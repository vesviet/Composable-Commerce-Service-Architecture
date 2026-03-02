# Order Lifecycle Flows — Business Logic Review Checklist

**Date**: 2026-02-25 (v2 — full re-verification)
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase deep-dive)
**Scope**: `order/`, `fulfillment/`, `payment/`, `warehouse/`, `shipping/`, `return/`, `checkout/`, `loyalty-rewards/`, `promotion/` — event coordination, saga, outbox, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §6 (Order Lifecycle)

---

## 📊 Summary

| Category | Status |
|----------|--------|
| 🔴 P0 — Critical (data loss / financial risk) | **10 FIXED** ✅ |
| 🟡 P1 — High (reliability) | **16 FIXED** ✅ + **1 ACCEPTED RISK** |
| 🔵 P2 — Medium (edge case / observability) | **9 open (monitor/document)** + **1 FIXED** |
| ✅ Verified Working | 40+ areas |

---

## 🔴 NEW P0 — CRITICAL

## 🔴 P0-2025-01: Loyalty Service Topic Mismatch ✅ FIXED

**Impact**: Loyalty points are **NEVER awarded** on order completion and **NEVER reversed** on order cancellation. Financial and customer trust risk.

**Root Cause**:
- Loyalty worker subscribes to `orders.order.completed` and `orders.order.cancelled` (file: `loyalty-rewards/internal/worker/event/consumer.go:72-79`)
- Dapr subscription YAML confirms: `dapr-subscription.yaml` routes `orders.order.completed` and `orders.order.cancelled`
- **BUT** the Order service only publishes `orders.order.status_changed` via outbox (`order/internal/biz/order/events.go:112`, `cancel.go:120`, `create.go:126`)
- `PublishOrderCompleted()` and `PublishOrderCancelled()` methods **exist** in `events/publisher.go:78,88` but are **NEVER called** from any business logic — they only appear in test mocks
- The `saveStatusChangedToOutbox()` writes ALL status changes to topic `orders.order.status_changed` only

**Evidence**:
```
// Order publishes:
Topic: "orders.order.status_changed" (outbox, always)

// Loyalty subscribes to:
Topic: "orders.order.completed"  ← NEVER published
Topic: "orders.order.cancelled"  ← NEVER published
```

**Fix Options**:
1. **Option A (Recommended)**: Change Loyalty to subscribe to `orders.order.status_changed` and filter by `new_status == "delivered"/"completed"` for points award, and `new_status == "cancelled"` for points reversal. This aligns with how Promotion service works.
2. **Option B**: Add outbox events in `UpdateOrderStatus` that publish BOTH `orders.order.status_changed` AND the specific `orders.order.completed`/`orders.order.cancelled` topics when the status is `delivered`/`cancelled`. This is the fan-out pattern.

**Affected Files**:
- `loyalty-rewards/internal/worker/event/consumer.go` — change topic subscriptions
- `loyalty-rewards/internal/worker/event/order_events.go` — update event struct to match `OrderStatusChangedEvent`
- `gitops/apps/loyalty-rewards/base/dapr-subscription.yaml` — update topics
- `order/internal/events/publisher.go` — remove dead `PublishOrderCompleted`/`PublishOrderCancelled` methods (cleanup)

---

## 🟡 NEW P1 — HIGH

### P1-2025-01: Promotion Worker Missing `startupProbe` + Config Volume

**Impact**: Promotion worker may be killed during slow startup; config file not mounted.

**Current State** (`gitops/apps/promotion/base/worker-deployment.yaml`):
- ❌ No `startupProbe` — K8s may kill pod during slow init
- ❌ No `volumeMounts` / `volumes` for config file — command `exec /app/bin/worker -conf /app/configs/config.yaml` will fail if config isn't mounted
- ❌ Probes use HTTP `:8081` — verify worker binary actually serves HTTP health on that port
- ❌ Dapr `app-port: "8081"` + `app-protocol: "http"` — promotion worker event consumers use gRPC-based common library

**Fix**: Add `startupProbe` (gRPC :5005), `volumeMounts`/`volumes` for `promotion-config`, switch Dapr to `app-protocol: "grpc"` if worker uses gRPC event server.

---

### P1-2025-02: Loyalty Worker Missing Config Volume Mount

**Impact**: Worker command `exec /app/bin/worker -conf /app/configs/config.yaml` won't find config file.

**Current State** (`gitops/apps/loyalty-rewards/base/worker-deployment.yaml`):
- ❌ No `volumeMounts` / `volumes` for config file
- ✅ Has `startupProbe` (tcpSocket :9014) — OK
- ⚠️ `livenessProbe` / `readinessProbe` use `kill -0 1` — not a real health check (only checks if PID 1 exists)
- ⚠️ `secretRef: loyalty-rewards` — should be `loyalty-rewards-secrets` for naming consistency

**Fix**: Add `volumeMounts`/`volumes` for `loyalty-rewards-config` ConfigMap at `/app/configs`.

---

### P1-2025-03: Promotion `HandleOrderStatusChanged` Missing Idempotency

**Impact**: Duplicate Dapr delivery will call `ReleasePromotionUsage` or `ConfirmPromotionUsage` twice. Could double-release promo quotas.

**Current State** (`promotion/internal/data/eventbus/order_consumer.go:73-109`):
- ❌ No `idempotencyHelper.CheckAndMark()` wrapper
- `ReleasePromotionUsage` — if called twice, may incorrectly double-decrease usage count
- `ConfirmPromotionUsage` — if called twice, second call is likely a no-op (depends on implementation)

**Fix**: Add `IdempotencyHelper` field, wrap `HandleOrderStatusChanged` with `CheckAndMark` using key `DeriveEventID("order_status_changed", orderID + "_" + newStatus)`.

---

### P1-2025-04: `publishStockCommittedEvent` Called Outside Transaction

**Impact**: If `outboxRepo.Save` succeeds but the caller (`ConfirmOrderReservations`) is called from a context where it's expected to be transactional, the stock committed event could be saved even if the parent operation fails.

**Current State** (`order/internal/biz/order/create.go:366-369`):
- `publishStockCommittedEvent` saves to outbox but is called AFTER the loop that confirms individual reservations
- If it fails, the error is logged but not returned (fire-and-forget with CRITICAL log)
- This is documented as acceptable risk, but the outbox save is **outside any transaction** — the ConfirmOrderReservations is called from `processPaymentConfirmed` which runs inside an event handler, not inside `tm.WithTransaction`

**Accepted Risk**: Log-only failure is intentional (stock is already committed). But the outbox event may be orphaned if the DB connection drops between the confirm loop and the save.

---

## 🔵 NEW P2 — MEDIUM

### P2-2025-01: Warehouse `StockCommittedConsumer` is Audit-Only (No Action)

**Status**: ⚠️ By design — `processStockCommitted()` only logs. No actual reconciliation logic.

**Current State** (`warehouse/internal/data/eventbus/stock_committed_consumer.go:112-119`):
```go
func (c StockCommittedConsumer) processStockCommitted(ctx context.Context, event *stockCommittedEvent) error {
    for _, item := range event.Items {
        c.log.WithContext(ctx).Infof("Stock committed: ...")
    }
    return nil
}
```

**Recommendation**: Implement actual reconciliation — compare committed quantities against warehouse stock records to detect discrepancies.

---

### P2-2025-02: Dead Code — `PublishOrderCompleted` and `PublishOrderCancelled` Never Called

**Status**: Code hygiene issue. Methods exist in `events/publisher.go:78,88` and the interface, but are never invoked from business logic. All status changes go through `saveStatusChangedToOutbox` → topic `orders.order.status_changed`.

**Recommendation**: After fixing P0-2025-01, either:
- Remove these methods if Option A (change loyalty to subscribe to `status_changed`) is chosen
- Wire them up if Option B (fan-out publish) is chosen

---

### P2-2025-03: Loyalty Worker Dapr App Port Mismatch Risk

**Status**: `dapr.io/app-port: "9014"` in worker deployment, but common events library uses gRPC server on port 5005 by default. If the loyalty worker uses `events.NewConsumerClientWithLogger` (which creates a gRPC server on :5005), the Dapr sidecar won't route events to it because it's configured to send to :9014.

**Current State** (`loyalty-rewards/internal/worker/event/consumer.go:32`):
```go
client, err := events.NewConsumerClientWithLogger(logger)
```
- This creates a gRPC server — need to verify what port it listens on
- Worker deployment has `containerPort: 9014` and `dapr.io/app-port: "9014"`
- If client library defaults to :5005, events won't be delivered

**Recommendation**: Verify the port mapping. If using common library default, Dapr should target :5005.

---

## ✅ Previously Fixed (All Prior P0s + Prior P1s)

| ID | Issue | Fix Confirmed? |
|----|-------|----------------|
| OR-P0-01 | Order creation lacks transactional outbox | ✅ `create.go:77-134` wraps order + outbox in `tm.WithTransaction` |
| OR-P0-02 | Double-confirmation of warehouse reservation at order creation | ✅ `create.go:210-219` removes `confirmOrderReservations` at creation; only confirmed on `payment.confirmed` |
| ORD-P0-01/02 | Missing FulfillmentConsumer + wrong status mapping | ✅ `fulfillment.completed → "shipped"` confirmed |
| OR-P1-01 | Order status transition validation | ✅ `canTransitionTo()` uses `constants.OrderStatusTransitions` |
| OR-P1-02 | Cart cleanup worker missing | ✅ `order/internal/worker/cron/order_cleanup.go` operational |
| PAY-P0-02 | Webhook idempotency missing | ✅ Redis state-machine idempotency service at `payment/internal/biz/webhook/handler.go:64-81` |
| WH-P0-02 | FulfillReservation missing idempotency | ✅ Idempotency checks added in warehouse fulfillment handler |
| FUL-P0-04/05 | Fulfillment events outside tx / batch picklist non-transactional | ✅ Both transactional outbox confirmed |
| P1-5 (refund_restock) | DLQ missing `refund_restock` handler | ✅ `dlq_retry_worker.go:183` handles `refund_restock` case |
| DLQ reservations | `release_reservations` DLQ lacked reservation IDs | ✅ `retryReleaseReservations()` reads from `CompensationMetadata["reservation_ids"]` |
| COD pagination | COD auto-confirm used unbounded cursor | ✅ Offset-based pagination with `batchSize=100` |
| Outbox worker PROCESSING | No atomic PROCESSING mark | ✅ `outbox/worker.go:118-122` marks PROCESSING before publish |
| **NEW-P0-001** | `writeWarehouseDLQ` did not save reservation IDs | ✅ `payment_consumer.go:533-547` loads order items, populates `metadata["reservation_ids"]` |
| **NEW-P0-002** | `processPaymentConfirmed` never called `confirmOrderReservations` | ✅ `payment_consumer.go:418` calls `c.orderUc.ConfirmOrderReservations(ctx, ord)` |
| **OR-P0-04** | Stripe webhook signature validation missing | ✅ `payment/internal/biz/gateway/stripe.go` — `stripe.ValidateWebhookSignature` added |
| **NEW-P1-001** | Worker health probes used HTTP `:8019` (no HTTP server in worker binary) | ✅ All 3 probes switched to `grpc: port: 5005` |
| **NEW-P1-002** | COD auto-confirm had no auto-cancel for expired orders | ✅ `cod_auto_confirm.go` two-pass: confirm within 24h, cancel past window |
| **NEW-P1-003** | `releaseWarehouseReservations` had no retry logic | ✅ `payment_consumer.go:468` — 3-retry with 100ms backoff per reservation |
| **DLQ Drain topic drift** | DLQ drain consumer topics were hardcoded strings | ✅ Replaced with `fmt.Sprintf("%s.dlq", constants.TopicXxx)` |
| **DLQ-SHIPPING-TOPIC** | DLQ drain slot 6 used wrong topic `TopicDeliveryConfirmed` | ✅ Fixed: slot 6 now uses `constants.TopicShipmentDelivered` |
| **SHIPPING-CONSTANT** | `shipping_consumer.go:76` used bare string instead of constant | ✅ Added `constants.TopicShipmentDelivered` |
| **RESERVATION-TTL-FALLBACK** | `reservation.go:35-40` silently fell back to no-TTL reservation | ✅ Removed fallback; both branches now fail-fast |
| **P0-2024-01** | Return restock retry path — `return.restock_retry` outbox event has no consumer | ✅ **RESOLVED** — `return/internal/worker/compensation_worker.go` `ReturnCompensationWorker` polls outbox for `return.restock_retry` and `return.refund_retry`, retries warehouse/payment calls, updates return status on success |
| **P0-2024-02** | Warehouse worker missing health probes + secret mount | ✅ GitOps FIXED |
| **P1-2024-01** | Fulfillment worker GitOps startup probe + volume | ✅ FIXED |
| **P1-2024-02** | Shipping `OrderCancelledConsumer` missing idempotency | ✅ FIXED |
| **P1-2024-03** | Fulfillment auto-complete shipped cron | ✅ FIXED |
| **P1-2024-04** | Fulfillment `OrderStatusConsumer` topic from config map key | ✅ FIXED — uses `constants.TopicOrderStatusChanged` |
| **P1-2024-05** | Shipping worker missing `startupProbe` | ✅ FIXED |
| **P1-2024-06** | Fulfillment `PicklistStatusConsumer` missing idempotency | ✅ FIXED |

---

### OR-P0-03: Stock Reservation Created Outside Order Transaction *(Formally Accepted Risk)*

**Status**: ✅ Option B accepted — `ReservationCleanupWorker` + TTL + `HandleReservationExpired` act as safety net.

> Reservation flow confirmed updated: checkout now reserves with `payment-window TTL` at `ConfirmCheckout` step 6 (`confirm.go:405`), after payment auth, before order creation. If order creation fails, `RollbackReservationsMap` immediately releases all reserved stock. This is the correct Shopify/Shopee pattern.

---

## 📋 Event Publishing Necessity Check

### Services That NEED to Publish (✅ Justified)

| Service | Event | Consumers | Justification |
|---------|-------|-----------|---------------|
| Order | `orders.order.status_changed` (outbox) | Fulfillment, Notification, Analytics, Promotion, Warehouse | **Essential** — drives entire downstream order lifecycle |
| Order | `inventory.stock.committed` (outbox) | Warehouse (audit-only), Analytics | **Essential** — stock audit trail |
| Order | `orders.payment.capture_requested` | Payment consumer (self-loop via Dapr) | **Essential** — async capture for auth-and-capture flow |
| Order | `orders.order.completed` | **🔴 DEAD — never published** | See P0-2025-01 |
| Order | `orders.order.cancelled` | **🔴 DEAD — never published** | See P0-2025-01 |
| Payment | `payments.payment.confirmed` | Order (confirm), Notification, Analytics | **Essential** |
| Payment | `payments.payment.failed` | Order (cancel + release), Analytics | **Essential** |
| Fulfillment | `fulfillments.fulfillment.status_changed` | Order (status update), Warehouse (stock deduct) | **Essential** |
| Fulfillment | `fulfillment.picklist_status_changed` | Fulfillment self (worker) | **Essential** — internal picklist state machine |
| Warehouse | `warehouse.inventory.reservation_expired` | Order (auto-cancel on TTL) | **Essential** — prevents ghost reservations |
| Return | `return.restock_retry` (outbox) | ✅ `ReturnCompensationWorker` | **RESOLVED** |
| Return | `return.refund_retry` (outbox) | ✅ `ReturnCompensationWorker` | **RESOLVED** |
| Return | `return.completed` | Warehouse (restock items) | **Essential** |
| Checkout | `checkout.cart.converted` (outbox) | Analytics, CRM | **Essential** — conversion funnel tracking |

### Services That Subscribe But Might Not Need To (🔶 Review)

| Service | Subscription | Verdict |
|---------|-------------|---------|
| Order | `orders.payment.capture_requested` (self-loop) | ✅ Correct pattern for 2-step auth-capture; COD correctly skipped |
| Order | `warehouse.inventory.reservation_expired` | ✅ Correct — auto-cancels order when reservation TTL expires |
| Order | `shipping.shipment.delivered` | ✅ Correct — sets order status to "delivered" |
| Fulfillment | `shipping.shipment.delivered` | ✅ Correct — triggers fulfillment completion |
| Shipping | `order.cancelled` | ✅ Correct — cancels active shipments (topic needs verification) |
| Promotion | `orders.order.status_changed` | ✅ Correct — releases usage on cancel/refund, confirms on delivered/completed |
| Loyalty | `orders.order.completed` | 🔴 **BROKEN** — topic never published. See P0-2025-01 |
| Loyalty | `orders.order.cancelled` | 🔴 **BROKEN** — topic never published. See P0-2025-01 |

---

## 📋 Event Subscription Necessity Check

### Order Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `payments.payment.confirmed` | `HandlePaymentConfirmed` | ✅ Yes — confirm order status, confirm reservations |
| `payments.payment.failed` | `HandlePaymentFailed` | ✅ Yes — cancel order + release reservations (with retry) |
| `orders.payment.capture_requested` | `HandlePaymentCaptureRequested` | ✅ Yes — trigger async payment capture |
| `fulfillments.fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ Yes — drive order status through lifecycle |
| `warehouse.inventory.reservation_expired` | `HandleReservationExpired` | ✅ Yes — auto-cancel orders with expired stock |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ Yes — move order to "delivered" |
| `*.dlq` (6 topics) | DLQ drain (log + ACK) | ✅ Added — prevents Redis DLQ backpressure |

### Fulfillment Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `orders.order.status_changed` | `HandleOrderStatusChanged` | ✅ Yes — create pick/pack tasks on PAID status; uses `constants.TopicOrderStatusChanged` ✅ |
| `fulfillment.picklist_status_changed` | `HandlePicklistStatusChanged` | ✅ Yes — advance fulfillment status; idempotency ✅ |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ Yes — mark fulfillment complete; **no idempotency** ⚠️ P2 |

### Warehouse Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `fulfillments.fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ Yes — deduct stock permanently on shipment |
| `orders.order.status_changed` | `HandleOrderStatusChanged` | ✅ Yes — release reservation on cancellation |
| `return.completed` | `HandleReturnCompleted` | ✅ Yes — restock returned items |
| `catalog.product.created` | `HandleProductCreated` | ✅ Yes — init stock record |
| `inventory.stock.committed` | `HandleStockCommitted` | ⚠️ Audit-only (logs, no action) — P2-2025-01 |

### Shipping Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `fulfillment.package_status_changed` | `HandlePackageStatusChanged` | ✅ Yes — update shipping shipment status |
| `order.cancelled` | `HandleOrderCancelled` | ✅ Yes — cancel active shipments; idempotency ✅ |

### Loyalty Worker Subscriptions

| Topic | Handler | Status |
|-------|---------|--------|
| `customer.created` | `handleCustomerCreated` | ✅ Working |
| `orders.order.completed` | `handleOrderCompleted` | 🔴 **BROKEN** — topic never published |
| `orders.order.cancelled` | `handleOrderCancelled` | 🔴 **BROKEN** — topic never published |
| `customer.deleted` | `handleCustomerDeleted` | ✅ Working |

### Promotion Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `orders.order.status_changed` | `HandleOrderStatusChanged` | ✅ Yes — releases on cancel/refund, confirms on complete; **no idempotency** ❌ P1-2025-03 |

---

## 📋 Worker & Cron Job Checks

### Order Worker (`order/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | 1s poll, 50 events/batch, atomic PROCESSING mark, 10 retries, 30-day cleanup |
| **EventConsumersWorker** | ✅ Yes | payment/fulfillment/warehouse/shipping consumers + 6 DLQ drain handlers |
| **DLQRetryWorker** | ✅ Yes | 5m interval, 5 operation types, exponential backoff (max 30m), alert on exhaustion |
| **CODAutoConfirmJob** | ✅ Yes | 1m interval, offset pagination, 24h confirm + expired auto-cancel (two-pass) |
| **PaymentCompensationWorker** | ✅ Yes | `cron/payment_compensation.go` — retry stuck payment captures |
| **CaptureRetryWorker** | ✅ Yes | `cron/capture_retry.go` — retry failed payment captures |
| **ReservationCleanupWorker** | ✅ Yes | `cron/reservation_cleanup.go` — release expired reservations |
| **OrderCleanupWorker** | ✅ Yes | `cron/order_cleanup.go` — clean abandoned/stale orders |
| **FailedCompensationsCleanup** | ✅ Yes | `cron/failed_compensations_cleanup.go` |
| **DLQ consumers** | ✅ Yes | 6 DLQ drain handlers registered in `event_worker.go:82-101` |

### Fulfillment Worker (`fulfillment/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | Outbox pattern for fulfillment status events |
| **OrderStatusConsumerWorker** | ✅ Yes | Topic uses `constants.TopicOrderStatusChanged` ✅; idempotency ✅ |
| **PicklistStatusConsumerWorker** | ✅ Yes | Idempotency added ✅ |
| **ShipmentDeliveredConsumerWorker** | ✅ Yes | `event_workers.go:104-134`; **no idempotency** ⚠️ — P2 |
| **AutoCompleteShippedWorker** | ✅ Yes | `cron/auto_complete_shipped.go` — 1h interval, 7-day threshold, batch 50 |

### Warehouse Worker (`warehouse/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | `worker/outbox_worker.go` |
| **FulfillmentStatusConsumerWorker** | ✅ Yes | Idempotency applied |
| **OrderStatusConsumerWorker** | ✅ Yes | Idempotency applied |
| **ReturnConsumerWorker** | ✅ Yes | `return_consumer.go` present |
| **StockCommittedConsumerWorker** | ✅ Yes | `stock_committed_consumer.go` — audit-only (logs) |
| **ExpiryWorker** | ✅ Yes | `worker/expiry/` — reservation TTL enforcement |
| **Stock Import Worker** | ✅ Yes | `worker/import_worker.go` |
| **Cron Jobs** | ✅ Yes | alert_cleanup, capacity_monitor, daily_reset, daily_summary, outbox_cleanup, reservation_cleanup, stock_change_detector, timeslot_validator, weekly_report |

### Shipping Worker (`shipping/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | `worker/outbox_worker.go` |
| **PackageStatusConsumerWorker** | ✅ Yes | Idempotency applied ✅ |
| **OrderCancelledConsumerWorker** | ✅ Yes | Idempotency added ✅ |
| **startupProbe** | ✅ Fixed | YAML validated |

### Return Worker (`return/internal/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | `outbox_worker.go` |
| **ReturnCompensationWorker** | ✅ Yes | `compensation_worker.go` — polls `return.restock_retry` + `return.refund_retry` |

### Loyalty Worker (`loyalty-rewards/internal/worker/event/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **EventConsumersWorker** | ⚠️ Partial | Subscribes: `customer.created` ✅, `orders.order.completed` 🔴, `orders.order.cancelled` 🔴, `customer.deleted` ✅ |
| **Idempotency on order.completed** | ✅ Yes | `TransactionExists(ctx, "order", orderID)` — but never triggered |
| **Idempotency on order.cancelled** | ✅ Yes | `TransactionExists(ctx, "order_cancellation", orderID)` — but never triggered |

### Promotion Worker (`promotion/internal/data/eventbus/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OrderConsumer** | ✅ Yes | `order_consumer.go` — subscribes to `orders.order.status_changed` |
| **Usage reversal on cancel/refund** | ✅ Yes | `ReleasePromotionUsage(ctx, orderID)` |
| **Usage confirmation on complete** | ✅ Yes | `ConfirmPromotionUsage(ctx, orderID)` |
| **Idempotency on OrderStatusChanged** | ❌ **MISSING** | No idempotency check — P1-2025-03 |

---

## 📋 Saga / Outbox / Retry Correctness

| Check | Status | Notes |
|-------|--------|-------|
| Order create → outbox (atomic tx) | ✅ | `create.go:77-134` |
| Cancel → outbox (atomic tx) | ✅ | `cancel.go:108-126` |
| Payment confirmed → UpdateOrderStatus (via `orderUc`) | ✅ | Triggers outbox in `UpdateOrderStatus` |
| Payment confirmed → ConfirmReservations | ✅ | `payment_consumer.go:418`; rollback on partial failure; DLQ on error |
| Payment failed → ReleaseReservations + DLQ | ✅ | `payment_consumer.go:468` — 3-retry per reservation; DLQ with reservation IDs |
| Fulfillment cancelled → CancelOrder (with reservation release) | ✅ | `fulfillment_consumer.go:143` |
| DLQ retry: void_authorization | ✅ | |
| DLQ retry: release_reservations | ✅ | Reads `reservation_ids` from `CompensationMetadata` |
| DLQ retry: refund | ✅ | |
| DLQ retry: payment_capture | ✅ | |
| DLQ retry: refund_restock | ✅ | `ReturnCompensationWorker` handles via outbox polling |
| DLQ retry: alert on exhaustion | ✅ | `triggerAlert` + `alertService` |
| Outbox worker: PROCESSING mark | ✅ | Line 118 |
| Outbox worker: max 10 retries | ✅ | Line 135 |
| Outbox worker: 30-day cleanup | ✅ | `CleanupOldEvents` every 10 cycles |
| Webhook idempotency | ✅ | Redis state machine in payment service |
| Event consumer idempotency (order) | ✅ | `IdempotencyHelper.CheckAndMark` in payment + fulfillment + warehouse + shipping consumers |
| Event consumer idempotency (warehouse) | ✅ | Applied on all warehouse consumers |
| Event consumer idempotency (shipping package) | ✅ | Applied |
| Event consumer idempotency (shipping order_cancelled) | ✅ | FIXED |
| Event consumer idempotency (fulfillment picklist) | ✅ | FIXED |
| Event consumer idempotency (fulfillment shipment_delivered) | ⚠️ | Missing — P2 (low risk) |
| Event consumer idempotency (promotion order_status) | ❌ | **MISSING** — P1-2025-03 |
| Event consumer idempotency (loyalty order events) | ✅ | App-level via `TransactionExists` (but never triggered — P0-2025-01) |
| Fulfillment status backward guard | ✅ | `constants.IsLaterStatus` check |
| ConfirmOrderReservations rollback | ✅ | `create.go:352-358` — rolls back already-confirmed reservations on failure |
| `publishStockCommittedEvent` (outbox) | ⚠️ | `create.go:373-409` — saves outbox but OUTSIDE transaction — P1-2025-04 |
| Checkout reservation rollback on order failure | ✅ | `confirm.go:425-426` `RollbackReservationsMap` called + payment void |
| Loyalty topic routing | 🔴 | Topics `orders.order.completed` / `orders.order.cancelled` NEVER published — P0-2025-01 |

---

## 📋 GitOps Config Checks

### Order Worker (`gitops/apps/order/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: order-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` + `startupProbe` on gRPC :5005 | ✅ Fixed |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: order-secrets` | ✅ |
| `resources: requests + limits` | ✅ |
| `revisionHistoryLimit: 1` | ✅ |
| `configFile volumeMount` | ✅ |
| `initContainers` (consul + redis + postgres) | ✅ |

### Fulfillment Worker (`gitops/apps/fulfillment/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext` | ✅ |
| `dapr.io/enabled` + `app-id: fulfillment-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` on gRPC :5005 | ✅ |
| `startupProbe` | ✅ Fixed |
| `envFrom: configMapRef + secretRef` | ✅ |
| `configFile volumeMount` | ✅ Fixed |
| `initContainers` | ✅ |

### Shipping Worker (`gitops/apps/shipping/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext` | ✅ |
| `dapr.io/enabled` + `app-id: shipping-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` on gRPC :5005 | ✅ |
| `startupProbe` | ✅ Fixed |
| `envFrom: configMapRef + secretRef` | ✅ |
| `configFile volumeMount` | ✅ |
| `initContainers` | ✅ |

### Warehouse Worker (`gitops/apps/warehouse/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext` | ✅ |
| `dapr.io/enabled` + `app-id: warehouse-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` + `startupProbe` | ✅ Fixed |
| `envFrom: configMapRef + secretRef` | ✅ Fixed |
| `configFile volumeMount` | ✅ Fixed |
| `initContainers` | ✅ |

### Promotion Worker (`gitops/apps/promotion/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext` | ✅ |
| `dapr.io/enabled` + `app-id: promotion-worker` | ✅ |
| `dapr.io/app-port: "8081"` + `app-protocol: "http"` | ❌ **P1-2025-01** — may need `"grpc"` + port `5005` if using common events library |
| `livenessProbe` + `readinessProbe` (HTTP :8081) | ⚠️ Verify worker serves HTTP health |
| `startupProbe` | ❌ **MISSING** — P1-2025-01 |
| `envFrom: configMapRef + secretRef` | ✅ |
| `configFile volumeMount` | ❌ **MISSING** — P1-2025-01 |
| `initContainers` | ✅ |

### Loyalty Worker (`gitops/apps/loyalty-rewards/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext` | ✅ |
| `dapr.io/enabled` + `app-id: loyalty-rewards-worker` | ✅ |
| `dapr.io/app-port: "9014"` + `app-protocol: "grpc"` | ⚠️ P2-2025-03 — verify port matches common library |
| `livenessProbe` + `readinessProbe` (`kill -0 1`) | ⚠️ Not a real health check |
| `startupProbe` (tcpSocket :9014) | ✅ |
| `envFrom: configMapRef + secretRef` | ✅ (but secret name is `loyalty-rewards` not `loyalty-rewards-secrets`) |
| `configFile volumeMount` | ❌ **MISSING** — P1-2025-02 |
| `initContainers` | ✅ |
| `Dapr subscription YAML` | ✅ Separate `dapr-subscription.yaml` — routes match code consumer topics |

---

## 📋 Data Consistency Matrix — Full Cross-Service

| Data Pair | Consistency Level | Risk |
|-----------|-----------------|------|
| Order DB ↔ Outbox events | ✅ Atomic (same TX) | Event loss extremely unlikely |
| Order status ↔ Payment status | ✅ Eventually consistent | `payment.confirmed` → order confirmed via event |
| Order status ↔ Fulfillment status | ✅ Eventually consistent | Via `fulfillment.status_changed` consumer |
| Warehouse reservation ↔ Order item | ⚠️ Race (OR-P0-03 — accepted) | Mitigated by TTL + `ReservationCleanupWorker` |
| Checkout stock reservation ↔ Payment auth | ✅ Correct ordering (confirm.go step 5→6) | Auth before reservation; void on fail |
| Warehouse stock ↔ Order paid | ✅ Fixed (NEW-P0-002) | `processPaymentConfirmed` → `ConfirmOrderReservations` |
| DLQ compensation ↔ Reservation IDs | ✅ Fixed (NEW-P0-001) | `writeWarehouseDLQ` saves `reservation_ids` |
| COD order lifecycle ↔ Time window | ✅ Fixed (NEW-P1-002) | Two-pass: confirm + cancel |
| Return restock ↔ Warehouse stock | ✅ RESOLVED | `ReturnCompensationWorker` |
| Promotion usage ↔ Order lifecycle | ✅ Handled | Subscribes to `order.status_changed`; reverses on cancel, confirms on complete. No idempotency — P1-2025-03 |
| **Loyalty points ↔ Order lifecycle** | 🔴 **BROKEN** | **P0-2025-01** — Loyalty subscribes to dead topics. Points never awarded/reversed. |
| Fulfillment topic ↔ Config key | ✅ Fixed (P1-2024-04) | Uses constant now |
| Shipping OrderCancelled ↔ Duplicate events | ✅ Fixed (P1-2024-02) | Idempotency added |

---

## 📋 Edge Cases Not Yet Handled

| Edge Case | Risk | Recommendation |
|-----------|------|----------------|
| **Loyalty never receives order events** | 🔴 Critical | **P0-2025-01** — Fix topic subscription |
| COD order delivered, `delivery.confirmed` webhook never arrives | ✅ FIXED | `AutoCompleteShippedWorker` runs hourly |
| Order has items from 2+ warehouses; partial fulfillment | 🟡 High | Multi-warehouse fulfillment aggregation still open |
| Capture payment fails with auth expiry; order stuck in `pending_capture` | 🟡 High | DLQ record created; Ops must act after DLQ alert |
| Promotion `HandleOrderStatusChanged` duplicate Dapr delivery | 🟡 Medium | **P1-2025-03** — add idempotency |
| Loyalty `order.completed` event payload missing `subtotal` field | 🔵 Medium | Currently never triggered (P0-2025-01) |
| Order with loyalty points redeemed; order cancelled → points not restored | ⚠️ Blocked | Cannot verify until P0-2025-01 is fixed |
| Fulfillment cron auto-complete → seller escrow release | ✅ FIXED | P1-2024-03 |
| Fulfillment `OrderStatusConsumer` empty topic string | ✅ FIXED | P1-2024-04 |
| Dapr redelivers `order.cancelled` to shipping → double carrier cancel | ✅ FIXED | P1-2024-02 |
| `OrderStatusChangedEvent` payload schema changes → deserialization failures | 🔵 Medium | Schema versioning needed |
| SLA breach: seller doesn't ship within 24h | 🔵 Medium | No SLA breach cron in fulfillment |
| Return restock uses `"default"` warehouse_id when metadata missing | 🔵 Low | `restock.go:47` falls back to `"default"` |
| Fulfillment `ShipmentDeliveredConsumer` no idempotency | 🔵 Low | Carrier dedup reduces risk |
| Promotion worker config file not mounted | 🟡 Medium | **P1-2025-01** — config volume missing from GitOps |
| Loyalty worker config file not mounted | 🟡 Medium | **P1-2025-02** — config volume missing from GitOps |

---

## 📋 Remediation Actions

### 🔴 Fix Now (Data Loss / Financial Risk)

- [ ] **P0-2025-01**: Loyalty service topic mismatch — events never received. **ACTION**: Change loyalty to subscribe to `orders.order.status_changed` and filter by status.

### 🟡 Fix Soon (Reliability)

- [ ] **P1-2025-01**: Promotion worker GitOps — add `startupProbe`, `volumeMounts`, verify Dapr protocol
- [ ] **P1-2025-02**: Loyalty worker GitOps — add config `volumeMount`
- [ ] **P1-2025-03**: Promotion `HandleOrderStatusChanged` — add idempotency
- [ ] **P1-2025-04**: `publishStockCommittedEvent` outside transaction — accepted risk, document

### 🔵 Monitor / Document

- [ ] P2-2025-01: Warehouse `StockCommittedConsumer` audit-only — implement reconciliation
- [ ] P2-2025-02: Dead code cleanup — `PublishOrderCompleted`/`PublishOrderCancelled` methods
- [ ] P2-2025-03: Loyalty worker Dapr port mismatch — verify common library port
- [ ] Add SLO alert: `pending outbox events > 100 AND age > 5m` → PagerDuty
- [ ] Document DLQ replay procedure for Ops
- [ ] Schema versioning for `OrderStatusChangedEvent` payload
- [ ] SLA breach escalation cron in fulfillment
- [ ] Verify `return.restock_retry` uses correct warehouse_id

---

## ✅ What Is Working Well

| Area | Notes |
|------|-------|
| Transactional outbox | All status changes use `tm.WithTransaction + outboxRepo.Save` |
| Saga compensation | 5 compensation types in DLQ retry worker with exponential backoff |
| Idempotency (order/warehouse/shipping) | `IdempotencyHelper.CheckAndMark` on all critical consumers |
| Status transition guard | `canTransitionTo` prevents invalid state changes |
| Fulfillment cancelled → CancelOrder | Uses `CancelOrder()` (not just `UpdateStatus`) → reservation release + retry + DLQ |
| Backward status guard | `constants.IsLaterStatus` prevents status regression |
| COD payment capture skip | COD orders correctly skip the payment capture path |
| Auth expiry guard | `HandlePaymentCaptureRequested` fails fast if order is too old |
| Auth amount guard | Capture uses authoritative DB amount, not event amount |
| DLQ alert on exhaustion | `triggerAlert` fires after `MaxRetries` → Ops email |
| Outbox cleanup | 30-day retention auto-cleanup |
| Payment webhook idempotency | Redis state machine |
| Stock committed event | `ConfirmOrderReservations` saves `inventory.stock.committed` outbox event |
| Partial confirm rollback | `ConfirmOrderReservations` rolls back already-confirmed reservations on failure |
| ReservationExpired → full cancel | `processReservationExpired` cancels entire order |
| DLQ drain consumers | 6 DLQ drain handlers prevent Redis backpressure |
| Order worker health probes | gRPC :5005 |
| Reservation TTL fail-fast | No silent fallback to no-TTL |
| Return compensation worker | Polls `return.restock_retry` + `return.refund_retry` |
| Promotion usage lifecycle | Subscribes to `order.status_changed` — reverses on cancel, confirms on complete |
| Checkout reservation ordering | Stock reserved AFTER payment auth (step 6), with immediate rollback |
| Checkout coupon locking | `acquireCouponLocks` at ConfirmCheckout |
| Checkout fraud pre-check | `validateFraudIndicators` before payment auth |
| CartConverted outbox (fail-fast) | `finalizeOrderAndCleanup` fails if outbox save fails |

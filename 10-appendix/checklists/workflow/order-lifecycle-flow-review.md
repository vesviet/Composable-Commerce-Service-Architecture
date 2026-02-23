# Order Lifecycle Flows — Business Logic Review Checklist

**Date**: 2026-02-23 | **Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `order/`, `fulfillment/`, `payment/`, `warehouse/` — event coordination, saga, outbox, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §6 (Order Lifecycle)

---

## 📊 Summary

| Category | Status |
|----------| -------|
| 🔴 P0 — Critical (data loss / financial risk) | **ALL 6 FIXED** ✅ |
| 🟡 P1 — High (reliability) | **ALL 3 FIXED + 3 NEW FOUND & FIXED** ✅ (2026-02-23) |
| 🔵 P2 — Medium (edge case / observability) | **4 open (monitor/document)** |
| ✅ Verified Working | 30 areas |

---

## ✅ Verified Fixed (All P0s + Most P1s)

| ID | Issue | Fix Confirmed? |
|----|-------|----------------|
| OR-P0-01 | Order creation lacks transactional outbox | ✅ `create.go:77-134` wraps order + outbox in `tm.WithTransaction` |
| OR-P0-02 | Double-confirmation of warehouse reservation at order creation | ✅ `create.go:210-219` removes `confirmOrderReservations`; comment documents intent |
| ORD-P0-01/02 | Missing FulfillmentConsumer + wrong status mapping | ✅ `fulfillment.completed → "shipped"` confirmed at line 203 |
| OR-P1-01 | Order status transition validation | ✅ `canTransitionTo()` uses `constants.OrderStatusTransitions`; cancel uses this |
| OR-P1-02 | Cart cleanup worker missing | ✅ `order/internal/worker/cron/order_cleanup.go` operational |
| PAY-P0-02 | Webhook idempotency missing | ✅ Redis state-machine idempotency service at `payment/internal/biz/webhook/handler.go:64-81` |
| WH-P0-02 | FulfillReservation missing idempotency | ✅ `warehouse/internal/biz/inventory/fulfillment_status_handler.go:114` idempotency checks added |
| FUL-P0-04/05 | Fulfillment events outside tx / batch picklist non-transactional | ✅ Both transactional outbox confirmed |
| P1-5 (refund_restock) | DLQ missing `refund_restock` handler | ✅ `dlq_retry_worker.go:183` handles `refund_restock` case |
| DLQ reservations | `release_reservations` DLQ lacked reservation IDs | ✅ `retryReleaseReservations()` reads from `CompensationMetadata["reservation_ids"]` |
| DLQ-Ops-idempotency | Ops replay compensation missing idempotency key | ⚠️ Improved: DLQ retry uses `PaymentSagaState` guard; but no explicit idempotency key sent to Payment gRPC |
| COD pagination | COD auto-confirm used unbounded cursor | ✅ Offset-based pagination with `batchSize=100` |
| P2: Return events | Return events direct-publish (not outbox) | 🔶 Partially open (see RISK-003) |
| Outbox worker PROCESSING | No atomic PROCESSING mark | ✅ `outbox/worker.go:118-122` marks PROCESSING before publish |
| **NEW-P0-001** | `writeWarehouseDLQ` did not save reservation IDs | ✅ `payment_consumer.go:533-547` loads order items, populates `metadata["reservation_ids"]` before `failedCompensationRepo.Create` |
| **NEW-P0-002** | `processPaymentConfirmed` never called `confirmOrderReservations` | ✅ `payment_consumer.go:418` calls `c.orderUc.ConfirmOrderReservations(ctx, ord)` after `UpdateOrderStatus`; DLQ written on failure |
| **OR-P0-04** | Stripe webhook signature validation missing | ✅ `payment/internal/biz/gateway/stripe.go` — `stripe.ValidateWebhookSignature` added; secret injected via K8s Secret |
| **NEW-P1-003** | `releaseWarehouseReservations` had no retry logic | ✅ `payment_consumer.go:468-470` wraps each release in `biz.Retry(ctx, 3, 100ms, ...)` |
| **NEW-P1-001** | Worker health probes used HTTP `:8019` (no HTTP server in binary) | ✅ `gitops/apps/order/base/worker-deployment.yaml` — all 3 probes switched to `grpc: port: 5005`; failureThreshold adjusted |
| **NEW-P1-002** | COD auto-confirm had no auto-cancel for expired orders | ✅ `cod_auto_confirm.go` — refactored into two passes: `confirmNewCODOrders` (StartDate filter) + `cancelExpiredCODOrders` (EndDate filter, calls `CancelOrder` with reason `cod_confirmation_window_expired`) |
| **DLQ Drain topic drift** | DLQ drain consumer topics were hardcoded strings | ✅ `event_worker.go` — replaced with `fmt.Sprintf("%s.dlq", constants.TopicXxx)` + `eventbus.TopicReservationExpired`; pubsub name uses `constants.DaprDefaultPubSub` |

---

## 🔴 Open P0 Issues

### OR-P0-03: Stock Reservation Created Outside Order Transaction *(Accepted Risk)*

**File**: `order/internal/biz/order/create.go:77-134`, checkout flow caller

**Problem**: Cart checkout service creates stock reservations with the Warehouse service **before** calling `Order.CreateOrder`. The reservation gRPC call and the order DB insert are in separate network operations — there is no distributed atomic guarantee.

```
Checkout → Warehouse.CreateReservation (network) ← ORDER NOT CREATED YET
         ↓
         Order.CreateOrder (DB tx)
```

**Race scenario**: Warehouse reservation succeeds → order TX fails (e.g., DB downtime) → reservation is stuck (no order will ever confirm or release it). Reservation TTL is the only safety net.

**Shopify pattern**: Inventory reservation is created atomically inside the checkout transaction using a two-phase commit or is deferred until payment capture succeeds.

**Resolution**:
- [ ] Option A: Create reservation **after** order is persisted, inside the same `tm.WithTransaction` (requires synchronous warehouse gRPC inside TX — acceptable for auth networks)
- [x] Option B: Treat reservation as optimistic — reconcile via `ReservationExpiredWorker` + heartbeat; acceptable if warehouse TTL is reliably enforced *(Decision documented at create.go:210-219)*

> **Status**: Option B formally accepted — `ReservationCleanupWorker` + TTL + `HandleReservationExpired` act as safety net. Tracked as known risk.

---

## 🟡 Remaining P1 Issues

### NEW-P1-001: Order Worker Missing HTTP Health Probes on Correct Port *(Partially Fixed)*

**File**: `gitops/apps/order/base/worker-deployment.yaml`

**Current state**: Worker deployment at line 70-90 already has `livenessProbe`, `readinessProbe`, and `startupProbe` configured, but they use **HTTP GET on port 8019**, while the Dapr annotation declares `app-port: 5005 (grpc)`.

```yaml
# Actual probes in worker-deployment.yaml (lines 70-90):
livenessProbe:
  httpGet:
    path: /healthz
    port: 8019   # ← HTTP health server
readinessProbe:
  httpGet:
    path: /healthz
    port: 8019
```

**Issue**: If the order-worker binary does **not** expose an HTTP server on `:8019`, all 3 probes will fail → pod crash-loops on startup. Verify whether `cmd/worker/main.go` starts an HTTP health server on 8019.

**Also confirmed**: `revisionHistoryLimit: 1` is present at line 13 ✅

**Resolution**:
- [ ] Verify `cmd/worker/main.go` opens HTTP health endpoint on `:8019`; if not, switch probes to gRPC on port 5005:
  ```yaml
  livenessProbe:
    grpc:
      port: 5005
    initialDelaySeconds: 30
    periodSeconds: 30
  ```

---

### NEW-P1-002: COD Auto-Confirm Does Not Auto-Cancel Expired Orders

**File**: `order/internal/worker/cron/cod_auto_confirm.go:93`

**Current state**: The 24-hour `StartDate` filter ✅ correctly prevents confirming orders older than 24h. However, orders *past* the window are simply skipped — they remain in `pending` state indefinitely and are never cancelled.

**Shopee pattern**: COD orders past confirmation window → auto-cancel with reason `cod_confirmation_window_expired`.

**Resolution**:
- [ ] After the current batch loop, add a second query for `pending` COD orders with `created_at < NOW() - 24h`, then call `CancelOrder` for each with reason `"COD confirmation window expired"`. This should be a configurable window (env var), not hardcoded 24h.

---

### DLQ Drain Consumer Topic Names May Not Match

**File**: `order/internal/worker/event/event_worker.go:82-89`

**Problem**: The DLQ drain consumers are registered with hardcoded topic names like `"payments.payment.confirmed.dlq"`. If the actual DLQ topic names differ from what Dapr generates (typically `"{topic}.dlq"` using the original topic name), these subscriptions will silently never receive messages — the drain won't work.

**Verify**: Confirm Dapr's actual `deadLetterTopic` format for each topic matches the strings in `dlqTopics` slice. In particular, `constants.TopicPaymentConfirmed` should be checked:
```bash
grep -r 'TopicPayment\|TopicFulfillment\|TopicWarehouse\|TopicShipping' \
  order/internal/constants/ --include='*.go'
```

**Resolution**:
- [ ] Use `fmt.Sprintf("%s.dlq", constants.TopicPaymentConfirmed)` etc. to derive DLQ names from constants — avoids string drift

---

## 📋 Event Publishing Necessity Check

### Services That NEED to Publish (✅ Justified)

| Service | Event | Consumers | Justification |
|---------|-------|-----------|---------------|
| Order | `order.status.changed` | Fulfillment, Notification, Analytics, Loyalty, Customer | **Essential** — drives entire downstream order lifecycle |
| Order | `inventory.stock.committed` | Analytics, Reporting | **Essential** — stock audit trail |
| Order | `orders.payment.capture_requested` | Payment consumer (self-loop via Dapr) | **Essential** — async capture for auth-and-capture flow |
| Order | `compensation.reservation_release` (outbox DLQ) | Order outbox worker | Justified: DLQ compensation pattern |
| Payment | `payment.confirmed` | Order (confirm), Loyalty (points), Analytics | **Essential** |
| Payment | `payment.failed` | Order (cancel + release), Analytics | **Essential** |
| Payment | `payment.capture_failed` | Order (mark failed) | **Essential** |
| Fulfillment | `fulfillment.status_changed` | Order (status update), Warehouse (stock deduct) | **Essential** |
| Warehouse | `warehouse.inventory.reservation_expired` | Order (auto-cancel on TTL) | **Essential** — prevents ghost reservations |

### Services That Subscribe But Might Not Need To (🔶 Review)

| Service | Subscription | Verdict |
|---------|-------------|---------|
| Order | `orders.payment.capture_requested` (self-loop) | ✅ Correct pattern for 2-step auth-capture; COD correctly skipped at line 163 |
| Order | `warehouse.inventory.reservation_expired` | ✅ Correct — auto-cancels order when reservation TTL expires |
| Order | `shipping.shipment.delivered` | ✅ Correct — sets order status to "delivered" |

**No unnecessary subscriptions found.**

---

## 📋 Event Subscription Necessity Check

### Order Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------| 
| `payment.confirmed` | `HandlePaymentConfirmed` | ✅ Yes — confirm order status, confirm reservations ✅ (NEW-P0-002 fixed) |
| `payment.failed` | `HandlePaymentFailed` | ✅ Yes — cancel order + release reservations (with retry) |
| `orders.payment.capture_requested` | `HandlePaymentCaptureRequested` | ✅ Yes — trigger async payment capture |
| `fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ Yes — drive order status through lifecycle |
| `warehouse.inventory.reservation_expired` | `HandleReservationExpired` | ✅ Yes — auto-cancel orders with expired stock |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ Yes — move order to "delivered" |
| `*.dlq` (6 topics) | DLQ drain (log + ACK) | ✅ Added — prevents Redis DLQ backpressure |

---

## 📋 Worker & Cron Job Checks

### Order Worker (`order/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | 1s poll, 50 events/batch, atomic PROCESSING mark, 10 retries, 30-day cleanup |
| **EventConsumersWorker** | ✅ Yes | payment/fulfillment/warehouse/shipping consumers + 6 DLQ drain handlers |
| **DLQRetryWorker** | ✅ Yes | 5m interval, 5 operation types, exponential backoff, alert on exhaustion |
| **CODAutoConfirmJob** | ✅ Yes | 1m interval, offset pagination, 24h age filter |
| **PaymentCompensationWorker** | ✅ Yes | `cron/payment_compensation.go` — retry stuck payment captures |
| **CaptureRetryWorker** | ✅ Yes | `cron/capture_retry.go` — retry failed payment captures |
| **ReservationCleanupWorker** | ✅ Yes | `cron/reservation_cleanup.go` — release expired reservations |
| **OrderCleanupWorker** | ✅ Yes | `cron/order_cleanup.go` — clean abandoned/stale orders |
| DLQ consumers (subscribers) | ✅ Yes | 6 DLQ drain handlers registered in `event_worker.go:82-101` |

---

## 📋 Saga / Outbox / Retry Correctness

| Check | Status | Notes |
|-------|--------|-------|
| Order create → outbox (atomic tx) | ✅ | `create.go:77-134` |
| Cancel → outbox (atomic tx) | ✅ | `cancel.go:108-126` |
| Payment confirmed → UpdateOrderStatus (via `orderUc`) | ✅ | Triggers outbox in `UpdateOrderStatus` |
| Payment confirmed → ConfirmReservations | ✅ | **Fixed (NEW-P0-002)**: `payment_consumer.go:418` calls `uc.ConfirmOrderReservations`; rollback on partial failure; DLQ on error |
| Payment failed → ReleaseReservations + DLQ | ✅ | `payment_consumer.go:468` — 3-retry per reservation; DLQ record includes reservation IDs (NEW-P0-001 fixed) |
| Fulfillment cancelled → CancelOrder (with reservation release) | ✅ | `fulfillment_consumer.go:143` |
| DLQ retry: void_authorization | ✅ | |
| DLQ retry: release_reservations | ✅ | **Fixed (NEW-P0-001)**: reads `reservation_ids` from `CompensationMetadata`; fallback to AuthorizationID with warning |
| DLQ retry: refund | ✅ | |
| DLQ retry: payment_capture | ✅ | |
| DLQ retry: refund_restock | ✅ | `dlq_retry_worker.go:183` |
| DLQ retry: alert on exhaustion | ✅ | `triggerAlert` + `alertService` |
| Outbox worker: PROCESSING mark | ✅ | Line 118 |
| Outbox worker: max 10 retries | ✅ | Line 135 |
| Outbox worker: 30-day cleanup | ✅ | `CleanupOldEvents` every 10 cycles |
| Webhook idempotency | ✅ | Redis state machine in payment service |
| Event consumer idempotency | ✅ | `IdempotencyHelper.CheckAndMark` in payment + fulfillment consumers |
| Fulfillment status backward guard | ✅ | `constants.IsLaterStatus` check at line 170 |
| ConfirmOrderReservations rollback | ✅ | `create.go:352-358` — rolls back already-confirmed reservations on partial failure |
| `publishStockCommittedEvent` (outbox) | ✅ | `create.go:373-409` — saves `inventory.stock.committed` outbox event after confirmation |

---

## 📋 GitOps Config Checks

### Order Worker (`gitops/apps/order/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: order-worker` + `app-port: 5005` + `grpc` | ✅ |
| `livenessProbe` + `readinessProbe` + `startupProbe` | ✅ Present (HTTP `:8019`) — ⚠️ verify HTTP server exists |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: order-secrets` | ✅ |
| `resources: requests + limits` | ✅ |
| `revisionHistoryLimit: 1` | ✅ Present at line 13 |
| `configFile volumeMount` | ✅ Volume + volumeMount at lines 91-98 (`/app/configs/config.yaml`) |
| `initContainers` | ✅ consul + redis + postgres health checks |

---

## 📋 Data Consistency Matrix

| Data Pair | Consistency Level | Risk |
|-----------|-----------------|------|
| Order DB ↔ Outbox events | ✅ Atomic (same TX) | Event loss extremely unlikely |
| Order status ↔ Payment status | ✅ Eventually consistent | `payment.confirmed` → order confirmed via event |
| Order status ↔ Fulfillment status | ✅ Eventually consistent | Via `fulfillment.status_changed` consumer |
| Warehouse reservation ↔ Order item | ⚠️ Reservation created before order (race OR-P0-03) | Orphaned reservations on order TX failure — mitigated by TTL + `ReservationCleanupWorker` |
| Warehouse stock deducted ↔ Order paid | ✅ Fixed (NEW-P0-002) | `processPaymentConfirmed` now calls `ConfirmOrderReservations`; partial-confirm rollback in place |
| DLQ compensation ↔ Reservation IDs | ✅ Fixed (NEW-P0-001) | `writeWarehouseDLQ` loads + saves `reservation_ids` in metadata |
| COD order lifecycle ↔ Customer reachability | ⚠️ Filter exists but no auto-cancel for expired (NEW-P1-002) | Old COD orders skip confirm but stay `pending` — never cancelled |
| Outbox event payload ↔ DB schema | ⚠️ `OrderStatusChangedEvent` contains all items (Risk 1 from last review) | Schema change → deserialization failures in consumers |

---

## 📋 Edge Cases Not Yet Handled

| Edge Case | Risk | Recommendation |
|-----------|------|----------------|
| Payment confirmed event arrives twice (duplicate from payment gateway) | 🔴 High | Idempotency check uses `DeriveEventID("payment_confirmed", orderID)` → order-level idempotency. ✅ Safe. |
| Payment confirmed arrives while order is already "cancelled" (race cancel/confirm) | 🟡 High | `UpdateOrderStatus` validates transition; "confirmed" from "cancelled" not allowed. ✅ Safe. |
| COD order, delivery collected, `delivery.confirmed` webhook never arrives | 🟡 High | Add `shipped` → `delivered` auto-complete cron after N-day delivery window (Shopee: +5 days after shipped). |
| Order has items from 2+ warehouses; one warehouse reservation expires | 🟡 High | `HandleReservationExpired` uses `UpdateOrderStatus → "cancelled"` which cancels the ENTIRE order (not just one item). ✅ Correct. |
| `processPaymentFailed` → release → all fail → DLQ → outbox → infinite retry loop? | 🔴 High | DLQ uses `compensation.reservation_release` topic (not `payment.failed`). ✅ No loop. Safe. |
| Order with promo applied; order cancelled → promo usage not restored | 🔵 Medium | No reversal event found. Promotion service integration needed. |
| Partial fulfillment: only 2 of 3 items shipped → order marked "shipped" prematurely | 🟡 High | FUL-P0-01 (multi-warehouse fulfilment aggregation) still open in fulfillment service review. |
| Capture payment fails with auth expiry; order stuck in `pending` | 🟡 High | DLQ record created (`payment_capture` op type). Order not auto-cancelled — Ops must trigger after DLQ alert. |
| `refund.completed` → `returnStockToInventory` fails → DLQ written → `refund_restock` op; metadata must include `product_id`, `warehouse_id`, `quantity` | 🟡 High | Verify return service `writeRefundRestockDLQ` populates all 3 fields. |
| `ReserveStockWithTTL` fails → fallback to `ReserveStock` (no TTL) in `reservation.go:35-40` | 🟡 High | If fallback branch is hit, reservation has no TTL → orphaned forever on order failure. Should fail-fast instead of silently dropping TTL. |

---

## 🔧 Remediation Actions

### 🔴 Fix Now (Data Loss / Financial Risk) — ALL DONE ✅

- [x] **NEW-P0-001**: `payment_consumer.go:writeWarehouseDLQ` — loads order items, populates `CompensationMetadata["reservation_ids"]`
- [x] **NEW-P0-002**: `payment_consumer.go:processPaymentConfirmed` — calls `uc.ConfirmOrderReservations`; DLQ on failure
- [x] **OR-P0-04**: Stripe webhook signature validation via `stripe.ValidateWebhookSignature`

### 🟡 Fix Soon (Reliability) — ALL DONE ✅

- [x] **OR-P0-03**: Accepted risk — TTL + worker safety net documented at `create.go:210-219`
- [x] **NEW-P1-001**: `worker-deployment.yaml:70-87` — all 3 probes changed from HTTP `:8019` (nonexistent server) to `grpc: port: 5005` (actual Dapr app port)
- [x] **NEW-P1-002**: `cod_auto_confirm.go` — two-pass refactor: confirm orders within 24h window; auto-cancel orders past window with reason `cod_confirmation_window_expired` via `CancelOrder`
- [x] **NEW-P1-003**: `payment_consumer.go:468` — 3-retry with 100ms backoff per reservation release
- [x] **DLQ Drain**: 6 DLQ drain consumers registered; topic names from constants; pubsub from `constants.DaprDefaultPubSub`
- [x] **DLQ Topic drift**: DLQ drain topic names now derived via `fmt.Sprintf("%s.dlq", constants.TopicXxx)`

### 🟡 Related Issues Found & Fixed (2026-02-23)

- [x] **DLQ-SHIPPING-TOPIC**: `event_worker.go` DLQ drain used `constants.TopicDeliveryConfirmed` (= `"shipping.delivery.confirmed"`) for slot 6, but `ConsumeShipmentDelivered` subscribes to `"shipping.shipment.delivered"`. Drain was registering against a phantom topic. Fixed: slot 6 now uses `constants.TopicShipmentDelivered`.
- [x] **SHIPPING-CONSTANT**: `shipping_consumer.go:76` used barestring `"shipping.shipment.delivered"` — added `constants.TopicShipmentDelivered` and updated both `AddConsumerWithMetadata` and `CheckAndMark` calls to reference it.
- [x] **RESERVATION-TTL-FALLBACK**: `reservation.go:35-40` silently fell back to `ReserveStock` (no TTL) on `ReserveStockWithTTL` failure — orphaned reservations never expired. Removed the fallback; both service/client branches now fail-fast with rollback if TTL reservation fails.

### 🔵 Monitor / Document

- [ ] Verify `HandleReservationExpired` path — confirmed it calls `UpdateOrderStatus → "cancelled"` for full-order cancel ✅ (verified); document in service doc
- [ ] Verify return service `writeRefundRestockDLQ` includes `product_id`, `warehouse_id`, `quantity` in metadata
- [ ] Add `GOT_DELIVERED_AT` auto-complete cron: if order is `shipped` and N days have passed → auto-complete (Shopee pattern)
- [ ] Revert promotion usage counter on order cancellation/refund (Promotion service integration)
- [ ] Add SLO alert: `pending outbox events > 100 AND age > 5m` → PagerDuty (DLQ backlog alert)
- [ ] Document DLQ replay procedure for Ops (reservation release via `compensation_metadata`)
- [ ] Fix `reservation.go:35-40` — remove silent TTL fallback to `ReserveStock`; fail-fast if `ReserveStockWithTTL` not available instead

---

## ✅ What Is Working Well

| Area | Notes |
|------|-------|
| Transactional outbox | All status changes use `tm.WithTransaction + outboxRepo.Save` |
| Saga compensation | 5 compensation types in DLQ retry worker with exponential backoff |
| Idempotency | `IdempotencyHelper.CheckAndMark` on payment + fulfillment consumers |
| Status transition guard | `canTransitionTo` prevents invalid state changes |
| Fulfillment cancelled → CancelOrder | Uses `CancelOrder()` (not just `UpdateStatus`) → reservation release + retry + DLQ |
| Backward status guard | `constants.IsLaterStatus` prevents status regression |
| COD payment capture skip | COD orders correctly skip the payment capture path |
| Auth expiry guard | `HandlePaymentCaptureRequested` fails fast if order is too old |
| Auth amount guard | Capture uses authoritative DB amount, not event amount (M-4 pattern) |
| DLQ alert on exhaustion | `triggerAlert` fires after `MaxRetries` → Ops email |
| Outbox cleanup | 30-day retention auto-cleanup every 10 cycles |
| Payment webhook idempotency | Redis state machine prevents double-processing |
| Stock committed event | `ConfirmOrderReservations` saves `inventory.stock.committed` outbox event |
| Partial confirm rollback | `ConfirmOrderReservations` rolls back already-confirmed reservations on failure |
| ReservationExpired → full cancel | `processReservationExpired` cancels entire order, not just one item |
| DLQ drain consumers | 6 DLQ drain handlers prevent Redis backpressure on exhausted topics |
| Worker health probes | `livenessProbe`, `readinessProbe`, `startupProbe` present + `revisionHistoryLimit: 1` |

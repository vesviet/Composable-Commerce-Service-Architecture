# Order Lifecycle Flows — Business Logic Review Checklist

**Date**: 2026-02-24 | **Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `order/`, `fulfillment/`, `payment/`, `warehouse/`, `shipping/`, `return/` — event coordination, saga, outbox, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §6 (Order Lifecycle)

---

## 📊 Summary

| Category | Status |
|----------|--------|
| 🔴 P0 — Critical (data loss / financial risk) | **ALL 6 FIXED** ✅ + **2 NEW OPEN** 🔴 |
| 🟡 P1 — High (reliability) | **6 FIXED** ✅ + **6 NEW OPEN** 🟡 |
| 🔵 P2 — Medium (edge case / observability) | **7 open (monitor/document)** |
| ✅ Verified Working | 34 areas |

---

## ✅ Previously Fixed (All Prior P0s + All Prior P1s)

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
| COD pagination | COD auto-confirm used unbounded cursor | ✅ Offset-based pagination with `batchSize=100` |
| Outbox worker PROCESSING | No atomic PROCESSING mark | ✅ `outbox/worker.go:118-122` marks PROCESSING before publish |
| **NEW-P0-001** | `writeWarehouseDLQ` did not save reservation IDs | ✅ `payment_consumer.go:533-547` loads order items, populates `metadata["reservation_ids"]` before `failedCompensationRepo.Create` |
| **NEW-P0-002** | `processPaymentConfirmed` never called `confirmOrderReservations` | ✅ `payment_consumer.go:418` calls `c.orderUc.ConfirmOrderReservations(ctx, ord)` |
| **OR-P0-04** | Stripe webhook signature validation missing | ✅ `payment/internal/biz/gateway/stripe.go` — `stripe.ValidateWebhookSignature` added |
| **NEW-P1-001** | Worker health probes used HTTP `:8019` (no HTTP server in binary) | ✅ `gitops/apps/order/base/worker-deployment.yaml` — all 3 probes switched to `grpc: port: 5005` |
| **NEW-P1-002** | COD auto-confirm had no auto-cancel for expired orders | ✅ `cod_auto_confirm.go` — two-pass refactor: confirm within 24h, cancel past window |
| **NEW-P1-003** | `releaseWarehouseReservations` had no retry logic | ✅ `payment_consumer.go:468` — 3-retry with 100ms backoff per reservation |
| **DLQ Drain topic drift** | DLQ drain consumer topics were hardcoded strings | ✅ `event_worker.go` — replaced with `fmt.Sprintf("%s.dlq", constants.TopicXxx)` |
| **DLQ-SHIPPING-TOPIC** | DLQ drain slot 6 used wrong topic `TopicDeliveryConfirmed` | ✅ Fixed: slot 6 now uses `constants.TopicShipmentDelivered` |
| **SHIPPING-CONSTANT** | `shipping_consumer.go:76` used bare string instead of constant | ✅ Added `constants.TopicShipmentDelivered` |
| **RESERVATION-TTL-FALLBACK** | `reservation.go:35-40` silently fell back to no-TTL reservation | ✅ Removed fallback; both branches now fail-fast |

---

## 🔴 New P0 Issues (This Review Cycle)

### P0-2024-01: Return Restock DLQ — operationType Mismatch

**Files**: `return/internal/biz/return/restock.go:76-87`, `order/internal/worker/cron/dlq_retry_worker.go:183`

**Problem**: `restockReturnedItems()` in the **return service** saves restock failures to its own **outbox as an event** (`return.restock_retry` event type). However, the **order service DLQ retry worker** (`dlq_retry_worker.go:183`) handles `refund_restock` as a `FailedCompensation` operation type — it reads from `order.failed_compensations` table (NOT from return service's outbox).

These are **two completely separate retry paths** that never converge:
- Return service: saves failures as outbox event `return.restock_retry` (who consumers this event?)
- Order service DLQ: retries `FailedCompensation.OperationType == "refund_restock"` which expects `product_id`, `warehouse_id`, `quantity` in `CompensationMetadata`

**Risk**: If a return restock fails, the `return.restock_retry` outbox event may have no subscriber that actually retries the warehouse call. The order DLQ `refund_restock` handler may never be triggered because the return service writes to its own outbox — not to `order.failed_compensations`.

**Resolution**:
- [ ] Verify what service/worker consumes `return.restock_retry` outbox events from return service — if none, items are silently skipped permanently
- [ ] Align retry paths: either (a) return service writes to `order.failed_compensations` via gRPC/event, or (b) return service has its own compensation worker that reads its outbox and retries warehouse calls

---

### P0-2024-02: Warehouse Worker Missing Health Probes and Secret Mount

**File**: `gitops/apps/warehouse/base/worker-deployment.yaml`

**Problem**: The warehouse worker deployment (lines 69-81) has **no liveness probe, no readiness probe, no startupProbe**, and **no `secretRef`** for `warehouse-secrets`. The warehouse service requires database credentials and OAuth secrets in production. Without probes, a crashed worker will never be restarted by K8s.

```yaml
# Missing in warehouse worker-deployment.yaml:
# - livenessProbe / readinessProbe (pod never restarted on crash)
# - secretRef: name: warehouse-secrets (no DB/API credential injection)
# - volumeMount for config.yaml (config loaded from flag, may fail)
```

**Resolution**:
- [ ] Add `livenessProbe` + `readinessProbe` (gRPC port 5005) matching other worker patterns
- [ ] Add `secretRef: name: warehouse-secrets` under `envFrom`
- [ ] Add `volumes` + `volumeMounts` for `warehouse-config` configMap (like shipping worker does)

---

## 🟡 New P1 Issues (This Review Cycle)

### P1-2024-01: Fulfillment Worker Missing `startupProbe` and Config VolumeMount

**File**: `gitops/apps/fulfillment/base/worker-deployment.yaml`

**Problem**: The fulfillment worker YAML (lines 63-74) has `livenessProbe` and `readinessProbe` on gRPC port 5005 ✅, but is missing:
1. `startupProbe` — without it, if the worker takes >30s to start (large DB schema checks), K8s kills it before it's ready  
2. `volumeMounts` + `volumes` for config file — other workers (shipping, order) explicitly mount `config.yaml`. Fulfillment passes `-conf /app/configs/config.yaml` but has no volume for it.

**Resolution**:
- [ ] Add `startupProbe` with `grpc: port: 5005`, `initialDelaySeconds: 5`, `failureThreshold: 30`, `periodSeconds: 5`
- [ ] Add config volume + mount (see shipping worker-deployment.yaml as template)

---

### P1-2024-02: Shipping `OrderCancelledConsumer` Missing Idempotency

**File**: `shipping/internal/data/eventbus/order_cancelled_consumer.go:68-84`

**Problem**: `HandleOrderCancelled` dispatches directly to `observerManager.Trigger()` with no idempotency check. If Dapr redelivers the event (network drop after handler completes but before ACK), the shipment cancellation will be attempted twice — potentially calling an external carrier API to cancel an already-cancelled shipment, resulting in error responses that may corrupt shipping state.

Compare with `PackageStatusConsumer` (same file, same pattern) which correctly uses `idempotencyHelper.CheckAndMark()`.

**Resolution**:
- [ ] Add `IdempotencyHelper` field to `OrderCancelledConsumer` (same as `PackageStatusConsumer`)
- [ ] Wrap `HandleOrderCancelled` body with `c.idempotencyHelper.CheckAndMark(ctx, eventID, ...)` where `eventID = DeriveEventID("order_cancelled", eventData.OrderID)`

---

### P1-2024-03: Fulfillment Service Has No Auto-Complete Cron for Shipped Orders

**Files**: `fulfillment/internal/worker/cron/provider.go` (stub only, no jobs)

**Problem**: The fulfillment cron directory contains only a `provider.go` stub with no actual cron jobs. Per the Shopee/Lazada pattern and the existing checklist TODO:

> "Add `GOT_DELIVERED_AT` auto-complete cron: if order is `shipped` and N days have passed → auto-complete"

Without this cron:
- Orders that ship but whose carrier webhook never arrives (or is delayed) remain stuck in `SHIPPED` state forever
- Escrow held indefinitely → seller never gets paid
- Customer never gets loyalty points / review invitation

**Resolution**:
- [ ] Implement `AutoCompleteShippedOrders` cron in `fulfillment/internal/worker/cron/`
- [ ] Query fulfillment records with status `shipped` AND `shipped_at < NOW() - N days` (configurable, default: 5 days Shopee / 7 days Lazada)
- [ ] For each: call `fulfillment.Complete()` → triggers `fulfillment.status_changed` event → order moves to `COMPLETED`
- [ ] Register cron in worker entrypoint

---

### P1-2024-04: Fulfillment `OrderStatusConsumer` subscribes to topic from config map key — Silent Miss on Key Mismatch

**File**: `fulfillment/internal/data/eventbus/order_status_consumer.go:48`

**Problem**:
```go
topic := c.config.Data.Eventbus.Topic["order_status_changed"]
```
The topic name is looked up from a **dynamic map key** `"order_status_changed"`. If this key is missing or misspelled in the ConfigMap, `topic` will be empty string `""`. When empty:
- `AddConsumerWithMetadata("", pubsub, ...)` will either silently succeed (subscribing to a phantom topic) or return an error that is swallowed (depending on Dapr client implementation)
- The fulfillment service SILENTLY stops receiving order status events → no fulfillment tasks created

By contrast, `picklist_status_consumer.go:46` uses `constants.TopicPicklistStatusChanged` (a named constant) which fails at compile time if renamed.

**Resolution**:
- [ ] Define `constants.TopicOrderStatusChanged` in `fulfillment/internal/constants/`
- [ ] Replace map key lookup with: `topic := constants.TopicOrderStatusChanged`
- [ ] Add a guard: if the topic still comes from config, `return fmt.Errorf(...)` (don't silently `return nil`) when topic is empty

---

### P1-2024-05: Warehouse Worker Missing `secretRef`

*See P0-2024-02 above — secretRef is part of that fix.*

---

### P1-2024-06: Fulfillment Picklist Consumer Missing Idempotency

**File**: `fulfillment/internal/data/eventbus/picklist_status_consumer.go:71`

**Problem**: `HandlePicklistStatusChanged` calls `observerManager.Trigger()` directly with no idempotency check. If Dapr redelivers the picklist status event, the observer may double-process a status change (e.g., marking a fulfilment "picked" twice), potentially causing a state regression if the downstream handler is not guarded.

Compare with `OrderStatusConsumer.HandleOrderStatusChanged` in the same service, which correctly uses `idempotencyHelper.CheckAndMark()`.

Note: `PicklistStatusConsumer` struct does not even have an `idempotencyHelper` field.

**Resolution**:
- [ ] Add `idempotencyHelper *IdempotencyHelper` field to `PicklistStatusConsumer`
- [ ] Inject via `NewPicklistStatusConsumer` constructor
- [ ] Wrap handler body with idempotency check: `eventID = DeriveEventID("picklist_status_changed", fmt.Sprintf("%s_%s", eventData.PicklistID, eventData.NewStatus))`

---

## 🔴 Remaining Open P0 Issues

### OR-P0-03: Stock Reservation Created Outside Order Transaction *(Accepted Risk)*

**File**: `order/internal/biz/order/create.go:77-134`, checkout flow caller

**Problem**: Cart checkout service creates stock reservations with the Warehouse service **before** calling `Order.CreateOrder`. The reservation gRPC call and the order DB insert are in separate network operations — there is no distributed atomic guarantee.

```
Checkout → Warehouse.CreateReservation (network) ← ORDER NOT CREATED YET
         ↓
         Order.CreateOrder (DB tx)
```

**Race scenario**: Warehouse reservation succeeds → order TX fails → reservation is stuck (no order will ever confirm or release it). Reservation TTL is the only safety net.

**Resolution**:
- [x] Option B (accepted): Treat reservation as optimistic — reconcile via `ReservationExpiredWorker` + heartbeat; acceptable if warehouse TTL is reliably enforced *(Decision documented at create.go:210-219)*

> **Status**: Option B formally accepted — `ReservationCleanupWorker` + TTL + `HandleReservationExpired` act as safety net. Tracked as known risk.

---

## 📋 Event Publishing Necessity Check

### Services That NEED to Publish (✅ Justified)

| Service | Event | Consumers | Justification |
|---------|-------|-----------|---------------|
| Order | `order.status.changed` | Fulfillment, Notification, Analytics, Loyalty, Customer | **Essential** — drives entire downstream order lifecycle |
| Order | `inventory.stock.committed` | Analytics, Reporting | **Essential** — stock audit trail |
| Order | `orders.payment.capture_requested` | Payment consumer (self-loop via Dapr) | **Essential** — async capture for auth-and-capture flow |
| Order | `order.cancelled` | Shipping (cancel shipments), Warehouse (release stock) | **Essential** |
| Payment | `payment.confirmed` | Order (confirm), Loyalty (points), Analytics | **Essential** |
| Payment | `payment.failed` | Order (cancel + release), Analytics | **Essential** |
| Payment | `payment.capture_failed` | Order (mark failed) | **Essential** |
| Fulfillment | `fulfillment.status_changed` | Order (status update), Warehouse (stock deduct) | **Essential** |
| Warehouse | `warehouse.inventory.reservation_expired` | Order (auto-cancel on TTL) | **Essential** — prevents ghost reservations |
| Return | `return.restock_retry` (outbox) | ⚠️ **No confirmed subscriber** — see P0-2024-01 | Risk: silent restock failure |

### Services That Subscribe But Might Not Need To (🔶 Review)

| Service | Subscription | Verdict |
|---------|-------------|---------|
| Order | `orders.payment.capture_requested` (self-loop) | ✅ Correct pattern for 2-step auth-capture; COD correctly skipped |
| Order | `warehouse.inventory.reservation_expired` | ✅ Correct — auto-cancels order when reservation TTL expires |
| Order | `shipping.shipment.delivered` | ✅ Correct — sets order status to "delivered" |
| Fulfillment | `shipment.delivered` | ✅ Correct — triggers fulfillment completion |
| Shipping | `order.cancelled` | ✅ Correct — cancels active shipments |

**No unnecessary subscriptions found.**

---

## 📋 Event Subscription Necessity Check

### Order Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `payment.confirmed` | `HandlePaymentConfirmed` | ✅ Yes — confirm order status, confirm reservations |
| `payment.failed` | `HandlePaymentFailed` | ✅ Yes — cancel order + release reservations (with retry) |
| `orders.payment.capture_requested` | `HandlePaymentCaptureRequested` | ✅ Yes — trigger async payment capture |
| `fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ Yes — drive order status through lifecycle |
| `warehouse.inventory.reservation_expired` | `HandleReservationExpired` | ✅ Yes — auto-cancel orders with expired stock |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ Yes — move order to "delivered" |
| `*.dlq` (6 topics) | DLQ drain (log + ACK) | ✅ Added — prevents Redis DLQ backpressure |

### Fulfillment Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `order.status.changed` | `HandleOrderStatusChanged` | ✅ Yes — create pick/pack tasks on PAID status |
| `fulfillment.picklist_status_changed` | `HandlePicklistStatusChanged` | ✅ Yes — advance fulfillment status |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ Yes — mark fulfillment complete |

> ⚠️ **Note**: Topic for `order.status.changed` is loaded via config map key (P1-2024-04 — risk of silent miss).

### Warehouse Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ Yes — deduct stock permanently on shipment |
| `order.status.changed` | `HandleOrderStatusChanged` | ✅ Yes — release reservation on cancellation |
| `return.completed` | `HandleReturnCompleted` | ✅ Yes — restock returned items |
| `catalog.product.created` | `HandleProductCreated` | ✅ Yes — init stock record |

> ⚠️ **Note**: Warehouse subscribes to `order.status.changed` via config map key `Topic.OrderStatusChanged` — same risk as fulfillment (silent miss if key absent).

### Shipping Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `fulfillment.package_status_changed` | `HandlePackageStatusChanged` | ✅ Yes — update shipping shipment status |
| `order.cancelled` | `HandleOrderCancelled` | ✅ Yes — cancel active shipments |

---

## 📋 Worker & Cron Job Checks

### Order Worker (`order/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | 1s poll, 50 events/batch, atomic PROCESSING mark, 10 retries, 30-day cleanup |
| **EventConsumersWorker** | ✅ Yes | payment/fulfillment/warehouse/shipping consumers + 6 DLQ drain handlers |
| **DLQRetryWorker** | ✅ Yes | 5m interval, 5 operation types, exponential backoff, alert on exhaustion |
| **CODAutoConfirmJob** | ✅ Yes | 1m interval, offset pagination, 24h confirm + expired auto-cancel |
| **PaymentCompensationWorker** | ✅ Yes | `cron/payment_compensation.go` — retry stuck payment captures |
| **CaptureRetryWorker** | ✅ Yes | `cron/capture_retry.go` — retry failed payment captures |
| **ReservationCleanupWorker** | ✅ Yes | `cron/reservation_cleanup.go` — release expired reservations |
| **OrderCleanupWorker** | ✅ Yes | `cron/order_cleanup.go` — clean abandoned/stale orders |
| DLQ consumers (subscribers) | ✅ Yes | 6 DLQ drain handlers registered in `event_worker.go:82-101` |

### Fulfillment Worker (`fulfillment/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | Outbox pattern for fulfillment status events |
| **OrderStatusConsumerWorker** | ✅ Yes | Registered in `event_workers.go:46-70` |
| **PicklistStatusConsumerWorker** | ✅ Yes | Registered in `event_workers.go:72-102` |
| **ShipmentDeliveredConsumerWorker** | ✅ Yes | Registered in `event_workers.go:104-134` |
| **SLA Breach / Auto-Complete Cron** | ❌ **MISSING** | `cron/` dir has only stub `provider.go` — see P1-2024-03 |

### Warehouse Worker (`warehouse/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | `worker/outbox_worker.go` |
| **FulfillmentStatusConsumerWorker** | ✅ Yes | Idempotency applied |
| **OrderStatusConsumerWorker** | ✅ Yes | Idempotency applied |
| **ReturnConsumerWorker** | ✅ Yes | `return_consumer.go` present |
| **ExpiryWorker** | ✅ Yes | `worker/expiry/` — reservation TTL enforcement |
| **Stock Import Worker** | ✅ Yes | `worker/import_worker.go` |
| **Cron Jobs** | ✅ Yes | `worker/cron/` — 10 files (replenishment, alerts, etc.) |

### Shipping Worker (`shipping/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | `worker/outbox_worker.go` |
| **PackageStatusConsumerWorker** | ✅ Yes | Idempotency applied |
| **OrderCancelledConsumerWorker** | ✅ Yes | Registered in `worker/event/order_cancelled_consumer.go` |
| **Idempotency on OrderCancelled** | ❌ **MISSING** | `HandleOrderCancelled` has no `idempotencyHelper` — see P1-2024-02 |

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
| DLQ retry: refund_restock | ⚠️ | Retry path in order DLQ exists, but return service writes outbox instead — **paths may not connect** (P0-2024-01) |
| DLQ retry: alert on exhaustion | ✅ | `triggerAlert` + `alertService` |
| Outbox worker: PROCESSING mark | ✅ | Line 118 |
| Outbox worker: max 10 retries | ✅ | Line 135 |
| Outbox worker: 30-day cleanup | ✅ | `CleanupOldEvents` every 10 cycles |
| Webhook idempotency | ✅ | Redis state machine in payment service |
| Event consumer idempotency (order) | ✅ | `IdempotencyHelper.CheckAndMark` in payment + fulfillment consumers |
| Event consumer idempotency (warehouse) | ✅ | Applied on all warehouse consumers |
| Event consumer idempotency (shipping package) | ✅ | Applied |
| Event consumer idempotency (shipping order_cancelled) | ❌ | **MISSING** — P1-2024-02 |
| Event consumer idempotency (fulfillment picklist) | ❌ | **MISSING** — P1-2024-06 |
| Fulfillment status backward guard | ✅ | `constants.IsLaterStatus` check at line 170 |
| ConfirmOrderReservations rollback | ✅ | `create.go:352-358` — rolls back already-confirmed reservations on failure |
| `publishStockCommittedEvent` (outbox) | ✅ | `create.go:373-409` — saves `inventory.stock.committed` outbox event after confirmation |

---

## 📋 GitOps Config Checks

### Order Worker (`gitops/apps/order/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: order-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` + `startupProbe` on gRPC :5005 | ✅ Fixed (was HTTP :8019) |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: order-secrets` | ✅ |
| `resources: requests + limits` | ✅ |
| `revisionHistoryLimit: 1` | ✅ |
| `configFile volumeMount` | ✅ Volume + volumeMount at `/app/configs/config.yaml` |
| `initContainers` (consul + redis + postgres health checks) | ✅ |

### Fulfillment Worker (`gitops/apps/fulfillment/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: fulfillment-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` on gRPC :5005 | ✅ |
| `startupProbe` | ❌ **MISSING** — P1-2024-01 |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: fulfillment-secrets` | ✅ |
| `resources: requests + limits` | ✅ |
| `configFile volumeMount` | ❌ **MISSING** — config volume not mounted — P1-2024-01 |
| `revisionHistoryLimit: 1` | ✅ |
| `initContainers` | ✅ consul + redis + postgres |

### Shipping Worker (`gitops/apps/shipping/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: shipping-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` on gRPC :5005 | ✅ |
| `startupProbe` | ❌ **MISSING** |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: shipping-secrets` | ✅ |
| `resources: requests + limits` | ✅ |
| `configFile volumeMount` | ✅ `shipping-config` mounted at `/app/configs` |
| `revisionHistoryLimit: 1` | ✅ |
| `initContainers` | ✅ consul + redis + postgres |

### Warehouse Worker (`gitops/apps/warehouse/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: warehouse-worker` + `app-port: 5005 (grpc)` | ✅ |
| `livenessProbe` + `readinessProbe` | ❌ **MISSING** — P0-2024-02 |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: warehouse-secrets` | ❌ **MISSING** — P0-2024-02 |
| `resources: requests + limits` | ✅ |
| `configFile volumeMount` | ❌ **MISSING** — volume defined but not mounted to container |
| `revisionHistoryLimit: 1` | ✅ |
| `initContainers` | ✅ consul + redis + postgres |

---

## 📋 Data Consistency Matrix — Full Cross-Service

| Data Pair | Consistency Level | Risk |
|-----------|-----------------|------|
| Order DB ↔ Outbox events | ✅ Atomic (same TX) | Event loss extremely unlikely |
| Order status ↔ Payment status | ✅ Eventually consistent | `payment.confirmed` → order confirmed via event |
| Order status ↔ Fulfillment status | ✅ Eventually consistent | Via `fulfillment.status_changed` consumer |
| Warehouse reservation ↔ Order item | ⚠️ Race (OR-P0-03 — accepted) | Orphaned reservations on order TX failure — mitigated by TTL + `ReservationCleanupWorker` |
| Warehouse stock ↔ Order paid | ✅ Fixed (NEW-P0-002) | `processPaymentConfirmed` → `ConfirmOrderReservations`; partial-confirm rollback |
| DLQ compensation ↔ Reservation IDs | ✅ Fixed (NEW-P0-001) | `writeWarehouseDLQ` saves `reservation_ids` |
| COD order lifecycle ↔ Time window | ✅ Fixed (NEW-P1-002) | Two-pass: confirm within window, cancel past window |
| Return restock ↔ Warehouse stock | ⚠️ Retry path unclear | `return.restock_retry` outbox event has no verified subscriber — see P0-2024-01 |
| Fulfillment topic ↔ Config key | ⚠️ Config map drift | Empty topic silently stops fulfillment creation — P1-2024-04 |
| Shipping OrderCancelled ↔ Duplicate events | ⚠️ No idempotency guard | Double-cancel may hit external carrier API — P1-2024-02 |

---

## 📋 Edge Cases Not Yet Handled

| Edge Case | Risk | Recommendation |
|-----------|------|----------------|
| COD order, delivery collected, `delivery.confirmed` webhook never arrives | 🟡 High | Add `shipped` → `completed` auto-complete cron in fulfillment after N-day window (P1-2024-03) |
| Order has items from 2+ warehouses; partial fulfilment — one item shipped, others not | 🟡 High | `FUL-P0-01` multi-warehouse fulfilment aggregation still open in fulfillment service review. Order marked "shipped" when first item ships = incorrect |
| Capture payment fails with auth expiry; order stuck in `pending_capture` | 🟡 High | DLQ record created (`payment_capture` op type). Order not auto-cancelled — Ops must trigger after DLQ alert |
| `refund.completed` → `returnStockToInventory` fails → `return.restock_retry` outbox event with no subscriber | 🔴 High | P0-2024-01 — verify or implement consumer for `return.restock_retry` |
| Promotion usage not reverted on order cancellation / refund | 🔵 Medium | No reversal event found. Promotion service integration needed |
| Order with loyalty points redeemed; order cancelled → points not restored | 🔵 Medium | Loyalty service must consume `order.cancelled` to restore redeemed points |
| Fulfillment cron never auto-completes shipped orders → seller escrow never released | 🟡 High | P1-2024-03 — implement auto-complete cron |
| `HandleOrderStatusChanged` in fulfilment/warehouse gets empty topic string → silent no-subscription | 🟡 High | P1-2024-04 — replace dynamic config map key lookup with named constant |
| Dapr redelivers `order.cancelled` to shipping → double carrier API cancel call | 🟡 Medium | P1-2024-02 — add idempotency to `OrderCancelledConsumer` |
| `OrderStatusChangedEvent` payload schema changes → deserialization failures in downstream consumers | 🔵 Medium | Schema versioning / graceful unknown-field handling needed |
| SLA breach: seller doesn't ship within 24h → no auto-escalation | 🔵 Medium | No SLA breach cron in fulfillment; manual ops alert only |

---

## 📋 Remediation Actions

### 🔴 Fix Now (Data Loss / Financial Risk)

- [ ] **P0-2024-01**: Return restock retry path — verify `return.restock_retry` outbox event consumer exists; if not, implement or redirect to `order.failed_compensations`
- [ ] **P0-2024-02**: Warehouse worker GitOps — add `livenessProbe`, `readinessProbe`, `secretRef: name: warehouse-secrets`, config volumeMount to `gitops/apps/warehouse/base/worker-deployment.yaml`

### 🟡 Fix Soon (Reliability)

- [ ] **P1-2024-01**: Fulfillment worker GitOps — add `startupProbe` (gRPC :5005) + config volumeMount to `gitops/apps/fulfillment/base/worker-deployment.yaml`
- [ ] **P1-2024-02**: Shipping `OrderCancelledConsumer` — add `idempotencyHelper` field + `CheckAndMark` wrap in `HandleOrderCancelled`
- [ ] **P1-2024-03**: Fulfillment — implement `AutoCompleteShippedOrders` cron for N-day `shipped` → `completed` auto-completion
- [ ] **P1-2024-04**: Fulfillment `OrderStatusConsumer` — replace config map key lookup `c.config.Data.Eventbus.Topic["order_status_changed"]` with `constants.TopicOrderStatusChanged`; fail-fast if empty (same for warehouse `OrderStatusConsumer`)
- [ ] **P1-2024-05**: Shipping worker GitOps — add `startupProbe` to `gitops/apps/shipping/base/worker-deployment.yaml`
- [ ] **P1-2024-06**: Fulfillment `PicklistStatusConsumer` — add `idempotencyHelper` field + `CheckAndMark` wrap in `HandlePicklistStatusChanged`

### 🔵 Monitor / Document

- [ ] Verify `HandleReservationExpired` cancels whole order correctly — ✅ confirmed; document in service doc
- [ ] Add `GOT_DELIVERED_AT` auto-complete cron (linked to P1-2024-03)
- [ ] Revert promotion usage counter on order cancellation/refund (Promotion service integration)
- [ ] Restore loyalty points on order cancellation (Loyalty service — consume `order.cancelled`)
- [ ] Add SLO alert: `pending outbox events > 100 AND age > 5m` → PagerDuty
- [ ] Document DLQ replay procedure for Ops (reservation release via `compensation_metadata`)
- [ ] Schema versioning for `OrderStatusChangedEvent` payload to avoid cross-service deserialization breaks
- [ ] SLA breach escalation cron in fulfillment (seller > 24h without shipping → notification/penalty)

---

## ✅ What Is Working Well

| Area | Notes |
|------|-------|
| Transactional outbox | All status changes use `tm.WithTransaction + outboxRepo.Save` |
| Saga compensation | 5 compensation types in DLQ retry worker with exponential backoff |
| Idempotency (order/warehouse) | `IdempotencyHelper.CheckAndMark` on payment + fulfillment consumers + warehouse consumers |
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
| Order worker health probes | `livenessProbe`, `readinessProbe`, `startupProbe` present on gRPC :5005 |
| Reservation TTL fail-fast | `ReserveStockWithTTL` no longer silently falls back to no-TTL reservation |
| Return restock exchange guard | Exchange returns correctly skip restock (E-23: stock managed via new exchange order) |
| Warehouse expiry worker | Reservation TTL enforced by dedicated expiry worker in `warehouse/internal/worker/expiry/` |

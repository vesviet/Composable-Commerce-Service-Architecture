# Fulfillment & Shipping Flows — Deep Business Logic Review v2

**Date**: 2026-02-26
**Reviewer**: Antigravity Agent
**Pattern Reference**: Shopify, Shopee, Lazada — `docs/10-appendix/ecommerce-platform-flows.md` §9
**Services Reviewed**: `fulfillment/`, `shipping/`
**Previous Review**: `fulfillment-shipping-flow-checklist.md` (2026-02-23) — all prior issues marked resolved.
**Scope**: Fresh review against actual code to verify current state & surface remaining/new risks.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented correctly |
| ⚠️ | Risk / partial — needs attention |
| ❌ | Missing / broken |
| 🔴 | P0 — blocks production |
| 🟡 | P1 — reliability risk |
| 🔵 | P2 — improvement / cleanup |

---

## 1. Data Consistency — Kiểm tra nhất quán dữ liệu giữa các service

### 1.1 Fulfillment ↔ Warehouse

| Check | Status | Notes |
|-------|--------|-------|
| Reservation validation (`active` check) before creating fulfillment | ✅ | `fulfillment_lifecycle.go:76-86` |
| `ConfirmReservation` called when picklist completed (stock deducted once) | ✅ | Confirmed by previous review |
| `AdjustStock` for unpicked qty after partial pick | ✅ | |
| **cancellation path — AdjustStock failure is now fatal (rolls back tx)** | ✅ | `fulfillment_lifecycle.go:292-298` — error returned → tx rollback ✅ |
| **Shipping address stored in metadata (JSONB), not a proper FK** | ⚠️ | `fulfillment_lifecycle.go:162-164` — marshalled to JSON string; if address service changes schema, it silently corrupts; no version field |

### 1.2 Fulfillment → Shipping

| Check | Status | Notes |
|-------|--------|-------|
| `ShipFulfillment` calls shipping gRPC to create shipment | ⚠️ **P0** | `fulfillment_dispatch.go:300-317` — hardcoded `Carrier: "UPS"`, `ServiceType: "Ground"`. Real carrier/service should come from order metadata or shipping method selection. This means ALL shipments use UPS Ground regardless of what customer selected. |
| OrderID / FulfillmentID type mismatch between Fulfillment (UUID string) and Shipping (int64) | 🔴 **P0** | `fulfillment_dispatch.go:302-308` — commented out with `FIXME: ID type mismatch`. Fields `OrderId`, `FulfillmentId`, `CustomerId` are **never set** in the gRPC request. Shipping service receives no order/fulfillment ID correlation. |
| Shipment ID stored in fulfillment metadata (not a typed field) | ⚠️ **P1** | `fulfillment_dispatch.go:357` — `fulfillment.Metadata["shipment_id"]` — if metadata is evicted or overwritten, correlation is lost. No FK, no index. |
| `ConfirmDelivery` hard-codes `StatusOutForDelivery` as previous status in status-changed event | ⚠️ **P1** | `confirm_delivery.go:97` — always saves `StatusOutForDelivery` as old status, even if actual previous was `StatusShipped`. If POD captured directly from `shipped`, event carries wrong old status. |

### 1.3 Shipping → Fulfillment (callback)

| Check | Status | Notes |
|-------|--------|-------|
| `HandlePackageShipped` reads `package_id` from metadata (not typed field) | ⚠️ **P1** | `package_shipped_handler.go:16-19` — if metadata key is missing, silently returns nil without updating package status. |
| `compensatePackageShipped` reverts to `StatusProcessing` hardcoded | ⚠️ **P1** | `package_shipped_handler.go:89` — saga compensation does not track previous status; always reverts to `processing` even if shipment was `ready`. |
| `CancelShipmentsForOrder` for multi-shipment: partial failure returns last error only | ⚠️ **P1** | `order_cancelled_handler.go:51-56` — loop continues on error, final `cancelErr` is only last error. Earlier shipments may be cancelled while later ones are not. No rollback of already-cancelled ones. |

### 1.4 Fulfillment Data Integrity — Multi-warehouse COD

| Check | Status | Notes |
|-------|--------|-------|
| `computeProRataCOD` distributes COD proportionally by item value | ✅ | `fulfillment_dispatch.go:394-457` — correct implementation with rounding remainder to last warehouse |
| If all items have `TotalPrice = 0` (free products + COD), COD is assigned to "first" warehouse | ⚠️ **P2** | `fulfillment_dispatch.go:422-430` — fallback assigns to alphabetically-first warehouse. Edge case that can happen with promo-discounted products. |

---

## 2. Data Mismatches — Các trường hợp dữ liệu bị lệch (Mismatched)

### M1 🔴 P0: Fulfillment→Shipping gRPC: OrderID/FulfillmentID not passed

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_dispatch.go:300-317`
```go
// OrderId: 0,      // ← NOT SET
// FulfillmentId: 0, // ← NOT SET
// CustomerId: 0,    // ← NOT SET
Carrier: "UPS",      // hardcoded
```
**Risk**: The Shipping service has no way to correlate a `Shipment` record back to the originating `Order` or `Fulfillment` by typed ID fields. All cross-service queries rely on `metadata["fulfillment_id"]` if it exists, or are totally disconnected. Event payloads in shipping that carry `fulfillment_id`/`order_id` are only populated at event creation time from the struct, not the DB FK.

### M2 🔴 P0: Hardcoded Carrier "UPS" in ShipFulfillment

**File**: `fulfillment_dispatch.go:310`
All orders are shipped via UPS Ground regardless of shipping method selected at checkout. This is arguably the most critical business logic gap — customers who paid for Express or Same-Day shipping receive Ground.

### M3 🟡 P1: `ConfirmDelivery` saves wrong oldStatus in event

**File**: `shipping/internal/biz/shipment/confirm_delivery.go:97`
```go
if err := uc.saveShipmentStatusChangedEvent(txCtx, shipment, StatusOutForDelivery.String()); err != nil {
```
The old status is hardcoded as `StatusOutForDelivery`. If the shipment transitioned `Shipped → Delivered` without going through `OutForDelivery` (e.g., express courier with no intermediate scan), the event emits an incorrect `previous_status`. Consumers (order, analytics) that track state transitions will see phantom states.

### M4 🟡 P1: `handleOrderCancelled` in fulfillment queries only one fulfillment per order

**File**: `fulfillment_lifecycle.go`, `order_status_handler.go:136`
```go
fulfillment, err := uc.repo.FindByOrderID(ctx, event.OrderID)
```
`FindByOrderID` returns a single fulfillment. Multi-warehouse orders have **multiple fulfillments per order**. Only the first is cancelled. Other fulfillments remain in active state, leading to ghost fulfillments stuck in picking/packing.

---

## 3. Cơ chế Retry / Rollback / Saga / Outbox

### 3.1 Fulfillment — Outbox

| # | Check | Status | Notes |
|---|-------|--------|-------|
| O1 | Events written to outbox inside `InTx` | ✅ | `fulfillment_lifecycle.go:176-181` — `outbox_publisher.go:saveToOutbox` called within `InTx` closure |
| O2 | `commonOutbox.Worker` polls and dispatches to Dapr | ✅ | `cmd/worker/wire.go:55,72` — `outboxWorker` registered |
| O3 | Outbox topic = `eventType` (not `aggregateType`) | ✅ | `outbox_publisher.go:40` — `EventType` field used as topic; correct |
| O4 | **Outbox worker is NOT listed in `newWorkers()` for fulfillment's SLABreachDetectorJob** | ⚠️ **P1** | Wire `newWorkers()` does NOT include `SLABreachDetectorJob`. The cron job is missing from the wired workers list. |

**Evidence — `fulfillment/cmd/worker/wire.go:50-76`**:
```go
func newWorkers(
    eventbusClient commonEvents.ConsumerClient,
    orderStatusConsumer eventbus.OrderStatusConsumer,
    picklistStatusConsumer eventbus.PicklistStatusConsumer,
    shipmentDeliveredConsumer eventbus.ShipmentDeliveredConsumer,
    outboxWorker *commonOutbox.Worker,
    autoCompleteShippedWorker *workerCron.AutoCompleteShippedWorker,
    // ← SLABreachDetectorJob NOT INCLUDED
    logger log.Logger,
) []worker.ContinuousWorker {
```
`SLABreachDetectorJob` is declared in `internal/worker/cron/sla_breach_detector.go` and has a `NewSLABreachDetectorJob` constructor, but it is **never injected** into `newWorkers()`. The SLA breach detection cron **never runs in production**.

### 3.2 Shipping — Outbox

| # | Check | Status | Notes |
|---|-------|--------|-------|
| O5 | Outbox worker polls every 5s, batch 20 | ✅ | `outbox_worker.go:33` |
| O6 | MaxRetries=5 with exponential backoff | ✅ | `outbox_worker.go:99` |
| O7 | Failed events marked FAILED permanently | ✅ | `outbox_worker.go:145` |
| O8 | Prometheus metrics for events processed/failed | ✅ | `outbox_worker.go:82-96` |
| O9 | `topicMapping` in `dapr_event_bus.go` maps `"shipment.assigned"` → `TopicShipmentCreated` | ⚠️ **P2** | `dapr_event_bus.go:29` — `shipment.assigned` maps to `TopicShipmentCreated` which is a *different* semantic event. Consumers subscribing to `shipment.created` will unexpectedly receive assignment events. |
| O10 | **Shipping OutboxWorker does NOT implement `ContinuousWorker` interface** | ⚠️ **P1** | `shipping/internal/worker/outbox_worker.go` — struct has `Run(ctx)` method but does NOT embed `*worker.BaseContinuousWorker` and does not implement `Name()`, `Start()`, `Stop()`, `HealthCheck()`, `GetBaseWorker()`. It is NOT registered in `shipping/cmd/worker/wire.go:newWorkers()` at all. |

**Evidence — `shipping/cmd/worker/wire.go:79-89`**:
```go
func newWorkers(
    packageStatusConsumerWorker *event.PackageStatusConsumerWorker,
    orderCancelledConsumerWorker *event.OrderCancelledConsumerWorker,
    eventbusServerWorker *event.EventbusServerWorker,
    // ← OutboxWorker NOT INCLUDED!
) []worker.ContinuousWorker {
```
The `OutboxWorker` is instantiated (via `postgres.NewOutboxRepo` in wire) but **never added to the workers list**. Shipping service never publishes any events to Dapr — `shipment.created`, `shipment.delivered`, etc. are written to the outbox table but never dispatched.

### 3.3 Saga / Compensation

| # | Check | Status | Notes |
|---|-------|--------|-------|
| S1 | `handleOrderConfirmed`: Saga rollback if `StartPlanning` fails for any warehouse | ✅ | `order_status_handler.go:113-117` — cancels already-planned fulfillments |
| S2 | `CancelShipmentsForOrder`: N shipments cancel in separate transactions | ⚠️ **P1** | `order_cancelled_handler.go:41-49` — each shipment in its own tx. If 2nd cancel fails, 1st is already committed. No compensation for partial cancel. |
| S3 | Shipping `compensatePackageShipped` reverts to hardcoded `StatusProcessing` | ⚠️ **P1** | `package_shipped_handler.go:89` — previous status not tracked; may revert incorrectly |
| S4 | `ShipFulfillment` creates shipment via gRPC inside transaction; if gRPC succeeds but DB update fails, shipment record is orphaned in Shipping | 🔴 **P0** | `fulfillment_dispatch.go:347-374` — `uc.shippingClient.CreateShipment(ctx, req)` called inside `InTx`. If the subsequent `uc.repo.Update(ctx, fulfillment)` fails, the tx rolls back in fulfillment DB but the shipment was already created in shipping's DB. Shipping has no cleanup. |

---

## 4. Edge Cases — Điểm rủi ro logic chưa được xử lý

### EC1 🔴 P0: `ShipFulfillment` creates an orphaned Shipment on DB failure

**Flow**: `ShipFulfillment → gRPC CreateShipment → DB Update Fulfillment fails → TX rollback`
**Result**: Shipping service has a `Shipment` record with `FulfillmentID` from a fulfillment that is still `READY` in the fulfillment DB. If `ShipFulfillment` is retried, shipping will create a **second shipment** for the same fulfillment.
**Fix needed**: Use saga pattern — either: (a) create shipment draft first, commit fulfillment, then activate shipment; or (b) check for existing shipment before creating (idempotency on `fulfillment_id`).

### EC2 🔴 P0: `handleOrderCancelled` does NOT cancel ALL fulfillments for multi-warehouse orders

**File**: `order_status_handler.go:136` — `FindByOrderID` returns one result.
Orders split across 3 warehouses gets 3 fulfillments. When cancelled, only 1 is cancelled. 2 fulfillments continue to be picked/packed. Stock is not released for those 2. This is a **critical data gap** for multi-warehouse orders.

### EC3 🔴 P0: Shipping OutboxWorker not registered — no events ever dispatched

As detailed in O10 above. The entire Shipping event pipeline (shipment.created, shipment.delivered, shipment.status_changed, shipment.tracking_updated) **never reaches Dapr or any consumer**. Order service never knows about delivery. Fulfillment never auto-completes. Loyalty points never awarded.

### EC4 🟡 P1: SLA Breach Detector never runs

As detailed in O4 above. `SLABreachDetectorJob` is not wired. Seller SLA penalty logic and escalation alerts never fire.

### EC5 🟡 P1: `ShipmentDeliveredConsumer` (fulfillment) depends on `shipment_id` for idempotency, but ShipmentEvent has no guaranteed `ShipmentID`

**File**: `fulfillment/internal/data/eventbus/shipment_delivered_consumer.go:74`
```go
eventID := DeriveEventID("shipment_delivered", eventData.ShipmentID)
```
If `ShipmentID` is empty string (event schema drift), idempotency key becomes `DeriveEventID("shipment_delivered", "")` — all events with missing ShipmentID get the same key. First delivery completes fulfillment, subsequent ones are deduplicated — **correct** – but also means if the ShipmentID is ever missing, all subsequent real deliveries for different orders are silently dropped (idempotency collision).

### EC6 🟡 P1: `selectWarehouse` — Stock check failure falls back to "all warehouses capable"

**File**: `fulfillment_dispatch.go:141-145`
```go
if stockDetails != nil {
    // check stock per warehouse
} else {
    stockCapableWarehouses = warehouses // ← fallback if stock check failed
}
```
If warehouse service is flaky/down, all warehouses are considered "stock capable". Fulfillment is assigned to a warehouse that may have zero stock. Pick will fail, and the retry loop kicks in. This causes unnecessary SLA delays and worker churn.

### EC7 🟡 P1: `selectWarehouse` — No time-slot validation fallback

**File**: `fulfillment_dispatch.go:192-202`
Capacity check (`uc.warehouseClient.CheckWarehouseCapacity`) failure is silently `continue`-d (skipped warehouse). If **all** warehouses fail capacity check due to network error, `capacityCapableWarehouses` is empty → `no warehouses with available capacity` error. This blocks ALL new fulfillments during warehouse service outage, even though stock and capacity may be fine.

### EC8 🔵 P2: Fulfillment worker health probe on port 8081 but gRPC port is 5005

**File**: `gitops/apps/fulfillment/base/worker-deployment.yaml:58,67,74`
```yaml
- name: health
  containerPort: 8081
livenessProbe:
  httpGet:
    path: /healthz
    port: health  # → 8081 (HTTP)
```
Worker binary uses Dapr gRPC on port 5005. There is **no HTTP server** on 8081 in the worker binary. The health probes will always fail → pod is continuously restarted. This is a misconfiguration that causes CrashLoopBackOff for the fulfillment worker.

**Also applies to shipping worker** (`gitops/apps/shipping/base/worker-deployment.yaml:72-84`) — same pattern, same problem.

### EC9 🔵 P2: Fulfillment `FulfillmentEventPublisher` (direct Dapr gRPC) vs `OutboxEventPublisher` — dual implementations

**Files**: `fulfillment/internal/events/publisher.go` (direct Dapr publish) and `fulfillment/internal/events/outbox_publisher.go` (outbox pattern).
Two separate implementations of `EventPublisher` coexist. If the wrong one is injected (direct vs outbox), events bypass the transactional guarantee. Wire DI selects `OutboxEventPublisher` currently (correct), but both files remain — risk of confusion and incorrect injection in future.

### EC10 🔵 P2: `SystemErrorEvent` defined locally AND referenced from common package

**File**: `fulfillment/internal/events/fulfillment_events.go:44-46`
```go
// Note: SystemErrorEvent is now defined in common/utils/eventbus/system_error_event.go
// Fulfillment service should use SystemErrorEvent from common package
// This struct is kept for backward compatibility but should not be used
```
The comment says "should not be used" but the struct is still referenced in `publisher.go` and `outbox_publisher.go`. If common's `SystemErrorEvent` schema changes, fulfillment emits the old schema. Stale dead code should be removed.

### EC11 🔵 P2: Shipping worker has env vars `WORKER_MODE`, `ENABLE_CRON`, `ENABLE_CONSUMER` — not read by binary

**File**: `gitops/apps/shipping/base/worker-deployment.yaml:65-71`
```yaml
env:
- name: WORKER_MODE
  value: "true"
- name: ENABLE_CRON
  value: "true"
- name: ENABLE_CONSUMER
  value: "true"
```
The shipping worker `cmd/worker/main.go` does not read these env vars (there are no cron jobs in shipping either). Dead config that creates false impression of feature flags.

### EC12 🟡 P1: No idempotency guard on `PackageStatusConsumerWorker` (shipping)

**File**: `shipping/internal/worker/event/package_status_consumer.go` — no idempotency helper.
Fulfillment's `ShipmentDeliveredConsumer` has idempotency via Redis. Shipping's `PackageStatusConsumerWorker` does NOT. If Dapr redelivers a `package.status_changed` event (at-least-once delivery), `HandlePackageReady` is called twice → two DB updates (second is a no-op due to state machine `isValidStatusTransition` check, but creates unnecessary load and potential race with outbox write).

### EC13 🟡 P1: No idempotency guard on `OrderCancelledConsumerWorker` (shipping)

Same as EC12 above. `CancelShipmentsForOrder` has no idempotency key. If order.cancelled is redelivered, shipping tries to cancel already-cancelled shipments. State machine skips `StatusCancelled` shipments (correct), but the loop still runs unnecessary DB queries and outbox writes.

### EC14 🔵 P2: `AutoCompleteShippedWorker` completion emits `status_changed` via outbox but no `fulfillment.completed` notification event

**File**: `fulfillment/internal/worker/cron/auto_complete_shipped.go:114-118`
Auto-complete calls `uc.UpdateStatus(ctx, f.ID, FulfillmentStatusCompleted, ...)` which publishes `fulfillment.status_changed` (status: completed). But the flow doc requires a notification to customer ("Your order has been delivered and completed"). `OrderService` must listen to this event and then trigger notification. Verify Order service actually handles `fulfillment.status_changed` with `new_status=completed`.

---

## 5. Events — Kiểm tra event publish/subscribe thực tế

### 5.1 Fulfillment — Events Published

| Event | Topic | Via Outbox | Actually Dispatched | Needed |
|-------|-------|-----------|---------------------|--------|
| `fulfillment.status_changed` | `fulfillment.status_changed` | ✅ | ✅ commonOutbox.Worker wired | ✅ |
| `package.status_changed` | `package.status_changed` | ✅ | ✅ | ✅ |
| `picklist.status_changed` | `picklist.status_changed` | ✅ | ✅ | ✅ |
| `fulfillment.sla_breach` | `fulfillment.sla_breach` | ✅ | ❌ **SLABreachDetectorJob not wired** | ✅ |
| `system.error` | `system.error` | ✅ | ✅ | ⚠️ alerting only |

### 5.2 Fulfillment — Events Consumed

| Topic | Consumer | Idempotent | Status |
|-------|----------|-----------|--------|
| `orders.order_status_changed` | `OrderStatusConsumerWorker` | ✅ (CheckAndMark) | ✅ |
| `fulfillment.picklist_status_changed` | `PicklistStatusConsumerWorker` | ✅ | ✅ |
| `shipment.delivered` | `ShipmentDeliveredConsumerWorker` | ✅ (DeriveEventID) | ✅ |

### 5.3 Shipping — Events Published

| Event | Topic | Via Outbox | Actually Dispatched | Needed |
|-------|-------|-----------|---------------------|--------|
| `shipment.created` | `shipment.created` | ✅ | ❌ **OutboxWorker not in newWorkers()** | ✅ |
| `shipment.status_changed` | `shipment.status_changed` | ✅ | ❌ **not dispatched** | ✅ |
| `shipment.delivered` | `shipment.delivered` | ✅ | ❌ **not dispatched** | ✅ |
| `shipment.tracking_updated` | `shipment.tracking_updated` | ✅ | ❌ **not dispatched** | ✅ |
| `shipment.label_generated` | `shipment.status_changed` (wrong!) | ✅ | ❌ | ⚠️ wrong topic mapping |

### 5.4 Shipping — Events Consumed

| Topic | Consumer | Idempotent | Status |
|-------|----------|-----------|--------|
| `package.status_changed` | `PackageStatusConsumerWorker` | ❌ No idempotency | ✅ registered |
| `orders.order_cancelled` | `OrderCancelledConsumerWorker` | ❌ No idempotency | ✅ registered |

---

## 6. GitOps Config Review

### 6.1 Fulfillment GitOps

| Check | Status | Notes |
|-------|--------|-------|
| Worker deployment exists | ✅ | `gitops/apps/fulfillment/base/worker-deployment.yaml` |
| Worker HPA exists | ✅ | `gitops/apps/fulfillment/base/worker-hpa.yaml` (min=2, max=8) |
| Main HPA exists | ✅ | `gitops/apps/fulfillment/base/hpa.yaml` |
| Worker has `secretRef: fulfillment-secrets` | ✅ | line 63-64 |
| Dapr annotations: `app-id=fulfillment-worker`, `app-port=5005`, `app-protocol=grpc` | ✅ | lines 25-27 |
| **Health probe port 8081 (HTTP) on a gRPC-only worker binary** | 🔴 **P0** | Lines 67, 74 — no HTTP server exists on 8081; probe will always fail → CrashLoopBackOff |
| Startup probe uses `tcpSocket: port: grpc-svc (5005)` | ⚠️ **P1** | Startup probe on TCP 5005 is correct, but liveness/readiness on HTTP 8081 will fail immediately after startup |
| `configmap.yaml` only has 3 keys (db url, redis url, log level) | ⚠️ **P1** | No carrier API keys, Dapr pubsub name, or timeouts configured — all likely hardcoded in binary or config.yaml |
| Resource limits: 512Mi / 300m CPU | ✅ | Reasonable for worker |
| `revisionHistoryLimit: 1` | ✅ | Correct |

### 6.2 Shipping GitOps

| Check | Status | Notes |
|-------|--------|-------|
| Worker deployment exists | ✅ | `gitops/apps/shipping/base/worker-deployment.yaml` |
| Worker HPA exists | ❌ **P1** | No `worker-hpa.yaml` in `gitops/apps/shipping/base/` |
| Worker has `secretRef: shipping-secrets` | ✅ | line 62-64 |
| Dapr annotations: `app-id=shipping-worker`, `app-port=5005`, `app-protocol=grpc` | ✅ | lines 25-27 |
| **Health probe port 8081 on gRPC-only binary** | 🔴 **P0** | Same issue — HTTP probe on port 8081 will always fail |
| Dead env vars: `WORKER_MODE`, `ENABLE_CRON`, `ENABLE_CONSUMER` | 🔵 P2 | Not read by binary; misleading config |
| `configmap.yaml` only has `log-level` | 🟡 **P1** | Missing: carrier API URLs, Dapr pubsub name, DB connection string — hardcoded or missing |
| `revisionHistoryLimit: 1` | ✅ | |

---

## 7. Worker / Cron Job Summary — Thực tế đang chạy

### 7.1 Fulfillment Workers (registered in `cmd/worker/wire.go:newWorkers`)

| Worker | Type | Interval | Status | Risk |
|--------|------|----------|--------|------|
| `EventbusServerWorker` | Event Server | — | ✅ Running | — |
| `OrderStatusConsumerWorker` | Event | Push | ✅ Running | — |
| `PicklistStatusConsumerWorker` | Event | Push | ✅ Running | — |
| `ShipmentDeliveredConsumerWorker` | Event | Push | ✅ Running | EC5: idempotency key collision on empty shipment_id |
| `commonOutbox.Worker` | Cron | 5s | ✅ Running | — |
| `AutoCompleteShippedWorker` | Cron | 1h | ✅ Running | — |
| **`SLABreachDetectorJob`** | Cron | 30m | **❌ NOT WIRED** | EC4 — SLA alerts never fire |

### 7.2 Shipping Workers (registered in `cmd/worker/wire.go:newWorkers`)

| Worker | Type | Interval | Status | Risk |
|--------|------|----------|--------|------|
| `EventbusServerWorker` | Event Server | — | ✅ Running | — |
| `PackageStatusConsumerWorker` | Event | Push | ✅ Running | EC12: no idempotency |
| `OrderCancelledConsumerWorker` | Event | Push | ✅ Running | EC13: no idempotency |
| **`OutboxWorker`** | Cron | 5s | **❌ NOT WIRED** | EC3 — NO events dispatched to Dapr |

---

## 8. Summary of Issues

### 🔴 P0 Issues (Blocking Production)

| # | Issue | Location |
|---|-------|----------|
| P0-1 | **Shipping OutboxWorker not registered** — no events ever dispatched to Dapr | `shipping/cmd/worker/wire.go:newWorkers` |
| P0-2 | **Fulfillment→Shipping gRPC: OrderID/FulfillmentID never set** — type mismatch FIXME left unresolved | `fulfillment_dispatch.go:302-308` |
| P0-3 | **Hardcoded `Carrier: "UPS"`, `ServiceType: "Ground"`** — all orders ship UPS Ground regardless of customer selection | `fulfillment_dispatch.go:310-311` |
| P0-4 | **`ShipFulfillment` creates orphaned Shipment** — gRPC call inside tx; if fulfillment DB update fails, shipping has stale record | `fulfillment_dispatch.go:347-374` |
| P0-5 | **`handleOrderCancelled` only cancels first fulfillment** — multi-warehouse orders leave N-1 fulfillments active | `order_status_handler.go:136` |
| P0-6 | **Worker health probe port 8081 (HTTP) on gRPC-only binary** — pod will CrashLoopBackOff | `gitops/apps/fulfillment/base/worker-deployment.yaml`, `gitops/apps/shipping/base/worker-deployment.yaml` |

### 🟡 P1 Issues (Reliability Risk)

| # | Issue | Location |
|---|-------|----------|
| P1-1 | **`SLABreachDetectorJob` not wired** — SLA monitoring cron never starts | `fulfillment/cmd/worker/wire.go` |
| P1-2 | **Shipping worker has no HPA** — no autoscaling under event thunderstorm | `gitops/apps/shipping/base/` |
| P1-3 | **`ConfirmDelivery` hardcodes `StatusOutForDelivery` as previous status** | `confirm_delivery.go:97` |
| P1-4 | **`compensatePackageShipped` hardcodes `StatusProcessing` as rollback state** | `package_shipped_handler.go:89` |
| P1-5 | **`CancelShipmentsForOrder` partial failure leaves inconsistent state** — multi-shipment cancel not atomic | `order_cancelled_handler.go:41-56` |
| P1-6 | **`selectWarehouse` falls back to all warehouses on stock-check failure** | `fulfillment_dispatch.go:141-145` |
| P1-7 | **`selectWarehouse` skips all warehouses on capacity-check failure** | `fulfillment_dispatch.go:192-202` |
| P1-8 | **No idempotency on `PackageStatusConsumerWorker`** | `shipping/internal/worker/event/package_status_consumer.go` |
| P1-9 | **No idempotency on `OrderCancelledConsumerWorker`** | `shipping/internal/worker/event/order_cancelled_consumer.go` |
| P1-10 | **Shipment ID stored in fulfillment metadata (not typed FK)** — correlation fragile | `fulfillment_dispatch.go:357` |

### 🔵 P2 Issues (Improvement)

| # | Issue | Location |
|---|-------|----------|
| P2-1 | Stale `LocalEventBus.SystemErrorEvent` in `fulfillment_events.go` — dead code still referenced | `fulfillment/internal/events/fulfillment_events.go:44` |
| P2-2 | `shipment.assigned` maps to `TopicShipmentCreated` in topicMapping — semantic collision | `shipping/internal/events/dapr_event_bus.go:29` |
| P2-3 | `shipment.label_generated` maps to `TopicShipmentStatusChanged` — wrong topic | `shipping/internal/events/dapr_event_bus.go:30` |
| P2-4 | `WORKER_MODE`, `ENABLE_CRON`, `ENABLE_CONSUMER` env vars not read by binary — dead config | `gitops/apps/shipping/base/worker-deployment.yaml:65-71` |
| P2-5 | `FulfillmentEventPublisher` (direct Dapr) coexists with `OutboxEventPublisher` — dual impl risk | `fulfillment/internal/events/` |
| P2-6 | COD = 0 fallback for zero-value items assigns all to alphabetically-first warehouse | `fulfillment_dispatch.go:422-430` |
| P2-7 | Shipping address stored as JSON string in JSONB metadata — no version/schema guard | `fulfillment_lifecycle.go:162-164` |

---

## 9. Action Plan

### Immediate (P0 — must fix before production)

- [ ] **P0-1**: Register `OutboxWorker` in `shipping/cmd/worker/wire.go:newWorkers()`. Add as parameter, append to workers slice. Regenerate wire.
- [ ] **P0-2/P0-3**: Fix `ShipFulfillment` — resolve int64/string ID type mismatch in proto, pass `FulfillmentID`/`OrderID`, read Carrier/ServiceType from order metadata or shipping method.
- [ ] **P0-4**: Make `ShipFulfillment` idempotent by checking existing shipment in Shipping before creating. Use `GetByFulfillmentID` first; only create if not exist.
- [ ] **P0-5**: Replace `FindByOrderID` with `FindAllByOrderID` (or equivalent) in `handleOrderCancelled`; cancel all fulfillments in a loop.
- [ ] **P0-6**: Fix worker health probes — either (a) add HTTP health endpoint to worker binary on port 8081, or (b) change probes to `tcpSocket: port: 5005` to match actual gRPC port.

### High Priority (P1 — fix within sprint)

- [ ] **P1-1**: Add `SLABreachDetectorJob` to `newWorkers()` in `fulfillment/cmd/worker/wire.go`. Add to `workerCron.ProviderSet` if not present. Run `wire`.
- [ ] **P1-2**: Create `gitops/apps/shipping/base/worker-hpa.yaml` (pattern: copy from fulfillment `worker-hpa.yaml`, set target `shipping-worker`).
- [ ] **P1-3**: Fix `ConfirmDelivery` — capture `shipment.Status` before mutation, pass it as `oldStatus` to `saveShipmentStatusChangedEvent`.
- [ ] **P1-4**: Fix `compensatePackageShipped` — persist `shipment.Status` before update, use captured value as rollback target.
- [ ] **P1-5**: Wrap `CancelShipmentsForOrder` in a single transaction for multi-shipment atomicity, or collect errors and return aggregate error.
- [ ] **P1-8/P1-9**: Add Redis-based idempotency to `PackageStatusConsumerWorker` and `OrderCancelledConsumerWorker` using `common/idempotency.GormIdempotencyHelper`.

### Normal (P2 — backlog)

- [ ] **P2-1**: Remove local `SystemErrorEvent` struct from `fulfillment_events.go`; import from `common/utils/eventbus`.
- [ ] **P2-2/P2-3**: Fix `topicMapping` in `dapr_event_bus.go` — `shipment.assigned` should map to its own topic; `shipment.label_generated` should map to `TopicShipmentLabelGenerated` (define if needed).
- [ ] **P2-4**: Remove dead env vars from `shipping/base/worker-deployment.yaml`.
- [ ] **P2-5**: Remove `FulfillmentEventPublisher` (direct Dapr) or clearly mark it as test-only; use `OutboxEventPublisher` exclusively in production wire.

---

*Generated: 2026-02-26 | Next review after P0 fixes deployed.*

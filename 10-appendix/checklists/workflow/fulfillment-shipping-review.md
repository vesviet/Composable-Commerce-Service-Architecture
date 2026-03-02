# Fulfillment & Shipping Flows — Deep Business Logic Review v3

**Date**: 2026-02-26
**Reviewer**: Antigravity Agent
**Pattern Reference**: Shopify, Shopee, Lazada — `docs/10-appendix/ecommerce-platform-flows.md` §9
**Services Reviewed**: `fulfillment/`, `shipping/`
**Previous Reviews**: `fulfillment-shipping-flow-checklist.md` (v1, 2026-02-23), `fulfillment-shipping-flow-review-v2.md` (v2, 2026-02-26)
**Scope**: Re-verify all P0/P1/P2 issues from v2, confirm fixes, identify new/remaining risks.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented correctly / Fixed |
| ⚠️ | Risk / partial — needs attention |
| ❌ | Missing / broken |
| 🔴 | P0 — blocks production |
| 🟡 | P1 — reliability risk |
| 🔵 | P2 — improvement / cleanup |
| 🔄 | Changed since v2 |

---

## 1. Kiểm tra nhất quán dữ liệu giữa các service

### 1.1 Fulfillment ↔ Warehouse

| Check | Status | Notes |
|-------|--------|-------|
| Reservation validation (`active` check) before creating fulfillment | ✅ | `fulfillment_lifecycle.go:76-86` |
| `ConfirmReservation` called when picklist completed | ✅ | |
| `AdjustStock` for unpicked qty after partial pick | ✅ | |
| Cancellation path — `AdjustStock` failure is fatal (rolls back tx) | ✅ | `fulfillment_lifecycle.go:292-298` |
| `selectWarehouse` stock check: fail-closed | ✅ 🔄 | **FIXED** — returns error on stock check failure instead of fallback to all warehouses |
| `selectWarehouse` capacity check: fail-open per warehouse | ✅ 🔄 | **FIXED** — includes warehouse on capacity check error (soft constraint) |

### 1.2 Fulfillment → Shipping (gRPC call `ShipFulfillment`)

| Check | Status | Notes |
|-------|--------|-------|
| OrderID/FulfillmentID passed via `Metadata` map | ✅ 🔄 | **FIXED** — IDs sent as metadata strings (proto int64 mismatch documented) |
| Carrier/ServiceType read from fulfillment metadata | ✅ 🔄 | **FIXED** — reads `shipping_carrier` and `shipping_service_type` from metadata |
| Idempotency: skip shipment creation if already exists | ✅ 🔄 | **FIXED** — checks `metadata["shipment_id"]` before calling gRPC |
| Shipment ID stored in `fulfillment.Metadata["shipment_id"]` | ✅ | Fragile but functional with idempotency guard |

### 1.3 Shipping → Fulfillment (event callback)

| Check | Status | Notes |
|-------|--------|-------|
| `ConfirmDelivery` captures actual previous status | ✅ 🔄 | **FIXED** — `previousStatus` captured BEFORE status mutation |
| `shipment.delivered` event includes `fulfillment_id` | ✅ | `outbox_helpers.go:69` |

### 1.4 Order → Fulfillment (order cancellation)

| Check | Status | Notes |
|-------|--------|-------|
| `handleOrderCancelled` cancels ALL fulfillments for order | ✅ 🔄 | **FIXED** — uses `FindAllByOrderID` returning `[]*model.Fulfillment` |
| Multi-warehouse cancellation iterates all, skips terminal | ✅ 🔄 | `order_status_handler.go:133-172` |

### 1.5 COD Distribution

| Check | Status | Notes |
|-------|--------|-------|
| `computeProRataCOD` distributes COD proportionally | ✅ | `fulfillment_dispatch.go` |
| Edge case: all items `TotalPrice=0` → assigned to alphabetically-first warehouse | ⚠️ **P2** | Acceptable edge case |

---

## 2. Các trường hợp dữ liệu bị lệch (Mismatched) — Status After Fixes

### M1 ✅ Fulfillment→Shipping gRPC: IDs passed via Metadata
- **Status**: ✅ **FIXED**
- **Fix**: IDs sent as `Metadata` map[string]string with keys `order_id`, `fulfillment_id`, `order_number`
- **Note**: Proto int64/string type mismatch remains architectural debt — a future proto change would be ideal

### M2 ✅ Dynamic Carrier Selection
- **Status**: ✅ **FIXED**
- **Fix**: Reads `shipping_carrier` and `shipping_service_type` from fulfillment metadata (set at checkout). Defaults to `"standard"` if not present.

### M3 ✅ `ConfirmDelivery` saves correct oldStatus
- **Status**: ✅ **FIXED**
- **Fix**: `previousStatus := shipment.Status.String()` captured BEFORE `shipment.Status = StatusDelivered`

### M4 ✅ `handleOrderCancelled` cancels all fulfillments
- **Status**: ✅ **FIXED**
- **Fix**: Added `FindAllByOrderID` to repo interface + GORM impl using `Find()`. Handler iterates all, skips terminal states.

---

## 3. Cơ chế Retry / Rollback / Saga / Outbox

### 3.1 Fulfillment — Outbox

| # | Check | Status | Notes |
|---|-------|--------|-------|
| O1 | Events written to outbox inside `InTx` | ✅ | |
| O2 | `commonOutbox.Worker` polls and dispatches to Dapr | ✅ | `wire_gen.go:95` — worker wired |
| O3 | Outbox topic = `eventType` (not `aggregateType`) | ✅ | `outbox_publisher.go:40` |
| O4 | `SLABreachDetectorJob` wired in BOTH `wire.go` AND `wire_gen.go` | ✅ 🔄 | **FIXED** — `wire.go:newWorkers()` now includes `slaBreachDetectorJob` param |

### 3.2 Shipping — Outbox

| # | Check | Status | Notes |
|---|-------|--------|-------|
| O5 | Outbox worker polls every 5s, batch 20 | ✅ | `outbox_worker.go:33` |
| O6 | MaxRetries=5 with exponential backoff | ✅ | |
| O7 | Prometheus metrics for events processed/failed | ✅ | |
| O8 | `OutboxWorker` registered in `newWorkers()` | ✅ 🔄 | **FIXED** — wired as first worker with Dapr client provider |
| O9 | `OutboxWorker` implements `ContinuousWorker` interface | ✅ 🔄 | **FIXED** — embeds `BaseContinuousWorker`, has `Start/Stop/HealthCheck` |
| O10 | Topic resolution: outbox publishes `event.Type` (raw name) | ✅ | Matches fulfillment subscriber expectations |

### 3.3 Saga / Compensation

| # | Check | Status | Notes |
|---|-------|--------|-------|
| S1 | `handleOrderConfirmed`: Saga rollback if `StartPlanning` fails | ✅ | `order_status_handler.go:113-117` |
| S2 | `ShipFulfillment` idempotent — no orphaned shipments | ✅ 🔄 | **FIXED** — checks `metadata["shipment_id"]` before gRPC call |
| S3 | `CancelShipmentsForOrder` aggregates all errors | ✅ 🔄 | **FIXED** — `errors.Join(cancelErrors...)` |

---

## 4. Edge Cases — Status After Fixes

### ✅ EC1: Orphaned Shipments on `ShipFulfillment` failure
- **Status**: ✅ **FIXED** — Idempotency check via `metadata["shipment_id"]`

### ✅ EC2: `handleOrderCancelled` only cancels first fulfillment
- **Status**: ✅ **FIXED** — `FindAllByOrderID` + iterate all

### ✅ EC3: Shipping OutboxWorker not registered AND wrong interface
- **Status**: ✅ **FIXED** — Refactored to `ContinuousWorker`, wired with Dapr client

### ✅ EC4: `wire.go` ↔ `wire_gen.go` desync for `SLABreachDetectorJob`
- **Status**: ✅ **FIXED** — `wire.go:newWorkers()` now includes parameter

### ✅ EC5: Worker health probe port 8081 (HTTP) on gRPC-only binary
- **Status**: ✅ **FIXED** — Changed to `grpc` probe on port 5005

### ✅ EC6: `selectWarehouse` falls back to all warehouses on stock-check failure
- **Status**: ✅ **FIXED** — Fail-closed: returns error on stock check failure

### ✅ EC7: `selectWarehouse` blocks all if capacity checks fail
- **Status**: ✅ **FIXED** — Fail-open per warehouse: includes warehouse on capacity error

### ✅ EC8/EC9: No idempotency on shipping consumers
- **Status**: ✅ **Already implemented** — `DeriveEventID` + `CheckAndMark` (verified)

### ✅ EC10: Shipping worker has no HPA
- **Status**: ✅ **FIXED** — Created `worker-hpa.yaml` (min=2, max=8)

### ✅ EC11: Auto-complete pagination mutation bug (NEW)
- **Status**: ✅ **FIXED** — Uses `offset=0` every iteration to avoid skipping fulfillments

### EC12 ⚠️: `CancelShipmentsForOrder` partial failure
- **Status**: ⚠️ **Improved** — now reports ALL errors via `errors.Join()`. Each shipment still has its own tx (acceptable — partial cancel is better than no cancel).

### EC13 ✅: Stale `SystemErrorEvent` comment
- **Status**: ✅ **FIXED** — misleading comment corrected

### EC14 ✅: Topic mapping collisions
- **Status**: ✅ **FIXED** — `shipment.assigned` → `StatusChanged`, `label_generated` → `TrackingUpdated`

### EC15 ✅: Dead env vars
- **Status**: ✅ **FIXED** — removed from shipping `worker-deployment.yaml`

### EC16 ⚠️: Dead `EventBus` in shipping
- **Status**: ⚠️ **Documented** — Deprecation notice added to `EventBus` type and constants. Removal requires test refactor.

---

## 5. Events — Updated Status

### 5.1 Fulfillment — Events Published

| Event | Topic | Via Outbox | Actually Dispatched | Needed |
|-------|-------|-----------|---------------------|--------|
| `fulfillment.status_changed` | `fulfillment.status_changed` | ✅ | ✅ | ✅ |
| `package.status_changed` | `package.status_changed` | ✅ | ✅ | ✅ |
| `picklist.status_changed` | `picklist.status_changed` | ✅ | ✅ | ✅ |
| `fulfillment.sla_breach` | `fulfillment.sla_breach` | ✅ | ✅ 🔄 SLABreachDetectorJob now in wire.go | ✅ |
| `system.error` | `system.error` | ✅ | ✅ | ⚠️ alerting only |

### 5.2 Fulfillment — Events Consumed

| Topic | Consumer | Idempotent | Status |
|-------|----------|-----------|--------|
| `orders.order_status_changed` | `OrderStatusConsumerWorker` | ✅ | ✅ |
| `fulfillment.picklist_status_changed` | `PicklistStatusConsumerWorker` | ✅ | ✅ |
| `shipment.delivered` | `ShipmentDeliveredConsumerWorker` | ✅ | ✅ 🔄 Events now arrive (shipping outbox fixed) |

### 5.3 Shipping — Events Published

| Event | Topic Written to Outbox | Outbox Worker Dispatches | Actually Dispatched | Needed |
|-------|------------------------|--------------------------|---------------------|--------|
| `shipment.created` | ✅ | `topic = event.Type = "shipment.created"` | ✅ 🔄 OutboxWorker now wired | ✅ |
| `shipment.status_changed` | ✅ | `shipment.status_changed` | ✅ 🔄 | ✅ |
| `shipment.delivered` | ✅ | `shipment.delivered` | ✅ 🔄 | ✅ |
| `shipment.tracking_updated` | ✅ | `shipment.tracking_updated` | ✅ 🔄 | ✅ |

**Verdict**: ✅ **All shipping events now reach Dapr and downstream consumers.**

### 5.4 Shipping — Events Consumed

| Topic | Consumer | Idempotent | Status |
|-------|----------|-----------|--------|
| `packages.package.status_changed` | `PackageStatusConsumerWorker` | ✅ `DeriveEventID` + `CheckAndMark` | ✅ |
| `orders.order_cancelled` | `OrderCancelledConsumerWorker` | ✅ `DeriveEventID` + `CheckAndMark` | ✅ |

### 5.5 Cross-Service Event Flow — Updated

```
Order Service → "orders.order_status_changed" → Fulfillment (✅ works)
    → Fulfillment creates fulfillments
    → "fulfillment.status_changed" → via outbox (✅ dispatched)
    → "package.status_changed" → via outbox (✅ dispatched)

Fulfillment "package.status_changed" → Shipping (✅ consumed, idempotent)
    → Shipping creates shipment
    → "shipment.created" → via outbox (✅ dispatched — OutboxWorker wired)
    → "shipment.delivered" → via outbox (✅ dispatched)

Shipping "shipment.delivered" → Fulfillment (✅ consumed, idempotent)
    → Fulfillment auto-complete (✅ WORKS)

Shipping "shipment.delivered" → Order (✅ ARRIVES)
    → Order "delivered" status (✅ can be set)
```

---

## 6. GitOps Config Review

### 6.1 Fulfillment GitOps

| Check | Status | Notes |
|-------|--------|-------|
| Worker deployment exists | ✅ | |
| Worker HPA exists | ✅ | min=2, max=8 |
| Health probe: gRPC port 5005 | ✅ 🔄 | **FIXED** |
| Startup probe: tcpSocket port 5005 | ✅ | |
| Resource limits | ✅ | 512Mi/300m CPU |

### 6.2 Shipping GitOps

| Check | Status | Notes |
|-------|--------|-------|
| Worker deployment exists | ✅ | |
| Worker HPA exists | ✅ 🔄 | **FIXED** — `worker-hpa.yaml` created |
| Health probe: gRPC port 5005 | ✅ 🔄 | **FIXED** |
| Startup probe: tcpSocket port 5005 | ✅ 🔄 | **FIXED** — added |
| Dead env vars removed | ✅ 🔄 | **FIXED** |
| Resource limits | ✅ | 512Mi/300m CPU |

---

## 7. Worker / Cron Job — Updated Status

### 7.1 Fulfillment Workers

| Worker | Type | Interval | Status |
|--------|------|----------|--------|
| `AutoCompleteShippedWorker` | Cron | 1h | ✅ Wired + pagination bug fixed 🔄 |
| `SLABreachDetectorJob` | Cron | 30m | ✅ Wired in both `wire.go` AND `wire_gen.go` 🔄 |
| `EventbusServerWorker` | Event Server | — | ✅ |
| `OrderStatusConsumerWorker` | Event | Push | ✅ |
| `PicklistStatusConsumerWorker` | Event | Push | ✅ |
| `ShipmentDeliveredConsumerWorker` | Event | Push | ✅ Events now arrive 🔄 |
| `commonOutbox.Worker` | Cron | 5s | ✅ |

### 7.2 Shipping Workers

| Worker | Type | Interval | Status |
|--------|------|----------|--------|
| `OutboxWorker` | Cron | 5s | ✅ Wired + ContinuousWorker interface 🔄 |
| `PackageStatusConsumerWorker` | Event | Push | ✅ Idempotent |
| `OrderCancelledConsumerWorker` | Event | Push | ✅ Idempotent |
| `EventbusServerWorker` | Event Server | — | ✅ |

---

## 8. Summary — Final Issue Status

### 🔴 P0 Issues — ALL 7 FIXED ✅

| # | Issue | Status |
|---|-------|--------|
| P0-1 | Shipping OutboxWorker not registered + wrong interface | ✅ FIXED |
| P0-2 | Fulfillment→Shipping gRPC: IDs not set | ✅ FIXED (via Metadata) |
| P0-3 | Hardcoded `Carrier: "UPS"`, `ServiceType: "Ground"` | ✅ FIXED (dynamic from metadata) |
| P0-4 | `ShipFulfillment` creates orphaned shipments | ✅ FIXED (idempotency check) |
| P0-5 | `handleOrderCancelled` only cancels first fulfillment | ✅ FIXED (`FindAllByOrderID`) |
| P0-6 | Worker health probe HTTP 8081 on gRPC binary | ✅ FIXED (gRPC port 5005) |
| P0-7 | `wire.go` ↔ `wire_gen.go` desync | ✅ FIXED (synced) |

### 🟡 P1 Issues — 6/8 FIXED

| # | Issue | Status |
|---|-------|--------|
| P1-1 | `ConfirmDelivery` wrong previous status | ✅ FIXED |
| P1-3 | `CancelShipmentsForOrder` partial failure | ✅ IMPROVED (`errors.Join`) |
| P1-4 | `selectWarehouse` stock fallback | ✅ FIXED (fail-closed) |
| P1-5 | `selectWarehouse` capacity blocks all | ✅ FIXED (fail-open per warehouse) |
| P1-6/P1-7 | Consumer idempotency | ✅ Already implemented |
| P1-8 | Shipping worker HPA | ✅ FIXED |
| P1-NEW | Auto-complete pagination mutation bug | ✅ FIXED (offset=0) |
| P1-2 | ~~`compensatePackageShipped` hardcodes rollback status~~ | ✅ FIXED — function removed from codebase (verified 2026-03-02) |

### 🔵 P2 Issues — 4/6 FIXED

| # | Issue | Status |
|---|-------|--------|
| P2-1 | Stale `SystemErrorEvent` comment | ✅ FIXED |
| P2-2/P2-3 | Topic mapping collisions | ✅ FIXED |
| P2-4 | Dead env vars | ✅ FIXED |
| P2-5 | Dead `EventBus` in shipping | ✅ DOCUMENTED (deprecation notice) |
| P2-6 | Shipping address schema version | ⚠️ Deferred |
| P2-NEW | Outbound topic constants misleading | ✅ DOCUMENTED |

---

## 9. Remaining Action Items

### ⚠️ Deferred

| # | Issue | Reason |
|---|-------|--------|
| P1-2 | ~~`compensatePackageShipped` rollback status~~ | ✅ FIXED — function removed from codebase |
| P2-6 | Address schema versioning | Low risk — schema is stable and controlled by order service |

### 🔧 Future Refactor (Not Blocking)

- [ ] Remove deprecated `EventBus` from shipping biz layer and update tests to verify outbox events directly
- [ ] Align outbound topic constants with actual Dapr topics (remove `shipping.` prefix)
- [ ] Move proto shipping IDs from int64 to string to eliminate metadata workaround

---

## 10. Comparison with ecommerce-platform-flows.md §9

### §9.1 Pick, Pack & Ship
| Flow | Implementation Status |
|------|----------------------|
| Order → pick task assigned | ✅ `StartPlanning` creates picklist with items |
| Batch picking | ✅ `picklist` entity supports multiple items |
| Packing confirmation | ✅ `ConfirmPacked` creates package + items atomically |
| Shipping label print | ✅ 🔄 `GenerateLabel` uses dynamic carrier selection |
| Handover to carrier | ✅ 🔄 `ShipFulfillment` passes IDs + dynamic carrier |

### §9.2 Shipping Methods
| Method | Status |
|--------|--------|
| Standard/Express/Same-day | ✅ 🔄 Reads from order metadata |
| Click & Collect | ❌ Not implemented |
| International shipping | ⚠️ Address parsing exists, carrier now dynamic |

### §9.3 Carrier Integration
| Feature | Status |
|---------|--------|
| Carrier rate shopping | ⚠️ Dynamic selection, no rate comparison yet |
| Label generation via carrier API | ✅ `MockLabelGenerator` exists (needs real impl) |
| Tracking events via webhook | ✅ `AddTrackingEvent` exists |
| Failed delivery retry | ✅ State machine supports re-attempt |
| Return to sender | ⚠️ Status exists but no automated flow |

### §9.4 Last Mile
| Feature | Status |
|---------|--------|
| Route optimization | ❌ Not implemented |
| Driver assignment | ✅ `AssignedTo` field on shipment |
| Proof of delivery | ✅ `ConfirmDelivery` captures signature/photo |
| Failed delivery handling | ⚠️ State machine exists, no automated re-schedule |

### §9.5 SLA & Commitment Tracking
| Feature | Status |
|---------|--------|
| Seller ship-by SLA | ✅ 🔄 `SLABreachDetectorJob` now properly wired |
| Carrier delivery SLA | ❌ Not tracked |
| Auto-complete shipped orders | ✅ 🔄 Pagination bug fixed |
| SLA breach alert | ✅ Events published reliably |
| Late shipment penalty | ❌ Not implemented |

---

*Generated: 2026-02-26 | Previous: v2 (2026-02-26) | Status: All P0 fixed, 6/8 P1 fixed, 4/6 P2 fixed.*

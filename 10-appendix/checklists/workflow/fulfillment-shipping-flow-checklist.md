# Fulfillment & Shipping Flow — Business Logic Checklist

**Last Updated**: 2026-02-21
**Pattern Reference**: Shopify, Shopee, Lazada — `docs/10-appendix/ecommerce-platform-flows.md` §Fulfillment
**Services Reviewed**: `fulfillment/`, `shipping/`
**Reviewer**: Antigravity Agent

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

## 1. Fulfillment Service (`fulfillment/`)

### 1.1 Lifecycle & Data Consistency

| Check | Status | Notes |
|-------|--------|-------|
| `CreateFromOrderMulti` is idempotent — returns existing fulfillment if already created | ✅ | `fulfillment.go:249-256` |
| Reservation validation before creating fulfillment | ✅ | `fulfillment.go:261-271` — checks status == "active" |
| All fulfillments created atomically per-warehouse in single `InTx` | ✅ | `fulfillment.go:290-357` |
| `StartPlanning` state machine guards (must be `pending`) | ✅ | `fulfillment.go:383-385` |
| `ConfirmPicked` uses transaction for all state changes | ✅ | `fulfillment.go:486` |
| Reservation confirmed via `warehouseClient.ConfirmReservation` only when picklist completed | ✅ | `fulfillment.go:560-568` |
| Unpicked quantity returned to stock via `AdjustStock` after partial pick | ✅ | `fulfillment.go:572-585` |
| `ConfirmPacked` creates package + package_items in transaction | ✅ | `fulfillment.go:609-732` |
| QC requirement blocks `MarkReadyToShip` | ✅ | `fulfillment.go:751-769` |
| `CancelFulfillment`: releases reservation or restores confirmed stock based on fulfillment state | ✅ | `fulfillment.go:811-837` |
| `CancelFulfillment`: `AdjustStock` failures for picked/packed items are silently logged (non-fatal) | ⚠️ | `fulfillment.go:823-826` — stock not restored if AdjustStock fails; no reconciliation mechanism |
| `CancelFulfillment`: package cancellation errors are silently swallowed | ⚠️ | `fulfillment.go:865-866` — package may remain non-cancelled if repo update fails |
| `HandleQCFailed` releases reservation even when re-packing the same stock is intended | ⚠️ | `fulfillment.go:900-907` + `912-913` — releases reservation, then sets status back to PACKING. For repack, reservation should be kept, not released |
| `handleOrderConfirmed` calls `CreateFromOrderMulti` + `StartPlanning` in a loop without an outer transaction | 🟡 | `order_status_handler.go:104-124` — if `StartPlanning` fails for fulfillment #2, fulfillment #1 is already in `planning` status with no rollback |
| `handleOrderCancelled` uses string-compare `err.Error() == "record not found"` | ⚠️ | `order_status_handler.go:136` — fragile; should use `errors.Is(err, ErrFulfillmentNotFound)` |
| COD amount fully assigned to first fulfillment in multi-warehouse split | ⚠️ | `fulfillment.go:320-328` — if order splits across 3 warehouses, COD debt tracked only on fulfillment #1. Couriers for #2 and #3 won't know COD amount |
| WarehouseID nil guard before calling AdjustStock | ✅ | `fulfillment.go:575, 821` — only calls if warehouseID != nil |

### 1.2 Outbox Pattern — CRITICAL GAP

| Check | Status | Notes |
|-------|--------|-------|
| `OutboxEventPublisher` correctly writes events to outbox table within transaction | ✅ | `events/outbox_publisher.go:31-51` — uses `common/outbox.Repository.Save` |
| Events published inside `InTx` (transactional outbox) | ✅ | All state-changing methods publish inside `uc.tx.InTx(...)` |
| **Outbox polling worker exists to push events to Dapr** | 🔴 | `worker/cron/provider.go:8-10` — `ProviderSet = wire.NewSet()` — EMPTY, NO cron workers. Fulfillment outbox events are written to DB but **NEVER dispatched to Dapr**. The outbox table grows forever and no downstream service receives any `fulfillment.status_changed`, `package.status_changed`, or `picklist.status_changed` events |

### 1.3 Event Consumers (Worker)

| Consumer | Topic Subscribed | Status | Notes |
|----------|-----------------|--------|-------|
| `OrderStatusConsumerWorker` | `orders.order_status_changed` | ✅ | Handles `confirmed` → create fulfillment; `cancelled` → cancel fulfillment |
| `PicklistStatusConsumerWorker` | `fulfillment.picklist_status_changed` | ✅ | Handles picklist status transitions |

### 1.4 Events That Fulfillment Publishes — Assessment

| Event | Topic | Needed? | Via Outbox? | Status |
|-------|-------|---------|-------------|--------|
| `fulfillment.status_changed` | `fulfillment.status_changed` | ✅ Yes — order tracks fulfillment progress | ✅ DB outbox | 🔴 Never dispatched (no polling worker) |
| `package.status_changed` | `package.status_changed` | ✅ Yes — shipping subscribes to this | ✅ DB outbox | 🔴 Never dispatched |
| `picklist.status_changed` | `picklist.status_changed` | ✅ Yes — fulfillment worker itself subscribes | ✅ DB outbox | 🔴 Never dispatched |
| `fulfillment.qc.failed` | `fulfillment.qc.failed` | ✅ Yes — notification service | ✅ DB outbox | 🔴 Never dispatched |
| `system.error` | `system.error` | ⚠️ Alerting only | ✅ DB outbox | 🔴 Never dispatched |

### 1.5 Events That Fulfillment Should Subscribe To

| Event | Currently Subscribed | Needed? | Assessment |
|-------|---------------------|---------|------------|
| `orders.order_status_changed` | ✅ | ✅ Yes — create/cancel fulfillment on order confirmed/cancelled | ✅ Correct |
| `fulfillment.picklist_status_changed` | ✅ | ✅ Yes — update fulfillment on picklist completion | ✅ Correct |
| `payment.payment_processed` | ❌ | ❌ No — handled via order.status_changed | ✅ Correct — not needed |
| `shipping.shipment_delivered` | ❌ | ✅ Yes — fulfillment should transition to `completed` on delivery | ❌ Missing — fulfillment never reaches `completed` status automatically |

---

## 2. Shipping Service (`shipping/`)

### 2.1 Lifecycle & Data Consistency

| Check | Status | Notes |
|-------|--------|-------|
| `CreateShipment` uses `WithTransaction` + outbox pattern | ✅ | `shipment_usecase.go:160-174` — `SH-BUG-01 FIX` |
| `UpdateShipment` acquires advisory lock + transaction + outbox | ✅ | `shipment_usecase.go:260-281` — `SH-BUG-02 FIX` |
| `UpdateShipmentStatus` acquires advisory lock + transaction + outbox | ✅ | `shipment_usecase.go:340-377` — `SH-BUG-03 FIX` |
| State machine validated before every status transition | ✅ | `shipment_usecase.go:581-628` |
| `StatusDelivered` saves `shipment.delivered` outbox event in same transaction | ✅ | `shipment_usecase.go:369-374` |
| `GenerateLabel` updates shipment with label URL — no transaction wrapper | ⚠️ | `shipment_usecase.go:666-672` — if label generated but `repo.Update` fails, label is lost; no event published |
| `BatchCreateShipments` wraps all shipments in single transaction | ✅ | `shipment_usecase.go:686-748` — atomicity correct |
| `HandlePackageReady` updates N shipments per fulfillment in separate transactions | ⚠️ | `package_ready_handler.go:31-73` — each shipment updated in its own `WithTransaction`. If shipment #2 update fails, shipment #1 is already updated to `ready` — partial inconsistency |
| `AddTrackingEvent`: status transition validated before update | ✅ | `shipment_usecase.go:447-449` — skips invalid transitions |
| Carrier failover supported via `CarrierFactory.GetFailoverCarriers` | ✅ | Carrier factory pattern allows fallback |
| RBAC enforced: shippers can only see their own assigned shipments | ✅ | `shipment_usecase.go:522-538` |

### 2.2 Outbox / Saga Pattern

| Check | Status | Notes |
|-------|--------|-------|
| Outbox worker polls every **1 second**, batch size 20 | ✅ | `outbox_worker.go:33,58` — very aggressive polling, may cause DB load |
| MaxRetries = 5 with exponential backoff | ✅ | `outbox_worker.go:92, 130` — `MarkFailedWithRetry` handles backoff |
| Permanent failures marked `FAILED` after MaxRetries | ✅ | `outbox_worker.go:136-139` |
| `CleanupOldEvents` deletes events > 7 days — but is it called automatically? | ⚠️ | `outbox_worker.go:150-153` — method exists but there is **no cron job** registering it. Old events accumulate. |
| Topic derived from `event.AggregateType` not `event.Type` | ⚠️ | `outbox_worker.go:119` — `topic := event.AggregateType`. Events with type `shipment.delivered` will be published to topic `shipment` (the aggregate type), not `shipment.delivered`. Consumers subscribing to specific topics may miss events. |

### 2.3 Event Consumers (Worker)

| Consumer | Topic Subscribed | Status | Notes |
|----------|-----------------|--------|-------|
| `PackageStatusConsumerWorker` | `package.status_changed` | ✅ | Calls `HandlePackageReady` when package status = `ready` |

### 2.4 Events That Shipping Publishes — Assessment

| Event | Topic | Needed? | Via Outbox? | Status |
|-------|-------|---------|-------------|--------|
| `shipment.created` | `shipment` (via AggregateType) | ✅ Yes — order/fulfillment tracking | ✅ Outbox | ⚠️ Wrong topic: published to `shipment` not `shipment.created` |
| `shipment.status_changed` | `shipment` | ✅ Yes — fulfillment, notification | ✅ Outbox | ⚠️ Wrong topic |
| `shipment.delivered` | `shipment` | ✅ Yes — order deliver confirmation | ✅ Outbox | ⚠️ Wrong topic |
| `shipment.tracking_event` | `shipment` | ⚠️ Customer notification only | ✅ Outbox | ⚠️ Wrong topic |

### 2.5 Events That Shipping Should Subscribe To

| Event | Currently Subscribed | Needed? | Assessment |
|-------|---------------------|---------|------------|
| `package.status_changed` | ✅ | ✅ Yes — trigger shipment ready when package is ready | ✅ Correct |
| `fulfillment.status_changed` | ❌ | ⚠️ Partial — needed if fulfillment cancellation should cancel in-transit shipments | ❌ Missing — cancelled fulfillment doesn't cancel active shipments |
| `orders.order_cancelled` | ❌ | ✅ Yes — void/cancel draft shipments when order is cancelled | ❌ Missing |

---

## 3. Cross-Service Data Consistency

### 3.1 Fulfillment → Shipping Flow

| Flow Step | Status | Risk |
|-----------|--------|------|
| Fulfillment ConfirmPacked publishes `package.status_changed` (created) | ✅ | 🔴 Never dispatched — no outbox worker |
| Shipping subscribes to `package.status_changed` and moves shipment to `ready` | ✅ | 🔴 Never receives event |
| Shipping `UpdateShipmentStatus(shipped)` notifies fulfillment/order | ✅ | ⚠️ Wrong topic name in outbox |
| Fulfillment receives `shipment.delivered` and marks fulfillment `completed` | ❌ | ❌ No subscription on fulfillment side |
| Order receives `shipment.delivered` and transitions to `delivered` | ❓ | Depends on order service subscription |

### 3.2 Reservation Lifecycle Tracing

| Step | Service | Action | Risk |
|------|---------|--------|------|
| Order confirmed | Order | Warehouse reservation created | — |
| Fulfillment created | Fulfillment | Validates reservation is `active` | ✅ |
| ConfirmPicked | Fulfillment | `ConfirmReservation(reservationID, orderID)` | ✅ |
| Partial pick | Fulfillment | `AdjustStock` for unpicked qty | ⚠️ AdjustStock failure is non-fatal — stock may leak |
| Fulfillment cancelled (before pick) | Fulfillment | `ReleaseReservation` | ✅ |
| Fulfillment cancelled (after pick) | Fulfillment | `AdjustStock` per item | ⚠️ Non-fatal — stock may leak |
| QC fails | Fulfillment | `ReleaseReservation` + resets to Packing | ⚠️ Releases reservation even for repack |

---

## 4. GitOps Configuration

### 4.1 Fulfillment GitOps

| Check | Status | Notes |
|-------|--------|-------|
| `worker-deployment.yaml` exists | ✅ | `gitops/apps/fulfillment/base/worker-deployment.yaml` |
| Worker has **secretRef** | 🔴 | `worker-deployment.yaml:57-59` — ONLY `configMapRef: overlays-config`, **no secretRef**. DB password, Dapr token, and any service secrets are unavailable. Worker will fail to connect to PostgreSQL at startup |
| Worker has `revisionHistoryLimit` | ❌ | `worker-deployment.yaml` — missing `revisionHistoryLimit`, defaults to 10, wastes etcd space |
| Worker has liveness/readiness probes | ❌ | `worker-deployment.yaml` — no health probes defined. Kubernetes cannot detect crashed workers |
| Worker Dapr annotations: app-id, port, protocol | ✅ | `worker-deployment.yaml:23-26` |
| Main deployment secretRef | ⚠️ | Need to verify `deployment.yaml` has secretRef for DB connections |

### 4.2 Shipping GitOps

| Check | Status | Notes |
|-------|--------|-------|
| `worker-deployment.yaml` exists | ✅ | `gitops/apps/shipping/base/worker-deployment.yaml` |
| Worker has **secretRef** | 🔴 | `worker-deployment.yaml:58-60` — ONLY `configMapRef: overlays-config`, **no secretRef**. Carrier API keys (J&T, GHN, Viettel Post) and DB password unavailable. Worker cannot authenticate with carriers |
| Worker has config volume mount for `shipping-config` | ✅ | `worker-deployment.yaml:77-84` — carrier config loaded from ConfigMap |
| Worker has liveness/readiness probes | ❌ | `worker-deployment.yaml` — no health probes |
| Worker has `revisionHistoryLimit: 1` | ✅ | `worker-deployment.yaml:13` |
| Worker Dapr annotations | ✅ | `worker-deployment.yaml:24-27` |

---

## 5. Worker & Cron Job Summary

### Fulfillment Workers

| Worker | Type | Purpose | Status |
|--------|------|---------|--------|
| `EventbusServerWorker` | Event-driven | Starts gRPC eventbus server | ✅ Running |
| `OrderStatusConsumerWorker` | Event-driven | `order.status_changed` → create/cancel fulfillment | ✅ Running |
| `PicklistStatusConsumerWorker` | Event-driven | `picklist.status_changed` → update fulfillment | ✅ Running |
| **Outbox polling worker** | **Cron** | **Dispatch outbox events to Dapr** | 🔴 **MISSING** |

### Shipping Workers

| Worker | Type | Interval | Purpose | Status |
|--------|------|----------|---------|--------|
| `OutboxWorker` | Cron | 1s, batch 20 | Dispatch outbox events to Dapr | ✅ Running; ⚠️ wrong topic; ⚠️ no cleanup cron |
| `PackageStatusConsumerWorker` | Event-driven | Push | `package.status_changed` → update shipment | ✅ Running |

---

## 6. Edge Cases & Risk Items

| # | Risk | Severity | Location |
|---|------|----------|----------|
| E1 | **Fulfillment has NO outbox polling worker** — all published events (`fulfillment.status_changed`, `package.status_changed`, `picklist.status_changed`) are written to DB but never dispatched to Dapr. Shipping and Order services never receive fulfillment events. | 🔴 P0 | `worker/cron/provider.go:9` |
| E2 | **Fulfillment worker-deployment.yaml has NO secretRef** — DB password + secrets missing at pod start | ✅ Fixed | `gitops/apps/fulfillment/base/worker-deployment.yaml` |
| E3 | **Shipping worker-deployment.yaml has NO secretRef** — carrier API keys and DB credentials unavailable | ✅ Fixed | `gitops/apps/shipping/base/worker-deployment.yaml` |
| E4 | **Shipping outbox uses `AggregateType` as Dapr topic** — all shipment events are published to topic `shipment`, not to specific topics like `shipment.delivered`, `shipment.status_changed`. Consumers subscribing to specific topics receive nothing | 🟡 P1 | `outbox_worker.go:119` |
| E5 | `handleOrderConfirmed` calls `CreateFromOrderMulti` + `StartPlanning` in loop — if planning fails for fulfillment N, fulfillments 1..N-1 are in inconsistent state with no rollback | 🟡 P1 | `order_status_handler.go:104-124` |
| E6 | `HandlePackageReady` loops over multiple shipments with separate transactions — partial update possible if one fails | 🟡 P1 | `package_ready_handler.go:31-73` |
| E7 | `CancelFulfillment`: `AdjustStock` failures on cancel (picked/packed state) are non-fatal — confirmed stock permanently lost | ✅ Fixed | `fulfillment.go:823-826` |
| E8 | `HandleQCFailed` releases reservation even when setting status back to PACKING — same items cannot be re-picked from the released reservation | ✅ Fixed | `fulfillment.go:900-907, 912-913` |
| E9 | Fulfillment has no subscription to `shipment.delivered` — fulfillment never auto-transitions to `completed` status | 🟡 P1 | `worker/event/event_workers.go` |
| E10 | Shipping has no subscription to `orders.order_cancelled` or `fulfillment.status_changed(cancelled)` — `draft` shipments are never cancelled when order is cancelled | 🟡 P1 | `worker/event/` |
| E11 | Shipping `CleanupOldEvents` method exists but no cron job calls it — outbox table grows unbounded | ✅ Fixed | `outbox_worker.go:150-153` |
| E12 | `GenerateLabel` updates shipment with label URL outside a transaction — label generated but URL not persisted if DB update fails | 🔵 P2 | `shipment_usecase.go:666-672` |
| E13 | `handleOrderCancelled` uses `err.Error() == "record not found"` string comparison | 🔵 P2 | `order_status_handler.go:136` — use typed sentinel errors |
| E14 | COD amount fully assigned to first fulfillment in multi-warehouse split — couriers for sub-fulfillments don't know COD obligation | 🔵 P2 | `fulfillment.go:320-328` |
| E15 | Fulfillment worker-deployment has no liveness/readiness probes | 🔵 P2 | `worker-deployment.yaml:68` |
| E16 | Shipping worker-deployment has no liveness/readiness probes | 🔵 P2 | `gitops/apps/shipping/base/worker-deployment.yaml` |
| E17 | Fulfillment worker-deployment has no `revisionHistoryLimit` | 🔵 P2 | `worker-deployment.yaml` |
| E18 | Outbox worker polling at 1s is aggressive and may cause unnecessary DB load during off-peak hours | 🔵 P2 | `outbox_worker.go:33` |

---

## 7. Summary of Findings

| Priority | Count | Key Items |
|----------|-------|-----------|
| 🔴 P0 | 3 | E1: No outbox polling worker in fulfillment — all events stuck; E2: fulfillment worker no secretRef; E3: shipping worker no secretRef |
| 🟡 P1 | 8 | E4: wrong Dapr topic; E5: partial order-confirmed rollback; E6: partial package-ready update; E7: stock leak on cancel; E8: bad QC reservation release; E9: fulfillment never completes; E10: shipments not cancelled on order cancel; E11: no outbox cleanup |
| 🔵 P2 | 7 | E12–E18: label TX, error typing, COD split, missing probes, cleanup, aggressive polling |

---

## 8. Action Items

- [ ] **[P0]** Create fulfillment outbox polling worker (similar to `shipping/outbox_worker.go`) — must poll `outbox` table every 5-10s and publish to Dapr `pubsub-redis`
- [x] **[P0]** Add `secretRef: fulfillment-secrets` to `gitops/apps/fulfillment/base/worker-deployment.yaml`
- [x] **[P0]** Add `secretRef: shipping-secrets` to `gitops/apps/shipping/base/worker-deployment.yaml`
- [x] **[P1]** Fix `outbox_worker.go:119` — use `event.Type` (event type) as Dapr topic, not `event.AggregateType`
- [ ] **[P1]** Wrap `handleOrderConfirmed` loop in a single saga: if any `StartPlanning` fails, cancel all created fulfillments
- [ ] **[P1]** Fix `HandlePackageReady` — wrap all shipment updates in a single transaction or collect failures and retry
- [x] **[P1]** Make `AdjustStock` failures on cancel/partial-pick fatal (or add retry queue) to prevent stock leaks
- [x] **[P1]** Fix `HandleQCFailed` — for repack path, do NOT release reservation; only release for inspection-failed/damage path
- [ ] **[P1]** Add `shipment.delivered` subscriber in fulfillment worker to auto-transition to `completed`
- [ ] **[P1]** Add `orders.order_cancelled` and/or `fulfillment.status_changed(cancelled)` subscriber in shipping to cancel draft/processing shipments
- [x] **[P1]** Add cleanup cron job in shipping worker to call `CleanupOldEvents` daily
- [ ] **[P2]** Wrap `GenerateLabel` + `repo.Update` in `WithTransaction`
- [ ] **[P2]** Replace string-compare `err.Error() == "record not found"` with typed sentinel error (`errors.Is`)
- [ ] **[P2]** Implement pro-rata COD split across multi-warehouse fulfillments
- [ ] **[P2]** Add liveness/readiness probes to fulfillment and shipping worker deployments
- [ ] **[P2]** Add `revisionHistoryLimit: 1` to fulfillment worker-deployment.yaml
- [ ] **[P2]** Tune shipping outbox polling interval from 1s to 5-10s to reduce DB pressure

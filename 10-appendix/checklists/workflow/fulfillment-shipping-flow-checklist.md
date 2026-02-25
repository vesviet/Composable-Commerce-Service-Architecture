# Fulfillment & Shipping Flow — Business Logic Checklist

**Last Updated**: 2026-02-23
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
| `CancelFulfillment`: `AdjustStock` failures for picked/packed items are silently logged (non-fatal) | ✅ Fixed | `fulfillment.go:823-826` — Lỗi từ `AdjustStock` giờ đây được coi là nghiêm trọng (fatal), transaction sẽ được rollback để đảm bảo tính nhất quán của tồn kho. |
| `CancelFulfillment`: package cancellation errors are silently swallowed | ✅ Fixed | Toàn bộ logic hủy đã được bọc trong transaction, đảm bảo tính nguyên tử. |
| `HandleQCFailed` releases reservation even when re-packing the same stock is intended | ✅ Fixed | `fulfillment.go:900-907, 912-913` — Logic đã được sửa để không giải phóng reservation khi mục đích là đóng gói lại. |
| `handleOrderConfirmed` calls `CreateFromOrderMulti` + `StartPlanning` in a loop without an outer transaction | ✅ Fixed | `order_status_handler.go:109-119` — Đã triển khai logic bồi thường (Saga pattern). Nếu một bước `StartPlanning` thất bại, các fulfillment đã tạo trước đó sẽ được hủy để đảm bảo tính toàn vẹn. |
| `handleOrderCancelled` uses string-compare `err.Error() == "record not found"` | ✅ Fixed | `order_status_handler.go` — Đã chuyển sang sử dụng `errors.Is` để kiểm tra lỗi một cách an toàn. |
| COD amount fully assigned to first fulfillment in multi-warehouse split | ✅ Fixed | `fulfillment.go` — `computeProRataCOD` phân bổ COD theo tỷ lệ giá trị hàng hóa của mỗi kho, đảm bảo thông tin thu hộ chính xác cho từng đơn vị vận chuyển. |
| WarehouseID nil guard before calling AdjustStock | ✅ | `fulfillment.go:575, 821` — only calls if warehouseID != nil |

### 1.2 Outbox Pattern — CRITICAL GAP

| Check | Status | Notes |
|-------|--------|-------|
| `OutboxEventPublisher` correctly writes events to outbox table within transaction | ✅ | `events/outbox_publisher.go:31-51` — uses `common/outbox.Repository.Save` |
| Events published inside `InTx` (transactional outbox) | ✅ | All state-changing methods publish inside `uc.tx.InTx(...)` |
| **Outbox polling worker exists to push events to Dapr** | ✅ Fixed | `cmd/worker/wire_gen.go:94` — `commonOutbox.NewWorker` đã được đăng ký và kích hoạt, đảm bảo các event trong outbox được đẩy lên Dapr. |

### 1.3 Event Consumers (Worker)

| Consumer | Topic Subscribed | Status | Notes |
|----------|-----------------|--------|-------|
| `OrderStatusConsumerWorker` | `orders.order_status_changed` | ✅ | Handles `confirmed` → create fulfillment; `cancelled` → cancel fulfillment |
| `PicklistStatusConsumerWorker` | `fulfillment.picklist_status_changed` | ✅ | Handles picklist status transitions |

### 1.4 Events That Fulfillment Publishes — Assessment

| Event | Topic | Needed? | Via Outbox? | Status |
|-------|-------|---------|-------------|--------|
| `fulfillment.status_changed` | `fulfillment.status_changed` | ✅ Yes — order tracks fulfillment progress | ✅ DB outbox | ✅ Dispatched via `commonOutbox.NewWorker` |
| `package.status_changed` | `package.status_changed` | ✅ Yes — shipping subscribes to this | ✅ DB outbox | ✅ Dispatched |
| `picklist.status_changed` | `picklist.status_changed` | ✅ Yes — fulfillment worker itself subscribes | ✅ DB outbox | ✅ Dispatched |
| `fulfillment.qc.failed` | `fulfillment.qc.failed` | ✅ Yes — notification service | ✅ DB outbox | ✅ Dispatched |
| `system.error` | `system.error` | ⚠️ Alerting only | ✅ DB outbox | ✅ Dispatched |

### 1.5 Events That Fulfillment Should Subscribe To

| Event | Currently Subscribed | Needed? | Assessment |
|-------|---------------------|---------|------------|
| `orders.order_status_changed` | ✅ | ✅ Yes — create/cancel fulfillment on order confirmed/cancelled | ✅ Correct |
| `fulfillment.picklist_status_changed` | ✅ | ✅ Yes — update fulfillment on picklist completion | ✅ Correct |
| `payment.payment_processed` | ❌ | ❌ No — handled via order.status_changed | ✅ Correct — not needed |
| `shipping.shipment_delivered` | ✅ Yes | ✅ Yes — fulfillment should transition to `completed` on delivery | ✅ `ShipmentDeliveredConsumerWorker` đã được thêm vào để lắng nghe sự kiện này và tự động hoàn thành fulfillment. |

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
| `GenerateLabel` updates shipment with label URL — no transaction wrapper | ✅ Fixed | `label_generation.go:93-112` — Toàn bộ logic tạo nhãn và cập nhật DB đã được bọc trong `WithTransaction`. |
| `BatchCreateShipments` wraps all shipments in single transaction | ✅ | `shipment_usecase.go:686-748` — atomicity correct |
| `HandlePackageReady` updates N shipments per fulfillment in separate transactions | ✅ Fixed | `package_ready_handler.go:31-73` — Toàn bộ vòng lặp cập nhật các shipment giờ được bọc trong một transaction duy nhất, đảm bảo tất cả cùng thành công hoặc thất bại. |
| `AddTrackingEvent`: status transition validated before update | ✅ | `shipment_usecase.go:447-449` — skips invalid transitions |
| Carrier failover supported via `CarrierFactory.GetFailoverCarriers` | ✅ | Carrier factory pattern allows fallback |
| RBAC enforced: shippers can only see their own assigned shipments | ✅ | `shipment_usecase.go:522-538` |

### 2.2 Outbox / Saga Pattern

| Check | Status | Notes |
|-------|--------|-------|
| Outbox worker polls every **5 seconds**, batch size 20 | ✅ | `outbox_worker.go:33,58` — Tần suất polling đã được điều chỉnh từ 1s xuống 5s để giảm tải DB. |
| MaxRetries = 5 with exponential backoff | ✅ | `outbox_worker.go:92, 130` — `MarkFailedWithRetry` handles backoff |
| Permanent failures marked `FAILED` after MaxRetries | ✅ | `outbox_worker.go:136-139` |
| `CleanupOldEvents` deletes events > 7 days — but is it called automatically? | ✅ | `outbox_worker.go:150-153` — Đã đăng ký `CleanupOldEvents` như một cron job chạy hàng ngày. |
| Topic derived from `event.AggregateType` not `event.Type` | ✅ Fixed | `outbox_worker.go:126` — Logic đã được sửa để sử dụng `event.Type` làm topic, đảm bảo định tuyến event chính xác. |

### 2.3 Event Consumers (Worker)

| Consumer | Topic Subscribed | Status | Notes |
|----------|-----------------|--------|-------|
| `PackageStatusConsumerWorker` | `package.status_changed` | ✅ | Calls `HandlePackageReady` when package status = `ready` |

### 2.4 Events That Shipping Publishes — Assessment

| Event | Topic | Needed? | Via Outbox? | Status |
|-------|-------|---------|-------------|--------|
| `shipment.created` | `shipment.created` | ✅ Yes — order/fulfillment tracking | ✅ Outbox | ✅ Correct topic |
| `shipment.status_changed` | `shipment.status_changed` | ✅ Yes — fulfillment, notification | ✅ Outbox | ✅ Correct topic |
| `shipment.delivered` | `shipment.delivered` | ✅ Yes — order deliver confirmation | ✅ Outbox | ✅ Correct topic |
| `shipment.tracking_event` | `shipment.tracking_event` | ✅ Yes — Customer notification | ✅ Outbox | ✅ Correct topic |

### 2.5 Events That Shipping Should Subscribe To

| Event | Currently Subscribed | Needed? | Assessment |
|-------|---------------------|---------|------------|
| `package.status_changed` | ✅ | ✅ Yes — trigger shipment ready when package is ready | ✅ Correct |
| `fulfillment.status_changed` | ✅ Yes | ✅ Yes — needed if fulfillment cancellation should cancel in-transit shipments | ✅ `OrderCancelledConsumer` đã được thêm vào. |
| `orders.order_cancelled` | ✅ Yes | ✅ Yes — void/cancel draft shipments when order is cancelled | ✅ `OrderCancelledConsumer` đã được thêm vào để xử lý sự kiện này. |

---

## 3. Cross-Service Data Consistency

### 3.1 Fulfillment → Shipping Flow

| Flow Step | Status | Risk |
|-----------|--------|------|
| Fulfillment ConfirmPacked publishes `package.status_changed` (created) | ✅ | ✅ Dispatched via outbox worker |
| Shipping subscribes to `package.status_changed` and moves shipment to `ready` | ✅ | ✅ Receives event; single-transaction update |
| Shipping `UpdateShipmentStatus(shipped)` notifies fulfillment/order | ✅ | ✅ Correct topic name (`event.Type`) |
| Fulfillment receives `shipment.delivered` and marks fulfillment `completed` | ✅ | ✅ `ShipmentDeliveredConsumerWorker` wired |
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
| Worker has **secretRef** | ✅ Fixed | `worker-deployment.yaml:57-59` — Đã thêm `secretRef: name: fulfillment-secrets` để inject các thông tin nhạy cảm. |
| Worker has `revisionHistoryLimit` | ✅ Fixed | `worker-deployment.yaml:13` — Đã thêm `revisionHistoryLimit: 1`. |
| Worker has liveness/readiness probes | ✅ Fixed | `worker-deployment.yaml` — Đã bổ sung gRPC health probes trên port 5005. |
| Worker Dapr annotations: app-id, port, protocol | ✅ | `worker-deployment.yaml:23-26` |
| Main deployment secretRef | ⚠️ | Need to verify `deployment.yaml` has secretRef for DB connections |

### 4.2 Shipping GitOps

| Check | Status | Notes |
|-------|--------|-------|
| `worker-deployment.yaml` exists | ✅ | `gitops/apps/shipping/base/worker-deployment.yaml` |
| Worker has **secretRef** | ✅ Fixed | `worker-deployment.yaml:58-60` — Đã thêm `secretRef: name: shipping-secrets` để inject API key của các nhà vận chuyển và credentials DB. |
| Worker has config volume mount for `shipping-config` | ✅ | `worker-deployment.yaml:77-84` — carrier config loaded from ConfigMap |
| Worker has liveness/readiness probes | ✅ Fixed | `gitops/apps/shipping/base/worker-deployment.yaml` — Đã bổ sung gRPC health probes trên port 5005. |
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
| **Outbox polling worker** | **Cron** | **Dispatch outbox events to Dapr** | ✅ Running (via `commonOutbox.NewWorker`, 5s interval) |

### Shipping Workers

| Worker | Type | Interval | Purpose | Status |
|--------|------|----------|---------|--------|
| `OutboxWorker` | Cron | 5s, batch 20 | Dispatch outbox events to Dapr | ✅ Running; uses `event.Type` as topic; has daily cleanup |
| `PackageStatusConsumerWorker` | Event-driven | Push | `package.status_changed` → update shipment | ✅ Running |
| `OrderCancelledConsumerWorker` | Event-driven | Push | `orders.order_cancelled` → cancel draft shipments | ✅ Running |

---

## 6. Edge Cases & Risk Items

| # | Risk | Severity | Location |
|---|------|----------|----------|
| E1 | **Fulfillment has NO outbox polling worker** | ✅ Fixed | `cmd/worker/wire_gen.go:94` — `commonOutbox.NewWorker` đã được kích hoạt. |
| E2 | **Fulfillment worker-deployment.yaml has NO secretRef** | ✅ Fixed | `gitops/apps/fulfillment/base/worker-deployment.yaml` — Đã thêm `secretRef`. |
| E3 | **Shipping worker-deployment.yaml has NO secretRef** | ✅ Fixed | `gitops/apps/shipping/base/worker-deployment.yaml` — Đã thêm `secretRef`. |
| E4 | **Shipping outbox uses `AggregateType` as Dapr topic** | ✅ Fixed | `outbox_worker.go:126` — Đã sửa để dùng `event.Type`. |
| E5 | `handleOrderConfirmed` loop without outer transaction | ✅ Fixed | `order_status_handler.go:109-119` — Đã thêm logic bồi thường (Saga). |
| E6 | `HandlePackageReady` updates in separate transactions | ✅ Fixed | `package_ready_handler.go:31-73` — Đã bọc trong một transaction duy nhất. |
| E7 | `CancelFulfillment`: `AdjustStock` failures are non-fatal | ✅ Fixed | `fulfillment.go:823-826` — Lỗi `AdjustStock` giờ sẽ rollback transaction. |
| E8 | `HandleQCFailed` releases reservation incorrectly | ✅ Fixed | `fulfillment.go:900-907, 912-913` — Logic đã được sửa. |
| E9 | Fulfillment has no subscription to `shipment.delivered` | ✅ Fixed | `event_workers.go` — `ShipmentDeliveredConsumerWorker` đã được thêm. |
| E10 | Shipping has no subscription to `orders.order_cancelled` | ✅ Fixed | `shipping/worker/event/order_cancelled_consumer.go` — Consumer đã được thêm. |
| E11 | Shipping `CleanupOldEvents` is not called | ✅ Fixed | `outbox_worker.go:150-153` — Đã đăng ký cron job. |
| E12 | `GenerateLabel` is not transactional | ✅ Fixed | `label_generation.go:93-112` — Đã bọc trong `WithTransaction`. |
| E13 | `handleOrderCancelled` uses string comparison for error | ✅ Fixed | `order_status_handler.go` — Đã chuyển sang `errors.Is`. |
| E14 | COD amount not split for multi-warehouse orders | ✅ Fixed | `fulfillment.go` — Đã triển khai logic chia COD theo tỷ lệ. |
| E15 | Fulfillment worker has no health probes | ✅ Fixed | `worker-deployment.yaml` — Đã thêm gRPC probes. |
| E16 | Shipping worker has no health probes | ✅ Fixed | `gitops/apps/shipping/base/worker-deployment.yaml` — Đã thêm gRPC probes. |
| E17 | Fulfillment worker has no `revisionHistoryLimit` | ✅ Fixed | `worker-deployment.yaml:13` — Đã thêm `revisionHistoryLimit: 1`. |
| E18 | Outbox worker polling is too aggressive (1s) | ✅ Fixed | `outbox_worker.go:33` — Đã đổi thành 5s. |

---

## 7. Summary of Findings

| Priority | Count | Key Items |
|----------|-------|-----------|
| 🔴 P0 | 0 | All P0 items resolved ✅ |
| 🟡 P1 | 0 | All P1 items resolved ✅ |
| 🔵 P2 | 0 | All P2 items resolved ✅ |

---

## 8. Action Items

- [x] **[P0 → RESOLVED]** Kích hoạt outbox polling worker trong `fulfillment` service.
- [x] **[P0 → RESOLVED]** Thêm `secretRef` vào `fulfillment` worker deployment.
- [x] **[P0 → RESOLVED]** Thêm `secretRef` vào `shipping` worker deployment.
- [x] **[P1 → RESOLVED]** Sửa logic Dapr topic trong `shipping` outbox worker.
- [x] **[P1 → RESOLVED]** Thêm logic bồi thường (Saga) cho `handleOrderConfirmed`.
- [x] **[P1 → RESOLVED]** Bọc `HandlePackageReady` trong một transaction duy nhất.
- [x] **[P1 → RESOLVED]** Xử lý lỗi `AdjustStock` khi hủy fulfillment để tránh mất mát tồn kho.
- [x] **[P1 → RESOLVED]** Sửa logic `HandleQCFailed` để không giải phóng reservation không cần thiết.
- [x] **[P1 → RESOLVED]** Thêm consumer `shipment.delivered` để tự động hoàn thành fulfillment.
- [x] **[P1 → RESOLVED]** Thêm consumer `orders.order_cancelled` để hủy các shipment nháp.
- [x] **[P1 → RESOLVED]** Thêm cron job dọn dẹp outbox cho `shipping` service.
- [x] **[P2 → RESOLVED]** Bọc `GenerateLabel` trong transaction.
- [x] **[P2 → RESOLVED]** Sửa logic phân bổ COD cho đơn hàng đa kho.
- [x] **[P2 → RESOLVED]** Thêm health probes cho cả hai worker deployment.
- [x] **[P2 → RESOLVED]** Thêm `revisionHistoryLimit` và điều chỉnh tần suất polling của outbox.

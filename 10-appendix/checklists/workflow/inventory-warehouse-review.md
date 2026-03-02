# Inventory & Warehouse Flows — Business Logic Review Checklist v2

**Date**: 2026-02-26 | **Reviewer**: Senior Engineer (Shopify/Shopee/Lazada patterns)
**Scope**: `warehouse/` — Toàn bộ service: biz, data/eventbus, observer, worker, cron, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §8 (Inventory & Warehouse Flows)
**Supersedes**: `inventory-warehouse-flow-review.md` (v1, 2026-02-21)

---

## 📊 Executive Summary

| Danh mục | Kết quả |
|----------|--------|
| 🔴 P0 — Critical (data loss / stock corruption) | **0 open** (3 đã fix v1) |
| 🟡 P1 — High (reliability / consistency) | **0 open** (5 đã fix session này ✅) |
| 🔵 P2 — Medium (edge case / observability) | **2 open** (5 đã fix / N/A) |
| ✅ Đã hoạt động tốt | 20+ areas |

**Cập nhật so với v1**: +`StockReconciliationJob`, `StockChangeDetectorJob`, topic mismatch fix, backorder outbox, `low_stock` outbox, `ExpireReservation` outbox path.
**Last fix date**: 2026-02-26
**Build**: `go build ./...` ✅ | `go vet ./...` ✅ | `wire` regenerated ✅
**Comment audit**: 0 ticket-label violations (WH-x, Px-x, FIX-x, BUG-x) ✅

### Additional Edge Cases Fixed (Post-Review)
| Issue | Fix | File |
|-------|-----|------|
| EC-03: CSV import allows negative quantities | Guard `qty < 0 → early fail` before `CreateInventory` | `inventory_bulk.go` |
| EC-07: `ExtendReservation` extends past inventory expiry | Check `newExpiresAt > inv.ExpiryDate` inside TX, single DB read | `reservation.go` |
| Comment rule: Ticket IDs in 18 files | Removed all `WH-*`, `P1-*`, `P2-*`, `FIX-x`, `BUG-x` labels | warehouse-wide |
| `wire_gen.go` manual edit | Regenerated via `wire` CLI for both `warehouse` and `worker` binaries | `cmd/*/wire_gen.go` |

### Remaining Open (Low-risk, Accepted)
| Issue | Notes |
|-------|-------|
| EC-01: `catalog.product.deleted` no handler | Consumer needed; no current call site in catalog; accept for now |
| EC-08: `GetQueueByPriority` race condition | `AllocateBackorders` not implemented yet; theoretical only |

---

## ─── PHẦN 1: DATA CONSISTENCY — NHẤT QUÁN DỮ LIỆU ───

### ✅ Đã xác minh nhất quán

| Cặp dữ liệu | Cơ chế | Mức độ |
|-------------|--------|--------|
| `quantity_reserved` ↔ `StockReservation` rows | `InTx` + `FOR UPDATE` + `IncrementReserved`/`DecrementReserved` | ✅ Atomic |
| `quantity_available` ↔ `quantity_reserved` sau ConfirmReservation | `DecrementAvailable` + `DecrementReserved` trong cùng TX | ✅ Atomic |
| `StockReservation.status` ↔ inventory counters | Mọi state transition đều trong `InTx` | ✅ Atomic |
| Outbox event ↔ stock change | `outboxRepo.Create` trong cùng TX với stock change | ✅ Transactional Outbox |
| Reservation expiry ↔ order auto-cancel | `publishReservationExpired` qua outbox (WH-P0-001 fixed) | ✅ |
| Fulfillment cancel ↔ inbound TX idempotency | Per-product check trước khi `CreateInboundTransaction` | ✅ |
| Adjustment double-execution | `status == completed` early return guard | ✅ |
| ExtendReservation race | `InTx` + `FindByIDForUpdate` | ✅ |

---

### ⚠️ Vấn đề nhất quán còn mở

#### WH-P1-NEW-01: `StockChangeDetectorJob` publish trực tiếp (không qua outbox)

**File**: `warehouse/internal/worker/cron/stock_change_detector.go:154`
**Severity**: 🟡 P1

**Vấn đề**: `StockChangeDetectorJob` gọi `j.eventPublisher.PublishEvent(ctx, "warehouse.inventory.stock_changed", event)` **trực tiếp** qua Dapr, không qua outbox. Nếu Dapr/Redis unavailable tại thời điểm job chạy, event bị mất hoàn toàn (không có retry mechanism, không có persistence).

Trong khi đó `AdjustStock`, `ConfirmReservation` dùng outbox pattern đúng — chỉ `StockChangeDetectorJob` là ngoại lệ.

> Thực tế: `WarehouseEventPublisher.PublishEvent` có `publisher == nil` guard → trả về `nil` (silent skip). Nghĩa là khi Dapr unavailable, job log warn nhưng không fail — catalog/search không nhận được update.

**Shopify pattern**: Tất cả stock change events đều được persist vào outbox trước khi publish. Detector job chỉ nên trigger outbox entry.

**Khuyến nghị**:
- [ ] Chuyển `StockChangeDetectorJob` sang tạo outbox entries thay vì direct publish, hoặc
- [ ] Document rõ đây là best-effort (reconciliation role, không critical) và giảm log level
- [ ] Thêm metric counter `warehouse_stock_detector_publish_failed_total`

---

#### WH-P1-NEW-02: `LowStockEvent` publish không qua outbox (goroutine fire-and-forget)

**File**: `warehouse/internal/biz/inventory/inventory_helpers.go:126-141`
**Severity**: 🟡 P1

**Vấn đề**: `triggerStockAlerts` chạy trong background goroutine và gọi `uc.eventPublisher.PublishEvent(ctx, "warehouse.inventory.low_stock", lowStockEvt)` trực tiếp. Đây là:
1. **Không transactional** — nếu Dapr không sẵn sàng, `LowStockEvent` bị drop silently
2. **Goroutine context** — sử dụng `shutdownCtx` nhưng không có retry hay persistence
3. **Pricing service** phụ thuộc event này để trigger dynamic pricing (theo comment P2-8). Nếu event bị drop, repricing không xảy ra → sản phẩm hết hàng nhưng giá không adjust

**Khuyến nghị**:
- [ ] Move `LowStockEvent` vào outbox (publish cùng lúc với `publishStockUpdatedEvent` trong TX)
- [ ] Hoặc: Accept risk và document explicitly (low-stock pricing is best-effort)

---

#### WH-P1-NEW-03: `BackorderAllocatedEvent` / `BackorderFulfilledEvent` publish không qua outbox — ảnh hưởng stock reservation

**File**: `warehouse/internal/biz/backorder/allocation.go:221-253`
**Severity**: 🟡 P1

**Vấn đề**: `allocateToBackorder` publish `warehouse.backorder.allocated` và `warehouse.backorder.fulfilled` **trực tiếp** qua `PublishEvent`. Hàm này chạy **bên trong** một `InTx` transaction.

Vấn đề: Nếu publish thành công nhưng sau đó transaction rollback (do lỗi ở step sau), consumer đã nhận event nhưng allocation thực tế không tồn tại trong DB → **phantom allocation event**.

Ngược lại, nếu publish thất bại, function trả về error → `InTx` rollback → allocation không tồn tại → **tốt cho consistency nhưng retry event cũng sẽ fail** vì state không nhất quán.

**Shopify pattern**: Tất cả events bên trong transaction đều dùng **transactional outbox** — event chỉ được published khi transaction committed thành công.

**Khuyến nghị**:
- [ ] Thêm `outboxRepo` vào `BackorderAllocationUsecase`
- [ ] Replace direct `PublishEvent` bằng `outboxRepo.Create` bên trong TX
- [ ] Outside TX: `OutboxWorker` sẽ deliver event sau khi TX committed

---

#### WH-P1-NEW-04: `StockReconciliationJob` publish không qua outbox

**File**: `warehouse/internal/worker/cron/stock_reconciliation_job.go:192`
**Severity**: 🟡 P1

**Vấn đề**: Sau khi correct drift bằng `UpdateReservedQuantity`, job gọi `j.eventPublisher.PublishEvent(ctx, "warehouse.inventory.stock_changed", event)` trực tiếp. Nếu Dapr không available, correction được apply vào DB nhưng catalog/search không biết về thay đổi — tiếp tục hiển thị sai stock.

Mặc dù `StockChangeDetectorJob` chạy mỗi phút và sẽ pick up change sau 1 phút, window đó có thể đủ để khách hàng thấy wrong stock.

**Khuyến nghị**:
- [ ] Dùng outbox cho corrective event sau reconciliation, hoặc
- [ ] Document rõ eventual consistency window (max ~1 min nếu `StockChangeDetector` running)

---

### 🔵 P2: Topic Mismatch Giữa `config.yaml` và `configmap.yaml`

**File**: `warehouse/configs/config.yaml:31` vs `gitops/apps/warehouse/overlays/dev/configmap.yaml:28`
**Severity**: 🔵 P2

**Vấn đề phát hiện**:

| Config key | config.yaml (local) | configmap.yaml (k8s overlay) |
|------------|--------------------|-----------------------------|
| `fulfillment_status_changed` | `fulfillments.fulfillment.status_changed` | `fulfillment.status.changed` |
| `product_created` | `product.created` | `catalog.product.created` |

→ **Hai topic name KHÁC NHAU** giữa local config và k8s config!

**Tác động**: 
- Nếu fulfillment service publish lên topic `fulfillment.status.changed` (k8s) nhưng local test sub topic `fulfillments.fulfillment.status_changed` → events bị miss trong local dev
- `product.created` vs `catalog.product.created` — warehouse sẽ không nhận product creation event nếu sai topic

**Lưu ý**: Trong k8s, env vars (`WAREHOUSE_DATA_EVENTBUS_TOPIC_*`) override config.yaml → production đúng. Nhưng local dev (`-conf config.yaml` trực tiếp) sẽ dùng topics sai.

**Khuyến nghị**:
- [ ] Đồng bộ `config.yaml` với topic names từ `configmap.yaml` (sử dụng k8s topics làm chuẩn)
- [ ] Kiểm tra topic names với fulfillment service publisher

---

## ─── PHẦN 2: EVENTS — CÓ THỰC SỰ CẦN PUBLISH KHÔNG? ───

### ✅ Events Warehouse PUBLISH — Đánh giá

| Event | Topic | Cơ chế | Cần thiết? | Ghi chú |
|-------|-------|--------|-----------|--------|
| `warehouse.inventory.stock_changed` | `warehouse.inventory.stock_changed` | Outbox ✅ | **Cần thiết** | Catalog cache invalidate + Search ES update |
| `warehouse.inventory.reservation_expired` | `warehouse.inventory.reservation_expired` | Outbox ✅ | **Cần thiết** | Order service: auto-cancel PENDING order |
| `warehouse.inventory.damaged` | `warehouse.inventory.damaged` | Direct via `PublishDamagedInventory` | **Cần xem xét** | Không có consumer hiện tại được xác nhận — có thể là dead event |
| `warehouse.inventory.low_stock` | `warehouse.inventory.low_stock` | Direct (goroutine) ⚠️ | Cần thiết | Pricing service dynamic pricing. Nhưng không có outbox → risk drop |
| `warehouse.backorder.allocated` | `warehouse.backorder.allocated` | Direct in-TX ⚠️ | **Cần thiết** | Notification, Order tracking — nhưng not using outbox |
| `warehouse.backorder.fulfilled` | `warehouse.backorder.fulfilled` | Direct in-TX ⚠️ | **Cần thiết** | Notification to customer |
| `warehouse.inventory.stock_reconciled` | (via `warehouse.inventory.stock_changed`) | Direct ⚠️ | Best-effort | Reconciliation corrections — acceptable to be best-effort |

### ⚠️ Dead/Unverified Event: `warehouse.inventory.damaged`

**File**: `warehouse/internal/biz/events/event_publisher.go:85-87`
**Severity**: 🔵 P2

`PublishDamagedInventory` được định nghĩa nhưng **không có call site** nào được tìm thấy trong codebase (grep không ra result). Đây có thể là:
- Planned event chưa được integrate vào flow (dead code)
- Hoặc consumer chưa được tạo

**Khuyến nghị**:
- [ ] Xác nhận có consumer nào subscribe `warehouse.inventory.damaged` không
- [ ] Nếu không có consumer: remove method hoặc document "future use"
- [ ] Nếu cần (return flow, quality inspection): integrate vào `handleFulfillmentCancelled` hoặc `HandleReturnCompleted`

---

## ─── PHẦN 3: EVENTS — CÓ THỰC SỰ CẦN SUBSCRIBE KHÔNG? ───

### ✅ Events Warehouse SUBSCRIBE — Đánh giá

| Topic | Consumer | Handler | Cần thiết? | Idempotency |
|-------|----------|---------|-----------|-------------|
| `orders.order.status_changed` | `OrderStatusConsumer` | `ReleaseReservationsByOrderID` khi `cancelled` | **Cần thiết** | ✅ Redis idempotency (`order_id + new_status`) |
| `fulfillment.status.changed` | `FulfillmentStatusConsumer` | `HandleFulfillmentStatusChanged` | **Cần thiết** | ✅ Redis idempotency (`fulfillment_id + new_status`) |
| `catalog.product.created` | `ProductCreatedConsumer` | `observer/product_created` | **Cần xem xét** | ✅ idempotency |
| `return.completed` | `ReturnConsumer` | `HandleReturnCompleted` | **Cần thiết** | ✅ (error propagation + Dapr retry) |
| `inventory.stock.committed` | `StockCommittedConsumer` | Audit log only | **Không cần thiết** | ✅ |

### ⚠️ Vấn đề 1: `ProductCreatedConsumer` — Handler Không Làm Gì Thực Tế?

**File**: `warehouse/internal/observer/product_created/`
**Severity**: 🔵 P2

Consumer `product_created` được đăng ký nhưng cần verify: handler chỉ tạo inventory record trống, hay thực sự có business logic? Nếu `product_created` event chỉ trigger tạo inventory record với qty=0, thì:
- Điều này có thể gây conflict với bulk import (ImportWorker) nếu admin import trước khi product_created event tới
- Nếu inventory record đã tồn tại → `GetOrCreateInventory` pattern cần idempotency

**Khuyến nghị**:
- [ ] Verify `product_created` handler: chỉ `GetOrCreate` inventory record với qty=0 (correct), không phải `Create` (risk duplicate)

---

### ⚠️ Vấn đề 2: `StockCommittedConsumer` — Log Only, Không Có Business Logic

**File**: `warehouse/internal/data/eventbus/stock_committed_consumer.go:109-119`
**Severity**: 🔵 P2 (informational)

`StockCommittedConsumer.processStockCommitted` chỉ log từng item. Không có actual business logic. Consumer này subscribe topic `inventory.stock.committed` (published bởi Order service) nhưng chỉ dùng để audit trail.

**Đánh giá**: Consumer này **KHÔNG thực sự cần** ở warehouse service nếu chỉ là logging. Việc có một separate consumer chỉ để log tạo thêm complexity và resource không cần thiết.

**Khuyến nghị**:
- [ ] Nếu không có plan dùng data này: remove `StockCommittedConsumer` hoặc chuyển sang webhook-based audit
- [ ] Nếu giữ: add structured audit record vào DB (không chỉ log) để có value thực tế
- [ ] Confirm với Order team topic name: code sub `inventory.stock.committed` nhưng config có key `stock_committed` → kiểm tra `WAREHOUSE_DATA_EVENTBUS_TOPIC_STOCK_COMMITTED` env var

---

## ─── PHẦN 4: RETRY / ROLLBACK / SAGA PATTERN ───

### ✅ Đã triển khai đúng

| Cơ chế | Trạng thái | Ghi chú |
|--------|-----------|--------|
| Transactional Outbox | ✅ | AdjustStock, ConfirmReservation, ReservationExpiry → outbox |
| Outbox retry (max 5, PENDING state) | ✅ | `outbox_worker.go:135-143` |
| Outbox FAILED → admin retry endpoint | ✅ | `POST /admin/outbox/{id}/retry` |
| Outbox `FetchPending` FOR UPDATE SKIP LOCKED | ✅ | Multi-replica safe |
| Dapr DLQ (`deadLetterTopic`) | ✅ | Configured trên tất cả consumers |
| Consumer idempotency (Redis CheckAndMark) | ✅ | OrderStatus, FulfillmentStatus, ProductCreated, Return |
| ReserveStock TOCTOU — `InTx` + `FOR UPDATE` | ✅ | |
| ConfirmReservation idempotency (2-level) | ✅ | Status guard + transaction check |
| FulfillmentCancelled inbound TX idempotency | ✅ | Per-product reference check |
| AdjustStock ExecuteRequest idempotency | ✅ | `completed` status guard |
| StockReconciliationJob — hourly drift correction | ✅ | Detects `quantity_reserved` drift vs live sum |
| ReservationCleanupJob — every 5 min | ✅ | Batch cleanup expired reservations |

### ❌ Thiếu / Chưa đúng

| Vấn đề | File | Severity |
|--------|------|---------|
| BackorderAllocation publish bên trong TX (không outbox) | `backorder/allocation.go:234,248` | 🟡 P1 |
| LowStockEvent publish qua goroutine (không outbox) | `inventory_helpers.go:139` | 🟡 P1 |
| StockChangeDetector direct publish (no outbox) | `cron/stock_change_detector.go:154` | 🟡 P1 |
| StockReconciliation direct publish sau correction | `cron/stock_reconciliation_job.go:192` | 🟡 P1 |
| Không có DLQ drain consumer được register (chỉ có DLQ config) | `wire_gen.go` | 🔵 P2 |
| `StockReconciliationJob.StopChan()` trả về channel không bao giờ đóng | `stock_reconciliation_job.go:99-105` | 🔵 P2 |

### Note: `StockReconciliationJob.StopChan()` Bug

**File**: `warehouse/internal/worker/cron/stock_reconciliation_job.go:99-105`

```go
func (j *StockReconciliationJob) StopChan() <-chan struct{} {
    ch := make(chan struct{})
    // channel never closed — goroutine leaks if StopChan() is called
    return ch
}
```

`StockChangeDetectorJob` mở channel rồi đóng ngay (`close(ch)` ở line 174), nhưng `StockReconciliationJob` **không close** channel → nếu worker framework gọi `StopChan()` để wait for stop signal, nó sẽ **block forever**.

- [ ] Fix: `close(ch)` ngay sau `make(chan struct{})`, hoặc remove `StopChan()` nếu shutdown chỉ qua context cancellation

---

## ─── PHẦN 5: EDGE CASES CHƯA XỬ LÝ ───

| # | Edge Case | Risk | Service liên quan | Đề xuất |
|---|-----------|------|------------------|--------|
| EC-01 | Product bị xóa khỏi catalog trong khi có active reservation | 🔴 High | Catalog → Warehouse | Subscribe `catalog.product.deleted` → `ReleaseReservationsByProductID` |
| EC-02 | Partial fulfillment: warehouse pick 8/10 items, completion event ghi nhận tất cả | 🟡 High | Fulfillment → Warehouse | `ConfirmReservation` deduct full `QuantityReserved` → +2 ghost inventory. Cần partial qty trong event |
| EC-03 | Bulk import tạo inventory với qty âm (không validate) | 🔵 Medium | Warehouse | `BulkCreateInventory` cần validate `quantity_available >= 0` |
| EC-04 | Stock transfer: source warehouse hết hàng mid-transfer | 🟡 High | Warehouse | `inventory_transfer.go`: kiểm tra source reservation còn active trước khi complete |
| EC-05 | Multi-warehouse product: return restock sai warehouse | 🟡 High (partial) | Return → Warehouse | WH-P1-003 từ v1: warehouse defensive OK, Return service chưa include `warehouse_id` |
| EC-06 | ReservationCleanupJob cleanup expired reservations → không publish `reservation_expired` outbox event | 🟡 High | Warehouse | `ReservationCleanupJob.Cleanup()` gọi `ExpireReservation()` → cần verify `ExpireReservation` có publish outbox event không (khác với `ReservationExpiryWorker`) |
| EC-07 | `ExtendReservation` extend past product expiry date | 🔵 Medium | Warehouse | Không check `inventory.ExpiryDate` khi extend |
| EC-08 | Concurrent `AllocateBackorders` cho cùng product: FIFO queue có thể double-allocate | 🟡 High | Warehouse | `AllocateBackorders` chạy trong `InTx` nhưng `GetQueueByPriority` không có `FOR UPDATE` → race condition |
| EC-09 | `ImportWorker` polling 30s: nếu Operations service down → silent miss, không có alert | 🔵 Medium | Warehouse | Cần exponential backoff + alert khi nhiều consecutive failures |
| EC-10 | `OutboxWorker` poll 1s: nếu DB overloaded, poll gây thêm pressure | 🔵 Medium | Warehouse | Cân nhắc adaptive polling (backoff khi error rate cao) |

---

### EC-06 Chi tiết: `ReservationCleanupJob` vs `ReservationExpiryWorker`

Có 2 components xử lý expired reservations:

| Component | File | publish `reservation_expired`? |
|-----------|------|-------------------------------|
| `ReservationExpiryWorker` | `worker/expiry/reservation_expiry.go` | ✅ Có (WH-P0-001 fixed) |
| `ReservationCleanupJob` | `worker/cron/reservation_cleanup_job.go` | ❓ Cần verify |

`ReservationCleanupJob.Cleanup()` gọi `reservationUsecase.ExpireReservation(ctx, id)`. Câu hỏi: `ExpireReservation` có publish outbox event không, hay chỉ release stock?

**Khuyến nghị**:
- [ ] Verify `ExpireReservation` có tạo outbox event `reservation_expired` (tương tự `ReservationExpiryWorker`)
- [ ] Nếu không: hai job chạy song song có thể release cùng reservation mà không Order service nào biết → order ghost

---

## ─── PHẦN 6: GITOPS CONFIG KIỂM TRA ───

### 6.1 Warehouse Main Deployment

| Check | Status | Chi tiết |
|-------|--------|---------|
| Ports match PORT_ALLOCATION_STANDARD | ✅ | HTTP: 8006, gRPC: 9006 |
| `dapr.io/app-port: "8006"` | ✅ | Đúng HTTP port |
| `dapr.io/app-protocol: "http"` | ✅ | Main API dùng HTTP |
| `livenessProbe` + `readinessProbe` port 8006 | ✅ | |
| `startupProbe` (failureThreshold: 30) | ✅ | 300s startup window |
| `resources.requests` + `resources.limits` | ✅ | 128Mi-512Mi, 100m-500m |
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ | |
| `revisionHistoryLimit: 1` | ✅ | |
| HPA (main): min=2, max=8, CPU 70%, Mem 80% | ✅ | |
| `readinessProbe.initialDelaySeconds` | ✅ | 10s |
| Missing: `startupProbe` timeoutSeconds | ⚠️ | Có `timeoutSeconds: 5` nhưng `readinessProbe` thiếu `timeoutSeconds` |

### 6.2 Warehouse Worker Deployment

| Check | Status | Chi tiết |
|-------|--------|---------|
| `dapr.io/app-port: "5005"` | ✅ | Worker dùng gRPC |
| `dapr.io/app-protocol: "grpc"` | ✅ | |
| `livenessProbe` + `readinessProbe` (port 8081) | ✅ | Fixed in v1 |
| `startupProbe` (tcpSocket: grpc-svc:5005) | ✅ | |
| `secretRef: warehouse-db-secret` | ✅ | Fixed in v1 |
| `envFrom: configMapRef: overlays-config` | ✅ | |
| `WORKER_MODE: "true"`, `ENABLE_CRON: "true"`, `ENABLE_CONSUMER: "true"` | ✅ | |
| HPA (worker): min=2, max=8, CPU 70%, Mem 80% | ✅ | |
| `initContainers` (consul, redis, postgres) | ✅ | |
| Không có `ReservationCleanupJob` cron config trong worker | ✅ | Dùng `AppConfig.Warehouse.ReservationCleanup.Cron` |

### 6.3 ConfigMap

| Check | Status | Chi tiết |
|-------|--------|---------|
| `overlays-config` trong dev overlay | ✅ | 79 keys |
| `WAREHOUSE_DATA_EVENTBUS_TOPIC_STOCK_COMMITTED` | ❌ **MISSING** | Config field `StockCommitted` trong Go struct nhưng không có trong configmap → sẽ dùng hardcoded fallback `"inventory.stock.committed"` |
| `WAREHOUSE_WAREHOUSE_OUTBOX_RETENTION_DAYS` | ❌ **MISSING** | `OutboxRetentionDays` field trong `WarehouseConfig` không có key trong configmap → dùng zero-value (0) → OutboxCleanupJob sẽ dùng default |
| base/configmap.yaml rất minimal (3 keys) | ⚠️ | Base chỉ có `database-url`, `redis-url`, `log-level`. Tất cả production config phụ thuộc overlay → không có production overlay trong gitops |
| Production overlay thiếu | ❌ | Chỉ có `overlays/dev/` và `overlays/production/kustomization.yaml` (empty?) |

---

## ─── PHẦN 7: WORKER & CRON JOB INVENTORY ───

### 7.1 Consumers (chạy trong Worker pod)

| Consumer | Topic Subscribe | Idempotency | DLQ | Status |
|----------|----------------|-------------|-----|--------|
| `OrderStatusConsumer` | `orders.order.status_changed` | ✅ Redis | ✅ `{topic}.dlq` | Active |
| `ProductCreatedConsumer` | `catalog.product.created` | ✅ Redis | ✅ | Active |
| `FulfillmentStatusConsumer` | `fulfillment.status.changed` | ✅ Redis | ✅ | Active |
| `ReturnConsumer` | `return.completed` | ✅ via error propagation | ✅ | Active |
| `StockCommittedConsumer` | `inventory.stock.committed` | ✅ Redis | ✅ | Active (audit only) |

### 7.2 Cron Jobs (chạy trong Worker pod)

| Job | Schedule | Interval | Timeout | DI wired? |
|-----|----------|----------|---------|-----------|
| `StockChangeDetectorJob` | `"0 * * * * *"` | 1 min | Context | ✅ |
| `StockReconciliationJob` | `"0 0 * * * *"` | 1 hour | 10 min | ✅ |
| `AlertCleanupJob` | via AppConfig | Configurable | 5 min | ✅ |
| `OutboxCleanupJob` | Daily at 3AM (default) | 24h | 10 min (assumed) | ✅ |
| `DailySummaryJob` | Daily | 24h | - | ✅ |
| `WeeklyReportJob` | Weekly | 168h | - | ✅ |
| `ReservationCleanupJob` | `"*/5 * * * *"` | 5 min | 5 min ✅ | Via AppConfig |
| `TimeslotValidatorJob` | `"cron/timeslot_validator_job.go"` | ? | ? | ? |
| `CapacityMonitorJob` | `"cron/capacity_monitor_job.go"` | ? | ? | ? |
| `DailyResetJob` | `"cron/daily_reset_job.go"` | Daily | ? | ? |

> ⚠️ **Lưu ý**: `TimeslotValidatorJob`, `CapacityMonitorJob`, `DailyResetJob` **không có trong `newWorkers()` list** của `wire_gen.go` → chưa được wired vào worker binary! Cần verify.

### 7.3 Continuous Workers

| Worker | Poll Interval | Max Retry | Status |
|--------|--------------|----------|--------|
| `OutboxWorker` | 1s | 5 attempts | ✅ Active |
| `ReservationExpiryWorker` | `expiry/reservation_expiry.go` | Dapr retry | ✅ Active |
| `ReservationWarningWorker` | `expiry/reservation_warning.go` | - | ✅ Active |
| `ImportWorker` | 30s poll | Per-task | ✅ Active |
| `eventbusServerWorker` (gRPC server) | Always on | - | ✅ Active |

---

## ─── PHẦN 8: CHECKLIST HOÀN CHỈNH ───

### P0 — Critical (phải fix trước khi release)

- [x] WH-P0-001: ReservationExpiry không publish event → ✅ FIXED v1
- [x] WH-P0-002: FulfillmentCancelled double inbound TX → ✅ FIXED v1
- [x] WH-P0-003: Outbox FetchPending không SKIP LOCKED → ✅ FIXED v1
- [ ] **WH-P0-NEW**: Verify `TimeslotValidatorJob`, `CapacityMonitorJob`, `DailyResetJob` có được wire vào `newWorkers()` không (nếu không → jobs không chạy)

### P1 — High (reliability)

- [x] WH-P1-001: FIX-3 fulfillment completion → directStockDeduct → ✅ FIXED v1
- [x] WH-P1-002: Worker GitOps probes + secretRef → ✅ FIXED v1
- [⚠️] WH-P1-003: Multi-warehouse return restock → warehouse defensive OK, return service pending
- [x] WH-P1-004: AdjustStock ExecuteRequest idempotency → ✅ FIXED v1
- [x] **WH-P1-NEW-01**: ✅ FIXED — `StockChangeDetectorJob` chuyển sang outbox (thay `eventPublisher`). `publishStockUpdatedEvent` → `outboxRepo.Create`. Wire updated.
- [x] **WH-P1-NEW-02**: ✅ FIXED — `LowStockEvent` trong `triggerStockAlerts` → `outboxRepo.Create` thay vì direct goroutine publish. Pricing service nhận guaranteed delivery.
- [x] **WH-P1-NEW-03**: ✅ FIXED — `BackorderAllocationUsecase` thay `eventPublisher` bằng `outboxRepo`. Cả `warehouse.backorder.allocated` và `warehouse.backorder.fulfilled` giờ dùng outbox trong TX → no phantom events.
- [x] **WH-P1-NEW-04**: ✅ FIXED — `StockReconciliationJob` thay `eventPublisher` bằng `outboxRepo`. Corrective events guaranteed delivery.
- [x] **WH-P1-NEW-05**: ✅ FIXED — `StockReconciliationJob.StopChan()` giờ `close(ch)` ngay → không còn goroutine leak risk.

### P2 — Medium (quality / observability)

- [x] P2-1 (v1): OutboxCleanupJob → ✅ FIXED v1
- [x] P2-2 (v1): FAILED outbox retry endpoint → ✅ FIXED v1
- [x] P2-3 (v1): ExtendReservation race → ✅ FIXED v1
- [x] **P2-NEW-01**: ✅ FIXED — `config.yaml` topics aligned với k8s configmap (`catalog.product.created`, `fulfillment.status.changed`). Thêm `return_completed`, `stock_committed`.
- [x] **P2-NEW-02**: ✅ DOCUMENTED — `StockCommittedConsumer` giữ lại với enhanced structured log `[STOCK_COMMITTED_AUDIT]` + design decision comment. Future: DB audit_log table.
- [x] **P2-NEW-03**: ✅ DOCUMENTED — `PublishDamagedInventory` giữ lại với comment `PLANNED: No active call site`. Không remove để không break mocks.
- [x] **P2-NEW-04**: ✅ FIXED — Thêm `WAREHOUSE_WAREHOUSE_OUTBOX_RETENTION_DAYS: "30"` vào dev configmap. `config.yaml` thêm `outbox_retention_days: 30`.
- [ ] **P2-NEW-05**: Production overlay (`overlays/production/`) — cần verify đầy đủ (out of scope hiện tại)
- [x] **P2-NEW-06**: ✅ FIXED (EC-06) — `ReservationUsecase.ExpireReservation` giờ lưu `reservation_expired` vào outbox trong cùng TX thay vì `PublishReservationExpired` direct.
- [ ] **P2-NEW-07**: EC-08: `AllocateBackorders` — `GetQueueByPriority` thiếu `FOR UPDATE` (cần xem xét thêm)

---

## ─── PHẦN 9: CROSS-SERVICE IMPACT ───

### Services publish event đến Warehouse

| Service | Event | Topic | Verified? |
|---------|-------|-------|-----------|
| Order | `order_status_changed` | `orders.order.status_changed` | ✅ |
| Fulfillment | `fulfillment_status_changed` | `fulfillment.status.changed` (k8s) | ✅ |
| Catalog | `product_created` | `catalog.product.created` (k8s) | ✅ |
| Return (order service?) | `return_completed` | `return.completed` | ✅ |
| Order | `stock_committed` | `inventory.stock.committed` | ✅ (audit only) |

### Services nhận event từ Warehouse

| Service | Event | Topic | Critical? |
|---------|-------|-------|-----------|
| Order | `reservation_expired` | `warehouse.inventory.reservation_expired` | 🔴 Critical — order auto-cancel |
| Catalog | `stock_changed` | `warehouse.inventory.stock_changed` | 🔴 Critical — product visibility |
| Search | `stock_changed` | `warehouse.inventory.stock_changed` | 🔴 Critical — ES out-of-stock filter |
| Pricing | `low_stock` | `warehouse.inventory.low_stock` | 🟡 High — dynamic pricing |
| Notification | `backorder.allocated` | `warehouse.backorder.allocated` | 🟡 — customer notification |

---

## 📝 Ghi chú cho Review Next Steps

1. **Verify**: `TimeslotValidatorJob`, `CapacityMonitorJob`, `DailyResetJob` wire status trong `newWorkers()`
2. **Decision needed**: `StockCommittedConsumer` — giữ hay remove?
3. **Decision needed**: `BackorderAllocation` events — outbox hay accept current direct publish?
4. **Cross-team**: Return service cần include `warehouse_id` trong `ReturnCompletedEvent.Metadata` (WH-P1-003)
5. **Config sync**: Align `config.yaml` topic names với k8s configmap

---

*Checklist này thay thế và mở rộng `inventory-warehouse-flow-review.md` (v1).*
*Tất cả P0 từ v1 đã được fix và verified trong code hiện tại.*

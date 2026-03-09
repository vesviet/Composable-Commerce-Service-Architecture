# Inventory & Warehouse Flows — Business Logic Review Checklist v3

**Date**: 2026-03-07 | **Reviewer**: Senior Engineer (Shopify/Shopee/Lazada patterns)
**Scope**: `warehouse/` — Toàn bộ service: biz, data/eventbus, observer, worker, cron, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §8 (Inventory & Warehouse Flows)
**Supersedes**: `inventory-warehouse-review.md` (v2, 2026-02-26)

---

## 📊 Executive Summary

| Danh mục | Kết quả |
|----------|--------|
| 🔴 P0 — Critical (data loss / stock corruption) | **2 open** (3 đã fix v1, 1 đã fix v2) |
| 🟡 P1 — High (reliability / consistency) | **1 open** (5 đã fix v2) |
| 🔵 P2 — Medium (edge case / observability) | **3 open** (7 đã fix v1/v2) |
| ✅ Đã hoạt động tốt | 25+ areas |

**Cập nhật so với v2**: Xác nhận tất cả P1 từ v2 đã fix trong code. Phát hiện mới: `StockReconciliationJob` & `ReservationCleanupJob` không được wire vào worker, `ProductCreatedConsumer` handler no-op, Production overlay thiếu configmap/secrets.
**Last review date**: 2026-03-07 (code verification)
**Build**: `go build ./...` ✅ | `wire` regenerated ✅

---

## ─── PHẦN 1: DATA CONSISTENCY — NHẤT QUÁN DỮ LIỆU ───

### ✅ Đã xác minh nhất quán

| Cặp dữ liệu | Cơ chế | Mức độ |
|-------------|--------|--------|
| `quantity_reserved` ↔ `StockReservation` rows | `InTx` + `FOR UPDATE` + `IncrementReserved`/`DecrementReserved` | ✅ Atomic |
| `quantity_available` ↔ `quantity_reserved` sau ConfirmReservation | `DecrementAvailable` + `DecrementReserved` trong cùng TX | ✅ Atomic |
| `StockReservation.status` ↔ inventory counters | Mọi state transition đều trong `InTx` | ✅ Atomic |
| Outbox event ↔ stock change | `outboxRepo.Create` trong cùng TX với stock change | ✅ Transactional Outbox |
| Reservation expiry ↔ order auto-cancel | `ExpireReservation` → outbox `reservation_expired` trong TX | ✅ Fixed v2 |
| Fulfillment cancel ↔ inbound TX idempotency | Per-product check trước khi `CreateInboundTransaction` | ✅ |
| Adjustment double-execution | `status == completed` early return guard | ✅ |
| ExtendReservation race | `InTx` + `FindByIDForUpdate` | ✅ |
| **BackorderAllocation events** | `outboxRepo.Create` trong TX — no phantom events | ✅ Fixed v2 |
| **StockChangeDetectorJob** | Outbox thay vì direct publish | ✅ Fixed v2 |
| **StockReconciliationJob** corrections | Outbox thay vì direct publish | ✅ Fixed v2 |
| **LowStockEvent** | Outbox trong `triggerStockAlerts` goroutine | ✅ Fixed v2 |

### ⚠️ Vấn đề nhất quán còn mở

#### 🔴 WH-P0-V3-01: `StockReconciliationJob` KHÔNG được wire vào `newWorkers()` — Job KHÔNG BAO GIỜ chạy

**File**: `cmd/worker/wire_gen.go:108` (line 108: `newWorkers(...)` call)
**Severity**: 🔴 P0

**Vấn đề**: `StockReconciliationJob` được:
- ✅ Defined trong `cron/provider.go:18` (`NewStockReconciliationJob`)
- ✅ Created tại `wire_gen.go:80` (variable unused!)
- ❌ **KHÔNG được truyền vào `newWorkers()` tại line 108**

`newWorkers()` nhận 17 parameters (line 173-191) nhưng **thiếu** `*cron.StockReconciliationJob`. Job được construct nhưng variable bị bỏ rơi — Go compiler không cảnh báo vì nó được create bên trong `wireWorkers` function scope.

**Tác động**: Reconciliation job chạy hourly để detect drift giữa `quantity_reserved` và actual sum từ `inventory_reservations`. Không chạy → drift tích tụ qua thời gian → stock hiển thị sai cho customer (over-sell risk hoặc phantom unavailable stock).

**Fix**:
- [ ] Thêm `stockReconciliationJob *cron.StockReconciliationJob` vào `newWorkers()` params
- [ ] Thêm `stockReconciliationJob` vào call site tại `wire_gen.go:108`
- [ ] Regenerate wire: `cd cmd/worker && wire`

---

#### 🔴 WH-P0-V3-02: `ReservationCleanupJob` KHÔNG được wire vào `newWorkers()` — Expired reservations KHÔNG được cleanup

**File**: `cmd/worker/wire_gen.go:108` + `internal/worker/cron/reservation_cleanup_job.go`
**Severity**: 🔴 P0

**Vấn đề**: Tương tự `StockReconciliationJob`:
- ✅ Defined trong `cron/provider.go:16` (`NewReservationCleanupJob`)
- ❌ **KHÔNG có trong `wire_gen.go`** (thậm chí không được construct!)
- ❌ `ReservationCleanupJob` chỉ có `Start`/`Stop`/`Cleanup` — **thiếu** `Name()`, `HealthCheck()`, `GetBaseWorker()`, `StopChan()` → không implement `worker.ContinuousWorker` interface

**Tác động**: `ReservationExpiryWorker` (expiry/) xử lý individual reservations nhưng `ReservationCleanupJob` là batch processor (every 5 min, batch 100). Nếu `ReservationExpiryWorker` bị lag, `ReservationCleanupJob` là safety net — nhưng nó không chạy!

**Fix**:
- [ ] Thêm methods `Name()`, `HealthCheck()`, `GetBaseWorker()`, `StopChan()` vào `ReservationCleanupJob` (implement `ContinuousWorker`)
- [ ] Add vào `wire.go` inject list + thêm parameter vào `newWorkers()`
- [ ] Regenerate wire: `cd cmd/worker && wire`

---

## ─── PHẦN 2: EVENTS — CÓ THỰC SỰ CẦN PUBLISH KHÔNG? ───

### ✅ Events Warehouse PUBLISH — Đánh giá (Re-verified v3)

| Event | Topic | Cơ chế | Cần thiết? | Ghi chú |
|-------|-------|--------|-----------|--------|
| `warehouse.inventory.stock_changed` | `warehouse.inventory.stock_changed` | Outbox ✅ | **Cần thiết** | Catalog cache invalidate + Search ES update |
| `warehouse.inventory.reservation_expired` | `warehouse.inventory.reservation_expired` | Outbox ✅ | **Cần thiết** | Order service: auto-cancel PENDING order |
| `warehouse.inventory.low_stock` | `warehouse.inventory.low_stock` | Outbox ✅ (fixed v2) | **Cần thiết** | Pricing service dynamic pricing |
| `warehouse.backorder.allocated` | `warehouse.backorder.allocated` | Outbox ✅ (fixed v2) | **Cần thiết** | Notification, Order tracking |
| `warehouse.backorder.fulfilled` | `warehouse.backorder.fulfilled` | Outbox ✅ (fixed v2) | **Cần thiết** | Notification to customer |
| `warehouse.inventory.damaged` | `warehouse.inventory.damaged` | Direct via `PublishDamagedInventory` | **Dead code** | No call site, documented PLANNED |
| `warehouse.inventory.stock_reconciled` | (via `warehouse.inventory.stock_changed`) | Outbox ✅ (fixed v2) | Best-effort | Reconciliation corrections |

### ⚠️ Dead Event: `warehouse.inventory.damaged`

**Status**: 🔵 P2 — Accepted, documented as PLANNED. Giữ lại method để không break mock interface.

---

## ─── PHẦN 3: EVENTS — CÓ THỰC SỰ CẦN SUBSCRIBE KHÔNG? ───

### ✅ Events Warehouse SUBSCRIBE — Đánh giá (Re-verified v3)

| Topic | Consumer | Handler | Cần thiết? | Idempotency |
|-------|----------|---------|-----------|-------------|
| `orders.order.status_changed` | `OrderStatusConsumer` | `ReleaseReservationsByOrderID` khi `cancelled` | **Cần thiết** | ✅ Redis + idempotency |
| `fulfillment.status.changed` | `FulfillmentStatusConsumer` | `HandleFulfillmentStatusChanged` | **Cần thiết** | ✅ Redis + idempotency |
| `catalog.product.created` | `ProductCreatedConsumer` | **No-op handler** ⚠️ | **Cần xem xét** | ✅ idempotency |
| `return.completed` | `ReturnConsumer` | `HandleReturnCompleted` | **Cần thiết** | ✅ (error propagation + Dapr retry) |
| `inventory.stock.committed` | `StockCommittedConsumer` | Audit log only | **Không cần thiết** | ✅ |

### 🟡 WH-P1-V3-01: `ProductCreatedConsumer` handler là No-Op — Không tạo inventory record

**File**: `internal/observer/product_created/warehouse_sub.go:24-31`
**Severity**: 🟡 P1

**Vấn đề**: Handler `WarehouseSub.Handle()` chỉ cast event rồi `return nil` — **không thực hiện bất kỳ business logic nào**:

```go
func (s WarehouseSub) Handle(ctx context.Context, data interface{}) error {
    _, ok := data.(event.ProductCreatedEvent)
    if !ok {
        return errors.New("cannot cast to ProductCreatedEvent")
    }
    return nil // NO BUSINESS LOGIC!
}
```

**Tác động theo Shopify/Shopee pattern**: Khi product mới được tạo trong Catalog, warehouse cần auto-create inventory record (qty=0) để:
1. Admin có thể import stock ngay mà không cần manual create inventory
2. Stock alerts có thể trigger cho products mới (low-stock == zero)
3. `ReserveStock` không fail với "inventory not found" khi customer cố mua sản phẩm mới

**Fix**:
- [ ] Implement handler: `uc.inventoryUsecase.GetOrCreateInventory(ctx, productID, warehouseID)` với qty=0
- [ ] Hoặc: Remove consumer nếu quyết định inventory chỉ tạo qua bulk import/API

---

### 🔵 P2: `StockCommittedConsumer` — Audit-only, xem xét remove

**Status**: Giữ lại với enhanced structured log `[STOCK_COMMITTED_AUDIT]` (documented v2). Future: DB audit_log table.

---

### 🔵 P2-V3-01: Không có handler cho `catalog.product.deleted`

**File**: Không tồn tại consumer
**Severity**: 🔵 P2

**Vấn đề**: Khi product bị xóa khỏi catalog, warehouse vẫn giữ inventory records + active reservations. Từ v2 EC-01, chưa được implement.

**Tác động**: Orphan inventory records, potential phantom reservations.

**Fix**:
- [ ] Subscribe `catalog.product.deleted` → `ReleaseReservationsByProductID` + deactivate inventory

---

## ─── PHẦN 4: RETRY / ROLLBACK / SAGA PATTERN ───

### ✅ Đã triển khai đúng (Re-verified v3)

| Cơ chế | Trạng thái | Ghi chú |
|--------|-----------|--------|
| Transactional Outbox | ✅ | AdjustStock, ConfirmReservation, ReservationExpiry, BackorderAllocation, LowStock, StockChangeDetector, StockReconciliation |
| Outbox retry (max 10 attempts) | ✅ | `outbox_worker.go:144` (`MaxRetries = 10`) |
| Outbox FAILED → admin retry endpoint | ✅ | `POST /admin/outbox/{id}/retry` |
| Outbox `FetchPending` FOR UPDATE SKIP LOCKED | ✅ | Multi-replica safe |
| Outbox stuck PROCESSING recovery | ✅ | `ResetStuckProcessing` (5min timeout) in `processBatch` |
| Outbox metrics (processed/failed counters) | ✅ | Prometheus counters registered |
| Dapr DLQ (`deadLetterTopic`) | ✅ | Configured trên tất cả consumers |
| Consumer idempotency (Redis/GORM) | ✅ | OrderStatus, FulfillmentStatus, ProductCreated, Return, StockCommitted |
| ReserveStock TOCTOU — `InTx` + `FOR UPDATE` | ✅ | |
| ConfirmReservation idempotency (2-level) | ✅ | Status guard + transaction check |
| FulfillmentCancelled inbound TX idempotency | ✅ | Per-product reference check |
| AdjustStock ExecuteRequest idempotency | ✅ | `completed` status guard |
| **GetQueueByPriority FOR UPDATE** | ✅ | `clause.Locking{Strength: "UPDATE"}` — EC-08 resolved |

### ⚠️ Vấn đề

| Vấn đề | File | Severity | Status |
|--------|------|----------|--------|
| StockReconciliationJob không wired → không chạy | `wire_gen.go:108` | 🔴 P0 | **OPEN** |
| ReservationCleanupJob không wired → không chạy | `wire_gen.go:108` | 🔴 P0 | **OPEN** |
| `OutboxWorker.cleanupOldEvents` hardcoded 7 ngày | `outbox_worker.go:115` | 🔵 P2 | OPEN |
| Không có DLQ drain consumer | wire_gen.go | 🔵 P2 | Accepted |

### 🔵 P2-V3-02: `OutboxWorker.cleanupOldEvents` hardcoded 7 ngày — config nói 30 ngày

**File**: `internal/worker/outbox_worker.go:115`
**Severity**: 🔵 P2

**Vấn đề**: `cleanupOldEvents` dùng hardcoded `7 * 24 * time.Hour` trong khi config `outbox_retention_days: 30` và `OutboxCleanupJob` dùng configurable retention. Hai cleanup paths xung đột:
- `OutboxWorker` inline cleanup: every 100 batches, hardcoded 7d
- `OutboxCleanupJob`: daily at 3AM, configurable retention

**Fix**:
- [ ] Remove inline cleanup từ `OutboxWorker` (để `OutboxCleanupJob` handle), hoặc
- [ ] Inject `OutboxRetentionDays` config vào `OutboxWorker`

---

## ─── PHẦN 5: EDGE CASES ───

| # | Edge Case | Risk | Status v3 | Ghi chú |
|---|-----------|------|-----------|--------|
| EC-01 | Product bị xóa khỏi catalog, active reservation | 🔴 High | **OPEN** | Cần `catalog.product.deleted` consumer |
| EC-02 | Partial fulfillment deduct full qty | 🟡 High | **OPEN** | `ConfirmReservation` deduct full — cần partial qty trong event |
| EC-03 | CSV import qty âm | 🔵 Medium | ✅ Fixed v2 | Guard `qty < 0` |
| EC-04 | Stock transfer source hết hàng mid-transfer | 🟡 High | **Accepted** | Cần source reservation check trước complete |
| EC-05 | Multi-warehouse return restock sai WH | 🟡 Partial | **OPEN** | WH defensive OK, Return service chưa include `warehouse_id` |
| EC-06 | ReservationCleanupJob không publish outbox | — | ✅ Fixed v2 | `ExpireReservation` giờ publish outbox |
| EC-07 | ExtendReservation past product expiry | 🔵 Medium | ✅ Fixed v2 | |
| EC-08 | GetQueueByPriority race condition | — | ✅ Fixed v3 | `FOR UPDATE` clause added |
| EC-09 | ImportWorker silent miss khi Operation service down | 🔵 Medium | **Accepted** | Cần exponential backoff |
| EC-10 | OutboxWorker poll 1s DB overload | 🔵 Medium | **Accepted** | Adaptive polling considered |
| **EC-11** | **ProductCreatedConsumer handler no-op** | 🟡 High | **NEW** | Handler returns nil without creating inventory |
| **EC-12** | **ReservationCleanupJob not running** | 🔴 Critical | **NEW** | Not wired + missing ContinuousWorker interface |
| **EC-13** | **StockReconciliationJob not running** | 🔴 Critical | **NEW** | Created but not passed to newWorkers() |

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
| HPA (main): min=2, max=8, CPU 70%, Mem 80% | ✅ | |

### 6.2 Warehouse Worker Deployment

| Check | Status | Chi tiết |
|-------|--------|---------|
| `dapr.io/app-port: "5005"` | ✅ | Worker dùng gRPC |
| `dapr.io/app-protocol: "grpc"` | ✅ | |
| `livenessProbe` + `readinessProbe` (port 8081) | ✅ | |
| `secretRef: warehouse-db-secret` | ✅ | |
| `WORKER_MODE: "true"`, `ENABLE_CRON: "true"`, `ENABLE_CONSUMER: "true"` | ✅ | |
| HPA (worker): min=2, max=8, CPU 70%, Mem 80% | ✅ | |
| `initContainers` (consul, redis, postgres) | ✅ | |

### 6.3 ConfigMap (Re-verified v3)

| Check | Status | Chi tiết |
|-------|--------|---------|
| `overlays-config` dev overlay | ✅ | 80 keys |
| Topic names aligned (config.yaml ↔ configmap) | ✅ Fixed v2 | `catalog.product.created`, `fulfillment.status.changed`, `return.completed`, `inventory.stock.committed` |
| `WAREHOUSE_DATA_EVENTBUS_TOPIC_STOCK_COMMITTED` | ✅ | Present in configmap line 30 |
| `WAREHOUSE_WAREHOUSE_OUTBOX_RETENTION_DAYS: "30"` | ✅ Fixed v2 | Present in configmap line 55 |
| Reservation cleanup config keys | ✅ | `CRON`, `BATCH_SIZE`, `ENABLED` all present |
| base/configmap.yaml minimal | ⚠️ | Base chỉ có `database-url`, `redis-url`, `log-level` — acceptable |

### 6.4 Production Overlay

| Check | Status | Chi tiết |
|-------|--------|---------|
| `overlays/production/kustomization.yaml` exists | ✅ | Có namespace, images, HPA |
| Production configmap | ❌ **MISSING** | Chỉ có HPA + base inherit — production sẽ dùng base configmap (3 keys) thay vì full config |
| Production secrets | ❌ **MISSING** | Không có `warehouse-db-secret` reference trong production overlay |

> **Risk**: Deploy to production sẽ thiếu hầu hết config (eventbus topics, consul, external services, reservation config, alert config...). Base kustomization chỉ có 3 keys.

---

## ─── PHẦN 7: WORKER & CRON JOB INVENTORY ───

### 7.1 Consumers (chạy trong Worker pod) — Re-verified v3

| Consumer | Topic Subscribe | Idempotency | DLQ | Wired? |
|----------|----------------|-------------|-----|--------|
| `OrderStatusConsumer` | `orders.order.status_changed` | ✅ GORM | ✅ | ✅ |
| `ProductCreatedConsumer` | `catalog.product.created` | ✅ GORM | ✅ | ✅ (handler no-op ⚠️) |
| `FulfillmentStatusConsumer` | `fulfillment.status.changed` | ✅ GORM | ✅ | ✅ |
| `ReturnConsumer` | `return.completed` | ✅ error propagation | ✅ | ✅ |
| `StockCommittedConsumer` | `inventory.stock.committed` | ✅ GORM | ✅ | ✅ (audit only) |

### 7.2 Cron Jobs (chạy trong Worker pod) — Re-verified v3

| Job | Schedule | Wired in `newWorkers()`? | Status |
|-----|----------|--------------------------|--------|
| `StockChangeDetectorJob` | 1 min | ✅ | Active |
| `StockReconciliationJob` | 1 hour | ❌ **NOT WIRED** | 🔴 Created but var unused |
| `AlertCleanupJob` | configurable | ✅ | Active |
| `OutboxCleanupJob` | daily 3AM | ✅ | Active |
| `DailySummaryJob` | daily | ✅ | Active |
| `WeeklyReportJob` | weekly | ✅ | Active |
| `DailyResetJob` | daily | ✅ | Active |
| `CapacityMonitorJob` | configurable | ✅ | Active |
| `TimeSlotValidatorJob` | configurable | ✅ | Active |
| `ReservationCleanupJob` | */5 min | ❌ **NOT WIRED** | 🔴 Not constructed, missing interface |

### 7.3 Continuous Workers — Re-verified v3

| Worker | Poll Interval | Max Retry | Wired? |
|--------|--------------|----------|--------|
| `OutboxWorker` | 1s | 10 attempts | ✅ |
| `ReservationExpiryWorker` | continuous | Dapr retry | ✅ |
| `ReservationWarningWorker` | continuous | - | ✅ |
| `ImportWorker` | 30s poll | Per-task | ❌ Not in wire_gen (separate binary?) |
| `eventbusServerWorker` (gRPC server) | Always on | - | ✅ |

---

## ─── PHẦN 8: CHECKLIST HOÀN CHỈNH ───

### P0 — Critical (phải fix trước khi release)

- [x] WH-P0-001: ReservationExpiry không publish event → ✅ FIXED v1
- [x] WH-P0-002: FulfillmentCancelled double inbound TX → ✅ FIXED v1
- [x] WH-P0-003: Outbox FetchPending không SKIP LOCKED → ✅ FIXED v1
- [x] WH-P0-NEW (v2): Verify `TimeslotValidatorJob`, `CapacityMonitorJob`, `DailyResetJob` → ✅ WIRED in v3 verification
- [ ] **WH-P0-V3-01**: `StockReconciliationJob` NOT in `newWorkers()` — job never runs. Cần wire vào worker binary.
- [ ] **WH-P0-V3-02**: `ReservationCleanupJob` NOT wired — missing `ContinuousWorker` interface methods + not constructed in wire_gen.

### P1 — High (reliability)

- [x] WH-P1-001: fulfillment completion → directStockDeduct → ✅ FIXED v1
- [x] WH-P1-002: Worker GitOps probes + secretRef → ✅ FIXED v1
- [⚠️] WH-P1-003: Multi-warehouse return restock → warehouse defensive OK, return service pending
- [x] WH-P1-004: AdjustStock ExecuteRequest idempotency → ✅ FIXED v1
- [x] WH-P1-NEW-01 (v2): StockChangeDetectorJob → outbox ✅
- [x] WH-P1-NEW-02 (v2): LowStockEvent → outbox ✅
- [x] WH-P1-NEW-03 (v2): BackorderAllocationUsecase → outbox ✅
- [x] WH-P1-NEW-04 (v2): StockReconciliationJob → outbox ✅
- [x] WH-P1-NEW-05 (v2): StopChan() fix → ✅
- [ ] **WH-P1-V3-01**: `ProductCreatedConsumer` handler no-op — `WarehouseSub.Handle()` returns nil without creating inventory record

### P2 — Medium (quality / observability)

- [x] P2-NEW-01 (v2): config.yaml topics aligned ✅
- [x] P2-NEW-02 (v2): StockCommittedConsumer documented ✅
- [x] P2-NEW-03 (v2): PublishDamagedInventory documented PLANNED ✅
- [x] P2-NEW-04 (v2): OUTBOX_RETENTION_DAYS in configmap ✅
- [x] P2-NEW-06 (v2): ExpireReservation outbox ✅
- [x] P2-NEW-07 (v2): GetQueueByPriority FOR UPDATE → ✅ FIXED (clause.Locking added)
- [ ] **P2-NEW-05 (v2)**: Production overlay missing configmap/secrets
- [ ] **P2-V3-01**: No handler for `catalog.product.deleted`
- [ ] **P2-V3-02**: `OutboxWorker.cleanupOldEvents` hardcoded 7d vs config 30d

---

## ─── PHẦN 9: CROSS-SERVICE IMPACT ───

### Services publish event đến Warehouse

| Service | Event | Topic | Verified? |
|---------|-------|-------|-----------|
| Order | `order_status_changed` | `orders.order.status_changed` | ✅ |
| Fulfillment | `fulfillment_status_changed` | `fulfillment.status.changed` | ✅ |
| Catalog | `product_created` | `catalog.product.created` | ✅ (handler no-op ⚠️) |
| Return | `return_completed` | `return.completed` | ✅ |
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

## 📝 Action Items (Prioritized)

### Immediate (P0/P1 — trước khi release)

1. **Wire `StockReconciliationJob`** vào `newWorkers()` trong `cmd/worker/wire.go` + regenerate wire
2. **Wire `ReservationCleanupJob`** — implement `ContinuousWorker` interface + add to `wire.go` + regenerate
3. **Implement `ProductCreatedConsumer` handler** — `GetOrCreateInventory(ctx, productID, defaultWarehouseID)` hoặc remove consumer

### Next Sprint (P2)

4. Production overlay cần configmap + secrets giống dev overlay
5. Remove/unify OutboxWorker inline cleanup (7d hardcode conflict)
6. Consider `catalog.product.deleted` consumer
7. **Cross-team**: Return service cần include `warehouse_id` trong `ReturnCompletedEvent.Metadata` (WH-P1-003)

---

*Checklist v3 thay thế v2 (2026-02-26). Xác nhận tất cả P1 từ v2 đã fix trong code hiện tại.*
*Phát hiện 2 P0 mới (unwired jobs) và 1 P1 mới (no-op handler).*

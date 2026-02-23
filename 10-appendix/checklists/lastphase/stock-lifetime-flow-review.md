# Stock Lifetime Flow Review (Last Phase)

> Review theo patterns của Shopify (inventory availability, reservation), Shopee (multi-warehouse), Lazada (real-time sync).
> Thời điểm review: 2026-02-20

---

## 1. Mức độ chuẩn hoá (Standardization)

Service **Warehouse** là core inventory engine, được thiết kế rất tốt:
- Clean Architecture rõ ràng: `biz/inventory/`, `biz/reservation/`, `biz/alert/`, `biz/backorder/`
- **Outbox Pattern** được triển khai đúng: `ConfirmReservation` và `UpdateInventory` lưu event vào outbox table cùng DB transaction.
- **OutboxWorker** poll mỗi 1s, retry 5 lần, đánh `FAILED` sau max retries.
- **Observer Pattern** (observerManager) dùng để route events từ consumers sang biz handlers — loose coupling tốt.
- **IdempotencyHelper** dùng nhất quán ở TẤT CẢ 4 consumers của warehouse.
- **FOR UPDATE lock** dùng trong `ReserveStock` và `ExpireReservation` — chống TOCTOU race condition tốt.
- **Double-deduction guard** trong `ConfirmReservation`: check `transactionRepo.GetByReference` trước khi deduct — rất an toàn.
- **ReservationCleanupJob** cron 5 phút, batch 100, có config granular theo từng payment method (COD 24h, e_wallet 15m, v.v.).

---

## 2. Sự nhất quán dữ liệu giữa các service

### ✅ Đã tốt
- `warehouse.inventory → catalog Redis cache`: Catalog `StockConsumer` dùng SET (không phải DEL-then-wait) → không có cache stampede window.
- `warehouse → order`: Order service nhận `warehouse.inventory.stock_changed` qua outbox, consumer có idempotency.
- `warehouse → fulfillment`: FulfillmentStatusConsumer trong warehouse có idempotency và DLQ metadata.
- Stock reservation → stock deduction: Atomicity đảm bảo bởi `ConfirmReservation` chạy trong `InTx`.

### ⚠️ Cần chú ý
| # | Điểm rủi ro | Ảnh hưởng |
|---|-------------|-----------|
| D1 | **`CompleteReservation` không dùng transaction bao quát**: `repo.Update(reservation, fulfilled)` và `DecrementReserved` là 2 lời gọi riêng biệt, KHÔNG nằm trong `InTx`. Nếu `DecrementReserved` fail sau `Update` succeeded → reservation "fulfilled" nhưng `quantity_reserved` không giảm → số liệu lệch. | **P1** |
| D2 | **`ReleaseReservationsByOrderID` silently continues on error**: Khi release nhiều reservation, nếu 1 reservation fail, code chỉ log lỗi và `continue` — không có DLQ hay retry. Tổng stock reserved có thể bị lệch nếu một số reservation không release được. | **P1** |
| D3 | **Return restock không atomic và không có DLQ**: `HandleReturnCompleted` gọi `CreateInboundTransaction` per-item trong vòng lặp. Nếu 1 item fail → chỉ log error và `continue`, item đó mất. Không có outbox/DLQ fallback. | **P1** |
| D4 | **Pricing `StockConsumer` không có idempotency**: Handler `HandleStockUpdate` xử lý event ngay, không check đã processed chưa. Nếu Dapr tái deliver (at-least-once), giá cập nhật theo stock có thể bị apply 2 lần. | **P2** |

---

## 3. Có trường hợp nào dữ liệu bị lệch (Mismatched) không?

### Tình huống lệch thực tế:

**M1 – `quantity_reserved` drift sau `CompleteReservation` fail giữa 2 bước (D1)**
```
reservation.status = "fulfilled"  ← thành công
inventoryRepo.DecrementReserved() ← fail (network/DB)
→ quantity_reserved tăng vĩnh cửu, availableStock = QuantityAvailable - QuantityReserved sai
```

**M2 – Phantom restock sau return (D3)**
```
Return event có 3 items: item A, B, C
CreateInboundTransaction(A) OK
CreateInboundTransaction(B) FAIL → log.Error, continue
CreateInboundTransaction(C) OK
→ item B không được restock, stock lệch, không trace được không retry được
```

**M3 – Double cancel reservation (D2)**
```
OrderCancelled event → ReleaseReservationsByOrderID → reservation[0] OK, reservation[1] FAIL
→ next retry lại toàn bộ → reservation[0] bị release 2 lần nếu ReleaseReservation không check status
→ (safe vì có status != "active" guard, nhưng DLQ alert không tồn tại)
```

**M4 – Topic name mismatch giữa services (xem mục 5)**

---

## 4. Cơ chế Retry / Rollback / Saga / Outbox

### ✅ Đã triển khai đúng
- **Outbox**: `ConfirmReservation` + `UpdateInventory` → lưu event vào DB trong cùng transaction → OutboxWorker publish
- **OutboxWorker retry**: 5 lần với PENDING state, sau đó FAILED (có Prometheus metric để alert)
- **Dapr DLQ metadata**: Tất cả consumers đều set `deadLetterTopic: <topic>.dlq`
- **Saga Compensation** (từ Order service): Khi payment fail → `ReleaseReservationsByOrderID` gRPC → fallback DLQ

### ❌ Chưa triển khai / có lỗ hổng

| # | Vấn đề | Mức độ |
|---|--------|--------|
| R1 | **Return restock không có outbox/DLQ**: `HandleReturnCompleted` publish event trực tiếp (không qua outbox), và khi fail chỉ `continue` | **P1** |
| R2 | **`ReleaseReservationsByOrderID` không có retry**: Nếu 1 reservation fail release, không có mechanism để retry sau. DLQ từ Order service chỉ bao gồm `release_reservations` ở cấp OrderID, không per-reservation | **P1** |
| R3 | **OutboxWorker FAILED state không tự recover**: Khi event đạt `FAILED` (5 retries), không có cron job hay Ops API để retry lại. Warehouse thiếu DLQ Admin API như Order service | **P2** |
| R4 | **Không có dead letter consumer cho warehouse events**: Catalog, Pricing, Search nhận `<topic>.dlq` nhưng không có consumer/monitor xử lý những event bị DLQ | **P2** |

---

## 5. Check Event Pub/Sub — Service có thực sự cần publish/subscribe không?

### Publishers (Warehouse → Others)

| Topic | Publisher | Có cần không? | Ghi chú |
|-------|-----------|---------------|---------|
| `warehouse.inventory.stock_changed` | Warehouse (OutboxWorker) | ✅ **Cần** | Catalog, Search, Pricing, Order consume |
| `warehouse.inventory.reservation_expired` | Warehouse EventPublisher | ✅ **Cần** | Order cần biết để cancel nếu chưa thanh toán |
| `warehouse.inventory.damaged` | Warehouse EventPublisher | ✅ **Cần** | Analytics/Review tracking |
| `warehouse.backorder.*` (created/allocated/fulfilled/cancelled) | Warehouse (chưa rõ) | ⚠️ **Chưa thấy consumer** | Struct định nghĩa nhưng không thấy bên nào subscribe |
| `warehouse.inventory.low_stock` | ❌ **KHÔNG tìm thấy publisher** | Nguy hiểm | Pricing subscribe `warehouse.inventory.low_stock` nhưng Warehouse không publish topic này! |

### Subscribers (Others → Warehouse)

| Service | Topic | Có cần không? | Ghi chú |
|---------|-------|---------------|---------|
| Warehouse ← Order | `order.status.changed` | ✅ **Cần** | Khi order cancelled → release reservation |
| Warehouse ← Fulfillment | `fulfillment.status.changed` | ✅ **Cần** | Khi shipped → confirm reservation deduction |
| Warehouse ← Return | `orders.return.completed` | ✅ **Cần** | Restock returned items |
| Warehouse ← Catalog | `catalog.product.created` | ✅ **Cần** | Auto-create inventory slot khi có sản phẩm mới |
| Catalog ← Warehouse | `warehouse.inventory.stock_changed` | ✅ **Cần** | Cache invalidation/update |
| Pricing ← Warehouse | `warehouse.inventory.stock_changed` | ✅ **Cần** | Low stock pricing rules |
| Pricing ← Warehouse | `warehouse.inventory.low_stock` | ❌ **Wasted** | Warehouse KHÔNG publish topic này → subscriber vô nghĩa |
| Search ← Warehouse | `warehouse.inventory.stock_changed` | ✅ **Cần** | Update Elasticsearch availability |

---

## 6. Check Topic Name Consistency

| Service | Topic được dùng | Constant/Config |
|---------|----------------|-----------------|
| Warehouse publisher | `warehouse.inventory.stock_changed` | hardcoded string |
| Catalog consumer | `warehouse.inventory.stock_changed` (từ `constants.TopicWarehouseInventoryStockChanged`) | OK |
| Pricing consumer | `warehouse.inventory.stock_changed` | hardcoded string (khác cách catalog dùng constant) |
| Search consumer | `warehouse.inventory.stock_changed` (từ `constants.TopicWarehouseInventoryStockChanged`) | OK |
| Warehouse consumer (order topic) | từ `c.config.Data.Eventbus.Topic.OrderStatusChanged` | bắt buộc có trong config |
| Return consumer default fallback | `"orders.return.completed"` | hardcoded fallback — khác với pattern `return.completed` dùng ở nơi khác |

**Risk T1**: Pricing dùng hardcoded topic string thay vì constants — dễ typo lúc refactor.
**Risk T2**: Return consumer có cả config topic lẫn fallback hardcoded `"orders.return.completed"` — phải verify config GitOps khớp topic mà Return service publish.

---

## 7. Check Config GitOps

### Warehouse GitOps — `gitops/apps/warehouse/base/configmap.yaml`

| Kiểm tra | Kết quả |
|----------|---------|
| Plaintext DB credentials trong base configmap | **🔴 P0**: `database-url: "postgres://warehouse_user:warehouse_pass@..."` — phải dùng External Secrets / Vault |
| Plaintext Redis URL (no password) | **🔴 P0**: Production Redis có auth không? configmap có `redis-url: "redis://redis:6379/0"` không có password |
| Port HTTP/gRPC | ✅ Dev overlay: `8006`/`9006` khớp PORT_ALLOCATION_STANDARD |
| Reservation expiry configs | ✅ Dev overlay có đủ COD 24h, e_wallet 15m, credit_card 30m, bank_transfer 4h, installment 2h |
| Dapr pubsub name | ✅ `WAREHOUSE_DATA_EVENTBUS_DEFAULT_PUBSUB: "pubsub-redis"` nhất quán |
| Reservation cleanup cron | ✅ `*/5 * * * *` |
| External service URLs | ✅ catalog, user, notification endpoints có đủ |
| Event topics trong config | ⚠️ Dev overlay không có `WAREHOUSE_DATA_EVENTBUS_TOPIC_*` entries → warehouse phải fallback nội bộ hoặc dùng hardcoded strings |
| Worker secretRef | ⚠️ Chưa verify worker deployment có `secretRef` cho DB password không |

---

## 8. Check Worker & Cron Jobs

### Warehouse Worker binary

| Worker/Job | Schedule | Mô tả | Risk |
|-----------|----------|--------|------|
| OutboxWorker | Poll 1s | Publish pending outbox events | ✅ OK, 5 retries, FAILED metric |
| ReservationCleanupJob | */5 * * * * | Expire hết active reservations quá TTL | ⚠️ `context.Background()` trong cron func — không có parent ctx/timeout |
| AlertCleanupJob | Cấu hình riêng | Cleanup old stock alerts | ✅ |
| CapacityMonitorJob | Cấu hình riêng | Monitor warehouse throughput capacity | ✅ |
| DailyResetJob | Cấu hình riêng | Reset daily counters | ✅ |
| DailySummaryJob | Cấu hình riêng | Daily summary report | ✅ |
| StockChangeDetectorJob | Cấu hình riêng | Detect stock anomalies | ✅ |
| TimeslotValidatorJob | Cấu hình riêng | Validate warehouse time slots | ✅ |
| WeeklyReportJob | Cấu hình riêng | Weekly inventory report | ✅ |
| ImportWorker | On-demand | Bulk stock import | ✅ |

**Ghi chú**:
- `ReservationCleanupJob` dùng `context.Background()` khi chạy cleanup → nếu DB slow, job không có timeout → có thể block lâu nhưng không cancel được.
- Cần verify `expiry_worker` (ExpiryWorker) ở `internal/worker/expiry/` được start trong worker binary không.

---

## 9. Liệt kê Edge Cases chưa xử lý

| # | Edge Case | Dịch vụ | Mức độ |
|---|-----------|---------|--------|
| E1 | **ReserveStock khi `ExpiresAt` nil và `PaymentMethod` nil**: Reservation được tạo với `ExpiresAt = nil` → không bao giờ expire → inventory bị lock vĩnh viễn | Warehouse | **P1** |
| E2 | **Multi-warehouse stock check**: Khi 1 product có inventory ở nhiều warehouse, không có cơ chế aggregate available stock — caller phải specify warehouse_id. Checkout có thể reserve ở warehouse không optimal | Warehouse/Checkout | **P2** |
| E3 | **Return restock chọn wrong warehouse**: Nếu `warehouse_id` không có trong event metadata, code lấy `inventories[0]` — có thể restock vào sai warehouse (nếu 1 product có inventory ở nhiều nơi) | Warehouse | **P1** |
| E4 | **Concurrent `ConfirmReservation` và `ExpireReservation`**: FOR UPDATE lock fix race condition, nhưng nếu reservation đang trong confirmed transaction và cron cleanup chạy đúng lúc → cron sẽ blocked đến khi TX commit. Nếu TX rollback, cron cần re-check status. OK nhưng cần verify timeout của cron không nhỏ hơn TX timeout | Warehouse | **P2** |
| E5 | **Backorder events không có consumer**: `BackorderCreatedEvent`, `BackorderAllocatedEvent`, etc. được định nghĩa nhưng không có service nào consume → backorder customer notification bị mất | Notification/Order | **P1** |
| E6 | **`ConfirmReservations` gọi từ Order khi Warehouse down**: Order service có retry 3 lần với exponential backoff và DLQ cho `release_reservations`, nhưng **confirm** path khi payment success chưa thấy DLQ record rõ ràng | Order | **P1** |
| E7 | **Stock version/sequence number không dùng để detect out-of-order events**: `StockUpdatedEvent` có `SequenceNumber` từ `inventory.Version`, nhưng Catalog/Pricing/Search không check sequence → có thể apply old event sau new event (stale update) | Catalog/Pricing/Search | **P2** |
| E8 | **Pricing subscribe `low_stock` topic chưa được publish**: `ConsumeStockEvents` subscribe cả `warehouse.inventory.low_stock` nhưng warehouse chưa publish topic này → subscriber idle. Nếu sau này enable, không có schema validation contract | Pricing/Warehouse | **P2** |
| E9 | **`DecrementReserved` dùng `warehouse_id/product_id` string làm key**: Trong `ReleaseReservation`, đầu tiên gọi `DecrementReserved` với `res.WarehouseID.String()+"/"+res.ProductID.String()` — nếu repo implementation parse key này sai → silent fail, fallback sang FindByWarehouseAndProduct. Fragile. | Warehouse | **P2** |
| E10 | **Import Worker không có idempotency**: `import_worker.go` bulk import stock — nếu fail giữa chừng và retry, một số SKU có thể bị import 2 lần → stock inflation | Warehouse | **P1** |

---

## 10. Checklist nghiệm thu Stock Lifetime Flow

### P0 — Critical (Blocks Prod)
- [ ] **P0-1**: Xóa plaintext DB credentials ra khỏi `gitops/apps/warehouse/base/configmap.yaml` → dùng External Secrets Operator (Vault)
- [ ] **P0-2**: Kiểm tra Redis production có auth password không, nếu có thì config overlay phải dùng Secret

### P1 — High (Impacts Reliability)
- [ ] **P1-1**: Wrap `CompleteReservation` bước `repo.Update` + `DecrementReserved` vào cùng 1 transaction (`InTx`)
- [ ] **P1-2**: Thêm outbox/DLQ cho `HandleReturnCompleted` — khi restock fail cho 1 item, ghi vào outbox để retry thay vì silent `continue`
- [ ] **P1-3**: `ReleaseReservationsByOrderID` — thêm DLQ record khi release fail (giống pattern của Order service `FailedCompensation`)
- [ ] **P1-4**: Thêm default `ExpiresAt` khi cả `ExpiresAt` và `PaymentMethod` đều nil trong `ReserveStock` — tránh lock inventory vĩnh viễn
- [ ] **P1-5**: Fix return restock warehouse selection: thêm `warehouse_id` bắt buộc trong `ReturnCompletedEvent` schema, không dùng `inventories[0]`
- [ ] **P1-6**: Implement hoặc remove Backorder event consumers — nếu backorder feature live, Notification/Order phải consume events
- [ ] **P1-7**: Verify `ConfirmReservation` (khi payment success) có DLQ/outbox nếu warehouse gRPC call fail từ Order side

### P2 — Medium (Quality/Observability)
- [x] **P2-1**: Thêm idempotency check vào `Pricing.StockConsumer.HandleStockUpdate` — dùng CloudEvent ID + sync.Map (5 min TTL)
- [x] **P2-2**: Thêm Ops Admin API để retry FAILED outbox events trong warehouse — `GET /admin/outbox/failed`, `POST /admin/outbox/{id}/retry`
- [ ] **P2-3**: Implement consumer cho `<topic>.dlq` topics ở catalog/pricing để alert/monitor (Search đã có ✅)
- [x] **P2-4**: Dùng constants thay vì hardcoded strings cho topic names trong Pricing service
- [x] **P2-5**: Verify topic `orders.return.completed` trong Return service publisher khớp với config trong warehouse consumer
- [x] **P2-6**: Thêm context timeout cho `ReservationCleanupJob.Cleanup` thay vì `context.Background()`
- [x] **P2-7**: Implement `SequenceNumber`/version check trong Catalog/Pricing/Search consumers để tránh stale update
- [x] **P2-8**: Warehouse publish `warehouse.inventory.low_stock`; Pricing subscribe để trigger dynamic pricing
- [x] **P2-9**: Refactor `DecrementReserved` để nhận `inventory_id` trực tiếp thay vì parse composite string key
- [ ] **P2-10**: Thêm idempotency cho Import Worker (check import_batch_id trước khi insert)
- [ ] **P2-11**: Verify warehouse worker deployment.yaml có `secretRef` (DB password) để worker binary có thể kết nối DB

---

## 11. Kết luận

Warehouse service có kiến trúc **rất tốt** — Outbox, FOR UPDATE lock, double-deduction guard, idempotency helpers, cron cleanup đều được triển khai đúng bản chất.

**Điểm ưu tú nhất**: `ConfirmReservation` với FOR UPDATE + double guard + outbox in same TX — đây là standard của Shopify/Shopee.

**Điểm yếu nhất**: Return restock path và CompleteReservation là 2 nơi có nguy cơ data drift thực tế nhất. Cần fix P1-1, P1-2, P1-5 trước khi prod.

**Cần làm gấp**: P0-1 (plaintext DB credentials trong GitOps) — không thể để credentials trong git.

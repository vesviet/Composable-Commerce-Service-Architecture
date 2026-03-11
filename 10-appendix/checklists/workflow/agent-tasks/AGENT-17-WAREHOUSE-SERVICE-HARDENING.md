# AGENT-17: Warehouse Service Hardening (10-Round Review Findings)

**Assignee:** Agent 17  
**Service:** Warehouse Service  
**Status:** COMPLETED ✅

## 📝 Objective
Resolve P0 (Critical), P1 (High), and P2 (Nice to Have) issues identified during the 10-Round Meeting Review for the Warehouse service. This hardening task focuses on concurrency bugs, outbox event atomicity, pagination performance, and gRPC bottlenecks.

---

## 🚩 P0 - Critical Issues (Blocking)

### [x] 1. `ExpireReservation` Optimistic Lock Drop (Concurrency & Idempotency) ✅ ALREADY IMPLEMENTED
- **File:** `warehouse/internal/biz/reservation/reservation.go`
- **Method:** `ExpireReservation` (lines 811-890)
- **Verification:** Code already uses `FindByWarehouseAndProductForUpdate` (pessimistic lock, line 842) + `DecrementReserved` (line 851) inside an `InTx` block. No `UpdateStockWithVersion` (optimistic) is used.
- **Evidence:**
  ```go
  // Line 842 — pessimistic lock already in place
  inventory, err := uc.inventoryRepo.FindByWarehouseAndProductForUpdate(txCtx, reservation.WarehouseID.String(), reservation.ProductID.String())
  // Line 851 — safe decrement under lock
  if err := uc.inventoryRepo.DecrementReserved(txCtx, inventory.ID.String(), reservation.QuantityReserved); err != nil {
  ```
- **Status:** No code change needed — already fixed in a prior hardening pass.

### [x] 2. `StockReconciliationJob` Incomplete Outbox Atomicity (Resilience) ✅ ALREADY IMPLEMENTED
- **File:** `warehouse/internal/worker/cron/stock_reconciliation_job.go`
- **Method:** `reconcile` (line 219)
- **Verification:** The `outboxRepo.Create()` failure already returns `fmt.Errorf("reconciliation outbox error: %w", saveErr)`, which correctly aborts the transaction and rolls back the inventory updates.
- **Evidence:**
  ```go
  // Line 218-219
  } else if saveErr := j.outboxRepo.Create(txCtx, &repoOutbox.OutboxEvent{...}); saveErr != nil {
      return fmt.Errorf("reconciliation outbox error: %w", saveErr)
  }
  ```
- **Status:** No code change needed — already fixed in a prior hardening pass.

---

## 🟡 P1 - High Priority

### [x] 3. Warehouse Utilization N+1 gRPC Bottleneck (Performance) ✅ ALREADY IMPLEMENTED
- **File:** `warehouse/internal/biz/inventory/inventory_utils.go`
- **Method:** `updatePhysicalUtilization` (lines 29, 38-48)
- **Verification:** A local `dimCache := make(map[string]*ProductDimensions)` (line 29) is already used to deduplicate gRPC calls. The cache is checked before calling `GetProductDimensions` (lines 38-48).
- **Evidence:**
  ```go
  dimCache := make(map[string]*ProductDimensions) // line 29
  // ...
  pid := inventory.ProductID.String()
  dimensions, ok := dimCache[pid]
  if !ok {
      dimensions, err = uc.catalogClient.GetProductDimensions(ctx, pid)
      dimCache[pid] = dimensions
  }
  ```
- **Status:** No code change needed — already implemented.

### [x] 4. Missing Cursor Pagination in `GetLowStockItems` (Database) ✅ ALREADY IMPLEMENTED
- **File:** `warehouse/internal/biz/inventory/inventory_query.go` (line 36)
- **Verification:** The biz layer `GetLowStockItems` already delegates to `GetLowStockItemsCursor`:
  ```go
  func (uc *InventoryUsecase) GetLowStockItems(ctx context.Context, warehouseID *string, cursorReq *pagination.CursorRequest) ([]*model.Inventory, *pagination.CursorResponse, error) {
      return uc.repo.GetLowStockItemsCursor(ctx, warehouseID, cursorReq)
  }
  ```
- **Status:** No code change needed — already migrated to cursor pagination.

---

## 🔵 P2 - Nice to Have

### [x] 5. OrderStatusConsumer Missing DeadLetter Metrics (Observability) ✅ SKIPPED (Per Task Spec)
- **File:** `warehouse/internal/data/eventbus/order_status_consumer.go`
- **Verification:** The `OrderStatusConsumer` struct does NOT have a `metrics` field injected. Task spec explicitly states: _"If no metric service is injected in the consumer constructor, skip this task."_
- **Status:** Skipped per task specification — no `WarehouseServiceMetrics` dependency in consumer.

### [x] 6. Hardcoded Status Strings (Code Quality) ✅ ALREADY IMPLEMENTED
- **File:** `warehouse/internal/biz/reservation/reservation.go`
- **Verification:** All status comparisons use `model.ReservationStatus*` constants defined in `warehouse/internal/model/inventory.go`:
  ```go
  ReservationStatusActive    = "active"
  ReservationStatusFulfilled = "fulfilled"
  ReservationStatusExpired   = "expired"
  ReservationStatusCancelled = "cancelled"
  ReservationStatusPartial   = "partial"
  ```
  Grep for raw `"active"`, `"expired"`, `"fulfilled"` strings in `reservation.go` returns zero matches — all replaced with constants.
- **Status:** No code change needed — already using constants.

---

## 🔧 Pre-Commit Checklist

```bash
cd warehouse && go build ./...              # ✅ passed
cd warehouse && go test -race ./...         # ✅ passed
cd warehouse && golangci-lint run ./...     # ✅ passed (zero errors)
```

---

## ✅ ACCEPTANCE CRITERIA
- [x] No `fmt.Errorf` strings dropped in `stock_reconciliation_job.go` outbox writes. ✅
- [x] `ExpireReservation` runs entirely under `FOR UPDATE` lock logic and doesn't rely on `UpdateStockWithVersion`. ✅
- [x] Local map caching is used in `updatePhysicalUtilization` to avoid duplicate N+1 gRPC requests per product. ✅
- [x] Code passes all tests and linting (`golangci-lint run ./warehouse/...`). ✅

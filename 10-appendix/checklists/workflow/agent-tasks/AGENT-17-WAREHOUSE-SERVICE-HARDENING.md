# AGENT-17: Warehouse Service Hardening (10-Round Review Findings)

**Assignee:** Agent 17  
**Service:** Warehouse Service  
**Status:** BACKLOG

## 📝 Objective
Resolve P0 (Critical), P1 (High), and P2 (Nice to Have) issues identified during the 10-Round Meeting Review for the Warehouse service. This hardening task focuses on concurrency bugs, outbox event atomicity, pagination performance, and gRPC bottlenecks.

---

## 🚩 P0 - Critical Issues (Blocking)

### 1. `ExpireReservation` Optimistic Lock Drop (Concurrency & Idempotency)
- **File:** `warehouse/internal/biz/reservation/reservation.go`
- **Method:** `ExpireReservation`
- **Issue:** Currently, releasing reserved stock uses optimistic locking (`UpdateStockWithVersion`). If this fails due to a version mismatch, the error is returned immediately and logged by the consumer, dropping the outbox event and leaving the reservation active to be retried 5 minutes later.
- **Action:** 
  1. Change to use pessimistic locking (`FindByWarehouseAndProductForUpdate`) within the `InTx` block to ensure stock can always be released safely without retries.
  2. Modify the logic to deduct `reservation.QuantityReserved` safely while holding the row lock.
- **Validation:** 
  - `go test -v -run TestExpireReservation ./warehouse/internal/biz/reservation`

### 2. `StockReconciliationJob` Incomplete Outbox Atomicity (Resilience)
- **File:** `warehouse/internal/worker/cron/stock_reconciliation_job.go`
- **Method:** `reconcile` (inside the `j.tx.InTx` block)
- **Issue:** If `j.outboxRepo.Create()` fails, the worker simply logs `saveErr` and returns `nil`. This commits the inventory table updates but drops the outbox event, leading to search and catalog sync discrepancies.
- **Action:** 
  1. Modify the error handling for `j.outboxRepo.Create(txCtx, ...)` to return `fmt.Errorf("reconciliation outbox error: %w", saveErr)`.
  2. This will ensure the transaction correctly rolls back if the outbox event fails to persist.
- **Validation:** 
  - `go test -v -run TestStockReconciliationJob ./warehouse/internal/worker/cron`

---

## 🟡 P1 - High Priority

### 3. Warehouse Utilization N+1 gRPC Bottleneck (Performance)
- **File:** `warehouse/internal/biz/inventory/inventory_utils.go`
- **Method:** `updatePhysicalUtilization`
- **Issue:** Uses a `for` loop over all inventory items in a warehouse, calling `GetProductDimensions` via gRPC for *every single item* completely synchronously. This creates N+1 latency spikes when reconciling warehouse utilization.
- **Action:**
  1. This is a heavy calculation. Skip the loop optimization for now, BUT wrap the gRPC call `uc.catalogClient.GetProductDimensions` with an in-memory cache check, or aggregate product IDs to batch fetch dimensions if `CatalogClient` supports it.
  2. (Alternatively), add a local `map[string]*ProductDimensions` within the function to deduplicate gRPC calls for the same product in a single run.
- **Validation:** 
  - Implement a basic caching map and run `go test -v ./warehouse/internal/biz/inventory`

### 4. Missing Cursor Pagination in `GetLowStockItems` (Database)
- **File:** `warehouse/internal/repository/inventory/inventory.go` (and `warehouse/internal/data/postgres/inventory.go`)
- **Method:** `GetLowStockItems`
- **Issue:** Uses `offset` and `limit` for retrieving low stock items, which is slow and skips items.
- **Action:** 
  1. Since `GetLowStockItemsCursor` is already implemented in the postgres adapter, replace `GetLowStockItems` usages in the business logic (e.g., workers/alert systems) with `GetLowStockItemsCursor`.
  2. Check `warehouse/internal/biz/inventory` and `warehouse/internal/worker` for usages of `offset`/`limit` in low stock tracking.
- **Validation:** 
  - `go test -v -run TestGetLowStockItems ./warehouse/internal/data/postgres`

---

## 🔵 P2 - Nice to Have

### 5. OrderStatusConsumer Missing DeadLetter Metrics (Observability)
- **File:** `warehouse/internal/data/eventbus/order_status_consumer.go`
- **Method:** `HandleOrderStatusChanged`
- **Issue:** Errors are returned but no explicit Prometheus tracking is incremented for skipped or failed consumer runs.
- **Action:** 
  1. Add a metric bump if `skip` is true (e.g., `metrics.EventsSkipped.Inc()`), assuming the `prometheus` package is injected. (If no metric service is injected in the consumer constructor, skip this task).
  
### 6. Hardcoded Status Strings (Code Quality)
- **File:** `warehouse/internal/biz/reservation/reservation.go`
- **Action:** 
  1. Replace magic strings like `"active"`, `"expired"`, `"fulfilled"` with standard constants defined in a new file or in the pre-existing `model` definitions.

---

## ✅ ACCEPTANCE CRITERIA
- [ ] No `fmt.Errorf` strings dropped in `stock_reconciliation_job.go` outbox writes.
- [ ] `ExpireReservation` runs entirely under `FOR UPDATE` lock logic and doesn't rely on `UpdateStockWithVersion`.
- [ ] Local map caching is used in `updatePhysicalUtilization` to avoid duplicate N+1 gRPC requests per product.
- [ ] Code passes all tests and linting (`golangci-lint run ./warehouse/...`).

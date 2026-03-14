# AGENT-02: Catalog & Search Services Hardening

> **Created**: 2026-03-14
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `search`, `catalog`
> **Estimated Effort**: 2-3 days
> **Source**: Meeting Review Catalog & Search

---

## 📋 Overview

Refactor and harden the `Search` service based on the multi-agent meeting review findings. The primary goals are to fix the broken cursor-based pagination caused by RAM filtering, eliminate the cache stampede risk during peak traffic, ensure accurate discount calculations with timestamp validation, and replace the in-memory analytics queue with a robust Event-Driven Pub/Sub architecture. Additionally, optimize the product bulk sync flow to prevent memory bloat.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Pagination Broken by RAM Filter (Visibility)

**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~200, 301, 362
**Risk**: In-memory filtering after Elasticsearch query breaks pagination (page sizes shrink randomly, cursor offset breaks), causing critical UX bugs on Mobile/Web.
**Problem**:
```go
// BEFORE
// Filter AFTER search execution
result.Hits = uc.filterByVisibility(ctx, result.Hits, req.CustomerCtx)
```
**Fix**:
1. Remove `filterByVisibility` from post-processing in `SearchProducts` and `AdvancedProductSearch`.
2. Ensure `ProductIndex` mapping in Elasticsearch contains fields for `VisibilityRoles`, `SegmentIDs`, `IsB2B`.
3. Update `ProductIndexRepo.Search` and Elasticsearch Query Builder to incorporate the `CustomerCtx` directly into the `bool` -> `filter` query clause before hitting Elasticsearch.

**Validation**:
```bash
cd search && go test ./internal/biz -run TestSearchUsecase_Pagination_With_Visibility -v
```

### [x] Task 2: Fix Cache Stampede Risk with Singleflight

**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~220
**Risk**: Thundering herd problem during mega sales. When the cache expires, thousands of concurrent requests will bypass the cache and hit Elasticsearch simultaneously, leading to OOM or timeouts.
**Problem**:
```go
// BEFORE
if err := uc.cache.Get(ctx, cacheKey, &cachedResult); err == nil {
    // ... cache hit logic
}
// Cache miss -> direct hit to DB
result, err := uc.searchRepo.Search(ctx, query)
```
**Fix**:
1. Add `singleflight.Group` to `searchUsecase` struct.
2. Wrap the cache miss execution (fetch from DB + set cache) inside `sg.Do(cacheKey, func() (interface{}, error) { ... })`.

**Validation**:
```bash
cd search && go test ./internal/biz -run TestSearchUsecase_CacheStampede -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Missing Timestamp Validation for Sales/Discounts

**File**: `search/internal/biz/sync_usecase.go`
**Lines**: ~22-54 (`calcDiscountPercent`)
**Risk**: `calcDiscountPercent` uses `SalePrice` or `SpecialPrice` even if the promotion hasn't started or has already ended, displaying fake discounts to users.
**Problem**:
```go
// BEFORE
if ws.SalePrice != nil && *ws.SalePrice > 0 && *ws.SalePrice < *basePrice {
    // ValidTo/ValidFrom are completely ignored
    val := *ws.SalePrice
    bestDiscountedPrice = &val
}
```
**Fix**:
1. Update `client.Price` and `WarehouseStockItem` to include `ValidFrom` and `ValidTo` timestamps if they don't already.
2. Update `calcDiscountPercent` to verify that `time.Now()` is within the `ValidFrom` and `ValidTo` range before selecting the `SalePrice` or `SpecialPrice`.

**Validation**:
```bash
cd search && go test ./internal/biz -run TestCalcDiscountPercent_WithTimestamps -v
```

### [x] Task 4: Prevent Analytics Log Drops (Queue Capacity & Persistence)

**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~116
**Risk**: In-memory `analyticsChan: make(chan analyticsJob, 1000)` drops events under high load, causing loss of critical data for AI and trends. OOM risk if the queue is blocked.
**Problem**:
```go
// BEFORE
analyticsChan: make(chan analyticsJob, 1000)
// and later:
default:
    uc.log.Warn("Analytics queue full, dropping search event")
```
**Fix**:
1. Remove `analyticsChan` and the in-memory background workers.
2. Implement Dapr Pub/Sub (Event Publisher) to publish `SearchAnalyticsEvent` asynchronously to a message broker (e.g., RabbitMQ/Kafka) when a search occurs.
3. Have a separate consumer handle the batch saving to the `AnalyticsRepo`.

**Validation**:
```bash
cd search && go test ./internal/biz -run TestSearchAnalytics_PubSub -v
```

### [x] Task 5: Prevent Bulk Sync Memory Bloat

**File**: `search/internal/biz/sync_usecase.go`
**Lines**: ~323, 414
**Risk**: Fetching arrays by cursor and accumulating `failedProductIDs` in memory up to 10k items per batch sync can blow up Kubernetes Pod memory limit (OOMKilled).
**Problem**:
```go
// BEFORE
failedProductIDs = append(failedProductIDs, product.ID)
```
**Fix**:
1. Refactor `SyncAllProducts` to leverage `errgroup.Group` for parallel fetching of batches instead of a sequential loop.
2. Implement chunked inserts to `failedProductIDs` table/DB directly instead of holding everything in a slice to prevent RAM bloat.

**Validation**:
```bash
cd search && go test ./internal/biz -run TestSyncAllProducts_MemoryOptimization -v
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 6: Strict Global vs Warehouse Price Mapping

**File**: `search/internal/biz/sync_usecase.go`
**Lines**: ~558
**Risk**: Falling back to global sale price might incorrectly price items in specific warehouses that are excluded from the sale.
**Problem**:
```go
// BEFORE
} else if globalPrice != nil {
    // Fallback to global price unconditionally
    applicablePrice = globalPrice
}
```
**Fix**:
1. Check internal configuration or flags before falling back to `globalPrice` if `warehousePrice` is explicitly missing.
2. Ensure clear logging of "Fallback to Global Price for product X in warehouse Y".

**Validation**:
```bash
cd search && go test ./internal/biz -run TestSyncUsecase_PriceFallbackMapping -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd search && wire gen ./cmd/server/ ./cmd/worker/
cd search && go build ./...
cd search && go test -race ./...
cd search && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(search): harden search usecase and sync flows

- fix: rewrite visibility refiltering to use ES native clause
- fix: use singleflight for search cache stampede protection
- fix: validate timestamps in discount calculation
- refactor: replace in-memory analytics queue with pub/sub
- perf: optimize memory usage during bulk sync
- fix: strict global price fallback mapping

Closes: AGENT-02
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Pagination works accurately with visibility filters | `GET /search` returns exact page sizes with correct offsets | |
| No cache stampede under heavy load | Concurrent tests against cache miss show 1 DB call via `singleflight` | |
| Discounts disappear instantly after expiry | Search API response shows base price when `ValidTo` passes | |
| Search analytics persist reliably | Event consumer metrics show zero dropped events | |
| Memory usage remains flat during bulk sync | K8s `OOMKilled` ceases to occur during background sync | |

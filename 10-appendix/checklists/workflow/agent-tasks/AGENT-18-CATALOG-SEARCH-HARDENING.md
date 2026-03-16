# AGENT-18: Catalog & Search Flow Hardening (Part 1)

> **Created**: 2026-03-16
> **Priority**: P0/P1
> **Sprint**: Tech Debt Sprint
> **Services**: `catalog`, `search`
> **Estimated Effort**: 1-2 days
> **Source**: Catalog & Search Meeting Review Artifact

---

## 📋 Overview

Fixing the highest-priority bugs and architectural gaps in the Catalog and Search services from the recent 10000-round meeting review. This includes fixing visibility filtering rendering age-restricted products to all users, resolving a sync status reporting bug, fixing search cache stampedes, restoring missing price/stock data in product update consumers, and preventing Dapr infinite retries on deprecated endpoints.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Visibility Filtering in Search Products (Dead Code) ✅ IMPLEMENTED
**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~255 and ~302
**Risk**: Age-restricted or location-restricted products are visible to all users, violating compliance.
**Problem**: The `buildCacheKey` accounts for the customer context, but `SearchProducts` returns the ES result without invoking the injected `CatalogVisibilityClient` to filter out restricted products.
**Fix**:
Add post-search filtering in `SearchProducts` and `AdvancedProductSearch` using `uc.visibilityClient.FilterVisibleProducts`.

### [x] Task 2: Fix `failedProductIDs` Slice Reset Bug ✅ IMPLEMENTED
**File**: `search/internal/biz/sync_usecase.go`
**Lines**: ~514-516
**Risk**: Sync runs complete with "0 failed items", blinding ops to products missing from the search index.
**Problem**: The `defer` status update captures `failedProductIDs`, but the slice is reset via `failedProductIDs = failedProductIDs[:0]` after every checkpoint batch.
**Fix**:
Don't reset the slice, or maintain a separate `totalFailedProductIDs` slice to be used by the defer closure.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Add `singleflight` and Caching to `SearchProducts` ✅ IMPLEMENTED
**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~250-256
**Risk**: Cache stampede under heavy load because basic search misses `singleflight` and misses storing the result in cache after retrieval.
**Problem**: ES is hit concurrently for the same un-cached query. The result isn't even saved to cache after fetching.
**Fix**:
Wrap the `uc.searchRepo.Search` call in `uc.sg.Do` and `uc.cache.Set` like `AdvancedProductSearch` does.

### [x] Task 4: Fix Product Updated Consumer Losing Price/Stock ✅ IMPLEMENTED
**File**: `search/internal/service/product_consumer.go`
**Lines**: ~197-216
**Risk**: Description update on catalog resets the product's price to $0 and stock to 0 in search results.
**Problem**: `ProcessProductUpdated` constructs a new `ProductIndex` with `catalogClient.GetProduct` but omits `Price`, `Stock`, `Currency`, and `WarehouseStock` fetching.
**Fix**:
Fetch existing ES doc via `s.productRepo.GetProduct` and merge existing pricing/stock fields into the new standard `ProductIndex` document OR re-fetch pricing/stock. Merging from existing ES doc is faster.

### [x] Task 5: Prevent Dapr Infinite Retry on Deprecated Stock Events ✅ IMPLEMENTED
**File**: `catalog/internal/service/events.go`
**Lines**: ~310-316 & ~323-328 & ~335
**Risk**: `http.StatusInternalServerError` returned for deprecated events invokes Dapr's retry fallback endlessly, filling DLQs and wasting resources.
**Problem**: Deprecated handlers `HandleStockUpdated` and `HandleStockAdjusted` return 500 when handlers aren't initialized.
**Fix**:
Change them to log a warning and return 200 OK with `{"status":"DROP"}`.

---

## 🔧 Pre-Commit Checklist

```bash
cd catalog && wire gen ./cmd/server/ ./cmd/worker/
cd search && wire gen ./cmd/server/ ./cmd/worker/
cd catalog && go build ./... && go test -race ./...
cd search && go build ./... && go test -race ./...
```

---

## 📝 Commit Format

```
fix(search,catalog): resolve P0/P1 catalog search hardening issues

- fix: apply visibility filtering to SearchProducts
- fix: maintain total failed products slice across sync checkpoints
- fix: add singleflight and cache setting to SearchProducts
- fix: merge existing ES price/stock data in product update consumer
- fix: return 200 ok for deprecated event handlers to prevent Dapr loops

Closes: AGENT-18
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| SearchProducts applies visibility wrapper | Verify usecase tests cover or code calls `FilterVisibleProducts` | ✅ |
| Sync doesn't reset total failed product lists | Inspect `failedProductIDs` slice logic | ✅ |
| SearchProducts uses singleflight and `cache.Set` | Look at `SearchProducts` method body | ✅ |
| ProcessProductUpdated merges price/stock from ES | Look at `product_consumer.go` missing field population | ✅ |
| Deprecated stock handlers return 200 `DROP` | Look at `catalog/internal/service/events.go` | ✅ |

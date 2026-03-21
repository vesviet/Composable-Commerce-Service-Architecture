# AGENT-04: Catalog & Search Hardening (V2 Review)

> **Created**: 2026-03-21
> **Priority**: P0/P1/P2
> **Sprint**: Security & Tech Debt Sprint
> **Services**: `catalog`, `search`
> **Estimated Effort**: 4-6 days
> **Source**: Meeting Review V2 - Catalog & Search Discovery Flows

---

## 📋 Overview

This batch addresses critical security and data leakage issues discovered in the Search and Catalog services. It focuses on resolving the P0 Fail-Open vulnerability in visibility filtering, the P0 Autocomplete Data Leak, the P1 Sparse Pagination UX bug, and the P1 Goroutine Leak during parallel catalog enrichments.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Autocomplete Data Leak By Applying Visibility Filtering

**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~465-495 (hàm `AutocompleteAdvanced`)
**Risk**: Data Leakage! Autocomplete queries fetch products directly from Elasticsearch without applying `uc.catalogVisibilityClient` filtering. Restricted (Age-Restricted, Draft, B2B) products have their names and images leaked in the dropdown search UI.
**Problem**: The `AutocompleteAdvanced` function returns suggestions without checking authorization context.
**Fix**:
```go
// BEFORE:
suggestions, err := uc.searchRepo.AutocompleteAdvanced(ctx, req)
if err != nil { return nil, err }
if uc.cache != nil { _ = uc.cache.Set(ctx, cacheKey, suggestions, uc.getAutocompleteTTL()) }
return suggestions, nil

// AFTER:
// TODO: Iterate over `suggestions`. For any suggestion of Type=="product", collect its ID.
// TODO: Call `uc.catalogVisibilityClient.BatchCheckProductVisibility` with `req.CustomerCtx`.
// TODO: Filter out any suggestion that returns `Visible: false` before caching and returning.
// TODO: Apply the same fix to `Autocomplete` (legacy string-based method) if it exposes product IDs or names.
```

**Validation**:
```bash
cd search && go test ./internal/biz -run TestAutocomplete_VisibilityBypass -v
# Construct a request that searches for a restricted SKU and assert it is not returned.
```

### [x] Task 2: Change Search Visibility Filter from Fail-Open to Fail-Closed

**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~695 (hàm `filterVisibleProducts`)
**Risk**: If the `catalog` service goes down or times out, the `search` service logs a warning and shows ALL products (including hidden/banned ones) to the user. This is a fatal security/business logic bypass under load.
**Problem**: `filterVisibleProducts` returns early without modifying the list if the gRPC call fails.
**Fix**:
```go
// BEFORE:
visibilityMap, err := uc.catalogVisibilityClient.BatchCheckProductVisibility(ctx, productIDs, customerCtx)
if err != nil {
	uc.log.WithContext(ctx).Warnf("Failed to check product visibility, failing open: %v", err)
	return
}

// AFTER:
visibilityMap, err := uc.catalogVisibilityClient.BatchCheckProductVisibility(ctx, productIDs, customerCtx)
if err != nil {
	uc.log.WithContext(ctx).Errorf("[SECURITY] Failed to check product visibility tightly, failing CLOSED: %v", err)
	// Fail closed: clear ALL hits from the result to prevent data leak.
	result.Hits = []SearchHit{}
	result.TotalHits = 0
	return
}
```

**Validation**:
```bash
cd search && go test ./internal/biz -run TestSearchProducts_CatalogUnavailable -v
# Ensure that if catalog client returns an error, Hits length is 0.
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Fix Goroutine Leak / Unchecked Semaphore in Catalog Bulk Enrichment

**File**: `catalog/internal/service/product_helper.go`
**Lines**: ~305-315
**Risk**: If a user disconnects/cancels the HTTP context while a bulk enrichment loop is running, the blocked struct insertion into the semaphore channel will hang forever, causing permanent memory/goroutine leaks, leading to OOM Kills.
**Problem**: `semaphore <- struct{}{}` does not aggressively check `ctx.Done()`.
**Fix**:
```go
// BEFORE:
// Acquire semaphore
semaphore <- struct{}{}
defer func() { <-semaphore }()

// AFTER:
// Acquire semaphore with context cancel awareness
select {
case semaphore <- struct{}{}:
	defer func() { <-semaphore }()
case <-ctx.Done():
	return // Context cancelled, gracefully exit without enriching this product or acquiring semaphore
}
```

**Validation**:
```bash
cd catalog && go test ./internal/service -run TestEnrichProductsBulk_ContextCancellation -v
```

### [x] Task 4: Fix Sparse Pagination (UX Bug) in Search Results

**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~710
**Risk**: When Post-Filtering hides elements from `result.Hits` but retains the `rawResult.TotalHits`, the frontend Pagination Math breaks, resulting in "phantom pages" where users click page 2 and see 0 items.
**Problem**: Post-filtering doesn't correct `TotalHits`. (Long-term fix is Elasticsearch Pre-Filtering, but short-term logic is required).
**Fix**:
```go
// BEFORE:
// Note: We don't artificially reduce TotalHits as it might confuse pagination calculations.

// AFTER:
// TODO: Temporarily fix TotalHits by reducing it by the number of filtered elements:
// filteredCount := len(result.Hits) - len(filtered)
// result.TotalHits = result.TotalHits - int64(filteredCount)
// TODO (Architecture Update): Migrate visibility checking directly into Elasticsearch syncing logic via worker daemon for True Pre-filtering.
```

**Validation**:
```bash
cd search && go test ./internal/biz -run TestSearchProducts_PaginationCorrection -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd search && wire gen ./cmd/server/ ./cmd/worker/
cd search && go build ./...
cd search && go test -race ./...
cd catalog && go build ./...
cd catalog && go test -race ./...
```

---

## 📝 Commit Format

```
fix(search): secure visibility filtering and autocomplete data leaks

- sec: convert fail-open visibility to fail-closed to prevent leaks
- fix: apply visibility checking to autocomplete suggestions
- fix: patch sparse pagination logic when post-filtering is applied
- fix(catalog): prevent goroutine leak in bulk product enrichment via context done

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Complete fail-close logic | `TestSearchProducts_CatalogUnavailable` passes properly | ✅ |
| Autocomplete secures data | Manual verify `autocomplete` with blocked SKU shows no results | ✅ |
| No Goroutines leaked | Profile `/debug/pprof` under load test and abort | ✅ |

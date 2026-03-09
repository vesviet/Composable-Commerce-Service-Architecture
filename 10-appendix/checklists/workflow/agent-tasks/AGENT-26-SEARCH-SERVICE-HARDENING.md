# AGENT-26: Search Service Hardening & Resilience

> **Created**: 2026-03-09
> **Priority**: P0 (1 issue), P1 (2 issues), P2 (1 issue)
> **Sprint**: Tech Debt Sprint
> **Services**: `search`
> **Estimated Effort**: 2-3 days
> **Source**: [10-Round Search Service Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/1c5f3407-0d62-454d-a4b8-5f2e02595222/artifacts/search_service_meeting_review.md)

---

## 📋 Overview

Batch of hardening tasks for the Search service derived from the 10-round multi-agent meeting review. Key focus areas include preventing silent data loss during catalog sync, fixing false-positive metrics in ES bulk operations, and addressing version conflict bugs in UpdateByQuery operations.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Silent Data Loss on Sync Failure

**File**: `search/internal/biz/sync_usecase.go`
**Lines**: ~597-606
**Risk**: If the Pricing Service goes down or returns empty data for a batch, `warehouseStock` falls back to empty. The sync silently skips all items (`return nil, nil`). The sync job finishes as "completed", but the new ES alias contains 0 products -> Full website product catalog disappears.
**Problem**: The function `buildProductIndexDoc` hides critical failures by treating empty stock/price as a successful skip.
**Fix**:
Refactor the retry logic in `performSync` to fail-fast if Critical dependencies (Pricing/Warehouse) completely fail, AND modify `buildProductIndexDoc` to return an explicit error instead of `nil, nil` when missing compulsory data for a valid product, or at least propagate the error state to `performSync` so it counts as `totalFailed`.

```go
// BEFORE (sync_usecase.go ~line 597):
if len(warehouseStock) == 0 {
    uc.log.Warnf("Product %s (%s): SKIPPED - No valid warehouse stock entries", product.ID, product.Name)
    return nil, nil // Skip successfully
}

// AFTER:
if len(warehouseStock) == 0 {
    uc.log.Errorf("Product %s (%s): FAILED - No valid warehouse stock entries (pricing/inventory fetch failed)", product.ID, product.Name)
    return nil, fmt.Errorf("missing valid price/stock for product %s", product.ID)
}
```

**Validation**:
```bash
cd search && go build ./...
cd search && go test ./internal/biz/... -run TestSync -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Fix False Positives in ES Bulk Indexing Metrics

**File**: `search/internal/data/elasticsearch/product_index.go` and `search/internal/biz/sync_usecase.go`
**Lines**: ~150-153 (product_index.go) and ~440 (sync_usecase.go)
**Risk**: An Elasticsearch bulk index operation containing 1000 items where 1 mapping fails will cause `BulkIndexProducts` to return an error. `performSync` then increments `totalFailed += len(productsToIndex)` (all 1000 items failed). This breaks monitoring and triggers false PagerDuty alerts.
**Problem**: Bulk indexing errors are partial but handled broadly.
**Fix**:
Modify `BulkIndexProducts` to return detailed failure counts/IDs instead of a generic error, and update `performSync` to only increment `totalFailed` by the actual number of failed items.

```go
// Modify interface in search/internal/biz/product_index_repo.go:
// BulkIndexProducts(...) (failedCount int, failedIDs []string, err error)

// In search/internal/data/elasticsearch/product_index.go:
// Parse the `bulkResp["items"]` properly to count and return exactly which ones failed.
```

**Validation**:
```bash
cd search && go build ./...
cd search && go test ./internal/data/elasticsearch/... -v
```

---

### [x] Task 3: Add `conflicts=proceed` to ES `UpdateByQuery`

**File**: `search/internal/data/elasticsearch/product_index.go`
**Lines**: ~466-519 (RemovePromotionFromAllProducts), ~624-666 (UnsetCategoryFromProducts)
**Risk**: Concurrent writes from Event Bus (Price updated, Stock updated) and global `UpdateByQuery` sweeps (Category removed) will cause Version Conflicts, throwing 500 Internal Server Errors and halting the sweep.
**Problem**: `UpdateByQuery` does not include the `conflicts: proceed` flag, meaning it aborts entirely if a version conflict happens.
**Fix**:
Chain `.WithConflicts("proceed")` into the `UpdateByQuery` calls.

```go
// BEFORE:
res, err := r.client.es.UpdateByQuery(
    []string{indexName},
    r.client.es.UpdateByQuery.WithContext(ctx),
    r.client.es.UpdateByQuery.WithBody(strings.NewReader(string(bodyJSON))),
    r.client.es.UpdateByQuery.WithRefresh(true),
)

// AFTER:
res, err := r.client.es.UpdateByQuery(
    []string{indexName},
    r.client.es.UpdateByQuery.WithContext(ctx),
    r.client.es.UpdateByQuery.WithBody(strings.NewReader(string(bodyJSON))),
    r.client.es.UpdateByQuery.WithRefresh(true),
    r.client.es.UpdateByQuery.WithConflicts("proceed"), // Resume on conflict
)
```

**Validation**:
```bash
cd search && go build ./...
cd search && go test ./internal/data/elasticsearch/... -v
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 4: Batch Insert for Search Analytics

**File**: `search/internal/biz/search_usecase.go`
**Lines**: ~133-150 (`startAnalyticsWorkers`)
**Risk**: In High RPS events, doing Single Inserts to PostgreSQL/ES for Analytics tracking will exhaust DB connections.
**Problem**: The workers `trackSearch` by saving records 1 by 1 inside a loop over the channel.
**Fix**:
Modify the worker loop to collect `SearchAnalytics` in a slice and use a ticker (e.g. 1 second) or size limit (e.g. 100) to batch insert using `analyticsRepo.SaveBatch`.

```go
// Example logic:
// Use a ticker and a slice to buffer incoming tracking requests, then flush them via SaveBatch.
```

**Validation**:
```bash
cd search && go build ./...
cd search && go test ./internal/biz/... -v
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
fix(search): harden search service — meeting review issues

P0 fixes:
- fix: fail-fast on sync pricing failure to prevent silent data loss

P1 fixes:
- fix: track partial failures properly in ES bulk indexing metrics
- fix: add conflicts=proceed to ES UpdateByQuery sweeps

P2 fixes:
- perf: implement batch insertion for search analytics tracking

Closes: AGENT-26
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Silent drop removed | `grep 'fmt.Errorf("missing valid price' sync_usecase.go` exists | ✅ |
| Partial metrics handled | `BulkIndexProducts` signature includes failure count/IDs | ✅ |
| Conflicts flag added | `grep 'WithConflicts("proceed")' product_index.go` | ✅ |
| Batch analytics inserted | DB records persist without single insert bottleneck | ✅ |
| Service compiles & tests pass | `go build ./... && go test ./...` | ✅ |

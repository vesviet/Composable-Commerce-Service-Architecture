# AGENT-03: Search & Discovery Service Hardening

> **Created**: 2026-03-10
> **Priority**: P0/P1
> **Sprint**: Hardening Sprint
> **Services**: `search`
> **Estimated Effort**: 3-4 days
> **Source**: [Search & Discovery 150-Round Meeting Review Artifact](file:///home/user/.gemini/antigravity/brain/2b1e1b9b-b02e-4879-a8a1-0af061864a7b/search_discovery_150round_review.md)

---

## 📋 Overview

Based on the 150-round Search & Discovery meeting review, the Search service contains a few critical vulnerabilities regarding Elasticsearch resource exhaustion and latency spikes. This hardening task re-assigns AGENT-03 to resolve deep pagination risks, prevent mapping explosions, and decouple analytical database writes from the core search request path.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Enforce API Limits on Deep Pagination & Faceting

**File**: `search/internal/service/search_handlers.go`
**Lines**: ~48-53 (Inside `SearchProducts` and `AdvancedProductSearch`)
**Risk**: Bots scraping deep pages or requesting massive facet arrays can OOM the Elasticsearch cluster.
**Problem**: The API currently accepts any `PageSize` allowing malicious queries to execute deep scrolling without boundaries.
**Fix**:
Implement hard limits on the cursor size:
```go
// BEFORE:
if req.Cursor != nil {
    cursorReq = &pagination.CursorRequest{
        Cursor:   req.Cursor.Cursor,
        PageSize: int(req.Cursor.PageSize),
    }
}

// AFTER:
if req.Cursor != nil {
    pageSize := int(req.Cursor.PageSize)
    if pageSize > 100 {
        pageSize = 100 // Hard limit to protect ES cluster
    }
    // Optional: Add logic to block if cursor indicates a page too deep
    cursorReq = &pagination.CursorRequest{
        Cursor:   req.Cursor.Cursor,
        PageSize: pageSize,
    }
}
```

**Validation**:
```bash
cd search && go test ./internal/service/... -v
```

---

### [ ] Task 2: Prevent Dynamic Mapping Explosion in Attributes

**File**: `search/mapping.json`
**Lines**: 6-7
**Risk**: Sellers adding unbounded dynamic attributes directly into the root mapping will exhaust Elasticsearch shard limits and corrupt the index ring.
**Problem**: The `attributes` object is set to `"dynamic": true`.
**Fix**:
Change the dynamic setting for `attributes` object to `false` or restructure to a `nested` object with strict key-value pairs (e.g. `{"name": "color", "value": "red"}`). At minimum, change `true` to `false` so the fields aren't indexed as separate column mappings.
```json
// BEFORE:
      "attributes": {
        "dynamic": true,
        "type": "object"
      },

// AFTER:
      "attributes": {
        "dynamic": false,
        "type": "object"
      },
```

**Validation**:
```bash
# Verify JSON linting passes
cat search/mapping.json | jq . > /dev/null
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Decouple Analytics Writes from Search Path

**File**: `search/internal/biz/analytics.go`
**Lines**: 115-118
**Risk**: Synchronous database writes to PostgreSQL during a search API call make the search endpoint's latency dependent on Postgres performance. A Postgres slowdown will cause Search to crash/timeout.
**Problem**: `TrackSearch` waits for `uc.analyticsRepo.Save()` to finish.
**Fix**:
Convert the `TrackSearch` and `TrackClick` inserts to run asynchronously in fire-and-forget goroutines or queue through Dapr PubSub.
```go
// BEFORE:
if err := uc.analyticsRepo.Save(ctx, analytics); err != nil {
    uc.log.WithContext(ctx).Errorf("Failed to track search: %v", err)
    return err
}
return nil

// AFTER:
go func(a *SearchAnalytics) {
    // Detach context
    bgCtx := context.Background()
    if err := uc.analyticsRepo.Save(bgCtx, a); err != nil {
        uc.log.Errorf("Failed to track search async: %v", err)
    }
}(analytics)
return nil
```

**Validation**:
```bash
cd search && go test ./internal/biz/... -v
```

---

### [ ] Task 4: Deduplicate LTR Click Events (Bot Fraud)

**File**: `search/internal/biz/analytics.go`
**Lines**: ~123
**Risk**: Bad actors can manipulate trending data by scripting rapid clicks on specific products.
**Problem**: `TrackClick` blindly inserts every click event as a valid `SearchAnalytics` entry.
**Fix**:
Add Redis-based sliding window rate-limiting or deduplication for identical `(SessionID, ProductID)` clicks within a short time window. Since `Cache` is injected into `analyticsUsecase`, use `uc.cache.Set()` with `NX` to only save the click if not recently clicked.

**Validation**:
```bash
cd search && go test ./internal/biz/... -run TrackClick -v
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
refactor(search): harden search elasticity and analytics decoupling

- fix: enforce hard limits on pagination page size to prevent ES OOM
- fix: disable dynamic mapping for product attributes to prevent field explosion
- perf: convert search and click tracking to fire-and-forget async goroutines
- feat: implement cache-based deduplication for LTR click tracking

Closes: AGENT-03
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Deep Pagination Defeated | API enforces `PageSize <= 100` regardless of request | 🔴 TODO |
| Mapping Schema Secure | `attributes` object no longer accepts dynamic mapping keys | 🔴 TODO |
| Search Latency is Independent | Search response time < 50ms even if Postgres is slow | 🔴 TODO |
| Click Fraud Mitigated | Same User/Session clicking identical product is deduplicated | 🔴 TODO |

# AGENT-13: Enhance Search & Discovery (Autocomplete, Rating Facets, Sorting)

> **Created**: 2026-04-01
> **Priority**: P1 (Search Sorting) / P2 (Autocomplete & Rating Filters)
> **Sprint**: QA Phase 1 Remediation
> **Services**: `search` service (Go), `frontend` (Next.js/React)
> **Estimated Effort**: 2-3 days
> **Source**: Browser Subagent & Playwright QA Run for Flow 3: Search & Discovery

---

## 📋 Overview

The Search & Discovery functionality successfully handles fuzzy matching (typo tolerance) and generic queries. However, a QA review discovered missing feature parity and replication of the 400 Sorting Error within the search context.

Specifically, the "Typeahead/Autocomplete" feature is entirely absent from the header search bar. Furthermore, the `rating` facet filter is missing from the search results page,
- [x] **TC-SRCH-12 BUG P0**: Sorting search results by `price:asc` or `price:desc` returns HTTP 400 Bad Request. Default relevance sorting works correctly.
  - *Fix*: Removed `unmapped_type` from ElasticSearch sort clauses for properties like price and review_count which was throwing a mapper_parsing_exception when combined with `missing: _last`.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix 400 Bad Request on Price Sort (Search Context)

**Service**: `search` microservice
**Risk**: Users cannot sort query results by price, hindering shopping comparison.
**Problem**: Automated test `TC-SSORT-03: BUG — Price sort triggers 400 in search context` failed. Sorting by price after submitting a search query returns an HTTP 400 error.

**Fix Instructions**:
1. Verify if the `search` service shares the `dosiin/base-service` query builder or implements its own Elasticsearch sorting logic.
2. In the `SearchProducts` handler, map the URL param `sort=price:asc` to the appropriate Elasticsearch sort query (e.g., `{"sort": [{"price": "asc"}]}`).
3. Handle case/type mismatches that cause the 400 validation rejection.

**Validation**:
```bash
# Verify TC-SSORT-03 passes (returns 200 OK and ordered products limit 10)
cd qa-auto && npx playwright test tests/search-discovery/search-facets-sort.spec.ts
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Implement Autocomplete / Typeahead UI

**Service**: `frontend` / `search` or `catalog` API
**Risk**: Lack of interactive search degrades modern e-commerce UX.
**Problem**: Typing slowly in the main search bar does not bring up an autocomplete tray or suggestions.
**Reference**: Playwright verifies this absence natively via `TC-AUTO-01: BUG — No autocomplete dropdown appears while typing`.

**Fix Instructions**:
1. Implement an `onChange` debounced handler (e.g., 300ms) on the Header's `<input type="text" data-testid="search-input">`.
2. Ensure the backend exposes a quick `/api/v1/search/suggest?q=...` endpoint. If not, pipe the query to the standard search endpoint with `limit=5`.
3. Render a dropdown absolute <ul> list displaying product names or matching categories below the input element.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 3: Add Rating Filter Facet to Search Results

**Service**: `frontend` / (Elasticsearch aggregations)
**Risk**: Missing filtering option compared to competitors.
**Problem**: Playwright test `TC-FACET-07: No rating filter available` failed trying to interact with a non-existent rating filter.

**Fix Instructions**:
1. Ensure the search service's Elasticsearch index includes the `average_rating` and aggregates it.
2. Wire up the `Rating` filter component (e.g., 4 Stars & Up) in the `FilterSidebar` on the `/search` page.

---

## 🔧 Pre-Commit Checklist

```bash
cd search && go test -race ./...
cd frontend && npm run build
cd qa-auto && npx playwright test tests/search-discovery/
```

---

## 📝 Commit Format

```
fix(search): resolve 400 bad request on price sort query mapping
feat(frontend): implement autocomplete dropdown on global search bar
feat(frontend): add rating filter to search facets

Closes: AGENT-13
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Typing slowly in the search bar triggers a suggestion dropdown. | Manual UI testing. | ✅ |
| Applying the price-sort dropdown in search results successfully re-orders items without a 400 error. | Automated script verification. | ✅ |
| Filtering search results by "4 Stars & Up", correctly limits results. | Manual UI verification. | ✅ |

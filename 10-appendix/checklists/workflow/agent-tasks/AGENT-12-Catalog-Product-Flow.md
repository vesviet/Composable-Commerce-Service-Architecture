# AGENT-12: Fix Catalog Filtering, Sorting, and Display Issues

> **Created**: 2026-04-01
> **Priority**: P0 (Sorting) / P1 (Display/Filters) / P2 (Test ID)
> **Sprint**: QA Phase 1 Remediation
> **Services**: `catalog` service (Go), `frontend` (Next.js/React)
> **Estimated Effort**: 1-3 days
> **Source**: Browser Subagent & Playwright QA Run for Flow 2: Catalog & Product

---

## 📋 Overview

During the QA validation of Flow 2 (Catalog & Product), several issues were identified combining both automated Playwright reports and manual exploratory testing.

The most critical issue is that sorting by price triggers a generic `400 Bad Request` from the backend API. Additionally, the frontend PLP (Product Listing Page) displays raw UUIDs instead of readable category names in the filter sidebar, and PDP (Product Detail Page) components suffer from missing or unmapped images/category descriptions.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix 400 Error on Price Sorting

**Service**: `catalog` microservice or API Gateway
**Risk**: Users cannot sort products by price, degrading the shopping experience and discovery.
**Problem**: Playwright test `TC-SORT-03: BUG — Sorting by price triggers 400 error` fails. When the frontend sends `sort=price:asc` (or similar), the backend returns an HTTP 400.

**Fix Instructions**:
1. Check the `catalog` service HTTP/gRPC handlers or the custom query builder (e.g., in `dosiin/base-service` or common `query_builder` utilities).
2. Validate how the `sort` parameter is parsed. Ensure the mapping from HTTP query string to database column respects `price` correctly.
3. Fix the validation layer so price sorting translates to a valid SQL `ORDER BY price ASC/DESC`.

**Validation**:
```bash
cd qa-auto && npm run test:filter
# Ensure TC-SORT-03 passes (200 OK)
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 2: Resolve Raw UUIDs in Category Filters

**Service**: `frontend`
**Risk**: Terrible UX; customers have no idea what categories they are filtering by.
**Problem**: The sidebar filters render raw UUIDs (e.g., `c0000000-...`) instead of localized names like "Electronics" or "Fashion".

**Fix Instructions**:
1. Inspect the filter component fetching categories (likely in `app/(catalog)/products/page.tsx` or a related `FilterSidebar` component).
2. Ensure the `catalog` service response includes the `name` field for category facets, not just the `category_id`.
3. If the backend is already sending names, correct the frontend mapping to display `category.name` instead of `category.id`.

### [ ] Task 3: Fix Missing Images & "N/A" Categories on PDP

**Service**: `frontend` / `catalog`
**Risk**: Lack of visual confirmation prevents sales conversion.
**Problem**: Product detail pages often display "Không có hình ảnh" (No image) and "Danh mục: N/A".

**Fix Instructions**:
1. Verify if the `catalog` service's `GetProduct` RPC eagerly loads the `media` and `categories` relations. 
2. Ensure GORM preloading is correctly set up (`Preload("Media").Preload("Categories")`) in the repository.
3. Ensure the frontend correctly parses the new payload structure.

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 4: Fix Missing `data-testid` for PLP Search Bar

**Service**: `frontend`
**Risk**: Breaks automated E2E testing.
**Problem**: `TC-PLP-05` failed because `locator('[data-testid="search-input"]')` timed out on the Product Listing Page.

**Fix Instructions**:
1. Open the search bar component in the frontend.
2. Add the `data-testid="search-input"` attribute to the primary `<input>` element.

---

## 🔧 Pre-Commit Checklist

```bash
cd catalog && go test -race ./...
cd catalog && golangci-lint run ./...
cd qa-auto && npx playwright test tests/catalog-product/
```

---

## 📝 Commit Format

```
fix(catalog): resolve 400 bad request on price sorting
fix(frontend): map category facet names to prevent UUID display
fix(catalog): preload media and categories for PDP retrieval
test(frontend): add missing data-testid to search input

Closes: AGENT-12
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Sorting by price low-to-high returns 200 OK and ordered items. | Run `npm run test:filter`. | |
| Filters show "Clothing" instead of "c0...". | Manual UI verification. | |
| PDP shows actual product images and correct category hierarchy. | Manual UI verification. | |

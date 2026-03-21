# AGENT-04: Catalog & Product Flow Issues

> **Created**: 2026-03-21
> **Priority**: P0 + P1 + P2
> **Sprint**: Bug Fix Sprint
> **Services**: `frontend`, `search`, `catalog`
> **Estimated Effort**: 2-3 days
> **Source**: Manual + Automated QA Testing on `https://frontend.tanhdev.com/`

---

## 📋 Overview

QA testing of Catalog & Product flows (Product Listing, Detail, Search, Filtering, Sorting) on `frontend.tanhdev.com` uncovered 5 issues: 1 P0 API integration bug, 2 P1 data/UI bugs, and 2 P2 UX issues.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Sorting — 400 Bad Request from Search API ✅

**Risk**: Product sorting is completely broken for all sort options except "Newest". Users cannot sort by price or name, blocking core shopping UX.

**Problem**: Selecting any sort option (Price: Low to High, Price: High to Low, Name: A to Z, Name: Z to A) on `/products` triggers a `400 Bad Request` from the search API. The frontend likely sends an invalid `sort_by` parameter value (e.g., `SORT_BY_PRICE_ASC`) that the search service doesn't accept.

**Investigation**:
```bash
# Check what sort values the search API accepts
grep -rn "sort\|SortBy\|OrderBy" search/api/search/v1/*.proto
grep -rn "sort\|SortBy" search/internal/service/
grep -rn "sortBy\|sort_by\|orderBy" frontend/src/
```

**Likely Fix**: The frontend is sending a sort enum value that doesn't match the API contract. Check the search service's proto definition for valid sort values and update the frontend mapping.

**Files to investigate**:
- `frontend/src/app/products/page.tsx` or product listing component
- `frontend/src/lib/api/services/search.service.ts` or equivalent
- `search/api/search/v1/search.proto` — sort enum definition

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-SORT-03"
# Expected: test should fail (bug confirmed) → after fix, test assertion should be inverted
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Fix Category/Brand Filters — Missing Labels ✅

**Risk**: Users see unlabeled radio buttons/checkboxes with only count numbers `(95)`, `(72)` — impossible to know which category/brand each option represents.

**Problem**: The sidebar filter components render category and brand names but the label text is empty. The backend likely returns category/brand data with `id` and `count` but the `name` field is either missing or not mapped in the frontend component.

**Files to investigate**:
- `frontend/src/app/products/page.tsx` or product listing components
- Frontend component rendering category filters
- Search API response — check if `name` field is returned for facets

**Fix**: Ensure the search API returns `name` for each category/brand facet, and the frontend renders it alongside the count.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-PLP-08"
# Console output should show "BUG CONFIRMED" if labels still missing
```

---

### [x] Task 3: Fix Category Showing UUID on Product Detail Page ✅

**Risk**: Product Detail Page shows raw UUID (e.g., `c000...015`) instead of human-readable category name. Breaks user trust and SEO.

**Problem**: The PDP component receives category as UUID reference but doesn't resolve it to a display name. The catalog API likely only returns `category_id` instead of `category_name` (or a nested object).

**Files to investigate**:
- Frontend PDP component (product detail page)
- `catalog/api/catalog/v1/catalog.proto` — check if GetProduct response includes category name
- Gateway routing for catalog endpoints

**Fix**: Either include category name in the product API response (join at API level), or make a secondary API call to resolve category name from ID.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-PDP-06"
# Console should show "BUG CONFIRMED: Page contains raw UUID"
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 4: Fix "Showing 1 to 0 of 0 products" Count ✅

**Risk**: Result count always shows "Showing 1 to 0 of 0 products" even when products are visible in the grid. Confusing UX.

**Problem**: The result count text is not synced with the actual product data returned from the API. The pagination metadata likely isn't being parsed/used correctly.

**File**: Frontend product listing component — result summary text
**Fix**: Use `total`, `page`, `pageSize` from the search API response to calculate the correct range.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-PLP-09"
```

---

### [x] Task 5: Remove Duplicate Sort Dropdown ✅

**Risk**: Two identical sort dropdowns appear side by side on the PLP — confusing UI element.

**Problem**: The sort component is rendered twice. One may be from the product listing layout and another from a separate filter bar component.

**File**: Frontend product listing page component
**Fix**: Remove the duplicate sort dropdown instance. Keep only one.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-PLP-10"
```

---

## 🔧 Pre-Commit Checklist

```bash
cd frontend && npm run lint && npm run build
cd qa-auto && npx playwright test tests/catalog-product/
```

## 📝 Commit Format

```
fix(frontend): fix product sorting, filter labels, and category display

- fix: correct sort_by parameter values for search API
- fix: render category/brand names in sidebar filters
- fix: resolve category UUID to name on PDP
- fix: sync result count with actual product data

Closes: AGENT-04 (Tasks 1-5)
```

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Sorting by price/name works | Select "Price: Low to High" → no errors, products reorder | |
| Category filters show names | Sidebar shows "Electronics (95)" not just "(95)" | |
| PDP shows category name | Category displays "Clothing" not UUID | |
| Result count is accurate | "Showing 1 to 20 of 500 products" matches grid | |
| Single sort dropdown only | One sort control visible, not two | |
| All 29 catalog E2E tests pass | `npx playwright test tests/catalog-product/` | |

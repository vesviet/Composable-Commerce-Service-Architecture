# AGENT-05: Search & Discovery Flow Issues

> **Created**: 2026-03-21
> **Priority**: P0 + P1 + P2
> **Sprint**: Bug Fix Sprint
> **Services**: `frontend`, `search`
> **Estimated Effort**: 2-3 days
> **Source**: Manual + Automated QA Testing on `https://frontend.tanhdev.com/`

---

## 📋 Overview

QA testing of Search & Discovery flows (Full-Text Search, Fuzzy Matching, Autocomplete, Zero-Result, Faceting, Sort, Discovery, SEO) on `frontend.tanhdev.com` uncovered 4 bugs and 3 missing features.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Zero-Result Search Shows Unrelated Products ✅

**Risk**: Searching for a non-existent term (e.g., "gibberish12345") shows "Showing 1 to 0 of 0 products" but the **product grid still displays unrelated products**. Users cannot trust search results. This fundamentally breaks search precision.

**Problem**: The frontend does not clear the product grid when the search API returns 0 results. The grid retains the previous product list or shows a default product set. The header text correctly says "0 products" but the grid ignores this.

**Investigation**:
```bash
grep -rn "setProducts\|products\s*=\|productList" frontend/src/app/products/
grep -rn "totalCount\|total_count\|totalProducts" frontend/src/
```

**Fix**: In the products page component, check if `totalCount === 0` from the search API response and render an empty state / "No results found" component instead of the product grid.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-ZERO-01"
```

---

### [x] Task 2: Fix All Sort Options — API 400 Error (Extends AGENT-04 Task 1) ✅

**Risk**: Sorting by price or name triggers `400 Bad Request`. Additionally, "Oldest" sort also fails silently within search context (no error displayed, but no products load). Only "Newest" sort works.

**Note**: This bug was also reported in AGENT-04 Task 1. This task extends it with the additional finding that "Oldest" sort also fails in search context.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-SSORT-02|TC-SSORT-03"
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Implement Autocomplete / Typeahead ✅ (Already implemented)

**Risk**: No autocomplete dropdown appears when typing in the search input. Users must complete their query and press Enter. Per ecommerce best practices (Shopify, Shopee, Lazada), typeahead suggestions significantly improve conversion.

**Expected behavior**: As user types 3+ characters, show a dropdown with:
- Product name suggestions
- Category suggestions
- Recent searches

**Implementation**: Call search API with `?suggest=true&q=<partial>` or implement a dedicated autocomplete endpoint. Frontend debounce at 300ms.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-AUTO-01"
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 4: Add Price Range Filter

**Risk**: No price range filter (slider or min/max inputs) on the PLP or search results page. Per ecommerce standards this is an essential filter.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-FACET-06"
# Console output should show "MISSING FEATURE"
```

---

### [ ] Task 5: Add Rating Filter

**Risk**: No rating filter on PLP or search results page. Standard e-commerce feature.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-FACET-07"
```

---

### [ ] Task 6: Implement "Recently Viewed" Section on Homepage

**Risk**: No "Recently Viewed" section appears after visiting products. Per Shopify/Shopee/Lazada patterns, this is a standard personalization feature.

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-DISC-04"
```

---

### [ ] Task 7: Add Zero-Result Fallback Suggestions

**Risk**: When search returns no results, no fallback content is shown (no "Did you mean?", no popular products, no suggestions).

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-ZERO-02"
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Zero-result search shows empty state | Search "gibberish" → "No results found" displayed, no products in grid | |
| All sort options work | Price/Name/Oldest sort → no 400 errors | |
| Autocomplete appears on typing | Type "coa" → dropdown with suggestions | |
| Price range filter exists | Slider or min/max inputs on PLP | |
| Rating filter exists | Star rating filter on PLP | |
| Recently Viewed shown | Visit product → back to homepage → section visible | |
| 26 search-discovery E2E tests pass | `npx playwright test tests/search-discovery/` | |

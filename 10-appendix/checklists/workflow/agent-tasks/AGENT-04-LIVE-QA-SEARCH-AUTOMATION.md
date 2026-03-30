# AGENT-04: Live QA Search Correctness & Automation Stabilization

> **Created**: 2026-03-30
> **Priority**: P0/P1
> **Sprint**: Hardening Sprint
> **Services**: `search`, `frontend`, `qa-auto`
> **Estimated Effort**: 2-3 days
> **Source**: `docs/10-appendix/ecommerce-platform-flows.md`, `docs/10-appendix/infotest.txt`, live QA run on 2026-03-30 (`164 passed / 14 failed / 3 skipped`)

---

## 📋 Overview

Live QA against `https://frontend.tanhdev.com` and `https://admin.tanhdev.com` found two confirmed product issues in the Search & Discovery flow and one data-enrichment gap that leaks into search payload quality. In parallel, several Playwright failures were verified as false negatives caused by outdated selectors and duplicated login helpers in `qa-auto`, so the automation suite now needs stabilization to remain trustworthy.

Confirmed live findings:
- `GET https://api.tanhdev.com/api/v1/search/autocomplete?query=coa&limit=10` returns `{"suggestions":[]}`, so autocomplete/typeahead is effectively absent on the storefront.
- `GET https://api.tanhdev.com/api/v1/search/products?q=zzzzxyznonexistent99999&cursor.page_size=12&include_facets=true` still returns `totalHits=934` with unrelated products, so zero-result handling is broken at the search backend level.
- `GET https://api.tanhdev.com/api/v1/search/products?q=coat...` returns hits whose `product.category` and `product.brand` are blank, even though facet display names are available.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Stop noisy/fuzzy search from turning gibberish into broad product matches ✅ IMPLEMENTED

**File**: `search/internal/data/elasticsearch/query_builder.go`
**Lines**: `196-210`
**Risk**: Search returns hundreds of irrelevant products for nonsense input, so the storefront cannot show a truthful zero-result state or fallback suggestions.
**Problem**: `buildMustClauses` always uses the same broad `multi_match` query with `fuzziness: "AUTO"` and `name.ngram^2`, which makes random strings such as `zzzzxyznonexistent99999` match a large portion of the catalog.
**Fix**:
```go
// BEFORE:
if query.Query != "" {
    must = append(must, map[string]interface{}{
        "multi_match": map[string]interface{}{
            "query":     query.Query,
            "fields":    []string{"name^3", "name.ngram^2", "description^2", "sku^2", "brand_name", "category_name"},
            "fuzziness": "AUTO",
            "operator":  "or",
        },
    })
}

// AFTER:
if query.Query != "" {
    fields := []string{"name^3", "description^2", "sku^2", "brand_name", "category_name"}
    multiMatch := map[string]interface{}{
        "query":    query.Query,
        "fields":   fields,
        "operator": "and",
    }

    if shouldUseFuzzyQuery(query.Query) {
        multiMatch["fuzziness"] = "AUTO"
        multiMatch["operator"] = "or"
        multiMatch["fields"] = append(fields, "name.ngram^2")
    } else {
        multiMatch["minimum_should_match"] = "100%"
    }

    must = append(must, map[string]interface{}{"multi_match": multiMatch})
}
```

**Validation**:
```bash
cd search && go test ./internal/data/elasticsearch/... ./internal/service/... -run 'TestSearchProducts|TestSearchProducts_WithCursor' -v
curl -s 'https://api.tanhdev.com/api/v1/search/products?q=zzzzxyznonexistent99999&cursor.page_size=12&include_facets=true'
# Expect: totalHits=0 (or no product results), not 934 unrelated hits
```

---

### [x] Task 2: Restore storefront autocomplete suggestions with a safe fallback path ✅ IMPLEMENTED

**File**: `search/internal/data/elasticsearch/autocomplete.go`
**Lines**: `42-93`, `135-203`
**Risk**: Search box looks interactive but never helps users complete queries, violating the Search & Discovery flow in the reference doc.
**Problem**: The live endpoint `/api/v1/search/autocomplete?query=coa&limit=10` returns no suggestions. The current implementation only trusts the completion suggester on `name.suggest` and returns empty if Elasticsearch has no completion options.
**Fix**:
```go
// BEFORE:
if len(response.Suggest.NameSuggest) > 0 {
    for _, option := range response.Suggest.NameSuggest[0].Options {
        suggestions = append(suggestions, option.Text)
    }
}
return suggestions, nil

// AFTER:
if len(response.Suggest.NameSuggest) > 0 {
    for _, option := range response.Suggest.NameSuggest[0].Options {
        suggestions = append(suggestions, option.Text)
    }
}
if len(suggestions) > 0 {
    return suggestions, nil
}

// Fall back to a prefix query against indexed product names so autocomplete
// still works even when completion data is stale or missing.
return h.autocompleteByPrefix(ctx, query, limit)
```

**Validation**:
```bash
cd search && go test ./internal/data/elasticsearch/... ./internal/service/... -run 'TestGetAutocomplete|TestAutocompleteIntegration' -v
curl -s 'https://api.tanhdev.com/api/v1/search/autocomplete?query=coa&limit=10'
# Expect: suggestions array is non-empty for common prefixes like "coa"
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Populate category and brand display names before indexing products into Search ✅ IMPLEMENTED

**File**: `search/internal/client/catalog_grpc_client.go`
**Lines**: `334-345`
**Risk**: Search hits carry blank `product.category` and `product.brand`, which degrades storefront metadata quality and makes downstream UI fall back to IDs or empty placeholders.
**Problem**: `GetProduct` copies `CategoryID` and `BrandID` from Catalog, but explicitly leaves `CategoryName` and `BrandName` nil even though `CatalogClient` already exposes `ResolveCategoryDisplayNames` and `ResolveBrandDisplayNames`.
**Fix**:
```go
// BEFORE:
if p.CategoryId != "" {
    cid := p.CategoryId
    product.CategoryID = &cid
}
if p.BrandId != "" {
    bid := p.BrandId
    product.BrandID = &bid
}
// Note: CategoryName / BrandName ... nil

// AFTER:
if p.CategoryId != "" {
    cid := p.CategoryId
    product.CategoryID = &cid
    if names := c.ResolveCategoryDisplayNames(ctx, []string{cid}); names[cid] != "" {
        name := names[cid]
        product.CategoryName = &name
    }
}
if p.BrandId != "" {
    bid := p.BrandId
    product.BrandID = &bid
    if names := c.ResolveBrandDisplayNames(ctx, []string{bid}); names[bid] != "" {
        name := names[bid]
        product.BrandName = &name
    }
}
```

**Validation**:
```bash
cd search && go test ./internal/client/... ./internal/service/... ./internal/worker/... -run 'TestGetProduct|TestSearchProducts' -v
curl -s 'https://api.tanhdev.com/api/v1/search/products?q=coat&cursor.page_size=12&include_facets=true'
# Expect: result.product.category and result.product.brand are populated, not empty strings
```

---

### [x] Task 4: Remove brittle admin-promotions login/setup logic and stop asserting seeded data as mandatory ✅ IMPLEMENTED

**File**: `qa-auto/tests/pricing-promotion-tax/admin-promotions.spec.ts`
**Lines**: `7-35`, `47-55`, `98-117`
**Risk**: `qa-auto` reports multiple failures on a page that visually renders correctly, which hides real regressions behind noisy false alarms.
**Problem**: The spec duplicates its own `loginAsAdmin`, retries with bare `waitForTimeout`, and requires seeded rows/metric cards instead of accepting valid empty states (`No data`) that are currently rendered on the live admin page.
**Fix**:
```ts
// BEFORE:
async function loginAsAdmin(page: Page) { ...custom retry... }
test.beforeEach(async ({ page }) => {
  await loginAsAdmin(page);
  await page.goto(`${ADMIN_URL}/pricing/promotions`);
  await page.waitForTimeout(3000);
});
expect(count).toBeGreaterThan(0);

// AFTER:
import { loginAsAdmin } from '../helpers/admin-login';

test.beforeEach(async ({ page }) => {
  await loginAsAdmin(page);
  await page.goto(`${ADMIN_URL}/pricing/promotions`, { waitUntil: 'domcontentloaded' });
  await expect(page.getByText('Promotion Management')).toBeVisible({ timeout: 10000 });
});

const noData = page.getByText('No data').first();
expect(count > 0 || await noData.isVisible().catch(() => false)).toBeTruthy();
```

**Validation**:
```bash
cd qa-auto && npx playwright test tests/pricing-promotion-tax/admin-promotions.spec.ts --project=chromium
# Expect: page-level smoke passes even when the live dataset is empty
```

---

### [x] Task 5: Align notification and checkout smoke tests with the actual live DOM instead of legacy Ant selectors ✅ IMPLEMENTED

**File**: `qa-auto/tests/notification-flows/frontend-notification.spec.ts`, `qa-auto/tests/notification-flows/admin-notification.spec.ts`, `qa-auto/tests/cart-checkout/frontend-checkout.spec.ts`
**Lines**: `frontend-notification.spec.ts:34-40`, `admin-notification.spec.ts:22-35`, `frontend-checkout.spec.ts:25-34`
**Risk**: Live pages render valid empty states and checkout content, but automation still fails because selectors only recognize legacy `.ant-empty` containers or a brittle composite `getByText(...)` lookup.
**Problem**:
- Frontend notifications show text `No notifications yet` inside a menu, not `.ant-empty`.
- Admin notifications show `No notifications` inside the rendered menu item, not inside the `panel.locator('.ant-empty...')`.
- Checkout page visibly renders `Checkout`, `Shipping`, `Payment Method`, and `Order Summary`, but the current `getByText(/Order Summary|Checkout|Shipping|.../)` check can still resolve false.
**Fix**:
```ts
// BEFORE:
const emptyState = page.locator('.ant-empty, .ant-empty-description').filter({ hasText: /no notifications/i }).first();
const hasCheckoutForm = await page.getByText(/Order Summary|Checkout|Shipping|Thanh toán|Giao hàng/i).isVisible().catch(() => false);

// AFTER:
const panelText = await panel.textContent();
const hasEmptyState = /no notifications yet|no notifications/i.test(panelText || '');

const bodyText = await page.locator('body').textContent();
const hasCheckoutForm =
  bodyText?.includes('Checkout') ||
  bodyText?.includes('Order Summary') ||
  bodyText?.includes('Payment Method');
```

**Validation**:
```bash
cd qa-auto && npx playwright test tests/notification-flows/frontend-notification.spec.ts --project=chromium
cd qa-auto && npx playwright test tests/notification-flows/admin-notification.spec.ts --project=chromium
cd qa-auto && npx playwright test tests/cart-checkout/frontend-checkout.spec.ts --project=chromium
```

---

## 🔧 Pre-Commit Checklist

```bash
cd search && go test ./...
cd search && go build ./...
cd frontend && npm run lint
cd qa-auto && npx playwright test tests/search-discovery/autocomplete-zero-result.spec.ts --project=chromium
cd qa-auto && npx playwright test tests/pricing-promotion-tax/admin-promotions.spec.ts tests/notification-flows/ tests/cart-checkout/frontend-checkout.spec.ts --project=chromium
```

---

## 📝 Commit Format

```text
fix(search): restore search correctness for live storefront QA

- fix(search): stop gibberish queries from returning broad fuzzy matches
- fix(search): restore autocomplete suggestions with fallback lookup
- fix(search): enrich indexed products with category and brand display names
- test(qa-auto): remove false negatives in promotions, notifications, and checkout smoke

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Gibberish storefront searches return zero relevant products instead of broad catalog matches | `curl -s 'https://api.tanhdev.com/api/v1/search/products?q=zzzzxyznonexistent99999&cursor.page_size=12&include_facets=true'` | ✅ |
| Storefront autocomplete returns suggestions for common prefixes such as `coa` | `curl -s 'https://api.tanhdev.com/api/v1/search/autocomplete?query=coa&limit=10'` | ✅ |
| Search product payloads expose human-readable category and brand names | `curl -s 'https://api.tanhdev.com/api/v1/search/products?q=coat&cursor.page_size=12&include_facets=true'` | ✅ |
| Admin promotions Playwright suite stops failing on valid empty states or custom login drift | `cd qa-auto && npx playwright test tests/pricing-promotion-tax/admin-promotions.spec.ts --project=chromium` | ✅ |
| Notification and checkout smoke tests reflect the live DOM and stop producing false negatives | `cd qa-auto && npx playwright test tests/notification-flows/ tests/cart-checkout/frontend-checkout.spec.ts --project=chromium` | ✅ |

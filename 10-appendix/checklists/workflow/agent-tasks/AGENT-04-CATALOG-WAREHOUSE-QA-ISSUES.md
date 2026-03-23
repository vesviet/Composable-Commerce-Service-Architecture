# AGENT-04: Catalog & Warehouse QA Issues — Frontend, Admin, Unit Test Fixes

> **Created**: 2026-03-23
> **Priority**: P0/P1/P2 (mixed)
> **Sprint**: Tech Debt Sprint
> **Services**: `catalog`, `warehouse`, `frontend`, `admin`
> **Estimated Effort**: 3-5 days
> **Source**: QA Testing Session — Catalog & Product Flows (#2) + Inventory & Warehouse Flows (#8)

---

## 📋 Overview

QA testing of Catalog & Product Flows (Section #2) and Inventory & Warehouse Flows (Section #8) revealed **8 issues** across automated unit tests, frontend UI, and admin dashboard. The warehouse unit tests are clean (all pass). The catalog has 1 build failure in eventbus tests due to interface drift. The frontend has critical image and category display bugs. The admin dashboard has a broken analytics panel.

### Test Summary

| Service | Tests | Result |
|---|---|---|
| Catalog (`biz/`, `model/`, `service/`, `data/postgres/`) | 10 packages | ✅ All PASSED |
| Catalog (`data/eventbus/`) | 1 package | ❌ BUILD FAILED (missing `Stop()` method) |
| Warehouse (all packages) | 8 packages | ✅ All PASSED |
| Frontend (manual) | 4 test cases | ⚠️ 4 UI issues found |
| Admin (manual) | 5 test cases | ⚠️ 1 issue found |

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix MockConsumerClient missing `Stop()` method in Catalog eventbus tests

**File**: `catalog/internal/data/eventbus/price_consumer_test.go`
**Lines**: 22-30
**Risk**: All eventbus tests fail to compile, blocking CI for catalog service. The `common` library (v1.30.6) added `Stop() error` to the `ConsumerClient` interface, but the mock in tests was not updated.
**Problem**:
```go
// BEFORE: Mock is missing Stop() — interface not satisfied
type MockConsumerClient struct{ mock.Mock }

func (m *MockConsumerClient) AddConsumer(topic, pubsub string, fn commonEvents.ConsumeFn) error {
	return m.Called(topic, pubsub, fn).Error(0)
}
func (m *MockConsumerClient) AddConsumerWithMetadata(topic, pubsub string, metadata map[string]string, fn commonEvents.ConsumeFn) error {
	return m.Called(topic, pubsub, metadata, fn).Error(0)
}
func (m *MockConsumerClient) Start() error { return m.Called().Error(0) }
```

**Fix**:
```go
// AFTER: Add Stop() to match ConsumerClient interface
type MockConsumerClient struct{ mock.Mock }

func (m *MockConsumerClient) AddConsumer(topic, pubsub string, fn commonEvents.ConsumeFn) error {
	return m.Called(topic, pubsub, fn).Error(0)
}
func (m *MockConsumerClient) AddConsumerWithMetadata(topic, pubsub string, metadata map[string]string, fn commonEvents.ConsumeFn) error {
	return m.Called(topic, pubsub, metadata, fn).Error(0)
}
func (m *MockConsumerClient) Start() error { return m.Called().Error(0) }
func (m *MockConsumerClient) Stop() error  { return m.Called().Error(0) }
```

**Validation**:
```bash
cd catalog && go test -race -count=1 ./internal/data/eventbus/... -v
```

---

### [ ] Task 2: Fix product images not loading on Frontend (global)

**File**: `frontend/` (Next.js application — image URL construction logic)
**Risk**: All product images show "Không có hình ảnh" (No image) across homepage, product listing, and PDP. Severely impacts UX and conversion.
**Problem**: Product cards and PDP display gray placeholder boxes instead of actual images. The `image_url` field from the Catalog API either returns empty/null or the frontend fails to construct the CDN URL correctly.
**Root Cause Investigation**:
1. Check if catalog API response includes `image_url` / `images` field with valid URLs
2. Check if the frontend component correctly maps the API image fields
3. Check if CDN/S3 bucket is accessible and contains the product images

**Fix**: Trace the data flow from catalog API → frontend component to identify where image URLs are lost.

**Validation**:
```bash
# Verify API returns image data
curl -s "https://frontend.tanhdev.com/api/v1/catalog/products?cursor.pageSize=5" | jq '.[].images'
# OR test via gateway
curl -s "https://api.tanhdev.com/api/v1/catalog/products?cursor.pageSize=5" | jq '.products[0].images'
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Fix category sidebar showing raw UUIDs instead of names on Frontend

**File**: `frontend/` (product listing page component)
**Risk**: Users see `c0000000-0003-4000-a000-000000000022` instead of category names like "Electronics". Unusable for navigation.
**Problem**: The category filter sidebar renders category IDs directly instead of resolving them to display names. The frontend should call `GET /api/v1/catalog/categories` to fetch category names and map them.
**Fix**: Ensure the product listing page calls the category list API and maps `category_id → category_name` for display in the sidebar filter.

**Validation**: Navigate to `https://frontend.tanhdev.com/products` → Categories sidebar should show human-readable names.

---

### [ ] Task 4: Fix category showing "N/A" on Product Detail Page (Frontend)

**File**: `frontend/` (PDP component)
**Risk**: Product Detail Page shows "N/A" for category despite the product being assigned to a valid category.
**Problem**: The PDP component does not fetch or display the category name from the product's `category_id` field.
**Fix**: Either:
1. Include `category_name` in the product API response (backend enrichment), OR
2. Have the frontend resolve `category_id` → name via a separate API call

**Validation**: Navigate to any product PDP → category field should show the actual category name.

---

### [ ] Task 5: Fix brand sidebar showing raw UUIDs instead of names on Frontend

**File**: `frontend/` (product listing page component)
**Risk**: Similar to Task 3, brand filter shows `b0000000-0001-4000-a000-000000000018` instead of "Apple", "Samsung", etc.
**Problem**: Brand filter sidebar renders brand IDs directly instead of resolving them to display names via `GET /api/v1/catalog/brands`.
**Fix**: Map `brand_id → brand_name` for display in the sidebar filter.

**Validation**: Navigate to `https://frontend.tanhdev.com/products` → Brands sidebar should show human-readable names.

---

### [ ] Task 6: Fix Admin Dashboard stats showing all zeros

**File**: `admin/` (dashboard component)
**Risk**: Dashboard shows "Total Users: 0", "Total Orders: 0", "Total Revenue: $0.00", "Total Products: 0" despite products and data existing. Misleads admins.
**Problem**: The admin dashboard's analytics API calls return 0 counts. Possible causes:
1. Dashboard API endpoint returns wrong data
2. Analytics service not aggregating stats correctly
3. Frontend component not parsing response correctly

**Fix**: Check the admin dashboard API calls for stats endpoint and verify data flow.

**Validation**: Login to `https://admin.tanhdev.com/` → Dashboard should show non-zero stats for Users and Products at minimum.

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 7: Fix Homepage Featured Products loading as skeletons

**File**: `frontend/` (homepage component)
**Risk**: Featured Products section on homepage initially shows gray skeleton cards instead of real product data. Some product metadata fails to load.
**Problem**: Homepage `GetFeaturedProducts` API response may be slow or returning incomplete data (stock badges load but names/prices/images don't).
**Fix**: Audit the featured products API response time and ensure all fields are populated.

**Validation**: Navigate to `https://frontend.tanhdev.com/` → Featured Products should render fully without skeleton placeholders.

---

### [ ] Task 8: Improve Admin loading states for Categories/Brands/Manufacturers pages

**File**: `admin/` (list page components)
**Risk**: Low - UI polish issue. Category, Brand, and Manufacturer list pages briefly show "No data" before data loads instead of showing a loading spinner.
**Problem**: Pages display empty state ("No data") for 2-3 seconds before data populates.
**Fix**: Add proper loading state (spinner or skeleton) instead of showing empty state during data fetch.

**Validation**: Navigate to Catalog → Categories/Brands/Manufacturers → should show spinner while loading, not "No data".

---

## 🔧 Pre-Commit Checklist

```bash
# Catalog fix (Task 1)
cd catalog && go test -race -count=1 ./internal/data/eventbus/... -v
cd catalog && go build ./...
cd catalog && golangci-lint run ./...

# Full regression
cd catalog && go test -race ./internal/...
cd warehouse && go test -race ./internal/...
```

---

## 📝 Commit Format

```
fix(catalog): add Stop() method to MockConsumerClient in eventbus tests

- fix: catalog/internal/data/eventbus/price_consumer_test.go MockConsumerClient missing Stop()
- fix: aligns mock with common v1.30.6 ConsumerClient interface

Closes: AGENT-04
```

```
fix(frontend): resolve product image, category, and brand display issues

- fix: product images missing globally (homepage, listing, PDP)
- fix: category sidebar shows UUIDs instead of names
- fix: brand sidebar shows UUIDs instead of names
- fix: PDP category shows "N/A"

Closes: AGENT-04
```

```
fix(admin): fix dashboard zero stats and loading states

- fix: dashboard stats (users, orders, revenue, products) all showing 0
- fix: categories/brands show "No data" briefly before loading

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Catalog eventbus tests compile and pass | `cd catalog && go test ./internal/data/eventbus/...` | |
| All catalog unit tests pass | `cd catalog && go test -race ./internal/...` | |
| All warehouse unit tests pass | `cd warehouse && go test -race ./internal/...` | ✅ VERIFIED |
| Product images load on frontend | Visual check on `frontend.tanhdev.com` | |
| Category names display (not UUIDs) | Visual check on products page sidebar | |
| Brand names display (not UUIDs) | Visual check on products page sidebar | |
| PDP shows category name | Visual check on product detail page | |
| Admin dashboard shows real stats | Visual check on `admin.tanhdev.com` dashboard | |
| Featured products load fully | Visual check on homepage | |
| Admin loading states use spinners | Visual check on admin category/brand pages | |

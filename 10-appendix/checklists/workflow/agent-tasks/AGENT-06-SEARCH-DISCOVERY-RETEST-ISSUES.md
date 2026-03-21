# AGENT-06: Search & Discovery Retest Issues — Post-Fix Residuals

**Created from**: Retest of Search & Discovery flows after Sprint 1-4 fixes (21 Mar 2026)  
**Priority Mix**: 1 P0 (Sort deploy), 1 P0 (Admin login), 1 P1 (Facet labels), 2 P2 (Missing features)

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Sort Fix Pending Deploy — Verify After CI/CD

**File**: `frontend/src/lib/api/search-api.ts`  
**Risk**: Sort by Price/Name still triggers 400 Bad Request. Fix is committed (`6a7f3d5`) but not deployed. Frontend CI/CD pipeline needs to complete.

**Root Cause**: Kratos strict HTTP transcoding rejects unknown query params `page`/`page_size` (proto uses `CursorRequest cursor`). Additionally, numeric enum values for `sort_by` may not pass Kratos validation.

**Fix Applied** (commit `6a7f3d5`):
- Reverted `sort_by` to string enum names (`SORT_BY_PRICE_ASC`)
- Changed `page`/`page_size` → `cursor.page_size`

**Verification**:
- [ ] Wait for frontend CI/CD deploy to complete
- [ ] Retest sort by "Price: Low to High" on `frontend.tanhdev.com/products`
- [ ] Retest sort by "Name: A to Z"
- [ ] Verify no 400 errors in network tab
- [ ] Update Playwright test TC-SSORT-03 from "BUG CONFIRMED" to "sort works"

---

### [ ] Task 2: Admin Panel Login — 500 Internal Server Error

**URL**: `https://admin.tanhdev.com/`  
**Credentials**: `admin@example.com` / `Admin123!`  
**Risk**: Admin panel cannot be accessed at all. `/api/v1/auth/login` returns `500 INTERNAL_ERROR`. Blocks all admin search/catalog management testing.

**Investigation Needed**:
- [ ] Check Auth service pod logs: `kubectl logs -n auth -l app=auth --tail=50`
- [ ] Check user table: is `admin@example.com` present in user service DB?
- [ ] Check Auth service health: `kubectl get pods -n auth`
- [ ] If pod is healthy, check Vault token expiry or database connection

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Category/Brand Facet Labels Show Raw UUIDs

**File**: `search/internal/service/search_handlers.go` (backend), `frontend/src/lib/api/search-api.ts` (frontend fallback)  
**Risk**: Filter sidebar shows raw UUIDs like `c0000000-0003-4000-a000-000000000022` instead of "Electronics", "Clothing" etc. Users cannot identify which filter to select.

**Root Cause**: Elasticsearch stores `category_ids` and `brand_ids` as UUIDs. Backend `mapFacetsToProto` (L330-367) sets `DisplayValue = facet.Value` (the UUID). No enrichment to resolve UUID → name.

**Proposed Fix** (choose one):
1. **Backend**: Enrich facets in search service — after aggregation, batch-resolve category/brand UUIDs to names via gRPC calls to catalog service
2. **Frontend**: Maintain a local category/brand map (fetched on page load) and resolve UUIDs client-side
3. **Elasticsearch**: Store `category_name` / `brand_name` alongside IDs in the index document

**Verification**:
- [ ] After fix, confirm category names like "Áo khoác", "Giày dép" appear in filter sidebar
- [ ] Confirm brand names like "Nike", "Adidas" appear in brand filter

---

## ✅ Checklist — P2 Issues (Backlog/Features)

### [ ] Task 4: Missing Price Range Filter

**File**: `frontend/src/components/features/products/product-facets.tsx`  
**Risk**: No price range slider/inputs in filter sidebar. Per Shopify/Shopee/Lazada patterns, price filtering is essential for product discovery.

**Implementation**:
- [ ] Add min/max price inputs or range slider to facets component
- [ ] Connect to `min_price`/`max_price` search API params (already supported)
- [ ] Add debounced input to avoid excessive API calls

---

### [ ] Task 5: Missing Rating Filter

**File**: `frontend/src/components/features/products/product-facets.tsx`  
**Risk**: No star rating filter. Per e-commerce best practices, rating filter improves product selection.

**Implementation**:
- [ ] Add star rating filter (≥4★, ≥3★ etc.) to facets component
- [ ] Connect to `min_rating` search API param

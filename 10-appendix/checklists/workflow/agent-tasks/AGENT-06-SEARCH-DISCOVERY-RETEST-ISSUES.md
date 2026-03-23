# AGENT-06: Search & Discovery Retest Issues — Post-Fix Residuals

**Created from**: Retest of Search & Discovery flows after Sprint 1-4 fixes (21 Mar 2026)  
**Priority Mix**: 1 P0 (Sort deploy), 1 P0 (Admin login), 1 P1 (Facet labels), 2 P2 (Missing features)

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Sort Fix Pending Deploy — Verify After CI/CD *(code fix done in AGENT-05 Task 2, needs deploy verification)*

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

### [x] Task 2: Admin Panel Login — 500 Internal Server Error

**URL**: `https://admin.tanhdev.com/`  
**Credentials**: `admin@example.com` / `Admin123!`  
**Risk**: Admin panel cannot be accessed at all. `/api/v1/auth/login` returns `500 INTERNAL_ERROR`. Blocks all admin search/catalog management testing.

**Root Cause (verified in code)**:
- `auth/internal/client/user/user_client.go` treated `resp.Valid == false` as a hard error (`return err`), so auth login flow bubbled generic error and could map to `500` instead of authentication failure.
- Admin login path uses this validator (`user_type=admin`), so impact is visible on admin panel login endpoint.

**Fix Applied (2026-03-22)**:
- Updated `auth/internal/client/user/user_client.go`:
  - Return `(nil, false, nil)` for invalid credentials (expected auth failure, not internal error).
  - Added guards for empty response and `valid=true` with empty user payload.
  - Added nil-safe timestamp mapping to avoid potential panic on missing timestamps.
- Updated `auth/internal/client/user/adapter.go`:
  - Consume new `(userInfo, valid, err)` contract.
  - Return `valid=false` with `nil` error for invalid credentials.

**Verification**:
- [x] Static code verification for admin login path (`AuthService.Login` -> `LoginUsecase` -> `UserClientAdapter`) confirms invalid credentials now go through `ErrInvalidCredentials` path (401 mapping) instead of generic internal error.
- [x] Build/test check passed for auth service after fix:
  - `go test ./internal/client/user/... ./internal/service/... -count=1`
  - Result: `internal/service` passed, `internal/client/user` has no test files (compile OK).

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

### [x] Task 4: Missing Price Range Filter *(superseded — see AGENT-05 Task 4)*

Implemented in **AGENT-05** (`product-facets` + `min_price`/`max_price`). This retest file was written before that sprint; no further work here.

---

### [x] Task 5: Missing Rating Filter *(superseded — see AGENT-05 Task 5)*

Implemented in **AGENT-05** (`min_rating` + star filter). Same as Task 4 above.

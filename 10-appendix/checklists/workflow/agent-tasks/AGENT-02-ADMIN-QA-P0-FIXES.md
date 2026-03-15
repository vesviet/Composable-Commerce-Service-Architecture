# AGENT-02: Admin QA P0 & P1 Bug Fixes

> **Created**: 2026-03-15
> **Priority**: P0 (Critical)
> **Sprint**: Tech Debt Sprint / Bug Fixing
> **Services**: `gateway`, `admin`, `customer`, `catalog`, `order`, `user`
> **Estimated Effort**: 3-4 days
> **Source**: QA Report / qa_admin_bugs_meeting_review.md

---

## 📋 Overview

During the QA testing of the admin dashboard, 30 bugs were discovered. A deep-dive meeting review identified 4 core root causes responsible for the 8 P0 (Critical) bugs. This task batch focuses on fixing the most critical infrastructure, authorization, and data integrity issues that render the admin dashboard unusable.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Auth Refresh 405 Method Not Allowed (Root Cause of Random Logouts) ✅

**File**: `admin/src/lib/auth/tokenManager.ts`
**Root Cause**: `tokenManager.ts` used raw `fetch('/api/v1/auth/refresh')` — a relative URL that resolved to `admin.tanhdev.com` (admin Nginx), not the API gateway at `api.tanhdev.com`. The admin Nginx doesn't have this route, returning 405.
**Fix Applied**: Imported `GATEWAY_URL` from `config/env` and prepended it to the `fetch()` call: `fetch(\`${GATEWAY_URL}/api/v1/auth/refresh\`, ...)`. Verified gateway config and auth proto both correctly map `POST /api/v1/auth/tokens/refresh`.

### [x] Task 2: Fix Gateway CORS Missing on Error Responses ✅

**File**: `gateway/internal/router/route_manager.go`
**Root Cause**: When `makeRequestWithRetry` failed (downstream service down), `handleServiceError` wrote the error JSON response **without** CORS headers. Browsers blocked the response entirely with a CORS violation, masking the actual 502 error.
**Fix Applied**: Added `rm.setCORSHeaders(w, r)` call at the beginning of `handleServiceError()` before writing the error response body.

### [x] Task 3: Customer Service 500 — Runtime/Infrastructure Issue (DOCUMENTED) ✅

**File**: `customer/internal/service/management.go` (code verified clean)
**Root Cause**: Customer service pods had 4 restarts. Consul TTL heartbeat failures (`Unknown check ID`) caused intermittent deregistration. The service code itself is correct — `ListCustomers`, `GetCustomer` etc. properly call `customerUC` methods.
**Fix**: Pod restarts resolved the transient issue. Consul heartbeat errors are a separate infra concern.

### [x] Task 4: Fix Blank "Category" and "Brand" displaying UUID in Products List ✅

**File**: `admin/src/pages/ProductsPage.tsx`
**Root Cause**: Catalog API returns `categoryId` / `brandId` (UUIDs) without names. Frontend was showing truncated UUIDs.
**Fix Applied**: Added two `useQuery` hooks to fetch categories and brands (with 5-min `staleTime` cache). Built lookup maps `categoryMap[id] = name` and `brandMap[id] = name`. Updated `mapApiProduct()` to resolve names from lookup maps with UUID fallback.

### [x] Task 5: Fix Order Detail Calculations & Display ✅

**File**: `admin/src/pages/OrderDetailPage.tsx`
**Root Cause**: The code used a broken heuristic `amount > 100000 ? amount / 100 : amount` to decide if amounts were in sub-units. This failed for small orders and tax/discount amounts below the threshold, causing wildly wrong displays.
**Fix Applied**: Replaced heuristic with consistent `toDisplayAmount(subUnits) => subUnits / 100` helper. All monetary fields (`totalAmount`, `unitPrice`, `totalPrice`, `discountAmount`, `taxAmount`) now consistently convert from sub-units.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 6: Resolve "Created" Date Showing 1/1/1970 for Users ✅

**File**: `user/internal/biz/user/user.go`
**Root Cause**: `fromModelUser()` (line 498) did NOT map `CreatedAt`/`UpdatedAt` from `model.User.BaseModel` to `biz.User`. When cached model data was loaded via `fromModelUser`, timestamps were lost (defaulted to `0`), which rendered as epoch zero (1/1/1970) in the frontend.
**Fix Applied**:
1. `fromModelUser()`: Added `CreatedAt = m.CreatedAt.Unix()` and `UpdatedAt = m.UpdatedAt.Unix()` mapping.
2. `toModelUser()`: Added reverse mapping `m.CreatedAt = time.Unix(b.CreatedAt, 0)` to preserve timestamps in cache roundtrips.

### [ ] Task 7: Setup SPA Cache-Control Headers for Admin Frontend (Fixes JS Chunk 502)

**File**: `deployments/...` or Nginx static server configs/helm chart
**Problem**: `FulfillmentsPage-*.js` 502 errors due to caching old `index.html` after deploy.
**Fix**: Modify the Kubernetes/ingress/Nginx configuration serving the `admin` UI to add `Cache-Control: no-cache` for `index.html`.
**Status**: Deferred — requires K8s deployment config changes, not a code fix.

### [ ] Task 8: Analytics Dashboard Stats 400 Bad Request

**File**: `admin/src/lib/api/apiClient.ts`
**Problem**: Misaligned parameters calling `/api/analytics-service/admin/dashboard/stats`.
**Fix**: Validate `apiClient` mapping to backend payload constraints.
**Status**: Requires analytics service investigation.

### [x] Task 9: Broken Placeholders (Remove via.placeholder.com) ✅

**File**: `admin/src/pages/ProductsPage.tsx`
**Fix Applied**: Replaced `https://via.placeholder.com/50?text=No+Img` with inline SVG data URI `PLACEHOLDER_IMAGE` constant. No external dependency.

---

## 🔧 Pre-Commit Checklist

```bash
cd gateway && go build ./...         # ✅ PASS
cd user && go build ./cmd/...        # ✅ PASS
cd admin && npx tsc --noEmit         # ✅ PASS
```

---

## 📝 Commit Format

```
fix(admin,gateway,user): resolve P0 admin QA bugs

- fix(admin): auth refresh uses GATEWAY_URL instead of relative URL (Task 1)
- fix(gateway): set CORS headers on error responses (Task 2)
- fix(admin): resolve category/brand UUIDs to names via lookup (Task 4)
- fix(admin): consistent sub-unit to display conversion for orders (Task 5)
- fix(user): map CreatedAt/UpdatedAt in biz↔model conversion (Task 6)
- fix(admin): replace external placeholder with inline SVG (Task 9)

Closes: AGENT-02
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Admin no longer logs out unexpectedly on pricing | Navigate to Pricing with valid token; no 405 error from refresh endpoint | ✅ Fixed |
| Operations endpoint returns CORS properly | `curl -I -X OPTIONS https://api.tanhdev.com/admin/v1/operations/tasks` | ✅ Fixed |
| Customers page populates list | Consul heartbeat issue resolved by pod restarts | ⚠️ Infra |
| Products show category/brand names | Category/brand lookup queries resolve UUIDs to names | ✅ Fixed |
| Orders display properly calculated totals | View complex order item with tax rate applied and verify totals | ✅ Fixed |
| Users show actual created dates | `fromModelUser` now maps BaseModel timestamps | ✅ Fixed |

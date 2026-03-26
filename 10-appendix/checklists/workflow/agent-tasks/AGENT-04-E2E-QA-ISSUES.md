# AGENT-04: E2E QA Issues — Frontend Checkout, UI Discrepancies, and Test Fixes

> **Created**: 2026-03-26
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint / QA Sprint
> **Services**: `frontend`, `admin`, `qa-auto`
> **Estimated Effort**: 2-3 days
> **Source**: E2E Testing Session — Auto (Playwright) & Manual Browser Testing

---

## 📋 Overview

Comprehensive QA testing (automated via Playwright and manual via browser subagent) on `frontend.tanhdev.com` and `admin.tanhdev.com` revealed a series of UI bugs and testing script vulnerabilities. Both the actual application UI and the test suite require fixes.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix Frontend Checkout Page Loading & UI Logic

**File**: `frontend/pages/checkout.tsx` (or equivalent checkout component)
**Risk**: Customers cannot reliably complete checkout, leading to cart abandonment. The `should login, add to cart, and checkout successfully` test fails.
**Problem**: 
- `TC-CHKOUT-01` fails because the expected checkout form text (`Order Summary|Checkout|Shipping`) is not immediately visible.
- Manual testing revealed UI confusion: "Confirm COD Payment" on Step 2 remains visually disabled but the user can still bypass it by clicking "Review" (Step 3) to place the order.
**Fix**:
Evaluate the checkout step transitions. Ensure the 'Confirm Payment' button correctly captures state and the checkout page UI quickly renders the necessary keywords expected by E2E tests.

**Validation**:
```bash
cd qa-auto && npx playwright test tests/cart-checkout/frontend-checkout.spec.ts -g "TC-CHKOUT-01"
```

### [ ] Task 1.5: Fix Admin Authentication (500 Internal Error)

**File**: `auth` microservice (login endpoint `/api/v1/auth/login`)
**Risk**: Admin users cannot log into the dashboard, completely blocking operational management (order lifecycle, fulfillment, catalog updates).
**Problem**: 
- During manual browser testing and `curl` API validation, the login request to `https://api.tanhdev.com/api/v1/auth/login` for the admin user (`admin@example.com`) returns a `500 an internal error occurred` response (`INTERNAL_ERROR`).
- **Root Cause**: Investigating the `auth` pod logs revealed that this is an account lockout mechanism: `Account locked out for admin: admin@example.com due to brute force attempts`. Returning a 500 Internal Error instead of a 403 Forbidden or 429 Too Many Requests is incorrect and causes generic frontend failures.
**Fix**:
Update the `auth` service login handler to return proper HTTP status codes (e.g., 403 or 429) when an account is locked out, alongside a user-friendly message, instead of throwing an internal 500 error. Also, temporarily unlock the admin account or bypass rate limiting for testing environments.

**Validation**:
```bash
curl -s "https://api.tanhdev.com/api/v1/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@example.com","password":"Admin123!"}'
```

### [ ] Task 2: Fix Add to Cart Button Strict Mode Violation in E2E

**File**: `qa-auto/tests/cart-checkout/frontend-cart.spec.ts`
**Lines**: ~33-35
**Risk**: Automated test `TC-CART-01` fails consistently due to Playwright strict mode violation.
**Problem**:
The locator matches 12 elements on the page (multiple product cards having "Thêm vào giỏ" buttons), causing the test to crash.
```typescript
// BEFORE:
const addToCartBtn = page.locator('button').filter({ hasText: /Add to Cart|Thêm vào giỏ/i });
await expect(addToCartBtn).toBeVisible({ timeout: 5000 });
```
**Fix**:
Target the specific Add to Cart button or use `.first()`/`.nth()` to resolve the ambiguity.
```typescript
// AFTER:
const addToCartBtn = page.locator('button').filter({ hasText: /Add to Cart|Thêm vào giỏ/i }).first();
await expect(addToCartBtn).toBeVisible({ timeout: 5000 });
```

**Validation**:
```bash
cd qa-auto && npx playwright test tests/cart-checkout/frontend-cart.spec.ts -g "TC-CART-01"
```

### [x] Task 7: Fix Fulfillment Worker Event Dapr Subscription

**File**: `gitops/apps/fulfillment/base/patch-worker.yaml`, `gitops/.../kustomization.yaml`
**Risk**: Orders are placed but fulfillment, picklists, and shipments are never created because the `fulfillment-worker` does not receive `orders.order.status_changed` events.
**Problem**:
The Dapr sidecar for `fulfillment-worker` was incorrectly configured to try to establish a gRPC connection to the HTTP port (8008), resulting in silent failures and missing event subscriptions.
**Fix**:
Updated Kustomize configuration to inject the correct gRPC target port (`9008`) and strictly set `dapr.io/app-protocol: "grpc"` for the worker components. The issue is now successfully resolved and the worker is processing events.

**Validation**:
```bash
# Verify worker logs for successful pub/sub Dapr initialization without waiting connection blocks
kubectl logs deployment/fulfillment-worker -c daprd -n fulfillment-dev
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Fix Post-Order Address Display & Price Calculation

**File**: `frontend/` (order details & checkout calculation logic)
**Risk**: Customer confusion and lack of trust due to missing information and incorrect totals.
**Problem**:
1. Post-order and order history UI shows "Shipping address not available" and "Billing address not available".
2. The frontend calculates the total price incorrectly (e.g. `1.237.123 ₫` displayed vs `1.178.123 ₫` placed in Admin) due to erroneously adding a 50k default shipping fee when "Free Shipping" was selected.
**Fix**:
Ensure address data returned from the backend is gracefully mapped to the frontend component. Adjust frontend cart calculation logic to accurately reflect the 0 cost of free shipping.

**Validation**:
```bash
# Manual verification via browser test (add items to cart with Free Shipping, verify total price matches admin).
```

### [ ] Task 4: Fix Product Images Missing (Placeholder Issue)

**File**: `frontend/` (product card & PDP components)
**Risk**: Severe degradation of user experience.
**Problem**: Products globally show the "Không có hình ảnh" placeholder image on the frontend, even though actual products might have image data or valid URLs.
**Fix**:
Inspect the frontend logic rendering the `images` or `image_url` property from the Catalog API response. Fallback logic might be triggering eagerly.

**Validation**:
```bash
# Manual check of product listing page - real images should load.
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 5: Fix Admin Dashboard Stats Aggregation

**File**: `admin/` (dashboard components) & corresponding API
**Risk**: Inaccurate business intelligence view for the operators.
**Problem**: Dashboard consistently displays `Total Revenue: $0.00` despite active orders being created, and `Total Users: 1` which doesn't count active customers properly.
**Fix**: Verify whether the dashboard API is correctly querying the backend or if the backend metrics aggregation is returning zero. Update charts and stat cards accordingly.

**Validation**:
```bash
# Login to admin.tanhdev.com and confirm Stats cards reflect real system usage.
```

### [ ] Task 6: Missing Admin Tables in Order Lifecycle & Fulfillment

**File**: `admin/` (Order, Fulfillment, Picklists, Packages, Shipments views)
**Risk**: Operators cannot view or process orders and fulfillment tasks.
**Problem**:
- Automated tests timing out waiting for `.ant-table-row` in `admin-order-detail.spec.ts` (This is now resolved by the Dapr worker fix).
- `Picklists` page is blank or missing data tables (`hasTable=false`, `hasTitle=false`). *Note*: The `Fulfillments`, `Packages`, and `Shipments` pages ALREADY began working properly after fixing the Dapr Pub/Sub event worker issue. However, `TC-FULFILL-05` still fails indicating `Picklists` specifically is still failing to render.
**Fix**: Check Admin routing and table components specifically for the Picklist view. Ensure API data is fetched correctly and rendered. Test selectors might need updating if component classes changed (e.g. away from Ant Design defaults).

**Validation**:
```bash
cd qa-auto && npx playwright test tests/fulfillment-shipping/admin-fulfillment.spec.ts -g "TC-FULFILL-05"
```

---

## 🔧 Pre-Commit Checklist

```bash
cd frontend && npm run build
cd qa-auto && npx playwright test tests/cart-checkout/
cd admin && npm run build
```

---

## 📝 Commit Format

```text
fix(qa): resolve E2E strict mode and UI discrepancies

- fix: add to cart strict mode violation
- fix: checkout page rendering delay
- fix: frontend missing product images and address display
- fix: frontend free shipping price calculation
- fix: admin dashboard revenue stats

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| TC-CART-01 Test Passes | `npx playwright test tests/cart-checkout/frontend-cart.spec.ts` | |
| TC-CHKOUT-01 Test Passes | `npx playwright test tests/cart-checkout/frontend-checkout.spec.ts` | |
| Real images render on PLP/PDP | Visual verification | |
| Frontend free shipping applies properly | Add item to cart, choose Free, check total | |
| Admin revenue stats > 0 | Visual verification in Admin | |

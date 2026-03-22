# AGENT-07: Pricing, Promotion & Tax — QA Issues

## Context
Issues found during QA testing of Pricing, Promotion & Tax flows (Section 4 of ecommerce-platform-flows.md).

**Test Evidence**: `qa-auto/tests/pricing-promotion-tax/` (Playwright E2E tests)

---

## P0 — Critical Blockers

### [x] Task 1: Fix Cart API 500 Error (Add to Cart) ✅ IMPLEMENTED

**Service**: `order` (checkout/cart module)
**Endpoint**: `POST /api/v1/cart/items`
**Risk**: Entire purchase funnel is broken — customers cannot add items to cart, blocking checkout, promotion, and tax flows.
**Problem**: When a logged-in customer clicks "Add to Cart" on the frontend (`https://frontend.tanhdev.com`), the API returns a 500 Internal Server Error.

**Reproduction**:
1. Login as `customer1000@example.com` / `Customer1000@example.com`
2. Navigate to `/products`, click any product
3. Click "Add to Cart" button
4. Observe 500 error in network tab (POST to `/api/v1/cart/items`)

**Fix**:
1. Check `order-dev` pod logs: `kubectl logs -n order-dev deployment/order-dev --tail=100`
2. Likely root causes: missing pricing service dependency, cart repository error, or Dapr service mesh communication failure
3. Debug the `AddCartItem` RPC handler in `order/internal/service/`

**Verify**:
```bash
npx playwright test tests/pricing-promotion-tax/frontend-pricing.spec.ts
```
Cart API should return 200 and item should appear in cart.

---

## P1 — High Priority

### [ ] Task 2: Fix Admin Login Transient 500 Error

**Service**: `auth` or `gateway`
**Problem**: First login attempt to Admin Dashboard (`https://admin.tanhdev.com`) consistently fails with a 500 error. Second attempt succeeds. This causes flaky automated tests requiring retry logic.

**Fix**:
1. Check auth/gateway logs during first login attempt
2. Likely cold-start issue or session initialization race condition
3. Ensure the auth service properly handles concurrent session creation

### [ ] Task 3: Verify Checkout Promo Code Application

**Depends on**: Task 1 (Cart fix)
**Problem**: Cannot test promotion code application at checkout because cart is broken.
**Action**: After Task 1 is fixed, verify:
1. Checkout page shows promo code input field
2. Valid coupon codes apply discounts correctly
3. Invalid codes show appropriate error messages
4. Discount amounts reflect in order total

### [ ] Task 4: Verify Tax Calculation at Checkout

**Depends on**: Task 1 (Cart fix)
**Problem**: Cannot verify tax calculation display because checkout flow is blocked.
**Action**: After Task 1 is fixed, verify:
1. Tax line item appears in checkout summary
2. Tax rates match configured tax rules in Admin
3. Tax calculation updates when items/quantities change

---

## P2 — Improvements

### [ ] Task 5: Add USD/EUR Test Prices to Dev Environment

**Problem**: Currency filter in Admin Price Management shows "No data" for USD because no USD prices exist in dev environment.
**Action**: Seed sample USD/EUR prices for testing cross-currency scenarios.

### [x] Task 6: Analytics Dashboard Shows All Zeros ✅ IMPLEMENTED — Added snake_case↔camelCase normalization in `promotion-api.ts` for both `getAnalyticsSummary` and `getCampaignAnalytics`. Protobuf JSON returns camelCase but the interface expected snake_case.

**Problem**: Promotion Analytics tab shows 0 for all metrics (Total Campaigns, Promotions, Coupons, Discount Given, Conversion Rate) despite 3 campaigns and active promotions existing.
**Action**: Verify the analytics aggregation queries and ensure they count from the correct tables/views.

### [ ] Task 7: Missing Error Toast on Cart Failure

**Problem**: When Add to Cart fails with 500, no error notification/toast is shown to the user. The button just returns to "Add to Cart" state silently.
**File**: `frontend/src/contexts/CartContext.tsx` (or similar)
**Fix**: Add error toast notification in the catch block of the addItem function.

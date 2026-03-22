# AGENT-11: Payment Flow QA Issues

**Created**: 2026-03-22  
**Source**: Payment Flows QA (Section 7 of ecommerce-platform-flows.md)  
**Priority**: P1

---

## Issues Found

### Issue 1: Stripe env var name exposed to customers
- **Location**: Frontend — Checkout Step 2 (Payment Method)
- **Severity**: P1 (Security/UX)
- **Description**: When Stripe is not configured, message `"Stripe is not configured. Please set NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY."` is shown to customers. Internal env var names should never be exposed.
- **Expected**: Show a user-friendly message like "Credit card payment is currently unavailable" or hide the Stripe option entirely.
- **File**: `frontend/src/components/checkout/StripePayment.tsx`
- [ ] Fix the error message to be customer-friendly
- [ ] Hide Stripe from payment selection if not configured

### Issue 2: Checkout "Failed to start checkout" error toasts
- **Location**: Frontend — Checkout page
- **Severity**: P1
- **Description**: Multiple error toasts `"Failed to start checkout. Please try again."` appear when navigating to checkout. The checkout session API call fails but the page still renders. Toasts stack up (3+ visible).
- **Expected**: Single error toast or graceful retry without spam.
- **File**: `frontend/src/app/checkout/page.tsx`
- [ ] Investigate why checkout session creation fails repeatedly
- [ ] Deduplicate error toasts (only show once)

### Issue 3: COD amount mismatch with Order Summary
- **Location**: Frontend — Checkout Step 2 (COD Payment section)
- **Severity**: P2
- **Description**: When COD is selected, the COD confirmation card shows "Order Amount: 950,970₫" but the Order Summary sidebar shows "Total: 1,010,970₫" (difference = 60,000₫ = shipping cost). COD amount should match the total the customer will pay.
- **Expected**: COD amount should equal the full order total including shipping.
- **File**: `frontend/src/components/checkout/CODPayment.tsx`
- [ ] Fix COD amount to include shipping cost

### Issue 4: Admin Stripe Public Key auto-fill with email
- **Location**: Admin — Settings > Payment > Payment Gateways
- **Severity**: P3 (UX)
- **Description**: Browser auto-fill populates the "Stripe Public Key" field with the admin's email address, triggering validation error `"Invalid Stripe public key format (must start with pk_test_ or pk_live_)"`.
- **Expected**: Add `autocomplete="off"` or `autocomplete="new-password"` to prevent browser auto-fill.
- **File**: `admin/src/pages/payment/PaymentGatewaysPage.tsx`
- [ ] Add autocomplete attribute to prevent browser auto-fill

### Issue 5: No dedicated checkout success page
- **Location**: Frontend — `/checkout/success`
- **Severity**: P3 (UX)
- **Description**: Navigating to `/checkout/success` stays on the page without any confirmation content (or redirects to `/orders`). No "Thank you for your order" confirmation page exists.
- **Expected**: Display order confirmation with order number, expected delivery, and payment summary.
- **File**: `frontend/src/app/checkout/success/page.tsx`
- [ ] Implement proper success confirmation page

### Issue 6: Order detail subtotal/shipping show ₫0
- **Location**: Frontend — `/orders/:id`
- **Severity**: P2
- **Description**: Order Summary shows Subtotal: ₫0, Shipping: ₫0, but Total shows correct amount (e.g., ₫701,500). Data is not populated correctly from order API.
- **Expected**: Subtotal and Shipping should reflect actual values.
- **File**: `frontend/src/components/orders/OrderDetail.tsx`
- [ ] Fix order summary data mapping from API response

### Issue 7: Order addresses show "not available"
- **Location**: Frontend — `/orders/:id` Delivery Information
- **Severity**: P2
- **Description**: Both Shipping and Billing address fields display "not available" even for orders that were placed with valid addresses.
- **Expected**: Display the actual saved shipping/billing addresses from the order.
- **File**: `frontend/src/components/orders/OrderDetail.tsx`
- [ ] Fix address data mapping from order API response

---

## Test Results

### Manual Tests (11/11 executed)
| # | Test | Result |
|---|------|--------|
| M1 | Admin Payment Settings loads | ✅ PASS |
| M2 | Payment Methods tab (COD, Bank Transfer) | ✅ PASS |
| M3 | Payment Gateways tab (Stripe, PayPal) | ✅ PASS |
| M4 | Admin Order Detail payment info | ✅ PASS |
| M5 | Customer login | ✅ PASS |
| M6 | Add product to cart | ✅ PASS |
| M7 | Checkout step 2 renders | ✅ PASS (with error toasts) |
| M8 | Payment methods display | ✅ PASS |
| M9 | COD selection flow | ✅ PASS (amount mismatch) |
| M10 | Checkout success/failed pages | ⚠️ PARTIAL |
| M11 | Order payment info | ✅ PASS (subtotal=₫0) |

### Automated Tests (11/11 passed)
```
tests/payment-flows/admin-payment-settings.spec.ts  (4 passed)
tests/payment-flows/frontend-checkout-payment.spec.ts (7 passed)
```

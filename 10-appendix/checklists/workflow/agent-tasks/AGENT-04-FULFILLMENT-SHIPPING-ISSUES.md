# AGENT-04: Fulfillment & Shipping Flow Issues

> **Created**: 2026-03-22
> **Priority**: P0 + P1 + P2
> **Sprint**: Bug Fix Sprint
> **Source**: QA Testing (Section 9 — Fulfillment & Shipping Flows)
> **Environment**: https://frontend.tanhdev.com / https://admin.tanhdev.com

---

## P0 — Critical (Blocking)

### [ ] Task 1: Order Detail Missing Shipping Address & Billing Address

**File**: `frontend/src/app/orders/[id]/page.tsx` (or equivalent order detail component)
**Risk**: Customer cannot see delivery information for shipped orders — causes support tickets
**Problem**: On order detail page for shipped order #ORD-2602-000002, both "Delivery Information" and "Billing Information" show "Shipping address not available" / "Billing address not available" despite the order being in "Shipped" status.
**Fix**:
- Check the API response from the Order service `GetOrder` RPC — verify if `shipping_address` and `billing_address` fields are populated
- If API returns empty addresses, investigate the Order service `internal/biz/order` to ensure addresses are saved during checkout
- If API returns valid data but frontend doesn't render, fix the frontend component to correctly map address fields
**Validation**: View a shipped order detail and verify shipping/billing addresses display correctly

---

### [ ] Task 2: Order Detail Shipping Method Shows "Not specified"

**File**: `frontend/src/app/orders/[id]/page.tsx` + `order/internal/service/`
**Risk**: Shipped orders display no shipping method info — inconsistent with actual fulfillment state
**Problem**: "Shipping & Payment" section shows Shipping Method as "Not specified" for order #ORD-2602-000002 which is already "Shipped" and was placed via checkout where shipping methods exist
**Fix**:
- Check if `shipping_method` or `shipping_method_code` is stored in the order record during checkout
- If missing from order creation, add shipping method capture in the `ConfirmCheckout` saga (order service)
- If present in DB but not in API response, add it to the `GetOrder` response proto
**Validation**: Shipped orders should display the shipping method name (e.g., "siêu nhanh" or "Giao hàng miễn phí")

---

### [ ] Task 3: Order Summary Shows ₫0 for Subtotal and Shipping

**File**: `frontend/src/app/orders/[id]/page.tsx`
**Risk**: Customer sees misleading price breakdown — total shows ₫701,500 but subtotal and shipping both show ₫0
**Problem**: Order Summary sidebar shows Subtotal = ₫0, Shipping = ₫0, but Total = ₫701,500. The line items show ₫550,000 for the product, so the subtotal should reflect this.
**Fix**:
- Check the Order service API response for `subtotal`, `shipping_cost`, and `total` fields
- If the API returns correct values, fix frontend mapping to display them
- If the API returns zeros, check order creation logic to ensure line-item totals and shipping costs are persisted
**Validation**: Order detail summary should show correct subtotal, shipping, and total amounts

---

## P1 — High Priority

### [ ] Task 4: Checkout "Failed to start checkout" Error

**File**: `frontend/src/app/checkout/page.tsx` + `order/internal/service/`
**Risk**: Customers cannot complete purchases — directly impacts revenue
**Problem**: Checkout page shows repeated toast error "Failed to start checkout. Please try again." even though shipping/payment methods are visible. This may be caused by a backend `StartCheckout` or `ConfirmCheckout` RPC failure.
**Fix**:
- Add browser console error logging to identify the specific API call that fails
- Check the Order service logs for checkout initialization errors
- Verify the checkout session creation flow and any idempotency key issues
**Validation**: Customer should be able to proceed through checkout without "Failed to start checkout" errors

---

### [ ] Task 5: Stripe Configuration Warning on Checkout

**File**: `frontend/.env` or `frontend/src/app/checkout/page.tsx`
**Risk**: Payment flow partially broken — Stripe card payments will not work
**Problem**: Yellow warning banner on checkout: "Stripe is not configured. Please set NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY." This indicates missing environment variable in the frontend deployment.
**Fix**:
- Add `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` to the frontend environment configuration
- If Stripe is not intended for this environment, conditionally hide the warning and the credit card payment option
**Validation**: No Stripe warning should appear on checkout if Stripe is properly configured or disabled

---

### [ ] Task 6: Admin Shipping Settings — Missing Shipping Method Details

**File**: `admin/src/pages/settings/shipping/` (shipping settings page)
**Risk**: Admin cannot identify standard shipping method types — all methods show custom codes only
**Problem**: Shipping settings page has 3 methods (test_debug, free, flat) but none show standard industry names like "Standard", "Express", "Same-day". The method code names are internal and not user-friendly.
**Fix**:
- Review the Shipping service `ListShippingMethods` RPC response to ensure display names are user-friendly
- Consider adding a "Type" column (Standard/Express/Economy) to shipping method configuration
- Rename existing methods or add display name mapping
**Validation**: Shipping methods should have clear, customer-facing display names

---

## P2 — Nice to Have

### [ ] Task 7: Admin Shipping Settings — No Carriers Configured

**File**: `shipping/internal/biz/` + `admin/src/pages/settings/shipping/`
**Risk**: No carrier integration available — all shipping is manual without tracking
**Problem**: The "Carriers" tab in Shipping Settings shows empty table with no carriers configured. Columns exist (Name, Code, Status, Services, Features, Actions) but no data.
**Fix**:
- Seed at least one carrier configuration for the dev/staging environment
- Or document that carrier setup is a manual admin task and add a "Create Carrier" button if missing
**Validation**: At least one carrier should be configured in shipping settings

---

### [ ] Task 8: Admin Shipping Settings — Missing Zone/Region Labels

**File**: `admin/src/pages/settings/shipping/`
**Risk**: Admin cannot identify shipping zones by name — only rate table visible
**Problem**: Shipping settings page shows rate table but no "Zone" or "Region" labels for the rate entries. This makes it hard for admins to understand which geographic areas have what rates.
**Fix**:
- Add zone/region labels or a zone management sub-section
- Or add descriptive text to the rate table entries
**Validation**: Rate table should clearly indicate which zones/regions the rates apply to

---

### [ ] Task 9: Sidebar Settings Menu — Missing "Shipping" Link

**File**: `admin/src/components/layout/Sidebar.tsx` (or equivalent layout component)
**Risk**: Admin cannot navigate to shipping settings from sidebar — must use direct URL
**Problem**: While `/settings/shipping` page exists and loads correctly, the sidebar under "Settings" menu does not show "Shipping" as a sub-item. Admin must know the URL directly.
**Fix**:
- Add "Shipping" menu item under Settings in the sidebar navigation
- Ensure it links to `/settings/shipping`
**Validation**: Settings menu in sidebar should show "Shipping" as a clickable sub-item

---

### [ ] Task 10: No Fulfillment Data for E2E Testing

**File**: Test environment / seed data
**Risk**: Cannot test full pick-pack-ship lifecycle due to no fulfillment records
**Problem**: All fulfillment-related pages (Fulfillments, Picklists, Packages, Shipments) show "No data". This prevents end-to-end testing of the fulfillment workflow.
**Fix**:
- Create seed data or a test scenario that places an order and triggers fulfillment creation
- Or add a test order that transitions through the fulfillment lifecycle
**Validation**: At least one fulfillment record should be visible with associated picklist, package, and shipment records

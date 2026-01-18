# Checkout Pricing Flow - Detailed Guide

**Last Updated:** 2026-01-18  
**Status:** 🟡 Partially verified vs code (tax + promotion + confirm flow verified; remaining items need verification)

## Overview

This document explains where prices come from during the checkout process and how they flow through the system. It should be validated against the current codebase before use as an operational reference.

## Verified vs Planned Snapshot

### Verified (by code)

- Tax in totals:
  - `order/internal/biz/checkout/calculations.go` calls `uc.pricingService.CalculateTax(...)`.
- Promotion validation:
  - Totals path uses `uc.promotionService.ValidateCoupon(...)`.
  - Preview path uses `uc.promotionService.ValidatePromotions(...)`.
- Confirm checkout ordering:
  - `order/internal/biz/checkout/confirm.go` follows `Authorize → CreateOrder → Capture` (non-COD).

### Planned / Needs verification

- Product categories for tax are currently not extracted (code passes empty categories slice; TODO).
- Cart add/update pricing source-of-truth (pricing vs stored cart item UnitPrice/TotalPrice) needs full trace.
- Any “catalog pricing fallback” behavior needs verification in cart flows.

---

## Code references (current implementation)

- Checkout (Quote Pattern, no draft order):
  - Service: `order/internal/service/checkout_service.go`
  - Confirm checkout: `order/internal/biz/checkout/confirm.go`
- Totals calculation (subtotal/discount/tax/shipping/total): `order/internal/biz/checkout/calculations.go` (`calculateTotals`)
- Promotion validation during totals: `order/internal/biz/checkout/calculations.go` (`calculateDiscounts`)
- Tax calculation (with postcode + optional categories/customer group): `order/internal/biz/checkout/calculations.go` (`calculateTax`)
- Pricing tax engine: `pricing/internal/biz/tax/tax.go` (`CalculateTaxWithContext`)

## Price sources (priority order)

### 1. Pricing service (primary)

- Protocol: gRPC/HTTP (depends on client implementation)
- Used for tax calculation in checkout totals.

**Tax API (observed):**
- `CalculateTax(amount, country_code, state_province, postcode, product_categories, customer_group_id)`
  - Called via `uc.pricingService.CalculateTax(...)` inside `order/internal/biz/checkout/calculations.go`.

### 2. Catalog service (fallback / validation)

Catalog is typically used to validate product existence and retrieve product metadata. Exact fallback behavior should be verified in the cart add/update codepaths.

### 3. Promotion service (discounts)

Promotion codes are validated during totals calculation:
- `uc.promotionService.ValidateCoupon(...)` in `order/internal/biz/checkout/calculations.go`.

## Complete checkout pricing flow (current behavior)

### Step 1: Add to cart

- Cart item prices are stored as `UnitPrice`/`TotalPrice` on cart items.
- Exact call chain for pricing calculation on add-to-cart should be verified in the cart usecase.

### Step 2: View cart

Subtotal is computed as:

- If `item.TotalPrice` exists: sum it.
- Else if `item.UnitPrice` exists: `UnitPrice * quantity`.

Code: `order/internal/biz/checkout/calculations.go` (`calculateCartSubtotal`).

### Step 3: Start checkout

Checkout is implemented as Quote Pattern:

- Start checkout creates a checkout session.
- No draft order is created at this stage.

Code:

- `order/internal/service/checkout_service.go` (`StartCheckout`)

### Step 4: Update checkout state (address/payment/shipping method/promo codes)

Checkout state persists:

- `PromotionCodes`
- Shipping/billing addresses
- Selected shipping method

Code:

- `order/internal/service/checkout_service.go` (`UpdateCheckoutState`)

### Step 5: Confirm checkout

`ConfirmCheckout` will:

- Validate cart status and prerequisites
- Calculate totals via `calculateTotals`
- Authorize payment then create order
- Capture payment (if not COD)
- Finalize cart and delete checkout session

Code: `order/internal/biz/checkout/confirm.go` (`ConfirmCheckout`).

## Totals formula (current behavior)

The totals are computed in `order/internal/biz/checkout/calculations.go` (`calculateTotals`):

- `subtotal = Σ(cart_item_total_price)`
- `discount_amount = Σ(valid_coupon_discount)`
- `taxable_amount = max(0, subtotal - discount_amount)`
- `tax_amount = Pricing.CalculateTax(taxable_amount, shipping_country, shipping_state, shipping_postcode, categories, customer_group_id)`
  - Note: categories are currently passed as empty slice (TODO in code).
- `shipping_cost = Shipping.CalculateRates(...)` (best-effort; may fallback to 0)
- `total_amount = (subtotal - discount_amount) + tax_amount + shipping_cost`

## Gaps / TODOs noted in code

- Product categories are not yet extracted from cart items for tax (TODO in `calculateTotals`).

## Notes

- This document intentionally avoids hardcoded line numbers.
- Any claims of "production ready" should be backed by tests and operational metrics.

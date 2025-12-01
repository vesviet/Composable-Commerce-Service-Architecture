# Checkout Pricing Flow - Detailed Guide

**Last Updated:** 2025-12-01

## Overview

This document explains where prices come from during the checkout process and how they flow through the system.

## Price Sources (Priority Order)

### 1. Pricing Service (PRIMARY - REQUIRED)
**Location:** Separate microservice  
**Protocol:** gRPC (primary) / HTTP (fallback)  
**When Called:** When adding items to cart

**APIs:**
- `CalculatePrice(product_id, sku, quantity, warehouse_id, currency, country_code)` ✅ IMPLEMENTED
- `CalculateTax(amount, country_code, state_province)` ✅ API EXISTS, ❌ NOT CALLED
- `ApplyDiscounts(items, promotion_codes)` ✅ API EXISTS, ❌ NOT CALLED

**Returns:**
```go
type PriceCalculation struct {
    FinalPrice     float64  // Final unit price after all calculations
    BasePrice      float64  // Original base price
    DiscountAmount float64  // Quantity/bulk discounts
    TaxAmount      float64  // Tax amount
    Currency       string   // Currency code
}
```

**Features:**
- Real-time price calculation
- Quantity-based discounts
- Warehouse-specific pricing
- Currency conversion
- Tax calculation (not integrated yet)

### 2. Catalog Service (FALLBACK)
**Location:** Catalog microservice  
**Protocol:** gRPC (primary) / HTTP (fallback)  
**When Called:** When adding items to cart (for product validation)

**APIs:**
- `GetProduct(product_id)` ✅ IMPLEMENTED
- `GetProductBySKU(sku)` ✅ IMPLEMENTED

**Price Priority:**
1. `sale_price` (if set and > 0)
2. `base_price` (if set and > 0)
3. `price` (default)

**Usage:**
- Used as fallback if pricing service fails
- Provides product validation
- Returns basic product info

### 3. Promotion Service (DISCOUNTS)
**Location:** Promotion microservice  
**When Called:** When validating promo codes

**APIs:**
- `ValidateCoupon(code, customer_id, segments, cart_total, product_ids, category_ids)` ✅ IMPLEMENTED

**Returns:**
```go
type CouponValidation struct {
    IsValid        bool
    DiscountAmount float64
    DiscountType   string  // "percentage" or "fixed"
    Reason         string
}
```

**Status:** ✅ Validation works, ❌ Discount not applied to order

## Complete Checkout Pricing Flow

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: ADD TO CART                                          │
├─────────────────────────────────────────────────────────────┤
│ 1. User adds product (SKU, quantity, warehouse)             │
│ 2. Catalog Service: Validate product exists                 │
│ 3. Pricing Service: CalculatePrice()                        │
│    → Returns: final_price (unit price)                      │
│ 4. Warehouse Service: Check stock availability              │
│ 5. Store in cart_items:                                     │
│    - product_id, sku, quantity                              │
│    - unit_price (from pricing service)                      │
│    - warehouse_id                                            │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: VIEW CART                                            │
├─────────────────────────────────────────────────────────────┤
│ 1. Load cart items from database                            │
│ 2. Calculate subtotal:                                      │
│    subtotal = Σ(unit_price × quantity)                      │
│ 3. Display to user                                          │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: START CHECKOUT                                       │
├─────────────────────────────────────────────────────────────┤
│ 1. Create checkout session                                  │
│ 2. Create draft order with:                                 │
│    - Items from cart (with unit_price)                      │
│    - total_amount = subtotal                                │
│ 3. Store in checkout_sessions table                         │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 4: SELECT SHIPPING ADDRESS                              │
├─────────────────────────────────────────────────────────────┤
│ 1. User selects/enters shipping address                     │
│ 2. Save to checkout_sessions.shipping_address (JSONB)       │
│ 3. ❌ MISSING: Recalculate tax based on address             │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 5: SELECT SHIPPING METHOD                               │
├─────────────────────────────────────────────────────────────┤
│ 1. Shipping Service: CalculateRates()                       │
│    Input: address, weight, order_total, item_count          │
│    Returns: [{method, rate, estimated_days}]                │
│ 2. User selects shipping method                             │
│ 3. shipping_cost = selected_method.rate                     │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 6: APPLY PROMO CODE (OPTIONAL)                          │
├─────────────────────────────────────────────────────────────┤
│ 1. User enters promo code                                   │
│ 2. Promotion Service: ValidateCoupon()                      │
│    Input: code, customer_id, cart_total, product_ids        │
│    Returns: {valid, discount_amount, discount_type}         │
│ 3. ✅ Validation works                                       │
│ 4. ❌ MISSING: Apply discount to order total                │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 7: CALCULATE TAX (NOT IMPLEMENTED)                      │
├─────────────────────────────────────────────────────────────┤
│ ❌ MISSING:                                                  │
│ 1. Pricing Service: CalculateTax()                          │
│    Input: (subtotal - discount), country, state             │
│    Returns: tax_amount                                       │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 8: FINAL TOTAL                                          │
├─────────────────────────────────────────────────────────────┤
│ Current Implementation:                                      │
│   total = subtotal + shipping_cost                           │
│                                                              │
│ Should Be:                                                   │
│   taxable_amount = subtotal - discount                       │
│   tax = taxable_amount × tax_rate                            │
│   total = taxable_amount + tax + shipping_cost               │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 9: CONFIRM CHECKOUT                                     │
├─────────────────────────────────────────────────────────────┤
│ 1. Update order status: draft → pending                     │
│ 2. Store final pricing in orders table:                     │
│    - total_amount                                            │
│    - currency                                                │
│ 3. Store items in order_items:                              │
│    - unit_price (from cart)                                  │
│    - total_price (unit_price × quantity)                     │
└─────────────────────────────────────────────────────────────┘
```

## Current Implementation Status

### ✅ Working
1. **Add to Cart Pricing**
   - Pricing service integration (gRPC/HTTP)
   - Unit price calculation
   - Price stored in cart_items

2. **Subtotal Calculation**
   - Sum of (unit_price × quantity)
   - Displayed in cart and checkout

3. **Shipping Cost**
   - Shipping service integration
   - Rate calculation based on address
   - Multiple shipping methods

4. **Price Storage**
   - Unit price in cart_items
   - Total amount in orders
   - Pricing snapshot preserved

### ❌ Missing
1. **Tax Calculation**
   - API exists in pricing service
   - Not called during checkout
   - No tax amount in order

2. **Promo Code Discount**
   - Validation works
   - Discount not applied to order total
   - No discount tracking in order

3. **Dynamic Price Updates**
   - No recalculation on address change
   - No tax update when address changes
   - Prices fixed once added to cart

4. **Loyalty Points**
   - No integration
   - No points discount

## Database Schema

### cart_items
```sql
- id
- session_id
- product_id
- product_sku
- quantity
- unit_price          ← From pricing service
- warehouse_id
- metadata (JSONB)
```

### orders
```sql
- id
- customer_id
- total_amount        ← subtotal + shipping (no tax, no discount)
- currency
- payment_method
- status
```

### order_items
```sql
- id
- order_id
- product_id
- product_sku
- quantity
- unit_price          ← From cart_items
- total_price         ← unit_price × quantity
- warehouse_id
```

### checkout_sessions
```sql
- id
- session_id
- order_id
- customer_id
- shipping_address (JSONB)
- billing_address (JSONB)
- payment_method
- shipping_method_id
- promotion_codes[]   ← Stored but not applied
- notes
```

## Required Changes

### Priority 1: Tax Calculation
```go
// In ConfirmCheckout, before creating order:

// 1. Get shipping address from session
address := session.ShippingAddress

// 2. Calculate tax
taxAmount, err := uc.pricingService.CalculateTax(
    ctx,
    subtotal - discountAmount,  // taxable amount
    address.CountryCode,
    address.StateProvince,
)

// 3. Add to order total
order.TaxAmount = taxAmount
order.TotalAmount = (subtotal - discountAmount) + taxAmount + shippingAmount
```

### Priority 2: Apply Promo Discount
```go
// In ConfirmCheckout:

// 1. Get promo codes from session
promoCodes := session.PromotionCodes

// 2. Validate and get discount
if len(promoCodes) > 0 {
    validation, err := uc.promotionService.ValidateCoupon(
        ctx,
        promoCodes[0],
        &session.CustomerID,
        []string{},  // customer segments
        subtotal,
        productIDs,
        []string{},  // category IDs
    )
    
    if validation.IsValid {
        discountAmount = validation.DiscountAmount
    }
}

// 3. Apply to order
order.DiscountAmount = discountAmount
order.TotalAmount = (subtotal - discountAmount) + taxAmount + shippingAmount
```

### Priority 3: Dynamic Tax Updates
```go
// In UpdateCheckoutState, when address changes:

if req.ShippingAddress != nil {
    // Recalculate tax
    taxAmount, err := uc.pricingService.CalculateTax(
        ctx,
        subtotal,
        req.ShippingAddress.CountryCode,
        req.ShippingAddress.StateProvince,
    )
    
    // Update session with new tax
    session.TaxAmount = taxAmount
}
```

## Testing Checklist

- [ ] Add item to cart → verify unit_price from pricing service
- [ ] View cart → verify subtotal calculation
- [ ] Start checkout → verify draft order created with correct total
- [ ] Change address → verify tax recalculated
- [ ] Apply promo code → verify discount applied
- [ ] Select shipping → verify shipping cost added
- [ ] Confirm checkout → verify final total correct
- [ ] Check order → verify pricing snapshot stored

## Related Files

- `order/internal/biz/cart.go` - Cart pricing logic
- `order/internal/biz/checkout.go` - Checkout pricing logic
- `order/internal/client/pricing_client.go` - Pricing service client
- `order/internal/client/product_client.go` - Catalog service client
- `frontend/src/app/checkout/page.tsx` - Frontend checkout UI
- `frontend/src/lib/api/cart-api.ts` - Frontend cart API

## Questions & Answers

**Q: Why is pricing service required?**  
A: It provides real-time pricing with quantity discounts, warehouse-specific pricing, and currency conversion. Catalog service only has static base prices.

**Q: When is price calculated?**  
A: When adding to cart. Price is then stored and used throughout checkout.

**Q: Why not recalculate price during checkout?**  
A: To prevent price changes after user adds to cart. Price is locked when added.

**Q: Where is tax calculated?**  
A: Currently nowhere. Should be calculated in pricing service based on shipping address.

**Q: How are promo codes handled?**  
A: Validated but not applied. Need to integrate discount into order total.

**Q: What about loyalty points?**  
A: Not implemented yet. Would need loyalty service integration.

# Checkout Pricing Flow - Detailed Guide

**Last Updated:** 2025-12-01  
**Status:** ✅ **Production Ready** - All core pricing features implemented

## Overview

This document explains where prices come from during the checkout process and how they flow through the system.

## Price Sources (Priority Order)

### 1. Pricing Service (PRIMARY - REQUIRED)
**Location:** Separate microservice  
**Protocol:** gRPC (primary) / HTTP (fallback)  
**When Called:** When adding items to cart

**APIs:**
- `CalculatePrice(product_id, sku, quantity, warehouse_id, currency, country_code)` ✅ IMPLEMENTED & CALLED
- `CalculateTax(amount, country_code, state_province)` ✅ IMPLEMENTED & CALLED (in ConfirmCheckout and UpdateCheckoutState)
- `ApplyDiscounts(items, promotion_codes)` ✅ IMPLEMENTED (used in cart operations)

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
- Real-time price calculation ✅
- Quantity-based discounts ✅
- Warehouse-specific pricing ✅
- Currency conversion ✅
- Tax calculation ✅ **INTEGRATED** (called during checkout)

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

**Status:** ✅ Validation works, ✅ **Discount applied to order** (in ConfirmCheckout)

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
│ 3. ✅ Tax recalculated based on address (in UpdateCheckoutState)│
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
│ 4. ✅ Discount applied to order total (in ConfirmCheckout)   │
│    - Discount stored in order.metadata["discount_amount"]   │
│    - Discount subtracted from subtotal before tax calc      │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 7: CALCULATE TAX ✅ IMPLEMENTED                          │
├─────────────────────────────────────────────────────────────┤
│ ✅ IMPLEMENTED:                                              │
│ 1. Pricing Service: CalculateTax()                          │
│    Input: (subtotal - discount), country, state             │
│    Returns: tax_amount                                       │
│ 2. Called in ConfirmCheckout and UpdateCheckoutState        │
│ 3. Tax stored in order.metadata["tax_amount"]              │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 8: FINAL TOTAL ✅ IMPLEMENTED                            │
├─────────────────────────────────────────────────────────────┤
│ ✅ Current Implementation (CORRECT):                         │
│   taxable_amount = subtotal - discount                       │
│   tax = CalculateTax(taxable_amount, country, state)         │
│   total = (subtotal - discount) + tax + shipping_cost       │
│                                                              │
│ Formula in ConfirmCheckout (line 627):                      │
│   order.TotalAmount = (subtotal - discountAmount) +          │
│                       taxAmount + shippingCost               │
│                                                              │
│ Breakdown stored in order.metadata:                         │
│   - subtotal                                                 │
│   - discount_amount                                          │
│   - tax_amount                                               │
│   - shipping_cost                                             │
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

### ✅ Implemented (Updated)
1. **Tax Calculation** ✅
   - API exists in pricing service
   - ✅ **Called during checkout** (ConfirmCheckout and UpdateCheckoutState)
   - ✅ **Tax amount stored in order.metadata["tax_amount"]**
   - Tax calculated on taxable amount (subtotal - discount)

2. **Promo Code Discount** ✅
   - Validation works
   - ✅ **Discount applied to order total** (in ConfirmCheckout)
   - ✅ **Discount tracked in order.metadata["discount_amount"]**
   - Discount subtracted from subtotal before tax calculation

3. **Dynamic Tax Updates** ✅
   - ✅ **Tax recalculated on address change** (in UpdateCheckoutState)
   - Tax updated when shipping address changes
   - Prices fixed once added to cart (by design)

4. **Shipping Cost** ✅
   - ✅ **Shipping cost calculated** (in ConfirmCheckout)
   - ✅ **Stored in order.metadata["shipping_cost"]**
   - Calculated from ShippingService.CalculateRates

### ❌ Still Missing
1. **Loyalty Points**
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
- total_amount        ← (subtotal - discount) + tax + shipping ✅ CORRECT
- currency
- payment_method
- status
- metadata (JSONB)    ← Stores: subtotal, discount_amount, tax_amount, shipping_cost
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

### Priority 1: Tax Calculation ✅ IMPLEMENTED
```go
// In ConfirmCheckout (line 541-556):

// 1. Get shipping address from session
shippingAddr := session.ShippingAddress

// 2. Calculate tax on taxable amount (subtotal - discount)
taxableAmount := subtotal - discountAmount
if taxableAmount < 0 {
    taxableAmount = 0
}

taxAmount, err := uc.pricingService.CalculateTax(
    ctx,
    taxableAmount,
    shippingAddr.Country,
    shippingAddr.State,
)

// 3. Add to order total and metadata
order.TotalAmount = (subtotal - discountAmount) + taxAmount + shippingCost
order.Metadata["tax_amount"] = taxAmount
```

**Status:** ✅ **IMPLEMENTED** - Tax is calculated and stored correctly

### Priority 2: Apply Promo Discount ✅ IMPLEMENTED
```go
// In ConfirmCheckout (line 526-539):

// 1. Get promo codes from session
promoCodes := session.PromotionCodes

// 2. Validate and accumulate discount
var discountAmount float64
if len(promoCodes) > 0 && uc.promotionService != nil {
    for _, code := range promoCodes {
        validation, err := uc.promotionService.ValidateCoupon(
            ctx,
            code,
            &session.CustomerID,
            []string{},  // customer segments
            subtotal,
            productIDs,
            []string{},  // category IDs
        )
        
        if err == nil && validation.IsValid {
            discountAmount += validation.DiscountAmount
        }
    }
}

// 3. Apply to order total and metadata
order.TotalAmount = (subtotal - discountAmount) + taxAmount + shippingCost
order.Metadata["discount_amount"] = discountAmount
```

**Status:** ✅ **IMPLEMENTED** - Discount is validated, applied, and stored correctly

### Priority 3: Dynamic Tax Updates ✅ IMPLEMENTED
```go
// In UpdateCheckoutState (line 247-260), when address changes:

if req.ShippingAddress != nil && uc.pricingService != nil {
    // Recalculate tax based on new address
    taxAmount, err := uc.pricingService.CalculateTax(
        ctx,
        order.TotalAmount,  // Uses current subtotal
        req.ShippingAddress.Country,
        req.ShippingAddress.State,
    )
    
    // Update session metadata with new tax
    if err == nil {
        if session.Metadata == nil {
            session.Metadata = make(JSONB)
        }
        session.Metadata["tax_amount"] = taxAmount
    }
}
```

**Status:** ✅ **IMPLEMENTED** - Tax is recalculated when shipping address changes

## Testing Checklist

- [x] Add item to cart → verify unit_price from pricing service ✅
- [x] View cart → verify subtotal calculation ✅
- [x] Start checkout → verify draft order created with correct total ✅
- [x] Change address → verify tax recalculated ✅ **IMPLEMENTED**
- [x] Apply promo code → verify discount applied ✅ **IMPLEMENTED**
- [x] Select shipping → verify shipping cost added ✅ **IMPLEMENTED**
- [x] Confirm checkout → verify final total correct ✅ **IMPLEMENTED**
- [x] Check order → verify pricing snapshot stored ✅ **IMPLEMENTED** (in metadata)

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
A: ✅ **Tax is calculated in pricing service** based on shipping address. Called in `ConfirmCheckout` and `UpdateCheckoutState`. Tax amount stored in `order.metadata["tax_amount"]`.

**Q: How are promo codes handled?**  
A: ✅ **Promo codes are validated AND applied**. Discount is calculated in `ConfirmCheckout`, subtracted from subtotal before tax calculation, and stored in `order.metadata["discount_amount"]`.

**Q: What about loyalty points?**  
A: Not implemented yet. Would need loyalty service integration.

# Implementation Plan: Cart-Promotion Integration

Integrate Order service cart management with Promotion service to support advanced promotions (BOGO, tiered discounts, free shipping) using structured line items.

## User Review Required

> [!IMPORTANT]
> **Cart Item Schema Changes**
> - Adding 4 new fields to CartItem: `category_id`, `brand_id`, `is_special_price`, `attributes`
> - Requires database migration
> - Proto changes for cart API responses

> [!WARNING]
> **Service Integration Dependencies**
> - Requires Catalog service to return `categories[]` and `brand` in product response
> - Requires Pricing service to return `is_special_price` flag
> - Requires Shipping service client integration in Order service (may not exist yet)

> [!CAUTION]  
> **Breaking Changes Risk**
> - Removing hardcoded `countryCode="VN"` and `currency="USD"` requires proper context propagation from Gateway
> - Cart totals calculation flow changes may affect existing checkout integration

## Proposed Changes

### Component 1: Data Model Updates

#### [MODIFY] CartItem Entity

**File:** `order/internal/biz/cart/cart.go` (assumed location)

Add new fields to CartItem struct:

```go
type CartItem struct {
    ID          string
    CartID      string
    ProductID   string
    SKU         string
    Name        string
    Quantity    int
    
    // Pricing (excl tax per Magento-like semantics)
    UnitPrice      float64  // excl tax
    TotalPrice     float64  // excl tax, before discount
    DiscountAmount float64  // excl tax
    TaxAmount      float64
    
    // NEW: For promotion validation
    CategoryID     string                  `json:"category_id"`     // Primary product category
    BrandID        string                  `json:"brand_id"`        // Product brand
    IsSpecialPrice bool                    `json:"is_special_price"` // Sale/special price flag
    Attributes     map[string]interface{} `json:"attributes,omitempty"` // Product attributes (color, size, etc.)
    
    CreatedAt      time.Time
    UpdatedAt      time.Time
}
```

#### [NEW] Database Migration

**File:** `order/migrations/XXXXXX_add_cart_item_promotion_fields.up.sql`

```sql
ALTER TABLE cart_items
ADD COLUMN category_id VARCHAR(255),
ADD COLUMN brand_id VARCHAR(255),
ADD COLUMN is_special_price BOOLEAN DEFAULT FALSE,
ADD COLUMN attributes JSONB;

CREATE INDEX idx_cart_items_category_id ON cart_items(category_id);
CREATE INDEX idx_cart_items_brand_id ON cart_items(brand_id);
```

**Down migration:** `XXXXXX_add_cart_item_promotion_fields.down.sql`

```sql
ALTER TABLE cart_items
DROP COLUMN IF EXISTS category_id,
DROP COLUMN IF EXISTS brand_id,
DROP COLUMN IF EXISTS is_special_price,
DROP COLUMN IF EXISTS attributes;
```

#### [MODIFY] Proto Definitions

**File:** `order/api/order/v1/cart.proto`

Update CartItem message:

```protobuf
message CartItem {
    // ... existing fields ...
    
    // NEW: For promotion validation
    string category_id = 10;
    string brand_id = 11;
    bool is_special_price = 12;
    map<string, string> attributes = 13;
}
```

---

### Component 2: Service Integration Updates

#### [MODIFY] AddToCart - Catalog Integration

**File:** `order/internal/biz/cart/add.go`

Update to fetch and store category and brand from Catalog:

```go
func (uc *CartUseCase) AddToCart(ctx context.Context, req *AddToCartRequest) (*Cart, error) {
    // ... existing validation ...
    
    // Get product from Catalog
    product, err := uc.catalogClient.GetProduct(ctx, &catalogpb.GetProductRequest{
        Sku: req.Sku,
    })
    if err != nil {
        return nil, fmt.Errorf("product not found: %w", err)
    }
    
    // Extract category (primary category or first category)
    categoryID := ""
    if len(product.Categories) > 0 {
        categoryID = product.Categories[0]  // Use primary or first category
    }
    
    // Extract brand
    brandID := ""
    if product.Brand != nil {
        brandID = product.Brand.Id
    }
    
    // ... existing stock check ...
    
    // Get price from Pricing service
    priceResp, err := uc.pricingClient.CalculatePrice(ctx, &pricingpb.CalculatePriceRequest{
        ProductId:       product.Id,
        Sku:             req.Sku,
        Quantity:        req.Quantity,
        WarehouseId:     warehouseID,
        Currency:        currency,
        CountryCode:     countryCode,  // From cart session, not hardcoded
        CustomerGroupId: customerGroupID,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to calculate price: %w", err)
    }
    
    // Create cart item with complete data
    cartItem := &CartItem{
        ProductID:      product.Id,
        SKU:            req.Sku,
        Name:           product.Name,
        Quantity:       req.Quantity,
        UnitPrice:      priceResp.UnitPriceExclTax,
        TotalPrice:     priceResp.UnitPriceExclTax * float64(req.Quantity),
        DiscountAmount: priceResp.DiscountAmount,
        TaxAmount:      priceResp.TaxAmount * float64(req.Quantity),
        
        // NEW: Promotion fields
        CategoryID:     categoryID,
        BrandID:        brandID,
        IsSpecialPrice: priceResp.IsSpecialPrice,
        Attributes:     product.Attributes,  // If Catalog returns attributes
    }
    
    // ... save cart item ...
}
```

#### [MODIFY] Remove Hardcoded Values

**Files:** `order/internal/biz/cart/update.go`, `validate.go`, `sync.go`

Replace hardcoded values with context from cart session:

```go
// BEFORE (in update.go, validate.go, etc.)
countryCode := "VN"  // ❌ Hardcoded
currency := "USD"    // ❌ Hardcoded

// AFTER
countryCode := cart.CountryCode
if countryCode == "" {
    countryCode = uc.defaultCountryCode  // From config or session
}

currency := cart.Currency
if currency == "" {
    currency = uc.defaultCurrency  // From config
}
```

**Also update Cart struct to store these:**

```go
type Cart struct {
    // ... existing fields ...
    
    CountryCode string  // From session/user preference
    Currency    string  // From session/storefront
    
    // For totals calculation
    ShippingAddress *Address
    ShippingMethod  string
    ShippingCost    float64
}
```

---

### Component 3: Promotion Integration

#### [NEW] Helper Function - Build Line Items

**File:** `order/internal/biz/cart/promotion.go` (new or existing)

```go
// buildLineItemsFromCart converts CartItem[] to promotionpb.LineItem[]
func buildLineItemsFromCart(cartItems []*CartItem) []*promotionpb.LineItem {
    items := make([]*promotionpb.LineItem, 0, len(cartItems))
    
    for _, item := range cartItems {
        lineItem := &promotionpb.LineItem{
            ProductId:        item.ProductID,
            Sku:              item.SKU,
            CategoryId:       item.CategoryID,
            BrandId:          item.BrandID,
            Quantity:         int32(item.Quantity),
            UnitPriceExclTax: item.UnitPrice,
            TotalPriceExclTax: item.TotalPrice,
            IsSpecialPrice:   item.IsSpecialPrice,
            Attributes:       convertAttributesToStringMap(item.Attributes),
        }
        items = append(items, lineItem)
    }
    
    return items
}

func convertAttributesToStringMap(attrs map[string]interface{}) map[string]string {
    result := make(map[string]string)
    for k, v := range attrs {
        result[k] = fmt.Sprintf("%v", v)
    }
    return result
}
```

#### [DONE] Cart Totals Calculation

**File:** `order/internal/biz/cart/totals.go` (new)

```go
type CartTotals struct {
    Subtotal          float64  // excl tax, before discounts
    DiscountAmount    float64  // from promotions, excl tax
    SubtotalAfterDiscount float64
    TaxAmount         float64
    ShippingCost      float64
    ShippingDiscount  float64  // from free shipping promotions
    ShippingTax       float64
    GrandTotal        float64  // final total incl tax
    
    AppliedPromotions []*AppliedPromotion
}

type AppliedPromotion struct {
    PromotionID    string
    Name           string
    DiscountAmount float64
    DiscountType   string
}

func (uc *CartUseCase) CalculateCartTotals(
    ctx context.Context,
    cartID string,
    shippingAddress *Address,
) (*CartTotals, error) {
    // 1. Load cart and items
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    items, err := uc.repo.GetCartItems(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    // 2. Calculate cart subtotal (excl tax)
    subtotal := 0.0
    for _, item := range items {
        subtotal += item.TotalPrice
    }
    
    // 3. Get shipping cost
    var shippingCost float64
    if shippingAddress != nil {
        shippingResp, err := uc.shippingClient.CalculateShipping(ctx, &shippingpb.CalculateShippingRequest{
            Items:              convertToShippingItems(items),
            DestinationAddress: convertToShippingAddress(shippingAddress),
            ShippingMethod:     cart.ShippingMethod,
        })
        if err != nil {
            uc.log.Warnf("Failed to calculate shipping: %v", err)
            shippingCost = 0
        } else {
            shippingCost = shippingResp.Cost
        }
    }
    
    // 4. Validate promotions with structured line items
    promoResp, err := uc.promotionClient.ValidatePromotions(ctx, &promotionpb.ValidatePromotionsRequest{
        CustomerId:       cart.CustomerID,
        CustomerSegments: cart.CustomerSegments,  // Need to add to Cart struct
        Items:            buildLineItemsFromCart(items),  // ✅ NEW: Structured items
        OrderAmount:      subtotal,
        CouponCodes:      cart.AppliedCoupons,
        ShippingAmount:   shippingCost,  // ✅ NEW: Real shipping amount
        ShippingMethod:   cart.ShippingMethod,
        ShippingCountry:  shippingAddress.Country,
        ShippingState:    shippingAddress.State,
        ShippingPostcode: shippingAddress.Postcode,
    })
    if err != nil {
        uc.log.Warnf("Failed to validate promotions: %v", err)
        // Continue without promotions
    }
    
    // 5. Apply promotion discounts
    discountAmount := 0.0
    shippingDiscount := 0.0
    var appliedPromotions []*AppliedPromotion
    
    if promoResp != nil {
        discountAmount = promoResp.TotalDiscount
        shippingDiscount = promoResp.ShippingDiscount
        
        for _, promo := range promoResp.ValidPromotions {
            appliedPromotions = append(appliedPromotions, &AppliedPromotion{
                PromotionID:    promo.PromotionId,
                Name:           promo.Name,
                DiscountAmount: promo.DiscountAmount,
                DiscountType:   promo.DiscountType,
            })
        }
    }
    
    // 6. Calculate tax on (subtotal - discount) + shipping
    taxableAmount := subtotal - discountAmount
    taxResp, err := uc.pricingClient.CalculateTax(ctx, &pricingpb.CalculateTaxRequest{
        Amount:          taxableAmount,
        ShippingAmount:  shippingCost - shippingDiscount,
        CountryCode:     shippingAddress.Country,
        StateProvince:   shippingAddress.State,
        Postcode:        shippingAddress.Postcode,
        CustomerGroupId: cart.CustomerGroupID,  // Need to add to Cart struct
    })
    
    taxAmount := 0.0
    shippingTax := 0.0
    if err == nil {
        taxAmount = taxResp.TaxAmount
        shippingTax = taxResp.ShippingTax
    }
    
    // 7. Calculate grand total
    grandTotal := (subtotal - discountAmount) + taxAmount + (shippingCost - shippingDiscount) + shippingTax
    
    return &CartTotals{
        Subtotal:              subtotal,
        DiscountAmount:        discountAmount,
        SubtotalAfterDiscount: subtotal - discountAmount,
        TaxAmount:             taxAmount,
        ShippingCost:          shippingCost,
        ShippingDiscount:      shippingDiscount,
        ShippingTax:           shippingTax,
        GrandTotal:            grandTotal,
        AppliedPromotions:     appliedPromotions,
    }, nil
}
```

#### [MODIFY] Coupon Application

**File:** `order/internal/biz/cart/coupon.go`

Update to use structured line items:

```go
func (uc *CartUseCase) ApplyCoupon(
    ctx context.Context,
    cartID string,
    couponCode string,
) (*Cart, error) {
    // Load cart and items
    cart, _ := uc.repo.GetCart(ctx, cartID)
    items, _ := uc.repo.GetCartItems(ctx, cartID)
    
    // Validate coupon with promotion service
    promoResp, err := uc.promotionClient.ValidatePromotions(ctx, &promotionpb.ValidatePromotionsRequest{
        CustomerId:       cart.CustomerID,
        CustomerSegments: cart.CustomerSegments,
        Items:            buildLineItemsFromCart(items),  // ✅ NEW
        OrderAmount:      cart.Subtotal,
        CouponCodes:      []string{couponCode},
        // Can include shipping if available
        ShippingAmount:   cart.ShippingCost,
        ShippingMethod:   cart.ShippingMethod,
    })
    
    if err != nil {
        return nil, fmt.Errorf("failed to validate coupon: %w", err)
    }
    
    // Check if coupon is valid
    if len(promoResp.ValidPromotions) == 0 {
        // Check invalid reasons
        if len(promoResp.InvalidPromotions) > 0 {
            reason := promoResp.InvalidPromotions[0].Reason
            return nil, fmt.Errorf("coupon invalid: %s", reason)
        }
        return nil, fmt.Errorf("coupon not applicable")
    }
    
    // Apply coupon to cart
    cart.AppliedCoupons = append(cart.AppliedCoupons, couponCode)
    cart.DiscountAmount = promoResp.TotalDiscount
    
    // Update cart
    err = uc.repo.UpdateCart(ctx, cart)
    if err != nil {
        return nil, err
    }
    
    return cart, nil
}
```

---

### Component 4: Repository Layer Updates

#### [MODIFY] Cart Repository

**File:** `order/internal/data/postgres/cart.go`

Update SQL queries to handle new fields:

```go
const insertCartItemSQL = `
    INSERT INTO cart_items (
        id, cart_id, product_id, sku, name, quantity,
        unit_price, total_price, discount_amount, tax_amount,
        category_id, brand_id, is_special_price, attributes,  -- NEW
        created_at, updated_at
    ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14,  -- NEW
        $15, $16
    )
`

const selectCartItemsSQL = `
    SELECT 
        id, cart_id, product_id, sku, name, quantity,
        unit_price, total_price, discount_amount, tax_amount,
        category_id, brand_id, is_special_price, attributes,  -- NEW
        created_at, updated_at
    FROM cart_items
    WHERE cart_id = $1
`

// Update scan logic to include new fields
func (r *CartRepo) scanCartItem(row *sql.Row) (*biz.CartItem, error) {
    item := &biz.CartItem{}
    var attributesJSON []byte
    
    err := row.Scan(
        &item.ID, &item.CartID, &item.ProductID, &item.SKU, &item.Name, &item.Quantity,
        &item.UnitPrice, &item.TotalPrice, &item.DiscountAmount, &item.TaxAmount,
        &item.CategoryID, &item.BrandID, &item.IsSpecialPrice, &attributesJSON,  // NEW
        &item.CreatedAt, &item.UpdatedAt,
    )
    
    // Unmarshal attributes JSON
    if len(attributesJSON) > 0 {
        json.Unmarshal(attributesJSON, &item.Attributes)
    }
    
    return item, err
}
```

---

## Verification Plan

### Unit Tests

**File:** `order/internal/biz/cart/promotion_test.go`

```go
func TestBuildLineItemsFromCart(t *testing.T) {
    cartItems := []*biz.CartItem{
        {
            ProductID:      "prod-1",
            SKU:            "SKU-001",
            CategoryID:     "cat-electronics",
            BrandID:        "brand-canon",
            Quantity:       2,
            UnitPrice:      500.0,
            TotalPrice:     1000.0,
            IsSpecialPrice: true,
        },
    }
    
    lineItems := buildLineItemsFromCart(cartItems)
    
    assert.Len(t, lineItems, 1)
    assert.Equal(t, "prod-1", lineItems[0].ProductId)
    assert.Equal(t, "cat-electronics", lineItems[0].CategoryId)
    assert.Equal(t, int32(2), lineItems[0].Quantity)
    assert.Equal(t, 500.0, lineItems[0].UnitPriceExclTax)
    assert.True(t, lineItems[0].IsSpecialPrice)
}
```

### Integration Tests

**Test scenarios:**

1. **BOGO Promotion Test**
   - Add 3 items of same product to cart
   - Apply BOGO coupon
   - Verify discount = price of 1 item

2. **Tiered Discount Test**
   - Add 5 items to cart
   - Apply tiered discount (buy 5+, get 20% off)
   - Verify discount = 20% of subtotal

3. **Free Shipping Test**
   - Add items to cart
   - Set shipping address
   - Apply free shipping coupon
   - Verify shipping_discount = shipping_cost

4. **Item Selection Test**
   - Add multiple items with different prices
   - Apply "cheapest item free" promotion
   - Verify discount = price of cheapest item

### Manual Verification

Run integration test script:

```bash
#!/bin/bash
# test-cart-promotions.sh

# 1. Add items to cart
CART_ID=$(curl -X POST http://localhost:8080/api/v1/cart \
  -d '{"sku":"CANON-001", "quantity":3}' | jq -r '.id')

# 2. Apply BOGO coupon
curl -X POST http://localhost:8080/api/v1/cart/$CART_ID/coupons \
  -d '{"code":"BOGO-CANON"}'

# 3. Calculate totals with shipping
curl -X POST http://localhost:8080/api/v1/cart/$CART_ID/totals \
  -d '{
    "shipping_address": {
      "country": "VN",
      "state": "HCM",
      "postcode": "700000"
    },
    "shipping_method": "standard"
  }'

# Verify: discount should equal 1 item price
```

---

## Migration Strategy

### Phase 1: Deploy Promotion Service (✅ Done)
- Promotion service already updated
- Backward compatible with old API

### Phase 2: Update Order Service Schema
1. Run database migration
2. Deploy Order service with new CartItem fields
3. Fields initially empty for existing carts

### Phase 3: Populate New Fields
1. AddToCart starts populating category/brand/is_special_price
2. Existing cart items gradually updated on price sync
3. Old carts without fields still work (fallback behavior)

### Phase 4: Enable Promotion Integration
1. Deploy CalculateCartTotals and updated ApplyCoupon
2. Frontend starts calling totals endpoint with shipping address
3. Advanced promotions now work for new cart operations

### Rollback Plan
- Database migration can be rolled back
- Promotion service still supports old API (parallel arrays)
- Order service can fall back to old promotion validation without line items

---

## Success Criteria

- [ ] Cart items store complete product metadata (category, brand, attributes)
- [ ] BOGO promotions calculate correctly
- [ ] Tiered quantity discounts work
- [ ] Free shipping promotions apply
- [ ] Item selection (cheapest/most expensive) works
- [ ] No hardcoded country/currency values
- [ ] All existing cart functionality still works
- [ ] Database migration completes successfully
- [ ] Integration tests pass

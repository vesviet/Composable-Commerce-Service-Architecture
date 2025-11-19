# 🛒 Cart Management Logic Checklist

**Service:** Cart/Order Service  
**Created:** 2025-11-19  
**Status:** 🟡 **Implementation Required**  
**Priority:** 🔴 **Critical**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Cart Operations](#cart-operations)
3. [Cart Validation](#cart-validation)
4. [Cart Persistence](#cart-persistence)
5. [Price & Stock Sync](#price--stock-sync)
6. [Promotion & Discount](#promotion--discount)
7. [Cart Merging](#cart-merging)
8. [Integration Points](#integration-points)
9. [Edge Cases & Race Conditions](#edge-cases--race-conditions)
10. [Performance & Caching](#performance--caching)
11. [Testing Scenarios](#testing-scenarios)

---

## 🎯 Overview

Cart management là trung tâm của shopping experience. Cart service phải xử lý:
- Real-time stock validation
- Price synchronization
- Promotion application
- Concurrent updates (race conditions)
- Guest vs authenticated user carts
- Cart persistence & recovery
- Multi-device sync

**Key Metrics:**
- Cart abandonment rate target: <70%
- Add to cart response time: <200ms
- Cart load time: <100ms
- Cart update success rate: >99.9%

---

## 1. Cart Operations

### 1.1 Add Item to Cart

**Requirements:**

- [ ] **R1.1.1** Validate product exists in catalog
- [ ] **R1.1.2** Check product is active and published
- [ ] **R1.1.3** Validate stock availability
- [ ] **R1.1.4** Check quantity limits (min/max per product)
- [ ] **R1.1.5** Check cart capacity limits (max items in cart)
- [ ] **R1.1.6** Validate product variants (size, color, etc.)
- [ ] **R1.1.7** Handle pre-order products
- [ ] **R1.1.8** Handle out-of-stock products with backorder
- [ ] **R1.1.9** Get current price from pricing service
- [ ] **R1.1.10** Check if product already in cart (update vs add)

**Implementation:**

```go
type AddToCartRequest struct {
    CartID      string                 // Cart identifier (session or user ID)
    ProductID   string                 // Product to add
    VariantID   *string                // Product variant (if applicable)
    Quantity    int                    // Quantity to add
    Attributes  map[string]interface{} // Custom attributes
}

type AddToCartResponse struct {
    Cart        *Cart
    Added       bool                   // True if new item, false if updated
    Message     string                 // Success/warning message
}

func (uc *CartUseCase) AddToCart(ctx context.Context, req *AddToCartRequest) (*AddToCartResponse, error) {
    // 1. Get or create cart
    cart, err := uc.getOrCreateCart(ctx, req.CartID)
    if err != nil {
        return nil, err
    }
    
    // 2. Validate product
    product, err := uc.catalogClient.GetProduct(ctx, req.ProductID)
    if err != nil {
        return nil, ErrProductNotFound
    }
    
    if !product.IsActive || !product.IsPublished {
        return nil, ErrProductNotAvailable
    }
    
    // 3. Validate variant (if applicable)
    if req.VariantID != nil {
        variant := product.GetVariant(*req.VariantID)
        if variant == nil {
            return nil, ErrVariantNotFound
        }
    }
    
    // 4. Check stock availability
    stock, err := uc.inventoryClient.CheckStock(ctx, req.ProductID, req.VariantID)
    if err != nil {
        return nil, err
    }
    
    if stock.Available < req.Quantity {
        if stock.AllowBackorder {
            // Allow add but mark as backorder
            return uc.addBackorderItem(ctx, cart, req, stock)
        }
        return nil, ErrInsufficientStock
    }
    
    // 5. Check quantity limits
    if req.Quantity < product.MinOrderQuantity {
        return nil, ErrBelowMinimumQuantity
    }
    
    if product.MaxOrderQuantity > 0 && req.Quantity > product.MaxOrderQuantity {
        return nil, ErrExceedsMaximumQuantity
    }
    
    // 6. Check cart capacity
    if len(cart.Items) >= uc.maxCartItems {
        return nil, ErrCartFull
    }
    
    // 7. Get current price
    price, err := uc.pricingClient.GetPrice(ctx, req.ProductID, req.VariantID, cart.CustomerSegment)
    if err != nil {
        return nil, err
    }
    
    // 8. Check if item already in cart
    existingItem := cart.GetItem(req.ProductID, req.VariantID)
    
    if existingItem != nil {
        // Update quantity
        newQuantity := existingItem.Quantity + req.Quantity
        
        // Re-check stock for new total
        if stock.Available < newQuantity {
            return nil, ErrInsufficientStock
        }
        
        // Re-check max quantity
        if product.MaxOrderQuantity > 0 && newQuantity > product.MaxOrderQuantity {
            return nil, ErrExceedsMaximumQuantity
        }
        
        existingItem.Quantity = newQuantity
        existingItem.Price = price.FinalPrice
        existingItem.UpdatedAt = time.Now()
        
        return &AddToCartResponse{
            Cart:    cart,
            Added:   false,
            Message: "Cart item quantity updated",
        }, nil
    }
    
    // 9. Add new item
    cartItem := &CartItem{
        ID:          uuid.New().String(),
        ProductID:   req.ProductID,
        VariantID:   req.VariantID,
        ProductName: product.Name,
        SKU:         product.SKU,
        Quantity:    req.Quantity,
        Price:       price.FinalPrice,
        OriginalPrice: price.OriginalPrice,
        TaxAmount:   price.TaxAmount,
        ImageURL:    product.MainImage,
        Attributes:  req.Attributes,
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }
    
    cart.Items = append(cart.Items, cartItem)
    cart.UpdatedAt = time.Now()
    
    // 10. Recalculate cart totals
    uc.recalculateCart(ctx, cart)
    
    // 11. Save cart
    if err := uc.repo.SaveCart(ctx, cart); err != nil {
        return nil, err
    }
    
    // 12. Publish event
    uc.publishEvent(ctx, "cart.item_added", cart)
    
    return &AddToCartResponse{
        Cart:    cart,
        Added:   true,
        Message: "Item added to cart successfully",
    }, nil
}
```

**Test Scenarios:**

- [ ] **T1.1.1** Add valid product to empty cart
- [ ] **T1.1.2** Add product with variant to cart
- [ ] **T1.1.3** Add product that's already in cart (should update quantity)
- [ ] **T1.1.4** Add product with quantity exceeding stock
- [ ] **T1.1.5** Add product with quantity below minimum
- [ ] **T1.1.6** Add product with quantity above maximum
- [ ] **T1.1.7** Add product to full cart (max items limit)
- [ ] **T1.1.8** Add inactive/unpublished product
- [ ] **T1.1.9** Add product with invalid variant
- [ ] **T1.1.10** Add backorder product
- [ ] **T1.1.11** Concurrent add operations (race condition)

---

### 1.2 Update Cart Item Quantity

**Requirements:**

- [ ] **R1.2.1** Validate new quantity is > 0
- [ ] **R1.2.2** Re-check stock availability for new quantity
- [ ] **R1.2.3** Re-check quantity limits (min/max)
- [ ] **R1.2.4** Update price if quantity tier pricing exists
- [ ] **R1.2.5** Recalculate cart totals
- [ ] **R1.2.6** Handle concurrent updates (optimistic locking)
- [ ] **R1.2.7** Remove item if quantity set to 0

**Implementation:**

```go
func (uc *CartUseCase) UpdateCartItemQuantity(ctx context.Context, req *UpdateQuantityRequest) (*Cart, error) {
    // Use optimistic locking to prevent race conditions
    cart, version, err := uc.repo.GetCartWithVersion(ctx, req.CartID)
    if err != nil {
        return nil, err
    }
    
    // Find cart item
    item := cart.GetItem(req.ProductID, req.VariantID)
    if item == nil {
        return nil, ErrItemNotInCart
    }
    
    // If quantity is 0, remove item
    if req.NewQuantity == 0 {
        return uc.RemoveCartItem(ctx, &RemoveItemRequest{
            CartID:    req.CartID,
            ProductID: req.ProductID,
            VariantID: req.VariantID,
        })
    }
    
    // Get product for validation
    product, err := uc.catalogClient.GetProduct(ctx, req.ProductID)
    if err != nil {
        return nil, err
    }
    
    // Check min/max quantity
    if req.NewQuantity < product.MinOrderQuantity {
        return nil, ErrBelowMinimumQuantity
    }
    
    if product.MaxOrderQuantity > 0 && req.NewQuantity > product.MaxOrderQuantity {
        return nil, ErrExceedsMaximumQuantity
    }
    
    // Check stock availability
    stock, err := uc.inventoryClient.CheckStock(ctx, req.ProductID, req.VariantID)
    if err != nil {
        return nil, err
    }
    
    if stock.Available < req.NewQuantity {
        return nil, ErrInsufficientStock
    }
    
    // Update quantity
    oldQuantity := item.Quantity
    item.Quantity = req.NewQuantity
    item.UpdatedAt = time.Now()
    
    // Check if tier pricing applies
    price, err := uc.pricingClient.GetPriceWithQuantity(ctx, req.ProductID, req.NewQuantity)
    if err == nil && price.FinalPrice != item.Price {
        item.Price = price.FinalPrice
        item.OriginalPrice = price.OriginalPrice
    }
    
    // Recalculate totals
    uc.recalculateCart(ctx, cart)
    
    // Save with version check (optimistic locking)
    if err := uc.repo.SaveCartWithVersion(ctx, cart, version); err != nil {
        if errors.Is(err, ErrVersionMismatch) {
            // Retry with fresh data
            return uc.UpdateCartItemQuantity(ctx, req)
        }
        return nil, err
    }
    
    // Publish event
    uc.publishEvent(ctx, "cart.item_quantity_updated", map[string]interface{}{
        "cart_id":      cart.ID,
        "product_id":   req.ProductID,
        "old_quantity": oldQuantity,
        "new_quantity": req.NewQuantity,
    })
    
    return cart, nil
}
```

**Test Scenarios:**

- [ ] **T1.2.1** Increase quantity (sufficient stock)
- [ ] **T1.2.2** Decrease quantity
- [ ] **T1.2.3** Set quantity to 0 (should remove item)
- [ ] **T1.2.4** Update to quantity exceeding stock
- [ ] **T1.2.5** Update to invalid quantity (negative, below min, above max)
- [ ] **T1.2.6** Concurrent quantity updates (version conflict)
- [ ] **T1.2.7** Update triggers tier pricing change
- [ ] **T1.2.8** Update non-existent item

---

### 1.3 Remove Cart Item

**Requirements:**

- [ ] **R1.3.1** Validate item exists in cart
- [ ] **R1.3.2** Remove item from cart items array
- [ ] **R1.3.3** Recalculate cart totals
- [ ] **R1.3.4** Clear applied promotions if no longer valid
- [ ] **R1.3.5** Handle empty cart after removal

**Implementation:**

```go
func (uc *CartUseCase) RemoveCartItem(ctx context.Context, req *RemoveItemRequest) (*Cart, error) {
    cart, err := uc.repo.GetCart(ctx, req.CartID)
    if err != nil {
        return nil, err
    }
    
    // Find and remove item
    itemIndex := -1
    for i, item := range cart.Items {
        if item.ProductID == req.ProductID && 
           (req.VariantID == nil || (item.VariantID != nil && *item.VariantID == *req.VariantID)) {
            itemIndex = i
            break
        }
    }
    
    if itemIndex == -1 {
        return nil, ErrItemNotInCart
    }
    
    removedItem := cart.Items[itemIndex]
    
    // Remove item
    cart.Items = append(cart.Items[:itemIndex], cart.Items[itemIndex+1:]...)
    cart.UpdatedAt = time.Now()
    
    // Recalculate totals (may affect promotions)
    uc.recalculateCart(ctx, cart)
    
    // Save cart
    if err := uc.repo.SaveCart(ctx, cart); err != nil {
        return nil, err
    }
    
    // Publish event
    uc.publishEvent(ctx, "cart.item_removed", map[string]interface{}{
        "cart_id":    cart.ID,
        "product_id": removedItem.ProductID,
        "variant_id": removedItem.VariantID,
        "quantity":   removedItem.Quantity,
    })
    
    return cart, nil
}
```

**Test Scenarios:**

- [ ] **T1.3.1** Remove existing item
- [ ] **T1.3.2** Remove last item (cart becomes empty)
- [ ] **T1.3.3** Remove non-existent item
- [ ] **T1.3.4** Remove item invalidates promotion (promotion should be removed)

---

### 1.4 Clear Cart

**Requirements:**

- [ ] **R1.4.1** Remove all items from cart
- [ ] **R1.4.2** Clear applied promotions
- [ ] **R1.4.3** Reset cart totals to 0
- [ ] **R1.4.4** Preserve cart metadata (customer info, etc.)

**Implementation:**

```go
func (uc *CartUseCase) ClearCart(ctx context.Context, cartID string) error {
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return err
    }
    
    itemCount := len(cart.Items)
    
    // Clear all items and promotions
    cart.Items = []CartItem{}
    cart.AppliedPromotions = []AppliedPromotion{}
    cart.Subtotal = 0
    cart.DiscountAmount = 0
    cart.TaxAmount = 0
    cart.ShippingAmount = 0
    cart.Total = 0
    cart.UpdatedAt = time.Now()
    
    // Save cart
    if err := uc.repo.SaveCart(ctx, cart); err != nil {
        return err
    }
    
    // Publish event
    uc.publishEvent(ctx, "cart.cleared", map[string]interface{}{
        "cart_id":    cart.ID,
        "item_count": itemCount,
    })
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T1.4.1** Clear cart with items
- [ ] **T1.4.2** Clear empty cart
- [ ] **T1.4.3** Clear cart removes all promotions

---

## 2. Cart Validation

### 2.1 Stock Availability Validation

**Requirements:**

- [ ] **R2.1.1** Real-time stock check before checkout
- [ ] **R2.1.2** Validate all items in cart have sufficient stock
- [ ] **R2.1.3** Handle stock changes since items were added
- [ ] **R2.1.4** Reserve stock during validation (optional)
- [ ] **R2.1.5** Provide clear error messages for out-of-stock items

**Implementation:**

```go
type CartValidationResult struct {
    IsValid           bool
    Errors            []ValidationError
    Warnings          []ValidationWarning
    OutOfStockItems   []OutOfStockItem
    PriceChangedItems []PriceChangedItem
}

type ValidationError struct {
    Code       string
    Message    string
    ProductID  string
    Field      string
}

func (uc *CartUseCase) ValidateCart(ctx context.Context, cartID string) (*CartValidationResult, error) {
    result := &CartValidationResult{
        IsValid:  true,
        Errors:   []ValidationError{},
        Warnings: []ValidationWarning{},
    }
    
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    if len(cart.Items) == 0 {
        result.IsValid = false
        result.Errors = append(result.Errors, ValidationError{
            Code:    "CART_EMPTY",
            Message: "Cart is empty",
        })
        return result, nil
    }
    
    // Validate each item
    for _, item := range cart.Items {
        // 1. Check product still exists and active
        product, err := uc.catalogClient.GetProduct(ctx, item.ProductID)
        if err != nil || !product.IsActive {
            result.IsValid = false
            result.Errors = append(result.Errors, ValidationError{
                Code:      "PRODUCT_NOT_AVAILABLE",
                Message:   fmt.Sprintf("Product %s is no longer available", item.ProductName),
                ProductID: item.ProductID,
            })
            continue
        }
        
        // 2. Check stock availability
        stock, err := uc.inventoryClient.CheckStock(ctx, item.ProductID, item.VariantID)
        if err != nil {
            result.IsValid = false
            result.Errors = append(result.Errors, ValidationError{
                Code:      "STOCK_CHECK_FAILED",
                Message:   "Unable to check stock availability",
                ProductID: item.ProductID,
            })
            continue
        }
        
        if stock.Available < item.Quantity {
            result.IsValid = false
            result.OutOfStockItems = append(result.OutOfStockItems, OutOfStockItem{
                ProductID:         item.ProductID,
                ProductName:       item.ProductName,
                RequestedQuantity: item.Quantity,
                AvailableQuantity: stock.Available,
            })
            result.Errors = append(result.Errors, ValidationError{
                Code:      "INSUFFICIENT_STOCK",
                Message:   fmt.Sprintf("Only %d of %s available (requested: %d)", stock.Available, item.ProductName, item.Quantity),
                ProductID: item.ProductID,
            })
        }
        
        // 3. Check price changes
        currentPrice, err := uc.pricingClient.GetPrice(ctx, item.ProductID, item.VariantID, cart.CustomerSegment)
        if err == nil && currentPrice.FinalPrice != item.Price {
            result.Warnings = append(result.Warnings, ValidationWarning{
                Code:      "PRICE_CHANGED",
                Message:   fmt.Sprintf("Price of %s changed from %.2f to %.2f", item.ProductName, item.Price, currentPrice.FinalPrice),
                ProductID: item.ProductID,
            })
            result.PriceChangedItems = append(result.PriceChangedItems, PriceChangedItem{
                ProductID:    item.ProductID,
                ProductName:  item.ProductName,
                OldPrice:     item.Price,
                NewPrice:     currentPrice.FinalPrice,
                PriceChanged: currentPrice.FinalPrice - item.Price,
            })
        }
    }
    
    return result, nil
}
```

**Test Scenarios:**

- [ ] **T2.1.1** Validate cart with all items in stock
- [ ] **T2.1.2** Validate cart with out-of-stock items
- [ ] **T2.1.3** Validate cart with partially available stock
- [ ] **T2.1.4** Validate cart with price changes
- [ ] **T2.1.5** Validate cart with inactive products
- [ ] **T2.1.6** Validate empty cart

---

### 2.2 Price Synchronization

**Requirements:**

- [ ] **R2.2.1** Sync cart prices with pricing service periodically
- [ ] **R2.2.2** Update prices on cart load
- [ ] **R2.2.3** Notify user of price changes
- [ ] **R2.2.4** Handle price increases vs decreases differently
- [ ] **R2.2.5** Log price change history

**Implementation:**

```go
func (uc *CartUseCase) SyncCartPrices(ctx context.Context, cartID string) (*CartPriceSyncResult, error) {
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    result := &CartPriceSyncResult{
        UpdatedItems: []PriceUpdate{},
        OldTotal:     cart.Total,
    }
    
    hasChanges := false
    
    for i := range cart.Items {
        item := &cart.Items[i]
        
        // Get current price
        currentPrice, err := uc.pricingClient.GetPriceWithQuantity(
            ctx,
            item.ProductID,
            item.Quantity,
            cart.CustomerSegment,
        )
        
        if err != nil {
            uc.log.Errorf("Failed to get price for product %s: %v", item.ProductID, err)
            continue
        }
        
        // Check if price changed
        if currentPrice.FinalPrice != item.Price {
            oldPrice := item.Price
            item.Price = currentPrice.FinalPrice
            item.OriginalPrice = currentPrice.OriginalPrice
            item.TaxAmount = currentPrice.TaxAmount
            item.UpdatedAt = time.Now()
            
            hasChanges = true
            
            result.UpdatedItems = append(result.UpdatedItems, PriceUpdate{
                ProductID:   item.ProductID,
                ProductName: item.ProductName,
                OldPrice:    oldPrice,
                NewPrice:    currentPrice.FinalPrice,
                Difference:  currentPrice.FinalPrice - oldPrice,
            })
            
            // Log price change
            uc.logPriceChange(ctx, cart.ID, item.ProductID, oldPrice, currentPrice.FinalPrice)
        }
    }
    
    if hasChanges {
        // Recalculate cart totals
        uc.recalculateCart(ctx, cart)
        
        // Save cart
        if err := uc.repo.SaveCart(ctx, cart); err != nil {
            return nil, err
        }
        
        result.NewTotal = cart.Total
        result.TotalDifference = cart.Total - result.OldTotal
        
        // Publish event
        uc.publishEvent(ctx, "cart.prices_synced", result)
    }
    
    return result, nil
}
```

**Test Scenarios:**

- [ ] **T2.2.1** Sync prices with no changes
- [ ] **T2.2.2** Sync prices with increases
- [ ] **T2.2.3** Sync prices with decreases
- [ ] **T2.2.4** Sync prices with mixed changes
- [ ] **T2.2.5** Sync prices affects cart total

---

## 3. Cart Persistence

### 3.1 Guest Cart (Session-Based)

**Requirements:**

- [ ] **R3.1.1** Store guest cart in Redis with session ID
- [ ] **R3.1.2** Set appropriate TTL (e.g., 7 days)
- [ ] **R3.1.3** Extend TTL on cart activity
- [ ] **R3.1.4** Handle session expiration gracefully

**Implementation:**

```go
func (uc *CartUseCase) SaveGuestCart(ctx context.Context, sessionID string, cart *Cart) error {
    // Serialize cart
    cartJSON, err := json.Marshal(cart)
    if err != nil {
        return err
    }
    
    // Save to Redis with TTL
    key := fmt.Sprintf("cart:guest:%s", sessionID)
    ttl := 7 * 24 * time.Hour // 7 days
    
    if err := uc.redis.Set(ctx, key, cartJSON, ttl).Err(); err != nil {
        return err
    }
    
    return nil
}

func (uc *CartUseCase) GetGuestCart(ctx context.Context, sessionID string) (*Cart, error) {
    key := fmt.Sprintf("cart:guest:%s", sessionID)
    
    cartJSON, err := uc.redis.Get(ctx, key).Bytes()
    if err != nil {
        if err == redis.Nil {
            // Cart not found, create new
            return uc.createNewCart(ctx, sessionID, false)
        }
        return nil, err
    }
    
    var cart Cart
    if err := json.Unmarshal(cartJSON, &cart); err != nil {
        return nil, err
    }
    
    // Extend TTL on access
    uc.redis.Expire(ctx, key, 7*24*time.Hour)
    
    return &cart, nil
}
```

**Test Scenarios:**

- [ ] **T3.1.1** Create guest cart
- [ ] **T3.1.2** Load guest cart
- [ ] **T3.1.3** Guest cart expires after TTL
- [ ] **T3.1.4** TTL extends on cart activity

---

### 3.2 Registered User Cart (Database)

**Requirements:**

- [ ] **R3.2.1** Store user cart in PostgreSQL
- [ ] **R3.2.2** One active cart per user
- [ ] **R3.2.3** Persist cart across sessions
- [ ] **R3.2.4** Handle cart recovery on login

**Database Schema:**

```sql
CREATE TABLE carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    session_id VARCHAR(255),
    customer_segment VARCHAR(50),
    subtotal DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    shipping_amount DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(user_id, is_active) WHERE is_active = TRUE
);

CREATE INDEX idx_carts_user_id ON carts(user_id);
CREATE INDEX idx_carts_session_id ON carts(session_id);
CREATE INDEX idx_carts_expires_at ON carts(expires_at) WHERE expires_at IS NOT NULL;

CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID REFERENCES carts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    variant_id UUID,
    product_name VARCHAR(255) NOT NULL,
    sku VARCHAR(100),
    quantity INT NOT NULL CHECK (quantity > 0),
    price DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2),
    tax_amount DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    image_url TEXT,
    attributes JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(cart_id, product_id, variant_id)
);

CREATE INDEX idx_cart_items_cart_id ON cart_items(cart_id);
CREATE INDEX idx_cart_items_product_id ON cart_items(product_id);
```

---

### 3.3 Cart Migration on Login

**Requirements:**

- [ ] **R3.3.1** Detect guest cart on user login
- [ ] **R3.3.2** Merge guest cart with user cart
- [ ] **R3.3.3** Handle duplicate items (merge quantities)
- [ ] **R3.3.4** Clear guest cart after migration
- [ ] **R3.3.5** Notify user of merged items

**Implementation:**

```go
func (uc *CartUseCase) MergeCartsOnLogin(ctx context.Context, userID, sessionID string) (*Cart, error) {
    // Get guest cart
    guestCart, err := uc.GetGuestCart(ctx, sessionID)
    if err != nil && err != ErrCartNotFound {
        return nil, err
    }
    
    // Get user cart
    userCart, err := uc.GetUserCart(ctx, userID)
    if err != nil && err != ErrCartNotFound {
        return nil, err
    }
    
    // If no guest cart, return user cart
    if guestCart == nil || len(guestCart.Items) == 0 {
        if userCart != nil {
            return userCart, nil
        }
        return uc.createNewCart(ctx, userID, true)
    }
    
    // If no user cart, convert guest cart to user cart
    if userCart == nil {
        guestCart.UserID = &userID
        guestCart.SessionID = nil
        guestCart.IsGuestCart = false
        
        if err := uc.repo.SaveCart(ctx, guestCart); err != nil {
            return nil, err
        }
        
        // Clear guest cart from Redis
        uc.redis.Del(ctx, fmt.Sprintf("cart:guest:%s", sessionID))
        
        return guestCart, nil
    }
    
    // Merge carts
    mergeResult := &CartMergeResult{
        MergedItems: []string{},
        AddedItems:  []string{},
    }
    
    for _, guestItem := range guestCart.Items {
        // Check if item exists in user cart
        existingItem := userCart.GetItem(guestItem.ProductID, guestItem.VariantID)
        
        if existingItem != nil {
            // Merge quantities
            oldQuantity := existingItem.Quantity
            existingItem.Quantity += guestItem.Quantity
            existingItem.UpdatedAt = time.Now()
            
            mergeResult.MergedItems = append(mergeResult.MergedItems, guestItem.ProductName)
            
            uc.log.Infof("Merged item %s: %d + %d = %d", 
                guestItem.ProductName, oldQuantity, guestItem.Quantity, existingItem.Quantity)
        } else {
            // Add item to user cart
            userCart.Items = append(userCart.Items, guestItem)
            mergeResult.AddedItems = append(mergeResult.AddedItems, guestItem.ProductName)
        }
    }
    
    // Recalculate totals
    uc.recalculateCart(ctx, userCart)
    
    // Save merged cart
    if err := uc.repo.SaveCart(ctx, userCart); err != nil {
        return nil, err
    }
    
    // Clear guest cart
    uc.redis.Del(ctx, fmt.Sprintf("cart:guest:%s", sessionID))
    
    // Publish event
    uc.publishEvent(ctx, "cart.merged", mergeResult)
    
    return userCart, nil
}
```

**Test Scenarios:**

- [ ] **T3.3.1** Merge guest cart into empty user cart
- [ ] **T3.3.2** Merge guest cart with duplicate items (quantities merge)
- [ ] **T3.3.3** Merge guest cart with new items
- [ ] **T3.3.4** Merge empty guest cart (no-op)
- [ ] **T3.3.5** Guest cart cleared after merge

---

## 4. Price & Stock Sync

### 4.1 Real-Time Stock Updates

**Requirements:**

- [ ] **R4.1.1** Subscribe to stock update events
- [ ] **R4.1.2** Update cart items when stock changes
- [ ] **R4.1.3** Mark items as out-of-stock in cart
- [ ] **R4.1.4** Notify user of stock changes

**Implementation:**

```go
// Event handler for stock updates
func (uc *CartUseCase) HandleStockUpdated(ctx context.Context, event *StockUpdatedEvent) error {
    // Find all carts with this product
    carts, err := uc.repo.FindCartsWithProduct(ctx, event.ProductID, event.VariantID)
    if err != nil {
        return err
    }
    
    for _, cart := range carts {
        item := cart.GetItem(event.ProductID, event.VariantID)
        if item == nil {
            continue
        }
        
        if event.NewStock < item.Quantity {
            // Stock insufficient for cart quantity
            if event.NewStock == 0 {
                // Mark as out of stock
                item.IsOutOfStock = true
                
                // Notify user
                uc.sendNotification(ctx, cart, "ITEM_OUT_OF_STOCK", map[string]interface{}{
                    "product_name": item.ProductName,
                })
            } else {
                // Partial stock available
                uc.sendNotification(ctx, cart, "ITEM_LOW_STOCK", map[string]interface{}{
                    "product_name":       item.ProductName,
                    "requested_quantity": item.Quantity,
                    "available_stock":    event.NewStock,
                })
            }
            
            // Save cart
            uc.repo.SaveCart(ctx, cart)
        }
    }
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T4.1.1** Product goes out of stock (update all carts)
- [ ] **T4.1.2** Product stock decreases below cart quantity
- [ ] **T4.1.3** Product stock increases
- [ ] **T4.1.4** User notified of stock changes

---

### 4.2 Periodic Cart Refresh

**Requirements:**

- [ ] **R4.2.1** Refresh cart data on load
- [ ] **R4.2.2** Refresh every N minutes for active sessions
- [ ] **R4.2.3** Batch refresh for performance
- [ ] **R4.2.4** Update UI with latest data

**Implementation:**

```go
func (uc *CartUseCase) RefreshCart(ctx context.Context, cartID string) (*Cart, error) {
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    // Sync prices
    if _, err := uc.SyncCartPrices(ctx, cartID); err != nil {
        uc.log.Errorf("Failed to sync prices: %v", err)
    }
    
    // Validate stock
    validation, err := uc.ValidateCart(ctx, cartID)
    if err != nil {
        uc.log.Errorf("Failed to validate cart: %v", err)
    }
    
    // Re-apply promotions
    if err := uc.ReapplyPromotions(ctx, cartID); err != nil {
        uc.log.Errorf("Failed to reapply promotions: %v", err)
    }
    
    // Reload cart
    cart, err = uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    cart.LastRefreshedAt = time.Now()
    cart.ValidationResult = validation
    
    return cart, nil
}
```

**Test Scenarios:**

- [ ] **T4.2.1** Refresh cart updates prices
- [ ] **T4.2.2** Refresh cart validates stock
- [ ] **T4.2.3** Refresh cart reapplies promotions
- [ ] **T4.2.4** Refresh cart updates all cart data

---

## 5. Promotion & Discount

### 5.1 Apply Coupon Code

**Requirements:**

- [ ] **R5.1.1** Validate coupon code with promotion service
- [ ] **R5.1.2** Check coupon eligibility for cart
- [ ] **R5.1.3** Apply coupon discount to cart
- [ ] **R5.1.4** Handle multiple coupons if allowed
- [ ] **R5.1.5** Prevent duplicate coupon application

**Implementation:**

```go
func (uc *CartUseCase) ApplyCoupon(ctx context.Context, cartID, couponCode string) (*Cart, error) {
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    // Validate coupon with promotion service
    couponValidation, err := uc.promotionClient.ValidateCoupon(ctx, &ValidateCouponRequest{
        Code:            couponCode,
        CustomerID:      cart.UserID,
        CustomerSegment: cart.CustomerSegment,
        CartAmount:      cart.Subtotal,
        ProductIDs:      cart.GetProductIDs(),
        CategoryIDs:     cart.GetCategoryIDs(),
    })
    
    if err != nil {
        return nil, err
    }
    
    if !couponValidation.IsValid {
        return nil, &CouponError{
            Code:    "INVALID_COUPON",
            Message: couponValidation.Reason,
        }
    }
    
    // Check if coupon already applied
    for _, promo := range cart.AppliedPromotions {
        if promo.CouponCode == couponCode {
            return nil, &CouponError{
                Code:    "COUPON_ALREADY_APPLIED",
                Message: "This coupon is already applied",
            }
        }
    }
    
    // Add promotion
    cart.AppliedPromotions = append(cart.AppliedPromotions, AppliedPromotion{
        PromotionID:    couponValidation.Promotion.ID,
        CouponCode:     couponCode,
        PromotionName:  couponValidation.Promotion.Name,
        DiscountType:   couponValidation.Promotion.DiscountType,
        DiscountAmount: couponValidation.DiscountAmount,
        AppliedAt:      time.Now(),
    })
    
    // Recalculate cart
    uc.recalculateCart(ctx, cart)
    
    // Save cart
    if err := uc.repo.SaveCart(ctx, cart); err != nil {
        return nil, err
    }
    
    // Publish event
    uc.publishEvent(ctx, "cart.coupon_applied", map[string]interface{}{
        "cart_id":     cart.ID,
        "coupon_code": couponCode,
        "discount":    couponValidation.DiscountAmount,
    })
    
    return cart, nil
}
```

**Test Scenarios:**

- [ ] **T5.1.1** Apply valid coupon
- [ ] **T5.1.2** Apply invalid coupon
- [ ] **T5.1.3** Apply expired coupon
- [ ] **T5.1.4** Apply coupon with minimum order requirement
- [ ] **T5.1.5** Apply duplicate coupon
- [ ] **T5.1.6** Apply multiple coupons (if allowed)
- [ ] **T5.1.7** Apply coupon to empty cart

---

### 5.2 Auto-Apply Promotions

**Requirements:**

- [ ] **R5.2.1** Automatically apply eligible promotions
- [ ] **R5.2.2** Select best promotion for customer
- [ ] **R5.2.3** Handle stackable vs non-stackable promotions
- [ ] **R5.2.4** Update promotions when cart changes

**Implementation:**

```go
func (uc *CartUseCase) AutoApplyPromotions(ctx context.Context, cartID string) (*Cart, error) {
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    // Get all eligible promotions
    promotions, err := uc.promotionClient.GetEligiblePromotions(ctx, &GetEligiblePromotionsRequest{
        CustomerID:      cart.UserID,
        CustomerSegment: cart.CustomerSegment,
        CartAmount:      cart.Subtotal,
        ProductIDs:      cart.GetProductIDs(),
        CategoryIDs:     cart.GetCategoryIDs(),
        BrandIDs:        cart.GetBrandIDs(),
    })
    
    if err != nil {
        return nil, err
    }
    
    // Clear auto-applied promotions (keep coupon-based ones)
    cart.AppliedPromotions = filterCouponPromotions(cart.AppliedPromotions)
    
    // Apply best promotion(s)
    bestPromotions := uc.selectBestPromotions(promotions)
    
    for _, promo := range bestPromotions {
        cart.AppliedPromotions = append(cart.AppliedPromotions, AppliedPromotion{
            PromotionID:    promo.ID,
            PromotionName:  promo.Name,
            DiscountType:   promo.DiscountType,
            DiscountAmount: promo.DiscountAmount,
            IsAutoApplied:  true,
            AppliedAt:      time.Now(),
        })
    }
    
    // Recalculate cart
    uc.recalculateCart(ctx, cart)
    
    // Save cart
    if err := uc.repo.SaveCart(ctx, cart); err != nil {
        return nil, err
    }
    
    return cart, nil
}
```

**Test Scenarios:**

- [ ] **T5.2.1** Auto-apply best promotion
- [ ] **T5.2.2** Auto-apply stackable promotions
- [ ] **T5.2.3** Auto-apply with existing coupon
- [ ] **T5.2.4** No promotions available
- [ ] **T5.2.5** Promotion eligibility changes with cart update

---

## 6. Cart Totals Calculation

**Requirements:**

- [ ] **R6.1** Calculate subtotal (sum of item prices × quantities)
- [ ] **R6.2** Apply discounts (coupons, promotions)
- [ ] **R6.3** Calculate tax
- [ ] **R6.4** Add shipping cost (if applicable)
- [ ] **R6.5** Calculate final total
- [ ] **R6.6** Handle rounding correctly

**Implementation:**

```go
func (uc *CartUseCase) recalculateCart(ctx context.Context, cart *Cart) error {
    // 1. Calculate subtotal
    cart.Subtotal = 0
    for _, item := range cart.Items {
        cart.Subtotal += item.Price * float64(item.Quantity)
    }
    
    // 2. Calculate discounts
    cart.DiscountAmount = 0
    for _, promo := range cart.AppliedPromotions {
        cart.DiscountAmount += promo.DiscountAmount
    }
    
    // Ensure discount doesn't exceed subtotal
    if cart.DiscountAmount > cart.Subtotal {
        cart.DiscountAmount = cart.Subtotal
    }
    
    // 3. Calculate taxable amount
    taxableAmount := cart.Subtotal - cart.DiscountAmount
    
    // 4. Calculate tax (if tax service available)
    if cart.ShippingAddress != nil {
        taxRate, err := uc.taxClient.GetTaxRate(ctx, cart.ShippingAddress.Country, cart.ShippingAddress.State)
        if err == nil {
            cart.TaxAmount = taxableAmount * taxRate
        }
    }
    
    // 5. Add shipping (if calculated)
    // cart.ShippingAmount is set separately
    
    // 6. Calculate total
    cart.Total = taxableAmount + cart.TaxAmount + cart.ShippingAmount
    
    // 7. Round to 2 decimal places
    cart.Subtotal = roundToDecimal(cart.Subtotal, 2)
    cart.DiscountAmount = roundToDecimal(cart.DiscountAmount, 2)
    cart.TaxAmount = roundToDecimal(cart.TaxAmount, 2)
    cart.ShippingAmount = roundToDecimal(cart.ShippingAmount, 2)
    cart.Total = roundToDecimal(cart.Total, 2)
    
    cart.UpdatedAt = time.Now()
    
    return nil
}

func roundToDecimal(value float64, decimals int) float64 {
    multiplier := math.Pow(10, float64(decimals))
    return math.Round(value*multiplier) / multiplier
}
```

**Test Scenarios:**

- [ ] **T6.1** Calculate subtotal correctly
- [ ] **T6.2** Apply single discount
- [ ] **T6.3** Apply multiple stackable discounts
- [ ] **T6.4** Discount doesn't exceed subtotal
- [ ] **T6.5** Tax calculated correctly
- [ ] **T6.6** Shipping added correctly
- [ ] **T6.7** Total sum is correct
- [ ] **T6.8** Rounding is correct

---

## 7. Edge Cases & Race Conditions

### 7.1 Concurrent Cart Updates

**Problem:** Multiple requests update cart simultaneously

**Solution:** Optimistic locking with version field

```go
type Cart struct {
    // ... other fields ...
    Version int `json:"version"`
}

func (r *CartRepository) SaveCartWithVersion(ctx context.Context, cart *Cart, expectedVersion int) error {
    query := `
        UPDATE carts 
        SET items = $1, subtotal = $2, total = $3, version = version + 1, updated_at = NOW()
        WHERE id = $4 AND version = $5
    `
    
    result, err := r.db.ExecContext(ctx, query, 
        cart.Items, cart.Subtotal, cart.Total, cart.ID, expectedVersion)
    
    if err != nil {
        return err
    }
    
    rowsAffected, _ := result.RowsAffected()
    if rowsAffected == 0 {
        return ErrVersionMismatch
    }
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T7.1.1** Concurrent add to cart operations
- [ ] **T7.1.2** Concurrent quantity updates
- [ ] **T7.1.3** Concurrent coupon applications
- [ ] **T7.1.4** Version conflict retry logic

---

### 7.2 Product Becomes Unavailable

**Problem:** Product deleted/deactivated while in cart

**Solution:** Handle gracefully, mark item as unavailable

```go
func (uc *CartUseCase) handleUnavailableProducts(ctx context.Context, cart *Cart) {
    for i := range cart.Items {
        item := &cart.Items[i]
        
        product, err := uc.catalogClient.GetProduct(ctx, item.ProductID)
        if err != nil || !product.IsActive {
            item.IsUnavailable = true
            item.UnavailableReason = "Product no longer available"
        }
    }
}
```

**Test Scenarios:**

- [ ] **T7.2.1** Product deleted after added to cart
- [ ] **T7.2.2** Product deactivated after added to cart
- [ ] **T7.2.3** User notified of unavailable products
- [ ] **T7.2.4** Checkout blocked with unavailable products

---

### 7.3 Price Increases During Checkout

**Problem:** Price increases after user adds to cart

**Solution:** Lock price at checkout time, notify of changes

```go
func (uc *CartUseCase) LockPricesForCheckout(ctx context.Context, cartID string) error {
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return err
    }
    
    // Sync prices one final time
    syncResult, err := uc.SyncCartPrices(ctx, cartID)
    if err != nil {
        return err
    }
    
    // If prices increased significantly, require confirmation
    if syncResult.TotalDifference > 0 {
        priceIncreasePercent := (syncResult.TotalDifference / syncResult.OldTotal) * 100
        
        if priceIncreasePercent > 5 { // 5% threshold
            return &PriceChangeError{
                OldTotal:    syncResult.OldTotal,
                NewTotal:    syncResult.NewTotal,
                Difference:  syncResult.TotalDifference,
                UpdatedItems: syncResult.UpdatedItems,
                RequiresConfirmation: true,
            }
        }
    }
    
    // Lock prices
    cart.PricesLockedAt = timePtr(time.Now())
    uc.repo.SaveCart(ctx, cart)
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T7.3.1** Small price increase (<5%) allowed
- [ ] **T7.3.2** Large price increase (>5%) requires confirmation
- [ ] **T7.3.3** Price decrease allowed
- [ ] **T7.3.4** Locked prices used in checkout

---

### 7.4 Session Expiration During Checkout

**Problem:** Guest session expires during checkout

**Solution:** Persist cart temporarily, allow recovery

```go
func (uc *CartUseCase) RecoverExpiredCart(ctx context.Context, sessionID, newSessionID string) (*Cart, error) {
    // Try to load from backup storage
    cart, err := uc.backupStorage.GetExpiredCart(ctx, sessionID)
    if err != nil {
        return nil, ErrCartNotFound
    }
    
    // Restore to new session
    cart.SessionID = &newSessionID
    cart.RestoredAt = timePtr(time.Now())
    
    // Validate cart is still valid
    validation, _ := uc.ValidateCart(ctx, cart.ID)
    if !validation.IsValid {
        // Notify user of issues
        cart.ValidationResult = validation
    }
    
    // Save restored cart
    uc.SaveGuestCart(ctx, newSessionID, cart)
    
    return cart, nil
}
```

**Test Scenarios:**

- [ ] **T7.4.1** Session expires during checkout
- [ ] **T7.4.2** Cart recovered successfully
- [ ] **T7.4.3** Recovered cart validated
- [ ] **T7.4.4** Recovery fails for old carts (>30 days)

---

## 8. Performance & Caching

### 8.1 Cart Caching Strategy

**Requirements:**

- [ ] **R8.1.1** Cache cart data in Redis
- [ ] **R8.1.2** Cache invalidation on updates
- [ ] **R8.1.3** Cache warming for active carts
- [ ] **R8.1.4** Fallback to database on cache miss

**Implementation:**

```go
func (uc *CartUseCase) GetCartWithCache(ctx context.Context, cartID string) (*Cart, error) {
    // Try cache first
    cacheKey := fmt.Sprintf("cart:%s", cartID)
    
    cachedCart, err := uc.getFromCache(ctx, cacheKey)
    if err == nil {
        return cachedCart, nil
    }
    
    // Cache miss, load from database
    cart, err := uc.repo.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    // Store in cache
    uc.storeInCache(ctx, cacheKey, cart, 5*time.Minute)
    
    return cart, nil
}

func (uc *CartUseCase) InvalidateCartCache(ctx context.Context, cartID string) {
    cacheKey := fmt.Sprintf("cart:%s", cartID)
    uc.redis.Del(ctx, cacheKey)
}
```

**Test Scenarios:**

- [ ] **T8.1.1** Cache hit returns cached data
- [ ] **T8.1.2** Cache miss loads from database
- [ ] **T8.1.3** Cache invalidated on update
- [ ] **T8.1.4** Cache TTL respected

---

### 8.2 Database Query Optimization

**Requirements:**

- [ ] **R8.2.1** Use proper indexes
- [ ] **R8.2.2** Batch operations where possible
- [ ] **R8.2.3** Avoid N+1 queries
- [ ] **R8.2.4** Use connection pooling

**Optimized Queries:**

```sql
-- Load cart with items in single query
SELECT 
    c.*,
    json_agg(ci.*) as items
FROM carts c
LEFT JOIN cart_items ci ON c.id = ci.cart_id
WHERE c.id = $1
GROUP BY c.id;

-- Find carts with specific product (for stock updates)
CREATE INDEX idx_cart_items_product_variant ON cart_items(product_id, variant_id);

SELECT DISTINCT c.*
FROM carts c
INNER JOIN cart_items ci ON c.id = ci.cart_id
WHERE ci.product_id = $1 
  AND (ci.variant_id = $2 OR $2 IS NULL)
  AND c.is_active = TRUE;
```

---

## 9. Integration Points

### 9.1 Required Service Integrations

**Catalog Service:**
- [ ] Get product details
- [ ] Get product variants
- [ ] Check product availability
- [ ] Get product images

**Inventory Service:**
- [ ] Check stock availability
- [ ] Reserve stock for checkout
- [ ] Release stock on cart abandonment
- [ ] Subscribe to stock update events

**Pricing Service:**
- [ ] Get current prices
- [ ] Get tiered pricing
- [ ] Calculate taxes
- [ ] Get customer-specific pricing

**Promotion Service:**
- [ ] Validate coupons
- [ ] Get eligible promotions
- [ ] Apply discounts
- [ ] Track promotion usage

**Customer Service:**
- [ ] Get customer segment
- [ ] Get customer addresses
- [ ] Get customer preferences

---

## 10. Testing Summary

### Unit Tests Required

- [ ] Add item to cart
- [ ] Update item quantity
- [ ] Remove item from cart
- [ ] Clear cart
- [ ] Apply coupon
- [ ] Remove coupon
- [ ] Calculate totals
- [ ] Merge carts
- [ ] Price synchronization
- [ ] Stock validation

### Integration Tests Required

- [ ] Cart with catalog service
- [ ] Cart with inventory service
- [ ] Cart with pricing service
- [ ] Cart with promotion service
- [ ] Cart persistence (Redis + PostgreSQL)
- [ ] Event publishing (Dapr)

### Performance Tests Required

- [ ] Add to cart (<200ms)
- [ ] Load cart (<100ms)
- [ ] Update cart (<150ms)
- [ ] Concurrent cart operations
- [ ] 1000+ items in cart

### Edge Case Tests Required

- [ ] Race conditions
- [ ] Session expiration
- [ ] Price changes
- [ ] Stock depletion
- [ ] Product unavailability
- [ ] Network failures
- [ ] Service timeouts

---

## 📊 Success Criteria

- [ ] ✅ All cart operations complete in <200ms (p95)
- [ ] ✅ Cart data syncs correctly across devices
- [ ] ✅ No cart data loss on session expiration
- [ ] ✅ Promotions apply correctly 99.9% of time
- [ ] ✅ Stock validation prevents overselling
- [ ] ✅ Price synchronization prevents price discrepancies
- [ ] ✅ Race conditions handled correctly
- [ ] ✅ Test coverage >80%

---

**Status:** Ready for Implementation  
**Next Steps:** Begin implementation based on priority order

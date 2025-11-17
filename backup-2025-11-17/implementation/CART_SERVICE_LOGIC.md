# Cart Service - Logic Implementation Review

> **Service**: Cart Service (part of Order Service)  
> **Last Updated**: December 2024  
> **Status**: Implementation Complete

---

## 📋 Overview

Cart Service quản lý shopping cart cho cả authenticated users và guest users. Service hỗ trợ add/update/remove items, tính toán totals với pricing service, và checkout để convert cart thành order.

---

## 🏗️ Architecture

### Service Structure
```
order/
├── internal/
│   ├── biz/
│   │   ├── cart.go       # Cart usecase
│   │   └── biz.go        # Cart domain models
│   ├── service/
│   │   └── cart.go       # Cart gRPC handlers
│   └── repository/
│       └── cart/         # Cart repository
```

### Key Dependencies
- **Product Service**: Validate products, get product details
- **Warehouse Service**: Check stock availability
- **Pricing Service**: Calculate dynamic prices, discounts
- **Order Service**: Convert cart to order during checkout

---

## 🔄 Core Business Logic

### 1. Add to Cart Flow

#### AddToCart Method
**Location**: `order/internal/biz/cart.go:48`

**Flow**:
1. **Validate Product**
   - Get product from ProductService
   - Return error if product not found
2. **Check Stock Availability**
   - If WarehouseID provided, check stock via WarehouseInventoryService
   - Return error if insufficient stock
3. **Get or Create Cart Session**
   - Try to find existing cart by SessionID, UserID, or GuestToken
   - Create new cart if not found
4. **Create Cart Item**
   - ProductID, ProductSKU, ProductName
   - Quantity, WarehouseID
   - InStock: true (initially)
5. **Get Pricing**
   - Call PricingService.CalculatePrice if available
   - Fallback to product.Price if pricing service fails
   - Calculate UnitPrice and TotalPrice
6. **Save Cart Item**
   - Use repository CreateItem method
7. **Track Metrics**
   - Prometheus metrics for cart operations
8. **Publish Events**
   - `CartItemAddedEvent`
   - `CartUpdatedEvent` (with totals)
9. **Return Updated Cart**

**Key Code**:
```go
func (uc *CartUsecase) AddToCart(ctx context.Context, req *AddToCartRequest) (*Cart, error) {
    // Validate product exists
    product, err := uc.productService.GetProduct(ctx, req.ProductID)
    if err != nil {
        return nil, fmt.Errorf("product not found: %w", err)
    }
    
    // Check stock availability
    if req.WarehouseID != nil {
        if err := uc.warehouseInventoryService.CheckStock(ctx, req.ProductID, *req.WarehouseID, req.Quantity); err != nil {
            return nil, fmt.Errorf("insufficient stock: %w", err)
        }
    }
    
    // Get or create cart session
    cart, err := uc.getOrCreateCart(ctx, req.SessionID, req.UserID, req.GuestToken)
    
    // Get current pricing
    if uc.pricingService != nil {
        priceCalc, err := uc.pricingService.CalculatePrice(ctx, req.ProductID, req.ProductSKU, req.Quantity, req.WarehouseID, product.Currency)
        if err != nil {
            // Fallback to product price
            cartItem.UnitPrice = &product.Price
        } else {
            cartItem.UnitPrice = &priceCalc.FinalPrice
        }
    }
    
    // ... save item, publish events
}
```

---

### 2. Get Cart Flow

#### GetCart Method
**Location**: `order/internal/biz/cart.go:167`

**Flow**:
1. **Find Cart by Identifier**
   - Try SessionID first
   - Then UserID
   - Then GuestToken
   - Return empty cart if not found (not an error)
2. **Convert Model to Biz**
   - Convert database model to business model
3. **Calculate Totals**
   - Call `calculateCartTotals` method
   - Calculate subtotal, discounts, tax estimate, shipping estimate
4. **Update Stock Status**
   - Check stock for each item
   - Update InStock flag
5. **Return Cart**

**Key Code**:
```go
func (uc *CartUsecase) GetCart(ctx context.Context, sessionID string, userID *string, guestToken string) (*Cart, error) {
    // Try to get cart by different identifiers
    var modelCart *model.CartSession
    if sessionID != "" {
        modelCart, err = uc.cartRepo.FindBySessionID(ctx, sessionID)
    } else if userID != nil {
        modelCart, err = uc.cartRepo.FindByUserID(ctx, *userID)
    } else if guestToken != "" {
        modelCart, err = uc.cartRepo.FindByGuestToken(ctx, guestToken)
    }
    
    if modelCart == nil {
        // Return empty cart
        return &Cart{
            Items:  []*CartItem{},
            Totals: &CartTotals{Currency: "USD"},
        }, nil
    }
    
    cart = convertModelCartToBiz(modelCart)
    
    // Calculate totals
    cart.Totals = uc.calculateCartTotals(cart.Items)
    
    // Update stock status for items
    uc.updateItemStockStatus(ctx, cart.Items)
    
    return cart, nil
}
```

---

### 3. Update Cart Item

#### UpdateCartItem Method
**Location**: `order/internal/biz/cart.go:210`

**Flow**:
1. **Validate Quantity**
   - Must be > 0
   - Return error if invalid
2. **Get Current Cart Item**
   - Find item by ItemID
   - Get SessionID from item
3. **Update Item Properties**
   - Update Quantity
   - Update WarehouseID if provided
   - Update Metadata if provided
4. **Recalculate Pricing**
   - If PricingService available, recalculate total price
5. **Save Updated Item**
   - Use repository UpdateItem method
6. **Publish CartUpdatedEvent**
7. **Return Updated Cart**

**Key Code**:
```go
func (uc *CartUsecase) UpdateCartItem(ctx context.Context, req *UpdateCartItemRequest) (*Cart, error) {
    if req.Quantity <= 0 {
        return nil, ErrInvalidQuantity
    }
    
    // Get current cart item
    modelItem, err := uc.cartRepo.FindItemByID(ctx, req.ItemID)
    sessionID := modelItem.SessionID
    
    // Update item
    modelItem.Quantity = req.Quantity
    if req.WarehouseID != nil {
        modelItem.WarehouseID = req.WarehouseID
    }
    
    // Recalculate pricing if quantity changed
    if uc.pricingService != nil && modelItem.UnitPrice != nil {
        totalPrice := *modelItem.UnitPrice * float64(req.Quantity)
        modelItem.TotalPrice = &totalPrice
    }
    
    // ... save, publish events
}
```

---

### 4. Remove Cart Item

#### RemoveCartItem Method
**Location**: `order/internal/biz/cart.go:284`

**Flow**:
1. Delete item by ItemID
2. Return updated cart

**Key Code**:
```go
func (uc *CartUsecase) RemoveCartItem(ctx context.Context, itemID int64, sessionID string, userID *string) (*Cart, error) {
    err := uc.cartRepo.DeleteItemByID(ctx, itemID)
    if err != nil {
        return nil, err
    }
    
    return uc.GetCart(ctx, sessionID, userID, "")
}
```

---

### 5. Clear Cart

#### ClearCart Method
**Location**: `order/internal/biz/cart.go:296`

**Flow**:
1. Get cart if SessionID not provided
2. Delete all items by SessionID
3. Publish `CartClearedEvent`

**Key Code**:
```go
func (uc *CartUsecase) ClearCart(ctx context.Context, sessionID string, userID *string, guestToken string) error {
    // Get cart to find session ID if not provided
    if sessionID == "" {
        cart, err := uc.GetCart(ctx, sessionID, userID, guestToken)
        sessionID = cart.SessionID
    }
    
    // Clear cart items
    err := uc.cartRepo.DeleteItemsBySessionID(ctx, sessionID)
    
    // Publish cart cleared event
    if uc.eventPublisher != nil {
        event := &events.CartClearedEvent{
            SessionID:  sessionID,
            UserID:     userID,
            GuestToken: guestToken,
            Timestamp:  time.Now(),
        }
        uc.eventPublisher.PublishCartCleared(ctx, event)
    }
    
    return nil
}
```

---

### 6. Checkout Cart (Convert to Order)

#### CheckoutCart Method
**Location**: `order/internal/biz/cart.go:334`

**Flow**:
1. **Get Cart**
   - Retrieve cart by SessionID/UserID
   - Return error if cart is empty
2. **Validate Stock**
   - Check all items are still in stock
   - Return error if any item out of stock
3. **Validate User ID**
   - UserID required for checkout
4. **Create Order Request**
   - Convert cart items to order items
   - Include shipping/billing addresses
   - Include payment method
5. **Calculate Totals**
   - Sum up all item totals
   - Use cart item TotalPrice if available
6. **Create Order**
   - Create order via OrderRepo
   - Status: "pending"
   - PaymentStatus: "pending"
7. **Track Metrics**
   - Cart checkout success metric
8. **Publish Events**
   - `CartCheckedOutEvent`
9. **Clear Cart**
   - Clear cart after successful order creation
10. **Return Created Order**

**Key Code**:
```go
func (uc *CartUsecase) CheckoutCart(ctx context.Context, req *CheckoutCartRequest) (*Order, error) {
    // Get cart
    cart, err := uc.GetCart(ctx, req.SessionID, req.UserID, "")
    if len(cart.Items) == 0 {
        return nil, fmt.Errorf("cart is empty")
    }
    
    // Validate all items are still in stock
    for _, item := range cart.Items {
        if item.WarehouseID != nil {
            if err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, *item.WarehouseID, item.Quantity); err != nil {
                return nil, fmt.Errorf("item %s is out of stock: %w", item.ProductSKU, err)
            }
        }
    }
    
    // Validate user ID
    if req.UserID == nil {
        return nil, fmt.Errorf("user ID is required for checkout")
    }
    
    // Create order from cart
    orderReq := &CreateOrderRequest{
        UserID:          *req.UserID,
        Items:           make([]*CreateOrderItemRequest, len(cart.Items)),
        ShippingAddress: req.ShippingAddress,
        BillingAddress:  req.BillingAddress,
        PaymentMethod:   req.PaymentMethod,
    }
    
    // Convert cart items to order items
    var totalAmount float64
    for i, cartItem := range cart.Items {
        orderReq.Items[i] = &CreateOrderItemRequest{
            ProductID:   cartItem.ProductID,
            ProductSKU:  cartItem.ProductSKU,
            Quantity:    cartItem.Quantity,
            WarehouseID: cartItem.WarehouseID,
        }
        
        // Calculate item total
        var itemTotal float64
        if cartItem.TotalPrice != nil {
            itemTotal = *cartItem.TotalPrice
        } else if cartItem.UnitPrice != nil {
            itemTotal = *cartItem.UnitPrice * float64(cartItem.Quantity)
        }
        totalAmount += itemTotal
    }
    
    // Create order
    order := &Order{
        UserID:          orderReq.UserID,
        Status:          "pending",
        PaymentStatus:   "pending",
        Currency:        "USD",
        TotalAmount:     totalAmount,
        PaymentMethod:   orderReq.PaymentMethod,
        Items:           orderItems,
    }
    
    // ... save order, publish events, clear cart
}
```

---

### 7. Merge Cart (Guest to User)

#### MergeCart Method
**Location**: `order/internal/biz/cart.go:463`

**Purpose**: Merge guest cart with user cart after login

**Strategies**:
- `MergeStrategyReplace`: Clear user cart, move guest items
- `MergeStrategyMerge`: Merge quantities for same products
- `MergeStrategyKeepUser`: Keep user cart as is

**Flow**:
1. Get guest cart by GuestToken
2. Get user cart by UserID
3. Handle scenarios:
   - No guest cart: Return user cart
   - No user cart: Convert guest cart to user cart
   - Both exist: Merge based on strategy
4. Delete guest cart
5. Return merged cart

**Key Code**:
```go
func (uc *CartUsecase) MergeCart(ctx context.Context, req *MergeCartRequest) (*Cart, error) {
    // Get guest cart
    modelGuestCart, err := uc.cartRepo.FindByGuestToken(ctx, req.GuestToken)
    guestCart := convertModelCartToBiz(modelGuestCart)
    
    // Get user cart
    modelUserCart, err := uc.cartRepo.FindByUserID(ctx, req.UserID)
    userCart := convertModelCartToBiz(modelUserCart)
    
    // If no guest cart, return user cart
    if guestCart == nil {
        if userCart == nil {
            return &Cart{Items: []*CartItem{}, Totals: &CartTotals{Currency: "USD"}}, nil
        }
        return userCart, nil
    }
    
    // If no user cart, convert guest cart to user cart
    if userCart == nil {
        modelGuestCart.UserID = &req.UserID
        modelGuestCart.GuestToken = ""
        err = uc.cartRepo.Update(ctx, modelGuestCart, nil)
        return convertModelCartToBiz(modelGuestCart), nil
    }
    
    // Merge carts based on strategy
    switch req.Strategy {
    case MergeStrategyReplace:
        // Clear user cart and move guest items
        uc.cartRepo.DeleteItemsBySessionID(ctx, userCart.SessionID)
        for _, bizItem := range guestCart.Items {
            modelItem := convertBizCartItemToModel(bizItem)
            modelItem.SessionID = userCart.SessionID
            uc.cartRepo.CreateItem(ctx, modelItem)
        }
    case MergeStrategyMerge:
        // Merge quantities for same products
        for _, bizItem := range guestCart.Items {
            modelItem := convertBizCartItemToModel(bizItem)
            modelItem.SessionID = userCart.SessionID
            uc.cartRepo.CreateItem(ctx, modelItem) // This will merge quantities
        }
    case MergeStrategyKeepUser:
        // Do nothing, keep user cart as is
    }
    
    // Delete guest cart
    uc.cartRepo.DeleteBySessionID(ctx, guestCart.SessionID)
    
    return uc.GetCart(ctx, userCart.SessionID, &req.UserID, "")
}
```

---

## 📊 Domain Models

### Cart Entity
```go
type Cart struct {
    ID         int64
    SessionID  string
    UserID     *string  // UUID (optional for guest carts)
    GuestToken string
    Items      []*CartItem
    Totals     *CartTotals
    ExpiresAt  *time.Time
    Metadata   map[string]interface{}
    CreatedAt  time.Time
    UpdatedAt  time.Time
}
```

### CartItem Entity
```go
type CartItem struct {
    ID             int64
    SessionID      string
    ProductID      string  // UUID
    ProductSKU     string
    ProductName    string
    Quantity       int32
    UnitPrice      *float64  // From PricingService
    TotalPrice     *float64  // UnitPrice * Quantity
    DiscountAmount float64
    WarehouseID    *string  // UUID (optional)
    InStock        bool
    Metadata       map[string]interface{}
    AddedAt        time.Time
    UpdatedAt      time.Time
}
```

### CartTotals Entity
```go
type CartTotals struct {
    Subtotal        float64
    DiscountTotal   float64
    TaxEstimate     float64      // 8% estimate
    ShippingEstimate float64     // $15.99 flat estimate
    TotalEstimate   float64      // Subtotal - Discount + Tax + Shipping
    ItemCount       int32
    UniqueItems     int32
    Currency        string
}
```

---

## 🔔 Events Published

### CartItemAddedEvent
- **Topic**: `cart.item_added`
- **Payload**:
  - SessionID, UserID, GuestToken
  - ProductID, ProductSKU, ProductName
  - Quantity, UnitPrice
  - WarehouseID
  - Timestamp, Metadata

### CartUpdatedEvent
- **Topic**: `cart.updated`
- **Payload**:
  - SessionID, UserID, GuestToken
  - ItemCount, TotalAmount, Currency
  - Timestamp

### CartClearedEvent
- **Topic**: `cart.cleared`
- **Payload**:
  - SessionID, UserID, GuestToken
  - Timestamp

### CartCheckedOutEvent
- **Topic**: `cart.checked_out`
- **Payload**:
  - SessionID, UserID
  - OrderID, OrderNumber
  - TotalAmount, Currency
  - Timestamp, Metadata

---

## 📈 Metrics & Observability

### Prometheus Metrics
- `CartOperationDuration`: Operation duration by type
- `CartOperationsTotal`: Total operations by type and result
- `CartItemsAddedTotal`: Items added to cart counter
- `CartCheckoutsTotal`: Cart checkouts by result

---

## 🔐 Business Rules

### Cart Identification
- **SessionID**: Primary identifier for cart
- **UserID**: For authenticated users
- **GuestToken**: For guest users
- Cart can be found by any of these identifiers

### Pricing Integration
- PricingService used for dynamic pricing
- Falls back to product.Price if PricingService unavailable
- UnitPrice and TotalPrice stored in CartItem

### Stock Validation
- Stock checked when adding item
- Stock status updated when getting cart
- Stock validated again during checkout

### Cart Totals Calculation
- **Subtotal**: Sum of all item TotalPrice
- **DiscountTotal**: Sum of all item DiscountAmount
- **TaxEstimate**: 8% of subtotal (simplified)
- **ShippingEstimate**: $15.99 flat rate (simplified)
- **TotalEstimate**: Subtotal - Discount + Tax + Shipping

### Cart Expiration
- Cart can have ExpiresAt timestamp
- Used for cleanup of abandoned carts

---

## 🔗 Service Integrations

### Product Service
- **GetProduct**: Get product details and price
- Used during AddToCart

### Warehouse Service
- **CheckStock**: Validate stock availability
- Called during AddToCart and CheckoutCart
- Used to update InStock status

### Pricing Service
- **CalculatePrice**: Get dynamic pricing
- Returns FinalPrice with discounts applied
- Falls back to product price if unavailable

### Order Service
- **CreateOrder**: Convert cart to order
- Called during CheckoutCart

---

## 🚨 Error Handling

### Common Errors
- `ErrCartNotFound`: Cart not found (returns empty cart)
- `ErrCartExpired`: Cart has expired
- `ErrCartItemNotFound`: Cart item not found
- `ErrInvalidQuantity`: Quantity must be > 0

### Error Scenarios
1. **Product Not Found**: Return error during AddToCart
2. **Insufficient Stock**: Return error, prevent adding to cart
3. **Empty Cart Checkout**: Return error during checkout
4. **User ID Required**: Return error if UserID not provided for checkout

---

## 📝 Notes & TODOs

### Known Limitations
1. **Tax Calculation**: Currently hardcoded 8% estimate
2. **Shipping Calculation**: Currently hardcoded $15.99 flat rate
3. **Cart Expiration**: Expiration logic not fully implemented

### Future Enhancements
- Integration with Shipping Service for accurate shipping rates
- Integration with Tax Service for accurate tax calculation
- Cart expiration cleanup job
- Cart abandonment tracking
- Cart recovery emails
- Save for later functionality
- Cart sharing

---

## 📚 Related Documentation

- [Order Service Logic](./ORDER_SERVICE_LOGIC.md)
- [Pricing Service Logic](../docs/services/pricing-service.md)
- [Cart Service API Docs](../docs/services/order-service.md#cart-apis)


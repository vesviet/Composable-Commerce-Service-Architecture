# 🎫 Checkout Process Logic Checklist

**Service:** Order/Checkout Service  
**Created:** 2025-11-19  
**Status:** 🟡 **Implementation Required**  
**Priority:** 🔴 **Critical**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Checkout Steps](#checkout-steps)
3. [Checkout Validation](#checkout-validation)
4. [Price Calculation](#price-calculation)
5. [Service Orchestration](#service-orchestration)
6. [Checkout State Management](#checkout-state-management)
7. [Inventory Reservation](#inventory-reservation)
8. [Order Creation](#order-creation)
9. [Error Handling & Rollback](#error-handling--rollback)
10. [Testing Scenarios](#testing-scenarios)

---

## 🎯 Overview

Checkout là critical orchestration service kết nối TẤT CẢ các services trong hệ thống. Một lỗi ở checkout = mất đơn hàng = mất doanh thu.

**Key Requirements:**
- **Atomicity:** All or nothing (create order + reserve stock + authorize payment)
- **Consistency:** All services must be in sync
- **Performance:** Complete checkout <5s (p95)
- **Reliability:** >99.9% success rate
- **Recovery:** Auto-rollback on failure

**Critical Metrics:**
- Checkout completion rate: >80%
- Checkout abandonment rate: <20%
- Checkout time: <5s (p95)
- Payment success rate: >95%
- Order creation success: >99.9%

---

## 1. Checkout Steps

### 1.1 Step 1: Cart Review

**Requirements:**

- [ ] **R1.1.1** Display cart items with latest prices
- [ ] **R1.1.2** Show stock availability for each item
- [ ] **R1.1.3** Display applied promotions/discounts
- [ ] **R1.1.4** Show estimated tax (if applicable)
- [ ] **R1.1.5** Show cart total
- [ ] **R1.1.6** Allow cart editing from checkout
- [ ] **R1.1.7** Validate cart before proceeding

**Implementation:**

```go
type CheckoutSession struct {
    ID                string
    UserID            string
    CartID            string
    
    // Steps completion
    CartReviewed      bool
    ShippingSelected  bool
    PaymentSelected   bool
    OrderReviewed     bool
    
    // Checkout data
    Cart              *Cart
    ShippingAddress   *Address
    BillingAddress    *Address
    ShippingMethod    *ShippingMethod
    PaymentMethod     *PaymentMethod
    
    // Pricing
    Subtotal          float64
    DiscountAmount    float64
    TaxAmount         float64
    ShippingAmount    float64
    Total             float64
    
    // State
    Status            string  // "active", "completed", "abandoned", "expired"
    CurrentStep       int
    
    // Metadata
    CreatedAt         time.Time
    UpdatedAt         time.Time
    ExpiresAt         time.Time
    CompletedAt       *time.Time
}

func (uc *CheckoutUseCase) InitiateCheckout(ctx context.Context, cartID string) (*CheckoutSession, error) {
    // 1. Validate cart
    cart, err := uc.cartClient.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    if len(cart.Items) == 0 {
        return nil, ErrCartEmpty
    }
    
    // 2. Validate all items
    validation, err := uc.cartClient.ValidateCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    if !validation.IsValid {
        return nil, &CheckoutError{
            Code:    "CART_VALIDATION_FAILED",
            Message: "Cart validation failed",
            Errors:  validation.Errors,
        }
    }
    
    // 3. Create checkout session
    session := &CheckoutSession{
        ID:          uuid.New().String(),
        UserID:      cart.UserID,
        CartID:      cartID,
        Cart:        cart,
        Status:      "active",
        CurrentStep: 1,
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
        ExpiresAt:   time.Now().Add(30 * time.Minute), // 30 min to complete
    }
    
    // 4. Save session
    if err := uc.repo.SaveCheckoutSession(ctx, session); err != nil {
        return nil, err
    }
    
    // 5. Start expiry timer
    uc.scheduleSessionExpiry(session.ID, session.ExpiresAt)
    
    return session, nil
}
```

**Test Scenarios:**

- [ ] **T1.1.1** Initiate checkout with valid cart
- [ ] **T1.1.2** Cannot checkout with empty cart
- [ ] **T1.1.3** Cannot checkout with out-of-stock items
- [ ] **T1.1.4** Cart prices synced before checkout
- [ ] **T1.1.5** Applied promotions validated

---

### 1.2 Step 2: Shipping Address Selection

**Requirements:**

- [ ] **R1.2.1** Display saved addresses
- [ ] **R1.2.2** Allow adding new address
- [ ] **R1.2.3** Validate address format
- [ ] **R1.2.4** Verify address deliverability
- [ ] **R1.2.5** Set default shipping address
- [ ] **R1.2.6** Support multiple addresses (split shipment)

**Implementation:**

```go
func (uc *CheckoutUseCase) SetShippingAddress(ctx context.Context, sessionID string, addressID string) (*CheckoutSession, error) {
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    // Validate session
    if session.Status != "active" {
        return nil, ErrCheckoutNotActive
    }
    
    if time.Now().After(session.ExpiresAt) {
        return nil, ErrCheckoutExpired
    }
    
    // Get address
    address, err := uc.customerClient.GetAddress(ctx, addressID)
    if err != nil {
        return nil, err
    }
    
    // Validate address belongs to user
    if address.CustomerID != session.UserID {
        return nil, ErrUnauthorized
    }
    
    // Validate address is deliverable
    deliverable, err := uc.shippingClient.ValidateAddress(ctx, address)
    if err != nil || !deliverable {
        return nil, &CheckoutError{
            Code:    "ADDRESS_NOT_DELIVERABLE",
            Message: "This address is not deliverable",
        }
    }
    
    // Update session
    session.ShippingAddress = address
    session.ShippingSelected = true
    session.CurrentStep = 3
    session.UpdatedAt = time.Now()
    
    // Recalculate shipping options
    session.ShippingMethods, err = uc.getShippingMethods(ctx, session)
    if err != nil {
        return nil, err
    }
    
    // Save session
    if err := uc.repo.SaveCheckoutSession(ctx, session); err != nil {
        return nil, err
    }
    
    return session, nil
}

func (uc *CheckoutUseCase) AddNewShippingAddress(ctx context.Context, sessionID string, req *AddAddressRequest) (*CheckoutSession, error) {
    // 1. Create address via customer service
    address, err := uc.customerClient.CreateAddress(ctx, &CreateAddressRequest{
        CustomerID:  req.CustomerID,
        AddressLine1: req.AddressLine1,
        AddressLine2: req.AddressLine2,
        City:        req.City,
        State:       req.State,
        PostalCode:  req.PostalCode,
        Country:     req.Country,
        PhoneNumber: req.PhoneNumber,
    })
    
    if err != nil {
        return nil, err
    }
    
    // 2. Set as shipping address
    return uc.SetShippingAddress(ctx, sessionID, address.ID)
}
```

**Test Scenarios:**

- [ ] **T1.2.1** Select saved address
- [ ] **T1.2.2** Add new address
- [ ] **T1.2.3** Invalid address format rejected
- [ ] **T1.2.4** Undeliverable address rejected
- [ ] **T1.2.5** Address validation (zip code, country)

---

### 1.3 Step 3: Shipping Method Selection

**Requirements:**

- [ ] **R1.3.1** Display available shipping methods
- [ ] **R1.3.2** Show delivery estimates
- [ ] **R1.3.3** Show shipping costs
- [ ] **R1.3.4** Filter by delivery speed/price
- [ ] **R1.3.5** Support free shipping promotions
- [ ] **R1.3.6** Recalculate total with shipping

**Implementation:**

```go
func (uc *CheckoutUseCase) GetShippingMethods(ctx context.Context, sessionID string) ([]*ShippingMethod, error) {
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    if session.ShippingAddress == nil {
        return nil, ErrShippingAddressRequired
    }
    
    // Get shipping options from shipping service
    methods, err := uc.shippingClient.CalculateShipping(ctx, &CalculateShippingRequest{
        Items:           session.Cart.Items,
        Origin:          uc.warehouseAddress,
        Destination:     session.ShippingAddress,
        TotalWeight:     session.Cart.TotalWeight,
        TotalValue:      session.Cart.Subtotal,
    })
    
    if err != nil {
        return nil, err
    }
    
    // Check for free shipping promotions
    for i, method := range methods {
        if uc.isFreeShippingEligible(session, method) {
            methods[i].Cost = 0
            methods[i].OriginalCost = method.Cost
            methods[i].FreeShipping = true
        }
    }
    
    return methods, nil
}

func (uc *CheckoutUseCase) SelectShippingMethod(ctx context.Context, sessionID, methodID string) (*CheckoutSession, error) {
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    // Get shipping methods
    methods, err := uc.GetShippingMethods(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    // Find selected method
    var selectedMethod *ShippingMethod
    for _, m := range methods {
        if m.ID == methodID {
            selectedMethod = m
            break
        }
    }
    
    if selectedMethod == nil {
        return nil, ErrShippingMethodNotFound
    }
    
    // Update session
    session.ShippingMethod = selectedMethod
    session.ShippingAmount = selectedMethod.Cost
    session.PaymentSelected = true
    session.CurrentStep = 4
    
    // Recalculate total
    uc.recalculateTotal(session)
    
    session.UpdatedAt = time.Now()
    
    if err := uc.repo.SaveCheckoutSession(ctx, session); err != nil {
        return nil, err
    }
    
    return session, nil
}
```

**Test Scenarios:**

- [ ] **T1.3.1** Get shipping methods for address
- [ ] **T1.3.2** Free shipping applied
- [ ] **T1.3.3** Express shipping cost calculated
- [ ] **T1.3.4** No shipping methods available (remote area)
- [ ] **T1.3.5** Shipping total updated

---

### 1.4 Step 4: Payment Method Selection

**Requirements:**

- [ ] **R1.4.1** Display available payment methods
- [ ] **R1.4.2** Support saved cards
- [ ] **R1.4.3** Support digital wallets
- [ ] **R1.4.4** Support bank transfer
- [ ] **R1.4.5** Support COD (if available)
- [ ] **R1.4.6** Validate payment method for region

**Implementation:**

```go
func (uc *CheckoutUseCase) GetAvailablePaymentMethods(ctx context.Context, sessionID string) ([]*PaymentMethodOption, error) {
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    methods := []*PaymentMethodOption{}
    
    // 1. Credit/Debit cards
    methods = append(methods, &PaymentMethodOption{
        Type:        "credit_card",
        Name:        "Credit/Debit Card",
        Icon:        "card",
        SavedCards:  uc.getSavedCards(ctx, session.UserID),
    })
    
    // 2. Digital wallets
    methods = append(methods, &PaymentMethodOption{
        Type: "paypal",
        Name: "PayPal",
        Icon: "paypal",
    })
    
    methods = append(methods, &PaymentMethodOption{
        Type: "apple_pay",
        Name: "Apple Pay",
        Icon: "apple",
    })
    
    // 3. Bank transfer
    methods = append(methods, &PaymentMethodOption{
        Type: "bank_transfer",
        Name: "Bank Transfer",
        Icon: "bank",
    })
    
    // 4. COD (check availability)
    codAvailable, _ := uc.shippingClient.IsCODAvailable(ctx, session.ShippingAddress)
    if codAvailable {
        methods = append(methods, &PaymentMethodOption{
            Type: "cash_on_delivery",
            Name: "Cash on Delivery",
            Icon: "cash",
            Fee:  uc.calculateCODFee(session.Total),
        })
    }
    
    return methods, nil
}

func (uc *CheckoutUseCase) SelectPaymentMethod(ctx context.Context, sessionID string, req *SelectPaymentMethodRequest) (*CheckoutSession, error) {
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    // Validate payment method
    if err := uc.validatePaymentMethod(session, req); err != nil {
        return nil, err
    }
    
    // Update session
    session.PaymentMethod = &PaymentMethod{
        Type:       req.Type,
        CardToken:  req.CardToken,
        SaveCard:   req.SaveCard,
    }
    
    session.OrderReviewed = false
    session.CurrentStep = 5
    session.UpdatedAt = time.Now()
    
    if err := uc.repo.SaveCheckoutSession(ctx, session); err != nil {
        return nil, err
    }
    
    return session, nil
}
```

**Test Scenarios:**

- [ ] **T1.4.1** Get payment methods
- [ ] **T1.4.2** Select credit card
- [ ] **T1.4.3** Select saved card
- [ ] **T1.4.4** Select PayPal
- [ ] **T1.4.5** COD available for address
- [ ] **T1.4.6** COD not available for address

---

### 1.5 Step 5: Order Review & Confirmation

**Requirements:**

- [ ] **R1.5.1** Display complete order summary
- [ ] **R1.5.2** Show final pricing breakdown
- [ ] **R1.5.3** Terms & conditions acceptance
- [ ] **R1.5.4** Final validation before submission
- [ ] **R1.5.5** Order submission button
- [ ] **R1.5.6** Prevent double submission

**Implementation:**

```go
type OrderSummary struct {
    Items             []*CartItem
    ShippingAddress   *Address
    ShippingMethod    *ShippingMethod
    PaymentMethod     *PaymentMethod
    
    // Pricing breakdown
    Subtotal          float64
    DiscountAmount    float64
    TaxAmount         float64
    ShippingAmount    float64
    Total             float64
    
    // Applied promotions
    Promotions        []*AppliedPromotion
}

func (uc *CheckoutUseCase) GetOrderSummary(ctx context.Context, sessionID string) (*OrderSummary, error) {
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    // Validate all steps completed
    if !session.CartReviewed || !session.ShippingSelected || 
       !session.PaymentSelected {
        return nil, ErrCheckoutIncomplete
    }
    
    // Recalculate everything one final time
    uc.recalculateTotal(session)
    
    summary := &OrderSummary{
        Items:           session.Cart.Items,
        ShippingAddress: session.ShippingAddress,
        ShippingMethod:  session.ShippingMethod,
        PaymentMethod:   session.PaymentMethod,
        Subtotal:        session.Subtotal,
        DiscountAmount:  session.DiscountAmount,
        TaxAmount:       session.TaxAmount,
        ShippingAmount:  session.ShippingAmount,
        Total:           session.Total,
        Promotions:      session.Cart.AppliedPromotions,
    }
    
    return summary, nil
}

func (uc *CheckoutUseCase) PlaceOrder(ctx context.Context, sessionID string, acceptTerms bool) (*Order, error) {
    // Prevent double submission
    if uc.isOrderSubmitting(sessionID) {
        return nil, ErrOrderAlreadySubmitting
    }
    
    uc.markOrderSubmitting(sessionID)
    defer uc.clearOrderSubmitting(sessionID)
    
    if !acceptTerms {
        return nil, ErrTermsNotAccepted
    }
    
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return nil, err
    }
    
    // Final validation
    if err := uc.validateFinalCheckout(ctx, session); err != nil {
        return nil, err
    }
    
    // Start distributed transaction
    return uc.executeCheckout(ctx, session)
}
```

**Test Scenarios:**

- [ ] **T1.5.1** Get order summary
- [ ] **T1.5.2** Cannot proceed without terms acceptance
- [ ] **T1.5.3** Double submission prevented
- [ ] **T1.5.4** Final price validated

---

## 2. Price Calculation

### 2.1 Total Calculation Logic

**Requirements:**

- [ ] **R2.1.1** Calculate subtotal (item prices × quantities)
- [ ] **R2.1.2** Apply discounts (coupons, promotions)
- [ ] **R2.1.3** Calculate tax based on shipping address
- [ ] **R2.1.4** Add shipping cost
- [ ] **R2.1.5** Calculate final total
- [ ] **R2.1.6** Handle rounding correctly

**Implementation:**

```go
func (uc *CheckoutUseCase) recalculateTotal(session *CheckoutSession) {
    // 1. Calculate subtotal
    session.Subtotal = 0
    for _, item := range session.Cart.Items {
        session.Subtotal += item.Price * float64(item.Quantity)
    }
    
    // 2. Apply discounts
    session.DiscountAmount = 0
    for _, promo := range session.Cart.AppliedPromotions {
        session.DiscountAmount += promo.DiscountAmount
    }
    
    // Ensure discount doesn't exceed subtotal
    if session.DiscountAmount > session.Subtotal {
        session.DiscountAmount = session.Subtotal
    }
    
    // 3. Calculate taxable amount
    taxableAmount := session.Subtotal - session.DiscountAmount
    
    // 4. Calculate tax (if shipping address available)
    session.TaxAmount = 0
    if session.ShippingAddress != nil {
        taxRate, err := uc.getTaxRate(session.ShippingAddress)
        if err == nil {
            session.TaxAmount = taxableAmount * taxRate
        }
    }
    
    // 5. Add shipping
    if session.ShippingMethod != nil {
        session.ShippingAmount = session.ShippingMethod.Cost
    }
    
    // 6. Calculate final total
    session.Total = taxableAmount + session.TaxAmount + session.ShippingAmount
    
    // 7. Round to 2 decimal places
    session.Subtotal = roundToDecimal(session.Subtotal, 2)
    session.DiscountAmount = roundToDecimal(session.DiscountAmount, 2)
    session.TaxAmount = roundToDecimal(session.TaxAmount, 2)
    session.ShippingAmount = roundToDecimal(session.ShippingAmount, 2)
    session.Total = roundToDecimal(session.Total, 2)
}

func (uc *CheckoutUseCase) getTaxRate(address *Address) (float64, error) {
    // Get tax rate from tax service based on address
    taxRate, err := uc.taxClient.GetTaxRate(ctx, &GetTaxRateRequest{
        Country:    address.Country,
        State:      address.State,
        City:       address.City,
        PostalCode: address.PostalCode,
    })
    
    if err != nil {
        return 0, err
    }
    
    return taxRate.Rate, nil
}
```

**Test Scenarios:**

- [ ] **T2.1.1** Subtotal calculated correctly
- [ ] **T2.1.2** Discount applied correctly
- [ ] **T2.1.3** Tax calculated based on address
- [ ] **T2.1.4** Shipping cost added
- [ ] **T2.1.5** Total is correct
- [ ] **T2.1.6** Rounding is correct

---

## 3. Service Orchestration

### 3.1 Checkout Execution Flow

**Requirements:**

- [ ] **R3.1.1** Reserve inventory
- [ ] **R3.1.2** Authorize payment
- [ ] **R3.1.3** Create order
- [ ] **R3.1.4** Clear cart
- [ ] **R3.1.5** Send confirmation
- [ ] **R3.1.6** Rollback on failure

**Implementation:**

```go
func (uc *CheckoutUseCase) executeCheckout(ctx context.Context, session *CheckoutSession) (*Order, error) {
    // Use Saga pattern for distributed transaction
    saga := uc.newCheckoutSaga(session)
    
    // Step 1: Reserve inventory
    reservationID, err := saga.Execute(ctx, "reserve_inventory", func(ctx context.Context) (interface{}, error) {
        return uc.reserveInventory(ctx, session)
    }, func(ctx context.Context, result interface{}) error {
        return uc.releaseInventory(ctx, result.(string))
    })
    
    if err != nil {
        return nil, &CheckoutError{
            Code:    "INVENTORY_RESERVATION_FAILED",
            Message: "Failed to reserve inventory",
            Err:     err,
        }
    }
    
    // Step 2: Authorize payment
    paymentAuth, err := saga.Execute(ctx, "authorize_payment", func(ctx context.Context) (interface{}, error) {
        return uc.authorizePayment(ctx, session)
    }, func(ctx context.Context, result interface{}) error {
        return uc.voidPaymentAuthorization(ctx, result.(*PaymentAuthorization))
    })
    
    if err != nil {
        saga.Rollback(ctx)
        return nil, &CheckoutError{
            Code:    "PAYMENT_AUTHORIZATION_FAILED",
            Message: "Payment authorization failed",
            Err:     err,
        }
    }
    
    // Step 3: Create order
    order, err := saga.Execute(ctx, "create_order", func(ctx context.Context) (interface{}, error) {
        return uc.createOrder(ctx, session, reservationID.(string), paymentAuth.(*PaymentAuthorization))
    }, func(ctx context.Context, result interface{}) error {
        return uc.cancelOrder(ctx, result.(*Order).ID)
    })
    
    if err != nil {
        saga.Rollback(ctx)
        return nil, &CheckoutError{
            Code:    "ORDER_CREATION_FAILED",
            Message: "Failed to create order",
            Err:     err,
        }
    }
    
    // Step 4: Clear cart (non-critical, no rollback needed)
    _ = uc.cartClient.ClearCart(ctx, session.CartID)
    
    // Step 5: Send confirmation email (async, non-blocking)
    go uc.sendOrderConfirmation(context.Background(), order.(*Order))
    
    // Step 6: Update checkout session
    session.Status = "completed"
    session.CompletedAt = timePtr(time.Now())
    uc.repo.SaveCheckoutSession(ctx, session)
    
    // Step 7: Publish event
    uc.publishEvent(ctx, "checkout.completed", order)
    
    return order.(*Order), nil
}
```

**Test Scenarios:**

- [ ] **T3.1.1** Successful checkout flow
- [ ] **T3.1.2** Inventory reservation fails - rollback
- [ ] **T3.1.3** Payment authorization fails - rollback
- [ ] **T3.1.4** Order creation fails - rollback
- [ ] **T3.1.5** All steps succeed

---

### 3.2 Inventory Reservation

**Requirements:**

- [ ] **R3.2.1** Reserve stock for all items
- [ ] **R3.2.2** Handle partial stock availability
- [ ] **R3.2.3** Set reservation expiry (e.g., 30 min)
- [ ] **R3.2.4** Release on payment failure
- [ ] **R3.2.5** Confirm on order creation

**Implementation:**

```go
func (uc *CheckoutUseCase) reserveInventory(ctx context.Context, session *CheckoutSession) (string, error) {
    // Create inventory reservation
    reservation, err := uc.inventoryClient.CreateReservation(ctx, &CreateReservationRequest{
        Items: convertToReservationItems(session.Cart.Items),
        CustomerID: session.UserID,
        ExpiresIn: 30 * time.Minute,
    })
    
    if err != nil {
        return "", err
    }
    
    // Check if all items reserved
    if !reservation.AllItemsReserved {
        // Release partial reservation
        uc.inventoryClient.ReleaseReservation(ctx, reservation.ID)
        
        return "", &CheckoutError{
            Code:    "INSUFFICIENT_STOCK",
            Message: "Some items are out of stock",
            UnavailableItems: reservation.UnavailableItems,
        }
    }
    
    return reservation.ID, nil
}

func (uc *CheckoutUseCase) releaseInventory(ctx context.Context, reservationID string) error {
    return uc.inventoryClient.ReleaseReservation(ctx, reservationID)
}
```

**Test Scenarios:**

- [ ] **T3.2.1** All items reserved successfully
- [ ] **T3.2.2** Partial stock - reservation fails
- [ ] **T3.2.3** Reservation expires after 30 min
- [ ] **T3.2.4** Reservation released on rollback
- [ ] **T3.2.5** Reservation confirmed on order creation

---

### 3.3 Payment Authorization

**Requirements:**

- [ ] **R3.3.1** Authorize payment for total amount
- [ ] **R3.3.2** Handle payment failures
- [ ] **R3.3.3** Support multiple payment methods
- [ ] **R3.3.4** Void authorization on rollback
- [ ] **R3.3.5** Capture payment after order shipped

**Implementation:**

```go
func (uc *CheckoutUseCase) authorizePayment(ctx context.Context, session *CheckoutSession) (*PaymentAuthorization, error) {
    paymentAuth, err := uc.paymentClient.AuthorizePayment(ctx, &AuthorizePaymentRequest{
        Amount:          session.Total,
        Currency:        session.Currency,
        PaymentMethod:   session.PaymentMethod,
        CustomerID:      session.UserID,
        BillingAddress:  session.BillingAddress,
        ShippingAddress: session.ShippingAddress,
        OrderReference:  session.ID,
    })
    
    if err != nil {
        return nil, err
    }
    
    if paymentAuth.Status != "authorized" {
        return nil, &PaymentError{
            Code:    paymentAuth.ErrorCode,
            Message: paymentAuth.ErrorMessage,
        }
    }
    
    return paymentAuth, nil
}

func (uc *CheckoutUseCase) voidPaymentAuthorization(ctx context.Context, auth *PaymentAuthorization) error {
    return uc.paymentClient.VoidAuthorization(ctx, auth.ID)
}
```

**Test Scenarios:**

- [ ] **T3.3.1** Payment authorized successfully
- [ ] **T3.3.2** Payment declined
- [ ] **T3.3.3** Insufficient funds
- [ ] **T3.3.4** Card expired
- [ ] **T3.3.5** Authorization voided on rollback

---

### 3.4 Order Creation

**Requirements:**

- [ ] **R3.4.1** Create order with all details
- [ ] **R3.4.2** Generate order number
- [ ] **R3.4.3** Set order status to "pending"
- [ ] **R3.4.4** Link payment authorization
- [ ] **R3.4.5** Link inventory reservation
- [ ] **R3.4.6** Store pricing snapshot

**Implementation:**

```go
func (uc *CheckoutUseCase) createOrder(ctx context.Context, session *CheckoutSession, reservationID string, paymentAuth *PaymentAuthorization) (*Order, error) {
    order, err := uc.orderClient.CreateOrder(ctx, &CreateOrderRequest{
        CustomerID:       session.UserID,
        OrderNumber:      uc.generateOrderNumber(),
        
        // Items
        Items:            session.Cart.Items,
        
        // Addresses
        ShippingAddress:  session.ShippingAddress,
        BillingAddress:   session.BillingAddress,
        
        // Shipping
        ShippingMethod:   session.ShippingMethod,
        ShippingAmount:   session.ShippingAmount,
        
        // Payment
        PaymentMethod:    session.PaymentMethod,
        PaymentAuthID:    paymentAuth.ID,
        
        // Pricing
        Subtotal:         session.Subtotal,
        DiscountAmount:   session.DiscountAmount,
        TaxAmount:        session.TaxAmount,
        Total:            session.Total,
        Currency:         session.Currency,
        
        // References
        CartID:           session.CartID,
        CheckoutID:       session.ID,
        ReservationID:    reservationID,
        
        // Promotions
        AppliedPromotions: session.Cart.AppliedPromotions,
        
        // Status
        Status:           "pending_payment",
    })
    
    if err != nil {
        return nil, err
    }
    
    return order, nil
}

func (uc *CheckoutUseCase) generateOrderNumber() string {
    // Generate unique order number: ORD-YYYYMMDD-XXXXXX
    timestamp := time.Now().Format("20060102")
    random := fmt.Sprintf("%06d", rand.Intn(1000000))
    return fmt.Sprintf("ORD-%s-%s", timestamp, random)
}
```

**Test Scenarios:**

- [ ] **T3.4.1** Order created successfully
- [ ] **T3.4.2** Order number is unique
- [ ] **T3.4.3** All order details saved
- [ ] **T3.4.4** Payment linked to order
- [ ] **T3.4.5** Reservation linked to order

---

## 4. Error Handling & Rollback

### 4.1 Saga Pattern Implementation

**Requirements:**

- [ ] **R4.1.1** Track all executed steps
- [ ] **R4.1.2** Define compensating transactions
- [ ] **R4.1.3** Execute rollback in reverse order
- [ ] **R4.1.4** Handle partial rollback failures
- [ ] **R4.1.5** Log all saga operations

**Implementation:**

```go
type CheckoutSaga struct {
    session        *CheckoutSession
    executedSteps  []SagaStep
    logger         *log.Helper
}

type SagaStep struct {
    Name           string
    ExecuteFunc    func(context.Context) (interface{}, error)
    CompensateFunc func(context.Context, interface{}) error
    Result         interface{}
    ExecutedAt     time.Time
}

func (s *CheckoutSaga) Execute(ctx context.Context, name string, executeFunc func(context.Context) (interface{}, error), compensateFunc func(context.Context, interface{}) error) (interface{}, error) {
    s.logger.Infof("Executing saga step: %s", name)
    
    // Execute step
    result, err := executeFunc(ctx)
    if err != nil {
        s.logger.Errorf("Saga step %s failed: %v", name, err)
        return nil, err
    }
    
    // Record step
    step := SagaStep{
        Name:           name,
        ExecuteFunc:    executeFunc,
        CompensateFunc: compensateFunc,
        Result:         result,
        ExecutedAt:     time.Now(),
    }
    
    s.executedSteps = append(s.executedSteps, step)
    
    s.logger.Infof("Saga step %s completed successfully", name)
    return result, nil
}

func (s *CheckoutSaga) Rollback(ctx context.Context) error {
    s.logger.Warnf("Rolling back checkout saga, %d steps to compensate", len(s.executedSteps))
    
    // Rollback in reverse order
    for i := len(s.executedSteps) - 1; i >= 0; i-- {
        step := s.executedSteps[i]
        
        s.logger.Infof("Compensating saga step: %s", step.Name)
        
        if err := step.CompensateFunc(ctx, step.Result); err != nil {
            s.logger.Errorf("Failed to compensate step %s: %v", step.Name, err)
            // Continue with other compensations
        }
    }
    
    s.logger.Infof("Saga rollback completed")
    return nil
}
```

**Test Scenarios:**

- [ ] **T4.1.1** Successful saga execution
- [ ] **T4.1.2** Rollback after inventory failure
- [ ] **T4.1.3** Rollback after payment failure
- [ ] **T4.1.4** Rollback after order creation failure
- [ ] **T4.1.5** Partial rollback failure handled

---

## 5. Checkout State Management

### 5.1 Session Expiry

**Requirements:**

- [ ] **R5.1.1** Session expires after 30 minutes
- [ ] **R5.1.2** Release reserved inventory on expiry
- [ ] **R5.1.3** Void payment authorization on expiry
- [ ] **R5.1.4** Allow session extension
- [ ] **R5.1.5** Notify user of expiry

**Implementation:**

```go
func (uc *CheckoutUseCase) scheduleSessionExpiry(sessionID string, expiresAt time.Time) {
    duration := time.Until(expiresAt)
    
    time.AfterFunc(duration, func() {
        ctx := context.Background()
        
        session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
        if err != nil {
            return
        }
        
        // Check if still not completed
        if session.Status == "active" {
            uc.expireCheckoutSession(ctx, session)
        }
    })
}

func (uc *CheckoutUseCase) expireCheckoutSession(ctx context.Context, session *CheckoutSession) {
    uc.log.Infof("Expiring checkout session: %s", session.ID)
    
    // Update status
    session.Status = "expired"
    session.UpdatedAt = time.Now()
    
    // Release reservations if any
    if session.ReservationID != "" {
        uc.inventoryClient.ReleaseReservation(ctx, session.ReservationID)
    }
    
    // Void payment authorization if any
    if session.PaymentAuthID != "" {
        uc.paymentClient.VoidAuthorization(ctx, session.PaymentAuthID)
    }
    
    // Save session
    uc.repo.SaveCheckoutSession(ctx, session)
    
    // Publish event
    uc.publishEvent(ctx, "checkout.expired", session)
}

func (uc *CheckoutUseCase) ExtendCheckoutSession(ctx context.Context, sessionID string, minutes int) error {
    session, err := uc.repo.GetCheckoutSession(ctx, sessionID)
    if err != nil {
        return err
    }
    
    if session.Status != "active" {
        return ErrCheckoutNotActive
    }
    
    // Extend expiry
    session.ExpiresAt = time.Now().Add(time.Duration(minutes) * time.Minute)
    session.UpdatedAt = time.Now()
    
    // Reschedule expiry
    uc.scheduleSessionExpiry(session.ID, session.ExpiresAt)
    
    return uc.repo.SaveCheckoutSession(ctx, session)
}
```

**Test Scenarios:**

- [ ] **T5.1.1** Session expires after 30 minutes
- [ ] **T5.1.2** Inventory released on expiry
- [ ] **T5.1.3** Payment authorization voided on expiry
- [ ] **T5.1.4** Session extended successfully
- [ ] **T5.1.5** User notified of impending expiry

---

## 📊 Success Criteria

- [ ] ✅ Checkout completion rate >80%
- [ ] ✅ Checkout time <5s (p95)
- [ ] ✅ Payment success rate >95%
- [ ] ✅ Order creation success >99.9%
- [ ] ✅ Rollback success rate >99%
- [ ] ✅ Zero data inconsistency
- [ ] ✅ Test coverage >85%

---

**Status:** Ready for Implementation  
**Next Steps:** Implement saga pattern and service orchestration

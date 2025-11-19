# 👤 Customer Account Management Checklist

**Service:** Customer Service  
**Created:** 2025-11-19  
**Priority:** 🟡 **Medium**

---

## 🎯 Overview

Customer account management là foundation của personalized shopping experience và customer retention.

---

## 1. Registration & Onboarding

### Requirements

- [ ] **R1.1** Email registration with verification
- [ ] **R1.2** Social login (Google, Facebook, Apple)
- [ ] **R1.3** Phone number verification (SMS OTP)
- [ ] **R1.4** Guest checkout option
- [ ] **R1.5** Welcome email series
- [ ] **R1.6** Profile completion incentive

### Implementation

```go
func (uc *CustomerUseCase) Register(ctx context.Context, req *RegisterRequest) (*Customer, error) {
    // Validate email
    if !isValidEmail(req.Email) {
        return nil, ErrInvalidEmail
    }
    
    // Check if email exists
    if uc.emailExists(req.Email) {
        return nil, ErrEmailAlreadyExists
    }
    
    // Hash password
    hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
    
    // Create customer
    customer := &Customer{
        ID:              uuid.New().String(),
        Email:           req.Email,
        HashedPassword:  string(hashedPassword),
        FirstName:       req.FirstName,
        LastName:        req.LastName,
        PhoneNumber:     req.PhoneNumber,
        EmailVerified:   false,
        Status:          "active",
        Segment:         "new_customer",
        CreatedAt:       time.Now(),
    }
    
    uc.repo.CreateCustomer(ctx, customer)
    
    // Send verification email
    uc.sendVerificationEmail(ctx, customer)
    
    // Trigger welcome email series
    uc.emailClient.TriggerDrip(ctx, "welcome_series", customer.ID)
    
    return customer, nil
}
```

---

## 2. Profile Management

### Requirements

- [ ] **R2.1** Update personal information
- [ ] **R2.2** Change password
- [ ] **R2.3** Enable/disable 2FA
- [ ] **R2.4** Manage email preferences
- [ ] **R2.5** Update communication preferences
- [ ] **R2.6** Profile picture upload

### Implementation

```go
func (uc *CustomerUseCase) UpdateProfile(ctx context.Context, customerID string, req *UpdateProfileRequest) error {
    customer, _ := uc.repo.GetCustomer(ctx, customerID)
    
    if req.FirstName != "" {
        customer.FirstName = req.FirstName
    }
    
    if req.LastName != "" {
        customer.LastName = req.LastName
    }
    
    if req.PhoneNumber != "" {
        customer.PhoneNumber = req.PhoneNumber
        customer.PhoneVerified = false  // Need re-verification
    }
    
    if req.DateOfBirth != nil {
        customer.DateOfBirth = req.DateOfBirth
    }
    
    if req.Gender != "" {
        customer.Gender = req.Gender
    }
    
    customer.UpdatedAt = time.Now()
    
    return uc.repo.UpdateCustomer(ctx, customer)
}

func (uc *CustomerUseCase) ChangePassword(ctx context.Context, customerID string, req *ChangePasswordRequest) error {
    customer, _ := uc.repo.GetCustomer(ctx, customerID)
    
    // Verify current password
    if !bcrypt.CompareHashAndPassword([]byte(customer.HashedPassword), []byte(req.CurrentPassword)) {
        return ErrCurrentPasswordIncorrect
    }
    
    // Validate new password strength
    if err := validatePasswordStrength(req.NewPassword); err != nil {
        return err
    }
    
    // Hash new password
    hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
    customer.HashedPassword = string(hashedPassword)
    
    // Invalidate all sessions
    uc.sessionStore.InvalidateUserSessions(customerID)
    
    return uc.repo.UpdateCustomer(ctx, customer)
}
```

---

## 3. Address Management

### Requirements

- [ ] **R3.1** Add multiple addresses
- [ ] **R3.2** Set default shipping address
- [ ] **R3.3** Set default billing address
- [ ] **R3.4** Edit/delete addresses
- [ ] **R3.5** Address validation
- [ ] **R3.6** Address autocomplete

### Implementation

```go
type Address struct {
    ID              string
    CustomerID      string
    Label           string  // "Home", "Work", "Other"
    FirstName       string
    LastName        string
    AddressLine1    string
    AddressLine2    string
    City            string
    State           string
    PostalCode      string
    Country         string
    PhoneNumber     string
    IsDefault       bool
    IsDefaultBilling bool
    CreatedAt       time.Time
}

func (uc *CustomerUseCase) AddAddress(ctx context.Context, req *AddAddressRequest) (*Address, error) {
    // Validate address
    if err := uc.validateAddress(req); err != nil {
        return nil, err
    }
    
    address := &Address{
        ID:           uuid.New().String(),
        CustomerID:   req.CustomerID,
        Label:        req.Label,
        AddressLine1: req.AddressLine1,
        City:         req.City,
        State:        req.State,
        PostalCode:   req.PostalCode,
        Country:      req.Country,
        IsDefault:    req.SetAsDefault,
        CreatedAt:    time.Now(),
    }
    
    // If set as default, unset other defaults
    if req.SetAsDefault {
        uc.repo.UnsetDefaultAddress(ctx, req.CustomerID)
    }
    
    return address, uc.repo.CreateAddress(ctx, address)
}
```

---

## 4. Customer Segmentation

### Requirements

- [ ] **R4.1** New customer segment
- [ ] **R4.2** Returning customer segment
- [ ] **R4.3** VIP/High-value segment (LTV > $1000)
- [ ] **R4.4** At-risk segment (no purchase in 90 days)
- [ ] **R4.5** Dormant segment (no purchase in 180 days)
- [ ] **R4.6** Custom segments

### Implementation

```go
func (uc *CustomerUseCase) CalculateSegment(ctx context.Context, customer *Customer) string {
    // Get customer metrics
    metrics := uc.getCustomerMetrics(ctx, customer.ID)
    
    // VIP customers (high LTV)
    if metrics.LifetimeValue > 1000 {
        return "vip"
    }
    
    // At-risk (no purchase in 90 days)
    if metrics.DaysSinceLastOrder > 90 && metrics.DaysSinceLastOrder <= 180 {
        return "at_risk"
    }
    
    // Dormant (no purchase in 180 days)
    if metrics.DaysSinceLastOrder > 180 {
        return "dormant"
    }
    
    // Returning customer (2+ orders)
    if metrics.OrderCount >= 2 {
        return "returning"
    }
    
    // New customer (1 order or 0 orders but registered)
    return "new_customer"
}
```

---

## 5. Wishlist & Favorites

### Requirements

- [ ] **R5.1** Add products to wishlist
- [ ] **R5.2** Move wishlist items to cart
- [ ] **R5.3** Share wishlist
- [ ] **R5.4** Price drop alerts
- [ ] **R5.5** Back-in-stock notifications
- [ ] **R5.6** Wishlist analytics

### Implementation

```go
type Wishlist struct {
    ID          string
    CustomerID  string
    Name        string
    Privacy     string  // "private", "shared"
    ShareToken  string
    Items       []WishlistItem
    CreatedAt   time.Time
}

type WishlistItem struct {
    ProductID   string
    VariantID   *string
    AddedAt     time.Time
    Notes       string
    Priority    int
}

func (uc *CustomerUseCase) AddToWishlist(ctx context.Context, req *AddToWishlistRequest) error {
    wishlist, _ := uc.getOrCreateWishlist(ctx, req.CustomerID)
    
    item := WishlistItem{
        ProductID: req.ProductID,
        VariantID: req.VariantID,
        AddedAt:   time.Now(),
        Notes:     req.Notes,
    }
    
    wishlist.Items = append(wishlist.Items, item)
    
    // Set price alert
    uc.priceAlertClient.CreateAlert(ctx, &PriceAlertRequest{
        CustomerID: req.CustomerID,
        ProductID:  req.ProductID,
    })
    
    return uc.repo.UpdateWishlist(ctx, wishlist)
}
```

---

## 6. Order History & Tracking

### Requirements

- [ ] **R6.1** View all orders
- [ ] **R6.2** Filter orders (status, date range)
- [ ] **R6.3** Order details view
- [ ] **R6.4** Track shipment
- [ ] **R6.5** Download invoice
- [ ] **R6.6** Reorder previous orders

### Implementation

```go
func (uc *CustomerUseCase) GetOrderHistory(ctx context.Context, customerID string, filter *OrderFilter) ([]*OrderSummary, error) {
    orders, err := uc.orderClient.GetCustomerOrders(ctx, &GetOrdersRequest{
        CustomerID: customerID,
        Status:     filter.Status,
        FromDate:   filter.FromDate,
        ToDate:     filter.ToDate,
        Limit:      filter.Limit,
        Offset:     filter.Offset,
    })
    
    if err != nil {
        return nil, err
    }
    
    summaries := []*OrderSummary{}
    for _, order := range orders {
        summaries = append(summaries, &OrderSummary{
            OrderID:        order.ID,
            OrderNumber:    order.OrderNumber,
            OrderDate:      order.CreatedAt,
            Status:         order.Status,
            Total:          order.Total,
            ItemCount:      len(order.Items),
            TrackingNumber: order.TrackingNumber,
        })
    }
    
    return summaries, nil
}

func (uc *CustomerUseCase) ReorderPreviousOrder(ctx context.Context, orderID, customerID string) (*Cart, error) {
    // Get original order
    order, err := uc.orderClient.GetOrder(ctx, orderID)
    if err != nil {
        return nil, err
    }
    
    // Verify order belongs to customer
    if order.CustomerID != customerID {
        return nil, ErrUnauthorized
    }
    
    // Create cart from order items
    cart, _ := uc.cartClient.CreateCart(ctx, customerID)
    
    for _, item := range order.Items {
        // Check if product still available
        product, err := uc.catalogClient.GetProduct(ctx, item.ProductID)
        if err != nil || !product.IsActive {
            continue  // Skip unavailable products
        }
        
        uc.cartClient.AddToCart(ctx, &AddToCartRequest{
            CartID:    cart.ID,
            ProductID: item.ProductID,
            VariantID: item.VariantID,
            Quantity:  item.Quantity,
        })
    }
    
    return cart, nil
}
```

---

## 7. Account Deletion (GDPR)

### Requirements

- [ ] **R7.1** Request account deletion
- [ ] **R7.2** Retain necessary data (orders for accounting)
- [ ] **R7.3** Anonymize personal data
- [ ] **R7.4** Delete PII
- [ ] **R7.5** Confirmation email
- [ ] **R7.6** Grace period (30 days)

### Implementation

```go
func (uc *CustomerUseCase) RequestAccountDeletion(ctx context.Context, customerID string) error {
    customer, _ := uc.repo.GetCustomer(ctx, customerID)
    
    // Set deletion scheduled date (30 days grace period)
    customer.DeletionScheduledAt = timePtr(time.Now().Add(30 * 24 * time.Hour))
    customer.Status = "pending_deletion"
    
    uc.repo.UpdateCustomer(ctx, customer)
    
    // Send confirmation email
    uc.emailClient.Send(ctx, &Email{
        To:       customer.Email,
        Template: "account_deletion_scheduled",
        Data: map[string]interface{}{
            "name": customer.FirstName,
            "deletion_date": customer.DeletionScheduledAt,
        },
    })
    
    // Schedule deletion job
    uc.scheduler.Schedule(customer.ID, *customer.DeletionScheduledAt, "delete_customer")
    
    return nil
}

func (uc *CustomerUseCase) ProcessAccountDeletion(ctx context.Context, customerID string) error {
    // Anonymize orders (keep for accounting/legal)
    uc.orderClient.AnonymizeOrders(ctx, customerID)
    
    // Delete customer data
    uc.repo.DeleteCustomer(ctx, customerID)
    
    // Delete addresses
    uc.repo.DeleteAddresses(ctx, customerID)
    
    // Delete wishlists
    uc.repo.DeleteWishlists(ctx, customerID)
    
    // Delete payment tokens
    uc.paymentClient.DeleteTokens(ctx, customerID)
    
    // Log deletion
    uc.auditLogger.Log("customer.deleted", customerID, "gdpr_request")
    
    return nil
}
```

---

## 📊 Success Criteria

- [ ] ✅ Registration flow <2min
- [ ] ✅ Email verification rate >80%
- [ ] ✅ Profile completion rate >60%
- [ ] ✅ Address management error-free
- [ ] ✅ GDPR compliance 100%

---

**Status:** Ready for Implementation

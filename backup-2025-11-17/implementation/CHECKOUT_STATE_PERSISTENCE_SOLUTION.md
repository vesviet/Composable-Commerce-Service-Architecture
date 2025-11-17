# Checkout State Persistence Solution

> **Problem**: Customer đã input đầy đủ thông tin checkout nhưng chưa place order, nếu reload page sẽ mất thông tin đã input  
> **Solution**: Draft Order + Checkout Session  
> **Status**: ✅ **Implementation Completed**  
> **Last Updated**: December 2024

---

## 📋 Problem Statement

### Current Flow Issues
1. **CheckoutCart** tạo order ngay với status `"pending"`
2. Customer input address, payment method nhưng chưa confirm payment
3. Nếu reload page → **Mất tất cả thông tin đã input**
4. Customer phải nhập lại từ đầu → **Poor UX**

### Use Cases
- Customer điền form checkout, đang chờ payment gateway redirect
- Customer reload page do network issue
- Customer quay lại checkout page sau khi navigate away
- Customer đang review order trước khi confirm payment

---

## 🎯 Solution Overview

### Approach: **Draft Order + Checkout Session**

**Two-Phase Checkout**:
1. **Phase 1 - Draft Order**: Tạo order với status `"draft"` khi customer bắt đầu checkout
2. **Phase 2 - Confirm Order**: Update order status `"draft" → "pending"` khi payment confirmed

**Benefits**:
- ✅ Persist checkout state in database
- ✅ Survive page reloads
- ✅ Track abandoned checkouts
- ✅ Resume checkout from any step
- ✅ Analytics on checkout abandonment

---

## 🏗️ Architecture

### 1. Draft Order Status

#### New Order Status: `"draft"`
```go
// Order statuses
const (
    OrderStatusDraft     = "draft"      // NEW: Checkout in progress
    OrderStatusPending   = "pending"    // Payment pending
    OrderStatusConfirmed = "confirmed"   // Payment confirmed
    OrderStatusProcessing = "processing"
    // ... other statuses
)
```

#### Draft Order Characteristics
- **Status**: `"draft"`
- **PaymentStatus**: `"draft"` (not yet submitted for payment)
- **ExpiresAt**: 30 minutes (same as pending orders)
- **Can be updated**: Address, payment method, notes
- **Cannot be processed**: Until status changes to `"pending"`

---

### 2. Checkout Session Table

#### New Table: `checkout_sessions`
```sql
CREATE TABLE checkout_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id VARCHAR(36) NOT NULL,
    current_step INTEGER DEFAULT 1,
    -- Checkout state
    shipping_address JSONB,
    billing_address JSONB,
    payment_method VARCHAR(50),
    shipping_method_id VARCHAR(36),
    promotion_codes TEXT[],
    loyalty_points_to_use INTEGER DEFAULT 0,
    notes TEXT,
    -- Metadata
    metadata JSONB,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_checkout_sessions_session_id (session_id),
    INDEX idx_checkout_sessions_order_id (order_id),
    INDEX idx_checkout_sessions_user_id (user_id),
    INDEX idx_checkout_sessions_expires_at (expires_at)
);
```

#### Model Structure
```go
type CheckoutSession struct {
    ID                int64                  `gorm:"primaryKey;autoIncrement"`
    SessionID         string                 `gorm:"uniqueIndex;size:100;not null"`
    OrderID           int64                  `gorm:"index;not null"`
    UserID            string                 `gorm:"index;type:varchar(36);not null"`
    CurrentStep       int32                  `gorm:"default:1"`
    ShippingAddress   map[string]interface{} `gorm:"type:jsonb"`
    BillingAddress    map[string]interface{} `gorm:"type:jsonb"`
    PaymentMethod     string                 `gorm:"size:50"`
    ShippingMethodID  *string                `gorm:"type:varchar(36)"`
    PromotionCodes    []string               `gorm:"type:text[]"`
    LoyaltyPointsToUse int32                 `gorm:"default:0"`
    Notes             string                 `gorm:"type:text"`
    Metadata          map[string]interface{} `gorm:"type:jsonb"`
    ExpiresAt         *time.Time
    CreatedAt         time.Time              `gorm:"index"`
    UpdatedAt         time.Time
    
    Order *Order `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
}
```

---

## 🔄 Updated Checkout Flow

### Phase 1: Start Checkout (Create Draft Order)

#### New Method: `StartCheckout`
```go
// StartCheckout creates a draft order and checkout session
func (uc *CartUsecase) StartCheckout(ctx context.Context, req *StartCheckoutRequest) (*CheckoutSession, error) {
    // 1. Get cart
    cart, err := uc.GetCart(ctx, req.SessionID, req.UserID, "")
    if err != nil {
        return nil, err
    }
    
    if len(cart.Items) == 0 {
        return nil, fmt.Errorf("cart is empty")
    }
    
    // 2. Check if draft order already exists
    existingSession, err := uc.checkoutSessionRepo.FindBySessionID(ctx, req.SessionID)
    if err == nil && existingSession != nil {
        // Return existing session
        return existingSession, nil
    }
    
    // 3. Create draft order
    orderReq := &CreateOrderRequest{
        UserID:          *req.UserID,
        Items:           convertCartItemsToOrderItems(cart.Items),
        Status:          "draft",  // NEW: Draft status
        PaymentStatus:   "draft",  // NEW: Draft payment status
    }
    
    draftOrder, err := uc.orderUc.CreateOrder(ctx, orderReq)
    if err != nil {
        return nil, err
    }
    
    // 4. Create checkout session
    checkoutSession := &CheckoutSession{
        SessionID:   req.SessionID,
        OrderID:     draftOrder.ID,
        UserID:      *req.UserID,
        CurrentStep: 1,
        ExpiresAt:   time.Now().Add(30 * time.Minute),
    }
    
    createdSession, err := uc.checkoutSessionRepo.Create(ctx, checkoutSession)
    if err != nil {
        // Rollback: delete draft order
        uc.orderUc.CancelOrder(ctx, &CancelOrderRequest{OrderID: draftOrder.ID})
        return nil, err
    }
    
    return createdSession, nil
}
```

---

### Phase 2: Update Checkout State

#### New Method: `UpdateCheckoutState`
```go
// UpdateCheckoutState updates checkout session with customer input
func (uc *CartUsecase) UpdateCheckoutState(ctx context.Context, req *UpdateCheckoutStateRequest) (*CheckoutSession, error) {
    // 1. Get checkout session
    session, err := uc.checkoutSessionRepo.FindBySessionID(ctx, req.SessionID)
    if err != nil {
        return nil, fmt.Errorf("checkout session not found: %w", err)
    }
    
    // 2. Update session fields
    if req.ShippingAddress != nil {
        session.ShippingAddress = convertToJSONB(req.ShippingAddress)
    }
    if req.BillingAddress != nil {
        session.BillingAddress = convertToJSONB(req.BillingAddress)
    }
    if req.PaymentMethod != "" {
        session.PaymentMethod = req.PaymentMethod
    }
    if req.ShippingMethodID != nil {
        session.ShippingMethodID = req.ShippingMethodID
    }
    if req.CurrentStep > 0 {
        session.CurrentStep = req.CurrentStep
    }
    
    // 3. Update draft order addresses (if provided)
    if req.ShippingAddress != nil || req.BillingAddress != nil {
        order, err := uc.orderUc.GetOrder(ctx, session.OrderID)
        if err == nil {
            updateReq := &UpdateOrderRequest{
                OrderID:          session.OrderID,
                ShippingAddress:  req.ShippingAddress,
                BillingAddress:   req.BillingAddress,
            }
            uc.orderUc.UpdateOrder(ctx, updateReq)
        }
    }
    
    // 4. Save session
    updatedSession, err := uc.checkoutSessionRepo.Update(ctx, session)
    if err != nil {
        return nil, err
    }
    
    return updatedSession, nil
}
```

---

### Phase 3: Get Checkout State (Resume Checkout)

#### New Method: `GetCheckoutState`
```go
// GetCheckoutState retrieves checkout session for resume
func (uc *CartUsecase) GetCheckoutState(ctx context.Context, sessionID string, userID *string) (*CheckoutSession, *Order, error) {
    // 1. Get checkout session
    session, err := uc.checkoutSessionRepo.FindBySessionID(ctx, sessionID)
    if err != nil {
        return nil, nil, fmt.Errorf("checkout session not found: %w", err)
    }
    
    // 2. Validate user
    if userID != nil && session.UserID != *userID {
        return nil, nil, fmt.Errorf("checkout session does not belong to user")
    }
    
    // 3. Check expiration
    if session.ExpiresAt != nil && time.Now().After(*session.ExpiresAt) {
        return nil, nil, fmt.Errorf("checkout session expired")
    }
    
    // 4. Get draft order
    order, err := uc.orderUc.GetOrder(ctx, session.OrderID)
    if err != nil {
        return nil, nil, err
    }
    
    // 5. Validate order is still draft
    if order.Status != "draft" {
        return nil, nil, fmt.Errorf("order is no longer in draft status")
    }
    
    return session, order, nil
}
```

---

### Phase 4: Confirm Checkout (Submit for Payment)

#### Updated Method: `ConfirmCheckout`
```go
// ConfirmCheckout confirms draft order and submits for payment
func (uc *CartUsecase) ConfirmCheckout(ctx context.Context, req *ConfirmCheckoutRequest) (*Order, error) {
    // 1. Get checkout session
    session, err := uc.checkoutSessionRepo.FindBySessionID(ctx, req.SessionID)
    if err != nil {
        return nil, fmt.Errorf("checkout session not found: %w", err)
    }
    
    // 2. Get draft order
    order, err := uc.orderUc.GetOrder(ctx, session.OrderID)
    if err != nil {
        return nil, err
    }
    
    // 3. Validate order is draft
    if order.Status != "draft" {
        return nil, fmt.Errorf("order is not in draft status")
    }
    
    // 4. Final validation
    if session.ShippingAddress == nil {
        return nil, fmt.Errorf("shipping address is required")
    }
    if session.PaymentMethod == "" {
        return nil, fmt.Errorf("payment method is required")
    }
    
    // 5. Update order with final checkout data
    updateReq := &UpdateOrderRequest{
        OrderID:          session.OrderID,
        ShippingAddress:  convertFromJSONB(session.ShippingAddress),
        BillingAddress:   convertFromJSONB(session.BillingAddress),
        PaymentMethod:    session.PaymentMethod,
        Notes:            session.Notes,
    }
    updatedOrder, err := uc.orderUc.UpdateOrder(ctx, updateReq)
    if err != nil {
        return nil, err
    }
    
    // 6. Update order status: draft → pending
    statusReq := &UpdateOrderStatusRequest{
        OrderID: session.OrderID,
        Status:  "pending",
        Reason:  "Checkout confirmed, awaiting payment",
    }
    confirmedOrder, err := uc.orderUc.UpdateOrderStatus(ctx, statusReq)
    if err != nil {
        return nil, err
    }
    
    // 7. Update payment status: draft → pending
    // (This happens when payment is processed)
    
    // 8. Clear checkout session
    uc.checkoutSessionRepo.DeleteBySessionID(ctx, req.SessionID)
    
    // 9. Clear cart
    uc.ClearCart(ctx, req.SessionID, req.UserID, "")
    
    // 10. Publish event
    if uc.eventPublisher != nil {
        event := &events.CheckoutConfirmedEvent{
            SessionID:   req.SessionID,
            OrderID:     confirmedOrder.ID,
            OrderNumber: confirmedOrder.OrderNumber,
            Timestamp:   time.Now(),
        }
        uc.eventPublisher.PublishCheckoutConfirmed(ctx, event)
    }
    
    return confirmedOrder, nil
}
```

---

## 📊 API Changes

### New Endpoints

#### 1. Start Checkout
```protobuf
// Start checkout process (creates draft order)
rpc StartCheckout(StartCheckoutRequest) returns (StartCheckoutResponse) {
    option (google.api.http) = {
        post: "/api/v1/cart/checkout/start"
        body: "*"
    };
}

message StartCheckoutRequest {
    string session_id = 1;
    string user_id = 2;
}

message StartCheckoutResponse {
    CheckoutSession session = 1;
    Order draft_order = 2;
}
```

#### 2. Update Checkout State
```protobuf
// Update checkout state (save progress)
rpc UpdateCheckoutState(UpdateCheckoutStateRequest) returns (UpdateCheckoutStateResponse) {
    option (google.api.http) = {
        put: "/api/v1/cart/checkout/state"
        body: "*"
    };
}

message UpdateCheckoutStateRequest {
    string session_id = 1;
    int32 current_step = 2;
    OrderAddress shipping_address = 3;
    OrderAddress billing_address = 4;
    string payment_method = 5;
    string shipping_method_id = 6;
    repeated string promotion_codes = 7;
    int32 loyalty_points_to_use = 8;
    string notes = 9;
}

message UpdateCheckoutStateResponse {
    CheckoutSession session = 1;
    bool success = 2;
}
```

#### 3. Get Checkout State
```protobuf
// Get checkout state (resume checkout)
rpc GetCheckoutState(GetCheckoutStateRequest) returns (GetCheckoutStateResponse) {
    option (google.api.http) = {
        get: "/api/v1/cart/checkout/state"
    };
}

message GetCheckoutStateRequest {
    string session_id = 1;
    string user_id = 2;
}

message GetCheckoutStateResponse {
    CheckoutSession session = 1;
    Order draft_order = 2;
    bool found = 3;
}
```

#### 4. Confirm Checkout
```protobuf
// Confirm checkout (submit for payment)
rpc ConfirmCheckout(ConfirmCheckoutRequest) returns (ConfirmCheckoutResponse) {
    option (google.api.http) = {
        post: "/api/v1/cart/checkout/confirm"
        body: "*"
    };
}

message ConfirmCheckoutRequest {
    string session_id = 1;
    string user_id = 2;
}

message ConfirmCheckoutResponse {
    Order order = 1;
    bool success = 2;
    string message = 3;
}
```

---

## 🎨 Frontend Integration

### Updated Checkout Flow

#### 1. On Checkout Page Load
```typescript
// Check for existing checkout session
const { data: checkoutState } = useQuery({
    queryKey: ['checkout-state', sessionId],
    queryFn: async () => {
        try {
            const response = await cartApi.getCheckoutState(sessionId);
            if (response.found) {
                // Resume checkout
                return response;
            }
        } catch (error) {
            // No existing session, start new checkout
        }
        return null;
    },
});

// If checkout state exists, restore form
useEffect(() => {
    if (checkoutState?.session) {
        setShippingAddress(checkoutState.session.shipping_address);
        setBillingAddress(checkoutState.session.billing_address);
        setPaymentMethod(checkoutState.session.payment_method);
        setCurrentStep(checkoutState.session.current_step);
    }
}, [checkoutState]);
```

#### 2. Start Checkout
```typescript
// Start checkout when user clicks "Checkout" button
const startCheckoutMutation = useMutation({
    mutationFn: async () => {
        return cartApi.startCheckout({
            session_id: sessionId,
            user_id: userId,
        });
    },
    onSuccess: (data) => {
        // Store session ID
        localStorage.setItem('checkout_session_id', data.session.session_id);
        // Navigate to checkout page
        router.push('/checkout');
    },
});
```

#### 3. Save Checkout Progress
```typescript
// Auto-save checkout state on form changes
const debouncedSave = useDebouncedCallback(async () => {
    if (checkoutSessionId) {
        await cartApi.updateCheckoutState({
            session_id: checkoutSessionId,
            current_step: currentStep,
            shipping_address: shippingAddress,
            billing_address: billingAddress,
            payment_method: paymentMethod,
        });
    }
}, 1000); // Debounce 1 second

// Call on form changes
useEffect(() => {
    if (shippingAddress || billingAddress || paymentMethod) {
        debouncedSave();
    }
}, [shippingAddress, billingAddress, paymentMethod]);
```

#### 4. Confirm Checkout
```typescript
// Confirm checkout and submit for payment
const confirmCheckoutMutation = useMutation({
    mutationFn: async () => {
        return cartApi.confirmCheckout({
            session_id: checkoutSessionId,
            user_id: userId,
        });
    },
    onSuccess: (data) => {
        // Redirect to payment page
        router.push(`/payment/${data.order.id}`);
    },
});
```

---

## 🔄 State Machine

### Order Status Transitions
```
[draft] → [pending] → [confirmed] → [processing] → ...
   ↑
   └── Can be updated/cancelled
```

### Checkout Session Lifecycle
```
[created] → [in_progress] → [confirmed] → [deleted]
     ↑
     └── Can be resumed
```

---

## 🧹 Cleanup & Expiration

### Draft Order Cleanup
```go
// Cleanup expired draft orders (run as cron job)
func (uc *OrderUsecase) CleanupExpiredDraftOrders(ctx context.Context) error {
    // Find draft orders older than 30 minutes
    expiredDrafts, err := uc.orderRepo.FindExpiredDrafts(ctx, 30*time.Minute)
    if err != nil {
        return err
    }
    
    for _, order := range expiredDrafts {
        // Cancel draft order
        uc.CancelOrder(ctx, &CancelOrderRequest{
            OrderID: order.ID,
            Reason:  "Draft order expired",
        })
        
        // Delete checkout session
        uc.checkoutSessionRepo.DeleteByOrderID(ctx, order.ID)
    }
    
    return nil
}
```

### Checkout Session Cleanup
```go
// Cleanup expired checkout sessions
func (uc *CartUsecase) CleanupExpiredCheckoutSessions(ctx context.Context) error {
    expiredSessions, err := uc.checkoutSessionRepo.FindExpired(ctx, 30*time.Minute)
    if err != nil {
        return err
    }
    
    for _, session := range expiredSessions {
        // Delete session
        uc.checkoutSessionRepo.DeleteBySessionID(ctx, session.SessionID)
        
        // Cancel associated draft order
        uc.orderUc.CancelOrder(ctx, &CancelOrderRequest{
            OrderID: session.OrderID,
            Reason:  "Checkout session expired",
        })
    }
    
    return nil
}
```

---

## 📈 Analytics & Metrics

### New Metrics
- `checkout_sessions_created_total` - Total checkout sessions created
- `checkout_sessions_resumed_total` - Total checkout sessions resumed
- `checkout_sessions_abandoned_total` - Total abandoned checkouts
- `checkout_duration_seconds` - Time from start to confirm
- `checkout_abandonment_rate` - Percentage of abandoned checkouts

### Abandonment Tracking
- Track when customer starts checkout but doesn't complete
- Track which step customers abandon most
- Track time to abandonment
- Send recovery emails for abandoned checkouts

---

## ✅ Benefits

### User Experience
- ✅ **No Data Loss**: Checkout state persists across reloads
- ✅ **Resume Checkout**: Can resume from any step
- ✅ **Auto-save**: Progress saved automatically
- ✅ **Better UX**: No need to re-enter information

### Business Benefits
- ✅ **Abandonment Tracking**: Track where customers drop off
- ✅ **Recovery**: Send recovery emails for abandoned checkouts
- ✅ **Analytics**: Better insights into checkout behavior
- ✅ **Conversion**: Higher conversion rate from reduced friction

### Technical Benefits
- ✅ **State Management**: Centralized checkout state
- ✅ **Data Integrity**: Draft orders in database
- ✅ **Scalability**: Can handle high checkout volumes
- ✅ **Resilience**: Survives server restarts

---

## 🚀 Implementation Steps

### Phase 1: Database Changes
1. ✅ Add `"draft"` status to orders
2. ✅ Create `checkout_sessions` table
3. ✅ Add migration scripts

### Phase 2: Backend Changes
1. ✅ Implement `StartCheckout` method
2. ✅ Implement `UpdateCheckoutState` method
3. ✅ Implement `GetCheckoutState` method
4. ✅ Implement `ConfirmCheckout` method
5. ✅ Add cleanup jobs

### Phase 3: API Changes
1. ✅ Add new gRPC endpoints
2. ✅ Update OpenAPI spec
3. ✅ Add validation

### Phase 4: Frontend Changes
1. ✅ Update checkout page to use new APIs
2. ✅ Add auto-save functionality
3. ✅ Add resume checkout logic
4. ✅ Update payment flow

### Phase 5: Testing & Monitoring
1. ✅ Unit tests
2. ✅ Integration tests
3. ✅ Load testing
4. ✅ Monitor metrics

---

## 📝 Migration Script

```sql
-- Migration: Add draft status and checkout_sessions table

-- 1. Update order status constraint to include 'draft'
ALTER TABLE orders 
    DROP CONSTRAINT IF EXISTS chk_orders_status;

ALTER TABLE orders 
    ADD CONSTRAINT chk_orders_status 
    CHECK (status IN (
        'draft', 'pending', 'confirmed', 'processing', 
        'shipped', 'delivered', 'cancelled', 'failed', 'refunded'
    ));

-- 2. Update payment_status constraint to include 'draft'
ALTER TABLE orders 
    DROP CONSTRAINT IF EXISTS chk_orders_payment_status;

ALTER TABLE orders 
    ADD CONSTRAINT chk_orders_payment_status 
    CHECK (payment_status IN (
        'draft', 'pending', 'processing', 'authorized', 
        'captured', 'failed', 'refunded', 'cancelled'
    ));

-- 3. Create checkout_sessions table
CREATE TABLE IF NOT EXISTS checkout_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id VARCHAR(36) NOT NULL,
    current_step INTEGER DEFAULT 1,
    shipping_address JSONB,
    billing_address JSONB,
    payment_method VARCHAR(50),
    shipping_method_id VARCHAR(36),
    promotion_codes TEXT[],
    loyalty_points_to_use INTEGER DEFAULT 0,
    notes TEXT,
    metadata JSONB,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create indexes
CREATE INDEX idx_checkout_sessions_session_id ON checkout_sessions(session_id);
CREATE INDEX idx_checkout_sessions_order_id ON checkout_sessions(order_id);
CREATE INDEX idx_checkout_sessions_user_id ON checkout_sessions(user_id);
CREATE INDEX idx_checkout_sessions_expires_at ON checkout_sessions(expires_at);

-- 5. Create trigger for updated_at
CREATE TRIGGER update_checkout_sessions_updated_at BEFORE UPDATE ON checkout_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## 📚 Related Documentation

- [Cart Service Logic](./CART_SERVICE_LOGIC.md)
- [Order Service Logic](./ORDER_SERVICE_LOGIC.md)
- [Cart & Order Data Structure Review](./CART_ORDER_DATA_STRUCTURE_REVIEW.md)


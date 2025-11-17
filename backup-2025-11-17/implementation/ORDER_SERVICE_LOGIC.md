# Order Service - Logic Implementation Review

> **Service**: Order Service  
> **Last Updated**: December 2024  
> **Status**: Implementation Complete

---

## 📋 Overview

Order Service quản lý toàn bộ vòng đời của đơn hàng từ khi tạo đến khi hoàn thành. Service này tích hợp với nhiều services khác để xử lý inventory, payment, shipping, và notifications.

---

## 🏗️ Architecture

### Service Structure
```
order/
├── internal/
│   ├── biz/              # Business logic layer
│   │   ├── order.go      # Order usecase
│   │   ├── cart.go       # Cart usecase
│   │   └── biz.go        # Domain models & interfaces
│   ├── service/         # gRPC/HTTP handlers
│   │   ├── order.go
│   │   └── cart.go
│   ├── data/             # Data access layer
│   └── client/            # External service clients
│       └── payment_client.go
```

### Key Dependencies
- **Product Service**: Validate products, get product details
- **Warehouse Service**: Check stock, reserve inventory
- **Payment Service**: Process payments
- **Pricing Service**: Calculate prices with discounts
- **Notification Service**: Send order notifications

---

## 🔄 Core Business Logic

### 1. Order Creation Flow

#### CreateOrder Method
**Location**: `order/internal/biz/order.go:64`

**Flow**:
1. **Validate User** (commented out - TODO: update UserService to use UUID)
2. **Validate Products & Calculate Totals**
   - Loop through items
   - Get product from ProductService
   - Check stock availability via WarehouseInventoryService
   - Calculate total amount: `product.Price * quantity`
3. **Create Order Entity**
   - Status: `"pending"`
   - PaymentStatus: `"pending"`
   - Set expiration: 30 minutes from now
   - Currency: `"USD"`
4. **Create Order Items**
   - For each item, create OrderItem with:
     - ProductID, ProductSKU, ProductName
     - Quantity, UnitPrice, TotalPrice
     - WarehouseID (optional)
5. **Save Order**
   - Use repository `Create` method
   - Track Prometheus metrics
6. **Create Status History**
   - Record initial status: `"" -> "pending"`
7. **Send Notification**
   - Publish `order.created` event
   - Send notification via NotificationService
8. **Publish Events**
   - `OrderCreatedEvent` với đầy đủ order details

**Key Code**:
```go
func (uc *OrderUsecase) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    // Validate products and calculate totals
    var totalAmount float64
    for _, item := range req.Items {
        product, err := uc.productService.GetProduct(ctx, item.ProductID)
        if err != nil {
            return nil, fmt.Errorf("product %d not found: %w", item.ProductID, err)
        }
        
        // Check stock availability
        if item.WarehouseID != nil {
            if err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, *item.WarehouseID, item.Quantity); err != nil {
                return nil, fmt.Errorf("insufficient stock for product %s: %w", item.ProductSKU, err)
            }
        }
        
        totalAmount += product.Price * float64(item.Quantity)
    }
    
    // Create order with expiration
    expiresAt := time.Now().Add(30 * time.Minute)
    order.ExpiresAt = &expiresAt
    
    // ... save and publish events
}
```

---

### 2. Order Status Management

#### Status Transitions
**Location**: `order/internal/biz/order.go:822`

**Valid Transitions**:
```go
validTransitions := map[string][]string{
    "pending":    {"confirmed", "cancelled", "failed"},
    "confirmed":  {"processing", "cancelled"},
    "processing": {"shipped", "cancelled"},
    "shipped":    {"delivered", "cancelled"},
    "delivered":  {"refunded"},
    "cancelled":  {}, // No transitions from cancelled
    "failed":     {"pending"}, // Can retry failed orders
    "refunded":   {}, // No transitions from refunded
}
```

#### UpdateOrderStatus Method
**Location**: `order/internal/biz/order.go:232`

**Flow**:
1. Get current order
2. Validate status transition
3. Update order status
4. Set timestamps:
   - `CompletedAt` for "completed"/"delivered"
   - `CancelledAt` for "cancelled"
5. Save order
6. Create status history
7. Send notification
8. Publish events:
   - `OrderStatusChangedEvent`
   - `OrderCompletedEvent` (if status is "completed")

**Key Code**:
```go
func (uc *OrderUsecase) UpdateOrderStatus(ctx context.Context, req *UpdateOrderStatusRequest) (*Order, error) {
    // Validate status transition
    if !uc.isValidStatusTransition(order.Status, req.Status) {
        return nil, ErrInvalidStatus
    }
    
    oldStatus := order.Status
    order.Status = req.Status
    
    // Set completion/cancellation timestamps
    now := time.Now()
    switch req.Status {
    case "completed", "delivered":
        order.CompletedAt = &now
    case "cancelled":
        order.CancelledAt = &now
    }
    
    // ... save, create history, publish events
}
```

---

### 3. Order Cancellation

#### CancelOrder Method
**Location**: `order/internal/biz/order.go:338`

**Flow**:
1. Get current order
2. Validate cancellation:
   - Cannot cancel if already cancelled
   - Cannot cancel if completed/delivered
3. **Release Stock Reservations**
   - Loop through items
   - Release each reservation via WarehouseInventoryService
4. Update order status to "cancelled"
5. Set `CancelledAt` timestamp
6. Save order
7. Create status history
8. Send notification
9. Publish `OrderCancelledEvent`

**Key Code**:
```go
func (uc *OrderUsecase) CancelOrder(ctx context.Context, req *CancelOrderRequest) (*Order, error) {
    // Check if order can be cancelled
    if order.Status == "cancelled" {
        return nil, fmt.Errorf("order is already cancelled")
    }
    if order.Status == "completed" || order.Status == "delivered" {
        return nil, fmt.Errorf("cannot cancel completed order")
    }
    
    // Release stock reservations
    for _, item := range order.Items {
        if item.ReservationID != nil {
            uc.warehouseInventoryService.ReleaseReservation(ctx, *item.ReservationID)
        }
    }
    
    // ... update status, save, publish events
}
```

---

### 4. Order Processing (Internal)

#### ProcessOrder Method
**Location**: `order/internal/biz/order.go:474`

**Purpose**: Internal method để process order sau khi payment thành công

**Flow**:
1. Get order
2. **Reserve Stock for All Items**
   - Loop through items
   - Reserve stock via WarehouseInventoryService
   - Store ReservationID in each item
3. Update order status to "processing"
4. Create status history: `"pending" -> "processing"`

**Key Code**:
```go
func (uc *OrderUsecase) ProcessOrder(ctx context.Context, orderID int64) (*Order, error) {
    // Reserve stock for all items
    for _, item := range order.Items {
        if item.WarehouseID != nil {
            reservation, err := uc.warehouseInventoryService.ReserveStock(ctx, item.ProductID, *item.WarehouseID, item.Quantity)
            if err != nil {
                return nil, fmt.Errorf("failed to reserve stock for item %s: %w", item.ProductSKU, err)
            }
            item.ReservationID = &reservation.ID
        }
    }
    
    // Update order status to processing
    order.Status = "processing"
    // ... save and create history
}
```

---

### 5. Payment Integration

#### AddPayment Method
**Location**: `order/internal/biz/order.go:421`

**Flow**:
1. Get order
2. Create payment record:
   - OrderID, PaymentID
   - PaymentMethod, PaymentProvider
   - Amount, Currency
   - Status: "pending"
   - TransactionID, GatewayResponse
3. Save payment via OrderPaymentRepo
4. Update order PaymentStatus to "processing"

**Payment Client Integration**:
- **Location**: `order/internal/client/payment_client.go`
- **Methods**:
  - `ProcessPayment`: POST `/v1/payments`
  - `GetPaymentStatus`: GET `/v1/payments/{id}/status`
- **Features**:
  - Circuit breaker pattern
  - HTTP client with timeout
  - Error handling

**Key Code**:
```go
func (uc *OrderUsecase) AddPayment(ctx context.Context, req *AddPaymentRequest) (*OrderPayment, error) {
    // Create payment record
    modelPayment := &model.OrderPayment{
        OrderID:         req.OrderID,
        PaymentID:      req.PaymentID,
        PaymentMethod:   req.PaymentMethod,
        PaymentProvider: req.PaymentProvider,
        Amount:          req.Amount,
        Currency:        req.Currency,
        Status:          "pending",
        TransactionID:   req.TransactionID,
        GatewayResponse: req.GatewayResponse,
    }
    
    // Save payment
    createdModelPayment, err := uc.orderPaymentRepo.Create(ctx, modelPayment)
    
    // Update order payment status
    order.PaymentStatus = "processing"
    // ... save order
}
```

---

## 📊 Domain Models

### Order Entity
```go
type Order struct {
    ID                int64
    OrderNumber       string
    UserID            string  // UUID
    Status            string
    TotalAmount       float64
    Currency          string
    PaymentMethod     string
    PaymentStatus     string
    Notes             string
    Metadata          map[string]interface{}
    CreatedAt         time.Time
    UpdatedAt         time.Time
    ExpiresAt         *time.Time  // 30 minutes from creation
    CancelledAt       *time.Time
    CompletedAt       *time.Time
    Items             []*OrderItem
    ShippingAddress   *OrderAddress
    BillingAddress    *OrderAddress
    StatusHistory     []*OrderStatusHistory
    Payments          []*OrderPayment
}
```

### OrderItem Entity
```go
type OrderItem struct {
    ID             int64
    OrderID        int64
    ProductID      string  // UUID
    ProductSKU     string
    ProductName    string
    Quantity       int32
    UnitPrice      float64
    TotalPrice     float64
    DiscountAmount float64
    TaxAmount      float64
    WarehouseID    *string  // UUID (optional)
    ReservationID  *int64   // Stock reservation ID
    Metadata       map[string]interface{}
}
```

---

## 🔔 Events Published

### OrderCreatedEvent
- **Topic**: `order.created`
- **Payload**:
  - OrderID, OrderNumber, UserID
  - TotalAmount, Currency
  - PaymentMethod
  - Items (array)
  - Timestamp, Metadata

### OrderStatusChangedEvent
- **Topic**: `order.status_changed`
- **Payload**:
  - OrderID, OrderNumber, UserID
  - OldStatus, NewStatus
  - Reason, ChangedBy
  - Timestamp

### OrderCompletedEvent
- **Topic**: `order.completed`
- **Payload**:
  - OrderID, OrderNumber, UserID
  - TotalAmount, Currency
  - Timestamp

### OrderCancelledEvent
- **Topic**: `order.cancelled`
- **Payload**:
  - OrderID, OrderNumber, UserID
  - Reason, CancelledBy
  - Timestamp

---

## 📈 Metrics & Observability

### Prometheus Metrics
- `OrderOperationDuration`: Operation duration by type
- `OrderOperationsTotal`: Total operations by type and result
- `OrdersCreatedTotal`: Orders created by status
- `OrderValueTotal`: Order value by currency and status
- `OrderValueHistogram`: Order value distribution
- `PendingOrders`: Current pending orders gauge
- `OrdersCompletedTotal`: Completed orders counter
- `OrdersCancelledTotal`: Cancelled orders by reason
- `OrderStatusChangesTotal`: Status changes by from/to status

---

## 🔐 Business Rules

### Order Expiration
- Orders expire **30 minutes** after creation
- Expiration time stored in `ExpiresAt` field
- Used to clean up abandoned orders

### Stock Reservation
- Stock is reserved when order status changes to "processing"
- Reservations are released when order is cancelled
- ReservationID stored in OrderItem

### Status Transitions
- Strict state machine enforced
- Invalid transitions return `ErrInvalidStatus`
- Status history tracks all changes

### Payment Integration
- Payment records linked to orders
- Order PaymentStatus updated when payment added
- Payment processing handled by external Payment Service

---

## 🔗 Service Integrations

### Product Service
- **GetProduct**: Validate product exists, get price
- **ValidateProducts**: Batch validation

### Warehouse Service
- **CheckStock**: Validate stock availability
- **ReserveStock**: Reserve inventory for order
- **ReleaseReservation**: Release reserved stock
- **ConfirmReservation**: Confirm stock reservation

### Payment Service
- **ProcessPayment**: Process payment transaction
- **GetPaymentStatus**: Get payment status

### Pricing Service
- **CalculatePrice**: Get dynamic pricing
- **CalculateTax**: Calculate tax amount
- **ApplyDiscounts**: Apply promotion codes

### Notification Service
- **SendOrderNotification**: Send order status notifications

---

## 🚨 Error Handling

### Common Errors
- `ErrOrderNotFound`: Order not found
- `ErrInvalidStatus`: Invalid status transition
- `ErrOrderExpired`: Order has expired
- `ErrOrderCancelled`: Order is cancelled
- `ErrInsufficientStock`: Insufficient stock for item

### Error Scenarios
1. **Product Not Found**: Return error during order creation
2. **Insufficient Stock**: Return error, prevent order creation
3. **Invalid Status Transition**: Return error, prevent status update
4. **Payment Service Unavailable**: Circuit breaker prevents cascading failures

---

## 📝 Notes & TODOs

### Known Issues
1. **UserService UUID Migration**: UserService still uses `int64`, needs update to `string` UUID
2. **Payment Service**: Currently integrated via HTTP client, full Payment Service implementation pending

### Future Enhancements
- Order expiration cleanup job
- Automatic order cancellation for expired orders
- Order splitting for multi-warehouse scenarios
- Partial order cancellation
- Order modification before processing

---

## 📚 Related Documentation

- [Cart Service Logic](./CART_SERVICE_LOGIC.md)
- [Payment Service Logic](./PAYMENT_SERVICE_LOGIC.md)
- [Shipping Service Logic](./SHIPPING_SERVICE_LOGIC.md)
- [Order Service API Docs](../docs/services/order-service.md)


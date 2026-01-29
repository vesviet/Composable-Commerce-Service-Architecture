# Order Management Flow

**Last Updated**: 2026-01-29  
**Status**: Updated for Service Split  
**Domain**: Commerce  
**Services**: Order Service (Primary), Checkout Service (Integration), Return Service (Integration)  
**Navigation**: [← Commerce Domain](../README.md) | [← Business Domains](../../README.md) | [Order Service →](../../03-services/core-services/order-service.md)

> **Note:** Comprehensive analysis updated for service domain split. Order service now focuses on order lifecycle management, while checkout and return operations are handled by dedicated services.

## 1. Executive Summary

The Order system follows a **distributed microservices architecture** with event-driven communication and transactional outbox patterns. After the service domain split, the order management flow now spans multiple specialized services with clear separation of concerns:

- **Checkout Service**: Handles cart management and checkout process
- **Order Service**: Manages order lifecycle and status transitions  
- **Return Service**: Processes returns and exchanges
- **Supporting Services**: Payment, Warehouse, Pricing, Promotion, Review

**Key Components:**
- **Gateway Service**: Request routing, authentication, rate limiting
- **Customer Service**: Profile management, authentication, order history
- **Checkout Service**: Cart management, checkout orchestration
- **Order Service**: Order lifecycle management, status tracking
- **Return Service**: Return and exchange processing
- **Warehouse Service**: Inventory management, stock reservations
- **Pricing Service**: Dynamic pricing, currency conversion, cache management
- **Promotion Service**: Campaign management, discount calculations
- **Review Service**: Post-order review collection and moderation

## 2. Service Architecture After Domain Split

```mermaid
graph TB
    subgraph "Customer Interface"
        C[Customer]
        F[Frontend]
    end
    
    subgraph "API Layer"
        G[Gateway Service]
        G --> |Auth/Routing| CheckoutAPI
        G --> |Auth/Routing| OrderAPI
        G --> |Auth/Routing| ReturnAPI
        G --> |Validation| CustomerAPI
    end
    
    subgraph "Business Logic Layer"
        CheckoutAPI[Checkout Service APIs]
        OrderAPI[Order Service APIs]
        ReturnAPI[Return Service APIs]
        CustomerAPI[Customer Service APIs]
        
        CheckoutAPI --> Cart[Cart Management]
        CheckoutAPI --> CheckoutProcess[Checkout Process]
        
        OrderAPI --> OrderCore[Order Lifecycle]
        OrderAPI --> OrderStatus[Status Management]
        
        ReturnAPI --> ReturnProcess[Return Processing]
        ReturnAPI --> ExchangeProcess[Exchange Processing]
        
        CustomerAPI --> Profile[Customer Profiles]
        CustomerAPI --> Auth[Authentication]
    end
    
    subgraph "Supporting Services"
        W[Warehouse Service]
        P[Pricing Service]
        PR[Promotion Service]
        PAY[Payment Service]
        R[Review Service]
    end
    
    subgraph "Data Layer"
        CheckoutDB[Checkout Database]
        OrderDB[Order Database]
        ReturnDB[Return Database]
        CustomerDB[Customer Database]
        WarehouseDB[Warehouse Database]
        PricingCache[Pricing Redis Cache]
        EventBus[Event Bus - Dapr]
    end
    
    C --> F
    F --> G
    
    Cart --> W
    Cart --> P
    Cart --> PR
    CheckoutProcess --> PAY
    CheckoutProcess --> OrderAPI
    
    OrderCore --> W
    OrderCore --> PAY
    OrderStatus --> CheckoutAPI
    OrderStatus --> ReturnAPI
    
    ReturnProcess --> OrderAPI
    ReturnProcess --> PAY
    ReturnProcess --> W
    
    CheckoutAPI --> CheckoutDB
    OrderAPI --> OrderDB
    ReturnAPI --> ReturnDB
    Profile --> CustomerDB
    W --> WarehouseDB
    P --> PricingCache
    
    OrderCore --> EventBus
    CheckoutProcess --> EventBus
    ReturnProcess --> EventBus
    W --> EventBus
    P --> EventBus
    
    EventBus --> R
```

## 3. Order Lifecycle Flows (Post Service Split)

### 3.1. Complete Order Creation Flow
End-to-end flow from cart to order confirmation across multiple services.

```mermaid
sequenceDiagram
    participant C as Customer
    participant G as Gateway
    participant CS as Checkout Service
    participant OS as Order Service
    participant W as Warehouse Service
    participant P as Pricing Service
    participant PR as Promotion Service
    participant PAY as Payment Service
    participant DB as Order Database
    participant E as Event Bus
    
    C->>G: POST /api/v1/checkout/start
    G->>G: JWT Validation & Rate Limiting
    G->>CS: StartCheckout(cart_session_id)
    
    rect rgb(240, 248, 255)
    note right of CS: Checkout Initialization
    CS->>CS: Get Cart from Session
    CS->>CS: Validate Customer Profile
    CS->>CS: Create Checkout Session
    CS-->>G: Checkout Session Created
    G-->>C: Checkout Session ID
    end
    
    C->>G: PUT /api/v1/checkout/state (address, payment)
    G->>CS: UpdateCheckoutState(session_id, state)
    
    rect rgb(255, 250, 240)
    note right of CS: State Updates & Validation
    CS->>CS: Validate Shipping Address
    CS->>P: Calculate Shipping Costs
    P-->>CS: Shipping Rates
    CS->>PR: Apply Available Promotions
    PR->>PR: Evaluate Promotion Rules
    PR-->>CS: Discount Calculations
    CS->>CS: Update Session State
    CS-->>G: State Updated
    G-->>C: Updated Totals
    end
    
    C->>G: POST /api/v1/checkout/confirm
    G->>CS: ConfirmCheckout(session_id)
    
    rect rgb(255, 240, 245)
    note right of CS: Order Confirmation & Creation
    CS->>W: Reserve Stock for Cart Items
    W->>W: Check Inventory Levels
    W->>W: Create Stock Reservations
    W-->>CS: Reservations Confirmed
    
    CS->>P: Get Final Pricing
    P->>P: Apply Currency Conversion
    P->>P: Cache Price Calculations
    P-->>CS: Final Prices
    
    CS->>PR: Apply Final Promotions
    PR->>PR: Validate Promotion Usage
    PR->>PR: Calculate Final Discounts
    PR-->>CS: Final Discount Amount
    
    CS->>PAY: AuthorizePayment(amount, method)
    PAY-->>CS: Payment Authorized
    
    CS->>OS: CreateOrder(order_data)
    OS->>DB: Begin Transaction
    OS->>DB: Create Order Record
    OS->>DB: Create Order Items
    OS->>DB: Create Outbox Event (OrderCreated)
    OS->>DB: Commit Transaction
    OS-->>CS: Order Created Successfully
    
    CS->>PAY: CapturePayment(auth_id)
    PAY-->>CS: Payment Captured
    
    CS-->>G: Order Created Successfully
    G-->>C: Order Confirmation
    
    note over E: Async Event Processing
    E->>W: Order Created Event
    E->>P: Update Price Cache
    E->>PR: Update Promotion Usage
    E->>CS: Update Customer Order History
    end
```

### 3.2. Order Status Management Flow
Order service manages status transitions and coordinates with other services.

```mermaid
sequenceDiagram
    participant OS as Order Service
    participant CS as Checkout Service
    participant RS as Return Service
    participant W as Warehouse Service
    participant F as Fulfillment Service
    participant E as Event Bus
    participant DB as Order Database
    
    Note over OS: Order Status Transitions
    
    OS->>DB: UpdateOrderStatus(order_id, new_status)
    OS->>DB: Create Status History Record
    OS->>DB: Write Outbox Event (OrderStatusChanged)
    
    alt Status: confirmed → processing
        OS->>W: ConfirmStockReservation(order_id)
        W-->>OS: Stock Confirmed
        OS->>F: CreateFulfillmentRequest(order_id)
        F-->>OS: Fulfillment Created
    end
    
    alt Status: processing → shipped
        F->>OS: UpdateOrderStatus(order_id, shipped)
        OS->>E: PublishEvent(OrderShipped)
        E->>CS: NotifyCustomer(order_shipped)
    end
    
    alt Status: shipped → delivered
        F->>OS: UpdateOrderStatus(order_id, delivered)
        OS->>E: PublishEvent(OrderDelivered)
        E->>RS: EnableReturnWindow(order_id)
    end
    
    alt Status: delivered → return_requested
        RS->>OS: UpdateOrderStatus(order_id, return_requested)
        OS->>E: PublishEvent(ReturnRequested)
    end
```

### 3.3. Cross-Service Integration Patterns
How services communicate and coordinate in the split architecture.

```mermaid
graph TD
    subgraph "Service Communication Patterns"
        A[Checkout Service] -->|gRPC| B[Order Service]
        B -->|Events| C[Return Service]
        C -->|gRPC| B
        A -->|Events| D[Analytics Service]
        B -->|Events| E[Notification Service]
        C -->|Events| E
    end
    
    subgraph "Event Flow"
        F[checkout.order.created] --> G[Order Service]
        H[orders.order.status_changed] --> I[Return Service]
        J[returns.return.requested] --> G
        K[orders.order.delivered] --> L[Review Service]
    end
    
    subgraph "Data Consistency"
        M[Checkout DB] -.->|Eventually Consistent| N[Order DB]
        N -.->|Eventually Consistent| O[Return DB]
        P[Event Bus] --> Q[Data Synchronization]
    end
```
### 3.4. Inventory Reservation Flow

Detailed stock management during order creation (now handled by Checkout Service).

```mermaid
sequenceDiagram
    participant CS as Checkout Service
    participant W as Warehouse Service
    participant WDB as Warehouse Database
    participant E as Event Bus
    
    CS->>W: ReserveStock(items[])
    W->>W: Validate Reservation Request
    
    loop For Each Cart Item
        W->>WDB: Check Available Stock
        alt Stock Available
            W->>WDB: Create Stock Reservation
            W->>WDB: Update Inventory Levels
            note right of W: available_quantity -= reserved_quantity
        else Insufficient Stock
            W->>W: Collect Out-of-Stock Items
        end
    end
    
    alt All Items Reserved
        W->>WDB: Commit Reservations
        W->>E: Publish StockReserved Event
        W-->>CS: Reservation Success (reservation_ids[])
    else Some Items Out-of-Stock
        W->>WDB: Rollback All Reservations
        W-->>CS: Reservation Failed (out_of_stock_items[])
    end
```

### 3.5. Dynamic Pricing Calculation Flow
Real-time pricing with cache management and currency support (used by Checkout Service).

```mermaid
sequenceDiagram
    participant CS as Checkout Service
    participant P as Pricing Service
    participant PC as Pricing Cache (Redis)
    participant PDB as Pricing Database
    participant CC as Currency Converter
    
    CS->>P: CalculatePrice(items[], currency, warehouse_id)
    
    loop For Each Item
        P->>PC: Get Cached Price(product_id, currency, warehouse_id)
        alt Cache Hit
            PC-->>P: Cached Price Data
        else Cache Miss
            P->>PDB: Get Base Price (VND)
            PDB-->>P: Base Price Data
            
            alt Currency Conversion Needed
                P->>CC: Convert Currency (VND → target_currency)
                CC-->>P: Converted Price
            end
            
            P->>PC: Cache Price (30min TTL)
        end
        
        P->>P: Apply Warehouse-Specific Markup
        P->>P: Calculate Quantity Discounts
    end
    
    P->>P: Aggregate Total Pricing
    P-->>CS: Price Calculation Result
```

### 3.6. Promotion Application Flow
Discount calculation with rule validation and usage tracking (integrated with Checkout Service).

```mermaid
sequenceDiagram
    participant CS as Checkout Service
    participant PR as Promotion Service
    participant CUS as Customer Service
    participant PRDB as Promotion Database
    participant E as Event Bus
    
    CS->>PR: ApplyPromotions(customer_id, cart_items[], total_amount)
    
    PR->>PRDB: Get Active Campaigns
    PRDB-->>PR: Active Campaign List
    
    loop For Each Campaign
        PR->>PR: Evaluate Campaign Rules
        
        rect rgb(255, 250, 240)
        note right of PR: Rule Evaluation
        PR->>PR: Check Date Validity
        PR->>PR: Check Budget Limits
        PR->>PR: Check Customer Eligibility
        PR->>PR: Check Product/Category Rules
        PR->>PR: Check Minimum Order Amount
        end
        
        alt Rules Pass
            PR->>CUS: Validate Customer Segment
            CUS-->>PR: Customer Segment Data
            
            PR->>PRDB: Check Usage Limits
            PRDB-->>PR: Usage Count
            
            alt Usage Limits OK
                PR->>PR: Calculate Discount Amount
                PR->>PR: Add to Applied Promotions
            end
        end
    end
    
    PR->>PR: Optimize Promotion Stack
    PR->>PR: Apply Best Combination
    
    alt Promotions Applied
        PR->>PRDB: Update Usage Counters
        PR->>E: Publish PromotionApplied Event
        PR-->>CS: Discount Details
    else No Applicable Promotions
        PR-->>CS: No Discounts Available
    end
```

### 3.7. Post-Order Review Collection Flow
Automated review request after order delivery (triggered by Order Service events).

```mermaid
sequenceDiagram
    participant F as Fulfillment Service
    participant OS as Order Service
    participant R as Review Service
    participant CS as Customer Service
    participant E as Event Bus
    participant N as Notification Service
    
    F->>E: Publish OrderDelivered Event
    E->>OS: OrderDelivered Event Received
    OS->>OS: Update Order Status (delivered)
    OS->>E: Publish OrderStatusChanged Event
    
    E->>R: OrderDelivered Event Received
    R->>OS: Get Order Details
    OS-->>R: Order Items & Customer Info
    
    R->>CS: Get Customer Preferences
    CS-->>R: Review Notification Preferences
    
    alt Customer Allows Review Requests
        R->>R: Schedule Review Request (7 days delay)
        R->>R: Create Review Campaign
        
        note over R: 7 Days Later
        R->>N: Send Review Request Email
        N->>N: Generate Review Links
        N->>CS: Send Personalized Email
        
        R->>E: Publish ReviewRequestSent Event
    else Customer Opted Out
        R->>R: Skip Review Request
        R->>E: Publish ReviewRequestSkipped Event
    end
```

## 4. Service Integration Details (Post Domain Split)

### 4.1. Gateway Service Integration
**File**: `gateway/internal/router/auto_router.go`

**Updated Routing for Service Split**:
```
/api/v1/cart/*       → Checkout Service (port 8001)
/api/v1/checkout/*   → Checkout Service (port 8001)
/api/v1/orders/*     → Order Service (port 8002)
/api/v1/returns/*    → Return Service (port 8003)
/api/v1/customers/*  → Customer Service (port 8004)
/api/v1/reviews/*    → Review Service (port 8005)
```

**Middleware Stack**:
1. **CORS Handler**: Cross-origin request support
2. **JWT Validator**: Customer authentication validation
3. **Rate Limiter**: API abuse protection (100 req/min per customer)
4. **Request ID Generator**: Distributed tracing support
5. **Proxy Handler**: Service discovery and load balancing

### 4.2. Checkout Service Integration
**File**: `checkout/internal/biz/checkout/checkout.go`

**Order-Related Operations**:
- **Cart Management**: Shopping cart operations and session management
- **Checkout Orchestration**: Multi-step checkout process coordination
- **Order Creation**: Integration with Order Service for order creation
- **Payment Integration**: Authorization and capture coordination
- **Inventory Coordination**: Stock reservation and validation

**Order Service Integration**:
```go
type OrderClient struct {
    client pb.OrderServiceClient
    timeout time.Duration
}

func (c *OrderClient) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    ctx, cancel := context.WithTimeout(ctx, c.timeout)
    defer cancel()
    
    response, err := c.client.CreateOrder(ctx, &pb.CreateOrderRequest{
        CustomerId: req.CustomerID,
        Items:      req.Items,
        TotalAmount: req.TotalAmount,
        // ... other fields
    })
    
    if err != nil {
        return nil, fmt.Errorf("failed to create order: %w", err)
    }
    
    return mapOrderResponse(response), nil
}
```

### 4.3. Order Service Core Logic (Refactored)
**File**: `order/internal/biz/order/order.go`

**Focused Responsibilities**:
- **Order Lifecycle Management**: Status transitions and tracking
- **Order History**: Customer order tracking and analytics
- **Integration Coordination**: Event publishing and service coordination
- **Business Rules**: Order validation and business logic

**Checkout Service Integration**:
```go
func (uc *UseCase) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    // Validate request from checkout service
    if err := uc.validateOrderRequest(req); err != nil {
        return nil, err
    }
    
    // Create order with transactional outbox
    err := uc.tm.WithTransaction(ctx, func(ctx context.Context) error {
        // Create order in DB
        createdOrder, err := uc.createOrderInternal(ctx, req)
        if err != nil {
            return err
        }
        
        // Create outbox event in same transaction
        eventPayload := &events.OrderCreatedEvent{
            OrderID:    createdOrder.ID,
            CustomerID: createdOrder.CustomerID,
            Items:      createdOrder.Items,
            TotalAmount: createdOrder.TotalAmount,
            CreatedAt:  time.Now(),
        }
        
        return uc.createOutboxEvent(ctx, eventPayload)
    })
    
    return createdOrder, err
}
```

### 4.4. Return Service Integration
**File**: `return/internal/biz/return/return.go`

**Order Service Integration**:
```go
type OrderServiceClient struct {
    client pb.OrderServiceClient
}

func (c *OrderServiceClient) GetOrder(ctx context.Context, orderID string) (*Order, error) {
    response, err := c.client.GetOrder(ctx, &pb.GetOrderRequest{
        OrderId: orderID,
    })
    
    if err != nil {
        return nil, fmt.Errorf("failed to get order: %w", err)
    }
    
    return mapOrderFromProto(response.Order), nil
}

func (c *OrderServiceClient) UpdateOrderStatus(ctx context.Context, orderID string, status string) error {
    _, err := c.client.UpdateOrderStatus(ctx, &pb.UpdateOrderStatusRequest{
        OrderId: orderID,
        Status:  status,
    })
    
    return err
}
```

### 4.4. Warehouse Service Integration
**File**: `warehouse/internal/biz/inventory/inventory.go`

**Stock Reservation Logic**:
```go
type ReservationRequest struct {
    ProductID   string
    SKU         string
    WarehouseID string
    Quantity    int32
    OrderID     string
    ExpiresAt   time.Time  // 15min default
}
```

**Inventory Update Flow**:
1. **Availability Check**: Real-time stock level validation
2. **Atomic Reservation**: Stock hold with expiration
3. **Event Publishing**: Stock level change notifications
4. **Alert System**: Low stock and out-of-stock alerts

### 4.5. Pricing Service Integration
**File**: `pricing/internal/biz/price/price.go`

**Cache-Aside Pattern**:
```go
func (uc *PriceUsecase) GetPrice(ctx context.Context, productID, currency string) (*model.Price, error) {
    // 1. Try cache first
    if price, err := uc.cache.GetProductPrice(ctx, productID, currency); err == nil {
        return price, nil
    }
    
    // 2. Cache miss - get from database
    price, err := uc.repo.GetByProduct(ctx, productID, currency)
    
    // 3. Currency conversion if needed
    if err != nil && currency != "VND" {
        anyPrice, err := uc.repo.GetAnyPriceByProduct(ctx, productID)
        if err == nil {
            convertedPrice, err := uc.currencyConverter.Convert(anyPrice, currency)
            price = convertedPrice
        }
    }
    
    // 4. Update cache
    uc.cache.SetProductPrice(ctx, productID, currency, price)
    return price, nil
}
```

### 4.6. Promotion Service Integration
**File**: `promotion/internal/biz/promotion.go`

**Campaign Rule Engine**:
```go
type PromotionRule struct {
    CampaignType         string    // "cart", "catalog", "customer"
    DiscountType         string    // "percentage", "fixed_amount", "buy_x_get_y"
    MinimumOrderAmount   *float64
    MaximumDiscountAmount *float64
    ApplicableProducts   []string
    ApplicableCategories []string
    CustomerSegments     []string
    UsageLimit           int32
    StartDate           time.Time
    EndDate             time.Time
}
```

### 4.7. Review Service Integration
**File**: `review/internal/biz/review/review.go`

**Verified Purchase Validation**:
```go
func (uc *ReviewUsecase) CreateReview(ctx context.Context, req *CreateReviewRequest) (*model.Review, error) {
    // Verify purchase with Order Service
    if req.OrderID != "" {
        order, err := uc.orderClient.GetOrder(ctx, req.OrderID)
        
        // Validate order belongs to customer
        if order.CustomerID != req.CustomerID {
            return nil, ErrOrderCustomerMismatch
        }
        
        // Validate product was in order
        hasProduct := false
        for _, item := range order.Items {
            if item.ProductID == req.ProductID {
                hasProduct = true
                break
            }
        }
        
        if !hasProduct {
            return nil, ErrProductNotInOrder
        }
        
        isVerified = true
    }
}
```

## 5. Event-Driven Architecture (Updated for Service Split)

### 5.1. Cross-Service Event Flow
```mermaid
graph TD
    subgraph "Checkout Service Events"
        CC[checkout.cart.item_added]
        CR[checkout.cart.item_removed]
        CA[checkout.cart.abandoned]
        COC[checkout.order.created]
    end
    
    subgraph "Order Service Events"
        OC[orders.order.status_changed]
        OD[orders.order.delivered]
        OU[orders.order.updated]
    end
    
    subgraph "Return Service Events"
        RR[returns.return.requested]
        RA[returns.return.approved]
        RC[returns.return.completed]
        ER[returns.exchange.requested]
        EA[returns.exchange.approved]
        EC[returns.exchange.completed]
    end
    
    subgraph "Warehouse Service Events"
        SR[warehouse.inventory.stock_reserved]
        SC[warehouse.inventory.stock_confirmed]
        SL[warehouse.inventory.stock_changed]
        LA[warehouse.inventory.low_stock_alert]
    end
    
    subgraph "Pricing Service Events"
        PC[pricing.price.calculated]
        PU[pricing.price.updated]
        CI[pricing.cache.invalidated]
    end
    
    subgraph "Promotion Service Events"
        PA[promotions.promotion.applied]
        PUA[promotions.usage.updated]
        CCM[promotions.campaign.completed]
    end
    
    subgraph "Review Service Events"
        RRS[reviews.request.sent]
        RCR[reviews.review.created]
        RAP[reviews.review.approved]
    end
    
    COC --> OC
    OC --> RR
    OD --> RRS
    
    CC --> SR
    SR --> SL
    SL --> LA
    
    COC --> PA
    PA --> PUA
    PUA --> CCM
    
    RCR --> RAP
```

### 5.2. Service Integration Events

**Checkout → Order Integration**:
- `checkout.order.created` → Order Service creates order record
- `checkout.payment.authorized` → Order Service updates payment status
- `checkout.session.completed` → Order Service finalizes order

**Order → Return Integration**:
- `orders.order.delivered` → Return Service enables return window
- `orders.order.status_changed` → Return Service updates return eligibility
- `returns.return.completed` → Order Service updates order status

**Cross-Service Coordination**:
- `warehouse.inventory.stock_reserved` → Checkout Service confirms availability
- `payment.payment.captured` → Order Service confirms payment
- `fulfillment.package.shipped` → Order Service updates delivery status

### 5.2. Event Processing Patterns

**Outbox Pattern Implementation**:
```sql
CREATE TABLE outbox (
    id UUID PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP NULL,
    retry_count INTEGER DEFAULT 0
);
```

**Event Worker Processing**:
- **Polling Interval**: 30 seconds
- **Batch Size**: 100 events per batch
- **Retry Strategy**: Exponential backoff (max 5 retries)
- **Dead Letter Queue**: Failed events after max retries

## 6. Performance & Monitoring

### 6.1. Key Performance Metrics

**Order Processing**:
- Order creation time: <5 seconds (p95)
- Cart operations: <200ms (p95)
- Stock reservation: <1 second (p95)
- Price calculation: <300ms (p95)

**Service Integration**:
- Gateway routing latency: <50ms (p95)
- Inter-service communication: <100ms (p95)
- Database transaction time: <500ms (p95)
- Cache hit ratio: >90%

### 6.2. Monitoring Implementation

**Prometheus Metrics**:
```go
type OrderMetrics struct {
    OrdersCreated       prometheus.Counter
    OrderCreationTime   prometheus.Histogram
    CartOperations      prometheus.Counter
    StockReservations   prometheus.Counter
    PriceCalculations   prometheus.Histogram
    PromotionApplications prometheus.Counter
}
```

**Health Check Endpoints**:
- `/health/live`: Service liveness check
- `/health/ready`: Service readiness with dependency checks
- `/metrics`: Prometheus metrics endpoint

## 7. Error Handling & Recovery

### 7.1. Compensation Patterns

**Stock Reservation Failure**:
```go
func (uc *UseCase) handleReservationFailure(ctx context.Context, reservations []Reservation) {
    for _, reservation := range reservations {
        if err := uc.warehouse.ReleaseReservation(ctx, reservation.ID); err != nil {
            // Send to dead letter queue for manual intervention
            uc.dlq.Send(ctx, &ReservationRollbackEvent{
                ReservationID: reservation.ID,
                Reason:       "Order creation failed",
            })
        }
    }
}
```

**Price Calculation Fallback**:
```go
func (uc *UseCase) getPriceWithFallback(ctx context.Context, productID string) (*Price, error) {
    // Try primary pricing service
    price, err := uc.pricing.GetPrice(ctx, productID)
    if err == nil {
        return price, nil
    }
    
    // Fallback to cached price
    cachedPrice, err := uc.cache.GetPrice(ctx, productID)
    if err == nil {
        return cachedPrice, nil
    }
    
    // Last resort: base catalog price
    return uc.catalog.GetBasePrice(ctx, productID)
}
```

### 7.2. Circuit Breaker Implementation

**Service Resilience**:
- **Failure Threshold**: 5 failures in 60 seconds
- **Half-Open**: Test with single request after 5 minutes
- **Timeout**: 30 seconds for external service calls
- **Fallback**: Cached data or graceful degradation

---

## 8. Service Split Benefits & Considerations

### 8.1. Benefits of Domain Split

**Separation of Concerns**:
- **Checkout Service**: Focused on cart and checkout experience
- **Order Service**: Dedicated to order lifecycle management
- **Return Service**: Specialized in return and exchange processing

**Scalability Improvements**:
- Independent scaling based on service-specific load patterns
- Checkout service can scale for high cart activity
- Order service scales for order processing volume
- Return service scales independently during return seasons

**Development Velocity**:
- Teams can work independently on different domains
- Faster feature development with reduced coordination overhead
- Clear service boundaries reduce merge conflicts

**Fault Isolation**:
- Checkout issues don't affect order tracking
- Return processing failures don't impact new orders
- Better system resilience with isolated failure domains

### 8.2. Integration Challenges

**Cross-Service Transactions**:
- Distributed transaction complexity across services
- Need for saga patterns and compensation logic
- Event-driven eventual consistency requirements

**Data Consistency**:
- Order data synchronized across multiple services
- Event ordering and duplicate handling
- Cross-service referential integrity

**Service Communication**:
- Network latency between service calls
- Circuit breaker and retry logic requirements
- Service discovery and load balancing complexity

### 8.3. Mitigation Strategies

**Event-Driven Architecture**:
- Asynchronous communication reduces coupling
- Event sourcing for audit trails and replay capability
- Outbox pattern ensures reliable event publishing

**Service Mesh Integration**:
- mTLS for secure service-to-service communication
- Observability and tracing across service boundaries
- Traffic management and load balancing

**Data Management**:
- Each service owns its data domain
- Event-driven data synchronization
- CQRS for read/write separation where needed

---

## 9. Development Guidelines (Updated)

### 9.1. Adding New Order Features

1. **Identify Service Boundary**: Determine which service owns the feature
2. **Update Proto Definitions**: Modify appropriate service API contracts
3. **Implement Business Logic**: Add to appropriate service's biz layer
4. **Add Cross-Service Integration**: Implement gRPC clients if needed
5. **Add Event Handling**: Implement event publishing and consumption
6. **Update Integration**: Modify service dependencies as needed
7. **Add Monitoring**: Include metrics and health checks
8. **Write Tests**: Unit, integration, and end-to-end tests

### 9.2. Cross-Service Testing Strategy

**Unit Tests**: Individual service business logic validation
**Integration Tests**: Service-to-service communication testing
**Contract Tests**: API contract validation between services
**End-to-End Tests**: Complete order flow validation across services
**Chaos Tests**: Service failure and recovery scenarios

---

**Document Status**: ✅ Updated for Service Domain Split  
**Last Updated**: January 29, 2026  
**Services Covered**: Gateway, Customer, Checkout, Order, Return, Warehouse, Pricing, Promotion, Payment, Review  
**Next Review**: Cross-Service Performance Optimization & Monitoring Enhancement

#### Step 3.5: Reservation Confirmation
- Calls `warehouseInventoryService.ConfirmReservation(reservationID)`.
- **Failure Handling**: If confirmation fails, errors are logged and stored in `order.metadata["reservation_confirmation_errors"]`. The order is **not** rolled back (Soft Failure). Admin intervention may be required.

#### Step 3.6: Cart Finalization
- marks the Cart as `is_active = false`.
- Invalidates Cart Cache.

## 3. Asynchronous Processing (Outbox)
- The `OrderStatusChanged` event (saved in Step 3.3) is picked up by a background worker (Change Data Capture or Polling).
- This worker publishes the event to the Event Bus (Dapr/Kafka) for other services:
    - **Notification**: Send email confirmation.
    - **Loyalty**: Accrue points.
    - **Analytics**: Track sales.

## 4. Key Dependencies
- **Catalog Service**: Product details.
- **Pricing Service**: Price calculation.
- **Warehouse Service**: Inventory check and reservation.
- **Payment Service**: (Implicit) Payment execution usually happens before confirmation or is integrated into the flow.

## 5. Error Handling
- **Idempotency**: Returns existing order if `cart_session_id` conflict occurs.
- **Reservation Failure**: Rollbacks are attempted if validation fails before order commit.
- **Post-Commit Failures**: (e.g., Warehouse confirmation) handled via logging/alerting (Metadata flagging).

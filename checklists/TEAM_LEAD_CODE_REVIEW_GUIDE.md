# 📋 TEAM LEAD CODE REVIEW GUIDE

**Version**: 1.0.0  
**Last Updated**: January 16, 2026  
**Purpose**: Standardized code review guidelines for Team Leads to ensure consistent quality across all services

---

## 🎯 DOCUMENT OBJECTIVES

This guide helps Team Leads:
- ✅ **Review code systematically** - Don't miss critical issues
- ✅ **Ensure consistent quality** - All services meet production standards
- ✅ **Catch issues early** - Before code is merged and deployed
- ✅ **Guide developers effectively** - Clear feedback with concrete examples
- ✅ **Save time** - Ready-to-use checklist, no need to start from scratch

---

## 📊 REVIEW PROCESS OVERVIEW

### Step 1: Preparation (5-10 minutes)
1. Read the Pull Request/Merge Request description
2. Understand the purpose of changes (new feature, bug fix, refactor)
3. Identify scope: which service, domain, and layers are affected
4. Prepare test environment if needed

### Step 2: Review with Checklist (30-60 minutes)
1. Check each item in the checklist below
2. Document issues found
3. Classify severity (P0, P1, P2)
4. Suggest concrete solutions

### Step 3: Provide Feedback (10-15 minutes)
1. Summarize feedback using template
2. Prioritize P0 issues (blocking)
3. Explain reasoning and how to fix
4. Acknowledge what was done well

### Step 4: Follow-up
1. Track developer fixes
2. Re-review after changes
3. Approve when standards are met

---

## 🔍 DETAILED CHECKLIST - 10 CORE STANDARDS

### 1. 🏗 ARCHITECTURE & CLEAN CODE

#### ✅ Acceptance Criteria:

- [ ] **Standard Layout**: Code follows Clean Architecture structure
  ```
  ✅ CORRECT:
  internal/biz/order/usecase.go      # Business logic
  internal/data/postgres/order.go    # Data access
  internal/service/order.go          # gRPC/HTTP handlers
  
  ❌ WRONG:
  internal/service/order_logic.go    # Business logic in service layer
  internal/biz/order_repo.go         # Data access in biz layer
  ```

- [ ] **Clear Separation of Concerns**:
  - **Biz layer**: MUST NOT call DB directly (gorm.DB)
  - **Data layer**: MUST NOT contain business logic
  - **Service layer**: ONLY acts as adapter between API and Biz layer
  
  ```go
  // ❌ WRONG - Business logic in service layer
  func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
      // Validation logic
      if req.TotalAmount < 0 {
          return nil, errors.New("invalid amount")
      }
      // Business calculation
      discount := calculateDiscount(req.Items)
      // Direct DB call
      s.db.Create(&order)
  }
  
  // ✅ CORRECT - Service only acts as adapter
  func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
      order, err := s.orderUsecase.CreateOrder(ctx, &biz.CreateOrderInput{
          CustomerID: req.CustomerId,
          Items:      convertItems(req.Items),
      })
      if err != nil {
          return nil, err
      }
      return convertToProto(order), nil
  }
  ```

- [ ] **Clear Dependency Injection**: Use Wire or manual DI
  ```go
  // ✅ CORRECT - Dependencies injected via constructor
  type OrderUsecase struct {
      orderRepo    OrderRepository
      paymentRepo  PaymentRepository
      eventBus     EventPublisher
      logger       *log.Logger
  }
  
  func NewOrderUsecase(
      orderRepo OrderRepository,
      paymentRepo PaymentRepository,
      eventBus EventPublisher,
      logger *log.Logger,
  ) *OrderUsecase {
      return &OrderUsecase{
          orderRepo:   orderRepo,
          paymentRepo: paymentRepo,
          eventBus:    eventBus,
          logger:      logger,
      }
  }
  
  // ❌ WRONG - Global state, hidden dependencies
  var globalDB *gorm.DB
  
  func CreateOrder(ctx context.Context, order *Order) error {
      return globalDB.Create(order).Error
  }
  ```

- [ ] **Linter Compliance**: Passes `golangci-lint` with zero warnings
  ```bash
  # Run linter
  cd service-name
  golangci-lint run
  
  # Expected result: 0 issues
  ```

#### 🚨 Common Mistakes:

**Mistake 1: Business logic leaking into Service layer**
```go
// ❌ WRONG
func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) {
    // Validation here is OK
    if req.CustomerId == "" {
        return nil, status.Error(codes.InvalidArgument, "customer_id required")
    }
    
    // ❌ Business logic should NOT be here
    var totalAmount float64
    for _, item := range req.Items {
        product, _ := s.catalogClient.GetProduct(ctx, item.ProductId)
        totalAmount += product.Price * float64(item.Quantity)
    }
    
    // ❌ Direct DB call should NOT be here
    order := &model.Order{
        CustomerID:  req.CustomerId,
        TotalAmount: totalAmount,
    }
    s.db.Create(order)
}

// ✅ CORRECT - Delegate to usecase
func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) {
    order, err := s.orderUsecase.CreateOrder(ctx, &biz.CreateOrderInput{
        CustomerID: req.CustomerId,
        Items:      convertItems(req.Items),
    })
    return convertToProto(order), err
}
```

**Mistake 2: Data access logic in Biz layer**
```go
// ❌ WRONG - Biz layer calling GORM directly
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    order := &model.Order{
        CustomerID: input.CustomerID,
        Status:     "pending",
    }
    
    // ❌ MUST NOT call gorm.DB directly
    if err := uc.db.Create(order).Error; err != nil {
        return nil, err
    }
    
    return order, nil
}

// ✅ CORRECT - Call through Repository interface
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    order := &biz.Order{
        CustomerID: input.CustomerID,
        Status:     biz.OrderStatusPending,
    }
    
    // ✅ Call through interface
    if err := uc.orderRepo.Create(ctx, order); err != nil {
        return nil, err
    }
    
    return order, nil
}
```

#### 📝 How to Review:
1. Check file structure matches standard layout
2. Random pick 2-3 files in each layer, read the code
3. Search for keywords: `gorm.DB`, `db.Create`, `db.Where` in biz layer → ❌
4. Look for business logic (complex if/else, calculations) in service layer → ❌
5. Check for global variables → ❌

---

### 2. 🔌 API & CONTRACT (gRPC/HTTP)

#### ✅ Acceptance Criteria:

- [ ] **Proto Standards**: Proper naming conventions and message structure
  ```protobuf
  // ✅ CORRECT
  service OrderService {
    // RPC name: verb + noun
    rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
    rpc GetOrder(GetOrderRequest) returns (GetOrderResponse);
    rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse);
    rpc UpdateOrder(UpdateOrderRequest) returns (UpdateOrderResponse);
    rpc DeleteOrder(DeleteOrderRequest) returns (DeleteOrderResponse);
  }
  
  message CreateOrderRequest {
    string customer_id = 1;
    repeated OrderItem items = 2;
    string shipping_address_id = 3;
  }
  
  message CreateOrderResponse {
    Order order = 1;
  }
  
  // ❌ WRONG - Non-standard naming
  service OrderService {
    rpc Create(OrderRequest) returns (OrderResponse);  // Missing noun
    rpc Get(string) returns (Order);                   // Not using message
  }
  ```

- [ ] **Error Handling**: Proper gRPC status code mapping
  ```go
  // ✅ CORRECT - Map error types to gRPC codes
  func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
      order, err := s.orderUsecase.CreateOrder(ctx, input)
      if err != nil {
          // Map business errors to gRPC codes
          switch {
          case errors.Is(err, biz.ErrOrderNotFound):
              return nil, status.Error(codes.NotFound, err.Error())
          case errors.Is(err, biz.ErrInvalidInput):
              return nil, status.Error(codes.InvalidArgument, err.Error())
          case errors.Is(err, biz.ErrUnauthorized):
              return nil, status.Error(codes.Unauthenticated, err.Error())
          case errors.Is(err, biz.ErrPermissionDenied):
              return nil, status.Error(codes.PermissionDenied, err.Error())
          default:
              return nil, status.Error(codes.Internal, "internal server error")
          }
      }
      return &pb.CreateOrderResponse{Order: convertToProto(order)}, nil
  }
  
  // ❌ WRONG - Return error directly
  func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
      order, err := s.orderUsecase.CreateOrder(ctx, input)
      if err != nil {
          return nil, err  // ❌ No error code mapping
      }
      return &pb.CreateOrderResponse{Order: convertToProto(order)}, nil
  }
  ```

- [ ] **Input Validation**: Validate before processing logic
  ```go
  // ✅ CORRECT - Comprehensive validation
  func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
      // Validate required fields
      if req.CustomerId == "" {
          return nil, status.Error(codes.InvalidArgument, "customer_id is required")
      }
      if len(req.Items) == 0 {
          return nil, status.Error(codes.InvalidArgument, "items cannot be empty")
      }
      
      // Validate business rules
      for i, item := range req.Items {
          if item.ProductId == "" {
              return nil, status.Errorf(codes.InvalidArgument, "items[%d].product_id is required", i)
          }
          if item.Quantity <= 0 {
              return nil, status.Errorf(codes.InvalidArgument, "items[%d].quantity must be positive", i)
          }
      }
      
      // Process
      order, err := s.orderUsecase.CreateOrder(ctx, input)
      // ...
  }
  
  // ❌ WRONG - No validation
  func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
      // Process directly without validation
      order, err := s.orderUsecase.CreateOrder(ctx, input)
      return &pb.CreateOrderResponse{Order: convertToProto(order)}, err
  }
  ```

- [ ] **Backward Compatibility**: No breaking changes
  ```protobuf
  // ✅ CORRECT - Add new field with new field number
  message Order {
    string id = 1;
    string customer_id = 2;
    string status = 3;
    string created_at = 4;
    string shipping_address = 5;  // New field - OK
  }
  
  // ❌ WRONG - Delete field or change type
  message Order {
    string id = 1;
    string customer_id = 2;
    // string status = 3;  // ❌ Deleted field - BREAKING CHANGE
    int32 status = 3;      // ❌ Changed type - BREAKING CHANGE
  }
  
  // ✅ CORRECT - Deprecate old field, add new one
  message Order {
    string id = 1;
    string customer_id = 2;
    string status = 3 [deprecated = true];
    OrderStatus status_enum = 6;  // New field
  }
  ```

#### 🚨 Common Mistakes:

**Mistake 1: No input validation**
```go
// ❌ WRONG
func (s *OrderService) UpdateOrderStatus(ctx context.Context, req *pb.UpdateOrderStatusRequest) (*pb.UpdateOrderStatusResponse, error) {
    // No check if req.OrderId is empty
    // No check if req.Status is valid
    err := s.orderUsecase.UpdateStatus(ctx, req.OrderId, req.Status)
    return &pb.UpdateOrderStatusResponse{}, err
}

// ✅ CORRECT
func (s *OrderService) UpdateOrderStatus(ctx context.Context, req *pb.UpdateOrderStatusRequest) (*pb.UpdateOrderStatusResponse, error) {
    if req.OrderId == "" {
        return nil, status.Error(codes.InvalidArgument, "order_id is required")
    }
    
    validStatuses := []string{"pending", "confirmed", "shipped", "delivered", "cancelled"}
    if !contains(validStatuses, req.Status) {
        return nil, status.Errorf(codes.InvalidArgument, "invalid status: %s", req.Status)
    }
    
    err := s.orderUsecase.UpdateStatus(ctx, req.OrderId, req.Status)
    if err != nil {
        return nil, mapError(err)
    }
    return &pb.UpdateOrderStatusResponse{}, nil
}
```

**Mistake 2: Improper error handling**
```go
// ❌ WRONG - Expose internal error
func (s *OrderService) GetOrder(ctx context.Context, req *pb.GetOrderRequest) (*pb.GetOrderResponse, error) {
    order, err := s.orderRepo.FindByID(ctx, req.OrderId)
    if err != nil {
        // ❌ Return DB error message
        return nil, status.Error(codes.Internal, err.Error())
    }
    return &pb.GetOrderResponse{Order: convertToProto(order)}, nil
}

// ✅ CORRECT - Map error properly
func (s *OrderService) GetOrder(ctx context.Context, req *pb.GetOrderRequest) (*pb.GetOrderResponse, error) {
    order, err := s.orderUsecase.GetOrder(ctx, req.OrderId)
    if err != nil {
        if errors.Is(err, biz.ErrOrderNotFound) {
            return nil, status.Error(codes.NotFound, "order not found")
        }
        // Log internal error but don't expose
        s.logger.Error("failed to get order", "error", err, "order_id", req.OrderId)
        return nil, status.Error(codes.Internal, "failed to get order")
    }
    return &pb.GetOrderResponse{Order: convertToProto(order)}, nil
}
```

#### 📝 How to Review:
1. Check proto files: naming, message structure, field numbers
2. Check service layer: is validation comprehensive
3. Check error handling: are error codes mapped correctly
4. Test with invalid input: does service reject properly
5. Check backward compatibility: any breaking changes

---

### 3. 🧠 BUSINESS LOGIC & CONCURRENCY

#### ✅ Acceptance Criteria:

- [ ] **Context Propagation**: `context.Context` passed through all layers
  ```go
  // ✅ CORRECT - Context passed everywhere
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // Pass context to repository
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // Pass context to external service
      payment, err := uc.paymentClient.CreatePayment(ctx, paymentReq)
      if err != nil {
          return nil, err
      }
      
      // Pass context to event publisher
      uc.eventBus.Publish(ctx, "order.created", order)
      
      return order, nil
  }
  
  // ❌ WRONG - Missing context
  func (uc *OrderUsecase) CreateOrder(input *CreateOrderInput) (*Order, error) {
      // ❌ No context parameter
      order, err := uc.orderRepo.Create(order)
      return order, err
  }
  ```

- [ ] **Goroutine Safety**: No unmanaged goroutines, use errgroup or worker pools
  ```go
  // ❌ WRONG - Unmanaged goroutine
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // ❌ Fire and forget - no error handling, no panic recovery
      go func() {
          uc.notificationClient.SendEmail(order.CustomerID, "Order created")
      }()
      
      return order, nil
  }
  
  // ✅ CORRECT - Use errgroup for managed goroutines
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // Use errgroup for parallel operations
      g, ctx := errgroup.WithContext(ctx)
      
      g.Go(func() error {
          return uc.notificationClient.SendEmail(ctx, order.CustomerID, "Order created")
      })
      
      g.Go(func() error {
          return uc.analyticsClient.TrackEvent(ctx, "order_created", order.ID)
      })
      
      // Wait for all goroutines and check errors
      if err := g.Wait(); err != nil {
          uc.logger.Error("failed to send notifications", "error", err)
          // Don't fail the order creation, just log
      }
      
      return order, nil
  }
  
  // ✅ CORRECT - Use event bus for async operations
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // Publish event - let worker handle async processing
      uc.eventBus.Publish(ctx, "order.created", order)
      
      return order, nil
  }
  ```

- [ ] **Race Conditions**: Shared mutable state protected by mutexes
  ```go
  // ❌ WRONG - Race condition
  type OrderCache struct {
      orders map[string]*Order  // ❌ Unprotected shared state
  }
  
  func (c *OrderCache) Set(id string, order *Order) {
      c.orders[id] = order  // ❌ Race condition
  }
  
  func (c *OrderCache) Get(id string) *Order {
      return c.orders[id]  // ❌ Race condition
  }
  
  // ✅ CORRECT - Protected with mutex
  type OrderCache struct {
      mu     sync.RWMutex
      orders map[string]*Order
  }
  
  func (c *OrderCache) Set(id string, order *Order) {
      c.mu.Lock()
      defer c.mu.Unlock()
      c.orders[id] = order
  }
  
  func (c *OrderCache) Get(id string) *Order {
      c.mu.RLock()
      defer c.mu.RUnlock()
      return c.orders[id]
  }
  
  // ✅ BETTER - Use sync.Map for concurrent access
  type OrderCache struct {
      orders sync.Map
  }
  
  func (c *OrderCache) Set(id string, order *Order) {
      c.orders.Store(id, order)
  }
  
  func (c *OrderCache) Get(id string) (*Order, bool) {
      val, ok := c.orders.Load(id)
      if !ok {
          return nil, false
      }
      return val.(*Order), true
  }
  ```

- [ ] **Idempotency**: Critical operations handle retries safely
  ```go
  // ❌ WRONG - Not idempotent
  func (uc *PaymentUsecase) CapturePayment(ctx context.Context, orderID string) error {
      // ❌ Retry will create duplicate charges
      charge, err := uc.paymentGateway.Charge(ctx, orderID, amount)
      if err != nil {
          return err
      }
      
      return uc.paymentRepo.Create(ctx, charge)
  }
  
  // ✅ CORRECT - Idempotent with idempotency key
  func (uc *PaymentUsecase) CapturePayment(ctx context.Context, orderID string, idempotencyKey string) error {
      // Check if already processed
      existing, err := uc.paymentRepo.FindByIdempotencyKey(ctx, idempotencyKey)
      if err == nil {
          return nil  // Already processed
      }
      
      // Use idempotency key in payment gateway
      charge, err := uc.paymentGateway.Charge(ctx, &ChargeRequest{
          OrderID:        orderID,
          Amount:         amount,
          IdempotencyKey: idempotencyKey,
      })
      if err != nil {
          return err
      }
      
      charge.IdempotencyKey = idempotencyKey
      return uc.paymentRepo.Create(ctx, charge)
  }
  ```

#### 🚨 Common Mistakes:

**Mistake 1: Fire-and-forget goroutines**
```go
// ❌ WRONG
func (uc *OrderUsecase) ProcessOrder(ctx context.Context, orderID string) error {
    order, _ := uc.orderRepo.FindByID(ctx, orderID)
    
    // ❌ No error handling, no panic recovery
    go uc.sendNotification(order)
    go uc.updateInventory(order)
    go uc.createShipment(order)
    
    return nil
}

// ✅ CORRECT - Use event-driven approach
func (uc *OrderUsecase) ProcessOrder(ctx context.Context, orderID string) error {
    order, err := uc.orderRepo.FindByID(ctx, orderID)
    if err != nil {
        return err
    }
    
    // Publish event - workers will handle async processing
    return uc.eventBus.Publish(ctx, "order.confirmed", order)
}
```

**Mistake 2: Missing context timeout**
```go
// ❌ WRONG - No timeout
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    // ❌ External call without timeout - can hang forever
    inventory, err := uc.warehouseClient.CheckStock(ctx, input.Items)
    if err != nil {
        return nil, err
    }
    // ...
}

// ✅ CORRECT - Set timeout for external calls
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    // Set timeout for external call
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    
    inventory, err := uc.warehouseClient.CheckStock(ctx, input.Items)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return nil, errors.New("warehouse service timeout")
        }
        return nil, err
    }
    // ...
}
```

#### 📝 How to Review:
1. Search for `go func()` - check if properly managed
2. Check for shared state (maps, slices) - verify mutex protection
3. Look for external calls - verify context and timeout
4. Check critical operations (payment, inventory) - verify idempotency
5. Run with `-race` flag to detect race conditions

---

### 4. 💽 DATA LAYER & PERSISTENCE

#### ✅ Acceptance Criteria:

- [ ] **Transaction Boundaries**: Multi-write operations use atomic transactions
  ```go
  // ❌ WRONG - No transaction, partial failure possible
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // ❌ If any step fails, previous steps are not rolled back
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      for _, item := range input.Items {
          err := uc.orderItemRepo.Create(ctx, item)
          if err != nil {
              return nil, err  // ❌ Order already created, items partially created
          }
      }
      
      err = uc.paymentRepo.Create(ctx, payment)
      if err != nil {
          return nil, err  // ❌ Order and items already created
      }
      
      return order, nil
  }
  
  // ✅ CORRECT - Use transaction
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      var order *Order
      
      err := uc.txManager.InTx(ctx, func(ctx context.Context) error {
          // All operations in same transaction
          var err error
          order, err = uc.orderRepo.Create(ctx, order)
          if err != nil {
              return err
          }
          
          for _, item := range input.Items {
              if err := uc.orderItemRepo.Create(ctx, item); err != nil {
                  return err  // Transaction will rollback
              }
          }
          
          if err := uc.paymentRepo.Create(ctx, payment); err != nil {
              return err  // Transaction will rollback
          }
          
          return nil
      })
      
      if err != nil {
          return nil, err
      }
      
      return order, nil
  }
  ```

- [ ] **Query Optimization**: No N+1 queries, proper indexing
  ```go
  // ❌ WRONG - N+1 query problem
  func (r *OrderRepository) GetOrdersWithItems(ctx context.Context, customerID string) ([]*Order, error) {
      // Query 1: Get orders
      orders, err := r.db.Where("customer_id = ?", customerID).Find(&orders).Error
      if err != nil {
          return nil, err
      }
      
      // ❌ N queries: Get items for each order
      for i, order := range orders {
          items, _ := r.db.Where("order_id = ?", order.ID).Find(&items).Error
          orders[i].Items = items
      }
      
      return orders, nil
  }
  
  // ✅ CORRECT - Use preload/joins
  func (r *OrderRepository) GetOrdersWithItems(ctx context.Context, customerID string) ([]*Order, error) {
      var orders []*Order
      
      // Single query with join
      err := r.db.
          Preload("Items").
          Preload("Items.Product").
          Where("customer_id = ?", customerID).
          Find(&orders).Error
      
      return orders, err
  }
  
  // ✅ BETTER - Use pagination for large datasets
  func (r *OrderRepository) GetOrdersWithItems(ctx context.Context, customerID string, limit, offset int) ([]*Order, error) {
      var orders []*Order
      
      err := r.db.
          Preload("Items").
          Where("customer_id = ?", customerID).
          Limit(limit).
          Offset(offset).
          Order("created_at DESC").
          Find(&orders).Error
      
      return orders, err
  }
  ```

- [ ] **Migration Management**: Schema changes properly scripted
  ```sql
  -- ✅ CORRECT - Migration with up and down
  -- migrations/001_create_orders_table.sql
  -- +goose Up
  CREATE TABLE orders (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      customer_id UUID NOT NULL,
      status VARCHAR(50) NOT NULL,
      total_amount DECIMAL(10,2) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      deleted_at TIMESTAMP
  );
  
  CREATE INDEX idx_orders_customer_id ON orders(customer_id);
  CREATE INDEX idx_orders_status ON orders(status);
  CREATE INDEX idx_orders_created_at ON orders(created_at);
  
  -- +goose Down
  DROP TABLE IF EXISTS orders;
  
  -- ❌ WRONG - No down migration, no indexes
  -- migrations/001_create_orders_table.sql
  CREATE TABLE orders (
      id UUID PRIMARY KEY,
      customer_id UUID,
      status VARCHAR(50),
      total_amount DECIMAL(10,2)
  );
  ```

- [ ] **Repository Pattern**: DB implementation isolated behind interfaces
  ```go
  // ✅ CORRECT - Interface in biz layer
  // internal/biz/order/repository.go
  package order
  
  type OrderRepository interface {
      Create(ctx context.Context, order *Order) error
      Update(ctx context.Context, order *Order) error
      FindByID(ctx context.Context, id string) (*Order, error)
      FindByCustomerID(ctx context.Context, customerID string) ([]*Order, error)
      Delete(ctx context.Context, id string) error
  }
  
  // Implementation in data layer
  // internal/data/postgres/order.go
  package postgres
  
  type orderRepository struct {
      db *gorm.DB
  }
  
  func NewOrderRepository(db *gorm.DB) order.OrderRepository {
      return &orderRepository{db: db}
  }
  
  func (r *orderRepository) Create(ctx context.Context, order *order.Order) error {
      model := convertToModel(order)
      return r.db.WithContext(ctx).Create(model).Error
  }
  
  // ❌ WRONG - Expose GORM in interface
  type OrderRepository interface {
      Create(ctx context.Context, order *gorm.Model) error  // ❌ GORM leak
      GetDB() *gorm.DB  // ❌ Expose DB
  }
  ```

#### 🚨 Common Mistakes:

**Mistake 1: Missing transaction for multi-step operations**
```go
// ❌ WRONG - Inventory adjustment without transaction
func (uc *WarehouseUsecase) AdjustStock(ctx context.Context, productID string, quantity int) error {
    // Step 1: Get current stock
    stock, err := uc.stockRepo.FindByProductID(ctx, productID)
    if err != nil {
        return err
    }
    
    // Step 2: Update stock
    stock.Quantity += quantity
    err = uc.stockRepo.Update(ctx, stock)
    if err != nil {
        return err
    }
    
    // Step 3: Create audit log
    audit := &StockAudit{
        ProductID: productID,
        Change:    quantity,
        Timestamp: time.Now(),
    }
    err = uc.auditRepo.Create(ctx, audit)
    if err != nil {
        return err  // ❌ Stock updated but audit failed
    }
    
    return nil
}

// ✅ CORRECT - Wrap in transaction
func (uc *WarehouseUsecase) AdjustStock(ctx context.Context, productID string, quantity int) error {
    return uc.txManager.InTx(ctx, func(ctx context.Context) error {
        stock, err := uc.stockRepo.FindByProductID(ctx, productID)
        if err != nil {
            return err
        }
        
        stock.Quantity += quantity
        if err := uc.stockRepo.Update(ctx, stock); err != nil {
            return err
        }
        
        audit := &StockAudit{
            ProductID: productID,
            Change:    quantity,
            Timestamp: time.Now(),
        }
        return uc.auditRepo.Create(ctx, audit)
    })
}
```

**Mistake 2: SQL injection vulnerability**
```go
// ❌ WRONG - SQL injection risk
func (r *OrderRepository) SearchOrders(ctx context.Context, query string) ([]*Order, error) {
    var orders []*Order
    
    // ❌ String concatenation - SQL injection risk
    sql := fmt.Sprintf("SELECT * FROM orders WHERE customer_name LIKE '%%%s%%'", query)
    err := r.db.Raw(sql).Scan(&orders).Error
    
    return orders, err
}

// ✅ CORRECT - Use parameterized queries
func (r *OrderRepository) SearchOrders(ctx context.Context, query string) ([]*Order, error) {
    var orders []*Order
    
    // ✅ Parameterized query
    err := r.db.
        Where("customer_name LIKE ?", "%"+query+"%").
        Find(&orders).Error
    
    return orders, err
}
```

#### 📝 How to Review:
1. Check for multi-step operations - verify transaction usage
2. Look for loops with DB queries - check for N+1 problems
3. Review migrations - verify up/down, indexes, constraints
4. Check repository interfaces - ensure no GORM/DB leakage
5. Search for string concatenation in SQL - check for injection risks

---

### 3. 🧠 BUSINESS LOGIC & CONCURRENCY

#### ✅ Điều kiện đạt chuẩn:

- [ ] **Context propagation**: `context.Context` được truyền qua tất cả các layers
  ```go
  // ✅ ĐÚNG - Context được truyền xuyên suốt
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // Check context cancellation
      if err := ctx.Err(); err != nil {
          return nil, err
      }
      
      // Pass context to repository
      order, err := uc.orderRepo.Create(ctx, &biz.Order{
          CustomerID: input.CustomerID,
          Status:     biz.OrderStatusPending,
      })
      if err != nil {
          return nil, err
      }
      
      // Pass context to external service
      payment, err := uc.paymentClient.CreatePayment(ctx, &payment.CreatePaymentRequest{
          OrderID: order.ID,
          Amount:  order.TotalAmount,
      })
      if err != nil {
          return nil, err
      }
      
      // Pass context to event publisher
      uc.eventBus.Publish(ctx, "order.created", order)
      
      return order, nil
  }
  
  // ❌ SAI - Không truyền context
  func (uc *OrderUsecase) CreateOrder(input *CreateOrderInput) (*Order, error) {
      // ❌ Không có context parameter
      order, err := uc.orderRepo.Create(&biz.Order{
          CustomerID: input.CustomerID,
      })
      return order, err
  }
  ```

- [ ] **Goroutine safety**: Không có unmanaged goroutines
  ```go
  // ❌ SAI - Unmanaged goroutine
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // ❌ Fire and forget - không handle error, không có timeout
      go func() {
          uc.notificationClient.SendEmail(order.CustomerID, "Order created")
      }()
      
      return order, nil
  }
  
  // ✅ ĐÚNG - Sử dụng errgroup
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // Sử dụng errgroup để manage goroutines
      g, ctx := errgroup.WithContext(ctx)
      
      // Send notification
      g.Go(func() error {
          return uc.notificationClient.SendEmail(ctx, order.CustomerID, "Order created")
      })
      
      // Update inventory
      g.Go(func() error {
          return uc.warehouseClient.ReserveStock(ctx, order.Items)
      })
      
      // Wait for all goroutines
      if err := g.Wait(); err != nil {
          uc.logger.Error("failed to process order", "error", err)
          // Decide: rollback or continue
      }
      
      return order, nil
  }
  
  // ✅ ĐÚNG - Async với event (recommended)
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // Publish event - worker sẽ xử lý async
      uc.eventBus.Publish(ctx, "order.created", order)
      
      return order, nil
  }
  ```

- [ ] **Race conditions**: Shared state được protect bằng mutex
  ```go
  // ❌ SAI - Race condition
  type OrderCache struct {
      orders map[string]*Order  // ❌ Không thread-safe
  }
  
  func (c *OrderCache) Set(id string, order *Order) {
      c.orders[id] = order  // ❌ Race condition khi concurrent access
  }
  
  func (c *OrderCache) Get(id string) *Order {
      return c.orders[id]  // ❌ Race condition
  }
  
  // ✅ ĐÚNG - Sử dụng mutex
  type OrderCache struct {
      mu     sync.RWMutex
      orders map[string]*Order
  }
  
  func (c *OrderCache) Set(id string, order *Order) {
      c.mu.Lock()
      defer c.mu.Unlock()
      c.orders[id] = order
  }
  
  func (c *OrderCache) Get(id string) *Order {
      c.mu.RLock()
      defer c.mu.RUnlock()
      return c.orders[id]
  }
  
  // ✅ TỐT HƠN - Sử dụng sync.Map (built-in thread-safe)
  type OrderCache struct {
      orders sync.Map
  }
  
  func (c *OrderCache) Set(id string, order *Order) {
      c.orders.Store(id, order)
  }
  
  func (c *OrderCache) Get(id string) (*Order, bool) {
      val, ok := c.orders.Load(id)
      if !ok {
          return nil, false
      }
      return val.(*Order), true
  }
  ```

- [ ] **Idempotency**: Critical operations handle retries safely
  ```go
  // ❌ SAI - Không idempotent
  func (uc *PaymentUsecase) ProcessPayment(ctx context.Context, orderID string, amount float64) error {
      // ❌ Retry sẽ tạo multiple payments
      payment := &Payment{
          OrderID: orderID,
          Amount:  amount,
          Status:  "pending",
      }
      return uc.paymentRepo.Create(ctx, payment)
  }
  
  // ✅ ĐÚNG - Idempotent với idempotency key
  func (uc *PaymentUsecase) ProcessPayment(ctx context.Context, input *ProcessPaymentInput) (*Payment, error) {
      // Check if payment already exists
      existing, err := uc.paymentRepo.FindByIdempotencyKey(ctx, input.IdempotencyKey)
      if err == nil {
          // Payment already processed
          return existing, nil
      }
      if !errors.Is(err, ErrNotFound) {
          return nil, err
      }
      
      // Create new payment
      payment := &Payment{
          OrderID:         input.OrderID,
          Amount:          input.Amount,
          IdempotencyKey:  input.IdempotencyKey,
          Status:          "pending",
      }
      
      if err := uc.paymentRepo.Create(ctx, payment); err != nil {
          // Check for unique constraint violation
          if errors.Is(err, ErrDuplicateKey) {
              // Another request created it, fetch and return
              return uc.paymentRepo.FindByIdempotencyKey(ctx, input.IdempotencyKey)
          }
          return nil, err
      }
      
      return payment, nil
  }
  
  // Migration: Add unique constraint
  // ALTER TABLE payments ADD CONSTRAINT uk_payments_idempotency_key UNIQUE (idempotency_key);
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: Fire-and-forget goroutines**
```go
// ❌ SAI - Nhiều vấn đề
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    order, _ := uc.orderRepo.Create(ctx, order)
    
    // ❌ Vấn đề 1: Không handle error
    // ❌ Vấn đề 2: Không có timeout
    // ❌ Vấn đề 3: Không có panic recovery
    // ❌ Vấn đề 4: Context không được respect
    go func() {
        uc.sendNotification(order)
        uc.updateInventory(order)
        uc.createInvoice(order)
    }()
    
    return order, nil
}

// ✅ ĐÚNG - Sử dụng worker pattern
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    order, err := uc.orderRepo.Create(ctx, order)
    if err != nil {
        return nil, err
    }
    
    // Publish event - worker sẽ xử lý với retry, timeout, monitoring
    if err := uc.eventBus.Publish(ctx, "order.created", order); err != nil {
        uc.logger.Error("failed to publish order.created event", "error", err)
        // Decide: fail or continue
    }
    
    return order, nil
}
```

**Lỗi 2: Không handle context cancellation**
```go
// ❌ SAI
func (uc *OrderUsecase) ProcessLargeOrder(ctx context.Context, orderID string) error {
    items, _ := uc.orderRepo.GetItems(ctx, orderID)
    
    // ❌ Không check context trong loop
    for _, item := range items {
        // Long running operation
        uc.processItem(ctx, item)
    }
    
    return nil
}

// ✅ ĐÚNG
func (uc *OrderUsecase) ProcessLargeOrder(ctx context.Context, orderID string) error {
    items, err := uc.orderRepo.GetItems(ctx, orderID)
    if err != nil {
        return err
    }
    
    for _, item := range items {
        // Check context cancellation
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
        
        if err := uc.processItem(ctx, item); err != nil {
            return err
        }
    }
    
    return nil
}
```

**Lỗi 3: Double-charge risk (không idempotent)**
```go
// ❌ SAI - Có thể charge 2 lần
func (uc *PaymentUsecase) ChargeCustomer(ctx context.Context, orderID string, amount float64) error {
    // ❌ Nếu request retry, sẽ charge 2 lần
    payment := &Payment{
        OrderID: orderID,
        Amount:  amount,
    }
    
    // Call payment gateway
    result, err := uc.paymentGateway.Charge(ctx, amount)
    if err != nil {
        return err
    }
    
    payment.TransactionID = result.TransactionID
    return uc.paymentRepo.Create(ctx, payment)
}

// ✅ ĐÚNG - Idempotent
func (uc *PaymentUsecase) ChargeCustomer(ctx context.Context, input *ChargeInput) (*Payment, error) {
    // Check existing payment
    existing, err := uc.paymentRepo.FindByIdempotencyKey(ctx, input.IdempotencyKey)
    if err == nil {
        return existing, nil
    }
    
    // Create payment record FIRST (pending state)
    payment := &Payment{
        OrderID:        input.OrderID,
        Amount:         input.Amount,
        IdempotencyKey: input.IdempotencyKey,
        Status:         "pending",
    }
    
    if err := uc.paymentRepo.Create(ctx, payment); err != nil {
        if errors.Is(err, ErrDuplicateKey) {
            // Concurrent request created it
            return uc.paymentRepo.FindByIdempotencyKey(ctx, input.IdempotencyKey)
        }
        return nil, err
    }
    
    // Then charge (with payment ID as idempotency key to gateway)
    result, err := uc.paymentGateway.Charge(ctx, &ChargeRequest{
        Amount:         input.Amount,
        IdempotencyKey: payment.ID,
    })
    if err != nil {
        // Update status to failed
        payment.Status = "failed"
        payment.ErrorMessage = err.Error()
        uc.paymentRepo.Update(ctx, payment)
        return nil, err
    }
    
    // Update with transaction ID
    payment.TransactionID = result.TransactionID
    payment.Status = "completed"
    uc.paymentRepo.Update(ctx, payment)
    
    return payment, nil
}
```

#### 📝 Cách review:
1. Search `go func` trong code → check có manage không
2. Search `context.Context` → check có truyền đầy đủ không
3. Check critical operations (payment, inventory) → có idempotency key không
4. Check shared state (maps, slices) → có mutex không
5. Run `go test -race` → check race conditions

---

### 4. 💽 DATA LAYER & PERSISTENCE

#### ✅ Điều kiện đạt chuẩn:

- [ ] **Transaction boundaries**: Multi-write operations dùng transaction
  ```go
  // ❌ SAI - Không dùng transaction
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // ❌ Nếu CreatePayment fail, Order đã được tạo → inconsistent
      order := &Order{CustomerID: input.CustomerID}
      if err := uc.orderRepo.Create(ctx, order); err != nil {
          return nil, err
      }
      
      payment := &Payment{OrderID: order.ID, Amount: input.Amount}
      if err := uc.paymentRepo.Create(ctx, payment); err != nil {
          return nil, err  // ❌ Order đã tạo nhưng payment fail
      }
      
      return order, nil
  }
  
  // ✅ ĐÚNG - Sử dụng transaction
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      var order *Order
      
      err := uc.txManager.InTx(ctx, func(ctx context.Context) error {
          // Tất cả operations trong cùng 1 transaction
          order = &Order{CustomerID: input.CustomerID}
          if err := uc.orderRepo.Create(ctx, order); err != nil {
              return err
          }
          
          payment := &Payment{OrderID: order.ID, Amount: input.Amount}
          if err := uc.paymentRepo.Create(ctx, payment); err != nil {
              return err  // ✅ Rollback cả order và payment
          }
          
          // Publish event trong transaction (outbox pattern)
          if err := uc.outboxRepo.Save(ctx, "order.created", order); err != nil {
              return err
          }
          
          return nil
      })
      
      if err != nil {
          return nil, err
      }
      
      return order, nil
  }
  ```

- [ ] **Query optimization**: Không có N+1 queries
  ```go
  // ❌ SAI - N+1 query problem
  func (r *OrderRepository) GetOrdersWithItems(ctx context.Context, customerID string) ([]*Order, error) {
      // Query 1: Get orders
      orders, err := r.db.Where("customer_id = ?", customerID).Find(&orders).Error
      if err != nil {
          return nil, err
      }
      
      // Query 2, 3, 4, ... N+1: Get items for each order
      for i, order := range orders {
          var items []*OrderItem
          if err := r.db.Where("order_id = ?", order.ID).Find(&items).Error; err != nil {
              return nil, err
          }
          orders[i].Items = items  // ❌ N+1 queries
      }
      
      return orders, nil
  }
  
  // ✅ ĐÚNG - Sử dụng Preload
  func (r *OrderRepository) GetOrdersWithItems(ctx context.Context, customerID string) ([]*Order, error) {
      var orders []*Order
      
      // Single query với JOIN
      err := r.db.WithContext(ctx).
          Preload("Items").
          Preload("Items.Product").  // Nested preload nếu cần
          Where("customer_id = ?", customerID).
          Find(&orders).Error
      
      return orders, err
  }
  
  // ✅ TỐT HƠN - Custom query với explicit JOIN
  func (r *OrderRepository) GetOrdersWithItems(ctx context.Context, customerID string) ([]*Order, error) {
      var orders []*Order
      
      err := r.db.WithContext(ctx).
          Select("orders.*, order_items.*").
          Joins("LEFT JOIN order_items ON order_items.order_id = orders.id").
          Where("orders.customer_id = ?", customerID).
          Scan(&orders).Error
      
      return orders, err
  }
  ```

- [ ] **Proper indexing**: Lookup columns có index
  ```sql
  -- ❌ SAI - Không có index
  CREATE TABLE orders (
      id UUID PRIMARY KEY,
      customer_id UUID NOT NULL,
      status VARCHAR(50) NOT NULL,
      created_at TIMESTAMP NOT NULL
  );
  
  -- Query này sẽ chậm vì full table scan
  SELECT * FROM orders WHERE customer_id = '...' AND status = 'pending';
  
  -- ✅ ĐÚNG - Có index
  CREATE TABLE orders (
      id UUID PRIMARY KEY,
      customer_id UUID NOT NULL,
      status VARCHAR(50) NOT NULL,
      created_at TIMESTAMP NOT NULL
  );
  
  -- Composite index cho query pattern thường dùng
  CREATE INDEX idx_orders_customer_status ON orders(customer_id, status);
  CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
  
  -- Query sẽ nhanh với index
  SELECT * FROM orders WHERE customer_id = '...' AND status = 'pending';
  ```

- [ ] **Migration management**: Schema changes có script
  ```go
  // ✅ ĐÚNG - Migration file structure
  // migrations/001_create_orders_table.sql
  -- +goose Up
  CREATE TABLE orders (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      customer_id UUID NOT NULL,
      status VARCHAR(50) NOT NULL DEFAULT 'pending',
      total_amount DECIMAL(10,2) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      deleted_at TIMESTAMP
  );
  
  CREATE INDEX idx_orders_customer_id ON orders(customer_id);
  CREATE INDEX idx_orders_status ON orders(status);
  CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
  
  -- +goose Down
  DROP TABLE IF EXISTS orders;
  
  // migrations/002_add_shipping_address_to_orders.sql
  -- +goose Up
  ALTER TABLE orders ADD COLUMN shipping_address_id UUID;
  CREATE INDEX idx_orders_shipping_address ON orders(shipping_address_id);
  
  -- +goose Down
  ALTER TABLE orders DROP COLUMN shipping_address_id;
  
  // ❌ SAI - Không có migration, dùng AutoMigrate
  func InitDB(db *gorm.DB) {
      // ❌ Không nên dùng AutoMigrate trong production
      db.AutoMigrate(&Order{}, &OrderItem{}, &Payment{})
  }
  ```

- [ ] **Repository pattern**: DB implementation ẩn sau interface
  ```go
  // ✅ ĐÚNG - Repository interface
  // internal/biz/order/repository.go
  type OrderRepository interface {
      Create(ctx context.Context, order *Order) error
      Update(ctx context.Context, order *Order) error
      Delete(ctx context.Context, id string) error
      FindByID(ctx context.Context, id string) (*Order, error)
      FindByCustomerID(ctx context.Context, customerID string) ([]*Order, error)
      List(ctx context.Context, filter *OrderFilter) ([]*Order, int64, error)
  }
  
  // internal/data/postgres/order.go
  type orderRepository struct {
      db *gorm.DB
  }
  
  func NewOrderRepository(db *gorm.DB) biz.OrderRepository {
      return &orderRepository{db: db}
  }
  
  func (r *orderRepository) Create(ctx context.Context, order *biz.Order) error {
      // Convert biz.Order to model.Order
      model := &model.Order{
          ID:         order.ID,
          CustomerID: order.CustomerID,
          Status:     string(order.Status),
      }
      
      return r.db.WithContext(ctx).Create(model).Error
  }
  
  // ❌ SAI - Expose GORM trong interface
  type OrderRepository interface {
      Create(ctx context.Context, order *model.Order) error  // ❌ Expose model
      GetDB() *gorm.DB  // ❌ Expose gorm.DB
  }
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: Không dùng transaction cho multi-write**
```go
// ❌ SAI - Partial failure risk
func (uc *OrderUsecase) CancelOrder(ctx context.Context, orderID string) error {
    // Update order status
    if err := uc.orderRepo.UpdateStatus(ctx, orderID, "cancelled"); err != nil {
        return err
    }
    
    // Release inventory
    if err := uc.warehouseClient.ReleaseStock(ctx, orderID); err != nil {
        return err  // ❌ Order đã cancelled nhưng stock chưa release
    }
    
    // Refund payment
    if err := uc.paymentClient.Refund(ctx, orderID); err != nil {
        return err  // ❌ Order cancelled, stock released, nhưng refund fail
    }
    
    return nil
}

// ✅ ĐÚNG - Sử dụng Saga pattern hoặc Outbox
func (uc *OrderUsecase) CancelOrder(ctx context.Context, orderID string) error {
    return uc.txManager.InTx(ctx, func(ctx context.Context) error {
        // Update order status
        if err := uc.orderRepo.UpdateStatus(ctx, orderID, "cancelled"); err != nil {
            return err
        }
        
        // Save events to outbox (trong cùng transaction)
        events := []OutboxEvent{
            {Type: "order.cancelled", Payload: orderID},
            {Type: "inventory.release", Payload: orderID},
            {Type: "payment.refund", Payload: orderID},
        }
        
        for _, event := range events {
            if err := uc.outboxRepo.Save(ctx, event); err != nil {
                return err  // ✅ Rollback tất cả
            }
        }
        
        return nil
    })
    
    // Worker sẽ process outbox events với retry
}
```

**Lỗi 2: N+1 query problem**
```go
// ❌ SAI
func (s *OrderService) ListOrders(ctx context.Context, req *pb.ListOrdersRequest) (*pb.ListOrdersResponse, error) {
    orders, err := s.orderRepo.List(ctx, req.CustomerId)
    if err != nil {
        return nil, err
    }
    
    var pbOrders []*pb.Order
    for _, order := range orders {
        // ❌ N+1: Query items cho mỗi order
        items, _ := s.orderItemRepo.GetByOrderID(ctx, order.ID)
        
        // ❌ N+1: Query customer cho mỗi order
        customer, _ := s.customerClient.GetCustomer(ctx, order.CustomerID)
        
        pbOrders = append(pbOrders, &pb.Order{
            Id:       order.ID,
            Items:    convertItems(items),
            Customer: convertCustomer(customer),
        })
    }
    
    return &pb.ListOrdersResponse{Orders: pbOrders}, nil
}

// ✅ ĐÚNG - Batch loading
func (s *OrderService) ListOrders(ctx context.Context, req *pb.ListOrdersRequest) (*pb.ListOrdersResponse, error) {
    // Get orders với preload
    orders, err := s.orderRepo.ListWithItems(ctx, req.CustomerId)
    if err != nil {
        return nil, err
    }
    
    // Collect unique customer IDs
    customerIDs := make([]string, 0, len(orders))
    customerMap := make(map[string]bool)
    for _, order := range orders {
        if !customerMap[order.CustomerID] {
            customerIDs = append(customerIDs, order.CustomerID)
            customerMap[order.CustomerID] = true
        }
    }
    
    // Batch get customers (1 query thay vì N queries)
    customers, err := s.customerClient.BatchGetCustomers(ctx, customerIDs)
    if err != nil {
        return nil, err
    }
    
    // Build response
    var pbOrders []*pb.Order
    for _, order := range orders {
        pbOrders = append(pbOrders, &pb.Order{
            Id:       order.ID,
            Items:    convertItems(order.Items),
            Customer: customers[order.CustomerID],
        })
    }
    
    return &pb.ListOrdersResponse{Orders: pbOrders}, nil
}
```

**Lỗi 3: Missing indexes**
```sql
-- ❌ SAI - Slow query
EXPLAIN ANALYZE
SELECT * FROM orders 
WHERE customer_id = '123' 
  AND status = 'pending' 
  AND created_at > '2024-01-01'
ORDER BY created_at DESC
LIMIT 20;

-- Result: Seq Scan on orders (cost=0.00..1000.00 rows=100 width=100)
-- ❌ Full table scan - CHẬM!

-- ✅ ĐÚNG - Add composite index
CREATE INDEX idx_orders_customer_status_created 
ON orders(customer_id, status, created_at DESC);

EXPLAIN ANALYZE
SELECT * FROM orders 
WHERE customer_id = '123' 
  AND status = 'pending' 
  AND created_at > '2024-01-01'
ORDER BY created_at DESC
LIMIT 20;

-- Result: Index Scan using idx_orders_customer_status_created (cost=0.00..10.00 rows=20 width=100)
-- ✅ Index scan - NHANH!
```

#### 📝 Cách review:
1. Check xem có dùng transaction cho multi-write không
2. Search `for` loop + DB query → check N+1
3. Check migrations folder → có đầy đủ Up/Down không
4. Review query patterns → có index phù hợp không
5. Check repository → có expose GORM không

---

### 5. 🛡 SECURITY

#### ✅ Điều kiện đạt chuẩn:

- [ ] **Authentication & Authorization**: Tất cả endpoints được protect
  ```go
  // ✅ ĐÚNG - Middleware authentication
  // internal/server/http.go
  func NewHTTPServer(
      authMiddleware middleware.AuthMiddleware,
      orderService *service.OrderService,
  ) *http.Server {
      router := gin.New()
      
      // Public endpoints (không cần auth)
      router.GET("/health", healthHandler)
      router.GET("/metrics", metricsHandler)
      
      // Protected endpoints (cần auth)
      api := router.Group("/api/v1")
      api.Use(authMiddleware.Authenticate())  // ✅ Require authentication
      {
          // Authorization check trong handler
          api.POST("/orders", orderService.CreateOrder)
          api.GET("/orders/:id", orderService.GetOrder)
          api.PUT("/orders/:id", orderService.UpdateOrder)
      }
      
      return router
  }
  
  // internal/service/order.go
  func (s *OrderService) GetOrder(ctx context.Context, req *pb.GetOrderRequest) (*pb.GetOrderResponse, error) {
      // Get user from context (set by auth middleware)
      userID := ctx.Value("user_id").(string)
      userRole := ctx.Value("user_role").(string)
      
      order, err := s.orderUsecase.GetOrder(ctx, req.OrderId)
      if err != nil {
          return nil, err
      }
      
      // ✅ Authorization check: User chỉ được xem order của mình
      if userRole != "admin" && order.CustomerID != userID {
          return nil, status.Error(codes.PermissionDenied, "access denied")
      }
      
      return &pb.GetOrderResponse{Order: convertToProto(order)}, nil
  }
  
  // ❌ SAI - Không có auth check
  func (s *OrderService) GetOrder(ctx context.Context, req *pb.GetOrderRequest) (*pb.GetOrderResponse, error) {
      // ❌ Không check user có quyền xem order này không
      order, err := s.orderUsecase.GetOrder(ctx, req.OrderId)
      return &pb.GetOrderResponse{Order: convertToProto(order)}, err
  }
  ```

- [ ] **Input sanitization**: Prevent SQL injection, XSS
  ```go
  // ✅ ĐÚNG - Sử dụng parameterized queries
  func (r *OrderRepository) Search(ctx context.Context, keyword string) ([]*Order, error) {
      var orders []*Order
      
      // ✅ Parameterized query - safe from SQL injection
      err := r.db.WithContext(ctx).
          Where("order_number LIKE ? OR customer_name LIKE ?", "%"+keyword+"%", "%"+keyword+"%").
          Find(&orders).Error
      
      return orders, err
  }
  
  // ❌ SAI - SQL injection vulnerability
  func (r *OrderRepository) Search(ctx context.Context, keyword string) ([]*Order, error) {
      var orders []*Order
      
      // ❌ String concatenation - SQL injection risk!
      query := fmt.Sprintf("SELECT * FROM orders WHERE order_number LIKE '%%%s%%'", keyword)
      err := r.db.Raw(query).Scan(&orders).Error
      
      return orders, err
  }
  
  // Example attack:
  // keyword = "'; DROP TABLE orders; --"
  // query = "SELECT * FROM orders WHERE order_number LIKE '%'; DROP TABLE orders; --%'"
  ```

- [ ] **Secrets management**: Không hardcode credentials
  ```go
  // ❌ SAI - Hardcoded secrets
  func ConnectDB() (*gorm.DB, error) {
      // ❌ KHÔNG BAO GIỜ hardcode credentials
      dsn := "postgres://admin:password123@localhost:5432/mydb"
      return gorm.Open(postgres.Open(dsn), &gorm.Config{})
  }
  
  // ✅ ĐÚNG - Load từ environment variables
  func ConnectDB() (*gorm.DB, error) {
      dsn := fmt.Sprintf(
          "postgres://%s:%s@%s:%s/%s",
          os.Getenv("DB_USER"),
          os.Getenv("DB_PASSWORD"),
          os.Getenv("DB_HOST"),
          os.Getenv("DB_PORT"),
          os.Getenv("DB_NAME"),
      )
      return gorm.Open(postgres.Open(dsn), &gorm.Config{})
  }
  
  // ✅ TỐT HƠN - Sử dụng config struct
  type Config struct {
      Database DatabaseConfig `mapstructure:"database"`
  }
  
  type DatabaseConfig struct {
      Host     string `mapstructure:"host"`
      Port     int    `mapstructure:"port"`
      User     string `mapstructure:"user"`
      Password string `mapstructure:"password"`
      DBName   string `mapstructure:"dbname"`
  }
  
  func LoadConfig() (*Config, error) {
      viper.SetConfigFile("config.yaml")
      viper.AutomaticEnv()  // Override với env vars
      
      if err := viper.ReadInConfig(); err != nil {
          return nil, err
      }
      
      var config Config
      if err := viper.Unmarshal(&config); err != nil {
          return nil, err
      }
      
      return &config, nil
  }
  ```

- [ ] **Sensitive data logging**: Không log passwords, tokens
  ```go
  // ❌ SAI - Log sensitive data
  func (s *AuthService) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
      // ❌ KHÔNG BAO GIỜ log password
      s.logger.Info("login attempt", 
          "email", req.Email, 
          "password", req.Password)  // ❌ NGUY HIỂM!
      
      user, err := s.authUsecase.Login(ctx, req.Email, req.Password)
      if err != nil {
          return nil, err
      }
      
      // ❌ KHÔNG log token
      s.logger.Info("login successful", 
          "user_id", user.ID, 
          "token", user.Token)  // ❌ NGUY HIỂM!
      
      return &pb.LoginResponse{Token: user.Token}, nil
  }
  
  // ✅ ĐÚNG - Không log sensitive data
  func (s *AuthService) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
      // ✅ Chỉ log email, không log password
      s.logger.Info("login attempt", "email", req.Email)
      
      user, err := s.authUsecase.Login(ctx, req.Email, req.Password)
      if err != nil {
          s.logger.Warn("login failed", "email", req.Email, "error", err)
          return nil, err
      }
      
      // ✅ Log user_id, không log token
      s.logger.Info("login successful", "user_id", user.ID)
      
      return &pb.LoginResponse{Token: user.Token}, nil
  }
  
  // ✅ TỐT HƠN - Sử dụng structured logging với redaction
  type SensitiveString string
  
  func (s SensitiveString) MarshalJSON() ([]byte, error) {
      return []byte(`"[REDACTED]"`), nil
  }
  
  func (s *AuthService) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
      s.logger.InfoContext(ctx, "login attempt", 
          "email", req.Email,
          "password", SensitiveString(req.Password))  // ✅ Auto redacted
      
      // ...
  }
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: Missing authorization check**
```go
// ❌ SAI - Chỉ có authentication, không có authorization
func (s *OrderService) DeleteOrder(ctx context.Context, req *pb.DeleteOrderRequest) (*pb.DeleteOrderResponse, error) {
    // ❌ Không check user có quyền delete order này không
    // Bất kỳ authenticated user nào cũng có thể delete bất kỳ order nào!
    err := s.orderUsecase.DeleteOrder(ctx, req.OrderId)
    return &pb.DeleteOrderResponse{}, err
}

// ✅ ĐÚNG - Check authorization
func (s *OrderService) DeleteOrder(ctx context.Context, req *pb.DeleteOrderRequest) (*pb.DeleteOrderResponse, error) {
    userID := ctx.Value("user_id").(string)
    userRole := ctx.Value("user_role").(string)
    
    // Get order to check ownership
    order, err := s.orderUsecase.GetOrder(ctx, req.OrderId)
    if err != nil {
        return nil, err
    }
    
    // ✅ Authorization check
    if userRole != "admin" && order.CustomerID != userID {
        return nil, status.Error(codes.PermissionDenied, "you can only delete your own orders")
    }
    
    // Additional business rule check
    if order.Status == "shipped" || order.Status == "delivered" {
        return nil, status.Error(codes.FailedPrecondition, "cannot delete shipped orders")
    }
    
    err = s.orderUsecase.DeleteOrder(ctx, req.OrderId)
    return &pb.DeleteOrderResponse{}, err
}
```

**Lỗi 2: SQL Injection vulnerability**
```go
// ❌ SAI - SQL injection
func (r *ProductRepository) SearchByName(ctx context.Context, name string) ([]*Product, error) {
    var products []*Product
    
    // ❌ String concatenation - SQL injection!
    query := "SELECT * FROM products WHERE name LIKE '%" + name + "%'"
    err := r.db.Raw(query).Scan(&products).Error
    
    return products, err
}

// Attack example:
// name = "'; DELETE FROM products WHERE '1'='1"
// Final query: SELECT * FROM products WHERE name LIKE '%'; DELETE FROM products WHERE '1'='1%'

// ✅ ĐÚNG - Parameterized query
func (r *ProductRepository) SearchByName(ctx context.Context, name string) ([]*Product, error) {
    var products []*Product
    
    // ✅ Parameterized query - safe!
    err := r.db.WithContext(ctx).
        Where("name LIKE ?", "%"+name+"%").
        Find(&products).Error
    
    return products, err
}
```

**Lỗi 3: Exposed secrets in code**
```go
// ❌ SAI - Secrets trong code
const (
    JWTSecret = "my-super-secret-key-123"  // ❌ NGUY HIỂM!
    APIKey    = "sk_live_abc123xyz"        // ❌ NGUY HIỂM!
)

func GenerateToken(userID string) (string, error) {
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(time.Hour * 24).Unix(),
    })
    return token.SignedString([]byte(JWTSecret))
}

// ✅ ĐÚNG - Load từ environment
type Config struct {
    JWTSecret string
    APIKey    string
}

func LoadConfig() (*Config, error) {
    jwtSecret := os.Getenv("JWT_SECRET")
    if jwtSecret == "" {
        return nil, errors.New("JWT_SECRET is required")
    }
    
    apiKey := os.Getenv("API_KEY")
    if apiKey == "" {
        return nil, errors.New("API_KEY is required")
    }
    
    return &Config{
        JWTSecret: jwtSecret,
        APIKey:    apiKey,
    }, nil
}

func GenerateToken(userID string, config *Config) (string, error) {
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(time.Hour * 24).Unix(),
    })
    return token.SignedString([]byte(config.JWTSecret))
}
```

#### 📝 Cách review:
1. Check middleware stack → có auth middleware không
2. Check handlers → có authorization check không
3. Search `fmt.Sprintf` + SQL → check SQL injection
4. Search hardcoded strings → check secrets
5. Search log statements → check sensitive data
6. Run security scanner: `gosec ./...`

---

### 6. ⚡ PERFORMANCE & SCALABILITY

#### ✅ Điều kiện đạt chuẩn:

- [ ] **Caching strategy**: Cache cho read-heavy data
  ```go
  // ❌ SAI - Không có cache, query DB mỗi lần
  func (uc *ProductUsecase) GetProduct(ctx context.Context, id string) (*Product, error) {
      // ❌ Mỗi request đều query DB
      return uc.productRepo.FindByID(ctx, id)
  }
  
  // ✅ ĐÚNG - Cache-aside pattern
  func (uc *ProductUsecase) GetProduct(ctx context.Context, id string) (*Product, error) {
      // Try cache first
      cacheKey := fmt.Sprintf("product:%s", id)
      
      var product Product
      err := uc.cache.Get(ctx, cacheKey, &product)
      if err == nil {
          // Cache hit
          return &product, nil
      }
      
      // Cache miss - query DB
      product, err := uc.productRepo.FindByID(ctx, id)
      if err != nil {
          return nil, err
      }
      
      // Save to cache
      uc.cache.Set(ctx, cacheKey, product, 5*time.Minute)
      
      return product, nil
  }
  
  // ✅ Cache invalidation khi update
  func (uc *ProductUsecase) UpdateProduct(ctx context.Context, product *Product) error {
      // Update DB
      if err := uc.productRepo.Update(ctx, product); err != nil {
          return err
      }
      
      // Invalidate cache
      cacheKey := fmt.Sprintf("product:%s", product.ID)
      uc.cache.Delete(ctx, cacheKey)
      
      return nil
  }
  ```

- [ ] **Bulk operations**: Batch processing cho high-volume
  ```go
  // ❌ SAI - Insert từng record một
  func (uc *OrderUsecase) ImportOrders(ctx context.Context, orders []*Order) error {
      for _, order := range orders {
          // ❌ N queries - CHẬM!
          if err := uc.orderRepo.Create(ctx, order); err != nil {
              return err
          }
      }
      return nil
  }
  
  // ✅ ĐÚNG - Bulk insert
  func (uc *OrderUsecase) ImportOrders(ctx context.Context, orders []*Order) error {
      // Single query - NHANH!
      return uc.orderRepo.BulkCreate(ctx, orders)
  }
  
  // Repository implementation
  func (r *OrderRepository) BulkCreate(ctx context.Context, orders []*Order) error {
      // GORM batch insert
      return r.db.WithContext(ctx).CreateInBatches(orders, 100).Error
  }
  
  // ✅ TỐT HƠN - Batch với progress tracking
  func (uc *OrderUsecase) ImportOrders(ctx context.Context, orders []*Order) error {
      batchSize := 100
      
      for i := 0; i < len(orders); i += batchSize {
          end := i + batchSize
          if end > len(orders) {
              end = len(orders)
          }
          
          batch := orders[i:end]
          if err := uc.orderRepo.BulkCreate(ctx, batch); err != nil {
              return fmt.Errorf("failed at batch %d-%d: %w", i, end, err)
          }
          
          // Log progress
          uc.logger.Info("imported batch", "from", i, "to", end, "total", len(orders))
      }
      
      return nil
  }
  ```

- [ ] **Connection pooling**: DB/Redis connection pools configured
  ```go
  // ❌ SAI - Không config connection pool
  func InitDB(dsn string) (*gorm.DB, error) {
      db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
      return db, err
  }
  
  // ✅ ĐÚNG - Config connection pool
  func InitDB(dsn string) (*gorm.DB, error) {
      db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
          Logger: logger.Default.LogMode(logger.Info),
      })
      if err != nil {
          return nil, err
      }
      
      sqlDB, err := db.DB()
      if err != nil {
          return nil, err
      }
      
      // ✅ Connection pool settings
      sqlDB.SetMaxOpenConns(25)                  // Max open connections
      sqlDB.SetMaxIdleConns(5)                   // Max idle connections
      sqlDB.SetConnMaxLifetime(5 * time.Minute)  // Max connection lifetime
      sqlDB.SetConnMaxIdleTime(10 * time.Minute) // Max idle time
      
      return db, nil
  }
  
  // ✅ Redis connection pool
  func InitRedis(addr string) (*redis.Client, error) {
      client := redis.NewClient(&redis.Options{
          Addr:         addr,
          Password:     os.Getenv("REDIS_PASSWORD"),
          DB:           0,
          PoolSize:     10,                    // Connection pool size
          MinIdleConns: 5,                     // Min idle connections
          MaxRetries:   3,                     // Max retries
          DialTimeout:  5 * time.Second,       // Connection timeout
          ReadTimeout:  3 * time.Second,       // Read timeout
          WriteTimeout: 3 * time.Second,       // Write timeout
      })
      
      // Test connection
      if err := client.Ping(context.Background()).Err(); err != nil {
          return nil, err
      }
      
      return client, nil
  }
  ```

- [ ] **Pagination**: Large result sets có pagination
  ```go
  // ❌ SAI - Không có pagination
  func (r *OrderRepository) List(ctx context.Context, customerID string) ([]*Order, error) {
      var orders []*Order
      
      // ❌ Load tất cả orders - có thể hàng triệu records!
      err := r.db.WithContext(ctx).
          Where("customer_id = ?", customerID).
          Find(&orders).Error
      
      return orders, err
  }
  
  // ✅ ĐÚNG - Offset-based pagination
  func (r *OrderRepository) List(ctx context.Context, filter *OrderFilter) ([]*Order, int64, error) {
      var orders []*Order
      var total int64
      
      query := r.db.WithContext(ctx).Model(&Order{})
      
      // Apply filters
      if filter.CustomerID != "" {
          query = query.Where("customer_id = ?", filter.CustomerID)
      }
      if filter.Status != "" {
          query = query.Where("status = ?", filter.Status)
      }
      
      // Count total
      if err := query.Count(&total).Error; err != nil {
          return nil, 0, err
      }
      
      // Apply pagination
      offset := (filter.Page - 1) * filter.PageSize
      err := query.
          Offset(offset).
          Limit(filter.PageSize).
          Order("created_at DESC").
          Find(&orders).Error
      
      return orders, total, err
  }
  
  // ✅ TỐT HƠN - Cursor-based pagination (cho large datasets)
  func (r *OrderRepository) ListCursor(ctx context.Context, filter *OrderFilter) ([]*Order, string, error) {
      var orders []*Order
      
      query := r.db.WithContext(ctx).Model(&Order{})
      
      // Apply cursor
      if filter.Cursor != "" {
          cursorTime, err := time.Parse(time.RFC3339, filter.Cursor)
          if err != nil {
              return nil, "", err
          }
          query = query.Where("created_at < ?", cursorTime)
      }
      
      // Get page + 1 to check if there's more
      err := query.
          Order("created_at DESC").
          Limit(filter.PageSize + 1).
          Find(&orders).Error
      if err != nil {
          return nil, "", err
      }
      
      // Check if there's next page
      var nextCursor string
      if len(orders) > filter.PageSize {
          nextCursor = orders[filter.PageSize-1].CreatedAt.Format(time.RFC3339)
          orders = orders[:filter.PageSize]
      }
      
      return orders, nextCursor, nil
  }
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: Không có cache cho hot data**
```go
// ❌ SAI - Query DB mỗi lần
func (uc *ProductUsecase) GetProductPrice(ctx context.Context, productID string) (float64, error) {
    // ❌ Price được query rất nhiều lần (mỗi lần add to cart, checkout, etc)
    // Nhưng không cache → DB overload
    product, err := uc.productRepo.FindByID(ctx, productID)
    if err != nil {
        return 0, err
    }
    return product.Price, nil
}

// ✅ ĐÚNG - Cache với TTL ngắn
func (uc *ProductUsecase) GetProductPrice(ctx context.Context, productID string) (float64, error) {
    cacheKey := fmt.Sprintf("product:price:%s", productID)
    
    // Try cache
    var price float64
    err := uc.cache.Get(ctx, cacheKey, &price)
    if err == nil {
        return price, nil
    }
    
    // Cache miss
    product, err := uc.productRepo.FindByID(ctx, productID)
    if err != nil {
        return 0, err
    }
    
    // Cache với TTL ngắn (vì price có thể thay đổi)
    uc.cache.Set(ctx, cacheKey, product.Price, 1*time.Minute)
    
    return product.Price, nil
}
```

**Lỗi 2: Load toàn bộ data không pagination**
```go
// ❌ SAI - Load tất cả
func (s *OrderService) ListOrders(ctx context.Context, req *pb.ListOrdersRequest) (*pb.ListOrdersResponse, error) {
    // ❌ Nếu customer có 10,000 orders → load hết → OOM!
    orders, err := s.orderRepo.FindByCustomerID(ctx, req.CustomerId)
    if err != nil {
        return nil, err
    }
    
    return &pb.ListOrdersResponse{
        Orders: convertOrders(orders),
    }, nil
}

// ✅ ĐÚNG - Pagination
func (s *OrderService) ListOrders(ctx context.Context, req *pb.ListOrdersRequest) (*pb.ListOrdersResponse, error) {
    // Default pagination
    page := req.Page
    if page < 1 {
        page = 1
    }
    pageSize := req.PageSize
    if pageSize < 1 || pageSize > 100 {
        pageSize = 20  // Default 20, max 100
    }
    
    orders, total, err := s.orderRepo.List(ctx, &OrderFilter{
        CustomerID: req.CustomerId,
        Page:       page,
        PageSize:   pageSize,
    })
    if err != nil {
        return nil, err
    }
    
    return &pb.ListOrdersResponse{
        Orders:     convertOrders(orders),
        Total:      total,
        Page:       page,
        PageSize:   pageSize,
        TotalPages: (total + int64(pageSize) - 1) / int64(pageSize),
    }, nil
}
```

**Lỗi 3: Không config connection pool**
```go
// ❌ SAI - Default settings
func InitDB(dsn string) (*gorm.DB, error) {
    // ❌ Sử dụng default settings
    // Default MaxOpenConns = unlimited → có thể exhaust DB connections
    // Default MaxIdleConns = 2 → quá ít, mỗi request phải tạo connection mới
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    return db, err
}

// Kết quả:
// - High load → tạo quá nhiều connections → DB reject
// - Low load → connections bị close → overhead tạo connection mới

// ✅ ĐÚNG - Tune connection pool
func InitDB(dsn string) (*gorm.DB, error) {
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        return nil, err
    }
    
    sqlDB, err := db.DB()
    if err != nil {
        return nil, err
    }
    
    // ✅ Tune based on workload
    // Rule of thumb: MaxOpenConns = (available_connections / number_of_instances)
    // Example: DB có 100 connections, 4 instances → 25 per instance
    sqlDB.SetMaxOpenConns(25)
    
    // Keep some idle connections for quick reuse
    sqlDB.SetMaxIdleConns(5)
    
    // Close old connections to avoid stale connections
    sqlDB.SetConnMaxLifetime(5 * time.Minute)
    sqlDB.SetConnMaxIdleTime(10 * time.Minute)
    
    return db, nil
}
```

#### 📝 Cách review:
1. Check hot paths → có cache không
2. Check list endpoints → có pagination không
3. Check DB init → có config connection pool không
4. Check bulk operations → có batch processing không
5. Run load test → measure performance

---

### 7. 👁 OBSERVABILITY

#### ✅ Điều kiện đạt chuẩn:

- [ ] **Structured logging**: JSON logs với context fields
  ```go
  // ❌ SAI - Unstructured logging
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // ❌ Plain text log, khó parse
      log.Println("Creating order for customer:", input.CustomerID)
      
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          // ❌ Không có context
          log.Println("Error creating order:", err)
          return nil, err
      }
      
      // ❌ Không có structured fields
      log.Println("Order created successfully:", order.ID)
      return order, nil
  }
  
  // ✅ ĐÚNG - Structured logging với context
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // Extract trace_id từ context
      traceID := ctx.Value("trace_id").(string)
      
      // ✅ Structured log với fields
      uc.logger.InfoContext(ctx, "creating order",
          "trace_id", traceID,
          "customer_id", input.CustomerID,
          "items_count", len(input.Items),
      )
      
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          // ✅ Log error với context
          uc.logger.ErrorContext(ctx, "failed to create order",
              "trace_id", traceID,
              "customer_id", input.CustomerID,
              "error", err,
          )
          return nil, err
      }
      
      // ✅ Log success với important fields
      uc.logger.InfoContext(ctx, "order created",
          "trace_id", traceID,
          "order_id", order.ID,
          "customer_id", order.CustomerID,
          "total_amount", order.TotalAmount,
      )
      
      return order, nil
  }
  
  // Output (JSON format):
  // {"level":"info","time":"2026-01-16T10:30:00Z","msg":"creating order","trace_id":"abc123","customer_id":"cust_456","items_count":3}
  // {"level":"info","time":"2026-01-16T10:30:01Z","msg":"order created","trace_id":"abc123","order_id":"ord_789","customer_id":"cust_456","total_amount":150.50}
  ```

- [ ] **Metrics**: Prometheus metrics cho RED method
  ```go
  // ✅ ĐÚNG - Define metrics
  // internal/observability/metrics.go
  var (
      // Request Rate
      requestsTotal = promauto.NewCounterVec(
          prometheus.CounterOpts{
              Name: "order_requests_total",
              Help: "Total number of order requests",
          },
          []string{"method", "status"},
      )
      
      // Error Rate
      errorsTotal = promauto.NewCounterVec(
          prometheus.CounterOpts{
              Name: "order_errors_total",
              Help: "Total number of order errors",
          },
          []string{"method", "error_type"},
      )
      
      // Duration (Latency)
      requestDuration = promauto.NewHistogramVec(
          prometheus.HistogramOpts{
              Name:    "order_request_duration_seconds",
              Help:    "Order request duration in seconds",
              Buckets: prometheus.DefBuckets,
          },
          []string{"method"},
      )
      
      // Business metrics
      ordersCreated = promauto.NewCounter(
          prometheus.CounterOpts{
              Name: "orders_created_total",
              Help: "Total number of orders created",
          },
      )
      
      orderValue = promauto.NewHistogram(
          prometheus.HistogramOpts{
              Name:    "order_value_dollars",
              Help:    "Order value in dollars",
              Buckets: []float64{10, 50, 100, 500, 1000, 5000},
          },
      )
  )
  
  // ✅ Instrument code
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      start := time.Now()
      
      // Increment request counter
      requestsTotal.WithLabelValues("CreateOrder", "started").Inc()
      
      order, err := uc.orderRepo.Create(ctx, order)
      
      // Record duration
      duration := time.Since(start).Seconds()
      requestDuration.WithLabelValues("CreateOrder").Observe(duration)
      
      if err != nil {
          // Increment error counter
          errorsTotal.WithLabelValues("CreateOrder", "db_error").Inc()
          requestsTotal.WithLabelValues("CreateOrder", "failed").Inc()
          return nil, err
      }
      
      // Record business metrics
      ordersCreated.Inc()
      orderValue.Observe(order.TotalAmount)
      requestsTotal.WithLabelValues("CreateOrder", "success").Inc()
      
      return order, nil
  }
  
  // ✅ Expose metrics endpoint
  // internal/server/http.go
  func NewHTTPServer() *http.Server {
      router := gin.New()
      
      // Metrics endpoint
      router.GET("/metrics", gin.WrapH(promhttp.Handler()))
      
      return router
  }
  ```

- [ ] **Tracing**: OpenTelemetry spans cho critical paths
  ```go
  // ✅ ĐÚNG - Distributed tracing
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // Start span
      ctx, span := uc.tracer.Start(ctx, "OrderUsecase.CreateOrder")
      defer span.End()
      
      // Add attributes
      span.SetAttributes(
          attribute.String("customer_id", input.CustomerID),
          attribute.Int("items_count", len(input.Items)),
      )
      
      // Validate
      ctx, validateSpan := uc.tracer.Start(ctx, "validate_order")
      if err := uc.validateOrder(ctx, input); err != nil {
          validateSpan.RecordError(err)
          validateSpan.SetStatus(codes.Error, err.Error())
          validateSpan.End()
          return nil, err
      }
      validateSpan.End()
      
      // Create order
      ctx, createSpan := uc.tracer.Start(ctx, "create_order_db")
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          createSpan.RecordError(err)
          createSpan.SetStatus(codes.Error, err.Error())
          createSpan.End()
          return nil, err
      }
      createSpan.SetAttributes(attribute.String("order_id", order.ID))
      createSpan.End()
      
      // Call payment service
      ctx, paymentSpan := uc.tracer.Start(ctx, "create_payment")
      payment, err := uc.paymentClient.CreatePayment(ctx, &CreatePaymentRequest{
          OrderID: order.ID,
          Amount:  order.TotalAmount,
      })
      if err != nil {
          paymentSpan.RecordError(err)
          paymentSpan.SetStatus(codes.Error, err.Error())
          paymentSpan.End()
          return nil, err
      }
      paymentSpan.SetAttributes(attribute.String("payment_id", payment.ID))
      paymentSpan.End()
      
      span.SetStatus(codes.Ok, "order created successfully")
      return order, nil
  }
  ```

- [ ] **Health checks**: Liveness & readiness probes
  ```go
  // ✅ ĐÚNG - Health check endpoints
  // internal/server/http.go
  type HealthChecker struct {
      db    *gorm.DB
      redis *redis.Client
  }
  
  func (h *HealthChecker) Liveness(c *gin.Context) {
      // Liveness: Service is running
      c.JSON(200, gin.H{
          "status": "ok",
          "time":   time.Now().Unix(),
      })
  }
  
  func (h *HealthChecker) Readiness(c *gin.Context) {
      // Readiness: Service can handle requests
      ctx := c.Request.Context()
      
      checks := make(map[string]string)
      healthy := true
      
      // Check database
      sqlDB, err := h.db.DB()
      if err != nil || sqlDB.Ping() != nil {
          checks["database"] = "unhealthy"
          healthy = false
      } else {
          checks["database"] = "healthy"
      }
      
      // Check redis
      if err := h.redis.Ping(ctx).Err(); err != nil {
          checks["redis"] = "unhealthy"
          healthy = false
      } else {
          checks["redis"] = "healthy"
      }
      
      status := 200
      if !healthy {
          status = 503
      }
      
      c.JSON(status, gin.H{
          "status": map[bool]string{true: "healthy", false: "unhealthy"}[healthy],
          "checks": checks,
          "time":   time.Now().Unix(),
      })
  }
  
  func NewHTTPServer(db *gorm.DB, redis *redis.Client) *http.Server {
      router := gin.New()
      
      health := &HealthChecker{db: db, redis: redis}
      router.GET("/health/live", health.Liveness)
      router.GET("/health/ready", health.Readiness)
      
      return router
  }
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: Không có structured logging**
```go
// ❌ SAI - Plain text logs
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    log.Println("Creating order")  // ❌ Không có context
    
    order, err := uc.orderRepo.Create(ctx, order)
    if err != nil {
        log.Println("Error:", err)  // ❌ Khó parse, không có fields
        return nil, err
    }
    
    log.Printf("Order %s created", order.ID)  // ❌ String formatting, không structured
    return order, nil
}

// Logs output:
// 2026/01/16 10:30:00 Creating order
// 2026/01/16 10:30:01 Error: connection timeout
// 2026/01/16 10:30:02 Order ord_123 created

// ❌ Vấn đề:
// - Không có trace_id → không trace được request flow
// - Không có customer_id → không biết order của ai
// - Không có structured fields → khó query trong log aggregator
// - Không có log level → không filter được

// ✅ ĐÚNG
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    uc.logger.InfoContext(ctx, "creating order",
        "customer_id", input.CustomerID,
        "items_count", len(input.Items),
    )
    
    order, err := uc.orderRepo.Create(ctx, order)
    if err != nil {
        uc.logger.ErrorContext(ctx, "failed to create order",
            "customer_id", input.CustomerID,
            "error", err,
        )
        return nil, err
    }
    
    uc.logger.InfoContext(ctx, "order created",
        "order_id", order.ID,
        "customer_id", order.CustomerID,
        "total_amount", order.TotalAmount,
    )
    return order, nil
}

// Logs output (JSON):
// {"level":"info","time":"2026-01-16T10:30:00Z","msg":"creating order","trace_id":"abc123","customer_id":"cust_456","items_count":3}
// {"level":"info","time":"2026-01-16T10:30:01Z","msg":"order created","trace_id":"abc123","order_id":"ord_789","customer_id":"cust_456","total_amount":150.50}
```

**Lỗi 2: Không có metrics**
```go
// ❌ SAI - Không có metrics
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    // ❌ Không track metrics
    order, err := uc.orderRepo.Create(ctx, order)
    return order, err
}

// ❌ Vấn đề:
// - Không biết có bao nhiêu orders được tạo
// - Không biết error rate
// - Không biết latency
// - Không có alerting

// ✅ ĐÚNG - Track metrics
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    start := time.Now()
    
    order, err := uc.orderRepo.Create(ctx, order)
    
    // Record metrics
    duration := time.Since(start).Seconds()
    uc.metrics.RequestDuration.WithLabelValues("CreateOrder").Observe(duration)
    
    if err != nil {
        uc.metrics.ErrorsTotal.WithLabelValues("CreateOrder", "db_error").Inc()
        return nil, err
    }
    
    uc.metrics.OrdersCreated.Inc()
    uc.metrics.OrderValue.Observe(order.TotalAmount)
    
    return order, nil
}
```

**Lỗi 3: Không có tracing**
```go
// ❌ SAI - Không có tracing
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    // ❌ Không có spans
    order, err := uc.orderRepo.Create(ctx, order)
    if err != nil {
        return nil, err
    }
    
    // Call external services
    uc.paymentClient.CreatePayment(ctx, payment)
    uc.warehouseClient.ReserveStock(ctx, items)
    uc.notificationClient.SendEmail(ctx, email)
    
    return order, nil
}

// ❌ Vấn đề:
// - Không trace được request flow qua nhiều services
// - Không biết service nào chậm
// - Khó debug distributed systems

// ✅ ĐÚNG - Distributed tracing
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    ctx, span := uc.tracer.Start(ctx, "OrderUsecase.CreateOrder")
    defer span.End()
    
    // Create order
    ctx, dbSpan := uc.tracer.Start(ctx, "create_order_db")
    order, err := uc.orderRepo.Create(ctx, order)
    dbSpan.End()
    if err != nil {
        span.RecordError(err)
        return nil, err
    }
    
    // Call payment (span được propagate qua gRPC)
    ctx, paymentSpan := uc.tracer.Start(ctx, "create_payment")
    _, err = uc.paymentClient.CreatePayment(ctx, payment)
    paymentSpan.End()
    
    // Call warehouse
    ctx, warehouseSpan := uc.tracer.Start(ctx, "reserve_stock")
    _, err = uc.warehouseClient.ReserveStock(ctx, items)
    warehouseSpan.End()
    
    return order, nil
}

// ✅ Kết quả: Có thể xem trace trong Jaeger
// OrderUsecase.CreateOrder (100ms)
//   ├─ create_order_db (20ms)
//   ├─ create_payment (50ms)
//   │   └─ PaymentService.CreatePayment (45ms)
//   │       └─ charge_gateway (40ms)
//   └─ reserve_stock (30ms)
//       └─ WarehouseService.ReserveStock (25ms)
```

#### 📝 Cách review:
1. Check logging → có structured không, có context fields không
2. Check metrics → có expose `/metrics` endpoint không
3. Check tracing → có OpenTelemetry spans không
4. Check health checks → có `/health/live` và `/health/ready` không
5. Test observability → xem logs, metrics, traces trong staging

---

### 8. 🧪 TESTING & QUALITY

#### ✅ Điều kiện đạt chuẩn:

- [ ] **Unit tests**: Business logic coverage > 80%
  ```go
  // ✅ ĐÚNG - Table-driven tests
  // internal/biz/order/usecase_test.go
  func TestOrderUsecase_CreateOrder(t *testing.T) {
      tests := []struct {
          name          string
          input         *CreateOrderInput
          mockSetup     func(*mocks.MockOrderRepository, *mocks.MockPaymentClient)
          expectedError error
          validate      func(*testing.T, *Order)
      }{
          {
              name: "success - create order with valid input",
              input: &CreateOrderInput{
                  CustomerID: "cust_123",
                  Items: []*OrderItem{
                      {ProductID: "prod_1", Quantity: 2, Price: 10.0},
                  },
              },
              mockSetup: func(repo *mocks.MockOrderRepository, payment *mocks.MockPaymentClient) {
                  repo.EXPECT().
                      Create(gomock.Any(), gomock.Any()).
                      Return(nil)
                  
                  payment.EXPECT().
                      CreatePayment(gomock.Any(), gomock.Any()).
                      Return(&Payment{ID: "pay_123"}, nil)
              },
              expectedError: nil,
              validate: func(t *testing.T, order *Order) {
                  assert.NotEmpty(t, order.ID)
                  assert.Equal(t, "cust_123", order.CustomerID)
                  assert.Equal(t, 20.0, order.TotalAmount)
              },
          },
          {
              name: "error - empty customer id",
              input: &CreateOrderInput{
                  CustomerID: "",
                  Items:      []*OrderItem{{ProductID: "prod_1", Quantity: 1}},
              },
              mockSetup:     func(repo *mocks.MockOrderRepository, payment *mocks.MockPaymentClient) {},
              expectedError: ErrInvalidInput,
          },
          {
              name: "error - empty items",
              input: &CreateOrderInput{
                  CustomerID: "cust_123",
                  Items:      []*OrderItem{},
              },
              mockSetup:     func(repo *mocks.MockOrderRepository, payment *mocks.MockPaymentClient) {},
              expectedError: ErrInvalidInput,
          },
          {
              name: "error - repository failure",
              input: &CreateOrderInput{
                  CustomerID: "cust_123",
                  Items:      []*OrderItem{{ProductID: "prod_1", Quantity: 1}},
              },
              mockSetup: func(repo *mocks.MockOrderRepository, payment *mocks.MockPaymentClient) {
                  repo.EXPECT().
                      Create(gomock.Any(), gomock.Any()).
                      Return(errors.New("db error"))
              },
              expectedError: errors.New("db error"),
          },
      }
      
      for _, tt := range tests {
          t.Run(tt.name, func(t *testing.T) {
              // Setup
              ctrl := gomock.NewController(t)
              defer ctrl.Finish()
              
              mockRepo := mocks.NewMockOrderRepository(ctrl)
              mockPayment := mocks.NewMockPaymentClient(ctrl)
              tt.mockSetup(mockRepo, mockPayment)
              
              uc := NewOrderUsecase(mockRepo, mockPayment, nil)
              
              // Execute
              order, err := uc.CreateOrder(context.Background(), tt.input)
              
              // Assert
              if tt.expectedError != nil {
                  assert.Error(t, err)
                  assert.Contains(t, err.Error(), tt.expectedError.Error())
              } else {
                  assert.NoError(t, err)
                  if tt.validate != nil {
                      tt.validate(t, order)
                  }
              }
          })
      }
  }
  ```

- [ ] **Integration tests**: Service-to-Repo flows với real DB
  ```go
  // ✅ ĐÚNG - Integration test với testcontainers
  // internal/data/postgres/order_test.go
  func TestOrderRepository_Integration(t *testing.T) {
      if testing.Short() {
          t.Skip("skipping integration test")
      }
      
      // Setup testcontainer
      ctx := context.Background()
      
      postgresContainer, err := postgres.RunContainer(ctx,
          testcontainers.WithImage("postgres:15-alpine"),
          postgres.WithDatabase("testdb"),
          postgres.WithUsername("test"),
          postgres.WithPassword("test"),
      )
      require.NoError(t, err)
      defer postgresContainer.Terminate(ctx)
      
      // Get connection string
      connStr, err := postgresContainer.ConnectionString(ctx)
      require.NoError(t, err)
      
      // Connect to DB
      db, err := gorm.Open(postgres.Open(connStr), &gorm.Config{})
      require.NoError(t, err)
      
      // Run migrations
      err = db.AutoMigrate(&model.Order{}, &model.OrderItem{})
      require.NoError(t, err)
      
      // Create repository
      repo := NewOrderRepository(db)
      
      t.Run("Create and FindByID", func(t *testing.T) {
          // Create order
          order := &biz.Order{
              ID:         uuid.New().String(),
              CustomerID: "cust_123",
              Status:     biz.OrderStatusPending,
              TotalAmount: 100.0,
          }
          
          err := repo.Create(ctx, order)
          require.NoError(t, err)
          
          // Find by ID
          found, err := repo.FindByID(ctx, order.ID)
          require.NoError(t, err)
          assert.Equal(t, order.ID, found.ID)
          assert.Equal(t, order.CustomerID, found.CustomerID)
          assert.Equal(t, order.TotalAmount, found.TotalAmount)
      })
      
      t.Run("Transaction rollback", func(t *testing.T) {
          err := db.Transaction(func(tx *gorm.DB) error {
              txRepo := NewOrderRepository(tx)
              
              order := &biz.Order{
                  ID:         uuid.New().String(),
                  CustomerID: "cust_456",
              }
              
              err := txRepo.Create(ctx, order)
              require.NoError(t, err)
              
              // Force rollback
              return errors.New("rollback")
          })
          
          assert.Error(t, err)
          
          // Verify order was not created
          _, err = repo.FindByID(ctx, "should_not_exist")
          assert.Error(t, err)
      })
  }
  ```

- [ ] **Mocks**: Dependencies được mock đúng cách
  ```go
  // ✅ ĐÚNG - Generate mocks với mockgen
  // Makefile
  .PHONY: mocks
  mocks:
  	mockgen -source=internal/biz/order/repository.go -destination=internal/biz/order/mocks/repository_mock.go -package=mocks
  	mockgen -source=internal/client/payment/client.go -destination=internal/client/payment/mocks/client_mock.go -package=mocks
  
  // internal/biz/order/repository.go
  //go:generate mockgen -source=repository.go -destination=mocks/repository_mock.go -package=mocks
  type OrderRepository interface {
      Create(ctx context.Context, order *Order) error
      Update(ctx context.Context, order *Order) error
      FindByID(ctx context.Context, id string) (*Order, error)
  }
  
  // Usage in tests
  func TestOrderUsecase_CreateOrder(t *testing.T) {
      ctrl := gomock.NewController(t)
      defer ctrl.Finish()
      
      mockRepo := mocks.NewMockOrderRepository(ctrl)
      mockRepo.EXPECT().
          Create(gomock.Any(), gomock.Any()).
          DoAndReturn(func(ctx context.Context, order *Order) error {
              order.ID = "ord_123"  // Simulate DB generating ID
              return nil
          })
      
      uc := NewOrderUsecase(mockRepo, nil, nil)
      order, err := uc.CreateOrder(context.Background(), input)
      
      assert.NoError(t, err)
      assert.Equal(t, "ord_123", order.ID)
  }
  ```

- [ ] **Test coverage**: Có coverage report
  ```bash
  # ✅ ĐÚNG - Run tests với coverage
  # Makefile
  .PHONY: test
  test:
  	go test -v -race -coverprofile=coverage.out ./...
  	go tool cover -html=coverage.out -o coverage.html
  	go tool cover -func=coverage.out | grep total
  
  # Run tests
  make test
  
  # Output:
  # ok      gitlab.com/ta-microservices/order/internal/biz/order    0.123s  coverage: 85.2% of statements
  # ok      gitlab.com/ta-microservices/order/internal/data/postgres 0.456s  coverage: 78.9% of statements
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: Không có tests**
```go
// ❌ SAI - Không có tests
// internal/biz/order/usecase.go
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    // Complex business logic
    if input.CustomerID == "" {
        return nil, ErrInvalidInput
    }
    
    // Calculate total
    var total float64
    for _, item := range input.Items {
        total += item.Price * float64(item.Quantity)
    }
    
    // Apply discount
    if total > 100 {
        total *= 0.9  // 10% discount
    }
    
    order := &Order{
        CustomerID:  input.CustomerID,
        TotalAmount: total,
        Status:      OrderStatusPending,
    }
    
    return uc.orderRepo.Create(ctx, order)
}

// ❌ Không có file usecase_test.go
// ❌ Không biết logic có đúng không
// ❌ Refactor sẽ rất nguy hiểm

// ✅ ĐÚNG - Có tests đầy đủ
// internal/biz/order/usecase_test.go
func TestOrderUsecase_CreateOrder(t *testing.T) {
    tests := []struct {
        name          string
        input         *CreateOrderInput
        expectedTotal float64
        expectedError error
    }{
        {
            name: "no discount",
            input: &CreateOrderInput{
                CustomerID: "cust_123",
                Items: []*OrderItem{
                    {Price: 10, Quantity: 5},  // 50
                },
            },
            expectedTotal: 50.0,
        },
        {
            name: "with discount",
            input: &CreateOrderInput{
                CustomerID: "cust_123",
                Items: []*OrderItem{
                    {Price: 50, Quantity: 3},  // 150
                },
            },
            expectedTotal: 135.0,  // 150 * 0.9
        },
        {
            name: "empty customer id",
            input: &CreateOrderInput{
                CustomerID: "",
                Items:      []*OrderItem{{Price: 10, Quantity: 1}},
            },
            expectedError: ErrInvalidInput,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}
```

**Lỗi 2: Tests không cover edge cases**
```go
// ❌ SAI - Chỉ test happy path
func TestOrderUsecase_CreateOrder(t *testing.T) {
    // ❌ Chỉ test case thành công
    mockRepo := mocks.NewMockOrderRepository(ctrl)
    mockRepo.EXPECT().Create(gomock.Any(), gomock.Any()).Return(nil)
    
    uc := NewOrderUsecase(mockRepo, nil, nil)
    order, err := uc.CreateOrder(ctx, &CreateOrderInput{
        CustomerID: "cust_123",
        Items:      []*OrderItem{{ProductID: "prod_1", Quantity: 1}},
    })
    
    assert.NoError(t, err)
    assert.NotNil(t, order)
}

// ❌ Không test:
// - Empty customer ID
// - Empty items
// - Negative quantity
// - Zero price
// - Repository error
// - Payment error
// - Transaction rollback

// ✅ ĐÚNG - Test tất cả edge cases
func TestOrderUsecase_CreateOrder(t *testing.T) {
    tests := []struct {
        name          string
        input         *CreateOrderInput
        mockSetup     func(*mocks.MockOrderRepository)
        expectedError error
    }{
        {
            name: "success",
            input: &CreateOrderInput{
                CustomerID: "cust_123",
                Items:      []*OrderItem{{ProductID: "prod_1", Quantity: 1, Price: 10}},
            },
            mockSetup: func(repo *mocks.MockOrderRepository) {
                repo.EXPECT().Create(gomock.Any(), gomock.Any()).Return(nil)
            },
        },
        {
            name: "error - empty customer id",
            input: &CreateOrderInput{
                CustomerID: "",
                Items:      []*OrderItem{{ProductID: "prod_1", Quantity: 1}},
            },
            expectedError: ErrInvalidInput,
        },
        {
            name: "error - empty items",
            input: &CreateOrderInput{
                CustomerID: "cust_123",
                Items:      []*OrderItem{},
            },
            expectedError: ErrInvalidInput,
        },
        {
            name: "error - negative quantity",
            input: &CreateOrderInput{
                CustomerID: "cust_123",
                Items:      []*OrderItem{{ProductID: "prod_1", Quantity: -1}},
            },
            expectedError: ErrInvalidInput,
        },
        {
            name: "error - repository failure",
            input: &CreateOrderInput{
                CustomerID: "cust_123",
                Items:      []*OrderItem{{ProductID: "prod_1", Quantity: 1}},
            },
            mockSetup: func(repo *mocks.MockOrderRepository) {
                repo.EXPECT().Create(gomock.Any(), gomock.Any()).Return(errors.New("db error"))
            },
            expectedError: errors.New("db error"),
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}
```

**Lỗi 3: Integration tests không cleanup**
```go
// ❌ SAI - Không cleanup
func TestOrderRepository_Create(t *testing.T) {
    db := setupTestDB()  // Connect to shared test DB
    repo := NewOrderRepository(db)
    
    // ❌ Tạo data nhưng không cleanup
    order := &Order{ID: "ord_123", CustomerID: "cust_123"}
    err := repo.Create(context.Background(), order)
    assert.NoError(t, err)
    
    // ❌ Data còn lại trong DB
    // ❌ Test chạy lại sẽ fail (duplicate key)
}

// ✅ ĐÚNG - Cleanup sau mỗi test
func TestOrderRepository_Create(t *testing.T) {
    // Setup testcontainer (isolated DB)
    ctx := context.Background()
    container, err := postgres.RunContainer(ctx)
    require.NoError(t, err)
    defer container.Terminate(ctx)  // ✅ Cleanup container
    
    db := connectToDB(container)
    repo := NewOrderRepository(db)
    
    t.Run("create order", func(t *testing.T) {
        order := &Order{
            ID:         uuid.New().String(),  // ✅ Random ID
            CustomerID: "cust_123",
        }
        
        err := repo.Create(ctx, order)
        assert.NoError(t, err)
        
        // ✅ Verify
        found, err := repo.FindByID(ctx, order.ID)
        assert.NoError(t, err)
        assert.Equal(t, order.ID, found.ID)
    })
    
    // ✅ Container bị terminate → data tự động cleanup
}
```

#### 📝 Cách review:
1. Check test files → có đầy đủ không
2. Run `make test` → coverage bao nhiêu %
3. Check test cases → có cover edge cases không
4. Check mocks → có generate đúng không
5. Run integration tests → có pass không

---

### 9. ⚙️ CONFIGURATION & RESILIENCE

#### ✅ Điều kiện đạt chuẩn:

- [ ] **Timeouts**: Tất cả external calls có timeout
  ```go
  // ❌ SAI - Không có timeout
  func (c *PaymentClient) CreatePayment(ctx context.Context, req *CreatePaymentRequest) (*Payment, error) {
      // ❌ Nếu payment service chậm → block forever
      return c.client.CreatePayment(ctx, req)
  }
  
  // ✅ ĐÚNG - Có timeout
  func (c *PaymentClient) CreatePayment(ctx context.Context, req *CreatePaymentRequest) (*Payment, error) {
      // ✅ Set timeout 5 seconds
      ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
      defer cancel()
      
      return c.client.CreatePayment(ctx, req)
  }
  
  // ✅ TỐT HƠN - Configurable timeout
  type PaymentClient struct {
      client  pb.PaymentServiceClient
      timeout time.Duration
  }
  
  func NewPaymentClient(conn *grpc.ClientConn, timeout time.Duration) *PaymentClient {
      return &PaymentClient{
          client:  pb.NewPaymentServiceClient(conn),
          timeout: timeout,
      }
  }
  
  func (c *PaymentClient) CreatePayment(ctx context.Context, req *CreatePaymentRequest) (*Payment, error) {
      ctx, cancel := context.WithTimeout(ctx, c.timeout)
      defer cancel()
      
      return c.client.CreatePayment(ctx, req)
  }
  ```

- [ ] **Retries**: Retry với exponential backoff
  ```go
  // ❌ SAI - Không có retry
  func (c *WarehouseClient) ReserveStock(ctx context.Context, items []*Item) error {
      // ❌ Nếu fail 1 lần → fail luôn
      _, err := c.client.ReserveStock(ctx, &pb.ReserveStockRequest{Items: items})
      return err
  }
  
  // ✅ ĐÚNG - Retry với exponential backoff
  func (c *WarehouseClient) ReserveStock(ctx context.Context, items []*Item) error {
      var lastErr error
      
      backoff := time.Second
      maxRetries := 3
      
      for i := 0; i < maxRetries; i++ {
          _, err := c.client.ReserveStock(ctx, &pb.ReserveStockRequest{Items: items})
          if err == nil {
              return nil
          }
          
          // Check if error is retryable
          if !isRetryable(err) {
              return err
          }
          
          lastErr = err
          
          // Wait before retry
          if i < maxRetries-1 {
              time.Sleep(backoff)
              backoff *= 2  // Exponential backoff
          }
      }
      
      return fmt.Errorf("failed after %d retries: %w", maxRetries, lastErr)
  }
  
  func isRetryable(err error) bool {
      // Retry on temporary errors
      st, ok := status.FromError(err)
      if !ok {
          return false
      }
      
      switch st.Code() {
      case codes.Unavailable, codes.DeadlineExceeded, codes.ResourceExhausted:
          return true
      default:
          return false
      }
  }
  
  // ✅ TỐT HƠN - Sử dụng retry library
  import "github.com/avast/retry-go/v4"
  
  func (c *WarehouseClient) ReserveStock(ctx context.Context, items []*Item) error {
      return retry.Do(
          func() error {
              _, err := c.client.ReserveStock(ctx, &pb.ReserveStockRequest{Items: items})
              return err
          },
          retry.Attempts(3),
          retry.Delay(time.Second),
          retry.DelayType(retry.BackOffDelay),
          retry.RetryIf(func(err error) bool {
              return isRetryable(err)
          }),
          retry.OnRetry(func(n uint, err error) {
              c.logger.Warn("retrying reserve stock", "attempt", n, "error", err)
          }),
      )
  }
  ```

- [ ] **Circuit breaker**: Protect từ cascading failures
  ```go
  // ❌ SAI - Không có circuit breaker
  func (c *CatalogClient) GetProduct(ctx context.Context, id string) (*Product, error) {
      // ❌ Nếu catalog service down → mỗi request đều timeout
      // ❌ Waste resources, slow response
      return c.client.GetProduct(ctx, &pb.GetProductRequest{Id: id})
  }
  
  // ✅ ĐÚNG - Circuit breaker
  import "github.com/sony/gobreaker"
  
  type CatalogClient struct {
      client  pb.CatalogServiceClient
      breaker *gobreaker.CircuitBreaker
  }
  
  func NewCatalogClient(conn *grpc.ClientConn) *CatalogClient {
      breaker := gobreaker.NewCircuitBreaker(gobreaker.Settings{
          Name:        "catalog",
          MaxRequests: 3,                    // Max requests in half-open state
          Interval:    time.Minute,          // Reset counts after 1 minute
          Timeout:     30 * time.Second,     // Time to wait before half-open
          ReadyToTrip: func(counts gobreaker.Counts) bool {
              failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
              return counts.Requests >= 3 && failureRatio >= 0.6
          },
          OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
              log.Printf("circuit breaker %s: %s -> %s", name, from, to)
          },
      })
      
      return &CatalogClient{
          client:  pb.NewCatalogServiceClient(conn),
          breaker: breaker,
      }
  }
  
  func (c *CatalogClient) GetProduct(ctx context.Context, id string) (*Product, error) {
      // Execute with circuit breaker
      result, err := c.breaker.Execute(func() (interface{}, error) {
          return c.client.GetProduct(ctx, &pb.GetProductRequest{Id: id})
      })
      
      if err != nil {
          return nil, err
      }
      
      return result.(*Product), nil
  }
  ```

- [ ] **Configuration validation**: Validate config on startup
  ```go
  // ❌ SAI - Không validate config
  type Config struct {
      Server   ServerConfig
      Database DatabaseConfig
      Redis    RedisConfig
  }
  
  func LoadConfig() (*Config, error) {
      var config Config
      viper.Unmarshal(&config)
      return &config, nil  // ❌ Không validate
  }
  
  func main() {
      config, _ := LoadConfig()
      
      // ❌ Runtime error khi connect DB
      db, err := gorm.Open(postgres.Open(config.Database.DSN))
      // ...
  }
  
  // ✅ ĐÚNG - Validate config on startup
  type Config struct {
      Server   ServerConfig   `validate:"required"`
      Database DatabaseConfig `validate:"required"`
      Redis    RedisConfig    `validate:"required"`
  }
  
  type ServerConfig struct {
      Host string `validate:"required"`
      Port int    `validate:"required,min=1,max=65535"`
  }
  
  type DatabaseConfig struct {
      Host     string `validate:"required"`
      Port     int    `validate:"required,min=1,max=65535"`
      User     string `validate:"required"`
      Password string `validate:"required"`
      DBName   string `validate:"required"`
  }
  
  func LoadConfig() (*Config, error) {
      var config Config
      
      if err := viper.Unmarshal(&config); err != nil {
          return nil, fmt.Errorf("failed to unmarshal config: %w", err)
      }
      
      // ✅ Validate config
      validate := validator.New()
      if err := validate.Struct(&config); err != nil {
          return nil, fmt.Errorf("invalid config: %w", err)
      }
      
      return &config, nil
  }
  
  func main() {
      // ✅ Fail fast nếu config invalid
      config, err := LoadConfig()
      if err != nil {
          log.Fatal("failed to load config:", err)
      }
      
      // Config đã được validate → safe to use
      db, err := gorm.Open(postgres.Open(config.Database.DSN()))
      // ...
  }
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: Không có timeout**
```go
// ❌ SAI - Blocking forever
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    // ❌ Nếu payment service chậm → block forever
    payment, err := uc.paymentClient.CreatePayment(ctx, &CreatePaymentRequest{
        Amount: input.TotalAmount,
    })
    if err != nil {
        return nil, err
    }
    
    // ❌ Nếu warehouse service chậm → block forever
    err = uc.warehouseClient.ReserveStock(ctx, input.Items)
    if err != nil {
        return nil, err
    }
    
    return order, nil
}

// Kết quả:
// - Payment service chậm 30s → request timeout
// - Warehouse service chậm 30s → request timeout
// - Total: 60s+ → user experience rất tệ

// ✅ ĐÚNG - Có timeout cho mỗi call
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    // ✅ Payment timeout 5s
    paymentCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    
    payment, err := uc.paymentClient.CreatePayment(paymentCtx, &CreatePaymentRequest{
        Amount: input.TotalAmount,
    })
    if err != nil {
        return nil, fmt.Errorf("payment failed: %w", err)
    }
    
    // ✅ Warehouse timeout 3s
    warehouseCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
    defer cancel()
    
    err = uc.warehouseClient.ReserveStock(warehouseCtx, input.Items)
    if err != nil {
        // Rollback payment
        uc.paymentClient.Refund(ctx, payment.ID)
        return nil, fmt.Errorf("warehouse failed: %w", err)
    }
    
    return order, nil
}
```

**Lỗi 2: Không có retry cho transient errors**
```go
// ❌ SAI - Fail ngay lập tức
func (c *NotificationClient) SendEmail(ctx context.Context, email *Email) error {
    // ❌ Network blip → fail
    // ❌ Service restart → fail
    // ❌ Rate limit → fail
    _, err := c.client.SendEmail(ctx, &pb.SendEmailRequest{
        To:      email.To,
        Subject: email.Subject,
        Body:    email.Body,
    })
    return err
}

// ✅ ĐÚNG - Retry với backoff
func (c *NotificationClient) SendEmail(ctx context.Context, email *Email) error {
    return retry.Do(
        func() error {
            _, err := c.client.SendEmail(ctx, &pb.SendEmailRequest{
                To:      email.To,
                Subject: email.Subject,
                Body:    email.Body,
            })
            return err
        },
        retry.Attempts(3),
        retry.Delay(time.Second),
        retry.DelayType(retry.BackOffDelay),
        retry.RetryIf(func(err error) bool {
            // Retry on transient errors
            st, ok := status.FromError(err)
            if !ok {
                return false
            }
            
            switch st.Code() {
            case codes.Unavailable, codes.DeadlineExceeded:
                return true
            default:
                return false
            }
        }),
        retry.OnRetry(func(n uint, err error) {
            c.logger.Warn("retrying send email",
                "attempt", n,
                "to", email.To,
                "error", err,
            )
        }),
    )
}
```

**Lỗi 3: Không validate config**
```go
// ❌ SAI - Runtime error
type Config struct {
    Database DatabaseConfig
}

type DatabaseConfig struct {
    Host string
    Port int
}

func main() {
    var config Config
    viper.Unmarshal(&config)
    
    // ❌ Nếu config thiếu host → runtime error khi connect
    dsn := fmt.Sprintf("postgres://%s:%d/db", config.Database.Host, config.Database.Port)
    db, err := gorm.Open(postgres.Open(dsn))
    if err != nil {
        log.Fatal(err)  // ❌ Fail sau khi start
    }
}

// ✅ ĐÚNG - Validate on startup
type Config struct {
    Database DatabaseConfig `validate:"required"`
}

type DatabaseConfig struct {
    Host string `validate:"required,hostname"`
    Port int    `validate:"required,min=1,max=65535"`
}

func LoadConfig() (*Config, error) {
    var config Config
    
    if err := viper.Unmarshal(&config); err != nil {
        return nil, err
    }
    
    // ✅ Validate
    validate := validator.New()
    if err := validate.Struct(&config); err != nil {
        return nil, fmt.Errorf("invalid config: %w", err)
    }
    
    return &config, nil
}

func main() {
    // ✅ Fail fast nếu config invalid
    config, err := LoadConfig()
    if err != nil {
        log.Fatal("config error:", err)  // ✅ Fail immediately
    }
    
    // Config valid → safe to use
    db, err := gorm.Open(postgres.Open(config.Database.DSN()))
    // ...
}
```

#### 📝 Cách review:
1. Search external calls → có timeout không
2. Check error handling → có retry không
3. Check critical dependencies → có circuit breaker không
4. Check config loading → có validation không
5. Test failure scenarios → service có recover không

---

### 10. 📚 DOCUMENTATION & MAINTENANCE

#### ✅ Điều kiện đạt chuẩn:

- [ ] **README**: Clear setup, run, usage instructions
  ```markdown
  # ✅ ĐÚNG - README.md template
  
  # Order Service
  
  ## Overview
  Order service quản lý toàn bộ lifecycle của orders: cart, checkout, payment, fulfillment.
  
  ## Features
  - ✅ Cart management (add, update, remove items)
  - ✅ Checkout flow với payment integration
  - ✅ Order tracking và status updates
  - ✅ Order cancellation và refunds
  - ✅ Event-driven architecture với Dapr
  
  ## Architecture
  ```
  ┌─────────────┐
  │   Gateway   │
  └──────┬──────┘
         │
  ┌──────▼──────┐
  │    Order    │
  │   Service   │
  └──────┬──────┘
         │
    ┌────┴────┬────────┬──────────┐
    │         │        │          │
  ┌─▼──┐  ┌──▼───┐ ┌──▼────┐ ┌───▼──────┐
  │ DB │  │Redis │ │Payment│ │Warehouse │
  └────┘  └──────┘ └───────┘ └──────────┘
  ```
  
  ## Prerequisites
  - Go 1.25+
  - PostgreSQL 15+
  - Redis 7+
  - Dapr 1.12+
  
  ## Quick Start
  
  ### 1. Install dependencies
  ```bash
  go mod download
  ```
  
  ### 2. Setup database
  ```bash
  # Create database
  createdb order_db
  
  # Run migrations
  make migrate-up
  ```
  
  ### 3. Configure environment
  ```bash
  cp .env.example .env
  # Edit .env với config của bạn
  ```
  
  ### 4. Run service
  ```bash
  make run
  ```
  
  Service sẽ chạy tại:
  - HTTP: http://localhost:8001
  - gRPC: localhost:9001
  - Metrics: http://localhost:8001/metrics
  
  ## Development
  
  ### Run tests
  ```bash
  make test
  ```
  
  ### Run with hot reload
  ```bash
  make dev
  ```
  
  ### Generate proto
  ```bash
  make api
  ```
  
  ### Run linter
  ```bash
  make lint
  ```
  
  ## API Documentation
  - [OpenAPI Spec](./api/openapi.yaml)
  - [Proto Definitions](./api/order/v1/)
  
  ## Configuration
  
  | Variable | Description | Default |
  |----------|-------------|---------|
  | `DB_HOST` | PostgreSQL host | `localhost` |
  | `DB_PORT` | PostgreSQL port | `5432` |
  | `REDIS_HOST` | Redis host | `localhost` |
  | `REDIS_PORT` | Redis port | `6379` |
  
  ## Deployment
  
  ### Docker
  ```bash
  docker build -t order-service .
  docker run -p 8001:8001 order-service
  ```
  
  ### Kubernetes
  ```bash
  kubectl apply -f k8s/
  ```
  
  ## Troubleshooting
  
  ### Database connection error
  ```
  Error: failed to connect to database
  ```
  Solution: Check DB_HOST, DB_PORT, DB_USER, DB_PASSWORD trong .env
  
  ### Redis connection error
  ```
  Error: failed to connect to redis
  ```
  Solution: Check REDIS_HOST, REDIS_PORT trong .env
  
  ## Contributing
  1. Create feature branch
  2. Make changes
  3. Run tests: `make test`
  4. Run linter: `make lint`
  5. Create merge request
  
  ## License
  Proprietary
  ```

- [ ] **API documentation**: OpenAPI/Swagger specs
  ```yaml
  # ✅ ĐÚNG - api/openapi.yaml
  openapi: 3.0.0
  info:
    title: Order Service API
    version: 1.0.0
    description: API for managing orders
  
  servers:
    - url: http://localhost:8001/api/v1
      description: Local development
    - url: https://api.example.com/api/v1
      description: Production
  
  paths:
    /orders:
      post:
        summary: Create order
        description: Create a new order from cart
        tags:
          - Orders
        requestBody:
          required: true
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CreateOrderRequest'
        responses:
          '200':
            description: Order created successfully
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/Order'
          '400':
            description: Invalid input
          '401':
            description: Unauthorized
          '500':
            description: Internal server error
      
      get:
        summary: List orders
        description: Get list of orders for current user
        tags:
          - Orders
        parameters:
          - name: page
            in: query
            schema:
              type: integer
              default: 1
          - name: page_size
            in: query
            schema:
              type: integer
              default: 20
        responses:
          '200':
            description: List of orders
            content:
              application/json:
                schema:
                  type: object
                  properties:
                    orders:
                      type: array
                      items:
                        $ref: '#/components/schemas/Order'
                    total:
                      type: integer
                    page:
                      type: integer
                    page_size:
                      type: integer
  
  components:
    schemas:
      CreateOrderRequest:
        type: object
        required:
          - customer_id
          - items
        properties:
          customer_id:
            type: string
            example: "cust_123"
          items:
            type: array
            items:
              $ref: '#/components/schemas/OrderItem'
          shipping_address_id:
            type: string
            example: "addr_456"
      
      Order:
        type: object
        properties:
          id:
            type: string
            example: "ord_789"
          customer_id:
            type: string
            example: "cust_123"
          status:
            type: string
            enum: [pending, confirmed, shipped, delivered, cancelled]
          total_amount:
            type: number
            format: double
            example: 150.50
          created_at:
            type: string
            format: date-time
  ```

- [ ] **Code comments**: Complex logic có comments
  ```go
  // ❌ SAI - Không có comments
  func (uc *OrderUsecase) CalculateDiscount(order *Order) float64 {
      var discount float64
      
      if order.TotalAmount > 100 {
          discount = order.TotalAmount * 0.1
      }
      
      if len(order.Items) > 5 {
          discount += 10
      }
      
      if order.Customer.Tier == "gold" {
          discount *= 1.5
      }
      
      return discount
  }
  
  // ✅ ĐÚNG - Có comments giải thích logic
  // CalculateDiscount tính discount cho order dựa trên:
  // 1. Order value: 10% discount nếu > $100
  // 2. Bulk purchase: $10 discount nếu > 5 items
  // 3. Customer tier: Gold tier được 1.5x discount
  func (uc *OrderUsecase) CalculateDiscount(order *Order) float64 {
      var discount float64
      
      // Apply value-based discount
      if order.TotalAmount > 100 {
          discount = order.TotalAmount * 0.1  // 10% discount
      }
      
      // Apply bulk purchase discount
      if len(order.Items) > 5 {
          discount += 10  // $10 flat discount
      }
      
      // Apply tier multiplier
      if order.Customer.Tier == "gold" {
          discount *= 1.5  // Gold tier gets 1.5x discount
      }
      
      return discount
  }
  
  // ✅ TỐT HƠN - Extract thành separate functions
  // CalculateDiscount tính tổng discount cho order
  func (uc *OrderUsecase) CalculateDiscount(order *Order) float64 {
      discount := 0.0
      
      discount += uc.calculateValueDiscount(order)
      discount += uc.calculateBulkDiscount(order)
      discount = uc.applyTierMultiplier(order, discount)
      
      return discount
  }
  
  // calculateValueDiscount returns 10% discount for orders > $100
  func (uc *OrderUsecase) calculateValueDiscount(order *Order) float64 {
      if order.TotalAmount > 100 {
          return order.TotalAmount * 0.1
      }
      return 0
  }
  
  // calculateBulkDiscount returns $10 discount for orders with > 5 items
  func (uc *OrderUsecase) calculateBulkDiscount(order *Order) float64 {
      if len(order.Items) > 5 {
          return 10
      }
      return 0
  }
  
  // applyTierMultiplier applies customer tier multiplier to discount
  func (uc *OrderUsecase) applyTierMultiplier(order *Order, discount float64) float64 {
      switch order.Customer.Tier {
      case "gold":
          return discount * 1.5
      case "silver":
          return discount * 1.2
      default:
          return discount
      }
  }
  ```

- [ ] **TODOs**: Tech debt được track
  ```go
  // ❌ SAI - TODO không có context
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // TODO: fix this
      order, err := uc.orderRepo.Create(ctx, order)
      return order, err
  }
  
  // ✅ ĐÚNG - TODO với context đầy đủ
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // TODO(tuananh): Implement transactional outbox pattern
      // Currently events are published directly which can cause event loss
      // if publish fails after DB commit. Need to:
      // 1. Save event to outbox table in same transaction
      // 2. Worker polls outbox and publishes events
      // 3. Mark events as published
      // Priority: P1 (before production)
      // Estimated: 8 hours
      // Reference: catalog service implementation
      
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      // Direct publish - risky!
      uc.eventBus.Publish(ctx, "order.created", order)
      
      return order, nil
  }
  
  // ✅ TỐT HƠN - Track trong issue tracker
  // Issue #123: Implement transactional outbox for order events
  // Priority: P1
  // Estimated: 8h
  // Assignee: tuananh
  func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
      // FIXME(#123): Replace direct publish with transactional outbox
      order, err := uc.orderRepo.Create(ctx, order)
      if err != nil {
          return nil, err
      }
      
      uc.eventBus.Publish(ctx, "order.created", order)
      
      return order, nil
  }
  ```

#### 🚨 Các lỗi thường gặp:

**Lỗi 1: README không đầy đủ**
```markdown
# ❌ SAI - README quá ngắn
# Order Service

Order service.

## Run
```bash
go run main.go
```

# ❌ Vấn đề:
# - Không có overview
# - Không có prerequisites
# - Không có setup instructions
# - Không có configuration guide
# - Không có troubleshooting

# ✅ ĐÚNG - README đầy đủ
# (Xem template ở trên)
```

**Lỗi 2: Không có API documentation**
```go
// ❌ SAI - Chỉ có code, không có docs
func (s *OrderService) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
    // Implementation
}

// ❌ Vấn đề:
// - Dev khác không biết API này làm gì
// - Không biết input/output format
// - Không biết error codes
// - Không có examples

// ✅ ĐÚNG - Có OpenAPI spec
// api/openapi.yaml
// (Xem template ở trên)

// ✅ Hoặc generate từ proto
// api/order/v1/order.proto
service OrderService {
  // CreateOrder creates a new order from cart
  //
  // This endpoint:
  // 1. Validates cart items
  // 2. Calculates total amount
  // 3. Creates payment
  // 4. Reserves inventory
  // 5. Creates order
  //
  // Returns:
  // - 200: Order created successfully
  // - 400: Invalid input (empty cart, invalid items)
  // - 401: Unauthorized
  // - 402: Payment failed
  // - 409: Out of stock
  // - 500: Internal server error
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
}
```

**Lỗi 3: Complex logic không có comments**
```go
// ❌ SAI - Magic numbers, không có explanation
func (uc *PricingUsecase) CalculatePrice(product *Product, quantity int) float64 {
    price := product.BasePrice
    
    if quantity > 10 {
        price *= 0.9
    } else if quantity > 5 {
        price *= 0.95
    }
    
    if product.Category == "electronics" {
        price *= 1.1
    }
    
    tax := price * 0.08
    
    return price + tax
}

// ❌ Vấn đề:
// - Không biết 0.9, 0.95 là gì
// - Không biết tại sao electronics +10%
// - Không biết 0.08 là tax rate nào

// ✅ ĐÚNG - Có comments và constants
const (
    // Bulk discount tiers
    BulkTier1Quantity = 5
    BulkTier1Discount = 0.05  // 5% discount
    
    BulkTier2Quantity = 10
    BulkTier2Discount = 0.10  // 10% discount
    
    // Category markup
    ElectronicsMarkup = 0.10  // 10% markup for electronics
    
    // Tax rate
    StandardTaxRate = 0.08  // 8% standard tax
)

// CalculatePrice tính giá cuối cùng cho product bao gồm:
// - Base price
// - Bulk discount (5% cho 5+ items, 10% cho 10+ items)
// - Category markup (10% cho electronics)
// - Tax (8%)
func (uc *PricingUsecase) CalculatePrice(product *Product, quantity int) float64 {
    price := product.BasePrice
    
    // Apply bulk discount
    if quantity >= BulkTier2Quantity {
        price *= (1 - BulkTier2Discount)
    } else if quantity >= BulkTier1Quantity {
        price *= (1 - BulkTier1Discount)
    }
    
    // Apply category markup
    if product.Category == "electronics" {
        price *= (1 + ElectronicsMarkup)
    }
    
    // Calculate tax
    tax := price * StandardTaxRate
    
    return price + tax
}
```

#### 📝 Cách review:
1. Check README → có đầy đủ sections không
2. Check API docs → có OpenAPI spec không
3. Check complex functions → có comments không
4. Search `TODO` → có track properly không
5. Check examples → có working examples không

---

## 📋 FEEDBACK TEMPLATE

### Cách viết feedback hiệu quả:

```markdown
## Code Review Feedback - [Service Name] - [Date]

**Reviewer**: [Your Name]
**PR/MR**: #[Number]
**Overall Status**: ✅ Approved / 🟡 Approved with comments / ❌ Changes requested

---

### 📊 Summary

**Strengths** (Những điểm làm tốt):
- ✅ Clean architecture, tách layer rõ ràng
- ✅ Test coverage 85%, đạt chuẩn
- ✅ Error handling đầy đủ

**Issues Found**: 3 P0, 5 P1, 2 P2

**Estimated Fix Time**: 16 hours (P0: 8h, P1: 6h, P2: 2h)

---

### 🚨 P0 - BLOCKING (Must fix before merge)

#### 1. Missing transaction for multi-write operation
**File**: `internal/biz/order/usecase.go:45`
**Issue**: `CreateOrder` tạo order và payment trong 2 separate DB calls. Nếu payment fail, order đã được tạo → data inconsistency.

```go
// ❌ Current code
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    order := &Order{CustomerID: input.CustomerID}
    if err := uc.orderRepo.Create(ctx, order); err != nil {
        return nil, err
    }
    
    payment := &Payment{OrderID: order.ID}
    if err := uc.paymentRepo.Create(ctx, payment); err != nil {
        return nil, err  // ❌ Order đã tạo nhưng payment fail
    }
    
    return order, nil
}
```

**Solution**: Wrap trong transaction
```go
// ✅ Fixed code
func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    var order *Order
    
    err := uc.txManager.InTx(ctx, func(ctx context.Context) error {
        order = &Order{CustomerID: input.CustomerID}
        if err := uc.orderRepo.Create(ctx, order); err != nil {
            return err
        }
        
        payment := &Payment{OrderID: order.ID}
        if err := uc.paymentRepo.Create(ctx, payment); err != nil {
            return err  // ✅ Rollback cả order và payment
        }
        
        return nil
    })
    
    return order, err
}
```

**Reference**: Xem `catalog` service implementation tại `internal/biz/product/usecase.go:123`

**Estimated**: 2 hours

---

#### 2. SQL Injection vulnerability
**File**: `internal/data/postgres/order.go:78`
**Issue**: String concatenation trong SQL query → SQL injection risk

```go
// ❌ Current code
func (r *OrderRepository) Search(ctx context.Context, keyword string) ([]*Order, error) {
    query := fmt.Sprintf("SELECT * FROM orders WHERE order_number LIKE '%%%s%%'", keyword)
    return r.db.Raw(query).Scan(&orders).Error
}
```

**Attack example**:
```
keyword = "'; DROP TABLE orders; --"
Final query: SELECT * FROM orders WHERE order_number LIKE '%'; DROP TABLE orders; --%'
```

**Solution**: Sử dụng parameterized query
```go
// ✅ Fixed code
func (r *OrderRepository) Search(ctx context.Context, keyword string) ([]*Order, error) {
    return r.db.WithContext(ctx).
        Where("order_number LIKE ?", "%"+keyword+"%").
        Find(&orders).Error
}
```

**Estimated**: 1 hour

---

### 🟡 P1 - HIGH PRIORITY (Should fix before production)

#### 3. Missing observability middleware
**File**: `internal/server/http.go:25`
**Issue**: HTTP server không có metrics và tracing middleware → không monitor được performance

**Solution**: Add middleware stack
```go
// ✅ Add this
import (
    "gitlab.com/ta-microservices/common/pkg/middleware/metrics"
    "gitlab.com/ta-microservices/common/pkg/middleware/tracing"
)

func NewHTTPServer() *http.Server {
    router := gin.New()
    
    // Add observability middleware
    router.Use(metrics.Server())
    router.Use(tracing.Server())
    
    // ... rest of setup
}
```

**Estimated**: 1 hour

---

#### 4. N+1 query problem
**File**: `internal/data/postgres/order.go:45`
**Issue**: `GetOrdersWithItems` query items trong loop → N+1 queries

**Solution**: Sử dụng Preload
```go
// ✅ Fixed code
func (r *OrderRepository) GetOrdersWithItems(ctx context.Context, customerID string) ([]*Order, error) {
    var orders []*Order
    
    err := r.db.WithContext(ctx).
        Preload("Items").
        Where("customer_id = ?", customerID).
        Find(&orders).Error
    
    return orders, err
}
```

**Estimated**: 1 hour

---

### 🔵 P2 - NICE TO HAVE (Can defer)

#### 5. Missing unit tests for edge cases
**File**: `internal/biz/order/usecase_test.go`
**Issue**: Tests chỉ cover happy path, không test edge cases

**Suggestion**: Add tests cho:
- Empty customer ID
- Empty items
- Negative quantity
- Repository errors

**Estimated**: 2 hours

---

### ✅ Good Practices Observed

1. **Clean Architecture**: Code structure tuân thủ chuẩn, tách layer rõ ràng
2. **Error Handling**: Errors được wrap và return properly
3. **Naming**: Variable và function names rõ ràng, dễ hiểu
4. **Code Organization**: Files được organize tốt theo domain

---

### 📝 Action Items

**For Developer**:
- [ ] Fix P0 issues (estimated 3h)
- [ ] Fix P1 issues (estimated 2h)
- [ ] Consider P2 improvements (estimated 2h)
- [ ] Update tests
- [ ] Re-request review

**For Reviewer**:
- [ ] Re-review after fixes
- [ ] Verify tests pass
- [ ] Check deployment readiness

---

### 📚 References

- [Backend Services Review Checklist](./BACKEND_SERVICES_REVIEW_CHECKLIST.md)
- [Catalog Service](../catalog/) - Reference implementation
- [Common Package](../common/) - Shared utilities

---

**Next Steps**:
1. Developer fixes P0 issues
2. Developer addresses P1 issues
3. Re-review
4. Merge if approved
```

---

## 🎯 QUICK REFERENCE CHECKLIST

Print này ra và check khi review:

```
□ 1. ARCHITECTURE
  □ Đúng layout (biz/data/service)
  □ Tách layer rõ ràng
  □ Dependency injection
  □ Pass golangci-lint

□ 2. API & CONTRACT
  □ Proto chuẩn
  □ Error handling đúng
  □ Input validation
  □ Backward compatible

□ 3. BUSINESS LOGIC
  □ Context propagation
  □ Goroutine safety
  □ No race conditions
  □ Idempotency

□ 4. DATA LAYER
  □ Transaction boundaries
  □ No N+1 queries
  □ Proper indexing
  □ Migration scripts

□ 5. SECURITY
  □ AuthN/AuthZ
  □ Input sanitization
  □ No hardcoded secrets
  □ No sensitive logging

□ 6. PERFORMANCE
  □ Caching strategy
  □ Bulk operations
  □ Connection pooling
  □ Pagination

□ 7. OBSERVABILITY
  □ Structured logging
  □ Prometheus metrics
  □ OpenTelemetry tracing
  □ Health checks

□ 8. TESTING
  □ Unit tests >80%
  □ Integration tests
  □ Mocks generated
  □ Coverage report

□ 9. RESILIENCE
  □ Timeouts
  □ Retries
  □ Circuit breakers
  □ Config validation

□ 10. DOCUMENTATION
  □ README complete
  □ API docs
  □ Code comments
  □ TODOs tracked
```

---

## 🚀 TIPS CHO TEAM LEAD

### 1. Ưu tiên review gì trước
1. **Security issues** (P0) - Có thể bị exploit
2. **Data consistency** (P0) - Có thể mất data
3. **Performance issues** (P1) - Ảnh hưởng user experience
4. **Code quality** (P2) - Technical debt

### 2. Làm sao review nhanh mà vẫn kỹ
- **Scan structure trước**: Check xem có đúng layout không
- **Focus vào critical paths**: Payment, inventory, auth
- **Sử dụng tools**: golangci-lint, gosec, go test -race
- **Check tests**: Nếu tests tốt → code thường tốt

### 3. Cách feedback hiệu quả
- **Cụ thể**: Chỉ rõ file, line number, vấn đề gì
- **Có ví dụ**: Show code hiện tại và code đúng
- **Giải thích tại sao**: Không chỉ nói "sai" mà giải thích risk
- **Khen ngợi**: Nhắc những điểm làm tốt

### 4. Khi nào approve
- ✅ Không có P0 issues
- ✅ P1 issues được acknowledge (có thể fix sau)
- ✅ Tests pass
- ✅ Code quality đạt chuẩn

### 5. Khi nào request changes
- ❌ Có P0 issues (security, data loss)
- ❌ Breaking changes không có migration plan
- ❌ Tests fail
- ❌ Code quality quá thấp

---

## 📞 HỖ TRỢ

Nếu gặp vấn đề khi review:
1. Check [Backend Services Review Checklist](./BACKEND_SERVICES_REVIEW_CHECKLIST.md)
2. Xem reference implementations trong `catalog`, `order`, `warehouse`
3. Hỏi Senior Tech Lead
4. Tham khảo [Common Package](../common/) documentation

---

**Version**: 1.0.0  
**Last Updated**: 16 Tháng 1, 2026  
**Maintainer**: Tech Lead Team  
**Feedback**: Gửi suggestions qua GitLab issues


# Data Flow Standards

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Purpose**: Standards for data transformation, validation, consistency, and flow patterns across services

---

## Overview

This document establishes standards for managing data flow across our microservices architecture, ensuring data integrity, consistency, and optimal performance throughout the system.

## Data Flow Patterns

### Synchronous Data Flow

#### Request-Response Pattern
```go
// Direct service-to-service data exchange
type ProductService struct {
    catalogClient CatalogServiceClient
    priceClient   PricingServiceClient
}

func (s *ProductService) GetProductWithPrice(ctx context.Context, productID string) (*ProductWithPrice, error) {
    // Get product data
    product, err := s.catalogClient.GetProduct(ctx, &GetProductRequest{
        ProductId: productID,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to get product: %w", err)
    }
    
    // Get pricing data
    price, err := s.priceClient.GetPrice(ctx, &GetPriceRequest{
        ProductId: productID,
        Currency:  "VND",
    })
    if err != nil {
        return nil, fmt.Errorf("failed to get price: %w", err)
    }
    
    // Combine data
    return &ProductWithPrice{
        Product: product,
        Price:   price,
    }, nil
}
```

#### Data Aggregation Pattern
```go
// Aggregate data from multiple sources
func (s *OrderService) GetOrderSummary(ctx context.Context, orderID string) (*OrderSummary, error) {
    // Parallel data fetching
    var (
        order    *Order
        customer *Customer
        items    []*OrderItem
        payment  *Payment
        wg       sync.WaitGroup
        mu       sync.Mutex
        errors   []error
    )
    
    // Fetch order details
    wg.Add(1)
    go func() {
        defer wg.Done()
        o, err := s.getOrder(ctx, orderID)
        if err != nil {
            mu.Lock()
            errors = append(errors, err)
            mu.Unlock()
            return
        }
        order = o
    }()
    
    // Fetch customer details
    wg.Add(1)
    go func() {
        defer wg.Done()
        c, err := s.customerClient.GetCustomer(ctx, order.CustomerID)
        if err != nil {
            mu.Lock()
            errors = append(errors, err)
            mu.Unlock()
            return
        }
        customer = c
    }()
    
    wg.Wait()
    
    if len(errors) > 0 {
        return nil, errors[0]
    }
    
    return &OrderSummary{
        Order:    order,
        Customer: customer,
        Items:    items,
        Payment:  payment,
    }, nil
}
```

### Asynchronous Data Flow

#### Event-Driven Data Propagation
```go
// Data changes propagated via events
type InventoryService struct {
    eventPublisher EventPublisher
    repository     InventoryRepository
}

func (s *InventoryService) UpdateStock(ctx context.Context, productID string, quantity int) error {
    // Update inventory
    inventory, err := s.repository.UpdateStock(ctx, productID, quantity)
    if err != nil {
        return err
    }
    
    // Publish inventory change event
    event := InventoryUpdatedEvent{
        ProductID:     productID,
        NewQuantity:   inventory.Quantity,
        PreviousQuantity: inventory.PreviousQuantity,
        Timestamp:     time.Now(),
        WarehouseID:   inventory.WarehouseID,
    }
    
    return s.eventPublisher.Publish(ctx, "inventory.updated", event)
}

// Consumer updates derived data
type SearchIndexService struct {
    searchIndex SearchIndex
}

func (s *SearchIndexService) HandleInventoryUpdated(ctx context.Context, event InventoryUpdatedEvent) error {
    // Update search index with new availability
    return s.searchIndex.UpdateProductAvailability(ctx, UpdateAvailabilityRequest{
        ProductID:   event.ProductID,
        InStock:     event.NewQuantity > 0,
        Quantity:    event.NewQuantity,
        UpdatedAt:   event.Timestamp,
    })
}
```

#### Stream Processing Pattern
```go
// Real-time data stream processing
type OrderAnalyticsProcessor struct {
    orderStream   Stream
    metricsStore  MetricsStore
}

func (p *OrderAnalyticsProcessor) ProcessOrderStream(ctx context.Context) error {
    return p.orderStream.Process(ctx, func(event OrderEvent) error {
        switch event.Type {
        case "order.created":
            return p.processOrderCreated(event)
        case "order.completed":
            return p.processOrderCompleted(event)
        case "order.cancelled":
            return p.processOrderCancelled(event)
        default:
            return nil
        }
    })
}

func (p *OrderAnalyticsProcessor) processOrderCreated(event OrderEvent) error {
    metrics := OrderMetrics{
        OrderID:      event.OrderID,
        CustomerID:   event.CustomerID,
        TotalAmount:  event.TotalAmount,
        CreatedAt:    event.Timestamp,
        Status:       "created",
    }
    
    return p.metricsStore.Store(metrics)
}
```

## Data Transformation Standards

### Schema Transformation

#### Data Transfer Objects (DTOs)
```go
// Internal domain model
type Order struct {
    ID          string
    CustomerID  string
    Items       []OrderItem
    Status      OrderStatus
    CreatedAt   time.Time
    UpdatedAt   time.Time
}

// External API DTO
type OrderDTO struct {
    ID         string    `json:"id"`
    CustomerID string    `json:"customer_id"`
    Items      []ItemDTO `json:"items"`
    Status     string    `json:"status"`
    CreatedAt  string    `json:"created_at"`
    UpdatedAt  string    `json:"updated_at"`
}

// Transformation functions
func (o *Order) ToDTO() *OrderDTO {
    items := make([]ItemDTO, len(o.Items))
    for i, item := range o.Items {
        items[i] = item.ToDTO()
    }
    
    return &OrderDTO{
        ID:         o.ID,
        CustomerID: o.CustomerID,
        Items:      items,
        Status:     string(o.Status),
        CreatedAt:  o.CreatedAt.Format(time.RFC3339),
        UpdatedAt:  o.UpdatedAt.Format(time.RFC3339),
    }
}

func (dto *OrderDTO) ToDomain() (*Order, error) {
    createdAt, err := time.Parse(time.RFC3339, dto.CreatedAt)
    if err != nil {
        return nil, fmt.Errorf("invalid created_at format: %w", err)
    }
    
    updatedAt, err := time.Parse(time.RFC3339, dto.UpdatedAt)
    if err != nil {
        return nil, fmt.Errorf("invalid updated_at format: %w", err)
    }
    
    items := make([]OrderItem, len(dto.Items))
    for i, itemDTO := range dto.Items {
        item, err := itemDTO.ToDomain()
        if err != nil {
            return nil, err
        }
        items[i] = *item
    }
    
    return &Order{
        ID:         dto.ID,
        CustomerID: dto.CustomerID,
        Items:      items,
        Status:     OrderStatus(dto.Status),
        CreatedAt:  createdAt,
        UpdatedAt:  updatedAt,
    }, nil
}
```

#### Protocol Buffer Transformations
```go
// Convert between domain models and protobuf messages
func (o *Order) ToProto() *pb.Order {
    items := make([]*pb.OrderItem, len(o.Items))
    for i, item := range o.Items {
        items[i] = item.ToProto()
    }
    
    return &pb.Order{
        Id:         o.ID,
        CustomerId: o.CustomerID,
        Items:      items,
        Status:     pb.OrderStatus(pb.OrderStatus_value[string(o.Status)]),
        CreatedAt:  timestamppb.New(o.CreatedAt),
        UpdatedAt:  timestamppb.New(o.UpdatedAt),
    }
}

func OrderFromProto(pbOrder *pb.Order) *Order {
    items := make([]OrderItem, len(pbOrder.Items))
    for i, pbItem := range pbOrder.Items {
        items[i] = *OrderItemFromProto(pbItem)
    }
    
    return &Order{
        ID:         pbOrder.Id,
        CustomerID: pbOrder.CustomerId,
        Items:      items,
        Status:     OrderStatus(pbOrder.Status.String()),
        CreatedAt:  pbOrder.CreatedAt.AsTime(),
        UpdatedAt:  pbOrder.UpdatedAt.AsTime(),
    }
}
```

### Data Enrichment

#### Context-Based Enrichment
```go
type ProductEnrichmentService struct {
    catalogService CatalogService
    pricingService PricingService
    reviewService  ReviewService
}

func (s *ProductEnrichmentService) EnrichProduct(ctx context.Context, productID string, enrichmentOptions EnrichmentOptions) (*EnrichedProduct, error) {
    // Base product data
    product, err := s.catalogService.GetProduct(ctx, productID)
    if err != nil {
        return nil, err
    }
    
    enriched := &EnrichedProduct{
        Product: product,
    }
    
    // Conditional enrichment based on options
    var wg sync.WaitGroup
    var mu sync.Mutex
    var enrichmentErrors []error
    
    if enrichmentOptions.IncludePricing {
        wg.Add(1)
        go func() {
            defer wg.Done()
            pricing, err := s.pricingService.GetPricing(ctx, productID)
            if err != nil {
                mu.Lock()
                enrichmentErrors = append(enrichmentErrors, err)
                mu.Unlock()
                return
            }
            mu.Lock()
            enriched.Pricing = pricing
            mu.Unlock()
        }()
    }
    
    if enrichmentOptions.IncludeReviews {
        wg.Add(1)
        go func() {
            defer wg.Done()
            reviews, err := s.reviewService.GetProductReviews(ctx, productID)
            if err != nil {
                mu.Lock()
                enrichmentErrors = append(enrichmentErrors, err)
                mu.Unlock()
                return
            }
            mu.Lock()
            enriched.Reviews = reviews
            mu.Unlock()
        }()
    }
    
    wg.Wait()
    
    // Handle enrichment errors (non-fatal)
    if len(enrichmentErrors) > 0 {
        log.Warn("Product enrichment partial failure", "errors", enrichmentErrors)
    }
    
    return enriched, nil
}
```

## Data Validation Standards

### Input Validation

#### Request Validation
```go
type CreateOrderRequest struct {
    CustomerID      string      `json:"customer_id" validate:"required,uuid"`
    Items          []OrderItem  `json:"items" validate:"required,min=1,dive"`
    ShippingAddress Address     `json:"shipping_address" validate:"required"`
    PaymentMethod   PaymentMethod `json:"payment_method" validate:"required"`
}

type OrderItem struct {
    ProductID string  `json:"product_id" validate:"required,uuid"`
    Quantity  int     `json:"quantity" validate:"required,min=1,max=100"`
    Price     float64 `json:"price" validate:"required,min=0"`
}

// Validation service
type ValidationService struct {
    validator *validator.Validate
}

func NewValidationService() *ValidationService {
    v := validator.New()
    
    // Custom validators
    v.RegisterValidation("uuid", validateUUID)
    v.RegisterValidation("currency", validateCurrency)
    
    return &ValidationService{validator: v}
}

func (s *ValidationService) ValidateCreateOrderRequest(req *CreateOrderRequest) error {
    if err := s.validator.Struct(req); err != nil {
        return s.formatValidationError(err)
    }
    
    // Business logic validation
    if err := s.validateBusinessRules(req); err != nil {
        return err
    }
    
    return nil
}

func (s *ValidationService) validateBusinessRules(req *CreateOrderRequest) error {
    // Check total amount limits
    totalAmount := calculateTotalAmount(req.Items)
    if totalAmount > MaxOrderAmount {
        return ErrOrderAmountTooHigh
    }
    
    // Validate item availability
    for _, item := range req.Items {
        if !s.isProductAvailable(item.ProductID, item.Quantity) {
            return fmt.Errorf("product %s not available in requested quantity", item.ProductID)
        }
    }
    
    return nil
}
```

#### Data Sanitization
```go
type DataSanitizer struct {
    htmlPolicy *bluemonday.Policy
}

func NewDataSanitizer() *DataSanitizer {
    policy := bluemonday.StrictPolicy()
    return &DataSanitizer{htmlPolicy: policy}
}

func (s *DataSanitizer) SanitizeUserInput(input string) string {
    // Remove HTML tags
    sanitized := s.htmlPolicy.Sanitize(input)
    
    // Trim whitespace
    sanitized = strings.TrimSpace(sanitized)
    
    // Remove control characters
    sanitized = removeControlCharacters(sanitized)
    
    return sanitized
}

func (s *DataSanitizer) SanitizeProductReview(review *ProductReview) *ProductReview {
    return &ProductReview{
        ID:        review.ID,
        ProductID: review.ProductID,
        UserID:    review.UserID,
        Title:     s.SanitizeUserInput(review.Title),
        Content:   s.SanitizeUserInput(review.Content),
        Rating:    review.Rating,
        CreatedAt: review.CreatedAt,
    }
}
```

### Output Validation

#### Response Validation
```go
type ResponseValidator struct {
    schemas map[string]*jsonschema.Schema
}

func (v *ResponseValidator) ValidateResponse(responseType string, data interface{}) error {
    schema, exists := v.schemas[responseType]
    if !exists {
        return fmt.Errorf("no schema found for response type: %s", responseType)
    }
    
    // Convert to JSON for validation
    jsonData, err := json.Marshal(data)
    if err != nil {
        return fmt.Errorf("failed to marshal response data: %w", err)
    }
    
    // Validate against schema
    var jsonObj interface{}
    if err := json.Unmarshal(jsonData, &jsonObj); err != nil {
        return fmt.Errorf("failed to unmarshal JSON: %w", err)
    }
    
    if err := schema.Validate(jsonObj); err != nil {
        return fmt.Errorf("response validation failed: %w", err)
    }
    
    return nil
}
```

## Data Consistency Patterns

### Eventual Consistency

#### Saga Pattern Implementation
```go
type OrderSaga struct {
    steps []SagaStep
    compensations []CompensationStep
}

type SagaStep interface {
    Execute(ctx context.Context, data SagaData) error
    GetCompensation() CompensationStep
}

type CompensationStep interface {
    Compensate(ctx context.Context, data SagaData) error
}

// Order creation saga
func (s *OrderSaga) ExecuteOrderCreation(ctx context.Context, orderData OrderCreationData) error {
    executedSteps := make([]SagaStep, 0)
    
    for _, step := range s.steps {
        err := step.Execute(ctx, orderData)
        if err != nil {
            // Compensate executed steps in reverse order
            return s.compensate(ctx, executedSteps, orderData, err)
        }
        executedSteps = append(executedSteps, step)
    }
    
    return nil
}

func (s *OrderSaga) compensate(ctx context.Context, executedSteps []SagaStep, data SagaData, originalErr error) error {
    for i := len(executedSteps) - 1; i >= 0; i-- {
        compensation := executedSteps[i].GetCompensation()
        if err := compensation.Compensate(ctx, data); err != nil {
            log.Error("Compensation failed", "step", i, "error", err)
            // Continue with other compensations
        }
    }
    
    return fmt.Errorf("saga failed and compensated: %w", originalErr)
}

// Example saga steps
type ReserveInventoryStep struct {
    inventoryService InventoryService
}

func (s *ReserveInventoryStep) Execute(ctx context.Context, data SagaData) error {
    orderData := data.(*OrderCreationData)
    return s.inventoryService.ReserveItems(ctx, orderData.OrderID, orderData.Items)
}

func (s *ReserveInventoryStep) GetCompensation() CompensationStep {
    return &ReleaseInventoryCompensation{
        inventoryService: s.inventoryService,
    }
}

type ReleaseInventoryCompensation struct {
    inventoryService InventoryService
}

func (c *ReleaseInventoryCompensation) Compensate(ctx context.Context, data SagaData) error {
    orderData := data.(*OrderCreationData)
    return c.inventoryService.ReleaseReservation(ctx, orderData.OrderID)
}
```

### Strong Consistency

#### Distributed Transaction Pattern
```go
type TransactionCoordinator struct {
    participants []TransactionParticipant
}

type TransactionParticipant interface {
    Prepare(ctx context.Context, txID string, data interface{}) error
    Commit(ctx context.Context, txID string) error
    Abort(ctx context.Context, txID string) error
}

func (tc *TransactionCoordinator) ExecuteTransaction(ctx context.Context, data interface{}) error {
    txID := generateTransactionID()
    
    // Phase 1: Prepare
    for _, participant := range tc.participants {
        if err := participant.Prepare(ctx, txID, data); err != nil {
            // Abort all participants
            tc.abortAll(ctx, txID)
            return fmt.Errorf("prepare phase failed: %w", err)
        }
    }
    
    // Phase 2: Commit
    for _, participant := range tc.participants {
        if err := participant.Commit(ctx, txID); err != nil {
            // This is a critical error - some participants may have committed
            log.Error("Commit phase failed - manual intervention required", 
                "txID", txID, "error", err)
            return fmt.Errorf("commit phase failed: %w", err)
        }
    }
    
    return nil
}

func (tc *TransactionCoordinator) abortAll(ctx context.Context, txID string) {
    for _, participant := range tc.participants {
        if err := participant.Abort(ctx, txID); err != nil {
            log.Error("Abort failed", "txID", txID, "error", err)
        }
    }
}
```

## Data Caching Strategies

### Multi-Level Caching

#### Cache Hierarchy
```go
type CacheManager struct {
    l1Cache Cache // In-memory cache
    l2Cache Cache // Redis cache
    l3Cache Cache // Database cache
}

func (cm *CacheManager) Get(ctx context.Context, key string) (interface{}, error) {
    // Try L1 cache first
    if value, found := cm.l1Cache.Get(key); found {
        return value, nil
    }
    
    // Try L2 cache
    value, err := cm.l2Cache.Get(ctx, key)
    if err == nil {
        // Populate L1 cache
        cm.l1Cache.Set(key, value, time.Minute*5)
        return value, nil
    }
    
    // Try L3 cache (database)
    value, err = cm.l3Cache.Get(ctx, key)
    if err == nil {
        // Populate L2 and L1 caches
        cm.l2Cache.Set(ctx, key, value, time.Minute*30)
        cm.l1Cache.Set(key, value, time.Minute*5)
        return value, nil
    }
    
    return nil, ErrCacheNotFound
}

func (cm *CacheManager) Set(ctx context.Context, key string, value interface{}) error {
    // Set in all cache levels
    cm.l1Cache.Set(key, value, time.Minute*5)
    cm.l2Cache.Set(ctx, key, value, time.Minute*30)
    return cm.l3Cache.Set(ctx, key, value, time.Hour*24)
}

func (cm *CacheManager) Invalidate(ctx context.Context, key string) error {
    cm.l1Cache.Delete(key)
    cm.l2Cache.Delete(ctx, key)
    return cm.l3Cache.Delete(ctx, key)
}
```

#### Cache-Aside Pattern
```go
type ProductService struct {
    repository ProductRepository
    cache      Cache
}

func (s *ProductService) GetProduct(ctx context.Context, productID string) (*Product, error) {
    cacheKey := fmt.Sprintf("product:%s", productID)
    
    // Try cache first
    if cached, found := s.cache.Get(cacheKey); found {
        return cached.(*Product), nil
    }
    
    // Cache miss - get from database
    product, err := s.repository.GetByID(ctx, productID)
    if err != nil {
        return nil, err
    }
    
    // Update cache
    s.cache.Set(cacheKey, product, time.Hour)
    
    return product, nil
}

func (s *ProductService) UpdateProduct(ctx context.Context, product *Product) error {
    // Update database
    err := s.repository.Update(ctx, product)
    if err != nil {
        return err
    }
    
    // Invalidate cache
    cacheKey := fmt.Sprintf("product:%s", product.ID)
    s.cache.Delete(cacheKey)
    
    return nil
}
```

## Performance Optimization

### Data Pagination

#### Cursor-Based Pagination
```go
type PaginationRequest struct {
    Limit  int    `json:"limit" validate:"min=1,max=100"`
    Cursor string `json:"cursor,omitempty"`
}

type PaginationResponse struct {
    Data       interface{} `json:"data"`
    NextCursor string      `json:"next_cursor,omitempty"`
    HasMore    bool        `json:"has_more"`
}

func (s *OrderService) ListOrders(ctx context.Context, req PaginationRequest) (*PaginationResponse, error) {
    var cursor time.Time
    var err error
    
    if req.Cursor != "" {
        cursor, err = decodeCursor(req.Cursor)
        if err != nil {
            return nil, fmt.Errorf("invalid cursor: %w", err)
        }
    }
    
    // Fetch one extra item to determine if there are more results
    orders, err := s.repository.ListOrdersAfter(ctx, cursor, req.Limit+1)
    if err != nil {
        return nil, err
    }
    
    hasMore := len(orders) > req.Limit
    if hasMore {
        orders = orders[:req.Limit]
    }
    
    var nextCursor string
    if hasMore && len(orders) > 0 {
        nextCursor = encodeCursor(orders[len(orders)-1].CreatedAt)
    }
    
    return &PaginationResponse{
        Data:       orders,
        NextCursor: nextCursor,
        HasMore:    hasMore,
    }, nil
}

func encodeCursor(t time.Time) string {
    return base64.URLEncoding.EncodeToString([]byte(t.Format(time.RFC3339Nano)))
}

func decodeCursor(cursor string) (time.Time, error) {
    data, err := base64.URLEncoding.DecodeString(cursor)
    if err != nil {
        return time.Time{}, err
    }
    
    return time.Parse(time.RFC3339Nano, string(data))
}
```

### Data Compression

#### Response Compression
```go
type CompressionMiddleware struct {
    threshold int // Minimum response size to compress
}

func (m *CompressionMiddleware) Compress(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Check if client accepts compression
        if !strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
            next(w, r)
            return
        }
        
        // Wrap response writer
        gzw := &gzipResponseWriter{
            ResponseWriter: w,
            threshold:      m.threshold,
        }
        defer gzw.Close()
        
        next(gzw, r)
    }
}

type gzipResponseWriter struct {
    http.ResponseWriter
    writer    *gzip.Writer
    threshold int
    buffer    []byte
}

func (w *gzipResponseWriter) Write(data []byte) (int, error) {
    if w.writer == nil {
        w.buffer = append(w.buffer, data...)
        
        // Check if we should compress
        if len(w.buffer) >= w.threshold {
            w.Header().Set("Content-Encoding", "gzip")
            w.writer = gzip.NewWriter(w.ResponseWriter)
            
            // Write buffered data
            if _, err := w.writer.Write(w.buffer); err != nil {
                return 0, err
            }
            w.buffer = nil
        }
        
        return len(data), nil
    }
    
    return w.writer.Write(data)
}
```

## Monitoring and Observability

### Data Flow Metrics

#### Custom Metrics
```go
var (
    dataTransformationDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "data_transformation_duration_seconds",
            Help: "Time spent transforming data",
        },
        []string{"source_type", "target_type", "operation"},
    )
    
    dataValidationErrors = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "data_validation_errors_total",
            Help: "Total number of data validation errors",
        },
        []string{"validation_type", "error_type"},
    )
    
    cacheHitRate = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "cache_operations_total",
            Help: "Total cache operations",
        },
        []string{"cache_level", "operation", "result"},
    )
)

func instrumentDataTransformation(sourceType, targetType, operation string, fn func() error) error {
    start := time.Now()
    err := fn()
    duration := time.Since(start).Seconds()
    
    dataTransformationDuration.WithLabelValues(sourceType, targetType, operation).Observe(duration)
    
    return err
}
```

---

**Last Updated**: January 31, 2026  
**Maintained By**: Data Architecture Team
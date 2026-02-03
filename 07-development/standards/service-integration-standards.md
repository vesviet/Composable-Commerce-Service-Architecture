# Service Integration Standards

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Purpose**: Standards for service-to-service integration patterns, API contracts, and communication protocols

---

## Overview

This document establishes standards for integrating services within our microservices architecture, ensuring reliable, secure, and maintainable service communication.

## Integration Patterns

### Synchronous Communication

#### gRPC Integration
**Primary Pattern**: Use gRPC for synchronous service-to-service communication

```proto
// Example service definition
service OrderService {
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
  rpc GetOrder(GetOrderRequest) returns (GetOrderResponse);
  rpc UpdateOrderStatus(UpdateOrderStatusRequest) returns (UpdateOrderStatusResponse);
}

message CreateOrderRequest {
  string customer_id = 1;
  repeated OrderItem items = 2;
  Address shipping_address = 3;
  PaymentMethod payment_method = 4;
}
```

#### HTTP/REST Integration
**Secondary Pattern**: Use REST for external integrations and admin interfaces

```yaml
# OpenAPI specification example
paths:
  /api/v1/orders:
    post:
      summary: Create new order
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateOrderRequest'
      responses:
        '201':
          description: Order created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Order'
```

### Asynchronous Communication

#### Event-Driven Integration
**Primary Pattern**: Use events for loose coupling and eventual consistency

```go
// Event publishing
type OrderCreatedEvent struct {
    OrderID    string    `json:"orderId"`
    CustomerID string    `json:"customerId"`
    Amount     float64   `json:"amount"`
    CreatedAt  time.Time `json:"createdAt"`
}

func (s *OrderService) CreateOrder(ctx context.Context, req *CreateOrderRequest) error {
    // Create order
    order := s.createOrder(req)
    
    // Publish event
    event := OrderCreatedEvent{
        OrderID:    order.ID,
        CustomerID: order.CustomerID,
        Amount:     order.TotalAmount,
        CreatedAt:  time.Now(),
    }
    
    return s.eventPublisher.Publish(ctx, "order.created", event)
}
```

#### Message Queue Integration
**Use Case**: For reliable message delivery and load balancing

```go
// Message queue consumer
func (h *InventoryHandler) HandleOrderCreated(ctx context.Context, msg *OrderCreatedMessage) error {
    // Reserve inventory
    err := h.inventoryService.ReserveItems(ctx, msg.OrderID, msg.Items)
    if err != nil {
        // Return error to trigger retry
        return fmt.Errorf("failed to reserve inventory: %w", err)
    }
    
    // Acknowledge message
    return nil
}
```

## API Contract Standards

### gRPC Contract Design

#### Service Definition Guidelines
- **Versioning**: Include version in package name (`api.order.v1`)
- **Naming**: Use clear, descriptive service and method names
- **Request/Response**: Separate request and response messages
- **Pagination**: Standard pagination for list operations

```proto
syntax = "proto3";

package api.order.v1;

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

service OrderService {
  rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse);
  rpc GetOrder(GetOrderRequest) returns (Order);
  rpc CreateOrder(CreateOrderRequest) returns (Order);
  rpc UpdateOrder(UpdateOrderRequest) returns (Order);
  rpc DeleteOrder(DeleteOrderRequest) returns (google.protobuf.Empty);
}

message ListOrdersRequest {
  int32 page_size = 1;
  string page_token = 2;
  string filter = 3;
  string order_by = 4;
}

message ListOrdersResponse {
  repeated Order orders = 1;
  string next_page_token = 2;
  int32 total_size = 3;
}
```

#### Error Handling
```proto
// Standard error response
message ErrorResponse {
  string code = 1;
  string message = 2;
  repeated ErrorDetail details = 3;
}

message ErrorDetail {
  string field = 1;
  string description = 2;
}
```

### REST API Contract Design

#### Resource Naming
- **Collections**: Use plural nouns (`/orders`, `/customers`)
- **Resources**: Use resource ID (`/orders/{orderId}`)
- **Sub-resources**: Nested resources (`/orders/{orderId}/items`)

#### HTTP Methods
- **GET**: Retrieve resources (idempotent)
- **POST**: Create new resources
- **PUT**: Update entire resource (idempotent)
- **PATCH**: Partial resource update
- **DELETE**: Remove resource (idempotent)

#### Response Formats
```json
// Success response
{
  "data": {
    "id": "order-123",
    "status": "confirmed",
    "items": [...]
  },
  "meta": {
    "timestamp": "2026-01-31T10:00:00Z",
    "version": "1.0"
  }
}

// Error response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid order data",
    "details": [
      {
        "field": "customer_id",
        "message": "Customer ID is required"
      }
    ]
  },
  "meta": {
    "timestamp": "2026-01-31T10:00:00Z",
    "request_id": "req-456"
  }
}
```

## Client Implementation Standards

### gRPC Client Configuration

#### Connection Management
```go
type ServiceClient struct {
    conn   *grpc.ClientConn
    client pb.OrderServiceClient
}

func NewServiceClient(address string) (*ServiceClient, error) {
    // Connection with retry and timeout
    conn, err := grpc.Dial(address,
        grpc.WithTransportCredentials(insecure.NewCredentials()),
        grpc.WithUnaryInterceptor(grpc_retry.UnaryClientInterceptor(
            grpc_retry.WithMax(3),
            grpc_retry.WithBackoff(grpc_retry.BackoffExponential(100*time.Millisecond)),
        )),
        grpc.WithTimeout(30*time.Second),
    )
    if err != nil {
        return nil, err
    }
    
    return &ServiceClient{
        conn:   conn,
        client: pb.NewOrderServiceClient(conn),
    }, nil
}
```

#### Error Handling
```go
func (c *ServiceClient) GetOrder(ctx context.Context, orderID string) (*Order, error) {
    req := &pb.GetOrderRequest{OrderId: orderID}
    
    resp, err := c.client.GetOrder(ctx, req)
    if err != nil {
        // Handle gRPC errors
        if status.Code(err) == codes.NotFound {
            return nil, ErrOrderNotFound
        }
        return nil, fmt.Errorf("failed to get order: %w", err)
    }
    
    return convertFromProto(resp), nil
}
```

### HTTP Client Configuration

#### Client Setup
```go
type HTTPClient struct {
    client  *http.Client
    baseURL string
}

func NewHTTPClient(baseURL string) *HTTPClient {
    return &HTTPClient{
        client: &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                MaxIdleConns:        100,
                MaxIdleConnsPerHost: 10,
                IdleConnTimeout:     90 * time.Second,
            },
        },
        baseURL: baseURL,
    }
}
```

#### Request/Response Handling
```go
func (c *HTTPClient) CreateOrder(ctx context.Context, order *CreateOrderRequest) (*Order, error) {
    body, err := json.Marshal(order)
    if err != nil {
        return nil, err
    }
    
    req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/orders", bytes.NewBuffer(body))
    if err != nil {
        return nil, err
    }
    
    req.Header.Set("Content-Type", "application/json")
    
    resp, err := c.client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusCreated {
        return nil, c.handleErrorResponse(resp)
    }
    
    var result Order
    err = json.NewDecoder(resp.Body).Decode(&result)
    return &result, err
}
```

## Reliability Patterns

### Circuit Breaker Pattern

#### Implementation
```go
type CircuitBreaker struct {
    maxFailures int
    timeout     time.Duration
    failures    int
    lastFailure time.Time
    state       CircuitState
    mutex       sync.RWMutex
}

type CircuitState int

const (
    Closed CircuitState = iota
    Open
    HalfOpen
)

func (cb *CircuitBreaker) Call(fn func() error) error {
    cb.mutex.Lock()
    defer cb.mutex.Unlock()
    
    if cb.state == Open {
        if time.Since(cb.lastFailure) > cb.timeout {
            cb.state = HalfOpen
        } else {
            return ErrCircuitBreakerOpen
        }
    }
    
    err := fn()
    if err != nil {
        cb.failures++
        cb.lastFailure = time.Now()
        
        if cb.failures >= cb.maxFailures {
            cb.state = Open
        }
        return err
    }
    
    // Success - reset circuit breaker
    cb.failures = 0
    cb.state = Closed
    return nil
}
```

### Retry Pattern

#### Exponential Backoff
```go
type RetryConfig struct {
    MaxRetries  int
    BaseDelay   time.Duration
    MaxDelay    time.Duration
    Multiplier  float64
    Jitter      bool
}

func RetryWithBackoff(ctx context.Context, config RetryConfig, fn func() error) error {
    var lastErr error
    
    for attempt := 0; attempt <= config.MaxRetries; attempt++ {
        if attempt > 0 {
            delay := calculateDelay(config, attempt)
            select {
            case <-time.After(delay):
            case <-ctx.Done():
                return ctx.Err()
            }
        }
        
        lastErr = fn()
        if lastErr == nil {
            return nil
        }
        
        // Check if error is retryable
        if !isRetryableError(lastErr) {
            return lastErr
        }
    }
    
    return fmt.Errorf("max retries exceeded: %w", lastErr)
}
```

### Timeout Pattern

#### Context-Based Timeouts
```go
func (s *OrderService) CreateOrderWithTimeout(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    // Set timeout for the entire operation
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    
    // Call downstream services with timeout
    customer, err := s.customerClient.GetCustomer(ctx, req.CustomerID)
    if err != nil {
        return nil, fmt.Errorf("failed to get customer: %w", err)
    }
    
    inventory, err := s.inventoryClient.CheckAvailability(ctx, req.Items)
    if err != nil {
        return nil, fmt.Errorf("failed to check inventory: %w", err)
    }
    
    // Create order
    return s.createOrder(ctx, req, customer, inventory)
}
```

## Security Standards

### Authentication

#### Service-to-Service Authentication
```go
// JWT token for service authentication
type ServiceAuthenticator struct {
    privateKey *rsa.PrivateKey
    publicKey  *rsa.PublicKey
    serviceID  string
}

func (a *ServiceAuthenticator) GenerateToken() (string, error) {
    claims := jwt.MapClaims{
        "sub": a.serviceID,
        "iss": "service-auth",
        "aud": "microservices",
        "exp": time.Now().Add(time.Hour).Unix(),
        "iat": time.Now().Unix(),
    }
    
    token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
    return token.SignedString(a.privateKey)
}
```

#### mTLS Configuration
```go
func setupMTLS(certFile, keyFile, caFile string) (*tls.Config, error) {
    cert, err := tls.LoadX509KeyPair(certFile, keyFile)
    if err != nil {
        return nil, err
    }
    
    caCert, err := ioutil.ReadFile(caFile)
    if err != nil {
        return nil, err
    }
    
    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)
    
    return &tls.Config{
        Certificates: []tls.Certificate{cert},
        ClientCAs:    caCertPool,
        ClientAuth:   tls.RequireAndVerifyClientCert,
    }, nil
}
```

### Authorization

#### Role-Based Access Control
```go
type AuthorizationMiddleware struct {
    permissions map[string][]string
}

func (m *AuthorizationMiddleware) CheckPermission(ctx context.Context, resource, action string) error {
    userRoles := getUserRoles(ctx)
    requiredPermission := fmt.Sprintf("%s:%s", resource, action)
    
    for _, role := range userRoles {
        if permissions, exists := m.permissions[role]; exists {
            for _, permission := range permissions {
                if permission == requiredPermission || permission == "*" {
                    return nil
                }
            }
        }
    }
    
    return ErrUnauthorized
}
```

## Monitoring and Observability

### Distributed Tracing

#### OpenTelemetry Integration
```go
func setupTracing(serviceName string) {
    exporter, err := jaeger.New(jaeger.WithCollectorEndpoint())
    if err != nil {
        log.Fatal(err)
    }
    
    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.ServiceNameKey.String(serviceName),
        )),
    )
    
    otel.SetTracerProvider(tp)
}

func (s *OrderService) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    tracer := otel.Tracer("order-service")
    ctx, span := tracer.Start(ctx, "CreateOrder")
    defer span.End()
    
    span.SetAttributes(
        attribute.String("customer.id", req.CustomerID),
        attribute.Int("items.count", len(req.Items)),
    )
    
    // Service logic with tracing
    order, err := s.processOrder(ctx, req)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }
    
    span.SetAttributes(attribute.String("order.id", order.ID))
    return order, nil
}
```

### Metrics Collection

#### Prometheus Metrics
```go
var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "service_requests_total",
            Help: "Total number of requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "service_request_duration_seconds",
            Help: "Request duration in seconds",
        },
        []string{"method", "endpoint"},
    )
)

func instrumentHandler(handler http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        // Wrap response writer to capture status code
        wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
        
        handler(wrapped, r)
        
        duration := time.Since(start).Seconds()
        
        requestsTotal.WithLabelValues(
            r.Method,
            r.URL.Path,
            strconv.Itoa(wrapped.statusCode),
        ).Inc()
        
        requestDuration.WithLabelValues(
            r.Method,
            r.URL.Path,
        ).Observe(duration)
    }
}
```

## Testing Standards

### Integration Testing

#### Service Contract Testing
```go
func TestOrderService_CreateOrder_Integration(t *testing.T) {
    // Setup test environment
    testContainer := setupTestContainer()
    defer testContainer.Cleanup()
    
    // Create test client
    client := NewOrderServiceClient(testContainer.GRPCAddress())
    
    // Test data
    req := &pb.CreateOrderRequest{
        CustomerId: "customer-123",
        Items: []*pb.OrderItem{
            {ProductId: "product-456", Quantity: 2},
        },
    }
    
    // Execute request
    resp, err := client.CreateOrder(context.Background(), req)
    
    // Assertions
    assert.NoError(t, err)
    assert.NotEmpty(t, resp.OrderId)
    assert.Equal(t, "pending", resp.Status)
}
```

#### End-to-End Testing
```go
func TestOrderFlow_EndToEnd(t *testing.T) {
    // Setup all required services
    services := setupServiceCluster()
    defer services.Cleanup()
    
    // Create order through API gateway
    orderResp := services.Gateway.CreateOrder(createOrderRequest)
    assert.NotNil(t, orderResp)
    
    // Verify order in order service
    order := services.OrderService.GetOrder(orderResp.OrderID)
    assert.Equal(t, "confirmed", order.Status)
    
    // Verify inventory reservation
    inventory := services.InventoryService.GetReservation(orderResp.OrderID)
    assert.NotNil(t, inventory)
    
    // Verify payment processing
    payment := services.PaymentService.GetPayment(orderResp.OrderID)
    assert.Equal(t, "completed", payment.Status)
}
```

## Performance Standards

### Response Time Requirements
- **Synchronous Calls**: < 100ms (P95)
- **Database Operations**: < 50ms (P95)
- **External API Calls**: < 2 seconds (P95)
- **Event Publishing**: < 10ms (P95)

### Throughput Requirements
- **High-Volume Services**: 10,000+ RPS
- **Standard Services**: 1,000+ RPS
- **Admin Services**: 100+ RPS

### Resource Utilization
- **CPU Usage**: < 70% average
- **Memory Usage**: < 80% of allocated
- **Connection Pools**: Properly sized for load
- **Database Connections**: Efficient connection management

---

**Last Updated**: January 31, 2026  
**Maintained By**: Platform Integration Team
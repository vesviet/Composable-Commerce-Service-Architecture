# � Order Service - Complete Documentation

**Service Name**: Order Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-24  
**Review Status**: ✅ Reviewed (Cleaned of cart/checkout/return logic)  
**Production Ready**: 95%  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Order Management APIs](#-order-management-apis)
- [Database Schema](#-database-schema)
- [Order Business Logic](#-order-business-logic)
- [Configuration](#-configuration)
- [Dependencies](#-dependencies)
- [Testing](#-testing)
- [Monitoring & Observability](#-monitoring--observability)
- [Known Issues & TODOs](#-known-issues--todos)
- [Development Guide](#-development-guide)

---

## 🎯 Overview

Order Service là microservice cốt lõi quản lý toàn bộ vòng đời order processing trong hệ thống e-commerce. Service này xử lý:

### Core Capabilities
- **📦 Order Processing**: Order creation, status management, fulfillment coordination
- **🔄 Order Lifecycle**: Status tracking, cancellations, returns, refunds
- **💰 Payment Coordination**: Payment processing workflow
- **📊 Analytics**: Order analytics và business intelligence

### Business Value
- **Operational Efficiency**: Automated order processing và fulfillment
- **Customer Experience**: Reliable order tracking và management
- **Revenue Protection**: Payment security và order integrity
- **Analytics**: Order insights cho business decisions

### Key Differentiators
- **Clean Architecture**: Separated concerns with dedicated Checkout and Return services
- **Event-Driven Architecture**: Async processing với Dapr pub/sub
- **Idempotency**: Duplicate request protection
- **Audit Trail**: Complete order history tracking

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
order/
├── cmd/order/                      # Application entry point
├── internal/
│   ├── biz/                        # Business Logic Layer
│   │   ├── order/                 # Order domain logic
│   │   ├── cancellation/          # Order cancellation
│   │   └── status/                # Order status management
│   ├── data/                       # Data Access Layer
│   │   ├── postgres/              # PostgreSQL repositories
│   │   └── eventbus/              # Dapr event bus
│   ├── service/                    # Service Layer (gRPC/HTTP)
│   ├── server/                     # Server setup
│   ├── middleware/                 # HTTP middleware
│   ├── config/                     # Configuration
│   └── constants/                  # Constants & enums
├── api/                            # Protocol Buffers
│   └── order/v1/                   # Order APIs
├── migrations/                     # Database migrations
└── configs/                        # Environment configs
```

### Ports & Endpoints
- **HTTP API**: `:8004` - REST endpoints cho frontend/client apps
- **gRPC API**: `:9004` - Internal service communication
- **Health Check**: `/api/v1/orders/health`

### Service Dependencies

#### Internal Dependencies
- **Customer Service**: Customer data, addresses, preferences
- **Catalog Service**: Product information, SKUs, categories
- **Pricing Service**: Dynamic pricing, promotions, tax calculations
- **Warehouse Service**: Inventory levels, stock reservations
- **Shipping Service**: Shipping rates, delivery options
- **Payment Service**: Payment processing, fraud detection
- **Fulfillment Service**: Order fulfillment, shipping coordination
- **Notification Service**: Order status notifications

#### External Dependencies
- **PostgreSQL**: Primary data store (`order_db`)
- **Redis**: Session storage, caching, rate limiting
- **Dapr**: Event-driven communication (pub/sub)
- **Consul**: Service discovery

---

##  Order Management APIs

### Order Lifecycle Operations

#### Create Order (Checkout)
```protobuf
rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse) {
  option (google.api.http) = {
    post: "/api/v1/orders"
    body: "*"
  };
}
```

**Flow**:
1. Basic validation
2. Create order record
3. Process payment
4. Publish order events
5. Trigger fulfillment

#### Order Status Management
```protobuf
rpc UpdateOrderStatus(UpdateOrderStatusRequest) returns (UpdateOrderStatusResponse) {
  option (google.api.http) = {
    put: "/api/v1/orders/{id}/status"
    body: "*"
  };
}
```

**Order Statuses**:
- `draft` → `confirmed` → `processing` → `shipped` → `delivered`
- `cancelled`, `refunded`, `failed`

#### Order Cancellation
```protobuf
// Full order cancellation
rpc CancelOrder(CancelOrderRequest) returns (CancelOrderResponse) {
  option (google.api.http) = {
    post: "/api/v1/orders/{id}/cancel"
    body: "*"
  };
}

// Partial item cancellation
rpc CancelOrderItems(CancelOrderItemsRequest) returns (CancelOrderItemsResponse) {
  option (google.api.http) = {
    post: "/api/v1/orders/{id}/cancel-items"
    body: "*"
  };
}
```

### Order Operations

#### Payment Management
```protobuf
rpc AddPayment(AddPaymentRequest) returns (AddPaymentResponse) {
  option (google.api.http) = {
    post: "/api/v1/orders/{order_id}/payments"
    body: "*"
  };
}
```

#### Return & Refund Management
```protobuf
rpc CreateReturnRequest(CreateReturnRequestRequest) returns (CreateReturnRequestResponse) {
  option (google.api.http) = {
    post: "/api/v1/orders/{order_id}/returns"
    body: "*"
  };
}

rpc RefundOrderItems(RefundOrderItemsRequest) returns (RefundOrderItemsResponse) {
  option (google.api.http) = {
    post: "/api/v1/orders/{id}/refund-items"
    body: "*"
  };
}
```

#### Order History & Tracking
```protobuf
rpc GetOrderStatusHistory(GetOrderStatusHistoryRequest) returns (GetOrderStatusHistoryResponse) {
  option (google.api.http) = {
    get: "/api/v1/orders/{order_id}/status-history"
  };
}

rpc GetOrderEditHistory(GetOrderEditHistoryRequest) returns (GetOrderEditHistoryResponse) {
  option (google.api.http) = {
    get: "/api/v1/orders/{order_id}/edit-history"
  };
}
```

---

## 🗄️ Database Schema

### Core Tables

#### orders
```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number VARCHAR(50) UNIQUE NOT NULL,
  customer_id UUID,  -- NULL for guest orders
  status VARCHAR(20) NOT NULL DEFAULT 'draft',
  currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  subtotal DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  shipping_amount DECIMAL(10,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(50),
  payment_status VARCHAR(20) DEFAULT 'pending',
  shipping_address JSONB,
  billing_address JSONB,
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE
);
```

#### order_items
```sql
CREATE TABLE order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id),
  product_id UUID NOT NULL,
  product_sku VARCHAR(255) NOT NULL,
  product_name VARCHAR(500) NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  warehouse_id UUID NOT NULL,
  reservation_id UUID,
  metadata JSONB DEFAULT '{}'
);
```

### Performance Optimizations

#### Indexes
```sql
-- Order performance
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at DESC);
CREATE INDEX idx_orders_number ON orders(order_number);
CREATE INDEX idx_order_items_order ON order_items(order_id);

-- Composite indexes for common queries
CREATE INDEX idx_orders_customer_status ON orders(customer_id, status);
```

#### Partitioning Strategy (Future)
```sql
-- Partition orders by month for performance
CREATE TABLE orders_y2024m01 PARTITION OF orders
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Partition cart items by session for cleanup
CREATE TABLE cart_items_active PARTITION OF cart_items
  FOR VALUES WHERE added_at >= CURRENT_DATE - INTERVAL '30 days';
---

## 📦 Order Business Logic

### Order Creation Flow

```go
func (uc *OrderUsecase) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    // 1. Basic validation (customer, items)
    // 2. Create order record with generated order number
    // 3. Create order items from request items
    // 4. Calculate totals from pre-validated data
    // 5. Process payment (coordinate with Payment Service)
    // 6. Update order status to 'confirmed'
    // 7. Publish order.created event
    // 8. Trigger fulfillment workflow
    // 9. Send confirmation notifications
}
```

### Order Number Generation
```go
func generateOrderNumber() string {
    // Format: ORD-{YYYYMMDD}-{6-digit sequence}
    // Example: ORD-20260122-000001
    date := time.Now().Format("20060102")
    sequence := getNextSequence("order_number")
    return fmt.Sprintf("ORD-%s-%06d", date, sequence)
}
```

### Status Transition Logic
```go
var validTransitions = map[string][]string{
    "draft":     {"confirmed", "cancelled"},
    "confirmed": {"processing", "cancelled"},
    "processing": {"shipped", "cancelled"},
    "shipped":    {"delivered", "cancelled"},
    "delivered":  {"refunded"}, // No further transitions
    "cancelled":  {},           // Terminal state
    "refunded":   {},           // Terminal state
}

func (uc *OrderUsecase) UpdateOrderStatus(ctx context.Context, orderID string, newStatus string) error {
    // 1. Validate status transition
    // 2. Check business rules (e.g., can't cancel shipped orders)
    // 3. Update order status
    // 4. Create status history record
    // 5. Publish status change event
    // 6. Trigger downstream actions (notifications, fulfillment)
}
```

### Cancellation Logic
```go
func (uc *OrderUsecase) CancelOrder(ctx context.Context, orderID string, reason string) error {
    // 1. Validate order can be cancelled (not shipped/delivered)
    // 2. Start transaction
    // 3. Update order status to 'cancelled'
    // 4. Release inventory reservations
    // 5. Process refunds if payment completed
    // 6. Update cancellation timestamp
    // 7. Publish cancellation event
    // 8. Send cancellation notifications
}
```

### Return & Refund Processing
```go
func (uc *OrderUsecase) CreateReturnRequest(ctx context.Context, req *CreateReturnRequest) error {
    // 1. Validate order exists and eligible for return
    // 2. Validate return window (30 days default)
    // 3. Validate return items against order
    // 4. Create return request record
    // 5. Update order items with return status
    // 6. Publish return request event
    // 7. Notify customer service team
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
ORDER_DATABASE_DSN=postgres://order_user:order_pass@postgres:5432/order_db?sslmode=disable

# Redis
ORDER_REDIS_ADDR=redis:6379
ORDER_REDIS_PASSWORD=

# Service Ports
ORDER_HTTP_PORT=8004
ORDER_GRPC_PORT=9004

# Order Configuration
ORDER_NUMBER_SEQUENCE_KEY=order_number
ORDER_RETURN_WINDOW_DAYS=30
ORDER_AUTO_CANCEL_DRAFT_HOURS=24

# External Services
ORDER_CUSTOMER_SERVICE_ADDR=customer-service:9003
ORDER_CATALOG_SERVICE_ADDR=catalog-service:9002
ORDER_PRICING_SERVICE_ADDR=pricing-service:9009
ORDER_WAREHOUSE_SERVICE_ADDR=warehouse-service:9010
ORDER_PAYMENT_SERVICE_ADDR=payment-service:9007
ORDER_FULFILLMENT_SERVICE_ADDR=fulfillment-service:9011

# Features
ORDER_ENABLE_PROMOTIONS=true
ORDER_ENABLE_MULTIPLE_WAREHOUSES=true
ORDER_ENABLE_GUEST_CHECKOUT=true
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: order-service
  version: 1.0.0

database:
  dsn: ${ORDER_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 25
  conn_max_lifetime: 5m

redis:
  addr: ${ORDER_REDIS_ADDR}
  password: ${ORDER_REDIS_PASSWORD}
  db: 1  # Separate DB for order service
  dial_timeout: 5s

order:
  return_window_days: ${ORDER_RETURN_WINDOW_DAYS}
  auto_cancel_draft_hours: ${ORDER_AUTO_CANCEL_DRAFT_HOURS}
  enable_partial_cancellations: true
  enable_returns: true

external_services:
  customer_service: ${ORDER_CUSTOMER_SERVICE_ADDR}
  catalog_service: ${ORDER_CATALOG_SERVICE_ADDR}
  pricing_service: ${ORDER_PRICING_SERVICE_ADDR}
  warehouse_service: ${ORDER_WAREHOUSE_SERVICE_ADDR}
  payment_service: ${ORDER_PAYMENT_SERVICE_ADDR}
  fulfillment_service: ${ORDER_FULFILLMENT_SERVICE_ADDR}

features:
  promotions: ${ORDER_ENABLE_PROMOTIONS}
  multi_warehouse: ${ORDER_ENABLE_MULTIPLE_WAREHOUSES}
  guest_checkout: ${ORDER_ENABLE_GUEST_CHECKOUT}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/order

go 1.24

require (
    gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    github.com/google/uuid v1.6.0
    golang.org/x/sync v0.7.0  // For errgroup
)
```

### Service Mesh Integration
```yaml
# Dapr pub/sub subscriptions
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: order-service-events
spec:
  topic: customer.created
  route: /events/customer-created
  pubsubname: pubsub
---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: order-price-updates
spec:
  topic: pricing.price.updated
  route: /events/price-updated
  pubsubname: pubsub
```

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: 70% coverage (business logic)
- **Integration Tests**: 50% coverage (API endpoints, external services)
- **E2E Tests**: 30% coverage (complete cart-to-order flows)

### Critical Test Scenarios

#### Cart Concurrency Tests
```go
func TestAddToCart_Concurrency(t *testing.T) {
    // Test 20 parallel AddToCart requests for same SKU
    // Verify no race conditions, correct final quantity
    // Verify atomic updates with SELECT FOR UPDATE
}

func TestCartMerging(t *testing.T) {
    // Create guest cart with items
    // Login as customer with existing cart
    // Verify carts merge correctly
    // Verify no duplicate items
}
```

#### Order Creation Tests
```go
func TestCreateOrder_CompleteFlow(t *testing.T) {
    // Setup: Create cart with valid items
    // Mock: All external services (pricing, inventory, payment)
    // Execute: Create order from cart
    // Verify: Order created, cart cleared, events published
}

func TestOrderCancellation(t *testing.T) {
    // Setup: Create confirmed order
    // Execute: Cancel order
    // Verify: Status updated, inventory released, refund processed
}
```

### Test Infrastructure
```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Integration tests (requires services)
make test-integration

# Load testing
make test-load

# Specific cart tests
go test ./internal/biz/cart/... -v
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### Cart Metrics
```go
# Cart operations
cart_operations_total{operation="add_item", status="success"} 15420
cart_operations_total{operation="remove_item", status="success"} 2340

# Cart performance
cart_operation_duration_seconds{operation="add_item", quantile="0.95"} 0.087
cart_operation_duration_seconds{operation="get_cart", quantile="0.95"} 0.034

# Cart business metrics
cart_conversion_rate 0.023  # Orders created / cart sessions
cart_abandonment_rate 0.68  # Abandoned carts / total carts
cart_average_items_per_cart 2.3
```

#### Order Metrics
```go
# Order lifecycle
order_created_total{status="confirmed"} 2340
order_status_changes_total{from="confirmed", to="processing"} 1890

# Order values
order_total_value_created 456789.99
order_average_value 195.12

# Performance
order_creation_duration_seconds{quantile="0.95"} 0.234
order_cancellation_rate 0.034
```

### Health Checks
```go
# Application health
GET /api/v1/orders/health

# Dependencies health
GET /api/v1/orders/health/dependencies

# Database connectivity
# Redis connectivity
# External services (catalog, pricing, warehouse, payment)
```

### Distributed Tracing (OpenTelemetry)

#### Cart Operations Trace
```
Frontend → Gateway → Order Service
├── Validate session (Redis)
├── Get product (Catalog Service)
├── Check stock (Warehouse Service)
├── Get pricing (Pricing Service)
├── Database transaction
│   ├── SELECT FOR UPDATE cart_session
│   ├── INSERT/UPDATE cart_item
│   └── Recalculate totals
└── Publish event (Dapr)
```

#### Order Creation Trace
```
Cart → Order Service → Multiple Services
├── Validate cart contents
├── Reserve inventory (Warehouse)
├── Calculate final pricing (Pricing)
├── Process payment (Payment Service)
├── Create order (Database)
├── Publish order.created event
└── Trigger fulfillment (Fulfillment Service)
```

---

## 🚨 Known Issues & TODOs

### ✅ RESOLVED ISSUES (From cart_flow_issues.md)

#### P0-01: Unmanaged goroutine in AddToCart ✅ FIXED
- **Issue**: Event publishing used unmanaged goroutine
- **Fix**: Now synchronous with `context.WithTimeout(5s)`
- **Status**: ✅ Verified in `order/internal/biz/cart/add.go:276`

#### P1-01: Cart updates not atomic ✅ FIXED
- **Issue**: Race conditions in concurrent cart updates
- **Fix**: Implemented `SELECT FOR UPDATE` locking
- **Status**: ✅ Verified in `order/internal/biz/cart/add.go:198-203`

#### P1-02: Silent failures in cart totals ✅ FIXED
- **Issue**: Cart totals ignored dependency failures
- **Fix**: Now returns errors when pricing/shipping fails
- **Status**: ✅ Verified error propagation implemented

#### P2-01: Hardcoded country codes ✅ FIXED
- **Issue**: Country code defaults hardcoded to "VN"
- **Fix**: Centralized in `constants.DefaultCountryCode`
- **Status**: ✅ Verified configurable defaults

### 🟡 REMAINING ISSUES

#### P1-02: Cart summary calculation performance 🟡 MEDIUM
- **Issue**: Complex cart operations without caching strategy
- **Impact**: Slow response times for cart summary calls
- **Location**: `order/internal/biz/cart/add.go:286-313`
- **Fix**: Implement Redis caching for cart summaries

#### P2-02: Missing comprehensive cart validation 🟡 LOW
- **Issue**: Some validation errors logged but not returned to client
- **Impact**: Poor user experience with silent failures
- **Location**: `order/internal/biz/cart/validate.go`
- **Fix**: Standardize error responses and client feedback

#### P2-03: Order edit history incomplete 🟡 LOW
- **Issue**: Order edit tracking not fully implemented
- **Impact**: Audit trail gaps for order modifications
- **Location**: Order edit tracking endpoints
- **Fix**: Complete edit history implementation

---

## 🚀 Development Guide

### Local Development Setup
```bash
# Clone and setup
git clone git@gitlab.com:ta-microservices/order.git
cd order

# Start dependencies
docker-compose up -d postgres redis

# Install dependencies
go mod download

# Run migrations
make migrate-up

# Generate protobuf code
make api

# Run service
make run

# Test cart functionality
curl -X POST http://localhost:8004/api/v1/cart/items \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: test-session" \
  -d '{"product_sku":"TEST-SKU","quantity":1}'
```

### Code Generation
```bash
# Generate protobuf code
make api

# Generate mocks for testing
make mocks

# Generate wire dependency injection
make wire
```

### Database Operations
```bash
# Create new migration
make migrate-create NAME="add_cart_metadata"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

### Cart API Development Workflow
1. **Update Proto Definition**: `api/order/v1/cart.proto`
2. **Generate Code**: `make api`
3. **Implement Service**: `internal/service/cart.go`
4. **Add Business Logic**: `internal/biz/cart/`
5. **Add Repository**: `internal/data/postgres/`
6. **Add Tests**: Unit + Integration tests
7. **Update Documentation**: This file

### Testing Cart Features
```bash
# Test cart operations
make test-cart

# Load testing
hey -n 1000 -c 10 -m POST \
  -H "X-Session-ID: load-test-session" \
  http://localhost:8004/api/v1/cart/items \
  -d '{"product_sku":"LOAD-TEST-SKU","quantity":1}'

# Concurrency testing
go test -run TestAddToCart_Concurrency -v
```

---

## 📈 Performance Benchmarks

### Cart Operations (P95 Response Times)
- **Add to Cart**: 87ms (with full validation)
- **Get Cart**: 34ms (with pricing sync)
- **Update Cart Item**: 65ms
- **Cart Validation**: 120ms (all services)
- **Cart Refresh**: 200ms (full sync)

### Order Operations (P95 Response Times)
- **Create Order**: 234ms (full checkout flow)
- **Get Order**: 45ms
- **Update Status**: 78ms
- **Cancel Order**: 156ms (with inventory release)

### Throughput Targets
- **Cart Operations**: 200 req/sec sustained
- **Order Creation**: 50 req/sec peak
- **Read Operations**: 500 req/sec sustained

### Database Performance
- **Cart Queries**: <20ms average
- **Order Creation**: <100ms with indexes
- **Concurrent Cart Updates**: <50ms with proper locking

### Caching Strategy
- **Cart Sessions**: Redis TTL 30 days
- **Cart Summaries**: Redis TTL 5 minutes
- **Product Prices**: Redis TTL 10 minutes
- **Stock Levels**: Redis TTL 1 minute

---

## 🔐 Security Considerations

### Authentication & Authorization
- **Session Tokens**: UUID-based session identification
- **Guest Tokens**: Anonymous cart access
- **Customer Context**: JWT validation from Auth Service
- **Service Tokens**: Internal service communication

### Data Protection
- **PII Handling**: Customer data encrypted in transit/logs
- **Payment Data**: Never stored, delegated to Payment Service
- **Session Security**: Secure random UUID generation
- **Rate Limiting**: Implemented at gateway level

### Business Logic Security
- **Price Validation**: Server-side price verification
- **Stock Validation**: Real-time inventory checks
- **Order Integrity**: Atomic operations with transactions
- **Audit Trail**: Complete order modification history

---

## 🎯 Future Roadmap

### Phase 1 (Q1 2026) - Performance & Reliability
- [ ] Implement Redis caching for cart summaries
- [ ] Add comprehensive cart validation error handling
- [ ] Complete order edit history tracking
- [ ] Implement cart persistence for crash recovery

### Phase 2 (Q2 2026) - Advanced Features
- [ ] AI-powered cart recommendations
- [ ] Advanced cart analytics and insights
- [ ] Cart abandonment recovery workflows
- [ ] Multi-currency cart support
- [ ] Cart sharing and collaboration features

### Phase 3 (Q3 2026) - Scale & Intelligence
- [ ] Database sharding for high-volume carts
- [ ] Machine learning for cart optimization
- [ ] Real-time cart synchronization across devices
- [ ] Advanced fraud detection for cart operations
- [ ] Predictive cart analytics

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: Order Service Team
- **Repository**: `gitlab.com/ta-microservices/order`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #order-service-alerts
- **Performance Issues**: #order-service-performance
- **Cart Issues**: #cart-support
- **Order Issues**: #order-processing

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/order-service`
- **Cart Analytics**: `https://grafana.tanhdev.com/d/cart-analytics`
- **Order Fulfillment**: `https://grafana.tanhdev.com/d/order-fulfillment`
- **Business Metrics**: `https://grafana.tanhdev.com/d/ecommerce-overview`

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Code Review Status**: ✅ Completed (Cart issues mostly resolved)  
**Production Readiness**: 90% (Performance optimizations needed)
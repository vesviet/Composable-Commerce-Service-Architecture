# Kratos + Consul Integration Patterns

> **Comprehensive guide for integrating go-kratos/kratos framework with Consul service discovery**  
> **Target**: All microservices in Application and Infrastructure layers

---

## 🏗️ Integration Architecture

### Service Registration & Discovery Flow
```mermaid
sequenceDiagram
    participant S as Service (Kratos)
    participant C as Consul Agent
    participant CS as Consul Server
    participant API as API Gateway
    
    Note over S: Service Startup
    S->>C: Register Service
    C->>CS: Store Service Info
    CS-->>C: Registration Confirmed
    C-->>S: Registration Success
    
    Note over API: Service Discovery
    API->>C: Discover Services
    C->>CS: Query Service Catalog
    CS-->>C: Return Service List
    C-->>API: Available Services
    
    Note over S: Health Checks
    C->>S: Health Check (HTTP/gRPC)
    S-->>C: Health Status
    C->>CS: Update Health Status
```

---

## 🔧 Kratos Service Configuration

### 1. Service Registration Configuration

#### `configs/config.yaml`
```yaml
server:
  http:
    addr: 0.0.0.0:8001
    timeout: 1s
  grpc:
    addr: 0.0.0.0:9001
    timeout: 1s

consul:
  address: "consul:8500"
  scheme: "http"
  service:
    name: "catalog-service"
    version: "v1.0.0"
    metadata:
      layer: "application"
      team: "catalog-team"
      environment: "production"
    tags:
      - "catalog"
      - "cms"
      - "products"
    health_check:
      http: "http://catalog-service:8001/health"
      interval: "10s"
      timeout: "3s"
      deregister_critical_service_after: "30s"

data:
  database:
    driver: postgres
    source: postgres://user:pass@postgres:5432/catalog_db?sslmode=disable
  redis:
    addr: redis:6379
    password: ""
    db: 0
```

### 2. Kratos Service Implementation

#### `internal/server/server.go`
```go
package server

import (
    "context"
    "fmt"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/go-kratos/kratos/v2/middleware/recovery"
    "github.com/go-kratos/kratos/v2/middleware/tracing"
    "github.com/go-kratos/kratos/v2/transport/grpc"
    "github.com/go-kratos/kratos/v2/transport/http"
    "github.com/go-kratos/kratos/v2/registry"
    
    "github.com/go-kratos/kratos/contrib/registry/consul/v2"
    consulAPI "github.com/hashicorp/consul/api"
    
    "your-project/internal/conf"
    "your-project/internal/service"
)

// NewGRPCServer creates a gRPC server with Consul registration
func NewGRPCServer(c *conf.Server, consul *conf.Consul, catalogService *service.CatalogService, logger log.Logger) *grpc.Server {
    var opts = []grpc.ServerOption{
        grpc.Middleware(
            recovery.Recovery(),
            tracing.Server(),
        ),
    }
    
    if c.Grpc.Network != "" {
        opts = append(opts, grpc.Network(c.Grpc.Network))
    }
    if c.Grpc.Addr != "" {
        opts = append(opts, grpc.Address(c.Grpc.Addr))
    }
    if c.Grpc.Timeout != nil {
        opts = append(opts, grpc.Timeout(c.Grpc.Timeout.AsDuration()))
    }
    
    srv := grpc.NewServer(opts...)
    
    // Register service handlers
    v1.RegisterCatalogServer(srv, catalogService)
    
    return srv
}

// NewHTTPServer creates an HTTP server with health checks
func NewHTTPServer(c *conf.Server, consul *conf.Consul, catalogService *service.CatalogService, logger log.Logger) *http.Server {
    var opts = []http.ServerOption{
        http.Middleware(
            recovery.Recovery(),
            tracing.Server(),
        ),
    }
    
    if c.Http.Network != "" {
        opts = append(opts, http.Network(c.Http.Network))
    }
    if c.Http.Addr != "" {
        opts = append(opts, http.Address(c.Http.Addr))
    }
    if c.Http.Timeout != nil {
        opts = append(opts, http.Timeout(c.Http.Timeout.AsDuration()))
    }
    
    srv := http.NewServer(opts...)
    
    // Register HTTP handlers
    v1.RegisterCatalogHTTPServer(srv, catalogService)
    
    // Health check endpoint
    srv.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"status":"healthy","service":"catalog-service","timestamp":"` + 
            time.Now().Format(time.RFC3339) + `"}`))
    })
    
    return srv
}

// NewConsulRegistry creates Consul service registry
func NewConsulRegistry(c *conf.Consul) registry.Registrar {
    consulConfig := consulAPI.DefaultConfig()
    consulConfig.Address = c.Address
    consulConfig.Scheme = c.Scheme
    
    consulClient, err := consulAPI.NewClient(consulConfig)
    if err != nil {
        panic(err)
    }
    
    reg := consul.New(consulClient, consul.WithHealthCheck(true))
    return reg
}
```

#### `cmd/server/main.go`
```go
package main

import (
    "flag"
    "os"
    
    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/config"
    "github.com/go-kratos/kratos/v2/config/file"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/go-kratos/kratos/v2/transport/grpc"
    "github.com/go-kratos/kratos/v2/transport/http"
    
    "your-project/internal/conf"
    "your-project/internal/server"
    "your-project/internal/service"
    "your-project/internal/data"
)

var (
    Name     = "catalog-service"
    Version  = "v1.0.0"
    flagconf = flag.String("conf", "../../configs", "config path, eg: -conf config.yaml")
)

func newApp(logger log.Logger, hs *http.Server, gs *grpc.Server, rr registry.Registrar) *kratos.App {
    return kratos.New(
        kratos.ID(Name),
        kratos.Name(Name),
        kratos.Version(Version),
        kratos.Metadata(map[string]string{
            "layer": "application",
            "team": "catalog-team",
        }),
        kratos.Logger(logger),
        kratos.Server(hs, gs),
        kratos.Registrar(rr),
    )
}

func main() {
    flag.Parse()
    
    logger := log.With(log.NewStdLogger(os.Stdout),
        "ts", log.DefaultTimestamp,
        "caller", log.DefaultCaller,
        "service.id", Name,
        "service.name", Name,
        "service.version", Version,
    )
    
    // Load configuration
    c := config.New(
        config.WithSource(
            file.NewSource(*flagconf),
        ),
    )
    defer c.Close()
    
    if err := c.Load(); err != nil {
        panic(err)
    }
    
    var bc conf.Bootstrap
    if err := c.Scan(&bc); err != nil {
        panic(err)
    }
    
    // Initialize data layer
    dataData, cleanup, err := data.NewData(bc.Data, logger)
    if err != nil {
        panic(err)
    }
    defer cleanup()
    
    // Initialize service layer
    catalogService := service.NewCatalogService(dataData, logger)
    
    // Initialize servers
    httpServer := server.NewHTTPServer(bc.Server, bc.Consul, catalogService, logger)
    grpcServer := server.NewGRPCServer(bc.Server, bc.Consul, catalogService, logger)
    
    // Initialize Consul registry
    consulRegistry := server.NewConsulRegistry(bc.Consul)
    
    // Create and run application
    app := newApp(logger, httpServer, grpcServer, consulRegistry)
    
    if err := app.Run(); err != nil {
        panic(err)
    }
}
```

---

## 🔗 Service-to-Service Communication Examples

### 1. HTTP Client with Service Discovery

#### `internal/data/pricing_client.go`
```go
package data

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/go-kratos/kratos/v2/registry"
    "github.com/go-kratos/kratos/v2/transport/http"
    
    "your-project/internal/biz"
)

type PricingClient struct {
    client *http.Client
    discovery registry.Discovery
    logger *log.Helper
}

func NewPricingClient(discovery registry.Discovery, logger log.Logger) biz.PricingRepo {
    return &PricingClient{
        client: &http.Client{
            Timeout: 5 * time.Second,
        },
        discovery: discovery,
        logger: log.NewHelper(logger),
    }
}

func (p *PricingClient) GetProductPrice(ctx context.Context, productID, warehouseID string) (*biz.ProductPrice, error) {
    // Discover pricing service
    services, err := p.discovery.GetService(ctx, "pricing-service")
    if err != nil {
        return nil, fmt.Errorf("failed to discover pricing service: %w", err)
    }
    
    if len(services) == 0 {
        return nil, fmt.Errorf("no pricing service instances available")
    }
    
    // Use first available instance (could implement load balancing)
    instance := services[0]
    baseURL := fmt.Sprintf("http://%s", instance.Endpoints[0])
    
    // Make HTTP request
    url := fmt.Sprintf("%s/v1/pricing/products/%s/price?warehouseId=%s", 
        baseURL, productID, warehouseID)
    
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }
    
    // Add service-to-service headers
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Service-Name", "catalog-service")
    req.Header.Set("X-Service-Version", "v1.0.0")
    
    resp, err := p.client.Do(req)
    if err != nil {
        return nil, fmt.Errorf("failed to call pricing service: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("pricing service returned status %d", resp.StatusCode)
    }
    
    var response struct {
        Success bool `json:"success"`
        Data    struct {
            Pricing biz.ProductPrice `json:"pricing"`
        } `json:"data"`
    }
    
    if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
        return nil, err
    }
    
    if !response.Success {
        return nil, fmt.Errorf("pricing service returned error")
    }
    
    p.logger.WithContext(ctx).Infof("Retrieved price for product %s: $%.2f", 
        productID, response.Data.Pricing.FinalPrice)
    
    return &response.Data.Pricing, nil
}
```

### 2. gRPC Client with Service Discovery

#### `internal/data/inventory_client.go`
```go
package data

import (
    "context"
    "fmt"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/go-kratos/kratos/v2/registry"
    "github.com/go-kratos/kratos/v2/transport/grpc"
    "google.golang.org/grpc/metadata"
    
    inventoryv1 "your-project/api/inventory/v1"
    "your-project/internal/biz"
)

type InventoryClient struct {
    client inventoryv1.InventoryServiceClient
    conn   *grpc.ClientConn
    logger *log.Helper
}

func NewInventoryClient(discovery registry.Discovery, logger log.Logger) (biz.InventoryRepo, func(), error) {
    // Create gRPC connection with service discovery
    conn, err := grpc.DialInsecure(
        context.Background(),
        grpc.WithEndpoint("discovery:///warehouse-inventory-service"),
        grpc.WithDiscovery(discovery),
        grpc.WithTimeout(5*time.Second),
    )
    if err != nil {
        return nil, nil, err
    }
    
    client := inventoryv1.NewInventoryServiceClient(conn)
    
    return &InventoryClient{
        client: client,
        conn:   conn,
        logger: log.NewHelper(logger),
    }, func() {
        conn.Close()
    }, nil
}

func (i *InventoryClient) CheckStock(ctx context.Context, productID, warehouseID string, quantity int32) (*biz.StockInfo, error) {
    // Add service-to-service metadata
    ctx = metadata.AppendToOutgoingContext(ctx,
        "x-service-name", "catalog-service",
        "x-service-version", "v1.0.0",
        "x-request-id", generateRequestID(),
    )
    
    req := &inventoryv1.CheckStockRequest{
        ProductId:   productID,
        WarehouseId: warehouseID,
        Quantity:    quantity,
    }
    
    resp, err := i.client.CheckStock(ctx, req)
    if err != nil {
        i.logger.WithContext(ctx).Errorf("Failed to check stock: %v", err)
        return nil, fmt.Errorf("failed to check stock: %w", err)
    }
    
    stockInfo := &biz.StockInfo{
        ProductID:   resp.ProductId,
        WarehouseID: resp.WarehouseId,
        Available:   resp.Available,
        Reserved:    resp.Reserved,
        InStock:     resp.InStock,
    }
    
    i.logger.WithContext(ctx).Infof("Stock check for product %s: available=%d, in_stock=%t", 
        productID, resp.Available, resp.InStock)
    
    return stockInfo, nil
}

func generateRequestID() string {
    return fmt.Sprintf("req_%d", time.Now().UnixNano())
}
```

### 3. Circuit Breaker Pattern

#### `internal/data/resilient_client.go`
```go
package data

import (
    "context"
    "fmt"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/sony/gobreaker"
)

type ResilientClient struct {
    client    *http.Client
    breaker   *gobreaker.CircuitBreaker
    logger    *log.Helper
}

func NewResilientClient(serviceName string, logger log.Logger) *ResilientClient {
    // Circuit breaker settings
    settings := gobreaker.Settings{
        Name:        serviceName,
        MaxRequests: 3,
        Interval:    10 * time.Second,
        Timeout:     30 * time.Second,
        ReadyToTrip: func(counts gobreaker.Counts) bool {
            failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
            return counts.Requests >= 3 && failureRatio >= 0.6
        },
        OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
            log.NewHelper(logger).Infof("Circuit breaker %s changed from %s to %s", name, from, to)
        },
    }
    
    return &ResilientClient{
        client: &http.Client{
            Timeout: 5 * time.Second,
        },
        breaker: gobreaker.NewCircuitBreaker(settings),
        logger:  log.NewHelper(logger),
    }
}

func (r *ResilientClient) CallService(ctx context.Context, url string) ([]byte, error) {
    result, err := r.breaker.Execute(func() (interface{}, error) {
        req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
        if err != nil {
            return nil, err
        }
        
        resp, err := r.client.Do(req)
        if err != nil {
            return nil, err
        }
        defer resp.Body.Close()
        
        if resp.StatusCode >= 500 {
            return nil, fmt.Errorf("server error: %d", resp.StatusCode)
        }
        
        body, err := ioutil.ReadAll(resp.Body)
        if err != nil {
            return nil, err
        }
        
        return body, nil
    })
    
    if err != nil {
        r.logger.WithContext(ctx).Errorf("Service call failed: %v", err)
        return nil, err
    }
    
    return result.([]byte), nil
}
```

---

## 📨 Event Schemas for Remaining Services

### 1. Promotion Service Events

#### `examples/implementation-samples/event-schemas/promotion/promotion-created.json`
```json
{
  "eventType": "PromotionCreated",
  "version": "1.0",
  "schema": {
    "type": "object",
    "required": ["promotionId", "name", "type", "rules", "effectiveFrom", "effectiveTo"],
    "properties": {
      "promotionId": {
        "type": "string",
        "description": "Unique promotion identifier"
      },
      "name": {
        "type": "string",
        "description": "Promotion name"
      },
      "type": {
        "type": "string",
        "enum": ["percentage", "fixed_amount", "buy_x_get_y", "free_shipping"],
        "description": "Type of promotion"
      },
      "rules": {
        "type": "object",
        "properties": {
          "conditions": {
            "type": "object",
            "properties": {
              "minOrderAmount": {"type": "number"},
              "productIds": {"type": "array", "items": {"type": "string"}},
              "categoryIds": {"type": "array", "items": {"type": "string"}},
              "warehouseIds": {"type": "array", "items": {"type": "string"}},
              "customerTiers": {"type": "array", "items": {"type": "string"}}
            }
          },
          "actions": {
            "type": "object",
            "properties": {
              "discountValue": {"type": "number"},
              "maxDiscountAmount": {"type": "number"},
              "freeShipping": {"type": "boolean"}
            }
          }
        }
      },
      "effectiveFrom": {
        "type": "string",
        "format": "date-time"
      },
      "effectiveTo": {
        "type": "string",
        "format": "date-time"
      },
      "status": {
        "type": "string",
        "enum": ["active", "inactive", "expired"]
      },
      "createdBy": {
        "type": "string"
      },
      "createdAt": {
        "type": "string",
        "format": "date-time"
      }
    }
  },
  "example": {
    "eventId": "evt_promo_123",
    "eventType": "PromotionCreated",
    "version": "1.0",
    "timestamp": "2024-01-15T10:30:00Z",
    "source": "promotion-service",
    "data": {
      "promotionId": "promo_001",
      "name": "Holiday Sale 20% Off",
      "type": "percentage",
      "rules": {
        "conditions": {
          "minOrderAmount": 100.00,
          "categoryIds": ["cat_electronics"],
          "warehouseIds": ["WH001", "WH002"]
        },
        "actions": {
          "discountValue": 20,
          "maxDiscountAmount": 200.00
        }
      },
      "effectiveFrom": "2024-12-01T00:00:00Z",
      "effectiveTo": "2024-12-31T23:59:59Z",
      "status": "active",
      "createdBy": "admin_user_123",
      "createdAt": "2024-01-15T10:30:00Z"
    }
  }
}
```

#### `examples/implementation-samples/event-schemas/promotion/promotion-applied.json`
```json
{
  "eventType": "PromotionApplied",
  "version": "1.0",
  "schema": {
    "type": "object",
    "required": ["promotionId", "orderId", "customerId", "discountAmount"],
    "properties": {
      "promotionId": {"type": "string"},
      "orderId": {"type": "string"},
      "customerId": {"type": "string"},
      "discountAmount": {"type": "number"},
      "originalAmount": {"type": "number"},
      "finalAmount": {"type": "number"},
      "appliedAt": {"type": "string", "format": "date-time"}
    }
  }
}
```

### 2. Shipping Service Events

#### `examples/implementation-samples/event-schemas/shipping/shipment-created.json`
```json
{
  "eventType": "ShipmentCreated",
  "version": "1.0",
  "schema": {
    "type": "object",
    "required": ["shipmentId", "orderId", "fulfillmentEntity", "items"],
    "properties": {
      "shipmentId": {"type": "string"},
      "orderId": {"type": "string"},
      "fulfillmentEntity": {
        "type": "object",
        "properties": {
          "type": {"type": "string", "enum": ["warehouse", "store", "dropship", "3pl"]},
          "id": {"type": "string"},
          "name": {"type": "string"},
          "address": {"type": "object"}
        }
      },
      "items": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "productId": {"type": "string"},
            "sku": {"type": "string"},
            "quantity": {"type": "integer"}
          }
        }
      },
      "carrier": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "service": {"type": "string"},
          "trackingNumber": {"type": "string"}
        }
      },
      "estimatedDelivery": {"type": "string", "format": "date-time"},
      "createdAt": {"type": "string", "format": "date-time"}
    }
  }
}
```

### 3. Customer Service Events

#### `examples/implementation-samples/event-schemas/customer/customer-updated.json`
```json
{
  "eventType": "CustomerUpdated",
  "version": "1.0",
  "schema": {
    "type": "object",
    "required": ["customerId", "changes"],
    "properties": {
      "customerId": {"type": "string"},
      "changes": {
        "type": "object",
        "properties": {
          "profile": {"type": "object"},
          "tier": {"type": "string"},
          "preferences": {"type": "object"},
          "addresses": {"type": "array"}
        }
      },
      "updatedBy": {"type": "string"},
      "updatedAt": {"type": "string", "format": "date-time"}
    }
  }
}
```

### 4. Review Service Events

#### `examples/implementation-samples/event-schemas/review/review-submitted.json`
```json
{
  "eventType": "ReviewSubmitted",
  "version": "1.0",
  "schema": {
    "type": "object",
    "required": ["reviewId", "productId", "customerId", "rating"],
    "properties": {
      "reviewId": {"type": "string"},
      "productId": {"type": "string"},
      "customerId": {"type": "string"},
      "rating": {"type": "integer", "minimum": 1, "maximum": 5},
      "title": {"type": "string"},
      "content": {"type": "string"},
      "status": {"type": "string", "enum": ["pending", "approved", "rejected"]},
      "submittedAt": {"type": "string", "format": "date-time"}
    }
  }
}
```

---

## 🚨 Error Handling Patterns

### 1. Standardized Error Response Format

#### `internal/errors/errors.go`
```go
package errors

import (
    "fmt"
    "net/http"
    
    "github.com/go-kratos/kratos/v2/errors"
)

// Standard error codes
const (
    // Client errors (4xx)
    ErrorReasonBadRequest     = "BAD_REQUEST"
    ErrorReasonUnauthorized   = "UNAUTHORIZED"
    ErrorReasonForbidden      = "FORBIDDEN"
    ErrorReasonNotFound       = "NOT_FOUND"
    ErrorReasonConflict       = "CONFLICT"
    ErrorReasonValidation     = "VALIDATION_ERROR"
    ErrorReasonRateLimit      = "RATE_LIMITED"
    
    // Server errors (5xx)
    ErrorReasonInternal       = "INTERNAL_ERROR"
    ErrorReasonServiceUnavailable = "SERVICE_UNAVAILABLE"
    ErrorReasonTimeout        = "TIMEOUT"
    ErrorReasonDependencyFailed = "DEPENDENCY_FAILED"
)

// Error response structure
type ErrorResponse struct {
    Success bool                   `json:"success"`
    Error   *ErrorDetail          `json:"error"`
    Meta    map[string]interface{} `json:"meta,omitempty"`
}

type ErrorDetail struct {
    Code    string                 `json:"code"`
    Message string                 `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
}

// Standard error constructors
func BadRequest(reason, message string) *errors.Error {
    return errors.BadRequest(reason, message)
}

func NotFound(reason, message string) *errors.Error {
    return errors.NotFound(reason, message)
}

func Internal(reason, message string) *errors.Error {
    return errors.InternalServer(reason, message)
}

func ServiceUnavailable(reason, message string) *errors.Error {
    return errors.ServiceUnavailable(reason, message)
}

// Validation error with field details
func ValidationError(message string, fieldErrors map[string]string) *errors.Error {
    err := errors.BadRequest(ErrorReasonValidation, message)
    err = err.WithMetadata(map[string]interface{}{
        "field_errors": fieldErrors,
    })
    return err
}

// Dependency service error
func DependencyError(service, operation string, cause error) *errors.Error {
    return errors.ServiceUnavailable(
        ErrorReasonDependencyFailed,
        fmt.Sprintf("Failed to call %s service for %s: %v", service, operation, cause),
    ).WithMetadata(map[string]interface{}{
        "dependency_service": service,
        "operation": operation,
        "cause": cause.Error(),
    })
}
```

### 2. Error Handling Middleware

#### `internal/middleware/error_handler.go`
```go
package middleware

import (
    "context"
    "encoding/json"
    "net/http"
    "time"
    
    "github.com/go-kratos/kratos/v2/errors"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/go-kratos/kratos/v2/middleware"
    "github.com/go-kratos/kratos/v2/transport"
    
    apperrors "your-project/internal/errors"
)

func ErrorHandler(logger log.Logger) middleware.Middleware {
    return func(handler middleware.Handler) middleware.Handler {
        return func(ctx context.Context, req interface{}) (interface{}, error) {
            reply, err := handler(ctx, req)
            if err != nil {
                // Log error with context
                logError(ctx, err, logger)
                
                // Convert to standard error format
                if tr, ok := transport.FromServerContext(ctx); ok {
                    if tr.Kind() == transport.KindHTTP {
                        return reply, handleHTTPError(err)
                    }
                }
                
                // Return gRPC error as-is
                return reply, err
            }
            return reply, nil
        }
    }
}

func logError(ctx context.Context, err error, logger log.Logger) {
    helper := log.NewHelper(logger)
    
    if se := errors.FromError(err); se != nil {
        helper.WithContext(ctx).Errorw(
            "msg", "Request failed",
            "error", se.Message,
            "code", se.Reason,
            "status", se.Code,
            "metadata", se.Metadata,
        )
    } else {
        helper.WithContext(ctx).Errorw(
            "msg", "Request failed",
            "error", err.Error(),
        )
    }
}

func handleHTTPError(err error) error {
    se := errors.FromError(err)
    if se == nil {
        // Unknown error, return as internal server error
        return errors.InternalServer("INTERNAL_ERROR", "An unexpected error occurred")
    }
    
    // Map Kratos error codes to HTTP status codes
    var httpStatus int
    switch se.Code {
    case 400:
        httpStatus = http.StatusBadRequest
    case 401:
        httpStatus = http.StatusUnauthorized
    case 403:
        httpStatus = http.StatusForbidden
    case 404:
        httpStatus = http.StatusNotFound
    case 409:
        httpStatus = http.StatusConflict
    case 429:
        httpStatus = http.StatusTooManyRequests
    case 500:
        httpStatus = http.StatusInternalServerError
    case 503:
        httpStatus = http.StatusServiceUnavailable
    default:
        httpStatus = http.StatusInternalServerError
    }
    
    return errors.New(httpStatus, se.Reason, se.Message).WithMetadata(se.Metadata)
}
```

### 3. Service-Specific Error Handling

#### `internal/service/catalog_service.go`
```go
package service

import (
    "context"
    "fmt"
    
    "github.com/go-kratos/kratos/v2/log"
    
    pb "your-project/api/catalog/v1"
    "your-project/internal/biz"
    apperrors "your-project/internal/errors"
)

type CatalogService struct {
    pb.UnimplementedCatalogServer
    
    catalog biz.CatalogUsecase
    logger  *log.Helper
}

func NewCatalogService(catalog biz.CatalogUsecase, logger log.Logger) *CatalogService {
    return &CatalogService{
        catalog: catalog,
        logger:  log.NewHelper(logger),
    }
}

func (s *CatalogService) GetProduct(ctx context.Context, req *pb.GetProductRequest) (*pb.GetProductReply, error) {
    // Validate request
    if req.ProductId == "" {
        return nil, apperrors.ValidationError("Product ID is required", map[string]string{
            "product_id": "This field is required",
        })
    }
    
    // Get product from business layer
    product, err := s.catalog.GetProduct(ctx, req.ProductId)
    if err != nil {
        // Handle different types of business errors
        switch {
        case biz.IsNotFound(err):
            return nil, apperrors.NotFound("PRODUCT_NOT_FOUND", 
                fmt.Sprintf("Product with ID %s not found", req.ProductId))
        case biz.IsValidationError(err):
            return nil, apperrors.ValidationError(err.Error(), nil)
        case biz.IsDependencyError(err):
            return nil, apperrors.DependencyError("pricing-service", "get_price", err)
        default:
            s.logger.WithContext(ctx).Errorf("Failed to get product %s: %v", req.ProductId, err)
            return nil, apperrors.Internal("INTERNAL_ERROR", "Failed to retrieve product")
        }
    }
    
    // Convert to protobuf response
    return &pb.GetProductReply{
        Product: convertToProductPB(product),
    }, nil
}

func (s *CatalogService) CreateProduct(ctx context.Context, req *pb.CreateProductRequest) (*pb.CreateProductReply, error) {
    // Validate request
    if err := validateCreateProductRequest(req); err != nil {
        return nil, err
    }
    
    // Convert from protobuf
    product := convertFromProductPB(req.Product)
    
    // Create product
    createdProduct, err := s.catalog.CreateProduct(ctx, product)
    if err != nil {
        switch {
        case biz.IsConflictError(err):
            return nil, apperrors.Conflict("PRODUCT_EXISTS", 
                fmt.Sprintf("Product with SKU %s already exists", req.Product.Sku))
        case biz.IsValidationError(err):
            return nil, apperrors.ValidationError(err.Error(), nil)
        default:
            s.logger.WithContext(ctx).Errorf("Failed to create product: %v", err)
            return nil, apperrors.Internal("INTERNAL_ERROR", "Failed to create product")
        }
    }
    
    return &pb.CreateProductReply{
        Product: convertToProductPB(createdProduct),
    }, nil
}

func validateCreateProductRequest(req *pb.CreateProductRequest) error {
    fieldErrors := make(map[string]string)
    
    if req.Product == nil {
        return apperrors.BadRequest("BAD_REQUEST", "Product data is required")
    }
    
    if req.Product.Sku == "" {
        fieldErrors["sku"] = "SKU is required"
    }
    
    if req.Product.Name == "" {
        fieldErrors["name"] = "Product name is required"
    }
    
    if req.Product.CategoryId == "" {
        fieldErrors["category_id"] = "Category ID is required"
    }
    
    if len(fieldErrors) > 0 {
        return apperrors.ValidationError("Validation failed", fieldErrors)
    }
    
    return nil
}
```

### 4. Retry and Timeout Patterns

#### `internal/data/resilient_repository.go`
```go
package data

import (
    "context"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/cenkalti/backoff/v4"
    
    "your-project/internal/biz"
    apperrors "your-project/internal/errors"
)

type ResilientRepository struct {
    repo   biz.ProductRepo
    logger *log.Helper
}

func NewResilientRepository(repo biz.ProductRepo, logger log.Logger) biz.ProductRepo {
    return &ResilientRepository{
        repo:   repo,
        logger: log.NewHelper(logger),
    }
}

func (r *ResilientRepository) GetProduct(ctx context.Context, id string) (*biz.Product, error) {
    var product *biz.Product
    var err error
    
    // Exponential backoff configuration
    backoffConfig := backoff.NewExponentialBackOff()
    backoffConfig.InitialInterval = 100 * time.Millisecond
    backoffConfig.MaxInterval = 2 * time.Second
    backoffConfig.MaxElapsedTime = 10 * time.Second
    
    operation := func() error {
        product, err = r.repo.GetProduct(ctx, id)
        if err != nil {
            // Don't retry on certain errors
            if biz.IsNotFound(err) || biz.IsValidationError(err) {
                return backoff.Permanent(err)
            }
            
            r.logger.WithContext(ctx).Warnf("Retrying get product %s due to error: %v", id, err)
            return err
        }
        return nil
    }
    
    if err := backoff.Retry(operation, backoff.WithContext(backoffConfig, ctx)); err != nil {
        r.logger.WithContext(ctx).Errorf("Failed to get product %s after retries: %v", id, err)
        return nil, err
    }
    
    return product, nil
}

func (r *ResilientRepository) CreateProduct(ctx context.Context, product *biz.Product) (*biz.Product, error) {
    // Add timeout for create operations
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    
    createdProduct, err := r.repo.CreateProduct(ctx, product)
    if err != nil {
        if ctx.Err() == context.DeadlineExceeded {
            return nil, apperrors.ServiceUnavailable("TIMEOUT", "Product creation timed out")
        }
        return nil, err
    }
    
    return createdProduct, nil
}
```

---

## 📋 Integration Checklist

### For Each Service Implementation:

#### ✅ Kratos + Consul Integration
- [ ] Add Consul configuration to `configs/config.yaml`
- [ ] Implement service registration in `cmd/server/main.go`
- [ ] Add health check endpoint
- [ ] Configure service metadata and tags
- [ ] Implement graceful shutdown

#### ✅ Service-to-Service Communication
- [ ] Implement HTTP client with service discovery
- [ ] Implement gRPC client with service discovery
- [ ] Add circuit breaker pattern
- [ ] Add retry logic with exponential backoff
- [ ] Add request/response logging

#### ✅ Event Schema Definition
- [ ] Define all published events with JSON Schema
- [ ] Define all subscribed events
- [ ] Add event versioning strategy
- [ ] Implement event validation
- [ ] Add event examples and documentation

#### ✅ Error Handling
- [ ] Implement standardized error responses
- [ ] Add error handling middleware
- [ ] Add service-specific error handling
- [ ] Implement retry and timeout patterns
- [ ] Add error logging and monitoring

---

This comprehensive integration guide provides the foundation for implementing Kratos + Consul integration, service-to-service communication, event schemas, and error handling patterns across all remaining services. Each service can follow these patterns while customizing for their specific business logic.
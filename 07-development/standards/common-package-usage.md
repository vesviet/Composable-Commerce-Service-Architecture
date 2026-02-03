# Common Package Usage Guide

**Version**: v1.7.1  
**Last Updated**: 2026-01-27  
**Domain**: Platform  
**Service**: Common Package (Shared Library)

## 🎯 Overview

The Common Package provides standardized utilities, middleware, and frameworks for microservices architecture. This guide demonstrates best practices for using all modules with real-world examples from production services.

**Key Benefits:**
- ✅ **Consistency**: Standardized patterns across all services
- ✅ **DRY Principle**: Eliminate duplicate code
- ✅ **Type Safety**: Protobuf-based configuration and strong typing
- ✅ **Production Ready**: Circuit breakers, retries, observability built-in
- ✅ **Migration Support**: Backward-compatible aliases for smooth transitions

## 📚 Module Index

| Module | Description | Key Features |
|--------|-------------|--------------|
| **[client](#client-package)** | HTTP/gRPC clients with circuit breaker | Circuit breaker, retries, connection pooling |
| **[config](#config-package)** | Configuration management | Environment-based, protobuf definitions |
| **[errors](#errors-package)** | Structured error handling | Auto-classification, HTTP mapping, retry logic |
| **[events](#events-package)** | Event publishing (Dapr gRPC) | Pub/sub abstraction, CloudEvents support |
| **[middleware](#middleware-package)** | HTTP middleware suite | Auth, rate limiting, CORS, logging |
| **[models](#models-package)** | Base models and standard types | GORM base models, API responses |
| **[observability](#observability-package)** | Health checks, metrics, tracing | Prometheus metrics, health endpoints |
| **[security](#security-package)** | Password hashing and security | bcrypt, strength validation, PII masking |
| **[utils](#utils-package)** | Utility functions | Cache, slice helpers, metadata converters |
| **[validation](#validation-package)** | Input validation | Fluent API, custom validators |
| **[worker](#worker-package)** | Background worker framework | Cron jobs, continuous workers, metrics |

---

## 🔄 Service Bootstrap Flow

```mermaid
flowchart TD
    A[Service Start] --> B[Load Config]
    B --> C[Init Logger]
    C --> D[Init Observability]
    D --> E[Init DB/Redis]
    E --> F[Init Repositories]
    F --> G[Init Event Publisher]
    G --> H[Init Middleware]
    H --> I[Init Workers]
    I --> J[Start HTTP/gRPC Servers]
    
    B --> B1[common/config]
    D --> D1[common/observability]
    F --> F1[common/repository]
    G --> G1[common/events]
    H --> H1[common/middleware]
    I --> I1[common/worker]
```

---

## Client Package

**Import**: `gitlab.com/ta-microservices/common/client`

### gRPC Client (Recommended for Internal Services)

```go
import "gitlab.com/ta-microservices/common/client"

// Create gRPC client factory
factory := client.NewGRPCClientFactory(logger)

// Create clients for internal services
authClient, err := factory.CreateAuthClient()
userClient, err := factory.CreateUserClient()
catalogClient, err := factory.CreateCatalogClient()

// Use with protobuf clients
conn := authClient.GetConnection()
authService := authpb.NewAuthServiceClient(conn)
response, err := authService.ValidateToken(ctx, request)
```

### HTTP Client (For External APIs)

```go
// Create HTTP client with circuit breaker
config := client.DefaultHTTPClientConfig("https://api.external-service.com")
config.MaxRetries = 3
config.Timeout = 30 * time.Second

httpClient := client.NewHTTPClient(config, logger)

// Make JSON requests
var user User
err := httpClient.GetJSON(ctx, "/api/v1/users/123", &user)

var response Response
err := httpClient.PostJSON(ctx, "/api/v1/users", createRequest, &response)
```

### Health Checks Integration

```go
import "gitlab.com/ta-microservices/common/observability/health"

// Individual gRPC service health check
authChecker := health.NewGRPCHealthChecker("auth-service", authClient, 5*time.Second)
healthManager.Register(authChecker)

// Pool health check (checks all gRPC services)
poolChecker := health.NewGRPCPoolHealthChecker("grpc-services", grpcFactory, 10*time.Second)
healthManager.Register(poolChecker)
```

---

## Config Package

**Import**: `gitlab.com/ta-microservices/common/config`

### Using Common Protobuf Config

Instead of duplicating common configurations, use shared definitions:

```protobuf
syntax = "proto3";
package your.service;

import "common/config/common.proto";

message Bootstrap {
  // Use common base configuration
  common.config.BaseBootstrap base = 1;
  
  // Add service-specific configuration
  YourServiceConfig your_service = 2;
}

message YourServiceConfig {
  message SpecificFeature {
    bool enabled = 1;
    int32 max_items = 2;
  }
  SpecificFeature feature = 1;
}
```

### Go Config Helpers

```go
// Load common configurations
baseConfig := config.LoadBaseConfig("your-service", "8080", "9090")
dbConfig := config.LoadDatabaseConfig("your-service")
redisConfig := config.LoadRedisConfig()
jwtConfig := config.LoadJWTConfig()

// Access nested configuration
serverConfig := c.Base.Server
dbConfig := c.Base.Data.Database
```

### Environment Variables

```bash
# Server
HTTP_PORT=8080
GRPC_PORT=9090
ENVIRONMENT=production

# Database
DATABASE_URL=postgres://user:pass@localhost/db
DB_MAX_OPEN_CONNS=25
DB_MAX_IDLE_CONNS=5

# Redis
REDIS_URL=redis://localhost:6379/0
REDIS_POOL_SIZE=10

# Security
JWT_SECRET=your-secret-key
JWT_EXPIRATION=24h
```

---

## Errors Package

**Import**: `gitlab.com/ta-microservices/common/errors`

### Structured Error Creation

```go
import commonErrors "gitlab.com/ta-microservices/common/errors"

// Create specific error types
authErr := commonErrors.NewAuthenticationError("Invalid JWT token")
validationErr := commonErrors.NewValidationError("Email format is invalid")
serviceErr := commonErrors.NewServiceUnavailableError("user-service", originalErr)

// Add rich context
err := commonErrors.NewServiceUnavailableError("payment-service", originalErr).
    WithContext("req-123", "/api/payments", "POST", "user-456", "gateway").
    WithDuration(5 * time.Second).
    WithRetryInfo(3, &[]time.Duration{60 * time.Second}[0])
```

### Automatic Error Classification

```go
classifier := commonErrors.NewErrorClassifier()

// Automatically classify any error
originalErr := fmt.Errorf("connection refused")
classified := classifier.ClassifyError(originalErr, "user-service")
// Result: ServiceError with Type=ErrorTypeServiceDown, Code="SERVICE_UNAVAILABLE"
```

### HTTP Response Integration

```go
// Create response builder
builder := commonErrors.NewResponseBuilder("user-service", "v1.0.0", true)

// Write error response to HTTP writer
err := commonErrors.NewValidationError("Invalid email format")
builder.WriteErrorResponse(w, err)

// Check error types
if commonErrors.IsRetryableError(err) {
    // Implement retry logic
}
```

### Service Integration Example

```go
func (s *UserService) CreateUser(ctx context.Context, req *CreateUserRequest) (*User, error) {
    // Validate input
    if req.Email == "" {
        return nil, commonErrors.NewValidationError("Email is required")
    }
    
    // Check if user exists
    existing, err := s.repo.FindByEmail(ctx, req.Email)
    if err == nil && existing != nil {
        return nil, commonErrors.NewConflictError("User with this email already exists")
    }
    
    // Create user
    user, err := s.repo.Create(ctx, req)
    if err != nil {
        return nil, commonErrors.NewDatabaseError("create", err)
    }
    
    return user, nil
}
```

---

## Events Package

**Import**: `gitlab.com/ta-microservices/common/events`

### Publishing Events (Dapr)

```go
// Configure publisher
config := &events.DaprEventPublisherConfig{
    PubsubName:   "pubsub-redis",
    DaprEndpoint: "localhost:50001",
}

// Create publisher
publisher, err := events.NewDaprEventPublisher(config, logger)

// Define and publish event
event := events.OrderEvent{
    BaseEvent: events.BaseEvent{
        ID:        "evt-1",
        Source:    "order-service",
        Timestamp: time.Now(),
    },
    OrderID: "ord-123",
}

err := publisher.PublishEvent(ctx, events.TopicOrderCreated, event)
```

### Event Topics

```go
// Standard topics available as constants
events.TopicUserRegistered
events.TopicOrderCreated
events.TopicPaymentProcessed
```

### Testing with NoOp Publisher

```go
// Use NoOp publisher for unit tests
mockPublisher := events.NewNoOpEventPublisher(logger)
```

---

## Middleware Package

**Import**: `gitlab.com/ta-microservices/common/middleware`

### Recommended Middleware Stack

```go
// Recommended order
router.Use(middleware.RequestID())      // 1. Tag request
router.Use(middleware.Logging())        // 2. Start logging
router.Use(middleware.Recovery())       // 3. Safety net
router.Use(middleware.CORS())           // 4. Browser security
router.Use(middleware.Auth(authConfig)) // 5. Auth check
```

### Authentication

```go
// Basic JWT authentication
authConfig := &middleware.AuthConfig{
    JWTSecret: "your-secret-key",
    SkipPaths: []string{"/health", "/docs", "/v1/auth/login"},
}
router.Use(middleware.Auth(authConfig))

// Optional authentication (doesn't fail if no token)
router.Use(middleware.OptionalAuth(authConfig))

// Role-based access control
router.Use(middleware.RequireRole("admin", "manager"))

// Context helpers
userID := middleware.GetUserID(c)
userRole := middleware.GetUserRole(c)
userEmail := middleware.GetUserEmail(c)
```

### Rate Limiting (Redis-based)

```go
rateLimitConfig := &middleware.RateLimitConfig{
    Enabled:       true,
    Redis:         redisClient,
    DefaultLimit:  100,         // Requests per window
    DefaultWindow: time.Minute, // Window duration
    SkipPaths:     []string{"/health", "/metrics"},
    Logger:        logger,
}

router.Use(middleware.RateLimit(rateLimitConfig))
```

### CORS Configuration

```go
// Default (permissive)
router.Use(middleware.CORS())

// Custom configuration
corsConfig := &middleware.CORSConfig{
    AllowOrigins:     []string{"https://example.com"},
    AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
    AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
    ExposeHeaders:    []string{"Content-Length"},
    AllowCredentials: true,
    MaxAge:           12 * time.Hour,
}
router.Use(middleware.CORSWithConfig(corsConfig))
```

---

## Models Package

**Import**: `gitlab.com/ta-microservices/common/models`

### Base Models

```go
// Embed BaseModel for standard fields
type User struct {
    models.BaseModel  // ID, CreatedAt, UpdatedAt, DeletedAt, CreatedBy, UpdatedBy
    Name  string
    Email string
}
```

### API Responses

```go
// Success responses
return ctx.JSON(200, models.NewAPIResponse(data))

// Error responses
return ctx.JSON(400, models.NewAPIError("BAD_REQ", "Invalid input", "details"))

// List responses with pagination
return ctx.JSON(200, models.NewListResponse(items, pagination))
```

### Standard Types

```go
// JSONB fields in Postgres
type Product struct {
    models.BaseModel
    Metadata models.JSON `gorm:"type:jsonb"`
}

// Text array fields
type Category struct {
    models.BaseModel
    Tags models.StringArray `gorm:"type:text[]"`
}
```

---

## Observability Package

**Import**: `gitlab.com/ta-microservices/common/observability`

### Health Checks

```go
import "gitlab.com/ta-microservices/common/observability/health"

// Initialize health manager
healthMgr := health.NewManager(logger)

// Add database check
healthMgr.AddCheck("database", func(ctx context.Context) error {
    return db.Ping()
})

// Add Redis check
healthMgr.AddCheck("redis", func(ctx context.Context) error {
    return redis.Ping(ctx).Err()
})

// Expose HTTP endpoints
router.GET("/health/live", healthMgr.LivenessHandler())
router.GET("/health/ready", healthMgr.ReadinessHandler())
```

### Metrics (Prometheus)

```go
import "gitlab.com/ta-microservices/common/observability/metrics"

// Create metrics factory
factory := metrics.NewNoOpFactory() // or real factory in production

collector, _ := factory.CreateCollector(metrics.MetricsConfig{
    Enabled:     true,
    ServiceName: "service-name",
})

// Increment counters
collector.IncrementCounter(metrics.MetricRequestsTotal, map[string]string{
    metrics.LabelService: "service-name",
}, 1)
```

---

## Security Package

**Import**: `gitlab.com/ta-microservices/common/security`

### Password Management

```go
// Create password manager
pwdManager := security.NewPasswordManager(12) // bcrypt cost

// Hash password
hash, err := pwdManager.HashPassword("mySecretPass123")

// Validate password
valid := pwdManager.CheckPasswordHash("mySecretPass123", hash)

// Validate password strength
err := security.ValidatePasswordStrength("weak") 
// Returns: "password must be at least 8 characters long"

err := security.ValidatePasswordStrength("StrongPass1!") // nil
```

### PII Masking

```go
import "gitlab.com/ta-microservices/common/security/pii"

// Mask sensitive data
maskedEmail := pii.MaskEmail("user@example.com")     // "u***@example.com"
maskedPhone := pii.MaskPhone("+1234567890")          // "+123***7890"
maskedCard := pii.MaskCreditCard("1234567890123456") // "1234****3456"
```

---

## Utils Package

**Import**: `gitlab.com/ta-microservices/common/utils`

### Cache (Generic Redis Wrapper)

```go
import "gitlab.com/ta-microservices/common/utils/cache"

// Create typed cache
userCache := cache.NewTypedCache[User](redisClient, time.Hour)

// Set value
err := userCache.Set(ctx, "user:123", &user)

// Get value
user, err := userCache.Get(ctx, "user:123")

// Delete
err := userCache.Delete(ctx, "user:123")
```

### Slice Helpers

```go
import "gitlab.com/ta-microservices/common/utils/slice"

// Check existence
exists := slice.Contains([]int{1, 2, 3}, 2) // true

// Filter
evens := slice.Filter([]int{1, 2, 3, 4}, func(i int) bool {
    return i%2 == 0
}) // [2, 4]

// Map/Convert
strs := slice.Convert([]int{1, 2}, func(i int) string {
    return fmt.Sprintf("%d", i)
}) // ["1", "2"]

// Deduplicate
unique := slice.Unique([]string{"a", "b", "a"}) // ["a", "b"]
```

### Metadata Converters

```go
import "gitlab.com/ta-microservices/common/utils/metadata"

// Create metadata from map
metadata := metadata.MustNewJSONMetadata(map[string]interface{}{
    "source": "web",
    "campaign": "summer_sale",
})

// Convert between types
dataMap := metadata.MetadataToMap(metadata)
stringMap := metadata.JSONBToStringMap(jsonbData)
interfaceMap := metadata.MapToJSON(stringMap)
```

### Status Transition Validation

```go
import "gitlab.com/ta-microservices/common/utils/status"

// Define transition map
var OrderStatusTransitions = map[string][]string{
    OrderStatusPending:    {OrderStatusConfirmed, OrderStatusCancelled},
    OrderStatusConfirmed:  {OrderStatusProcessing, OrderStatusCancelled},
    OrderStatusProcessing: {OrderStatusShipped, OrderStatusCancelled},
    // ...
}

// Validate transitions
func (uc *UseCase) isValidStatusTransition(from, to string) bool {
    return status.ValidateStatusTransition(from, to, OrderStatusTransitions)
}
```

---

## Validation Package

**Import**: `gitlab.com/ta-microservices/common/validation`

### Fluent API Validation

```go
import commonValidation "gitlab.com/ta-microservices/common/validation"

// Basic validation
func validateCreateShipmentRequest(req *v1.CreateShipmentRequest) error {
    return commonValidation.NewValidator().
        Required("carrier", req.Carrier).
        Range("order_id", int(req.OrderId), 1, 0).  // Must be > 0
        Range("weight", int(req.Weight), 1, 0).     // Must be > 0
        Validate()
}
```

### Advanced Conditional Validation

```go
// Example from Customer Service
func (uc *CustomerUsecase) CreateCustomer(ctx context.Context, req *CreateCustomerRequest) (*model.Customer, error) {
    if err := validation.NewValidator().
        Required("email", req.Email).
        Email("email", req.Email).
        Conditional(req.Phone != "", func(v *validation.Validator) *validation.Validator {
            return v.Phone("phone", req.Phone)
        }).
        Conditional(req.DateOfBirth != nil, func(v *validation.Validator) *validation.Validator {
            now := time.Now()
            return v.DateRange("date_of_birth", *req.DateOfBirth, nil, &now)
        }).
        Validate(); err != nil {
        return nil, err
    }
    
    // Business logic...
}
```

### Available Validators

| Method | Description | Example |
|--------|-------------|---------|
| `Required(field, value)` | Check non-empty | `Required("name", req.Name)` |
| `Email(field, email)` | Validate email format | `Email("email", req.Email)` |
| `Phone(field, phone)` | Validate phone number | `Phone("phone", req.Phone)` |
| `UUID(field, uuid)` | Validate UUID format | `UUID("id", req.ID)` |
| `Range(field, val, min, max)` | Check numeric range | `Range("age", age, 18, 120)` |
| `StringLength(field, str, min, max)` | Check string length | `StringLength("password", pwd, 8, 64)` |
| `DateRange(field, date, min, max)` | Validate date range | `DateRange("dob", dob, nil, &now)` |
| `Conditional(cond, fn)` | Conditional validation | See example above |

### Standalone Validators

```go
// Individual validation functions
if err := validation.ValidateEmail(email); err != nil {
    return err
}

if err := validation.ValidatePhoneNumber(phone); err != nil {
    return err
}

if err := validation.ValidatePagination(page, pageSize); err != nil {
    return err
}
```

---

## Worker Package

**Import**: `gitlab.com/ta-microservices/common/worker`

### Creating Workers

```go
// Implement Worker interface or embed BaseWorker
type MyWorker struct {
    *worker.BaseWorker
}

func NewMyWorker() *MyWorker {
    return &MyWorker{
        BaseWorker: worker.NewBaseWorker("my-worker", 24*time.Hour), // Interval
    }
}

func (w *MyWorker) Run(ctx context.Context) error {
    // Do work here
    log.Info("Running scheduled task")
    return nil
}
```

### Worker Registry

```go
// Initialize registry
registry := worker.NewRegistry(logger)

// Register workers
registry.Register(NewMyWorker())
registry.Register(NewCleanupWorker())

// Start all workers
registry.Start()

// Stop all workers on shutdown
defer registry.Stop()
```

### Automatic Metrics

Workers automatically export Prometheus metrics:
- `worker_job_processed_total`
- `worker_job_errors_total`
- `worker_job_duration_seconds`

---

## 🚀 Migration Guide

### Step 1: Identify Duplicates

Search for common patterns in your codebase:

```bash
# Find duplicate metadata converters
rg "func.*MetadataToMap" --type go

# Find duplicate validation logic
rg "if.*=.*\"\".*return.*error" --type go

# Find status assignments without validation
rg "\.Status\s*=" --type go
```

### Step 2: Create Aliases for Backward Compatibility

```go
// Before: Custom function
func convertMetadataToMap(metadata *JSONMetadata) map[string]interface{} {
    if metadata == nil {
        return nil
    }
    m, _ := metadata.ToMap()
    return m
}

// After: Alias to common package
var convertMetadataToMap = commonMetadata.MetadataToMap
```

### Step 3: Update Imports

```go
import (
    commonMetadata "gitlab.com/ta-microservices/common/utils/metadata"
    commonValidation "gitlab.com/ta-microservices/common/validation"
    commonErrors "gitlab.com/ta-microservices/common/errors"
    statusUtil "gitlab.com/ta-microservices/common/utils/status"
)
```

### Step 4: Verify Migration

```bash
# Run tests
go test ./internal/biz/... -v -count=1

# Run wire generation
wire gen ./...

# Build
go build ./...

# Run vendor sync
go mod vendor
```

---

## 📊 Production Examples

### Customer Service ✅
- ✅ Uses `commonValidation.NewValidator()` extensively
- ✅ Conditional validation for optional fields
- 📁 Reference: `customer/internal/biz/customer/customer.go:117-129`

### Shipping Service ✅
- ✅ Uses `commonMetadata.MapToJSON()` and `JSONBToStringMap()`
- ✅ Uses `commonValidation` for request validation
- 📁 Reference: `shipping/internal/service/helper.go:67-73, 273-308`

### Order Service ✅
- ✅ Uses `statusUtil.ValidateStatusTransition()` 
- ✅ Comprehensive status transition map
- 📁 Reference: `order/internal/biz/status/status.go:198-203`

### Gateway Service ✅
- ✅ Uses `commonErrors` for structured error handling
- ✅ Circuit breaker integration with `common/client`
- 📁 Reference: Gateway error handling middleware

---

## 🎯 Best Practices

### 1. Use Specific Error Types

```go
// ✅ Good: Specific error type
return commonErrors.NewValidationError("Email format is invalid")

// ❌ Avoid: Generic error
return fmt.Errorf("validation error")
```

### 2. Add Rich Context

```go
// ✅ Good: Rich context
err := commonErrors.NewServiceUnavailableError("payment-service", originalErr).
    WithContext(requestID, path, method, userID, "gateway").
    WithDuration(duration)

// ❌ Avoid: Minimal context
err := commonErrors.NewServiceUnavailableError("payment-service", originalErr)
```

### 3. Use Conditional Validation

```go
// ✅ Good: Only validate phone if provided
validator.Conditional(req.Phone != "", func(v *validation.Validator) *validation.Validator {
    return v.Phone("phone", req.Phone)
})

// ❌ Bad: Always validate phone even if empty
validator.Phone("phone", req.Phone)  // Will fail for empty string
```

### 4. Validate Status Transitions

```go
// ✅ Good: Use status transition validation
if !uc.isValidStatusTransition(order.Status, req.Status) {
    return nil, commonErrors.NewBusinessLogicError("INVALID_TRANSITION", 
        "Cannot transition from %s to %s", order.Status, req.Status)
}

// ❌ Bad: Direct status assignment
order.Status = req.Status // No validation
```

### 5. Use Circuit Breakers for External Calls

```go
// ✅ Good: Use common client with circuit breaker
httpClient := client.NewHTTPClient(config, logger)
response, err := httpClient.GetJSON(ctx, "/api/users", &users)

// ❌ Bad: Direct HTTP calls without protection
resp, err := http.Get("http://external-service/api/users")
```

---

## 🔧 Troubleshooting

### Common Issues

1. **Import Path Errors**
   ```bash
   # Ensure correct import paths
   go mod tidy
   go mod vendor
   ```

2. **Circuit Breaker Open**
   ```go
   // Check circuit breaker state
   if commonErrors.IsCircuitBreakerError(err) {
       // Handle circuit breaker open
       log.Warn("Circuit breaker is open, failing fast")
   }
   ```

3. **Validation Failures**
   ```go
   // Parse validation errors for debugging
   if err != nil {
       validationErrors := validation.ParseErrors(err)
       log.Errorf("Validation failed: %+v", validationErrors)
   }
   ```

### Debug Configuration

```go
// Enable debug logging for common packages
config.EnableTracing = true
config.EnableMetrics = true

// Check health status
err := healthManager.Check(ctx)
if err != nil {
    log.Errorf("Health check failed: %v", err)
}
```

---

## 📚 Additional Resources

- **Comprehensive Usage Guide**: [common/docs/USAGE_GUIDE.md](../../common/docs/USAGE_GUIDE.md)
- **Module Documentation**: Each module has detailed README.md files
- **Examples**: See `common/examples/` directory
- **Migration Patterns**: Documented in individual module READMEs

---

**Last Updated**: 2026-01-27  
**Common Package Version**: v1.7.1
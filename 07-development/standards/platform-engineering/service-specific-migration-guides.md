# Service-Specific Migration Guides

## 📋 Service-by-Service Migration Instructions

**Purpose:** Detailed migration instructions for each service with service-specific considerations and gotchas.

---

## 🥇 PRIORITY 1: AUTH SERVICE (Start Here)

### Service Overview
- **Path:** `auth/`
- **Complexity:** Low (good starting point)
- **Dependencies:** Database, Redis
- **Special Notes:** Simple service, minimal external dependencies

### Pre-Migration Analysis
```bash
# Check current implementations
find auth/internal -name "health.go" -type f
find auth/internal -name "*client*.go" -type f
grep -r "http.Client" auth/internal/
grep -r "circuitbreaker" auth/internal/
```

### Service-Specific Steps

#### Phase 1: Health Checks
- [ ] **Current file:** `auth/internal/service/health.go`
- [ ] **HTTP server:** `auth/internal/server/http.go`
- [ ] **Dependencies:** Database, Redis
- [ ] **Special handling:** None

```go
// In auth/internal/server/http.go
healthSetup := health.NewHealthSetup("auth-service", "v1.0.0", "production", logger)
healthSetup.AddDatabaseCheck("database", db).AddRedisCheck("redis", rdb)
healthHandler := healthSetup.GetHandler()

// Register endpoints
srv.HandleFunc("/health", healthHandler.HealthHandler)
srv.HandleFunc("/health/ready", healthHandler.ReadinessHandler)
srv.HandleFunc("/health/live", healthHandler.LivenessHandler)
```

#### Phase 2: Database
- [ ] **Current file:** `auth/internal/data/data.go`
- [ ] **Special handling:** JWT token storage in Redis

#### Phase 3: Configuration
- [ ] **Current file:** `auth/internal/config/config.go`
- [ ] **Service-specific fields:** JWT configuration, token expiration

```go
type AuthAppConfig struct {
    *config.BaseAppConfig
    Auth AuthConfig `mapstructure:"auth" yaml:"auth"`
}

type AuthConfig struct {
    JWT JWTConfig `mapstructure:"jwt" yaml:"jwt"`
}
```

#### Phase 4: HTTP Clients
- [ ] **Current clients:** User service client (if any)
- [ ] **Special handling:** Minimal HTTP clients

#### Phase 5: Events
- [ ] **Current events:** User authentication events
- [ ] **Topics:** `user.login`, `user.logout`, `token.refresh`

### Testing Checklist
- [ ] JWT token generation works
- [ ] Token validation works
- [ ] Redis token storage works
- [ ] Health checks include JWT validation

---

## 🥈 PRIORITY 2: USER SERVICE

### Service Overview
- **Path:** `user/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, Auth service
- **Special Notes:** Has circuit breaker implementations

### Pre-Migration Analysis
```bash
# Check existing circuit breakers
find user/internal -name "*circuit*" -type f
grep -r "circuitbreaker" user/internal/
```

### Service-Specific Steps

#### Phase 1: Health Checks
- [ ] **Current file:** `user/internal/service/health.go`
- [ ] **Dependencies:** Database, Redis, Auth service
- [ ] **Special handling:** Add auth service health check

```go
healthSetup := health.NewHealthSetup("user-service", "v1.0.0", "production", logger)
healthSetup.
    AddDatabaseCheck("database", db).
    AddRedisCheck("redis", rdb).
    AddHTTPServiceCheck("auth-service", "http://auth-service:80/health")
```

#### Phase 4: HTTP Clients
- [ ] **Current clients:** Auth service client
- [ ] **Circuit breaker:** Already implemented - replace with common

```go
// Replace existing auth client with common HTTP client
authConfig := client.DefaultHTTPClientConfig("http://auth-service:80")
authClient := client.NewHTTPClient(authConfig, logger)
```

#### Phase 5: Events
- [ ] **Current events:** User CRUD events
- [ ] **Topics:** `user.created`, `user.updated`, `user.deleted`

### Testing Checklist
- [ ] User CRUD operations work
- [ ] Auth service communication works
- [ ] Circuit breaker protects auth calls
- [ ] User events publish correctly

---

## 🥉 PRIORITY 3: ORDER SERVICE

### Service Overview
- **Path:** `order/`
- **Complexity:** High (most HTTP clients)
- **Dependencies:** Database, Redis, 10+ external services
- **Special Notes:** Most complex service, good test case

### Pre-Migration Analysis
```bash
# Check all HTTP clients
find order/internal -name "*client*.go" -type f
# Should find: PromotionClient, PaymentClient, ShippingClient, etc.
```

### Service-Specific Steps

#### Phase 1: Health Checks
- [ ] **Dependencies:** Database, Redis, multiple services
- [ ] **Special handling:** Add key service health checks

```go
healthSetup := health.NewHealthSetup("order-service", "v1.0.0", "production", logger)
healthSetup.
    AddDatabaseCheck("database", db).
    AddRedisCheck("redis", rdb).
    AddHTTPServiceCheck("payment-service", "http://payment-service:80/health").
    AddHTTPServiceCheck("catalog-service", "http://catalog-service:80/health").
    AddHTTPServiceCheck("warehouse-service", "http://warehouse-service:80/health")
```

#### Phase 4: HTTP Clients (MAJOR WORK)
- [ ] **PromotionClient** → Promotion Service
- [ ] **PaymentClient** → Payment Service
- [ ] **PaymentMethodClient** → Payment Service
- [ ] **ShippingClient** → Shipping Service
- [ ] **NotificationClient** → Notification Service
- [ ] **UserClient** → User Service
- [ ] **ProductClient** → Catalog Service
- [ ] **CustomerClient** → Customer Service
- [ ] **PricingClient** → Pricing Service
- [ ] **WarehouseClient** → Warehouse Service

```go
// Example: Replace PromotionClient
type PromotionClient struct {
    client *client.HTTPClient
}

func NewPromotionClient(baseURL string, logger log.Logger) *PromotionClient {
    config := client.DefaultHTTPClientConfig(baseURL)
    return &PromotionClient{
        client: client.NewHTTPClient(config, logger),
    }
}

func (c *PromotionClient) ValidateCoupon(ctx context.Context, couponCode string) (*Coupon, error) {
    var coupon Coupon
    err := c.client.GetJSON(ctx, fmt.Sprintf("/api/v1/promotions/coupons/%s", couponCode), &coupon)
    return &coupon, err
}
```

#### Phase 5: Events
- [ ] **Current events:** Order lifecycle events
- [ ] **Topics:** `order.created`, `order.updated`, `order.cancelled`, `order.completed`

### Testing Checklist
- [ ] All 10+ HTTP clients work with common implementation
- [ ] Circuit breakers protect all external calls
- [ ] Order creation flow works end-to-end
- [ ] Order events publish correctly
- [ ] Performance is maintained

---

## 📦 CATALOG SERVICE

### Service Overview
- **Path:** `catalog/`
- **Complexity:** Medium-High
- **Dependencies:** Database, Redis, Pricing service
- **Special Notes:** Has caching implementation

### Service-Specific Steps

#### Phase 1: Health Checks
- [ ] **Dependencies:** Database, Redis, Pricing service
- [ ] **Special handling:** Cache health check

#### Phase 4: HTTP Clients
- [ ] **PricingClient** → Pricing Service
- [ ] **Special handling:** Preserve caching logic

#### Phase 5: Events
- [ ] **Topics:** `product.created`, `product.updated`, `product.deleted`

---

## 🏪 WAREHOUSE SERVICE

### Service Overview
- **Path:** `warehouse/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, Catalog, Notification services
- **Special Notes:** Has gRPC client to User service

### Service-Specific Steps

#### Phase 4: HTTP Clients
- [ ] **CatalogClient** → Catalog Service
- [ ] **NotificationClient** → Notification Service
- [ ] **UserServiceClient** → User Service (gRPC - special handling)

```go
// Keep gRPC client separate, only replace HTTP clients
catalogConfig := client.DefaultHTTPClientConfig("http://catalog-service:80")
catalogClient := client.NewHTTPClient(catalogConfig, logger)
```

---

## 💳 PAYMENT SERVICE

### Service Overview
- **Path:** `payment/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, Customer, Order services
- **Special Notes:** Has webhook endpoints

### Service-Specific Steps

#### Phase 1: Health Checks
- [ ] **Special handling:** Add webhook health check if needed

#### Phase 4: HTTP Clients
- [ ] **CustomerClient** → Customer Service
- [ ] **OrderClient** → Order Service

#### Phase 5: Events
- [ ] **Topics:** `payment.processed`, `payment.failed`, `payment.refunded`

---

## 👥 CUSTOMER SERVICE

### Service Overview
- **Path:** `customer/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, Order, Notification services
- **Special Notes:** Recently added circuit breakers

### Service-Specific Steps

#### Phase 4: HTTP Clients
- [ ] **OrderClient** → Order Service (recently implemented)
- [ ] **NotificationClient** → Notification Service (recently implemented)
- [ ] **Special handling:** Verify recent circuit breaker implementations

---

## 🔍 SEARCH SERVICE

### Service Overview
- **Path:** `search/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, Elasticsearch, multiple services
- **Special Notes:** Recently added circuit breakers

### Service-Specific Steps

#### Phase 1: Health Checks
- [ ] **Special handling:** Add Elasticsearch health check

```go
healthSetup.AddHTTPServiceCheck("elasticsearch", "http://elasticsearch:9200/_cluster/health")
```

#### Phase 4: HTTP Clients
- [ ] **PricingClient** → Pricing Service (recently implemented)
- [ ] **WarehouseClient** → Warehouse Service (recently implemented)
- [ ] **CatalogClient** → Catalog Service (recently implemented)

---

## 🚚 SHIPPING SERVICE

### Service Overview
- **Path:** `shipping/`
- **Complexity:** Low-Medium
- **Dependencies:** Database, Redis
- **Special Notes:** Minimal external dependencies

---

## 📦 FULFILLMENT SERVICE

### Service Overview
- **Path:** `fulfillment/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, multiple services
- **Special Notes:** Complex business logic

---

## 🔔 NOTIFICATION SERVICE

### Service Overview
- **Path:** `notification/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, external APIs
- **Special Notes:** Has Telegram provider with circuit breaker

### Service-Specific Steps

#### Phase 4: HTTP Clients
- [ ] **TelegramProvider** → Telegram API (keep existing circuit breaker)
- [ ] **Special handling:** External API clients

---

## ⭐ REVIEW SERVICE

### Service Overview
- **Path:** `review/`
- **Complexity:** Low-Medium
- **Dependencies:** Database, Redis
- **Special Notes:** Simple CRUD service

---

## 📍 LOCATION SERVICE

### Service Overview
- **Path:** `location/`
- **Complexity:** Low
- **Dependencies:** Database, Redis
- **Special Notes:** Geographic data service

---

## ⚙️ COMMON-OPERATIONS SERVICE

### Service Overview
- **Path:** `common-operations/`
- **Complexity:** Medium
- **Dependencies:** Database, Redis, multiple services
- **Special Notes:** Settings and configuration service

---

## 🌐 GATEWAY SERVICE (SPECIAL HANDLING)

### Service Overview
- **Path:** `gateway/`
- **Complexity:** Very High
- **Dependencies:** All services
- **Special Notes:** Already has circuit breakers, needs careful handling

### Special Considerations
- [ ] **Already has circuit breakers** - enhance rather than replace
- [ ] **ServiceClient** - already uses circuit breakers
- [ ] **RouteManager** - already has HTTP client protection
- [ ] **Health checks** - already implemented

### Migration Strategy
- [ ] **Phase 1:** Enhance existing health checks with common interfaces
- [ ] **Phase 4:** Enhance existing HTTP clients with common patterns
- [ ] **Phase 5:** Add common event publishing if needed

---

## 🖥️ FRONTEND SERVICES (ADMIN, FRONTEND)

### Service Overview
- **Path:** `admin/`, `frontend/`
- **Complexity:** Low (Frontend services)
- **Dependencies:** Minimal backend dependencies
- **Special Notes:** Different patterns than backend services

### Migration Strategy
- [ ] **Focus on health checks only**
- [ ] **Skip HTTP clients** (different patterns)
- [ ] **Skip events** (frontend doesn't publish events)
- [ ] **Configuration** may be different

---

## 📊 MIGRATION ORDER RECOMMENDATION

### Week 1: Foundation Services
1. **auth-service** (Simplest, good starting point)
2. **user-service** (Has circuit breakers, good test)
3. **location-service** (Simple, low risk)

### Week 2: Core Services
4. **catalog-service** (Medium complexity)
5. **customer-service** (Recently updated)
6. **review-service** (Simple CRUD)

### Week 3: Business Services
7. **order-service** (Most complex, major test)
8. **payment-service** (Critical service)
9. **warehouse-service** (Has gRPC client)

### Week 4: Integration Services
10. **pricing-service** (Business logic)
11. **promotion-service** (Business logic)
12. **shipping-service** (Logistics)
13. **fulfillment-service** (Complex workflows)

### Week 5: Support Services
14. **notification-service** (External APIs)
15. **search-service** (Recently updated)
16. **common-operations-service** (Settings)

### Week 6: Special Cases
17. **gateway** (Special handling, enhance existing)
18. **admin** (Frontend service)
19. **frontend** (Frontend service)

---

## 🚨 RISK MITIGATION

### High-Risk Services
- **order-service** (Most complex, 10+ HTTP clients)
- **gateway** (Critical path, already has implementations)
- **payment-service** (Critical business function)

### Mitigation Strategies
- [ ] **Migrate during low-traffic periods**
- [ ] **Have rollback plan ready**
- [ ] **Test thoroughly in staging**
- [ ] **Monitor closely after deployment**
- [ ] **Keep backup implementations**

### Success Criteria
- [ ] **Zero downtime** during migration
- [ ] **No performance regression**
- [ ] **All tests pass**
- [ ] **Health checks work**
- [ ] **Circuit breakers function**

---

**Last Updated:** December 2024  
**Status:** Ready for implementation  
**Next Action:** Start with auth-service migration
# Common Code Migration Checklist v1.3.3

## 📋 Daily Checklist - Common Code Implementation

**Ngày:** ___________  
**Reviewer:** ___________  
**Service:** ___________  
**Common Version:** v1.3.3 (Latest)  
**Status:** 🔄 In Progress / ✅ Completed / ❌ Issues Found

---

## 🎯 OVERVIEW

This checklist guides the migration of each service to use the new common code implementations v1.3.3. Follow this checklist for each of the 19 microservices to eliminate code duplication and standardize implementations.

### 🆕 New Features in v1.3.3
- **Enhanced Health Checks**: Caching, concurrent checks, detailed endpoints
- **HTTP Client with Circuit Breaker**: Retry logic, connection pooling, observability
- **Dapr Event Publisher**: Circuit breaker protection, structured events
- **Enhanced Database Utils**: Environment variable overrides, connection pooling
- **Configuration Loader**: Service-specific config loading with validation
- **Cache Manager**: Redis operations with TTL management
- **Validation Utils**: UUID, email, phone, password validation

**Services to Migrate:**
- [x] **auth-service (PRIORITY 1)** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: c3023fb
  - Common version: v1.3.3
  - Lines saved: ~200
  - Notes: All 5 phases complete, CI validation pending
- [x] **user-service (PRIORITY 2)** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: cd56a50
  - Common version: v1.3.3
  - Lines saved: ~215
  - Notes: Phases 1-3 complete (health, DB, config), events kept as-is
- [x] **notification-service (PRIORITY 3)** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: f81aa26
  - Common version: v1.3.3
  - Lines saved: ~199
  - Notes: DB, Redis, config migrated. Vendor-managed deps.
- [ ] product-service (PRIORITY 4 - NEXT)
- [x] **payment-service (PRIORITY 5)** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: 15be6d4
  - Common version: v1.3.3
  - Lines saved: ~150
  - Notes: Added health checks, migrated DB/Redis/Config.
- [x] **order-service (PRIORITY 6)** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: 742fb5b
  - Common version: v1.3.3
  - Lines saved: ~150
  - Notes: Health, DB, Config migrated.
- [x] **warehouse-service (PRIORITY 7)** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: f63a067
  - Common version: v1.3.3
  - Lines saved: ~9 (Phases 1-3 already done)
  - Notes: Phases 1-3 already using common code. Migrated catalog HTTP client.
- [x] **shipping-service (PRIORITY 8)** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: 5797535
  - Common version: v1.3.3
  - Lines saved: ~20 (Phases 1-3, 5 already done)
  - Notes: All phases complete. Catalog HTTP client migrated. Pre-existing helper.go issue noted.
- [x] **catalog-service** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: d34fcff
  - Common version: v1.2.9 → v1.3.3
  - Lines saved: ~8 added (health setup)
  - Notes: Phase 1 complete. Already using gRPC for all internal services! Config kept as-is (custom Viper).
- [x] **customer-service** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: 78b135b
  - Common version: v1.2.10 → v1.3.3
  - Lines saved: ~11 added (health setup)
  - Notes: Phase 1 complete. Already using gRPC for Order service with circuit breaker! Config kept as-is (custom Viper).
- [x] **pricing-service** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: 5271829 (health) + gRPC migration
  - Common version: v1.2.9 → v1.3.3
  - Phases complete: 1 (Health) + 4 (HTTP→gRPC)
  - Lines saved: ~150 (HTTP clients → gRPC)
  - Notes: Health checks + catalog/warehouse migrated to gRPC with circuit breakers!
- [x] **promotion-service** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: (pending)
  - Common version: v1.0.9 → v1.3.3
  - Lines saved: ~8 added (health setup)
  - Notes: Phase 1 complete. Added common health checks. HTTP clients (catalog, customer, pricing, review) still HTTP.
- [x] **fulfillment-service** ✅ COMPLETED
  - Migrated: 2025-12-25
  - Commit: ffad000
  - Common version: v1.3.0 → v1.3.3
  - Lines saved: ~11 added (health setup)
  - Notes: Phase 1 complete. Already using gRPC for catalog+warehouse with circuit breakers!
- [ ] search-service
- [ ] review-service
- [ ] location-service
- [ ] common-operations-service
- [ ] gateway (Special handling)
- [ ] admin (Frontend service)
- [ ] frontend (Frontend service)

---

## 🚀 PHASE 1: HEALTH CHECKS (CRITICAL - Start Here)

### Pre-Migration Checklist
- [ ] **Backup current implementation**
  ```bash
  cp -r {service}/internal/service/health.go {service}/internal/service/health.go.backup
  cp -r {service}/internal/observability/ {service}/internal/observability.backup/ 2>/dev/null || true
  ```
- [ ] **Verify common module version**
  ```bash
  cd common && git log --oneline -5
  # Should show: c8b1562 (HEAD -> main, tag: v1.3.3) cho
  ```
- [ ] **Update common module dependency**
  ```bash
  cd {service} && go get gitlab.com/ta-microservices/common@v1.3.3
  go mod tidy
  ```

### Implementation Steps
- [ ] **1. Remove existing health files**
  ```bash
  rm -f {service}/internal/service/health.go
  rm -rf {service}/internal/observability/health/ 2>/dev/null || true
  # Remove any other health-related files
  ```

- [ ] **2. Update imports in main.go or server setup**
  ```go
  // Add to imports
  import (
      "gitlab.com/ta-microservices/common/observability/health"
  )
  ```

- [ ] **3. Create health manager and register checks**
  ```go
  // Create health manager
  healthConfig := health.HealthConfig{
      ServiceName:    "{service-name}",
      ServiceVersion: "v1.0.0",
      Environment:    "production", // or from config
      CheckInterval:  30 * time.Second,
  }
  healthManager := health.NewDefaultHealthManager(healthConfig)
  
  // Register database health check
  if db != nil {
      dbChecker := health.NewDatabaseHealthChecker("database", db, 5*time.Second)
      healthManager.Register(dbChecker)
  }
  
  // Register Redis health check
  if rdb != nil {
      redisChecker := health.NewRedisHealthChecker("redis", rdb, 3*time.Second)
      healthManager.Register(redisChecker)
  }
  
  // Create HTTP handler
  healthHandler := health.NewHTTPHealthHandler(healthManager, logger)
  ```

- [ ] **4. Register health endpoints**
  ```go
  // For Kratos HTTP server
  srv.HandleFunc("/health", healthHandler.HealthHandler)
  srv.HandleFunc("/health/ready", healthHandler.ReadinessHandler)
  srv.HandleFunc("/health/live", healthHandler.LivenessHandler)
  srv.HandleFunc("/health/detailed", healthHandler.DetailedHandler)
  
  // Or use the helper function
  health.RegisterHTTPHandlers(srv, healthHandler)
  ```

### Testing & Validation
- [ ] **Build service successfully**
  ```bash
  cd {service} && go build ./cmd/{service}
  ```

- [ ] **Test health endpoints locally**
  ```bash
  # Start service locally
  ./bin/{service} -conf ./configs
  
  # Test all endpoints
  curl http://localhost:8080/health          # Overall health
  curl http://localhost:8080/health/ready    # Readiness probe
  curl http://localhost:8080/health/live     # Liveness probe
  curl http://localhost:8080/health/detailed # Detailed information
  ```

- [ ] **Verify enhanced response format**
  - [ ] `/health` returns cached results (10s TTL)
  - [ ] `/health/ready` returns strict readiness status
  - [ ] `/health/live` returns simple liveness status
  - [ ] `/health/detailed` returns comprehensive information with metadata

- [ ] **Test health check caching**
  ```bash
  # Multiple rapid requests should return cached results
  time curl http://localhost:8080/health
  time curl http://localhost:8080/health  # Should be faster (cached)
  ```

- [ ] **Test with dependencies down**
  - [ ] Stop database → health should be unhealthy, circuit breaker should open
  - [ ] Stop Redis → health should show Redis as unhealthy
  - [ ] Restart dependencies → health should recover automatically

### Kubernetes Validation
- [ ] **Deploy to staging**
  ```bash
  # Update image tag and deploy
  kubectl apply -f argocd/applications/{service}/{service}-staging-app.yaml
  ```

- [ ] **Verify Kubernetes health checks**
  ```bash
  kubectl get pods -n support-services -l app.kubernetes.io/name={service}
  kubectl describe pod {pod-name} -n support-services
  # Check readiness and liveness probe status
  ```

- [ ] **Check health endpoints in cluster**
  ```bash
  kubectl port-forward svc/{service} 8080:80 -n support-services
  curl http://localhost:8080/health/detailed
  ```

---

## 🗄️ PHASE 2: DATABASE CONNECTIONS (CRITICAL)

### Pre-Migration Checklist
- [ ] **Backup current data.go**
  ```bash
  cp {service}/internal/data/data.go {service}/internal/data/data.go.backup
  ```

- [ ] **Review current database configuration**
  - [ ] Note current connection pool settings
  - [ ] Note current Redis configuration
  - [ ] Check environment variable usage

### Implementation Steps
- [ ] **1. Update imports**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/utils"
  ```

- [ ] **2. Replace database connection function**
  ```go
  // Replace existing NewDB function with:
  func NewDB(cfg *config.AppConfig, logger log.Logger) *gorm.DB {
      return utils.NewPostgresDB(utils.DatabaseConfig{
          Source:          cfg.Data.Database.Source,
          MaxOpenConns:    cfg.Data.Database.MaxOpenConns,
          MaxIdleConns:    cfg.Data.Database.MaxIdleConns,
          ConnMaxLifetime: cfg.Data.Database.ConnMaxLifetime,
          ConnMaxIdleTime: cfg.Data.Database.ConnMaxIdleTime,
          LogLevel:        cfg.Data.Database.LogLevel,
      }, logger)
  }
  ```

- [ ] **3. Replace Redis connection function**
  ```go
  // Replace existing NewRedis function with:
  func NewRedis(cfg *config.AppConfig, logger log.Logger) *redis.Client {
      return utils.NewRedisClient(utils.RedisConfig{
          Addr:         cfg.Data.Redis.Addr,
          Password:     cfg.Data.Redis.Password,
          DB:           cfg.Data.Redis.DB,
          MaxRetries:   cfg.Data.Redis.MaxRetries,
          PoolSize:     cfg.Data.Redis.PoolSize,
          DialTimeout:  cfg.Data.Redis.DialTimeout,
          ReadTimeout:  cfg.Data.Redis.ReadTimeout,
          WriteTimeout: cfg.Data.Redis.WriteTimeout,
      }, logger)
  }
  ```

- [ ] **4. Remove duplicate connection code**
  - [ ] Remove manual GORM setup code
  - [ ] Remove manual Redis client setup code
  - [ ] Remove duplicate connection pool configuration
  - [ ] Remove duplicate error handling

### 🆕 Enhanced Features Testing
- [ ] **Test environment variable overrides**
  ```bash
  # Test DATABASE_URL override (highest priority)
  DATABASE_URL="postgres://test:test@localhost:5432/test" ./bin/{service} -conf ./configs
  # Should see: "Using DATABASE_URL from environment variable"
  
  # Test REDIS_ADDR override
  REDIS_ADDR="localhost:6380" ./bin/{service} -conf ./configs
  # Should see: "Using REDIS_ADDR from environment variable"
  ```

- [ ] **Verify enhanced connection logging**
  ```bash
  # Start service and check logs for enhanced connection info
  ./bin/{service} -conf ./configs
  # Should see: "✅ Database connected (max_open=100, max_idle=20, max_lifetime=30m0s)"
  # Should see: "✅ Redis connected (addr=localhost:6379, db=0, pool_size=10)"
  ```

- [ ] **Test connection pool settings**
  - [ ] Verify default values are applied when not configured
  - [ ] Check connection pool metrics in logs
  - [ ] Test connection recovery after database restart

### Testing & Validation
- [ ] **Test database connectivity**
  ```bash
  # Start service and check logs for database connection
  ./bin/{service} -conf ./configs
  # Should see: "✅ Database connected (max_open=100, max_idle=20)"
  ```

- [ ] **Test Redis connectivity**
  ```bash
  # Check logs for Redis connection
  # Should see: "✅ Redis connected (addr=localhost:6379, db=0, pool_size=10)"
  ```

- [ ] **Test connection pooling**
  - [ ] Check connection pool metrics in logs
  - [ ] Verify max connections are respected
  - [ ] Test connection recovery after database restart

---

## ⚙️ PHASE 3: CONFIGURATION MANAGEMENT (HIGH PRIORITY)

### Pre-Migration Checklist
- [ ] **Backup current config files**
  ```bash
  cp {service}/internal/config/config.go {service}/internal/config/config.go.backup
  ```

- [ ] **Review current configuration structure**
  - [ ] Note service-specific config fields
  - [ ] Check Viper setup patterns
  - [ ] Identify environment variable mappings

### Implementation Steps
- [ ] **1. Update imports**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/config"
  ```

- [ ] **2. Use ServiceConfigLoader for enhanced loading**
  ```go
  // Replace manual Viper setup with:
  func Init(configPath string) (*{Service}AppConfig, error) {
      loader := config.NewServiceConfigLoader("{service-name}", configPath)
      
      cfg := &{Service}AppConfig{}
      
      return cfg, loader.LoadServiceConfig(cfg)
  }
  ```

- [ ] **3. Extend BaseAppConfig (Optional but Recommended)**
  ```go
  // Update service config struct to extend BaseAppConfig
  type {Service}AppConfig struct {
      *config.BaseAppConfig  // 🆕 Inherit common config
      ExternalServices ExternalServicesConfig `mapstructure:"external_services" yaml:"external_services"`
      Business         BusinessConfig         `mapstructure:"business" yaml:"business"`
      // Add other service-specific fields
  }
  ```

- [ ] **4. Remove duplicate Viper code**
  - [ ] Remove manual Viper initialization
  - [ ] Remove duplicate environment variable setup
  - [ ] Remove duplicate config file reading

### 🆕 Enhanced Configuration Features
- [ ] **Test service-specific environment prefix**
  ```bash
  # Environment variables are automatically prefixed with service name
  # For "auth-service": AUTH_SERVICE_SERVER_HTTP_ADDR=":8081"
  # For "user-service": USER_SERVICE_DATA_DATABASE_SOURCE="postgres://..."
  {SERVICE}_SERVER_HTTP_ADDR=":8081" ./bin/{service} -conf ./configs
  ```

- [ ] **Verify common defaults are applied**
  ```bash
  # Check that common defaults are loaded
  ./bin/{service} -conf ./configs
  # Should see default values for server.http.timeout=30s, database pool settings, etc.
  ```

- [ ] **Test configuration validation**
  ```go
  // Add validation in your config loading
  if err := config.ValidateServiceConfig(cfg); err != nil {
      return nil, fmt.Errorf("config validation failed: %w", err)
  }
  ```

### Testing & Validation
- [ ] **Test configuration loading**
  ```bash
  # Test with config file
  ./bin/{service} -conf ./configs
  
  # Test with environment variables
  {SERVICE}_SERVER_HTTP_ADDR=":8081" ./bin/{service} -conf ./configs
  ```

- [ ] **Verify all config fields load correctly**
  - [ ] Check service-specific configuration
  - [ ] Verify database configuration
  - [ ] Verify Redis configuration
  - [ ] Check external service URLs

- [ ] **Test environment variable overrides**
  ```bash
  # Test common overrides
  {SERVICE}_DATA_DATABASE_SOURCE="postgres://..." ./bin/{service} -conf ./configs
  {SERVICE}_DATA_REDIS_ADDR="localhost:6380" ./bin/{service} -conf ./configs
  ```

---

## 🌐 PHASE 4: HTTP CLIENTS → gRPC CLIENTS (HIGH PRIORITY)

> [!IMPORTANT]
> **POLICY: Migrate to gRPC for Internal Services**
> - **Primary Goal**: Migrate HTTP clients to gRPC clients for internal service communication
> - **Use gRPC clients** from `common/client` for all internal microservices
> - **Keep HTTP clients** only for:
>   - External third-party APIs (payment gateways, shipping carriers, etc.)
>   - Services that don't have gRPC support yet (legacy systems)
> - **Benefits**: Better performance, type safety, circuit breaker protection, connection pooling

### Pre-Migration Checklist
- [ ] **Identify existing HTTP clients for internal services**
  ```bash
  find {service}/internal -name "*client*.go" -type f
  grep -r "http.Client" {service}/internal/
  grep -r "catalog.*http" {service}/internal/
  grep -r "user.*http" {service}/internal/
  ```

- [ ] **Identify services that should use gRPC**
  ```bash
  # Look for internal service calls that should be gRPC
  grep -r "auth-service" {service}/internal/
  grep -r "user-service" {service}/internal/
  grep -r "catalog-service" {service}/internal/
  grep -r "order-service" {service}/internal/
  ```

### Implementation Steps

#### Option A: Migrate HTTP → gRPC (Recommended)
- [ ] **1. Update imports**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/client"
  ```

- [ ] **2. Replace HTTP clients with gRPC clients using factory**
  ```go
  // Replace HTTP client creation with gRPC factory:
  grpcFactory := client.NewGRPCClientFactory(logger)
  
  // Create gRPC clients for internal services
  authClient, err := grpcFactory.CreateAuthClient()
  userClient, err := grpcFactory.CreateUserClient()
  catalogClient, err := grpcFactory.CreateCatalogClient()
  orderClient, err := grpcFactory.CreateOrderClient()
  ```

- [ ] **3. Update service client methods to use gRPC**
  ```go
  // Replace HTTP calls with gRPC calls:
  func (c *UserClient) GetUser(ctx context.Context, userID string) (*User, error) {
      // Get gRPC connection
      conn := c.grpcClient.GetConnection()
      
      // Create protobuf client
      userClient := userpb.NewUserServiceClient(conn)
      
      // Make gRPC call
      resp, err := userClient.GetUser(ctx, &userpb.GetUserRequest{
          UserId: userID,
      })
      if err != nil {
          return nil, err
      }
      
      // Convert protobuf to domain model
      return convertUserFromProto(resp.User), nil
  }
  ```

- [ ] **4. Add gRPC health checks**
  ```go
  // Add gRPC health checks to health manager
  if authClient != nil {
      authChecker := health.NewGRPCHealthChecker("auth-service", authClient, 5*time.Second)
      healthManager.Register(authChecker)
  }
  
  // Or use pool health checker for all gRPC services
  poolChecker := health.NewGRPCPoolHealthChecker("grpc-services", grpcFactory, 10*time.Second)
  healthManager.Register(poolChecker)
  ```

#### Option B: Keep HTTP but Enhance (For External APIs)
- [ ] **1. Update imports for enhanced HTTP client**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/client"
  ```

- [ ] **2. Replace HTTP client creation with enhanced client**
  ```go
  // Replace existing HTTP client with:
  config := client.DefaultHTTPClientConfig(baseURL)
  config.MaxRetries = 3
  config.Timeout = 30 * time.Second
  config.CircuitBreaker.FailureThreshold = 5
  config.CircuitBreaker.RecoveryTimeout = 30 * time.Second
  httpClient := client.NewHTTPClient(config, logger)
  ```

### 🆕 gRPC Client Features Testing
- [ ] **Test gRPC client factory**
  ```bash
  # Verify gRPC clients are created successfully
  # Check connection states and circuit breaker states
  ```

- [ ] **Test gRPC connection pooling**
  ```bash
  # Verify gRPC connections are reused efficiently
  # Check keep-alive settings work correctly
  ```

- [ ] **Test gRPC circuit breaker**
  ```bash
  # Stop target service → circuit should open
  # Start target service → circuit should close
  # Verify gRPC-specific error handling
  ```

- [ ] **Test gRPC metadata**
  ```go
  // Test custom metadata in gRPC calls
  grpcClient.SetMetadata("request-id", requestID)
  grpcClient.SetMetadata("user-id", userID)
  ```

- [ ] **Test environment variable overrides**
  ```bash
  # Test gRPC service endpoint overrides
  AUTH_SERVICE_GRPC_ADDR="auth-service:9001" ./bin/{service} -conf ./configs
  USER_SERVICE_GRPC_ADDR="user-service:9001" ./bin/{service} -conf ./configs
  ```

### Testing & Validation
- [ ] **Test gRPC client functionality**
  ```bash
  # Start dependent gRPC services
  # Test service-to-service gRPC communication
  ```

- [ ] **Test gRPC circuit breaker behavior**
  - [ ] Stop target gRPC service → circuit should open
  - [ ] Start target gRPC service → circuit should close
  - [ ] Verify gRPC circuit breaker metrics

- [ ] **Test gRPC retry logic**
  - [ ] Simulate gRPC failures (UNAVAILABLE, DEADLINE_EXCEEDED)
  - [ ] Verify retry attempts with backoff
  - [ ] Check gRPC-specific error codes

- [ ] **Test gRPC connection management**
  - [ ] Verify connection reuse and pooling
  - [ ] Check keep-alive functionality
  - [ ] Monitor connection states

- [ ] **Performance comparison**
  - [ ] Compare gRPC vs HTTP performance
  - [ ] Measure latency improvements
  - [ ] Check resource usage (memory, CPU)

### Migration Priority
1. **High Priority**: Internal service calls (auth, user, catalog, order)
2. **Medium Priority**: Internal business logic services (pricing, promotion, inventory)
3. **Low Priority**: External APIs (keep as HTTP with enhanced client)

### Common gRPC Service Endpoints
```bash
# Default gRPC endpoints (can be overridden with environment variables)
AUTH_SERVICE_GRPC_ADDR="auth-service:9000"
USER_SERVICE_GRPC_ADDR="user-service:9000"
CATALOG_SERVICE_GRPC_ADDR="catalog-service:9000"
ORDER_SERVICE_GRPC_ADDR="order-service:9000"
PAYMENT_SERVICE_GRPC_ADDR="payment-service:9000"
WAREHOUSE_SERVICE_GRPC_ADDR="warehouse-service:9000"
SHIPPING_SERVICE_GRPC_ADDR="shipping-service:9000"
CUSTOMER_SERVICE_GRPC_ADDR="customer-service:9000"
PRICING_SERVICE_GRPC_ADDR="pricing-service:9000"
PROMOTION_SERVICE_GRPC_ADDR="promotion-service:9000"
```

---

## 📡 PHASE 5: EVENT PUBLISHING (HIGH PRIORITY)

### Pre-Migration Checklist
- [ ] **Identify existing event publishers**
  ```bash
  find {service}/internal -name "*event*" -type f
  grep -r "dapr" {service}/internal/
  grep -r "publish" {service}/internal/
  ```

### Implementation Steps
- [ ] **1. Update imports**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/events"
  ```

- [ ] **2. Replace event publisher creation with enhanced publisher**
  ```go
  // Replace existing Dapr publisher with:
  config := events.DefaultDaprEventPublisherConfig()
  config.DaprURL = "http://localhost:3500"
  config.PubsubName = "pubsub-redis"
  config.Timeout = 10 * time.Second
  config.CircuitBreaker.FailureThreshold = 3
  eventPublisher := events.NewDaprEventPublisher(config, logger)
  ```

- [ ] **3. Update event publishing calls with structured events**
  ```go
  // Replace manual event publishing with structured events:
  event := events.UserEvent{
      BaseEvent: events.BaseEvent{
          EventType:   "user.registered",
          ServiceName: "{service-name}",
          Timestamp:   time.Now(),
          Version:     "v1.0",
      },
      UserID: user.ID,
      Action: "registered",
  }
  
  err := eventPublisher.PublishEvent(ctx, events.TopicUserRegistered, event)
  
  // 🆕 Or with metadata:
  metadata := map[string]string{
      "source":    "user-service",
      "requestId": requestID,
  }
  err := eventPublisher.PublishWithMetadata(ctx, events.TopicUserRegistered, event, metadata)
  ```

- [ ] **4. Use predefined event types and topics**
  ```go
  // 🆕 Use common event types:
  orderEvent := events.OrderEvent{
      BaseEvent: events.BaseEvent{
          EventType:   "order.created",
          ServiceName: "order-service",
          Timestamp:   time.Now(),
      },
      OrderID:    order.ID,
      CustomerID: order.CustomerID,
      Status:     "created",
      Amount:     order.TotalAmount,
  }
  
  // 🆕 Use predefined topics:
  err := eventPublisher.PublishEvent(ctx, events.TopicOrderCreated, orderEvent)
  ```

- [ ] **5. Remove duplicate event code**
  - [ ] Remove manual Dapr HTTP calls
  - [ ] Remove duplicate event structures
  - [ ] Remove manual retry logic
  - [ ] Remove custom circuit breaker implementations

### 🆕 Enhanced Event Publishing Features
- [ ] **Test circuit breaker protection**
  ```bash
  # Stop Dapr sidecar and verify circuit breaker opens
  # Events should fail gracefully without crashing service
  ```

- [ ] **Test structured event format**
  ```bash
  # Verify events follow CloudEvents specification
  # Check event metadata and headers
  ```

- [ ] **Test event metadata**
  ```go
  // Test custom metadata in events
  metadata := map[string]string{
      "correlation_id": correlationID,
      "user_id":       userID,
  }
  err := eventPublisher.PublishWithMetadata(ctx, topic, event, metadata)
  ```

### Testing & Validation
- [ ] **Test event publishing**
  ```bash
  # Start Dapr sidecar
  dapr run --app-id {service} --app-port 8080 --dapr-http-port 3500
  
  # Test event publishing
  # Check Dapr logs for published events
  ```

- [ ] **Verify enhanced event format**
  - [ ] Check event structure matches CloudEvents specification
  - [ ] Verify event metadata and headers
  - [ ] Check event timestamps and versioning

- [ ] **Test circuit breaker for events**
  - [ ] Stop Dapr → events should fail gracefully
  - [ ] Start Dapr → events should resume
  - [ ] Verify circuit breaker metrics

- [ ] **Test event types and topics**
  - [ ] Verify predefined event types work correctly
  - [ ] Check topic constants are used
  - [ ] Test event serialization/deserialization

---

## 🛠️ PHASE 6: UTILITIES & CACHING (MEDIUM PRIORITY)

### Pre-Migration Checklist
- [ ] **Identify existing utility functions**
  ```bash
  find {service}/internal -name "*util*" -type f
  find {service}/internal -name "*helper*" -type f
  grep -r "validation" {service}/internal/
  grep -r "cache" {service}/internal/
  ```

### Implementation Steps
- [ ] **1. Update imports for utilities**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/utils"
  ```

- [ ] **2. Replace validation functions**
  ```go
  // Replace custom validation with common utilities:
  
  // UUID validation
  if !utils.IsValidUUID(userID) {
      return errors.New("invalid user ID format")
  }
  
  // Email validation
  if !utils.IsValidEmail(user.Email) {
      return errors.New("invalid email format")
  }
  
  // Phone validation
  if !utils.IsValidPhone(user.Phone) {
      return errors.New("invalid phone format")
  }
  
  // Password validation
  if !utils.IsValidPassword(password) {
      return errors.New("password does not meet requirements")
  }
  
  // Slug generation
  slug := utils.GenerateSlug(product.Name)
  
  // Required field validation
  missing := utils.ValidateRequired(map[string]interface{}{
      "name":  user.Name,
      "email": user.Email,
  })
  if len(missing) > 0 {
      return fmt.Errorf("missing required fields: %s", strings.Join(missing, ", "))
  }
  ```

- [ ] **3. Implement cache manager**
  ```go
  // Replace manual Redis operations with cache manager:
  cacheManager := utils.NewCacheManager(redisClient, "{service-name}")
  
  // Set cache with TTL
  err := cacheManager.Set(ctx, utils.UserCacheKey(userID), user, utils.MediumTTL)
  
  // Get from cache
  var user User
  err := cacheManager.Get(ctx, utils.UserCacheKey(userID), &user)
  
  // Get or set pattern
  var products []Product
  err := cacheManager.GetOrSet(ctx, "products:list", &products, utils.ShortTTL, func() (interface{}, error) {
      return fetchProductsFromDB()
  })
  
  // Use predefined cache keys
  productKey := utils.ProductCacheKey(productID)
  categoryKey := utils.CategoryCacheKey(categoryID)
  listKey := utils.ListCacheKey("orders", map[string]interface{}{
      "user_id": userID,
      "status":  "active",
  })
  ```

- [ ] **4. Replace string and data utilities**
  ```go
  // String sanitization
  cleanInput := utils.SanitizeString(userInput)
  
  // String truncation
  shortDesc := utils.TruncateString(description, 100)
  ```

- [ ] **5. Remove duplicate utility code**
  - [ ] Remove custom validation functions
  - [ ] Remove manual Redis cache operations
  - [ ] Remove duplicate string utilities
  - [ ] Remove custom helper functions that exist in common

### 🆕 Enhanced Utility Features Testing
- [ ] **Test validation utilities**
  ```go
  // Test various validation functions
  assert.True(t, utils.IsValidUUID("123e4567-e89b-12d3-a456-426614174000"))
  assert.True(t, utils.IsValidEmail("user@example.com"))
  assert.True(t, utils.IsValidPhone("+1234567890"))
  assert.True(t, utils.IsValidPassword("SecurePass123!"))
  
  // Test slug generation
  slug := utils.GenerateSlug("My Product Name")
  assert.Equal(t, "my-product-name", slug)
  ```

- [ ] **Test cache manager functionality**
  ```bash
  # Test cache operations
  # Verify TTL settings work correctly
  # Test cache key generation
  ```

- [ ] **Test GetOrSet pattern**
  ```go
  // Test cache-aside pattern
  var result ExpensiveData
  err := cacheManager.GetOrSet(ctx, "expensive:data", &result, utils.LongTTL, func() (interface{}, error) {
      // This should only be called on cache miss
      return fetchExpensiveData()
  })
  ```

### Testing & Validation
- [ ] **Test validation functions**
  ```bash
  # Test various input validation
  # Verify error messages are appropriate
  ```

- [ ] **Test cache operations**
  ```bash
  # Test cache set/get operations
  # Verify TTL behavior
  # Test cache invalidation
  ```

- [ ] **Test utility functions**
  ```bash
  # Test string utilities
  # Test data transformation functions
  # Verify performance improvements
  ```

- [ ] **Performance validation**
  - [ ] Verify cache hit rates
  - [ ] Check validation performance
  - [ ] Monitor memory usage

---

## 🗄️ PHASE 7: REPOSITORY PATTERNS (HIGH IMPACT)

### Pre-Migration Checklist
- [ ] **Identify existing repository patterns**
  ```bash
  find {service}/internal -name "*repo*" -type f
  find {service}/internal -name "*repository*" -type f
  grep -r "FindByID\|Create\|Update\|Delete" {service}/internal/
  ```

### Implementation Steps
- [ ] **1. Update imports for repository base**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/repository"
  ```

- [ ] **2. Replace repository implementations**
  ```go
  // Replace custom repository with generic base:
  
  // Before (custom implementation)
  type UserRepository struct {
      db *gorm.DB
  }
  
  func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
      var user User
      err := r.db.WithContext(ctx).First(&user, "id = ?", id).Error
      // ... error handling
      return &user, err
  }
  
  // After (using common base)
  type UserRepository struct {
      repository.BaseRepository[User]
  }
  
  func NewUserRepository(db *gorm.DB, logger log.Logger) *UserRepository {
      baseRepo := repository.NewGormRepository[User](db, logger)
      baseRepo.SetSearchFields([]string{"name", "email", "username"})
      
      return &UserRepository{
          BaseRepository: baseRepo,
      }
  }
  
  // Usage remains the same
  user, err := userRepo.FindByID(ctx, userID)
  ```

- [ ] **3. Implement advanced filtering**
  ```go
  // Use common filter for complex queries
  filter := &repository.Filter{
      Page:     1,
      PageSize: 20,
      Sort:     "created_at",
      Order:    "desc",
      Search:   "john",
      Filters: map[string]interface{}{
          "status": "active",
          "role":   "user",
      },
      Conditions: []repository.Condition{
          {Field: "age", Operator: ">=", Value: 18},
          {Field: "country", Operator: "IN", Value: []string{"US", "CA"}},
      },
      Preloads: []string{"Profile", "Orders"},
  }
  
  users, pagination, err := userRepo.List(ctx, filter)
  ```

- [ ] **4. Use repository factory**
  ```go
  // Create repositories using factory
  factory := repository.NewRepositoryFactory(db, logger)
  
  userRepo := factory.CreateRepository[User]()
  productRepo := factory.CreateRepository[Product]()
  orderRepo := factory.CreateRepository[Order]()
  ```

### 🆕 Enhanced Repository Features Testing
- [ ] **Test generic repository operations**
  ```go
  // Test CRUD operations
  user := &User{Name: "John Doe", Email: "john@example.com"}
  err := userRepo.Create(ctx, user)
  
  foundUser, err := userRepo.FindByID(ctx, user.ID)
  
  err = userRepo.Update(ctx, user, map[string]interface{}{"name": "Jane Doe"})
  
  err = userRepo.DeleteByID(ctx, user.ID)
  ```

- [ ] **Test advanced filtering**
  ```bash
  # Test search functionality
  # Test pagination
  # Test sorting and filtering
  ```

- [ ] **Test batch operations**
  ```go
  // Test batch create/update/delete
  users := []*User{{Name: "User1"}, {Name: "User2"}}
  err := userRepo.CreateBatch(ctx, users)
  
  err = userRepo.UpdateBatch(ctx, users)
  
  ids := []string{"id1", "id2"}
  err = userRepo.DeleteBatch(ctx, ids)
  ```

### Testing & Validation
- [ ] **Test repository functionality**
  ```bash
  # Test all CRUD operations
  # Test filtering and pagination
  # Test search functionality
  ```

- [ ] **Performance validation**
  - [ ] Verify query performance
  - [ ] Check memory usage
  - [ ] Test with large datasets

---

## 🔧 PHASE 8: ADVANCED VALIDATION (MEDIUM PRIORITY)

### Pre-Migration Checklist
- [ ] **Identify existing validation logic**
  ```bash
  find {service}/internal -name "*validation*" -type f
  grep -r "Validate\|validate" {service}/internal/
  grep -r "IsValid\|isValid" {service}/internal/
  ```

### Implementation Steps
- [ ] **1. Update imports for validation**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/validation"
  ```

- [ ] **2. Replace validation functions with fluent API**
  ```go
  // Replace custom validation with fluent API:
  
  // Before (custom validation)
  func ValidateUser(user *User) error {
      if user.Email == "" {
          return errors.New("email is required")
      }
      if !isValidEmail(user.Email) {
          return errors.New("invalid email format")
      }
      if len(user.Name) < 2 {
          return errors.New("name too short")
      }
      return nil
  }
  
  // After (using common validation)
  func ValidateUser(user *User) error {
      return validation.NewValidator().
          Required("email", user.Email).
          Email("email", user.Email).
          Required("name", user.Name).
          StringLength("name", user.Name, 2, 100).
          Validate()
  }
  ```

- [ ] **3. Use predefined business validators**
  ```go
  // Use business-specific validators
  err := validation.ValidateUserRegistration(user.Email, user.Password, user.Name)
  err := validation.ValidateProductData(product.Name, product.Description, product.Price)
  err := validation.ValidateOrderData(order.CustomerID, order.Items)
  err := validation.ValidatePromotionCode(promotion.Code)
  ```

- [ ] **4. Implement custom validation rules**
  ```go
  // Add custom validation rules
  err := validation.NewValidator().
      Required("product_id", productID).
      UUID("product_id", productID).
      Custom("quantity", quantity, func(value interface{}) error {
          if q, ok := value.(int); ok && q <= 0 {
              return fmt.Errorf("quantity must be positive")
          }
          return nil
      }).
      Validate()
  ```

### Testing & Validation
- [ ] **Test validation rules**
  ```bash
  # Test all validation functions
  # Test error messages
  # Test edge cases
  ```

- [ ] **Performance validation**
  - [ ] Verify validation performance
  - [ ] Test with large datasets

---

## 🏗️ PHASE 9: WORKER CONSOLIDATION (MEDIUM PRIORITY)

### Pre-Migration Checklist
- [ ] **Identify existing workers**
  ```bash
  find {service}/internal -name "*worker*" -type f
  find {service}/internal -name "*job*" -type f
  grep -r "ticker\|time.Ticker" {service}/internal/
  ```

### Implementation Steps
- [ ] **1. Update imports for worker base**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/worker"
  ```

- [ ] **2. Replace worker implementations**
  ```go
  // Replace custom worker with base worker:
  
  // Before (custom worker)
  type OrderCleanupWorker struct {
      interval time.Duration
      logger   *log.Helper
      stopCh   chan struct{}
  }
  
  func (w *OrderCleanupWorker) Start(ctx context.Context) {
      ticker := time.NewTicker(w.interval)
      defer ticker.Stop()
      
      for {
          select {
          case <-ctx.Done():
              return
          case <-w.stopCh:
              return
          case <-ticker.C:
              w.cleanup(ctx)
          }
      }
  }
  
  // After (using common base)
  type OrderCleanupWorker struct {
      *worker.BaseWorker
      orderRepo OrderRepository
  }
  
  func NewOrderCleanupWorker(orderRepo OrderRepository, logger log.Logger) *OrderCleanupWorker {
      config := worker.DefaultWorkerConfig("order-cleanup", 1*time.Hour)
      baseWorker := worker.NewBaseWorker(config, logger)
      
      return &OrderCleanupWorker{
          BaseWorker: baseWorker,
          orderRepo:  orderRepo,
      }
  }
  
  func (w *OrderCleanupWorker) Name() string {
      return "order-cleanup"
  }
  
  func (w *OrderCleanupWorker) Run(ctx context.Context) error {
      return w.orderRepo.CleanupExpiredOrders(ctx)
  }
  
  func (w *OrderCleanupWorker) HealthCheck(ctx context.Context) error {
      // Check if repository is accessible
      return w.orderRepo.HealthCheck(ctx)
  }
  ```

- [ ] **3. Use worker registry**
  ```go
  // Register and manage workers
  registry := worker.NewWorkerRegistry(logger)
  
  // Register workers
  cleanupWorker := NewOrderCleanupWorker(orderRepo, logger)
  registry.Register("order-cleanup", cleanupWorker.BaseWorker)
  
  emailWorker := NewEmailWorker(emailService, logger)
  registry.Register("email-sender", emailWorker.BaseWorker)
  
  // Start all workers
  workers := map[string]worker.Worker{
      "order-cleanup": cleanupWorker,
      "email-sender":  emailWorker,
  }
  
  err := registry.StartAll(ctx, workers)
  ```

### Testing & Validation
- [ ] **Test worker functionality**
  ```bash
  # Test worker start/stop
  # Test worker restart
  # Test worker metrics
  ```

- [ ] **Performance validation**
  - [ ] Verify worker performance
  - [ ] Test error handling and retries

---

## 🔍 VALIDATION & TESTING

### Comprehensive Testing
- [ ] **Unit tests pass**
  ```bash
  cd {service} && go test ./...
  ```

- [ ] **Integration tests pass**
  ```bash
  # Run integration tests if available
  go test -tags=integration ./...
  ```

- [ ] **Load testing (if applicable)**
  ```bash
  # Run load tests to verify performance
  ```

### Performance Validation
- [ ] **No performance regression**
  - [ ] Response times within acceptable range
  - [ ] Memory usage stable
  - [ ] CPU usage stable
  - [ ] Database connection pool efficient

- [ ] **Circuit breaker metrics**
  - [ ] Circuit breakers respond correctly
  - [ ] Failure thresholds work
  - [ ] Recovery works properly

### Production Readiness
- [ ] **Staging deployment successful**
  ```bash
  kubectl get pods -n support-services -l app.kubernetes.io/name={service}
  kubectl logs -f deployment/{service} -n support-services
  ```

- [ ] **Health checks working in K8s**
  ```bash
  kubectl describe pod {pod-name} -n support-services
  # Check readiness and liveness probe status
  ```

- [ ] **Service communication working**
  - [ ] Service-to-service calls successful
  - [ ] Events publishing correctly
  - [ ] Database operations working

---

## 📊 COMPLETION CHECKLIST

### Code Quality
- [ ] **All duplicate code removed**
  - [ ] No remaining health check implementations
  - [ ] No duplicate database connection code
  - [ ] No manual HTTP client implementations
  - [ ] No duplicate event publishing code
  - [ ] No custom validation functions that exist in common
  - [ ] No manual Redis cache operations

- [ ] **Code follows common patterns**
  - [ ] Uses enhanced health check system with caching
  - [ ] Uses common database utilities with environment overrides
  - [ ] Uses common gRPC clients with circuit breakers (for internal services)
  - [ ] Uses common HTTP clients with circuit breakers (for external APIs only)
  - [ ] Uses common event publishing with structured events
  - [ ] Uses common validation utilities
  - [ ] Uses common cache manager

### 🆕 Enhanced Features Validation
- [ ] **Health checks enhanced**
  - [ ] Caching enabled (10s TTL)
  - [ ] Concurrent health checks working
  - [ ] All 4 endpoints functional (/health, /ready, /live, /detailed)
  - [ ] Circuit breaker protection active

- [ ] **Database connections enhanced**
  - [ ] Environment variable overrides working (DATABASE_URL, REDIS_ADDR)
  - [ ] Enhanced logging with connection details
  - [ ] Connection pooling optimized

- [ ] **HTTP clients enhanced**
  - [ ] Circuit breaker protection active
  - [ ] Retry logic with exponential backoff
  - [ ] Connection pooling enabled
  - [ ] Custom headers support working

- [ ] **gRPC clients implemented (for internal services)**
  - [ ] gRPC factory working for service discovery
  - [ ] Circuit breaker protection active for gRPC
  - [ ] Connection pooling and keep-alive working
  - [ ] Metadata support functional
  - [ ] Environment variable overrides working (e.g., AUTH_SERVICE_GRPC_ADDR)

- [ ] **Event publishing enhanced**
  - [ ] Circuit breaker protection for Dapr
  - [ ] Structured events (CloudEvents format)
  - [ ] Metadata support working
  - [ ] Predefined event types used

- [ ] **Utilities integrated**
  - [ ] Validation functions working
  - [ ] Cache manager operational
  - [ ] String utilities functional
  - [ ] Performance improvements verified

### Documentation
- [ ] **Update service README**
  - [ ] Document new common code usage v1.3.3
  - [ ] Update setup instructions
  - [ ] Update troubleshooting guide
  - [ ] Document new environment variables

- [ ] **Update deployment docs**
  - [ ] Update environment variables
  - [ ] Update health check endpoints
  - [ ] Update monitoring setup
  - [ ] Document circuit breaker metrics

### Monitoring & Observability
- [ ] **Metrics working**
  - [ ] Health check metrics with caching info
  - [ ] Circuit breaker metrics (state, failures, recoveries)
  - [ ] Database connection pool metrics
  - [ ] HTTP client metrics (requests, latency, errors)
  - [ ] gRPC client metrics (requests, latency, errors, connection states)
  - [ ] Cache hit/miss ratios

- [ ] **Logging enhanced**
  - [ ] Structured logging with context
  - [ ] Enhanced error logging with stack traces
  - [ ] Performance logging with timing
  - [ ] Circuit breaker state changes logged

### Performance & Reliability
- [ ] **Circuit breakers functional**
  - [ ] Database circuit breaker working
  - [ ] HTTP client circuit breakers working (external APIs)
  - [ ] gRPC client circuit breakers working (internal services)
  - [ ] Event publishing circuit breaker working
  - [ ] Proper failure thresholds configured

- [ ] **Caching operational**
  - [ ] Health check caching working (10s TTL)
  - [ ] Application data caching working
  - [ ] Cache invalidation working
  - [ ] TTL management working

---

## 🚨 ROLLBACK PLAN

If issues occur during migration:

### Immediate Rollback
- [ ] **Restore backup files**
  ```bash
  cp {service}/internal/service/health.go.backup {service}/internal/service/health.go
  cp {service}/internal/data/data.go.backup {service}/internal/data/data.go
  cp {service}/internal/config/config.go.backup {service}/internal/config/config.go
  ```

- [ ] **Revert go.mod changes**
  ```bash
  git checkout HEAD -- go.mod go.sum
  go mod tidy
  ```

- [ ] **Rebuild and redeploy**
  ```bash
  go build ./cmd/{service}
  # Redeploy to staging/production
  ```

### Partial Rollback
- [ ] **Keep successful phases**
- [ ] **Rollback problematic phases only**
- [ ] **Document issues for future fixes**

---

## 📈 SUCCESS METRICS

### Code Metrics
- [ ] **Lines of code reduced significantly**
  - [ ] Health check code: ~30-50 lines removed (enhanced functionality)
  - [ ] Database code: ~80-120 lines removed (environment overrides, pooling)
  - [ ] HTTP→gRPC migration: ~200-400 lines removed (internal service calls)
  - [ ] HTTP client code: ~150-300 lines removed (circuit breakers, retry logic)
  - [ ] Event code: ~50-80 lines removed (structured events, circuit breakers)
  - [ ] Validation code: ~100-200 lines removed (comprehensive utilities)
  - [ ] Cache code: ~50-100 lines removed (cache manager)

### Quality Metrics
- [ ] **Zero performance regression**
- [ ] **All tests passing**
- [ ] **Enhanced health checks working (4 endpoints)**
- [ ] **Circuit breakers functioning (HTTP, DB, Events)**
- [ ] **Events publishing successfully with metadata**
- [ ] **Caching operational with proper TTLs**

### Reliability Metrics
- [ ] **Circuit breaker protection active**
  - [ ] HTTP clients protected (external APIs)
  - [ ] gRPC clients protected (internal services)
  - [ ] Database connections protected
  - [ ] Event publishing protected
  - [ ] Proper failure thresholds set

- [ ] **Enhanced observability**
  - [ ] Detailed health information available
  - [ ] Circuit breaker states monitored
  - [ ] Cache performance tracked
  - [ ] Connection pool metrics available

### Operational Metrics
- [ ] **Service starts successfully**
- [ ] **Dependencies connect properly with enhanced logging**
- [ ] **Kubernetes health checks pass (all 4 endpoints)**
- [ ] **Enhanced monitoring and logging work**
- [ ] **Environment variable overrides functional**

---

## 📝 NOTES & ISSUES

**Migration Date:** ___________  
**Time Taken:** ___________  
**Issues Encountered:**
- Issue 1: ________________________________
- Issue 2: ________________________________
- Issue 3: ________________________________

**Lessons Learned:**
- Lesson 1: ________________________________
- Lesson 2: ________________________________

**Next Service to Migrate:** ___________

---

**Checklist completed by:** ___________  
**Date:** ___________  
**Service Status:** ✅ Successfully Migrated / ❌ Issues Found / 🔄 In Progress

---

## 🆕 ADDITIONAL COMMON FUNCTIONS TO CONSIDER

### gRPC Client Usage
```go
// Enhanced gRPC client usage from common/client
import "gitlab.com/ta-microservices/common/client"

// Create gRPC client factory
grpcFactory := client.NewGRPCClientFactory(logger)

// Create clients for internal services
authClient, err := grpcFactory.CreateAuthClient()
userClient, err := grpcFactory.CreateUserClient()
catalogClient, err := grpcFactory.CreateCatalogClient()

// Use gRPC client builder for custom configuration
grpcClient, err := client.NewGRPCClientBuilder("order-service:9000", logger).
    WithTimeout(15 * time.Second).
    WithRetries(5, 2*time.Second).
    WithCircuitBreaker(10, 60*time.Second).
    WithKeepAlive(30*time.Second, 5*time.Second, true).
    WithMetadata(map[string]string{
        "service-name": "my-service",
        "version":      "v1.0.0",
    }).
    Build()

// Make gRPC calls with circuit breaker protection
conn := grpcClient.GetConnection()
serviceClient := servicepb.NewServiceClient(conn)
response, err := serviceClient.Method(ctx, request)

// Health check gRPC services
poolChecker := health.NewGRPCPoolHealthChecker("grpc-services", grpcFactory, 10*time.Second)
healthManager.Register(poolChecker)
```

### Error Handling & Response
```go
// Enhanced error handling from common/errors
import "gitlab.com/ta-microservices/common/errors"

// Create structured errors
err := errors.NewValidationError("INVALID_INPUT", "Email is required", map[string]string{
    "field": "email",
    "code":  "REQUIRED",
})

// Create business logic errors
err := errors.NewBusinessError("INSUFFICIENT_BALANCE", "Account balance too low")

// Create not found errors
err := errors.NewNotFoundError("USER_NOT_FOUND", "User with ID %s not found", userID)

// Convert to HTTP response
response := errors.ToHTTPResponse(err)
```

### Middleware Enhancements
```go
// Enhanced middleware from common/middleware
import "gitlab.com/ta-microservices/common/middleware"

// Request ID middleware
router.Use(middleware.RequestID())

// Enhanced logging middleware
router.Use(middleware.LoggingWithConfig(&middleware.LoggingConfig{
    Logger:    logger,
    SkipPaths: []string{"/health", "/metrics"},
}))

// CORS with custom config
router.Use(middleware.CORSWithConfig(&middleware.CORSConfig{
    AllowOrigins:     []string{"https://yourdomain.com"},
    AllowCredentials: true,
}))

// Recovery with custom handler
router.Use(middleware.RecoveryWithConfig(&middleware.RecoveryConfig{
    Logger: logger,
}))
```

### Observability Enhancements
```go
// Enhanced observability from common/observability
import (
    "gitlab.com/ta-microservices/common/observability/metrics"
    "gitlab.com/ta-microservices/common/observability/tracing"
)

// Metrics collection
metricsCollector := metrics.NewPrometheusCollector("{service-name}")
metricsCollector.IncrementCounter("requests_total", map[string]string{
    "method": "GET",
    "status": "200",
})

// Distributed tracing
tracer := tracing.NewJaegerTracer("{service-name}", "http://jaeger:14268/api/traces")
span := tracer.StartSpan(ctx, "operation-name")
defer span.Finish()
```

### Database Utilities
```go
// Enhanced database utilities
import "gitlab.com/ta-microservices/common/utils"

// Auto-migration with extensions
err := utils.CreateExtensions(db) // Creates uuid-ossp, pg_trgm
err := utils.AutoMigrate(db, &User{}, &Product{}, &Order{})

// Transaction helper
err := utils.WithTransaction(db, func(tx *gorm.DB) error {
    // Your transactional operations
    return nil
})

// Health check with detailed info
healthStatus := utils.HealthCheck(db, rdb)
```

### Configuration Validation
```go
// Enhanced configuration validation
import "gitlab.com/ta-microservices/common/config"

validator := config.NewConfigValidator()
err := validator.
    RequireString(cfg.Database.Source, "database.source").
    RequirePositiveInt(cfg.Server.Port, "server.port").
    ValidateURL(cfg.ExternalAPI.URL, "external_api.url").
    ValidatePort(cfg.Server.Port, "server.port").
    Validate()
```

### File & Upload Utilities
```go
// File handling utilities
import "gitlab.com/ta-microservices/common/utils/file"

// File validation
isValid := file.IsValidImageType(filename)
isValid := file.IsValidFileSize(fileSize, 10*1024*1024) // 10MB

// File upload parsing
import "gitlab.com/ta-microservices/common/utils/upload_parser"

files, err := upload_parser.ParseMultipartForm(r, 32<<20) // 32MB
```

### Pagination & Filtering
```go
// Enhanced pagination
import "gitlab.com/ta-microservices/common/utils/pagination"

paginator := pagination.NewPaginator(page, limit, total)
response := pagination.PaginatedResponse{
    Data:       items,
    Pagination: paginator.GetInfo(),
}

// Query filtering
import "gitlab.com/ta-microservices/common/utils/filter"

filters := filter.ParseQueryFilters(r.URL.Query())
query := filter.ApplyFilters(db, filters)
```

---

## 🔧 TROUBLESHOOTING COMMON ISSUES

### Health Check Issues
- **Issue**: Health checks timing out
- **Solution**: Increase timeout in health checker configuration
- **Code**: `healthChecker := health.NewDatabaseHealthChecker("db", db, 10*time.Second)`

### Circuit Breaker Issues
- **Issue**: Circuit breaker opening too frequently
- **Solution**: Adjust failure threshold and recovery timeout
- **Code**: 
  ```go
  config.CircuitBreaker.FailureThreshold = 10
  config.CircuitBreaker.RecoveryTimeout = 60 * time.Second
  ```

### Cache Issues
- **Issue**: Cache not working
- **Solution**: Verify Redis connection and TTL settings
- **Code**: `cacheManager.Set(ctx, key, value, utils.MediumTTL)`

### Environment Variable Issues
- **Issue**: Environment variables not overriding config
- **Solution**: Check environment variable naming convention
- **Format**: `{SERVICE_NAME}_{CONFIG_PATH}` (e.g., `AUTH_SERVICE_DATA_DATABASE_SOURCE`)

---
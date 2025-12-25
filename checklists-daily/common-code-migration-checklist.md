# Common Code Migration Checklist

## 📋 Daily Checklist - Common Code Implementation

**Ngày:** ___________  
**Reviewer:** ___________  
**Service:** ___________  
**Status:** 🔄 In Progress / ✅ Completed / ❌ Issues Found

---

## 🎯 OVERVIEW

This checklist guides the migration of each service to use the new common code implementations. Follow this checklist for each of the 19 microservices to eliminate code duplication and standardize implementations.

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
  - Commit: 80a9b86
  - Common version: v1.2.9 → v1.3.3
  - Lines saved: ~18 added (health setup)
  - Notes: Phase 1 complete. Added health checks. Catalog/warehouse clients still HTTP (should migrate to gRPC).
- [ ] promotion-service
- [ ] fulfillment-service
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
  ```
- [ ] **Verify common module version**
  ```bash
  cd common && git log --oneline -5
  # Should show recent consolidation commits
  ```
- [ ] **Update common module dependency**
  ```bash
  cd {service} && go get gitlab.com/ta-microservices/common@latest
  go mod tidy
  ```

### Implementation Steps
- [ ] **1. Remove existing health files**
  ```bash
  rm {service}/internal/service/health.go
  # Remove any other health-related files
  ```

- [ ] **2. Update imports in HTTP server**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/observability/health"
  ```

- [ ] **3. Replace health handler creation**
  ```go
  // Replace existing health setup with:
  healthSetup := health.NewHealthSetup("{service-name}", "v1.0.0", "production", logger)
  
  // Add appropriate health checks
  healthSetup.AddDatabaseCheck("database", db)
  healthSetup.AddRedisCheck("redis", rdb)
  
  // Get handler
  healthHandler := healthSetup.GetHandler()
  ```

- [ ] **4. Register health endpoints**
  ```go
  // For Kratos HTTP server
  srv.HandleFunc("/health", healthHandler.HealthHandler)
  srv.HandleFunc("/health/ready", healthHandler.ReadinessHandler)
  srv.HandleFunc("/health/live", healthHandler.LivenessHandler)
  srv.HandleFunc("/health/detailed", healthHandler.DetailedHandler)
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
  
  # Test endpoints
  curl http://localhost:8080/health
  curl http://localhost:8080/health/ready
  curl http://localhost:8080/health/live
  curl http://localhost:8080/health/detailed
  ```

- [ ] **Verify response format**
  - [ ] `/health` returns overall health status
  - [ ] `/health/ready` returns readiness status
  - [ ] `/health/live` returns liveness status
  - [ ] `/health/detailed` returns detailed information

- [ ] **Test with dependencies down**
  - [ ] Stop database → health should be unhealthy
  - [ ] Stop Redis → health should show Redis as unhealthy
  - [ ] Restart dependencies → health should recover

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
  ```

- [ ] **Check health endpoints in cluster**
  ```bash
  kubectl port-forward svc/{service} 8080:80 -n support-services
  curl http://localhost:8080/health
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

- [ ] **Verify environment variable override**
  ```bash
  # Test DATABASE_URL override
  DATABASE_URL="postgres://test:test@localhost:5432/test" ./bin/{service} -conf ./configs
  
  # Test REDIS_ADDR override
  REDIS_ADDR="localhost:6380" ./bin/{service} -conf ./configs
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

- [ ] **2. Extend BaseAppConfig**
  ```go
  // Update service config struct to extend BaseAppConfig
  type {Service}AppConfig struct {
      *config.BaseAppConfig
      ExternalServices ExternalServicesConfig `mapstructure:"external_services" yaml:"external_services"`
      Business         BusinessConfig         `mapstructure:"business" yaml:"business"`
      // Add other service-specific fields
  }
  ```

- [ ] **3. Replace configuration loading**
  ```go
  // Replace manual Viper setup with:
  func Init(configPath string, envPrefix string) (*{Service}AppConfig, error) {
      loader := config.NewServiceConfigLoader("{service-name}", configPath)
      
      cfg := &{Service}AppConfig{
          BaseAppConfig: &config.BaseAppConfig{},
      }
      
      return cfg, loader.LoadServiceConfig(cfg)
  }
  ```

- [ ] **4. Remove duplicate Viper code**
  - [ ] Remove manual Viper initialization
  - [ ] Remove duplicate environment variable setup
  - [ ] Remove duplicate config file reading

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

## 🌐 PHASE 4: HTTP CLIENTS (HIGH PRIORITY)

> [!IMPORTANT]
> **POLICY: Prefer gRPC over HTTP for Internal Services**
> - For internal service-to-service communication, **use gRPC clients** instead of HTTP
> - HTTP clients in `common/client` should ONLY be used for:
>   - External third-party APIs (payment gateways, shipping carriers, etc.)
>   - Services that don't have gRPC support yet (legacy systems)
> - If migrating legacy HTTP client code, consider migrating to gRPC instead
> - See [http-to-grpc-migration.md](./http-to-grpc-migration.md) for gRPC migration guide

### Pre-Migration Checklist
- [ ] **Identify existing HTTP clients**
  ```bash
  find {service}/internal -name "*client*.go" -type f
  grep -r "http.Client" {service}/internal/
  ```

- [ ] **Review circuit breaker implementations**
  ```bash
  find {service}/internal -name "*circuit*" -type f
  grep -r "circuitbreaker" {service}/internal/
  ```

### Implementation Steps
- [ ] **1. Update imports**
  ```go
  // Add to imports
  import "gitlab.com/ta-microservices/common/client"
  ```

- [ ] **2. Replace HTTP client creation**
  ```go
  // Replace existing HTTP client with:
  config := client.DefaultHTTPClientConfig(baseURL)
  config.MaxRetries = 3
  config.Timeout = 30 * time.Second
  httpClient := client.NewHTTPClient(config, logger)
  ```

- [ ] **3. Update service client methods**
  ```go
  // Replace manual HTTP calls with:
  func (c *UserClient) GetUser(ctx context.Context, userID string) (*User, error) {
      var user User
      err := c.httpClient.GetJSON(ctx, fmt.Sprintf("/api/v1/users/%s", userID), &user)
      return &user, err
  }
  
  func (c *UserClient) CreateUser(ctx context.Context, user *User) error {
      return c.httpClient.PostJSON(ctx, "/api/v1/users", user, nil)
  }
  ```

- [ ] **4. Remove duplicate circuit breaker code**
  - [ ] Remove local circuit breaker implementations
  - [ ] Remove duplicate retry logic
  - [ ] Remove manual HTTP client setup

### Testing & Validation
- [ ] **Test HTTP client functionality**
  ```bash
  # Start dependent services
  # Test service-to-service communication
  ```

- [ ] **Test circuit breaker behavior**
  - [ ] Stop target service → circuit should open
  - [ ] Start target service → circuit should close
  - [ ] Verify circuit breaker metrics

- [ ] **Test retry logic**
  - [ ] Simulate network failures
  - [ ] Verify retry attempts
  - [ ] Check retry backoff

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

- [ ] **2. Replace event publisher creation**
  ```go
  // Replace existing Dapr publisher with:
  config := events.DefaultDaprEventPublisherConfig()
  config.DaprURL = "http://localhost:3500"
  config.PubsubName = "pubsub-redis"
  eventPublisher := events.NewDaprEventPublisher(config, logger)
  ```

- [ ] **3. Update event publishing calls**
  ```go
  // Replace manual event publishing with:
  event := events.UserEvent{
      BaseEvent: events.BaseEvent{
          EventType:   "user.registered",
          ServiceName: "{service-name}",
          Timestamp:   time.Now(),
      },
      UserID: user.ID,
      Action: "registered",
  }
  
  err := eventPublisher.PublishEvent(ctx, events.TopicUserRegistered, event)
  ```

- [ ] **4. Remove duplicate event code**
  - [ ] Remove manual Dapr HTTP calls
  - [ ] Remove duplicate event structures
  - [ ] Remove manual retry logic

### Testing & Validation
- [ ] **Test event publishing**
  ```bash
  # Start Dapr sidecar
  dapr run --app-id {service} --app-port 8080 --dapr-http-port 3500
  
  # Test event publishing
  # Check Dapr logs for published events
  ```

- [ ] **Verify event format**
  - [ ] Check event structure matches common format
  - [ ] Verify event metadata
  - [ ] Check event timestamps

- [ ] **Test circuit breaker for events**
  - [ ] Stop Dapr → events should fail gracefully
  - [ ] Start Dapr → events should resume

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

- [ ] **Code follows common patterns**
  - [ ] Uses common health check system
  - [ ] Uses common database utilities
  - [ ] Uses common HTTP clients
  - [ ] Uses common event publishing

### Documentation
- [ ] **Update service README**
  - [ ] Document new common code usage
  - [ ] Update setup instructions
  - [ ] Update troubleshooting guide

- [ ] **Update deployment docs**
  - [ ] Update environment variables
  - [ ] Update health check endpoints
  - [ ] Update monitoring setup

### Monitoring
- [ ] **Metrics working**
  - [ ] Health check metrics
  - [ ] Circuit breaker metrics
  - [ ] Database connection metrics
  - [ ] HTTP client metrics

- [ ] **Logging working**
  - [ ] Structured logging
  - [ ] Error logging
  - [ ] Performance logging

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
- [ ] **Lines of code reduced**
  - [ ] Health check code: ~20-30 lines removed
  - [ ] Database code: ~50-80 lines removed
  - [ ] HTTP client code: ~100-200 lines removed
  - [ ] Event code: ~30-50 lines removed

### Quality Metrics
- [ ] **Zero performance regression**
- [ ] **All tests passing**
- [ ] **Health checks working**
- [ ] **Circuit breakers functioning**
- [ ] **Events publishing successfully**

### Operational Metrics
- [ ] **Service starts successfully**
- [ ] **Dependencies connect properly**
- [ ] **Kubernetes health checks pass**
- [ ] **Monitoring and logging work**

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
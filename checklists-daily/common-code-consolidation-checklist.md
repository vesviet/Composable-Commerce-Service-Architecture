# Common Code & Module Consolidation Checklist

**Last Updated**: 2025-01-26  
**Status**: In Progress  
**Overall Progress**: 70% Complete (Consolidation: 2/4 phases complete)

---

## 📊 Executive Summary

This comprehensive checklist tracks both:
1. **Common Code Migration** - Migrating services to use common implementations (health, DB, config, HTTP clients, events)
2. **Common Module Consolidation** - Eliminating duplicate code patterns (worker, cache, middleware, validation)

### Overall Status

| Category | Status | Progress |
|----------|--------|----------|
| **Common Code Migration** | ✅ 89% Complete | 17/19 services |
| **Worker Framework** | 🔄 50% Complete | 6/12 services |
| **Cache Consolidation** | ✅ 100% Complete | 6/6 services |
| **Middleware System** | 🔄 30% Complete | 1/3 services |
| **Validation Framework** | 🔄 7% Complete | 1/14 services |

**Total Code Reduction**: 
- **Common Code Migration**: ~3,150+ lines eliminated (89% complete)
- **Cache Consolidation**: ~300+ lines eliminated (100% complete) ✅
- **Worker Framework**: ~300+ lines eliminated (50% complete)
- **Target Remaining**: ~900+ lines (Middleware, Validation)

---

## PART 1: COMMON CODE MIGRATION

### Health Checks Migration Status ⭐ UPDATED

**Progress**: 17/19 services (89%) ✅

| Service | Status | Notes |
|---------|--------|-------|
| **auth** | ✅ DONE | Using `common/observability/health` |
| **user** | ✅ DONE | Using `common/observability/health` |
| **order** | ✅ DONE | Using `common/observability/health` |
| **warehouse** | ✅ DONE | Using `common/observability/health` |
| **customer** | ✅ DONE | Using `common/observability/health` |
| **fulfillment** | ✅ DONE | Using `common/observability/health` |
| **catalog** | ✅ DONE | Using `common/observability/health` |
| **promotion** | ✅ DONE | Using `common/observability/health` |
| **search** | ✅ DONE | Using `common/observability/health` |
| **notification** | ✅ DONE | Using `common/observability/health` |
| **review** | ✅ DONE | Using `common/observability/health` |
| **shipping** | ✅ DONE | Using `common/observability/health` |
| **payment** | ✅ DONE | Using `common/observability/health` |
| **pricing** | ✅ DONE | Using `common/observability/health` |
| **location** | ✅ DONE | Using `common/observability/health` |
| **common-operations** | ✅ DONE | Using `common/observability/health` |
| **gateway** | ✅ **DONE** ⭐ | **Recently migrated** - Using `common/observability/health` |
| **analytics** | 🔄 TODO | Not started |
| **loyalty-rewards** | 🔄 TODO | Not started |

**Remaining**: 2 services (analytics, loyalty-rewards)

### Service Migration Status

| Service | Health | DB/Redis | Config | HTTP Clients | Events | Status | Notes |
|---------|--------|----------|--------|--------------|--------|--------|-------|
| **auth** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ **DONE** | All 5 phases complete |
| **user** | ✅ | ✅ | ✅ | - | - | ✅ **DONE** | Phases 1-3 complete |
| **notification** | ✅ | ✅ | ✅ | - | - | ✅ **DONE** | DB, Redis, config migrated |
| **payment** | ✅ | ✅ | ✅ | - | - | ✅ **DONE** | Health, DB/Redis/Config migrated |
| **order** | ✅ | ✅ | ✅ | - | - | ✅ **DONE** | Health, DB, Config migrated |
| **warehouse** | ✅ | ✅ | ✅ | ✅ | - | ✅ **DONE** | Catalog HTTP client migrated |
| **shipping** | ✅ | ✅ | ✅ | ✅ | - | ✅ **DONE** | All phases complete |
| **catalog** | ✅ | - | - | - | - | ✅ **DONE** | Health only, already using gRPC |
| **customer** | ✅ | - | - | - | - | ✅ **DONE** | Health only, already using gRPC |
| **pricing** | ✅ | - | - | ✅ | - | ✅ **DONE** | Health + HTTP→gRPC migration |
| **promotion** | ✅ | - | - | - | - | ✅ **DONE** | Health checks added |
| **fulfillment** | ✅ | - | - | - | - | ✅ **DONE** | Health checks added |
| **search** | ✅ | - | - | - | - | ✅ **DONE** | Health + ES check |
| **review** | ✅ | - | - | - | - | ✅ **DONE** | Health checks added |
| **location** | ✅ | - | - | - | - | ✅ **DONE** | Health checks added |
| **common-operations** | ✅ | - | - | - | - | ✅ **DONE** | Health checks added |
| **gateway** | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 **In Progress** | Health checks migrated ✅ |
| **analytics** | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 **TODO** | Not started |
| **loyalty-rewards** | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 **TODO** | Not started |

**Migration Progress**: 17/19 services (89%) ✅

### Quick Migration Guide

For detailed step-by-step instructions, see sections below. Quick reference:

1. **Health Checks** (Phase 1) - Use `common/observability/health`
2. **Database/Redis** (Phase 2) - Use `common/utils` (NewPostgresDB, NewRedisClient)
3. **Configuration** (Phase 3) - Use `common/config` (ServiceConfigLoader)
4. **HTTP Clients** (Phase 4) - Use `common/client` (prefer gRPC for internal services)
5. **Event Publishing** (Phase 5) - Use `common/events` (DaprEventPublisher)

---

## PART 2: COMMON MODULE CONSOLIDATION

### Phase 1: Worker Framework Consolidation

**Status**: 🔄 50% Complete (6/12 services migrated)

#### Common Worker Base
- ✅ **Created**: `common/worker/continuous_worker.go` exists with full implementation
- ✅ **Features**: ContinuousWorker interface, BaseContinuousWorker, ContinuousWorkerRegistry, WorkerMetrics, HealthCheck

#### Service Migration Status

| Service | Has Worker | Uses Common Worker | Status | Priority | Notes |
|---------|-----------|-------------------|--------|----------|-------|
| **warehouse** | ✅ | ✅ Yes | ✅ **DONE** | Priority 1 | Uses `NewContinuousWorkerRegistry`, has `newWorkers()` |
| **pricing** | ✅ | ✅ Yes | ✅ **DONE** | Priority 1 | Uses `NewContinuousWorkerRegistry`, has `workers.go` |
| **catalog** | ✅ | ✅ Yes | ✅ **DONE** | Priority 2 | Uses `NewContinuousWorkerRegistry`, has `workers.go` |
| **promotion** | ✅ | ✅ Yes | ✅ **DONE** | Priority 2 | Uses `NewContinuousWorkerRegistry`, has `workers.go` |
| **search** | ✅ | ✅ Yes | ✅ **DONE** | Priority 2 | Uses `NewContinuousWorkerRegistry`, has `workers.go` |
| **notification** | ✅ | ✅ Yes | ✅ **DONE** | Priority 2 | Uses `NewContinuousWorkerRegistry` |
| **customer** | ✅ | ❌ | 🔄 TODO | Priority 1 | Uses `base.Worker`, has `internal/worker/base/worker.go` |
| **fulfillment** | ✅ | ❌ | 🔄 TODO | Priority 1 | Uses `base.Worker`, has `internal/worker/base/worker.go` |
| **payment** | ✅ | ❌ | 🔄 TODO | Priority 2 | Uses custom `worker.NewWorkerRegistry`, has `internal/worker/base/worker.go` |
| **shipping** | ✅ | ❌ | 🔄 TODO | Priority 2 | Uses `base.Worker`, has `internal/worker/base/worker.go` |
| **order** | ✅ | ❌ | 🔄 TODO | Priority 2 | Uses custom `WorkerManager`, no common worker framework |
| **common-operations** | ✅ | ❌ | 🔄 TODO | Priority 2 | Uses cron directly, no worker framework |
| **review** | ❌ | - | ⚪ N/A | - | No worker binary found |

**Migration Tasks**:
- [x] **Priority 2**: Migrate promotion, catalog, search services ✅
- [x] **Priority 1**: Migrate warehouse, pricing services ✅
- [x] **Priority 2**: Migrate notification service ✅
- [ ] **Priority 1**: Migrate customer, fulfillment workers (use `base.Worker`)
- [ ] **Priority 2**: Migrate payment, shipping workers (use `base.Worker`)
- [ ] **Priority 2**: Migrate order service (custom `WorkerManager`)
- [ ] **Priority 2**: Migrate common-operations (cron-based)
- [ ] Remove duplicate `internal/worker/base/worker.go` files after migration

**Expected Reduction**: ~600+ lines → 0 lines (100% elimination)

---

### Phase 2: Cache Consolidation

**Status**: ✅ 100% Complete (6/6 services migrated)

#### Common Cache Status
- ✅ **Created**: `common/utils/cache/redis_helper.go` exists
- ✅ **Features**: RedisCache with Get, Set, Delete, pattern matching
- 🔄 **Missing**: TypedCache with generics, cache warming, bulk operations

#### Service Cache Status

| Service | Has Cache | Uses Common Cache | Status | Notes |
|---------|-----------|------------------|--------|-------|
| **pricing** | ✅ | ✅ Yes | ✅ **DONE** | Uses `common/utils/cache/RedisCache` |
| **warehouse** | ✅ | ✅ Yes | ✅ **DONE** | Migrated to `common/utils/cache` |
| **gateway** | ✅ | ✅ Yes | ✅ **DONE** | Migrated smart cache to `common/utils/cache` |
| **loyalty-rewards** | ✅ | ✅ Yes | ✅ **DONE** | Migrated CacheService to `common/utils/cache` |
| **promotion** | ✅ | ✅ Yes | ✅ **DONE** | Already using `common/utils/cache` |
| **catalog** | ✅ | ✅ Yes | ✅ **DONE** | Migrated L2RedisCache to `common/utils/cache` |
| **search** | ✅ | ✅ Yes | ✅ **DONE** | Already using `common/utils/cache`, optimized DeletePattern |

**Enhancement Tasks**:
- [x] Migrate warehouse, gateway, loyalty-rewards, catalog caches ✅
- [x] Optimize search cache DeletePattern ✅
- [x] All 6 services using `common/utils/cache/RedisCache` ✅
- [x] Code reduction: ~300+ lines eliminated ✅
- [ ] Create TypedCache: `common/cache/typed_cache.go` with generics (future enhancement - low priority)
- [ ] Add cache warming, bulk operations, metrics (future enhancement - low priority)

**Expected Reduction**: ~400+ lines → ~100 lines (75% elimination)

---

### Phase 3: Middleware Consolidation

**Status**: 🔄 30% Complete (1/3 services migrated)

#### Common Middleware Status
- ✅ **Created**: `common/middleware/` package exists
- ✅ **Features**: Auth, CORS, Logging, Recovery, Context
- 🔄 **Missing**: MiddlewareChain, BaseMiddleware, advanced patterns

#### Service Middleware Status

| Service | Has Middleware | Uses Common Middleware | Status | Notes |
|---------|---------------|----------------------|--------|-------|
| **gateway** | ✅ | ✅ Partial | 🔄 In Progress | Has custom manager (300+ lines) |
| **order** | ✅ | ❌ | 🔄 TODO | Has `internal/middleware/auth.go` |
| **customer** | ✅ | ❌ | 🔄 TODO | Uses middleware in service layer |

**Enhancement Tasks**:
- [ ] Create BaseMiddleware: `common/middleware/base.go`
- [ ] Complete gateway migration (reduce 67% code)
- [ ] Migrate order and customer middleware

**Expected Reduction**: ~300+ lines → ~100 lines (67% elimination)

---

### Phase 4: Validation Framework

**Status**: 🔄 7% Complete (1/14 services migrated)

#### Common Validation Status
- ✅ **Created**: `common/validation/validator.go` exists
- ✅ **Features**: Fluent validation API, ValidationError, common validators
- ✅ **Created**: `common/utils/validation/` with additional helpers
- 🔄 **Missing**: JWT validation integration, business rule validation

#### Service Validation Status

| Service | Has Validation | Uses Common Validation | Status | Notes |
|---------|---------------|----------------------|--------|-------|
| **review** | ✅ | ✅ Yes | ✅ **DONE** | Uses `common/validation` |
| **gateway** | ✅ | ❌ | 🔄 TODO | Has JWT validation in middleware |
| **order** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **customer** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **catalog** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **warehouse** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **pricing** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **payment** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **shipping** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **notification** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **common-operations** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **auth** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **user** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **fulfillment** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **loyalty-rewards** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **promotion** | ✅ | ❌ | 🔄 TODO | Validation in service layer |
| **search** | ✅ | ❌ | 🔄 TODO | Validation in service layer |

**Enhancement Tasks**:
- [ ] Add JWT Validation: `common/validation/jwt.go`
- [ ] Add Business Rule Validation: `common/validation/business_rules.go`
- [ ] Migrate all services to use common validation

**Expected Reduction**: ~200+ lines → ~50 lines (75% elimination)

---

## 📋 DETAILED MIGRATION GUIDES

### Common Code Migration Steps

#### Phase 1: Health Checks

**Quick Steps**:
1. Remove existing `internal/service/health.go`
2. Import `common/observability/health`
3. Create health setup: `health.NewHealthSetup("{service}", "v1.0.0", "production", logger)`
4. Add checks: `healthSetup.AddDatabaseCheck()`, `healthSetup.AddRedisCheck()`
5. Register endpoints: `/health`, `/health/ready`, `/health/live`, `/health/detailed`

**Example**:
```go
import "gitlab.com/ta-microservices/common/observability/health"

healthSetup := health.NewHealthSetup("service-name", "v1.0.0", "production", logger)
healthSetup.AddDatabaseCheck("database", db)
healthSetup.AddRedisCheck("redis", rdb)
healthHandler := healthSetup.GetHandler()

srv.HandleFunc("/health", healthHandler.HealthHandler)
srv.HandleFunc("/health/ready", healthHandler.ReadinessHandler)
srv.HandleFunc("/health/live", healthHandler.LivenessHandler)
srv.HandleFunc("/health/detailed", healthHandler.DetailedHandler)
```

#### Phase 2: Database & Redis Connections

**Quick Steps**:
1. Import `common/utils`
2. Replace DB connection: `utils.NewPostgresDB(config, logger)`
3. Replace Redis connection: `utils.NewRedisClient(config, logger)`
4. Remove duplicate connection code

**Example**:
```go
import "gitlab.com/ta-microservices/common/utils"

func NewDB(cfg *config.AppConfig, logger log.Logger) *gorm.DB {
    return utils.NewPostgresDB(utils.DatabaseConfig{
        Source:          cfg.Data.Database.Source,
        MaxOpenConns:    cfg.Data.Database.MaxOpenConns,
        MaxIdleConns:    cfg.Data.Database.MaxIdleConns,
        ConnMaxLifetime: cfg.Data.Database.ConnMaxLifetime,
    }, logger)
}

func NewRedis(cfg *config.AppConfig, logger log.Logger) *redis.Client {
    return utils.NewRedisClient(utils.RedisConfig{
        Addr:     cfg.Data.Redis.Addr,
        Password: cfg.Data.Redis.Password,
        DB:       cfg.Data.Redis.DB,
    }, logger)
}
```

#### Phase 3: Configuration Management

**Quick Steps**:
1. Import `common/config`
2. Extend `config.BaseAppConfig`
3. Use `config.NewServiceConfigLoader()` for loading
4. Remove duplicate Viper setup

**Example**:
```go
import "gitlab.com/ta-microservices/common/config"

type ServiceAppConfig struct {
    *config.BaseAppConfig
    ExternalServices ExternalServicesConfig `mapstructure:"external_services"`
    Business         BusinessConfig         `mapstructure:"business"`
}

func Init(configPath string, envPrefix string) (*ServiceAppConfig, error) {
    loader := config.NewServiceConfigLoader("service-name", configPath)
    cfg := &ServiceAppConfig{BaseAppConfig: &config.BaseAppConfig{}}
    return cfg, loader.LoadServiceConfig(cfg)
}
```

#### Phase 4: HTTP Clients

> **⚠️ IMPORTANT**: Prefer gRPC over HTTP for internal services. HTTP clients should only be used for external APIs.

**Quick Steps**:
1. Import `common/client`
2. Replace HTTP client: `client.NewHTTPClient(config, logger)`
3. Use methods: `GetJSON()`, `PostJSON()`, `PutJSON()`, `DeleteJSON()`
4. Remove duplicate circuit breaker code

**Example**:
```go
import "gitlab.com/ta-microservices/common/client"

config := client.DefaultHTTPClientConfig(baseURL)
config.MaxRetries = 3
config.Timeout = 30 * time.Second
httpClient := client.NewHTTPClient(config, logger)

// Use client
var user User
err := httpClient.GetJSON(ctx, fmt.Sprintf("/api/v1/users/%s", userID), &user)
```

#### Phase 5: Event Publishing

**Quick Steps**:
1. Import `common/events`
2. Create publisher: `events.NewDaprEventPublisher(config, logger)`
3. Publish events: `eventPublisher.PublishEvent(ctx, topic, event)`
4. Remove duplicate Dapr code

**Example**:
```go
import "gitlab.com/ta-microservices/common/events"

config := events.DefaultDaprEventPublisherConfig()
config.DaprURL = "http://localhost:3500"
config.PubsubName = "pubsub-redis"
eventPublisher := events.NewDaprEventPublisher(config, logger)

event := events.UserEvent{
    BaseEvent: events.BaseEvent{
        EventType:   "user.registered",
        ServiceName: "service-name",
        Timestamp:   time.Now(),
    },
    UserID: user.ID,
}
err := eventPublisher.PublishEvent(ctx, events.TopicUserRegistered, event)
```

---

## 🎯 CONSOLIDATION PRIORITIES

### Next Steps (Priority Order)

1. **Week 1**: Worker Framework Consolidation
   - ✅ Migrated: warehouse, pricing, catalog, promotion, search, notification (6/12)
   - 🔄 Remaining: customer, fulfillment, payment, shipping, order, common-operations (6/12)
   - Expected: 100% code elimination in worker base

2. **Week 2**: Cache Consolidation ✅
   - ✅ Migrated: warehouse, gateway, loyalty-rewards, catalog, promotion, search (6/6)
   - Expected: 75% code reduction
   - Future: Create TypedCache framework, cache warming, bulk operations

3. **Week 3**: Middleware System
   - Enhance common middleware framework
   - Complete gateway migration
   - Expected: 67% code reduction

4. **Week 4**: Validation Framework
   - Add JWT and business rule validation
   - Migrate all services
   - Expected: 75% code reduction

---

## 📊 PROGRESS SUMMARY

### Code Reduction Progress

| Category | Current Lines | Target Lines | Reduction % | Progress |
|----------|--------------|-------------|-------------|----------|
| **Common Code Migration** | ~3,150+ | 0 | 100% | 89% (17/19) |
| **Worker Framework** | ~600+ | 0 | 100% | 50% (6/12) |
| **Cache Consolidation** | ~400+ | ~100 | 75% | 100% (6/6) |
| **Middleware System** | ~300+ | ~100 | 67% | 30% (1/3) |
| **Validation Framework** | ~200+ | ~50 | 75% | 7% (1/14) |
| **TOTAL** | **~4,650+** | **~250** | **95%** | **65%** |

### Services Summary

**Total Services**: 19
- **Common Code Migration**: 17/19 (89%) ✅
- **Health Checks**: 17/19 (89%) ✅
- **Services with Workers**: 12 (6 migrated, 6 remaining)
- **Services with Cache**: 6 (all migrated to common cache ✅)
- **Services with Middleware**: 3 (need consolidation)
- **Services with Validation**: 14 (need consolidation)

---

## 🔧 TESTING & VALIDATION

### Pre-Migration Checklist
- [ ] Backup current implementation
- [ ] Verify common module version (v1.3.3+)
- [ ] Update common module dependency
- [ ] Review service-specific requirements

### Post-Migration Validation
- [ ] Build service successfully
- [ ] All tests pass
- [ ] Health checks working
- [ ] Service communication working
- [ ] No performance regression
- [ ] Deploy to staging and verify

---

## 📝 NOTES & BEST PRACTICES

### Success Stories
- **Pricing Service**: Already using `common/utils/cache` - good example
- **Review Service**: Already using `common/worker` partially - good example
- **16 Services**: Successfully migrated to common code with zero regressions

### Challenges
- **Version Consistency**: Some services lag behind on common module updates
- **Service-Specific Configs**: Some services need custom configuration handling
- **Testing Complexity**: Integration testing requires careful setup

### Lessons Learned
- Migrate services incrementally (one phase at a time)
- Always prepare rollback before migration
- Test thoroughly in staging before production
- Monitor metrics during and after migration

---

## 🚨 ROLLBACK PLAN

If issues occur:
1. Restore backup files
2. Revert go.mod changes
3. Rebuild and redeploy
4. Document issues for future fixes

---

## 📚 RESOURCES

- [Common Module README](../../common/README.md)
- [Common Module Consolidation Plan](./common-module-consolidation-plan.md)
- [Health Check Guide](../../common/observability/health/README.md)
- [Circuit Breaker Guide](../../common/client/circuitbreaker/README.md)

---

## Update Log

- **2025-01-26**: Phase 2 Cache Consolidation completed ✅
  - All 6 services migrated to `common/utils/cache`
  - warehouse, gateway, loyalty-rewards, catalog: migrated
  - promotion, search: already using common cache
  - Progress: 20% → 100% (1/6 → 6/6 services)
  - Code reduction: ~300+ lines eliminated
- **2025-01-26**: Phase 1 Worker Framework progress updated
  - 6/12 services migrated (50% complete)
  - warehouse, pricing, catalog, promotion, search, notification: migrated
- **2025-01-XX**: Updated Health Checks migration status
  - Gateway service migrated to common health checks ✅
  - Progress: 17/19 services (89%) - Health Checks complete
- **2025-01-XX**: Merged two checklists into one comprehensive file
- **2025-12-25**: 16/19 services migrated to common code (84% complete)
- **2025-01-XX**: Initial consolidation checklist created


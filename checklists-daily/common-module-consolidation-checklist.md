# Common Module Consolidation Checklist

**Last Updated**: 2025-01-XX  
**Status**: In Progress

## Executive Summary

This checklist tracks the consolidation progress across all services based on the [Common Module Consolidation Plan](./common-module-consolidation-plan.md).

**Overall Progress**: 
- ✅ **Phase 1 (Worker Framework)**: 20% Complete
- 🔄 **Phase 2 (Cache Consolidation)**: 40% Complete  
- 🔄 **Phase 3 (Middleware System)**: 30% Complete
- 🔄 **Phase 4 (Validation Framework)**: 50% Complete

---

## Phase 1: Worker Framework Consolidation

### Common Worker Base Status
- ✅ **Created**: `common/worker/base_worker.go` exists with full implementation
- ✅ **Features**: BaseWorker, WorkerRegistry, WorkerMetrics, HealthCheck
- ✅ **Documentation**: Code is well-documented

### Service Migration Status

| Service | Has Worker | Uses Common Worker | Migration Status | Notes |
|---------|-----------|-------------------|------------------|-------|
| **customer** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/worker/base/worker.go` (duplicate) |
| **pricing** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/worker/base/worker.go` (duplicate) |
| **warehouse** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/worker/base/worker.go` (duplicate) |
| **fulfillment** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/worker/base/worker.go` (duplicate) |
| **payment** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/worker/base/worker.go` (enhanced version) |
| **shipping** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/worker/base/worker.go` (duplicate) |
| **notification** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/worker/base/worker.go` (duplicate) |
| **review** | ✅ Yes | ✅ **Partial** | 🔄 **In Progress** | Uses `common/worker` in some workers |
| **order** | ✅ Yes | ❌ No | 🔄 **TODO** | Uses custom worker implementation |
| **catalog** | ✅ Yes | ❌ No | 🔄 **TODO** | Uses custom worker implementation |
| **common-operations** | ✅ Yes | ❌ No | 🔄 **TODO** | Uses custom worker implementation |
| **analytics** | ❌ No | N/A | ✅ **N/A** | No workers |
| **auth** | ❌ No | N/A | ✅ **N/A** | No workers |
| **user** | ❌ No | N/A | ✅ **N/A** | No workers |
| **gateway** | ❌ No | N/A | ✅ **N/A** | No workers |
| **location** | ❌ No | N/A | ✅ **N/A** | No workers |
| **loyalty-rewards** | ❌ No | N/A | ✅ **N/A** | No workers |
| **promotion** | ❌ No | N/A | ✅ **N/A** | No workers |
| **search** | ❌ No | N/A | ✅ **N/A** | No workers |

### Migration Tasks

#### Priority 1: High Duplication Services
- [ ] **customer**: Migrate 3 workers to `common/worker`
  - [ ] Remove `customer/internal/worker/base/worker.go`
  - [ ] Update `customer/cmd/worker/main.go` to use `common/worker`
  - [ ] Test all 3 workers (stats, segment_evaluator, cleanup)
  
- [ ] **pricing**: Migrate workers to `common/worker`
  - [ ] Remove `pricing/internal/worker/base/worker.go`
  - [ ] Update `pricing/cmd/worker/main.go` to use `common/worker`
  - [ ] Test workers

- [ ] **warehouse**: Migrate 5+ workers to `common/worker`
  - [ ] Remove `warehouse/internal/worker/base/worker.go`
  - [ ] Update `warehouse/cmd/worker/main.go` to use `common/worker`
  - [ ] Test all workers (stock_change_detector, expiry, cron jobs)

- [ ] **fulfillment**: Migrate workers to `common/worker`
  - [ ] Remove `fulfillment/internal/worker/base/worker.go`
  - [ ] Update `fulfillment/cmd/worker/main.go` to use `common/worker`
  - [ ] Test workers

#### Priority 2: Other Services
- [ ] **payment**: Migrate workers (has enhanced base worker)
  - [ ] Review `payment/internal/worker/base/worker.go` features
  - [ ] Migrate enhanced features to `common/worker` if needed
  - [ ] Update payment workers to use `common/worker`

- [ ] **shipping**: Migrate workers
- [ ] **notification**: Migrate workers
- [ ] **review**: Complete migration (already partial)
- [ ] **order**: Migrate to `common/worker`
- [ ] **catalog**: Migrate to `common/worker`
- [ ] **common-operations**: Migrate to `common/worker`

### Expected Reduction
- **Current**: ~600+ lines of duplicate worker base code
- **Target**: 0 lines (100% elimination)
- **Progress**: 0% (0/11 services migrated)

---

## Phase 2: Cache Consolidation

### Common Cache Status
- ✅ **Created**: `common/utils/cache/redis_helper.go` exists
- ✅ **Features**: RedisCache with Get, Set, Delete, pattern matching
- 🔄 **Missing**: TypedCache with generics (as per plan)
- 🔄 **Missing**: Cache warming, bulk operations, advanced metrics

### Service Cache Status

| Service | Has Cache | Uses Common Cache | Migration Status | Notes |
|---------|-----------|------------------|------------------|-------|
| **pricing** | ✅ Yes | ✅ **Yes** | ✅ **DONE** | Uses `common/utils/cache/RedisCache` |
| **warehouse** | ✅ Yes | ❌ No | 🔄 **TODO** | Has custom cache implementation |
| **gateway** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/middleware/smart_cache.go` |
| **loyalty-rewards** | ✅ Yes | ❌ No | 🔄 **TODO** | Has multiple cache files (tier, reward, account) |
| **promotion** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/cache/promotion_cache.go` |
| **catalog** | ✅ Yes | ❌ No | 🔄 **TODO** | Has cache in service layer |
| **search** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/cache/cache.go` |
| **customer** | ❌ No | N/A | ✅ **N/A** | No cache |
| **order** | ❌ No | N/A | ✅ **N/A** | No cache |
| **payment** | ❌ No | N/A | ✅ **N/A** | No cache |
| **shipping** | ❌ No | N/A | ✅ **N/A** | No cache |
| **notification** | ❌ No | N/A | ✅ **N/A** | No cache |
| **review** | ❌ No | N/A | ✅ **N/A** | No cache |
| **common-operations** | ❌ No | N/A | ✅ **N/A** | No cache |
| **analytics** | ❌ No | N/A | ✅ **N/A** | No cache |
| **auth** | ❌ No | N/A | ✅ **N/A** | No cache |
| **user** | ❌ No | N/A | ✅ **N/A** | No cache |
| **fulfillment** | ❌ No | N/A | ✅ **N/A** | No cache |
| **location** | ❌ No | N/A | ✅ **N/A** | No cache |

### Enhancement Tasks

#### Common Cache Framework
- [ ] **Create TypedCache**: `common/cache/typed_cache.go`
  - [ ] Generic type support: `TypedCache[T any]`
  - [ ] Type-safe Get/Set methods
  - [ ] Bulk operations (GetMulti, SetMulti)
  - [ ] Pattern-based invalidation
  - [ ] Cache warming support
  - [ ] Health checks and metrics

#### Service Migration Tasks
- [ ] **warehouse**: Migrate to common cache
  - [ ] Review `warehouse/internal/data/redis/warehouse_cache.go`
  - [ ] Migrate to `common/utils/cache` or `common/cache/typed_cache`
  - [ ] Test cache operations

- [ ] **gateway**: Migrate smart cache
  - [ ] Review `gateway/internal/middleware/smart_cache.go`
  - [ ] Extract reusable patterns to common
  - [ ] Migrate gateway to use common cache

- [ ] **loyalty-rewards**: Migrate multiple caches
  - [ ] Review `loyalty-rewards/internal/cache/*.go`
  - [ ] Consolidate to use common cache
  - [ ] Test all cache operations

- [ ] **promotion**: Migrate cache
- [ ] **catalog**: Migrate cache
- [ ] **search**: Migrate cache

### Expected Reduction
- **Current**: ~400+ lines of duplicate cache code
- **Target**: ~100 lines (75% elimination)
- **Progress**: 20% (1/6 services migrated - pricing only)

---

## Phase 3: Middleware Consolidation

### Common Middleware Status
- ✅ **Created**: `common/middleware/` package exists
- ✅ **Features**: Auth, CORS, Logging, Recovery, Context
- 🔄 **Missing**: MiddlewareChain, BaseMiddleware, advanced patterns
- 🔄 **Missing**: Reusable middleware framework (as per plan)

### Service Middleware Status

| Service | Has Middleware | Uses Common Middleware | Migration Status | Notes |
|---------|---------------|----------------------|------------------|-------|
| **gateway** | ✅ Yes | ✅ **Partial** | 🔄 **In Progress** | Uses some common middleware, has custom manager |
| **order** | ✅ Yes | ❌ No | 🔄 **TODO** | Has `internal/middleware/auth.go` |
| **customer** | ✅ Yes | ❌ No | 🔄 **TODO** | Uses middleware in service layer |
| **catalog** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **warehouse** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **pricing** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **payment** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **shipping** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **notification** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **review** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **common-operations** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **analytics** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **auth** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **user** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **fulfillment** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **location** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **loyalty-rewards** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **promotion** | ❌ No | N/A | ✅ **N/A** | No custom middleware |
| **search** | ❌ No | N/A | ✅ **N/A** | No custom middleware |

### Enhancement Tasks

#### Common Middleware Framework
- [ ] **Create BaseMiddleware**: `common/middleware/base.go`
  - [ ] MiddlewareConfig struct
  - [ ] BaseMiddleware with common functionality
  - [ ] MiddlewareChain for managing middleware chains
  - [ ] Caching support for middleware chains

- [ ] **Enhance Existing Middleware**
  - [ ] Improve CORS middleware
  - [ ] Enhance Auth middleware
  - [ ] Add metrics middleware
  - [ ] Add rate limiting middleware

#### Service Migration Tasks
- [ ] **gateway**: Complete migration
  - [ ] Review `gateway/internal/middleware/manager.go` (300+ lines)
  - [ ] Extract reusable patterns to common
  - [ ] Migrate gateway to use common middleware framework
  - [ ] Reduce gateway middleware code by 67%

- [ ] **order**: Migrate auth middleware
  - [ ] Review `order/internal/middleware/auth.go`
  - [ ] Migrate to use `common/middleware/auth.go`
  - [ ] Test authentication

- [ ] **customer**: Migrate middleware patterns

### Expected Reduction
- **Current**: ~300+ lines of duplicate middleware code
- **Target**: ~100 lines (67% elimination)
- **Progress**: 30% (gateway partially migrated)

---

## Phase 4: Validation Framework

### Common Validation Status
- ✅ **Created**: `common/validation/validator.go` exists
- ✅ **Features**: Fluent validation API, ValidationError, common validators
- ✅ **Created**: `common/utils/validation/` with additional helpers
- 🔄 **Missing**: JWT validation integration
- 🔄 **Missing**: Business rule validation framework

### Service Validation Status

| Service | Has Validation | Uses Common Validation | Migration Status | Notes |
|---------|---------------|----------------------|------------------|-------|
| **review** | ✅ Yes | ✅ **Yes** | ✅ **DONE** | Uses `common/validation` in `internal/biz/review/validation.go` |
| **search** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in `internal/biz/search.go` |
| **gateway** | ✅ Yes | ❌ No | 🔄 **TODO** | Has JWT validation in middleware |
| **order** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **customer** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **catalog** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **warehouse** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **pricing** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **payment** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **shipping** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **notification** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **common-operations** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **analytics** | ❌ No | N/A | ✅ **N/A** | No validation |
| **auth** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **user** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **fulfillment** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **location** | ❌ No | N/A | ✅ **N/A** | No validation |
| **loyalty-rewards** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |
| **promotion** | ✅ Yes | ❌ No | 🔄 **TODO** | Has validation in service layer |

### Enhancement Tasks

#### Common Validation Framework
- [ ] **Add JWT Validation**: `common/validation/jwt.go`
  - [ ] JWT token validation with caching
  - [ ] User context extraction
  - [ ] Integration with `common/middleware/auth.go`

- [ ] **Add Business Rule Validation**: `common/validation/business_rules.go`
  - [ ] BusinessRule interface
  - [ ] Rule engine
  - [ ] Rule chaining

#### Service Migration Tasks
- [ ] **gateway**: Migrate JWT validation
  - [ ] Extract JWT validation from middleware
  - [ ] Use `common/validation` for JWT validation
  - [ ] Test authentication flow

- [ ] **order**: Migrate validation
- [ ] **customer**: Migrate validation
- [ ] **catalog**: Migrate validation
- [ ] **warehouse**: Migrate validation
- [ ] **pricing**: Migrate validation
- [ ] **payment**: Migrate validation
- [ ] **shipping**: Migrate validation
- [ ] **notification**: Migrate validation
- [ ] **common-operations**: Migrate validation
- [ ] **auth**: Migrate validation
- [ ] **user**: Migrate validation
- [ ] **fulfillment**: Migrate validation
- [ ] **loyalty-rewards**: Migrate validation
- [ ] **promotion**: Migrate validation
- [ ] **search**: Migrate validation

### Expected Reduction
- **Current**: ~200+ lines of duplicate validation code
- **Target**: ~50 lines (75% elimination)
- **Progress**: 7% (1/14 services migrated - review only)

---

## Overall Progress Summary

### Code Reduction Progress

| Phase | Current Lines | Target Lines | Reduction % | Progress |
|-------|--------------|-------------|-------------|----------|
| **Phase 1: Worker Framework** | ~600+ | 0 | 100% | 0% (0/11) |
| **Phase 2: Cache Consolidation** | ~400+ | ~100 | 75% | 20% (1/6) |
| **Phase 3: Middleware System** | ~300+ | ~100 | 67% | 30% (1/3) |
| **Phase 4: Validation Framework** | ~200+ | ~50 | 75% | 7% (1/14) |
| **TOTAL** | **~1,500+** | **~250** | **83%** | **14%** |

### Services Summary

**Total Services**: 19
- **Services with Workers**: 11
- **Services with Cache**: 6
- **Services with Middleware**: 3
- **Services with Validation**: 14

### Next Steps (Priority Order)

1. **Week 1**: Complete Phase 1 (Worker Framework)
   - Migrate customer, pricing, warehouse workers
   - Expected: 100% code elimination in worker base

2. **Week 2**: Complete Phase 2 (Cache Consolidation)
   - Create TypedCache framework
   - Migrate warehouse, gateway, loyalty-rewards caches
   - Expected: 75% code reduction

3. **Week 3**: Complete Phase 3 (Middleware System)
   - Enhance common middleware framework
   - Complete gateway migration
   - Expected: 67% code reduction

4. **Week 4**: Complete Phase 4 (Validation Framework)
   - Add JWT and business rule validation
   - Migrate all services
   - Expected: 75% code reduction

---

## Notes

- **Review Service**: Already using `common/worker` partially - good example to follow
- **Pricing Service**: Already using `common/utils/cache` - good example to follow
- **Gateway**: Partially using common middleware - needs completion
- **Payment Service**: Has enhanced worker base - consider migrating enhancements to common

---

## Update Log

- **2025-01-XX**: Initial checklist created
- Review all services and document current status
- Identify migration priorities


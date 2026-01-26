# Common Module Consolidation Plan

## Executive Summary

Based on comprehensive audit of the codebase, I've identified **4 major consolidation opportunities** that can eliminate **60-80% code duplication** across services and significantly improve maintainability.

**Current Status**: 
- ✅ **gRPC Client**: Implemented (75% code reduction possible)
- ✅ **HTTP Client**: Already consolidated
- 🔄 **Worker Framework**: 100% duplicate code across 3+ services
- 🔄 **Middleware System**: Extensive duplication in gateway
- 🔄 **Cache Implementations**: Multiple Redis cache patterns
- 🔄 **Validation Patterns**: Scattered validation logic

## Phase 1: Worker Framework Consolidation (Week 1)

### Problem Analysis
**100% duplicate code** found across services:
- `customer/internal/worker/base/worker.go` (identical)
- `pricing/internal/worker/base/worker.go` (identical) 
- `warehouse/internal/worker/base/worker.go` (identical)

**Impact**: 3 services × 50+ lines = 150+ lines of duplicate code

### Solution: Common Worker Framework

#### 1.1 Create Common Worker Base
```go
// common/worker/base.go
package worker

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
)

// Worker interface defines the contract for all workers
type Worker interface {
	Start(ctx context.Context) error
	Stop() error
	Name() string
	Health() HealthStatus
}

// BaseWorker provides common functionality for all workers
type BaseWorker struct {
	name        string
	stopChan    chan struct{}
	log         *log.Helper
	startTime   time.Time
	healthCheck func() error
}

// WorkerConfig holds worker configuration
type WorkerConfig struct {
	Name            string
	HealthCheckFunc func() error
	GracefulTimeout time.Duration
}

// NewBaseWorker creates a new base worker with enhanced features
func NewBaseWorker(config WorkerConfig, logger log.Logger) *BaseWorker {
	return &BaseWorker{
		name:        config.Name,
		stopChan:    make(chan struct{}),
		log:         log.NewHelper(logger),
		healthCheck: config.HealthCheckFunc,
	}
}

// Enhanced methods with health checks, metrics, graceful shutdown
func (w *BaseWorker) Start(ctx context.Context) error {
	w.startTime = time.Now()
	w.log.Info("Worker starting", "name", w.name)
	return nil
}

func (w *BaseWorker) Health() HealthStatus {
	if w.healthCheck != nil {
		if err := w.healthCheck(); err != nil {
			return HealthStatus{Status: "unhealthy", Error: err.Error()}
		}
	}
	return HealthStatus{
		Status:  "healthy",
		Uptime:  time.Since(w.startTime),
		Started: w.startTime,
	}
}

type HealthStatus struct {
	Status  string        `json:"status"`
	Uptime  time.Duration `json:"uptime"`
	Started time.Time     `json:"started"`
	Error   string        `json:"error,omitempty"`
}
```

#### 1.2 Create Worker Manager
```go
// common/worker/manager.go
package worker

import (
	"context"
	"sync"

	"github.com/go-kratos/kratos/v2/log"
)

// WorkerManager manages multiple workers with health monitoring
type WorkerManager struct {
	workers []Worker
	logger  *log.Helper
	mu      sync.RWMutex
}

func NewWorkerManager(logger log.Logger) *WorkerManager {
	return &WorkerManager{
		workers: make([]Worker, 0),
		logger:  log.NewHelper(logger),
	}
}

func (wm *WorkerManager) AddWorker(worker Worker) {
	wm.mu.Lock()
	defer wm.mu.Unlock()
	wm.workers = append(wm.workers, worker)
}

func (wm *WorkerManager) StartAll(ctx context.Context) error {
	// Start all workers with error handling and monitoring
}

func (wm *WorkerManager) StopAll() error {
	// Graceful shutdown of all workers
}

func (wm *WorkerManager) HealthCheck() map[string]HealthStatus {
	// Return health status of all workers
}
```

#### 1.3 Migration Steps
1. **Create** `common/worker/` package
2. **Migrate** customer service workers (3 workers)
3. **Migrate** pricing service workers (3 workers)  
4. **Migrate** warehouse service workers (5 workers)
5. **Remove** duplicate base worker files

**Expected Reduction**: 150+ lines → 0 lines (100% elimination)

## Phase 2: Cache Consolidation (Week 2)

### Problem Analysis
**Multiple cache implementations** with similar patterns:
- `pricing/internal/cache/price_cache.go` (Redis cache with TTL)
- `gateway/internal/middleware/smart_cache.go` (HTTP cache)
- `warehouse/internal/data/redis/warehouse_cache.go` (Warehouse cache)
- `common/utils/cache/redis_helper.go` (Generic helper - good base)

**Impact**: 4 different cache patterns × 100+ lines = 400+ lines

### Solution: Enhanced Common Cache Framework

#### 2.1 Extend Common Cache
```go
// common/cache/typed_cache.go
package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/go-kratos/kratos/v2/log"
)

// TypedCache provides type-safe caching with patterns
type TypedCache[T any] struct {
	redis  *redis.Client
	prefix string
	ttl    time.Duration
	logger *log.Helper
}

// CacheConfig holds cache configuration
type CacheConfig struct {
	Prefix    string
	DefaultTTL time.Duration
	MaxEntries int
	MaxMemoryMB int
}

func NewTypedCache[T any](redis *redis.Client, config CacheConfig, logger log.Logger) *TypedCache[T] {
	return &TypedCache[T]{
		redis:  redis,
		prefix: config.Prefix,
		ttl:    config.DefaultTTL,
		logger: log.NewHelper(logger),
	}
}

// Enhanced methods with pattern support, bulk operations, metrics
func (c *TypedCache[T]) Get(ctx context.Context, key string) (*T, error) {
	// Implementation with metrics, error handling
}

func (c *TypedCache[T]) Set(ctx context.Context, key string, value *T, ttl ...time.Duration) error {
	// Implementation with TTL override
}

func (c *TypedCache[T]) GetMulti(ctx context.Context, keys []string) (map[string]*T, error) {
	// Bulk get operation
}

func (c *TypedCache[T]) InvalidatePattern(ctx context.Context, pattern string) error {
	// Pattern-based invalidation
}

// Cache warming, health checks, metrics
func (c *TypedCache[T]) WarmCache(ctx context.Context, loader func(ctx context.Context) (map[string]*T, error)) error {
	// Cache warming implementation
}
```

#### 2.2 Service-Specific Cache Implementations
```go
// pricing/internal/cache/price_cache.go (AFTER)
package cache

import (
	"context"
	"fmt"

	commonCache "gitlab.com/ta-microservices/common/cache"
	"gitlab.com/ta-microservices/pricing/internal/model"
)

// PriceCache uses common typed cache
type PriceCache struct {
	productCache   *commonCache.TypedCache[model.Price]
	skuCache       *commonCache.TypedCache[model.Price]
	calculationCache *commonCache.TypedCache[PriceCalculationResponse]
}

func NewPriceCache(redis *redis.Client, logger log.Logger) *PriceCache {
	return &PriceCache{
		productCache: commonCache.NewTypedCache[model.Price](redis, commonCache.CacheConfig{
			Prefix:     "prices:product:",
			DefaultTTL: constants.CacheTTLPrice,
		}, logger),
		skuCache: commonCache.NewTypedCache[model.Price](redis, commonCache.CacheConfig{
			Prefix:     "prices:sku:",
			DefaultTTL: constants.CacheTTLPrice,
		}, logger),
		calculationCache: commonCache.NewTypedCache[PriceCalculationResponse](redis, commonCache.CacheConfig{
			Prefix:     "prices:calculation:",
			DefaultTTL: constants.CacheTTLCalculation,
		}, logger),
	}
}

// Simplified methods using common cache
func (c *PriceCache) GetProductPrice(ctx context.Context, productID, currency string) (*model.Price, error) {
	key := fmt.Sprintf("%s:%s", productID, currency)
	return c.productCache.Get(ctx, key)
}

// 80% code reduction: 200+ lines → 40 lines
```

#### 2.3 Migration Steps
1. **Enhance** `common/cache/` with typed cache
2. **Migrate** pricing cache (200+ lines → 40 lines)
3. **Migrate** warehouse cache (150+ lines → 30 lines)
4. **Migrate** gateway cache patterns
5. **Add** cache monitoring and metrics

**Expected Reduction**: 400+ lines → 100 lines (75% elimination)

## Phase 3: Middleware Consolidation (Week 3)

### Problem Analysis
**Gateway middleware system** has extensive implementations:
- `gateway/internal/middleware/manager.go` (300+ lines)
- Multiple middleware files with similar patterns
- No reuse across services

**Opportunity**: Create reusable middleware framework

### Solution: Common Middleware Framework

#### 3.1 Create Common Middleware Base
```go
// common/middleware/base.go
package middleware

import (
	"net/http"
	"time"

	"github.com/go-kratos/kratos/v2/log"
)

// MiddlewareConfig holds common middleware configuration
type MiddlewareConfig struct {
	Enabled bool
	Timeout time.Duration
	Logger  log.Logger
}

// BaseMiddleware provides common middleware functionality
type BaseMiddleware struct {
	config MiddlewareConfig
	logger *log.Helper
}

// MiddlewareChain manages middleware chains with caching
type MiddlewareChain struct {
	middlewares []func(http.Handler) http.Handler
	cache       map[string]func(http.Handler) http.Handler
	mu          sync.RWMutex
}

// Common middleware implementations: CORS, Auth, Logging, Metrics
func CORSMiddleware(config CORSConfig) func(http.Handler) http.Handler {
	// Reusable CORS implementation
}

func AuthMiddleware(config AuthConfig) func(http.Handler) http.Handler {
	// Reusable auth implementation
}

func LoggingMiddleware(logger log.Logger) func(http.Handler) http.Handler {
	// Reusable logging implementation
}
```

#### 3.2 Migration Steps
1. **Extract** common middleware patterns from gateway
2. **Create** `common/middleware/` package
3. **Migrate** gateway to use common middleware
4. **Enable** other services to use middleware framework

**Expected Reduction**: 300+ lines → 100 lines (67% elimination)

## Phase 4: Validation Framework (Week 4)

### Problem Analysis
**Scattered validation logic** across services:
- JWT token validation in multiple places
- Request validation patterns
- Business rule validation

### Solution: Common Validation Framework

#### 4.1 Create Validation Framework
```go
// common/validation/validator.go
package validation

import (
	"context"
	"fmt"

	"github.com/go-playground/validator/v10"
	"github.com/go-kratos/kratos/v2/log"
)

// Validator provides common validation functionality
type Validator struct {
	validate *validator.Validate
	logger   *log.Helper
}

// ValidationRule defines custom validation rules
type ValidationRule struct {
	Tag      string
	Func     validator.Func
	Message  string
}

// Common validation methods
func (v *Validator) ValidateStruct(ctx context.Context, s interface{}) error {
	// Struct validation with context
}

func (v *Validator) ValidateJWT(ctx context.Context, token string, config JWTConfig) (*UserContext, error) {
	// JWT validation with caching
}

func (v *Validator) ValidateBusinessRules(ctx context.Context, entity interface{}, rules []BusinessRule) error {
	// Business rule validation
}
```

#### 4.2 Migration Steps
1. **Create** `common/validation/` package
2. **Migrate** JWT validation from gateway
3. **Migrate** request validation patterns
4. **Add** business rule validation framework

**Expected Reduction**: 200+ lines → 50 lines (75% elimination)

## Implementation Timeline

### Week 1: Worker Framework
- **Day 1-2**: Create common worker framework
- **Day 3**: Migrate customer service
- **Day 4**: Migrate pricing service  
- **Day 5**: Migrate warehouse service

### Week 2: Cache Consolidation
- **Day 1-2**: Enhance common cache framework
- **Day 3**: Migrate pricing cache
- **Day 4**: Migrate warehouse cache
- **Day 5**: Add cache monitoring

### Week 3: Middleware Framework
- **Day 1-2**: Create common middleware framework
- **Day 3-4**: Migrate gateway middleware
- **Day 5**: Enable for other services

### Week 4: Validation Framework
- **Day 1-2**: Create validation framework
- **Day 3-4**: Migrate validation logic
- **Day 5**: Add business rule validation

## Success Metrics

### Code Reduction Targets
- **Worker Framework**: 150+ lines → 0 lines (100% elimination)
- **Cache Implementations**: 400+ lines → 100 lines (75% elimination)  
- **Middleware System**: 300+ lines → 100 lines (67% elimination)
- **Validation Logic**: 200+ lines → 50 lines (75% elimination)

**Total Reduction**: 1,050+ lines → 250 lines (**76% code elimination**)

### Quality Improvements
- ✅ **Standardization**: Consistent patterns across services
- ✅ **Maintainability**: Single source of truth for common functionality
- ✅ **Testing**: Centralized testing for common components
- ✅ **Performance**: Optimized implementations with caching
- ✅ **Monitoring**: Built-in health checks and metrics

### Risk Mitigation
- **Backward Compatibility**: Maintain existing interfaces during migration
- **Gradual Migration**: Service-by-service migration approach
- **Testing**: Comprehensive testing at each phase
- **Rollback Plan**: Keep old implementations until migration complete

## Next Steps

1. **Review and Approve** this consolidation plan
2. **Start with Phase 1** (Worker Framework) - highest impact, lowest risk
3. **Create** common module structure for new components
4. **Begin** service-by-service migration
5. **Monitor** metrics and performance during migration

## Files to Create/Modify

### New Files
- `common/worker/base.go`
- `common/worker/manager.go`
- `common/cache/typed_cache.go`
- `common/middleware/base.go`
- `common/validation/validator.go`

### Files to Migrate
- `customer/internal/worker/base/worker.go` → Remove
- `pricing/internal/worker/base/worker.go` → Remove
- `warehouse/internal/worker/base/worker.go` → Remove
- `pricing/internal/cache/price_cache.go` → Simplify (200+ → 40 lines)
- `gateway/internal/middleware/manager.go` → Simplify (300+ → 100 lines)

This consolidation plan will eliminate **76% of duplicate code** while improving maintainability, performance, and standardization across the entire microservices architecture.
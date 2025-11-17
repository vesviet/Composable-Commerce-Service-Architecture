# Common Package Migration Plan

## Overview
Plan để move generated code và duplicate code vào common package, sau đó publish tag mới và migrate các services.

---

## STEP 1: MOVE GENERATED CODE TO COMMON

### 1.1. Create Pagination Helper
**File**: `common/utils/pagination/helper.go`

**Status**: ❌ Chưa có (cần tạo)

**Implementation**:
```go
package pagination

import "math"

type PaginationInput struct {
    Page    int32
    Limit   int32
    Offset  int32
    PerPage int32
}

type PaginationOutput struct {
    Page       int32
    Limit      int32
    Total      int32
    TotalPages int32
    HasNext    bool
    HasPrev    bool
}

func NormalizePagination(page, limit int32) PaginationInput
func CalculatePagination(page, limit, total int32) PaginationOutput
func GetOffsetLimit(page, limit int32) (offset, normalizedLimit int32)
```

**Duplicate locations**:
- `warehouse/internal/service/distributor_service.go` (lines 34-46, 58-66)
- `catalog/internal/service/*_service.go` (multiple files)
- `user/internal/service/*_service.go` (multiple files)

---

### 1.2. Create Validation Helper
**File**: `common/utils/validation/validators.go`

**Status**: ⚠️ Partial (có `common/utils/validation/` nhưng thiếu một số functions)

**Missing functions**:
- `IsValidEmail(email string) bool`
- `IsValidPhone(phone string) bool`
- `IsValidURL(url string) bool`
- `GenerateSlug(text string) string`
- `IsValidPassword(password string) (bool, string)`
- `ValidateRequired(fields map[string]string) (bool, string)`

**Duplicate locations**:
- `customer/internal/biz/customer.go` (email, phone validation)
- `catalog/internal/biz/*.go` (slug generation)
- `user/internal/biz/*.go` (password validation)

---

### 1.3. Create Generic Cache Helper
**File**: `common/utils/cache/redis_helper.go`

**Status**: ❌ Chưa có (có `common/utils/cache/cache.go` nhưng khác structure)

**Implementation**:
```go
package cache

type RedisCache struct {
    rdb        *redis.Client
    prefix     string
    defaultTTL time.Duration
    log        *log.Helper
}

func NewRedisCache(rdb *redis.Client, prefix string, defaultTTL time.Duration, logger log.Logger) *RedisCache
func (c *RedisCache) Get(ctx context.Context, key string, dest interface{}) error
func (c *RedisCache) Set(ctx context.Context, key string, value interface{}, ttl ...time.Duration) error
func (c *RedisCache) Delete(ctx context.Context, keys ...string) error
func (c *RedisCache) DeletePattern(ctx context.Context, pattern string) error
func (c *RedisCache) Exists(ctx context.Context, key string) (bool, error)
```

**Duplicate locations**:
- `customer/internal/cache/customer_cache.go`
- `pricing/internal/cache/pricing_cache.go`
- `promotion/internal/cache/promotion_cache.go`

---

### 1.4. Create Event Publisher Helper
**File**: `common/events/publisher_helper.go`

**Status**: ❌ Chưa có

**Implementation**:
```go
package events

type EventHelper struct {
    publisher   EventPublisher
    serviceName string
    log         *log.Helper
}

func NewEventHelper(publisher EventPublisher, serviceName string, logger log.Logger) *EventHelper
func (h *EventHelper) PublishCreated(ctx context.Context, entityType, entityID string, data map[string]interface{})
func (h *EventHelper) PublishUpdated(ctx context.Context, entityType, entityID string, changes map[string]interface{})
func (h *EventHelper) PublishDeleted(ctx context.Context, entityType, entityID string)
func (h *EventHelper) PublishCustom(ctx context.Context, eventType string, data map[string]interface{})
```

**Duplicate locations**:
- `customer/internal/events/customer_events.go`
- `pricing/internal/events/pricing_events.go`
- `promotion/internal/events/promotion_events.go`

---

### 1.5. Generate Protobuf Files
**Files**: 
- `common/proto/v1/common.pb.go` (generated)
- `common/config/common.pb.go` (if exists)

**Commands**:
```bash
cd common
make proto
# Or manually:
protoc --proto_path=. \
       --proto_path=../.. \
       --go_out=. \
       --go_opt=paths=source_relative \
       --go-grpc_out=. \
       --go-grpc_opt=paths=source_relative \
       proto/v1/common.proto \
       config/common.proto
```

**Verify**:
- Check generated `.pb.go` files exist
- Run `go build ./...` to ensure no errors
- Run `go test ./...` to ensure tests pass

---

## STEP 2: PUSH NEW TAG TO COMMON

### 2.1. Update go.mod
**File**: `common/go.mod`

**Current**:
```go
module gitlab.com/ta-microservices/common
go 1.24.0
```

**Action**: ✅ Already correct (no changes needed)

---

### 2.2. Commit Changes
```bash
cd common
git add -A
git commit -m "feat: add pagination, validation, cache, and event helpers

- Add pagination helper (NormalizePagination, CalculatePagination)
- Add validation helpers (IsValidEmail, IsValidPhone, GenerateSlug, etc.)
- Add generic Redis cache helper
- Add event publisher helper
- Generate protobuf files"
```

---

### 2.3. Create and Push Tag
```bash
cd common

# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0: Common helpers for pagination, validation, cache, and events"

# Push tag to remote
git push origin v1.0.0

# Or push all tags
git push origin --tags
```

**Tag format**: `v1.0.0` (semantic versioning)

---

### 2.4. Verify Tag
```bash
# Check tag exists
git tag -l

# Check tag on remote
git ls-remote --tags origin

# Test import (from another service)
cd ../catalog
go get gitlab.com/ta-microservices/common@v1.0.0
go mod tidy
```

---

## STEP 3: USE COMMON CODE IN SERVICES

### 3.1. Update Service go.mod
**Services to update**: `catalog`, `warehouse`, `user`, `customer`, `pricing`, `promotion`

**For each service**:
```bash
cd {service}

# Update common dependency
go get gitlab.com/ta-microservices/common@v1.0.0
go mod tidy
```

**go.mod change**:
```go
require (
    gitlab.com/ta-microservices/common v1.0.0
)

// Remove local replace (if exists)
// replace gitlab.com/ta-microservices/common => ../common
```

---

### 3.2. Replace Pagination Code

**Files to update**:
- `catalog/internal/service/*_service.go`
- `warehouse/internal/service/distributor_service.go`
- `warehouse/internal/service/warehouse_service.go`
- `user/internal/service/*_service.go`

**Before**:
```go
// Set default pagination
page := req.Page
if page <= 0 {
    page = 1
}
limit := req.Limit
if limit <= 0 {
    limit = 20
}
if limit > 100 {
    limit = 100
}
offset := (page - 1) * limit

// Calculate pagination
totalPages := int32((int64(total) + int64(limit) - 1) / int64(limit))
```

**After**:
```go
import "gitlab.com/ta-microservices/common/utils/pagination"

// Normalize pagination
paging := pagination.NormalizePagination(req.Page, req.Limit)

// Calculate pagination metadata
pageMeta := pagination.CalculatePagination(paging.Page, paging.Limit, total)
```

---

### 3.3. Replace Validation Code

**Files to update**:
- `customer/internal/biz/customer.go`
- `catalog/internal/biz/*.go` (slug generation)
- `user/internal/biz/*.go` (password validation)

**Before**:
```go
emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
if !emailRegex.MatchString(req.Email) {
    return nil, fmt.Errorf("invalid email")
}
```

**After**:
```go
import "gitlab.com/ta-microservices/common/utils/validation"

if !validation.IsValidEmail(req.Email) {
    return nil, fmt.Errorf("invalid email")
}
```

---

### 3.4. Replace Cache Code

**Files to update**:
- `customer/internal/cache/customer_cache.go`
- `pricing/internal/cache/pricing_cache.go`
- `promotion/internal/cache/promotion_cache.go`

**Before**:
```go
type customerCache struct {
    rdb    *redis.Client
    config *conf.Config
    log    *log.Helper
}

func (c *customerCache) Get(ctx context.Context, key string) (*Customer, error) {
    cacheKey := fmt.Sprintf("customer:%s", key)
    data, err := c.rdb.Get(ctx, cacheKey).Result()
    // ... manual JSON unmarshal
}
```

**After**:
```go
import "gitlab.com/ta-microservices/common/utils/cache"

type customerCache struct {
    cache *cache.RedisCache
}

func NewCustomerCache(rdb *redis.Client, logger log.Logger) *customerCache {
    return &customerCache{
        cache: cache.NewRedisCache(rdb, "customer", 5*time.Minute, logger),
    }
}

func (c *customerCache) Get(ctx context.Context, key string) (*Customer, error) {
    var customer Customer
    if err := c.cache.Get(ctx, key, &customer); err != nil {
        return nil, err
    }
    return &customer, nil
}
```

---

### 3.5. Replace Event Publisher Code

**Files to update**:
- `customer/internal/events/customer_events.go`
- `pricing/internal/events/pricing_events.go`
- `promotion/internal/events/promotion_events.go`

**Before**:
```go
type customerEvents struct {
    publisher events.EventPublisher
    log       *log.Helper
}

func (e *customerEvents) PublishCreated(ctx context.Context, customer *Customer) {
    event := map[string]interface{}{
        "event_type": "customer.created",
        "customer_id": customer.ID,
        // ... manual event construction
    }
    e.publisher.PublishEvent(ctx, "customer.created", event)
}
```

**After**:
```go
import "gitlab.com/ta-microservices/common/events"

type customerEvents struct {
    events *events.EventHelper
}

func NewCustomerEvents(publisher events.EventPublisher, logger log.Logger) *customerEvents {
    return &customerEvents{
        events: events.NewEventHelper(publisher, "customer-service", logger),
    }
}

func (e *customerEvents) PublishCreated(ctx context.Context, customer *Customer) {
    e.events.PublishCreated(ctx, "customer", customer.ID, map[string]interface{}{
        "email": customer.Email,
        "name": customer.Name,
    })
}
```

---

## MIGRATION CHECKLIST

### Step 1: Move Generated Code ✅
- [ ] Create `common/utils/pagination/helper.go`
- [ ] Add missing validators to `common/utils/validation/validators.go`
- [ ] Create `common/utils/cache/redis_helper.go`
- [ ] Create `common/events/publisher_helper.go`
- [ ] Generate protobuf files (`make proto`)
- [ ] Run tests: `cd common && go test ./...`
- [ ] Build: `cd common && go build ./...`

### Step 2: Push Tag ✅
- [ ] Commit all changes in common
- [ ] Create tag `v1.0.0`: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Verify tag exists on remote

### Step 3: Use Common Code ✅
- [ ] Update `catalog/go.mod`: `go get gitlab.com/ta-microservices/common@v1.0.0`
- [ ] Update `warehouse/go.mod`: `go get gitlab.com/ta-microservices/common@v1.0.0`
- [ ] Update `user/go.mod`: `go get gitlab.com/ta-microservices/common@v1.0.0`
- [ ] Update `customer/go.mod`: `go get gitlab.com/ta-microservices/common@v1.0.0`
- [ ] Update `pricing/go.mod`: `go get gitlab.com/ta-microservices/common@v1.0.0`
- [ ] Update `promotion/go.mod`: `go get gitlab.com/ta-microservices/common@v1.0.0`
- [ ] Replace pagination code in services
- [ ] Replace validation code in services
- [ ] Replace cache code in services
- [ ] Replace event publisher code in services
- [ ] Test each service: `go build ./...` and `go test ./...`

---

## NOTES

1. **Backward Compatibility**: Ensure existing code continues to work during migration
2. **Testing**: Test each service after migration to ensure no regressions
3. **Documentation**: Update service READMEs to reference common package usage
4. **Versioning**: Use semantic versioning (v1.0.0, v1.1.0, etc.) for common package
5. **Git Tags**: Always create annotated tags with descriptive messages

---

## ESTIMATED TIME

- **Step 1**: 2-3 hours (create helpers, generate code, test)
- **Step 2**: 15 minutes (commit, tag, push)
- **Step 3**: 4-6 hours (update all services, test)

**Total**: ~7-10 hours

---

Generated: 2025-11-10


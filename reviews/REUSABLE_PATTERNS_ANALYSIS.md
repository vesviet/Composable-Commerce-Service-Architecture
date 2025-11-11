# Reusable Patterns Analysis - Microservices Project

## Tổng quan
Document này tổng hợp các method/function patterns thường được sử dụng lặp lại trong các services, giúp tổ chức code để reuse tốt hơn.

---

## 1. REPOSITORY PATTERNS

### 1.1. Base Repository Interface
**Xuất hiện ở**: Tất cả services (catalog, customer, warehouse, user, auth)

**Pattern chung**:
```go
type BaseRepo interface {
    // CRUD Operations
    FindByID(ctx context.Context, id string) (*Model, error)
    Create(ctx context.Context, m *Model) (*Model, error)
    Update(ctx context.Context, m *Model, params interface{}) error
    Save(ctx context.Context, m *Model) error
    DeleteByID(ctx context.Context, id string) error
    
    // List & Search Operations
    List(ctx context.Context, q *ListInput) ([]*Model, Paging, error)
    Search(ctx context.Context, q *ListInput) ([]*Model, Paging, error)
}
```

**Đề xuất**: Tạo `common/utils/repository/base_interface.go` với generic interface

---

### 1.2. ListInput & Paging Structures
**Xuất hiện ở**: catalog, customer, warehouse

**Pattern chung**:
```go
type ListInput struct {
    // Filters
    Keyword  string
    Status   string
    Statuses []string
    
    // Pagination
    Page    int32
    PerPage int32
    Offset  int32
    Limit   int32
    
    // Sorting
    OrderBy []string
}

type Paging struct {
    Page       int32
    PerPage    int32
    Total      int32
    TotalPages int32
}
```

**Đề xuất**: Move to `common/utils/repository/pagination.go`

---

## 2. BUSINESS LOGIC (BIZ) PATTERNS

### 2.1. Usecase Constructor Pattern
**Xuất hiện ở**: Tất cả services

**Pattern chung**:
```go
type XxxUsecase struct {
    repo   XxxRepo
    log    *log.Helper
    cache  *redis.Client  // Optional
    events EventPublisher // Optional
}

func NewXxxUsecase(
    repo XxxRepo,
    logger log.Logger,
    // ... other dependencies
) *XxxUsecase {
    return &XxxUsecase{
        repo: repo,
        log:  log.NewHelper(logger),
    }
}
```

**Đề xuất**: Tạo base usecase struct trong `common/biz/base_usecase.go`

---

### 2.2. CRUD Operations Pattern
**Xuất hiện ở**: catalog (brand, category, manufacturer), customer, warehouse

**Pattern chung**:
```go
// Create
func (uc *Usecase) CreateXxx(ctx context.Context, req *CreateRequest) (*Model, error) {
    uc.log.WithContext(ctx).Infof("Creating xxx: %s", req.Name)
    
    // 1. Validate required fields
    if req.Name == "" {
        return nil, fmt.Errorf("name is required")
    }
    
    // 2. Check uniqueness (slug, code, email, etc.)
    existing, err := uc.repo.FindByXxx(ctx, req.Xxx)
    if existing != nil {
        return nil, fmt.Errorf("xxx already exists")
    }
    
    // 3. Create model
    model := &Model{...}
    
    // 4. Save to database
    result, err := uc.repo.Create(ctx, model)
    
    // 5. Cache & Events (optional)
    if uc.cache != nil {
        uc.cache.Set(...)
    }
    if uc.events != nil {
        uc.events.Publish(...)
    }
    
    return result, nil
}

// Update
func (uc *Usecase) UpdateXxx(ctx context.Context, req *UpdateRequest) (*Model, error) {
    // 1. Get existing
    existing, err := uc.repo.FindByID(ctx, req.ID)
    if existing == nil {
        return nil, fmt.Errorf("not found")
    }
    
    // 2. Validate changes
    // 3. Update fields
    // 4. Save
    // 5. Invalidate cache & publish events
    
    return updated, nil
}

// Get
func (uc *Usecase) GetXxx(ctx context.Context, id string) (*Model, error) {
    // 1. Try cache first (if available)
    if uc.cache != nil {
        cached, _ := uc.cache.Get(ctx, id)
        if cached != nil {
            return cached, nil
        }
    }
    
    // 2. Fetch from database
    model, err := uc.repo.FindByID(ctx, id)
    
    // 3. Cache result
    if uc.cache != nil {
        uc.cache.Set(ctx, model)
    }
    
    return model, nil
}

// List
func (uc *Usecase) ListXxx(ctx context.Context, offset, limit int32) ([]*Model, int32, error) {
    if limit <= 0 || limit > 100 {
        limit = 20 // Default limit
    }
    
    listInput := &ListInput{
        Offset:  offset,
        Limit:   limit,
        Page:    (offset / limit) + 1,
        PerPage: limit,
    }
    
    models, paging, err := uc.repo.List(ctx, listInput)
    return models, paging.Total, err
}

// Delete
func (uc *Usecase) DeleteXxx(ctx context.Context, id string) error {
    // 1. Check exists
    // 2. Check dependencies (optional)
    // 3. Delete
    // 4. Invalidate cache & publish events
    
    return nil
}
```

**Đề xuất**: Tạo `common/biz/crud_operations.go` với helper functions

---

### 2.3. Validation Helpers
**Xuất hiện ở**: customer, catalog

**Pattern chung**:
```go
// Email validation
func isValidEmail(email string) bool {
    emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
    return emailRegex.MatchString(email)
}

// Phone validation
func isValidPhone(phone string) bool {
    cleaned := regexp.MustCompile(`[\s\-\(\)]`).ReplaceAllString(phone, "")
    // International: +country code
    if matched, _ := regexp.MatchString(`^\+[1-9]\d{1,14}$`, cleaned); matched {
        return true
    }
    // Local: 8-15 digits
    if matched, _ := regexp.MatchString(`^\d{8,15}$`, cleaned); matched {
        return true
    }
    return false
}

// URL validation
func isValidURL(url string) bool {
    return strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://")
}

// Slug generation
func generateSlug(name string) string {
    slug := strings.ToLower(name)
    slug = strings.ReplaceAll(slug, " ", "-")
    slug = strings.ReplaceAll(slug, "_", "-")
    return slug
}
```

**Đề xuất**: Move to `common/utils/validation/validators.go`

---

## 3. SERVICE LAYER PATTERNS

### 3.1. Proto Conversion Pattern
**Xuất hiện ở**: Tất cả services

**Pattern chung**:
```go
// Model to Proto
func (m *Model) ToProto() *pb.Model {
    return &pb.Model{
        Id:   m.ID,
        Name: m.Name,
        // ... other fields
    }
}

// Proto to Model
func FromProto(pb *pb.Model) *Model {
    return &Model{
        ID:   pb.Id,
        Name: pb.Name,
        // ... other fields
    }
}

// Batch conversion
func ModelsToProto(models []*Model) []*pb.Model {
    result := make([]*pb.Model, len(models))
    for i, m := range models {
        result[i] = m.ToProto()
    }
    return result
}
```

**Đề xuất**: Tạo interface trong `common/proto/converter.go`

---

### 3.2. Pagination Response Pattern
**Xuất hiện ở**: Tất cả services

**Pattern chung**:
```go
func (s *Service) ListXxx(ctx context.Context, req *pb.ListRequest) (*pb.ListReply, error) {
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
    
    // Fetch data
    items, total, err := s.usecase.List(ctx, offset, limit)
    
    // Calculate pagination
    totalPages := (total + limit - 1) / limit
    if totalPages == 0 {
        totalPages = 1
    }
    
    return &pb.ListReply{
        Items: convertToProto(items),
        Pagination: &v1.Pagination{
            Page:       page,
            Limit:      limit,
            Total:      total,
            TotalPages: totalPages,
        },
    }, nil
}
```

**Đề xuất**: Tạo helper trong `common/utils/pagination/helper.go`

---

## 4. CACHING PATTERNS

### 4.1. Cache Helper Structure
**Xuất hiện ở**: customer (customer, address, preference), pricing

**Pattern chung**:
```go
type xxxCache struct {
    rdb    *redis.Client
    config *conf.Config
    log    *log.Helper
}

func NewXxxCache(rdb *redis.Client, config *conf.Config, logger log.Logger) *xxxCache {
    if rdb == nil {
        return nil // Cache is optional
    }
    return &xxxCache{
        rdb:    rdb,
        config: config,
        log:    log.NewHelper(logger),
    }
}

// Get from cache
func (c *xxxCache) Get(ctx context.Context, key string) (*Model, error) {
    if c == nil || c.rdb == nil {
        return nil, nil // Cache not available
    }
    
    cacheKey := fmt.Sprintf("xxx:%s", key)
    data, err := c.rdb.Get(ctx, cacheKey).Result()
    if err == redis.Nil {
        return nil, nil // Cache miss
    }
    if err != nil {
        return nil, err
    }
    
    var model Model
    if err := json.Unmarshal([]byte(data), &model); err != nil {
        return nil, err
    }
    
    return &model, nil
}

// Set to cache
func (c *xxxCache) Set(ctx context.Context, model *Model) error {
    if c == nil || c.rdb == nil {
        return nil
    }
    
    cacheKey := fmt.Sprintf("xxx:%s", model.ID)
    data, err := json.Marshal(model)
    if err != nil {
        return err
    }
    
    ttl := c.getTTL()
    return c.rdb.Set(ctx, cacheKey, data, ttl).Err()
}

// Invalidate cache
func (c *xxxCache) Invalidate(ctx context.Context, key string) error {
    if c == nil || c.rdb == nil {
        return nil
    }
    
    cacheKey := fmt.Sprintf("xxx:%s", key)
    return c.rdb.Del(ctx, cacheKey).Err()
}

// Get TTL from config
func (c *xxxCache) getTTL() time.Duration {
    if c.config != nil && c.config.Cache != nil {
        return time.Duration(c.config.Cache.TtlSeconds) * time.Second
    }
    return 5 * time.Minute // Default
}
```

**Đề xuất**: Tạo generic cache helper trong `common/utils/cache/redis_cache.go`

---

## 5. TRANSACTION PATTERNS

### 5.1. Transaction Function Type
**Xuất hiện ở**: customer, catalog

**Pattern chung**:
```go
type TransactionFunc func(ctx context.Context, fn func(ctx context.Context) error) error

// Usage in usecase
func (uc *Usecase) CreateWithRelations(ctx context.Context, req *Request) error {
    return uc.transaction(ctx, func(ctx context.Context) error {
        // Create main entity
        if err := uc.repo.Create(ctx, main); err != nil {
            return err
        }
        
        // Create related entities
        if err := uc.relatedRepo.Create(ctx, related); err != nil {
            return err
        }
        
        return nil
    })
}
```

**Đã có**: `common/utils/transaction/gorm.go` ✅

---

## 6. EVENT PUBLISHING PATTERNS

### 6.1. Event Publisher Helper
**Xuất hiện ở**: customer, pricing

**Pattern chung**:
```go
type xxxEvents struct {
    publisher events.EventPublisher
    log       *log.Helper
}

func NewXxxEvents(publisher events.EventPublisher, logger log.Logger) *xxxEvents {
    if publisher == nil {
        return nil
    }
    return &xxxEvents{
        publisher: publisher,
        log:       log.NewHelper(logger),
    }
}

func (e *xxxEvents) PublishCreated(ctx context.Context, model *Model) {
    if e == nil || e.publisher == nil {
        return
    }
    
    event := map[string]interface{}{
        "event_type": "xxx.created",
        "xxx_id":     model.ID,
        "timestamp":  time.Now(),
        // ... other fields
    }
    
    if err := e.publisher.PublishEvent(ctx, "xxx.created", event); err != nil {
        e.log.WithContext(ctx).Warnf("Failed to publish event: %v", err)
    }
}
```

**Đề xuất**: Tạo base event helper trong `common/events/publisher_helper.go`

---

## 7. LOGGING PATTERNS

### 7.1. Structured Logging
**Xuất hiện ở**: Tất cả services

**Pattern chung**:
```go
// In usecase constructor
log: log.NewHelper(logger)

// Usage
uc.log.WithContext(ctx).Infof("Creating xxx: %s", req.Name)
uc.log.WithContext(ctx).Errorf("Failed to create xxx: %v", err)
uc.log.WithContext(ctx).Warnf("Cache miss for xxx: %s", id)
uc.log.WithContext(ctx).Debugf("Cache hit for xxx: %s", id)
```

**Đã có**: Kratos log.Helper ✅

---

## 8. ERROR HANDLING PATTERNS

### 8.1. Error Constructors
**Đã có**: `common/errors/constructors.go` ✅

**Các error types thường dùng**:
- `NewNotFoundError(resource string)`
- `NewValidationError(message string)`
- `NewConflictError(message string)`
- `NewInternalError(message string, cause error)`
- `NewDatabaseError(operation string, cause error)`

---

## 9. CONFIG PATTERNS

### 9.1. Environment Variable Helpers
**Đã có**: `common/config/config.go` ✅

**Helpers có sẵn**:
- `GetEnv(key, defaultValue string) string`
- `GetIntEnv(key string, defaultValue int) int`
- `GetBoolEnv(key string, defaultValue bool) bool`
- `GetDurationEnv(key string, defaultValue time.Duration) time.Duration`

---

## 10. CIRCUIT BREAKER PATTERNS

### 10.1. Circuit Breaker Wrapper
**Xuất hiện ở**: catalog, warehouse, auth

**Pattern chung**:
```go
type CircuitBreaker struct {
    name          string
    maxFailures   int
    timeout       time.Duration
    resetTimeout  time.Duration
    state         State
    failures      int
    lastFailTime  time.Time
    mu            sync.RWMutex
}

func (cb *CircuitBreaker) Execute(fn func() error) error {
    if !cb.CanExecute() {
        return WrapError(ErrCircuitOpen, cb.name, cb.state)
    }
    
    err := fn()
    if err != nil {
        cb.RecordFailure()
        return err
    }
    
    cb.RecordSuccess()
    return nil
}
```

**Đề xuất**: Consolidate vào `common/utils/circuitbreaker/`

---

## RECOMMENDATIONS - Ưu tiên implement

### Priority 1 - Critical (Dùng nhiều nhất)
1. ✅ **Transaction helpers** - Đã có trong `common/utils/transaction/`
2. ✅ **Error constructors** - Đã có trong `common/errors/`
3. ✅ **Config helpers** - Đã có trong `common/config/`
4. **Pagination helpers** - Cần tạo `common/utils/pagination/`
5. **Validation helpers** - Cần tạo `common/utils/validation/`

### Priority 2 - High (Dùng thường xuyên)
6. **Cache helper (generic)** - Cần tạo `common/utils/cache/redis_helper.go`
7. **Repository base interface** - Cần tạo `common/utils/repository/base_interface.go`
8. **Proto conversion helpers** - Cần tạo `common/proto/converter_helpers.go`
9. **Event publisher helper** - Cần tạo `common/events/publisher_helper.go`

### Priority 3 - Medium (Có thể optimize sau)
10. **CRUD operation templates** - Cần tạo `common/biz/crud_helpers.go`
11. **Circuit breaker consolidation** - Consolidate existing implementations
12. **Base usecase struct** - Cần tạo `common/biz/base_usecase.go`

---

## NEXT STEPS

1. **Review & Approve**: Review document này với team
2. **Create Issues**: Tạo issues cho từng item cần implement
3. **Implement Priority 1**: Bắt đầu với pagination và validation helpers
4. **Migrate Existing Code**: Dần dần migrate code hiện tại sang dùng common helpers
5. **Documentation**: Update docs cho mỗi common helper được tạo

---

Generated: 2025-11-10
Services analyzed: catalog, customer, warehouse, user, auth, gateway, pricing, promotion, order

# 🎁 PROMOTION SERVICE REVIEW

**Review Date**: January 14, 2026  
**Reviewer**: Principal Developer (Cascade)  
**Service**: Promotion (Campaign + Promotion + Coupon Management)  
**Score**: 75% | **Issues**: 6 (3 P0, 3 P1)
**Est. Fix Time**: 21 hours

---

## 📋 Executive Summary

Promotion service has solid business logic and architecture but has **3 critical P0 issues** that must be fixed before production:

**Critical Issues**:
1. **P0-1**: JSON unmarshaling without error checking (security risk)
2. **P0-2**: Non-atomic usage limit enforcement (race condition)
3. **P0-3**: Missing Transactional Outbox pattern (event loss risk)

**Good News**:
- Clean DDD architecture ✅
- Advanced promotion logic (BOGO, tiered, review-based) ✅
- Comprehensive validation logic ✅
- Event-driven design ✅

**Status**: ⚠️ **NOT PRODUCTION READY** - Requires P0 fixes

---

## ✅ What's Excellent

### 1. Advanced Promotion Logic ✅
**Status**: Feature-rich | **Impact**: Supports complex business rules

**Features**:
- BOGO (Buy One Get One) discounts
- Tiered pricing
- Review-based promotions
- Cart vs Catalog rules
- Stackable/non-stackable promotions
- Priority-based rule processing
- Stop rules processing flag

**Rubric Compliance**: ✅ #3 (Business Logic)


### 2. Clean Architecture ✅
**Status**: Well-organized | **Impact**: Maintainable codebase

**Pattern**:
- Proper DDD layers (biz, data, service)
- Repository pattern implemented
- Dependency injection via Wire
- Clear separation of concerns

**Rubric Compliance**: ✅ #1 (Architecture & Clean Code)

---

### 3. Comprehensive Validation ✅
**Status**: Robust validation | **Impact**: Data integrity

**Features**:
- Coupon validation (expiry, usage limits, customer segments)
- Promotion applicability checks
- Date range validation
- Customer segment matching
- Product/category/brand filtering

**Rubric Compliance**: ✅ #2 (API & Contract - Validation)

---

### 4. Health Checks ✅
**Status**: Database + Redis verification
- `/health` → basic readiness
- `/health/ready` → external dependencies
- `/health/live` → liveness
- `/health/detailed` → detailed status

**Rubric Compliance**: ✅ #9 (Configuration - Resilience)

---

### 5. Bulk Coupon Generation ✅
**Status**: Scalable coupon creation
- Supports up to 10,000 coupons per batch
- Template-based generation
- Unique code generation

**Rubric Compliance**: ✅ #6 (Performance - Bulk Operations)

---

## 🚨 Critical Issues (3 P0 + 3 P1)


### P0-1: JSON Unmarshaling Without Error Checking (4h) ⚠️

**Files**: 
- `internal/data/promotion.go:326-332`
- `internal/data/campaign.go:194-195`
- `internal/data/coupon.go:279-280`
- `internal/service/promotion.go:140-154`

**Severity**: 🔴 CRITICAL  
**Impact**: Security vulnerability - malformed JSON can crash service or cause silent data corruption

**Current State**:
```go
// ❌ NO ERROR CHECKING - DANGEROUS!
json.Unmarshal([]byte(p.ApplicableProducts), &applicableProducts)
json.Unmarshal([]byte(p.ApplicableCategories), &applicableCategories)
json.Unmarshal([]byte(p.Conditions), &conditions)
json.Unmarshal([]byte(p.Actions), &actions)
```

**Problem**:
- User input (Conditions, Actions) decoded without validation
- Malformed JSON silently ignored → wrong business logic
- Potential panic if JSON structure unexpected
- No logging of unmarshal failures

**Fix** (4 hours):
```go
// ✅ PROPER ERROR HANDLING
var applicableProducts []string
if err := json.Unmarshal([]byte(p.ApplicableProducts), &applicableProducts); err != nil {
    r.log.Errorf("Failed to unmarshal applicable_products for promotion %s: %v", p.ID, err)
    applicableProducts = []string{} // Safe default
}

var conditions map[string]interface{}
if err := json.Unmarshal([]byte(p.Conditions), &conditions); err != nil {
    r.log.Errorf("Failed to unmarshal conditions for promotion %s: %v", p.ID, err)
    return nil, fmt.Errorf("invalid promotion conditions: %w", err)
}
```

**Files to Fix**:
1. `internal/data/promotion.go` - convertToBusinessModel (7 unmarshal calls)
2. `internal/data/campaign.go` - convertToBusinessModel (2 unmarshal calls)
3. `internal/data/coupon.go` - convertToBusinessModel (2 unmarshal calls)
4. `internal/data/promotion_usage.go` - convertToBusinessModel (1 unmarshal call)
5. `internal/service/promotion.go` - ValidatePromotions (5 unmarshal calls)

**Testing**:
- [ ] Send malformed JSON in Conditions field
- [ ] Verify error returned (not panic)
- [ ] Check logs for error messages
- [ ] Verify safe defaults used

**Rubric Violation**: #2 (API & Contract - Validation), #5 (Security - Input Sanitation)

---


### P0-2: Non-Atomic Usage Limit Enforcement (6h) ⚠️

**File**: `internal/biz/promotion.go:700-720`  
**Severity**: 🔴 CRITICAL  
**Impact**: Race condition - multiple concurrent requests can exceed usage limits

**Current State**:
```go
// ❌ CHECK AND UPDATE ARE SEPARATE - RACE CONDITION!
func (uc *PromotionUseCase) isPromotionApplicable(ctx context.Context, promotion *Promotion, req *PromotionValidationRequest) bool {
    // Check total usage limit
    if promotion.TotalUsageLimit != nil && promotion.CurrentUsageCount >= *promotion.TotalUsageLimit {
        return false  // ← Check happens here
    }
    
    // Check per-customer usage limit
    if promotion.UsageLimitPerCustomer != nil && req.CustomerID != "" {
        usages, _, err := uc.promotionUsageRepo.GetUsageByCustomer(ctx, req.CustomerID, 0, 1000)
        // ... count usage ...
        if customerUsageCount >= *promotion.UsageLimitPerCustomer {
            return false  // ← Another check
        }
    }
    // ← But increment happens LATER in a different transaction!
}
```

**Problem**:
- Usage check and increment are NOT atomic
- Two concurrent requests can both pass the check
- Both increment the counter → exceeds limit
- Example: Limit=100, Current=99, 2 requests → both succeed → Final=101

**Fix** (6 hours):
```go
// ✅ ATOMIC INCREMENT WITH ROW LOCK
func (r *promotionRepo) IncrementUsageAtomic(ctx context.Context, promotionID string, customerID string) error {
    return r.data.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
        // 1. Lock row and check total limit
        var promo Promotion
        if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
            Where("id = ?", promotionID).
            First(&promo).Error; err != nil {
            return err
        }
        
        if promo.TotalUsageLimit != nil && promo.CurrentUsageCount >= *promo.TotalUsageLimit {
            return ErrUsageLimitExceeded
        }
        
        // 2. Check per-customer limit atomically
        if promo.UsageLimitPerCustomer != nil {
            var count int64
            if err := tx.Model(&PromotionUsage{}).
                Where("promotion_id = ? AND customer_id = ?", promotionID, customerID).
                Count(&count).Error; err != nil {
                return err
            }
            
            if int(count) >= *promo.UsageLimitPerCustomer {
                return ErrCustomerUsageLimitExceeded
            }
        }
        
        // 3. Increment atomically
        return tx.Model(&Promotion{}).
            Where("id = ?", promotionID).
            Update("current_usage_count", gorm.Expr("current_usage_count + 1")).
            Error
    })
}
```

**Implementation Steps**:
1. Add `IncrementUsageAtomic` method to PromotionRepo interface
2. Implement in `internal/data/promotion.go`
3. Call from `ValidatePromotions` BEFORE applying discount
4. Add error handling for limit exceeded
5. Add integration test with concurrent requests

**Testing**:
- [ ] Create promotion with limit=10
- [ ] Send 20 concurrent validation requests
- [ ] Verify exactly 10 succeed, 10 fail
- [ ] Check final usage count = 10 (not 11+)

**Rubric Violation**: #3 (Business Logic - Race Conditions), #4 (Data Layer - Transaction Boundaries)

---


### P0-3: Missing Transactional Outbox Pattern (8h) ⚠️

**Files**: 
- `internal/biz/promotion.go:460-470` (CreateCampaign)
- `internal/biz/promotion.go:490-500` (CreatePromotion)
- `internal/biz/promotion.go:850-860` (GenerateBulkCoupons)

**Severity**: 🔴 CRITICAL  
**Impact**: Event loss on crashes - events published AFTER DB commit

**Current State**:
```go
// ❌ DUAL-WRITE PROBLEM - EVENTS CAN BE LOST!
func (uc *PromotionUseCase) CreateCampaign(ctx context.Context, campaign *Campaign) error {
    // 1. Write to DB
    if err := uc.campaignRepo.CreateCampaign(ctx, campaign); err != nil {
        return err
    }
    
    // 2. Publish event AFTER commit
    uc.publishCampaignEvent(ctx, "campaign.created", campaign)
    // ← If crash here, event is LOST but campaign is SAVED!
    
    return nil
}
```

**Problem**:
- DB write and event publish are NOT atomic
- If service crashes between DB commit and event publish → event lost
- Other services never notified of campaign creation
- Data inconsistency across services

**Fix** (8 hours) - Implement Transactional Outbox:

**Step 1**: Create outbox table migration
```sql
-- migrations/010_create_outbox_events_table.sql
CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    
    INDEX idx_outbox_status (status, created_at),
    INDEX idx_outbox_aggregate (aggregate_type, aggregate_id)
);
```

**Step 2**: Create OutboxRepo
```go
// internal/data/outbox.go
type OutboxEvent struct {
    ID            string
    AggregateType string
    AggregateID   string
    EventType     string
    Payload       string
    Status        string
    RetryCount    int
    CreatedAt     time.Time
    ProcessedAt   *time.Time
}

type OutboxRepo interface {
    Create(ctx context.Context, event *OutboxEvent) error
    GetPending(ctx context.Context, limit int) ([]*OutboxEvent, error)
    MarkProcessed(ctx context.Context, id string) error
    MarkFailed(ctx context.Context, id string) error
}
```


**Step 3**: Update CreateCampaign to use Outbox
```go
// ✅ ATOMIC DB + OUTBOX WRITE
func (uc *PromotionUseCase) CreateCampaign(ctx context.Context, campaign *Campaign) error {
    return uc.tm.InTx(ctx, func(ctx context.Context) error {
        // 1. Create campaign
        if err := uc.campaignRepo.CreateCampaign(ctx, campaign); err != nil {
            return err
        }
        
        // 2. Create outbox event IN SAME TRANSACTION
        payload, _ := json.Marshal(map[string]interface{}{
            "campaign_id": campaign.ID,
            "name": campaign.Name,
            "status": campaign.Status,
        })
        
        event := &OutboxEvent{
            AggregateType: "campaign",
            AggregateID:   campaign.ID,
            EventType:     "campaign.created",
            Payload:       string(payload),
            Status:        "PENDING",
        }
        
        return uc.outboxRepo.Create(ctx, event)
        // ← Both succeed or both fail together!
    })
}
```

**Step 4**: Create Outbox Worker
```go
// cmd/worker/main.go - add outbox worker
type OutboxWorker struct {
    outboxRepo     OutboxRepo
    eventPublisher EventPublisher
    log            *log.Helper
}

func (w *OutboxWorker) Start(ctx context.Context) error {
    ticker := time.NewTicker(1 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return nil
        case <-ticker.C:
            w.processEvents(ctx)
        }
    }
}

func (w *OutboxWorker) processEvents(ctx context.Context) {
    events, _ := w.outboxRepo.GetPending(ctx, 100)
    
    for _, event := range events {
        if err := w.eventPublisher.PublishEvent(ctx, event.EventType, event.Payload); err != nil {
            w.outboxRepo.MarkFailed(ctx, event.ID)
        } else {
            w.outboxRepo.MarkProcessed(ctx, event.ID)
        }
    }
}
```

**Reference**: See `catalog/internal/biz/product/product_write.go:40-76` for working implementation

**Testing**:
- [ ] Create campaign → verify outbox event created
- [ ] Worker processes event → verify status=COMPLETED
- [ ] Kill service after DB commit → verify event still published
- [ ] Verify no duplicate events

**Rubric Violation**: #4 (Data Layer - Transaction Boundaries), #3 (Business Logic - Concurrency)

---


### P1-1: Missing Standard Middleware Stack (3h) ⚠️

**File**: `internal/server/http.go:28-35`  
**Severity**: 🟡 HIGH  
**Impact**: No metrics collection, no distributed tracing

**Current State**:
```go
// ❌ MISSING METRICS AND TRACING
middlewareList := []middleware.Middleware{
    recovery.Recovery(),
}

// Add Kratos built-in logging middleware
middlewareList = append(middlewareList, logging.Server(logger))

// Add rate limiting middleware if Redis is available
if d != nil && d.Redis() != nil {
    middlewareList = append(middlewareList, commonMiddleware.RateLimit(rateLimitConfig))
}
```

**Problem**:
- No `metrics.Server()` → Prometheus metrics not collected
- No `tracing.Server()` → No OpenTelemetry spans
- Cannot trace cross-service calls
- Cannot monitor request latency/errors

**Fix** (3 hours):
```go
// ✅ ADD STANDARD MIDDLEWARE STACK
import (
    "github.com/go-kratos/kratos/v2/middleware/metrics"
    "github.com/go-kratos/kratos/v2/middleware/tracing"
)

middlewareList := []middleware.Middleware{
    recovery.Recovery(),
    logging.Server(logger),
    metrics.Server(),      // ← ADD THIS
    tracing.Server(),      // ← ADD THIS
}
```

**Testing**:
- [ ] Build: `make build`
- [ ] Run: `make run`
- [ ] Metrics: `curl http://localhost:8003/metrics | grep http_requests`
- [ ] Tracing: Check Jaeger for "promotion" service spans

**Rubric Violation**: #7 (Observability - Metrics & Tracing)

---


### P1-2: In-Memory Filtering Instead of DB Query (3h) ⚠️

**File**: `internal/data/promotion.go:200-250`  
**Severity**: 🟡 HIGH  
**Impact**: Performance - fetches ALL promotions then filters in memory

**Current State**:
```go
// ❌ FETCHES ALL THEN FILTERS - INEFFICIENT!
func (r *promotionRepo) GetActivePromotions(ctx context.Context, filters map[string]interface{}) ([]*biz.Promotion, error) {
    query := r.data.db.WithContext(ctx).
        Model(&Promotion{}).
        Where("is_active = ?", true).
        Where("(starts_at IS NULL OR starts_at <= ?)", now).
        Where("(ends_at IS NULL OR ends_at >= ?)", now)
    
    // ← Fetches ALL active promotions
    if err := query.Order("priority DESC, created_at DESC").Find(&promotions).Error; err != nil {
        return nil, err
    }
    
    // ← Then filters in Go code (should be in SQL)
}
```

**Problem**:
- Fetches all active promotions from DB
- Filters by products/categories/brands in application code
- Wastes memory and CPU
- Slow for large promotion catalogs

**Fix** (3 hours):
```go
// ✅ FILTER IN DATABASE
func (r *promotionRepo) GetActivePromotions(ctx context.Context, filters map[string]interface{}) ([]*biz.Promotion, error) {
    query := r.data.db.WithContext(ctx).
        Model(&Promotion{}).
        Where("is_active = ?", true).
        Where("(starts_at IS NULL OR starts_at <= ?)", now).
        Where("(ends_at IS NULL OR ends_at >= ?)", now)
    
    // Apply filters in SQL using JSONB operators
    if productIDs, ok := filters["products"].([]string); ok && len(productIDs) > 0 {
        // Use PostgreSQL JSONB contains operator
        query = query.Where(
            "(applicable_products::jsonb = '[]'::jsonb OR applicable_products::jsonb ?| array[?])",
            pq.Array(productIDs),
        )
    }
    
    // Similar for categories, brands, etc.
    
    return query.Find(&promotions).Error
}
```

**Note**: Current implementation already has JSONB filtering logic but it's commented or incomplete. Need to verify and enable it.

**Testing**:
- [ ] Create 1000 promotions
- [ ] Query with product filter
- [ ] Verify SQL EXPLAIN shows index usage
- [ ] Measure query time (should be <50ms)

**Rubric Violation**: #6 (Performance - Query Optimization)

---


### P1-3: No Worker Implementation (3h) ⚠️

**File**: `internal/worker/workers.go`  
**Severity**: 🟡 HIGH  
**Impact**: No background processing for outbox events or expired promotions

**Current State**:
```go
// ❌ EMPTY WORKER LIST
func NewWorkers() []commonWorker.ContinuousWorker {
    var workers []commonWorker.ContinuousWorker
    // Future workers can be added here
    return workers  // ← Returns empty list!
}
```

**Problem**:
- No outbox worker to publish events
- No worker to expire promotions
- No worker to clean up old usage records
- Events stuck in PENDING state forever

**Fix** (3 hours) - Add Outbox Worker:
```go
// internal/worker/outbox_worker.go
type OutboxWorker struct {
    outboxRepo     biz.OutboxRepo
    eventPublisher events.EventPublisher
    log            *log.Helper
}

func NewOutboxWorker(
    outboxRepo biz.OutboxRepo,
    eventPublisher events.EventPublisher,
    logger log.Logger,
) *OutboxWorker {
    return &OutboxWorker{
        outboxRepo:     outboxRepo,
        eventPublisher: eventPublisher,
        log:            log.NewHelper(logger),
    }
}

func (w *OutboxWorker) Name() string {
    return "promotion-outbox-worker"
}

func (w *OutboxWorker) Start(ctx context.Context) error {
    ticker := time.NewTicker(1 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return nil
        case <-ticker.C:
            if err := w.processEvents(ctx); err != nil {
                w.log.Errorf("Failed to process events: %v", err)
            }
        }
    }
}

func (w *OutboxWorker) processEvents(ctx context.Context) error {
    events, err := w.outboxRepo.GetPending(ctx, 100)
    if err != nil {
        return err
    }
    
    for _, event := range events {
        if err := w.eventPublisher.PublishEvent(ctx, event.EventType, event.Payload); err != nil {
            w.log.Errorf("Failed to publish event %s: %v", event.ID, err)
            w.outboxRepo.MarkFailed(ctx, event.ID)
        } else {
            w.outboxRepo.MarkProcessed(ctx, event.ID)
        }
    }
    
    return nil
}
```

**Update workers.go**:
```go
func NewWorkers(
    outboxRepo biz.OutboxRepo,
    eventPublisher events.EventPublisher,
    logger log.Logger,
) []commonWorker.ContinuousWorker {
    return []commonWorker.ContinuousWorker{
        NewOutboxWorker(outboxRepo, eventPublisher, logger),
    }
}
```

**Testing**:
- [ ] Start worker
- [ ] Create campaign → verify outbox event created
- [ ] Wait 1 second → verify event processed
- [ ] Check event status = COMPLETED

**Rubric Violation**: #3 (Business Logic - Concurrency), #9 (Configuration - Resilience)

---


## 📊 Rubric Compliance Matrix

| Rubric Item | Score | Status | Notes |
|-------------|-------|--------|-------|
| 1️⃣ Architecture & Clean Code | 8/10 | ✅ | Clean DDD, proper DI |
| 2️⃣ API & Contract | 6/10 | ⚠️ | P0-1: JSON validation missing |
| 3️⃣ Business Logic & Concurrency | 6/10 | ⚠️ | P0-2: Race conditions, P0-3: No outbox |
| 4️⃣ Data Layer & Persistence | 5/10 | ⚠️ | P0-2: Non-atomic updates, P0-3: No outbox |
| 5️⃣ Security | 6/10 | ⚠️ | P0-1: Input validation gaps |
| 6️⃣ Performance & Scalability | 7/10 | ⚠️ | P1-2: In-memory filtering |
| 7️⃣ Observability | 6/10 | ⚠️ | P1-1: Missing middleware |
| 8️⃣ Testing & Quality | 4/10 | ⚠️ | No tests found |
| 9️⃣ Configuration & Resilience | 6/10 | ⚠️ | P1-3: No workers |
| 🔟 Documentation & Maintenance | 8/10 | ✅ | Good README |
| **OVERALL** | **6.2/10** | **⚠️** | **NOT PRODUCTION READY** |

---

## 🚀 Implementation Roadmap

### Phase 1: Fix P0 Issues (18 hours)

**Priority**: CRITICAL - Must complete before production

**P0-1: JSON Error Handling** (4h)
- [ ] Fix `internal/data/promotion.go` (7 calls)
- [ ] Fix `internal/data/campaign.go` (2 calls)
- [ ] Fix `internal/data/coupon.go` (2 calls)
- [ ] Fix `internal/data/promotion_usage.go` (1 call)
- [ ] Fix `internal/service/promotion.go` (5 calls)
- [ ] Add error logging
- [ ] Test with malformed JSON

**P0-2: Atomic Usage Limits** (6h)
- [ ] Add `IncrementUsageAtomic` to PromotionRepo interface
- [ ] Implement in `internal/data/promotion.go`
- [ ] Update `ValidatePromotions` to use atomic increment
- [ ] Add error handling for limit exceeded
- [ ] Write integration test with concurrent requests
- [ ] Verify no race conditions

**P0-3: Transactional Outbox** (8h)
- [ ] Create migration `010_create_outbox_events_table.sql`
- [ ] Create `internal/data/outbox.go` with OutboxRepo
- [ ] Update `CreateCampaign` to use outbox
- [ ] Update `CreatePromotion` to use outbox
- [ ] Update `GenerateBulkCoupons` to use outbox
- [ ] Create outbox worker
- [ ] Test event delivery guarantees

---

### Phase 2: Fix P1 Issues (9 hours)

**Priority**: HIGH - Should complete before production

**P1-1: Add Middleware** (3h)
- [ ] Import `metrics.Server()` and `tracing.Server()`
- [ ] Add to middleware list in `http.go`
- [ ] Test `/metrics` endpoint
- [ ] Verify Jaeger traces
- [ ] Deploy to staging

**P1-2: Optimize Filtering** (3h)
- [ ] Review current JSONB filtering logic
- [ ] Enable/fix DB-level filtering
- [ ] Add indexes if needed
- [ ] Test with 1000+ promotions
- [ ] Measure performance improvement

**P1-3: Implement Workers** (3h)
- [ ] Create `internal/worker/outbox_worker.go`
- [ ] Update `internal/worker/workers.go`
- [ ] Wire dependencies in `cmd/worker/wire.go`
- [ ] Test worker startup
- [ ] Verify event processing

---

## ✅ Success Criteria

### Phase 1 Complete When
- [ ] All JSON unmarshal calls have error handling
- [ ] Usage limits enforced atomically
- [ ] Outbox table created and working
- [ ] Events guaranteed delivered
- [ ] All P0 tests passing
- [ ] No race conditions detected

### Phase 2 Complete When
- [ ] Metrics middleware active
- [ ] Tracing spans visible in Jaeger
- [ ] DB filtering optimized
- [ ] Outbox worker running
- [ ] All P1 tests passing

### Overall Complete When
- [ ] Score ≥ 9.0/10
- [ ] All P0 + P1 issues fixed
- [ ] Integration tests passing
- [ ] Deployed to staging
- [ ] Team signs off

---

## 📚 Production Readiness

### Current Status: ⚠️ NOT PRODUCTION READY
**Blockers**: 3 P0 issues must be fixed

### Timeline to Production
- **Phase 1 (P0)**: 18 hours → 2-3 business days
- **Phase 2 (P1)**: 9 hours → 1-2 business days
- **Total**: 27 hours → 4-5 business days

### Risk Assessment
- **High Risk**: Event loss (P0-3), race conditions (P0-2)
- **Medium Risk**: Security (P0-1), observability (P1-1)
- **Low Risk**: Performance (P1-2), workers (P1-3)

---


## 🔍 Code Locations

**Key Files**:
- `internal/server/http.go` - HTTP setup (P1-1 fix here)
- `internal/biz/promotion.go` - Business logic (P0-2, P0-3 fixes here)
- `internal/data/promotion.go` - Data layer (P0-1, P0-2 fixes here)
- `internal/data/campaign.go` - Campaign data (P0-1 fix here)
- `internal/data/coupon.go` - Coupon data (P0-1 fix here)
- `internal/service/promotion.go` - Service layer (P0-1 fix here)
- `internal/worker/workers.go` - Worker setup (P1-3 fix here)
- `cmd/worker/main.go` - Worker entry point

---

## 💡 Reference Implementation

**For Transactional Outbox**:
- See `catalog/internal/biz/product/product_write.go:40-76`
- See `catalog/internal/worker/outbox_worker.go`
- See `catalog/migrations/026_create_outbox_events_table.sql`

**For Middleware Stack**:
- See `catalog/internal/server/http.go:48-52`

**For Worker Patterns**:
- See `catalog/cmd/worker/main.go`

---

## ❓ FAQ

**Q: Can we deploy now?**  
A: NO. 3 P0 issues are critical blockers.

**Q: What's the biggest risk?**  
A: P0-3 (Event loss) and P0-2 (Race conditions) are highest risk.

**Q: How long to fix?**  
A: 18 hours for P0 issues (critical), 9 hours for P1 issues (recommended).

**Q: Should we copy catalog's outbox?**  
A: YES! Catalog has working reference implementation.

**Q: What about tests?**  
A: No tests found. Should add after P0 fixes.

---

## 📝 Comparison with Catalog Service

| Feature | Catalog | Promotion | Gap |
|---------|---------|-----------|-----|
| Transactional Outbox | ✅ | ❌ | P0-3 |
| Middleware Stack | ✅ | ❌ | P1-1 |
| JSON Error Handling | ✅ | ❌ | P0-1 |
| Atomic Operations | ✅ | ❌ | P0-2 |
| Worker Implementation | ✅ | ❌ | P1-3 |
| DB Query Optimization | ✅ | ⚠️ | P1-2 |
| Test Coverage | ✅ | ❌ | Future |
| Overall Score | 100% | 75% | -25% |

---

## 📋 Detailed Checklist

### P0-1: JSON Error Handling ✓
- [ ] `internal/data/promotion.go:326-332` (7 calls)
- [ ] `internal/data/campaign.go:194-195` (2 calls)
- [ ] `internal/data/coupon.go:279-280` (2 calls)
- [ ] `internal/data/promotion_usage.go:178` (1 call)
- [ ] `internal/service/promotion.go:140-154` (5 calls)
- [ ] Add error logging for all failures
- [ ] Add safe defaults for non-critical fields
- [ ] Return errors for critical fields (Conditions, Actions)
- [ ] Test with malformed JSON payloads
- [ ] Verify no panics occur

### P0-2: Atomic Usage Limits ✓
- [ ] Define `IncrementUsageAtomic` in `biz.PromotionRepo`
- [ ] Implement with row locking in `data.promotionRepo`
- [ ] Check total usage limit atomically
- [ ] Check per-customer usage limit atomically
- [ ] Increment counter atomically
- [ ] Add error types: `ErrUsageLimitExceeded`, `ErrCustomerUsageLimitExceeded`
- [ ] Update `ValidatePromotions` to call atomic method
- [ ] Write concurrent test (20 requests, limit=10)
- [ ] Verify exactly 10 succeed
- [ ] Verify final count = 10

### P0-3: Transactional Outbox ✓
- [ ] Create `migrations/010_create_outbox_events_table.sql`
- [ ] Create `internal/data/outbox.go` with models
- [ ] Implement `OutboxRepo` interface
- [ ] Add `outboxRepo` to `PromotionUseCase`
- [ ] Update `CreateCampaign` to write to outbox
- [ ] Update `CreatePromotion` to write to outbox
- [ ] Update `GenerateBulkCoupons` to write to outbox
- [ ] Create `internal/worker/outbox_worker.go`
- [ ] Implement event polling (1s interval)
- [ ] Implement event publishing
- [ ] Implement retry logic (exponential backoff)
- [ ] Implement DLQ for failed events
- [ ] Update `cmd/worker/wire.go` to include outbox worker
- [ ] Test: Create campaign → verify outbox event
- [ ] Test: Worker processes event → verify COMPLETED
- [ ] Test: Kill service after commit → verify event still published

### P1-1: Middleware Stack ✓
- [ ] Import `metrics.Server()` from kratos
- [ ] Import `tracing.Server()` from kratos
- [ ] Add to middleware list in `http.go`
- [ ] Build service
- [ ] Run service
- [ ] Test `/metrics` endpoint
- [ ] Verify Prometheus format
- [ ] Test Jaeger tracing
- [ ] Verify spans appear
- [ ] Deploy to staging

### P1-2: Query Optimization ✓
- [ ] Review `GetActivePromotions` implementation
- [ ] Verify JSONB filtering logic
- [ ] Enable DB-level filtering for products
- [ ] Enable DB-level filtering for categories
- [ ] Enable DB-level filtering for brands
- [ ] Add GIN indexes if missing
- [ ] Test with 1000 promotions
- [ ] Measure query time (target <50ms)
- [ ] Run EXPLAIN ANALYZE
- [ ] Verify index usage

### P1-3: Worker Implementation ✓
- [ ] Create `internal/worker/outbox_worker.go`
- [ ] Implement `Name()` method
- [ ] Implement `Start()` method
- [ ] Implement `Stop()` method
- [ ] Implement `HealthCheck()` method
- [ ] Add event polling logic
- [ ] Add event publishing logic
- [ ] Add error handling
- [ ] Add metrics collection
- [ ] Update `internal/worker/workers.go`
- [ ] Update `cmd/worker/wire.go`
- [ ] Test worker startup
- [ ] Test event processing
- [ ] Test graceful shutdown

---

**Document Version**: 1.0  
**Last Updated**: January 14, 2026  
**Status**: ⚠️ NOT PRODUCTION READY - Requires P0 Fixes  
**Next Phase**: Implementation of P0-1, P0-2, P0-3


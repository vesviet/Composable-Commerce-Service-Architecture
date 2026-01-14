# 💳 PAYMENT SERVICE REVIEW

**Review Date**: January 14, 2026  
**Reviewer**: Principal Developer (Cascade)  
**Service**: Payment (Payment Processing + Gateway Integration + Refunds)  
**Score**: 70% | **Issues**: 7 (3 P0, 4 P1)
**Est. Fix Time**: 27 hours

---

## 📋 Executive Summary

Payment service has good architecture and idempotency handling but has **3 critical P0 issues** that must be fixed before production:

**Critical Issues**:
1. **P0-1**: Dual-write problem - DB write then event publish (event loss risk)
2. **P0-2**: Idempotency check continues on failure (double charge risk)
3. **P0-3**: Repository methods return nil without implementation (ghost charges)

**Good News**:
- Idempotency service implemented ✅
- Fraud detection integrated ✅
- Clean gateway abstraction ✅
- Transaction management ✅
- Comprehensive validation ✅

**Status**: ⚠️ **NOT PRODUCTION READY** - Requires P0 fixes

---

## ✅ What's Excellent

### 1. Idempotency Service Implemented ✅
**Status**: Well-designed | **Impact**: Prevents duplicate charges

**Features**:
- Redis-based idempotency key storage
- 24-hour TTL for idempotency keys
- CheckAndStore pattern
- Graceful degradation when Redis unavailable

**Location**: `internal/biz/common/idempotency.go`

**Rubric Compliance**: ✅ #3 (Business Logic - Idempotency)


### 2. Fraud Detection Integration ✅
**Status**: Comprehensive | **Impact**: Risk mitigation

**Features**:
- Fraud score calculation
- Risk status (low/medium/high/blocked)
- Geographic data analysis
- Payment history analysis
- Device fingerprinting

**Rubric Compliance**: ✅ #5 (Security)

---

### 3. Clean Gateway Abstraction ✅
**Status**: Well-architected | **Impact**: Easy to add new gateways

**Pattern**:
- Gateway factory pattern
- Provider-agnostic interface
- Supports multiple providers (Stripe, PayPal, VNPay, MoMo)
- Standardized error handling

**Rubric Compliance**: ✅ #1 (Architecture & Clean Code)

---

### 4. Transaction Management ✅
**Status**: Proper transaction boundaries
- Uses TransactionFunc abstraction
- Wraps payment + transaction creation
- Atomic operations

**Rubric Compliance**: ✅ #4 (Data Layer - Transaction Boundaries)

---

### 5. Comprehensive Validation ✅
**Status**: Robust validation | **Impact**: Data integrity

**Features**:
- Order validation
- Customer validation
- Payment method validation
- Amount validation (min/max)
- Currency validation
- Expiry checks

**Rubric Compliance**: ✅ #2 (API & Contract - Validation)

---

## 🚨 Critical Issues (3 P0 + 4 P1)


### P0-1: Dual-Write Problem - Missing Transactional Outbox (10h) ⚠️

**Files**: 
- `internal/biz/payment/usecase.go:233-310` (ProcessPayment)
- `internal/biz/payment/usecase.go:315-380` (CapturePayment)
- `internal/biz/refund/usecase.go:93-150` (ProcessRefund)

**Severity**: 🔴 CRITICAL  
**Impact**: Event loss on crashes - events published AFTER DB commit

**Current State**:
```go
// ❌ DUAL-WRITE PROBLEM - EVENTS CAN BE LOST!
err = uc.transaction(ctx, func(ctx context.Context) error {
    // 1. Create payment
    if err := uc.paymentRepo.Create(ctx, payment); err != nil {
        return err
    }
    
    // 2. Process via gateway
    gatewayResult, err := paymentGateway.ProcessPayment(ctx, payment, paymentMethod)
    // ... update payment ...
    
    // 3. Create transaction record
    if err := uc.transactionRepo.Create(ctx, txn); err != nil {
        return err
    }
    
    return nil
})
// ← Transaction committed here

// 4. Publish event AFTER commit (OUTSIDE transaction)
if payment.Status == PaymentStatusAuthorized || payment.Status == PaymentStatusCaptured {
    if err := uc.eventPublisher.PublishPaymentProcessed(ctx, payment.PaymentID, req.OrderID, payment.Amount, payment.Currency); err != nil {
        uc.log.WithContext(ctx).Warnf("Failed to publish payment processed event: %v", err)
        // ← If crash here, event is LOST but payment is SAVED!
    }
}
```

**Problem**:
- DB write and event publish are NOT atomic
- If service crashes between commit and publish → event lost
- Order service never notified of payment success
- Order stuck in "pending payment" state forever
- **Financial Impact**: Customer charged but order not fulfilled

**Fix** (10 hours) - Implement Transactional Outbox:

**Step 1**: Create outbox table migration
```sql
-- migrations/008_create_outbox_events_table.sql
CREATE TABLE outbox_events (
    id BIGSERIAL PRIMARY KEY,
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 5,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    
    INDEX idx_outbox_status (status, created_at),
    INDEX idx_outbox_aggregate (aggregate_type, aggregate_id)
);
```

**Step 2**: Update ProcessPayment to use Outbox
```go
// ✅ ATOMIC DB + OUTBOX WRITE
err = uc.transaction(ctx, func(ctx context.Context) error {
    // 1. Create payment
    if err := uc.paymentRepo.Create(ctx, payment); err != nil {
        return err
    }
    
    // 2. Process via gateway
    gatewayResult, err := paymentGateway.ProcessPayment(ctx, payment, paymentMethod)
    // ... update payment ...
    
    // 3. Create transaction record
    if err := uc.transactionRepo.Create(ctx, txn); err != nil {
        return err
    }
    
    // 4. Create outbox event IN SAME TRANSACTION
    if payment.Status == PaymentStatusAuthorized || payment.Status == PaymentStatusCaptured {
        payload, _ := json.Marshal(map[string]interface{}{
            "payment_id": payment.PaymentID,
            "order_id":   req.OrderID,
            "amount":     payment.Amount,
            "currency":   payment.Currency,
        })
        
        event := &OutboxEvent{
            AggregateType: "payment",
            AggregateID:   payment.PaymentID,
            EventType:     "payment.processed",
            Payload:       payload,
            Status:        "PENDING",
        }
        
        return uc.outboxRepo.Create(ctx, event)
        // ← All succeed or all fail together!
    }
    
    return nil
})
```

**Step 3**: Create Outbox Worker (already have worker structure)
```go
// internal/worker/event/outbox_worker.go
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
```

**Reference**: See `catalog/internal/biz/product/product_write.go:40-76` for working implementation

**Testing**:
- [ ] Create payment → verify outbox event created
- [ ] Worker processes event → verify status=COMPLETED
- [ ] Kill service after DB commit → verify event still published
- [ ] Verify no duplicate events

**Rubric Violation**: #4 (Data Layer - Transaction Boundaries), #3 (Business Logic - Concurrency)

---


### P0-2: Idempotency Check Continues on Failure (6h) ⚠️

**File**: `internal/biz/payment/usecase.go:95-105`  
**Severity**: 🔴 CRITICAL  
**Impact**: Double charge risk - idempotency check failure allows duplicate processing

**Current State**:
```go
// ❌ CONTINUES ON IDEMPOTENCY FAILURE - DANGEROUS!
if req.IdempotencyKey != "" {
    exists, cachedResult, err := uc.idempotencyService.CheckAndStore(ctx, req.IdempotencyKey, nil)
    if err != nil {
        uc.log.WithContext(ctx).Warnf("Idempotency check failed: %v, continuing with processing", err)
        // ← CONTINUES PROCESSING! Should return 409 Conflict
    } else if exists {
        // Return cached result
        if cachedPayment, ok := cachedResult.(*Payment); ok {
            return cachedPayment, nil
        }
        uc.log.WithContext(ctx).Warnf("Cached result is not a Payment, continuing with processing")
        // ← CONTINUES PROCESSING! Should return error
    }
}
```

**Problem**:
- If idempotency check fails (Redis down, network error) → continues processing
- If cached result exists but wrong type → continues processing
- Two concurrent requests with same idempotency key can both succeed
- **Financial Impact**: Customer charged twice for same order

**Scenario**:
1. Request 1 arrives with idempotency_key="abc123"
2. Redis is temporarily down
3. Idempotency check fails → logs warning → continues
4. Payment processed → customer charged
5. Request 2 arrives with same idempotency_key="abc123"
6. Redis still down
7. Idempotency check fails → logs warning → continues
8. Payment processed AGAIN → customer charged TWICE

**Fix** (6 hours):
```go
// ✅ FAIL-CLOSED ON IDEMPOTENCY ERRORS
if req.IdempotencyKey != "" {
    exists, cachedResult, err := uc.idempotencyService.CheckAndStore(ctx, req.IdempotencyKey, nil)
    if err != nil {
        // CRITICAL: Don't process if idempotency check fails
        uc.log.WithContext(ctx).Errorf("Idempotency check failed: %v", err)
        return nil, fmt.Errorf("idempotency check failed, cannot process payment safely: %w", err)
    }
    
    if exists {
        // Return cached result
        if cachedPayment, ok := cachedResult.(*Payment); ok {
            uc.log.WithContext(ctx).Infof("Returning cached payment result for idempotency key: %s", req.IdempotencyKey)
            return cachedPayment, nil
        }
        
        // If cached result exists but wrong type, return error
        uc.log.WithContext(ctx).Errorf("Cached result exists but is not a Payment for key: %s", req.IdempotencyKey)
        return nil, fmt.Errorf("idempotency key already used with different operation type")
    }
}
```

**Alternative**: Implement fallback to database-based idempotency
```go
// If Redis fails, check database for duplicate payment_id
if err != nil {
    uc.log.WithContext(ctx).Warnf("Redis idempotency check failed, falling back to DB: %v", err)
    
    // Check if payment with this idempotency key already exists in DB
    existingPayment, dbErr := uc.paymentRepo.FindByIdempotencyKey(ctx, req.IdempotencyKey)
    if dbErr == nil && existingPayment != nil {
        return existingPayment, nil
    }
    
    // If DB check also fails, MUST fail the request
    if dbErr != nil && dbErr != ErrNotFound {
        return nil, fmt.Errorf("idempotency check failed (Redis and DB): %w", dbErr)
    }
}
```

**Implementation Steps**:
1. Change idempotency check to fail-closed
2. Add database fallback for idempotency
3. Add `idempotency_key` column to payments table
4. Add unique index on `idempotency_key`
5. Add `FindByIdempotencyKey` to PaymentRepository
6. Add integration test with concurrent requests
7. Add monitoring alert for idempotency failures

**Testing**:
- [ ] Simulate Redis failure → verify payment rejected
- [ ] Send duplicate request → verify 409 Conflict
- [ ] Send concurrent requests with same key → verify only one succeeds
- [ ] Verify cached result type checking works

**Rubric Violation**: #3 (Business Logic - Idempotency), #5 (Security)

---


### P0-3: Repository Methods Return Nil Without Implementation (8h) ⚠️

**File**: `internal/repository/payment/payment.go:25-70`  
**Severity**: 🔴 CRITICAL  
**Impact**: Ghost charges - payments created in gateway but not saved in DB

**Current State**:
```go
// ❌ ALL METHODS RETURN NIL - NO IMPLEMENTATION!
func (r *PaymentRepository) Create(ctx context.Context, payment *payment.Payment) error {
    return nil  // ← DOES NOTHING!
}

func (r *PaymentRepository) FindByID(ctx context.Context, id int64) (*payment.Payment, error) {
    return nil, nil  // ← ALWAYS RETURNS NIL!
}

func (r *PaymentRepository) Update(ctx context.Context, payment *payment.Payment) error {
    return nil  // ← DOES NOTHING!
}

// ... all other methods also return nil ...
```

**Problem**:
- Repository methods are stubs - no actual database operations
- `Create` returns success but doesn't save to database
- `FindByID` always returns nil (payment not found)
- `Update` returns success but doesn't update database
- **Financial Impact**: 
  - Customer charged via gateway
  - Payment not saved in database
  - No record of transaction
  - Cannot issue refunds
  - Cannot track payment history

**Scenario**:
1. Customer submits payment
2. `ProcessPayment` calls `paymentRepo.Create(ctx, payment)`
3. Repository returns `nil` (success) but doesn't save
4. Gateway processes payment → customer charged
5. Service returns success to customer
6. Later: Customer requests refund
7. `FindByPaymentID` returns nil → payment not found
8. Cannot process refund → customer support nightmare

**Fix** (8 hours) - Implement all repository methods:

```go
// ✅ PROPER IMPLEMENTATION
func (r *PaymentRepository) Create(ctx context.Context, payment *payment.Payment) error {
    model := convertToModel(payment)
    
    if err := r.data.DB(ctx).Create(model).Error; err != nil {
        r.log.Errorf("Failed to create payment: %v", err)
        return fmt.Errorf("failed to create payment: %w", err)
    }
    
    // Update payment with generated ID
    payment.ID = model.ID
    payment.CreatedAt = model.CreatedAt
    payment.UpdatedAt = model.UpdatedAt
    
    return nil
}

func (r *PaymentRepository) FindByID(ctx context.Context, id int64) (*payment.Payment, error) {
    var model PaymentModel
    
    if err := r.data.DB(ctx).Where("id = ?", id).First(&model).Error; err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, ErrPaymentNotFound
        }
        r.log.Errorf("Failed to find payment by ID: %v", err)
        return nil, fmt.Errorf("failed to find payment: %w", err)
    }
    
    return convertToDomain(&model), nil
}

func (r *PaymentRepository) Update(ctx context.Context, payment *payment.Payment) error {
    model := convertToModel(payment)
    
    result := r.data.DB(ctx).Model(&PaymentModel{}).
        Where("id = ?", payment.ID).
        Updates(model)
    
    if result.Error != nil {
        r.log.Errorf("Failed to update payment: %v", result.Error)
        return fmt.Errorf("failed to update payment: %w", result.Error)
    }
    
    if result.RowsAffected == 0 {
        return ErrPaymentNotFound
    }
    
    return nil
}

// Implement all other methods similarly...
```

**Implementation Steps**:
1. Create `PaymentModel` struct for GORM
2. Implement `convertToModel` and `convertToDomain` functions
3. Implement all 14 repository methods
4. Add proper error handling
5. Add database indexes
6. Write unit tests for each method
7. Write integration tests with real database

**Testing**:
- [ ] Create payment → verify saved in DB
- [ ] Find payment → verify correct data returned
- [ ] Update payment → verify changes persisted
- [ ] Test all query methods
- [ ] Test error cases (not found, duplicate, etc.)

**Rubric Violation**: #4 (Data Layer - Repository Pattern), #1 (Architecture - Implementation)

---


### P1-1: Missing Standard Middleware Stack (3h) ⚠️

**File**: `internal/server/http.go:32-40`  
**Severity**: 🟡 HIGH  
**Impact**: No metrics collection, no distributed tracing

**Current State**:
```go
// ❌ MISSING METRICS AND TRACING
var opts = []krathttp.ServerOption{
    krathttp.Middleware(
        recovery.Recovery(),
        metadata.Server(
            metadata.WithPropagatedPrefix("x-md-", "x-client-", "x-user-"),
        ),
        // ❌ MISSING: metrics.Server()
        // ❌ MISSING: tracing.Server()
    ),
}
```

**Problem**:
- No `metrics.Server()` → Prometheus metrics not collected
- No `tracing.Server()` → No OpenTelemetry spans
- Cannot trace payment flows across services
- Cannot monitor payment latency/errors
- Cannot debug payment failures

**Fix** (3 hours):
```go
// ✅ ADD STANDARD MIDDLEWARE STACK
import (
    "github.com/go-kratos/kratos/v2/middleware/metrics"
    "github.com/go-kratos/kratos/v2/middleware/tracing"
)

var opts = []krathttp.ServerOption{
    krathttp.Middleware(
        recovery.Recovery(),
        metadata.Server(
            metadata.WithPropagatedPrefix("x-md-", "x-client-", "x-user-"),
        ),
        metrics.Server(),      // ← ADD THIS
        tracing.Server(),      // ← ADD THIS
    ),
}
```

**Testing**:
- [ ] Build: `make build`
- [ ] Run: `make run`
- [ ] Metrics: `curl http://localhost:8004/metrics | grep http_requests`
- [ ] Tracing: Check Jaeger for "payment" service spans

**Rubric Violation**: #7 (Observability - Metrics & Tracing)

---

### P1-2: PCI Compliance Risk - CardLast4 in Generic Struct (4h) ⚠️

**File**: `internal/biz/payment/payment.go:40-42`  
**Severity**: 🟡 HIGH  
**Impact**: PCI compliance violation risk

**Current State**:
```go
// ⚠️ CARD DATA IN GENERIC PAYMENT STRUCT
type Payment struct {
    // ... other fields ...
    
    // Card details (for display, tokenized)
    CardLast4 string  // ← Should be in separate secure table
    CardBrand string  // ← Should be in separate secure table
    
    // 3D Secure
    ThreeDSStatus string
    ThreeDSToken  string
}
```

**Problem**:
- Card data stored in main payments table
- Logged in application logs
- Included in API responses
- May violate PCI DSS requirements
- Risk of card data exposure

**Fix** (4 hours):
```go
// ✅ SEPARATE CARD DATA
type Payment struct {
    // ... other fields ...
    PaymentMethodID int64  // Reference to payment method
    // Remove CardLast4, CardBrand from here
}

type PaymentMethod struct {
    ID         int64
    CustomerID int64
    Type       string
    Provider   string
    Token      string  // Gateway token (PCI compliant)
    CardLast4  string  // Only last 4 digits
    CardBrand  string
    // ... other fields ...
}
```

**Implementation Steps**:
1. Remove card fields from Payment struct
2. Always use PaymentMethodID reference
3. Fetch card display data from PaymentMethod when needed
4. Update API responses to not include card data
5. Add PCI compliance documentation
6. Audit logs for card data exposure

**Testing**:
- [ ] Verify no card data in payment logs
- [ ] Verify API responses don't include card data
- [ ] Verify card data only in payment_methods table
- [ ] Run PCI compliance scan

**Rubric Violation**: #5 (Security - PCI Compliance)

---

### P1-3: No Webhook Reconciliation (5h) ⚠️

**File**: `internal/biz/payment/usecase.go` (missing method)  
**Severity**: 🟡 HIGH  
**Impact**: Stuck pending payments not reconciled

**Problem**:
- Payments can get stuck in "pending" or "authorized" status
- No automatic reconciliation with gateway
- Manual intervention required
- Poor customer experience

**Fix** (5 hours) - Implement Webhook Reconciliation:

```go
// ✅ WEBHOOK RECONCILIATION
func (uc *PaymentUsecase) ReconcilePayment(ctx context.Context, paymentID string) error {
    // 1. Get payment from DB
    payment, err := uc.paymentRepo.FindByPaymentID(ctx, paymentID)
    if err != nil {
        return err
    }
    
    // 2. Check if payment is in reconcilable state
    if payment.IsFinalStatus() {
        return nil // Already in final state
    }
    
    // 3. Get gateway
    gateway, err := uc.gatewayFactory.GetGateway(payment.PaymentProvider)
    if err != nil {
        return err
    }
    
    // 4. Query gateway for payment status
    gatewayStatus, err := gateway.GetPaymentStatus(ctx, payment.GatewayPaymentID)
    if err != nil {
        return err
    }
    
    // 5. Update payment status based on gateway status
    if gatewayStatus.Status != string(payment.Status) {
        payment.Status = PaymentStatus(gatewayStatus.Status)
        payment.UpdatedAt = time.Now()
        
        if err := uc.paymentRepo.Update(ctx, payment); err != nil {
            return err
        }
        
        // Publish status change event
        uc.publishStatusChangeEvent(ctx, payment)
    }
    
    return nil
}

// Scheduled job to reconcile stuck payments
func (uc *PaymentUsecase) ReconcileStuckPayments(ctx context.Context) (int, error) {
    // Find payments stuck in pending/authorized for > 1 hour
    cutoff := time.Now().Add(-1 * time.Hour)
    stuckPayments, err := uc.paymentRepo.FindStuckPayments(ctx, cutoff)
    if err != nil {
        return 0, err
    }
    
    successCount := 0
    for _, payment := range stuckPayments {
        if err := uc.ReconcilePayment(ctx, payment.PaymentID); err != nil {
            uc.log.Errorf("Failed to reconcile payment %s: %v", payment.PaymentID, err)
            continue
        }
        successCount++
    }
    
    return successCount, nil
}
```

**Implementation Steps**:
1. Add `GetPaymentStatus` to gateway interface
2. Implement for all gateways (Stripe, PayPal, etc.)
3. Add `ReconcilePayment` method to usecase
4. Add `ReconcileStuckPayments` scheduled job
5. Add `FindStuckPayments` to repository
6. Add cron worker to run reconciliation every 5 minutes
7. Add metrics for reconciliation

**Testing**:
- [ ] Create stuck payment → verify reconciliation works
- [ ] Test with different gateway statuses
- [ ] Verify events published on status change
- [ ] Test scheduled job

**Rubric Violation**: #9 (Configuration - Resilience)

---

### P1-4: No Metrics Endpoint Registered (2h) ⚠️

**File**: `internal/server/http.go` (missing)  
**Severity**: 🟡 HIGH  
**Impact**: Cannot monitor payment service

**Problem**:
- No `/metrics` endpoint registered
- Cannot collect Prometheus metrics
- Cannot monitor payment processing
- Cannot alert on failures

**Fix** (2 hours):
```go
// ✅ ADD METRICS ENDPOINT
import "github.com/prometheus/client_golang/prometheus/promhttp"

// In NewHTTPServer function
srv.HandleFunc("/metrics", promhttp.Handler().ServeHTTP)
logHelper.Infof("✅ Registered Prometheus metrics endpoint at /metrics")
```

**Testing**:
- [ ] Run service
- [ ] Curl `/metrics` endpoint
- [ ] Verify Prometheus format
- [ ] Verify payment-specific metrics

**Rubric Violation**: #7 (Observability - Metrics)

---


## 📊 Rubric Compliance Matrix

| Rubric Item | Score | Status | Notes |
|-------------|-------|--------|-------|
| 1️⃣ Architecture & Clean Code | 8/10 | ✅ | Clean DDD, gateway abstraction |
| 2️⃣ API & Contract | 8/10 | ✅ | Good validation, proto standards |
| 3️⃣ Business Logic & Concurrency | 5/10 | ⚠️ | P0-1: No outbox, P0-2: Idempotency issues |
| 4️⃣ Data Layer & Persistence | 3/10 | ⚠️ | P0-3: Repository not implemented |
| 5️⃣ Security | 6/10 | ⚠️ | P0-2: Double charge risk, P1-2: PCI compliance |
| 6️⃣ Performance & Scalability | 7/10 | ⚠️ | Good design, needs implementation |
| 7️⃣ Observability | 5/10 | ⚠️ | P1-1: Missing middleware, P1-4: No metrics |
| 8️⃣ Testing & Quality | 4/10 | ⚠️ | Some tests, needs more coverage |
| 9️⃣ Configuration & Resilience | 6/10 | ⚠️ | P1-3: No reconciliation |
| 🔟 Documentation & Maintenance | 7/10 | ✅ | Good README |
| **OVERALL** | **5.9/10** | **⚠️** | **NOT PRODUCTION READY** |

---

## 🚀 Implementation Roadmap

### Phase 1: Fix P0 Issues (24 hours)

**Priority**: CRITICAL - Must complete before production

**P0-1: Transactional Outbox** (10h)
- [ ] Create migration `008_create_outbox_events_table.sql`
- [ ] Create `internal/biz/outbox/outbox.go` with OutboxRepo
- [ ] Update `ProcessPayment` to write to outbox
- [ ] Update `CapturePayment` to write to outbox
- [ ] Update `ProcessRefund` to write to outbox
- [ ] Create `internal/worker/event/outbox_worker.go`
- [ ] Wire outbox worker in `cmd/worker/wire.go`
- [ ] Test event delivery guarantees

**P0-2: Fix Idempotency** (6h)
- [ ] Change idempotency check to fail-closed
- [ ] Add `idempotency_key` column to payments table
- [ ] Add unique index on `idempotency_key`
- [ ] Add `FindByIdempotencyKey` to PaymentRepository
- [ ] Implement database fallback for idempotency
- [ ] Add integration test with concurrent requests
- [ ] Add monitoring alert for idempotency failures

**P0-3: Implement Repository** (8h)
- [ ] Create `PaymentModel` struct for GORM
- [ ] Implement `convertToModel` and `convertToDomain`
- [ ] Implement all 14 repository methods
- [ ] Add proper error handling
- [ ] Add database indexes
- [ ] Write unit tests for each method
- [ ] Write integration tests with real database

---

### Phase 2: Fix P1 Issues (14 hours)

**Priority**: HIGH - Should complete before production

**P1-1: Add Middleware** (3h)
- [ ] Import `metrics.Server()` and `tracing.Server()`
- [ ] Add to middleware list in `http.go`
- [ ] Test `/metrics` endpoint
- [ ] Verify Jaeger traces
- [ ] Deploy to staging

**P1-2: PCI Compliance** (4h)
- [ ] Remove card fields from Payment struct
- [ ] Update API responses
- [ ] Audit logs for card data
- [ ] Add PCI compliance documentation
- [ ] Run PCI compliance scan

**P1-3: Webhook Reconciliation** (5h)
- [ ] Add `GetPaymentStatus` to gateway interface
- [ ] Implement for all gateways
- [ ] Add `ReconcilePayment` method
- [ ] Add `ReconcileStuckPayments` scheduled job
- [ ] Add `FindStuckPayments` to repository
- [ ] Add cron worker
- [ ] Test reconciliation

**P1-4: Metrics Endpoint** (2h)
- [ ] Register `/metrics` endpoint
- [ ] Add payment-specific metrics
- [ ] Test Prometheus scraping
- [ ] Add Grafana dashboard

---

## ✅ Success Criteria

### Phase 1 Complete When
- [ ] Outbox table created and working
- [ ] Events guaranteed delivered
- [ ] Idempotency enforced (no double charges)
- [ ] All repository methods implemented
- [ ] All P0 tests passing
- [ ] No ghost charges possible

### Phase 2 Complete When
- [ ] Metrics middleware active
- [ ] Tracing spans visible in Jaeger
- [ ] PCI compliance verified
- [ ] Webhook reconciliation working
- [ ] Metrics endpoint active
- [ ] All P1 tests passing

### Overall Complete When
- [ ] Score ≥ 9.0/10
- [ ] All P0 + P1 issues fixed
- [ ] Integration tests passing
- [ ] Load tests passing
- [ ] PCI compliance audit passed
- [ ] Deployed to staging
- [ ] Team signs off

---

## 📚 Production Readiness

### Current Status: ⚠️ NOT PRODUCTION READY
**Blockers**: 3 P0 issues must be fixed

### Timeline to Production
- **Phase 1 (P0)**: 24 hours → 3 business days
- **Phase 2 (P1)**: 14 hours → 2 business days
- **Total**: 38 hours → 5 business days

### Risk Assessment
- **Critical Risk**: Ghost charges (P0-3), double charges (P0-2), event loss (P0-1)
- **High Risk**: PCI compliance (P1-2), no reconciliation (P1-3)
- **Medium Risk**: Observability (P1-1, P1-4)

---

## 🔍 Code Locations

**Key Files**:
- `internal/server/http.go` - HTTP setup (P1-1, P1-4 fixes here)
- `internal/biz/payment/usecase.go` - Business logic (P0-1, P0-2 fixes here)
- `internal/repository/payment/payment.go` - Data layer (P0-3 fix here)
- `internal/biz/payment/payment.go` - Domain model (P1-2 fix here)
- `internal/worker/event/` - Worker setup (P0-1, P1-3 fixes here)
- `cmd/worker/main.go` - Worker entry point

---

## 💡 Reference Implementation

**For Transactional Outbox**:
- See `catalog/internal/biz/product/product_write.go:40-76`
- See `catalog/internal/worker/outbox_worker.go`
- See `catalog/migrations/026_create_outbox_events_table.sql`

**For Middleware Stack**:
- See `catalog/internal/server/http.go:48-52`

**For Repository Implementation**:
- See `catalog/internal/repository/product/product.go`

---

## ❓ FAQ

**Q: Can we deploy now?**  
A: NO. 3 P0 issues are critical blockers, especially P0-3 (repository not implemented).

**Q: What's the biggest risk?**  
A: P0-3 (Ghost charges) is highest risk - payments processed but not saved.

**Q: How long to fix?**  
A: 24 hours for P0 issues (critical), 14 hours for P1 issues (recommended).

**Q: Should we copy catalog's outbox?**  
A: YES! Catalog has working reference implementation.

**Q: What about PCI compliance?**  
A: P1-2 needs attention. Card data should be in separate table.

---

## 📝 Comparison with Catalog Service

| Feature | Catalog | Payment | Gap |
|---------|---------|---------|-----|
| Transactional Outbox | ✅ | ❌ | P0-1 |
| Middleware Stack | ✅ | ❌ | P1-1 |
| Repository Implementation | ✅ | ❌ | P0-3 |
| Idempotency Handling | ✅ | ⚠️ | P0-2 |
| Worker Implementation | ✅ | ⚠️ | P0-1, P1-3 |
| Metrics Endpoint | ✅ | ❌ | P1-4 |
| Test Coverage | ✅ | ⚠️ | Future |
| Overall Score | 100% | 70% | -30% |

---

## 📋 Detailed Checklist

### P0-1: Transactional Outbox ✓
- [ ] Create `migrations/008_create_outbox_events_table.sql`
- [ ] Create `internal/biz/outbox/outbox.go`
- [ ] Define `OutboxEvent` struct
- [ ] Define `OutboxRepo` interface
- [ ] Implement `OutboxRepo` in data layer
- [ ] Update `ProcessPayment` to write to outbox
- [ ] Update `CapturePayment` to write to outbox
- [ ] Update `VoidPayment` to write to outbox
- [ ] Update `ProcessRefund` to write to outbox
- [ ] Create `internal/worker/event/outbox_worker.go`
- [ ] Implement event polling (1s interval)
- [ ] Implement event publishing
- [ ] Implement retry logic (exponential backoff)
- [ ] Implement DLQ for failed events
- [ ] Update `cmd/worker/wire.go`
- [ ] Test: Create payment → verify outbox event
- [ ] Test: Worker processes event → verify COMPLETED
- [ ] Test: Kill service after commit → verify event still published

### P0-2: Fix Idempotency ✓
- [ ] Change idempotency check to fail-closed
- [ ] Add `idempotency_key VARCHAR(255)` to payments table
- [ ] Add unique index on `idempotency_key`
- [ ] Add `FindByIdempotencyKey` to PaymentRepository interface
- [ ] Implement `FindByIdempotencyKey` in repository
- [ ] Implement database fallback in `ProcessPayment`
- [ ] Add error handling for duplicate idempotency key
- [ ] Write concurrent test (10 requests, same key)
- [ ] Verify only one succeeds
- [ ] Add monitoring alert for idempotency failures

### P0-3: Implement Repository ✓
- [ ] Create `PaymentModel` struct with GORM tags
- [ ] Implement `convertToModel` function
- [ ] Implement `convertToDomain` function
- [ ] Implement `Create` method
- [ ] Implement `FindByID` method
- [ ] Implement `FindByPaymentID` method
- [ ] Implement `FindByGatewayPaymentID` method
- [ ] Implement `Update` method
- [ ] Implement `UpdateStatus` method
- [ ] Implement `FindByOrderID` method
- [ ] Implement `FindByCustomerID` method
- [ ] Implement `FindByStatus` method
- [ ] Implement `FindByFilters` method
- [ ] Implement `CountByFilters` method
- [ ] Implement `FindPendingCaptures` method
- [ ] Add proper error handling to all methods
- [ ] Write unit tests for each method
- [ ] Write integration tests with real database

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

### P1-2: PCI Compliance ✓
- [ ] Remove `CardLast4` from Payment struct
- [ ] Remove `CardBrand` from Payment struct
- [ ] Update API responses
- [ ] Audit application logs
- [ ] Audit database queries
- [ ] Add PCI compliance documentation
- [ ] Run PCI compliance scan
- [ ] Fix any violations found

### P1-3: Webhook Reconciliation ✓
- [ ] Add `GetPaymentStatus` to gateway interface
- [ ] Implement for Stripe gateway
- [ ] Implement for PayPal gateway
- [ ] Implement for VNPay gateway
- [ ] Implement for MoMo gateway
- [ ] Add `ReconcilePayment` method to usecase
- [ ] Add `ReconcileStuckPayments` method to usecase
- [ ] Add `FindStuckPayments` to repository
- [ ] Create cron worker for reconciliation
- [ ] Add metrics for reconciliation
- [ ] Test reconciliation with stuck payment
- [ ] Test scheduled job

### P1-4: Metrics Endpoint ✓
- [ ] Register `/metrics` endpoint in `http.go`
- [ ] Add payment-specific metrics
- [ ] Test Prometheus scraping
- [ ] Create Grafana dashboard
- [ ] Add alerts for payment failures

---

**Document Version**: 1.0  
**Last Updated**: January 14, 2026  
**Status**: ⚠️ NOT PRODUCTION READY - Requires P0 Fixes  
**Next Phase**: Implementation of P0-1, P0-2, P0-3


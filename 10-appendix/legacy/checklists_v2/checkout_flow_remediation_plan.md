# 🚨 Checkout Flow P0 Remediation Plan

**Created**: 2026-01-22  
**Based on**: [checkout_flow_v2.md](checkout_flow_v2.md)  
**Status**: Production Blocker - Must Fix Before Deploy  
**Timeline**: 2-3 weeks (Sprint 1-2)  
**Priority**: P0 - Critical  

---

## 📊 Executive Summary

### Current State
- **Health Score**: 6/10 (Not Production-Ready)
- **P0 Issues**: 4 critical blockers
- **Impact**: Service cannot handle distributed transaction failures safely

### Target State
- **Health Score**: 8.5/10 (Production-Ready with monitoring)
- **P0 Issues**: 0 (All resolved)
- **Impact**: Robust checkout flow with proper error handling and recovery

### Success Criteria
- [ ] All P0 issues resolved and tested
- [ ] Distributed transaction failures handled gracefully
- [ ] Saga workers implemented and operational
- [ ] DLQ system for failed compensations
- [ ] Comprehensive integration tests passing
- [ ] Load testing with failure scenarios

---

## 🛠️ Detailed Fix Implementation

## 1. CHECKOUT-CONC-03: Add Timeouts to Payment Service Calls

### Problem
```go
// Current: No timeout - can hang indefinitely
authResp, err := uc.paymentService.AuthorizePayment(ctx, authReq)
```

### Solution
**File**: `order/internal/biz/checkout/payment.go`

**Implementation**:
```go
// Line 93: Add timeout wrapper
authCtx, cancel := uc.withServiceTimeout(ctx, PaymentServiceTimeout)
defer cancel()
authResp, err := uc.paymentService.AuthorizePayment(authCtx, authReq)

// Line 170: Add timeout for capture
captureCtx, cancel := context.WithTimeout(ctx, PaymentServiceTimeout)
defer cancel()
paymentResp, err := uc.paymentService.CapturePayment(captureCtx, captureReq)
```

**Verification**:
```bash
# Test: Configure payment service to delay 20s
# Expected: Checkout should timeout after 15s (PaymentServiceTimeout)
curl -X POST http://localhost:8080/api/v1/checkout/confirm \
  -H "X-Session-ID: test-session" \
  --max-time 20
# Should return timeout error within 15s
```

---

## 2. CHECKOUT-CONC-04: Implement DLQ for Failed Compensation

### Problem
```go
// Current: Compensation errors ignored
func handleRollbackAndAlert(...) {
    // Logs error but doesn't persist or alert
    uc.log.WithContext(ctx).Errorf("CRITICAL Failed to void authorization: %v", err)
}
```

### Solution

#### Step 1: Create Failed Compensation Table
**File**: `order/migrations/XXX_create_failed_compensations_table.sql`

```sql
CREATE TABLE failed_compensations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id VARCHAR(100) NOT NULL,
    operation_type VARCHAR(50) NOT NULL, -- 'void_authorization', 'release_reservations', 'refund'
    authorization_id VARCHAR(255),
    error_message TEXT NOT NULL,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'retrying', 'failed', 'resolved'
    alert_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for efficient querying
CREATE INDEX idx_failed_compensations_order ON failed_compensations(order_id);
CREATE INDEX idx_failed_compensations_status ON failed_compensations(status);
CREATE INDEX idx_failed_compensations_created ON failed_compensations(created_at);
```

#### Step 2: Update Compensation Handler
**File**: `order/internal/biz/checkout/confirm.go`

**Current** (Lines 303-318):
```go
func (uc *CheckoutUsecase) handleRollbackAndAlert(ctx context.Context, order *Order, authID string) {
    uc.log.WithContext(ctx).Errorf("CRITICAL Failed to void authorization: %v", err)

    // TODO: Send alert to on-call engineer
    // alertSvc := uc.alertService
    // alertSvc.SendCriticalAlert("Payment compensation failed", ...)
}
```

**New Implementation**:
```go
func (uc *CheckoutUsecase) handleRollbackAndAlert(ctx context.Context, order *Order, authID string, operationErr error) error {
    // Log critical error
    uc.log.WithContext(ctx).Errorf("CRITICAL Failed to void authorization for order %s: %v", order.ID, operationErr)

    // Persist to DLQ
    dlqRecord := &FailedCompensation{
        OrderID:        order.ID,
        OperationType:  "void_authorization",
        AuthorizationID: authID,
        ErrorMessage:   operationErr.Error(),
        Status:         "pending",
    }

    if err := uc.failedCompensationRepo.Create(ctx, dlqRecord); err != nil {
        uc.log.WithContext(ctx).Errorf("CRITICAL Failed to persist compensation failure to DLQ: %v", err)
        // Continue with alerting even if DLQ fails
    }

    // Send PagerDuty alert
    alertErr := uc.alertService.SendCriticalAlert(ctx, "Payment Compensation Failed", map[string]interface{}{
        "order_id":         order.ID,
        "customer_id":      order.CustomerID,
        "authorization_id": authID,
        "error":           operationErr.Error(),
        "dlq_recorded":    err == nil,
    })

    if alertErr != nil {
        uc.log.WithContext(ctx).Errorf("Failed to send compensation alert: %v", alertErr)
    }

    // Return error to ensure calling code knows compensation failed
    return fmt.Errorf("compensation failed: %w", operationErr)
}
```

#### Step 3: Create Admin UI for DLQ Management
**File**: `admin/src/pages/FailedCompensations.tsx`

```typescript
// Admin UI to view/retry failed compensations
const FailedCompensations = () => {
  const [compensations, setCompensations] = useState([]);

  const retryCompensation = async (id: string) => {
    try {
      await api.post(`/api/v1/admin/compensations/${id}/retry`);
      // Refresh list
      loadCompensations();
    } catch (error) {
      message.error('Retry failed');
    }
  };

  // Table showing: Order ID, Operation, Error, Retry Count, Actions
};
```

#### Step 4: Add DLQ Processing Worker
**File**: `order/internal/workers/failed_compensation_processor.go`

```go
func (w *FailedCompensationProcessor) Process(ctx context.Context) error {
    // Get pending compensations
    compensations, err := w.repo.GetPendingCompensations(ctx, 10)
    if err != nil {
        return err
    }

    for _, comp := range compensations {
        if err := w.processCompensation(ctx, comp); err != nil {
            w.log.Errorf("Failed to process compensation %s: %v", comp.ID, err)
        }
    }

    return nil
}

func (w *FailedCompensationProcessor) processCompensation(ctx context.Context, comp *FailedCompensation) error {
    // Retry logic with exponential backoff
    if comp.RetryCount >= comp.MaxRetries {
        // Mark as permanently failed
        return w.repo.UpdateStatus(ctx, comp.ID, "failed")
    }

    // Attempt retry based on operation type
    var err error
    switch comp.OperationType {
    case "void_authorization":
        err = w.retryVoidAuthorization(ctx, comp)
    case "release_reservations":
        err = w.retryReleaseReservations(ctx, comp)
    }

    if err != nil {
        // Increment retry count
        return w.repo.IncrementRetryCount(ctx, comp.ID)
    }

    // Success - mark as resolved
    return w.repo.UpdateStatus(ctx, comp.ID, "resolved")
}
```

**Verification**:
```bash
# Test: Trigger compensation failure
# 1. Mock payment service void to fail
# 2. Create order and trigger cancellation
# 3. Verify DLQ record created
kubectl exec -n dev -it deployment/postgres -- psql -U postgres -d order_db -c \
  "SELECT * FROM failed_compensations ORDER BY created_at DESC LIMIT 1;"

# 4. Check alert sent
# 5. Verify admin UI shows the failed compensation
```

---

## 3. CHECKOUT-CONC-02: Implement Saga Workers

### Problem
**Status**: Documented in checkout_flow_issues.md but **workers not found in codebase**
- `capture-retry-job` missing
- `payment-compensation-job` missing
- No outbox worker integration

### Solution

#### Step 1: Create Capture Retry Worker
**File**: `order/internal/workers/capture_retry_worker.go`

```go
type CaptureRetryWorker struct {
    orderRepo       OrderRepo
    paymentService  PaymentService
    log             *log.Helper
    maxRetries      int
    retryInterval   time.Duration
}

func (w *CaptureRetryWorker) Process(ctx context.Context) error {
    // Find orders that need capture retry
    orders, err := w.orderRepo.FindOrdersForCaptureRetry(ctx, w.maxRetries)
    if err != nil {
        return fmt.Errorf("failed to find orders for capture retry: %w", err)
    }

    for _, order := range orders {
        if err := w.processCaptureRetry(ctx, order); err != nil {
            w.log.Errorf("Failed to retry capture for order %s: %v", order.ID, err)
        }
    }

    return nil
}

func (w *CaptureRetryWorker) processCaptureRetry(ctx context.Context, order *Order) error {
    // Check idempotency - ensure not already captured
    if order.PaymentSagaState == PaymentSagaStateCaptured {
        w.log.Infof("Order %s already captured, skipping", order.ID)
        return nil
    }

    // Apply exponential backoff based on retry count
    backoff := w.calculateBackoff(order.CaptureRetryCount)
    if backoff > 0 {
        w.log.Infof("Waiting %v before retry for order %s", backoff, order.ID)
        time.Sleep(backoff)
    }

    // Attempt capture
    captureReq := &CapturePaymentRequest{
        AuthorizationID: order.AuthorizationID,
        Amount:         order.TotalAmount,
        Currency:       order.Currency,
        IdempotencyKey: fmt.Sprintf("capture:%s:%d", order.ID, order.CaptureRetryCount+1),
    }

    captureResp, err := w.paymentService.CapturePayment(ctx, captureReq)
    if err != nil {
        // Increment retry count
        order.CaptureRetryCount++
        if order.CaptureRetryCount >= w.maxRetries {
            order.PaymentSagaState = PaymentSagaStateCaptureFailed
            w.log.Errorf("Max retries exceeded for order %s", order.ID)
        }
        return w.orderRepo.Update(ctx, order)
    }

    // Success - update order
    order.PaymentSagaState = PaymentSagaStateCaptured
    order.PaymentStatus = "captured"
    order.CapturedAt = time.Now()

    w.log.Infof("Successfully captured payment for order %s", order.ID)
    return w.orderRepo.Update(ctx, order)
}

func (w *CaptureRetryWorker) calculateBackoff(retryCount int) time.Duration {
    // Exponential backoff: 1m, 2m, 4m, 8m, 16m, max 30m
    backoff := time.Duration(1<<uint(retryCount)) * time.Minute
    if backoff > 30*time.Minute {
        backoff = 30 * time.Minute
    }
    return backoff
}
```

#### Step 2: Create Payment Compensation Worker
**File**: `order/internal/workers/payment_compensation_worker.go`

```go
type PaymentCompensationWorker struct {
    orderRepo              OrderRepo
    paymentService         PaymentService
    warehouseService       WarehouseService
    failedCompensationRepo FailedCompensationRepo
    alertService           AlertService
    log                    *log.Helper
}

func (w *PaymentCompensationWorker) Process(ctx context.Context) error {
    // Find orders that have exceeded max capture retries
    orders, err := w.orderRepo.FindOrdersNeedingCompensation(ctx)
    if err != nil {
        return fmt.Errorf("failed to find orders needing compensation: %w", err)
    }

    for _, order := range orders {
        if err := w.processCompensation(ctx, order); err != nil {
            w.log.Errorf("Failed to compensate order %s: %v", order.ID, err)
            // Continue processing other orders
        }
    }

    return nil
}

func (w *PaymentCompensationWorker) processCompensation(ctx context.Context, order *Order) error {
    w.log.Infof("Starting compensation for order %s", order.ID)

    compensationErrors := []error{}

    // Step 1: Void authorization
    if order.AuthorizationID != "" {
        if err := w.voidAuthorization(ctx, order); err != nil {
            compensationErrors = append(compensationErrors, fmt.Errorf("void authorization failed: %w", err))
        }
    }

    // Step 2: Release warehouse reservations
    if err := w.releaseReservations(ctx, order); err != nil {
        compensationErrors = append(compensationErrors, fmt.Errorf("release reservations failed: %w", err))
    }

    // Step 3: Update order status
    order.Status = "cancelled"
    order.CancelledAt = time.Now()
    if err := w.orderRepo.Update(ctx, order); err != nil {
        compensationErrors = append(compensationErrors, fmt.Errorf("order update failed: %w", err))
    }

    // Step 4: Handle compensation results
    if len(compensationErrors) > 0 {
        // Some compensations failed - record in DLQ
        errorMsg := fmt.Sprintf("Compensation partially failed: %v", compensationErrors)
        dlqRecord := &FailedCompensation{
            OrderID:       order.ID,
            OperationType: "order_compensation",
            ErrorMessage:  errorMsg,
            Status:        "pending",
        }

        if dlqErr := w.failedCompensationRepo.Create(ctx, dlqRecord); dlqErr != nil {
            w.log.Errorf("Failed to create DLQ record for order %s: %v", order.ID, dlqErr)
        }

        // Send alert
        w.alertService.SendCriticalAlert(ctx, "Order Compensation Failed", map[string]interface{}{
            "order_id":    order.ID,
            "customer_id": order.CustomerID,
            "errors":     compensationErrors,
            "dlq_recorded": dlqErr == nil,
        })

        return fmt.Errorf("compensation failed: %v", compensationErrors)
    }

    w.log.Infof("Successfully completed compensation for order %s", order.ID)
    return nil
}

func (w *PaymentCompensationWorker) voidAuthorization(ctx context.Context, order *Order) error {
    voidReq := &VoidPaymentRequest{
        AuthorizationID: order.AuthorizationID,
        IdempotencyKey:  fmt.Sprintf("void:%s", order.ID),
    }

    _, err := w.paymentService.VoidPayment(ctx, voidReq)
    return err
}

func (w *PaymentCompensationWorker) releaseReservations(ctx context.Context, order *Order) error {
    // Get order items to release reservations
    items, err := w.orderRepo.GetOrderItems(ctx, order.ID)
    if err != nil {
        return err
    }

    for _, item := range items {
        releaseReq := &ReleaseReservationRequest{
            ReservationID: item.ReservationID,
        }

        if err := w.warehouseService.ReleaseReservation(ctx, releaseReq); err != nil {
            w.log.Errorf("Failed to release reservation %s: %v", item.ReservationID, err)
            // Continue with other reservations
        }
    }

    return nil
}
```

#### Step 3: Integrate Workers with Cron/Dapr
**Option A: Kubernetes CronJob**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: capture-retry-job
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: capture-retry
            image: order-service:latest
            command: ["/app/order", "worker", "capture-retry"]
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: payment-compensation-job
spec:
  schedule: "*/10 * * * *"  # Every 10 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: payment-compensation
            image: order-service:latest
            command: ["/app/order", "worker", "payment-compensation"]
```

**Option B: Dapr Cron Binding**
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: cron-binding
spec:
  type: bindings.cron
  version: v1
  metadata:
  - name: schedule
    value: "*/5 * * * *"  # Every 5 minutes
---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: capture-retry-trigger
spec:
  topic: schedule
  route: /workers/capture-retry
  pubsubname: pubsub
```

#### Step 4: Update Main Application
**File**: `order/cmd/order/main.go`

```go
func main() {
    // ... existing setup ...

    // Register workers
    captureWorker := workers.NewCaptureRetryWorker(orderRepo, paymentService, logger)
    compensationWorker := workers.NewPaymentCompensationWorker(
        orderRepo, paymentService, warehouseService, failedCompensationRepo, alertService, logger)

    // Add worker endpoints or cron triggers
    // ...
}
```

**Verification**:
```bash
# Test 1: Verify workers are running
kubectl get cronjobs -n production
# Should show: capture-retry-job, payment-compensation-job

# Test 2: Create order with capture failure
# 1. Mock payment service capture to fail
# 2. Create order via checkout
# 3. Wait for worker to retry capture
kubectl logs -n production -l job-name=capture-retry-job --tail=100

# Test 3: Verify compensation after max retries
# 1. Ensure capture fails repeatedly
# 2. Wait for compensation worker
kubectl logs -n production -l job-name=payment-compensation-job --tail=100

# Test 4: Check DLQ for failed compensations
kubectl exec -n production deployment/postgres -- psql -U postgres -d order_db -c \
  "SELECT * FROM failed_compensations WHERE status = 'pending';"
```

---

## 4. CHECKOUT-CONC-01: Saga Orchestrator (Future Enhancement)

### Current State
Manual orchestration in `ConfirmCheckout()` with sequential method calls.

### Future Implementation
**Option 1: Temporal Workflow** (Recommended)
```go
func ConfirmCheckoutSaga(ctx workflow.Context, req *ConfirmCheckoutRequest) error {
    // Step 1: Authorize Payment
    authFuture := workflow.ExecuteActivity(ctx, AuthorizePaymentActivity, req)
    var authResp AuthorizePaymentResponse
    if err := authFuture.Get(ctx, &authResp); err != nil {
        return err
    }

    // Step 2: Create Order
    orderFuture := workflow.ExecuteActivity(ctx, CreateOrderActivity, req, authResp.AuthorizationID)
    var orderResp CreateOrderResponse
    if err := orderFuture.Get(ctx, &orderResp); err != nil {
        // Compensation: Void authorization
        workflow.ExecuteActivity(ctx, VoidAuthorizationActivity, authResp.AuthorizationID)
        return err
    }

    // Step 3: Capture Payment
    captureFuture := workflow.ExecuteActivity(ctx, CapturePaymentActivity, authResp.AuthorizationID, orderResp.Total)
    if err := captureFuture.Get(ctx, nil); err != nil {
        // Compensation: Cancel order + void authorization
        workflow.ExecuteActivity(ctx, CancelOrderActivity, orderResp.OrderID)
        workflow.ExecuteActivity(ctx, VoidAuthorizationActivity, authResp.AuthorizationID)
        return err
    }

    return nil
}
```

**Timeline**: Q2 2026 (After P0 fixes are stable)

---

## 📋 Implementation Timeline

### Week 1: Foundation (High Priority P0)
- [x] **Day 1-2**: Add timeouts to payment calls (CHECKOUT-CONC-03)
- [x] **Day 3-5**: Implement DLQ for compensation failures (CHECKOUT-CONC-04)

### Week 2-3: Saga Workers (Critical Path)
- [ ] **Week 2**: Implement capture retry worker
- [ ] **Week 2**: Implement compensation worker
- [ ] **Week 3**: Integrate workers with cron/K8s jobs
- [ ] **Week 3**: Add comprehensive testing

### Week 4: Testing & Validation
- [ ] **Integration Tests**: End-to-end failure scenarios
- [ ] **Load Testing**: Concurrent checkout with failures
- [ ] **Monitoring**: Alert configuration and dashboards
- [ ] **Documentation**: Update checkout flow docs

---

## 🧪 Testing Strategy

### Unit Tests
```go
func TestCaptureRetryWorker_Process(t *testing.T) {
    // Setup mock order with failed capture
    // Execute worker
    // Verify capture retried
    // Verify state updated on success/failure
}

func TestPaymentCompensationWorker_Process(t *testing.T) {
    // Setup mock order needing compensation
    // Execute worker
    // Verify authorization voided
    // Verify reservations released
    // Verify DLQ created on failure
}
```

### Integration Tests
```go
func TestDistributedTransactionFailureRecovery(t *testing.T) {
    // 1. Start with clean state
    // 2. Authorize payment successfully
    // 3. Simulate service crash before order creation
    // 4. Restart service
    // 5. Verify Saga worker detects and handles orphaned authorization
}

func TestCompensationFailureHandling(t *testing.T) {
    // 1. Create order with successful authorization
    // 2. Mock void authorization to fail
    // 3. Trigger compensation
    // 4. Verify DLQ record created
    // 5. Verify alert sent
}
```

### Load Testing
```bash
# Simulate checkout load with failures
hey -n 1000 -c 50 \
  -H "X-Session-ID: load-test-$(date +%s)" \
  -H "X-Customer-ID: customer-123" \
  http://localhost:8080/api/v1/checkout/confirm

# Monitor worker performance
kubectl top pods -n load-test
kubectl logs -f -n load-test -l app=order-service | grep -E "worker|capture|compensation"
```

---

## 📊 Success Metrics

### Before Fix
- ❌ **Crash Recovery**: Manual intervention required
- ❌ **Compensation**: Errors ignored, customer charged incorrectly
- ❌ **Timeout Handling**: Indefinite hangs on service failures
- ❌ **Monitoring**: No visibility into Saga state transitions

### After Fix
- ✅ **Crash Recovery**: Automatic retry via Saga workers
- ✅ **Compensation**: DLQ with alerting for failed operations
- ✅ **Timeout Handling**: 15s timeout on payment operations
- ✅ **Monitoring**: Full observability of distributed transactions

### KPIs to Monitor
- **Saga Success Rate**: % of checkouts completing without worker intervention
- **Compensation Failure Rate**: % of compensations that fail and go to DLQ
- **Average Resolution Time**: Time from failure to successful compensation
- **Alert Volume**: Number of compensation alerts (should be low)

---

## 🚨 Risk Mitigation

### Rollback Plan
- **Feature Flags**: Can disable workers if issues arise
- **Monitoring**: Comprehensive alerting for any worker failures
- **Gradual Rollout**: Deploy workers with 1% traffic initially
- **Circuit Breakers**: Stop worker processing if downstream services fail

### Operational Readiness
- **Runbooks**: Document worker troubleshooting and manual intervention
- **On-Call Training**: Train team on worker monitoring and DLQ management
- **Dashboard**: Create operations dashboard for worker health
- **Alert Tuning**: Configure appropriate alert thresholds

---

## 📞 Support & Contact

### Implementation Team
- **Lead**: Checkout Flow Team
- **Reviewers**: Senior Backend Engineers
- **QA**: Integration Testing Team

### Monitoring & Alerts
- **Critical Alerts**: Compensation failures, worker crashes
- **Warning Alerts**: High retry rates, queue backlogs
- **Info Alerts**: Worker processing stats, DLQ growth

### Documentation Updates
- [ ] Update checkout_flow_v2.md with implementation details
- [ ] Add worker operation runbooks
- [ ] Update architecture diagrams
- [ ] Add troubleshooting guides

---

**Plan Created**: 2026-01-22  
**Estimated Effort**: 2-3 weeks (80 developer hours)  
**Risk Level**: High (affects payment processing)  
**Business Impact**: Critical (enables safe production deployment)  
**Next Steps**: Begin implementation with timeout fixes (lowest risk)
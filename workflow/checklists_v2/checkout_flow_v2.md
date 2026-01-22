# Checkout Process Flow - Quality Review V2

**Last Updated**: 2026-01-22  
**Services**: Order Service (`order/internal/biz/checkout/*`)  
**Related Flows**: [cart_flow_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/cart_flow_v2.md), [order_fulfillment_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/order_fulfillment_v2.md), [payment_security_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/payment_security_v2.md)  
**Previous Version**: [checkout_flow_issues.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists/checkout_flow_issues.md)

---

## 📊 Executive Summary

**Flow Health Score**: 6.0/10 (Needs Work → Pre-Production)

**Critical Find ings**:
- 🚨 **P0**: 4 issues (manual distributed transactions, missing Saga workers, timeout gaps, compensation errors)
- 🟡 **P1**: 6 issues (idempotency gaps, error handling, observability, testing)
- 🔵 **P2**: 5 issues (code complexity, documentation, N+1 queries)

**Status**: ⚠️ **NOT Production-Ready** - Distributed transaction orchestration incomplete, Saga workers not implemented, compensation logic fragile

**Strengths**:
- ✅ Authorization → Capture two-phase pattern implemented
- ✅ Payment idempotency key generation (session-based)
- ✅ Saga state tracking in database (authorized, capture_pending, captured, capture_failed)
- ✅ Errgroup used for parallel validations
- ✅ Compensation logic exists (void authorization, release reservations)

**Critical Weaknesses**:
- ❌ **No Saga workers found** - capture retry, compensation documented but not implemented
- ❌ Manual distributed transaction orchestration (Authorize → Create → Capture)
- ❌ Missing timeouts on critical external service calls
- ❌ Compensation errors not properly handled/alerted
- ❌ No DLQ for failed compensation

---

## 🏗️ 1. Architecture & Clean Code Review

### ✅ **Strengths**

**Layer Separation** - Good:
- [`usecase.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/usecase.go): Clean DI with 15+ dependencies
- Dedicated files per concern: confirm.go, payment.go, order_creation.go, validation.go, calculations.go

**Service Timeout Infrastructure**:
- [`usecase.go:282-298`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/usecase.go#L282-L298): `withServiceTimeout()` helper + timeout constants defined

**Decomposition**:
- Order creation broken into: buildOrderRequest → createOrder → confirmReservations → completeCart

### ❌ **Issues**

#### **[P0]** CHECKOUT-ARCH-01: ConfirmCheckout Still Too Complex
- **File**: [`confirm.go:15-67`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go#L15-L67)
- **Impact**: 384 lines total, main orchestration 53 lines but calls 10+ methods (cognitive load high)
- **Evidence**: Sequential calls to 8 different helper methods, error handling mixed with business logic
- **Fix**: Extract to Saga orchestrator pattern with explicit state machine

#### **[P2]** CHECKOUT-ARCH-02: Category Extraction N+1
- **File**: [`calculations.go:76-103`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/calculations.go#L76-L103)
- **Impact**: `extractCategoriesFromBizItems()` calls catalog per item (N queries for N items)
- **Evidence**: Line 86 calls `GetProduct()` in loop
- **Fix**: Add bulk `GetProductsByIDs()` API, fetch all categories in one call

---

## 🧠 2. Business Logic & Concurrency Review

### ✅ **Strengths**

**Payment Idempotency** - Implemented:
- [`payment.go:47-49`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L47-L49): Idempotency key = `checkout:{sessionID}:auth`
- [`payment.go:113-143`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L113-L143): Capture checks saga state before calling gateway

**Saga State Tracking** - Partially Implemented:
- [`payment.go:128`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L128): Checks `PaymentSagaStateCaptured` for idempotency
- [`payment.go:153-160`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L153-L160): Updates state to `capture_pending` atomically

**Parallel Validation** - Good Pattern:
- [`validation.go:54-105`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/validation.go#L54-L105): Errgroup with limit (10) for stock validation

### ❌ **Issues**

#### **[P0]** CHECKOUT-CONC-01: Manual Distributed Transaction (No Saga Orchestrator)
- **File**: [`confirm.go:36-57`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go#L36-L57)
- **Impact**: Authorization → Order Creation → Capture sequence has no durable orchestration
- **Evidence**: Sequential method calls, if service crashes between steps → inconsistent state
- **Scenario**: Crash after order creation but before capture → order exists, payment not captured
- **Fix**: Implement Temporal workflow or custom Saga coordinator with state persistence
- **Status**: **CRITICAL** - Documented in checkout_flow_issues.md but **workers not found in codebase**

#### **[P0]** CHECKOUT-CONC-02: Saga Workers Not Implemented
- **Evidence**: Search for `*worker*.go`, `*saga*.go`, `*capture*.go` returned 0 results
- **Impact**: Saga documented (P1-05 in checkout_flow_issues.md) but workers missing:
  - `capture-retry-job` not found
  - `payment-compensation-job` not found
  - Outbox worker integration unclear
- **Fix**: Implement workers as documented in Phase 2 verification plan
- **Status**: **BLOCKING** - Cannot recover from capture failures without worker

#### **[P0]** CHECKOUT-CONC-03: Missing Timeout on Payment Authorization
- **File**: [`payment.go:93`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L93)
- **Impact**: `AuthorizePayment()` can hang indefinitely
- **Evidence**: No `withServiceTimeout()` wrapper, context not timeout-wrapped
- **Fix**:
  ```go
  authCtx, cancel := uc.withServiceTimeout(ctx, PaymentServiceTimeout)
  defer cancel()
  authResp, err := uc.paymentService.AuthorizePayment(authCtx, authReq)
  ```

#### **[P0]** CHECKOUT-CONC-04: Compensation Errors Ignored
- **File**: [`confirm.go:303-318`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go#L303-L318)
- **Impact**: `handleRollbackAndAlert()` logs errors but doesn't block on DLQ
- **Evidence**: Line 305 logs critical error, but function returns void (no escalation path)
- **Scenario**: Void authorization fails → customer charged for cancelled order
- **Fix**: Persist failed rollback to DLQ table, trigger PagerDuty alert
- **Status**: Partially addressed (alerts), needs DLQ persistence

#### **[P1]** CHECKOUT-CONC-05: Order Creation Not Idempotent
- **File**: [`order_creation.go:53-90`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/order_creation.go#L53-L90)
- **Impact**: Retry of `createOrderAndConfirmReservations()` creates duplicate orders
- **Evidence**: No idempotency key check before `CreateOrder()` call
- **Fix**: Add idempotency key (from checkout session ID), check before order creation

#### **[P1]** CHECKOUT-CONC-06: Validation Doesn't Handle Service Timeout
- **File**: [`validation.go:76-78`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/validation.go#L76-L78)
- **Impact**: Stock check timeout treated as availability error (line 97 returns nil)
- **Evidence**: Timeout → `availableQty=0` → false negative
- **Fix**: Distinguish timeout errors from actual out-of-stock, fail fast on timeout

---

## 💽 3. Data Layer & Persistence Review

### ✅ **Strengths**

**Saga State Persistence**:
- Order model has `payment_saga_state`, `authorization_id`, `capture_retry_count` fields
- Atomic state updates via `Update()` calls

**Transaction Usage (Partial)**:
- Order creation likely wrapped in transaction (via orderUc.CreateOrder)

### ❌ **Issues**

#### **[P1]** CHECKOUT-DATA-01: No Transaction for Entire Confirm Flow
- **File**: [`confirm.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go)
- **Impact**: Authorization + Order Creation + Reservation Confirm not atomic
- **Evidence**: No `WithTransaction()` wrapper around lines 25-61
- **Fix**: Wrap critical path in distributed transaction or use outbox pattern consistently

#### **[P2]** CHECKOUT-DATA-02: Cart Cleanup Retry Logic Inconsistent
- **File**: [`confirm.go:279-296`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go#L279-L296)
- **Impact**: `completeCartWithRetry()` called but retries might not persist across restarts
- **Evidence**: Background context used, no persistent queue
- **Fix**: Move to async job queue (Dapr workflow or cron job)

---

## 🛡️ 4. Security Review

### ✅ **Strengths**

**Session Ownership Validation**:
- [`confirm.go:21-23`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go#L21-L23): `validateSessionOwnership()` checks customer ID match

**Payment Method Validation**:
- [`payment.go:61-72`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L61-L72): Validates payment method ownership

### ❌ **Issues**

#### **[P1]** CHECKOUT-SEC-01: No Rate Limiting on Checkout Confirm
- **Impact**: DDoS via repeated checkout attempts (payment authorization spam)
- **Fix**: Implement per-customer rate limiting (5 attempts/10 minutes)

#### **[P2]** CHECKOUT-SEC-02: Authorization ID Exposed in Logs
- **File**: [`payment.go:102`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L102)
- **Evidence**: `Infof("Payment authorized: authorization_id=%s", authResp.AuthorizationID)`
- **Impact**: Sensitive payment data in logs
- **Fix**: Redact or hash authorization IDs in logs

---

## ⚡ 5. Performance & Resilience Review

### ✅ **Strengths**

**Timeout Infrastructure Defined**:
- [`usecase.go:290-297`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/usecase.go#L290-L297): Timeout constants (10s warehouse, 15s payment, 8s shipping)

**Parallel Stock Validation**:
- [`validation.go:55`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/validation.go#L55): errgroup.SetLimit(10) prevents overwhelming warehouse service

### ❌ **Issues**

#### **[P0]** CHECKOUT-PERF-01: Timeout Constants Defined But Not Used in Critical Paths
- **File**: confirm.go, payment.go
- **Impact**: Payment authorization (line 93), shipping calculation (calculations.go:158) have no timeouts
- **Evidence**: `withServiceTimeout()` helper exists but not applied
- **Fix**: Wrap all external service calls:
  ```go
  ctx, cancel := uc.withServiceTimeout(ctx, PaymentServiceTimeout)
  defer cancel()
  ```

#### **[P1]** CHECKOUT-PERF-02: No Circuit Breaker on Payment Service
- **Impact**: Cascading failures if payment gateway degrades
- **Fix**: Implement gobreaker on payment service client

#### **[P1]** CHECKOUT-PERF-03: Category Extraction N+1 Query
- **File**: [`calculations.go:86`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/calculations.go#L86)
- **Impact**: For 20-item cart, makes 20 GetProduct calls
- **Fix**: Bulk fetch products or cache category mappings

---

## 👁️ 6. Observability Review

### ✅ **Strengths**

**Saga State Logging**:
- Payment capture logs state transitions

**Alert Service Integration**:
- [`confirm.go:230-237`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go#L230-L237): Triggers alerts on payment rollback failure

### ❌ **Issues**

#### **[P1]** CHECKOUT-OBS-01: No Distributed Tracing for Multi-Service Flow
- **Impact**: Cannot trace Authorize → Order Create → Capture across services
- **Fix**: Propagate trace_id, add spans for each phase

#### **[P1]** CHECKOUT-OBS-02: Missing Metrics for Saga State Transitions
- **Impact**: Can't monitor capture_pending → captured conversion rate
- **Fix**: Increment counters on state transitions:
  ```go
  uc.metricsService.IncrementCounter("checkout.saga.state_transition", map[string]string{
      "from": currentState,
      "to": newState,
  })
  ```

#### **[P2]** CHECKOUT-OBS-03: Compensation Alerts Missing Context
- **File**: [`confirm.go:308-316`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go#L308-L316)
- **Impact**: Alert payload lacks order details
- **Fix**: Include order_id, customer_id, total_amount in alert metadata

---

## 🧪 7. Testing & Quality Review

### ✅ **Strengths**

**Validation Logic Testable**:
- Pure functions like `calculateCartSubtotal()` easy to unit test

### ❌ **Issues**

#### **[P1]** CHECKOUT-TEST-01: No Distributed Transaction Failure Tests
- **Impact**: Crash scenarios not validated (e.g., crash after authorize, before capture)
- **Fix**: Add integration tests:
  - Authorize succeeds → Service crashes → Restart → Saga worker retries capture
  - Order created → Capture fails → Compensation triggered

#### **[P1]** CHECKOUT-TEST-02: No Saga Worker Tests
- **Impact**: Workers not implemented → Can't test
- **Status**: Blocked on CHECKOUT-CONC-02 fix

#### **[P2]** CHECKOUT-TEST-03: Payment Idempotency Not Tested
- **Impact**: Duplicate authorization not validated
- **Fix**: Test calling `ConfirmCheckout()` twice with same session ID → should return same order

---

## 📋 8. API & Contract Review

### ✅ **Strengths**

**Error Mapping** - Partial:
- Returns wrapped errors with context

### ❌ **Issues**

#### **[P2]** CHECKOUT-API-01: Error Messages Leak Internal State
- **Example**: `"failed to load cart for update: %w"` exposes locking strategy
- **Fix**: Map to user-friendly messages: `"Unable to process checkout, please try again"`

---

## 📚 9. Maintenance & Documentation Review

### ✅ **Strengths**

**Flow Documentation Exists**:
- [checkout_flow.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checkout_flow.md) is detailed

**Sequence Diagrams**:
- Mermaid diagrams document happy path and compensation flow

### ❌ **Issues**

#### **[P1]** CHECKOUT-MAINT-01: Saga Workers Documented But Not Implemented
- **Evidence**: checkout_flow_issues.md Phase 2 describes workers, but `/order/internal/workers` doesn't exist
- **Impact**: Documentation-code mismatch → confusion
- **Fix**: Either implement workers or update docs to reflect "planned"

#### **[P2]** CHECKOUT-MAINT-02: Timeout Constants Not Cross-Referenced
- **File**: [`usecase.go:290-297`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/usecase.go#L290-L297)
- **Impact**: Developers don't know these exist, don't use them
- **Fix**: Add code comment linking to usage examples

---

## 🗂️ Issues Index

### 🚨 P0 - Production Blockers (4)

| ID | Category | Description | File | Line |
|----|----------|-------------|------|------|
| CHECKOUT-CONC-01 | Distributed Transactions | No durable Saga orchestrator | [`confirm.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go) | 36-57 |
| CHECKOUT-CONC-02 | Infrastructure | Saga workers not implemented | Missing files | - |
| CHECKOUT-CONC-03 | Performance | No timeout on payment authorization | [`payment.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go) | 93 |
| CHECKOUT-CONC-04 | Data Integrity | Compensation errors ignored | [`confirm.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go) | 303-318 |

### 🟡 P1 - High Priority (6)

| ID | Category | Description | File | Line |
|----|----------|-------------|------|------|
| CHECKOUT-CONC-05 | Idempotency | Order creation not idempotent | [`order_creation.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/order_creation.go) | 53-90 |
| CHECKOUT-CONC-06 | Error Handling | Validation timeout handling | [`validation.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/validation.go) | 76-97 |
| CHECKOUT-PERF-02 | Performance | No circuit breaker | - | - |
| CHECKOUT-OBS-01 | Observability | No distributed tracing | - | - |
| CHECKOUT-TEST-01 | Testing | No failure scenario tests | - | - |
| CHECKOUT-MAINT-01 | Maintenance | Docs-code mismatch (workers) | Missing workers | - |

### 🔵 P2 - Technical Debt (5)

| ID | Category | Description | File | Line |
|----|----------|-------------|------|------|
| CHECKOUT-ARCH-02 | Performance | Category extraction N+1 | [`calculations.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/calculations.go) | 76-103 |
| CHECKOUT-DATA-02 | Resilience | Cart cleanup retry inconsistent | [`confirm.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go) | 279-296 |
| CHECKOUT-SEC-02 | Security | Auth ID exposed in logs | [`payment.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go) | 102 |
| CHECKOUT-API-01 | API Design | Error messages leak internals | Various | - |
| CHECKOUT-MAINT-02 | Documentation | Timeout constants undocumented | [`usecase.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/usecase.go) | 290-297 |

---

## ✅ Resolved Issues (From V1)

Verified as fixed from checkout_flow_issues.md:

- ✅ **P1-01**: Authorization currency fallback → Now uses `constants.DefaultCurrency`
- ✅ **P1-03**: Capture failure ignores status update errors → Alerts implemented
- ✅ **P1-04**: Compensation errors ignored → Joined error returned (partial fix needed)

---

## 🔍 Verification Plan

### Distributed Transaction Testing

```bash
# Test 1: Simulate crash after authorization
# 1. Set breakpoint in confirm.go after line 39 (after payment auth)
# 2. Call ConfirmCheckout
# 3. Kill process during order creation
# 4. Restart service
# Expected: Saga worker should detect authorized order without capture → retry capture
# Actual: ❌ No worker found to retry

# Test 2: Payment capture failure
# 1. Mock payment service to fail capture
# 2. Call ConfirmCheckout with valid cart
# Expected: 
#   - Order created
#   - Capture fails
#   - Compensation triggered (void authorization)
#   - Order status = cancelled
curl -X POST http://localhost:8080/api/v1/checkout/confirm \
  -H "X-Session-ID: test-session" \
  -H "X-Customer-ID: cust-123"
# Verify via logs: "CRITICAL Failed to void authorization" should trigger alert
```

### Timeout Testing

```bash
# Test 3: Payment service slow response
# Configure payment service to delay 20s
# Call ConfirmCheckout
# Expected: Should timeout after 15s (PaymentServiceTimeout)
# Actual: ❌ Hangs indefinitely (CHECKOUT-PERF-01)

# Test 4: Warehouse service unavailable
# Stop warehouse service
# Call ValidateInventory
# Expected: Should timeout after 10s
curl http://localhost:8080/api/v1/checkout/validate/inventory?session_id=test
# Actual: Check if timeout applied
```

### K8s Debugging (Dev Environment)

```bash
# View checkout logs
kubectl logs -n dev -l app=order-service --tail=200 -f | grep -E "checkout|Checkout|payment"

# Check Saga states in database
kubectl exec -n dev -it deployment/postgres -- psql -U postgres -d order_db -c \
  "SELECT id, payment_saga_state, authorization_id, capture_retry_count, payment_status, status 
   FROM orders 
   WHERE payment_saga_state IS NOT NULL 
   ORDER BY created_at DESC LIMIT 10;"

# Monitor for failed compensations
kubectl logs -n dev -l app=order-service | grep "CRITICAL.*rollback"

# Check if workers are running (should fail if not implemented)
kubectl get pods -n dev -l job-name=capture-retry-job
# Expected: Error "No resources found" → Confirms CHECKOUT-CONC-02

# Check outbox events (if implemented)
kubectl exec -n dev -it deployment/postgres -- psql -U postgres -d order_db -c \
  "SELECT id, topic, status, retry_count, error_message, created_at 
   FROM outbox 
   WHERE topic LIKE '%payment.capture%' 
   ORDER BY created_at DESC LIMIT 20;"
```

### Idempotency Testing

```bash
# Test 5: Duplicate checkout confirmation
SESSION_ID="idempotency-test-$(date +%s)"

# Create cart and checkout session (via normal flow)
# ...

# Call ConfirmCheckout twice with same session_id
curl -X POST http://localhost:8080/api/v1/checkout/confirm \
  -H "X-Session-ID: $SESSION_ID" \
  -H "X-Customer-ID: cust-123" &
curl -X POST http://localhost:8080/api/v1/checkout/confirm \
  -H "X-Session-ID: $SESSION_ID" \
  -H "X-Customer-ID: cust-123" &
wait

# Verify in database: Only ONE order created
kubectl exec -n dev -it deployment/postgres -- psql -U postgres -d order_db -c \
  "SELECT COUNT(*) FROM orders WHERE metadata->>'checkout_session_id' = '$SESSION_ID';"
# Expected: 1
# Actual: Might be 2 (CHECKOUT-CONC-05 not fully addressed)
```

---

## 🛠️ Remediation Roadmap

### Phase 1: P0 Critical Blockers (Sprint 1-2)

**1. CHECKOUT-CONC-03: Add Timeouts to Payment Service Calls**
- **Effort**: 2 hours
- **Files**: [`payment.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go)
- **Implementation**:
  ```go
  // Line 93
  authCtx, cancel := uc.withServiceTimeout(ctx, PaymentServiceTimeout)
  defer cancel()
  authResp, err := uc.paymentService.AuthorizePayment(authCtx, authReq)
  
  // Line 170
  captureCtx, cancel := context.WithTimeout(ctx, PaymentServiceTimeout)
  defer cancel()
  paymentResp, err := uc.paymentService.CapturePayment(captureCtx, captureReq)
  ```

**2. CHECKOUT-CONC-04: Implement DLQ for Failed Compensation**
- **Effort**: 8 hours
- **Steps**:
  1. Create `failed_compensations` table (id, order_id, authorization_id, reason, error, retry_count, created_at)
  2. Update `handleRollbackAndAlert()` to persist failures
  3. Create admin UI to view/retry failed compensations
  4. Add PagerDuty alert integration

**3. CHECKOUT-CONC-02: Implement Saga Workers** (CRITICAL PATH)
- **Effort**: 2-3 days
- **Deliverables**:
  - `order/internal/workers/capture_retry_job.go`:
    - Scan orders with `payment_saga_state IN ('authorized', 'capture_failed')`
    - Apply exponential backoff based on `capture_retry_count`
    - Call `capturePayment()` (already idempotent)
    - Update state to `captured` or increment retry count
  - `order/internal/workers/payment_compensation_job.go`:
    - Scan orders with `capture_retry_count >= MaxCaptureRetries` AND `capture_failed`
    - Execute: Void authorization +(optional) release reservations
    - Update order status to `cancelled`
    - On failure: Write to  DLQ
  - Integration: Dapr cron binding or Kubernetes CronJob
- **Testing**: Add scenario tests (see Verification Plan)

**4. CHECKOUT-CONC-01: Saga Orchestrator (Long-term)**
- **Effort**: 1-2 weeks
- **Options**:
  - **Option A**: Temporal workflow (recommended for complex flows)
  - **Option B**: Custom Saga coordinator with persistent event log
- **Scope**: Beyond immediate sprint, plan for Q2

### Phase 2: P1 High Priority (Sprint 3)

**5. CHECKOUT-CONC-05: Add Order Creation Idempotency**
- **Effort**: 4 hours
- **Implementation**:
  ```go
  // order_creation.go:55
  idempotencyKey := fmt.Sprintf("checkout:%s:order", session.SessionID)
  existingOrder, _ := uc.orderRepo.FindByIdempotencyKey(ctx, idempotencyKey)
  if existingOrder != nil {
      return existingOrder, nil // Already created
  }
  // ... proceed with creation
  ```

**6. CHECKOUT-PERF-02: Add Circuit Breaker on Payment Service**
- **Effort**: 6 hours
- **Library**: `github.com/sony/gobreaker`
- **Configuration**: 5 failures in 10s → open circuit for 30s

**7. CHECKOUT-OBS-01: Add Distributed Tracing**
- **Effort**: 4 hours
- **Steps**:
  1. Extract trace_id from context
  2. Add spans: "checkout.confirm", "payment.authorize", "payment.capture", "order.create"
  3. Propagate trace_id to all service calls

### Phase 3: P2 Technical Debt (Sprint 4+)

8. Refactor ConfirmCheckout into state machine
9. Fix category extraction N+1 (bulk API)
10. Improve error messages
11. Add comprehensive testing suite

---

## 📖 Related Documentation

- **Flow Documentation**: [checkout_flow.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checkout_flow.md)
- **V1 Checklist**: [checkout_flow_issues.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists/checkout_flow_issues.md)
- **Team Lead Guide**: [TEAM_LEAD_CODE_REVIEW_GUIDE.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/TEAM_LEAD_CODE_REVIEW_GUIDE.md)
- **Related Flows**: 
  - [cart_flow_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/cart_flow_v2.md)
  - [payment_security_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/payment_security_v2.md) (to be created)

---

**Review Completed**: 2026-01-22  
**Critical Blocker**: Saga workers (capture-retry-job, payment-compensation-job) **NOT IMPLEMENTED** - documented but missing in codebase  
**Production Readiness**: ❌ **NOT READY** - Must implement workers + DLQ before production  
**Reviewer**: AI Senior Code Review (Team Lead Standards)

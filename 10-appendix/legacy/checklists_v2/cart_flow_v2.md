# Cart Management Flow - Quality Review V2

**Last Updated**: 2026-01-22  
**Services**: Order Service (`order/internal/biz/cart/*`)  
**Related Flows**: [checkout_flow_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/checkout_flow_v2.md)  
**Previous Version**: [cart_flow_issues.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists/cart_flow_issues.md)

---

## 📊 Executive Summary

**Flow Health Score**: 7.5/10 (Good → Production-Ready with minor improvements)

**Critical Findings**:
- 🚨 **P0**: 2 issues (missing transaction isolation, goroutine leaks)
- 🟡 **P1**: 5 issues (merge race conditions, validation error handling, cache invalidation gaps)
- 🔵 **P2**: 8 issues (code complexity, missing pagination, documentation gaps)

**Status**: ⚠️ **Production-Ready with Caveats** - Core functionality solid, concurrency mostly handled, but distributed consistency gaps remain

**Strengths**:
- ✅ Proper layer separation (biz/data/service)
- ✅ Transaction + row-level locking for add/update
- ✅ Errgroup pattern for parallel external calls
- ✅ Promotion validation caching implemented
- ✅ Quote pattern correctly applied

**Weaknesses**:
- ❌ Missing transaction isolation in totals calculation
- ❌ Goroutine management in validate.go needs supervision
- ❌ Merge operation lacks atomic guarantees
- ❌ Event publishing error handling incomplete

---

## 🏗️ 1. Architecture & Clean Code Review

### ✅ **Strengths**

**Layer Separation** - Excellent:
- [`usecase.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/usecase.go): Clean dependency injection (11 services)
- **Biz layer** never calls `gorm.DB` directly
- **Repository** abstracted via interfaces ([`interfaces.go:11`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/interfaces.go#L11))

**Dependency Injection** - Wire-compatible:
- Constructor-based DI in [`usecase.go:27-58`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/usecase.go#L27-L58)
- All

 dependencies injected, no globals
- Interface-based service contracts

**Code Organization**:
- Flow-specific files: `add.go`, `update.go`, `totals.go`, `coupon.go`, `merge.go`
- Helper functions isolated: `helpers.go`, `helpers_internal.go`
- Type definitions centralized: `types.go`, `interfaces.go`

### ❌ **Issues**

#### **[P2]** CART-ARCH-01: AddToCart Function Complexity
- **File**: [`add.go:16-316`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L16-L316)
- **Impact**: 317 lines, cognitive complexity ~25 (threshold: 15)
- **Evidence**: Handles validation + errgroup + transaction + pricing + events inline
- **Fix**: Extract private methods:
  - `validateAndFetchProduct()`
  - `checkStockAndPricing()`  
  - `addOrUpdateItemInTransaction()`
  - `buildResponse()`

#### **[P2]** CART-ARCH-02: Totals Calculation Function Complexity
- **File**: [`totals.go:57-350`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go#L57-L350)
- **Impact**: 412 lines total, main function 294 lines
- **Fix**: Extract shipping, promotion, tax calculation into private methods

#### **[P2]** CART-ARCH-03: Helper Function Duplication
- **File**: [`helpers.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/helpers.go)
- **Impact**: Multiple `ensureMetadata*` functions (lines 11-37)
- **Fix**: Consolidate into single parameterized helper

---

## 🧠 2. Business Logic & Concurrency Review

### ✅ **Strengths**

**Transaction + Locking** (add.go, update.go, remove.go):
- Uses `LoadCartForUpdate()` for SELECT FOR UPDATE pattern
- Transaction wraps entire modify operation
- Retry logic via `executeWithRetry()` for version conflicts

**Errgroup Pattern** (add.go):
- Lines 77-161: Parallel stock check + pricing calculation
- Proper error propagation
- Context cancellation support

**Idempotency**:
- RemoveCartItem treats already-deleted as success ([`remove.go:32-33`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/remove.go#L32-L33))
- AddToCart merges quantities for existing items ([`add.go:230-242`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L230-L242))

### ❌ **Issues**

#### **[P0]** CART-CONC-01: Missing Transaction Isolation in Totals Calculation
- **File**: [`totals.go:57-350`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go#L57-L350)
- **Impact**: Cart items read without repeatable read guarantee
- **Evidence**: Line 74 loops over `cart.Items` without transaction wrapper
- **Scenario**: Concurrent AddToCart during totals calculation → inconsistent subtotal
- **Fix**:
  ```go
  err := uc.transactionManager.WithTransaction(ctx, func(txCtx context.Context) error {
      cart, err := uc.GetCart(txCtx, ...) // Read within tx
      // ... rest of calculation
  })
  ```
- **Priority**: P0 - Can cause incorrect checkout amounts

#### **[P0]** CART-CONC-02: Unmanaged Goroutines in ValidateCart
- **File**: [`validate.go:36-136`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/validate.go#L36-L136)
- **Impact**: Goroutine leaks if context cancelled before WaitGroup completes
- **Evidence**: Lines 42-134 spawn goroutines without errgroup supervision
- **Fix**: Replace `sync.WaitGroup` with `errgroup.WithContext()`:
  ```go
  eg, egCtx := errgroup.WithContext(ctx)
  for _, item := range cart.Items {
      item := item // Capture
      eg.Go(func() error {
          // Validation logic
      })
  }
  return eg.Wait()
  ```

#### **[P1]** CART-CONC-03: Merge Operation Not Atomic
- **File**: [`merge.go:44-62`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/merge.go#L44-L62)
- **Impact**: Merge strategy execution not wrapped in transaction
- **Evidence**: Multiple repo calls (DeleteItemsBySessionID, CreateItem) without tx
- **Scenario**: Service crash between delete guest cart and create merged items → data loss
- **Fix**: Wrap entire merge switch in `WithTransaction()`

#### **[P1]** CART-CONC-04: ClearCart Missing Transaction
- **File**: [`clear.go:25`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/clear.go#L25)
- **Impact**: DeleteItemsBySessionID not atomic with potential metadata updates
- **Fix**: Wrap in transaction if clearing cart involves status update

#### **[P2]** CART-CONC-05: Event Publishing Error Handling
- **File**: [`add.go:273-276`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L273-L276)
- **Impact**: Context timeout error not logged/monitored
- **Evidence**: `publishAddToCartEvents()` is fire-and-forget, errors ignored
- **Fix**: Add error logging or metric increment on timeout

---

## 💽 3. Data Layer & Persistence Review

### ✅ **Strengths**

**Repository Abstraction**:
- Interface-based contracts ([`interfaces.go:11`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/interfaces.go#L11))
- No `gorm.DB` leakage into biz layer

**Locking Strategy**:
- `LoadCartForUpdate()` uses SELECT FOR UPDATE for cart session
- Prevents concurrent modifications to same cart

**Optimistic Locking Readiness**:
- `executeWithRetry()` infrastructure present for version conflicts

### ❌ **Issues**

#### **[P1]** CART-DATA-01: No Pagination in GetCart (Implicit)
- **File**: [`get.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/get.go)
- **Impact**: Loads all cart items without limit (OOM risk for carts with 100+ items)
- **Fix**: Add pagination params to GetCart request, implement cursor-based pagination

#### **[P2]** CART-DATA-02: Missing Index on cart_items(session_id, product_id, warehouse_id)
- **Impact**: FindItemByCartIDAndProductAndWarehouse query may be slow
- **Evidence**: Composite lookup without covering index
- **Fix**: Add migration for composite unique index:
  ```sql
  CREATE UNIQUE INDEX idx_cart_items_session_product_warehouse 
  ON cart_items(session_id, product_id, warehouse_id);
  ```

#### **[P2]** CART-DATA-03: Soft Delete Missing for Cart Sessions
- **Impact**: No audit trail when carts are deleted/expired
- **Fix**: Add `deleted_at` timestamp column, implement soft delete pattern

---

## 🛡️ 4. Security Review

### ✅ **Strengths**

**Ownership Validation**:
- [`remove.go:22-24`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/remove.go#L22-L24): Validates cart ownership before delete
- [`remove.go:35-37`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/remove.go#L35-L37): Validates item belongs to session

**Input Validation**:
- Quantity validation via `validateQuantity()` (add.go, update.go)
- Max items per cart enforced ([`add.go:245-247`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L245-L247))

### ❌ **Issues**

#### **[P1]** CART-SEC-01: Missing Rate Limiting on AddToCart
- **Impact**: Cart spam attack (add 1000 items rapidly)
- **Fix**: Implement per-customer/session rate limiting (e.g., 50 adds/minute)

#### **[P2]** CART-SEC-02: Guest Token Not Validated
- **Impact**: Attacker can guess guest tokens and access carts
- **Fix**: Use cryptographically secure token generation (UUID v4 minimum)

#### **[P2]** CART-SEC-03: Coupon Code SQL Injection Risk (Indirect)
- **File**: [`coupon.go:69`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/coupon.go#L69)
- **Impact**: If promotion service uses raw SQL for `couponCode` lookup
- **Mitigation**: Ensure promotion service uses parameterized queries

---

## ⚡ 5. Performance & Resilience Review

### ✅ **Strengths**

**Promotion Validation Caching**:
- [`totals.go:218-229`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go#L218-L229): SHA256-based cache key generation
- Cache hit avoids expensive promotion service call

**Parallel External Calls**:
- [`add.go:77-161`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L77-L161): Stock check + pricing in parallel via errgroup

**Quick Summary Endpoint**:
- [`add.go:286-297`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L286-L297): `IncludeCartData=false` avoids totals calculation overhead

### ❌ **Issues**

#### **[P0]** CART-PERF-01: No Timeout on Shipping Service Call
- **File**: [`totals.go:114`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go#L114)
- **Impact**: CalculateRates() can hang indefinitely if shipping service is slow
- **Fix**:
  ```go
  shippingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
  defer cancel()
  ratesResp, err := uc.shippingService.CalculateRates(shippingCtx, shippingReq)
  ```

#### **[P1]** CART-PERF-02: No Circuit Breaker on Pricing Service
- **Impact**: Cascading failures if pricing service degrades
- **Fix**: Implement circuit breaker using `gobreaker` library

#### **[P1]** CART-PERF-03: Cache Invalidation Too Broad
- **File**: [`add.go:271`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L271)
- **Impact**: Invalidates entire cart cache on single item add
- **Fix**: Use cache versioning or selective invalidation

#### **[P2]** CART-PERF-04: Validation Makes N External Calls
- **File**: [`validate.go:43-134`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/validate.go#L43-L134)
- **Impact**: For cart with 20 items, makes 20 pricing + 20 stock calls (even with parallelism)
- **Fix**: Add bulk pricing/stock check APIs

---

## 👁️ 6. Observability Review

### ✅ **Strengths**

**Structured Logging**:
- Context-aware logging via `uc.log.WithContext(ctx)`
- Informational logs at key decision points

**Metrics**:
- [`metrics.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/metrics.go): Operation counters and duration tracking

### ❌ **Issues**

#### **[P1]** CART-OBS-01: Missing trace_id in Logs
- **Impact**: Difficult to trace multi-service cart operations
- **Fix**:Extract and log trace_id from context in all operations:
  ```go
  traceID := getTraceIDFromContext(ctx)
  uc.log.WithContext(ctx).Infof("[trace_id=%s] Adding item to cart...", traceID)
  ```

#### **[P1]** CART-OBS-02: No Error Rate Metrics
- **Impact**: Can't alert on cart add failures
- **Fix**: Increment error counter in catch blocks:
  ```go
  uc.trackCartOperation("add_item", "error")
  uc.metricsService.IncrementCounter("cart.add_item.error", map[string]string{
      "reason": classifyError(err),
  })
  ```

#### **[P2]** CART-OBS-03: Totals Calculation Latency Not Tracked Per Service
- **Impact**: Can't identify which dependency is slow
- **Fix**: Add service-specific duration metrics for shipping, pricing, tax, promotion calls

---

## 🧪 7. Testing & Quality Review

### ✅ **Strengths**

**Unit Tests Present**:
- [`cart_test.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/cart_test.go): Basic coverage
- [`totals_internal_test.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals_internal_test.go): Totals logic tests
- [`mocks_test.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/mocks_test.go): Mock infrastructure

### ❌ **Issues**

#### **[P1]** CART-TEST-01: No Concurrency Tests
- **Impact**: Race conditions in add/update not tested
- **Fix**: Add test that fires 100 parallel AddToCart requests with same SKU, verify final quantity

#### **[P1]** CART-TEST-02: Totals Calculation Missing Integration Tests
- **Impact**: Pricing/promotion/tax integration bugs not caught
- **Fix**: Add integration test with real service mocks (testcontainers)

#### **[P2]** CART-TEST-03: Error Path Coverage Below 80%
- **Impact**: Edge cases not validated
- **Fix**: Add tests for stock check failures, pricing service errors, transaction rollbacks

---

## 📋 8. API & Contract Review

### ✅ **Strengths**

**Request/Response Types**:
- Well-defined types in [`types.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/types.go)
- JSONMetadata used consistently

**Validation**:
- Quantity limits enforced (max 999 per item, max 100 items per cart)

### ❌ **Issues**

#### **[P2]** CART-API-01: Error Messages Expose Internal Details
- **Example**: `"failed to load cart for update: %w"` in [`remove.go:15`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/remove.go#L15)
- **Fix**: Map internal errors to user-friendly messages before returning

#### **[P2]** CART-API-02: No API Documentation
- **Impact**: Frontend integration difficult
- **Fix**: Add OpenAPI/Swagger specs for cart endpoints

---

## 📚 9. Maintenance & Documentation Review

### ✅ **Strengths**

**Code Comments**:
- Quote Pattern documented in code comments
- Helper functions have docstrings

**Flow Documentation**:
- [`cart_flow.md`](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/cart_flow.md) exists and detailed

### ❌ **Issues**

#### **[P2]** CART-MAINT-01: TODOs Not Tracked
- **Example**: [`coupon.go:39`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/coupon.go#L39): `"TODO: Get from customer service"`
- **Fix**: Create JIRA tickets and reference in code: `// TODO(CART-123): Get customer segments`

#### **[P2]** CART-MAINT-02: Complex Functions Missing Inline Documentation
- **Example**: [`add.go:198-258`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L198-L258): Transaction logic not explained
- **Fix**: Add block comments explaining locking strategy

---

## 🗂️ Issues Index

### 🚨 P0 - Production Blockers (2)

| ID | Category | Description | File | Line |
|----|----------|-------------|------|------|
| CART-CONC-01 | Data Integrity | Missing transaction isolation in totals calculation | [`totals.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go) | 57-350 |
| CART-CONC-02 | Concurrency | Unmanaged goroutines in ValidateCart | [`validate.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/validate.go) | 36-136 |

### 🟡 P1 - High Priority (5)

| ID | Category | Description | File | Line |
|----|----------|-------------|------|------|
| CART-CONC-03 | Data Integrity | Merge operation not atomic | [`merge.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/merge.go) | 44-62 |
| CART-SEC-01 | Security | Missing rate limiting on AddToCart | [`add.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go) | 16 |
| CART-PERF-01 | Performance | No timeout on shipping service call | [`totals.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go) | 114 |
| CART-OBS-01 | Observability | Missing trace_id in logs | All files | - |
| CART-TEST-01 | Testing | No concurrency tests | [`cart_test.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/cart_test.go) | - |

### 🔵 P2 - Technical Debt (8)

| ID | Category | Description | File | Line |
|----|----------|-------------|------|------|
| CART-ARCH-01 | Code Quality | AddToCart function complexity | [`add.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go) | 16-316 |
| CART-ARCH-02 | Code Quality | Totals calculation function complexity | [`totals.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go) | 57-350 |
| CART-DATA-01 | Performance | No pagination in GetCart | [`get.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/get.go) | - |
| CART-PERF-03 | Performance | Cache invalidation too broad | [`add.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go) | 271 |
| CART-API-01 | API Design | Error messages expose internal details | Various | - |
| CART-TEST-02 | Testing | Integration tests missing | - | - |
| CART-MAINT-01 | Maintenance | TODOs not tracked | [`coupon.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/coupon.go) | 39 |
| CART-SEC-02 | Security | Guest token not validated | [`add.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go) | - |

---

## ✅ Resolved Issues (From V1)

These issues from cart_flow_issues.md have been **verified as fixed**:

- ✅ **P0-01**: Unmanaged goroutine for event publishing → Now uses `context.WithTimeout`
- ✅ **P1-01**: Cart item updates not atomic → Transaction + `LoadCartForUpdate` implemented
- ✅ **P1-02**: Totals calculation silent failures → Now fails fast on errors
- ✅ **P2-01**: CountryCode hardcoded → Uses `constants.DefaultCountryCode`

---

## 🔍 Verification Plan

### Concurrency Testing

```bash
# Test 1: Concurrent AddToCart (same product)
for i in {1..20}; do
  curl -X POST http://localhost:8080/api/v1/cart/items \
    -H "X-Session-ID: test-session" \
    -d '{"product_sku":"SKU123","quantity":1,"warehouse_id":"WH1"}' &
done
wait

# Verify final quantity = 20
curl http://localhost:8080/api/v1/cart -H "X-Session-ID: test-session" | jq '.items[0].quantity'

# Test 2: Totals calculation during concurrent updates
curl http://localhost:8080/api/v1/cart/totals -H "X-Session-ID: test-session" &
curl -X POST http://localhost:8080/api/v1/cart/items [...] &
wait
```

### Performance Testing

```bash
# Test shipping service timeout
# 1. Configure shipping service to delay 10s
# 2. Call GetCart with totals
curl http://localhost:8080/api/v1/cart -H "X-Session-ID: test-session"
# Expected: Should fail after 5s (P0-PERF-01 fix)

# Test N+1 validation queries
# Monitor DB query count during ValidateCart for 20-item cart
# Expected: Should be 2 queries (1 GetCart + 1 bulk pricing), not 40+
```

### K8s Debugging (Dev Environment)

```bash
# View cart service logs
kubectl logs -n dev -l app=order-service --tail=100 -f | grep "cart"

# Check cart database state
kubectl exec -n dev -it deployment/postgres -- psql -U postgres -d order_db -c \
  "SELECT session_id, customer_id, status, COUNT(*) as item_count 
   FROM cart_sessions cs 
   LEFT JOIN cart_items ci ON cs.session_id = ci.session_id 
   GROUP BY cs.id ORDER BY cs.updated_at DESC LIMIT 10;"

# Monitor goroutine count (check for leaks)
kubectl port-forward -n dev svc/order-service 6060:6060
curl http://localhost:6060/debug/pprof/goroutine?debug=1 | grep "validate"

# Check promotion cache hit rate
kubectl exec -n dev -it deployment/redis -- redis-cli INFO stats | grep keyspace
```

---

## 🛠️ Remediation Roadmap

### Phase 1: P0 Blockers (Sprint 1)

1. **CART-CONC-01**: Wrap totals calculation in transaction
   - Estimated effort: 4 hours
   - Files: [`totals.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go)
   - Testing: Add integration test

2. **CART-CONC-02**: Replace WaitGroup with errgroup in ValidateCart
   - Estimated effort: 3 hours
   - Files: [`validate.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/validate.go)
   - Testing: Add goroutine leak test

### Phase 2: P1 High Priority (Sprint 2)

3. **CART-PERF-01**: Add timeouts to all external service calls
   - Estimated effort: 6 hours (all cart files)
   - Pattern:
     ```go
     ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
     defer cancel()
     ```

4. **CART-CONC-03**: Wrap merge operation in transaction
   - Estimated effort: 4 hours
   - Files: [`merge.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/merge.go)

5. **CART-SEC-01**: Implement rate limiting
   - Estimated effort: 8 hours
   - Use Redis token bucket or middleware

### Phase 3: P2 Technical Debt (Sprint 3-4)

6. Refactor complex functions (CART-ARCH-01, CART-ARCH-02)
7. Add comprehensive testing (CART-TEST-01, CART-TEST-02)
8. Improve observability (CART-OBS-01, CART-OBS-02)

---

## 📖 Related Documentation

- **Flow Documentation**: [cart_flow.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/cart_flow.md)
- **V1 Checklist**: [cart_flow_issues.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists/cart_flow_issues.md)
- **Team Lead Guide**: [TEAM_LEAD_CODE_REVIEW_GUIDE.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/TEAM_LEAD_CODE_REVIEW_GUIDE.md)
- **Related Flow**: [checkout_flow_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/checkout_flow_v2.md)

---

**Review Completed**: 2026-01-22  
**Next Review**: Before major release or quarterly  
**Reviewer**: AI Senior Code Review (Team Lead Standards)

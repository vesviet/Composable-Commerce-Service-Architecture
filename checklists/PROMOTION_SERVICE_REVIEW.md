# 🎁 PROMOTION SERVICE REVIEW

**Review Date**: January 14, 2026  
**Reviewer**: Principal Developer (Cascade)  
**Service**: Promotion (Campaign + Promotion + Coupon Management)  
**Status**: ⚠️ **NOT PRODUCTION READY** - Requires P0 fixes  

**Score**: 75% | **Issues**: 6 (3 P0, 3 P1)  
**Est. Fix Time**: 21 hours  

---

## 📋 Executive Summary

Promotion service has solid business logic and architecture but has **3 critical P0 issues** that must be fixed before production:

**Critical Issues**:
1. **P0-1**: JSON (un)marshaling without error handling (correctness + corruption risk)
2. **P0-2**: Usage limit enforcement is not atomic / not reserved (race + oversell risk)
3. **P0-3**: Event publishing is non-transactional (dual-write / event loss risk)

**Good News**:
- Clean DDD architecture ✅
- Advanced promotion logic (BOGO, tiered, review-based) ✅
- Comprehensive validation logic ✅

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

---

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

## 🚨 Critical Issues (P0)

### P0-1: JSON (Un)Marshaling Without Error Handling (4h) ⚠️

**Files (verified)**:
- `promotion/internal/data/promotion.go: convertToBusinessModel` (7 `json.Unmarshal(...)` without checking `error`)
- `promotion/internal/data/promotion.go: CreatePromotion/UpdatePromotion` (multiple `json.Marshal(...), _ := ...`)
- `promotion/internal/data/campaign.go` (unmarshal in conversion)
- `promotion/internal/data/coupon.go` (unmarshal in conversion)
- `promotion/internal/data/promotion_usage.go` (unmarshal in conversion)

**Severity**: 🔴 CRITICAL

**Impact**:
- **Correctness risk**: invalid JSON silently becomes empty values (`nil` / `{}`) changing eligibility/discount outcomes.
- **Reliability risk**: corrupted JSON can be written to DB because `Marshal` errors are ignored.

**Current State (verified in `promotion/internal/data/promotion.go`)**:
```go
json.Unmarshal([]byte(p.ApplicableProducts), &applicableProducts)
json.Unmarshal([]byte(p.ApplicableCategories), &applicableCategories)
json.Unmarshal([]byte(p.ApplicableBrands), &applicableBrands)
json.Unmarshal([]byte(p.ExcludedProducts), &excludedProducts)
json.Unmarshal([]byte(p.CustomerSegments), &customerSegments)
json.Unmarshal([]byte(p.Conditions), &conditions)
json.Unmarshal([]byte(p.Actions), &actions)
```

**Fix** (4 hours):
- For `Conditions` + `Actions`: treat as **critical**. If unmarshal fails → return typed error.
- For arrays (`ApplicableProducts`, etc.): log error + default to `[]`.
- For marshaling before DB write: check error and fail the operation (don’t persist corrupted record).

**Testing**:
- [ ] Seed DB with invalid JSON in `conditions/actions` and verify service returns error (not silent default).
- [ ] Unit tests for conversion functions with malformed JSON.

**Rubric Violation**:
- #2 (Validation)
- #5 (Input Sanitation)
- #8 (Testing & Quality)

---

### P0-2: Usage Limit Enforcement Is Not Atomic (6h) ⚠️

**Files (verified)**:
- `promotion/internal/biz/promotion.go: isPromotionApplicable` (checks limits using in-memory `CurrentUsageCount` + per-customer count via `GetUsageByCustomer`)
- `promotion/internal/biz/promotion.go: ValidatePromotions` (does **not** reserve usage / increment counters)

**Severity**: 🔴 CRITICAL

**Impact**:
- **Race condition / oversell risk**: concurrent checkouts can all pass `isPromotionApplicable` at the same time.
- **Functional gap**: current validation computes discounts but does not **atomically reserve** usage.

**Fix** (6 hours):
- Decide enforcement point: **checkout commit** (preferred) vs **validation endpoint**.
- Add atomic reservation method (e.g. `ReservePromotionUsageAtomic`) using transaction + row lock + per-customer `COUNT(*)`.

**Testing**:
- [ ] Concurrency test: limit=10, spawn 20 goroutines → exactly 10 succeed.

**Rubric Violation**:
- #3 (Race Conditions)
- #4 (Transaction Boundaries)

---

### P0-3: Event Publishing Is Non-Transactional (Dual-Write Risk) (8h) ⚠️

**Files (verified)**:
- `promotion/internal/biz/promotion.go: CreateCampaign/UpdateCampaign/DeleteCampaign/ActivateCampaign/DeactivateCampaign` → write DB then publish event
- `promotion/internal/biz/promotion.go: CreatePromotion/UpdatePromotion/DeletePromotion` → write DB then publish event
- `promotion/internal/biz/promotion.go: GenerateBulkCoupons` → generate DB rows then publish event

**Severity**: 🔴 CRITICAL

**Impact**:
- **Event loss risk**: crash after DB commit but before publish → downstream misses events.
- **Inconsistency risk**: retries can produce duplicates without idempotency.

**Fix** (8 hours):
- Implement **Transactional Outbox** (same pattern as `catalog`): write domain record + outbox event in the same transaction.
- Add worker to publish outbox with retry.

**Testing**:
- [ ] Create campaign/promotion → verify outbox row created in same transaction.
- [ ] Kill service after DB commit → verify worker still publishes later.

**Rubric Violation**:
- #4 (Transaction Boundaries)
- #3 (Concurrency)

---

## ⚠️ High Priority Issues (P1)

### P1-1: Missing Standard Middleware Stack (Tracing + Standard Metrics) (3h)

**File (verified)**: `promotion/internal/server/http.go`

**Impact**:
- `/metrics` exists via `promhttp` but request instrumentation middleware is missing.
- No distributed tracing spans.

**Fix**:
- Add `metrics.Server()` and `tracing.Server()` middleware.

---

### P1-2: JSONB Filtering Logic Needs Correctness + Indexing Review (3h)

**File (verified)**: `promotion/internal/data/promotion.go: GetActivePromotions`

**Impact**:
- Current SQL generation uses only the first condition when multiple IDs provided.
- Uses string concatenation to build JSONB SQL fragments.

**Fix**:
- Combine conditions with `OR` for all IDs.
- Prefer parameterized query; add GIN indexes if needed.

---

### P1-3: Worker Framework Exists But No Workers Are Registered (3h)

**Files (verified)**:
- `promotion/internal/worker/workers.go` → returns empty slice
- `promotion/cmd/worker/wire.go` / `wire_gen.go` → calls `worker.NewWorkers()` (no deps injected)

**Impact**:
- If outbox is implemented, there is currently no worker to drain/publish.

**Fix**:
- Add `OutboxWorker` and register it in `NewWorkers(...)`.

---

## 📊 Rubric Compliance Matrix

| Rubric Item | Score | Status | Notes |
|-------------|-------|--------|-------|
| 1️⃣ Architecture & Clean Code | 8/10 | ✅ | Clean DDD, proper DI |
| 2️⃣ API & Contract | 6/10 | ⚠️ | P0-1: JSON error handling missing |
| 3️⃣ Business Logic & Concurrency | 6/10 | ⚠️ | P0-2/P0-3 |
| 4️⃣ Data Layer & Persistence | 5/10 | ⚠️ | P0-2/P0-3 |
| 5️⃣ Security | 6/10 | ⚠️ | P0-1 + P1-2 string concat |
| 6️⃣ Performance & Scalability | 7/10 | ⚠️ | P1-2 |
| 7️⃣ Observability | 6/10 | ⚠️ | P1-1 |
| 8️⃣ Testing & Quality | 4/10 | ⚠️ | tests exist but coverage gaps |
| 9️⃣ Configuration & Resilience | 6/10 | ⚠️ | P1-3 |
| 🔟 Documentation & Maintenance | 8/10 | ✅ | Docs exist |
| **OVERALL** | **6.2/10** | **⚠️** | **NOT PRODUCTION READY** |

---

## 🚀 Implementation Roadmap

### Phase 1: Fix P0 Issues (18 hours)
- **P0-1**: Add JSON error handling (4h)
- **P0-2**: Atomic usage reservation (6h)
- **P0-3**: Transactional outbox + worker (8h)

### Phase 2: Fix P1 Issues (9 hours)
- **P1-1**: Add tracing + Kratos metrics middleware (3h)
- **P1-2**: Fix JSONB filter correctness + consider indexes (3h)
- **P1-3**: Register workers (3h)

---

## ✅ Success Criteria

- [ ] All JSON marshal/unmarshal has error handling.
- [ ] Usage limits enforced atomically at the chosen enforcement point.
- [ ] Outbox events are created transactionally and published by worker with retry.
- [ ] Tracing spans visible in Jaeger/Tempo.
- [ ] Request metrics available and dashboards possible.

---

**Last Updated**: 2026-01-17

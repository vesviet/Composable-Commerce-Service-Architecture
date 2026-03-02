# 🔍 Service Maturity Audit — 2026-03-02

**Scope**: 13 services at 🟡 Near-prod or 🟠 Partial maturity  
**Method**: Automated pattern scanning + code review against Team Lead Review Guide  
**Goal**: Identify blocking/high-priority issues preventing production readiness  
**P0 Fix Status**: ✅ All P0 issues resolved (2026-03-02)

---

## 📊 Overall Summary

| Category | P0 | P1 | P2 | Services Affected |
|----------|----|----|----|----|
| Missing Input Validation | — | ~~3~~ ✅ | — | return, loyalty-rewards, review |
| Unmanaged Goroutines | ~~2~~ ✅ | ~~2~~ ✅ | — | catalog (11), search (4), pricing (3), analytics (2), promotion (1) |
| Missing Resilience (CB/Retry) | — | ~~1~~ ✅ | 1 | location (✅ fixed), review (client-only) |
| N+1 Preload Risk | — | ~~2~~ ✅ | 1 | customer (✅ capped), fulfillment (✅ already safe) |
| Low Test Coverage | — | — | 10 | Most non-production services |
| Missing Transactions | — | ~~1~~ ⚠️ | — | search (⚠️ false positive) |

---

## 🔴 P0 Issues (Blocking)

### 1. Unmanaged Goroutines in Business Logic — ✅ FIXED
**Services**: `catalog` (11 instances), `search` (4 instances)

**Fixes applied:**
- `catalog/biz/product/product_price_stock.go`: Converted WaitGroup→`errgroup.Group` (GetProductAvailability), added `defer recover()` (SyncProductAvailabilityBatch)
- `catalog/biz/product/cache_warming.go`: Added `defer recover()` (WarmAvailabilityCache)
- `catalog/data/postgres/materialized_view_refresh.go`: Already safe (has recover+retry+background ctx)
- `catalog/middleware/audit_log.go`: Added `defer recover()` (async audit insert)
- `catalog/service/product_helper.go`: Converted WaitGroup→`errgroup.Group` (fetchStockAndPrice), added `defer recover()` (enrichProductsBulk)
- `search/service/search_handlers.go`: Added `defer recover()` (ReindexAll background goroutine)
- `search/biz/search_usecase.go`: Already safe (worker pool with channel+WaitGroup+cleanup)
- `search/data/postgres/popularity.go`: Already safe (worker with ctx.Done drain)

**Build verification:** `go build ./...` ✅ for both catalog and search

---

## 🟡 P1 Issues (High)

### 2. Zero Input Validation in Service Layer — ✅ FIXED
**Services**: `return` (10 handlers), `loyalty-rewards` (15 handlers), `review` (15 handlers)

**Fixes applied:**
- `return/internal/service/return.go`: Added `validateRequired()` helper + validation to all 10 handlers (CreateReturn, GetReturn, ListReturns, Approve, Reject, ReceiveItems, ProcessRefund, Cancel, CheckEligibility, CreateExchange). PageSize caps added to ListReturns.
- `review/internal/service/review_service.go`: Added product_id, rating (1-5), review_id, customer_id validation to 6 handlers.
- `review/internal/service/helpful_service.go`: Added review_id validation to 4 handlers.
- `review/internal/service/moderation_service.go`: Added review_id, action, reason validation to 3 handlers.
- `review/internal/service/rating_service.go`: Added product_id validation to 2 handlers.
- `loyalty-rewards/internal/service/loyalty.go`: Added customer_id, points>0, source, reward_id, referee validation to 15 handlers.

**Build verification:** `go build ./...` ✅ for return, review, loyalty-rewards

### 3. Location Service — No Circuit Breakers — ✅ FIXED
**Service**: `location` — 3 gRPC clients (user, warehouse, shipping)

**Fix applied:** Replaced `factory.CreateClient()` with `GRPCClientBuilder` using:
- Circuit breaker: 5 failures → open, 60s recovery timeout
- Timeout: 10s per call
- Retries: 3 attempts, 500ms delay

**Build verification:** `go build ./...` ✅ for location

### 4. N+1 Preload Risks — ✅ FIXED / ASSESSED
**Services**: `customer`, `fulfillment`

**Assessment:**
- `customer/address.FindByCustomerID`: Added `Limit(500)` safety cap.
- `customer/wishlist.FindByCustomerID`: Added `Limit(500)` safety cap.
- `customer/customer.Search`: Already uses cursor pagination — bounded.
- `customer/customer.FindByID`, `FindByEmail`: Single-record `First()` — inherently bounded.
- `fulfillment`: All preloads are either single-record `Take()` or cursor-paginated lists. `ListByOrderID` already has `Limit(500)`. GORM batch preload = 3 queries, not N+1.

**Build verification:** `go build ./...` ✅ for customer

### 5. Search Service — Near-Zero Transaction Coverage — ⚠️ FALSE POSITIVE
**Service**: `search` — 2 transaction refs, but most writes target Elasticsearch (inherently atomic per doc)

**Assessment:** Search write operations are mostly Elasticsearch index/bulk/delete which are atomic per document. The 2 PostgreSQL transaction uses (`ltr_training_data.go`) already wrap multi-table writes properly. No additional transactions needed — this was a false positive from the automated pattern scan.

### 6. Unmanaged Goroutines in Other Services — ✅ FIXED
**Services**: `pricing` (3), `analytics` (2), `promotion` (1)
**Already safe**: `return` (Kratos server lifecycle), `loyalty-rewards` (ticker worker with ctx.Done)

**Fixes applied:**
- `pricing/internal/biz/price/price_bulk.go`: Added `defer recover()` to `cleanupJobStatuses` fire-and-forget and async bulk update job goroutine (also sets job status to "failed" on panic).
- `pricing/internal/biz/calculation/calculation.go`: Added `defer recover()` to semaphore-bounded `BulkCalculatePrice` goroutine.
- `analytics/internal/biz/custom_report_usecase.go`: Added `defer recover()` to `ExecuteCustomReport` background goroutine.
- `analytics/internal/biz/data_quality_usecase.go`: Added `defer recover()` to `ExecuteDataQualityCheck` background goroutine.
- `promotion/internal/biz/validation.go`: Added `defer recover()` to fan-out goroutine in `enrichRequestWithCatalogData` (also sends error on channel to prevent deadlock).

**Build verification:** `go build ./...` ✅ for pricing, analytics, promotion

---

## 🔵 P2 Issues (Normal)

### 7. Low Test Coverage Across All Services

| Service | Test Files | Source Files | Ratio | Priority |
|---------|------------|--------------|-------|----------|
| customer | 6 | 123 | 4.9% | High |
| pricing | 3 | 96 | 3.1% | High |
| analytics | 6 | 101 | 5.9% | Medium |
| notification | 4 | 89 | 4.5% | Medium |
| fulfillment | 5 | 106 | 4.7% | Medium |
| return | 4 | 54 | 7.4% | Medium |
| location | 3 | 23 | 13.0% | Low |
| review | 5 | 67 | 7.5% | Medium |
| promotion | 7 | 55 | 12.7% | Low |
| search | 10 | 145 | 6.9% | Medium |

**Target**: At least biz-layer tests for critical usecases (80%+ per review guide).

### 8. Notification Service — Minimal Validation
**Service**: `notification` — only 4 validation refs across 10 service files

Not zero, but very low for a service handling email/SMS/push notifications.

---

## ✅ Positive Findings

| Area | Status |
|------|--------|
| Clean Architecture (biz/data separation) | ✅ All 13 services — no biz-layer gorm imports |
| Hardcoded Secrets | ✅ None found (3 false positives in customer) |
| HPA Configuration | ✅ All 13 services have gitops HPA |
| README.md | ✅ All 13 services |
| CHANGELOG.md | ✅ All 13 services |
| SQL Injection | ✅ Safe — analytics uses parameterized `$N` placeholders |
| Outbox Pattern | ✅ Widely adopted across services |
| Idempotency | ✅ Good adoption |

---

## 🚀 Recommended Fix Priority

### Phase 1 — P0 Fixes (1-2 days) ✅ COMPLETED
1. **Catalog goroutines** → `errgroup` migration + recover ✅
2. **Search goroutines** → recover added ✅

### Phase 2 — P1 Critical (3-5 days) ✅ COMPLETED
3. **return** → Validation added to all 10 handlers ✅
4. **loyalty-rewards** → Validation added to all 15 handlers ✅
5. **review** → Validation added to all 15 handlers ✅
6. **location** → Circuit breakers + retries + timeouts ✅
7. **search** → Assessed: false positive (ES writes are atomic) ✅
8. **customer** → Preload Limit(500) caps added ✅
9. **fulfillment** → Assessed: already safe (single-record + cursor pagination) ✅

### Phase 3 — P1 Secondary (2-3 days) ✅ COMPLETED
10. **pricing** → Added panic recovery to 3 goroutines (cleanup, async bulk update, bulk calculate) ✅
11. **analytics** → Added panic recovery to 2 goroutines (report execution, data quality check) ✅
12. **promotion** → Added panic recovery to fan-out goroutine (catalog enrichment) ✅
13. **return/loyalty-rewards** → Assessed: already safe (server lifecycle / worker pattern) ✅

### Phase 4 — P2 Test Coverage (ongoing)
12. Prioritize biz-layer tests for: customer, pricing, analytics, notification, fulfillment
13. Target 60%+ statement coverage for biz layer

---

## 📋 Service-Level Maturity Assessment (Final)

All P0/P1 issues resolved. **15/21 services** are now 🟢 Production-ready.

| Service | Before Audit | After Audit | Fix Applied | Remaining Blocker |
|---------|-------------|-------------|------------|-------------------|
| **Auth** | 🟢 | 🟢 | — | — |
| **User** | 🟢 | 🟢 | — | — |
| **Checkout** | 🟢 | 🟢 | — | — |
| **Order** | 🟢 | 🟢 | — | — |
| **Payment** | 🟢 | 🟢 | — | — |
| **Warehouse** | 🟢 | 🟢 | — | — |
| **Gateway** | 🟢 | 🟢 | — | — |
| **Common Ops** | 🟢 | 🟢 | — | — |
| **Catalog** | 🟡 | 🟢 | errgroup migration (P0) | — |
| **Search** | 🟡 | 🟢 | Goroutine recover + tx audit (P0/P1) | — |
| **Customer** | 🟡 | 🟢 | Preload Limit(500) caps (P1) | — |
| **Pricing** | 🟡 | 🟢 | Goroutine recover (P1) | — |
| **Shipping** | 🟡 | 🟢 | No blocker found | — |
| **Return** | 🟡 | 🟢 | Input validation (P1) | — |
| **Loyalty** | 🟡 | 🟢 | Input validation (P1) | — |
| **Location** | 🟡 | 🟢 | Circuit breakers (P1) | — |
| **Promotion** | 🟠 | 🟡 | Goroutine recover (P1) | Low test coverage |
| **Fulfillment** | 🟠 | 🟡 | Assessed safe (preloads bounded) | Low test coverage |
| **Review** | 🟠 | 🟡 | Input validation (P1) | No DLQ, low test coverage |
| **Analytics** | 🟠 | 🟡 | Goroutine recover (P1) | No outbox, low test coverage |
| **Notification** | 🟡 | 🟡 | — | Low test coverage |


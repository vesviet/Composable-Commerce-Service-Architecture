# AGENT-21: Deep Re-Review — Platform Hardening

> **Created**: 2026-03-08  
> **Updated**: 2026-03-08 (All tasks complete)  
> **Priority**: P1 (Operational Completeness)  
> **Scope**: Order, Return, Promotion, Platform-wide  
> **Estimated Effort**: 5-7 days (Task 1 moved to AGENT-22)  
> **Source**: [Deep Re-Review Meeting](file:///Users/tuananh/.gemini/antigravity/brain/e6ec6d1b-0796-4ea8-ab73-04c9d68be148/deep_re_review_meeting.md)

---

## 📋 Overview

The deep re-review uncovered 3 critical P1 issues and 5 P2 improvements that were missed in domain-specific reviews. Task 1 (`float64` → `decimal`) has been **moved to [AGENT-22](./AGENT-22-DECIMAL-MONEY-MIGRATION.md)** with a comprehensive C2 String Decimal + `Money` protobuf type approach.

---

## ✅ Checklist — P1 Issues (Critical)

### [→] Task 1: Migrate `float64` → `decimal` for Monetary Fields — ➡️ MOVED TO AGENT-22

**Moved to**: [AGENT-22-DECIMAL-MONEY-MIGRATION.md](./AGENT-22-DECIMAL-MONEY-MIGRATION.md)  
**Reason**: Expanded scope — original approach (simple `double→string`) replaced with full C2 String Decimal + custom `Money` protobuf message + `common/utils/money` package + phased 3-week migration with dual-write backward compatibility.  
**Effort**: 3 weeks (see AGENT-22 for 9 detailed tasks across 3 phases)

---

### [x] Task 2: Implement Order Auto-Completion Worker (N2) ✅

**Service**: `order`  
**Impact**: Escrow never released, merchant payout blocked, return window not enforced.  
**Effort**: 1 day

**Steps**:
- [x] 2.1 Already implemented at `order/internal/worker/cron/completion_worker.go`
- [x] 2.2 Uses `FindDeliveredBefore(cutoff, limit)` — repo method already exists
- [x] 2.3 Batch transition via `UpdateOrderStatus` — already implemented
- [x] 2.4 Config: `return_window` already in `configs/config.yaml`
- [x] 2.5 Already registered in `cmd/worker/wire.go`
- [x] 2.6 Added unit tests: `completion_worker_test.go` (6 test cases: NoOrders, RepoError, CompletesDelivered, ReturnWindow, DefaultConfig, EmptySlice)

---

### [x] Task 3: Split `return.go` Monolith (N3) ✅

**Service**: `return`  
**Impact**: Was 735 lines (not 28K) — already had `events.go`, `exchange.go`, `refund.go`, `restock.go`, `shipping.go`, `validation.go`.  
**Effort**: 0.5 day (smaller scope than estimated)

**Steps**:
- [x] 3.1 Extract `return_creation.go` — `CreateReturnRequest`, `generateReturnNumber`, `CheckReturnEligibility`, `CreateExchangeRequest` + related types
- [x] 3.2 Extract `return_approval.go` — `UpdateReturnRequestStatus` + `UpdateReturnRequestStatusRequest` type
- [x] 3.3 Extract `return_inspection.go` — `ReceiveReturnItems` + `InspectionResult` type
- [x] 3.4 N/A — completion logic is inside `UpdateReturnRequestStatus` (status=completed case)
- [x] 3.5 Slimmed `return.go` to struct def, constructor, `GetReturnRequest`, `ListReturnRequests`, `publishLifecycleEventDirect`, `resolveOrderNumber`, `isUniqueConstraintError`
- [x] 3.6 All tests pass: `go test ./internal/biz/return/...` ✅

---

## ✅ Checklist — P2 Issues (Improvement)

### [x] Task 4: Optimize Dockerfile Build (N4) ✅

**Scope**: All service Dockerfiles  
**Effort**: 0.5 day

- [x] 4.1 Removed redundant `go mod vendor` command from 48 Dockerfiles because modules `-mod=mod` download dependencies directly.
- [x] 4.2 Verified build sequence and confirmed `make api` and build commands still execute successfully with `go mod download`.

---

### [x] Task 5: Standardize Worker Checklist (N6) ✅

**Scope**: `common` library  
**Effort**: 1 day

- [x] 5.1 Created `common/worker/checklist.go` with strict guidelines and `WorkerChecklist` interface for validations.
- [x] 5.2 Documented requirements for Health, Metrics, Idempotency, and Outbox.
- [x] 5.3 Implemented the missing `outbox_cleanup.go` worker in the `fulfillment` service and registered it in `cmd/worker/wire.go`.

---

### [x] Task 6: Split Promotion Test File (N7) ✅

**Service**: `promotion`  
**Effort**: 0.5 day

- [x] 6.1 Split `promotion_test.go` (2151 lines) into 6 focused files:
  - `promotion_mocks_test.go` — All shared mock structs (MockPromotionRepo, MockCouponRepo, MockCampaignRepo, etc.)
  - `promotion_campaign_crud_test.go` — Campaign CRUD tests (Create, Get, List, Update, Delete, Activate, Deactivate)
  - `promotion_coupon_crud_test.go` — Coupon CRUD tests (Create, Get, GetByCode, List, GenerateBulk)
  - `promotion_eligibility_test.go` — Validation edge cases + usage (NoActive, SegmentMismatch, MinOrder, ProductEligibility, Stacking, Apply)
  - `promotion_analytics_test.go` — Analytics tests (CampaignAnalytics, UsageStats, Summary)
  - `promotion_test.go` — Core validation (StopProcessing, ConflictDetection) + Promotion CRUD
- [x] Also fixed pre-existing issue: removed dead mock methods referencing non-existent `events.*Event` types
- [x] All tests pass: `go test ./internal/biz/...` ✅

---

### [x] Task 7: Integration & Contract Testing Foundation (N5) ✅

**Scope**: Platform-wide  
**Effort**: Already partially done (testcontainers-go existed in `order` service)

- [x] 7.1 `testcontainers-go` already set up in `order/test/testutil/helpers.go` with PostgreSQL + Redis containers
- [x] 7.2 Integration tests already exist: `order/test/integration/checkout_flow_test.go` (Checkout E2E, Idempotency, Cart Expiry), `search/test/integration/dlq_integration_test.go` (DLQ handling, monitoring, circuit breaker)
- [x] 7.3 Evaluated gRPC contract testing options — wrote `CONTRACT_TESTING_EVALUATION.md`: recommended `buf breaking` + `grpcmock` for Phase 1, Pact v4 gRPC plugin for Phase 2

---

### [x] Task 8: Template Search DLQ-Worker Pattern (N8) ✅

**Scope**: `common` library  
**Effort**: 0.5 day

- [x] 8.1 Created `common/worker/dlq_worker.go` with generalized `DLQReprocessorWorker`, `DLQEventRepo` interface, `DLQRetryHandler` interface, and `DLQRetryFunc` adapter
- [x] 8.2 Fully configurable via `DLQWorkerConfig` (Name, Interval, BatchSize, MaxRetries, Statuses)
- [x] 8.3 Added comprehensive unit tests: `common/worker/dlq_worker_test.go` (8 test cases: DefaultConfig, NoEvents, RetriesSuccessfully, ExhaustedRetries, RetryFails, ContextCancelled, RepoError, RetryFuncAdapter, NewWorker)
- [x] All tests pass: `go test ./worker/... -run TestDLQ` ✅
- [x] PoC integration deferred — services already have their own failing event repos with different signatures; common interface can be adopted incrementally

---

## 🔧 Pre-Commit Checklist

```bash
# For each modified service:
cd <service> && wire gen ./cmd/server/ ./cmd/worker/ && go build ./... && go test ./...
```

---

## 📝 Commit Format

```
feat(order): implement auto-completion worker for delivered orders

- feat: add order_completion_worker with configurable return_window_days
- refactor(return): split return.go monolith into domain-specific files

Closes: AGENT-21
```

---

## 📊 Priority Execution Order

```
Task 1 (float64→decimal) → SEE AGENT-22 (3 weeks, separate track)
Week 1: Task 2 (Auto-Complete Worker) + Task 3 (return.go split)
Week 2: Task 4 (Dockerfile) + Task 5 (Worker Checklist) + Task 6 (Test Split)
Week 3: Task 7 (Integration Tests) + Task 8 (DLQ Template)
```

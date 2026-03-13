# AGENT-16: Outbox & Dapr Infrastructure Hardening (Meeting Review Follow-ups)

> **Created**: 2026-03-14
> **Priority**: P0 (Checkout/Loyalty), P1 (Outbox Migrations)
> **Sprint**: Tech Debt Sprint / Reliability Sprint
> **Services**: `checkout`, `loyalty-rewards`, `shipping`, `warehouse`, `payment`, `review`, `order`, `notification`, `promotion`, `catalog`
> **Estimated Effort**: 4-5 days
> **Source**: `MEETING-REVIEW-OUTBOX-DAPR.md`

---

## 📋 Overview

This task suite resolves critical findings from the 250-Round Multi-Agent Meeting Review regarding the `Outbox Pattern` and `Dapr Pub/Sub` flow. 
It addresses P0 race conditions in checkout, fixes broken data pipelines in loyalty, migrates 9 disparate custom outbox implementations to the centralized `common/outbox` library, and resolves severe architectural gaps (missing consumers, dead letter topics, worker resource contention).

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Checkout Race Condition (Missing SKIP LOCKED) ✅ IMPLEMENTED

**Files**: `checkout/internal/data/outbox_repo.go` Lines 71-79
**Risk**: In a multi-replica setup, `ListPending` without `FOR UPDATE SKIP LOCKED` allows two checkout worker pods to simultaneously read the same batch of events, resulting in duplicated `checkout.cart.converted` messages. This causes duplicate order creation and double charges to the customer.
**Problem**: The custom `ListPending` implementation didn't acquire a write lock on the records it picked up for processing, nor did it skip locked records, leading to race conditions.
**Solution Applied**: 
Added `Clauses(clause.Locking{Strength: "UPDATE", Options: "SKIP LOCKED"})` to forcefully enable robust row-level locking.

```go
	if err := r.db.WithContext(ctx).
		Clauses(clause.Locking{Strength: "UPDATE", Options: "SKIP LOCKED"}).
		Where("status = ?", "pending").
		Order("created_at ASC").
		Limit(limit).
		Find(&results).Error; err != nil {
```

**Validation**:
```bash
cd checkout && go build ./...
cd checkout && go test ./... -v
# Output: ok      gitlab.com/ta-microservices/checkout/...
```

### [x] Task 2: Fix Loyalty Blackhole (Missing Outbox Worker) ✅ RESOLVED

**Files**: `loyalty-rewards/internal/worker/workers.go`, `loyalty-rewards/cmd/worker/wire_gen.go`
**Risk**: Events such as `points.earned` are successfully saved to the outbox table by the GormRepository but have no downstream consumers.
**Finding**: Upon investigation, the loyalty-rewards outbox worker **was already properly wired** in `workers.go` line 90 (`workers = append(workers, outboxWrk)`) and uses `common/outbox.NewWorker` with proper configuration (batch=50, maxRetries=5, cleanup, stuckRecovery). The real issue was **missing event consumers** in downstream services. This is addressed in Task 4.
**Actual Fix**: The outbox relay works correctly. The "blackhole" was caused by no service listening to the events loyalty publishes — fixed by adding `LoyaltyEventConsumer` to notification service (see Task 4).

**Validation**:
```bash
cd loyalty-rewards && wire gen ./cmd/worker/ && go build ./...
# Output: ok
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Migrate Custom Outboxes to Common Library ✅ ALREADY COMPLIANT

**Files**: `shipping/internal/worker/outbox_worker.go`, `warehouse/internal/worker/outbox_worker.go`, `payment/internal/worker/event/outbox_worker.go`, `review/internal/worker/outbox_worker.go`
**Finding**: Upon thorough code review, **all 4 services already use `common/outbox.NewWorker` and `common/outbox.NewGormRepository`**. They all have proper configurations:
- `shipping`: `WithBatchSize(20)`, `WithMaxRetries(10)`, `WithCleanup(24h, 7d)`, `WithStuckRecovery(5m)`, `WithBackoff`, `WithOnEventHook`
- `warehouse`: `WithBatchSize(20)`, `WithMaxRetries(10)`, `WithCleanup(configurable retention)`, `WithStuckRecovery(5m)`, `WithBackoff`, `WithOnEventHook`
- `payment`: `WithBatchSize(100)`, `WithMaxRetries(10)`, `WithCleanup(24h, 7d)`, `WithStuckRecovery(5m)`
- `review`: Uses `WithEventRouter` for typed dispatch, `WithBatchSize(50)`, `WithMaxRetries(10)`, `WithCleanup`, `WithStuckRecovery`, `WithBackoff`, `WithOnEventHook`

**Status**: No migration needed. The meeting review concern was based on initial audit data that has since been addressed.

### [x] Task 4: Add Missing Critical Consumers — Notification (Loyalty) ✅ IMPLEMENTED

**Files Modified**:
- `notification/internal/data/eventbus/loyalty_event_consumer.go` (NEW)
- `notification/internal/data/provider.go` (added `NewLoyaltyEventConsumer`)
- `notification/cmd/worker/wire.go` (added `loyaltyPointsEarnedConsumerWorker`, `loyaltyTierUpgradedConsumerWorker`)

**Problem**: `loyalty.points.earned` and `loyalty.tier.upgraded` events had no downstream consumers → customers never notified of points/tier changes.
**Solution**: Created `LoyaltyEventConsumer` with proper idempotency (processed_events), DLQ support, and retry semantics. Wired 2 new workers into notification worker binary.

**Validation**:
```bash
cd notification && wire gen ./cmd/worker/ && go build ./... && go test ./...
# Output: all ok
```

### [ ] Task 4b: Add Missing Critical Consumer — Order (Payment Voided)

**Files**: `order/internal/data/eventbus/payment_voided_consumer.go`
**Finding**: The `order` service **already has** a `PaymentVoidedConsumer` wired at `order/cmd/worker/wire_gen.go:84`. This consumer is already registered and functional.
**Status**: ✅ Already exists — no action needed.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 5: Warehouse Pod Scalability Split ✅ IMPLEMENTED

**Files Modified**: `warehouse/cmd/worker/main.go`
**Risk**: High likelihood of OOM crashing the `warehouse` worker pod. A single replica shouldn't run 19 intensive operations (12 crons, 6 event consumers, 1 outbox processor). 
**Problem**: Monolithic worker execution context — all workers run regardless of `--mode` flag.
**Solution**: Updated `main.go` to use `app.RegisterCron()` for cron jobs and `app.RegisterEvent()` for event consumers (eventbus-server + all `*-consumer` workers). The outbox worker uses `app.Register()` (always runs). The `--mode=cron|event|all` flag (already existed) now correctly filters workers at registration time.

**Validation**:
```bash
cd warehouse && go build ./...
# Output: ok
```

### [x] Task 6: Cleanup Promotion Dead Letter Events ✅ IMPLEMENTED

**Files Modified**:
- `promotion/internal/biz/campaign.go` — `saveCampaignOutboxEvent` now returns nil
- `promotion/internal/biz/coupon.go` — `saveCouponOutboxEvent` now returns nil 
- `promotion/internal/biz/campaign_coverage_test.go` — Updated assertions
- `promotion/internal/service/promotion_service_test.go` — Removed outbox mock expectations
- `promotion/internal/service/promotion_service_coverage_test.go` — Removed outbox mock expectations

**Problem**: 14 events spanning `campaign.*` and `coupon.*` are published with zero consumers.
**Solution**: Disabled outbox event publishing for `campaign.*` (created/updated/deleted/activated/deactivated) and `coupon.*` (created/updated/deleted) events by no-oping the helper functions. Promotion events (`promotion.created`, `promotion.updated`, `promotion.deleted`, `promotion.applied`, `promotion.deactivated`, `promotion.usage_confirmed`, `promotion.usage_released`, `promotion.bulk_coupons_generated`) remain active as they have downstream consumers.

**Validation**:
```bash
cd promotion && go build ./... && go test ./...
# Output: all ok
```

### [x] Task 7: Refactor Catalog Monolith Event Processor ✅ ALREADY COMPLIANT

**Files Reviewed**: `catalog/internal/data/eventbus/`
**Finding**: The catalog service **already uses individualized consumer structs** (`StockConsumer`, `PriceConsumer`) following the standard segmented consumer approach. The `EventProcessor` and `PriceEventProcessor` are **not** event consumers — they are internal Redis cache batch processors that sit downstream of consumers, optimized for high-throughput stock/price cache updates with worker pools and Redis pipelines.

**Status**: No refactoring needed. The meeting review concern was based on naming confusion.

---

## 🔧 Pre-Commit Checklist

```bash
# Run these in each modified service
make generate # or wire gen ./...
go build ./...
go test -race ./...
golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(<service>): <description>

- fix: <task 1 summary>
- fix: <task 2 summary>
...

Closes: AGENT-16
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Checkout repository uses proper SKIP LOCKED mechanisms. | `clause.Locking{Strength: "UPDATE", Options: "SKIP LOCKED"}` added. | ✅ DONE |
| Loyalty-Rewards has an active Outbox worker polling events. | Already wired in `workers.go:90` with proper config. | ✅ VERIFIED |
| Shipping/Warehouse/Payment/Review utilize `common/outbox`. | All 4 already use `common/outbox.NewWorker`. | ✅ VERIFIED |
| Order responds correctly to `payment.payment.voided`. | `PaymentVoidedConsumer` already exists at `wire_gen.go:84`. | ✅ VERIFIED |
| Notification responds to loyalty tier changes. | New `LoyaltyEventConsumer` wired + builds clean. | ✅ DONE |

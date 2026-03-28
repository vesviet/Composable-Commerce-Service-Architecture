# AGENT-05: Warehouse & Reservation Stock — Reliability Hardening

> **Created**: 2026-03-28
> **Priority**: P0 (4 critical) + P1 (11 high) + P2 (13 backlog)
> **Sprint**: Architecture Hardening Sprint
> **Services**: `warehouse`
> **Estimated Effort**: 5-7 days
> **Source**: [Warehouse Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/a284e4db-b1c9-4a83-89c4-5ce6420b67a9/artifacts/warehouse_meeting_review.md), [Reservation Stock Review](file:///Users/tuananh/.gemini/antigravity/brain/a284e4db-b1c9-4a83-89c4-5ce6420b67a9/artifacts/reservation_stock_meeting_review.md)

---

## 📋 Overview

Consolidated hardening tasks from two exhaustive multi-agent reviews covering the warehouse service's **event-driven architecture**, **worker lifecycle**, **reservation stock lifecycle**, **data consistency**, and **concurrency control**. Issues range from silent worker death (cron jobs not blocking) to late-payment re-reservation failures (unique constraint blocking expired rows), with 4 P0 blockers that must be resolved before next production release.

### Architecture Context

```
Order ──gRPC──► Warehouse API ──TX──► PostgreSQL
  │                                       │
  │ event                                 │ outbox
  ▼                                       ▼
Dapr PubSub ◄──── Warehouse Worker ─── OutboxWorker
  │                    │
  ├─ Consumers (6)     ├─ Cron Jobs (10)
  └─ DLQ               └─ Expiry Workers (2)
```

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix 3 Cron Jobs `Start()` Not Blocking — Silent Worker Death

**Files**:
- `warehouse/internal/worker/cron/daily_reset_job.go` (lines 45-93)
- `warehouse/internal/worker/cron/daily_summary_job.go` (lines 44-72)
- `warehouse/internal/worker/cron/capacity_monitor_job.go` (lines 41-66)

**Risk**: Cron goroutines become orphaned — no graceful shutdown, no context propagation, `DailyResetJob` failure means throughput counters never reset → warehouse falsely "full" → rejects all orders.

**Problem**: These 3 jobs call `j.cron.Start()` then immediately `return nil` without blocking on `<-ctx.Done()`. Compare with correct pattern in `OutboxCleanupJob`, `ReservationCleanupJob`, `StockReconciliationJob`.

**Fix** — Apply to all 3 files:

```go
// BEFORE (daily_reset_job.go):
func (j *DailyResetJob) Start(ctx context.Context) error {
    // ... schedule crons ...
    j.cron.Start()
    j.log.WithContext(ctx).Info("Daily reset jobs started")
    return nil
}

// AFTER:
func (j *DailyResetJob) Start(ctx context.Context) error {
    // ... schedule crons ...
    j.cron.Start()
    j.log.WithContext(ctx).Info("Daily reset jobs started")
    <-ctx.Done()
    j.cron.Stop()
    j.log.Info("Daily reset jobs stopped")
    return nil
}
```

Apply identical `<-ctx.Done()` + `j.cron.Stop()` pattern to `DailySummaryJob.Start()` and `CapacityMonitorJob.Start()`.

**Validation**:

```bash
cd warehouse && grep -n "ctx.Done" internal/worker/cron/daily_reset_job.go internal/worker/cron/daily_summary_job.go internal/worker/cron/capacity_monitor_job.go
# Should show <-ctx.Done() in all 3 files
cd warehouse && go build ./...
cd warehouse && go test ./internal/worker/cron/... -v
```

---

### [ ] Task 2: Add Idempotency Guard to `HandleReturnCompleted` — Prevent Double Restock

**File**: `warehouse/internal/biz/inventory/inventory_events.go` (lines 14-89)

**Risk**: Dapr re-delivery causes double inbound transaction → inventory inflated → financial P&L mismatch. At Shopee-scale (1000+ returns/day), this compounds into significant inventory drift.

**Problem**: `HandleReturnCompleted` creates `CreateInboundTransaction` for each item without checking if inbound TX already exists. Compare with `handleFulfillmentCancelled` which has full idempotency.

**Fix**:

```go
// BEFORE (inventory_events.go, inside the for loop ~line 50):
_, _, err := uc.transactionUsecase.CreateInboundTransaction(ctx, inboundReq)

// AFTER:
// Idempotency: check if inbound TX already exists for this return+product
if uc.transactionRepo != nil {
    existing, txErr := uc.transactionRepo.GetByReference(ctx, "return", event.ReturnRequestID)
    if txErr == nil {
        alreadyCreated := false
        for _, tx := range existing {
            if tx.ProductID.String() == item.ProductID && tx.MovementType == "inbound" {
                alreadyCreated = true
                break
            }
        }
        if alreadyCreated {
            uc.log.WithContext(ctx).Infof("[IDEMPOTENT] Inbound TX already exists for return %s product %s — skipping", event.ReturnRequestID, item.ProductID)
            continue
        }
    }
}

_, _, err := uc.transactionUsecase.CreateInboundTransaction(ctx, inboundReq)
```

**Validation**:

```bash
cd warehouse && go build ./...
cd warehouse && go test ./internal/biz/inventory/... -v -run TestHandleReturnCompleted
```

---

### [ ] Task 3: Fix Unique Constraint Blocking Late-Payment Re-Reservation

**Files**:
- `warehouse/migrations/` (NEW migration)
- `warehouse/internal/data/eventbus/stock_committed_consumer.go` (lines 182-192)

**Risk**: Customer pays AFTER reservation expires → StockCommittedConsumer tries ReserveStock → `uk_reservation_idempotency` unique constraint violation → order stuck permanently in DLQ → lost revenue.

**Problem**: Migration 035 added `UNIQUE(reference_type, reference_id, product_id)` WITHOUT filtering by status. An expired/cancelled row blocks new reservation for same key.

**Fix** — Create new migration:

```sql
-- +goose Up
-- +goose StatementBegin

-- Drop the existing non-partial unique constraint
ALTER TABLE inventory_reservations
DROP CONSTRAINT IF EXISTS uk_reservation_idempotency;

-- Re-create as a PARTIAL unique index that only blocks duplicates
-- for reservations in active/fulfilled states.
-- Expired/cancelled rows no longer block re-reservation.
CREATE UNIQUE INDEX uk_reservation_idempotency
ON inventory_reservations(reference_type, reference_id, product_id)
WHERE status IN ('active', 'fulfilled');

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS uk_reservation_idempotency;

ALTER TABLE inventory_reservations
ADD CONSTRAINT uk_reservation_idempotency UNIQUE (reference_type, reference_id, product_id);
-- +goose StatementEnd
```

Also update `ReserveStock` idempotency check to handle `status IN ('active', 'fulfilled')` instead of just 'active':

```go
// reservation.go ~line 160: GetActiveByReference → also check fulfilled
existingRes, _ := uc.repo.GetActiveByReference(txCtx, req.ReferenceType, referenceID.String())
// Add fulfilled check
fulfilledRes, _ := uc.repo.GetByReference(txCtx, req.ReferenceType, referenceID.String())
for _, res := range fulfilledRes {
    if res.ProductID.String() == req.ProductID && res.Status == model.ReservationStatusFulfilled {
        uc.log.WithContext(txCtx).Infof("[IDEMPOTENT] Fulfilled reservation already exists for %s %s product %s", req.ReferenceType, referenceID, req.ProductID)
        created = res
        inv, invErr := uc.inventoryRepo.FindByWarehouseAndProduct(txCtx, req.WarehouseID, req.ProductID)
        if invErr != nil { return invErr }
        updated = inv
        return nil
    }
}
```

**Validation**:

```bash
cd warehouse && goose -dir migrations postgres "$DB_URL" up
cd warehouse && go build ./...
cd warehouse && go test ./internal/biz/reservation/... -v -run TestLatePaymentReReservation
```

---

### [ ] Task 4: Add Distributed Lock or Explicit Singleton for Cron Jobs

**Files**:
- `warehouse/cmd/worker/wire.go`
- `gitops/apps/warehouse/base/patch-worker.yaml` (OR `common/worker/`)

**Risk**: During rolling updates, old and new worker pods overlap for up to 60s (`terminationGracePeriodSeconds`) → ALL cron jobs execute N times simultaneously → duplicate outbox events, duplicate notifications, potential DB deadlocks.

**Problem**: `common/worker/checklist.go` line 21 marks distributed locking as unimplemented TODO. No singleton mode exists.

**Fix** — Choose ONE of:

**Option A (Quick — GitOps only)**: Set worker deployment strategy to `Recreate` with `replicas: 1`:
```yaml
# patch-worker.yaml
spec:
  replicas: 1
  strategy:
    type: Recreate  # Ensures old pod fully stops before new starts
```

**Option B (Proper — Distributed lock for each cron)**: Implement Redis-based distributed lock in cron job `Start()` methods:
```go
func (j *StockReconciliationJob) Start(ctx context.Context) error {
    _, err := j.cron.AddFunc("0 0 * * * *", func() {
        lock, err := j.redis.SetNX(ctx, "cron:stock-reconciliation:lock", "1", 50*time.Minute).Result()
        if err != nil || !lock {
            j.log.Info("Skipping cron — another instance holds the lock")
            return
        }
        defer j.redis.Del(ctx, "cron:stock-reconciliation:lock")
        // ... execute job ...
    })
}
```

**Validation**:

```bash
# Option A: Verify GitOps
kubectl kustomize gitops/apps/warehouse/overlays/dev > /dev/null
grep -A2 "strategy" gitops/apps/warehouse/base/patch-worker.yaml

# Option B: Verify lock implementation
cd warehouse && go build ./...
cd warehouse && go test ./internal/worker/cron/... -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 5: Fix `directStockDeductForFulfillment` Select-then-Insert Race Condition

**File**: `warehouse/internal/biz/inventory/fulfillment_status_handler.go` (lines 259-293)

**Risk**: 2 concurrent Dapr deliveries read "no existing TX" simultaneously → both deduct stock → double deduction.

**Fix**: Add DB unique index for idempotency guard:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS uk_stock_movement_idempotency
ON stock_movements(reference_type, reference_id, product_id, movement_reason)
WHERE movement_reason = 'fulfillment_direct_deduction';
```
Then catch unique constraint violation in Go code and skip silently (idempotent success).

**Validation**:
```bash
cd warehouse && go build ./...
cd warehouse && go test ./internal/biz/inventory/... -v -run TestDirectStockDeduct
```

---

### [ ] Task 6: Fix Damaged Item Transaction Semantic Mismatch

**File**: `warehouse/internal/biz/inventory/inventory_return.go` (lines 264-291)

**Risk**: Comment says "outbound" but calls `CreateInboundTransaction` with `inbound_damaged`. Analytics miscount damaged as sellable stock.

**Fix**: Change `movement_reason` to `"damaged_quarantine"` and update comment to match:
```go
// BEFORE:
MovementReason: "inbound_damaged",
// AFTER:
MovementReason: "damaged_quarantine",
```

**Validation**:
```bash
cd warehouse && go build ./...
grep -rn "inbound_damaged\|damaged_quarantine" warehouse/internal/
```

---

### [ ] Task 7: Move `reservation_expired` Event to Outbox Pattern

**File**: `warehouse/internal/biz/events/event_publisher.go` (lines 76-78)

**Risk**: Direct Dapr publish for `reservation_expired` event — if Dapr unavailable, event lost, Order service never auto-cancels.

**Problem**: `PublishReservationExpired` calls Dapr gRPC directly, bypassing transactional outbox.

**Note**: `ExpireReservation()` in `reservation.go:935-955` already uses outbox for this event. Verify no other code path calls `PublishReservationExpired` directly. If only `ExpireReservation` publishes this event (via outbox), mark `PublishReservationExpired` as deprecated or remove it.

**Validation**:
```bash
grep -rn "PublishReservationExpired" warehouse/internal/
# Should only appear in event_publisher.go definition — not called from biz layer
```

---

### [ ] Task 8: Persist `StockChangeDetector.lastCheckTime` to Redis

**File**: `warehouse/internal/worker/cron/stock_change_detector.go` (lines 28, 41)

**Risk**: Pod restart resets `lastCheckTime` → duplicate `stock_changed` outbox events → downstream consumers process same changes twice.

**Fix**:
```go
// BEFORE:
lastCheckTime: time.Now().Add(-1 * time.Minute),

// AFTER: Read from Redis, fallback to recent
lastCheckStr, err := j.redis.Get(ctx, "cron:stock-change-detector:last-check").Result()
if err == nil {
    j.lastCheckTime, _ = time.Parse(time.RFC3339, lastCheckStr)
} else {
    j.lastCheckTime = time.Now().Add(-1 * time.Minute)
}
// At end of each check cycle:
j.redis.Set(ctx, "cron:stock-change-detector:last-check", j.lastCheckTime.Format(time.RFC3339), 24*time.Hour)
```

**Validation**:
```bash
cd warehouse && go build ./...
cd warehouse && go test ./internal/worker/cron/... -v -run TestStockChangeDetector
```

---

### [ ] Task 9: Remove Duplicate `ReservationCleanupJob` — Keep Only `ReservationExpiryWorker`

**Files**:
- `warehouse/internal/worker/cron/reservation_cleanup_job.go` (DELETE or deprecate)
- `warehouse/cmd/worker/wire.go` (remove from provider set)

**Risk**: Two workers processing the same expired reservations wastes resources and adds complexity. Both are safe (idempotent), but redundant.

**Fix**: Remove `ReservationCleanupJob` from Wire injection and cron registration. Keep `ReservationExpiryWorker` with `BulkExpireReservations` (more efficient batch processing).

**Validation**:
```bash
cd warehouse && wire gen ./cmd/worker/ ./cmd/server/
cd warehouse && go build ./...
grep -rn "ReservationCleanupJob" warehouse/
# Should only appear in deleted/commented code
```

---

### [ ] Task 10: Fix Return Missing `warehouse_id` — Reject Instead of Fallback

**File**: `warehouse/internal/biz/inventory/inventory_events.go` (lines 36-54)

**Risk**: Multi-warehouse products restocked to arbitrary `inventories[0]` warehouse → wrong stock count.

**Fix**:
```go
// BEFORE:
if warehouseID == "" {
    // fallback to inventories[0]
}

// AFTER:
if warehouseID == "" {
    return fmt.Errorf("[DATA_CONSISTENCY] return %s missing warehouse_id for product %s — cannot determine correct warehouse for restock", event.ReturnRequestID, item.ProductID)
}
```

**Validation**:
```bash
cd warehouse && go build ./...
cd warehouse && go test ./internal/biz/inventory/... -v -run TestReturnMissingWarehouse
```

---

### [ ] Task 11: Clean Dead Retry Loop in `ReserveStock`

**File**: `warehouse/internal/biz/reservation/reservation.go` (lines 298-312)

**Risk**: Dead code creates false sense of retry protection. `IncrementReservedAtomic` returns "insufficient stock" not "VERSION_CONFLICT" — retry loop never triggers.

**Fix**: Either remove the retry loop entirely (atomic SQL handles concurrency) or change the error detection:
```go
// BEFORE:
if strings.Contains(err.Error(), "VERSION_CONFLICT") || strings.Contains(strings.ToLower(err.Error()), "version conflict") {

// AFTER (if keeping retry):
if strings.Contains(strings.ToLower(err.Error()), "insufficient stock") || strings.Contains(err.Error(), "VERSION_CONFLICT") {
```

**Validation**:
```bash
cd warehouse && go build ./...
cd warehouse && go test ./internal/biz/reservation/... -v
```

---

### [ ] Task 12: Fix `BulkExpireReservations` Dead Guard

**File**: `warehouse/internal/biz/reservation/reservation.go` (lines 1009-1013)

**Risk**: Guard `if freshRes.Status != model.ReservationStatusExpired` is always FALSE because `BulkUpdateStatus` at line 997 already set status to "expired". Guard is a no-op.

**Fix**: Remove the redundant `FindByID` + status check:
```go
// BEFORE:
freshRes, err := uc.repo.FindByID(txCtx, r.ID.String())
if err != nil || freshRes == nil || freshRes.Status != model.ReservationStatusExpired {
    continue
}

// AFTER:
// Status already set to "expired" by BulkUpdateStatus above.
// FOR UPDATE SKIP LOCKED in Step 1 already excluded rows locked by ConfirmReservation.
```

**Validation**:
```bash
cd warehouse && go build ./...
cd warehouse && go test ./internal/biz/reservation/... -v -run TestBulkExpire
```

---

### [ ] Task 13: Add Safety-Net for Fulfilled Orders With Stale Active Reservations

**File**: `warehouse/internal/worker/cron/stock_reconciliation_job.go`

**Risk**: If `fulfillment.status.changed` event is lost, stock stays reserved indefinitely — stock leak.

**Fix**: Add reconciliation check: find reservations with `status = 'active'` AND `reference_type = 'fulfillment'` AND `created_at < NOW() - INTERVAL '48 hours'`, then auto-confirm them:
```go
func (j *StockReconciliationJob) reconcileStaleReservations(ctx context.Context) {
    staleReservations, err := j.reservationRepo.FindStaleActive(ctx, 48*time.Hour)
    for _, res := range staleReservations {
        j.log.Warnf("[RECONCILIATION] Auto-confirming stale reservation %s (age > 48h)", res.ID)
        j.reservationUsecase.ConfirmReservation(ctx, res.ID.String())
    }
}
```

**Validation**:
```bash
cd warehouse && go build ./...
cd warehouse && go test ./internal/worker/cron/... -v -run TestStaleReservationReconciliation
```

---

### [ ] Task 14: Remove `IncrementReserved` (Non-Atomic) or Mark as Internal-Only

**File**: `warehouse/internal/data/postgres/inventory.go` (lines 512-520)

**Risk**: `IncrementReserved` exists alongside `IncrementReservedAtomic`. If any code path calls the non-atomic version → overselling possible because it lacks `WHERE available - reserved >= qty` check.

**Fix**:
```bash
grep -rn "IncrementReserved(" warehouse/internal/ --include="*.go" | grep -v "Atomic" | grep -v "_test.go"
```
If no callers found outside tests, remove `IncrementReserved` from `domain.InventoryRepo` interface and `postgres/inventory.go`. If callers exist, replace with `IncrementReservedAtomic`.

**Validation**:
```bash
cd warehouse && go build ./...
```

---

### [ ] Task 15: Add DLQ Monitoring for All 6 Consumers

**Files**:
- `warehouse/internal/data/eventbus/` (all consumers)
- `warehouse/internal/observability/prometheus/` (metrics)

**Risk**: Failed events silently rot in DLQ with no alerting. Critical events (return.completed, stock.committed) may never be processed.

**Fix**: Add Prometheus counter for DLQ events:
```go
// In each consumer, wrap handler to track DLQ:
dlqCounter := prometheus.NewCounterVec(prometheus.CounterOpts{
    Name: "warehouse_dlq_events_total",
    Help: "Events sent to dead letter queue",
}, []string{"topic"})
```

**Validation**:
```bash
cd warehouse && go build ./...
curl -s localhost:8006/metrics | grep warehouse_dlq
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 16: Fix camelCase JSON Tags on Product Events

**Files**:
- `warehouse/internal/observer/event/product_created.go`
- `warehouse/internal/observer/event/product_deleted.go`

**Fix**: Change `json:"eventType"` → `json:"event_type"`, `json:"productId"` → `json:"product_id"` to match all other event structs.

---

### [ ] Task 17: Fix `StockChangeDetector` OldStock Always 0

**File**: `warehouse/internal/worker/cron/stock_change_detector.go` (line 151)

**Fix**: Track previous stock value from the last check cycle or read from transaction history.

---

### [ ] Task 18: Replace Wildcard Cache Invalidation

**File**: `warehouse/internal/biz/inventory/inventory_helpers.go` (line 111)

**Fix**: Replace `InvalidateBulkStock(ctx, "*")` with product-specific invalidation: `InvalidateBulkStock(ctx, inventory.ProductID.String())`.

---

### [ ] Task 19: Fix stdlib `log.Printf` in Observer

**File**: `warehouse/internal/observer/fulfillment_status_changed/warehouse_sub.go` (line 64)

**Fix**: Replace `log.Printf(...)` with `s.logger.WithContext(ctx).Errorf(...)`.

---

### [ ] Task 20: Persist `ReservationWarning` Warned Map to Redis

**File**: `warehouse/internal/worker/expiry/reservation_warning.go` (line 25)

**Fix**: Replace in-memory `warnedReservations map[string]bool` with Redis SET.

---

### [ ] Task 21: Add Outbox Permanent Failure Alert

**File**: `warehouse/internal/worker/outbox_worker.go` (lines 56-58)

**Fix**: `OnEventHook` should publish metric or call notification when `retry_count >= MaxRetries`.

---

### [ ] Task 22: Fix ConfirmReservation Audit Trail Accuracy

**File**: `warehouse/internal/biz/reservation/reservation.go` (lines 712-768)

**Fix**: Read `quantity_available` AFTER `DecrementAvailable` for accurate `QuantityBefore`/`QuantityAfter`.

---

### [ ] Task 23: Fix ExpireReservation Audit Semantic Mismatch

**File**: `warehouse/internal/biz/reservation/reservation.go` (lines 922-924)

**Fix**: Audit should track `quantity_reserved` change, not `quantity_available`.

---

### [ ] Task 24: Move DistributedLocker to Wire DI

**File**: `warehouse/internal/biz/reservation/reservation.go` (line 85-87)

**Fix**: Replace setter injection `SetDistributedLocker` with Wire constructor parameter.

---

### [ ] Task 25: Fix `damaged` Event Fallback Direct Publish

**File**: `warehouse/internal/biz/inventory/inventory_return.go` (lines 326-344)

**Fix**: Remove fallback direct publish. If outbox is configured, use outbox only.

---

### [ ] Task 26: Remove `ReserveStock` Expiry Hardcoded 5-Minute Fallback

**File**: `warehouse/internal/biz/reservation/reservation.go` (line 225)

**Fix**: Use a config value instead of hardcoded `5 * time.Minute`.

---

### [ ] Task 27: Verify Worker Replicas Default

**File**: `gitops/apps/warehouse/base/kustomization.yaml` + `common-worker-deployment-v2` component

**Fix**: Explicitly set `replicas: 1` in worker deployment patch.

---

### [ ] Task 28: Fix Worker Label Selector Overlap With API

**File**: `gitops/apps/warehouse/base/kustomization.yaml` (lines 109-116)

**Fix**: Use `app.kubernetes.io/name: warehouse-worker` for worker deployment (not `warehouse`).

---

## 🔧 Pre-Commit Checklist

```bash
# Wire generation
cd warehouse && wire gen ./cmd/server/ ./cmd/worker/

# Build
cd warehouse && go build ./...

# Tests with race detection
cd warehouse && go test -race ./internal/biz/reservation/... ./internal/biz/inventory/... ./internal/worker/... ./internal/data/eventbus/... -v

# Linter
cd warehouse && golangci-lint run ./...

# Migration validation
cd warehouse && goose -dir migrations postgres "$DB_URL" status

# GitOps
kubectl kustomize gitops/apps/warehouse/overlays/dev > /dev/null
```

---

## 📝 Commit Format

```
fix(warehouse): reliability hardening for reservation stock lifecycle

- fix: add <-ctx.Done() blocking to 3 cron jobs (DailyReset, DailySummary, CapacityMonitor)
- fix: add idempotency guard to HandleReturnCompleted
- fix: change unique constraint to partial index for late-payment re-reservation
- fix: add distributed lock / singleton for cron jobs
- fix: remove dead retry loop in ReserveStock
- refactor: remove duplicate ReservationCleanupJob
- fix: add DLQ monitoring metrics

Closes: AGENT-05
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| All 10 cron jobs block in `Start()` | `grep -n "ctx.Done" internal/worker/cron/*.go` shows all files | |
| `HandleReturnCompleted` is idempotent | Double-delivery test passes without duplicate stock | |
| Late-payment re-reservation succeeds | Reserve → Expire → Reserve again for same order succeeds | |
| No cron duplicate during rolling update | Worker pod logs show exactly 1 cron execution per schedule | |
| `directStockDeduct` race-safe | Concurrent test shows no double deduction | |
| No orphan `IncrementReserved` calls | `grep -rn "IncrementReserved(" \| grep -v Atomic` returns zero results | |
| DLQ events have metrics | `curl /metrics \| grep dlq` returns counter | |
| Zero `go build` / `go test -race` failures | CI pipeline passes | |

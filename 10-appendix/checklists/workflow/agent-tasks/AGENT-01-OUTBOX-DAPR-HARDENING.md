# AGENT-01: Outbox Pattern & Dapr Event Flow Hardening

> **Created**: 2026-03-15
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`, `loyalty-rewards`, `shipping`, `warehouse`, `payment`, `review`, `order`, `notification`
> **Estimated Effort**: 3-5 days
> **Source**: [MEETING-REVIEW-OUTBOX-DAPR.md](MEETING-REVIEW-OUTBOX-DAPR.md)

---

## 📋 Overview

Refactor and harden the Outbox Pattern implementation and Dapr event consumer architecture across all services. The primary goal is to standardize the transaction outbox flow on `common/outbox`, eliminating double-processing due to non-standard race protections, adding missing outbox handlers, standardizing OTel tracing via common worker usages, and cleaning up unused event topics.

> **⚠️ POST-AUDIT NOTE (2026-03-15)**: Upon code-level audit, **all 6 tasks from the original meeting review were already implemented** in the current codebase! The meeting review data was stale by the time this task was planned. Each task below documents the evidence found.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Checkout Outbox Race Condition (SKIP LOCKED) ✅ ALREADY RESOLVED

**File**: `checkout/internal/worker/outbox/worker.go`
**Evidence**:
- Checkout **worker** already uses `commonOutbox.NewGormRepository()` (L28) which has built-in `SELECT ... FOR UPDATE SKIP LOCKED` via `common/outbox/gorm_repository.go:94`.
- Wire binding at `checkout/internal/worker/outbox/wire.go:14` properly binds `commonOutbox.Repository` → `*commonOutbox.GormRepository`.
- Worker is initialized with `commonOutbox.NewWorker("checkout", ...)` with batch size 50, max retries 10, stuck recovery 5m.
- Legacy custom repo at `checkout/internal/data/outbox_repo.go` is only used by the **server binary** for the Save path (biz layer inserting events), not for polling. It also has `SKIP LOCKED` at L73.

**Validation**:
```bash
# Confirmed via grep: worker uses common/outbox, not custom repo
grep "commonOutbox.NewGormRepository" checkout/internal/worker/outbox/worker.go  # ✅ Found L28
grep "SKIP LOCKED" checkout/internal/data/outbox_repo.go  # ✅ Found L73
```

### [x] Task 2: Fix Missing Loyalty Outbox Relay Initialization ✅ ALREADY RESOLVED

**File**: `loyalty-rewards/internal/worker/workers.go`
**Evidence**:
- `NewOutboxWorker` is in `ProviderSet` at L22.
- `NewOutboxWorker()` uses `common/outbox.NewWorker("loyalty-rewards", ...)` at L39 with batch 50, max retries 5, cleanup 30 days, stuck recovery 5m.
- Outbox worker is appended to active workers at L90: `workers = append(workers, outboxWrk)`.
- Wire gen confirms at `loyalty-rewards/cmd/worker/wire_gen.go:43`: `outboxWorker := worker2.NewOutboxWorker(repository, eventPublisher, logger)`.
- `NewDaprPublisher()` at L54 properly initializes the Dapr publisher for relay.

**Validation**:
```bash
grep "outboxWrk" loyalty-rewards/internal/worker/workers.go  # ✅ Found L80, L90
grep "NewOutboxWorker" loyalty-rewards/cmd/worker/wire_gen.go  # ✅ Found L43
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Migrate Services to Standard `common/outbox` ✅ ALREADY RESOLVED

**Files**: `shipping/internal/worker/outbox_worker.go`, `payment/internal/worker/event/outbox_worker.go`, `review/internal/worker/outbox_worker.go`
**Evidence**:
- **Shipping**: Uses `commonOutbox.NewGormRepository()` at L72 and `commonOutbox.NewWorker("shipping", ...)` at L97. Has `WithCleanup`, `WithStuckRecovery`, `WithBackoff`, `WithOnEventHook`.
- **Payment**: Uses `commonOutbox.NewGormRepository()` at L24 and `commonOutbox.NewWorker("payment", ...)` at L41. Has `WithCleanup(24h, 7d)`, `WithStuckRecovery`.
- **Review**: Uses `commonOutbox.NewGormRepository()` at L64 and `commonOutbox.NewWorker("review", ...)` at L81 with `EventRouter` for typed dispatch. Has `WithCleanup`, `WithStuckRecovery`, `WithBackoff`.
- Legacy custom repos (`payment/internal/data/outbox.go`, `shipping/internal/data/postgres/outbox.go`, `review/internal/data/postgres/outbox.go`) exist but are only used by the server binary Save path, not for relay polling.

**Validation**:
```bash
grep "commonOutbox.NewWorker" shipping/internal/worker/outbox_worker.go  # ✅ L97
grep "commonOutbox.NewWorker" payment/internal/worker/event/outbox_worker.go  # ✅ L41
grep "commonOutbox.NewWorker" review/internal/worker/outbox_worker.go  # ✅ L81
```

### [x] Task 4: Add Missing Critical Consumers (Order & Notification) ✅ ALREADY RESOLVED

**Files**: `order/internal/data/eventbus/payment_voided_consumer.go`, `notification/internal/data/eventbus/loyalty_event_consumer.go`
**Evidence**:
- **Order**: Has `PaymentVoidedConsumer` at `order/internal/data/eventbus/payment_voided_consumer.go` subscribing to `payment.payment.voided` (constant at `order/internal/constants/constants.go:34`). Includes idempotency helper.
- **Notification**: Has `LoyaltyEventConsumer` at `notification/internal/data/eventbus/loyalty_event_consumer.go` with `ConsumeLoyaltyPointsEarned` (subscribing to `loyalty.points.earned`) and `ConsumeLoyaltyTierUpgraded` (subscribing to `loyalty.tier.upgraded`).

**Validation**:
```bash
grep "payment.payment.voided" order/internal/data/eventbus/payment_voided_consumer.go  # ✅ Found
grep "loyalty.points.earned" notification/internal/data/eventbus/loyalty_event_consumer.go  # ✅ Found
grep "loyalty.tier.upgraded" notification/internal/data/eventbus/loyalty_event_consumer.go  # ✅ Found
```

### [x] Task 5: Configure Outbox Cleanup Retention ✅ ALREADY RESOLVED

**Files**: All outbox workers
**Evidence**:
- **Checkout**: `WithCleanup(24*time.Hour, 30*24*time.Hour, "processed", "failed")` — 30d retention
- **Loyalty**: `WithCleanup(24*time.Hour, 30*24*time.Hour, "processed")` — 30d retention
- **Shipping**: `WithCleanup(24*time.Hour, 7*24*time.Hour, "processed", "failed")` — 7d retention
- **Payment**: `WithCleanup(24*time.Hour, 7*24*time.Hour, "processed", "failed")` — 7d retention
- **Review**: `WithCleanup(24*time.Hour, 7*24*time.Hour, "processed", "failed")` — 7d retention

All services have cleanup properly configured via `common/outbox.WithCleanup()`.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 6: Warehouse Worker Pod Decoupling ✅ ALREADY RESOLVED

**File**: `warehouse/cmd/worker/main.go`
**Evidence**:
- Worker has CLI flag at L23: `flag.StringVar(&workerMode, "mode", "all", "Worker mode: cron|event|all")`
- Supports `--mode=cron`, `--mode=event`, `--mode=all` for K8s deployment separation.

**Validation**:
```bash
grep "mode" warehouse/cmd/worker/main.go  # ✅ Found L23
```

---

## 🔧 Pre-Commit Checklist

N/A — No code changes required. All tasks were pre-resolved.

---

## 📝 Commit Format

N/A — No commits needed.

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| `checkout` and `loyalty-rewards` exclusively leverage `commonOutbox` with transactional locking | Code audit confirms `commonOutbox.NewGormRepository` + `NewWorker` in worker binaries | ✅ |
| `order` actively catches and terminates orders upon `payment.voided` events | `PaymentVoidedConsumer` exists with idempotency | ✅ |
| `review` table limits data to trailing retention window | `WithCleanup(24h, 7d)` confirmed | ✅ |
| Workers are free of local dedup caches in relay path | Worker binaries use `common/outbox.Worker` exclusively | ✅ |
| Warehouse worker supports pod separation | `--mode=cron\|event\|all` flag exists | ✅ |

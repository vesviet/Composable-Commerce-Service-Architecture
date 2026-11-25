# 📊 Outbox Pattern Audit — All Services

**Generated**: 2026-03-07  
**Common Library**: `common/outbox/` — `Worker`, `GormRepository`, `Repository`, `Publisher`  
**Standard**: All services SHOULD use `common/outbox.NewWorker()` + `common/outbox.NewGormRepository()`

---

## Summary

| Service | Uses `common/outbox.Worker`? | Uses `common/outbox.GormRepository`? | SKIP LOCKED? | Stuck Recovery? | Cleanup? | Verdict |
|---------|:--:|:--:|:--:|:--:|:--:|---------|
| **customer** | ✅ Yes | ✅ Yes | ✅ (via common) | ✅ (via common) | ✅ (via common) | ✅ COMPLIANT |
| **return** | ✅ Yes | ✅ Yes | ✅ (via common) | ✅ (via common) | ✅ (via common) | ✅ COMPLIANT |
| **location** | ✅ Yes | ✅ Yes | ✅ (via common) | ✅ (via common) | ✅ (via common) | ✅ COMPLIANT |
| **fulfillment** | ⚠️ Partial | ✅ Yes | ✅ (via common) | ❓ Unknown | ❓ Unknown | ⚠️ CHECK |
| **notification** | ⚠️ Partial | ✅ Yes | ✅ (via common) | ❓ Unknown | ❓ Unknown | ⚠️ CHECK |
| **loyalty-rewards** | ❌ No Worker | ✅ GormRepo only | ✅ (via common) | ❌ None | ❌ None | 🔴 NO WORKER |
| **warehouse** | ❌ Custom | ❌ Custom | ✅ Custom | ✅ Custom | ✅ Custom | 🟡 CUSTOM |
| **shipping** | ❌ Custom | ❌ Custom | ✅ Custom | ✅ Custom | ⚠️ Hardcoded 7d | 🟡 CUSTOM |
| **review** | ❌ Custom | ❌ Custom | ❓ Unknown | ✅ Custom | ❌ None | 🟡 CUSTOM |
| **checkout** | ❌ Custom | ❌ Custom | ❌ **NO** | ✅ Custom | ✅ Custom | 🔴 MISSING SKIP LOCKED |
| **pricing** | ❌ Custom | ❌ Custom | ✅ Custom | ❌ None | ❌ None | 🟡 CUSTOM |
| **catalog** | ❌ Custom | ❌ Custom | ❓ Separate outbox | ⚠️ Unknown | ⚠️ Unknown | 🟡 CUSTOM |
| **order** | ❌ Custom | ❌ Custom | ❓ Unknown | ❓ Unknown | ❓ Unknown | 🟡 CUSTOM |
| **payment** | ❌ Custom | ❌ Custom | ❓ Unknown | ❓ Unknown | ❓ Unknown | 🟡 CUSTOM |

---

## 🔴 P0 — CRITICAL Issues

### P0-OUTBOX-01: Checkout outbox does NOT use `SKIP LOCKED`
- **File**: `checkout/internal/worker/outbox/worker.go:101`
- **Problem**: Uses `outboxRepo.ListPending(ctx, 50)`. If the repo does NOT use `FOR UPDATE SKIP LOCKED`, two worker replicas will process the same batch → **duplicate events** (double orders, double payments).
- **Impact**: Financial risk — duplicate `checkout.cart.converted` events.
- **Fix**: Either:
  - (A) Migrate checkout to `common/outbox.NewWorker()` + `common/outbox.NewGormRepository()` — both have SKIP LOCKED built-in
  - (B) Add `FOR UPDATE SKIP LOCKED` to the repo's ListPending query

### P0-OUTBOX-02: Loyalty-rewards has `GormRepository` but NO outbox worker
- **File**: `loyalty-rewards/internal/data/provider.go:44`
- **Problem**: `outbox.NewGormRepository()` is wired, events are written to outbox table via `Save()`, but no worker ever polls them. Events stay in `pending` forever.
- **Impact**: `points.earned`, `tier.changed` events never published.
- **Fix**: Add `outbox.NewWorker("loyalty-rewards", outboxRepo, publisher, logger)` to worker binary. Wire in `cmd/worker/`.
- **Note**: Agent 3 may have addressed this (P1-03 in their task).

---

## 🟡 P1 — HIGH Priority

### P1-OUTBOX-01: 7 services use custom outbox workers instead of `common/outbox.Worker`
Each custom implementation duplicates ~150-200 lines of boilerplate (poll loop, retry, cleanup, metrics). Issues:

| Service | Custom File | Missing vs Common | Specific Gap |
|---------|------------|-------------------|--------------|
| **warehouse** | `internal/worker/outbox_worker.go` | OTel trace propagation, EventRouter, backoff strategy | Hardcoded `cleanupOldEvents` every 100 cycles instead of configurable |
| **shipping** | `internal/worker/outbox_worker.go` | OTel trace propagation, EventRouter, backoff strategy, backlog threshold | Hardcoded cleanup retention 7d |
| **review** | `internal/worker/outbox_worker.go` | OTel trace propagation, metrics, cleanup, stuck recovery timing | No cleanup at all, no Prometheus metrics |
| **checkout** | `internal/worker/outbox/worker.go` | SKIP LOCKED, OTel trace propagation, backoff | In-memory dedup cache instead of DB-level idempotency |
| **pricing** | `internal/data/postgres/price.go` | Full worker (only raw SQL query) | Inline raw SQL, no worker abstraction |
| **catalog** | Custom event processor | EventRouter, metrics collection | Uses separate EventProcessor pattern |
| **order** | Custom | Unknown full gap | Needs deeper inspection |

### P1-OUTBOX-02: Review outbox worker has NO event cleanup — table grows unbounded
- **File**: `review/internal/worker/outbox_worker.go`
- **Problem**: No `cleanupOldEvents()` or `DeleteOld()` call. Processed events accumulate forever.
- **Fix**: Either migrate to `common/outbox.Worker` (has `WithCleanup()`), or add cleanup method.

### P1-OUTBOX-03: Review outbox worker has NO Prometheus metrics
- **File**: `review/internal/worker/outbox_worker.go`
- **Problem**: Unlike warehouse/shipping custom workers, review has no `metricEventsProcessed`/`metricEventsFailed` counters.
- **Fix**: Add metrics or migrate to `common/outbox.Worker` (has `WithMetrics()`).

### P1-OUTBOX-04: Shipping cleanup retention hardcoded to 7 days
- **File**: `shipping/internal/worker/outbox_worker.go:179`
- **Problem**: `7 * 24 * time.Hour` is hardcoded. Common library supports configurable retention via `WithCleanup()`.
- **Fix**: Migrate to `common/outbox.Worker` or read from config.

---

## ⚠️ P2 — Nice to Have / Tech Debt

### P2-OUTBOX-01: Custom workers miss trace propagation
- **Services**: warehouse, shipping, review, checkout
- **Problem**: Common `outbox.Worker` parses `Traceparent` from the stored event and creates correlated OTel spans. Custom workers create fresh spans — breaking cross-service trace continuity.

### P2-OUTBOX-02: No `EventRouter` in custom workers
- **Services**: warehouse, shipping, checkout
- **Problem**: Common `outbox.Worker` supports `WithEventRouter()` for service-specific dispatch logic (cache invalidation, view refresh). Custom workers implement this ad-hoc or not at all.

### P2-OUTBOX-03: Custom workers use `prometheus.MustRegister(init())` pattern
- **Services**: warehouse, shipping
- **Problem**: `init()` with `MustRegister` can panic if metrics are registered twice (e.g., test setup). Common worker uses `WithMetrics()` which avoids this.

### P2-OUTBOX-04: Inconsistent backoff strategies
- **Services**: All custom workers
- **Problem**: Common worker supports `WithBackoff()` for exponential backoff. Custom workers use immediate retry (set back to `pending` immediately), causing tight retry loops under Dapr outage.

### P2-OUTBOX-05: Inconsistent max retries
- **Services**: warehouse (10), shipping (10), checkout (10), review (no max)
- **Problem**: Review has no retry cap — events retry forever.

### P2-OUTBOX-06: Custom outbox repos define their own `OutboxEvent` model
- **Services**: warehouse, shipping, review, checkout, pricing
- **Problem**: Each service has its own `OutboxEvent` struct. Common library already defines `outbox.GormOutboxEvent`. Field names and JSON tags may diverge.

---

## ✅ COMPLIANT Services (Using `common/outbox`)

| Service | Worker Wire Location | Repo Wire Location |
|---------|--------------------|--------------------|
| **customer** | `cmd/worker/wire.go:197` | `internal/data/postgres/outbox_event.go:22` |
| **return** | `internal/worker/outbox_worker.go:11` | `internal/data/outbox.go:16` |
| **location** | `internal/worker/provider.go:23` | `internal/data/provider.go:42` |
| **fulfillment** | Partial (GormRepo only in wire_gen) | `cmd/worker/wire_gen.go:59` |
| **notification** | Partial (GormRepo only in wire_gen) | `cmd/worker/wire_gen.go:64` |

---

## 📋 Recommended Migration Path

### Priority 1 (P0): Fix checkout SKIP LOCKED + Loyalty outbox worker
1. Checkout: `common/outbox.NewGormRepository()` has SKIP LOCKED → replace custom repo
2. Loyalty-rewards: Wire `common/outbox.NewWorker()` into worker binary

### Priority 2 (P1): Migrate high-traffic services to `common/outbox.Worker`
1. **warehouse** → Replace custom worker with `outbox.NewWorker("warehouse", repo, pub, log, outbox.WithBatchSize(20), outbox.WithMaxRetries(10), outbox.WithCleanup(24h, 30d, "processed"))`
2. **shipping** → Same pattern
3. **review** → Same pattern (highest gap — no cleanup, no metrics)

### Priority 3 (P2): Remaining services
4. **checkout** → Full migration (replace custom dedup cache with DB-level idempotency)
5. **pricing** → Extract inline outbox logic into proper worker
6. **order**, **payment**, **catalog** → Audit and migrate

---

*Each migration should be a separate PR with before/after tests verifying event processing behavior is preserved.*

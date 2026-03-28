# AGENT-16: Add Scheduler Singleton Mode to `common/worker`

> **Created**: 2026-03-28  
> **Updated**: 2026-03-28  
> **Priority**: P1  
> **Sprint**: Common Library Hardening Sprint  
> **Services**: `common`, plus consumers of `gitlab.com/ta-microservices/common`  
> **Estimated Effort**: 2-3 days (library); per-service adoption is incremental  
> **Source**: Deep review of `common/worker`, `common/outbox`, and worker usage across services

---

## Release status (common)

| Item | Value |
|------|--------|
| **Git tag** | `v1.31.3` |
| **Module** | `gitlab.com/ta-microservices/common` |
| **Scope** | `common/worker`: `SchedulerLock`, `RedisSchedulerLock`, `CronWorker` singleton options, `ProcessSingletonCoordinator`, health `role` on `/readyz`, `StopAll` → concrete `Stop` |

Library implementation is **done** and pushed. Service adoption is **optional per team** and should follow the playbook below.

---

## Overview

The `common/worker` package now provides:

- worker lifecycle management  
- cron / event / all mode routing  
- health endpoints (including optional **`role`: `leader` \| `standby`**)  
- basic metrics  
- graceful shutdown with **concrete** `Stop()` for lease cleanup  
- **opt-in** singleton scheduling: **per-cron** (`CronWorker` + `WithSingleton`) or **whole process** (`ProcessSingletonCoordinator` + `Wrap`)

See `common/worker/README.md` in the common repo for API details.

---

## Summary of Review Findings (historical)

### Previous gaps (addressed in v1.31.3)

1. ~~`CronWorker` was process-local only~~ → optional `WithSingleton` + `SchedulerLock`.  
2. ~~`WorkerApp` had no leader gate~~ → use `ProcessSingletonCoordinator` where one replica must run all crons.  
3. ~~Checklist deferred locking to services~~ → shared `RedisSchedulerLock` + documented patterns.  
4. ~~`analytics` bespoke leader lock~~ → migrated to `ProcessSingletonCoordinator`.  
5. Other services may still use ad hoc `SETNX`; migrate incrementally using the playbook.  
6. `common/outbox` remains multi-replica-safe without singleton (`SKIP LOCKED`).

---

## Checklist - P1 Issues (shared library)

### [x] Task 1: Native singleton scheduling abstraction in `common/worker`

- `SchedulerLock` interface; `CronWorker` options: `WithSingleton`, `WithStandbyHealthy`, `WithSingletonOwner`, `WithSingletonRetry`.  
- `WithRunOnStart` runs after lock acquisition when singleton is enabled.

### [x] Task 2: Redis-backed `RedisSchedulerLock`

- Owner-based acquire / Lua renew / Lua release (no blind `DEL`).

### [x] Task 3: Leader / standby readiness semantics

- `SchedulerRoleAware`, `/readyz` JSON `role` field via `AddCheckerWithRole`.  
- Standby can stay ready when `WithStandbyHealthy(true)` (default).

### [x] Task 4: Registry shutdown calls concrete `Stop()`

- `ContinuousWorkerRegistry` stores concrete workers; `StopAll` invokes `ContinuousWorker.Stop`.

### [x] Task 5: Documentation

- `common/worker/README.md` (in repo `common`).

---

## Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Opt-in singleton cron execution | `CronWorker` + `WithSingleton` + `SchedulerLock` | Done (v1.31.3) |
| Renew / safe release | `RedisSchedulerLock` + renew goroutine in `CronWorker` | Done |
| Standby vs leader explicit | `/readyz` includes `role` when applicable | Done |
| `StopAll` → concrete shutdown | `continuous_worker.go` + tests | Done |
| At least one service drops bespoke leader code | `analytics` uses `ProcessSingletonCoordinator` | Done |
| Outbox unchanged | `go test ./outbox/...` | Pass |

---

## Pre-commit validation (common)

```bash
cd common && go test ./worker/... ./outbox/... ./idempotency/... -short
```

---

## Step-by-step: bump `common` in any Go service

Do this **once per service** when you are ready to adopt `v1.31.3` (or only bump version without using singleton APIs yet).

### Step 1 — Update dependency

From the service repository root:

```bash
go get gitlab.com/ta-microservices/common@v1.31.3
go mod tidy
```

If the service uses vendoring:

```bash
go mod vendor
```

### Step 2 — Remove local `replace` (if present)

If `go.mod` contains:

```go
replace gitlab.com/ta-microservices/common => ../common
```

remove that `replace` line after `go get` so CI resolves the tagged module from GitLab.

### Step 3 — Build and test

```bash
go build ./...
go test ./... -short
```

Focus extra tests on `cmd/worker` and `internal/worker` if the service has a worker binary.

### Step 4 — Deploy

Merge to your deployment branch and let GitLab CI build/push the image as usual. No Helm change is required **only** for a dependency bump unless you change env vars or replica counts.

---

## Step-by-step: adopt singleton APIs (when you change code)

Choose **one** pattern; do not add singleton to outbox or idempotent consumers unless there is a product reason.

### Pattern A — Whole worker process has a single leader (all crons on one replica)

**When**: One Redis (or similar) lease for the entire `cmd/worker` process — same as former bespoke `analytics` leader election.

**Steps**:

1. Inject or construct `*redis.Client` in `cmd/worker/main.go` (or Wire).  
2. Create lock and coordinator:

```go
schedLock := worker.NewRedisSchedulerLock(rdb, logger)
coord := worker.NewProcessSingletonCoordinator(
    schedLock,
    "your-service:worker:leader", // unique key per env/service
    15*time.Second,
    podOrOwnerID,
    logger,
    // optional: worker.WithProcessSingletonStandbyHealthy(false),
)
coordCtx, coordCancel := context.WithCancel(context.Background())
defer coordCancel()
go coord.Run(coordCtx)
```

3. Register workers with `app.Register(coord.Wrap(w))` instead of `app.Register(w)`.  
4. Delete custom `SetNX` / leader goroutines / wrapper types from `main.go`.  
5. Test: `go test ./cmd/worker/...` and run two replicas locally or in staging; verify one leader and standby ready.

### Pattern B — Only some periodic jobs must be singleton

**When**: Most workers scale horizontally; one or a few `CronWorker` jobs must run on one replica only.

**Steps**:

1. Build `RedisSchedulerLock` once (shared `redis.Cmdable`).  
2. For each `NewCronWorker(...)`, add options, e.g.:

```go
worker.NewCronWorker("cleanup", interval, logger, doFunc,
    worker.WithSingleton(lock, "your-service:cron:cleanup", lockTTL),
    worker.WithStandbyHealthy(true),
)
```

3. Use a **distinct lock key per job** (not one key shared by all crons unless intentional).  
4. Remove inline `SetNX` + blind `DEL` inside the job body; rely on framework lock semantics.  
5. Test two replicas: only one should execute the job per tick; `/readyz` should show `role` where implemented.

### Pattern C — No code change

**When**: Service only needs security patches or other `common` fixes; no cron singleton issues.

**Steps**: Perform **Step 1–4** in “bump common” only.

---

## Per-service migration guidance (suggested order)

Use this table to plan work. Priority is **suggestion** only; align with your team.

| Service | Suggested pattern | Notes |
|---------|-------------------|--------|
| **analytics** | A (done) | `ProcessSingletonCoordinator` + `RedisSchedulerLock`; bump to `v1.31.3` and drop `replace` when CI uses the tag. |
| **loyalty-rewards** | B | Replace manual `SETNX` in `internal/jobs/*` with `CronWorker` + `WithSingleton` or shared `RedisSchedulerLock` inside a thin wrapper. |
| **customer** | B | `segment_evaluator`: `WithSingleton` on the cron path or one lock key per schedule. |
| **common-operations** | B | `process_scheduled_tasks`-style jobs: same as above. |
| **warehouse** | Mixed | Many `robfig/cron` jobs; only add singleton where global side effects exist (reconciliation, reports). Keep parallel-safe jobs unchanged. |
| **payment** | C | Domain `DistributedLock` in `internal/data/lock.go` is a different concern; migrate only if you want to unify on `RedisSchedulerLock` API later. |
| **Outbox / event consumers** | C | Do **not** enable singleton; outbox uses `SKIP LOCKED`. |

---

## Implementation notes (constraints)

- Keep singleton **opt-in**; do not wrap `WorkerApp` globally by default.  
- Prefer **owner** + Lua release over `SETNX` + unconditional `DEL`.  
- Do **not** convert the outbox worker to singleton mode.  
- After losing leadership in a long-running process, consider operational follow-up (alerting) if inner work continues — same class of edge case as any leader election.

---

## References

- Common tag: **`v1.31.3`** — `https://gitlab.com/ta-microservices/common/-/tags/v1.31.3`  
- In-repo doc: `common/worker/README.md` (clone `common` and open that path).

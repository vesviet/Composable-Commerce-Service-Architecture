# AGENT-16: Add Scheduler Singleton Mode to `common/worker`

> **Created**: 2026-03-28  
> **Updated**: 2026-03-28 (per-service worker review)  
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

## Rà soát từng service (`cmd/worker`) — có cần singleton không?

Phần này ghi lại **kết quả review codebase** (Wire `wire_gen.go` / `wire.go`, cron, outbox, consumer). Mục tiêu: biết service nào **nên** thêm singleton cho **job định kỳ / tác vụ toàn cục**, và service nào **không** cần (outbox / consumer scale ngang).

### Cách đọc kết quả

| Cột / giá trị | Ý nghĩa |
|----------------|---------|
| **Cần singleton (cron / job)** | Có ít nhất một cron hoặc ticker làm việc “một lần trên cluster” (cleanup, reconciliation, báo cáo, refresh MV, …). Nên dùng **Pattern B** (theo job) hoặc **Pattern A** (cả process) tùy mức. |
| **Một phần** | Chủ yếu outbox + consumer; chỉ **một vài** cron cần xem xét singleton. |
| **Không cần (worker)** | Worker chủ yếu là **outbox** + **event consumer** — đã an toàn multi-replica; chỉ cần **Pattern C** khi bump `common`. |
| **Đã xử lý** | Đã dùng API chung (`ProcessSingletonCoordinator` / `WithSingleton`). |

### Các bước review (áp dụng khi tự kiểm tra lại)

1. Mở `cmd/worker/wire_gen.go` (hoặc `wire.go`) — liệt kê worker: **outbox**, **consumer**, **CronWorker** / `robfig/cron`.  
2. Với **outbox** / **Dapr consumer**: **không** gắn singleton (đã có `SKIP LOCKED` / idempotency).  
3. Với **mỗi cron** (đặc biệt cleanup, reconciliation, báo cáo, refresh): hỏi “nếu chạy N replica cùng lúc có **trùng tác vụ toàn cục** không?” — nếu **có** → thêm **Pattern B** (khóa theo job) hoặc **Pattern A** (một leader cho cả process).  
4. Nếu trong code đã có **SETNX thủ công** → ưu tiên migrate sang `RedisSchedulerLock` / `WithSingleton`.

### Bảng tổng hợp (20 service có `cmd/worker` trong monorepo)

| STT | Service | Kết quả | Worker chính (tóm tắt) | Gợi ý hành động |
|-----|---------|---------|------------------------|-----------------|
| 1 | **analytics** | Đã xử lý | Cron jobs + `ProcessSingletonCoordinator` + Redis | Bump `common@v1.31.3`; bỏ `replace` local nếu có. |
| 2 | **auth** | Một phần | `SessionCleanupWorker` + `EventConsumerWorker` + outbox | Session cleanup: nếu lo trùng xóa / tải DB, cân nhắc `WithSingleton` cho **một** cron đó; consumer + outbox: không singleton. |
| 3 | **catalog** | Cần singleton (cron) | Outbox + stock/price consumer + **MV refresh** + **outbox cleanup** | **Pattern B** cho `MaterializedViewRefreshJob`, `OutboxCleanupJob` (khóa theo job). Consumer/outbox: không. |
| 4 | **checkout** | Không cần | Chủ yếu outbox | **Pattern C** (chỉ bump `common`). |
| 5 | **common-operations** | Cần singleton | Nhiều `CronWorker`; **SETNX** trong `process_scheduled_tasks`, `cleanup_old_tasks` | **Pattern B** hoặc thay SETNX bằng `RedisSchedulerLock`; Dapr server / polling: đánh giá riêng (thường không bọc cả process trừ khi có yêu cầu). |
| 6 | **customer** | Cần singleton | Outbox + consumer + **segment** (đã SETNX) + stats + GDPR cleanup | **Pattern B** cho segment evaluator; các cron khác: tùy (stats/cleanup có thể singleton nhẹ). |
| 7 | **fulfillment** | Cần singleton (cron) | Consumers + outbox + **auto complete shipped**, **SLA breach**, **outbox cleanup** | **Pattern B** cho từng cron “global”; **không** singleton cho outbox/consumer. |
| 8 | **gateway** | Không cần | Chỉ consumer (cache invalidation) | **Pattern C**. |
| 9 | **loyalty-rewards** | Cần singleton | Outbox + consumer + **points expiration / pending points** (SETNX trong job) | **Pattern B** — migrate SETNX → `WithSingleton` + `RedisSchedulerLock`. |
| 10 | **location** | Không cần | Outbox | **Pattern C**. |
| 11 | **notification** | Một phần | Nhiều consumer + outbox + **`notification_worker` (robfig cron)** | Xem từng **schedule** cron: gửi batch / digest / retry → thường **nên singleton** cho job đó; consumer/outbox: không. |
| 12 | **order** | Cần singleton (cron) | Nhiều `CronWorker` (cleanup, reservation, COD, capture, compensation, idempotency, completion) + event consumer + outbox | **Pattern B** lần lượt cho các cron “toàn cục”; **không** bọc outbox/consumer. |
| 13 | **payment** | Một phần | Nhiều cron (reconciliation, retry, …) + webhook retry + outbox + consumer; **DistributedLock** trong domain (khác scheduler) | Cron reconciliation / cleanup: **Pattern B** nếu chưa đủ an toàn multi-replica; giữ domain lock cho payment/refund như hiện tại. |
| 14 | **promotion** | Không cần | Outbox + order consumer | **Pattern C**. |
| 15 | **return** | Một phần | Outbox + **stale return cleanup** (`NewCronWorker`) | **Pattern B** cho cleanup cron nếu chạy nhiều replica. |
| 16 | **review** | Không cần | Outbox | **Pattern C**. |
| 17 | **search** | Cần singleton (cron) | Nhiều consumer + trending/popular + **DLQ** + **reconciliation** + orphan + failed-event cleanup | **Pattern B** cho các job đụng index / DLQ / reconciliation toàn cục; consumer: không. |
| 18 | **shipping** | Không cần | Outbox + consumer | **Pattern C**. |
| 19 | **user** | Không cần | Outbox | **Pattern C**. |
| 20 | **warehouse** | Cần singleton (cron) | Nhiều `robfig/cron` (reconciliation, stock detector, báo cáo, cleanup, …) + outbox + consumer; **RedisDistributedLocker** cho reservation (khác cron) | **Pattern B** theo từng cron “một runner”; **không** singleton outbox; locker reservation giữ nguyên logic domain. |

### Ưu tiên migrate (gợi ý)

| Ưu tiên | Service | Lý do ngắn |
|---------|---------|------------|
| **P0** | **loyalty-rewards**, **customer** (segment), **common-operations** | Đã có SETNX thủ công — dễ lệch semantics / blind DEL. |
| **P1** | **order**, **warehouse**, **search** | Nhiều cron toàn cục — rủi ro trùng chạy khi scale worker. |
| **P2** | **fulfillment**, **catalog**, **payment** (cron), **notification** (cron), **return**, **auth** (session cleanup) | Từng job xử lý dần bằng Pattern B. |
| **P3** | **gateway**, **user**, **location**, **promotion**, **checkout**, **shipping**, **review** | Chỉ bump `common` trừ khi sau này thêm cron “global”. |

### Lưu ý chung

- **Outbox worker** và **event consumer** trong bảng trên: **không** chuyển sang singleton.  
- **Warehouse** `DistributedLocker` / **Payment** domain lock: là **khóa nghiệp vụ**, không thay bằng singleton worker trừ khi refactor có chủ đích.  
- **analytics**: đã dùng **Pattern A** — làm mẫu cho bất kỳ service nào muốn **một replica** chạy **toàn bộ** nhóm cron.

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

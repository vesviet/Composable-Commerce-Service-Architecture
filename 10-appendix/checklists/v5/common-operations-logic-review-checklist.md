# Common-Operations Business Logic Review Checklist

> **Service**: `common-operations/` — Task orchestration & MinIO file operations  
> **Reviewed**: 2026-02-18 | **Reviewer**: AI Senior Architect  
> **Benchmark**: Shopify (job pipeline), Shopee (async task engine), Lazada (bulk operations platform)

---

## 1 — Data Consistency Between Services

### 1.1 Task Creation → Event Record (Non-Atomic)

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| DC-01 | `CreateTask` writes task to DB then writes event to DB in **separate** non-transactional calls. If event creation fails, task exists in DB without an event record → **phantom task** | 🔴 P0 | [task.go](file:///d:/microservices/common-operations/internal/biz/task/task.go#L159-L201) | 174→188 |
| DC-02 | `CreateTask` returns error on event creation failure but the task row **already persists** — caller sees error, task is orphaned | 🔴 P0 | [task.go](file:///d:/microservices/common-operations/internal/biz/task/task.go#L185-L188) | 185-188 |
| DC-03 | `CreateService.CreateTask` creates task → generates upload URL → **updates task again** via `UpdateTask()`. Three separate DB writes with no transaction. If step 2 or 3 fails, task exists with incorrect `InputFileURL` | 🟡 P1 | [operations.go](file:///d:/microservices/common-operations/internal/service/operations.go#L37-L93) | 67→83 |
| DC-04 | `UpdateTask` does `Get` → validate → `Update` as **3 separate queries** with no row-level locking (`SELECT ... FOR UPDATE`). Concurrent workers can read stale state and apply conflicting transitions | 🔴 P0 | [task.go](file:///d:/microservices/common-operations/internal/biz/task/task.go#L227-L276) | 231→255 |

> [!CAUTION]
> **Shopify pattern**: All job state mutations use DB transactions. Shopee wraps state transitions in `SELECT ... FOR UPDATE` to prevent race conditions. Current code has **zero transactions** in the entire business logic layer.

### 1.2 Cross-Service Data Fetch (Order Export)

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| DC-05 | Order export fetches via gRPC pagination. If the order service data changes mid-export (new orders added, orders deleted), exported data is **point-in-time inconsistent** — may include duplicates or miss records | 🟡 P1 | [order_exporter.go](file:///d:/microservices/common-operations/internal/exporter/order_exporter.go#L95-L165) | 103-161 |
| DC-06 | Only first status filter applied (`params.Filters.Status[0]`) — multi-status export silently drops remaining statuses | 🟡 P1 | [order_exporter.go](file:///d:/microservices/common-operations/internal/exporter/order_exporter.go#L113-L115) | 114 |
| DC-07 | Order client uses `DialInsecure` with no circuit breaker, no retry, no timeout configuration. Single gRPC failure during page fetch aborts entire export | 🟡 P1 | [order_client.go](file:///d:/microservices/common-operations/internal/client/order_client.go#L22-L44) | 29-35 |

### 1.3 Cache Consistency

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| DC-08 | Redis cache TTL is 15 minutes. Worker reads task from cache, modifies it, writes back. If another worker updated the DB in between, the stale cached version **overwrites** the newer DB version via `Save()` | 🟡 P1 | [task_cache.go](file:///d:/microservices/common-operations/internal/data/redis/task_cache.go#L33) + [task_repo.go](file:///d:/microservices/common-operations/internal/data/postgres/task_repo.go#L109-L123) | — |
| DC-09 | `Get()` caches on read, but `Update()` only deletes cache. Between delete and next read, a race window allows serving stale data from another process | 🟢 P2 | [task_repo.go](file:///d:/microservices/common-operations/internal/data/postgres/task_repo.go#L33-L56) | 33-56 |

---

## 2 — Data Mismatch Cases

### 2.1 Dual Validation → Inconsistent Rules

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| MM-01 | **Three separate validation locations** with divergent allowed task types: `model.Task.validateTaskType()` allows 11 types (`import`, `export`, `process`, `delete`, `order_processing`, `notification_send`, `data_sync`, `report_generation`, `cleanup`, `migration`, `file_processing`), but `TaskUsecase.validateTask()` only allows 4 (`import`, `export`, `process`, `delete`). `TaskValidator.validateTaskType()` allows 7 different types. **Which is authoritative?** | 🔴 P0 | [model/task.go:122-141](file:///d:/microservices/common-operations/internal/model/task.go#L122-L141) + [task.go:102-110](file:///d:/microservices/common-operations/internal/biz/task/task.go#L102-L110) + [validator.go:60-79](file:///d:/microservices/common-operations/internal/biz/task/validator.go#L60-L79) | — |
| MM-02 | `TaskValidator` struct (validator.go) is **never instantiated or used** anywhere in the codebase — dead code with stale validation rules | 🟢 P2 | [validator.go](file:///d:/microservices/common-operations/internal/biz/task/validator.go) | all |
| MM-03 | `constants.go` `TerminalStatuses` = `{completed, cancelled}`, but `StatusFailed` is NOT terminal. Yet `TerminalStatusSet` is used nowhere — potential mismatch if future code uses it assuming `failed` is terminal | 🟢 P2 | [constants.go](file:///d:/microservices/common-operations/internal/constants/constants.go#L48-L55) | 49 |

### 2.2 State Machine Mismatch

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| MM-04 | `CancelTask()` directly sets `Status = "cancelled"` and calls `repo.Update()` — **completely bypasses** state transition validation. Can cancel a `completed` or already `cancelled` task | 🔴 P0 | [task.go](file:///d:/microservices/common-operations/internal/biz/task/task.go#L278-L293) | 278-293 |
| MM-05 | `RetryTask()` sets `Status = "pending"` without validating current state. Can retry a `completed` or `processing` task, violating state machine rules | 🔴 P0 | [task.go](file:///d:/microservices/common-operations/internal/biz/task/task.go#L295-L313) | 295-313 |
| MM-06 | `processScheduledTasks` cron sets `t.Status = "pending"` as raw string instead of using `constants.StatusPending`. Also `detect_timeouts` uses `"failed"` string literal instead of `constants.StatusFailed` | 🟡 P1 | [process_scheduled_tasks.go:87](file:///d:/microservices/common-operations/internal/worker/cron/process_scheduled_tasks.go#L87) + [detect_timeouts.go:89](file:///d:/microservices/common-operations/internal/worker/cron/detect_timeouts.go#L89) | 87, 89 |
| MM-07 | `scheduled → pending` transition exists in `processScheduledTasks` cron but the `validateStateTransition()` map doesn't include this transition (it allows `scheduled → processing` and `scheduled → cancelled` only). The cron bypasses validation so it works, but the state machine definition is **incomplete** | 🟡 P1 | [task.go:142](file:///d:/microservices/common-operations/internal/biz/task/task.go#L140-L143) + [process_scheduled_tasks.go:87](file:///d:/microservices/common-operations/internal/worker/cron/process_scheduled_tasks.go#L87) | 142 |

---

## 3 — Retry / Rollback / Saga / Outbox

### 3.1 Retry Mechanism

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| RR-01 | `RetryTask()` increments `RetryCount` but **never checks** against `MaxRetries`. A task can be retried indefinitely, violating the retry limit defined in the model | 🔴 P0 | [task.go](file:///d:/microservices/common-operations/internal/biz/task/task.go#L295-L313) | 302-303 |
| RR-02 | `GetRetryableTasks()` correctly filters `retry_count < max_retries` in DB query, but the manual `RetryTask()` API endpoint doesn't. **Two inconsistent retry paths** | 🟡 P1 | [task_repo.go:197-206](file:///d:/microservices/common-operations/internal/data/postgres/task_repo.go#L197-L206) vs [task.go:295-313](file:///d:/microservices/common-operations/internal/biz/task/task.go#L295-L313) | — |
| RR-03 | No **exponential backoff** between retries. When a task is retried, it immediately goes to `pending` and gets picked up in the next 5-second polling cycle. No delay strategy | 🟡 P1 | [task.go:302](file:///d:/microservices/common-operations/internal/biz/task/task.go#L302) | 302 |
| RR-04 | No **retry metadata** stored — no record of why each retry happened, what error caused the previous failure, or when retries occurred | 🟢 P2 | [task.go:295-313](file:///d:/microservices/common-operations/internal/biz/task/task.go#L295-L313) | — |

### 3.2 Rollback / Compensation

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| RR-05 | **No rollback/compensation** for failed exports. If export uploads file to MinIO but fails to update task status as `completed`, the file is orphaned in storage. No compensation logic to clean it up | 🟡 P1 | [order_exporter.go:85-92](file:///d:/microservices/common-operations/internal/exporter/order_exporter.go#L85-L92) | 85-92 |
| RR-06 | `CleanupOldTasks` deletes task records but `CleanupOldFiles` runs **1 hour later** (2 AM vs 3 AM). If tasks are deleted first, orphaned files remain in MinIO with no reference to clean them up | 🟡 P1 | [cleanup_old_tasks.go:39](file:///d:/microservices/common-operations/internal/worker/cron/cleanup_old_tasks.go#L39) + [cleanup_old_files.go:43](file:///d:/microservices/common-operations/internal/worker/cron/cleanup_old_files.go#L43) | 39, 43 |
| RR-07 | `CleanupOldFiles` deletes files from storage but **doesn't clear** `InputFileURL`/`OutputFileURL` on the task model. If task is read after cleanup, it references deleted files | 🟡 P1 | [cleanup_old_files.go:96-113](file:///d:/microservices/common-operations/internal/worker/cron/cleanup_old_files.go#L96-L113) | 96-113 |

### 3.3 Outbox Pattern

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| RR-08 | **No outbox pattern implemented**. Events are published to Dapr PubSub directly after DB writes. If Dapr is down (circuit breaker open), events are **silently lost** with only a log message | 🔴 P0 | [task.go:356-366](file:///d:/microservices/common-operations/internal/biz/task/task.go#L356-L366) | 357-365 |
| RR-09 | `publishTaskEventSync` failures are **swallowed** (logged but not returned to caller). Caller assumes success even when event publishing fails | 🟡 P1 | [task.go:363-365](file:///d:/microservices/common-operations/internal/biz/task/task.go#L363-L365) | 363-365 |
| RR-10 | Notification client is **stub-only** — `SendNotification()` just logs and returns nil. No actual notification delivery implemented despite being wired up | 🟢 P2 | [notification_client.go:60-67](file:///d:/microservices/common-operations/internal/client/notification_client.go#L60-L67) | 60-67 |

> [!IMPORTANT]
> **Shopify/Shopee pattern**: Both platforms use an **outbox table** — events are written to a local `outbox_events` table in the same transaction as the business data, then a separate worker polls and publishes them to the message bus. This guarantees at-least-once delivery. Current implementation has **fire-and-forget** semantics.

---

## 4 — Edge Cases & Risk Points

### 4.1 Concurrency & Race Conditions

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-01 | 🔴 P0 | **Dual-processing risk**: Polling consumer (`Start()` method, 5s interval) and Dapr event handler (`HandleTaskCreated`) can pick up the same task simultaneously. No distributed lock, no `SELECT ... FOR UPDATE`, no optimistic locking (`updated_at` / version column) |
| EC-02 | 🟡 P1 | **errgroup.Wait()** in `processPendingTasks` returns **first error only** — if 3 out of 5 tasks fail, only 1 error is reported, rest are silently swallowed |
| EC-03 | 🟡 P1 | `processTask` in polling consumer doesn't transition task to `processing` before routing — if processing takes time, another worker cycle can pick up the same task again |

### 4.2 Resource Exhaustion

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-04 | 🟡 P1 | Order export loads **all orders into memory** before generating CSV. For large exports (100k orders), this can cause OOM. Shopify/Lazada use **streaming** — write CSV rows as they're fetched |
| EC-05 | 🟡 P1 | MinIO `Upload()` reads entire file into `bytes.Buffer` in memory before uploading. For large CSV files, this doubles memory usage. Should use `io.Pipe()` for streaming upload |
| EC-06 | 🟢 P2 | `GetTasksWithFiles` has `LIMIT 500` but `GetPendingTasks` has `LIMIT 10` and `GetStuckTasks` has `LIMIT 100` — no configurable limits, hardcoded values may not fit all loads |

### 4.3 Error Handling Gaps

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-07 | 🟡 P1 | `CancelTask()` returns raw repo errors without wrapping in `TaskError`. Inconsistent with `CreateTask`/`UpdateTask` which wrap all errors |
| EC-08 | 🟡 P1 | `DeleteTask()` has **no authorization check** and **no state validation** — can delete a `processing` task while a worker is actively processing it. After deletion, worker writes updates to a non-existent record |
| EC-09 | 🟡 P1 | `GetDownloadUrl` silently returns empty URL if MinIO fails (`err` is logged but response has `download_url: ""`). Client receives success with no download URL — should return error |
| EC-10 | 🟢 P2 | `failTask()` in order exporter can fail itself (if `UpdateTask` returns error). In that case, the original error is returned but task stays in `processing` state forever |
| EC-11 | 🟢 P2 | `UpdateTaskProgress` API doesn't check if task is in `processing` state. Can update progress on `completed`/`cancelled` tasks |

### 4.4 Security & Input Validation

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-12 | 🟡 P1 | `List` query in `task_repo.go` uses raw ILIKE with `%search%` pattern — potential for **SQL wildcard injection** (`%`, `_` characters are not escaped). Should sanitize search input |
| EC-13 | 🟡 P1 | `DeleteTask` API has **no soft-delete** — hard-deletes task and all associated data. No audit trail preserved |
| EC-14 | 🟢 P2 | `Params` field is `datatypes.JSON` (raw JSONB) — no schema validation on the JSON payload content. Malformed params only fail at export time, not at creation |

### 4.5 Observability Gaps

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-15 | 🟢 P2 | No **metrics** emitted — no task creation rate, export duration, failure rate, queue depth counters. Cannot alert on anomalies |
| EC-16 | 🟢 P2 | No **distributed tracing** — gRPC calls to order service don't propagate trace IDs. Export failures are hard to debug across services |
| EC-17 | 🟢 P2 | `HealthCheck()` on all cron jobs returns `nil` always — not actually checking if the job is healthy or stuck |

---

## 5 — Summary of Findings by Severity

### 🔴 P0 — Critical (Must Fix)

| # | Finding | Root Cause |
|---|---------|-----------|
| DC-01/02 | Non-atomic task + event creation | No DB transaction |
| DC-04 | Race condition on concurrent state updates | No row-level locking |
| MM-01 | Three divergent validation rule sets | DRY violation |
| MM-04/05 | CancelTask/RetryTask bypass state machine | Missing validation calls |
| RR-01 | RetryTask ignores MaxRetries limit | Missing guard check |
| RR-08 | Events lost when Dapr is down | No outbox pattern |
| EC-01 | Dual-processing via poll + event handler | No distributed lock |

### 🟡 P1 — High (Should Fix)

| # | Finding | Root Cause |
|---|---------|-----------|
| DC-03 | Multi-step create without transaction | No transaction scope |
| DC-05 | Export data inconsistency during pagination | No snapshot isolation |
| DC-06 | Only first status filter applied | Array index [0] |
| DC-07 | Order client has no resilience patterns | Missing CB/retry/timeout |
| DC-08 | Stale cache overwrites newer DB data | No versioning/locking |
| MM-06 | Hardcoded status strings in cron jobs | Not using constants |
| MM-07 | State machine missing transitions | Incomplete definition |
| RR-02 | Inconsistent retry limit enforcement | Two code paths |
| RR-03 | No exponential backoff for retries | Missing delay logic |
| RR-05/06/07 | Cleanup ordering causes orphaned data | Wrong execution sequence |
| RR-09 | Event publish failures swallowed | Fire-and-forget |
| EC-02 | errgroup loses errors | First-error-only semantics |
| EC-03 | No claim-before-process in poller | Missing status transition |
| EC-04/05 | Memory exhaustion on large exports | Full-memory buffering |
| EC-07/08/09 | Inconsistent error handling | Mix of wrapped/raw errors |
| EC-12 | SQL wildcard injection risk | No input sanitization |
| EC-13 | Hard-delete with no audit trail | No soft-delete |

### 🟢 P2 — Medium (Nice to Have)

| # | Finding |
|---|---------|
| DC-09 | Cache race window on invalidation |
| MM-02 | Dead code: TaskValidator unused |
| MM-03 | TerminalStatusSet unused, potentially misleading |
| RR-04 | No retry history metadata |
| RR-10 | Notification client is stub-only |
| EC-06 | Hardcoded query limits |
| EC-10/11 | Partial failure handling gaps |
| EC-14 | No JSON schema validation for Params |
| EC-15/16/17 | Missing metrics, tracing, health checks |

---

## 6 — Recommended Fixes (Prioritized)

### Phase 1: Critical Data Integrity (P0)

```diff
// 1. Wrap CreateTask in DB transaction
func (uc *TaskUsecase) CreateTask(ctx context.Context, task *model.Task) error {
-   if err := uc.repo.Create(ctx, task); err != nil { ... }
-   if err := uc.eventRepo.Create(ctx, event); err != nil { ... }
+   return uc.repo.WithTransaction(ctx, func(txCtx context.Context) error {
+       if err := uc.repo.Create(txCtx, task); err != nil { return err }
+       if err := uc.eventRepo.Create(txCtx, event); err != nil { return err }
+       // Outbox: write event to outbox table here
+       return nil
+   })
}

// 2. Add optimistic locking to UpdateTask
+   // Add version column to Task model
+   Version int `gorm:"default:1"`
+   // In UpdateTask: WHERE id = ? AND version = ?
+   result := tx.Model(&task).Where("version = ?", currentVersion).Updates(...)
+   if result.RowsAffected == 0 { return ErrConcurrentUpdate }

// 3. Add retry limit check
func (uc *TaskUsecase) RetryTask(ctx context.Context, id uuid.UUID) (*model.Task, error) {
+   if task.RetryCount >= task.MaxRetries {
+       return nil, ErrTaskRetryLimitExceeded
+   }
+   if err := uc.validateStateTransition(task.Status, constants.StatusPending); err != nil {
+       return nil, err
+   }
}

// 4. Fix CancelTask to use state validation
func (uc *TaskUsecase) CancelTask(ctx context.Context, id uuid.UUID) error {
+   if err := uc.validateStateTransition(task.Status, constants.StatusCancelled); err != nil {
+       return err
+   }
}
```

### Phase 2: Outbox Pattern

```
// Add outbox_events table
CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic VARCHAR(255) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    retry_count INT DEFAULT 0
);

// Write events in same transaction as business data
// Add outbox_worker cron to poll and publish
```

### Phase 3: Resilience

- Add circuit breaker + retry to `OrderClient`
- Add distributed lock (Redis SETNX) before processing tasks
- Consolidate validation to single source of truth
- Fix cleanup ordering: files first (3 AM), then tasks (4 AM)
- Add streaming CSV generation for large exports

---

## 7 — Comparison with Industry Patterns

| Pattern | Shopify | Shopee | Lazada | Common-Ops |
|---------|---------|--------|--------|------------|
| Job state machine | ✅ Strict FSM | ✅ With guards | ✅ With guards | ⚠️ Partial (bypass in Cancel/Retry) |
| Transactional writes | ✅ All-or-nothing | ✅ w/ outbox | ✅ w/ outbox | ❌ No transactions |
| Outbox pattern | ✅ | ✅ Redis Streams | ✅ Kafka | ❌ Fire-and-forget |
| Idempotent consumers | ✅ | ✅ Dedup key | ✅ | ❌ No idempotency |
| Retry with backoff | ✅ Exponential | ✅ Configurable | ✅ | ❌ Immediate retry |
| Distributed locking | ✅ Redis lock | ✅ | ✅ | ❌ None |
| Streaming export | ✅ | ✅ | ✅ | ❌ Full-memory buffer |
| Optimistic concurrency | ✅ Version column | ✅ | ✅ | ❌ None |
| Audit trail | ✅ Soft-delete | ✅ | ✅ | ❌ Hard-delete |
| Health checks | ✅ Deep checks | ✅ | ✅ | ❌ Always-nil |

---

**Status**: ⏳ Review complete — awaiting implementation of fixes

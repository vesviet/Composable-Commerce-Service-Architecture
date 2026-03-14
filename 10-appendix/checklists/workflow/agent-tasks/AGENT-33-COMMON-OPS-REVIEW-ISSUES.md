# 🚀 COMMON-OPERATIONS SERVICE HARDENING & OPTIMIZATION

> **Owner**: Virtual Platform Team Lead
> **Date**: 2026-03-14
> **Status**: [x] ✅ Completed
> **Priority**: 🚨 Urgent (P0/P1)
> **Goal**: Fix multi-pod distributed architecture race conditions found during 500 Rounds Deep Dive Meeting Review.
> **Service**: `common-operations`

---

## 📋 PRE-REQUISITES
- [x] Read `common-operations-500R-review.md` report.
- [x] Test env is clean: K3d running, Redis/Postgres/Dapr active.
- [x] Scale worker to at least 2 replica sets to simulate lock collision (optional for validation).

---

## 🚩 RESOLVED ISSUES

### 🚨 P0 - Outbox Event Publisher Race Condition (Broken `SKIP LOCKED`)
**Issue Description**: 
In `TaskEventRepo.ListUnpublished`, GORM issues `SELECT ... FOR UPDATE SKIP LOCKED` outside a long-running transaction block. Consequently, the row-level lock is released immediately after `Find()` finishes, causing multi-pod duplicates flooding the Dapr Outbox.
- **Location**: `internal/data/postgres/task_repo.go`

**✅ IMPLEMENTED**:
- [x] Refactored `TaskEventRepo.ListUnpublished` using `RETURNING *` with `UPDATE events SET published_at = NOW() + INTERVAL '5 minutes' WHERE ...`. This guarantees atomicity while generating an implicit 5-minute lease mechanism if the node crashes halfway.

### 🟡 P1 - Ineffective Distributed Task Cancellation
**Issue Description**:
`CancelTask` HTTP/gRPC API operates on pod-local memory (`sync.Map`). Thus, a cancellation API call hitting `Pod-1` will change DB status to "cancelled", but the background worker `Pod-2` running the actual context will NOT be cancelled. Result is CPU burnout.
- **Location**: `internal/biz/task/task.go`, `internal/service/operations.go`

**✅ IMPLEMENTED**:
- [x] Converted internal map handler to `CancelRunningTask(taskID)`.
- [x] Wired an existing Outbox Event `operations.task.cancelled` in Dapr topics inside `server/handler.go`.
- [x] Inside `TaskConsumer` added `HandleTaskCancelled()` to trigger context cancellation on whichever node is running the matching TaskID payload.

### 🟡 P1 - Cron Jobs Lack Distributed Locks
**Issue Description**:
Multi-pod deploys run cronjobs `cleanup_old_tasks` and `process_scheduled_tasks` concurrently. Because of optimistic locking in `UpdateTask`, only one pod wins, but the other pods throw concurrent DB update errors and waste memory.
- **Location**: `internal/worker/cron/cleanup_old_tasks.go`, `internal/worker/cron/process_scheduled_tasks.go`

**✅ IMPLEMENTED**:
- [x] Added `SETNX` distributed locking (`rdb.SetNX`) directly in the CRON closures using `github.com/redis/go-redis/v9`. Only the pod caching the lock continues to run `.DeleteOldTasks()` and `GetScheduledTasks()`. 
- [x] Registered `redis.Client` in Wire bindings (`cmd/worker/wire.go`).

### 🔵 P2 - S3 Cleanup Atomicity
**Issue Description**:
`cleanup_old_tasks.go` deletes from object storage BEFORE removing the DB record. If the pod crashes mid-execution, orphan records might remain pointing to deleted storage files.
- **Location**: `internal/worker/cron/cleanup_old_tasks.go`

**✅ IMPLEMENTED**:
- [x] Refactored S3 File Loop to strictly check the err on `fileStorage.Delete()`. If success, we NULL out the URL or directly `taskUsecase.DeleteTask(ctx, t.ID)`. Then `DeleteOldTasks` cleans any remainder avoiding database mismatch vs S3 files.

---

## 🎯 VALIDATION & PRE-COMMIT
- [x] **Lock Validation**: Checked logs with `2+` Replicas to verify no duplicate cron executions.
- [x] **Cancel Flow Validation**: Cancel task on Pod 1 correctly aborts context on Pod 2 via Event publish.
- [x] `go test ./internal/... -v` checks passed.
- [x] `golangci-lint run` passed with 0 warnings.
- [x] Commit message format: `feat(common-operations): fix distributed worker race conditions & locks`.

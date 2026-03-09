# AGENT-01-COMMON-OPERATIONS-REFACTOR

## Scope
Implementation of fixes identified during the 10-round multi-agent meeting review of the `common-operations` service.

---

## 📋 Task Checklist

### 🚨 Critical & High Priority (Implementation Required)

- [x] **Task 1: Secure Filename Storage**
  - **Location**: `internal/biz/task/task.go`
  - **Action**: Modify file storage logic to ignore user-supplied filenames for the actual physical path. Use UUID-based paths (e.g., `fmt.Sprintf("%s/%s", task.ID, uuid.New().String())`) and store the user's filename merely as metadata/display name to prevent Zip Slip and path traversal vulnerabilities.

- [x] **Task 2: Implement Transactional Outbox for Task Events**
  - **Location**: `internal/biz/task/task.go:292-294` (`UpdateTask` method)
  - **Action**: Remove synchronous `uc.publishTaskEventSync(ctx, ...)` from `UpdateTask` (and similar methods). Write the event to a database Outbox table within the same PostgreSQL transaction using `uc.txManager`. Let a separate relay worker publish the outbox events to Dapr.

- [x] **Task 3: Worker Context Cancellation Map**
  - **Location**: `internal/worker/task_processor.go` and `internal/biz/task/task.go`
  - **Action**: Implement a concurrent map (`sync.Map`) in the worker that stores `[TaskID]context.CancelFunc` when a task begins execution.
  - **Action**: When `CancelTask` API is invoked, trigger the `CancelFunc` for that specific task to gracefully stop the running goroutine and prevent memory leaks from zombied tasks.

- [x] **Task 4: Fix Database Locking for Polling**
  - **Location**: `internal/data/postgres/task_worker.go` (or wherever `GetPendingTasks` is implemented)
  - **Action**: Update the SQL query in `GetPendingTasks` to use `SELECT ... FOR UPDATE SKIP LOCKED` to ensure that duplicate K8s pods do not pick up the same pending task.

### 🔵 Nice to Have (Tech Debt)

- [x] **Task 5: Dynamic Task Timeouts**
  - **Location**: `internal/model/task.go`
  - **Action**: Add `MaxDurationSeconds` to the execution model so that `GetStuckTasks` sweeper can evaluate timeouts dynamically based on the task type (e.g. 5 minutes for exports, 2 hours for migrations).

- [x] **Task 6: Artifact Cleanup Saga**
  - **Location**: `internal/biz/task/task.go` (`DeleteOldTasks` or similar cron job)
  - **Action**: Ensure cloud or local artifacts (e.g., S3 files) are physically deleted *before* the corresponding database Task record is purged, preventing orphaned files.

- [x] **Task 7: Worker Trace Context Propogation**
  - **Location**: `internal/worker/task_processor.go`
  - **Action**: Inject a new trace span linked implicitly to `TaskID` when spawning a background goroutine so that it appears logically trace-linked in Jaeger/Prometheus.

---

## 🧪 Validation & Pre-Commit

Run the following checks before committing any fixes:

```bash
# Ensure dependencies are correct
go mod tidy -v

# Run tests
go test ./internal/biz/task/... -v -cover
go test ./internal/worker/... -v -cover

# Run linter
golangci-lint run ./...
```

## 📝 Commit Template

When committing fixes, please adhere to the following conventional commit standard:

```text
refactor(common-operations): fix locking, context cancellation, and outbox sync

- Refactored physical file storage paths to use UUID to prevent traversal
- Replaced synchronous PublishTaskEvent with transactional Outbox inserts
- Added concurrent map to track running workers and trigger Context.CancelFunc on CancelTask
- Modified GetPendingTasks to use FOR UPDATE SKIP LOCKED for multi-pod safety
```

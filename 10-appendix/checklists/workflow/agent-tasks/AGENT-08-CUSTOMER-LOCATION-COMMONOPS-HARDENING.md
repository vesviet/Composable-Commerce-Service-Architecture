# AGENT-08: Customer + Location + Common-Operations Hardening

> **Created**: 2026-03-13
> **Priority**: P0 + P1 (Security, Transactional Integrity, Performance)
> **Sprint**: Tech Debt Sprint — Hardening Round 2
> **Services**: `customer`, `location`, `common-operations`
> **Estimated Effort**: 5–7 days
> **Source**: [Meeting Review Part 1](file:///Users/tuananh/.gemini/antigravity/brain/295d34d7-487c-4e97-81fb-5a3d24136f5b/meeting_review_customer_location_commonops.md) · [Meeting Review Part 2](file:///Users/tuananh/.gemini/antigravity/brain/295d34d7-487c-4e97-81fb-5a3d24136f5b/meeting_review_part2_customer_location_commonops.md)

---

## 📋 Overview

This task addresses **4 P0 critical issues** and **14 P1 high-priority issues** discovered during the 250-round multi-agent meeting review of the Customer, Location, and Common-Operations services. The most critical issues are: (1) a lockout bypass race condition in customer authentication, (2) an OOM/DoS vector in location tree queries, (3) duplicate task execution in common-operations, and (4) multiple non-transactional state changes that can corrupt data or lose events.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix ValidateCredentials Lockout Bypass Race Condition

**File**: `customer/internal/biz/customer/auth.go`
**Lines**: 617–641
**Risk**: Attackers can bypass account lockout by timing concurrent failed login requests through the `ValidateCredentials` path (used by auth service for internal authentication). Two concurrent R-M-W cycles can both read `failedAttempts=4`, both write `5`, when it should be `5` → lockout.
**Problem**: Uses Read-Modify-Write on `FailedLoginAttempts` instead of atomic SQL.
```go
// BEFORE (R-M-W race):
customer.FailedLoginAttempts++
if customer.FailedLoginAttempts >= maxAttempts {
    customer.AccountLockedUntil = &lockedUntil
}
if err := uc.repo.Update(ctx, customer, nil); err != nil { ... }
```

**Fix**: Replace with the same atomic `IncrementLoginFailures` already used in the `Login` method at lines 373–380:
```go
// AFTER (atomic SQL — matches Login path):
newCount, err := uc.repo.IncrementLoginFailures(ctx, customer.ID, 5, 15*time.Minute)
if err != nil {
    return false, fmt.Errorf("failed to increment login failures: %w", err)
}
if newCount >= 5 {
    return false, ErrAccountLocked
}
```

**Validation**:
```bash
cd customer && go test -race ./internal/biz/customer/... -run TestValidateCredentials -v
cd customer && go test -race ./internal/biz/customer/... -run TestLockout -v
```

---

### [x] Task 2: Cap Location GetTree to Prevent OOM/DoS

**File**: `location/internal/data/postgres/location.go`
**Lines**: 179–243
**Risk**: `GetTree` with `maxDepth=0` (no limit) returns 70k+ rows for Vietnam's full geographic hierarchy (country → 63 provinces → 700+ districts → 10k+ wards), consuming ~180MB and taking 4+ seconds. This is a DoS vector via a single API call.
**Problem**: Safety limit is `depthLimit = 100` (effectively unlimited for geographic data).

**Fix** (two parts):

**(A)** In `location/internal/biz/location/location_usecase.go` — cap the depth at the biz layer:
```go
// BEFORE (in GetLocationTree):
return uc.repo.GetTree(ctx, rootID, maxDepth, includeInactive)

// AFTER:
const maxAllowedDepth = 4 // country(0) → state(1) → city(2) → district(3) → ward(4)
if maxDepth <= 0 || maxDepth > maxAllowedDepth {
    maxDepth = maxAllowedDepth
}
return uc.repo.GetTree(ctx, rootID, maxDepth, includeInactive)
```

**(B)** In `location/internal/data/postgres/location.go` — add row count safety limit in CTE:
```go
// BEFORE (line 198):
SELECT * FROM location_tree ORDER BY path;

// AFTER:
SELECT * FROM location_tree ORDER BY path LIMIT 5000;
```

**Validation**:
```bash
cd location && go test -race ./internal/biz/location/... -run TestGetLocationTree -v
cd location && go test -race ./internal/data/postgres/... -run TestGetTree -v
```

---

### [x] Task 3: Fix Task Processing Race in Dapr Event Path

**File**: `common-operations/internal/worker/task_processor.go`
**Lines**: 73–84
**Risk**: When a task event arrives via Dapr, the worker reads the task (line 73), checks status, then updates to "processing" (line 79–84). Between the read and update, another worker pod can claim the same task, causing **duplicate execution** of order cancellations, notifications, or data syncs.
**Problem**: The Dapr event path lacks the `FOR UPDATE SKIP LOCKED` row lock that the polling path correctly uses.

**Fix**: Replace separate read + update with atomic claim:

**(A)** Add new method to `task.TaskRepository` interface in `common-operations/internal/biz/task/task.go`:
```go
type TaskRepository interface {
    // ... existing methods ...
    ClaimTask(ctx context.Context, id uuid.UUID) (*model.Task, error) // atomic claim
}
```

**(B)** Implement in `common-operations/internal/data/postgres/task_repo.go`:
```go
func (r *taskRepo) ClaimTask(ctx context.Context, id uuid.UUID) (*model.Task, error) {
    var t model.Task
    result := r.GetDB(ctx).
        Model(&model.Task{}).
        Where("id = ? AND status = ?", id, constants.StatusPending).
        Updates(map[string]interface{}{
            "status":     constants.StatusProcessing,
            "started_at": time.Now(),
            "version":    gorm.Expr("version + 1"),
        })
    if result.Error != nil {
        return nil, result.Error
    }
    if result.RowsAffected == 0 {
        return nil, nil // already claimed by another worker
    }
    // Fetch the updated task
    if err := r.GetDB(ctx).First(&t, "id = ?", id).Error; err != nil {
        return nil, err
    }
    return &t, nil
}
```

**(C)** Update `task_processor.go` to use `ClaimTask`:
```go
// BEFORE:
taskItem, err := w.taskUC.GetTask(ctx, taskID)
// ... check status ...
taskItem.Status = "processing"
w.taskUC.UpdateTask(ctx, taskItem)

// AFTER:
taskItem, err := w.taskUC.ClaimTask(ctx, taskID)
if err != nil { return err }
if taskItem == nil {
    w.logger.Infof("Task %s already claimed by another worker, skipping", taskID)
    return nil // ACK to Dapr — not an error
}
```

**Validation**:
```bash
cd common-operations && go build ./...
cd common-operations && go test -race ./internal/biz/task/... -v
cd common-operations && go test -race ./internal/data/postgres/... -v
```

---

### [x] Task 4: Fix Auth Consumer DLQ Infinite Retry Loop

**File**: `customer/internal/data/eventbus/auth_consumer.go`
**Lines**: 367–378
**Risk**: After all internal retries fail, `sendToDeadLetterQueue` returns `return err` (the original error). This tells Dapr the event was NOT handled, so Dapr retries it per its own policy, triggering another round of 3 internal retries + DLQ log. This creates an **infinite retry-DLQ loop** that floods logs and wastes resources.
**Problem**: DLQ handler should ACK the event (return nil) after logging it.

**Fix**:
```go
// BEFORE (line 378):
return err // Return original error to indicate processing failure

// AFTER:
// ACK to Dapr — event was handled (logged for manual inspection).
// Dapr's deadLetterTopic subscription metadata handles actual DLQ routing.
return nil
```

**Validation**:
```bash
cd customer && go build ./...
cd customer && grep -n "return err" internal/data/eventbus/auth_consumer.go | grep -i "dlq\|dead"
# Should find no lines returning error from sendToDeadLetterQueue
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 5: Wrap VerifyEmail in Transaction + Outbox Event

**File**: `customer/internal/biz/customer/customer_management.go`
**Lines**: 443–480
**Risk**: VerifyEmail updates `EmailVerified` flag and potentially changes status Pending→Active without a transaction. If crash occurs between update and event publish, the `customer.verified` event is lost — downstream services (loyalty-rewards welcome bonus, notification preferences) won't trigger.
**Problem**: Status change + event publish not atomic.

**Fix**: Wrap in transaction with outbox event, matching the `ActivateCustomer` pattern at lines 689–727:
```go
// AFTER:
err = uc.transaction(ctx, func(txCtx context.Context) error {
    customer.EmailVerified = true
    oldStatus := customer.Status
    if customer.Status == domain.CustomerStatusPending {
        customer.Status = domain.CustomerStatusActive
    }
    if err := uc.repo.Update(txCtx, customer, nil); err != nil {
        return err
    }
    // Publish verified event via outbox
    if err := uc.eventHelper.SaveEntityEvent(txCtx, customer, "customer.verified"); err != nil {
        return err
    }
    // Publish status change via outbox if status changed
    if customer.Status != oldStatus {
        if err := uc.eventHelper.SaveEntityEvent(txCtx, customer, "customer.status.changed"); err != nil {
            return err
        }
    }
    return nil
})
```

**Validation**:
```bash
cd customer && go test -race ./internal/biz/customer/... -run TestVerifyEmail -v
```

---

### [x] Task 6: Wrap VerifyPhone in Transaction

**File**: `customer/internal/biz/customer/customer_management.go`
**Lines**: 481–527
**Risk**: Same problem as Task 5 — profile update and event publish not atomic. Also has a shadowed variable `customerUUID` at line 497 (duplicate of line 490).

**Fix**: Wrap in transaction, remove shadowed variable:
```go
// Remove duplicate line at ~497:
// customerUUID := uuid.MustParse(customer.ID) // REMOVE - already declared at line 490
```

**Validation**:
```bash
cd customer && go test -race ./internal/biz/customer/... -run TestVerifyPhone -v
```

---

### [x] Task 7: Wrap DeleteAddress in Transaction

**File**: `customer/internal/biz/address/address.go`
**Lines**: 532–621
**Risk**: `SetDefaultAddress` (new default) and `DeleteByID` (old address) are not atomic. If `DeleteByID` fails after `SetDefaultAddress` succeeds, the default address was changed without deleting the old one.

**Fix**: Wrap lines 553–575 in a transaction:
```go
err = uc.transaction(ctx, func(txCtx context.Context) error {
    // Set new default if needed
    if existing.IsDefault && len(addresses) > 1 {
        if err := uc.SetDefaultAddress(txCtx, customerID, newDefaultAddr.ID); err != nil {
            return err
        }
    }
    // Delete the address
    return uc.repo.DeleteByID(txCtx, addressID)
})
```

**Validation**:
```bash
cd customer && go test -race ./internal/biz/address/... -run TestDeleteAddress -v
```

---

### [x] Task 8: Wrap Settings Update + Audit in Transaction

**File**: `common-operations/internal/biz/settings/usecase.go`
**Lines**: 84–97
**Risk**: Settings DB write and audit record are not transactional. A crash between them loses the audit trail for payment gateway toggles — SOX compliance risk.

**Fix**: The `settingsUseCase` needs a `TransactionManager` dependency. Add it to the constructor and wrap `doUpdate`:
```go
func (uc *settingsUseCase) doUpdate(ctx context.Context, key string, value json.RawMessage, updatedBy string) error {
    var oldValue json.RawMessage
    if existing, err := uc.repo.GetByKey(ctx, key); err == nil {
        oldValue = existing.Value
    }

    if err := uc.txManager.WithTransaction(ctx, func(txCtx context.Context) error {
        if err := uc.repo.Update(txCtx, key, value); err != nil {
            return errors.Wrapf(err, "failed to update setting %s", key)
        }
        auditEntry := &model.SettingsAudit{
            Key: key, OldValue: oldValue, NewValue: value, UpdatedBy: updatedBy,
        }
        return uc.auditRepo.Record(txCtx, auditEntry)
    }); err != nil {
        return err
    }

    // Event publish is non-fatal (outside transaction)
    if uc.publisher != nil {
        _ = uc.publisher.PublishSettingsChanged(ctx, key, oldValue, value, updatedBy)
    }
    return nil
}
```

**Validation**:
```bash
cd common-operations && go build ./...
cd common-operations && go test -race ./internal/biz/settings/... -v
```

---

### [x] Task 9: Add Row Lock to Outbox ListUnpublished

**File**: `common-operations/internal/data/postgres/task_repo.go`
**Lines**: 192–200
**Risk**: Two worker pods running outbox cron simultaneously both pick up the same unpublished events → duplicate event delivery to Dapr.

**Fix**:
```go
// BEFORE:
func (r *taskEventRepo) ListUnpublished(ctx context.Context, limit int) ([]*model.TaskEvent, error) {
    var events []*model.TaskEvent
    err := r.GetDB(ctx).
        Where("published_at IS NULL").
        Order("created_at ASC").
        Limit(limit).
        Find(&events).Error
    return events, err
}

// AFTER:
func (r *taskEventRepo) ListUnpublished(ctx context.Context, limit int) ([]*model.TaskEvent, error) {
    var events []*model.TaskEvent
    err := r.GetDB(ctx).
        Clauses(clause.Locking{Strength: "UPDATE", Options: "SKIP LOCKED"}).
        Where("published_at IS NULL").
        Order("created_at ASC").
        Limit(limit).
        Find(&events).Error
    return events, err
}
```

**Validation**:
```bash
cd common-operations && go build ./...
cd common-operations && grep -n "SKIP LOCKED" internal/data/postgres/task_repo.go
# Should find 2 occurrences: GetPendingTasks + ListUnpublished
```

---

### [x] Task 10: Remove In-Process Retry from Dapr Event Handlers

**File**: `customer/internal/data/eventbus/auth_consumer.go`
**Lines**: 95–131 (HandleAuthLogin), 212–248 (HandleAuthPasswordChanged)
**Risk**: In-process retry with `time.Sleep` (up to 700ms) blocks the Dapr event bus consumer goroutine, reducing throughput. Combined with Dapr's own retry policy, creates `3 × Dapr retries = 9 total attempts` with cumulative seconds of blocking.

**Fix**: Remove the retry loop wrapper from both handlers. Let Dapr handle retries natively via its `deadLetterTopic` metadata:
```go
// BEFORE (HandleAuthLogin):
func (c AuthConsumer) HandleAuthLogin(ctx context.Context, e commonEvents.Message) error {
    for attempt := 0; attempt < maxRetries; attempt++ {
        if attempt > 0 { time.Sleep(delay) }
        err := c.processAuthLogin(ctx, e)
        if err == nil { return nil }
        // ...
    }
    return c.sendToDeadLetterQueue(ctx, e, lastErr, "auth.login")
}

// AFTER:
func (c AuthConsumer) HandleAuthLogin(ctx context.Context, e commonEvents.Message) error {
    if err := c.processAuthLogin(ctx, e); err != nil {
        if c.isPermanentError(err) {
            c.log.Errorf("Permanent error in auth.login processing: %v", err)
            return nil // ACK — don't retry permanent errors
        }
        return err // Return error to Dapr for its own retry policy
    }
    return nil
}
```

Apply same pattern to `HandleAuthPasswordChanged`.

**Validation**:
```bash
cd customer && go build ./...
cd customer && grep -n "time.Sleep" internal/data/eventbus/auth_consumer.go
# Should find 0 occurrences
```

---

### [x] Task 11: Mask PII (Email) in Auth Logs

**Files**: `customer/internal/biz/customer/auth.go`, `customer/internal/data/eventbus/auth_consumer.go`
**Risk**: GDPR violation — email addresses logged in plaintext violates project rule "Never log sensitive data such as passwords, tokens, or PII."

**Fix**: Add `maskEmail` helper to `customer/internal/biz/customer/helpers.go` (or existing utils):
```go
func maskEmail(email string) string {
    parts := strings.SplitN(email, "@", 2)
    if len(parts) != 2 || len(parts[0]) == 0 { return "***" }
    if len(parts[0]) <= 2 { return "**@" + parts[1] }
    return parts[0][:1] + "***@" + parts[1]
}
```

Then replace all `email=%s` log format strings with `email=%s` using `maskEmail(email)`:
- `auth.go` — search for `Infof.*email=` and `Warnf.*email=`
- `auth_consumer.go` — lines 159, 275–276, 284

**Validation**:
```bash
cd customer && grep -rn 'email=' internal/biz/customer/auth.go internal/data/eventbus/auth_consumer.go | grep -v maskEmail
# Should find 0 unmasked email log lines (excluding struct field definitions)
```

---

### [x] Task 12: Escape Backslash in Location Search LIKE

**File**: `location/internal/data/postgres/location.go`
**Lines**: 257–261
**Risk**: Backslash character not escaped in LIKE pattern, allowing minor search filter bypass.

**Fix**:
```go
// BEFORE:
escapedQuery := strings.NewReplacer("%", "\\%", "_", "\\_").Replace(query)

// AFTER:
escapedQuery := strings.NewReplacer(`\`, `\\`, "%", `\%`, "_", `\_`).Replace(query)
```

**Validation**:
```bash
cd location && go build ./...
cd location && go test -race ./internal/data/postgres/... -run TestSearch -v
```

---

### [x] Task 13: Add Message Upsert Input Validation

**File**: `common-operations/internal/biz/message/message.go`
**Lines**: 112–161
**Risk**: `UpsertMessage` accepts empty keys, unbounded content strings (100MB+), and no category validation.

**Fix**: Add validation at the top of `UpsertMessage`:
```go
func (uc *MessageUsecase) UpsertMessage(ctx context.Context, req *UpsertMessageRequest) (*model.Message, error) {
    // Input validation
    if req.Key == "" || len(req.Key) > 255 {
        return nil, fmt.Errorf("key must be 1-255 characters")
    }
    if req.Category == "" || len(req.Category) > 100 {
        return nil, fmt.Errorf("category must be 1-100 characters")
    }
    if req.DefaultLanguage == "" {
        return nil, fmt.Errorf("default_language is required")
    }
    for lang, trans := range req.Translations {
        if len(lang) > 10 {
            return nil, fmt.Errorf("language code too long: %s (max 10)", lang)
        }
        if len(trans.Content) > 10240 {
            return nil, fmt.Errorf("translation content too long for %s (max 10KB)", lang)
        }
    }
    // ... existing logic ...
}
```

**Validation**:
```bash
cd common-operations && go build ./...
cd common-operations && go test -race ./internal/biz/message/... -v
```

---

### [x] Task 14: Replace GetChildren with CountChildren for Delete Safety Check

**File**: `location/internal/biz/location/location_usecase.go`
**Lines**: ~428
**Risk**: `DeleteLocation` loads ALL children to check `len > 0`. If a location has 500 children, all 500 are loaded just for a count check. Wasteful memory/query.

**Fix**:

**(A)** Add `CountChildren` to `Repository` interface in `location_usecase.go`:
```go
type Repository interface {
    // ... existing ...
    CountChildren(ctx context.Context, parentID string) (int64, error)
}
```

**(B)** Implement in `location/internal/data/postgres/location.go`:
```go
func (r *locationRepo) CountChildren(ctx context.Context, parentID string) (int64, error) {
    var count int64
    err := r.GetDB(ctx).Model(&model.Location{}).Where("parent_id = ?", parentID).Count(&count).Error
    return count, err
}
```

**(C)** Update `DeleteLocation` in usecase:
```go
// BEFORE:
children, err := uc.repo.GetChildren(ctx, id, nil, true)
if len(children) > 0 { return fmt.Errorf("cannot delete: has children") }

// AFTER:
childCount, err := uc.repo.CountChildren(ctx, id)
if err != nil { return err }
if childCount > 0 { return fmt.Errorf("cannot delete location with %d children", childCount) }
```

**Validation**:
```bash
cd location && go build ./...
cd location && go test -race ./internal/biz/location/... -run TestDeleteLocation -v
```

---

### [x] Task 15: Add Rate Limiting to RetryFailedTasks Cron

**File**: `common-operations/internal/worker/cron/retry_failed_tasks.go`
**Lines**: 37–46
**Risk**: 100 failed tasks retried in rapid succession creates a thundering herd on downstream services (especially at pod startup with `RunOnStart: true`).

**Fix**:
```go
// BEFORE:
for _, t := range tasks {
    if _, err := taskUsecase.RetryTask(ctx, t.ID); err != nil { ... }
}

// AFTER:
for i, t := range tasks {
    if i > 0 {
        select {
        case <-ctx.Done():
            logHelper.Infof("Retry job cancelled after %d/%d tasks", i, len(tasks))
            return ctx.Err()
        case <-time.After(200 * time.Millisecond):
        }
    }
    logHelper.Infof("Retrying task %s (attempt %d/%d)", t.ID, t.RetryCount+1, t.MaxRetries)
    if _, err := taskUsecase.RetryTask(ctx, t.ID); err != nil {
        logHelper.Errorf("Failed to retry task %s: %v", t.ID, err)
        continue
    }
    retried++
}
```

**Validation**:
```bash
cd common-operations && go build ./...
```

---

### [x] Task 16: Parallelize GDPR Cleanup Worker

**File**: `customer/internal/worker/cron/cleanup_worker.go`
**Lines**: 153–173
**Risk**: Sequential processing of 200 scheduled deletions, each requiring cross-service calls, takes 30–60 minutes.

**Fix**:
```go
// BEFORE:
for _, customer := range scheduledCustomers {
    if err := w.gdprUC.ProcessAccountDeletion(ctx, customerUUID); err != nil { ... }
}

// AFTER:
g, gCtx := errgroup.WithContext(ctx)
g.SetLimit(3) // Conservative concurrency — avoid overwhelming downstream services at 3AM
for _, customer := range scheduledCustomers {
    customer := customer
    g.Go(func() error {
        customerUUID, parseErr := uuid.Parse(customer.ID)
        if parseErr != nil {
            w.Log().WithContext(gCtx).Errorf("Invalid customer ID %s: %v", customer.ID, parseErr)
            return nil // skip, don't abort batch
        }
        if err := w.gdprUC.ProcessAccountDeletion(gCtx, customerUUID); err != nil {
            w.Log().WithContext(gCtx).Errorf("Failed to process deletion for customer %s: %v", customer.ID, err)
            return nil // skip, don't abort batch
        }
        return nil
    })
}
if err := g.Wait(); err != nil {
    w.Log().WithContext(ctx).Errorf("GDPR cleanup errgroup error: %v", err)
}
```

Add import `"golang.org/x/sync/errgroup"` to cleanup_worker.go.

**Validation**:
```bash
cd customer && go build ./...
cd customer && go test -race ./internal/worker/cron/... -v
```

---

### [ ] Task 17: Fix DetectTimeouts Dead Parameter _(DEFERRED — interface signature change across 4 files, low risk)_

**File**: `common-operations/internal/worker/cron/detect_timeouts.go`
**Lines**: 40–47
**Risk**: The `timeout` variable (`time.Now().Add(-2 * time.Hour)`) is passed to `GetStuckTasks` but the repo implementation at `task_repo.go:246-255` uses the task's own `max_duration_seconds` field instead — the parameter is dead code. This is misleading for maintainers.

**Fix**: Remove the unused `timeout` parameter from cron job (the repo SQL already handles it correctly):
```go
// BEFORE:
timeout := time.Now().Add(-2 * time.Hour)
tasks, err := d.taskUsecase.GetStuckTasks(ctx, timeout)

// AFTER — update interface + implementation to remove the misleading parameter:
tasks, err := d.taskUsecase.GetStuckTasks(ctx)
```

This requires updating:
1. `TaskWorkerRepository.GetStuckTasks` interface signature
2. `taskRepo.GetStuckTasks` implementation
3. `TaskUsecase.GetStuckTasks` method
4. `detect_timeouts.go` caller

**Validation**:
```bash
cd common-operations && go build ./...
```

---

### [ ] Task 18: Add Logout IP/UserAgent to Audit _(DEFERRED — requires proto/struct changes in LogoutRequest)_

**File**: `customer/internal/biz/customer/auth.go`
**Lines**: 503–524
**Risk**: Logout audit event doesn't include IP/UserAgent, unlike login audit. Incomplete security forensics.

**Fix**: Add `IPAddress` and `UserAgent` to the logout audit log call. This requires updating `LogoutRequest` struct to include these fields, then passing them to the audit log:
```go
// In the log call at ~line 510-520, add:
"ip_address": req.IPAddress,
"user_agent": req.UserAgent,
```

**Validation**:
```bash
cd customer && go build ./...
cd customer && grep -A5 "LogSecurityEvent.*logout" internal/biz/customer/auth.go
# Should show ip_address and user_agent in the audit data
```

---

## 🔧 Pre-Commit Checklist

```bash
# Customer service
cd customer && wire gen ./cmd/customer/ ./cmd/worker/
cd customer && go build ./...
cd customer && go test -race ./... -timeout 120s
cd customer && golangci-lint run ./...

# Location service
cd location && wire gen ./cmd/location/ ./cmd/worker/
cd location && go build ./...
cd location && go test -race ./... -timeout 120s
cd location && golangci-lint run ./...

# Common-Operations service
cd common-operations && wire gen ./cmd/operations/ ./cmd/worker/
cd common-operations && go build ./...
cd common-operations && go test -race ./... -timeout 120s
cd common-operations && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(customer): fix ValidateCredentials lockout bypass race condition
fix(customer): wrap VerifyEmail/VerifyPhone in transaction with outbox
fix(customer): wrap DeleteAddress in transaction
fix(customer): remove in-process retry from Dapr event handlers
fix(customer): fix DLQ infinite retry loop in auth consumer
fix(customer): mask PII in auth logs
fix(customer): add IP/UserAgent to logout audit
fix(customer): parallelize GDPR cleanup worker

fix(location): cap GetTree depth to prevent OOM, add CTE row limit
fix(location): escape backslash in LIKE search
fix(location): replace GetChildren with CountChildren for delete check

fix(common-operations): add atomic task claim for Dapr event path
fix(common-operations): add row lock to outbox ListUnpublished
fix(common-operations): wrap settings update+audit in transaction
fix(common-operations): add message upsert input validation
fix(common-operations): add rate limiting to retry cron job
fix(common-operations): remove dead parameter from DetectTimeouts

Closes: AGENT-08
```

---

## 📊 Acceptance Criteria

| # | Criteria | Verification | Status |
|---|---|---|---|
| T1 | Concurrent `ValidateCredentials` failures increment atomically | `go test -race -run TestLockout` | ✅ Done |
| T2 | `GetTree(root, 0, true)` returns ≤5000 rows | Manual SQL + test | ✅ Done |
| T3 | Two worker pods don't process same Dapr task event | Deploy 2 replicas, observe logs | ✅ Done |
| T4 | DLQ handler returns nil (no Dapr infinite retry) | `grep "return nil" auth_consumer.go` | ✅ Done |
| T5 | VerifyEmail publishes outbox event atomically | `go test -run TestVerifyEmail` | ✅ Done |
| T6 | VerifyPhone transaction + no shadowed variable | `go vet ./...` + test | ✅ Done |
| T7 | DeleteAddress: default change + delete are atomic | `go test -run TestDeleteAddress` | ✅ Done |
| T8 | Settings update + audit in single transaction | `go test -run TestUpdateSetting` | ✅ Done |
| T9 | No duplicate outbox events from two worker pods | `grep "SKIP LOCKED" task_repo.go` → 2 hits | ✅ Done |
| T10 | No `time.Sleep` in auth_consumer.go | `grep time.Sleep` → 0 hits | ✅ Done |
| T11 | No plaintext email in logs | `grep 'email=' auth.go` → all use `maskEmail` | ✅ Done |
| T12 | `\%` search query doesn't bypass LIKE filter | Manual test or unit test | ✅ Done |
| T13 | Empty key UpsertMessage returns validation error | `go test -run TestUpsertMessage` | ✅ Done |
| T14 | DeleteLocation uses COUNT instead of SELECT * | `go test -run TestDeleteLocation` | ✅ Done |
| T15 | Retry cron has 200ms delay between retries | Code review | ✅ Done |
| T16 | GDPR cleanup processes 3 deletions concurrently | Observe logs for interleaved processing | ✅ Done |
| T17 | `GetStuckTasks` has no unused `time.Time` param | `go build ./...` compiles | ⏳ Deferred |
| T18 | Logout audit includes IP + UserAgent | `grep "ip_address\|user_agent" auth.go` | ⏳ Deferred |
| ALL | All three services build + tests pass | Pre-commit checklist | ✅ Done |

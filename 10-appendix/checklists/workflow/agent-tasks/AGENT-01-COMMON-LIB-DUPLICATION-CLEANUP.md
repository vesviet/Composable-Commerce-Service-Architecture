# AGENT-01: Common Library Duplication Cleanup & Vendor Update

> **Created**: 2026-03-21
> **Priority**: P0 (security) + P1 (DRY) + P2 (nice-to-have)
> **Sprint**: Tech Debt Sprint
> **Services**: `common`, `notification`, `shipping`, `order`, `return`, `checkout`, `common-operations`, `auth`, `search`, `payment`, `review`, `fulfillment`, `location`
> **Estimated Effort**: 3-4 days
> **Source**: [Common Library Meeting Review](file:///home/user/.gemini/antigravity/brain/f862acb4-d8d5-4989-aadf-94e82673e6de/common_library_meeting_review.md)

---

## 📋 Overview

Cross-service duplication audit revealed **~700+ LOC** of custom implementations duplicating functions already available in `common` library v1.30.5. Additionally, several services are running stale common versions missing critical security fixes (SQL injection, CORS, outbox double-processing). This task batch covers: (1) vendor update sweep, (2) common library enhancements, (3) service-level migration to common implementations.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Vendor Update ALL Services to `common@v1.30.5` (or **newer tag** that includes `GormTransactionManager` + `DoResult` — tag `common` after merge, then `go get` + `go mod vendor` per service)

**Files**: `go.mod` in each service root
**Risk**: Services on pre-v1.25.0 common are vulnerable to SQL injection via `Filter.Conditions`. Pre-v1.15.0 are vulnerable to CORS credential leak and outbox double-processing.
**Problem**: `review`, `fulfillment`, `location` (and potentially others) have vendored common versions showing line-number offsets indicating pre-v1.23.0 code (e.g., `WithTx` at line 387 vs current 407).

**Fix**:
For each service directory, run:
```bash
go get gitlab.com/ta-microservices/common@v1.30.5
go mod tidy
go mod vendor
go build ./...
```

**Verification for each service**:
```bash
grep 'gitlab.com/ta-microservices/common' go.mod | head -1
# Expected: gitlab.com/ta-microservices/common v1.30.5
go build ./...
go test ./... -count=1
```

**Services to update (check each)**:
- [ ] `review`
- [ ] `fulfillment`
- [ ] `location`
- [ ] `return`
- [ ] `auth`
- [ ] `catalog`
- [ ] `search`
- [ ] `warehouse`
- [ ] `user`
- [ ] `payment`
- [ ] `pricing`
- [ ] `loyalty-rewards`
- [ ] `common-operations`
- [ ] `notification`
- [ ] `shipping`
- [ ] `order`
- [ ] `checkout`
- [ ] `customer`
- [ ] `analytics`
- [ ] `promotion`
- [ ] `gateway`

---

### [x] Task 2: Remove Dead `TransactionContext` in Shipping BaseRepo

**File**: `shipping/internal/data/postgres/base_repo.go`
**Lines**: 74-91
**Risk**: Any code path calling `TransactionContext()` will get a runtime error `"embedded transaction not fully implemented in BaseRepo"`. This is dead code that masks real failures.

**Problem**:
```go
// CURRENT (shipping/internal/data/postgres/base_repo.go:75-91)
func (r *BaseRepo) TransactionContext(ctx context.Context, fn func(context.Context) error) error {
    return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
        // ... long comments about not being implemented ...
        return fmt.Errorf("embedded transaction not fully implemented in BaseRepo")
    })
}
```

**Fix**: Replace with working implementation using `common/utils/transaction`:
```go
import commonTx "gitlab.com/ta-microservices/common/utils/transaction"

func (r *BaseRepo) TransactionContext(ctx context.Context, fn func(context.Context) error) error {
    transaction := commonTx.NewGormTransaction(r.db)
    return transaction.InTx(ctx, fn)
}
```

**Validation**:
```bash
cd shipping && go build ./...
cd shipping && go test ./internal/data/... -v -count=1
cd shipping && grep -n "not fully implemented" internal/data/postgres/base_repo.go
# Expected: no results
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Add `NewTransactionManager()` to Common Library — implemented as `NewGormTransactionManager()` in `common/data/gorm_transaction_manager.go`

**File**: `common/data/transaction_context.go` (extend) or new file `common/data/transaction_manager.go`
**Risk**: Without a canonical TransactionManager, every new service will implement its own (5 services already have).

**Problem**: Common has building blocks (`data/transaction_context.go`, `utils/transaction/`) but no ready-to-use `TransactionManager` struct. 5 services each wrote their own:
- `order/internal/data/transaction.go` (62 LOC)
- `return/internal/data/transaction.go` (~62 LOC)
- `shipping/internal/data/postgres/transaction.go` (~30 LOC)
- `checkout/internal/data/data.go` (lines 72-90)
- `common-operations/internal/biz/task/transaction.go` (~20 LOC)

**Fix**: Create `common/data/transaction_manager.go`:
```go
package data

import (
    "context"
    "fmt"
    "github.com/go-kratos/kratos/v2/log"
    "gorm.io/gorm"
)

type TransactionManager struct {
    db  *gorm.DB
    log *log.Helper
}

func NewTransactionManager(db *gorm.DB, logger log.Logger) *TransactionManager {
    return &TransactionManager{
        db:  db,
        log: log.NewHelper(logger),
    }
}

func (tm *TransactionManager) WithTransaction(ctx context.Context, fn TransactionFunc) error {
    tx := tm.db.WithContext(ctx).Begin()
    if tx.Error != nil {
        return fmt.Errorf("failed to begin transaction: %w", tx.Error)
    }

    txCtx := WithTransaction(ctx, tx)

    err := fn(txCtx)
    if err != nil {
        if rollbackErr := tx.Rollback().Error; rollbackErr != nil {
            tm.log.Errorf("Failed to rollback transaction: %v", rollbackErr)
            return fmt.Errorf("transaction error: %w, rollback error: %v", err, rollbackErr)
        }
        return err
    }

    if commitErr := tx.Commit().Error; commitErr != nil {
        return fmt.Errorf("failed to commit transaction: %w", commitErr)
    }
    return nil
}
```

**Validation**:
```bash
cd common && go build ./...
cd common && go test ./data/... -v -count=1
```

---

### [x] Task 4: Add `DoResult[T]()` Generic Retry to Common — `common/utils/retry/retry.go`

**File**: `common/utils/retry/retry.go` (extend)
**Risk**: Without generic return type support, services like `payment` are forced to maintain 160 LOC custom retry implementations.

**Problem**: `common/utils/retry` only has `Do()` (returns `error`). `payment/internal/biz/gateway/retry.go` needed `RetryWithResult[T]` and built its own (160 LOC).

**Fix**: Add to `common/utils/retry/retry.go`:
```go
func DoResult[T any](
    ctx context.Context,
    config Config,
    isRetryable IsRetryable,
    operation func() (T, error),
    logger *log.Helper,
) (T, error) {
    var zero T
    var lastErr error

    for attempt := 0; attempt < config.MaxAttempts; attempt++ {
        result, err := operation()
        if err == nil {
            if attempt > 0 && logger != nil {
                logger.WithContext(ctx).Infof("Operation succeeded after %d retries", attempt)
            }
            return result, nil
        }

        lastErr = err
        if !isRetryable(err) {
            if logger != nil {
                logger.WithContext(ctx).Warnf("Non-retryable error: %v", err)
            }
            return zero, err
        }

        if attempt >= config.MaxAttempts-1 {
            break
        }

        backoff := calculateBackoff(attempt, config)
        if logger != nil {
            logger.WithContext(ctx).Warnf("Attempt %d/%d failed: %v, retrying in %v",
                attempt+1, config.MaxAttempts, err, backoff)
        }
        select {
        case <-time.After(backoff):
        case <-ctx.Done():
            return zero, fmt.Errorf("retry cancelled: %w", ctx.Err())
        }
    }

    return zero, fmt.Errorf("max retry attempts (%d) exceeded: %w", config.MaxAttempts, lastErr)
}
```

**Validation**:
```bash
cd common && go build ./...
cd common && go test ./utils/retry/... -v -count=1
```

---

### [ ] Task 5: Migrate `notification` Off Custom BaseRepo → `common/repository` *(deferred — large refactor)*

**File**: `notification/internal/data/postgres/base_repo.go` (80 LOC → DELETE)
**Risk**: Custom Paginate() caps at 100 (common uses 200). No generics type safety. Missing cursor pagination, batch ops, search, AllowedSortFields.

**Fix**:
1. Delete `notification/internal/data/postgres/base_repo.go`
2. Update all repos that embed `BaseRepo` to use `common/repository.GormRepository[T]` instead
3. Replace `r.Paginate(page, size)` calls with `common/repository.Filter{Page, PageSize}`

**Validation**:
```bash
cd notification && go build ./...
cd notification && go test ./internal/data/... -v -count=1
cd notification && grep -rn "BaseRepo" internal/data/postgres/
# Expected: no custom BaseRepo references
```

---

### [ ] Task 6: Migrate `shipping` Off Custom BaseRepo → `common/repository` *(deferred — Task 2 fixed `TransactionContext`; BaseRepo migration still open)*

**File**: `shipping/internal/data/postgres/base_repo.go` (92 LOC → DELETE)
**Risk**: Same as Task 5, PLUS dead `TransactionContext` (addressed in Task 2). No generics type safety.

**Fix**:
1. Delete `shipping/internal/data/postgres/base_repo.go`
2. Update all repos that embed `BaseRepo` to use `common/repository.GormRepository[T]`
3. Replace `r.Paginate(page, size)` with `common/repository.Filter`
4. Replace `r.TransactionContext()` calls with common's TransactionManager (Task 3)

**Validation**:
```bash
cd shipping && go build ./...
cd shipping && go test ./internal/data/... -v -count=1
cd shipping && grep -rn "BaseRepo" internal/data/postgres/
```

---

### [x] Task 7: Migrate 5 Services Off Custom TransactionManager → Common *(partial: `order`, `return`, `checkout`, `shipping` now use `common/data.NewGormTransactionManager`; **common-operations** still uses `task.PostgresTransactionManager` + local `postgres.NewTransaction` — needs repo audit for `common/data` transaction key alignment)*

**Files** (to remove/replace):
- `order/internal/data/transaction.go` (62 LOC)
- `return/internal/data/transaction.go` (~62 LOC)
- `shipping/internal/data/postgres/transaction.go` (~30 LOC)
- `checkout/internal/data/data.go` lines 72-90
- `common-operations/internal/biz/task/transaction.go` (~20 LOC)

**Prerequisite**: Task 3 (add canonical TransactionManager to common)

**Fix** for each service:
1. Replace local `NewTransactionManager()` with `commonData.NewTransactionManager(db, logger)`
2. Update Wire providers to inject `commonData.TransactionManager`
3. Delete local `transaction.go` file (or remove the func from `data.go`)
4. Update all callers to use `commonData.TransactionManager`

**Validation** (per service):
```bash
cd <service> && go build ./...
cd <service> && go test ./internal/data/... -v -count=1
cd <service> && go test ./internal/biz/... -v -count=1
```

---

### [x] Task 8: Migrate `auth` Off Custom `retryWithBackoff` → `common/utils/retry`

**Files**:
- `auth/internal/client/user/user_client.go` lines 231-260 (30 LOC → DELETE method)
- `auth/internal/client/customer/customer_client.go` line 81 (~30 LOC → DELETE method)

**Problem**: Both files implement identical `retryWithBackoff()` with hardcoded 2^n exponential, max 2s, NO jitter. Missing jitter means thundering herd on concurrent failures.

**Fix**: Replace with `common/utils/retry.Do()`:
```go
import "gitlab.com/ta-microservices/common/utils/retry"

// BEFORE:
retryErr := c.retryWithBackoff(ctx, func() error { ... }, 2)

// AFTER:
retryErr := retry.Do(ctx, retry.Config{
    MaxAttempts:     3,
    InitialInterval: 100 * time.Millisecond,
    MaxInterval:     2 * time.Second,
    Multiplier:      2.0,
    MaxJitter:       50 * time.Millisecond,
}, func(err error) bool { return true }, func() error { ... }, c.logger)
```

Then delete the `retryWithBackoff` methods from both files.

**Validation**:
```bash
cd auth && go build ./...
cd auth && go test ./internal/client/... -v -count=1
cd auth && grep -rn "retryWithBackoff" internal/
# Expected: no results
```

---

### [x] Task 9: Migrate `search` Off Custom Retry → `common/utils/retry` (`RetryWithBackoff` delegates to `retry.Do`; `IsRetryableError` uses `strings.Contains`)

**File**: `search/internal/service/common/retry_helpers.go` (120 LOC → DELETE)

**Problem**: Custom `RetryWithBackoff()`, `IsRetryableError()`, and hand-written `contains()` / `containsSubstring()` (instead of `strings.Contains`). ~120 LOC duplicating common's retry.

**Fix**:
1. Replace all callers of `common.RetryWithBackoff()` with `retry.Do()` from `common/utils/retry`
2. Replace `common.IsRetryableError()` callers with domain-specific `IsRetryable` callback
3. Delete `search/internal/service/common/retry_helpers.go`

**Validation**:
```bash
cd search && go build ./...
cd search && go test ./internal/service/... -v -count=1
cd search && grep -rn "RetryWithBackoff\|IsRetryableError\|containsSubstring" internal/
# Expected: no results
```

---

### [x] Task 10: Migrate `payment` Off Custom Retry → `common/utils/retry` (`retry_config.go` + `wrapper.go` uses `retry.Do` / `retry.DoResult`; removed `gateway/retry.go`)

**File**: `payment/internal/biz/gateway/retry.go` (160 LOC → DELETE)

**Prerequisite**: Task 4 (add `DoResult[T]` to common)

**Problem**: Custom `Retry()`, `RetryWithResult[T]()`, `DefaultRetryConfig()`, `IsRetryableError()` — 160 LOC duplicating common's retry with added generic return type.

**Fix**:
1. Replace `gateway.Retry()` callers → `retry.Do()`
2. Replace `gateway.RetryWithResult[T]()` callers → `retry.DoResult[T]()`
3. Move `gateway.IsRetryableError()` logic into a local `isRetryable` closure
4. Delete `payment/internal/biz/gateway/retry.go`

**Validation**:
```bash
cd payment && go build ./...
cd payment && go test ./internal/biz/gateway/... -v -count=1
cd payment && grep -rn "gateway\.Retry\|RetryWithResult" internal/
# Expected: no results
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 11: Migrate `order` CacheHelper → `common/utils/cache/TypedCache[T]` *(deferred)*

**File**: `order/internal/cache/cache.go` (~180 LOC)
**Value**: Consistency with checkout's pattern (already uses `TypedCache[T]`). Eliminates manual JSON marshal/unmarshal boilerplate.

**Fix**: Replace `CacheHelper` methods with `commonCache.TypedCache[biz.Order]` and `commonCache.TypedCache[biz.PromotionValidationResult]`.

**Validation**:
```bash
cd order && go build ./...
cd order && go test ./internal/cache/... -v -count=1
```

---

### [ ] Task 12: Delete `search` Custom `contains()` Function

**File**: `search/internal/service/common/retry_helpers.go` lines 104-118
**Value**: Replace hand-written byte comparison with `strings.Contains()` from stdlib. 20 LOC unnecessary code.
**Note**: This is resolved automatically by Task 9 (delete entire file).

---

## 🔧 Pre-Commit Checklist

```bash
# After common library changes (Tasks 3, 4):
cd common && go build ./...
cd common && go test -race ./...
cd common && golangci-lint run ./...

# After each service migration:
cd <service> && go get gitlab.com/ta-microservices/common@v1.30.5
cd <service> && go mod tidy && go mod vendor
cd <service> && go build ./...
cd <service> && go test -race ./...
```

---

## 📝 Commit Format

### For common library changes:
```
feat(common): add TransactionManager and DoResult[T] retry

- feat: add canonical NewTransactionManager() to common/data
- feat: add DoResult[T]() generic retry to common/utils/retry
- test: add unit tests for both new features

Closes: AGENT-01 (Tasks 3, 4)
```

### For vendor update sweep:
```
chore(*): upgrade common to v1.30.5 across all services

- fix: resolve P0 SQL injection vulnerability (pre-v1.25.0)
- fix: resolve P0 CORS credential leak (pre-v1.15.0)
- fix: resolve P0 outbox double-processing (pre-v1.15.0)

Closes: AGENT-01 (Task 1)
```

### For service-level migrations:
```
refactor(<service>): migrate to common TransactionManager/retry/repository

- refactor: replace custom TransactionManager with commonData.NewTransactionManager
- refactor: replace custom retry with common/utils/retry.Do()
- refactor: replace custom BaseRepo with common/repository.GormRepository[T]
- delete: remove <N> LOC of duplicated code

Closes: AGENT-01 (Tasks 5-10)
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| All services on common v1.30.5+ | `grep 'common v1.30' */go.mod` — **pending** tag + vendor sweep (Task 1) | ⏳ |
| No custom BaseRepo in notification/shipping | Open — Tasks 5–6 deferred | ⏳ |
| No custom TransactionManager in 5 services | order/return/checkout/shipping → `NewGormTransactionManager`; common-ops still local | **partial** |
| No custom retry in auth/search/payment | `retryWithBackoff` removed (auth); payment uses `retry.Do*`; search wraps `retry.Do` | ✅ |
| Dead TransactionContext removed from shipping | `grep -n "not fully implemented" shipping/` → 0 | ✅ |
| All services build cleanly | Run after `go get` + replace to tagged common | ⏳ |
| All service tests pass | Run per service after common tag | ⏳ |
| common/utils/retry has DoResult[T] | `grep "func DoResult" common/utils/retry/retry.go` | ✅ |
| common/data has GormTransactionManager | `grep "NewGormTransactionManager" common/data/` | ✅ |

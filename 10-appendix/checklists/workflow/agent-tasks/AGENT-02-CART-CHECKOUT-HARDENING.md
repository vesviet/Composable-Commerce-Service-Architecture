# AGENT-02: Cart & Checkout Saga Hardening

> **Created**: 2026-03-14
> **Priority**: P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`
> **Estimated Effort**: 2-3 days
> **Source**: Meeting Review (1000-Round Cart & Checkout Flows)

---

## 📋 Overview

Implement vital reliability and data consistency fixes for the Cart & Checkout 10-Step Saga. This batch removes silent error swallowing during rollback, mitigates race conditions in promotion applications, optimizes database lock usage via async compensation, and hardens the cart cleanup worker.

---

## ✅ Checklist — P1 Issues (High Priority)

### [x] Task 1: Fix Swallowed Rollback Errors in ConfirmCheckout
**File**: `checkout/internal/biz/checkout/confirm.go`
**Lines**: Search for `RollbackReservationsMap` and `_ = `
**Risk**: If the `ReleaseReservation` network call fails during a rollback, the error is discarded. This leads to leaked/zombie stock inventory (Phantom Stock).
**Problem**: The rollback logic uses a blank identifier to swallow the error:
```go
// BEFORE
_ = uc.warehouseInventoryService.ReleaseReservation(ctx, req)
```
**Fix**: Catch the error and wrap it, or push it to `FailedCompensation` for the DLQ worker to handle.
```go
// AFTER
err = uc.warehouseInventoryService.ReleaseReservation(ctx, req)
if err != nil {
	uc.log.Errorf("RollbackReservationsMap failed: %v", err)
	// Optionally push to FailedCompensation DLQ outbox
}
```
**Validation**:
```bash
cd checkout && go test ./internal/biz/checkout/... -v
```

### [x] Task 2: Refactor VoidAuthorization out of Synchronous DB Lock Path
**File**: `checkout/internal/biz/checkout/confirm.go`
**Lines**: Inside the saga failure compensations.
**Risk**: `VoidAuthorization()` calls an external payment gateway. If this is executed synchronously within a deferred rollback block while a DB transaction is active, it will cause connection pool exhaustion during spikes (e.g. 11.11 Flash Sale).
**Fix**: Dispatch the `VoidAuthorization` to an async background worker or write it to the outbox `FailedCompensation` immediately instead of blocking the request thread.
```go
// INSTRUCTION: Move VoidAuthorization() to an async goroutine or just write to outbox DB.
go func() {
    _ = uc.paymentService.VoidAuthorization(context.Background(), req)
}()
```
**Validation**:
```bash
cd checkout && go test ./internal/biz/checkout/... -v
```

### [x] Task 3: Address Promotion Apply Race Condition (Pre-Reserve Promotion)
**File**: `checkout/internal/biz/checkout/confirm.go` (Step 7)
**Risk**: Promotion budget leak. Promotions are currently applied *after* order creation. If a coupon's quota maximum is reached concurrently, the `ApplyPromotion` step will fail but the order order has been recorded with a discounted price.
**Instruction**: Refactor the Saga steps. During Step 3 (Validation) or Step 4, explicitly "Reserve" or acquire the coupon lock (simulate or use Redis LUA scripts via Promotion Service). If the reservation fails, abort early before the order is created in step 6.
**Validation**:
```bash
cd checkout && go test ./internal/biz/checkout/... -v
```

---

## ✅ Checklist — P2 Issues (Nice to Have)

### [x] Task 4: Prevent Lock Contention in CartCleanupWorker 
**File**: `checkout/internal/worker/cron/cart_cleanup.go`
**Risk**: Worker might interfere with active checkouts that hold transactions.
**Problem**: Standard `SELECT` to find expired `checkout` carts can block or read uncommitted rows causing data races.
**Instruction**: Modify the query executed by the worker to use `SELECT ... FOR UPDATE SKIP LOCKED`.
```go
// BEFORE
query := db.Where("status = ? AND updated_at < ?", "checkout", expirationTime).Find(&carts)

// AFTER
query := db.Clauses(clause.Locking{Strength: "UPDATE", Options: "SKIP LOCKED"}).
    Where("status = ? AND updated_at < ?", "checkout", expirationTime).Find(&carts)
```
**Validation**:
```bash
cd checkout && go test ./internal/worker/cron/... -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd checkout && wire gen ./cmd/server/ ./cmd/worker/
cd checkout && go build ./...
cd checkout && go test -race ./...
cd checkout && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(checkout): harden saga compensation and cart worker

- fix: catch error in warehouse reservation rollback
- refactor: move VoidAuthorization to async execution
- feat: pre-reserve promotions using locks during checkout validations
- fix: apply SKIP LOCKED to CartCleanupWorker

Closes: AGENT-02
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Rollback errors are caught | Check `confirm.go` `RollbackReservationsMap` error handling | ✅ |
| VoidAuth does not block | Verify `VoidAuthorization` run inside goroutine or queue | ✅ |
| Promotion Race Cond Mitigated | Verify coupon acquisition happens before order creation | ✅ |
| Cart cleanup is transaction safe | Verify `SKIP LOCKED` is used in GORM query | ✅ |

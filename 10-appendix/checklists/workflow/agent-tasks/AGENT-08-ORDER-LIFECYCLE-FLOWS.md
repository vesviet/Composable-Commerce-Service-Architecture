# AGENT TASK - ORDER LIFECYCLE FLOWS (AGENT-08)

## STATUS
**State:** [ ] Not Started | [ ] In Progress | [ ] In Review | [x] Done

## ASSIGNMENT
**Focus Area:** Order Lifecycle (Transaction Poisoning, Cancellation Compensation)
**Primary Services:** `order`
**Priority:** Critical (P0 fixes required)

## 📌 P0: Transaction Poisoning in createStatusHistory
**Risk:** `createStatusHistory` suppresses creation errors but is called inside `uc.tm.WithTransaction`. If GORM/Postgres encounters a failure inserting the history record, the transaction is marked Aborted. The swallowed error forces the code to proceed, causing all subsequent queries in the block (e.g., `uc.orderRepo.Update`, `uc.saveStatusChangedToOutbox`) to fail with "current transaction is aborted". This propagates silently and crashes order processing APIs.
**Location:** `order/internal/biz/order/status_helpers.go` (Method `createStatusHistory`, Line ~24)

### Implementation Plan
1.  **Refactor Error Handling to Return Error:**
    *   Change the signature of `createStatusHistory` to return an `error`:
        `func (uc *UseCase) createStatusHistory(...) error`
    *   Change the implementation to:
        ```go
        if _, err := uc.orderStatusHistoryRepo.Create(ctx, modelHistory); err != nil {
            uc.log.WithContext(ctx).Errorf("Failed to create order status history: %v", err)
            return fmt.Errorf("failed to create order status history: %w", err)
        }
        return nil
        ```
2.  **Propagate Error in Callers:**
    *   Find all references to `uc.createStatusHistory(...)` within the `order` package (in `create.go`, `cancel.go`, `process.go`, `update.go`, etc.).
    *   Ensure the error is checked and returned so that `WithTransaction` can rollback safely.
    *   Ex: `if err := uc.createStatusHistory(...); err != nil { return err }`

### 🔍 Verification Steps
*   Run unit tests: `go test -v ./order/internal/biz/order/...`
*   Verify all callers properly check the returned error from `createStatusHistory`.

---

## 📌 P1: Premature Cancellation DLQ in CancelOrder
**Risk:** If the gRPC attempt to `ReleaseReservation` fails during `CancelOrder`, the code immediately writes a DLQ outbox event (`writeReservationReleaseDLQ`) *before* the transaction that actually cancels the order has succeeded. If the cancellation transaction fails (e.g., due to optimistic lock or invalid state transition), the DLQ will still eventually release the stock in the background, resulting in lost stock for an order that is still active.
**Location:** `order/internal/biz/order/cancel.go` (Function `CancelOrder`, Line ~72)

### Implementation Plan
1.  **Deferred DLQ Publishing:**
    *   In `CancelOrder`, collect all `releaseErr` metadata into a slice instead of immediately calling `writeReservationReleaseDLQ`.
    *   Inside the `uc.tm.WithTransaction(...)` block, after updating the order status successfully, loop through the collected errors and call `writeReservationReleaseDLQ` passing the `txCtx`.
    *   Ensure `writeReservationReleaseDLQ` uses the provided `txCtx` for outbox saving so it's committed atomically with the order cancellation.
    *   If no transactions are used for the outer logic, ensure DLQ events are only emitted *after* successful row lock and update.
    *   Since outbox saves are usually done via transaction, integrating the DLQ saves into the `txCtx` block is exactly the required fix.

### 🔍 Verification Steps
*   Inspect `CancelOrder` to ensure `writeReservationReleaseDLQ` is only executed when the transactional state change is guaranteed to succeed.
*   Run unit tests: `go test -v ./order/internal/biz/order/...`

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add order/internal/biz/order/status_helpers.go
git add order/internal/biz/order/cancel.go
git add order/internal/biz/order/process.go
git add order/internal/biz/order/create.go

git commit -m "fix(order): prevent transaction poisoning by returning errors in createStatusHistory
fix(order): wrap reservation release DLQ inside cancellation transaction to prevent stock leaking

# Agent-08 Fixes based on 250-Round Meeting Review
# P0: Prevents 'aborted transaction' cascading errors in PostgreSQL
# P1: Prevents asynchronous stock leaks via premature DLQ event logging"
```

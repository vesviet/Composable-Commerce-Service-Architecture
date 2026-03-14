# AGENT-31: Return Service Deep Review Fixes

## Context
Following a 400-round deep meeting review of the `return` service, several critical (P0/P1) bugs were identified relating to distributed transaction data consistency, dead code in outbox retry patterns, and unhandled races in the compensation workers.

## P0 Tasks
- [x] **Fix 1: Dead Code `processReturnRefund` & Compensation Loop** ✅ IMPLEMENTED
  - **Location:** `biz/return/refund.go`, `worker/compensation_worker.go`, `biz/return/return_approval.go`
  - **Risk / Problem:** `processReturnRefund()` was dead code (never called). The `orders.return.completed` event was published to Dapr hoping Payment would consume it, but if Payment was down or failed, there was NO compensation or retry. The refund was silently lost.
  - **Solution Applied:** Instead of relying on Payment consuming `orders.return.completed`, we now emit a `return.refund.process_requested` outbox event in the `completed` case of `UpdateReturnRequestStatus`. The CompensationWorker picks it up and drives the refund via `PaymentService.ProcessRefund` gRPC with full retry/DLQ support.
  - **Files:**
    - `internal/biz/return/return_approval.go` — Added refund outbox event in the `completed` case (lines 92-111)
    - `internal/worker/compensation_worker.go` — Registered `return.refund.process_requested` in `compensationEventTypes` and switch case
  - **Validation:** `go build ./...` ✅, `go test -race ./internal/biz/return/` ✅

- [x] **Fix 2: Silent State Corruption in `CancelStaleReturns`** ✅ IMPLEMENTED
  - **Location:** `data/return_repo.go`, `worker/stale_return_cleanup.go`
  - **Risk / Problem:** `CancelStaleReturns()` directly updated GORM status to `cancelled` bypassing the biz layer. No `orders.return.cancelled` outbox events were generated per-return, and `orderService.UpdateOrderStatus` was never called — causing zombie orders stuck in `return_requested` state.
  - **Solution Applied:** Added `FindStaleReturns()` to the repository (returns IDs only). Refactored `StaleReturnCleanupWorker` to iterate those IDs and delegate each cancellation to `ReturnUsecase.UpdateReturnRequestStatus(status="cancelled")`, which emits proper outbox events and restores order status post-commit.
  - **Files:**
    - `internal/repository/return/return.go` — Added `FindStaleReturns` to interface (line 31)
    - `internal/data/return_repo.go` — Implemented `FindStaleReturns` (lines 310-322)
    - `internal/worker/stale_return_cleanup.go` — Full rewrite: now injects `*ReturnUsecase`, iterates stale IDs, delegates to biz layer
    - `cmd/worker/wire.go` — Updated Wire build to include `return_biz.ProviderSet` and all dependencies
    - `cmd/worker/wire_gen.go` — Regenerated via `wire gen`
    - `internal/biz/return/return_test.go` — Added `FindStaleReturns` to mock
    - `internal/service/return_test.go` — Added `FindStaleReturns` to mock
  - **Validation:** `wire gen ./cmd/worker/` ✅, `go build ./...` ✅, `go test -race ./...` ✅

## P1 Tasks
- [x] **Fix 3: Out-of-Transaction RPC Calls (`UpdateOrderStatus`)** ✅ IMPLEMENTED
  - **Location:** `biz/return/return_approval.go` (Lines 71, 183)
  - **Risk / Problem:** `orderService.UpdateOrderStatus` was called BEFORE the DB transaction for `rejected` and `cancelled` cases. If the transaction then failed, the Order service was already mutated, causing split-brain (Order thinks it's `completed`, Return thinks it's still `pending`).
  - **Solution Applied:** Moved both `UpdateOrderStatus` calls for `rejected` and `cancelled` to post-commit side effects (after the `WithTransaction` block), alongside the existing `approved` post-commit logic. Now failures in the DB transaction cannot corrupt Order service state.
  - **Files:**
    - `internal/biz/return/return_approval.go` — Removed pre-tx RPC calls from `rejected`/`cancelled` cases, added unified post-commit block (lines 232-238)
  - **Validation:** `go build ./...` ✅, `go test -race ./internal/biz/return/` ✅

- [x] **Fix 4: Race Condition in `ReturnCompensationWorker` Setting `completed`** ✅ IMPLEMENTED
  - **Location:** `worker/compensation_worker.go` (Lines 348-405)
  - **Risk / Problem:** When both refund and restock retries succeed, whichever finishes first would set the return to `completed` — even if the other was still pending. This caused premature completion and masked failures.
  - **Solution Applied:** Added a guard in `tryUpdateReturnStatus`: before setting status to `completed`, it fetches pending outbox events for this return and checks if any other compensation events are still pending. If so, it defers the status update until all compensating actions have completed.
  - **Files:**
    - `internal/worker/compensation_worker.go` — Added pending-event guard in `tryUpdateReturnStatus` (lines 367-389)
  - **Validation:** `go build ./...` ✅, `go test -race ./...` ✅

## 🔧 Pre-Commit Checklist
- [x] `wire gen ./cmd/worker/` ✅
- [x] `go build ./...` ✅
- [x] `go test -race ./...` ✅

## 📝 Commit Format
```
fix(return): fix P0/P1 distributed transaction, compensation, and race bugs

- Fix 1: Re-activate refund compensation loop via outbox (return.refund.process_requested)
- Fix 2: StaleReturnCleanupWorker delegates to biz layer for proper event emission
- Fix 3: Move out-of-transaction RPC calls to post-commit
- Fix 4: Guard tryUpdateReturnStatus against premature completion race
```

## Completion Criteria
| Criteria | Status |
|---|---|
| All tests in `biz/return` run successfully | ✅ |
| No direct `gorm.DB` mutations in Repo bypassing business logic | ✅ |
| Outbox pattern correctly envelopes all side effects | ✅ |

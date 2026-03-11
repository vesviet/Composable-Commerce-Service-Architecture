# AGENT TASK - RETURN & REFUND FLOWS (AGENT-11)

## STATUS
**State:** [ ] Not Started | [ ] In Progress | [ ] In Review | [x] Done

## ASSIGNMENT
**Focus Area:** Refund Idempotency & Return Distributed Transaction Integrity
**Primary Services:** `return`, `payment`
**Priority:** Critical (P0 fixes required)

## 📌 P0: Double Refund Vulnerability due to lack of Idempotency
**Risk:** In `payment/internal/data/eventbus/return_consumer.go`, when an `orders.return.completed` event is processed, it initiates a refund by calling `refundUc.ProcessRefund`. Because Message Brokers have at-least-once delivery, the event might be retried. `ProcessRefund` lacks an `IdempotencyKey` check and always generates a new `RefundID`. A retried event for a partial return will trigger an identical, completely separate refund call to the gateway, draining the merchant's funds.
**Location:** `payment/internal/biz/refund/usecase.go`, `payment/internal/biz/refund/dto.go`, `payment/internal/data/eventbus/return_consumer.go`

### Implementation Plan
1.  **Add Idempotency to Payment/Refund:**
    *   Update `ProcessRefundRequest` DTO in `dto.go` to include `IdempotencyKey string`.
    *   In `return_consumer.go`, pass `event.ReturnRequestID` (or `fmt.Sprintf("return:%s", event.ReturnRequestID)`) as the `IdempotencyKey` when building `ProcessRefundRequest`.
    *   In `usecase.go` (`ProcessRefund`), after acquiring the distributed lock, check if a refund with this `IdempotencyKey` already exists in the database.
    *   If it exists and was successful, return the existing refund immediately without calling the gateway. If it exists and failed, either reject or retry safely (depending on payment architecture).

### 🔍 Verification Steps
*   Run tests: `go test -v ./payment/internal/biz/refund/...`
*   Run tests: `go test -v ./payment/internal/data/eventbus/...`

---

## 📌 P0: External Mutation Before Local Commit (Distributed Transaction Poisoning)
**Risk:** In `return/internal/biz/return/return_approval.go`, inside the `UpdateReturnRequestStatus` branch for `"completed"`, the service calls `processExchangeOrder` (which calls Order Service via gRPC) and `restockReturnedItems` (which calls Warehouse Service via gRPC) BEFORE wrapping the return status update in `uc.tm.WithTransaction(ctx, ...)`. If the local DB transaction fails, the Return Request rolls back to its old status, but the Warehouse inventory is incorrectly inflated and a ghost Exchange Order is created in the Order service.
**Location:** `return/internal/biz/return/return_approval.go`

### Implementation Plan
1.  **Move Mutations to Async Outbox Workers:**
    *   Do NOT call `uc.processExchangeOrder` or `uc.restockReturnedItems` directly inside `UpdateReturnRequestStatus`.
    *   Instead, in `return_approval.go`, when the status is `"completed"`, simply create Outbox Events for them (e.g., `return.exchange.process_requested`, `return.restock.process_requested`) and save them *inside* the main `txCtx` transaction block alongside the status update.
    *   Create consumer workers/handlers in the Return service that listen to these outbox events and *then* execute the gRPC calls to Order and Warehouse services with proper retries.

### 🔍 Verification Steps
*   Run tests: `go test -v ./return/internal/biz/return/...`

---

## 📌 P1: Non-Transactional Outbox Save (Phantom Compensation)
**Risk:** In `return/internal/biz/return/restock.go`, if restocking a single item fails, it saves a `return.restock_retry` outbox event using the incoming HTTP `ctx`, not the database transaction context. This event is committed immediately. If the main HTTP request subsequently fails to commit the overarching `UpdateReturnRequestStatus` transaction, we have a phantom retry event floating around for a return that hasn't officially reached the completed state yet.
**Location:** `return/internal/biz/return/restock.go`

### Implementation Plan
1.  **Transactional Alignment:**
    *   If the async worker approach (above) is taken, this issue naturally disappears as the restock logic moves to a separate worker transaction.
    *   If staying synchronous, `restockReturnedItems` must either accept `txCtx` and run inside the transaction, or return a list of `outbox.Event` objects to be saved collectively by the caller inside the transaction.

### 🔍 Verification Steps
*   Run tests: `go test -v ./return/internal/biz/return/...`

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add payment/internal/biz/refund/usecase.go
git add payment/internal/biz/refund/dto.go
git add payment/internal/data/eventbus/return_consumer.go
git add payment/internal/data/repository/
git add return/internal/biz/return/

git commit -m "fix(payment): add idempotency to refund processing to prevent double refunds
fix(return): decouple restock and exchange mutations into async outbox events

# Agent-11 Fixes based on 250-Round Meeting Review
# P0: Refund endpoint in Payment service uses Distributed Lock & DB Idempotency Key check
# P0: Return Approval no longer synchronously mutates Warehouse and Order services
# P1: Phantom restock retry events prevented by bringing Outbox saves into Tx boundary"
```

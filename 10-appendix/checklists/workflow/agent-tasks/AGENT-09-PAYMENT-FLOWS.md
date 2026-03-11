# AGENT TASK - PAYMENT FLOWS (AGENT-09)

## STATUS
**State:** [ ] Not Started | [ ] In Progress | [ ] In Review | [x] Done

## ASSIGNMENT
**Focus Area:** Payment Processing (Delayed Persistence, Phantom Charges, Idempotency)
**Primary Services:** `payment`
**Priority:** Critical (P0 fixes required)

## 📌 P0: Delayed Payment DB Persistence (Phantom Charge)
**Risk:** In `ProcessPayment`, the system constructs the `Payment` struct in memory, calls `uc.processPaymentWithGateway(ctx, payment, paymentMethod)`, and only AFTER returning from the gateway does it save the `Payment` to the database. If the pod crashes during the gateway call, or if the HTTP request times out (yielding an `err` and forcing `payment.Status = Failed`), the database record is either lost entirely or incorrectly marked as Failed without a `GatewayPaymentID`. When the gateway's asynchronous webhook arrives indicating success, the local database cannot match it, leading to a permanent state inconsistency (user is charged, but order remains unpaid).
**Location:** `payment/internal/biz/payment/usecase.go` (Method `ProcessPayment`, Line ~155-220)

### Implementation Plan
1.  **Phase 1 - Persist Intent:**
    *   Before calling `uc.processPaymentWithGateway`, persist the `payment` to the database using `uc.paymentRepo.Create(ctx, payment)`.
    *   The `payment` status should be initialized to `PaymentStatusPending`.
    *   This ensures that the intent to charge is durably recorded.
2.  **Phase 2 - Execute External Call:**
    *   Call `uc.processPaymentWithGateway(...)`.
3.  **Phase 3 - Update Status:**
    *   Change the logic after the gateway call to use `uc.paymentRepo.Update(ctx, payment)` instead of `Create`.
    *   If the gateway call times out or errors, the `Update` saves the `Failed` state.
    *   If it succeeds, it updates the status to `Authorized` or `Captured` as appropriate, along with the `GatewayPaymentID`.
4.  **Metadata Tracing (Webhook robustness):**
    *   When constructing the request to the gateway, ensure you inject the internal `PaymentID` into the gateway's metadata. This allows webhooks to look up by our internal `PaymentID` if `GatewayPaymentID` matching fails.

### 🔍 Verification Steps
*   Run unit tests: `go test -v ./payment/internal/biz/payment/...`
*   Verify that `ProcessPayment` properly creates the pending record before the gateway call, and updates it afterward.

---

## 📌 P1: Gateway Transaction ID Collisions on Retries
**Risk:** The failover logic generates `attemptTransactionID := fmt.Sprintf("%s_gw%d", baseTransactionID, i)`. Wait, `baseTransactionID` is `tx_<PaymentID>`, which is unique if `PaymentID` is unique per attempt. Oh! Wait, `PaymentID` *is* unique per attempt because `createPaymentFromRequest` generates a new `PaymentID` via `commonUUID.NewPrefixedID("pay")` every time `ProcessPayment` is called.
BUT if the same `ProcessPayment` is retried due to a client timeout retry *and* idempotency cache is wiped or expired, the system will generate a NEW `PaymentID`. If the gateway processed the original charge but the connection dropped, the client retry will cause a double charge because the `PaymentID` changed, so `baseTransactionID` changed!
**Location:** `payment/internal/biz/payment/usecase.go` (Method `processPaymentWithGateway` & Idempotency)

### Implementation Plan
1.  **Stable Transaction ID:**
    *   To prevent double charges if idempotency cache is wiped, the `baseTransactionID` sent to the gateway should be durably linked to the `OrderID` rather than the ephemeral `PaymentID`, or the `ProcessPaymentRequest` should strictly require an idempotency key passed by the client.
    *   Specifically, use `req.IdempotencyKey` if provided by the checkout service. The checkout service generating stable idempotency keys is better than generating them inside the payment service based on amount hash.

### 🔍 Verification Steps
*   Ensure the gateway receives a transaction ID that resists duplicate external charges.

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add payment/internal/biz/payment/usecase.go

git commit -m "fix(payment): prevent phantom charges by persisting payment intent before gateway calls
fix(payment): stabilize gateway transaction IDs to prevent double charges on retries

# Agent-09 Fixes based on 250-Round Meeting Review
# P0: Saves payment as Pending before mutating state on external providers
# P1: Hardens webhook reconciliation and idempotency against network timeouts"
```

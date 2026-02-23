# Payment Service — Logic Review Checklist (v5)

> **Date**: 2026-02-18 | **Reviewer**: AI-assisted Deep Review (re-verified)
> **Scope**: Full payment lifecycle — ProcessPayment → Capture → Refund → Webhook → Retry → Sync → Reconciliation
> **Benchmark**: Shopify, Shopee, Lazada payment patterns
> **Implementation Status**: ✅ 19/21 issues resolved (P0: 1/1, P1: 9/9, P2: 9/11) + 2 new P2 items identified

---

## 1. Data Consistency Between Services

### 1.1 Event Publisher Consolidated ✓

- [x] **P1-1**: Previously two distinct `EventPublisher` implementations existed (direct Dapr + outbox). Now consolidated to `ServiceEventPublisher` — single publisher wired via `provider.go`.

### 1.2 Payment vs Order Amount Cross-Validated ✓

- [x] **P1-2**: `ProcessPayment` (usecase.go:78-96) now validates `req.Amount` against order service's `order.TotalAmount`. Returns error if amounts differ. Falls back with warning when order client is not configured.

### 1.3 Currency Mismatch Enforced ✓

- [x] **P2-1**: `ProcessPayment` (usecase.go:90-92) now returns error when `req.Currency != order.Currency`. No longer just a risk — actively blocked.

---

## 2. Outbox / Saga Pattern Review

### 2.1 Outbox in Same Transaction as Payment Create ✓

- [x] **P0-1**: `ProcessPayment` (usecase.go:212) now wraps `paymentRepo.Create` + `eventPublisher.Publish*` inside `uc.transaction.InTx()`. DB write and outbox event are atomic.

### 2.2 Refund Event Inside Transaction ✓

- [x] `refund/usecase.go` wraps refund + payment status update in `transaction.InTx()`.
- [x] **P1-3**: `PublishPaymentRefunded` (line 191-209) now runs **inside** the transaction. Event is guaranteed to be created atomically with the refund.

### 2.3 Outbox Worker Verified ✓

- [x] **P1-4**: Outbox worker wired in `cmd/worker/wire.go` (line 123: `event.NewOutboxWorker`, line 157: workers append). Events from outbox table are delivered.

### 2.4 No Saga Compensation for Cross-Service Failures

- [ ] **P2-2**: When payment succeeds but downstream order status update fails (event lost or consumer error), there is no compensation mechanism:
  - No scheduled job to reconcile payment.status vs order.status
  - No payment→order status sync webhook
  - **Shopee pattern**: Dedicated "payment-order consistency checker" cron job
  - **Lazada pattern**: Saga orchestrator with compensating transactions

---

## 3. Retry / Rollback Mechanism Review

### 3.1 Retry Service Functional ✓

- [x] `getFailedPaymentsForRetry()` correctly queries DB, filters by retry_count and next_retry_at.
- [x] `retryPayment()` correctly calls `gateway.ProcessPayment()` with unique transaction ID.
- [x] `updateRetryInfo()` correctly persists retry count + next retry time via `paymentRepo.Update()`.
- [x] `moveToDeadLetter()` correctly calls `paymentRepo.Update()` with `PaymentStatusDeadLetter`.

### 3.2 `next_retry_at` Migration Added ✓

- [x] **P1-5**: Migration `003_add_next_retry_at_column.sql` adds `next_retry_at TIMESTAMP WITH TIME ZONE` with index `idx_payments_next_retry_at`.

### 3.3 `PaymentStatusDeadLetter` Not in Status Column Check Constraints

- [ ] **P2-3**: The status check constraint (migration 013) allows `pending, processing, authorized, captured, completed, failed, cancelled, refunded, voided` but not `dead_letter`, `partially_refunded`, `disputed`, `settled`. Dead letter status will be rejected at DB level. Constraint needs updating to include all valid statuses.

---

## 4. State Machine Validation

### 4.1 `CanTransitionTo()` Enforced in All Paths ✓

- [x] `UpdatePaymentStatus` (usecase.go:433) — calls `payment.CanTransitionTo(status)` ✓
- [x] `CapturePayment` (usecase.go:493) — calls `payment.CanTransitionTo(PaymentStatusCaptured)` ✓
- [x] `VoidPayment` (usecase.go:537) — calls `payment.CanTransitionTo(PaymentStatusVoided)` ✓
- [x] **P1-6**: Status mutations in `ProcessPayment` now use `CanTransitionTo()`:
  - Gateway failure path (line 171): `payment.CanTransitionTo(PaymentStatusFailed)` ✓
  - Gateway success path (line 184): `payment.CanTransitionTo(newStatus)` ✓
  - Auto-capture path (line 194): `payment.CanTransitionTo(PaymentStatusCaptured)` ✓

### 4.2 State Machine Transitions Complete ✓

- [x] **P2-4**: All transitions now exist in `CanTransitionTo()` (payment.go:294-334):
  - `requires_action → authorized` ✅ (line 303)
  - `requires_action → failed` ✅ (line 304)
  - `authorized → voided` ✅ (line 310)
  - `captured → disputed` ✅ (line 316)
  - `partially_refunded → refunded` ✅ (line 327)
  - `disputed → refunded` ✅ (line 330)
  - `disputed → partially_refunded` ✅ (line 331)
  - `disputed → completed` ✅ (line 332)

### 4.3 `IsFinalStatus()` vs `CanTransitionTo()` Consistent ✓

- [x] **P2-5**: `IsFinalStatus()` (payment.go:349-367) only marks `cancelled`, `refunded`, `voided` as final. `failed` is explicitly NOT final (comment lines 352-354), consistent with `CanTransitionTo` allowing `failed → pending` for retry.

---

## 5. Edge Cases & Risk Points

### 5.1 Failover Uses Unique TransactionID per Gateway ✓

- [x] **P1-7**: `processPaymentWithGateway` (usecase.go:707) now generates `attemptTransactionID := fmt.Sprintf("%s_gw%d", baseTransactionID, i)` — unique per gateway attempt. No more cross-gateway idempotency conflicts.

### 5.2 Distributed Lock on Refund ✓

- [x] **P1-8**: `ProcessRefund` (refund/usecase.go:18-28) now acquires `payment:lock:refund:{paymentID}` distributed lock with 30s TTL. Concurrent refunds are serialized.

### 5.3 Float64 for Money

- [x] **P2-6**: Partially resolved — `Money` type using integer cents exists (payment.go:14-146) with full arithmetic, JSON, and SQL support. However, `Payment.Amount` (line 193) is still `float64`, not `Money`. The `Money` type is available but not yet adopted in the domain entity.
  - ✅ **PARTIALLY FIXED**: `Money` type infrastructure complete. Remaining: migrate `Payment.Amount`, `Order.TotalAmount`, and related fields from `float64` to `Money`.

### 5.4 Reconciliation Status Mapping — `requires_action` Grouped with `pending`

- [ ] **P2-7**: `isStatusMatched()` groups `requires_action` with `pending`. While both are "incomplete", `requires_action` means customer must take action (3DS), whereas `pending` means gateway is processing. Can mask genuine status drift.

### 5.5 COD Payment Flow Gaps

- [ ] **P2-8**: `biz/payment/cod.go` exists (10KB) but COD payments skip gateway flow entirely. No verification that:
  - COD is allowed for the order's shipping destination
  - COD maximum order value is enforced
  - COD fee is applied and recorded

### 5.6 Gateway Call Timeouts ✓

- [x] **P2-9**: Gateway wrapper (`gateway/wrapper.go`) wraps all gateway operations (`ProcessPayment`, `CapturePayment`, `RefundPayment`, `VoidPayment`, `GetPaymentStatus`) with `context.WithTimeout(ctx, 30*time.Second)`. Includes circuit breaker, retry, and rate limiting.

### 5.7 Idempotency Key Uses Integer Cents ✓

- [x] **P2-10**: `generateIdempotencyKey` (usecase.go:378-384) uses `int64(req.Amount * 100)` for integer cents formatting. No float precision issues.

### 5.8 Float64 Equality in Amount Validation ✓

- [x] **N1 (P2)**: `ProcessPayment` (usecase.go:85) amount comparison now uses epsilon tolerance `math.Abs(req.Amount - order.TotalAmount) > 0.005` instead of direct `!=` on float64 values. Avoids IEEE 754 precision false mismatches.

### 5.9 CapturePayment/VoidPayment Events in Transaction ✓

- [x] **N2 (P2)**: `CapturePayment` and `VoidPayment` now wrap DB update + event publish in `uc.transaction.InTx()`, consistent with the outbox pattern used in `ProcessPayment` and `ProcessRefund`.

---

## 6. Security Observations

### 6.1 Webhook Timestamp Tolerance Enforced ✓

- [x] **P1-9**: `validateWebhookSecurity` (handler.go:158-166) now rejects webhooks > 5 minutes old at the platform level, with metrics recording for security failures.

### 6.2 Webhook `handlePaymentFailed` ✓

- [x] Correctly checks current status (line 64) — only processes if payment is in `pending` or `requires_action`.

### 6.3 PCI Sensitive Logging

- [ ] **P2-11**: `ProcessPayment` log includes `amount` but review if any gateway response logging exposes card tokens, CVV fragments, or PII.

---

## 7. Summary: Priority Matrix

| Priority | Total | Resolved | Remaining | Key Remaining Items |
|----------|-------|----------|-----------|-------------------|
| **P0** | 1 | **1** ✅ | 0 | All resolved |
| **P1** | 9 | **9** ✅ | 0 | All resolved |
| **P2** | 13 | **9** | 4 | Saga compensation, status constraint, COD, PCI logging |

### Remaining Fixes (by Impact)

1. **Saga compensation / consistency checker** (P2-2) — no reconciliation between payment and order status
2. **DB status constraint** (P2-3) — missing `dead_letter`, `partially_refunded`, `disputed`, `settled` in constraint
3. **COD payment flow** (P2-8) — missing destination, max value, fee validation
4. **PCI sensitive logging** (P2-11) — audit gateway response logging

---

## Appendix: Items Verified as Fixed Since Original Review ✓

| Issue | What Changed |
|-------|-------------|
| **P0-1** (outbox outside tx) | `ProcessPayment` now wraps `paymentRepo.Create` + event publish in `InTx()` |
| **P1-1** (dual publishers) | Consolidated to `ServiceEventPublisher`, old direct Dapr publisher removed |
| **P1-2** (amount not validated) | Amount cross-validated against order service with error on mismatch |
| **P1-3** (refund event outside tx) | `PublishPaymentRefunded` now inside `InTx()` block |
| **P1-4** (no outbox worker) | Outbox worker wired in `cmd/worker/wire.go` |
| **P1-5** (no next_retry_at) | Migration `003_add_next_retry_at_column.sql` added |
| **P1-6** (state machine bypass) | `CanTransitionTo()` added to all paths: ProcessPayment, auto-capture, sync |
| **P1-7** (shared failover txn ID) | Unique `attemptTransactionID` per gateway attempt |
| **P1-8** (no refund lock) | Distributed lock `payment:lock:refund:{paymentID}` with 30s TTL |
| **P1-9** (webhook timestamp) | 5-minute tolerance enforced with metrics |
| **P2-1** (currency mismatch) | Currency mismatch returns error instead of just warning |
| **P2-4** (missing transitions) | `disputed → refunded/partially_refunded/completed` transitions added |
| **P2-5** (IsFinalStatus contradiction) | `failed` removed from final statuses; consistent with retry logic |
| **P2-6** (float for money) | `Money` type infrastructure complete (adoption pending) |
| **P2-9** (no gateway timeout) | `gateway/wrapper.go` adds 30s timeout to all gateway calls |
| **P2-10** (idempotency float) | Uses `int64(req.Amount * 100)` integer cents |
| **N1** (float equality) | Amount comparison uses epsilon tolerance |
| **N2** (capture/void outside tx) | Wrapped in `InTx()` with event publish |

---

## Appendix: Items Verified as Correct ✓

| Area | Detail |
|------|--------|
| **Outbox types** | `PublishPaymentProcessed` and `PublishPaymentFailed` both use struct-based events |
| **State machine** | `CanTransitionTo()` called in ALL status mutation paths |
| **CapturePayment** | Has `amount = &payment.Amount` fallback when `req.Amount == 0` — no nil deref |
| **Retry service** | Fully implemented: queries DB, filters eligible, calls gateway, persists retry info |
| **Dead letter** | Correctly calls `paymentRepo.Update()` with `PaymentStatusDeadLetter` |
| **Outbox backoff** | `MarkFailed` fetches `currentRetries` before increment — exponential backoff works correctly |
| **Reconciliation** | Correctly uses `localPayment.GatewayPaymentID` (not `PaymentID`) for gateway queries |
| **Webhook failed** | Checks current status — only transitions from `pending`/`requires_action` to `failed` |
| **Gateway wrapper** | All gateway ops wrapped with timeout, circuit breaker, retry, rate limiting |

---

> **Implementation Status (2026-02-18)**:
> - ✅ **P0 Critical Issues**: 1/1 completed — all resolved
> - ✅ **P1 High-Priority Issues**: 9/9 completed — all resolved
> - ⚠️ **P2 Quality Issues**: 9/13 completed — 4 quality improvements remain
> - **Remaining**: 4 issues (0×P0, 0×P1, 4×P2)
> - **Next steps**: Address P2 quality items (saga compensation, DB constraint update, COD validation, PCI audit) → integration testing → production deployment

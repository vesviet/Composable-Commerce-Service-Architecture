# Checkout Process Flow - Issues, Index, Plan & Fixes

**Last Updated**: 2026-01-20  
**Scope**: Order Service checkout (`order/internal/biz/checkout/*`)

This document tracks review findings for the Checkout flow and provides a **repeatable verification plan** (API calls, required headers, expected outcomes).

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] [NEW ISSUE 🆕] CHECKOUT-P1-06 Payment Event Topic Mismatch: Consumer subscribes to `payment.confirmed`/`payment.failed` while constants define `payments.payment.confirmed`/`payments.payment.failed`. Required: align topics with constants to avoid missed events. See `order/internal/data/eventbus/payment_consumer.go`, `order/internal/constants/constants.go`.
- [High] [NEW ISSUE 🆕] CHECKOUT-P1-07 Silent Subscription Skip: Payment consumer returns nil on missing config/pubsub, silently disabling critical capture events. Required: fail-fast or explicit disable flag. See `order/internal/data/eventbus/payment_consumer.go`.
- [High] [NEW ISSUE 🆕] CHECKOUT-P1-08 Outbox Publisher No-Op Risk: If Dapr publisher fails init, it falls back to NoOp but outbox worker still marks events as published, losing critical payment events. Required: fail startup or keep events pending when publisher is NoOp. See `order/internal/events/publisher.go`, `order/internal/worker/outbox/worker.go`.
- [Medium] [NEW ISSUE 🆕] CHECKOUT-P2-02 Outbox Status Semantics: Outbox worker uses status `published` while schema defaults to `pending` and no cleanup policy is defined. Required: unify status enum (pending/failed/completed) + add cleanup retention. See `order/internal/worker/outbox/worker.go`, `order/internal/data/postgres/outbox.go`.
- [Medium] P2-01 ConfirmCheckout Complexity: `ConfirmCheckout` still overly long/complex. Required: refactor into smaller private methods. See `order/internal/biz/checkout/confirm.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- [Reliability] [NEW ISSUE 🆕] CHECKOUT-P1-06 Payment event topic mismatch (confirmed/failed) can drop events.
- [Reliability] [NEW ISSUE 🆕] CHECKOUT-P1-07 Payment consumer silently skips subscriptions when config is nil.
- [Reliability] [NEW ISSUE 🆕] CHECKOUT-P1-08 Outbox publisher NoOp fallback causes event loss while marking as published.
- [Maintainability] [NEW ISSUE 🆕] CHECKOUT-P2-02 Outbox status/cleanup semantics are inconsistent.

## ✅ RESOLVED / FIXED
- ~~[FIXED ✅] P1-01 Authorization currency fallback hardcoded to USD: now uses `constants.DefaultCurrency`.~~
- ~~[FIXED ✅] P1-02 Capture failure wraps wrong error variable: already correct.~~
- ~~[FIXED ✅] P1-03 Capture failure ignores order status update errors: now logs/alerts.~~
- ~~[FIXED ✅] P1-04 Compensation errors ignored: now returned and alerted.~~
- ~~[FIXED ✅] P1-05 Checkout confirm lacks durable Saga: outbox capture + consumer + retry worker implemented.~~

---

## Index

- **P1**
  - **P1-01**: Authorization currency fallback hardcoded to `USD` (**Status: ✅ Fixed**)
  - **P1-02**: Capture failure wraps wrong error variable (**Status: ✅ Not applicable / already correct**)  
  - **P1-03**: Capture failure ignores order status update errors (**Status: ✅ Fixed**)  
  - **P1-04**: Compensation (void/refund/release) errors ignored (**Status: ✅ Fixed**)  
  - **P1-05**: Checkout confirm is a manual distributed transaction, lacks durable Saga (**Status: ✅ Fixed**)  
- **P2**
  - **P2-01**: `ConfirmCheckout` overly long/complex (**Status: ❌ Not fixed**)  

---

## P1-01 - Correctness / Payment (currency propagation)

- **Issue**: Authorization used hardcoded fallback currency `"USD"`.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/payment.go` (`authorizePayment`)
  - **Impact**: Wrong authorization currency for non-USD carts; reconciliation risk.
  - **Fix Applied (2026-01-19)**:
    - Fallback now uses `constants.DefaultCurrency` (and callers already pass cart currency when present).
  - **Extra Fix Applied (preview)**:
    - `order/internal/biz/checkout/preview.go` no longer falls back to `"USD"` and no longer hardcodes country `"US"`.

### Verification Plan

- **Test A: Checkout confirm uses cart currency**
  - Prepare a cart with `currency != USD` (e.g., `VND`).
  - Run confirm (through API gateway path used by frontend).
  - Expected:
    - Payment service receives `Currency=<cart currency>` for authorization.
    - No `"USD"` appears as default unless currency truly missing.

- **Test B: Checkout preview uses request currency / defaults**
  - Call preview with empty `currency` and non-empty shipping country.
  - Expected:
    - Pricing call uses `constants.DefaultCurrency` and country from `shipping_address.country_code`.

---

## P1-02 - Correctness / Payment (error variable on capture failure)

- **Issue**: Capture failure returns wrapped error using wrong variable.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/confirm.go`
  - **Status**: ✅ **Not applicable / already correct**
  - **Evidence**: Current code returns `fmt.Errorf(\"payment capture failed: %w\", captureErr)`.

---

## P1-03 - Resilience (order status update on capture failure)

- **Issue**: Order status update errors are ignored on capture failure.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/confirm.go`
  - **Status**: ✅ **Fixed**
  - **Evidence**: Current code logs `[CRITICAL]` and triggers alert `ORDER_STATUS_UPDATE_FAILED` when status update fails.

### Verification Plan
- Simulate failure of `UpdateOrderStatus` (e.g., make Order service repo return error in dev).
- Expected:
  - Checkout confirm returns capture failure error.
  - Alert is triggered for inconsistent state.

---

## P1-04 - Resilience (compensation errors must be surfaced)

- **Issue**: Errors from compensating actions (refund/void/release) were ignored.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/payment.go` (`rollbackPaymentAndReservations`)
  - **Impact**: Funds could remain on hold; reservations not released; requires manual intervention but no signal.
  - **Fix Applied (2026-01-19)**:
    - `rollbackPaymentAndReservations` now **returns a joined error** if any compensation step fails (refund, void, release/cleanup).
    - Callers already log as `[CRITICAL]` + trigger alerts when rollback returns an error.

### Verification Plan
- Force `VoidAuthorization` or `ProcessRefund` to fail in dev.
- Expected:
  - `rollbackPaymentAndReservations` returns error.
  - Caller logs `[CRITICAL]` and triggers alert (`PAYMENT_ROLLBACK_FAILED` / `PAYMENT_VOID_FAILED`).

---

## P1-05 - Atomicity / Distributed Transaction (Saga)

- **Issue**: Checkout confirm is a sequential distributed transaction (`Authorize -> Create Order -> Capture`) without a durable Saga/state machine.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/confirm.go`
  - **Status**: ✅ **Fixed** (Phase 1 + Phase 2 + Phase 3 implemented)

### Implementation Summary (Phase 1)
- ✅ **Migration 035**: Added Saga state fields to `orders` table:
  - `payment_saga_state` (authorized, capture_pending, capture_failed, captured)
  - `authorization_id`, `capture_retry_count`, `last_capture_attempt_at`
- ✅ **Constants**: `PaymentSagaState*`, retry config (`MaxCaptureRetries`, `CaptureRetryBaseDelay`, `CaptureRetryMaxDelay`)
- ✅ **Model Updates**: Saga fields on Order (domain + db)
- ✅ **Idempotent Capture**: `capturePayment` checks already-captured before calling payment service
- ✅ **State Tracking**: Order creation sets `authorized`; capture sets `capture_pending` → `captured`/`capture_failed`

### Implementation Summary (Phase 2 - finished)
- ✅ **Capture Retry Worker** (`capture-retry-job`):
  - Scans orders in `authorized` / `capture_failed` states
  - Applies exponential backoff (capped) + max retries
  - Idempotent capture using Saga state + authorization_id
  - Updates Saga state to `capture_pending` → `captured` or `capture_failed`
- ✅ **Outbox-driven capture initiation**
  - On order creation with `payment_saga_state=authorized`, Order service enqueues outbox event:
    - topic: `orders.payment.capture_requested`
    - payload: `{ order_id, authorization_id, amount, currency, ... }`
  - Outbox worker publishes this event via Dapr pub/sub.
- ✅ **Event consumer handles capture request**
  - Event consumer subscribes to `orders.payment.capture_requested`
  - Performs payment capture and updates order state:
    - `capture_failed` on failure (retryable)
    - `captured` on success + writes `payment_id` into metadata
- ✅ **Outbox emits capture result events**
  - On capture success: enqueue `orders.payment.captured`
  - On capture failure: enqueue `orders.payment.capture_failed`

### Verification Plan
1. **Idempotency**:
   - Create order with authorization
   - Call capture twice (or let worker rerun)
   - Expect first capture succeeds, subsequent attempts return already-captured

2. **State Tracking**:
   - After order creation: `payment_saga_state = authorized`, `authorization_id` set
   - During worker attempt: `capture_pending` then `captured` or `capture_failed`

3. **Worker Retry & Backoff**:
   - Force payment provider to fail → observe `capture_retry_count` increments and `capture_failed` state
   - After backoff window, worker retries and succeeds → state becomes `captured`

4. **Crash Recovery**:
   - Authorize payment, stop service before capture
   - Restart worker; it retries capture using same `authorization_id`
   - Expect successful capture without duplication

### Phase 3 - Compensation + DLQ (Implemented)
- ✅ **Compensation job**: `payment-compensation-job`
  - Scans orders with:
    - `payment_saga_state = capture_failed`
    - `capture_retry_count >= MaxCaptureRetries`
  - Executes compensation:
    - **Void authorization** (release funds hold)
    - **Cancel order** + set `payment_status=failed`
  - On any failure:
    - Writes to **DLQ** (`failed_events`) with:
      - topic: `orders.payment.compensation_failed`
      - event_type: `orders.payment.compensation_failed`
      - payload includes `order_id`, `authorization_id`, `reason`, `error`
    - Triggers alert (if alert service wired) using `PAYMENT_COMPENSATION_FAILED` / `ORDER_STATUS_UPDATE_FAILED`

### Verification Plan (Phase 3)
1. Force capture to fail until retries exhausted (`capture_retry_count >= MaxCaptureRetries`).
2. Wait for compensation job interval.
3. Expected:
   - Payment authorization is voided (funds hold released)
   - Order status becomes `cancelled`, payment_status becomes `failed`
4. If void/cancel fails:
   - A `failed_events` record is created (DLQ)
   - Alert is triggered with severity critical

---

## P2-01 - Maintainability (ConfirmCheckout complexity)

- **Issue**: `ConfirmCheckout` is overly long and complex.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/confirm.go`
  - **Status**: ❌ **Not fixed (refactor work)**

### Plan
- Extract private methods:
  - `loadAndValidateSessionAndCart`
  - `validatePrerequisites`
  - `finalStockValidationAndExtendReservations`
  - `calculateTotals`
  - `authorizePayment`
  - `buildOrderRequest`
  - `createOrderAndConfirmReservations`
  - `capturePaymentOrHandleFailure`
  - `finalizeOrderAndCleanup`

---

## Checkout Process Logic Checklist (Operational)

### 1. Checkout Initialization & Cart Validation
- [ ] **Cart Validation**: Ensure `CreateOrder` validates cart status (must be active, not empty).
- [ ] **Stock Check**: Verify `ReserveStock` is called and handles "insufficient stock" gracefully (User P2 issue).
- [ ] **Pricing**: Confirm `GetPricesBulk` is used (optimized) and matches cart totals.
- [ ] **Address**: Validate shipping/billing address presence and completeness.

### 2. Order Creation & State Management
- [ ] **Status Transition**: Initial status must be `Pending`.
- [ ] **Idempotency**: `IdempotencyKey` must be unique per request; duplicate keys should return stored result.
- [ ] **Transaction**: Order creation and initial status history must be atomic (within transaction).
- [ ] **Timeouts**: Order created with expiration (e.g., 30m) for payment.

### 3. Payment Processing
- [ ] **Authorization**: `ProcessPayment` should Authorization (not Capture) first (unless AutoCapture enabled).
- [ ] **Webhook Verification**:
  - [ ] Signatures verified using `headers` (e.g., `Stripe-Signature`, `Paypal-Transmission-Sig`).
  - [ ] `Timestamp` tolerance checked (prevent replay attacks).
  - [ ] `Idempotency` checked for webhooks (don't process same event twice).
- [ ] **Status Updates**:
  - [ ] `payment_intent.succeeded` -> Capture -> Order `Paid` (or `Confirmed`).
  - [ ] `payment_intent.failed` -> Order `PaymentFailed` (trigger retry notification).
- [ ] **Fraud Check**: Fraud score analyzed before capturing. High risk -> Block/Review.

### 4. Post-Payment Fulfillment
- [ ] **Inventory Confirmation**: Confirm stock reservation upon payment success.
- [ ] **Shipping**: `CreateShipment` triggered only after payment confirmation.
- [ ] **Notifications**: Order confirmation email sent to user.

### 5. Error Handling & Resilience
- [ ] **Circuit Breakers**: Active on calls to Payment/Warehouse/Shipping services.
- [ ] **Retries**: Exponential backoff for transient failures (e.g., Gateway timeout).
- [ ] **Compensation**: If payment succeeds but inventory fails (rare race), auto-refund or manual alert? (Saga pattern required?).

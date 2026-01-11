# Payment Processing Logic Checklist + Implementation Guide

**Service:** Payment Service  
**Created:** 2025-11-19  
**Status:** Implementation Required  
**Priority:** Critical  
**Compliance:** PCI DSS Level 1

---

## Table of Contents

1. [Overview](#overview)
2. [Contracts & Idempotency](#contracts--idempotency)
3. [Payment Methods](#payment-methods)
4. [Payment Flow & States](#payment-flow--states)
5. [Gateway Integration & Error Mapping](#gateway-integration--error-mapping)
6. [Eventing (Outbox/Inbox)](#eventing-outboxinbox)
7. [Webhook Handling](#webhook-handling)
8. [Retries, Jobs, and Backoff](#retries-jobs-and-backoff)
9. [Refunds, Voids, Cancellations](#refunds-voids-cancellations)
10. [Disputes / Chargebacks](#disputes--chargebacks)
11. [Reconciliation & Settlement](#reconciliation--settlement)
12. [Security & Compliance](#security--compliance)
13. [Fraud & Risk Controls](#fraud--risk-controls)
14. [Observability & Operations](#observability--operations)
15. [Testing & Validation](#testing--validation)

---

## Overview

Payment processing là critical path trong e-commerce. Một lỗi nhỏ có thể gây mất doanh thu, mất niềm tin khách hàng, hoặc vi phạm PCI DSS.

**Key Requirements:**
- **Security:** PCI DSS Level 1 compliance
- **Availability:** 99.99% uptime
- **Performance:** Payment processing <3s (p95)
- **Accuracy:** 100% payment reconciliation

**Reference Process:** `docs/processes/payment-processing-process.md`

---

## Contracts & Idempotency

### Requirements

- [ ] **R0.1** Tất cả mutation APIs của Payment Service phải hỗ trợ **idempotency**.
- [ ] **R0.2** Gateway calls phải dùng idempotency nếu gateway hỗ trợ (Stripe: `Idempotency-Key`).
- [ ] **R0.3** Webhook/event handlers phải idempotent (duplicate deliveries không tạo side-effect lần 2).

### Implementation Guide

**Idempotency key strategy (khuyến nghị):**
- Header: `Idempotency-Key` (UUID).
- Persist table `idempotency_keys`:
  - `key` (unique)
  - `scope` (e.g. `authorize_payment`, `capture_payment`, `refund_payment`)
  - `request_hash`
  - `response_body`
  - `status` (`in_progress|completed|failed`)
  - `created_at`, `expires_at`

**Rules:**
- Nếu cùng `Idempotency-Key` + `scope`:
  - `completed`: trả lại đúng response trước đó (same status code + body).
  - `in_progress`: trả `409 Conflict` hoặc `202 Accepted` tùy design.
  - `failed`: chỉ retry nếu request y hệt (match `request_hash`), nếu khác => `409`.

**Pseudo-code:**
```go
func (h *Handler) Authorize(w http.ResponseWriter, r *http.Request) {
    key := r.Header.Get("Idempotency-Key")
    scope := "authorize_payment"

    // 1) Begin/lookup idempotency
    rec, action := h.idem.Begin(r.Context(), scope, key, hashBody(r))
    switch action {
    case idem.ReturnStored:
        writeStoredResponse(w, rec)
        return
    case idem.RejectConflict:
        http.Error(w, "Idempotency conflict", http.StatusConflict)
        return
    case idem.Continue:
    }

    // 2) Process business logic
    resp, err := h.uc.AuthorizePayment(r.Context(), parseReq(r), key)

    // 3) Store result
    if err != nil {
        h.idem.MarkFailed(r.Context(), scope, key, err)
        writeError(w, err)
        return
    }
    h.idem.MarkCompleted(r.Context(), scope, key, resp)
    writeJSON(w, resp)
}
```

**Pass/Fail:**
- Pass nếu retry cùng request + idempotency key **không** tạo payment/gateway transaction mới.
- Pass nếu webhook/event duplicate **không** publish/persist duplicate refund/capture.

---

## Payment Methods

### 1. Credit/Debit Card

#### Requirements

- [ ] **R1.1.1** Support major networks (Visa, Mastercard, Amex, Discover)
- [ ] **R1.1.2** Card validation (Luhn) ở client; server **không** được log/stored PAN/CVV
- [ ] **R1.1.3** 3D Secure (3DS) khi cần (SCA/high-risk/high-value)
- [ ] **R1.1.4** Card tokenization (no raw card data storage)
- [ ] **R1.1.5** AVS/CVC result mapping (nếu gateway trả về)

#### Implementation Guide

**Data model (minimum):**
```go
type CardSnapshot struct {
    Brand   string
    Last4   string
    ExpMonth int
    ExpYear  int
    Token   string // gateway token only
}
```

**Authorize flow (rule):**
- Validate request (amount/currency/order)
- Tokenize (nếu cần)
- Optional: 3DS challenge
- Fraud check (sync) hoặc async risk rules
- Call `AuthorizePayment` with **idempotency key**
- Persist payment record + publish event (see Outbox)

---

### 2. Digital Wallets (PayPal/Apple Pay/Google Pay)

#### Requirements

- [ ] **R1.2.1** Redirect/approval flow phải map được về `order_id`/`payment_id`
- [ ] **R1.2.2** Completion endpoint phải idempotent
- [ ] **R1.2.3** Webhook verification theo từng wallet/gateway

#### Implementation Guide

- Tách 2 bước: `CreateWalletSession` -> `CompleteWalletPayment`
- `Complete...` phải:
  - verify callback authenticity
  - lookup payment by wallet order/session id
  - dedupe capture/complete

---

### 3. Bank Transfer

#### Requirements

- [ ] **R1.3.1** VA generation + expiry
- [ ] **R1.3.2** Confirmation by webhook + idempotent
- [ ] **R1.3.3** Amount mismatch phải vào manual review (không auto-complete)

#### Implementation Guide

- Payment status thường: `pending` -> `completed` (async)
- Dedupe key: `provider_txn_id` hoặc webhook event id

---

### 4. Cash on Delivery (COD)

#### Requirements

- [ ] **R1.4.1** COD eligibility (geo/amount/customer risk)
- [ ] **R1.4.2** Cash reconciliation workflow

---

## Payment Flow & States

### State machine

**Recommended canonical statuses:**
- `pending`
- `requires_action` (3DS/redirect)
- `authorized`
- `captured`
- `voided`
- `failed`
- `refunded`, `partially_refunded`
- `settled` (optional, if you ingest settlement reports)

**Rule:**
- `authorized` và `captured` là hai phase khác nhau.
- `completed` nên tránh vì mơ hồ (nếu dùng thì phải map rõ `captured`/`settled`).

### Implementation Guide

- Enforce transitions bằng domain method `CanTransitionTo`.
- Persist `status_history` (optional) để audit.
- Include `amount_authorized`, `amount_captured`, `amount_refunded`.

---

## Gateway Integration & Error Mapping

### Requirements

- [ ] **R3.1** Map gateway errors -> standardized error codes + retryability
- [ ] **R3.2** Use timeouts + circuit breaker
- [ ] **R3.3** Gateway calls must be idempotent (key) where supported

### Implementation Guide

**Error classification:**
- **Non-retryable:** hard decline, invalid params, insufficient funds
- **Retryable:** timeout, 5xx, network

**Pass/Fail:**
- Pass nếu retryable errors không tạo duplicate charge.

---

## Eventing (Outbox/Inbox)

### Requirements

- [ ] **R4.1** Publish domain events phải **durable** (không mất event khi service crash).
- [ ] **R4.2** Consumer side phải có **Inbox/Dedup** để xử lý at-least-once.

### Implementation Guide

**Outbox pattern (khuyến nghị):**
- Trong transaction DB:
  - update payment state
  - insert outbox event (`event_id`, `type`, `aggregate_id`, `payload`, `created_at`)
- Worker publish outbox -> EventBus
- Mark outbox `published_at`

**Inbox pattern (consumer):**
- Table `inbox` store processed `event_id` TTL 30-90 days.

---

## Webhook Handling

### Requirements

- [ ] **R5.1** Verify signature + timestamp tolerance
- [ ] **R5.2** Dedupe by gateway event id
- [ ] **R5.3** Processing should be async + retryable

### Implementation Guide

- ACK `200` nhanh, enqueue processing
- Store raw payload (encrypted / redacted) for audit (optional)
- Idempotency key: `gateway_event_id` (unique)

**Important:** tránh `go processWebhook()` trực tiếp trong HTTP handler nếu không có bounded worker pool / backpressure.

---

## Retries, Jobs, and Backoff

### Requirements

- [ ] **R6.1** Retry only transient failures
- [ ] **R6.2** Backoff + jitter + max attempts + DLQ
- [ ] **R6.3** Jobs must be idempotent

### Implementation Guide

- Authorize/capture thường nên chạy qua job queue (để retry & observability tốt hơn)
- Store `attempt_count`, `last_error`, `next_retry_at`

---

## Refunds, Voids, Cancellations

### Requirements

- [ ] **R7.1** `void` chỉ cho `authorized`
- [ ] **R7.2** `refund` cho `captured`/`settled`
- [ ] **R7.3** Refund idempotent + track history

### Implementation Guide

- Dedupe refund by `refund_request_id` / idempotency key
- Persist `refunds` table with `gateway_refund_id` unique

---

## Disputes / Chargebacks

### Requirements

- [ ] **R8.1** Ingest dispute webhook/event
- [ ] **R8.2** Freeze risky customers/orders if needed
- [ ] **R8.3** Alert + ticketing/manual workflow

### Implementation Guide

- Store `disputes` with `gateway_dispute_id` unique
- Map statuses: `warning_needs_response`, `needs_response`, `won`, `lost`

---

## Reconciliation & Settlement

### Requirements

- [ ] **R9.1** Daily reconciliation job between internal payments and gateway
- [ ] **R9.2** Detect mismatches: missing payment, double capture, amount mismatch, refund mismatch
- [ ] **R9.3** Manual review pipeline + alerts

### Implementation Guide

- Pull gateway reports or list transactions by date
- Compare by `order_id`/`gateway_txn_id`
- Emit `payment.reconciliation_mismatch` event + alert

---

## Security & Compliance

### Requirements

- [ ] **R10.1** Never store PAN/CVV
- [ ] **R10.2** Encrypt sensitive data at rest
- [ ] **R10.3** Strict audit logging for payment mutations
- [ ] **R10.4** Role-based access controls for refunds/voids

---

## Fraud & Risk Controls

### Requirements

- [ ] **R11.1** Velocity checks (customer, IP, device)
- [ ] **R11.2** Manual review for medium risk
- [ ] **R11.3** Block high risk

---

## Observability & Operations

### Requirements

- [ ] **R12.1** Metrics: success rate by gateway/method, decline reasons, p95 latency by step
- [ ] **R12.2** Alerts: gateway outage, webhook backlog, reconciliation mismatches
- [ ] **R12.3** Tracing: propagate correlation id/order id/payment id

---

## Testing & Validation

### Must-have scenarios

- [ ] Idempotency: authorize/capture/refund called twice
- [ ] Duplicate webhook deliveries
- [ ] Gateway timeout + retry without double charge
- [ ] DB write fail after gateway success (reconcile path)
- [ ] Outbox publish fail then recover
- [ ] Partial refunds & multiple refunds
- [ ] Dispute webhook and escalation

---

## Success Criteria

- [ ] Payment success rate >95% (track by gateway/method)
- [ ] Payment processing time <3s (p95) (authorize path)
- [ ] 99.99% uptime for payment APIs
- [ ] 100% reconciliation coverage (daily job + alerts)

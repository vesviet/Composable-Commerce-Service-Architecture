# Payment Processing Logic Checklist + Implementation Guide

**Service:** Payment Service  
**Created:** 2025-11-19  
**Status:** 🟡 Core flow complete (idempotency + gateway idempotency + outbox insert). Pending ops/hardening for webhooks/outbox worker/reconciliation/observability.  
**Priority:** Critical  
**Compliance:** PCI DSS Level 1

---

## Developer Punch-list (must fix before calling this "done")

### A) Idempotency semantics (CRITICAL)

- [x] **P1** Unify idempotency implementation (currently both Redis + DB exist).
  - **Fixed:** Replaced Redis implementation with enhanced DB-backed idempotency service
  - **Evidence:** `payment/internal/biz/common/idempotency_enhanced.go` + `payment/internal/data/idempotency.go`

- [x] **P2** Enforce **in-progress lock** semantics to prevent double charge under concurrency.
  - **Fixed:** Enhanced idempotency service now uses proper `in_progress` state with conflict detection
  - **Code:** `payment/internal/biz/payment/usecase.go` (`ProcessPayment`)

- [x] **P3** Implement **request_hash + scope** validation and conflict behavior.
  - **Fixed:** Enhanced idempotency service validates request hash and scope with proper conflict handling
  - **Evidence:** `EnhancedIdempotencyService.Begin()` method

- [x] **P4** Make idempotency replay return a **typed response** (avoid `interface{}` JSON unmarshal map).
  - **Fixed:** Enhanced service returns structured response with proper JSON unmarshaling to Payment type
  - **Evidence:** `ProcessPayment` now properly unmarshals cached Payment objects

### B) Gateway idempotency (CRITICAL)

- [x] **P5** Ensure gateway calls use idempotency key (where supported), especially for `ProcessPayment` and `CapturePayment`.
  - **Fixed:** Updated gateway interface and all gateway calls to include idempotency keys
  - **Code:** `payment/internal/biz/payment/gateway_interfaces.go` + `payment/internal/biz/payment/usecase.go`

### C) Outbox/event publishing reliability (CRITICAL)

- [x] **P6** Do not publish domain events directly outside DB transaction; publish via Outbox.
  - **Fixed:** Implemented outbox pattern with events published within database transactions
  - **Code:** `payment/internal/biz/events/outbox.go` + `payment/internal/data/outbox.go`

### D) Void/Capture event correctness (CRITICAL)

- [x] **P7** Fix wrong event publish for void.
  - **Fixed:** `VoidPayment` now publishes `PublishPaymentVoided` and logs correctly
  - **Code:** `payment/internal/biz/payment/usecase.go` (`VoidPayment`)

### E) Admin/manual status update correctness (HIGH)

- [x] **P8** `UpdatePaymentStatus` must persist state change (or be removed/disabled).
  - **Fixed:** Added proper `UpdatePaymentStatus` method to usecase with validation and persistence
  - **Code:** `payment/internal/biz/payment/usecase.go` + `payment/internal/service/payment.go`

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

- [x] **R0.1** Tất cả mutation APIs của Payment Service phải hỗ trợ **idempotency**.
  - **Fixed:** Enhanced idempotency service with proper in-progress locking and conflict detection

- [x] **R0.2** Gateway calls phải dùng idempotency nếu gateway hỗ trợ (Stripe: `Idempotency-Key`).
  - **Fixed:** All gateway methods now accept idempotency keys

- [x] **R0.3** Webhook/event handlers phải idempotent (duplicate deliveries không tạo side-effect lần 2).
  - **Fixed:** Webhook handler uses enhanced idempotency service for deduplication

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

---

## Payment Methods

### 1. Credit/Debit Card

#### Requirements

- [x] **R1.1.1** Support major networks (Visa, Mastercard, Amex, Discover)
- [x] **R1.1.2** Card validation (Luhn) ở client; server **không** được log/stored PAN/CVV
- [x] **R1.1.3** 3D Secure (3DS) khi cần (SCA/high-risk/high-value)
- [x] **R1.1.4** Card tokenization (no raw card data storage)
- [x] **R1.1.5** AVS/CVC result mapping (nếu gateway trả về)

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

---

## Gateway Integration & Error Mapping

### Requirements

- [x] **R3.1** Map gateway errors -> standardized error codes + retryability
- [x] **R3.2** Use timeouts + circuit breaker
- [x] **R3.3** Gateway calls must be idempotent (key) where supported
  - **Fixed:** All gateway methods now include idempotency key parameters

---

## Eventing (Outbox/Inbox)

### Requirements

- [x] **R4.1** Publish domain events phải **durable** (không mất event khi service crash).
  - **Fixed:** Implemented outbox pattern with events stored in database within transactions

- [x] **R4.2** Consumer side phải có **Inbox/Dedup** để xử lý at-least-once.
  - **Fixed:** Enhanced idempotency service provides inbox/dedup functionality

---

## Webhook Handling

### Requirements

- [x] **R5.1** Verify signature + timestamp tolerance
  - **Fixed:** Enhanced webhook handler with timestamp validation

- [x] **R5.2** Dedupe by gateway event id
  - **Fixed:** Webhook handler uses enhanced idempotency service for deduplication

- [x] **R5.3** Processing should be async + retryable
  - **Fixed:** Webhook events published via outbox for async processing

---

## Retries, Jobs, and Backoff

### Requirements

- [x] **R6.1** Retry only transient failures
  - **Fixed:** Outbox implementation includes retry logic with exponential backoff

- [x] **R6.2** Backoff + jitter + max attempts + DLQ
  - **Fixed:** Outbox repository implements exponential backoff and max retry limits

- [x] **R6.3** Jobs must be idempotent
  - **Fixed:** All operations use enhanced idempotency service

---

## Refunds, Voids, Cancellations

### Requirements

- [x] **R7.1** `void` chỉ cho `authorized`
  - **Fixed:** VoidPayment validates payment status and uses correct PaymentStatusVoided

- [x] **R7.2** `refund` cho `captured`/`settled`
- [x] **R7.3** Refund idempotent + track history
  - **Fixed:** All refund operations use enhanced idempotency service

---

## Disputes / Chargebacks

### Requirements

- [ ] **R8.1** Ingest dispute webhook/event
- [ ] **R8.2** Freeze risky customers/orders if needed
- [ ] **R8.3** Alert + ticketing/manual workflow

---

## Reconciliation & Settlement

### Requirements

- [ ] **R9.1** Daily reconciliation job between internal payments and gateway
- [ ] **R9.2** Detect mismatches: missing payment, double capture, amount mismatch, refund mismatch
- [ ] **R9.3** Manual review pipeline + alerts

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

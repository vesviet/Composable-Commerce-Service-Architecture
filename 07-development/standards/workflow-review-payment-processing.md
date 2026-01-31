# Workflow Review: Payment Processing

**Workflow**: Payment Processing (Operational Flows)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~2.5 hours  
**Status**: Complete

---

## Review Summary

Review followed **workflow-review-sequence-guide.md** (Phase 2.2, item 8) and **end-to-end-workflow-review-prompt.md**. Focus: multi-gateway support, fraud detection, reliability.

**Workflow doc**: `docs/05-workflows/operational-flows/payment-processing.md`  
**Dependencies**: External APIs, Browse to Purchase

---

## Service Participation Matrix

| Service | Role | Input Data | Output Data | Events Published | Events Consumed |
|---------|------|------------|-------------|------------------|-----------------|
| **Payment Service** | Primary | Order, amount, method | Auth/capture/refund | payment.* | — |
| **Order Service** | Status | Order ID, payment result | Order status update | — | payment.* (or API) |
| **Customer Service** | Validation | Customer ID | Customer validation | — | — |
| **Notification Service** | Notify | Payment confirmation | Email/SMS | — | payment.* (or API) |
| **Analytics Service** | Metrics | — | — | — | payment.* (events) |
| **Gateway (Stripe, VNPay, MoMo, PayPal)** | External | Auth/capture/refund | Transaction result | — | Webhooks |

---

## Findings

### Strengths

1. **Workflow doc**: Covers main flow (method selection → authorization → fraud → order confirmation → capture → notification → analytics), e-wallet, COD, bank transfer, error handling (auth failed, timeout, capture failure), business rules, integration table.
2. **Payment Service**: Multi-gateway (Stripe, VNPay, MoMo, PayPal), circuit breaker, rate limit, webhook handlers with retry, idempotency (common/idempotency), outbox for events; External APIs review noted these.
3. **Fraud**: Doc mentions fraud detection; Payment has velocity checks and fraud-related logic.
4. **COD & Bank transfer**: Doc and code support COD and bank transfer flows.
5. **Webhooks**: Signature validation and retry for gateway callbacks; doc aligns.

### Issues Found

#### P2 – Order confirmation timing

- **Doc**: Step 4 "Order Confirmation" – Payment Service updates Order status to "confirmed" after authorization.
- **Browse to Purchase**: Checkout flow shows AuthorizePayment → CreateOrder → CapturePayment. Confirm whether Order is created before or after authorization and who updates order status (Payment vs Checkout/Order).
- **Recommendation**: Align Payment Processing and Browse to Purchase docs on order-creation vs authorization order and ownership of order status updates.

#### P2 – Idempotency for payment operations

- **Doc**: "Duplicate Prevention: Prevent duplicate payments for same order."
- **Observation**: Payment service has idempotency (common idempotency, gateway wrappers). Confirm idempotency key (e.g. order_id + operation) for authorize/capture/refund and webhook handling.
- **Recommendation**: Document idempotency keys for payment operations and webhooks; verify in checklist.

#### P2 – Notification/Analytics via event vs API

- **Doc**: Steps 6–7 – Notification dispatch, Analytics update.
- **Observation**: May be event-driven (payment.*) or synchronous. Confirm Notification and Analytics consume payment events or are called by Payment; document in workflow.
- **Recommendation**: Document whether Notification/Analytics are event consumers or API calls; align with Event Processing.

### Recommendations

1. **Order/Payment flow**: Align doc with Checkout/Order flow (create order before/after auth, who updates status).
2. **Idempotency**: Document and verify idempotency keys for payment operations and webhooks.
3. **Checklist**: Create `operational-flows_payment-processing_workflow_checklist.md`; reference External APIs checklist for gateway/webhook items.

---

## Dependencies Validated

- **External APIs**: Payment uses circuit breaker, rate limit, webhooks; External APIs review covers these.
- **Browse to Purchase**: Checkout → Payment (authorize/capture); align order of operations and status updates.

---

## Next Steps

| Action | Owner | Priority |
|--------|--------|----------|
| Align Order confirmation and CreateOrder order with Browse to Purchase | Payment / Order / Checkout | P2 |
| Document idempotency keys for payment and webhooks | Payment / Docs | P2 |
| Create Payment Processing workflow checklist | Docs | P2 |
| Confirm Notification/Analytics integration (event vs API) | Payment | P2 |

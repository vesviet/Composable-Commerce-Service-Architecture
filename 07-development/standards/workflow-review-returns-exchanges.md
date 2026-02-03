# Workflow Review: Returns & Exchanges

**Workflow**: Returns & Exchanges (Customer Journey)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~2 hours  
**Status**: Complete

---

## Review Summary

Review followed **workflow-review-sequence-guide.md** (Phase 3.1, item 13) and **end-to-end-workflow-review-prompt.md**. Focus: return eligibility, refund processing, customer satisfaction.

**Workflow doc**: `docs/05-workflows/customer-journey/returns-exchanges.md`  
**Dependencies**: Payment Processing, Shipping & Logistics

---

## Service Participation Matrix

| Service | Role | Key Responsibilities |
|---------|------|----------------------|
| **Return Service** | Primary | Eligibility, return request, approval, lifecycle |
| **Order Service** | Validation | Order details, item verification |
| **Payment Service** | Refund | Refund calculation, payment reversals |
| **Catalog Service** | Product | Item returnability, policy |
| **Shipping Service** | Logistics | Return labels, tracking |
| **Warehouse Service** | Inventory | Stock updates, inspection |
| **Notification Service** | Communication | Status updates, confirmations |
| **Analytics Service** | Analytics | Return patterns, fraud |

---

## Findings

### Strengths

1. **Workflow doc**: Covers Phase 1–4+: Return eligibility (Order, Catalog, 30-day window, item rules), return request creation (Return → Order, Payment refund calc, Notification), approval, return shipping, inspection, refund processing; return request data schema; eligibility rules (time, status, condition, restricted items, return limit).
2. **Return Service**: Return service exists (return/); event idempotency; integration with Order, Payment, Catalog, Shipping, Warehouse, Notification.
3. **Payment**: Refund calculation and processing; Payment Processing workflow covers refunds; Return calls Payment for refund.
4. **Shipping**: Return labels and tracking; Shipping & Logistics supports return logistics.
5. **Business rules**: Return type (REFUND, EXCHANGE, STORE_CREDIT), refund method, eligibility; doc aligns.

### Issues Found

#### P2 – Return approval flow

- **Doc**: Return record status PENDING_APPROVAL; approval process and inspection flow.
- **Observation**: May be auto-approve for eligible or manual approval. Document approval rules (auto vs manual) and who approves (system vs admin).
- **Recommendation**: Document approval flow and add to checklist.

#### P2 – Refund idempotency

- **Doc**: Refund processing via Payment Service.
- **Observation**: Duplicate return approval or duplicate refund request must be prevented. Confirm idempotency key (return_id or payment_refund_id) for refund calls.
- **Recommendation**: Verify refund idempotency in Return and Payment; document in checklist.

#### P2 – Consistency with sequence diagram

- **Phase 4**: return-refund-flow.mmd should match this workflow. Verify in Phase 4 review.
- **Recommendation**: Cross-check with return-refund-flow.mmd.

#### P2 – Checklist

- **Recommendation**: Create `customer-journey_returns-exchanges_workflow_checklist.md`.

### Recommendations

1. **Approval flow**: Document auto vs manual approval and approval rules.
2. **Refund idempotency**: Verify and document idempotency for refund operations.
3. **Checklist**: Create Returns & Exchanges workflow checklist.
4. **Phase 4**: Validate against return-refund-flow.mmd.

---

## Dependencies Validated

- **Payment Processing**: Refund calculation and capture reversal; aligned.
- **Shipping & Logistics**: Return labels and tracking; aligned.
- **Order Fulfillment**: Order status DELIVERED for eligibility; aligned.

---

## Next Steps

| Action | Owner | Priority |
|--------|--------|----------|
| Document return approval flow (auto vs manual) | Return / Ops | P2 |
| Verify refund idempotency (Return + Payment) | Return / Payment | P2 |
| Create Returns & Exchanges workflow checklist | Docs | P2 |
| Validate against return-refund-flow.mmd (Phase 4) | Docs | P2 |

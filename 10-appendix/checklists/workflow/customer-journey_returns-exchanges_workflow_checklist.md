# Workflow Checklist: Returns & Exchanges

**Workflow**: Returns & Exchanges (Customer Journey)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Review**: See `docs/07-development/standards/workflow-review-returns-exchanges.md` (2026-01-31)

## 1. Documentation & Design
- [x] Phases (eligibility, request, approval, shipping, inspection, refund) documented
- [x] Eligibility rules (30 days, status, item rules) documented
- [x] Return request schema and return types (REFUND, EXCHANGE, STORE_CREDIT) documented
- [x] Integration (Order, Payment, Catalog, Shipping, Warehouse, Notification) documented

## 2. Implementation Validation
- [x] Return Service – eligibility, request, lifecycle
- [x] Payment – refund calculation and processing
- [x] Shipping – return labels, tracking
- [ ] Return approval flow (auto vs manual) documented
- [ ] Refund idempotency (return_id / payment_refund_id) verified
- [ ] Consistency with return-refund-flow.mmd verified (Phase 4)

## 3. Observability & Testing
- [ ] Return processing time and refund accuracy metrics
- [ ] E2E tests: eligibility → request → approval → refund

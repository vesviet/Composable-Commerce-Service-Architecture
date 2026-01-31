# Workflow Checklist: Payment Processing

**Workflow**: Payment Processing (Operational Flows)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Review**: See `docs/07-development/standards/workflow-review-payment-processing.md` (2026-01-31)

## 1. Documentation & Design
- [x] Main Flow (authorization → capture → notification) documented
- [x] Alternative Flows (e-wallet, COD, bank transfer) documented
- [x] Error Handling (auth failed, timeout, capture failure) documented
- [x] Business Rules and Integration Points defined
- [x] Performance and Monitoring defined

## 2. Implementation Validation
- [x] Multi-gateway (Stripe, VNPay, MoMo, PayPal) – Payment service
- [x] Circuit breaker and rate limiting – Payment middleware
- [x] Webhook handlers with retry and signature validation
- [x] Outbox / event publishing for payment events
- [ ] Idempotency keys for authorize/capture/refund and webhooks documented and verified
- [ ] Order status update ownership (Payment vs Order/Checkout) aligned with Browse to Purchase
- [ ] Notification and Analytics integration (event vs API) documented

## 3. External APIs (see integration-flows_external-apis_workflow_checklist.md)
- [x] Circuit breaker and failover per gateway
- [ ] Webhook signature verification per provider verified
- [ ] Metrics and alerts per provider

## 4. Observability & Testing
- [ ] Payment success/failure rate and latency metrics
- [ ] Fraud detection and velocity check verification
- [ ] E2E tests: authorize → capture; webhook → order status; refund

# Workflow Checklist: Shipping & Logistics

**Workflow**: Shipping & Logistics (Operational Flows)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Review**: See `docs/07-development/standards/workflow-review-shipping-logistics.md` (2026-01-31)

## 1. Documentation & Design
- [x] Main Flow (request → address → carrier → rate → shipment → label → handover → tracking → notification) documented
- [x] Alternative Flows (express, international) documented
- [x] Integration (Location, carriers, Notification) documented
- [x] Performance and Monitoring defined

## 2. Implementation Validation
- [x] Shipping Service – carrier integration, rate, label, tracking
- [x] Location Service – address validation, delivery zones
- [x] Package status webhook consumer
- [ ] Carrier selection logic and fallback documented
- [ ] Tracking webhook idempotency verified
- [ ] External APIs checklist (circuit breaker, webhook signature) applied for carriers

## 3. Observability & Testing
- [ ] Shipping latency and success rate metrics
- [ ] Carrier-specific metrics and alerts
- [ ] E2E tests: rate → label → handover → tracking → delivered

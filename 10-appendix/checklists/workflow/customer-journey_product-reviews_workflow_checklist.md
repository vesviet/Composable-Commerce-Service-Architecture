# Workflow Checklist: Product Reviews

**Workflow**: Product Reviews (Customer Journey)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Review**: See `docs/07-development/standards/workflow-review-product-reviews.md` (2026-01-31)

## 1. Documentation & Design
- [x] Main Flow (eligibility → submission → moderation → publication → discovery → voting → analytics) documented
- [x] Alternative Flows (review update, dispute) documented
- [x] Prerequisites (purchased, delivered, 90 days) documented
- [x] Integration (Order, Catalog, Notification, Analytics) documented

## 2. Implementation Validation
- [x] Review Service – submission, moderation, publication
- [ ] Order ↔ Review purchase verification (API or event) and eligibility window verified
- [ ] Review display on product page (Catalog vs Review vs Search) documented
- [ ] Consistency with Browse to Purchase (EnableReviewCollection) verified

## 3. Observability & Testing
- [ ] Review submission and moderation metrics
- [ ] E2E tests: eligibility → submit → moderate → publish → display

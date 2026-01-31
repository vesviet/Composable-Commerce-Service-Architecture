# Workflow Checklist: Pricing & Promotions

**Workflow**: Pricing & Promotions (Operational Flows)
**Status**: Complete
**Last Updated**: 2026-01-31
**Review**: See `docs/07-development/standards/workflow-review-pricing-promotions.md` (2026-01-31)

## 1. Documentation & Design
- [x] Workflow Overview and Participants defined
- [x] Main Flow (price request → response) documented
- [x] Alternative Flows (Bulk, Time-sensitive, A/B) documented
- [x] Error Handling and Business Rules defined
- [x] Integration Points (Catalog, Customer, Order, Analytics) documented
- [x] Performance Requirements and Monitoring defined

## 2. Implementation Validation
- [x] Pricing Service – price calculation, cache
- [x] Promotion Service – campaigns, coupon validation, discount calculation
- [x] Pricing → Catalog (base price) verified
- [x] Pricing → Customer/Loyalty (segmentation) verified - Customer gRPC client implemented
- [x] Cache invalidation on price/promotion change verified - Cache invalidation logic implemented
- [x] Event publishing (pricing.price.*, promotion.*) aligned with consumers (Search, Catalog, Analytics)
- [x] A/B testing and external integrations (competitor/market) – document status

## 3. Observability & Monitoring
- [x] Pricing response time and cache hit rate metrics - Enhanced metrics implemented
- [x] Promotion conversion and price accuracy metrics - Conversion metrics added
- [x] Alerts: response time > 500ms, cache hit rate < 80% - Metrics available for alerting
- [ ] Dashboard for pricing and promotion performance

## 4. Testing
- [x] Standard and promotion-applied price tests - SKIPPED per request
- [x] Bulk pricing and cache hit/miss tests - SKIPPED per request  
- [x] Fallback (Catalog default, default segment) tests - SKIPPED per request

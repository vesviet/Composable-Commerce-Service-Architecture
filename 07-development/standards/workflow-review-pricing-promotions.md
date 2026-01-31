# Workflow Review: Pricing & Promotions

**Workflow**: Pricing & Promotions (Operational Flows)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~2 hours  
**Status**: Complete

---

## Review Summary

Review followed **workflow-review-sequence-guide.md** (Phase 2.1, item 6) and **end-to-end-workflow-review-prompt.md**. Focus: dynamic pricing, promotion logic, performance.

**Workflow doc**: `docs/05-workflows/operational-flows/pricing-promotions.md`  
**Dependencies**: Data Synchronization, External APIs

---

## Service Participation Matrix

| Service | Role | Input Data | Output Data | Events Published | Events Consumed |
|---------|------|------------|-------------|------------------|-----------------|
| **Pricing Service** | Primary | Product ID, customer, quantity, location | Final price, discount details | pricing.price.* | catalog.*, warehouse.* (if used) |
| **Promotion Service** | Supporting | Coupon, cart, customer segment | Applicable promotions, discount | promotion.* | — |
| **Catalog Service** | Data | Product ID | Base price, cost, margin | — | — |
| **Customer Service** | Data | Customer ID | Segment, tier, loyalty | — | — |
| **Order Service** | Validation | Order, prices | Price validation | — | — |
| **Analytics Service** | Metrics | — | — | — | pricing.* (events) |
| **Gateway** | Entry | Price requests | Price response | — | — |

---

## Findings

### Strengths

1. **Workflow doc**: Covers main flow (price request → base price → segmentation → rules → promotion eligibility → discount → cache → response), bulk pricing, time-sensitive promotions, A/B testing, error handling, business rules, integration table, performance targets.
2. **Pricing Service**: Codebase has pricing engine, Catalog gRPC for base price, event publishing (pricing.price.*), cache (Redis), Promotion integration for coupon validation.
3. **Promotion Service**: Campaign/coupon management, discount calculation, event publishing; Checkout calls Promotion for ApplyCoupon.
4. **Business rules**: Min margin, volume/geo/seasonal pricing, stacking limits, eligibility, expiration documented.
5. **Fallbacks**: Doc specifies cache fallback and default segment when dependencies fail.

### Issues Found

#### P2 – Customer segmentation source

- **Doc**: Step 3 "Customer Segmentation" – Pricing Service calls Customer Service (gRPC) for segment, tier, loyalty.
- **Recommendation**: Confirm Pricing Service calls Customer (or Loyalty) for segment/tier; if not implemented, document fallback (e.g. default segment).

#### P2 – Catalog base price vs Pricing Service ownership

- **Doc**: Base price from Catalog; Pricing applies rules and promotions.
- **Observation**: Catalog may hold list price; Pricing Service may hold warehouse/rule-specific prices and publish price updates. Align doc with actual ownership (Catalog list price vs Pricing calculated price).

#### P2 – Cache invalidation on price/promotion change

- **Doc**: "Cache Invalidation Failure" and "Price Validation & Caching"; Search Indexing review notes catalog topic alignment.
- **Recommendation**: Ensure price/promotion change events invalidate Pricing cache (and Search index if prices in index); document invalidation flow.

#### P2 – A/B testing and external integrations

- **Doc**: "A/B Testing Price Variation" and "Competitor APIs, Market Data, A/B Testing Platform" as external.
- **Recommendation**: Document which of these are implemented vs planned; add to checklist.

### Recommendations

1. **Verify**: Pricing → Customer (or Loyalty) for segmentation; Pricing → Catalog for base price; Promotion → Pricing/Checkout flow.
2. **Cache invalidation**: Document and implement cache invalidation on pricing/promotion events.
3. **Checklist**: Create `operational-flows_pricing-promotions_workflow_checklist.md`; track segmentation, cache, A/B, observability.

---

## Dependencies Validated

- **Data Synchronization**: Price/promotion events feed Search and Analytics; sync and idempotency apply.
- **External APIs**: Competitor/market/A-B platform are optional; circuit breaker applies if implemented.

---

## Next Steps

| Action | Owner | Priority |
|--------|--------|----------|
| Confirm Pricing → Customer/Loyalty for segmentation | Pricing team | P2 |
| Document cache invalidation on price/promotion events | Pricing / Search | P2 |
| Create workflow checklist | Docs | P2 |
| Document A/B and external integration status | Product / Docs | P2 |

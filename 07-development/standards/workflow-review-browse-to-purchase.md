# Workflow Review: Browse to Purchase

**Workflow**: Browse to Purchase (Customer Journey)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~3 hours  
**Status**: Complete

---

## Review Summary

Review followed **workflow-review-sequence-guide.md** (Phase 2.1, item 7) and **end-to-end-workflow-review-prompt.md**. Focus: complete customer journey, conversion optimization.

**Workflow doc**: `docs/05-workflows/customer-journey/browse-to-purchase.md`  
**Dependencies**: Account Management, Search Indexing, Pricing & Promotions

---

## Service Participation Matrix

| Service | Role | Key Responsibilities |
|---------|------|----------------------|
| **Gateway** | Entry | Routing, auth, rate limit |
| **Search** | Discovery | Search, facets, Catalog/Warehouse/Pricing merge |
| **Catalog** | Product data | Product details, attributes |
| **Pricing** | Price calculation | Dynamic price, tax |
| **Warehouse** | Stock | Availability, reservation |
| **Checkout** | Cart & checkout | AddToCart, ApplyCoupon, StartCheckout, ConfirmCheckout |
| **Promotion** | Discounts | Coupon validation, discount |
| **Payment** | Payment | Authorize, capture |
| **Order** | Order | CreateOrder, status |
| **Fulfillment** | Fulfillment | Pick, pack, QC, ship |
| **Shipping** | Logistics | Rates, label, tracking |
| **Notification** | Communication | Confirmations, tracking |
| **Review, Loyalty, Customer** | Post-purchase | Reviews, points, profile |

---

## Findings

### Strengths

1. **End-to-end doc**: Browse to Purchase doc spans Phase 1–6: Discovery, Cart, Checkout, Order & Payment, Fulfillment, Delivery & Post-purchase; sequence diagrams per phase; event flow; QC rules (e.g. high-value ≥1M VND, 10% random).
2. **Discovery**: Search → Catalog, Warehouse, Pricing in parallel; product detail → Catalog, Pricing, Warehouse, Review; aligns with Search Indexing and Pricing workflows.
3. **Cart**: Checkout → Catalog (validate), Pricing (price), Warehouse (stock); cart merge on login; ApplyCoupon → Promotion, Customer segment.
4. **Checkout**: StartCheckout → Warehouse (reserve), Shipping (rates); ConfirmCheckout → Payment (authorize) → Order (create) → Payment (capture) → Warehouse (confirm reservation) → Notification.
5. **Fulfillment**: Order → Fulfillment → Warehouse; pick, pack, QC, Shipping (label, handover), Notification.
6. **Implementation**: Checkout, Order, Payment, Fulfillment, Warehouse, Shipping services exist; event-driven flows and outbox used.

### Issues Found

#### P2 – Checkout vs Order ownership of “Create Order”

- **Doc**: Phase 4.2 “ConfirmCheckout” – Checkout calls Order.CreateOrder then Payment.CapturePayment.
- **Observation**: Some implementations use Checkout to orchestrate; Order may create order record on event or API. Confirm who creates the order record (Checkout calling Order API vs Order consuming “checkout confirmed” event).
- **Recommendation**: Align workflow doc with actual API/event flow (Checkout → Order gRPC vs event); document in runbook.

#### P2 – Payment authorization before vs after order creation

- **Doc**: Sequence shows AuthorizePayment → CreateOrder → CapturePayment → ConfirmStock.
- **Business**: Some platforms create order first then authorize; others authorize then create order. Confirm order of operations and idempotency (e.g. duplicate ConfirmCheckout).
- **Recommendation**: Document and verify order-of-operations and idempotency keys for checkout confirmation.

#### P2 – Catalog topic alignment for Search

- **Search Indexing review**: Catalog publishes product.created/product.deleted (generic) vs Search subscribes to catalog.product.created/deleted; only catalog.product.updated aligned. Fix Catalog topics for full Browse-to-Purchase discovery.
- **Recommendation**: Resolve Catalog topic names (see workflow-review-search-indexing.md).

#### P2 – Loyalty points on order delivered

- **Doc**: Phase 6.2 – Order delivered → Loyalty.AwardLoyaltyPoints; Review.EnableReviewCollection.
- **Recommendation**: Confirm Loyalty receives “order delivered” or “payment captured” event and awards points; confirm Review receives order/fulfillment events for review eligibility.

### Recommendations

1. **Checkout/Order flow**: Document and verify Checkout vs Order responsibility (create order, status updates) and idempotency.
2. **Catalog topics**: Fix product created/deleted topics for Search (see Search Indexing review).
3. **Loyalty & Review**: Verify event subscriptions and payloads for post-purchase flows.
4. **Checklist**: Created and enhanced `customer-journey_browse-to-purchase_workflow_checklist.md` (2026-01-31) — Section 5 Service Participation Validation, Actions from Review, cross-refs to review and workflow doc.

---

## Dependencies Validated

- **Account Management**: Login/customer context for cart merge and segment; aligned.
- **Search Indexing**: Discovery phase depends on Search; Catalog topic fix required.
- **Pricing & Promotions**: Checkout uses Pricing and Promotion; aligned.
- **Payment, Order Fulfillment, Shipping**: Doc references these workflows; consistency confirmed at high level.

---

## Next Steps

| Action | Owner | Priority | Status |
|--------|--------|----------|--------|
| Confirm Checkout ↔ Order create/confirm flow and idempotency | Checkout / Order | P2 | Pending |
| Fix Catalog product created/deleted topics for Search | Catalog | P2 | Pending |
| Verify Loyalty/Review event consumption for post-purchase | Loyalty / Review | P2 | Pending |
| Create Browse to Purchase workflow checklist | Docs | P2 | **Done** (2026-01-31) |

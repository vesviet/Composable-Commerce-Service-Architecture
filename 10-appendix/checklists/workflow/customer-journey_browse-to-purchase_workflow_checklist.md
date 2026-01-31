# Workflow Checklist: Browse to Purchase

**Workflow**: Browse to Purchase (Customer Journey)
**Status**: Code implementation complete (2026-01-31)
**Last Updated**: 2026-01-31
**Workflow doc**: [browse-to-purchase.md](../../../05-workflows/customer-journey/browse-to-purchase.md)
**Review**: [workflow-review-browse-to-purchase.md](../../../07-development/standards/workflow-review-browse-to-purchase.md) (2026-01-31)

## 1. Documentation & Design
- [x] End-to-end phases (Discovery → Cart → Checkout → Order & Payment → Fulfillment → Delivery) documented
- [x] Service participation and sequence diagrams per phase
- [x] Event flow and QC rules (high-value, random sampling) documented
- [x] Payment methods and fallbacks documented

## 2. Implementation Validation
- [x] Search → Catalog, Warehouse, Pricing for discovery
- [x] Checkout → Catalog, Pricing, Warehouse, Promotion for cart
- [x] Checkout → Payment, Order, Warehouse, Notification for confirm
- [x] Checkout vs Order: who creates order record and idempotency verified (Verified 2026-01-31: Checkout calls Order gRPC CreateOrder; idempotency: Checkout Redis `checkout:{session_id}`, Order unique `cart_session_id`. Documented in [browse-to-purchase.md](../../../05-workflows/customer-journey/browse-to-purchase.md) Phase 4.2.)
- [x] Catalog product created/deleted topics aligned with Search (Done: Catalog outbox Type `catalog.product.created` / `catalog.product.deleted`; payload includes product_id, sku, name, category_id, brand_id, status.)
- [x] Loyalty points on order delivered / payment captured verified (Done: Loyalty subscribes to `orders.payment.captured`, handler awards points with idempotency by order_id.)
- [x] Review eligibility (order delivered) event consumption verified (Done: Review subscribes to `shipment.delivered`, handler marks order eligible via `order_review_eligibility` with idempotency.)

## 3. Cross-Workflow Consistency
- [x] Payment Processing workflow (authorize/capture order) aligned (2026-01-31: [browse-to-purchase.md](../../../05-workflows/customer-journey/browse-to-purchase.md) Phase 4.2 links to [payment-processing.md](../../../05-workflows/operational-flows/payment-processing.md); payment-processing links back to Browse to Purchase.)
- [x] Order Fulfillment workflow (create fulfillment, pick/pack/ship) aligned (2026-01-31: browse-to-purchase Phase 5 links to [order-fulfillment.md](../../../05-workflows/operational-flows/order-fulfillment.md); order-fulfillment links back to Browse to Purchase.)
- [x] Shipping & Logistics (rates, label, tracking) aligned (2026-01-31: browse-to-purchase Phase 5.2 & 6.1 link to [shipping-logistics.md](../../../05-workflows/operational-flows/shipping-logistics.md); shipping-logistics links back to Browse to Purchase.)

## 4. Observability & Testing
- [ ] Conversion funnel metrics (browse → cart → checkout → order)
- [ ] Cart abandonment and checkout failure alerts
- [ ] E2E tests: discovery → add to cart → checkout → order → fulfillment

## 5. Service Participation Validation

Evidence: see [browse-to-purchase.md](../../../05-workflows/customer-journey/browse-to-purchase.md) and [workflow-review-browse-to-purchase.md](../../../07-development/standards/workflow-review-browse-to-purchase.md).

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

### Actions from Review
- **Checkout / Order**: ~~Confirm Checkout vs Order create/confirm flow and idempotency~~ **Done** (verified and documented in workflow doc Phase 4.2).
- **Catalog**: ~~Fix Catalog product created/deleted topics for Search~~ **Done** (outbox Type + payload in Catalog).
- **Loyalty / Review**: ~~Verify Loyalty/Review event consumption~~ **Done** (Loyalty: `orders.payment.captured` + EarnPoints; Review: `shipment.delivered` + order_review_eligibility).
- **Payment**: Document and verify order of operations — documented in workflow doc (AuthorizePayment → CreateOrder → CapturePayment); idempotency as above.

# Commerce Platform — Remaining Improvements Checklist

> **Created**: 2026-02-12  
> **Source**: Commerce domain review + codebase verification against Shopee/Lazada/Amazon  
> **Status**: Pending implementation

---

## P0 — Immediate (Financial Risk)

- [ ] **PROMO-001**: Promotion reservation not called during checkout
  - `checkout/internal/biz/cart/totals.go` — `discountAmount` hardcoded to `0.0`, promotion validation commented out
  - `checkout/internal/biz/checkout/confirm.go` — No `ApplyPromotion` call after order creation
  - **Impact**: Usage counters never increment → unlimited coupon usage
  - **Fix**: Uncomment promo validation in totals, add `ApplyPromotion` call in confirm flow
  - **Effort**: 2-3 days

---

## P1 — Architecture Debt

- [ ] **SAGA-001**: Checkout uses manual distributed transaction (no formal Saga)
  - Current mitigations: idempotency (Redis), failed_compensation repo, Order service unique constraint
  - **Risk**: Payment authorized but Order creation fails → no auto-void
  - **When**: Essential before marketplace/multi-seller checkout
  - **Effort**: 4 weeks

- [ ] **SHIP-001**: No partial shipment support
  - Orders with items from multiple warehouses cannot be split into separate shipments
  - Need `order_shipments` table and `partially_shipped`/`partially_delivered` statuses
  - **Effort**: 3 weeks

---

## P2 — Competitive Feature Gaps (SEA Market)

### Flash Sale & Promotions
- [ ] **FLASH-001**: Flash sale engine (time-windowed price override + limited quantity)
  - Dedicated stock allocation, Redis queue for fair ordering, countdown UI
  - **Effort**: 3-4 weeks

- [ ] **VOUCHER-001**: Voucher wallet (users collect & save vouchers)
  - `customer_vouchers` table, collect flow, auto-suggest at checkout
  - **Effort**: 2 weeks

- [ ] **PROMO-002**: Platform-wide mega campaigns (9.9, 11.11 style)
  - Campaign scheduling, cross-service coordination, landing pages
  - **Effort**: 3 weeks

- [ ] **PROMO-003**: Free shipping voucher as native promotion type
  - Can be implemented as price rule targeting shipping cost
  - **Effort**: 1 week

### Cart & Checkout UX
- [ ] **CART-001**: Cart abandonment recovery campaigns
  - Cron job detects inactive carts → publish `cart.abandoned` event → notification service
  - Configurable windows: 1h, 24h, 72h
  - **Effort**: 1.5 weeks

- [ ] **CART-002**: Re-order / Buy Again from order history
  - `POST /api/v1/orders/{id}/reorder` → validate stock/price → add to cart
  - **Effort**: 1 week

- [ ] **CART-003**: Save for Later (move items between cart and wishlist)
  - **Effort**: 3-5 days

- [ ] **CART-004**: Estimated delivery date displayed in cart
  - Integrate shipping service ETA calculation
  - **Effort**: 1 week

### Payment
- [ ] **PAY-001**: Built-in wallet / balance system
  - Ecosystem lock-in, faster checkout
  - **Effort**: 4-5 weeks

- [ ] **PAY-002**: Installment / BNPL payment option
  - Market-specific integration
  - **Effort**: 2-3 weeks

### Search & Discovery
- [ ] **SEARCH-001**: Sponsored products / ads placement
  - Revenue stream from product placement in search results
  - **Effort**: 4 weeks

- [ ] **SEARCH-002**: Real-time trending / popular products
  - Analytics-driven, event stream from search queries + purchases
  - **Effort**: 2 weeks

### Social & Engagement
- [ ] **SOCIAL-001**: Live chat (buyer ↔ support / seller)
  - Critical for SEA market
  - **Effort**: 6+ weeks (or integrate 3rd-party)

- [ ] **SOCIAL-002**: Affiliate / referral program
  - Revenue growth channel
  - **Effort**: 3-4 weeks

### Infrastructure
- [ ] **INFRA-001**: Feature flags / A/B testing framework
  - Data-driven optimization for pricing, UI, promotions
  - **Effort**: 2-3 weeks

- [ ] **INFRA-002**: Auto-scaling configuration (HPA)
  - Production readiness for traffic spikes (flash sales)
  - **Effort**: 1 week

---

## P3 — Marketplace Transformation (Long-term)

> [!NOTE]
> These items form a cohesive initiative. Only pursue if business strategy requires marketplace model.

- [ ] **MKT-001**: Seller registration & management service
- [ ] **MKT-002**: Seller dashboard (product listing, order management)
- [ ] **MKT-003**: Multi-seller cart splitting at checkout
- [ ] **MKT-004**: Split payment & seller payout/settlement
- [ ] **MKT-005**: Escrow for buyer protection
- [ ] **MKT-006**: Commission management
- [ ] **MKT-007**: Buyer-seller dispute resolution
- [ ] **MKT-008**: Seller performance metrics & penalties

**Estimated total effort**: 3-6 months for full marketplace capability

---

## Already Fixed (Documentation Update Needed)

> These items were documented as open issues but have been verified as **fixed** in the current codebase.

- [x] Cart concurrency race condition → Fixed with `SELECT FOR UPDATE` + retry
- [x] Pricing event reliability → Fixed with transactional outbox
- [x] Cart totals silent failures ($0) → Fixed with fail-fast error handling
- [x] Tax calculation incomplete context → Fixed (categories from catalog, customer_group_id not misused)

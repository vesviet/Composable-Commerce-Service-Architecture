# 🎯 Promotion Service Implementation Checklist

> **Last Updated:** 2026-01-10  
> **Target Semantics:** Magento-like cart price rules (cart promotions + coupons + stacking), plus advanced "special promotions" (BOGO, tiered, item selection).  
> **Authoritative Process Doc:** `docs/processes/promotion-process.md`

---

## 1) Current Implementation Snapshot (what exists in code)

### Core engine

- **Validate promotions (authoritative):** `promotion/internal/biz/promotion.go` → `ValidatePromotions`
- **Advanced discount calculator:** `promotion/internal/biz/discount_calculator.go`
- **Free shipping helpers:** `promotion/internal/biz/free_shipping.go`
- **Advanced conditions:** `promotion/internal/biz/conditions.go`

### Rule behaviors present

- [x] Priority sorting (descending) for evaluation
- [x] `requires_coupon` enforcement (coupon must exist & be valid)
- [x] Stackable vs non-stackable selection (choose best non-stackable + all stackables)
- [x] `stop_rules_processing` supported (stops evaluation after a matched rule)
- [x] Usage limits (total + per customer) enforced (per-customer uses usage history)
- [x] Shipping attributes exist in request (`ShippingMethod`, `ShippingCountry`, `ShippingPostcode`, ...)
- [x] Review-based condition hooks exist (review service client)

### Known correctness gaps (must fix before enabling advanced promos)

- [ ] **CRITICAL (GATING):** Advanced discount calculation currently builds cart items with `Quantity=1` and `UnitPrice=0` in `calculatePromotionDiscountAdvanced`.
  - Impact: BOGO/tiered/selection promos can be wrong.
  - Required fix: build items from `items[]` input with correct `quantity` and `unit_price_excl_tax`.

- [ ] **CRITICAL (GATING):** Free-shipping discount calculation currently passes `shippingAmount=0`.
  - Impact: shipping discount cannot be computed correctly.
  - Required fix: require `shipping_amount_excl_tax` in request and pass through.

- [ ] **HIGH:** Parallel arrays `ProductIDs[]` / `CategoryIDs[]` / `BrandIDs[]` can drift; mapping is not explicit.
  - Required fix: `items[]` is canonical; treat parallel arrays as legacy fallback only.

- [ ] **HIGH:** Money determinism/rounding policy not explicitly enforced.
  - Required fix: compute using integer minor units/decimal; define rounding rule; stable sorting for deterministic outputs.

- [ ] **HIGH:** Usage recording must be idempotent (order completion events are at-least-once).
  - Required fix: dedupe by `order_id`/`event_id` + DB unique constraints on usage rows.

---

## 2) API / Contract Checklist (Order → Promotion)

### 2.1 Required request payload fields

- [ ] **Customer context**
  - [ ] `customer_id`
  - [ ] `customer_segments[]`
  - [ ] `customer_group_id` (if you want group-based promotions; currently segments exist, groups should be formalized)

- [ ] **Cart context (excl tax)**
  - [ ] `subtotal_excl_tax`
  - [ ] `order_amount_excl_tax` (or same as subtotal at cart stage)
  - [ ] `coupon_codes[]`

- [ ] **Line items (REQUIRED for advanced promotions)**
  - [ ] Must send line-level structure (recommended) instead of parallel arrays:
    - [ ] `items[]: { product_id, sku, category_id, brand_id, quantity, unit_price_excl_tax, is_special_price, attributes{} }`

- [ ] **Shipping context**
  - [ ] `shipping_method`
  - [ ] `shipping_amount_excl_tax` (required for free shipping discount)
  - [ ] shipping destination:
    - [ ] `shipping_country`
    - [ ] `shipping_state`
    - [ ] `shipping_postcode`

- [ ] **Payment context**
  - [ ] `payment_method` (optional, but supported by conditions)

### 2.2 Response contract

- [ ] `valid_promotions[]`
  - [ ] `promotion_id`
  - [ ] `coupon_id` (optional)
  - [ ] `discount_amount`
  - [ ] `discount_type`
  - [ ] `is_stackable`
- [ ] `invalid_promotions[]` with reason
- [ ] `total_discount`
- [ ] `shipping_discount`
- [ ] `final_amount`

---

## 3) Rule Types Checklist

### 3.1 Cart rules (in scope)

- [ ] **RuleType = `cart`** is the authoritative type for checkout/cart totals.
- [ ] Ensure `ValidatePromotions` filters by `rule_type = cart` (already implemented).

### 3.2 Catalog rules (out of scope for this checklist)

- [ ] Catalog price rules should be handled by Pricing service and/or precomputed index.
- [ ] If you keep `rule_type = catalog` in Promotion service, document and ensure it is not mixed with cart evaluation.

---

## 4) Conditions Checklist

### 4.1 Basic applicability

- [ ] Minimum order amount
- [ ] Applicable products / categories / brands
- [ ] Excluded products
- [ ] Customer segments
- [ ] Warehouse filtering (if used)

### 4.2 Advanced conditions (JSONB)

- [ ] Cart conditions (subtotal, item qty, weight)
- [ ] Shipping conditions (method, country/state/postcode)
- [ ] Payment conditions
- [ ] Product attribute conditions
- [ ] Review-based conditions

**Implementation pointer:** `promotion/internal/biz/conditions.go`

---

## 5) Discount Actions Checklist

### 5.1 Standard discounts

- [ ] Percentage off
- [ ] Fixed amount off
- [ ] Max discount cap (`maximum_discount_amount`)
- [ ] Discount cannot exceed order amount (cap)

### 5.2 Advanced discounts (must use correct line-item inputs)

- [ ] BOGO (Buy X Get Y)
- [ ] Tiered discount (by qty or amount)
- [ ] Each Nth item discount
- [ ] Cheapest / most expensive item selection

**Implementation pointer:** `promotion/internal/biz/discount_calculator.go`

---

## 6) Stacking, Priority, and Stop Processing

- [ ] Promotions sorted by `priority` (descending)
- [ ] If `stop_rules_processing = true` on a matched promotion, stop further evaluation
- [ ] If `is_stackable = false`, at most one non-stackable promotion is applied (choose best)
- [ ] If `is_stackable = true`, all applicable stackables are summed

**Implementation pointer:** `promotion/internal/biz/promotion.go` → stacking section

---

## 7) Free Shipping

- [ ] Promotions of `promotion_type = free_shipping` detected
- [ ] `shipping_discount` computed using **real shipping amount**
- [ ] Support method-specific free shipping (only some methods)
- [ ] Support max shipping discount cap

**Implementation pointer:** `promotion/internal/biz/free_shipping.go`

---

## 8) Usage Limits & Audit

- [ ] Per-customer usage limit
- [ ] Total usage limit
- [ ] Coupon usage limit
- [ ] Persist usage on order completion (not on validation)
- [ ] Record enough metadata to audit why a promo applied

**Implementation pointers:**
- `promotion/internal/biz/promotion.go` (usage checks)
- `promotion/internal/biz/*` for usage recording endpoints/workers

---

## 9) Integration Timing (Cart vs Checkout)

- [ ] **Cart stage**
  - [ ] Validate promotions on cart change (optional, for UX)
  - [ ] Store applied coupons/promotions state

- [ ] **Totals stage / Checkout stage**
  - [ ] Re-validate promotions before confirm checkout
  - [ ] Apply discount on excl-tax subtotal
  - [ ] Then compute tax (Magento-like) based on shipping address

**Related:** `docs/processes/cart-management-process.md`, `docs/processes/promotion-process.md`

---

## 10) Test Scenarios (minimum set)

### Coupon
- [ ] Valid coupon applies
- [ ] Expired coupon rejected
- [ ] Usage-limit exceeded rejected
- [ ] Customer-bound coupon rejected for other customer

### Stacking
- [ ] Two stackable rules sum
- [ ] One non-stackable beats another (higher discount) regardless of priority order
- [ ] stop_rules_processing stops evaluation

### Advanced discounts (requires correct line payload)
- [ ] Buy 2 Get 1 Free (same SKU)
- [ ] Buy from category A get cheapest from category B
- [ ] Tiered discount by quantity thresholds
- [ ] Cheapest item free when cart qty >= N

### Free shipping
- [ ] Free shipping only for method "standard"
- [ ] Free shipping capped at max amount

---

## 11) Action Items to Align with Current Platform Decisions

Given current platform direction:
- **Order → Pricing direct** for prices
- tax computed at totals stage (Magento-like)

Promotion service must:
- [ ] operate only on **excl-tax** amounts
- [ ] receive accurate line item qty/price from Order
- [ ] return discount breakdown that Order can apply before tax

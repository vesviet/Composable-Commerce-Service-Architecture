# Promotion Service — Developer Implementation Checklist

**Purpose:** A developer-facing checklist for implementing and integrating Promotion service features safely and consistently.

**Current status:** Core Promotion engine is implemented. **Integration with other services is pending.**

**Related docs:**
- Process: `docs/processes/promotion-process.md`
- Checklist (service-level): `docs/checklists/promotion-service-checklist.md`

---

## 0) Ground rules (do these first)

- [ ] Treat Promotion as **authoritative** for:
  - coupon validity
  - cart rule selection (priority/stacking/stop processing)
  - discount computation (including advanced actions)

- [ ] Treat Order as **orchestrator** for:
  - collecting cart + customer + shipping context
  - applying returned discount to totals (excl tax)
  - recomputing destination tax after discount (Magento-like)

- [ ] **Canonical data contract = `items[]`** (structured line items). Legacy parallel arrays are fallback only.

---

## 1) Contract checklist (Order → Promotion)

### 1.1 Request payload (minimum required)

- [ ] **Identity**
  - [ ] `customer_id` (optional for guest)
  - [ ] `customer_segments[]` (optional)
  - [ ] `customer_group_id` (optional — if you plan group-based promos)

- [ ] **Cart money (excl tax)**
  - [ ] `subtotal_excl_tax`
  - [ ] `order_amount_excl_tax` (or same as subtotal at cart stage)

- [ ] **Coupons**
  - [ ] `coupon_codes[]`

- [ ] **Line items — REQUIRED for advanced promos**
  - [ ] `items[]` objects:
    - [ ] `product_id`
    - [ ] `sku`
    - [ ] `category_id`
    - [ ] `brand_id`
    - [ ] `quantity`
    - [ ] `unit_price_excl_tax`
    - [ ] `total_price_excl_tax` *(optional; can be derived)*
    - [ ] `is_special_price`
    - [ ] `attributes{}`

- [ ] **Shipping context**
  - [ ] `shipping_method`
  - [ ] `shipping_amount_excl_tax` *(required for free shipping discount)*
  - [ ] destination:
    - [ ] `shipping_country`
    - [ ] `shipping_state`
    - [ ] `shipping_postcode`

- [ ] **Payment context**
  - [ ] `payment_method` (optional)

### 1.2 Response payload

- [ ] `valid_promotions[]`:
  - [ ] `promotion_id`
  - [ ] `coupon_id` (optional)
  - [ ] `discount_amount`
  - [ ] `discount_type`
  - [ ] `is_stackable`

- [ ] `invalid_promotions[]` with reason
- [ ] `total_discount`
- [ ] `shipping_discount`
- [ ] `final_amount`

### 1.3 Contract invariants (validate defensively)

- [ ] If `items[]` is present, it must be the single source for:
  - [ ] quantities
  - [ ] unit prices
  - [ ] category/brand mapping

- [ ] Reject or log warnings if:
  - [ ] `quantity <= 0`
  - [ ] `unit_price_excl_tax < 0`
  - [ ] `total_price_excl_tax != unit_price_excl_tax * quantity` (if caller sends both)

---

## 2) Engine correctness checklist (Promotion service)

### 2.1 Rule retrieval

- [ ] Validate repository filtering for active cart rules:
  - [ ] `rule_type = cart`
  - [ ] time window (`starts_at`, `ends_at`)
  - [ ] warehouse filter (if used)

### 2.2 Coupon validity

- [ ] Coupon exists
- [ ] `is_active = true`
- [ ] now within `[starts_at, expires_at]`
- [ ] usage limits (`usage_limit`, `usage_count`)
- [ ] minimum order amount
- [ ] optional customer binding

### 2.3 Applicability checks

- [ ] minimum order amount
- [ ] segments match (if promotion has segments)
- [ ] applicable products/categories/brands
- [ ] excluded products
- [ ] usage limits (total and per customer)
- [ ] advanced conditions JSONB (cart/shipping/payment/product attributes)

### 2.4 Stacking / priority / stop processing

- [ ] Sort by `priority` desc
- [ ] Apply `stop_rules_processing`
- [ ] Keep all stackable promotions
- [ ] Choose best single non-stackable by **largest computed discount**

### 2.5 Free shipping

- [ ] Uses **real shipping amount** from request
- [ ] method filtering works
- [ ] product/category filtering works
- [ ] max cap works

---

## 3) Advanced discount actions checklist

**Goal:** All advanced discounts must compute from `items[]` (not legacy arrays).

- [ ] BOGO (Buy X Get Y)
  - [ ] buy filters by product/category/brand
  - [ ] get filters by product/category
  - [ ] cheapest/most expensive selection
  - [ ] max applications respected

- [ ] Tiered discount
  - [ ] based_on: quantity
  - [ ] based_on: amount
  - [ ] apply_to: cart
  - [ ] apply_to: each_item
  - [ ] each Nth item

- [ ] Item selection
  - [ ] cheapest N
  - [ ] most expensive N
  - [ ] apply-to category/product restrictions

---

## 4) Integration checklist (PENDING — to be implemented)

### 4.1 Order service integration points

- [ ] Decide when Order calls Promotion:
  - [ ] on apply coupon
  - [ ] on cart change (optional)
  - [ ] on totals computation before confirm checkout (required)

- [ ] Persist applied promotions/coupons in cart/checkout state.

- [x] Ensure totals sequence (Magento-like):
  - [x] subtotal_excl_tax
  - [x] apply promotions (excl tax) (Logic handles discount correctly)
  - [x] compute destination tax after discount
  - [x] add shipping + shipping tax

### 4.2 Catalog enrichment (until payload includes it)

- [ ] Ensure Order can provide for each line item:
  - [ ] category_id
  - [ ] brand_id
  - [ ] product attributes needed by promotion conditions

### 4.3 Shipping integration

- [ ] Ensure Order provides:
  - [ ] selected shipping method
  - [ ] shipping amount
  - [ ] destination address fields

---

## 5) Observability & safety checklist

### 5.0 Money determinism & rounding

- [ ] Compute money using **integer minor units** (e.g., cents) or a decimal library; avoid float drift.
- [ ] Define rounding policy:
  - [ ] round per-line then sum (recommended) OR sum then round (but must be consistent)
- [ ] Ensure deterministic evaluation:
  - [ ] stable sort keys for items and promotions
  - [ ] same input => same output

### 5.1 Usage recording idempotency

- [ ] Persist promotion/coupon usage only on **order completion**.
- [ ] Make usage recording idempotent:
  - [ ] dedupe key: `order_id` (or `order_completed_event_id`)
  - [ ] repeated events do not increment usage twice
  - [ ] enforce DB unique constraint on `(order_id, promotion_id)` and `(order_id, coupon_id)` (as applicable)

## 5) Observability & safety checklist

- [ ] Log promo evaluation inputs (redact sensitive fields)
- [ ] Log which promotions were applied and why
- [ ] Add metrics:
  - [ ] validation duration p95/p99
  - [ ] applied promotion counts
  - [ ] coupon invalid reasons
- [ ] Avoid blocking checkout on non-critical dependencies (policy decision)

---

## 6) Tests checklist

### 6.1 Unit tests (Promotion service)

- [ ] Coupon validity matrix (active, expired, usage limit, min amount)
- [ ] Stacking behavior:
  - [ ] multiple stackables sum
  - [ ] non-stackable chooses best discount
  - [ ] stop_rules_processing stops evaluation
- [ ] Free shipping:
  - [ ] method filter
  - [ ] cap
- [ ] Advanced actions:
  - [ ] BOGO
  - [ ] tiered
  - [ ] item selection

### 6.2 Integration tests (Order ↔ Promotion) — when integration starts

- [ ] Order sends `items[]` with correct qty/price
- [ ] Order applies returned `total_discount` excl tax
- [ ] Tax recomputed after discount

---

## 7) Suggested refactor boundaries (optional, for maintainability)

- [ ] Split `promotion/internal/biz/promotion.go` into:
  - [ ] `types.go` (domain + request/response)
  - [ ] `engine.go` (ValidatePromotions loop)
  - [ ] `validation.go` (coupon + applicability)
  - [ ] `events.go`
  - [ ] `analytics.go`

---

**Outcome:** When all items above are checked, Promotion service can be considered production-ready for cart rule evaluation, with safe contracts and predictable behavior.

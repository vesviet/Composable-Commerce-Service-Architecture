# Tax Implementation Checklist (Magento-like vs Shopify-like)

**Purpose:** Provide a checklist to verify and maintain tax behavior aligned with Magento-like semantics (primary) and Shopify-like semantics (secondary).

**Scope:** Pricing Service + integration points (Order/Cart/Checkout, Promotion, Shipping, Catalog enrichment).

---

## 0) Status

You indicated **core tax has been implemented**, but **integration with other services is not done yet**.

Legend:
- ✅ implemented & verified
- 🟡 implemented but needs verification
- ❌ not implemented yet

---

## 1) Magento-like Semantics (PRIMARY)

**Target:**
- Catalog prices are **exclusive of tax** (net).
- Discounts are applied on **excl-tax** prices.
- Tax is calculated based on **shipping address** (destination-based).
- Category and customer group can affect tax rate.

---

## 2) Pricing Service (authoritative tax engine)

### 2.1 API contract (proto)

- ✅ `CalculateTaxRequest` supports destination + segmentation context:
  - ✅ `country_code`
  - ✅ `state_province`
  - ✅ `postcode`
  - ✅ `customer_group_id`
  - ✅ `product_categories[]`

**Reference:** `pricing/api/pricing/v1/pricing.proto` → `message CalculateTaxRequest`

- ✅ `TaxRule` supports key match dimensions:
  - ✅ `country_code`, `state_province`, `postcode` (pattern)
  - ✅ `applicable_categories[]`
  - ✅ `applicable_customer_groups[]`
  - ✅ `priority` (higher wins)

**Reference:** `pricing/api/pricing/v1/pricing.proto` → `message TaxRule`

### 2.2 Behavior requirements (core tax engine)

Mark these as implemented by you, but keep a verification list:

- 🟡 **Destination matching**
  - [ ] Verify repository / query path actually filters by `postcode` and applies wildcard semantics.
  - [ ] Verify precedence order when multiple rules match (e.g., postcode-specific wins over state-only).

- 🟡 **Category-based tax**
  - [ ] Verify tax selection uses `product_categories[]` against `TaxRule.applicable_categories[]`.
  - [ ] Verify multi-category precedence is deterministic.

- 🟡 **Customer group-based tax**
  - [ ] Verify rule selection uses `customer_group_id` against `TaxRule.applicable_customer_groups[]`.

- 🟡 **Tax base**
  - [ ] Verify tax is computed on **excl-tax discounted taxable amount**:
    - `taxable_amount_excl_tax = max(0, subtotal_excl_tax - discount_excl_tax)`

---

## 3) Integration (NOT DONE YET) — what remains to implement

This section tracks all remaining work to connect the tax engine to the rest of the platform.

### 3.1 Order Service Integration (Cart/Checkout)

- ❌ **Order → Pricing direct call (source of truth)**
  - [ ] `AddToCart` should call **Pricing.CalculatePrice** (excl tax) and store net price snapshot.
  - [ ] Stop relying on catalog-provided tax in cart stage.

- ❌ **Totals calculation (Magento-like tax timing)**
  - [ ] Implement/standardize a totals computation flow that:
    - [ ] applies discounts (excl tax)
    - [ ] computes destination tax using shipping address via Pricing.CalculateTax
    - [ ] recomputes tax when shipping address / discounts / quantities change

- ❌ **Context propagation**
  - [ ] Ensure Order passes to Pricing.CalculateTax:
    - [ ] `country_code`, `state_province`, `postcode`
    - [ ] `customer_group_id`
    - [ ] `product_categories[]` (or derived tax class)

### 3.2 Promotion Integration (discount-before-tax)

- ❌ **Discount values must be excl-tax and affect tax base**
  - [ ] Order must apply promotion discounts before tax.
  - [ ] Promotion request/response must provide discount info that can be applied to excl-tax subtotal.

### 3.3 Shipping Integration (shipping tax)

- ❌ **Shipping tax policy**
  - [ ] Decide whether shipping is taxable.
  - [ ] Define shipping tax class per shipping method/zone.

- ❌ **Totals formula must include shipping tax**
  - [ ] `grand_total_incl_tax = (items_subtotal_excl_tax - items_discount_excl_tax) + items_tax_total + shipping_excl_tax + shipping_tax_amount`

### 3.4 Catalog enrichment (categories)

- ❌ Ensure Order can obtain product categories to pass to Pricing tax calculation:
  - [ ] from Catalog service (preferred)
  - [ ] or cached on cart line snapshot

---

## 4) Rounding & Precision (verify once integrated)

- ❌ Decide and enforce one rounding strategy across Order totals:
  - [ ] per unit, per row, or totals

- ❌ Verify currency decimals (e.g., VND 0, USD 2).

---

## 5) Acceptance Fixtures (enable after integration)

- ❌ FOOD reduced VAT example (5%)
- ❌ ALCOHOL excise example (20%)
- ❌ WHOLESALE group override example
- ❌ Postcode-specific override example (`100*`)
- ❌ Shipping address change updates tax
- ❌ Discount change updates tax base then tax

---

## 6) Shopify-like (secondary)

Keep as future reference if needed:
- tax lines (`tax_lines[]`)
- exemptions / VAT IDs
- mixed-rate carts

---

## 7) References

- Cart process: `docs/processes/cart-management-process.md`
- Promotion process: `docs/processes/promotion-process.md`
- Promotion checklist: `docs/checklists/promotion-service-checklist.md`
- Pricing flow: `docs/checklists/PRICING_FLOW.md`

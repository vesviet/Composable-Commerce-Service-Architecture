# Commerce Core Follow-up Checklist (Single Source of Truth)

**Scope:** Cart (Order service cart-management) + Promotion service + Fulfillment service  
**Audience:** Developers implementing follow-ups after tech lead review  
**Status:** Active  
**Last Updated:** 2026-01-11

---

## How to use this doc

- Use this document as the only checklist for follow-up work.
- For each item:
  - Fill `Owner`.
  - Keep `Status` as one of: `todo | in_progress | blocked | done`.
  - Add links to PRs and code pointers in `Evidence`.

---

## A) Cart (Order service) — Magento-like alignment

**Primary goal:**
- Price source of truth = **Pricing service**.
- Cart stage tax = **pending** until shipping address.
- Totals stage computes: `taxable = max(0, subtotal_excl_tax - discount_excl_tax)`.

### A.1 Critical follow-ups

1. **[A1] Remove hard-coded country/currency in Pricing calls**  
   - **Status:** done
   - **Owner:** Antigravity
   - **Why:** Country/currency drives pricing rules; hard-code breaks multi-country.  
   - **Evidence (current code):** Fixed in `order/internal/biz/cart/{update,validate,sync}.go` to use Cart context. `add.go` legacy pending.
   - **Definition of Done:** `countryCode` and `currency` come from cart/session/storefront/shipping context end-to-end.

2. **[A2] Idempotency + concurrency control for cart mutations**  
   - **Status:** todo  
   - **Owner:**  
   - **Why:** Prevent duplicate increments and race conditions under retries/concurrent adds.  
   - **Definition of Done:**
     - Accept `Idempotency-Key` (or request-id) for: add/update/remove/apply coupon/sync.
     - Enforce DB uniqueness for `(cart_id, product_id, warehouse_id)` (or equivalent) and use conflict-safe upserts.
     - Add optimistic locking (`cart_version`/ETag) to prevent lost updates.

### A.2 Tax + totals correctness

3. **[A3] Totals recompute tax using taxable amount (after discount)**  
   - **Status:** done
   - **Owner:** Antigravity
   - **Definition of Done:** Checkout/totals path uses `taxable = max(0, subtotal_excl_tax - discount_excl_tax)` consistently for all recalculation triggers.

4. **[A4] Pass postcode/category/customer_group into tax calculation**  
   - **Status:** done
   - **Owner:** Antigravity
   - **Definition of Done:** Pricing/Tax call receives `country/state/postcode`, `customer_group_id`, and category/tax-class signals.

5. **[A5] Shipping tax policy**  
   - **Status:** done
   - **Owner:** Antigravity
   - **Definition of Done:** Defined if shipping taxable; if yes compute `shipping_tax_amount` and include in grand total.

### A.3 Observability

6. **[A6] Cart observability**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** metrics + logs for:
     - price mismatch rate
     - stock check failure
     - cart mutation latency p95/p99

---

## B) Promotion service — production readiness

**Primary goal:** Promotion is authoritative for discounts; Order is orchestrator; inputs must use canonical `items[]`.

### B.1 Gating bugs (must fix before enabling advanced promos)

1. **[B1] Advanced discount calculation must use real line inputs**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** Advanced calculator builds cart items from `items[]` with correct `quantity` + `unit_price_excl_tax`.

2. **[B2] Free shipping must use real shipping amount**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** request requires `shipping_amount_excl_tax` and calculation uses it (not `0`).

### B.2 Safety / correctness

3. **[B3] Usage recording idempotency (order completion is at-least-once)**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** dedupe by `order_id`/`event_id` + DB unique constraints to prevent double increment.

4. **[B4] Money determinism + rounding policy**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** integer minor units or decimal; rounding rule documented; stable sorting ensures same input => same output.

---

## C) Fulfillment service — consistency & reliability

**Primary goal:** Fulfillment owns warehouse execution workflow; must be safe under retries and partial failures.

### C.1 Atomicity + idempotency

1. **[C1] Packing/ConfirmPacked must be DB-atomic**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** `ConfirmPacked` uses a single DB transaction for package + package_items + fulfillment status.

2. **[C2] Idempotency enforced via DB constraints + conflict-safe writes**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** constraints prevent duplicate packages/picklists; retries are safe.

### C.2 Eventing

3. **[C3] Outbox/Inbox for fulfillment events**  
   - **Status:** todo  
   - **Owner:**  
   - **Definition of Done:** outbox insert in same tx; worker publishes; inbox dedup for consumed events.

---

## D) Verification checklist (required before marking items done)

- **Unit tests:** critical invariants per domain
- **Integration tests:**
  - cart totals vs tax rules
  - promotion advanced rules + free shipping
  - fulfillment full workflow + retries
- **Observability:** dashboards/alerts exist for core failure modes

# Catalog Service — Developer Implementation Checklist (Refactor)

**Purpose:** This is a developer-facing punch-list to align the Catalog service with the platform's architecture. The core issue is that the Catalog's API contract currently violates domain boundaries.

**Status:** ❌ **Implementation Required**

**Context (Platform Direction):**
- **Pricing Service** is the source of truth for cart/checkout prices (excl tax) and tax.
- **Promotion Service** is the source of truth for discounts.
- **Warehouse Service** is the source of truth for stock.
- **Catalog Service** is the source of truth for product information (name, SKU, attributes, categories, etc.).

---

## 📌 Developer Punch-list (What MUST Be Implemented)

### 1. CRITICAL: Refactor API Contract (`catalog/api/product/v1/product.proto`)

**Problem:** The `Product` message currently exposes fields from other domains (`price`, `stock`, `tax_amount`, `promotion`), creating a risk of stale data and violating domain boundaries.

- [ ] **Action 1.1: Remove non-authoritative fields.**
  - In `product.proto`, remove the following fields from the `Product` message:
    - `stock`, `stock_status`
    - `price`, `base_price`, `sale_price`, `currency`, `prices_by_currency`
    - `tax_amount`
    - `promotion`

- [ ] **Action 1.2 (Alternative - for display only):**
  - If these fields are absolutely needed for a simple display client, rename them to indicate they are not authoritative and may be stale. **This is not the preferred approach.**
  - Example: `price` → `display_price`, `stock` → `cached_stock_level`.
  - Add a comment in the `.proto` file: `// For display purposes only. Do not use for cart/checkout calculations. Authoritative source is Pricing/Warehouse service.`

### 2. REQUIRED: Update Service Consumers

**Problem:** After refactoring the `Product` message, any service that calls `ProductService.GetProduct` and uses the removed fields will fail.

- [ ] **Action 2.1: Identify all consumers.**
  - Search the codebase for any service that calls `ProductService` gRPC endpoints.

- [ ] **Action 2.2: Refactor consumers.**
  - Update each consumer to call the correct authoritative service for the data it needs:
    - For price/tax, call **Pricing Service**.
    - For stock, call **Warehouse Service**.
    - For promotions, call **Promotion Service**.
  - If a consumer needs aggregated data (e.g., a frontend), it should go through a **BFF (Backend for Frontend)** or aggregate the data itself.

### 3. REQUIRED: Display-only Aggregation Policy (if you keep cached fields)

**Problem:** This item only applies if Catalog intentionally keeps **display-only** cached fields such as `display_price` / `cached_stock_level`.

If you follow **Action 1.1 (remove non-authoritative fields)**, then Catalog must **stop** caching price/stock/promotion and this section should be removed together with the old implementation (`product_price_stock.go`).

- [ ] **Action 3.1: Decide the policy (choose one).**
  - [ ] **Preferred:** remove all cross-domain cached fields (no price/stock/tax/promo in Catalog APIs).
  - [ ] **Display-only:** keep cached fields but mark them clearly as non-authoritative (see Action 1.2).

- [ ] **Action 3.2 (only for display-only): Subscribe to update events.**
  - Implement event listeners in Catalog service for:
    - `warehouse.stock_updated`
    - `pricing.price_updated`
    - `promotion.promotion_updated`

- [ ] **Action 3.3 (only for display-only): Invalidate cache.**
  - When an update event is received, invalidate the corresponding cache entry for that product in Redis.

### 4. REQUIRED: Migration / Rollout Plan

- [ ] **Action 4.1: Version the API contract.**
  - Introduce a new version (`product.v2`) or a new RPC/endpoint that returns the boundary-correct `Product` message.

- [ ] **Action 4.2: Consumer-first rollout.**
  - Update consumers to stop using removed fields **before** removing them from the existing `v1` response.

- [ ] **Action 4.3: Deprecation window.**
  - Keep backward compatibility for a defined window (e.g. 2-4 weeks), then delete the old fields and any cross-domain cache code.

- [ ] **Action 4.4: Add contract tests.**
  - Add a CI check that prevents re-introducing non-authoritative fields into Catalog.

### 5. REQUIRED: Update Documentation

- [ ] **Action 4.1: Update Catalog's `README.md`.**
  - Clearly state that the service's responsibility is limited to product master data and does not include price, stock, or promotion data for transactional flows.

---

## 4) Developer Implementation Checklist (Existing Items - Keep for Reference)

These are existing requirements from the previous checklist that are still valid.

### 4.1 Category/brand enrichment

- [ ] Provide an endpoint or repository method to resolve:
  - [ ] `product_id → category_ids[]`
  - [ ] `product_id → brand_id`

- [ ] Define a “primary category” policy.

### 4.2 Visibility rules

- [ ] Ensure visibility evaluation is applied consistently across:
  - [ ] product detail
  - [ ] product listing
  - [ ] search indexing payload

### 4.3 Data quality checks

- [ ] SKU uniqueness enforced.
- [ ] product status transitions validated.
- [ ] attributes validated against allowed schema.

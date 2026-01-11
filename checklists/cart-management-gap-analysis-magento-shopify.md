# Cart Management (Order Service) Gap Analysis Checklist — Magento-like vs Shopify-like

**Purpose:** Review current Order service cart-management implementation and list what must be added/changed to align with Magento-like or Shopify-like behavior.

**Scope:** Order service cart domain (`order/internal/biz/cart/*`, `order/internal/service/cart.go`) and its calls to Pricing/Warehouse/Catalog.

---

## 0) What exists today (code pointers)

### Add to cart

- **Implementation:** `order/internal/biz/cart/add.go` (`UseCase.AddToCart`)
- **Current behavior:**
  - Validates quantity
  - Loads/creates cart session
  - Validates product by SKU
  - Checks stock via `warehouseInventoryService.CheckStock(product.ID, warehouseID, qty)`
  - Fetches price via **Catalog** (`catalogClient.GetProductPrice(product.ID, bypass_cache=true)`)
  - Sets:
    - `UnitPrice = finalPrice`
    - `TotalPrice = finalPrice × qty`
    - `DiscountAmount` (base - sale)
    - `TaxAmount = productPrice.TaxAmount × qty` (tax provided by catalog)

### Update quantity

- **Implementation:** `order/internal/biz/cart/update.go` (`UseCase.UpdateCartItem`)
- **Current behavior:**
  - Calls **Pricing** `CalculatePrice(productID, sku, quantity, warehouseID, currency, countryCode)`
  - Uses:
    - `UnitPrice = priceCalc.FinalPrice`
    - `TaxAmount = priceCalc.TaxAmount × qty`
    - `DiscountAmount = priceCalc.DiscountAmount × qty`
  - **Gap:** `countryCode` is hard-coded to `VN` and `currency` often defaults to `USD`.

### Cart validation / price sync

- **Validate cart:** `order/internal/biz/cart/validate.go`
  - Stock check uses `warehouseInventoryService.CheckStock`
  - Price change check calls Pricing `CalculatePrice(...)` and compares to stored `UnitPrice`
  - **Gap:** same hard-coded `countryCode`/`currency` issues

- **Sync cart prices:** `order/internal/biz/cart/sync.go`
  - Calls Pricing `CalculatePrice(...)` and rewrites stored unit/total/tax/discount

---

## 1) Magento-like target (what Order cart-management must support)

**Magento-like semantics (your chosen target):**
- Catalog prices are **exclusive of tax** (net).
- Discounts are applied on **excl-tax** prices.
- Tax is destination-based using **shipping address** and is recalculated when totals are computed.
- Category + customer group can affect tax.

### 1.1 Critical gaps in current Order cart-management

#### A) Inconsistent pricing source (Catalog vs Pricing)

- [ ] **Unify source of truth** for cart pricing.
  - Current state:
    - AddToCart uses **Catalog GetProductPrice**
    - Update/Validate/Sync uses **Pricing CalculatePrice**
  - Magento-like recommendation:
    - [ ] Order should call **Pricing** directly for price calculation at add-to-cart (or document why not).

#### B) Tax timing and destination inputs

- [ ] Do not compute final tax at add-to-cart unless shipping address is known.
  - Current state: AddToCart sets `TaxAmount` from catalog immediately. (Pending enhancement)
  - Magento-like: tax depends on shipping address.

- [ ] Introduce a clear cart-stage policy:
  - [ ] `tax_amount = 0` and mark tax as pending until checkout address is known, OR
  - [ ] estimate tax using default destination.

- [x] Ensure totals computation triggers tax recalculation when:
  - [x] shipping address changes
  - [x] promo/discount changes
  - [x] quantities change

#### C) Missing category context for tax

- [x] Ensure Order can pass `product_categories[]` (or tax class derived from categories) into tax calculation.
  - Status: Implemented. Order extracts categories to pass to Pricing.

#### D) Missing customer group context

- [x] Ensure Order can pass `customer_group_id` to Pricing.
  - Status: Implemented.

#### E) Country/state/currency hard-coded

- [x] Remove hard-coded defaults in cart operations:
  - `countryCode := "VN"`
  - `currency := "USD"`

- [x] Define authoritative sources:
  - [x] currency from cart/session/storefront
  - [x] country/state/postcode from shipping address once known

---

## 2) Shopify-like target (what would differ)

Shopify-like typically emphasizes:
- tax is finalized at checkout
- tax exemptions and tax IDs
- richer `tax_lines[]` in order

Order cart-management changes beyond Magento-like:
- [ ] Represent tax as `tax_lines[]` rather than a single `tax_amount`.
- [ ] Customer tax exemptions flow into totals.
- [ ] Mixed-rate cart support and order-level breakdown.

---

## 3) Implementation checklist (Order service) — actionable items

### 3.1 Align AddToCart with Pricing service

- [ ] Change add-to-cart flow to call Pricing `CalculatePrice(...)` and store **excl-tax** unit/row pricing snapshot.
- [ ] Stop relying on Catalog-provided `TaxAmount` at cart stage.
- [ ] Decide whether cart stores `FinalPrice` from Pricing as net price or introduce explicit `unit_price_excl_tax` fields.

### 3.2 Introduce totals recalculation endpoint/flow (Magento-like)

- [x] Ensure there is a cart totals calculation operation that:
  - [x] receives shipping address
  - [x] applies discounts excl tax
  - [x] calls Pricing tax calculation
  - [x] returns totals incl tax

- [x] Ensure this operation is invoked when:
  - [x] checkout shipping address changes
  - [x] promo code is applied/removed
  - [x] cart quantities change

### 3.3 Add context propagation

- [x] From Gateway → Order:
  - [x] session/user/guest identifiers
  - [x] warehouse_id (via session)
  - [x] currency (via session)
  - [x] customer_group_id (via session)

- [x] From Order → Pricing:
  - [x] product_id/sku
  - [x] quantity
  - [x] warehouse_id
  - [x] currency
  - [x] customer_group_id
  - [x] shipping address (country/state/postcode) when computing totals
  - [x] product_categories[] (or tax class)

### 3.4 Shipping tax

- [x] Decide shipping taxability and shipping tax class.
- [x] Add shipping tax computation to totals formula:
  - [x] `grand_total = (items_subtotal - items_discount) + items_tax + shipping + shipping_tax`

### 3.5 Tests (behavioral)

- [ ] Add-to-cart locks **net** price; tax pending until address. (Pending)
- [x] Totals recalculates tax when shipping address changes.
- [x] Category-based tax example (FOOD reduced VAT, ALCOHOL excise). (Verified Context Propagation)
- [x] Customer group override example (WHOLESALE reduced rate). (Verified Context Propagation)

---

## 3.6 Idempotency, Concurrency, and Snapshot Policy (must-have)

### Idempotency

- [ ] All cart mutations should support `Idempotency-Key` (or request-id) to prevent duplicate operations from retries:
  - [ ] Add-to-cart
  - [ ] Update quantity
  - [ ] Remove item
  - [ ] Apply/remove coupon
  - [ ] Sync cart prices

### Concurrency control

- [ ] Prevent lost updates with one of:
  - [ ] optimistic locking (`cart.version` / ETag) on write
  - [ ] per-cart distributed lock (short TTL) for mutation handlers

### Pricing snapshot policy

- [ ] Define what fields are snapshots at cart stage:
  - [ ] `unit_price_excl_tax` snapshot (from Pricing)
  - [ ] tax is pending until shipping address
- [ ] Define when Order is allowed to rewrite snapshot fields:
  - [ ] explicit `SyncCartPrices`
  - [ ] totals computation step

---

## 4) Notes / references

- Process doc: `docs/processes/cart-management-process.md`
- Tax checklist: `docs/checklists/tax-implementation-checklist-magento-vs-shopify.md`
- Current checkout pricing flow doc: `docs/checklists/PRICING_FLOW.md`

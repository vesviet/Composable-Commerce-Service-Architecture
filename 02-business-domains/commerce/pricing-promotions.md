# 💰🎁 Pricing + Promotion Flow (End-to-End)

**Last Updated**: 2026-01-18  
**Owner**: Platform Engineering  
**Scope**: Pricing service + Promotion service + Order integration + downstream consumers (Search/Gateway cache)

---

## 1) Purpose & Boundaries

### Pricing service owns
- Base price storage (per SKU/product, per warehouse/global)
- Price calculation pipeline (base → dynamic → rules → tax)
- Publish price change events (`pricing.price.updated|deleted`)

### Promotion service owns
- Promotion definitions (conditions, segments, applicable products/categories/brands)
- Validation (read-only): determine applicable promotions and discount amounts
- Reservation/apply (write): atomic usage reservation with locking + outbox events

### Order service owns
- Checkout orchestration: preview totals, confirm order, payment, finalization
- Calling pricing & promotion APIs at the right moments (idempotent)

---

## 2) Request-Time Flow: Cart/Checkout Price Preview

### What this flow answers
- “Given cart items + customer + warehouse, what is the total price and which promos apply?”

```mermaid
sequenceDiagram
  autonumber
  participant C as Client (Web/Admin)
  participant G as Gateway
  participant O as Order Service
  participant P as Pricing Service
  participant PR as Promotion Service

  C->>G: POST /cart/preview (items, warehouse_id, coupon?)
  G->>O: Forward request

  Note over O: Build pricing context (warehouse, currency, customer)
  loop for each cart line
    O->>P: CalculatePrice(sku/product, qty, warehouse_id, currency)
    P-->>O: line price breakdown (base/sale/rules/tax)
  end

  O->>PR: ValidatePromotions(cart snapshot, customer, coupon?)
  PR-->>O: applicable promos + computed discount

  O->>O: Compute totals (subtotal, discount, tax, grand_total)
  O-->>G: preview response
  G-->>C: preview response
```

### Notes
- Pricing calculates **tax** and internal pricing rules.
- Promotion applies **coupon/promo discounts** (separate service).
- Order must keep a stable **cart snapshot** used for both validation and eventual apply.

Tax integration details are documented in [tax-calculation.md](tax-calculation.md).

---

## 3) Request-Time Flow: Order Confirmation (Promotion Apply/Reserve)

### Recommended “correct” sequence
- Promotion usage should be **reserved/applied** only when the order is truly being placed (or in a clear reservation step with TTL).

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant G as Gateway
  participant O as Order Service
  participant P as Pricing Service
  participant PR as Promotion Service
  participant Pay as Payment Service

  C->>G: POST /checkout/confirm
  G->>O: Forward request

  Note over O: Recompute totals to avoid client tampering
  loop items
    O->>P: CalculatePrice(...)
    P-->>O: prices
  end

  O->>PR: ValidatePromotions(cart snapshot, customer)
  PR-->>O: eligible promos

  Note over O: Create pending order in DB (idempotency key)

  O->>Pay: Authorize/Capture payment
  Pay-->>O: payment success

  Note over O: Commit promotion usage after payment
  O->>PR: ApplyPromotion(order_id, customer_id, promo_ids) (idempotent)
  PR-->>O: reserved usage + audit records

  O->>O: Mark order confirmed
  O-->>G: success
  G-->>C: success
```

### Idempotency rules
- Order must pass a stable `order_id` / idempotency key to Promotion.
- Promotion Apply must be safe to retry (e.g., on gateway timeout).

---

## 4) Pricing Calculation Internals (Pricing Service)

```mermaid
flowchart TD
  A[CalculatePrice Request] --> B{Redis Cache Hit?}
  B -->|Yes| Z[Return cached price]
  B -->|No| C[Fetch Base Price]
  C --> C1[Priority: SKU+WH]
  C --> C2[SKU Global]
  C --> C3[Product+WH]
  C --> C4[Product Global]
  C --> D[Currency Conversion if needed]
  D --> E[Multiply by Quantity]
  E --> F[Dynamic Pricing Adjustment]
  F --> G[Apply Pricing Rules (priority order)]
  G --> H[Tax Calculation]
  H --> I[Cache Result]
  I --> J[Publish price.calculated event (optional)]
  J --> Z2[Return final breakdown]

### 4.1 Tax Calculation (How it should work)

Pricing should calculate tax using **full context** (address + product categories + customer group when applicable).  
There are currently two integration styles in the system:

1. **Preferred**: tax is part of `CalculatePrice`.
2. **Current**: Order calls `CalculateTax` (RPC). Pricing internally uses `TaxUsecase.CalculateTaxWithContext`.

Current correctness risks are mostly on the **Order context** side (not on Pricing):
- Some Order flows pass `product_categories=[]` (TODO), so category-based tax rules won’t apply.
- Some Order flows mistakenly pass `customer_id` into the `customer_group_id` field.

See [tax-calculation.md](tax-calculation.md) for the verified current path and the recommended refactor (pass full context correctly).
```

---

## 5) Promotion Internals (Promotion Service)

### 5.1 ValidatePromotions (read-only)

```mermaid
flowchart TD
  A[ValidatePromotions Request] --> B[Fetch active promotions by context]
  B --> C[Sort by priority]
  C --> D[Check eligibility: segments/min cart/sku/category]
  D --> E[Check usage limits snapshot]
  E --> F[Compute discount candidates]
  F --> G{Stacking}
  G -->|stackable| H[Apply all stackable in order]
  G -->|non-stackable| I[Pick best single promo]
  H --> J[Return applicable promos + discount]
  I --> J
```

### 5.2 Apply/ReserveUsage (write, atomic)

```mermaid
sequenceDiagram
  autonumber
  participant O as Order Service
  participant PR as Promotion Service
  participant DB as Postgres
  participant OB as Outbox Worker
  participant PUB as PubSub

  O->>PR: ApplyPromotion(order_id, promo_id, customer_id)
  PR->>DB: BEGIN
  PR->>DB: SELECT promotion FOR UPDATE
  PR->>DB: Re-validate usage limits
  PR->>DB: UPDATE current_usage_count = current_usage_count + 1
  PR->>DB: INSERT promotion_usage (order_id, customer_id, ...)
  PR->>DB: INSERT outbox event (promotion.applied)
  PR->>DB: COMMIT
  PR-->>O: OK

  OB->>DB: Poll outbox
  OB->>PUB: Publish promotion.applied
  PUB-->>OB: Ack
  OB->>DB: Mark outbox delivered
```

---

## 6) Write-Time Flow: Admin Updates Price → Downstream Sync

```mermaid
sequenceDiagram
  autonumber
  participant Admin as Admin UI
  participant G as Gateway
  participant P as Pricing Service
  participant DB as Postgres
  participant OB as Outbox Worker
  participant PUB as PubSub
  participant S as Search Worker
  participant ES as Elasticsearch

  Admin->>G: PUT /pricing/prices/{id}
  G->>P: Forward

  P->>DB: BEGIN
  P->>DB: Update price record
  P->>DB: Insert outbox (pricing.price.updated)
  P->>DB: COMMIT
  P-->>G: 200 OK

  OB->>DB: Poll outbox
  OB->>PUB: Publish pricing.price.updated

  PUB->>S: pricing.price.updated
  S->>ES: Update product warehouse price fields
  ES-->>S: ack
```

---

## 7) Where Search fits in (read model)

- Search service consumes `pricing.price.updated|deleted` and `warehouse.inventory.stock_changed` to keep a **warehouse-aware sellable view** in Elasticsearch.
- Order uses Pricing+Promotion as the **source of truth** for checkout totals; Search is for discovery only.

---

## 8) Links
- Issues checklist: [docs/10-appendix/checklists/pricing-promotion-flow-issues.md](../../10-appendix/checklists/pricing-promotion-flow-issues.md)
- Pricing-only flow: [pricing-management.md](pricing-management.md)
- Promotion-only flow: [promotion-management.md](promotion-management.md)
- Tax flow: [tax-calculation.md](tax-calculation.md)
- Search sellable view: [docs/10-appendix/legacy/search-sellable-view-per-warehouse-complete.md](../../10-appendix/legacy/search-sellable-view-per-warehouse-complete.md)

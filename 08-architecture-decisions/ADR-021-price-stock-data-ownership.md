# ADR-021: Price & Stock Data Ownership Between Catalog and Search
Date: 2026-02-12
Status: Accepted

## Context

The e-commerce platform has two services that store product data related to price and stock availability:

- **Catalog Service**: Manages product metadata, receives price/stock data from external sources (warehouse, pricing services), and publishes events on product changes.
- **Search Service**: Indexes product data in Elasticsearch for fast retrieval, filtering by price range, stock availability, and sorting by price.

Both services maintain representations of price and stock data, creating ambiguity about:
1. Which service is authoritative for price and stock data?
2. When should a consumer query Catalog vs. Search for this data?
3. How should data staleness be handled?

This is related to but distinct from [ADR: Inventory Data Ownership](../05-workflows/integration-flows/inventory-data-ownership-adr.md), which covers the Warehouse → Catalog/Search flow.

## Decision

### Data Ownership Hierarchy

```
                  Source of Truth
                  ──────────────
Pricing Service ─────► Catalog Service ─────► Search Service
                        (Relational)          (Denormalized)
                        
Warehouse Service ──► Catalog Service ─────► Search Service
                       (Real-time via gRPC)   (Eventually consistent)
```

### 1. Catalog Service is the **Relational Authority**
- Stores canonical product metadata: name, SKU, description, category, brand, images, attributes
- Receives price data via events from **Pricing Service** (`pricing.price.updated`)
- Queries **Warehouse Service** via gRPC for real-time stock (does NOT store stock)
- Publishes `catalog.product.created`, `catalog.product.updated`, `catalog.product.deleted` events

### 2. Search Service is the **Denormalized Index**
- Indexes flattened, query-optimized product documents in Elasticsearch
- Contains denormalized copies of: price, stock status, warehouse availability
- Data is **eventually consistent** (target lag: <5 seconds)
- Consumers of search results should treat price/stock as **approximate** for display purposes

### 3. Rules for Consumers

| Operation | Query Service | Reason |
|-----------|--------------|--------|
| Search / filter / sort products | **Search** | Performance, relevance scoring |
| Display product list (browse) | **Search** | Pre-indexed, fast, paginated |
| Product detail page (PDP) | **Catalog** | Authoritative, real-time |
| Add to cart / checkout | **Catalog → Warehouse** | Must be real-time accurate |
| Admin product management | **Catalog** | Full relational data |
| Price comparison / analytics | **Catalog** | Authoritative historical data |

### 4. Consistency Guarantees

| Data Field | Catalog Consistency | Search Consistency | Max Lag |
|-----------|--------------------|--------------------|---------|
| Product name/description | Immediate | Eventually consistent | <5s |
| Base price | Immediate | Eventually consistent | <5s |
| Sale price | Immediate | Eventually consistent | <5s |
| Stock status (in/out) | Real-time (via Warehouse gRPC) | Eventually consistent | <5s |
| Stock quantity | Real-time (via Warehouse gRPC) | Eventually consistent | <5s |
| Category/brand | Immediate | Eventually consistent | <5s |

### 5. Search Index as Cache, Not Source of Truth

The Search Service's Elasticsearch index should be treated as a **read-optimized projection**, similar to a CQRS read model:
- It **MUST NOT** be used as input for business logic decisions (pricing, stock validation)
- It **MAY** be stale by up to 5 seconds under normal load
- It **CAN** be fully rebuilt from Catalog + Warehouse data without data loss
- It **SHOULD** display "Prices may vary" disclaimers on search result pages

## Consequences

### Positive
1. **Clear boundaries**: No ambiguity about where to query for each use case
2. **Performance**: Search results are sub-100ms from pre-indexed data
3. **Rebuild safety**: Search index can be recreated from authoritative sources
4. **Decoupled scaling**: Search scales independently via ES cluster

### Negative
1. **Stale prices**: Search results may show slightly outdated prices (max 5s)
2. **Dual updates**: Price changes must flow through two systems
3. **Complexity**: Event pipeline Pricing→Catalog→Search requires monitoring

### Risks & Mitigation
- **Risk**: Customer sees one price in search, different price on PDP
  - **Mitigation**: PDP always queries Catalog (authoritative); Search disclaims "Prices may vary"
- **Risk**: Search shows "in stock" but Warehouse says "out of stock"
  - **Mitigation**: Cart/checkout validates stock via Catalog→Warehouse gRPC

## Alternatives

1. **Search queries Catalog/Warehouse directly** — Rejected: too slow for search (100ms+ per query vs <10ms from index)
2. **Catalog stores stock locally** — Rejected: violates Warehouse as source of truth (see inventory ADR)
3. **No stock data in Search** — Rejected: filtering by availability is critical for UX

## References

- [Inventory Data Ownership ADR](../05-workflows/integration-flows/inventory-data-ownership-adr.md)
- `catalog/internal/biz/product/product_price_stock.go` — Catalog price/stock logic
- `search/internal/biz/sync_usecase.go` — Search sync pipeline (buildProductIndexDoc)
- [Search & Discovery Architecture](../02-business-domains/content/search-discovery.md)

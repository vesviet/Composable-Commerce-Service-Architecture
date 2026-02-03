# 🔍 Search Service - Product Discovery Flow (Search + Catalog Integration)

**Last Updated**: 2026-01-18  
**Owner**: Platform Engineering  
**Scope**: Search Service (Elasticsearch read model) + Catalog visibility filtering + Pricing/Warehouse enrichment via events

---

## 1) Goal & Boundary

### What Search Service is responsible for
- Serve **product discovery APIs** (search/list/autocomplete/content search)
- Query Elasticsearch indices (products, cms content)
- Apply **warehouse-aware** filtering/sorting using indexed per-warehouse views
- Apply **visibility rules** (hybrid: ES pre-filter + Catalog post-filter)
- Emit/search analytics events (query/click/conversion tracking)

### What Search Service is NOT responsible for
- Source-of-truth product data (Catalog owns)
- Source-of-truth price rules (Pricing owns)
- Source-of-truth stock/reservation (Warehouse owns)

---

## 2) Request-Time Flow: Search Products

### 2.1 Sequence Diagram (happy path)

```mermaid
sequenceDiagram
  autonumber
  participant C as Client (Web/Admin)
  participant G as Gateway
  participant S as Search Service
  participant R as Redis Cache
  participant ES as Elasticsearch
  participant CAT as Catalog Service (visibility)
  participant PG as Postgres (analytics)

  C->>G: GET /api/v1/search/products?q=...&warehouse=...
  G->>G: Resolve warehouse_id (header/middleware)
  G->>S: Forward request + headers (customer context)

  S->>S: Validate request (min/max length, page size)
  S->>R: Get(cacheKey)
  alt cache hit
    R-->>S: cached SearchResult
    S-->>G: response (cached)
    G-->>C: response
  else cache miss
    S->>S: Build SearchQuery (filters, sort, warehouse_id, customerCtx)
    S->>ES: Search(products index)
    ES-->>S: hits + aggregations

    Note over S: Visibility rules (hybrid)
    S->>S: ES pre-filter (age/group/geo hard rules if possible)
    S->>CAT: BatchCheckProductVisibility(productIDs, customerCtx)
    CAT-->>S: visible productIDs
    S->>S: Post-filter hits by visibility

    S->>R: Set(cacheKey, result, TTL)

    par Analytics (best-effort)
      S->>PG: TrackSearch(query, resultCount, warehouse_id, ...)
    end

    S-->>G: response
    G-->>C: response
  end
```

### 2.2 Data shaping rules (what Search returns)
- Source fields come from **indexed document** (product read model)
- Warehouse-aware fields are read from `warehouse_stock[]` (ex: `in_stock`, `sale_price`, `quantity`)
- Visibility filtering happens **after** ES returns hits (post-filter), so:
  - Total hits may be adjusted after visibility
  - Pagination must be careful to avoid “empty page after filtering” (see risks section)

---

## 3) Request-Time Flow: Autocomplete

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant G as Gateway
  participant S as Search Service
  participant R as Redis Cache
  participant ES as Elasticsearch

  C->>G: GET /api/v1/search/autocomplete?q=iph
  G->>S: Forward request

  S->>S: Validate request
  S->>R: Get(autocompleteKey)
  alt cache hit
    R-->>S: suggestions
    S-->>G: suggestions
    G-->>C: suggestions
  else cache miss
    S->>ES: Completion/Prefix suggest query
    ES-->>S: suggestions
    S->>R: Set(autocompleteKey, suggestions, TTL)
    S-->>G: suggestions
    G-->>C: suggestions
  end
```

---

## 4) Request-Time Flow: CMS Content Search

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant G as Gateway
  participant S as Search Service
  participant R as Redis Cache
  participant ES as Elasticsearch

  C->>G: GET /api/v1/search/content?q=return&type=help
  G->>S: Forward request

  S->>R: Get(cmsCacheKey)
  alt cache hit
    R-->>S: cms results
  else cache miss
    S->>ES: Search(cms index)
    ES-->>S: cms hits
    S->>R: Set(cmsCacheKey, cms hits, TTL)
  end

  S-->>G: response
  G-->>C: response
```

---

## 5) Real-Time Indexing Flow (Event-Driven)

### 5.1 High-level event topology

```mermaid
flowchart LR
  CATALOG[Catalog Service] -- catalog.product.created/updated/deleted --> PUB[(Dapr PubSub)]
  PRICING[Pricing Service] -- pricing.price.updated/deleted --> PUB
  WAREHOUSE[Warehouse Service] -- warehouse.inventory.stock_changed --> PUB
  CMS[Catalog CMS] -- catalog.cms.page.* --> PUB

  PUB --> SW[Search Worker (event consumers)]
  SW --> ES[(Elasticsearch)]
  SW --> PG[(Postgres analytics/metadata)]

  SVC[Search API Service] --> ES
  SVC --> R[(Redis cache)]
  SVC --> CATV[Catalog visibility client]
```

### 5.2 Product Created/Updated event handling (happy path)

```mermaid
sequenceDiagram
  autonumber
  participant PUB as PubSub
  participant W as Search Worker
  participant CAT as Catalog Service
  participant ES as Elasticsearch
  participant R as Redis

  PUB->>W: catalog.product.updated
  W->>W: Validate event payload (id, sku, updated_at)
  W->>CAT: GetProduct(product_id)
  CAT-->>W: product detail

  Note over W: Build ES doc (Index)
  W->>W: Map core fields + attributes + visibility_rules metadata

  W->>ES: IndexProduct(doc)
  ES-->>W: ack

  Note over W: Cache invalidation (best-effort)
  W->>R: DeletePattern(search:*product_id:...*)
  R-->>W: deleted count

  W-->>PUB: 200 OK (ack)
```

### 5.3 Price Updated event handling

```mermaid
sequenceDiagram
  autonumber
  participant PUB as PubSub
  participant W as Search Worker
  participant ES as Elasticsearch

  PUB->>W: pricing.price.updated
  W->>W: Validate payload (product_id/sku, warehouse_id, sale_price, currency)
  W->>ES: UpdateProduct(product_id, warehouse_stock[warehouse_id].sale_price)
  ES-->>W: ack
  W-->>PUB: 200 OK
```

### 5.4 Stock Changed event handling

```mermaid
sequenceDiagram
  autonumber
  participant PUB as PubSub
  participant W as Search Worker
  participant ES as Elasticsearch

  PUB->>W: warehouse.inventory.stock_changed
  W->>W: Validate payload (sku_id, warehouse_id, available_for_sale)
  W->>ES: UpdateProductBySKU(sku_id, warehouse_stock[warehouse_id].in_stock/qty)
  ES-->>W: ack
  W-->>PUB: 200 OK
```

---

## 6) Initial Backfill Flow (cmd/sync)

Use this when Elasticsearch is empty, mapping changed, or after major drift.

```mermaid
sequenceDiagram
  autonumber
  participant OP as Operator
  participant SYNC as search/cmd/sync
  participant CAT as Catalog Service
  participant PR as Pricing Service
  participant WH as Warehouse Service
  participant ES as Elasticsearch
  participant DB as Postgres

  OP->>SYNC: Run sync (batch-size=N, status=active)
  SYNC->>ES: EnsureIndex(mapping)
  ES-->>SYNC: ok

  loop page batches
    SYNC->>CAT: ListProducts(page,N,status)
    CAT-->>SYNC: products

    SYNC->>PR: (optional) GetPrices(products, warehouse/currency)
    PR-->>SYNC: prices

    SYNC->>WH: (optional) GetStock(products, warehouse)
    WH-->>SYNC: stock

    SYNC->>SYNC: Merge into Index docs
    SYNC->>ES: BulkIndex(docs)
    ES-->>SYNC: ok

    SYNC->>DB: Save sync status/checkpoint
    DB-->>SYNC: ok
  end

  SYNC-->>OP: Summary (total/indexed/failed)
```

---

## 7) Visibility Filtering (Hybrid Model)

### 7.1 Strategy
- **Pre-filter in ES** (fast): only simple hard rules that can be represented as filters
- **Post-filter via Catalog** (correct): evaluate full rule engine with customer context

### 7.2 Flow

```mermaid
sequenceDiagram
  autonumber
  participant S as Search Service
  participant ES as Elasticsearch
  participant CAT as Catalog Service

  S->>S: Extract customer context (age, groups, location)
  S->>ES: Search with pre-filters (hard age/group/geo)
  ES-->>S: hits
  S->>CAT: BatchCheckProductVisibility(hitIDs, customerCtx)
  CAT-->>S: visibleIDs
  S->>S: Filter hits by visibleIDs
```

### 7.3 Fail-open vs fail-closed (policy)
- Default for commerce: **fail-open** (availability) for Catalog visibility check failures
- For compliance categories (age restricted): consider **fail-safe** behavior

---

## 8) Observability & SLO checkpoints

### Key metrics
- Search latency: p50/p95/p99
- Elasticsearch `took` vs total duration
- Cache hit rate (search + autocomplete)
- Event processing lag (consumer)
- Event failures by type + DLQ count

### Recommended SLOs
- p95 search latency < 200ms
- Event processing lag < 5s
- Cache hit rate > 90% for popular queries

---

## 9) Failure Modes (what to expect)

### 9.1 Elasticsearch slow or degraded
- Search API latency increases
- Autocomplete may fall back or timeout

### 9.2 Catalog visibility unavailable
- If fail-open: results may include restricted products (risk)
- If fail-safe: results may be overly strict (lower discovery)

### 9.3 Event consumer blocked
- Index drift grows (stale price/stock)
- Symptoms: search results inconsistent with product detail

---

## 10) Related Docs
- Search sellable view & warehouse strategy: [search-sellable-view-per-warehouse-complete.md](search-sellable-view-per-warehouse-complete.md)
- Visibility filtering design: [search-product-visibility-filtering.md](search-product-visibility-filtering.md)
- Issues checklist: [search-catalog-product-discovery-flow-issues.md](../checklists/search-catalog-product-discovery-flow-issues.md)

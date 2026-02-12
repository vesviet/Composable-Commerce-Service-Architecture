# 🔍 Search & Product Discovery

**Purpose**: Product search, discovery, catalog sync to Elasticsearch, and content search  
**Domain**: Content Management  
**Services**: Search Service, Catalog Service, Pricing Service, Warehouse Service  
**Last Updated**: 2026-02-12  
**Navigation**: [← Content Domain](../README.md) | [← Business Domains](../../README.md)

---

## 📋 Quick Navigation

| Area | Section | Description |
|------|---------|-------------|
| **Data Sync** | [Initial Backfill (cmd/sync)](#1-initial-backfill-cmdsync) | One-time full sync from Catalog → ES |
| **Data Sync** | [Real-Time Event Sync](#2-real-time-event-sync-worker) | Event-driven incremental updates |
| **Search** | [Product Search](#3-product-search-flow) | Full-text search + filters + facets |
| **Search** | [Autocomplete](#4-autocomplete) | Type-ahead suggestions |
| **Data Read** | [Product Detail Page](#5-product-detail-page-pdp) | How PDP data is assembled |
| **Data Read** | [Product List / Category Page](#6-product-list--category-page) | Listings, filters, sorting |
| **Index** | [Elasticsearch Mapping](#7-elasticsearch-index-mapping) | Document structure in ES |
| **Architecture** | [Data Ownership Matrix](#8-data-ownership-matrix) | Who owns what |

---

## 🏗️ Architecture Overview

```mermaid
graph TB
    subgraph "Write Path (Source of Truth)"
        CAT[("Catalog Service<br/>(PostgreSQL)")]
        PR[("Pricing Service<br/>(PostgreSQL)")]
        WH[("Warehouse Service<br/>(PostgreSQL)")]
    end

    subgraph "Event Bus"
        PUBSUB[("Dapr PubSub<br/>(Redis Streams)")]
    end

    subgraph "Search Service"
        SYNC["cmd/sync<br/>(Initial Backfill)"]
        WORKER["cmd/worker<br/>(Event Consumers)"]
        API["cmd/search<br/>(Query API)"]
        ES[("Elasticsearch<br/>(Read Model)")]
        REDIS[("Redis<br/>(Cache)")]
        PG_ANALYTICS[("PostgreSQL<br/>(Analytics)")]
    end

    CAT -- "catalog.product.*" --> PUBSUB
    PR -- "pricing.price.*" --> PUBSUB
    WH -- "warehouse.inventory.*" --> PUBSUB

    PUBSUB --> WORKER --> ES
    SYNC -- "gRPC" --> CAT
    SYNC -- "gRPC" --> PR
    SYNC -- "gRPC" --> WH
    SYNC --> ES

    API --> ES
    API --> REDIS
    API --> PG_ANALYTICS
    API -- "gRPC (visibility)" --> CAT
```

> [!IMPORTANT]
> **ES is a read model**, not the source of truth. The source of truth is always the upstream service's PostgreSQL database. ES can be rebuilt at any time via `cmd/sync`.

---

## 1. Initial Backfill (`cmd/sync`)

> **Source**: [sync_usecase.go](file:///home/user/microservices/search/internal/biz/sync_usecase.go) | [README_SYNC.md](file:///home/user/microservices/search/README_SYNC.md)

### 1.1 When to Run
- First deployment of Search Service
- After ES index mapping changes
- After major data migration
- Manual re-sync when index has drifted

### 1.2 Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    participant OP as Operator
    participant SYNC as cmd/sync
    participant CAT as Catalog Service (gRPC)
    participant PR as Pricing Service (gRPC)
    participant WH as Warehouse Service (gRPC)
    participant ES as Elasticsearch
    participant DB as Postgres (sync_status)

    OP->>SYNC: Run sync (--status=active --batch-size=100 --currency=VND)
    SYNC->>DB: Check for partial sync (resume capability)
    alt Partial sync exists
        SYNC->>SYNC: Resume from last checkpoint page
    else New sync
        SYNC->>ES: CreateProductIndex("products_YYYYMMDD_HHMMSS")
        Note over SYNC,ES: New index created for zero-downtime swap
    end

    loop Page batches (100 products/page)
        SYNC->>CAT: ListProducts(page, batchSize, status)
        CAT-->>SYNC: products[] + total count

        par Batch fetch enrichments
            SYNC->>PR: GetAllPricesBulk(productIDs, currency)
            PR-->>SYNC: map[productID][]Price (global + warehouse-specific)
        and
            SYNC->>WH: GetBulkStock(productIDs)
            WH-->>SYNC: map[productID][]InventoryItem
        end

        SYNC->>SYNC: buildProductIndexDoc() for each product
        Note over SYNC: Priority price matching:<br/>1. Warehouse-specific price<br/>2. Global price<br/>3. Skip if no price

        SYNC->>ES: BulkIndexProducts(docs, targetIndex)
        SYNC->>DB: Checkpoint progress (every 10 pages)
    end

    SYNC->>ES: Refresh index
    SYNC->>ES: SwitchAlias("products_search", old → new)
    Note over ES: Zero-downtime alias swap
    SYNC-->>OP: Summary (total/synced/failed)
```

### 1.3 buildProductIndexDoc Logic

This is the core data assembly for each product → ES document:

```
For each product from Catalog:
  1. Get inventory[] from WarehouseClient batch map
  2. Get prices[] from PricingClient batch map
  3. Separate prices into: globalPrice + warehousePrices map

  For each inventory item (per warehouse):
    ├── Match price (warehouse-specific > global > skip)
    ├── Calculate: availableStock = quantityAvailable - quantityReserved
    ├── Determine: inStock = inv.InStock AND availableStock > 0
    └── Build WarehouseStockItem {warehouseID, inStock, quantity, basePrice, salePrice, currency}

  4. If NO valid warehouse stock entries → SKIP product (not indexed)
  5. Set main display price from global or first warehouse entry
  6. Return ProductIndex document
```

> [!NOTE]
> Products without any valid price+inventory combination are deliberately **not indexed**. This follows the business rule: "no sellable view → no search result."

### 1.4 Zero-Downtime Reindex Strategy

```mermaid
graph LR
    A["products_search (alias)"] --> B["products_20260210_120000 (old index)"]
    
    C["cmd/sync creates"] --> D["products_20260212_140000 (new index)"]
    D --> E["Bulk index all products into new index"]
    E --> F["Atomic alias swap"]
    F --> G["products_search (alias)"] --> D
    
    B -.-> H["Delete old index (optional, after 24h)"]
```

### 1.5 CLI Usage

```bash
cd search
./bin/sync -conf ./configs -status active -batch-size 100 -currency VND
```

| Flag | Default | Description |
|------|---------|-------------|
| `-conf` | `../../configs` | Config path |
| `-status` | `active` | Product status filter (`active`, `published`, `all`) |
| `-batch-size` | `100` | Products per page |
| `-currency` | `VND` | Currency for prices |

---

## 2. Real-Time Event Sync (Worker)

> **Source**: [product_consumer.go](file:///home/user/microservices/search/internal/service/product_consumer.go) | [price_consumer.go](file:///home/user/microservices/search/internal/service/price_consumer.go) | [consumer.go](file:///home/user/microservices/search/internal/service/consumer.go)

### 2.1 Event Topology

```mermaid
flowchart LR
    subgraph Publishers
        CAT["Catalog Service"]
        PR["Pricing Service"]
        WH["Warehouse Service"]
        PROMO["Promotion Service"]
    end

    subgraph "Dapr PubSub"
        T1["catalog.product.created"]
        T2["catalog.product.updated"]
        T3["catalog.product.deleted"]
        T4["pricing.price.updated"]
        T5["pricing.price.deleted"]
        T6["warehouse.inventory.stock_changed"]
        T7["catalog.cms.page.*"]
        T8["catalog.attribute.config_changed"]
        T9["promotion.applied / expired"]
    end

    subgraph "Search Worker Consumers"
        PC["ProductConsumerService"]
        PRC["PriceConsumerService"]
        SC["StockConsumerService"]
        CC["CmsConsumerService"]
        PMC["PromotionConsumerService"]
    end

    CAT --> T1 & T2 & T3 & T7 & T8
    PR --> T4 & T5
    WH --> T6
    PROMO --> T9

    T1 & T2 & T3 & T8 --> PC
    T4 & T5 --> PRC
    T6 --> SC
    T7 --> CC
    T9 --> PMC

    PC & PRC & SC & CC & PMC --> ES[("Elasticsearch")]
    PC & PRC & SC --> REDIS[("Redis<br/>Cache Invalidation")]
```

### 2.2 Event Processing Details

#### Product Created / Updated

```mermaid
sequenceDiagram
    autonumber
    participant PUB as PubSub
    participant W as ProductConsumerService
    participant CAT as Catalog Service (gRPC)
    participant ES as Elasticsearch
    participant R as Redis

    PUB->>W: catalog.product.created/updated (CloudEvent)
    W->>W: Validate event + Check idempotency
    W->>CAT: GetProduct(product_id) via gRPC
    CAT-->>W: Full product detail
    W->>W: Map to product.Index{} document
    Note over W: Includes: name, SKU, category, brand,<br/>attributes, images, tags, visibility_rules
    W->>ES: IndexProduct(doc) or UpdateProduct(doc)
    ES-->>W: ack

    par Cache Invalidation
        W->>R: DeletePattern("search:*")
        W->>R: DeletePattern("autocomplete:*name*")
    end

    W-->>PUB: 200 OK (ack)
```

#### Price Updated

```mermaid
sequenceDiagram
    autonumber
    participant PUB as PubSub
    participant W as PriceConsumerService
    participant ES as Elasticsearch
    participant R as Redis

    PUB->>W: pricing.price.updated
    W->>W: Validate: product_id, warehouse_id, sale_price, currency
    W->>ES: UpdateProduct(product_id, {warehouse_stock[warehouse_id]: {sale_price, base_price, price_updated_at}})
    Note over W,ES: Partial update on nested warehouse_stock field
    ES-->>W: ack
    W->>R: InvalidatePriceCache(productID, warehouseID)
    W-->>PUB: 200 OK
```

#### Stock Changed

```mermaid
sequenceDiagram
    autonumber
    participant PUB as PubSub
    participant W as StockConsumerService
    participant ES as Elasticsearch
    participant R as Redis

    PUB->>W: warehouse.inventory.stock_changed
    W->>W: Validate: sku_id, warehouse_id, available_for_sale
    W->>ES: UpdateProductBySKU(sku_id, {warehouse_stock[warehouse_id]: {in_stock, quantity}})
    ES-->>W: ack
    W->>R: InvalidateStockCache(skuID, warehouseID)
    W-->>PUB: 200 OK
```

### 2.3 Event Reliability

| Feature | Implementation |
|---------|---------------|
| **Idempotency** | `EventIdempotencyRepo` stores processed event IDs (dedup window) |
| **DLQ** | Failed events → Dead Letter Queue → `DLQConsumerService` for manual retry |
| **Validation** | `ValidatorRegistry` validates all event payloads before processing |
| **Cache Invalidation** | Pattern-based Redis key deletion (`DeletePattern`) after every mutation |
| **Outbox** | Catalog uses Transactional Outbox pattern — event intent saved in same DB tx as business data |

---

## 3. Product Search Flow

> **Source**: [search_usecase.go](file:///home/user/microservices/search/internal/biz/search_usecase.go) | [search_handlers.go](file:///home/user/microservices/search/internal/service/search_handlers.go)

### 3.1 Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    participant C as Client (Web/Mobile)
    participant G as API Gateway
    participant S as Search API (cmd/search)
    participant R as Redis Cache
    participant ES as Elasticsearch
    participant CAT as Catalog Service (visibility)
    participant A as Analytics (async)

    C->>G: GET /api/v1/search/products?q=iphone&warehouse_id=wh-001&page=1
    G->>G: Extract warehouse_id from X-Warehouse-ID header
    G->>S: Forward request + customer context headers

    S->>S: 1. Validate request (min/max query length, page bounds)
    S->>R: 2. Get(cacheKey)
    alt Cache Hit
        R-->>S: Cached SearchResult
        S->>S: Apply visibility filter on cached hits
        S-->>C: Response (cached)
    else Cache Miss
        S->>S: 3. Build SearchQuery
        S->>ES: 4. Search(products_search alias)
        ES-->>S: hits[] + aggregations + spell_correction

        S->>S: 5. Apply PopularityBooster.BoostResults()
        S->>R: 6. Cache result (TTL: default 30min, stock-filtered: 15min)
        
        par Async Analytics
            S->>A: TrackSearch(query, resultCount, warehouseID)
        end

        S->>CAT: 7. BatchCheckProductVisibility(hitIDs, customerCtx)
        CAT-->>S: visibleIDs map
        S->>S: 8. Post-filter hits by visibility (fail-open)

        S-->>G: Response
        G-->>C: Response
    end
```

### 3.2 Pipeline: Validate → Query → Filter → Sort → Return

```
1. VALIDATE
   ├── Trim query, set page defaults (page=1, pageSize=20)
   ├── Enforce max_result_window <= 10,000 (or use cursor pagination)
   └── Require warehouse_id if in_stock filter is active

2. BUILD ES QUERY (query_builder.go)
   ├── Multi-match: name^3, name.ngram^1, description, brand_name, category_name
   ├── Active filter: is_active=true, status=active
   ├── Warehouse stock boost: function_score wraps query with nested in_stock boost
   └── Spell correction: ES phrase_suggester for zero-result queries

3. APPLY FILTERS (filter_builder.go)
   ├── category_ids → terms filter on category_id
   ├── brand_ids → terms filter on brand_id
   ├── price_range → nested warehouse_stock price range (effective_price = min(sale, base))
   ├── on_sale → nested: warehouse_stock.sale_price < warehouse_stock.base_price
   ├── min_rating → range filter on rating
   ├── colors/sizes → terms filter on attributes.color/size.keyword
   ├── attributes.{key} → dynamic terms/range filter
   └── in_stock → nested: warehouse_stock.warehouse_id + in_stock=true

4. APPLY SORT (sort_builder.go)
   ├── Default: _score DESC, nested in_stock DESC (warehouse-aware)
   ├── price_asc/desc → nested warehouse_stock.sale_price sort
   ├── newest → created_at DESC
   ├── rating → rating DESC
   ├── popularity → stock + review_count weighted
   └── Always: _score as tiebreaker

5. AGGREGATE (aggregation_builder.go)
   ├── categories → terms agg on category_id
   ├── brands → terms agg on brand_id  
   └── price_ranges → range agg on price

6. VISIBILITY POST-FILTER
   ├── Extract customer context (age, groups, location) from headers
   ├── Batch call Catalog.BatchCheckProductVisibility()
   ├── Filter hits by visible product IDs
   └── FAIL-OPEN: on error, allow all products through
```

### 3.3 API Endpoint

```
GET /api/v1/search/products

Query params:
  q              string   Search query (empty = browse mode)
  page           int      Page number (default: 1)
  page_size      int      Results per page (default: 20, max: 100)
  sort_by        enum     relevance|price_asc|price_desc|newest|rating|popularity
  warehouse_id   string   Warehouse context (from X-Warehouse-ID header)
  in_stock       bool     Filter to in-stock only (requires warehouse_id)
  category_ids   []string Filter by category
  brand_ids      []string Filter by brand
  price_range    object   {gte: float, lte: float}
  min_rating     float    Minimum rating filter
  on_sale        bool     Products with active sale price
  cursor         string   Cursor for deep pagination (>10k results)
```

### 3.4 Response Structure

```json
{
  "total_hits": 1234,
  "max_score": 12.5,
  "page": 1,
  "page_size": 20,
  "total_pages": 62,
  "next_cursor": "eyJzY29yZSI6MTIuNSwic29ydCI6WzEyLjUsIjIwMjYtMDEtMTUiXX0=",
  "spell_correction": "iphone",
  "results": [
    {
      "id": "prod-uuid-123",
      "name": "iPhone 15 Pro Max",
      "sku": "SKU-IP15PM-256",
      "description": "...",
      "category_id": "cat-electronics",
      "category_name": "Electronics",
      "brand_id": "brand-apple",
      "brand_name": "Apple",
      "price": 999.99,
      "stock": 150,
      "rating": 4.8,
      "review_count": 2340,
      "images": ["https://cdn.example.com/img1.jpg"],
      "tags": ["smartphone", "5g", "flagship"],
      "warehouse_stock": [
        {
          "warehouse_id": "wh-001",
          "in_stock": true,
          "quantity": 50,
          "base_price": 999.99,
          "sale_price": 899.99,
          "currency": "VND"
        }
      ],
      "attributes": {"color": "Space Black", "storage": "256GB"},
      "score": 12.5
    }
  ],
  "facets": [
    {"field": "category_id", "type": "TERMS", "values": [{"key": "cat-electronics", "count": 500}]},
    {"field": "brand_id", "type": "TERMS", "values": [{"key": "brand-apple", "count": 120}]},
    {"field": "price", "type": "RANGE", "values": [{"key": "0-500", "count": 300}]}
  ]
}
```

---

## 4. Autocomplete

> **Source**: [search_usecase.go → Autocomplete/AutocompleteAdvanced](file:///home/user/microservices/search/internal/biz/search_usecase.go#L357-L417) | [autocomplete.go](file:///home/user/microservices/search/internal/data/elasticsearch/autocomplete.go)

### 4.1 Types

| Type | Source | Description |
|------|--------|-------------|
| **Product** | `name.suggest` (completion) + `name.autocomplete` (edge_ngram) | Product name suggestions |
| **Content** | CMS index | Help articles, blog posts |
| **Category** | `category_name.keyword` | Category navigation |
| **Brand** | `brand_name.keyword` | Brand filtering |

### 4.2 Flow

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant S as Search Service
    participant R as Redis
    participant ES as Elasticsearch

    C->>S: GET /api/v1/search/autocomplete?q=iph&limit=10
    S->>S: Validate (min query length check)
    S->>R: Get("autocomplete:advanced:iph:10:product,content:0")
    alt Cache Hit
        R-->>S: suggestions[]
    else Cache Miss
        S->>ES: Completion Suggester + Edge N-gram query
        ES-->>S: suggestions with metadata
        S->>R: Set(key, suggestions, TTL=15min + jitter 0-3min)
        Note over S,R: Jittered TTL prevents thundering herd
    end
    S-->>C: suggestions[]
```

### 4.3 Endpoints

```
GET /api/v1/search/autocomplete     # Simple string suggestions (legacy)
GET /api/v1/search/autocomplete/v2  # Advanced: typed suggestions with metadata
GET /api/v1/search/trending         # Trending searches (cached, jittered TTL)
GET /api/v1/search/popular          # Popular searches by period
```

---

## 5. Product Detail Page (PDP)

> **Source**: [product_read.go → GetProduct](file:///home/user/microservices/catalog/internal/biz/product/product_read.go#L13-L59) | [product_price_stock.go](file:///home/user/microservices/catalog/internal/biz/product/product_price_stock.go)

### 5.1 Data Source: Catalog Service (NOT Search)

Product detail is served by the **Catalog Service** directly, NOT from Elasticsearch.

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant G as Gateway
    participant CAT as Catalog Service
    participant L1 as L1 Cache (In-memory)
    participant L2 as L2 Cache (Redis)
    participant DB as PostgreSQL
    participant WH as Warehouse Service
    participant PR as Pricing Service

    C->>G: GET /api/v1/products/{id}
    G->>CAT: GetProduct(id)

    CAT->>L1: Check L1 cache
    alt L1 Hit
        L1-->>CAT: product
    else L1 Miss
        CAT->>L2: Check L2 cache (Redis)
        alt L2 Hit
            L2-->>CAT: product
            CAT->>L1: Populate L1
        else L2 Miss
            CAT->>DB: SELECT from products + joins
            DB-->>CAT: product
            CAT->>L1: Populate L1
            CAT->>L2: Populate L2
        end
    end

    par Lazy Price/Stock Enrichment
        CAT->>PR: GetBasePrice(productID, currency, warehouseID)
        PR-->>CAT: basePrice, salePrice
    and
        CAT->>WH: GetStock(productID, warehouseID)
        WH-->>CAT: stock count
    end

    CAT->>CAT: Assemble ProductAvailability
    CAT-->>G: Full product + availability
    G-->>C: Product Detail Response
```

### 5.2 Key Differences: PDP vs Search

| Aspect | Product Detail (PDP) | Product List/Search |
|--------|---------------------|-------------------|
| **Data source** | Catalog Service (PostgreSQL) | Search Service (Elasticsearch) |
| **Price/Stock** | Live from Pricing + Warehouse services | Denormalized in ES (may be slightly stale) |
| **Cache** | Multi-layer: L1 (in-memory) → L2 (Redis) → DB | Redis cache (30min TTL) |
| **Attributes** | Full EAV from DB | Flattened map in ES doc |
| **Freshness** | Real-time | Near real-time (event-driven, <5s lag) |

> [!WARNING]
> **Price shown in search results may differ from PDP price.** Search uses the last-indexed price (event latency). PDP always fetches live price. Frontend should re-fetch price on PDP load.

---

## 6. Product List / Category Page

### 6.1 Two Paths: Search Service vs Catalog Service

```mermaid
graph TD
    REQ["Product List Request"] --> DECISION{Has search query<br/>or complex filters?}
    
    DECISION -- "Yes: text search,<br/>facets, multi-filter" --> SEARCH["Search Service<br/>(Elasticsearch)"]
    DECISION -- "No: simple category<br/>browse, admin list" --> CATALOG["Catalog Service<br/>(PostgreSQL + materialized views)"]
    
    SEARCH --> RESP["Product List Response"]
    CATALOG --> RESP
```

### 6.2 Via Search Service (Customer-facing)

**Use for**: Homepage search, category browsing with filters, search results page

```
GET /api/v1/search/products?category_ids=cat-electronics&sort_by=popularity&warehouse_id=wh-001

Pipeline:
  1. SearchUsecase.SearchProducts() ← (same flow as section 3)
  2. Empty query = browse mode (match_all + filters)
  3. Returns: products + facets for sidebar filters + total count for pagination
```

### 6.3 Via Catalog Service (Admin / Simple Browse)

**Use for**: Admin product management, simple paginated browse, internal tools

> **Source**: [product_read.go → ListProducts](file:///home/user/microservices/catalog/internal/biz/product/product_read.go#L161-L327)

```
GET /admin/v1/products?offset=0&limit=20&category_id=xxx&status=active

Pipeline:
  1. ProductUsecase.ListProducts()
  2. Check search result cache for simple queries
  3. Query PostgreSQL materialized views (pre-aggregated)
  4. No facets, no full-text search — just filtered pagination
```

### 6.4 Filter Comparison — Industry Standards

| Filter | Our Implementation | Shopee | Amazon |
|--------|--------------------|--------|--------|
| **Category** | `terms` on `category_id` | ✅ Hierarchical tree | ✅ Category + subcategory |
| **Brand** | `terms` on `brand_id` | ✅ | ✅ |
| **Price Range** | Nested warehouse_stock effective price | ✅ Sliders | ✅ Preset ranges |
| **Rating** | `range` on `rating` (≥ N stars) | ✅ ≥ 4 stars | ✅ ≥ 1-4 stars |
| **On Sale** | Nested: `sale_price < base_price` | ✅ Flash sale / mall | ✅ Deal badge |
| **In Stock** | Nested: `warehouse_stock.in_stock=true` | ✅ | ✅ |
| **Color/Size** | `terms` on `attributes.color/size` | ✅ | ✅ |
| **Dynamic Attrs** | `attributes.{key}` terms/range | ⚠️ Category-specific | ✅ Category-specific |
| **Warehouse** | Nested `warehouse_stock.warehouse_id` | ✅ Location-based | ✅ Fulfillment-based |
| **Spell Correct** | ES `phrase_suggester` on zero results | ✅ | ✅ |
| **Faceted Counts** | ES `terms`/`range` aggregations | ✅ Dynamic | ✅ Dynamic |

### 6.5 Sorting Options

| Sort Key | ES Implementation | Notes |
|----------|------------------|-------|
| `relevance` | `_score` DESC + nested `in_stock` DESC | Default. Stock-boosted via `function_score` |
| `price_asc` | Nested `warehouse_stock.sale_price` ASC | Warehouse-aware, filtered by `warehouse_id` |
| `price_desc` | Nested `warehouse_stock.sale_price` DESC | Same ^^ |
| `newest` | `created_at` DESC | |
| `rating` | `rating` DESC | |
| `popularity` | `stock` DESC + `review_count` weighted | Custom scoring |

---

## 7. Elasticsearch Index Mapping

> **Source**: [mapping.json](file:///home/user/microservices/search/mapping.json)

### 7.1 Index: `products_search` (alias)

| Field | Type | Analyzer | Purpose |
|-------|------|----------|---------|
| `id` | keyword | — | Product UUID |
| `sku` | keyword | — | SKU code |
| `name` | text | `product_analyzer` | Full-text search |
| `name.keyword` | keyword | — | Exact match, sorting |
| `name.ngram` | text | `product_analyzer_with_ngram` | Partial match |
| `name.autocomplete` | text | `autocomplete_analyzer` | Edge n-gram (2-10) |
| `name.suggest` | completion | — | Completion suggester |
| `description` | text | `product_analyzer` | Full-text search |
| `description.ngram` | text | `product_analyzer_with_ngram` | Partial match |
| `category_id` | keyword | — | Category filter |
| `category_name` | text + keyword | `product_analyzer` | Search + exact |
| `brand_id` | keyword | — | Brand filter |
| `brand_name` | text + keyword | `product_analyzer` | Search + exact |
| `price` | double | — | Display price (global/first warehouse) |
| `stock` | long | — | Total stock across warehouses |
| `rating` | double | — | Average rating |
| `review_count` | long | — | Total review count |
| `status` | keyword | — | Product status |
| `is_active` | boolean | — | Active flag |
| `tags` | keyword | — | Tag filter/search |
| `images` | keyword | — | Image URLs |
| `attributes` | object (dynamic) | — | EAV attributes as flat map |
| `created_at` | date | — | Sort by newest |
| `updated_at` | date | — | Last modification |

### 7.2 Nested: `warehouse_stock[]`

| Field | Type | Purpose |
|-------|------|---------|
| `warehouse_id` | keyword | Warehouse identifier |
| `in_stock` | boolean | Available for sale |
| `quantity` | long | Available quantity |
| `base_price` | double | Original price |
| `sale_price` | double | Discounted price |
| `special_price` | double | Promotional price |
| `currency` | keyword | Price currency |
| `price_updated_at` | date | Last price update |

### 7.3 Nested: `visibility_rules[]`

| Field | Type | Purpose |
|-------|------|---------|
| `rule_type` | keyword | Rule category |
| `enforcement_level` | keyword | Soft / hard |
| `min_age` | integer | Age restriction |
| `allowed_groups` / `denied_groups` | keyword[] | Customer group access |
| `restricted_countries/regions/cities` | keyword[] | Geo restriction |

### 7.4 Analyzers

| Analyzer | Tokenizer | Filters | Use |
|----------|-----------|---------|-----|
| `product_analyzer` | standard | lowercase, stop, **synonym_filter**, asciifolding | Main search |
| `product_analyzer_with_ngram` | standard | lowercase, ngram(3-4) | Partial match |
| `autocomplete_analyzer` | standard | lowercase, edge_ngram(2-10) | Type-ahead |

**Synonym examples**: `laptop, notebook, computer, máy tính xách tay` | `phone, mobile, smartphone, điện thoại`

---

## 8. Data Ownership Matrix

```mermaid
graph TB
    subgraph "Source of Truth (Write)"
        CAT_DB["Catalog DB<br/>Products, Categories, Brands,<br/>Attributes, Images, CMS"]
        PR_DB["Pricing DB<br/>Base price, Sale price,<br/>Price rules"]
        WH_DB["Warehouse DB<br/>Inventory, Stock levels,<br/>Reservations"]
        REV_DB["Review DB<br/>Ratings, Review count"]
    end

    subgraph "Read Model (Denormalized)"
        ES_IDX["ES products_search<br/>Merged: product + price + stock + rating"]
    end

    subgraph "Query Patterns"
        PDP["Product Detail Page<br/>→ Catalog (live) + Pricing + Warehouse"]
        SEARCH["Product Search/List<br/>→ Search Service (ES)"]
        ADMIN["Admin Product List<br/>→ Catalog (DB views)"]
    end

    CAT_DB --> ES_IDX
    PR_DB --> ES_IDX
    WH_DB --> ES_IDX
    REV_DB --> ES_IDX

    ES_IDX --> SEARCH
    CAT_DB --> PDP
    CAT_DB --> ADMIN
```

| Data | Source of Truth | Read Model (ES) | PDP Source | Staleness |
|------|----------------|-----------------|------------|-----------|
| Product name, SKU, description | Catalog DB | ✅ Synced | Catalog DB | <5s (event) |
| Category, Brand | Catalog DB | ✅ Synced | Catalog DB | <5s |
| Attributes (EAV) | Catalog DB | ✅ Flattened map | Catalog DB | <5s |
| Images, Tags | Catalog DB | ✅ Synced | Catalog DB | <5s |
| Base Price | Pricing DB | ✅ Per-warehouse nested | Live from Pricing | <5s |
| Sale Price | Pricing DB | ✅ Per-warehouse nested | Live from Pricing | <5s |
| Stock Quantity | Warehouse DB | ✅ Per-warehouse nested | Live from Warehouse | <5s |
| In-Stock Status | Warehouse DB | ✅ Calculated | Live from Warehouse | <5s |
| Rating, Review Count | Review DB | ✅ Synced | Catalog cache | <5m |
| Visibility Rules | Catalog DB | ✅ Nested metadata | Catalog (post-filter) | <5s |

---

## 9. Visibility Filtering (Hybrid Model)

### 9.1 Strategy

| Phase | Where | What | Speed |
|-------|-------|------|-------|
| **Pre-filter** | Elasticsearch | Simple hard rules (age, group, geo) as nested filter on `visibility_rules` | Fast (query-time) |
| **Post-filter** | Catalog Service | Full rule engine with complete customer context | Correct (authoritative) |

### 9.2 Fail-Open Policy

- **Commerce (default)**: On Catalog visibility error → allow all products (availability > restriction)
- **Compliance (age/license)**: Consider fail-safe (stricter, but may reduce discovery)

---

## 10. Performance & Caching

### 10.1 Cache Strategy

| Cache Key Pattern | TTL | Invalidation |
|------------------|-----|--------------|
| `search:{query}:{warehouseID}:{inStock}:{filters}:{page}:{pageSize}:{sort}` | 30min (stock-filtered: 15min) | Pattern delete on product/price/stock event |
| `autocomplete:{query}:{limit}` | 15min + 0-3min jitter | Pattern delete on product update |
| `trending:{limit}` | 15min + jitter | Rebuilt by `TrendingWorker` |
| `spell:correction:{query}` | 24h | Auto-expire |

### 10.2 SLO Targets

| Metric | Target |
|--------|--------|
| Product search p95 | < 200ms |
| Autocomplete p95 | < 50ms |
| Event processing lag | < 5s |
| Cache hit rate | > 80% (search), > 90% (autocomplete) |
| Slow query threshold | 500ms (logged + alerted) |

---

## 11. CMS Content Search

> **Source**: [cms_search_usecase.go](file:///home/user/microservices/search/internal/biz/cms_search_usecase.go) | [cms_consumer.go](file:///home/user/microservices/search/internal/service/cms_consumer.go)

Separate ES index for CMS content (help articles, blog posts, FAQs, policy pages).

```
GET /api/v1/search/content?q=return&type=help&page=1&page_size=10

Flow: same query pipeline but targets cms_content index
Events: catalog.cms.page.created/updated/deleted → CmsConsumerService → ES
```

---

## 📚 Related Documentation

- **[Catalog Management](catalog-management.md)** — Product CRUD, outbox events, materialized views
- **[Review Management](review-management.md)** — Rating and review integration
- **[ADR-012: Search Architecture](../../08-architecture-decisions/ADR-012-search-architecture-elasticsearch.md)** — Architecture decision record
- **[Search OpenAPI](../../04-apis/openapi/search.openapi.yaml)** — API specification
- **[Search Indexing Workflow](../../05-workflows/integration-flows/search-indexing.md)** — Operational workflow

---

**Maintained By**: Platform Engineering  
**Code Refs**: `search/internal/biz/`, `search/internal/service/`, `search/internal/data/elasticsearch/`, `catalog/internal/biz/product/`
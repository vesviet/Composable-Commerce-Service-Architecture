# Search Sellable View per Warehouse - Complete Implementation Guide

**Service:** Search Service  
**Created:** 2025-11-19  
**Status:** 🟡 Planning  
**Priority:** High

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture & Design](#architecture--design)
3. [Gateway Integration](#gateway-integration)
4. [Catalog Cache Strategy](#catalog-cache-strategy)
5. [Realtime Analysis](#realtime-analysis)
6. [Implementation Checklist](#implementation-checklist)
7. [Migration Plan](#migration-plan)

---

## Overview

### Problem Statement

Currently, frontend/admin calls Catalog service to list products (10k+ SKUs), which requires:
- Fan-out calls to Warehouse service for stock (10k calls)
- Fan-out calls to Pricing service for prices (10k calls)
- Fan-out calls to Promotion service for discounts (10k calls)

**This is not scalable** and causes performance issues.

### Solution

**Search Service** will become the "sellable view" per warehouse:
- Maintains read model with `in_stock`, `price`, and `discount` per `warehouse_id`
- Updated via events from Warehouse/Pricing/Promotion services
- Single API call returns all data (no fan-out)
- Supports filter/sort by `in_stock`, `price`, `discount`

### Key Principles

- **Warehouse Context**: All `in_stock`, `price`, `discount` fields are scoped by `warehouse_id` (from gateway header)
- **Eventual Consistency**: Accept 1-5 seconds lag for search/list (near-realtime)
- **Critical Operations**: Checkout/cart still validate directly with warehouse/pricing services (100% realtime)
- **Separation of Concerns**:
  - **Search Service**: Optimized for list/search (10k SKU, filter/sort)
  - **Catalog Service**: Optimized for single product (detail page, admin)

---

## Architecture & Design

### Data Flow

```
┌─────────────────┐
│  Catalog Service│
│  (Product Data) │
└────────┬────────┘
         │ Events (product.created/updated)
         ↓
┌─────────────────┐
│  Search Service │
│  (Read Model)   │
└────────┬────────┘
         │
         ├─── Warehouse Events (stock_changed)
         ├─── Pricing Events (price_changed)
         └─── Promotion Events (discount_changed)
```

### Read Model Structure

**Primary Key**: `(sku_id, warehouse_id)`

**Fields**:
- **From Catalog**: `name`, `description`, `brand`, `category`, `attributes`, `images`, etc.
- **From Warehouse**: `in_stock` (boolean), `available_for_sale` (int64)
- **From Pricing** (future): `base_price`, `currency`
- **From Promotion** (future): `final_price`, `discount_percent`, `promotion_tags`

**Storage Strategy**:
- Option A: Separate table/collection for per-warehouse stock & price view
- Option B: Embedded fields directly in search index/document (depends on search engine)

### Event Contracts

#### Warehouse → Search

**Topic**: `warehouse.inventory.stock_changed`

**Payload**:
```json
{
  "sku_id": "SKU123",
  "warehouse_id": "WH001",
  "available_for_sale": 100,
  "in_stock": true,
  "timestamp": "2025-11-19T10:30:00Z"
}
```

**Idempotency**: Use event ID or `(sku_id, warehouse_id, timestamp)` as key

#### Catalog → Search

**Events**: `catalog.product.created`, `catalog.product.updated`, `catalog.product.deleted`

**Payload**: Product metadata (name, description, category, attributes, etc.)

#### Pricing → Search (Future)

**Topic**: `pricing.product.price_changed`

**Payload**:
```json
{
  "sku_id": "SKU123",
  "warehouse_id": "WH001",
  "base_price": 1000000,
  "currency": "VND",
  "timestamp": "2025-11-19T10:30:00Z"
}
```

#### Promotion → Search (Future)

**Topic**: `promotion.product.discount_changed`

**Payload**:
```json
{
  "sku_id": "SKU123",
  "warehouse_id": "WH001",
  "discount_percent": 10,
  "final_price": 900000,
  "promotion_tags": ["sale", "flash"],
  "timestamp": "2025-11-19T10:30:00Z"
}
```

---

## Gateway Integration

### Current Gateway Implementation

#### ✅ Already Implemented

1. **Warehouse Detection Middleware**
   - **Location**: `gateway/internal/middleware/warehouse_detection.go`
   - Detects warehouse from `X-User-Location` header
   - Sets `X-Warehouse-ID`, `X-Warehouse-Code`, `X-Location-ID` headers
   - Supports default warehouse fallback
   - Redis caching (10min TTL)

2. **Header Forwarding**
   - **Location**: `gateway/internal/router/utils/proxy.go`
   - `CopyHeaders()` automatically forwards all headers (including `X-Warehouse-ID`)
   - No code changes needed

3. **CORS Configuration**
   - Already allows `X-User-Location` and `X-Warehouse-ID` headers

#### ❌ Missing for Search Service

1. **Search Service Definition** (in `gateway.yaml`)
   ```yaml
   search:
     name: search-service
     host: search-service
     port: 80
     grpc_port: 81
     protocol: http
     health_path: /health
     timeout: 30s
     retry:
       attempts: 3
       delay: 1s
     headers:
       X-Service-Name: search-service
       X-Gateway-Version: v1.0.0
   ```

2. **Search Service Routing**
   ```yaml
   routing:
     patterns:
       - prefix: "/api/search-service/"
         service: "search"
         strip_prefix: true
         middleware:
           - "cors"
           - "warehouse_detection"  # Important!
       - prefix: "/api/v1/search/"
         service: "search"
         strip_prefix: false
         middleware:
           - "cors"
           - "warehouse_detection"
   ```

3. **Resource Mapping** (optional, for auto-routing)
   ```yaml
   resource_mapping:
     search:
       service: search
       internal_prefix: /api/v1/search
   ```

### Header Flow

```
Client Request
  ↓
  X-User-Location: LOC123 (optional)
  ↓
Gateway Warehouse Detection Middleware
  ↓
  Calls: GET /api/v1/warehouses/detect/LOC123
  ↓
  Sets: X-Warehouse-ID, X-Warehouse-Code, X-Location-ID
  ↓
Gateway Proxy Handler
  ↓
  CopyHeaders() → Forwards X-Warehouse-ID to Search Service
  ↓
Search Service
  ↓
  Reads X-Warehouse-ID from header
  ↓
  Uses warehouse_id to filter/sort by in_stock
```

### Default Warehouse Behavior

- **Current Config**: `default_warehouse_id: "081395a4-d564-4b13-b66e-1df5aba6aeaa"`
- **Behavior**: If no `X-User-Location` header, gateway uses default warehouse directly
- **For Search**: Search will always have a `warehouse_id` context (either detected or default)

---

## Catalog Cache Strategy

### Current Catalog Cache Implementation

**Location**: `catalog/internal/biz/product/product_price_stock.go`

**Stock Cache**:
- `CacheKeyStockTotal`: Total stock across all warehouses
- `CacheKeyStockWarehouse`: Stock per warehouse
- **TTL**: 5 minutes
- **Source**: Warehouse service (via events or direct call on cache miss)

**Price Cache**:
- `CacheKeyPriceBase`: Base price per currency
- `CacheKeyPriceSale`: Sale price per currency
- **TTL**: 5 minutes
- **Source**: Pricing service (via events or direct call on cache miss)

**Enrichment**: Applied to all product responses (detail, list, search, category)

### Can We Remove Cache?

#### ❌ **NO - Cannot Remove Completely**

**Reasons**:
1. **Product Detail Performance**: Single product query needs fast response (cache provides ~50-200ms savings)
2. **Different Use Cases**: Search = list/search, Catalog = single product detail
3. **Resilience**: Fallback when search service is down
4. **Admin/CMS**: Direct product queries don't go through search

#### ✅ **YES - Can Simplify/Reduce Scope**

**What We CAN Remove/Simplify**:

1. **Remove Warehouse-Specific Logic**
   - Keep only global stock/price cache
   - Remove `GetStockByWarehouse()`, `GetBasePriceFromCacheWithWarehouse()`
   - Simplify to: `GetStockFromCache()`, `GetBasePriceFromCache()` (global only)

2. **Remove from List/Search Endpoints**
   - If frontend/admin switches to search service:
     - `GET /api/v1/catalog/products` (list) - remove stock/price enrichment
     - `GET /api/v1/catalog/products/search` - remove stock/price enrichment
   - Keep cache only for **product detail** endpoint

3. **Remove Event Listeners**
   - Remove stock/price event handlers (search handles events)
   - Keep only product metadata events
   - Cache becomes "lazy" (only on cache miss, not proactive sync)

4. **Increase Cache TTL**
   - Current: 5 minutes
   - Increase to 10-15 minutes (backup cache)

### Recommended Approach

**Phase 1: Keep Cache, Simplify Logic**
- Keep stock/price cache in catalog service
- Simplify to global-only (remove warehouse-specific)
- Keep for product detail endpoint only
- Remove from list/search endpoints

**Phase 2: Make Cache Lazy**
- Remove event listeners for stock/price
- Make cache "lazy" - only populate on cache miss
- Increase TTL to 10-15 minutes

**Phase 3: Evaluate Removal (Future)**
- Monitor cache hit rates for 1-2 months
- If hit rate < 10% and performance acceptable → Remove cache

---

## Realtime Analysis

### Stock Cache Realtime Characteristics

#### Catalog Service (Current)

| Method | Realtime Level | Latency | Use Case |
|--------|---------------|---------|----------|
| Event-driven | Near-realtime | 1-5 seconds | Primary update method |
| Cron job | Not realtime | 1 minute | Backup sync |
| Cache miss | Realtime | 50-200ms | Fallback |

**Overall**: **Near-realtime** (1-5 seconds lag via events, realtime on cache miss)

#### Search Service (Planned)

| Method | Realtime Level | Latency | Use Case |
|--------|---------------|---------|----------|
| Event-driven | Near-realtime | 1-5 seconds | Primary update method |
| No cron job | N/A | N/A | Not needed (read model) |
| No cache miss | N/A | N/A | All data in search index |

**Overall**: **Near-realtime** (1-5 seconds lag via events, eventual consistency)

### When is Stock 100% Realtime?

**Scenarios with 100% Realtime Stock**:
1. **Cache Miss**: First request or expired cache → direct call to warehouse
2. **Admin Operations**: Bypass cache for critical operations
3. **Checkout/Cart**: Call warehouse service directly (don't rely on cache)

**Scenarios with Near-Realtime Stock**:
1. **Event-Driven Updates**: Stock changes → event published → cache updated (1-5 seconds)
2. **Cached Requests**: Subsequent requests use cache (may be 1-5 seconds stale)

### Recommendations

**For Product Detail Page (Catalog)**:
- ✅ Use event-driven cache (near-realtime, 1-5 seconds)
- ✅ Cache miss fallback (realtime when needed)
- ✅ Cron job backup (1 minute sync)

**For Checkout/Cart (Critical Operations)**:
- ❌ **Don't rely on cache**
- ✅ **Call warehouse service directly** for stock validation
- ✅ **Real-time stock check** before order creation

**For Search Service (List/Search)**:
- ✅ Event-driven updates (near-realtime, 1-5 seconds)
- ✅ Eventual consistency acceptable
- ✅ No direct calls (all data in search index)

---

## Implementation Checklist

### 1. Requirements & Scope

- [ ] **Clarify primary use cases**: product search + product list will use `search-service` (no direct `catalog` calls for large listings)
- [ ] **Define `in_stock` clearly**: a SKU is `in_stock` if `available_for_sale > 0` at a specific `warehouse_id`
- [ ] **Confirm primary dimension**: all `in_stock`, `price`, and `discount` fields are scoped by `warehouse_id` (provided via header/gateway)
- [ ] **Define consistency level**: accept eventual consistency for search/list, while checkout and order flows still validate directly with `warehouse`, `pricing`, and `promotion` services

### 2. Contract & API Design (Search Service)

- [ ] **Design search/list request**:
  - [ ] Include `warehouse_id` context (from header or query param, but documented and standardized)
  - [ ] Add `in_stock=true/false` filter (default: no filter)
  - [ ] Add `in_stock` sort option (in-stock items first), plus secondary sort (e.g., relevance, price)
- [ ] **Design response structure**:
  - [ ] Each item includes `in_stock` (scoped to `warehouse_id`)
  - [ ] (Optional) Include `available_quantity` / `available_for_sale` if the UI needs it
  - [ ] (Future) Include `base_price`, `final_price`, and `discount_percent` scoped by `warehouse_id`
- [ ] **Update gateway docs**: confirm the gateway forwards `warehouse_id` correctly to search-service

### 3. Data Model & View in Search

- [ ] **Design the read model / view** for search:
  - [ ] Primary key: `(sku_id, warehouse_id)`
  - [ ] Fields from `catalog`: name, description, brand, category, attributes, images, etc.
  - [ ] Fields from `warehouse`: `in_stock`, `available_for_sale` (or `available_quantity`)
  - [ ] Fields from `pricing` (future): `base_price`, `currency`
  - [ ] Fields from `promotion` (future): `final_price`, `discount_percent`, `promotion_tags`
- [ ] **Decide storage strategy**:
  - [ ] Separate table/collection for per-warehouse stock & price view
  - [ ] Or embedded fields directly in the search index/document (depends on search engine)
- [ ] **Define required indexes** (e.g., by `warehouse_id`, `in_stock`, `sku_id`)

### 4. Event Contracts from Other Services

- [ ] **Warehouse → Search**:
  - [ ] Define topic (e.g., `warehouse.inventory.stock_changed`)
  - [ ] Define payload: `sku_id`, `warehouse_id`, `available_for_sale`, `in_stock`, timestamp
  - [ ] Document idempotency key / versioning to handle out-of-order updates
- [ ] **Catalog → Search**:
  - [ ] Identify events when product/SKU changes (create/update/delete)
  - [ ] Payload: product metadata required for search (name, category, attributes, etc.)
- [ ] **Pricing → Search** (future):
  - [ ] Define topic for price changes: `pricing.product.price_changed`
  - [ ] Payload: `sku_id`, `warehouse_id` (or sales channel), `base_price`, `currency`
- [ ] **Promotion → Search** (future):
  - [ ] Define topic for discount changes: `promotion.product.discount_changed`
  - [ ] Payload: `sku_id`, `warehouse_id`, `discount_percent`, `final_price`, plus optional tags/campaign info

### 5. Search Service – Event Consumers & Sync

- [ ] **Design Dapr gRPC worker(s) in search**:
  - [ ] Subscribe to `warehouse.inventory.stock_changed` to update the stock view
  - [ ] Subscribe to catalog events to sync product metadata
  - [ ] (Future) Subscribe to `pricing` and `promotion` topics to sync price/discount
- [ ] **Initial sync (backfill) strategy**:
  - [ ] Batch job to load current stock from warehouse into search for the first full sync
  - [ ] Batch job(s) to load current prices and promotions if needed
- [ ] **Retry & dead-letter strategy**:
  - [ ] Define retry behavior when updating the view fails
  - [ ] Define logging and DLQ (dead-letter queue) behavior for failed events

### 6. Query Logic in Search

- [ ] **Standard search/list flow**:
  - [ ] Step 1: filter by text/category/attributes as currently implemented
  - [ ] Step 2: join/lookup the `(sku_id, warehouse_id)` view to fetch `in_stock` and pricing
  - [ ] Step 3: if client sends `in_stock=true`, filter to only items with `in_stock=true`
  - [ ] Step 4: apply sorting by `in_stock` (true first), then secondary sorting (price, relevance, etc.)
- [ ] **Fallback / behavior when stock data is missing**:
  - [ ] Clearly define behavior if no stock record exists for `(sku_id, warehouse_id)` (e.g., treat as `in_stock=false` or exclude SKU)
  - [ ] Document this behavior for frontend/admin consumers

### 7. Gateway Integration

- [ ] **Add Search Service Definition**:
  - [ ] Add to `gateway/configs/gateway.yaml` → `services` section
  - [ ] Define host, port, health path, timeout, retry config
- [ ] **Add Search Routes**:
  - [ ] Add routing patterns for `/api/search-service/*` and `/api/v1/search/*`
  - [ ] Apply `warehouse_detection` middleware to ensure `X-Warehouse-ID` is set
- [ ] **Verify Header Forwarding**:
  - [ ] Gateway already forwards all headers via `CopyHeaders()`
  - [ ] `X-Warehouse-ID` set by middleware will be automatically forwarded
  - [ ] Test warehouse detection on search routes
  - [ ] Test header forwarding to search service
  - [ ] Verify default warehouse fallback works

### 8. Frontend/Admin Integration

- [ ] **Frontend/Admin**:
  - [ ] Update to call search-service instead of catalog for large product lists
  - [ ] Add filter option "Only show in-stock items" based on `in_stock=true`
  - [ ] Add sort option "Prioritize in-stock items" (sort by `in_stock` + secondary sort)
  - [ ] Update UI to display `in_stock`, `price`, and `discount` for the current warehouse

### 9. Catalog Cache Simplification

- [ ] **Document current catalog cache usage metrics**
- [ ] **Simplify catalog cache to global-only** (remove warehouse-specific)
- [ ] **Remove stock/price enrichment from list/search endpoints** (if using search service)
- [ ] **Remove stock/price event listeners from catalog** (search handles events)
- [ ] **Make cache "lazy"** (only on miss)
- [ ] **Increase cache TTL to 10-15 minutes**

### 10. Validation, Monitoring & Rollout

- [ ] **Functional validation**:
  - [ ] Verify search/filter/sort by `in_stock` across multiple warehouses
  - [ ] Randomly compare `in_stock` values from search with real warehouse data to measure drift
- [ ] **Monitoring**:
  - [ ] Metrics for sync lag between warehouse/pricing/promotion and search (staleness)
  - [ ] Metrics for event/consumer error rates when updating the view
  - [ ] Monitor cache hit rates for 1-2 months
- [ ] **Rollout strategy**:
  - [ ] Gradually enable the new view behind a feature flag (start with specific use cases/tenants)
  - [ ] Keep a fallback path: during early stages, allow some screens to still use direct catalog access if needed
  - [ ] Evaluate removal after monitoring period

---

## Migration Plan

### Phase 1: Gateway & Search Service Setup

1. **Gateway Configuration**
   - Add search service definition to `gateway.yaml`
   - Add search routing patterns with `warehouse_detection` middleware
   - Test warehouse detection and header forwarding

2. **Search Service - Basic Infrastructure**
   - Set up read model/view structure
   - Implement Dapr gRPC worker for event consumption
   - Create initial sync (backfill) job

### Phase 2: Stock Integration

1. **Event Contract**
   - Define `warehouse.inventory.stock_changed` event schema
   - Implement event handler in search service
   - Test event processing and view updates

2. **Search API**
   - Add `in_stock` filter and sort options
   - Update response to include `in_stock` field
   - Test search/list with stock filtering

3. **Frontend/Admin Migration**
   - Switch list/search to use search service
   - Add `in_stock` filter UI
   - Add `in_stock` sort option

### Phase 3: Price & Discount Integration (Future)

1. **Pricing Integration**
   - Define `pricing.product.price_changed` event schema
   - Implement event handler
   - Add price fields to search response

2. **Promotion Integration**
   - Define `promotion.product.discount_changed` event schema
   - Implement event handler
   - Add discount fields to search response

### Phase 4: Catalog Cache Simplification

1. **Remove Warehouse-Specific Logic**
   - Simplify to global-only cache
   - Remove `GetStockByWarehouse()` methods

2. **Remove from List/Search Endpoints**
   - Remove stock/price enrichment from catalog list/search
   - Keep only for product detail

3. **Remove Event Listeners**
   - Remove stock/price event handlers from catalog
   - Make cache "lazy" (only on miss)

### Phase 5: Monitoring & Optimization

1. **Monitor for 1-2 months**
   - Cache hit rates
   - Search service performance
   - Event processing lag
   - Data consistency (search vs warehouse)

2. **Optimize**
   - Tune cache TTLs
   - Optimize event processing
   - Fine-tune search queries

3. **Evaluate Removal**
   - If cache hit rate < 10% and performance acceptable → Remove catalog cache
   - If cache still useful → Keep as backup

---

## Success Criteria

- [ ] ✅ Search response time <200ms (p95)
- [ ] ✅ Autocomplete <100ms
- [ ] ✅ Zero-result rate <10%
- [ ] ✅ Search-to-purchase conversion >5%
- [ ] ✅ Click-through rate >15%
- [ ] ✅ Stock sync lag <5 seconds (p95)
- [ ] ✅ Event processing error rate <0.1%
- [ ] ✅ Search service uptime >99.9%

---

## References

- Gateway Warehouse Detection: `gateway/internal/middleware/warehouse_detection.go`
- Gateway Header Forwarding: `gateway/internal/router/utils/proxy.go`
- Catalog Stock Cache: `catalog/internal/biz/product/product_price_stock.go`
- Catalog Event Handlers: `catalog/internal/data/eventbus/warehouse_stock_update.go`
- Gateway Config: `gateway/configs/gateway.yaml`
- Gateway Warehouse Detection Docs: `gateway/WAREHOUSE_DETECTION.md`

---

**Last Updated**: 2025-11-19  
**Status**: Planning Phase


# Search Service Data Synchronization Architecture

**Last Updated:** 2025-12-01  
**Status:** ✅ Implemented

---

## Overview

The Search Service maintains a denormalized read model in Elasticsearch by synchronizing data from three source services:
1. **Catalog Service** - Product metadata
2. **Warehouse Service** - Inventory/stock data
3. **Pricing Service** - Price data

**Synchronization Strategy:**
- **Initial Sync (Backfill):** Bulk load existing data on first deployment
- **Real-time Sync:** Event-driven updates via Dapr pub/sub

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA SYNCHRONIZATION FLOW                     │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   CATALOG    │         │  WAREHOUSE   │         │   PRICING    │
│   SERVICE    │         │   SERVICE    │         │   SERVICE    │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                        │
       │ Events                 │ Events                 │ Events
       │                        │                        │
       ▼                        ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                        DAPR PUB/SUB                              │
│  Topics:                                                         │
│  • catalog.product.created                                       │
│  • catalog.product.updated                                       │
│  • catalog.product.deleted                                       │
│  • catalog.attribute.config_changed                              │
│  • warehouse.inventory.stock_changed                             │
│  • pricing.price.updated                                         │
│  • pricing.warehouse_price.updated                               │
│  • pricing.sku_price.updated                                     │
│  • pricing.price.deleted                                         │
└─────────────────────────────────────────────────────────────────┘
       │                        │                        │
       │ Subscribe              │ Subscribe              │ Subscribe
       ▼                        ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SEARCH SERVICE                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Product    │  │    Stock     │  │    Price     │          │
│  │   Consumer   │  │   Consumer   │  │   Consumer   │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                            │                                     │
│                            ▼                                     │
│                  ┌──────────────────┐                            │
│                  │  Index Manager   │                            │
│                  └────────┬─────────┘                            │
│                           │                                      │
│                           ▼                                      │
│                  ┌──────────────────┐                            │
│                  │  Elasticsearch   │                            │
│                  │  Product Index   │                            │
│                  └──────────────────┘                            │
└─────────────────────────────────────────────────────────────────┘

INITIAL SYNC (Backfill):
┌──────────────┐    gRPC/HTTP    ┌──────────────┐
│ Sync Command │ ──────────────> │ Catalog API  │
│              │                 │ Warehouse API│
│              │                 │ Pricing API  │
└──────┬───────┘                 └──────────────┘
       │
       │ Bulk Index
       ▼
┌──────────────────┐
│  Elasticsearch   │
│  Product Index   │
└──────────────────┘
```

---

## 1. Initial Sync (Backfill)

### Purpose
Load existing products, stock, and prices into Elasticsearch when:
- First deploying search service
- Rebuilding search index
- After data migration
- Manual re-sync when index is out of sync

### Implementation

**Command:** `search/cmd/sync/main.go`

**Process Flow:**
```go
1. Fetch products from Catalog (paginated, batch_size=100)
   └─> GET /api/v1/products?page=1&page_size=100&status=active

2. For each product:
   a. Fetch inventory from Warehouse
      └─> GET /api/v1/inventory/product/{product_id}
   
   b. Fetch prices from Pricing
      └─> POST /api/v1/prices/bulk (product_ids, currency)
   
   c. Build Elasticsearch document:
      {
        "id": "product-123",
        "sku": "SKU-123",
        "name": "Product Name",
        "description": "...",
        "category_id": "cat-1",
        "brand_id": "brand-1",
        "status": "active",
        "is_active": true,
        "tags": ["tag1", "tag2"],
        "images": [...],
        "attributes": {...},
        "warehouse_stock": [
          {
            "warehouse_id": "WH-001",
            "in_stock": true,
            "quantity": 100,
            "base_price": 99.99,
            "sale_price": 79.99,
            "currency": "VND",
            "price_updated_at": "2024-12-01T10:00:00Z"
          }
        ],
        "stock": 100,  // Total across all warehouses
        "price": 99.99,  // Global price or first available
        "currency": "VND",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-12-01T10:00:00Z"
      }
   
   d. Index to Elasticsearch
      └─> PUT /products/_doc/{product_id}

3. Continue until all products synced
```

**Usage:**
```bash
# Run sync command
./bin/sync -conf ./configs \
  -status active \
  -batch-size 100 \
  -currency VND \
  -catalog-url http://catalog-service:80 \
  -warehouse-url http://warehouse-service:80 \
  -pricing-url http://pricing-service:80

# Or via Docker
docker run -e RUN_SYNC=true search-service:latest
```

**Configuration:**
- `status`: Filter products by status (active, published, all)
- `batch_size`: Products per page (default: 100)
- `currency`: Currency for prices (default: VND)
- Service URLs: Override config with CLI flags

**Error Handling:**
- If product fails → log error, continue with next
- If Warehouse unavailable → index without stock
- If Pricing unavailable → index without prices
- Sync is idempotent (can run multiple times)

---

## 2. Real-time Sync (Event-Driven)

### 2.1 Catalog Service Events

**Events Published:**
```go
// catalog/internal/biz/product/product_write.go

// When product created
Topic: "catalog.product.created"
Event: {
  "event_type": "catalog.product.created",
  "product_id": "uuid",
  "sku": "SKU-123",
  "name": "Product Name",
  "description": "...",
  "category_id": "cat-1",
  "brand_id": "brand-1",
  "status": "active",
  "is_active": true,
  "tags": ["tag1"],
  "images": [...],
  "attributes": {...},
  "timestamp": "2024-12-01T10:00:00Z"
}

// When product updated
Topic: "catalog.product.updated"
Event: {
  "event_type": "catalog.product.updated",
  "product_id": "uuid",
  "sku": "SKU-123",
  "name": "Updated Name",
  // ... same fields as created
  "timestamp": "2024-12-01T10:00:00Z"
}

// When product deleted
Topic: "catalog.product.deleted"
Event: {
  "event_type": "catalog.product.deleted",
  "product_id": "uuid",
  "sku": "SKU-123",
  "timestamp": "2024-12-01T10:00:00Z"
}

// When attribute config changed (affects indexing)
Topic: "catalog.attribute.config_changed"
Event: {
  "event_type": "catalog.attribute.config_changed",
  "attribute_id": "attr-1",
  "code": "color",
  "is_searchable": true,
  "is_filterable": true,
  "is_indexed": true,
  "timestamp": "2024-12-01T10:00:00Z"
}
```

**Search Service Handler:**
```go
// search/internal/data/eventbus/product_consumer.go

func (c ProductConsumer) HandleProductCreated(ctx, event) {
  1. Decode event data
  2. Fetch full product from Catalog (to get complete data)
  3. Fetch inventory from Warehouse
  4. Fetch prices from Pricing
  5. Build Elasticsearch document
  6. Index to Elasticsearch
}

func (c ProductConsumer) HandleProductUpdated(ctx, event) {
  1. Decode event data
  2. Fetch updated product from Catalog
  3. Fetch current inventory from Warehouse
  4. Fetch current prices from Pricing
  5. Update Elasticsearch document
}

func (c ProductConsumer) HandleProductDeleted(ctx, event) {
  1. Decode event data
  2. Delete from Elasticsearch by product_id
}

func (c ProductConsumer) HandleAttributeConfigChanged(ctx, event) {
  1. Decode event data
  2. If is_indexed changed → re-index affected products
  3. Fetch products using this attribute from Catalog
  4. Re-index each product with updated attribute config
}
```


### 2.2 Warehouse Service Events

**Events Published:**
```go
// warehouse/internal/biz/inventory/inventory.go

// When stock changes (update, adjust, transfer)
Topic: "warehouse.inventory.stock_changed"
Event: {
  "event_type": "warehouse.inventory.stock_changed",
  "warehouse_id": "WH-001",
  "product_id": "uuid",
  "sku_id": "SKU-123",
  "quantity_available": 100,
  "quantity_reserved": 20,
  "available_stock": 80,  // quantity_available - quantity_reserved
  "in_stock": true,
  "movement_type": "updated",  // or "adjusted", "transferred", "detected"
  "timestamp": "2024-12-01T10:00:00Z"
}
```

**Triggers:**
1. **UpdateInventory** - Manual stock update
2. **AdjustInventory** - Stock adjustment (correction)
3. **TransferStock** - Stock transfer between warehouses
4. **StockChangeDetectorJob** - Cron job detects changes (every 5 min)

**Search Service Handler:**
```go
// search/internal/data/eventbus/stock_consumer.go

func (c StockConsumer) HandleStockChanged(ctx, event) {
  1. Decode event data
  2. Find product in Elasticsearch by product_id or sku_id
  3. Update warehouse_stock array:
     - Find warehouse entry by warehouse_id
     - Update quantity, in_stock, available_stock
     - Keep prices unchanged
  4. Recalculate total stock (sum across warehouses)
  5. Update Elasticsearch document (partial update)
}
```

**Elasticsearch Update:**
```json
// Partial update - only warehouse_stock field
POST /products/_update/{product_id}
{
  "script": {
    "source": "
      // Find warehouse in array
      for (item in ctx._source.warehouse_stock) {
        if (item.warehouse_id == params.warehouse_id) {
          item.quantity = params.quantity;
          item.in_stock = params.in_stock;
          item.available_stock = params.available_stock;
        }
      }
      // Recalculate total stock
      ctx._source.stock = ctx._source.warehouse_stock.stream()
        .filter(w -> w.in_stock)
        .mapToLong(w -> w.quantity)
        .sum();
    ",
    "params": {
      "warehouse_id": "WH-001",
      "quantity": 100,
      "in_stock": true,
      "available_stock": 80
    }
  }
}
```

---

### 2.3 Pricing Service Events

**Events Published:**
```go
// pricing/internal/biz/dynamic/dynamic_pricing.go

// Global price updated
Topic: "pricing.price.updated"
Event: {
  "event_type": "pricing.price.updated",
  "product_id": "uuid",
  "sku": null,
  "warehouse_id": null,
  "base_price": 99.99,
  "sale_price": 79.99,
  "currency": "VND",
  "is_active": true,
  "timestamp": "2024-12-01T10:00:00Z"
}

// Warehouse-specific price updated
Topic: "pricing.warehouse_price.updated"
Event: {
  "event_type": "pricing.warehouse_price.updated",
  "product_id": "uuid",
  "sku": null,
  "warehouse_id": "WH-001",
  "base_price": 99.99,
  "sale_price": 79.99,
  "currency": "VND",
  "is_active": true,
  "timestamp": "2024-12-01T10:00:00Z"
}

// SKU-specific price updated
Topic: "pricing.sku_price.updated"
Event: {
  "event_type": "pricing.sku_price.updated",
  "product_id": "uuid",
  "sku": "SKU-123",
  "warehouse_id": null,
  "base_price": 99.99,
  "sale_price": 79.99,
  "currency": "VND",
  "is_active": true,
  "timestamp": "2024-12-01T10:00:00Z"
}

// Price deleted
Topic: "pricing.price.deleted"
Event: {
  "event_type": "pricing.price.deleted",
  "product_id": "uuid",
  "sku": "SKU-123",
  "warehouse_id": "WH-001",
  "timestamp": "2024-12-01T10:00:00Z"
}
```

**Triggers:**
1. **Dynamic Pricing Rules** - Automated price adjustments
2. **Manual Price Updates** - Admin updates prices
3. **Bulk Price Updates** - Batch price changes

**Search Service Handler:**
```go
// search/internal/data/eventbus/price_consumer.go

func (c PriceConsumer) HandlePriceUpdated(ctx, event) {
  1. Decode event data
  2. Find product in Elasticsearch by product_id
  3. Update price based on scope:
     
     If warehouse_id != null:
       // Update warehouse-specific price
       - Find warehouse in warehouse_stock array
       - Update base_price, sale_price, currency
       - Set price_updated_at
     
     Else if sku != null:
       // Update SKU-specific price (if product has this SKU)
       - Update global price fields
     
     Else:
       // Update global price
       - Update price, currency fields
       - Also update all warehouse entries without specific prices
  
  4. Update Elasticsearch document (partial update)
}

func (c PriceConsumer) HandlePriceDeleted(ctx, event) {
  1. Decode event data
  2. Find product in Elasticsearch
  3. Remove price based on scope:
     - If warehouse_id: Remove price from warehouse entry
     - If global: Remove global price
  4. Update Elasticsearch document
}
```

---

## 3. Event Flow & Idempotency

### 3.1 Event Idempotency

**Problem:** Events may be delivered multiple times (at-least-once delivery)

**Solution:** Event idempotency tracking

```sql
-- search/migrations/007_create_event_idempotency_table.sql

CREATE TABLE IF NOT EXISTS event_idempotency (
    event_id VARCHAR(255) PRIMARY KEY,
    
    -- Event metadata
    topic VARCHAR(255) NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    source VARCHAR(255),
    pubsub_name VARCHAR(255),
    
    -- Processing information
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processing_duration_ms INTEGER,
    success BOOLEAN DEFAULT true,
    
    -- Event data hash (optional, for additional verification)
    data_hash VARCHAR(64),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_event_idempotency_topic ON event_idempotency(topic);
CREATE INDEX idx_event_idempotency_event_type ON event_idempotency(event_type);
CREATE INDEX idx_event_idempotency_processed_at ON event_idempotency(processed_at);
CREATE INDEX idx_event_idempotency_created_at ON event_idempotency(created_at);
CREATE INDEX idx_event_idempotency_topic_processed_at ON event_idempotency(topic, processed_at);
```

**Processing Logic:**
```go
// search/internal/service/event_helpers.go (or similar)

func ProcessEvent(ctx, event) error {
  // 1. Check if already processed
  if IsEventProcessed(ctx, event.ID) {
    log.Info("Event already processed, skipping")
    return nil  // Idempotent
  }
  
  // 2. Process event
  startTime := time.Now()
  err := HandleEvent(ctx, event)
  processingDuration := time.Since(startTime)
  
  if err != nil {
    // Save to DLQ on failure
    SaveToDLQ(ctx, event, err)
    return err  // Will retry
  }
  
  // 3. Mark as processed
  MarkEventProcessed(ctx, &EventIdempotency{
    EventID:            event.ID,
    Topic:              event.Topic,
    EventType:          event.Type,
    Source:             event.Source,
    PubsubName:         event.PubsubName,
    ProcessedAt:        time.Now(),
    ProcessingDuration: processingDuration,
    Success:            true,
  })
  
  return nil
}
```

**Note:** Implementation includes:
- Event ID as primary key (not auto-increment ID)
- Processing duration tracking
- Success/failure tracking
- Topic and event_type for filtering
- Data hash for additional verification (optional)

### 3.2 Failed Events & DLQ

**Dead Letter Queue (DLQ):** Failed events are moved to DLQ for manual retry

**DLQ Topics:**
- `dlq.catalog.product.created`
- `dlq.catalog.product.updated`
- `dlq.catalog.product.deleted`
- `dlq.warehouse.inventory.stock_changed`
- `dlq.pricing.price.updated`
- `dlq.pricing.warehouse_price.updated`
- `dlq.pricing.sku_price.updated`
- `dlq.pricing.price.deleted`

**Failed Events Table:**
```sql
-- search/migrations/006_create_failed_events_table.sql

CREATE TABLE IF NOT EXISTS failed_events (
    id VARCHAR(255) PRIMARY KEY,
    event_id VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    source VARCHAR(255),
    pubsub_name VARCHAR(255),
    data JSONB NOT NULL,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending', -- pending, retrying, resolved, ignored
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP
);

CREATE INDEX idx_failed_events_topic ON failed_events(topic);
CREATE INDEX idx_failed_events_status ON failed_events(status);
CREATE INDEX idx_failed_events_created_at ON failed_events(created_at);
```

**Manual Retry:**
```bash
# Retry failed events via HTTP endpoint
POST /events/dlq/catalog.product.created
POST /events/dlq/warehouse.inventory.stock_changed
POST /events/dlq/pricing.price.updated
```

---

## 4. Data Consistency Guarantees

### 4.1 Eventual Consistency

**Model:** Search service uses eventual consistency
- Source services are source of truth
- Search index is a read model (denormalized)
- Updates propagate via events (typically <1 second)
- Temporary inconsistencies are acceptable

### 4.2 Consistency Scenarios

**Scenario 1: Product Created**
```
T0: Catalog creates product → DB committed
T1: Event published to Dapr
T2: Search receives event
T3: Search fetches product, stock, prices
T4: Search indexes to Elasticsearch
T5: Product searchable

Delay: T5 - T0 ≈ 100-500ms (typical)
```

**Scenario 2: Stock Updated**
```
T0: Warehouse updates stock → DB committed
T1: Event published to Dapr
T2: Search receives event
T3: Search updates Elasticsearch (partial update)
T4: Updated stock visible in search

Delay: T4 - T0 ≈ 50-200ms (typical)
```

**Scenario 3: Price Updated**
```
T0: Pricing updates price → DB committed
T1: Event published to Dapr
T2: Search receives event
T3: Search updates Elasticsearch (partial update)
T4: Updated price visible in search

Delay: T4 - T0 ≈ 50-200ms (typical)
```

### 4.3 Handling Inconsistencies

**Detection:**
- Monitor event processing lag
- Compare source data with search index
- Alert on large discrepancies

**Resolution:**
1. **Automatic:** Event retry mechanism
2. **Manual:** Re-sync specific products
3. **Full:** Run initial sync command

---

## 5. Performance Considerations

### 5.1 Initial Sync Performance

**Metrics:**
- Batch size: 100 products/page
- Processing time: ~100ms/product (with stock + prices)
- Total time: ~10 seconds per 1000 products
- Parallelization: Sequential (to avoid overwhelming services)

**Optimization:**
- Increase batch size for faster sync (trade-off: memory)
- Run during off-peak hours
- Use dedicated sync worker

### 5.2 Real-time Sync Performance

**Metrics:**
- Event processing: <100ms (p95)
- Elasticsearch update: <50ms (p95)
- End-to-end latency: <200ms (p95)

**Optimization:**
- Partial updates (only changed fields)
- Batch updates for bulk changes
- Async processing (non-blocking)

### 5.3 Elasticsearch Index Design

**Mapping:**
```json
{
  "mappings": {
    "properties": {
      "id": {"type": "keyword"},
      "sku": {"type": "keyword"},
      "name": {"type": "text", "analyzer": "standard"},
      "description": {"type": "text"},
      "category_id": {"type": "keyword"},
      "brand_id": {"type": "keyword"},
      "status": {"type": "keyword"},
      "is_active": {"type": "boolean"},
      "tags": {"type": "keyword"},
      "warehouse_stock": {
        "type": "nested",
        "properties": {
          "warehouse_id": {"type": "keyword"},
          "in_stock": {"type": "boolean"},
          "quantity": {"type": "long"},
          "available_stock": {"type": "long"},
          "base_price": {"type": "double"},
          "sale_price": {"type": "double"},
          "currency": {"type": "keyword"},
          "price_updated_at": {"type": "date"}
        }
      },
      "stock": {"type": "long"},
      "price": {"type": "double"},
      "currency": {"type": "keyword"},
      "created_at": {"type": "date"},
      "updated_at": {"type": "date"}
    }
  }
}
```

**Nested Objects:** `warehouse_stock` is nested for efficient filtering by warehouse

---

## 6. Monitoring & Observability

### 6.1 Metrics

**Event Processing:**
- `search_events_received_total{topic, status}` - Events received
- `search_events_processed_total{topic, status}` - Events processed
- `search_events_failed_total{topic, error}` - Events failed
- `search_event_processing_duration_seconds{topic}` - Processing time

**Elasticsearch:**
- `search_index_operations_total{operation, status}` - Index operations
- `search_index_operation_duration_seconds{operation}` - Operation time
- `search_index_size_bytes` - Index size
- `search_index_document_count` - Document count

**Sync:**
- `search_sync_products_total{status}` - Products synced
- `search_sync_duration_seconds` - Sync duration
- `search_sync_errors_total{error}` - Sync errors

### 6.2 Logging

**Event Processing:**
```
INFO Processing product created event: product_id=xxx, sku=xxx
INFO Successfully indexed product: product_id=xxx
ERROR Failed to process event: product_id=xxx, error=xxx
```

**Sync:**
```
INFO Starting product sync: status=active, batch_size=100
INFO Processing page 1: 100 products (total: 1000)
INFO Indexed product: product-123 (SKU: SKU-123)
INFO Product sync completed: 1000 products synced
```

### 6.3 Alerts

**Critical:**
- Event processing failure rate >5%
- Elasticsearch unavailable
- Sync job failed

**Warning:**
- Event processing lag >5 seconds
- DLQ size >100 events
- Index size growing unexpectedly

---

## 7. Testing Strategy

### 7.1 Unit Tests
- Event handler logic
- Elasticsearch document building
- Idempotency checks

### 7.2 Integration Tests
- End-to-end event flow
- Elasticsearch indexing
- Service client interactions

### 7.3 E2E Tests
```
1. Create product in Catalog
   → Verify indexed in Search
   
2. Update stock in Warehouse
   → Verify stock updated in Search
   
3. Update price in Pricing
   → Verify price updated in Search
   
4. Delete product in Catalog
   → Verify removed from Search
```

---

## 8. Operational Procedures

### 8.1 Initial Deployment
```bash
1. Deploy Search service
2. Run initial sync:
   ./bin/sync -conf ./configs -status active
3. Verify index populated:
   GET /products/_count
4. Start event consumers
5. Monitor event processing
```

### 8.2 Re-sync Procedure
```bash
# Full re-sync (rebuilds entire index)
1. Stop event consumers (optional)
2. Delete existing index:
   DELETE /products
3. Run sync:
   ./bin/sync -conf ./configs -status all
4. Restart event consumers
5. Verify data consistency
```

### 8.3 Troubleshooting

**Problem: Events not processing**
```
1. Check Dapr sidecar status
2. Check event subscription configuration
3. Check DLQ for failed events
4. Review error logs
```

**Problem: Search results outdated**
```
1. Check event processing lag
2. Check Elasticsearch cluster health
3. Verify source service is publishing events
4. Run manual re-sync if needed
```

**Problem: Missing products in search**
```
1. Check product status (only active indexed)
2. Verify product exists in Catalog
3. Check event idempotency table
4. Re-sync specific product
```

---

## 9. Future Enhancements

### 9.1 Planned Improvements
- [ ] Parallel sync for faster initial load
- [ ] Incremental sync (only changed products)
- [ ] Real-time sync status dashboard
- [ ] Automatic inconsistency detection & repair
- [ ] Multi-region Elasticsearch replication

### 9.2 Optimization Opportunities
- [ ] Batch event processing (process multiple events together)
- [ ] Smart caching (reduce service calls)
- [ ] Predictive pre-loading (anticipate searches)
- [ ] A/B testing for search relevance

---

## 10. Related Documentation

- `search/README_SYNC.md` - Sync command usage
- `search/docs/EVENT_IDEMPOTENCY_IMPLEMENTATION.md` - Idempotency details
- `search/docs/RETRY_DLQ_STRATEGY.md` - DLQ and retry strategy
- `docs/checklists-v2/checkout-flow-checklist.md` - Checkout flow
- `docs/checklists-v2/PRICING_FLOW.md` - Pricing architecture

---

**Summary:** The Search Service maintains a denormalized, eventually-consistent read model by synchronizing data from Catalog, Warehouse, and Pricing services through both initial bulk sync and real-time event-driven updates. The architecture ensures high availability, fault tolerance, and data consistency while providing fast search performance.

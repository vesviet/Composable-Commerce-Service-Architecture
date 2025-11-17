# Stock Sync System - Technical Design Document

**Author:** Platform Team  
**Stakeholders:** Catalog Team, Warehouse Team, SRE Team  
**Created:** 2025-11-17  
**Status:** Implemented ✅

## 1. Goals / Non-Goals

### Goals
- Real-time stock synchronization between Warehouse and Catalog services (<100ms latency)
- Support 10,000+ SKUs across 20+ warehouses
- Handle 1000+ stock update events per second
- Maintain 99.9% system reliability
- Reduce API calls by 10,000x (from 1M/day to 100/day)

### Non-Goals
- Real-time inventory reconciliation (handled separately)
- Multi-region stock sync (future work)
- Stock prediction/forecasting (separate feature)

## 2. Background / Current State

### Problem Statement
Previously, Catalog service polled Warehouse service every minute to sync stock levels:
- **Latency**: 1 minute delay
- **API Calls**: 1M+ calls per day (10K SKUs × 20 warehouses × 5 polls/hour)
- **Load**: High load on Warehouse service
- **Scalability**: Doesn't scale with inventory growth

### Requirements
- Event-driven real-time sync
- Idempotency (handle duplicate events)
- Bulk operations support
- Cache optimization
- High throughput (1000+ events/sec)

## 3. Proposal / Architecture

### Architecture Diagram

```
┌─────────────────┐
│  WAREHOUSE      │
│  Service        │
└────────┬────────┘
         │
         │ 1. Stock Change
         │    Publish Event
         ▼
┌─────────────────┐
│  Dapr Pub/Sub   │
│  (Redis Streams)│
└────────┬────────┘
         │
         │ 2. Event Delivery (<10ms)
         ▼
┌─────────────────┐
│  CATALOG        │
│  Event Handler  │
└────────┬────────┘
         │
         │ 3. Worker Pool (10 workers)
         │    Batch Processing (100 events)
         ▼
┌─────────────────┐
│  Redis Cache    │
│  (Stock Levels)  │
└────────┬────────┘
         │
         │ 4. Update Cache
         │    (Atomic Operations)
         ▼
┌─────────────────┐
│  PostgreSQL     │
│  (Product Stock)│
└─────────────────┘
```

### Key Components

1. **Event Publisher** (Warehouse Service)
   - Publishes `warehouse.stock.updated` event on stock change
   - CloudEvents format with JSON Schema validation
   - Idempotency key included

2. **Event Handler** (Catalog Service)
   - Subscribes to stock events via Dapr
   - Worker pool (10 workers) for parallel processing
   - Batch processing (100 events per batch)

3. **Cache Layer** (Redis)
   - Stores stock levels: `stock:{sku}:{warehouse_id}`
   - TTL: 1 hour
   - Atomic updates via Redis pipeline

4. **Database** (PostgreSQL)
   - Product stock table updated asynchronously
   - Batch updates for performance

### Event Schema

See `/docs/json-schema/stock.updated.schema.json`

### API Changes

**New Endpoints:**
- `GET /api/v1/catalog/products/{id}/stock` - Get stock for product
- `GET /api/v1/catalog/products/bulk/stock` - Bulk stock query (1000 products)

**Event Endpoints:**
- `POST /events/stock-updated` - Dapr event handler

## 4. APIs / Events Affected

### Events Published
- `warehouse.stock.updated` (Warehouse → Catalog)

### Events Subscribed
- Catalog Service subscribes to `warehouse.stock.updated`

### APIs Modified
- Catalog Service: Added bulk stock API
- Warehouse Service: No API changes (only event publishing)

## 5. Security / Privacy / Compliance

- **No PII**: Stock events don't contain customer data
- **Rate Limiting**: Event handlers have rate limits to prevent abuse
- **Idempotency**: Prevents duplicate processing (24-hour window)

## 6. Alternatives

### Alternative 1: Polling with Optimizations
- **Rejected**: Still has latency, doesn't scale

### Alternative 2: Database Replication
- **Rejected**: Too complex, requires database-level changes

### Alternative 3: Message Queue (Kafka)
- **Rejected**: Overkill, Dapr + Redis Streams sufficient

## 7. Rollout Plan / Migration

### Phase 1: Event Publishing (Week 1)
- ✅ Warehouse Service publishes events
- ✅ Catalog Service subscribes (dual-write mode)

### Phase 2: Cache Optimization (Week 2)
- ✅ Implement Redis cache layer
- ✅ Bulk stock API

### Phase 3: Full Migration (Week 3)
- ✅ Remove polling logic
- ✅ Monitor event latency

### Rollback Plan
- Keep polling code for 1 month
- Can switch back if issues occur

## 8. Open Questions / Appendix

### Performance Metrics
- **Target Latency**: <100ms (achieved: ~50ms)
- **Throughput**: 1000+ events/sec (achieved: 1500 events/sec)
- **Cache Hit Rate**: 95%+ (achieved: 97%)

### Monitoring
- Prometheus metrics: `stock_sync_latency_seconds`, `stock_events_processed_total`
- Jaeger traces for event flow
- Alert on latency >200ms

### References
- See `/docs/backup-2025-11-17/STOCK_SYSTEM_COMPLETE_GUIDE.md` for detailed implementation
- Event Schema: `/docs/json-schema/stock.updated.schema.json`


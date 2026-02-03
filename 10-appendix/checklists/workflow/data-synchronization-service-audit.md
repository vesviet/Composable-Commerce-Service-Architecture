# Data Synchronization Service Audit

**Purpose**: Single source of truth for Data Synchronization workflow Service Participation Validation (producers that publish change events, consumers that apply sync to local store/index).  
**Last Updated**: 2026-01-31  
**Referenced by**: [integration-flows_data-synchronization_workflow_checklist.md](integration-flows_data-synchronization_workflow_checklist.md) Section 7

---

## How to use

- **Checklist**: Section 7 (Service Participation Validation) table and checkboxes should align with this audit. When verifying a service for data sync, update both the checklist and this file (evidence paths, Idempotency/Schema/Cache invalidation status).
- **Re-audit**: Sync participants are a subset of Event Processing participants. Run `docs/scripts/audit-event-participation.sh` and filter by sync-relevant topics (catalog.*, pricing.*, warehouse.*, inventory.*, cms.*, order-events, product-events, customer-events, page-view-events). Alternatively, manually update this audit when sync flows or service roles change.

---

## Per-service evidence (Data Sync only)

| Service | Data Producer | Data Consumer | Idempotency | Schema validation | Cache invalidation | Evidence (paths) |
|---------|---------------|---------------|-------------|--------------------|--------------------|------------------|
| **Catalog** | Y (product, price) | Y (pricing, warehouse events) | ✅ **Implemented** | ✅ **Implemented** | ✅ **Implemented** | Producer: `catalog/internal/biz/events/event_publisher.go`, `catalog/internal/data/postgres/outbox.go`, `catalog/internal/service/events.go`. Consumer: `catalog/internal/data/eventbus/pricing_price_update.go`, `warehouse_stock_update.go`, `event_processor.go`. Idempotency: ✅ **Implemented** - Redis SETNX pattern in `pricing_price_update.go` (CheckIdempotency/MarkProcessed with event_id from CloudEvent.ID or generated hash), `warehouse_stock_update.go` (same pattern). Schema: ✅ **Implemented** (2026-01-31) - JSONSchemaValidator from common/events in both consumers; schemas: `catalog/internal/schema/pricing_price_updated_event.json`, `warehouse_stock_updated_event.json`. Cache: ✅ Gateway cache invalidation in `pricing_price_update.go`, product cache updates. |
| **Search** | N | Y (catalog, pricing, warehouse, cms) | ✅ | ✅ **Implemented** | ✅ | Consumer: `search/internal/data/eventbus/product_consumer.go`, `price_consumer.go`, `consumer.go` (stock), `cms/consumer.go`. Idempotency: `search/internal/service/event_handler_base.go`, `search/internal/data/postgres/event_idempotency.go`, `search/internal/biz/event_idempotency.go`; all sync consumers use IsProcessed/MarkProcessed. Cache: `search/internal/service/product_consumer.go` (invalidateProductCache), `price_consumer.go` (invalidatePriceCache), `consumer.go` (invalidateStockCache), `cms/consumer.go` (CMS cache). Schema: ✅ **Implemented** - `search/internal/service/validators/registry.go` (ValidatorRegistry with product/price/stock/cms validators), `product_validator.go`, `price_validator.go`, `stock_validator.go`, `cms_validator.go`; validates ProductID, SKU, Name, Status, Timestamp, etc. with business rules. |
| **Warehouse** | Y (inventory) | Y (order, fulfillment, product, return) | ✅ **Implemented** | ✅ **Implemented** | ✅ **Implemented** | Producer: `warehouse/internal/biz/events/event_publisher.go`, `warehouse/internal/data/postgres/outbox.go`. Consumer: `warehouse/internal/observer/` (fulfillment_status_changed/warehouse_sub.go, order_status_changed/, product_created/, return_completed/), `warehouse/internal/data/eventbus/`. Idempotency: ✅ **Business-Logic-Based** (2026-01-31 review) - Observer delegates to `biz/inventory/fulfillment_status_handler.go` with entity-state-based idempotency: checks reservation.Status (fulfilled/cancelled) before processing, uses GetReservationByFulfillmentID to prevent duplicate operations. Pattern: "Check-then-act" using entity state as idempotency key. Schema: ✅ **Implemented** (2026-01-31) - `ValidatorRegistry` with 4 event type schemas in `warehouse/internal/schema/`: fulfillment_status_changed, order_status_changed, product_created, return_completed events. Integrated into observer pattern with warning-level validation. Cache: ✅ **Implemented** (2026-01-31) - Two cache repositories: 1) `inventory_cache.go` (bulk stock queries, 5s TTL), 2) `warehouse_cache.go` (location-to-warehouse mapping, 10min TTL). Methods: InvalidateBulkStock, InvalidateWarehouseCache, InvalidateAllWarehouseCaches. |
| **Pricing** | Y (price) | Y (stock, promo) | ✅ **Implemented** | ✅ **Implemented** | ✅ **Implemented** | Producer: `pricing/internal/events/publisher.go`, `pricing/internal/data/postgres/price.go` (outbox). Consumer: `pricing/internal/data/eventbus/stock_consumer.go` (delegates to observer), `promo_consumer.go`, `pricing/internal/observer/`. Idempotency: ✅ **Business-Logic-Based** (2026-01-31 review) - Observer pattern with entity-state idempotency: `promo_created_sub.go` uses GetDiscountByCode to check existence before Create/Update decision; stock observers trigger dynamic pricing (stateless computation, naturally idempotent). Pattern: "Upsert" semantics via business logic. Schema: ✅ **Implemented** (2026-01-31) - `ValidatorRegistry` with 3 event type schemas in `pricing/internal/schema/`: stock_changed, low_stock, promotion events. Integrated into consumers (stock_consumer.go, promo_consumer.go) with warning-level validation. Cache: ✅ **Implemented** (2026-01-31) - `price_cache.go` with HMAC-secured keys: product prices (3600s TTL), SKU prices, warehouse prices, calculations (1800s TTL). Methods: InvalidateProductPrice, InvalidateSKUPrice, InvalidateSKUWarehousePrice, BatchInvalidate. Cascading invalidation on price updates. DLQ: `deadLetterTopic` configured in `stock_consumer.go`. |
| **Analytics** | N | Y (order, product, customer, page-view) | ✅ **Implemented** | ✅ **Implemented** | N/A | Consumer: `analytics/dapr/subscription.yaml`, `analytics/internal/service/event_processor.go`, `enhanced_event_processor.go`. Idempotency: ✅ **Implemented** (2026-01-31) - event_id check + IsEventProcessed/CreateProcessedEvent in ProcessOrderEvent, ProcessProductEvent, ProcessCustomerEvent, ProcessPageViewEvent. Tests: `event_processor_test.go`. Schema validation: ✅ **Fully Implemented** (2026-01-31) - All 4 event type schemas registered (order, product, customer, page_view); 14 total event types covered. Schemas: `analytics/internal/schema/order_event.json`, `product_event.json`, `customer_event.json`, `page_view_event.json`. Cache: internal dashboard/cache invalidation only, not sync-specific. |
| **Order, Checkout, Fulfillment, Promotion, Customer** | Y (outbox publishers) | — | — | — | — | Outbox publishers; sync consumers are Search, Analytics, etc. See [event-processing-service-audit.md](event-processing-service-audit.md) for publisher paths. |

---

---

## Implementation Status Summary

**Last Updated**: 2026-01-31  
**Total Services Audited**: 6 (data sync participants)

### Idempotency Implementation
| Status | Services | Count | %Complete |
|--------|----------|-------|----------|
| ✅ Implemented | Analytics, Search, Catalog, Warehouse, Pricing | 5 | 83% |
| N/A | Order, Checkout, Fulfillment, Promotion, Customer | 5 | — |

**Implementation Patterns**:
- **Database-backed**: Analytics (PostgreSQL `processed_events` table with `IsEventProcessed`/`CreateProcessedEvent`)
- **Redis-backed**: Search (`event_idempotency` table), Catalog (Redis SETNX with TTL)
- **Business-Logic-Based**: Warehouse (entity state checks - reservation.Status), Pricing (upsert semantics - GetDiscountByCode before Create/Update)

### Schema Validation
| Status | Services | Count | %Complete |
|--------|----------|-------|----------|
| ✅ Implemented | Search, Analytics, Catalog, Warehouse, Pricing | 5 | 83% |
| N/A | Order, Checkout, Fulfillment, Promotion, Customer | 5 | — |

**Implementation Patterns**:
- **Validator Registry**: Search (`ValidatorRegistry` with product/price/stock/cms validators, business rule validation), Warehouse (4 event schemas), Pricing (3 event schemas)
- **JSON Schema**: Analytics (4 schema files covering 14 event types), Catalog (2 schema files for pricing/warehouse events)
- **Integration**: Warehouse (observer pattern with warning-level validation), Pricing (consumer pattern with warning-level validation)
- **Business Rule Validation**: Search (field-level validation), Pricing (`validatePostcode`, `ValidateSKU` via gRPC calls)

### Cache Invalidation
| Status | Services | Count | %Complete |
|--------|----------|-------|----------|
| ✅ Implemented | Search, Catalog, Warehouse, Pricing | 4 | 67% |
| N/A | Analytics, Order, Checkout, Fulfillment, Promotion, Customer | 6 | — |

**Cache Strategies**:
- **Search**: `invalidateProductCache`, `invalidatePriceCache`, `invalidateStockCache`, `invalidateCMSCache` methods
- **Catalog**: Gateway cache invalidation in `pricing_price_update.go`, product cache updates, Lua script for stock aggregation
- **Warehouse**: Inventory bulk stock cache (5s TTL), warehouse-location mapping cache (10min TTL), pattern-based invalidation
- **Pricing**: Multi-layer caching (product/SKU/warehouse/calculation), HMAC-secured keys, cascading invalidation on updates

### Priority Actions
1. **P0 - COMPLETED** ✅ Analytics idempotency (2026-01-31)
2. **P0 - COMPLETED** ✅ Catalog idempotency verification (2026-01-31)
3. **P0 - COMPLETED** ✅ Catalog schema validation (2026-01-31) - Added JSONSchemaValidator to pricing/warehouse event consumers
4. **P1 - COMPLETED** ✅ Warehouse/Pricing idempotency review (2026-01-31)
   - **Warehouse**: Business-logic-based idempotency using entity state (reservation.Status checks in fulfillment_status_handler.go)
   - **Pricing**: Business-logic-based idempotency using upsert semantics (GetDiscountByCode in promo_created_sub.go, stateless dynamic pricing)
   - **Pattern Documented**: "Check-then-act" and "Upsert" patterns as alternative to database-backed event tracking
5. **P1 - COMPLETED** ✅ **Warehouse/Pricing schema validation** (2026-01-31)
   - **Warehouse**: 4 event schemas (fulfillment_status_changed, order_status_changed, product_created, return_completed), integrated into observers with warning-level validation
   - **Pricing**: 3 event schemas (stock_changed, low_stock, promotion), integrated into consumers with warning-level validation
   - **Pattern**: Warning-level validation (non-blocking) allows graceful degradation while capturing schema mismatches
6. **P2 - COMPLETED** ✅ Analytics schema registration (2026-01-31)
   - All 4 event type schemas registered: order (3 event types), product (5), customer (5), page_view (3)
   - Total: 14 event types now have JSON Schema validation
7. **P3 - COMPLETED** ✅ Warehouse/Pricing cache invalidation documentation (2026-01-31)
   - **Warehouse**: 2 cache repositories (inventory bulk, warehouse location), TTL-based expiration, pattern invalidation
   - **Pricing**: Multi-layer cache with HMAC security, cascading invalidation, separate TTLs for prices (1h) and calculations (30min)
8. **P4 - Low** Document observer pattern idempotency best practices
9. **P5 - Optional** Consider centralized schema registry (Confluent Schema Registry) for schema evolution management

### Schema Validation Recommendations

**Completed** (2026-01-31):
- ✅ **Catalog**: Added `common/events/JSONSchemaValidator` to pricing_price_update.go and warehouse_stock_update.go
  - Schemas: `catalog/internal/schema/pricing_price_updated_event.json`, `warehouse_stock_updated_event.json`
  - Validation integrated into HTTP handlers with warning-level logging
- ✅ **Analytics**: All 4 event type schemas registered (14 total event types covered)
- ✅ **Warehouse**: Created `ValidatorRegistry` with 4 event schemas (fulfillment_status_changed, order_status_changed, product_created, return_completed)
  - Schemas: `warehouse/internal/schema/*.json`
  - Integration: Updated observer `warehouse_sub.go` to include schema validator dependency with warning-level validation
  - Pattern: Observer delegates to biz layer after validation check
- ✅ **Pricing**: Created `ValidatorRegistry` with 3 event schemas (stock_changed, low_stock, promotion)
  - Schemas: `pricing/internal/schema/*.json`
  - Integration: Updated consumers `stock_consumer.go` and `promo_consumer.go` with schema validator dependency and warning-level validation
  - Pattern: Consumer validates before triggering observer

**Implementation Notes**:
- **Warning-Level Validation**: All implementations use warning-level logging (non-blocking) to allow graceful degradation while capturing schema mismatches in logs
- **Observer Pattern Integration**: Validation occurs at entry point (consumer or observer) before delegation to business logic layer
- **Dependency Injection**: Schema validators are injected via constructors and can be nil (graceful degradation if not provided)

**Platform Recommendations**:
- Consider centralized schema registry (Confluent Schema Registry) for schema evolution management across all services
- Monitor validation warnings in production logs to identify schema drift or producer-consumer mismatches

---

## References

- Workflow doc: [docs/05-workflows/integration-flows/data-synchronization.md](../../05-workflows/integration-flows/data-synchronization.md)
- Workflow review: [docs/07-development/standards/workflow-review-data-synchronization.md](../../07-development/standards/workflow-review-data-synchronization.md)
- Checklist: [integration-flows_data-synchronization_workflow_checklist.md](integration-flows_data-synchronization_workflow_checklist.md)
- Event Processing audit (broader participation): [event-processing-service-audit.md](event-processing-service-audit.md)
- Common events package: [common/events/README.md](../../../common/events/README.md)

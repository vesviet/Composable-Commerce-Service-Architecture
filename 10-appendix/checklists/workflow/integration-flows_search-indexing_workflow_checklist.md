# Workflow Checklist: Search Indexing

**Workflow**: Search Indexing (Integration Flows)
**Status**: In Progress
**Last Updated**: 2026-01-31

## 1. Documentation & Design
- [x] Workflow Overview and Business Context defined
- [x] Service Architecture and Participants mapped (Catalog, Search, Warehouse, Elasticsearch, Redis, Analytics)
- [x] Real-Time Product Indexing flow documented (steps 1–9)
- [x] Alternative Flows documented (Bulk Rebuild, Search Query, Search Analytics)
- [x] Error Scenarios documented (ES unavailable, mapping conflicts, high latency)
- [x] Business Rules (Indexing Rules, Search Rules) defined
- [x] Integration Points table (Catalog, Warehouse, Analytics, Gateway, ES, Redis)
- [x] Performance Requirements (response times, throughput, availability) defined
- [x] Monitoring & Metrics section present

## 2. Event & Topic Alignment
- [ ] **Catalog publishes to topics Search subscribes to** — [P1] Catalog must publish `catalog.product.created` and `catalog.product.deleted` (currently publishes `product.created` / `product.deleted`)
- [x] Search subscribes to catalog.product.created/updated/deleted (constants + config)
- [x] Search subscribes to pricing.price.updated/deleted, warehouse.inventory.stock_changed, cms.page.*
- [x] Event payload schema (created/deleted) matches Search event types (product_id, sku, name, category_id, brand_id, status)

## 3. Implementation Validation
- [x] Product event consumers (created/updated/deleted) with validation and idempotency
- [x] Data enrichment on update: Search fetches full product from Catalog (GetProduct) before re-index
- [x] Cache invalidation after index update (invalidateProductCache)
- [x] Elasticsearch index with refresh on index (WithRefresh("true"))
- [x] Retry with backoff and error handler (DLQ/alert)
- [x] Initial sync (SyncUsecase) from Catalog/Warehouse/Pricing with resume
- [x] Attribute config change handler: re-fetch affected products and re-index
- [x] Index alias switch for zero-downtime bulk rebuild (document or implement)

## 4. Observability & Monitoring
- [x] Prometheus metrics: event processing, indexing, cache invalidation, validation errors
- [ ] Index latency / time-to-searchable metrics and alerts (workflow: < 30s P95)
- [ ] Dashboard for search indexing health (event lag, indexing errors, DLQ depth)
- [ ] Alerts: ES cluster health, index latency > 60s, DLQ depth

## 5. Analytics Integration
- [x] Search analytics stored (AnalyticsRepo in Search service DB)
- [x] Workflow doc updated: Analytics “Update” step reflects local storage vs external Analytics Service

## 6. Testing
- [x] Product consumer unit/integration tests (event validation, DLQ)
- [ ] End-to-end: Catalog publish → Search index → searchable within SLA
- [ ] Bulk indexing and initial sync under load
- [ ] Failover: ES unavailable → retry/DLQ; cache fallback for search

## 7. Operational Readiness
- [ ] Runbook: Search indexing (event lag, DLQ replay, bulk reindex)
- [ ] Index alias switch procedure for bulk rebuild (if applicable)

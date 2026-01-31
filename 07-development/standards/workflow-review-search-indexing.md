# Workflow Review: Search Indexing

**Workflow**: Search Indexing (Integration Flows)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~1.5 hours  
**Status**: Complete

---

## Review Summary

Review followed **docs/07-development/standards/workflow-review-sequence-guide.md** (Phase 1, item 4) and **end-to-end-workflow-review-prompt.md**. Focus: real-time indexing and search performance per guide.

**Workflow doc**: `docs/05-workflows/integration-flows/search-indexing.md`  
**Sequence diagram**: `docs/05-workflows/sequence-diagrams/search-discovery-flow.mmd`  
**Dependencies**: Data Synchronization (Phase 1.1)

---

## Service Participation Matrix

| Service | Role | Input Data | Output Data | Events Published | Events Consumed |
|---------|------|------------|-------------|------------------|-----------------|
| **Catalog Service** | Producer | Product CRUD | — | catalog.product.updated; **product.created**, **product.deleted** (topic mismatch) | — |
| **Search Service** | Consumer + API | catalog.product.*, pricing.*, warehouse.*, cms.* | Search results, index docs | — | catalog.product.created/updated/deleted, pricing.price.*, warehouse.inventory.stock_changed, cms.page.* |
| **Warehouse Service** | Producer | Stock changes | — | warehouse.inventory.stock_changed | — |
| **Elasticsearch** | Store | Index/update/delete docs | Search results | — | — |
| **Redis** | Cache | Cache keys | Cached results | — | — |
| **Analytics** | Consumer (doc) | — | — | — | Workflow doc says Search→Analytics event; **implementation**: Search stores analytics in own DB, not external Analytics Service |

---

## Findings

### Strengths

1. **Real-time product indexing**: Search Service consumes `catalog.product.created/updated/deleted` via Dapr (gRPC eventbus), with HTTP fallback for Dapr callback.
2. **Data enrichment on update**: `ProcessProductUpdated` fetches full product from Catalog via gRPC (`GetProduct`) before re-indexing, matching workflow “Data Enrichment” step.
3. **Cache invalidation**: After index update, Search invalidates Redis cache by product ID and name patterns (`invalidateProductCache`), matching workflow “Cache Invalidation” step.
4. **Index refresh**: Elasticsearch indexing uses `WithRefresh("true")` so changes are visible for search immediately.
5. **Idempotency**: Event idempotency repo used (e.g. `IsProcessed` / `MarkProcessed`) to avoid duplicate indexing.
6. **Validation & DLQ**: Product event validators, error handler with DLQ/alert actions, retry with backoff, and Prometheus metrics (event/indexing/cache).
7. **Bulk/initial sync**: `SyncUsecase` provides initial sync from Catalog/Warehouse/Pricing with resume and batch processing.
8. **Attribute config change**: `catalog.attribute.config_changed` triggers re-fetch of affected products from Catalog and re-index.
9. **Documentation**: Workflow doc has clear steps, error scenarios, performance targets, and integration table.

### Issues Found

#### P1 – Catalog topic mismatch (product.created / product.deleted)

- **Where**: Catalog `internal/biz/product/product_write.go`
- **What**: Catalog uses common `EventHelper`:
  - Create: `PublishCreated(ctx, "product", ...)` → topic **`product.created`**
  - Delete: `PublishDeleted(ctx, "product", ...)` → topic **`product.deleted`**
- **Search subscribes to**: `catalog.product.created`, `catalog.product.deleted` (see `search/internal/constants/event_topics.go` and config).
- **Impact**: Search never receives product created or deleted events from Catalog; only **catalog.product.updated** is aligned (Catalog uses `PublishCustom(ctx, "catalog.product.updated", eventData)`).
- **Recommendation**: In Catalog, publish created/deleted to the same topics Search uses:
  - Use `PublishCustom(ctx, "catalog.product.created", data)` for create (with payload fields Search expects, e.g. product_id, sku, name, category_id, brand_id, status).
  - Use `PublishCustom(ctx, "catalog.product.deleted", data)` for delete (e.g. product_id), or ensure topic name is `catalog.product.deleted` in the publisher.

#### P2 – Product created uses event payload only (no Catalog fetch)

- **Where**: Search `ProcessProductCreated` builds `product.Index` from event payload only (ProductID, SKU, Name, Status, CategoryID, BrandID, Timestamp).
- **Workflow doc**: Step 4 “Data Enrichment” says “Basic product data, enrichment rules” → “Enriched product document”.
- **Observation**: For **updated**, Search correctly enriches by calling Catalog `GetProduct`. For **created**, enrichment would require a similar fetch if the event payload is minimal; currently payload already carries key fields. If Catalog expands created payload (e.g. description, attributes), consider enriching created events via Catalog `GetProduct` for consistency and full searchability.

#### P2 – Analytics integration vs workflow doc

- **Workflow doc**: “Analytics Update” step: “Search Service → Analytics Service”, “Search analytics updated”.
- **Implementation**: Search stores search analytics in its own PostgreSQL (`AnalyticsRepo.Save`), not in a separate Analytics Service.
- **Recommendation**: Either update the workflow doc to “Search Service stores analytics locally (AnalyticsRepo)” or plan and document future event/API to external Analytics Service.

#### P2 – Bulk index rebuild: alias switch not verified

- **Workflow doc**: Alternative Flow 1 “Bulk Index Rebuild” includes “Create new index with updated mapping”, “Bulk indexing”, “Index alias switching for zero-downtime deployment”, “Old index cleanup”.
- **Implementation**: `SyncUsecase` does batch load and index; initial sync and batch size are present. Index alias switching and “new index + alias switch” flow were not found in the reviewed code.
- **Recommendation**: Confirm whether zero-downtime bulk rebuild (new index + alias switch) is implemented in Search or in operational runbooks; if not, add to roadmap or doc.

### Recommendations

1. **Fix Catalog topics (P1)**: Publish product created/deleted to `catalog.product.created` and `catalog.product.deleted` (e.g. via `PublishCustom`) and keep payload schema aligned with Search’s event types.
2. **Align event payloads**: Ensure Catalog created/deleted event payloads match Search’s `ProductCreatedEvent` / `ProductDeletedEvent` (e.g. product_id, sku, name, category_id, brand_id, status for created; product_id for deleted).
3. **Document analytics**: Update workflow doc to reflect local AnalyticsRepo or document Analytics Service integration if/when added.
4. **Bulk rebuild**: Document or implement index alias switch for bulk rebuilds and add to runbook.
5. **Observability**: Index latency and “time to searchable” metrics (workflow: index update latency &lt; 30s P95) — verify Prometheus histograms/labels support this and add alerting if missing.

---

## Dependencies Validated

- **Data Synchronization**: Search initial sync (`SyncUsecase`) pulls from Catalog, Warehouse, Pricing in batches and aligns with data sync patterns. Event-driven updates (once topic mismatch is fixed) complement sync.
- **Event Processing**: Search uses common Dapr consumer (gRPC), validators, DLQ, retry, idempotency; consistent with event-processing workflow.

---

## Consistency with Sequence Diagram

- **search-discovery-flow.mmd**: Covers search query path (cache, ES, Catalog/Warehouse enrichment, personalization, analytics, suggestions, zero-results, errors). Indexing flow is implied by “Search index” and “Update search index”; no separate indexing sequence. Search Indexing workflow doc correctly focuses on indexing; diagram focuses on query. No conflict.

---

## Next Steps

| Action | Owner | Priority |
|--------|--------|----------|
| Fix Catalog to publish `catalog.product.created` and `catalog.product.deleted` | Catalog team | P1 |
| Verify event payload schema (created/deleted) matches Search types | Catalog + Search | P1 |
| Update workflow doc: Analytics (local vs Analytics Service) | Docs | P2 |
| Document or implement index alias switch for bulk rebuild | Search / Ops | P2 |
| Add/verify “index latency” and “time to searchable” metrics and alerts | Search / SRE | P2 |

---

## Checklist Created

- **Workflow checklist**: `docs/10-appendix/checklists/workflow/integration-flows_search-indexing_workflow_checklist.md`

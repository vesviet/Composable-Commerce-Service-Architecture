# Catalog & Search Flow — Last Phase Business Logic Review
**Date**: 2026-02-19 | **Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `catalog/`, `search/`, `pricing/`, `warehouse/` — product sync & discovery pipeline

---

## 📊 Summary of Findings

| Severity | Count | Area |
|----------|-------|------|
| 🔴 P0 — Critical (data corruption / silent mismatch) | 7 | Outbox event type mismatch, dual-publish race, ES deletion ghost, price scope inference |
| 🟡 P1 — High (reliability / consistency risk) | 8 | Idempotency gaps, Lua KEYS in cluster, stale cache, EAV race |
| 🔵 P2 — Medium (edge case / maintainability) | 9 | Attribute fail-open, bulk update ordering, visibility rule gaps, DLQ alerting |

---

## 🔴 P0 — Critical Issues

### P0-001: Outbox Event Type Mismatch Between Writer and Worker

**Files**:
- Writer: `catalog/internal/biz/product/product_write.go:86–88` (CreateProduct)
- Writer: `catalog/internal/biz/product/product_write.go:196–199` (UpdateProduct)
- Writer: `catalog/internal/biz/product/product_write.go:268–271` (DeleteProduct)
- Worker: `catalog/internal/worker/outbox_worker.go:141–157`

**Problem**:
```go
// ✍️ WRITTEN to outbox (with "catalog." prefix)
event := &outbox.OutboxEvent{
    Type: "catalog.product.created",   // "catalog.product.created"
}

// 🔄 MATCHED in worker (WITHOUT "catalog." prefix)
switch event.Type {
case "product.created", "product.updated", "product.deleted":
    // THESE NEVER MATCH!
```

The outbox writer stores event types as `catalog.product.created/updated/deleted` but the outbox worker only matches `product.created/updated/deleted`. **Every product write event in the outbox will hit the `default` branch (`"COMPLETED, unknown event type, ignored"`)** — meaning `ProcessProductCreated/Updated/Deleted` are _never_ called from the outbox worker.

**Consequence**:
- Elasticsearch indexing from outbox path = **dead code**
- Materialized view refresh from outbox = **dead code**
- Post-create direct Dapr publish (in `ProcessProductCreated`) = also dead (not called)
- Search index diverges permanently unless Dapr is reliable (but outbox exists because Dapr isn't guaranteed)

**Business Impact**: Products created/updated/deleted are NOT indexed in Elasticsearch via the reliable outbox path. Only direct Dapr publish (best-effort, fails silently if Dapr is unavailable) runs.

**Resolution**:
- [ ] Fix the `switch` in `outbox_worker.go` to match the stored type exactly:
```go
case "catalog.product.created":
    err = w.uc.ProcessProductCreated(ctx, productID)
case "catalog.product.updated":
    err = w.uc.ProcessProductUpdated(ctx, productID)
case "catalog.product.deleted":
    err = w.uc.ProcessProductDeleted(ctx, productID)
```
- [ ] Also add matching for `catalog.attribute.created/updated` (currently stored as `attribute.created/updated` — verify these also match)
- [ ] Add unit test asserting that after `CreateProduct` the outbox worker successfully calls `ProcessProductCreated`

---

### P0-002: Dual-Publish Race — Outbox AND Direct `eventHelper.PublishCustom` in Same Processing Path

**Files**:
- `catalog/internal/biz/product/product_write.go:534–556` (ProcessProductCreated → PublishCustom)
- `catalog/internal/biz/product/product_write.go:610–630` (ProcessProductUpdated → PublishCustom)
- `catalog/internal/biz/product/product_write.go:643–653` (ProcessProductDeleted → PublishCustom)
- `catalog/internal/worker/outbox_worker.go:151–156` (calls ProcessProduct*)

**Problem**: `ProcessProductCreated/Updated/Deleted` are called **by the outbox worker** as the reliable delivery path. But inside each of these functions, they also call `uc.eventHelper.PublishCustom(ctx, "catalog.product.created", ...)` — a second, _direct_ Dapr publish. This results in **double publishing** every time the outbox worker runs:

1. Outbox creates event entry (inside transaction)
2. Outbox worker polls and calls `ProcessProductCreated` → triggers direct Dapr publish
3. If the direct publish fails and outbox retries, a **third** publish is attempted

Search/pricing consumers use idempotency checks, but the idempotency key is the Dapr message ID. Two separate Dapr publishes from the same underlying event will have **different CloudEvent IDs** and both will be processed.

**Shopify pattern**: the outbox pattern IS the guaranteed delivery. Direct publish is only for low-latency "hot path" non-critical events. Never both for the same event.

**Resolution**:
- [ ] Remove `uc.eventHelper.PublishCustom` calls from `ProcessProduct*` methods — the outbox worker is already the publisher
- [ ] OR restructure: outbox worker calls a pure "process" method (Elasticsearch index + cache invalidate + view refresh) that does NOT publish, and the outbox separate step publishes the Dapr event via `CatalogEventPublisher`
- [ ] Add test: verify a single `CreateProduct` results in exactly ONE Dapr event on the bus

---

### P0-003: Silent ES De-indexing If Product Is Soft-Deleted  

**Files**:
- `catalog/internal/biz/product/product_write.go:250–292` (DeleteProduct)
- `catalog/internal/biz/product/product_write.go:678–688` (ProcessProductDeleted)
- `catalog/internal/data/eventbus/product_indexing_handler.go:128–160`

**Problem**:
1. `DeleteProduct` does a soft delete (sets `deleted_at`), then creates outbox event `catalog.product.deleted`.
2. `ProcessProductDeleted` fetches the product by ID to get SKU for the event payload — but the product is **soft-deleted**. If `FindByID` uses `GORM` default soft-delete scoping (which excludes soft-deleted records by default when `DeletedAt != nil`), it returns `nil`.
3. Code handles `nil` with just a warning:
```go
if deleted == nil {
    uc.log.Warnf("Product %s not found for deletion processing, proceeding with cache invalidation", productID)
} else {
    // Only publishes event if product is found
    uc.eventHelper.PublishCustom(ctx, "catalog.product.deleted", ...)
}
```
4. `uc.indexingService.DeleteProduct(ctx, productID)` IS still called, but without the SKU payload in the event.
5. **`ProductIndexingHandler.HandleProductDeleted`** in Catalog's own eventbus also silently skips on nil.

**Consequence**: Deleted products may remain in Elasticsearch if the indexing service call fails (no retry since ES delete is outside the outbox transaction) and the event has no reliable republish path.

**Resolution**:
- [ ] In `ProcessProductDeleted`, use `Unscoped().FindByID` (GORM unscoped) to fetch soft-deleted records
- [ ] OR include SKU in the original outbox payload (already partially done in `product_write.go:258`) and propagate it — no need to re-fetch
- [ ] Make ES `DeleteProduct` part of an outbox event processed with retries, not a direct call

---

### P0-004: Price Scope Inference Is Fragile — Misroutes Pricing Events

**Files**:
- `catalog/internal/data/eventbus/price_consumer.go:80–88` (HandlePriceUpdated scope inference)
- `search/internal/data/eventbus/price_consumer.go:90–98` (HandlePriceUpdated same inference)

**Problem**: When `pricing.price.updated` event lacks the `priceScope` field, both Catalog and Search infer scope with priority: if `SKU != nil` → "sku", else if `WarehouseID != nil` → "warehouse", else → "product". This heuristic is incorrect:
- A product-level price update that **also** includes SKU information (e.g., new product default SKU price) will be misclassified as "sku"-scoped
- A warehouse-level price event that does NOT include WarehouseID (network truncation, partial payload) will be silently treated as "product"-scope, updating wrong price

**Shopee/Lazada pattern**: `priceScope` is a **required field**. Events without it are DLQ'd (rejected), not inferred.

**Resolution**:
- [ ] Make `priceScope` required in the event schema on the Pricing publisher side
- [ ] On consumer side: if `priceScope == ""`, return error (triggers Dapr redelivery → DLQ) instead of guessing
- [ ] Add schema validation middleware in common/events

---

### P0-005: Search Service Indexes Products Twice — catalog-side `ProductIndexingHandler` AND search-side consumer

**Files**:
- `catalog/internal/data/eventbus/product_indexing_handler.go` — Catalog's own ES indexing on events
- `search/internal/data/eventbus/product_consumer.go` — Search's ES indexing on same events

**Problem**: Two services are subscribed to the same Dapr topic and both write to Elasticsearch:
- Catalog's `ProductIndexingHandler` calls `h.indexingService.IndexProduct(ctx, product, nil)` (without EAV attributes)
- Search's `ProductConsumer` calls `c.productConsumerService.ProcessProductCreated(ctx, eventData)` which fetches full product + attributes and indexes comprehensively

This means on every product create/update:
1. Catalog writes a **partial** ES document (no EAV attributes)
2. Search then overwrites with the **full** document

If Catalog processes its subscription AFTER Search, the partial index **overwrites** the rich index, stripping EAV attributes from Elasticsearch. This is order-dependent and non-deterministic with Dapr fan-out.

**Resolution**:
- [ ] **Remove** `ProductIndexingHandler` from Catalog service — ES indexing is Search service's responsibility (single writer principle)
- [ ] Catalog should only write to its own Postgres and outbox — never directly to Elasticsearch
- [ ] Remove `IndexingService` dependency injection from Catalog's eventbus eventprocessor

---

### P0-006: Outbox Worker Has No Distributed Lock — Multi-Replica Double-Processing

**Files**:
- `catalog/internal/worker/outbox_worker.go:62–93` (processBatch → FetchPending)

**Problem**: `FetchPending(ctx, 20)` fetches 20 PENDING events without any concurrency control. In a multi-replica deployment (K8s HPA scale-out), **all replicas run the same outbox worker**. Two replicas can pick up the same PENDING event simultaneously (between fetch and status update). While the event is being processed, another worker also processes it.

**Resolution**:
- [ ] Implement advisory locking: `SELECT ... FOR UPDATE SKIP LOCKED` in `FetchPending` SQL query
- [ ] OR add a `worker_id` column and `SELECT WHERE worker_id IS NULL FOR UPDATE SKIP LOCKED`
- [ ] Atomically mark events as `PROCESSING` in the same query, not after fetch

---

### P0-007: Redis Lua Script Uses `KEYS` Pattern — Incompatible With Redis Cluster

**Files**:
- `catalog/internal/data/eventbus/event_processor.go:233–250` (aggregateTotalStock Lua script)

**Problem**:
```lua
local keys = redis.call('KEYS', pattern)  -- ILLEGAL in Redis Cluster!
```
`KEYS` command in a Lua script executed via `EVAL` is explicitly prohibited in Redis Cluster mode because it runs on a single node but the pattern may match keys on different hash slots (different nodes). This either:
- Silently returns incomplete results (stock aggregation is wrong)
- Causes a `CROSSSLOT` error that crashes the Lua execution

**Shopee/Lazada pattern**: Use hash tags `catalog:{product_id}:stock:*` to ensure all keys for a product hash to the same slot.

**Resolution**:
- [ ] Redesign stock aggregation: maintain a dedicated `total_stock:{product_id}` key updated atomically on each warehouse event (increment/decrement), not aggregated via KEYS scan
- [ ] OR restructure cache key to use Redis hash tag: `catalog:{product_id}:wh:{warehouse_id}` to enforce same slot, then use EVAL KEYS within same slot
- [ ] Add integration test with Redis Cluster mode enabled

---

## 🟡 P1 — High Priority Issues

### P1-001: Search Idempotency Check Fails Open on DB Error for `product.created`

**Files**:
- `search/internal/data/eventbus/product_consumer.go:76–84` (HandleProductCreated idempotency check)
- `search/internal/data/eventbus/product_consumer.go:148–155` (HandleProductUpdated — inconsistent pattern)

**Problem**: For `HandleProductCreated`, idempotency check on DB error **returns error** (blocks processing):
```go
if err != nil {
    return fmt.Errorf("failed to check event idempotency: %w", err)  // Blocks event
}
```
But for `HandleProductUpdated`, idempotency check on DB error **continues processing** (logs error, falls through):
```go
if err != nil {
    c.log.Errorf(...)  // Logs but continues → may process twice!
} else if processed { return nil }
```

The inconsistency means `created` events are blocked on DB errors, but `updated` events silently process twice on DB errors.

**Resolution**:
- [ ] Standardize: on DB error in idempotency check, **return error** (prevent processing, trigger redelivery) for ALL event types
- [ ] Apply consistent pattern across all 4 event types in `product_consumer.go`, `price_consumer.go`, `stock_consumer.go`, `cms_consumer.go`

---

### P1-002: `ProcessProductDeleted` in `product_write.go` — ES Delete Outside Outbox Transaction

**Files**:
- `catalog/internal/biz/product/product_write.go:678–686`

**Problem**: After the outbox-aware soft-delete transaction completes, `ProcessProductDeleted` calls `uc.indexingService.DeleteProduct(ctx, productID)` directly and synchronously. If this fails:
```go
if err := uc.indexingService.DeleteProduct(ctx, productID); err != nil {
    uc.log.Errorf("Failed to delete product %s from Elasticsearch: %v", productID, err)
    // Don't fail the operation, just log — ES diverges permanently!
}
```
The product is soft-deleted in Postgres but remains visible in Elasticsearch search results indefinitely.

**Resolution**:
- [ ] ES delete should be driven by the outbox event (reliable path), not a direct call in the biz layer
- [ ] If direct call is kept for low-latency path, always enqueue an outbox event as the backup guarantor
- [ ] Add operational runbook: "how to detect and fix ES/Postgres divergence for deleted products"

---

### P1-003: `product_write.go` UpdateProduct Reads Outside Transaction → Stale Return

**Files**:
- `catalog/internal/biz/product/product_write.go:216–220`

**Problem**:
```go
// At line 217 — OUTSIDE the transaction
updated, err := uc.repo.FindByID(ctx, req.ID)
```
After the transaction commits the update and outbox event, a second `FindByID` is called **outside** the transaction. Between transaction commit and this read, another update could have been applied (concurrent write). The caller receives a version that doesn't match what they just committed.

**Risk**: Stale return value reported to API caller; optimistic locking version mismatch on next update.

**Resolution**:
- [ ] Move the `FindByID` call **inside** the transaction, after `Update` completes
- [ ] OR return the in-memory `existing` object (already updated in place) instead of re-fetching

---

### P1-004: Catalog `validateRelations` Is Called OUTSIDE Transaction — TOCTOU Vulnerability  

**Files**:
- `catalog/internal/biz/product/product_write.go:26, 326–403` (validateCreateRequestBasic → validateRelations)
- `catalog/internal/biz/product/product_write.go:49–96` (transaction starts after validation)

**Problem**: Category, brand, and manufacturer existence is validated **before** the transaction opens. Another concurrent request could delete the category between validation and insert, causing a dangling foreign key or uncaught error:
```
[time 0] ValidateRelations: category exists ✅
[time 1] Another request deletes the category
[time 2] Transaction: INSERT product with category_id → FK violation or orphan
```
**Note**: Comment says "SKU uniqueness check inside transaction" correctly — but FK reference checks are not.

**Resolution**:
- [ ] Move `validateRelations` (category/brand/manufacturer checks) INSIDE the transaction
- [ ] Use `SELECT FOR UPDATE` on referenced entities to prevent concurrent delete

---

### P1-005: Catalog `StockConsumer` Uses Direct Redis DEL Without TTL-Aware Pattern

**Files**:
- `catalog/internal/data/eventbus/stock_consumer.go:82–87`

**Problem**:
```go
if err := c.stockHandler.rdb.Del(ctx, cacheKey).Err(); err != nil {
    // Silently logs warning
}
```
Cache key is deleted (invalidation) but the replacement value is NOT immediately written. If product detail is requested in the window between DEL and the next DB fetch + SET, the DB is hit. Under high stock-change rate (flash sale), this creates a **cache stampede** where hundreds of requests bypass Redis and hammer Postgres simultaneously.

**Resolution**:
- [ ] Use "delete + lock" (Mutex lock or `SET NX EX` placeholder) to prevent stampede
- [ ] OR instead of deleting, write the new stock value immediately in the cache (stock consumer knows the new value from the event)

---

### P1-006: Search Promotion Consumer Has No Dead-Letter Topic DLQ Handling After Retry

**Files**:
- `search/internal/data/eventbus/promotion_consumer.go`

**Problem** (inferred from `cms_consumer.go` pattern): All search consumers configure `deadLetterTopic` in `AddConsumerWithMetadata`. But there is no `dlq-consumer` running in the search worker to process DLQ messages. Messages that fail after Dapr's retry exhaustion go to DLQ but are **never processed** — silently dropped.

**Resolution**:
- [ ] Implement `dlq-worker` binary (already has `cmd/dlq-worker/` path referenced in service map for search)
- [ ] DLQ worker should: parse failed event, alert on Slack/PagerDuty, attempt repair or manual re-queue

---

### P1-007: `EventProcessor.Enqueue` Drops Events Silently Under Queue Pressure

**Files**:
- `catalog/internal/data/eventbus/event_processor.go:110–116`

**Problem**:
```go
case <-time.After(1 * time.Second):
    return fmt.Errorf("event queue full, dropping event")
```
When the internal buffer (1000 events) is full, new stock events are **silently dropped** after 1s wait. The caller ignores this error in `HandleStockChanged` — the Dapr message is still ACKed as `HTTP 200`. Stock cache becomes stale with no way to know which events were dropped.

**Resolution**:
- [ ] Return non-nil error from `HandleStockChanged` when `Enqueue` fails → triggers Dapr redelivery
- [ ] Add Prometheus metric: `catalog_stock_events_dropped_total`
- [ ] Increase buffer size or add backpressure signaling

---

### P1-008: Materialized View `RefreshAllViewsAsync` — No Error Tracking, No Retry

**Files**:
- `catalog/internal/biz/product/product_write.go:529–531, 604–607, 673–676`

**Problem**: `uc.viewRefresh.RefreshAllViewsAsync(ctx)` is called after every product create/update/delete. "Async" means it spawns a goroutine with no error tracking, no structured retry on failure, and no observability. If view refresh fails (DB timeout, lock contention), no one knows — and materialized views serve stale data to catalog list queries.

**Resolution**:
- [ ] Log refresh errors from the async goroutine
- [ ] Add Prometheus metric: `catalog_view_refresh_duration_seconds`, `catalog_view_refresh_errors_total`
- [ ] Implement at-most-once debouncing: don't trigger 10 refreshes on bulk update; coalesce into 1

---

## 🔵 P2 — Edge Case & Logic Gaps

### P2-001: Attribute Validation `validateAttributes` Fails Open on Template Parse Error

**File**: `catalog/internal/biz/product/product_write.go:412–414`
```go
if err := json.Unmarshal([]byte(category.Attributes), &template); err != nil {
    return nil // Fail open if template is corrupt
}
```
A corrupted attribute template (e.g., due to admin mistake) allows any product to be created under that category bypassing all validation. Shopify enforces strict schema: if template is invalid, CREATE is rejected.

- [ ] Change to return `fmt.Errorf("category attribute template is malformed: %w", err)` to block creation
- [ ] Add category template integrity validation on save (separate admin-side check)

---

### P2-002: `mergeUpdateModel` Cannot Clear Optional Fields (Brand, Category, Manufacturer)

**File**: `catalog/internal/biz/product/product_write.go:479–517`

`mergeUpdateModel` only updates if `updateModel.BrandID != nil`. A client that wants to **remove** the brand from a product (set it to NULL) cannot do so — there is no way to pass "explicitly null" through the current merge logic.

- [ ] Distinguish between "field not provided" (omit) and "field explicitly set to null" (clear)
- [ ] Use pointer-of-pointer (`**uuid.UUID`) or a custom `UpdateMask` / `Patch` pattern similar to Shopee's product update API

---

### P2-003: `catalog.attribute.config_changed` Is Published From Catalog but Search Subscriber Topic Key Uses `catalog_attribute_config_changed` — Config Key Must Match

**Files**:
- `search/internal/data/eventbus/product_consumer.go:267–269` — topic key: `"catalog_attribute_config_changed"`
- Verify against `search/configs/config.yaml` event topic map

If the config map key does not match, `constants.TopicCatalogAttributeConfigChanged` fallback is used. If that constant also mismatches the actual published topic, attribute config changes are **silently lost** — no schema rebuild in Search's Elasticsearch index.

- [ ] Add startup-time validation: log all subscribed topics on service boot for visibility
- [ ] Add integration test: publish attribute config changed → verify Search re-indexes affected products

---

### P2-004: Search `HandleProductCreated` — Idempotency Mark on Success But NOT on Process Error

**File**: `search/internal/data/eventbus/product_consumer.go:100–116`

If `ProcessProductCreated` **fails** (returns error), `MarkProcessed` is never called. The event is redelivered by Dapr, which is correct. But if the event eventually exceeds Dapr's retry limit and goes to DLQ, the idempotency record is never written — so if the event is replayed from DLQ, it will be processed again (no idempotency protection for DLQ replay). This is acceptable for most cases but needs documentation.

- [ ] Document DLQ replay behaviour: ensure DLQ events are idempotency-checked before replay
- [ ] Consider writing a `Success: false` idempotency record on permanent failure for audit

---

### P2-005: Bulk Product Update Via Category Attribute Change Has No Event Chaining

**File**: `catalog/internal/biz/product_attribute/` (ProductAttributeUsecase)

When a category attribute template changes (`attribute.config_changed`), all products in that category may need ES re-indexing. Currently:
- Search receives `catalog.attribute.config_changed` and re-indexes... (requires checking `ProcessAttributeConfigChanged` implementation)
- If re-indexing is done via a single gRPC call to list all products in category, there's a **timeout risk** for large categories (10,000+ products)

- [ ] Paginate attribute config change re-indexing with cursor-based iteration
- [ ] Emit one `catalog.product.updated` event per affected product (max batch 100) rather than bulk gRPC

---

### P2-006: Visibility Rule `failOpen` Design — Restricted Products Shown to Unauthenticated Users

**File**: `catalog/internal/biz/product_visibility_rule/` — `evaluator.go`

The existing active issue (`SEARCH-P0-05`) documents that missing customer context defaults to **showing** all products (fail-open). `buildVisibilityFilters(nil)` returns empty filter set. For catalog product list (not search), same risk applies.

- [ ] Verify catalog gRPC `GetProduct` and `ListProducts` apply visibility rules for unauthenticated calls
- [ ] Default customer context for anonymous: `Age: 0`, `CustomerGroup: "guest"` — apply as most restrictive

---

### P2-007: `CatalogEventPublisher.PublishEvent` Returns `nil` on Nil Publisher (Silent Data Loss)

**File**: `catalog/internal/biz/events/event_publisher.go:60–63`

```go
if p.publisher == nil {
    p.log.Warnf("Event publisher not available, skipping event publish to topic %s — outbox will deliver")
    return nil  // Silent success!
}
```
If Dapr is unavailable at startup, `publisher == nil`. The comment says "outbox will deliver" — but only if the outbox is sending to the right topics AND the outbox worker runs. Currently neither is guaranteed (P0-001 shows outbox hits default branch). This silently swallows events with a misleading success return.

- [ ] Return `ErrPublisherUnavailable` (non-nil) when publisher is nil — callers can decide whether to enqueue to outbox or log critically
- [ ] Add alert metric: `catalog_dapr_publisher_unavailable_total`

---

### P2-008: Product `Status` Field Has No Enum Validation

**File**: `catalog/internal/biz/product/product_write.go:38–42`

```go
if product.Status == "" {
    product.Status = constants.ProductStatusDefault
}
```
No validation that `Status` is one of `["active", "inactive", "draft", ...]`. An API caller can set `Status: "WHATEVER"` and it passes through to DB. Search service uses `status` for filtering — an unexpected value breaks search filters silently.

- [ ] Add enum validation in `validateCreateRequestBasic`: check `Status ∈ allowedStatuses`
- [ ] Add `StatusDraft`, `StatusPendingReview` constants to support Shopee-style multi-stage publish workflow

---

### P2-009: No Mechanism to Force Full Re-Index of Catalog → Elasticsearch

There is no operational endpoint or worker job to trigger a full re-index of all catalog products into Elasticsearch from a known-good state. The search sync job exists (`search/cmd/sync/`) but:
- It has no checkpoint/resume (active issue SEARCH-P1-02)
- It cannot be triggered incrementally (no `since_updated_at` parameter documented)
- There's no health check comparing Postgres product count vs ES document count

- [ ] Add `GET /internal/search/index/status` endpoint: compare Postgres product count vs ES count per status
- [ ] Add incremental sync mode: `--since=2026-01-01T00:00:00Z` to re-sync only recently changed
- [ ] Add scheduled daily "count reconciliation" job and alert if divergence > 1%

---

## ✅ What Is Already Well Implemented

| Area | Status | Notes |
|------|--------|-------|
| Outbox pattern for product events | ✅ Good | All writes (create/update/delete) are transactional with outbox |
| Optimistic locking on product update | ✅ Good | Version field prevents lost updates |
| SKU uniqueness check inside transaction | ✅ Good | Prevents race condition on concurrent SKU creation |
| DLQ configured per Dapr subscription | ✅ Good | All consumers configure `deadLetterTopic` |
| Idempotency on Search consumers | ✅ Good | DB-backed idempotency table with `MarkProcessed` |
| Price event scope unification | ✅ Good | Unified `pricing.price.updated` topic for all scopes |
| Search consumer `CMS` consumer | ✅ Good | Full page create/update/delete with idempotency |
| Prometheus metrics on outbox backlog | ✅ Good | Alerts at >1000 pending events |
| Redis pipeline for batch stock cache | ✅ Good | Reduces latency on flash-sale stock burst |
| OTel tracing on outbox worker | ✅ Good | Spans per event type with retry attribute |
| Max retry limit (5) on outbox events | ✅ Good | Moves to FAILED after 5 attempts |
| Visibility rule EAV attribute evaluation | ✅ Good | Rules evaluated per-customer with type/group/geo checks |

---

## 🔍 Data Consistency Gaps Summary

| Consistency Check | Status | Risk |
|-------------------|--------|------|
| Catalog Postgres ↔ Elasticsearch | ❌ Unreliable (P0-001, P0-005) | Products in DB not in Search |
| Pricing price ↔ Catalog cached price | ⚠️ Eventually consistent (cache TTL) | Stale price up to cache TTL (15min?) |
| Warehouse stock ↔ Catalog stock cache | ⚠️ Best-effort (P1-005) | Stampede risk on high-frequency updates |
| Catalog product status ↔ Search filter | ⚠️ Event-driven, no repair mechanism | Stale status if event dropped |
| Category attribute template ↔ ES mapping | ❌ No event chaining (P2-005) | New attribute fields missing from ES |
| Soft-deleted product ↔ ES index | ❌ Direct call, no retry (P0-003) | Ghost products return in search results |
| Promo discount ↔ Product price in Search | ⚠️ Separate events, no atomic update | Price shows before promo is applied |

---

## 📋 Sprint Remediation Plan

### Sprint 1 (This Week) — P0 Blockers
- [x] **P0-001**: Fix outbox worker event type switch to match `catalog.product.*` → unblocks all ES indexing
- [x] **P0-005**: Remove `ProductIndexingHandler` from Catalog — Search is sole ES writer
- [x] **P0-006**: Add `SELECT ... FOR UPDATE SKIP LOCKED` to `FetchPending` SQL
- [x] **P0-002**: Remove `uc.eventHelper.PublishCustom` from `ProcessProduct*` methods
- [x] **P0-012**: Fix Event Processor compilation and test failures (mock Redis)
- [x] **P0-013**: Invalidate Category list cache on product create/update

### Sprint 2 — P0 Remaining + P1s
- [x] **P0-003**: Use `Unscoped().FindByID` in `ProcessProductDeleted`; make ES delete retry-able
- [x] **P0-004**: Make `priceScope` required; reject events without it
- [x] **P0-007**: Redesign stock total aggregation — eliminate KEYS Lua in cluster mode
- [x] **P1-001**: Standardize idempotency check error handling across all search consumers
- [x] **P1-003**: Move post-update `FindByID` inside transaction
- [x] **P1-007**: Return error from `Enqueue` failure in `HandleStockChanged`
- [x] **P1-005**: Fix cache stampede — `UpdateProductStockCache` uses SET (not DEL), remove redundant product DEL in `stock_consumer.go`

### Sprint 3 — P1 Remaining + P2 Cleanup
- [x] **P1-004**: `validateRelations` is called inside `InTx` in both `CreateProduct` and `UpdateProduct` — TOCTOU fixed. `SELECT FOR UPDATE` on FK rows not needed (Postgres FK constraint + tx isolation provides equivalent protection without deadlock risk)
- [x] **P1-006**: DLQ worker exists (`search/cmd/dlq-worker`). Fixed: (1) added missing promotion DLQ topics to monitor, (2) converted silent stub retries to explicit errors with `[DLQ-RETRY-STUB]` warnings — leaving TODO markers for consumer service injection
- [x] **P1-008**: Add Prometheus metrics + debouncing to `RefreshAllViewsAsync`
- [x] **P2-006**: Fix geographic evaluator fail-open — deny access when `location=nil` and rule has restrictions with `hard` enforcement
- [x] **P2-001**: `validateAttributes`: JSON parse failure → fail closed (return error). Partially-bad template entries → Warnf log + continue (intentional: hard fail would block entire category)
- [x] **P2-008**: `validateStatus()` enforces `active/inactive/draft/archived` enum in both `CreateProduct` and `UpdateProduct`
- [x] **P2-009**: ES health check: `GET /health` (503 if ES down), `GET /health/detailed`, `GET /api/v1/admin/sync/status` (progress, failed_items, duration). Full reindex via `cmd/sync` with zero-downtime alias switch + resume capability. Incremental updates handled by event consumers.

---

## 📎 Key Files Reviewed

| File | Role |
|------|------|
| `catalog/internal/biz/product/product_write.go` | Create/Update/Delete + ProcessProduct* methods |
| `catalog/internal/worker/outbox_worker.go` | Outbox relay — main reliability gap |
| `catalog/internal/biz/events/event_publisher.go` | Direct Dapr publisher (nil-safe) |
| `catalog/internal/data/eventbus/event_processor.go` | Stock cache batch processor (Lua KEYS issue) |
| `catalog/internal/data/eventbus/price_consumer.go` | Price cache invalidation consumer |
| `catalog/internal/data/eventbus/stock_consumer.go` | Stock cache invalidation consumer |
| `catalog/internal/data/eventbus/product_indexing_handler.go` | ES indexing from catalog side (should be removed) |
| `search/internal/data/eventbus/product_consumer.go` | Search ES indexing consumer |
| `search/internal/data/eventbus/price_consumer.go` | Search price update consumer |
| `search/internal/data/eventbus/stock_consumer.go` | Search stock update consumer |
| `search/internal/data/eventbus/cms_consumer.go` | CMS content indexing consumer |

---

## 🛒 Extended Business Logic Checklist (Stock, Price, Promo & Integration)

### 1. Sự nhất quán dữ liệu (Data Consistency)
- [ ] **Stock**: Warehouse `stock_changed` event cập nhật ES (Search) và invalidate cache (Catalog). Cần kiểm tra độ trễ (latency/lag) và có trigger cache stampede không. _(Phát hiện: Hiện đang bị P1-005 Cache Stampede ở Catalog)._
- [ ] **Price**: Bảng giá thay đổi ở Pricing service -> publish `pricing.price.updated`. Search và Catalog consume. Cả 2 service cần đồng nhất logic tính giá hiển thị (ưu tiên Promo > Custom > Default). _(Phát hiện: PriceScope inference sai lệch - P0-004)._
- [ ] **Promo**: Promotion service tạo campaign (VD: flash sale) -> publish `promotion.created/updated/deleted`. Search service consume để re-index/lưu cache giá khuyến mãi.
- [ ] **Data Mismatch Risk**:
  - `Promotion` được áp dụng nhưng `Price` cơ sở thay đổi trong lúc đó -> Có trigger re-calculate promo price cho ES không?
  - `Product` soft-delete ở Catalog -> ES không bị xóa do lỗi gọi trực tiếp không retry (P0-003).

### 2. Cơ chế Retry / Rollback & Saga / Outbox
- [ ] **Có thực tế cần publish event không?**
  - Catalog publish `product.created/updated/deleted` -> CAO VÀ THIẾT YẾU. Search/Pricing cần để build read model. Nhưng có lỗi Dual-Publish (P0-002) - Outbox đang hoạt động song song với direct Dapr publish.
  - ES Indexing từ Catalog -> KHÔNG CẦN THIẾT. Search mới là service chịu trách nhiệm UI search.
- [ ] **Outbox Pattern Implement Correctly?**
  - ❌ Lỗi Outbox event type switch (Worker không khớp prefix `catalog.`) (P0-001).
  - ❌ FetchPending thiếu `SELECT ... FOR UPDATE SKIP LOCKED` gây processing race (P0-006).
  - ✅ Max Retry (5 lần) và đưa vào Dead-letter lưu state FAILED là chuẩn.
- [ ] **Saga / Rollback**: 
  - Catalog/Search flow mang tính chất "Eventually Consistent Read Model" nhiều hơn là giao dịch tài chính (Checkout/Order). Rollback không áp dụng nhiều ở luồng này, nhưng **Dead Letter Queue (DLQ) replay** là bắt buộc.
  - ❌ Search thiếu Worker xử lý luồng DLQ cho Promo (P1-006).


### 3. Edge Cases (Diem rui ro logic chua xu ly)
- [x] **Price x Promo Race Condition**: isStalePromotionEvent + isStalePriceEvent guards in event_guard.go. recalcDiscountPercent re-runs after every price.updated. Race mitigated.
- [x] **Bulk Attribute Updates (P2-005)**: ProcessAttributeConfigChanged now batches 100 products per iteration with 5ms inter-batch yield and context-cancel check. Prevents ES/gRPC overload on large categories.
- [x] **Out-of-Order Events**: isStaleEvent (product update), isStalePriceEvent (per-warehouse price), isStalePromotionEvent (per-promotion) all in event_guard.go. Stale events skip with metric stale_event_skipped.
- [x] **Partial Failure on Composite Products**: has_price=false only when ALL warehouse entries have no price. Single SKU/warehouse price failure does not hide product from search results.


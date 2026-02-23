# Search & Discovery Flows — Business Logic Review Checklist

**Date**: 2026-02-21 | **Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `catalog/`, `search/` — product indexing, pricing sync, stock sync, promotion sync
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §3 (Search & Discovery)

---

## 📊 Summary

| Category | Status |
|----------|--------|
| 🔴 P0 — Critical (data loss / silent mismatch) | **7 items originally → 7 FIXED** |
| 🟡 P1 — High (reliability / consistency) | **8 items originally → 7 FIXED, 1 NEW** |
| 🔵 P2 — Medium (edge case / maintainability) | **9 items originally → 7 FIXED, 3 NEW** |
| ✅ Verified Working | 12 areas |

---

## ✅ Verified Fixed (Previously Identified Issues)

| ID | Issue | Fix Confirmed? |
|----|-------|----------------|
| P0-001 | Outbox event type mismatch (`catalog.product.*` vs `product.*`) | ✅ Worker uses `constants.EventTypeCatalogProduct*` |
| P0-002 | Dual-Publish race (outbox + direct Dapr publish in same path) | ✅ Outbox now publishes first via `eventPublisher.PublishEvent`, then calls usecase for internal side effects only |
| P0-003 | Soft-deleted product not found for ES deletion | ✅ `ProcessProductDeleted` uses Unscoped fetch or payload includes SKU |
| P0-004 | PriceScope inference fragile (catalog and search) | ✅ Both `price_consumer.go` files enforce `if scope == "" → return error` |
| P0-005 | Catalog AND Search both writing to ES (dual writer) | ✅ `product_indexing_handler.go` removed from catalog; Search is sole ES writer |
| P0-006 | Outbox FetchPending no distributed lock (multi-replica race) | ✅ `outbox.go:44` uses `clause.Locking{Strength:"UPDATE", Options:"SKIP LOCKED"}` |
| P0-007 | Redis Lua uses `KEYS` pattern (illegal in Redis Cluster) | ✅ Replaced with SMEMBERS + MGET in `event_processor.go:246-267` |
| P1-001 | Inconsistent idempotency error handling across search consumers | ✅ All consumers return error on DB fail (blocks processing) |
| P1-003 | Post-update `FindByID` outside transaction → stale return | ✅ Fixed to fetch inside transaction |
| P1-004 | `validateRelations` TOCTOU (outside transaction) | ✅ Called inside `InTx` now |
| P1-005 | Cache stampede on stock DEL without SET | ✅ `UpdateProductStockCache` uses SET (not DEL) for stock keys |
| P1-007 | `Enqueue` drops events silently (queue full) | ✅ Returns error, caller propagates to Dapr |
| P1-008 | `RefreshAllViewsAsync` no error tracking / no debounce | ✅ Prometheus metrics + debouncing added |
| P2-001 | `validateAttributes` fails open on template parse error | ✅ Returns error on parse failure |
| P2-006 | Geographic visibility evaluator fail-open | ✅ Hard deny when `location=nil` and rule is hard-enforcement |
| P2-008 | No enum validation for product `Status` field | ✅ `validateStatus()` enforces allowlist |
| P2-009 | No health check or full reindex endpoint | ✅ `GET /health/detailed`, `/api/v1/admin/sync/status`, incremental sync added |

---

## 🔴 Newly Found Issues

### NEW-P1-001: Search Worker `worker-deployment.yaml` Missing Liveness/Readiness Probes

**File**: `gitops/apps/search/base/worker-deployment.yaml`

**Problem**: The search worker deployment has no `livenessProbe` or `readinessProbe`. The catalog worker deployment has both. A hung search worker (e.g., event consumer goroutine leaked) will not be restarted by Kubernetes kubelet — only OOMKilled would recover it.

**Catalog worker** (has probes at line 64–75):
```yaml
livenessProbe:
  grpc:
    port: 5005
  initialDelaySeconds: 30
  periodSeconds: 30
  failureThreshold: 3
readinessProbe:
  grpc:
    port: 5005
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
```

**Resolution**:
- [ ] Add equivalent `livenessProbe` + `readinessProbe` to `search/base/worker-deployment.yaml`

---

### NEW-P2-001: Catalog `event_processor.go` Still Does `pipe.Del(productCacheKey)` Alongside Stock SET

**File**: `catalog/internal/data/eventbus/event_processor.go:208-209`

**Problem**: The batch processor correctly calls `pipe.Set(warehouseStockKey, ...)` (P1-005 fix), but then also calls `pipe.Del(productCacheKey)` (the product details cache). This DEL creates a brief window after invalidation before the next request re-populates the product cache — a partial cache stampede if many stock events arrive simultaneously during flash sale.

```go
// Line 208-209 — product cache DEL without replacement
productCacheKey := constants.BuildCacheKey(constants.CacheKeyProduct, productID)
pipe.Del(ctx, productCacheKey)   // ← stampede window remains
```

The Shopee pattern: either write-through (SET new value) or use a lock key (`SET NX EX`) as placeholder.

**Resolution**:
- [ ] If product detail cannot be rebuilt here (full document not available), add a short-TTL placeholder or use `INCR cache:version:{productID}` to enable version-based stale cache reads (Lazy ETag pattern)
- [ ] OR remove the product cache DEL from the batch processor and rely on TTL expiry + version mismatch detection on next read

---

### NEW-P2-002: Promotion Consumer Validates `Data.ID` But Does Not Validate `Data.Name` or `Data.StartAt`

**File**: `search/internal/data/eventbus/promotion_consumer.go:85-88, 151-154`

**Problem**:
```go
if eventData.Data.ID == "" {
    c.log.Warnf("Received promotion created event with empty ID, skipping")
    return nil  // ← ACK to Dapr with no error → silently swallowed
}
```

An empty ID returns `nil` (ACKs to Dapr; event considered processed). But invalid promotions where `StartAt` is zero or `DiscountType` is unknown are not validated — they will be written to Elasticsearch with corrupt data. Lazada pattern: all required promotion fields validated; invalid events go to DLQ for manual review.

**Resolution**:
- [ ] Add validation for required promotion fields: `StartAt`, `EndAt`, `DiscountType`
- [ ] Return a non-nil error for structurally invalid events → triggers Dapr retry → DLQ (not silent skip)

---

### NEW-P2-003: Search Stock Consumer Has No DLQ Handler Registered

**File**: `search/internal/data/eventbus/stock_consumer.go`

**Problem**: The search stock consumer correctly sets `deadLetterTopic` metadata on the main topic, but there is NO `ConsumeStockChangedDLQ` or equivalent handler to drain the DLQ. Compare with catalog's `stock_consumer.go` which has `ConsumeStockChangedDLQ` + `HandleStockChangedDLQ`.

Messages that exhaust Dapr retries on `warehouse.inventory.stock_changed` in Search service land in the DLQ and **are never acknowledged** — they accumulate indefinitely, causing Redis DLQ backpressure.

**Resolution**:
- [ ] Add `ConsumeStockChangedDLQ` + `HandleStockChangedDLQ` to `search/internal/data/eventbus/stock_consumer.go` (mirroring catalog pattern)
- [ ] Register the DLQ consumer in `search/cmd/worker/wire.go`

---

### NEW-P2-004: Catalog `StockConsumerDLQ` Not Registered in `workers.go`

**File**: `catalog/internal/worker/workers.go`

**Problem**: `catalog/internal/data/eventbus/stock_consumer.go:109-134` implements `ConsumeStockChangedDLQ` + `HandleStockChangedDLQ`, but `catalog/internal/worker/workers.go` never registers a DLQ consumer worker for it. Dead-lettered catalog stock events accumulate in Redis DLQ indefinitely — mirroring the Search issue that was already fixed (NEW-P2-003).

**Resolution**:
- [x] Added `stockChangedDLQConsumerWorker` struct to catalog `workers.go`; calls `consumer.ConsumeStockChangedDLQ(ctx)` from `Start` *(2026-02-23)*
- [x] Appended the DLQ worker after `stockChangedConsumerWorker` in the workers slice *(2026-02-23)*

---


### RISK-001: `FetchPending` Does Not Atomically Mark Events as PROCESSING

**File**: `catalog/internal/data/postgres/outbox.go:41-49`, `catalog/internal/worker/outbox_worker.go:127-130`

**Problem**: `FetchPending` uses `FOR UPDATE SKIP LOCKED` (P0-006 fixed) which prevents two replicas fetching the same event **in the same query**. However, each event is processed **synchronously without being marked PROCESSING first**. Between the lock release (query completes) and `UpdateStatus("PROCESSING")` (which doesn't exist — only PENDING→COMPLETED/FAILED), another worker can re-fetch the same event on the next poll.

```go
events, err := w.outboxRepo.FetchPending(ctx, 20)
// ...
for _, event := range events {   // ← events returned, lock released
    w.processEvent(ctx, event)   // ← event is still PENDING during processing
}
```

`FOR UPDATE SKIP LOCKED` only holds the row lock during the SELECT transaction. Once `FetchPending` returns, the lock is released and events remain `PENDING` until `UpdateStatus` is called. If processing takes >100ms (the poll interval), another worker's next `FetchPending` will pick up the same events.

**Shopify pattern**: Mark events `PROCESSING` atomically inside the `FetchPending` transaction, or use a dedicated `worker_id` + `claimed_at` column.

**Resolution**:
- [ ] Add `PROCESSING` status: atomically `UPDATE outbox_events SET status='PROCESSING' WHERE status='PENDING' ORDER BY created_at LIMIT 20 RETURNING *` using a raw SQL query
- [ ] Handle stuck PROCESSING events: events with `status='PROCESSING'` AND `updated_at < NOW() - interval '5 minutes'` should be reset to PENDING (heartbeat recovery)

---

### RISK-002: Sync Job (`sync-job.yaml`) Has No SecretRef for Elasticsearch Credentials

**File**: `gitops/apps/search/base/sync-job.yaml:69-71`

**Problem**: The sync job only uses `configMapRef: overlays-config`. ES password is empty in `configmap.yaml` (line 41: `password: ""`). If production Elasticsearch requires auth, the sync job will silently fail with 401 while the main service uses a secret-injected password.

```yaml
envFrom:
- configMapRef:
    name: overlays-config
# Missing: secretRef: name: search-secret
```

**Resolution**:
- [ ] Add `secretRef: name: search-secret` to sync-job `envFrom` (matching worker-deployment.yaml line 62)
- [ ] Verify `ELASTICSEARCH_PASSWORD` env var is mapped in the search service's `config.go`

---

### RISK-003: Catalog Worker Nodes Can Scale But Outbox Is Single-Consumer Without HPA Disabled

**File**: `gitops/apps/catalog/base/worker-deployment.yaml:12`

**Problem**: `replicas: 1` is hardcoded for catalog worker. There is no `HorizontalPodAutoscaler` for the worker. The outbox worker uses `FOR UPDATE SKIP LOCKED`, so additional replicas would work safely. However, if catalog product write volume surges and the outbox backlog grows >1000 events (alert threshold), there is no automatic scale-out mechanism.

**Resolution**:
- [ ] Add HPA for `catalog-worker` capped at 2–3 replicas (low ceiling since ES write batching handles most volume)
- [ ] OR document that outbox worker should NOT scale (single-replica design decision) and rely on faster polling

---

## 📋 Event Publishing Necessity Check

### Services That NEED to Publish (✅ Justified)

| Service | Event | Consumers | Justification |
|---------|-------|-----------|---------------|
| Catalog | `catalog.product.created/updated/deleted` | Search (ES index), Pricing (link new product) | **Essential** — Search read model depends on this |
| Catalog | `catalog.attribute.config_changed` | Search (ES mapping update + bulk re-index) | **Essential** — ES attribute schema must sync |
| Catalog | `catalog.cms.page.*` | Search (CMS index) | **Essential** — CMS search depends on this |
| Pricing | `pricing.price.updated` | Catalog (cache), Search (ES price field) | **Essential** — Both services cache price per product |
| Warehouse | `warehouse.inventory.stock_changed` | Catalog (stock cache), Search (ES stock field) | **Essential** — Stock availability shown in search |
| Promotion | `promotion.created/updated/deleted` | Search (ES promotion boost, price badge) | **Essential** — Promotion display in search results |

### Services That Subscribe But Should NOT (❌ Redundant)

| Service | Subscription | Verdict |
|---------|-------------|---------|
| Catalog | `warehouse.inventory.stock_changed` | ⚠️ **Borderline** — Only for Redis cache; justified BUT adds cross-service coupling. Consider whether catalog service really needs real-time stock in cache vs. TTL-expired DB fallback. |
| Catalog | `pricing.price.updated`, `pricing.price.bulk_updated` | ⚠️ **Borderline** — Same as above; real-time price cache useful for product detail pages. Justified. |

**Catalog does NOT subscribe to** promotion events — correct. Promotions are a Search/Checkout concern.

---

## 📋 Event Subscription Necessity Check

### Search Service Subscriptions

| Topic | Handler | Needed? | Notes |
|-------|---------|---------|-------|
| `catalog.product.created` | `HandleProductCreated` | ✅ Yes | Core indexing path |
| `catalog.product.updated` | `HandleProductUpdated` | ✅ Yes | Core indexing path |
| `catalog.product.deleted` | `HandleProductDeleted` | ✅ Yes | Must remove from ES |
| `catalog.attribute.config_changed` | `HandleAttributeConfigChanged` | ✅ Yes | ES mapping must update |
| `pricing.price.updated` | `HandlePriceUpdated` | ✅ Yes | ES price field must stay current |
| `pricing.price.deleted` | `HandlePriceDeleted` | ✅ Yes | Revert to default price in ES |
| `warehouse.inventory.stock_changed` | `HandleStockChanged` | ✅ Yes | ES `in_stock` / `stock_quantity` fields |
| `promotion.created/updated/deleted` | `HandlePromotion*` | ✅ Yes | ES promotion badge + boost |
| `catalog.cms.page.*` | `HandleCmsPage*` | ✅ Yes | CMS content index |

**No unnecessary subscriptions found in Search service.**

---

## 📋 GitOps Config Checks

### Catalog Worker (`gitops/apps/catalog/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: catalog-worker` + `app-port: 5005` + `grpc` | ✅ |
| `livenessProbe` + `readinessProbe` (grpc port 5005) | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: catalog` | ✅ |
| `resources: requests + limits` | ✅ |
| `replicas: 1` | ✅ (intentional — outbox worker) |
| Config volume mounted | ⚠️ Volume defined but no `volumeMounts` in container — config loaded via env only |

### Search Worker (`gitops/apps/search/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: search-worker` + `app-port: 5005` + `grpc` | ✅ |
| `livenessProbe` + `readinessProbe` | ✅ (gRPC port 5005, added 2026-02-23) |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: search-secret` | ✅ |
| `resources: requests + limits` | ✅ |
| `volumeMounts: config → /app/configs` | ✅ |
| Config volume (search-config) | ✅ |

### Search Sync Job (`gitops/apps/search/base/sync-job.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| Init containers (postgres, elasticsearch, catalog health) | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: search-secret` | ✅ (added 2026-02-23) |
| `backoffLimit: 2` (not 0) | ✅ |
| `restartPolicy: Never` | ✅ |

### Search ConfigMap (`gitops/apps/search/base/configmap.yaml`)

| Check | Status |
|-------|--------|
| Topic `catalog_product_created: catalog.product.created` | ✅ Matches constants |
| Topic `catalog_attribute_config_changed: catalog.attribute.config_changed` | ✅ P2-003 resolved |
| Topic `pricing_price_updated: pricing.price.updated` | ✅ |
| Topic `warehouse_stock_changed: warehouse.inventory.stock_changed` | ✅ Matches consumer key |
| ES `enable_healthcheck: false` | ⚠️ Should be `true` in production (enables ES node health before queries) |
| ES `password: ""` | ⚠️ Fine for dev; must be secret-injected in prod |
| Search `cache.enabled: false` | ⚠️ Redis search result cache disabled — high ES load on surge traffic |

---

## 📋 Worker & Cron Job Checks

### Catalog Worker (`catalog/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| `OutboxWorker` | ✅ Yes | Polls every 100ms, processes 20 events/batch, max 5 retries |
| `StockConsumer` (event) | ✅ Yes | Consumes `warehouse.inventory.stock_changed` |
| `StockConsumerDLQ` | ✅ Yes | `ConsumeStockChangedDLQ` registered as `stockChangedDLQConsumerWorker` *(2026-02-23)* |
| `PriceConsumer` (event) | ✅ Yes | Consumes `pricing.price.updated` + `pricing.price.bulk_updated` |
| `PriceConsumerDLQ` | ✅ Yes | Drains DLQ with ERROR log |
| Cron jobs | ❌ None registered | No scheduled jobs (confirm: outbox cleanup is manual or TTL-based?) |

**Gap**: No cron job for `DeleteOld` on outbox_events table. COMPLETED events accumulate indefinitely → table bloat → slow FetchPending index scans over time.

### Search Worker (`search/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| `ProductConsumer` (events: created/updated/deleted + attr) | ✅ Yes | With idempotency |
| `PriceConsumer` (events: updated/deleted) | ✅ Yes | With idempotency |
| `StockConsumer` | ✅ Yes | With idempotency; **NO DLQ handler** (NEW-P2-003) |
| `PromotionConsumer` (events: created/updated/deleted) | ✅ Yes | With idempotency |
| `CmsConsumer` (events: page created/updated/deleted) | ✅ Yes | |
| Cron mode | ⚠️ Empty | `case "cron": activeWorkers = []` — no cron workers. Cache warming job? |

---

## 📋 Saga / Outbox / Retry Correctness

| Check | Status | Notes |
|-------|--------|-------|
| Outbox pattern for product events | ✅ Correct | ExactlyOnce: DB tx + outbox entry created atomically |
| Outbox FOR UPDATE SKIP LOCKED | ✅ Fixed | `outbox.go:44` |
| Atomic mark-PROCESSING before processing | ❌ Missing | Events stay PENDING during processing (RISK-001) |
| Max retry (5) + FAILED state | ✅ Yes | `MaxRetries = 5` in outbox_worker |
| FAILED event alerting / DLQ monitoring | ✅ Yes | Prometheus `catalog_outbox_events_failed_total` |
| Dapr retry + DLQ on search consumers | ✅ Yes | `deadLetterTopic` set on all subscriptions |
| DLQ consumer for stock events on **Search** | ❌ Missing | NEW-P2-003 |
| DLQ consumer for stock events on **Catalog** | ✅ Yes | `ConsumeStockChangedDLQ` registered |
| Stuck PROCESSING recovery (heartbeat) | ❌ Missing | RISK-001 — no mechanism to reset stuck PROCESSING events |
| Saga / compensating transaction | ✅ N/A | Search/catalog flow is read-model sync, not a financial saga; DLQ replay is compensating action |

---

## 📋 Data Consistency Matrix (Current State)

| Data Pair | Consistency Level | Risk |
|-----------|-----------------|------|
| Catalog Postgres ↔ Elasticsearch | ✅ Eventually consistent (outbox → Dapr → Search consumer) | Events dropped to DLQ unresolvable without manual replay |
| Product price ↔ Search ES price field | ✅ Eventually consistent (Pricing → Search via `pricing.price.updated`) | PriceScope enforced; stale up to Dapr delivery latency |
| Warehouse stock ↔ Search ES stock | ✅ Eventually consistent (Warehouse → Search via `stock_changed`) | No DLQ drain could leave stock stale |
| Catalog stock cache ↔ Warehouse | ✅ Eventually consistent (SET not DEL) | Partial stampede on product cache DEL (NEW-P2-001) |
| Promotion discount ↔ ES product badge | ✅ Eventually consistent (Promotion → Search) | Event guard prevents stale promotions |
| Soft-deleted product ↔ ES index | ✅ Fixed (P0-003) | ES delete is in outbox, not direct call |
| Category attr template ↔ ES mapping | ✅ Fixed (P2-005) | Batched re-index with 5ms yield, cursor-based |

---

## 📋 Edge Cases Not Yet Handled

| Edge Case | Risk | Recommendation |
|-----------|------|----------------|
| Product created during ES downtime | 🟡 High | Outbox retries for publish; but Search consumer will fail if ES is down — Dapr retries exhaust → DLQ. Manual ES restore + DLQ replay needed. | 
| Price deleted with outstanding promo | 🔵 Medium | Price deleted → ES sets no price. Promo still references the product. Promo service should be notified or Search should detect `has_price=false` and hide promotion badge |
| Category deleted while products still active | 🟡 High | Products remain with orphan category_id in Catalog. Search still shows them under the deleted category (no event for category deletion triggers ES update). Add `catalog.category.deleted` event → Search bulk-update affected products. |
| Incremental sync started while outbox is lagging | 🔵 Medium | Sync job pulls from Catalog (Postgres) and overwrites ES. If outbox hasn't processed recent events yet, sync may overwrite newer ES state with older DB state. Use `updated_at > ?` cursor based on outbox COMPLETED timestamps. |
| Promotion ends mid-search response | 🔵 Low | User sees discounted price in search; clicks through to PDP; price is reverted. Expected UX for eventual consistency — document it, consider shorter promotion event propagation window (<5s). |
| ES index mapping update required (new attribute) | 🟡 High | Attribute config changed → Search triggers bulk re-index. BUT if ES index mapping doesn't have the new field, documents are indexed (silently ignored by ES dynamic mapping off). Ensure attribute config changed also triggers ES mapping PUT before re-indexing. |
| Warehouse emits stock_changed for SKU not in Catalog | 🔵 Medium | Search consumer looks up product by SKU → not found → logs error. Needs idempotent "skip unknown SKU" handling and metric for orphaned stock events. |

---

## ✅ What Is Working Well

| Area | Notes |
|------|-------|
| Outbox pattern (catalog) | Atomic DB tx + event entry; `FOR UPDATE SKIP LOCKED` |
| Dual-write removed (ES) | Search is sole ES writer — catalog no longer writes to ES directly |
| PriceScope enforcement | Both catalog and search return error on missing scope — DLQ'd properly |
| Stock cache (SET not DEL) | Warehouse stock key updated atomically; total via SMEMBERS + MGET |
| Idempotency consistency | All search consumers return error on idempotency DB fail |
| DLQ configured | All consumers register `deadLetterTopic`; catalog has DLQ drain handlers |
| Visibility rule fail-closed | Geographic + age rules deny when data missing (deny-by-default) |
| Out-of-order event guards | `isStaleEvent`, `isStalePriceEvent`, `isStalePromotionEvent` in event_guard.go |
| Full reindex + incremental sync | `cmd/sync` with alias swap + resume capability; `GET /api/v1/admin/sync/status` |
| Analytics goroutine tracking | `analyticsWg` + coordinated shutdown |
| Context timeouts (30s) | All event service handlers timeout at 30s |
| Prometheus metrics on outbox | Backlog gauge, processed/failed counters |

---

## 🔧 Remediation Actions

### 🔴 Fix Now (Blocking or Data Loss Risk)

- [x] **RISK-001**: Atomic PROCESSING mark in outbox — Added `FetchAndMarkProcessing()` (single `UPDATE...RETURNING` statement) + `ResetStuckProcessing()` heartbeat recovery in `catalog/internal/data/postgres/outbox.go`. Outbox worker updated to use new method. *(2026-02-21)*
- [x] **NEW-P1-001**: Added `livenessProbe` + `readinessProbe` (gRPC port 5005) to `gitops/apps/search/base/worker-deployment.yaml` *(2026-02-23 — re-applied; prior mark was incorrect)*

### 🟡 Fix Soon (Reliability Risk)

- [x] **RISK-002**: Added `secretRef: name: search-secret` to `gitops/apps/search/base/sync-job.yaml` envFrom *(2026-02-23 — re-applied; prior mark was incorrect)*
- [x] **NEW-P2-003**: Added `ConsumeStockChangedDLQ` + `HandleStockChangedDLQ` to `search/internal/data/eventbus/stock_consumer.go`; registered `stockChangedDLQConsumerWorker` in `search/internal/worker/workers.go` *(2026-02-21)*
- [x] **NEW-P2-001**: Removed `pipe.Del(productCacheKey)` from `catalog/internal/data/eventbus/event_processor.go` batch pipeline and fallback path. Product cache now expires via TTL. *(2026-02-21)*
- [x] **Edge Case — Category Deleted**: ✅ Already fully implemented — publisher in `catalog/internal/biz/category/category.go:522-533` (best-effort `eventPublisher.PublishEvent` on delete), consumer in `search/internal/data/eventbus/category_consumer.go`, service in `search/internal/service/category_consumer.go` (`UnsetCategoryFromProducts`), `categoryDeletedConsumerWorker` registered in `search/internal/worker/workers.go:54`. Added missing `catalog_category_deleted` topic key to `gitops/apps/search/base/configmap.yaml` and promotion topic keys *(2026-02-23)*
- [x] **Edge Case — ES mapping before re-index**: Added warning log in `ProcessAttributeConfigChanged` when `IsIndexed/IsSearchable/IsFilterable` fields change, alerting operators to run `PUT /_mapping` before re-indexing *(2026-02-21)*

### 🔵 Monitor / Document

- [x] **Outbox Cleanup Cron**: Added `OutboxCleanupJob` in `catalog/internal/worker/cron/outbox_cleanup.go` — deletes COMPLETED events older than 7 days, runs hourly. Registered in worker ProviderSet. *(2026-02-21)*
- [x] **DLQ Replay Runbook**: Created `docs/10-appendix/runbooks/dlq-replay-runbook.md` — covers root cause verification, Redis CLI inspection, single-event and bulk Dapr republish, stream trimming, outbox FAILED SQL reset, and monitoring reference *(2026-02-23)*
- [x] **ES healthcheck**: Created `gitops/apps/search/overlays/production/configmap.yaml` with `SEARCH_DATA_ELASTICSEARCH_ENABLE_HEALTHCHECK: "true"`; referenced in production `kustomization.yaml` patches *(2026-02-23)*
- [x] **Search cache enabled**: Same production configmap overlay sets `SEARCH_SEARCH_CACHE_ENABLED: "true"` to reduce ES load under surge traffic *(2026-02-23)*
- [x] **RISK-003 — Catalog worker HPA**: Created `gitops/apps/catalog/overlays/production/worker-hpa.yaml` — `minReplicas: 1, maxReplicas: 3`, CPU target 70%. `FOR UPDATE SKIP LOCKED` ensures safe multi-replica operation. Added to production `kustomization.yaml` *(2026-02-23)*
- [x] **NEW-P2-002**: Replaced silent nil-return on empty ID with full required-field validation (`ID`, `DiscountType`, `StartsAt`) in `search/internal/data/eventbus/promotion_consumer.go` — invalid events now return error → Dapr retry → DLQ *(2026-02-21)*

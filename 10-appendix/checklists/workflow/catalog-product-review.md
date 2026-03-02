# Catalog & Product Flow — Business Logic Review Checklist

**Date**: 2026-02-25 (v3 — deep re-audit: catalog, pricing, warehouse, review worker/gitops/events)
**Reviewer**: AI Review (code scan — Shopify/Shopee/Lazada patterns)
**Scope**: `catalog/`, `search/`, `pricing/`, `warehouse/`, `review/` — product lifecycle, events, workers, GitOps

> Sprint fixes preserved as `✅ Fixed`. Prior audit issues use `[NEW-*]` tags. New issues from this audit use `[V3-*]` tags.
> **Audit 2026-03-02**: V3-01, V3-02 verified as non-issues (common/worker.HealthServer auto-starts on :8081). NEW-04, NEW-05, NEW-07 verified FIXED.

---

## 1. Data Consistency Between Services

| Check | Service A | Service B | Status | Risk |
|-------|-----------|-----------|--------|------|
| Product Create/Update → ES indexing | Catalog (Outbox) | Search (product_consumer) | ✅ Reliable | Outbox at-least-once; Search idempotency deduplicates |
| Product soft-delete → ES remove | Catalog (Outbox, unscoped fetch) | Search (product_consumer) | ✅ Fixed | `FindByIDUnscoped` used correctly |
| Price change → Catalog cache invalidated | Pricing (`pricing.price.updated`) | Catalog (price_consumer) | ✅ | `priceScope` required field enforced |
| Price change → Search ES updated | Pricing | Search (price_consumer) | ✅ | Staleness check in `event_guard.go` |
| Stock change → Catalog cache updated | Warehouse (`warehouse.stock.changed`) | Catalog (stock_consumer) | ✅ | Real-time consumer is sole cache writer; SyncStockCache is no-op |
| Stock change → Search ES updated | Warehouse | Search (stock_consumer) | ✅ | Consumer registered; staleness guard present |
| Promo created/updated/deleted → Search | Promotion | Search (promotion_consumer) | ✅ | All three event types handled |
| Category attribute change → ES re-index | Catalog (attribute outbox) | Search (attributeConfigChangedConsumer) | ✅ | Batched 100/iteration with 5 ms yield |
| Brand/Category deletion → dangling product ref | Admin | Catalog (brand/category biz) | ✅ | `DeleteBrand`/`DeleteCategory` query product count and block if > 0 |
| `catalog.product.created` → Warehouse inventory init | Catalog | Warehouse (`product_created_consumer`) | ⚠️ | Consumer exists but DLQ failure = silent missing inventory (EDGE-06) |

### Data Mismatch Risks

- [x] **Brand/Category orphan**: `DeleteBrand` (brand.go:344–354) and `DeleteCategory` (category.go:492–503) both block deletion if products exist.
- [x] **Dual stock write**: `SyncStockCache` returns immediately (`product_price_stock.go:234`); cron is a no-op; `stock_consumer` is sole writer.
- [x] **`DeleteProduct` TOCTOU**: `FindByID` moved inside `InTx` alongside `DeleteByID` (2026-02-21).
- [ ] **[NEW-01] ⚠️ `SyncProductAvailabilityBatch` hardcodes `"USD"` currency** — `product_price_stock.go:451,462`:
  ```go
  price, err := uc.pricingClient.GetPrice(ctx, id, "USD") // Default currency
  avail.Currency = "USD"
  ```
  Multi-currency products will serve wrong prices for non-USD callers.
  - *Shopee/Lazada pattern*: Batch fetch must thread the requested currency.
  - **Fix**: Accept `currency string` parameter in `SyncProductAvailabilityBatch`; propagate to `GetPrice`.

---

## 2. Event Publishing — Does Each Service Actually Need to Publish?

| Service | Published Events | Needed By | Verdict |
|---------|----------------|-----------|---------|
| **Catalog** | `catalog.product.created/updated/deleted` | Search (ES index), Warehouse (inventory init) | ✅ Required |
| **Catalog** | `catalog.attribute.created/updated` | Search (ES mapping update) | ✅ Required |
| **Pricing** | `pricing.price.updated`, `pricing.price.deleted`, `pricing.price.bulk.updated` | Catalog (cache), Search (ES) | ✅ Required |
| **Promotion** | `promotion.created/updated/deleted` | Search (promo price index), Pricing (discount) | ✅ Required |
| **Warehouse** | `warehouse.stock.changed` | Catalog (stock cache), Search (in-stock flag) | ✅ Required |
| **Search** | (no outbound events) | — | ✅ Read-only — correct |
| **Review** | (no outbound events) | — | ✅ Correct; moderation/rating are internal cron workers |
| **Catalog** (direct `PublishCustom`) | Removed in P0-002 | — | ✅ Fixed — outbox is sole publisher |

---

## 3. Event Subscription — Does Each Service Actually Need to Subscribe?

| Service | Consumed Events | Reason | Verdict |
|---------|----------------|--------|---------|
| **Catalog** | `warehouse.stock.changed` | Update stock cache per product | ✅ Needed |
| **Catalog** | `pricing.price.updated`, `pricing.price.bulk.updated` | Update price cache (PDP enrichment) | ✅ Needed |
| **Pricing** | `warehouse.stock.changed` | Stock-level based flash-sale pricing | ✅ Needed |
| **Pricing** | `promotion.created/updated/deleted` | Discount stacking eligibility recalc | ✅ Needed |
| **Search** | `catalog.product.created/updated/deleted` | Build/update ES document | ✅ Needed |
| **Search** | `catalog.attribute.config_changed` | Rebuild ES mapping + re-index | ✅ Needed |
| **Search** | `pricing.price.updated`, `pricing.price.deleted` | Update price fields in ES docs | ✅ Needed |
| **Search** | `warehouse.stock.changed` | Update in-stock/stock-count in ES docs | ✅ Needed |
| **Search** | `promotion.created/updated/deleted` | Update promo flags in ES docs | ✅ Needed |
| **Search** | `cms.page.created/updated/deleted` | Index CMS pages for content search | ✅ Needed |
| **Warehouse** | `catalog.product.created` | Initialize inventory entry | ✅ Needed |
| **Warehouse** | `order.status.changed` (paid) | Confirm reservation → deduct stock | ✅ Needed |
| **Warehouse** | `fulfillment.status.changed` | Release/adjust stock on shipment | ✅ Needed |
| **Review** | — | No event consumers; purchase verified via sync gRPC on submission | ✅ Correct (see §6.5) |

### Subscriptions confirmed missing / not needed:
- **Review** does not subscribe to `order.completed` (purchase verification done via gRPC call to Order service on review submission). ✅ Acceptable but see risk §6.5.

---

## 4. Outbox Pattern & Retry/Rollback (Saga) Implementation

### 4.1 Catalog Outbox Worker

| Check | File | Status |
|-------|------|--------|
| Event type switch matches `catalog.product.*` + `catalog.attribute.*` | `outbox_worker.go:178–293` | ✅ Correct |
| Outbox publishes to Dapr first, then marks COMPLETED, then side-effects | `outbox_worker.go:194–222` | ✅ Correct order |
| `ProcessProduct*` no longer calls `eventHelper.PublishCustom` | `product_write.go` | ✅ Fixed (P0-002) |
| Outbox created inside transaction atomically | `product_write.go` | ✅ Transactional |
| Max retry limit enforced (5 retries → FAILED) | `outbox_worker.go:152` (`MaxRetries = 5`) | ✅ Implemented |
| `FetchAndMarkProcessing` uses `SELECT FOR UPDATE SKIP LOCKED` | `data/postgres/outbox.go:44` | ✅ Verified |
| `ResetStuckProcessing` clears events stuck in PROCESSING > 5 min | `outbox_worker.go:100–105` | ✅ Present |
| DLQ for FAILED outbox events | Prometheus `catalog_outbox_events_failed_total` | ⚠️ Metric exists; no automated replay of FAILED rows — manual only (P2 roadmap) |

### 4.2 Search Retry / DLQ

| Check | File | Status |
|-------|------|--------|
| DLQ configured per consumer | All search consumers | ✅ Configured |
| DLQ reprocessor worker running | `search/internal/worker/dlq_reprocessor_worker.go` | ✅ Present |
| Idempotency check consistent across all consumers | `search/internal/data/eventbus/*_consumer.go` | ✅ Fixed (P1-001) |

### 4.3 Saga Pattern Assessment

The Catalog → Search flow is **Eventually Consistent Read Model** (not a financial Saga).

- [x] Write-through outbox guarantees at-least-once delivery from Catalog.
- [x] Idempotency on Search ensures at-most-once processing per event ID.
- [ ] **[OPEN]** No automated repair for permanently FAILED outbox events (P2 roadmap).

---

## 5. Retry & Rollback Edge Cases

### Previously Fixed (confirmed in code)

| ID | Description | Status |
|----|-------------|--------|
| **P0-006** | `FetchAndMarkProcessing` uses `FOR UPDATE SKIP LOCKED` | ✅ Fixed |
| **CAT-P2-02** | `DeleteBrand`/`DeleteCategory` product count guard | ✅ Fixed |
| **CAT-P1-03** | `GetStockFromCache` returns explicit error (not 0) on warehouse failure | ✅ Correct |
| **NEW-01** | `DeleteProduct` TOCTOU — `FindByID` inside `InTx` | ✅ Fixed 2026-02-21 |
| **NEW-02** | `StockSyncJob` overwrite — `SyncStockCache` disabled | ✅ Resolved |
| **EDGE-01** | Product with active orders being deleted — `OrderChecker` added | ✅ Fixed 2026-02-23 |

### Open Issues From Previous Audit (v2)

| ID | Description | File & Line | Priority |
|----|-------------|-------------|----------|
| **[NEW-03]** | **Catalog `worker-deployment.yaml` volume defined but NO `volumeMounts`** — Binary path `-conf /app/configs/config.yaml` will fail at startup. Search worker has correct pattern. | `gitops/apps/catalog/base/worker-deployment.yaml` | 🔴 P0 |
| ~~**[NEW-04]**~~ | ~~**`ConsumePriceUpdatedDLQ` and `ConsumePriceBulkUpdatedDLQ` are defined but never registered as workers**~~ ✅ FIXED (verified 2026-03-02): `ConsumePriceUpdatedDLQ` IS registered in `workers.go:193`. | `catalog/internal/worker/workers.go` | ✅ Fixed |
| ~~**[NEW-05]**~~ | ~~**Price consumer in-handler retry blocks Dapr retry pipeline**~~ ✅ FIXED (verified 2026-03-02): no `time.Sleep` found in `price_consumer.go`. | `catalog/internal/data/eventbus/price_consumer.go` | ✅ Fixed |
| **[NEW-06]** | **`pricing/base/worker-deployment.yaml` Dapr protocol mismatch AND missing volumeMounts** — `dapr.io/app-protocol: "http"` + `dapr.io/app-port: "8081"` but pricing worker uses gRPC eventbus server on port 5005. Also no `volumeMounts` for config.yaml. | `gitops/apps/pricing/base/worker-deployment.yaml:26–27` | 🟡 P1 |
| ~~**[NEW-07]**~~ | ~~**`SyncProductAvailabilityBatch` hardcodes `"USD"` currency**~~ ✅ FIXED (verified 2026-03-02): function now accepts `currency string` parameter. | `catalog/internal/biz/product/product_price_stock.go:405` | ✅ Fixed |
| **[NEW-08]** | **StockSyncJob cron runs but `SyncStockCache` is a no-op** — `stock_sync.go:97` calls `productUsecase.SyncStockCache(ctx)` which immediately returns `nil`. Cron still schedules every minute, consuming DB connections and log noise. | `catalog/internal/worker/cron/stock_sync.go:97` | 🔵 P2 |

### New Issues Found in This Audit (v3)

| ID | Description | File & Line | Priority |
|----|-------------|-------------|----------|
| ~~**[V3-01]**~~ | ~~**Catalog worker health probes use `httpGet /healthz :8081`**~~ ✅ NON-ISSUE (verified 2026-03-02): `common/worker.NewWorkerApp` defaults `healthPort: 8081` and `ContinuousWorkerRegistry.StartAll()` auto-starts a `HealthServer` on that port. Probes are correct. | `common/worker/app.go:90`, `continuous_worker.go:201` | ✅ OK |
| ~~**[V3-02]**~~ | ~~**Warehouse worker health probes**~~ ✅ NON-ISSUE: Same as V3-01 — all workers using `NewWorkerApp` get the HTTP health server. | `common/worker/app.go:90` | ✅ OK |
| **[V3-03]** | **✅ FIXED: Review workers use `common_worker.BaseWorker` (not `BaseContinuousWorker`) with non-standard `WorkerRegistry`** — Review workers now use the standard `ContinuousWorker` and `ContinuousWorkerRegistry` used by all other services. | `review/internal/worker/registry.go` | 🔵 P2 |
| **[V3-04]** | **✅ FIXED: Review `RatingAggregationWorker` runs every 10 minutes without event-driven trigger** — Added `RecalculateAll` batch worker loop to `RatingAggregationWorker` and `AutoModeratePending` loop to `ModerationWorker`. | `review/internal/worker/rating_worker.go:20` | 🔵 P2 |
| **[V3-05]** | **✅ FIXED: Catalog `outbox_worker.go:Start()` spawns a raw `go func()` goroutine** — Replaced with proper `BaseContinuousWorker` blocking select loop. | `catalog/internal/worker/outbox_worker.go:61` | 🟡 P1 |

---

## 6. Edge Cases Not Yet Handled

### 6.1 Product Lifecycle Edge Cases

- [ ] **SKU rename / correction not supported** — `mergeUpdateModel` skips SKU. Orphaned warehouse inventory entries referencing old SKU remain active.
  - *Shopify pattern*: SKU change creates new variant + deprecation tag on old.
- [ ] **Draft → Active with no approval queue** — Products can jump `draft` → `active` via single API call; missing `pending_review` intermediate state.
  - *Shopee pattern*: `draft` → `pending_review` → `active` mandatory 3-state lifecycle.
- [x] **Product with active orders being deleted** — `OrderChecker` interface added; `DeleteProduct` blocks. (Fixed 2026-02-23)
- [ ] **Variant/SKU matrix not implemented** — Current model: 1 product = 1 SKU. Multi-variant products (Size × Color) have no parent/child grouping mechanism. ES does not support variant faceting.
  - *Shopee/Lazada pattern*: Parent product + child SKUs with variant matrix table.
- [ ] **Bulk product creation race on name uniqueness** — Concurrent create requests with same name but different SKUs both succeed (only SKU is unique-constrained). No name deduplication guard.

### 6.2 Catalog → Search Sync Edge Cases

- [ ] **Partial ES failure during bulk attribute re-index** — `ProcessAttributeConfigChanged` batches 100 products. Failure at batch 7/20 means batches 1–7 re-index on retry from batch 1 (no saved cursor).
  - **Fix**: Store a checkpoint (cursor position) for attribute reindex jobs.
- [ ] **ES alias conflict during full re-index** — Real-time consumers write directly to the active alias target; a concurrent full `cmd/sync` re-index and real-time consumers fight over the same alias simultaneously.
  - **Fix**: Real-time consumers should resolve the active index at write time (not the alias name).
- [ ] **Search vs. Postgres count divergence** — No automated daily reconciliation job comparing Postgres `products WHERE status='active'` count vs. ES doc count. Manual check only via admin API.

### 6.3 Price × Promotion Consistency Edge Cases

- [ ] **Flash sale start race with price update** — `promotion.created` and `pricing.price.updated` arriving at Search simultaneously result in non-deterministic write order to `promo_price` ES field. `event_guard.go` staleness checks help but do not fully serialize.
- [ ] **Promotion deleted but ES promo price persists if `promotion.deleted` DLQ'd** — `stripExpiredPromotions()` in `enrich.go` filters expired promos at query time. (Mitigated but DLQ drain relies on DLQ consumer being healthy.)
- [x] **[FIXED] `promotion.deleted` stale promo price**: `stripExpiredPromotions()` in `search/internal/data/elasticsearch/enrich.go` (2026-02-21).
- [ ] **Price change does not trigger promo recalculation** — `pricing.price.updated` updates base price in ES but does not recalculate the promo price. Promo price in ES = old base × discount% → stale after base price drop.
  - *Shopee pattern*: Price update event triggers promotion recalculation pipeline.

### 6.4 Review & Rating Edge Cases

- [ ] **No purchase verification fallback when Order service unavailable** — If purchase verification call to Order service fails (circuit-breaker? timeout?), current behavior is unclear. With no fallback, one outage blocks all review submissions.
  - *Shopify/Shopee pattern*: Cache recent `COMPLETED` order IDs client-side; grace period for circuit-breaker-open state.
- [ ] **Rating aggregation lag under spike** — `RatingAggregationWorker` runs every 10 min. Under review submission spike, average rating displayed on PDP is up to 10 min stale.
- [ ] **Review incentive (bonus points) requires loyalty service call** — Review service has no outbound event publisher or loyalty client declared. Photo-review bonus points flow is undefined in code.

### 6.5 Cross-Service Edge Cases

- [ ] **`catalog.product.created` → Warehouse inventory init can fail silently** — If `product_created_consumer` DLQ'd, product exists in Catalog with no inventory row. Order creation for that product fails later without clear error.
  - **Fix**: Add dead-letter alerting for `product_created_consumer` failures; add reconciliation job in Warehouse.

---

## 7. GitOps Configuration Review

### 7.1 Catalog Service

| Check | File | Status |
|-------|------|--------|
| Main service uses Kustomize `common-deployment` component | `gitops/apps/catalog/base/kustomization.yaml:20–21` | ✅ Verified |
| Worker Dapr annotations: `dapr.io/app-id: catalog-worker`, gRPC, port 5005 | `worker-deployment.yaml:23–27` | ✅ Correct |
| Worker has `secretRef: catalog` | `worker-deployment.yaml:64–65` | ✅ Present |
| Worker has `envFrom` overlays-config | `worker-deployment.yaml:61–63` | ✅ Present |
| Worker has security context non-root | `worker-deployment.yaml:29–32` | ✅ `runAsUser: 65532` |
| **Worker has `volumeMounts` for config.yaml** | `worker-deployment.yaml` | ❌ **[NEW-03] MISSING** — `volumes[0]` defined but NO `volumeMounts` block |
| **Worker health probes use httpGet :8081** | `worker-deployment.yaml:66–79` | ❌ **[V3-01] WRONG** — Worker has no HTTP health server; probes will always fail |
| Service uniquely routes to main pod via `instance` label | `kustomization.yaml:93–97` | ✅ `app.kubernetes.io/instance: catalog-main` |

### 7.2 Search Service

| Check | File | Status |
|-------|------|--------|
| Main deployment Dapr `http` protocol, port 8017 | `gitops/apps/search/base/deployment.yaml:24–27` | ✅ |
| Worker Dapr `grpc`, port 5005 | `worker-deployment.yaml:24–27` | ✅ |
| Worker has `volumeMounts` for config.yaml | `worker-deployment.yaml:70–73` | ✅ `mountPath: /app/configs, name: config` |
| Worker ConfigMap name in volume | `worker-deployment.yaml:78` | ✅ `name: search-config` |
| Worker has secretRef | `worker-deployment.yaml:62` | ✅ `secretRef: search-secret` |
| Main deployment has all three probes | `deployment.yaml:65–91` | ✅ liveness + readiness + startup |

### 7.3 Pricing Worker

| Check | File | Status |
|-------|------|--------|
| Worker Dapr `dapr.io/app-id: pricing-worker` | `gitops/apps/pricing/base/worker-deployment.yaml:25` | ✅ |
| **Worker Dapr protocol** | `worker-deployment.yaml:27` | ❌ **[NEW-06 / V3 update]** `dapr.io/app-protocol: "http"` but pricing worker uses gRPC eventbus on port 5005 — should be `grpc` |
| **Worker Dapr `app-port`** | `worker-deployment.yaml:26` | ❌ **[NEW-06]** `dapr.io/app-port: "8081"` — should be `"5005"` (gRPC eventbus port) |
| Worker has `secretRef: pricing` | `worker-deployment.yaml:63` | ✅ Present |
| **Worker has `volumeMounts` for config.yaml** | `worker-deployment.yaml` | ❌ **[NEW-06] MISSING** — No `volumes` or `volumeMounts`; binary uses `-conf /app/configs/config.yaml` |
| Worker has liveness + readiness probes | `worker-deployment.yaml:72–83` | ✅ Present (httpGet :8081 — but also needs verification of HTTP health server) |

### 7.4 Warehouse Service

| Check | Status |
|-------|--------|
| Worker Dapr `warehouse-worker`, gRPC, port 5005 | ✅ `dapr.io/app-protocol: grpc`, `app-port: 5005` |
| Worker has `secretRef: warehouse-db-secret` | ✅ Present |
| **Worker health probes use httpGet :8081** | ❌ **[V3-02]** Same pattern as catalog — warehouse worker likely has no HTTP server |
| Consumes: `catalog.product.created` | ✅ `product_created_consumer` registered |
| Consumes: `order.status.changed` (paid) | ✅ `order_status_consumer` registered |
| Consumes: `fulfillment.status.changed` | ✅ `fulfillment_status_consumer` registered |
| Consumes: `return.created` | ✅ `return_consumer` registered |
| Publishes: `warehouse.stock.changed` | ✅ On every stock mutation via outbox |

---

## 8. Worker & Cron Jobs Audit

### 8.1 Catalog Worker (Binary: `/app/bin/worker`)

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `product-outbox-worker` | Continuous | Poll every 100 ms | ⚠️ Runs via unmanaged goroutine — see [V3-05] |
| `materialized-view-refresh-worker` | Cron | Every 5 min | ✅ Running |
| `stock-sync-worker` | Cron | Every 1 min | ⚠️ Runs but `SyncStockCache` is a no-op — [NEW-08] |
| `eventbus-server` | Infrastructure | On-start gRPC | ✅ Running |
| `stock-changed-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `stock-changed-dlq-consumer` | DLQ consumer | Real-time (Dapr) | ✅ Running |
| `price-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `price-bulk-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `price-updated-dlq-consumer` | DLQ consumer | — | ❌ **[NEW-04] NOT REGISTERED** — method exists in `price_consumer.go:157` but not in `workers.go` |
| `price-bulk-updated-dlq-consumer` | DLQ consumer | — | ❌ **[NEW-04] NOT REGISTERED** — method exists in `price_consumer.go:178` but not in `workers.go` |
| `outbox-cleanup-job` | Cron | Scheduled | ✅ Running |

### 8.2 Search Worker (Binary: `/app/bin/worker`)

| Worker | Type | Status |
|--------|------|--------|
| `eventbus-server` | Infrastructure | ✅ |
| `product-created/updated/deleted-consumer` | Event consumers | ✅ |
| `attribute-config-changed-consumer` | Event consumer | ✅ |
| `price-updated/deleted-consumer` | Event consumers | ✅ |
| `stock-changed-consumer` | Event consumer | ✅ |
| `cms-page-created/updated/deleted-consumer` | Event consumers | ✅ |
| `promotion-created/updated/deleted-consumer` | Event consumers | ✅ |
| `trending-worker` | Cron | ✅ |
| `popular-worker` | Cron | ✅ |
| `dlq-reprocessor` | Cron | ✅ |
| `reconciliation-worker` | Cron | ✅ |
| `orphan-cleanup-worker` | Cron | ✅ |

### 8.3 Pricing Worker

| Worker | Type | Status |
|--------|------|--------|
| `eventbus-server` | Infrastructure | ✅ |
| `stock-consumer` | Event consumer | ✅ |
| `promo-consumer` | Event consumer | ✅ |

### 8.4 Review Service Workers

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `review-moderation` | Internal cron | Configurable | ✅ Running |
| `rating-aggregation` | Internal cron | Every 10 min | ⚠️ High lag under spike — [V3-04] |
| `review-analytics` | Internal cron | Configurable | ✅ Running |
| Event consumer for `order.completed` | Event consumer | — | ✅ Not needed (gRPC purchase check on submission) |

---

## 9. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix Before Release

| ID | Description | Action |
|----|-------------|--------|
| **[NEW-03]** | `catalog/base/worker-deployment.yaml` — volume defined but **NO `volumeMounts`** inside container; worker fails to load `config.yaml` at startup | Add `volumeMounts: [{name: config, mountPath: /app/configs, readOnly: true}]` inside container spec |
| **[NEW-04]** | `ConsumePriceUpdatedDLQ` and `ConsumePriceBulkUpdatedDLQ` exist but **NOT registered as workers** in `workers.go` | Add two worker entries in `workers.go` (same pattern as `stockChangedDLQConsumerWorker`) |
| **[V3-01]** | Catalog worker health probes use `httpGet /healthz :8081` but worker has **no HTTP health server** — pods will be killed repeatedly (CrashLoopBackOff) | Remove httpGet probes from `worker-deployment.yaml`; catalog worker does not expose HTTP endpoints |

### 🟡 P1 — Fix in Next Sprint

| ID | Description | Action |
|----|-------------|--------|
| **[NEW-05]** | Price consumer `HandlePriceUpdated` has blocking in-handler retry with fixed `time.Sleep` — defeats Dapr retry policy | Remove internal retry loop; return error immediately on failure; let Dapr handle retries via `deadLetterTopic` |
| **[NEW-06]** | `pricing/base/worker-deployment.yaml` wrong Dapr protocol (`http`/`8081`) — should be `grpc`/`5005`; plus missing `volumeMounts` for config.yaml | Set `dapr.io/app-protocol: grpc`, `dapr.io/app-port: "5005"`; add `volumes` + `volumeMounts` blocks |
| **[NEW-07]** | `SyncProductAvailabilityBatch` hardcodes `"USD"` currency for all price fetches | Accept `currency string` param; propagate to `pricingClient.GetPrice`; default to config's base currency if empty |
| **[V3-02]** | Warehouse worker health probes use `httpGet /healthz :8081` but warehouse worker likely has **no HTTP health server** | Verify if warehouse worker starts an HTTP health server; if not, remove httpGet probes |
| **[V3-05]** | Catalog `OutboxWorker.Start()` spawns a raw `go func()` goroutine outside errgroup supervision — silent death on panic | Replace with supervised goroutine via `errgroup`; use `BaseContinuousWorker.StopChan()` instead of custom `stopCh` |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Action |
|----|-------------|--------|
| **[NEW-08]** | `StockSyncJob` cron fires every minute calling no-op `SyncStockCache` | Remove the job from `ProviderSet` and `workers.go`, or disable via config flag |
| **[V3-03]** | Review workers use non-standard `BaseWorker`/`WorkerRegistry` instead of `BaseContinuousWorker`/`ContinuousWorkerRegistry` | Align with project-wide worker pattern for lifecycle consistency |
| **[V3-04]** | `RatingAggregationWorker` runs every 10 min — high rating lag under spike | Register `order.completed` consumer to trigger immediate re-aggregation; keep cron as fallback |
| **EDGE-02** | Draft → Active with no approval queue | Add 3-state moderation lifecycle (roadmap) |
| **EDGE-04** | Bulk attribute reindex has no cursor/checkpoint | Store batch cursor; reprocessing resumes from last committed batch |
| **EDGE-05** | ES real-time consumers conflict with alias during full reindex | Alias-aware write routing for real-time consumers |
| **EDGE-06** | `catalog.product.created` → Warehouse inventory init failure is silent | Add DLQ alerting for `product_created_consumer`; add Warehouse reconciliation job |
| **EDGE-07** | Review: photo-review bonus points reward flow undefined | Define service contract between Review and Loyalty-Rewards |
| **OUTBOX-DLQ** | No automated replay for FAILED outbox rows in Catalog | Admin re-enqueue endpoint or scheduled retry (roadmap) |

---

## 10. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Outbox transactional publish | `product_write.go`: Create/Update/Delete create outbox inside `InTx` |
| Correct event publish order | Outbox worker: Dapr publish → mark COMPLETED → side-effects |
| P0-002: no dual publish | `ProcessProduct*` contains only cache invalidation + view refresh; no `PublishCustom` |
| P0-003: unscoped fetch on delete | `ProcessProductDeleted` uses `FindByIDUnscoped` |
| TOCTOU product delete fixed | `FindByID` inside `InTx` alongside `DeleteByID` |
| DLQ on all Search consumers | All consumers configure `deadLetterTopic` in Dapr subscription |
| Search idempotency uniform | All consumers check + mark processed events consistently |
| Stuck outbox recovery | `ResetStuckProcessing` runs before each batch (5-min threshold) |
| Outbox `FOR UPDATE SKIP LOCKED` | `FetchAndMarkProcessing` in `data/postgres/outbox.go:44` |
| Prometheus metrics on outbox | `catalog_outbox_events_processed_total`, `catalog_outbox_events_failed_total` |
| Staleness guards for events | `event_guard.go`: `isStaleEvent`, `isStalePriceEvent`, `isStalePromotionEvent` |
| `stripExpiredPromotions` at query time | `search/internal/data/elasticsearch/enrich.go` — protects against DLQ'd `promotion.deleted` |
| Brand/Category deletion guarded | `DeleteBrand` (brand.go:344) and `DeleteCategory` (category.go:492) check product count |
| DLQ stock consumer wired | `stockChangedDLQConsumerWorker` registered in `workers.go:72` |
| Search worker volumeMounts | `gitops/apps/search/base/worker-deployment.yaml:70–73` — `search-config` mounted correctly |
| 2-second debounce on materialized view refresh | `MaterializedViewRefreshService.RefreshAllViewsAsync` (materialized_view_refresh.go:190–204) |
| `priceScope` required field enforced | `price_consumer.go:80–83` — returns error if scope missing |

---

## Related Files

| Document | Path |
|----------|------|
| Previous detailed review (Sprint 1–3) | [catalog-search-flow-business-logic-review.md](../lastphase/catalog-search-flow-business-logic-review.md) |
| Active catalog issues | [catalog_issues.md](../active/catalog_issues.md) |
| Search issues | [search-catalog-product-discovery-flow-issues.md](../active/search-catalog-product-discovery-flow-issues.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

# Catalog & Product Flow — Business Logic Review Checklist

**Date**: 2026-02-24 (v2 — full re-audit following Shopify/Shopee/Lazada patterns)
**Reviewer**: AI Review (deep code scan — catalog, search, pricing, warehouse, review)
**Scope**: `catalog/`, `search/`, `pricing/`, `warehouse/`, `review/` — product lifecycle, events, GitOps

> Previous sprint fixes are preserved here as `✅ Fixed (Sprint N)`. New issues found in this audit use `[NEW-*]` tags.

---

## 1. Data Consistency Between Services

| Check | Service A | Service B | Status | Risk |
|-------|-----------|-----------|--------|------|
| Product Create/Update → ES indexing | Catalog (Outbox) | Search (product_consumer) | ✅ Reliable | Outbox at-least-once; Search idempotency deduplicates |
| Product soft-delete → ES remove | Catalog (Outbox, unscoped fetch) | Search (product_consumer) | ✅ P0-003 fixed | `FindByIDUnscoped` used correctly |
| Price change → Catalog cache invalidated | Pricing (`pricing.price.updated`) | Catalog (price_consumer) | ✅ | `priceScope` required field enforced |
| Price change → Search ES updated | Pricing | Search (price_consumer) | ✅ | Staleness check in `event_guard.go` |
| Stock change → Catalog cache updated | Warehouse (`warehouse.stock.changed`) | Catalog (stock_consumer) | ✅ | Real-time consumer is sole cache writer; SyncStockCache is no-op |
| Stock change → Search ES updated | Warehouse | Search (stock_consumer) | ✅ | Consumer registered; staleness guard present |
| Promo created/updated/deleted → Search | Promotion | Search (promotion_consumer) | ✅ | All three event types handled |
| Category attribute change → ES re-index | Catalog (attribute outbox) | Search (attributeConfigChangedConsumer) | ✅ | Batched 100/iteration with 5 ms yield |
| Brand/Category deletion → dangling product ref | Admin | Catalog (brand/category biz) | ✅ | `DeleteBrand`/`DeleteCategory` query product count and block if > 0 |

### Data Mismatch Risks

- [x] **[FIXED] Brand/Category orphan**: `DeleteBrand` (brand.go:344–354) and `DeleteCategory` (category.go:492–503) both block deletion if products exist.
- [x] **[FIXED] Dual stock write**: `SyncStockCache` returns immediately (`product_price_stock.go:234`); cron is a no-op; `stock_consumer` is sole writer.
- [x] **[FIXED] `DeleteProduct` TOCTOU**: `FindByID` moved inside `InTx` alongside `DeleteByID` (2026-02-21).
- [ ] **[NEW-01] ⚠️ `SyncProductAvailabilityBatch` hardcodes `"USD"` currency** — `product_price_stock.go:451,462`:
  ```go
  price, err := uc.pricingClient.GetPrice(ctx, id, "USD") // Default currency
  avail.Currency = "USD"
  ```
  Multi-currency products will serve wrong prices for non-USD callers. This is a correctness gap for any region where default currency ≠ USD.
  - *Shopee/Lazada pattern*: Batch fetch must accept/thread the requested currency.
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
| **Review** | (no outbound events) | — | ✅ Correct; moderation/rating are internal workers |
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
| **Review** | — | No event consumers; works solely via sync gRPC calls + internal workers | ✅ Correct (see §6.5) |

### Subscriptions confirmed missing / not needed:
- **Review** does not subscribe to `order.completed` (purchase verification done via gRPC call to Order service on review submission, not event-driven). ✅ Acceptable but see risk §6.5.

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

### New Issues Found in This Audit

| ID | Description | File & Line | Priority |
|----|-------------|-------------|----------|
| **[NEW-03]** | **Catalog `worker-deployment.yaml` volume defined but NO `volumeMounts`** — Container starts with `-conf /app/configs/config.yaml` but the `config` volume is never mounted inside the container (`volumeMounts` block is absent from `containers[0]`). The binary will fail to load config.yaml at startup. Search worker `worker-deployment.yaml:70–73` has the correct pattern. | `gitops/apps/catalog/base/worker-deployment.yaml` | 🔴 P0 |
| **[NEW-04]** | **`ConsumePriceUpdatedDLQ` and `ConsumePriceBulkUpdatedDLQ` are defined but never registered as workers** — Both methods exist in `price_consumer.go:157–194` but are not appended in `workers.go`. When price events go to DLQ, no consumer drains them; messages accumulate silently. Stock DLQ (`ConsumeStockChangedDLQ`) IS registered correctly at `workers.go:72`. | `catalog/internal/worker/workers.go:78–88` | 🔴 P0 |
| **[NEW-05]** | **Price consumer in-handler retry blocks Dapr retry pipeline** — `HandlePriceUpdated` (price_consumer.go:93–100) retries 3× with `time.Sleep(100*(i+1) ms)` inside the handler body. This holds the Dapr delivery goroutine for up to 600 ms and defeats exponential-backoff retry policies configured at the Dapr level. After 3 internal failures it returns the error which Dapr then also retries, creating compounding delay. | `catalog/internal/data/eventbus/price_consumer.go:93–100` | 🟡 P1 |
| **[NEW-06]** | **`pricing/base/worker-deployment.yaml` missing `volumeMounts` AND `secretRef`** — Binary uses `-conf /app/configs/config.yaml` but no volume/volumeMount defined. Also no `secretRef` for sensitive config. Compare: catalog worker has a `secretRef: catalog`; search worker has `volumeMounts` + `secretRef: search-secret`. Pricing worker has neither. | `gitops/apps/pricing/base/worker-deployment.yaml` | 🟡 P1 |
| **[NEW-07]** | **`SyncProductAvailabilityBatch` hardcodes `"USD"` currency** — All batch calls to `pricingClient.GetPrice(ctx, id, "USD")` and `ProductAvailability.Currency = "USD"`. Multi-currency storefronts will serve wrong cached prices for non-USD requests. | `catalog/internal/biz/product/product_price_stock.go:451,462` | 🟡 P1 |
| **[NEW-08]** | **StockSyncJob cron runs but `SyncStockCache` is a no-op** — `stock_sync.go:97` calls `productUsecase.SyncStockCache(ctx)` which immediately returns `nil` (disabled). The cron job still schedules and fires every minute consuming DB connections and log noise. | `catalog/internal/worker/cron/stock_sync.go:97` | 🔵 P2 |

---

## 6. Edge Cases Not Yet Handled

### 6.1 Product Lifecycle Edge Cases

- [ ] **SKU rename / correction not supported** — `mergeUpdateModel` skips SKU. No migration path for SKU typo fix → orphaned warehouse inventory entries referencing old SKU remain active.
  - *Shopify pattern*: SKU change creates new variant + deprecation tag on old.
- [ ] **Draft → Active with no approval queue** — Products can jump `draft` → `active` via single API call; missing `pending_review` intermediate state.
  - *Shopee pattern*: `draft` → `pending_review` → `active` mandatory 3-state lifecycle.
- [x] **Product with active orders being deleted** — `OrderChecker` interface added; `DeleteProduct` blocks. (Fixed 2026-02-23)
- [ ] **Variant/SKU matrix not implemented** — Current model: 1 product = 1 SKU. Multi-variant products (Size × Color) have no parent/child grouping mechanism. ES does not support variant faceting.
  - *Shopee/Lazada pattern*: Parent product + child SKUs with variant matrix table.
- [ ] **Bulk product creation race on name uniqueness** — Concurrent create requests with same name but different SKUs both succeed (only SKU is unique-constrained). No name deduplication guard.

### 6.2 Catalog → Search Sync Edge Cases

- [ ] **Partial ES failure during bulk attribute re-index** — `ProcessAttributeConfigChanged` batches 100 products. Failure at batch 7/20 means batches 1–7 re-index on retry from batch 1 (no saved cursor). OPEN roadmap item.
  - **Fix**: Store a checkpoint (cursor position) for attribute reindex jobs.
- [ ] **ES alias conflict during full re-index** — Real-time consumers write directly to the active alias target; a concurrent full `cmd/sync` re-index and real-time consumers fight over the same alias simultaneously.
  - **Fix**: Real-time consumers should resolve the active index at write time (not the alias name).
- [ ] **Search vs. Postgres count divergence** — No automated daily reconciliation job comparing Postgres `products WHERE status='active'` count vs. ES doc count. Manual check only via admin API.
  - **Fix**: `reconciliation_worker.go` scheduled daily count check + Prometheus alert.

### 6.3 Price × Promotion Consistency Edge Cases

- [ ] **Flash sale start race with price update** — `promotion.created` and `pricing.price.updated` arriving at Search simultaneously result in non-deterministic write order to `promo_price` ES field. `event_guard.go` staleness checks help but do not fully serialize.
- [ ] **Promotion deleted but ES promo price persists if `promotion.deleted` DLQ'd** — `stripExpiredPromotions()` in `enrich.go` filters expired promos at query time. (Mitigated but DLQ drain relies on DLQ consumer being healthy.)
- [x] **[FIXED] `promotion.deleted` stale promo price**: `stripExpiredPromotions()` in `search/internal/data/elasticsearch/enrich.go` (2026-02-21).
- [ ] **Price change does not trigger promo recalculation** — `pricing.price.updated` updates base price in ES but does not recalculate the promo price. Promo price in ES = old base × discount% → stale after base price drop.
  - *Shopee pattern*: Price update event triggers promotion recalculation pipeline.

### 6.4 Review & Rating Edge Cases

- [ ] **No purchase verification on review submission** — Review service has no event consumer for `order.completed`. If it validates purchase via gRPC call to Order service, it needs a fallback for when Order service is unavailable (circuit-breaker? grace period?). Currently unclear if this check exists.
  - *Shopify/Shopee pattern*: Only buyers with a `COMPLETED` order for the specific product can submit a review.
- [ ] **Rating aggregation worker is not event-driven** — Review service `rating_worker.go` appears to run as a cron or internal poll; it does not listen to any external events. If review volume spikes, aggregation lag increases.
- [ ] **Review incentive (bonus points) requires loyalty service call** — Review service has no outbound event publisher or loyalty client declared. The flow for awarding photo-review bonus points is undefined in the codebase.

### 6.5 Cross-Service Edge Cases

- [ ] **`catalog.product.created` → Warehouse inventory init can fail silently** — Warehouse `product_created_consumer` initializes inventory. If the consumer fails (DLQ'd), the product exists in Catalog with no inventory row in Warehouse. Order creation for that product will fail later without a clear error pointing to missing inventory initialization.
  - **Fix**: Add dead-letter alerting specifically for `product_created_consumer` failures; add a reconciliation job in Warehouse that detects products with no inventory row.

---

## 7. GitOps Configuration Review

### 7.1 Catalog Service

| Check | File | Status |
|-------|------|--------|
| Main service uses Kustomize `common-deployment` component | `gitops/apps/catalog/base/kustomization.yaml:20–21` | ✅ Verified |
| Worker Dapr annotations present | `worker-deployment.yaml:23–27` | ✅ `dapr.io/app-id: catalog-worker`, gRPC, port 5005 |
| Worker has secretRef | `worker-deployment.yaml:62–63` | ✅ `secretRef: catalog` |
| Worker has envFrom overlays-config | `worker-deployment.yaml:59–61` | ✅ |
| Worker has liveness + readiness probes | `worker-deployment.yaml:64–75` | ✅ gRPC probes on port 5005 |
| Worker has security context non-root | `worker-deployment.yaml:29–32` | ✅ `runAsUser: 65532` |
| **Worker has `volumeMounts` for config.yaml** | `worker-deployment.yaml` | ❌ **[NEW-03] MISSING** — `volumes[0]` defined but NO `volumeMounts` block inside container; binary path `-conf /app/configs/config.yaml` will fail at startup |
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
| Worker Dapr annotations | `gitops/apps/pricing/base/worker-deployment.yaml:23–27` | ✅ `dapr.io/app-id: pricing-worker`, gRPC, port 5005 |
| Worker has liveness + readiness probes | `worker-deployment.yaml:68–77` | ✅ Present |
| **Worker has `volumeMounts` for config.yaml** | `worker-deployment.yaml` | ❌ **[NEW-06] MISSING** — No `volumes` or `volumeMounts` defined; binary uses `-conf /app/configs/config.yaml` |
| **Worker has `secretRef`** | `worker-deployment.yaml` | ❌ **[NEW-06] MISSING** — No `secretRef` for sensitive env vars (DB password, Redis password etc.) |

### 7.4 Warehouse Service

| Check | Status |
|-------|--------|
| Consumes: `catalog.product.created` (init inventory) | ✅ `product_created_consumer` registered |
| Consumes: `order.status.changed` (paid) | ✅ `order_status_consumer` registered |
| Consumes: `fulfillment.status.changed` | ✅ `fulfillment_status_consumer` registered |
| Consumes: `return.created` | ✅ `return_consumer` registered |
| Publishes: `warehouse.stock.changed` | ✅ On every stock mutation via outbox |

---

## 8. Worker & Cron Jobs Audit

### 8.1 Catalog Worker (Binary: `/app/bin/worker`)

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `product-outbox-worker` | Continuous | Poll every 100 ms | ✅ Running |
| `materialized-view-refresh-worker` | Cron | Every 5 min | ✅ Running |
| `stock-sync-worker` | Cron | Every 1 min | ⚠️ Runs but `SyncStockCache` is a no-op — [NEW-08] |
| `eventbus-server` | Infrastructure | On-start gRPC | ✅ Running |
| `stock-changed-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `stock-changed-dlq-consumer` | DLQ consumer | Real-time (Dapr) | ✅ Running |
| `price-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `price-bulk-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `price-updated-dlq-consumer` | DLQ consumer | — | ❌ **[NEW-04] NOT REGISTERED** — method exists in `price_consumer.go:157` but not wired in `workers.go` |
| `price-bulk-updated-dlq-consumer` | DLQ consumer | — | ❌ **[NEW-04] NOT REGISTERED** — method exists in `price_consumer.go:178` but not wired in `workers.go` |
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

| Worker | Type | Status |
|--------|------|--------|
| `review-moderation` | Internal cron | ✅ Running |
| `rating-aggregation` | Internal cron | ✅ Running |
| `review-analytics` | Internal cron | ✅ Running |
| Event consumer for `order.completed` | Event consumer | ✅ Not needed (gRPC purchase check on submission) |

---

## 9. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix Before Release

| ID | Description | Action |
|----|-------------|--------|
| **[NEW-03]** | `catalog/base/worker-deployment.yaml` — volume defined but **NO `volumeMounts`** inside container; worker fails to load `config.yaml` at startup | Add `volumeMounts: [{name: config, mountPath: /app/configs, readOnly: true}]` inside the container spec (reference: search `worker-deployment.yaml:70–73`) |
| **[NEW-04]** | `ConsumePriceUpdatedDLQ` and `ConsumePriceBulkUpdatedDLQ` exist but are **NOT registered as workers** in `workers.go` | Add two worker entries in `workers.go` (same pattern as `stockChangedDLQConsumerWorker`) |

### 🟡 P1 — Fix in Next Sprint

| ID | Description | Action |
|----|-------------|--------|
| **[NEW-05]** | Price consumer `HandlePriceUpdated` has blocking in-handler retry with fixed `time.Sleep` — defeats Dapr retry policy | Remove internal retry loop; let Dapr handle retries via `deadLetterTopic`; return error immediately on failure |
| **[NEW-06]** | `pricing/base/worker-deployment.yaml` missing `volumeMounts` (config.yaml path not mounted) AND `secretRef` (secrets not injected) | Add `volumes`, `volumeMounts`, and `envFrom.secretRef` blocks matching the pattern in `catalog/base/worker-deployment.yaml` |
| **[NEW-07]** | `SyncProductAvailabilityBatch` hardcodes `"USD"` currency for all price fetches | Accept `currency string` param; propagate to `pricingClient.GetPrice`; default to config's base currency if empty |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Action |
|----|-------------|--------|
| **[NEW-08]** | `StockSyncJob` cron fires every minute calling a no-op `SyncStockCache` — wasted CPU/connection overhead | Remove the job from `ProviderSet` and `workers.go`, or conditionally skip if `SyncStockCache` disabled |
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
| Correct event publish order | Outbox worker: Dapr publish → mark COMPLETED → side-effects (no re-deliver risk) |
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

---

## Related Files

| Document | Path |
|----------|------|
| Previous detailed review (Sprint 1–3) | [catalog-search-flow-business-logic-review.md](../lastphase/catalog-search-flow-business-logic-review.md) |
| Active catalog issues | [catalog_issues.md](../active/catalog_issues.md) |
| Search issues | [search-catalog-product-discovery-flow-issues.md](../active/search-catalog-product-discovery-flow-issues.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

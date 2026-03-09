# Catalog & Product Flow — Business Logic Review Checklist

**Date**: 2026-03-07 (v4 — deep re-audit against current codebase)
**Reviewer**: AI Review (code scan — Shopify/Shopee/Lazada patterns)
**Scope**: `catalog/`, `search/`, `pricing/`, `warehouse/`, `review/` — product lifecycle, events, workers, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §2 (Catalog & Product Flows)

> **Change log**: v3 issues verified against current code. Fixed issues marked `✅ FIXED`. New v4 findings use `[V4-*]` tags.

---

## 1. Data Consistency Between Services

| Check | Service A | Service B | Status | Risk |
|-------|-----------|-----------|--------|------|
| Product Create/Update → ES indexing | Catalog (Outbox) | Search (product_consumer) | ✅ Reliable | Outbox at-least-once; Search idempotency deduplicates |
| Product soft-delete → ES remove | Catalog (Outbox, unscoped fetch) | Search (product_consumer) | ✅ Fixed | `FindByIDUnscoped` used correctly |
| Price change → Catalog cache invalidated | Pricing (`pricing.price.updated`) | Catalog (price_consumer) | ✅ | `priceScope` required field enforced (line 80–83) |
| Price change → Search ES updated | Pricing | Search (price_consumer) | ✅ | Staleness check in `event_guard.go` |
| Stock change → Catalog cache updated | Warehouse (`warehouse.stock.changed`) | Catalog (stock_consumer) | ✅ | Sequence-number stale event drop + atomic SET (not DEL) |
| Stock change → Search ES updated | Warehouse | Search (stock_consumer) | ✅ | Consumer registered; staleness guard present |
| Promo created/updated/deleted → Search | Promotion | Search (promotion_consumer) | ✅ | All three event types handled |
| Category attribute change → ES re-index | Catalog (attribute outbox) | Search (attributeConfigChangedConsumer) | ✅ | Batched 100/iteration with 5 ms yield |
| Brand/Category deletion → dangling product ref | Admin | Catalog (brand/category biz) | ✅ | `DeleteBrand`/`DeleteCategory` block if products > 0 |
| `catalog.product.created` → Warehouse inventory init | Catalog | Warehouse (`product_created_consumer`) | ⚠️ | Consumer exists with idempotency, but DLQ failure = silent missing inventory |
| Review rating updated → Search rating fields | Review (outbox `rating.updated`) | Search | ❌ **[V4-01]** | Search has NO `rating.updated` consumer — rating/review_count in ES never updates |

### Data Mismatch Risks

- [x] **Brand/Category orphan**: `DeleteBrand` and `DeleteCategory` block deletion if products exist.
- [x] **Dual stock write eliminated**: `SyncStockCache` is a no-op; `stock_consumer` is sole cache writer.
- [x] **`DeleteProduct` TOCTOU**: `FindByID` inside `InTx` alongside `DeleteByID`.
- [x] **`SyncProductAvailabilityBatch` currency**: Now accepts `currency string` parameter.
- [ ] **[V4-01] ⚠️ Search has no `rating.updated` event consumer** — Review service publishes `rating.updated` via outbox, but Search has no consumer for it. Product rating fields in ES are never dynamically updated.

---

## 2. Event Publishing — Does Each Service Actually Need to Publish?

| Service | Published Events | Needed By | Verdict |
|---------|-----------------|-----------|---------|
| **Catalog** | `catalog.product.created/updated/deleted` | Search (ES index), Warehouse (inventory init) | ✅ Required |
| **Catalog** | `catalog.attribute.created/updated` | Search (ES mapping update) | ✅ Required |
| **Pricing** | `pricing.price.updated`, `pricing.price.bulk.updated` | Catalog (cache), Search (ES) | ✅ Required |
| **Promotion** | `promotion.created/updated/deleted` | Search (promo price index), Pricing (discount) | ✅ Required |
| **Warehouse** | `warehouse.stock.changed` | Catalog (stock cache), Search (in-stock flag) | ✅ Required |
| **Search** | (no outbound events) | — | ✅ Read-only — correct |
| **Review** | `review.created/updated/approved/rejected`, `rating.updated` | Search (rating), Notification | ✅ Required (via outbox) |
| **Catalog** (direct publish) | Removed in P0-002 | — | ✅ Fixed — outbox is sole publisher |

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
| **Search** | `pricing.price.updated/deleted` | Update price fields in ES docs | ✅ Needed |
| **Search** | `warehouse.stock.changed` | Update in-stock/stock-count in ES docs | ✅ Needed |
| **Search** | `promotion.created/updated/deleted` | Update promo flags in ES docs | ✅ Needed |
| **Search** | `cms.page.created/updated/deleted` | Index CMS pages for content search | ✅ Needed |
| **Search** | `rating.updated` | Update product rating in ES | ❌ **[V4-01] MISSING** |
| **Warehouse** | `catalog.product.created` | Initialize inventory entry | ✅ Needed |
| **Warehouse** | `order.status.changed` (paid) | Confirm reservation → deduct stock | ✅ Needed |
| **Warehouse** | `fulfillment.status.changed` | Release/adjust stock on shipment | ✅ Needed |
| **Review** | `shipping.shipment.delivered` | Mark order eligible for review | ✅ Needed (Dapr declarative subscription) |

---

## 4. Outbox Pattern & Retry/Rollback (Saga) Implementation

### 4.1 Catalog Outbox Worker

| Check | Status |
|-------|--------|
| Event type switch matches `catalog.product.*` + `catalog.attribute.*` | ✅ Correct |
| Outbox publishes to Dapr first → marks COMPLETED → side-effects | ✅ Correct order |
| Outbox created inside transaction atomically | ✅ Transactional (`InTx`) |
| Max retry limit enforced (`MaxRetries = 5`) | ✅ Implemented |
| `FetchAndMarkProcessing` uses `SELECT FOR UPDATE SKIP LOCKED` | ✅ Verified |
| `ResetStuckProcessing` clears events stuck > 5 min | ✅ Present |
| Prometheus metrics on outbox | ✅ `catalog_outbox_events_processed/failed_total` |
| Outbox backlog alert at > 1000 pending | ✅ Logged as CRITICAL |
| DLQ for permanently FAILED outbox events | ⚠️ Metric exists; no automated replay — manual only |

### 4.2 Review Outbox Worker

| Check | Status |
|-------|--------|
| Outbox worker processes `review.created/updated/approved/rejected`, `rating.updated` | ✅ All 5 event types handled |
| `ResetStuckProcessing` present | ✅ Clears stuck > 5 min |
| `FetchAndMarkProcessing` batch (20) | ✅ Same pattern as catalog |
| **[V4-02] No retry count / MaxRetries enforcement** | ❌ Failed events marked `failed` immediately without retry limit tracking |
| Worker polling interval | ✅ 5 seconds |

### 4.3 Search Retry / DLQ

| Check | Status |
|-------|--------|
| DLQ configured per consumer | ✅ All consumers use `deadLetterTopic` |
| DLQ reprocessor worker running | ✅ Present (`dlq_reprocessor_worker.go`) |
| Idempotency check consistent | ✅ Fixed (P1-001) |

### 4.4 Saga Pattern Assessment

The Catalog → Search flow is **Eventually Consistent Read Model** (not a financial Saga).

- [x] Write-through outbox guarantees at-least-once delivery from Catalog.
- [x] Idempotency on Search ensures at-most-once processing per event ID.
- [x] Review outbox now implemented (was missing in v3 — ✅ FIXED).
- [ ] **[OPEN]** No automated repair for permanently FAILED outbox events (P2 roadmap).

---

## 5. Edge Cases Not Yet Handled

### 5.1 Product Lifecycle

- [ ] **SKU rename / correction not supported** — `mergeUpdateModel` skips SKU. Warehouse inventory entries remain tied to old SKU.
- [ ] **Draft → Active with no approval queue** — Products jump `draft` → `active` directly; missing `pending_review` intermediate state.
- [x] **Product with active orders being deleted** — `OrderChecker` interface added; `DeleteProduct` blocks. ✅ Fixed
- [ ] **Variant/SKU matrix not implemented** — 1 product = 1 SKU. No parent/child variant grouping.
- [ ] **Bulk product creation race on name uniqueness** — Only SKU has unique constraint; duplicate names pass.

### 5.2 Catalog → Search Sync

- [ ] **Partial ES failure during bulk attribute re-index** — No cursor/checkpoint; failures restart from batch 1.
- [ ] **ES alias conflict during full re-index** — Real-time consumers and `cmd/sync` fight over same alias.
- [ ] **Search vs. Postgres count divergence** — No automated daily reconciliation job.

### 5.3 Price × Promotion Consistency

- [ ] **Flash sale start race with price update** — Non-deterministic write order to `promo_price` ES field.
- [ ] **Price change does not trigger promo recalculation** — `pricing.price.updated` updates base price but promo price = old base × discount%.

### 5.4 Review & Rating

- [ ] **No purchase verification fallback when Order service unavailable** — Outage blocks all review submissions.
- [ ] **Rating aggregation lag under spike** — `RatingAggregationWorker` runs every 10 min.
- [ ] **Review incentive (bonus points) requires loyalty service call** — Review has no loyalty client; photo-review bonus flow undefined.
- [ ] **[V4-01] `rating.updated` events are published but Search never consumes them** — Product rating in ES remains static.

### 5.5 Cross-Service

- [ ] **`catalog.product.created` → Warehouse inventory init failure is silent** — If DLQ'd, product has no inventory row. Order fails later.
- [ ] **[V4-03] Review Dapr subscription scoped only to `review` (main pod)** — `dapr-subscription.yaml` scopes to `review` but `shipping.shipment.delivered` needs processing by the API pod or needs separate worker subscription.

---

## 6. GitOps Configuration Review

### 6.1 Catalog Service

| Check | Status |
|-------|--------|
| Kustomize `common-deployment-v2` + `common-worker-deployment-v2` components | ✅ |
| Worker uses `patch-worker.yaml` for envFrom + resources | ✅ |
| Worker startup: `/app/bin/worker -conf /app/configs/config.yaml` | ✅ |
| Service ports: HTTP=8015, gRPC=9015 | ✅ |
| Instance label separates API vs worker pods | ✅ `catalog-main` |
| Sync-wave ordering: API=3, Worker=4 | ✅ Correct |
| Worker Dapr app-id auto-propagated from deployment name | ✅ |
| ServiceAccount shared between API + Worker | ✅ |

### 6.2 Review Service

| Check | Status |
|-------|--------|
| Kustomize `common-deployment-v2` + `common-worker-deployment-v2` components | ✅ |
| Worker deployment + PDB present | ✅ `worker-pdb.yaml` |
| Dapr subscription for `shipping.shipment.delivered` | ✅ `dapr-subscription.yaml` present |
| Worker startup: `/app/bin/worker -conf /app/configs/config.yaml` | ✅ |
| Service ports: HTTP=8016, gRPC=9016 | ✅ |
| Sync-wave ordering: API=2, Worker=3 | ✅ |
| **[V4-03] Dapr subscription scoped to `review` not `review-worker`** | ⚠️ Subscription targets API pod; if event handler is wired to API that's OK, but if workers need it, scope is wrong |

### 6.3 Search Service

| Check | Status |
|-------|--------|
| Worker Dapr `grpc`, port 5005 | ✅ |
| Worker has `volumeMounts` for config.yaml | ✅ |
| DLQ reprocessor + reconciliation workers deployed | ✅ |

### 6.4 Pricing Worker

| Check | Status |
|-------|--------|
| **[NEW-06] Worker Dapr protocol mismatch** — `http/8081` should be `grpc/5005` | ❌ Still present — needs fix |
| **[NEW-06] Missing `volumeMounts` for config.yaml** | ❌ Still present |

---

## 7. Worker & Cron Jobs Audit

### 7.1 Catalog Worker (`/app/bin/worker`)

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `product-outbox-worker` | Continuous | Poll 100ms | ✅ Proper `BaseContinuousWorker` select loop |
| `materialized-view-refresh-worker` | Cron | 5 min | ✅ Running |
| `outbox-cleanup-job` | Cron | Scheduled | ✅ Running |
| `eventbus-server` | Infrastructure | On-start gRPC | ✅ |
| `stock-changed-consumer` | Event | Real-time (Dapr) | ✅ |
| `stock-changed-dlq-consumer` | DLQ | Real-time | ✅ |
| `price-updated-consumer` | Event | Real-time | ✅ |
| `price-bulk-updated-consumer` | Event | Real-time | ✅ |
| `price-updated-dlq-consumer` | DLQ | Real-time | ✅ Registered |
| `price-bulk-updated-dlq-consumer` | DLQ | Real-time | ✅ Registered |

> **[V4-04]** `StockSyncJob` previously listed in v3 is **no longer in ProviderSet** — confirmed removed from `workers.go` Wire set. `SyncStockCache` is still a no-op but the cron job file (`stock_sync.go`) remains as dead code. Low priority cleanup.

### 7.2 Review Worker (`/app/bin/worker`)

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `review-outbox-worker` | Continuous | Poll 5s | ✅ Running (NEW in v4) |
| `review-moderation` | Internal cron | Configurable | ✅ |
| `rating-aggregation` | Internal cron | ~10 min | ⚠️ High lag under spike |
| `review-analytics` | Internal cron | Configurable | ✅ |

### 7.3 Search Worker

| Worker | Type | Status |
|--------|------|--------|
| `eventbus-server` | Infrastructure | ✅ |
| `product-created/updated/deleted-consumer` | Event | ✅ |
| `attribute-config-changed-consumer` | Event | ✅ |
| `price-updated/deleted-consumer` | Event | ✅ |
| `stock-changed-consumer` | Event | ✅ |
| `cms-page-*-consumer` | Event | ✅ |
| `promotion-*-consumer` | Event | ✅ |
| `trending-worker` | Cron | ✅ |
| `popular-worker` | Cron | ✅ |
| `dlq-reprocessor` | Cron | ✅ |
| `reconciliation-worker` | Cron | ✅ |
| `orphan-cleanup-worker` | Cron | ✅ |

---

## 8. Summary: Issue Priority Matrix

### 🚩 PENDING ISSUES (Unfixed)

| ID | Description | Priority | Action |
|----|-------------|----------|--------|
| **[V4-01]** | Search has NO `rating.updated` consumer — product rating/review_count in ES never dynamically updates from Review service events | 🟡 P1 | Create `ReviewConsumer` in `search/internal/data/eventbus/` subscribing to `rating.updated`; update ES `product` doc with `average_rating` and `total_reviews` |
| **[V4-02]** | Review outbox worker marks events `failed` immediately without retry count tracking — no `MaxRetries` enforcement like Catalog | 🟡 P1 | Add `RetryCount` field to review outbox model; increment on failure; only mark `failed` when `RetryCount >= MaxRetries` |
| **[NEW-06]** | `pricing/base/worker-deployment.yaml` Dapr protocol `http/8081` should be `grpc/5005` + missing `volumeMounts` | 🟡 P1 | Fix Dapr annotations; add `volumes` + `volumeMounts` |
| **[V4-03]** | Review Dapr subscription for `shipping.shipment.delivered` scoped to `review` — verify routing to correct pod | 🔵 P2 | Verify if event handler is wired in API server or worker; adjust scope accordingly |
| **[V4-04]** | `stock_sync.go` is dead code (not in ProviderSet); cleanup recommended | 🔵 P2 | Delete `stock_sync.go` or add TODO marker |
| **EDGE-02** | Draft → Active with no approval queue | 🔵 P2 | Add 3-state moderation lifecycle (roadmap) |
| **EDGE-04** | Bulk attribute reindex has no cursor/checkpoint | 🔵 P2 | Store batch cursor; reprocessing resumes from last committed batch |
| **EDGE-05** | ES real-time consumers conflict with alias during full reindex | 🔵 P2 | Alias-aware write routing |
| **EDGE-06** | `catalog.product.created` → Warehouse inventory init failure is silent | 🔵 P2 | DLQ alerting + Warehouse reconciliation job |
| **EDGE-07** | Review: photo-review bonus points reward flow undefined | 🔵 P2 | Define service contract between Review and Loyalty-Rewards |
| **OUTBOX-DLQ** | No automated replay for FAILED outbox rows in Catalog | 🔵 P2 | Admin re-enqueue endpoint or scheduled retry |

### 🆕 NEWLY DISCOVERED ISSUES (v4)

| ID | Category | Description | Fix |
|----|----------|-------------|-----|
| **[V4-01]** | Event Gap | Search has no consumer for `rating.updated` from Review | Add `review_consumer.go` in search eventbus |
| **[V4-02]** | Retry Logic | Review outbox worker has no retry count — events fail permanently on first attempt | Add retry count tracking with MaxRetries=5 |
| **[V4-03]** | GitOps | Review dapr-subscription scope may not match event handler location | Verify and adjust scope |
| **[V4-04]** | Dead Code | `catalog/internal/worker/cron/stock_sync.go` no longer wired | Delete file |

### ✅ RESOLVED / FIXED (since v3)

| ID | Description | Evidence |
|----|-------------|----------|
| **[NEW-03]** | ✅ Catalog worker volumeMounts — resolved by Kustomize `common-worker-deployment-v2` component which auto-includes config volume | `kustomization.yaml` line 16 |
| **[NEW-04]** | ✅ `ConsumePriceUpdatedDLQ` and `ConsumePriceBulkUpdatedDLQ` now registered as workers | `workers.go` lines 83–93 |
| **[NEW-05]** | ✅ No `time.Sleep` in price consumer handlers | Verified in `price_consumer.go` |
| **[NEW-08]** | ✅ `StockSyncJob` removed from `ProviderSet` (dead code file remains) | `workers.go` ProviderSet |
| **[V3-01]** | ✅ Worker health probes use `:8081` — `common/worker.NewWorkerApp` auto-starts HealthServer on that port | `common/worker/app.go` |
| **[V3-02]** | ✅ Same as V3-01 for all workers | All use `NewWorkerApp` |
| **[V3-03]** | ✅ Review workers now use standard `ContinuousWorker` pattern | `review/internal/worker/` |
| **[V3-04]** | ✅ Review rating/moderation workers now have proper batch loops | `rating_worker.go`, `moderation_worker.go` |
| **[V3-05]** | ✅ Catalog outbox worker uses proper `BaseContinuousWorker` select loop | `outbox_worker.go:57–78` |
| **Archived Issue 3** | ✅ Review outbox pattern now implemented | `review/internal/worker/outbox_worker.go` |
| **Archived Issue 4** | ✅ Review workers wired via `ProviderSet` + `NewWorkerRegistry` | `review/internal/worker/worker.go` |
| **Archived Issue 5** | ✅ Review Dapr subscription present in GitOps | `gitops/apps/review/base/dapr-subscription.yaml` |
| **Archived Issue 6** | ✅ Review worker deployment present in GitOps | `gitops/apps/review/base/patch-worker.yaml` + `common-worker-deployment-v2` |

---

## 9. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Outbox transactional publish | `product_write.go`: Create/Update/Delete create outbox inside `InTx` |
| Correct event publish order | Outbox worker: Dapr publish → mark COMPLETED → side-effects |
| Outbox dual-publish eliminated (P0-002) | `ProcessProduct*` contains only cache invalidation + view refresh |
| Unscoped fetch on delete (P0-003) | `ProcessProductDeleted` uses `FindByIDUnscoped` |
| TOCTOU product delete fix | `FindByID` inside `InTx` alongside `DeleteByID` |
| DLQ on all event consumers | All consumers configure `deadLetterTopic`; DLQ consumers registered |
| Search idempotency uniform | All consumers check + mark processed events consistently |
| Stuck outbox recovery | `ResetStuckProcessing` runs before each batch (5-min threshold) |
| `FOR UPDATE SKIP LOCKED` on outbox | `FetchAndMarkProcessing` prevents concurrent processing |
| Prometheus metrics on outbox | `catalog_outbox_events_processed/failed_total` + backlog gauge |
| Staleness guards for events | `event_guard.go`, sequence-number stale event drop on stock consumer |
| `stripExpiredPromotions` at query time | `search/enrich.go` — protects against DLQ'd `promotion.deleted` |
| Brand/Category deletion guarded | Block deletion if products exist |
| Review outbox pattern | `review/internal/worker/outbox_worker.go` — 5 event types via outbox |
| Review GitOps complete | Worker deployment + Dapr subscription + PDB |
| Optimistic locking on product update | Version check with `WHERE version = ?` clause |
| SKU distributed lock on create | Idempotency service lock prevents concurrent SKU creation |
| `priceScope` required field enforced | Error returned if scope missing in price event |
| Kustomize component reuse | All services use `common-deployment-v2` + `common-worker-deployment-v2` |

---

## Related Files

| Document | Path |
|----------|------|
| Previous v3 review | [archive/catalog-product-flows-checklist.md](archive/catalog-product-flows-checklist.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |
| Customer Identity review | [customer-identity-review.md](customer-identity-review.md) |

# Catalog & Product Flow — Business Logic Review Checklist

**Date**: 2026-02-21 (updated: 2026-02-21 — fixes applied)
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `catalog/`, `search/`, `pricing/`, `warehouse/` — product lifecycle, events, GitOps

> This checklist is the **current-state audit** following previous sprints (see [catalog-search-flow-business-logic-review.md](../lastphase/catalog-search-flow-business-logic-review.md) for fixed items from Sprint 1–3).
> Focus: remaining gaps, newly found issues, and operational completeness.

---

## 1. Data Consistency Between Services

| Check | Service A | Service B | Status | Risk |
|-------|-----------|-----------|--------|------|
| Product Create/Update → ES indexing | Catalog (Outbox) | Search (product_consumer) | ✅ Reliable | Outbox relays, Search consumers index |
| Product soft-delete → ES remove | Catalog (Outbox payload includes SKU) | Search (product_consumer) | ✅ | P0-003 fixed: unscoped fetch used |
| Price change → Catalog cache invalidated | Pricing (publishes `pricing.price.updated`) | Catalog (price_consumer) | ✅ | `priceScope` required field enforced |
| Price change → Search ES updated | Pricing | Search (price_consumer) | ✅ | event_guard staleness check in place |
| Stock change → Catalog cache updated | Warehouse (`warehouse.stock.changed`) | Catalog (stock_consumer) | ✅ | `SyncStockCache` disabled (lazy cache only); cron is no-op; real-time consumer is sole writer |
| Stock change → Search ES updated | Warehouse | Search (stock_consumer) | ✅ | Consumers registered |
| Promo created/updated/deleted → Search | Promotion | Search (promotion_consumer) | ✅ | promotionCreated/Updated/Deleted workers registered |
| Category attribute change → ES re-index | Catalog (attribute outbox) | Search (attributeConfigChangedConsumer) | ✅ | Batched 100 per iteration with yield |
| Category/Brand deletion → product dangling ref | Admin deletes brand | Catalog (brand/category biz) | ❌ **OPEN** | CAT-P2-02: `DeleteBrand` / `DeleteCategory` do NOT check existing product associations |

### Data Mismatch Risks

- [x] **[FIXED] Brand/Category orphan after delete**: `DeleteBrand` and `DeleteCategory` already have product-count guard — verified in code (brand.go:344–355, category.go:483–495). Correct; no change needed.
- [x] **[FIXED] Dual stock update**: `SyncStockCache` is disabled (returns immediately with a log line). Cron job is a no-op. `stock_consumer` is the sole writer. No race condition.
- [x] **[FIXED] `DeleteProduct` TOCTOU**: Moved `FindByID` inside `InTx` alongside `DeleteByID` — both now execute atomically. (`product_write.go` — 2026-02-21)

---

## 2. Event Publishing — Does Each Service Actually Need to Publish?

| Service | Published Events | Needed By | Verdict |
|---------|-----------------|-----------|---------|
| **Catalog** | `catalog.product.created/updated/deleted` | Search (ES index), Warehouse (inventory init) | ✅ Required |
| **Catalog** | `catalog.attribute.created/updated` | Search (ES mapping update) | ✅ Required |
| **Pricing** | `pricing.price.updated`, `pricing.price.deleted`, `pricing.price.bulk.updated` | Catalog (cache), Search (ES) | ✅ Required |
| **Promotion** | `promotion.created/updated/deleted` | Search (promo price index), Pricing (discount calc) | ✅ Required |
| **Warehouse** | `warehouse.stock.changed` | Catalog (stock cache), Search (in-stock flag) | ✅ Required |
| **Search** | (no outbound events) | — | ✅ Correct — Search is read-only service |
| **Review** | (no outbound events) | — | ✅ Correct |
| **Catalog** (direct `PublishCustom`) | Removed in P0-002 fix | — | ✅ Fixed — outbox is sole publisher now |

---

## 3. Event Subscription — Does Each Service Actually Need to Subscribe?

| Service | Consumed Events | Reason | Verdict |
|---------|----------------|--------|---------|
| **Catalog** | `warehouse.stock.changed` | Update stock cache per product | ✅ Needed |
| **Catalog** | `pricing.price.updated`, `pricing.price.bulk.updated` | Update price cache (PDP enrichment) | ✅ Needed |
| **Pricing** | `warehouse.stock.changed` | Stock-level based price rules (flash sale quantity) | ✅ Needed |
| **Pricing** | `promotion.created/updated/deleted` | Discount stacking eligibility recalc | ✅ Needed |
| **Search** | `catalog.product.created/updated/deleted` | Build/update ES document | ✅ Needed |
| **Search** | `catalog.attribute.config_changed` | Rebuild ES mapping + re-index | ✅ Needed |
| **Search** | `pricing.price.updated`, `pricing.price.deleted` | Update price fields in ES docs | ✅ Needed |
| **Search** | `warehouse.stock.changed` | Update in-stock/stock-count in ES docs | ✅ Needed |
| **Search** | `promotion.created/updated/deleted` | Update promo flags in ES docs | ✅ Needed |
| **Search** | `cms.page.created/updated/deleted` | Index CMS pages for content search | ✅ Needed |
| **Warehouse** | `catalog.product.created` | Initialize inventory entry on new product | ✅ Needed |
| **Warehouse** | `order.status.changed` (paid) | Confirm reservation → deduct stock | ✅ Needed |
| **Warehouse** | `fulfillment.status.changed` | Release/adjust stock on shipment | ✅ Needed |

---

## 4. Outbox Pattern & Retry/Rollback (Saga) Implementation

### 4.1 Catalog Outbox Worker

| Check | File | Status |
|-------|------|--------|
| Event type switch matches `catalog.product.*` prefix | `catalog/internal/worker/outbox_worker.go:177` | ✅ Fixed (P0-001) |
| Outbox worker publishes to Dapr first, then calls internal side-effects | `outbox_worker.go:192–208` | ✅ Correct order |
| `ProcessProduct*` no longer calls `eventHelper.PublishCustom` | `product_write.go:628–761` | ✅ Fixed (P0-002) |
| Outbox created inside transaction atomically | `product_write.go:111–121, 213–223, 286–293` | ✅ Transactional |
| Max retry limit enforced (5 retries → FAILED) | `outbox_worker.go:269–277` | ✅ Implemented |
| **`FetchAndMarkProcessing` uses `SELECT FOR UPDATE SKIP LOCKED`** | `catalog/internal/data/postgres/outbox.go:44` | ✅ **VERIFIED** — `clause.Locking{Strength: "UPDATE", Options: "SKIP LOCKED"}` present; worker uses `FetchAndMarkProcessing` |
| DLQ for FAILED outbox events (monitoring/alerting) | Prometheus `catalog_outbox_events_failed_total` | ⚠️ Metric exists, but no consumer replays FAILED outbox rows |

### 4.2 Search Retry / DLQ

| Check | File | Status |
|-------|------|--------|
| DLQ configured per consumer (deadLetterTopic) | All search consumers | ✅ Configured |
| DLQ reprocessor worker running | `search/internal/worker/dlq_reprocessor_worker.go` | ✅ Present |
| Promotion DLQ topics registered | DLQ reprocessor + promotion consumer | ✅ Fixed (P1-006) |
| Idempotency check consistent across all consumers | `search/internal/data/eventbus/*_consumer.go` | ✅ Fixed (P1-001) |

### 4.3 Saga Pattern Assessment

The Catalog → Search flow is **Eventually Consistent Read Model** (not a financial Saga). Compensating transactions are not applicable. Key principles verified:

- [x] Write-through outbox guarantees at-least-once delivery from Catalog
- [x] Idempotency on Search ensures at-most-once processing per event ID
- [ ] **[OPEN]** No automated repair for permanently FAILED outbox events (stuck in FAILED state, admin must manually re-enqueue) — P2 roadmap

---

## 5. Retry & Rollback Edge Cases

### Critical Open Issues (`❌`)

| ID | Description | File & Line | Priority |
|----|-------------|-------------|----------|
| **P0-006** | ~~`FetchPending` NO SKIP LOCKED~~ — **RESOLVED**: `FetchAndMarkProcessing` uses `clause.Locking{Strength:"UPDATE", Options:"SKIP LOCKED"}`. Worker upgraded to `FetchAndMarkProcessing`. | `catalog/internal/data/postgres/outbox.go:44` | ✅ Already fixed |
| **CAT-P2-02** | ~~`DeleteBrand`/`DeleteCategory` no product check~~ — **RESOLVED**: Both already had product-count guards before deletion. | `brand.go:344`, `category.go:483` | ✅ Already implemented |
| **CAT-P1-03** | `GetStockFromCache` returns explicit error (not `0`) when warehouse client fails. `GetProductAvailability` surfaces this error to caller. | `product_price_stock.go:62–75` | ✅ Already correct |

### Medium / Operational Risks (`⚠️`)

| ID | Description | File | Impact |
|----|-------------|------|--------|
| **NEW-01** | ~~`DeleteProduct` TOCTOU~~ — **FIXED**: `FindByID` moved inside `InTx` alongside `DeleteByID`. Atomic read-then-delete. | `product_write.go` (2026-02-21) | ✅ Fixed |
| **NEW-02** | ~~`StockSyncJob` overwrite~~  — **RESOLVED**: `SyncStockCache` disabled (`returns nil` immediately). Cron is no-op. Real-time `stock_consumer` is sole cache writer. | `stock_sync.go:97`, `product_price_stock.go:234` | ✅ Already resolved |
| **NEW-03** | ~~`worker-deployment.yaml` missing `volumeMounts`~~ — **FIXED**: Added `volumeMounts: [{name: config, mountPath: /app/configs}]` to container spec. | `gitops/apps/catalog/base/worker-deployment.yaml` (2026-02-21) | ✅ Fixed |
| **NEW-04** | `RefreshAllViewsAsync` triggered after every product event — unbounded goroutine spawn during bulk import. Debounce layer helps but trigger frequency remains unthrottled. | `product_write.go:671,716,757` | ⚠️ P2 — roadmap |

---

## 6. Edge Cases Not Yet Handled

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    UNHANDLED EDGE CASES — CATALOG & PRODUCT FLOW               │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 6.1 Product Lifecycle Edge Cases

- [ ] **SKU rename via product update is blocked** — `mergeUpdateModel` skips SKU. But if admin needs to fix a typo in SKU, there is no supported migration path (SKU is immutable after create). This creates orphaned warehouse inventory entries that still reference the old SKU.
  - *Shopify pattern*: SKU change creates a new variant with a deprecation tag on old.
- [ ] **Draft → Published status transition without approval queue** — Products can jump from `draft` directly to `active` via a single API call with no moderation review step. Missing: `pending_review` status + approval endpoint.
  - *Shopee pattern*: `draft` → `pending_review` → `active` mandatory 3-state lifecycle for seller products.
- [ ] **Product with active orders being deleted** — `DeleteProduct` soft-deletes without checking if the product has open orders (PENDING_PAYMENT, PROCESSING). Warehouses may still try to fulfill a soft-deleted product.
  - **Fix**: Check `order_items` table (via Order service gRPC) before soft-delete; block if active.
- [ ] **Variant/SKU matrix generation** — Not implemented. Current model has one product = one SKU. Multi-variant products (Size × Color) have no grouping mechanism. Elasticsearch indexing does not support variant faceting.
  - *Shopee/Lazada pattern*: Parent product + child SKUs with variant matrix table.
- [ ] **Bulk product creation race condition** — If two admin requests concurrently try to create a product with the same **name but different SKUs**, both succeed. No deduplication on name (only SKU is unique-constrained).

### 6.2 Catalog → Search Sync Edge Cases

- [ ] **Partial ES failure during bulk attribute re-index** — `ProcessAttributeConfigChanged` batches 100 products but if it fails at batch 7 of 20, batches 1–7 are re-indexed and 8–20 are not. On Dapr retry, all 20 batches re-run. Idempotency check on product re-index prevents double-write, but the cursor (batch 8) is lost — retry starts from batch 1 again.
  - **Fix**: Store a checkpoint (cursor position) for attribute reindex jobs.
- [ ] **ES alias switch during reindex** — The `cmd/sync` tool supports zero-downtime alias switch. But the real-time consumers write directly to the active index (no alias-aware routing). If a full reindex is in progress, consumers and the indexer fight over the same alias simultaneously.
  - **Fix**: Real-time consumers should write to the `active alias target` (resolved at write time), not the alias name.
- [ ] **Search index and Postgres count divergence monitoring** — No automated daily reconciliation job comparing Postgres `products` count (status=active) vs ES document count. Manual check only via `/api/v1/admin/sync/status`.
  - **Fix**: Add `reconciliation_worker.go` scheduled daily count check + Prometheus alert.

### 6.3 Price × Promotion Consistency Edge Cases

- [ ] **Flash sale starts while product is updating** — If a promo starts (`promotion.created`) at the same microsecond as a price update (`pricing.price.updated`), both events are consumed by Search. The order of writes to the ES `promo_price` field is non-deterministic. `event_guard.go` staleness checks help but do not fully serialize these.
- [ ] **Promotion deleted but promo price still cached** — If Search processes `promotion.created` and caches the promo price, then `promotion.deleted` is DLQ'd (failed), the promo price remains in the ES document indefinitely. No TTL on promo price field.
  - **Fix applied**: `stripExpiredPromotions()` added to `enrich.go` — filters promotions with `ends_at` in the past at query-response time. (2026-02-21)
- [x] **[FIXED] `promotion.deleted` DLQ stale promo price**: `enrichWarehouseData` now calls `stripExpiredPromotions` on every search response hit. Promotions with past `ends_at` are removed before returning to caller. (`search/internal/data/elasticsearch/enrich.go` — 2026-02-21)
- [ ] **Product price change does not trigger promo recalculation** — If base price drops from 200 to 150 and there is an active 10% promo, the promo price in ES is still 180 (10% of old 200). `pricing.price.updated` consumed by Search updates base price but does not recalculate active promos.
  - *Shopee pattern*: Price update event triggers promotion recalculation pipeline.

---

## 7. GitOps Configuration Review

### 7.1 Catalog Service

| Check | File | Status |
|-------|------|--------|
| Worker deployment has Dapr annotations | `gitops/apps/catalog/base/worker-deployment.yaml:24–27` | ✅ `dapr.io/app-id: catalog-worker`, port 5005 |
| Worker has secretRef | `worker-deployment.yaml:62–63` | ✅ `secretRef: catalog` |
| Worker has envFrom overlays-config | `worker-deployment.yaml:60–61` | ✅ |
| Worker has liveness + readiness probes | `worker-deployment.yaml:64–75` | ✅ gRPC probes on port 5005 |
| Worker has security context non-root | `worker-deployment.yaml:29–32` | ✅ `runAsUser: 65532` |
| **Worker has volumeMount for config.yaml** | `worker-deployment.yaml` | ✅ **FIXED** (2026-02-21) — `volumeMounts: [{name: config, mountPath: /app/configs, readOnly: true}]` added |
| Main service deployment exists | `gitops/apps/catalog/base/` | ❌ **OPEN** — only `worker-deployment.yaml` found; no `deployment.yaml` for catalog main service |

> **Risk**: If catalog main service binary reads `config.yaml` from file path, it cannot start.

### 7.2 Search Service

| Check | File | Status |
|-------|------|--------|
| Main deployment has Dapr (HTTP protocol, port 8017) | `gitops/apps/search/base/deployment.yaml:24–27` | ✅ |
| Main deployment has secretRef | `deployment.yaml:57` | ✅ `secretRef: search-secret` |
| Main deployment has liveness + readiness + startup probes | `deployment.yaml:65–91` | ✅ All present |
| Main deployment mounts config volumeMount | `deployment.yaml:80–83` | ✅ |
| Worker deployment has Dapr (gRPC, port 5005) | `worker-deployment.yaml:24–27` | ✅ |
| Worker has secretRef | `worker-deployment.yaml:62` | ✅ `secretRef: search-secret` |
| Worker mounts config volumeMount | `worker-deployment.yaml:70–73` | ✅ |
| Search service does NOT have readinessProbe | `deployment.yaml:85–91` | ✅ Has readinessProbe |

### 7.3 Pricing Worker

| Check | Status |
|-------|--------|
| Consumes: `warehouse.stock.changed` | ✅ `stockConsumer` registered |
| Consumes: `promotion.created/updated/deleted` | ✅ `promoConsumer` registered |
| Publishes: `pricing.price.updated`, `pricing.price.deleted`, `pricing.price.bulk.updated` | ✅ Publisher via outbox/direct Dapr |

### 7.4 Warehouse

| Check | Status |
|-------|--------|
| Consumes: `catalog.product.created` (init inventory) | ✅ `product_created_consumer` registered |
| Consumes: `order.status.changed` | ✅ `order_status_consumer` registered |
| Consumes: `fulfillment.status.changed` | ✅ `fulfillment_status_consumer` registered |
| Consumes: `return.created` | ✅ `return_consumer` registered |
| Publishes: `warehouse.stock.changed` | ✅ On every stock mutation |

---

## 8. Worker & Cron Jobs Audit

### 8.1 Catalog Worker (Binary: `/app/bin/worker`)

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `product-outbox-worker` | Continuous | Poll every 100ms | ✅ Running |
| `materialized-view-refresh-worker` | Cron | Every 5 minutes | ✅ Running |
| `stock-sync-worker` | Cron | Every 1 minute | ✅ Running |
| `stock-changed-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `price-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |
| `price-bulk-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ Running |

### 8.2 Search Worker (Binary: `/app/bin/worker`)

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `eventbus-server` | Infrastructure | On-start gRPC | ✅ |
| `product-created-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `product-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `product-deleted-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `attribute-config-changed-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `price-updated-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `price-deleted-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `stock-changed-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `cms-page-created/updated/deleted-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `promotion-created/updated/deleted-consumer` | Event consumer | Real-time (Dapr) | ✅ |
| `trending-worker` | Cron | Scheduled | ✅ |
| `popular-worker` | Cron | Scheduled | ✅ |
| `dlq-reprocessor` | Cron | Scheduled | ✅ |
| `reconciliation-worker` | Cron | Scheduled | ✅ |
| `orphan-cleanup-worker` | Cron | Scheduled | ✅ |

### 8.3 Pricing Worker

| Worker | Type | Status |
|--------|------|--------|
| `eventbus-server` | Infrastructure | ✅ |
| `stock-consumer` | Event consumer | ✅ |
| `promo-consumer` | Event consumer | ✅ |

---

## 9. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix Before Release

| Issue | Description | Action |
|-------|-------------|--------|
| **P0-006** | ~~Outbox `FetchPending` lacks SKIP LOCKED~~ — `FetchAndMarkProcessing` with `FOR UPDATE SKIP LOCKED` already in place | ✅ Already implemented |
| **GITOPS-CAT-01** | ~~Catalog `worker-deployment.yaml` missing `volumeMounts`~~ | ✅ Fixed 2026-02-21 |

### 🟡 P1 — Fix in Next Sprint

| Issue | Description | Action |
|-------|-------------|--------|
| **CAT-P1-03** | ~~Stock lookup return 0~~ — `GetStockFromCache` already returns explicit error (not 0) on warehouse failure. | ✅ Already correct |
| **NEW-01** | ~~`DeleteProduct` TOCTOU~~ — Moved `FindByID` inside `InTx`. | ✅ Fixed 2026-02-21 |
| **NEW-02** | ~~`StockSyncJob` overwrite~~ — `SyncStockCache` disabled; cron is no-op. | ✅ Already resolved |
| **EDGE-01** | Product with active orders can be deleted — no cross-service check | Call Order service before delete; block if open orders exist (P1 — roadmap) |

### 🔵 P2 — Roadmap / Tech Debt

| Issue | Description | Action |
|-------|-------------|--------|
| **CAT-P2-02** | ~~No product association check~~ — Both `DeleteBrand` and `DeleteCategory` already query product count and reject if > 0. | ✅ Already implemented |
| **NEW-03** | Bulk `RefreshAllViewsAsync` goroutine flood during bulk import | Rate-limit or debounce triggers from outbox worker (roadmap) |
| **EDGE-02** | Draft → Active with no approval queue — missing `pending_review` status | Add moderation lifecycle 3-state (roadmap) |
| **EDGE-03** | ~~Stale promo price if `promotion.deleted` DLQ'd~~ — `stripExpiredPromotions()` in `enrich.go` filters expired promos at query time | ✅ Fixed 2026-02-21 |
| **EDGE-04** | Bulk attribute reindex has no cursor/checkpoint — full retry from start | Store batch cursor; reprocessing resumes from last committed batch (roadmap) |
| **EDGE-05** | ES indexing during reindex conflicts with real-time consumers writing to same alias | Alias-aware routing for real-time consumers during reindex (roadmap) |

---

## 10. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Outbox pattern (transactional publish) | `product_write.go`: Create/Update/Delete all create outbox inside `InTx` |
| Outbox event type matching | `outbox_worker.go:177–210`: uses `constants.EventTypeCatalogProduct*` — correct |
| P0-002 fix: no dual publish | `ProcessProduct*` methods contain only cache invalidation + view refresh |
| P0-003 fix: unscoped fetch on delete | `ProcessProductDeleted` uses `FindByIDUnscoped` |
| P1-004 fix: validateRelations inside tx | Both `CreateProduct` and `UpdateProduct` validate category/brand/manufacturer inside `InTx` |
| P1-003 fix: FindByID inside tx | `UpdateProduct` fetches `updated` inside the same transaction |
| P2-001 fix: attribute template fail-closed | `validateAttributes` returns error on JSON parse failure |
| P2-002 fix: clearing optional fields | `mergeUpdateModel` uses pointer-of-pointer to distinguish null vs not-provided |
| P2-008 fix: status enum validation | `validateStatus` enforces `active/inactive/draft/archived` |
| DLQ configured on all Search consumers | All consumers configure `deadLetterTopic` in Dapr subscription |
| Search idempotency uniformly applied | All consumers check + mark processed events consistently |
| Prometheus metrics on outbox | `catalog_outbox_events_processed_total`, `catalog_outbox_events_failed_total` |
| Search health endpoint + ES health | `/health`, `/health/detailed`, `/api/v1/admin/sync/status` |
| Staleness guards for events | `event_guard.go`: `isStaleEvent`, `isStalePriceEvent`, `isStalePromotionEvent` |
| Bulk attribute reindex pagination | `ProcessAttributeConfigChanged`: batched 100/iteration with 5ms yield |
| Out-of-order event protection | Stale events skipped with `stale_event_skipped` metric |
| Search worker has DLQ/reconciliation/orphan-cleanup | All three specialized workers present in search worker |
| Price scope required field | `priceScope` is required; events without it are rejected (not inferred) |

---

## Related Files

| Document | Path |
|----------|------|
| Previous detailed review (Sprint 1–3) | [catalog-search-flow-business-logic-review.md](../lastphase/catalog-search-flow-business-logic-review.md) |
| Active open issues | [catalog_issues.md](../active/catalog_issues.md) |
| Search issues | [search-catalog-product-discovery-flow-issues.md](../active/search-catalog-product-discovery-flow-issues.md) |
| Customer/Identity flow checklist | [customer-identity-flow-checklist.md](customer-identity-flow-checklist.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

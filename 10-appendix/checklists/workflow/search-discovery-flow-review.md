# Search & Discovery Flows — Business Logic Review Checklist

**Date**: 2026-02-24 (v2 — full re-audit following Shopify/Shopee/Lazada patterns)
**Reviewer**: AI Review (deep code scan — search, catalog, pricing, warehouse, promotion)
**Scope**: `search/`, `catalog/` — product indexing, ES sync, event consumers, workers, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §3 (Search & Discovery)

> Previous sprint fixes are preserved as `✅ Fixed (Sprint N)`. New issues found in this audit use `[NEW-*]` tags.

---

## 📊 Summary (v2)

| Category | Sprint 1–3 | This Audit |
|----------|-----------|------------|
| 🔴 P0 — Critical | 7 found → 7 fixed | 1 new |
| 🟡 P1 — High | 8 found → 8 fixed | 2 new |
| 🔵 P2 — Medium | 9 found → 9 fixed | 3 new |

---

## 1. Data Consistency Between Services

| Data Pair | Consistency Level | Status |
|-----------|-----------------|--------|
| Catalog Postgres ↔ Elasticsearch | Eventually consistent (outbox → Dapr → Search) | ✅ Reliable |
| Product price ↔ ES price field | Eventually consistent (Pricing → Search via `pricing.price.updated`) | ✅ PriceScope enforced |
| Warehouse stock ↔ ES stock | Eventually consistent (Warehouse → Search via `stock_changed`) | ✅ DLQ handler present |
| Catalog stock cache ↔ Warehouse | Eventually consistent (SET, not DEL) | ✅ Fixed (P1-005) |
| Promotion discount ↔ ES promo badge | Eventually consistent (Promotion → Search) | ✅ `stripExpiredPromotions()` at query time |
| Soft-deleted product ↔ ES | Fixed (outbox includes SKU for unscoped fetch) | ✅ Fixed (P0-003) |
| Category deleted ↔ ES products | `catalog.category.deleted` → Search `UnsetCategoryFromProducts` | ✅ Implemented |

### Data Mismatch Risks

- [x] **[FIXED] Dual ES writer** — Catalog no longer writes to ES directly; Search is sole writer.
- [x] **[FIXED] PriceScope inference fragile** — Both consumers enforce `scope == "" → return error`.
- [x] **[FIXED] Outbox dual-publish race** — Outbox publishes first; ProcessProduct* only cache/view.
- [ ] **[NEW-01] ⚠️ ReconciliationWorker re-indexes products WITHOUT price, stock, or promotion data** — `reconciliation_worker.go:121–138` builds a `ProductIndex` with only catalog fields (name, SKU, category, brand, status). Price, stock, and promotion fields are all zero/nil. A product re-indexed by the reconciliation worker will appear in search results with `price: 0`, `in_stock: false`, no promotion badge until subsequent events arrive.
  - *Shopee/Lazada pattern*: Reconciliation must enrich from Pricing + Warehouse before indexing.
  - **Fix**: After `catalogClient.GetProduct`, fetch price via Pricing gRPC and stock via Warehouse gRPC before calling `productRepo.IndexProduct`.

---

## 2. Event Publishing — Does Each Service Need to Publish?

| Service | Published Events | Needed By | Verdict |
|---------|----------------|-----------|---------|
| **Catalog** | `catalog.product.created/updated/deleted` | Search (ES index), Warehouse (init inventory) | ✅ Required |
| **Catalog** | `catalog.attribute.config_changed` | Search (ES mapping update + bulk re-index) | ✅ Required |
| **Catalog** | `catalog.category.deleted` | Search (bulk unset category from ES products) | ✅ Required |
| **Catalog** | `catalog.cms.page.created/updated/deleted` | Search (CMS content index) | ✅ Required |
| **Pricing** | `pricing.price.updated`, `pricing.price.deleted`, `pricing.price.bulk.updated` | Catalog (cache), Search (ES price field) | ✅ Required |
| **Warehouse** | `warehouse.inventory.stock_changed` | Catalog (stock cache), Search (ES `in_stock`) | ✅ Required |
| **Promotion** | `promotion.created/updated/deleted` | Search (ES promo badge + discount boost) | ✅ Required |
| **Search** | (no outbound events published) | — | ✅ Correct — read-only service |

**No unnecessary publishers identified.**

---

## 3. Event Subscription — Does Each Service Need to Subscribe?

| Service | Consumed Events | Reason | Verdict |
|---------|----------------|--------|---------|
| **Search** | `catalog.product.created/updated/deleted` | Core ES indexing path | ✅ Essential |
| **Search** | `catalog.attribute.config_changed` | ES mapping update + bulk re-index trigger | ✅ Essential |
| **Search** | `catalog.category.deleted` | Bulk unset category from affected ES docs | ✅ Essential |
| **Search** | `catalog.cms.page.created/updated/deleted` | CMS content index | ✅ Essential |
| **Search** | `pricing.price.updated`, `pricing.price.deleted` | ES price/sale_price fields | ✅ Essential |
| **Search** | `warehouse.inventory.stock_changed` | ES `in_stock`/`stock_quantity` fields | ✅ Essential |
| **Search** | `promotion.created/updated/deleted` | ES promo badge, discount boost, expiry | ✅ Essential |
| **Catalog** | `warehouse.inventory.stock_changed` | Redis stock cache invalidation (lazy write) | ✅ Justified |
| **Catalog** | `pricing.price.updated`, `pricing.price.bulk.updated` | Redis price cache invalidation | ✅ Justified |

**No unnecessary subscriptions detected.**

---

## 4. Outbox Pattern & Retry/Rollback (Saga) Implementation

### 4.1 Catalog Outbox (publishes to Search via Dapr)

| Check | File | Status |
|-------|------|--------|
| Product events inside `InTx` alongside DB write | `product_write.go` | ✅ Atomic |
| `FetchAndMarkProcessing` uses `FOR UPDATE SKIP LOCKED` | `data/postgres/outbox.go:44` | ✅ Fixed (P0-006) |
| `ResetStuckProcessing` (recovery for stuck PROCESSING > 5 min) | `outbox_worker.go:100–105` | ✅ Present |
| Max retries (5) → FAILED state | `outbox_worker.go:152` | ✅ Correct |
| Publish first, then COMPLETED, then side-effects (no re-deliver risk) | `outbox_worker.go:194–222` | ✅ Correct order |
| Outbox cleanup job (delete COMPLETED > 7 days) | `cron/outbox_cleanup.go` | ✅ Hourly |

### 4.2 Search DLQ Reprocessor

| Check | File | Status |
|-------|------|--------|
| DLQ reprocessor processes pending events every 5 minutes | `dlq_reprocessor_worker.go:25` | ✅ Running |
| Max retries (5) → marks event as "ignored" | `dlq_reprocessor_worker.go:112–118` | ✅ Correct |
| Context cancel check inside loop | `dlq_reprocessor_worker.go:104–108` | ✅ Present |
| **Retry failure status not set to "failed"** | `dlq_reprocessor_worker.go:122–132` | ⚠️ See [NEW-02] |
| **"ignored" events never cleaned up from DB** | `dlq_reprocessor_worker.go` | ⚠️ See [NEW-P2-01] |

### 4.3 Saga Pattern Assessment

Catalog → Search is **Eventually Consistent Read Model** — not a financial Saga.
- [x] Write-through outbox guarantees at-least-once delivery.
- [x] Idempotency on Search ensures at-most-once processing per event ID.
- [x] DLQ consumers drain dead-lettered events with ERROR logging.
- [x] DLQ reprocessor retries up to 5× then marks "ignored".

---

## 5. Retry & Rollback Edge Cases

### Previously Fixed (confirmed in code)

| ID | Description | Status |
|----|-------------|--------|
| **P0-001** | Outbox event type mismatch | ✅ Fixed — uses `constants.EventTypeCatalogProduct*` |
| **P0-002** | Dual-Publish race | ✅ Fixed — outbox sole publisher |
| **P0-003** | Soft-deleted product ES deletion | ✅ Fixed — unscoped fetch |
| **P0-004** | PriceScope inference fragile | ✅ Fixed — both consumers enforce `scope == "" → error` |
| **P0-005** | Catalog AND Search writing to ES (dual writer) | ✅ Fixed — Search sole writer |
| **P0-006** | Outbox no SKIP LOCKED | ✅ Fixed |
| **P0-007** | Redis Lua KEYS pattern (Cluster illegal) | ✅ Fixed — SMEMBERS + MGET |
| **RISK-001** | Atomic PROCESSING mark in outbox | ✅ Fixed — `FetchAndMarkProcessing` |
| **NEW-P1-001** | Search worker missing liveness/readiness probes | ✅ Fixed |
| **NEW-P2-001** | `pipe.Del(productCacheKey)` stampede | ✅ Fixed |
| **NEW-P2-002** | Promotion consumer silent skip on invalid event | ✅ Fixed — required field validation returns error |
| **NEW-P2-003** | Search stock DLQ handler missing | ✅ Fixed — `ConsumeStockChangedDLQ` registered |
| **RISK-002** | Sync job missing secretRef | ✅ Fixed |
| **RISK-003** | Catalog worker HPA missing | ✅ Fixed — production overlay |

---

## 6. NEW Issues Found in This Audit

### 🔴 NEW-01: ReconciliationWorker Re-indexes Without Price / Stock / Promotion Data

**File**: `search/internal/worker/reconciliation_worker.go:121–138`

**Problem**: When a product is missing from Elasticsearch and gets re-indexed by the reconciliation worker, only catalog metadata fields are populated. Price, stock, and promotion fields are all empty/zero:

```go
productIndex := &biz.ProductIndex{
    ID:           fullProduct.ID,
    Name:         fullProduct.Name,
    // ...catalog fields only...
    // ← Price: 0.0 (zero value)
    // ← InStock: false (zero value)
    // ← Promotions: nil
}
```

A user searching for this product will see it with **price = 0**, **out of stock**, and **no promotions** until subsequent price/stock/promotion events overwrite the fields. In flash sales this is a critical UX / revenue defect.

- *Shopee/Lazada pattern*: Reconciliation enriches from all data owners before indexing.
- **Fix**: After `catalogClient.GetProduct`, call Pricing gRPC `GetPrice()` and Warehouse gRPC `GetTotalStock()` to populate `BasePrice`, `InStock`, `StockQuantity` before calling `productRepo.IndexProduct`.

---

### 🟡 NEW-02: DLQ Reprocessor Retry Failure Leaves Status Stuck as "pending"

**File**: `search/internal/worker/dlq_reprocessor_worker.go:120–133`

**Problem**: When `dlqService.RetryFailedEvent` fails (increments `failed++`) but the retry count has NOT yet reached `dlqMaxRetries (5)`, the event status remains `"pending"` — it is NOT updated to reflect repeated failure. The worker will keep picking up this event every 5 minutes, log a warning, and increment `failed`. Operators have no way to distinguish "pending → just arrived" from "pending → failed 3 times already" without inspecting `retry_count`.

```go
event.RetryCount++
w.failedEventRepo.Update(ctx, event)  // saves retry count
// On failure:
failed++                               // counter only, no status change
// Status stays "pending" → picked up again next tick
```

- *Shopify pattern*: After each failure, set status to `"retrying"` or add a `next_retry_at` backoff timestamp; set `status = "failed"` when exhausted.
- **Fix**: After a failed retry, update status to `"retrying"` (or add exponential `next_retry_at`). Reserve `"pending"` for new unprocessed events only.

---

### 🟡 NEW-03: OrphanCleanupWorker Treats gRPC Errors as "Product Missing" → Deletes Valid Products

**File**: `search/internal/worker/orphan_cleanup_worker.go:122–133`

**Problem**: The orphan cleanup worker calls `catalogClient.GetProduct(ctx, productID)` for every ES product ID. If the response is an error for **any reason** (catalog service unavailable, network timeout, context deadline exceeded), the code treats this as "product not found in catalog" and deletes it from Elasticsearch:

```go
_, getErr := w.catalogClient.GetProduct(ctx, productID)
if getErr != nil {
    // Product not found in catalog — it's an orphan
    totalOrphans++
    w.productRepo.DeleteProduct(ctx, productID)  // ← deletes on ANY error!
}
```

A transient catalog outage during a 6-hour cleanup run could delete **all valid products** from Elasticsearch.

- *Shopee/Lazada pattern*: Distinguish `NotFound` (gRPC `codes.NotFound`) from network/deadline errors; only delete on confirmed `NotFound`.
- **Fix**: Inspect the gRPC error code: `if status.Code(getErr) == codes.NotFound { delete }` else `{ log warning and skip }`.

---

### 🔵 NEW-P2-01: DLQ "ignored" Events Never Cleaned Up from DB

**File**: `search/internal/worker/dlq_reprocessor_worker.go:112–117`

**Problem**: When an event exceeds `dlqMaxRetries`, it is marked `"ignored"` in the `failed_events` table:
```go
w.failedEventRepo.UpdateStatus(ctx, event.ID, "ignored")
```
There is no cleanup job to delete old `"ignored"` records. Over time, the `failed_events` table accumulates all historically ignored events, degrading query performance for the `GetByStatus("pending")` query.

- **Fix**: Add a weekly cleanup cron (similar to `OutboxCleanupJob`) that deletes `failed_events WHERE status='ignored' AND updated_at < NOW() - interval '30 days'`.

---

### 🔵 NEW-P2-02: N+1 gRPC Calls in ReconciliationWorker and OrphanCleanupWorker

**File**: `reconciliation_worker.go:114–119`, `orphan_cleanup_worker.go:122`

**Problem**: Both workers make individual `catalogClient.GetProduct(ctx, id)` calls per product — N separate gRPC calls for N products. With 100,000 products in ES, the orphan cleanup runs 100,000 single-product gRPC calls synchronously per product (no parallelism, no batching).

- **Fix**: Add a `catalogClient.GetProductsBatch(ctx, []string ids)` gRPC method or use the existing `ListProducts` pagination to build a set, then compute symmetric difference vs. ES IDs without per-product calls.

---

### 🔵 NEW-P2-03: promotion_consumer `HandlePromotionDeleted` Returns `nil` on Empty `PromotionID`

**File**: `search/internal/data/eventbus/promotion_consumer.go:222–226`

**Problem**: `HandlePromotionCreated` and `HandlePromotionUpdated` correctly return an error on missing required fields (→ Dapr retry → DLQ). But `HandlePromotionDeleted` returns `nil` (silent ACK) on empty `PromotionID`:

```go
if eventData.PromotionID == "" {
    c.log.WithContext(ctx).Warnf("Received promotion deleted event with empty PromotionID, skipping")
    return nil  // ← ACK to Dapr — event considered processed, no DLQ routing
}
```

An empty `PromotionID` is a malformed event that should go to DLQ for inspection, not be silently acknowledged.

- **Fix**: Return `fmt.Errorf("promotion deleted event has empty PromotionID: %s", e.ID)` instead of `nil` to route to the DLQ.

---

## 7. GitOps Configuration Review

### 7.1 Search Worker (`gitops/apps/search/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr annotations: `enabled=true`, `app-id=search-worker`, `app-port=5005`, `grpc` | ✅ |
| `securityContext: runAsNonRoot, runAsUser: 65532` | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `envFrom: secretRef: search-secret` | ✅ |
| `volumeMounts: /app/configs` → `search-config` ConfigMap | ✅ |
| `livenessProbe` + `readinessProbe` (gRPC port 5005) | ✅ Fixed (prior sprint) |
| `resources.requests` + `resources.limits` defined | ✅ |

### 7.2 Search Main Deployment (`gitops/apps/search/base/deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr: `http` protocol, port 8017 | ✅ |
| `secretRef: search-secret` | ✅ |
| `volumeMounts` + config file mounted | ✅ |
| Liveness + readiness + startup probes | ✅ All present |

### 7.3 Search Sync Job (`gitops/apps/search/base/sync-job.yaml`)

| Check | Status |
|-------|--------|
| `secretRef: name: search-secret` | ✅ Fixed (prior sprint) |
| `backoffLimit: 2` | ✅ |
| `restartPolicy: Never` | ✅ |
| ES healthcheck init container | ✅ |

### 7.4 Search ConfigMap (`gitops/apps/search/overlays/dev/configmap.yaml`)

| Check | Status |
|-------|--------|
| `catalog_product_created` topic key | ✅ Matches constant |
| `catalog_attribute_config_changed` topic key | ✅ Fixed (prior sprint) |
| `warehouse_inventory_stock_changed` topic key | ✅ |
| `catalog_category_deleted` topic key | ✅ Fixed (prior sprint) |
| Promotion topic keys registered | ✅ Fixed (prior sprint) |
| `SEARCH_DATA_ELASTICSEARCH_ENABLE_HEALTHCHECK` in prod | ✅ prod overlay set |
| `SEARCH_SEARCH_CACHE_ENABLED` in prod | ✅ prod overlay set |

### 7.5 Search Production HPA

| Check | Status |
|-------|--------|
| Main service HPA defined | Check `gitops/apps/search/overlays/production/` |
| Worker HPA (safe due to DLQ partitioning) | ⚠️ Verify separate HPA for worker vs. main |

---

## 8. Worker & Cron Jobs Audit

### 8.1 Search Worker (Binary: `/app/bin/worker`)

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
| `stock-changed-dlq-consumer` | DLQ consumer | Real-time (Dapr) | ✅ Fixed (prior sprint) |
| `cms-page-created/updated/deleted-consumer` | Event consumers | Real-time (Dapr) | ✅ |
| `promotion-created/updated/deleted-consumer` | Event consumers | Real-time (Dapr) | ✅ |
| `category-deleted-consumer` | Event consumer | Real-time (Dapr) | ✅ Fixed (prior sprint) |
| `trending-worker` | Cron | Scheduled | ✅ |
| `popular-worker` | Cron | Scheduled | ✅ |
| `dlq-reprocessor` | Cron | Every 5 min | ✅ Running — see [NEW-02] |
| `reconciliation-worker` | Cron | Every 1 hour | ✅ Running — see [NEW-01] |
| `orphan-cleanup-worker` | Cron | Every 6 hours | ✅ Running — see [NEW-03] |

### 8.2 Missing / Not Registered

All consumers and cron workers are registered in `workers.go`. No missing registrations found.

**💡 DLQ topics for product/price/cms/category consumers** — each main consumer sets `deadLetterTopic` via Dapr metadata. However, unlike the stock DLQ which has an explicit `ConsumeStockChangedDLQ` drain handler, the other DLQ topics (product, price, cms, category) have NO drain consumer registered — they rely on `dlq_reprocessor_worker.go` to retry via DB `failed_events`. Verify this is the intended architecture: if the DLQ reprocessor is down, DLQ messages accumulate unacknowledged in Redis Streams indefinitely.

---

## 9. Edge Cases Not Yet Handled

| Edge Case | Risk | Note |
|-----------|------|------|
| **Product indexed by reconciliation shows $0 price, 0 stock** | 🔴 P0 | [NEW-01] — Must enrich from Pricing + Warehouse |
| **Orphan cleanup deletes on gRPC error (not just NotFound)** | 🔴 P0 | [NEW-03] — Catalog outage → mass ES deletion |
| **DLQ retry failure leaves event in "pending" indefinitely** | 🟡 P1 | [NEW-02] — No backoff status, hard to ops |
| **Promotion deleted event silently ACK'd on empty ID** | 🔵 P2 | [NEW-P2-03] — Should route to DLQ |
| **DLQ "ignored" events accumulate in DB forever** | 🔵 P2 | [NEW-P2-01] — Table bloat |
| **N+1 gRPC calls in reconciliation + orphan cleanup** | 🔵 P2 | [NEW-P2-02] — 100K products = 100K calls |
| **Attribute re-index no checkpoint** | 🔵 P2 | Prior audit — batch cursor missing on partial failure |
| **ES alias conflict during full reindex** | 🔵 P2 | Prior audit — real-time consumers write to alias simultaneously |
| **Soft-deleted product vs. DLQ'd delete event** | 🟡 P1 | If `product.deleted` event is DLQ'd, ES retains stale product; orphan cleanup catches it in 6h but shows invalid product in that window |
| **CMS consumer has no DLQ drain handler registered** | 🔵 P2 | CMS DLQ relies on reprocessor — single point of failure for CMS search |

---

## 10. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix Before Release

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-01]** | ReconciliationWorker indexes products with no price/stock/promotion data | Enrich from Pricing + Warehouse gRPC before `IndexProduct` |
| **[NEW-03]** | OrphanCleanupWorker deletes on ANY gRPC error (not just `codes.NotFound`) | Check `status.Code(err) == codes.NotFound` before deleting |

### 🟡 P1 — Fix in Next Sprint

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-02]** | DLQ failed retry leaves status "pending" — no operational visibility | Set status to `"retrying"` after each failed attempt; `"failed"` when exhausted |
| **EDGE-01** | Soft-deleted product remains in ES for up to 6h if `product.deleted` event DLQ'd | Reduce orphan cleanup interval or add monitoring alert for product.deleted DLQ depth |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-P2-01]** | DLQ "ignored" events accumulate in `failed_events` DB table | Add weekly cleanup job: `DELETE WHERE status='ignored' AND updated_at < NOW()-30d` |
| **[NEW-P2-02]** | N+1 gRPC calls in reconciliation + orphan cleanup | Add batch gRPC method or set-diff approach |
| **[NEW-P2-03]** | `HandlePromotionDeleted` silent ACK on empty `PromotionID` | Return error instead of nil → DLQ routing |
| **ATTR-REINDEX** | Bulk attribute re-index has no checkpoint cursor | Store page cursor; resume from last committed batch |
| **ES-ALIAS** | Real-time consumers may conflict with alias during full reindex | Alias-aware write routing |

---

## 11. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Outbox transactional | `product_write.go`: all mutations create outbox inside `InTx` |
| SKIP LOCKED + FetchAndMarkProcessing | `data/postgres/outbox.go:44` |
| Stuck processing recovery | `ResetStuckProcessing` (5 min threshold) |
| Search is sole ES writer | `product_indexing_handler.go` removed from catalog |
| PriceScope enforcement | Both `price_consumer.go` files require non-empty scope |
| Idempotency on all consumers | All search consumers: check → process → mark |
| DLQ on all consumers | All subscriptions register `deadLetterTopic` |
| Stock DLQ drain handler | `ConsumeStockChangedDLQ` registered in workers.go |
| Category deleted event + consumer | `catalog.category.deleted` → `UnsetCategoryFromProducts` |
| Promotion required field validation | `HandlePromotionCreated/Updated` return error on missing fields |
| DLQ reprocessor | Processes pending failed events every 5 min, max 5 retries |
| Orphan cleanup | Runs every 6 hours — removes ES products deleted from catalog |
| Reconciliation worker | Runs every 1 hour — detects catalog products missing from ES |
| `stripExpiredPromotions()` at query time | Protects against stale promo prices when `promotion.deleted` DLQ'd |
| Event staleness guards | `isStaleEvent`, `isStalePriceEvent`, `isStalePromotionEvent` |
| Search GitOps complete | secretRef, volumeMounts, probes, HPA (production) all present |
| Outbox cleanup job | Deletes COMPLETED events > 7 days, runs hourly |
| Reconciliation skips inactive contexts | Context-cancel check inside all batch loops |

---

## Related Files

| Document | Path |
|----------|------|
| Previous review (Sprint 1–3) | [search-discovery-flow-review.md](search-discovery-flow-review.md) |
| Catalog flow checklist | [catalog-product-flow-checklist.md](catalog-product-flow-checklist.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |
| DLQ replay runbook | [runbooks/dlq-replay-runbook.md](../../runbooks/dlq-replay-runbook.md) |

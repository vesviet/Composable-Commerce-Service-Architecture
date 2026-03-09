# Search & Discovery Flows — Business Logic Review Checklist

**Date**: 2026-03-07 (v3 — full re-audit following Shopify/Shopee/Lazada patterns)
**Reviewer**: AI Review (deep code scan — search, catalog, pricing, warehouse, promotion, review)
**Scope**: `search/`, `catalog/`, `pricing/`, `warehouse/`, `promotion/`, `review/` — product indexing, ES sync, event consumers, workers, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §3 (Search & Discovery)

> Previous sprint fixes are preserved as `✅ Fixed (Sprint N)`. New issues found in this audit use `[V3-*]` tags.
> **Audit 2026-03-07**: Full v3 re-audit — cross-checked ALL source service event publishers, GitOps ConfigMap topics, review/rating consumers, and worker constants.

---

## 📊 Summary (v3)

| Category | Sprint 1–3 | v2 Audit | v3 (This Audit) |
|----------|-----------|----------|-----------------|
| 🔴 P0 — Critical | 7 → 7 fixed | 1 → 1 fixed | 2 new |
| 🟡 P1 — High | 8 → 8 fixed | 2 → 2 fixed | 3 new |
| 🔵 P2 — Medium | 9 → 9 fixed | 3 noted | 4 new |

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
| Review rating ↔ ES rating | Eventually consistent (Review → Search via `review.approved`/`rating.updated`) | ⚠️ See [V3-P0-01] |
| **ConfigMap topic names ↔ Code constants** | Promotions topic mismatch | 🔴 See [V3-P0-02] |

### Data Mismatch Risks

- [x] **[FIXED] Dual ES writer** — Catalog no longer writes to ES directly; Search is sole writer.
- [x] **[FIXED] PriceScope inference fragile** — Both consumers enforce `scope == "" → return error`.
- [x] **[FIXED] Outbox dual-publish race** — Outbox publishes first; ProcessProduct* only cache/view.
- [x] **[FIXED NEW-01] ReconciliationWorker re-indexes products WITH price, stock data** — enriched via PricingClient + WarehouseClient.
- [ ] **[V3-P0-01] Review/Rating event topics NOT registered in GitOps ConfigMap** — See §6.
- [ ] **[V3-P0-02] ConfigMap promotion topic names MISMATCH with code constants** — See §6.

---

## 2. Event Publishing — Does Each Service Need to Publish?

| Service | Published Events | Needed By | Verdict |
|---------|----------------|-----------|---------|
| **Catalog** | `catalog.product.created/updated/deleted` | Search (ES index), Warehouse (init inventory) | ✅ Required |
| **Catalog** | `catalog.attribute.config_changed` | Search (ES mapping update + bulk re-index) | ✅ Required |
| **Catalog** | `catalog.category.deleted` | Search (bulk unset category from ES products) | ✅ Required |
| **Catalog** | `catalog.cms.page.created/updated/deleted` | Search (CMS content index) | ✅ Required |
| **Pricing** | `pricing.price.updated`, `pricing.price.deleted` | Search (ES price field) | ✅ Required |
| **Warehouse** | `warehouse.inventory.stock_changed` | Search (ES `in_stock`/`stock_quantity`) | ✅ Required (via outbox) |
| **Promotion** | `promotion.created/updated/deleted` | Search (ES promo badge + discount boost) | ✅ Required |
| **Review** | `review.approved` | Search (ES rating + review count update) | ✅ Required (via outbox) |
| **Review** | `rating.updated` | Search (ES average rating update) | ✅ Required (via outbox) |
| **Search** | (no outbound events published) | — | ✅ Correct — read-only service |

**No unnecessary publishers identified.**

---

## 3. Event Subscription — Does Search Need Each Subscription?

| Consumed Event | Reason | Worker Registered | Verdict |
|----------------|--------|-------------------|---------|
| `catalog.product.created` | Core ES indexing | ✅ `productCreatedConsumerWorker` | ✅ Essential |
| `catalog.product.updated` | Partial update ES | ✅ `productUpdatedConsumerWorker` | ✅ Essential |
| `catalog.product.deleted` | Remove from ES | ✅ `productDeletedConsumerWorker` | ✅ Essential |
| `catalog.attribute.config_changed` | ES mapping update + bulk re-index | ✅ `attributeConfigChangedConsumerWorker` | ✅ Essential |
| `catalog.category.deleted` | Bulk unset category from ES docs | ✅ `categoryDeletedConsumerWorker` | ✅ Essential |
| `catalog.cms.page.created/updated/deleted` | CMS content index | ✅ 3 CMS consumer workers | ✅ Essential |
| `pricing.price.updated` | ES price/sale_price fields | ✅ `priceUpdatedConsumerWorker` | ✅ Essential |
| `pricing.price.deleted` | Clear price from ES | ✅ `priceDeletedConsumerWorker` | ✅ Essential |
| `warehouse.inventory.stock_changed` | ES `in_stock`/`stock_quantity` | ✅ `stockChangedConsumerWorker` + DLQ | ✅ Essential |
| `promotion.created/updated/deleted` | ES promo badge, discount boost, expiry | ✅ 3 promotion consumer workers | ✅ Essential |
| `review.approved` | ES rating, review count | ✅ `reviewApprovedConsumerWorker` | ✅ Essential |
| `rating.updated` | ES average rating | ✅ `ratingUpdatedConsumerWorker` | ✅ Essential |

**No unnecessary subscriptions detected. All 17 event consumers serve a valid purpose.**

---

## 4. Outbox Pattern & Retry/Rollback (Saga) Implementation

### 4.1 Catalog Outbox (publishes to Search via Dapr)

| Check | File | Status |
|-------|------|--------|
| Product events inside `InTx` alongside DB write | `product_write.go` | ✅ Atomic |
| `FetchAndMarkProcessing` uses `FOR UPDATE SKIP LOCKED` | `data/postgres/outbox.go:44` | ✅ Fixed (P0-006) |
| `ResetStuckProcessing` (recovery for stuck PROCESSING > 5 min) | `outbox_worker.go:100–105` | ✅ Present |
| Max retries (5) → FAILED state | `outbox_worker.go:152` | ✅ Correct |
| Publish first, then COMPLETED, then side-effects | `outbox_worker.go:194–222` | ✅ Correct order |
| Outbox cleanup job (delete COMPLETED > 7 days) | `cron/outbox_cleanup.go` | ✅ Hourly |

### 4.2 Warehouse Outbox (stock_changed via Dapr)

| Check | Status |
|-------|--------|
| Stock events written to outbox inside `InTx` alongside DB write | ✅ `inventory_helpers.go`, `reservation.go` |
| Event type `warehouse.inventory.stock_changed` matches search constant | ✅ Exact match |

### 4.3 Review Outbox (review.approved, rating.updated via Dapr)

| Check | Status |
|-------|--------|
| `review.approved` via outbox in `moderation.go` | ✅ Atomic in transaction |
| `rating.updated` via outbox in `rating.go` | ✅ Atomic in transaction |
| Topic strings match search constants | ✅ `review.approved` and `rating.updated` exact match |

### 4.4 Search DLQ Reprocessor

| Check | File | Status |
|-------|------|--------|
| DLQ reprocessor processes pending events every 5 minutes | `dlq_reprocessor_worker.go:25` | ✅ Running |
| Max retries (5) → marks event as `"failed"` | `dlq_reprocessor_worker.go` | ✅ Fixed (NEW-02) |
| Context cancel check inside loop | `dlq_reprocessor_worker.go` | ✅ Present |
| `FailedEventCleanupWorker` cleans up old events | `failed_event_cleanup.go` | ✅ Daily cleanup, 30-day retention |

### 4.5 Saga Pattern Assessment

Catalog → Search is **Eventually Consistent Read Model** — not a financial Saga.
- [x] Write-through outbox guarantees at-least-once delivery.
- [x] Idempotency on Search ensures at-most-once processing per event ID.
- [x] DLQ consumers drain dead-lettered events with ERROR logging.
- [x] DLQ reprocessor retries up to 5× then marks `"failed"`.
- [x] `FailedEventCleanupWorker` deletes ignored events older than 30 days.

---

## 5. Previously Fixed Issues (confirmed in code)

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
| **NEW-01** | ReconciliationWorker indexes without price/stock | ✅ Fixed — enriched via Pricing + Warehouse |
| **NEW-02** | DLQ retry failure leaves status "pending" | ✅ Fixed — separated pending/retrying; "failed" on exhaust |
| **NEW-03** | OrphanCleanupWorker treats gRPC errors as "not found" | ✅ Fixed — `strings.Contains` for `not found` check |
| **NEW-P2-01** | DLQ "ignored" events never cleaned up | ✅ Fixed — `FailedEventCleanupWorker` daily cron |
| **NEW-P2-02** | N+1 gRPC calls in reconciliation/orphan cleanup | 🔵 P2 — still present, roadmap item |
| **NEW-P2-03** | `HandlePromotionDeleted` silent ACK on empty ID | 🔵 P2 — still present |

---

## 6. NEW Issues Found in v3 Audit

### 🔴 V3-P0-01: Review/Rating Event Topics NOT Registered in GitOps ConfigMap

**File**: `gitops/apps/search/base/configmap.yaml` lines 47–65

**Problem**: The `data.eventbus.topic` section in the ConfigMap only declares topics from catalog, pricing, warehouse, and promotion domains. The two review/rating topics consumed by Search are completely absent:

```yaml
# MISSING from configmap.yaml:
review_approved: review.approved
rating_updated: rating.updated
```

The search code in `constants/event_topics.go` hardcodes these topics (`TopicReviewApproved = "review.approved"`, `TopicRatingUpdated = "rating.updated"`), and `review_consumer.go` uses these constants directly (not reading from config). This means **the consumers work today because they bypass config**, but the ConfigMap documentation is incomplete and the topics won't appear in any ops dashboards or config audits.

**Risk**: If a future refactor reads topics from config (like other consumers do for `defaultPubsub`), review/rating events will silently stop being consumed.

**Fix**: Add the two review/rating topics to `configmap.yaml` under `data.eventbus.topic`:
```yaml
review_approved: review.approved
rating_updated: rating.updated
```

---

### 🔴 V3-P0-02: ConfigMap Promotion Topic Names MISMATCH with Code Constants and Source Service

**File**: `gitops/apps/search/base/configmap.yaml` lines 63–65

**Problem**: The ConfigMap declares promotion topics with `promotions.` prefix:
```yaml
promotions_promotion_created: promotions.promotion.created
promotions_promotion_updated: promotions.promotion.updated
promotions_promotion_deleted: promotions.promotion.deleted
```

But the actual values used everywhere in code and the source promotion service are:
- Search constants: `TopicPromotionCreated = "promotion.created"` (no `s`)
- Promotion service constants: `TopicPromotionCreated = "promotion.created"` (no `s`)
- Search consumer code: uses `constants.TopicPromotionCreated` directly

**Impact**: Because the promotion consumer in `promotion_consumer.go:52` reads the topic from `constants.TopicPromotionCreated` (not from config), the mismatch is currently harmless. But the ConfigMap is **factually wrong** as documentation — any ops/SRE reviewing the ConfigMap will believe topics are `promotions.promotion.*` when they are actually `promotion.*`.

**Fix**: Correct the ConfigMap to match:
```yaml
promotion_created: promotion.created
promotion_updated: promotion.updated
promotion_deleted: promotion.deleted
```

---

### 🟡 V3-P1-01: Missing DLQ Topics for Review/Rating Events

**File**: `search/internal/data/eventbus/review_consumer.go` lines 74–81, 145–152

**Problem**: Review consumers register `deadLetterTopic` metadata that references DLQ constants:
```go
"deadLetterTopic": constants.DLQTopicReviewApproved,  // "dlq.review.approved"
"deadLetterTopic": constants.DLQTopicRatingUpdated,    // "dlq.rating.updated"
```

These DLQ topics are defined in `constants/event_topics.go` but are **not declared in the GitOps ConfigMap**. This means Dapr pubsub will create these topics on-the-fly (auto-provisioned). While this works with Redis Streams, it may cause issues with stricter brokers or create invisible resource usage.

**Fix**: Add to ConfigMap:
```yaml
dlq_review_approved: dlq.review.approved
dlq_rating_updated: dlq.rating.updated
```

---

### 🟡 V3-P1-02: Stale Pricing Topics in ConfigMap — `pricing.warehouse_price.updated` and `pricing.sku_price.updated`

**File**: `gitops/apps/search/base/configmap.yaml` lines 59–60

**Problem**: ConfigMap declares two pricing topics that no longer exist in the pricing service:
```yaml
pricing_warehouse_price_updated: pricing.warehouse_price.updated
pricing_sku_price_updated: pricing.sku_price.updated
```

Pricing service only publishes:
- `pricing.price.updated` — unified topic (all scopes)
- `pricing.price.deleted`
- `pricing.price.bulk_updated`
- `pricing.price.calculated`
- `pricing.discount.applied`

These stale ConfigMap entries are dead configuration that misleads auditors.

**Fix**: Remove the two stale lines from ConfigMap.

---

### 🟡 V3-P1-03: `FailedEventCleanupWorker` NOT Registered in `worker_names.go` Constants

**File**: `search/internal/constants/worker_names.go`

**Problem**: All other workers have named constants in `worker_names.go`, but `FailedEventCleanupWorker` uses a hardcoded string `"failed-event-cleanup"` in its constructor. This breaks the convention that all worker names are centralized constants.

**Fix**: Add to `worker_names.go`:
```go
WorkerNameFailedEventCleanup = "failed-event-cleanup"
```
And use it in `NewFailedEventCleanupWorker`.

---

### 🔵 V3-P2-01: No DLQ Drain Consumer for Review/Rating Topics

**File**: `search/internal/worker/workers.go`

**Problem**: The stock consumer has a dedicated DLQ drain consumer (`ConsumeStockChangedDLQ`), but review/rating DLQ topics (`dlq.review.approved`, `dlq.rating.updated`) have **no drain consumer registered**. DLQ'd review/rating events will accumulate unacknowledged in Redis Streams. They'll be picked up by the `DLQReprocessorWorker` only if they were saved to `failed_events` DB table (which relies on the DLQ handler saving them first).

**Fix**: Either add explicit DLQ drain consumers for review/rating (like `ConsumeStockChangedDLQ`), or verify the DLQ reprocessor path handles them correctly.

---

### 🔵 V3-P2-02: `HandlePromotionDeleted` Returns `nil` on Empty `PromotionID` (Carried Forward)

**File**: `search/internal/data/eventbus/promotion_consumer.go:222–226`

**Problem** (carried from v2): An empty `PromotionID` is ACK'd silently:
```go
if eventData.PromotionID == "" {
    c.log.WithContext(ctx).Warnf("...")
    return nil  // ← ACK to Dapr — event skipped
}
```

**Fix**: Return `fmt.Errorf(...)` to route to DLQ.

---

### 🔵 V3-P2-03: N+1 gRPC Calls in Reconciliation and OrphanCleanup (Carried Forward)

**File**: `reconciliation_worker.go`, `orphan_cleanup_worker.go`

**Problem** (carried from v2): Both workers make individual per-product gRPC calls (O(N) calls for N products). OrphanCleanup calls `GetProduct` for every product in ES index.

**Fix**: Add batch gRPC method or set-diff approach.

---

### 🔵 V3-P2-04: ConfigMap Cache Disabled in Dev — No Test Coverage for Cache Path

**File**: `gitops/apps/search/base/configmap.yaml` line 83

**Problem**: `cache.enabled: false` in the base ConfigMap means all dev/staging testing occurs with cache disabled. The code path through `searchUsecase.SearchProducts` → cache-hit → return is never tested in the dev environment. If a bug exists in cache serialization/deserialization, it will only surface in production.

**Fix**: Enable cache in at least one non-production environment (e.g., staging) to validate the cache path before production rollout.

---

## 7. GitOps Configuration Review

### 7.1 Kustomization Structure (`gitops/apps/search/base/kustomization.yaml`)

| Check | Status |
|-------|--------|
| Uses `common-deployment-v2` component | ✅ |
| Uses `common-worker-deployment-v2` component | ✅ |
| `infrastructure-egress` component included | ✅ |
| `imagepullsecret/registry-api-tanhdev` component included | ✅ |
| API deployment: `search`, ports 8017/9017 | ✅ |
| Worker deployment: `search-worker`, command `/app/bin/worker` | ✅ |
| ArgoCD sync-waves: config(0), sync(1), api(2), worker(3) | ✅ Correct order |
| ServiceAccount propagation to both API + worker | ✅ Via kustomize replacements |
| Worker Dapr app-id propagation | ✅ Via kustomize replacements |
| PDB for both API and worker | ✅ `pdb.yaml` + `worker-pdb.yaml` |
| HPA defined | ✅ `hpa.yaml` in base |

### 7.2 Worker Deployment (`gitops/apps/search/base/patch-worker.yaml`)

| Check | Status |
|-------|--------|
| Dapr: `app-port=5005`, `app-protocol=grpc` | ✅ |
| initContainers: wait-for-consul, wait-for-redis, wait-for-postgres | ✅ |
| envFrom: configMapRef + secretRef | ✅ |
| Ports: gRPC 5005, metrics 8081 | ✅ |
| Resources: requests (128Mi/50m), limits (256Mi/200m) | ⚠️ May be low for 17 consumers + 4 cron workers |

### 7.3 ConfigMap (`gitops/apps/search/base/configmap.yaml`)

| Check | Status |
|-------|--------|
| Server ports: HTTP 8017, gRPC 9017 | ✅ |
| Database: connection pooling configured | ✅ max_open=100, max_idle=20 |
| Redis: configured with timeouts | ✅ |
| Elasticsearch: addresses, timeout=30s, max_retries=3 | ✅ |
| Consul service discovery | ✅ |
| Eventbus catalog topics (7 topics) | ✅ Listed |
| Eventbus pricing topics | ⚠️ Has 2 stale topics — see [V3-P1-02] |
| Eventbus warehouse topic | ✅ |
| Eventbus promotion topics | 🔴 Names mismatch — see [V3-P0-02] |
| Eventbus review/rating topics | 🔴 MISSING — see [V3-P0-01] |
| Search config: page sizes, fuzzy, spell check | ✅ |
| Cache: disabled in dev | ⚠️ See [V3-P2-04] |
| Analytics tracking | ✅ |
| ES index configuration (products, content, suggestions) | ✅ |
| Feature flags: personalization, recommendations, trending | ✅ |
| Business boost values: popular 1.2, in_stock 1.1, rated 1.15 | ✅ |

### 7.4 Sync Job (`gitops/apps/search/base/sync-job.yaml`)

| Check | Status |
|-------|--------|
| ArgoCD hook: `Sync` with sync-wave 1 | ✅ |
| backoffLimit: 2 | ✅ |
| restartPolicy: Never | ✅ |
| initContainers: wait-for-postgres, wait-for-elasticsearch, wait-for-catalog | ✅ |
| securityContext: runAsNonRoot, runAsUser 65532 | ✅ |
| Resources: requests (256Mi/100m), limits (512Mi/300m) | ✅ |
| Config volume mounted at `/app/configs` | ✅ |
| secretRef: search-secret | ✅ |
| ttlSecondsAfterFinished: 3600 (1 hour cleanup) | ✅ |

### 7.5 ArgoCD Application (`environments/dev/apps/search-app.yaml`)

| Check | Status |
|-------|--------|
| Namespace: `search-dev` | ✅ |
| Source path: `apps/search/overlays/dev` | ✅ |
| Automated sync: prune + selfHeal | ✅ |
| CreateNamespace=true | ✅ |
| Retry: limit=5, backoff 5s→3m | ✅ |

---

## 8. Worker & Cron Jobs Audit

### 8.1 Search Worker (Binary: `/app/bin/worker`)

| Worker | Type | Schedule/Trigger | DLQ Coverage | Status |
|--------|------|-----------------|--------------|--------|
| `eventbus-server` | Infrastructure | On-start gRPC | — | ✅ |
| `product-created-consumer` | Event consumer | Real-time (Dapr) | `dlq.catalog.product.created` | ✅ |
| `product-updated-consumer` | Event consumer | Real-time (Dapr) | `dlq.catalog.product.updated` | ✅ |
| `product-deleted-consumer` | Event consumer | Real-time (Dapr) | `dlq.catalog.product.deleted` | ✅ |
| `attribute-config-changed-consumer` | Event consumer | Real-time (Dapr) | implicit via DLQ reprocessor | ✅ |
| `price-updated-consumer` | Event consumer | Real-time (Dapr) | `dlq.pricing.price.updated` | ✅ |
| `price-deleted-consumer` | Event consumer | Real-time (Dapr) | `dlq.pricing.price.deleted` | ✅ |
| `stock-changed-consumer` | Event consumer | Real-time (Dapr) | `dlq.warehouse.inventory.stock_changed` | ✅ |
| `stock-changed-dlq-consumer` | DLQ drain | Real-time (Dapr) | — | ✅ |
| `cms-page-created-consumer` | Event consumer | Real-time (Dapr) | `dlq.catalog.cms.page.created` | ✅ |
| `cms-page-updated-consumer` | Event consumer | Real-time (Dapr) | `dlq.catalog.cms.page.updated` | ✅ |
| `cms-page-deleted-consumer` | Event consumer | Real-time (Dapr) | `dlq.catalog.cms.page.deleted` | ✅ |
| `category-deleted-consumer` | Event consumer | Real-time (Dapr) | `dlq.catalog.category.deleted` | ✅ |
| `promotion-created-consumer` | Event consumer | Real-time (Dapr) | `dlq.promotion.created` | ✅ |
| `promotion-updated-consumer` | Event consumer | Real-time (Dapr) | `dlq.promotion.updated` | ✅ |
| `promotion-deleted-consumer` | Event consumer | Real-time (Dapr) | `dlq.promotion.deleted` | ✅ |
| `review-approved-consumer` | Event consumer | Real-time (Dapr) | `dlq.review.approved` | ✅ |
| `rating-updated-consumer` | Event consumer | Real-time (Dapr) | `dlq.rating.updated` | ✅ |
| `trending-worker` | Continuous | Periodic (interval-based) | — | ✅ |
| `popular-worker` | Continuous | Periodic (interval-based) | — | ✅ |
| `dlq-reprocessor` | Cron | Every 5 min | — | ✅ |
| `reconciliation-cron` | Cron | Every 1 hour | — | ✅ |
| `orphan-cleanup-cron` | Cron | Every 6 hours | — | ✅ |
| `failed-event-cleanup` | Cron | Every 24 hours | — | ✅ |

### 8.2 Cross-Check: All Workers Registered in `workers.go`?

| Worker | In `workers.go` | Constants Name | Status |
|--------|-----------------|----------------|--------|
| eventbus-server | ✅ line 41 | `WorkerNameEventbusServer` | ✅ |
| product CRUD (3) | ✅ lines 44–46 | ✅ | ✅ |
| attribute-config-changed | ✅ line 47 | ✅ | ✅ |
| price-updated/deleted (2) | ✅ lines 48–50 | ✅ | ✅ |
| stock-changed + DLQ (2) | ✅ lines 51–52 | ✅ | ✅ |
| CMS CRUD (3) | ✅ lines 53–55 | ✅ | ✅ |
| category-deleted | ✅ line 56 | ✅ | ✅ |
| promotion CRUD (3) | ✅ lines 59–61 | ✅ | ✅ |
| review-approved | ✅ line 64 | ✅ | ✅ |
| rating-updated | ✅ line 65 | ✅ | ✅ |
| trending + popular | ✅ line 68 | ✅ | ✅ |
| dlq-reprocessor | ✅ line 71 | ✅ | ✅ |
| reconciliation | ✅ line 71 | ✅ | ✅ |
| orphan-cleanup | ✅ line 71 | ✅ | ✅ |
| failed-event-cleanup | ✅ line 71 | ⚠️ No constant | See [V3-P1-03] |

---

## 9. Edge Cases — Risk Matrix

| Edge Case | Severity | Status | Note |
|-----------|----------|--------|------|
| Product indexed by reconciliation with $0 price/0 stock | 🔴 P0 | ✅ Fixed (NEW-01) | Enriched from Pricing + Warehouse |
| Orphan cleanup deletes on gRPC error (not just NotFound) | 🔴 P0 | ✅ Fixed (NEW-03) | `strings.Contains "not found"` check |
| Review/rating events not in ConfigMap | 🔴 P0 | ⏳ [V3-P0-01] | Events work via hardcoded constants but ConfigMap is incomplete |
| ConfigMap promotion topics mismatch with code | 🔴 P0 | ⏳ [V3-P0-02] | `promotions.` prefix incorrect |
| DLQ retry failure leaves status stuck | 🟡 P1 | ✅ Fixed (NEW-02) | Separated pending/retrying; "failed" on exhaust |
| Missing DLQ topics for review/rating in ConfigMap | 🟡 P1 | ⏳ [V3-P1-01] | Not declared in ConfigMap |
| Stale pricing topics in ConfigMap | 🟡 P1 | ⏳ [V3-P1-02] | `warehouse_price.updated` and `sku_price.updated` don't exist |
| `FailedEventCleanupWorker` not in constants | 🟡 P1 | ⏳ [V3-P1-03] | Convention violation |
| No DLQ drain consumer for review/rating | 🔵 P2 | ⏳ [V3-P2-01] | Relies on DLQ reprocessor only |
| `HandlePromotionDeleted` silent ACK on empty ID | 🔵 P2 | ⏳ [V3-P2-02] | Should route to DLQ |
| N+1 gRPC calls in reconciliation/orphan cleanup | 🔵 P2 | ⏳ [V3-P2-03] | 100K products = 100K calls |
| Cache disabled in dev — no test coverage | 🔵 P2 | ⏳ [V3-P2-04] | Cache path never tested before prod |
| Attribute re-index no checkpoint cursor | 🔵 P2 | Prior audit | Batch cursor missing on partial failure |
| ES alias conflict during full reindex | 🔵 P2 | Prior audit | Alias-aware write routing needed |
| Soft-deleted product visible for up to 6h if delete DLQ'd | 🟡 P1 | ✅ Mitigated | Hourly `ReconciliationWorker` catches it |
| CMS consumer has no DLQ drain handler | 🔵 P2 | Prior audit | Relies on DLQ reprocessor |

---

## 10. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix Before Next Deploy

| ID | Description | Fix |
|----|-------------|-----|
| **[V3-P0-01]** | Review/Rating event topics NOT in GitOps ConfigMap | Add `review_approved` and `rating_updated` to `configmap.yaml` |
| **[V3-P0-02]** | ConfigMap promotion topics use `promotions.` prefix — mismatch with code `promotion.*` | Correct to `promotion.created/updated/deleted` |

### 🟡 P1 — Fix in Next Sprint

| ID | Description | Fix |
|----|-------------|-----|
| **[V3-P1-01]** | Missing DLQ topics for review/rating in ConfigMap | Add `dlq.review.approved` and `dlq.rating.updated` |
| **[V3-P1-02]** | Stale pricing topics in ConfigMap (`warehouse_price.updated`, `sku_price.updated`) | Remove stale entries |
| **[V3-P1-03]** | `FailedEventCleanupWorker` not in `worker_names.go` constants | Add constant and reference it |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Fix |
|----|-------------|-----|
| **[V3-P2-01]** | No DLQ drain consumer for review/rating events | Add explicit DLQ drain or verify reprocessor handles it |
| **[V3-P2-02]** | `HandlePromotionDeleted` silent ACK on empty `PromotionID` | Return error instead of nil |
| **[V3-P2-03]** | N+1 gRPC calls in reconciliation + orphan cleanup | Add batch gRPC method |
| **[V3-P2-04]** | Cache disabled in dev — no test coverage for cache path | Enable cache in staging |

---

## 11. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Outbox transactional (Catalog, Warehouse, Review) | All mutations create outbox inside `InTx` |
| SKIP LOCKED + FetchAndMarkProcessing | `data/postgres/outbox.go:44` |
| Search is sole ES writer | Catalog removed ES write code |
| PriceScope enforcement | Both price consumers require non-empty scope |
| Event idempotency on ALL consumers | All search consumers: check → process → mark |
| DLQ on ALL primary consumers | All subscriptions register `deadLetterTopic` |
| Stock DLQ drain handler | `ConsumeStockChangedDLQ` registered in workers.go |
| Zero-downtime index rebuild | `RebuildIndex()` — alias create → populate → switch → cleanup |
| Reconciliation worker | Hourly cross-check Catalog ↔ ES with price/stock enrichment |
| Orphan cleanup worker | 6-hourly removal of ES products deleted from Catalog |
| Failed event cleanup | Daily cleanup of `failed_events` older than 30 days |
| `stripExpiredPromotions()` at query time | Protects against stale promo prices |
| Event staleness guards | `isStaleEvent`, `isStalePriceEvent`, `isStalePromotionEvent` |
| Cache warming workers | Trending + Popular workers for pre-computed search results |
| GitOps complete structure | kustomize, PDB, HPA, NetworkPolicy, ServiceMonitor, probes |
| Sync job with health waits | Waits for Postgres, ES, and Catalog before starting |
| Context cancellation in all cron loops | All workers respect `ctx.Done()` for graceful shutdown |

---

## Related Files

| Document | Path |
|----------|------|
| Previous review (v2) | This file (overwritten with v3) |
| Catalog flow checklist | [catalog-product-review.md](catalog-product-review.md) |
| eCommerce flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |
| DLQ replay runbook | [runbooks/dlq-replay-runbook.md](../../runbooks/dlq-replay-runbook.md) |
| GitOps search config | `gitops/apps/search/base/configmap.yaml` |
| Worker registration | `search/internal/worker/workers.go` |
| Event topics | `search/internal/constants/event_topics.go` |

# Pricing, Promotion & Tax Flow — Business Logic Checklist

**Last Updated**: 2026-02-21
**Pattern Reference**: Shopify, Shopee, Lazada — `docs/10-appendix/ecommerce-platform-flows.md` §4
**Services Reviewed**: `pricing/`, `promotion/`
**Reviewer**: Antigravity Agent

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented correctly |
| ⚠️ | Risk / partial — needs attention |
| ❌ | Missing / broken |
| 🔴 | P0 — blocks production |
| 🟡 | P1 — reliability risk |
| 🔵 | P2 — improvement / cleanup |

---

## 1. Data Consistency Between Services

### 1.1 Pricing Service

| Check | Status | Notes |
|-------|--------|-------|
| `CreatePrice` / `UpdatePrice` use DB transaction + outbox in single TX | ✅ | `price.go:274-322`, outbox inserted before commit |
| `DeletePrice` fetches record first, then uses TX + outbox | ✅ | `price.go:482-544` |
| Cache invalidated **after** commit (not before) | ✅ | `price.go:317-319` — correct ordering |
| 4-level price priority fallback (SKU+WH > SKU > Product+WH > Product) | ✅ | `GetPriceWithPriority` properly cascades |
| `validatePrice` rejects `BasePrice ≤ 0`, negative SalePrice, SalePrice ≥ BasePrice | ✅ | `price.go:694-717` |
| Historical price uses `GetHistoricalPrice` — bypasses `IsEffective()` | ✅ | `price.go:473-479` — correct |
| **Discount table in pricing is a local mirror of promotion data** | ⚠️ | `promo_created_sub.go`: pricing mirrors promotion discounts locally. If promo event is lost or delayed, the local discount table diverges from the promotion service — stale discounts may be applied or not cleaned up. |
| Discount module in pricing marked as removed from `CalculationPrice` | ✅ | `calculation.go:260-264` — discounts offloaded to promotion service |
| `BulkCalculatePrice` — partial failure leaves some items nil, caller not notified | ⚠️ | `calculation.go:498-516` — nil results silently dropped; caller can't distinguish "not found" from "error" |

### 1.2 Promotion Service

| Check | Status | Notes |
|-------|--------|-------|
| `ApplyPromotion` uses idempotency check (`FindByPromotionAndOrder`) before insert | ✅ | `promotion.go:712-725` |
| DB-level unique constraint on `(promotion_id, order_id)` (migration 013) | ✅ | Documented in code comment |
| Campaign budget increment and usage reservation in same TX | ✅ | `promotion.go:741-765` |
| `ReleasePromotionUsage` decrements coupon usage atomically with cancellation | ✅ | `promotion.go:854-861` |
| `ConfirmPromotionUsage` is idempotent (0 rows = no-op) | ✅ | `promotion.go:817-820` |
| Per-customer usage limit (`UsageLimitPerCustomer`) checked during `ValidatePromotions` | ❌ | `isPromotionApplicable` (validation.go:244-303) does **not** query `GetUsageByCustomer` to count how many times the customer already used this promotion. Customer can abuse promotions with `UsageLimitPerCustomer` set. |
| Promotion `ValidatePromotions` fetches customer segments from `CustomerClient` | ⚠️ | Segments come from the request (`req.CustomerSegments`); if caller doesn't populate this field (checkout), validation may skip segment-restricted promotions incorrectly. |
| `GetAnalyticsSummary` caps promotions at limit 10000 — N+1 queries | ⚠️ | `usage_tracking.go:108-161` — loops over 10k promotions, calls DB for usage stats + coupon stats per promotion. Will cause timeout for large datasets. |
| Campaign deactivation cascades to promotions but does NOT publish per-promotion events | ⚠️ | `promotion.go:595-608` — individual promotions are deactivated in DB but no outbox events are saved; downstream consumers won't know promotions were deactivated. |

### 1.3 Tax Service (within Pricing)

| Check | Status | Notes |
|-------|--------|-------|
| Tax uses `TaxCalculationContext` with inclusive/exclusive flag | ✅ | `tax.go:144-306` |
| Pre-discount vs post-discount mode (`TaxBaseMode`) | ✅ | `tax.go:198-202` — CA/some-US-state pattern |
| Compound tax rules (stacked tax on tax) | ✅ | `tax.go:251-280` |
| Tax exempt customers (`IsTaxExempt`) | ✅ | `tax.go:188-192` |
| Tax rule cache key does NOT include `TaxBaseMode` — cache mismatch risk | ⚠️ | `generateTaxRuleCacheKey` at `tax.go:308-339` — the cache key is based on jurisdiction/category/group. Two requests for the same product+location but different `TaxBaseMode` will share the same cached rules but calculate different amounts (which is actually correct, as the rules are the same — only the base changes). However, `invalidateTaxRuleCache` only invalidates by `countryCode:state:postcode` — it does **not** invalidate combined `cat_` keys when a category-filtered rule changes. |

---

## 2. Outbox / Saga / Retry Pattern

### 2.1 Pricing Service — Outbox

| Check | Status | Notes |
|-------|--------|-------|
| Outbox worker exists in `pricing/internal/worker/` | ❌ | **No `outbox_worker.go` exists** in `pricing/internal/worker/`. The pricing service writes outbox events (model.OutboxEvent via `repo.InsertOutboxEvent`) but **no worker processes them**. Events sit in the outbox table and are never published to Dapr. |
| Pricing worker subscribes to `stock.updated` (→ dynamic pricing) | ✅ | `workers.go:29-41`, `stock_updated_sub.go` |
| Pricing worker subscribes to `promo.created/updated` (→ local discount sync) | ✅ | `workers.go:35-40`, `promo_created_sub.go` |
| `publishPriceDeletedEvent` in `price.go:786` — legacy direct publish still exists (dead code path) | ⚠️ | `price.go:786-803` — the function is defined but never called (delete path now uses outbox). Safe but confusing. |

### 2.2 Promotion Service — Outbox

| Check | Status | Notes |
|-------|--------|-------|
| Outbox worker polls every 30s, processes 50 events per tick | ✅ | `outbox_worker.go:46,77` |
| Failed publish keeps status `pending` and increments retry — will be retried next cycle | ✅ | `outbox_worker.go:122-124` |
| No max-retry cap enforced in outbox worker | ⚠️ | Comment says "SKIP LOCKED query with max_retries check will eventually stop retrying" but the code in `processEvent` only keeps status as `pending`. Whether the DB query actually enforces max retries depends on `FetchPendingEvents` SQL — not verified here. If not enforced, poison-pill events will loop forever. |
| Outbox cleanup: processed events older than 7 days purged | ✅ | `outbox_worker.go:94-99` |
| Promotion subscribes to `order.status_changed` (to confirm/release usage) | ✅ | `event_worker.go:41-43` |

### 2.3 Saga / Compensating Transactions

| Check | Status | Notes |
|-------|--------|-------|
| Promotion apply → order cancel → `ReleasePromotionUsage` triggered via order event | ✅ | Order consumer calls `ReleasePromotionUsage`; coupon usage decremented in same TX |
| Promotion confirm triggered by `order.delivered` event | ✅ | `ConfirmPromotionUsage` on delivered status |
| Price lock at order creation (snapshot of price at order time) | ⚠️ | Pricing service does **not** provide a `SnapshotPrice` or `LockPriceForOrder` API. The checkout service must call `CalculatePrice` and store the result on the order. If checkout doesn't persist the price snapshot at order write time, a price change between checkout and order creation causes a price mismatch. This pattern must be enforced in the checkout/order service, not pricing. |

---

## 3. Event Publishing — Is It Actually Needed?

### 3.1 Pricing Service

| Event | Topic | Published | Who Consumes | Assessment |
|-------|-------|-----------|--------------|------------|
| `price.updated` | `pricing.price.updated` | ✅ via outbox | Search service (re-index), Catalog (price display) | ✅ Needed — but **outbox worker missing** (see above) |
| `price.deleted` | `pricing.price.deleted` | ✅ via outbox | Search service (remove from index) | ✅ Needed |
| `price.calculated` | `pricing.price.calculated` | ✅ direct publish in `CalculationUsecase` | Analytics / audit | ⚠️ Not via outbox — if Dapr is temporarily unavailable, event is lost. Consider making this best-effort or moving to outbox. |
| `discount.applied` | `pricing.discount.applied` | ❌ Struct exists in events package but never published | — | 🔵 Dead code or missing integration |

### 3.2 Promotion Service

| Event | EventType (outbox) | Published | Who Consumes | Assessment |
|-------|-------------------|-----------|--------------|------------|
| `campaign.created/updated/activated/deactivated/deleted` | Various | ✅ via outbox | — | ⚠️ No downstream service appears to consume campaign events. Outbox overhead without consumer. |
| `promotion.event_created` | `promotion.event_created` | ✅ via outbox | Pricing (discount sync) | ⚠️ Event type `promotion.event_created` is a **typo** — should be `promotion.created`. Pricing observer subscribes based on topic, not event type string, so it still works via Dapr topic routing — but the event type field in payload is misleading for auditing. |
| `promotion.updated` | `promotion.updated` | ✅ via outbox | Pricing (discount sync) | ✅ |
| `promotion.deleted` | `promotion.deleted` | ✅ via outbox | Pricing (cleanup local discount) | ⚠️ Pricing's `promo_created_sub.go` handles create+update but **no handler exists for `promotion.deleted`** — stale discounts remain in pricing's local discount table. |
| `promotion.applied` | `promotion.applied` | ✅ via outbox | Loyalty (points earned?), Analytics | ✅ Needed |
| `promotion.usage_released` | `promotion.usage_released` | ✅ via outbox | Analytics | ✅ Needed |

### 3.3 Services That Should Subscribe (but may not)

| Service | Event to Subscribe | Reason | Status |
|---------|--------------------|--------|--------|
| Search | `pricing.price.updated` | Re-index product price in Elasticsearch | ⚠️ Check search service subscriber |
| Promotion | `pricing.price.updated` | None obvious | ✅ Should NOT subscribe |
| Order | `promotion.applied` | None required (promotion already applies via sync call) | ✅ Order calls promotion service directly |
| Loyalty | `promotion.applied` | Award points based on discount received | ⚠️ Check loyalty service subscriber |

---

## 4. GitOps Configuration

### 4.1 Pricing

| Check | Status | Notes |
|-------|--------|-------|
| Main deployment: HTTP 8002, gRPC 9002, Dapr 8002 (HTTP) | ✅ | Matches PORT_ALLOCATION_STANDARD |
| Worker deployment exists (`worker-deployment.yaml`) | ✅ | Dapr gRPC port 5005, health via gRPC probe |
| Worker ConfigMap `envFrom: overlays-config` | ✅ | `worker-deployment.yaml:58-60` |
| Worker has no `secretRef` (no secret volume) | ⚠️ | If worker needs DB/Redis credentials that come from a Secret (not ConfigMap), it must mount the secret. Verify overlay secrets include worker. |
| Worker health probe: gRPC on 5005 | ✅ | |
| Security context: `runAsNonRoot: true, runAsUser: 65532` | ✅ | Both main and worker |

### 4.2 Promotion

| Check | Status | Notes |
|-------|--------|-------|
| Main deployment: HTTP 8011, gRPC 9011, Dapr 8011 (HTTP) | ✅ | Matches PORT_ALLOCATION_STANDARD |
| **Worker deployment missing in GitOps** | 🔴 | `gitops/apps/promotion/base/` has NO `worker-deployment.yaml`. The promotion worker (outbox worker + order event consumer) will **never run in Kubernetes**. Outbox events accumulate forever; order cancellation/delivery will not trigger coupon release/confirm. |
| HPA (`hpa.yaml`) | ❌ | Not present for promotion — should be added if load is expected |
| Security context on main deployment | ✅ | `runAsNonRoot: true, runAsUser: 65532` |
| `dapr.io/app-protocol: http` on main | ✅ | |

---

## 5. Edge Cases & Risk Items

### 5.1 Pricing

| # | Risk | Severity | File | Mitigation |
|---|------|----------|------|------------|
| E1 | No outbox worker in pricing → `price.updated` events never published → Search/Catalog price index becomes stale | 🔴 P0 | `pricing/internal/worker/` | Add outbox worker similar to promotion service |
| E2 | `BulkCalculatePrice`: partial failures silently return nil — caller sees fewer results than requested with no error | 🟡 P1 | `calculation.go:499-516` | Return partial failure indicator or error list |
| E3 | Converted prices (currency conversion fallback) are cached **with the original price's ID** — if the source price changes, the cached converted price is not invalidated | 🟡 P1 | `price.go:179-205` | Store converted prices with a derived key excluding ID or use short TTL |
| E4 | `GetPrice` with currency fallback silently returns a converted price if the requested currency has no price record — consumer may not know it's using a converted rate | 🔵 P2 | `price.go:131-208` | Add a `PriceSource`/`IsCurrencyConverted` flag on the response |
| E5 | Dynamic pricing errors are swallowed (graceful degradation) — base price used without alerting | 🔵 P2 | `calculation.go:235-249` | Log metric/alert when dynamic pricing fails |
| E6 | Price rule tiebreaker uses insertion order (`CreatedAt`) — two rules created at the same second have non-deterministic order across DB instances | 🔵 P2 | `calculation.go:361-367` | Add a secondary stable ID sort |
| E7 | `stale discount table` — promotion deletion event has no handler in pricing → orphan discounts remain active | 🟡 P1 | `pricing/internal/observer/` | Add `promo_deleted_sub.go` handler |

### 5.2 Promotion

| # | Risk | Severity | File | Mitigation |
|---|------|----------|------|------------|
| E8 | `ValidatePromotions` does NOT check per-customer usage count vs `UsageLimitPerCustomer` — customer can apply the same promotion unlimited times during validation | 🔴 P0 | `validation.go:244-303` | Query `GetUsageByCustomer` at validation time, count existing usages for this promotion |
| E9 | Campaign deactivation does not emit per-promotion outbox events — downstream can't react to bulk promo deactivation | 🟡 P1 | `promotion.go:595-608` | Save `promotion.deactivated` outbox event for each deactivated promotion |
| E10 | `GetAnalyticsSummary` performs N+1 DB queries (per-promotion usage stats + coupon stats loop) — will timeout with large promotion count | 🟡 P1 | `usage_tracking.go:108-161` | Add aggregation SQL query or paginate |
| E11 | Outbox worker has no maximum retry cap in code — failed events could loop indefinitely unless `FetchPendingEvents` SQL enforces a cap | 🟡 P1 | `outbox_worker.go:102-130` | Verify `FetchPendingEvents` SQL has `WHERE retry_count < N`; if not, add to `processEvent` |
| E12 | `ValidatePromotions` enriches categories from Catalog with 2s timeout per product — for a 20-item cart this could add 40s latency | 🟡 P1 | `validation.go:487-515` | Batch product fetch or cache category lookups |
| E13 | Free shipping discount (`DiscountType: free_shipping`) returns `0` for `totalDiscount` — order total unchanged; checkout must read `ShippingDiscount` separately | 🔵 P2 | `validation.go:436-437` | Ensure checkout reads `PromotionValidationResponse.ShippingDiscount` not `TotalDiscount` |
| E14 | Promotion stacking conflict detection uses `warning` severity for multiple percentage discounts — they are still applied; no enforcement | 🔵 P2 | `validation.go:39-51` | Decide if multiple percentage discounts should be blocked (change severity to `error`) |
| E15 | Campaign budget increment does **not** check if the campaign itself is still active before incrementing | 🔵 P2 | `promotion.go:741-751` | Verify campaign is still active before `IncrementBudgetUsed` |

### 5.3 Tax

| # | Risk | Severity | File | Mitigation |
|---|------|----------|------|------------|
| E16 | Tax cache does not invalidate compound category keys — when a category-specific tax rule changes, only the base country key is invalidated | 🟡 P1 | `tax.go:341-372` | Add wildcard pattern invalidation or flush all keys for the country when any rule changes |
| E17 | Tax calculation returns `(0, nil, nil)` when no rules match — caller can't distinguish "tax = 0 by rule" from "no rules found (config error)" | 🔵 P2 | `tax.go:237-239` | Return a `TaxRulesNotFoundError` or a boolean `rulesFound` |
| E18 | `CalculateTax` (deprecated) is still public and callable — bypasses `TaxBaseMode` and category/customer group filtering | 🔵 P2 | `tax.go:101-124` | Remove or unexport the deprecated method |

---

## 6. Worker & Cron Job Summary

| Service | Worker | Type | Interval | Topics Consumed | Events Published |
|---------|--------|------|----------|-----------------|-----------------|
| `pricing` | `eventbus-server` | Continuous | — | (server) | — |
| `pricing` | `stock-consumer` | Event | Push | `warehouse.stock.updated` | Triggers dynamic pricing adjustment |
| `pricing` | `promo-consumer` | Event | Push | `promotion.created`, `promotion.updated` | Syncs local discount table |
| `pricing` | ❌ **missing outbox worker** | Periodic | — | — | `pricing.price.updated`, `pricing.price.deleted` (never published) |
| `promotion` | `outbox-worker` | Periodic | 30s | — | All promotion events via Dapr |
| `promotion` | `event-consumers` | Event | Push | `orders.order.status_changed` | — |

---

## 7. Summary of Findings

| Priority | Count | Key Items |
|----------|-------|-----------|
| 🔴 P0 | 3 | E1: Pricing outbox worker missing; E8: No per-customer usage limit check in validation; Promotion worker-deployment.yaml missing in GitOps |
| 🟡 P1 | 7 | E2 bulk calc silent fails; E3 converted price cache stale; E7 stale discount table; E9 cascade deactivation events; E10 N+1 analytics query; E11 no outbox max retries; E12 catalog enrichment latency; E16 tax cache invalidation gap |
| 🔵 P2 | 8 | E4 conversion flag missing; E5 dynamic pricing alert; E6 rule sort determinism; E13 shipping discount reads; E14 stacking enforcement; E15 budget check; E17 tax zero ambiguity; E18 deprecated CalculateTax |

---

## 8. Action Items

- [ ] **[P0]** Add outbox worker to `pricing/internal/worker/` (copy pattern from promotion outbox worker)
- [ ] **[P0]** Add `promotion-worker-deployment.yaml` to `gitops/apps/promotion/base/` and `kustomization.yaml`
- [ ] **[P0]** Add per-customer usage count query in `ValidatePromotions` for `UsageLimitPerCustomer`
- [ ] **[P1]** Add `promo_deleted_sub.go` handler in pricing observer to clean up local discount table
- [ ] **[P1]** Add outbox max-retry enforcement (verify `FetchPendingEvents` SQL filter)
- [ ] **[P1]** Fix campaign deactivation to emit per-promotion outbox events
- [ ] **[P1]** Fix N+1 analytics query in `GetAnalyticsSummary`
- [ ] **[P1]** Fix tax cache invalidation to flush category-scoped keys on rule change
- [ ] **[P1]** Batch catalog enrichment in `enrichRequestWithCatalogData` (parallel fetch or cache)
- [ ] **[P2]** Fix `promotion.event_created` typo → `promotion.created` in `CreatePromotion`
- [ ] **[P2]** Verify Search and Loyalty services subscribe to `pricing.price.updated` and `promotion.applied` respectively

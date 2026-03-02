# Pricing, Promotion & Tax Flow — Business Logic Review Checklist

**Date**: 2026-02-25 (v3 — full re-audit + fixes following Shopify/Shopee/Lazada patterns)
**Reviewer**: AI Review (deep code scan — pricing, promotion, tax)
**Scope**: `pricing/`, `promotion/` — price lifecycle, promotion validation, tax calculation, event pub/sub, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §4 (Pricing, Promotion & Tax)

> Previous sprint fixes preserved as `✅ Fixed`. New issues from this audit use `[V3-*]` tags.

---

## 📊 Summary (v3)

| Category | v1–v2 Status | v3 Status |
|----------|-------------|------------|
| 🔴 P0 — Critical | 5 found → 3 fixed, 2 open | **2 open → 2 FIXED this session** |
| 🟡 P1 — High | 4 found → 0 fixed | **5 open → 5 FIXED this session** |
| 🔵 P2 — Medium | 7 open | **1 new → FIXED this session** |

---

## 1. Data Consistency Between Services

### 1.1 Pricing Service

| Check | Status | Notes |
|-------|--------|-------|
| `CreatePrice`/`UpdatePrice` use DB transaction + outbox in single TX | ✅ | `price_crud.go:203–252`, `254–309` |
| Cache invalidated **after** commit (not before) | ✅ | `price_crud.go:247–249`, `304–306` |
| 4-level price priority fallback (SKU+WH > SKU > Product+WH > Product) | ✅ | `GetPriceWithPriority` cascades correctly |
| `validatePrice` rejects `BasePrice ≤ 0`, negative SalePrice, SalePrice ≥ BasePrice | ✅ | `price_crud.go:544–567` |
| Outbox `GetPendingOutboxEvents` uses `FOR UPDATE SKIP LOCKED` | ✅ Fixed |
| `BulkCalculatePrice` partial failures signalled via `([]results, []errors)` | ✅ Fixed |
| Converted price cache key uses `productID+currency` (not stale record ID) | ✅ Fixed |
| Price rules sorted deterministically (priority + CreatedAt tiebreaker) | ✅ | `calculation.go:354–367` — `sort.SliceStable` with `CreatedAt` tiebreaker |
| Decimal arithmetic for price calculation (no float-based overflow) | ✅ | `calculation.go:223–226` — uses `shopspring/decimal` |

### Pricing Data Mismatch Risks

- [x] **[FIXED]** `promo_deleted_sub.go` handler implemented — orphan discounts cleaned up.
- [ ] **[V2-01] ⚠️ Stock consumer idempotency is in-memory only (`sync.Map`, 5-min TTL)** — `stock_consumer.go:31–52`. When the pricing worker pod restarts, `processedEvents` and `lastSeqMap` are reset. Dapr may re-deliver stock events → duplicate dynamic pricing triggers.
  - *Shopee/Lazada pattern*: Idempotency stored in Redis or PostgreSQL, not in-process memory.
  - **Fix**: Replace `sync.Map` with Redis `SET NX EX` per event ID.
- [x] **[V3-01] ✅ Fixed** — Added `promotion.deactivated` subscription to `promo_consumer.go:ConsumePromoEvents`, routed to `HandlePromotionDeleted`. Added `EventTypePromotionDeactivated` constant and DLQ topic.

### 1.2 Promotion Service

| Check | Status | Notes |
|-------|--------|-------|
| `ApplyPromotion` idempotency: `FindByPromotionAndOrder` + DB unique constraint | ✅ | `promotion_usecase.go:94–104` |
| Campaign budget + usage reservation in same TX | ✅ | `promotion_usecase.go:122–131` |
| `ReleasePromotionUsage` decrements atomically in TX | ✅ | `promotion_usecase.go:200–254` |
| Per-customer usage limit enforced in `ValidatePromotions` | ✅ Fixed |
| Campaign deactivation emits per-promotion outbox events | ✅ | `campaign.go:83–101` |
| N+1 analytics queries eliminated (bulk stats) | ✅ | `usage_tracking.go:35–44` |
| Outbox max retry cap (migration 013 adds `max_retries INT DEFAULT 5`) | ✅ Fixed |
| `ConfirmPromotionUsage` idempotent (returns nil when rowsAffected==0) | ✅ | `promotion_usecase.go:190–193` |
| `ReleasePromotionUsage` idempotent (returns nil when rowsAffected==0) | ✅ | `promotion_usecase.go:216–219` |
| Coupon usage decremented on release (within TX) | ✅ | `promotion_usecase.go:222–228` |
| Release failure publishes alert event | ✅ | `promotion_usecase.go:251–253` |

### Promotion Data Mismatch Risks

- [x] **[V2-02] ✅ Fixed** — Changed `const maxRetries = 10` → `5` in `outbox_worker.go:119` to match DB `max_retries DEFAULT 5`.
- [x] **[V3-02] ✅ Fixed** — Aligned all `Topic*` and `EventType*` constants in `promotion/internal/constants/constants.go` to match actual outbox strings (e.g., `promotion.created` not `promotions.promotion.created`). `EventType*` now derives from `Topic*` constants.

---

## 2. Outbox / Saga / Retry Pattern

### 2.1 Pricing Service — Outbox

| Check | Status |
|-------|--------|
| Outbox worker implements `ContinuousWorker` | ✅ |
| Outbox registered in worker binary | ✅ |
| `FOR UPDATE SKIP LOCKED` in `GetPendingOutboxEvents` | ✅ |
| Outbox cleanup: 7-day retention, 1000 batch limit | ✅ `biz/worker/outbox.go:92–99` |
| Poll interval: 5 seconds | ✅ `biz/worker/outbox.go:39` |
| Max retries: 5 (code matches DB) | ✅ `biz/worker/outbox.go:149` |
| Panic recovery in process loop | ✅ `biz/worker/outbox.go:82–87` |
| `GetBaseWorker()` returns `BaseContinuousWorker` | ✅ |

### 2.2 Promotion Service — Outbox

| Check | Status |
|-------|--------|
| Outbox worker processes 50 events per tick | ✅ `outbox_worker.go:77` |
| Outbox cleanup: processed events > 7 days purged | ✅ `outbox_worker.go:93–99` |
| `FOR UPDATE SKIP LOCKED` in `FetchPendingEvents` | ✅ `data/outbox.go:64–70` |
| **Outbox worker initial run on start** | ✅ Fixed — `w.processEvents(ctx)` called before ticker loop |
| **`max_retries` alignment (code=5, DB=5)** | ✅ Fixed [V2-02] |
| **`StopChan()` in select loop** | ✅ Fixed [V3-P2-03] — now listens for both `ctx.Done()` and `w.StopChan()` |

### 2.3 Saga / Compensating Transactions

| Check | Status |
|-------|--------|
| Promotion apply → order cancel → `ReleasePromotionUsage` | ✅ `order_consumer.go:88–94` |
| Promotion confirm triggered by `order.delivered` or `order.completed` | ✅ `order_consumer.go:96–102` |
| Release failure publishes alert event (`promotion.release_failed`) | ✅ `promotion_usecase.go:258–267` |
| Price snapshot locked at checkout (pricing service responsibility?) | ⚠️ Pricing has no `SnapshotPrice`/`LockPriceForOrder` API. Checkout must persist price at order time. |

---

## 3. Event Publishing — Is It Actually Needed?

### 3.1 Pricing Service

| Event | Topic | Published | Consumers | Assessment |
|-------|-------|-----------|-----------|------------|
| `price.updated` | `pricing.price.updated` | ✅ via outbox | Search, Catalog | ✅ Required |
| `price.deleted` | `pricing.price.deleted` | ✅ via outbox | Search | ✅ Required |
| `price.calculated` | `pricing.price.calculated` | ✅ direct publish (NOT via outbox) | Analytics | ⚠️ **Not durable** — direct Dapr publish via `eventHelper.PublishCustom`; if sidecar unavailable, event lost. Best-effort acceptable for analytics. |
| `discount.applied` | `pricing.discount.applied` | ❌ struct exists, never published | — | 🔵 Dead code — struct definition without any publish call |

### 3.2 Promotion Service

| Event | Published Via | Consumers | Assessment |
|-------|--------------|-----------|------------|
| `promotion.created` | ✅ outbox | Pricing (discount sync) | ✅ Required |
| `promotion.updated` | ✅ outbox | Pricing (discount sync) | ✅ Required |
| `promotion.deleted` | ✅ outbox | Pricing (discount sync) | ✅ Required |
| `promotion.deactivated` | ✅ outbox (campaign cascade) | **No consumer subscribed** | ❌ **[V3-01]** Pricing doesn't subscribe — discount mirror stale |
| `promotion.applied` | ✅ outbox | Loyalty (points), Analytics | ✅ Required |
| `promotion.usage_released` | ✅ outbox | Analytics | ✅ Required |
| `campaign.created/updated/activated/deactivated/deleted` | ✅ outbox | **No known consumer** | ⚠️ Outbox overhead; no documented consumer. Acceptable if analytics consumer planned. |

---

## 4. Event Subscription — Is It Actually Needed?

### 4.1 Pricing Service Subscriptions

| Event | Topic | Handler | Needed? |
|-------|-------|---------|---------| 
| `warehouse.stock.updated` | `warehouse.inventory.stock_changed` | `HandleStockUpdate` | ✅ Dynamic pricing on stock level |
| `warehouse.inventory.low_stock` | `warehouse.inventory.low_stock` | `HandleLowStock` | ✅ Flash pricing trigger on low stock |
| `promotion.created` | `promotion.created` | `HandlePromotionCreated` | ✅ Sync local discount mirror |
| `promotion.updated` | `promotion.updated` | `HandlePromotionUpdated` | ✅ Sync local discount mirror |
| `promotion.deleted` | `promotion.deleted` | `HandlePromotionDeleted` | ✅ Clean local discount mirror |
| **`promotion.deactivated`** | — | **NOT SUBSCRIBED** | ❌ **[V3-01]** Must subscribe to keep discount mirror consistent on campaign cascade |

**DLQ handling for pricing subscriptions**:
- `ConsumeStockUpdateDLQ` defined → ❌ NOT registered in `workers.go`
- `ConsumeLowStockDLQ` defined → ❌ NOT registered in `workers.go`
- `ConsumePromoDLQ` defined → ❌ NOT registered in `workers.go`

All 3 DLQ drain handlers are dead code (see [V2-03]).

### 4.2 Promotion Service Subscriptions

| Event | Handler | Needed? |
|-------|---------|---------| 
| `orders.order.status_changed` | `OrderConsumer.ConsumeOrderStatusChanged` | ✅ Confirm/release usage on order status |

**DLQ handling**:
- No DLQ consumer for `orders.order.status_changed.dlq` — see [V2-07].

---

## 5. New Issues Found in This Audit (v3)

### 🔴 V3-01: Pricing Does NOT Subscribe to `promotion.deactivated` — Stale Discount Mirror on Campaign Cascade

**File**: `pricing/internal/data/eventbus/promo_consumer.go`, `promotion/internal/biz/campaign.go:83–101`

**Problem**: When a campaign is deactivated, `DeactivateCampaign` cascades to all child promotions and emits `promotion.deactivated` events via outbox for each. However, the pricing service's `PromoConsumer.ConsumePromoEvents` only subscribes to 3 topics:
- `promotion.created` → `HandlePromotionCreated`
- `promotion.updated` → `HandlePromotionUpdated`  
- `promotion.deleted` → `HandlePromotionDeleted`

The `promotion.deactivated` topic is **not subscribed**. Consequence:
- Pricing's local discount mirror retains stale "active" promotions that were cascade-deactivated.
- Customers see discounts that should no longer apply.
- `CalculatePrice` applies phantom discounts from deactivated promotions.

**Fix**: Add `promotion.deactivated` subscription in `promo_consumer.go:ConsumePromoEvents`:
```go
if err := c.client.AddConsumerWithMetadata("promotion.deactivated", pubsub, map[string]string{
    "deadLetterTopic": "promotion.deactivated.dlq",
}, c.HandlePromotionDeleted); err != nil {
    return err
}
```
Also add this DLQ topic to `ConsumePromoDLQ`.

---

### 🟡 V3-03: `HandleLowStock` Has No Idempotency Guard — Duplicate Events Trigger Duplicate Pricing

**File**: `pricing/internal/data/eventbus/stock_consumer.go:145–167`

**Problem**: `HandleStockUpdate` has an in-memory idempotency guard via `processedEvents` sync.Map (even if imperfect). `HandleLowStock` has **no idempotency check at all** — not even in-memory. Every duplicate delivery of a `low_stock` event from Dapr triggers a full observer pipeline run, potentially applying dynamic pricing adjustments multiple times.

**Fix**: Add the same `processedEvents` dedup pattern to `HandleLowStock` (and ideally move to Redis-backed dedup for both handlers).

---

### 🟡 V3-04: Promotion Constants vs Outbox Topic Names Are Different — Maintenance Trap

**File**: `promotion/internal/constants/constants.go` vs `promotion/internal/biz/promotion_usecase.go`

**Problem**: Constants define topic names with `promotions.` prefix (e.g., `TopicPromotionCreated = "promotions.promotion.created"`), but the biz layer saves outbox events with bare names (e.g., `EventType: "promotion.created"`). These constants are **NOT used** for outbox event types — they're dangling. If a future developer uses `constants.TopicPromotionCreated` to subscribe or publish, they'll connect to a different topic than what the outbox actually emits.

| Where | Value |
|-------|-------|
| `constants.go:TopicPromotionCreated` | `"promotions.promotion.created"` |
| `promotion_usecase.go:23` (actual outbox) | `"promotion.created"` |
| Pricing subscribes to | `"promotion.created"` ✅ matches outbox |

**Fix**: Either (a) align constants to `"promotion.created"` etc., or (b) use the constants in `promotion_usecase.go` instead of hardcoded strings. Consistency is the key requirement.

---

### 🔵 V3-P2-03: Promotion Outbox Worker Missing `StopChan()` in Select Loop

**File**: `promotion/internal/worker/outbox_worker.go:49–56`

**Problem**: The `Start()` select loop only listens for `ctx.Done()`:
```go
select {
case <-ctx.Done():
    return nil
case <-ticker.C:
    w.processEvents(ctx)
}
```
It does NOT listen for `w.StopChan()`. Compare pricing's outbox worker which has both `ctx.Done()` AND `w.StopChan()`. If `BaseContinuousWorker.Stop()` is called without cancelling ctx, the promotion outbox worker will keep running.

**Fix**: Add `case <-w.StopChan(): return nil` to the select block.

---

## 6. Previously Identified Issues — Status Update

### 🔴 V2-03: Pricing — DLQ Drain Handlers NOT Registered in `workers.go`

**Status**: ✅ **FIXED this session** — Added `stockDLQWorker`, `lowStockDLQWorker`, `promoDLQWorker` types and registered in `NewWorkers()`. All 3 DLQ methods (`ConsumeStockUpdateDLQ`, `ConsumeLowStockDLQ`, `ConsumePromoDLQ`) are now wired.

### 🔴 V2-04: Pricing Worker `worker-deployment.yaml` Missing secretRef/volumeMounts

**Status**: ✅ **FIXED** — `gitops/apps/pricing/base/worker-deployment.yaml` now has:
- `secretRef: pricing` (line 63–64)
- `volumeMounts` for `/app/configs` (lines 84–87)
- `volumes` with `configMap: pricing-config` (lines 89–92)

### 🔴 V2-05: Promotion Worker `worker-deployment.yaml` Missing secretRef/volumeMounts

**Status**: ✅ **FIXED** — `gitops/apps/promotion/base/worker-deployment.yaml` now has:
- `secretRef: promotion-secrets` (line 63–64)
- `volumeMounts` for `/app/configs` (lines 72–74)
- `volumes` with `configMap: promotion-config` (lines 96–99)
- Bonus: `startupProbe` added (lines 89–95)

### 🟡 V2-06: Stock Consumer In-Memory Dedup Lost on Pod Restart

**Status**: ❌ **Still Open** — `stock_consumer.go:31–52` still uses `sync.Map`. Needs Redis `SET NX EX` migration (larger refactor).

### 🟡 V2-07: Promotion — No DLQ Consumer for `order.status_changed`

**Status**: ✅ **FIXED this session** — Added `ConsumeOrderStatusChangedDLQ` to `order_consumer.go` and registered in `event_worker.go:Start()`.

---

## 7. GitOps Configuration Review

### 7.1 Pricing Worker (`gitops/apps/pricing/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr: `enabled=true`, `app-id=pricing-worker`, `app-port=5005`, `grpc` | ✅ |
| `securityContext: runAsNonRoot, runAsUser: 65532` | ✅ |
| `livenessProbe` (httpGet /healthz port 8081) | ✅ |
| `readinessProbe` (httpGet /healthz port 8081) | ✅ |
| `resources.requests` + `resources.limits` | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: pricing` | ✅ Fixed |
| `volumeMounts` for `/app/configs` | ✅ Fixed |
| `volumes` section with `configMap: pricing-config` | ✅ Fixed |

### 7.2 Promotion Worker (`gitops/apps/promotion/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr: `enabled=true`, `app-id=promotion-worker`, `app-port=5005`, `grpc` | ✅ |
| `securityContext: runAsNonRoot, runAsUser: 65532` | ✅ |
| `livenessProbe` (httpGet /healthz port 8081) | ✅ |
| `readinessProbe` (httpGet /healthz port 8081) | ✅ |
| `startupProbe` | ✅ |
| `resources.requests` + `resources.limits` | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: promotion-secrets` | ✅ Fixed |
| `volumeMounts` for `/app/configs` | ✅ Fixed |
| `volumes` section with `configMap: promotion-config` | ✅ Fixed |
| HPA defined | ❌ Still missing (open P2) |

### 7.3 Pricing Main Deployment

| Check | Status |
|-------|--------|
| HTTP 8002, gRPC 9002, Dapr 8002 (HTTP) | ✅ |
| `runAsNonRoot: true, runAsUser: 65532` | ✅ |

### 7.4 Promotion Main Deployment

| Check | Status |
|-------|--------|
| HTTP 8011, gRPC 9011, Dapr 8011 (HTTP) | ✅ |
| `runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/app-protocol: http` on main | ✅ |

---

## 8. Worker & Cron Jobs Audit

### 8.1 Pricing Worker (Binary: `/app/bin/worker`)

| Worker | Type | Status |
|--------|------|--------|
| `eventbus-server` | Infrastructure (gRPC server for Dapr subscriptions) | ✅ |
| `stock-consumer` | Event consumer (`warehouse.inventory.stock_changed`, `warehouse.inventory.low_stock`) | ✅ |
| `promo-consumer` | Event consumer (`promotion.created`, `promotion.updated`, `promotion.deleted`) | ✅ |
| `outbox-worker` | Periodic 5s (publishes `price.updated`, `price.deleted`) | ✅ |
| **stock-changed-dlq-consumer** | DLQ drain | ✅ Fixed [V2-03] — registered in `workers.go` |
| **low-stock-dlq-consumer** | DLQ drain | ✅ Fixed [V2-03] — registered in `workers.go` |
| **promo-dlq-consumer** | DLQ drain (4 topics incl. deactivated) | ✅ Fixed [V2-03] — registered in `workers.go` |
| **promo-deactivated-consumer** | Event consumer for `promotion.deactivated` | ✅ Fixed [V3-01] — uses `HandlePromotionDeleted` |

### 8.2 Promotion Worker (Binary: `/app/bin/worker`)

| Worker | Type | Status |
|--------|------|--------|
| `outbox-worker` | Periodic 30s (publishes all promotion/campaign events) | ✅ See [V2-02] for max_retries mismatch |
| `event-consumers` | Event consumer (`orders.order.status_changed`) | ✅ |
| **order-status-dlq-consumer** | DLQ drain | ✅ Fixed [V2-07] — `ConsumeOrderStatusChangedDLQ` registered in `event_worker.go` |

---

## 9. Edge Cases Not Yet Handled

| Edge Case | Risk | Note |
|-----------|------|------|
| ~~Pricing doesn't subscribe `promotion.deactivated`~~ | ~~🔴 P0~~ | ✅ Fixed [V3-01] |
| ~~Pricing DLQ events accumulate~~ | ~~🔴 P0~~ | ✅ Fixed [V2-03] |
| **Pod restart invalidates stock event dedup → duplicate pricing triggers** | 🟡 P1 | [V2-06] — in-memory sync.Map lost on restart (needs Redis) |
| ~~LowStock handler has no idempotency~~ | ~~🟡 P1~~ | ✅ Fixed [V3-03] |
| ~~Promotion outbox max_retries mismatch~~ | ~~🟡 P1~~ | ✅ Fixed [V2-02] |
| ~~order.status_changed DLQ not drained~~ | ~~🟡 P1~~ | ✅ Fixed [V2-07] |
| ~~Promotion constants mismatch~~ | ~~🟡 P1~~ | ✅ Fixed [V3-04] |
| ~~Promotion outbox worker missing StopChan~~ | ~~🔵 P2~~ | ✅ Fixed [V3-P2-03] |
| **`price.calculated` event dropped if Dapr sidecar unavailable** | 🔵 P2 | Direct publish, not outbox — acceptable for analytics |
| **Campaign events published to outbox with no known consumer** | 🔵 P2 | Unnecessary DB write overhead |
| **Currency conversion flag missing on response** | 🔵 P2 | Caller can't detect converted rate |
| **Dynamic pricing errors swallowed silently** | 🔵 P2 | `calculation.go:236` — logs WARN but no metric/alert |
| **Free shipping discount — checkout must read `ShippingDiscount` field** | 🔵 P2 | Documentation gap |
| **Tax returns `(0, nil, nil)` when no rules match** | 🔵 P2 | Ambiguous zero-tax vs. no-config |
| **`DiscountAppliedEvent` struct defined but never published** | 🔵 P2 | Dead code |
| **Promotion HPA missing for production** | 🔵 P2 | No HPA yaml in production overlay |

---

## 10. Summary: Issue Priority Matrix

### 🔴 P0 — All Fixed ✅

| ID | Description | Status |
|----|-------------|--------|
| **[V3-01]** | Pricing: does NOT subscribe to `promotion.deactivated` | ✅ Fixed — Added subscription + DLQ |
| **[V2-03]** | Pricing: DLQ drain handlers NOT registered in `workers.go` | ✅ Fixed — 3 DLQ workers registered |

### 🟡 P1 — Mostly Fixed

| ID | Description | Status |
|----|-------------|--------|
| **[V3-03]** | Pricing: `HandleLowStock` zero idempotency | ✅ Fixed — in-memory dedup added |
| **[V3-04]** | Promotion: constants mismatch with actual outbox strings | ✅ Fixed — all constants aligned |
| **[V2-02]** | Promotion outbox `max_retries` mismatch | ✅ Fixed — code changed to 5 |
| **[V2-07]** | Promotion: no DLQ for `order.status_changed` | ✅ Fixed — `ConsumeOrderStatusChangedDLQ` added |
| **[V2-06]** | Pricing stock consumer: in-memory dedup lost on pod restart | ❌ Open — needs Redis `SET NX EX` (larger change) |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Status |
|----|-------------|--------|
| **[V3-P2-03]** | Promotion outbox worker `Start()` missing `StopChan()` | ✅ Fixed — StopChan + initial run added |
| **[V2-P2-01]** | `pricing.price.calculated` published direct (not outbox) — lost if Dapr unavailable | ❌ Open — acceptable for analytics |
| **[V2-P2-02]** | Campaign events published to outbox with no documented consumer | ❌ Open |
| **Dead code** | `DiscountAppliedEvent` struct defined in `events/price_events.go:58–69` but never published anywhere | ❌ Open |
| **Promotion HPA** | No HPA for promotion service (main + worker) in production overlay | ❌ Open |

---

## 11. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Pricing outbox: `FOR UPDATE SKIP LOCKED`, panic recovery, 5s poll, 7-day cleanup | `biz/worker/outbox.go` |
| Pricing outbox max_retries aligned at 5 (matches DB) | `biz/worker/outbox.go:149` |
| Promotion per-customer usage enforcement | `validation.go` — `GetUsageByCustomer` called per validation |
| Campaign cascade deactivation emits per-promotion events | `campaign.go:83–101` |
| Promotion analytics use bulk queries (no N+1) | `usage_tracking.go:35–44` bulk stats |
| Outbox cleanup (7-day retention) | Both pricing and promotion workers |
| ApplyPromotion optimistic lock retry (3 attempts) | `promotion_usecase.go:70–87` |
| Tax: compound tax rules, inclusive/exclusive, per-category | `tax.go` |
| Tax cache invalidation includes category wildcard | `tax.go` |
| Decimal arithmetic in price calculation | `calculation.go:223–226` (shopspring/decimal) |
| Price rule deterministic sorting (SliceStable + CreatedAt tiebreaker) | `calculation.go:354–367` |
| Stock consumer sequence-based staleness guard | `stock_consumer.go:116–124` |
| Schema validation on consumers (warning-level, non-blocking) | Both stock and promo consumers |
| GitOps: Both worker deployments have secretRef + volumeMounts | ✅ Fixed |
| Order consumer business-level idempotency | `order_consumer.go:73–76` (ConfirmPromotionUsage returns nil for 0 rows) |

---

## Related Files

| Document | Path |
|----------|------|
| Catalog flow checklist | [catalog-product-review.md](catalog-product-review.md) |
| Search flow checklist | [search-discovery-review.md](search-discovery-review.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

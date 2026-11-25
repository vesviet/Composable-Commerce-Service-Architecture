# 💰🎁🧾 Pricing, Promotion & Tax Flows — Business Logic Review Checklist

**Last Updated**: 2026-03-07  
**Pattern Reference**: Shopify, Shopee, Lazada  
**Scope**: Section 4 of [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md)  
**Services**: Pricing, Promotion, Order (cart totals), Catalog (price sync), Search (price index)

---

## 📊 Executive Summary

| Area | Status | Details |
|------|--------|---------|
| **Data Consistency** | ⚠️ Partial | Outbox pattern implemented in both services; some inter-service sync gaps remain |
| **Retry / Rollback** | ✅ Good | Outbox + DLQ + idempotency in place; promotion usage lifecycle (apply → confirm/release) working |
| **Event Architecture** | ✅ Good | All needed events published/consumed; DLQ drains configured |
| **Edge Cases** | 🔴 Gaps | Several unhandled edge cases identified (see §6) |
| **GitOps** | ✅ Good | Both services have API + Worker deployments, Dapr annotations, probes, ConfigMaps |

---

## 1. Data Consistency Between Services

### 1.1 Pricing ↔ Catalog Sync
- [x] Pricing publishes `pricing.price.updated` and `pricing.price.deleted` via **outbox pattern** — [price_crud.go](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/price/price_crud.go)
- [x] Catalog consumes price events via `price_consumer` worker — [service-map SKILL](file:///Users/tuananh/Desktop/myproject/microservice/.agent/skills/service-map/SKILL.md#L138)
- [ ] **RISK**: No reconciliation mechanism if catalog misses a price event (DLQ logs but doesn't retry to catalog)
- [ ] **RISK**: Bulk price updates (`pricing.price.bulk_updated`) — catalog consumer may not handle bulk events

### 1.2 Pricing ↔ Search Sync  
- [x] Search worker consumes `pricing.price.updated` and `pricing.price.deleted` — [trace-event-flow SKILL](file:///Users/tuananh/Desktop/myproject/microservice/.agent/skills/trace-event-flow/SKILL.md#L79-L86)
- [x] Search handles missing product in ES by fetching from Catalog gRPC → index → apply price
- [x] Price visibility: `has_price=true` on price update, `has_price=false` when last price deleted
- [ ] **RISK**: `pricing.price.bulk_updated` topic — search may not subscribe to bulk events

### 1.3 Pricing ↔ Warehouse (Dynamic Pricing)
- [x] Pricing consumes `warehouse.inventory.stock_changed` and `warehouse.inventory.low_stock` — [stock_consumer.go](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/data/eventbus/stock_consumer.go)
- [x] Redis-backed idempotency dedup with TTL — [stock_consumer.go:53-63](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/data/eventbus/stock_consumer.go#L53-L63)
- [x] Sequence ordering: drops stale out-of-order events via `sequence_number` check in Redis — [stock_consumer.go:130-142](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/data/eventbus/stock_consumer.go#L130-L142)
- [x] Dynamic pricing recalculation triggered on stock updates — [dynamic_pricing.go:TriggerDynamicPricingForStockUpdate](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/dynamic/dynamic_pricing.go)
- [ ] **RISK**: If warehouse event schema changes, schema validation is warning-level only (won't fail processing)

### 1.4 Promotion ↔ Pricing Sync
- [x] Pricing consumes `promotion.created`, `promotion.updated`, `promotion.deleted`, `promotion.deactivated` — [promo_consumer.go](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/data/eventbus/promo_consumer.go)
- [x] Promotion publishes events via **outbox pattern** — [outbox_worker.go](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/worker/outbox_worker.go)
- [x] DLQ configured for all 4 promo topics — [promo_consumer.go:152-176](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/data/eventbus/promo_consumer.go#L152-L176)
- [ ] **RISK**: `promotion.deactivated` is handled with same handler as `promotion.deleted` — may lose nuance

### 1.5 Promotion ↔ Order (Usage Lifecycle)
- [x] Promotion consumes `orders.order.status_changed` — [order_consumer.go](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/data/eventbus/order_consumer.go)
- [x] `cancelled`/`refunded` → `ReleasePromotionUsage` (restore quotas) — [order_consumer.go:122-128](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/data/eventbus/order_consumer.go#L122-L128)
- [x] `delivered`/`completed` → `ConfirmPromotionUsage` (finalize) — [order_consumer.go:130-136](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/data/eventbus/order_consumer.go#L130-L136)
- [x] IdempotencyHelper prevents duplicate processing (DB-backed, per orderID+status) — [order_consumer.go:101-116](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/data/eventbus/order_consumer.go#L101-L116)
- [x] DLQ configured for order status events — [order_consumer.go:142-156](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/data/eventbus/order_consumer.go#L142-L156)
- [ ] **RISK**: If promotion service is down when order status changes, events go to DLQ (ACK+log only, no re-processing)

---

## 2. Data Mismatch Risks

| # | Scenario | Risk Level | Current Handling | Gap |
|---|----------|-----------|------------------|-----|
| 1 | Price updated in DB but event not published | 🟢 Low | Outbox pattern — write event in same TX | ✅ Handled |
| 2 | Outbox event stuck in `processing` | 🟢 Low | Both workers reset stuck events after 5min | ✅ Handled |
| 3 | Promotion applied at checkout but price changed mid-checkout | 🟡 Medium | Price lock on order creation (ref: flow 4.5) | Partially handled — no explicit price snapshot |
| 4 | Promotion usage "applied" but order never paid/completed | 🟡 Medium | `order.status_changed` → release on cancel | Usage stays "applied" if order never transitions |
| 5 | Dynamic pricing + promotion applied simultaneously | 🟡 Medium | Sequential calculation: base→dynamic→discount→tax | No conflict detection between dynamic pricing and promotions |
| 6 | Tax rules changed between cart display and checkout | 🟡 Medium | Tax calculated at checkout | No price-lock for tax |
| 7 | Currency rate stale in cache (1hr TTL) | 🟡 Medium | Circuit breaker + single-flight pattern | No freshness validation for currency rates |
| 8 | Promotion deleted while being applied in concurrent checkout | 🟢 Low | Optimistic locking on usage increment | ✅ Handled |

---

## 3. Retry / Rollback (Saga & Outbox) Review

### 3.1 Outbox Pattern — Pricing Service ✅
- [x] Outbox table written in same DB transaction as price CRUD — [price_crud.go](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/price/price_crud.go)
- [x] Worker polls every 5s, publishes via Dapr gRPC — [outbox.go](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/worker/outbox.go)
- [x] Max retries: 10, then mark `failed` — [outbox.go:154](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/worker/outbox.go#L154)
- [x] Stuck event reset: events in `processing` for >5min reset to `pending` — [outbox.go:104](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/worker/outbox.go#L104)
- [x] Event cleanup: 7-day retention, batch limit 1000 — [outbox.go:92](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/worker/outbox.go#L92)
- [x] Panic recovery on processEvent — [outbox.go:82-87](file:///Users/tuananh/Desktop/myproject/microservice/pricing/internal/biz/worker/outbox.go#L82-L87)

### 3.2 Outbox Pattern — Promotion Service ✅
- [x] Outbox table written in same DB TX as campaign/promotion CRUD — [promotion_usecase.go](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/biz/promotion_usecase.go)
- [x] Worker polls every 5s, publishes via Dapr — [outbox_worker.go](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/worker/outbox_worker.go)
- [x] Max retries: 10, then mark `failed` — [outbox_worker.go:139](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/worker/outbox_worker.go#L139)
- [x] Stuck event reset: every 5 minutes — [outbox_worker.go:65-70](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/worker/outbox_worker.go#L65-L70)
- [x] Cleanup: processed events >7 days — [outbox_worker.go:112](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/worker/outbox_worker.go#L112)

### 3.3 Promotion Usage Saga (Choreography)
- [x] `ApplyPromotion` → usage created with status `applied` + optimistic locking retry — [promotion_usecase.go:70-89](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/biz/promotion_usecase.go#L70-L89)
- [x] `ConfirmPromotionUsage` → transitions `applied` → `redeemed` on order delivery — [promotion_usecase.go:179-216](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/biz/promotion_usecase.go#L179-L216)
- [x] `ReleasePromotionUsage` → transitions `applied` → `cancelled` on order cancel/refund — [promotion_usecase.go:218-275](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/biz/promotion_usecase.go#L218-L275)
- [x] Release failure → publishes alert event to DLQ — [promotion_usecase.go:277-287](file:///Users/tuananh/Desktop/myproject/microservice/promotion/internal/biz/promotion_usecase.go#L277-L287)
- [ ] **GAP**: No compensation action if `ConfirmPromotionUsage` fails (e.g., order delivered but promo confirm fails)
- [ ] **GAP**: No periodic reconciliation cron for "applied" usages older than N days (orphaned usage leak)

---

## 4. Event Publishing Review — Do Services Actually Need to Publish?

| Service | Event Published | Actually Needed? | Consumers | Verdict |
|---------|----------------|-------------------|-----------|---------|
| **Pricing** | `pricing.price.updated` | ✅ Yes | Catalog (cache), Search (ES index) | **NEEDED** |
| **Pricing** | `pricing.price.deleted` | ✅ Yes | Catalog (invalidate), Search (remove/hide) | **NEEDED** |
| **Pricing** | `pricing.price.bulk_updated` | ⚠️ Check | No known consumer | **REVIEW** — may be unused |
| **Pricing** | `pricing.price.calculated` | ⚠️ Check | No known consumer | **REVIEW** — analytics only? |
| **Pricing** | `pricing.discount.applied` | ⚠️ Check | No known consumer | **REVIEW** — analytics only? |
| **Promotion** | `campaign.created/updated/activated/deactivated` | ✅ Yes | Search (campaign display), Pricing (promo sync) | **NEEDED** |
| **Promotion** | `promotion.created/updated/deleted/deactivated` | ✅ Yes | Pricing (discount rules), Search (promo badge) | **NEEDED** |
| **Promotion** | `coupon.created/bulk_created/applied` | ⚠️ Check | No known consumer | **REVIEW** — analytics/notification? |

### 🆕 NEW-PPT-01: Unused Event Topics
- **Topics**: `pricing.price.bulk_updated`, `pricing.price.calculated`, `pricing.discount.applied`, `coupon.*`
- **Impact**: Event publishing overhead without consumers; Dapr PubSub resources wasted
- **Action**: Verify consumers exist or remove publishers; if needed for analytics, add analytics consumer

---

## 5. Event Subscription Review — Do Services Actually Need to Subscribe?

| Service | Event Consumed | Actually Needed? | Purpose | Verdict |
|---------|---------------|-------------------|---------|---------|
| **Pricing** | `warehouse.inventory.stock_changed` | ✅ Yes | Dynamic pricing recalculation | **NEEDED** |
| **Pricing** | `warehouse.inventory.low_stock` | ✅ Yes | Surge pricing trigger | **NEEDED** |
| **Pricing** | `promotion.created` | ✅ Yes | Local discount mirror sync | **NEEDED** |
| **Pricing** | `promotion.updated` | ✅ Yes | Update discount mirror | **NEEDED** |
| **Pricing** | `promotion.deleted` | ✅ Yes | Clean up discount mirror | **NEEDED** |
| **Pricing** | `promotion.deactivated` | ✅ Yes | Campaign cascade cleanup | **NEEDED** |
| **Promotion** | `orders.order.status_changed` | ✅ Yes | Usage lifecycle (confirm/release) | **NEEDED** |

> **All event subscriptions are justified.** No unnecessary subscriptions found.

---

## 6. Edge Cases — Unhandled Risks

### 🔴 Critical Edge Cases

**[EC-PPT-01] Orphaned Promotion Usage ("applied" forever)**
- **Scenario**: Checkout applies promotion, order enters PENDING_PAYMENT, customer never pays, order never transitions to cancelled (timeout mechanism could fail)
- **Impact**: Promotion quota permanently decremented, coupon "used" but not redeemed
- **Current**: No cron job to clean up stale "applied" usages
- **Fix**: Add a cron job to promotion worker that scans for `applied` usages older than 48h and releases them

**[EC-PPT-02] Price Mismatch at Checkout (Mid-Session Price Change)**
- **Scenario**: Customer adds item at $50, price changes to $60 via dynamic pricing while in cart, customer checks out at old price
- **Impact**: Revenue loss from stale cart prices
- **Current**: ecommerce-platform-flows.md §4.5 specifies "price mismatch handling" but no explicit code enforces re-validation before order creation
- **Fix**: Re-fetch prices at order creation time and compare with cart snapshot; reject if delta exceeds threshold

**[EC-PPT-03] Promotion Stacking Exploit via Concurrent Requests**
- **Scenario**: Customer sends 2 simultaneous checkout requests with different coupon codes to bypass stacking rules
- **Impact**: Double discount applied
- **Current**: Optimistic locking on usage, but stacking validation happens per-request
- **Fix**: Distributed lock on customerID during checkout validation

### 🟡 High Edge Cases

**[EC-PPT-04] Dynamic Pricing + Promotion Double Discount**
- **Scenario**: Dynamic pricing gives 10% off (low stock surge reversed to clearance), promotion gives additional 20% off
- **Impact**: Unintended 30% discount
- **Current**: No conflict detection between dynamic pricing and promotions
- **Fix**: Add max discount cap in calculation pipeline; flag conflicting adjustments

**[EC-PPT-05] Tax Jurisdiction Ambiguity**
- **Scenario**: Customer address at border of two tax zones; different shipping warehouses may apply different tax rules
- **Impact**: Tax calculation inconsistency
- **Current**: Tax calculated by shipping address only; no warehouse-based tax
- **Fix**: Consider origin-based vs destination-based tax rules per jurisdiction

**[EC-PPT-06] Currency Conversion During Flash Sale**
- **Scenario**: Flash sale price set in VND, customer views in USD; exchange rate fluctuation causes price to exceed original discount intent
- **Impact**: Sale price in foreign currency may not reflect intended discount
- **Current**: 1-hour cache TTL for exchange rates
- **Fix**: Lock sale price in target currency at sale creation time, or use margin buffer

**[EC-PPT-07] Outbox Event Ordering Not Guaranteed**
- **Scenario**: Price updated from $50→$60 then $60→$70 within same poll cycle; outbox events may be delivered out of order to consumers
- **Impact**: Consumer may apply $50→$60 after $60→$70, ending with stale price
- **Current**: No explicit ordering guarantee in outbox; pricing outbox doesn't include sequence numbers
- **Fix**: Add monotonic sequence per product to outbox events; consumer should apply latest seq only

### 🔵 Normal Edge Cases

**[EC-PPT-08] Promotion End Time Race**
- **Scenario**: Promotion expires at 23:59:59; request arrives at 23:59:59.500
- **Impact**: Promotion applied/rejected depending on clock skew
- **Current**: Time comparison in validation
- **Fix**: Add grace period (e.g., 30s buffer) for promotion start/end times

**[EC-PPT-09] Zero-Quantity Cart Items**
- **Scenario**: Cart item with quantity=0 passed to promotion engine
- **Impact**: Division by zero in per-item discount calculation, BOGO logic confusion
- **Current**: No explicit guard in discount calculator
- **Fix**: Validate quantity > 0 before entering discount calculation

---

## 7. GitOps Configuration Review

### 7.1 Pricing Service GitOps ✅

| Component | File | Status |
|-----------|------|--------|
| Kustomization | [kustomization.yaml](file:///Users/tuananh/Desktop/myproject/microservice/gitops/apps/pricing/base/kustomization.yaml) | ✅ Complete |
| API Deployment | `common-deployment-v2` component | ✅ Dapr app-id=`pricing`, HTTP 8002, gRPC 9002 |
| Worker Deployment | `common-worker-deployment-v2` component | ✅ Dapr app-id=`pricing-worker`, gRPC 5005 |
| Worker Patch | [patch-worker.yaml](file:///Users/tuananh/Desktop/myproject/microservice/gitops/apps/pricing/base/patch-worker.yaml) | ✅ Resources: 256Mi-512Mi mem, 100m-300m CPU |
| ConfigMap | configmap.yaml | ✅ Present |
| NetworkPolicy | networkpolicy.yaml | ✅ Present |
| PDB (API + Worker) | pdb.yaml + worker-pdb.yaml | ✅ Present |
| HPA | hpa.yaml | ✅ Present |
| ServiceMonitor | servicemonitor.yaml | ✅ Prometheus scraping |
| Migration Job | migration-job.yaml | ✅ Present |
| Sync Wave | API=2, Worker=3 | ✅ Worker starts after API |

### 7.2 Promotion Service GitOps ✅

| Component | File | Status |
|-----------|------|--------|
| Kustomization | [kustomization.yaml](file:///Users/tuananh/Desktop/myproject/microservice/gitops/apps/promotion/base/kustomization.yaml) | ✅ Complete |
| API Deployment | `common-deployment-v2` component | ✅ Dapr app-id=`promotion`, HTTP 8011, gRPC 9011 |
| Worker Deployment | `common-worker-deployment-v2` component | ✅ Dapr app-id=`promotion-worker`, gRPC 5005 |
| Worker Patch | [patch-worker.yaml](file:///Users/tuananh/Desktop/myproject/microservice/gitops/apps/promotion/base/patch-worker.yaml) | ✅ Resources: 128Mi-256Mi mem, 50m-200m CPU |
| ConfigMap | configmap.yaml | ✅ Present |
| NetworkPolicy | networkpolicy.yaml | ✅ Present |
| PDB (API + Worker) | pdb.yaml + worker-pdb.yaml | ✅ Present |
| HPA | hpa.yaml (API only) | ⚠️ No `worker-hpa.yaml` in base |
| Worker HPA | promotion only has `worker-hpa.yaml` in **production overlay** | ⚠️ No dev worker HPA |
| ServiceMonitor | servicemonitor.yaml | ✅ Prometheus scraping |
| Migration Job | migration-job.yaml | ✅ Present |
| Sync Wave | API=2, Worker=3 | ✅ Worker starts after API |

### 🆕 NEW-PPT-02: GitOps Gaps
- **Promotion worker resources** (128Mi/50m) are lower than pricing worker (256Mi/100m) — may be insufficient if event load grows
- **No worker HPA for dev** — promotion worker can't auto-scale in dev environment

---

## 8. Worker / Event Consumer / Cron Job Review

### 8.1 Pricing Worker (`pricing-worker`)

| Worker | Type | Description | Status |
|--------|------|-------------|--------|
| `eventbus-server` | Event | gRPC server for Dapr eventbus | ✅ Running |
| `stock-consumer` | Event | Consumes `warehouse.inventory.stock_changed` | ✅ Running |
| `promo-consumer` | Event | Consumes `promotion.{created,updated,deleted,deactivated}` | ✅ Running |
| `stock-changed-dlq-consumer` | DLQ | Drains stock_changed DLQ | ✅ Running |
| `low-stock-dlq-consumer` | DLQ | Drains low_stock DLQ | ✅ Running |
| `promo-dlq-consumer` | DLQ | Drains promo DLQ (created, updated, deleted, deactivated) | ✅ Running |
| `outbox-worker` | Outbox | Publishes price.updated/price.deleted from outbox table | ✅ Running |

- ✅ All DLQ consumers implemented
- ⚠️ **No cron jobs** in pricing worker — no scheduled reconciliation tasks
- [ ] **MISSING**: No periodic price consistency check cron (compare DB prices vs search index vs catalog cache)

### 8.2 Promotion Worker (`promotion-worker`)

| Worker | Type | Description | Status |
|--------|------|-------------|--------|
| `outbox-worker` | Outbox | Publishes campaign/promotion/coupon events from outbox | ✅ Running |
| `event-consumers` | Event | Consumes `orders.order.status_changed` + DLQ | ✅ Running |

- ✅ Outbox worker with stuck event reset + cleanup
- ✅ Order status consumer with DB-backed idempotency
- ⚠️ **No cron jobs** in promotion worker
- [ ] **MISSING**: Orphaned usage cleanup cron (see EC-PPT-01)
- [ ] **MISSING**: Campaign auto-activation/deactivation cron (based on starts_at/ends_at)
- [ ] **MISSING**: Expired coupon cleanup cron

---

## 9. Cross-Reference with ecommerce-platform-flows.md §4

| Flow Requirement | Implementation Status | Notes |
|-----------------|----------------------|-------|
| **4.1** Base Pricing — seller sets base price | ✅ | price_crud.go CreatePrice/UpdatePrice |
| **4.1** Platform minimum price rule | ✅ | rule_usecase, PriceRules evaluation |
| **4.1** Currency conversion | ✅ | currency_converter.go with circuit breaker |
| **4.1** Price history tracking | ❌ Missing | P1-5 issue — no audit trail |
| **4.1** Price competitiveness alerts | ❌ Missing | P1-7 — no competitor price comparison |
| **4.2** Percentage/Fixed/BOGO/Bundle discounts | ✅ | discount_calculator.go |
| **4.2** Flash sale (time-bounded, stock-limited) | ⚠️ Partial | Time-based exists, stock limit not enforced in promotion |
| **4.2** Voucher/coupon code redemption | ✅ | coupon.go with atomic usage increment |
| **4.2** Cashback (post-purchase credit) | ❌ Missing | Not implemented |
| **4.2** Free shipping threshold | ✅ | free_shipping.go |
| **4.3** Customer segment targeting | ✅ | conditions.go with customer gRPC call |
| **4.3** Promotion stacking rules | ✅ | StopRulesProcessing flag |
| **4.3** Campaign quota management | ✅ | Usage tracking with limits |
| **4.3** Promotion scheduling | ✅ | starts_at/ends_at in campaign |
| **4.4** Tax jurisdiction detection | ✅ | tax.go with TaxCalculationContext |
| **4.4** Product tax category mapping | ✅ | ProductCategories in TaxCalculationContext |
| **4.4** Inclusive vs exclusive tax | ✅ | IsTaxInclusive flag |
| **4.4** Tax invoice generation | ❌ Missing | No tax invoice service |
| **4.5** Price finalization pipeline | ✅ | calculation.go orchestrates all steps |
| **4.5** Line item price lock | ⚠️ Partial | Locked at order creation, not at checkout start |
| **4.5** Price mismatch handling | ⚠️ Partial | EC-PPT-02 — no explicit guard code |

---

## 10. Issue Summary

### 🚩 PENDING ISSUES (New Findings)

| ID | Priority | Issue | Service |
|----|----------|-------|---------|
| NEW-PPT-01 | 🔵 P2 | Unused event topics (`bulk_updated`, `calculated`, `discount.applied`, `coupon.*`) | Pricing, Promotion |
| NEW-PPT-02 | 🔵 P2 | GitOps: Promotion worker resources low, no worker HPA in dev | GitOps |
| EC-PPT-01 | 🔴 P0 | Orphaned "applied" promotion usage — no cleanup cron | Promotion |
| EC-PPT-02 | 🔴 P0 | Price mismatch at checkout — no re-validation before order creation | Order × Pricing |
| EC-PPT-03 | 🟡 P1 | Concurrent checkout stacking exploit — no distributed lock | Order × Promotion |
| EC-PPT-04 | 🟡 P1 | Dynamic pricing + promotion double discount — no cap | Pricing × Promotion |
| EC-PPT-05 | 🟡 P1 | Tax jurisdiction ambiguity at zone borders | Pricing (Tax) |
| EC-PPT-06 | 🟡 P1 | Currency conversion during flash sale — rate drift | Pricing |
| EC-PPT-07 | 🟡 P1 | Outbox event ordering not guaranteed | Pricing |
| EC-PPT-08 | 🔵 P2 | Promotion end time race condition (clock skew) | Promotion |
| EC-PPT-09 | 🔵 P2 | Zero-quantity cart items — no guard in discount calc | Promotion |
| MISSING-01 | 🟡 P1 | No price consistency reconciliation cron | Pricing |
| MISSING-02 | 🟡 P1 | No campaign auto-activation/deactivation cron | Promotion |
| MISSING-03 | 🟡 P1 | No expired coupon cleanup cron | Promotion |
| MISSING-04 | 🟡 P1 | No `ConfirmPromotionUsage` failure compensation | Promotion |
| EXISTING-01 | 🔴 P0 | P0-8: Bulk price updates no true batch SQL | Pricing |
| EXISTING-02 | ✅ Fixed | P0-10: BOGO logic verified | Promotion |
| EXISTING-03 | ✅ Fixed | P0-13: Free shipping validated | Promotion |

### ✅ RESOLVED (Previously Reported — Verified in Code)

| Issue | Fix Location |
|-------|-------------|
| Price events transactional (outbox pattern) | `pricing/internal/biz/price/price_crud.go` |
| Promotion stacking rules enforced | `promotion/internal/biz/conditions.go` |
| Cart session concurrency (optimistic locking) | `order/internal/biz/cart/cart.go` |
| Customer segment validation | `promotion/internal/biz/conditions.go` |
| Currency context propagation | `order/internal/biz/cart/totals.go` |
| Promotion usage race condition (atomic) | `promotion/internal/data/coupon.go` |
| Goroutine leak in bulk updates | `pricing/internal/biz/price/price_crud.go` |
| Batch SQL operations | `pricing/internal/data/postgres/price.go` |

---

## Related Documents

| Document | Path |
|----------|------|
| Existing Issues Checklist | [pricing-promotion-flow-issues.md](../active/pricing-promotion-flow-issues.md) |
| Platform Flows Reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |
| Service Map | [service-map SKILL](../../../../.agent/skills/service-map/SKILL.md) |
| Event Flow Tracing | [trace-event-flow SKILL](../../../../.agent/skills/trace-event-flow/SKILL.md) |
| Service Structure | [service-structure SKILL](../../../../.agent/skills/service-structure/SKILL.md) |

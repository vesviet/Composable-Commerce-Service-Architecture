# Pricing, Promotion & Tax Flow — Business Logic Review Checklist

**Date**: 2026-02-24 (v2 — full re-audit following Shopify/Shopee/Lazada patterns)
**Reviewer**: AI Review (deep code scan — pricing, promotion, tax)
**Scope**: `pricing/`, `promotion/` — price lifecycle, promotion validation, tax calculation, event pub/sub, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §4 (Pricing, Promotion & Tax)

> Previous sprint fixes preserved as `✅ Fixed (Sprint N)`. New issues from this audit use `[NEW-*]` tags.

---

## 📊 Summary (v2)

| Category | Sprint 1–3 | This Audit |
|----------|-----------|------------|
| 🔴 P0 — Critical | 3 found → 3 fixed | 2 new |
| 🟡 P1 — High | 9 found → 9 fixed | 3 new |
| 🔵 P2 — Medium | 8 found → 8 open | 2 new |

---

## 1. Data Consistency Between Services

### 1.1 Pricing Service

| Check | Status | Notes |
|-------|--------|-------|
| `CreatePrice`/`UpdatePrice` use DB transaction + outbox in single TX | ✅ | `price.go:274–322`, outbox inserted before commit |
| Cache invalidated **after** commit (not before) | ✅ | `price.go:317–319` — correct order |
| 4-level price priority fallback (SKU+WH > SKU > Product+WH > Product) | ✅ | `GetPriceWithPriority` cascades correctly |
| `validatePrice` rejects `BasePrice ≤ 0`, negative SalePrice, SalePrice ≥ BasePrice | ✅ | `price.go:694–717` |
| Outbox `GetPendingOutboxEvents` uses `FOR UPDATE SKIP LOCKED` | ✅ | Fixed (Sprint 3) |
| `BulkCalculatePrice` partial failures signalled via `([]results, []errors)` | ✅ | Fixed (Sprint 3) |
| Converted price cache key uses `productID+currency` (not stale record ID) | ✅ | Fixed (Sprint 3) |

### Pricing Data Mismatch Risks

- [x] **[FIXED]** `promo_deleted_sub.go` handler implemented — orphan discounts cleaned up.
- [ ] **[NEW-01] ⚠️ Stock consumer idempotency is in-memory only (`sync.Map`, 5-min TTL)** — `stock_consumer.go:31–51`. When the pricing worker pod restarts, `processedEvents` and `lastSeqMap` are reset to empty. Dapr may re-deliver stock events published before the restart → duplicate dynamic pricing triggers applied to price rules.
  - *Shopee/Lazada pattern*: Idempotency stored in Redis or PostgreSQL, not in-process memory.
  - **Fix**: Replace `sync.Map` with a Redis `SET NX EX` check per event ID, or add a DB-backed idempotency table similar to the search service's `event_idempotency`.

### 1.2 Promotion Service

| Check | Status | Notes |
|-------|--------|-------|
| `ApplyPromotion` idempotency: `FindByPromotionAndOrder` + DB unique constraint | ✅ | `promotion.go:712–725` |
| Campaign budget + usage reservation in same TX | ✅ | `promotion.go:741–765` |
| `ReleasePromotionUsage` decrements atomically | ✅ | `promotion.go:854–861` |
| Per-customer usage limit enforced in `ValidatePromotions` | ✅ | Fixed (Sprint 3) |
| Campaign deactivation emits per-promotion outbox events | ✅ | Fixed (Sprint 3) |
| N+1 analytics queries eliminated | ✅ | Fixed (Sprint 3) |
| Outbox max retry cap (migration 013 adds `max_retries INT DEFAULT 5`) | ✅ | Fixed (Sprint 3) |

### Promotion Data Mismatch Risks

- [ ] **[NEW-02] ⚠️ Promotion outbox `max_retries` inconsistency** — Migration 013 sets `max_retries DEFAULT 5` in the DB column, but `outbox_worker.go:119` hardcodes `const maxRetries = 10`. The in-code check runs first; if `retry_count >= 10` the event is marked `"failed"`. The DB SQL filter `WHERE retry_count < max_retries` (where `max_retries=5`) prevents fetching events already at count ≥ 5. This means events with `retry_count` between 5–9 are **invisible** to `FetchPendingEvents` (SQL filter blocks them) but the in-code cap hasn't triggered yet. These events are silently stuck — never retried and never marked failed. They will accumulate until a migration changes `max_retries` or the column is reset manually.
  - **Fix**: Align `maxRetries` constant in `outbox_worker.go` to `5` (matching migration 013), or remove the SQL filter and rely on the in-code cap alone.

---

## 2. Outbox / Saga / Retry Pattern

### 2.1 Pricing Service — Outbox

| Check | Status |
|-------|--------|
| Outbox worker implements `ContinuousWorker` | ✅ Fixed (Sprint 3) |
| Outbox registered in worker binary | ✅ Fixed (Sprint 3) |
| `FOR UPDATE SKIP LOCKED` in `GetPendingOutboxEvents` | ✅ Fixed (Sprint 3) |
| Outbox cleanup: COMPLETED events > 7 days purged | ✅ `outbox_worker.go:94–99` |
| `GetBaseWorker()` returns `BaseContinuousWorker` | ✅ |

### 2.2 Promotion Service — Outbox

| Check | Status |
|-------|--------|
| Outbox worker processes 50 events per tick | ✅ `outbox_worker.go:77` |
| Outbox cleanup: processed events > 7 days purged | ✅ `outbox_worker.go:94–99` |
| **Outbox worker does NOT run on startup — first fire after 30s** | ⚠️ `outbox_worker.go:46–57` — ticker fires after `30s`; no initial run before ticker. If pod restarts during high event volume, up to 30 seconds of event delivery lag. Compare: DLQ reprocessor in search runs immediately. |
| **`max_retries` inconsistency (code=10, DB=5)** | ❌ See [NEW-02] |

### 2.3 Saga / Compensating Transactions

| Check | Status |
|-------|--------|
| Promotion apply → order cancel → `ReleasePromotionUsage` | ✅ Order consumer triggers on `order.cancelled` |
| Promotion confirm triggered by `order.delivered` | ✅ `ConfirmPromotionUsage` on delivered status |
| Price snapshot locked at checkout (not pricing service responsibility) | ⚠️ Pricing has no `SnapshotPrice`/`LockPriceForOrder` API; checkout must persist price at order time. Enforced by checkout, not pricing. |

---

## 3. Event Publishing — Is It Actually Needed?

### 3.1 Pricing Service

| Event | Topic | Published | Consumers | Assessment |
|-------|-------|-----------|-----------|------------|
| `price.updated` | `pricing.price.updated` | ✅ via outbox | Search, Catalog | ✅ Required |
| `price.deleted` | `pricing.price.deleted` | ✅ via outbox | Search | ✅ Required |
| `price.calculated` | `pricing.price.calculated` | ✅ direct publish (NOT via outbox) | Analytics | ⚠️ **Not durable** — direct Dapr publish; if sidecar unavailable, event lost. Consider best-effort with error log or move to outbox. |
| `discount.applied` | `pricing.discount.applied` | ❌ struct exists, never published | — | 🔵 Dead code |

### 3.2 Promotion Service

| Event | Published | Consumers | Assessment |
|-------|-----------|-----------|------------|
| `promotion.created/updated/deleted` | ✅ via outbox | Pricing (local discount sync) | ✅ Required |
| `promotion.applied` | ✅ via outbox | Loyalty (points), Analytics | ✅ Required |
| `promotion.usage_released` | ✅ via outbox | Analytics | ✅ Required |
| `campaign.created/updated/activated/deactivated/deleted` | ✅ via outbox | **No known consumer** | ⚠️ Outbox overhead without documented consumer — verify if Analytics subscribes |

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

**DLQ handling for pricing subscriptions**:
- `ConsumeStockUpdateDLQ` defined → ❌ NOT registered in `workers.go`
- `ConsumeLowStockDLQ` defined → ❌ NOT registered in `workers.go`
- `ConsumePromoDLQ` defined → ❌ NOT registered in `workers.go`

All 3 DLQ drain handlers are dead code (see [NEW-03]).

### 4.2 Promotion Service Subscriptions

| Event | Handler | Needed? |
|-------|---------|---------|
| `orders.order.status_changed` | `OrderConsumer.ConsumeOrderStatusChanged` | ✅ Confirm/release usage on order status |

**DLQ handling for promotion subscriptions**: No DLQ consumer for `orders.order.status_changed.dlq` registered — if order events are exhausted to DLQ, promotion usage will never be confirmed/released.

---

## 5. NEW Issues Found in This Audit

### 🔴 NEW-03: Pricing — All 3 DLQ Drain Handlers Defined but NOT Wired in `workers.go`

**File**: `pricing/internal/worker/workers.go` + `pricing/internal/data/eventbus/promo_consumer.go:142–168` + `pricing/internal/data/eventbus/stock_consumer.go:169–198`

**Problem**: Three DLQ drain handlers are implemented but never registered as workers:

| Method | DLQ Topics Covered |
|--------|-------------------|
| `StockConsumer.ConsumeStockUpdateDLQ` | `warehouse.inventory.stock_changed.dlq` |
| `StockConsumer.ConsumeLowStockDLQ` | `warehouse.inventory.low_stock.dlq` |
| `PromoConsumer.ConsumePromoDLQ` | `promotion.created.dlq`, `promotion.updated.dlq`, `promotion.deleted.dlq` |

`workers.go` only registers: `eventbus-server`, `stock-consumer`, `promo-consumer`, `outbox-worker`. None of the DLQ handlers are called.

Consequence: When Dapr exhausts retries:
- Stock events that failed → accumulate in `warehouse.inventory.stock_changed.dlq` unacknowledged → Redis stream backpressure.
- Promo sync events that failed → accumulate in `promotion.*.dlq` → local discount table in pricing **permanently diverges** from the promotion service.

**Fix**: Add 3 DLQ worker registrations to `workers.go`:
```go
// stockChangedDLQWorker
workers = append(workers, &stockDLQWorker{consumer: stockConsumer})
// lowStockDLQWorker  
workers = append(workers, &lowStockDLQWorker{consumer: stockConsumer})
// promoDLQWorker (covers all 3 promo DLQ topics via ConsumePromoDLQ)
workers = append(workers, &promoDLQWorker{consumer: promoConsumer})
```

---

### 🔴 NEW-04: Pricing Worker `worker-deployment.yaml` Missing `secretRef` AND `volumeMounts`

**File**: `gitops/apps/pricing/base/worker-deployment.yaml`

**Problem**: The pricing worker deployment is missing two critical sections:

1. **No `secretRef`**: `envFrom` only has `configMapRef: overlays-config`. DB password, Redis password, JWT signing key — none are injected. Compare: catalog worker has `secretRef: catalog`; search worker has `secretRef: search-secret`.

2. **No `volumeMounts` + `volumes`**: Binary starts with `-conf /app/configs/config.yaml` but neither a `volumes` section with a ConfigMap nor a `volumeMounts` block mounting it to `/app/configs`. The binary will fail to load `config.yaml` at startup.

```yaml
# Current (broken):
envFrom:
- configMapRef:
    name: overlays-config
# No secretRef, no volumes, no volumeMounts
```

```yaml
# Required pattern (from search/base/worker-deployment.yaml):
envFrom:
- configMapRef:
    name: overlays-config
- secretRef:
    name: pricing-secret
volumeMounts:
- mountPath: /app/configs
  name: config
  readOnly: true
volumes:
- name: config
  configMap:
    name: pricing-config
```

---

### 🟡 NEW-05: Promotion Worker `worker-deployment.yaml` Missing `secretRef` AND `volumeMounts`

**File**: `gitops/apps/promotion/base/worker-deployment.yaml`

**Problem**: Same pattern as pricing — promotion worker has `envFrom: configMapRef: overlays-config` only. No `secretRef` for DB/Redis credentials and no `volumes`/`volumeMounts` for the config file at `/app/configs/config.yaml`.

---

### 🟡 NEW-06: Stock Consumer Idempotency Is In-Memory Only (`sync.Map`) — Lost on Pod Restart

**File**: `pricing/internal/data/eventbus/stock_consumer.go:31–52`

**Problem**: The stock consumer deduplicates events using an in-process `sync.Map`:
```go
processedEvents *sync.Map  // eventID → time.Time
lastSeqMap      *sync.Map  // "productID:warehouseID" → int64
```
TTL is 5 minutes. When the pod restarts (deploy, OOM, node eviction), both maps are reset. Dapr at-least-once delivery may re-deliver events published in the previous 5 minutes → duplicate dynamic pricing adjustments applied to price rules.

- *Shopee pattern*: Event dedup stored in Redis `SET NX EX 300` or DB `event_idempotency` table.
- **Fix**: Store dedup state in Redis (SETNX with 5-min TTL per event ID). Fallback to in-memory if Redis unavailable.

---

### 🟡 NEW-07: Promotion — No DLQ Consumer for `orders.order.status_changed`

**File**: `promotion/internal/worker/event/event_worker.go:41–43`

**Problem**: `EventConsumersWorker` registers `ConsumeOrderStatusChanged` but there is no DLQ topic handler. If `orders.order.status_changed` events exhaust Dapr retries:
- Cancelled orders will never have `ReleasePromotionUsage` called → coupon usage leaks (over-counts remain).
- Delivered orders will never have `ConfirmPromotionUsage` called → promotions remain in `reserved` state.

- **Fix**: Add `ConsumeOrderStatusChangedDLQ` to `OrderConsumer` and register it in `EventConsumersWorker.Start`.

---

### 🔵 NEW-P2-01: `pricing.price.calculated` Published Directly (Not via Outbox)

**File**: `pricing/internal/biz/calculation/calculation.go` (referenced in checklist §3.1)

**Problem**: The `price.calculated` event is published via a direct `eventPublisher.PublishEvent` call, bypassing the outbox. If Dapr's sidecar is temporarily unavailable (pod restart, upgrade), this event is silently dropped.

- **Fix**: Either (a) write to the outbox table before publishing, or (b) make the event best-effort with an explicit warning log + metric increment on failure.

---

### 🔵 NEW-P2-02: Campaign Events Have No Known Consumer — Outbox Overhead Without Value

**File**: `promotion/internal/biz/promotion.go:595–617`

**Problem**: Campaign events (`campaign.created`, `campaign.activated`, `campaign.deactivated`, etc.) are published via the outbox. No downstream service is known to subscribe to these topics. The outbox accumulates campaign events that are never consumed, increasing DB write load.

- **Fix**: Document which service(s) are intended to consume campaign events. If none, remove campaign event publishing from the outbox (or defer to when a consumer is built).

---

## 6. GitOps Configuration Review

### 6.1 Pricing Worker (`gitops/apps/pricing/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr: `enabled=true`, `app-id=pricing-worker`, `app-port=5005`, `grpc` | ✅ |
| `securityContext: runAsNonRoot, runAsUser: 65532` | ✅ |
| `livenessProbe` + `readinessProbe` (gRPC port 5005) | ✅ |
| `resources.requests` + `resources.limits` | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| **`secretRef` for DB/Redis secret** | ❌ **[NEW-04] MISSING** |
| **`volumeMounts` for `/app/configs/config.yaml`** | ❌ **[NEW-04] MISSING** |
| **`volumes` section with ConfigMap** | ❌ **[NEW-04] MISSING** |

### 6.2 Promotion Worker (`gitops/apps/promotion/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr: `enabled=true`, `app-id=promotion-worker`, `app-port=5005`, `grpc` | ✅ |
| `securityContext: runAsNonRoot, runAsUser: 65532` | ✅ |
| `livenessProbe` + `readinessProbe` (gRPC port 5005) | ✅ |
| `resources.requests` + `resources.limits` | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| **`secretRef` for DB/Redis secret** | ❌ **[NEW-05] MISSING** |
| **`volumeMounts` for `/app/configs/config.yaml`** | ❌ **[NEW-05] MISSING** |
| **`volumes` section with ConfigMap** | ❌ **[NEW-05] MISSING** |
| HPA defined | ❌ Still missing (open P2 from Sprint 3) |

### 6.3 Pricing Main Deployment

| Check | Status |
|-------|--------|
| HTTP 8002, gRPC 9002, Dapr 8002 (HTTP) | ✅ Matches PORT_ALLOCATION_STANDARD |
| `runAsNonRoot: true, runAsUser: 65532` | ✅ |

### 6.4 Promotion Main Deployment

| Check | Status |
|-------|--------|
| HTTP 8011, gRPC 9011, Dapr 8011 (HTTP) | ✅ |
| `runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/app-protocol: http` on main | ✅ |

---

## 7. Worker & Cron Jobs Audit

### 7.1 Pricing Worker (Binary: `/app/bin/worker`)

| Worker | Type | Status |
|--------|------|--------|
| `eventbus-server` | Infrastructure | ✅ |
| `stock-consumer` | Event consumer (`stock_changed`, `low_stock`) | ✅ |
| `promo-consumer` | Event consumer (`promotion.created/updated/deleted`) | ✅ |
| `outbox-worker` | Periodic 5s | ✅ |
| `stock-changed-dlq-consumer` | DLQ drain | ❌ **[NEW-03]** Method exists, NOT registered |
| `low-stock-dlq-consumer` | DLQ drain | ❌ **[NEW-03]** Method exists, NOT registered |
| `promo-dlq-consumer` | DLQ drain (3 topics) | ❌ **[NEW-03]** Method exists, NOT registered |

### 7.2 Promotion Worker (Binary: `/app/bin/worker`)

| Worker | Type | Status |
|--------|------|--------|
| `outbox-worker` | Periodic 30s | ✅ Running — see [NEW-02] for max_retries mismatch |
| `event-consumers` | Event consumer (`order.status_changed`) | ✅ |
| `order-status-dlq-consumer` | DLQ drain | ❌ **[NEW-07]** Not implemented |

---

## 8. Edge Cases Not Yet Handled

| Edge Case | Risk | Note |
|-----------|------|------|
| **Pricing DLQ events accumulate → promo discount table diverges** | 🔴 P0 | [NEW-03] — No DLQ drain; local discount mirror silently stale |
| **Pod restart invalidates stock event dedup → duplicate pricing triggers** | 🟡 P1 | [NEW-06] — in-memory sync.Map lost on restart |
| **Promotion outbox `max_retries` mismatch: code=10, DB filter=5** | 🟡 P1 | [NEW-02] — Events retry_count 5–9 silently stuck |
| **`order.status_changed` DLQ → promotion usage never confirmed/released** | 🟡 P1 | [NEW-07] — Coupon usage leak or stuck reservations |
| **`price.calculated` event dropped if Dapr sidecar unavailable** | 🔵 P2 | [NEW-P2-01] — Direct publish, not outbox |
| **Campaign events published to outbox with no known consumer** | 🔵 P2 | [NEW-P2-02] — Unnecessary DB write overhead |
| **Currency conversion flag missing on response** | 🔵 P2 | E4 (prior) — Caller can't detect converted rate |
| **Dynamic pricing errors swallowed silently** | 🔵 P2 | E5 (prior) — No metric/alert on fallback |
| **Price rule tiebreaker non-deterministic at same `CreatedAt`** | 🔵 P2 | E6 (prior) — Add secondary sort by ID |
| **Free shipping discount returns $0 discount — checkout reads wrong field** | 🔵 P2 | E13 (prior) — Must read `ShippingDiscount` not `TotalDiscount` |
| **Promotion budget not validated for active status before increment** | 🔵 P2 | E15 (prior) — Campaign deactivated mid-apply |
| **Tax returns `(0, nil, nil)` when no rules match** | 🔵 P2 | E17 (prior) — Ambiguous zero-tax vs. no-config |

---

## 9. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix Before Release

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-03]** | Pricing: `ConsumeStockUpdateDLQ`, `ConsumeLowStockDLQ`, `ConsumePromoDLQ` NOT registered in `workers.go` — promo discount table silently diverges | Add 3 DLQ worker structs + append to `NewWorkers` return slice |
| **[NEW-04]** | Pricing `worker-deployment.yaml`: missing `secretRef` + `volumeMounts` + `volumes` — binary fails to load config.yaml; no secrets injected | Add `secretRef: pricing-secret`, `volumes`, `volumeMounts` blocks (reference: `search/base/worker-deployment.yaml`) |
| **[NEW-05]** | Promotion `worker-deployment.yaml`: same missing `secretRef` + `volumeMounts` + `volumes` | Same fix as above with `secretRef: promotion-secret` |

### 🟡 P1 — Fix in Next Sprint

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-02]** | Promotion outbox `max_retries`: code hardcodes 10, DB migration sets 5 — events with retry_count 5–9 silently stuck | Change `const maxRetries = 10` → `5` in `outbox_worker.go:119` |
| **[NEW-06]** | Pricing stock consumer: in-memory dedup lost on pod restart → duplicate dynamic pricing | Replace `sync.Map` dedup with Redis `SET NX EX 300` per event ID |
| **[NEW-07]** | Promotion: no DLQ consumer for `order.status_changed` → coupon usage leak or stuck reservations | Implement `ConsumeOrderStatusChangedDLQ` and register in `EventConsumersWorker.Start` |
| **[NEW-01]** | Same pattern: pricing stock consumer in-memory idempotency for `lastSeqMap` (sequence tracking) also lost on restart | Same Redis-backed fix as above |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-P2-01]** | `pricing.price.calculated` published direct (not outbox) — lost if Dapr unavailable | Move to outbox or add error metric/log on publish failure |
| **[NEW-P2-02]** | Campaign events published to outbox with no documented consumer | Document consumer or remove publishing until consumer exists |
| **E4** | Currency conversion flag missing on price response | Add `IsCurrencyConverted bool` to `Price` response struct |
| **E5** | Dynamic pricing errors swallowed silently | Add Prometheus counter + WARN log on fallback |
| **E6** | Price rule tiebreaker non-deterministic at same `CreatedAt` | Add secondary sort by rule `id` |
| **E13** | Free shipping discount — checkout must read `ShippingDiscount`, not `TotalDiscount` | Document in checkout service; add assertion in validation response |
| **Promotion HPA** | No HPA for promotion service (main + worker) | Add HPA yaml to `gitops/apps/promotion/overlays/production/` |

---

## 10. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Pricing outbox: `FOR UPDATE SKIP LOCKED` | `data/postgres/price.go:119–136` |
| Pricing outbox as `ContinuousWorker` | `biz/worker/outbox.go` implements interface; wired in worker binary |
| Promotion per-customer usage enforcement | `validation.go:271–281` — `GetUsageByCustomer` called per validation |
| Campaign deactivation emits per-promotion events | `promotion.go:607–617` — individual `promotion.deactivated` outbox events |
| Outbox cleanup (7-day retention) | Both pricing and promotion workers |
| Promo DLQ drain handlers defined | `promo_consumer.go:142–168`, `stock_consumer.go:169–198` |
| Promotion outbox max-retry SQL filter | `data/outbox.go:67` — `WHERE retry_count < max_retries` |
| Stock consumer sequence-based staleness guard | `stock_consumer.go:116–124` — `lastSeqMap` tracks per `productID:warehouseID` |
| Schema validator on consumers (warning-level) | Both stock and promo consumers call `schemaValidator.Validate*` |
| Promotion `ConsumeOrderStatusChanged` registered | `event_worker.go:41–43` |
| Tax: compound tax rules, inclusive/exclusive, per-category | `tax.go:144–306` |
| Tax cache invalidation includes category wildcard | `tax.go:370–378` |

---

## Related Files

| Document | Path |
|----------|------|
| Catalog flow checklist | [catalog-product-flow-checklist.md](catalog-product-flow-checklist.md) |
| Search flow checklist | [search-discovery-flow-review.md](search-discovery-flow-review.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

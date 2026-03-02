# Analytics & Reporting Flow — Business Logic Review Checklist

**Date**: 2026-02-21
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `analytics/` service — event ingestion, aggregation, reporting, real-time, A/B testing, data quality

> Based on: `ecommerce-platform-flows.md` section 14, direct code review of `analytics/internal/`

---

## 1. Architecture Overview

```
All upstream services (order, checkout, catalog, customer, payment, warehouse, return...)
    ↓ Dapr PubSub events
Analytics service (/events/orders|products|customers|page-views|fulfillment|shipping|dlq)
    ↓ processEventByType
analyticsRepo (PostgreSQL) + metricsRepo (Redis cache)
    ↑ MetricsRepository.AggregateDaily / AggregateHourly / RefreshMaterializedViews
API layer (HTTP/gRPC) → Dashboard, Revenue, Orders, Products, Customer, Return/Refund, A/B, Data Quality, Alerts, Custom Reports
```

---

## 2. Data Consistency Between Services

| Data Source | Analytics Receives Via | Stored As | Status |
|-------------|----------------------|-----------|--------|
| Order created/updated/cancelled | Dapr HTTP push `/events/orders` | Processed event + cache invalidation | ⚠️ **STUB** — no real aggregation write |
| Product viewed/purchased | Dapr HTTP push `/events/products` | Processed event + cache invalidation | ⚠️ **STUB** |
| Customer registered/updated | Dapr HTTP push `/events/customers` | Processed event + cache invalidation | ⚠️ **STUB** |
| Page view / session start / end | Dapr HTTP push `/events/page-views` | Cache invalidation only | ⚠️ **STUB** |
| Fulfillment events | Dapr HTTP push `/events/fulfillment` | EventProcessor.ProcessFulfillmentEvent | Needs verify |
| Shipping events | Dapr HTTP push `/events/shipping` | EventProcessor.ProcessShippingEvent | Needs verify |
| Cart converted | `checkout.cart.converted` (outbox) | Not handled in event type switch | ❌ **Missing** event type |
| Return completed | `return.completed` (direct Dapr) | Not handled | ❌ **Missing** |
| Payment confirmed | Not listed in routes | Not handled | ❌ **Missing** |
| Promotion applied | Not listed | Not handled | ❌ |
| Stock changed | Not listed | Not handled | ❌ |

---

## 3. Critical Code Gaps Found

### 3.1 P0 — `processOrderEvent` / `processProductEvent` / `processCustomerEvent` are STUBS

**Status**: ❌ **Not Implemented**

```go
// event_processing_usecase.go:237-265
func (uc *eventProcessingUseCase) processOrderEvent(ctx context.Context, event *AnalyticsEvent) error {
    // Only validates order_id and invalidates caches
    // Does NOT write to any analytics table (GMV, order count, AOV, etc.)
    uc.metricsRepo.InvalidateCache(ctx, "analytics:order:*")
    uc.metricsRepo.InvalidateCache(ctx, "analytics:revenue:*")
    return nil
}
```

- `processOrderEvent` validates `order_id` exists and invalidates caches — **does not write order data**
- `processProductEvent` validates `product_id` and invalidates caches — **does not write product analytics**
- `processCustomerEvent` validates `user_id` and invalidates caches — **does not write customer metrics**
- `processGenericEvent` saves to raw events table only — no dimension population

**Impact**: All analytics dashboard data is read from either:
1. Pre-aggregated PostgreSQL tables (via `AggregateDaily`/`AggregateHourly` crons — but no worker found)
2. Direct DB queries that scan raw events or other service DBs

If aggregation crons don't run, ALL report data is stale or empty: `GetRevenueAnalytics`, `GetOrderAnalytics`, `GetProductPerformance`, `GetCustomerAnalyticsSummary` all query materialized/aggregated tables that are never populated via events.

---

### 3.2 P0 — No Worker/Cron for Aggregation Jobs

`MetricsRepository` interface defines:
```go
AggregateDaily(ctx context.Context, date string) error
AggregateHourly(ctx context.Context, hour string) error
RefreshMaterializedViews(ctx context.Context) error
```

But:
- **No cron worker found** in `analytics/internal/` for any of these
- GitOps has **no worker-deployment.yaml** — no separate aggregation pod
- The `analytics` binary runs only the API server + event handlers
- `AggregateDaily` / `AggregateHourly` are defined in the repository layer but never called

**Impact**: Daily/hourly GMV, order count, revenue aggregations are **never computed**. All historical reports show stale or zero data.

---

### 3.3 P0 — Event Type Coverage Gap

`processEventByType` (event_processing_usecase.go:220-234) handles only **13 event types**:
```go
"order_created", "order_updated", "order_cancelled"
"product_viewed", "product_purchased"
"customer_registered", "customer_updated"
"inventory_updated"
"page_view", "session_start", "session_end"
```

Missing event types from upstream services:
| Missing Event | Source Service | Impact |
|---------------|---------------|--------|
| `payment.confirmed` | Payment (webhook) | Revenue analytics miss successful payment data |
| `payment.failed` | Payment | Payment success rate metric unavailable |
| `checkout.cart.converted` | Checkout (outbox) | Cart abandonment rate missing (cart that didn't convert) |
| `catalog.product.created/updated/deleted` | Catalog | Product catalog analytics stale |
| `return.requested/approved/completed` | Return | Return rate by category never updated |
| `warehouse.stock.changed` | Warehouse | Inventory analytics missing real-time stock |
| `promotion.applied` | Promotion (via checkout) | Promotion analytics never updated |
| `fulfillment.shipped/delivered` | Fulfillment | SLA compliance never tracked |
| `customer.reviewed` | Review | Product review analytics missing |

---

## 4. Event Publishing & Subscription Audit

### 4.1 Analytics Service — Does it publish events?

**No**. Analytics is a pure sink service — it only consumes events and serves queries. Correct.

### 4.2 Events Analytics Should Subscribe To (vs. what it currently handles)

| Service | Current Subscription | Status |
|---------|---------------------|--------|
| Order → `order.status.changed` | `/events/orders` registered | ⚠️ Handler stub only |
| Checkout → `checkout.cart.converted` | ❌ Not registered | GMV/conversion miss |
| Payment → `payment.confirmed` | ❌ Not registered | Revenue accuracy |
| Catalog → `catalog.product.*` | ❌ Not registered | Product catalog analytics |
| Return → `return.completed` | ❌ Not registered | Return rate analytics |
| Warehouse → `warehouse.stock.changed` | ❌ Not registered | OOS/inventory analytics |
| Promotion → usage events | ❌ Not registered | Promo effectiveness |
| Fulfillment → ship/deliver events | `/events/fulfillment` registered | ⚠️ Need to verify handler |
| Search → query events | ❌ Not registered | Search analytics (section 14.4) |

### 4.3 What Other Services Should NOT Emit to Analytics (but currently might)

- Analytics should not subscribe to `return.refund_retry` / `return.restock_retry` — these are internal compensation events, not analytics-relevant.

---

## 5. Data Mismatch Risks

### 5.1 Real-Time Metrics vs. Aggregated Reports

`GetRealTimeMetrics` queries a separate real-time table; `GetRevenueAnalytics` queries aggregated tables. If:
- Real-time writes from events succeed
- But `AggregateDaily` never runs

Then **real-time dashboard shows activity**, but **daily/weekly revenue reports show zero/stale**.

*Shopify pattern*: Separate streaming pipeline (Kafka → ClickHouse) for real-time; nightly ETL batch for reports. Both must reconcile.

### 5.2 Cart Abandonment Rate — Incomplete Signal

`ecommerce-platform-flows.md` section 14.1 lists **cart abandonment rate** as a key real-time metric.

Current implementation:
- `cart_cleanup.go` marks expired carts as inactive
- But no event is fired when a cart expires (abandoned)
- Analytics service has no handler for abandoned cart events
- `checkout.cart.converted` is also not subscribed

→ **Cart abandonment rate = total carts started - converted carts** — both inputs missing.

### 5.3 Revenue Data Source Mismatch

`GetRevenueData` (repo_revenue.go) queries from internal analytics DB. But orders are created in the **Order service DB**, payments confirmed in the **Payment service DB**. Analytics DB is only populated when aggregation runs. If data pipeline breaks → analytics revenue diverges from actual order/payment data.

*Lazada/Shopee pattern*: Revenue is computed from payment confirmed events, not order created — avoids counting unfulfilled/cancelled orders in GMV.

---

## 6. Retry & DLQ Audit

### 6.1 Event Health — DLQ Handler (SG-11 Fix)

`/events/dlq` route correctly persists Dapr DLQ events to `dead_letter_queue` table. ✅

### 6.2 Internal DLQ After Max Retries

`ProcessIncomingEvent` sends to DLQ after `RetryCount >= MaxRetries (3)`. ✅

But: **DLQ events have no replay mechanism**. `ResolveDeadLetterQueueEvent` marks as resolved but does not re-process. Manual replay is the only option.

### 6.3 processOrderEvent Failures Are Silent

`processOrderEvent` currently only invalidates cache. If cache invalidation fails, no retry, no DLQ — event is marked `completed` even though analytics tables were not updated.

→ If cache invalidation fails during high-traffic periods, analytics serves **stale data** with no alerting.

---

## 7. Business Logic Edge Cases (Shopify/Shopee/Lazada Patterns)

### 7.1 Real-Time Metrics Gaps (section 14.1)

- [ ] **Live GMV**: Requires `payment.confirmed` events — currently not subscribed. GMV may be calculated from `order_created` (counts unconfirmed/cancelled orders as revenue).
- [ ] **Cart abandonment rate**: Both `cart.started` AND `cart.converted` events needed — neither subscribed.
- [ ] **Payment success rate**: `payment.confirmed` + `payment.failed` both absent from subscription list.
- [ ] **Out-of-stock rate**: `warehouse.stock.changed` not subscribed — OOS rate cannot be tracked.
- [ ] **Active user count (DAU/MAU)**: `session_start/end` handled but stub only — active user counters in real-time table may not be incremented.

### 7.2 Business Reports Gaps (section 14.2)

- [ ] **Daily GMV**: Requires `AggregateDaily` cron — **cron not deployed in GitOps**.
- [ ] **Revenue by category/brand/seller**: Requires order items with category/brand metadata in events — `order_created` event schema unclear if it includes category breakdown.
- [ ] **Return rate by category**: Requires `return.completed` event subscription — missing.
- [ ] **Seller performance scorecard**: No seller-dimension in any event handler.
- [ ] **Payout reconciliation**: No payment service events subscribed.
- [ ] **Tax report by jurisdiction**: No tax information in analytics event handlers.

### 7.3 Customer Analytics Gaps (section 14.3)

- [ ] **Funnel analysis** (landing→PDP→cart→checkout→order): `page_view` + `session_*` handled as stubs. `checkout.cart.converted` missing. Funnel data incomplete.
- [ ] **Cohort retention**: Requires `customer_registered` + purchase events over time — both present but stubs.
- [ ] **CLV/RFM segmentation**: `CustomerJourneyUseCase` interface exists (✅ well-designed) but data feeding it comes from stubs.
- [ ] **A/B test analysis**: `ABTestingUseCase` fully designed with `StartABExperiment`, `TrackABExperimentEvent`. But `TrackABExperimentEvent` requires frontend to emit events — no event handler route registered for A/B events.

### 7.4 Operational Analytics Gaps (section 14.4)

- [ ] **Fulfillment SLA compliance**: `/events/fulfillment` route exists but needs `fulfillment.shipped_at` vs `order.placed_at` comparison — unclear if event payload includes both timestamps.
- [ ] **Carrier performance**: `GetShippingAnalytics` defined but data relies on `warehouse.stock.changed` events not subscribed.
- [ ] **Support ticket resolution time**: No support/ticket service integration in analytics.

---

## 8. GitOps Configuration Review

### 8.1 Analytics Service (`gitops/apps/analytics/base/deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr enabled, app-id `analytics`, port 8019, HTTP | ✅ |
| secretRef: `analytics-secrets` | ✅ |
| envFrom: `overlays-config` | ✅ |
| startupProbe (failureThreshold=30, period=10s, timeout=5s) | ✅ Generous threshold for cold start |
| livenessProbe (delay=30s, period=10s) | ✅ |
| readinessProbe (delay=5s, period=5s) | ✅ |
| securityContext non-root (runAsUser=65532) | ✅ |
| revisionHistoryLimit: 1 | ✅ |
| **config volumeMount** (`/app/configs/config.yaml`) | ❌ **MISSING** — runs `-conf /app/configs/config.yaml` but no volume mounted |
| **worker-deployment.yaml** | ❌ **MISSING** — no separate aggregation/cron pod |
| **HPA for analytics API** | ❌ **MISSING** — analytics may receive burst of events during flash sale, single replica |

### 8.2 Aggregation Cron — No GitOps Deployment

`AggregateDaily`, `AggregateHourly`, `RefreshMaterializedViews` are interfaces defined but:
1. No cron worker Go file found in `analytics/internal/`
2. No Kubernetes `CronJob` in GitOps for daily aggregation
3. No `worker-deployment.yaml` for a continuous aggregation pod

**Impact**: All historical analytics (GMV, revenue, product performance) depend on these aggregations but they never run.

---

## 9. Workers & Cron Jobs Audit

### 9.1 Current Workers in Analytics Service

| Worker | Type | File | Status |
|--------|------|------|--------|
| Event HTTP handlers | HTTP server endpoints | `handler/event_handler.go` | ✅ Registered, stubs |
| DLQ handler | HTTP endpoint `/events/dlq` | `handler/event_handler.go:167` | ✅ |
| **AggregateDaily cron** | ❌ Not found | N/A | ❌ Missing implementation |
| **AggregateHourly cron** | ❌ Not found | N/A | ❌ Missing implementation |
| **RefreshMaterializedViews cron** | ❌ Not found | N/A | ❌ Missing implementation |
| Alert condition checker | Interface: `CheckAlertConditions` | `alert_usecase.go` | ⚠️ No cron trigger found |
| Data quality runner | Interface: `ExecuteDataQualityCheck` | `data_quality_usecase.go` | ⚠️ Manual API only |
| Scheduled custom report runner | Interface: `ScheduleReport` | `custom_report_usecase.go` | ⚠️ No cron trigger |

### 9.2 Dapr Subscription Topics Analytics Currently Listens To

Based on `SetupEventRoutes`:
- `/events/orders` → order events
- `/events/products` → product events
- `/events/customers` → customer events
- `/events/page-views` → page view events
- `/events/fulfillment` → fulfillment events
- `/events/shipping` → shipping events
- `/events/dlq` → DLQ endpoint

**Missing subscriptions**: `checkout.cart.converted`, `payment.confirmed`, `payment.failed`, `catalog.product.*`, `return.completed`, `warehouse.stock.changed`, `promotion.applied`

---

## 10. Summary: Issue Priority Matrix

### 🔴 P0 — Critical (Analytics Produces Wrong/Empty Data)

| Issue | Description | Action | Status |
|-------|-------------|--------| ------|
| **ANLT-P0-001** | `processOrderEvent` / `processProductEvent` / `processCustomerEvent` are stubs — no analytics data written on event receipt. All analytics tables stay empty/stale. | Implement actual DB writes in each `processXxxEvent` method | ✅ Already implemented in `service/event_processor.go` — uses `SaveEvent` |
| **ANLT-P0-002** | `AggregateDaily` / `AggregateHourly` / `RefreshMaterializedViews` interfaces exist but **no cron worker** calls them — daily/weekly/monthly reports never aggregate. | Create `AggregationWorker` cron (daily + hourly intervals) AND add `worker-deployment.yaml` to GitOps | ✅ **DONE** — `internal/worker/cron/aggregation_cron.go` + `cmd/worker/` + `gitops/apps/analytics/base/worker-deployment.yaml` |
| **ANLT-P0-003** | `payment.confirmed` not subscribed — **GMV dashboard counts unconfirmed orders** (from `order_created`). Revenue figures systematically overstated. | Register Dapr subscription for `payment.confirmed`; use payment-confirmed amount as GMV | ✅ **DONE** — `ProcessPaymentEvent` + `/events/payments` route |
| **ANLT-P0-004** | `checkout.cart.converted` not subscribed — **cart abandonment rate cannot be computed**. One of the top 3 e-commerce metrics (section 14.1) permanently unavailable. | Subscribe to `checkout.cart.converted`; track `cart_converted` vs `cart_created` delta | ✅ **DONE** — `ProcessCartConvertedEvent` + `/events/cart` route |

### 🟡 P1 — High Priority

| Issue | Description | Action | Status |
|-------|-------------|--------| ------|
| **ANLT-P1-001** | `return.completed` not subscribed — return rate by category (section 14.2) never computed | Add `/events/returns` Dapr subscription | ✅ **DONE** — `ProcessReturnEvent` + `/events/returns` route |
| **ANLT-P1-002** | No HPA configured for analytics API — single replica under flash-sale event burst may drop events | Add HPA (min=2, max=8) for analytics deployment | ✅ **DONE** — `hpa.yaml` enabled in `kustomization.yaml` |
| **ANLT-P1-003** | DLQ events have no replay — `ResolveDeadLetterQueueEvent` marks resolved but data is never recovered | Implement `RetryDeadLetterQueueEvent` to re-emit events through `processEventByType` | ✅ **DONE** — `RetryDeadLetterEvent` added to `eventProcessingUseCase` |
| **ANLT-P1-004** | `AlertUseCase.CheckAlertConditions` has no cron trigger — alert thresholds (e.g., OOS rate > 10%, payment failure > 5%) are never evaluated automatically | Add `AlertCheckerCron` running every 5 minutes | ✅ **DONE** — `internal/worker/cron/alert_checker_cron.go` |
| **ANLT-P1-005** | `RefreshMaterializedViews` is NOT called by any cron — reports served from materialized views show stale data after view refresh window elapses | Add materialized view refresh (every 1 hour, configurable) | ✅ **DONE** — called inside hourly loop in `AggregationCronJob` |
| **ANLT-P1-006** | Missing config volumeMount — `analytics` binary reads `-conf /app/configs/config.yaml` but no volume is mounted | Add volume + volumeMount for config ConfigMap | ✅ **DONE** — `analytics-config.yaml` + volumeMount in `deployment.yaml` + `worker-deployment.yaml` |

### 🔵 P2 — Roadmap / Tech Debt

| Issue | Description | Action |
|-------|-------------|--------|
| **ANLT-P2-001** | `warehouse.stock.changed` not subscribed — OOS rate metric unavailable | Add `/events/inventory` Dapr subscription |
| **ANLT-P2-002** | No A/B test event tracking route registered — `TrackABExperimentEvent` needs frontend events | Add `/events/ab-test` route; integrate with frontend SDK |
| **ANLT-P2-003** | Cart abandonment requires both `cart.started` (Checkout StartCheckout log) and `cart.converted` events — only latter partially subscribed | Emit `checkout.cart.started` event from checkout; subscribe in analytics |
| **ANLT-P2-004** | Funnel analysis (section 14.3) requires ordered session events with user stitching — current `session_start/end` are stubs | Implement session → cart → checkout → order funnel tracking using journey events |
| **ANLT-P2-005** | `DataQualityUseCase.ExecuteDataQualityCheck` is API-triggered only — data quality checks should run on a schedule | Add `DataQualityCron` daily execution |
| **ANLT-P2-006** | `ScheduleReport` interface exists but no scheduler executes it — custom reports set to "scheduled" never auto-run | Add `ReportSchedulerCron` |
| **ANLT-P2-007** | Real-time metrics `UpdateRealTimeMetrics` called by `RealTimeDashboardUseCase` — but no heartbeat cron triggers it periodically | Add `RealTimeMetricsRefreshCron` (every 30s) |
| **ANLT-P2-008** | Event ID generation falls back to SHA256 of full event payload (including timestamps) — same logical event at different times gets different hash, causing duplicates in analytics | Use stable dedup key: `source_service + entity_type + entity_id + event_type` only |
| **ANLT-P2-009** | Revenue computed from `order_created` events (which include cancelled orders) — should be from `payment.confirmed` | Switch GMV source to `payment.confirmed` events for accuracy |
| **EDGE-01** | Flash-sale event burst: 10K orders/min → 10K Dapr events/min → analytics HTTP handler → single PostgreSQL INSERT per event → DB connection pool exhaustion | Use `BatchSaveEvents` (already defined in repo interface) with in-memory buffer |
| **EDGE-02** | `IsEventDuplicate` checks data hash but hash includes `user_id` and session data without timestamp — two different events with same user/product data at different times deduplicated incorrectly | Include `event_time` (floored to second) in dedup hash |
| **EDGE-03** | No seller / marketplace dimension in analytics — multi-seller platform needs `GetSellerPerformance` analytics | Add seller_id dimension to order/product analytics tables |
| **EDGE-04** | Tax report by jurisdiction (section 14.2) — no tax data in any analytics event payload | Include `tax_amount`, `tax_jurisdiction` in `order_created` event; add to analytics schema |

---

## 11. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| CloudEvent envelope parsing (SG-7 fix) | `event_handler.go:30-80` — full `DaprCloudEvent` struct with ID, source, type, traceParent |
| Event dedup via ID + data hash | `event_processing_usecase.go:42-65` — two-level dedup |
| DLQ handler persisted to DB (SG-11 fix) | `event_handler.go:167-218` — persists failed events even on parse error |
| Max retry → DLQ promotion | `event_processing_usecase.go:122-124` — `MaxRetries=3` before DLQ |
| Rich interface design (35 use cases) | `interfaces.go` — covers all platform analytics needs |
| `BatchSaveEvents` for high-volume ingestion | `interfaces.go:334` — multi-row INSERT available |
| Customer journey touchpoint model | `customer_journey_usecase.go` — multi-touch attribution, funnel paths |
| A/B experiment lifecycle management | `ab_testing_usecase.go` — start/stop/results/tracking |
| Data quality monitoring framework | `data_quality_usecase.go` — checks, results, summary |
| Alert definition and condition check | `alert_usecase.go` — definition CRUD + `CheckAlertConditions` |
| Predictive analytics model lifecycle | `recommendation_usecase.go` + `realtime_models.go` — train/deploy/forecast |
| Dapr HTTP protocol (not gRPC) for event ingestion | `deployment.yaml:27` — `dapr.io/app-protocol: http` — correct for HTTP handlers |
| Startup probe generous failureThreshold=30 | `deployment.yaml:73` — allows slow cold DB connection |
| secretRef present | `deployment.yaml:54-55` — `analytics-secrets` |

---

## Related Files

| Document | Path |
|----------|------|
| Return & Refund flow checklist | [return-refund-flow-checklist.md](return-refund-flow-checklist.md) |
| Cart & Checkout flow checklist | [cart-checkout-flow-checklist.md](cart-checkout-flow-checklist.md) |
| Catalog & Product flow checklist | [catalog-product-flow-checklist.md](catalog-product-flow-checklist.md) |
| Customer & Identity flow checklist | [customer-identity-flow-checklist.md](customer-identity-flow-checklist.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

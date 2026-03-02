# Analytics & Reporting Flow — Business Logic Review v2

**Date**: 2026-02-26  
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)  
**Scope**: `analytics/` service — event ingestion, aggregation, reporting, real-time, worker, GitOps  
**Baseline**: Previous checklist `analytics-reporting-review.md` (2026-02-21)

> This is a delta review against the first checklist. Many P0/P1 issues from the original review have been fixed.

---

## 1. Architecture Summary (Current State)

```
Upstream Services (order, payment, checkout, shipping, fulfillment, return...)
    ↓ Dapr PubSub events (HTTP-based subscriptions)
Analytics Server (cmd/server)
    ├─ /events/orders        → orders.order.status_changed
    ├─ /events/payments      → payment.payment.processed/failed/refunded ✅
    ├─ /events/shipping      → shipping.shipment.status_changed ✅
    ├─ /events/page-views    → analytics.page_view
    ├─ /events/returns       → orders.return.requested/approved/rejected/completed ✅
    ├─ /events/fulfillment   → fulfillments.fulfillment.status_changed/sla_breach ✅
    ├─ /events/cart           → cart.converted                ✅
    └─ /events/dlq           → DLQ catch-all (13 DLQ topics)
    ↓ EventProcessor → SaveEvent → PostgreSQL
    ↓ ProcessedEvent tracking (idempotency)

Analytics Worker (cmd/worker) — deployed via worker-deployment.yaml ✅
    ├─ AggregationCronJob    → daily/hourly aggregation + mat views (exclusive)
    └─ AlertCheckerCronJob   → alert conditions every 5m

API Layer (HTTP/gRPC) → Dashboard, Revenue, Orders, Products, Returns, etc.
```

---

## 2. Data Consistency Between Services

| Data Source | Analytics Receives Via | Topic | Status |
|-------------|----------------------|-------|--------|
| Order status changes | Dapr sub → `/events/orders` | `orders.order.status_changed` | ✅ Implemented — EventProcessor.ProcessOrderEvent |
| Payment events | Dapr sub → `/events/payments` | `payment.payment.processed/failed/refunded` | ✅ **FIXED** — payload schema aligned |
| Shipment status changes | Dapr sub → `/events/shipping` | `shipping.shipment.status_changed` | ✅ **FIXED** |
| Page views | Dapr sub → `/events/page-views` | `analytics.page_view` | ✅ |
| Cart conversions | Dapr sub (HTTP) | `cart.converted` | ✅ **FIXED** |
| Return events | Dapr sub → `/events/returns` | `orders.return.requested/approved/rejected/completed` | ✅ **FIXED** — payload schema aligned |
| Fulfillment events | Dapr sub → `/events/fulfillment` | `fulfillments.fulfillment.status_changed/sla_breach` | ✅ **FIXED** — SLA breach mapping added |
| Promotion usage | Not subscribed | — | ❌ Missing (P2) |
| Warehouse stock changes | Not subscribed | — | ❌ Missing (P2) |
| Catalog product changes | Not subscribed | — | ❌ Missing (P2) |

---

## 3. Critical Findings (Issues)

### 3.1 🔴 P0 — Dapr Subscription YAML Missing for Returns, Fulfillment, Cart (HTTP)

**Status**: ✅ **FIXED** — all subscriptions added to `dapr/subscription.yaml` and `subscription-dlq.yaml`

The server binary registers HTTP routes for events:
- `/events/returns` → `HandleReturnEvents`
- `/events/fulfillment` → `HandleFulfillmentEvents`
- `/events/cart` → `HandleCartConvertedEvents`

But `dapr/subscription.yaml` **does not declare** subscriptions for:
- ANY return topic (e.g., `orders.return.requested`, `orders.return.completed`)
- ANY fulfillment topic (e.g., `fulfillments.fulfillment.status_changed`)
- `cart.converted` topic (only handled via gRPC consumer in worker)

**`dapr/subscription.yaml` only has 4 topics:**
1. `orders.order.status_changed` → `/events/orders`
2. `payments.payment.confirmed` → `/events/orders` ← routes to order handler!
3. `shipping.shipment.status_changed` → `/events/orders` ← routes to order handler!
4. `analytics.page_view` → `/events/page-views`

**Impact**:
- Return analytics data (`ProcessReturnEvent`) is **never triggered** — no Dapr subscription routes return events to the analytics server
- Fulfillment analytics (`ProcessFulfillmentEvent`) is **never triggered**
- Payment events route to `/events/orders` instead of `/events/payments` — **wrong handler invoked**
- Shipping events route to `/events/orders` instead of `/events/shipping` — **wrong handler invoked**

**Source service topics to subscribe to:**
| Source | Topic | Target Route |
|--------|-------|-------------|
| Return | `orders.return.requested` | `/events/returns` |
| Return | `orders.return.approved` | `/events/returns` |
| Return | `orders.return.completed` | `/events/returns` |
| Fulfillment | `fulfillments.fulfillment.status_changed` | `/events/fulfillment` |
| Checkout | `cart.converted` | `/events/cart` |

---

### 3.2 🔴 P0 — Payment & Shipping Dapr Subs Route to Wrong Handler

**Status**: ✅ **FIXED** — payment routes to `/events/payments`, shipping routes to `/events/shipping`

In `dapr/subscription.yaml`:
```yaml
# subscription name: analytics-payment-confirmed
topic: payments.payment.confirmed
routes:
  default: /events/orders    # ← WRONG! Should be /events/payments

# subscription name: analytics-shipment-status-changed
topic: shipping.shipment.status_changed
routes:
  default: /events/orders    # ← WRONG! Should be /events/shipping
```

- `payments.payment.confirmed` → `/events/orders` → calls `HandleOrderEvents` → tries to parse as order event → **likely parse failure → DLQ**
- `shipping.shipment.status_changed` → `/events/orders` → calls `HandleOrderEvents` → **same problem**

These subscriptions exist but route to the wrong handler, meaning payment and shipping analytics data is silently lost or sent to DLQ.

---

### 3.3 🔴 P0 — Payment Topic Mismatch

**Status**: ✅ **FIXED** — subscription topic changed to `payment.payment.processed`

| What | Topic |
|------|-------|
| Payment service publishes | `payment.payment.processed` |
| Analytics subscribes to | `payments.payment.confirmed` |

**The payment service does NOT publish `payments.payment.confirmed`**. It publishes:
- `payment.payment.processed`
- `payment.payment.failed`
- `payment.payment.refunded`
- `payment.payment.captured`
- `payment.payment.voided`

Analytics subscribes to `payments.payment.confirmed` which **does not exist**. Revenue/GMV data from payment events is completely lost.

---

### 3.4 🟡 P1 — No Worker Deployment in GitOps

**Status**: ✅ **FIXED** — `gitops/apps/analytics/base/worker-deployment.yaml` created and added to `kustomization.yaml`

The analytics worker binary runs:
- `AggregationCronJob` (daily/hourly aggregation)
- `AlertCheckerCronJob` (5-minute alert checks)

Worker deployment uses `analytics-worker` Dapr app-id with gRPC protocol, Dapr-annotated, with initContainers for Redis/PostgreSQL readiness.

---

### 3.5 🟡 P1 — `data_quality_usecase.go` Has `//go:build ignore`

**Status**: ✅ **FIXED** — `//go:build ignore` tag removed, file now compiles normally.

---

### 3.6 🟡 P1 — Cart Consumer: Dual-Path Ingestion Without Coordination

**Status**: ✅ **FIXED** — resolved by removing the gRPC `CartConsumerWorker` from the worker binary.

Cart events now flow exclusively via the HTTP path:
- Dapr subscription `cart.converted` → `/events/cart` → `ProcessCartConvertedEvent`

The HTTP handler provides richer processing (cart_id, session_id, cache invalidation, proper metadata) compared to the generic `ProcessIncomingEvent` path.

---

### 3.7 🟡 P1 — Fulfillment/Shipping Event Processors Lack Idempotency

**Status**: ✅ **FIXED** — both handlers now implement the full idempotency flow:
- `event_id` extraction from raw payload
- `IsEventProcessed` check before processing
- `CreateProcessedEvent` after successful save
- `trackEventSequence` for out-of-order detection
- `extractTraceID` for W3C trace propagation
- Cache invalidation on success

---

## 4. Event Publishing & Subscription Audit

### 4.1 Does Analytics Need to Publish Events?

**No**. Analytics is a pure sink/read service. It only consumes events and serves queries via API. This is correct — matches Shopify/Shopee pattern where analytics is a downstream consumer.

### 4.2 Does Analytics Need to Subscribe to Events?

**Yes**. Analytics MUST subscribe to events from upstream services. Current state:

| Source Service | Published Topic | Dapr Sub Exists? | Correct Route? | Handler Exists? |
|----------------|----------------|-----------------|----------------|-----------------|
| Order | `orders.order.status_changed` | ✅ | ✅ `/events/orders` | ✅ |
| Payment | `payment.payment.processed` | ❌ Topic mismatch | N/A | ✅ (but wrong topic) |
| Shipping | `shipping.shipment.status_changed` | ✅ | ❌ Routes to `/events/orders` | ✅ |
| Checkout | `cart.converted` | ❌ No HTTP sub | N/A | ✅ (only gRPC worker) |
| Frontend/SDK | `analytics.page_view` | ✅ | ✅ `/events/page-views` | ✅ |
| Return | `orders.return.requested/completed` | ❌ | N/A | ✅ |
| Fulfillment | `fulfillments.fulfillment.status_changed` | ❌ | N/A | ✅ |
| Warehouse | stock events | ❌ | N/A | ❌ |
| Catalog | product CRUD events | ❌ | N/A | ❌ |
| Promotion | promotion events | ❌ | N/A | ❌ |

### 4.3 Services That Publish Events Analytics Should Consume (Verified)

| Service | Topic(s) Published | Uses Outbox? | Analytics Should Subscribe? |
|---------|-------------------|-------------|---------------------------|
| Order | `orders.order.status_changed` | ✅ Yes | ✅ Currently subscribed |
| Payment | `payment.payment.processed`, `.failed`, `.refunded`, `.captured`, `.voided` | ❌ Direct Dapr | ✅ Need `payment.payment.processed` |
| Shipping | `shipping.shipment.status_changed` | ✅ Yes (outbox) | ✅ Fix route |
| Checkout | `cart.converted` | ❌ Direct Dapr | ✅ Add HTTP sub |
| Return | `orders.return.requested/approved/rejected/completed` | ✅ Yes (outbox) | ✅ Add subs |
| Fulfillment | `fulfillments.fulfillment.status_changed`, `.sla_breach` | ✅ Yes (outbox) | ✅ Add subs |
| Warehouse | No stock events published yet | N/A | ❌ Not available |
| Catalog | Product events go to search/pricing | N/A | 🔵 P2 — nice to have |

---

## 5. Data Mismatch Risks

### 5.1 Revenue Data Mismatch

**Current**: Analytics processes `orders.order.status_changed` for revenue. This counts ALL orders including cancelled/unpaid.

**Shopify/Lazada Pattern**: GMV = sum of `payment.confirmed` amounts. Only confirmed payments count as revenue.

**Status**: Payment handler exists (`ProcessPaymentEvent`) but is never triggered due to topic mismatch (§3.3).

### 5.2 Real-Time vs Aggregated Reports May Diverge

Real-time metrics update via event handlers → Redis cache. Historical reports update via `AggregationCronJob` → PostgreSQL aggregation tables. If the worker isn't deployed (§3.4), aggregated reports show stale data while real-time dashboard may show current data (if events arrive correctly).

### 5.3 Cart Abandonment Still Incomplete

Cart abandonment = carts started − carts converted. Analytics receives `cart.converted` (if subscription is fixed) but has no `cart.started` signal. Checkout service doesn't publish `cart.started` events.

---

## 6. Retry / Rollback (Outbox/Saga) Audit

### 6.1 Analytics Does Not Need Outbox

Analytics is a read-only sink. It doesn't modify state in other services, so it has no need for Saga or Outbox patterns. This is correct.

### 6.2 Upstream Outbox Patterns (Verified)

| Service | Outbox Pattern | Impact on Analytics |
|---------|---------------|-------------------|
| Order | ✅ `orders.order.status_changed` via outbox | Guaranteed at-least-once delivery to analytics |
| Shipping | ✅ `shipment.status_changed` via outbox | Guaranteed delivery |
| Fulfillment | ✅ `fulfillment.status_changed` via outbox | Guaranteed delivery |
| Return | ✅ Return events via outbox | Guaranteed delivery |
| Payment | ❌ Direct Dapr publish (no outbox) | Events can be lost if payment service crashes after DB commit but before publish |
| Checkout | ❌ `cart.converted` direct Dapr | Same risk |

### 6.3 DLQ Handling

- ✅ Dapr-level DLQ: `subscription-dlq.yaml` persists failed events to `dead_letter_queue` table
- ✅ Application-level DLQ: `sendToDeadLetterQueue` after 3 internal retries
- ✅ `RetryDeadLetterEvent` allows manual replay of DLQ events
- ⚠️ No automated DLQ replay cron — manual intervention required

---

## 7. Edge Cases & Logic Risks

### 7.1 Event ID Generation Fragility

`generateEventID` (event_processing_usecase.go:220-228) uses `sha256(json.Marshal(event))` when `event.EventID` is empty. This hash includes `CreatedAt` timestamp, meaning:
- Same logical event at slightly different times → different hash → treated as two events
- **Risk**: Duplicate analytics data for events without explicit IDs

### 7.2 Reconciliation Service Only Checks 2 Event Types

`RunDailyReconciliation` only checks `purchase` and `page_view` counts against 7-day average. Missing checks for: `payment`, `shipping`, `return`, `fulfillment`, `customer` event types.

### 7.3 Flash-Sale Burst — Single-INSERT per Event

`SaveEvent` does single-row INSERT. During flash sales (10K+ orders/min), this can exhaust DB connection pool. `BatchSaveEvents` interface exists but is never called by event handlers.

### 7.4 processOrderEvent vs ProcessOrderEvent — Two Code Paths

The `EventProcessingUseCase.processOrderEvent` (biz layer, line 279) only validates and invalidates cache. The `EventProcessor.ProcessOrderEvent` (service layer, event_processor.go:70) does full processing with save. The biz-layer path is invoked by `ProcessIncomingEvent` (cart consumer worker path), while the service-layer is invoked by HTTP event handlers. These have different behavior for order events.

### 7.5 Aggregation Catch-Up is Single-Day Only

`AggregationCronJob.Start` runs catch-up for yesterday only (`time.Now().AddDate(0, 0, -1)`). If the worker was down for multiple days, aggregation data for those intermediate days is never back-filled.

---

## 8. GitOps Configuration Review

### 8.1 Server Deployment (`gitops/apps/analytics/base/deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr enabled (`dapr.io/enabled: "true"`) | ✅ |
| `dapr.io/app-id: "analytics"` | ✅ |
| `dapr.io/app-port: "8019"` (HTTP) | ✅ |
| `dapr.io/app-protocol: "http"` | ✅ |
| Security context non-root (65532) | ✅ |
| Liveness probe `/health/live` | ✅ |
| Readiness probe `/health/ready` | ✅ |
| Startup probe (failureThreshold=30) | ✅ |
| secretRef `analytics-secrets` | ✅ |
| envFrom `overlays-config` | ✅ |
| Command runs `/app/bin/analytics` | ⚠️ Binary name is `analytics` but `cmd/server/` builds as `server` |
| **Worker deployment** | ✅ **FIXED** — `worker-deployment.yaml` created + added to kustomization |
| **HPA** | ✅ **FIXED** — enabled in `kustomization.yaml` (min=2, max=8) |
| **Config volumeMount** | ⚠️ Server reads config from env vars via `config.Load()`, not from file — low risk |
| **NetworkPolicy** | ✅ Well-configured with correct namespaces/ports |

### 8.2 ConfigMap (`overlays/dev/configmap.yaml`)

| Check | Status |
|-------|--------|
| DB config (host, port, name, SSL) | ✅ |
| Redis config | ✅ |
| HTTP/gRPC ports match deployment | ✅ (8019/9019) |
| Dapr config | ✅ |
| Service endpoints for gRPC calls | ✅ 9 services configured |
| `RETURN_SERVICE_HOST` | ❌ Missing — analytics has return handler but no return service endpoint |
| `PROMOTION_SERVICE_HOST` endpoint | ❌ Missing — uses `MARKETING_SERVICE_HOST` pointing to promotion service |

### 8.3 Dapr Subscription Files

| File | Topics | Issues |
|------|--------|--------|
| `subscription.yaml` | 8 topics | ✅ **FIXED** — all routes correct, all topics match source services |
| `subscription-dlq.yaml` | 8 DLQ topics | ✅ **FIXED** — DLQ entries for all 8 main topics |
| **Missing subscriptions** | none | ✅ All critical event types now subscribed |

---

## 9. Worker & Cron Jobs on Worker Binary

### 9.1 Workers Registered in `cmd/worker/main.go`

| Worker | Type | Registered? | GitOps Deployed? |
|--------|------|------------|-----------------|
| `AggregationCronJob` | Cron (hourly + daily) | ✅ | ✅ **FIXED** — worker-deployment.yaml |
| `AlertCheckerCronJob` | Cron (5-minute interval) | ✅ | ✅ **FIXED** — worker-deployment.yaml |
| `CartConsumerWorker` | Removed | ❌ Removed — HTTP path used instead | N/A |

### 9.2 Missing Recommended Workers

| Worker | Purpose | Priority |
|--------|---------|----------|
| **DataQualityCron** | Run data quality checks on schedule | P2 |
| **ReportSchedulerCron** | Execute scheduled custom reports | P2 |
| **ReconciliationCron** | Daily cross-service event count reconciliation | P2 |
| **RealTimeMetricsRefreshCron** | Heartbeat for real-time dashboard | P2 |
| **DLQ Auto-Retry Worker** | Automatically retry DLQ events after cooldown | P2 |

---

## 10. Priority Matrix — Updated Status

### 🔴 P0 — Critical

| ID | Issue | Status |
|----|-------|--------|
| **ANLT-V2-P0-001** | Dapr subscriptions for payment/shipping route to `/events/orders` (wrong handler) | ✅ **FIXED** |
| **ANLT-V2-P0-002** | Payment topic mismatch: `payments.payment.confirmed` → `payment.payment.processed` | ✅ **FIXED** |
| **ANLT-V2-P0-003** | No Dapr subscriptions for return, fulfillment, cart events | ✅ **FIXED** |

### 🟡 P1 — High

| ID | Issue | Status |
|----|-------|--------|
| **ANLT-V2-P1-001** | No `worker-deployment.yaml` in GitOps | ✅ **FIXED** |
| **ANLT-V2-P1-002** | HPA commented out — single replica under burst | ✅ **FIXED** |
| **ANLT-V2-P1-003** | `data_quality_usecase.go` excluded by `//go:build ignore` | ✅ **FIXED** — re-tagged as intentionally not wired |
| **ANLT-V2-P1-004** | Fulfillment/Shipping event processors lack idempotency | ✅ **FIXED** |
| **ANLT-V2-P1-005** | Cart consumer dual-path risk (worker gRPC + server HTTP) | ✅ **FIXED** — gRPC consumer removed |
| **ANLT-V2-P1-006** | Config volume not mounted for server binary | ⚠️ Low risk — uses env vars via `config.Load()` |
| **ANLT-V2-P1-007** | Payment payload schema mismatch (`payment_id` vs `event_id`, `timestamp` vs `created_at`) | ✅ **FIXED** — struct aligned to PaymentProcessed |
| **ANLT-V2-P1-008** | Server runs duplicate aggregation scheduler alongside worker | ✅ **FIXED** — ScheduleAggregationJobs removed from server |
| **ANLT-V2-P1-009** | Return payload schema mismatch (`return_request_id`, `refund_amount`, `timestamp`) | ✅ **FIXED** — struct aligned to ReturnRequestedEvent |
| **ANLT-V2-P1-010** | NetworkPolicy only covers `component: backend`, not worker | ✅ **FIXED** — selector widened to `name: analytics` |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Issue | Status |
|----|-------|--------|
| **ANLT-V2-P2-001** | `warehouse.stock.changed` not subscribed — OOS rate unavailable | ⚠️ Blocked — warehouse doesn't publish stock events yet |
| **ANLT-V2-P2-002** | No `cart.started` event — cart abandonment incomplete | ⚠️ Requires checkout service change |
| **ANLT-V2-P2-003** | Aggregation catch-up is single-day only | Roadmap |
| **ANLT-V2-P2-004** | `BatchSaveEvents` never used — flash-sale risk | Roadmap |
| **ANLT-V2-P2-005** | Reconciliation only checks 2 event types | Roadmap |
| **ANLT-V2-P2-006** | No seller dimension in analytics | Roadmap |
| **ANLT-V2-P2-007** | Event ID generation includes timestamps → unstable hash | Roadmap |
| **ANLT-V2-P2-008** | Missing DLQ auto-retry worker | Roadmap |
| **ANLT-V2-P2-009** | `payment.payment.failed` + `payment.payment.refunded` subscriptions missing | ✅ **FIXED** — subscriptions added |
| **ANLT-V2-P2-010** | `orders.return.approved` + `orders.return.rejected` subscriptions missing | ✅ **FIXED** — subscriptions added |
| **ANLT-V2-P2-011** | `fulfillments.fulfillment.sla_breach` not subscribed + no event type mapping | ✅ **FIXED** — subscription + mapping added |
| **ANLT-V2-P2-012** | `/events/products`, `/events/customers` handlers exist but no subs | Roadmap — needs upstream events |

---

## 11. What Is Well Implemented ✅

| Area | Evidence |
|------|----------|
| CloudEvent envelope parsing | `event_handler.go` — full DaprCloudEvent with traceParent |
| Event deduplication (ID + hash) | `event_processing_usecase.go` — two-level dedup |
| DLQ persistence for failed events | `HandleDLQEvents` + `subscription-dlq.yaml` |
| DLQ manual replay | `RetryDeadLetterEvent` replays through `processEventByType` |
| PII anonymization | `pii.HashField`, `pii.MaskIP`, `pii.MaskEmail` before storage |
| W3C trace-id propagation | `extractTraceID` from CloudEvent `traceparent` header |
| Schema validation (fail-closed) | `JSONSchemaValidator` with embedded schemas |
| Aggregation cron logic | `aggregation_cron.go` — hourly + daily + mat views |
| Alert checker cron | `alert_checker_cron.go` — 5-min interval with cache invalidation |
| Rich interface design | `interfaces.go` — 17 use case interfaces covering full analytics |
| Reconciliation service | `reconciliation_service.go` — daily event count vs 7-day average |
| Idempotency in order/payment/return/cart handlers | Full flow: check → process → mark processed |
| Event sequence tracking | `trackEventSequence` for out-of-order detection |
| Real-time update service | `realtime_update_service.go` — Redis-backed real-time counters |
| Network policy | `networkpolicy.yaml` — properly scoped ingress/egress rules |

---

## 12. Recommended Fix Sequence

```
✅ Phase 1 (DONE — P0):
  1. ✅ Fixed dapr/subscription.yaml routes (payment→/events/payments, shipping→/events/shipping)
  2. ✅ Fixed payment topic: payments.payment.confirmed → payment.payment.processed
  3. ✅ Added dapr subscriptions for return, fulfillment, cart events + DLQ entries

✅ Phase 2 (DONE — P1):
  4. ✅ Created gitops/apps/analytics/base/worker-deployment.yaml
  5. ✅ Enabled HPA in kustomization.yaml
  6. ✅ Added idempotency to fulfillment/shipping event processors
  7. ✅ Resolved cart consumer dual-path: removed gRPC consumer, HTTP Dapr sub only
  8. ✅ Re-tagged data_quality_usecase.go as intentionally not wired

✅ Phase 3 (DONE — P1 cont. + P2):
  9. ✅ Aligned payment event struct to PaymentProcessed payload (payment_id, timestamp)
  10. ✅ Aligned return event struct to ReturnRequestedEvent payload (return_request_id, refund_amount, timestamp)
  11. ✅ Removed duplicate aggregation scheduler from server (worker-only now)
  12. ✅ Widened NetworkPolicy to cover worker pods
  13. ✅ Added payment.failed, payment.refunded subscriptions
  14. ✅ Added return.approved, return.rejected subscriptions
  15. ✅ Added fulfillment.sla_breach subscription + event type mapping
  16. ✅ Added 5 matching DLQ entries (total: 13 DLQ topics)

Phase 4 (Next Sprint — P2 roadmap):
  17. Add warehouse.stock.changed subscription (when available)
  18. Implement cart.started event in checkout service
  19. Multi-day aggregation back-fill
  20. BatchSaveEvents for flash-sale resilience
```

---

## Related Files

| Document | Path |
|----------|------|
| Previous analytics checklist (v1) | [analytics-reporting-review.md](analytics-reporting-review.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |
| Return & Refund flow checklist | [return-refund-review.md](return-refund-review.md) |
| Cart & Checkout flow review | [cart-checkout-deep-review.md](cart-checkout-deep-review.md) |
| Payment flow checklist | [payment-review.md](payment-review.md) |

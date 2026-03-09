# Analytics & Reporting Flow — Business Logic Review v3

**Date**: 2026-03-07  
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase deep-dive)  
**Scope**: `analytics/` service — event ingestion, aggregation, reporting, real-time, worker, GitOps  
**Baseline**: Previous checklist v2 (2026-02-26)

> Delta review against v2. P0/P1 issues from v2 remain FIXED. New issues discovered by scanning code + GitOps layer.

---

## 1. Architecture Summary (Current State)

```
Upstream Services (order, payment, checkout, shipping, fulfillment, return...)
    ↓ Dapr PubSub events (HTTP-based subscriptions — 13 topics)
Analytics Server (cmd/server)
    ├─ /events/orders        → orders.order.status_changed
    ├─ /events/payments      → payment.payment.processed/failed/refunded  ✅
    ├─ /events/shipping      → shipping.shipment.status_changed           ✅
    ├─ /events/page-views    → analytics.page_view
    ├─ /events/returns       → orders.return.requested/approved/rejected/completed ✅
    ├─ /events/fulfillment   → fulfillments.fulfillment.status_changed/sla_breach  ✅
    ├─ /events/cart           → cart.converted                             ✅
    ├─ /events/products      → (handler exists, no Dapr sub — roadmap)
    ├─ /events/customers     → (handler exists, no Dapr sub — roadmap)
    └─ /events/dlq           → DLQ catch-all (13 DLQ topics)
    ↓ EventProcessor → SaveEvent → PostgreSQL
    ↓ ProcessedEvent tracking (idempotency)

Analytics Worker (cmd/worker) — deployed via common-worker-deployment-v2 ✅
    ├─ AggregationCronJob     → hourly aggregation + mat views + daily pipeline
    ├─ AlertCheckerCronJob    → alert conditions every 5m
    ├─ RetentionCronJob       → data retention + partition management (24h)
    └─ ReconciliationCronJob  → daily cross-service event count check (24h)

API Layer (HTTP gRPC-Gateway + Kratos gRPC) → Dashboard, Revenue, Orders, Products, etc.
```

---

## 2. Data Consistency Between Services

| Data Source | Analytics Receives Via | Topic | Status |
|-------------|----------------------|-------|--------|
| Order status changes | Dapr sub → `/events/orders` | `orders.order.status_changed` | ✅ |
| Payment processed | Dapr sub → `/events/payments` | `payment.payment.processed` | ✅ |
| Payment failed | Dapr sub → `/events/payments` | `payment.payment.failed` | ✅ |
| Payment refunded | Dapr sub → `/events/payments` | `payment.payment.refunded` | ✅ |
| Shipment status | Dapr sub → `/events/shipping` | `shipping.shipment.status_changed` | ✅ |
| Page views | Dapr sub → `/events/page-views` | `analytics.page_view` | ✅ |
| Cart conversions | Dapr sub → `/events/cart` | `cart.converted` | ✅ |
| Return requested | Dapr sub → `/events/returns` | `orders.return.requested` | ✅ |
| Return approved | Dapr sub → `/events/returns` | `orders.return.approved` | ✅ |
| Return rejected | Dapr sub → `/events/returns` | `orders.return.rejected` | ✅ |
| Return completed | Dapr sub → `/events/returns` | `orders.return.completed` | ✅ |
| Fulfillment status | Dapr sub → `/events/fulfillment` | `fulfillments.fulfillment.status_changed` | ✅ |
| Fulfillment SLA breach | Dapr sub → `/events/fulfillment` | `fulfillments.fulfillment.sla_breach` | ✅ |
| Promotion usage | Not subscribed | — | ❌ Missing (P2) |
| Warehouse stock changes | Not subscribed | — | ❌ Missing (P2) |
| Catalog product changes | Not subscribed | — | ❌ Missing (P2) |

---

## 3. Critical Findings (New Issues from v3 Review)

### 3.1 🟡 P1 — `ExecuteDataQualityCheck` Spawns Unmanaged Goroutine

**File**: `internal/biz/data_quality_usecase.go:170`

```go
go func() {
    defer func() {
        if r := recover(); r != nil { ... }
    }()
    time.Sleep(1 * time.Second)
    // update result...
    uc.analyticsRepo.CreateDataQualityResult(context.Background(), createdResult)
}()
```

**Issues**:
- Uses bare `go func()` — violates goroutine safety rules (must use `errgroup` or managed worker pools)
- Uses `context.Background()` inside goroutine — ignores parent cancellation/timeout
- Simulated logic with hardcoded `time.Sleep` and fake quality scores — not production-ready
- Panic recovery exists but goroutine is not tracked, leaked on shutdown

**Recommendation**: Use `errgroup` or a managed task runner. If this is intentionally deferred, gate behind a feature flag and document.

---

### 3.2 🟡 P1 — Reconciliation Only Checks 2 of 7+ Event Types

**File**: `internal/service/reconciliation_service.go:83-91`

The threshold check struct only includes `purchase` and `page_view`:
```go
checks := []struct {
    name    string
    daily   int64
    weekAvg float64
}{
    {"purchase", report.PurchaseEvents, report.SevenDayAvgPurchase},
    {"page_view", report.PageViewEvents, report.SevenDayAvgPageView},
}
```

`product_view` is counted (`report.ProductViewEvents`) but **never used in threshold checks**.

Missing event types from reconciliation:
- `payment.payment.processed/failed/refunded`
- `shipping.shipment.status_changed`
- `orders.return.*`
- `fulfillments.fulfillment.*`
- `cart.converted`

**Impact**: Silent event loss for 5+ event types would not be detected by daily reconciliation.

---

### 3.3 🟡 P1 — `BatchProcessEvents` Missing Routes for Payment/Return/Fulfillment/Shipping/Cart

**File**: `internal/service/event_processor.go:555-606`

The `BatchProcessEvents` switch only routes 4 event types:
```go
case "order_created", "order_updated", "purchase":
case "product_viewed", "product_added_to_cart":
case "customer_registered", "customer_login":
case "page_viewed":
```

Events like `payment.processed`, `return.requested`, `fulfillment.status_changed`, `shipment_created`, `cart_converted` are all classified as **"Unknown event type"** and silently dropped.

**Impact**: If `BatchProcessEvents` is ever invoked for non-order/product events (e.g., DLQ replay of payment events via batch), those events would be silently dropped. Currently not a production issue since individual processors handle live traffic, but this is a latent bug.

---

### 3.4 🔵 P2 — HPA Only Targets API Deployment, Worker Has No HPA

**File**: `gitops/apps/analytics/base/hpa.yaml`

```yaml
spec:
  scaleTargetRef:
    kind: Deployment
    name: analytics      # API server only
```

The worker deployment (`analytics-worker`) has no HPA. During aggregation bursts or alert checker heavy load, the worker cannot scale. For analytics, this is acceptable since cron jobs are designed for single-instance execution, but if the worker ever handles event processing, HPA would be needed.

---

### 3.5 🔵 P2 — Worker Pod Labels Match API Pod Labels — NetworkPolicy Overlap

**File**: `gitops/apps/analytics/base/kustomization.yaml:110-117`

Both API and worker deployments use the same label:
```yaml
app.kubernetes.io/name: analytics
```

The `NetworkPolicy` pod selector targets `app.kubernetes.io/name: analytics`. This means the worker pods receive **the same ingress rules** as the API pods (allowing gateway traffic on port 8019/9019). The worker doesn't serve HTTP/gRPC — these ports are unnecessarily open.

**Recommendation**: Add a `app.kubernetes.io/component: worker` label to the worker deployment and create a separate, more restrictive NetworkPolicy for worker pods (only egress to DB/Redis/Dapr).

---

### 3.6 🔵 P2 — `updateProductMetrics` Is a No-Op Stub

**File**: `internal/service/event_processor.go:548-553`

```go
func (ep *EventProcessor) updateProductMetrics(ctx context.Context, eventType, productID string) {
    ep.log.Debugf("Updated product metrics for %s: %s", productID, eventType)
}
```

Marked as `TODO(P2)` — real-time product metrics (views, cart adds) are not actually tracked in Redis. The dashboard's real-time product performance data would show stale/missing data.

---

## 4. Event Publishing & Subscription Audit

### 4.1 Does Analytics Need to Publish Events?

**No.** Analytics is a pure sink/read service. Correct — matches Shopify/Shopee/Lazada pattern.

### 4.2 Does Analytics Need to Subscribe to Events?

**Yes.** All critical event subscriptions are now in place:

| Source Service | Topic | Dapr Sub? | Correct Route? | Handler? | Idempotency? |
|----------------|-------|-----------|----------------|----------|--------------|
| Order | `orders.order.status_changed` | ✅ | ✅ | ✅ | ✅ |
| Payment | `payment.payment.processed` | ✅ | ✅ `/events/payments` | ✅ | ✅ |
| Payment | `payment.payment.failed` | ✅ | ✅ `/events/payments` | ✅ | ✅ |
| Payment | `payment.payment.refunded` | ✅ | ✅ `/events/payments` | ✅ | ✅ |
| Shipping | `shipping.shipment.status_changed` | ✅ | ✅ `/events/shipping` | ✅ | ✅ |
| Checkout | `cart.converted` | ✅ | ✅ `/events/cart` | ✅ | ✅ |
| Page view | `analytics.page_view` | ✅ | ✅ `/events/page-views` | ✅ | ✅ |
| Return | `orders.return.requested` | ✅ | ✅ `/events/returns` | ✅ | ✅ |
| Return | `orders.return.approved` | ✅ | ✅ `/events/returns` | ✅ | ✅ |
| Return | `orders.return.rejected` | ✅ | ✅ `/events/returns` | ✅ | ✅ |
| Return | `orders.return.completed` | ✅ | ✅ `/events/returns` | ✅ | ✅ |
| Fulfillment | `fulfillments.fulfillment.status_changed` | ✅ | ✅ `/events/fulfillment` | ✅ | ✅ |
| Fulfillment | `fulfillments.fulfillment.sla_breach` | ✅ | ✅ `/events/fulfillment` | ✅ | ✅ |
| Warehouse | stock events | ❌ | N/A | ❌ | N/A |
| Catalog | product CRUD | ❌ | N/A | ❌ | N/A |
| Promotion | promo usage | ❌ | N/A | ❌ | N/A |

### 4.3 Upstream Outbox Verification

| Service | Outbox Pattern | Analytics Impact |
|---------|---------------|-----------------|
| Order | ✅ Outbox | Guaranteed delivery |
| Shipping | ✅ Outbox | Guaranteed delivery |
| Fulfillment | ✅ Outbox | Guaranteed delivery |
| Return | ✅ Outbox | Guaranteed delivery |
| Payment | ❌ Direct Dapr | Events can be lost on crash between DB commit and publish |
| Checkout | ❌ Direct Dapr | Same risk |

---

## 5. Data Mismatch Risks

### 5.1 Revenue Data — Now Correctly Sourced ✅

Payment handler (`ProcessPaymentEvent`) is properly wired via `payment.payment.processed` subscription. Revenue data now comes from confirmed payments, matching Shopify/Lazada GMV calculation pattern.

### 5.2 Cart Abandonment Still Incomplete ⚠️

`cart.converted` is subscribed, but `cart.started` doesn't exist as an upstream event. Abandonment rate = carts started - carts converted. Blocked on checkout service publishing `cart.started`.

### 5.3 Real-Time vs Aggregated Report Divergence — Low Risk ✅

Worker is properly deployed with 4 cron jobs. Aggregation runs hourly + daily. Risk of divergence is acceptable with proper materialized view refresh.

---

## 6. Retry / Rollback (Outbox/Saga) Audit

### 6.1 Analytics Does Not Need Outbox ✅

Correct — read-only sink, no cross-service state mutations.

### 6.2 DLQ Handling ✅

- ✅ Dapr-level DLQ: `subscription-dlq.yaml` with 13 DLQ topic entries
- ✅ Application-level DLQ: `HandleDLQEvents` persists to `dead_letter_queue` table
- ✅ Manual replay: `RetryDeadLetterEvent` replays through `processEventByType`
- ⚠️ No automated DLQ replay cron (manual intervention required)

---

## 7. Edge Cases & Logic Risks

### 7.1 Event ID Generation Fragility (Carried from v2)

`generateEventID` in `event_processing_usecase.go:220-228` uses `sha256(json.Marshal(event))` when `event.EventID` is empty. Hash includes `CreatedAt` → same logical event at different times produces different hashes → potential duplicates.

### 7.2 Aggregation Catch-Up Still Single-Day (Carried from v2)

`AggregationCronJob` runs daily catch-up for yesterday only. Multi-day worker outage = aggregation gaps.

### 7.3 Flash-Sale Burst — SaveEvent Single-INSERT per Event (Carried from v2)

Individual event handlers call `SaveEvent` (single INSERT). `BatchSaveEvents` exists but is only used for order item product events, not the main event path.

### 7.4 NEW: `processEventByType` in Biz Layer Missing Payment/Return/Fulfillment/Shipping/Cart Types

**File**: `internal/biz/event_processing_usecase.go:262-277`

The biz-layer `processEventByType` switch handles: `purchase/order_created/order_updated`, `product_viewed/product_added_to_cart/...`, `customer_registered/...`, `page_viewed`, `inventory_*`, `shipping_*`. But it does NOT handle `payment.*`, `return_*`, `fulfillment_*`, `cart_converted`.

Since this path is only invoked via `ProcessIncomingEvent` (not the HTTP handlers), it only affects DLQ replay of events that go through the biz layer. HTTP handlers call service-layer processors directly, so production traffic is unaffected.

### 7.5 NEW: `ReconciliationReport.ProductViewEvents` Counted But Never Used in Threshold

`product_view` events are counted in the reconciliation SQL query and stored in `report.ProductViewEvents`, but the threshold check array only includes `purchase` and `page_view`. This field is always zero in the alert logic.

---

## 8. GitOps Configuration Review

### 8.1 Server Deployment

| Check | Status |
|-------|--------|
| Dapr enabled (`dapr.io/enabled: "true"`) | ✅ Via component |
| `dapr.io/app-id: "analytics"` | ✅ Via kustomization replacement |
| `dapr.io/app-port` = 8019 (HTTP) | ✅ Via port propagation |
| `dapr.io/app-protocol: "http"` | ✅ Via component |
| Security context non-root | ✅ Via component |
| Liveness probe `/health/live` | ✅ Via component |
| Readiness probe `/health/ready` | ✅ Via component |
| Startup probe (failureThreshold=30) | ✅ Via component |
| envFrom `config` + `secrets` | ✅ `patch-api.yaml` |
| Resources (128Mi-512Mi, 100m-500m) | ✅ |
| HPA (min=2, max=5, CPU 75%, Mem 80%) | ✅ |
| PDB | ✅ `pdb.yaml` |
| Command runs `/app/bin/analytics` | ✅ |

### 8.2 Worker Deployment

| Check | Status |
|-------|--------|
| Worker deployment via `common-worker-deployment-v2` | ✅ |
| Worker command `/app/bin/worker` | ✅ |
| Worker resources (128Mi-256Mi, 50m-200m) | ✅ |
| Worker PDB | ✅ `worker-pdb.yaml` |
| Worker ServiceAccount shared with API | ✅ |
| Worker Dapr app-id = `analytics-worker` | ✅ |
| Worker HPA | ❌ None (acceptable for cron-only) |
| Worker labels same as API (`app.kubernetes.io/name: analytics`) | ⚠️ NetworkPolicy overlap |

### 8.3 ConfigMap

| Check | Status |
|-------|--------|
| DB config (host, port, name, SSL) | ✅ |
| Redis config | ✅ |
| HTTP/gRPC ports match deployment (8019/9019) | ✅ |
| Dapr config | ✅ |
| Service endpoints (9 services) | ✅ |
| `RETURN_SERVICE_HOST` | ❌ Missing — return events come via PubSub, no direct gRPC calls needed |
| `PROMOTION_SERVICE_HOST` | ❌ Missing — uses `MARKETING_SERVICE_HOST` pointing to promotion service |

### 8.4 Dapr Subscription Files

| File | Topics | Status |
|------|--------|--------|
| `subscription.yaml` | 13 topics | ✅ All routes correct, all topics match sources |
| `subscription-dlq.yaml` | 13 DLQ topics | ✅ Matching DLQ entries for all 13 main topics |

### 8.5 Network Policy

| Check | Status |
|-------|--------|
| Ingress from gateway (8019/9019) | ✅ |
| Ingress from order/catalog/customer/payment | ✅ |
| Egress to 7 services (order, catalog, customer, payment, warehouse, fulfillment, shipping, search) | ✅ |
| Infrastructure egress via component | ✅ |
| Pod selector covers API + Worker equally | ⚠️ Worker doesn't need ingress rules |

---

## 9. Worker & Cron Jobs

### 9.1 Workers in `cmd/worker/main.go`

| Worker | Type | Interval | RunOnStart | Notes |
|--------|------|----------|------------|-------|
| `AggregationCronJob` | Cron | 1 hour | ✅ | Hourly agg + daily pipeline (after 1 AM) |
| `AlertCheckerCronJob` | Cron | 5 min | ✅ | Alert conditions + cache invalidation |
| `RetentionCronJob` | Cron | 24 hours | ✅ | Data retention + partition management |
| `ReconciliationCronJob` | Cron | 24 hours | ❌ | Daily event count vs 7-day average |

### 9.2 Missing Recommended Workers

| Worker | Purpose | Priority |
|--------|---------|----------|
| **DLQ Auto-Retry Worker** | Automatically retry DLQ events after cooldown | P2 |
| **DataQualityCron** | Run data quality checks on schedule | P2 |
| **ReportSchedulerCron** | Execute scheduled custom reports | P2 |

---

## 10. Priority Matrix — Updated Status

### 🔴 P0 — All Fixed ✅

| ID | Issue | Status |
|----|-------|--------|
| **ANLT-V2-P0-001** | Dapr subs for payment/shipping route to wrong handler | ✅ **FIXED** |
| **ANLT-V2-P0-002** | Payment topic mismatch | ✅ **FIXED** |
| **ANLT-V2-P0-003** | No Dapr subs for return, fulfillment, cart | ✅ **FIXED** |

### 🟡 P1 — Previously Fixed + New

| ID | Issue | Status |
|----|-------|--------|
| **ANLT-V2-P1-001** | No worker-deployment.yaml in GitOps | ✅ **FIXED** |
| **ANLT-V2-P1-002** | HPA commented out | ✅ **FIXED** |
| **ANLT-V2-P1-003** | `data_quality_usecase.go` excluded by build tag | ✅ **FIXED** |
| **ANLT-V2-P1-004** | Fulfillment/Shipping processors lack idempotency | ✅ **FIXED** |
| **ANLT-V2-P1-005** | Cart consumer dual-path risk | ✅ **FIXED** |
| **ANLT-V2-P1-006** | Config volume not mounted | ⚠️ Low risk — uses env vars |
| **ANLT-V2-P1-007** | Payment payload schema mismatch | ✅ **FIXED** |
| **ANLT-V2-P1-008** | Server duplicate aggregation scheduler | ✅ **FIXED** |
| **ANLT-V2-P1-009** | Return payload schema mismatch | ✅ **FIXED** |
| **ANLT-V2-P1-010** | NetworkPolicy only covers backend component | ✅ **FIXED** |
| **ANLT-V3-P1-001** | `ExecuteDataQualityCheck` spawns unmanaged goroutine | 🆕 OPEN |
| **ANLT-V3-P1-002** | Reconciliation only checks 2 of 7+ event types | 🆕 OPEN |
| **ANLT-V3-P1-003** | `BatchProcessEvents` missing routes for 5+ event types | 🆕 OPEN |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Issue | Status |
|----|-------|--------|
| **ANLT-V2-P2-001** | `warehouse.stock.changed` not subscribed | ⚠️ Blocked — warehouse doesn't publish |
| **ANLT-V2-P2-002** | No `cart.started` event | ⚠️ Requires checkout service change |
| **ANLT-V2-P2-003** | Aggregation catch-up single-day only | Roadmap |
| **ANLT-V2-P2-004** | `BatchSaveEvents` never used for main event path | Roadmap |
| **ANLT-V2-P2-005** | Reconciliation only checks 2 event types | ⬆️ Promoted to P1 (ANLT-V3-P1-002) |
| **ANLT-V2-P2-006** | No seller dimension in analytics | Roadmap |
| **ANLT-V2-P2-007** | Event ID generation includes timestamps → unstable hash | Roadmap |
| **ANLT-V2-P2-008** | Missing DLQ auto-retry worker | Roadmap |
| **ANLT-V2-P2-009** | `payment.payment.failed/refunded` subs missing | ✅ **FIXED** |
| **ANLT-V2-P2-010** | `orders.return.approved/rejected` subs missing | ✅ **FIXED** |
| **ANLT-V2-P2-011** | `fulfillments.fulfillment.sla_breach` not subscribed | ✅ **FIXED** |
| **ANLT-V2-P2-012** | `/events/products`, `/events/customers` handlers no subs | Roadmap |
| **ANLT-V3-P2-001** | Worker HPA missing (acceptable for cron-only) | Roadmap |
| **ANLT-V3-P2-002** | Worker pods share API labels → NetworkPolicy too permissive | 🆕 OPEN |
| **ANLT-V3-P2-003** | `updateProductMetrics` is a no-op stub | 🆕 OPEN |
| **ANLT-V3-P2-004** | `ReconciliationReport.ProductViewEvents` never threshold-checked | 🆕 OPEN |

---

## 11. What Is Well Implemented ✅

| Area | Evidence |
|------|----------|
| CloudEvent envelope parsing | `event_handler.go` — full DaprCloudEvent with traceParent |
| Event deduplication (ID + hash) | All 7 processors implement IsEventProcessed → process → CreateProcessedEvent |
| DLQ persistence for failed events | `HandleDLQEvents` + 13-entry `subscription-dlq.yaml` |
| DLQ manual replay | `RetryDeadLetterEvent` replays through `processEventByType` |
| PII anonymization | `pii.HashField`, `pii.MaskIP`, `pii.MaskEmail` before storage |
| W3C trace-id propagation | `extractTraceID` from CloudEvent `traceparent` header |
| Schema validation (fail-closed) | `JSONSchemaValidator` with embedded schemas |
| Aggregation cron logic | Hourly + daily + 9 aggregation pipelines + mat views |
| Alert checker cron | 5-min interval with cache invalidation |
| Retention cron | Daily retention + partition management |
| Reconciliation cron | Daily event count vs 7-day average (needs expansion) |
| Rich interface design | `interfaces.go` — 17+ use case interfaces |
| Event sequence tracking | `trackEventSequence` for out-of-order detection |
| Body size limit | `parseCloudEvent` limits to 1MB |
| Clean server/worker separation | No duplicate aggregation in server binary |
| Managed goroutines | `errgroup` in server main for gRPC + HTTP servers |
| Network policy | Properly scoped ingress/egress rules with infra egress component |
| ArgoCD sync waves | Proper ordering: 0 (networkpolicy) → 2 (api) → 3 (worker) → 4 (hpa) |

---

## 12. Recommended Fix Sequence

```
✅ Phase 1-3 (DONE — P0 + P1 + P2 fixes from v2):
   All 16 items completed. See v2 checklist for details.

Phase 4 (v3 — Current Sprint P1):
  17. Fix ExecuteDataQualityCheck goroutine — use errgroup or managed task runner (ANLT-V3-P1-001)
  18. Expand reconciliation to check all 7+ event types, not just purchase + page_view (ANLT-V3-P1-002)
  19. Add payment/return/fulfillment/shipping/cart routes to BatchProcessEvents (ANLT-V3-P1-003)

Phase 5 (Next Sprint — P2 roadmap):
  20. Separate worker NetworkPolicy with component label
  21. Implement updateProductMetrics Redis counters
  22. Add warehouse.stock.changed subscription (when available)
  23. Implement cart.started event in checkout service
  24. Multi-day aggregation back-fill
  25. DLQ auto-retry worker
```

---

## Related Files

| Document | Path |
|----------|------|
| Previous analytics checklist (v2) | [archive/analytics-reporting-flow-checklist.md](archive/analytics-reporting-flow-checklist.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |
| Return & Refund flow checklist | [return-refund-review.md](return-refund-review.md) |
| Cart & Checkout flow review | [cart-checkout-deep-review.md](cart-checkout-deep-review.md) |
| Payment flow checklist | [payment-review.md](payment-review.md) |

# Return & Refund Flows — Business Logic Review Checklist v3

**Reviewed**: 2026-03-07
**Pattern Reference**: Shopify, Shopee, Lazada + `docs/10-appendix/ecommerce-platform-flows.md` §10
**Services Involved**: return, order, payment, warehouse, shipping, notification, loyalty-rewards
**Status**: 🔴 1 P0 OPEN | Remaining: 4 P1, 5 P2
**Audit**: 2026-03-07 — Full code re-review of all consumers, GitOps, workers, and event wiring

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Data Consistency Audit](#3-data-consistency-audit)
4. [Event Publishing & Subscription Audit](#4-event-publishing--subscription-audit)
5. [Outbox / Saga / Retry Mechanisms](#5-outbox--saga--retry-mechanisms)
6. [Edge Cases & Risk Points](#6-edge-cases--risk-points)
7. [GitOps Configuration Audit](#7-gitops-configuration-audit)
8. [Worker / Cron Job Audit](#8-worker--cron-job-audit)
9. [Comparison vs Shopify/Shopee/Lazada Standard](#9-comparison-vs-shopifyshopee-lazada-standard)
10. [Issue Tracker](#10-issue-tracker)

---

## 1. Executive Summary

The **Return Service** (`return/`) handles both **returns** and **exchanges** with outbox-based event publishing. The service has solid foundations: transactional outbox for event durability, compensation workers for failed refunds/restocks, idempotent return creation (DB unique index), and real gRPC integrations with Order, Payment, Warehouse, and Shipping services.

**Previous P0 issues (double refund, topic mismatch, missing worker binary) — ALL FIXED.**

**New findings in this audit:**

| Severity | Count | Summary |
|----------|-------|---------|
| 🔴 P0 | 1 | Loyalty-rewards `handleReturnCompleted` method body missing → compile blocker |
| 🟡 P1 | 4 | No stale return cleanup cron, no DLQ worker, missing analytics subscription, exchange compensation gap |
| 🟢 P2 | 5 | Schema drift, exchange price diff, return window per-category, evidence upload, refund to store credit |

---

## 2. Architecture Overview

### Return Service Flow
```
Customer → CreateReturnRequest API
  → Validate eligibility (order status = delivered/completed, 30-day window)
  → Check for duplicate active returns (read + DB unique index)
  → Create return_request + items + outbox event (atomic TX)
  → Outbox Worker polls & publishes event via Dapr PubSub

Admin → ApproveReturn API
  → Generate shipping label (Shipping Service gRPC)
  → Update order status to return_requested (Order Service gRPC)
  → Write return.approved outbox event (atomic TX)

Warehouse → ReceiveItems API
  → Mark items received, apply inspection results
  → Status → processing

Admin → CompleteReturn API (complete)
  → Restock restockable items via Warehouse gRPC
  → Update order status to returned (gRPC)
  → Write return.completed outbox event (atomic TX)
  → Payment Service refunds via orders.return.completed event consumer
  → Order Service updates to returned/partially_returned via event consumer
  → Loyalty-Rewards claws back points via event consumer (BROKEN — see P0-04)
```

### Current Event Flow
```
Return Service PUBLISHES:
  orders.return.requested  → Notification (informational)
  orders.return.approved   → Notification (send label)
  orders.return.rejected   → Notification (rejection reason)
  orders.return.cancelled  → Notification (cancellation)
  orders.return.completed  → Payment (refund), Warehouse (restock),
                             Order (partial/full return status), Loyalty-Rewards (clawback)
  orders.exchange.*        → (no consumer — exchange is processed inline)
  return.refund_retry      → CompensationWorker (internal)
  return.restock_retry     → CompensationWorker (internal)

CONSUMERS (verified matching topics):
  Payment Service      → orders.return.completed → process refund ✅ + DLQ ✅
  Warehouse Service    → orders.return.completed → restock via observer ✅ + idempotency ✅
  Order Service        → orders.return.completed → partial/full return status ✅ + DLQ ✅ (NEW)
  Notification         → orders.return.approved  → send return approved notification ✅
  Notification         → payment.payment.refunded → send refund confirmation ✅
  Loyalty-Rewards      → orders.return.completed → clawback points ❌ BROKEN (handler missing)
```

### gRPC Dependencies
| From (Return) | To | Purpose |
|---|---|---|
| Return → Order | GetOrder, GetOrderItems, UpdateOrderStatus, CreateExchangeOrder |
| Return → Payment | ProcessRefund, GetPaymentStatus |
| Return → Warehouse | RestockItem |
| Return → Shipping | CreateReturnShipment |

---

## 3. Data Consistency Audit

### ✅ What's Working

| Check | Status | Details |
|-------|--------|---------|
| Return + Items + Event atomic | ✅ | `CreateReturnRequest` uses `tm.WithTransaction` (L166-281) |
| Status + Event atomic (update) | ✅ | `UpdateReturnRequestStatus` uses `tm.WithTransaction` (L505-522) |
| Duplicate return prevention | ✅ | Read-before-write (L122-130) + `idx_returns_order_active_unique` partial unique index |
| Idempotent refund requests | ✅ | Idempotency key: `{return_id}:refund` sent to Payment Service (`refund.go:54`) |
| Refund cap to order total | ✅ | `processReturnRefund` caps refund to `order.TotalAmount` (`refund.go:43-47`) |
| Warehouse ID routing | ✅ | `warehouse_id` stored in ReturnItem.Metadata from OrderItem.WarehouseID (`return.go:226-228`) |
| Order partial/full return | ✅ | Order consumer compares returned qty vs total order qty (NEW — `order/return_consumer.go:137-151`) |
| Fallback direct publish | ✅ | `publishLifecycleEventDirect` (L668-686) publishes via Dapr if TX+outbox fails |

### 🟡 Data Consistency Gaps

| # | Issue | Severity | Details |
|---|-------|----------|---------|
| DC-01 | **Schema drift: migration vs model** | 🟢 P2 | Migration `001` creates minimal table but GORM model has 30+ columns. Relies on auto-migration. |
| DC-02 | **Restock + refund not atomic** | 🟡 Info | Restock is synchronous (L458), refund is event-driven via Payment consumer. Items restocked before refund confirmed. Low risk since Payment consumer is reliable. |
| DC-03 | **Order status update dual path** | 🟡 Info | Return service sets order status via gRPC (L464-468), AND Order consumer also sets it via event. Both converge on same status (`returned`/`partially_returned`). Order consumer has correct partial logic; gRPC call always sets `returned`. Minor: gRPC may overwrite `partially_returned` with `returned`. |

---

## 4. Event Publishing & Subscription Audit

### ✅ Topic Name Consistency (ALL MATCH)

| Publisher (Return) | Topic Published | Consumer Service | Topic Subscribed | Match? |
|---|---|---|---|---|
| Return | `orders.return.requested` | *(informational — no consumer needed)* | — | ✅ |
| Return | `orders.return.approved` | Notification | `orders.return.approved` | ✅ |
| Return | `orders.return.rejected` | *(informational)* | — | ✅ |
| Return | `orders.return.cancelled` | *(informational)* | — | ✅ |
| Return | `orders.return.completed` | Payment | `orders.return.completed` | ✅ |
| Return | `orders.return.completed` | Warehouse | `orders.return.completed` | ✅ |
| Return | `orders.return.completed` | Order | `orders.return.completed` | ✅ (NEW) |
| Return | `orders.return.completed` | Loyalty-Rewards | `orders.return.completed` | ✅ topic match, ❌ handler missing |
| Payment | `payment.payment.refunded` | Notification | `payment.payment.refunded` | ✅ |

### ✅ Previously Missing — Now Fixed

| Consumer | Event | Status |
|----------|-------|--------|
| **Order Service** | `orders.return.completed` | ✅ FIXED — `order/internal/data/eventbus/return_consumer.go` processes partial vs full return with DLQ |
| **Loyalty-Rewards** | `orders.return.completed` | ⚠️ WIRED but BROKEN — consumer registered + DLQ, but `handleReturnCompleted` method body doesn't exist |

### 🟡 Still Missing Subscriptions

| Expected Consumer | Event | Status | Impact |
|---|---|---|---|
| **Analytics** | `orders.return.*` | ❌ Not subscribed | No return rate tracking, no refund analytics |

### ✅ Services That Correctly Do NOT Subscribe

| Service | Rationale |
|---------|-----------|
| Return Service | Purely request-driven (REST/gRPC). No inbound event subscriptions needed. ✅ |
| Shipping Service | Return service calls Shipping via gRPC for label generation. No event needed. ✅ |

---

## 5. Outbox / Saga / Retry Mechanisms

### ✅ Outbox Pattern Implementation

| Component | Status | Details |
|-----------|--------|---------|
| Outbox table | ✅ | `outbox_events` table with status, retry_count, trace/span IDs |
| Outbox repository | ✅ | `internal/data/outbox.go` using `common/outbox.Repository` |
| Outbox worker | ✅ | `internal/worker/outbox_worker.go` using `common/outbox.Worker` (batch=50) |
| Publisher bindings | ✅ | `ReturnEventPublisher` implements both `EventPublisher` and `outbox.Publisher` |
| Lifecycle events via outbox | ✅ | All return/exchange lifecycle events go through outbox within DB TX |
| Fallback on TX failure | ✅ | `publishLifecycleEventDirect()` falls back to direct Dapr publish |

### ✅ Compensation Worker

| Component | Status | Details |
|-----------|--------|---------|
| Refund retry | ✅ | `compensation_worker.go` polls `return.refund_retry` events, retries payment |
| Restock retry | ✅ | Polls `return.restock_retry` events, retries warehouse restock |
| Status update after retry | ✅ | Updates `refund_failed` → `completed` and `restock_failed` → `completed` |
| Max retry limit | ✅ | `maxCompensationRetries = 5`. Events exceeding max are moved to `dlq` status |
| Idempotent retries | ✅ | Same idempotency key used for refund retries |
| Separated event types | ✅ | Uses `FetchPendingByTypes` to only fetch compensation events (avoids race with outbox worker) |

### 🟡 Compensation Gaps

| # | Issue | Severity | Details |
|---|-------|----------|---------|
| CW-01 | **Exchange failure not compensated** | 🟡 P1 | `processExchangeOrder` failure at L452-454 is logged as "non-blocking" with no retry event. Exchange customer gets no replacement and no refund. |
| CW-02 | **No DLQ worker for permanently failed outbox events** | 🟡 P1 | Events that fail all outbox retries stay in `failed` status with no alerting or manual resolution path. Other services have DLQ workers. |

---

## 6. Edge Cases & Risk Points

### 🟡 Medium Edge Cases (Open)

| # | Edge Case | Current Handling | Risk |
|---|-----------|-----------------|------|
| E-01 | **Multiple returns for same order (sequential)** | Only one active return allowed (unique index on `pending/approved/processing`). After completion, a new return can be created. | ⚠️ No check if remaining items already returned — second return can re-return items. |
| E-02 | **Return for partially shipped order** | Not handled; eligibility only checks `delivered`/`completed` | Items not yet shipped shouldn't go through return flow. |
| E-03 | **Concurrent admin approval** | No locking on status transition; read → check → write not atomic | Possible double approval → double shipping label. Low probability. |
| E-04 | **Return window boundary** | Uses `time.Since()` server-side | Clock skew between services could allow/deny at boundary. |
| E-05 | **Exchange with price difference** | `PriceDifference: 0` hardcoded in event | No calculation or charge/refund for price differences. |
| E-06 | **Exchange items out of stock** | No stock check before creating exchange order | Exchange order may fail downstream. |
| E-07 | **Restocking fee always 0** | `RestockingFee` on model but no admin API to set it | No mechanism to apply restocking fees. |
| E-08 | **Order status dual-path conflict** | gRPC sets `returned`, Order consumer sets `partially_returned` or `returned` | If gRPC runs first and sets `returned`, Order consumer skips (already terminal). If partial return, gRPC overwrites `partially_returned` with `returned`. |
| E-09 | **Empty return items list** | Not validated in `CreateReturnRequest` | Creating an empty return request is possible. |
| E-10 | **Return for already-refunded cancelled order** | Eligibility checks `delivered`/`completed` ✅ | But doesn't check if order was already fully refunded via cancellation path. |

### 🟢 Low Edge Cases

| # | Edge Case | Risk |
|---|-----------|------|
| E-11 | Item condition not set before completion | `ReceiveItems` now applies inspection results ✅. But if inspection is skipped, defaults to `new`+`restockable=true` — may restock damaged items. |
| E-12 | COD orders may not have `CompletedAt` set | Fail-safe: returns denied if `CompletedAt` is nil ✅. But COD customers can't return. |

---

## 7. GitOps Configuration Audit

### Return Service GitOps (`gitops/apps/return/`)

| Check | Status | Details |
|-------|--------|---------|
| Base kustomization | ✅ | Uses `common-deployment-v2` + `common-worker-deployment-v2` components |
| API patch (ports 8013/9013) | ✅ | `patch-api.yaml` with HTTP+gRPC ports, configMap, secrets |
| Worker patch | ✅ | `patch-worker.yaml` with configMap, secrets, resource limits |
| HPA | ✅ FIXED | `hpa.yaml` with min=2, max=4, CPU 75%, memory 80% |
| PDB (API) | ✅ | `pdb.yaml` present |
| PDB (Worker) | ✅ | `worker-pdb.yaml` present |
| NetworkPolicy | ✅ | `networkpolicy.yaml` present |
| ServiceMonitor | ✅ | present for Prometheus |
| Migration job | ✅ | `migration-job.yaml` present |
| ConfigMap base | ✅ | Complete config with business settings |
| Overlay dev ConfigMap | ✅ | `overlays/dev/configmap.yaml` with all env vars |
| Overlay dev Secrets | ✅ | `overlays/dev/secrets.yaml` ExternalSecret |
| Service account | ✅ | `serviceaccount.yaml` present |
| Infrastructure egress | ✅ | `components/infrastructure-egress` included |

### ✅ All Previous GitOps Gaps Fixed

| # | Gap | Status |
|---|-----|--------|
| G-01 | No separate worker deployment | ✅ FIXED — `common-worker-deployment-v2` + `patch-worker.yaml` |
| G-02 | No HPA | ✅ FIXED — `hpa.yaml` added with proper scaling policies |
| G-03 | No Dapr subscription YAML | ✅ N/A — Return service only publishes, no inbound subscriptions needed |

---

## 8. Worker / Cron Job Audit

### Return Service Workers (running on worker binary)

| Worker | Type | Interval | What it does | Status |
|--------|------|----------|--------------|--------|
| **Outbox Worker** | Continuous | ~1s | Polls `outbox_events` WHERE status='pending', publishes via Dapr | ✅ |
| **Compensation Worker** | Periodic | 5 min | Retries `return.refund_retry` and `return.restock_retry` outbox events | ✅ |

### Consumer Workers in Other Services

| Service | Worker | Type | Event | Status |
|---------|--------|------|-------|--------|
| Payment | ReturnConsumer | Event consumer | `orders.return.completed` | ✅ + DLQ |
| Warehouse | ReturnConsumer | Event consumer | `orders.return.completed` | ✅ + idempotency |
| Order | ReturnConsumer | Event consumer | `orders.return.completed` | ✅ + DLQ (NEW) |
| Notification | ReturnEventConsumer | Event consumer | `orders.return.approved` | ✅ + retry + DLQ |
| Notification | ReturnEventConsumer | Event consumer | `payment.payment.refunded` | ✅ + retry + DLQ |
| Loyalty-Rewards | returnCompletedConsumerWorker | Event consumer | `orders.return.completed` | ❌ BROKEN (P0-04) |
| Loyalty-Rewards | returnCompletedDLQWorker | DLQ drain | `orders.return.completed.dlq` | ✅ wired |

### 🟡 Missing Workers / Cron Jobs

| # | Issue | Severity | Details |
|---|-------|----------|---------|
| W-01 | **No stale return cleanup cron** | 🟡 P1 | Per Shopify/Lazada: `pending` returns after 7 days → auto-cancel; `approved` not shipped after 14 days → auto-cancel. |
| W-02 | **No DLQ worker** | 🟡 P1 | No processing for permanently failed outbox events. Events stuck in `failed` status. |

---

## 9. Comparison vs Shopify/Shopee/Lazada Standard

### Reference: `ecommerce-platform-flows.md` §10

| Flow Step | Reference | Current Implementation | Gap |
|-----------|-----------|----------------------|-----|
| **10.1 Return Request** | ||||
| Buyer initiates return (within window) | ✅ | ✅ 30-day window check via `CompletedAt` | — |
| Return reason selection | ✅ | ✅ Validated: defective, wrong_item, not_as_described, changed_mind, damaged, other | — |
| Photo/video evidence upload | ✅ | ❌ Not implemented | P2 |
| Return eligibility check | ✅ | ✅ Order status + window check | Item-level policy stubbed |
| Seller/platform approval | ✅ | ✅ Admin approval API | No auto-approve for small amounts |
| **10.2 Return Logistics** | ||||
| Return label generation | ✅ | ✅ Via Shipping Service gRPC | — |
| Return tracking | ✅ | ⚠️ Tracking number stored but no tracking event consumption | No return tracking updates |
| Item received at warehouse | ✅ | ✅ ReceiveItems API with inspection | — |
| **10.3 Item Inspection** | ||||
| Condition inspection | ✅ | ✅ Applied via InspectionResult (`return.go:548-560`) | — |
| Disposition decision | ✅ | ⚠️ Only restockable/not | Missing quarantine/destroy |
| **10.4 Refund Processing** | ||||
| Refund to original payment | ✅ | ✅ Via Payment event consumer + compensation retry | — |
| Refund to store credit | ✅ | ❌ Not implemented | P2 |
| Refund timeline | ✅ | ❌ No timeline tracking | P2 |
| Refund confirmation notification | ✅ | ✅ FIXED — `payment.payment.refunded` → Notification | — |
| **10.5 Dispute & Resolution** | ||||
| Buyer escalates dispute | ✅ | ❌ Not implemented | P2 (Roadmap) |
| Mediation | ✅ | ❌ Not implemented | P2 (Roadmap) |
| Chargeback handling | ✅ | ❌ Not implemented | P2 (Roadmap) |

---

## 10. Issue Tracker

### 🔴 P0 — Critical

| ID | Issue | Service | Status | Details |
|----|-------|---------|--------|---------|
| RET-P0-01 | ~~Double refund: direct gRPC + event consumer~~ | return | ✅ FIXED | Removed `processReturnRefund()` from completed case. Refund is event-driven only. |
| RET-P0-02 | ~~Notification topic mismatch~~ | notification | ✅ FIXED | Constants corrected to `orders.return.approved` and `payment.payment.refunded`. |
| RET-P0-03 | ~~No worker binary separation~~ | return | ✅ FIXED | Created `cmd/worker/`, `common-worker-deployment-v2`, worker GitOps. |
| **RET-P0-04** | **Loyalty-rewards `handleReturnCompleted` method body MISSING** | loyalty-rewards | 🔴 OPEN | `consumer.go:72` calls `c.handleReturnCompleted` but the method is not defined anywhere in the codebase. The consumer is wired (`workers.go:105-108,207-208`) and subscribes to `orders.return.completed` with DLQ, but the handler function body does not exist. **This is a compile blocker** — service cannot be built. Loyalty points earned on original order are NOT clawed back on return. |

### 🟡 P1 — High Priority

| ID | Issue | Service(s) | Status | Fix Description |
|----|-------|------------|--------|-----------------|
| RET-P1-01 | ~~Order status not restored on rejection/cancellation~~ | return | ✅ FIXED | Added `orderService.UpdateOrderStatus(orderID, "completed")` on rejection and cancellation. |
| RET-P1-02 | ~~Loyalty points not clawed back on return~~ | loyalty-rewards | ❌ NOT FIXED (see P0-04) | Consumer wired but handler method missing. Previous review incorrectly marked as FIXED. |
| RET-P1-03 | ~~No cancellation event~~ | return | ✅ FIXED | Added `orders.return.cancelled` outbox event. |
| RET-P1-04 | ~~Compensation worker no max retry~~ | return | ✅ FIXED | `maxCompensationRetries = 5`. Events exceeding limit marked `dlq`. |
| RET-P1-05 | ~~Partial return → order status~~ | order | ✅ FIXED | `OrderStatusPartiallyReturned` logic in `order/return_consumer.go:137-151`. |
| **RET-P1-06** | **No stale return cleanup cron** | return | 🟡 OPEN | `pending` returns after 7d and `approved` returns not shipped after 14d should auto-cancel. |
| **RET-P1-07** | **No DLQ worker for failed outbox events** | return | 🟡 OPEN | Events that permanently fail stay in `failed` status with no resolution. |
| **RET-P1-08** | **Exchange failure not compensated** | return | 🟡 OPEN | `processExchangeOrder` failure logged as non-blocking (L452-454) with no retry event. |
| **RET-P1-09** | **Order status dual-path conflict** | return, order | 🟡 OPEN | gRPC always sets `returned`; Order consumer correctly distinguishes `partially_returned`. If gRPC runs first for partial return, it overwrites with wrong terminal status. Should remove gRPC call and rely solely on event-driven Order consumer. |

### 🟢 P2 — Nice to Have

| ID | Issue | Service(s) | Fix Description |
|----|-------|------------|-----------------|
| RET-P2-01 | Migration schema drift | return | Add migration to match full GORM model. Don't rely on auto-migration. |
| RET-P2-02 | ~~Auto-approve for small amounts~~ | return | Implement `auto_approve_limit` config usage (config exists: `100`). |
| RET-P2-03 | ~~Stale return cleanup cron~~ | return | Promoted to P1-06. |
| RET-P2-04 | ~~Add HPA~~ | return (gitops) | ✅ FIXED — `hpa.yaml` added with min=2, max=4. |
| RET-P2-05 | Exchange price difference | return | Calculate and handle price diff between original and exchange products. |
| RET-P2-06 | Evidence upload (photo/video) | return | Add `EvidenceURLs []string` to CreateReturnItemRequest. |
| RET-P2-07 | Refund to store credit option | return, payment | Add `RefundMethod` enum (original, store_credit) per Shopify/Lazada. |
| RET-P2-08 | Return window per category | return, catalog | Configurable `ReturnWindowDays` per product category (e.g., 7d electronics, 30d apparel). |
| RET-P2-09 | Dispute & escalation flow | return | Implement `escalated`, `in_mediation` statuses + admin mediation (§10.5). |

---

## ✅ RESOLVED / FIXED

| Issue | Summary |
|-------|---------|
| RET-P0-01 | Double refund removed — refund is event-driven only via Payment consumer |
| RET-P0-02 | Notification topic constants corrected |
| RET-P0-03 | Worker binary created with GitOps deployment |
| RET-P1-01 | Order status restored on return rejection/cancellation |
| RET-P1-03 | `orders.return.cancelled` event added with outbox |
| RET-P1-04 | Max retry limit (5) added to compensation worker |
| RET-P1-05 | Order service consumer differentiates partial vs full return |
| RET-P2-04 | HPA added to GitOps (`hpa.yaml`) |
| G-01 | Worker deployment via `common-worker-deployment-v2` + `patch-worker.yaml` |
| G-02 | HPA added |
| G-04 | Worker PDB added (`worker-pdb.yaml`) |

---

## 🆕 NEWLY DISCOVERED ISSUES

| Category | Issue | Why it's a problem | Suggested fix |
|----------|-------|---------------------|---------------|
| 🔴 **Compile Blocker** | `handleReturnCompleted` missing in loyalty-rewards | `consumer.go:72` references a non-existent method. Service won't build. Points clawback for returns is completely non-functional. | Implement `handleReturnCompleted` on `LoyaltyConsumer` — unmarshal `ReturnCompletedEvent`, find original earn transaction by order ID, deduct points with source `"order_return"`. |
| 🟡 **Data Consistency** | Order status dual-path for partial returns | Return service gRPC sets `returned` (always full), Order consumer correctly sets `partially_returned`. Race condition if gRPC runs before event. | Remove gRPC `UpdateOrderStatus` call from `return.go:464-468` completed case. Let Order consumer handle it event-only (it already does correctly). |
| 🟡 **Analytics Gap** | No analytics consumer for return events | Return rates, refund amounts, return reasons not tracked. `analytics` service doesn't subscribe to any return events. | Add `orders.return.completed` consumer to analytics service for return rate dashboards. |

---

## Appendix A: File Reference

| What | Path |
|------|------|
| Main business logic | `return/internal/biz/return/return.go` |
| Refund logic | `return/internal/biz/return/refund.go` |
| Restock logic | `return/internal/biz/return/restock.go` |
| Exchange logic | `return/internal/biz/return/exchange.go` |
| Shipping label | `return/internal/biz/return/shipping.go` |
| Status validation | `return/internal/biz/return/validation.go` |
| Event builders | `return/internal/biz/return/events.go` |
| Event publisher | `return/internal/events/publisher.go` |
| Outbox worker | `return/internal/worker/outbox_worker.go` |
| Compensation worker | `return/internal/worker/compensation_worker.go` |
| Worker cmd entry | `return/cmd/worker/main.go` |
| Payment consumer | `payment/internal/data/eventbus/return_consumer.go` |
| Warehouse consumer | `warehouse/internal/data/eventbus/return_consumer.go` |
| Warehouse observer | `warehouse/internal/observer/event/return_completed.go` |
| Order consumer | `order/internal/data/eventbus/return_consumer.go` |
| Order constants | `order/internal/constants/constants.go` |
| Notification consumer | `notification/internal/data/eventbus/return_event_consumer.go` |
| Notification constants | `notification/internal/constants/constants.go` |
| Loyalty-rewards consumer | `loyalty-rewards/internal/worker/event/consumer.go` |
| Loyalty-rewards workers | `loyalty-rewards/internal/worker/workers.go` |
| GitOps base | `gitops/apps/return/base/` |
| GitOps dev overlay | `gitops/apps/return/overlays/dev/` |

## Appendix B: Status Transition Diagram

```
                  ┌──────────┐
                  │ pending  │
                  └────┬─────┘
                  ┌────┼─────────────┐
                  │    │             │
                  ▼    ▼             ▼
            ┌──────────┐   ┌──────────┐   ┌───────────┐
            │ approved │   │ rejected │   │ cancelled │
            └────┬─────┘   └──────────┘   └───────────┘
                 │
                 ▼
            ┌──────────┐
            │processing│
            └────┬─────┘
                 │
           ┌─────┼──────────────┐
           │     │              │
           ▼     ▼              ▼
    ┌──────────┐ ┌──────────────┐ ┌───────────┐
    │completed │ │refund_failed │ │  cancelled│
    └──────────┘ └──────┬───────┘ └───────────┘
                        │
                  (compensation worker)
                        │
                        ▼
                  ┌──────────┐
                  │completed │
                  └──────────┘

    restock_failed → completed (via compensation worker)
    restock_failed → cancelled (manual)
```

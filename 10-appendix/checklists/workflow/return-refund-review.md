# Return & Refund Flows — Business Logic Review Checklist v2

**Reviewed**: 2026-02-26
**Pattern Reference**: Shopify, Shopee, Lazada + `docs/10-appendix/ecommerce-platform-flows.md` §10
**Services Involved**: return, order, payment, warehouse, shipping, notification, loyalty-rewards
**Status**: ✅ ALL P0/P1 FIXED | Remaining: P2-*  
**Audit**: 2026-03-02 — P1-02 (loyalty clawback) verified: `loyalty-rewards/internal/worker/event/return_events.go` + `workers.go:208`. P1-05 (partial return) verified: `order/internal/constants/constants.go:125` `OrderStatusPartiallyReturned`

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

**Critical findings:**

| Severity | Count | Summary |
|----------|-------|---------|
| 🔴 P0 | 3 | Topic name mismatch (notifications never received), double refund path, no worker binary |
| 🟡 P1 | 5 | Missing events to loyalty/order/analytics, no cancellation event, no Dapr subscription YAML |
| 🟢 P2 | 5 | Missing item-level return policy, no auto-approve, schema drift, etc. |

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
  → Update order status to returned
  → Write return.completed outbox event (atomic TX)
  → Payment Service refunds via orders.return.completed event consumer
```

### Current Event Flow
```
Return Service PUBLISHES:
  orders.return.requested  → (no consumer currently)
  orders.return.approved   → (no consumer currently — topic mismatch)
  orders.return.rejected   → (no consumer currently)
  orders.return.completed  → Payment (refund), Warehouse (restock)
  orders.exchange.requested → (no consumer)
  orders.exchange.approved  → (no consumer)
  orders.exchange.completed → (no consumer)
  orders.exchange.order_created → (no consumer)
  return.refund_retry       → CompensationWorker (internal)
  return.restock_retry      → CompensationWorker (internal)

CONSUMERS:
  Payment Service   → orders.return.completed → process refund
  Warehouse Service → orders.return.completed → restock items
  Notification      → return.approved (WRONG TOPIC — never receives)
  Notification      → refund.completed (NEVER published by return service)
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
| Return + Items + Event atomic | ✅ | `CreateReturnRequest` uses `tm.WithTransaction` to atomically create return, items, and outbox event |
| Status + Event atomic (update) | ✅ | `UpdateReturnRequestStatus` uses `tm.WithTransaction` for status change + outbox event |
| Duplicate return prevention | ✅ | Read-before-write check + `idx_returns_order_active_unique` partial unique index |
| Idempotent refund requests | ✅ | Idempotency key: `{return_id}:refund` sent to Payment Service |
| Refund cap to order total | ✅ | `processReturnRefund` caps refund to `order.TotalAmount` |
| Warehouse ID routing | ✅ | `warehouse_id` stored in ReturnItem.Metadata from OrderItem.WarehouseID |

### 🔴 Data Consistency Issues

| # | Issue | Severity | Details |
|---|-------|----------|---------|
| DC-01 | ~~Double refund path~~ | ✅ FIXED | Removed `processReturnRefund()` from `UpdateReturnRequestStatus` completed case. Refund now only goes through Payment consumer via `orders.return.completed` event. |
| DC-02 | **Schema drift: migration vs model** | 🟢 P2 | Migration `001` creates a minimal `return_requests` table but GORM model has 30+ columns. Relies entirely on auto-migration. |
| DC-03 | ~~Order status not rolled back on rejection~~ | ✅ FIXED | Added `orderService.UpdateOrderStatus(orderID, "completed")` on rejection and cancellation. |

---

## 4. Event Publishing & Subscription Audit

### ✅ Topic Name Mismatch (FIXED)

| Publisher (Return Service) | Topic Published | Consumer Service | Topic Subscribed | Match? |
|---|---|---|---|---|
| Return | `orders.return.approved` | Notification | `orders.return.approved` | ✅ FIXED |
| Return | `orders.return.completed` | Payment | `orders.return.completed` | ✅ |
| Return | `orders.return.completed` | Warehouse | `orders.return.completed` | ✅ |
| Payment | `payment.payment.refunded` | Notification | `payment.payment.refunded` | ✅ FIXED |

**Fixed**: Notification constants updated to match published topic names (done in prior session).

### 🟡 Missing Event Subscriptions (P1)

| Expected Consumer | Event | Current Status | Impact |
|---|---|---|---|
| **Order Service** | `orders.return.requested` | ❌ Not subscribed | Order has topic constants defined but no consumer. Could update order status to `return_requested` via event instead of synchronous gRPC. |
| **Order Service** | `orders.return.completed` | ❌ Not subscribed | Order status update to `returned` is done via synchronous gRPC from Return Service. If gRPC fails, order status stays stale. Event-driven fallback needed. |
| **Loyalty-Rewards** | `orders.return.completed` | ❌ Not subscribed | **Loyalty points earned on original order are not clawed back on return.** Per Shopify/Lazada pattern, returned orders should deduct the loyalty points that were earned. |
| **Analytics** | `orders.return.*` | ❌ Not subscribed | No return rate tracking, no refund analytics. |

### 🟡 Missing Event Publications (P1)

| Expected Event | Source | Status | Impact |
|---|---|---|---|
| `orders.return.cancelled` | Return Service | ✅ FIXED | Added `cancelled` case with `orders.return.cancelled` outbox event |
| `payment.payment.refunded` | Payment Service | ✅ EXISTS | Payment publishes `payment.payment.refunded` via outbox; Notification subscribes correctly |

### ✅ Correctly Wired Events

| Event | Publisher | Consumer | Status |
|-------|-----------|----------|--------|
| `orders.return.completed` | Return → Outbox → Dapr | Payment `return_consumer.go` | ✅ Working |
| `orders.return.completed` | Return → Outbox → Dapr | Warehouse `return_consumer.go` | ✅ Working |

---

## 5. Outbox / Saga / Retry Mechanisms

### ✅ Outbox Pattern Implementation

| Component | Status | Details |
|-----------|--------|---------|
| Outbox table | ✅ | `outbox_events` table with status, retry_count, trace/span IDs |
| Outbox repository | ✅ | `internal/data/outbox.go` using `common/outbox.Repository` |
| Outbox worker | ✅ | `internal/worker/outbox_worker.go` using `common/outbox.Worker` (batch=50) |
| Publisher bindings | ✅ | `ReturnEventPublisher` implements both `EventPublisher` and `outbox.Publisher` |
| Lifecycle events via outbox | ✅ | `return.requested`, `return.approved`, `return.rejected`, `return.completed` all go through outbox |
| Fallback on outbox.Save failure | ✅ | `publishLifecycleEventDirect()` falls back to direct Dapr publish |

### ✅ Compensation Worker

| Component | Status | Details |
|-----------|--------|---------|
| Refund retry | ✅ | `compensation_worker.go` polls `return.refund_retry` events, retries payment |
| Restock retry | ✅ | Polls `return.restock_retry` events, retries warehouse restock |
| Status update after retry | ✅ | Updates `refund_failed` → `completed` and `restock_failed` → `completed` |
| Idempotent retries | ✅ | Same idempotency key used for refund retries |

### 🟡 Compensation Gaps

| # | Issue | Severity | Details |
|---|-------|----------|---------|
| CW-01 | **FetchPending race condition** | 🟡 P1 | `compensation_worker.go:94` calls `outboxRepo.FetchPending(ctx, 20)` which returns ALL pending events (lifecycle + compensation). The worker filters client-side, but both outbox worker and compensation worker call `FetchPending` — they may mark the same event as "in-progress" causing duplicate processing or missed events. |
| CW-02 | ~~No max retry limit~~ | ✅ FIXED | Added `maxCompensationRetries = 5`. Events exceeding max retries are moved to `dlq` status. |
| CW-03 | **Exchange failure not compensated** | 🟡 P1 | When exchange order creation fails, it's logged as "non-blocking" with no retry event written to outbox. |

---

## 6. Edge Cases & Risk Points

### 🔴 Critical Edge Cases

| # | Edge Case | Severity | Current Handling | Risk |
|---|-----------|----------|-----------------|------|
| E-01 | ~~Double refund: gRPC + Event~~ | ✅ FIXED | Removed direct `processReturnRefund()` call. Refund is now event-driven only via Payment consumer. |
| E-02 | **Restock succeeds but refund delayed** | 🟡 P1 | Restock happens synchronously on completion, while refund happens asynchronously via event. Items restocked before refund is confirmed. Low risk since Payment consumer is reliable. |
| E-03 | **Partial return → order status incorrectly set to `returned`** | 🟡 P1 | `UpdateReturnRequestStatus` sets `returned` on the order regardless of whether all items were returned. Shopify/Lazada treat this as `partially_returned`. |

### 🟡 Medium Edge Cases

| # | Edge Case | Current Handling | Risk |
|---|-----------|-----------------|------|
| E-04 | Multiple returns for same order (sequential) | Only one active return allowed (unique index on `pending/approved/processing`). After completion, a new return can be created. | ✅ Correct — but no check if remaining items are eligible (already returned items not tracked). |
| E-05 | Return for partially shipped order | Not handled; eligibility only checks `delivered`/`completed` | Items that haven't been shipped yet shouldn't go through return flow. |
| E-06 | Concurrent admin approval | No locking on status transition; status read → check → write is not atomic | Possible double approval → double shipping label, double order status update. Low probability. |
| E-07 | Return window boundary | Uses `time.Since()` which depends on server clock | Clock skew between services could allow or deny returns at the boundary. |
| E-08 | Exchange with price difference | `PriceDifference: 0` hardcoded in event | Price difference between original and exchange item not calculated or charged/refunded. |
| E-09 | Exchange items out of stock | No stock availability check before creating exchange order | Exchange order may fail downstream because replacement item is out of stock. |
| E-10 | Restocking fee calculation | `RestockingFee` stored on model but never set via API | No admin API to set restocking fee. Always 0. |

### 🟢 Low Edge Cases

| # | Edge Case | Risk |
|---|-----------|------|
| E-11 | Empty return items list | Validated only in restock; `CreateReturnRequest` with 0 items creates an empty return request. |
| E-12 | Return for a cancelled/refunded order | Eligibility check filters for `delivered`/`completed` status ✅, but doesn't check if order was already fully refunded via cancellation path. |
| E-13 | Item condition not set before completion | `ReceiveItems` defaults `condition="new"` and `restockable=true` — may restock damaged items if inspection skipped. |

---

## 7. GitOps Configuration Audit

### Return Service GitOps (`gitops/apps/return/`)

| Check | Status | Details |
|-------|--------|---------|
| Base deployment | ✅ | Single `return` deployment, ports 8013/9013 |
| Dapr sidecar enabled | ✅ | `dapr.io/enabled: "true"`, `app-id: return`, `app-port: 8013` |
| ConfigMap base | ✅ | Complete config with business settings, warehouse address |
| Overlay dev ConfigMap | ✅ | All env vars configured including external service endpoints |
| Secrets | ✅ | ExternalSecret for `return-secrets` |
| NetworkPolicy | ✅ | Present in base |
| PDB | ✅ | Present in base |
| ServiceMonitor | ✅ | Present for Prometheus scraping |
| Migration job | ✅ | Present in base |

### 🔴 GitOps Gaps

| # | Gap | Severity | Details |
|---|-----|----------|---------|
| G-01 | ~~No separate worker deployment~~ | ✅ FIXED | Created `cmd/worker/main.go`, `cmd/worker/wire.go`, `wire_gen.go`, and `gitops/apps/return/base/worker-deployment.yaml`. Added to kustomization. Dockerfile updated to build worker binary. **Note**: To fully decouple, remove `worker.ProviderSet` from `cmd/return/wire.go` and re-run `wire`. |
| G-02 | **No HPA** | 🟡 P1 | No `hpa.yaml` in base. Other services all have HPA configs. |
| G-03 | **No Dapr subscription YAML** | 🟡 P1 | Return service has no Dapr subscription YAML in gitops (no consumer events). Correct currently since it only publishes. |
| G-04 | **No `networkpolicy.yaml` for worker** | 🟢 P2 | Workers need egress to Payment/Warehouse for compensation retries, but there's no worker-specific NetworkPolicy. |
| G-05 | **external_services config missing from base configmap** | 🟢 P2 | Base `configmap.yaml` does not have `external_services:` section. It's only in overlay env vars, which means `configs/config.yaml` embedded in the configmap is incomplete (missing order/payment/warehouse/shipping endpoints). These are fed via env var substitution, which works but is inconsistent with other services. |

---

## 8. Worker / Cron Job Audit

### Workers Running on Main Binary

| Worker | Type | Interval | What it does |
|--------|------|----------|--------------|
| **Outbox Worker** | Continuous | ~1s (default) | Polls `outbox_events` WHERE status='pending', publishes via Dapr, marks 'processed' |
| **Compensation Worker** | Continuous | 5 minutes | Polls outbox for `return.refund_retry` and `return.restock_retry`, retries failed operations |

### 🔴 Worker Issues

| # | Issue | Severity | Details |
|---|-------|----------|---------|
| W-01 | ~~No dedicated worker binary~~ | ✅ FIXED | Created `cmd/worker/` binary with Wire DI, health server, and graceful shutdown. GitOps deployment and Dockerfile updated. |
| W-02 | **No DLQ worker** | 🟡 P1 | No DLQ processing for failed outbox events. Events that permanently fail stay in `failed` status. Other services have DLQ workers. |
| W-03 | **No cron job for stale return cleanup** | 🟡 P1 | Per Shopify/Lazada, returns that stay in `pending` for too long (e.g., 7 days) should be auto-cancelled. Returns in `approved` but not shipped within 14 days should be auto-cancelled. No such cron exists. |
| W-04 | **No auto-completion cron** | 🟢 P2 | Per ecommerce-platform-flows.md §6.6, orders auto-complete after N days. Similarly, returns in `processing` for too long (received but not completed) should have a timeout. |

---

## 9. Comparison vs Shopify/Shopee/Lazada Standard

### Reference: `ecommerce-platform-flows.md` §10

| Flow Step | Reference | Current Implementation | Gap |
|-----------|-----------|----------------------|-----|
| **10.1 Return Request** | ||||
| Buyer initiates return (within window) | ✅ | ✅ 30-day window check via `CompletedAt` | — |
| Return reason selection | ✅ | ✅ Validated: defective, wrong_item, not_as_described, changed_mind, damaged, other | — |
| Photo/video evidence upload | ✅ | ❌ Not implemented | No media upload capability |
| Return eligibility check | ✅ | ✅ Order status + window check | Item-level policy (hygiene, final sale) is stubbed |
| Seller/platform approval | ✅ | ✅ Admin approval API | No auto-approve for small amounts (config exists but unused) |
| **10.2 Return Logistics** | ||||
| Return label generation | ✅ | ✅ Via Shipping Service gRPC | — |
| Return tracking | ✅ | ⚠️ Tracking number stored but no tracking event consumption | No webhook/event from carrier for return tracking |
| Item received at warehouse | ✅ | ✅ ReceiveItems API | — |
| **10.3 Item Inspection** | ||||
| Condition inspection | ✅ | ⚠️ Basic (condition + restockable flag) | No detailed inspection workflow |
| Disposition decision | ✅ | ⚠️ Only restockable/not | Missing quarantine/destroy dispositions |
| **10.4 Refund Processing** | ||||
| Refund to original payment | ✅ | ✅ Via Payment gRPC + compensation retry | Double refund risk (P0) |
| Refund to store credit | ✅ | ❌ Not implemented | Only original payment method |
| Refund timeline | ✅ | ❌ No timeline tracking | No SLA enforcement |
| Refund confirmation notification | ✅ | ❌ Topic mismatch prevents notification | P0 |
| **10.5 Dispute & Resolution** | ||||
| Buyer escalates dispute | ✅ | ❌ Not implemented | No dispute/escalation flow |
| Mediation | ✅ | ❌ Not implemented | — |
| Chargeback handling | ✅ | ❌ Not implemented | — |

---

## 10. Issue Tracker

### 🔴 P0 — ✅ ALL FIXED

| ID | Issue | Status | Fix Applied |
|----|-------|--------|-------------|
| RET-P0-01 | Double refund: direct gRPC + event consumer | ✅ FIXED | Removed `processReturnRefund()` from `return.go` completed case. Refund now only via Payment consumer on `orders.return.completed`. |
| RET-P0-02 | Notification topic mismatch | ✅ FIXED | Notification constants already corrected to `orders.return.approved` and `payment.payment.refunded`. |
| RET-P0-03 | No worker binary separation | ✅ FIXED | Created `cmd/worker/{main.go,wire.go}`, `worker-deployment.yaml`, updated kustomization and Dockerfile. |

### 🟡 P1 — Partially Fixed

| ID | Issue | Status | Fix Description |
|----|-------|--------|-----------------|
| RET-P1-01 | Order status not restored on rejection/cancellation | ✅ FIXED | Added `orderService.UpdateOrderStatus(orderID, "completed")` on rejection and cancellation. |
| RET-P1-02 | ~~**Loyalty points not clawed back on return**~~ | ✅ FIXED | `return_events.go:30` in loyalty-rewards + `workers.go:208` wires consumer + DLQ |
| RET-P1-03 | No cancellation event | ✅ FIXED | Added `cancelled` case with `orders.return.cancelled` event, `ReturnCancelledEvent` struct, and `PublishReturnCancelled`. |
| RET-P1-04 | Compensation worker no max retry | ✅ FIXED | Added `maxCompensationRetries = 5`. Events exceeding limit are marked `dlq`. |
| RET-P1-05 | ~~**Partial return → order status**~~ | ✅ FIXED | `OrderStatusPartiallyReturned` in `order/constants.go:125` + `processReturnCompleted` in `return_consumer.go:116` |

### 🟢 P2 — Nice to Have

| ID | Issue | Service(s) | Fix Description |
|----|-------|------------|-----------------|
| RET-P2-01 | Migration schema drift | return | Add migration to match full GORM model (all 30+ columns). Don't rely on auto-migration in production. |
| RET-P2-02 | Auto-approve for small amounts | return | Implement `auto_approve_limit` config usage. Auto-approve returns under threshold (config already exists: `100`). |
| RET-P2-03 | Stale return cleanup cron | return | Add cron job: auto-cancel `pending` returns after 7 days, `approved` returns not shipped after 14 days. |
| RET-P2-04 | Add HPA | return (gitops) | Add `hpa.yaml` like other services. |
| RET-P2-05 | Exchange price difference | return | Calculate and handle price differences between original and exchange products. |

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
| Worker server | `return/internal/server/worker_server.go` |
| Service layer | `return/internal/service/return.go` |
| Data models | `return/internal/model/return.go` |
| Config | `return/internal/config/config.go` |
| Payment consumer | `payment/internal/data/eventbus/return_consumer.go` |
| Warehouse consumer | `warehouse/internal/data/eventbus/return_consumer.go` |
| Notification consumer | `notification/internal/data/eventbus/return_event_consumer.go` |
| Notification constants | `notification/internal/constants/constants.go` |
| GitOps base | `gitops/apps/return/base/` |
| GitOps dev overlay | `gitops/apps/return/overlays/dev/` |
| Migrations | `return/migrations/` |

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

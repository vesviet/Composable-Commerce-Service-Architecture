# Order Lifecycle Flows — Business Logic Review Checklist

**Date**: 2026-03-07 (v5 — all P0/P1/P2 fixes applied)
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase deep-dive)
**Scope**: `order/`, `fulfillment/`, `payment/`, `warehouse/`, `shipping/`, `return/`, `checkout/`, `loyalty-rewards/`, `promotion/` — event coordination, saga, outbox, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §6 (Order Lifecycle)
**Previous Version**: `order-lifecycle-deep-review.md` (v4, 2026-03-07)

---

## 📊 Summary (v4 Snapshot — 2026-03-07)

| Category | Count | Status |
|----------|-------|--------|
| 🔴 P0 — Fixed this session (v5) | **2** | ✅ FIXED |
| 🟡 P1 — Fixed this session (v5) | **3** | ✅ FIXED |
| 🔵 P2 — Fixed this session (v5) | **3** | ✅ FIXED |
| 🔴 P0 — Previously fixed (v3) | 1 (P0-2025-01) | ✅ |
| 🟡 P1 — Previously fixed (v3) | 4 (P1-2025-01..04) | ✅ |
| 🔵 P2 — Previously fixed (v3) | 8 | ✅ |
| ✅ Verified Working | 50+ areas | — |

---

## ✅ P0 — CRITICAL (FIXED in v5)

### P0-2026-01: Payment Service Subscribes to Dead Topic `orders.order.completed`

**Impact**: Escrow release and seller payout are **NEVER triggered** by event. Financial risk — sellers never receive payment.

**Root Cause**:
- Payment worker registers `OrderCompletedConsumer.ConsumeOrderCompleted()` → subscribes to topic `orders.order.completed`
- Order service **ONLY** publishes `orders.order.status_changed` via outbox (`saveStatusChangedToOutbox`)
- `PublishOrderCompleted()` was confirmed as dead code and **removed** in v1.1.9
- The `orders.order.completed` topic is **NEVER published** by any service
- `TopicOrderCompleted` constant still exists in `order/internal/constants/constants.go:14` but is unused in publishing

**Evidence**:
```
// Payment subscribes to:
Topic: "orders.order.completed" ← NEVER published by any service

// Order only publishes:
Topic: "orders.order.status_changed" (via outbox, always)
```

**Affected Files**:
- `payment/internal/data/eventbus/order_completed_consumer.go` — change topic to `orders.order.status_changed`, filter by `new_status == "delivered"/"completed"`
- `payment/internal/worker/event/event_consumer_worker.go` — update registration
- `gitops/apps/payment/base/` — add Dapr subscription YAML if needed (currently missing)

**Fix**: ✅ **FIXED** — Merged `OrderCompletedConsumer` + `OrderConsumer` → unified `OrderStatusChangedConsumer` subscribing to `orders.order.status_changed`, routing by `new_status`:
- `cancelled` → void payments
- `delivered`/`completed` → escrow release
- Added `GormIdempotencyHelper` with key `payment_order_status:{orderID}_{newStatus}`
- Deleted `order_completed_consumer.go` and `order_consumer.go`
- Wire regenerated, `go build ./...` clean
- GitOps: `dapr-subscription.yaml` created with `orders.order.status_changed` + `orders.return.completed`

---

### P0-2026-02: Payment Service Subscribes to Dead Topic `orders.order.cancelled`

**Impact**: Payment void on order cancellation is **NEVER triggered** by event. Authorized payments remain held on customer cards indefinitely.

**Root Cause**:
- Payment worker registers `OrderConsumer.ConsumeOrderCancelled()` → subscribes to topic `orders.order.cancelled`
- Order `cancel.go:120` calls `saveStatusChangedToOutbox()` with status `"cancelled"` → writes to `orders.order.status_changed`, NOT `orders.order.cancelled`
- `PublishOrderCancelled()` was confirmed as dead code and **removed** in v1.1.9
- Zero grep results for `HandleOrderCancelled` or `TopicOrderCancelled` being used in order's internal publishing logic

**Evidence**:
```
// Payment subscribes to:
Topic: "orders.order.cancelled" ← NEVER published by Order service

// Order publishes on cancel:
cancel.go:120 → saveStatusChangedToOutbox(txCtx, order, oldStatus, "cancelled", req.Reason)
→ Topic: "orders.order.status_changed" (not orders.order.cancelled)
```

**Affected Files**:
- `payment/internal/data/eventbus/order_consumer.go` — change topic to `orders.order.status_changed`, filter by `new_status == "cancelled"`
- `payment/internal/worker/event/event_consumer_worker.go` — update registration
- `gitops/apps/payment/base/` — add Dapr subscription YAML

**Fix**: ✅ **FIXED** — Same unified consumer as P0-2026-01. `OrderStatusChangedConsumer.HandleOrderStatusChanged()` filters `new_status == "cancelled"` and calls `voidAuthorizedPayments()`. Old `OrderConsumer` deleted.

> [!CAUTION]
> **Both P0-2026-01 and P0-2026-02** are the exact same class of bug as the previously fixed P0-2025-01 (Loyalty dead topic). The fix pattern is identical: subscribe to `orders.order.status_changed` and filter by `new_status`. This needs to be applied to ALL consumers of specific order lifecycle events.

---

## ✅ P1 — HIGH (FIXED in v5)

### P1-2026-01: Order Status `completed` Not Reachable from `delivered`

**Impact**: Orders can never reach `completed` status. Per Shopify/Shopee pattern (§6.6), delivered orders should auto-complete after N days (escrow release, loyalty points, review trigger).

**Current State** (`order/internal/constants/constants.go:181`):
```go
OrderStatusDelivered: {OrderStatusPartiallyReturned, OrderStatusReturned, OrderStatusRefunded},
```
- ❌ `"completed"` is NOT in the allowed transitions from `delivered`
- ❌ No `OrderStatusCompleted` constant defined (only `OrderStatusDelivered`)
- Fulfillment `AutoCompleteShippedWorker` marks fulfillment as completed → triggers `fulfillments.fulfillment.status_changed` → mapped to order `shipped`, NOT `completed`

**Fix**: ✅ **FIXED** — Added `OrderStatusCompleted = "completed"` constant and added `OrderStatusCompleted` to `OrderStatusTransitions[OrderStatusDelivered]`. Also added to `StatusHierarchy` as terminal (`-1`). Removed dead constants `TopicOrderCompleted`/`TopicOrderCancelled` and dead event types. `go build ./...` clean.

---

### P1-2026-02: Loyalty Dapr Subscription YAML Missing `orders.return.completed`

**Impact**: Loyalty worker code subscribes to `orders.return.completed` via `ConsumeReturnCompleted()` (for points clawback on return), but the GitOps Dapr subscription YAML does NOT declare this topic. Event delivery depends on runtime programmatic subscription working correctly — no YAML-level routing guarantee.

**Current State**:
- `loyalty-rewards/internal/worker/event/consumer.go:64-74` — code calls `AddConsumerWithMetadata("orders.return.completed", ...)` ✅
- `gitops/apps/loyalty-rewards/base/dapr-subscription.yaml` — only 3 topics: `customer.created`, `orders.order.status_changed`, `customer.deleted` ❌
- Missing subscription for `orders.return.completed`
- Also missing DLQ subscription `orders.return.completed.dlq` in YAML

**Fix**: ✅ **FIXED** — Added `loyalty-rewards-return-completed` subscription entry for `orders.return.completed` with DLQ `dlq.orders.return.completed` and `maxRetryCount: "3"` to `gitops/apps/loyalty-rewards/base/dapr-subscription.yaml`.

---

### P1-2026-03: Payment Worker Missing Dapr Subscription YAML

**Impact**: Payment worker subscribes to 3 topics programmatically (`orders.return.completed`, `orders.order.cancelled`, `orders.order.completed`) but has NO `dapr-subscription.yaml` file in GitOps. Relies entirely on programmatic subscription via `AddConsumer()`.

**Current GitOps** (`gitops/apps/payment/base/`):
- ❌ No `dapr-subscription.yaml` present
- Worker uses common template with HTTP health on `:8081` but patches to `dapr.io/app-port: "5005"` + `grpc`
- The Dapr sidecar will deliver events to `:5005` (gRPC), but common template health probes use HTTP `:8081`
- Health probes and Dapr port are correctly separated (Dapr uses app-port, probes use container port)

**Fix**: ✅ **FIXED** — Created `gitops/apps/payment/base/dapr-subscription.yaml` with subscriptions for `orders.order.status_changed` and `orders.return.completed` (with DLQs and `maxRetryCount: "3"`). Added to `kustomization.yaml` resources.

---

## ✅ P2 — MEDIUM (FIXED in v5)

### P2-2026-01: Payment `HandleOrderCancelled` Missing Idempotency Guard

**Status**: ✅ **FIXED** — `OrderStatusChangedConsumer` includes `GormIdempotencyHelper` with `CheckAndMark` wrapping all handler logic. Idempotency key: `payment_order_status:{orderID}_{newStatus}`.

---

### P2-2026-02: Payment `HandleOrderCompleted` Missing Idempotency Guard

**Status**: ✅ **FIXED** — Same idempotency helper as P2-2026-01, keyed on `payment_order_status:{orderID}_{newStatus}` where `newStatus` is `delivered` or `completed`.

---

### P2-2026-03: Dead Constants — `TopicOrderCompleted` / `TopicOrderCancelled`

**Status**: ✅ **FIXED** — Removed `TopicOrderCompleted`, `TopicOrderCancelled` from `order/internal/constants/constants.go`. Removed `EventTypeOrderCompleted`, `EventTypeOrderCancelled`. Removed backward-compat re-exports and dead event structs (`OrderCompletedEvent`, `OrderCancelledEvent`) from `order/internal/events/order_events.go`. `go build ./...` clean.

---

## ✅ Previously Fixed (All Prior P0s + P1s from v3)

| ID | Issue | Fix Confirmed? |
|----|-------|----------------|
| **P0-2025-01** | Loyalty service topic mismatch (orders.order.completed/cancelled never published) | ✅ Loyalty now subscribes to `orders.order.status_changed` with `new_status` filter |
| **P1-2025-01** | Promotion worker GitOps — startupProbe + volumeMounts + Dapr protocol | ✅ Fixed (common-worker-deployment-v2 + patch) |
| **P1-2025-02** | Loyalty worker GitOps — config volumeMount | ✅ Fixed via kustomization patches |
| **P1-2025-03** | Promotion `HandleOrderStatusChanged` — no idempotency | ✅ `GormIdempotencyHelper` added (commit `8837225`) |
| **P1-2025-04** | `publishStockCommittedEvent` outside transaction — accepted risk | ✅ Documented |
| **P2-2025-01** | `StockCommittedConsumer` audit-only | ✅ `StockReconciliationJob` added |
| **P2-2025-02** | Dead code `PublishOrderCompleted`/`PublishOrderCancelled` methods | ✅ Removed from publisher.go |
| **P2-CANCEL-QUERY** | `ReservationCleanupJob` unbounded query | ✅ Cursor-based pagination |
| **P2-FULFILLED-IDEM** | `ShipmentDeliveredConsumerWorker` no idempotency | ✅ GormIdempotencyHelper added |
| **No HPA for workers** | Order, warehouse, fulfillment workers missing HPA | ✅ HPA added |
| **SLA breach cron** | No SLA breach monitoring | ✅ `SLABreachDetectorJob` added |
| **P2-SCHEMA-DRIFT** | No shared event schema registry | ⚠️ Accepted risk |

---

## 📋 Event Publishing Necessity Check

### Services That PUBLISH Events — Justified?

| Service | Event Topic | Consumers | Status |
|---------|-------------|-----------|--------|
| Order | `orders.order.status_changed` (outbox) | Fulfillment, Warehouse, Loyalty, Promotion, Notification | ✅ Essential |
| Order | `inventory.stock.committed` (outbox) | Warehouse (audit → reconciliation) | ✅ Justified |
| Order | `orders.payment.capture_requested` | Order self-loop (Dapr consumer) | ✅ Essential |
| Order | `orders.return.*` (requested/approved/rejected/completed) | Warehouse, Payment, Fulfillment | ✅ Essential |
| Payment | `payment.payment.processed` | Order | ✅ Essential |
| Payment | `payment.payment.failed` | Order | ✅ Essential |
| Payment | `payment.payment.refunded` | Order | ✅ Essential |
| Fulfillment | `fulfillments.fulfillment.status_changed` (outbox) | Order, Warehouse | ✅ Essential |
| Fulfillment | `fulfillment.picklist_status_changed` | Fulfillment (self-loop) | ✅ Essential |
| Fulfillment | `fulfillment.package_status_changed` | Shipping | ✅ Essential |
| Warehouse | `warehouse.inventory.reservation_expired` | Order | ✅ Essential |
| Shipping | `shipping.shipment.delivered` | Order, Fulfillment | ✅ Essential |
| Promotion | — | — | N/A — consumer only |
| Loyalty | — | — | N/A — consumer only |

### Dead Topics Still Defined

```
order/constants.go:14  TopicOrderCompleted = "orders.order.completed"  → Never published
order/constants.go:17  TopicOrderCancelled = "orders.order.cancelled" → Never published
```

---

## 📋 Event Subscription Necessity Check

### Order Worker Subscriptions

| Topic | Handler | Needed? | Idempotency? |
|-------|---------|---------|--------------|
| `payment.payment.processed` | `HandlePaymentConfirmed` | ✅ | ✅ |
| `payment.payment.failed` | `HandlePaymentFailed` | ✅ | ✅ |
| `orders.payment.capture_requested` | `HandlePaymentCaptureRequested` | ✅ | ✅ |
| `fulfillments.fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ | ✅ |
| `warehouse.inventory.reservation_expired` | `HandleReservationExpired` | ✅ | ✅ |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ | ✅ |
| `payment.payment.refunded` | `ConsumeRefundCompleted` | ✅ | ✅ |
| `*.dlq` (7 topics) | DLQ drain (log + ACK) | ✅ | N/A |

### Payment Worker Subscriptions

| Topic | Handler | Needed? | Status |
|-------|---------|---------|--------|
| `orders.return.completed` | `HandleReturnCompleted` | ✅ Yes — refund on return | ✅ Working |
| `orders.order.cancelled` | `HandleOrderCancelled` | ✅ Yes — void authorized payment | 🔴 **BROKEN** — dead topic (P0-2026-02) |
| `orders.order.completed` | `HandleOrderCompleted` | ✅ Yes — escrow release | 🔴 **BROKEN** — dead topic (P0-2026-01) |

### Fulfillment Worker Subscriptions

| Topic | Handler | Needed? | Idempotency? |
|-------|---------|---------|--------------|
| `orders.order.status_changed` | `HandleOrderStatusChanged` | ✅ | ✅ |
| `fulfillment.picklist_status_changed` | `HandlePicklistStatusChanged` | ✅ | ✅ |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ | ✅ Fixed |

### Warehouse Worker Subscriptions

| Topic | Handler | Needed? | Idempotency? |
|-------|---------|---------|--------------|
| `fulfillments.fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ | ✅ |
| `orders.order.status_changed` | `HandleOrderStatusChanged` | ✅ | ✅ |
| `orders.return.completed` | `HandleReturnCompleted` | ✅ | ✅ |
| `catalog.product.created` | `HandleProductCreated` | ✅ | ✅ |
| `inventory.stock.committed` | `HandleStockCommitted` | ⚠️ Audit + reconciliation | N/A |

### Shipping Worker Subscriptions

| Topic | Handler | Needed? | Idempotency? |
|-------|---------|---------|--------------|
| `fulfillment.package_status_changed` | `HandlePackageStatusChanged` | ✅ | ✅ |
| `order.cancelled` | `HandleOrderCancelled` | ✅ | ✅ |

### Loyalty Worker Subscriptions

| Topic | Handler | Needed? | Idempotency? | Status |
|-------|---------|---------|--------------|--------|
| `customer.created` | `handleCustomerCreated` | ✅ | N/A | ✅ |
| `orders.order.status_changed` | `handleOrderStatusChanged` | ✅ | ✅ `TransactionExists` | ✅ Fixed (v3) |
| `customer.deleted` | `handleCustomerDeleted` | ✅ | N/A | ✅ |
| `orders.return.completed` | `handleReturnCompleted` | ✅ | ✅ | ⚠️ Code OK, Dapr YAML missing (P1-2026-02) |

### Promotion Worker Subscriptions

| Topic | Handler | Needed? | Idempotency? |
|-------|---------|---------|--------------|
| `orders.order.status_changed` | `HandleOrderStatusChanged` | ✅ | ✅ `GormIdempotencyHelper` |

---

## 📋 Worker & Cron Job Checks

### Order Worker (`order/cmd/worker/`)

| Component | Type | Status | Notes |
|-----------|------|--------|-------|
| `OutboxWorker` | Outbox | ✅ | 1s poll, 50 batch, PROCESSING mark, 10 retries, 30-day cleanup |
| `EventConsumersWorker` | Event | ✅ | All consumers + 7 DLQ drain |
| `CODAutoConfirmJob` | Cron | ✅ | 1m, 2-pass confirm+cancel |
| `CaptureRetryJob` | Cron | ✅ | 1m, exp backoff, DLQ on exhaustion |
| `PaymentCompensationJob` | Cron | ✅ | 2m, void auth, DLQ+alert |
| `ReservationCleanupJob` | Cron | ✅ | 15m, cursor-based pagination |
| `OrderCleanupJob` | Cron | ✅ | 15m, parallel (10 concurrent) |
| `FailedCompensationsCleanupJob` | Cron | ✅ | Old DLQ cleanup |
| `DLQRetryWorker` | Cron | ✅ | 5m, 5 op types, exp backoff max 30m |

### Payment Worker (`payment/cmd/worker/`)

| Component | Type | Status | Notes |
|-----------|------|--------|-------|
| `ReturnConsumer` | Event | ✅ | `orders.return.completed` → refund |
| `OrderConsumer` | Event | 🔴 | `orders.order.cancelled` → void — **BROKEN** (dead topic, P0-2026-02) |
| `OrderCompletedConsumer` | Event | 🔴 | `orders.order.completed` → escrow — **BROKEN** (dead topic, P0-2026-01) |
| `OutboxWorker` | Outbox | ✅ | Payment event publishing |
| Cron jobs | Cron | ✅ | AutoCapture, BankTransferExpiry, Cleanup, FailedRetry, Reconciliation, StatusSync, RefundProcessing |
| `WebhookRetryWorker` | Worker | ✅ | Retry failed webhook deliveries |

### Fulfillment Worker (`fulfillment/cmd/worker/`)

| Component | Type | Status | Notes |
|-----------|------|--------|-------|
| `OrderStatusConsumerWorker` | Event | ✅ | Topic via constant; idempotency |
| `PicklistStatusConsumerWorker` | Event | ✅ | Idempotency |
| `ShipmentDeliveredConsumerWorker` | Event | ✅ | Idempotency added |
| `AutoCompleteShippedWorker` | Cron | ✅ | 1h, 7-day threshold, batch 50 |
| `SLABreachDetectorJob` | Cron | ✅ | 30m, 6 active statuses |

### Warehouse Worker (`warehouse/cmd/worker/`)

| Component | Type | Status | Notes |
|-----------|------|--------|-------|
| `OutboxWorker` | Outbox | ✅ | |
| `FulfillmentStatusConsumer` | Event | ✅ | Idempotency |
| `OrderStatusConsumer` | Event | ✅ | Idempotency |
| `ReturnConsumer` | Event | ✅ | |
| `StockCommittedConsumer` | Event | ⚠️ | Audit + reconciliation via `StockReconciliationJob` |
| `ExpiryWorker` | Worker | ✅ | Reservation TTL enforcement |
| `ImportWorker` | Worker | ✅ | |
| Cron jobs (9) | Cron | ✅ | All operational |

### Shipping Worker (`shipping/cmd/worker/`)

| Component | Type | Status | Notes |
|-----------|------|--------|-------|
| `OutboxWorker` | Outbox | ✅ | |
| `PackageStatusConsumer` | Event | ✅ | Idempotency |
| `OrderCancelledConsumer` | Event | ✅ | Idempotency |

### Loyalty Worker (`loyalty-rewards/cmd/worker/`)

| Component | Type | Status | Notes |
|-----------|------|--------|-------|
| `ConsumeOrderStatusChanged` | Event | ✅ | Fixed (v3) — `orders.order.status_changed` |
| `ConsumeCustomerCreated` | Event | ✅ | |
| `ConsumeCustomerDeleted` | Event | ✅ | |
| `ConsumeReturnCompleted` | Event | ⚠️ | Code OK — Dapr YAML missing (P1-2026-02) |
| `ConsumeReturnCompletedDLQ` | Event | ⚠️ | Code OK — Dapr YAML missing |

### Promotion Worker (`promotion/internal/`)

| Component | Type | Status | Notes |
|-----------|------|--------|-------|
| `OrderConsumer` | Event | ✅ | `orders.order.status_changed`; `GormIdempotencyHelper` |
| `OrderConsumerDLQ` | Event | ✅ | DLQ drain |

---

## 📋 Saga / Outbox / Retry Correctness

| Check | Status | Notes |
|-------|--------|-------|
| Order create → outbox (atomic tx) | ✅ | `create.go:77-134` |
| Cancel → outbox (atomic tx) | ✅ | `cancel.go:108-126` |
| Payment confirmed → UpdateOrderStatus | ✅ | Triggers outbox in `UpdateOrderStatus` |
| Payment confirmed → ConfirmReservations | ✅ | `payment_consumer.go:418`; rollback on partial failure; DLQ on error |
| Payment failed → ReleaseReservations + DLQ | ✅ | 3-retry per reservation; DLQ with reservation IDs |
| Fulfillment cancelled → CancelOrder | ✅ | `fulfillment_consumer.go:143` |
| DLQ retry: void_authorization | ✅ | |
| DLQ retry: release_reservations | ✅ | Reads `reservation_ids` from `CompensationMetadata` |
| DLQ retry: refund | ✅ | |
| DLQ retry: payment_capture | ✅ | |
| DLQ retry: refund_restock | ✅ | `ReturnCompensationWorker` |
| DLQ retry: alert on exhaustion | ✅ | `triggerAlert` + `alertService` |
| Outbox worker: PROCESSING mark | ✅ | |
| Outbox worker: 10 retries | ✅ | |
| Outbox worker: 30-day cleanup | ✅ | |
| Webhook idempotency | ✅ | Redis state machine in payment service |
| Order event consumer idempotency | ✅ | All consumers |
| Warehouse event consumer idempotency | ✅ | All consumers |
| Shipping event consumer idempotency | ✅ | Applied |
| Fulfillment picklist idempotency | ✅ | |
| Fulfillment shipmentDelivered idempotency | ✅ | Fixed |
| Promotion event idempotency | ✅ | `GormIdempotencyHelper` |
| Loyalty event idempotency | ✅ | `TransactionExists` |
| **Payment event idempotency (cancelled)** | ❌ | **MISSING** — P2-2026-01 |
| **Payment event idempotency (completed)** | ❌ | **MISSING** — P2-2026-02 |
| Fulfillment status backward guard | ✅ | `constants.IsLaterStatus` |
| ConfirmOrderReservations rollback | ✅ | |
| `publishStockCommittedEvent` (outbox) | ⚠️ | Outside transaction — accepted risk |
| Checkout reservation rollback | ✅ | `RollbackReservationsMap` + void |
| **Payment void on order cancel — via event** | 🔴 | **BROKEN** — dead topic (P0-2026-02) |
| **Escrow release on order complete — via event** | 🔴 | **BROKEN** — dead topic (P0-2026-01) |

---

## 📋 GitOps Config Checks

### Order Worker
| Check | Status |
|-------|--------|
| Dapr: `app-id: order-worker`, `app-port: 5005`, `grpc` | ✅ |
| Health probes: HTTP `:8081` + startup tcp `:5005` | ✅ |
| Config, secrets, resources, initContainers | ✅ |
| HPA | ✅ |

### Payment Worker
| Check | Status |
|-------|--------|
| Dapr: `app-port: 5005`, `grpc` (via patch) | ✅ |
| Common template health probes: HTTP `:8081` | ✅ (probes = HTTP, Dapr = gRPC — correct separation) |
| Config, secrets, resources, initContainers | ✅ |
| Dapr subscription YAML | ❌ **MISSING** (P1-2026-03) |
| HPA | ✅ |

### Warehouse Worker
| Check | Status |
|-------|--------|
| Dapr, probes, config, secrets, resources | ✅ |
| HPA | ✅ |

### Fulfillment Worker
| Check | Status |
|-------|--------|
| Dapr, probes, config, secrets, resources | ✅ |
| HPA | ✅ |

### Promotion Worker
| Check | Status |
|-------|--------|
| Dapr: `app-port: 5005`, `grpc` | ✅ Fixed (v3) |
| startupProbe, volumeMounts | ✅ Fixed (v3) |
| HPA | ✅ |

### Loyalty Worker
| Check | Status |
|-------|--------|
| Dapr: `app-port`, `grpc` | ✅ Fixed (v3) via common-worker-deployment-v2 + kustomization |
| Probes: via common template | ✅ |
| Config volume: via kustomization | ✅ Fixed (v3) |
| Dapr subscription YAML topics match code | ⚠️ **Partial** — missing `orders.return.completed` (P1-2026-02) |
| HPA | ✅ |

### Shipping Worker
| Check | Status |
|-------|--------|
| Dapr, probes, config, secrets | ✅ |

---

## 📋 Data Consistency Matrix — Full Cross-Service

| Data Pair | Consistency Level | Risk |
|-----------|-----------------|------|
| Order DB ↔ Outbox events | ✅ Atomic (same TX) | Minimal |
| Order status ↔ Payment status | ✅ Eventually consistent | |
| Order status ↔ Fulfillment status | ✅ Eventually consistent | |
| Warehouse reservation ↔ Order item | ⚠️ Accepted risk | TTL + `ReservationCleanupWorker` |
| Checkout stock reservation ↔ Payment auth | ✅ Correct ordering | |
| Warehouse stock ↔ Order paid | ✅ Fixed | |
| DLQ compensation ↔ Reservation IDs | ✅ Fixed | |
| COD order lifecycle ↔ Time window | ✅ Fixed | |
| Return restock ↔ Warehouse stock | ✅ RESOLVED | |
| Promotion usage ↔ Order lifecycle | ✅ Handled + idempotent | |
| Loyalty points ↔ Order lifecycle | ✅ Fixed (v3) | |
| Loyalty points ↔ Return completed | ⚠️ Code OK, Dapr YAML gap | P1-2026-02 |
| **Payment escrow ↔ Order completion** | 🔴 **BROKEN** | **P0-2026-01** |
| **Payment void ↔ Order cancellation** | 🔴 **BROKEN** | **P0-2026-02** |

---

## 📋 Edge Cases Not Yet Handled

| Edge Case | Risk | Status |
|-----------|------|--------|
| **Payment never voids authorized amount on order cancel** | 🔴 Critical | **P0-2026-02** |
| **Seller never receives escrow payout on order complete** | 🔴 Critical | **P0-2026-01** |
| **Delivered order cannot transition to `completed`** | 🟡 High | **P1-2026-01** — missing status transition |
| Order with items from 2+ warehouses; partial fulfillment | 🟡 High | No partial-fulfillment split-order support |
| Capture payment fails with auth expiry; order stuck | 🟡 High | DLQ + Ops alert |
| Return completed → loyalty clawback event not routed by Dapr | 🟡 Medium | **P1-2026-02** |
| `OrderStatusChangedEvent` schema evolution | 🔵 Medium | JSON omitempty, accepted risk |
| Multiple replicas of `CODAutoConfirmJob` | 🟡 Medium | Worker replicas=1 |
| Return restock falls back to `"default"` warehouse_id | 🔵 Low | `restock.go:47` |

---

## 📋 Remediation Actions

### 🔴 Fix Now (Data Loss / Financial Risk)

- [ ] **P0-2026-01**: Payment `OrderCompletedConsumer` → change to subscribe to `orders.order.status_changed`, filter `new_status == "delivered"/"completed"` for escrow release
- [ ] **P0-2026-02**: Payment `OrderConsumer` → change to subscribe to `orders.order.status_changed`, filter `new_status == "cancelled"` for payment void

### 🟡 Fix Soon (Reliability)

- [ ] **P1-2026-01**: Add `completed` to `OrderStatusTransitions[delivered]` OR document that `delivered` is the terminal happy state
- [ ] **P1-2026-02**: Add `orders.return.completed` (+ DLQ) to loyalty Dapr subscription YAML
- [ ] **P1-2026-03**: Create `dapr-subscription.yaml` for payment worker with correct topics

### 🔵 Monitor / Document

- [ ] **P2-2026-01**: Add idempotency guard to Payment `HandleOrderCancelled`
- [ ] **P2-2026-02**: Add idempotency guard to Payment `HandleOrderCompleted`
- [ ] **P2-2026-03**: Remove dead constants `TopicOrderCompleted` / `TopicOrderCancelled` from order constants.go

---

## ✅ What Is Working Well

| Area | Notes |
|------|-------|
| Transactional outbox | All status changes use `tm.WithTransaction + outboxRepo.Save` |
| Saga compensation | 5 compensation types in DLQ retry worker with exponential backoff |
| Idempotency (order/warehouse/shipping/fulfillment/promotion/loyalty) | Comprehensive coverage |
| Status transition guard | `canTransitionTo` + `ShouldSkipStatusUpdate` |
| Backward status guard | `constants.IsLaterStatus` prevents regression |
| COD payment capture skip | COD orders correctly skip payment capture |
| Auth expiry guard | `HandlePaymentCaptureRequested` fails fast if order is too old |
| Auth amount guard | Capture uses authoritative DB amount, not event amount |
| DLQ alert on exhaustion | `triggerAlert` fires after `MaxRetries` |
| Outbox cleanup | 30-day retention auto-cleanup |
| Payment webhook idempotency | Redis state machine |
| Partial confirm rollback | `ConfirmOrderReservations` rolls back already-confirmed on failure |
| ReservationExpired → full cancel | Entire order cancelled |
| DLQ drain consumers | 7+ DLQ drain handlers prevent Redis backpressure |
| Reservation TTL fail-fast | No silent fallback to no-TTL |
| Return compensation worker | Polls `return.restock_retry` + `return.refund_retry` |
| Promotion usage lifecycle | `orders.order.status_changed` filter + idempotency |
| Checkout reservation ordering | Stock reserved AFTER payment auth, with rollback |
| Loyalty order events | Fixed — `orders.order.status_changed` with `new_status` filter |
| Stock reconciliation | `StockReconciliationJob` runs hourly |

---

## Appendix: Topic Ownership Map (Updated v4)

```
Publisher           Topic                                     Consumer(s)
─────────────────────────────────────────────────────────────────────────
Order       →  orders.order.status_changed           → Fulfillment, Warehouse, Loyalty, Promotion, Notification
                                                        🔴 MISSING: Payment (should subscribe for void/escrow)
Order       →  orders.payment.capture_requested      → Order (self-loop)
Order       →  inventory.stock.committed             → Warehouse (audit + reconciliation)
Order       →  orders.return.requested               → Fulfillment, Notification
Order       →  orders.return.approved                → Fulfillment, Notification, Warehouse
Order       →  orders.return.completed               → Warehouse (restock), Payment (refund), Loyalty (clawback)
Payment     →  payment.payment.processed             → Order
Payment     →  payment.payment.failed                → Order
Payment     →  payment.payment.refunded              → Order
Fulfillment →  fulfillments.fulfillment.status_changed → Order, Warehouse
Fulfillment →  fulfillment.picklist_status_changed   → Fulfillment (self)
Fulfillment →  fulfillment.package_status_changed    → Shipping
Warehouse   →  warehouse.inventory.reservation_expired → Order
Shipping    →  shipping.shipment.delivered           → Order, Fulfillment

DEAD TOPICS (defined but never published):
Order       →  orders.order.completed                → Payment SUBSCRIBES 🔴 but NOBODY publishes
Order       →  orders.order.cancelled               → Payment SUBSCRIBES 🔴 but NOBODY publishes
```

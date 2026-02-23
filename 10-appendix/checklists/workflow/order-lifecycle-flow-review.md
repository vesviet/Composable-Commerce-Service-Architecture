# Order Lifecycle Flows — Business Logic Review Checklist

**Date**: 2026-02-21 | **Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `order/`, `fulfillment/`, `payment/`, `warehouse/` — event coordination, saga, outbox, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §6 (Order Lifecycle)

---

## 📊 Summary

| Category | Status |
|----------|--------|
| 🔴 P0 — Critical (data loss / financial risk) | **2 still open (OR-P0-03, OR-P0-04), 4 newly found** |
| 🟡 P1 — High (reliability) | **13 items originally → 10 FIXED, 3 NEW** |
| 🔵 P2 — Medium (edge case / observability) | **3 NEW discovered** |
| ✅ Verified Working | 18 areas |

---

## ✅ Verified Fixed (Previously Identified Issues)

| ID | Issue | Fix Confirmed? |
|----|-------|----------------|
| OR-P0-01 | Order creation lacks transactional outbox | ✅ `create.go:77-134` wraps order + outbox in `tm.WithTransaction` |
| OR-P0-02 | Double-confirmation of warehouse reservation at order creation | ✅ `confirmOrderReservations` only called after `payment.confirmed` |
| ORD-P0-01/02 | Missing FulfillmentConsumer + wrong status mapping | ✅ `fulfillment.completed → "shipped"` (not "delivered") confirmed at line 203 |
| OR-P1-01 | Order status transition validation | ✅ `canTransitionTo()` uses `constants.OrderStatusTransitions`; cancel uses this |
| OR-P1-02 | Cart cleanup worker missing | ✅ `order/internal/worker/cron/order_cleanup.go` operational |
| PAY-P0-02 | Webhook idempotency missing | ✅ Redis state-machine idempotency service at `payment/internal/biz/webhook/handler.go:64-81` |
| WH-P0-02 | FulfillReservation missing idempotency | ✅ `warehouse/internal/biz/inventory/fulfillment_status_handler.go:114` idempotency checks added |
| FUL-P0-04/05 | Fulfillment events outside tx / batch picklist non-transactional | ✅ Both transactional outbox confirmed |
| P1-5 (refund_restock) | DLQ missing `refund_restock` handler | ✅ `dlq_retry_worker.go:183` handles `refund_restock` case |
| DLQ reservations | `release_reservations` DLQ lacked reservation IDs | ✅ `retryReleaseReservations()` reads from `CompensationMetadata["reservation_ids"]` |
| DLQ-Ops-idempotency | Ops replay compensation missing idempotency key | ⚠️ Improved: DLQ retry uses `PaymentSagaState` guard; but no explicit idempotency key sent to Payment gRPC |
| COD pagination | COD auto-confirm used unbounded cursor | ✅ Offset-based pagination with `batchSize=100` |
| P2: Return events | Return events direct-publish (not outbox) | 🔶 Partially open (see RISK-003) |
| Outbox worker PROCESSING | No atomic PROCESSING mark | ✅ `outbox/worker.go:118-122` marks PROCESSING before publish |

---

## 🔴 Open P0 Issues (Confirmed Still Open in Code)

### OR-P0-03: Stock Reservation Created Outside Order Transaction

**File**: `order/internal/biz/order/create.go:77-134`, checkout flow caller

**Problem**: Cart checkout service creates stock reservations with the Warehouse service **before** calling `Order.CreateOrder`. The reservation gRPC call and the order DB insert are in separate network operations — there is no distributed atomic guarantee.

```
Checkout → Warehouse.CreateReservation (network) ← ORDER NOT CREATED YET
         ↓
         Order.CreateOrder (DB tx)
```

**Race scenario**: Warehouse reservation succeeds → order TX fails (e.g., DB downtime) → reservation is stuck (no order will ever confirm or release it). Reservation TTL is the only safety net.

**Shopify pattern**: Inventory reservation is created atomically inside the checkout transaction using a two-phase commit or is deferred until payment capture succeeds.

**Resolution**:
- [ ] Option A: Create reservation **after** order is persisted, inside the same `tm.WithTransaction` (requires synchronous warehouse gRPC inside TX — acceptable for auth networks)
- [x] Option B: Treat reservation as optimistic — reconcile via `ReservationExpiredWorker` + heartbeat; acceptable if warehouse TTL is reliably enforced

---

### OR-P0-04: Payment Webhook Signature Validation Missing

**File**: `payment/internal/biz/gateway/stripe.go`

**Problem**: Payment status updates from the gateway (Stripe webhooks) are accepted without HMAC signature verification. Any actor who knows the webhook URL can submit a forged `payment.confirmed` event → order marked PAID → stock deducted → merchandise shipped → fraud.

**Resolution**:
- [x] Add `Stripe-Signature` header verification using `stripe.ValidateWebhookSignature` (Stripe Go SDK)
- [ ] Add `PayPal-Transmission-Sig` verification for PayPal IPN
- [x] Store signature secret in Kubernetes Secret, inject via env
- [ ] Rate-limit webhook endpoint by source IP

---

### NEW-P0-001: `writeWarehouseDLQ` in Payment Consumer Does Not Save Reservation IDs

**File**: `order/internal/data/eventbus/payment_consumer.go:496-514`

**Problem**: When `releaseWarehouseReservations` fails after `payment.failed`, `writeWarehouseDLQ` creates a `FailedCompensation` record with `OperationType = "release_reservation"` **but without `CompensationMetadata["reservation_ids"]`**. The DLQ retry worker's `retryReleaseReservations()` reads from `CompensationMetadata["reservation_ids"]` — which will be nil. If `AuthorizationID` is also nil (it often is for payment failures), `retryReleaseReservations` returns:

```go
return fmt.Errorf("no reservation_ids found in compensation_metadata for order %s; cannot release reservations", comp.OrderID)
```

This means the compensation permanently fails and is eventually marked `"failed"` with an alert — **reservations are never released → stock leak**.

**Resolution**:
- [x] In `writeWarehouseDLQ`, load the order's items and populate `CompensationMetadata["reservation_ids"]` before saving the `FailedCompensation`:
  ```go
  comp.CompensationMetadata = map[string]interface{}{
      "reservation_ids": reservationIDs,   // []string from order items
  }
  ```

---

### NEW-P0-002: `processPaymentConfirmed` Does Not Confirm Warehouse Reservations

**File**: `order/internal/data/eventbus/payment_consumer.go:385-398`

**Problem**: The comment on `processPaymentConfirmed` (line 382-384) says:
> "Warehouse reservation confirmation is handled by Order service's CreateOrder flow (confirmOrderReservations). Removed duplicate confirmWarehouseReservations call."

However, `CreateOrder` **no longer calls `confirmOrderReservations`** (this was removed in the P0-02 fix to prevent double-confirmation). The comment at `create.go:210-218` explains that only `HandlePaymentConfirmed` should confirm reservations. But `processPaymentConfirmed` (the actual handler) only calls `UpdateOrderStatus → "confirmed"` — it never calls `confirmOrderReservations`.

**Result**: Warehouse reservations are **never converted to stock deductions**. Stock remains "reserved" indefinitely → expires by TTL → ghost inventory. Warehouse shows stock as available when it should be deducted.

**Shopify pattern**: `payment.confirmed` triggers reservation confirmation (stock commit) atomically with order confirmation.

**Resolution**:
- [x] Add `uc.confirmOrderReservations(ctx, order)` call inside `processPaymentConfirmed` after `UpdateOrderStatus` succeeds
- [x] Ensure this call is idempotent (reservation double-confirm returns "already confirmed" gracefully)

---

## 🟡 Remaining P1 Issues

### NEW-P1-001: Order Worker Missing Liveness/Readiness Probes

**File**: `gitops/apps/order/base/worker-deployment.yaml`

**Problem**: The order worker deployment has no `livenessProbe` or `readinessProbe` configured. A hung event consumer or blocked outbox worker will not be restarted by Kubernetes kubelet.

```yaml
# Missing:
livenessProbe:
  grpc:
    port: 5005
  initialDelaySeconds: 30
  periodSeconds: 30
readinessProbe:
  grpc:
    port: 5005
  initialDelaySeconds: 10
  periodSeconds: 10
```

Also missing: `revisionHistoryLimit` (catalog uses `1`; order omits it → unlimited old ReplicaSets accumulate).

**Resolution**:
- [ ] Add `livenessProbe` + `readinessProbe` to `order/base/worker-deployment.yaml`
- [ ] Add `revisionHistoryLimit: 1` to spec

---

### NEW-P1-002: COD Auto-Confirm Does Not Check Payment Expiry Window

**File**: `order/internal/worker/cron/cod_auto_confirm.go:114-128`

**Problem**: The COD auto-confirm job auto-confirms ALL pending COD orders by calling `UpdateOrderStatus(→ "confirmed")`. It does not check if the order was created too long ago. If a COD order is created but the customer was unavailable for delivery → still auto-confirmed → fulfillment assigned → logistics waste. Lazada pattern: COD orders have a configurable confirmation window (e.g., 24 hours from creation); after window orders not reachable → cancelled.

**Resolution**:
- [x] Add a `created_at` filter to the query: `created_at > NOW() - INTERVAL '24h'` (configurable)
- [ ] For orders beyond the confirmation window, auto-cancel instead of auto-confirm

---

### NEW-P1-003: Payment Consumer `releaseWarehouseReservations` Lacks Retry

**File**: `order/internal/data/eventbus/payment_consumer.go:425-458`

**Problem**: `releaseWarehouseReservations` calls `ReleaseReservation` once per item with no retry. If the Warehouse service is temporarily unavailable (common during rolling restarts), all releases fail and go to DLQ. But due to NEW-P0-001, the DLQ record has no reservation IDs → retry is impossible.

Contrast with `cancel.go:releaseReservationWithRetry` which has 3 retries + exponential backoff.

**Resolution**:
- [x] Replace direct `c.warehouseClient.ReleaseReservation(ctx, ...)` call with the same `releaseReservationWithRetry(ctx, resID, 3)` pattern used in `cancel.go`
- [x] Fix NEW-P0-001 first (populate reservation IDs in DLQ record)

---

## 📋 Event Publishing Necessity Check

### Services That NEED to Publish (✅ Justified)

| Service | Event | Consumers | Justification |
|---------|-------|-----------|---------------|
| Order | `order.status.changed` | Fulfillment, Notification, Analytics, Loyalty, Customer | **Essential** — drives entire downstream order lifecycle |
| Order | `inventory.stock.committed` | Analytics, Reporting | **Essential** — stock audit trail |
| Order | `orders.payment.capture_requested` | Payment consumer (self-loop via Dapr) | **Essential** — async capture for auth-and-capture flow |
| Order | `compensation.reservation_release` (outbox DLQ) | Order outbox worker | Justified: DLQ compensation pattern |
| Payment | `payment.confirmed` | Order (confirm), Loyalty (points), Analytics | **Essential** |
| Payment | `payment.failed` | Order (cancel + release), Analytics | **Essential** |
| Payment | `payment.capture_failed` | Order (mark failed) | **Essential** |
| Fulfillment | `fulfillment.status_changed` | Order (status update), Warehouse (stock deduct) | **Essential** |
| Warehouse | `warehouse.inventory.reservation_expired` | Order (auto-cancel on TTL) | **Essential** — prevents ghost reservations |

### Services That Subscribe But Might Not Need To (🔶 Review)

| Service | Subscription | Verdict |
|---------|-------------|---------|
| Order | `orders.payment.capture_requested` (self-loop) | ✅ Correct pattern for 2-step auth-capture; COD correctly skipped at line 163 |
| Order | `warehouse.inventory.reservation_expired` | ✅ Correct — auto-cancels order when reservation TTL expires |
| Order | `shipping.shipment.delivered` | ✅ Correct — sets order status to "delivered" |

**No unnecessary subscriptions found.**

---

## 📋 Event Subscription Necessity Check

### Order Worker Subscriptions

| Topic | Handler | Needed? |
|-------|---------|---------|
| `payment.confirmed` | `HandlePaymentConfirmed` | ✅ Yes — confirm order status, confirm reservations (⚠️ see NEW-P0-002) |
| `payment.failed` | `HandlePaymentFailed` | ✅ Yes — cancel order + release reservations |
| `orders.payment.capture_requested` | `HandlePaymentCaptureRequested` | ✅ Yes — trigger async payment capture |
| `fulfillment.status_changed` | `HandleFulfillmentStatusChanged` | ✅ Yes — drive order status through lifecycle |
| `warehouse.inventory.reservation_expired` | `HandleReservationExpired` | ✅ Yes — auto-cancel orders with expired stock |
| `shipping.shipment.delivered` | `HandleShipmentDelivered` | ✅ Yes — move order to "delivered" |

**No DLQ handlers registered for any of the above topics**. Dapr will route exhausted events to `{topic}.dlq` but no consumer drains them.

---

## 📋 Worker & Cron Job Checks

### Order Worker (`order/cmd/worker/`)

| Component | Running? | Notes |
|-----------|---------|-------|
| **OutboxWorker** | ✅ Yes | 1s poll, 50 events/batch, atomic PROCESSING mark, 10 retries, 30-day cleanup |
| **EventConsumersWorker** | ✅ Yes | payment/fulfillment/warehouse/shipping consumers |
| **DLQRetryWorker** | ✅ Yes | 5m interval, 5 operation types, exponential backoff, alert on exhaustion |
| **CODAutoConfirmJob** | ✅ Yes | 1m interval, offset pagination |
| **PaymentCompensationWorker** | ✅ Yes | `cron/payment_compensation.go` — retry stuck payment captures |
| **CaptureRetryWorker** | ✅ Yes | `cron/capture_retry.go` — retry failed payment captures |
| **ReservationCleanupWorker** | ✅ Yes | `cron/reservation_cleanup.go` — release expired reservations |
| **OrderCleanupWorker** | ✅ Yes | `cron/order_cleanup.go` — clean abandoned/stale orders |
| DLQ consumers (subscribers) | ❌ None | No DLQ drain handlers for any event topic (see below) |

---

## 📋 Saga / Outbox / Retry Correctness

| Check | Status | Notes |
|-------|--------|-------|
| Order create → outbox (atomic tx) | ✅ | `create.go:77-134` |
| Cancel → outbox (atomic tx) | ✅ | `cancel.go:108-126` |
| Payment confirmed → UpdateOrderStatus (via `orderUc`) | ✅ | Triggers outbox in `UpdateOrderStatus` |
| Payment confirmed → ConfirmReservations | ❌ | **NEW-P0-002**: never called |
| Payment failed → ReleaseReservations + DLQ | ⚠️ | Works but DLQ record missing reservation IDs (NEW-P0-001) |
| Fulfillment cancelled → CancelOrder (with reservation release) | ✅ | `fulfillment_consumer.go:143` |
| DLQ retry: void_authorization | ✅ | |
| DLQ retry: release_reservations | ⚠️ | Needs reservation IDs in metadata (NEW-P0-001) |
| DLQ retry: refund | ✅ | |
| DLQ retry: payment_capture | ✅ | |
| DLQ retry: refund_restock | ✅ | |
| DLQ retry: alert on exhaustion | ✅ | `triggerAlert` + `alertService` |
| Outbox worker: PROCESSING mark | ✅ | Line 118 |
| Outbox worker: max 10 retries | ✅ | Line 135 |
| Outbox worker: 30-day cleanup | ✅ | `CleanupOldEvents` every 10 cycles |
| Webhook idempotency | ✅ | Redis state machine in payment service |
| Event consumer idempotency | ✅ | `IdempotencyHelper.CheckAndMark` in payment + fulfillment consumers |
| Fulfillment status backward guard | ✅ | `constants.IsLaterStatus` check at line 170 |

---

## 📋 GitOps Config Checks

### Order Worker (`gitops/apps/order/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| `securityContext: runAsNonRoot: true, runAsUser: 65532` | ✅ |
| `dapr.io/enabled: "true"` + `app-id: order-worker` + `app-port: 5005` + `grpc` | ✅ |
| `livenessProbe` + `readinessProbe` | ❌ **MISSING** (NEW-P1-001) |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `secretRef: name: order-secrets` | ✅ (P1 fix confirmed) |
| `resources: requests + limits` | ✅ |
| `revisionHistoryLimit` | ❌ **MISSING** |
| `configFile volumeMount` | ⚠️ No volume / volumeMount — config loaded via env |
| `initContainers` | ✅ consul + redis + postgres health checks |

---

## 📋 Data Consistency Matrix

| Data Pair | Consistency Level | Risk |
|-----------|-----------------|------|
| Order DB ↔ Outbox events | ✅ Atomic (same TX) | Event loss extremely unlikely |
| Order status ↔ Payment status | ✅ Eventually consistent | `payment.confirmed` → order confirmed via event |
| Order status ↔ Fulfillment status | ✅ Eventually consistent | Via `fulfillment.status_changed` consumer |
| Warehouse reservation ↔ Order item | ⚠️ Reservation created before order (race OR-P0-03) | Orphaned reservations on order TX failure |
| Warehouse stock deducted ↔ Order paid | ❌ Stock NOT deducted when payment confirmed (NEW-P0-002) | Stock perpetually "reserved" until TTL |
| DLQ compensation ↔ Reservation IDs | ❌ Reservation IDs missing in payment failure DLQ (NEW-P0-001) | DLQ retry cannot find reservations to release |
| COD order lifecycle ↔ Customer reachability | ⚠️ No expiry check in COD auto-confirm (NEW-P1-002) | Old COD orders auto-confirmed but un-deliverable |
| Outbox event payload ↔ DB schema | ⚠️ `OrderStatusChangedEvent` contains all items (Risk 1 from last review) | Schema change → deserialization failures in consumers |

---

## 📋 Edge Cases Not Yet Handled

| Edge Case | Risk | Recommendation |
|-----------|------|----------------|
| Payment confirmed event arrives twice (duplicate from payment gateway) | 🔴 High | Idempotency check uses `DeriveEventID("payment_confirmed", orderID)` → order-level idempotency. OK. |
| Payment confirmed arrives while order is already "cancelled" (race cancel/confirm) | 🟡 High | `UpdateOrderStatus` validates transition; "confirmed" from "cancelled" not allowed. ✅ Safe. |
| COD order, delivery collected, but `delivery.confirmed` webhook never arrives | 🟡 High | Add `shipped` → `delivered` auto-complete after N-day delivery window (Shopee: +5 days after shipped date) |
| Order has items from 2+ warehouses; one warehouse's reservation expires, other stays | 🟡 High | `warehouse.inventory.reservation_expired` event carries single `reservation_id`. `HandleReservationExpired` should cancel the **entire order** not just one item's reservation. Verify the handler does full cancellation. |
| `processPaymentFailed` calls `releaseWarehouseReservations` → all fail → DLQ saved → outbox worker publishes outbox event → triggers new payment.failed → infinite retry loop? | 🔴 High | The outbox DLQ uses a **different** topic (`compensation.reservation_release`), not `payment.failed`. No loop. Safe. |
| Order with promo applied; promo expired between order creation and fulfillment | 🔵 Medium | Promo usage counter was decremented at checkout. On order cancel → promo counter must be restored. No reversal event found. |
| Partial fulfillment: only 2 of 3 items picked, shipment created for 2 → order marked "shipped" | 🟡 High | FUL-P0-01 (multi-warehouse fulfilment aggregation) still open. Check if `order → shipped` should wait for ALL fulfillments vs. first shipment. |
| Capture payment fails with auth expiry; order marked `capture_failed` + `payment_status=failed` | 🟡 High | DLQ record created (via `payment_capture` operation type). But order status not reverted to `cancelled` automatically. Ops must manually trigger cancel after DLQ failure alert. |
| `refund.completed` event → `returnStockToInventory` fails → DLQ written (return service) → DLQ retry → `refund_restock` operation; metadata must include `product_id`, `warehouse_id`, `quantity` | 🟡 High | Verify return service `writeRefundRestockDLQ` populates all 3 fields. |
| COD order auto-confirmed by cron → fulfillment assigned → customer cancels before pick | 🔵 Medium | Standard `CancelOrder` flow handles this. ✅ |

---

## 🔧 Remediation Actions

### 🔴 Fix Now (Data Loss / Financial Risk)

- [x] **NEW-P0-001**: In `payment_consumer.go:writeWarehouseDLQ`, load order items and populate `CompensationMetadata["reservation_ids"]` before saving `FailedCompensation`
- [x] **NEW-P0-002**: In `processPaymentConfirmed`, after `UpdateOrderStatus`, call `orderUc.confirmOrderReservations(ctx, order)` to deduct stock — the step missing since the double-conf fix
- [x] **OR-P0-04**: Add Stripe webhook signature validation (`stripe.ValidateWebhookSignature`) before processing any gateway callback

### 🟡 Fix Soon (Reliability)

- [x] **OR-P0-03**: Move stock reservation inside order creation transaction (or document TTL-as-safety-net decision formally)
- [ ] **NEW-P1-001**: Add `livenessProbe` + `readinessProbe` + `revisionHistoryLimit: 1` to `order/base/worker-deployment.yaml`
- [ ] **NEW-P1-002**: Add creation-time filter to COD auto-confirm query (configurable window, default 24h); orders past window → auto-cancel
- [x] **NEW-P1-003**: Use `releaseReservationWithRetry` (3 retries + backoff) inside `releaseWarehouseReservations` in `payment_consumer.go`
- [ ] **Add DLQ drain consumers**: Register `{topic}.dlq` consumers for all 6 subscribed topics in order worker (log ERROR + ACK) — prevents Redis DLQ backpressure

### 🔵 Monitor / Document

- [ ] Verify `HandleReservationExpired` cancels the ENTIRE order (not just one item) when one reservation expires
- [ ] Verify return service `writeRefundRestockDLQ` includes `product_id`, `warehouse_id`, `quantity` in metadata
- [ ] Add `GOT_DELIVERED_AT` auto-complete cron: if order is `shipped` and `N` days have passed → auto-complete (Shopee pattern)
- [ ] Revert promotion usage counter on order cancellation/refund (Promotion service integration)
- [ ] Add SLO alert: `pending outbox events > 100 AND age > 5m` → PagerDuty (DLQ backlog alert)
- [ ] Document DLQ replay procedure for Ops (reservation release requires DB compensation_metadata patch if NEW-P0-001 is not retroactively fixed)

---

## ✅ What Is Working Well

| Area | Notes |
|------|-------|
| Transactional outbox | All status changes use `tm.WithTransaction + outboxRepo.Save` |
| Saga compensation | 5 compensation types in DLQ retry worker with exponential backoff |
| Idempotency | `IdempotencyHelper.CheckAndMark` on payment + fulfillment consumers |
| Status transition guard | `canTransitionTo` prevents invalid state changes |
| Fulfillment cancelled → CancelOrder | Uses `CancelOrder()` (not just `UpdateStatus`) → reservation release + retry + DLQ |
| Backward status guard | `constants.IsLaterStatus` prevents status regression |
| COD payment capture skip | COD orders correctly skip the payment capture path |
| Auth expiry guard | `HandlePaymentCaptureRequested` fails fast if order is too old |
| Auth amount guard | Capture uses authoritative DB amount, not event amount (M-4 pattern) |
| DLQ alert on exhaustion | `triggerAlert` fires after `MaxRetries` → Ops email |
| Outbox cleanup | 30-day retention auto-cleanup every 10 cycles |
| Payment webhook idempotency | Redis state machine prevents double-processing |

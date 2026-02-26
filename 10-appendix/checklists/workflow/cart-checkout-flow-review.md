# Cart & Checkout Flows — Business Logic Review

**Date**: 2026-02-26  
**Pattern Reference**: Shopify, Shopee, Lazada  
**Scope**: `checkout` service + `order` service — Cart & Checkout Flows (Section 5)  
**Status**: ⚠️ Needs Work — Several P1/P2 gaps found

---

## Table of Contents

1. [Data Consistency Between Services](#1-data-consistency-between-services)
2. [Data Mismatches (Mismatched Data)](#2-data-mismatches)
3. [Saga / Outbox / Retry / Rollback](#3-saga--outbox--retry--rollback)
4. [Edge Cases — Logic Risks Unhandled](#4-edge-cases--logic-risks-unhandled)
5. [Event Publish Audit (Does service NEED to publish?)](#5-event-publish-audit)
6. [Event Subscribe Audit (Does service NEED to subscribe?)](#6-event-subscribe-audit)
7. [GitOps Config Check](#7-gitops-config-check)
8. [Worker: Events, Consumers, Cron Jobs](#8-worker-events-consumers-cron-jobs)
9. [Action Items Summary](#9-action-items-summary)

---

## 1. Data Consistency Between Services

### 1.1 Price Consistency — ✅ Good

| Layer | Behavior |
|---|---|
| Cart Preview | `CalculateOrderTotals()` called via `Pricing Service` gRPC |
| Checkout Confirm | `RevalidatePrices: true` — prices re-fetched at confirm time |
| Order Create | Order service accepts total from checkout (authoritative) |
| Server-side validation | `validateOrderTotals()` in order service cross-checks item math |

**Assessment**: Price is re-validated synchronously at `ConfirmCheckout`. The 0.05 VND tolerance for float aggregation is reasonable. ✅

### 1.2 Stock / Reservation Consistency — ✅ Good (with caveat)

| Stage | Behavior |
|---|---|
| Cart add-item | Stock availability soft-checked (not reserved) |
| `ConfirmCheckout` | `reserveStockForOrder()` — hard reserve with `ReserveStockWithTTL` + 15 min TTL |
| Order created | Reservation ID stored per `OrderItem` |
| Payment confirmed | `confirmReservationsForOrder()` — removes TTL, commits stock |
| Payment failed | `CancelOrder()` — releases reservation via `releaseReservationWithRetry()` |
| Order expired (cron) | `ReservationCleanupJob` (every 15 min) releases dangling reservations |

**Caveat (P1)**: `reserveStockForOrder()` in checkout does not guard against `warehouseID == ""` explicitly — it passes an empty string to `ReserveStockWithTTL`. If warehouse client accepts empty warehouse ID, an oversell risk exists. The order service in `reservation.go` does guard this, but checkout does not call order's `ReserveStockForItems`.

### 1.3 Promotion / Coupon Consistency — ✅ Good

- Single-use coupon lock via `acquireCouponLocks()` (Redis SETNX) — prevents race condition.
- `MaxPromotionCodesPerOrder = 5` enforced at `validateCheckoutPrerequisites()`.
- Promo usage applied **after** order creation (best-effort, DLQ-backed).

### 1.4 Cart ↔ Order Session Consistency — ⚠️ Gap

- Cart session ID is used as idempotency key for order creation (unique constraint on `cart_session_id`).
- After `createOrder` succeeds, `completeCartAfterOrderCreation()` updates cart status to `completed`.
- **Gap**: If `completeCartAfterOrderCreation` fails AND DLQ retry also fails, cart remains in `checkout` status. Customer may re-submit checkout → DB unique constraint catches it (idempotent). But cart cleanup cron must also handle `checkout`-status carts beyond `auto_cancel_minutes`.
- `checkout/configs/config.yaml`: `auto_cancel_minutes: 30` for checkout, but `config.yaml` order has `auto_cancel_minutes: 1440` (24h). Different TTLs between checkout session (30 min) and order payment window (30 min in order) are consistent — good.

### 1.5 Shipping Fee Consistency — ⚠️ Gap

- Shipping fee is calculated at `CalculateOrderTotals` time and embedded in `TotalAmount`.
- No lock on the selected shipping method between calculation and order creation.
- **Risk**: If carrier updates rates between `CalculateOrderTotals` and `ConfirmCheckout` (usually seconds), the price in the order may differ from what customer saw.
- **Shopee/Lazada approach**: Re-fetch shipping fee at confirm time — this **is** done via `RevalidatePrices: true` in `CalculateOpts` but only price is revalidated, not shipping rates.

---

## 2. Data Mismatches

| # | Issue | Severity | Status |
|---|---|---|---|
| M-01 | `default_country: "US"` in `checkout/configs/config.yaml` but `DefaultCountryCode = "VN"` in `constants/business.go`. Config value overrides constant — devs may be confused about which is authoritative. | P2 | ⚠️ Open |
| M-02 | `order_timeout_minutes: 30` in order configmap, `OrderExpirationPending = 30min` in order constants. But checkout `auto_cancel_minutes: 30` is checkout SESSION not order. Aligns correctly — but needs documentation. | P2 | ⚠️ Open |
| M-03 | `ReservationPaymentTTL = 15min` in checkout vs `reservation_timeout_minutes: 30` in order configmap. The order configmap controls nothing in code — it's documentation only. Actual TTL used is checkout constant (15 min). This divergence will confuse operators. | P1 | ⚠️ Open |
| M-04 | `TopicCheckoutCompleted = "orders.checkout.completed"` is defined in checkout constants but **never published**. Dead constant — should be removed or the publish call added. | P2 | ⚠️ Open |
| M-05 | `checkout/internal/constants/constants.go` re-defines `OrderStatusTransitions` but with fewer entries than `order/internal/constants/constants.go` (missing `partially_shipped` status). If checkout code ever uses this map for validation, it will be missing a valid transition. | P1 | ⚠️ Open |
| M-06 | `cart.converted` event has `items_count` (int32) and `cart_total` (float64) but no per-item detail. Analytics `ProcessCartConvertedEvent` works with this. However, loyalty points calculation cannot be triggered by this event alone — it correctly relies on `orders.order.completed` from order service. | ✅ | OK |

---

## 3. Saga / Outbox / Retry / Rollback

### 3.1 Checkout Saga (ConfirmCheckout) — ✅ Well Implemented

```
Step 1: Validate cart & session
Step 2: Calculate totals (price re-validation)
Step 3: Fraud pre-check
Step 4: Authorize payment
Step 5: Reserve stock (just-in-time, 15 min TTL)
Step 6: Create order (Order service gRPC)
   ↳ FAIL → RollbackReservationsMap() + VoidAuthorization()
           ↳ VoidAuth FAIL → FailedCompensation DLQ (async retry)
Step 7: Apply promotions (best-effort, DLQ-backed)
Step 8: Finalize + cleanup (tx: outbox save + cart complete)
```

**Assessment**: Compensating transactions are correctly implemented. The idempotency lock (15 min Redis key) covers the payment auth TTL window. ✅

### 3.2 Order Creation Outbox — ✅ Good

- `CreateOrder()` wraps DB insert + outbox event write in single `tm.WithTransaction()`.
- `orders.order.status_changed` published atomically with order creation.
- Outbox worker (`order-worker`) polls every 1 second, retries up to 10 times, then marks `failed`.

**Gap (P1)**: Outbox worker marks event `failed` after 10 retries but there is no alerting or DLQ drain for `failed` outbox events. They are cleaned up after 30 days but no human is notified. Silent event loss possible.

### 3.3 Payment Confirmed → Reservation Confirm — ✅ Good (with DLQ)

- `confirmReservationWithRetry()`: 3 retries, 100ms/200ms/400ms backoff.
- On failure → `writeReservationConfirmDLQ()` saves to outbox topic `compensation.reservation_confirm`.
- `dlq_retry_worker.go` in order worker handles this.

**Gap (P1)**: `HandlePaymentConfirmed()` is on the HTTP handler which is marked `httpHandlerDeprecated()`. The actual consumer is in `worker/event` (gRPC consumer). But the HTTP handler struct still has the logic — if Dapr HTTP subscription is accidentally re-enabled, events would be processed twice.

### 3.4 Payment Failed → Order Cancellation — ✅ Good

- `CancelOrder()` handles reservation release with retry + DLQ (no double-release bug fixed).
- Previously: `releaseReservationsForOrder()` + `CancelOrder()` caused phantom restock (P0-2 fix confirmed).

### 3.5 Checkout Worker FailedCompensation — ✅ Good

- `FailedCompensationWorker` retries: void_authorization, apply_promotion, cart_cleanup.
- `MaxRetries = 5` for void, `10` for promo, `3` for cart cleanup.
- `AlertSent` flag prevents alert spam.

---

## 4. Edge Cases — Logic Risks Unhandled

| # | Edge Case | Risk Level | Status |
|---|---|---|---|
| EC-01 | **Cart item added after checkout starts**: Customer opens 2 tabs, adds item in tab 1 while tab 2 is at checkout confirm. Cart version in idempotency key (`v{modelCart.Version}`) correctly invalidates stale checkout. ✅ | Low | ✅ Handled |
| EC-02 | **Stock drops to 0 between `reserveStockForOrder` and order creation**: Very narrow window. Reservation acquired = stock exists. Order service trusts reservation. ✅ | Low | ✅ Handled |
| EC-03 | **Duplicate payment webhook**: Order service `EventIdempotencyRepo` dedups by event ID. ✅ | Medium | ✅ Handled |
| EC-04 | **Promotion expires between validation and apply**: Promo applied after order creation. If promo expired in that window: `ApplyPromotion` fails → DLQ retry. On retry, promo still expired → max retries exhausted. **Order succeeds with discount that was never properly registered** (usage counter not incremented = promo budget leak). | High | ⚠️ Unhandled |
| EC-05 | **Cart expires during payment processing**: Cart expiry = 24h (user) / 1h (guest). Payment window is 15 min. Cart should not expire during payment — OK. But `CartCleanupWorker` may delete a `checkout`-status cart if `Status=checkout` is treated as abandoned. Need to verify cleanup logic excludes `checkout` status carts with active orders. | High | ⚠️ Needs Verification |
| EC-06 | **Multiple items, partial reservation failure**: `reserveStockForOrder` iterates sequentially. If item 3 of 5 fails → `RollbackReservationsMap()` releases items 1-2. ✅ But rollback errors are silently swallowed (`_ = uc.warehouseInventoryService.ReleaseReservation(...)`). Stock leak if rollback fails. | High | ⚠️ Unhandled |
| EC-07 | **COD order + failed order creation**: COD skips payment auth. If order creation fails, there is no `VoidAuthorization` call (correct). But reservation is rolled back. COD DLQ path is: only stock rollback, no payment compensation. ✅ Clean. | Low | ✅ Handled |
| EC-08 | **`WarehouseID` is nil in cart item at reservation time**: `reserveStockForOrder()` passes `warehouseID = ""` if `item.WarehouseID == nil`. Warehouse service behavior with empty warehouse ID is not guarded here (unlike `order/reservation.go` which returns error). **Potential silent oversell or wrong warehouse deduction**. | Critical | ❌ Bug |
| EC-09 | **Guest checkout with large cart, some items go OOS after fraud check**: No re-validation between fraud check and reservation. Steps 4.5 → 6 have no stock re-check. Window is typically < 1s but visible in high-traffic scenarios. | Medium | ⚠️ Acceptable |
| EC-10 | **Order cleanup job processes confirmed orders**: `OrderCleanupJob` cancels both `pending` AND `confirmed` orders that expire. Confirmed orders have stock already committed (reservation confirmed). Cancelling a confirmed order triggers `CancelOrder()` which tries to release reservation → reservoir is "not active" (already confirmed) → triggers `RestockItem`. This is **correct behavior** but generates noise in logs for expired-confirmed orders. | Low | ✅ Correct (noisy) |
| EC-11 | **`auto_cancel_minutes: 1440` (24h) in order configmap vs TTL-based reservation of 30 min**: After 30 min reservation expires at warehouse TTL level, but order remains in `pending` for 24h. Reservation cleanup job (every 15 min) should release this. But if `FindExpired` only queries by `expiry_at < now`, orders without explicit `expiry_at` may slip through. | Medium | ⚠️ Needs Verification |
| EC-12 | **Loyalty points redemption not in checkout flow**: `ecommerce-platform-flows.md §5.3` lists "Loyalty points redemption" as step 5 of checkout. Code does not implement loyalty point deduction at checkout. Points are only **earned** (post-delivery). **Missing feature**. | High | ❌ Not Implemented |
| EC-13 | **No price lock / frozen price on order**: Once order is created, the `unit_price` in `order_items` is the authoritative price. Good. But if promotions apply retroactively (admin retroactive discount), there is no mechanism to re-price existing pending orders. Shopee/Lazada handle via compensation: keep order price, issue store credit. | Low | ⚠️ By design |
| EC-14 | **`warehouseClient` vs `warehouseInventoryService` dual interface in order service**: `reservation.go:31-44` — if `warehouseInventoryService != nil`, use that; else try `warehouseClient`. This dual-path increases cognitive load and could lead to rollback calling the wrong interface (`rollbackReservationsMap` only releases via `warehouseInventoryService`). | Medium | ⚠️ Tech Debt |

---

## 5. Event Publish Audit

### 5.1 Checkout Service — Published Events

| Topic | Published? | Where | Needed? | Assessment |
|---|---|---|---|---|
| `cart.converted` | ✅ Yes | `finalizeOrderAndCleanup` via Outbox | ✅ Yes — Analytics, CRM funnel tracking | ✅ Correct |
| `orders.checkout.completed` | ❌ Not published | Defined in constants, never called | ❌ Dead constant | **P2: Remove or implement** |
| `orders.payment.capture_requested` | ✅ Yes | Payment saga capture worker | ✅ Yes — capture flow | ✅ Correct |

### 5.2 Order Service — Published Events

| Topic | Published? | Where | Needed? | Assessment |
|---|---|---|---|---|
| `orders.order.status_changed` | ✅ Yes | Outbox (all status transitions) | ✅ Yes — Fulfillment, Notification, Analytics | ✅ Correct |
| `orders.order.completed` | ✅ Yes | Outbox (delivered status) | ✅ Yes — Loyalty, Analytics | ✅ Correct |
| `orders.order.cancelled` | ✅ Yes | Outbox | ✅ Yes — Loyalty reversal | ✅ Correct |
| `inventory.stock.committed` | ✅ Yes | `publishStockCommittedEvent` via Outbox | ✅ Yes — Warehouse denormalization | ✅ Correct |
| `compensation.reservation_release` | ✅ Yes | `writeReservationReleaseDLQ` via Outbox | ✅ Yes — async reservation release retry | ✅ Correct |
| `compensation.reservation_confirm` | ✅ Yes | `writeReservationConfirmDLQ` via Outbox | ✅ Yes — async confirmation retry | ✅ Correct |
| `compensation.refund_restock` | ✅ Yes | `writeRefundRestockDLQ` via Outbox | ✅ Yes — async inventory restore | ✅ Correct |
| `orders.return.*` / `orders.exchange.*` | ✅ Yes | Return/Exchange handlers | ✅ Yes | ✅ Correct |

**No unnecessary event publishing found in order service.**

---

## 6. Event Subscribe Audit

### 6.1 Checkout Service — Subscriptions

| Topic | Subscribed? | Needed? | Assessment |
|---|---|---|---|
| `payments.payment.confirmed` | ❌ No | ❌ Not needed — checkout calls order service which handles this | ✅ Correct |
| `payments.payment.failed` | ❌ No | ❌ Not needed — same reason | ✅ Correct |
| `orders.order.status_changed` | ❌ No | ❌ Not needed — checkout is fire-and-forget after order creation | ✅ Correct |
| Any other subscription | ❌ No | ❌ Checkout is a pure write-path service | ✅ Correct |

**Assessment**: Checkout correctly has zero event subscriptions. Price/stock data is always fetched on-demand via gRPC.

### 6.2 Order Service Worker — Subscriptions (via `EventConsumersWorker`)

| Topic | Consumer | Handler | Needed? |
|---|---|---|---|
| `payments.payment.confirmed` | `paymentConsumer.ConsumePaymentConfirmed` | Updates order → `confirmed`, confirms reservations, triggers fulfillment | ✅ Yes |
| `payments.payment.failed` | `paymentConsumer.ConsumePaymentFailed` | Calls `CancelOrder()` | ✅ Yes |
| `orders.payment.capture_requested` | `paymentConsumer.ConsumePaymentCaptureRequested` | Capture retry saga | ✅ Yes |
| `fulfillments.fulfillment.status_changed` | `fulfillmentConsumer.ConsumeFulfillmentStatusChanged` | Maps fulfillment → order status | ✅ Yes |
| `warehouse.inventory.reservation_expired` | `warehouseConsumer.ConsumeReservationExpired` | Cancel order when reservation TTL expires | ✅ Yes |
| `shipping.shipment.delivered` | `shippingConsumer.ConsumeShipmentDelivered` | Updates order → `delivered` | ✅ Yes |

**Gap (P1)**: `payments.refund.completed` is defined as `TopicRefundCompleted` in order constants and handled in `HandleRefundCompleted()` (HTTP handler) but this handler is marked `httpHandlerDeprecated`. There is NO gRPC consumer for `refund.completed` in `EventConsumersWorker`. **Refund completion → order status update is currently broken in worker mode**.

---

## 7. GitOps Config Check

### 7.1 Checkout Service (`gitops/apps/checkout/base/`)

| Check | Status | Notes |
|---|---|---|
| `deployment.yaml` — app-port `8010`: matches `config.yaml` server.http.addr `0.0.0.0:8010` | ✅ | |
| `dapr.io/app-port: "8010"` | ✅ | Consistent |
| `dapr.io/app-protocol: "http"` | ✅ | Correct for HTTP checkout |
| Health probes: `/health/live`, `/health/ready` on port 8010 | ✅ | |
| `configmap.yaml` — only `log-level: "info"` — missing all business config | ⚠️ P1 | Business config is injected via `checkout-secrets` + `overlays-config`. No `config.yaml` embed in ConfigMap unlike order service. May cause confusion about which config is active. |
| `worker-deployment.yaml` — `dapr.io/app-port: "8019"` | ✅ | Health server port 8019 confirmed in `main.go` |
| `worker-deployment.yaml` — `dapr.io/app-protocol: "http"` | ✅ | Worker publishes via Dapr but doesn't subscribe (HTTP subscriptions) |
| HPA for checkout | ❓ | Not found in base — check overlays |
| `checkout-secrets` referenced but not present in base | ⚠️ | Must exist in overlays — verify dev overlay has all required secrets including `jwt_secret`, DB credentials |

### 7.2 Order Service (`gitops/apps/order/base/`)

| Check | Status | Notes |
|---|---|---|
| `deployment.yaml` exists (not reviewed) | — | See separate order review checklist |
| `worker-deployment.yaml` — `dapr.io/app-port: "5005"` | ✅ | gRPC event consumer port |
| `dapr.io/app-protocol: "grpc"` | ✅ | Correct — worker uses gRPC eventbus |
| Health probe for worker: `httpGet /healthz` port `health` (8081) | ✅ | |
| `startupProbe.tcpSocket` on gRPC port 5005 | ✅ | Correct for gRPC server startup |
| `configmap.yaml` — `eventbus.default_pubsub: pubsub-redis` | ✅ | Matches `DaprDefaultPubSub = "pubsub-redis"` |
| `configmap.yaml` — `reservation_timeout_minutes: 30` vs code TTL of 15min | ⚠️ P1 | Config value unused in code. Misleading documentation in configmap. |
| `configmap.yaml` — missing `MaxOrderAmount` config key | ⚠️ P2 | `MaxOrderAmount = 100_000_000` is hardcoded in checkout constants but not configurable via K8s ConfigMap. |

---

## 8. Worker: Events, Consumers, Cron Jobs

### 8.1 Checkout Worker (`checkout/cmd/worker`)

Workers registered in `wire_gen.go`:

| Worker | Type | Schedule | Job |
|---|---|---|---|
| `CartCleanupWorker` | Cron (continuous) | Interval-based | Cleans up stale/abandoned carts, releases their reservations |
| `FailedCompensationWorker` | Cron (continuous) | Polling | Retries: `void_authorization`, `apply_promotion`, `cart_cleanup` |
| `OutboxWorker` | Continuous | Every ~1s | Publishes pending `cart.converted` events from outbox to Dapr pubsub |

**No event consumers in checkout worker** — correct, checkout is write-path only.

**Gap (P2)**: `shouldRunWorker()` in `cmd/worker/main.go` returns `false` for `"event"` mode with comment "Temporarily disable event workers". If checkout ever needs event consumers in future, this disables them silently. Should be removed or explicitly documented.

**Gap (P1)**: `CartCleanupWorker` — verify it does NOT cancel carts with `status=checkout` that have an active order (order just created but cart not yet `completed`). If it cancels `checkout`-status carts too aggressively, it may release reservations for live orders.

### 8.2 Order Worker (`order/cmd/worker`)

Workers registered via `wire_gen.go` (inferred from file structure):

| Worker | Type | Schedule | Job |
|---|---|---|---|
| `OutboxWorker` | Continuous | Every 1s, batch 50 | Publishes outbox events to Dapr |
| `EventConsumersWorker` | Continuous | gRPC server | Subscribes to 6 topics (payment, fulfillment, warehouse, shipping) |
| `ReservationCleanupJob` | Cron | Every 15 min | Releases expired reservations from cancelled/expired orders |
| `OrderCleanupJob` | Cron | Every 15 min | Auto-cancels expired `pending` and `confirmed` orders |
| `DLQRetryWorker` | Cron | Polling | Retries `compensation.*` outbox events |
| `CaptureRetryWorker` | Cron | Polling | Retries payment capture attempts |
| `CODAutoConfirmWorker` | Cron | Interval | Auto-confirms COD orders after delivery |
| `PaymentCompensationWorker` | Cron | Interval | Handles payment compensation flows |
| `FailedCompensationsCleanupJob` | Cron | Interval | Cleans up old failed compensation records |

**Gap (P0 — Critical)**: `refund.completed` event consumer **missing** from `EventConsumersWorker`. Topic `payments.refund.completed` is consumed via HTTP `HandleRefundCompleted()` which is `httpHandlerDeprecated`. Worker does NOT register a gRPC consumer for this topic. **Orders are not automatically updated to `refunded` status after a refund completes**. Manual or admin intervention required.

---

## 9. Action Items Summary

### 🔴 P0 — Blocking

| ID | Item | Service | File |
|---|---|---|---|
| P0-CC-01 | Add `payments.refund.completed` gRPC consumer to `EventConsumersWorker`. The HTTP handler exists but is deprecated. Without this, order status is never updated to `refunded` after payment refund. | order-worker | `internal/worker/event/event_worker.go` |

### 🟡 P1 — High Priority

| ID | Item | Service | File |
|---|---|---|---|
| P1-CC-01 | Guard `warehouseID == ""` in `reserveStockForOrder()` checkout. If `item.WarehouseID == nil`, return error before calling warehouse service. | checkout | `internal/biz/checkout/confirm.go:134-142` |
| P1-CC-02 | `reservation_timeout_minutes: 30` in order configmap is misleading — actual TTL is `ReservationPaymentTTL=15min` in checkout code. Align config value or document clearly. | gitops | `gitops/apps/order/base/configmap.yaml:51` |
| P1-CC-03 | Add Prometheus alert or notification when outbox events reach `failed` status (10 retries exhausted). Silent failure = undetected event loss. | order | `internal/worker/outbox/worker.go:135-138` |
| P1-CC-04 | `CartCleanupWorker` — verify it excludes `checkout`-status carts that have a corresponding live order (order.status: pending). If cleanup is too aggressive, reservations for live orders are released. | checkout | `internal/worker/cron/` |
| P1-CC-05 | `M-05`: `checkout/constants.go` defines `OrderStatusTransitions` missing `partially_shipped`. Merge or remove duplicate. Source of truth should be `order/constants.go`. | checkout | `internal/constants/constants.go:174-183` |
| P1-CC-06 | `checkout configmap.yaml` has no `config.yaml` embed. Add at minimum business-critical keys (`max_order_amount`, `reservation_timeout_minutes`) to configmap for ops visibility. | gitops | `gitops/apps/checkout/base/configmap.yaml` |

### 🔵 P2 — Normal

| ID | Item | Service | File |
|---|---|---|---|
| P2-CC-01 | Remove dead constant `TopicCheckoutCompleted = "orders.checkout.completed"` — never published. | checkout | `internal/constants/constants.go:12` |
| P2-CC-02 | `default_country: "US"` in config.yaml but `DefaultCountryCode = "VN"`. Align to VN or document explicitly which wins. | checkout | `configs/config.yaml:73` |
| P2-CC-03 | EC-12: Loyalty point redemption at checkout is not implemented. This is a flow listed in `ecommerce-platform-flows.md §5.3 step 5`. Create tracking issue. | checkout | — |
| P2-CC-04 | EC-04: Promo that expires between checkout validation and `ApplyPromotion` → order succeeds but promo usage not tracked. Consider making promo apply synchronous (fail checkout if promo expired during payment). | checkout | `internal/biz/checkout/confirm.go:469-532` |
| P2-CC-05 | EC-06: Rollback errors in `RollbackReservationsMap` are silently swallowed. Add error log + DLQ entry for failed rollbacks. | checkout | `internal/biz/checkout/usecase.go` |
| P2-CC-06 | `shouldRunWorker()` returns `false` for `"event"` mode with TODO comment. Remove or document explicitly. | checkout | `cmd/worker/main.go:149` |
| P2-CC-07 | EC-14: Dual `warehouseClient` / `warehouseInventoryService` interface in order biz. Simplify to single interface path. | order | `internal/biz/order/reservation.go` |
| P2-CC-08 | `MaxOrderAmount = 100_000_000` hardcoded in checkout constants. Should be per-environment configurable via ConfigMap or Secret. | checkout | `internal/constants/constants.go:108` |

---

## Event Architecture Summary

```
[Checkout Service] 
  PUBLISHES:
    → cart.converted          (Outbox → Analytics)
    → orders.payment.capture_requested  (Saga → Payment)
  SUBSCRIBES: NONE ✅

[Order Service]
  PUBLISHES:
    → orders.order.status_changed      (Outbox → Fulfillment, Notification, Analytics)
    → orders.order.completed           (Outbox → Loyalty, Analytics)
    → orders.order.cancelled           (Outbox → Loyalty)
    → inventory.stock.committed        (Outbox → Warehouse)
    → compensation.*                   (DLQ Outbox → Self-retry)
  SUBSCRIBES (worker gRPC):
    ← payments.payment.confirmed       ✅
    ← payments.payment.failed          ✅
    ← orders.payment.capture_requested ✅
    ← fulfillments.fulfillment.status_changed ✅
    ← warehouse.inventory.reservation_expired ✅
    ← shipping.shipment.delivered      ✅
    ← payments.refund.completed        ❌ MISSING (P0)
```

---

*Generated: 2026-02-26 | Reviewer: Antigravity AI | Next review: after P0 fix*

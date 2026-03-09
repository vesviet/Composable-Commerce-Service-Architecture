# Cart & Checkout Flows — Business Logic Review (2026-03-07)

**Date**: 2026-03-07
**Previous Audit**: 2026-03-02 (`cart-checkout-deep-review.md`)
**Pattern Reference**: Shopify, Shopee, Lazada
**Scope**: `checkout` + `order` service — Cart & Checkout Flows (Section 5)
**Status**: ✅ ALL P0/P1 Fixed, 4/8 P2 Fixed — 4 P2 remain OPEN + 5 NEW issues discovered

---

## Table of Contents

1. [Data Consistency Between Services](#1-data-consistency-between-services)
2. [Data Mismatches](#2-data-mismatches)
3. [Saga / Outbox / Retry / Rollback](#3-saga--outbox--retry--rollback)
4. [Edge Cases — Logic Risks](#4-edge-cases--logic-risks)
5. [Event Publish Audit](#5-event-publish-audit)
6. [Event Subscribe Audit](#6-event-subscribe-audit)
7. [GitOps Config Check](#7-gitops-config-check)
8. [Worker: Events, Consumers, Cron Jobs](#8-worker-events-consumers-cron-jobs)
9. [Action Items Summary](#9-action-items-summary)

---

## 1. Data Consistency Between Services

### 1.1 Price Consistency — ✅ Good

| Layer | Behavior | Code Reference |
|---|---|---|
| Cart Preview | `CalculateOrderTotals()` via Pricing Service gRPC | `checkout/biz/checkout/calculations.go` |
| Checkout Confirm | `RevalidatePrices: true` — prices re-fetched at confirm time | `confirm.go:358-364` |
| Order Create | Order service accepts total from checkout (authoritative) | `order/biz/order/create.go` |
| Server-side validation | `validateOrderTotals()` cross-checks item math | `order/biz/validation/` |

**Assessment**: ✅ Price is re-validated synchronously. The 0.05 VND tolerance for float aggregation is reasonable.

### 1.2 Stock / Reservation Consistency — ✅ Good

| Stage | Behavior | Code Reference |
|---|---|---|
| Cart add-item | Stock availability soft-checked (not reserved) | `cart/add.go` → `CheckStock` |
| `ConfirmCheckout` | `reserveStockForOrder()` with `ReserveStockWithTTL` + 15 min TTL | `confirm.go:131-163` |
| WarehouseID guard | Fails fast if `warehouseID == ""` + rollback already-reserved items | `confirm.go:143-146` ✅ |
| Order created | Reservation ID stored per `OrderItem` | `order/create.go` |
| Payment confirmed | `confirmReservationsForOrder()` removes TTL, commits stock | order worker |
| Payment failed | `CancelOrder()` → `releaseReservationWithRetry()` + DLQ | `cancel.go:62-93` |
| Order expired (cron) | `ReservationCleanupJob` (every 15 min) releases dangling reservations | `reservation_cleanup.go` |
| Session expired | `CheckoutSessionCleanupWorker` (every 5 min) releases reservations, resets cart | `checkout_session_cleanup.go` |
| Cart expired | `CartCleanupWorker` (every 1h) releases reservations, deletes cart | `cart_cleanup.go` |

### 1.3 Promotion / Coupon Consistency — ✅ Good

- Single-use coupon lock via `acquireCouponLocks()` (Redis SETNX) — prevents race condition.
- `MaxPromotionCodesPerOrder = 5` enforced at `validateCheckoutPrerequisites()`.
- Promo usage applied **after** order creation (best-effort, DLQ-backed, MaxRetries=10).

### 1.4 Cart ↔ Order Session Consistency — ✅ Acceptable

- Cart session ID = idempotency key for order creation (unique constraint on `cart_session_id`).
- After `createOrder` succeeds, `completeCartAfterOrderCreation()` updates cart status.
- If that fails → DLQ with `cart_cleanup` type, MaxRetries=3.
- `CartCleanupWorker` skips `checkout`/`completed` status carts + carts with `order_id` metadata. ✅

### 1.5 Shipping Fee Consistency — ⚠️ Gap (unchanged)

- Shipping fee calculated at `CalculateOrderTotals` time.
- `RevalidatePrices: true` revalidates **product prices** but **not shipping rates**.
- **Risk**: Carrier rate update between calculation and order creation.
- **Mitigation**: Window is typically < 2 seconds. Low risk in practice.

---

## 2. Data Mismatches

| # | Issue | Severity | Status | Notes |
|---|---|---|---|---|
| M-01 | ~~`default_country: "US"` vs `"VN"`~~ | P2 | ✅ FIXED | Both `config.yaml` and `constants.go` use `"VN"` |
| M-02 | `order_timeout_minutes: 30` vs `auto_cancel_minutes: 1440` | P2 | ✅ Documented | `30` = checkout session, `1440` = order payment window. Separate concerns. |
| M-03 | ~~`reservation_timeout_minutes` mismatch~~ | P1 | ✅ FIXED | Order configmap now `15` with comment "documentation-only" (`configmap.yaml:51-53`) |
| M-04 | ~~`TopicCheckoutCompleted` dead constant~~ | P2 | ✅ FIXED | Removed with "intentionally removed" comment |
| M-05 | ~~Duplicate `OrderStatusTransitions`~~ in checkout | P1 | ✅ FIXED | Removed from checkout entirely (`constants.go:176-178`) |
| M-06 | `cart.converted` minimal payload | — | ✅ OK | Analytics works fine. Loyalty uses `orders.order.completed`. |
| M-07 | **[NEW]** `codCeiling = 5_000_000` and `installmentFloor = 1_000_000` hardcoded in `confirm_guards.go:88,98` | P2 | ⚠️ OPEN | Should be configurable via ConfigMap for per-market tuning |

---

## 3. Saga / Outbox / Retry / Rollback

### 3.1 Checkout Saga (`ConfirmCheckout`) — ✅ Well Implemented

```
Step 1: Load & validate session + cart (empty cart guard ✅)
Step 2: Acquire idempotency lock (SETNX, 15min TTL, cart-version-aware ✅)
Step 3: Validate prerequisites (address, shipping method, coupon limit, per-SKU qty)
Step 3.5: Acquire per-coupon locks (Redis SETNX, race prevention ✅)
Step 4: Calculate totals (price revalidation ✅)
Step 4.5: Validate min/max order amount
Step 5: Fraud pre-check (guest high-value, SKU explosion, round-amount)
Step 6: Authorize payment (skip for COD ✅)
Step 7: Reserve stock (JIT, 15min TTL)
   ↳ warehouseID=="" guard → fail fast + rollback ✅
   ↳ Partial failure → RollbackReservationsMap (retry 3x + DLQ) ✅
Step 8: Build + create order (gRPC to Order Service)
   ↳ FAIL → RollbackReservationsMap + VoidAuthorization (DLQ if void fails) ✅
Step 9: Apply promotions (best-effort, parallel errgroup, limit=5, DLQ per promo) ✅
Step 10: Finalize (tx: outbox save + cart complete + session delete) ✅
   ↳ Tx fails → outbox recovery save out-of-tx (idempotent via unique constraint) ✅
Step 11: Store idempotency result (24h TTL)
```

### 3.2 `RollbackReservationsMap` — ✅ FIXED (was P2-CC-05)

Previously fire-and-forget. **Now** (`helpers.go:38-77`):
- Retries 3x per reservation with 100ms×N backoff
- On permanent failure → writes `FailedCompensation` with `release_reservation` type
- `FailedCompensationWorker` retries async

### 3.3 Order Creation Outbox — ✅ Good

- `CreateOrder()` wraps DB insert + `orders.order.status_changed` outbox event in `WithTransaction()`.
- Outbox worker polls every 1s, retries up to 10 times.
- ✅ **P1-CC-03 FIXED**: Prometheus counter `outbox_failed_events_total` for alerting.

### 3.4 Payment Confirmed → Reservation Confirm — ✅ Good (with DLQ)

- `confirmReservationWithRetry()`: 3 retries, exponential backoff.
- On failure → `writeReservationConfirmDLQ()` via outbox topic `compensation.reservation_confirm`.

### 3.5 Order Cancellation + Stock Return — ✅ Good

`cancel.go:62-93` handles two paths:
1. **Reservation still active**: `releaseReservationWithRetry()` (3 retries, 100ms/200ms/400ms).
2. **Reservation already confirmed** (error contains "not active"): `RestockItem()` + DLQ on fail.

Both paths have DLQ fallback via `writeReservationReleaseDLQ()`.

### 3.6 Checkout FailedCompensation Worker — ✅ Good

Retries: `void_authorization` (max 5), `apply_promotion` (max 10), `cart_cleanup` (max 3), `release_reservation` (max 3). `AlertSent` flag prevents alert spam.

---

## 4. Edge Cases — Logic Risks

### ✅ RESOLVED

| # | Edge Case | Status |
|---|---|---|
| EC-01 | Cart item added after checkout starts → cart version in idempotency key | ✅ |
| EC-02 | Stock drops to 0 between reserve and order creation | ✅ |
| EC-03 | Duplicate payment webhook → EventIdempotencyRepo dedups | ✅ |
| EC-07 | COD + failed order creation → only stock rollback, no payment | ✅ |
| EC-08 | ~~`warehouseID == ""` at reservation~~ → fail fast + rollback | ✅ FIXED |
| EC-10 | Order cleanup cancels confirmed orders → correct restock path | ✅ |

### ⚠️ OPEN

| # | Edge Case | Risk | Status | Details |
|---|---|---|---|---|
| EC-04 | Promo expires between validation and apply | High | ⚠️ P2-CC-04 | DLQ retries but promo still expired → usage counter not incremented = budget leak. Mitigated by MaxRetries=10 + alerting. |
| EC-05 | Cart expires during payment | Medium | ✅ Verified | `CartCleanupWorker` skips `checkout` status + carts with `order_id`. Safe. |
| EC-09 | No stock re-check between fraud check and reservation | Medium | ⚠️ Acceptable | Window < 1s. High-traffic flash sale risk accepted. |
| EC-11 | `auto_cancel_minutes: 1440` vs 15min reservation TTL | Medium | ✅ Verified | `ReservationCleanupJob` paginates cancelled orders and clears `ReservationID`. `OrderCleanupJob` auto-cancels both `pending` and `confirmed`. |
| EC-12 | **Loyalty points redemption not in checkout** | High | ❌ P2-CC-03 | `ecommerce-platform-flows.md §5.3` lists loyalty redemption as Step 5. Not implemented. |
| EC-13 | No retroactive re-pricing for pending orders | Low | ⚠️ By design | Keep order price, issue store credit if needed. |
| EC-14 | ~~Dual `warehouseClient` vs `warehouseInventoryService` in order~~ | Medium | ⚠️ P2-CC-07 | Still present with warning log (`reservation.go:41`). |

### 🆕 NEW EDGE CASES DISCOVERED

| # | Edge Case | Risk | Service | Details |
|---|---|---|---|---|
| EC-15 | `CheckoutSessionCleanupWorker` releases reservations without DLQ fallback | Medium | checkout | `checkout_session_cleanup.go:114` — `ReleaseReservation` failure is only logged (`Warnf`), no DLQ retry. If warehouse service is down during cleanup, reservations leak until warehouse-side TTL expires. |
| EC-16 | `ReservationCleanupJob` queries ALL cancelled orders every 15 min | Medium | order | `reservation_cleanup.go:50-65` — Paginates by `cancelledPageSize=100` but scans ALL cancelled orders (no `has_reservation_ids` filter). Performance degrades as cancelled order count grows. |
| EC-17 | `order_cleanup.go` uses `errgroup.SetLimit(10)` for concurrent cancellations but errors are swallowed | Low | order | `order_cleanup.go:66-68` — `return nil` on cancel error means errgroup never surfaces issues. OK for resilience but hides systemic failures. |
| EC-18 | `validatePaymentMethodEligibility` uses cart subtotal (no shipping/tax) for COD ceiling check | Medium | checkout | `confirm_guards.go:76-81` — Calculates `cartTotal` from items only. Final total (with shipping+tax) may exceed COD ceiling. Should use `totals.TotalAmount` from step 4. |
| EC-19 | `checkout_session_cleanup.go` sets `cart.Metadata = nil` — loses `reservation_ids` after release | Low | checkout | Line 63 — Metadata is cleared to nil. If reservation release partially failed, we lose the remaining IDs. Should only clear `reservation_ids` key, not all metadata. |

---

## 5. Event Publish Audit

### 5.1 Checkout Service — Published Events

| Topic | Published? | Where | Needed? | Assessment |
|---|---|---|---|---|
| `cart.converted` | ✅ | `finalizeOrderAndCleanup` via Outbox | ✅ Analytics, CRM | ✅ Correct |
| `orders.payment.capture_requested` | ✅ | Payment saga capture worker | ✅ Capture flow | ✅ Correct |

**No unnecessary events.** `TopicCheckoutCompleted` was removed (✅).

### 5.2 Order Service — Published Events

| Topic | Published? | Where | Needed? | Assessment |
|---|---|---|---|---|
| `orders.order.status_changed` | ✅ | Outbox (all transitions) | ✅ Fulfillment, Notification, Analytics | ✅ Correct |
| `orders.order.completed` | ✅ | Outbox (delivered) | ✅ Loyalty, Analytics | ✅ Correct |
| `orders.order.cancelled` | ✅ | Outbox | ✅ Loyalty reversal | ✅ Correct |
| `inventory.stock.committed` | ✅ | Outbox | ✅ Warehouse denorm | ✅ Correct |
| `compensation.reservation_release` | ✅ | DLQ Outbox | ✅ Async retry | ✅ Correct |
| `compensation.reservation_confirm` | ✅ | DLQ Outbox | ✅ Async retry | ✅ Correct |
| `compensation.refund_restock` | ✅ | DLQ Outbox | ✅ Async retry | ✅ Correct |
| `orders.return.*` / `orders.exchange.*` | ✅ | Return/Exchange handlers | ✅ | ✅ Correct |

**No unnecessary event publishing found.**

---

## 6. Event Subscribe Audit

### 6.1 Checkout Service — Subscriptions

| Topic | Subscribed? | Needed? | Assessment |
|---|---|---|---|
| Any | ❌ No | ❌ | ✅ Checkout is a pure write-path service. Price/stock fetched on-demand via gRPC. |

### 6.2 Order Service Worker — Subscriptions (`EventConsumersWorker`)

| Topic | Consumer | Needed? | Status |
|---|---|---|---|
| `payments.payment.confirmed` | `ConsumePaymentConfirmed` | ✅ | ✅ Wired |
| `payments.payment.failed` | `ConsumePaymentFailed` | ✅ | ✅ Wired |
| `orders.payment.capture_requested` | `ConsumePaymentCaptureRequested` | ✅ | ✅ Wired |
| `fulfillments.fulfillment.status_changed` | `ConsumeFulfillmentStatusChanged` | ✅ | ✅ Wired |
| `warehouse.inventory.reservation_expired` | `ConsumeReservationExpired` | ✅ | ✅ Wired |
| `shipping.shipment.delivered` | `ConsumeShipmentDelivered` | ✅ | ✅ Wired |
| `payments.refund.completed` | `ConsumeRefundCompleted` | ✅ | ✅ Wired (P0-CC-01 FIXED) |
| `orders.return.completed` | `ConsumeReturnCompleted` | ✅ | ✅ Wired |

**DLQ Drains**: All 8 topics have `.dlq` consumers registered (`event_worker.go:99-120`). ✅

**No missing or unnecessary subscriptions.**

---

## 7. GitOps Config Check

### 7.1 Checkout Service (`gitops/apps/checkout/base/`)

| Check | Status | Notes |
|---|---|---|
| ConfigMap `log-level: "info"` | ✅ | |
| ConfigMap `max-order-amount: "100000000"` | ✅ | Documentation-only (code reads constant) |
| ConfigMap `reservation-payment-ttl-min: "15"` | ✅ | Matches `ReservationPaymentTTL = 15 * time.Minute` |
| ConfigMap `checkout-session-timeout-min: "30"` | ✅ | Matches `MaxCheckoutSessionDuration` |
| Worker deployment uses `commonWorker` pattern | ✅ | Old `shouldRunWorker()` removed |
| **[NEW]** `codCeiling`, `installmentFloor` not in ConfigMap | ⚠️ P2 | Hardcoded in `confirm_guards.go`. Ops cannot tune per market. |

### 7.2 Order Service (`gitops/apps/order/base/`)

| Check | Status | Notes |
|---|---|---|
| `eventbus.default_pubsub: pubsub-redis` | ✅ | Matches `DaprDefaultPubSub` |
| `reservation_timeout_minutes: 15` with "documentation-only" comment | ✅ | P1-CC-02 FIXED |
| `max_items_per_order: 50` | ✅ | |
| `order_timeout_minutes: 30` | ✅ | |
| `auto_cancel_minutes: 1440` | ✅ | 24h window for pending orders |
| `default_currency: VND`, `default_country: VN` | ✅ | |
| Worker deployment `dapr.io/app-protocol: "grpc"` | ✅ | Correct for gRPC eventbus |
| Worker health probe `/healthz` on port `health` (8081) | ✅ | |
| DLQ drains registered for all consumed topics | ✅ | |

---

## 8. Worker: Events, Consumers, Cron Jobs

### 8.1 Checkout Worker (`checkout/cmd/worker`)

| Worker | Type | Interval | Job | Status |
|---|---|---|---|---|
| `CartCleanupWorker` | Cron | 1h | Cleans abandoned carts, releases reservations | ✅ Skips `checkout`/`completed` + `order_id` carts |
| `CheckoutSessionCleanupWorker` | Cron | 5m | Resets expired checkout carts to `active`, releases reservations | ⚠️ No DLQ for failed releases (EC-15) |
| `FailedCompensationWorker` | Cron | Polling | Retries: `void_auth`, `apply_promo`, `cart_cleanup`, `release_reservation` | ✅ |
| `OutboxWorker` | Continuous | ~1s | Publishes `cart.converted` events from outbox | ✅ |
| Event consumers | — | — | **None** | ✅ Correct (checkout is write-path only) |

### 8.2 Order Worker (`order/cmd/worker`)

| Worker | Type | Interval | Job | Status |
|---|---|---|---|---|
| `OutboxWorker` | Continuous | 1s, batch 50 | Publishes outbox events to Dapr | ✅ |
| `EventConsumersWorker` | Continuous | gRPC server :5005 | 8 topic consumers + 8 DLQ drains | ✅ |
| `OrderCleanupJob` | Cron | 15m | Auto-cancels expired `pending`+`confirmed` orders | ✅ (errors swallowed — EC-17) |
| `ReservationCleanupJob` | Cron | 15m | Releases reservations from expired/cancelled orders | ⚠️ Scans ALL cancelled (EC-16) |
| `DLQRetryWorker` | Cron | Polling | Retries `compensation.*` outbox events | ✅ |
| `CaptureRetryWorker` | Cron | Polling | Retries payment capture attempts | ✅ |
| `CODAutoConfirmWorker` | Cron | Interval | Auto-confirms COD orders after delivery | ✅ |
| `PaymentCompensationWorker` | Cron | Interval | Handles payment compensation flows | ✅ |
| `FailedCompensationsCleanupJob` | Cron | Interval | Cleans up old failed compensation records | ✅ |

---

## 9. Action Items Summary

### ✅ P0 — All Fixed

| ID | Item | Service | Status |
|---|---|---|---|
| P0-CC-01 | ~~`payments.refund.completed` gRPC consumer~~ | order-worker | ✅ FIXED — `event_worker.go:86` |

### ✅ P1 — All Fixed

| ID | Item | Service | Status |
|---|---|---|---|
| P1-CC-01 | ~~Guard `warehouseID == ""`~~ | checkout | ✅ FIXED — `confirm.go:143-146` |
| P1-CC-02 | ~~ConfigMap `reservation_timeout_minutes` mismatch~~ | gitops | ✅ FIXED — now `15` with doc comment |
| P1-CC-03 | ~~Outbox failed event alerting~~ | order | ✅ FIXED — Prometheus counter |
| P1-CC-04 | ~~CartCleanupWorker vs active orders~~ | checkout | ✅ FIXED — skips checkout/completed + order_id |
| P1-CC-05 | ~~Duplicate OrderStatusTransitions~~ | checkout | ✅ FIXED — removed entirely |
| P1-CC-06 | ~~ConfigMap missing business keys~~ | gitops | ✅ FIXED — added 3 reference keys |

### 🔵 P2 — Previously Open (4 FIXED, 4 remain)

| ID | Item | Service | Status |
|---|---|---|---|
| P2-CC-01 | ~~Dead `TopicCheckoutCompleted`~~ | checkout | ✅ FIXED |
| P2-CC-02 | ~~`default_country: "US"` mismatch~~ | checkout | ✅ FIXED |
| P2-CC-03 | Loyalty point redemption at checkout | checkout | ❌ OPEN (backlog feature) |
| P2-CC-04 | Promo expiry race between validation and apply | checkout | ❌ OPEN — mitigated by DLQ + MaxRetries=10 |
| P2-CC-05 | ~~Rollback errors silently swallowed~~ | checkout | ✅ FIXED — retry 3x + DLQ in `helpers.go:38-77` |
| P2-CC-06 | ~~`shouldRunWorker()` returns false for event mode~~ | checkout | ✅ FIXED — migrated to `commonWorker` |
| P2-CC-07 | Dual `warehouseClient` / `warehouseInventoryService` | order | ❌ OPEN — tech debt, has warning log |
| P2-CC-08 | `MaxOrderAmount` hardcoded as constant | checkout | ❌ OPEN — documented in ConfigMap but not read from config |

### 🆕 Newly Discovered Issues

| ID | Category | Issue | Risk | Service | Action |
|---|---|---|---|---|---|
| NEW-01 | Resilience | `CheckoutSessionCleanupWorker` has no DLQ for failed reservation releases | Medium | checkout | Add DLQ fallback when `ReleaseReservation` fails in `checkout_session_cleanup.go:114` |
| NEW-02 | Performance | `ReservationCleanupJob` scans ALL cancelled orders every 15 min | Medium | order | Add `has_active_reservation=true` DB filter or track `reservation_cleared_at` |
| NEW-03 | Logic | `validatePaymentMethodEligibility` uses subtotal (no shipping/tax) for COD ceiling | Medium | checkout | Move COD ceiling check after `CalculateOrderTotals` using `totals.TotalAmount` |
| NEW-04 | Config | `codCeiling` and `installmentFloor` hardcoded | P2 | checkout | Extract to ConfigMap / constants for per-market tuning |
| NEW-05 | Data Safety | Session cleanup clears ALL metadata (`cart.Metadata = nil`) — drops remaining reservation IDs if partial release fails | Low | checkout | Only clear `reservation_ids` key, preserve other metadata |

---

## Event Architecture Summary

```
[Checkout Service]
  PUBLISHES:
    → cart.converted                       (Outbox → Analytics, CRM)
    → orders.payment.capture_requested     (Saga → Payment)
  SUBSCRIBES: NONE ✅

[Order Service]
  PUBLISHES:
    → orders.order.status_changed          (Outbox → Fulfillment, Notification, Analytics)
    → orders.order.completed               (Outbox → Loyalty, Analytics)
    → orders.order.cancelled               (Outbox → Loyalty)
    → inventory.stock.committed            (Outbox → Warehouse)
    → compensation.*                       (DLQ Outbox → Self-retry)
    → orders.return.* / orders.exchange.*  (Return/Exchange)
  SUBSCRIBES (worker gRPC):
    ← payments.payment.confirmed           ✅
    ← payments.payment.failed              ✅
    ← orders.payment.capture_requested     ✅
    ← fulfillments.fulfillment.status_changed ✅
    ← warehouse.inventory.reservation_expired ✅
    ← shipping.shipment.delivered          ✅
    ← payments.refund.completed            ✅
    ← orders.return.completed              ✅
  DLQ DRAINS: All 8 topics ✅
```

---

## Comparison with Previous Review (2026-03-02)

| Category | Previous | Current | Delta |
|---|---|---|---|
| P0 items | 1 (all fixed) | 1 (all fixed) | No change |
| P1 items | 6 (all fixed) | 6 (all fixed) | No change |
| P2 items open | 8 | 4 | **-4** (P2-CC-01,02,05,06 FIXED) |
| New issues | 0 | 5 | **+5** (NEW-01..05) |
| Event consumers | 7 | 8 | +1 (`orders.return.completed`) |
| DLQ drains | Not tracked | 8 registered | Improved observability |

---

*Generated: 2026-03-07 | Previous: 2026-03-02 | All P0/P1 verified fixed. 4 P2 resolved. 5 new issues discovered.*

# User Flow Business Logic Review Checklist — v5

> **Date**: 2026-02-19 | **Reviewer**: AI Senior Review  
> **Scope**: Full user purchase flow: Auth → Checkout → Order → Payment → Warehouse → Fulfillment → Shipping → Loyalty → Notification  
> **Methodology**: Shopify/Shopee/Lazada patterns, codebase deep-dive, cross-service event tracing  
> **Legend**: 🟢 Implemented ✅ | 🟡 Partial / Needs Improvement ⚠️ | 🔴 Missing / High Risk ❌

---

## 1. Data Consistency Between Services

### 1.1 Price / Total Amount Consistency

| Check | Status | Location | Notes |
|-------|--------|----------|-------|
| Checkout re-validates prices at confirm time (`RevalidatePrices: true`) | 🟢 | `checkout/biz/checkout/confirm.go:280` | Calls pricing service in errgroup |
| Order service performs sanity check on TotalAmount vs Σ items | 🟢 | `order/biz/order/create.go:292` | `validateOrderTotals()` with 5-cent tolerance |
| `TotalAmount` passed as `float64` between checkout→order→event | 🟡 | Multiple services | `float64` can accumulate rounding errors; Shopee/Lazada use integer cents. Shipping money fields were migrated but `TotalAmount` in `OrderStatusChangedEvent` still uses `float64` |
| Discount amount applied by promotion exactly matches what checkout calculated | 🟡 | `checkout/biz/checkout/confirm.go:399` | Promotion applied best-effort after order creation; usage count increment may fail silently (DLQ registered, but discount is already given) |
| COD order amount never re-validated after auto-confirm | 🔴 | `notification/eventbus/order_status_consumer.go:183` | COD confirmed by notification consumer, but no second price check |

### 1.2 Stock / Inventory Consistency

| Check | Status | Location | Notes |
|-------|--------|----------|-------|
| Stock reservation created during cart add-to-cart | 🟢 | `warehouse/biz/reservation` | TTL-based reservation |
| Reservation extended at checkout confirm (payment window) | 🟢 | `checkout/biz/checkout/confirm.go:615` | Extended to `ReservationPaymentTTL` |
| Reservation validated before payment authorization | 🟢 | `checkout/biz/checkout/confirm.go:509` | Parallel validation in `extractAndValidateReservations()` |
| Reservation validated AGAIN before payment capture | 🟢 | `order/eventbus/payment_consumer.go:197` | `validateStockForOrder()` before capture call |
| Reservation confirmed (stock deducted) only after payment captured | 🟢 | `order/eventbus/payment_consumer.go:305` | `processPaymentConfirmed()` triggers `confirmOrderReservations()` |
| Partial reservation confirm rollback on failure | 🟢 | `order/biz/order/create.go:342` | `confirmOrderReservations()` tracks and releases partial |
| Reservation released on payment failure | 🟢 | `order/eventbus/payment_consumer.go:392` | `releaseWarehouseReservations()` with DLQ fallback |
| Reservation released on order cancel (from fulfillment cancel) | 🟢 | `order/eventbus/fulfillment_consumer.go:143` | Routes to `CancelOrder()` which triggers release |
| Reservation expiry event cancels pending order | 🟢 | `order/eventbus/warehouse_consumer.go:157` | Only cancels `pending` status orders |
| Items with `reservation_id = nil` fall back to generic stock check | 🟡 | `order/eventbus/payment_consumer.go:453` | Fallback exists but no retry on fallback failure |
| Multi-warehouse order: all reservations from correct warehouse | 🟡 | `order/biz/order/create.go:58` | `WarehouseID` per item stored, but confirmed globally not per-warehouse atomically |

### 1.3 Order ↔ Payment Status Consistency

| Check | Status | Location | Notes |
|-------|--------|----------|-------|
| Order `payment_status` updated to `completed` after capture | 🟢 | `order/eventbus/payment_consumer.go:245` | With `[CRITICAL]` log on DB update failure, triggers Dapr retry |
| Order `payment_status` updated to `failed` on capture failure | 🟢 | `order/eventbus/payment_consumer.go:207` | Outbox emits `payment.capture_failed` |
| Auth expiry check (7-day) before capture attempt | 🟢 | `order/eventbus/payment_consumer.go:164` | Sets order to `capture_failed` |
| `PaymentSagaState` idempotency on capture re-delivery | 🟢 | `order/eventbus/payment_consumer.go:156` | `captured` state → early return |
| Payment void on order creation failure persisted to DLQ | 🟢 | `checkout/biz/checkout/confirm.go:355` | `FailedCompensation` with `MaxRetries: 5` |
| **MISMATCH RISK**: Payment `captured` in gateway but order DB update fails | 🟡 | `order/eventbus/payment_consumer.go:253` | Returns error to trigger Dapr retry; idempotency guard prevents re-capture — **correct**. But if Dapr retries exceed max, the DLQ only logs, no `FailedCompensation` written for this specific case |

### 1.4 Order ↔ Fulfillment Status Consistency

| Check | Status | Location | Notes |
|-------|--------|----------|-------|
| Backward status transition prevented | 🟢 | `order/eventbus/fulfillment_consumer.go:170` | `constants.IsLaterStatus()` guard |
| `fulfillment.completed` → order stays `shipped` (not `delivered`) | 🟢 | `order/eventbus/fulfillment_consumer.go:203` | Correct: delivery driven by shipping service |
| No `order.completed` event published when fulfillment completes | 🟡 | Fulfillment consumer | Loyalty-rewards listens to `order.completed` but Order service only emits `order.status_changed`. **Who publishes `order.completed`?** |

### 1.5 Loyalty Points Consistency

| Check | Status | Location | Notes |
|-------|--------|----------|-------|
| Points earned on `order.completed` event | 🟡 | `loyalty-rewards/worker/event/consumer.go:76` | Consumer exists, but no idempotency check in loyalty worker |
| Points deducted on `order.cancelled` | 🟡 | `loyalty-rewards/worker/event/consumer.go:81` | Consumer registered, but `handleOrderCancelled` implementation not verified to be atomic |
| **MISMATCH RISK**: Points earned, then order cancelled → points not reversed | 🔴 | `loyalty-rewards/biz/loyalty.go` | `EarnPoints` and `RedeemPoints` have no saga/rollback. If cancel event arrives after earn, no automatic deduction |
| Tier upgrade check races with concurrent earn events | 🟡 | `loyalty-rewards/biz/loyalty.go:212` | `checkTierUpgrade` called after `EarnPoints` but NOT in same DB transaction |
| No DLQ for loyalty point failures | 🔴 | `loyalty-rewards/worker/event/consumer.go` | Uses basic `commonWorker`, no `FailedCompensation` or DLQ write on loyalty failures |

---

## 2. Data Mismatches (Mismatched Fields)

| Risk | Severity | Services | Detail |
|------|----------|----------|--------|
| `TotalAmount` as `float64` across the saga | HIGH | checkout, order, payment, notification | Accumulated float rounding. Use `int64` cents (Shopify pattern). Already fixed in shipping but not in core order total |
| Shipping `cost` field: `float64` in event vs `int64` in model | MEDIUM | checkout, shipping, order | Shipping cost fixed to int64 in biz layer but event payload still uses `float64` |
| `order.completed` topic consumed by loyalty, but Order service emits `order.status_changed` | HIGH | order, loyalty | **Topic name mismatch**: loyalty listens `order.completed`, order publishes `order.status_changed`. Points will never be earned if these topics differ — verify Dapr subscription routes match |
| `warehouse.inventory.reservation_expired` topic defined locally in `warehouse_consumer.go` as a constant, but is this what warehouse actually publishes? | MEDIUM | order, warehouse | Should be in `common/constants` to avoid divergence |
| `FulfillmentStatusChangedEvent.Items` only contains `ProductID`, `ProductSKU`, `Quantity` — no `ReservationID` | LOW | order, fulfillment | If order needs to release per-item reservations from fulfillment events, `ReservationID` is missing from the fulfillment event payload |
| Notification `RecipientID` is always `nil` in order notifications | MEDIUM | notification | `order_status_consumer.go:244`: `RecipientID: nil` — Telegram sends to admin, not the customer who placed the order |
| `CartID` vs `CartSessionID` dual field naming | LOW | checkout, order | Checkout uses `CartID` and `CartCartID` interchangeably; order uses `CartSessionID`. Adds confusion and potential bug if wrong field passed |

---

## 3. Retry & Rollback Mechanisms (Saga / Outbox)

### 3.1 Outbox Pattern

| Service | Publishes via Outbox | Topics | Status |
|---------|---------------------|--------|--------|
| Order | ✅ | `order.status_changed`, `inventory.stock.committed`, `payment.capture_requested`, `payment.capture_failed`, `payment.captured` | 🟢 Full outbox within DB transaction |
| Checkout | ✅ | `cart.converted` | 🟡 Partial: event published outside DB transaction, error only logged |
| Warehouse | ❓ | `warehouse.inventory.reservation_expired` | 🟡 Not verified to use Outbox — if not, event can be lost on crash |
| Loyalty | ❌ | No outbox | 🔴 Points mutations not protected by Outbox; crash between DB write and event ACK can lose points |
| Notification | N/A | Consumes only | — |
| Fulfillment | ❓ | `fulfillment.status_changed` | 🟡 Not verified |

### 3.2 Saga Compensation (DLQ)

| Saga Step | Compensation | DLQ / Retry | Status |
|-----------|-------------|-------------|--------|
| Payment auth void after order creation failure | `FailedCompensation` record, `MaxRetries: 5` | 🟢 Correctly implemented |
| Cart cleanup after order creation | `FailedCompensation` record, `MaxRetries: 3` | 🟢 Implemented |
| Promotion usage increment after order creation | `FailedCompensation` record, `MaxRetries: 3` | 🟢 Best-effort with DLQ |
| Warehouse reservation release after payment failure | `writeWarehouseDLQ()` + `FailedCompensation` | 🟢 Implemented |
| Payment capture failure → order state update | Dapr retry via error return | 🟡 Relies entirely on Dapr max-retries; no `FailedCompensation` written if Dapr gives up |
| Loyalty point reverse on order cancel | ❌ No compensation | 🔴 **Missing rollback** |
| Notification DLQ → actual persistence | Logs only, no DB record | 🔴 `sendToDeadLetterQueue()` has `TODO: Persist to dead_letter_events table` — unimplemented |
| FailedCompensation processor / worker | Exists? | 🟡 DLQ records are written to DB but no evidence of a background worker processing them automatically |

### 3.3 Idempotency Coverage

| Event | Idempotency Strategy | Status |
|-------|---------------------|--------|
| `payment.confirmed` | `DeriveEventID("payment_confirmed", orderID)` + DB check | 🟢 |
| `payment.failed` | `DeriveEventID("payment_failed", orderID)` + DB check | 🟢 |
| `payment.capture_requested` | `PaymentSagaState == captured` check | 🟢 |
| `fulfillment.status_changed` | `DeriveEventID(fulfillmentID + ":" + newStatus)` | 🟢 |
| `shipping.shipment.delivered` | `DeriveEventID(shipmentID)` | 🟢 |
| `warehouse.reservation_expired` | `DeriveEventID(reservationID)` | 🟢 |
| `order.completed` (loyalty) | ❌ No idempotency | 🔴 Duplicate `order.completed` events → double points earned |
| `order.cancelled` (loyalty) | ❌ No idempotency | 🔴 |
| `order.status_changed` (notification) | Time-bucketed event ID (1-min window) | 🟡 1-min bucket may miss genuine same-minute replays |
| Checkout confirm (Redis SETNX) | `TryAcquire` + 15-min TTL | 🟢 |
| Order create (DB unique constraint on `cart_session_id`) | Idempotency hit → return existing order | 🟢 |

---

## 4. Unhandled Edge Cases (Risk Register)

### P0 — Critical (Production-blocking)

| ID | Edge Case | Affected Flow | Risk | Recommended Fix |
|----|-----------|---------------|------|----------------|
| EC-P0-1 | **`order.completed` topic never published** — Loyalty listens `order.completed` but Order only emits `order.status_changed`. Points are NEVER earned | Order→Loyalty | Points engine silent failure | Add `order.completed` Outbox event when order status transitions to `delivered`, OR update Loyalty consumer to listen to `order.status_changed` with `newStatus == "delivered"` |
| EC-P0-2 | **Loyalty points earned, order then cancelled — no refund** | Payment→Loyalty | Points leak, user gets free points | Implement `DeductPoints` compensation on `order.cancelled` event in Loyalty worker with idempotency |
| EC-P0-3 | **FailedCompensation records accumulate but no background worker processes them** | All compensation flows | Orphaned DB records, void/refund never retried automatically | Implement `FailedCompensationWorker` that polls pending records and replays operations |
| EC-P0-4 | **Notification DLQ not persisted** — `sendToDeadLetterQueue()` only logs, doesn't persist to DB | Notification | Notification failures invisible in ops | Implement `dead_letter_events` table insert as the TODO comments indicate |

### P1 — High (Customer-impact)

| ID | Edge Case | Affected Flow | Risk | Recommended Fix |
|----|-----------|---------------|------|----------------|
| EC-P1-1 | **Duplicate loyalty points on event replay** — No idempotency in loyalty worker | Order→Loyalty | Customer gets 2× points on Dapr retry | Add `source_id` unique constraint or idempotency check in `EarnPoints` using `sourceID` |
| EC-P1-2 | **COD order: no refund/compensation path** — COD auto-confirmed, no payment gateway void if cancelled after dispatch | COD→Cancel | Money collected but order returned — no refund saga | For COD, implement manual refund workflow with `FailedCompensation` or human review step |
| EC-P1-3 | **`RecipientID: nil` in order notifications** — Customer not notified, only admin/Telegram bot receives | Notification | Customer UX: no SMS/email on order status | Resolve customer contact from `CustomerID` using customer gRPC client in `OrderStatusConsumer` |
| EC-P1-4 | **Multi-item order with different warehouses: reservation confirm partially fails** — rollback in `confirmOrderReservations` releases already-confirmed items, but Order DB already has `payment_status: completed` | Payment→Warehouse | Stock inconsistency: paid order, stock partially deducted | Wrap `confirmOrderReservations` in DB transaction alongside Order state update |
| EC-P1-5 | **Authorization expires between checkout and Dapr retry of capture** — 7-day check based on `order.created_at`, but if order was created on day 6.9, retry on day 7 fails with auth_expiry | Payment Capture | Capture abandoned, user charged but no fulfillment | Proactively check auth expiry before scheduling `payment.capture_requested` and trigger immediate capture if close to expiry |

### P2 — Medium (Reliability / Edge)

| ID | Edge Case | Affected Flow | Risk | Recommended Fix |
|----|-----------|---------------|------|----------------|
| EC-P2-1 | **Checkout idempotency lock held for 15 min, cart items expire** — If reservation TTL < 15 min, user retry gets "reservation expired" instead of cached result | Checkout | User sees error on retry of successful checkout | Return cached idempotency result before reservation validation when lock is held by another request |
| EC-P2-2 | **`warehouse.inventory.reservation_expired` topic defined as local constant** in `warehouse_consumer.go`, not in `common/constants` | Order→Warehouse | Topic mismatch if warehouse publishes with different name | Move to `common/constants/events.go` |
| EC-P2-3 | **Promotion applied concurrently to >MaxPromotionCodesPerOrder** — validation is in checkout, but `ApplyPromotion` is fired in goroutine pool. If promotion service is slow, concurrent goroutines may both pass the limit | Checkout→Promotion | Exceed promotion usage limits | Apply `MaxPromotionCodesPerOrder` to goroutine limit or check sequentially |
| EC-P2-4 | **Order cancelled by reservation expiry after payment authorized (pre-capture)** — Warehouse consumer allows only `pending` orders to be auto-cancelled, but authorization is valid for 7 days | Warehouse→Order→Payment | Void of authorized payment never triggered since order status changes to `cancelled` without voiding auth | On `cancelled` transition for orders with `auth_id`, trigger void compensation |
| EC-P2-5 | **Tier upgrade loses race with concurrent `EarnPoints`** — `checkTierUpgrade` reads account after earn, but another concurrent earn could change points again | Loyalty | Tier not upgraded correctly | Use optimistic lock / row version on `LoyaltyAccount.UpdateAccount` |
| EC-P2-6 | **Fulfillment `cancelled` maps to order `cancelled` via `CancelOrder()`** but if COD and payment already collected (cod_collected), cancel doesn't trigger COD refund | Fulfillment→Order→COD | Money collected, customer doesn't receive refund | Add COD refund compensation in `CancelOrder()` when `payment_method == cod` and `cod_status == collected` |
| EC-P2-7 | **`float64` total amount rounding across saga** — Checkout calculates `TotalAmount`, passes to order, notification formats with `%.2f`. Accumulated FP errors | Checkout→Order→Notification | Price displayed differs by ±0.01 | Standardize on `int64` cents (Shopify/Lazada pattern) for `TotalAmount` |
| EC-P2-8 | **Shipment delivered event from legacy PascalCase format** silently falls back if legacy decode fails | Shipping→Order | `order_id` empty → nil delivery notification | Add metric/alert when PascalCase fallback is triggered |

### P3 — Low (Tech Debt / Observability)

| ID | Edge Case | Affected Flow | Notes |
|----|-----------|---------------|-------|
| EC-P3-1 | No structured trace-ID propagation from checkout through loyalty | All | Observability broken across saga boundary |
| EC-P3-2 | `formatOrderStatusChangedMessage` dead code in notification consumer | Notification | Remove or wire to applicable status changes |
| EC-P3-3 | `CartID` / `CartCartID` / `CartSessionID` naming inconsistency | Checkout↔Order | Should be unified to `cart_session_id` |
| EC-P3-4 | Auth expiry window hardcoded as 7 days | Payment | Should be config-driven and aligned with actual gateway TTL per payment method |
| EC-P3-5 | Notification consumer retry is `time.Sleep()` in handler goroutine | Notification | Blocks Dapr subscriber thread; prefer returning error for Dapr-managed retry |

---

## 5. Summary Risk Matrix

| Priority | Count | Status |
|----------|-------|--------|
| 🔴 P0 — Critical | 4 | **Must fix before production** |
| 🟡 P1 — High | 5 | Fix in current sprint |
| 🟠 P2 — Medium | 8 | Fix in next sprint |
| ⚪ P3 — Low | 5 | Tech debt backlog |

### Critical Path for Production Readiness

```
1. EC-P0-1: Fix order.completed topic mismatch → loyalty points never earned
2. EC-P0-3: Implement FailedCompensationWorker → all DLQ records processed
3. EC-P0-2: Add loyalty point rollback on order.cancelled
4. EC-P0-4: Persist notification DLQ to dead_letter_events table
```

---

## 6. Services Verified in This Review

| Service | Files Reviewed | Event Consumers | Outbox |
|---------|---------------|-----------------|--------|
| `checkout` | `confirm.go`, `pricing_engine.go`, `validation.go` | Publisher only | Partial |
| `order` | `create.go`, `payment_consumer.go`, `fulfillment_consumer.go`, `warehouse_consumer.go`, `shipping_consumer.go` | 4 consumers | ✅ Full |
| `warehouse` | `biz/reservation` (structure) | Via worker | ❓ Not verified |
| `payment` | `biz/payment` (structure) | Via order consumer | — |
| `loyalty-rewards` | `biz/loyalty.go`, `worker/event/consumer.go` | 3 topics | ❌ None |
| `notification` | `eventbus/order_status_consumer.go` | 2 consumers | N/A |
| `fulfillment` | Event structure only | Via order consumer | ❓ Not verified |
| `shipping` | Event decode (via order consumer) | Via order consumer | ❓ Not verified |

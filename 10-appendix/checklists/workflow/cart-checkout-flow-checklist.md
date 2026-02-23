# Cart & Checkout Flow — Business Logic Review Checklist

**Date**: 2026-02-21
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `checkout/`, `order/`, `warehouse/`, `pricing/`, `promotion/`, `payment/`, `shipping/`

> Builds on **previous sprint review** ([checkout-flow-business-logic-review.md](../lastphase/checkout-flow-business-logic-review.md)).
> Focus: current code state, remaining open issues, newly found gaps, and cross-service flow accuracy.

---

## 1. Data Consistency Between Services

| Data Point | Source of Truth | Consumer | Status | Risk |
|------------|----------------|----------|--------|------|
| Cart item price at checkout | Pricing service (revalidated at confirm) | Checkout `CalculateOrderTotals(RevalidatePrices: true)` | ✅ Re-validated | Time-of-display vs time-of-confirm delta possible |
| Stock at add-to-cart | Warehouse (hard) / Catalog (fallback for no warehouseID) | Checkout `checkStockInParallel` | ⚠️ Fallback path | Catalog stock not reservation-aware |
| Stock at confirm | Warehouse reservation | `validateStockBeforeConfirm → validateStockAvailability → checkStockInParallel` | ⚠️ **Still uses Catalog fallback** | See P0-002 below |
| Reservation status | Warehouse | `extractAndValidateReservations` | ✅ Parallel gRPC with status check | Clock skew risk P1-002 |
| Coupon usage count | Promotion service | `apply_promotion` after order creation | ⚠️ Best-effort | P0-005: MaxRetries=10 + DLQ ✅; but usage CAN diverge |
| Order amount | Checkout totals engine | Order service (receives pre-computed totals) | ✅ Totals locked at confirm | Order service trusts checkout amounts |
| Shipping fee in cart preview | Shipping service (using `"default"` warehouse) | `cart/totals.go` | ⚠️ **Hardcoded origin** | P1-001: Different from confirm-time warehouse origin |
| Cart status after order creation | Checkout local DB | Order service (event-driven) | ✅ `completeCartAfterOrderCreation` | DLQ fallback for cleanup failures |
| Promotion discount in cart vs confirm | Promotion service (revalidated) | `pricing_engine.go:ValidateAndApplyPromotions` | ✅ Re-validated at confirm | Single-use coupon race possible in parallel checkouts |

---

## 2. Data Mismatches Found

### 2.1 P0-002 — Catalog Stock Fallback Still Active at Confirm Time (Fixed)

**Status**: ✅ **FIXED** — Extracted `validateStockForConfirm()` that fails closed when warehouseID is nil.

```go
// checkout/internal/biz/checkout/validation.go:161-183
if warehouseID == nil || *warehouseID == "" {
    // ← This path calls catalogClient.GetProductPrice during ConfirmCheckout
    productPrice, err := uc.catalogClient.GetProductPrice(gCtx, item.ProductID, false)
    availableQty = int32(productPrice.Stock)
}
```

`validateStockAvailability` → `checkStockInParallel` — same function used for both `ValidateInventory` (pre-checkout display) and `validateStockBeforeConfirm` (confirm step). Cart items without a `warehouseID` still fall back to Catalog stock at confirm time. Catalog stock is **not reservation-aware** — in-flight reservations are not subtracted.

- **Risk**: Two customers can both confirm checkout for the last unit if neither has a warehouseID assigned yet.
- **Shopify resolution**: Call `WarehouseService.CheckStock` unconditionally at confirm time; return error if warehouseID is missing.
- `- [x]` **Fix**: Extract separate `validateStockForConfirm()` that **fails closed** when warehouseID is nil

---

### 2.2 P1-001 — Shipping Fee Mismatch Between Cart Preview and Confirm (Still Open)

`cart/totals.go:getWarehouseOriginAddress()` uses `"default"` warehouse hardcoded.
`confirm.go` passes `shippingAddr` from cart to `CalculateOrderTotals` but origin warehouse comes from `X-Warehouse-ID` header.

Customer sees one shipping fee at cart review; different fee at order creation.

- `- [ ]` **Fix**: Store `warehouseID` in cart session at `StartCheckout`; use it consistently through preview → confirm

---

### 2.3 Coupon Code Dual Storage (P1-004 — Partially Open)

`confirm.go:306` reads `bizSession.PromotionCodes` from session (correct).
But `cart/totals.go` also reads `coupon_code` from cart metadata in some paths.
If a user applies a coupon after session is started, the session is not updated.

- `- [x]` **Fix**: Consolidate coupon storage to `CheckoutSession.PromotionCodes` only; update session on every coupon apply

---

## 3. Event Publishing — Service-by-Service Audit

| Service | Event Published | Method | Needed By | Verdict |
|---------|----------------|--------|-----------|---------|
| **Checkout** | `checkout.cart.converted` | ✅ Outbox pattern (`finalizeOrderAndCleanup`) | Analytics, CRM, Loyalty | ✅ Fixed (P0-003) |
| **Checkout** | (no other outbound events) | Outbox worker runs inside checkout binary | — | ✅ Correct |
| **Order** | `order.status.changed` | Outbox or direct (need to verify in order service) | Checkout (refund), Payment, Shipping, Notification | ✅ Documented |
| **Order** | `order.payment.capture_requested` | ✅ Outbox | Payment service capture consumer | ✅ Saga P1-05 implemented |
| **Order** | `order.payment.captured` / `order.payment.capture_failed` | ✅ Outbox | Fulfillment trigger | ✅ |
| **Payment** | `payment.confirmed` / `payment.failed` | Webhook → Dapr | Order service | ✅ Described in checkout_flow_issues.md |
| **Warehouse** | `warehouse.stock.changed` | On reservation confirm / release | Catalog, Search | ✅ |
| **Promotion** | No event needed for usage increment | Rely on synchronous gRPC retry | — | ⚠️ Best-effort, see P0-005 |

---

## 4. Event Subscription — Service-by-Service Audit

| Service | Event Consumed | Reason | Verdict |
|---------|---------------|--------|---------|
| **Checkout** | ❌ **NO events consumed** | Checkout worker has only cron jobs + outbox; no Dapr subscriber | ✅ Correct — checkout is purely request-driven |
| **Order** | `payment.confirmed` | Mark order PAID; trigger fulfillment | ✅ |
| **Order** | `payment.failed` | Update order status; cancel reservation | ✅ |
| **Order** | `order.payment.captured` | Advance saga state | ✅ |
| **Order** | `fulfillment.shipped` | Update order to SHIPPED | ✅ |
| **Warehouse** | `order.status.changed` (→ PAID) | Confirm inventory reservation | ✅ |
| **Warehouse** | `fulfillment.status.changed` | Release / deduct stock on ship | ✅ |
| **Pricing** | `warehouse.stock.changed` | Adjust tier pricing on low stock | ✅ |
| **Promotion** | (no direct subscription needed) | Promotion apply is synchronous gRPC | ✅ |

---

## 5. Saga Pattern & Outbox Implementation Audit

### 5.1 Payment Saga (Authorize → Capture)

| Phase | Implementation | File | Status |
|-------|---------------|------|--------|
| Auth → Order Creation | Sequential in `ConfirmCheckout` | `confirm.go:340-379` | ✅ |
| SAGA-001: Void auth on order creation failure | `paymentService.VoidAuthorization` + DLQ fallback | `confirm.go:382-415` | ✅ |
| Capture via outbox + consumer | `order.payment.capture_requested` event | `checkout_flow_issues.md P1-05` | ✅ |
| Payment Capture Retry Worker | Exponential backoff, max retries | `order/internal/worker/cron/capture_retry` | ✅ |
| Payment Compensation Job | Void auth + cancel order after max failures | `order/internal/worker/cron/compensation` | ✅ |

### 5.2 Checkout Compensation Worker (`failed_compensation.go`)

| Operation | Handler | Max Retries | Backoff | Status |
|-----------|---------|-------------|---------|--------|
| `release_reservations` | `retryReleaseReservations` | `comp.MaxRetries` | Exp: 1min → 2h | ✅ |
| `void_authorization` | `retryVoidAuthorization` | 5 (money at risk) | Exp: 1min → 2h | ✅ |
| `cart_cleanup` | `retryCartCleanup` | 3 | Exp: 1min → 2h | ✅ |
| `apply_promotion` | `retryApplyPromotion` | 10 (P0-005 fix) | Exp: 1min → 2h | ✅ |

### 5.3 Outbox Worker State

| Check | Value | Status |
|-------|-------|--------|
| Poll interval | 1 second | ✅ |
| Batch size | 50 events | ✅ |
| Max retry count before FAILED | 10 | ✅ |
| Stuck event recovery (processing → pending) | Every 10 cycles (≈10s) after 5-min threshold | ✅ |
| Old event cleanup | Every 10 cycles, 30-day retention | ✅ |
| `SELECT FOR UPDATE SKIP LOCKED` on `ListPending` | **NOT VERIFIED** | ⚠️ Check `outboxRepo.ListPending` implementation |

---

## 6. Retry & Rollback Edge Cases

### 🔴 P0 — Critical (Money / Oversell Risk)

| Issue | Description | File | Fix |
|-------|-------------|------|-----|
| **P0-002** | `checkStockInParallel` still calls Catalog when `warehouseID` is nil — used at both ValidateInventory (display) AND validateStockAvailability (confirm step). Catalog stock is not reservation-aware → oversell risk. | `validation.go:161-183` | ✅ Fails closed if warehouseID missing |
| **P0-007** | `buildOrderRequest` at line 127 dereferences `*req.CustomerID` directly — **will panic if CustomerID is nil** for guest checkout attempting `ConfirmCheckout`. | `confirm.go:127` | ✅ Nil guard added |

### 🟡 P1 — High Priority

| Issue | Description | File | Fix |
|-------|-------------|------|-----|
| **P1-001** | Shipping fee uses `"default"` warehouse in cart preview, `X-Warehouse-ID` at confirm | `cart/totals.go:30-51` | Store warehouseID in session at `StartCheckout` |
| **P1-002** | Reservation expiry: `time.Now().After(*res.ExpiresAt)` uses local clock — k8s clock skew can disagree with Warehouse authoritative time | `confirm.go:584-586` | Add `is_expired` flag to `GetReservation` response on Warehouse side |
| **P1-003** | `extendReservationsForPayment`: now parallel (`errgroup`), but still not atomic — partial extension leaves reservations in mixed-TTL state | `confirm.go:659-693` | Implement bulk `ExtendReservations` API in Warehouse; or roll back already-extended on partial failure |
| **P1-004** | Coupon code stored in BOTH `checkout_session.promotion_codes` AND `cart.metadata.coupon_code` — can diverge post-session-creation | `cart/totals.go:139-155` | ✅ Array read logic updated |
| **P1-005** | Outbox `recoverStuckEvents` resets processing → pending. If the previous publish succeeded but the status update failed (network timeout mid-write), the event is republished and consumers must be idempotent | `outbox/worker.go:164-188` | Verify all outbox consumers implement `event_id` deduplication |
| **P1-008** | `ConfirmCheckout` idempotency uses per-cart key but allows concurrent confirms for different cart IDs for same customer | `confirm.go:238-269` | ✅ Rate limit lock added |

### 🔵 P2 — Logic Gaps / Edge Cases

| Issue | Description | Fix |
|-------|-------------|-----|
| **P2-001** | ✅ Fixed — CustomerID nil guard on promo apply | — |
| **P2-002** | Integer arithmetic (cents) not used throughout pricing engine — float accumulation on 100+ items can create $0.01 rounding drift | Use `int64` cents everywhere; convert to float only on output |
| **P2-003** | Shipping tax base: preview uses `netShipping` (post-discount), confirm uses `shippingCost` (pre-discount) | ✅ Aligned to netShipping |
| **P2-004** | ✅ Fixed — Staleness threshold unified to `constants.StockFallbackStalenessThreshold` | — |
| **P2-005** | ✅ Fixed — Empty cart guard in `loadAndValidateSessionAndCart` | — |
| **P2-006** | ✅ Fixed — COD skips payment auth (uses `cod-auth-skipped` auth result) | — |
| **P2-007** | `getCartCartID()` type-asserts `session.Metadata["cart_session_id"].(string)` — silent fallback to raw cartID if stored as non-string | ✅ Coercion added |
| **P2-008** | ✅ Fixed — `MaxOrderAmount` ceiling enforced at `confirm.go:335-338` | — |
| **P2-009** | Promotion race: two customers applying the same single-use coupon simultaneously can both pass `ValidateCoupon` — promotionService.ApplyPromotion is called after order creation, not in the same transaction | Promotion service must do atomic usage check+increment in Redis/DB lock |

---

## 7. Business Logic Edge Cases (Shopify/Shopee/Lazada Patterns)

### 7.1 Cart Management Gaps

- [ ] **No guest cart → login merge**: When a guest user logs in mid-session, the guest `cart_session_id` and logged-in user's existing cart are NOT merged. Guest cart items are silently abandoned.
  - *Shopify pattern*: `CartMerge` API call on login; merge guest items into user cart with conflict resolution.

- [ ] **No inactivity expiry trigger**: Cart expiry is checked at `AddToCart` time, but an idle cart is not expired proactively. A cart created 45 days ago with no mutations is still accepted at checkout.
  - *Lazada pattern*: Background `cart_cleanup` job checks and marks carts inactive after TTL.
  - The `cart_cleanup.go` cron in checkout handles expired carts — but only by marking inactive, not by releasing warehouse reservations.
  - `- [x]` `cart_cleanup` cron must also release any active warehouse reservations on expiry

- [ ] **Cart sharing / link not implemented**: Platform flows document (section 5.1) mentions cart sharing via shareable link. Not found in checkout service.

- [ ] **Save-for-later (wishlist from cart)**: Mentioned in section 5.1 of ecommerce-platform-flows.md. Not implemented in checkout service. Items removed from cart are simply deleted, not offered as "save for later."
  - *Shopee pattern*: "Move to Wishlist" button on each cart item.

- [ ] **Back-in-stock notification for out-of-stock cart items**: If stock check at checkout fails, the user gets an error but is NOT subscribed to restock notifications.
  - *Shopee/Lazada pattern*: On OOS at checkout, auto-subscribe to `product.stock.replenished` for the SKU.

### 7.2 Checkout Validation Gaps

- [ ] **No fraud pre-check** (referenced in ecommerce-platform-flows.md section 5.4): There is no velocity check or blacklist check before payment authorization. A single compromised card can attempt unlimited `ConfirmCheckout` calls (idempotency lock prevents doubles for same cart but not for different carts).
  - *Shopify pattern*: Fraud score from Signifyd/Stripe Radar injected before `authorizePayment`.
  - `- [ ]` Add fraud score API call between steps 4 (min/max order) and 5 (authorize payment)

- [ ] **No address delivery zone validation** (referenced in section 5.4): `validateCheckoutPrerequisites` checks `ShippingAddress != nil` and shipping method selected, but does NOT validate that the shipping address is within the delivery zone for the chosen carrier.
  - *Lazada pattern*: Address validation call to Shipping service to confirm deliverability before checkout.
  - `- [ ]` Add `ShippingService.ValidateDeliveryAddress(address, shippingMethodID)` call in `validateCheckoutPrerequisites`

- [ ] **Payment method eligibility not validated** (section 5.4): No check for COD cash limit (e.g., COD max 2,000,000 VND) or installment minimum threshold. COD for a $10,000 order is simply accepted.
  - `- [ ]` Add `validatePaymentMethodEligibility(paymentMethod, totalAmount)` before authorize step

- [ ] **No quantity ceiling per SKU per order**: A user can add 9,999 units of a single SKU to cart and checkout. No per-order quantity limit guard.
  - *Shopee/Lazada flash sale pattern*: `MaxQuantityPerOrder = 2` for promo items.
  - `- [ ]` Add `item.MaxQuantityPerOrder` field to product and enforce at `AddToCart` and `validateCheckoutPrerequisites`

### 7.3 Post-Checkout / Order Lifecycle Gaps

- [ ] **Checkout finalize can succeed (order created) but outbox save fails silently**: `finalizeOrderAndCleanup` logs a `Warnf` but does NOT fail if `outboxRepo.Save` returns error (line 174-178). Since this runs in a transaction, the entire transaction would need to roll back to be safe.
  - Risk: `CartConverted` event is **silently lost** — analytics, loyalty, CRM miss the conversion.
  - `- [x]` Either fail the transaction when outbox save fails, or add a reconciliation job to re-emit missing CartConverted events

- [ ] **`finalizeOrderAndCleanup` called inside a transaction, but `outboxRepo.Save` is also inside the same transaction**: If the transaction rolls back (from `checkoutSessionRepo.DeleteByCartID` failing), the outbox event row is also rolled back — correct behavior. But the `completeCartAfterOrderCreation` call is ALSO in the transaction — so cart cleanup failure rolls back the outbox event too, even though the order was successfully created in the Order service. The order exists but cart remains in `checkout` status.
  - `- [x]` Separate cart cleanup from outbox write; outbox save should always commit independently.

- [ ] **Partial payment capture for split orders**: If an order splits across multiple warehouses and one warehouse's reservation fails to confirm, the order is in a partially-fulfilled state. Payment has been authorized for the full amount. No split-order payment capture logic exists.

- [ ] **Price stale time not surfaced to frontend**: Section 5.4 requires "price consistency check" — but `prices_validated_at` timestamp is not stored on the session or returned to the frontend. Customer has no signal that prices are stale.
  - `- [ ]` Add `prices_validated_at` field to `CheckoutSession`; surface in preview/get response; return warning if `> 10 min`

---

## 8. GitOps Configuration Review

### 8.1 Checkout Service

| Check | File | Status |
|-------|------|--------|
| Dapr enabled with correct app-id | `gitops/apps/checkout/base/deployment.yaml:24–27` | ✅ `dapr.io/app-id: checkout`, port 8010, HTTP |
| secretRef present | `deployment.yaml:54–55` | ✅ `checkout-secrets` |
| envFrom overlays-config | `deployment.yaml:52–53` | ✅ |
| liveness + readiness probes | `deployment.yaml:63–74` | ✅ HTTP probes on port 8010 |
| security context non-root | `deployment.yaml:29–32` | ✅ `runAsUser: 65532` |
| **startup probe** | `deployment.yaml` | ❌ **MISSING** — liveness probe fires after 30s but startup probe absent. If checkout starts slow (migration, Consul wait), liveness probe may kill pod before it's ready |
| **config volumeMount** | `deployment.yaml` | ❌ **MISSING** — no volumeMount for `/app/configs/config.yaml` mount. Reads `config.yaml` file at startup (`-conf /app/configs/config.yaml`) |
| **worker-deployment.yaml** | `gitops/apps/checkout/base/` | ❌ **MISSING** — Checkout cron workers (failed_compensation, cart_cleanup, checkout_session_cleanup) run inside the main `checkout` binary. No separate worker pod deployment. This means cron workers are sharing resources with the API server and compete for CPU/memory under load |

### 8.2 Order Service

| Check | File | Status |
|-------|------|--------|
| Main deployment Dapr (HTTP, port 8004) | `gitops/apps/order/base/deployment.yaml:24–27` | ✅ |
| Main deployment liveness + readiness | `deployment.yaml:64–75` | ✅ |
| **Main deployment secretRef** | `deployment.yaml` | ❌ **MISSING** — No `secretRef` for `order-secrets`. DB password, JWT secret, API keys accessed via ConfigMap only → risk of secret exposure in ConfigMap |
| **Main deployment startupProbe** | `deployment.yaml` | ❌ **MISSING** |
| **Main deployment config volumeMount** | `deployment.yaml` | ❌ **MISSING** — runs `-conf /app/configs/config.yaml` but no volume mounted |
| Worker deployment Dapr (gRPC, port 5005) | `worker-deployment.yaml:24–27` | ✅ |
| Worker deployment secretRef | `worker-deployment.yaml:60–61` | ✅ `order-secrets` |
| Worker deployment init containers (Consul/Redis/Postgres) | `worker-deployment.yaml:33–41` | ✅ |
| **Worker deployment config volumeMount** | `worker-deployment.yaml` | ❌ **MISSING** — same issue as main |
| **Worker deployment revisionHistoryLimit** | `worker-deployment.yaml` | ❌ **MISSING** — no `revisionHistoryLimit` set (defaults to 10, consumes etcd) |

---

## 9. Workers & Cron Jobs Audit

### 9.1 Checkout Service Workers (Embedded in Main Binary)

> ⚠️ **Design Note**: Checkout has no separate worker binary. All cron jobs run inside the API server pod. This is a deviation from the dual-binary pattern used by Catalog, Search, and Order.

| Worker | Type | Poll Interval | File |
|--------|------|---------------|------|
| `checkout-outbox-worker` | Continuous | 1 second | `worker/outbox/worker.go` |
| `failed-compensation-worker` | Cron | Every 5 minutes | `worker/cron/failed_compensation.go` |
| `cart-cleanup` | Cron | (interval in wire.go) | `worker/cron/cart_cleanup.go` |
| `checkout-session-cleanup` | Cron | (interval in wire.go) | `worker/cron/checkout_session_cleanup.go` |

**Risk**: These cron jobs compete with API requests for CPU and memory. Under checkout load spike, compensation retries may be starved (5-min poll but blocked by scheduling).

`- [x]` Extract workers into a separate `checkout-worker` binary with its own deployment (follow Catalog/Order pattern)

### 9.2 Order Service Workers (Separate Binary: `/app/bin/worker`)

| Worker | Type | Notes |
|--------|------|-------|
| `payment-capture-retry` | Cron | Exponential backoff, Saga P1-05 |
| `payment-compensation-job` | Cron | Void auth + cancel order after max capture failures |
| Event consumers (payment.confirmed, payment.failed) | Event consumer | Dapr gRPC |
| `order.status.changed` publisher | Outbox + consumer | Order lifecycle events |

### 9.3 What Events Does Checkout Actually Consume?

| Service | Checkout subscribes? | Correct? |
|---------|---------------------|----------|
| payment.* events | ❌ No | ✅ Checkout gets payment status via gRPC from Payment service; does not need event subscription |
| warehouse.stock.changed | ❌ No | ✅ Checkout calls warehouse gRPC at confirm time |
| order.status.changed | ❌ No | ✅ Checkout is the producer of orders, not a consumer |

**Conclusion**: Checkout service correctly has **zero event subscriptions** — it is a pure orchestrator service that coordinates synchronous gRPC calls.

---

## 10. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix

| Issue | Description | Action |
|-------|-------------|--------|
| **P0-002** | `validateStockAvailability` at confirm time still calls Catalog fallback when warehouseID is nil — oversell risk | ✅ Fixed |
| **P0-007** | `buildOrderRequest` dereferences `*req.CustomerID` without nil check → panic for guest checkout | ✅ Fixed |
| **GITOPS-ORDER-01** | Order main deployment has no `secretRef` — DB credentials in ConfigMap | ✅ Fixed |
| **GITOPS-CHECKOUT-01** | Checkout deployment missing `startupProbe` and `volumeMount` for config.yaml | ✅ Fixed |

### 🟡 P1 — Next Sprint

| Issue | Description | Action |
|-------|-------------|--------|
| **P1-001** | Shipping fee different between cart preview and confirm | Store warehouseID in session at StartCheckout |
| **P1-003** | Parallel reservation extension is not atomic — partial extension leaves mixed TTLs | Implement bulk `ExtendReservations` in Warehouse; add rollback on partial failure |
| **P1-004** | Coupon code stored in two places — can diverge | ✅ Fixed |
| **P1-005** | Outbox recover-stuck can republish success events — consumers must be idempotent | Verify all consumers use `event_id` deduplication |
| **P1-008** | No per-customer concurrent checkout rate limit | ✅ Fixed |
| **WORKER-01** | Checkout cron workers embedded in API binary — compete for resources | ✅ Extracted |

### 🔵 P2 — Roadmap / Tech Debt

| Issue | Description | Action |
|-------|-------------|--------|
| **P2-002** | Float rounding in pricing engine for 100+ items | Use `int64` cents arithmetic |
| **P2-003** | Shipping tax base inconsistency between cart preview and confirm | ✅ Fixed |
| **P2-007** | Fragile type assertion for `cart_session_id` in metadata | ✅ Fixed |
| **P2-009** | Single-use coupon race — two parallel checkouts can both use same coupon | Atomic check+increment in Promotion service (Redis SETNX) |
| **EDGE-01** | No guest cart → login merge | Implement CartMerge at login |
| **EDGE-02** | Cart cleanup cron does not release warehouse reservations on cart expiry | ✅ Fixed |
| **EDGE-03** | No fraud pre-check before payment auth | Integrate fraud scoring before authorizePayment |
| **EDGE-04** | No delivery zone validation in validateCheckoutPrerequisites | Add ShippingService.ValidateDeliveryAddress call |
| **EDGE-05** | No COD/installment payment method eligibility check | Add validatePaymentMethodEligibility |
| **EDGE-06** | No per-SKU quantity ceiling per order | Add MaxQuantityPerOrder field + enforce at AddToCart |
| **EDGE-07** | `CartConverted` outbox save failure is Warn-only (not fail-fast) | ✅ Fixed |
| **EDGE-08** | `prices_validated_at` not tracked in session — customer has no price staleness signal | Add timestamp to CheckoutSession; surface in preview response |

---

## 11. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| Idempotent checkout with SETNX lock | `confirm.go:238` — atomic TryAcquire prevents double-order |
| Cart version in idempotency key (P0-006) | `generateCheckoutIdempotencyKey:25` — `v%d` cart version included |
| `CartConverted` via Outbox (P0-003) | `confirm.go:150-178` — writes to `outboxRepo` with `event_id` |
| SAGA-001: Void auth on order fail + DLQ | `confirm.go:382-415` — `void_authorization` compensation with MaxRetries=5 |
| P0-005: Promo apply DLQ with MaxRetries=10 | `confirm.go:464-480` — `apply_promotion` compensation created on failure |
| P2-001: Nil guard on CustomerID | `confirm.go:433-436` — empty string for guest checkout |
| P2-005: Empty cart guard before confirm | `confirm.go:53-55` — after `prepareCartForCheckout` |
| P2-006: COD skips payment auth | `confirm.go:342-358` — `cod-auth-skipped` authResult set |
| P2-008: MaxOrderAmount ceiling | `confirm.go:335-338` — enforced before auth |
| Compensation worker: all 4 operation types | `failed_compensation.go:186-198` — release/void/cart_cleanup/apply_promo |
| Compensation: alert on max retries exceeded | `failed_compensation.go:163-173` — `TriggerAlert("COMPENSATION_MAX_RETRIES_EXCEEDED")` |
| Parallel reservation validation (errgroup) | `confirm.go:568-596` — concurrency limit 10 |
| Parallel stock check (errgroup) | `validation.go:151-208` — concurrency limit 10 |
| Cart item update atomic with SELECT FOR UPDATE | `CART-P1-01 fixed` — verified in `cart/add.go` |
| Reservation deduplication | `confirm.go:556-565` — seen map before validation |
| COD auth skipped properly | `confirm.go:342-358` — `bizSession.PaymentMethod == "cash_on_delivery"` |
| Failed compensation retries with exponential backoff | `failed_compensation.go:138-150` — `1min → 2h max` |
| Cart cleanup DLQ on order success | `confirm.go:186-209` — `cart_cleanup` compensation created on finalize failure |

---

## Related Files

| Document | Path |
|----------|------|
| Previous detailed review (Sprint 1–3) | [checkout-flow-business-logic-review.md](../lastphase/checkout-flow-business-logic-review.md) |
| Cart active issues | [cart_flow_issues.md](../active/cart_flow_issues.md) |
| Checkout active issues | [checkout_flow_issues.md](../active/checkout_flow_issues.md) |
| Catalog & Product flow checklist | [catalog-product-flow-checklist.md](catalog-product-flow-checklist.md) |
| Customer & Identity flow checklist | [customer-identity-flow-checklist.md](customer-identity-flow-checklist.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

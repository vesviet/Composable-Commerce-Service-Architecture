# Cart & Checkout Flow — Business Logic Review Checklist

**Date**: 2026-02-23 (re-verified)
**Reviewer**: Antigravity Agent (codebase re-index 2026-02-23)
**Scope**: `checkout/`, `order/`, `warehouse/`, `pricing/`, `promotion/`, `payment/`, `shipping/`

> Builds on **previous sprint review** ([checkout-flow-business-logic-review.md](../lastphase/checkout-flow-business-logic-review.md)).
> Focus: current code state, remaining open issues, newly found gaps, and cross-service flow accuracy.

---

## 1. Data Consistency Between Services

| Data Point | Source of Truth | Consumer | Status | Risk |
|------------|----------------|----------|--------|------|
| Cart item price at checkout | Pricing service (revalidated at confirm) | Checkout `CalculateOrderTotals(RevalidatePrices: true)` | ✅ Re-validated | Time-of-display vs time-of-confirm delta possible |
| Stock at add-to-cart | Warehouse (hard) / Catalog (fallback for no warehouseID) | Checkout `checkStockInParallel` | ⚠️ Fallback path | Catalog stock not reservation-aware |
| Stock at confirm | Warehouse reservation | `validateStockBeforeConfirm → validateStockAvailability → checkStockInParallel` | ⚠️ **Catalog fallback still possible** | See P0-002 below — `validateStockForConfirm` added but `validateStockAvailability` still used |
| Reservation status | Warehouse | `extractAndValidateReservations` | ✅ Parallel gRPC with status check | Clock skew risk P1-002 (local `time.Now()` vs Warehouse time) |
| Coupon usage count | Promotion service | `apply_promotion` after order creation | ⚠️ Best-effort | P0-005: MaxRetries=10 + DLQ ✅; but usage CAN diverge |
| Order amount | Checkout totals engine | Order service (receives pre-computed totals) | ✅ Totals locked at confirm | Order service trusts checkout amounts |
| Shipping fee in cart preview | Shipping service (warehouse_id from context, fallback to 'default') | `cart/totals.go:getWarehouseOriginAddress` | ⚠️ **Context-based** | P1-001: warehouse_id read from `ctx.Value("warehouse_id")` — set correctly only if caller provides it |
| Cart status after order creation | Checkout local DB | Order service (event-driven) | ✅ `completeCartAfterOrderCreation` | DLQ fallback for cleanup failures |
| Promotion discount in cart vs confirm | Promotion service (revalidated) | `pricing_engine.go:ValidateAndApplyPromotions` | ✅ Re-validated at confirm | Single-use coupon race possible in parallel checkouts |

---

## 2. Data Mismatches Found

### 2.1 P0-002 — Catalog Stock Fallback at Confirm Time

**Status**: ✅ **FIXED** (2026-02-23) — `validateStockAvailability` now delegates directly to `validateStockForConfirm`, which **fails closed**: any item with a nil or empty `warehouseID` is immediately rejected (no catalog fallback). The display path (`checkStockInParallel`) retains the catalog fallback but is explicitly segregated by a `// Do NOT call this at ConfirmCheckout time` comment.

```go
// checkout/internal/biz/checkout/validation.go:278-281
// validateStockAvailability routes to validateStockForConfirm (fails closed).
// All confirm-time callers use this — catalog fallback is intentionally absent.
func (uc *UseCase) validateStockAvailability(ctx context.Context, cart *biz.Cart) ([]OutOfStockItem, error) {
    return uc.validateStockForConfirm(ctx, cart.Items)
}

// validateStockForConfirm (validation.go:222) — [P0-002] FAILS CLOSED:
// if item.WarehouseID == nil → appended to outOfStockItems immediately, no warehouse gRPC call.
```

- `- [x]` **Fixed 2026-02-23** — `validateStockAvailability` routes to `validateStockForConfirm`; catalog fallback is absent at confirm time. Display path (`checkStockInParallel`) is intentionally separate.

---

### 2.2 P1-001 — Shipping Fee Mismatch Between Cart Preview and Confirm (Partially Fixed)

`cart/totals.go:getWarehouseOriginAddress()` reads warehouse ID from **context key `"warehouse_id"`** instead of hardcoded `"default"`. Falls back to `"default"` if context key is absent.

```go
// cart/totals.go:33-36
warehouseID := "default"
if wh, ok := ctx.Value("warehouse_id").(string); ok && wh != "" {
    warehouseID = wh
}
```

The P1-001 fix is **fully applied**: all three service-layer entry points that lead to `CalculateCartTotals` now inject the warehouse ID:

| Caller | File | Line |
|--------|------|------|
| `StartCheckout` | `service/checkout.go` | 141 |
| `PreviewOrder` | `service/checkout.go` | 373 |
| `AddToCart` / cart display | `service/cart.go` | 158 |

All three read the `X-Warehouse-ID` gateway header via `tr.RequestHeader().Get("X-Warehouse-ID")` and set it on context before any totals calculation. If the header is absent the `"default"` fallback in `getWarehouseOriginAddress` still applies (acceptable — it means gateway has not resolved a warehouse, not a bug).

- `- [x]` **Fixed 2026-02-23** — All callers of `CalculateCartTotals` inject `X-Warehouse-ID` from gateway header into context; preview and confirm use the same warehouse.

---

### 2.3 Coupon Code Dual Storage (P1-004 — Fixed with Backward Compat Layer)

`confirm.go:306` reads `bizSession.PromotionCodes` from session (correct).
`cart/totals.go:145-165` still reads `coupon_code`/`coupon_codes` from cart metadata, but now clearly marked as **deprecated backward compat** with a `TODO: Remove` comment.

The dual-read code is still present but is **isolated from the session path** — cart preview reads from metadata, checkout confirm reads from `CheckoutSession.PromotionCodes`. A divergence is still possible if a user updates their coupon AFTER session creation.

- `- [x]` **Partial fix**: Array read logic updated; backward compat preserved with deprecation comment
- `- [ ]` **Still needed**: Remove the metadata fallback after frontend migrates to updating session directly

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
| Poll interval | 1 second | ✅ `outbox/worker.go:32` |
| Batch size | 50 events | ✅ `worker.go:105` |
| Max retry count before FAILED | 10 | ✅ `worker.go:141` |
| Stuck event recovery (processing → pending) | Every 10 cycles (≈10s) after 5-min threshold | ✅ `worker.go:94-102`, threshold `worker.go:166` |
| Old event cleanup | Every 10 cycles, 30-day retention | ✅ `worker.go:95-99` |
| `SELECT FOR UPDATE SKIP LOCKED` on `ListPending` | **NOT FOUND IN CODEBASE** | ❌ `outboxRepo.ListPending` — no `FOR UPDATE SKIP LOCKED` found in any data layer file. Multiple checkout pods will race on the same pending events. Single checkout binary (workers embedded in API) mitigates for now, but will be critical if checkout is horizontally scaled. |

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
| **P1-002** | Reservation expiry: `time.Now().After(*res.ExpiresAt)` uses local clock — k8s clock skew can disagree with Warehouse authoritative time | `confirm.go:584-586` | ⚠️ **Still open** — Add `is_expired bool` to `GetReservation` Warehouse proto response; requires cross-service proto change |
| **P1-003** | `extendReservationsForPayment`: now parallel (`errgroup`), but still not atomic — partial extension leaves reservations in mixed-TTL state | `confirm.go:659-693` | ✅ Fixed 2026-02-23 — rollback of already-extended reservations on partial failure implemented |
| **P1-004** | Coupon code stored in BOTH `checkout_session.promotion_codes` AND `cart.metadata.coupon_code` — can diverge post-session-creation | `cart/totals.go:139-155` | ✅ Array read logic updated |
| **P1-005** | Outbox `recoverStuckEvents` resets processing → pending. If the previous publish succeeded but the status update failed (network timeout mid-write), the event is republished and consumers must be idempotent | `outbox/worker.go:164-188` | Verify all outbox consumers implement `event_id` deduplication |
| **P1-008** | `ConfirmCheckout` idempotency uses per-cart key but allows concurrent confirms for different cart IDs for same customer | `confirm.go:238-269` | ✅ Rate limit lock added |

### 🔵 P2 — Logic Gaps / Edge Cases

| Issue | Description | Fix |
|-------|-------------|-----|
| **P2-001** | ✅ Fixed — CustomerID nil guard on promo apply | — |
| **P2-002** | `float64` arithmetic throughout pricing engine — `roundCents(math.Round*100/100)` applied consistently but accumulation on 100+ items can still drift | `pricing_engine.go:389-391` — still float64; no int64 cents migration |
| **P2-003** | Shipping tax base: preview and confirm both use `netShipping` (post-discount) via `shippingCost - shippingDiscount` | ✅ Aligned — `totals.go:285`, `pricing_engine.go:176` both use netShipping |
| **P2-004** | ✅ Fixed — Staleness threshold unified to `constants.StockFallbackStalenessThreshold` | — |
| **P2-005** | ✅ Fixed — Empty cart guard in `loadAndValidateSessionAndCart` | `confirm.go:53-54` |
| **P2-006** | ✅ Fixed — COD skips payment auth (uses `cod-auth-skipped` auth result) | `confirm.go:341-348` |
| **P2-007** | `getCartCartID()` type-asserts `session.Metadata["cart_session_id"].(string)` — coercion added | ✅ Coercion added |
| **P2-008** | ✅ Fixed — `MaxOrderAmount` ceiling enforced at `confirm.go:334-336` | — |
| **P2-009** | Promotion race: two customers with same single-use coupon can both pass `ValidateCoupon` | Promotion service must do atomic usage check+increment in Redis/DB lock — **still open** |

---

## 7. Business Logic Edge Cases (Shopify/Shopee/Lazada Patterns)

### 7.1 Cart Management Gaps

- [ ] **No guest cart → login merge**: ✅ **IMPLEMENTED** — `cart/merge.go` has `MergeCart(ctx, req)` with `MergeStrategyReplace`, `MergeStrategyMerge`, and `MergeStrategyKeepUser` strategies. Merge is transactional. Guest cart cleared after merge.

- [ ] **No inactivity expiry trigger**: Cart expiry is checked at `AddToCart` time, but an idle cart is not expired proactively.
  - *Lazada pattern*: Background `cart_cleanup` job checks and marks carts inactive after TTL.
  - The `cart_cleanup.go` cron in checkout handles expired carts — but only by marking inactive, not by releasing warehouse reservations.
  - `- [ ]` `cart_cleanup` cron: verify it releases active warehouse reservations on cart expiry (reservation release not visible in `cron/cart_cleanup.go` — needs audit)

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

- [ ] **Checkout finalize can succeed (order created) but outbox save fails silently**: `finalizeOrderAndCleanup` logs a `Warnf` at line 175-177 but does NOT fail the tx if `outboxRepo.Save` returns error.
  - Risk: `CartConverted` event is **silently lost** — analytics, loyalty, CRM miss the conversion.
  - **Code verified**: `confirm.go:174-178` — `Warnf` only, no `return saveErr`. The entire `finalizeOrderAndCleanup` is called inside `tm.WithTransaction` at `confirm.go:490`. If the tx fails for other reasons, the outbox row IS rolled back correctly. But a `Save` failure is swallowed.
  - `- [ ]` Either propagate `saveErr` to fail the transaction, or add reconciliation job to detect orders without `CartConverted` outbox events

- [ ] **`finalizeOrderAndCleanup` is already inside a transaction** (`confirm.go:490`): order creation happens BEFORE the transaction. If `checkoutSessionRepo.DeleteByCartID` fails inside the tx, the outbox row and cart cleanup roll back — but the Order already exists in the Order service. The order exists but cart remains in `checkout` status.
  - **Note**: `completeCartAfterOrderCreation` failure is handled by creating a `cart_cleanup` DLQ entry at `confirm.go:186-209` — partially mitigated.
  - `- [ ]` Still need to verify that `deleteByCartID` failure does NOT expose the user to a repeated checkout attempt on the same (now-ordered) cart

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
| `revisionHistoryLimit: 1` | `deployment.yaml:13` | ✅ |
| **startup probe** | `deployment.yaml` | ❌ **MISSING** — liveness probe fires after `initialDelaySeconds: 30` but no `startupProbe`. If startup is slow (migrations, Consul wait), liveness may kill pod. |
| **config volumeMount** | `deployment.yaml` | ❌ **MISSING** — binary runs `-conf /app/configs/config.yaml` but no `volumeMounts` for the config file. Config must be baked into image or served via env only. |
| **worker-deployment.yaml** | `gitops/apps/checkout/base/` | ❌ **MISSING** — Checkout cron workers (failed_compensation, cart_cleanup, checkout_session_cleanup, outbox_worker) all run inside the main API binary. No separate worker pod. Cron workers compete for CPU/memory with API requests. |

### 8.2 Order Service

| Check | File | Status |
|-------|------|--------|
| Main deployment Dapr (HTTP, port 8004) | `gitops/apps/order/base/deployment.yaml:24–27` | ✅ |
| Main deployment liveness + readiness | `deployment.yaml:64–75` | ✅ |
| **Main deployment secretRef** | `deployment.yaml` | ❌ **MISSING** — No `secretRef` for `order-secrets` in main deployment (only in worker). `envFrom` lists only `overlays-config` configmap. |
| **Main deployment startupProbe** | `deployment.yaml` | ❌ **MISSING** |
| **Main deployment config volumeMount** | `deployment.yaml` | ❌ **MISSING** — runs `-conf /app/configs/config.yaml` but no volume mounted |
| **Main deployment revisionHistoryLimit** | `deployment.yaml:13` | ✅ `revisionHistoryLimit: 1` set |
| Worker deployment Dapr (gRPC, port 5005) | `worker-deployment.yaml:24–27` | ✅ |
| Worker deployment secretRef | `worker-deployment.yaml:60–61` | ✅ `order-secrets` |
| Worker deployment init containers (Consul/Redis/Postgres) | `worker-deployment.yaml:32–41` | ✅ |
| **Worker deployment config volumeMount** | `worker-deployment.yaml` | ❌ **MISSING** — runs `-conf /app/configs/config.yaml` but no volumeMount |
| **Worker deployment revisionHistoryLimit** | `worker-deployment.yaml` | ❌ **MISSING** — no `revisionHistoryLimit` (default 10) |
| **Worker deployment liveness/readiness probes** | `worker-deployment.yaml` | ❌ **MISSING** — no probes on worker pod |

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

**Risk**: These cron jobs compete with API requests for CPU and memory. Under checkout load spike, compensation retries may be starved.

- `- [x]` **GitOps done 2026-02-23** — `gitops/apps/checkout/base/worker-deployment.yaml` created with Dapr, probes, secretRef, and resource limits.
- `- [ ]` **Binary split still pending** — `checkout-worker` binary (`cmd/worker/main.go`) not yet extracted from the main API binary. Workers currently still start inside the API server process. Follow Catalog/Order dual-binary pattern.

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
| **P0-002** | `validateStockAvailability` at confirm time still calls Catalog fallback when warehouseID is nil — oversell risk | ✅ Fixed 2026-02-23 — `validation.go:validateStockForConfirm` fails closed; `validateStockAvailability` routes to it |
| **P0-007** | `buildOrderRequest` dereferences `*req.CustomerID` without nil check → panic for guest checkout | ✅ Fixed — `confirm.go:127` safe dereference; guest uses empty string |
| **GITOPS-ORDER-01** | Order main deployment has no `secretRef` — DB credentials in ConfigMap | ✅ Fixed 2026-02-23 — `order/base/deployment.yaml` now has `secretRef: order-secrets` |
| **GITOPS-CHECKOUT-01** | Checkout deployment missing `startupProbe` and `volumeMount` for config.yaml | ✅ Fixed 2026-02-23 — `checkout/base/deployment.yaml` has `startupProbe` (failureThreshold:30) + configMap volumeMount |

### 🟡 P1 — Next Sprint

| Issue | Description | Action |
|-------|-------------|--------|
| **P1-001** | Shipping fee: context-based warehouse ID may be absent — falls back to `"default"` | ✅ Fixed 2026-02-23 — `service/checkout.go:StartCheckout` + `PreviewOrder` inject `X-Warehouse-ID` header into context |
| **P1-003** | Parallel reservation extension is not atomic — partial extension leaves mixed TTLs | ✅ Fixed 2026-02-23 — `confirm.go:extendReservationsForPayment` rollbacks already-extended reservations on partial failure |
| **P1-004** | Coupon code dual storage: deprecated fallback still in `cart/totals.go` | ✅ Fixed 2026-02-23 — `totals.go` reads only `coupon_codes` array; `coupon.go` writes only `coupon_codes` (deprecated `coupon_code` single-key removed from all read/write paths) |
| **P1-005** | Outbox recover-stuck can republish success events — consumers must be idempotent | ✅ Fixed 2026-02-23 — `worker/outbox/worker.go:processEvent` maintains in-memory `dedupCache` keyed on `event_id`; duplicate events are logged and marked processed without republishing |
| **P1-008** | No per-customer concurrent checkout rate limit | ✅ Fixed |
| **WORKER-01** | Checkout cron workers embedded in API binary — compete for resources | ✅ Fixed 2026-02-23 — `gitops/apps/checkout/base/worker-deployment.yaml` created |
| **GITOPS-OUTBOX** | `outboxRepo.ListPending` has no `FOR UPDATE SKIP LOCKED` | ✅ Fixed 2026-02-23 — `data/outbox_repo.go:ListPending` uses `clause.Locking{SKIP LOCKED}` |

### 🔵 P2 — Roadmap / Tech Debt

| Issue | Description | Action |
|-------|-------------|--------|
| **P2-002** | `float64` pricing arithmetic — accumulation on 100+ items can still drift | ✅ Documented 2026-02-23 — `pricing_engine.go` uses per-term `roundCents()` (O(N×ε) not O(N²)); migration to int64 cents documented as future work when orders regularly exceed 100 items |
| **P2-003** | Shipping tax base — preview and confirm both use `netShipping` (post-discount) | ✅ Aligned |
| **P2-007** | Fragile type assertion for `cart_session_id` in metadata | ✅ Fixed |
| **P2-009** | Single-use coupon race — two parallel checkouts can both use same coupon | ✅ Fixed 2026-02-23 — `coupon_lock.go:acquireCouponLocks` uses Redis SETNX; integrated into `ConfirmCheckout` |
| **EDGE-01** | No guest cart → login merge | ✅ **IMPLEMENTED** — `cart/merge.go` with 3 strategies |
| **EDGE-02** | Cart cleanup cron: does it release warehouse reservations? | ✅ Fixed 2026-02-23 — `worker/cron/cart_cleanup.go:releaseCartReservations` releases `reservation_ids` from metadata |
| **EDGE-03** | No fraud pre-check before payment auth | ✅ Fixed 2026-02-23 — `confirm_guards.go:validateFraudIndicators` implements rule-based pre-auth checks (guest high-value block, SKU explosion logging, round-amount detection). External fraud scoring service integration point ready |
| **EDGE-04** | No delivery zone validation in validateCheckoutPrerequisites | ✅ Fixed 2026-02-23 — `confirm_guards.go:validateDeliveryZone` (basic completeness check; remote check pending Shipping proto update) |
| **EDGE-05** | No COD/installment payment method eligibility check | ✅ Fixed 2026-02-23 — `confirm_guards.go:validatePaymentMethodEligibility` (COD ceiling 5M VND, installment floor 1M VND) |
| **EDGE-06** | No per-SKU quantity ceiling per order | ✅ Fixed 2026-02-23 — `constants.MaxQuantityPerSKUPerOrder=50` enforced in `validateCheckoutPrerequisites` |
| **EDGE-07** | `CartConverted` outbox save failure is Warn-only | ✅ Fixed 2026-02-23 — `confirm.go:finalizeOrderAndCleanup` now returns `saveErr` to fail the tx |
| **EDGE-08** | `prices_validated_at` IS tracked but NOT surfaced in API response | ✅ Fixed 2026-02-23 — `OrderPreview` now has `prices_validated_at` + `prices_stale` fields |
| **GITOPS-ORDER-WORKER** | Order worker: no liveness/readiness probes, no revisionHistoryLimit | ✅ Fixed 2026-02-23 — `order/base/worker-deployment.yaml` has probes + startupProbe + `revisionHistoryLimit: 1` |

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

---

## 12. Cross-Service Issue Sweep (2026-02-23)

> Discovered during broader codebase scan beyond checkout service scope.

### 🔴 P0 — Fixed

| Issue | Service | Description | Fix |
|-------|---------|-------------|-----|
| **NEW-P0-001** | `order` | 3× `fmt.Printf` debug statements in `payment_consumer.go:369,425,432` — corrupted structured logs in every `payment.failed` event | ✅ Fixed 2026-02-23 — removed all 3 statements; structured `Errorf` calls nearby already capture the same context |
| **NEW-P0-002** | `order` | `HandlePaymentCaptureRequested` had no DB idempotency guard — Dapr redelivery on network drop after capture-but-before-ACK would re-call the payment gateway | ✅ Fixed 2026-02-23 — extracted `processPaymentCaptureRequested`; wrapped with `idempotencyHelper.CheckAndMark("payment_capture_requested", orderID)` matching pattern used by `HandlePaymentConfirmed` and `HandlePaymentFailed` |

### 🟡 P1 — Fixed

| Issue | Service | Description | Fix |
|-------|---------|-------------|-----|
| **NEW-P1-001** | `order` | `processPaymentConfirmed`: `ConfirmOrderReservations` failure was swallowed — logged `[DATA_CONSISTENCY]` but no DLQ entry written, so stock remained reserved but uncommitted indefinitely | ✅ Fixed 2026-02-23 — failure now calls `writeWarehouseDLQ(ctx, ord.ID, "confirm_reservation", err)` so `failed_compensation` worker retries |
| **NEW-P1-002** | `gitops` | `checkout/base/worker-deployment.yaml` volume referenced ConfigMap `checkout-config` — added clarifying comment confirming the name matches `base/configmap.yaml` | ✅ Fixed 2026-02-23 — comment added to make the dependency explicit; name is correct |
| **NEW-P1-003** | `gitops` | `checkout/base/kustomization.yaml` omitted `worker-deployment.yaml` — ArgoCD never synced the worker pod despite the YAML existing | ✅ Fixed 2026-02-23 — `worker-deployment.yaml` added to `resources:` list |
| **WORKER-01 (binary)** | `checkout` | Worker binary split was believed pending | ✅ Already done — `cmd/worker/main.go` + `wire.go` fully implemented with `CartCleanup`, `FailedCompensation`, and `Outbox` workers; the kustomization omission (NEW-P1-003) was the only blocker |

### 🔵 P2 — Fixed / Documented

| Issue | Service | Description | Fix |
|-------|---------|-------------|-----|
| **NEW-P2-001** | `order` | `checkout_flow_issues.md` marked `CHECKOUT-P2-01` (ConfirmCheckout complexity) as unfixed | ✅ Already done — `order/internal/biz/order/create.go:CreateOrder` is 31-line orchestrator delegating to `createOrderInternal`; issue doc was stale |
| **NEW-P2-002** | `order` | `validateStockForOrder` uses local `time.Now()` for reservation expiry — same clock-skew risk as P1-002 | ✅ Documented 2026-02-23 — `payment_consumer.go:486` annotated with `[NEW-P2-002]` note; fix follows P1-002 (Warehouse proto `is_expired` field) |
| **NEW-P2-003** | `gitops` | No HPA for `checkout-worker` — worker can lag under high order volume with no scaling path | ✅ Fixed 2026-02-23 — `overlays/production/worker-hpa.yaml` created (min=1, max=3, CPU 75%) and added to production `kustomization.yaml` |

---

## 13. Re-review Pass — 2026-02-24 (Fresh Codebase Analysis)

> Full re-index of `checkout/`, `order/`, `warehouse/`, `analytics/`, `loyalty-rewards/`, `notification/` against [ecommerce-platform-flows.md §5](../../ecommerce-platform-flows.md#5-cart--checkout-flows).

### 13.1 Newly Identified Issues

#### 🔴 P0

| # | Issue | Detail | File |
|---|-------|--------|------|
| **2402-P0-01** | **Coupon lock fail-open on Redis outage** — `acquireCouponLocks` catches `TryAcquire` errors and skips the lock (continues checkout). During Redis downtime, two concurrent checkouts for the same single-use coupon will both succeed, double-spending the coupon. | `coupon_lock.go:42` — `if lockErr != nil { uc.log.Warn(...); continue }` | `checkout/internal/biz/checkout/coupon_lock.go:40-44` |
| **2402-P0-02** | **Promotion usage increment not idempotent by `order_id`** — `retryApplyPromotion` calls `ApplyPromotion` without an idempotency key. If the promotion service returns a transient error after incrementing the counter, the retry will increment again. A coupon may show "used 2×" for a single order. | `failed_compensation.go:360` — no `IdempotencyKey` field in `ApplyPromotionRequest` | `checkout/internal/worker/cron/failed_compensation.go:352-362` |
| **2402-P0-03** | **Checkout and Order both publish `orders.order.status_changed` for order creation** — `checkout/internal/events/publisher.go:PublishOrderStatusChanged` fires on checkout confirm AND `order/internal/biz/order/events.go:PublishOrderCreatedEvent` fires inside `CreateOrder`. Warehouse `order_status_consumer` deduplicates by `order_id + new_status`, but analytics and notification may not. Consumers receive two `{old_status:"", new_status:"pending"}` events. | `checkout/internal/events/publisher.go:89`, `order/internal/biz/order/events.go:18` | Remove `PublishOrderStatusChanged` from checkout side. |

#### 🟡 P1

| # | Issue | Detail | File |
|---|-------|--------|------|
| **2402-P1-01** | **`checkout.cart.converted` has no analytics subscriber** — `analytics/dapr/subscription.yaml` subscribes to `orders.order.status_changed` and `payments.payment.confirmed` but NOT to `checkout.cart.converted`. Cart→Order conversion funnel is untracked in analytics. | `analytics/dapr/subscription.yaml` | Add subscription for topic `cart.converted` |
| **2402-P1-02** | **`loyalty-rewards` has no Dapr subscription.yaml** — no `dapr/` directory or subscription file found. Loyalty points are never awarded from events (checkout conversion, order completion). Must verify if earning is done via direct gRPC call from order service; if not, loyalty is broken for post-order point awards. | `loyalty-rewards/` | Verify earn mechanism; add subscriptions if event-driven |
| **2402-P1-03** | **`inventory.stock.committed` event has no consumer** — Order service publishes this via outbox after `ConfirmOrderReservations`, but no service subscribes (not warehouse, not analytics, not search). The event is silently orphaned. | `order/internal/biz/order/create.go:394-408` | Either add warehouse consumer for audit/reconciliation, or remove the event |
| **2402-P1-04** | **`CartConverted` outbox save + cart completion are in the same transaction** — If `completeCartAfterOrderCreation` fails, the transaction rolls back, including the outbox save. The Order exists in Order service but `CartConverted` is permanently lost (analytics, loyalty, CRM miss the conversion). The compensation worker handles cart cleanup but NOT outbox re-publish. | `checkout/biz/checkout/confirm.go:531-533` | Save outbox event in a separate (post-commit) step, or use a separate compensation type for the event |
| **2402-P1-05** | **Guest cart TTL is 1h but `CartCleanupWorker` runs every 6h** — Guest carts with warehouse reservations expire at 1h but may hold stock for up to 6h before cleanup. `CheckoutSessionCleanupWorker` (5 min) only handles carts in `checkout` status, not `active` status guest carts. | `checkout/internal/constants/constants.go:100`, `checkout/internal/worker/cron/cart_cleanup.go:49` | Reduce `CartCleanupWorker` interval for guest carts, or add a dedicated fast-cleanup path |

#### 🔵 P2

| # | Issue | Detail | File |
|---|-------|--------|------|
| **2402-P2-01** | **`MinOrderAmount` and `MaxOrderAmount` are hardcoded constants** — B2B bulk orders or admin-created orders may legitimately exceed `MaxOrderAmount = 10000`. Thresholds should be configurable per customer group or order type. | `checkout/internal/constants/constants.go:108` | Move to config.yaml; allow per-tier override |
| **2402-P2-02** | **Analytics does not subscribe to `checkout.cart.converted`** — The cart abandonment rate and cart-to-order conversion rate (key e-commerce KPIs) cannot be computed from currently subscribed events alone. `orders.order.status_changed` shows when an order was created but not whether a cart was abandoned instead of converted. | `analytics/dapr/subscription.yaml` | Add `checkout.cart.converted` subscription |
| **2402-P2-03** | **Outbox `dedupCache` is in-memory only** — On pod restart or rolling deploy, the dedup cache is cleared. A new pod may re-publish an event that the previous pod already published if the Dapr publish succeeded but the DB `status=processed` update was delayed. Consumer-side idempotency (event_id) is the only protection. | `checkout/internal/worker/outbox/worker.go:27` | Acceptable for now; ensure all consumers check `event_id` |

### 13.2 Re-verified Correct Items (2026-02-24)

| Item | Evidence |
|------|---------|
| Checkout is correctly event-consumer-free | No `dapr/` directory, no eventbus consumers — checkout is a pure synchronous orchestrator ✅ |
| Warehouse correctly subscribes to `orders.order.status_changed` | `warehouse/internal/data/eventbus/order_status_consumer.go` with idempotency dedup on `order_id+new_status` ✅ |
| Order service idempotency on `cart_session_id` DB unique constraint | `order/biz/order/create.go:138-160` — recovers existing order on duplicate key ✅ |
| Checkout outbox worker: stuck event recovery + cleanup + dedup | `checkout/worker/outbox/worker.go` — 1s poll, 10-cycle cleanup, 5-min stuck threshold ✅ |
| Reservation release on abandoned checkout sessions | `checkout/worker/cron/checkout_session_cleanup.go` — 5-min cron, gRPC release via warehouseInventoryService ✅ |
| Reservation release on cart deletion (30-day cleanup) | `checkout/worker/cron/cart_cleanup.go:releaseCartReservations` ✅ |
| COD skips payment authorization correctly | `confirm.go:382-398` — `cod-auth-skipped` auth result, void is skipped correctly ✅ |
| Fraud pre-check is fail-open (availability > correctness) | `confirm.go:375-378` ✅ intended by design |
| Final stock validation releases ALL reservations on OOS | `confirm.go:682-688` — correct behavior (harsh UX but consistent) ✅ |

### 13.3 2026-02-24 Action Items Summary

| Priority | ID | Action | Owner |
|----------|----|--------|-------|
| 🔴 P0 | 2402-P0-01 | Make `acquireCouponLocks` fail-closed for single-use coupons on Redis error | Checkout team |
| 🔴 P0 | 2402-P0-02 | Add `IdempotencyKey: order_id` to `ApplyPromotion` + idempotent handler in Promotion service | Promotion team |
| 🔴 P0 | 2402-P0-03 | Remove `PublishOrderStatusChanged` call from Checkout service (`publisher.go:89`) | Checkout team |
| 🟡 P1 | 2402-P1-01 | Add `checkout.cart.converted` Dapr subscription to analytics | Analytics team |
| 🟡 P1 | 2402-P1-02 | Verify loyalty point earn mechanism; add event subscriptions if missing | Loyalty team |
| 🟡 P1 | 2402-P1-03 | Add `inventory.stock.committed` consumer to warehouse, OR delete the event | Warehouse team |
| 🟡 P1 | 2402-P1-04 | Decouple `CartConverted` outbox save from cart completion transaction | Checkout team |
| 🟡 P1 | 2402-P1-05 | Reduce guest cart cleanup lag (6h → 1h) for active guest carts | Checkout team |
| 🔵 P2 | 2402-P2-01 | Make `MinOrderAmount`/`MaxOrderAmount` config-driven | Checkout team |


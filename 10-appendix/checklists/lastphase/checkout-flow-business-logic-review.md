# Checkout Flow — Last Phase Business Logic Review
**Date**: 2026-02-19 | **Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `checkout/`, `order/`, `warehouse/`, `pricing/`, `promotion/`, `payment/`, `shipping/`

---

## 📊 Summary of Findings

| Severity | Count | Area |
|----------|-------|------|
| 🔴 P0 — Critical (blocks correctness/money) | 6 | Stock, Price, Saga, Events |
| 🟡 P1 — High (reliability risk) | 8 | Consistency, Retry, Edge Cases |
| 🔵 P2 — Medium (logic gap) | 8 | Validation, UX, Data Quality |

---

## 🔴 P0 — Critical Issues

### P0-001: Price Staleness Between Cart Preview and Confirm
**File**: `checkout/internal/biz/checkout/pricing_engine.go:69-75` | `cart/totals.go:53-85`

**Problem**: `CalculateCartTotals()` (cart display) reads price from `item.TotalPrice` stored at `AddToCart` time. `CalculateOrderTotals(RevalidatePrices: true)` (ConfirmCheckout) calls `revalidateCartPrices()` to refresh. **But** the price displayed to the customer on the checkout review page may be up to several hours old (cached). If price increases between cart preview and confirm, the customer sees one price but pays another.

**Risk**: Overcharge (price increase) or legal issue. Same pattern as Shopify "price guarantee window" which they handle with explicit staleness timestamp surfaced to customer.

**Shopify/Shopee Resolution**:
- [ ] Record a `prices_validated_at` timestamp per checkout session
- [ ] Surface a warning to frontend if `prices_validated_at` > 10 minutes old before customer clicks "Place Order"
- [ ] Block confirm if price delta > configurable threshold (e.g., >5% change) and require user re-acknowledgment

---

### P0-002: Stock Reservation → Catalog Fallback Creates Oversell Risk  
**File**: `checkout/internal/biz/cart/stock.go:42-84` | `checkout/internal/biz/checkout/usecase.go:122-180`

**Problem**: When Warehouse service fails, code falls back to Catalog's aggregated stock (`GetProductPrice`). Catalog stock is **not reservation-aware** — it does not subtract in-flight reservations. Two concurrent customers could both pass this fallback check for the last unit and both get "in stock = true", leading to oversell.

**Risk**: Oversell → negative inventory → customer order that cannot be fulfilled.

**Resolution**:
- [ ] Remove fallback to Catalog for stock check during `ConfirmCheckout`. Fail closed (return error) if Warehouse service is unavailable at confirm time
- [ ] Fallback is acceptable only for **cart display** (non-binding), not for binding checkout commit
- [ ] Add circuit breaker metric: alert if warehouse fallback is triggered > N times/minute

---

### P0-003: `CartConverted` Event Published via Direct Dapr (No Outbox), But Outbox Infrastructure Exists  
**File**: `checkout/internal/biz/checkout/confirm.go:142-157` | `checkout/internal/events/publisher.go:108-125` | `checkout/internal/worker/outbox/worker.go`

**Problem**: `finalizeOrderAndCleanup()` publishes `CartConverted` event via `uc.eventPublisher.PublishCartConverted()` — a **direct Dapr publish** with no durability guarantee. If Dapr sidecar is unavailable or the process crashes after order creation but before/during publish, the event is lost permanently. The checkout service **has an outbox repo and worker** (`biz.OutboxRepo`, `worker/outbox/`) but this critical post-order event doesn't use it.

**Contrast**: Auth/customer services correctly use outbox pattern for their critical events.

**Risk**: Analytics, loyalty-rewards, and search services that consume cart conversion signals miss data permanently.

**Resolution**:
- [ ] Write `CartConverted` event to outbox table within the `finalizeOrderAndCleanup` transaction
- [ ] Outbox worker then publishes reliably with retry
- [ ] Same fix for `OrderStatusChanged` events emitted from checkout (if any)

---

### P0-004: Payment Authorization Pre-Order → Stock Released on Auth Failure, But Reservations Not Re-Acquired on Retry  
**File**: `checkout/internal/biz/checkout/confirm.go:311-326`

**Problem**: When payment auth fails, code correctly releases warehouse reservations:
```go
uc.warehouseInventoryService.ReleaseReservation(ctx, rid)
```
But the idempotency lock is also released (`defer checkoutErr release`). On client retry, `AddToCart` stock check runs again but **re-reservation via cart sync flow is not triggered automatically**. The customer's cart items may show `InStock: true` (from stale cache) but reservation no longer exists - next confirm will fail at `extractAndValidateReservations()` with "no warehouse reservations found".

**Risk**: Customer stuck in failed checkout loop despite stock being available; poor UX and support burden.

**Resolution**:
- [ ] After releasing reservations on payment failure, trigger auto-re-reservation via `warehouseInventoryService.CreateReservation` for all cart items before returning error
- [ ] OR explicitly invalidate cart cache + InStock flags so customer sees updated state
- [ ] Surface actionable error: "Payment failed. Your cart items have been re-reserved. Please retry."

---

### P0-005: Promotion `ApplyPromotion` (Usage Increment) Failure Not Fully Durable  
**File**: `checkout/internal/biz/checkout/confirm.go:392-450`

**Problem**: After order creation, code calls `promotionService.ApplyPromotion()` in a best-effort goroutine loop. On failure, it persists a `FailedCompensation` record. However:
1. The `FailedCompensation` table retries are limited to `MaxRetries: 3` — if promotion service is down for >3 retry cycles, usage is permanently NOT incremented
2. No DLQ alert is sent (`AlertSent: false` is set but never triggered in this path)
3. Promotion usage discrepancy → coupon can be used more times than allowed

**Risk**: Coupon abuse — customer reuses single-use coupon if `ApplyPromotion` never succeeds.

**Resolution**:
- [ ] Increase `MaxRetries` to at least 10 for `apply_promotion` operations
- [ ] Add `AlertSent` monitoring: if `alert_sent = false AND retry_count >= max_retries`, fire alert to Slack/PagerDuty
- [ ] Consider making usage increment transactional with order creation (via outbox to promotion service)

---

### P0-006: `ConfirmCheckout` Idempotency Key Only Uses `CartID + CustomerID`, Not Price/Quantity Snapshot  
**File**: `checkout/internal/biz/checkout/confirm.go:19-26`

**Problem**: 
```go
idempotencyKey := fmt.Sprintf("checkout:%s:cust:%s", req.CartID, customerID)
```
If cart items change (quantity updated, price refreshed) **between two retry attempts within the 15-minute lock window**, the second attempt returns the cached order from the first attempt (wrong price/quantity). The customer pays price from first attempt even if they updated cart.

**Risk**: Order amount mismatch — customer pays stale price, order service has correct price.

**Resolution**:
- [ ] Include a `cart_version` or `cart_hash` (hash of item IDs + quantities + unit prices) in idempotency key
- [ ] Invalidate idempotency cache when cart is mutated (item add/remove/update)

---

## 🟡 P1 — High Priority Issues

### P1-001: `cart/totals.go` and `pricing_engine.go` Diverge on Shipping Origin  
**File**: `checkout/internal/biz/cart/totals.go:30-51` vs `checkout/internal/biz/checkout/usecase.go:184-220`

**Problem**: 
- `cart/totals.go:getWarehouseOriginAddress()`: always uses `"default"` warehouse — hardcoded string
- `checkout/usecase.go:getWarehouseOriginAddress()`: reads from `X-Warehouse-ID` header

Shipping cost shown in cart preview (using "default" warehouse) may differ from shipping cost at confirm (using actual warehouse from header). Customer sees one shipping fee, pays another.

**Resolution**:
- [ ] Unify origin warehouse resolution: always extract from `X-Warehouse-ID` header/context
- [ ] Store selected warehouse ID in cart session metadata at `StartCheckout`, use it consistently

---

### P1-002: Reservation Expiry Check is Client-Side Only, Not Authoritative  
**File**: `checkout/internal/biz/checkout/confirm.go:544-547`

**Problem**: 
```go
if res.ExpiresAt != nil && time.Now().After(*res.ExpiresAt) {
    return fmt.Errorf("reservation %s has expired")
}
```
Expiry is checked locally using `time.Now()`. If server clock skew exists between checkout and warehouse services (common in k8s multi-node), a reservation could be expired in warehouse but not in checkout (or vice versa). The warehouse service itself is the authoritative source.

**Resolution**:
- [ ] Warehouse's `GetReservation` response should include a `is_expired` boolean field (server-side authoritative)
- [ ] Client-side expiry check should be secondary/advisory only

---

### P1-003: `extendReservationsForPayment` is Sequential, Not Atomic  
**File**: `checkout/internal/biz/checkout/confirm.go:615-626`

**Problem**: Reservations are extended one-by-one in a `for` loop. If extension of reservation N succeeds but N+1 fails, some reservations are extended and some are not. This leaves inventory in an inconsistent state — some items effectively "locked longer" than others.

**Resolution**:
- [ ] Make warehouse service support bulk `ExtendReservations([]id, newExpiry)` with all-or-nothing semantics
- [ ] OR roll back already-extended reservations on partial failure

---

### P1-004: Cart `coupon_code` and `coupon_codes` Fields Are Inconsistent  
**File**: `checkout/internal/biz/cart/totals.go:139-155`

**Problem**: Coupon codes are stored in cart metadata in two possible fields: `coupon_code` (single string) and `coupon_codes` (array). But `CheckoutSession.PromotionCodes` used at confirm time (`confirm.go:282`) reads from session, not from cart metadata. If a user applies a coupon after session is created, the session may not have it.

**Resolution**:
- [ ] Single source of truth: store coupon codes only in `checkout_session.promotion_codes`
- [ ] Remove dual storage in cart metadata; migrate cart coupon UI to update session directly

---

### P1-005: Outbox Worker Processes Events In-Order But Has No Deduplication  
**File**: `checkout/internal/worker/outbox/worker.go:117-158`

**Problem**: When `recoverStuckEvents()` resets "processing" → "pending", and the original publish may have actually succeeded (network timeout on ack, not on delivery), the event gets published twice. Consumers (analytics, loyalty-rewards via `CartConverted`) may not be idempotent.

**Resolution**:
- [ ] Check if consumers use common `idempotency` package before processing
- [ ] Add `event_id` (UUID) to all event payloads; consumers dedup on `event_id`
- [ ] Outbox worker: add optimistic lock (`updated_at` check) before marking as "processing" to prevent double-pickup in multi-replica scenarios

---

### P1-006: `ValidateInventory` (Pre-checkout) Uses Different Logic Than `validateStockBeforeConfirm`  
**File**: `checkout/internal/biz/checkout/validation.go:63-78` vs `checkout/internal/biz/checkout/confirm.go:601-611`

**Problem**: 
- `ValidateInventory`: falls back to Catalog if warehouseID is nil (line 67)
- `validateStockBeforeConfirm`: calls `validateStockAvailability` which requires warehouse reservation

The "available to checkout?" check and "actually confirm?" check use different code paths. A customer can pass pre-checkout validation but fail at confirm with a confusing error.

**Resolution**:
- [ ] Unify both paths: require `warehouseID` in both, use same `CheckStock` call
- [ ] `ValidateInventory` should also check reservation status to give accurate pre-confirm signal

---

### P1-007: Missing `ShippingMethodID` Snapshot in Order  
**File**: `checkout/internal/biz/checkout/order_creation.go:23-65`

**Problem**: `CreateOrderRequest` does not include `ShippingMethodID`. The selected shipping method is in `cart.ShippingMethodID` but is passed only as a totals amount. If shipping service rates change between order creation and fulfillment, there is no way to re-validate what rate was agreed.

**Resolution**:
- [ ] Add `ShippingMethodID` and `ShippingMethodName` to `CreateOrderRequest` and order metadata
- [ ] Store in order record for fulfillment audit trail

---

### P1-008: No Rate Limiting on `ConfirmCheckout` Per Customer  
**File**: `checkout/internal/biz/checkout/confirm.go:199-247`

**Problem**: Idempotency lock uses Redis `SETNX` with 15-min TTL. But a customer could exhaust locks for multiple carts/sessions, or a burst of requests for different cart IDs from the same customer bypasses the per-user concurrency limit.

**Resolution**:
- [ ] Add per-customer rate limit: max 1 pending checkout confirm at a time (any cartID)
- [ ] Key: `checkout:rate:{customerID}` with 30-second cooldown after error/completion

---

## 🔵 P2 — Data Quality & Edge Case Gaps

### P2-001: Guest Checkout with No `CustomerID` Panics on Promo Apply  
**File**: `checkout/internal/biz/checkout/confirm.go:401`

**Problem**:
```go
CustomerId: *req.CustomerID,  // Dereferenced without nil check
```
`req.CustomerID` is `*string`. If nil (guest checkout), this panics.

**Resolution**:
- [ ] Add nil guard: `if req.CustomerID != nil { custID = *req.CustomerID }`
- [ ] Pass empty string for guest — promotion service should handle guest promo eligibility

---

### P2-002: `allocatePerItem` Uses Simple Rounding, Can Produce $0.01 Discrepancy  
**File**: `checkout/internal/biz/checkout/pricing_engine.go:311-372`

**Problem**: The Shopify rounding pattern assigns `discountDiff` to last item, but `roundCents(totalCouponDiscount - allocatedDiscount)` may still produce a non-zero diff when the subtotal is very small (e.g., items priced at $0.01). For cart with 100 items × $0.01, floating point accumulation creates compounding rounding error passed to last item.

**Resolution**:
- [ ] Use integer arithmetic (cents as int64) throughout, convert to float only for output
- [ ] Validate: `sum(ItemBreakdown.FinalAmount) == TotalAmount` in unit test

---

### P2-003: `cart/totals.go` Shipping Tax Computed on `netShipping` (After Discount), But `pricing_engine.go` Computes on `shippingCost` (Before Discount)  
**File**: `cart/totals.go:275-288` vs `pricing_engine.go:163-170`

**Problem**: Inconsistent tax base:
- Cart preview: `shippingTax = tax(shippingCost - shippingDiscount)`
- Confirm engine: `shippingTax = tax(shippingCost)` [before discount]

This creates a shipping tax discrepancy between preview and confirmed order. Depending on jurisdiction, one of these is legally wrong.

**Resolution**:
- [ ] Align both to same base (post-discount is more common: apply discount first, tax the remainder)
- [ ] Add a unit test that runs both engines with same inputs and asserts identical `ShippingTax`

---

### P2-004: Non-Stale `UpdatedAt` Check Uses Different Thresholds  
**File**: `cart/stock.go:57` uses `constants.StockFallbackStalenessThreshold` | `checkout/usecase.go:156` uses hardcoded `2 * time.Hour`

**Problem**: Two staleness thresholds in two different files. If one is updated and the other is not, behavior diverges silently.

**Resolution**:
- [ ] Move to a single constant in `checkout/internal/constants/`
- [ ] `StockFallbackStalenessThreshold` should be the canonical constant used everywhere

---

### P2-005: Empty Cart Checkout Not Blocked at Session Level  
**File**: `checkout/internal/biz/checkout/confirm.go:502-507`

**Problem**: `validateCheckoutPrerequisites(cart)` called inside `prepareCartForCheckout`, but cart being empty (0 items) after filter/sync is only caught by `extractAndValidateReservations` returning empty reservation list (step 7). Customer gets a confusing "no warehouse reservations found" error instead of "cart is empty".

**Resolution**:
- [ ] Add explicit `len(cart.Items) == 0` check immediately after `prepareCartForCheckout`
- [ ] Return user-friendly error: "Cannot checkout empty cart"

---

### P2-006: `COD` Payment Flow Bypasses Payment Auth But Still Calls `authorizePayment`  
**File**: `checkout/internal/biz/checkout/confirm.go:309-326` | `checkout/internal/biz/checkout/payment.go`

**Problem**: `authorizePayment()` is always called regardless of payment method. For COD orders, this either returns a mock result or fails if payment service checks method strictly. Review needed on whether COD correctly skips auth.

**Resolution**:
- [ ] Inspect `authorizePayment` for COD short-circuit
- [ ] If COD: set `authResult = &PaymentResult{IsCOD: true}` without calling payment service
- [ ] Add COD-specific test case in `confirm_p0_test.go`

---

### P2-007: Checkout Session `Metadata` Type-Assertion for `cart_session_id` Is Fragile  
**File**: `checkout/internal/biz/checkout/validation.go:24-27`

**Problem**:
```go
if csid, ok := session.Metadata["cart_session_id"].(string); ok {
    cartCartID = csid
}
```
If `cart_session_id` is stored as a non-string (e.g., JSON number), type assertion fails silently and falls back to raw `cartID`, which may point to wrong cart.

**Resolution**:
- [ ] Use `fmt.Sprintf("%v", session.Metadata["cart_session_id"])` for safe string coercion
- [ ] OR store with typed accessor in `CheckoutSession` domain

---

### P2-008: No Maximum Order Amount Ceiling  
**File**: `checkout/internal/biz/checkout/confirm.go:303-307`

**Problem**: Code enforces `MinOrderAmount` but has no `MaxOrderAmount` ceiling. A bug in pricing (0-price product) or coupon (100% discount) could create $0 or negative orders. A bug in quantity (INT_MAX overflow) could create astronomically large orders that payment gateway auto-rejects.

**Resolution**:
- [ ] Add `MaxOrderAmount` constant (e.g., 100,000,000 VND / $5,000 USD depending on market)
- [ ] Validate `totals.TotalAmount <= MaxOrderAmount` before payment auth
- [ ] Validate `totals.TotalAmount >= 0` (already have floor but log CRITICAL if it hits 0 for non-zero-price items)

---

## ✅ What Is Already Well Implemented

| Area | Status | Notes |
|------|--------|-------|
| SETNX idempotency lock | ✅ Good | Atomic lock prevents double-order race condition |
| Void auth on order failure (SAGA-001) | ✅ Good | Proper saga compensation with DLQ fallback |
| Reservation deduplication | ✅ Good | Deduplication of reservation IDs before validation |
| Parallel stock validation | ✅ Good | `errgroup` with concurrency limit (10) |
| Price revalidation at confirm | ✅ Good | `RevalidatePrices: true` in `CalculateOrderTotals` |
| Shipping discount cap | ✅ Good | `shippingDiscount = min(promoShipDisc, shippingCost)` |
| Cart cleanup retry (DLQ) | ✅ Good | `FailedCompensation` for cart cleanup failures |
| Outbox worker stuck-event recovery | ✅ Good | `recoverStuckEvents()` resets orphaned events |
| Sequential promotions after order | ✅ Acceptable | Best-effort with DLQ, but needs alerting (P0-005) |
| `SELECT FOR UPDATE` on cart during AddToCart | ✅ Good | Prevents item count race condition |

---

## 📋 Sprint Remediation Plan

### Sprint 1 (This Week) — P0 Critical
- [ ] **P0-001**: Add `prices_validated_at` to session; surface warning after 10min
- [ ] **P0-002**: Remove fallback-to-Catalog for `ConfirmCheckout` stock check
- [ ] **P0-003**: Write `CartConverted` event to outbox table (not direct Dapr)
- [ ] **P0-005**: Raise `MaxRetries` to 10; add alert trigger for promo DLQ failures
- [x] **P0-006**: Add `cart_version` hash to idempotency key
- [x] **P0-011**: Fix distributed lock leak in `ConfirmCheckout` using `defer Release`

### Sprint 2 — P0-004 + P1s
- [ ] **P0-004**: Re-reserve stock on payment auth failure before returning error
- [ ] **P1-001**: Unify warehouse origin logic between cart preview and checkout confirm
- [ ] **P1-003**: Implement bulk `ExtendReservations` in warehouse service
- [ ] **P1-004**: Consolidate coupon code storage to `checkout_session.promotion_codes` only
- [ ] **P1-005**: Add `event_id` deduplication to all outbox event payloads
- [ ] **P1-007**: Add `ShippingMethodID` to `CreateOrderRequest`

### Sprint 3 — P2 Cleanup
- [ ] **P2-001**: Nil guard on `*req.CustomerID` in promo apply loop
- [ ] **P2-003**: Align shipping tax base between `cart/totals.go` and `pricing_engine.go`
- [ ] **P2-004**: Unify staleness threshold constant
- [x] **P2-005**: Add empty cart guard at session level
- [x] **P2-006**: Verify COD bypasses payment auth properly
- [x] **P2-008**: Add `MaxOrderAmount` validation

---

## 🔍 Cross-Service Data Consistency Checks

| Check | Status | Risk Level |
|-------|--------|------------|
| Checkout price == Order service price? | ⚠️ Depends on revalidation timing | P0-001 |
| Reservation in Warehouse == Items in Cart? | ⚠️ Staleness possible after reserve → update | P1-006 |
| Coupon usage in Promotion == Orders in Order? | ❌ Best-effort, can diverge | P0-005 |
| Stock in Catalog == Stock in Warehouse? | ⚠️ Catalog is eventually consistent via event | P0-002 |
| Cart `completed` in Checkout == Order `created` in Order? | ✅ Handled via `completeCartAfterOrderCreation` | OK |
| Shipping cost in preview == Shipping cost in order? | ❌ Different warehouse origin logic | P1-001 |
| Idempotency key prevents duplicate in Order service? | ✅ `cart_session_id` unique constraint | OK |

---

## 📎 References

- `checkout/internal/biz/checkout/confirm.go` — Main saga orchestrator
- `checkout/internal/biz/checkout/pricing_engine.go` — CalculateOrderTotals
- `checkout/internal/biz/cart/stock.go` — Cart stock check with fallback
- `checkout/internal/biz/cart/totals.go` — Cart preview totals
- `checkout/internal/biz/cart/add.go` — AddToCart with stock + pricing
- `checkout/internal/worker/outbox/worker.go` — Outbox processor
- `checkout/internal/events/publisher.go` — Direct Dapr publisher
- `checkout/internal/biz/checkout/validation.go` — ValidateInventory
- `checkout/internal/biz/checkout/order_creation.go` — CreateOrderRequest builder

# Cart & Checkout Workflow — Quality Checklist

**Last Updated**: 2026-02-27
**Pattern Reference**: Shopify, Shopee, Lazada, Magento
**Service**: `checkout` (main API + worker binary)

---

## How to Use This Checklist

Run through this checklist when:
1. **Adding new checkout features** (new payment method, shipping option, etc.)
2. **Modifying cart/checkout business logic** (pricing, stock, promotions)
3. **Debugging checkout failures** (500 errors, data inconsistency)
4. **Reviewing PRs** that touch `checkout/internal/biz/cart/` or `checkout/internal/biz/checkout/`
5. **Pre-release validation** of the checkout service

---

## 1. Cart Management Checklist

### 1.1 Cart Lifecycle

- [ ] **1 Active Cart per Customer**: Verify `cleanupOtherActiveCartsForCustomer` is called when creating new cart for logged-in customer
- [ ] **Cart Status Transitions**: Validate status transitions follow the allowed flow:
  ```
  active → checkout → completed (happy path)
  active → abandoned (cleanup worker, 30d)
  checkout → active (session expired, cleanup)
  ```
- [ ] **Cart Expiry**: User cart = 24h, Guest cart = 1h (from `constants.go`)
- [ ] **Inactive Cart Handling**: `GetCart` creates new cart if current cart is inactive (`is_active=false`)
- [ ] **Cart Ownership Validation**: `validateCartOwnership` checks `customer_id` match for logged-in users, `guest_token` match for guests

### 1.2 Cart Items

- [ ] **Stock Check on Add**: `AddToCart` calls `warehouseInventoryService.CheckStock` — fails if no stock
- [ ] **Pricing from Pricing Service**: `AddToCart` calls `pricingService.CalculatePrice` — never hardcodes prices
- [ ] **Max Items per Cart**: `MaxItemsPerCart` limit enforced inside transaction lock
- [ ] **Max Quantity per Item**: `MaxQuantityPerItem` limit enforced in `validateQuantity`
- [ ] **Existing Item Merge**: If same product+warehouse already in cart, quantities are added (not duplicated)
- [ ] **Transaction Lock**: `LoadCartForUpdate` uses `SELECT FOR UPDATE` to prevent race conditions on cart modification
- [ ] **Cache Invalidation**: `invalidateCartCache` called after every cart modification (add/update/remove)
- [ ] **Tax Pending at Add-to-Cart**: Tax is set to `pending` at add-to-cart stage; calculated at checkout

### 1.3 Cart-Checkout Boundary

- [ ] **Cart → Checkout**: `StartCheckout` changes cart status to `checkout` and creates `checkout_session`
- [ ] **Checkout → Cart Rollback**: If checkout session expires, `CheckoutSessionCleanupWorker` resets cart to `active`
- [ ] **No Duplicate Checkout Sessions**: `StartCheckout` checks for existing session before creating new one
- [ ] **Completed Checkout Cleanup**: If existing session has `order_id`, it's deleted before creating new session

---

## 2. Checkout Session Checklist

### 2.1 Session Lifecycle

- [ ] **TTL**: Checkout session expires after 30 minutes (configurable via `OrderExpirationPending`)
- [ ] **Auto-Extend**: Session auto-extends when customer interacts (update address, select method)
- [ ] **Expiry Check**: Every `UpdateCheckoutState` checks `session.ExpiresAt` before processing
- [ ] **Cleanup Worker**: `CheckoutSessionCleanupWorker` runs every 5 minutes, resets expired checkout carts

### 2.2 Checkout Steps

Validate that each step updates the correct fields:

- [ ] **Step 1 — Cart Review**: `StartCheckout` validates stock, creates session
- [ ] **Step 2 — Shipping Address**: `UpdateShippingAddress` stores address in session + calculates tax/shipping
- [ ] **Step 3 — Shipping Method**: `SelectShippingMethod` stores method ID + recalculates shipping cost
- [ ] **Step 4 — Promotion Codes**: Applied via session's `promotion_codes` array
- [ ] **Step 5 — Payment Method**: `SelectPaymentMethod` stores method + validates eligibility
- [ ] **Step 6 — Order Summary**: `PreviewOrder` shows final totals with revalidated prices
- [ ] **Step 7 — Confirm**: `ConfirmCheckout` executes the full saga

### 2.3 Pre-Checkout Validations

All of these MUST pass before order creation:

- [ ] **Shipping Address Required**: `cart.ShippingAddress != nil`
- [ ] **Shipping Method Selected**: `cart.ShippingMethodID != nil`
- [ ] **Payment Method Eligibility**: COD ceiling (5M VND), installment floor (1M VND)
- [ ] **Delivery Zone Valid**: Country + postal code/state present
- [ ] **Max Coupon Stacking**: `MaxPromotionCodesPerOrder` limit
- [ ] **Per-SKU Quantity Ceiling**: `MaxQuantityPerSKUPerOrder = 50`
- [ ] **Order Amount Limits**: `MinOrderAmount` ≤ total ≤ `MaxOrderAmount` (100M VND)
- [ ] **Fraud Pre-Check**: Guest high-value threshold (2M VND), SKU explosion (>20 unique)
- [ ] **Price Revalidation**: `CalculateOrderTotals(RevalidatePrices: true)` confirms prices haven't changed

---

## 3. ConfirmCheckout Saga Checklist

### 3.1 Happy Path Steps

Verify each step executes in correct order:

```
1. Load & validate session + cart
2. Acquire idempotency lock (SETNX)
3. Validate prerequisites
4. Acquire coupon locks (Redis)
5. Calculate order totals (revalidate prices)
6. Check min/max order amount
7. Fraud pre-check
8. Authorize payment (skip for COD)
9. Reserve stock (just-in-time, TTL-based)
10. Build order request (with reservation IDs)
11. Create order (gRPC to Order Service)
12. Apply promotions (best-effort, parallel, DLQ on fail)
13. Finalize: outbox event + cart complete + session delete
14. Store idempotency result
```

### 3.2 Compensation (Rollback) on Failure

For each failure point, verify the correct compensation:

- [ ] **Payment auth fails (step 8)**: No reservations exist yet → nothing to rollback ✅
- [ ] **Stock reserve fails (step 9)**: `VoidAuthorization` for payment → ✅
- [ ] **Order creation fails (step 11)**: `RollbackReservationsMap` + `VoidAuthorization` → ✅
- [ ] **Void auth fails**: `FailedCompensation` DLQ with `void_authorization` type → ✅
- [ ] **Promo apply fails (step 12)**: `FailedCompensation` DLQ with `apply_promotion` type → ✅
- [ ] **Cart cleanup fails (step 13)**: `FailedCompensation` DLQ with `cart_cleanup` type → ✅
- [ ] **Outbox save fails (step 13)**: Transaction rollback + out-of-tx retry → ✅

### 3.3 Idempotency

- [ ] **Key Format**: `checkout:{cartID}:cust:{customerID}:v{cartVersion}`
- [ ] **Cart Version Included**: Prevents retrying against modified cart state
- [ ] **Lock Mechanism**: `TryAcquire` (SETNX) — atomic, prevents concurrent checkout
- [ ] **Lock TTL**: 15 minutes (covers slow payment gateways)
- [ ] **Lock Release on Failure**: `defer` releases lock only on error
- [ ] **Result Storage**: Order ID stored with 24h TTL after successful checkout
- [ ] **Duplicate Detection**: Returns cached order if lock already held with result

---

## 4. Event & Worker Checklist

### 4.1 Events Published

| Event | Topic | Publisher | When | Outbox? |
|-------|-------|----------|------|---------|
| Cart Converted | `cart.converted` | Outbox Worker | After ConfirmCheckout | ✅ Yes |

Verify:
- [ ] `cart.converted` event contains: `event_id`, `cart_session_id`, `order_id`, `customer_id`, `items_count`, `cart_total`, `converted_at`
- [ ] Event `event_id` = Order ID (stable dedup key for consumers)
- [ ] Event is saved to outbox table inside finalize transaction
- [ ] If TX fails, event is re-saved outside TX (recovery path)

### 4.2 Events NOT Published (Intentionally)

- [ ] `orders.order.status_changed` — owned by Order Service ✅
- [ ] `cart.item.added` — removed (comment: "Cart events removed") ✅
- [ ] `checkout.completed` — removed (replaced by `cart.converted`) ✅

### 4.3 Worker Health

- [ ] **Outbox Worker**: Processes pending events every 1s, recovers stuck events every 10 cycles
- [ ] **Cart Cleanup Worker**: Runs every 1h, skips checkout/completed carts, releases reservations
- [ ] **Session Cleanup Worker**: Runs every 5m, resets expired checkout carts to active
- [ ] **Failed Compensation Worker**: Runs every 5m, exponential backoff (1m → 2h max), alerts on max retries

---

## 5. Data Consistency Checklist

### 5.1 Cross-Service Consistency

- [ ] **Cart Price ↔ Pricing Service**: Prices fetched at AddToCart time; revalidated at ConfirmCheckout
- [ ] **Stock ↔ Warehouse Service**: Checked at AddToCart; reserved at ConfirmCheckout (JIT)
- [ ] **Reservation TTL**: Matches payment window; auto-expires if payment not completed
- [ ] **Order ↔ Checkout**: `cart_session_id` unique constraint on Order prevents duplicate orders
- [ ] **Promotion Usage ↔ Promotion Service**: Applied after order creation (best-effort + DLQ)

### 5.2 Local Consistency

- [ ] **Cart Items ↔ Cart Session**: Items joined via `cart_id` FK
- [ ] **Checkout Session ↔ Cart Session**: Linked via `session_id` = `cart_id`
- [ ] **Outbox Events**: Unique constraint on `id` (= order_id) prevents duplicate events
- [ ] **Idempotency Store**: Redis-based with TTL; version-aware key prevents stale retries

---

## 6. GitOps Deployment Checklist

- [ ] **API Deployment**: Has Dapr sidecar (`dapr.io/enabled: "true"`)
- [ ] **Worker Deployment**: Has Dapr sidecar + init containers (wait-for-db, wait-for-redis)
- [ ] **Init Containers**: ⚠️ Verify main API also has init containers (currently missing!)
- [ ] **Health Probes**: API uses `/health/live` + `/health/ready`; Worker uses `/healthz`
- [ ] **Resource Limits**: API ≤ 512Mi; Worker ≤ 256Mi
- [ ] **Sync Wave Order**: Migration (4) → API (6) → Worker (7)
- [ ] **Image Tag**: `placeholder` in base; CI/CD overlay sets actual tag
- [ ] **ConfigMap**: `overlays-config` provides DATABASE_*, REDIS_*, service discovery vars
- [ ] **Secrets**: `checkout-secrets` provides DATABASE_PASSWORD, JWT secrets

---

## 7. Known Edge Cases & Mitigations

| Edge Case | Current Mitigation | Status |
|-----------|-------------------|--------|
| Double submit (duplicate order) | SETNX idempotency lock | ✅ Handled |
| Price changed mid-checkout | Revalidated at ConfirmCheckout | ✅ Handled |
| Stock sold out during checkout | JIT reservation fails → checkout aborted | ✅ Handled |
| Payment auth timeout | 15min lock TTL; payment gateway retries internally | ✅ Handled |
| Pod crashes during ConfirmCheckout | Idempotency lock released on error; outbox recovers events | ✅ Handled |
| Guest cart merge on login | `validateCartOwnership` auto-upgrades guest → customer | ✅ Handled |
| Multiple browser tabs | Second tab creates new cart, first abandoned | ⚠️ Known UX issue |
| Redis unavailable for coupon lock | Fail-open; server-side dedup needed in Promotion Service | ⚠️ Verify |
| Outbox event permanently failed | Marked `failed` but no alert sent | ⚠️ Add alerting |

---

## 8. Review Sign-off

| Reviewer | Date | Status | Notes |
|----------|------|--------|-------|
| TA Agent | 2026-02-27 | ✅ Initial Review | 17 issues found (3 P0, 7 P1, 4 P2, 3 informational) |
| | | | |

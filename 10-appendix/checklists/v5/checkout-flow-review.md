# 🛒 Checkout Flow Review — Shopify / Shopee / Lazada Pattern Analysis

> **Date**: 2026-02-17 | Part of v5 system review  
> **Scope**: Cross-service checkout data consistency, saga/outbox patterns, edge cases  
> **Services Indexed**: checkout, order, payment, warehouse, pricing, promotion, shipping, catalog, customer

---

## Quick Stats

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 P0 Critical | 4 | **Fixed** |
| 🟡 P1 High | 10 | Open |
| 🔵 P2 Medium | 10 | Open |

---

## Architecture Overview

```
┌─────────┐     StartCheckout      ┌──────────────────────────────────────────────────────┐
│ Customer │ ──────────────────────→│ Checkout Service                                     │
│          │     ConfirmCheckout    │                                                      │
│          │ ──────────────────────→│  1. Idempotency Lock (SETNX, 5min)                   │
└─────────┘                        │  2. Load & Validate Session + Cart                    │
                                   │  3. CalculateOrderTotals (RevalidatePrices=true)      │
                                   │     ├── Pricing Service (price revalidation)          │
                                   │     ├── Shipping Service (shipping cost)              │
                                   │     └── Promotion Service (coupon validation)         │
                                   │  4. Authorize Payment (Payment Service)               │
                                   │  5. Extend Reservations (Warehouse Service)           │
                                   │  6. CreateOrder (Order Service gRPC)                  │
                                   │  7. Apply Promotion Usage (best-effort + DLQ)         │
                                   │  8. Finalize Cart + Cleanup (local TX)                │
                                   │  9. Publish CartConverted event (outbox)              │
                                   └──────────────────────────────────────────────────────┘
```

---

## 🔴 P0 — Critical Issues (All Fixed)

### P0-1: Panic in Payment Authorization — Nil Type Assertion

- **File**: `checkout/internal/biz/checkout/payment.go:103`
- **Status**: ✅ Fixed
- **Solution**: Added `extractCurrency()` helper with safe type assertion and fallback to `constants.DefaultCurrency`
- **Code**: `currency := extractCurrency(session.Metadata)`

### P0-2: DLQ Compensation Worker Missing 3 of 4 Operation Handlers

- **File**: `checkout/internal/worker/cron/failed_compensation.go:189-194`
- **Status**: ✅ Fixed
- **Solution**: Added all 4 operation handlers: `void_authorization`, `cart_cleanup`, and `apply_promotion` to `processSingleCompensation`
- **Impact**: Prevents money leaks from failed void operations and cart cleanup failures

### P0-3: Outbox Events Stuck in `processing` Status After Worker Crash

- **File**: `checkout/internal/worker/outbox/worker.go:41`
- **Status**: ✅ Fixed
- **Solution**: Added `recoverStuckEvents()` method that runs at startup to reset events in `processing` status older than 5 minutes back to `pending`
- **Shopee pattern**: Uses lease-based recovery with timeout detection

### P0-4: No Reservation Rollback on Payment Authorization Failure

- **File**: `checkout/internal/biz/checkout/confirm.go:315-322`
- **Status**: ✅ Fixed
- **Solution**: Added reservation release logic that executes when payment authorization fails
- **Current flow**: Step 5: extendReservationsForPayment ✅ → Step 5: authorizePayment ❌ → Release reservations → return error
- **Impact**: Prevents stock from being locked indefinitely when checkout fails

---

## 🟡 P1 — High Impact Issues

### P1-1: No Price Revalidation at StartCheckout

- **File**: `checkout/internal/biz/checkout/start.go`
- **Current**: StartCheckout only validates stock, not prices
- **Risk**: Customer may see outdated price from cart, only discovering the price changed at ConfirmCheckout
- **Shopify pattern**: Price is rechecked when creating a draft order (equivalent to StartCheckout)
- **Shopee pattern**: "Price changed" warning shown before checkout button
- [ ] Add optional price revalidation at StartCheckout with change notification

### P1-2: Sequential Reservation Validation (N Serial Calls)

- **File**: `checkout/internal/biz/checkout/confirm.go:491-517`
- **Current**: `extractAndValidateReservations` loops through each reservation ID and calls `GetReservation` sequentially
- **Impact**: 10-item cart = 10 serial gRPC calls to warehouse, adding ~500ms-2s
- **Shopee pattern**: Batch reservation validation (`BatchGetReservations`)
- [ ] Parallelize with `errgroup` or add batch gRPC endpoint

### P1-3: No Timeout on Price Calculation errgroup

- **File**: `checkout/internal/biz/checkout/pricing_engine.go:88-117`
- **Current**: `errgroup.WithContext(ctx)` inherits parent context but no explicit deadline
- **Risk**: Slow promotion/shipping service = unbounded checkout latency
- [ ] Add `context.WithTimeout(ctx, 10*time.Second)` for the pricing errgroup

### P1-4: Sequential Promotion Apply Loop

- **File**: `checkout/internal/biz/checkout/confirm.go:381-431`
- **Current**: Loops through `ValidPromotions` and calls `ApplyPromotion` one by one
- **Risk**: Multiple promos = slow checkout confirmation
- [ ] Batch apply or parallelize with errgroup

### P1-5: No Exponential Backoff in Compensation Retry

- **File**: `checkout/internal/worker/cron/failed_compensation.go:51`
- **Current**: Fixed 5-minute polling interval, no per-item backoff
- **Risk**: Transient payment gateway failures get hammered every 5 mins
- **Shopify pattern**: Exponential backoff: 1min → 5min → 30min → 2hr → manual
- [ ] Add `nextRetryAt = now + 2^retryCount * baseDelay` with jitter

### P1-6: N+1 Catalog Query Inside Promotion Pricing Loop

- **File**: `checkout/internal/biz/checkout/pricing_engine.go:264-268`
- **Current**: For each cart item, `catalogClient.GetProduct()` is called inside the promotion building loop
- **Impact**: 10 items = 10 extra gRPC calls just to get category/brand
- [ ] Batch fetch or pre-cache product details before entering the loop

### P1-7: Hardcoded Shipping Origin Address

- **File**: `checkout/internal/biz/checkout/preview.go:153-157`
- **Current**: `FromAddress` hardcoded to `"US"/"CA"/"Default City"/"00000"`
- **Risk**: Wrong shipping cost for non-US warehouses
- **Lazada pattern**: Origin derived from seller/warehouse address per item
- [ ] Use `getWarehouseOriginAddress` instead of hardcoded values

### P1-8: No Reservation ID Deduplication

- **File**: `checkout/internal/biz/checkout/confirm.go:492`
- **Current**: `extractReservationIDs` returns all IDs including potential duplicates
- **Risk**: Same reservation validated/extended twice; wasted gRPC calls
- [ ] Add `uniqueReservationIDs` dedup before validation

### P1-9: Cart Price Sync Updates Items Without Transaction

- **File**: `checkout/internal/biz/cart/sync.go:103-107`
- **Current**: Loop through items, `UpdateItem` one by one, no wrapping transaction
- **Risk**: Partial update if cart has 10 items and crash after 5
- [ ] Wrap in transaction or batch update

### P1-10: `parseInt64` Silently Strips Non-Numeric Characters

- **File**: `checkout/internal/adapter/payment_adapter.go:162-174`
- **Current**: `parseInt64("abc123")` returns `123` — no error
- **Risk**: Invalid payment method IDs silently mapped to wrong IDs
- [ ] Use `strconv.ParseInt` with error propagation

---

## 🔵 P2 — Medium / Edge Cases

### P2-1: Minimum Order Amount Hardcoded to 0

- **File**: `checkout/internal/biz/checkout/confirm.go:302`
- **Current**: `const minimumOrderAmount = 0.0 // TODO: Move to config/settings service`
- **Impact**: No minimum order enforcement
- [ ] Move to config or settings service

### P2-2: Currency Fallback to "USD" Without Config

- **Files**: `payment.go:104`, `pricing_engine.go:377-381`
- **Current**: Multiple hardcoded `"USD"` fallbacks
- **Shopee/Lazada pattern**: Currency from store config, never hardcoded
- [ ] Centralize default currency in config

### P2-3: Duplicate Step Numbering in ConfirmCheckout

- **File**: `checkout/internal/biz/checkout/confirm.go:308,317,324`
- **Current**: Three steps labeled "5" (authorize payment, build order, stock validation)
- [ ] Renumber to 5, 6, 7

### P2-4: Idempotency Lock TTL (5min) vs Result TTL (24h) Mismatch

- **File**: `checkout/internal/biz/checkout/confirm.go:206,454`
- **Risk**: If checkout takes >5min (slow payment gateway), lock expires and second request can enter
- **Shopify pattern**: Lock TTL = max checkout timeout (15min)
- [ ] Increase lock TTL to at least 15 minutes

### P2-5: `ValidatePromoCode` Dereferences nil customerID

- **File**: `checkout/internal/biz/checkout/validation.go:155`
- **Current**: `CustomererId: *customerID` without nil check
- **Risk**: Panic for guest checkout promo validation
- [ ] Add nil check, return error for guest users

### P2-6: Expired Checkout Session Cleanup Error Silenced

- **File**: `checkout/internal/biz/checkout/start.go:71`
- **Current**: `_ = uc.cleanupExpiredCheckoutSession(ctx, req.CartID)`
- **Risk**: Leaked sessions if cleanup consistently fails
- [ ] Log error, add monitoring metric

### P2-7: CheckStock Returns Requested Qty, Not Actual Available

- **File**: `checkout/internal/adapter/warehouse_adapter.go:36`
- **Current**: `return quantity, nil // Mock: return requested quantity as available`
- **Risk**: Downstream code can't show "X items remaining" or partial fulfillment
- [ ] Return actual available from warehouse gRPC response

### P2-8: Cart Status String Comparisons Without Full Constant Coverage

- **File**: `checkout/internal/biz/checkout/confirm.go:524-537`, `order_creation.go:95`
- **Current**: Mix of `constants.CartStatusCheckout` and raw strings like `"active"`, `"completed"`
- [ ] Define constants for all states: `active`, `checkout`, `completed`, `expired`

### P2-9: No Max Cart Items Limit

- **Current**: No validation on number of items in cart
- **Risk**: Cart with 1000 items = 1000 gRPC calls for stock/price validation
- **Shopee limit**: ~50 items, **Lazada**: ~150 items
- [ ] Add `MaxCartItems` config (recommended: 100)

### P2-10: Guest Checkout Cannot Use Promo Codes

- **File**: `checkout/internal/biz/checkout/validation.go:155`
- **Current**: `ValidatePromoCode` requires non-nil `*customerID`
- **Shopify pattern**: Guest can use promo codes (validated without customer context)
- [ ] Support guest promo validation with session-based tracking

---

## Cross-Service Data Consistency Matrix

### Price Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| Add to Cart | Pricing → Checkout | `CalculatePrice` → store in cart item | ✅ |
| Preview | Checkout (cached prices) | `RevalidatePrices=false` | ⚠️ May be stale |
| Confirm | Pricing → Checkout | `RevalidatePrices=true` → fresh prices | ✅ |
| Create Order | Checkout → Order | Totals passed as-is | ⚠️ No server-side revalidation by Order |
| **Gap** | Order accepts Checkout totals without recalculating | Shopify recalculates on Order service side | ❌ |

### Stock Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| Add to Cart | Warehouse → Checkout | `CheckStock` (non-binding) | ✅ |
| Start Checkout | Warehouse → Checkout | `CheckStock` + `ReserveStock` (15min TTL) | ✅ |
| Confirm Checkout | Warehouse → Checkout | `GetReservation` + expiry check + `ExtendReservation` | ✅ |
| Confirm Checkout | Warehouse → Checkout | `validateStockBeforeConfirm` (additional check) | ⚠️ Redundant with reservation |
| Create Order | Order → Warehouse | `confirmOrderReservations` | ✅ |
| **Gap** | Partial `ExtendReservation` failure has no rollback | | ❌ P0-4 |

### Promotion Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| Apply Coupon | Promotion → Checkout | `ValidateCoupon` / `ValidatePromotions` | ✅ |
| Confirm | Checkout → Promotion | `ApplyPromotion` (post-order, best-effort + DLQ) | ✅ |
| Cancel Order | Order → Promotion | `ReleasePromotionUsage` via event consumer | ✅ |
| **Gap** | No atomic reserve-and-validate → race between validate and apply | | ⚠️ |

### Payment Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| Validate | Payment → Checkout | `ValidatePaymentMethodOwnership` | ✅ |
| Authorize | Payment → Checkout | `AuthorizePayment` (pre-order) | ✅ |
| Void on Failure | Payment → Checkout | `VoidAuthorization` with DLQ for failures | ✅ (DLQ exists) |
| Capture | Order → Payment | Handled by Order service | ✅ |
| **Gap** | DLQ `void_authorization` handler not implemented in worker | | ❌ P0-2 |

---

## Saga / Compensation Coverage

### ConfirmCheckout Compensation Matrix

```
Step 1: Load session/cart           → No compensation needed
Step 2: Validate prerequisites      → No compensation needed
Step 3: Calculate totals (pricing)  → No compensation needed (read-only)
Step 4: Authorize payment           → VOID payment on subsequent failure   ✅ (lines 339-373)
Step 5: Extend reservations         → RELEASE reservations on Order fail   ❌ No explicit rollback
Step 6: Create order                → VOID payment if order creation fails ✅ (lines 338-376)
Step 7: Apply promotions            → Best-effort + DLQ                    ✅ (lines 399-427)
Step 8: Finalize cart               → Best-effort + DLQ                    ✅ (lines 160-188)
```

### Compensation Gap: Payment Auth Fail → Reservation Leak

```
Current:  Reserve → Extend → Auth(FAIL) → return error ← reservations still extended!
Expected: Reserve → Extend → Auth(FAIL) → RELEASE reservations → return error
```

### Outbox Pattern Assessment

| Feature | Status | Notes |
|---------|--------|-------|
| Outbox table exists | ✅ | `migrations/004_create_outbox_table.sql` |
| Worker polls 1s | ✅ | Efficient for near-real-time delivery |
| Batch processing (50) | ✅ | Prevents overload |
| Stuck event recovery | ❌ P0-3 | `processing` events never reclaimed |
| Dedup on publish | ❌ | No idempotency key → duplicate possible on crash-restart |
| Retention cleanup | ✅ | 30-day, cleans `published` + `failed` |

---

## Industry Pattern Comparison

| Pattern | Shopify | Shopee | Lazada | This Codebase |
|---------|---------|--------|--------|---------------|
| Price revalidation at checkout start | ✅ Draft order recalcs | ✅ Price change warning | ✅ | ❌ Only at confirm |
| Stock reservation with TTL | ✅ | ✅ Flash sale pattern | ✅ | ✅ 15min + extend |
| Idempotency on checkout | ✅ Idempotency key header | ✅ | ✅ | ✅ SETNX lock |
| Atomic promo reserve | N/A | ✅ ValidateAndReserve | ✅ | ❌ Validate then Apply |
| Per-item pricing (rounding) | ✅ Last-item remainder | ✅ | ✅ | ✅ Shopify pattern |
| Payment auth before order | ✅ (3D Secure) | ✅ | Varies | ✅ |
| Saga compensation DLQ | ✅ Background jobs | ✅ | ✅ | ⚠️ Partial (P0-2) |
| Outbox for events | ✅ | ✅ | ✅ | ⚠️ No stuck recovery (P0-3) |
| Order-side total verification | ✅ Recalculates | ✅ | ✅ | ❌ Trusts checkout |
| Max cart items limit | 500 | ~50 | ~150 | ❌ No limit |
| Multi-currency | ✅ | ✅ | ✅ | ⚠️ Hardcoded USD |

---

## Remediation Priority

### Phase 1 — Immediate (Money/Data Risk)
1. P0-1: Fix panic in `payment.go:95`
2. P0-2: Add 3 missing DLQ handlers in compensation worker
3. P0-3: Add outbox stuck-event recovery
4. P0-4: Rollback reservation on payment auth failure

### Phase 2 — Short-term (Reliability)
5. P1-2: Parallelize reservation validation
6. P1-3: Add timeout to pricing errgroup
7. P1-5: Exponential backoff for compensation retry
8. P1-6: Batch catalog queries in promo loop
9. P1-10: Fix `parseInt64` to use `strconv.ParseInt`

### Phase 3 — Medium-term (E-commerce Quality)
10. P1-1: Price revalidation at StartCheckout
11. P1-7: Dynamic shipping origin from warehouse
12. P2-4: Increase idempotency lock TTL
13. P2-9: Add max cart items limit
14. P2-1: Configurable minimum order amount

### Phase 4 — Long-term (Industry Parity)
15. Order-side total verification (Shopify pattern)
16. Atomic promo reserve-and-validate (Shopee pattern)
17. Multi-currency support from config
18. Guest promo code support

---

## Files Reviewed

| File | Lines | Key Function |
|------|-------|-------------|
| `checkout/internal/biz/checkout/confirm.go` | 600 | `ConfirmCheckout` — main orchestrator |
| `checkout/internal/biz/checkout/start.go` | 100 | `StartCheckout` — session creation |
| `checkout/internal/biz/checkout/preview.go` | 232 | `PreviewOrder` — totals preview |
| `checkout/internal/biz/checkout/pricing_engine.go` | 435 | `CalculateOrderTotals` — unified pricing |
| `checkout/internal/biz/checkout/payment.go` | 123 | `authorizePayment` — payment auth |
| `checkout/internal/biz/checkout/validation.go` | 194 | `ValidateInventory`, `ValidatePromoCode` |
| `checkout/internal/biz/checkout/order_creation.go` | 144 | `buildOrderRequestFromCart` |
| `checkout/internal/biz/checkout/usecase.go` | 272 | UseCase struct, stock checks |
| `checkout/internal/biz/cart/stock.go` | 117 | Stock fallback to catalog cache |
| `checkout/internal/biz/cart/sync.go` | 121 | `SyncCartPrices` |
| `checkout/internal/biz/cart/retry.go` | 40 | Optimistic lock retry |
| `checkout/internal/adapter/payment_adapter.go` | 175 | Payment service wrapper |
| `checkout/internal/adapter/warehouse_adapter.go` | 142 | Warehouse service wrapper |
| `checkout/internal/worker/cron/failed_compensation.go` | 212 | DLQ compensation retry worker |
| `checkout/internal/worker/outbox/worker.go` | 154 | Outbox event publisher worker |
| `checkout/internal/model/failed_compensation.go` | 61 | FailedCompensation model |

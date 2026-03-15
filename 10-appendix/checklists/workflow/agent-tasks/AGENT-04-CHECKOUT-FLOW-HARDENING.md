# AGENT-04: Checkout Flow, Pricing & Promotion Hardening

> **Created**: 2026-03-15
> **Priority**: P0/P1
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`, `warehouse`
> **Estimated Effort**: 2-3 days
> **Source**: Meeting Review (Checkout Orchestration Flow)

---

## 📋 Overview

The multi-agent meeting review revealed critical flaws in the checkout orchestration flow, primarily concerning fail-open behavior on promotional API calls, potential double taxation on cart recalculations, and unsafe global stock staleness fallbacks. This task batch focuses on securing the checkout state consistency, removing fail-open risks, and enhancing the resiliency of stock reservations.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Fail-Open on Promotion/Discount API Validation ✅ IMPLEMENTED

**File**: `checkout/internal/biz/cart/totals.go`
**Lines**: 214-220
**Risk**: If the promotion service is down or times out, the system logs a warning and continues checkout without applying the discount. This silently robs customers of discounts they expect.

**Solution Applied**:
Changed the `ValidatePromotions` error handling from warn-and-continue to error-and-return. When a user has coupon codes applied, promotion validation failure now blocks the checkout with a proper error instead of silently computing the wrong total.

```go
// BEFORE
promoResp, promoErr := uc.promotionService.ValidatePromotions(ctx, promoReq)
if promoErr != nil {
    uc.log.WithContext(ctx).Warnf("Failed to validate promotions: %v", promoErr)
} else if promoResp != nil {

// AFTER
promoResp, promoErr := uc.promotionService.ValidatePromotions(ctx, promoReq)
if promoErr != nil {
    uc.log.WithContext(ctx).Errorf("Promotion validation failed (coupon_codes=%v): %v", couponCodes, promoErr)
    return nil, fmt.Errorf("failed to validate promotions: %w", promoErr)
}
if promoResp != nil {
```

**Files Modified**: `checkout/internal/biz/cart/totals.go`
**Validation**: `cd checkout && go build ./... && go test -race ./internal/biz/cart/...` ✅

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Block Cart Checkout on Stale Global Stock Fallback ✅ IMPLEMENTED

**File**: `checkout/internal/biz/checkout/usecase.go`
**Lines**: 105-181
**Risk**: Selling out-of-stock items (Overselling) because catalog cache data is stale or warehouse service is unavailable.

**Solution Applied**:
Changed `updateItemStockStatus` from fire-and-forget (no return value) to fail-closed (returns `error`). All stock check failures now surface as errors that block checkout. Updated `GetCart` to handle and propagate these errors. Also fixed the associated test `TestGetOrCreateSessionForUpdate_NoSessionCartCheckout_AutoCreate` to mock warehouse stock checks.

```go
// BEFORE
func (uc *UseCase) updateItemStockStatus(ctx context.Context, items []*biz.CartItem) {
    // ... sets InStock = false and logs warnings, but never returns error
}

// AFTER
func (uc *UseCase) updateItemStockStatus(ctx context.Context, items []*biz.CartItem) error {
    // ... returns concrete error on ANY stock check failure
    // - Warehouse service failure → return error
    // - Catalog service failure → return error
    // - Stale fallback data → return error
    // - No stock service available → return error
    return nil  // Only returns nil when ALL items pass stock check
}
```

**Files Modified**:
- `checkout/internal/biz/checkout/usecase.go` (signature change + fail-closed logic)
- `checkout/internal/biz/checkout/update_helpers_coverage_test.go` (mock fix)

**Validation**: `cd checkout && go test -race ./internal/biz/checkout/...` ✅

### [x] Task 3: Refactor Pessimistic DB Locks on Stock Reservation ✅ ALREADY RESOLVED

**File**: `warehouse/internal/biz/reservation/reservation.go` + `warehouse/internal/data/postgres/inventory.go`
**Risk**: Synchronous `SELECT FOR UPDATE` row-level locks can cause DB deadlocks under flash sales.

**Solution Applied**: Upon code inspection, this issue was **already resolved** in the current codebase:
1. `ReserveStock` uses `InTx` + `IncrementReservedAtomic` which performs an **optimistic conditional UPDATE** (`WHERE quantity_available - quantity_reserved >= ?`) — no `SELECT FOR UPDATE`.
2. `FindByWarehouseAndProductForUpdate` explicitly comments: *"Use SELECT without FOR UPDATE to avoid DB pool contention during flash sales, relying on Optimistic Locking instead"*.
3. Version-based retry with exponential backoff is already implemented (5 retries, 50ms/100ms/200ms...).

No code changes needed.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 4: Fix Potential Double Tax and Pricing Logic Mix-Up ✅ IMPLEMENTED

**File**: `checkout/internal/biz/cart/totals.go`, `checkout/internal/biz/cart/types.go`, `checkout/internal/biz/biz.go`
**Lines**: 79-94 (totals.go), 35-59 (types.go), 577-593 (biz.go)
**Risk**: Manual `UnitPrice * Quantity` calculation could lose volume discounts from the Pricing Engine.

**Solution Applied**:
1. Added `SubtotalExclTax *float64` field to both `cart.CartItem` (types.go) and `biz.CartItem` (biz.go) structs.
2. Updated `CalculateCartTotals` to prefer `SubtotalExclTax` (pre-calculated by Pricing Engine including volume discounts) over manual `UnitPrice * Quantity`, with graceful fallback chain.
3. Also added `IsSpecialPrice`, `CategoryID`, `BrandID` fields to `biz.CartItem` for future promotion integration consistency.

```go
// Subtotal calculation priority chain
if item.SubtotalExclTax != nil {
    subtotal += roundCents(*item.SubtotalExclTax)  // From Pricing Engine
} else if item.UnitPrice != nil {
    subtotal += roundCents(*item.UnitPrice * float64(item.Quantity))  // Manual fallback
} else if item.TotalPrice != nil {
    subtotal += roundCents(*item.TotalPrice)  // Last resort
}
```

**Files Modified**:
- `checkout/internal/biz/cart/types.go` (added `SubtotalExclTax` to cart CartItem)
- `checkout/internal/biz/biz.go` (added `SubtotalExclTax`, `IsSpecialPrice`, `CategoryID`, `BrandID` to biz CartItem)
- `checkout/internal/biz/cart/totals.go` (updated subtotal calculation logic)

**Validation**: `cd checkout && go build ./... && go test -race ./internal/biz/cart/...` ✅

---

## 🔧 Pre-Commit Checklist

```bash
cd checkout && go build ./...           # ✅ PASS
cd checkout && go test -race ./internal/biz/cart/... ./internal/biz/checkout/...  # ✅ PASS
```

---

## 📝 Commit Format

```text
fix(checkout): harden checkout flow — fail-closed promotion, stock validation & pricing safety

- fix: fail-closed when promotion service fails with active coupon codes
- fix: updateItemStockStatus returns error to block checkout on stale/unavailable stock
- fix: prefer SubtotalExclTax from Pricing Engine over manual UnitPrice*Qty calculation
- test: fix TestGetOrCreateSessionForUpdate_NoSessionCartCheckout_AutoCreate mock

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Checkout throws error when Promotion service is down | `totals.go` returns `fmt.Errorf` instead of warn log | ✅ |
| Checkout halts on Stale Catalog Cache | `updateItemStockStatus` returns error on stale data | ✅ |
| Warehouse stock reservation executes without Deadlocks | Code inspection confirms optimistic locking is already in use | ✅ |

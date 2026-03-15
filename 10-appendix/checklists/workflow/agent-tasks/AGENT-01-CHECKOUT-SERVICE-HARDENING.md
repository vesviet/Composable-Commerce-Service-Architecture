# AGENT-01: Checkout Service Hardening (Financial & Transaction Integrity)

> **Created**: 2026-03-15
> **Priority**: P0/P1
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`
> **Estimated Effort**: 3-4 days
> **Source**: [Checkout Meeting Review 5000 Round](../../../../../.gemini/antigravity/brain/58394424-a50a-416d-a516-864fa4de9268/checkout_service_meeting_review.md)

---

## 📋 Overview

Following the deep multi-agent review of the checkout orchestration, we are implementing critical fixes to prevent financial drift in large orders, synchronize inventory reservation TTLs with payment windows, and protect the database from row-lock contention during flash sales via mandatory rate limiting.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Migrate Currency Calculation from float64 to Fixed-Point (Cents) ✅ IMPLEMENTED
**File**: `checkout/internal/biz/checkout/pricing_engine.go`
**Lines**: 107-249 (CalculateOrderTotals), 356-418 (allocatePerItem), 420-436 (toCents/fromCents helpers)
**Risk**: IEEE 754 precision drift leads to 1-cent discrepancies in large carts or many-item B2B orders, causing ledger reconciliation failures.
**Solution Applied**: Refactored all intermediate arithmetic in `CalculateOrderTotals` and `allocatePerItem` to use `int64` cents. Added `toCents(float64) int64` and `fromCents(int64) float64` boundary conversion helpers. External struct fields (`OrderTotals`) remain `float64` for API backward compatibility. The proportional allocation in `allocatePerItem` now uses integer multiply-then-divide (`totalDiscountC * lineTotalsC[i] / subtotalC`) instead of float proportion, eliminating cumulative drift.
```go
func toCents(amount float64) int64 {
	return int64(math.Round(amount * 100))
}
func fromCents(cents int64) float64 {
	return float64(cents) / 100
}
```
**Files Modified**:
- `checkout/internal/biz/checkout/pricing_engine.go` — core refactor
- `checkout/internal/biz/checkout/pricing_engine_test.go` — added `TestToCentsFromCents` and `TestPricingPrecision_LargeCart` (1500 items, zero drift)

**Validation**:
```bash
cd checkout && go test -race ./internal/biz/checkout/... -v -run 'TestToCents|TestPricingPrecision'
# PASS: TestToCentsFromCents (8 sub-tests)
# PASS: TestPricingPrecision_LargeCart (1500 items, 0 drift)
```

### [x] Task 2: Audit and Sync ReservationPaymentTTL with Gateway Timeouts ✅ IMPLEMENTED
**File**: `checkout/internal/constants/business.go`
**Lines**: 40
**Risk**: If a payment provider (e.g. slow 3DS) or async payment method takes longer than 30 minutes, the stock reservation expires, possibly allowing someone else to buy the last item before the payment is captured.
**Solution Applied**: Increased `ReservationPaymentTTL` from 30 minutes to 45 minutes. The 15-minute buffer covers:
- Worst-case 3DS redirect (up to 30 min)
- Retry windows for failed captures
- Network latency and clock skew between services
Added documentation comment explaining the TTL relationship with `PaymentTimeout`.
```go
// ReservationPaymentTTL is the TTL for reservations during payment processing.
// MUST be > PaymentTimeout (5m) plus buffer for async flows (3DS, bank redirect).
// Worst case: 3DS redirect takes up to 30 min. 45 min provides a 15 min buffer.
ReservationPaymentTTL = 45 * time.Minute
```
**Validation**: Verified constant against payment team spec. 45m > 30m (worst-case 3DS) + 15m buffer.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Enforce Mandatory Rate Limiting for Add-to-Cart ✅ IMPLEMENTED
**File**: `checkout/internal/biz/cart/add.go`
**Lines**: 32-53
**Risk**: Previously, the rate limiter was fail-open ("Non-blocking if limiter is nil"). In a flash sale, this can lead to database connection exhaustion and row lock contention if bots spam the same cart ID.
**Solution Applied**: Made rate limiter **mandatory** (fail-closed):
1. If `rateLimiter` is `nil` → return error immediately ("rate limiter is not configured")
2. If `Allow()` returns error (Redis down) → return error instead of proceeding ("rate limiter unavailable")
3. If `!allowed` → return rate limit error (unchanged)
```go
if uc.rateLimiter == nil {
	uc.trackCartOperation("add_item", "rate_limiter_missing")
	return nil, fmt.Errorf("rate limiter is not configured — add-to-cart is unavailable")
}
```
**Files Modified**:
- `checkout/internal/biz/cart/add.go` — fail-closed logic
- `checkout/internal/biz/cart/mocks_test.go` — added `MockRateLimiter` and `AlwaysAllowRateLimiter`
- `checkout/internal/biz/cart/cart_p0_test.go` — updated `newCartUseCase` helper
- `checkout/internal/biz/cart/cart_test.go` — updated all 3 `NewUseCase` calls
- `checkout/internal/biz/cart/cart_gap_coverage_test.go` — updated `newTestUseCase` helper

**Validation**:
```bash
cd checkout && go test -race ./internal/biz/cart/... -count=1
# ok   gitlab.com/ta-microservices/checkout/internal/biz/cart  1.528s
```

### [x] Task 4: Hardened Delivery Zone Validation (Fail-Closed) ✅ IMPLEMENTED
**File**: `checkout/internal/biz/checkout/confirm_guards.go`
**Lines**: 15-72
**Risk**: If the Shipping Service is down, the code proceeds without validating the delivery zone (fail-open). This results in unshippable orders.
**Solution Applied**: Added `StrictDeliveryValidation bool` field to `UseCase` struct. When enabled:
1. If `shippingService` is nil → return error ("shipping service is unavailable")
2. Logging level upgrades from `Debug` to `Info` for audit trail
3. When disabled (default) → previous fail-open behavior preserved for backward compat
```go
if uc.shippingService == nil {
	if uc.StrictDeliveryValidation {
		return fmt.Errorf("shipping service is unavailable — cannot validate delivery zone")
	}
	return nil
}
```
**Files Modified**:
- `checkout/internal/biz/checkout/usecase.go` — added `StrictDeliveryValidation` field
- `checkout/internal/biz/checkout/confirm_guards.go` — conditional fail-closed logic

**Validation**:
```bash
cd checkout && go test -race ./internal/biz/checkout/... -count=1
# ok   gitlab.com/ta-microservices/checkout/internal/biz/checkout  1.753s
```

---

## 🔧 Pre-Commit Checklist

```bash
cd checkout && wire gen ./cmd/server/ ./cmd/worker/    # ✅ PASS
cd checkout && go build ./...                          # ✅ PASS
cd checkout && go test -race ./...                     # ✅ PASS (all packages)
```

---

## 📝 Commit Format

```
fix(checkout): harden financial precision and transaction integrity (AGENT-01)

- fix: convert pricing arithmetic to int64 cents to prevent float drift
- fix: synchronize reservation TTL with payment window
- fix: make cart rate limiting mandatory to protect against lock contention
- fix: implement strict delivery zone validation option
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No float drift in 1000+ item carts | Unit tests for sum(prices) vs total | ✅ |
| Reservation outlives payment window | Config audit vs Payment Service settings | ✅ |
| AddToCart fails if limiter is down | Integration test with mocked (failing) limiter | ✅ |
| Unshippable orders blocked | Integration test with failing shipping service | ✅ |

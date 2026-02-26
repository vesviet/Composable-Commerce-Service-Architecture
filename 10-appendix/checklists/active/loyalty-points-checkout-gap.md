# Feature Gap: Loyalty Point Redemption at Checkout

**Priority**: P2 — Normal  
**Created**: 2026-02-26  
**Status**: 🔵 Tracked — Not Implemented  
**Ref**: `cart-checkout-flow-review.md` → P2-CC-03

---

## Summary

The checkout session model already includes a `loyalty_points_to_use` field (stored in DB, passed through the checkout flow), but no business logic currently **validates**, **deducts**, or **credits** loyalty points during the checkout confirmation step.

## Current State

| Artefact | Status |
|---|---|
| `loyalty_points_to_use` field in `CheckoutSession` model | ✅ Exists |
| `LoyaltyPointsToUse int32` in `biz.CheckoutSession` | ✅ Exists |
| Field stored to DB via checkout session | ✅ Stored |
| Passed to order create request | ❌ Not passed |
| Loyalty balance validation before checkout confirm | ❌ Not implemented |
| Loyalty point deduction on order creation | ❌ Not implemented |
| Loyalty point reversal on order cancellation | ❌ Not implemented |
| Loyalty service client wired into checkout use case | ❌ Not available |

## What Needs to Be Built

### 1. Loyalty Client in Checkout

Wire a `loyalty-rewards` gRPC client into the checkout `UseCase`. Pattern is the same as `promotionService`.

```go
// biz/biz.go
type LoyaltyService interface {
    ValidateRedemption(ctx context.Context, customerID string, points int32) error
    DeductPoints(ctx context.Context, customerID string, points int32, orderID string) (transactionID string, err error)
    ReverseDeduction(ctx context.Context, transactionID string) error
}
```

### 2. Validation at ConfirmCheckout (Step 4)

Before payment authorization, validate the customer has enough points and the amount does not exceed the order total:

```go
if req.LoyaltyPointsToUse > 0 && uc.loyaltyService != nil {
    if err := uc.loyaltyService.ValidateRedemption(ctx, customerID, req.LoyaltyPointsToUse); err != nil {
        return nil, fmt.Errorf("loyalty point redemption invalid: %w", err)
    }
    // Apply loyalty discount to totals.TotalAmount
}
```

### 3. Deduction After Order Creation (Step 9, alongside ApplyPromotion)

Use the same parallel + DLQ pattern as promotions:

```go
if req.LoyaltyPointsToUse > 0 && uc.loyaltyService != nil {
    txID, deductErr := uc.loyaltyService.DeductPoints(ctx, customerID, req.LoyaltyPointsToUse, createdOrder.ID)
    if deductErr != nil {
        // Write FailedCompensation DLQ with operation_type='deduct_loyalty_points'
        // DLQRetryWorker picks it up and retries or escalates
    }
}
```

### 4. Compensation on Order Cancellation

The order service's compensation saga (or DLQ worker) must call `ReverseDeduction` when an order is cancelled after points have been deducted.

## Risk Assessment

- **No risk to existing flow** — the field is already stored but simply ignored at redemption time.
- **Customer impact** — customers see the `loyalty_points_to_use` field in the checkout session but points are never actually deducted, creating a UX discrepancy.
- **Revenue impact** — Low (customers can't currently redeem points), but blocks the loyalty programme launch.

## Acceptance Criteria

- [ ] Checkout validates loyalty point balance before authorizing payment
- [ ] Points deducted atomically after successful order creation (DLQ-backed)
- [ ] Points reversed automatically on order cancellation
- [ ] Loyalty redemption amount reflected in `discount_total` in the order totals
- [ ] Integration test: full checkout with loyalty point redemption

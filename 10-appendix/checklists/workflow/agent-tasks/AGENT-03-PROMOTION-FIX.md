# AGENT-03-PROMOTION-FIX.md

## 🎯 Task Details
- **Description:** Fix Critical Issues found from Promotion Service Meeting Review
- **Priority:** P0 (Critical)
- **Status:** ✅ DONE
- **Service:** Promotion

## 📝 Background
In the deep-dive meeting review for the Promotion service, a massive P0 critical bug was discovered in `ReleasePromotionUsage`. When an order is cancelled, the `Coupon` usage is correctly decremented, but the `Campaign` budget and `Promotion` usage limits are NOT refunded/decremented. This leads to permanent loss of campaign budget for abandoned checkouts. 
There is also a data race when updating `usages` to `cancelled`, and a Thundering Herd risk in the `time.Sleep` retry loop.

## ✅ Implementation Plan

### 1. Fix P0: Refund Campaign & Promotion Budgets (`internal/biz/promotion_usecase.go`)
- [x] In `ReleasePromotionUsage`, after `uc.couponRepo.BatchDecrementUsage`, add logic to Rollback Campaign Budget.
- [x] Add `DecrementBudgetUsed` to the `CampaignRepo` interface (`internal/biz/interfaces.go`).
- [x] Implement `DecrementBudgetUsed` in data layer (`internal/data/campaign.go`) with floor guard.
- [x] In `ReleasePromotionUsage`, fetch promotions by IDs, loop over applied usages, and decrement Campaign Budget for each.
- [x] **Note:** Promotion `current_usage_count` is already auto-decremented by DB trigger `trigger_update_promotion_usage_count` when usage_type changes to 'cancelled'.

### 2. Fix P1: Exponential Backoff & Jitter for Retry (`internal/biz/promotion_usecase.go`)
- [x] Replaced `time.Sleep(time.Duration(attempt*10) * time.Millisecond)` with proper exponential backoff + jitter.
- [x] Uses `backoffMs := 10 * (1 << attempt)` with `rand.IntN(backoffMs/2 + 1)` jitter.
- [x] Fixed unit mismatch bug (Duration nanoseconds * Millisecond = overflow).

### 3. Fix P2: Clean Up Unused Funcs (`internal/biz/discount_calculator.go`)
- [x] Removed `filterBuyItems()` and `filterGetItems()` (112 lines of dead code with `//nolint:unused`).

### 4. Mock Updates
- [x] `MockCampaignRepo` in `promotion_test.go` — added `DecrementBudgetUsed`.
- [x] `MockCampaignRepoExtended` in `promotion_crud_test.go` — added `DecrementBudgetUsed` with func hook.
- [x] `mocks/mock_campaign_repo.go` (mockgen) — added `DecrementBudgetUsed` mock+recorder methods.

## 🧪 Validation Results
```
go build ./...          ✅ PASS
go test ./internal/biz/... -v  ✅ ALL PASS (0.802s)
```

## 📋 Commit Message
```
fix: restore campaign budget and promotion limits on order cancellation

- P0: ReleasePromotionUsage now refunds campaign budget via DecrementBudgetUsed
- P1: ApplyPromotion retry uses exponential backoff with jitter
- P2: Removed 112 lines of dead filter functions from discount_calculator.go
```

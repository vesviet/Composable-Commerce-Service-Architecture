# Cart & Checkout Flows - Logic Review Checklist

## 1. Data Consistency Between Services
- [ ] **Price Consistency**: Cart totals are calculated by querying the `Pricing Service` synchronously (`CalculateOrderTotals`). Prices are re-validated during `ConfirmCheckout` to ensure no mismatch between cart page and checkout page.
- [ ] **Stock Consistency**: Stock is logically assured upfront, but definitely reserved just-in-time in `ConfirmCheckout` using `warehouseInventoryService.ReserveStockWithTTL`.
- [ ] **Promo Consistency**: Coupon lock mechanism (`acquireCouponLocks` using Redis SETNX) prevents double-spending of single-use coupons concurrently.

## 2. Data Mismatches (Potential Issues)
- [x] **Guest to User Merge**: Guest carts need to be correctly merged to user carts upon login. `cart/merge.go` should handle this.
- [x] **Currency & Metadata Fallbacks**: `extractCurrency` handles missing currency explicitly, falling back to `constants.DefaultCurrency` to avoid crashes.
- [x] **Cart Ownership & Security**: `GetCart` correctly ensures a guest cannot load a registered user's cart, and a user cannot load another user's cart.

## 3. Retry or Rollback (Saga/Outbox & Event Publishing)
- [ ] **SAGA (Rollback)**: Implemented correctly in `ConfirmCheckout`. If `createOrder` fails, SAGA-001 triggers:
  - `RollbackReservationsMap` to release warehouse stock locks.
  - `paymentService.VoidAuthorization` to void the authorized payment.
  - If voiding fails, it saves to `FailedCompensation` DLQ for async retry.
- [ ] **Outbox Pattern**: `finalizeOrderAndCleanup` uses the outbox for `CartConverted` event. Fail-Fast transaction is used.
- [ ] **Are events necessary?**: 
  - `CartConverted` is necessary for Data Analytics, Marketing flags, and order follow-up.

## 4. Logic Risks (Edge Cases) Unhandled
- [ ] **Best-effort Promo Usage**: Applying promo usage (`promotionService.ApplyPromotion`) is best-effort. If it fails, the order succeeds, and it retries via DLQ. This is fail-open.
- [ ] **Coupon Lock TTL vs Payment Auth**: Coupon Lock TTL is 10 minutes, `TryAcquire` lock on cart checkout is 15 mins. There is a potential timing gap if payment auth takes very long.
- [x] **Abandoned Carts**: `RefreshCart` isn't called proactively. Need a cron job / worker to clean up inactive/stale checked-out carts.

## 5. Event Subscriptions & Consumers
- [x] **Does Checkout need to subscribe to events?**: Currently, checkout doesn't subscribe to `product.updated` or `stock.changed`. It fetches pricing directly via gRPC during `RefreshCart` and validation. This is correct as on-demand validation avoids complex data sync out-of-band and consumer lag issues.
- [x] Worker consumers: Checkout does not need Kafka/Dapr subscribers for main business logic flow.

## 6. GitOps Configuration
- [x] Review `gitops/apps/checkout/overlays/dev/kustomization.yaml` to ensure any workers or cronjobs (for cleanup and DLQ retry) are correctly configured.

## 7. Events, Consumers, Cron Jobs on Worker
- [x] **Cron Job:** Needs a cron job to process `FailedCompensation` table (for voiding payments and applying promos that failed synchronously).
- [x] **Cron Job:** Needs an `Outbox Worker` to relay `CartConverted` events from DB to Event Bus.
- [x] **Cron Job:** Needs `Cart Cleanup` cron for stale sessions.

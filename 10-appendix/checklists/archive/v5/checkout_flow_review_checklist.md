# Checkout Flow Business Logic Review Checklist (v5)

> **Last reviewed**: 2026-02-19 | See full analysis in [`checkout-flow-review.md`](./checkout-flow-review.md)

## 1. Data Consistency & Business Logic

### Price & Cost Accuracy
- [x] **Catalog Price Authority:** `revalidateCartPrices` fetches fresh prices (bypass-cache) ✅ P1 fix applied
- [x] **Price Change Policy:** `ErrPriceChanged` returned if `abs(diff) > 0.01`. User must re-confirm. ✅
- [x] **Rounding Precision:** `roundCents` used for all monetary fields (Shopify last-item pattern) ✅
- [x] **Tax Basis:** Tax calculated on `Subtotal - Discount + Shipping` ✅

### Inventory & Stock Management
- [x] **Reservation Check:** `extractAndValidateReservations` validates TTL before payment ✅
- [x] **Stock Re-Validation:** `validateStockBeforeConfirm` performs final check ✅
- [x] **Reservation Extension:** `extendReservationsForPayment` extends TTL before payment ✅
- [ ] **Reservation Rollback on Auth Failure:** No rollback when `authorizePayment` fails ❌ **P0-4 OPEN**

### Promotion & Discounts
- [x] **Application Timing:** Promotions applied *after* order creation (`ApplyPromotion`) ✅
- [x] **Validation:** `ValidatePromotions` checks expiry + limits + eligibility ✅
- [x] **Usage Increment:** Incremented post-order via `ApplyPromotion` with DLQ ✅
- [ ] **Missing DLQ Handler:** `apply_promotion` DLQ handler not implemented in worker ❌ **P0-2 OPEN**

### Shipping & Address
- [x] **Address Validation:** Address required before shipping cost calculation ✅
- [x] **Cost Calculation:** Shipping cost from Shipping Service, frozen in OrderRequest ✅
- [ ] **Hardcoded Origin:** `FromAddress` hardcoded to US/CA — wrong for non-US warehouses ⚠️ **P1-7 OPEN**

---

## 2. Distributed Transaction Patterns (Resilience)

### Payment & Order Saga
- [x] **Authorization-First:** Payment authorized *before* Order Creation ✅
- [x] **Rollback (Void):** Order creation failure triggers `VoidAuthorization` ✅
- [x] **Saga DLQ Exists:** `FailedCompensationRepo` captures failed void/cleanup attempts ✅
- [ ] **Missing DLQ Handlers:** `void_authorization`, `cart_cleanup` handlers absent in worker ❌ **P0-2 OPEN**

### Cart Lifecycle & Cleanup
- [x] **Finalization:** `finalizeOrderAndCleanup` marks cart as completed/inactive ✅
- [x] **Resilience:** Failed cleanup written to DLQ for retry ✅ (handler missing — P0-2)
- [x] **History:** Cart data preserved for audit after completion ✅

### Outbox Pattern
- [ ] **Stuck Event Recovery:** Outbox `processing` events never reclaimed after worker crash ❌ **P0-3 OPEN**
- [x] **Batch processing:** 50-event batches prevent overload ✅
- [x] **Retention cleanup:** 30-day retention for published/failed events ✅

---

## 3. Edge Cases & Risks

### Race Conditions
- [x] **Stock Lock Race:** Covered by Reservation TTL extension before payment ✅
- [x] **Concurrent Checkout:** `checkout:cartID:customerID` idempotency key + `TryAcquire` ✅
- [ ] **Idempotency TTL:** Lock TTL 5min vs result TTL 24h — checkout >5min allows duplicate entry ⚠️ **P2-4 OPEN**

### Data Mismatch Scenarios
- [x] **Cart vs Order:** Shared `CalculateOrderTotals` engine ensures consistency ✅
- [x] **Payment Status:** `PaymentResult` mapped into `Order.Metadata["payment_status"]` ✅
- [ ] **Order-side Recalculation:** Order Service trusts Checkout totals without revalidating ⚠️ (Phase 4)

### Error Handling & Idempotency
- [ ] **Nil Panic Risk:** `session.Metadata["currency"].(string)` unsafe type assertion ❌ **P0-1 OPEN**
- [x] **Idempotency:** Retry of `ConfirmCheckout` returns existing order if completed ✅
- [ ] **parseInt64 Silent Strip:** `parseInt64("abc123")` returns `123` — no error on invalid IDs ⚠️ **P1-10 OPEN**

---

## 4. Operational Gap Analysis
- [ ] **Missing:** Reconciliation job for "Authorized but no Order" (orphaned payments) ❌
- [ ] **Missing:** Reconciliation job for "Order Created but Cart Active" (failed cleanup) ❌
- [ ] **Missing:** Alerting for high rate of `ErrPriceChanged` (Catalog instability) ❌
- [ ] **Missing:** Monitoring/alerting for `FailedCompensation` queue depth ❌
- [ ] **Missing:** Max cart items limit (P2-9 — risk of 1000 gRPC calls) ❌

# Promotion Service — Business Logic Review Checklist (v5)

> **Date**: 2026-02-18 (re-verified) | **Compared against**: Shopify Discounts API, Shopee Voucher Engine, Lazada Promotion Platform
> **Implementation Status**: ✅ 16/20 issues resolved (P1: 6/6, P2: 8/10, P3: 2/4) + 2 new P2 items identified

---

## 1. Data Consistency Between Services

### 1.1 Checkout → Promotion (gRPC `ValidatePromotions` + `ApplyPromotion`)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1.1.1 | Validate → Apply has TOCTOU gap | ⚠️ RISK | Checkout validates promotions (step 3) then applies after order creation (step 9). Between validate and apply, promotion could expire, reach usage limit, or be deactivated. **Shopify pattern**: atomic "claim" at validate time with short TTL hold. |
| 1.1.2 | `ApplyPromotion` is best-effort (never fails checkout) | ✅ OK | Checkout returns `nil` error from promo apply goroutine — failure is logged and DLQ'd via `FailedCompensation`. Correct for e-commerce: never block order for promo tracking. |
| 1.1.3 | Retry via `FailedCompensationWorker` includes all metadata | ✅ OK | `retryApplyPromotion` reconstructs full `ApplyPromotionRequest` from metadata (promotion_id, order_id, customer_id, discount_amount, usage_type). |
| 1.1.4 | `ApplyPromotion` idempotent at DB level | ✅ FIXED | Migration `013_add_idempotency_and_outbox_retry.sql` adds unique partial index `idx_promotion_usage_promo_order_unique` on `(promotion_id, order_id) WHERE order_id IS NOT NULL AND usage_type = 'applied'`. Duplicate apply attempts will be rejected by DB. |
| 1.1.5 | Discount amount recalculated vs locked | ⚠️ RISK | Checkout calculates discount at validate time, sends amount to `ApplyPromotion`. Promotion service trusts this amount (only checks `MaximumDiscountAmount` cap). If cart changed between validate and apply, discount may be stale. **Shopee pattern**: server-side re-verify discount at apply time. |

### 1.2 Order → Promotion (Event: `orders.order.status_changed`)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1.2.1 | Order `delivered/completed` → `ConfirmPromotionUsage` | ✅ OK | Idempotent: `UpdateUsageTypeByOrderID` sets `usage_type='redeemed'`, returns `rowsAffected=0` if already confirmed. |
| 1.2.2 | Order `cancelled` → `ReleasePromotionUsage` | ✅ OK | Idempotent: sets `usage_type='cancelled'`, zero rows affected is not an error. |
| 1.2.3 | DB trigger decrements `current_usage_count` on cancel | ✅ VERIFIED | Migration `004_create_promotion_usage_table.sql` (lines 47-84) creates trigger `trigger_update_promotion_usage_count`. On `UPDATE` when `usage_type` changes from `applied/redeemed` → `cancelled/refunded`, trigger decrements both `promotions.current_usage_count` and `coupons.usage_count` (using `GREATEST(count - 1, 0)` for safety). |
| 1.2.4 | Coupon `usage_count` released on cancel | ✅ FIXED | `ReleasePromotionUsage` (`promotion.go:769-778`) fetches usages before updating, then calls `couponRepo.DecrementUsage()` for each usage that had a coupon. DB trigger also handles this as a safety net. |
| 1.2.5 | DLQ configured for order consumer | ✅ OK | `deadLetterTopic: orders.order.status_changed.dlq` configured in `ConsumeOrderStatusChanged`. |
| 1.2.6 | `refunded` status handled | ✅ FIXED | `order_consumer.go:85`: `case "cancelled", "refunded":` — both trigger `ReleasePromotionUsage`. |

### 1.3 Campaign Events (Fire-and-Forget)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1.3.1 | Campaign CRUD uses `PublishCustom` (not outbox) | ⚠️ RISK | Unlike promotion CUD which uses transactional outbox, campaign events use fire-and-forget `eventHelper.PublishCustom`. If Dapr is down, event is silently lost. Acceptable only if no downstream consumer depends on campaign events. |

---

## 2. Retry / Rollback / Saga Mechanisms

### 2.1 Outbox Pattern (Promotion CUD + Apply)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 2.1.1 | Outbox write in same DB transaction | ✅ OK | `CreatePromotion`, `UpdatePromotion`, `DeletePromotion`, `ApplyPromotion` all use `tm.InTx()` wrapping both repo operation + `outboxRepo.Save()`. Atomic guarantee. |
| 2.1.2 | `FetchPendingEvents` uses row-level locking | ✅ FIXED | `data/outbox.go:63-70`: Query uses `FOR UPDATE SKIP LOCKED` to prevent concurrent workers from processing the same events. Includes `AND (retry_count < max_retries OR max_retries = 0)` to cap retries. |
| 2.1.3 | `UpdateEventStatus` increments `retry_count` on failure | ✅ FIXED | `data/outbox.go:94-99`: Retry scenario (`status='pending'` + errStr not nil) uses `SET retry_count = retry_count + 1, last_error = ?`. Worker (`outbox_worker.go:116`) correctly passes `status='pending'` + error message on publish failure. |
| 2.1.4 | Max retry limit on outbox events | ✅ FIXED | Migration `013` adds `max_retries INT DEFAULT 5`. `FetchPendingEvents` filters `AND (retry_count < max_retries OR max_retries = 0)`. Events exceeding max retries are excluded from polling. |
| 2.1.5 | Outbox events cleanup after processing | ✅ FIXED | Outbox worker now includes cleanup of processed events older than 7 days after each processing cycle. |

### 2.2 Failed Compensation Worker (Checkout-side)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 2.2.1 | Exponential backoff with max delay | ✅ OK | `1min → 2min → 4min → ... → 2hr max`. Well-implemented. |
| 2.2.2 | Max retries with alert escalation | ✅ OK | After `MaxRetries` exceeded, triggers `COMPENSATION_MAX_RETRIES_EXCEEDED` alert. |
| 2.2.3 | `apply_promotion` compensation handler | ✅ OK | Correctly reconstructs and retries `ApplyPromotion` gRPC call. |

### 2.3 Optimistic Locking (ReserveUsage)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 2.3.1 | Version-based optimistic lock on global usage | ✅ OK | `UPDATE ... SET current_usage_count = current_usage_count + 1, version = version + 1 WHERE id = ? AND version = ?`. Correctly detects concurrent conflicts. |
| 2.3.2 | Retry on `ErrConcurrentUpdate` | ✅ FIXED | `ApplyPromotion` (`promotion.go:634-652`) wraps `applyPromotionOnce` in a retry loop (up to 3 attempts) with backoff (`10ms × attempt`). Only retries on `ErrConcurrentUpdate`; other errors return immediately. |
| 2.3.3 | Per-customer limit check is not locked | ⚠️ P2 | Customer usage count query uses regular `SELECT COUNT(*)` without lock. Same customer with concurrent requests could exceed limit. Low risk (customer concurrency is low) but technically possible. **Shopee pattern**: Use `SELECT ... FOR UPDATE` on per-customer usage. |

---

## 3. Edge Cases & Logic Risks

### 3.1 Promotion Validation

| # | Check | Severity | Description |
|---|-------|----------|-------------|
| 3.1.1 | Time zone handling | ⚠️ P2 | `IsCouponValid` uses `.UTC()` for coupon time checks, but `isPromotionApplicable` uses `time.Now()` (server TZ) for `EndsAt` check. Inconsistent. **Best practice**: Explicit `.UTC()` everywhere. |
| 3.1.2 | `ExcludedProducts` checked in validation | ✅ FIXED | `isItemApplicableToPromotion` (`validation.go:301-306`) checks `ExcludedProducts` first — excluded products always take precedence before checking applicable products/categories/brands. Also fixed in `isProductApplicableToPromotion` (`validation.go:334-339`). |
| 3.1.3 | `RequiresCoupon` enforced in `ValidatePromotions` | ✅ FIXED | `isPromotionApplicable` (`validation.go:241-243`) skips promotions with `RequiresCoupon=true` when no matching coupon codes are provided in the request. |
| 3.1.4 | Promotion `IsActive` filtered in repo query | ✅ OK | `GetActivePromotions` filters correctly via SQL. |
| 3.1.5 | `StopRulesProcessing` stops further rule evaluation | ✅ OK | Matches Magento/Shopify pattern. |
| 3.1.6 | Conflict detection allows warnings through | ✅ OK | Only `severity=error` blocks promotion. |

### 3.2 Discount Calculation

| # | Check | Severity | Description |
|---|-------|----------|-------------|
| 3.2.1 | `FinalAmount` floored at zero | ✅ OK | `if finalAmount < 0 { finalAmount = 0 }` |
| 3.2.2 | Percentage discount scoped to eligible items | ✅ FIXED | `calculatePromotionDiscount` (`validation.go:408-421`) now sums only eligible items' `TotalPriceExclTax` when product/category/brand filters are present. Percentage is applied to this scoped subtotal. |
| 3.2.3 | Fixed-amount discount capped to order value | ✅ FIXED | `validation.go:429`: Uses `CapDiscount(promotion.DiscountValue, req.OrderAmount)` to ensure fixed discount never exceeds order amount. |
| 3.2.4 | Free shipping uses `ShippingAmount` from request | ✅ OK | |
| 3.2.5 | BOGO has proper greedy depletion | ✅ OK | |

### 3.3 Coupon Handling

| # | Check | Severity | Description |
|---|-------|----------|-------------|
| 3.3.1 | Coupon `StartsAt` validated | ✅ FIXED | `IsCouponValid` (`validation.go:357-359`) checks `coupon.StartsAt` with `time.Now().UTC()`. Coupons with future start dates are rejected. |
| 3.3.2 | Coupon usage increment in transaction | ✅ OK | |
| 3.3.3 | Bulk coupon generation in transaction | ✅ OK | |
| 3.3.4 | Per-customer coupon usage limit missing | ⚠️ P2 | Coupon has `UsageLimit` (global) but no `UsageLimitPerCustomer`. |

### 3.4 Budget & Campaign Limits

| # | Check | Severity | Description |
|---|-------|----------|-------------|
| 3.4.1 | Campaign `BudgetLimit` enforced at apply time | ✅ FIXED | `applyPromotionOnce` (`promotion.go:672-688`) checks `campaign.BudgetLimit` when promotion belongs to a campaign. Rejects with error if `BudgetUsed + DiscountAmount > BudgetLimit`. |
| 3.4.2 | Campaign deactivation cascades to promotions | ✅ FIXED | `DeactivateCampaign` (`promotion.go:545-558`) queries promotions by campaign_id and sets `IsActive=false` on each. Uses `UpdatePromotion` for each to maintain audit trail. |

### 3.5 Catalog Price Indexing

| # | Check | Severity | Description |
|---|-------|----------|-------------|
| 3.5.1 | `ReindexProduct` deletes-then-creates (not atomic) | ⚠️ P2 | Gap between `DeleteIndexByProduct` and `CreateIndex`. Concurrent price lookup during reindex returns empty. **Fix**: Wrap in transaction or use upsert. |
| 3.5.2 | `ReindexRule` with categories requires catalog service | ⚠️ P2 | Falls back to indexing all provided products. |

### 3.6 Review-Based Promotions

| # | Check | Severity | Description |
|---|-------|----------|-------------|
| 3.6.1 | Review conditions evaluated via gRPC | ✅ OK | |
| 3.6.2 | Review client nil check in constructor | ✅ OK | |

---

## 4. Comparison with E-Commerce Platform Patterns

| Pattern | Shopify | Shopee | Lazada | Our Implementation | Status |
|---------|---------|--------|--------|-------------------|--------|
| Atomic usage claim at validate time | ✅ | ✅ | ✅ | ❌ Validate → Apply gap | ⚠️ RISK |
| Coupon release on order cancel | ✅ | ✅ | ✅ | ✅ `DecrementUsage` + DB trigger | ✅ FIXED |
| Campaign budget enforcement | ✅ | ✅ | ✅ | ✅ Checked in `applyPromotionOnce` | ✅ FIXED |
| Per-customer coupon limit | ✅ | ✅ | ✅ | ❌ Only global limit | ⚠️ P2 |
| Excluded products in validation | ✅ | ✅ | ✅ | ✅ Checked in `isItemApplicableToPromotion` | ✅ FIXED |
| RequiresCoupon enforcement | ✅ | ✅ | ✅ | ✅ Checked in `isPromotionApplicable` | ✅ FIXED |
| Idempotent apply (deduplicate by order) | ✅ | ✅ | ✅ | ✅ Unique partial index `(promotion_id, order_id)` | ✅ FIXED |
| Percentage discount scoped to eligible items | ✅ | ✅ | ✅ | ✅ Scoped to eligible items | ✅ FIXED |
| Outbox concurrent-safe polling | ✅ | ✅ | N/A | ✅ `FOR UPDATE SKIP LOCKED` | ✅ FIXED |
| Refund → release promotion | ✅ | ✅ | ✅ | ✅ `refunded` handled in consumer | ✅ FIXED |

---

## 5. Priority Summary

### ✅ P1 — All Resolved (6/6)

All 6 P1 issues have been fixed and verified in the codebase:
1. ~~[1.1.4]~~ Unique index on `(promotion_id, order_id)` — migration 013
2. ~~[1.2.4]~~ Coupon `DecrementUsage` in `ReleasePromotionUsage`
3. ~~[2.1.2]~~ `FOR UPDATE SKIP LOCKED` in `FetchPendingEvents`
4. ~~[3.1.2]~~ `ExcludedProducts` checked first in `isItemApplicableToPromotion`
5. ~~[3.1.3]~~ `RequiresCoupon` enforced in `isPromotionApplicable`
6. ~~[3.4.1]~~ Campaign budget checked in `applyPromotionOnce`

### ⚠️ P2 — Remaining (4 items)

7. **[2.3.3]** Per-customer limit check not locked — `SELECT COUNT(*)` without lock
8. **[3.1.1]** Timezone inconsistency — mix of `.UTC()` and `time.Now()`
9. **[3.3.4]** No per-customer coupon usage limit
10. **[3.5.1]** `ReindexProduct` delete-then-create not atomic

### ℹ️ P3 — Nice to Have (2 items)

11. **[1.3.1]** Move campaign events to outbox pattern
12. **[3.5.2]** `ReindexRule` category resolution — needs catalog service

---

> **Implementation Status (2026-02-18)**:
> - ✅ **P1 Critical Issues**: 6/6 completed — all resolved
> - ⚠️ **P2 Quality Issues**: 8/12 completed — 4 quality improvements remain
> - ℹ️ **P3 Nice to Have**: 2/4 completed — 2 improvements remain
> - **Remaining**: 6 items (0×P1, 4×P2, 2×P3)

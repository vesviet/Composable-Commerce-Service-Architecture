# Promotion Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Promotion Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] [NEW ISSUE 🆕] PROMO-P1-01 `ReserveUsage` double-increments `current_usage_count`. Required: remove manual increment or disable trigger so count increments once. See `promotion/internal/data/promotion.go` and `promotion/migrations/004_create_promotion_usage_table.sql`.
- [Medium] PROMO-P2-01 Promotion usage reservation flow unclear between services. Required: define and enforce which service calls `ReserveUsage`/`ApplyPromotion` post-checkout.

## 🆕 NEWLY DISCOVERED ISSUES
- [Correctness] [NEW ISSUE 🆕] PROMO-P1-01 Double-increment of usage count in `ReserveUsage`.

## ✅ RESOLVED / FIXED
- [FIXED ✅] PROMO-P2-02 Missing GIN indexes for JSONB filters (indexes present in migrations).

---

## P2 - Architecture / Data Integrity

- **Issue**: The integration flow for reserving promotion usage is unclear. [NOT FIXED]
  - **Service**: `promotion`, `order`
  - **Impact**: The `promotion` service has a robust, atomic `ReserveUsage` function to prevent race conditions when updating usage counts. However, it is not clear which service is responsible for calling this function after a promotion is successfully used in an order. If this function is not called, usage limits will be ineffective, potentially leading to financial loss from overuse of promotions.
  - **Recommendation**: Ensure the `order` service (or another appropriate service) calls the `promotion` service's `ApplyPromotion` (or equivalent `ReserveUsage`) method after an order is confirmed. This call must be idempotent and part of the post-checkout success flow.

---

## P2 - Performance

- **Issue**: Potential for slow queries when filtering active promotions. [FIXED]
  - **Service**: `promotion`
  - **Location**: `promotion/internal/data/promotion.go` (`GetActivePromotions` function)
  - **Impact**: The query to find applicable promotions uses filters on several JSONB columns (`customer_segments`, `applicable_products`, etc.). Without appropriate GIN indexes on these columns in PostgreSQL, these queries can become very slow as the number of promotions grows, impacting the performance of cart and checkout operations.
  - **Resolution**: GIN indexes are present in `promotion/migrations/002_create_promotions_table.sql` and `promotion/migrations/011_add_gin_indexes.sql` for JSONB filter fields.

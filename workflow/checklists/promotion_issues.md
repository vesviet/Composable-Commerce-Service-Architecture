# Promotion Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Promotion Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P2 - Architecture / Data Integrity

- **Issue**: The integration flow for reserving promotion usage is unclear.
  - **Service**: `promotion`, `order`
  - **Impact**: The `promotion` service has a robust, atomic `ReserveUsage` function to prevent race conditions when updating usage counts. However, it is not clear which service is responsible for calling this function after a promotion is successfully used in an order. If this function is not called, usage limits will be ineffective, potentially leading to financial loss from overuse of promotions.
  - **Recommendation**: Ensure the `order` service (or another appropriate service) calls the `promotion` service's `ApplyPromotion` (or equivalent `ReserveUsage`) method after an order is confirmed. This call must be idempotent and part of the post-checkout success flow.

---

## P2 - Performance

- **Issue**: Potential for slow queries when filtering active promotions.
  - **Service**: `promotion`
  - **Location**: `promotion/internal/data/promotion.go` (`GetActivePromotions` function)
  - **Impact**: The query to find applicable promotions uses filters on several JSONB columns (`customer_segments`, `applicable_products`, etc.). Without appropriate GIN indexes on these columns in PostgreSQL, these queries can become very slow as the number of promotions grows, impacting the performance of cart and checkout operations.
  - **Recommendation**: Verify that the database migration scripts for the `promotions` table create GIN indexes on all JSONB columns that are used in `WHERE` clauses.

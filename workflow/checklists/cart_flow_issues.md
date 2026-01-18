# Cart Management Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Cart Management Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P1 - Concurrency / Data Integrity

- **Issue**: Cart item updates are not atomic and are vulnerable to race conditions.
  - **Service**: `order`
  - **Location**: `order/internal/biz/cart/add.go`, `order/internal/biz/cart/update.go`
  - **Impact**: The `Read-Then-Write` pattern is used without locking, which can lead to incorrect cart quantities and totals under concurrent requests.
  - **Recommendation**: Implement optimistic locking with a `version` field on the `cart_items` table. The `UPDATE` query should check `WHERE version = ?` and the application should retry the logic if the version has changed.

---

## P1/P2 - Resilience / Correctness

- **Issue**: Cart totals calculation has silent failures.
  - **Service**: `order`
  - **Location**: `order/internal/biz/cart/totals.go`
  - **Impact**: When calls to dependent services (shipping, promotion, tax) fail, the logic logs a warning and continues with a default value of `0`. This can lead to incorrect pricing and compliance/revenue risks (especially for tax, which is a P1 risk).
  - **Recommendation**: For critical dependencies like Tax, the calculation should fail fast and return an error. For non-critical dependencies like promotions, the current behavior might be acceptable but should be explicitly monitored.

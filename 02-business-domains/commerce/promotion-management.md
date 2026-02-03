# Promotion & Coupon Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code
**Domain**: Commerce
**Service**: Promotion Service

## Overview

This document describes the business logic for validating and applying promotions within the `promotion` service. The architecture correctly separates the read-only validation logic from the write-intensive usage reservation logic to ensure both performance and data integrity.

**Key Files:**
- **Usecase**: `promotion/internal/biz/promotion.go`
- **Data/Repo**: `promotion/internal/data/promotion.go`
- **Key Pattern**: Separation of Read (Validation) and Write (Reservation), Transactional Outbox.

---

## Key Flows

### 1. Promotion Validation Flow (Read-Only)

This flow is designed to be a safe, read-only check to determine which promotions are applicable to a given context (e.g., a shopping cart).

- **Function**: `ValidatePromotions`
- **Logic**:
  1.  Fetches all active promotions that match the context (customer segments, products, etc.).
  2.  Sorts the promotions by priority.
  3.  For each promotion, it checks applicability (`isPromotionApplicable`):
      - Verifies conditions like minimum order amount.
      - **Checks usage limits** (`TotalUsageLimit`, `UsageLimitPerCustomer`) against currently recorded usage counts.
  4.  It calculates the potential discount for all valid promotions.
  5.  It handles stacking logic, applying either all `stackable` promotions or only the single best `non-stackable` promotion.
  6.  **Crucially, this flow does not modify any state.** It does not increment usage counts.

### 2. Promotion Usage Reservation Flow (Write)

This is the critical, state-changing flow that commits the usage of a promotion. It is designed to be atomic and safe from race conditions.

- **Function**: `ReserveUsage` (exposed via the repository, called by the usecase's `ApplyPromotion`)
- **Logic**:
  1.  **Database Transaction**: The entire operation is wrapped in a database transaction.
  2.  **Pessimistic Locking**: It immediately acquires a row-level lock on the specific promotion record using `SELECT ... FOR UPDATE`. This prevents any other concurrent requests from modifying this promotion until the transaction is complete.
  3.  **Re-validation**: Inside the transaction, it re-checks the `TotalUsageLimit` and `UsageLimitPerCustomer` to ensure the promotion is still valid at the moment of reservation.
  4.  **Atomic Increment**: It atomically increments the `current_usage_count` in the database using `gorm.Expr("current_usage_count + 1")`.
  5.  **Audit Record**: It creates a `PromotionUsage` record to log the specific instance of the promotion being used (e.g., for which order, customer).
  6.  **Commit/Rollback**: The transaction is committed. If any step fails, the entire operation is rolled back.

### 3. Event Publishing Flow

All state changes (create, update, apply) are published reliably using the Transactional Outbox pattern.

- **Logic**:
  1.  Inside the main database transaction (e.g., in `CreatePromotion` or `ApplyPromotion`), an event record is written to the `outbox` table.
  2.  This ensures that the event is only queued if the business logic was successfully committed to the database.
  3.  A separate background worker is responsible for reading from the outbox and publishing the events to the message bus.

---

## Identified Issues & Gaps

### P2 - Architecture: Unclear Integration Flow

- **Issue**: The `promotion` service provides a robust, atomic `ReserveUsage` function, but it is not clear which service is responsible for calling it, or when. The `order` service is seen calling `ValidatePromotions`, but the corresponding call to `ReserveUsage` (e.g., after an order is confirmed) is not apparent from the reviewed code.
- **Impact**: If `ReserveUsage` is never called, the promotion usage counts will never be updated. This would render all usage limits (`TotalUsageLimit`, `UsageLimitPerCustomer`) ineffective, potentially leading to significant financial loss if promotions are overused.
- **Recommendation**: The end-to-end checkout flow in the `order` service must be updated to explicitly call the `promotion` service's `ApplyPromotion` (or equivalent) method after an order is successfully created and payment is confirmed. This call must be idempotent.

### P2 - Performance: JSONB Query Indexing

- **Issue**: The `GetActivePromotions` query uses JSONB operators (`@>`) to filter promotions by customer segments, products, categories, and brands.
- **Location**: `promotion/internal/data/promotion.go`
- **Impact**: While flexible, these queries can be slow on large datasets if the corresponding JSONB columns (`customer_segments`, `applicable_products`, etc.) are not indexed using GIN indexes in PostgreSQL.
- **Recommendation**: Verify that the database migration scripts for the `promotions` table include the creation of GIN indexes on all JSONB columns that are used for filtering.

# Promotion & Coupon Flow

**Last Updated**: 2026-11-25
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

### 2. Promotion Usage Reservation Flow (Write — Two-Phase TTL)

This is the critical, state-changing flow that reserves and commits promotion usage across checkout without overdrafts or permanent orphaned locks:

- **Functions**: `ReservePromotion`, `ConfirmPromotionReservation`, `ReleasePromotionReservation` (plus background `ReservationCleanupWorker`)
- **Logic**:
  1.  **Reserve during Checkout (`ReservePromotion`)**: Inside a database transaction with `SELECT ... FOR UPDATE`, re-validates limits and inserts a `promotion_usage` row in `'reserved'` status bound to `checkout_session_id` with `reservation_expires_at`.
  2.  **Confirm on Order Creation (`ConfirmPromotionReservation`)**: Transitions reserved rows to `'confirmed'` when `CreateOrderStep` completes and atomically commits `current_usage_count`.
  3.  **Release / Expire (`ReleasePromotionReservation` / `ReservationCleanupWorker`)**: Releases reserved rows immediately on pre-order checkout rollback, or marks expired `'reserved'` rows as `'expired'` after TTL expiry and publishes `promotion.usage_confirmed` / `promotion.release_failed` via Transactional Outbox.

### 3. Event Publishing Flow

All state changes (create, update, apply) are published reliably using the Transactional Outbox pattern.

- **Logic**:
  1.  Inside the main database transaction (e.g., in `CreatePromotion` or `ApplyPromotion`), an event record is written to the `outbox` table.
  2.  This ensures that the event is only queued if the business logic was successfully committed to the database.
  3.  A separate background worker is responsible for reading from the outbox and publishing the events to the message bus.

---

## Identified Issues & Gaps

### P2 - Performance: JSONB Query Indexing (Verify GIN Coverage)

- **Issue**: Active promotion filtering uses JSONB containment queries (`@>`) for customer segments, products, categories, and brands.
- **Location**: `promotion/internal/data/promotion.go`
- **Status**: ✅ Usage reservation lifecycle resolved via `ReservePromotion` / `ConfirmPromotionReservation` / `ReleasePromotionReservation` + `checkout` `ReservePromotionsStep` & `CreateOrderStep`. Retain GIN index verification on JSONB filter columns as ongoing performance hygiene.

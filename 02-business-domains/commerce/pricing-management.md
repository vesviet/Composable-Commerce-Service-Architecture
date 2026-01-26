# Pricing Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code
**Domain**: Commerce
**Service**: Pricing Service

## Overview

This document describes the business logic for price calculation and management within the `pricing` service. This service acts as the central authority for determining the price of a product, orchestrating several layers of logic including base prices, dynamic adjustments, rules, and taxes.

**Key Files:**
- **Orchestrator**: `pricing/internal/biz/calculation/calculation.go`
- **Base Price Logic**: `pricing/internal/biz/price/price.go`
- **Price Rules Logic**: `pricing/internal/biz/rule/rule.go`
- **Tax Logic**: `pricing/internal/biz/tax/tax.go`

---

## Key Flows

### 1. Price Calculation Flow

This is the primary read-only flow, designed as a multi-step waterfall to arrive at a final price.

- **Function**: `CalculatePrice` in `calculation.go`
- **Logic Sequence**:
  1.  **Cache Check**: The system first checks a Redis cache for a previously calculated result for the exact same request context.
  2.  **Base Price Retrieval**: On a cache miss, it fetches the base price using a robust 4-level priority fallback system:
      -   1. SKU + Warehouse ID (most specific)
      -   2. SKU Global (any warehouse)
      -   3. Product ID + Warehouse ID
      -   4. Product ID Global (least specific)
      -   It also handles on-the-fly currency conversion if a price is found in a different currency.
  3.  **Quantity Application**: The base/sale price is multiplied by the requested quantity.
  4.  **Dynamic Pricing**: The total is passed to a `dynamicPricing` service, which can make adjustments based on real-time factors like stock levels or demand.
  5.  **Price Rules**: The adjusted price is then processed by the price rule engine. It fetches all active rules, sorts them by priority, and applies their actions (e.g., percentage discount, fixed amount) if their conditions are met.
  6.  **Discount Application**: The code explicitly notes that coupon/promotion discounts have been moved to the `promotion` service and are **not** handled here.
  7.  **Tax Calculation**: The final taxable amount is passed to the `taxUsecase` to calculate and add tax.
  8.  **Cache & Event**: The final result is cached for future requests, and a `price.calculated` event is published.

### 2. Price Management Flow (Create/Update/Delete)

This flow handles the CRUD operations for the base price records that feed into the calculation flow.

- **File**: `price.go`
- **Logic**:
  1.  Standard CRUD operations are provided (`CreatePrice`, `UpdatePrice`, `DeletePrice`).
  2.  **Side Effects**: Upon any successful write operation, two side effects are triggered:
      -   **Cache Invalidation**: Relevant Redis cache keys are invalidated to prevent stale data.
      -   **Event Publishing**: An event (`price.updated` or `price.deleted`) is published to notify downstream services (like `search`) of the change.

---

## Identified Issues & Gaps

Based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

### P1 - Concurrency: Unmanaged Goroutine

- **Issue**: The `CreatePrice` and `UpdatePrice` functions launch a detached, unmanaged goroutine (`go func()`) to trigger a price sync in the `catalog` service.
- **Impact**: This violates the guide's rule against unmanaged goroutines. If the sync fails, the error is only logged and not retried. The request completes without any guarantee that the side effect was successful.
- **Recommendation**: This direct sync call should be removed. The `catalog` service should instead be a consumer of the `price.updated` event, which is published more reliably (though still with its own issues, see below).

### P2 - Event Reliability: Missing Transactional Outbox

- **Issue**: The event publishing in `price.go` is a direct call made *after* the database operation. It does not use the Transactional Outbox pattern.
- **Impact**: If the application crashes between the database commit and the event publishing call, the event will be lost permanently. This leads to data inconsistency, as downstream services like `search` will never be notified of the price change.
- **Recommendation**: Refactor all event publishing in the `pricing` service to use the Transactional Outbox pattern. The event should be written to an `outbox` table within the same database transaction as the price change itself.

### P2 - Resilience: Silent Failures in Calculation

- **Issue**: The `CalculatePrice` function in `calculation.go` handles errors from `dynamicPricing` and `applyPriceRules` by logging them and continuing with the last known price. 
- **Impact**: While this makes the API more resilient to partial failures, it can hide significant underlying problems with configuration or dependent services, leading to incorrect prices being calculated without raising an alarm.
- **Recommendation**: While failing fast might not be desirable, these silent failures should be made louder. At a minimum, they should generate high-priority metrics and alerts so that the operations team is immediately aware of a degradation in the pricing engine.

# Pricing Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Pricing Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P1 - Concurrency

- **Issue**: Unmanaged goroutine used for a critical side effect.
  - **Service**: `pricing`
  - **Location**: `pricing/internal/biz/price/price.go` (`CreatePrice`, `UpdatePrice` functions)
  - **Impact**: A detached goroutine (`go func()`) is used to trigger a price sync in the `catalog` service. This violates the guide's rule against unmanaged goroutines. If the sync fails, the error is only logged and not retried, and the request completes without any guarantee that the side effect was successful. This can lead to price inconsistencies between services.
  - **Recommendation**: This direct, asynchronous call should be removed. The `catalog` service should instead be a reliable consumer of the `price.updated` event.

---

## P2 - Event Reliability

- **Issue**: Event publishing does not use the Transactional Outbox pattern.
  - **Service**: `pricing`
  - **Location**: `pricing/internal/biz/price/price.go`
  - **Impact**: Events (`price.updated`, `price.deleted`) are published in a separate step after the database transaction has committed. If the application crashes between the commit and the event publishing call, the event will be lost permanently. This leads to data inconsistency, as downstream services like `search` will never be notified of the price change.
  - **Recommendation**: Refactor all event publishing in the `pricing` service to use the Transactional Outbox pattern. The event should be written to an `outbox` table within the same database transaction as the price change itself.

---

## P2 - Resilience / Observability

- **Issue**: Silent failures in the price calculation waterfall.
  - **Service**: `pricing`
  - **Location**: `pricing/internal/biz/calculation/calculation.go` (`CalculatePrice` function)
  - **Impact**: The function handles errors from `dynamicPricing` and `applyPriceRules` by logging them and continuing with the last known price. While this makes the API more resilient, it can hide significant underlying problems with configuration or dependent services, leading to incorrect prices being calculated without raising an alarm.
  - **Recommendation**: These silent failures should generate high-priority metrics and alerts (e.g., a counter for `price_calculation_fallback_used`). This makes the operations team immediately aware of a degradation in the pricing engine without failing the entire request.

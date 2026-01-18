# Shipping Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Shipping Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P1 - Event Reliability

- **Issue**: Inconsistent use of the Transactional Outbox pattern.
  - **Service**: `shipping`
  - **Location**: `shipping/internal/biz/shipment/shipment_usecase.go`
  - **Impact**: While critical flows like `CreateShipment` and `UpdateShipmentStatus` correctly write events to an outbox for reliable delivery, other methods like `UpdateShipment` and `AddTrackingEvent` publish events directly to the event bus. This creates a risk of lost events if the service crashes after the database commit but before the event is published, leading to data inconsistencies in downstream services like `order`.
  - **Recommendation**: Refactor all methods that publish events to consistently use the Transactional Outbox pattern. All state changes should result in an event being written to the `outbox` table within the same database transaction.

---

## P2 - Correctness / Architecture

- **Issue**: The `processing` status for an order has an ambiguous source of truth.
  - **Services**: `order`, `shipping`, `fulfillment`
  - **Location**: `order/internal/service/event_handler.go`
  - **Impact**: The `order` service can set an order's status to `processing` based on events from both the `fulfillment` service (e.g., when picking starts) and the `shipping` service (when a shipment is created). This can cause race conditions, redundant updates, and makes it difficult to determine the true state of the order fulfillment process.
  - **Recommendation**: Define a single, authoritative event that triggers the `processing` status. A good candidate is the first event from the `fulfillment` service (e.g., `fulfillment.status_changed` to `planning`). The `shipment.created` event could then be used to transition the order to a more specific status like `ready_to_ship` or directly to `shipped`.

---

## P2 - Resilience

- **Issue**: External API calls to carriers for rate calculation are not wrapped in a circuit breaker.
  - **Service**: `shipping`
  - **Location**: `shipping/internal/biz/shipping_method/carrier_rate.go` (and specific carrier implementations)
  - **Impact**: If a third-party carrier's API becomes slow or unresponsive, the repeated, synchronous calls from the `shipping` service can exhaust its own resources (e.g., connection pool, goroutines). This could cause a cascading failure where the entire rate calculation system becomes unavailable, preventing customers from checking out.
  - **Recommendation**: Wrap all external API calls to carriers in a circuit breaker. This will allow the system to fail fast, stop sending requests to an unhealthy dependency, and give it time to recover, thus protecting the `shipping` service from cascading failures.

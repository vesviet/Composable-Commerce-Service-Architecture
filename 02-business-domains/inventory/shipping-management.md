# Shipping Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code
**Domain**: Inventory
**Service**: Shipping Service

## Overview

This document describes the two primary responsibilities of the `shipping` service: calculating shipping rates for carts/checkouts and managing the lifecycle of a shipment after an order is fulfilled.

**Key Files:**
- **Rate Calculation**: `shipping/internal/biz/shipping_method/rate_calculation.go`
- **Shipment Management**: `shipping/internal/biz/shipment/shipment_usecase.go`
- **Event Publishing**: `shipping/internal/biz/shipment/events.go`
- **Event Consumption**: `order/internal/service/event_handler.go`

---

## Key Flows

### 1. Rate Calculation Flow

This flow is called by services like `order` (during checkout) to get available shipping options and their costs.

- **Function**: `CalculateRates` in `rate_calculation.go`
- **Logic**:
  1.  **Cache Check**: The system first checks a Redis cache for a result matching the exact order info (destination, items, etc.).
  2.  **Fetch Methods**: On a cache miss, it fetches all enabled `ShippingMethod`s from the database.
  3.  **Dispatching**: It iterates through each method and calls a specific calculation logic based on the method's `Type`:
      -   `flat_rate`: Returns a fixed rate from the method's configuration.
      -   `free`: Returns a rate of 0 if the order meets a configured `min_order_amount`.
      -   `table_rate`: Looks up the rate from a pre-defined table based on order weight, amount, or item count.
      -   `carrier`: This is for real-time rates. It uses a `carrierFactory` to get a specific carrier's implementation (e.g., an adapter for GHTK's API) and calls its `CalculateRate` method.
  4.  **Resilience**: The main `CalculateRates` function has a simple retry loop. If calculating the rate for one method fails (e.g., a carrier API times out), it logs the error and continues to calculate rates for the other available methods.
  5.  **Caching**: The final list of calculated rates is stored in the Redis cache for subsequent identical requests.

### 2. Shipment Lifecycle & Event Flow

This flow begins after the `fulfillment` service has packed an order and is ready to ship it.

- **Function**: `CreateShipment` in `shipment_usecase.go`
- **Logic**:
  1.  The `shipping` service receives a request to create a shipment, including details like order ID, fulfillment ID, and carrier.
  2.  A new `Shipment` record is created in the database with a `draft` status.
  3.  **Transactional Outbox**: Within the same database transaction, a `shipment.created` event is written to the `outbox` table. This guarantees that the event will be published if, and only if, the shipment record was successfully created.
  4.  **Status Updates**: As the shipment progresses (e.g., a tracking number is added, the status changes to `shipped` or `delivered`), the `UpdateShipmentStatus` function is called. This function also uses the Transactional Outbox to reliably publish `shipment.status_changed` events.
  5.  **Event Consumption**: The `order` service listens for these events:
      -   On `shipment.created`, it updates the order status to `processing`.
      -   On `delivery.confirmed` (which is triggered by a `shipment.status_changed` event with status `delivered`), it updates the order status to `delivered`.

---

## Identified Issues & Gaps

### P1 - Event Reliability: Inconsistent Use of Transactional Outbox

- **Issue**: While `CreateShipment` and `UpdateShipmentStatus` correctly use the Transactional Outbox pattern, other methods like `UpdateShipment` and `AddTrackingEvent` publish events directly to the event bus.
- **Impact**: This inconsistency creates a risk of lost events. If the service crashes after the database update but before the direct event publish call completes, the change will never be communicated to other services like `order`.
- **Recommendation**: Refactor all event-publishing methods in `shipment_usecase.go` to use the Transactional Outbox pattern (`save...Event`) to ensure guaranteed, reliable event delivery for all state changes.

### P2 - Correctness: Ambiguous `processing` Status Trigger

- **Issue**: The `order`'s `processing` status can be set by events from both the `fulfillment` service (e.g., when picking starts) and the `shipping` service (when the shipment is created).
- **Impact**: This creates a potential race condition and makes the source of truth for the `processing` status ambiguous. It can also lead to redundant or out-of-order status updates.
- **Recommendation**: Define a single, authoritative source for the `processing` status. A good candidate would be the first `fulfillment.status_changed` event (e.g., `planning` or `picking`). The `shipment.created` event should perhaps transition the order to a more specific status like `ready_to_ship` or directly to `shipped`.

### P2 - Resilience: Missing Circuit Breaker for Carrier APIs

- **Issue**: The `calculateCarrierRate` logic calls external carrier APIs but does not appear to be wrapped in a circuit breaker.
- **Impact**: If a third-party carrier's API becomes slow or unresponsive, the repeated calls from the `shipping` service can exhaust its own resources (e.g., connection pool, goroutines), potentially causing a cascading failure that impacts all rate calculations.
- **Recommendation**: Wrap all external API calls within the carrier-specific implementations in a circuit breaker. This will allow the system to fail fast, stop sending requests to an unhealthy dependency, and recover quickly once the external API is stable again.

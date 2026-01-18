# Order Fulfillment & Tracking Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Order Fulfillment & Tracking Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P1/P2 - Correctness / Semantics

- **Issue**: Semantic conflict between `fulfillment.completed` and `order.delivered`.
  - **Services**: `order`, `fulfillment`
  - **Location**: `order/internal/service/event_handler.go` (`mapFulfillmentStatusToOrderStatus` function)
  - **Impact**: The `order` service currently maps `fulfillment.completed` to `order.delivered`. This is likely incorrect, as "delivered" implies the customer has received the item, which is information that should originate from the `shipping` service. This creates a race condition with the `delivery.confirmed` event and can lead to inaccurate order tracking for the customer.
  - **Recommendation**: Change the mapping. `fulfillment.completed` should not change the order status to `delivered`. The `delivered` status should only be set by an event from the `shipping` service.

---

## P1 - Resilience / Observability

- **Issue**: Event handler in `order` service silently ignores status update errors.
  - **Service**: `order`
  - **Location**: `order/internal/service/event_handler.go` (`HandleFulfillmentStatusChanged`)
  - **Impact**: The handler is designed to `return nil` even if updating the order status fails. While this prevents a poison message from blocking the queue, it hides critical errors. Without a Dead-Letter Queue (DLQ) and associated alerting, these failures can lead to silent data inconsistencies between `order` and `fulfillment` states.
  - **Recommendation**: Enhance the event handler to push failing messages to a DLQ and trigger a high-priority alert for manual investigation.

---

## P2 - Event Reliability

- **Issue**: The `fulfillment` service does not use the Transactional Outbox pattern for publishing events.
  - **Service**: `fulfillment`
  - **Location**: `fulfillment/internal/biz/fulfillment/fulfillment.go` (e.g., in `CreateFromOrderMulti`)
  - **Impact**: Events are published *after* the database transaction commits. If the service crashes between the commit and the publish, the event is lost, and downstream services like `order` will not receive the status update.
  - **Recommendation**: Refactor the event publishing logic in the `fulfillment` service to use the same Transactional Outbox pattern implemented in the `order` service. This ensures that an event is guaranteed to be sent if, and only if, the business transaction was successful.

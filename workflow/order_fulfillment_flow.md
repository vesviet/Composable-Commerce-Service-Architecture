# Order Fulfillment & Tracking Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code

## Overview

This document describes the event-driven workflow between the `order` and `fulfillment` services, which handles order processing from confirmation to completion. The flow ensures that order status is kept in sync with the physical fulfillment process.

**Key Services & Files:**
- **Order Service**:
  - `order/internal/service/event_handler.go`: Consumes events from other services.
  - `order/internal/biz/status/status.go`: Manages order status transitions and publishes events.
- **Fulfillment Service**:
  - `fulfillment/internal/biz/fulfillment/fulfillment.go`: Core fulfillment logic.
  - `fulfillment/internal/biz/fulfillment/order_status_handler.go`: Consumes order events.

---

## Core Workflows

### 1. Flow Initiation: Order Confirmed → Fulfillment Created

This flow starts when an order is ready to be processed by the warehouse.

1.  **Order Confirmed**: An order's status is updated to `confirmed` in the `order` service (typically after successful payment).
2.  **Event Published**: The `order` service's `StatusUsecase` publishes an `order.status_changed` event. This is done via the Transactional Outbox pattern, ensuring the event is sent reliably.
3.  **Event Consumed**: The `fulfillment` service listens for this topic. Its `order_status_handler.go` processes the event.
4.  **Fulfillment Created**: The handler calls `CreateFromOrderMulti`, which creates one or more `Fulfillment` records (one for each warehouse involved in the order).
5.  **Planning Started**: Immediately after creation, `StartPlanning` is called for each new fulfillment, which assigns a warehouse if needed and moves the status to `planning`.
6.  **Fulfillment Event Published**: The `fulfillment` service then publishes its own `fulfillment.status_changed` event to notify other services that the fulfillment process has begun.

### 2. Internal Fulfillment Lifecycle

Once created, a fulfillment record moves through a detailed status machine within the `fulfillment` service.

-   **Status Machine**: `pending` → `planning` → `picking` → `picked` → `packing` → `packed` → `ready` → `shipped` → `completed`.
-   **Atomicity**: Each status transition is wrapped in a database transaction (`tx.InTx(...)`) to ensure atomicity.
-   **Event-Driven**: Every successful status change publishes a `fulfillment.status_changed` event, allowing other services to react to the fulfillment progress in real-time.

### 3. Synchronization: Fulfillment Status → Order Status

This flow keeps the customer-facing order status updated based on the internal warehouse progress.

1.  **Event Consumed**: The `order` service's `event_handler.go` subscribes to and processes `fulfillment.status_changed` events.
2.  **Status Mapping**: The `HandleFulfillmentStatusChanged` function uses a mapping (`mapFulfillmentStatusToOrderStatus`) to translate the detailed fulfillment status into a more general order status:
    -   `planning`, `picking`, `picked`, `packing`, `packed`, `ready` → **`processing`**
    -   `shipped` → **`shipped`**
    -   `completed` → **`delivered`**
    -   `cancelled` → **`cancelled`**
3.  **State Guard**: A `shouldSkipStatusUpdate` function prevents the order status from regressing (e.g., moving from `shipped` back to `processing`).

---

## Identified Issues & Gaps

Based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

### P1/P2 - Semantics: `fulfillment.completed` vs `order.delivered`

- **Issue**: The `order` service maps the `fulfillment.completed` status to `order.delivered`. This is a potential semantic conflict.
- **Impact**: `fulfillment.completed` signifies the warehouse has finished its process. `order.delivered` implies the customer has received the package, which is information that should come from the `shipping` service (e.g., from a carrier webhook). This creates ambiguity and a potential race condition, as the `order` service also listens for a `delivery.confirmed` event.
- **Recommendation**: Change the mapping. `fulfillment.completed` should perhaps trigger no status change on the order, or a new internal status. The `order.delivered` status should **only** be set by an event from the `shipping` service, such as `delivery.confirmed`.

### P1 - Resilience: Silent Error Handling in Event Consumer

- **Issue**: The `HandleFulfillmentStatusChanged` handler in the `order` service intentionally ignores errors (`return nil`) when it fails to update an order's status.
- **Impact**: While this prevents a poison message from blocking the event queue, it hides underlying issues (e.g., invalid status transitions, database problems) that could lead to data inconsistency. These failures are only logged and not sent to a Dead-Letter Queue (DLQ) for reprocessing or alerting.
- **Recommendation**: Enhance the handler to push failing messages to a DLQ and trigger a high-priority alert for manual investigation.

### P2 - Event Reliability: Missing Transactional Outbox in Fulfillment

- **Issue**: The `fulfillment` service publishes events *after* the database transaction commits. A `TODO` in the code confirms this needs to be moved to the Transactional Outbox pattern.
- **Impact**: If the service crashes between the DB commit and the event publish, the event is lost, and downstream services (like `order`) will not be updated.
- **Recommendation**: Refactor the event publishing logic in the `fulfillment` service to use the same Transactional Outbox pattern that the `order` service uses.

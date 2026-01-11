# Order Event Reference (orders.*)

## Purpose
Trace reference for **Order-domain published events** (`orders.*`) and their downstream consumers, plus DLQ/Retry behavior.

## Publisher (Source of Truth)
- **Service**: `order`
- **Topic constants**: `order/internal/constants/constants.go`
- **Publisher wrapper**: `order/internal/events/publisher.go`
- **Payload structs**: `order/internal/events/order_events.go`

## Published Topics

### `orders.order.status_changed`
- **What**: Unified order lifecycle event (created/confirmed/processing/shipped/delivered/cancelled/refunded/failed)
- **Payload**: `events.OrderStatusChangedEvent`
  - Defined in: `order/internal/events/order_events.go`
- **Producer trace**:
  - `order/internal/events/publisher.go` → `PublishOrderStatusChanged(...)`

**Primary consumers (observed in code/config)**:
- **Warehouse worker**
  - Subscription: `warehouse/internal/data/eventbus/order_status_consumer.go`
- **Notification worker**
  - Subscription: `notification/internal/data/eventbus/order_status_consumer.go`
- **Fulfillment**
  - Event model present: `fulfillment/internal/observer/event/order_status_changed.go`
  - Topic configured via values/config (see `argocd/applications/main/fulfillment/values-base.yaml`)

**DLQ / Retry**:
- No explicit `dlq.orders.*` topics found in codebase.
- Consumer services above do not implement an orders.*-specific DLQ layer (based on grep for `dlq.orders` / `DLQTopic*orders*`).
- Operational retries depend on:
  - Dapr pub/sub delivery retry behavior
  - handler robustness/logging

### `orders.return.requested`
- **Payload**: `events.ReturnRequestedEvent` (`order/internal/events/order_events.go`)
- **Producer trace**: `order/internal/events/publisher.go` → `PublishReturnRequested(...)`
- **DLQ / Retry**: No `dlq.orders.*` found.

### `orders.return.approved`
- **Payload**: `events.ReturnApprovedEvent`
- **Producer trace**: `order/internal/events/publisher.go` → `PublishReturnApproved(...)`
- **DLQ / Retry**: No `dlq.orders.*` found.

### `orders.return.rejected`
- **Payload**: `events.ReturnRejectedEvent`
- **Producer trace**: `order/internal/events/publisher.go` → `PublishReturnRejected(...)`
- **DLQ / Retry**: No `dlq.orders.*` found.

### `orders.return.completed`
- **Payload**: `events.ReturnCompletedEvent`
- **Producer trace**: `order/internal/events/publisher.go` → `PublishReturnCompleted(...)`

**Primary consumers (observed in code/config)**:
- **Warehouse worker**
  - Subscription: `warehouse/internal/data/eventbus/return_consumer.go` (topic default: `orders.return.completed`)

**DLQ / Retry**: No `dlq.orders.*` found.

### `orders.exchange.requested`
- **Payload**: `events.ExchangeRequestedEvent`
- **Producer trace**: `order/internal/events/publisher.go` → `PublishExchangeRequested(...)`
- **DLQ / Retry**: No `dlq.orders.*` found.

### `orders.exchange.approved`
- **Payload**: `events.ExchangeApprovedEvent`
- **Producer trace**: `order/internal/events/publisher.go` → `PublishExchangeApproved(...)`
- **DLQ / Retry**: No `dlq.orders.*` found.

### `orders.exchange.completed`
- **Payload**: `events.ExchangeCompletedEvent`
- **Producer trace**: `order/internal/events/publisher.go` → `PublishExchangeCompleted(...)`
- **DLQ / Retry**: No `dlq.orders.*` found.

## Important Note: Order service DLQ is for **Inbound** events (not orders.*)
Order service implements a DB-based DLQ for failures while processing **inbound** events (from payment/shipping/fulfillment):

- **DLQ storage**: `order/migrations/017_create_failed_events_table.sql`
- **Save-to-DLQ logic**: `order/internal/service/event_helpers.go` (`saveToDLQ(...)`)
- **DLQ admin endpoints**: registered in `order/internal/server/http.go`
  - `/api/v1/admin/dlq/events`
  - `/api/v1/admin/dlq/events/get?id={id}`
  - `/api/v1/admin/dlq/events/retry?id={id}`
  - `/api/v1/admin/dlq/events/delete?id={id}`
- **DLQ handler**: `order/internal/service/dlq_handler.go`

This is separate from any topic-based DLQ (e.g., `dlq.orders.*`), which is currently not implemented.

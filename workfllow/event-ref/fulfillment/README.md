# Fulfillment Event Reference (fulfillments.* / picklists.* / packages.*)

## Purpose
Trace reference for **Fulfillment-domain published events** and their downstream consumers, plus DLQ/Retry behavior.

## Publisher (Source of Truth)
- **Service**: `fulfillment`
- **Topic constants**: `fulfillment/internal/constants/event_topics.go`
- **Publisher implementation**: `fulfillment/internal/events/publisher.go`
- **Payload structs**:
  - `fulfillment/internal/events/fulfillment_events.go`
  - `fulfillment/internal/events/picklist_events.go`
  - `fulfillment/internal/events/package_events.go`

## Published Topics

### `fulfillments.fulfillment.status_changed`
- **What**: Unified fulfillment lifecycle event (pending → planning → picking → picked → packing → packed → ready → shipped → completed/cancelled)
- **Payload (Go type)**: `events.FulfillmentStatusChangedEvent`
  - Defined in: `fulfillment/internal/events/fulfillment_events.go`
- **Producer trace**:
  - `fulfillment/internal/events/publisher.go` → `PublishFulfillmentStatusChanged(...)`
  - Main call sites (biz): `fulfillment/internal/biz/fulfillment/fulfillment.go` (multiple transitions call `uc.eventPub.PublishFulfillmentStatusChanged(...)`)

**Primary consumers (observed in code/config)**:
- **Order service (inbound subscription)**
  - Order subscribes via Dapr HTTP subscription list:
    - `order/internal/service/event_handler.go` includes `constants.TopicFulfillmentStatusChanged` → route `/events/fulfillment-status-changed`
  - Order constant: `order/internal/constants/constants.go` (`TopicFulfillmentStatusChanged = "fulfillments.fulfillment.status_changed"`)
- **Warehouse service**
  - Event model present: `warehouse/internal/observer/event/fulfillment_status_changed.go`
  - Topic configured via warehouse config/values:
    - `warehouse/configs/config.yaml` / `warehouse/configs/config-docker.yaml`
    - `argocd/applications/main/warehouse/values-base.yaml`

**DLQ / Retry**:
- No topic-based DLQ topics found for fulfillment topics:
  - No `dlq.fulfillments.*`, `dlq.picklists.*`, `dlq.packages.*` in codebase.
- Order service implements **DB-based DLQ for inbound events** (including this one):
  - Save-to-DLQ: `order/internal/service/event_helpers.go` (`saveToDLQ(...)`)
  - Admin endpoints: `order/internal/server/http.go` (`/api/v1/admin/dlq/events/*`)

### `picklists.picklist.status_changed`
- **What**: Unified picklist status changes
- **Payload (Go type)**: `events.PicklistStatusChangedEvent`
  - Defined in: `fulfillment/internal/events/picklist_events.go`
- **Producer trace**:
  - `fulfillment/internal/events/publisher.go` → `PublishPicklistStatusChanged(...)`

**Primary consumers (observed in code/config)**:
- Internal consumption within fulfillment/warehouse flows (event model present)
  - Event model: `fulfillment/internal/observer/event/picklist_status_changed.go`

**DLQ / Retry**:
- No topic-based DLQ topics found (`dlq.picklists.*` not present).

### `packages.package.status_changed`
- **What**: Unified package status changes
- **Payload (Go type)**: `events.PackageStatusChangedEvent`
  - Defined in: `fulfillment/internal/events/package_events.go`
- **Producer trace**:
  - `fulfillment/internal/events/publisher.go` → `PublishPackageStatusChanged(...)` / `PublishPackageStatusChangedWithItems(...)`

**Primary consumers (observed in code/config)**:
- **Shipping service**
  - Topic constant: `shipping/internal/constants/event_topics.go`
  - Event model present: `shipping/internal/observer/event/package_status_changed.go`
  - Topic configured via shipping config:
    - `shipping/configs/config.yaml` / `shipping/configs/config-docker.yaml`
    - `argocd/applications/main/shipping/values-base.yaml`

**DLQ / Retry**:
- No topic-based DLQ topics found (`dlq.packages.*` not present).

## Also published by Fulfillment (System error)
### `system.errors`
- **Publisher**: Fulfillment service publishes system errors for notification.
- **Producer trace**:
  - `fulfillment/internal/events/publisher.go` → `PublishFulfillmentError(...)`
  - Topic constant is `TopicSystemError` ("system.errors")

## Notes
- Per your request, searches/trace were done excluding `admin/` and `frontend/` (web apps).

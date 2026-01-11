# Warehouse Event Reference (warehouse.*)

## Purpose
Trace reference for **Warehouse-domain published events** and their downstream consumers, plus DLQ/Retry behavior.

> Per your request: this doc keeps the 3 canonical warehouse inventory topics in the reference (**B-mode**), even if some do not currently have confirmed publish call-sites.

## Publisher (Source of Truth)
- **Service**: `warehouse`
- **Publisher wrapper**: `warehouse/internal/biz/events/event_publisher.go` (`WarehouseEventPublisher.PublishEvent`)
- **Event payload types** (used by stock events): `warehouse/internal/biz/events/events.go`
  - `events.StockUpdatedEvent`

## Topics

### `warehouse.inventory.stock_changed`
- **Status**: **Confirmed published** (multiple call-sites)
- **Payload (Go type)**: `events.StockUpdatedEvent`
  - Defined in: `warehouse/internal/biz/events/events.go`
- **Producer trace (publish call-sites)**:
  - `warehouse/internal/biz/inventory/inventory.go` (publishes `warehouse.inventory.stock_changed`)
  - `warehouse/internal/biz/reservation/reservation.go` (publishes `warehouse.inventory.stock_changed`)
  - `warehouse/internal/worker/cron/stock_change_detector.go` (publishes `warehouse.inventory.stock_changed`)
- **Important note (trace)**:
  - These call-sites currently use **string literals** for the topic, not constants. When debugging, search for the literal `"warehouse.inventory.stock_changed"`.

**Primary consumers (observed in code/config)**:
- **Search service** (updates sellable view / indexes)
  - Topic constant: `search/internal/constants/event_topics.go` (`TopicWarehouseInventoryStockChanged`)
  - Consumer code: `search/internal/data/eventbus/stock_consumer.go`

**DLQ / Retry mapping**:
- Search implements a topic-based DLQ for this consumer:
  - DLQ topic: `dlq.warehouse.inventory.stock_changed` (`search/internal/constants/event_topics.go`)
  - DLQ handler: `search/internal/service/dlq_handler.go`
  - Retry handler: `search/internal/service/retry_handler.go`
  - HTTP trigger endpoint: `search/internal/server/http.go` → `/events/dlq/warehouse.inventory.stock_changed`

### `warehouse.inventory.reserved`
- **Status**: **Referenced in global event list, publish call-sites not yet confirmed in warehouse code**
- **Intended meaning**: Inventory reserved for an order/cart
- **Trace suggestion**:
  - Search for literal `"warehouse.inventory.reserved"` in `warehouse/internal`.
  - If implemented later, align payload fields with `events.StockUpdatedEvent` or introduce a dedicated `InventoryReservedEvent`.

**DLQ / Retry**:
- No topic-based DLQ found in codebase for `dlq.warehouse.inventory.reserved`.

### `warehouse.inventory.released`
- **Status**: **Referenced in global event list, publish call-sites not yet confirmed in warehouse code**
- **Intended meaning**: Inventory released (reservation cancelled/expired)
- **Trace suggestion**:
  - Search for literal `"warehouse.inventory.released"` in `warehouse/internal`.
  - If implemented later, align payload fields with `events.StockUpdatedEvent` or introduce a dedicated `InventoryReleasedEvent`.

**DLQ / Retry**:
- No topic-based DLQ found in codebase for `dlq.warehouse.inventory.released`.

## Notes
- This doc intentionally excludes `admin/` and `frontend/` (web) from search/tracing.
- For worker/runtime behavior (cron/consumers), see `warehouse/internal/worker/*`.

# Return Service

## Overview

The Return Service manages the full lifecycle of post-purchase return and exchange requests on the platform. It handles customer eligibility checks, return approval workflows, refund orchestration, inventory restocking, and return shipping label generation. The service supports two request types: **return** (refund to original payment method) and **exchange** (replace with a different product).

- **Port**: HTTP `8013`, gRPC `9013`
- **Dapr App ID**: `return`
- **Database**: PostgreSQL (`return_db`)
- **Module**: `gitlab.com/ta-microservices/return`

---

## Architecture

The service follows Clean Architecture with a single binary entry point (`cmd/return/`). Worker goroutines for the outbox relay and compensation retries run within the same process, registered via `internal/server/worker_server.go`.

```
cmd/return/           → Main binary (API + embedded workers)
internal/
  biz/return/         → Domain use-case layer (ReturnUsecase)
    return.go         → Core CRUD and eligibility logic
    refund.go         → Payment refund orchestration
    restock.go        → Warehouse inventory restocking
    exchange.go       → Exchange order creation via Order service
    shipping.go       → Return label generation via Shipping service
    validation.go     → Status transition guard and input validation
    events.go         → Event builders for all lifecycle events
  data/               → Repository implementations (GORM + common BaseRepository)
  service/            → gRPC/HTTP handler layer
  client/             → gRPC clients for Order, Payment, Shipping, Warehouse
  events/             → Dapr event publisher
  worker/             → OutboxWorker + CompensationWorker
  middleware/         → JWT extraction from Gateway headers
```

---

## Key Capabilities

### Return Eligibility
- Checks order status (`delivered` or `completed` required)
- Enforces 30-day return window from `order.CompletedAt` (fail-safe: denies if timestamp absent)
- Deduplicates active return requests per order (DB unique constraint + pre-check)

### Status Lifecycle
Valid transitions are strictly enforced:

```
pending → approved | rejected | cancelled
approved → processing | cancelled
processing → completed | cancelled
```

Terminal states (`rejected`, `completed`, `cancelled`) cannot transition further. Partial failures produce granular intermediate states (`refund_failed`, `restock_failed`).

### Refund Processing
- Calls Payment service gRPC with an idempotency key (`returnID:refund`) to prevent double-refund on retry
- Caps refund amount at order total
- On failure, saves `return.refund_retry` to outbox; `ReturnCompensationWorker` retries every 5 minutes

### Inventory Restocking
- Exchange returns are **not** restocked (the replacement order manages inventory separately)
- Standard returns restock only items marked `restockable = true` after inspection
- On failure, saves `return.restock_retry` to outbox for compensation-worker retry
- Warehouse ID is read from item-level metadata (populated at creation from order item data)

### Exchange Orders
- Calls Order service to create a replacement order with original pricing
- Records `ExchangeOrderID` on the return request for traceability

### Return Shipping Labels
- Labels are generated via Shipping service on approval
- Origin = customer's order shipping address (fetched from Order service)
- Destination = configured warehouse return address (`business.warehouse_return_address` in config)

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/v1/returns` | Create a return request |
| `GET` | `/v1/returns/{return_id}` | Get a return request |
| `GET` | `/v1/returns` | List returns for a customer |
| `POST` | `/v1/returns/{return_id}/approve` | Approve a return (admin) |
| `POST` | `/v1/returns/{return_id}/reject` | Reject a return (admin) |
| `POST` | `/v1/returns/{return_id}/receive` | Mark items as received |
| `POST` | `/v1/returns/{return_id}/refund` | Trigger refund (→ completed) |
| `POST` | `/v1/returns/{return_id}/cancel` | Cancel a return |
| `GET` | `/v1/returns/{order_id}/eligibility` | Check return eligibility |
| `POST` | `/v1/exchanges` | Create an exchange request |

Auth: `X-User-ID` header (injected by Gateway). Admin endpoints require `X-User-Roles: admin`.

---

## Events Published

| Event Type | Topic | Trigger |
|------------|-------|---------|
| `orders.return.requested` | Dapr pubsub | Return created |
| `orders.return.approved` | Dapr pubsub | Return approved by admin |
| `orders.return.rejected` | Dapr pubsub | Return rejected by admin |
| `orders.return.completed` | Dapr pubsub | Return fully processed |
| `orders.exchange.requested` | Dapr pubsub | Exchange created |
| `orders.exchange.order_created` | Dapr pubsub | Replacement order created |

All events are written via the transactional outbox pattern — the status save and outbox insert execute in the same DB transaction. The `OutboxWorker` relays pending events to Dapr. On outbox failure, a direct Dapr publish is attempted as a last resort.

---

## External Dependencies

| Service | Protocol | Purpose |
|---------|----------|---------|
| Order | gRPC | Fetch order/items, update order status, create exchange order |
| Payment | gRPC | Process refunds (with idempotency key) |
| Warehouse | gRPC | Restock returned items |
| Shipping | gRPC | Generate return shipping labels |

---

## Data Model

### `return_requests`
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `return_number` | VARCHAR | `RET-YYMM-000001` format, unique |
| `order_id` | UUID | FK to Orders |
| `customer_id` | UUID | FK to Customers |
| `return_type` | VARCHAR | `return` or `exchange` |
| `status` | VARCHAR | `pending`, `approved`, `rejected`, `processing`, `completed`, `cancelled`, `refund_failed`, `restock_failed` |
| `reason` | VARCHAR | Return reason code |
| `refund_amount` | DECIMAL | Total refund before restocking fee |
| `restocking_fee` | DECIMAL | Deducted from refund amount |
| `exchange_order_id` | UUID | Created replacement order (exchange only) |

### `return_items`
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `return_request_id` | UUID | FK to return_requests |
| `order_item_id` | BIGINT | FK to order items |
| `product_id` | VARCHAR | Denormalised from order |
| `quantity` | INT | Must not exceed original ordered quantity |
| `unit_price` | DECIMAL | Denormalised from order |
| `condition` | VARCHAR | Set during inspection: `new`, `like_new`, `used`, `damaged`, `defective` |
| `restockable` | BOOLEAN | Set during inspection |
| `metadata` | JSONB | Includes `warehouse_id` for restock routing |

---

## Configuration

Key `config.yaml` sections:

```yaml
server:
  http:
    addr: 0.0.0.0:8013
  grpc:
    addr: 0.0.0.0:9013

business:
  return_window: 720h              # 30 days
  auto_approve_limit: 100          # Auto-approve under this amount
  warehouse_return_address:        # Destination for return shipping labels
    street1: "123 Warehouse Road"
    city: "Logistics City"
    country: "US"
```

---

## Sequence Number Format

Return numbers use the `common/utils/sequence` PostgreSQL sequence generator:

```
RET-{YYMM}-{000001}   e.g. RET-2602-000042
```

Entity key: `return_request_{YYMM}` (resets monthly).

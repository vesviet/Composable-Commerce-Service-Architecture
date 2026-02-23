# Warehouse Service - Documentation Template

**Copy this template to create Warehouse Service documentation**

## Quick Start

```bash
cp templates/warehouse-service-template.md docs/services/warehouse-service.md
cp templates/service-openapi-template.yaml docs/openapi/warehouse.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/warehouse-service-runbook.md
```

## Service Information

- **Service Name:** Warehouse Service
- **HTTP Port:** 8009
- **gRPC Port:** 9009
- **Repository:** `warehouse/`
- **Bounded Context:** Inventory Management

## Key Responsibilities

- Inventory management (stock levels, locations)
- Stock movement tracking (inbound, outbound, transfers)
- Warehouse management
- Stock reservation
- Inventory reconciliation

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `warehouse.stock.updated` | `stock.updated` | Published when stock level changes |
| `warehouse.inventory.reserved` | `inventory.reserved` | Published when inventory is reserved |
| `warehouse.inventory.released` | `inventory.released` | Published when inventory reservation is released |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `order.order.created` | `order.created` | `HandleOrderCreated` | Reserve inventory |
| `order.order.cancelled` | `order.cancelled` | `HandleOrderCancelled` | Release inventory reservation |
| `fulfillment.fulfillment.completed` | `fulfillment.completed` | `HandleFulfillmentCompleted` | Deduct inventory |

## Key API Endpoints

- `GET /api/v1/inventory/{sku}` - Get stock level for SKU
- `POST /api/v1/inventory/reserve` - Reserve inventory
- `POST /api/v1/inventory/release` - Release inventory reservation
- `POST /api/v1/inventory/movement` - Record stock movement
- `GET /api/v1/warehouses` - List warehouses

## Database Tables

- `warehouses` - Warehouse records
- `inventory` - Stock levels per SKU per warehouse
- `stock_movements` - Stock movement history
- `inventory_reservations` - Active inventory reservations

## Dependencies

- **Catalog Service:** SKU information
- **Order Service:** Order information
- **Fulfillment Service:** Fulfillment information

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:8009
  grpc:
    addr: 0.0.0.0:9009

warehouse:
  defaultWarehouse: main-warehouse
  reservationTimeout: 15m

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: order.created
      route: /api/v1/events/order.created
    - pubsubName: pubsub-redis
      topic: order.cancelled
      route: /api/v1/events/order.cancelled
```


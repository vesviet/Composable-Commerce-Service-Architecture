# Fulfillment Service - Documentation Template

**Copy this template to create Fulfillment Service documentation**

## Quick Start

```bash
cp templates/fulfillment-service-template.md docs/services/fulfillment-service.md
cp templates/service-openapi-template.yaml docs/openapi/fulfillment.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/fulfillment-service-runbook.md
```

## Service Information

- **Service Name:** Fulfillment Service
- **HTTP Port:** {HTTP Port}
- **gRPC Port:** {gRPC Port}
- **Repository:** `fulfillment/`
- **Bounded Context:** Order Fulfillment

## Key Responsibilities

- Fulfillment order creation
- Picklist generation
- Packing and shipping preparation
- Fulfillment status tracking
- Batch processing

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `fulfillment.fulfillment.created` | `fulfillment.created` | Published when fulfillment is created |
| `fulfillment.fulfillment.completed` | `fulfillment.completed` | Published when fulfillment is completed |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `order.order.status_changed` | `order.status_changed` | `HandleOrderStatusChanged` | Create fulfillment when order is CONFIRMED |

## Key API Endpoints

- `POST /api/v1/fulfillments` - Create fulfillment
- `GET /api/v1/fulfillments/{id}` - Get fulfillment by ID
- `POST /api/v1/fulfillments/{id}/picklist` - Generate picklist
- `PUT /api/v1/fulfillments/{id}/complete` - Mark fulfillment as completed

## Database Tables

- `fulfillments` - Fulfillment records
- `picklists` - Picklist records
- `fulfillment_items` - Fulfillment line items

## Dependencies

- **Order Service:** Order information
- **Warehouse Service:** Inventory location
- **Shipping Service:** Shipment information

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:{http-port}
  grpc:
    addr: 0.0.0.0:{grpc-port}

fulfillment:
  batchSize: 100
  processingTimeout: 300s

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: order.status_changed
      route: /api/v1/events/order.status_changed
```


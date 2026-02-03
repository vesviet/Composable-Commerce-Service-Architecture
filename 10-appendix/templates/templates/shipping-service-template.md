# Shipping Service - Documentation Template

**Copy this template to create Shipping Service documentation**

## Quick Start

```bash
cp templates/shipping-service-template.md docs/services/shipping-service.md
cp templates/service-openapi-template.yaml docs/openapi/shipping.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/shipping-service-runbook.md
```

## Service Information

- **Service Name:** Shipping Service
- **HTTP Port:** 8006
- **gRPC Port:** 9006
- **Repository:** `shipping/`
- **Bounded Context:** Shipping & Fulfillment

## Key Responsibilities

- Shipment creation and management
- Carrier integration (FedEx, UPS, DHL, etc.)
- Shipping rate calculation
- Tracking updates
- Fulfillment coordination

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `shipping.shipment.created` | `shipment.created` | Published when shipment is created |
| `shipping.shipment.status_changed` | `shipment.status_changed` | Published when shipment status changes |
| `shipping.tracking.updated` | `tracking.updated` | Published when tracking information is updated |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `order.order.status_changed` | `order.status_changed` | `HandleOrderStatusChanged` | Create shipment when order is CONFIRMED |
| `fulfillment.fulfillment.completed` | `fulfillment.completed` | `HandleFulfillmentCompleted` | Update shipment status |

## Key API Endpoints

- `POST /api/v1/shipments` - Create shipment
- `GET /api/v1/shipments/{id}` - Get shipment by ID
- `GET /api/v1/shipments/{id}/tracking` - Get tracking information
- `POST /api/v1/shipments/rates` - Calculate shipping rates

## Database Tables

- `shipments` - Shipment records
- `carriers` - Carrier information
- `tracking_events` - Tracking event history

## Dependencies

- **Order Service:** Order information
- **Warehouse Service:** Inventory location
- **Fulfillment Service:** Fulfillment status
- **External:** Carrier APIs

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:8006
  grpc:
    addr: 0.0.0.0:9006

shipping:
  carriers:
    fedex:
      apiKey: ${FEDEX_API_KEY}
      accountNumber: ${FEDEX_ACCOUNT_NUMBER}
    ups:
      apiKey: ${UPS_API_KEY}
      accountNumber: ${UPS_ACCOUNT_NUMBER}

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: order.status_changed
      route: /api/v1/events/order.status_changed
```


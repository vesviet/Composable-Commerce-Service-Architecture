# Order Service - Documentation Template

**Copy this template to create Order Service documentation**

## Quick Start

```bash
cp templates/order-service-template.md docs/services/order-service.md
cp templates/service-openapi-template.yaml docs/openapi/order.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/order-service-runbook.md
```

## Service Information

- **Service Name:** Order Service
- **HTTP Port:** 8004
- **gRPC Port:** 9004
- **Repository:** `order/`
- **Bounded Context:** Order Management

## Key Responsibilities

- Order lifecycle management (create, update, cancel)
- Cart management (add items, checkout)
- Order status tracking
- Order history
- Order fulfillment coordination

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `order.order.created` | `order.created` | Published when a new order is created |
| `order.order.status_changed` | `order.status_changed` | Published when order status changes |
| `order.cart.item_added` | `cart.item_added` | Published when item is added to cart |
| `order.cart.checked_out` | `cart.checked_out` | Published when cart is checked out |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `payment.payment.processed` | `payment.processed` | `HandlePaymentProcessed` | Update order status to CONFIRMED |
| `payment.payment.failed` | `payment.failed` | `HandlePaymentFailed` | Cancel order |
| `warehouse.stock.updated` | `stock.updated` | `HandleStockUpdate` | Validate cart items availability |

## Key API Endpoints

- `POST /api/v1/orders` - Create order
- `GET /api/v1/orders/{id}` - Get order by ID
- `PUT /api/v1/orders/{id}/status` - Update order status
- `POST /api/v1/cart` - Add item to cart
- `GET /api/v1/cart` - Get cart contents
- `POST /api/v1/cart/checkout` - Checkout cart

## Database Tables

- `orders` - Order records
- `order_items` - Order line items
- `carts` - Shopping carts
- `cart_items` - Cart line items

## Dependencies

- **Catalog Service:** Product information
- **Pricing Service:** Price calculation
- **Warehouse Service:** Stock availability
- **Payment Service:** Payment processing
- **Customer Service:** Customer information

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:8004
  grpc:
    addr: 0.0.0.0:9004

data:
  database:
    source: host=postgres port=5432 user=order_user password=order_pass dbname=order_db
  redis:
    addr: redis:6379
    db: 4

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: payment.processed
      route: /api/v1/events/payment.processed
    - pubsubName: pubsub-redis
      topic: payment.failed
      route: /api/v1/events/payment.failed
    - pubsubName: pubsub-redis
      topic: stock.updated
      route: /api/v1/events/stock.updated
```


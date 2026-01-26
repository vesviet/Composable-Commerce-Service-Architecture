# Customer Service - Documentation Template

**Copy this template to create Customer Service documentation**

## Quick Start

```bash
cp templates/customer-service-template.md docs/services/customer-service.md
cp templates/service-openapi-template.yaml docs/openapi/customer.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/customer-service-runbook.md
```

## Service Information

- **Service Name:** Customer Service
- **HTTP Port:** 8007
- **gRPC Port:** 9007
- **Repository:** `customer/`
- **Bounded Context:** Customer Management

## Key Responsibilities

- Customer profile management
- Address management
- Customer segmentation
- Customer preferences
- Customer history

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `customer.customer.created` | `customer.created` | Published when a new customer is created |
| `customer.customer.updated` | `customer.updated` | Published when customer profile is updated |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `order.order.created` | `order.created` | `HandleOrderCreated` | Update customer order history |

## Key API Endpoints

- `GET /api/v1/customers/{id}` - Get customer by ID
- `POST /api/v1/customers` - Create customer
- `PUT /api/v1/customers/{id}` - Update customer
- `GET /api/v1/customers/{id}/addresses` - Get customer addresses
- `POST /api/v1/customers/{id}/addresses` - Add address

## Database Tables

- `customers` - Customer records
- `addresses` - Address records
- `customer_segments` - Customer segmentation

## Dependencies

- **Auth Service:** Customer authentication
- **Order Service:** Order history

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:8007
  grpc:
    addr: 0.0.0.0:9007

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: order.created
      route: /api/v1/events/order.created
```


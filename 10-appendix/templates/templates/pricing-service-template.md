# Pricing Service - Documentation Template

**Copy this template to create Pricing Service documentation**

## Quick Start

```bash
cp templates/pricing-service-template.md docs/services/pricing-service.md
cp templates/service-openapi-template.yaml docs/openapi/pricing.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/pricing-service-runbook.md
```

## Service Information

- **Service Name:** Pricing Service
- **HTTP Port:** 8002
- **gRPC Port:** 9002
- **Repository:** `pricing/`
- **Bounded Context:** Price Management

## Key Responsibilities

- Price calculation (base price, discounts, taxes)
- Price rules management
- Price synchronization with Catalog
- Multi-currency support
- Price history

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `pricing.price.updated` | `price.updated` | Published when price is updated |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `catalog.product.created` | `product.created` | `HandleProductCreated` | Create default price for new product |
| `promotion.promotion.applied` | `promotion.applied` | `HandlePromotionApplied` | Apply promotion to price |

## Key API Endpoints

- `GET /api/v1/prices/{sku}` - Get price for SKU
- `POST /api/v1/prices/calculate` - Calculate final price
- `PUT /api/v1/prices/{sku}` - Update price

## Database Tables

- `prices` - Price records
- `price_rules` - Price calculation rules
- `price_history` - Price change history

## Dependencies

- **Catalog Service:** Product/SKU information
- **Promotion Service:** Promotion rules

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:8002
  grpc:
    addr: 0.0.0.0:9002

pricing:
  defaultCurrency: USD
  cache:
    ttl: 300s

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: product.created
      route: /api/v1/events/product.created
```


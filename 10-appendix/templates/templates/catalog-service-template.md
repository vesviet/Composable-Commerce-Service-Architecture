# Catalog Service - Documentation Template

**Copy this template to create Catalog Service documentation**

## Quick Start

```bash
cp templates/catalog-service-template.md docs/services/catalog-service.md
cp templates/service-openapi-template.yaml docs/openapi/catalog.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/catalog-service-runbook.md
```

## Service Information

- **Service Name:** Catalog Service
- **HTTP Port:** 8001
- **gRPC Port:** 9001
- **Repository:** `catalog/`
- **Bounded Context:** Product Catalog

## Key Responsibilities

- Product management (CRUD operations)
- Category management
- Brand management
- Product search and filtering
- Product image management
- Stock status synchronization

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `catalog.product.created` | `product.created` | Published when a new product is created |
| `catalog.product.updated` | `product.updated` | Published when product is updated |
| `catalog.price.updated` | `price.updated` | Published when product price is updated (from Pricing Service) |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `warehouse.stock.updated` | `stock.updated` | `HandleStockUpdate` | Update product stock status |
| `pricing.price.updated` | `price.updated` | `HandlePriceUpdate` | Update product price in cache |

## Key API Endpoints

- `GET /api/v1/products` - List products
- `GET /api/v1/products/{id}` - Get product by ID
- `POST /api/v1/products` - Create product
- `PUT /api/v1/products/{id}` - Update product
- `GET /api/v1/categories` - List categories
- `GET /api/v1/brands` - List brands

## Database Tables

- `products` - Product records
- `categories` - Category records
- `brands` - Brand records
- `product_images` - Product image records

## Dependencies

- **Warehouse Service:** Stock information
- **Pricing Service:** Price information
- **Search Service:** Product search indexing

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:8001
  grpc:
    addr: 0.0.0.0:9001

catalog:
  cache:
    ttl: 3600s
  gatewayCache:
    db: 0

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: stock.updated
      route: /api/v1/events/stock.updated
    - pubsubName: pubsub-redis
      topic: price.updated
      route: /api/v1/events/price.updated
```


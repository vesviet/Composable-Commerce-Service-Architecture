# Microservices Event Reference

This document provides a comprehensive reference of all events published across the microservices architecture.

## Traceability Notes (for debugging)

This file is intended to make it easy to trace an event end-to-end:

- **Topic**: Dapr pub/sub topic name.
- **Publisher**: which service emits it + the **closest code location** (file/function) to start investigating.
- **Payload**: the Go struct (or shape) used when publishing.
- **Primary Consumers**: which services typically consume it (if known from code constants/handlers).
- **DLQ**: if the consuming service implements DLQ/retry mapping, note the DLQ topic + handler entrypoints.

If a topic appears in multiple places, prefer the **publisher’s service constants** as the source of truth, and use consumer constants only for subscription/DLQ routing.

## Event Naming Convention
- Format: `{domain}.{entity}.{action}`
- Example: `orders.order.status_changed`

## Core Domains

### 1. Order Domain

| Topic | Description | Publisher Service | Payload (Go type) | Producer Trace (code) | Primary Consumers | DLQ / Retry Trace |
|-------|-------------|-------------------|------------------|------------------------|------------------|------------------|
| `orders.order.status_changed` | Order status changed (unified event for created/confirmed/cancelled/completed/...) | Order Service | `events.OrderStatusChangedEvent` | `order/internal/events/publisher.go` (`PublishOrderStatusChanged`) | Warehouse worker, Fulfillment worker, Notification worker (depending on subscriptions) | (TBD: locate consumer-side DLQ topics/handlers for orders.*) |
| `orders.return.requested` | Return requested | Order Service | `events.ReturnRequestedEvent` | `order/internal/events/publisher.go` (`PublishReturnRequested`) | Warehouse worker | (TBD) |
| `orders.return.approved` | Return approved | Order Service | `events.ReturnApprovedEvent` | `order/internal/events/publisher.go` (`PublishReturnApproved`) | Warehouse worker | (TBD) |
| `orders.return.rejected` | Return rejected | Order Service | `events.ReturnRejectedEvent` | `order/internal/events/publisher.go` (`PublishReturnRejected`) | Warehouse worker | (TBD) |
| `orders.return.completed` | Return completed | Order Service | `events.ReturnCompletedEvent` | `order/internal/events/publisher.go` (`PublishReturnCompleted`) | Warehouse worker | (TBD) |
| `orders.exchange.requested` | Exchange requested | Order Service | `events.ExchangeRequestedEvent` | `order/internal/events/publisher.go` (`PublishExchangeRequested`) | Warehouse worker | (TBD) |
| `orders.exchange.approved` | Exchange approved | Order Service | `events.ExchangeApprovedEvent` | `order/internal/events/publisher.go` (`PublishExchangeApproved`) | Warehouse worker | (TBD) |
| `orders.exchange.completed` | Exchange completed | Order Service | `events.ExchangeCompletedEvent` | `order/internal/events/publisher.go` (`PublishExchangeCompleted`) | Warehouse worker | (TBD) |

**Notes**:
- Authoritative topic constants: `order/internal/constants/constants.go`.
- Event payload structs: `order/internal/events/order_events.go`.
- Order publishes via `common/events` Dapr gRPC publisher (see `order/internal/events/publisher.go`).

### 2. Payment Domain

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `payments.payment.confirmed` | Payment confirmed | Payment Service | `payment/internal/events/payment_events.go` |
| `payments.payment.failed` | Payment failed | Payment Service | `payment/internal/events/payment_events.go` |
| `payments.refund.completed` | Refund completed | Payment Service | `payment/internal/events/refund_events.go` |

### 3. Catalog Domain

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `catalog.product.created` | New product created | Catalog Service | `catalog/internal/events/product_events.go` |
| `catalog.product.updated` | Product updated | Catalog Service | `catalog/internal/events/product_events.go` |
| `catalog.product.deleted` | Product deleted | Catalog Service | `catalog/internal/events/product_events.go` |
| `catalog.attribute.config_changed` | Product attribute config changed | Catalog Service | `catalog/internal/events/attribute_events.go` |
| `catalog.cms.page.created` | CMS page created | Catalog Service | `catalog/internal/events/cms_events.go` |
| `catalog.cms.page.updated` | CMS page updated | Catalog Service | `catalog/internal/events/cms_events.go` |
| `catalog.cms.page.deleted` | CMS page deleted | Catalog Service | `catalog/internal/events/cms_events.go` |

### 4. Pricing Domain

| Topic | Description | Publisher Service | Payload (Go type) | Producer Trace (code) | Primary Consumers | DLQ / Retry Trace |
|-------|-------------|-------------------|------------------|------------------------|------------------|------------------|
| `pricing.price.updated` | Price updated (Unified topic for Product, Warehouse, and SKU prices) | Pricing Service | `events.PriceUpdatedEvent` | `pricing/internal/biz/price/price.go` (publish) | Search worker, Catalog worker | Search DLQ: `dlq.pricing.price.updated`, Catalog DLQ (if applicable) |
| `pricing.price.deleted` | Price deleted | Pricing Service | `events.PriceDeletedEvent` | `pricing/internal/biz/price/price.go` (publish) | Search worker | Search DLQ: `dlq.pricing.price.deleted` (`search/internal/constants/event_topics.go`), handler refs as above |
| `pricing.price.bulk_updated` | Bulk price update | Pricing Service | `events.PriceBulkUpdatedEvent` | `pricing/internal/events/price_events.go` (type); publish call sites TBD | (TBD) | (TBD) |
| `pricing.price.calculated` | Price calculated (observability / downstream analytics) | Pricing Service | `events.PriceCalculatedEvent` | `pricing/internal/biz/calculation/calculation.go` (`PublishCustom` to topic) | (TBD) | (TBD) |
| `pricing.discount.applied` | Discount applied | Pricing Service | `events.DiscountAppliedEvent` | `pricing/internal/events/price_events.go` (type); publish call sites TBD | (TBD) | (TBD) |

**Notes**:
- **Price Topic Unification**: All price updates (including Warehouse and SKU specific prices) are now published to `pricing.price.updated`. Consumers must check the `priceScope` field in the payload to determine the scope of the update ("product", "warehouse", or "sku").
- Legacy topics (`pricing.warehouse_price.updated`, `pricing.sku_price.updated`) have been deprecated and removed.

### 5. Warehouse Domain

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `warehouse.inventory.stock_changed` | Inventory stock level changed | Warehouse Service | `warehouse/internal/events/inventory_events.go` |
| `warehouse.inventory.reserved` | Inventory reserved | Warehouse Service | `warehouse/internal/events/inventory_events.go` |
| `warehouse.inventory.released` | Inventory released | Warehouse Service | `warehouse/internal/events/inventory_events.go` |

### 6. Fulfillment Domain

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `fulfillments.fulfillment.status_changed` | Fulfillment status changed | Fulfillment Service | `fulfillment/internal/events/fulfillment_events.go` |
| `picklists.picklist.status_changed` | Picklist status changed | Fulfillment Service | `fulfillment/internal/events/picklist_events.go` |
| `packages.package.status_changed` | Package status changed | Fulfillment/Shipping Service | `shipping/internal/events/package_events.go` |

### 7. Promotion Domain

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `promotions.campaign.created` | New campaign created | Promotion Service | `promotion/internal/events/campaign_events.go` |
| `promotions.campaign.updated` | Campaign updated | Promotion Service | `promotion/internal/events/campaign_events.go` |
| `promotions.campaign.deleted` | Campaign deleted | Promotion Service | `promotion/internal/events/campaign_events.go` |
| `promotions.campaign.activated` | Campaign activated | Promotion Service | `promotion/internal/events/campaign_events.go` |
| `promotions.campaign.deactivated` | Campaign deactivated | Promotion Service | `promotion/internal/events/campaign_events.go` |
| `promotions.promotion.created` | New promotion created | Promotion Service | `promotion/internal/events/promotion_events.go` |
| `promotions.promotion.updated` | Promotion updated | Promotion Service | `promotion/internal/events/promotion_events.go` |
| `promotions.promotion.deleted` | Promotion deleted | Promotion Service | `promotion/internal/events/promotion_events.go` |
| `promotions.coupon.created` | Coupon created | Promotion Service | `promotion/internal/events/coupon_events.go` |
| `promotions.coupon.updated` | Coupon updated | Promotion Service | `promotion/internal/events/coupon_events.go` |
| `promotions.coupon.deleted` | Coupon deleted | Promotion Service | `promotion/internal/events/coupon_events.go` |
| `promotions.coupon.bulk_created` | Bulk coupons created | Promotion Service | `promotion/internal/events/coupon_events.go` |
| `promotions.coupon.applied` | Coupon applied | Promotion Service | `promotion/internal/events/coupon_events.go` |

### 8. System Events

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `system.errors` | System error occurred | Various Services | `common/events/system_events.go` |

## Common Event Payload Structure

All events follow a base structure:

```go
type BaseEvent struct {
    EventID     string    `json:"event_id"`
    EventType   string    `json:"event_type"`
    Timestamp   time.Time `json:"timestamp"`
    ServiceName string    `json:"service_name"`
    Environment string    `json:"environment"`
    // Additional metadata
    Metadata    map[string]interface{} `json:"metadata,omitempty"`
}
```

## Event Consumption Guidelines

1. **Idempotency**: All event handlers should be idempotent to handle duplicate events.
2. **Error Handling**: Implement dead-letter queues (DLQ) for failed event processing.
3. **Schema Evolution**: Always add new fields as optional to maintain backward compatibility.
4. **Monitoring**: Monitor event processing metrics and set up alerts for failures.

## Event Versioning

- **v1**: Initial version (current)
- Future versions will be documented with migration guides when introduced.

## Best Practices

1. **Publishing Events**:
   - Always set a unique event ID
   - Include timestamps in UTC
   - Include the source service name
   - Keep payloads lean and focused

2. **Consuming Events**:
   - Validate all required fields
   - Handle out-of-order events when necessary
   - Implement circuit breakers for external calls

## Monitoring and Observability

Key metrics to monitor:
- Event publish rate
- Event processing latency
- Error rates
- Dead letter queue size
- Consumer lag

---

*Document generated from code analysis on: 2026-01-10*
*Last Updated: 2026-01-10*
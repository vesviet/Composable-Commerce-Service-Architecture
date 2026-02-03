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

### 2. Checkout Domain

| Topic | Description | Publisher Service | Payload (Go type) | Producer Trace (code) | Primary Consumers | DLQ / Retry Trace |
|-------|-------------|-------------------|------------------|------------------------|------------------|------------------|
| `checkout.cart.item_added` | Item added to cart | Checkout Service | `events.CartItemAddedEvent` | `checkout/internal/events/publisher.go` (`PublishCartItemAdded`) | Analytics worker, Recommendation worker | (TBD) |
| `checkout.cart.item_removed` | Item removed from cart | Checkout Service | `events.CartItemRemovedEvent` | `checkout/internal/events/publisher.go` (`PublishCartItemRemoved`) | Analytics worker | (TBD) |
| `checkout.cart.abandoned` | Cart abandoned | Checkout Service | `events.CartAbandonedEvent` | `checkout/internal/events/publisher.go` (`PublishCartAbandoned`) | Notification worker (for abandoned cart emails) | (TBD) |
| `checkout.order.created` | Order created from checkout | Checkout Service | `events.OrderCreatedEvent` | `checkout/internal/events/publisher.go` (`PublishOrderCreated`) | Order service, Warehouse worker, Payment worker | (TBD) |

### 3. Return Domain

| Topic | Description | Publisher Service | Payload (Go type) | Producer Trace (code) | Primary Consumers | DLQ / Retry Trace |
|-------|-------------|-------------------|------------------|------------------------|------------------|------------------|
| `returns.return.requested` | Return requested | Return Service | `events.ReturnRequestedEvent` | `return/internal/events/publisher.go` (`PublishReturnRequested`) | Order service, Warehouse worker, Notification worker | (TBD) |
| `returns.return.approved` | Return approved | Return Service | `events.ReturnApprovedEvent` | `return/internal/events/publisher.go` (`PublishReturnApproved`) | Order service, Warehouse worker, Payment worker | (TBD) |
| `returns.return.rejected` | Return rejected | Return Service | `events.ReturnRejectedEvent` | `return/internal/events/publisher.go` (`PublishReturnRejected`) | Order service, Notification worker | (TBD) |
| `returns.return.completed` | Return completed | Return Service | `events.ReturnCompletedEvent` | `return/internal/events/publisher.go` (`PublishReturnCompleted`) | Order service, Payment worker | (TBD) |
| `returns.exchange.requested` | Exchange requested | Return Service | `events.ExchangeRequestedEvent` | `return/internal/events/publisher.go` (`PublishExchangeRequested`) | Order service, Warehouse worker | (TBD) |
| `returns.exchange.approved` | Exchange approved | Return Service | `events.ExchangeApprovedEvent` | `return/internal/events/publisher.go` (`PublishExchangeApproved`) | Order service, Warehouse worker | (TBD) |
| `returns.exchange.completed` | Exchange completed | Return Service | `events.ExchangeCompletedEvent` | `return/internal/events/publisher.go` (`PublishExchangeCompleted`) | Order service, Fulfillment worker | (TBD) |

**Notes**:
- **Order Service**: Now focused on order lifecycle management post-checkout
- **Checkout Service**: Handles cart management and order creation from checkout flow
- **Return Service**: Dedicated service for returns and exchanges
- Authoritative topic constants: `order/internal/constants/constants.go`, `checkout/internal/constants/constants.go`, `return/internal/constants/constants.go`
- Event payload structs: `order/internal/events/order_events.go`, `checkout/internal/events/checkout_events.go`, `return/internal/events/return_events.go`
- All services publish via `common/events` Dapr gRPC publisher

### 4. Payment Domain

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `payments.payment.confirmed` | Payment confirmed | Payment Service | `payment/internal/events/payment_events.go` |
| `payments.payment.failed` | Payment failed | Payment Service | `payment/internal/events/payment_events.go` |
| `payments.refund.completed` | Refund completed | Payment Service | `payment/internal/events/refund_events.go` |

### 5. Catalog Domain

| Topic | Description | Publisher Service | Payload Reference |
|-------|-------------|--------------------|-------------------|
| `catalog.product.created` | New product created | Catalog Service | `catalog/internal/events/product_events.go` |
| `catalog.product.updated` | Product updated | Catalog Service | `catalog/internal/events/product_events.go` |
| `catalog.product.deleted` | Product deleted | Catalog Service | `catalog/internal/events/product_events.go` |
| `catalog.attribute.config_changed` | Product attribute config changed | Catalog Service | `catalog/internal/events/attribute_events.go` |
| `catalog.cms.page.created` | CMS page created | Catalog Service | `catalog/internal/events/cms_events.go` |
| `catalog.cms.page.updated` | CMS page updated | Catalog Service | `catalog/internal/events/cms_events.go` |
| `catalog.cms.page.deleted` | CMS page deleted | Catalog Service | `catalog/internal/events/cms_events.go` |

### 6. Pricing Domain

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

### 7. Warehouse Domain

| Topic | Description | Publisher Service | Payload (Go type) | Producer Trace (code) | Primary Consumers | DLQ / Retry Trace |
|-------|-------------|-------------------|------------------|------------------------|------------------|------------------|
| `warehouse.inventory.stock_changed` | Inventory stock level changed | Warehouse Service | `warehouse/internal/biz/events.StockUpdatedEvent` | `warehouse/internal/biz/inventory/inventory.go`, `warehouse/internal/biz/reservation/reservation.go`, `warehouse/internal/worker/cron/stock_change_detector.go` (all publish via string literal) | Search worker | Search DLQ: `dlq.warehouse.inventory.stock_changed` (`search/internal/constants/event_topics.go`), handler: `search/internal/service/dlq_handler.go`, HTTP: `search/internal/server/http.go` |
| `warehouse.inventory.reserved` | Inventory reserved (kept in reference) | Warehouse Service | (TBD) | Publish call-site not confirmed (search for literal `warehouse.inventory.reserved` in warehouse service) | (TBD) | No topic-based DLQ found (`dlq.warehouse.inventory.reserved` not present) |
| `warehouse.inventory.released` | Inventory released (kept in reference) | Warehouse Service | (TBD) | Publish call-site not confirmed (search for literal `warehouse.inventory.released` in warehouse service) | (TBD) | No topic-based DLQ found (`dlq.warehouse.inventory.released` not present) |

**Notes**:
- Detailed trace doc: `docs/workfllow/event-ref/warehouse/README.md`.
- `warehouse.inventory.stock_changed` is currently published from multiple places using **string literals**.

### 8. Fulfillment Domain

| Topic | Description | Publisher Service | Payload (Go type) | Producer Trace (code) | Primary Consumers | DLQ / Retry Trace |
|-------|-------------|-------------------|------------------|------------------------|------------------|------------------|
| `fulfillments.fulfillment.status_changed` | Fulfillment status changed (unified lifecycle event) | Fulfillment Service | `events.FulfillmentStatusChangedEvent` | `fulfillment/internal/events/publisher.go` (`PublishFulfillmentStatusChanged`) | Order service (inbound HTTP subscription), Warehouse | No topic-based DLQ found (`dlq.fulfillments.*` not present). Order inbound failures stored in DB DLQ: `order/internal/service/event_helpers.go` + admin endpoints in `order/internal/server/http.go`. |
| `picklists.picklist.status_changed` | Picklist status changed (unified) | Fulfillment Service | `events.PicklistStatusChangedEvent` | `fulfillment/internal/events/publisher.go` (`PublishPicklistStatusChanged`) | (TBD/limited) | No topic-based DLQ found (`dlq.picklists.*` not present). |
| `packages.package.status_changed` | Package status changed (unified) | Fulfillment Service | `events.PackageStatusChangedEvent` | `fulfillment/internal/events/publisher.go` (`PublishPackageStatusChanged*`) | Shipping service, Warehouse (optional) | No topic-based DLQ found (`dlq.packages.*` not present). |

**Notes**:
- Authoritative topic constants: `fulfillment/internal/constants/event_topics.go`.
- Payload structs:
  - `fulfillment/internal/events/fulfillment_events.go`
  - `fulfillment/internal/events/picklist_events.go`
  - `fulfillment/internal/events/package_events.go`
- Detailed trace doc: `docs/workfllow/event-ref/fulfillment/README.md`.

### 9. Promotion Domain

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

### 10. System Events

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
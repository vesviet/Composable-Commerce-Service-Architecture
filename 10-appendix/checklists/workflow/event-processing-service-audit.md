# Event Processing Service Audit

**Purpose**: Single source of truth for Event Processing workflow Section 7 (Service Participation Validation).  
**Last Updated**: 2026-01-31  
**Referenced by**: [integration-flows_event-processing_workflow_checklist.md](integration-flows_event-processing_workflow_checklist.md) Section 7

---

## How to use

- **Checklist**: Section 7 table and checkboxes should align with this audit. When verifying a service, update both the checklist and this file (evidence paths, Last verified).
- **Re-audit**: From repo root run `./docs/scripts/audit-event-participation.sh`. It scans each service directory for `outbox`, `events/publisher`, `eventbus/`, `observer/`, `dapr_subscription`, `subscription.yaml`, `event_idempotency`, `dlq`, `deadLetterTopic` and outputs a markdown table. Compare the output to this doc and update paths when service structure changes.

---

## Per-service evidence

| # | Service | Publisher | Consumer | Idempotency | DLQ | Evidence (paths) |
|---|---------|-----------|----------|-------------|-----|------------------|
| 1 | **Order** | Y | Y | Y | Y | Publisher: `order/internal/events/publisher.go`, `order/internal/worker/outbox/worker.go`. Consumer: `order/internal/data/eventbus/payment_consumer.go`, `fulfillment_consumer.go`, `reservation_consumer.go`. Idempotency: `order/internal/data/postgres/event_idempotency.go`, `order/internal/biz/event_idempotency.go`. DLQ: `order/internal/data/postgres/failed_event.go`. |
| 2 | **Checkout** | Y | N | Y | — | Publisher: `checkout/internal/events/publisher.go`, `checkout/internal/worker/outbox/worker.go`. Idempotency: `checkout/internal/biz/event_idempotency.go`. Consumer: not found (eventbus/observer). |
| 3 | **Return** | Y | N | Y | — | Publisher: `return/internal/events/publisher.go`. Idempotency: `return/internal/biz/event_idempotency.go`. Consumer: not found. |
| 4 | **Payment** | Y | Y (webhooks) | Y | Y | Publisher: `payment/internal/biz/events/event_publisher.go`, `payment/internal/worker/event/outbox_worker.go`. Consumer: webhooks only. Idempotency: `payment/internal/biz/common/idempotency.go`. DLQ: retry/DLQ in webhook handler. |
| 5 | **Catalog** | Y | Y | ✅ **Implemented** | ✅ **Configured** | Publisher: `catalog/internal/biz/events/event_publisher.go`, `catalog/internal/service/events.go`, `catalog/internal/data/postgres/outbox.go`. Consumer: `catalog/internal/data/eventbus/pricing_price_update.go`, `warehouse_stock_update.go`, `event_processor.go`. Idempotency: ✅ **Implemented** (Redis SETNX) - `CheckIdempotency`/`MarkProcessed` methods with event_id from CloudEvent.ID or generated hash; TTL-based with `EventIdempotencyTTL`. DLQ: ✅ **Configured** (2026-01-31) - `deadLetterTopic` configured in both pricing and warehouse event consumers (stock_consumer.go, price_consumer.go) with format `{topic}.dlq`. |
| 6 | **Search** | Minimal | Y | Y | Y | Publisher: minimal. Consumer: `search/internal/data/eventbus/product_consumer.go`, `price_consumer.go`, `stock_consumer.go`, `cms_consumer.go`. Idempotency: `search/internal/service/event_handler_base.go`, `search/internal/data/postgres/event_idempotency.go`. DLQ: `search/internal/service/dlq_consumer.go`, `dlq_handler.go`. |
| 7 | **Warehouse** | Y | Y | ✅ **Implemented** | N/A | Publisher: `warehouse/internal/biz/events/event_publisher.go`, `warehouse/internal/data/postgres/outbox.go`. Consumer: `warehouse/internal/observer/fulfillment_status_changed/warehouse_sub.go`, `order_status_changed/`, `product_created/`, `return_completed/`. Observers delegate to biz layer (`inventory.InventoryUsecase.HandleFulfillmentStatusChanged`). Idempotency: ✅ **Business-Logic-Based** (2026-01-31 verified) - Entity-state idempotency: reservation.Status checks (fulfilled/cancelled) in `fulfillment_status_handler.go`, GetReservationByFulfillmentID prevents duplicate operations. Pattern: "Check-then-act" using entity state as idempotency key. DLQ: N/A - Observer pattern, internal processing. |
| 8 | **Pricing** | Y | Y | ✅ **Implemented** | ✅ **Configured** | Publisher: `pricing/internal/events/publisher.go`, `pricing/internal/data/postgres/price.go` (outbox). Consumer: `pricing/internal/data/eventbus/stock_consumer.go` (warehouse.inventory.stock_changed, warehouse.inventory.low_stock), `promo_consumer.go`. Observers: `pricing/internal/observer/stock_updated/`. Idempotency: ✅ **Business-Logic-Based** (2026-01-31 verified) - Upsert semantics: `promo_created_sub.go` uses GetDiscountByCode before Create/Update; stock observers trigger stateless dynamic pricing (naturally idempotent). Pattern: "Upsert" via business logic. DLQ: ✅ `deadLetterTopic` configured in `stock_consumer.go` and `promo_consumer.go`. |
| 9 | **Promotion** | Y | N | — | — | Publisher: `promotion/internal/events/publisher.go`, `promotion/internal/data/outbox.go`. Consumer: not found. Idempotency/DLQ: N/A (publisher-only). |
| 10 | **Fulfillment** | Y | Y | Y | — | Publisher: `fulfillment/internal/events/publisher.go`, `fulfillment/internal/events/outbox_publisher.go`, `fulfillment/internal/data/postgres/outbox.go`. Consumer: `fulfillment/internal/observer/` (order_status_changed, picklist_status_changed), `fulfillment/internal/data/eventbus/`. Idempotency: present. DLQ: verify. |
| 11 | **Shipping** | Y | Y | ✅ **Implemented** | ✅ **Configured** | Publisher: `shipping/internal/biz/shipment/events.go`, `shipping/internal/data/postgres/outbox.go`. Consumer: `shipping/internal/observer/package_status_changed/`, `shipping/internal/data/eventbus/package_status_consumer.go`. DLQ: ✅ **Configured** (2026-01-31) - `deadLetterTopic` configured in `package_status_consumer.go` with format `{topic}.dlq`. Idempotency: ✅ **Business-Logic-Based** (2026-01-31 verified) - Entity-state idempotency: `GetByFulfillmentID` check in `handlePackageCreated` prevents duplicate shipments. Pattern: \"Check-then-act\" using entity existence as idempotency key. |
| 12 | **Location** | Y | N | — | — | Publisher: `location/internal/data/postgres/outbox.go`. Consumer: not found. Idempotency/DLQ: N/A (publisher-only). |
| 13 | **Customer** | Y | Y | ❌ **Missing** | ✅ **Configured** | Publisher: `customer/internal/biz/events/event_publisher.go`, `customer/internal/data/postgres/outbox_event.go`. Consumer: `customer/internal/server/dapr_subscription.go`, `customer/internal/data/eventbus/order_consumer.go`, `auth_consumer.go`. DLQ: ✅ **Configured** (2026-01-31) - `deadLetterTopic` configured in all consumers (auth_consumer.go: auth.login, auth.password_changed; order_consumer.go: order.completed, order.cancelled, order.returned). Idempotency: ❌ **Missing** (2026-01-31 verified) - No idempotency mechanisms found; consumers handle events but don't check for duplicate processing. No `processed_events` table or idempotency repository. |
| 14 | **Auth** | Y | N | — | — | Publisher: `auth/internal/biz/token/events.go`, `auth/internal/biz/session/events.go`. Consumer: not found. Idempotency/DLQ: N/A. |
| 15 | **User** | Y | N | — | — | Publisher: `user/internal/biz/events/event_publisher.go`, `user/internal/data/postgres/outbox.go`. Consumer: not found. Idempotency/DLQ: N/A. |
| 16 | **Review** | Y | N | — | — | Publisher: `review/internal/biz/events/publisher.go`. Consumer: not found. Idempotency/DLQ: N/A. |
| 17 | **Analytics** | N | Y | ✅ **Implemented** | Y | Publisher: not found. Consumer: `analytics/dapr/subscription.yaml` (order-events, product-events, customer-events, page-view-events), `analytics/internal/handler/event_handler.go`, `analytics/internal/service/event_processor.go`. Idempotency: ✅ **Implemented** (2026-01-31) - event_id field added to all event types; IsEventProcessed/CreateProcessedEvent logic in ProcessOrderEvent, ProcessProductEvent, ProcessCustomerEvent, ProcessPageViewEvent. Repository: `analytics/internal/repository/analytics_repository.go` (IsEventProcessed, CreateProcessedEvent methods). Domain: `analytics/internal/domain/event_processing_models.go` (ProcessedEvent model). Tests: `analytics/internal/service/event_processor_test.go`. DLQ: `analytics/dapr/subscription.yaml` deadLetterTopic, `analytics/internal/service/enhanced_event_processor.go` sendToDeadLetterQueue. |
| 18 | **Notification** | Y | Y | ❌ **Missing** | ✅ **Configured** | Publisher: `notification/internal/biz/events/publisher.go`. Consumer: `notification/internal/data/eventbus/order_status_consumer.go`, `system_error_consumer.go`. DLQ: ✅ **Configured** (2026-01-31) - `deadLetterTopic` configured in both consumers with format `{topic}.dlq`. Idempotency: ❌ **Missing** (2026-01-31 verified) - No idempotency mechanisms found; programmatic consumer handles events but doesn't check for duplicate processing. No `processed_events` table or idempotency repository. Has webhook delivery tracking with status precedence logic. |
| 19 | **Loyalty** | Y | N | — | — | Publisher: `loyalty-rewards/internal/biz/events/publisher.go`. Consumer: not found (no eventbus/observer). Idempotency/DLQ: N/A unless consumer added. |
| 20 | **Gateway** | — | — | — | — | API only; no Dapr pub/sub. |
| (optional) | **common-operations** | Y | Pending | Pending | — | Publisher: `common-operations/internal/event/publisher.go`. Consumer: verify. |

---

## Dapr subscription types (legend)

- **subscription.yaml**: File-based Dapr Subscription (e.g. Analytics).
- **Programmatic**: HTTP/gRPC handlers register subscriptions in code (e.g. Order, Search, Customer).
- **Observers**: Observer pattern / eventbus in code (e.g. Warehouse, Pricing, Fulfillment, Shipping).
- **None**: Publisher-only or N/A.

---

---

## Implementation Status Summary

**Last Updated**: 2026-01-31  
**Total Services Audited**: 21 (19 Go services + 2 Node apps)

### Idempotency Implementation
| Status | Services | Count | %Complete |
|--------|----------|-------|----------|
| ✅ Implemented | Order, Checkout, Return, Payment, Search, Catalog, Fulfillment, Analytics, Warehouse, Pricing, Shipping | 11 | 58% |
| ❌ Missing | Customer, Notification | 2 | 11% |
| N/A (Publisher-only) | Promotion, Location, Auth, User, Review, Loyalty | 6 | — |
| N/A (Infrastructure) | Gateway, Admin, Frontend, common-operations | 4 | — |

**Implementation Patterns**:
- **Database Table**: Order, Search, Analytics (PostgreSQL with `IsProcessed`/`MarkProcessed`)
- **Redis SETNX**: Catalog (TTL-based with `CheckIdempotency`/`MarkProcessed`)
- **Biz Layer**: Checkout, Return, Payment, Fulfillment (idempotency in business logic)
- **Business-Logic-Based**: Warehouse (entity-state checks - reservation.Status), Pricing (upsert semantics - GetDiscountByCode)

### DLQ Implementation
| Status | Services | Count | %Complete |
|--------|----------|-------|----------|
| ✅ Implemented | Order, Payment, Search, Analytics, Pricing, Catalog, Shipping, Customer, Notification | 9 | 47% |
| ⚠️ Verify | Fulfillment | 1 | 5% |
| N/A | Warehouse (observer), Checkout, Return, Promotion, Location, Auth, User, Review, Loyalty, Gateway | 10 | — |

### Subscription Patterns
| Pattern | Services | Count | %Total |
|---------|----------|-------|--------|
| **Programmatic** | Order, Payment, Search, Customer | 4 | 19% |
| **Observer** | Warehouse, Pricing, Fulfillment, Shipping | 4 | 19% |
| **File-based** | Analytics | 1 | 5% |
| **None** (Publisher-only) | Checkout, Return, Promotion, Location, Auth, User, Review, Loyalty | 8 | 38% |
| **N/A** (No pub/sub) | Gateway, Admin, Frontend | 3 | 14% |
| **Mixed/TBD** | Catalog, Notification, common-operations | 3 | 14% |

### Priority Actions
1. **P0 - COMPLETED** ✅ Analytics idempotency implementation (2026-01-31)
2. **P1 - COMPLETED** ✅ Verify and document idempotency in Catalog, Warehouse, Pricing (2026-01-31)
3. **P2 - COMPLETED** ✅ Verify DLQ handling in Catalog, Shipping, Customer, Notification (2026-01-31)
4. **P3 - COMPLETED** ✅ Verify idempotency implementation in Shipping, Customer, Notification (2026-01-31)
   - **Shipping**: ✅ **Implemented** - Business-logic-based idempotency using entity existence check (`GetByFulfillmentID`)
   - **Customer**: ❌ **Missing** - No idempotency mechanisms; consumers don't check for duplicate processing
   - **Notification**: ❌ **Missing** - No idempotency mechanisms; programmatic consumer handles events without duplicate checks
5. **P4 - Medium** ⚠️ Verify DLQ configuration in Fulfillment service
6. **P5 - Medium** Topic alignment between Catalog publisher and Search consumer
7. **P6 - Low** Document observer pattern implementations comprehensively

### Recent Changes
- **2026-01-31**: Analytics service idempotency implemented
  - Added event_id field to all event structs
  - Implemented IsEventProcessed/CreateProcessedEvent pattern
  - Added ProcessedEvent domain model and repository methods
  - Tests passing for all event types
  - Status changed from ❌ Missing → ✅ Implemented

- **2026-01-31**: Catalog service idempotency verified
  - Redis SETNX-based idempotency in `pricing_price_update.go` and `warehouse_stock_update.go`
  - CheckIdempotency/MarkProcessed methods with TTL (EventIdempotencyTTL)
  - event_id from CloudEvent.ID or generated deterministic hash
  - Status changed from ⚠️ Pending → ✅ Implemented

- **2026-01-31**: Warehouse service idempotency verified
  - Business-logic-based idempotency using entity state
  - reservation.Status checks in `fulfillment_status_handler.go`
  - GetReservationByFulfillmentID prevents duplicate operations
  - Pattern: "Check-then-act" using entity state as idempotency key
  - Status changed from ⚠️ Needs Review → ✅ Implemented

- **2026-01-31**: Pricing service idempotency verified
  - Business-logic-based idempotency using upsert semantics
  - GetDiscountByCode before Create/Update in `promo_created_sub.go`
  - Stateless dynamic pricing (naturally idempotent)
  - Pattern: "Upsert" semantics via business logic
  - Status changed from ⚠️ Needs Review → ✅ Implemented

- **2026-01-31**: DLQ configuration verified across 5 services
  - **Catalog**: `deadLetterTopic` in stock_consumer.go, price_consumer.go
  - **Pricing**: Already verified in stock_consumer.go
  - **Shipping**: `deadLetterTopic` in package_status_consumer.go
  - **Customer**: `deadLetterTopic` in auth_consumer.go (2 topics), order_consumer.go (3 topics)
  - **Notification**: `deadLetterTopic` in order_status_consumer.go, system_error_consumer.go
  - All use format `{topic}.dlq` for dead letter topics

- **2026-01-31**: Idempotency verification completed for Shipping, Customer, Notification services
  - **Shipping**: ✅ **Implemented** - Business-logic-based idempotency using `GetByFulfillmentID` check in `handlePackageCreated` to prevent duplicate shipments
  - **Customer**: ❌ **Missing** - No idempotency mechanisms found in `OrderConsumer` and `AuthConsumer`; consumers handle events but don't check for duplicate processing
  - **Notification**: ❌ **Missing** - No idempotency mechanisms found in `OrderStatusConsumer`; programmatic consumer handles events without duplicate checks

---

## References

- Workflow doc: [docs/05-workflows/integration-flows/event-processing.md](../../05-workflows/integration-flows/event-processing.md)
- Workflow review: [docs/07-development/standards/workflow-review-event-processing.md](../../07-development/standards/workflow-review-event-processing.md)
- Checklist: [integration-flows_event-processing_workflow_checklist.md](integration-flows_event-processing_workflow_checklist.md)
- Common events package: [common/events/README.md](../../../common/events/README.md)
- Data synchronization audit (subset): [data-synchronization-service-audit.md](data-synchronization-service-audit.md)

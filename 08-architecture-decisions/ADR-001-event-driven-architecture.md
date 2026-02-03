# ADR-001: Event-Driven Architecture for Transactional Events

**Date:** 2025-11-17  
**Status:** Accepted  
**Deciders:** Platform Team, Architecture Review Board

## Context

The e-commerce platform requires real-time synchronization between multiple services (Order, Inventory, Payment, Shipping, Catalog, Pricing). Traditional synchronous REST calls create:

- **High coupling**: Services directly depend on each other
- **Cascading failures**: One service failure breaks entire flow
- **Performance bottlenecks**: Sequential calls increase latency
- **Scalability issues**: Hard to scale individual services independently

We need a solution that provides:
- Loose coupling between services
- Eventual consistency
- High availability and resilience
- Independent service scaling
- Real-time updates (<100ms latency)

## Decision

We will use **Dapr Pub/Sub with Redis Streams backend** for all transactional events in the platform.

### Key Components:
1. **Dapr Pub/Sub**: Abstraction layer for event messaging
2. **Redis Streams**: Backend storage (already in infrastructure)
3. **CloudEvents Format**: Standard event envelope (JSON Schema validated)
4. **Event Versioning**: JSON Schema with `$id` versioning for backward compatibility

### Event Naming Convention:
- Format: `{service}.{domain}.{action}` (e.g., `orders.order.status_changed`)
- All events must have corresponding JSON Schema in `/docs/json-schema/`
- Events are published via Dapr HTTP API: `POST /v1.0/publish/{pubsub}/{topic}`

### Services Using Events:
- **Order Service**: Publishes `orders.order.status_changed`, `orders.cart.*`
- **Warehouse Service**: Publishes `warehouse.stock.updated`, `warehouse.inventory.*`
- **Payment Service**: Publishes `payment.processed`, `payment.failed`
- **Catalog Service**: Subscribes to stock/price events
- **Pricing Service**: Publishes `pricing.price.updated`

## Consequences

### Positive:
- ✅ **Loose Coupling**: Services communicate via events, not direct calls
- ✅ **Resilience**: Services can process events asynchronously, retry on failure
- ✅ **Scalability**: Each service can scale independently based on event volume
- ✅ **Real-time Updates**: Sub-second latency for event delivery
- ✅ **Event Sourcing Ready**: All events are stored in Redis Streams for replay
- ✅ **Backward Compatible**: JSON Schema versioning allows gradual migration

### Negative:
- ⚠️ **Eventual Consistency**: Data may be temporarily inconsistent (acceptable for e-commerce)
- ⚠️ **Complexity**: Requires understanding of event-driven patterns
- ⚠️ **Debugging**: Harder to trace distributed event flows (mitigated with Jaeger tracing)
- ⚠️ **Idempotency**: Must implement idempotency checks in event handlers

### Risks:
- **Event Loss**: Mitigated by Redis Streams persistence and Dapr retry logic
- **Duplicate Events**: Handled via idempotency keys and 24-hour deduplication window
- **Schema Evolution**: Managed via JSON Schema versioning and backward compatibility rules

## Alternatives Considered

### 1. Direct REST Callbacks
- **Rejected**: Creates tight coupling, cascading failures, high latency

### 2. Apache Kafka
- **Rejected**: Overkill for current scale, adds infrastructure complexity, Redis Streams sufficient

### 3. RabbitMQ
- **Rejected**: Requires additional infrastructure, Dapr abstraction provides flexibility to switch later

### 4. gRPC Streaming
- **Rejected**: Point-to-point only, doesn't support pub/sub pattern, harder to scale

## Implementation Notes

- All events must be defined in `/docs/json-schema/` before implementation
- Event handlers must be idempotent (check event ID before processing)
- Use Dapr retry policies for transient failures
- Monitor event latency via Prometheus metrics
- Use Jaeger for distributed tracing of event flows

## References

- [Dapr Pub/Sub Documentation](https://docs.dapr.io/developing-applications/building-blocks/pubsub/)
- [CloudEvents Specification](https://cloudevents.io/)
- [JSON Schema Validation](https://json-schema.org/)


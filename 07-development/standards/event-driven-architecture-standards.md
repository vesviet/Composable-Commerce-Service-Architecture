# Event-Driven Architecture Standards

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Purpose**: Standards for event-driven architecture patterns, messaging, and data consistency

---

## Overview

This document establishes standards for implementing event-driven architecture across our microservices platform, ensuring reliable, scalable, and maintainable event-based communication.

## Event Design Standards

### Event Naming Conventions

#### Event Name Format
```
{domain}.{entity}.{action}
```

**Examples**:
- `order.created`
- `payment.completed`
- `inventory.updated`
- `customer.registered`

#### Event Type Categories
- **Domain Events**: Business-significant events (`order.confirmed`)
- **Integration Events**: Cross-service communication (`inventory.reserved`)
- **System Events**: Technical events (`service.started`)

### Event Schema Standards

#### Required Event Fields
```json
{
  "eventId": "uuid",
  "eventType": "domain.entity.action",
  "eventVersion": "1.0",
  "timestamp": "ISO 8601 timestamp",
  "source": "service-name",
  "correlationId": "uuid",
  "causationId": "uuid",
  "data": {
    // Event-specific payload
  },
  "metadata": {
    "userId": "uuid",
    "traceId": "uuid",
    "retryCount": 0
  }
}
```

#### Event Payload Guidelines
- **Immutable**: Events should never be modified after creation
- **Self-Contained**: Include all necessary data for processing
- **Backward Compatible**: Support schema evolution
- **Minimal**: Include only essential data, avoid large payloads

## Event Publishing Standards

### Publishing Patterns

#### Fire-and-Forget
```go
// For non-critical events
eventPublisher.Publish(ctx, event)
```

#### At-Least-Once Delivery
```go
// For critical business events
err := eventPublisher.PublishWithRetry(ctx, event, retryPolicy)
if err != nil {
    // Handle publishing failure
}
```

#### Transactional Outbox Pattern
```go
// For events that must be published with database changes
tx := db.Begin()
defer tx.Rollback()

// Perform database operations
err := repository.Save(tx, entity)
if err != nil {
    return err
}

// Store event in outbox table
err = outbox.Store(tx, event)
if err != nil {
    return err
}

tx.Commit()
```

### Event Publishing Best Practices

#### Idempotency
- **Event IDs**: Use deterministic UUIDs for idempotency
- **Deduplication**: Implement consumer-side deduplication
- **Retry Safety**: Ensure publishing retries are safe

#### Error Handling
- **Retry Logic**: Exponential backoff with jitter
- **Dead Letter Queues**: Handle permanently failed events
- **Circuit Breakers**: Protect against downstream failures

#### Performance
- **Batch Publishing**: Group related events when possible
- **Async Publishing**: Don't block business operations
- **Connection Pooling**: Reuse connections to message brokers

## Event Consumption Standards

### Consumer Patterns

#### Single Consumer
```go
func (h *OrderEventHandler) HandleOrderCreated(ctx context.Context, event OrderCreatedEvent) error {
    // Process event
    return nil
}
```

#### Competing Consumers
```go
// Multiple instances processing from same queue
func (h *InventoryHandler) HandleInventoryReserved(ctx context.Context, event InventoryReservedEvent) error {
    // Ensure idempotent processing
    if h.isAlreadyProcessed(event.EventId) {
        return nil
    }
    
    // Process event
    return h.processInventoryReservation(event)
}
```

#### Event Sourcing Consumer
```go
func (h *EventSourcingHandler) HandleEvent(ctx context.Context, event DomainEvent) error {
    // Append to event store
    return h.eventStore.Append(event.AggregateId, event)
}
```

### Consumer Best Practices

#### Idempotency
- **Idempotent Operations**: Ensure processing can be repeated safely
- **Event Tracking**: Track processed events to avoid duplicates
- **Natural Idempotency**: Design operations to be naturally idempotent

#### Error Handling
- **Retry Strategies**: Implement appropriate retry logic
- **Poison Message Handling**: Handle malformed or problematic events
- **Graceful Degradation**: Continue processing other events on failure

#### Performance
- **Parallel Processing**: Process independent events concurrently
- **Batch Processing**: Group related operations when possible
- **Resource Management**: Manage memory and connections efficiently

## Data Consistency Patterns

### Eventual Consistency

#### Saga Pattern
```go
type OrderSaga struct {
    steps []SagaStep
}

func (s *OrderSaga) Execute(ctx context.Context, event OrderCreatedEvent) error {
    for _, step := range s.steps {
        err := step.Execute(ctx, event)
        if err != nil {
            // Execute compensation steps
            return s.compensate(ctx, step)
        }
    }
    return nil
}
```

#### CQRS (Command Query Responsibility Segregation)
```go
// Command side - handles writes
type OrderCommandHandler struct {
    eventStore EventStore
}

func (h *OrderCommandHandler) CreateOrder(ctx context.Context, cmd CreateOrderCommand) error {
    // Validate command
    // Create domain events
    // Store events
    return h.eventStore.Save(cmd.OrderId, events)
}

// Query side - handles reads
type OrderQueryHandler struct {
    readModel OrderReadModel
}

func (h *OrderQueryHandler) GetOrder(ctx context.Context, orderId string) (*Order, error) {
    return h.readModel.GetOrder(orderId)
}
```

### Strong Consistency

#### Two-Phase Commit (Limited Use)
```go
// Only for critical operations requiring strong consistency
func (s *PaymentService) ProcessPaymentWithInventory(ctx context.Context, payment Payment) error {
    tx := s.coordinator.BeginTransaction()
    
    // Phase 1: Prepare
    err := s.paymentGateway.Prepare(tx, payment)
    if err != nil {
        tx.Abort()
        return err
    }
    
    err = s.inventoryService.Prepare(tx, payment.Items)
    if err != nil {
        tx.Abort()
        return err
    }
    
    // Phase 2: Commit
    return tx.Commit()
}
```

## Event Store Standards

### Event Storage Requirements

#### Append-Only Storage
- **Immutable Events**: Events are never updated or deleted
- **Ordered Storage**: Events stored in chronological order
- **Partitioning**: Partition by aggregate ID for scalability

#### Event Metadata
```json
{
  "streamId": "order-12345",
  "eventNumber": 1,
  "eventId": "uuid",
  "eventType": "OrderCreated",
  "eventData": "base64-encoded-json",
  "metadata": "base64-encoded-json",
  "timestamp": "2026-01-31T10:00:00Z"
}
```

### Event Store Operations

#### Appending Events
```go
func (es *EventStore) AppendEvents(streamId string, expectedVersion int, events []Event) error {
    // Optimistic concurrency control
    currentVersion := es.getStreamVersion(streamId)
    if currentVersion != expectedVersion {
        return ErrConcurrencyConflict
    }
    
    // Append events atomically
    return es.appendEventsToStream(streamId, events)
}
```

#### Reading Events
```go
func (es *EventStore) ReadEvents(streamId string, fromVersion int) ([]Event, error) {
    return es.readEventsFromStream(streamId, fromVersion)
}
```

#### Snapshots
```go
func (es *EventStore) SaveSnapshot(streamId string, version int, snapshot interface{}) error {
    return es.saveSnapshotForStream(streamId, version, snapshot)
}
```

## Message Broker Standards

### Dapr Pub/Sub Configuration

#### Topic Configuration
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub-redis
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: "redis:6379"
  - name: redisPassword
    value: ""
  - name: enableTLS
    value: "false"
```

#### Subscription Configuration
```yaml
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: order-events
spec:
  topic: order-events
  route: /events/orders
  pubsubname: pubsub-redis
  metadata:
    rawPayload: "true"
```

### Message Routing

#### Topic Design
- **Domain-Based Topics**: `order-events`, `payment-events`, `inventory-events`
- **Event Type Filtering**: Use message headers for event type routing
- **Dead Letter Topics**: `{topic-name}-deadletter`

#### Routing Rules
```go
func (r *EventRouter) RouteEvent(event DomainEvent) string {
    switch event.EventType {
    case "order.created", "order.updated", "order.cancelled":
        return "order-events"
    case "payment.authorized", "payment.captured", "payment.failed":
        return "payment-events"
    default:
        return "general-events"
    }
}
```

## Monitoring and Observability

### Event Metrics

#### Key Performance Indicators
- **Event Publishing Rate**: Events published per second
- **Event Processing Latency**: Time from publish to consumption
- **Event Processing Success Rate**: Percentage of successfully processed events
- **Dead Letter Queue Size**: Number of failed events

#### Monitoring Implementation
```go
// Prometheus metrics
var (
    eventsPublished = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "events_published_total",
            Help: "Total number of events published",
        },
        []string{"event_type", "service"},
    )
    
    eventProcessingDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "event_processing_duration_seconds",
            Help: "Event processing duration",
        },
        []string{"event_type", "handler"},
    )
)
```

### Distributed Tracing

#### Trace Context Propagation
```go
func (p *EventPublisher) Publish(ctx context.Context, event DomainEvent) error {
    // Extract trace context
    span := trace.SpanFromContext(ctx)
    traceId := span.SpanContext().TraceID().String()
    
    // Add trace context to event metadata
    event.Metadata["traceId"] = traceId
    
    return p.broker.Publish(event)
}
```

### Event Auditing

#### Audit Trail Requirements
- **Event Lineage**: Track event causation chains
- **Processing History**: Record all event processing attempts
- **Error Tracking**: Detailed error information for failed events

## Testing Standards

### Event Testing Strategies

#### Unit Testing
```go
func TestOrderEventHandler_HandleOrderCreated(t *testing.T) {
    // Arrange
    handler := NewOrderEventHandler(mockRepo, mockPublisher)
    event := OrderCreatedEvent{
        OrderId: "order-123",
        CustomerId: "customer-456",
    }
    
    // Act
    err := handler.HandleOrderCreated(context.Background(), event)
    
    // Assert
    assert.NoError(t, err)
    mockRepo.AssertExpectations(t)
}
```

#### Integration Testing
```go
func TestEventFlow_OrderToFulfillment(t *testing.T) {
    // Test complete event flow from order creation to fulfillment
    testContainer := setupTestEnvironment()
    defer testContainer.Cleanup()
    
    // Publish order created event
    orderEvent := OrderCreatedEvent{...}
    testContainer.EventBus.Publish(orderEvent)
    
    // Verify fulfillment event is generated
    fulfillmentEvent := testContainer.WaitForEvent("fulfillment.created", 5*time.Second)
    assert.NotNil(t, fulfillmentEvent)
}
```

#### Contract Testing
```go
func TestEventContract_OrderCreated(t *testing.T) {
    // Verify event schema compliance
    event := OrderCreatedEvent{...}
    
    schema := loadEventSchema("order.created.v1.json")
    err := validateEventAgainstSchema(event, schema)
    assert.NoError(t, err)
}
```

## Security Standards

### Event Security

#### Authentication and Authorization
- **Service Identity**: Authenticate publishing services
- **Topic Permissions**: Authorize access to specific topics
- **Event Encryption**: Encrypt sensitive event data

#### Data Privacy
- **PII Handling**: Avoid including PII in events when possible
- **Data Masking**: Mask sensitive data in event logs
- **Retention Policies**: Define event retention and deletion policies

## Performance Standards

### Throughput Requirements
- **High Volume Topics**: Support 10,000+ events per second
- **Standard Topics**: Support 1,000+ events per second
- **Low Volume Topics**: Support 100+ events per second

### Latency Requirements
- **Critical Events**: < 100ms end-to-end latency
- **Standard Events**: < 500ms end-to-end latency
- **Batch Events**: < 5 seconds end-to-end latency

### Scalability Patterns
- **Horizontal Scaling**: Scale consumers based on queue depth
- **Partitioning**: Partition events for parallel processing
- **Load Balancing**: Distribute events across consumer instances

---

**Last Updated**: January 31, 2026  
**Maintained By**: Platform Architecture Team
# Event Bus (Kafka/RabbitMQ)

## Description
Messaging infrastructure that enables asynchronous communication between microservices through event-driven architecture.

## Core Responsibilities
- Event publishing and subscription
- Message routing and delivery
- Event ordering and partitioning
- Dead letter queue handling
- Event replay capabilities
- Message persistence and durability

## Key Events

### Order Events
- `order.created` - New order placed
- `order.updated` - Order status changed
- `order.cancelled` - Order cancelled
- `order.completed` - Order fulfilled

### Inventory Events
- `inventory.updated` - Stock level changed
- `inventory.reserved` - Stock reserved for order
- `inventory.released` - Reserved stock released

### Payment Events
- `payment.processed` - Payment completed
- `payment.failed` - Payment failed
- `payment.refunded` - Refund processed

### Customer Events
- `customer.registered` - New customer registered
- `customer.updated` - Customer profile updated

## Event Schema
```json
{
  "eventId": "uuid",
  "eventType": "order.created",
  "timestamp": "2024-01-01T00:00:00Z",
  "source": "order-service",
  "version": "1.0",
  "data": {
    // Event-specific payload
  }
}
```

## Configuration

### Kafka Configuration
- **Cluster**: 3 Kafka brokers for high availability
- **Partitioning**: By customer ID, order ID, or service type
- **Retention**: 7 days for event replay capability
- **Replication Factor**: 3 replicas for fault tolerance
- **Compression**: LZ4 compression for better throughput

### Topic Configuration
```yaml
topics:
  order-events:
    partitions: 12
    replication_factor: 3
    retention_ms: 604800000  # 7 days
    
  inventory-events:
    partitions: 6
    replication_factor: 3
    retention_ms: 259200000  # 3 days
    
  customer-events:
    partitions: 8
    replication_factor: 3
    retention_ms: 2592000000  # 30 days
```

### Consumer Groups
```yaml
consumer_groups:
  order-processing:
    services: [shipping-service, notification-service, warehouse-service]
    
  inventory-updates:
    services: [catalog-service, search-service, pricing-service]
    
  customer-analytics:
    services: [analytics-service, recommendation-service]
```

## Event Processing Patterns

### Event Sourcing
- **Complete Event History**: Store all state changes as events
- **Event Replay**: Rebuild service state from events
- **Audit Trail**: Complete audit log for compliance
- **Temporal Queries**: Query system state at any point in time

### CQRS (Command Query Responsibility Segregation)
- **Command Side**: Handle write operations and emit events
- **Query Side**: Build read models from events
- **Eventual Consistency**: Read models eventually consistent with events
- **Performance Optimization**: Optimized read models for queries

### Saga Pattern
- **Distributed Transactions**: Coordinate transactions across services
- **Compensation**: Rollback operations if transaction fails
- **State Management**: Track saga state and progress
- **Error Handling**: Handle partial failures gracefully

## Monitoring & Management

### Event Bus Metrics
```json
{
  "kafka_metrics": {
    "messages_per_second": {
      "type": "gauge",
      "labels": ["topic", "partition"]
    },
    "consumer_lag": {
      "type": "gauge", 
      "labels": ["consumer_group", "topic", "partition"]
    },
    "broker_availability": {
      "type": "gauge",
      "labels": ["broker_id"]
    }
  }
}
```

### Health Monitoring
- **Broker Health**: Monitor Kafka broker availability
- **Consumer Lag**: Track message processing delays
- **Throughput**: Monitor message production and consumption rates
- **Error Rates**: Track failed message processing

### Management Tools
- **Kafka Manager**: Web-based Kafka cluster management
- **Schema Registry**: Manage event schema evolution
- **Connect**: Integration with external systems
- **Streams**: Real-time stream processing
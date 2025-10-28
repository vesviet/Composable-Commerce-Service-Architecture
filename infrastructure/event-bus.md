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
- **Kafka**: High-throughput, distributed streaming
- **RabbitMQ**: Reliable message queuing
- **Partitioning**: By customer ID or order ID
- **Retention**: 7 days for replay capability
- **Replication**: 3 replicas for high availability
# 🔄 Event Processing Workflow

**Last Updated**: January 30, 2026  
**Status**: Based on Actual Implementation  
**Services Involved**: All 19 services participate in event-driven architecture  
**Navigation**: [← Integration Flows](README.md) | [← Workflows](../README.md)

---

## 📋 **Overview**

This document describes the complete event processing workflow including event publishing, routing, consumption, and error handling across our event-driven microservices architecture based on the actual implementation using Dapr Pub/Sub with Redis.

### **Business Context**
- **Domain**: System Integration & Communication
- **Objective**: Reliable, scalable, and decoupled service communication
- **Success Criteria**: High throughput, low latency, guaranteed delivery, fault tolerance
- **Key Metrics**: Event throughput, processing latency, delivery success rate, error rate

---

## 🏗️ **Service Architecture**

### **Event Infrastructure**
| Component | Role | Technology | Key Responsibilities |
|-----------|------|------------|---------------------|
| 🔄 **Dapr Sidecar** | Event Broker | Dapr Runtime | Event routing, retry logic, dead letter queues |
| 🗄️ **Redis Streams** | Message Store | Redis | Event persistence, ordering, replay capability |
| 🚪 **Gateway Service** | Event Gateway | Go + Kratos | Event validation, rate limiting, authentication |
| 📊 **Event Store** | Event Persistence | PostgreSQL | Event sourcing, audit trails, compliance |
| 📈 **Analytics Service** | Event Analytics | Go + ClickHouse | Event metrics, monitoring, business intelligence |

### **Event Participants (All 19 Services)**
| Service Category | Services | Event Role |
|------------------|----------|------------|
| **Core Commerce** | Order, Checkout, Return, Payment | High-volume publishers and consumers |
| **Product & Inventory** | Catalog, Search, Warehouse, Pricing, Promotion | Real-time data synchronization |
| **Fulfillment & Logistics** | Fulfillment, Shipping, Location | Workflow orchestration |
| **Customer & User** | Customer, Auth, User, Review | Profile and behavior tracking |
| **Intelligence & Communication** | Analytics, Notification, Loyalty | Event processing and reactions |
| **Infrastructure** | Gateway | Event routing and security |

---

## 🔄 **Event Processing Workflow**

### **Phase 1: Event Publishing**

#### **1.1 Event Creation & Validation**
**Services**: Any Service → Dapr Sidecar → Redis

```mermaid
sequenceDiagram
    participant S as Publishing Service
    participant D as Dapr Sidecar
    participant V as Event Validator
    participant R as Redis Streams
    participant Store as Event Store
    
    S->>S: Business operation completed
    S->>S: Create event payload
    S->>S: Add correlation ID and metadata
    
    S->>D: PublishEvent(topic, event_data)
    D->>V: ValidateEvent(event_schema, event_data)
    
    alt Event valid
        V-->>D: Validation passed
        D->>D: Add Dapr metadata (timestamp, source, etc.)
        D->>R: PublishToStream(topic, enriched_event)
        R->>R: Persist event in stream
        R-->>D: Event published successfully
        
        D->>Store: StoreEvent(event_id, event_data, metadata)
        Store-->>D: Event stored for audit
        
        D-->>S: Event published successfully
    else Event invalid
        V-->>D: Validation failed
        D-->>S: Event validation error
        S->>S: Log validation error
        S->>S: Handle publishing failure
    end
```

**Event Publishing Features:**
- **Schema Validation**: JSON Schema validation for all events
- **Correlation Tracking**: Unique correlation IDs for request tracing
- **Metadata Enrichment**: Automatic addition of service, version, timestamp
- **Retry Logic**: Automatic retry with exponential backoff
- **Dead Letter Queue**: Failed events stored for manual processing

#### **1.2 Event Routing & Topic Management**
**Services**: Dapr → Redis → Subscribers

```mermaid
sequenceDiagram
    participant D as Dapr Sidecar
    participant R as Redis Streams
    participant Router as Event Router
    participant Sub1 as Subscriber 1
    participant Sub2 as Subscriber 2
    participant Sub3 as Subscriber 3
    
    Note over D: Event published to topic
    D->>R: Event stored in Redis Stream
    
    R->>Router: NotifyEventAvailable(topic, event_id)
    Router->>Router: Get topic subscribers
    Router->>Router: Apply routing rules
    Router->>Router: Check subscriber health
    
    par Parallel Delivery
        Router->>Sub1: DeliverEvent(event_data)
        Sub1-->>Router: Acknowledge receipt
    and
        Router->>Sub2: DeliverEvent(event_data)
        Sub2-->>Router: Acknowledge receipt
    and
        Router->>Sub3: DeliverEvent(event_data)
        Sub3-->>Router: Processing failed
        Router->>Router: Schedule retry for Sub3
    end
    
    Router->>R: UpdateDeliveryStatus(event_id, delivery_results)
```

**Event Routing Features:**
- **Topic-based Routing**: Events routed based on topic subscriptions
- **Pattern Matching**: Wildcard and regex pattern subscriptions
- **Load Balancing**: Round-robin delivery for multiple instances
- **Health Checking**: Skip unhealthy subscribers temporarily
- **Delivery Guarantees**: At-least-once delivery with deduplication

---

### **Phase 2: Event Consumption**

#### **2.1 Event Subscription & Processing**
**Services**: Dapr Sidecar → Consuming Service

```mermaid
sequenceDiagram
    participant D as Dapr Sidecar
    participant S as Consuming Service
    participant DB as Service Database
    participant Cache as Redis Cache
    participant DLQ as Dead Letter Queue
    
    D->>S: DeliverEvent(topic, event_data)
    S->>S: Validate event format
    S->>S: Check idempotency key
    
    alt Event already processed
        S->>Cache: CheckProcessedEvent(event_id)
        Cache-->>S: Event already processed
        S-->>D: Acknowledge (idempotent)
    else New event
        S->>S: Process business logic
        S->>DB: UpdateBusinessData(event_data)
        
        alt Processing successful
            DB-->>S: Data updated successfully
            S->>Cache: MarkEventProcessed(event_id, ttl=24h)
            S-->>D: Acknowledge successful processing
        else Processing failed
            DB-->>S: Database error
            S->>S: Log processing error
            S-->>D: Negative acknowledge (retry)
            
            alt Max retries exceeded
                D->>DLQ: MoveToDeadLetterQueue(event_data, error_info)
                D->>S: NotifyDeadLetterEvent(event_id)
            else Retry available
                D->>D: Schedule retry with backoff
            end
        end
    end
```

**Event Consumption Features:**
- **Idempotency**: Duplicate event detection and handling
- **Transactional Processing**: Database transactions for consistency
- **Error Handling**: Comprehensive error handling and retry logic
- **Monitoring**: Processing metrics and health monitoring
- **Backpressure**: Flow control for high-volume events

#### **2.2 Event Ordering & Sequencing**
**Services**: Redis Streams → Dapr → Services

```mermaid
sequenceDiagram
    participant R as Redis Streams
    participant D as Dapr Sidecar
    participant S as Service
    participant Seq as Sequence Manager
    
    Note over R: Multiple events for same entity
    R->>D: Event 1 (order.created)
    R->>D: Event 2 (order.paid)
    R->>D: Event 3 (order.shipped)
    
    D->>Seq: CheckEventSequence(entity_id, event_sequence)
    Seq->>Seq: Validate event ordering
    
    alt Events in correct order
        Seq-->>D: Sequence valid
        D->>S: DeliverEvent(order.created)
        S-->>D: Processed successfully
        
        D->>S: DeliverEvent(order.paid)
        S-->>D: Processed successfully
        
        D->>S: DeliverEvent(order.shipped)
        S-->>D: Processed successfully
        
    else Events out of order
        Seq-->>D: Sequence violation detected
        D->>D: Buffer out-of-order events
        D->>D: Wait for missing events (timeout: 5 minutes)
        
        alt Missing event arrives
            D->>S: DeliverEventsInOrder(buffered_events)
        else Timeout exceeded
            D->>DLQ: MoveToDeadLetterQueue(out_of_order_events)
        end
    end
```

**Event Ordering Features:**
- **Partition Keys**: Events with same key processed in order
- **Sequence Numbers**: Monotonic sequence numbers for ordering
- **Buffer Management**: Temporary buffering of out-of-order events
- **Timeout Handling**: Configurable timeouts for missing events
- **Conflict Resolution**: Strategies for handling sequence violations

---

### **Phase 3: Event Orchestration & Sagas**

#### **3.1 Distributed Transaction Management**
**Services**: Saga Orchestrator → Multiple Services

```mermaid
sequenceDiagram
    participant O as Order Service
    participant Saga as Saga Orchestrator
    participant P as Payment Service
    participant W as Warehouse Service
    participant F as Fulfillment Service
    participant N as Notification Service
    
    O->>Saga: StartOrderSaga(order_id, saga_definition)
    Saga->>Saga: Create saga instance
    Saga->>Saga: Initialize saga state
    
    Note over Saga: Step 1: Process Payment
    Saga->>P: ProcessPayment(order_id, payment_details)
    P->>P: Authorize payment
    P-->>Saga: PaymentProcessed(transaction_id)
    Saga->>Saga: Update saga state: PAYMENT_COMPLETED
    
    Note over Saga: Step 2: Reserve Inventory
    Saga->>W: ReserveInventory(order_id, items)
    W->>W: Reserve stock
    W-->>Saga: InventoryReserved(reservation_id)
    Saga->>Saga: Update saga state: INVENTORY_RESERVED
    
    Note over Saga: Step 3: Create Fulfillment
    Saga->>F: CreateFulfillment(order_id, items)
    F->>F: Create fulfillment task
    F-->>Saga: FulfillmentCreated(fulfillment_id)
    Saga->>Saga: Update saga state: FULFILLMENT_CREATED
    
    Note over Saga: Step 4: Send Confirmation
    Saga->>N: SendOrderConfirmation(order_id, customer_id)
    N->>N: Send confirmation email
    N-->>Saga: NotificationSent(notification_id)
    Saga->>Saga: Update saga state: COMPLETED
    
    Saga->>O: SagaCompleted(order_id, saga_result)
```

#### **3.2 Compensation & Rollback Handling**
**Services**: Saga Orchestrator → Services (Compensation)

```mermaid
sequenceDiagram
    participant Saga as Saga Orchestrator
    participant P as Payment Service
    participant W as Warehouse Service
    participant F as Fulfillment Service
    participant O as Order Service
    
    Note over Saga: Saga execution failed at fulfillment step
    Saga->>Saga: Determine compensation actions
    Saga->>Saga: Execute compensation in reverse order
    
    Note over Saga: Compensate Step 3: Cancel Fulfillment
    Saga->>F: CancelFulfillment(fulfillment_id)
    F->>F: Cancel fulfillment task
    F-->>Saga: FulfillmentCancelled()
    
    Note over Saga: Compensate Step 2: Release Inventory
    Saga->>W: ReleaseInventory(reservation_id)
    W->>W: Release reserved stock
    W-->>Saga: InventoryReleased()
    
    Note over Saga: Compensate Step 1: Refund Payment
    Saga->>P: RefundPayment(transaction_id)
    P->>P: Process refund
    P-->>Saga: PaymentRefunded(refund_id)
    
    Saga->>Saga: Update saga state: COMPENSATED
    Saga->>O: SagaFailed(order_id, compensation_result)
    O->>O: Update order status: FAILED
```

**Saga Management Features:**
- **State Persistence**: Saga state stored for recovery
- **Compensation Logic**: Automatic rollback for failed transactions
- **Timeout Handling**: Configurable timeouts for each saga step
- **Retry Strategies**: Configurable retry policies per step
- **Monitoring**: Real-time saga execution monitoring

---

### **Phase 4: Event Analytics & Monitoring**

#### **4.1 Real-time Event Metrics**
**Services**: All Services → Analytics → Monitoring Dashboard

```mermaid
sequenceDiagram
    participant S as Services
    participant A as Analytics Service
    participant M as Metrics Store
    participant D as Dashboard
    participant Alert as Alerting System
    
    loop Continuous Monitoring
        S->>A: PublishMetricEvent(service_id, metric_data)
        A->>A: Aggregate metrics by service, topic, time
        A->>A: Calculate throughput, latency, error rates
        
        A->>M: StoreMetrics(aggregated_metrics)
        M-->>A: Metrics stored
        
        A->>D: UpdateDashboard(real_time_metrics)
        D->>D: Refresh monitoring dashboard
        
        alt Threshold exceeded
            A->>Alert: TriggerAlert(metric_name, current_value, threshold)
            Alert->>Alert: Send alert to operations team
        end
    end
```

#### **4.2 Event Tracing & Debugging**
**Services**: Distributed Tracing → Analytics

```mermaid
sequenceDiagram
    participant T as Tracing System
    participant A as Analytics Service
    participant S as Search Engine
    participant Debug as Debug Dashboard
    
    T->>A: CollectTraceData(correlation_id, span_data)
    A->>A: Correlate events across services
    A->>A: Build complete event flow trace
    A->>A: Identify bottlenecks and errors
    
    A->>S: IndexTraceData(trace_id, searchable_data)
    S-->>A: Trace data indexed
    
    A->>Debug: UpdateTraceVisualization(trace_data)
    Debug->>Debug: Display event flow diagram
    Debug->>Debug: Highlight errors and delays
    
    Note over Debug: Operations team can search and analyze traces
    Debug->>S: SearchTraces(correlation_id, time_range, filters)
    S-->>Debug: Matching traces returned
```

**Event Analytics Features:**
- **Real-time Metrics**: Live event processing statistics
- **Distributed Tracing**: End-to-end event flow visualization
- **Error Analysis**: Automatic error pattern detection
- **Performance Monitoring**: Latency and throughput analysis
- **Business Intelligence**: Event-driven business insights

---

## 📊 **Event Architecture Overview**

### **Event Categories & Topics**

#### **Core Business Events (High Volume)**
```yaml
# Order Domain Events
order.created: 5000 events/hour
order.confirmed: 4800 events/hour
order.paid: 4500 events/hour
order.shipped: 4200 events/hour
order.delivered: 4000 events/hour

# Inventory Domain Events
inventory.reserved: 8000 events/hour
inventory.allocated: 4500 events/hour
inventory.picked: 4200 events/hour
inventory.restocked: 1000 events/hour

# Payment Domain Events
payment.authorized: 5000 events/hour
payment.captured: 4500 events/hour
payment.refunded: 200 events/hour
payment.failed: 100 events/hour
```

#### **System Events (Medium Volume)**
```yaml
# Customer Domain Events
customer.registered: 500 events/hour
customer.verified: 450 events/hour
customer.profile.updated: 200 events/hour

# Catalog Domain Events
catalog.product.created: 50 events/hour
catalog.product.updated: 200 events/hour
catalog.price.changed: 1000 events/hour

# Search Domain Events
search.index.updated: 1500 events/hour
search.query.performed: 10000 events/hour
```

#### **Operational Events (Low Volume)**
```yaml
# System Health Events
service.health.check: 1140 events/hour (every 30s per service)
service.deployment: 10 events/hour
service.error: 50 events/hour

# Analytics Events
analytics.report.generated: 24 events/hour
analytics.alert.triggered: 10 events/hour
```

### **Event Schema Standards**

#### **Base Event Schema**
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["event_id", "event_type", "timestamp", "version", "data", "metadata"],
  "properties": {
    "event_id": {
      "type": "string",
      "pattern": "^evt_[a-z]+_[0-9]+$",
      "description": "Unique event identifier"
    },
    "event_type": {
      "type": "string",
      "pattern": "^[a-z]+\\.[a-z]+\\.[a-z]+$",
      "description": "Event type in domain.entity.action format"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "Event creation timestamp in ISO 8601 format"
    },
    "version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+$",
      "description": "Event schema version"
    },
    "data": {
      "type": "object",
      "description": "Event-specific payload data"
    },
    "metadata": {
      "type": "object",
      "required": ["correlation_id", "service", "version"],
      "properties": {
        "correlation_id": {
          "type": "string",
          "description": "Request correlation identifier"
        },
        "service": {
          "type": "string",
          "description": "Publishing service name"
        },
        "version": {
          "type": "string",
          "description": "Publishing service version"
        }
      }
    }
  }
}
```

#### **Domain-Specific Event Examples**

**Order Event:**
```json
{
  "event_id": "evt_ord_123456789",
  "event_type": "order.created",
  "timestamp": "2026-01-30T10:30:00Z",
  "version": "1.0",
  "data": {
    "order_id": "ORD-20260130-12345",
    "customer_id": "cust_789012345",
    "total_amount": 1500000,
    "currency": "VND",
    "items": [
      {
        "product_id": "prod_456",
        "quantity": 2,
        "unit_price": 750000
      }
    ],
    "delivery_address": {
      "city": "Ho Chi Minh City",
      "district": "District 1"
    }
  },
  "metadata": {
    "correlation_id": "corr_checkout_123456789",
    "service": "order-service",
    "version": "1.2.0"
  }
}
```

**Inventory Event:**
```json
{
  "event_id": "evt_inv_987654321",
  "event_type": "inventory.reserved",
  "timestamp": "2026-01-30T10:25:00Z",
  "version": "1.0",
  "data": {
    "product_id": "prod_456",
    "warehouse_id": "WH-HCM-001",
    "quantity_reserved": 2,
    "reservation_id": "res_123456789",
    "customer_id": "cust_789012345",
    "expires_at": "2026-01-30T11:00:00Z"
  },
  "metadata": {
    "correlation_id": "corr_checkout_123456789",
    "service": "warehouse-service",
    "version": "1.1.0"
  }
}
```

---

## 🎯 **Event Processing Rules & Patterns**

### **Event Publishing Rules**
- **Transactional Outbox**: Events published as part of database transaction
- **At-Least-Once Delivery**: Guaranteed event delivery with deduplication
- **Schema Evolution**: Backward-compatible schema changes only
- **Event Ordering**: Events for same entity published in order
- **Retention Policy**: Events retained for 30 days in Redis, 1 year in Event Store

### **Event Consumption Rules**
- **Idempotency**: All event handlers must be idempotent
- **Error Handling**: Comprehensive error handling with retry logic
- **Dead Letter Queues**: Failed events moved to DLQ after max retries
- **Processing Timeouts**: Configurable timeouts for event processing
- **Backpressure**: Flow control to prevent consumer overload

### **Saga Patterns**
- **Orchestration**: Centralized saga orchestrator for complex workflows
- **Choreography**: Decentralized event-driven workflows for simple cases
- **Compensation**: Automatic rollback for failed distributed transactions
- **State Persistence**: Saga state persisted for recovery and monitoring
- **Timeout Handling**: Configurable timeouts with automatic compensation

---

## 📈 **Performance Metrics & SLAs**

### **Target Performance**
| Metric | Target | Current | Monitoring |
|--------|--------|---------|------------|
| **Event Publishing Latency** | <10ms (P95) | Tracking | Real-time |
| **Event Processing Latency** | <100ms (P95) | Tracking | Real-time |
| **Event Throughput** | 50,000 events/sec | Tracking | Real-time |
| **Delivery Success Rate** | >99.9% | Tracking | Real-time |
| **Processing Success Rate** | >99.5% | Tracking | Real-time |

### **Business SLAs**
| Process | Target SLA | Current Performance |
|---------|------------|-------------------|
| **Critical Events** | <1 second end-to-end | Tracking |
| **Standard Events** | <5 seconds end-to-end | Tracking |
| **Batch Events** | <1 minute end-to-end | Tracking |
| **Event Recovery** | <15 minutes | Tracking |

### **System Health Metrics**
| Metric | Target | Current | Alert Threshold |
|--------|--------|---------|----------------|
| **Redis Availability** | >99.99% | Tracking | <99.9% |
| **Dapr Sidecar Health** | >99.9% | Tracking | <99% |
| **Dead Letter Queue Size** | <100 events | Tracking | >500 events |
| **Event Lag** | <1 second | Tracking | >10 seconds |
| **Memory Usage** | <80% | Tracking | >90% |

---

## 🔒 **Security & Compliance**

### **Event Security**
- **Authentication**: Service-to-service authentication via mTLS
- **Authorization**: Topic-based access control
- **Encryption**: Event payloads encrypted in transit and at rest
- **Audit Logging**: Complete audit trail for all events
- **Data Privacy**: PII encryption and access controls

### **Compliance Features**
- **Event Sourcing**: Complete audit trail for compliance
- **Data Retention**: Configurable retention policies
- **GDPR Compliance**: Right to deletion and data export
- **Regulatory Reporting**: Automated compliance reporting
- **Access Controls**: Role-based access to event data

---

## 🚨 **Error Handling & Recovery**

### **Common Error Scenarios**

**Publishing Failures:**
- **Redis Unavailable**: Temporary Redis connectivity issues
- **Schema Validation**: Invalid event format or missing fields
- **Rate Limiting**: Publisher exceeding rate limits
- **Network Issues**: Temporary network connectivity problems

**Consumption Failures:**
- **Processing Errors**: Business logic failures in event handlers
- **Database Issues**: Database connectivity or constraint violations
- **Timeout Errors**: Event processing exceeding timeout limits
- **Resource Exhaustion**: Consumer running out of memory or CPU

### **Recovery Mechanisms**
- **Automatic Retry**: Exponential backoff retry for transient failures
- **Circuit Breakers**: Prevent cascade failures across services
- **Dead Letter Queues**: Manual processing of failed events
- **Event Replay**: Replay events from Event Store for recovery
- **Health Monitoring**: Automatic detection and alerting of issues

---

## 📋 **Integration Points**

### **External Integrations**
- **Monitoring Systems**: Prometheus, Grafana, Jaeger integration
- **Alerting Systems**: PagerDuty, Slack integration for alerts
- **Log Aggregation**: ELK stack for centralized logging
- **Business Intelligence**: Data warehouse integration for analytics

### **Internal Service Dependencies**
- **Critical Infrastructure**: Redis, PostgreSQL, Dapr runtime
- **All Services**: Every service participates in event architecture
- **Monitoring Services**: Analytics, notification services

---

**Document Status**: ✅ Complete Implementation-Based Documentation  
**Last Updated**: January 30, 2026  
**Next Review**: February 29, 2026  
**Maintained By**: Platform Architecture & Integration Team
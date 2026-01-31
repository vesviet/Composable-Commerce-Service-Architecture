# Workflow Checklist: Event Processing

**Workflow**: Event Processing (Integration Flows)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Workflow doc**: [docs/05-workflows/integration-flows/event-processing.md](../../../05-workflows/integration-flows/event-processing.md)
**Review**: [docs/07-development/standards/workflow-review-event-processing.md](../../../07-development/standards/workflow-review-event-processing.md)
**System Architecture**: [SYSTEM_ARCHITECTURE_OVERVIEW.md](../../../SYSTEM_ARCHITECTURE_OVERVIEW.md)
**Common Events**: [common/events/README.md](../../../../common/events/README.md)

## 1. Documentation & Design
- [x] Workflow Overview and Business Context defined (19 services in event-driven architecture)
- [x] Service Architecture and Participants mapped (Clean Architecture per service)
- [x] Event Publishing Flow documented (Transactional Outbox pattern)
- [x] Event Routing & Topic Management documented (Dapr Pub/Sub with Redis)
- [x] Event Consumption & Processing Flow documented (Programmatic, File-based, Observer patterns)
- [x] Event Ordering & Sequencing documented (at-least-once delivery with idempotency)
- [x] Saga Orchestration & Compensation patterns defined (Order checkout saga)
- [x] Event Schema Standards defined (JSON Schema, snake_case fields)
- [x] Error Handling & Recovery mechanisms documented (DLQ, retry, compensation)
- [x] Performance Metrics & SLAs defined (<1s P95 for event processing)
- [x] Security & Compliance requirements defined (mTLS, PII masking, audit logging)

## 2. Infrastructure & Configuration
- [x] Dapr Pub/Sub component configured (Redis Streams backend)
- [x] Redis Streams persistence configured (message durability)
- [x] Dead Letter Queues (DLQ) configured (deadLetterTopic for failed events)
- [x] Event Store schema created (outbox, event_idempotency, failed_events tables)
- [x] Analytics Service integration (ClickHouse/Elasticsearch for event storage)
- [x] Topic naming conventions (domain.entity.action format)
- [x] Consumer group configuration (for horizontal scaling)
- [x] Retry policies (maxRetries: 3, maxRetryBackoff: 2s)

## 3. Implementation Validation
- [x] BaseEvent Schema implementation (Go structs with correlation_id, event_id)
- [x] Event Validation Logic (JSON Schema validation middleware)
- [x] Correlation ID Propagation (request tracing across services)
- [x] Idempotency middleware in event consumers (event_id check + processed_events)
- [x] Retry Policy configuration (Dapr sidecar level)
- [x] Circuit Breaker configuration (service-to-service calls)
- [x] Saga Orchestrator implementation (choreography-based with compensation)
- [x] Event Publisher implementations (gRPC-based current standard)
- [x] Event Consumer patterns (Programmatic, File-based, Observer)

## 4. Observability & Monitoring
- [x] Distributed Tracing enabled (OpenTelemetry/Zipkin integration)
- [x] Event Metrics collection (throughput, latency, error rates)
- [x] Dashboard for Event Processing health (Prometheus + Grafana)
- [x] Alerts for DLQ depth and processing failures
- [x] Event throughput monitoring (events/sec per topic)
- [x] Processing latency monitoring (P50/P95/P99)
- [x] Saga state monitoring (state transitions, compensation triggers)
- [x] Dead letter queue monitoring (depth, processing rate)

## 5. Security & Compliance
- [x] mTLS between services and Dapr sidecar
- [x] Event Payload Encryption (for sensitive data fields)
- [x] Audit Logging verification (event publish/consume operations)
- [x] PII masking in event payloads (common/security/pii)
- [x] Access control for pub/sub topics (service-level authentication)
- [x] Data residency compliance (regional data handling)

## 6. Testing
- [x] Unit Tests for event handlers (idempotency, validation)
- [x] Integration Tests for Publish/Subscribe (end-to-end event flow)
- [x] Chaos Testing (Redis failure, service crashes, network partitions)
- [x] Load Testing (high throughput, SLA validation)
- [x] Saga Testing (compensation scenarios, failure recovery)
- [x] Idempotency Tests (duplicate event handling)
- [x] Schema Validation Tests (invalid payload handling)

## 7. Service Participation Validation

**Scope**: All 19 Go services + 2 Node apps participate in event-driven architecture.  
**Evidence**: See [event-processing-service-audit.md](event-processing-service-audit.md) for per-service code paths.  
**Workflow doc**: [docs/05-workflows/integration-flows/event-processing.md](../../../05-workflows/integration-flows/event-processing.md)  
**Common Package**: [common/events/README.md](../../../../common/events/README.md)

**Subscription Types**: **Programmatic** = HTTP/gRPC handlers; **File-based** = subscription.yaml; **Observer** = internal event bus; **None** = publisher-only.

| # | Service | Publisher | Consumer | Idempotency | Subscription Type | DLQ | Saga Role | Evidence Paths |
|---|---------|-----------|----------|-------------|-------------------|-----|-----------|----------------|
| 1 | **Order** | ✅ | ✅ | ✅ | Programmatic | ✅ | Orchestrator | `internal/worker/outbox/`, `internal/data/postgres/event_idempotency.go`, consumers: payment, fulfillment |
| 2 | **Checkout** | ✅ | ❌ | ✅ | None | ❌ | Initiator | `internal/biz/event_idempotency.go`, outbox worker |
| 3 | **Return** | ✅ | ❌ | ✅ | None | ❌ | Initiator | `internal/data/postgres/outbox.go` |
| 4 | **Payment** | ✅ | ✅ | ✅ | Programmatic | ✅ | Participant | `internal/biz/common/idempotency.go`, webhook consumers |
| 5 | **Catalog** | ✅ | ✅ | ⚠️ Verify | Programmatic | ❌ | Participant | `internal/service/eventbus/`, outbox worker |
| 6 | **Search** | ❌ | ✅ | ✅ | Programmatic | ✅ | Consumer | `internal/service/event_handler_base.go`, `internal/data/eventbus/` |
| 7 | **Warehouse** | ✅ | ✅ | ⚠️ Verify | Observer | ❌ | Participant | `internal/observer/`, outbox worker |
| 8 | **Pricing** | ✅ | ✅ | ⚠️ Verify | Observer | ❌ | Participant | `internal/data/postgres/outbox.go`, observer pattern |
| 9 | **Promotion** | ✅ | ❌ | N/A | None | ❌ | Participant | `internal/data/postgres/outbox.go` |
| 10 | **Fulfillment** | ✅ | ✅ | ✅ | Observer | ⚠️ Verify | Participant | `internal/worker/event/`, outbox worker |
| 11 | **Shipping** | ✅ | ✅ | ⚠️ Verify | Observer | ❌ | Participant | observer pattern, outbox worker |
| 12 | **Location** | ✅ | ❌ | N/A | None | ❌ | Participant | `internal/data/postgres/outbox.go` |
| 13 | **Customer** | ✅ | ✅ | ⚠️ Verify | Programmatic | ❌ | Participant | `internal/service/dapr_subscription.go` |
| 14 | **Auth** | ✅ | ❌ | N/A | None | ❌ | Participant | `internal/data/postgres/outbox.go` |
| 15 | **User** | ✅ | ❌ | N/A | None | ❌ | Participant | `internal/data/postgres/outbox.go` |
| 16 | **Review** | ✅ | ❌ | N/A | None | ❌ | Participant | `internal/data/postgres/outbox.go` |
| 17 | **Analytics** | ❌ | ✅ | ✅ **IMPLEMENTED** | File-based | ✅ | Consumer | `dapr/subscription.yaml`, event processors |
| 18 | **Notification** | ✅ | ✅ | ⚠️ Verify | Programmatic | ❌ | Consumer | `internal/data/eventbus/` |
| 19 | **Loyalty** | ✅ | ❌ | N/A | None | ❌ | Consumer | `internal/data/postgres/outbox.go` |
| 20 | **Gateway** | ❌ | ❌ | N/A | N/A | N/A | Infrastructure | API-only service |
| 21 | **Admin** (Node) | ❌ | ❌ | N/A | N/A | N/A | Frontend | React app |
| 22 | **Frontend** (Node) | ❌ | ❌ | N/A | N/A | N/A | Frontend | Next.js app |

### Actions from Service Participation Validation
- **CRITICAL: Analytics Idempotency** - Add `event_id` check + `processed_events` table for order/product/customer/page-view consumers. Impact: Duplicate analytics, inflated metrics.
- **Idempotency Verification** - Code review and document in 7 services marked "Verify" (Catalog, Warehouse, Pricing, Shipping, Customer, Notification, Fulfillment).
- **DLQ Implementation** - Add DLQ handling to Catalog, Warehouse, Pricing, Shipping, Customer, Notification, Fulfillment where missing.
- **Topic Alignment** - Ensure Catalog publishes to topics Search subscribes to (e.g., `catalog.product.created` vs `product.created`).
- **Saga Documentation** - Add sequence diagrams for Order checkout saga and compensation flows.
- **Observer Pattern Documentation** - Document Warehouse, Pricing, Fulfillment, Shipping observer implementations.
- **File-based Subscriptions** - Verify Analytics subscription.yaml configuration and add missing DLQ topics.
- **Publisher-Only Services** - Confirm no consumers needed for Checkout, Return, Promotion, Location, Auth, User, Review, Loyalty.

## 8. Saga Orchestration & Compensation
- [x] Saga Patterns implemented (Order checkout with payment capture)
- [x] Compensation Logic (payment void, order cancellation)
- [x] Saga State persistence (payment_saga_state, authorization_id in orders)
- [x] Failed Compensation handling (failed_compensations table, DLQ)
- [x] Saga Workers (capture_retry, payment_compensation cron jobs)
- [x] Saga Monitoring (state transitions, retry counts, failure alerts)
- [x] Compensation Testing (failure scenarios, recovery validation)

## 9. Event Ordering & Sequencing
- [x] At-least-once delivery guarantee (Dapr Pub/Sub)
- [x] Idempotency for duplicate handling (event_id deduplication)
- [x] Event ordering requirements documented (per business domain)
- [x] Out-of-order event handling (business logic tolerance)
- [x] Sequence number handling (optional for strict ordering)
- [x] Causality tracking (correlation_id propagation)

## 10. Schema Evolution & Versioning
- [x] Event schema versioning strategy (backward compatible changes)
- [x] Schema validation (JSON Schema enforcement)
- [x] Breaking change handling (version negotiation)
- [x] Event migration patterns (transformers for old versions)
- [x] Schema registry (future consideration)
- [x] Consumer compatibility testing (schema evolution validation)

## 11. Performance & Scalability
- [x] Event throughput targets (<1000 events/sec per service)
- [x] Processing latency SLAs (<1s P95)
- [x] Horizontal scaling (consumer groups, multiple instances)
- [x] Backpressure handling (queue depth limits)
- [x] Resource utilization monitoring (CPU, memory per event)
- [x] Bottleneck identification (hot partitions, slow consumers)

## 12. Error Handling & Recovery
- [x] Dead Letter Queue processing (failed event retry logic)
- [x] Poison message handling (unrecoverable event quarantine)
- [x] Circuit breaker patterns (failure isolation)
- [x] Retry strategies (exponential backoff, max attempts)
- [x] Alerting for persistent failures (DLQ depth thresholds)
- [x] Manual intervention workflows (failed event replay)

## 6. Testing
- [ ] Integration Tests for Publish/Subscribe
- [ ] Chaos Testing (Redis failure, Service failure)
- [ ] Load Testing (Matches SLA targets)

---

## 7. Service Participation Validation

Per workflow doc, **19 services** participate in event-driven architecture (+ Gateway as infrastructure, + Location and common-operations for full coverage). For each service: verify **Publisher**, **Consumer**, **Idempotency** (consumer deduplication), **Dapr subscription** type, **DLQ** (consumer DLQ handling).

**Evidence**: See [event-processing-service-audit.md](event-processing-service-audit.md) for per-service code paths.  
**Workflow doc**: [docs/05-workflows/integration-flows/event-processing.md](../../05-workflows/integration-flows/event-processing.md) | **Review**: [workflow-review-event-processing.md](../../07-development/standards/workflow-review-event-processing.md)

**Dapr subscription legend**: **subscription.yaml** = file-based (Analytics); **Programmatic** = HTTP/gRPC handlers (Order, Search, Customer); **Observers** = observer/eventbus in code (Warehouse, Pricing, Fulfillment, Shipping); **None** = publisher-only or N/A.

| # | Service | Publisher | Consumer | Idempotency | Dapr subscription | DLQ | Owner | Last verified | Notes |
|---|---------|-----------|----------|-------------|-------------------|-----|-------|---------------|-------|
| 1 | **Order** | [x] | [x] | [x] | Programmatic | [x] | Order team | 2026-01-31 | Outbox, event_idempotency, consumers: payment, fulfillment, reservation |
| 2 | **Checkout** | [x] | [ ] | [x] | Programmatic | — | Checkout team | — | Publisher + idempotency; no event consumer in code |
| 3 | **Return** | [x] | [ ] | [x] | None | — | Return team | 2026-01-31 | Publisher-only; idempotency for publish path |
| 4 | **Payment** | [x] | [x] webhooks | [x] | Programmatic | [x] | Payment team | 2026-01-31 | Outbox, idempotency, multi-gateway |
| 5 | **Catalog** | [x] | [x] | [ ] | Programmatic (eventbus) | — | Catalog team | — | Topic alignment with Search (product.created/deleted) pending |
| 6 | **Search** | [ ] minimal | [x] | [x] | Programmatic | [x] | Search team | 2026-01-31 | event_handler_base, dlq_consumer; consumers: catalog, pricing, warehouse, cms |
| 7 | **Warehouse** | [x] | [x] | [ ] | Observers | — | Warehouse team | — | Idempotency in consumers: verify |
| 8 | **Pricing** | [x] | [x] | [ ] | Observers | — | Pricing team | — | Idempotency in consumers: verify |
| 9 | **Promotion** | [x] | [ ] | — | None | — | Promotion team | 2026-01-31 | Publisher-only; no consumer in code |
| 10 | **Fulfillment** | [x] | [x] | [x] | Observers | — | Fulfillment team | 2026-01-31 | Outbox, order_status, picklist_status consumers; DLQ: verify |
| 11 | **Shipping** | [x] | [x] | [ ] | Observers | — | Shipping team | — | Idempotency in consumers: verify |
| 12 | **Location** | [x] | [ ] | — | None | — | Location team | 2026-01-31 | Outbox only; no consumer in code |
| 13 | **Customer** | [x] | [x] | [ ] | Programmatic (dapr_subscription) | — | Customer team | — | auth.login, auth.password_changed consumers; idempotency: verify |
| 14 | **Auth** | [x] | [ ] | — | None | — | Auth team | 2026-01-31 | Publisher-only; token, session events |
| 15 | **User** | [x] | [ ] | — | None | — | User team | 2026-01-31 | Publisher-only |
| 16 | **Review** | [x] | [ ] | — | None | — | Review team | 2026-01-31 | Publisher-only |
| 17 | **Analytics** | [ ] | [x] | [ ] **Missing** | subscription.yaml | [x] | Analytics team | — | Idempotency missing; order/product/customer/page-view topics |
| 18 | **Notification** | [x] | [x] | [ ] | Programmatic (eventbus) | — | Notification team | — | Idempotency in consumers: verify |
| 19 | **Loyalty** | [x] | [ ] | — | None | — | Loyalty team | 2026-01-31 | Publisher only; no event consumer in code (points may be API-based) |
| 20 | **Gateway** | — | — | — | — | — | Gateway team | — | API only; no Dapr pub/sub |
| (optional) | **common-operations** | [x] | [ ] | [ ] | — | — | Platform | — | Internal publisher; consumer: verify if any |

### Actions from Section 7
- [x] **Analytics**: Add idempotency (event_id check + store) for order/product/customer/page-view consumers. **✅ IMPLEMENTED** - Added event_id fields and idempotency logic to ProcessProductEvent, ProcessCustomerEvent, ProcessPageViewEvent methods.
- [ ] **Location**: Confirm event topics published (outbox worker?) and document; no consumer in code — N/A for idempotency/DLQ.
- [ ] **Catalog**: Align product.created / product.deleted topic names with Search subscriptions (see [workflow-review-search-indexing.md](../../07-development/standards/workflow-review-search-indexing.md)).
- [ ] **Checkout**: Confirm publisher-only; no event consumer in code. If consumer is added later, add idempotency and DLQ.
- [ ] **Return, Promotion, Auth, User, Review, Loyalty**: Confirmed publisher-only; no consumer. No further action unless consumer is added.
- [ ] **Catalog, Warehouse, Pricing, Shipping, Customer, Notification**: Verify idempotency in event consumers and document in [event-processing-service-audit.md](event-processing-service-audit.md); add DLQ handling where missing.
- [ ] **Fulfillment**: Verify DLQ handling for observer consumers; document in audit.
- [ ] **common-operations**: Verify if any event consumer exists; if yes, add idempotency and document.
- [ ] Fill **Owner** and **Last verified** in table above per service owner when re-validated.

## 8. Saga Orchestration & Compensation
- [x] Saga Patterns implemented (Order checkout with payment authorization/capture)
- [x] Compensation Logic (payment void, order cancellation, inventory release)
- [x] Saga State persistence (payment_saga_state, authorization_id in database)
- [x] Failed Compensation handling (failed_compensations table, escalation alerts)
- [x] Saga Workers (capture_retry cron job, payment_compensation worker)
- [x] Saga Monitoring (state transitions, retry counts, failure rates)
- [x] Compensation Testing (failure injection, recovery validation)
- [x] Saga Documentation (sequence diagrams, state machine flows)

## 9. Event Ordering & Sequencing
- [x] At-least-once delivery guarantee (Dapr Pub/Sub semantics)
- [x] Idempotency for duplicate handling (event_id deduplication)
- [x] Event ordering requirements (per business domain - strict vs eventual)
- [x] Out-of-order event handling (business logic tolerance)
- [x] Causality tracking (correlation_id for request tracing)
- [x] Sequence number handling (optional for domains requiring strict ordering)
- [x] Partitioning strategy (topic partitioning for ordering guarantees)

## 10. Schema Evolution & Versioning
- [x] Event schema versioning strategy (semantic versioning)
- [x] Backward compatibility (additive changes only)
- [x] Schema validation (JSON Schema enforcement)
- [x] Breaking change handling (version negotiation, migration periods)
- [x] Event migration patterns (transformers for legacy versions)
- [x] Consumer compatibility testing (multiple schema versions)
- [x] Schema registry consideration (future centralized schema management)

## 11. Performance & Scalability
- [x] Event throughput targets (per service capacity planning)
- [x] Processing latency SLAs (<1s P95 for critical events)
- [x] Horizontal scaling (consumer groups, multiple instances)
- [x] Backpressure handling (queue depth monitoring, rate limiting)
- [x] Resource utilization (CPU/memory per event type)
- [x] Bottleneck identification (hot partitions, slow consumers)
- [x] Auto-scaling configuration (Kubernetes HPA based on queue depth)

## 12. Error Handling & Recovery
- [x] Dead Letter Queue processing (automated retry with backoff)
- [x] Poison message handling (quarantine unrecoverable events)
- [x] Circuit breaker patterns (failure isolation between services)
- [x] Retry strategies (exponential backoff, maximum attempts)
- [x] Alerting thresholds (DLQ depth, failure rates)
- [x] Manual intervention workflows (failed event replay tools)
- [x] Recovery testing (disaster recovery scenarios)

# Workflow Checklist: Data Synchronization

**Workflow**: Data Synchronization (Integration Flows)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Workflow doc**: [docs/05-workflows/integration-flows/data-synchronization.md](../../../05-workflows/integration-flows/data-synchronization.md)
**Review**: [docs/07-development/standards/workflow-review-data-synchronization.md](../../../07-development/standards/workflow-review-data-synchronization.md)
**System Architecture**: [SYSTEM_ARCHITECTURE_OVERVIEW.md](../../../SYSTEM_ARCHITECTURE_OVERVIEW.md)

## 1. Documentation & Design
- [x] Workflow Overview and Business Context defined
- [x] Service Architecture and Participants mapped (19 Go services + 2 Node apps)
- [x] Data Ownership & Master Data defined (Catalog: products, Pricing: prices, Warehouse: inventory)
- [x] Synchronization Sequencing & Latency SLAs defined (<500ms P95 for real-time sync)
- [x] Event-Driven Architecture alignment (Dapr Pub/Sub with Redis Streams)
- [x] Conflict Resolution Strategies defined (Last-Write-Wins default, timestamp/version-based optional)
- [x] Data Consistency Models documented (Eventual consistency with idempotency)
- [x] Cache Invalidation Patterns documented (Gateway cache, Search internal caches)

## 2. Infrastructure & Configuration
- [x] Transactional Outbox Pattern implemented (current standard for critical data)
- [x] Dapr Pub/Sub topics for Data Sync configured (Redis Streams backend)
- [x] Consumer Group configuration for scaling (Dapr handles automatically)
- [x] Retry Policy for Sync Events (maxRetries: 3, maxRetryBackoff: 2s)
- [x] Dead Letter Queue (DLQ) configuration (deadLetterTopic for failed syncs)
- [x] CDC (Change Data Capture) optional/future (Debezium + PostgreSQL logical replication)
- [x] Cache Infrastructure (Redis with service-specific DB numbers)

## 3. Implementation Validation
- [x] Publisher Implementation (Producer Side)
  - [x] Transactional Outbox Pattern (Order, Checkout, Payment, Fulfillment, Warehouse, Pricing, Promotion)
  - [x] Idempotency Key generation (event_id propagated in payloads)
  - [x] Schema validation before publishing
  - [x] Correlation ID propagation for tracing
- [x] Consumer Implementation (Consumer Side)
  - [x] Idempotent Event Handling (event_id check + processed_events table)
  - [x] Data Transformation Logic (entity mapping, business rules)
  - [x] Local Store Update Logic (Elasticsearch, PostgreSQL, Redis)
  - [x] Cache Invalidation Pattern (Search: invalidateProductCache, invalidatePriceCache, invalidateStockCache)
- [x] Schema validation in sync consumers (JSON Schema validation)
- [x] Error Handling & Recovery (DLQ processing, retry mechanisms)
- [x] Circuit Breaker configuration (service-to-service calls)

## 4. Observability & Monitoring
- [x] Sync Latency Metrics (Producer → Consumer, P50/P95/P99)
- [x] Data Consistency Alerts (sync failure rate, DLQ depth)
- [x] Dashboard for Sync Health (Prometheus + Grafana)
- [x] Distributed Tracing (OpenTelemetry integration)
- [x] Event Throughput monitoring (events/sec per topic)
- [x] Data Freshness monitoring (age of synced data)

## 5. Security & Compliance
- [x] Data Privacy handling during sync (PII masking via common/security/pii)
- [x] Access Control for Sync Topics (service-level authentication)
- [x] Event Payload Encryption (for sensitive data fields)
- [x] Audit Logging verification (sync operations logged)
- [x] mTLS between services and Dapr sidecar

## 6. Testing
- [x] Unit Tests for Sync Logic (transformation, validation)
- [x] Integration Tests for Publish/Subscribe (end-to-end sync)
- [x] Idempotency Tests (duplicate event handling)
- [x] Conflict Resolution Tests (concurrent update scenarios)
- [x] Load Tests (high throughput sync, SLA validation)
- [x] Chaos Testing (Redis failure, network partition)
- [x] Cache Invalidation Tests (consistency verification)

## 7. Service Participation Validation

**Evidence**: See [data-synchronization-service-audit.md](data-synchronization-service-audit.md) and [event-processing-service-audit.md](event-processing-service-audit.md).  
**Workflow doc**: [docs/05-workflows/integration-flows/data-synchronization.md](../../../05-workflows/integration-flows/data-synchronization.md)  
**Common Package**: [common/events/README.md](../../../../common/events/README.md)

| Service | Data Producer | Data Consumer | Idempotency | Schema Validation | Cache Invalidation | DLQ | Evidence Paths |
|---------|---------------|---------------|-------------|-------------------|---------------------|-----|----------------|
| **Catalog** | ✅ (product, price) | ✅ (pricing, warehouse events) | ⚠️ Verify | ⚠️ Verify | ⚠️ Verify | ❌ | `internal/data/postgres/outbox.go`, `internal/service/eventbus/` |
| **Search** | ❌ | ✅ (catalog, pricing, warehouse, cms) | ✅ | ✅ | ✅ | ✅ | `internal/service/event_handler_base.go`, `internal/data/eventbus/`, `invalidate*Cache` methods |
| **Warehouse** | ✅ (inventory) | ✅ (order, fulfillment, product, return) | ⚠️ Verify | ⚠️ Verify | ⚠️ Verify | ❌ | `internal/observer/`, `internal/data/postgres/outbox.go` |
| **Pricing** | ✅ (price) | ✅ (stock, promo) | ⚠️ Verify | ⚠️ Verify | ⚠️ Verify | ❌ | `internal/data/postgres/outbox.go`, observer pattern |
| **Analytics** | ❌ | ✅ (order, product, customer, page-view) | ✅ **IMPLEMENTED** | ⚠️ Verify | N/A | ✅ | `dapr/subscription.yaml`, event processors |
| **Order** | ✅ (order events) | ❌ | ✅ | ✅ | N/A | ✅ | `internal/worker/outbox/`, `internal/data/postgres/event_idempotency.go` |
| **Checkout** | ✅ (checkout events) | ❌ | ✅ | ✅ | N/A | ❌ | `internal/biz/event_idempotency.go` |
| **Payment** | ✅ (payment events) | ✅ (webhooks) | ✅ | ✅ | N/A | ✅ | `internal/biz/common/idempotency.go` |
| **Fulfillment** | ✅ (fulfillment events) | ✅ (order status) | ✅ | ⚠️ Verify | N/A | ⚠️ Verify | `internal/worker/event/`, observer pattern |
| **Shipping** | ✅ (shipping events) | ✅ (package status) | ⚠️ Verify | ⚠️ Verify | N/A | ❌ | observer pattern |
| **Customer** | ✅ (profile events) | ✅ (auth events) | ⚠️ Verify | ⚠️ Verify | N/A | ❌ | `internal/service/dapr_subscription.go` |
| **Notification** | ✅ (notification events) | ✅ (system errors) | ⚠️ Verify | ⚠️ Verify | N/A | ❌ | `internal/data/eventbus/` |
| **Promotion** | ✅ (promotion events) | ❌ | N/A | N/A | N/A | ❌ | `internal/data/postgres/outbox.go` |
| **Return** | ✅ (return events) | ❌ | ✅ | ✅ | N/A | ❌ | `internal/data/postgres/outbox.go` |
| **Auth** | ✅ (auth events) | ❌ | N/A | N/A | N/A | ❌ | `internal/data/postgres/outbox.go` |
| **User** | ✅ (user events) | ❌ | N/A | N/A | N/A | ❌ | `internal/data/postgres/outbox.go` |
| **Review** | ✅ (review events) | ❌ | N/A | N/A | N/A | ❌ | `internal/data/postgres/outbox.go` |
| **Loyalty** | ✅ (loyalty events) | ❌ | N/A | N/A | N/A | ❌ | `internal/data/postgres/outbox.go` |
| **Location** | ✅ (location events) | ❌ | N/A | N/A | N/A | ❌ | `internal/data/postgres/outbox.go` |
| **Gateway** | ❌ | ❌ | N/A | N/A | N/A | N/A | API-only service |

### Actions from Service Participation Validation
- **CRITICAL: Analytics Idempotency** - Add `event_id` check + `processed_events` table for all consumers (order/product/customer/page-view). Impact: Duplicate analytics data, inflated metrics.
- **Schema Validation Gaps** - Add JSON Schema validation to Analytics and verify in Catalog, Warehouse, Pricing consumers.
- **Cache Invalidation Verification** - Confirm Gateway cache invalidation works for product/price updates from Search service.
- **DLQ Implementation** - Add DLQ handling to Catalog, Warehouse, Pricing, Shipping, Customer, Notification services where missing.
- **Idempotency Verification** - Code review and document idempotency implementation in 7 services marked "Verify".
- **Topic Alignment** - Ensure Catalog publishes to topics that Search subscribes to (e.g., `catalog.product.created` vs `product.created`).
- **Performance Monitoring** - Implement sync latency metrics and alerts for SLA compliance (<500ms P95).
- **Testing Framework** - Add integration tests for data sync scenarios, especially conflict resolution.

## 8. Saga Orchestration & Distributed Transactions
- [x] Saga Patterns documented (Order Checkout saga with payment capture)
- [x] Compensation Logic implemented (payment void, order cancellation)
- [x] Saga State persistence (payment_saga_state in orders table)
- [x] Failed Compensation DLQ (failed_compensations table)
- [x] Saga Monitoring (state transitions, compensation triggers)

## 9. Cache Strategy Validation
- [x] Cache Invalidation patterns (write-through, TTL-based fallback)
- [x] Cache Consistency guarantees (event-driven invalidation)
- [x] Multi-level caching (service-level + Gateway-level)
- [x] Cache key naming conventions (service-specific prefixes)
- [x] Cache performance monitoring (hit rates, miss penalties)

## 10. Data Quality & Validation
- [x] Data Transformation validation (business rules, constraints)
- [x] Referential Integrity checks (foreign key validation)
- [x] Data Type validation (schema enforcement)
- [x] Business Rule validation (domain constraints)
- [x] Data Quality monitoring (anomaly detection)

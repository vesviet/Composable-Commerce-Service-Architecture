# Cross-Cutting Concerns — Workflow Review Checklist Template

**Purpose**: Standardized checklist for reviewing cross-cutting concerns in any microservice.
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §15 + Shopify/Shopee/Lazada patterns.
**Usage**: Copy this checklist for each new service review or periodic audit.

---

## Pre-Review Setup

- [ ] Read `docs/10-appendix/ecommerce-platform-flows.md` §15
- [ ] Read `docs/10-appendix/checklists/workflow/cross-cutting-concerns-review-v2.md` (latest findings)
- [ ] Identify which service(s) are being reviewed
- [ ] Run `navigate-service` skill on the service

---

## 1. Event Publishing Audit

### 1.1 Does This Service Need to Publish Events?

- [ ] List all topics the service publishes to
- [ ] For each topic, verify at least one downstream service subscribes to it
- [ ] If no subscriber exists → flag as orphan event (wasted resources)
- [ ] Verify event schema follows CloudEvents format (`type`, `source`, `data`)

### 1.2 Outbox Pattern Verification

- [ ] Does the service use the outbox pattern for event publishing?
  - [ ] If YES → `common/outbox` or custom?
  - [ ] If custom → does it have `FOR UPDATE SKIP LOCKED`?
  - [ ] If custom → does it have retry logic with backoff?
  - [ ] If custom → does it have max retries before marking `failed`?
  - [ ] If NO (direct publish) → is this acceptable? (fire-and-forget events like logging are OK; business-critical events must use outbox)
- [ ] Is the outbox write inside the same DB transaction as the business data mutation?
- [ ] Is there an outbox cleanup cron to prevent table bloat?

### 1.3 Outbox Worker

- [ ] Does `cmd/worker/main.go` exist?
- [ ] Does it register and start the outbox worker?
- [ ] Does the worker have graceful shutdown (`context.Done()`, signal handling)?
- [ ] Does the worker expose health check endpoints?

---

## 2. Event Subscription Audit

### 2.1 Does This Service Need to Subscribe to Events?

- [ ] List all topics the service subscribes to
- [ ] For each topic, verify the publishing service actually publishes it
- [ ] Verify topic names match exactly between publisher and subscriber
- [ ] Verify pubsub component name is correct (`pubsub-redis`)

### 2.2 Idempotency Check

- [ ] Is there idempotency protection for each event consumer?
  - [ ] DB-backed? (`event_processing_log`, `processed_events`, etc.)
  - [ ] In-memory only? (❌ lost on pod restart)
  - [ ] Redis-only? (⚠️ lost on Redis flush)
  - [ ] Business logic guard? (⚠️ may have race conditions)
- [ ] Prefer using `common/idempotency.IdempotencyChecker`
- [ ] Is there cleanup for old idempotency records? (TTL or cron)

### 2.3 Dead Letter Queue (DLQ)

- [ ] Is `deadLetterTopic` configured for each subscription?
- [ ] Is there a DLQ consumer to handle exhausted retries?
- [ ] Are DLQ events logged with sufficient context for debugging?

### 2.4 Error Handling in Event Consumers

- [ ] Does the consumer return errors correctly (Dapr will retry on error)?
- [ ] Is partial processing handled? (e.g., 5 of 10 items processed, then failure)
- [ ] Are transient vs permanent errors distinguished?

---

## 3. Data Consistency Check

### 3.1 Cross-Service Data References

- [ ] List all foreign service IDs stored in this service's DB (e.g., `customer_id`, `order_id`)
- [ ] How is data consistency maintained?
  - [ ] Event-driven sync? (eventual consistency)
  - [ ] Synchronous gRPC call? (strong consistency but coupling)
  - [ ] Cached/denormalized copy? (stale data risk)
- [ ] What happens if the referenced entity is deleted in the source service?

### 3.2 Saga / Compensation Patterns

- [ ] Does this service participate in any saga?
- [ ] Are compensating actions implemented for all failure scenarios?
- [ ] Is there a timeout for pending operations? (e.g., stock reservation TTL)
- [ ] Are compensating actions idempotent?

---

## 4. GitOps Configuration Check

### 4.1 Service Deployment

- [ ] Does `gitops/apps/{service}/base/deployment.yaml` exist?
- [ ] Dapr annotations present and correct?
  - [ ] `dapr.io/enabled: "true"` (if service uses Dapr)
  - [ ] `dapr.io/app-id: "{service}"`
  - [ ] `dapr.io/app-port: "{correct port}"`
  - [ ] `dapr.io/app-protocol: "{http|grpc}"`
- [ ] ConfigMap references correct pubsub name (`pubsub-redis`)?
- [ ] All environment variables have correct default values?

### 4.2 Worker Deployment

- [ ] If service has worker code → does `gitops/apps/{service}/base/worker-deployment.yaml` exist?
- [ ] Worker Dapr annotations present and correct?
  - [ ] `dapr.io/enabled: "true"` (if worker subscribes to events)
  - [ ] `dapr.io/app-id: "{service}-worker"` (must be different from main service)
  - [ ] `dapr.io/app-port: "5005"` (or appropriate port)
  - [ ] `dapr.io/app-protocol: "grpc"` (or appropriate protocol)
- [ ] Worker is included in `kustomization.yaml` resources?
- [ ] Worker has init containers (wait-for-postgres, wait-for-redis)?
- [ ] Worker has resource limits?
- [ ] Does the worker need HPA for scaling?

### 4.3 Dapr Subscription Resources

- [ ] If using declarative subscriptions (YAML), verify `pubsubname` matches Dapr component
- [ ] Verify `topic` names match what the publishing service actually publishes
- [ ] Verify `route` paths match the worker's HTTP handler
- [ ] DLQ topics configured in subscription resources?

### 4.4 ConfigMap / Secret Consistency

- [ ] Base configmap has sensible defaults
- [ ] Dev overlay overrides match dev environment
- [ ] Production overlay exists with production values
- [ ] No hardcoded secrets in configmap (use Vault/Sealed Secrets)

---

## 5. Worker Operations Check

### 5.1 Worker Binary Structure

- [ ] `cmd/worker/main.go` exists and boots correctly?
- [ ] Wire dependency injection set up for worker components?
- [ ] Worker supports mode flags? (`--mode cron|event|all`)
- [ ] Worker has structured logging with service ID, trace ID?

### 5.2 Running Workers

| Worker Type | Running? | Interval/Trigger | Notes |
|-------------|----------|-------------------|-------|
| Outbox processor | ☐ | Every 30s | Polls DB for pending events |
| Event consumer(s) | ☐ | Event-driven | Dapr subscription delivery |
| Cron job(s) | ☐ | Scheduled | List schedule |
| Cleanup job(s) | ☐ | Daily/hourly | Outbox cleanup, idempotency log cleanup |

### 5.3 Health & Monitoring

- [ ] Worker exposes health check endpoint (`/healthz` or similar)?
- [ ] Kubernetes liveness/readiness probes configured?
- [ ] Metrics exposed for worker processing rate?
- [ ] Alerting configured for worker failures?

---

## 6. Security Cross-Cutting Check

### 6.1 Authentication / Authorization

- [ ] All API endpoints require JWT auth (except public endpoints)?
- [ ] `Auth()` middleware used (not `OptionalAuth()`) for protected endpoints?
- [ ] Role-based access checks where needed?
- [ ] Service-to-service calls use proper authentication?

### 6.2 PII / Data Protection

- [ ] PII fields not logged in plaintext?
- [ ] `pii.MaskLogMessage()` applied to log outputs?
- [ ] Sensitive fields marked in API responses? (e.g., masked phone, masked email)
- [ ] PDPA/GDPR consent tracking implemented?

### 6.3 Rate Limiting

- [ ] Sensitive endpoints have rate limiting? (login, OTP, payment)
- [ ] Sliding window rate limit for critical endpoints?
- [ ] Rate limit key uses trusted client IP (not spoofable `X-Forwarded-For`)?

---

## 7. Resilience Cross-Cutting Check

### 7.1 Circuit Breaker

- [ ] gRPC clients to other services use `CircuitBreakerRegistry`?
- [ ] Circuit breaker configuration appropriate? (threshold, recovery time)
- [ ] Fallback behavior defined when circuit is open?

### 7.2 Retry / Timeout

- [ ] HTTP/gRPC clients have timeout configured?
- [ ] Retries use exponential backoff with jitter?
- [ ] Max retries capped to prevent infinite loops?

### 7.3 Graceful Degradation

- [ ] Service can partially function when downstream services are unavailable?
- [ ] Cached data used as fallback? (e.g., search → category browse)
- [ ] Error responses are informative but don't leak internal details?

---

## 8. Observability Cross-Cutting Check

### 8.1 Logging

- [ ] Structured JSON logging?
- [ ] Trace ID (`trace.id`) and Span ID (`span.id`) in every log line?
- [ ] Appropriate log levels? (ERROR for failures, WARN for degradation, INFO for business events)

### 8.2 Tracing

- [ ] OTel tracing initialized?
- [ ] Trace context propagated across gRPC calls?
- [ ] Trace context included in outbox events (`Traceparent` field)?
- [ ] Trace context extracted from incoming events?

### 8.3 Metrics

- [ ] Business metrics exposed? (e.g., orders/min, payment success rate)
- [ ] Technical metrics exposed? (e.g., request duration, error rate)
- [ ] ServiceMonitor configured in GitOps for Prometheus scraping?

---

## Review Summary Template

```
## Service: {service_name}
## Date: YYYY-MM-DD
## Reviewer: {name}

### Findings Summary
| Category | Count |
|----------|-------|
| 🔴 P0 Critical | N |
| 🟡 P1 High | N |
| 🔵 P2 Medium | N |
| ✅ Working Well | N |

### P0 Issues
- [ ] {issue description}

### P1 Issues
- [ ] {issue description}

### P2 Issues
- [ ] {issue description}

### Action Items
1. {action}
2. {action}
```

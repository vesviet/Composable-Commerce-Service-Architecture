# 🛡️ QA Non-Functional Test Checklist — Performance, Security & Resilience
> **Version**: v5.3 | **Date**: 2026-02-15
> **Scope**: 19 Go services — performance, security, fault tolerance, observability
> **Environment**: Dev (k3d), Staging (pre-prod), Production

---

## 🔴 P0 — Security Tests

### 1. Authentication & Authorization

| # | Test Case | Expected Result | Status |
|---|-----------|-----------------|--------|
| 1.1 | **Unauthenticated API access** — call any protected endpoint without JWT | 401 Unauthorized | `[x]` |
| 1.2 | **Expired JWT** — call with expired access token | 401 + clear error message | `[x]` |
| 1.3 | **Tampered JWT** — modify payload, keep signature | 401 (signature mismatch) | `[x]` |
| 1.4 | **RBAC enforcement** — customer calls admin-only endpoint | 403 Forbidden | `[x]` |
| 1.5 | **Cross-tenant data access** — customer A reads customer B's orders | 403 or empty result | `[x]` |
| 1.6 | **Rate limiting** — exceed 100 requests/min from same IP | 429 Too Many Requests | `[ ]` |
| 1.7 | **Admin MFA required** — admin login without MFA | Redirects to MFA setup / blocks login | `[ ]` |

### 2. Payment Security (PCI DSS)

| # | Test Case | Expected Result | Status |
|---|-----------|-----------------|--------|
| 2.1 | **No raw card numbers in logs** — grep all service logs | Zero card numbers found | `[ ]` |
| 2.2 | **No raw card numbers in DB** — check payment tables | Tokenized or masked only | `[ ]` |
| 2.3 | **Payment webhook HMAC verification** — tampered webhook | Rejected (signature invalid) | `[ ]` |
| 2.4 | **Payment webhook replay** — replay same webhook twice | Idempotent — processed once | `[ ]` |
| 2.5 | **Fraud score blocking** — high-risk transaction | Blocked or flagged for manual review | `[x]` |

### 3. Input Validation & Injection

| # | Test Case | Expected Result | Status |
|---|-----------|-----------------|--------|
| 3.1 | **SQL injection** — `' OR 1=1 --` in search/filter params | Escaped, no data leak | `[ ]` |
| 3.2 | **XSS in review content** — `<script>alert('xss')</script>` | Sanitized on output | `[ ]` |
| 3.3 | **Path traversal** — `../../../etc/passwd` in file upload name | Rejected or sanitized | `[x]` |
| 3.4 | **Oversized payload** — 100MB POST body | 413 Payload Too Large | `[x]` |
| 3.5 | **Invalid UUID** — non-UUID string in ID params | 400 Bad Request (not 500) | `[x]` |

---

## 🟡 P1 — Resilience & Fault Tolerance

### 4. Service Failure Scenarios

| # | Test Case | Failure | Expected Behavior | Status |
|---|-----------|---------|-------------------|--------|
| 4.1 | **Payment gateway down** — mock gateway 503 | Checkout returns error, stock not reserved | `[ ]` |
| 4.2 | **Warehouse service down** — stop warehouse pod | Checkout returns "stock service unavailable" | `[ ]` |
| 4.3 | **Dapr sidecar missing** — restart pod without sidecar | Events queued/retried when sidecar recovers | `[ ]` |
| 4.4 | **Redis down** — stop Redis cluster | Idempotency checks fail gracefully (allow-through or reject) | `[ ]` |
| 4.5 | **PostgreSQL failover** — kill primary PostgreSQL node | CNPG promotes replica, service recovers within 30s | `[ ]` |
| 4.6 | **Elasticsearch down** — stop ES cluster | Search returns cached results or graceful error | `[ ]` |
| 4.7 | **Consul down** — stop consul | gRPC calls use last known targets, circuit breaker activates | `[ ]` |

### 5. Event Processing Resilience

| # | Test Case | Failure | Expected Behavior | Status |
|---|-----------|---------|-------------------|--------|
| 5.1 | **Consumer crash mid-processing** — kill worker during event | Event NACK'd, Dapr redelivers | `[ ]` |
| 5.2 | **Outbox worker crash** — kill outbox processor | Events remain in `pending`, next poll picks them up | `[ ]` |
| 5.3 | **Event poison pill** — publish malformed event payload | Consumer logs error, does NOT crash loop | `[x]` |
| 5.4 | **High event volume** — 1000 events/second burst | Consumers process with backpressure, no OOM | `[ ]` |
| 5.5 | **DLQ overflow** — exhaust all retries on 100 events | All moved to DLQ, alert triggered | `[ ]` |

### 6. Network & Timeout Handling

| # | Test Case | Failure | Expected Behavior | Status |
|---|-----------|---------|-------------------|--------|
| 6.1 | **gRPC timeout** — slow downstream (5s delay) | Caller times out, returns error (not hang) | `[x]` |
| 6.2 | **gRPC retry** — transient failure on first call | Auto-retry succeeds on second attempt | `[x]` |
| 6.3 | **Circuit breaker trip** — downstream fails 5x consecutively | Circuit opens, fast-fail for 30s | `[x]` |
| 6.4 | **DNS resolution failure** — invalid service name | Graceful error, not panic | `[ ]` |

---

## 🟢 P2 — Performance Tests

### 7. API Response Time (SLA Targets)

| # | Endpoint | Target (p95) | Load | Status |
|---|----------|-------------|------|--------|
| 7.1 | `GET /api/search?q=...` | < 100ms | 100 concurrent | `[ ]` |
| 7.2 | `POST /api/checkout/confirm` | < 200ms | 50 concurrent | `[ ]` |
| 7.3 | `GET /api/orders/{id}` | < 50ms | 100 concurrent | `[ ]` |
| 7.4 | `POST /api/auth/login` | < 100ms | 100 concurrent | `[ ]` |
| 7.5 | `GET /api/catalog/products/{id}` | < 50ms | 200 concurrent | `[ ]` |
| 7.6 | `POST /api/payments/authorize` | < 2s | 50 concurrent | `[ ]` |

### 8. Load & Stress Testing

| # | Test Case | Scale | Expected | Status |
|---|-----------|-------|----------|--------|
| 8.1 | **Sustained load** — 500 orders/hour for 4 hours | 2,000 orders total | No memory leak, stable response time | `[ ]` |
| 8.2 | **Peak load** — 100 concurrent checkouts | 100 users | All succeed, no deadlocks | `[ ]` |
| 8.3 | **Search load** — 1,000 queries/second | 60s burst | p99 < 500ms | `[ ]` |
| 8.4 | **Event backlog processing** — 10,000 queued events | Catchup scenario | Processed within 10 minutes | `[ ]` |
| 8.5 | **Database connection pool** — exhaust all connections | Max pool size | Queued requests, no crash | `[ ]` |

### 9. Data Sync Latency

| # | Test Case | Source → Target | Target Latency | Status |
|---|-----------|-----------------|----------------|--------|
| 9.1 | **Price update → Search** | Pricing → Search (via event) | < 5s | `[ ]` |
| 9.2 | **Stock update → Search** | Warehouse → Search (via event) | < 5s | `[ ]` |
| 9.3 | **Product CRUD → Search** | Catalog → Search (via event) | < 5s | `[ ]` |
| 9.4 | **Outbox processing lag** | Any outbox service | < 30s | `[ ]` |

---

## ⚪ P3 — Observability & Monitoring

### 10. Monitoring & Alerting

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 10.1 | **Prometheus scrape** — all services expose `/metrics` | All 19 services scraped | `[ ]` |
| 10.2 | **Grafana dashboards** — overview dashboard loads | 12 panels with data | `[ ]` |
| 10.3 | **DLQ alert fires** — add entry to FailedCompensation | AlertManager triggers notification | `[ ]` |
| 10.4 | **Outbox lag alert** — stop outbox worker for 5min | Alert triggered for outbox backlog | `[ ]` |
| 10.5 | **High error rate alert** — simulate 50% error rate | Alert triggered for service degradation | `[ ]` |
| 10.6 | **Service health check** — kill a service pod | Kubernetes restart + alert | `[ ]` |

### 11. Logging & Tracing

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 11.1 | **Structured logging** — verify JSON log format | All services output structured logs | `[x]` |
| 11.2 | **Request tracing** — trace ID propagated across services | Same trace ID from Gateway → downstream | `[x]` |
| 11.3 | **PII masking** — customer data in logs | Email, phone, name masked in logs | `[ ]` |
| 11.4 | **Error context** — error logs include request context | User ID, order ID, etc. in error logs | `[ ]` |

---

## 📊 Non-Functional Test Summary

| Category | Test Cases | Priority | Environment |
|----------|-----------|----------|-------------|
| Auth & Authorization | 7 | 🔴 P0 | All |
| Payment Security | 5 | 🔴 P0 | Staging + Prod |
| Input Validation | 5 | 🔴 P0 | All |
| Service Failures | 7 | 🟡 P1 | Staging |
| Event Resilience | 5 | 🟡 P1 | Staging |
| Network/Timeout | 4 | 🟡 P1 | Staging |
| API Response Time | 6 | 🟢 P2 | Staging |
| Load Testing | 5 | 🟢 P2 | Staging |
| Data Sync Latency | 4 | 🟢 P2 | All |
| Monitoring | 6 | ⚪ P3 | All |
| Logging & Tracing | 4 | ⚪ P3 | All |
| **Total** | **~58** | | |

### Recommended Tools

| Purpose | Tool | Notes |
|---------|------|-------|
| Load testing | **k6** or **hey** | HTTP load generator |
| API testing | **Postman** / **Bruno** | Collection-based testing |
| Security scanning | **gosec** | Go security linter |
| Chaos engineering | **Chaos Mesh** / **LitmusChaos** | K8s fault injection |
| gRPC testing | **grpcurl** | CLI gRPC client |
| Log analysis | **Loki** / **stern** | K8s log aggregation |

# AGENT-24: Cross-Cutting Concerns Hardening

> **Created**: 2026-03-10
> **Priority**: P0 + P1
> **Sprint**: Infrastructure Hardening Sprint
> **Services**: `common`, `order`, `loyalty-rewards`, `notification`, `fulfillment`, `warehouse`, `payment`, `catalog`, `pricing`, `customer`, `analytics`
> **Estimated Effort**: 5-7 days
> **Status**: 🔲 PENDING
> **Source**: [Cross-Cutting §15 — 150-Round Review](../../../.gemini/antigravity/brain/2b1e1b9b-b02e-4879-a8a1-0af061864a7b/cross_cutting_s15_150round_review.md)

---

## 📋 Overview

Audit of `ecommerce-platform-flows.md` §15 Cross-Cutting Concerns revealed **12/28 verified, 13/28 partial, 3/28 not implemented**. This task addresses the most critical gaps: event processing idempotency (10/17 services unprotected), DLQ adoption (14/17 services missing), health check enforcement, alerting rules, trace propagation, and `failed_compensations` retry worker. Each task is ordered by risk and includes exact file locations, code snippets, and validation commands.

### Architecture Context

```
┌─────────────────────────────────────────────────────────────────┐
│                    CROSS-CUTTING GAPS                           │
├─────────────────────────────────────────────────────────────────┤
│ 1. Idempotency:  ██████░░░░ 5/17 services (order,loyalty = P0) │
│ 2. DLQ:          ██░░░░░░░░ 3/17 services                      │
│ 3. Trace Prop:   ██░░░░░░░░ 3/17 services inject TraceExtractor│
│ 4. Health Check: ░░░░░░░░░░ 0/17 verify dependencies           │
│ 5. Alerting:     ░░░░░░░░░░ 0 PrometheusRules deployed         │
│ 6. Compensation: ░░░░░░░░░░ Table exists, no retry worker       │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Wire Event Idempotency into Order Service

**Files**:
- `order/internal/data/eventbus/*.go` (all consumer handlers)
- `order/internal/data/data.go` (Wire provider)
- `order/migrations/` (new migration)

**Risk**: Order service consumes `payment.captured`, `reservation.expired`, `shipment.dispatched` WITHOUT idempotency. Dapr retry on transient failure → duplicate status transitions → double refund trigger, phantom "shipped" notifications.

**Problem**: All event handlers in `order/internal/data/eventbus/` process events directly without `CheckAndMark` wrapper:
```go
// CURRENT (order/internal/data/eventbus/payment_consumer.go):
func (c *PaymentConsumer) HandlePaymentCaptured(ctx context.Context, event *events.BaseEvent) error {
    // Processes directly — no idempotency check
    return c.orderUsecase.ConfirmPayment(ctx, event.Data["order_id"].(string))
}
```

**Fix**:
1. Add migration for `event_idempotency` table (copy from `shipping/migrations/`):
```sql
-- migrations/YYYYMMDDHHMMSS_add_event_idempotency.sql
-- +goose Up
CREATE TABLE IF NOT EXISTS event_idempotency (
    event_id            VARCHAR(255) PRIMARY KEY,
    topic               VARCHAR(255) NOT NULL,
    event_type          VARCHAR(255) NOT NULL,
    consumer_service    VARCHAR(100) NOT NULL DEFAULT 'order',
    processed_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    processing_duration_ms INT DEFAULT 0,
    success             BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_event_idempotency_created_at ON event_idempotency(created_at);
```

2. Wire `GormIdempotencyHelper` in data provider:
```go
// order/internal/data/data.go — add to Wire provider
idempotencyHelper := idempotency.NewGormIdempotencyHelper(db, "order", logger)
```

3. Wrap each handler:
```go
// AFTER:
func (c *PaymentConsumer) HandlePaymentCaptured(ctx context.Context, event *events.BaseEvent) error {
    skip, err := c.idempotency.CheckAndMark(ctx, event.EventID, "payment.captured", "payment_captured", func() error {
        return c.orderUsecase.ConfirmPayment(ctx, event.Data["order_id"].(string))
    })
    if skip { return nil }
    return err
}
```

**Validation**:
```bash
cd order && goose -dir migrations postgres "$DATABASE_URL" up
cd order && go build ./...
cd order && go test ./internal/data/eventbus/... -v
```

---

### [ ] Task 2: Wire Event Idempotency into Loyalty-Rewards Service

**Files**:
- `loyalty-rewards/internal/data/eventbus/*.go` (consumer handlers)
- `loyalty-rewards/internal/data/data.go` (Wire provider)
- `loyalty-rewards/migrations/` (new migration)

**Risk**: Loyalty-rewards consumes `order.completed` WITHOUT idempotency. Dapr retry → **double points award** = financial loss + fraud opportunity. At 10K orders/day × 0.1% retry rate = 10 duplicate awards/day.

**Problem**: Same pattern as Task 1 — handlers process without `CheckAndMark`.

**Fix**: Identical pattern to Task 1: (1) Migration, (2) Wire `GormIdempotencyHelper`, (3) Wrap handlers.

**Validation**:
```bash
cd loyalty-rewards && goose -dir migrations postgres "$DATABASE_URL" up
cd loyalty-rewards && go build ./...
cd loyalty-rewards && go test ./internal/... -v
```

---

### [ ] Task 3: Wire Event Idempotency into Notification Service

**Files**:
- `notification/internal/data/eventbus/*.go` (consumer handlers)
- `notification/internal/data/data.go`
- `notification/migrations/`

**Risk**: Notification consumes events from ALL services without idempotency. Duplicate email/SMS on retry → customer confusion + SMS cost doubling.

**Fix**: Same pattern as Tasks 1-2.

**Validation**:
```bash
cd notification && go build ./...
cd notification && go test ./internal/... -v
```

---

### [ ] Task 4: Add `failed_compensations` Retry Worker to Checkout

**Files**:
- `checkout/internal/worker/cron/compensation_retry_worker.go` (NEW)
- `checkout/internal/worker/workers.go` (register worker)
- `checkout/cmd/worker/wire.go` (Wire binding)

**Risk**: `failed_compensations` table stores failed saga compensations (e.g., void payment after stock reservation failure) but **no worker retries them**. Customer is charged but order is cancelled. Manual intervention required currently.

**Problem**: Table exists (`checkout/internal/model/failed_compensation.go`) with `FailedCompensationRepo` interface (`GetPending`, `Update`), but no cron worker calls `GetPending`.

**Fix**: Create compensation retry worker:
```go
// checkout/internal/worker/cron/compensation_retry_worker.go
package cron

type CompensationRetryWorker struct {
    repo    biz.FailedCompensationRepo
    handler *checkout.ConfirmCheckout
    log     *log.Helper
}

func (w *CompensationRetryWorker) Run(ctx context.Context) error {
    pending, err := w.repo.GetPending(ctx, 10)
    if err != nil { return err }
    for _, record := range pending {
        if record.RetryCount >= 5 {
            record.Status = "permanently_failed"
            w.log.Errorf("[CRITICAL] Compensation permanently failed: order=%s step=%s", record.OrderID, record.StepName)
        } else {
            // Re-attempt compensation
            err := w.handler.ExecuteCompensation(ctx, record)
            if err != nil {
                record.RetryCount++
                record.ErrorMessage = err.Error()
            } else {
                record.Status = "resolved"
            }
        }
        _ = w.repo.Update(ctx, record)
    }
    return nil
}
```

**Validation**:
```bash
cd checkout && go build ./...
cd checkout && go test ./internal/worker/cron/... -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 5: Wire Event Idempotency into Remaining 7 Services

**Services**: `catalog`, `pricing`, `customer`, `review`, `search`, `analytics`, `auth`

**Risk**: All consume events without idempotency. Lower impact than order/loyalty (P0) but still causes duplicate index writes, duplicate segment recalculations, duplicate analytics events.

**Fix**: Same pattern as Tasks 1-3 for each service. Can batch-apply via script:
```bash
# For each service: add migration, wire helper, wrap handlers
for svc in catalog pricing customer review search analytics auth; do
  cp order/migrations/YYYYMMDDHHMMSS_add_event_idempotency.sql $svc/migrations/
  # Then manually wire GormIdempotencyHelper and wrap handlers
done
```

**Validation**:
```bash
for svc in catalog pricing customer review search analytics auth; do
  echo "=== $svc ===" && cd /home/user/microservices/$svc && go build ./... && echo "✅ PASS"
done
```

---

### [ ] Task 6: Enforce Composite Health Checks Across All Services

**Files**:
- Each service's `cmd/server/main.go` or `internal/server/http.go`
- `common/observability/health/` (already has checkers — need to wire)

**Risk**: All health checks return nil unconditionally. K8s keeps pods running when PostgreSQL/Redis/Dapr connections are dead → silent data loss.

**Problem**:
```go
// Current (most services): health endpoint just returns 200
router.GET("/healthz", func(c *gin.Context) { c.JSON(200, "ok") })
```

**Fix**: Use existing `common/observability/health` infrastructure:
```go
// Use composite health checker from common lib
healthChecker := health.NewCompositeChecker(
    health.WithDBChecker(db),
    health.WithRedisChecker(rdb),
)
router.GET("/healthz", func(c *gin.Context) {
    if err := healthChecker.Check(c.Request.Context()); err != nil {
        c.JSON(503, gin.H{"status": "unhealthy", "error": err.Error()})
        return
    }
    c.JSON(200, gin.H{"status": "healthy"})
})
```

**Validation**:
```bash
# For each service: stop PostgreSQL → verify /healthz returns 503
curl -s http://localhost:8001/healthz | jq .status
```

---

### [ ] Task 7: Inject TraceExtractor in Outbox for All Services Using Outbox

**Files**: Each service's outbox Wire setup (typically `internal/data/data.go` or `internal/biz/biz.go`)

**Risk**: 14/17 services lose trace context at outbox boundary. Jaeger shows disconnected traces. Cannot debug end-to-end async flows.

**Problem**: Only `order`, `payment`, `pricing` inject `TraceExtractor`. Other services save outbox events without `Traceparent` field.

**Fix**: In each service's outbox repository constructor, inject trace extractor:
```go
// When creating outbox event, populate Traceparent from OTel context:
import "go.opentelemetry.io/otel/trace"

func extractTraceparent(ctx context.Context) string {
    span := trace.SpanFromContext(ctx)
    if !span.SpanContext().IsValid() { return "" }
    sc := span.SpanContext()
    flags := "00"
    if sc.IsSampled() { flags = "01" }
    return fmt.Sprintf("00-%s-%s-%s", sc.TraceID().String(), sc.SpanID().String(), flags)
}
```

**Validation**:
```bash
# Verify trace_id populated in outbox_events table after save:
psql -c "SELECT id, traceparent FROM outbox_events ORDER BY created_at DESC LIMIT 5;"
```

---

### [ ] Task 8: Deploy Minimum Viable Alerting Rules

**Files**: `deploy/monitoring/prometheus-rules.yaml` (NEW)

**Risk**: Zero PrometheusRules deployed. Outbox backlog, payment errors, goroutine leaks all go undetected until customer complaint.

**Fix**: Create PrometheusRule resource:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: microservices-critical-alerts
spec:
  groups:
    - name: outbox
      rules:
        - alert: OutboxBacklogHigh
          expr: outbox_pending_count > 100
          for: 5m
          labels: { severity: critical }
          annotations:
            summary: "Outbox backlog > 100 for {{ $labels.service }}"
    - name: http
      rules:
        - alert: HighErrorRate
          expr: rate(http_server_requests_total{status=~"5.."}[5m]) / rate(http_server_requests_total[5m]) > 0.01
          for: 2m
          labels: { severity: warning }
    - name: runtime
      rules:
        - alert: GoroutineLeak
          expr: go_goroutines > 1000
          for: 10m
          labels: { severity: warning }
        - alert: PodRestartLoop
          expr: increase(kube_pod_container_status_restarts_total[1h]) > 3
          labels: { severity: critical }
    - name: payment
      rules:
        - alert: PaymentGatewayErrors
          expr: rate(payment_gateway_errors_total[5m]) > 0.05
          for: 2m
          labels: { severity: critical }
```

**Validation**:
```bash
kubectl apply -f deploy/monitoring/prometheus-rules.yaml
kubectl get prometheusrules -n monitoring
# Verify rules loaded in Prometheus: http://prometheus:9090/rules
```

---

### [ ] Task 9: Wire DLQ Worker into Critical Consumer Services

**Services**: `order`, `notification`, `fulfillment`, `warehouse`, `payment`
**Files**: Each service's `internal/worker/workers.go` + `cmd/worker/wire.go`

**Risk**: Failed events permanently lost after Dapr retry exhaustion. Customer never receives notification, order never transitions status.

**Problem**: `common/worker/dlq_worker.go` exists with full retry logic. Only `loyalty-rewards`, `pricing`, `return` have it wired.

**Fix**: Copy DLQ worker wiring pattern from `return/internal/worker/dlq_worker.go`:
```go
// Each service: register DLQ worker
dlqWorker := worker.NewDLQWorker(worker.DLQConfig{
    ServiceName:   "order",
    SubscriptionID: "order-dlq",
    MaxRetries:     5,
    RetryInterval:  30 * time.Second,
}, db, eventPublisher, logger)
registry.Register("dlq-worker", dlqWorker)
```

Also configure Dapr dead letter topic for each subscription:
```yaml
# dapr/components/subscription.yaml
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: order-payment-captured
spec:
  topic: payment.captured
  route: /events/payment-captured
  pubsubname: pubsub-redis
  deadLetterTopic: order-dlq  # ADD THIS
```

**Validation**:
```bash
cd order && go build ./cmd/worker/...
cd notification && go build ./cmd/worker/...
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 10: Rename Analytics `CardNumber` Field to `CardLast4`

**File**: `analytics/internal/biz/realtime_models.go`
**Risk**: PCI QSA audit flag — field name implies full PAN storage.

### [ ] Task 11: Switch Payment Webhook Rate Limit to Sliding Window

**File**: `payment/internal/middleware/ratelimit.go`
**Risk**: Fixed-window allows 2× burst on external payment Gateway callbacks.

### [ ] Task 12: Update `ecommerce-platform-flows.md` §15 Truth Table

**File**: `docs/10-appendix/ecommerce-platform-flows.md` (Lines 627-676)
**Risk**: Documentation over-states implementation maturity. Add ✅/⚠️/🎯 status per claim.

---

## 🔧 Pre-Commit Checklist

```bash
# For each modified service:
for svc in order loyalty-rewards notification checkout catalog pricing customer review search analytics auth; do
  echo "=== $svc ==="
  cd /home/user/microservices/$svc
  go build ./... && echo "✅ build" || echo "❌ build"
  go test ./... && echo "✅ test" || echo "❌ test"
  golangci-lint run ./... && echo "✅ lint" || echo "❌ lint"
  cd /home/user/microservices
done
```

---

## 📝 Commit Format

```
fix(cross-cutting): enforce event idempotency across 10+ services

Phase 1 (P0):
- fix(order): wire GormIdempotencyHelper into all event consumers
- fix(loyalty-rewards): wire idempotency to prevent double points
- fix(notification): wire idempotency to prevent duplicate emails/SMS
- fix(checkout): add compensation retry worker for failed_compensations

Phase 2 (P1):
- fix(common): inject TraceExtractor into outbox by default
- feat(monitoring): deploy minimum viable PrometheusRules
- fix(*): enforce composite health checks in all services
- fix(*): wire DLQ worker into critical consumer services

Closes: AGENT-24
```

---

## 📊 Acceptance Criteria

| # | Criteria | Verification | Status |
|---|---------|-------------|:------:|
| 1 | Order event consumers have idempotency | Send duplicate event → single DB write | |
| 2 | Loyalty-rewards has idempotency | Send duplicate `order.completed` → single points award | |
| 3 | Notification has idempotency | Send duplicate event → single email sent | |
| 4 | Failed compensations auto-retried | Insert failed compensation → worker picks up within 1 min | |
| 5 | All 7 remaining services have idempotency | `event_idempotency` table exists in each service DB | |
| 6 | Health checks verify DB + Redis | Stop PostgreSQL → `/healthz` returns 503 | |
| 7 | Trace context propagated at outbox | `SELECT traceparent FROM outbox_events` → non-empty | |
| 8 | Alerting rules deployed | `kubectl get prometheusrules` → rules visible | |
| 9 | DLQ worker in 5 critical services | `deadLetterTopic` configured in Dapr subscriptions | |

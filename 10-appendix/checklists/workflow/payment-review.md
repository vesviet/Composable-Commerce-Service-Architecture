# Payment Flow — Business Logic Review Checklist

**Date**: 2026-02-24 (v2 — full re-audit following Shopify/Shopee/Lazada patterns)
**Reviewer**: AI Review (deep code scan — payment service)
**Scope**: `payment/` — payment processing, refund, webhook, reconciliation, workers, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §7 (Payment Flows)

> Previous sprint fixes preserved as `✅ Fixed`. New issues from this audit use `[NEW-*]` tags.

---

## 📊 Summary (v2)

| Category | Sprint 1–3 | This Audit |
|----------|-----------|------------|
| 🔴 P0 — Critical | 3 found → 3 fixed | 1 new |
| 🟡 P1 — High | 6 found → 6 fixed | 3 new |
| 🔵 P2 — Medium | 6 found → 6 fixed | 3 new |

---

## 1. Data Consistency

### 1.1 Previously Fixed — Confirmed in Code

| Issue | Status | Evidence |
|-------|--------|----------|
| `PublishPaymentStatusChanged` runtime PANIC via unsafe type assertion | ✅ Fixed | Adapter pattern introduced |
| `order.cancelled` consumer missing — authorized payments never voided | ✅ Fixed | `event_consumer_worker.go:49–51` — `ConsumeOrderCancelled` registered |
| `UpdatePaymentStatus` publishes directly outside `InTx` | ✅ Fixed | Wrapped in `InTx` alongside DB update |
| Outbox cleanup never called | ✅ Fixed | `outbox_worker.go:56,64–65` — `cleanupTicker` every 24h |
| Outbox `MaxRetries` not enforced | ✅ Fixed | `FindRetryable` SQL filters by `max_retries` |
| `GetTotalRefundedAmount` TOCTOU in `ProcessRefund` | ✅ Fixed | Moved inside `InTx` |
| `ProcessPayment` saga compensation uses request ctx | ✅ Fixed | Uses `context.Background()` |
| Dispute events stub no-ops | ✅ Fixed | `PublishDisputeCreated/Responded/StatusChanged` implemented |
| HPA missing for payment main | ✅ Fixed | `gitops/apps/payment/base/hpa.yaml` added (2–8 replicas) |

### 1.2 Still Open from Sprint Review

| Issue | Severity | Notes |
|-------|----------|-------|
| `CreatePaymentFromGatewayData` reads `payment_provider` from metadata, fallback `"stripe"` | ⚠️ P1 | Correct now — but verify non-Stripe gateways include `payment_provider` metadata key |
| `handleRefundSucceeded` now uses `FindByGatewayRefundID` | ✅ Fixed | Direct lookup |

---

## 2. Event Consumers — DLQ Coverage

### 2.1 Registered Consumers in `event_consumer_worker.go`

| Consumer | Topic | DLQ Handler | Status |
|----------|-------|------------|--------|
| `ReturnConsumer.ConsumeReturnCompleted` | `returns.return_completed` | ❌ None registered | ⚠️ [NEW-01] |
| `OrderConsumer.ConsumeOrderCancelled` | `orders.order_cancelled` | ❌ None registered | ⚠️ [NEW-01] |
| `OrderCompletedConsumer.ConsumeOrderCompleted` | `orders.order_completed` | ❌ None registered | ⚠️ [NEW-01] |

No DLQ drain handlers exist for any of the 3 payment event consumers. When Dapr exhausts retries on these topics, events go to unacknowledged DLQ streams.

---

## 3. Outbox Pattern — Confirmed Working ✅

| Check | Status |
|-------|--------|
| Outbox worker runs immediately on start | ✅ `outbox_worker.go:53` |
| Outbox worker: 5s tick, batches 100 events | ✅ `outbox_worker.go:55,43` |
| 24h cleanup of published events > 7 days | ✅ `outbox_worker.go:56,140–149` |
| `ProcessPayment` — outbox inside `InTx` | ✅ `usecase.go:214–258` |
| `CapturePayment`/`VoidPayment` — `InTx` | ✅ `usecase.go:511–521,569–579` |
| Outbox `MarkFailed` is atomic (single UPDATE) | ✅ Fixed (Sprint 3) |
| DaprEventPublisher created at construction time, `pubsubName` hardcoded `"pubsub-redis"` | ⚠️ See [NEW-P2-03] |

---

## 4. NEW Issues Found in This Audit

### 🔴 NEW-01: No DLQ Drain Handlers for Any Payment Event Consumer

**File**: `payment/internal/data/eventbus/return_consumer.go`, `order_consumer.go`, `order_completed_consumer.go`

**Problem**: All 3 event consumers register Dapr subscriptions with `deadLetterTopic` metadata, but `event_consumer_worker.go` never registers a corresponding DLQ drain consumer for any of them.

Consequences when events exhaust Dapr retries:
- `returns.return_completed.dlq` accumulates → refunds for returned items **never triggered** → customers not refunded.
- `orders.order_cancelled.dlq` accumulates → authorized payments **never voided** → gateway holds customer funds indefinitely.
- `orders.order_completed.dlq` accumulates → seller escrow/payout never triggered.

These are financial safety issues. Shopify, Shopee, and Lazada all implement DLQ monitoring + drain consumers for payment-related topics.

**Fix**: Add DLQ handler methods to each consumer and register them in `EventConsumerWorker.Start`:
```go
// In event_consumer_worker.go Start():
if err := w.returnConsumer.ConsumeReturnCompletedDLQ(ctx); err != nil {
    return fmt.Errorf("failed to register return DLQ consumer: %w", err)
}
if err := w.orderConsumer.ConsumeOrderCancelledDLQ(ctx); err != nil {
    return fmt.Errorf("failed to register order cancelled DLQ consumer: %w", err)
}
if err := w.orderCompletedConsumer.ConsumeOrderCompletedDLQ(ctx); err != nil {
    return fmt.Errorf("failed to register order completed DLQ consumer: %w", err)
}
```

---

### 🟡 NEW-02: `PaymentReconciliationJob.Start()` Spawns Goroutine and Returns Immediately — Worker Lifecycle Broken

**File**: `payment/internal/worker/cron/payment_reconciliation.go:46–97`

**Problem**: `Start()` spawns the actual reconciliation loop in a background `goroutine` and then blocks only on a `select{ctx.Done()/stopSignal}`. The goroutine uses its own context reference but is NOT the blocking call. Consequence:

1. `Start()` returns `nil` when `ctx` or `stopSignal` fires — **before the goroutine completes its current reconciliation run**.
2. A pending `processReconciliation(ctx)` run may be mid-flight when the pod receives SIGTERM, resulting in a partial reconciliation with potentially half-committed alerts.
3. `j.stopSignal` is closed in `Stop()` — but the goroutine reads from `j.stopSignal` too. After `Stop()` closes the channel, both the outer select and inner goroutine select will fire simultaneously, causing a double-read on a closed channel (safe in Go, but the goroutine exits independently of `Start()`'s return).

*Shopify/Lazada pattern*: cron job `Start()` should run the ticker loop directly (blocking), similar to the `OutboxWorker` pattern.

**Fix**: Remove the goroutine; run the initial delay + ticker loop directly in `Start()` as a blocking call. Move context-cancel and stop-signal checks into the same select:
```go
func (j *PaymentReconciliationJob) Start(ctx context.Context) error {
    select {
    case <-time.After(initialDelay):
        j.processReconciliation(ctx)
    case <-ctx.Done():
        return nil
    }
    ticker := time.NewTicker(24 * time.Hour)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            j.processReconciliation(ctx)
        case <-ctx.Done():
            return nil
        }
    }
}
```

---

### 🟡 NEW-03: `WebhookRetryWorker` Uses Busy-Wait (`time.Sleep(1s)`) Instead of Ticker — CPU-Inefficient

**File**: `payment/internal/worker/event/webhook_retry.go:45–57`

**Problem**: The webhook retry loop uses `time.Sleep(1 * time.Second)` in a tight loop with a `default:` case. This means:
- `processRetryQueue` is called ~once/second continuously with no backpressure.
- If the queue is empty, it still issues a DB query every second.
- CPU spin on idle pods (no exponential backoff, no adaptive interval).

```go
for {
    select {
    case <-ctx.Done(): ...
    case <-w.stopSignal: ...
    default:
        w.processRetryQueue(ctx)
        time.Sleep(1 * time.Second) // busy-wait
    }
}
```

**Fix**: Replace with `time.NewTicker(interval)` where `interval` is configurable (e.g., 30 seconds). Use blocking select on the ticker channel. Add exponential backoff when the queue is empty.

---

### 🟡 NEW-04: Payment Worker GitOps — `tcpSocket` Probes Not Upgraded to gRPC (Claimed Fixed, Still Broken)

**File**: `gitops/apps/payment/base/worker-deployment.yaml:72–81`

**Problem**: The previous sprint checklist claims this was fixed:
> **[P2]** Fix worker liveness/readiness probes to use gRPC health check → **Fixed**

But the **current `worker-deployment.yaml`** still uses `tcpSocket`:
```yaml
livenessProbe:
  tcpSocket:
    port: 5005
readinessProbe:
  tcpSocket:
    port: 5005
```

A `tcpSocket` probe only verifies the port is open — it cannot detect a hung gRPC server. The fix was documented but **not applied**. The payment worker's health is invisible to Kubernetes if the gRPC server accepts connections but stops processing.

**Fix**: Replace with gRPC probe (as in pricing and search worker-deployment.yaml):
```yaml
livenessProbe:
  grpc:
    port: 5005
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  grpc:
    port: 5005
  initialDelaySeconds: 10
  periodSeconds: 5
```

---

### 🔵 NEW-P2-01: Payment Worker GitOps — Missing `volumeMounts` for `config.yaml`

**File**: `gitops/apps/payment/base/worker-deployment.yaml`

**Problem**: The worker binary starts with `-conf /app/configs/config.yaml` but there is no `volumes` or `volumeMounts` section mounting the ConfigMap to `/app/configs`. The binary will fail to load `config.yaml` on startup unless the config is embedded in the image.

Compare: search worker has explicit `volumes` + `volumeMounts` mounting `search-config` ConfigMap to `/app/configs`.

**Fix**: Add:
```yaml
volumeMounts:
- mountPath: /app/configs
  name: config
  readOnly: true
volumes:
- name: config
  configMap:
    name: payment-config
```

---

### 🔵 NEW-P2-02: Reconciliation Alert Cooldown (`lastAlertTime` Map) Is In-Memory — Resets on Pod Restart

**File**: `payment/internal/worker/cron/payment_reconciliation.go:24,172–177`

**Problem**: Alert cooldown is tracked in `j.lastAlertTime map[string]time.Time` which is initialized as an empty map at construction. If the pod restarts between reconciliation runs, ALL cooldown state is lost → the next reconciliation may send alerts that should have been suppressed by the cooldown window.

On a daily reconciliation job this is low-impact, but during pod churn (deploy rollout during reconciliation window), multiple alert emails/PagerDuty notifications may fire.

**Fix**: Options: (a) Store cooldown timestamp in Redis with `SETNX EX` TTL, or (b) Accept the behavior given it's a daily job and document it in runbooks.

---

### 🔵 NEW-P2-03: `OutboxWorker.NewOutboxWorker` Hardcodes `pubsubName = "pubsub-redis"` — Not Configurable

**File**: `payment/internal/worker/event/outbox_worker.go:29`

**Problem**: The Dapr pubsub name is hardcoded as `"pubsub-redis"` at construction:
```go
pubsubName := "pubsub-redis"
```

If the environment uses a different Dapr pubsub component name (e.g. `"pubsub-kafka"` in production vs `"pubsub-redis"` in dev), events will publish to the wrong component or fail silently. Other consumers in the codebase read the pubsub name from config to allow env-specific override.

**Fix**: Read `pubsubName` from `config.AppConfig.Data.Eventbus.DefaultPubsub` (or equivalent), same pattern as search and pricing consumers.

---

## 5. GitOps Configuration Review

### 5.1 Payment Worker (`gitops/apps/payment/base/worker-deployment.yaml`)

| Check | Status |
|-------|--------|
| Dapr: `enabled=true`, `app-id=payment-worker`, `app-port=5005`, `grpc` | ✅ |
| `securityContext: runAsNonRoot, runAsUser: 65532` | ✅ |
| `envFrom: configMapRef: overlays-config` | ✅ |
| `envFrom: secretRef: payment-secrets` | ✅ |
| `resources.requests` + `resources.limits` | ✅ |
| **`livenessProbe`/`readinessProbe` uses `tcpSocket`** (not gRPC) | ❌ **[NEW-04]** — claimed fixed but not applied |
| **`volumeMounts` for `/app/configs/config.yaml`** | ❌ **[NEW-P2-01]** — missing |
| **`volumes` section with ConfigMap** | ❌ **[NEW-P2-01]** — missing |

### 5.2 Payment Main Deployment

| Check | Status |
|-------|--------|
| HTTP 8010, Dapr HTTP | ✅ |
| HPA (2–8 replicas, CPU 70% / mem 80%) | ✅ Fixed (Sprint 3) |
| `secretRef` in overlay for gateway API keys | ✅ `payment-secrets` |

---

## 6. Worker & Cron Jobs Audit

### 6.1 Payment Worker (Binary: `/app/bin/worker`)

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `outbox-worker` | Periodic | 5s tick, 24h cleanup | ✅ |
| `event-consumer-worker` | Event consumers | Real-time (Dapr) | ✅ — but no DLQ handlers ([NEW-01]) |
| `webhook-retry-worker` | Continuous | Effectively every ~1s | ⚠️ [NEW-03] busy-wait |
| `failed-payment-retry-job` | Cron | Every 15 min | ✅ |
| `refund-processing-job` | Cron | Every 10 min | ✅ |
| `auto-capture` | Cron | Configurable | ✅ |
| `payment-status-sync` | Cron | Configurable | ✅ |
| `bank-transfer-expiry` | Cron | Configurable | ✅ |
| `payment-reconciliation-job` | Cron | Daily 2 AM | ⚠️ [NEW-02] goroutine lifecycle issue |
| `cleanup` | Cron | Configurable | ✅ |

### 6.2 DLQ Coverage Matrix

| Consumer Topic | DLQ Topic | Drain Handler | Risk |
|---------------|-----------|--------------|------|
| `returns.return_completed` | `returns.return_completed.dlq` | ❌ None | Customer not refunded on return |
| `orders.order_cancelled` | `orders.order_cancelled.dlq` | ❌ None | Authorized funds held indefinitely |
| `orders.order_completed` | `orders.order_completed.dlq` | ❌ None | Seller payout/escrow never released |

---

## 7. Event Publishing Review — Confirmed Working

| Event | Via Outbox? | Status |
|-------|------------|--------|
| `payment.processed` | ✅ via InTx | ✅ |
| `payment.failed` | ✅ via InTx | ✅ |
| `payment.captured` | ✅ via InTx | ✅ |
| `payment.voided` | ✅ via InTx | ✅ |
| `payment.refunded` | ✅ via InTx (fixed) | ✅ Fixed Sprint 3 |
| `payment.status_changed` | ✅ via InTx (fixed) | ✅ Fixed Sprint 3 |
| `dispute.created/responded/status_changed` | ✅ via outbox (fixed) | ✅ Fixed Sprint 3 |
| `reconciliation.mismatch` | ⚠️ Direct publish | P2 — best-effort alerting acceptable |

---

## 8. Edge Cases — Summary

| Edge Case | Risk | Note |
|-----------|------|------|
| **Return/cancel/completed DLQ → refunds/voids/payouts never execute** | 🔴 P0 | [NEW-01] — Financial safety issue |
| **Reconciliation job goroutine detaches from Start() lifecycle** | 🟡 P1 | [NEW-02] — Partial reconciliation on SIGTERM |
| **tcpSocket probe can't detect hung gRPC worker** | 🟡 P1 | [NEW-04] — Claimed fixed, NOT applied |
| **Webhook retry busy-waits every 1s** | 🟡 P1 | [NEW-03] — DB query every second, no backoff |
| **Payment worker missing volumeMounts for config.yaml** | 🔵 P2 | [NEW-P2-01] — Startup failure if config not embedded |
| **Reconciliation alert cooldown lost on pod restart** | 🔵 P2 | [NEW-P2-02] — Duplicate alerts possible during rollout |
| **Outbox pubsubName hardcoded to `"pubsub-redis"`** | 🔵 P2 | [NEW-P2-03] — Not env-configurable |

---

## 9. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix Before Release

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-01]** | No DLQ drain handlers for `return.completed`, `order.cancelled`, `order.completed` — customer refunds & fund releases silent-fail | Add `Consume*DLQ` methods on each consumer; register in `EventConsumerWorker.Start` |

### 🟡 P1 — Fix in Next Sprint

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-02]** | `PaymentReconciliationJob.Start()` goroutine lifecycle — partial reconciliation on shutdown | Run ticker loop directly in `Start()` (blocking pattern like `OutboxWorker`) |
| **[NEW-03]** | `WebhookRetryWorker` busy-wait with `time.Sleep(1s)` | Replace with `time.NewTicker(30s)` and blocking select |
| **[NEW-04]** | Worker `tcpSocket` probes not upgraded to gRPC (claimed fixed, still broken) | Replace `tcpSocket` with `grpc` in `worker-deployment.yaml` |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Fix |
|----|-------------|-----|
| **[NEW-P2-01]** | Payment worker missing `volumeMounts` + `volumes` for `config.yaml` | Add volume + volumeMounts blocks |
| **[NEW-P2-02]** | Reconciliation cooldown in-memory — lost on restart | Redis-backed cooldown or document caveat |
| **[NEW-P2-03]** | OutboxWorker hardcodes `pubsubName = "pubsub-redis"` | Read from `config.AppConfig` |

---

## 10. What Is Already Well Implemented ✅ (Post-Sprint 3)

| Area | Evidence |
|------|----------|
| Runtime panic fix via adapter pattern | `PaymentEventAdapter` replaces unsafe assertion |
| `order.cancelled` consumer triggers `VoidPayment` | `event_consumer_worker.go:49–51` |
| `order.completed` consumer triggers escrow release / payout | `event_consumer_worker.go:53–56` |
| Outbox `InTx` for all payment state events | `usecase.go:214–258`, capture/void also transactional |
| Outbox cleanup (7d, 24h ticker) | `outbox_worker.go:56,64–65,140–149` |
| `FindRetryable` enforces `max_retries` | `data/outbox.go:130` |
| Dispute events: created/responded/status_changed implemented | `event_publisher.go:163–193` |
| HPA for payment main (2–8 replicas) | `gitops/apps/payment/base/hpa.yaml` |
| Distributed lock prevents concurrent double-payment | `usecase.go:113–123` (30s TTL Redis lock) |
| Refund TOCTOU fixed: `GetTotalRefundedAmount` inside `InTx` | `refund/usecase.go:93–98` |
| Outbox worker runs immediately on start | `outbox_worker.go:52–53` |
| Reconciliation job respects `ReconciliationEnabled` config flag | `payment_reconciliation.go:47–50` |
| Reconciliation alert cooldown (60 min default) | `payment_reconciliation.go:155–177` |
| Gateway provider read from metadata (not hardcoded) | `CreatePaymentFromGatewayData` reads `payment_provider` key |

---

## Related Files

| Document | Path |
|----------|------|
| Previous review (Sprint 1–3) | [payment-review.md](payment-review.md) |
| Pricing flow checklist | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

# Payment Flow — Business Logic Review Checklist

**Date**: 2026-03-07 (v3 — full re-audit following Shopify/Shopee/Lazada patterns)
**Reviewer**: AI Review (deep code scan — payment service)
**Scope**: `payment/` — payment processing, refund, webhook, reconciliation, workers, GitOps
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §7 (Payment Flows)

> v2 issues **all resolved**. New issues from this audit use `[V3-*]` tags.

---

## 📊 Summary (v3)

| Category | Sprint 1–3 | v2 Audit | This Audit (v3) |
|----------|-----------|----------|-----------------|
| 🔴 P0 — Critical | 3 → 3 fixed | 1 → ✅ fixed | 0 new |
| 🟡 P1 — High | 6 → 6 fixed | 3 → ✅ fixed | 3 new |
| 🔵 P2 — Medium | 6 → 6 fixed | 3 → ✅ fixed | 5 new |

---

## 1. v2 Issues — All Resolved ✅

### 1.1 DLQ Drain Handlers [v2 NEW-01] → ✅ FIXED

| Consumer | DLQ Method | Registered In Worker | Evidence |
|----------|-----------|---------------------|----------|
| `ReturnConsumer` | `ConsumeReturnCompletedDLQ` | ✅ `event_consumer_worker.go:59–61` | `return_consumer.go:108–121` |
| `OrderConsumer` | `ConsumeOrderCancelledDLQ` | ✅ `event_consumer_worker.go:62–64` | `order_consumer.go:93–106` |
| `OrderCompletedConsumer` | `ConsumeOrderCompletedDLQ` | ✅ `event_consumer_worker.go:65–67` | `order_completed_consumer.go:85–98` |

All 3 DLQ handlers implemented and registered. DLQ messages are ACK'd with `[DLQ_DRAIN]` log warning.

### 1.2 Reconciliation Job Lifecycle [v2 NEW-02] → ✅ FIXED

Reconciliation job now wraps `worker.CronWorker` (line 18, 42–45) instead of raw goroutine. `Start()` delegates to the CronWorker which handles the ticker loop and context cancellation correctly.

**Evidence**: `payment_reconciliation.go:18` — `type PaymentReconciliationJob struct{ *worker.CronWorker }`

### 1.3 WebhookRetryWorker Busy-Wait [v2 NEW-03] → ✅ FIXED

Uses `time.NewTicker(30 * time.Second)` with blocking `select` (line 48–62). No more `time.Sleep` busy-wait.

**Evidence**: `webhook_retry.go:48–62`

### 1.4 Worker Probes [v2 NEW-04] → ✅ FIXED

Payment now uses `common-worker-deployment-v2` component (via `kustomization.yaml:16`). The component defines `httpGet /healthz` probes with proper `startupProbe`, `livenessProbe`, `readinessProbe`. No more `tcpSocket`.

**Evidence**: `gitops/components/common-worker-deployment-v2/deployment.yaml:85–105`

### 1.5 Worker Volume Mounts [v2 NEW-P2-01] → ✅ FIXED

`common-worker-deployment-v2` component embeds the worker startup command with `-conf /app/configs/config.yaml`. Config is baked into the Docker image at build time via `Dockerfile`. No separate ConfigMap volume mount needed — consistent with all other services.

### 1.6 Reconciliation Alert Cooldown [v2 NEW-P2-02] → ✅ FIXED

Alert cooldown now uses Redis-backed keys with TTL (`SETNX EX`). No more in-memory map.

**Evidence**: `payment_reconciliation.go:49–69` — `isAlertCoolingDown()` checks Redis, `setAlertCooldown()` writes Redis key with TTL.

### 1.7 Outbox pubsubName Hardcoded [v2 NEW-P2-03] → ✅ FIXED

`OutboxWorker` reads `pubsubName` from `cfg.Data.Eventbus.DefaultPubsub` with fallback to `commonConstants.DaprDefaultPubSub`.

**Evidence**: `internal/worker/event/outbox_worker.go:31–34`

---

## 2. NEW Issues Found in This Audit (v3)

### 🟡 V3-01: `ConfirmCODCollection` Skips `CanTransitionTo` — Bypasses State Machine

**File**: `payment/internal/biz/payment/cod.go:159`

**Problem**: `ConfirmCODCollection` directly sets `payment.Status = PaymentStatusCaptured` without calling `payment.CanTransitionTo(PaymentStatusCaptured)`. Every other status update in the payment service (`ProcessPayment`, `CapturePayment`, `VoidPayment`, `MarkPaymentCompleted`, `expireBankTransferPayment`) properly validates the transition first.

If a COD payment is in a non-transitional state (e.g., already `cancelled` or `failed`), this bypasses the state machine and creates an invalid status transition.

Shopify/Lazada enforce state machine validation on every status change, including COD confirmation.

**Fix**:
```go
if !payment.CanTransitionTo(PaymentStatusCaptured) {
    return nil, fmt.Errorf("invalid status transition from %s to captured for COD collection", payment.Status)
}
payment.Status = PaymentStatusCaptured
```

---

### 🟡 V3-02: `voidAuthorizedPayments` Only Voids `authorized` — Misses `pending` Payments

**File**: `payment/internal/data/eventbus/order_consumer.go:139`

**Problem**: When `order.cancelled` event is received, `voidAuthorizedPayments` only processes payments with `PaymentStatusAuthorized` (line 139). But orders can be cancelled before payment completes (e.g., user cancels during 3DS challenge). Payments in `pending` or `requires_action` status are orphaned — they remain open and may eventually succeed after the order is already cancelled.

Shopee pattern: cancel/void all non-final payments for the order (pending, requires_action, authorized).

**Fix**:
```go
for _, p := range payments {
    // Void/cancel all non-final payments
    if p.IsFinalStatus() {
        continue
    }
    switch p.Status {
    case payment.PaymentStatusAuthorized:
        // Void authorized payments via gateway
        _, err := c.paymentUc.VoidPayment(ctx, &payment.VoidPaymentRequest{...})
    case payment.PaymentStatusPending, payment.PaymentStatusRequiresAction:
        // Cancel pending/in-progress payments directly (no gateway void needed)
        _, err := c.paymentUc.UpdatePaymentStatus(ctx, p.PaymentID, payment.PaymentStatusCancelled, ...)
    }
}
```

---

### 🟡 V3-03: `capturePayment` (Scheduled) Skips `CanTransitionTo` on Capture Failure

**File**: `payment/internal/biz/payment/usecase.go:864`

**Problem**: When scheduled auto-capture fails at the gateway, the internal `capturePayment` method directly sets `payment.Status = PaymentStatusFailed` (line 864) without calling `CanTransitionTo(PaymentStatusFailed)`. The public `CapturePayment` method (line 529) correctly validates the transition, but the scheduled capture code path bypasses it.

This can cause an invalid transition if the payment has already been moved to a different state (e.g., voided by a concurrent `order.cancelled` event).

**Fix**: Add `CanTransitionTo` check before setting failed status:
```go
if !payment.CanTransitionTo(PaymentStatusFailed) {
    return fmt.Errorf("cannot transition payment %s from %s to failed", payment.PaymentID, payment.Status)
}
payment.Status = PaymentStatusFailed
```

---

### 🔵 V3-P2-01: Duplicate OutboxWorker Implementations — Confusing

**Files**:
- `payment/internal/worker/event/outbox_worker.go` (156 lines, uses Dapr publisher, 5s interval, 7-day cleanup)
- `payment/internal/worker/outbox/worker.go` (161 lines, uses `events.EventPublisher`, 1s interval, 30-day cleanup)

**Problem**: Two distinct `OutboxWorker` implementations exist with different intervals, cleanup policies, retry logic, and publisher types. Only one can be wired into the worker binary. This creates maintenance confusion — developers may edit the wrong file.

The `internal/worker/event/outbox_worker.go` version is the correctly wired one (uses Dapr publisher with config-based pubsub). The `internal/worker/outbox/worker.go` appears to be an older version that was superseded.

**Fix**: Remove or archive `internal/worker/outbox/worker.go` if it is not wired. Add a comment to the active worker explaining it is the canonical implementation.

---

### 🔵 V3-P2-02: `getBankTransferProvider` Always Returns `nil` — Bank Transfer Non-Functional

**File**: `payment/internal/biz/payment/bank_transfer.go:422`

**Problem**: After successfully selecting a bank transfer provider from config, `getBankTransferProvider` still returns `nil` (line 422) with a comment "TODO: Create actual provider instance". This means `CreateBankTransferPayment` will always fail at line 70–71 with `"bank transfer provider not available"`.

Bank transfer is a critical payment method for SEA markets (Shopee, Lazada). The selection logic is correctly implemented but the provider instantiation is missing.

**Fix**: Implement a provider factory that instantiates the actual `BankTransferProvider` from `selectedProvider` config. Until then, this feature should be disabled in config to avoid confusing errors.

---

### 🔵 V3-P2-03: COD Amount Mismatch Proceeds Without Flag

**File**: `payment/internal/biz/payment/cod.go:152–155`

**Problem**: `ConfirmCODCollection` logs a warning when `collectedAmount != expectedAmount` but continues processing. In Shopify/Lazada, COD amount mismatches are flagged for investigation (either short collection or overpayment). The current code silently accepts any amount.

**Fix**: Store the mismatch flag in metadata and optionally publish an alert event:
```go
if collectedAmount != expectedAmount {
    payment.Metadata["amount_mismatch"] = true
    payment.Metadata["expected_amount"] = expectedAmount
    payment.Metadata["mismatch_diff"] = collectedAmount - expectedAmount
}
```

---

### 🔵 V3-P2-04: Commission Rate Hardcoded in `MarkPaymentCompleted`

**File**: `payment/internal/biz/payment/usecase.go:931`

**Problem**: `const defaultCommissionRate = 0.10` is hardcoded. The TODO references `TA-1075` for making it configurable per seller/category. Until seller service is implemented, this should at minimum be read from `config.AppConfig` to allow environment-level override.

**Fix**: Read from config:
```go
commissionRate := uc.config.Payment.DefaultCommissionRate
if commissionRate == 0 {
    commissionRate = 0.10
}
```

---

### 🔵 V3-P2-05: Service Map Skill Outdated — Payment Event Consumers Incomplete

**File**: `.agent/skills/service-map/SKILL.md:141`

**Problem**: The service map shows payment only consumes `return_consumer`, but the actual code registers 3 consumers:
- `ReturnConsumer` → `orders.return.completed`
- `OrderConsumer` → `orders.order.cancelled`
- `OrderCompletedConsumer` → `orders.order.completed`

**Fix**: Update service map line 141 to:
```
| **payment** | return_consumer, order_consumer, order_completed_consumer |
```

---

## 3. Data Consistency Matrix

| Flow | Consistency Check | Status |
|------|------------------|--------|
| ProcessPayment → Order amount cross-validation | ✅ `orderClient.GetOrder` + epsilon comparison + currency match | ✅ |
| ProcessPayment → Idempotency | ✅ Idempotency key + distributed lock (30s TTL) | ✅ |
| ProcessPayment → Double-payment prevention | ✅ Lock + double-check existing payments after lock | ✅ |
| Refund → TOCTOU prevention | ✅ `GetTotalRefundedAmount` inside `InTx` + distributed lock | ✅ |
| Refund → Over-refund prevention | ✅ `totalRefunded + refundAmount > p.Amount` check | ✅ |
| CapturePayment → InTx + outbox | ✅ `transaction.InTx` wraps update + event publish | ✅ |
| VoidPayment → InTx + outbox | ✅ `transaction.InTx` wraps update + event publish | ✅ |
| StatusChange → InTx + outbox | ✅ `transaction.InTx` wraps update + event publish | ✅ |
| COD create → InTx + outbox | ✅ `transaction.InTx` wraps create + event publish | ✅ |
| COD confirm → InTx + outbox | ✅ `transaction.InTx` wraps update + event publish | ✅ |
| Bank transfer create → InTx + outbox | ✅ `transaction.InTx` wraps create + event publish | ✅ |
| Bank transfer confirm → InTx + outbox | ✅ `transaction.InTx` wraps update + event publish | ✅ |
| Bank transfer expire → InTx + outbox | ✅ `transaction.InTx` wraps update + event publish | ✅ |
| MarkPaymentCompleted → InTx + outbox | ✅ `transaction.InTx` wraps update + event publish | ✅ |
| Saga compensation → detached context | ✅ Uses `context.Background()` with 10s timeout | ✅ |

---

## 4. Outbox Pattern — Confirmed Working ✅

| Check | Status |
|-------|--------|
| Outbox worker runs immediately on start | ✅ `outbox_worker.go:60` |
| Outbox worker: 5s tick, batches 100 events | ✅ `outbox_worker.go:50,62` |
| 24h cleanup of published events > 7 days | ✅ `outbox_worker.go:63,147–157` |
| `ProcessPayment` — outbox inside `InTx` | ✅ `usecase.go:215–252` |
| `CapturePayment`/`VoidPayment` — `InTx` | ✅ `usecase.go:539–560,597–618` |
| Outbox `MarkFailed` is atomic (single UPDATE) | ✅ |
| `pubsubName` read from config | ✅ `outbox_worker.go:31–34` |
| DaprEventPublisher created with config pubsub | ✅ |

---

## 5. Event Publishing Review

| Event | Via Outbox (InTx)? | Status |
|-------|-------------------|--------|
| `payment.processed` | ✅ | ✅ |
| `payment.failed` | ✅ | ✅ |
| `payment.captured` | ✅ | ✅ |
| `payment.voided` | ✅ | ✅ |
| `payment.refunded` | ✅ | ✅ |
| `payment.status_changed` | ✅ | ✅ |
| `dispute.created/responded/status_changed` | ✅ | ✅ |
| `reconciliation.mismatch` | ⚠️ Direct publish | P2 — best-effort alerting acceptable |

### Does payment service need to publish events? ✅ YES

Payment events are consumed by:
- **order** service → `payment_consumer` (payment status → order status advance)
- **notification** service → order status notifications (payment confirmed → email/push)
- **analytics** service → payment metrics

All published events are necessary and correctly routed.

---

## 6. Event Subscription Review

### Does payment service need to subscribe to events? ✅ YES

| Consumer | Topic | Purpose | Needed? |
|----------|-------|---------|---------|
| `ReturnConsumer` | `orders.return.completed` | Auto-refund for completed returns | ✅ Critical |
| `OrderConsumer` | `orders.order.cancelled` | Void authorized payments | ✅ Critical |
| `OrderCompletedConsumer` | `orders.order.completed` | Mark payment completed, escrow release | ✅ Critical |

All 3 consumers are essential for the payment lifecycle.

### DLQ Coverage ✅

| Consumer | DLQ Handler | Status |
|----------|------------|--------|
| `ReturnConsumer` | `ConsumeReturnCompletedDLQ` | ✅ Registered |
| `OrderConsumer` | `ConsumeOrderCancelledDLQ` | ✅ Registered |
| `OrderCompletedConsumer` | `ConsumeOrderCompletedDLQ` | ✅ Registered |

---

## 7. GitOps Configuration Review ✅

### 7.1 Payment Worker

| Check | Status |
|-------|--------|
| Uses `common-worker-deployment-v2` component | ✅ `kustomization.yaml:16` |
| Dapr: `enabled=true`, `app-port=5005`, `grpc` protocol | ✅ `patch-worker.yaml:9–10` |
| `securityContext: runAsNonRoot, runAsUser: 65532` | ✅ (from component) |
| `envFrom: configMapRef + secretRef` | ✅ `patch-worker.yaml:25–28` |
| `resources.requests` + `resources.limits` | ✅ `patch-worker.yaml:36–42` |
| `startupProbe` / `livenessProbe` / `readinessProbe` (httpGet) | ✅ (from component) |
| initContainers: wait-for-consul, redis, postgres | ✅ `patch-worker.yaml:13–21` |
| Worker Dapr `app-id` propagated from metadata.name | ✅ `kustomization.yaml:189–199` |

### 7.2 Payment Main (API)

| Check | Status |
|-------|--------|
| HTTP 8005, gRPC 9005 port mapping | ✅ `kustomization.yaml:36–45` |
| HPA (via `hpa.yaml`) | ✅ |
| `secretRef: payment-secrets` | ✅ `patch-api.yaml:13` |
| Startup command: `/app/bin/payment -conf /app/configs/config.yaml` | ✅ `kustomization.yaml:53–54` |

### 7.3 Other Resources

| Resource | Status |
|----------|--------|
| `configmap.yaml` — payment-config | ✅ Sync-wave 0 |
| `migration-job.yaml` | ✅ |
| `networkpolicy.yaml` | ✅ |
| `pdb.yaml` + `worker-pdb.yaml` | ✅ |
| `serviceaccount.yaml` | ✅ |
| `servicemonitor.yaml` | ✅ |

---

## 8. Worker & Cron Jobs Audit

| Worker | Type | Schedule | Status |
|--------|------|----------|--------|
| `outbox-worker` | Periodic | 5s tick, 24h cleanup | ✅ |
| `event-consumer-worker` | Event consumers | Real-time (Dapr) + DLQ handlers | ✅ |
| `webhook-retry-worker` | Periodic | 30s ticker | ✅ |
| `failed-payment-retry-job` | Cron | Every 15 min | ✅ |
| `refund-processing-job` | Cron | Every 10 min | ✅ |
| `auto-capture` | Cron | Configurable | ⚠️ [V3-03] no CanTransitionTo on failure path |
| `payment-status-sync` | Cron | Configurable | ✅ |
| `bank-transfer-expiry` | Cron | Configurable | ✅ |
| `payment-reconciliation-job` | Cron | Daily (CronWorker) | ✅ |
| `cleanup` | Cron | Configurable | ✅ |

---

## 9. Edge Cases — Summary

| Edge Case | Risk | Issue |
|-----------|------|-------|
| COD confirmation bypasses state machine | 🟡 P1 | [V3-01] |
| Pending/requires_action payments orphaned on order cancel | 🟡 P1 | [V3-02] |
| Scheduled capture failure skips CanTransitionTo | 🟡 P1 | [V3-03] |
| Duplicate OutboxWorker implementations | 🔵 P2 | [V3-P2-01] |
| Bank transfer provider always returns nil | 🔵 P2 | [V3-P2-02] |
| COD amount mismatch silently accepted | 🔵 P2 | [V3-P2-03] |
| Commission rate hardcoded | 🔵 P2 | [V3-P2-04] |
| Service map outdated for payment consumers | 🔵 P2 | [V3-P2-05] |

---

## 10. Issue Priority Matrix

### 🟡 P1 — Fix in Next Sprint

| ID | Description | Fix |
|----|-------------|-----|
| **[V3-01]** | `ConfirmCODCollection` sets captured without `CanTransitionTo` check | Add validation before status change |
| **[V3-02]** | `voidAuthorizedPayments` ignores `pending`/`requires_action` payments on order cancel | Cancel/void all non-final payments |
| **[V3-03]** | `capturePayment` (scheduled) skips `CanTransitionTo` on failure | Add validation on failure path |

### 🔵 P2 — Roadmap / Tech Debt

| ID | Description | Fix |
|----|-------------|-----|
| **[V3-P2-01]** | Duplicate OutboxWorker in `worker/event/` and `worker/outbox/` | Remove or archive unused implementation |
| **[V3-P2-02]** | `getBankTransferProvider` always returns nil (bank transfer non-functional) | Implement provider factory or disable in config |
| **[V3-P2-03]** | COD amount mismatch logged but not flagged in metadata | Store mismatch flag + publish alert event |
| **[V3-P2-04]** | Commission rate hardcoded at 10% in `MarkPaymentCompleted` | Read from `config.AppConfig` |
| **[V3-P2-05]** | Service map skill shows 1 consumer, actual has 3 | Update `.agent/skills/service-map/SKILL.md` |

---

## 11. What Is Already Well Implemented ✅

| Area | Evidence |
|------|----------|
| **All v2 issues resolved** | DLQ handlers, reconciliation lifecycle, webhook ticker, probes, cooldown, pubsub config |
| ProcessPayment: order amount + currency cross-validation | `usecase.go:80–101` |
| ProcessPayment: distributed lock (30s TTL) | `usecase.go:114–124` |
| ProcessPayment: double-check after lock | `usecase.go:127–136` |
| ProcessPayment: idempotency (Begin/MarkCompleted) | `usecase.go:103–112,266–269` |
| ProcessPayment: saga compensation with detached ctx | `usecase.go:212–263` |
| ProcessPayment: state machine validation | `usecase.go:174,187,197` |
| Gateway failover with per-attempt transaction ID | `usecase.go:717–795` |
| Refund: distributed lock + TOCTOU prevention in InTx | `refund/usecase.go:18–27,93–105` |
| Refund: window check (configurable days) | `refund/usecase.go:41–57` |
| Refund: auto-adjust type (full/partial) | `refund/usecase.go:60–68` |
| Refund: transaction record creation | `refund/usecase.go:169–188` |
| COD: shipping availability check via client | `cod.go:51–68` |
| COD: location-based fee adjustments | `cod.go:196–319` |
| Bank transfer: webhook signature verification (HMAC) | `bank_transfer.go:220–269` |
| Bank transfer: expiry processing | `bank_transfer.go:436–553` |
| Reconciliation: Redis-backed alert cooldown | `payment_reconciliation.go:49–69` |
| Reconciliation: configurable thresholds | `payment_reconciliation.go:96–113` |
| MarkPaymentCompleted: commission + seller payout calc | `usecase.go:930–986` |
| Money type with cent-based arithmetic | `payment.go:17–147` |
| Fraud detection with score, status, block | `usecase.go:158–168` |
| All event publishes wrapped in InTx with outbox | Every status-changing operation |

---

## Related Files

| Document | Path |
|----------|------|
| Previous review (v2) | This file (history preserved above) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |
| Payment usecase | [usecase.go](file:///Users/tuananh/Desktop/myproject/microservice/payment/internal/biz/payment/usecase.go) |
| Refund usecase | [usecase.go](file:///Users/tuananh/Desktop/myproject/microservice/payment/internal/biz/refund/usecase.go) |
| Event consumer worker | [event_consumer_worker.go](file:///Users/tuananh/Desktop/myproject/microservice/payment/internal/worker/event/event_consumer_worker.go) |
| Outbox worker (active) | [outbox_worker.go](file:///Users/tuananh/Desktop/myproject/microservice/payment/internal/worker/event/outbox_worker.go) |
| GitOps kustomization | [kustomization.yaml](file:///Users/tuananh/Desktop/myproject/microservice/gitops/apps/payment/base/kustomization.yaml) |

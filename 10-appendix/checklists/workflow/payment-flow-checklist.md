# Payment Flow — Business Logic Checklist

**Last Updated**: 2026-02-21
**Pattern Reference**: Shopify, Lazada, Shopee — `docs/10-appendix/ecommerce-platform-flows.md` §Payment
**Services Reviewed**: `payment/`
**Reviewer**: Antigravity Agent

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented correctly |
| ⚠️ | Risk / partial — needs attention |
| ❌ | Missing / broken |
| 🔴 | P0 — blocks production |
| 🟡 | P1 — reliability risk |
| 🔵 | P2 — improvement / cleanup |

---

## 1. Data Consistency

### 1.1 Payment Processing (`ProcessPayment`)

| Check | Status | Notes |
|-------|--------|-------|
| Amount cross-validated against Order service before processing | ✅ | `usecase.go:79-100` — epsilon comparison (0.005) |
| Currency validated against Order service | ✅ | `usecase.go:92-94` |
| Idempotency key includes order_id, customer_id, amount (in cents), method_id | ✅ | `usecase.go:386-392` — avoids float precision issue |
| Distributed lock acquired before DB check to prevent race conditions | ✅ | `usecase.go:113-123` — 30s TTL |
| Double-check for existing authorized/captured payment after acquiring lock | ✅ | `usecase.go:125-135` |
| DB save + outbox event publish wrapped in single transaction (saga) | ✅ | `usecase.go:214-258` — uses `InTx` |
| Saga compensation: delete payment if outbox insert fails | ✅ | `usecase.go:220-224` |
| State machine transition validated before every status change | ✅ | `usecase.go:173,186,196,501,559` — `CanTransitionTo` |
| Gateway failover: unique transaction ID per retry attempt | ✅ | `usecase.go:743` — `fmt.Sprintf("%s_gw%d", base, i)` |
| `CreatePaymentFromGatewayData` (reconciliation): hardcodes `PaymentProvider: "stripe"` | ⚠️ | `usecase.go:303` — multi-gateway setups using PayPal/Adyen will create reconciliation-created payments with wrong provider label |
| `UpdatePaymentStatus` publishes event **outside** a transaction | ⚠️ | `usecase.go:462-466` — DB update committed, then event published via direct Dapr. If Dapr publish fails, order service never knows status changed. |

### 1.2 Refund (`ProcessRefund`)

| Check | Status | Notes |
|-------|--------|-------|
| Distributed lock on `payment:lock:refund:<paymentID>` prevents concurrent over-refund | ✅ | `refund/usecase.go:18-27` |
| Refund amount checked: `totalRefunded + refundAmount ≤ payment.Amount` | ✅ | `refund/usecase.go:82-84` |
| Refund window configurable (default 30 days), falls back to `CreatedAt` if no capture time | ✅ | `refund/usecase.go:41-57` |
| Refund record created → gateway called → status updated all in one transaction | ✅ | `refund/usecase.go:105-199` |
| `totalRefunded` read **before** lock, creating a TOCTOU window | ⚠️ | `refund/usecase.go:71-75` — `GetTotalRefundedAmount` called outside the InTx. A concurrent refund could pass this check and both submit to gateway before either commits. Lock partially mitigates, but only within this process instance. Needs DB-level locking (SELECT FOR UPDATE on sum). |
| Payment status update on refund failure path silently swallows error | ⚠️ | `refund/usecase.go:164-167` — `"Don't fail the refund if payment update fails"` — leaves payment status and refund amount inconsistent |
| Transaction record creation silently swallowed | ⚠️ | `refund/usecase.go:185-188` — `"Don't fail refund if txn record creation fails"` — audit trail is incomplete |
| Refund event publisher interface mismatch (see §3) | 🔴 | `refund/usecase.go:192` — calls `eventPublisher.PublishPaymentRefunded(ctx, paymentID, refundID, amount)` which does NOT match `biz/events.EventPublisher` signature |

### 1.3 Webhook Event Handlers

| Check | Status | Notes |
|-------|--------|-------|
| Idempotency check using gateway webhook ID before processing | ✅ | `webhook/handler.go:68-84` |
| Signature validation + timestamp tolerance (5 min) | ✅ | `webhook/handler.go:98-106,159-165` |
| `handlePaymentSucceeded`: DB update + event publish NOT in a transaction | ⚠️ | `event_handlers.go:35-42` — DB update committed, then event fired. If Dapr publish fails, order won't be notified. |
| `handleRefundSucceeded`: loads all payment refunds, iterates to match by `GatewayRefundID` | ⚠️ | `event_handlers.go:121-141` — O(n) scan of all refunds per payment. For payments with many refunds, this is slow. Should query directly by gateway refund ID. |
| `handleDisputeCreated`: updates payment to `disputed` status but publishes **zero events** | ❌ | `event_handlers.go:146-171` — no outbox event, no Dapr publish. Downstream finance/fraud systems won't know about disputes. |
| `handlePaymentMethodCreated`: stub (no-op) | ⚠️ | `event_handlers.go:174-180` — placeholder; if gateway sends this event, no state is updated |

---

## 2. Outbox / Saga / Retry Pattern

### 2.1 Outbox Consistency

| Check | Status | Notes |
|-------|--------|-------|
| `ProcessPayment` uses outbox correctly (event created inside DB transaction) | ✅ | `usecase.go:227-238` |
| `CapturePayment` / `VoidPayment` use `InTx` for DB update + event publish | ✅ | `usecase.go:511-521,569-579` |
| Outbox worker polls every 5s, batch size 100 | ✅ | `outbox_worker.go:50,55,43` |
| **`biz/events.EventPublisher` (used by webhook + UpdatePaymentStatus) publishes DIRECTLY to Dapr** | 🔴 | `biz/events/event_publisher.go:98-128` — This is NOT an outbox write. `ServiceEventPublisher.PublishPaymentProcessed/Failed/Refunded` call `daprPublisher.PublishEvent` directly. If Dapr is temporarily unavailable, events are **silently lost**. There is no retry mechanism. |
| `UpdatePaymentStatus` publishes directly (not via outbox) | 🔴 | `usecase.go:463` — calls `eventPublisher.PublishPaymentStatusChanged` directly, outside transaction. |
| Outbox `MarkFailed` does not increment retry count — the `FindRetryable` query must filter by retry count to prevent infinite loops | ⚠️ | `outbox_worker.go:113` + `outbox.go:38` — `MarkFailed` only sets error message. There is no `MaxRetries` cap visible at the worker level. |
| Outbox cleanup (`DeleteOldEvents`) is not called by the worker — accumulates forever | ⚠️ | `outbox.go:45` method defined on interface but never called by `OutboxWorker`. Only `FindRetryable`/`MarkPublished`/`MarkFailed` are called. |

### 2.2 Saga Correctness

| Check | Status | Notes |
|-------|--------|-------|
| `ProcessPayment` compensation function calls `paymentRepo.Delete` — method `Delete` may not exist | ⚠️ | `usecase.go:223` — comment says `"Assume we add Delete method"`. If this is not implemented in the repo, compensation panics or silently fails, leaving an orphan payment record. |
| Compensation actions are closure-captured with same `ctx` — if ctx is cancelled, compensation fails | ⚠️ | `usecase.go:221-224` — should use `context.Background()` or a timeout context for compensation |

---

## 3. Interface Mismatches & Bugs 🔴

### 3.1 Two Different `EventPublisher` Interfaces

The codebase has **two incompatible `EventPublisher` interfaces**:

| Package | Interface | Method Signatures |
|---------|-----------|-------------------|
| `internal/events` | `events.EventPublisher` | `PublishPaymentProcessed(ctx, *PaymentProcessed)` |
| `internal/biz/events` | `events.EventPublisher` | `PublishPaymentProcessed(ctx, *PaymentProcessed)` |
| `internal/biz/payment` | `payment.EventPublisher` | `PublishPaymentProcessed(ctx, paymentID, orderID string, amount float64, currency string)` |

`webhook/event_handlers.go:40` calls `h.eventPublisher.PublishPaymentProcessed(ctx, pmt.PaymentID, pmt.OrderID, pmt.Amount, pmt.Currency)` — this matches `payment.EventPublisher`, NOT `biz/events.EventPublisher`. Two parallel implementations exist which means the codebase compiles only because `Handler.eventPublisher` is typed as `payment.EventPublisher`, but the actual payment.EventPublisher **interface is NOT declared in biz/events/event_publisher.go** — there is a separate `payment.EventPublisher` interface in `biz/payment/interfaces.go`. If these get swapped, production silently calls wrong implementation.

### 3.2 Runtime PANIC in `PublishPaymentStatusChanged`

```go
// biz/events/event_publisher.go:196-199
event := map[string]interface{}{
    "payment_id": payment.(map[string]interface{})["payment_id"], // PANIC
    "old_status": oldStatus,
    "new_status": payment.(map[string]interface{})["status"],     // PANIC
}
```

`UpdatePaymentStatus` calls `eventPublisher.PublishPaymentStatusChanged(ctx, payment, oldStatus)` where `payment` is `*payment.Payment`. The implementation type-asserts it to `map[string]interface{}` — **this panics at runtime**. Every call to `UpdatePaymentStatus` that succeeds in DB update will then panic and crash the goroutine.

### 3.3 Dispute Events Are All Stubs

```go
// biz/events/event_publisher.go:163-175
func (p *ServiceEventPublisher) PublishDisputeCreated(...) error { return nil }
func (p *ServiceEventPublisher) PublishDisputeResponded(...) error { return nil }
func (p *ServiceEventPublisher) PublishDisputeStatusChanged(...) error { return nil }
```

Dispute events are no-ops. Webhook properly detects disputes (`handleDisputeCreated`) and updates payment status, but publishes nothing downstream. Finance/fraud/analytics will not receive chargeback notifications.

---

## 4. Event Publishing — What Is Actually Needed?

### 4.1 Events Payment Should Publish

| Event | Topic | Currently Published | Via Outbox? | Needed? | Assessment |
|-------|-------|---------------------|-------------|---------|------------|
| `payment.processed` | `payment.processed` | ✅ | ✅ (via sagaFn in ProcessPayment) | ✅ Yes — Order service confirms payment | Correct for ProcessPayment; broken for webhook (direct) |
| `payment.failed` | `payment.failed` | ✅ | ✅ (via sagaFn) | ✅ Yes — Order moves to failed | Correct for ProcessPayment; broken for webhook (direct) |
| `payment.captured` | `payment.captured` | ✅ | ✅ (via InTx) | ✅ Yes — Order confirms fulfillment | ✅ Correct |
| `payment.voided` | `payment.voided` | ✅ | ✅ (via InTx) | ✅ Yes — Order releases inventory | ✅ Correct |
| `payment.refunded` | `payment.refunded` | ✅ | ❌ Direct | ✅ Yes — Order updates refund status | 🔴 Broken — direct Dapr, not outbox |
| `payment.status_changed` | `payment.status_changed` | ✅ | ❌ Direct + PANIC | ⚠️ Partial — analytics/admin only | 🔴 Runtime panic |
| `dispute.created` | `dispute.created` | ❌ No-op | ❌ | ✅ Yes — finance/fraud must know | ❌ Missing |
| `reconciliation.mismatch` | `reconciliation.mismatch` | ✅ | ❌ Direct | ⚠️ Admin alerting only | ⚠️ OK as alerting-only, but loses event on Dapr downtime |

### 4.2 Events Payment Should Subscribe To

| Event | Topic | Currently Subscribed | Needed? | Assessment |
|-------|-------|---------------------|---------|------------|
| `returns.return_completed` | `returns.*` | ✅ | ✅ Yes — trigger refund on return | ✅ Correct |
| `orders.order_cancelled` | `orders.*` | ❌ | ✅ Yes — void/release authorized payment | ❌ Missing — cancelled orders leave authorized payments hanging indefinitely |
| `orders.order_status_changed` | `orders.*` | ❌ | ⚠️ — only need cancel transition | ❌ Missing if no order.cancelled subscription |
| `pricing.price.updated` | `pricing.*` | ❌ | ❌ No | ✅ Correct — payment does not need price events |
| `promotion.applied` | `promotion.*` | ❌ | ❌ No | ✅ Correct |

---

## 5. Worker & Cron Job Summary

| Worker | Type | Interval | Purpose | Status |
|--------|------|----------|---------|--------|
| `outbox-worker` | Periodic | 5s, batch 100 | Publishes pending outbox events to Dapr | ✅ Running; ⚠️ no cleanup, no retry cap |
| `event-consumer-worker` | Event-driven | Push | Subscribes to `returns.return_completed` | ✅ Running |
| `failed-payment-retry-job` | Cron | Every 15 min | Retries failed payments with exponential backoff, moves to DLQ at max retries | ✅ Running |
| `refund-processing-job` | Cron | Every 10 min | Processes pending refunds | ✅ Running |
| `auto-capture` | Cron | (see below) | Auto-captures authorized payments after delay | ✅ Running |
| `payment-status-sync` | Cron | (see below) | Syncs payment status with gateways | ✅ Running |
| `bank-transfer-expiry` | Cron | (see below) | Expires unpaid bank transfer payments | ✅ Running |
| `payment-reconciliation-job` | Cron | Daily at 2 AM | Reconciles payment records with gateway | ✅ Running; triggers alert events |
| `cleanup` | Cron | (see below) | Purges old records | ✅ Running |

---

## 6. GitOps Configuration

| Check | Status | Notes |
|-------|--------|-------|
| `worker-deployment.yaml` exists | ✅ | `gitops/apps/payment/base/worker-deployment.yaml` |
| Worker has `secretRef: payment-secrets` | ✅ | `worker-deployment.yaml:61-62` — DB/gateway creds available |
| Worker has `configMapRef: overlays-config` | ✅ | `worker-deployment.yaml:59-60` |
| Worker Dapr: `grpc`, port `5005` | ✅ | |
| Worker liveness probe: `tcpSocket` on 5005 | ⚠️ | `worker-deployment.yaml:73-75` — tcpSocket only checks port open, not actual worker health. Should use gRPC health probe like pricing worker. |
| Main deployment: HTTP 8010, Dapr HTTP | ✅ | Matches PORT_ALLOCATION_STANDARD |
| No Secret for main deployment (only configMap) | ⚠️ | `deployment.yaml` only has `configMapRef: overlays-config`. If payment gateway API keys are not in overlays-config, the main service can't call gateways. Verify dev/prod secrets are mounted in overlay. |
| HPA for main deployment | ❌ | No HPA — high traffic payments service should have HPA |

---

## 7. Edge Cases & Risk Items

### 7.1 Payment Processing

| # | Risk | Severity | Notes |
|---|------|----------|-------|
| E1 | `PublishPaymentStatusChanged` **PANICS at runtime** — unsafe type assertion `payment.(map[string]interface{})` on `*Payment` struct | 🔴 P0 | `biz/events/event_publisher.go:196-199` — crash on every status update |
| E2 | Authorized payments are never voided if order is cancelled — no `order.cancelled` event subscription | 🔴 P0 | `event/event_consumer_worker.go` — only return.completed subscribed; authorized amount held forever |
| E3 | `biz/events.ServiceEventPublisher` publishes directly to Dapr (not outbox) — events lost when Dapr sidecar is down or restarts | 🔴 P0 | `biz/events/event_publisher.go:98-128` — affects `payment.refunded`, `payment.status_changed`, webhook-triggered events |
| E4 | Dispute events are stub no-ops — no downstream notification on chargebacks | 🟡 P1 | `biz/events/event_publisher.go:163-175` |
| E5 | `ProcessRefund`: `GetTotalRefundedAmount` called before distributed lock (TOCTOU window) — concurrent refunds from different instances can both pass the amount check | 🟡 P1 | `refund/usecase.go:71-75` vs `85-84` — add SELECT FOR UPDATE on refund sum |
| E6 | `ProcessPayment` compensation closes over request `ctx` — if ctx is cancelled (e.g. client disconnects), DB delete compensation also fails | 🟡 P1 | `usecase.go:221-224` — use detached context for compensation |
| E7 | `CreatePaymentFromGatewayData` hardcodes `PaymentProvider: "stripe"` | 🟡 P1 | `usecase.go:303` — multi-provider setup breaks reconciliation attribution |
| E8 | Outbox `DeleteOldEvents`/`DeleteOld` never called — outbox table grows unbounded | 🟡 P1 | `outbox.go:45-46` cleanup methods exist but no cron calls them |
| E9 | Outbox worker does not enforce `MaxRetries` — poison-pill events loop forever | 🟡 P1 | `outbox_worker.go:106-127` — `FindRetryable` must filter by max retries |
| E10 | `handleRefundSucceeded` webhook scans all refunds per payment to find matching gateway refund ID (O(n)) | 🔵 P2 | `event_handlers.go:121-140` — add index or repo method by gateway refund ID |
| E11 | `handlePaymentSucceeded` webhook updates DB + publishes event without a wrapping transaction | 🔵 P2 | `event_handlers.go:35-42` — use `InTx` |
| E12 | `handlePaymentMethodCreated` is a no-op placeholder — payment methods created via gateway webhook are never saved locally | 🔵 P2 | `event_handlers.go:174-180` |
| E13 | Refund transaction record creation failure is silently swallowed | 🔵 P2 | `refund/usecase.go:185-188` — audit trail incomplete |
| E14 | Worker liveness probe uses `tcpSocket` not gRPC health check | 🔵 P2 | `worker-deployment.yaml:72-75` — use `grpc` probe as pricing worker does |
| E15 | No HPA for payment main deployment — payment service is highest-traffic and should auto-scale | 🔵 P2 | `gitops/apps/payment/base/` |

---

## 8. Summary of Findings

| Priority | Count | Key Items |
|----------|-------|-----------|
| 🔴 P0 | 3 | E1: Runtime panic in PublishPaymentStatusChanged; E2: No order.cancelled subscription → authorized payments hang; E3: Direct Dapr publish in biz/events bypasses outbox — events lost on Dapr downtime |
| 🟡 P1 | 6 | E4: Dispute events no-op; E5: TOCTOU refund overspend window; E6: Compensation ctx cancel; E7: Hardcoded stripe provider; E8: Outbox never cleaned; E9: No retry cap |
| 🔵 P2 | 6 | E10–E15: Webhook scan O(n), missing InTx, no-op payment method, silent audit swallow, wrong liveness probe, no HPA |

---

## 9. Action Items

- [ ] **[P0]** Fix `PublishPaymentStatusChanged` in `biz/events/event_publisher.go` — replace unsafe type assertion, use `*payment.Payment` struct directly
- [ ] **[P0]** Add `order.cancelled` event consumer to trigger `VoidPayment` for authorized payments
- [ ] **[P0]** Move `biz/events.ServiceEventPublisher` to write to outbox (not direct Dapr) for at-least-once delivery guarantee; or route all callers through the outbox `EventPublisher` adapter
- [ ] **[P1]** Implement `PublishDisputeCreated/Responded/StatusChanged` with real outbox writes
- [ ] **[P1]** Fix TOCTOU in `ProcessRefund` — use `SELECT FOR UPDATE` aggregate for total refunded amount
- [ ] **[P1]** Fix saga compensation to use detached `context.Background()`, not request context
- [ ] **[P1]** Verify `paymentRepo.Delete` exists; if not, add it (compensation will panic)
- [ ] **[P1]** Add outbox cleanup cron job (call `DeleteOldEvents`/`DeleteOld` daily)
- [ ] **[P1]** Add `MaxRetries` enforcement in `FindRetryable` SQL query
- [ ] **[P2]** Extract `CreatePaymentFromGatewayData` provider from gateway metadata, not hardcoded `"stripe"`
- [ ] **[P2]** Add repo method to find refund by `GatewayRefundID` directly (avoid O(n) scan in webhook handler)
- [ ] **[P2]** Wrap `handlePaymentSucceeded`, `handleRefundSucceeded` webhook updates in `InTx`
- [ ] **[P2]** Implement `handlePaymentMethodCreated` webhook handler
- [ ] **[P2]** Fix worker liveness probe to use gRPC health check instead of `tcpSocket`
- [ ] **[P2]** Add HPA for payment main deployment

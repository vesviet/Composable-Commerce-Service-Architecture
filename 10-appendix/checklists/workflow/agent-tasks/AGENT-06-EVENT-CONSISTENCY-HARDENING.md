# AGENT-06: System-Wide Event & Saga Consistency Hardening

> **Created**: 2026-03-21
> **Priority**: P0 Critical
> **Sprint**: Architecture & Reliability Sprint
> **Services**: `order`, `gitops`
> **Source**: Meeting Review V1 & V2 - System-Wide Event Consistency 

---

## 📋 Overview

This batch addresses critical architecture flaws in the Event-Driven infrastructure and Saga State Machine. It focuses on resolving the P0 Silent Event Loss due to ephemeral Redis PubSub configurations and the P0 Missing Payment Refund gap in the Order Cancellation Saga.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Silent Event Loss via Redis PubSub Configuration
**File**: `gitops/components/dapr-resiliency/resiliency.yaml` (and related PubSub components)
**Risk**: Dapr's retry max is 5 with a 60s timeout. Because it uses standard Redis PubSub (which has no message persistence), if a subscriber Pod restarts or loses connection for ~1 minute, Dapr will drop the message. The Outbox table implies the message was successfully dispatched, leading to **permanent data mismatches**.

**Fix**:
1. Check `gitops/components` for the pubsub component definition (likely `pubsub-redis.yaml` or similar inside `common-infrastructure-envvars` or cluster configs).
2. Change the component type or configuration to use **Redis Streams** (or another persistent message broker if Redis is not intended for Streams).
    - If using Redis Streams for Dapr: Add `consumerID` and `enableTLS` metadata to the `pubsub.redis` Dapr component if applicable, ensuring un-acked messages remain in the stream. (Check Dapr docs for exact `redis` stream features).
3. If changing the underlying broker isn't possible, expand the `dapr-resiliency.yaml` PubSub intervals.
```yaml
      pubsubRetry:
        policy: exponential
        duration: 1s
        maxInterval: 60s
        maxRetries: 30 # Greatly increase retries so it covers normal downtime blocks (e.g. 5 mins)
```

**Validation**:
```bash
# Validate GitOps manifests
kubectl kustomize gitops/components/dapr-resiliency/
```


### [x] Task 2: Fix Order Cancellation Saga (Missing Payment Refunds)
**File**: `order/internal/biz/order/cancel.go`
**Lines**: ~90-100 (inside the `txCtx` transaction loop)
**Risk**: `CancelOrder` publishes `inventory.release.requested` to refund the warehouse stock, but completely skips refunding the payment! If an order is in `processing` or `paid` status (where `PaymentSagaState == captured`), the money is kept while the goods are restocked.

**Fix**:
1. Inject the `CancelOrder` logic to check `updatedOrder.PaymentSagaState == constants.PaymentSagaStateCaptured` (or similar logic mapping to paid status).
2. If true, emit a `payment.refund.requested` Outbox payload within the `txCtx` transaction **before** or **after** the stock release event.
3. Validate that `CancelOrder` correctly populates the Outbox row for the payment service.
```go
// Inside CancelOrder txCtx:
if lockedOrder.PaymentSagaState != nil && *lockedOrder.PaymentSagaState == constants.PaymentSagaStateCaptured {
    // 5. Publish refund requested event
    // Create payload, insert into Outbox
}
```

**Validation**:
```bash
cd order && go test ./internal/biz/order -run TestCancelOrder_PaidOrderRefunds -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd order && wire gen ./cmd/server/ ./cmd/worker/
cd order && go build ./...
cd order && go test -race ./...
```

---

## 📝 Commit Format

```
fix(gitops): increase dapr pubsub resiliency retries to prevent silent message loss
fix(order): initiate payment refunds during order cancellation saga

- sec: guarantee saga rollback refunds for captured orders during cancellation
- infra: expand pubsub backoff window in dapr-resiliency

Closes: AGENT-06
```

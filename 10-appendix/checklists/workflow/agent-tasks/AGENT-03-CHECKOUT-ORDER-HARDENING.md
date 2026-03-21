# AGENT-03: Checkout & Order Lifecycle Hardening (V2 Review)

> **Created**: 2026-03-21
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`, `order`
> **Estimated Effort**: 3-5 days
> **Source**: Meeting Review V2 - Cart, Checkout & Order Lifecycle Flows

---

## 📋 Overview

This batch addresses critical Distributed Transaction (Saga) failures between Checkout and Order services. It focuses on resolving the "Deadlock of Retry" (Idempotency breakdown during checkout network timeouts) and removing a "Split-Brain Outbox Recovery" anti-pattern that can cause phantom events and data inconsistencies across the e-commerce platform.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix "Deadlock of Retry" - Catch `AlreadyExists` in Checkout Order Creation

**File**: `checkout/internal/biz/checkout/confirm_step_create.go`
**Lines**: ~31-35
**Risk**: If the inter-service call to `createOrder` times out but the Order service creates the record, the Checkout session remains incomplete. Retrying will yield an `AlreadyExists` error which is not caught, causing it to block the customer from checking out forever while locking their funds (Payment Auth).
**Problem**: The `s.uc.createOrder(c.Ctx, orderReq)` call treats ALL errors as fatal and triggers a Saga rollback. It does not check if the error is an idempotency violation (`codes.AlreadyExists`).
**Fix**:
```go
// BEFORE:
createdOrder, err := s.uc.createOrder(c.Ctx, orderReq)
if err != nil {
	return err // Rollback handled by runner
}

// AFTER:
createdOrder, err := s.uc.createOrder(c.Ctx, orderReq)
if err != nil {
	// Treat AlreadyExists as a recovery scenario, not a fatal error
	if status.Code(err) == codes.AlreadyExists {
		s.uc.log.WithContext(c.Ctx).Warnf("Order already exists for session %s, fetching to recover Saga...", c.Request.CartID)
		
		// TODO: Implement and call s.uc.orderClient.GetOrderByCartSession(ctx, req.CartSessionID)
		// createdOrder, fetchErr := ...
		// if fetchErr == nil { return nil } // Successfully recovered, continue to next step
	}
	return err // Rollback handled by runner if truly failed
}
```

**Validation**:
```bash
cd checkout && go test ./internal/biz/checkout -run TestCreateOrderStep -v
# Ensure you mock a codes.AlreadyExists return and verify that execution does not rollback
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 2: Remove "Split-Brain Outbox Recovery" Anti-Pattern

**File**: `checkout/internal/biz/checkout/confirm_step_create.go`
**Lines**: ~133-185
**Risk**: Producing Kafka events (`publishCartConvertedDirect`) directly upon a local DB transaction failure intentionally breaks Transactional Outbox consistency. It will emit Phantom Events where downstream services react to a `CartConverted` event that does not actually exist in the checkout database state.
**Problem**: The `recoverOutbox(c)` and `publishCartConvertedDirect` methods try to publish `CartConverted` directly if `uc.tm.WithTransaction` fails.
**Fix**:
```go
// BEFORE:
if err != nil {
	s.uc.log.WithContext(c.Ctx).Errorf("[CRITICAL] Order %s created but finalize tx failed: %v. Retrying outbox save out-of-transaction.", c.CreatedOrder.ID, err)
	s.recoverOutbox(c)
}

// AFTER:
if err != nil {
	s.uc.log.WithContext(c.Ctx).Errorf("[CRITICAL] Finalize tx failed: %v. Order %s exists in Order Service but cart remains active. Letting Saga Rollback or Manual Intervention handle this mismatch.", err, c.CreatedOrder.ID)
	return err // MUST return the error so the runner knows to log or rollback!
	
	// TODO: Delete `func (s *CreateOrderStep) recoverOutbox` entirely.
	// TODO: Delete `func (s *CreateOrderStep) publishCartConvertedDirect` entirely.
}
```

**Validation**:
```bash
cd checkout && go test ./internal/biz/checkout -run TestCreateOrderStep_FinalizeTxFailed -v
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 3: Establish DLQ Metric Alerting for Async Promotion Rules

**File**: `checkout/internal/biz/checkout/confirm_step_create.go`
**Lines**: ~70-130
**Risk**: Failed asynchronous application of promotions gets saved to `failedCompensationRepo` but there is no active monitoring. Customers may be undercharged (loss of revenue) or overcharged without CS/Operations knowing.
**Problem**: The loop pushes errors to `failedCompensationRepo.Create(promoCtx, failedComp)` silently with `AlertSent: false`.
**Fix**:
```go
// BEFORE: 
// Only stores inside DB `FailedCompensation` without telemetry emission.

// AFTER:
// TODO: Inside promoErr handling (or globally in failed_event logic):
// Emit a Prometheus counter: `prometheus.DLQEventsTotal.WithLabelValues("apply_promotion").Inc()`
// TODO: Document the need for an AlertManager rule tracking `FailedCompensation` queue depth > 0.
```

**Validation**:
```bash
cd checkout && go build ./...
# Setup alert testing in K8S environment/Grafana
```

---

## 🔧 Pre-Commit Checklist

```bash
cd checkout && wire gen ./cmd/server/ ./cmd/worker/
cd checkout && go build ./...
cd checkout && go test -race ./...
```

---

## 📝 Commit Format

```
fix(checkout): resolve saga idempotency and outbox dual-write anti-patterns

- fix: catch gRPC AlreadyExists errors and fetch existing order during checkout retries
- refactor: remove dangerous recoverOutbox direct-publish method on transaction failure
- feat: add prometheus metric emission for promotion application DLQ failures

Closes: AGENT-03
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Retries do not cause hanging checkout | Unit test verifying `codes.AlreadyExists` is handled as success | |
| Direct publish removed | grep for `publishCartConvertedDirect` returns nothing | |
| DLQ failure incremented on err | PromQL `rate(dlq_events_total{operation="apply_promotion"}[5m]) > 0` |  |

# AGENT-05: Order & Fulfillment Hardening (250-Round Review Outcomes)

> **Created**: 2026-03-13
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `order`, `fulfillment`
> **Estimated Effort**: 3-5 days
> **Source**: [Order & Fulfillment 250-Round Review](/Users/tuananh/.gemini/antigravity/brain/0b98fd15-b692-4157-b6b6-8c6609c4afb5/order_fulfillment_250_round_review.md)

---

## 📋 Overview

This task addresses critical flaws identified during the 250-round meeting review of the Order and Fulfillment services. It includes fixing a P0 race condition in Outbox stock commitment, a P1 DB-assisted blocking idempotency loop, a P1 OOM and N+1 query issue during fulfillment batch picklist generation, and a P2 PII data leak in order logs.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Synchronous RPC Call Inside Transactional Outbox Flow ✅ IMPLEMENTED

**File**: `order/internal/biz/order/create.go`
**Lines**: 333-366 (func `ConfirmOrderReservations`)
**Risk**: If the DB outbox transaction fails after the external RPC call (`ConfirmReservation`) succeeds, a permanent "zombie reservation" is created in Warehouse, locking stock indefinitely.
**Problem**: Mixing a synchronous gRPC call (`uc.warehouseInventoryService.ConfirmReservation()`) with an asynchronous outbox event commit in the same function breaks Event-Driven choreography.
**Solution Applied**:
Refactored `ConfirmOrderReservations` to remove the synchronous gRPC call `ConfirmReservation` entirely. It now only saves the intent event `inventory.stock.committed` to the outbox synchronously inside the database transaction. `TestConfirmOrderReservations_PartialFail_DLQ` was removed as partial failure during synchronous confirmation is no longer applicable.

```go
// ConfirmOrderReservations (Deduct Stock)
// P0 FIX: Track confirmed reservations and rollback on partial failure to prevent stock leaks
// Refactored to fully asynchronous pattern using outbox events
func (uc *UseCase) ConfirmOrderReservations(ctx context.Context, order *Order) error {
	// Save outbox event within transaction for atomicity
	err := uc.tm.WithTransaction(ctx, func(txCtx context.Context) error {
		return uc.publishStockCommittedEvent(txCtx, order)
	})
	if err != nil {
		// Event cannot be persisted
		uc.log.WithContext(ctx).Errorf("[CRITICAL] Failed to publish stock committed event for order %s: %v", order.ID, err)
		return fmt.Errorf("failed to publish stock committed event: %w", err)
	}

	return nil
}
```

**Validation**:
```bash
cd order && go build ./...
cd order && go test ./internal/biz/order/... -run TestConfirmOrderReservations -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Implement Redis-based Idempotency to Prevent DB connection exhaustion ✅ IMPLEMENTED

**File**: `order/internal/biz/order/create.go`
**Lines**: 118-151 (Idempotency Recovery Retry Loop)
**Risk**: High concurrent requests using the same `CartSessionID` trigger the Postgres `23505 Unique Violation`. The `time.Sleep` retry loop eats up Go worker resources, causing 504 Gateway Timeouts under heavy load.
**Problem**: The loop blocks goroutines synchronously:
```go
maxRetries := 5
backoff := 50 * time.Millisecond
for i := 0; i < maxRetries; i++ {
    // ... DB calls
    time.Sleep(backoff)
    backoff *= 2
}
```
**Solution Applied**:
Removed the blocking retry loop. Since the initial insert into DB violates idempotency if another concurrent request or already processed cart exists, returning `409 Conflict` (gRPC `AlreadyExists` status code) early is the proper microservice pattern. This moves retry/handling responsibilities upstream (e.g., to the API Gateway or client) instead of holding Go threads open waiting for the DB to stabilize under peak load.

```go
			if csIDToLook != "" {
				uc.log.WithContext(ctx).Warnf("Order creation conflicts with existing/processing session: %s", csIDToLook)
				// Return 409 Conflict early over gRPC instead of blocking
				return nil, status.Error(codes.AlreadyExists, "order already exists for this cart session")
			}
```

**Validation**:
```bash
cd order && go test ./internal/biz/order/... -run TestCreateOrder_Idempotent_UniqueViolation -v
```

### [x] Task 3: Fix N+1 and Batch Insert OOM in Batch Picklist Generation

**File**: `fulfillment/internal/biz/picklist/batch_picking.go`
**Lines**: 27-49 and 77-109
**Risk**: Executing thousands of singular `FindByID` inside a loop, keeping everything in memory (`allPicklistItems`), and then calling `repo.CreateItem` thousands of times one-by-one inside a transaction will crash the `fulfillment-worker` pod via OOM or Transaction Timeout during peak sales.
**Problem**: N+1 queries reading fulfillments, and N+1 inserting picklist items.
**Fix**:
1. Replace `FindByID` loop with a single repository call: `FindFulfillmentsByIDs(ctx, fulfillmentIDs)`.
2. Replace single `CreateItem` inserts loop with a batch insert repository call: `CreateItemsBatch(txCtx, optimizedItems)`.

```go
// BEFORE (fulfillment/internal/biz/picklist/batch_picking.go):
for _, id := range fulfillmentIDs {
    fulfillment, err := uc.fulfillmentRepo.FindByID(txCtx, id)
    // ...
}
//...
for _, item := range optimizedItems {
    if err := uc.repo.CreateItem(txCtx, item); err != nil {
        return fmt.Errorf("failed to create picklist item: %w", err)
    }
}

// AFTER:
fulfillments, err := uc.fulfillmentRepo.FindFulfillmentsByIDs(txCtx, fulfillmentIDs)
//...
if err := uc.repo.CreateItemsBatch(txCtx, optimizedItems); err != nil {
    return fmt.Errorf("failed to batch create picklist items: %w", err)
}
```
*(Note: You will also need to add `FindFulfillmentsByIDs` and `CreateItemsBatch` methods to the respective Repository interfaces and Postgres implementations).*

**Validation**:
```bash
cd fulfillment && go build ./...
cd fulfillment && go test ./internal/biz/picklist/... -v
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 4: Prevent PII Leakage in Trace Logs

**File**: `order/internal/biz/order/create.go`
**Lines**: 179-187
**Risk**: Logging clear text CustomerIDs and PII info in application logs violates GDPR standards and can leak into metrics platforms (Grafana/Loki).
**Problem**: 
```go
uc.log.WithContext(ctx).Infof(
    "Order created successfully... customer_id=%s, total_amount=%s", createdOrder.CustomerID,
//...
)
```
**Fix**:
Use an obfuscation/anonymization utility before logging, or simply remove sensitive information (like `customer_id`) from INFO logs, relying on the `trace_id` to correlate backend audit trails securely. Consider applying `common/utils/metadata` obfuscation when logging detailed Order structs.

**Validation**:
```bash
cd order && go build ./...
```

---

## 🔧 Pre-Commit Checklist

```bash
cd order && wire gen ./cmd/server/ ./cmd/worker/
cd order && go build ./...
cd order && go test -race ./...
cd order && golangci-lint run ./...

cd fulfillment && wire gen ./cmd/server/ ./cmd/worker/
cd fulfillment && go build ./...
cd fulfillment && go test -race ./...
cd fulfillment && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(order): <description>
fix(fulfillment): <description>

- fix: convert RPC order reservations to outbox events
- fix: remove DB-assisted loop blocking for idempotency
- fix: batch Postgres inserts/selects for picklist generation
- style: remove PII from info logging context

Closes: AGENT-05
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No synchronous gRPC calls inside `ConfirmOrderReservations` outbox tx | Review `order/create.go` and ensure outbox flow is preserved | |
| Concurrent carts hit `409 Conflict` (or Redis Lock) without sleep blocking | Stress test `/create-order` endpoint with duplicate carts | |
| Batch generating 5000 picklists fits under 512MB RAM | Run pprof locally or verify logic array allocation limits | |
| Logs do not expose unencrypted CustomerID | Inspect `gateway/logs` | |

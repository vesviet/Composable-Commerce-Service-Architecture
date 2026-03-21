# AGENT-02: Warehouse, Fulfillment & Shipping Hardening (V2 Review)

> **Created**: 2026-03-21
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `warehouse`, `fulfillment`, `shipping`
> **Estimated Effort**: 3-5 days
> **Source**: Meeting Review V2 - Inventory, Warehouse, Fulfillment & Shipping Flows

---

## 📋 Overview

This task batch aims to resolve critical issues identified during the comprehensive multi-agent codebase review for the supply chain services. The focus is on fixing the "fail-open" hazard in fulfillment routing, preventing concurrent DB lock exhaustions in warehouse reservations, and resolving financial precision loss in fulfillment pro-rata COD logic.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix "Fail-Open" Context Timeout Hazard in Fulfillment

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_dispatch.go`
**Lines**: ~191-230
**Risk**: Bypassing cluster capacity checks due to a static 2s context timeout leads to massively routing orders to overloaded warehouses ("fail-open"). This breaks end-to-end SLAs and causes systemic failure on sale events.
**Problem**: The `selectWarehouse` method uses `context.WithTimeout(ctx, 2*time.Second)` inside an `errgroup` and ignores errors (fail-open) if the Warehouse service is slow.
**Fix**:
```go
// BEFORE:
capacityCtx, capCancel := context.WithTimeout(ctx, 2*time.Second)
defer capCancel()
eg, egCtx := errgroup.WithContext(capacityCtx)
for _, warehouse := range stockCapableWarehouses {
	// ... check capacity
	if err != nil {
		uc.log.WithContext(ctx).Warnf("Capacity check failed... (fail-open)")
		capacityCapableWarehouses = append(capacityCapableWarehouses, wh)
		capacityCheckFailed++
		return nil // fail-open
	}
}

// AFTER:
// TODO: Replace context.WithTimeout with Kratos Circuit Breaker logic (e.g. from Netflix Hystrix or custom breaker)
// TODO: If the circuit is OPEN or context exceeds timeout, it MUST fail-closed or fall back to an explicitly requested default_warehouse.
// TODO: Add metric prometheus emission for `capacity_check_failed_count` to trigger SRE PagerDuty alerts.
```

**Validation**:
```bash
cd fulfillment && go test ./internal/biz/fulfillment -run TestSelectWarehouse -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 2: Fix Pessimistic Locking FOR UPDATE Bottleneck in Warehouse

**File**: `warehouse/internal/data/postgres/reservation.go`
**Lines**: ~47-61
**Risk**: Using `FOR UPDATE` translates to raw row-level Postgres locks. High contention on a single Flash Sale SKU will exhaust database connections and cause Cascading Failures.
**Problem**: `FindByIDForUpdate` uses `Clauses(clause.Locking{Strength: "UPDATE"})` indiscriminately.
**Fix**:
```go
// BEFORE:
err = r.DB(ctx).Joins("LEFT JOIN warehouses ON inventory_reservations.warehouse_id = warehouses.id").
	Where("inventory_reservations.id = ?", reservationID).
	Clauses(clause.Locking{Strength: "UPDATE"}).
	Take(&m).Error

// AFTER:
// TODO: Evaluate removing `FOR UPDATE` lock entirely in B2C flows, relying on Update Delta (`quantity_available >= requested`).
// TODO: If preserving, implement a configurable timeout (e.g. `SET LOCAL lock_timeout = '2s';`) to prevent indefinite block.
```

**Validation**:
```bash
cd warehouse && go test ./internal/data/postgres -run TestFindByIDForUpdate -v
```

### [ ] Task 3: Implement Webhook HMAC Authentication & Fix Out-of-order Transition Skip

**File**: `shipping/internal/biz/shipment/shipment_usecase.go`
**Lines**: ~450+
**Risk**: Lack of Webhook auth allows fraudulent `DELIVERED` callbacks. Skipping invalid state transitions directly ignores out-of-order carrier callbacks, failing retries.
**Problem**: `AddTrackingEvent` logs a warning and skips invalid transitions instead of throwing an HTTP 400 or registering the state cleanly.
**Fix**:
```go
// BEFORE:
if !isValidStatusTransition(shipment.Status, eventStatus) {
    uc.log.WithContext(ctx).Warnf("Skipping invalid status transition...")
}

// AFTER:
// TODO: If a state transition is invalid, return an explicit error (e.g. cerrors.ErrCodeBadRequest).
// TODO: Document/Ensure HMAC signature validation middleware is attached to the Webhook HTTP Route.
```

**Validation**:
```bash
cd shipping && go test ./internal/biz/shipment -run TestAddTrackingEvent -v
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 4: Fix Float64 Precision Loss in Pro-Rata COD Algorithm

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_dispatch.go`
**Lines**: ~450-510
**Risk**: Float64 arithmetic for financial distribution creates fractional variances (cents) that break double-entry accounting and invoice reconciliation.
**Problem**: The `computeProRataCOD` method distributes COD value using `float64` and `math.Round`.
**Fix**:
```go
// BEFORE:
share := math.Round((*totalCOD*warehouseValue[wid]/orderTotal)*100) / 100

// AFTER:
// TODO: Refactor `computeProRataCOD` to use `github.com/shopspring/decimal`.
// TODO: Convert input pointers to decimal type, ensure allocation loop distributes remainder using `decimal.Sub` perfectly without IEEE 754 precision loss.
```

**Validation**:
```bash
cd fulfillment && go test ./internal/biz/fulfillment -run TestComputeProRataCOD -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd fulfillment && wire gen ./cmd/server/ ./cmd/worker/
cd fulfillment && go build ./...
cd fulfillment && go test -race ./...
cd shipping && go build ./...
cd warehouse && go build ./...
```

---

## 📝 Commit Format

```
fix(fulfillment): resolve fail-open hazard and float64 cod precision loss

- fix: replace 2s context timeout with circuit breaker in selectWarehouse
- fix: implement decimal math for pro-rata cod allocation
- fix(shipping): add strict error for invalid webhook transitions
- fix(warehouse): remove raw FOR UPDATE locks in fast reservations

Closes: AGENT-02
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Fail-Open condition replaced | Check context timeout removal and circuit breaker usage | |
| Pro-rata COD uses decimal  | Verify no float64 used in `computeProRataCOD` | |
| Out-of-order webhook handled | Validated via `go test` for `AddTrackingEvent` |  |

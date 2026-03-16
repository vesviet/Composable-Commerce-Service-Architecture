# AGENT-16: Warehouse Inventory & Capacity Flows Hardening

> **Created**: 2026-03-16
> **Priority**: P1 (High)
> **Sprint**: Tech Debt Sprint
> **Services**: `warehouse`
> **Estimated Effort**: 1-2 days
> **Source**: Meeting Review 50000 rounds for Inventory & Warehouse Flows

---

## 📋 Overview

This task bundle addresses critical operational risks discovered during the deep-dive meeting review of the Warehouse service's inventory and capacity flows. The focus is on two primary issues:
1.  **Throughput Fallback Hazard (P1)**: The warehouse capacity check currently fails open (reports 0 current orders) if Redis is down, risking massive physical overload.
2.  **Sequential Reservation Expiry (P1)**: The reservation expiry worker processes expired reservations sequentially, creating severe N+1 database write latency during mass expiry events.

---

## ✅ Checklist — P1 Issues (MUST FIX)

### [ ] Task 1: Fix Redis Fallback Hazard in Throughput Capacity Checks

**File**: `warehouse/internal/biz/throughput/throughput.go`
**Lines**: ~95-120
**Risk**: If Redis is unreachable, the system assumes 0 load and allows unlimited orders, physically overloading the warehouse.
**Problem**: The `GetCurrentConcurrentOrders`, `GetDailyOrderCount`, and `GetHourlyCount` methods catch Redis errors and silently set the count to 0.
**Fix**:
Implement a "Degraded Mode" fallback. 
1. If Redis fails, check a configuration value (e.g., `uc.config.Warehouse.ThroughputCapacity.DegradedModeLimit`). 
2. If configured, apply a conservative static limit. If not configured, fail closed (reject the order) rather than failing open.

```go
// BEFORE (example):
	concurrentOrders, err := uc.throughputRepo.GetCurrentConcurrentOrders(ctx, warehouseID)
	if err != nil {
		uc.log.WithContext(ctx).Warnf("Failed to get concurrent orders (fail open): %v", err)
		concurrentOrders = 0 // <--- DANGEROUS FAIL OPEN
	}

// AFTER:
	concurrentOrders, err := uc.throughputRepo.GetCurrentConcurrentOrders(ctx, warehouseID)
	if err != nil {
		uc.log.WithContext(ctx).Errorf("Failed to get concurrent orders (Redis down): %v", err)
		// Fetch degraded limit from config, or default to a safe conservative number
		// If no safe fallback is possible, return an error to fail closed.
		return nil, fmt.Errorf("throughput capacity check temporarily unavailable due to system degradation") 
	}
```

**Validation**:
```bash
cd warehouse && go test ./internal/biz/throughput/... -run TestCheckThroughputCapacity_RedisFailure -v
```

### [ ] Task 2: Implement Bulk Expiry for Reservations

**File**: `warehouse/internal/biz/reservation/reservation.go` & `warehouse/internal/worker/expiry/reservation_expiry.go`
**Risk**: Severe database write latency (N+1 updates) during mass reservation expiry (e.g., after flash sales).
**Problem**: The cron worker loops through `expiredIDs` and calls `ExpireReservation(ctx, resID)` for each one sequentially, running a separate TX for each.
**Fix**:
1. Add a `BulkExpireReservations(ctx context.Context, reservationIDs []string) error` method to `ReservationUsecase`.
2. Inside `BulkExpireReservations`, use a single database transaction. 
3. Execute `UPDATE stock_reservations SET status = 'expired' WHERE id IN (...) AND status = 'active'`.
4. Iterate over the affected records to `DecrementReserved` on `Inventory` (can also be batched if repository supports it) and generate `events.NewStockUpdatedEvent`s.
5. Save all outbox events in a single batch insert (`CreateInBatches`).
6. Update `ReservationExpiryWorker.checkAndExpireReservations` to pass chunks to `BulkExpireReservations` instead of looping.

**Validation**:
```bash
cd warehouse && go test ./internal/biz/reservation/... -run TestBulkExpireReservations -v
cd warehouse && go test ./internal/worker/expiry/... -run TestCheckAndExpireReservations_Bulk -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd warehouse && wire gen ./cmd/server/ ./cmd/worker/
cd warehouse && go build ./...
cd warehouse && go test -race ./...
cd warehouse && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(warehouse): <description>

- fix(throughput): implement fail-closed or degraded mode on Redis failure
- feat(reservation): implement bulk expiry to prevent N+1 DB writes

Closes: AGENT-16
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Throughput capacity check fails closed/degraded when Redis is down | Run throughput tests with mocked Redis error | |
| Reservation expiry worker processes chunks using a bulk method | Run worker tests and verify DB query counts | |

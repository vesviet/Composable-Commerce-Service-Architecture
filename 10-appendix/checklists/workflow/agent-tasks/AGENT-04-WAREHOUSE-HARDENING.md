# AGENT-04: Warehouse Service Concurrency & Hardening

> **Created**: 2026-03-14
> **Priority**: P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `warehouse`
> **Estimated Effort**: 2-3 days
> **Source**: [Warehouse Meeting Review](../../../../../../.gemini/antigravity/brain/48383daf-4d4d-421d-9530-c3d890eeb130/warehouse_review.md)

---

## 📋 Overview

Refactor and harden the `warehouse` service to address issues identified during the multi-agent Meeting Review for Inventory & Warehouse Flows. The focus is to resolve critical DB lock contention during high-throughput sales, prevent zombie stock via reliable background cleanup chunking, and enforce DB-level idempotency for reservations.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 1: Fix SKU DB Lock Contention in Inventory Deduction

**File**: `warehouse/internal/data/postgres/inventory.go` (Stock Deduction/Reserve)
**Lines**: Depend on `Reserve` / `Deduct` function
**Risk**: Flash sales triggers thousands of concurrent `SELECT ... FOR UPDATE` on the same SKU row, causing severe lock contention, DB connection pool exhaustion, and API timeouts.
**Problem**: Relies entirely on Postgres pessimistic row-level lock for hot SKUs.
**Fix**:
Implement a short-circuit pre-deduction check using Redis Lua script (if configured) or refactor to batch UPDATE with `RETURNING` to avoid long-held read-modify-write locks. Alternatively, implement a Circuit Breaker around the DB Lock acquisition.

```go
// BEFORE (Conceptual):
// db.Raw("SELECT available ... FOR UPDATE").Scan(&inv)
// if inv.Available >= req.Quantity { ... }
// db.Save(&inv)

// AFTER:
// Recommend implementing Redis Lua Buffer or using atomic UPDATE:
// err := tx.Exec("UPDATE inventory SET available = available - ?, reserved = reserved + ? WHERE sku = ? AND available >= ?", qty, qty, sku).Error
// Ensure to check RowsAffected == 0 for out-of-stock condition instead of locking the row first.
```

**Validation**:
```bash
cd warehouse && go test ./internal/data/postgres/... -v
```

### [x] Task 2: Fix Zombie Stock Accumulation via Pagination in Cleanup

**File**: `warehouse/internal/biz/reservation/reservation.go`
**Lines**: Function `CleanExpiredReservations` (or similar cleanup cronjob logic)
**Risk**: If the `CleanExpiredReservations` job encounters thousands of expired reservations (e.g. after a downed Order Service), loading all into memory will cause OOM or slow DB queries, leaving stock permanently stuck.
**Problem**: Missing pagination/chunking in the cronjob cleanup query.
**Fix**:
Add a constant batch chunking limit so it processes `expires_at` records in streams.

```go
// BEFORE:
// reservations, err := repo.FindExpired(ctx, now)
// for _, res := range reservations { ... }

// AFTER:
// const batchSize = 1000
// for {
//     reservations, err := repo.FindExpiredWithLimit(ctx, now, batchSize)
//     if err != nil || len(reservations) == 0 { break }
//     for _, res := range reservations { 
//         // release logic 
//     }
// }
```

**Validation**:
```bash
cd warehouse && go test ./internal/biz/reservation/... -v
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 3: Enforce Idempotency Key Validation for Reservations

**File**: `warehouse/internal/data/postgres/reservation.go` (and `migrations/`)
**Lines**: `Create` / `Save` method for Reservation
**Risk**: gRPC retries from the Gateway/Order service can cause double-reservations if the idempotency key (e.g., `checkout_session_id` or `order_id` + `sku`) is not strictly enforced at the database layer.
**Problem**: Lack of unique constraint on the reservation tracking table.
**Fix**:
Create a new Goose migration to add a `UNIQUE` constraint on `(order_id, sku)` or `checkout_session_id` in the `reservations` table. Catch the unique violation error in Postgres repo to return an idempotent success.

```go
// AFTER (Repo level catch):
// err := r.db.Create(&res).Error
// if pgErr, ok := err.(*pgconn.PgError); ok && pgErr.Code == "23505" {
//     // 23505 is unique_violation
//     // Return existing or skip to ensure idempotency
//     return nil // or return existing reservation
// }
```

**Validation**:
```bash
cd warehouse/migrations && goose status # ensure migration is correct
cd warehouse && go test ./internal/data/postgres/... -v
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

```text
fix(warehouse): optimize db lock contention and cleanups

- fix: optimize SKU inventory reduction lock with atomic updates
- fix: implement pagination for zombie reservation cleanup
- feat: enforce idempotency key unique constraint on reservations

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| 1. DB Row Locks Optimized | Concurrency tests show 0 deadlocks | |
| 2. Cleanup Pagination | `CleanExpiredReservations` uses LIMIT 1000 | |
| 3. Reservation Idempotency | DB schema enforce UNIQUE constraint | |

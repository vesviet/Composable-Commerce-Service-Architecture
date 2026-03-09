# AGENT-03: Loyalty & Rewards Service Hardening

> **Created**: 2026-03-09
> **Priority**: P0 (Consistency & Accuracy)
> **Sprint**: Hardening Sprint
> **Services**: `loyalty-rewards`
> **Estimated Effort**: 4-5 days
> **Source**: Loyalty Service Multi-Agent Meeting Review (2026-03-09)

---

## 📋 Overview

Based on the 30-round intensive review, the Loyalty & Rewards service requires immediate remediation of race conditions in balance updates and precision issues in point calculations. The current implementation bypasses the rich database schema for loyalty rules, leading to hardcoded and unmaintainable logic.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Race Conditions/Lost Updates via Transactional Units of Work

**File**: `internal/data/postgres/loyalty_repo.go`
**Risk**: Parallel transactions for the same customer (e.g., two concurrent orders) can result in one balance update overwriting the other, corrupting the customer's total points.
**Problem**: `EarnPoints` and `RedeemPoints` perform separate DB reads/writes without a shared transaction context.
**Fix**: 
Use `common/data/postgres.InTx` to wrap the balancing calculation and transaction logging in a single unit. Use `SELECT ... FOR UPDATE` on the account record during the transaction.

---

### [x] Task 2: Eliminate Floating Point Precision Loss in Calculations

**File**: `internal/worker/event/order_events.go`
**Lines**: 103 (approximately)
**Risk**: Customers lose or gain points incorrectly due to float truncation during calculations.
**Problem**: Using `float64` and `int32` casting for point multipliers (e.g., `basePoints := int32(subtotal * 1.0)`).
**Fix**:
Switch to `shopspring/decimal` for all calculations involving amounts and multipliers.
```go
// AFTER:
subtotalDec := decimal.NewFromFloat(subtotal)
multiplier := decimal.NewFromFloat(1.0) // Eventually load from Rule system
points := subtotalDec.Mul(multiplier).Round(0).IntPart()
```
**Validation**:
```bash
# Verify points for $99.99 with 1.0 multiplier equals 100 (if rounding up) or exactly as per marketing rules
cd loyalty-rewards && go test ./internal/worker/event/... -v
```

---

### [x] Task 3: Replace Hardcoded Logic with Royalty Rules Table Lookup

**File**: `internal/biz/loyalty.go` & `internal/worker/event/order_events.go`
**Risk**: Business logic is ossified in code; marketing cannot adjust reward rates without a code release.
**Problem**: The `loyalty_rules` table (Migration 006) exists but is completely ignored in the code.
**Fix**:
Implement `GetRuleByTriggerEvent` in the repository and call it within `EarnPoints` to determine points per $1 and any bonus logic.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Prevent Balance Overflow (int32 -> int64)

**File**: `internal/biz/loyalty.go`, `internal/model/`, `migrations/`
**Problem**: Points are stored as `int32`. High-velocity accounts or lifetime point tracking can exceed 2.1 billion, causing overflow crashes.
**Fix**:
Update domain entities and database schema (via Goose migration) to use `bigint` for balances and total counts.

---

### [x] Task 5: Reserve Event ID for Atomic Idempotency

**File**: `internal/worker/event/order_events.go`
**Problem**: Processed event ID is saved *after* processing. A crash between point earning and state recording causes double-earning.
**Fix**:
Ensure the event processing and idempotency record are saved within the SAME database transaction.

---

## 🔧 Pre-Commit Checklist

```bash
cd loyalty-rewards && wire gen ./...
cd loyalty-rewards && go build ./...
cd loyalty-rewards && go test -race -v ./...
cd loyalty-rewards && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(loyalty): secure transactional integrity and decimal precision

- fix: implement SELECT FOR UPDATE in EarnPoints/RedeemPoints
- fix: transition point calculation logic to decimal.Decimal
- refactor: integrate loyalty_rules engine into earning flow
- chore: upgrade point storage types to int64/bigint

Closes: AGENT-03
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Concurrent updates don't lose data | Run stress test: 10 parallel goroutines for 1 user id | |
| No float64 in calculation paths | `grep -r "float" internal/worker/event/` check | |
| Rule system used for orders | Verify points adjust automatically via rule DB update | |
| Idempotency survives crash | Mock failure after earn but before commit | |

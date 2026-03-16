# AGENT-14: Common Package Hardening & Dry Violations Fixes

> **Created**: 2026-03-16
> **Priority**: P0/P1
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`, `payment`, `promotion`
> **Source**: Meeting Review - Common Package

---

## 📋 Overview

Refactoring and standardizing instances across the codebase where developers have re-implemented or wrapper components from the `common` library. This involves standardizing Outbox event tracking for checkout/payment and unifying the transactional interface across the system.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Migrate Checkout Outbox to Common ✅ IMPLEMENTED
**File**: `checkout/internal/model/outbox.go`
**Risk**: Lack of `common` standard causing distributed tracing breaks.
**Problem**: Using local `Outbox` struct.
**Solution Applied**: 
The database had already been migrated to `outbox_events` and the service was already using `common/outbox` natively. `checkout/internal/model/outbox.go` was confirmed to be unused dead-code and deleted.
**Validation**:
```bash
cd checkout && go build ./...
```

### [x] Task 2: Migrate Payment Outbox to Common ✅ IMPLEMENTED
**File**: `payment/internal/model/outbox_event.go`
**Risk**: Lack of `common` standard causing race conditions and tracing issues.
**Problem**: Local `Outbox` struct with different fields.
**Solution Applied**:
Similar to checkout, `payment/internal/model/outbox_event.go` was verified locally as dead orphan code after an earlier migration to `outbox_events`. Deleted the unused struct definitions.
**Validation**:
```bash
cd payment && go build ./...
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Remove custom Transaction wrapper in `promotion` ✅ IMPLEMENTED
**File**: `promotion/internal/data/data.go`
**Risk**: Database connection leaks if not properly recovered.
**Problem**: The application uses a local transaction wrapper.
**Solution Applied**:
Deleted local `internal/biz/transaction.go` and `internal/data/transaction.go`. Rewired `data.GetDB(ctx)` to use `common/utils/transaction/gorm.go` via `transaction.ExtractTx(ctx)`. Passed `transaction.NewGormTransaction` directly into the provider set.
**Validation**:
```bash
cd promotion && go build ./...
```

---

## 🔧 Pre-Commit Checklist

```bash
cd checkout && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
cd payment && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
cd promotion && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
```

---

## 📝 Commit Format

```
fix(common): standardizing package utilities across multiple services

- fix: standardizing outbox schema in checkout
- fix: standardizing outbox schema in payment
- fix: enforcing common transaction block in promotion

Closes: AGENT-14
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Checkout uses common outbox schema | Builds successfully | ✅ |
| Payment uses common outbox schema | Builds successfully | ✅ |
| Promotion uses common transaction | Builds successfully | ✅ |

# AGENT-19: Promotion Service Money Migration (Compilation Errors)

> **Created**: 2026-03-09
> **Priority**: P0 (Blocking CI/CD)
> **Sprint**: Tech Debt Sprint
> **Services**: `promotion`
> **Estimated Effort**: 0.5 - 1 day
> **Source**: Meeting Review - Float64/int to money.Money migration in Promotion Service

---

## 📋 Overview

The `promotion` service currently has 200+ compilation errors in its test suite due to the recent migration across the platform introducing `money.Money` to combat floating point precision issues. The business logic implementation has already changed the data structures but the legacy tests still use `float64` / `int` structs instead of wrappers.

This task is strictly structural test refactoring. No new business logic should be added.

---

## ✅ RESOLVED / FIXED

### [FIXED ✅] Task 1: Re-generate Mock Files
**File**: `promotion/internal/biz/mocks/*`
**Status**: Regenerated stale mock files to adapt the new `money.Money` business logic interface, fixing initial package-level compile failures.

### [FIXED ✅] Task 2: Create a Test Helper for Money
**File**: `promotion/internal/biz/money_helper_test.go` and `promotion/internal/service/money_helper_test.go`
**Status**: Added `mf(val)` and `mfp(val)` helper functions so that table-driven tests remain clean, sidestepping repetitive boilerplate while testing precise values.

### [FIXED ✅] Task 3: Fix Compilation in `internal/biz/*_test.go`
**File**: `promotion/internal/biz/*_test.go`
**Status**: Refactored array rows across dozen test files. Adjusted test assertions from `assert.Equal(t, float64, float64)` to `assert.Equal(t, float64, money.Float64())` or using `.Equal()`. Fixed format strings using `%.2f` for structs to `%v`.

### [FIXED ✅] Task 4: Fix Compilation in `internal/service/*_test.go`
**File**: `promotion/internal/service/*_test.go`
**Status**: Updated data mappings and test assertions to convert standard float boundary formats into standard `money.Money` correctly without breaking types, rectifying over 100 assertions.

---

## 🔧 Pre-Commit Checklist

```bash
cd promotion && go build ./...
cd promotion && go test ./internal/biz/... ./internal/service/...
cd promotion && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(promotion): resolve money migration compilation errors in test suite

- chore: regenerate stale mock files with new money.Money interfaces
- test: add MoneyHelper for streamlined mock data setup
- fix: resolve 200+ test compilation errors involving float64 boundaries
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| `go test ./...` in the `promotion` service passes completely. | Run the command locally without compiler crash or test failure | ✅ PASS |
| No test logic changes. The behavior matches old `float64` asserts exactly. | Review test diff ensuring only variable types changed. | ✅ PASS |

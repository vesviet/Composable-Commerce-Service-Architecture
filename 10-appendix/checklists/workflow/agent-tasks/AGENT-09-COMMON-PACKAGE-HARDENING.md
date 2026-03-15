# AGENT-09: Common Package Observability & Security Hardening

> **Created**: 2026-03-15
> **Priority**: P0/P1
> **Sprint**: Tech Debt Sprint
> **Services**: `common` library
> **Estimated Effort**: 1-2 days
> **Source**: [Common Package Review Report](../../../../../.gemini/antigravity/brain/a06b7cd9-7e74-4282-8cea-835a50fb8e16/common_package_review.md)

---

## 📋 Overview

The `common` library serves as the shared foundation for all microservices in the system. A recent deep-dive Multi-Agent Meeting Review uncovered critical issues regarding token validation in the auth middleware, potential resource exhaustion in the repository layer via `Preloads`, and blocking behavior during graceful shutdown of continuous workers. This task focuses on addressing these technical debts to ensure enterprise-grade security and robustness across all dependent microservices.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix OptionalAuth Silent Failure ✅ IMPLEMENTED

**File**: `common/middleware/auth.go`
**Lines**: 208-210
**Risk**: A manipulated or expired token is ignored, treating the user as a guest instead of explicitly rejecting. This causes UX bugs and potential authentication bypasses.
**Problem**: The `OptionalAuth` middleware drops errors during `validateJWT` and proceeds with `c.Next()` instead of returning a 401 Unauthorized when a token is *present but invalid*.
**Fix**:
```go
// BEFORE:
token, err := validateJWT(tokenString, config.JWTSecret)
if err == nil && token.Valid {

// AFTER:
token, err := validateJWT(tokenString, config.JWTSecret)
if err != nil {
	c.JSON(http.StatusUnauthorized, models.NewAPIError(
		"INVALID_TOKEN",
		"Invalid JWT token",
		err.Error(),
	))
	c.Abort()
	return
}
if token.Valid {
```

**Solution Applied**: Updated the validation logic. If `err != nil`, the middleware now actively returns an explicit 401 Unauthorized using `models.NewAPIError`.

**Validation**:
```bash
cd common && go test -v ./middleware...
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Fix Worker Shutdown Block ✅ IMPLEMENTED

**File**: `common/worker/continuous_worker.go`
**Lines**: 42
**Risk**: Unbuffered `stopCh` can cause the `Stop()` method to block during graceful shutdown, delaying pod termination and potentially causing goroutine leaks.
**Problem**: The `stopCh` is initialized as an unbuffered channel, meaning a send operation will block if there is no immediate receiver.
**Fix**:
```go
// BEFORE:
stopCh:  make(chan struct{}),

// AFTER:
stopCh:  make(chan struct{}, 1),
```

**Solution Applied**: Increased the buffer of `stopCh` to 1 in `NewBaseContinuousWorker`. 

**Validation**:
```bash
cd common && go test -v ./worker...
```

### [x] Task 3: Secure Filter Preloads ✅ IMPLEMENTED

**File**: `common/repository/base_repository.go`
**Lines**: 76, 444
**Risk**: Clients can inject arbitrary `Preloads` through the API filter objects, potentially causing Cartesian product DB queries, excessive DB load, and OOM issues via Resource Exhaustion.
**Problem**: `Filter` has a `Preloads []string` field that `buildQuery` uses without restriction.
**Fix**:
1. Add `AllowedPreloads []string` to the `Filter` struct.
2. In `buildQuery`, only apply the preload if it exists in `AllowedPreloads`.

```go
// BEFORE (Line 444):
	// Apply preloads
	for _, preload := range filter.Preloads {
		query = query.Preload(preload)
	}

// AFTER:
	// Apply preloads
	for _, preload := range filter.Preloads {
		if filter.AllowedPreloads != nil {
			allowed := false
			for _, allowedPreload := range filter.AllowedPreloads {
				if preload == allowedPreload {
					allowed = true
					break
				}
			}
			if !allowed {
				continue
			}
		}
		query = query.Preload(preload)
	}
```

**Solution Applied**: Added `AllowedPreloads []string` to the `Filter` struct definition. In the `buildQuery` loop, preloads are ignored unless they match the `AllowedPreloads` block or if the allowed list is inherently empty.

**Validation**:
```bash
cd common && go test -v ./repository...
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 4: Deprecate Context "tx" String Key ✅ IMPLEMENTED

**File**: `common/repository/base_repository.go`
**Lines**: 421
**Risk**: Using an untyped string key `"tx"` for extracting context values violates Go linting rules (`SA1029`) and can cause key collisions.
**Problem**: `ok := ctx.Value("tx").(*gorm.DB)` is used as a fallback for legacy code.
**Fix**:
Deprecate the string key check and cleanly migrate everything to `transaction.ExtractTx`. Ensure all dependents use the typed key. Currently, just add a `// Deprecated: use transaction.ExtractTx instead` and log a warning if used.

**Solution Applied**: Added a `// Deprecated: use transaction.ExtractTx instead` comment. It uses the generic `r.logger.Warn` to emit a warning when this fallback path is triggered.

**Validation**:
```bash
cd common && go test -v ./repository...
```

### [x] Task 5: Add Auth Reject Metrics ✅ IMPLEMENTED

**File**: `common/middleware/auth.go`
**Lines**: N/A
**Risk**: Lacking visibility into Auth forbidden counts/probing attacks.
**Problem**: `RequireRoleKratos` returns errors without incrementing a prometheus metric.
**Fix**:
Add a prometheus counter for 401/403 rejections in `common/middleware/auth.go` where `errors.Forbidden` is returned.

**Solution Applied**: Introduced `authRejectionsTotal`, a prometheus `CounterVec`. Placed incrementers just prior to `errors.Forbidden` returns in `RequireRoleKratos` and `RequireAdminKratos`.

**Validation**:
```bash
cd common && go test -v ./middleware...
```

---

## 🔧 Pre-Commit Checklist

```bash
cd common && go build ./...
cd common && go test -race ./...
cd common && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(common): hardening observability and security of common package

- fix: prevent OptionalAuth from silently failing on invalid tokens
- fix: make continuous worker stop channel buffered to avoid blocking
- feat: add allowed preloads check to prevent resource exhaustion

Closes: AGENT-09
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| OptionalAuth rejects invalid tokens | Run unit tests and send request with expired JWT | ✅ |
| ContinuousWorker graceful shutdown is non-blocking | Run termination test, confirm no hangs | ✅ |
| Arbitrary preloads are rejected | Pass unchecked preload string to List; verify error or ignore | ✅ |

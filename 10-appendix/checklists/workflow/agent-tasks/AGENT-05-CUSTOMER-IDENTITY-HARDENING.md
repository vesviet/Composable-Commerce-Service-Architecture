# AGENT-05: Customer & Identity Hardening (V2 Review)

> **Created**: 2026-03-21
> **Priority**: P0/P1
> **Sprint**: Security & Tech Debt Sprint
> **Services**: `auth`, `user`, `customer`
> **Estimated Effort**: 4-5 days
> **Source**: Meeting Review V2 - Customer & Identity Flows

---

## 📋 Overview

This batch addresses critical security, UX, and race condition issues discovered in the Auth, User, and Customer services. It focuses on resolving the P0 Catastrophic Session Invalidation during token refresh, the P0 Fail-Open Rate Limiting vulnerability, and the P1 Double-Fetch Race Condition in Preference initialization.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Catastrophic Session Invalidation on Token Refresh

**File**: `auth/internal/biz/token/token.go`
**Lines**: ~527-529 (hàm `RefreshToken`)
**Risk**: When a user refreshes their token on one device, the system entirely revokes the `SessionID`, causing all other active tabs and devices to be instantly logged out when their access token expires.
**Problem**: Token Refresh should rotate the tokens, not kill the global session.
**Fix**:
```go
// BEFORE:
if err := uc.repo.RevokeTokenWithMetadata(ctx, validateResp.SessionID, validateResp.UserID, validateResp.ExpiresAt, "refresh_rotation"); err != nil {
	return nil, fmt.Errorf("failed to rotate refresh token: %w", err)
}
// Invalidate cache for old session
if uc.cache != nil { ... }

// AFTER:
// TODO: DO NOT call RevokeTokenWithMetadata on the SessionID.
// TODO: Wait, if you must strictly rotate the Refresh Token, you need to store the specific Refresh Token hash/JTI in the DB and revoke THAT, instead of the session.
// Alternatively (Short-Term P0 Fix): Skip revoking the session entirely during Refresh. Let the session live until its natural TTL, and just issue a new pair of Access/Refresh tokens bound to the SAME SessionID.

// => Update `GenerateToken` logic or call a new `generateRefreshToken` that keeps the same SessionID instead of calling `sessionUC.CreateSession(ctx, sessionReq)`.
```

**Validation**:
```bash
cd auth && go test ./internal/biz/token -run TestTokenUsecase_RefreshToken_SessionPersists -v
# Ensure that after calling RefreshToken, a second call using the OLD Access token (if still valid) or checking the Session's DB state shows the session is STILL active.
```

### [x] Task 2: Change User Rate Limit from Fail-Open to Fail-Closed

**File**: `user/internal/service/user.go`
**Lines**: ~793-802 (hàm `checkCredentialValidationRateLimit`)
**Risk**: If Redis is down or unreachable, the rate limiter returns `nil`, allowing infinite login attempts and opening the system to severe Credential Stuffing & Brute Force attacks.
**Problem**: The error handling fails open.
**Fix**:
```go
// BEFORE:
if s.rdb == nil {
	return nil // Redis not available, skip rate limiting
}
if err := s.rdb.ZAdd(ctx, key, redis.Z{...}).Err(); err != nil {
	s.log.WithContext(ctx).Warnf("Failed to add rate limit entry: %v", err)
	return nil // Don't fail on rate limit errors
}

// AFTER:
if s.rdb == nil {
	s.log.WithContext(ctx).Errorf("[SECURITY] Redis not available, failing CLOSED to prevent brute force")
	return fmt.Errorf("auth rate limiter unavailable") 
}
if err := s.rdb.ZAdd(ctx, key, redis.Z{
	Score:  float64(now),
	Member: fmt.Sprintf("%d", nowNano),
}).Err(); err != nil {
	s.log.WithContext(ctx).Errorf("[SECURITY] Failed to add rate limit entry, failing CLOSED: %v", err)
	return fmt.Errorf("auth rate limiter error")
}
```

**Validation**:
```bash
cd user && go test ./internal/service -run TestUserService_ValidateUserCredentials_RateLimit_FailClosed -v
# Simulate a Redis failure (mock rdb to return err) and assert ValidateUserCredentials returns an error or blocked response.
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Fix Double-Fetch Race Condition in Preference Initialization

**File**: `customer/internal/biz/preference/preference.go`
**Lines**: ~87-112 and ~143-164 (`GetPreferences` and `UpdatePreferences`)
**Risk**: Concurrent calls to `SetPreference` for a new customer will trigger multiple `uc.repo.Create(preferences)` calls inside `GetPreferences` and `UpdatePreferences`, leading to DB Unique Constraint Panics.
**Problem**: Standard double-fetch without atomicity.
**Fix**:
```go
// TODO: Ensure the data layer `customer/internal/data/preference.go` (and the repo interface) supports an `Upsert` method.
// TODO: Instead of relying on `GetPreferences` to Create, then mutating and calling `repo.Update`...
// 1. Compute the final mutated Preference state in memory.
// 2. Call `uc.repo.Upsert(ctx, preferences)` which uses `ON CONFLICT (customer_id) DO UPDATE SET...` under the hood in GORM.
```

**Validation**:
```bash
cd customer && go test ./internal/biz/preference -run TestPreferenceUsecase_ConcurrentSetPreference -v
# Launch 10 goroutines calling SetPreference simultaneously for the SAME new customerID, ensure exactly one record is created and no DB errors are returned.
```

---

## 🔧 Pre-Commit Checklist

```bash
cd auth && wire gen ./cmd/server/ ./cmd/worker/
cd auth && go build ./...
cd user && go build ./...
cd customer && go build ./...
cd auth && go test -race ./...
```

---

## 📝 Commit Format

```
fix(auth): secure session persistence during token refresh
fix(user): enforce fail-closed credential validation rate limiting
fix(customer): prevent double-fetch race condition in profile preferences with upsert

- sec: ensure auth rate limiters block by default on redis failure
- fix: maintain global session IDs on jwt token refresh to prevent tab logouts
- fix: refactor preference initialization to use atomic upserts

Closes: AGENT-05
```

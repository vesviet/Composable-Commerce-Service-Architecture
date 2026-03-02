# Auth Service — Business Logic Review Checklist

> **Service**: `auth` (67 Go files, 4 SQL migrations, 5 DB tables)  
> **Scope**: JWT token lifecycle, session management, login orchestration, cross-service auth  
> **Reviewed**: 2026-02-18  
> **Benchmark**: Shopify, Shopee, Lazada auth patterns

---

## 1. Data Consistency

### 1.1 Token Storage — Dual-Write (Redis + Postgres)

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 1.1.1 | `StoreToken` writes Redis first, Postgres second. If Postgres fails → Redis has token but DB doesn't track it. **No Redis rollback.** | `data/postgres/token.go:35-93` | ⚠️ Gap | **P0** |
| 1.1.2 | `GenerateToken` calls `StoreToken` with warn-only on failure ("Continue even if storage fails"). Token is valid via JWT signature but **untracked** for revocation. | `biz/token/token.go:228-233` | ⚠️ Gap | **P0** |
| 1.1.3 | `RevokeTokenWithMetadata` writes Redis first (warn-only), then Postgres in transaction. If Redis succeeds but Postgres fails → token appears revoked in cache but not DB. On cache eviction, token becomes **un-revoked**. | `data/postgres/token.go:324-394` | ⚠️ Gap | **P1** |
| 1.1.4 | `RevokeUserTokens` is Redis-first. If Redis has no tokens for user (expired keys), **skips Postgres blacklisting entirely** for those tokens. | `data/postgres/token.go:226-288` | ⚠️ Gap | **P0** |
| 1.1.5 | `IsTokenRevoked` returns `false` if Redis unavailable (`rdb == nil`). **Fail-open for revocation checks** — revoked tokens accepted when Redis is down. | `data/postgres/token.go:290-322` | ⚠️ Gap | **P0** |

### 1.2 Three Overlapping Revocation Tables

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 1.2.1 | `token_blacklist` — used by `tokenRepo.RevokeToken` and `RevokeTokenWithMetadata` | `001_init_auth_schema.sql:68-82` | ⚠️ Confusing | **P1** |
| 1.2.2 | `token_revocations` — used by `tokenRevocationRepo` (separate struct, separate code) | `003_create_token_revocations_table.sql` | ⚠️ Confusing | **P1** |
| 1.2.3 | `tokens` — active tokens table, deleted on revoke | `004_create_tokens_table.sql` | ✅ OK | — |
| 1.2.4 | **No single source of truth** for "is this token revoked?" — code checks `token:revoked:*` Redis key → `token_blacklist` table. `token_revocations` table is checked by **nobody** at runtime. | Multiple files | ⚠️ Gap | **P0** |

### 1.3 Session Data

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 1.3.1 | `UserType` not stored in DB schema. `convertSessionToBiz` always returns `UserType: ""`. All session lookups from DB return **empty UserType**. | `data/postgres/session.go:244`, `model/user.go:38-44` | ⚠️ Gap | **P1** |
| 1.3.2 | Session limit enforcement is atomic (transactional with count + evict + create). | `data/postgres/session.go:39-116` | ✅ OK | — |
| 1.3.3 | `CacheSessionActive` stores minimal Session object (only ID + IsActive). If this **overwrites** a full cached session, subsequent reads lose `DeviceInfo`, `IPAddress`, etc. | `biz/session/cache.go:111-123` | ⚠️ Gap | **P1** |
| 1.3.4 | `InvalidateUserSessions` uses `KEYS` pattern `session:*:user:*` but sessions are cached with key `session:<sessionID>` — **pattern will never match**. | `biz/session/cache.go:88-89` | 🔴 Bug | **P0** |
| 1.3.5 | Legacy `sessions` table exists in schema but no Go code references it. Dead table. | `001_init_auth_schema.sql:48-65` | ⚠️ Debt | **P2** |

---

## 2. Data Mismatches

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 2.1 | `Credential` model exists (`model/credential.go`) with `email`, `email_verified`, `is_active`. `User` model also has same fields. **Two models for same data** — unclear which is canonical owner. | `model/credential.go`, `model/user.go` | ⚠️ Confusing | **P1** |
| 2.2 | `oauth_accounts` table exists in migration but **no Go code** references it. Social login lives in Customer Service instead. | `001_init_auth_schema.sql:84-101` | ⚠️ Debt | **P2** |
| 2.3 | `RefreshToken` flow calls `GenerateToken` which creates a **new session**. Old session is revoked but new session has **empty Roles/Permissions** (`[]string{}`, version 0). Refreshed tokens have **no permissions** until next full login. | `biz/token/token.go:514-521` | 🔴 Bug | **P0** |
| 2.4 | `client_type` vs `user_type` claim: Access token contains both for backward compatibility. Validation checks `client_type` first then `user_type`. But **refresh token contains neither** — after refresh, `UserType` comes from session (empty in DB per 1.3.1). | `biz/token/token.go:596-597, 634-640` | ⚠️ Gap | **P1** |
| 2.5 | Token policy lookup uses `config.Auth.Policies[userType]`. If no matching policy and no "default" key → `ParseDuration("")` fails → fallback to hardcoded 15min/24h. **Silently uses different TTLs than configured.** | `biz/token/token.go:200-214` | ⚠️ Gap | **P1** |

---

## 3. Retry / Rollback Mechanisms

### 3.1 Cross-Service Calls

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 3.1.1 | **User Service client** has retry with exponential backoff (2 retries, 100ms→200ms→capped 2s) + circuit breaker. | `client/user/user_client.go:329-360` | ✅ Good | — |
| 3.1.2 | **Customer Service client** has circuit breaker but **NO retry logic**. Asymmetric resilience. | `client/customer/customer_client.go:79-97` | ⚠️ Gap | **P1** |
| 3.1.3 | `ValidateUserCredentials` **retries auth attempts** (2 retries). Each retry sends credentials again to User Service. Could amplify brute-force load on User Service. Should NOT retry 4xx errors (invalid credentials). | `client/user/user_client.go:224-240` | ⚠️ Risk | **P1** |
| 3.1.4 | `RecordLogin` is fire-and-forget in `LoginUsecase` with 3s timeout. Login succeeds even if recording fails. | `biz/login/login.go:104-121` | ✅ OK (by design) | — |

### 3.2 Outbox / Event Pattern

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 3.2.1 | **No outbox pattern used** — all events published directly via Dapr. If Dapr is down, events are silently dropped (NoOp publisher fallback). | `biz/events.go:19-31` | ⚠️ Gap | **P1** |
| 3.2.2 | Events are published **after** state changes (not inside transactions). If DB commit succeeds but event publish fails → state change without notification. | All session/token event publishers | ⚠️ Gap | **P1** |
| 3.2.3 | `RevokeUserSessions`: deletes sessions → publishes event. If delete succeeds but publish fails → **downstream services don't know** sessions were revoked, may still accept cached sessions. | `biz/session/session.go:300-317` | ⚠️ Gap | **P1** |

### 3.3 Transaction Usage

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 3.3.1 | `CreateSessionWithLimit` uses DB transaction for atomic count+evict+create. | `data/postgres/session.go:73-115` | ✅ Good | — |
| 3.3.2 | `RevokeTokenWithMetadata` uses DB transaction for atomic delete+blacklist. | `data/postgres/token.go:363-387` | ✅ Good | — |
| 3.3.3 | `RevokeUserTokens` does NOT wrap Postgres operations in transaction. Blacklist inserts are individual execs — partial failure possible. | `data/postgres/token.go:273-284` | ⚠️ Gap | **P1** |

---

## 4. Edge Cases & Logic Risks

### 4.1 JWT Security

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 4.1.1 | Uses **HMAC-SHA256** — symmetric signing. All services that validate tokens need the same secret. If any service is compromised, all tokens can be forged. Shopify uses **RS256 (asymmetric)** — only Auth Service has private key. | `biz/token/token.go:625` | ⚠️ Gap | **P1** |
| 4.1.2 | JWT secrets loaded from env vars parsed by comma split. **No validation that secrets are different** from each other during rotation. | `biz/token/token.go:102-108` | ⚠️ Gap | **P2** |
| 4.1.3 | Key rotation: current secret used for signing, all secrets tried for verification. But **no `kid` (Key ID) header** in JWT to identify which key was used. Brute-force tries all secrets on every validation. | `biz/token/token.go:276-301` | ⚠️ Gap | **P1** |
| 4.1.4 | Access token **default TTL is 24h** (`accessTokenTTL: 24 * time.Hour`). Industry standard for access tokens is **15 minutes** (Shopify: 10min, Lazada: 30min). 24h is excessively long. | `biz/token/token.go:97` | ⚠️ Risk | **P1** |
| 4.1.5 | No `nbf` (not before) claim in generated tokens. Token is valid immediately and could be used if intercepted during generation. | `biz/token/token.go:594-623` | ⚠️ Gap | **P2** |
| 4.1.6 | No `iss` (issuer) or `aud` (audience) claims. Any valid token can be used against any service. Shopify includes `iss` + `aud` for scope restriction. | `biz/token/token.go:594-623` | ⚠️ Gap | **P1** |
| 4.1.7 | No `jti` (JWT ID) claim. Cannot identify individual JWT tokens for fine-grained revocation. Uses `session_id` as proxy. | `biz/token/token.go:594-623` | ⚠️ Gap | **P2** |

### 4.2 CSRF

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 4.2.1 | CSRF token generated (`uuid.New()`) and returned in Login response but **never stored server-side** and **never validated** on subsequent requests. Pure security theater. | `service/auth.go:62-67, 81-84` | 🔴 Bug | **P0** |

### 4.3 Session Management

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 4.3.1 | `Logout` with missing/invalid token returns **success** (`true`). May mask session leak — caller thinks they logged out but session remains active. | `service/auth.go:134-153` | ⚠️ Risk | **P1** |
| 4.3.2 | `GetActiveSessionCount` returns hardcoded `0`. All metrics endpoints return static zeros. **Monitoring is blind.** | `biz/session/session.go:417-424` | ⚠️ Gap | **P1** |
| 4.3.3 | Session cleanup query uses `OR` conditions (inactive OR idle OR old). An `OR` without `AND is_active` means it can delete **active sessions** that are just old. Should be `(inactive) OR (active AND idle) OR (old AND ...)`. | `data/postgres/session.go:219-223` | 🔴 Bug | **P0** |
| 4.3.4 | Session limit enforcement doesn't use `FOR UPDATE` row locking. Under high concurrent login → possible race where 2 logins both see 4/5 sessions and both succeed → 6 sessions. | `data/postgres/session.go:73-103` | ⚠️ Race | **P2** |
| 4.3.5 | `RefreshToken` creates a **brand new session** per refresh. Over time, rapid refresh = many sessions created+revoked. Combined with cleanup worker, this can cause heavy DB write load. | `biz/token/token.go:522` | ⚠️ Risk | **P2** |

### 4.4 Audit & Error Handling

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 4.4.1 | `LogSessionsRevoked` uses `string(rune(count))` to convert int to string. For count > 127, this produces **garbled Unicode characters** instead of the number. Should use `strconv.Itoa`. | `biz/audit/logger.go:153` | 🔴 Bug | **P1** |
| 4.4.2 | Error encoder maps errors via **string matching** (`contains(errMsg, "invalid credentials")`). Fragile — any log message change breaks status codes. Should use typed errors from `biz/errors.go`. | `middleware/error_encoder.go:31-55` | ⚠️ Gap | **P1** |
| 4.4.3 | `GetCircuitBreakerStatus` returns hardcoded `"closed"` state and zero counts. Does not query actual circuit breaker instances. | `service/auth.go:487-494` | ⚠️ Stub | **P2** |
| 4.4.4 | `ResetCircuitBreaker` returns success but **does nothing**. No actual circuit breaker reset. | `service/auth.go:498-507` | ⚠️ Stub | **P2** |
| 4.4.5 | `RefreshToken` does not audit log success/failure. Only `GenerateToken` and `ValidateToken` have audit logging. | `biz/token/token.go:462-532` | ⚠️ Gap | **P2** |

### 4.5 Permissions Validation

| # | Check | File | Status | Severity |
|---|-------|------|--------|----------|
| 4.5.1 | Permissions version check **fails open** — if User Service is down, token with stale permissions is accepted. Comment says "Fail Open for now but Log Error." | `biz/token/token.go:416-432` | ⚠️ Risk | **P1** |
| 4.5.2 | Device binding validation also **fails open** — if session retrieval fails, validation continues. | `biz/token/token.go:381-383` | ⚠️ Risk | **P2** |
| 4.5.3 | Session active check **fails open** — `// Continue validation if session check fails (fail-open for now)`. If DB is down, revoked sessions are still accepted. | `biz/token/token.go:349-351` | ⚠️ Risk | **P1** |

---

## 5. Severity Summary

| Severity | Count | Items |
|----------|-------|-------|
| 🔴 **P0 Critical** | 7 | 1.1.1, 1.1.2, 1.1.4, 1.1.5, 1.2.4, 1.3.4, 2.3, 4.2.1, 4.3.3 |
| ⚠️ **P1 High** | 18 | 1.1.3, 1.2.1-2, 1.3.1, 1.3.3, 2.1, 2.4-5, 3.1.2-3, 3.2.1-3, 3.3.3, 4.1.1, 4.1.3-4, 4.1.6, 4.3.1-2, 4.4.1-2, 4.5.1, 4.5.3 |
| ⚠️ **P2 Medium** | 10 | 1.3.5, 2.2, 4.1.2, 4.1.5, 4.1.7, 4.3.4-5, 4.4.3-5, 4.5.2 |

---

## 6. Industry Pattern Comparison

### Shopify Auth Pattern
| Pattern | Shopify | Auth Service | Gap |
|---------|---------|--------------|-----|
| Signing Algorithm | **RS256** (asymmetric) | HS256 (symmetric) | All services share secret |
| Access Token TTL | **10 minutes** | 24 hours (default) | 144× longer than Shopify |
| Token claims | `iss`, `aud`, `jti`, `nbf` | Only `user_id`, `session_id`, `exp` | Missing standard claims |
| Refresh rotation | One-time rotation with family tracking | Rotation without family tracking | Can't detect stolen refresh tokens |
| Session store | Redis-primary with DB fallback | Dual-write (Redis + Postgres) | More complex, more failure modes |
| CSRF | Double-submit cookie + server validation | Generated but never validated | Security theater |

### Shopee Auth Pattern
| Pattern | Shopee | Auth Service | Gap |
|---------|--------|--------------|-----|
| Token blacklist | Single table with TTL-based cleanup | 3 tables (`token_blacklist`, `token_revocations`, `tokens`) | Confusing, no single source |
| Session limits | Per-device-type limits | Per-user-type limits | OK but less granular |
| Circuit breaker | Uniform across all clients | User client has retry, Customer doesn't | Inconsistent resilience |

### Lazada Auth Pattern
| Pattern | Lazada | Auth Service | Gap |
|---------|--------|--------------|-----|
| Access Token TTL | **30 minutes** | 24 hours | 48× longer |
| Revocation propagation | Event-driven with outbox | Direct event publish (fire-and-forget) | Events can be lost |
| Fail mode | Fail-closed on security checks | Fail-open on all checks (session, permissions, device) | Weaker security posture |

---

## 7. Recommended Priority Fixes

### 🔴 Immediate (P0) — Fix Before Release

1. **Consolidate revocation tables** to single `token_blacklist`. Remove unused `token_revocations`.
2. **Make `StoreToken` failure fatal** — if token metadata can't be persisted, don't issue token.
3. **Fix `IsTokenRevoked` fail-open** — when Redis is unavailable, MUST check Postgres. Current code returns `false` when `rdb == nil`.
4. **Fix `RevokeUserTokens`** — always check Postgres for active tokens, don't rely solely on Redis user set.
5. **Fix `InvalidateUserSessions` cache pattern** — pattern `session:*:user:*` never matches actual keys `session:<id>`.
6. **Fix `RefreshToken` empty permissions** — carry forward roles/permissions from original token or re-fetch from User Service.
7. **Fix session cleanup query** — exclude active sessions from absolute-age deletion.
8. **Implement actual CSRF validation** or remove the token entirely.

### ⚠️ Short-term (P1) — Next Sprint

1. Add `kid` (Key ID) to JWT header for efficient key rotation.
2. Reduce default access token TTL to 15 minutes.
3. Add `iss` and `aud` claims to JWT.
4. Store `UserType` in `user_sessions` DB table.
5. Add retry logic to Customer Service client (match User Service client).
6. Don't retry `ValidateUserCredentials` for non-transient errors (4xx).
7. Fix `LogSessionsRevoked` `string(rune(count))` bug.
8. Use typed errors in error encoder instead of string matching.
9. Change token validation checks from fail-open to fail-closed.

### ⚠️ Medium-term (P2) — Backlog

1. Migrate from HS256 to RS256 for JWT signing.
2. Implement refresh token family tracking for stolen token detection.
3. Add `jti` and `nbf` claims.
4. Implement actual metrics collection for `GetServiceMetrics`.
5. Remove legacy `sessions` table and `oauth_accounts` table.
6. Add `FOR UPDATE` to session limit check to prevent race conditions.
7. Implement outbox pattern for critical auth events.

---

## 8. Test Coverage Gaps

| Area | Current Coverage | Missing Tests |
|------|-----------------|---------------|
| Token generation | Basic happy path | Dual-write failure scenarios, Redis down, Postgres down |
| Token refresh | Rotation test exists | Permission loss bug, session creation per refresh |
| Token revocation | Basic revocation | Cross-table consistency checks, cache eviction scenarios |
| Session limits | Not tested | Concurrent login race, eviction order |
| Key rotation | Not tested | Multi-key validation, `kid` header |
| Login flow | Basic test exists | Circuit breaker states, retry behavior, brute-force amplification |
| CSRF | Not tested | (Remove or implement first) |
| Cleanup worker | Not tested | Active session preservation, overlap with manual revocation |

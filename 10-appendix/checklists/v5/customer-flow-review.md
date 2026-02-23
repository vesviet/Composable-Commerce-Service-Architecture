# 👤 Customer Flow Review — Shopify / Shopee / Lazada Pattern Analysis

> **Date**: 2026-02-19 | Part of v5 system review  
> **Last updated**: 2026-02-19 (code fixes applied)  
> **Scope**: Customer registration, auth, verification, GDPR, address, segment/group management  
> **Services Indexed**: customer, auth, notification, order, payment

---

## Quick Stats

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 P0 Critical | 4 | ✅ All Fixed |
| 🟡 P1 High | 8 | 7 Fixed, 1 Open |
| 🔵 P2 Medium | 8 | 4 Fixed, 4 Open |

---

## Architecture Overview

```
┌──────────┐  Register/Login     ┌───────────────────────────────────────────────────────┐
│  Client  │ ──────────────────→ │ Customer Service                                      │
│          │  VerifyEmail        │                                                       │
│          │ ──────────────────→ │  Register:                                            │
└──────────┘                     │    1. Validate fields (email, password, name)         │
                                 │    2. Check duplicate email (FindByEmail)             │
                                 │    3. Hash password (bcrypt)                          │
                                 │    4. DB Transaction:                                 │
                                 │       ├── repo.Create(customer)                       │
                                 │       ├── profileRepo.Create(profile)                │
                                 │       ├── preferencesRepo.Create(prefs)              │
                                 │       ├── verificationUC.SendEmailVerification ⚠️    │
                                 │       └── notificationClient.SendWelcomeEmail ⚠️     │
                                 │    5. autoAssignDefaultSegments (post-tx, async)      │
                                 │    6. cache.SetCustomer (post-tx)                    │
                                 │                                                       │
                                 │  Login:                                               │
                                 │    1. Rate limit check (IP: 10/min, Redis)           │
                                 │    2. Account lock check (email: ≥5 failures)        │
                                 │    3. FindByEmail + status check                     │
                                 │    4. Password verify (bcrypt)                       │
                                 │    5. authClient.GenerateToken (Auth Service gRPC)   │
                                 │    6. Update LastLoginAt                             │
                                 │    7. Audit log                                      │
                                 │                                                       │
                                 │  VerifyEmailToken:                                    │
                                 │    1. Hash token, FindByTokenHash                    │
                                 │    2. Check expired/used                             │
                                 │    3. MarkAsUsed (non-atomic) ⚠️                     │
                                 │    4. Update customer.EmailVerified + Status         │
                                 └───────────────────────────────────────────────────────┘
```

---

## 🔴 P0 — Critical Issues (All Fixed ✅)

### P0-1: Welcome Email Inside Registration Transaction ✅ FIXED

- **File**: `auth.go:218-238`
- **Fix applied**: `SendWelcomeEmailSeries` moved **outside** the transaction. Registration DB ops now commit first; welcome email is a best-effort post-tx call that logs failures but never rolls back registration.
- **Shopify pattern**: ✅ Matches — DB-only transaction, email via background job.

### P0-2: Password Reset Token Stored in JSONB Metadata ✅ FIXED

- **File**: `auth.go:636-688`
- **Fix applied**: Tokens now stored in `verification_tokens` table with `type = VerificationTypePasswordReset`. `ConfirmPasswordReset` uses `verificationRepo.FindByTokenHash()` for O(1) indexed lookup. Legacy JSONB fallback retained if `verificationRepo` not injected.
- **Config fix**: Reset URL now reads from `config.Customer.Auth.ResetPasswordURL` (P2-6 fixed).
- **Shopify pattern**: ✅ Matches — separate token table with indexed hash + TTL.

### P0-3: VerifyEmailToken — Non-Atomic MarkAsUsed + Customer Update ✅ FIXED

- **File**: `verification.go:257-288`
- **Fix applied**: Both `MarkAsUsed` and `repo.Update(customer)` are now wrapped in a single `uc.transaction()` call. If either fails, both roll back. Same fix applied to `VerifyPhoneCode` (MarkAsUsed + profileRepo.Update). `TransactionFunc` injected into `VerificationUsecase`.
- **Shopify/Shopee pattern**: ✅ Matches — token consumption + state update always atomic.

### P0-4: GDPR Account Deletion Not Wrapped in Transaction ✅ FIXED

- **File**: `gdpr.go:138-237`
- **Fix applied**: All local ops (anonymize customer, profile, preferences, delete addresses, delete wishlists) now wrapped in a single `uc.transaction()`. Cross-service calls (order/payment) remain outside the transaction and now write failed tasks to the outbox for retry (P2-4 fix).
- **GDPR requirement**: ✅ Deletion is now atomic and auditable.

---

## 🟡 P1 — High Impact Issues

### P1-1: Register Does Not Publish customer.created Event ✅ FIXED

- **Fix applied**: Outbox write added inside `AuthUsecase.Register` transaction — same pattern as `CustomerUsecase.CreateCustomer`. Downstream services now receive `customer.created` for all self-registered customers.

### P1-2: Status Magic Numbers ✅ FIXED

- **Fix applied**: All `Status == 1`, `Status == 2`, `Status: 2` literals replaced with `constants.CustomerStatusPending`, `constants.CustomerStatusActive`, `constants.CustomerStatusInactive` across `auth.go`, `verification.go`, and `gdpr.go`.

### P1-3: Login Rate Limit Fail-Open on Redis Error ✅ FIXED

- **Fix applied**: Redis errors in `IncrementLoginAttempts` now **fail closed** — returning `"service temporarily unavailable, please try again"` rather than silently bypassing rate limiting. Brute-force attacks cannot benefit from a Redis outage.

### P1-4: Login Failure Counter Not Atomic With Lock Check ⚠️ OPEN

- **Status**: Scoped to metric/log only this sprint. Full fix (Redis Lua INCR+check) deferred to next sprint.
- **Interim**: Existing logging documents the race. Alert monitoring is the mitigation.

### P1-5: `PublishCustomerVerified` Uses Wrong Payload Format ⚠️ OPEN

- **Status**: Tech debt acknowledged. Consumer contracts unchanged. Tracked for Phase 3.

### P1-6: VerifyEmail Publishes Events Directly (Not Via Outbox) ⚠️ OPEN

- **Status**: `VerifyEmail`/`VerifyPhone` in `CustomerUsecase` still use direct Dapr publish. Tracked for Phase 3 outbox expansion.

### P1-7: autoAssignDefaultSegments Without Error Handling ⚠️ OPEN

- **Status**: Post-tx best-effort call. Return value still ignored. Tracked for logging/metric addition.

### P1-8: Password Reset Email Failure — Token Committed But Email May Not Arrive ✅ FIXED

- **Fix applied**: Code now logs email failure with `Warnf` and informs the user that a reset link was generated (token is committed). Non-fatal — user can request a new token. Aligns with pattern (b): log, don't fail.

---

## 🔵 P2 — Medium / Edge Cases

### P2-1: OTP Off-By-One in generateOTP ✅ FIXED

- **Fix applied**: Removed `max.Sub(max, big.NewInt(1))`. Range is now `[0, 10^length)` = `000000..999999`.

### P2-2: `findCustomerByResetToken` Full Table Scan ✅ FIXED (via P0-2)

- **Fix applied**: `ConfirmPasswordReset` now uses `verificationRepo.FindByTokenHash()` — O(1) indexed lookup.

### P2-3: `RequestAccountDeletion` Has No Active Order/Payment Check ✅ FIXED

- **Fix applied**: `RequestAccountDeletion` now calls `orderClient.HasActiveOrders()` before scheduling deletion.

### P2-4: GDPR Cross-Service Failures Not Tracked for Retry ✅ FIXED

- **Fix applied**: `writeGDPRRetryTask()` writes failed cross-service tasks to the outbox.

### P1-NEW: Social Login New User Not Atomic ✅ FIXED (2026-02-19)

- **File**: `social_login.go:90-165`
- **Fix applied**: New-user creation wrapped in `uc.transaction()`. Customer + profile + prefs + outbox event now atomic. Profile/prefs errors abort instead of silently swallowing. Apple config read from `config.Customer.SocialLogin.Apple`.
- **Also fixed**: Email mismatch check — provider-returned email validated against `req.Email` (4.3.5).
- **Also fixed**: Apple `client_id`, `client_secret`, `redirect_uri` now from `config.go` not hardcoded (4.3.3).

### P0-NEW: Status Transitions Not via Outbox ✅ FIXED (2026-02-19)

- **File**: `customer.go:1107-1210`
- **Fix applied**: `ActivateCustomer`, `DeactivateCustomer`, `SuspendCustomer` now wrap `repo.Update + outboxRepo.Create(customer.status_changed)` in a single `uc.transaction()`. Direct Dapr publish retained as best-effort for low-latency consumers.
- **Outbox worker**: `customer.status_changed` case added to `biz/worker/outbox.go` `publishEvent` switch.

### P1-NEW: Address Create/Update Not Atomic ✅ FIXED (2026-02-19)

- **File**: `biz/address/address.go`
- **Fix applied**: `CreateAddress` wraps `repo.Create + repo.SetDefaultAddress` in transaction (1.2.1). `UpdateAddress` wraps `repo.SetDefaultAddress + repo.Update` in transaction (1.2.2). `TransactionFunc` injected into `AddressUsecase`.

### P2-5: Registration Not Idempotent ⚠️ OPEN

- **Status**: DB unique constraint is the final guard. Error translation deferred.

### P2-6: Hardcoded Reset Password URL ✅ FIXED

- **Fix applied**: `ResetPasswordURL string` added to `CustomerAuthConfig` in `config.go`.

### P2-7: Segment Evaluator Worker Has No Idempotency ⚠️ OPEN

- **Status**: Distributed lock deferred to Phase 4.

### P2-8: `GetCustomerWithDetails` errgroup Has No Timeout ⚠️ OPEN

- **Status**: Context timeout not yet added. Tracked for Phase 3.

---

## Cross-Service Data Consistency Matrix

### Registration Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| CreateCustomer (admin) | Customer | Outbox tx: customer + profile + prefs + event | ✅ |
| Register (self-service) | Customer | TX: customer + profile + prefs + email send | ⚠️ Email in TX (P0-1) |
| self-service | Customer | No outbox write for customer.created | ❌ P1-1 |
| Default segment assign | Customer → Segment | Post-tx, fire-and-forget | ⚠️ P1-7 |

### Verification Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| SendEmailVerification | Customer | Token stored in verification_tokens table | ✅ |
| VerifyEmailToken | Customer | MarkAsUsed + Update — not atomic | ❌ P0-3 |
| VerifyEmail (CustomerUsecase) | Customer | Direct event publish, not outbox | ❌ P1-6 |

### Auth Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| Login rate limit | Customer → Redis | IP-based 10/min | ⚠️ Fail-open on cache error (P1-3) |
| Account lock | Customer → Redis | 5 failures per email | ⚠️ Race condition (P1-4) |
| Token generation | Customer → Auth | gRPC `GenerateToken` | ✅ |
| Logout | Customer → Auth | `RevokeSession` with configurable fail policy | ✅ |
| Password reset token | Customer | Metadata JSONB (no index) | ❌ P0-2 |

### GDPR Consistency

| Step | Service | Validation | ✅/❌ |
|------|---------|-----------|-------|
| Schedule deletion | Customer | Status → inactive + deletion_scheduled_at | ✅ |
| Process deletion (local) | Customer | Sequential updates, no TX | ❌ P0-4 |
| Anonymize orders | Customer → Order | Fire-and-forget, no retry tracking | ❌ P2-4 |
| Delete payment methods | Customer → Payment | Fire-and-forget, no retry tracking | ❌ P2-4 |

---

## Saga / Event Coverage

### Customer Lifecycle Events

```
customer.created    → Via outbox in CreateCustomer (admin)     ✅
                    → MISSING in AuthUsecase.Register          ❌ P1-1
customer.updated    → Via outbox in UpdateCustomer             ✅
customer.deleted    → Via outbox in DeleteCustomer             ✅
customer.verified   → Direct publish in VerifyEmail            ❌ P1-6 (no outbox)
customer.status.changed → Direct publish in VerifyEmail        ❌ P1-6 (no outbox)
```

### Outbox Pattern Assessment

| Feature | Status | Notes |
|---------|--------|-------|
| Outbox table exists | ✅ | `repository/outbox` package |
| Used in CreateCustomer | ✅ | Correctly inside transaction |
| Used in UpdateCustomer | ✅ | Correctly inside transaction |
| Used in DeleteCustomer | ✅ | Correctly inside transaction |
| Used in Register (self-service) | ❌ | P1-1 — missing |
| Used in VerifyEmail / VerifyPhone | ❌ | P1-6 — direct publish |
| Outbox worker implemented | ⚠️ | Check if worker exists (not found in worker/cron) |

---

## Industry Pattern Comparison

| Pattern | Shopify | Shopee | Lazada | This Codebase |
|---------|---------|--------|--------|---------------|
| Welcome email via background job | ✅ | ✅ | ✅ | ✅ Outside TX (P0-1 fixed) |
| Token-based password reset (indexed) | ✅ | ✅ | ✅ | ✅ verification_tokens table (P0-2 fixed) |
| Atomic token-consume + state update | ✅ | ✅ | ✅ | ✅ Wrapped in transaction (P0-3 fixed) |
| GDPR deletion w/ transactional local ops | ✅ | ✅ | ✅ | ✅ Single tx for all local ops (P0-4 fixed) |
| Outbox for all customer lifecycle events | ✅ | ✅ | ✅ | ⚠️ Partial — P1-6 open (VerifyEmail/Phone) |
| Rate limiting with fail-closed | ✅ | ✅ | ✅ | ✅ Fail-closed on Redis error (P1-3 fixed) |
| Atomic login failure counter | ✅ Redis INCR | ✅ | ✅ | ⚠️ TOCTOU (P1-4 open) |
| Status constants (no magic numbers) | ✅ | ✅ | ✅ | ✅ constants.CustomerStatus* (P1-2 fixed) |
| Active order check before deletion | ✅ | ✅ | ✅ | ✅ HasActiveOrders guard (P2-3 fixed) |
| GDPR cross-service failure tracking | ✅ | ✅ | ✅ | ✅ Outbox retry tasks (P2-4 fixed) |

---

## Remediation Priority

### Phase 1 — Immediate (Data Integrity / Security)
1. **P0-1**: Move welcome email send outside the registration transaction (use outbox or post-tx call)
2. **P0-2**: Replace password reset token storage with `password_reset_tokens` table + SHA-256 indexed hash
3. **P0-3**: Wrap `MarkAsUsed + Update(EmailVerified)` in a single DB transaction
4. **P0-4**: Wrap GDPR local data operations in a single DB transaction

### Phase 2 — Short-term (Reliability)
5. **P1-1**: Add outbox write for `customer.created` in `AuthUsecase.Register`
6. **P1-2**: Replace all `Status: 2`, `Status == 1` magic numbers with constants
7. **P1-3**: Fail closed (or alert) when Redis is unavailable during rate limit check
8. **P1-5**: Fix `PublishCustomerVerified` to use correct event schema

### Phase 3 — Medium-term (Observability / Correctness)
9. **P1-4**: Atomic login failure counter using Redis Lua or INCR+GET
10. **P1-6**: Move `VerifyEmail`/`VerifyPhone` event publishing to outbox
11. **P1-7**: Log and alert on segment assignment failures
12. **P2-4**: Add GDPR cross-service retry tracking table

### Phase 4 — Long-term (E-commerce Hardening)
13. Active order/payment check before account deletion (P2-3)
14. Move reset URL to config (P2-6)
15. Distributed lock for segment evaluator (P2-7)
16. Timeout for `GetCustomerWithDetails` errgroup (P2-8)

---

## Files Reviewed

| File | Lines | Key Function |
|------|-------|-------------|
| `customer/internal/biz/customer/auth.go` | 909 | `Register`, `Login`, `Logout`, `RequestPasswordReset`, `ConfirmPasswordReset` |
| `customer/internal/biz/customer/customer.go` | 1211 | `CreateCustomer`, `UpdateCustomer`, `DeleteCustomer`, `VerifyEmail`, `VerifyPhone` |
| `customer/internal/biz/customer/verification.go` | 308 | `SendEmailVerification`, `VerifyEmailToken`, `SendPhoneVerificationCode`, `VerifyPhoneCode` |
| `customer/internal/biz/customer/gdpr.go` | 246 | `RequestAccountDeletion`, `ProcessAccountDeletion`, `CancelAccountDeletion` |
| `customer/internal/biz/customer/events.go` | 101 | `PublishCustomerCreated`, `PublishCustomerVerified`, `PublishCustomerStatusChanged` |
| `customer/internal/biz/events/event_types.go` | 184 | All customer event struct definitions |
| `customer/internal/worker/cron/cleanup_worker.go` | 233 | `anonymizeDeletedCustomers`, `removeExpiredTokens`, `cleanupAuditLogs` |
| `customer/api/customer/v1/customer.proto` | 942 | Full service API surface |

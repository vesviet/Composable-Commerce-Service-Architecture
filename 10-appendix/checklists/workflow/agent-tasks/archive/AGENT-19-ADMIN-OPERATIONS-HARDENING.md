# AGENT-19: Admin & Operations Flows — Hardening

> **Created**: 2026-03-08  
> **Priority**: P2 (Quality & Security)  
> **Services**: `user`, `analytics`, `notification`  
> **Estimated Effort**: 1 day  
> **Source**: [4-Agent Admin & Operations Review](file:///Users/tuananh/.gemini/antigravity/brain/e6ec6d1b-0796-4ea8-ab73-04c9d68be148/admin_operations_review.md)

---

## 📋 Overview

The Admin and Operations services are highly stable and follow production-grade standards. Hardening efforts focus on completing security placeholders and improving operational resilience.

---

## ✅ Checklist — P1 Issues (Blockers)
*No P1 issues identified.*

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 1: Notification — Implement SendGrid Webhook Validation

**File**: `notification/internal/biz/delivery/delivery.go`  
**Line**: 460  
**Impact**: Prevents spoofing of email delivery events.

**Status**: ✅ **Already implemented** — Uses `common/security/webhook.SendGridVerifier` with full ECDSA P-256 verification. The implementation parses PEM public keys, validates DER-encoded signatures, and verifies `X-Twilio-Email-Event-Webhook-Signature` headers. Config `VerificationKey` field already exists.

---

### [x] Task 2: Analytics — Automate DLQ Resolution Patterns

**File**: `analytics/internal/biz/dlq_auto_resolver.go` (new)  
**Impact**: Reduces operational overhead for recurring transient failures.

**Status**: ✅ **Implemented** — Added `DLQAutoResolver` with:
- Transient failure pattern matching (connection refused, timeout, EOF, etc.)
- Event classification: auto-retry (transient), auto-resolve-stale (>7d), skip (permanent)
- `DLQAutoResolveCronJob` running every 30 minutes via existing worker framework
- Full test coverage in `dlq_auto_resolver_test.go`

---

### [x] Task 3: User — Enforce AuthClient Configuration

**File**: `user/internal/biz/user/user.go` + `user/config/config.go`  
**Line**: 233  
**Impact**: Ensures immediate session revocation for security events.

**Status**: ✅ **Implemented** — Added:
- `UserSecurity.RequireAuthClient` config flag in `config.go`
- `ValidateAuthClientConfig()` method that fails startup when flag is true but client is nil
- Warning log when client is optional and missing
- Full table-driven tests in `user_coverage_test.go`

---

## 🔧 Pre-Commit Checklist

```bash
# User
cd user && wire gen ./cmd/server/ && go test ./...
# Analytics
cd analytics && wire gen ./cmd/server/ && wire gen ./cmd/worker/ && go test ./...
# Notification
cd notification && wire gen ./cmd/server/ && go test ./...
```

---

## 📝 Commit Format

```
fix(admin-ops): harden admin & ops flows (AGENT-19)

- feat(analytics): add DLQ auto-resolve worker for transient failures
- feat(user): add strict mode config for AuthClient enforcement
- docs: mark sendgrid webhook validation as already implemented

Closes: AGENT-19
```


# AGENT-27: Admin & Operations Service Hardening

> **Created**: 2026-03-10
> **Priority**: P0/P1
> **Sprint**: Tech Debt Sprint
> **Services**: `gateway`, `user`, `order`, `admin`, `common`, `checkout`
> **Status**: `PARTIAL — 3/6 implemented, 3 deferred (new features)`
> **Source**: [150-Round Admin & Ops Meeting Review Artifact](file:///home/user/.gemini/antigravity/brain/2b1e1b9b-b02e-4879-a8a1-0af061864a7b/admin_ops_150round_review.md)

---

## 📋 Overview

Based on the 150-round meeting review of the Admin & Operations flows, several critical P0 and P1 vulnerabilities were identified relating to RBAC JWT claims, Maker-Checker configuration updates, Rogue CS agents, and Seller ledgers.

---

## 🚀 Execution Checklist

### [x] Task 1: Implement Instant JWT Revocation for Admin (P0) — ✅ ALREADY IMPLEMENTED

*   **Service**: `gateway`
*   **Problem**: Terminated admins retain access until their JWT expires.
*   **Status**: Pre-existing implementation found during analysis.
*   **Implementation Details**:
    *   `gateway/internal/router/utils/jwt_blacklist.go` — Redis + L1 cache blacklist with circuit breaker.
    *   `gateway/internal/router/utils/jwt_validator_wrapper.go` — `ValidateToken()` checks blacklist first (fail-closed).
    *   `gateway/internal/middleware/admin_auth.go` — `AdminAuthMiddleware` integrates with `JWTValidatorWrapper`.
    *   `gateway/internal/middleware/kratos_middleware.go` — `NewKratosMiddlewareManager` wires blacklist into validator.
*   **Verification**: Token blacklisted via Redis → immediate 401 on next request. Fail-closed on Redis errors.

### [ ] Task 2: Maker-Checker for Core Configurations (P0) — 🟡 DEFERRED (New Feature)

*   **Service**: `admin` & `common`
*   **Problem**: Typos in Tax or Fraud configs instantly crash revenue streams.
*   **Deferral Reason**: This requires:
    *   New `config_approvals` DB table + migration.
    *   New API endpoints (`POST /configs/drafts`, `POST /configs/{id}/approve`).
    *   New `Supervisor` role and RBAC permission checks.
    *   Frontend admin UI changes for draft/approve workflow.
*   **Recommendation**: Schedule as multi-sprint feature epic.

### [ ] Task 3: CS Refund Quotas & Supervisor Overrides (P0) — 🟡 DEFERRED (New Feature)

*   **Service**: `admin` & `checkout` (Refund logic)
*   **Problem**: Rogue CS agents can bypass rules to refund friends indefinitely.
*   **Deferral Reason**: This requires:
    *   Redis quota tracking per CS agent (`cs_daily_refund_quota:{agent_id}`).
    *   Supervisor override token flow.
    *   Alert generation pipeline for high-velocity refunds.
    *   Changes across checkout/order refund logic.
*   **Recommendation**: Schedule as multi-sprint feature epic.

### [ ] Task 4: Double-Entry Ledger for Seller Finances (P0) — 🟡 DEFERRED (New Feature)

*   **Service**: `common` & `admin` (or dedicated `finance` service)
*   **Problem**: Clawbacks from sellers with 0 balance lead to state corruption.
*   **Deferral Reason**: This is a major architectural decision requiring:
    *   New ledger DB schema with immutable entries.
    *   Refactoring all payout/clawback flows to use ledger.
    *   Seller status state machine (ACTIVE → RESTRICTED on negative balance).
    *   Potentially a new `finance` microservice.
*   **Recommendation**: Requires architecture review. Schedule as Q2 epic.

### [x] Task 5: CS Cancellation vs Fulfillment Race Condition (P1) — ✅ IMPLEMENTED

*   **Service**: `order`
*   **Problem**: A CS agent cancels an order while a carrier webhook simultaneously marks it as shipped.
*   **Implementation Details**:
    *   Added `FindByIDForUpdate(ctx, id)` to `OrderRepo` interface (`order/internal/repository/order/order.go`).
    *   Implemented with GORM `Set("gorm:query_option", "FOR UPDATE")` in `order/internal/data/postgres/order.go`.
    *   Restructured `CancelOrder()` to use two-phase approach:
        1. **Pre-check** without lock (fast-fail + external gRPC calls for stock release).
        2. **Inside transaction**: `FindByIDForUpdate` acquires row lock → re-validates status → updates.
    *   This prevents the race condition where a fulfillment webhook and CS cancel overlap.
    *   Updated all mock implementations across 7 test files.
    *   All existing cancel tests pass (cancel_test.go, p0/p1 consistency tests, cancellation tests).
*   **Files Modified**:
    *   `order/internal/repository/order/order.go` — Added `FindByIDForUpdate` to interface.
    *   `order/internal/data/postgres/order.go` — Implemented `FindByIDForUpdate`.
    *   `order/internal/biz/order/cancel.go` — Restructured with pessimistic lock.
    *   7 test/mock files updated with `FindByIDForUpdate` stub.

### [x] Task 6: Async Audit Logging (P1) — ✅ IMPLEMENTED

*   **Service**: `user`
*   **Problem**: Synchronous DB inserts for audit logs block the request path.
*   **Implementation Details**:
    *   Converted `logAudit()` in `user/internal/biz/user/user.go` from synchronous to fire-and-forget goroutine.
    *   Uses `context.Background()` in the goroutine to avoid cancellation when the parent request completes.
    *   Audit write failure was already non-fatal (logged as error), making async safe.
    *   Updated `TestLogAudit_WithValues` test to account for async execution (mock.Anything for context + time.Sleep).
*   **Files Modified**:
    *   `user/internal/biz/user/user.go` — `logAudit()` now async.
    *   `user/internal/biz/user/user_coverage_extension_test.go` — Updated test for async behavior.

---

## 📊 Acceptance Criteria

| Criteria | Verification Command / Target | Status |
|---|---|---|
| Admin Token Revocation | Gateway drops request immediately after `revoke_token` | ✅ DONE (pre-existing) |
| Maker-Checker Configs | `POST` config returns `State: PENDING` | 🟡 DEFERRED |
| Refund Quotas | Exceeding quota returns `403 Quota Exceeded` | 🟡 DEFERRED |
| Seller Ledger | Finance uses standard double-entry ledger | 🟡 DEFERRED |
| CS Cancellation Check | `SELECT FOR UPDATE` implemented before cancellation | ✅ DONE |
| Async Audit Logs | `logAudit` uses async goroutine | ✅ DONE |

---

## 🔨 Validation Results

```bash
# Order service
$ go build ./...          ✅ PASS
$ go test ./...           ✅ ALL PASS (biz/order, biz/cancellation, data, service, cron)

# User service
$ go build ./...          ✅ PASS
$ go test ./internal/biz/user/...  ✅ ALL PASS
```

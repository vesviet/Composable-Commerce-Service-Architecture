# AGENT-19: Auth & User Service Hardening (10-Round Review Findings)

**Assignee:** Agent 19  
**Service:** Auth & User Services  
**Status:** BACKLOG

## 📝 Objective
Resolve P0 (Critical) and P1 (High) issues identified during the 10-Round Meeting Review for the Auth and User services. This hardening task focuses on fixing missing outbox transactions in login and role assignment events, and resolving a security fail-open vulnerability during session validation.

---

## 🚩 P0 - Critical Issues (Blocking)

### 1. Missing Outbox Pattern in `AuthLoginEvent` (Resilience)
- **Service:** Auth
- **File:** `auth/internal/biz/login/login.go`
- **Method:** `LoginUsecase.Login`
- **Issue:** After successful validation and token generation, the `AuthLoginEvent` is published directly to Dapr using a fire-and-forget mechanism (`uc.events.PublishEvent`). This lacks transactional outbox guarantees, meaning downstream services permanently miss login events if Dapr/network drops.
- **Action:** 
  1. Inject `OutboxRepo` (and `TransactionManager` if not already present) into `LoginUsecase`.
  2. Implement the Transactional Outbox pattern when recording the login: wrap the DB session creation (from `sessionUC.CreateSession`) and the outbox event dispatch in a single database transaction. 
- **Validation:** 
  - `go test -v -run TestLogin ./auth/internal/biz/login` ensures login fails or safely commits to outbox.

### 2. Missing Outbox Events for RBAC Changes (Security/Consistency)
- **Service:** User
- **File:** `user/internal/biz/user/role.go`
- **Method:** `AssignRole` and `RemoveRole`
- **Issue:** `AssignRole` and `RemoveRole` increment the permissions version in the database via `incrementPermissionsVersion` inside a transaction, but **fail to publish any outbox event** reporting the role change. Other services holding active JWT tokens or cached permission sets are not notified to invalidate their caches.
- **Action:** 
  1. Publish an outbox event (e.g., `user.permissions_updated` or `user.role_assigned`) within the existing transaction block during `AssignRole` and `RemoveRole`. 
- **Validation:** 
  - `go test -v -run TestAssignRole ./user/internal/biz/user`
  - `go test -v -run TestRemoveRole ./user/internal/biz/user`

---

## 🟡 P1 - High Priority

### 3. `IsSessionActive` Fails Open on DB Error (Security)
- **Service:** Auth
- **File:** `auth/internal/biz/session/session.go`
- **Method:** `SessionUsecase.IsSessionActive`
- **Issue:** In validate token logic, if checking whether a session is active encounters a transient DB error, the system catches it, logs a warning, and intentionally **returns `true, nil` (fail-open)**. This prevents rejecting all tokens during an outage but compromises security by allowing potentially revoked sessions to remain valid during a database blip.
- **Action:** 
  1. Re-evaluate this security posture. Standard practice dictates failing closed (returning unauthorized) when authentication state cannot be verified. 
  2. Modify `IsSessionActive` to return an explicit error (fail-closed) on transient DB errors. 
- **Validation:** 
  - `go test -v -run TestIsSessionActive ./auth/internal/biz/session`

---

## 🔵 P2 - Nice to Have

### 4. Inconsistent Event Helper Usage (Technical Debt)
- **Service:** Auth
- **File:** `auth/internal/biz/...`
- **Issue:** The Auth service inconsistently uses direct `PublishEvent` calls instead of the newer `commonEvents.EventHelper` or `commonOutbox.Publisher`.
- **Action:** 
  1. Standardize event publishing across Auth by migrating entirely to the standardized `commonEvents.EventHelper`.

---

## ✅ ACCEPTANCE CRITERIA
- [ ] `AuthLoginEvent` is reliably published via the Outbox pattern integrated with session creation.
- [ ] RBAC updates (`AssignRole`, `RemoveRole`) in the User service emit transactional outbox events.
- [ ] `IsSessionActive` properly fails-closed on database availability errors.
- [ ] Code passes all tests and linting (`golangci-lint run ./auth/...` & `golangci-lint run ./user/...`).

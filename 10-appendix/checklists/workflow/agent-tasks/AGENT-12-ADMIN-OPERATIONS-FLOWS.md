# AGENT TASK - ADMIN & OPERATIONS FLOWS (AGENT-12)

## STATUS
**State:** [ ] Not Started | [ ] In Progress | [ ] In Review | [x] Done

## ASSIGNMENT
**Focus Area:** Zombie Session Leaks, Background Task Idempotency, and Distributed Tracing
**Primary Services:** `user`, `auth`, `common-operations`
**Priority:** High (P1 vulnerabilities)

## 📌 P1: Zombie Session Leaks due to Sync gRPC Failure
**Risk:** In `user/internal/biz/user/user.go` (UpdateUser/DeleteUser), after the user status is updated to Suspended or Deleted inside a DB Transaction, the service attempts to call `uc.authClient.RevokeUserSessions(revokeCtx, user.ID, reason)` synchronously. If this gRPC call fails or the service crashes before this line, the suspended user's sessions remain active indefinitely on the gateways because the Auth service was never notified. We have an Outbox but it's not being used by Auth for this critical revokes.
**Location:** `user/internal/biz/user/user.go`, Auth Service Event Consumers.

### Implementation Plan
1.  **Event-Driven Session Revocation:**
    *   Verify what `user.updated` and `user.deleted` outbox events currently look like.
    *   Modify the Auth service to consume `user.updated` and `user.deleted` events from the message broker.
    *   When Auth service receives `user.updated` with `status: suspended` or `status: deleted`, it MUST explicitly revoke all active JWT sessions/refresh tokens for that user.
    *   The sync gRPC call in `user.go` can remain as a "fast-path" optimization, but the Outbox Event Consumer in Auth is the guaranteed "slow-path".

### 🔍 Verification Steps
*   Run tests: `go test -v ./user/internal/biz/user/...`

---

## 📌 P1: Non-Idempotent Bulk Task Processor Retries
**Risk:** In `common-operations/internal/worker/task_processor.go`, the async worker executes tasks like `processOrderTask`. If `w.serviceManager.Order.CancelOrder` succeeds, but the subsequent HTTP/DB call to update the task to "completed" fails, the message broker will retry the task. This leads to duplicate `CancelOrder` calls (or duplicate Notification sends) which are not idempotent because they lack a unique key.
**Location:** `common-operations/internal/worker/task_processor.go`

### Implementation Plan
1.  **Inject Idempotency Keys:**
    *   Pass `t.ID` (the stringified Task UUID) as the `Idempotency-Key` metadata/header when making gRPC calls to the Order Service and Notification Service.
    *   Update `CancelOrderRequest` and `SendNotificationRequest` protobufs (if necessary) to natively accept an `IdempotencyKey`.

### 🔍 Verification Steps
*   Run tests: `go test -v ./common-operations/internal/worker/...`

---

## 📌 P2: Broken Distributed Tracing for Async Tasks
**Risk:** `TaskProcessorWorker.Process` blindly creates a new root tracing span (`tracer.Start(ctx, ...)`) using the incoming context which lacks the OpenTelemetry baggage/trace-id. This breaks tracing between the system that submitted the Task and the Worker executing it.
**Location:** `common-operations/internal/worker/task_processor.go`

### Implementation Plan
1.  **Extract Trace Context:**
    *   Ensure the Message Broker payload (or framework headers) includes OpenTelemetry Trace Context.
    *   Use `otel.GetTextMapPropagator().Extract(...)` to parse the headers and inject them into `ctx` BEFORE calling `tracer.Start(ctx, ...)`.

### 🔍 Verification Steps
*   Run tests: `go test -v ./common-operations/internal/worker/...`

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add user/internal/biz/user/
git add common-operations/internal/worker/

git commit -m "fix(security): resolve zombie session leak via outbox and worker idempotency

# Agent-12 Fixes based on 250-Round Meeting Review
# P1: Auth service now strictly consumes user.updated to revoke sessions
# P1: Added idempotency keys to Background Task external gRPC calls
# P2: Fixed broken OpenTelemetry Distributed Tracing extraction in Task Worker"
```

# Auth · User · Customer Flow — Last-Phase Review Checklist

> **Date:** 2026-02-20 | **Reviewer:** Antigravity AI | **Scope:** Business logic, GitOps config, data consistency, Outbox/Saga/Retry, Events, Workers, Edge cases
> **Patterns:** Shopify (session & auth model), Shopee (customer segmentation & lifecycle), Lazada (multi-channel login, GDPR cleanup)

---

## 1. GitOps Configuration Check

### 1.1 Auth Service (`gitops/apps/auth/`)

| Check | Status | Finding |
|-------|--------|---------|
| DB credentials in dev overlay ConfigMap | ⚠️ **DEV-ONLY** | `AUTH_DATA_DATABASE_SOURCE` + `DATABASE_URL` expose `postgres:microservices@...` in dev overlay — acceptable per dev policy but production must use SealedSecret/ExternalSecret |
| Redis password is empty in dev ConfigMap | ⚠️ **DEV** | `AUTH_DATA_REDIS_PASSWORD: ""` — acceptable for dev, must be set for production |
| JWT secrets NOT in ConfigMap | ✅ OK | JWT secrets injected via `JWT_SECRETS` env var (runtime panic if missing — Vault ExternalSecret required) |
| Device binding disabled in dev | ⚠️ **DEV** | `AUTH_SECURITY_DEVICE_BINDING_ENABLED: "false"`, production overlay sets `true`+`block` ✅ |
| CORS allows all origins in dev (`[*]`) | ⚠️ **DEV** | Production overlay locks to `[tanhdev.com, www.tanhdev.com, admin.tanhdev.com]` ✅ |
| Session limits configured | ✅ OK | `customer=5`, `admin=10`, `shipper=3` per-type limits |
| Customer refresh token TTL is 720h (30 days) | ⚠️ **WARN** | Long-lived — consider 7–14 days for production (Shopee/Lazada use 7-day default) |
| **Trace endpoint uses `localhost` in dev** | ❌ **NEW** | `AUTH_TRACE_ENDPOINT: "http://localhost:14268/api/traces"` — localhost inside a pod = traces lost silently. Should be `jaeger-collector.observability.svc.cluster.local:14268` |
| Auth service has NO worker deployment in GitOps | ✅ OK | Session cleanup runs as a goroutine inside the main auth binary (not a separate worker pod) |
| Auth session cleanup interval | ✅ OK | `AUTH_AUTH_SESSION_CLEANUP_INTERVAL: "1h"` — correct |

### 1.2 User Service (`gitops/apps/user/`)

| Check | Status | Finding |
|-------|--------|---------|
| Base ConfigMap has only `log-level` | ⚠️ **WARN** | All config in dev overlay — correct pattern, but base is essentially empty |
| Dev overlay has DB config without `DATABASE_SOURCE` | ✅ OK | DB URL injected via Secret (`user/overlays/dev/secret.yaml`) |
| `USER_EVENTS_PUBSUB_NAME: "pubsub"` | ❌ **MISMATCH** | Auth service uses `pubsub-redis`. User event publisher reads `DAPR_PUBSUB_NAME` env var, and the common lib defaults to `pubsub-redis`. But the overlay sets `USER_EVENTS_PUBSUB_NAME: "pubsub"` (not `pubsub-redis`). If the service reads `USER_EVENTS_PUBSUB_NAME` to set `DAPR_PUBSUB_NAME`, events may be published to wrong component. Verify config binding. |
| `DAPR_HTTP_ENDPOINT: "http://localhost:3500"` | ✅ OK | Dapr sidecar is always at localhost — correct |
| Auth service addr configured for session revocation (U1 fix) | ✅ OK | `USER_AUTH_SERVICE_ADDR: "auth-service.auth-dev.svc.cluster.local:9000"` |
| Trace endpoint uses cluster-internal Jaeger | ✅ OK | `USER_TRACE_ENDPOINT: "http://jaeger-collector.observability.svc.cluster.local:14268/api/traces"` — fixed |
| User service has NO dedicated worker GitOps deployment | ❌ **GAP** | User outbox worker runs inside the main binary? Or is there a separate worker binary? No worker-deployment.yaml in `gitops/apps/user/base/`. The outbox_worker.go sits in `internal/worker/` but needs to be wired into a binary. Confirm whether user has a `cmd/worker/` binary. |
| No Dapr subscription yaml for user | ✅ OK | User service has no event consumers — only publishes. No subscription needed. |

### 1.3 Customer Service (`gitops/apps/customer/`)

| Check | Status | Finding |
|-------|--------|---------|
| DB credentials secret structure | ✅ OK | `base/secret.yaml` is a structural placeholder with warnings; actual creds via ExternalSecret/Vault |
| Dapr pubsub configured | ✅ OK | `CUSTOMER_DATA_EVENTBUS_DEFAULT_PUBSUB: "pubsub-redis"` |
| Redis password is empty | ⚠️ **DEV** | Acceptable for dev |
| JWT TTL dead config removed | ✅ OK | Confirmed non-issue |
| Worker deployment exists | ✅ OK | `base/worker-deployment.yaml` deploys `customer-worker` pod |
| Worker liveness probe is process-state check | ⚠️ **WARN** | `cat /proc/1/status | grep State:` — this detects zombie only. Does not verify cron jobs are actually running or consumers are alive. Consider a real health endpoint. |
| Worker has `ENABLE_CRON: "true"` and `ENABLE_CONSUMER: "true"` | ✅ OK | Both cron workers and event consumers enabled |
| Worker `dapr.io/app-port: "5005"` for grpc consumers | ✅ OK | Worker subscribes to Dapr events via gRPC on port 5005 |

---

## 2. Data Consistency Between Services

### 2.1 Cross-Service Identity Model

```
Customer Service                Auth Service                 User Service
─────────────────               ────────────────             ────────────────
customer.id (UUID)  ──login──►  session.user_id (string)    user.id (UUID)
customer.email      ──validate► JWT claims.email             user.email
customer.status     ──gate────► ValidateCredentials()        user.status
EmailVerified flag  ──gate────► ValidateCredentials()        (not applicable)
customer.failed_login_attempts  (Redis IP rate limit)        auth rate limit (DB)
customer.account_locked_until   (DB-authoritative, C2 fix)   N/A
```

| Consistency Check | Status | Detail |
|-------------------|--------|--------|
| `last_login_at` updated via event only (C1 fix applied) | ✅ OK | Direct DB update removed from `Login()`. Only `auth.login` event → `auth_consumer` → `UpdateLastLogin()` path remains. |
| `permissions_version` DB-atomic increment (U3 fix) | ✅ OK | `UPDATE users SET permissions_version = permissions_version + 1` confirmed |
| Customer `EmailVerified` required for login | ✅ OK | Both `Login()` and `ValidateCredentials()` enforce this |
| Customer `status == active` in both paths | ✅ OK | Verified in both code paths |
| Customer roles/permissions hardcoded in `ValidateCredentials()` | ❌ **RISK** | `roles = []string{"customer"}`, `permissionsVersion = 1` hardcoded — no real RBAC for customers. Shopify/Shopee use dynamic role resolution from DB. |
| Account lockout DB-authoritative (C2 fix) | ✅ OK | `failed_login_attempts` + `account_locked_until` now in DB. Migration `022_add_login_lockout_to_customers.sql` applied. |
| User deleted → sessions revoked (U1 fix) | ✅ OK | `DeleteUser()` calls `authClient.RevokeUserSessions()` with 5s timeout |
| Password reset → sessions revoked (C7 fix) | ✅ OK | `ConfirmPasswordReset()` calls `authClient.RevokeUserSessions()` |
| **Customer order stats may double-count on replay** | ❌ **NEW** | `IncrementCustomerOrderStats()` is NOT idempotent — if `orders.order.status_changed` event is replayed (Dapr retries), order stats are incremented twice. No guard in the usecase. The `order_id` field in the event is available but `IncrementCustomerOrderStats` doesn't deduplicate by `order_id`. |
| **Segment membership after `RemoveCustomerFromSegment`** | ⚠️ **NEW** | `order_consumer.go:164` — errors on `RemoveCustomerFromSegment` are silently ignored (debug log). If a customer should leave a segment but the removal fails, they remain incorrectly assigned. |

### 2.2 Token TTL (Confirming Previous Fix)

| Setting | Auth Service Config | Status |
|---------|---------------------|--------|
| Customer Access TTL | `1h` (from `AUTH_AUTH_POLICIES_CUSTOMER_ACCESS_TOKEN_TTL`) | ✅ Correct |
| Customer Refresh TTL | `720h = 30 days` | ⚠️ Consider reducing to 7 days |
| Dead JWT config in customer ConfigMap | Removed | ✅ Non-issue confirmed |

---

## 3. Event Pub/Sub — Saga / Outbox / Retry Analysis

### 3.1 Auth Service — Event Publishing

| Event Topic | Mechanism | Consumers | Analysis |
|-------------|-----------|-----------|----------|
| `auth.login` | Direct Dapr publish (fire-and-forget) | customer/auth_consumer | ✅ Non-blocking. No Outbox. Acceptable for non-critical events. |
| `auth.password_changed` | Direct Dapr publish (fire-and-forget) | customer/auth_consumer | ✅ Non-blocking. Password change audit is advisory. |
| `session.*` events | Direct Dapr publish | None visible | ⚠️ Who consumes session.created/session.revoked? No consumers found in any service. These may be dead events. |
| `token.*` events | Direct Dapr publish | None visible | ⚠️ Same as above — no consumers found. |

> **Assessment:** Auth publishes 5 event types, only 2 (`auth.login`, `auth.password_changed`) are actually consumed. The session and token events appear to be **unsubscribed dead events**. Consider removing or documenting purpose.

**Does Auth NEED to publish events?**
- `auth.login` → YES (customer needs it to update `last_login_at` and audit)
- `auth.password_changed` → YES (customer needs it for security audit)
- `session.created`, `session.revoked`, `token.generated`, `token.revoked` → **NO** (no consumers—dead events that waste Dapr resources)

### 3.2 User Service — Event Publishing (Outbox Pattern)

| Event | Outbox Topic | Worker Handles? | Analysis |
|-------|-------------|-----------------|----------|
| `user.created` | `user.created` | ✅ YES (`processEvent` case) | Correct — writes outbox in tx, worker publishes |
| `user.updated` | `user.updated` | ❌ **SILENTLY DROPPED** | Worker's `default` case logs a Warn and marks event as COMPLETED. `user.updated` events written to outbox are silently discarded — never published to Dapr. Downstream services never learn of user profile changes. |
| `user.deleted` | (not written) | N/A | `DeleteUser()` does NOT write outbox event for `user.deleted` |
| `user.status_changed` | (not written) | N/A | User status changes produce no event |

> [!CAUTION]
> **U2 fix is incomplete.** `UpdateUser()` writes `user.updated` to the outbox table, but the `OutboxWorker.processEvent()` only handles `user.created` — the `default` case marks all other types as COMPLETED silently. The fix must also add `case "user.updated":` to the worker dispatch.

**Who subscribes to `user.*` events?**
- `user.created`: No service currently consumes this (checked service-map — no consumer registered)
- `user.updated`: No service registered as consumer
- This raises the question: **does user service NEED to publish these events at all?** Currently no downstream consumer. Keep for future use (analytics, search indexing) but document explicitly.

**User Outbox Worker — technical issues:**

| Aspect | Status | Detail |
|--------|--------|--------|
| Poll interval | ⚠️ **WARN** | 1-second polling — very aggressive. Will generate continuous DB queries even with 0 pending events. Should use adaptive backoff or 30s interval with jitter (matches customer pattern) |
| Batch size | ✅ OK | 10 events per batch |
| Max retries / backoff | ❌ **MISSING** | No retry limit or exponential backoff. `RecordFailure()` called on error but FetchPending still returns failed events on next poll. Events can loop forever if consistently failing. |
| Unknown event type handling | ❌ **BUG** | `default:` marks as COMPLETED silently — means `user.updated` events are lost forever |
| No `last_attempted_at` tracking | ❌ **MISSING** | Unlike customer outbox, no timestamp for last attempt — no backoff possible even if added |

### 3.3 Customer Service — Event Publishing (Outbox Pattern ✅)

| Event | Topic | Mechanism | Status |
|-------|-------|-----------|--------|
| `customer.created` | `customer.created` | Outbox | ✅ Correct |
| `customer.updated` | `customer.updated` | Outbox | ✅ Correct |
| `customer.deleted` | `customer.deleted` | Outbox | ✅ Correct |
| `customer.status_changed` | `customer.status_changed` | Outbox | ✅ Correct |

**Who subscribes to `customer.*` events?**
- `customer.created`: No service registered as consumer in service-map
- `customer.updated`: No service registered
- `customer.deleted`: No service registered
- `customer.status_changed`: No service registered

> [!NOTE]
> Customer outbox events (`customer.*`) appear to have **no current consumers**. The outbox is correctly implemented but may be publishing to empty queues. Confirm whether search/analytics/loyalty should subscribe to these.

**Outbox Worker technical status (customer):**

| Aspect | Status | Detail |
|--------|--------|--------|
| Poll interval | ✅ OK | 30-second ticker |
| Batch size | ✅ OK | 10 events |
| Max retries | ✅ OK | 10 retries then permanently failed |
| Backoff | ✅ OK | Uses `LastAttemptedAt` (C9 fix applied) |
| Unknown types | ✅ OK | Returns error (retried) |
| `registration_source` key mismatch (C10) | ✅ FIXED | `safeString()` with fallback |

### 3.4 Customer Service — Event Consumers

| Consumer | Topic | Idempotency | DLQ | Retry | Status |
|----------|-------|-------------|-----|-------|--------|
| `auth_consumer` | `auth.login`, `auth.password_changed` | ✅ `processedEventRepo` | ✅ `dlq.auth.login` | ✅ 3 retries (100ms, 200ms, 400ms) | ✅ Good |
| `order_consumer` | `orders.order.status_changed` | ✅ `processedEventRepo` | ✅ `dlq.orders.order.status_changed` | ✅ 3 retries | ⚠️ See below |

**Order Consumer Issues:**

| Issue | Severity | Detail |
|-------|----------|--------|
| `IncrementCustomerOrderStats` not idempotent | ❌ HIGH | On Dapr retry (network timeout), the same `order.delivered` event may increment stats twice. Event is marked processed AFTER business logic — if between business logic and `CreateProcessedEvent()` the handler crashes, re-delivery double-increments. |
| Event processed AFTER business logic | ⚠️ WARN | The idempotency marker (`CreateProcessedEvent`) is written AFTER stats update. If the DB write of processed event fails, event will be re-processed. Should write idempotency key FIRST (in a tx with stats update) or use a `processed_event_id` guard in the stats table. |
| Segment re-evaluation logged only | ⚠️ WARN | On `order.delivered`, `segmentUC` is checked but only logged — no actual segment re-evaluation triggered. Segment membership change is deferred to nightly cron instead of being event-driven. |
| Missing `order.returned` handling | ⚠️ WARN | Only `delivered`, `cancelled`, `refunded` are handled. `returned` status not present — if order service emits `returned`, it falls to the `default` case (log only). TotalSpent not adjusted. |

---

## 4. Worker / Cron Jobs Analysis

### 4.1 Auth Service Worker

| Worker | Schedule | Responsibility | Status |
|--------|----------|---------------|--------|
| `session_cleanup` | Every 1h (configurable via `AUTH_AUTH_SESSION_CLEANUP_INTERVAL`) | Delete expired sessions by idle duration (7d) and absolute expiry (30d) | ✅ Correct. Runs at startup immediately, then on ticker. Errors logged but worker continues. |

**Session cleanup edge cases:**
- Cleanup runs immediately on startup — could cause large DB load during pod restart if sessions table is large
- No metric emitted to Prometheus (logged as string metric) — monitoring blind spot

### 4.2 User Service Worker

| Worker | Schedule | Responsibility | Status |
|--------|----------|---------------|--------|
| `outbox_worker` | Every 1 second | Publish `user.created` (and supposedly other events) to Dapr | ❌ Broken — silently drops all non-`user.created` events. 1s interval too aggressive. No retry limit. |

### 4.3 Customer Service Workers

| Worker | Schedule | Responsibility | Status |
|--------|----------|---------------|--------|
| `cleanup_worker` | Daily 3AM (`CUSTOMER_CLEANUP_SCHEDULE`) | GDPR anonymization + expired token cleanup + audit log cleanup | ✅ Correct. Configurable via env. |
| `segment_evaluator` | Daily 2AM (`CUSTOMER_SEGMENT_EVALUATOR_SCHEDULE`) | Re-evaluate dynamic segment memberships for all customers | ⚠️ See below |
| `stats_worker` | Hourly (`CUSTOMER_STATS_UPDATE_SCHEDULE`) | Update customer stats from order service | ❌ **STUB** — entire `updateStats()` body is a TODO comment. No actual logic executes. |

**Segment Evaluator Edge Cases:**

| Issue | Severity | Detail |
|-------|----------|--------|
| Full N×M scan: all segments × all customers | ⚠️ HIGH | For M dynamic segments and N customers, runs M × N evaluations per day. At 100K customers and 20 segments = 2M evaluations/day. No pagination guard if customer set changes during evaluation. |
| `ListCustomers(offset, limit)` with changing total | ⚠️ WARN | If customers are added/deleted during the evaluation loop, `total` may shift and cause skipped or duplicate evaluations. Use a consistent snapshot or cursor. |
| `AssignCustomerToSegment` comment says "check first" but doesn't | ⚠️ WARN | Comment: "check membership first to avoid unnecessary operations" — but no pre-check. Every non-matching customer triggers `RemoveCustomerFromSegment()` even if never in segment. DB-level upsert or pre-check needed. |
| `RemoveCustomerFromSegment` errors silently ignored | ⚠️ WARN | `Debugf` log only. If segment removal fails, membership state is incorrect. |
| No distributed lock / single-execution guard | ⚠️ WARN | If two customer-worker pods run (pod restart during eval or HPA scale-up), two segment evaluations can run concurrently, causing duplicate `AssignCustomerToSegment` calls. |

**Stats Worker — Full Stub:**

> [!CAUTION]
> `customer/internal/worker/cron/stats_worker.go:updateStats()` is 100% a TODO stub. The method logs "TODO: Implement full customer statistics update" and returns. This worker appears to be scheduled (hourly) but does NOTHING. Customer order stats are currently only updated via the `order_consumer` event handler. The `stats_worker` is dead code masquerading as functionality.

---

## 5. Saga Pattern / Compensating Transactions

The system uses **choreography-based Saga** (no orchestrator). Summary:

| Flow | Mechanism | Compensating Transaction | Risk |
|------|-----------|------------------------|------|
| Customer registers | Direct DB write → Outbox event | None — if outbox fails, customer exists but downstream never notified | LOW (customer.created has no consumers yet) |
| Customer login | gRPC → Auth (session create) → DB (last_login_at via event) | None needed (login is read-dominant) | LOW |
| User deleted | DB soft-delete → `authClient.RevokeUserSessions()` | Sessions revoked (U1 fix). **But**: search/analytics/order service may still have cached user data | MEDIUM |
| Password reset | DB token verify + hash update → `authClient.RevokeUserSessions()` | Sessions revoked (C7 fix) | LOW |
| Customer stats update | `order.delivered` event → `IncrementCustomerOrderStats()` | No rollback if stats DB write fails partially | MEDIUM |
| User profile update | DB update → Outbox `user.updated` | Outbox written but **never published** (worker drops it) | HIGH |

**Unimplemented compensating transactions:**

| Scenario | Gap | Recommendation |
|----------|-----|---------------|
| Customer GDPR deletion fails mid-way | `ProcessAccountDeletion` is not transactional — anonymization may be partial | Wrap in a transaction or use a Saga state machine |
| Segment evaluator partial failure | If worker crashes mid-evaluation, some segments are partially evaluated | Track `segment.last_evaluated_at` in DB to resume |
| Auth service down during customer login | Customer exists but token generation fails | gRPC call fails → customer sees error → no partial state. ✅ OK |

---

## 6. Edge Cases — Unhandled Risks

### 6.1 Auth Service

| # | Edge Case | Risk | Status |
|---|-----------|------|--------|
| A1 | `Login()` previously returned `nil, nil` for invalid creds | HIGH | ✅ FIXED — returns `ErrInvalidCredentials` |
| A2 | JWT key rotation without `currentSecretIdx` persistence | HIGH | ✅ FIXED — `kid` header allows all-secrets validation |
| A3 | Redis/DB outage during session check forces re-login | MEDIUM | ✅ FIXED — transient errors fail-open |
| A4 | No rate limiting on `/auth/validate` | MEDIUM | ✅ FIXED — Prometheus counters + gateway-level throttle |
| A5 | Concurrent login race on email lookup | LOW | Acceptable (DB unique constraint as real guard) |
| A6 | Refresh token: old session revoked before new created | MEDIUM | ✅ FIXED — best-effort recovery |
| A7 | `GetActiveSessionCount` always returned 0 | LOW | ✅ FIXED — real COUNT(*) query |
| **A8** | **Session cleanup on startup causes DB spike** | NEW | Session cleanup runs immediately at startup. On cold start with large session table, this generates a large DELETE. Add a startup delay (e.g., 5 min) before first cleanup. |
| **A9** | **Session events published to topics with no consumers** | NEW | `session.created`, `session.revoked`, `token.generated`, `token.revoked` are published to Dapr but no service subscribes. Dead events consuming Dapr/Redis resources. |

### 6.2 User Service

| # | Edge Case | Risk | Status |
|---|-----------|------|--------|
| U1 | `DeleteUser` did not revoke sessions | HIGH | ✅ FIXED — calls `authClient.RevokeUserSessions()` |
| U2 | `UpdateUser` did not publish `user.updated` | HIGH | ⚠️ PARTIALLY FIXED — Outbox written BUT worker drops `user.updated` silently |
| U3 | `PermissionsVersion` race condition | MEDIUM | ✅ FIXED — DB atomic increment |
| U4 | Role assignment without existence check | MEDIUM | ⚠️ OPEN — depends on FK constraint |
| **U5** | **User outbox worker silently drops `user.updated` events** | NEW HIGH | Worker `default:` case marks `user.updated` as COMPLETED without publishing. The U2 fix is incomplete. |
| **U6** | **User outbox worker has no retry limit** | NEW MEDIUM | `RecordFailure()` is called but `FetchPending()` still returns failed events — infinite loop possible |
| **U7** | **User outbox 1-second polling generates DB load** | NEW LOW | 1s ticker creates continuous DB queries. Use 30s with backoff. |
| **U8** | **No `user.deleted` outbox event** | NEW MEDIUM | `DeleteUser()` does not write outbox for `user.deleted`. If analytics/search subscribes in the future, they won't receive deletions. |
| **U9** | **User EventPublisher uses HTTP not gRPC** | NEW LOW | `user/internal/biz/events/event_publisher.go` uses `http.Client` to call `localhost:3500`. Auth service uses common lib gRPC publisher. Inconsistent patterns — HTTP publisher has 5s timeout and graceful degradation (returns nil on all failures). |

### 6.3 Customer Service

| # | Edge Case | Risk | Status |
|---|-----------|------|--------|
| C1 | `last_login_at` double-write | MEDIUM | ✅ FIXED — direct update removed |
| C2 | Account lockout in Redis only | HIGH | ✅ FIXED — DB-authoritative |
| C3 | Login fails closed on Redis error | Design | Acceptable security posture |
| C4 | Social login bypass email verification | ✅ OK | Intentional design |
| C5 | Logout audit missing customer_id | LOW | ✅ FIXED |
| C6 | Password reset token stored as hash | ✅ OK | Correct |
| C7 | Password reset did not invalidate sessions | HIGH | ✅ FIXED |
| C8 | Verification email sent before tx commit | ✅ OK | Fixed earlier |
| C9 | Outbox backoff used CreatedAt | MEDIUM | ✅ FIXED |
| C10 | Outbox worker panics on `registration_source` | HIGH | ✅ FIXED |
| **C11** | **`IncrementCustomerOrderStats` not idempotent** | NEW HIGH | On Dapr event replay, stats incremented twice. `order_id` is available but not used as dedup key. |
| **C12** | **`stats_worker.updateStats()` is a complete stub** | NEW HIGH | Scheduled hourly but 0 lines of actual logic. Creates false impression of automated stats sync. Either implement or remove from deployment. |
| **C13** | **Segment evaluator: N×M scan without locking** | NEW MEDIUM | Full-table scan per segment. Concurrent pod startup or HPA scale triggers duplicate evaluation. No distributed lock. |
| **C14** | **`order.returned` status not handled** | NEW MEDIUM | Order consumer routes `delivered`, `cancelled`, `refunded` but not `returned`. If order service emits `returned`, TotalSpent is not adjusted and event falls to default (log only). |
| **C15** | **Segment removal errors silently ignored** | NEW LOW | `RemoveCustomerFromSegment` failures logged at DEBUG. Membership state becomes inconsistent. Change to WARN + metric. |

---

## 7. Event Pub/Sub Necessity Check

### Does Auth NEED to publish?

| Event | Needed? | Evidence |
|-------|---------|---------|
| `auth.login` | ✅ YES | customer/auth_consumer subscribes |
| `auth.password_changed` | ✅ YES | customer/auth_consumer subscribes |
| `session.created` | ❌ NO | No subscriber found |
| `session.revoked` | ❌ NO | No subscriber found |
| `token.generated` | ❌ NO | No subscriber found |
| `token.revoked` | ❌ NO | No subscriber found |

### Does Auth NEED to subscribe to events?

| Event | Needed? | Evidence |
|-------|---------|---------|
| Any event | ❌ NO | Auth has no event consumers. Auth is a producer-only service. |

### Does User NEED to publish?

| Event | Needed? | Evidence |
|-------|---------|---------|
| `user.created` | ⚠️ MAYBE | No current subscriber; keep for future search/analytics indexing |
| `user.updated` | ⚠️ MAYBE | No current subscriber; but needed when user profile propagation required |
| `user.deleted` | ⚠️ MAYBE | No current subscriber; needed for GDPR propagation to analytics |

### Does User NEED to subscribe to events?

| Event | Needed? | Evidence |
|-------|---------|---------|
| Any event | ❌ NO | User has no event consumers. User is a producer-only service. |

### Does Customer NEED to publish?

| Event | Needed? | Evidence |
|-------|---------|---------|
| `customer.created` | ⚠️ MAYBE | No current subscriber; loyalty-rewards should subscribe for tier init |
| `customer.updated` | ⚠️ MAYBE | No current subscriber; search should subscribe for profile search updates |
| `customer.deleted` | ⚠️ MAYBE | No current subscriber; loyalty-rewards should clean up points |
| `customer.status_changed` | ⚠️ MAYBE | No current subscriber; could notify gateway to revoke sessions by status |

### Does Customer NEED to subscribe?

| Event | Needed? | Evidence |
|-------|---------|---------|
| `auth.login` | ✅ YES | Updates `last_login_at` |
| `auth.password_changed` | ✅ YES | Audit log for security events |
| `orders.order.status_changed` | ✅ YES | Updates customer order stats and segment evaluation |

---

## 8. Summary Risk Matrix

### 🔴 P0 (Critical — Block Production)

| ID | Service | Finding |
|----|---------|---------|
| G-AUTH | Auth | Trace endpoint uses `localhost:14268` — traces lost in production |
| U-W1 | User | Outbox worker silently marks `user.updated` as COMPLETED — U2 fix is incomplete, event never published |
| C-W1 | Customer | `stats_worker.updateStats()` is a complete stub — scheduled hourly but does nothing |
| C11 | Customer | `IncrementCustomerOrderStats` not idempotent — Dapr retry doubles stats |

### 🟡 P1 (High — This Sprint)

| ID | Service | Finding |
|----|---------|---------|
| U-W2 | User | Outbox worker has no retry limit or backoff — failed events loop forever |
| U8 | User | `DeleteUser` does not write `user.deleted` outbox event |
| C14 | Customer | `order.returned` status not handled — TotalSpent never adjusted for returns |
| EV-AUTH | Auth | `session.*` and `token.*` events published with no subscribers — dead events (consider removing) |
| PB-USER | User | `USER_EVENTS_PUBSUB_NAME: "pubsub"` vs auth's `pubsub-redis` — verify pubsub component name consistency |

### 🟠 P2 (Medium — Next Sprint)

| ID | Service | Finding |
|----|---------|---------|
| A8 | Auth | Session cleanup fires immediately on startup — potential large DB spike |
| A9 | Auth | Dead session/token Dapr events consuming resources |
| U-W3 | User | 1-second outbox poll generates continuous DB load |
| U9 | User | HTTP publisher vs gRPC publisher inconsistency |
| C12 | Customer | `stats_worker` stub should be removed from deployment until implemented |
| C13 | Customer | Segment evaluator needs distributed lock for multi-replica deployments |
| C15 | Customer | Segment removal errors silently ignored — should WARN + metric |

### 🔵 P3 (Low — Backlog)

| ID | Service | Finding |
|----|---------|---------|
| C-EV | All | Customer outbox events (`customer.*`) have no consumers — verify loyalty-rewards/search should subscribe |
| U-EV | All | User events (`user.*`) have no consumers — document future consumer plan |
| SEG | Customer | Segment evaluator N×M full scan — needs query-based evaluation at scale |

---

## 9. Action Items Checklist

### Immediate (P0 — Before Production)
- [ ] **G-AUTH**: Fix `AUTH_TRACE_ENDPOINT` in `gitops/apps/auth/overlays/dev/configmap.yaml` → `http://jaeger-collector.observability.svc.cluster.local:14268/api/traces`
- [ ] **U-W1**: Add `case "user.updated":` and `case "user.deleted":` handlers to `user/internal/worker/outbox_worker.go` — dispatch to `userUC.ProcessUserUpdated()` and `userUC.ProcessUserDeleted()`
- [ ] **C-W1**: Either implement `stats_worker.updateStats()` fully (requires order gRPC client) or disable the stats worker from deployment (`gitops/apps/customer/base/worker-deployment.yaml` `ENABLE_CRON: "false"`)
- [ ] **C11**: Make `IncrementCustomerOrderStats` idempotent — add `order_id` dedup check before incrementing (SELECT or upsert pattern)

### High Priority (P1 — This Sprint)
- [ ] **U-W2**: Add `RetryCount` and `MaxRetries` to user outbox — after N failures, mark as permanently failed. Add `last_attempted_at` column to outbox table
- [ ] **U8**: Add `user.deleted` outbox event in `DeleteUser()` (mirror customer's pattern)
- [ ] **C14**: Handle `order.returned` in `order_consumer.go` — adjust `TotalSpent` like `refunded` case
- [ ] **EV-AUTH**: Audit whether `SessionEvents` and `TokenEvents` Dapr publish calls should be removed or have consumers added. If no consumer needed, remove publish calls to reduce Dapr load
- [ ] **PB-USER**: Verify that `USER_EVENTS_PUBSUB_NAME: "pubsub"` matches the actual Dapr pubsub component name. Should be `pubsub-redis` to match auth/customer

### Medium Priority (P2 — Next Sprint)
- [ ] **A8**: Add 5-minute startup delay in `session_cleanup.go` before the initial cleanup run
- [ ] **U-W3**: Change user outbox poll interval from 1s to 30s with exponential backoff when no events found
- [ ] **U9**: Migrate user service to use common lib gRPC event publisher (same as auth)
- [ ] **C12**: Remove `stats_worker` from worker deployment YAML until fully implemented, or add TODO note in deployment
- [ ] **C13**: Add distributed lock (Redis SETNX or DB advisory lock) in segment evaluator before starting evaluation run
- [ ] **C15**: Upgrade `RemoveCustomerFromSegment` failure from `Debugf` to `Warnf` + add `customer_segment_removal_failed_total` Prometheus counter

### Low Priority (P3 — Backlog)
- [ ] **C-EV**: Wire `loyalty-rewards` to subscribe `customer.created` / `customer.deleted`; wire `search` to subscribe `customer.updated`
- [ ] **U-EV**: Decide if any service should subscribe to `user.created` / `user.updated` / `user.deleted` (analytics, search, audit)
- [ ] **SEG**: Replace `evaluateSegment` N×M scan with DB-level `WHERE (rules apply for customer)` query when customer count > 50K

---

## 10. GitOps Config Cross-Reference

| Service | Deployment | Worker Deployment | Dapr Subscriptions | HPA | PDB |
|---------|-----------|------------------|-------------------|-----|-----|
| Auth | ✅ (via kustomize component) | No separate worker — session cleanup runs in main process | None (producer only) | In production overlay | ✅ |
| User | ✅ (base/deployment.yaml) | ❌ No worker-deployment.yaml — where does outbox worker run? | None (producer only) | Unknown | ✅ |
| Customer | ✅ (base/deployment.yaml) | ✅ base/worker-deployment.yaml | ✅ auth.login, auth.password_changed, orders.order.status_changed | Unknown | ✅ |

> [!IMPORTANT]
> **User service GitOps gap**: `gitops/apps/user/base/` has no `worker-deployment.yaml`. The `internal/worker/outbox_worker.go` exists in code and is likely wired into a worker binary, but there is no K8s deployment for it. The outbox_worker may be running inside the main `user` binary (co-located) or may simply not be deployed. Verify `cmd/` directory structure.

---

*Generated by: Antigravity AI Review — Auth · User · Customer Flow*
*Reference: Shopify/Shopee/Lazada patterns applied: Outbox + idempotency + fail-closed security + token rotation + GDPR cleanup + segment-based targeting*
*Last updated: 2026-02-20*

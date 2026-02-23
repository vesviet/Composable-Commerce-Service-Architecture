# Customer & Identity Flow Review Checklist

**Services**: Auth · User · Customer  
**Reference**: [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) §1 · Shopify/Shopee/Lazada patterns  
**Date**: 2026-02-21  
**Status Legend**: ✅ OK · ⚠️ Risk · ❌ Issue · 🔴 P0 · 🟡 P1 · 🔵 P2

---

## 1. Data Consistency Between Services

### 1.1 Auth ↔ Customer

| Check | Status | Detail |
|---|---|---|
| Auth stores `user_id` (from User or Customer service) | ✅ | Sessions reference `user_id` + `user_type` (`customer`/`admin`) |
| Session revocation on Customer suspension/delete | ✅ | `CustomerUsecase` injects `authClient` and calls session revoke on delete/suspend |
| Auth does **not** own or replicate customer profile data | ✅ | Auth only manages tokens and sessions — no profile duplication |
| Auth `user_type` values match Customer service enum values | ⚠️ **P1** | Auth uses plain string `"customer"/"admin"`, Customer uses `int32` type enum — no schema contract enforced |
| Session `userType` validated on create | ✅ **Fixed** | `CreateSession` now rejects unknown user types (enum check: customer/admin/shipper) |

### 1.2 User ↔ Auth

| Check | Status | Detail |
|---|---|---|
| User deletion triggers session revocation in Auth | ✅ | User service calls Auth gRPC `RevokeUserSessions` on user delete |
| User status change triggers session revocation | ✅ | User service revokes sessions when account is suspended/deactivated |
| User and Auth share no shared DB | ✅ | Separate `user_db` and `auth_db` databases |
| User profile changes immediately visible to Auth | ✅ | Auth validates token against session only (stateless JWT); profile info not cached in Auth |

### 1.3 Customer ↔ User (Admin Users)

| Check | Status | Detail |
|---|---|---|
| Separate identity tables — no shared user table | ✅ | `auth_db` handles sessions; `user_db` handles admin/staff; `customer_db` handles end-customers |
| Data isolation at DB level | ✅ | Each service owns its own DB schema |
| No dual-write risk between customer and user records | ✅ | No cross-DB foreign keys |

### 1.4 Customer Internal Consistency

| Check | Status | Detail |
|---|---|---|
| `customer` + `customer_profile` + `customer_preferences` created atomically | ✅ | `CreateCustomer` wraps all three inserts in a single transaction |
| Outbox event written inside same transaction as customer create | ✅ | `outboxRepo.Create` called within `uc.transaction(...)` closure |
| `UpdateCustomer` — outbox event written in same transaction | ✅ | `outboxRepo.Create` inside the same `uc.transaction(...)` closure |
| Status machine enforced — status changes only via explicit endpoints | ✅ | Direct status via `UpdateCustomer` is **blocked** with a warning log; must use `Activate/Deactivate/Suspend` |
| Phone stored in `customer_profile`, not `customer` table | ⚠️ **P1** | `GetCustomerByPhone` looks up profile then customer — 2-hop query; no DB-level phone uniqueness constraint visible |
| Soft-delete cascades to profile + preferences | ✅ | `DeleteCustomer` calls `profileRepo.SoftDelete` and `preferencesRepo.SoftDelete` inside a transaction |

---

## 2. Data Mismatch Risks

| Risk | Severity | Detail |
|---|---|---|
| `customer.verified` event payload uses wrong structure | 🟡 **P1** | `PublishCustomerVerified` calls `helper.PublishUpdated` with `changes={"verify_type": "..."}` instead of the `CustomerVerifiedEvent` struct defined in `event_types.go` — consumers expecting `verifyType` at root level will fail |
| User service uses **custom HTTP DaprEventPublisher** (not common gRPC lib) | 🟡 **P1** | `user/internal/biz/events/event_publisher.go` implements its own HTTP-based retry + Dapr publish. Auth and Customer use `common/events.DaprEventPublisher` (gRPC). If pubsub name (`pubsub` vs `pubsub-redis`) differs, events are routed to different topics |
| User overlay sets `USER_EVENTS_PUBSUB_NAME: "pubsub"` | 🟡 **P1** | All other services use `pubsub-redis`. User publishes to a different pubsub component — any consumer subscribing on `pubsub-redis` for `user.created` will never receive it |
| `customer_type` inconsistency in outbox event payload | 🔵 **P2** | `customer.created` outbox event stores raw `customerTypeEnum` as int32; `customer.updated` changes map uses `req.Status` string. Consumers see mixed types for the same entity field |
| `autoAssignDefaultSegments` runs **outside** the main transaction | ⚠️ **P1** | Segment assignment happens after `uc.transaction(...)` commits — if it fails, customer exists but has no segment. No compensating action or retry. |

---

## 3. Outbox Pattern & Saga / Retry / Rollback

### 3.1 Customer Service — Outbox ✅ Implemented

| Operation | Outbox | Notes |
|---|---|---|
| `customer.created` | ✅ Written inside DB transaction | Outbox relay publishes to `pubsub-redis` |
| `customer.updated` | ✅ Written inside DB transaction | Changes map written to outbox |
| `customer.deleted` | ⚠️ **P1** | **No outbox event on soft-delete** — `DeleteCustomer` revokes auth sessions but does NOT write a `customer.deleted` outbox event; consumers (loyalty, notifications) will miss deletions |
| `customer.status.changed` | ⚠️ **P1** | `ActivateCustomer/SuspendCustomer` publish via `events.PublishCustomerStatusChanged` **directly** (not via outbox) — if publishing fails after DB commit, status change is lost |
| Address CRUD events | ⚠️ **P2** | `AddressCreated/Updated/Deleted` events exist in `event_types.go` but direct publish (not outbox) — at-most-once delivery |

### 3.2 Auth Service — No Outbox (Intentional)

| Event | Published | Notes |
|---|---|---|
| Session created | ✅ Direct publish via Dapr (best-effort) | `session.created` — low business impact if lost |
| Session revoked | ✅ Direct publish via Dapr (best-effort) | `session.revoked` — OK for analytics; security handled synchronously by removing from DB/cache |
| User authenticated | ✅ Direct publish | Login event — analytics/audit only; no downstream saga dependency |
| Account locked | ✅ Direct publish | OK for notifications; lock is DB-persisted, not event-dependent |
| **Verdict** | ✅ **Correct** | Auth events are fire-and-forget. No saga dependency on auth events — correct decision not to use outbox |

### 3.3 User Service — No Outbox (Partial Risk)

| Event | Published | Notes |
|---|---|---|
| `user.created` | ⚠️ Direct HTTP publish (no outbox) | If Dapr sidecar unavailable, event is gracefully dropped (`return nil`) — downstream services never know |
| `user.updated` | ⚠️ Direct HTTP publish (no outbox) | Same risk |
| `user.deleted` | ⚠️ Direct HTTP publish (no outbox) | Could leave orphaned data in downstream services |
| **Verdict** | 🟡 **P1** | User service calls should use Outbox pattern for `user.created/deleted` since other services may depend on these for data propagation |

---

## 4. Event Publishing — Does the Service Actually Need to Publish?

### Auth Service
| Event | Need? | Consumers | Verdict |
|---|---|---|---|
| `session.created` | ✅ Yes | Analytics, audit | ✅ Keep |
| `session.revoked` | ✅ Yes | Analytics, notification (forced logout) | ✅ Keep |
| `user.authenticated` | ✅ Yes | Analytics, fraud detection | ✅ Keep |
| `account.locked` | ✅ Yes | Notification service | ✅ Keep |
| `permission.refresh.needed` | ⚠️ Maybe | Only if gateway caches permissions | ⚠️ Verify consumer exists |

### User Service
| Event | Need? | Consumers | Verdict |
|---|---|---|---|
| `user.created` | ✅ Yes | Notification (welcome email), analytics | ✅ Keep |
| `user.updated` | ✅ Yes | Analytics, search index | ✅ Keep |
| `user.deleted` | ✅ Yes | Any service with user reference | ✅ Keep |
| `user.status_changed` | ✅ Yes | Auth (session revoke), notification | ✅ Keep |

### Customer Service
| Event | Need? | Consumers | Verdict |
|---|---|---|---|
| `customer.created` | ✅ Yes | Loyalty (init account), notification (welcome), analytics | ✅ Keep — Outbox correct |
| `customer.updated` | ✅ Yes | Search (if customer search exists), analytics | ✅ Keep — Outbox correct |
| `customer.deleted` | ✅ Yes | Loyalty, notification, order history | ❌ **Missing outbox event** |
| `customer.verified` | ✅ Yes | Loyalty (unlock benefits), notification | ✅ Keep — fix payload structure |
| `customer.status.changed` | ✅ Yes | Loyalty, notification | ⚠️ Move to outbox |
| `customer.group.assigned` | ⚠️ Maybe | Pricing, promotion (group-based discounts) | ✅ Keep if Promotion uses it |
| `customer.segment.assigned` | ⚠️ Maybe | Analytics, campaign targeting | ✅ Keep for marketing use |
| `customer.address.created/updated` | ✅ Yes | Fulfillment (default address), checkout | ⚠️ Use outbox for critical ops |
| `preferences.updated` | ⚠️ Maybe | Notification (opt-out compliance) | ✅ Keep for PDPA compliance |

---

## 5. Event Subscription — Does the Service Actually Need to Subscribe?

### Auth Service
| Event Subscribed | Source | Need? | Verdict |
|---|---|---|---|
| None currently | — | Auth is event **publisher** only | ✅ Correct — no inbound consumers needed |

### User Service
| Event Subscribed | Source | Need? | Verdict |
|---|---|---|---|
| None currently | — | User is event publisher only | ✅ OK — but consider subscribing to `customer.deleted` to purge linked admin ops |

### Customer Service
| Event Subscribed | Source | Need? | Verdict |
|---|---|---|---|
| None currently found | — | Customer service appears event publisher only | ⚠️ **P2** Review: Should subscribe to `order.completed` to auto-update stats (currently uses polling via StatsWorker); subscribing would be more real-time |

---

## 6. Worker & Cron Job Review

### Auth — `SessionCleanupWorker`

| Check | Status | Detail |
|---|---|---|
| Runs on ticker interval (not cron) | ✅ | Default 1h, configurable via `AUTH_AUTH_SESSION_CLEANUP_INTERVAL` |
| Runs immediately on startup | ✅ | `cleanup(ctx)` called before ticker loop |
| Does **not** publish events | ✅ | Cleanup is internal DB operation only |
| Worker registered in wire/DI | ✅ | Verify in `cmd/auth/wire.go` |
| Separate worker binary | ❌ **NOT present** | Auth has no worker binary/deployment — `SessionCleanupWorker` must be wired into the main binary via goroutine or missing a dedicated worker deployment |
| Metrics emitted | ⚠️ **P2** | Uses log-based metrics (`METRIC auth_sessions_cleaned_total=N`) instead of Prometheus — not scraped by Prometheus. The Prometheus counter `sessionsCleanedTotal` is registered in `session.go` but the log-based approach in `session_cleanup.go` duplicates and diverges |

### Customer — Worker Deployment

| Check | Status | Detail |
|---|---|---|
| Separate `customer-worker` Deployment | ✅ | `gitops/apps/customer/base/worker-deployment.yaml` exists |
| Dapr sidecar enabled on worker | ✅ | `dapr.io/enabled: "true"`, `dapr.io/app-id: "customer-worker"` |
| Worker missing `secretRef` for DB/Redis credentials | ✅ **Fixed** | Added `secretRef: customer` to `worker-deployment.yaml` |
| Worker health probe uses `proc/1/status` check | ⚠️ **P2** | `exec: cat /proc/1/status grep State:[RS]` — this detects if the process is running but not if workers are actually processing. Not a functional health check |
| ENABLE_CRON and ENABLE_CONSUMER set | ✅ | Both env vars set to `"true"` in worker deployment |
| Worker runs correct binary | ✅ | `/app/bin/worker -conf /app/configs/config.yaml` |

### Customer — `CleanupWorker` (Cron)

| Check | Status | Detail |
|---|---|---|
| Schedule configurable | ✅ | Default `"0 0 3 * * *"` (daily 3AM), env var `CUSTOMER_CLEANUP_SCHEDULE` |
| Schedule in overlay ConfigMap | ✅ | `CUSTOMER_CUSTOMER_WORKERS_CLEANUP_SCHEDULE: "0 0 3 * * *"` in dev overlay |
| GDPR deletion processing | ✅ | `gdprUC.GetScheduledDeletions` → `ProcessAccountDeletion` per customer |
| Batch size limit on scheduled deletions | ✅ **Fixed** | `GetScheduledDeletions` capped at 200 per run to prevent OOM |
| Retry on partial failure | ⚠️ **P1** | Failed individual deletions are logged but no retry queue — they will be retried at next cron run (next day) if still in scheduled state |
| Audit log retention configurable | ✅ | `AUDIT_LOG_RETENTION_DAYS`, default 365 days |

### Customer — `SegmentEvaluatorWorker` (Cron)

| Check | Status | Detail |
|---|---|---|
| Schedule configurable | ✅ | Default `"0 0 2 * * *"` (daily 2AM), env var `CUSTOMER_SEGMENT_EVALUATOR_SCHEDULE` |
| Batch processing of customers | ✅ | 100 customers per batch with offset pagination |
| Idempotency for `AssignCustomerToSegment` | ✅ **Fixed** | Repo now uses `INSERT ... ON CONFLICT DO NOTHING`; worker uses `EvaluateCustomerSegments` with membership pre-check |
| `RemoveCustomerFromSegment` silently ignores "not a member" errors | ✅ | Logged at Debug level — acceptable |
| Total customer count race condition | ⚠️ **P2** | `total` is fetched at each batch iteration — if new customers register mid-evaluation, `total` can grow causing infinite processing in theory. Should snapshot total at start |
| No event published on segment change | ⚠️ **P2** | When worker assigns/removes customer from segment, no `customer.segment.assigned/removed` event is published — campaign systems won't know in real-time |
| Schedule overlap if long run | ⚠️ **P2** | Uses `cron.WithSeconds()` but no distributed lock or overlap detection — if evaluation takes > 22 hours (unlikely but possible for 1M customers), jobs will overlap |

### Customer — `StatsWorker` (Cron)

| Check | Status | Detail |
|---|---|---|
| Schedule configurable | ✅ | Default `"0 0 * * * *"` (hourly), env var `CUSTOMER_STATS_UPDATE_SCHEDULE` |
| Calls Order Service via gRPC | ✅ | `orderClient.GetCustomerOrderStats` with 10s timeout per customer |
| Polling vs event-driven | ⚠️ **P2** | Hourly polling of ALL customers via gRPC is inefficient at scale. Should subscribe to `order.completed` event and update stats incrementally |
| Error handling in batch | ✅ | Per-customer errors are logged as warnings; batch continues |
| Context cancellation check between batches | ✅ | `select ctx.Done()` between batches |
| Order service unavailability | ✅ **Fixed** | Circuit breaker added: after 5 consecutive gRPC failures the run aborts to protect Order Service |

---

## 7. GitOps Configuration Review

### Auth Service GitOps

| Check | Status | Detail |
|---|---|---|
| Ports correct (HTTP:8000, gRPC:9000) | ✅ | Overlay: `AUTH_SERVER_HTTP_ADDR: "0.0.0.0:8000"`, `AUTH_SERVER_GRPC_ADDR: "0.0.0.0:9000"` |
| DB credentials in ConfigMap (not Secret) | 🔴 **P0** | `AUTH_DATA_DATABASE_SOURCE` contains plaintext `postgres://postgres:microservices@...` in dev ConfigMap — violates secrets management policy |
| Auth base dir missing deployment.yaml | ⚠️ **P1** | `gitops/apps/auth/base/` has no `deployment.yaml` — only configmap, migration-job, etc. May be using kustomize patchStrategicMerge or auth has no dedicated base deployment |
| Rate limit config in overlay | ✅ | `AUTH_AUTH_RATE_LIMIT_LOGIN_ATTEMPTS: "5"`, `AUTH_AUTH_RATE_LIMIT_LOCKOUT_DURATION: "15m"` |
| Device binding disabled in dev | ✅ | `AUTH_SECURITY_DEVICE_BINDING_ENABLED: "false"` — acceptable for dev |
| Jaeger endpoint uses `localhost` | 🔴 **P0** | `AUTH_TRACE_ENDPOINT: "http://localhost:14268/api/traces"` — localhost does not work in K8s pods. Should be cluster-internal Jaeger URL |
| CORS wildcard origins in dev | ✅ | `AUTH_SECURITY_CORS_ALLOWED_ORIGINS: "[*]"` — OK for dev, production overlay must restrict |

### User Service GitOps

| Check | Status | Detail |
|---|---|---|
| Ports correct (HTTP:8001, gRPC:9001) | ✅ | `USER_SERVER_HTTP_ADDR: "0.0.0.0:8001"`, `USER_SERVER_GRPC_ADDR: "0.0.0.0:9001"` |
| DB credentials via Secret (user has secret.yaml) | ✅ | `gitops/apps/user/overlays/dev/secret.yaml` exists |
| User overlay missing DATABASE_SOURCE in ConfigMap | ✅ | DB source in secret, not ConfigMap |
| User pubsub name `"pubsub"` (not `"pubsub-redis"`) | 🟡 **P1** | `USER_EVENTS_PUBSUB_NAME: "pubsub"` — inconsistent with `pubsub-redis` used by all other services |
| Jaeger endpoint uses cluster-internal URL | ✅ | `USER_TRACE_ENDPOINT: "http://jaeger-collector.observability.svc.cluster.local:14268/api/traces"` |
| Auth service gRPC endpoint configured | ✅ | `USER_AUTH_SERVICE_ADDR: "auth-service.auth-dev.svc.cluster.local:9000"` |

### Customer Service GitOps

| Check | Status | Detail |
|---|---|---|
| Ports correct (HTTP:8003, gRPC:9003) | ✅ | Deployment and overlay match |
| DB credentials in overlay ConfigMap (not Secret) | 🔴 **P0** | `CUSTOMER_DATA_DATABASE_SOURCE` contains plaintext credentials — must be in Secret |
| Order service gRPC endpoint configured | ✅ | `CUSTOMER_EXTERNAL_SERVICES_ORDER_SERVICE_GRPC_ENDPOINT: "order.order-dev.svc.cluster.local:81"` |
| Order service HTTP uses wrong port (`:80`) | ⚠️ **P1** | `CUSTOMER_EXTERNAL_SERVICES_ORDER_SERVICE_ENDPOINT: "http://order.order-dev.svc.cluster.local:80"` but order HTTP port is 8004 |
| Customer worker missing secretRef | 🔴 **P0** | `worker-deployment.yaml` only has `configMapRef: overlays-config` — no `secretRef: customer`. Worker cannot connect to DB |
| Customer worker Dapr app-protocol set to gRPC | ✅ | `dapr.io/app-protocol: "grpc"` |
| HTTP timeout too low (1s) | ⚠️ **P2** | `CUSTOMER_SERVER_HTTP_TIMEOUT: "1s"` — profile creation flows that involve segment assignment may exceed this under load |
| Default segments configured | ✅ | `CUSTOMER_CUSTOMER_DEFAULT_SEGMENTS: "[all-customers, new-customers]"` |

---

## 8. Edge Cases & Logic Risks

### 8.1 Authentication Flows

| Edge Case | Status | Risk |
|---|---|---|
| Concurrent login from 2 clients — session limit race | ✅ Handled | `CreateSessionWithLimit` is atomic via repo-level transaction |
| Expired token + valid session: token accepted | ✅ Handled | JWT expiry checked independently of session |
| Revoked session + valid JWT: token accepted until JWT expiry | ⚠️ **P1** | Revoked session invalidates session check, but if `IsSessionActive` fails open on DB error, revoked sessions can still authenticate |
| Token rotation on refresh: old refresh token reuse | ⚠️ **P1** | Refresh token rotation not confirmed — if old refresh token accepted after rotation, token replay attack possible |
| Account locked mid-session: existing tokens still valid | ⚠️ **P1** | If account is locked, session must be revoked; verify `AccountLockedEvent` triggers session revocation |
| `user_type="customer"` vs `user_type="Customer"` (case mismatch) | ✅ **Fixed** | `CreateSession` now validates `userType` enum (customer/admin/shipper); invalid values rejected immediately |

### 8.2 Customer Registration

| Edge Case | Status | Risk |
|---|---|---|
| Duplicate email registration — TOCTOU race | ⚠️ **P1** | `FindByEmail` → `Create` has a race window; concurrent registrations with same email can both pass the check. Needs DB-level unique constraint on `email` |
| Customer created but outbox relay down | ✅ | Outbox row persists; relay picks up on recovery |
| Customer created but segment assignment fails | ✅ **Fixed** | `autoAssignDefaultSegments` now writes `customer.segments.pending` outbox event on failure; segment evaluator retries on next run |
| Email verification OTP expiry — no cleanup | ✅ | `CleanupWorker.removeExpiredTokens` handles this daily |
| Verification token sent but customer deleted before use | ⚠️ **P2** | Token cleanup job deletes expired tokens, but a valid (unexpired) token for a deleted customer is not cleaned up; could be misused if email is re-registered |

### 8.3 Account Deletion & GDPR

| Edge Case | Status | Risk |
|---|---|---|
| Deletion scheduled but customer reopens account before processing | ⚠️ **P1** | No mechanism to cancel a scheduled deletion — if customer is marked for deletion but re-activates via support, the cleanup worker will still anonymize them |
| Batch deletion fails mid-batch | ✅ Partially | Failed individual records logged; retried next cron run |
| Auth sessions not revoked on GDPR deletion | ✅ **Fixed** | `ProcessAccountDeletion` calls `authClient.RevokeUserSessions` synchronously |
| `customer.deleted` event not published by cleanup worker | ✅ **Fixed** | `ProcessAccountDeletion` writes `customer.deleted` outbox event after anonymization |

### 8.4 Segment Evaluation

| Edge Case | Status | Risk |
|---|---|---|
| Segment rules evaluate stale customer data | ⚠️ **P2** | Evaluation references live DB, but newly updated fields (phone, status) may not be reflected if customer is cached |
| Customer added to segment twice | ✅ **Fixed** | `AssignCustomerToSegment` uses `ON CONFLICT DO NOTHING`; worker uses `EvaluateCustomerSegments` with membership pre-check |
| Segment rules deleted mid-evaluation | ⚠️ **P2** | If segment is deleted while evaluator iterates, `EvaluateSegment` may get nil rules — not explicitly handled |
| Large customer base causes evaluation timeout | ⚠️ **P2** | 1M customers × 100-batch → 10,000 DB calls. No timeout on individual batch; could block worker goroutine for hours |

### 8.5 Stats Worker

| Edge Case | Status | Risk |
|---|---|---|
| Order Service unavailable — stats become stale | ⚠️ **P1** | All customer stats freeze if Order Service is down for 1h+ |
| `OverwriteCustomerStats` on concurrent update | ✅ | Stats overwrite is last-write-wins — no race issue since worker is single-goroutine per customer |
| Stats worker and application layer both write stats | ⚠️ **P2** | If application layer also writes stats (e.g., on order completion), StatsWorker's hourly overwrite may overwrite more recent data |

---

## 9. Summary: Action Items

### 🔴 P0 — Must Fix Before Production

- [x] **AUTH**: Move `AUTH_DATA_DATABASE_SOURCE` from ConfigMap to Secret ✅ Already in `secret.yaml`  
- [x] **AUTH**: Fix Jaeger endpoint from `localhost:14268` to cluster-internal URL ✅ Already cluster-internal  
- [x] **CUSTOMER**: Move `CUSTOMER_DATA_DATABASE_SOURCE` from ConfigMap to Secret ✅ Already in `secret.yaml`  
- [x] **CUSTOMER Worker**: Add `secretRef: customer` to `worker-deployment.yaml` ✅ Fixed  

### 🟡 P1 — Fix Before Release

- [x] ~~**USER**: Change `USER_EVENTS_PUBSUB_NAME` from `"pubsub"` to `"pubsub-redis"`~~ ✅ Already `pubsub-redis`  
- [x] **USER**: Migrate custom HTTP `DaprEventPublisher` to use `common/events.DaprEventPublisher` (gRPC) ✅ Already migrated — uses `commonEvents.NewDaprEventPublisher` (gRPC)  
- [x] **CUSTOMER**: Add `customer.deleted` outbox event in `DeleteCustomer` usecase ✅ Already present  
- [x] **CUSTOMER**: Move `customer.status.changed` event to outbox pattern ✅ `writeStatusChangedOutbox` already used  
- [x] **CUSTOMER**: Fix `PublishCustomerVerified` to publish proper `CustomerVerifiedEvent` struct ✅ Fixed — direct publisher with `CustomerVerifiedEvent`  
- [x] **CUSTOMER**: Fix `autoAssignDefaultSegments` — write `customer.segments.pending` outbox on failure for retry ✅ Fixed  
- [x] **CUSTOMER Worker**: Add batch size limit to `GetScheduledDeletions` ✅ Fixed (200 batch cap)  
- [x] **CUSTOMER Worker**: GDPR cleanup publishes `customer.deleted` outbox event ✅ Fixed in `ProcessAccountDeletion`  
- [x] **CUSTOMER**: `ProcessAccountDeletion` calls `authClient.RevokeUserSessions` ✅ Fixed  
- [x] **CUSTOMER**: Add DB-level unique constraint on `email` ✅ Already `UNIQUE NOT NULL` in migration 001  
- [x] **SEGMENT Worker**: Membership pre-check + `ON CONFLICT DO NOTHING` in repo ✅ Fixed  
- [x] **STATS Worker**: Circuit breaker after 5 consecutive Order Service failures ✅ Fixed  
- [x] **AUTH**: Account lock → synchronous session revocation ✅ Fixed — `UpdateUser` now revokes sessions on Suspended/Deleted status change  
- [x] **AUTH**: Refresh token rotation rejects replayed tokens ✅ Verified — `RevokeTokenWithMetadata` blacklists token in Redis + Postgres; `IsTokenRevoked` is fail-closed  
- [x] **AUTH**: Add `userType` enum validation in `CreateSession` ✅ Fixed  
- [x] **CUSTOMER Worker**: Add `secretRef: customer` to `worker-deployment.yaml` ✅ Fixed  
- [x] **CUSTOMER**: Order Service HTTP endpoint port ✅ Already `:8004`  

### 🔵 P2 — Nice to Have / Cleanup

- [ ] **AUTH**: Add `auth.base/deployment.yaml` if missing, or document why auth uses patchStrategicMerge only  
- [ ] **CUSTOMER Worker**: Replace `proc/1/status` health probe with proper HTTP health endpoint  
- [ ] **AUTH Session Cleanup**: Reconcile Prometheus counter in `session.go` vs manual log-metric in `session_cleanup.go`  
- [ ] **SEGMENT Worker**: Add distributed lock to prevent cron overlap  
- [ ] **SEGMENT Worker**: Snapshot `total` at start of evaluation to prevent pagination drift  
- [ ] **SEGMENT Worker**: Publish `customer.segment.assigned/removed` events when membership changes  
- [ ] **STATS Worker**: Consider replacing hourly polling with event-driven stats update on `order.completed` subscription  
- [ ] **CUSTOMER**: OTP token for deleted customer cleanup — add check in `removeExpiredTokens` for soft-deleted customers  
- [ ] **AUTH**: Add `permission.refresh.needed` consumer inventory — verify which service actually subscribes  
- [ ] **SESSION**: Add `userType` case normalization (lowercase before store) to prevent `"Customer"` vs `"customer"` divergence  

---

## 10. Event Map Summary

```
[Auth Service]
  Publishes:  session.created, session.revoked, user.authenticated,
              account.locked, permission.refresh.needed
  Subscribes: (none)
  Pattern:    Direct publish (fire-and-forget, best-effort)
  ✅ Correct for auth use case

[User Service]
  Publishes:  user.created, user.updated, user.deleted, user.status_changed
  Subscribes: (none)
  Pattern:    Direct HTTP Dapr publish (no outbox) ⚠️ Risk on user.deleted
  pubsub:     "pubsub" ← WRONG, should be "pubsub-redis"

[Customer Service]
  Publishes:  customer.created ✅ Outbox
              customer.updated ✅ Outbox
              customer.deleted ❌ MISSING outbox event
              customer.verified ⚠️ Wrong payload structure
              customer.status.changed ⚠️ Direct publish (not outbox)
              customer.address.* ⚠️ Direct publish
              customer.segment.assigned/removed ⚠️ Not published by cron worker
  Subscribes: (none — stats via polling, not events)
  Pattern:    Outbox for core entities; direct publish for secondary events
```

---

*Generated during Customer & Identity Flow review — 2026-02-21*  
*Cross-reference: [lastphase/](../lastphase/) for P0/P1/P2 fix tracking*

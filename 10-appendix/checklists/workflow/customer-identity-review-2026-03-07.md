# Customer & Identity Flow — Fresh Audit 2026-03-07

**Services**: Auth · User · Customer · Loyalty-Rewards  
**Reference**: [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) §1 · Shopify/Shopee/Lazada patterns  
**Previous Review**: [customer-identity-review.md](customer-identity-review.md) (2026-02-24)  
**Status Legend**: ✅ OK · ⚠️ Risk · ❌ Issue · 🔴 P0 · 🟡 P1 · 🔵 P2

---

## 🚩 PENDING ISSUES (Unfixed from Previous + Ongoing)

| # | Svc | Severity | Issue | File(s) |
|---|-----|----------|-------|---------|
| 1 | AUTH | 🟡 P1 | `UserRegisteredEvent` struct defined but **never published** — no `PublishEvent` call exists for `user.registered`/`auth.user_registered` | `biz/events.go:55` |
| 2 | CUSTOMER | 🟡 P1 | Outbox infra exists (`data/postgres/outbox_event.go`, `repository/outbox/`) but **no outbox worker** — events written to outbox table are never flushed/published | `data/postgres/outbox_event.go` |
| 3 | LOYALTY | 🔴 P0 | `configmap.yaml` hardcodes `database-url` and `redis-url` with plaintext credentials | `gitops/apps/loyalty-rewards/base/configmap.yaml:12-13` |
| 4 | LOYALTY | 🟡 P1 | `OutboxPublisherAdapter.PublishEvent` is a **no-op stub** (`return nil`) — outbox events are never actually published to Dapr after relay reads them | `worker/workers.go:41-43` |
| 5 | LOYALTY | 🟡 P1 | `orders.return.completed` subscription code exists in consumer but **missing from GitOps** `dapr-subscription.yaml` — returns won't trigger point clawback in K8s | `worker/event/consumer.go:64-73` vs `gitops/.../dapr-subscription.yaml` |
| 6 | AUTH | 🟡 P1 | Worker patch is placeholder-only — no Dapr annotations, no initContainers, no env vars (unlike customer worker which has full config) | `gitops/apps/auth/base/patch-worker.yaml` |
| 7 | LOYALTY | 🟡 P1 | Worker patch is placeholder-only — no Dapr annotations for event consumer worker to receive events | `gitops/apps/loyalty-rewards/base/patch-worker.yaml` |
| 8 | USER | 🟡 P1 | Worker patch is placeholder-only — no Dapr annotations; outbox worker cannot relay to Dapr | `gitops/apps/user/base/patch-worker.yaml` |
| 9 | CUSTOMER | ⚠️ P1 | `auth_consumer.go` `isPermanentError` is defined on **pointer receiver** `*AuthConsumer` but struct methods use **value receiver** `AuthConsumer` — inconsistency | `data/eventbus/auth_consumer.go:322` |
| 10 | LOYALTY | ⚠️ P2 | Points expiry cron runs every 24h but has **no distributed lock** — multiple replicas could expire same points concurrently | `worker/workers.go:116-119` vs `jobs/` |
| 11 | CUSTOMER | ⚠️ P2 | Event handler in `service/event_handler.go` duplicates logic from `data/eventbus/{auth,order}_consumer.go` — dual processing paths exist | `service/event_handler.go` |

---

## 🆕 NEWLY DISCOVERED ISSUES

### N-1. Auth `UserRegisteredEvent` — Dead Code [🟡 P1]

**Problem**: `auth/internal/biz/events.go:55` defines `UserRegisteredEvent` struct, but **no code in the entire auth service calls `PublishEvent` with "user.registered" or "auth.user_registered"**. The `ecommerce-platform-flows.md` reference doc and KI both state "Auth publishes `user.registered` → Customer consumes it to create profile" — but this event flow is **not implemented**.

**Impact**: Registration flow relies on synchronous API calls from frontend to both Auth and Customer services separately, rather than event-driven choreography. If frontend only calls Auth, no customer profile is created.

**Fix**: Either:
1. Wire `UserRegisteredEvent` publish into auth registration flow (if auth owns registration)
2. Remove dead `UserRegisteredEvent` struct and document that registration is frontend-orchestrated (current reality)
3. Move to Customer-first registration where Customer creates the profile and publishes `customer.created`

---

### N-2. Customer Outbox — Infra Without Worker [🟡 P1]

**Problem**: Customer has full outbox infrastructure:
- `data/postgres/outbox_event.go` — GORM repository
- `repository/outbox/outbox_event.go` — interface
- Biz layer writes outbox events in transactions

But there is **no outbox worker** (unlike loyalty-rewards which has `outbox.Worker` in `workers.go:31-37`). The worker directory only contains `cron/` subdirectory with cleanup + segment + stats workers.

**Impact**: `customer.created`, `customer.updated`, `customer.deleted` outbox events written to DB are **never published to Dapr PubSub**. Downstream consumers (loyalty-rewards subscribes to `customer.created`, `customer.deleted`) never receive events ← this means loyalty accounts are never auto-created on registration.

**Fix**: Add `outbox.Worker` to customer's worker binary, following loyalty-rewards' pattern.

---

### N-3. Loyalty OutboxPublisherAdapter — No-Op [🟡 P1]

**Problem**: `loyalty-rewards/internal/worker/workers.go:39-43`:
```go
type outboxPublisherAdapter struct{ pub bizEvents.EventPublisher }
func (a *outboxPublisherAdapter) PublishEvent(_ context.Context, _ string, _ interface{}) error {
    return nil  // ← no-op!
}
```
The outbox worker relays events through this adapter, which drops them silently.

**Impact**: Loyalty events (`points.earned`, `tier.upgraded`, `points.redeemed`, `reward.redeemed`, `referral.completed`) are written to outbox table but never actually published to Dapr when the outbox worker picks them up.

**Fix**: Wire the `NewDaprPublisher` into the adapter so events are actually published.

---

### N-4. Loyalty GitOps — Missing `orders.return.completed` Subscription [🟡 P1]

**Problem**: Consumer code exists (`consumer.go:64-73`):
```go
func (c *LoyaltyConsumer) ConsumeReturnCompleted(ctx context.Context) error {
    return c.client.AddConsumerWithMetadata("orders.return.completed", "pubsub-redis", ...)
}
```
And the worker registers it (`workers.go:105-108`):
```go
workers = append(workers, &returnCompletedConsumerWorker{...})
```
But `gitops/apps/loyalty-rewards/base/dapr-subscription.yaml` only has 3 subscriptions: `customer.created`, `orders.order.status_changed`, `customer.deleted` — missing `orders.return.completed`.

**Impact**: In K8s, Dapr's declarative subscriptions override programmatic ones. Return completions won't trigger point clawback.

**Fix**: Add `orders.return.completed` + its DLQ to `dapr-subscription.yaml`.

---

### N-5. Loyalty ConfigMap — Hardcoded Credentials [🔴 P0]

**Problem**: `gitops/apps/loyalty-rewards/base/configmap.yaml:12-13`:
```yaml
database-url: "postgres://postgres:microservices@postgresql:5432/loyalty_rewards_db?sslmode=disable"
redis-url: "redis://redis:6379/0"
```
Plaintext DB password in ConfigMap (not Secret). All other services (auth, customer, user) have credentials in `Secret` only.

**Fix**: Move to `Secret` same as other services.

---

### N-6. Worker GitOps Patches — Auth/User/Loyalty Missing Dapr Annotations [🟡 P1]

**Problem**: Customer's `patch-worker.yaml` correctly has:
- `dapr.io/app-port: "5005"`, `dapr.io/app-protocol: "grpc"` 
- `initContainers` for Consul/Redis/Postgres wait
- `WORKER_MODE`, `ENABLE_CRON`, `ENABLE_CONSUMER` env vars

But auth, user, and loyalty-rewards `patch-worker.yaml` are bare stubs:
```yaml
containers:
- name: placeholder-worker
  envFrom:
  - configMapRef: ...
  - secretRef: ...
  resources: ...
```
No Dapr annotations, no port, no init containers, no env vars.

**Impact**: Workers won't receive Dapr events in K8s. Loyalty-rewards consumer workers can't function without Dapr sidecar annotation.

---

### N-7. Customer Service — Actually Subscribes to Events (Correction to Previous Review) [INFO]

Previous review Section 5 stated "Customer Service: None currently found — event publisher only". This is **incorrect**.

Customer worker subscribes to:
- `auth.login` → updates `last_login_at` (via `auth_consumer.go`)
- `auth.password_changed` → audit log (via `auth_consumer.go`)
- `orders.order.status_changed` → update customer stats: order count, total spent (via `order_consumer.go`)

The consumers run in the worker binary with retry + DLQ + idempotency (processed_event table).

**However**, these consumers also lack Dapr subscription entries in GitOps — they rely on programmatic subscription which may conflict with Dapr's declarative model.

---

### N-8. Customer & Loyalty — Consumer Event Schema Mismatch Risk [⚠️ P2]

Customer's `OrderStatusChangedEvent` uses `json:"event_type"` (snake_case) while the `AuthLoginEvent` uses `json:"eventType"` (camelCase). The auth service publishes with camelCase.

This means if auth team changes their event format or if a schema registry is introduced, the inconsistency will amplify.

---

## ✅ RESOLVED / FIXED (from previous review)

All items marked `[x]` in previous review Sections 9 and 12 remain valid:

- **AUTH**: Credentials moved to Secret ✅
- **USER**: `USER_EVENTS_PUBSUB_NAME` = `pubsub-redis` ✅
- **USER**: Uses common gRPC publisher ✅
- **CUSTOMER**: `customer.deleted` outbox event added ✅
- **CUSTOMER**: `customer.status.changed` via outbox ✅
- **CUSTOMER**: `autoAssignDefaultSegments` writes pending outbox on failure ✅
- **CUSTOMER**: DB unique constraint on email ✅
- **CUSTOMER Worker**: `secretRef` added ✅
- **SEGMENT Worker**: Distributed lock + snapshot pagination ✅
- **STATS Worker**: Circuit breaker after 5 failures ✅
- **LOYALTY**: `customer.deleted` consumer added ✅
- **LOYALTY**: Stale `dapr/subscription.yaml` removed ✅
- **AUTH**: Session `userType` enum validation ✅
- **AUTH**: Token rotation fail-closed ✅
- **GDPR**: `CancelAccountDeletion` implemented ✅
- **AUTH Worker**: K8s worker deployment created ✅

---

## Updated Event Map (2026-03-07)

```
[Auth Service]
  Publishes:  auth.login (on successful login)
              auth.session.created, auth.session.revoked
              auth.user.sessions.revoked
              auth.token.generated, auth.token.revoked
  NOT Published: auth.user_registered (DEAD CODE — struct exists, never called)
  Subscribes: (none)
  Outbox:     None (fire-and-forget — correct for auth)

[User Service]
  Publishes:  user.created, user.updated, user.deleted, user.status_changed
  Subscribes: (none)
  Outbox:     Has outbox_worker.go ✅ — relays via Dapr gRPC

[Customer Service]
  Publishes:  customer.created, customer.updated, customer.deleted (via Outbox)
              customer.verified, customer.status.changed (via Outbox)
              customer.address.* (direct publish)
              customer.segment.assigned/removed, customer.group.* (direct)
  Subscribes: auth.login, auth.password_changed (via auth_consumer.go worker)
              orders.order.status_changed (via order_consumer.go worker)
  Outbox:     ❌ Infra exists but NO OUTBOX WORKER — events stuck in DB

[Loyalty-Rewards Service]
  Publishes:  loyalty.account.created/updated (via outbox)
              loyalty.points.earned/redeemed/deducted (via outbox)
              loyalty.tier.upgraded, loyalty.reward.redeemed (via outbox)
              loyalty.referral.completed (via outbox)
  Subscribes: customer.created (welcome bonus)
              customer.deleted (GDPR account deactivation)
              orders.order.status_changed (points earn/reverse)
              orders.return.completed (points clawback)
              orders.return.completed.dlq (DLQ drain)
  Outbox:     ❌ Worker exists but PublishEvent is NO-OP stub
  Cron:       Points expiration (every 24h, no distributed lock)
```

---

## Worker/Cron Summary

| Service | Worker Binary | Cron Jobs | Event Consumers | Outbox Worker |
|---------|--------------|-----------|-----------------|---------------|
| Auth | ✅ `session_cleanup.go` | Session cleanup (1h ticker) | None | N/A |
| User | ✅ `outbox_worker.go` | None | None | ✅ |
| Customer | ✅ Worker deployment | Cleanup (3AM), Segment eval (2AM), Stats sync (hourly) | `auth.login`, `auth.password_changed`, `orders.order.status_changed` | ❌ **Missing** |
| Loyalty | ✅ Worker deployment | Points expiration (24h) | `customer.created`, `customer.deleted`, `orders.order.status_changed`, `orders.return.completed` | ❌ **No-op stub** |

---

## GitOps Configuration Gaps

| Service | ConfigMap | Secret | Worker Dapr | Dapr Subscriptions | Issue |
|---------|-----------|--------|-------------|-------------------|-------|
| Auth | ✅ Clean | ✅ | ❌ Placeholder | N/A | Worker patch needs Dapr config |
| User | ✅ Clean | ✅ | ❌ Placeholder | N/A | Worker patch needs Dapr config |
| Customer | ✅ Clean | ✅ | ✅ Full config | N/A (programmatic) | Missing declarative Dapr sub YAML |
| Loyalty | ❌ **Hardcoded creds** | N/A | ❌ Placeholder | ✅ 3/4 topics | Missing `orders.return.completed` |

---

## Priority Action Items

### 🔴 P0 — Must Fix Immediately

| # | Service | Action |
|---|---------|--------|
| 1 | LOYALTY | Move `database-url` and `redis-url` from `configmap.yaml` to a proper `secret.yaml` |

### 🟡 P1 — Fix Before Release  

| # | Service | Action |
|---|---------|--------|
| 2 | CUSTOMER | Add outbox worker to flush `customer.created/updated/deleted` events to Dapr |
| 3 | LOYALTY | Fix `OutboxPublisherAdapter.PublishEvent` — wire actual `DaprEventPublisher` so outbox relay publishes events |
| 4 | LOYALTY | Add `orders.return.completed` + DLQ to `gitops/apps/loyalty-rewards/base/dapr-subscription.yaml` |
| 5 | AUTH | Either implement `UserRegisteredEvent` publish or remove dead struct + document frontend-orchestrated registration |
| 6 | AUTH/USER/LOYALTY | Update worker `patch-worker.yaml` with Dapr annotations, port, env vars (follow customer's pattern) |
| 7 | CUSTOMER | Add declarative Dapr subscription YAML to gitops for `auth.login`, `auth.password_changed`, `orders.order.status_changed` |

### 🔵 P2 — Nice to Have

| # | Service | Action |
|---|---------|--------|
| 8 | LOYALTY | Add distributed lock (Redis SETNX) for points expiration cron |
| 9 | CUSTOMER | Consolidate `service/event_handler.go` duplicate with `data/eventbus/*_consumer.go` — single processing path |
| 10 | ALL | Standardize event JSON field naming (camelCase vs snake_case) across services |

---

*Generated: 2026-03-07 — Fresh codebase audit against ecommerce-platform-flows.md §1*  
*Cross-reference: [customer-identity-review.md](customer-identity-review.md) for historical context*

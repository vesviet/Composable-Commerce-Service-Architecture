# Cross-Cutting Concerns — Business Logic Review Checklist

**Date**: 2026-02-21 | **Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `common/` library + cross-service patterns — Idempotency, Outbox, Auth/RBAC, Rate Limit, CORS, PII, Observability, Circuit Breaker
**Reference**: `docs/10-appendix/ecommerce-platform-flows.md` §15 (Cross-Cutting Concerns)

---

## 📊 Summary

| Category | Status |
|----------|--------|
| 🔴 P0 — Critical (security / data corruption) | **3 fixed** ✅ |
| 🟡 P1 — High (reliability / consistency) | **2 fixed** ✅ · 3 open |
| 🔵 P2 — Medium (observability / edge case) | **2 fixed** ✅ · 3 open |
| ✅ Verified Working Well | 18 areas |

---

## ✅ Verified Fixed & Working

| Area | File | Notes |
|------|------|-------|
| JWT signature algorithm enforcement (HMAC only) | `common/middleware/auth.go:188` | `if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok` prevents `alg:none` attack |
| JWT claims type-safe extraction | `common/middleware/auth.go:80-88` | Type assertion `.(string)` before setting context values |
| OptionalAuth: invalid token → continue (not reject) | `auth.go:164-179` | Correct behaviour for guest browsing |
| Rate limit Lua script atomicity | `ratelimit.go:149-155` | INCR + EXPIRE in a single Lua eval — no TOCTOU |
| Rate limit X-RateLimit-* response headers | `ratelimit.go:102-106` | Limit, Remaining, Reset sent to client |
| Rate limit FailClosed option | `ratelimit.go:94-96` | When Redis down + FailClosed=true → 503 SERVICE_DEGRADED |
| Rate limit DDoS alerting | `ratelimit.go:84-91` | ERROR log with Redis endpoint when rate limiter DOWN |
| Outbox worker graceful stop via StopChan | `common/outbox/worker.go:85-86` | `<-w.StopChan()` unblocks on stop |
| Outbox atomic save inside TX | `common/outbox/gorm_repository.go` | `outboxRepo.Save(txCtx, ...)` called inside same DB transaction |
| Common IdempotencyChecker: ProcessWithIdempotency | `common/idempotency/event_processing.go:200` | Wraps check + mark in helper; cleanup via CleanupOldLogs |
| Idempotency: ON CONFLICT DO UPDATE | `event_processing.go:70-74` | Upsert prevents duplicate rows on concurrent inserts |
| PII masker: email, phone, credit card, address | `common/security/pii/masker.go` | All 4 types masked; MaskLogMessage scans logs automatically |
| PII masker: MaskOrderData field-name-based detection | `masker.go:198-213` | ShouldMaskField: 15 sensitive field patterns |
| Recovery middleware: logs stack trace | `common/middleware/recovery.go:56-57` | Full stack captured and logged on panic |
| Recovery middleware: no stack in HTTP response | `recovery.go:62-66` | Only generic 500 returned to client (not internal details) |
| Health checkers: DB, Redis, gRPC | `common/observability/health/` | Factory pattern for health check composition |
| Metrics interface + noop implementation | `common/observability/metrics/` | No-op safe for services without Prometheus |
| Tracing interface | `common/observability/tracing/` | OTel abstraction layer |

---

## 🔴 Open P0 Issues (Critical — Security)

### XC-P0-001: CORS Default Allows `*` + `AllowCredentials: true` — Invalid Per CORS Spec

**File**: `common/middleware/cors.go:20-47`

**Problem**: `DefaultCORSConfig()` sets:
```go
AllowOrigins:     []string{"*"},
AllowCredentials: true,
```

According to the CORS specification, **it is invalid** to send `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true`. Browsers will **reject** the response entirely — any cross-origin fetch with `credentials: "include"` will fail with a CORS error.

Additionally, `DefaultCORSConfig()` is used as-is in places that call `CORS()`. If production services use the default, every authenticated cross-origin API call from the frontend will silently fail.

Also: `config.MaxAge` is cast incorrectly at line 88:
```go
c.Writer.Header().Set("Access-Control-Max-Age", string(rune(config.MaxAge)))
```
`string(rune(86400))` produces a Unicode character (U+15180 = CJK Unified Ideograph), not the string `"86400"`. The `Max-Age` header is always malformed.

**Resolution**:
- [x] Change `DefaultCORSConfig()` to use **explicit origin allowlist** (not `"*"`) when `AllowCredentials: true` — added `CORSWithCredentials(allowOrigins)` helper; default config sets `AllowCredentials: false` _(v1.14.0)_
- [x] Fix `MaxAge` serialization: `fmt.Sprintf("%d", config.MaxAge)` _(v1.14.0)_
- [ ] Add environment-specific CORS overlays (dev: localhost, prod: production domain)

---

### XC-P0-002: Common Outbox Worker Has No `FOR UPDATE SKIP LOCKED`

**File**: `common/outbox/worker.go:113`

**Problem**: `w.repo.FetchPending(ctx, w.batchSize)` in the shared outbox worker runs a plain `SELECT`. When services scale to >1 worker replica (e.g., catalog, search, order), multiple workers fetch and process the **same events**, publishing duplicate messages to Dapr pubsub.

Multiple downstream services (warehouse, notification) may process the same event twice → duplicate stock changes, duplicate emails.

This was also separately flagged in the warehouse outbox (WH-P0-003), but **the root cause is the shared common library**.

**Resolution**:
- [x] Implement `SELECT ... WHERE status='pending' FOR UPDATE SKIP LOCKED LIMIT N` inside a transaction in `common/outbox/gorm_repository.go` _(v1.14.0)_
- [x] Mark fetched rows as `processing` atomically before returning _(v1.14.0)_
- [ ] All service-specific outbox workers (warehouse, notification, etc.) that duplicate this code should migrate to the common worker after the fix

---

### XC-P0-003: Rate Limiter Uses `X-Forwarded-For` Without Trusted Proxy Validation

**File**: `common/middleware/ratelimit.go:133-136`

**Problem**: `getClientIP()` reads `X-Forwarded-For` first without validating the source is a trusted proxy:
```go
if forwarded := header.Get("X-Forwarded-For"); forwarded != "" {
    ips := strings.Split(forwarded, ",")
    return strings.TrimSpace(ips[0])
}
```

An attacker can set `X-Forwarded-For: 1.2.3.4` in any request to impersonate any IP → completely bypass IP-based rate limiting. Rate limit keys become `ratelimit:ip:1.2.3.4:/api/v1/orders` which the attacker controls.

This means:
- Brute-force login is unrestricted (can cycle IPs at will)
- OTP endpoint is unprotected
- Payment endpoint rate limit is bypassable

**Resolution**:
- [x] Add `TrustedProxies []string` to `RateLimitConfig`; ignore `X-Forwarded-For` if source IP not in trusted list _(v1.14.0)_
- [ ] Use `c.ClientIP()` in Gin (which respects `TrustedProxies` set on the engine) rather than manual header inspection
- [ ] For Kratos middleware: use the last non-trusted IP in the `X-Forwarded-For` chain

---

## 🟡 Open P1 Issues

### XC-P1-001: Common IdempotencyChecker Not Universally Adopted — Each Service Has Its Own Impl

**Problem**: `common/idempotency/event_processing.go` provides a reusable `IdempotencyChecker` with `ProcessWithIdempotency()`. However, services use different idempotency mechanisms:

| Service | Mechanism | Table |
|---------|-----------|-------|
| Order | `IdempotencyHelper` (Redis state machine) | Redis key |
| Notification | `processedEventRepo.IsEventProcessed` | `processed_events` |
| Warehouse | Inline status guard (`res.Status == "active"`) | No dedicated table |
| Auth | `CartSessionID` unique constraint | `orders` |
| Common | `IdempotencyChecker` | `event_processing_log` |

**Result**: Idempotency logic is fragmented → different services have different guarantees, retry behaviors, and cleanup policies. Some lack event_processing_log TTL cleanup entirely.

**Resolution**:
- [ ] Standardize on `common/idempotency.IdempotencyChecker` for all event consumers
- [ ] Add `event_processing_log` migration to each service that doesn't have it
- [ ] Enforce idempotency cleanup cron in every service worker (call `CleanupOldLogs` daily)

---

### XC-P1-002: JWT Auth Middleware Does Not Enforce `user_id` Claim as Mandatory

**File**: `common/middleware/auth.go:80-88`

**Problem**: `Auth()` middleware does NOT fail if `user_id` is missing from JWT claims. It silently proceeds without setting `user_id` in context — which then causes downstream `GetUserID(c)` calls to return `"", false`. Business logic that relies on user identity without checking the `bool` return can inadvertently process requests as anonymous.

The comment at line 89-92 confirms this is intentionally lenient ("mirror existing behavior"). But for a mandatory Auth middleware, a token without `user_id` should be rejected.

**Resolution**:
- [x] In `Auth()` (not `OptionalAuth()`): require `user_id` claim to be non-empty; return 401 INVALID_CLAIMS if missing _(v1.14.0)_
- [ ] Document which endpoints use `OptionalAuth` vs `Auth` and audit all handlers that call `GetUserID` without checking the bool

---

### XC-P1-003: Rate Limiter Uses Fixed Window — Vulnerable to Burst at Window Boundary

**File**: `common/middleware/ratelimit.go:146-185`

**Problem**: Fixed window counter (`INCR` + `EXPIRE`) allows request bursting. At minute :59 → :00 boundary an attacker can send 100 requests just before reset, then 100 more just after → 200 requests in 2 seconds. For OTP, login, and payment endpoints this is dangerous.

Compare: Shopify uses a **sliding window** or **token bucket** for critical endpoints.

**Resolution**:
- [ ] Implement sliding window counter using a Redis `ZADD` + `ZREMRANGEBYSCORE` + `ZCARD` approach for sensitive endpoints
- [ ] OR: use **per-endpoint limits** with lower caps for sensitive paths (`/auth/otp`, `/payment/`, `/auth/login`) vs default for read endpoints

---

### XC-P1-004: Common Outbox Worker Has No Retry Backoff on Publish Failure

**File**: `common/outbox/worker.go:142-147`

**Problem**: When `publisher.PublishEvent` fails, the event status is marked `"failed"` immediately and the worker moves on. On the next poll (30 seconds later), `FetchPending` only returns `status='pending'` events — `"failed"` events are **never retried** by the common worker.

If Dapr sidecar is temporarily unresponsive (e.g., networking blip, pod restart), all in-flight outbox events are permanently dropped.

Compare with warehouse's custom outbox worker which has `MaxRetries=5` and keeps status `PENDING` on failure.

**Resolution**:
- [x] Change failed publish to keep status `'pending'` with increment retry count _(v1.14.0)_
- [x] Add `max_retries` field to `Worker` struct; mark as `'failed'` only after exceeding max; added `WithMaxRetries(n)` option _(v1.14.0)_
- [ ] Add `retry_count` to the outbox events table via migration

---

### XC-P1-005: No Circuit Breaker Implementation Found

**File**: `common/` — searched across all packages

**Problem**: §15.4 specifies "Circuit breaker (service-to-service calls)". No circuit breaker implementation exists in the common library or any service client. gRPC service clients (warehouse → catalog, order → warehouse) do not have circuit breaking configured.

Loss of downstream service without a circuit breaker leads to:
- Cascading timeouts across the call chain
- Request queue buildup
- Memory exhaustion in upstream services (goroutine leak on blocked I/O)

Compare: Shopify/Lazada use Hystrix / Resilience4j / go-zero circuit breakers for all inter-service calls.

**Resolution**:
- [ ] Add circuit breaker to `common/grpc/` client wrapper using `sony/gobreaker` or `go-retryablehttp`
- [ ] Apply to all service client constructors: `add-service-client` skill should include circuit breaker as default
- [ ] Document circuit breaker configuration: failure threshold (5 failures in 10s → open), recovery timeout (30s)

---

## 🔵 P2 Issues

### XC-P2-001: PII Masker Does Not Cover National ID / Passport Number / Tax ID Patterns

**File**: `common/security/pii/masker.go:200-213`

**Problem**: `ShouldMaskField` covers `ssn`, `tax_id` by field name, but `MaskLogMessage` regex only applies email, credit card, and phone patterns. National ID numbers (CCCD Vietnam: 12 digits, Passport: 8-9 alphanumeric) are not in the regex list → can appear unmasked in logs.

Under PDPA (Thailand) and Vietnamese Personal Data Protection Decree, national ID is Category-1 sensitive data requiring higher protection than email.

**Resolution**:
- [x] Add National ID regex patterns (12-digit for VN CCCD, 8-9 char for passport) to `MaskLogMessage` _(v1.14.0)_
- [x] Add `national_id`, `passport`, `citizen_id`, `cccd` to `sensitiveFields` list in `ShouldMaskField` _(v1.14.0)_

---

### XC-P2-002: `event_processing_log` Cleanup Not Enforced — Table Will Bloat

**Problem**: `common/idempotency.CleanupOldLogs()` exists but no service calls it in a scheduled cron. Each event consumer marks events as `processed` but they accumulate indefinitely.

High-volume services (notification, order) may process millions of events per day. Without cleanup, the `event_processing_log` table will grow to GB scale within months → slow `IsProcessed` queries → idempotency check latency spike.

**Resolution**:
- [ ] Register a daily `CleanupOldLogs(retentionDays=30)` call in each service worker that uses `IdempotencyChecker`
- [ ] Add index `(event_id, consumer_service, processed_at)` for efficient cleanup queries

---

### XC-P2-003: Recovery Middleware Logs Full Stack Trace in Structured Log — PII Risk

**File**: `common/middleware/recovery.go:56-57`

**Problem**: On panic, `debug.Stack()` is included in the log entry:
```go
entry = entry.WithField("stack", string(debug.Stack()))
```

Stack traces may include function argument values, variable contents, or Go interface strings that contain customer PII (email, phone, order details) when the panic occurs inside a request handler.

**Resolution**:
- [x] Pass stack trace through `pii.Masker.MaskLogMessage()` before logging _(v1.14.0)_
- [x] Gate stack trace logging behind env flag: `LOG_PANIC_STACK=true` (default false in prod) _(v1.14.0)_

---

### XC-P2-004: Single string `role` Claim in JWT — Not Scalable for RBAC

**File**: `common/middleware/auth.go:83-84`

**Problem**: JWT token stores a single `role` string (`"admin"`, `"customer"`, `"warehouse_manager"`). This doesn't support:
- Users with multiple roles (e.g., a user who is both `seller` and `customer`)
- Fine-grained permission checks (can read order vs can update order)
- Service accounts / API keys with specific scopes

The warehouse `AdjustmentUsecase` already needs `["warehouse_manager", "operations_staff", "system_admin"]` multi-role checks — it calls `HasAnyRole` using a gRPC call to the User service per request, which adds latency.

**Resolution** (medium-term):
- [ ] Migrate JWT claim to `roles: ["warehouse_manager", "operations_staff"]` (array)
- [ ] OR: embed permissions/scopes in JWT and validate without User service roundtrip

---

### XC-P2-005: No Cross-Service Trace Propagation Standardized

**Problem**: Each service uses OTel, but there is no documented standard for how trace context is propagated across service boundaries:
- gRPC calls: are `traceparent` headers forwarded automatically by Dapr?
- Event consumers: are trace IDs included in event payloads?
- Outbox events: the warehouse outbox injects `event_id` but not `traceparent`

Without consistent trace propagation, Jaeger/Tempo shows disconnected spans — making root-cause analysis of cross-service failures very difficult.

**Resolution**:
- [ ] Document OTel propagation: confirm Dapr injects W3C `traceparent` in pubsub messages
- [ ] Add `traceparent` field to all outbox event payloads for correlated tracing
- [ ] Add integration test that verifies trace ID flows from gateway → order → warehouse → notification

---

## 📋 Data Consistency Matrix (Cross-Service)

| Concern | Consistency Level | Risk |
|---------|-----------------|------|
| Outbox event + DB write | ✅ Atomic (same TX) | Safe in services that use `outboxRepo.Save(txCtx, ...)` |
| Outbox delivery to Dapr (multi-replica) | ❌ No SKIP LOCKED | XC-P0-002: duplicate events possible |
| Event consumer idempotency | ⚠️ Fragmented | XC-P1-001: different mechanisms per service |
| JWT user identity in request | ⚠️ Optional claim | XC-P1-002: user_id not enforced mandatory |
| Rate limit per IP | ❌ Spoofable | XC-P0-003: X-Forwarded-For not trusted-proxy validated |
| CORS for auth'd requests | ❌ Broken | XC-P0-001: `*` + `credentials:true` is invalid spec |
| PII in logs | ⚠️ Partial | XC-P2-001: national ID not covered; XC-P2-003: stack trace with PII |
| Service resilience on downstream failure | ❌ No circuit breaker | XC-P1-005: cascading failures unmitigated |
| Distributed tracing continuity | ⚠️ Incomplete | XC-P2-005: trace propagation not standardized |

---

## 📋 §15 Mapping vs Implementation Status

| §15 Requirement | Implementation | Gap |
|----------------|---------------|-----|
| **15.1 Idempotency** | Fragmented (per-service) | No unified adoption of `common/idempotency` |
| **15.2 Saga / Outbox / Reservation** | Outbox ✅ Saga ✅ Reservation ✅ | No SKIP LOCKED → duplicate publish risk |
| **15.3 JWT auth** | `common/middleware/auth.go` ✅ | Single role claim, user_id not enforced |
| **15.3 Rate limiting** | `common/middleware/ratelimit.go` ✅ | Fixed window, spoofable IP |
| **15.3 CORS** | `common/middleware/cors.go` | `*` + credentials → XC-P0-001 |
| **15.3 PCI-DSS (no raw PAN)** | PII masker ✅ | National ID / passport coverage missing |
| **15.3 PDPA/GDPR** | Unsubscribe + preference ✅ | No data erasure endpoint found |
| **15.4 Circuit breaker** | ❌ Not implemented | XC-P1-005 |
| **15.4 Retry + backoff** | Per-service impl ✅ | Common outbox no retry backoff |
| **15.4 DLQ** | Per-service DLQ ✅ | Common outbox marks failed without retry |
| **15.4 Health checks** | `common/observability/health` ✅ | Good; factory pattern |
| **15.5 Structured logging** | Per-service ✅ | Trace ID in logs consistent? Not audited |
| **15.5 Distributed tracing** | OTel in each service | Propagation across events not verified |
| **15.5 Metrics (RED)** | `common/observability/metrics` ✅ | Rate limit DOWN metric ✅ |
| **15.6 Multi-language** | Catalog has `name_en/name_th` ✅ | Search index language handling unclear |

---

## 🔧 Remediation Actions

### 🔴 Fix Now (Security / Correctness)

- [x] **XC-P0-001**: Fix `cors.go` → `AllowCredentials: false` in default; `CORSWithCredentials(origins)` for auth flows; fix `MaxAge` format bug _(v1.14.0)_
- [x] **XC-P0-002**: Add `FOR UPDATE SKIP LOCKED` to `common/outbox/gorm_repository.go:FetchPending`; atomically marks rows as `processing` _(v1.14.0)_
- [x] **XC-P0-003**: Added `TrustedProxies []string` to `RateLimitConfig`; validate `X-Forwarded-For` source before using as rate limit key _(v1.14.0)_

### 🟡 Fix Soon (Reliability / Consistency)

- [ ] **XC-P1-001**: Standardize on `common/idempotency.IdempotencyChecker`; add migration + cron cleanup per service
- [x] **XC-P1-002**: Enforce `user_id` as mandatory claim in `Auth()` (not `OptionalAuth()`); `AuthKratos` also updated _(v1.14.0)_
- [ ] **XC-P1-003**: Implement sliding window or per-endpoint limits for `/auth/otp`, `/auth/login`, `/payment/`
- [x] **XC-P1-004**: Common outbox worker failed publish → keep `pending` with retry count; mark `failed` only after max retries _(v1.14.0)_
- [ ] **XC-P1-005**: Add circuit breaker to `common/grpc/client` wrapper; apply to all service clients

### 🔵 Monitor / Document

- [x] **XC-P2-001**: Add national ID, passport, citizen_id patterns to `MaskLogMessage` regex; added to `ShouldMaskField` _(v1.14.0)_
- [ ] **XC-P2-002**: Register daily `CleanupOldLogs` in all service workers using `IdempotencyChecker`
- [x] **XC-P2-003**: Stack trace routed through PII masker; gated with `LOG_PANIC_STACK` env flag _(v1.14.0)_
- [ ] **XC-P2-004**: Migrate JWT `role` (string) to `roles` ([]string); reduce User service roundtrips for role checks
- [ ] **XC-P2-005**: Document OTel trace propagation standard; inject `traceparent` in outbox event payloads
- [ ] Audit PDPA/GDPR: implement data erasure API (`DELETE /users/{id}/data`) and document retention periods

---

## ✅ What Is Working Well

| Area | Notes |
|------|-------|
| JWT algorithm pinning | `*jwt.SigningMethodHMAC` prevents alg:none attack |
| Lua atomic rate limit | INCR+EXPIRE in single eval — no TOCTOU race |
| FailClosed option | Rate limiter returns 503 when Redis down and FailClosed=true |
| DDoS protection monitoring | ERROR log + metrics on Redis failure |
| Outbox atomic save in DB tx | All services using outbox write event inside same TX as business data |
| Recovery → no stack to client | Only generic 500 returned; stack stays server-side |
| PII masker auto-scan logs | `MaskLogMessage` regex scans email, phone, CC patterns in-flight |
| Health check composition | Factory pattern for DB, Redis, gRPC health in `common/observability/health` |
| Graceful worker stop | `StopChan()` + context cancellation in `common/worker` |
| Idempotency ON CONFLICT upsert | Race-safe even if two workers check simultaneously |

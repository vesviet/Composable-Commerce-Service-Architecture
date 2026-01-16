# ✅ Backend Services - Code Review Checklist

**Last Updated**: January 16, 2026
**Reviewer**: Cascade (Tech Lead)
**Objective**: Systematically review all Go microservices to ensure they meet architecture standards, identify risks, and create a backlog of actionable improvements.

---

## 📊 Overall Review Progress

| Service Group | Status | Notes |
| :--- | :--- | :--- |
| **Core Libs & Gateway** | ✅ Completed | `common`, `gateway` |
| **Identity** | 🟡 In Progress | `auth`, `user`, `customer` |
| **Commerce** | ✅ Completed | `catalog` ✅, `pricing` 🟡, `promotion` ✅ |
| **Logistics** | 🟡 In Progress | `order` 🟡, `warehouse` ✅, `payment` ✅, `fulfillment` ✅, `shipping` 🟡 |
| **Supporting** | ✅ Completed | `search` ✅, `location` 🟡 |
| **Engagement** | ⚪ Pending | `review`, `notification`, `analytics` |

---

## 📝 Master Review Rubric (Standardized Checklist)

To ensure code quality, reliability, and maintainability across all backend services, we apply the following **Standard 10-Point Checklist**.

### 1. 🏗 Architecture & Clean Code
- **[ ] Standard Layout**: Follows standard Go layout (`api`, `internal/biz`, `internal/data`, `internal/service`, `cmd`).
- **[ ] Separation of Concerns**: Strong boundaries. No DB logic in Biz layer; no Biz logic in HTTP handlers.
- **[ ] Dependency Injection**: Clear dependency graph (Wire or manual DI); no global state or hidden dependencies.
- **[ ] Linter Compliance**: Passes `golangci-lint` (errcheck, staticcheck, gosec, revive) with zero warnings.

### 2. 🔌 API & Contract (gRPC/HTTP)
- **[ ] Proto Standards**: Follows naming conventions; request/response messages defined properly; standardized types.
- **[ ] Error Handling**: Returns standard gRPC status codes (e.g., `NotFound`, `InvalidArgument`, `Unauthenticated`) mapped correctly to HTTP statuses.
- **[ ] Validation**: Input validation implemented explicitly (e.g., `protoc-gen-validate` or manual checks) before logic execution.
- **[ ] Backward Compatibility**: No breaking changes in existing contracts without versioning.

### 3. 🧠 Business Logic & Concurrency
- **[ ] Context Propagation**: `context.Context` passed through all layers for cancellation and timeouts.
- **[ ] Goroutine Safety**: No unmanaged `go func`; use `errgroup` or worker pools; panic recovery in background tasks.
- **[ ] Race Conditions**: Mutable shared state protected by mutexes; atomic operations used where appropriate.
- **[ ] Idempotency**: Critical write operations (payments, inventory, wallet) must handle retries safely (idempotency keys).

### 4. 💽 Data Layer & Persistence
- **[ ] Transaction Boundaries**: Business operations spanning multiple writes MUST uses atomic transactions (Unit of Work).
- **[ ] Query Optimization**: No N+1 queries; proper indexing on lookup columns; efficient pagination.
- **[ ] Migration Management**: Schema changes scripted (Goose/Migrate); Up/Down steps tested; no breaking schema changes.
- **[ ] Repository Pattern**: DB implementation isolated behind interfaces; no raw SQL leakage to business layer.

### 5. 🛡 Security
- **[ ] AuthN/AuthZ**: All endpoints protected by Middleware; strict ownership checks (User can only access own data).
- **[ ] Input Sanitation**: SQL injection prevention (parameterized queries); XSS protection; strict input validation.
- **[ ] Secrets Management**: No hardcoded credentials/tokens; use environment variables or secret managers.

### 6. ⚡ Performance & Scalability
- **[ ] Caching Strategy**: Appropriate use of Redis for read-heavy data; clear Invalidation logic (Cache-aside/Write-through).
- **[ ] Bulk Operations**: Batch processing available for high-volume inserts/updates.
- **[ ] Resource Management**: DB/Redis connection pools configured (MaxOpenConns, MaxIdleConns, Timeouts).

### 7. 👁 Observability
- **[ ] Structured Logging**: JSON logs with context fields (`trace_id`, `user_id`, `request_id`).
- **[ ] Metrics**: Prometheus metrics for Request Rate (RED method), Errors, Latency, and custom Business Metrics.
- **[ ] Tracing**: OpenTelemetry spans implemented for critical paths and cross-service calls.

### 8. 🧪 Testing & Quality
- **[ ] Unit Tests**: Business logic coverage > 80%; Table-driven tests used; Edge cases covered.
- **[ ] Integration Tests**: Service-to-Repo flows verifying DB interactions (using Docker/Testcontainers).
- **[ ] Mocks**: Dependencies mocked correctly (using `mockgen`) to isolate unit tests.

### 9. ⚙️ Configuration & Resilience
- **[ ] Resilience**: Timeouts set on ALL external calls; Retries with Exponential Backoff; Circuit Breakers for failure-prone dependencies.
- **[ ] Robust Config**: Strongly typed configuration; Valid defaults; Configuration validation on startup.

### 10. 📚 Documentation & Maintenance
- **[ ] README**: Clear setup, run, and usage instructions; Architecture diagram if complex.
- **[ ] API Docs**: Swagger/OpenAPI specs generated and up-to-date.
- **[ ] Action Items**: Clear backlog of tech debt labeled in code (TODOs) or issue tracker.

---

## 📚 Review Documents

**Consolidated Service Reviews** (1 document per service group):
- 🔐 **Identity Services** (Auth, User, Customer): [`IDENTITY_SERVICES_REVIEW.md`](./IDENTITY_SERVICES_REVIEW.md)
- 📦 **Catalog Service**: [`CATALOG_SERVICE_REVIEW.md`](./CATALOG_SERVICE_REVIEW.md)
- 🎁 **Promotion Service**: [`PROMOTION_SERVICE_REVIEW.md`](./PROMOTION_SERVICE_REVIEW.md)
- 💳 **Payment Service**: [`PAYMENT_SERVICE_REVIEW.md`](./PAYMENT_SERVICE_REVIEW.md)
- 📦 **Fulfillment Service**: [`FULFILLMENT_SERVICE_REVIEW.md`](./FULFILLMENT_SERVICE_REVIEW.md)
- 🔍 **Search Service**: [`SEARCH_SERVICE_REVIEW.md`](./SEARCH_SERVICE_REVIEW.md)

**Master Checklist** (this document):
- Overall progress
- Rubric standards
- Quick reference for all services

---

## 🚀 Service-by-Service Review

### Group 1: Core Libs & Gateway

#### 1. `common` (Shared Library)
-   **[✅] Review Status**: Completed (Re-audited)
-   **Findings**:
    -   **Good**: Robust `errors` package (Standard codes ✅); `client` includes circuit breakers/retries.
    -   **Issue (P1) [Documentation]**: `README.md` is malformed (Git conflicts present).
    -   **Issue (P1) [Observability]**: Tracing helpers exist in `observability/tracing` but are not standard middleware interceptors.
-   **Action Items**:
    -   `[P1]` **Fix README**: Clean up conflict markers.
    -   `[P1]` **Enhance Observability**: Add reusable `StartSpan` middleware/interceptors for Kratos/HTTP.

#### 2. `gateway`
-   **[🟡] Review Status**: In Progress (Re-audited against 10-Point Standard)
-   **Findings (New Standard)**:
    -   **Good**: Centralized routing via `gateway.yaml` (clean config); Health checks present.
    -   **Issue (P0) [Security]**: Routing Patterns in `gateway.yaml` refer to **Paths ONLY**. **[✅ Fixed]** - Updated `gateway.yaml` to enforce strict `methods` filtering (GET vs POST).
        -   *Risk*: `POST /api/v1/reviews` matches the "public" middleware alias intended for `GET`. **[Fixed]**
    -   **Issue (P1) [Observability]**: `NewHTTPServer` uses Promhttp but **MISSES** OpenTelemetry Tracing middleware.
-   **Prioritized Action Items**:
    -   `[x]` `[P0]` **Fix Routing Engine**: Update `internal/router` and `gateway.yaml` to support `methods: ["GET"]` in routing patterns. **(Completed)**
    -   `[P1]` **Add Tracing**: Inject OpenTelemetry middleware in `server/http.go`.

---

### Group 2: Identity Services

**📋 Detailed Review Document**: See [`IDENTITY_GATEWAY_SERVICES_DETAILED_REVIEW.md`](./IDENTITY_GATEWAY_SERVICES_DETAILED_REVIEW.md) for comprehensive Auth, User, Customer, Gateway analysis with findings, action items, and implementation roadmap.

**Quick Summary**:
- Auth (88%): 0 P0, 2 P1, 1 P2 → 8h fix
- User (90%): 0 P0, 2 P1, 1 P2 → 6h fix
- Customer (85%): 1 P0, 3 P1, 1 P2 → 12h fix
- Gateway (92%): 0 P0, 1 P1, 1 P2 → 4h fix
- **Total**: 1 P0, 8 P1, 4 P2 → 30h to production ready

<<<<<<< HEAD
#### 3. `auth`
-   **[🟡] Review Status**: In Progress - See [`IDENTITY_SERVICES_REVIEW.md`](./IDENTITY_SERVICES_REVIEW.md) for full details
-   **Overall Score**: 90% | **Issues**: 4 (2 P0, 1 P1, 1 P2) | **Est. Fix**: 29h
-   **Key Issues**:
    -   **P0-1**: Redis-only persistence (8h) - Implement PostgreSQL dual-write
    -   **P0-2**: Missing middleware stack (4h) - Add metrics + tracing
    -   **P1-1**: Token revocation metadata (6h) - Capture audit trail
    -   **P1-2**: Session limits bypass (5h) - Enforce LRU eviction
    -   **P1-3**: Refresh token rotation handling (2-4h) - Rotation currently revokes old refresh token/session but only logs a warning if revoke fails; recommend **fail refresh** on revoke failure to avoid token reuse and add tests to enforce behavior.
    -   **P1-4**: Gateway blacklist & validation metrics (1-2h) - Gateway implements JWT blacklist (`jwt_blacklist.go`) and local validation fallback; verify Redis integration, add metrics (blacklist checks, cache hit rate), and add integration tests.
-   **Reference**: Full details in [`IDENTITY_SERVICES_REVIEW.md` → Auth Service](./IDENTITY_SERVICES_REVIEW.md#-service-1-auth-service)
    -   **Issue (P0) [Persistence]**: Tokens/Sessions are stored **ONLY in Redis** → **[✅ Fixed]** - Implemented `tokens` table and dual-write in `TokenRepo`.
    -   **Issue (P0) [Observability]**: Missing `metrics` and `tracing` middleware → **[P0]** Add metrics + tracing: inject `metrics.Server()` and `tracing.Server()` in `auth/internal/server/http.go` and verify `/metrics` + Jaeger traces in staging.
    -   **Issue (P1) [Security]**: `RevokeTokenWithMetadata` not implemented → **[✅ Fixed]** - Verified implementation; `TokenRepo` properly persists revocation metadata to `token_blacklist`.
    -   **Issue (P1) [Security]**: Session limit bypass risk → **[✅ Fixed]** - Implemented atomic `CreateSessionWithLimit` in `SessionRepo`.
-   **Prioritized Action Items** (Est. 6 hours):
    -   `[P2]` Add Integration Tests (6h)

#### 4. `user`
-   **[🟡] Review Status**: In Progress - See [`IDENTITY_SERVICES_REVIEW.md`](./IDENTITY_SERVICES_REVIEW.md) for full details
-   **Overall Score**: 95% | **Issues**: 2 (all P1) | **Est. Fix**: 9h
-   **Key Issues**:
    -   **P1-2**: Event publishing outside transaction (5h) - Move to business logic
    -   **P1-3**: Repository leaks implementation (4h) - Hide gorm.DB behind interface
-   **Reference**: Full details in [`IDENTITY_SERVICES_REVIEW.md` → User Service](./IDENTITY_SERVICES_REVIEW.md#-service-2-user-service)

#### 5. `customer`
-   **[🟡] Review Status**: In Progress - See [`IDENTITY_SERVICES_REVIEW.md`](./IDENTITY_SERVICES_REVIEW.md) for full details
-   **Overall Score**: 92% | **Issues**: 1 (P1) | **Est. Fix**: 8h
-   **Key Issues**:
    -   **P1-2**: Worker resilience audit (8h) - Verify concurrency patterns
    -   **P1-3**: Password management (1h) - Customer `AuthUsecase` uses `common/security` PasswordManager (✅ implemented). Verify no remaining direct `bcrypt` usage and update tests/docs.
-   **Reference**: Full details in [`IDENTITY_SERVICES_REVIEW.md` → Customer Service](./IDENTITY_SERVICES_REVIEW.md#-service-3-customer-service)
=======
#### 3. `auth` (Session Auth)
-   **[🟡] Review Status**: In Progress (session auth reviewed vs Master Rubric)
-   **Session/Auth Entry Points**:
    -   `auth/internal/service/auth.go`: `Login`, `GenerateToken`, `RefreshToken`, `CreateSession`, `GetSession`, `GetUserSessions`, `RevokeSession`, `RevokeUserSessions`
-   **Session Persistence & Limits**:
    -   `auth/internal/biz/session/session.go`: session usecase + configurable limits (`Auth.Session.MaxSessionsPerUser`, `Auth.SessionLimits.*`)
    -   `auth/internal/data/postgres/session.go`: Postgres repo `user_sessions` + atomic `CreateSessionWithLimit` (rotates oldest sessions)
    -   **Gap (P1) [Correctness]**: `GetSession`/`GetUserSessions` repo does **not filter** `is_active=true` and `RevokeSession` physically deletes instead of marking inactive. Decide consistent semantics (soft revoke vs hard delete) and enforce.
-   **Session TTL / Cleanup**:
    -   `auth/internal/biz/session/session.go`: exposes `CleanupExpiredSessions(maxIdle, absoluteExpiration)`
    -   `auth/internal/data/postgres/session.go`: cleanup deletes if `is_active=false` OR idle OR too old
    -   **Gap (P1) [Config/Runtime Safety]**: cleanup logic depends on worker scheduling + durations; verify config wiring and add metrics on rows deleted.
-   **Security Notes (Session Auth scope)**:
    -   No cookie-based session flags to review here (service appears token+session-id based, not HTTP cookie session).
    -   **Gap (P1) [Auditability]**: session rotation/revocation deletes rows; consider persisting `revoked_at`/`revoked_reason` for audit trails.
-   **Action Items (Session Auth)**:
    -   `[P1]` Define revoke semantics (soft vs hard) + filter queries by active status.
    -   `[P1]` Add metrics/tracing around session endpoints + cleanup worker.

#### 4. `user` (Identity User Service)
-   **[🟡] Review Status**: In Progress (re-audited)
-   **Entry Points**:
    -   `user/internal/service/user.go` (gRPC/HTTP handlers)
    -   `cmd/user/main.go` (server bootstrap)
-   **Architecture & Patterns**:
    -   Clean layers, Google Wire DI, Outbox pattern implemented (`internal/worker/outbox_worker.go`).
    -   Redis cache wrapper (`userCache`) for hot reads.
-   **Key Findings (this review)**:
    -   **[✅ Fixed] Event publishing transactionality**: `UserUsecase.CreateUser` now writes Outbox event within DB tx; worker publishes asynchronously.
    -   **[P1] Missing tracing middleware**: `internal/server/http.go` uses metrics but no `tracing.Server()`; same for gRPC server.
    -   **[P1] Repository abstraction leak**: `internal/data/postgres/user.go` still returns GORM models and exposes `gorm.DB` in repo; refactor to pure interface + DTO mapping.
    -   **[P1] Token invalidation**: `incrementPermissionsVersion` uses `time.Now().UnixNano()` but tokens reference `PermissionsVersion` claim; need strict monotonic guarantees & tests.
    -   **[P2] Cache eviction strategy**: `userCache` invalidates on writes but lacks TTL metrics; add hit/miss instrumentation.
-   **Action Items (User Service)**:
    -   `[P1]` Inject OpenTelemetry tracing middleware for HTTP & gRPC servers.
    -   `[P1]` Refactor postgres repos to hide GORM; return domain entities.
    -   `[P1]` Add unit/integration tests ensuring `PermissionsVersion` bump invalidates old JWTs.
    -   `[P2]` Instrument Redis cache with Prometheus metrics (hits, misses, evictions).
-   **Overall Score (updated)**: 92 → 93 % (1 P1 fixed, 3 P1 remain) | **Est. Fix**: 10h

#### 5. `customer` (Identity Customer Service)
-   **[🟡] Review Status**: In Progress (re-audited)
-   **Entry Points**:
    -   `customer/internal/service/customer.go` (service composition)
    -   `customer/internal/service/authentication.go` (`Register`, `Login`, `Logout`, `RefreshToken`, `ValidateToken`, `VerifyEmail`)
    -   `customer/cmd/customer/*` (server bootstrap + wire)
    -   `customer/cmd/worker/*` + `customer/internal/data/eventbus/*` (async consumers)
-   **Auth Integration Model**:
    -   Customer service owns **customer credential + profile**; delegates **token/session** to Auth service via `internal/client/auth/*`.
    -   `customer/internal/biz/customer/auth.go`: `AuthUsecase` calls `authClient.GenerateToken/RefreshToken/RevokeSession/ValidateToken`.
-   **Security & AuthZ**:
    -   **Good**: Rate limit + account lock backed by Redis (`customer/internal/biz/customer/cache.go`).
    -   **Good**: Ownership middleware `CustomerAuthorization()` on HTTP server (`customer/internal/server/http.go`, `customer/internal/server/middleware/authz.go`).
    -   **Gap (P1) [Security]**: `Logout` continues even if `authClient.RevokeSession` fails (fail-open). Consider configurable policy: fail-closed for high-security clients; at minimum emit metric + alert.
    -   **Gap (P1) [Security]**: AuthZ middleware relies on `x-user-id` / `x-user-role` headers; ensure Gateway strips client-supplied values and injects trusted identity.
-   **Observability**:
    -   **Gap (P1)**: HTTP server has recovery/metadata/authz but **no metrics/tracing middleware** (unlike user service). Add `metrics.Server()` + `tracing.Server()`.
-   **Data & Domain**:
    -   Password hashing uses `common/security.PasswordManager` ✅ (`customer/internal/biz/customer/auth.go`).
    -   Email verification tokens implemented (`internal/biz/customer/verification.go`, `internal/data/postgres/verification.go`, migrations `016_create_verification_tokens_table.sql`).
-   **Resilience / Workers**:
    -   Events handled by worker (eventbus consumers) — good separation from API server.
    -   **Gap (P1)**: Need resilience audit for consumers: retry/backoff, DLQ, idempotency (files: `customer/internal/data/eventbus/*.go`).
-   **Action Items (Customer Service)**:
    -   `[P1]` Add `metrics.Server()` + `tracing.Server()` in `customer/internal/server/http.go`.
    -   `[P1]` Harden logout behavior: add metric + decide fail-open vs fail-closed.
    -   `[P1]` Ensure Gateway header trust boundary is enforced for `x-user-*`.
    -   `[P1]` Audit eventbus consumers for retry/DLQ/idempotency.
-   **Overall Score (updated)**: 88 → 90 % | **Est. Fix**: 10-14h
>>>>>>> 481ae01f7c8354b16cd65236eea82c558a83f81f

---

### Group 3: Commerce Services

#### 6. `catalog`
-   **[✅] Review Status**: Completed
-   **Production Readiness**: ✅ PRODUCTION READY
-   **Notes**: Transactional Outbox fully implemented; middleware and worker concurrency audited.

#### 7. `pricing`
-   **[🟡] Review Status**: In Progress (fixes verified)
-   **Outstanding Action Items**:
  - [P1] Implement Transactional Outbox for Price Events (6-12h)
  - [P1] Replace unmanaged goroutines for Catalog sync with outbox/worker (2-4h)
  - [P1] Add CI benchmarks & regression tests for `BulkCalculatePrice` (2-4h)
  - [P2] Money representation evaluation & migration plan (8-16h)
  - [P1] Add integration tests for tax/currency failure modes (3-6h)
-   **Acceptance Criteria**:
  - Tax and conversion failures covered by tests and return explicit errors
  - Price events emitted reliably via Transactional Outbox with retries/DLQ
  - No unmanaged `go` background syncs; traces preserved for async work
  - Benchmarks included in CI and meet performance targets
-   **Notes**: Follow `catalog` outbox + worker as canonical implementation to reduce dual-write risk and standardize behavior.


#### 8. `promotion`
-   **[✅] Review Status**: Completed
-   **Overall Score**: 75% | **Issues**: 6 (3 P0, 3 P1) | **Est. Fix**: 21h
-   **Key Issues**:
    -   **P0-1**: JSON unmarshaling without error checking (4h) - Security vulnerability
    -   **P0-2**: Non-atomic usage limit enforcement (6h) - Race condition risk
    -   **P0-3**: Missing Transactional Outbox pattern (8h) - Event loss risk
    -   **P1-1**: Missing middleware stack (3h) - No metrics/tracing
    -   **P1-2**: In-memory filtering (3h) - Performance issue
    -   **P1-3**: No worker implementation (3h) - No background processing
-   **Reference**: Full details in [`PROMOTION_SERVICE_REVIEW.md`](./PROMOTION_SERVICE_REVIEW.md)
-   **⚠️ Special Note**: **NOT PRODUCTION READY** - 3 P0 blockers must be fixed
    - Reference catalog service for Transactional Outbox implementation
    - Critical: Event loss and race conditions are high-risk issues
-   **Prioritized Action Items** (Total: 21 hours):
    -   `[P0]` **Fix JSON Validation** (4h): Add error handling to all 17 `json.Unmarshal` calls
    -   `[P0]` **Atomic Usage Increment** (6h): Implement `IncrementUsageAtomic` with row locking
    -   `[P0]` **Implement Transactional Outbox** (8h): Create outbox table, repo, and worker
    -   `[P1]` **Add Middleware Stack** (3h): Add `metrics.Server()` + `tracing.Server()`
    -   `[P1]` **Optimize Filtering** (3h): Move JSONB filtering to DB queries
    -   `[P1]` **Implement Workers** (3h): Create outbox worker for event processing
-   **Production Readiness**: ⚠️ NOT READY - Requires 18h P0 fixes + 9h P1 fixes

---

### Group 4: Logistics Services

#### 9. `order`
-   **[🟡] Review Status**: In Progress (Deep audit against Master Rubric)
-   **Architecture Goal**: Cart & Checkout orchestration, Order lifecycle, and reliable integration with Payment/Warehouse/Fulfillment services.
-   **Good**:
    -   Clear separation of concerns (UseCases for Checkout vs Order domain).
    -   Robust inbound event handling with idempotency and a DB-based DLQ for inbound events (`failed_events` table + admin endpoints). ✅
    -   Optimistic locking implemented for cart items (helps concurrency).
-   **Findings (Detailed)**:
    -   **Issue (P0) [Payment Atomicity / Ghost Charge Risk]**: `ConfirmCheckout` performs **payment capture before order creation**. If order creation or reservation confirmation later fails, captured payments are not guaranteed to be refunded — rollback currently attempts to void **authorization** only (not refunds), which leaves a **ghost charge / revenue risk**. **[✅ Fixed]**
    -   **Issue (P0) [Orchestration / Transactions]**: There is no Saga/transactional coordination across Payment → Order → Reservation confirmation. `CreateOrder` + `ConfirmReservations` are separate steps with retries and metadata flags; no transactional outbox or distributed saga is used to guarantee eventual consistency. **[✅ Fixed]** - Implemented Transactional Outbox for Order events.
    -   **Issue (P0) [Inventory Safety / Fail-Open Fallback]**: `validateStockAvailability` falls back to cart `InStock` flag when Warehouse service is unavailable (timeout/unavailable). This **fail-open** behavior can allow orders that cannot be fulfilled — consider conservative (fail-closed) default or configurable policy. **[✅ Fixed]** - Implemented fail-closed logic.
    -   **Issue (P1) [Observability]**: HTTP Server has Prometheus metrics and logging, but **no OpenTelemetry tracing middleware** (no `tracing.Server()`), reducing cross-service correlation for checkout flows. **[✅ Fixed]**
    -   **Issue (P1) [Event Reliability]**: `PublishOrderCreatedEvent` is sent directly and only logs on failure — there is **no transactional outbox pattern** or outbound DLQ to guarantee event delivery. (Follow `catalog`'s transactional outbox as a reference implementation.) **[✅ Fixed]**
    -   **Issue (P1) [Idempotency / Retry Windows]**: Checkout uses cart metadata / session cleanup to detect duplicated attempts, but there remain small windows where retries could cause duplicate payments/orders; strengthen idempotency (idempotency keys / unique constraints) around ConfirmCheckout. **[✅ Fixed]**
    -   **Issue (P1) [Testing]**: Missing integration / fault-injection tests that simulate payment capture failures, reservation confirmation failures, and warehouse unavailability.
    -   **Issue (P2) [Money Representation]**: `float64` is used for monetary values across flows — consider evaluating minor-unit integers or a decimal type for correctness (rounding/precision).
-   **Prioritized Action Items (with estimates)**:
    -   `[x]` `[P0]` **Fix Payment Flow & Compensation (4-8h)**: Rework flow to **authorize-only** before order creation and **capture after order is created and reservations confirmed**, or implement robust compensation (refund) mechanism for captured payments. Add unit/integration tests that simulate failures and verify refunds/compensations. **(Completed)**
    -   `[x]` `[P0]` **Implement Saga / Transactional Coordination (8-16h)**: Implement a Saga (or Transactional Outbox + consumer) to coordinate Payment → Order → Inventory confirmation. **(Completed - Outbox Implemented)**
    -   `[x]` `[P1]` **Harden Inventory Safety Policy (2-4h)**: Change fail-open fallback to a conservative default (fail-closed) or make it configurable (feature-flagged safe-mode). Add tests and monitoring for warehouse service errors. **(Completed)**
    -   `[x]` `[P1]` **Add Observability & Trace Tests (2h)**: Inject `tracing.Server()` middleware in `order/internal/server/http.go`, and add a lightweight integration test asserting spans are created for `ConfirmCheckout` and related handlers. **(Completed)**
    -   `[x]` `[P1]` **Add Reliable Outbound Delivery (4-8h)**: Implement Transactional Outbox for `order` events (use `catalog` as reference), and create an outbound DLQ / retry policy for `orders.*` topics. **(Completed)**
    -   `[x]` `[P1]` **Idempotency & Uniqueness (3-6h)**: Add explicit idempotency keys or unique constraint on `cart_session_id -> order_id` so repeated ConfirmCheckout calls cannot double-charge or create duplicate orders. Add tests covering race/retry scenarios. **(Completed)**
    -   `[ ]` `[P1]` **Integration & Fault-injection Tests (4-8h)**: Add E2E tests that simulate payment capture failure, inventory confirmation failure, and network/timeouts to ensure compensation and cleanup paths work.
    -   `[ ]` `[P2]` **Money Representation Evaluation (8-16h)**: Plan migration from `float64` to integer minor-units or a decimal math library; provide migration steps and compatibility notes.
-   **Acceptance Criteria**:
    -   Payment is never captured without a corresponding order; or captured payments are refunded reliably in failure cases (tests + monitored alerts).
    -   Order creation and reservation confirmation are coordinated by a Saga or Outbox; events are delivered reliably (success or retry/DLQ) — follow `catalog`'s pattern.
    -   Inventory validation behavior is configurable and defaults to safe (fail-closed) mode for production.
    -   Tracing is enabled for checkout and order flows and spans are visible end-to-end.
    -   Integration tests covering the above are added and green in CI.
-   **Notes / Rationale**:
    -   **Follow `catalog`**: Use `catalog`'s transactional outbox and worker pattern as a direct reference for implementing reliable outbound events and transaction boundaries in `order`.
    -   Existing inbound DLQ + idempotency are good foundations — extend same rigor to outbound events and long-running sagas.
    -   Add monitoring alerts (payment capture without order, reservation confirmation failures) to detect regressions quickly.

#### 10. `warehouse`
-   **[✅] Review Status**: Completed (P0 items resolved)
-   **Outstanding Action Items**:
  - [P1] Replace unmanaged goroutines for alerts/catalog sync (3-6h) - Documented with TODOs
  - [P1] Improve `GetBulkStock` semantics (configurable limit or chunking) (2-4h)
  - [P1] Add integration & fault-injection tests (4-8h)
  - [P2] Money representation evaluation & plan (4-8h)
-   **Completed (2026-01-14)**:
  - [x] [P0] Make `AdjustStock` atomic - Wrapped in `tx.InTx()` for ACID compliance
  - [x] [P0] Implement Transactional Outbox - Events saved in DB before publishing
  - [x] [P1] Add observability middleware - Metrics, tracing, metadata added to HTTP server
-   **Acceptance Criteria**:
  - ✅ `AdjustStock` atomic with rollback on failure
  - ✅ Events emitted via Outbox with retries/DLQ
  - 🔄 No unmanaged background goroutines for critical flows (alerts/sync still use go func with TODOs)
  - ⏳ `GetBulkStock` behavior explicit and monitored (deferred)
-   **Implementation Details**: 
  - Created `outbox_events` table with migration `025_create_outbox_events_table.sql`
  - Implemented `OutboxRepo` and `OutboxWorker` following catalog service pattern
  - `AdjustStock` and `UpdateInventory` now fully atomic with transactional outbox
#### 10. `warehouse`
-   **[✅] Review Status**: Completed (Re-audited 2026-01-16)
-   **Overall Score**: 88% ⭐⭐⭐⭐ | **Issues**: 5 (0 P0, 3 P1, 2 P2) | **Est. Fix**: 12h
-   **Key Issues**:
    -   **P1-1**: Unmanaged goroutines for alerts & catalog sync (4h) - Panic risk, context lost
    -   **P1-2**: GetBulkStock semantics unclear (2h) - Silent truncation
    -   **P1-3**: Missing test coverage (8h) - No unit/integration tests
    -   **P2-1**: Missing architecture decision records (2h) - Undocumented decisions
    -   **P2-2**: Money representation evaluation (4h) - float64 precision issues
-   **Reference**: Full details in [`WAREHOUSE_SERVICE_REVIEW.md`](./WAREHOUSE_SERVICE_REVIEW.md)
-   **✅ Strengths**:
    - Clean Architecture with multi-domain (inventory, warehouse, throughput, timeslot)
    - Transactional Outbox pattern implemented ✅
    - Redis caching for warehouse detection
    - Comprehensive throughput capacity management with time slots
    - Location-based warehouse detection with ancestor matching
    - Bulk operations support (GetBulkStock)
    - Event-driven architecture with observers
-   **Completed (2026-01-14)**:
  - [x] [P0] Make `AdjustStock` atomic - Wrapped in `tx.InTx()` for ACID compliance
  - [x] [P0] Implement Transactional Outbox - Events saved in DB before publishing
  - [x] [P1] Add observability middleware - Metrics, tracing, metadata added to HTTP server
-   **Outstanding Action Items**:
  - [P1] Replace unmanaged goroutines for alerts/catalog sync (4h) - Documented with TODOs
  - [P1] Improve `GetBulkStock` semantics (2h) - Configurable limit or chunking
  - [P1] Add comprehensive test coverage (8h) - Target: 80%
  - [P2] Add architecture decision records (2h) - Document key decisions
  - [P2] Money representation evaluation (4h) - Plan migration from float64
-   **Acceptance Criteria**:
  - ✅ `AdjustStock` atomic with rollback on failure
  - ✅ Events emitted via Outbox with retries/DLQ
  - 🔄 No unmanaged background goroutines for critical flows (alerts/sync still use go func with TODOs)
  - ⏳ `GetBulkStock` behavior explicit and monitored (deferred)
  - ⏳ Test coverage > 80% (deferred)
-   **Implementation Details**: 
  - Created `outbox_events` table with migration `025_create_outbox_events_table.sql`
  - Implemented `OutboxRepo` and `OutboxWorker` following catalog service pattern
  - `AdjustStock` and `UpdateInventory` now fully atomic with transactional outbox
  - Worker polls outbox every 1s, processes 20 events/batch, retries 5x before DLQ
  - Prometheus metrics: `warehouse_outbox_events_processed_total`, `warehouse_outbox_events_failed_total`
  - Comprehensive throughput capacity management with time slots (see `WAREHOUSE_THROUGHPUT_CAPACITY.md`)
  - Location-based warehouse detection with Redis caching

  **References**
  - `warehouse/internal/biz/inventory/inventory.go` (transactional `AdjustStock`, outbox save; TODOs: unmanaged goroutines for alerts & catalog sync)
  - `warehouse/migrations/025_create_outbox_events_table.sql`
  - `warehouse/internal/worker/outbox_worker.go` (worker logic, retries, metrics)
  - `warehouse/internal/observability/prometheus/metrics.go`
  - `docs/checklists/WAREHOUSE_THROUGHPUT_CAPACITY.md` (capacity management implementation)

-   **Production Readiness**: ✅ PRODUCTION READY - All P0 items resolved. P1 items are enhancements (unmanaged goroutines have TODOs, tests can be added incrementally).

#### 11. `payment`
-   **[✅] Review Status**: Completed (Re-audited 2026-01-16)
-   **Overall Score**: 82% ⭐⭐⭐⭐ | **Issues**: 6 (0 P0, 4 P1, 2 P2) | **Est. Fix**: 14h
-   **Key Issues**:
    -   **P1-1**: Missing observability middleware (2h) - No metrics/tracing
    -   **P1-2**: Idempotency service không implement đầy đủ (4h) - Begin/MarkCompleted/MarkFailed return nil
    -   **P1-3**: Missing context timeout trong gateway calls (2h) - Hang risk
    -   **P1-4**: Missing unit tests cho core logic (6h) - Low coverage
    -   **P2-1**: Outbox worker implementation missing (4h) - Events không được process
    -   **P2-2**: Missing webhook reconciliation job (4h) - Stuck payments
-   **Reference**: Full details in [`PAYMENT_SERVICE_REVIEW.md`](./PAYMENT_SERVICE_REVIEW.md)
-   **✅ Special Note**: **NEAR PRODUCTION READY** - NO P0 blockers!
    - Transactional Outbox đã implemented ✅
    - Idempotency framework có sẵn (cần fix implementation)
    - Gateway abstraction pattern ✅
    - Fraud detection system ✅
    - Repository layer implemented ✅
    - P1 improvements cần thiết cho production robustness
-   **Prioritized Action Items** (Total: 14 hours P1 + 8 hours P2):
    -   `[P1]` **Add Observability Middleware** (2h): Add `metrics.Server()` + `tracing.Server()` + `/metrics` endpoint
    -   `[P1]` **Fix Idempotency Implementation** (4h): Implement Begin/MarkCompleted/MarkFailed với Redis state management
    -   `[P1]` **Add Context Timeouts** (2h): Add timeouts cho gateway calls với circuit breaker
    -   `[P1]` **Add Unit Tests** (6h): Comprehensive tests cho ProcessPayment, CapturePayment, VoidPayment, ProcessRefund
    -   `[P2]` **Implement Outbox Worker** (4h): Worker để process outbox events
    -   `[P2]` **Webhook Reconciliation** (4h): Job để reconcile stuck payments với gateway
-   **Production Readiness**: 🟡 NEAR READY - Cần fix 14h P1 issues cho full production readiness

#### 12. `fulfillment`
-   **[✅] Review Status**: Completed (Re-audited 2026-01-16)
-   **Overall Score**: 87% ⭐⭐⭐⭐ | **Issues**: 6 (1 P0, 3 P1, 2 P2) | **Est. Fix**: 14h
-   **Key Issues**:
    -   **P0-1**: Warehouse client fail-open security risk (2h) - Over-allocation risk
    -   **P1-1**: Missing business metrics (4h) - Cannot monitor operations
    -   **P1-2**: Missing distributed tracing spans (2h) - Hard to debug cross-service
    -   **P1-3**: Repository abstraction leak (4h) - Domain coupled with GORM
    -   **P2-1**: Missing API documentation (1h) - No Swagger docs
    -   **P2-2**: Missing database index hints (2h) - Query optimization
-   **Reference**: Full details in [`FULFILLMENT_SERVICE_REVIEW.md`](./FULFILLMENT_SERVICE_REVIEW.md)
-   **✅ Strengths**:
    - Clean Architecture with multi-domain (fulfillment, picklist, package, qc)
    - Transactional Outbox pattern implemented ✅
    - Multi-warehouse support with capacity checking
    - Retry mechanism for pick/pack failures
    - Status transition validation
    - Sequence generator for business numbers
-   **⚠️ Critical Fix Required**: Warehouse capacity check fail-open → change to fail-closed
-   **Prioritized Action Items** (Total: 14 hours):
    -   `[P0]` **Fix Warehouse Client Fail-Open** (2h): Change to fail-closed, add metrics
    -   `[P1]` **Add Business Metrics** (4h): Prometheus metrics for fulfillment operations
    -   `[P1]` **Add Distributed Tracing** (2h): OpenTelemetry spans for business operations
    -   `[P1]` **Fix Repository Abstraction** (4h): Separate domain from persistence models
    -   `[P2]` **Add API Documentation** (1h): Swagger annotations to proto files
    -   `[P2]` **Add Database Indexes** (2h): Composite indexes for query patterns
-   **Production Readiness**: 🟡 NEAR READY - Requires 2h P0 fix + 10h P1 fixes for full production readiness

#### 13. `shipping`
-   **[🟡] Review Status**: In Progress (Re-audited against 10-Point Standard)
-   **Architecture Goal**: Shipping orchestration + carrier integration + tracking.
-   **Findings (New Standard)**:
    -   **Good**: clean RBAC usage. `server/http.go` includes `tracing.Server()` ✅.
    -   **Good**: Clear state machine and domain separation; event-driven model is well structured.
    -   **Issue (P0) [Atomicity]**: `BatchCreateShipments` creates shipments in a loop without transaction — risk of partial commits and inconsistent state (4-8h).
    -   **Issue (P0) [Consistency / Dual-Write]**: `CreateShipment` and status updates perform DB writes then publish events directly to Dapr — no transactional outbox, leading to event loss or mismatches (8-12h).
    -   **Issue (P0) [Data Modeling]**: `tracking_events` are stored in JSONB metadata and `AddTrackingEvent` is a no-op — this makes querying and analytics difficult. Migrate to a `shipment_tracking_events` table and implement `AddTrackingEvent` (4-8h).
    -   **Issue (P0) [Carrier Integration]**: Label generation and carrier adapters are stubs; there is no real 3rd-party carrier integration or robust retry/reconciliation for label creation (8-16h).
    -   **Issue (P1) [Resilience]**: No Retry/DLQ for carrier webhooks (3-6h).
    -   **Issue (P1) [Partial Batch Semantics & Idempotency]**: `BatchCreateShipments` and related endpoints do not clearly support partial success or idempotency keys — add explicit semantics, unique constraints, and idempotency handling (3-6h).
    -   **Issue (P1) [Observability & Monitoring]**: Missing Prometheus metrics and event processing metrics for outbox/workers (2-4h).
    -   **Issue (P2) [Schema Enhancements]**: No `shipping_labels` or `shipment_items` tables; normalize label and item data for audits and analytics (4-8h).
-   **Prioritized Action Items**:
    -   `[P0]` **Fix Transaction Boundary**: `BatchCreateShipments` (and `HandlePackageReady`) must wrap multi-row changes in a single transaction or provide clearly defined partial semantics with compensations and tests (4-8h).
    -   `[P0]` **Implement Transactional Outbox**: Create `outbox_events` migration, `OutboxRepo`, and an Outbox Worker; modify usecases to save outbox events within DB transactions and stop direct `Publish` to Dapr (8-12h). **Follow `catalog`'s outbox + worker pattern as canonical reference.**
    -   `[P0]` **Migrate Tracking Events**: Create `shipment_tracking_events` table (with necessary indexes), implement `AddTrackingEvent` and query builders; phase out JSONB tracking storage (4-8h).
    -   `[P0]` **Complete Carrier Integrations & Label Generation**: Implement carrier adapters, reliable label generation with retries and reconciliation, sandbox integration tests, and a reconciliation job for stuck labels (8-16h).
    -   `[P1]` **Add Webhook Reliability**: Add retry policy, DLQ for carrier webhooks, and monitoring/alerts for stuck webhooks (3-6h).
    -   `[P1]` **Idempotency & Uniqueness**: Add idempotency key support to batch/create endpoints; add DB unique constraints (fulfillment_id/order_id → shipment) and tests to prevent duplicates (3-6h).
    -   `[P1]` **Add Observability**: Expose Prometheus metrics for outbox processing, publish failures, webhook retries and add OpenTelemetry spans for cross-service flows (2-4h).
    -   `[P2]` **Schema Improvements**: Introduce `shipping_labels` and `shipment_items` tables and migrate label/line-item data (4-8h).
    -   `[P1]` **Integration & Fault-injection Tests**: Add E2E tests simulating carrier outages, webhook failures, partial-batch failures, and outbox worker failures (4-8h).
-   **Acceptance Criteria**:
    -   All critical events (`shipment.created`, `shipment.status_changed`, `shipment.label_generated`, `shipment.delivered`) are persisted via a transactional outbox and processed reliably (retries and DLQ) — tests and staging runs green.
    -   `BatchCreateShipments` atomic behavior (or defined partial semantics) is validated by tests and idempotency keys.
    -   Tracking events are queryable (separate table) and label generation operates against real carrier adapters with retry and reconciliation.
    -   Webhooks have retry/DLQ and monitoring; alerts exist for repeated failures.
    -   Observability: Prometheus metrics and OpenTelemetry spans present for critical flows.
-   **Notes**:
    -   **Follow `catalog`**: Use `catalog`'s transactional outbox + worker pattern as the canonical implementation (see `CATALOG_SERVICE_REVIEW.md`).
    -   **Reference**: Detailed analysis available in [`SHIPPING_SERVICE_REVIEW.md`](../../shipping/SHIPPING_SERVICE_REVIEW.md)

---

### Group 5: Supporting Services

#### 14. `search`
-   **[✅] Review Status**: Completed (Re-audited 2026-01-16)
-   **Overall Score**: 89% ⭐⭐⭐⭐ | **Issues**: 5 (0 P0, 3 P1, 2 P2) | **Est. Fix**: 10h
-   **Key Issues**:
    -   **P1-1**: Cache nil check inconsistency (1h) - Missing CacheEnabled check
    -   **P1-2**: Missing context timeout in event consumers (2h) - Block risk
    -   **P1-3**: Unmanaged goroutines for analytics (3h) - Goroutine leak risk
    -   **P2-1**: Missing input validation in event handlers (1h) - Data quality
    -   **P2-2**: Cache key collision risk (1h) - Map iteration non-deterministic
-   **Reference**: Full details in [`SEARCH_SERVICE_REVIEW.md`](./SEARCH_SERVICE_REVIEW.md)
-   **✅ Special Note**: **PRODUCTION READY** - NO P0 blockers!
    - Excellent architecture with Clean Architecture + Event-driven ✅
    - Full middleware stack (metrics + tracing) ✅
    - Comprehensive DLQ + retry mechanism ✅
    - Event idempotency implemented ✅
    - Rich observability (Prometheus + OpenTelemetry) ✅
    - Multi-layer visibility filtering (pre-filter + post-filter) ✅
    - Elasticsearch best practices (custom analyzers, mappings) ✅
    - Excellent documentation ✅
-   **Prioritized Action Items** (Total: 10 hours):
    -   `[P1]` **Fix Cache Nil Check** (1h): Add CacheEnabled check to spell correction caching
    -   `[P1]` **Add Context Timeouts** (2h): Add timeouts to event consumer operations
    -   `[P1]` **Manage Goroutines** (3h): Implement WaitGroup or worker pool for analytics
    -   `[P2]` **Add Input Validation** (1h): Validate event data before processing
    -   `[P2]` **Fix Cache Key Collision** (1h): Use deterministic filter string generation
    -   `[P2]` **Add Unit Tests** (3h): Increase test coverage for core business logic
-   **Production Readiness**: ✅ READY - Can deploy now, P1 improvements recommended for robustness

#### 15. `location`
-   **[🟡] Review Status**: In Progress (Re-audited against 10-Point Standard)
-   **Architecture Goal**: Address Validation + Administrative Hierarchy.
-   **Findings (New Standard)**:
    -   **Good**: Clean separation of concerns, strong validation logic, and good unit test coverage for usecases.
    -   **Issue (P1) [Observability]**: `internal/server/http.go` is missing `tracing.Server()` (no OpenTelemetry middleware), and per-handler metrics/traces are sparse.
    -   **Issue (P1) [Performance]**: `GetLocationTree` does recursive DB calls (depth-first) which will be slow for large hierarchies and can cause multiple DB round-trips under load; no pagination or limits on tree traversal.
    -   **Issue (P1) [Caching]**: Static hierarchical data (locations by country) is read-heavy but not cached — add Redis cache or in-memory cache with invalidation.
    -   **Issue (P1) [Search Scalability]**: `Search` uses `ILIKE '%q%'` which does full table scans at scale; consider full-text search or trigram/GIN indexes.
    -   **Issue (P2) [Data Validation & Size]**: `postal_codes` and `metadata` are JSONB without validation/size limits; risk of oversized payloads and unstructured metadata causing query/perf issues.
    -   **Issue (P2) [Observability]**: No outbox or event publishing currently; if Location begins publishing domain events (location.created/updated), it must adopt the Transactional Outbox pattern (follow `catalog`).
-   **Prioritized Action Items**:
    -   `[P1]` **Add Tracing & Add Metrics** (2-4h): Inject `tracing.Server()` into `internal/server/http.go`, add per-endpoint Prometheus metrics (request rate/errors/latency) and instrument key usecases with OpenTelemetry spans.
    -   `[P1]` **Optimize GetLocationTree** (4-8h): Implement iterative tree loading or a single-query hierarchical query (CTE) to reduce round-trips; add maxDepth safeguards and pagination options.
    -   `[P1]` **Add Read Cache for Hierarchies** (4-8h): Add Redis-based cache for `GetTree` and commonly used `List` endpoints with proper invalidation on writes (create/update/delete). Add cache TTL and cache warming strategy.
    -   `[P1]` **Improve Search Performance** (4-8h): Add full-text search or trigram GIN index on `name`/`code` and switch `ILIKE` to indexed search; add integration tests and benchmarks.
    -   `[P2]` **Add Metadata & PostalCode Validation** (2-4h): Enforce size limits and shape validation for `metadata` and `postal_codes` in validators and at service boundaries.
    -   `[P2]` **Plan Events + Outbox If Needed** (4-8h): If you plan to publish `location.*` events, implement Transactional Outbox (use `catalog`'s outbox & worker as reference) to guarantee reliable event delivery.
-   **Acceptance Criteria**:
    -   Tracing is enabled and spans are visible end-to-end for `GetLocationTree` and critical endpoints.
    -   `GetLocationTree` performance improved (reduced DB queries), validated by a benchmark and an integration test for deep hierarchies.
    -   Read-heavy endpoints (`GetTree`, `List`) are cached with invalidation on writes and TTLs; cache hit/miss metrics are published.
    -   Search endpoint uses an indexed search strategy and passes benchmark targets for typical query loads.
    -   Metadata/postal code sizes are bounded and validated; tests enforce size limits.
-   **Notes**:
    -   **Follow `catalog`**: For event publishing use Transactional Outbox + worker pattern as canonical implementation.
    -   **Reference**: Service code: `location/internal/biz/location/*`, `location/internal/data/postgres/*`, `location/internal/server/http.go`.


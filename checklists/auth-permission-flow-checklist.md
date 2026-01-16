# Auth & Permission Flow Checklist

**Last Updated**: 2026-01-16
**Scope**: `auth`, `user`, `customer` services (paths per `docs/CODEBASE_INDEX.md`) + Gateway trust boundary notes.

---

## 1) Service Paths (per CODEBASE_INDEX.md)

- **Auth Service**: `/auth`
  - Key server file: `auth/internal/server/http.go`
- **User Service**: `/user`
  - Key server file: `user/internal/server/http.go`
- **Customer Service**: `/customer`
  - Key server file: `customer/internal/server/http.go`

---

## 2) Current Flow (Observed in Code)

### 2.1 Client → Gateway → Services

- Client calls APIs through **Gateway**.
- Gateway is expected to:
  - Validate JWT / session (depending on route)
  - Inject trusted identity headers (e.g. `x-user-id`, `x-user-role`, etc.)
  - Strip any client-supplied identity headers
- Services read identity context mainly via Kratos **metadata middleware**.

### 2.2 Auth responsibilities (`/auth`)

- Auth service is responsible for **token/session**.
- HTTP server middleware stack (from `auth/internal/server/http.go`):
  - `recovery.Recovery()`
  - `logging.Server(logger)`
  - `metadata.Server()`
  - `metrics.Server()`
  - `tracing.Server()`
  - plus custom `middleware.ErrorEncoder()` (HTTP error mapping)
- Operational endpoints:
  - `/health`, `/health/ready`, `/health/live`, `/health/detailed` via `common/observability/health`
  - `/metrics` via `promhttp.Handler()`
  - Swagger UI `/docs/` and OpenAPI `/docs/openapi.yaml`

### 2.3 User responsibilities (`/user`)

- User service exposes user/identity management.
- HTTP server middleware stack (from `user/internal/server/http.go`):
  - `recovery.Recovery()`
  - `metadata.Server()`
  - `metrics.Server()`
  - `tracing.Server()`
  - plus custom `middleware.ErrorEncoder()`
- Health endpoints are available via `common/observability/health`.

### 2.4 Customer responsibilities (`/customer`)

- Customer service is customer-facing and includes **ownership authorization** at HTTP layer.
- HTTP server middleware stack (from `customer/internal/server/http.go`):
  - `recovery.Recovery()`
  - `metadata.Server(metadata.WithPropagatedPrefix("x-md-", "x-client-", "x-user-"))`
  - `metrics.Server()`
  - `tracing.Server()`
  - `middleware.CustomerAuthorization()`
- Health endpoints are available via `common/observability/health`.

---

## 3) AuthN/AuthZ Checklist (Must Hold)

### 3.1 Trust boundary: identity headers are trusted only if injected by Gateway

- [ ] Gateway strips client-supplied identity headers:
  - [ ] `x-user-id`
  - [ ] `x-user-role`
  - [ ] any `x-user-*` keys
- [ ] Gateway injects authoritative identity context after successful authentication.
- [ ] Services do not treat arbitrary client headers as identity.

### 3.2 Authentication (AuthN)

- [ ] Protected endpoints require valid identity.
- [ ] Error mapping is consistent (gRPC/HTTP):
  - [ ] Invalid/expired token → `Unauthenticated`
  - [ ] Missing identity context on protected route → `Unauthenticated`

### 3.3 Authorization (AuthZ)

- [ ] Customer service enforces ownership consistently via `CustomerAuthorization()`.
- [ ] User service enforces RBAC (roles/permissions) consistently for admin operations.
- [ ] Forbidden access is returned as `PermissionDenied` (not `Unauthenticated`).

---

## 4) Session / Token Semantics Checklist (AuthN focus)

### 4.1 Token issuance

- [ ] Token minting creates a session first (single source of session id):
  - Reference: `auth/internal/biz/token/token.go` → `TokenUsecase.GenerateToken()` calls `sessionUC.CreateSession()`.
- [ ] Access token claims include:
  - [ ] `user_id`
  - [ ] `session_id`
  - [ ] `type=access`
  - [ ] `client_type` (primary)
  - [ ] `user_type` only for backward compatibility
  - Reference: `auth/internal/biz/token/token.go` → `generateAccessToken()`.
- [ ] Refresh token claims include:
  - [ ] `session_id`
  - [ ] `user_id`
  - [ ] `type=refresh`
  - Reference: `auth/internal/biz/token/token.go` → `generateRefreshToken()`.

### 4.2 Token validation

- [ ] JWT validation enforces HMAC signing method and secret:
  - Reference: `auth/internal/biz/token/token.go` → `TokenUsecase.ValidateToken()`.
- [ ] Revocation/blacklist check order is consistent:
  - [ ] Cache check first (if configured)
  - [ ] Repo check fallback
  - Reference: `auth/internal/biz/token/token.go` → `ValidateToken()` calls `cache.IsTokenRevoked()` then `repo.IsTokenRevoked()`.
- [ ] Session active check is enforced during token validation:
  - Reference: `auth/internal/biz/token/token.go` → `ValidateToken()` calls `sessionUC.IsSessionActive()`.
  - [ ] Decide and document policy if `IsSessionActive` fails (currently **fail-open** with warn log).

### 4.3 Refresh rotation (must be fail-safe)

- [ ] Refresh verifies token type == `refresh`:
  - Reference: `auth/internal/biz/token/token.go` → `TokenUsecase.RefreshToken()`.
- [ ] Refresh verifies session exists and is active:
  - Reference: `TokenUsecase.RefreshToken()` calls `sessionUC.GetSession()` and checks `IsActive`.
- [ ] Rotation does **not** allow reuse if revoke fails (**fail-closed**):
  - Reference: `TokenUsecase.RefreshToken()` calls `repo.RevokeTokenWithMetadata(...)` and returns error on failure.

### 4.4 Token storage & revocation persistence

- [ ] Token metadata is dual-written:
  - Reference: `auth/internal/data/postgres/token.go` → `StoreToken()` writes Redis + inserts into Postgres `tokens` table.
- [ ] Revocation is persisted:
  - Reference: `auth/internal/data/postgres/token.go` → `RevokeTokenWithMetadata()` writes Redis + inserts/updates Postgres `token_blacklist`.
- [ ] `IsTokenRevoked()` supports DB fallback:
  - Reference: `auth/internal/data/postgres/token.go` → `IsTokenRevoked()` checks Redis then Postgres `token_blacklist`.

### 4.5 Session limits + revoke semantics

- [ ] Session limits are enforced atomically in repo transaction:
  - Reference: `auth/internal/data/postgres/session.go` → `CreateSessionWithLimit()`.
- [ ] Revoke semantics are defined and consistent:
  - Current behavior: `SessionUsecase.RevokeSession()` calls `repo.DeleteSession()` (hard delete).
  - Reference: `auth/internal/biz/session/session.go` + `auth/internal/data/postgres/session.go`.
  - [ ] If you require soft revoke/audit trail, migrate to `is_active=false` + `revoked_at/reason` columns.

---

## 5) Observability & Ops Checklist (aligned with BACKEND_SERVICES_REVIEW_CHECKLIST)

- [ ] Standard middleware stack exists:
  - [ ] recovery
  - [ ] metadata propagation
  - [ ] metrics
  - [ ] tracing
  - [ ] logging (at least at gateway / edge; auth already has it)
- [ ] Health endpoints exist and are wired to DB/Redis checks.
- [ ] `/metrics` endpoint exposure is standardized across services (auth has it; verify need for user/customer).
- [ ] Logs include correlation fields (`trace_id`, `request_id`, `user_id` when available).

---

## 6) Security Hardening Checklist

- [ ] Login endpoints have rate limiting + brute-force protection.
- [ ] No secrets/tokens are hardcoded.
- [ ] Input validation happens before business logic.

---

## 7) Verification Steps

- [ ] Call `GET /health` for auth/user/customer and verify ready/live.
- [ ] Call `GET /metrics` where exposed and verify RED metrics.
- [ ] In staging, attempt sending spoofed `x-user-id` directly to services and verify:
  - [ ] it is blocked by network policy OR
  - [ ] gateway strips/overwrites so spoofing is ineffective.
- [ ] Verify `CustomerAuthorization()` rejects cross-user access.

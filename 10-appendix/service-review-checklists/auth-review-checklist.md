# Auth Service Review Checklist

**Date**: 2026-02-25  
**Reviewer**: Antigravity AI  
**Version**: v1.1.8 → v1.1.9 (dep update)

---

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | ✅ Fixed |
| P1 (High) | 1 | ⚠️ Remaining |
| P2 (Normal) | 2 | ⚠️ Remaining |

---

## 🔴 P0 Issues (Blocking)

### 1. [NETWORK] Customer NetworkPolicy blocked egress to Auth gRPC — Login returns HTTP 503

**Root Cause:**  
`gitops/apps/customer/base/networkpolicy.yaml` had `egress: []` (empty), which blocked all outbound connections from customer pods except those added by the `infrastructure-egress` component (DNS, PostgreSQL, Redis, Consul, Dapr). No egress rule existed for `auth-dev:9000` (gRPC) or `auth-dev:8000` (HTTP).

**Impact:**  
- `POST /api/v1/customers/login` returned HTTP 503 for all customers
- customer service authenticated credentials locally (DB lookup OK) but failed at `GenerateToken` gRPC call to auth service
- Circuit breaker `auth-service` opened after failures, compounding the issue

**Error log (customer pod):**
```
ERROR auth/auth_client.go:109 Failed to generate token: rpc error: code = Unavailable 
desc = "connection error: dial tcp 10.42.1.218:9000: connect: connection refused"
INFO auth/auth_client.go:71 Auth Service circuit breaker state changed: closed -> open
```

**Fix Applied (gitops commit `048de97`):**  
Added egress rules to `gitops/apps/customer/base/networkpolicy.yaml`:
- `auth-dev:8000` (HTTP) + `auth-dev:9000` (gRPC)  
- `order-dev:8008/9008` (order stats sync)  
- `notification-dev:8016/9016` (notifications)

**Verified:** `nc -zv 10.42.1.218 9000` → `open` after policy update. Login returns HTTP 200 with valid JWT.

---

## 🟡 P1 Issues (High)

### 1. [CONFIG] `AUTH_REGISTRY_CONSUL_ADDRESS: "127.0.0.1:8500"` — Dapr localhost dependency

Auth service registration uses `127.0.0.1:8500` (Dapr sidecar proxy → Consul). This is correct for the current architecture (Dapr routing), but **undocumented**. If Dapr sidecar does not initialize before auth process starts, registration silently fails.

- **Workaround**: Auth service has `AUTH_CONSUL_ADDRESS: "consul.infrastructure.svc.cluster.local:8500"` for discovery (separate from registration) — this is fine.
- **Action**: Document the Dapr→Consul registration pattern in service README.

### 2. [OBSERVABILITY] Auth pod has 18 restarts in 40h — Root cause uncleaned

After NetworkPolicy fix, customer login works. However auth pod has accumulated 18 restarts (`BackOff restarting` events seen). This may be caused by:
- User service health check timeout at startup (seen in logs: "User Service health check failed: DeadlineExceeded") → triggers liveness probe failure
- Need to investigate: does liveness probe fire before `initialDelaySeconds` elapses?

**Recommendation**: Increase `initialDelaySeconds` on liveness probe or make health check non-blocking at startup.

---

## 🔵 P2 Issues (Normal)

### 1. [DEPS] Auth imported `customer v1.1.4` while latest was `v1.2.3`

Fixed: `go get gitlab.com/ta-microservices/customer@latest` → upgraded to `v1.2.3`. Committed as `chore(auth): upgrade customer dep`.

### 2. [CODE] Comment noise with old-style markers

Internal comments use `P0 Fix:` / `P0.3:` / `P0.4:` inline prefixes (e.g. `token.go:236`, `server/grpc.go:23`) — these should be cleaned up to plain English descriptions per project commenting standards.

---

## ✅ Completed Actions

1. **[FIX]** Added egress NetworkPolicy rules to `customer/base/networkpolicy.yaml` — auth, order, notification namespaces → commit `048de97` (gitops)
2. **[FIX]** Upgraded auth `go.mod`: `customer v1.1.4 → v1.2.3`, `swagger-ui v0.0.1` → commit `376be62` (auth repo)
3. **[VERIFIED]** Consul health checks for auth: `10.42.1.218:9000 TCP connect Success`
4. **[VERIFIED]** Login endpoint: `HTTP 200` with valid access + refresh JWT tokens after fix
5. **[VERIFIED]** `go build ./...` clean, no replace directives, no bin/ directory

---

## 🌐 Cross-Service Impact

- **Services that import auth proto**: `customer` (v1.2.2), `gateway` (v1.2.2)
- **Services that consume auth events**: `customer` (subscribes to `auth.login` topic via Dapr)
- **Backward compatibility**: ✅ Preserved — no proto field changes in this review

---

## 🚀 Deployment Readiness

| Check | Status |
|-------|--------|
| Config/GitOps aligned | ✅ |
| Ports match PORT_ALLOCATION_STANDARD (HTTP:8000, gRPC:9000) | ✅ |
| Health probes configured | ✅ (but pod restarts need investigation) |
| Resource limits set | ✅ |
| Dapr annotations correct | ✅ (app-id: auth, app-port: 8000) |
| NetworkPolicy — customer egress to auth | ✅ Fixed |
| Migration safety | ✅ (goose migrations, job completed) |
| Circuit breaker in auth client | ✅ Present |

---

## Build Status

| Check | Status |
|-------|--------|
| `go build ./...` | ✅ 0 errors |
| `golangci-lint` | ⚠️ v1/v2 config mismatch (infrastructure, not code issue) |
| `bin/` Files | ✅ Not present |
| Replace directives | ✅ None found |
| Internal deps latest | ✅ customer v1.2.3, user v1.0.5, common v1.16.0 |

---

## Documentation

| Item | Status |
|------|--------|
| Service doc | ✅ Exists |
| README.md | ✅ Exists |
| CHANGELOG.md | ✅ Up to date (v1.1.8) |

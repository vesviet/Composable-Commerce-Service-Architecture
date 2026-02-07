# Gateway Service: Last Phase Readiness Checklist

This checklist covers critical steps to finalize the Gateway service for production.

## 🔴 Priority 1: Outstanding Tasks (Review Findings)
- [ ] **Missing Unit Tests**
  - [ ] **Action**: Add Unit Tests for Admin Routing (`internal/router/admin_route_test.go`) to verify path rewriting. (Currently MISSING)
- [ ] **Final Validation**
  - [ ] **Smoke Test**: Create `scripts/smoke-test.sh` and `docs/testing/SMOKE_TEST_GUIDE.md`. (Currently MISSING)
  - [ ] **Performance Check**: Create `scripts/performance-test.sh`. (Currently MISSING)

## 🟢 Priority 2: Completed & Verified (Code Quality)
- [x] **Refactor Monolithic Router**
  - [x] **Target**: `internal/router/kratos_router.go` (Refactored to ~565 lines).
  - [x] **Action**: Extract BFF handlers to `internal/bff/` (Verified `handler.go`).
  - [x] **Action**: Move Proxy logic (Verified `proxy_handler.go`).
- [x] **Reduce Logic Complexity**
  - [x] **Target**: `internal/router/auto_router.go` (Verified clean delegation).
  - [x] **Action**: Delegate URL construction and Header manipulation.
- [x] **Remove Dead Code**
  - [x] Scan for commented-out logic in `router` package (Verified clean).
- [x] **Unit Tests**
  - [x] **Action**: Implement `TestAuthMiddleware` (Verified in `kratos_middleware_test.go`).

## 🟢 Priority 3: Completed & Verified (Infrastructure & Security)
- [x] **Infrastructure Readiness (GitOps)**
  - [x] **Deployment Config Injection**: `deployment.yaml` mounts `gateway-config` ConfigMap.
  - [x] **Scalability (HPA)**: `hpa.yaml` created with CPU > 70% trigger (Min 3 / Max 10).
  - [x] **Ingress Security**: `ingress.yaml` configured with TLS (cert-manager, letsencrypt-prod).
  - [x] **Standardize Hostnames**: `gateway.yaml` uses FQDNs.

- [x] **Security Hardening**
  - [x] **Refactor CORS Middleware**: Optimized `kmm.corsHandler` handles Origin logic.
  - [x] **Header Injection Prevention**: `StripUntrustedHeaders` implemented.
  - [x] **Secrets Management**: No committed secrets found.
  - [x] **Environment Variables**: `jwt_secret` uses `${JWT_SECRET}`.

- [x] **Routing & Logic**
  - [x] **Admin Routes**: Explicitly defined in `gateway.yaml`.
  - [x] **Verify Authentication Fallback**: Implemented.

- [x] **Documentation & Config**
  - [x] **API Documentation**: `api/gateway/v1/gateway.proto` exists.
  - [x] **Config Strategy**: Code supports loading config from `/app/configs`.

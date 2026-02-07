# Gateway Service: Last Phase Readiness Checklist

This checklist covers critical steps to finalize the Gateway service for production.

## 🔴 Priority 1: Critical Code Remediation (Remaining)
- [ ] **Unit Tests for Middleware (Partial)**
  - [x] Create `internal/middleware/kratos_middleware_test.go`.
  - [x] Test `CORSMiddleware`: Verify allowed origin, blocked origin, and `OPTIONS` handling.
  - [ ] **Action**: Implement `TestAuthMiddleware`. Currently SKIPPED ("needs proper JWT validator mocking").

## 🟢 Priority 2: Completed Code Fixes (Verified)
- [x] **Refactor CORS Middleware**
  - [x] Modify `CORSMiddleware` to use the optimized `kmm.corsHandler`.
  - [x] Remove redundant inline CORS logic.
  - [x] Verify `OPTIONS` preflight requests handling.
- [x] **Verify Authentication Fallback**
  - [x] Code implements fallback to Auth Service if JWT signature validation fails.
- [x] **Hardening: Header Injection Prevention (P0)**
  - [x] `StripUntrustedHeaders` implemented and called before validation.
- [x] **API Documentation**
  - [x] `api/gateway/v1/gateway.proto` exists.
- [x] **Deployment Config Injection**
  - [x] Code supports loading config from `/app/configs` (via Dockerfile `CMD`).

## 🧹 Priority 3: Code Maintainability & Cleanup (New)
- [ ] **Refactor Monolithic Router**
  - [ ] **Target**: `internal/router/kratos_router.go` (~1200 lines).
  - [ ] **Action**: Extract BFF handlers to `internal/bff/` (e.g., `product_handler.go`, `admin_handler.go`).
  - [ ] **Action**: Move Proxy logic to `internal/proxy/`.
  - [ ] **Action**: Add Unit Tests for Admin Routing (`internal/router/admin_route_test.go`) to verify path rewriting.
- [ ] **Reduce Logic Complexity**
  - [ ] **Target**: `internal/router/auto_router.go` (Mixed URL parsing & Forwarding).
  - [ ] **Action**: Delegate URL construction and Header manipulation to dedicated helper structs.
- [ ] **Remove Dead Code**
  - [ ] Scan for commented-out logic in `router` package and remove.

## 🧪 Priority 4: GitOps & Configuration (Verified)
- [x] **Standardize Service Hostnames**
  - [x] `gateway.yaml` uses FQDNs (e.g., `auth-service.core-business.svc.cluster.local`).
- [x] **Review Cross-Domain (CORS) Configuration**
  - [x] `allow_origins` includes production domains and removes wildcards (mostly).
- [x] **Environment Variables**
  - [x] `jwt_secret` uses `${JWT_SECRET}`.

## 🛡️ Priority 5: Enterprise Security & Resilience
- [ ] **Scalability: Distributed Rate Limiting**
  - [ ] Enforce Redis configuration for Rate Limiting in `gateway.yaml` for production profile.
- [ ] **Observability: Global Sanitization**
  - [ ] Register `ResponseSanitizerMiddleware` in global middleware chain.

## 🏭 Priority 6: Infrastructure Readiness (GitOps Pending)
- [ ] **Deployment Config Injection**
  - [ ] **Action**: Update `deployment.yaml` to mount `gateway-config` ConfigMap.
- [ ] **Scalability (HPA)**
  - [ ] Create `hpa.yaml` with CPU > 70% trigger.
- [ ] **Ingress Security**
  - [ ] Configure TLS (cert-manager).

## 🟡 Priority 7: Final Verification
- [ ] **Smoke Test**
  - [ ] Verify `/health`, public endpoints, and protected endpoints.
- [ ] **Performance Check**
  - [ ] Run load test on Gateway.

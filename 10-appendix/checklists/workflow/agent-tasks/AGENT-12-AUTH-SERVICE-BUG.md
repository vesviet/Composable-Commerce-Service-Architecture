# AGENT-12: Fix Auth Service Internal Error (Context Deadline Exceeded)

> **Created**: 2026-03-26
> **Priority**: P0
> **Sprint**: Tech Debt Sprint
> **Services**: `auth`, `user`
> **Estimated Effort**: 1-2 days
> **Source**: QA Testing / E-Commerce Flows (Admin Login Failure)

---

## 📋 Overview

During manual QA testing of the E-Commerce Admin flow (`https://admin.tanhdev.com/`), logging in with `admin@example.com` results in a persistent 500 Internal Server Error.

Analysis of the `auth` service logs reveals that it fails to validate user credentials because its gRPC call to the `user` service times out (`context deadline exceeded`). Additionally, there is an ongoing warning about Consul health checks failing because the check ID is unknown to the consul server.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix `auth` service gRPC connection to `user` service

**File**: `auth/internal/infrastructure/grpc/user/user_client.go` (or similar dependent client configuration)
**Risk**: Admin login is completely broken. The `auth` service cannot communicate with the `user` service, causing authentication for admins and sellers to crash.
**Problem**: The `user_client` in the auth service is hitting a deadline exceeded error. This suggests the connection is not being established correctly, possibly due to a service discovery misconfiguration or improper gRPC dialing.

**Instructions**:
1. Check the `user_client.go` in `auth` to see how it dials.
2. Verify if Consul service discovery is returning the correct address or if the `grpc` timeout is too aggressive.
3. Fix the connection implementation to correctly find and communicate with the `user` service.

**Validation**:
```bash
# Validate that the auth service can reach user service
curl -s -X POST http://localhost:8001/api/v1/auth/login -d '{"email":"admin@example.com","password":"Admin123!","user_type":"admin"}'
```

### [x] Task 2: Fix `auth` service Consul TTL heartbeat

**Risk**: The `auth` service continuously logs `[Consul] update ttl heartbeat to consul failed! err=Unexpected response code: 404`. If Consul health checks fail, the service might be deregistered, affecting upstream routing.
**Problem**: The service is likely registering with one agent (or server) and attempting to heartbeat to another, or passing an invalid check ID (`service:auth-579bb8dc8c-2dprh`).

**Instructions**:
1. Review the Consul registration logic in `auth/internal/pkg/registry` or similar.
2. Ensure the TTL heartbeat uses the exact Check ID returned during registration.
3. Compare with a healthy service (like `catalog` or `customer`) to align the consul pattern.

**Validation**:
```bash
kubectl logs -n auth-dev deploy/auth | grep -i consul
# Ensure no 404 unknown check ID errors are looping after restart
```

---

## 🔧 Pre-Commit Checklist

```bash
cd auth && wire gen ./cmd/server/ ./cmd/worker/
cd auth && go build ./...
cd auth && go test -race ./...
```

---

## 📝 Commit Format

```
fix(auth): fix gRPC connection to user service and consul checks

- fix: user_client connection yielding deadline exceeded
- fix: consul ttl heartbeat 404 unknown check ID

Closes: AGENT-12
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Admin login works successfully | Log into `https://admin.tanhdev.com` | |
| Consul logs no longer spam 404 errors | Check `kubectl logs -n auth-dev deploy/auth` | |

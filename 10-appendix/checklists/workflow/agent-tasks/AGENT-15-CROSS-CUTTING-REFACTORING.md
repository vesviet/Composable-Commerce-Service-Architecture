# AGENT-15: Cross-Cutting Concerns Hardening

> **Created**: 2026-03-16
> **Priority**: P0/P1
> **Sprint**: Tech Debt Sprint
> **Services**: `payment`, `analytics`, `user`
> **Source**: Meeting Review - 15. Cross-Cutting Concerns

---

## 📋 Overview
Refactor locally reinvented patterns back to the `common` packages to ensure consistency, telemetry fidelity, and bug fix alignment. Specifically targeting local idempotency modules in `payment` and local circuit-breakers/metric modules in `analytics` and `user`.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Migrate Payment Idempotency to Common
**File**: `payment/internal/biz/common/idempotency.go` (and related data layer)
**Risk**: Missed bug fixes from the global locking/cleanup mechanism in `common/idempotency`.
**Fix**: 
- Remove the local implementation of idempotency.
- Convert `payment` biz and data layers to use `gitlab.com/ta-microservices/common/idempotency/event_processing.go` or `redis_idempotency.go` as appropriate.
- Verify through building the service.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 2: Standardize Analytics Circuit Breaker
**File**: `analytics/internal/pkg/circuitbreaker/circuit_breaker.go`
**Risk**: Breaking global Prometheus observability for upstream API faults.
**Fix**:
- Remove the massive local circuit breaker.
- Replace it in `analytics/internal/service/marketplace/external_api_integration.go` (or wherever used) with `common/client/circuitbreaker` logic if manual wrapping is needed, OR rely on standard Kratos HTTP/gRPC middleware.

### [ ] Task 3: Standardize User Service Circuit Breaker
**File**: `user/internal/client/circuitbreaker/circuit_breaker.go`
**Risk**: Reinventing the wheel; metric mismatch.
**Fix**:
- Remove the local Circuit Breaker logic and wire up the `common` variant.

### [ ] Task 4: Standardize User Service Metrics
**File**: `user/internal/observability/prometheus/metrics.go`
**Risk**: Redundant metric initialization causing panics or uncollected metrics.
**Fix**:
- Switch Prometheus metric definitions to use `common/observability/metrics`.

---

## 🔧 Pre-Commit Checklist

```bash
cd payment && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
cd analytics && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
cd user && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
```

---

## 📝 Commit Format

```
refactor(cross-cutting): migrate bespoke patterns to common packages

- refactor: migrate payment idempotency to common
- refactor: standardize circuit breakers in analytics and user
- refactor: standardize prometheus metrics in user service

Closes: AGENT-15
```

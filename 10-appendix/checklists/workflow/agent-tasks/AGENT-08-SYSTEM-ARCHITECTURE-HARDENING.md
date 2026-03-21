# AGENT-08: System-Wide Architecture & Infrastructure Hardening

> **Created**: 2026-03-21
> **Priority**: P0
> **Sprint**: Tech Debt / Reliability Sprint
> **Services**: `gitops`, `gateway`
> **Estimated Effort**: 1-2 days
> **Source**: System-Wide 5M Rounds Meeting Review

---

## 📋 Overview

The recent system-wide architectural review highlighted critical platform-level configurations that pose extreme severe risks during Flash Sales (e.g., 11.11). Most notably, Dapr's Resiliency policies completely missed the real microservices, rendering Circuit Breakers and Retries inactive. Additionally, the Gateway has a hazardous 3-second downstream dependency for Auth validation and masks missing `Idempotency-Key` headers via auto-generation.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Enable Dapr Resiliency for Real Microservices

**File**: `gitops/components/dapr-resiliency/resiliency.yaml`
**Lines**: 47-52
**Risk**: Service-to-service calls (e.g., Checkout scaling to Order/Payment) have zero Circuit Breaking or Retry protection, resulting in cascading failures during heavy load.
**Problem**: The `targets.apps` parameter explicitly (and only) targets `placeholder`, meaning all production services silently bypass the resiliency policies.
**Fix**:
Change the configuration to explicitly target all actual services (or omit `apps` to target all, depending on Dapr version).
```yaml
# BEFORE:
  targets:
    apps:
      placeholder:
        retry: serviceRetry
        timeout: serviceTimeout
        circuitBreaker: defaultCB

# AFTER:
  targets:
    apps:
      checkout:
        retry: serviceRetry
        timeout: serviceTimeout
        circuitBreaker: defaultCB
      payment:
        retry: serviceRetry
        timeout: serviceTimeout
        circuitBreaker: defaultCB
      order:
        retry: serviceRetry
        timeout: serviceTimeout
        circuitBreaker: defaultCB
      catalog:
        retry: serviceRetry
        timeout: serviceTimeout
        circuitBreaker: defaultCB
# Add remaining services (inventory, fulfillment, return, etc)
```

**Validation**:
```bash
kubectl apply -f gitops/components/dapr-resiliency/resiliency.yaml --dry-run=local
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 2: Mitigate Synchronous Auth Bottleneck in Gateway

**File**: `gateway/internal/middleware/validate_access.go`
**Lines**: 87-103
**Risk**: Gateway makes a synchronous 3-second gRPC `ValidateAccess` call for *every* incoming request. If the User service stutters under load, the Gateway will drag the entire ecommerce platform down.
**Problem**: Hard dependency on User service in the critical hot path of Gateway.
**Fix**:
Refactor the middleware to either:
1. Parse the roles natively from the JWT (Stateless Auth) without calling the User service.
2. Or strictly limit the `ValidateAccess` timeout to `500ms` and configure a Gateway Circuit Breaker specifically around the `UserClient.ValidateAccess` call.
```go
// Proposed change (Timeout Reduction Strategy):
validateCtx, validateCancel := context.WithTimeout(r.Context(), 500*time.Millisecond)
defer validateCancel()

// Wrap with custom fast-fail circuit breaker (or monitor via Prometheus)
```

**Validation**:
```bash
cd gateway && go build ./...
cd gateway && go test ./internal/middleware... -v
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 3: Stop Gateway Idempotency Auto-Generation for Mutating Requests

**File**: `gateway/internal/router/proxy_handler.go`
**Lines**: 62-69
**Risk**: By auto-generating an `Idempotency-Key` when the client omits it, the Gateway prevents true client idempotency. If a client retries due to a network drop, they issue a new request, get a new UUID from Gateway, and double-charge the card.
**Problem**: Gateway enforces `isMutation` by creating a key (`gw-UUID`) instead of rejecting the request.
**Fix**:
For critical endpoints (like Checkout, Payment), the Gateway should `400 Bad Request` if the client fails to provide an `Idempotency-Key`.
```go
// BEFORE:
if isMutation && r.Header.Get("Idempotency-Key") == "" {
    r.Header.Set("Idempotency-Key", generateIdempotencyKey())
}

// AFTER:
if isMutation && r.Header.Get("Idempotency-Key") == "" {
    // Check if path requires strict idempotency
    if strings.Contains(r.URL.Path, "/checkout") || strings.Contains(r.URL.Path, "/payments") {
        rm.handleServiceError(w, r, errors.New("Missing Idempotency-Key Header"), pattern.Service)
        return
    }
    // Only fallback for non-critical legacy apps
    r.Header.Set("Idempotency-Key", generateIdempotencyKey())
}
```

**Validation**:
```bash
cd gateway && go build ./...
```

---

## 🔧 Pre-Commit Checklist

```bash
cd gateway && go build ./...
cd gateway && go test ./...
kubectl auth can-i update resiliency -n microservices # Verify yaml deployment capability
```

---

## 📝 Commit Format

```text
fix(gitops): enable Dapr resiliency circuit breakers for all production microservices
perf(gateway): reduce ValidateAccess timeout to 500ms to prevent cascading failures
refactor(gateway): enforce explicit client Idempotency-Key for checkout and payment paths

Closes: AGENT-08
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Dapr Circuit Breakers Enabled For All Services | Inspect `resiliency.yaml` diff | |
| Gateway Auth does not block > 500ms | Load test `gateway` with injected latency | |
| Checkout API rejects missing Idempotency | `curl -X POST /api/v1/checkout` → HTTP 400 | |

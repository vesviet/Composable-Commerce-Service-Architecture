# AGENT-14: Fix Checkout Service Internal Error (Missing Authentication Context for Warehouse gRPC)

> **Created**: 2026-03-26
> **Priority**: P0
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`, `warehouse`
> **Estimated Effort**: 1 day
> **Source**: QA Testing / E-Commerce Flows (Checkout Flow Failure)

---

## 📋 Overview

During manual QA testing of the E-Commerce Cart & Checkout flow (`https://frontend.tanhdev.com/`), clicking the "Place Order" button results in a 500 Internal Server Error, preventing order creation.

Analysis of the `checkout` service logs shows that the 500 error on the `/confirm` endpoint is triggered by a downstream gRPC failure when requesting data from the `warehouse` service:
```
GetWarehouse failed for warehouse <uuid>: rpc error: code = Unauthenticated desc = missing authentication context
```

The `checkout` service is failing to forward the JWT or machine-to-machine authentication token in the context metadata when calling the `warehouse` service, causing the warehouse service's interceptor to reject the call.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix `checkout` -> `warehouse` gRPC client authentication context

**File**: `checkout/internal/infrastructure/grpc/client/warehouse.go` (or similar)
**Risk**: Users cannot complete their purchases. The checkout process is completely blocked.
**Problem**: The checkout service is making a gRPC call without attaching credentials or authorization headers. The `warehouse` service strictly enforces authentication.

**Instructions**:
1. Check the gRPC dialing logic in the `checkout` service for the `warehouse_client`.
2. Ensure that when calling `GetWarehouse` (and any other methods), the context is wrapped with the correct JWT token from the incoming HTTP/gRPC request, or a valid machine-to-machine server token is injected.
3. Use the common library's `metadata.AppendToOutgoingContext` or the provided auth interceptor.

**Validation**:
```bash
# Validate unit test connects without unauthenticated error
cd checkout && go test ./internal/infrastructure/grpc/client/... -run TestWarehouseClient -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd checkout && wire gen ./cmd/server/ ./cmd/worker/
cd checkout && go build ./...
cd checkout && go test -race ./...
```

---

## 📝 Commit Format

```
fix(checkout): forward auth context in warehouse gRPC client

- fix: missing authentication context error breaking checkout confirm flow

Closes: AGENT-14
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Checkout confirms successfully | Proceed through checkout on frontend and hit Place Order | |
| No Unauthenticated errors in log | Check `kubectl logs -n checkout-dev deploy/checkout` | |

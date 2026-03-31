# AGENT-10: Connect Return Domain & Fix Customer Refund Flow

> **Created**: 2026-03-31
> **Priority**: P0
> **Sprint**: Bugfix Sprint
> **Services**: `gateway`, `frontend`, `order`
> **Estimated Effort**: 1 day
> **Source**: Automation QA Run Flow 10 (Return API 404 Bug)

---

## 📋 Overview

The `return` microservice is already functionally complete but disconnected from the Gateway. The customer-facing Return UI on the Frontend is currently sending `POST /api/v1/orders/{orderId}/return-request` which results in a `404 Not Found`.

This task aims to:
1. Connect the `return-service` instance to the `gateway` routing rules (`gateway.yaml`).
2. Re-wire the `frontend` `lib/api/order-api.ts` to execute Return operations against the newly routed `POST /api/v1/returns` endpoint.
3. Clean up documented comment confusion inside Kratos Protobuf definitions on the `order` side, directing future devs to the `return` Domain.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Expose `return-service` via API Gateway

**File**: `gateway/configs/gateway.yaml`
**Lines**: Under `services:` and `routing:` blocks
**Risk**: Without this, the entire Return business logic remains isolated and useless.
**Problem**: The `gateway` doesn't recognize the `return-service` service nor does it forward `/api/v1/returns` routes.
**Fix**:
Add the service definition under `services:` key:
```yaml
// AFTER:
  return:
    <<: *service-defaults
    name: return-service
    host: return-service
    protocol: grpc
    grpc_port: 81
    health_path: /health
    headers:
      X-Gateway-Version: v1.0.0
      X-Service-Name: return-service
```
Add routing definitions under `routing.patterns`:
```yaml
// AFTER:
    # Return service routes
    - prefix: "/api/v1/returns"
      service: "return"
      strip_prefix: false
      middleware: *middleware-authenticated
```

**Validation**:
```bash
cd gateway && make test
```

### [ ] Task 2: Re-Link Frontend Return API Call

**File**: `frontend/src/lib/api/order-api.ts`
**Lines**: ~52
**Risk**: The Next.js client is currently sending broken URLs derived from legacy mocks.
**Problem**: `submitReturnRequest` hardcodes `/api/v1/orders/${orderId}/return-request`.
**Fix**:
Modify the API call to point directly to the REST endpoint `POST /api/v1/returns`.
```typescript
// BEFORE:
export const submitReturnRequest = async (orderId: string, body: any) => {
    const { data } = await apiClient.post(`/api/v1/orders/${orderId}/return-request`, body);
    return data;
};

// AFTER:
export const submitReturnRequest = async (orderId: string, body: any) => {
    // Return Request Expects order_id in the body schema based on protobuf:
    const payload = { ...body, order_id: orderId, customer_id: body.customer_id || "" };
    const { data } = await apiClient.post(`/api/v1/returns`, payload);
    return data;
};
```

**Validation**:
```bash
cd frontend && npm run lint
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 3: Clean Deprecated Protobuf Comments in Order Domain

**File**: `order/api/order/v1/order.proto`
**Lines**: ~136
**Risk**: Future devs might read `// Return request methods removed - return domain not yet implemented` and mistakenly think Returns don't exist in the company.
**Problem**: Stale docblock from before `return-service` was created.
**Fix**:
Replace the comment with a clear pointer towards the `return` service.
```proto
// BEFORE:
  // Return request methods removed - return domain not yet implemented
  // These will be added when return usecase is implemented in internal/biz/return/

// AFTER:
  // Return request domain is strictly orchestrated by the `return-service`.
  // Please see gitlab.com/ta-microservices/return/api/return/v1/return.proto for Return architecture.
```

**Validation**:
```bash
cd order && make api
```

---

## 🔧 Pre-Commit Checklist

```bash
cd gateway && go build ./...
cd frontend && npm run build
```

---

## 📝 Commit Format

```
fix(infrastructure): connect Return domain and UI

- fix(gateway): integrate return-service into api mesh routing
- fix(frontend): fix return-request payload structure and endpoint mapping
- docs(order): update proto definitions dropping stubbed return hints

Closes: AGENT-10
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Gateway routes traffic to `return-service` | Send unauthenticated HTTP POST to `gateway.microservices.local/api/v1/returns`, it should yield `401 Unauthorized`, not `502 Bad Gateway`. | |
| Customer interface successfully processes returns | Login via Next.js Customer portal, submit Return on Order `ORD-X`, expect success toast message in UI. | |

# AGENT-04: Payment Service Stripe Validation Crash Fix

> **Created**: 2026-04-06
> **Priority**: P0
> **Sprint**: Hardening Sprint
> **Services**: `payment`, `frontend`
> **Estimated Effort**: 1 day
> **Source**: Browser Subagent QA Manual Testing on `frontend.tanhdev.com`

---

## 📋 Overview

During manual QA testing of the Stripe checkout flow, the frontend checkout crashed consistently when selecting "Credit/Debit Card". The `POST /api/v1/payments` endpoint returned a `400 VALIDATION_ERROR` due to multiple mismatched validation constraints in the `payment` microservice:
1. The deprecated `amount` float field was ignored in favor of hardcoded `0`, causing the "amount must be positive" validation to fail.
2. The `customer_id` was mandatory in validation, but not injected from context or included in the frontend payload.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix `amount` floating point backwards compatibility mapping

**File**: `payment/internal/service/payment.go`
**Lines**: 85, 307, 434 (approx)
**Risk**: Payments relying on the deprecated `amount` field instead of `amount_money` fail with `VALIDATION_ERROR` (0 amount).
**Problem**: The service passes `0` to `parseAmountProto` instead of using the struct's actual `.Amount` float field when `.AmountMoney` is nil.

**Fix**:
Replace hardcoded `0` with the actual mapped value:
```go
// BEFORE:
parsedAmount := parseAmountProto(0, req.AmountMoney)
parsedCaptureAmount := parseAmountProto(0, req.AmountMoney)
parsedRefundAmount := parseAmountProto(0, req.AmountMoney)

// AFTER:
parsedAmount := parseAmountProto(req.Amount, req.AmountMoney)
// Same for capture and refund endpoints:
parsedCaptureAmount := parseAmountProto(req.Amount, req.AmountMoney)
parsedRefundAmount := parseAmountProto(req.Amount, req.AmountMoney)
```

**Validation**:
```bash
cd payment && go test ./internal/service/... -v
```

### [x] Task 2: Inject `customer_id` from Authentication Context

**File**: `payment/internal/service/payment.go`
**Lines**: 80-92 (ProcessPayment signature)
**Risk**: Authenticated checkout flows via Gateway fail missing `customer_id` during strict UUID validation.
**Problem**: Frontend requests via Next.js do not send an explicit `customer_id` field in the payload, relying on user session. `payment` service strictly validates `customer_id` from the payload before extracting it from the Auth Claims.

**Fix**:
Extract the token context and default `req.CustomerId` into the proto request before feeding it into the Validator. Do this for `ProcessPayment`, `CapturePayment`, and `ProcessRefund`:
```go
// BEFORE:
// Missing context extraction before validation layer
if err := commonValidation.NewValidator().
    UUID("customer_id", req.CustomerId).

// AFTER:
import "gitlab.com/ta-microservices/common/auth"

func (s *PaymentService) ProcessPayment(...) {
...
    if req.CustomerId == "" {
        if claims, ok := auth.FromContext(ctx); ok {
            req.CustomerId = claims.Subject
        }
    }
    
    if err := commonValidation.NewValidator().
        UUID("order_id", req.OrderId).
        UUID("customer_id", req.CustomerId).
        // ...
```

**Validation**:
```bash
cd payment && go test -race ./...
```

### [x] Task 3: Ensure `order_id` is correctly supplied by Frontend Stripe API

**File**: `frontend/src/lib/api/payment-api.ts`
**Lines**: 9-14
**Risk**: If `checkoutState.draft_order.id` implies `orderId` is missing, validation fails.
**Problem**: Validation demands `UUID("order_id", req.OrderId)`. Ensure `order_id` isn't silently swallowed in frontend if undefined.

**Fix**:
Add a check in `PaymentStep.tsx` or `StripePayment.tsx` to warn if `orderId` is missing before initializing `createStripeIntent`. If it's undefined, block initialization or handle grace.
```typescript
// Add front-end defensive programming check before POST to avoid unhandled validation errors
if (!orderId) {
    throw new Error("Missing Order ID");
}
```

**Validation**:
```bash
cd frontend && npm run build
```

---

## 🔧 Pre-Commit Checklist

```bash
cd payment && wire gen ./cmd/server/ ./cmd/worker/
cd payment && go build ./...
cd payment && go test -race ./...
cd payment && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(payment): fix Stripe validation errors during payment initialization

- fix: map deprecated float amount in parseAmountProto
- fix: extract customer_id from auth claims when missing from request
- fix(frontend): add defensive checks for missing order_id during Stripe initialization

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Payment initialization parses float amount correctly | `payment` service unit tests or manual checkout without `validation_error` | |
| Checkout flow accepts implicitly identified Customer | Perform checkout as `customer1000@example.com`, checkout initializes successfully | |

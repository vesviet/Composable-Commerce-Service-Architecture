# 🚀 ORDER & CHECKOUT SERVICE REFACTOR PLAN

**Date**: 2026-01-25
**Status**: Analysis Complete
**Ref**: `docs/TEAM_LEAD_CODE_REVIEW_GUIDE.md`

## 📊 EXECUTIVE SUMMARY

Based on the latest code review, significant progress has been made since the previous audit. Critical P0 issues like **Transaction Management** and **Idempotency** in the Checkout service have been **resolved**. The focus now shifts to completing unimplemented features, improving test coverage, and refining strict architectural boundaries.

### ✅ RESOLVED / VERIFIED FIXED
- **[CHECKOUT] Transaction Management**: Implemented in `ConfirmCheckout` using `uc.tm.WithTransaction`.
- **[CHECKOUT] Idempotency**: Implemented `generateCheckoutIdempotencyKey` and `idempotencyService` check.
- **[CHECKOUT] Duplicate Domain**: No duplicate `order` domain found in `checkout/internal/biz`.
- **[CHECKOUT] Outbox Repository**: Fully implemented in `checkout/internal/data/outbox_repo.go`.
- **[ORDER] Hardcoded Tokens**: No hardcoded service tokens found. Admin check uses config.

---

## 🚩 PENDING ISSUES (OPEN)

### 🚨 P1 - HIGH PRIORITY (Functional & Quality Gaps)

#### 1. [CHECKOUT] Unimplemented `PreviewOrder` Endpoint
- **Location**: `checkout/internal/service/checkout.go`
- **Issue**: `PreviewOrder` returns `fmt.Errorf("PreviewOrder not yet implemented")`.
- **Requirement**: Implement logic to calculate totals without creating a persistent session (or using a temporary one).

#### 2. [CHECKOUT] Missing Integration Tests
- **Location**: `checkout/`
- **Issue**: No dedicated `test` directory or integration tests found (unlike `order/test`).
- **Requirement**: Add Testcontainers-based integration tests for `ConfirmCheckout` flow.

#### 3. [ORDER] Service Layer Complexity (`validateOrderStatusUpdateAuthorization`)
- **Location**: `order/internal/service/order.go`
- **Issue**: `validateOrderStatusUpdateAuthorization` contains business/policy logic (checking specific status transitions allowed for business ops).
- **Requirement**: Move policy logic to `internal/biz/order/policy.go` or similar domain service. The Service layer should only orchestrate.

### 🔵 P2 - MEDIUM PRIORITY (Maintenance & Refactoring)

#### 4. [ORDER] Input Validation in Service Layer
- **Location**: `order/internal/service/order.go` (CreateOrder)
- **Issue**: Extensive inline validation (approx 80 lines).
- **Requirement**: Extract to `internal/biz/order/validator.go` to keep Service layer clean and readable.

#### 5. [ALL] Verify Metrics/Tracing Coverage
- **Location**: `checkout/internal/biz/checkout/usecase.go`
- **Issue**: `metricsService` and `alertService` fields exist but need verification of usage in all critical paths.
- **Requirement**: Ensure all critical paths (Checkout, Payment, Order Creation) have proper RED metrics and Tracing spans.

---

## 📅 IMPLEMENTATION PLAN

### Phase 1: Feature Completion (Week 1)
- [ ] Implement `PreviewOrder` in Checkout Service.
- [ ] Verify Outbox Pattern End-to-End (ensure worker processes events).

### Phase 2: Quality Assurance (Week 1-2)
- [ ] Add Integration Tests for Checkout (`TestConfirmCheckout`, `TestPreviewOrder`).
- [ ] Add Unit Tests for `order` validation logic.

### Phase 3: Refactoring (Week 2)
- [ ] Refactor Order Service Validation to Biz layer.
- [ ] Refactor Order Authorization Logic to Policy layer.

---

## 🔍 NOTABLE CODE SMELLS (For Future Attention)
- **Distributed Transaction Safety**: `ConfirmCheckout` calls `orderClient.CreateOrder`. This is a synchronous gRPC call within a local transaction. If the order creation succeeds but the local commit fails, we have an orphan order.
    - *Recommendation*: Ensure `CreateOrder` is idempotent (it involves `orderReq.CartSessionID` which I verified is passed). Consider strictly using Outbox for Order Creation trigger if higher reliability is needed.

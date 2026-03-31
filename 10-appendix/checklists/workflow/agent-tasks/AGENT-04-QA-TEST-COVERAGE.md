# AGENT-04: Complete QA System Test Coverage (Auto)

> **Created**: 2026-03-31
> **Priority**: P1 (High Priority)
> **Sprint**: Tech Debt Sprint
> **Services**: `qa-auto`
> **Estimated Effort**: 3-5 days
> **Source**: QA Coverage Review against 15 Ecommerce Platform Flows

---

## 📋 Overview

The `qa-auto` suite has solid basic coverage for Customer, Catalog, Checkout, and Fulfillment flows. However, entire domains (Seller/Merchant, Admin & Operations, Analytics & Reporting, Cross-Cutting concerns) and complex edge cases (Promotions stacking, ESCROW payment via Webhooks) are completely missing. This task batch assigns the implementation of the missing end-to-end flows.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Complete "15. Cross-Cutting Concerns" Tests
**File**: `qa-auto/tests/cross-cutting/security-idempotency.spec.ts`
**Risk**: Lack of rate limit validation or double-submission guards can lead to double charges or API abuse.
**Problem**: The `qa-auto` suite has zero test coverage for Idempotency locks (Checkout double click) or JWT access manipulation.
**Fix**:
Implement `security-idempotency.spec.ts`:
- Ensure Checkout API deduplicates requests with the same session lock.
- Verify rate limiting returns 429 Too Many Requests.
- Verify JWT manipulation results in 401 Unauthorized.

**Validation**:
```bash
cd qa-auto && npx playwright test tests/cross-cutting/
```

### [ ] Task 2: Complete "7. Payment Flows" - Webhooks & Escrow Edge Cases
**File**: `qa-auto/tests/payment-flows/webhook-escrow.spec.ts`
**Risk**: Relying purely on frontend checkout payment misses the async server-to-server webhook path and escrow mechanics.
**Problem**: The suite only tests `admin-payment-settings` and `frontend-checkout-payment`. It misses simulating third-party callbacks.
**Fix**:
Implement `webhook-escrow.spec.ts`:
- Build a mock callback injector to simulate Dapr/webhook payment success.
- Test Escrow rules (funds held until order completion).
- Test refund-to-wallet behavior.

**Validation**:
```bash
cd qa-auto && npx playwright test tests/payment-flows/webhook-escrow.spec.ts
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Complete "12. Seller / Merchant Flows"
**File**: `qa-auto/tests/seller-merchant/seller-onboarding.spec.ts`
**Risk**: Marketplace mechanics are broken if seller onboarding or B2B features regress.
**Problem**: Folder `seller-merchant` doesn't exist. There are no tests for document review or B2B/wholesale pricing.
**Fix**:
Implement `seller-onboarding.spec.ts` and `b2b-wholesale.spec.ts`:
- Test the KYC document upload flow.
- Test the admin queue for reviewing applications.
- Test net-30 terms and bulk/quantity pricing break triggers.

**Validation**:
```bash
cd qa-auto && npx playwright test tests/seller-merchant/
```

### [ ] Task 4: Complete "13. Admin & Operations Flows" - RBAC
**File**: `qa-auto/tests/admin-operations/rbac-permissions.spec.ts`
**Risk**: Flawed permission enforcement allows unauthorized CS agents to override critical configs.
**Problem**: Missing RBAC validation tests across the admin interfaces.
**Fix**:
Implement `rbac-permissions.spec.ts`:
- Verify an agent with "View Only" cannot save changes.
- Verify Privilege Escalation Protection blocks self-assigning Admin roles.

**Validation**:
```bash
cd qa-auto && npx playwright test tests/admin-operations/
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 5: Complete "4. Pricing, Promotion & Tax Flows" Edge Cases
**File**: `qa-auto/tests/pricing-promotion-tax/promotion-stacking.spec.ts`
**Risk**: Vouchers and discounts stacking incorrectly can result in negative order totals.
**Problem**: Missing tests for stacking logic (e.g., checking if max 1 voucher + 1 discount is properly maintained).
**Fix**:
Implement `promotion-stacking.spec.ts` and `tax-breakdown.spec.ts`:
- Cover overlapping campaigns to verify priority selection logic.
- Verify checkout Tax Breakdown inclusive format.

**Validation**:
```bash
cd qa-auto && npx playwright test tests/pricing-promotion-tax/promotion-stacking.spec.ts
```

---

## 🔧 Pre-Commit Checklist

```bash
cd qa-auto
npm run lint
npm run build
npx playwright test
```

---

## 📝 Commit Format

```
test(qa-auto): add missing 12-15 coverage domains

- test: add cross-cutting security tests
- test: add payment webhook simulations
- test: implement seller/merchant flows
- test: add admin rbac overrides

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Security/Idempotency covered | `playwright test tests/cross-cutting/` | |
| Webhooks & Escrow simulated | `playwright test tests/payment-flows/` | |
| Seller flows successfully run | `playwright test tests/seller-merchant/` | |
| Admin RBAC overrides blocked | `playwright test tests/admin-operations/` | |
| Promo stacking calculates OK | `playwright test tests/pricing-promotion-tax/` | |

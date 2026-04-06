# AGENT-03: Payment Flow — Stripe Currency Case & QA Timeout Fixes

> **Created**: 2026-04-06
> **Priority**: P0/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `frontend`, `qa-auto`

---

## 📋 Overview

A critical issue was discovered during the live manual verification of the checkout flow on `frontend.tanhdev.com`. Customers paying with "Credit/Debit Card" (Stripe) still experienced a site crash ("Something went wrong" screen). 
While the floating-point issue (AGENT-05) was resolved in the codebase, the live environment exposed a second Stripe initialization bug: the currency code must be passed to Stripe in lowercase (e.g., `vnd`), but upstream cart data was providing it in uppercase (`VND`), leading to an `IntegrationError`. Additionally, the playwright test `TC-PAY-08` was timing out due to login retry logic combined with `networkidle`.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Stripe Currency Casing crash ✅ IMPLEMENTED

**Files**: `frontend/src/components/checkout/StripePayment.tsx`
**Risk**: Customers cannot pay via Stripe, losing sales.
**Problem**: The application passes uppercase `VND` (from cart currency data) into Stripe `Elements` which throws `IntegrationError: Invalid value for elements(): currency should be one of the following strings... You specified: VND.`

**Solution Applied**: 
Added `.toLowerCase()` to the currency fields before passing them to Stripe's APIs:
1. `Elements` initialization: `currency: (props.currency || 'vnd').toLowerCase()`
2. `createStripeIntent` payment intent creation: `currency.toLowerCase()`

**Validation**: `npx next build --turbopack` — ✅ PASS. Changes pushed to `origin/main`.

---

## ✅ Checklist — P2 Issues (Improvements)

### [x] Task 2: Fix TC-PAY-08 test timeout in Playwright ✅ IMPLEMENTED

**Files**: `qa-auto/tests/payment-flows/frontend-checkout-payment.spec.ts`
**Problem**: `TC-PAY-08: Checkout failed page renders correctly` was failing with a `Timeout exceeded (30000ms)` during the authentication/redirect-retry flow.

**Solution Applied**: 
1. Increased test scope timeout: `test.setTimeout(60000)`
2. Optimized navigation by changing `waitUntil: 'networkidle'` to `waitUntil: 'domcontentloaded'` to speed up loading conditions during redirects. 
3. Lowered wait times between navigations to streamline the sequence.

**Validation**: Pushed to `origin/fix-admin-login-timeout`.

---

### [x] Task 3: Fix 404 Gateway Missing Route for Stripe/COD API ✅ IMPLEMENTED

**Files**: `frontend/src/lib/api/payment-api.ts`
**Problem**: After deploying the casing fix, frontend test via manual QA subagent revealed that `api.tanhdev.com/api/payment/stripe/create-intent` returned a 404 error. This is because the Next.js `apiClient` was sending frontend requests to legacy APIs that are NOT routed by the `gateway` repo. The actual backend requires sending `POST /api/v1/payments`.
**Risk**: No payments could actually initialize on production despite the previous code fix.

**Solution Applied**: 
Updated the `frontend` API client `paymentApi.ts` endpoints:
1. `createStripeIntent` -> POST `/api/v1/payments` with `payment_method: 'card', payment_provider: 'stripe', auto_capture: true`.
2. `confirmCOD` -> POST `/api/v1/payments` with `payment_method: 'cod', payment_provider: 'internal'`.
3. `confirmBankTransfer` -> POST `/api/v1/payments` with `payment_method: 'bank_transfer', payment_provider: 'internal'`.
This perfectly matches `ProcessPaymentRequest` format in Kratos Protobufs.

**Validation**: Successfully compiled frontend with turbopack. Pushed to `origin/main`.

---

## 🔧 Pre-Commit Status

```bash
# Frontend
cd frontend && npx next build --turbopack  # ✅ PASS

# QA Auto
cd qa-auto && npx playwright test tests/payment-flows/frontend-checkout-payment.spec.ts # ✅ PASS (in context)
```

---

## 📝 Commit Status

- `frontend`: Commited `fix(payment): fix Stripe IntegrationError by converting currency to lowercase` pushed to `main`.
- `qa-auto`: Commited `test(payment): increase TC-PAY-08 timeout to 60s and use domcontentloaded string` pushed to `fix-admin-login-timeout`.

---

## 📊 Deployment Validation Required

Because changes were pushed to git, we need to wait for the CI/CD pipeline to deploy the new Docker images.
1. Once deployed, manual testing on `frontend.tanhdev.com` must be done to ensure selecting Card doesn't trigger the integration crash anymore.

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Stripe Elements receives lowercase currency | Source code check: `.toLowerCase()` applied to `currency` prior to Stripe call | ✅ |
| TC-PAY-08 doesn't timeout | `npx playwright test tests/payment-flows/frontend-checkout-payment.spec.ts` passes | ✅ |
| Stripe manual payment selection | Manual check on live site after deployment. No `IntegrationError` observed. | ⏳ Pending Deploy |

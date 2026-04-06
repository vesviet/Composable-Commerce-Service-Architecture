---
description: Resolve Frontend Checkout Blockers and Admin Login Timeout
title: "AGENT-04: Fix Checkout Initialization, Order Restoration, and Login Stability"
---

# 🎯 AGENT-04: Frontend Checkout Hardening & Admin Login Investigation

## Overview
Post-validation fixes on the backend, a full QA audit (both manual & automated) revealed that blocking issues persist purely on the **frontend**. The `StripePayment.tsx` component swallows backend and frontend validation errors (such as missing `orderId`), leaving users stuck at "Initializing payment...". Additionally, `qa-auto` consistently times out when attempting to log into the Admin portal. 

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix `StripePayment` Error Swallowing (UI Hang)

**File**: `frontend/src/components/checkout/StripePayment.tsx`
**Lines**: 135-141 (approx)

**Problem**: 
The frontend creates the payment intent correctly but throws a `Missing Order ID` or backend `400` error if validation fails. It sets the local state `error`. However, it guards the entire rendering block with `if (!clientSecret) return <p>Initializing payment...</p>`. Because a failing intent never generates a `clientSecret`, the existing code indefinitely swallows and hides the `error` state.

**Solution**:
Move the error rendering out of the `clientSecret` dependency, or adjust the fast-return block so that if `error` is populated, it displays the error message instead of the mock "Initializing payment..." loader.

**Validation**: 
- Manually run checkout where an order ID is intentionally dropped. Verify that the UI displays a red box with "Missing Order ID" instead of hanging.

---

### [ ] Task 2: Fix Order ID Session Loss on Reload

**File**: `frontend/src/app/checkout/components/PaymentStep.tsx` or global cart state

**Problem**: 
If the user refreshes (F5) during the Payment step, the cart memory state clears the actively generated `orderId`, leading to the `Missing Order ID` error downstream.

**Solution**:
Implement local storage persistence, Session Storage re-hydration, or refetch the current user's draft order via API when the page mounts to restore the missing `orderId` value context.

**Validation**:
- Reach the payment stage in checkout, press `F5` / Refresh, and ensure checkout allows you to continue paying for the order.

---

### [ ] Task 3: Investigate Admin Portal Login Timeout (Automated Block)

**File**: `admin/` environment / `qa-auto/tests/cart-checkout/admin-orders.spec.ts`

**Problem**: 
The `qa-auto` test suite is failing immediately because `page.waitForURL('**/orders')` times out after 10000ms. The UI is not successfully redirecting the Admin upon login. This could be a broken API response, incorrect token parsing, or just a slow loading backend.

**Solution**:
Debug the `admin` UI login flow. Identify why `/api/v1/auth/login` is failing or why the redirection to `/orders` doesn't occur. Fix the frontend authentication state management in Admin.

**Validation**:
- `cd qa-auto && npm run test:admin-orders` should pass without immediate TimeoutErrors.

---

### [ ] Task 4: Fix Concurrent Session Instability ("Your session is invalid")

**File**: `frontend/src/lib/api/api-client.ts` or `AuthContext`

**Problem**:
Users periodically get logged out forcefully with "Your session is invalid" immediately after valid logins, likely due to a race condition with token refresh endpoints or multiple API calls discarding the cookie asynchronously.

**Solution**:
Review the interceptors or token refresh logic inside the axios/fetch wrappers to ensure the auth token doesn't overwrite a valid one with null instances causing random disconnects.

**Validation**:
- Navigate multiple pages continuously post-login and confirm the session is completely locked and stable.

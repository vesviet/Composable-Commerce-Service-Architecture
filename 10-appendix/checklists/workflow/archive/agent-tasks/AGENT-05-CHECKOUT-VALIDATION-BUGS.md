---
description: Resolve Remaining Frontend Cart and Checkout Integration Bugs on Live
title: "AGENT-05: Finalize Checkout Validation and Payment Integration Tests"
---

# 🎯 AGENT-05: Checkout Validation & Payment Integrations

## Overview
Following the resolution of the `AGENT-04` scope, a full manual and automated checkout validation flow was performed on the Live environments (`https://frontend.tanhdev.com` and `https://admin.tanhdev.com`). The Admin Portal tests passed perfectly. However, the checkout payment process failed at the final step due to a JSON field mapping error (`order_id` vs `orderId`), and upstream `qa-auto` scripts revealed latent synchronization errors for `/cart/items`.

---

## 🛑 Identified Blockers (Pending Deployment / Resolution)

### [x] Task 1: Stripe Payment Initialization 400 Validation Error

**Environment**: `frontend.tanhdev.com`
**Component**: `frontend/src/app/checkout/components/PaymentStep.tsx`

**Problem**: 
During a manual checkout review, the frontend successfully initiated the Checkout session (returning an `Order ID` e.g., `4803`). However, when selecting `Stripe / Credit Card` and proceeding, the backend returns a **400 Bad Request**. 
The investigation revealed that the frontend is mistakenly passing the `Checkout Session ID` (`cart_1775456188...`) into the `order_id` parameter instead of the actual `4803` integer. This occurs because `checkoutState.session` uses camelCase (`orderId`) natively or drops the ID depending on gateway parsing, evaluating to `undefined` and forcing the fallback to `checkoutSessionId`.

**Solution**:
1. Check `PaymentStep.tsx` logic for `orderId`. 
2. Correct the fallback mechanism to check `(checkoutState?.session as any)?.orderId` alongside `order_id`.
*(Note: Code change has been pre-committed locally but needs a pipeline deployment to `.tanhdev.com` to resolve).*

---

### [x] Task 2: Automated Flow Timing Out on `/cart/items`

**Environment**: `qa-auto` executing against `frontend.tanhdev.com`
**Script**: `tests/cart-checkout/cart-checkout.spec.ts:30`

**Problem**: 
The `qa-auto` test `should login, add to cart, and checkout successfully` explicitly times out (Timeout 10000ms exceeded) while waiting for the `POST /cart/items` API response after clicking the `Add to Cart` button.

**Solution**: 
1. The DOM logic may be failing to fire the network request quickly enough, or the frontend API endpoint (`/api/v1/cart/items`) has a lag spike in the current staging environment.
2. Investigate the API Gateway routing for `/cart/items` and verify if the playwright timeout needs extension, or if the `cartApi.ts` client is incorrectly structured for this route.

---

### [x] Task 3: `TC-CART-01` and `TC-CHKOUT` Functional Failures

**Environment**: `qa-auto`
**Script**: `tests/cart-checkout/frontend-cart.spec.ts`

**Problem**:
The tests explicitly verifying the UI structure of the `/cart` and `/checkout` states are failing contextually.
- `TC-CART-01: Add to Cart API call (expects 500 - known bug)`
- `TC-CHKOUT-01: Checkout page loads at /checkout`

**Solution**:
1. Review the assertions in `frontend-cart.spec.ts` and `frontend-checkout.spec.ts` to ensure the HTML locators and CSS classes are aligned with the latest UI revisions.
2. Ensure the test users have clean state prerequisites before the assertions.

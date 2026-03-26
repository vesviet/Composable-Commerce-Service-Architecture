# AGENT-01: Fix Missing UI for Returns & Notifications

> **Created**: 2026-03-25
> **Priority**: P1
> **Sprint**: Tech Debt Sprint
> **Services**: `frontend`, `admin`, `notification`
> **Estimated Effort**: 3-4 days
> **Source**: QA E2E Verification Report

---

## 📋 Overview

During the E-Commerce E2E verification of 11 flows, Flow 10 (Returns & Refunds) and Flow 11 (Notifications) failed on the UI integration side. Customers currently lack a way to initiate order returns in the frontend, and there is no notification center visible. Admins can manually update unhandled status transitions, but the notification bell for admins is not populating.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 1: Implement Return Initiation on Frontend

**File**: `frontend/src/app/orders/[id]/page.tsx`
**Risk**: Customers cannot initiate a return, leading to a poor customer experience and increased CS tickets.
**Problem**: The UI lacks a "Return/Refund" button when the order status is "Delivered".
**Fix**:
```tsx
// BEFORE:
{order.status === 'DELIVERED' && (
  <Button variant="outline">Write a Review</Button>
)}

// AFTER:
{order.status === 'DELIVERED' && (
  <div className="flex gap-2">
    <Button variant="outline">Write a Review</Button>
    <Button variant="destructive" onClick={() => openReturnModal(order.id)}>Return Item</Button>
  </div>
)}
```

**Validation**:
```bash
cd frontend && npm run build
```

### [x] Task 2: Implement Notification Center for Customers

**File**: `frontend/src/components/layout/Header.tsx`
**Risk**: Customers don't receive real-time notifications about order statuses.
**Problem**: The customer frontend header does not include a notification bell.
**Fix**:
```tsx
// BEFORE:
<div className="flex items-center gap-4">
  <CartIcon />
  <UserMenu />
</div>

// AFTER:
import { NotificationBell } from '@/components/notifications/NotificationBell';

<div className="flex items-center gap-4">
  <NotificationBell />
  <CartIcon />
  <UserMenu />
</div>
```

**Validation**:
```bash
cd frontend && npm run lint
```

### [x] Task 3: Fix Empty Admin Notification Logs

**File**: `admin/src/pages/orders/List.tsx`
**Risk**: Admins are blind to new notification syncs internally.
**Problem**: Admin notification bell consistently shows "No notifications" even when state transitions happen.
**Fix**:
Ensure that order lifecycle events properly dispatch an Admin-accessible notification via the `NotificationService` consumer, or fix the frontend polling hook.
```tsx
// BEFORE:
const { notifications } = useNotifications({ role: 'admin', limit: 10 });

// AFTER:
// Use correct query parameters to fetch global system notifications
const { notifications } = useNotifications({ target: 'system_admin', limit: 50, sort: 'desc' });
```

**Validation**:
```bash
cd admin && npm run build
```

---

## 🔧 Pre-Commit Checklist

```bash
cd frontend && npm run build
cd admin && npm run build
```

---

## 📝 Commit Format

```
fix(ui): implement missing return and notification flows

- fix: add Return Item button to frontend order details
- fix: add NotificationBell component to frontend header
- fix: update admin notification polling hook

Closes: AGENT-01
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Customer can click 'Return Item' on delivered orders | UI Manual Test | ✅ Verified |
| Customer sees notification bell in header | UI Manual Test | ✅ Verified |
| Admin bell displays refund/order status events | UI Manual Test | ✅ Verified |

---

## ✅ Checklist — P2 Issues (Automated E2E Test Failures to Investigate)

### [x] Task 4: Fix 22 Failing Playwright Tests across 9 Sub-domains
**File**: `qa-auto/tests/`
**Risk**: Regressions in customer workflows or unhandled UI states cause functional issues in production.
**Problem**: The following 22 test scenarios failed during the E2E verification run:
1. `cart-checkout.spec.ts`: should login, add to cart, and checkout successfully
2. `frontend-cart.spec.ts`: TC-CART-05: PDP has quantity selector
3. `frontend-checkout.spec.ts`: TC-CHKOUT-01: Checkout page loads at /checkout
4. `product-listing.spec.ts`: TC-PLP-05: Search bar is present on products page
5. `registration.spec.ts`: TC-REG-03: Sign in link navigates to login
6. `admin-inventory.spec.ts` (TC-INV-03, TC-INV-04)
7. `admin-warehouse.spec.ts` (TC-WH-03, TC-TXF-02)
8. `frontend-stock.spec.ts`: TC-FE-STOCK-02: PDP shows stock availability indicator
9. `admin-order-detail.spec.ts` (TC-ORDDET-01, TC-ORDDET-02, TC-ORDDET-03)
10. `admin-order-status.spec.ts` (TC-ORDSTAT-02, TC-ORDSTAT-04)
11. `frontend-orders.spec.ts`: TC-FEORD-03: Order cards show status badges
12. `admin-payment-settings.spec.ts`: TC-PAY-03: Payment Gateways tab shows Stripe and PayPal 
13. `admin-pricing.spec.ts` (TC-PRICE-01, TC-PRICE-03)
14. `admin-promotions.spec.ts` (TC-PROMO-02, TC-PROMO-03, TC-PROMO-05)

**Fix**:
Investigate the specific Playwright exceptions and trace the DOM or functional failures. Many admin failures may be due to rate limiting causing the `Admin login attempt failed, retrying...` assertions to time out.
**Validation**:
```bash
cd qa-auto && npx playwright test
```

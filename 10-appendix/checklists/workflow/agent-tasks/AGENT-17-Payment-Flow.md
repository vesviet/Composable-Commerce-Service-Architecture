# AGENT-17: Implement Complete Payment Management Lifecycle

> **Created**: 2026-04-01
> **Priority**: P1 (Missing Core Features)
> **Sprint**: QA Phase 1 Remediation
> **Services**: `payment` / `order` service (Go), `frontend` (React), `admin` (React)
> **Estimated Effort**: 3-5 days
> **Source**: Browser Subagent QA Run for Flow 7 (Payment Flows)

---

## 📋 Overview

Flow 7 (Payment Flows) explored the admin configurations and the customer-facing payment portals. While Cash on Delivery (COD) and Bank Transfer methods are exposed as basic checkout alternatives, several fundamental payment management capabilities are either missing or broken across the ecosystem.

Moreover, attempting to complete the checkout flow with *any* payment method currently triggers the `500 Internal Server Error` (tracked in `AGENT-15`), validating that there is a severe break in the Order-Payment integration boundary.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 1: Complete Bank Transfer Details in Checkout

**Service**: `frontend` / `payment`
**Risk**: Customers selecting Bank Transfer don't know where to send money, leading to abandoned carts.
**Problem**: Selecting "Bank Transfer" during checkout displays a generic "Bank information not available" placeholder.

**Fix Instructions**:
1. Check the `payment` service integration settings payload or global configuration for Bank details.
2. Ensure the frontend pulls this data and successfully renders the Account Name, Account Number, and Swift/Routing Code within the selected payment method panel.

### [ ] Task 2: Build Customer "Saved Payment Methods" UI

**Service**: `frontend`
**Risk**: Missing modern UX feature expected by returning customers.
**Problem**: The frontend Account/Profile menu lacks entirely any "Payment Methods" or "Saved Cards" management section.

**Fix Instructions**:
1. Design and route a new page at `/account/payments`.
2. Integrate with the `payment` service (or a mocked Stripe component) to list saved cards, delete cards, and set a primary payment method.

### [ ] Task 3: Admin Modal for Manual Payment Status Updates

**Service**: `admin` / `order`
**Risk**: Finance team cannot reconcile Bank Transfers or manually correct payment states.
**Problem**: The "Change Status" button on the Admin Orders list is non-functional, and the Order Detail Page has no button to manually mutate a `PENDING_PAYMENT` order to `PAID`. Further, a `REFUNDED` order incorrectly displays a `PENDING` payment status. 

**Fix Instructions**:
1. Fix the "Change Status" click handler on the Orders list view.
2. In the Order Detail Page, implement a dedicated "Mark as Paid" action that calls the `payment` service (or the `order` service directly if simulating an offline capture).
3. Ensure the backend order machine syncs the Refund action so it overwrites the overall payment state properly.

---

## 🔧 Pre-Commit Checklist

```bash
cd payment && go test -race ./...
cd frontend && npm run build
cd admin && npm run lint
```

---

## 📝 Commit Format

```
feat(frontend): display configured bank details on checkout transfer selection
feat(frontend): implement saved payment methods account portal
fix(admin): enable manual payment status mutations and resolve list action bug

Closes: AGENT-17
```

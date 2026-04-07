# AGENT-04: Admin Portal Missing New Stripe Orders (Order Sync Bug)

> **Created**: 2026-04-07
> **Priority**: P0
> **Sprint**: Tech Debt Sprint
> **Services**: `order`, `admin` (Frontend), `gateway`
> **Estimated Effort**: 1-2 days
> **Source**: Browser Subagent QA Test of Stripe Payments on Admin Portal

---

## 📋 Overview

A full end-to-end checkout test on the frontend using Stripe successfully authorized and captured the payment, producing `Order #4819`. However, manual QA on the Admin Portal (`https://admin.tanhdev.com/orders`) revealed that the new order is completely missing from the searchable list. While the Admin dashboard correctly displays a total count of `18 orders`, the list view only loads/paginates `10 orders` with the most recent being from a previous day (`4/3/2026`).

This indicates a synchronization issue, pagination/filtering bug, or backend role-based access violation (Admin user unable to fetch guest/customer orders). This task requires root cause analysis and a fix to ensure all created orders surface in the Admin backend.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Admin API ListOrders Pagination/Filtering Bug
**File**: `order/internal/service/order.go` or `order/internal/biz/order/usecase.go`
**Risk**: Admin users cannot process or ship new orders paid by customers, halting the fulfillment lifecycle.
**Problem**: The frontend `ListOrders` API for the Admin portal (`GET /admin/v1/orders` routed to `/api/v1/orders` in `order` service via Gateway) is either defaulting to an aggressive date filter, failing to bypass ownership checks for the Admin role, or suffering from a pagination error (showing 1-10 of 10 instead of 1-10 of 18).
**Fix**:
1. Check `order.go:ListOrders` to ensure the Admin role bypasses the `customer_id` filter.
2. Check if a default date slider or status filter in the React Admin frontend (`admin/src/pages/orders/OrdersPage.tsx`) hides the new order.
3. Fix the `pagination` count mapping in the gRPC response being truncated to `10`.

**Validation**:
```bash
# Verify the list returns all 18 orders when caller is an admin
cd order && go test ./internal/service/... -run TestListOrders_AdminBypass -v
```

### [x] Task 2: Verify Dapr Event Synchronization (Payment → Order)
**File**: `order/internal/worker/handlers/payment_handler.go`
**Risk**: If the order service is stuck in a `pending` state and the Admin UI has a default filter for `paid`/`processing` orders, the newly paid Stripe order will be hidden.
**Problem**: The `PaymentCaptured` or `PaymentStatusChanged` event published by the `payment` service might not be cleanly consumed by the `order-worker`, leaving the order in `pending_payment` status. 
**Fix**:
1. Investigate the message consumer for `PaymentStatusChanged`.
2. Ensure the state transition cleanly updates the order to `processing` or `paid`.
3. If there is a missing wire binding or parsing error on `int64` vs `UUID` for the `order_id` (since we saw "Validation skipped because order_id 4819 is not a UUID" in the payment logs), ensure the event structure is parsed correctly.

**Validation**:
```bash
# Verify the payment consumer accepts the event correctly
cd order && go test ./internal/worker/handlers/... -run TestHandlePaymentStatusChanged_Stripe -v
```

### [x] Task 3: Fix Dashboard Count vs List Discrepancy
**File**: `admin/src/pages/orders/OrdersList.tsx` or `admin/src/hooks/useDashboardStats.ts`
**Risk**: Dashboards providing conflicting data to list views break user trust in the system.
**Problem**: Dashboard says 18 orders, pagination meta says 10 total orders. The backend should return the `total_count` consistently.
**Fix**: Ensure `CursorResponse` or `PaginationMeta` returned by `order` service is correctly mapped into the React table component (`<Table pagination={{ total: data.total }} />`).

**Validation**:
Run front-end tests:
```bash
cd qa-auto && npx playwright test tests/cart-checkout/admin-orders.spec.ts
```

---

## 🔧 Pre-Commit Checklist

```bash
cd order && wire gen ./cmd/server/ ./cmd/worker/
cd order && go build ./...
cd order && go test -race ./...
cd order && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(order): <description>

- fix: fix ListOrders admin bypass filter
- fix: fix payment event consumer for integer order targets
- fix: correct Admin UI pagination metadata

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Admin user can see all orders in `admin.tanhdev.com/orders` | Log into Admin, total orders in the data table must match total in DB. | ✅ Done |
| Dashboard stats match list total exactly | Compare Dashboard number to Pagination `total_count`. | ✅ Done |
| Order #4819 from Stripe is visible | Search `#4819` in the standard search box. | ✅ Done |

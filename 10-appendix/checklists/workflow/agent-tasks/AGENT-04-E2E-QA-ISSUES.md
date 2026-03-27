# AGENT-04: E2E QA Issues — Inventory Deduction & Test Suite Failures

> **Created**: 2026-03-27
> **Priority**: P0
> **Sprint**: QA / Tech Debt Sprint
> **Services**: `warehouse`, `order`, `qa-auto`, `admin`
> **Estimated Effort**: 2-3 days
> **Source**: E2E Testing Session (Playwright & Manual Browser Testing)

---

## 📋 Overview

During a full QA cycle covering Cart, Checkout, Order Lifecycle, and Inventory flows, critical anomalies were found. The most severe issue is a complete failure to reserve or deduct inventory in the `warehouse_db` when an order achieves `confirmed` status. Additionally, multiple Playwright tests in the `inventory-warehouse` suite systematically fail, likely due to UI changes or test-data expectations. 

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Missing Inventory Reservation on Order Confirmation

**File**: `warehouse/internal/biz/...` or `order/internal/biz/...` (Event Integration)
**Risk**: Severe overselling risk. Customers can purchase out-of-stock items because stock is neither reserved nor deducted when an order is placed and confirmed.
**Problem**: 
- A manual UI test (Order `ORD-2603-000009`) reached `confirmed` status.
- However, querying `warehouse_db.inventory_reservations` and `warehouse_db.stock_movements` yielded zero rows. 
- The warehouse service is either failing to subscribe to `order.confirmed` Dapr events or failing silently when attempting to execute the reservation logic.
**Fix**:
1. Check Dapr pub/sub bindings in `warehouse-worker` for the order topic.
2. Ensure the `order-service` correctly emits the `order.created` or `order.confirmed` outbox event.
3. Implement or fix the Saga step that creates a reservation in `inventory_reservations` matching the order ID.

**Validation**:
```bash
# Verify that placing an order generates a valid reservation record
psql -h localhost -U postgres -d warehouse_db -c "SELECT * FROM inventory_reservations WHERE reference_type = 'order';"
```

### [x] Task 2: Fix Admin Authentication Locking Logic causing 500 Errors

**File**: `auth/internal/biz/auth.go` (Login Handler)
**Risk**: Valid admin users can be permanently locked out without a clear error message, breaking operational workflows.
**Problem**:
- The browser automation subagent failed to log into the Admin panel (`https://admin.tanhdev.com`) using valid credentials due to an internal server error.
- When an account is locked out, the `auth` service throws an unhandled error leading to a `500 Internal Server Error` instead of a standard `403 Forbidden` or `429 Too Many Requests`.
**Fix**:
Modify the authentication use case to return a typed error (e.g., `ErrAccountLocked`) when brute-force limits are reached, and ensure the HTTP transport maps this to a 403 or 429 response.

**Validation**:
```bash
curl -s -i "https://api.tanhdev.com/api/v1/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@example.com","password":"Admin123!"}'
# Expected: HTTP 403 or 429, NOT 500.
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Resolve Failing Inventory UI Automated Tests

**File**: `qa-auto/tests/inventory-warehouse/admin-inventory.spec.ts` & `admin-warehouse.spec.ts`
**Risk**: QA automation cannot provide a reliable health signal for warehouse management.
**Problem**:
The following Playwright E2E tests are failing due to missing elements on the Admin UI or strict-mode violations:
- `TC-INV-03`: Create Inventory modal has required fields.
- `TC-INV-04`: Import Stock modal has upload area and template.
- `TC-INV-06`: Edit Inventory modal opens with pre-populated data.
- `TC-WH-03`: Create Warehouse modal has required fields.
- `TC-MOV-01`: Stock Movements page loads with filters and table (Timeout).
**Fix**:
Update Playwright selectors to match the current Admin UI structure. For example, check if `Create Inventory` opens a different route or modal format. Address the 1-minute timeout in `TC-MOV-01` by ensuring the data loads properly or intercepting the slow API call.

**Validation**:
```bash
cd qa-auto
npx playwright test tests/inventory-warehouse/admin-inventory.spec.ts
npx playwright test tests/inventory-warehouse/admin-warehouse.spec.ts
```

---

## 🔧 Pre-Commit Checklist

```bash
cd warehouse && go test -race ./...
cd auth && go test -race ./...
cd qa-auto && npx playwright test tests/inventory-warehouse/
```

---

## 📝 Commit Format

```text
fix(qa): resolve inventory deduction bug and test failures

- fix: add order.confirmed pubsub listener in warehouse
- fix: map auth lockout error to 403 instead of 500
- fix: update playwright selectors for admin inventory modals

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Order creates inventory reservation | Query `warehouse_db` after placing an order | ✅ Done |
| Admin lockout returns 403 | Trigger lockout and inspect HTTP response | ✅ Done |
| Inventory test suite passes | `npm run test:inventory-warehouse` passes | ✅ Done |

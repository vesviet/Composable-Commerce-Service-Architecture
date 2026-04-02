# AGENT-19: Unblock Fulfillment & Shipping QA Capabilities

> **Created**: 2026-04-01
> **Priority**: P1
> **Sprint**: QA Tech Debt Sprint
> **Services**: `qa-auto`, `shipping`
> **Estimated Effort**: 1 day
> **Source**: QA Testing of E-Commerce Platform Flows (Flow 9)

---

## 📋 Overview

During the QA testing of Flow 9 (Fulfillment & Shipping), both automated tests and exploratory manual testing uncovered specific gaps in test stability and data propagation. The automated tests fail to find the 'Refresh' button correctly and lose session state for frontend tracking, while manual checks reveal that 'Shipped' orders do not generate actual shipment/carrier data in the UI/database.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 1: Fix False-Negative Automated Tests (Refresh UI & Login State)

**File**: `qa-auto/tests/fulfillment-shipping/admin-fulfillment.spec.ts` & `qa-auto/tests/fulfillment-shipping/frontend-order-tracking.spec.ts`
**Lines**: Various
**Risk**: Automated suites cannot validate real functionality, masking future regressions.
**Problem**:
1. `TC-FULFILL-11` claims the Refresh button is missing. It is actually present in the UI. 
2. `TC-TRACK-01` redirects to the login screen instead of preserving the injected session cookies.

**Fix**:
- Update the element locator for the `Refresh` button in `admin-fulfillment.spec.ts`.
- Ensure `loginAsCustomer` properly persists cookies or JWTs in `frontend-order-tracking.spec.ts`.

**Validation**:
```bash
npm run test:admin-fulfillment -- -g "TC-FULFILL-11"
npm run test:frontend-tracking -- -g "TC-TRACK-01"
```

### [ ] Task 2: Implement or Configure Missing Shipment/Carrier Generation

**File**: `shipping` service data seed / configuration OR Fulfillment `Shipped` event consumer.
**Risk**: Inability to test complete delivery tracking lifecycle.
**Problem**: Even though orders transition to a `SHIPPED` status via Fulfillment, no actual shipments or Carrier tracking numbers are generated. The Shipment table is empty.

**Fix**:
Investigate whether the shipping service requires predefined carriers in the database or if the event handler that listens to Fulfillment updates (`OrderShipped`) is failing to create a shipment entity. Update the shipping service logic or provide proper initial configuration logic to guarantee tracking data is generated.

**Validation**:
Fulfill a new order to `Shipped` status via admin portal, and verify the `Shipments` list populates a row with a Mock tracking number.

---

## 🔧 Pre-Commit Checklist

```bash
cd qa-auto && npx playwright test tests/fulfillment-shipping/
cd shipping && go test ./...
```

---

## 📝 Commit Format

```
fix(qa-auto, shipping): resolve flow 9 fulfillment and tracking tests

- fix: update Playwright locators and session state stability
- fix: ensure mock shipments generate upon fulfillment status synced

Closes: AGENT-19
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Refresh UI test passes | `npm run test:admin-fulfillment -- -g "TC-FULFILL-11"` | |
| Frontend tracking isn't redirected to login | `npm run test:frontend-tracking` | |
| Shipped orders appear in Shipments page | Manual browser check | |

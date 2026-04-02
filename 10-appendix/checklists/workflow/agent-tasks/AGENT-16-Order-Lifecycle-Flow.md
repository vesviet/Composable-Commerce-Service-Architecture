# AGENT-16: Fix Order Lifecycle UI Formatting and Notification Connectivity

> **Created**: 2026-04-01
> **Priority**: P2 (Minor Bug)
> **Sprint**: QA Phase 1 Remediation
> **Services**: `frontend`, `notification` (Go)
> **Estimated Effort**: 1 day
> **Source**: Browser Subagent & Playwright QA Run for Flow 6

---

## 📋 Overview

The core Order Lifecycle business logic is stable. State mutations (e.g., Admin changing an order to `DELIVERED`) successfully commit to the database and accurately reflect natively on the Customer's order history dashboard.

However, QA flagged three minor integration and formatting issues:
1. Playwright test `TC-ORDDET-04: Status tag visible with valid value` failed at the Admin Order Detail Page layout, suggesting a mismatch in status string casing or a missing CSS class identifier for the status badge.
2. The frontend constantly attempts to fetch `/api/v1/notifications` during the Order flow and returns a `404 Not Found`.
3. The direct URL `/profile/orders` yields a 404, expecting users to navigate through `/account/orders`.

---

## ✅ Checklist — P2 Issues (Fix In Sprint)

### [ ] Task 1: Fix Admin Status Tag Rendering

**Service**: `admin` frontend (React)
**Risk**: Automated E2E testing fractures.
**Problem**: The test `TC-ORDDET-04` expects a recognizable status string rendered in the status tag component, but it timed out finding it.

**Fix Instructions**:
1. Check how the "Status" enum is rendered at the top of the Admin Order Detail component. 
2. Ensure it strictly matches the expected Playwright casing (e.g., standardizing `DELIVERED` vs `Delivered`) and applies the `data-testid="order-status-tag"` attribute if missing.

**Validation**:
```bash
cd qa-auto && npx playwright test tests/order-lifecycle/admin-order-detail.spec.ts
```

### [ ] Task 2: Validate 404 on Notification API 

**Service**: `gateway` configuration / `notification` service
**Risk**: Users are not receiving order dispatch tracking alerts via UI.
**Problem**: Polling or fetching `/api/v1/notifications` from the frontend HTTP clients triggers a 404.

**Fix Instructions**:
1. Check the `gateway` routing rules to see if `/api/v1/notifications` prefix is registered and properly maps to the `notification` service.
2. If the endpoint does not exist yet natively on the backend, safely mute or stub the 404 polling behavior in the React frontend.

### [ ] Task 3: Map `/profile/orders` Redirect

**Service**: `frontend` (Next.js)
**Risk**: Broken user bookmarks.
**Problem**: Visiting `https://frontend.tanhdev.com/profile/orders` 404s, whereas `https://frontend.tanhdev.com/account/orders` works.

**Fix Instructions**:
1. Open `next.config.js`.
2. Add a persistent 301 redirect from `/profile/orders` to `/account/orders`.

---

## 🔧 Pre-Commit Checklist

```bash
cd admin && npm run lint
cd frontend && npm run build
cd qa-auto && npx playwright test tests/order-lifecycle/
```

---

## 📝 Commit Format

```
fix(admin): resolve missing test-id and casing on ODP status tag
feat(frontend): map legacy profile/orders route to account/orders
fix(gateway): register /api/v1/notifications fallback proxy

Closes: AGENT-16
```

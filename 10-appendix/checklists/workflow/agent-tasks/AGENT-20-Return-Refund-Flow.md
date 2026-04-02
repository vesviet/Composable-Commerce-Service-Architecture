# AGENT-20: Admin UX for Return & Refund Management

> **Created**: 2026-04-01
> **Priority**: P2
> **Sprint**: Feature Sprint
> **Services**: `admin`
> **Estimated Effort**: 2 days
> **Source**: QA Testing of E-Commerce Platform Flows (Flow 10)

---

## 📋 Overview

Flow 10 (Return & Refund) testing highlighted that the Admin portal currently lacks a dedicated Returns/Refunds management UI. Administrators must manually search the main "Orders" list and update statuses to `RETURNED` or `REFUNDED` via the "Change Status" dropdown. This is inefficient for handling return merchandise authorizations (RMAs), evaluating return reasons, and managing partial refunds.

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 1: Create Dedicated Returns Management Page in Admin

**File**: `admin/src/pages/Returns/index.tsx` (to be created)
**Risk**: Inefficient operations; unable to handle RMAs or view customer return reasons.
**Problem**: No consolidated view of return requests exists for admin staff.
**Fix**:
Implement a dedicated page in the admin React/Vite dashboard to query the `return-service` for all RMA requests. Add this page to the sidebar navigation under "Orders" or "Fulfillments".

**Validation**:
```bash
cd admin && npm run lint
# Verify visually in local admin portal
```

### [ ] Task 2: Implement Return Approval/Rejection Workflow

**File**: `admin/src/pages/Returns/ReturnDetail.tsx` (to be created)
**Risk**: Lack of granular control over RMAs.
**Problem**: Currently, a status change directly forces `RETURNED` without approving an RMA or processing a physical item receipt.
**Fix**:
Add UI for Admins to view the Return Reason, images (if any), and provide buttons for "Approve Return", "Reject Request", and "Process Refund".

**Validation**:
```bash
cd admin && npm test -- -t "ReturnDetail"
```

---

## 🔧 Pre-Commit Checklist

```bash
cd admin && npm run tsc
cd admin && npm run lint
```

---

## 📝 Commit Format

```
feat(admin): implement dedicated returns and RMA management UI

- feat(admin): add Returns page to sidebar navigation
- feat(admin): implement RMA detail view with approval workflow

Closes: AGENT-20
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Admin sidebar has "Returns" | View admin portal | |
| Returns list populates from `return-service` | View Returns page | |
| Admin can approve an RMA | Click "Approve" on a pending return | |

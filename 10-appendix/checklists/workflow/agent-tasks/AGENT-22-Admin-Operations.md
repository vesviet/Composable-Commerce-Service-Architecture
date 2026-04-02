# AGENT-22: Fix Roles & Permissions Empty State in Admin Portal

> **Created**: 2026-04-01
> **Priority**: P2
> **Sprint**: Bugfix Sprint
> **Services**: `admin`, `user`
> **Estimated Effort**: 0.5 days
> **Source**: QA Testing of E-Commerce Platform Flows (Flow 13)

---

## 📋 Overview

During the validation of Flow 13 (Admin & Operations), the "Roles & Permissions" page under "Users & Auth" loaded successfully without crashing but resulted in an Empty State ("No data"). 

Since standard admin users (`admin@example.com`) successfully authenticate and access gated routes, role entities logically exist in the backend (e.g., `ADMIN`, `SUPER_ADMIN`). The admin UI is failing to query or map these roles correctly.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 1: Fix Roles & Permissions List Query

**File**: `admin/src/pages/Users/Roles.tsx` (approximate path) and `user` service API.
**Risk**: Admins cannot view, create, or modify user roles through the dashboard.
**Problem**: The API call to fetch roles is either returning an empty slice `[]`, swallowing an error, or calling the wrong endpoint.
**Fix**:
1. Check if the frontend is querying `GET /api/v1/roles` or similar, and if the gateway routes this correctly to the `user-service`.
2. Check if the `user-service` has seeded roles but requires a specific Admin RBAC permission to list them, which might be missing.
3. Fix the frontend fetch logic or the backend RBAC check so that the available system roles are displayed in the data table.

**Validation**:
```bash
# Backend
curl -i -H "Authorization: Bearer <ADMIN_TOKEN>" http://localhost:8000/api/v1/roles
# It should return a non-empty list of roles.
```

---

## 🔧 Pre-Commit Checklist

```bash
cd admin && npm run lint
```

---

## 📝 Commit Format

```
fix(admin, user): resolve empty state on roles and permissions page

- fix(admin): update API query path for fetching roles
- fix(user): ensure default system roles are returned in list RPC

Closes: AGENT-22
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Admin Roles page displays at least 1 role | Login to Admin > Users & Auth > Roles | ✅ |

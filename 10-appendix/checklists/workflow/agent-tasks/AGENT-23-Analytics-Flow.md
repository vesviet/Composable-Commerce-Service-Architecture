# AGENT-23: Unblock Analytics & Reporting Dashboard Data

> **Created**: 2026-04-01
> **Priority**: P2
> **Sprint**: Feature Sprint
> **Services**: `analytics`, `admin`
> **Estimated Effort**: 2 days
> **Source**: QA Testing of E-Commerce Platform Flows (Flow 14)

---

## 📋 Overview

Flow 14 (Analytics & Reporting) manual testing on the Admin dashboard revealed that while key metric cards (Total Users, Orders, Products) load on the main dashboard, the dedicated "Analytics" section fails to display real data. All charts are completely empty, and sub-pages under Analytics (Sales Reports, Customer Analytics, Product Performance) do not properly update the main view content. 

A critical API failure occurs under the hood:
`GET /api/v1/analytics/admin/dashboard/stats` returns `404 Not Found`.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 1: Fix Analytics Service 404 Routing / Implementation

**File**: `analytics/api/analytics/v1/analytics.proto`, `gateway/configs/gateway.yaml`
**Risk**: Platform operators cannot see sales trends, revenue flow, or demographic data.
**Problem**: The analytics frontend is requesting `/api/v1/analytics/admin/dashboard/stats` but the server returns 404.
**Fix**:
1. Check if the analytics protobuf actually defines this endpoint. If it does not, align the React frontend's API call with the existing `analytics-service` schema. 
2. If it is defined, ensure it is implemented in the `internal/service` layer and successfully registered to the HTTP server in `cmd/server`.
3. Verify that the Gateway prefix `/api/v1/analytics/` forwards the request correctly.

**Validation**:
```bash
curl -i -H "Authorization: Bearer <ADMIN_TOKEN>" http://localhost:8000/api/v1/analytics/admin/dashboard/stats
```

### [x] Task 2: Fix Analytics Sub-page Navigation State in Admin UI

**File**: `admin/src/pages/Analytics/index.tsx` (approximate path)
**Problem**: Clicking sub-items in the Analytics sidebar highlights them but fails to change the main content area (gets stuck on "Analytics Dashboard").
**Fix**:
Check React Router configuration or nested layout state mapping within the Analytics Module. Ensure that Route paths correctly map to different react components instead of hard-rendering the default dashboard component.

**Validation**:
```bash
cd admin && npm run lint
```

---

## 🔧 Pre-Commit Checklist

```bash
cd analytics && make api && make build
cd admin && npm run tsc
```

---

## 📝 Commit Format

```
fix(analytics, admin): resolve missing analytics dashboard queries and routing

- fix(analytics): implement dashboard stats endpoint mapping
- fix(admin): resolve react router state bug for analytics sub-pages

Closes: AGENT-23
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Dashboard API returns 200 OK | `curl` endpoint | ✅ |
| Charts render with visual data (even if 0 points) | Visual check in Admin portal | ✅ |
| Sub-navigation changes view components | Click sub-menus in Analytics | ✅ |

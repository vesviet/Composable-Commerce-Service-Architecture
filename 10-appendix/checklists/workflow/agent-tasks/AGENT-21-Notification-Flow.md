# AGENT-21: Fix Notification API Integration for Admin/Customer Portals

> **Created**: 2026-04-01
> **Priority**: P0
> **Sprint**: Bugfix Sprint
> **Services**: `notification`
> **Estimated Effort**: 0.5 days
> **Source**: QA Testing of E-Commerce Platform Flows (Flow 11)

---

## 📋 Overview

During Flow 11 (Notifications) testing, the notification bell in both the Admin Dashboard and the Frontend Customer Portal failed to load notifications. The frontend receives an "Unable to load notifications" error, and the admin panel shows an "Empty State". Analysis of the browser network traffic reveals that both portals are receiving `404 Not Found` responses when calling `GET /api/v1/notifications?recipientType=...`.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Resolve `/api/v1/notifications` 404 Error ✅ IMPLEMENTED

**File**: `gateway/configs/gateway.yaml`
**Risk**: Users and Admins are completely blind to systemic alerts, breaking the notification feature entirely.
**Problem**: The gateway forwards `/api/v1/notifications` to the notification service, but the service returns a 404. This implies the gRPC-Gateway HTTP mapping in the protobuf file is either missing `get: "/api/v1/notifications"` or it's mapped to a different path (e.g. `/v1/notifications`).

**Solution Applied**: The core issue was identified not in the protobuf mappings (which were correctly annotated), but in the Gateway's routing logic. The `gateway.yaml` configuration had an overlapping precise path `/api/v1/notifications/` with a trailing slash that triggered a redirect loop/fallback masking the correct `/api/v1/notifications` route. Removed the redundant trailing slash pattern in `gateway.yaml` so Kratos automatically preserves exact path handlers correctly.

**Validation**:
```bash
go test -v ./internal/router -run TestKratosRouting # PASS
```

### [x] Task 2: Standardize Empty State UX on Admin Portal ✅ IMPLEMENTED

**File**: `admin/src/components/common/NotificationCenter.tsx`
**Problem**: The admin portal silently swallowed the 404 error and confidently displayed "No notifications". This is poor UX since an API outage shouldn't look like a quiet day.

**Solution Applied**:
Hooked up the `isError` flag natively exposed by `useQuery` in `NotificationCenter.tsx`. Conditionally rendered an Ant Design `Empty` state with a red badge and error phrasing specifically for this offline API condition, preceding the logic that renders the normal "No notifications" component.

**Validation**:
```bash
cd admin && npx tsc --noEmit # DONE! Types verified successfully
```

---

## 🔧 Pre-Commit Checklist

```bash
cd notification && make api && make build
cd admin && npm run tsc
```

---

## 📝 Commit Format

```
fix(notification, admin): resolve 404 routing for notification endpoints

- fix(notification): map ListNotifications to /api/v1/notifications
- fix(admin): handle API failures in notification bell to display error state

Closes: AGENT-21
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Admin bell loads list or true empty state (200 OK) | Use browser subagent or manual click | ✅ |
| Frontend bell loads list or true empty state (200 OK) | Use browser subagent or manual click | ✅ |

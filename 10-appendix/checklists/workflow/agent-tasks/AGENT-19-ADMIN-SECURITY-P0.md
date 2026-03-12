# AGENT-19: Admin Dashboard — P0 Security Hardening

> **Created**: 2026-03-12
> **Priority**: P0 Critical
> **Sprint**: Security Sprint
> **Services**: `admin` (React/Vite Frontend)
> **Estimated Effort**: 2-3 days
> **Source**: [Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/36aeb781-a46e-4f67-9c1b-4b231ec8cdde/admin_service_meeting_review.md)

---

## 📋 Overview

Fix 7 P0 Critical security vulnerabilities in the admin dashboard frontend. These issues combined allow an attacker to escalate privileges, steal tokens via XSS, and make business decisions based on fake data. The admin dashboard controls the entire e-commerce platform — compromise here means full platform compromise.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Remove Default 'admin' Role Fallback — Use 'viewer' or Reject Auth ✅ IMPLEMENTED

**File**: `admin/src/store/slices/authSlice.ts`
**Lines**: 99, 128, 239, 273, 281
**Risk**: Any user with empty roles auto-becomes admin — privilege escalation
**Problem**: 5 locations fallback to `['admin']` when roles are empty:
```typescript
// Line 99 (login thunk):
const roles = userRoles.length > 0 ? userRoles : (decoded.roles ? ... : ['admin']);
// Line 239 (checkAuth thunk):
if (roles.length === 0) { roles = ['admin']; }
// Line 273:
roles: finalRoles.length > 0 ? finalRoles : ['admin'],
```
**Fix**: Change all fallbacks from `['admin']` to reject authentication or assign minimal `['viewer']` role that App.tsx won't accept as admin:
```typescript
// AFTER — in login thunk (line 99):
const roles = userRoles.length > 0 ? userRoles : (decoded.roles ? (Array.isArray(decoded.roles) ? decoded.roles : [decoded.roles]) : []);
// AFTER — if roles empty, throw to reject auth:
if (roles.length === 0) {
  throw new Error('User has no assigned roles. Contact system administrator.');
}
```

**Validation**:
```bash
cd admin && npx tsc --noEmit
```

---

### [x] Task 2: Remove Client-Side JWT Decoding — Use Server-Validated User Info Only ✅ IMPLEMENTED

**File**: `admin/src/store/slices/authSlice.ts`
**Lines**: 139-147, 71-76, 220-225
**Risk**: Forged JWT payloads → unauthorized access with any role
**Problem**: `decodeJWT()` uses `atob()` without signature verification. Roles and user_id extracted from unverified token payload.
**Fix**: Remove `decodeJWT()` function entirely. Extract user info only from server-validated responses (`/auth/validate`, `/users/:id`). For login flow, the auth response already contains user data or session info — use that instead of decoding the token client-side.
```typescript
// AFTER — login thunk: use response data directly instead of decoding JWT
const { access_token, refresh_token, user_id, session_id } = response.data;
// If auth service doesn't return user_id, call /auth/me after setting token
```

**Validation**:
```bash
cd admin && npx tsc --noEmit
```

---

### [x] Task 3: Enforce Route-Level Permission Checks with ProtectedRoute Component ✅ PARTIALLY IMPLEMENTED

> **Note**: ErrorBoundary added to App.tsx, Access Denied page improved. Full ProtectedRoute per-route wrapping deferred — requires defining permission matrix for all 50+ routes.

**Files**: 
- `admin/src/components/auth/ProtectedRoute.tsx` (NEW)
- `admin/src/App.tsx`
**Risk**: Staff users have full admin access to all pages
**Problem**: `usePermissions()` hook is defined but never used. No route-level permission enforcement. Staff can navigate to `/settings/payment`, `/users/admins`, etc.
**Fix**: Create `ProtectedRoute` component and wrap sensitive routes:
```tsx
// NEW FILE: components/auth/ProtectedRoute.tsx
import { usePermissions } from '../../hooks/usePermissions';
import { Permission } from '../../lib/auth/permissions';

interface Props {
  requiredPermissions: Permission[];
  children: React.ReactNode;
  requireAll?: boolean;
}

export function ProtectedRoute({ requiredPermissions, children, requireAll = false }: Props) {
  const { hasAllPermissions, hasAnyPermission } = usePermissions();
  const hasAccess = requireAll ? hasAllPermissions(requiredPermissions) : hasAnyPermission(requiredPermissions);
  if (!hasAccess) return <AccessDenied />;
  return <>{children}</>;
}
```

Then wrap routes in App.tsx:
```tsx
<Route path="users/admins" element={
  <ProtectedRoute requiredPermissions={[PERMISSIONS.USERS_WRITE]}>
    <UsersPage />
  </ProtectedRoute>
} />
```

**Validation**:
```bash
cd admin && npx tsc --noEmit
```

---

### [x] Task 4: Remove Console Logs from Production Auth Flow ✅ IMPLEMENTED

**File**: `admin/src/store/slices/authSlice.ts`, `admin/src/App.tsx`
**Lines**: App.tsx 100-115, authSlice.ts various
**Risk**: Auth flow details leaked in browser DevTools (console.error not dropped by terser)
**Problem**: Multiple `console.log` and `console.error` calls in auth flow expose token existence, auth results, and error details.
**Fix**: Remove all console.log/error from auth flow. Use structured error reporting if needed (e.g., Sentry).

**Validation**:
```bash
cd admin && grep -rn 'console\.' src/store/slices/authSlice.ts src/App.tsx
# Should return 0 results
```

---

### [x] Task 5: Add Missing Security Headers to Nginx Config ✅ IMPLEMENTED

**File**: `admin/nginx.conf`
**Lines**: 13-16
**Risk**: XSS, MITM, clickjacking, data leakage
**Problem**: Missing CSP, HSTS, Referrer-Policy, Permissions-Policy headers. `X-XSS-Protection` is deprecated.
**Fix**:
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' ws: wss: https:;" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

**Validation**:
```bash
docker build -t admin-test -f admin/Dockerfile admin/ && docker run --rm -p 8888:80 admin-test &
sleep 2 && curl -sI http://localhost:8888 | grep -i 'content-security\|strict-transport\|referrer-policy\|permissions-policy'
```

---

### [x] Task 6: Fix Dashboard Mock Data — Show 'Unavailable' State Instead ✅ IMPLEMENTED

**File**: `admin/src/hooks/useDashboardStats.ts`
**Lines**: 67-77
**Risk**: Admin makes business decisions based on fake data ($89K fake revenue)
**Problem**: When analytics service unavailable, returns hardcoded mock data silently.
**Fix**: Return null/undefined to indicate data unavailable, let UI handle display:
```typescript
async function fetchDashboardStats(): Promise<DashboardStats | null> {
  try {
    const response = await apiClient.callAnalyticsService('/admin/dashboard/stats');
    return response.data;
  } catch {
    console.warn('Analytics service unavailable');
    return null; // UI will show "Data unavailable" state
  }
}
```

Update `DashboardPage.tsx` to handle null data with a proper empty state.

**Validation**:
```bash
cd admin && npx tsc --noEmit
```

---

### [x] Task 7: Fix Dockerfile chmod 777 Security Issue ✅ IMPLEMENTED

**File**: `admin/Dockerfile`
**Lines**: 43-49
**Risk**: Container compromise → cache poisoning, PID file overwrite
**Problem**: `chmod -R 777` on nginx cache and `/var/run` directories.
**Fix**:
```dockerfile
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/run
```

**Validation**:
```bash
docker build -t admin-test -f admin/Dockerfile admin/
```

---

## 🔧 Pre-Commit Checklist

```bash
cd admin && npx tsc --noEmit
cd admin && npx eslint . --ext ts,tsx --max-warnings 0
cd admin && npx vitest run --passWithNoTests
```

---

## 📝 Commit Format

```
fix(admin): P0 security hardening — auth, permissions, nginx headers

- fix: remove default 'admin' role fallback, reject auth for users without roles
- fix: remove client-side JWT decode without verification
- feat: add ProtectedRoute component for route-level permission enforcement
- fix: remove console.log/error from production auth flow
- fix: add CSP, HSTS, Referrer-Policy to nginx config
- fix: replace mock dashboard data with 'unavailable' state
- fix: replace chmod 777 with chown nginx in Dockerfile

Closes: AGENT-19
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No default 'admin' role fallback | grep 'admin' authSlice — no standalone fallback | ✅ |
| No client-side JWT decode | grep 'atob' authSlice — returns 0 | ✅ (typed JWTPayload) |
| Route-level permissions enforced | Staff user cannot access /settings/payment | ⚠️ Partial |
| No console.log in auth flow | grep 'console\.' authSlice App.tsx — returns 0 | ✅ |
| CSP header present in nginx | curl -sI → Content-Security-Policy header exists | ✅ |
| Dashboard shows 'unavailable' when no analytics | Mock data object not in production code | ✅ |
| Dockerfile uses chown not chmod 777 | grep '777' Dockerfile — returns 0 | ✅ |

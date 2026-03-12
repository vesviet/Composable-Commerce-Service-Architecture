# AGENT-20: Admin Dashboard — P1 Architecture & Code Quality

> **Created**: 2026-03-12
> **Priority**: P1 High
> **Sprint**: Tech Debt Sprint
> **Services**: `admin` (React/Vite Frontend)
> **Estimated Effort**: 3-4 days
> **Source**: [Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/36aeb781-a46e-4f67-9c1b-4b231ec8cdde/admin_service_meeting_review.md)

---

## 📋 Overview

Fix 18 P1 High Priority issues covering: API layer inconsistencies, token refresh race conditions, React Error Boundary, hook bugs (useApi infinite loop, useWebSocket memory leak), CSRF handling, audit logging, rate limiting, mixed case conventions, and environment file security. These issues impact stability, maintainability, and operational safety.

---

## ✅ Checklist — P1 Issues

### [x] Task 1: Add React Error Boundary to App.tsx ✅ IMPLEMENTED

**File**: `admin/src/App.tsx`, `admin/src/components/common/ErrorBoundary.tsx` (NEW)
**Risk**: Any lazy-loaded page crash → entire app white screen
**Problem**: No Error Boundary wrapping routes. React error kills entire tree.
**Fix**: Create ErrorBoundary component and wrap `<Suspense>` in App.tsx:
```tsx
// NEW: components/common/ErrorBoundary.tsx
import { Component, ErrorInfo, ReactNode } from 'react';
import { Button, Result } from 'antd';

interface Props { children: ReactNode; }
interface State { hasError: boolean; error?: Error; }

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };
  static getDerivedStateFromError(error: Error): State { return { hasError: true, error }; }
  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('ErrorBoundary:', error, errorInfo);
  }
  render() {
    if (this.state.hasError) {
      return (
        <Result status="error" title="Something went wrong"
          subTitle={this.state.error?.message}
          extra={<Button type="primary" onClick={() => window.location.reload()}>Reload Page</Button>}
        />
      );
    }
    return this.props.children;
  }
}
```
Wrap in App.tsx: `<ErrorBoundary><Suspense>...</Suspense></ErrorBoundary>`

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 2: Fix useApi Hook Infinite Loop Risk ✅ IMPLEMENTED

**File**: `admin/src/hooks/useApi.ts`
**Lines**: 29-60
**Risk**: Inline apiCall function → infinite re-renders → DDoS backend
**Problem**: `execute` depends on `apiCall` in useCallback deps. Inline functions change every render → infinite effect loop.
**Fix**: Use `useRef` to store latest apiCall without triggering re-renders:
```typescript
export function useApi<T = any>(
  apiCall: () => Promise<T>,
  options: UseApiOptions = {}
) {
  const apiCallRef = useRef(apiCall);
  apiCallRef.current = apiCall; // Always keep latest reference

  const execute = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await apiCallRef.current(); // Use ref instead of closure
      // ... rest of logic
    }
  }, []); // No apiCall dependency — stable reference

  // Remove execute from usePaginatedApi effect deps too
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 3: Fix useWebSocket Variable Shadowing Bug + Memory Leak ✅ IMPLEMENTED

**File**: `admin/src/hooks/useWebSocket.ts`
**Lines**: 97, 107-119
**Risk**: Runtime crash when socket not open, constant reconnect loop
**Problem 1**: Variable `message` parameter (line 97) shadows `message` import from antd → calling `message.warning()` on the parameter causes runtime error.
**Problem 2**: `connect` callback recreates on every prop change → effect re-runs → perpetual reconnect.
**Fix**:
```typescript
// Rename parameter to avoid shadowing
const sendMessage = useCallback((data: any) => { // renamed from 'message' to 'data'
  if (socket && readyState === WebSocket.OPEN) {
    const payload = typeof data === 'string' ? data : JSON.stringify(data);
    socket.send(payload);
  } else {
    console.warn('WebSocket is not connected');
    antdMessage.warning('Cannot send: WebSocket not connected');
  }
}, [socket, readyState]);
```
Import antd message with alias: `import { message as antdMessage } from 'antd';`

For memory leak — use refs for callbacks to stabilize `connect`:
```typescript
const onMessageRef = useRef(onMessage);
onMessageRef.current = onMessage;
// Similar for other callback props
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 4: Fix Token Storage Key Mismatch Between Constants and TokenManager ✅ IMPLEMENTED

**File**: `admin/src/utils/constants.ts`, `admin/src/lib/auth/tokenManager.ts`
**Risk**: Code using STORAGE_KEYS.AUTH_TOKEN reads wrong cookie key → auth breaks
**Problem**: constants.ts defines `AUTH_TOKEN: 'admin_auth_token'` but tokenManager uses `'admin_access_token'`. Different keys!
**Fix**: Align all token keys to use single source of truth from tokenManager:
```typescript
// constants.ts — fix to match tokenManager
export const STORAGE_KEYS = {
  AUTH_TOKEN: 'admin_access_token',    // Match tokenManager
  REFRESH_TOKEN: 'admin_refresh_token', // Already matches
  // ... rest
} as const;
```

**Validation**:
```bash
cd admin && grep -rn 'admin_auth_token\|admin_access_token' src/
# All should use 'admin_access_token'
```

---

### [x] Task 5: Fix Logout to Await Server Session Invalidation ✅ IMPLEMENTED

**File**: `admin/src/hooks/useLogout.ts`
**Lines**: 15-27
**Risk**: Token remains valid on server after local logout → session hijacking
**Problem**: `dispatch(logout())` is fire-and-forget. Server session stays active.
**Fix**:
```typescript
const handleLogout = async () => {
  try {
    // Await server logout first to invalidate session
    await dispatch(logout()).unwrap();
  } catch {
    // Even if server logout fails, proceed with local cleanup
  }
  clearTokens();
  queryClient.clear();
  window.location.replace(window.location.origin + '/login');
};
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 6: Remove Access Denied Page Role Disclosure ✅ IMPLEMENTED

**File**: `admin/src/App.tsx`
**Lines**: 155-159
**Risk**: Information disclosure — attacker knows required roles
**Fix**: Remove role details from access denied page:
```tsx
if (!hasAdminRole) {
  return (
    <Layout style={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Result
        status="403"
        title="Access Denied"
        subTitle="You don't have permission to access the admin dashboard. Please contact your administrator."
        extra={<Button type="primary" onClick={handleLogout}>Sign Out</Button>}
      />
    </Layout>
  );
}
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 7: Reduce React Query Retry Count from 3 to 1 ✅ IMPLEMENTED

**File**: `admin/src/main.tsx`
**Lines**: 13-20
**Risk**: User waits 120s (4×30s timeout) before seeing error
**Fix**:
```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,
      retry: 1, // Reduced from 3 — admin dashboard should show error fast
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    },
  },
});
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 8: Increase Health Check Interval from 30s to 120s ✅ IMPLEMENTED

**File**: `admin/src/components/layout/DashboardLayout.tsx`
**Lines**: 90-104
**Risk**: Unnecessary load on gateway — N tabs × 2 requests/min
**Fix**:
```typescript
const interval = setInterval(checkHealth, 120000); // Every 2 minutes instead of 30 seconds
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 9: Remove Duplicate API_ENDPOINTS from constants.ts env.ts ✅ IMPLEMENTED

**File**: `admin/src/utils/constants.ts`
**Lines**: 4-188
**Risk**: Developers use wrong endpoints object → routing bugs
**Problem**: `API_ENDPOINTS` defined in both `utils/constants.ts` and `lib/config/env.ts`. Pages inconsistently use one or the other.
**Fix**: Keep `API_ENDPOINTS` only in `constants.ts` (larger, more complete). Remove duplicate from `env.ts`. Update imports across codebase.

**Validation**:
```bash
cd admin && grep -rn 'from.*env.*API_ENDPOINTS\|from.*constants.*API_ENDPOINTS' src/
```

---

### [x] Task 10: Remove .env.staging and .env.production from Git ✅ IMPLEMENTED

**Files**: `admin/.env.staging`, `admin/.env.production`, `admin/.gitignore`
**Risk**: Environment-specific config exposed in git
**Fix**: Add to `.gitignore` and remove tracked files:
```bash
echo ".env.staging" >> admin/.gitignore
echo ".env.production" >> admin/.gitignore
```

**Validation**:
```bash
grep '.env.staging' admin/.gitignore
grep '.env.production' admin/.gitignore
```

---

### [x] Task 11: Remove Dead Code — Sidebar.tsx and Header.tsx ✅ IMPLEMENTED

**Files**: `admin/src/components/layout/Sidebar.tsx`, `admin/src/components/layout/Header.tsx`
**Risk**: 510 lines dead code, confuses developers
**Problem**: Both files exist but only DashboardLayout.tsx is used (via App.tsx line 169)
**Fix**: Delete both files and any related imports:
```bash
rm admin/src/components/layout/Sidebar.tsx admin/src/components/layout/Header.tsx
```
Also remove any imports of these components (search for unused imports).

**Validation**:
```bash
cd admin && npx tsc --noEmit
# Should compile without errors after removing dead files
```

---

### [x] Task 12: Remove Dead extractServiceName Method from apiClient ✅ IMPLEMENTED

**File**: `admin/src/lib/api/apiClient.ts`
**Lines**: 107-110
**Risk**: Dead code, confusion
**Fix**: Delete the method.

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 13: Remove socket.io-client Dead Dependency ✅ IMPLEMENTED

**File**: `admin/package.json`
**Risk**: +50KB unnecessary bundle size
**Problem**: `socket.io-client` installed but `useWebSocket.ts` uses native WebSocket API.
**Fix**:
```bash
cd admin && npm uninstall socket.io-client
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 14: Fix Sidebar Hardcoded User Info ✅ IMPLEMENTED (via Task 11 — dead file deleted)

**File**: `admin/src/components/layout/DashboardLayout.tsx` (if Sidebar.tsx deleted)
**Risk**: All admins see "Admin User" / "admin@example.com" in sidebar
**Problem**: Sidebar section shows hardcoded text instead of actual user from Redux store.
**Fix**: Already fixed by deleting Sidebar.tsx (Task 11). DashboardLayout.tsx already uses `{user?.name}` (Line 226). Verify no hardcoded user info remains.

**Validation**:
```bash
cd admin && grep -rn 'Admin User\|admin@example.com' src/components/
# Should return 0 results after Sidebar.tsx deleted
```

---

### [x] Task 15: Fix Header Hardcoded Notifications ✅ IMPLEMENTED (via Task 11 — dead file deleted)

**Note**: Header.tsx is being deleted in Task 11 (dead code). DashboardLayout.tsx uses `<NotificationCenter />` component which presumably connects to real backend. Verify NotificationCenter is not hardcoded.

**Validation**:
```bash
cd admin && grep -rn 'count={3}\|New order received\|Low stock alert' src/
# Should return 0 after Header.tsx deleted
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
refactor(admin): P1 architecture & code quality improvements

- feat: add ErrorBoundary component for graceful error handling
- fix: stabilize useApi hook to prevent infinite loops
- fix: resolve useWebSocket variable shadowing and memory leak
- fix: align token storage keys between constants and tokenManager
- fix: await server logout before clearing local state
- fix: remove role disclosure from access denied page
- perf: reduce React Query retries and health check interval
- chore: remove dead code (Sidebar, Header, extractServiceName)
- chore: remove socket.io-client dead dependency
- chore: exclude env files from git

Closes: AGENT-20
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Error Boundary catches page crashes | Navigate to broken route → shows error page, not white screen | |
| useApi no infinite loop | Component using useApi renders without N+1 requests | |
| useWebSocket no shadowing | sendMessage works without runtime error | |
| Token keys aligned | Single key used across codebase | |
| Logout awaits server | Network tab shows logout request completed | |
| No role disclosure | Access denied page shows generic message | |
| React Query retry=1 | Error shown within 60s, not 120s | |
| Health check 120s interval | Network tab shows 2-min intervals | |
| No dead code | Sidebar.tsx, Header.tsx deleted | |
| socket.io-client removed | Not in package.json or node_modules | |

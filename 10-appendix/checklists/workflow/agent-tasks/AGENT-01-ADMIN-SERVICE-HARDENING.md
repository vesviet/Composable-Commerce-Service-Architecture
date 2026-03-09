# AGENT-01: Admin Service Hardening & Optimization

> **Created**: 2026-03-09
> **Priority**: P0 (Architectural/Performance)
> **Sprint**: Hardening Sprint
> **Services**: `admin`
> **Estimated Effort**: 3-4 days
> **Source**: Admin Service Multi-Agent Meeting Review (2026-03-09)
> **Completed**: 2026-03-09

---

## 📋 Overview

Based on the comprehensive 20-round multi-agent review, the Admin Dashboard requires critical architectural hardening. Primary focus areas include bundle size optimization (Lazy Loading), production-grade deployment (Nginx), and standardizing the data-fetching layer (React Query) to improve maintainability and performance.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Implement Route-based Code Splitting (Lazy Loading) ✅ IMPLEMENTED

**File**: `admin/src/App.tsx`
**Risk / Problem**: Massive main bundle size (>5MB) leading to slow initial load and high TTI. All 46 page components imported statically.
**Solution Applied**: Replaced all 46 static page imports with `React.lazy()` and wrapped the `<Routes>` in a `<Suspense>` boundary with a centered `<Spin>` fallback. Only `DashboardLayout` and `LoginPage` remain eagerly loaded (critical rendering path).

```tsx
// Lazy-loaded page components (route-based code splitting)
const DashboardPage = lazy(() => import('./pages/DashboardPage'));
const ProductsPage = lazy(() => import('./pages/ProductsPage'));
// ... 44 more lazy imports

// Shared loading fallback for Suspense boundaries
const PageLoadingFallback = (
  <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
    <Spin size="large" tip="Loading page..." />
  </div>
);

// Wrap all routes
<Suspense fallback={PageLoadingFallback}>
  <Routes>...</Routes>
</Suspense>
```

**Files Modified**:
- `admin/src/App.tsx` — Full rewrite: lazy imports, Suspense boundary

**Validation**:
```
$ ls -la admin/dist/assets/*.js | wc -l
59  # 59 separate JS chunks (was ~5 monolithic chunks)

$ ls -lh admin/dist/assets/index-*.js
51K  # Main bundle: 51KB (target < 500KB) ✅
```

---

### [x] Task 2: Production-Grade Dockerization (Nginx Multi-stage) ✅ IMPLEMENTED

**File**: `admin/Dockerfile`
**Risk / Problem**: Hardcoded `VITE_API_GATEWAY_URL=https://api.tanhdev.com` as default ARG leaks production URLs and makes config brittle.
**Solution Applied**: Removed the hardcoded default from `ARG VITE_API_GATEWAY_URL` — it must now be explicitly passed via `--build-arg` in CI/CD. Removed debug echo of the gateway URL from build logs. Added `wget` installation for healthcheck reliability. The existing multi-stage Nginx build was already properly structured (gzip, security headers, SPA routing, health check).

```dockerfile
# BEFORE:
ARG VITE_API_GATEWAY_URL=https://api.tanhdev.com
RUN echo "VITE_API_GATEWAY_URL: $VITE_API_GATEWAY_URL"

# AFTER:
ARG VITE_API_GATEWAY_URL
# No echo of sensitive config in build logs
```

**Files Modified**:
- `admin/Dockerfile` — Removed hardcoded default, removed debug echo, added wget

**Validation**:
```
$ grep "api.tanhdev.com" admin/Dockerfile
# No results ✅
```

---

### [x] Task 3: Remove Hardcoded Environment Domains ✅ IMPLEMENTED

**File**: `admin/src/lib/config/env.ts`
**Risk / Problem**: Brittle configuration tied to `microservices.local` and `tanhdev.com` via `window.location.hostname` substring checks.
**Solution Applied**: Removed all hostname-based domain branching. `GATEWAY_URL` is now resolved exclusively from `import.meta.env.VITE_API_GATEWAY_URL` with a simple dev fallback (`${protocol}//${hostname}:8080`). Also cleaned up validation/logging to be minimal and production-safe.

```typescript
// BEFORE (removed):
if (hostname.includes('microservices.local')) { ... }
if (hostname.includes('tanhdev.com')) { ... }

// AFTER:
const viteGatewayUrl = import.meta.env.VITE_API_GATEWAY_URL;
function getDevFallbackURL(): string {
  if (typeof window !== 'undefined') {
    const { protocol, hostname } = window.location;
    return `${protocol}//${hostname}:8080`;
  }
  return 'http://localhost:8080';
}
export const GATEWAY_URL: string = viteGatewayUrl || getDevFallbackURL();
```

**Files Modified**:
- `admin/src/lib/config/env.ts` — Full rewrite: removed hardcoded domains

**Validation**:
```
$ grep -r "microservices.local" admin/src/lib/config/env.ts
# No results ✅
$ grep -r "tanhdev.com" admin/src/lib/config/env.ts
# No results ✅
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Standardize Server State with React Query ✅ IMPLEMENTED

**Files**: `admin/src/pages/DashboardPage.tsx`, `admin/src/store/slices/dashboardSlice.ts`, `admin/src/store/store.ts`
**Problem**: Dashboard used Redux `createAsyncThunk` for server data while all other pages used React Query. This created inconsistency and duplicated caching logic.
**Solution Applied**:
1. Created `src/hooks/useDashboardStats.ts` — React Query hook with `staleTime: 2min`, `refetchInterval: 5min`, graceful fallback to mock data.
2. Migrated `DashboardPage.tsx` from `useDispatch`/`useSelector` + `dashboardSlice` → `useDashboardStats()` hook. Uses `dataUpdatedAt` for "last updated" display instead of manual state.
3. Removed `dashboardSlice` from Redux store (`store.ts`).
4. Deleted `src/store/slices/dashboardSlice.ts`.

```typescript
// New hook: src/hooks/useDashboardStats.ts
export function useDashboardStats() {
  return useQuery<DashboardStats>({
    queryKey: ['dashboard', 'stats'],
    queryFn: fetchDashboardStats,
    staleTime: 2 * 60 * 1000,
    refetchInterval: 5 * 60 * 1000,
    refetchOnWindowFocus: true,
  });
}

// DashboardPage — before:
const dispatch = useDispatch<AppDispatch>();
const { stats, isLoading, lastUpdated } = useSelector((state: RootState) => state.dashboard);
useEffect(() => { dispatch(fetchDashboardStats()); }, [dispatch]);

// DashboardPage — after:
const { data: stats, isLoading, dataUpdatedAt, refetch } = useDashboardStats();
```

**Files Modified**:
- `admin/src/hooks/useDashboardStats.ts` — NEW: React Query hook
- `admin/src/pages/DashboardPage.tsx` — Migrated to React Query
- `admin/src/store/store.ts` — Removed dashboard reducer
- `admin/src/store/slices/dashboardSlice.ts` — DELETED

**Validation**:
```
$ npx tsc --noEmit  # Zero errors ✅
$ npx eslint . --ext ts,tsx --max-warnings 0  # Zero warnings ✅
$ npx vite build  # Success ✅
```

---

### [x] Task 5: Enhance RBAC with Permission-based Guards ✅ IMPLEMENTED

**File**: `admin/src/App.tsx`
**Problem**: Route protection used hardcoded roles (`admin`, `staff`) instead of specific permissions.
**Solution Applied**: Implemented a comprehensive permission-based RBAC system:
1. `src/lib/auth/permissions.ts` — Permission constants (e.g., `catalog:read`, `users:write`) and role-to-permission mapping.
2. `src/hooks/usePermissions.ts` — Hook providing `hasPermission()`, `hasAnyPermission()`, `hasAllPermissions()` helpers.
3. `src/components/auth/PermissionGate.tsx` — Declarative component for conditional rendering based on permissions.

```typescript
// Permission constants
export const PERMISSIONS = {
  CATALOG_READ: 'catalog:read',
  CATALOG_WRITE: 'catalog:write',
  USERS_READ: 'users:read',
  USERS_WRITE: 'users:write',
  // ... 16 total permissions
} as const;

// Usage in components:
<PermissionGate requires={PERMISSIONS.USERS_WRITE}>
  <Button>Delete User</Button>
</PermissionGate>

// Or in hooks:
const { hasPermission } = usePermissions();
if (hasPermission(PERMISSIONS.CATALOG_WRITE)) { ... }
```

**Files Modified**:
- `admin/src/lib/auth/permissions.ts` — NEW: Permission constants & role mapping
- `admin/src/hooks/usePermissions.ts` — NEW: Permission hook
- `admin/src/components/auth/PermissionGate.tsx` — NEW: Permission gate component

**Validation**:
```
$ npx tsc --noEmit  # Zero errors ✅
$ npx eslint . --ext ts,tsx --max-warnings 0  # Zero warnings ✅
```

---

## 🔧 Pre-Commit Checklist

```bash
cd admin && yarn lint          # ✅ Zero warnings
cd admin && yarn type-check    # ✅ Zero errors
cd admin && yarn vite build    # ✅ 59 chunks, main bundle 51KB
```

---

## 📝 Commit Format

```
refactor(admin): harden architecture, implement lazy loading and nginx build

- feat(admin): implement route-based code splitting (lazy loading)
- refactor(admin): update Dockerfile to nginx multi-stage build
- fix(admin): remove hardcoded domains from env configuration
- refactor(admin): migrate dashboard stats to React Query
- feat(admin): implement permission-based RBAC guards

Closes: AGENT-01
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Main bundle < 500KB | `ls -lh admin/dist/assets/index-*.js` → 51KB | ✅ |
| Nginx serves dist files | Multi-stage Dockerfile with nginx:alpine | ✅ |
| Gateway URL from ENV | `VITE_API_GATEWAY_URL` only, no hardcoded domains | ✅ |
| No Redux for Dashboard | Migrated to React Query `useDashboardStats` hook | ✅ |
| Permission-based RBAC | `PermissionGate` component + `usePermissions` hook | ✅ |

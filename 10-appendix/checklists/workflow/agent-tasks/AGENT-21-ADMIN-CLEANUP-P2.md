# AGENT-21: Admin Dashboard — P2 Cleanup & Nice-to-Have

> **Created**: 2026-03-12
> **Priority**: P2 Nice-to-Have
> **Sprint**: Backlog
> **Services**: `admin` (React/Vite Frontend)
> **Estimated Effort**: 2 days
> **Source**: [Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/36aeb781-a46e-4f67-9c1b-4b231ec8cdde/admin_service_meeting_review.md)

---

## 📋 Overview

12 P2 improvements for admin dashboard: eliminate `any` types, fix duplicated code, replace hardcoded geographic data with API calls, fix normalizeStatus semantics, and clean up minor inconsistencies.

---

## ✅ Checklist — P2 Issues

### [ ] Task 1: Replace `any` Types with Proper Interfaces (~20 instances)

**Files**: Multiple — authSlice.ts, useApi.ts, apiClient.ts, catalog-api.ts, operations-api.ts, menuConfig.ts
**Risk**: Type safety holes → runtime errors
**Fix**: Create proper interfaces for JWT payload, API responses, and hook generics. Key changes:
- `authSlice.ts decodeJWT(): any` → `decodeJWT(): JWTPayload | null` with interface
- `useApi<T = any>` → `useApi<T = unknown>` (force callers to specify type)
- `useApi state: any` → typed state
- `catalog-api searchProducts(): Promise<any[]>` → `Promise<ProductSearchResult[]>`

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 2: Deduplicate CSV Parser in useCSVValidation ✅ IMPLEMENTED

**File**: `admin/src/hooks/useCSVValidation.ts`
**Lines**: 17-35, 57-74
**Risk**: DRY violation — same parseLine duplicated in same file
**Fix**: Extract `parseLine` as standalone utility:
```typescript
function parseLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') { inQuotes = !inQuotes; }
    else if (char === ',' && !inQuotes) { result.push(current.trim()); current = ''; }
    else { current += char; }
  }
  result.push(current.trim());
  return result;
}
```
Use in both `parseCSV()` and `validateFile()`.

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 3: Replace Hardcoded Country/Region Data with Location API ✅ IMPLEMENTED

**File**: `admin/src/lib/api/catalog-api.ts`
**Lines**: 294-378
**Risk**: Geographic targeting broken for non-US markets
**Fix**: Replace `getCountries()` and `getRegions()` with calls to location service:
```typescript
import { listLocations } from './location-api';

export async function getCountries(): Promise<Array<{code: string; name: string}>> {
  try {
    const response = await listLocations({ type: 'country', page: 1, pageSize: 300 });
    return response.data.map(loc => ({ code: loc.code, name: loc.name }));
  } catch {
    console.warn('Location service unavailable, using fallback');
    return FALLBACK_COUNTRIES; // Keep existing as fallback only
  }
}
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 4: Replace Hardcoded Customer Groups with API ✅ IMPLEMENTED

**File**: `admin/src/lib/api/catalog-api.ts`
**Lines**: 272-286
**Risk**: Visibility rule mismatch when backend group names differ
**Fix**: Keep API call as primary, fallback returns empty with warning:
```typescript
export async function getCustomerGroups(): Promise<string[]> {
  try {
    const response = await apiClient.callCustomerService('/v1/customer-groups');
    return response.data.groups || [];
  } catch {
    console.warn('Customer groups unavailable — dynamic groups may not be available');
    return []; // Empty instead of fake data — UI should handle empty state
  }
}
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 5: Fix normalizeStatus Return for Non-User Statuses ✅ IMPLEMENTED

**File**: `admin/src/utils/constants.ts`
**Lines**: 514-573
**Risk**: Fulfillment status "picking" normalizes to "inactive" — semantically wrong
**Fix**: Remove user-specific fallback logic. Return the status as-is if it's a known status from ANY domain:
```typescript
export function normalizeStatus(status: string | number | undefined, prefix?: string): string {
  if (status === undefined || status === null) return 'unknown';
  if (typeof status === 'number') {
    return USER_STATUS_ENUM_TO_STRING[status] || 'unknown';
  }
  if (typeof status !== 'string') return 'unknown';
  
  let normalized = status.trim();
  if (prefix) {
    normalized = normalized.replace(new RegExp(`^${prefix}`, 'i'), '');
  } else {
    normalized = normalized.replace(/^(USER_|PRODUCT_|ORDER_|PAYMENT_|...)?STATUS_/i, '');
  }
  return normalized.toLowerCase() || 'unknown';
}
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 6: Remove Demo Credentials Environment Check Risk ✅ IMPLEMENTED

**File**: `admin/src/pages/LoginPage.tsx`
**Lines**: 123-137
**Risk**: Weak credentials visible in dev, potential social engineering
**Fix**: Remove hardcoded password. Use placeholder text instead:
```tsx
{import.meta.env.DEV && (
  <div style={{ marginTop: 24, padding: 16, background: '#f5f5f5', borderRadius: 6 }}>
    <Text type="secondary" style={{ fontSize: '12px' }}>
      Development mode — use dev credentials from .env.local
    </Text>
  </div>
)}
```

**Validation**: `cd admin && npx tsc --noEmit`

---

### [x] Task 7: Remove Unused Icon Imports from DashboardLayout ✅ IMPLEMENTED

**File**: `admin/src/components/layout/DashboardLayout.tsx`
**Lines**: 6-26
**Risk**: Unused imports increase bundle size
**Problem**: Multiple imported icons not used directly (menu items come from menuConfig.ts)
**Fix**: Remove unused icon imports:
```typescript
import {
  UserOutlined,
  SettingOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
} from '@ant-design/icons';
// Remove: DashboardOutlined, ShoppingOutlined, ShoppingCartOutlined, etc.
```

**Validation**: `cd admin && npx tsc --noEmit`

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
refactor(admin): P2 cleanup — types, DRY, hardcoded data, dead imports

- refactor: replace any types with proper interfaces
- refactor: deduplicate CSV parser in useCSVValidation
- refactor: use location API instead of hardcoded countries
- fix: normalizeStatus returns 'unknown' instead of 'inactive' for non-user domains
- chore: remove demo credentials display
- chore: remove unused icon imports

Closes: AGENT-21
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No `any` in hook/auth layer | grep 'any' in target files — reduced count | |
| Single parseLine function | grep parseLine useCSVValidation — only 1 definition | |
| Countries from location API | getCountries calls location service | |
| normalizeStatus correct | 'picking' normalizes to 'picking' not 'inactive' | |
| No demo password in code | grep 'admin123' — returns 0 | |
| No unused imports | tsc --noEmit passes cleanly | |

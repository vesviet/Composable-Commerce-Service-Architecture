# AGENT-03: Customer & Identity Flow Issues

> **Created**: 2026-03-21
> **Priority**: P0 + P1 + P2
> **Sprint**: Bug Fix Sprint
> **Services**: `frontend`, `customer`, `auth`, `gateway`
> **Estimated Effort**: 1-2 days
> **Source**: Manual + Automated QA Testing on `https://frontend.tanhdev.com/`

---

## 📋 Overview

QA testing of Customer & Identity flows (Registration, Login, Account, Address, Logout) on `frontend.tanhdev.com` uncovered 5 issues: 1 P0 data mapping bug, 1 P1 session handling bug, and 3 P2/P3 UX issues.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Gender Enum Mismatch in Profile Save ✅

**File**: `frontend/src/components/account/ProfileSection.tsx`
**Lines**: 18, 61, 86
**Risk**: Profile save silently fails or shows validation error when gender is set. The form breaks on reload if backend returns `CUSTOMER_GENDER_FEMALE`.

**Problem**: Backend (customer service) returns gender as `CUSTOMER_GENDER_FEMALE`, `CUSTOMER_GENDER_MALE`, etc. But the frontend zod schema (line 18) validates against `MALE | FEMALE | OTHER | CUSTOMER_GENDER_UNSPECIFIED`. When the form loads customer data (line 61), `customer.gender` = `CUSTOMER_GENDER_FEMALE` fails zod validation silently. When saving (line 86), the frontend sends `FEMALE` but the backend may expect the prefixed variant.

```tsx
// BEFORE (line 18):
gender: z.enum(['MALE', 'FEMALE', 'OTHER', 'CUSTOMER_GENDER_UNSPECIFIED']).optional(),

// BEFORE (line 61):
gender: customer.gender || 'CUSTOMER_GENDER_UNSPECIFIED',

// AFTER (line 18) — accept both formats:
gender: z.enum([
  'MALE', 'FEMALE', 'OTHER', 'CUSTOMER_GENDER_UNSPECIFIED',
  'CUSTOMER_GENDER_MALE', 'CUSTOMER_GENDER_FEMALE', 'CUSTOMER_GENDER_OTHER'
]).optional(),

// AFTER (line 61) — normalize backend values:
gender: normalizeGender(customer.gender),
```

Add normalization helper:
```tsx
function normalizeGender(gender?: string): string {
  const map: Record<string, string> = {
    'CUSTOMER_GENDER_MALE': 'MALE',
    'CUSTOMER_GENDER_FEMALE': 'FEMALE',
    'CUSTOMER_GENDER_OTHER': 'OTHER',
    'CUSTOMER_GENDER_UNSPECIFIED': 'CUSTOMER_GENDER_UNSPECIFIED',
  };
  return map[gender || ''] || gender || 'CUSTOMER_GENDER_UNSPECIFIED';
}
```

**Validation**:
```bash
cd frontend && npm run build
# Automated test:
cd qa-auto && npx playwright test -g "TC-PROFILE-04"
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Fix Stale Session Token Blocking Login ✅ IMPLEMENTED — Added `refreshAttempted` ref guard in auth-context to prevent infinite check loops, and timeout-reset on `redirectingToLogin` flag in api-client.

**Files**: `frontend/src/lib/api/api-client.ts`, `frontend/src/lib/auth/auth-context.tsx`
**Risk**: Users with expired tokens get stuck showing "Your session is invalid. Please sign in again" error loop. Login is impossible until localStorage is manually cleared.

**Problem**: When the token refresh call (`POST /api/v1/auth/tokens/refresh`) returns `401`, the API client does not clear localStorage tokens. The auth context re-reads stale tokens on page load, hitting the same 401 loop. Manual `localStorage.clear()` is the only workaround.

**Fix**: In the API interceptor's 401 handler:
```typescript
// When refresh token also fails (401 on refresh):
if (error.config?.url?.includes('/tokens/refresh')) {
  localStorage.removeItem('token');
  localStorage.removeItem('refreshToken');
  window.location.href = '/login';
  return Promise.reject(error);
}
```

**Validation**:
```bash
# Set stale tokens manually, navigate to /login, verify auto-clear
cd qa-auto && npx playwright test -g "TC-LOGIN-06"
```

---

### [ ] Task 3: Fix Products Not Visible for Guest Users

**Files**: `frontend/src/app/page.tsx` or `frontend/src/components/home/FeaturedProducts.tsx`
**Risk**: New visitors see "No products found" on homepage — terrible first impression, potential revenue loss.

**Problem**: Featured products API call returns empty for unauthenticated users. The cart API returns `403 Forbidden`. The product listing should be publicly accessible without authentication.

**Fix**: Ensure the featured products API call does NOT require auth token, OR handle the unauthenticated case by using a public endpoint:
```typescript
// Use public catalog endpoint for featured products
const response = await fetch(`${API_URL}/api/v1/catalog/products?featured=true&limit=8`, {
  // No Authorization header for public product listing
});
```

Also check gateway routes: ensure `/api/v1/catalog/products` is in the public (no-auth) whitelist.

**Validation**:
```bash
# Open homepage without login, verify products visible
cd qa-auto && npx playwright test -g "TC-LOGIN-01"
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 4: Improve Address Save UX Feedback ✅ (Already implemented)

**File**: `frontend/src/components/account/AddressSection.tsx`
**Risk**: User submits address form, sees "Saving..." but no success/error toast — unclear if save worked.

**Fix**: Add success toast after address API call resolves:
```typescript
toast.success('Address added successfully');
// Refresh address list
await loadAddresses();
```

**Validation**:
```bash
cd qa-auto && npx playwright test -g "TC-ADDR-04"
```

---

### [x] Task 5: Add Footer to Frontend ✅

**File**: `frontend/src/components/layout/Footer.tsx` (likely new)
**Risk**: Missing footer means no navigation/company info/legal links — impacts SEO and user trust.

**Fix**: Create footer component with: Company info, links (About, Contact, Terms, Privacy), social media links.

---

## 🔧 Pre-Commit Checklist

```bash
cd frontend && npm run lint
cd frontend && npm run build
cd qa-auto && npx playwright test tests/customer-identity/
```

---

## 📝 Commit Format

```
fix(frontend): fix gender enum mismatch and stale session handling

- fix: normalize gender enum from backend CUSTOMER_GENDER_* format
- fix: clear stale tokens on refresh failure to prevent login loop
- fix: show products to guest users on homepage

Closes: AGENT-03 (Tasks 1-3)
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Profile save with gender works | Select Female → Save → Reload → Gender still Female | |
| Login works with stale tokens | Set expired token → Navigate to /login → Auto-clears → Login succeeds | |
| Guest users see products | Open homepage without login → Products visible | |
| Address save shows feedback | Add address → Success toast appears | |
| All 21 E2E tests pass | `cd qa-auto && npx playwright test tests/customer-identity/` | |

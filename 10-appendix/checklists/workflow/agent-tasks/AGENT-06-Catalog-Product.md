# AGENT-06: Fix Catalog Rendering and Admin Edit Permissions

> **Created**: 2026-03-31
> **Priority**: P0 (blocking/critical)
> **Sprint**: Tech Debt Sprint
> **Services**: `catalog`, `frontend`
> **Estimated Effort**: 2-3 days
> **Source**: QA Automation Run Flow 2 (Catalog & Product)

---

## 📋 Overview

During E2E testing of the Catalog & Product flows, several critical presentation and RBAC issues were identified. On the frontend, categories are displaying raw UUIDs instead of names, product images are returning 400 Bad Request through the Next.js optimizer, and guest users are blocked from viewing reviews (401). On the Admin portal, updating a product returns a `403 Forbidden (INSUFFICIENT_PERMISSIONS)` despite the user holding wildcard `system_admin` roles. 

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix 403 Forbidden for System Admin Editing Products

**File**: `catalog/internal/service/product.go` (or `api/catalog/v1/product.proto` / `middleware/auth`)
**Lines**: `UpdateProduct` handler or authorization middleware
**Risk**: Platform administrators are completely blocked from managing catalog items.
**Problem**: The RBAC system is explicitly expecting the literal role `admin` while the user's token contains `system_admin` and wildcard `[*]`. The permission evaluator fails to recognize wildcard or super-admin hierarchies.
**Fix**:
```go
// BEFORE (example in middleware or interceptor):
if !hasRole(claims.Roles, "admin") {
    return status.Error(codes.PermissionDenied, "INSUFFICIENT_PERMISSIONS")
}

// AFTER:
// Ensure RBAC evaluator honors `system_admin` or wildcard pointers correctly.
if !hasRole(claims.Roles, "admin") && !hasRole(claims.Roles, "system_admin") && !hasPermission(claims.Permissions, "*") {
    return status.Error(codes.PermissionDenied, "INSUFFICIENT_PERMISSIONS")
}
```

**Validation**:
```bash
curl -X PUT https://api.tanhdev.com/api/v1/catalog/products/test-id -H "Authorization: Bearer <SYSTEM_ADMIN_TOKEN>" -d '{"name":"Classic Set 9350 [TEST]"}'
# Expect HTTP 200 OK
```

---

### [ ] Task 2: Fix Raw UUIDs Displaying in Frontend Category Sidebar

**File**: `frontend/src/components/catalog/CategorySidebar.tsx` (OR `catalog` service aggregation)
**Lines**: Category mapping logic
**Risk**: Degraded UX; customers cannot understand what category they are filtering by.
**Problem**: The products API or category aggregation API is returning `c0000000-0003-4000-a000-000000000015` instead of resolving to the translated Category Name.
**Fix**:
```typescript
// BEFORE:
{categories.map(cat => (
    <label>{cat.id}</label> // or cat.name when name equals ID due to poor backend aggregation
))}

// AFTER:
// Backend must JOIN the category table or Frontend must look up the correct translation map.
{categories.map(cat => (
    <label>{cat.name || resolveCategoryName(cat.id)}</label>
))}
```

**Validation**:
```bash
# Verify the backend search/aggregation returns the human-readable `name` alongside `id`.
curl -X GET https://api.tanhdev.com/api/v1/search/products
```

---

### [ ] Task 3: Fix 401 Unauthorized for Guest Users on Product Reviews

**File**: `review/internal/service/review.go` or Gateway routing
**Lines**: `ListProductReviews` API
**Risk**: SEO and conversion rate drop because unauthenticated users cannot see social proof (reviews).
**Problem**: The `GET /api/v1/reviews/product/{id}` route is inadvertently wrapped in an authentication middleware, returning 401 for guests.
**Fix**:
```go
// BEFORE: 
// In gateway or service auth middleware
// All `/api/v1/reviews/*` routes require auth.

// AFTER:
// Whitelist `GET /api/v1/reviews/product/*` to allow anonymous access.
// Only `POST /api/v1/reviews` (create review) requires authentication.
```

**Validation**:
```bash
curl -X GET https://api.tanhdev.com/api/v1/reviews/product/test-id
# Expect HTTP 200 OK for guest (no auth header)
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 4: Handle Missing Product Images Gracefully (400 Bad Request)

**File**: `frontend/src/components/product/ProductCard.tsx` / `Next.js config`
**Lines**: `<Image>` component handling
**Risk**: Broken images ruin the storefront aesthetic.
**Problem**: The Next.js image optimizer returns `400 Bad Request` because the source images (e.g. `/images/products/BLK-009350-1.jpg`) do not exist or are an unsupported type.
**Fix**:
```typescript
// Add an fallback/onError handler to standard Next.js Image component
<Image 
  src={imgSrc} 
  onError={() => setImgSrc('/images/placeholders/product-fail.png')} 
  alt={product.name} 
/>
// Additionally, verify if the backend seed data needs regenerating to fix broken image URLs.
```

**Validation**:
```bash
# Browse frontend; images should display a local placeholder instead of a broken icon.
```

---

## 🔧 Pre-Commit Checklist

```bash
cd catalog && go test -race ./...
cd frontend && npm run lint
```

---

## 📝 Commit Format

```text
fix(catalog): resolve admin edit permissions and frontend category display

- fix: update RBAC evaluator to respect system_admin and wildcards
- fix: resolve category UUID mapping to names in search filters
- fix(review): whitelist GET /product-reviews for guest access
- fix(frontend): add fallback handler for Next.js image optimizer 400s

Closes: AGENT-06
```

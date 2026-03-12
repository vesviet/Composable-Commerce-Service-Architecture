# AGENT-28FRONTEND-HARDENING

## 📝 Overview
This task tracks the critical performance, security, and architectural issues discovered during the Multi-Agent Meeting Review of the `frontend` Next.js service. The objective is to bring the UI service up to production-grade standards, resolving P0 security flaws with JWT handling and P1 edge cases in the Cart/Checkout flow.

## 📋 Assigned Tasks

### [ ] Task 1: Migrate to HttpOnly BFF Auth Pattern (P0)
**Files**: `src/middleware.ts`, `src/app/(auth)/api/auth/route.ts` (to be created), `src/lib/api/auth.ts`
**Risk / Problem**: Storing JWT access tokens in `localStorage` or accessible cookies exposes them to XSS and prevents Next.js Server Components / Middleware from securely attaching headers.
**Required Action**: 
- Create a Next.js API route (`/api/auth/login`) that acts as a proxy to Kratos, returning HTTP-only, Secure cookies.
- Update `middleware.ts` to read the cookie and protect `/account` and `/checkout`.
- Ensure the frontend API client automatically attaches credentials so interceptors don't need to manually read `localStorage`.

### [ ] Task 2: Implement Redis Cache Handler for Next.js ISR (P0)
**Files**: `next.config.js`, `src/lib/cache/redis-cache.js`
**Risk / Problem**: In a K8s multi-pod environment, default Next.js file-system cache causes data inconsistency across pods because ISR static file rebuilds aren't shared. 
**Required Action**:
- Implement a custom cache handler utilizing `ioredis` to store and retrieve Next.js App Router cache data.
- Update `next.config.js` to point `cacheHandler` to the new Redis implementation.

### [ ] Task 3: Enforce Checkout Idempotency (P1)
**Files**: `src/app/checkout/page.tsx`, `src/lib/api/checkout.ts`
**Risk / Problem**: Network drops or rapid double-clicking during checkout can cause multiple parallel charge requests to the backend, double-charging the user.
**Required Action**:
- Generate an `Idempotency-Key` (e.g., UUID + CartID) when the checkout page mounts.
- Pass it in the HTTP headers using Axios interceptors or fetch options.
- Disable the "Confirm" button immediately on submission to minimize parallel events on the UI itself.

### [ ] Task 4: Move Domain Data to React Query & Purge Zustand (P1)
**Files**: `src/components/cart/`, `src/contexts/cart-store.ts`
**Risk / Problem**: Syncing server domain state (i.e. Cart items) into Zustand leads to stale client caches and synchronization bugs when opening multiple tabs.
**Required Action**:
- Strip cart items and product lists out of Zustand.
- Use `@tanstack/react-query` exclusively for these entities, ensuring `refetchOnWindowFocus` is enabled.
- Zustand should purely hold UI volatile states like `isCartOpen`.

### [ ] Task 5: Add `<Suspense>` Boundaries to Catalog for LCP (P1)
**Files**: `src/app/products/page.tsx`, `src/components/products/ProductGrid.tsx`
**Risk / Problem**: SSR blocks TTFB (Time To First Byte) downloading the full HTML of 25k+ SKUs.
**Required Action**:
- Wrap `ProductGrid.tsx` in a `<Suspense fallback={<ProductSkeleton />}>` boundary inside the server component layout.
- Ensure the shell (navigation, filters) loads instantly.

---

## 🔧 Pre-Commit Checklist
- [ ] `cd frontend && npm run build` passes.
- [ ] `cd frontend && npm run type-check` (tsc) passes with zero errors.
- [ ] `cd frontend && npm run lint` passes without warnings.

## 📝 Commit Format
```text
fix(frontend): harden frontend security and performance (AGENT-28)

- Implemented HttpOnly BFF authentication
- Configured Redis as the shared Next.js ISR cache for Kubernetes 
- Added Request Idempotency to Checkout to prevent double-charges
- Fixed React Query state domain boundaries
- Added Suspense boundaries for catalog LCP improvement
```

## ✅ Acceptance Criteria
| Criteria | Status |
|----------|--------|
| `middleware.ts` reads secure HttpOnly cookies, not exposed tokens. | |
| Custom Redis cache handler is wired in `next.config.js`. | |
| Checkout network requests send a unique `Idempotency-Key`. | |
| Zustand no longer stores domain entities like `cart.items`. | |
| Product pages stream the heavy list via `<Suspense>`. | |

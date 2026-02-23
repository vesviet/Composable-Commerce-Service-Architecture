# Cart Management Flow - Issues, Index, Plan & Fixes

**Last Updated**: 2026-01-20  
**Scope**: Order Service cart/checkout flow (`order/internal/biz/cart/*`)

This document tracks review findings for the Cart Management Flow and provides a **repeatable verification plan** (API calls, required headers, expected outcomes).

---

## 🚩 PENDING ISSUES (Unfixed)

### High Priority
- None.

## 🆕 NEWLY DISCOVERED ISSUES

### DevOps/K8s
- [Debugging] **CART-NEW-03 Dev K8s Debugging Steps Missing**: Cart flow checklist lacks standard troubleshooting commands. **Suggested fix**: Add section with kubectl logs, exec, port-forward, and stern examples for order service in dev namespace.
  - **Status**: ✅ **FIXED** (2026-01-21) - Added comprehensive Dev K8s debugging section with kubectl logs, exec, port-forward, stern commands, database queries, and troubleshooting examples for cart flow debugging in development namespace.

## ✅ RESOLVED / FIXED

- [FIXED ✅] **CART-P1-03 Data Race in AddToCart ErrGroup**: Refactored errgroup to return errors directly and removed shared error variables.
- [FIXED ✅] **CART-NEW-01 ErrGroup variable capture**: Eliminated outer-scope error assignment in goroutines.
- [FIXED ✅] **CART-NEW-02 Currency fallback comment inconsistency**: Comment clarified to match behavior.
- [FIXED ✅] **CART-P2-02 Currency fallback**: Now uses `constants.DefaultCurrency` in `AddToCart`, `UpdateCartItem`, and `ValidateCart`. Verified in `order/internal/biz/cart/add.go` line 106, constants import at line 10.
- [FIXED ✅] **P0-01 Unmanaged goroutine for event publishing**: Event publishing now uses `context.WithTimeout(..., 5s)` (synchronous), and `publishAddToCartEvents(...)` is a no-op kept for backward compatibility. Verified in `order/internal/biz/cart/add.go` lines 286-287.
- [FIXED ✅] **P1-01 Cart item updates not atomic**: Transaction + `LoadCartForUpdate` locking implemented. Verified in `order/internal/biz/cart/add.go` lines 198-203 with SELECT FOR UPDATE pattern.
- [FIXED ✅] **P1-02 Cart totals calculation silent failures**: Current implementation returns errors when shipping/promotions/tax calls fail. No silent failures remain.
- [FIXED ✅] **P2-01 CountryCode hardcoded to VN**: Centralized in `constants.DefaultCountryCode`. All cart flows use the constant. Verified in `order/internal/constants/constants.go`.

---

## Index

- **P0**
  - **P0-01**: Unmanaged goroutine for event publishing in AddToCart (**Status: ✅ Not applicable / already fixed**)
- **P1**
  - **P1-01**: Cart item updates not atomic under concurrency (**Status: ✅ Fixed**)
  - **P1-02**: Cart totals calculation silently ignores dependency failures (**Status: ✅ Fixed**)
- **P2**
  - **P2-01**: CountryCode defaults hardcoded to `VN` causing pricing/tax mismatch (**Status: ✅ Fixed**)

---

## P0-01 - Concurrency / Reliability

- **Issue**: Unmanaged goroutine for event publishing in AddToCart.
  - **Service**: `order`
  - **Location**: `order/internal/biz/cart/add.go`
  - **Status**: ✅ **Not applicable / already fixed**
  - **Evidence**:
    - `AddToCart` publishes via `context.WithTimeout(..., 5s)` (synchronous call).
    - `publishAddToCartEvents(...)` is currently a no-op (kept for backward compatibility).
  - **Action**: None (keep doc in sync with code).

---

## P2-01 - Correctness / Context (CountryCode propagation)

- **Issue**: CountryCode default was hardcoded to `VN` in multiple cart flows, which can produce incorrect pricing/tax for non-VN customers.
  - **Service**: `order`
  - **Locations (before fix)**:
    - `order/internal/biz/cart/add.go`
    - `order/internal/biz/cart/helpers_internal.go` (new session defaults)
    - `order/internal/biz/cart/validate.go`
    - `order/internal/biz/cart/totals.go`
    - `order/internal/biz/cart/update.go`
    - `order/internal/biz/cart/sync.go`
  - **Impact**:
    - Wrong pricing rules (final price, discounts) for non-VN.
    - Wrong tax jurisdiction (compliance/revenue risk).
  - **Fix Applied (2026-01-19)**:
    - Centralized fallback into `order/internal/constants/constants.go` as `constants.DefaultCountryCode`.
    - `AddToCart` now **prefers `req.CountryCode`**, then cart session, then fallback constant.
    - All other cart flows now use `constants.DefaultCountryCode` (no hardcoded `"VN"`).

### Verification Plan

**Preconditions**
- Gateway routes are available for Order Service.
- Pricing service is reachable and returns different results for different country codes (or at minimum logs/accepts the country code parameter).

**Test A: AddToCart respects request country code**
- Call `POST /api/v1/cart/items`
- Headers:
  - `X-Session-ID`: `<session-id>`
  - `X-Guest-Token`: `<guest-token>` (if guest)
  - (optional) `X-Customer-ID`: `<customer-uuid>` (if authenticated)
- Body:
  - `product_sku`: `<sku>`
  - `quantity`: 1
  - `warehouse_id`: `<warehouse-uuid>`
  - `currency`: `USD`
  - `country_code`: `US`
- Expected:
  - Pricing service receives `countryCode=US` (verify via logs or mock).
  - Response 200 and cart item reflects the calculated unit/total prices.

**Test B: ValidateCart uses cart CountryCode**
- Call `GET /api/v1/cart/validate`
- Expected:
  - Pricing checks use `cart.CountryCode` or fallback constant if missing.

**Test C: Totals uses country code and fails on tax error**
- Ensure shipping address has a non-VN country code and run:
  - `POST /api/v1/cart/refresh` (or totals-calculation path used by UI)
- Expected:
  - Tax calculation uses shipping country/state/postcode when present.
  - If tax dependency fails, the endpoint returns an error (not silent 0).

---

## P1-01 - Concurrency / Data Integrity

- **Issue**: Cart item updates are not atomic and are vulnerable to race conditions. **Status: ✅ Fixed**
  - **Service**: `order`
  - **Location**: `order/internal/biz/cart/add.go`, `order/internal/biz/cart/update.go`
  - **Impact**: The `Read-Then-Write` pattern can lead to incorrect quantities and totals under concurrent requests.
  - **Fix**: Transaction + `LoadCartForUpdate` lock for serialized updates in add/update flows.

### Verification Plan (Concurrency)
- Fire 20 parallel `POST /api/v1/cart/items` requests adding the same SKU to the same session.
- Expected:
  - No duplicate cart items for same (cart_id, product_id, warehouse_id).
  - Final quantity equals sum of increments.
  - No unique constraint violations / race errors.

---

## P1-02 - Resilience / Correctness

- **Issue**: Cart totals calculation has silent failures. **Status: ✅ Fixed**
  - **Service**: `order`
  - **Location**: `order/internal/biz/cart/totals.go`
  - **Impact**: Continuing with default `0` for tax/shipping/promotions can cause incorrect totals and compliance risks.
  - **Fix**: Current implementation returns errors when shipping/promotions/tax calls fail.

### Verification Plan
- Temporarily simulate downstream failure (e.g., block pricing/shipping/promotion dependency in dev).
- Expected:
  - Totals calculation endpoints return error (non-200) instead of returning 0’d fields.

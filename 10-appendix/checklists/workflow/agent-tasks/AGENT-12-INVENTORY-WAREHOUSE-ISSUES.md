# AGENT-12: Inventory & Warehouse Flow QA Issues

**Created**: 2026-03-22  
**Source**: Inventory & Warehouse Flows QA (Section 8 of ecommerce-platform-flows.md)  
**Priority**: P2

---

## Issues Found

### Issue 1: Automated test login timeout (test infrastructure)
- **Location**: `qa-auto/tests/inventory-warehouse/admin-warehouse.spec.ts`
- **Severity**: P3 (Test Infra)
- **Description**: Admin login function uses `waitForURL` with regex pattern that times out after the first describe block completes. Tests 6-13 (warehouse, movements, transfers) all fail with "Failed to login after 3 attempts". The app itself works — verified manually.
- **Root Cause**: Browser session expires between Playwright test describe blocks. The `loginAsAdmin()` function's `waitForURL` regex doesn't match the redirected URL after session timeout.
- **Fix**: Update `loginAsAdmin()` to handle session recovery, or use Playwright `storageState` for persistent auth.
- [ ] Fix `loginAsAdmin()` to handle post-session-expiry redirects
- [ ] Consider using Playwright `storageState` for session persistence

### Issue 2: Create Inventory modal strict-mode locator
- **Location**: `qa-auto/tests/inventory-warehouse/admin-inventory.spec.ts` TC-INV-03
- **Severity**: P3 (Test Bug — FIXED)
- **Description**: `modal.getByText('Warehouse')` resolves to 2 elements (label + placeholder). Fixed by adding `.first()`.
- [x] Fixed with `.first()` selector

### Issue 3: Stock Transfers page shows "No data"
- **Location**: Admin — `/inventory/transfers`
- **Severity**: P3 (Data)
- **Description**: Stock Transfers page loads correctly with Create Transfer button and all columns, but displays "No data". This is expected if no transfers have been created, but could improve UX with a more guided empty state.
- [ ] Consider adding an empty state with "Create your first transfer" CTA

### Issue 4: Warehouse Time Slots show "No data"
- **Location**: Admin — Warehouse → Time Slots
- **Severity**: P3 (Data)
- **Description**: Time Slots sub-page has correct structure (Time Range, Max Orders/Hour, etc.) but no data configured. This is expected for dev environment but should be seeded with sample data.
- [ ] Consider seeding sample time slot data for dev environment

---

## Test Results

### Manual Tests (All areas verified ✅)
| Area | URL | Result | Notes |
|------|-----|--------|-------|
| Warehouses | `/inventory/warehouses` | ✅ PASS | 3 warehouses, all Active |
| Warehouse Types | — | ✅ PASS | Fulfillment, Returns, Standard — color-coded |
| Time Slots | `/inventory/warehouses/.../time-slots` | ✅ PASS | Page loads, no data (expected) |
| Stock Management | `/inventory/stock` | ✅ PASS | 20 items, all "In Stock" |
| Stock Movements | `/inventory/movements` | ✅ PASS | 3 Adjustment entries |
| Stock Transfers | `/inventory/transfers` | ✅ PASS | Page loads, no data |
| Frontend PLP Stock | `/products` | ✅ PASS | Stock badges visible |
| Frontend PDP Stock | `/products/:id` | ✅ PASS | "Còn 110 sản phẩm" shown |
| Frontend Add to Cart | `/products/:id` | ✅ PASS | Login-to-buy shown for guests |

### Automated Tests
```
admin-inventory.spec.ts:  5/6 passed (1 login timeout)
admin-warehouse.spec.ts:  0/7 passed (all login timeout)
frontend-stock.spec.ts:   3/3 passed
Total: 8/16 passed (8 login-timeout failures)
```

### Summary
The application is functionally correct for all inventory/warehouse flows. No application bugs found. Issues are limited to test infrastructure (login session timeouts) and empty seed data.

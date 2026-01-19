# Tax Flow - Code Review Issues

**Last Updated**: 2026-01-20

This document lists issues found during the review of the Tax Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🔎 Re-review (2026-01-19)

### Fixed
- **TAX-P2-01**: Order service tax calculation lacked category context in checkout flow.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/calculations.go`, `order/internal/biz/checkout/update_helpers.go`, `order/internal/biz/checkout/preview.go`
  - **Fix**: Populate `categories` from cart items and pass them into tax calculation.
  - **Evidence**: `extractCategoriesFromCart` helper added and used across checkout tax paths.

## P2 - Correctness / Refactoring

- **Issue**: Order service tax calculation missed category context in checkout flows.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/calculations.go`, `order/internal/biz/checkout/update_helpers.go`, `order/internal/biz/checkout/preview.go`
  - **Impact**: Tax computed without product category context can be inaccurate for category-based rules.
  - **Status**: ✅ Fixed (categories now passed into tax calculation).

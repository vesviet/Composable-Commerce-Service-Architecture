# Tax Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Tax Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P2 - Correctness / Refactoring

- **Issue**: Order service uses a deprecated tax calculation method.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/calculations.go`
  - **Impact**: Incorrect tax calculation. The current implementation calls `pricingService.CalculateTax`, which is deprecated and does not use critical context like postcode, product categories, or customer groups. This can lead to compliance and accounting risks.
  - **Recommendation**: Refactor the call to use the correct `pricingService.CalculateTaxWithContext` method and ensure the full context object is passed, including resolving the `TODO` for `ProductCategories`.

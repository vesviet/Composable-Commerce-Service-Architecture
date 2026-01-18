# Tax Calculation Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code

## Overview

This document describes the current tax calculation flow, from the initiating service (`order`) to the processing service (`pricing`).

## Current Flow (Verified)

The tax calculation is triggered during the checkout totals calculation in the `order` service.

1.  **Initiator**: `order/internal/biz/checkout/calculations.go`
    - The `calculateTax` function is called.
2.  **API Call**: The function calls `uc.pricingService.CalculateTax(...)`.
    - **Issue**: This is a **deprecated** method in the `pricing` service.
3.  **Data Passed**: The call passes `country`, `state`, and `postcode`, but `product_categories` is passed as an empty slice (marked with a `TODO` in the code).
4.  **Processing**: `pricing/internal/biz/tax/tax.go`
    - The `CalculateTax` method receives the request.
    - It calls `repo.ListSimple(...)`, which only filters tax rules by `countryCode` and `stateProvince`.
    - It does **not** use postcode, product categories, or customer group for filtering, even though the `pricing` service has a more advanced `CalculateTaxWithContext` method that supports these.

## Identified Gap (P2 - Correctness)

- **The `order` service is using a deprecated tax calculation method.**
  - This results in a simplified tax calculation that ignores critical context like postcode, product categories, and customer groups.
  - This can lead to incorrect tax amounts being charged, creating compliance and accounting risks.

## Recommendation

- **Refactor `order` service**: Update the call in `order/internal/biz/checkout/calculations.go` to use the correct `pricingService.CalculateTaxWithContext` method.
- **Pass Full Context**: Ensure the `TaxCalculationContext` object is fully populated, especially `ProductCategories` (which is currently a `TODO`).

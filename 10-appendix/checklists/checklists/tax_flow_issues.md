# Tax Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Tax Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- None

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- [FIXED ✅] TAX-P2-01 Order tax calculation now includes category context in checkout flows (`order/internal/biz/checkout/calculations.go`, `order/internal/biz/checkout/update_helpers.go`, `order/internal/biz/checkout/preview.go`).

## P2 - Correctness / Refactoring

- **Issue**: Order service tax calculation missed category context in checkout flows.
  - **Service**: `order`
  - **Location**: `order/internal/biz/checkout/calculations.go`, `order/internal/biz/checkout/update_helpers.go`, `order/internal/biz/checkout/preview.go`
  - **Impact**: Tax computed without product category context can be inaccurate for category-based rules.
  - **Status**: ✅ Fixed (categories now passed into tax calculation).

# Product & Catalog Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Product & Catalog Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] [NEW ISSUE 🆕] CAT-P1-03 Warehouse stock lookup returns 0 on error, causing false out-of-stock. Required: return error or cached value instead of silent 0. See `catalog/internal/biz/product/product_price_stock.go`.
- [Medium] CAT-P2-01 Unclear data ownership/query patterns for stock/price information in catalog vs search. Required: document ownership and enforce usage boundaries.
- [Medium] CAT-P2-02 Brand/category delete does not check product associations. Required: block deletion when products reference brand/category.
- [Medium] [NEW ISSUE 🆕] CAT-P2-03 Cache TTL jitter uses default RNG seed, causing synchronized expirations. Required: seed RNG at startup or use per-request jitter. See `catalog/internal/biz/product/product_price_stock.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- [Reliability] [NEW ISSUE 🆕] CAT-P1-03 Warehouse-specific stock lookup returns 0 on error (`catalog/internal/biz/product/product_price_stock.go`).
- [Reliability] [NEW ISSUE 🆕] CAT-P2-03 Cache TTL jitter uses default RNG seed (`catalog/internal/biz/product/product_price_stock.go`).

## ✅ RESOLVED / FIXED
- None

## P2 - Maintainability / Architecture

- **Issue**: Unclear data ownership and query patterns for stock/price information. [NOT FIXED]
  - **Service**: `catalog`
  - **Location**: `catalog/internal/biz/product/product_price_stock.go`
  - **Impact**: The `catalog` service contains active code for fetching and caching stock/price data, while the primary responsibility for this in listings belongs to the `search` service (CQRS pattern). This creates ambiguity for developers, increasing the risk of inconsistent data being displayed and making the system harder to maintain.
  - **Recommendation**: Create a central architecture document that clearly defines data ownership. For example: "All product listing/searching MUST use the `search` service. The `catalog` service's price/stock enrichment is ONLY for the Product Detail Page as a fallback or for direct, real-time checks."

---

## P2 - Data Integrity

- **Issue**: Deleting a brand or category does not check for existing product associations. [NOT FIXED]
  - **Service**: `catalog`
  - **Location**: `catalog/internal/biz/brand/brand.go` (`DeleteBrand`), `catalog/internal/biz/category/category.go` (`DeleteCategory`)
  - **Impact**: Deleting a brand or category that is still linked to products can lead to dangling references, broken links on the frontend, and errors in filtering or analytics. This violates foreign key integrity at a logical level.
  - **Recommendation**: Before performing the deletion, the usecase should query the `products` table to verify that no products are currently using the `brand_id` or `category_id`. If references exist, the operation should be rejected with a clear error message (e.g., "Cannot delete brand with active products").

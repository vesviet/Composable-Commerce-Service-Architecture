# Product & Catalog Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Product & Catalog Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P2 - Maintainability / Architecture

- **Issue**: Unclear data ownership and query patterns for stock/price information.
  - **Service**: `catalog`
  - **Location**: `catalog/internal/biz/product/product_price_stock.go`
  - **Impact**: The `catalog` service contains active code for fetching and caching stock/price data, while the primary responsibility for this in listings belongs to the `search` service (CQRS pattern). This creates ambiguity for developers, increasing the risk of inconsistent data being displayed and making the system harder to maintain.
  - **Recommendation**: Create a central architecture document that clearly defines data ownership. For example: "All product listing/searching MUST use the `search` service. The `catalog` service's price/stock enrichment is ONLY for the Product Detail Page as a fallback or for direct, real-time checks."

---

## P2 - Data Integrity

- **Issue**: Deleting a brand or category does not check for existing product associations.
  - **Service**: `catalog`
  - **Location**: `catalog/internal/biz/brand/brand.go` (`DeleteBrand`), `catalog/internal/biz/category/category.go` (`DeleteCategory`)
  - **Impact**: Deleting a brand or category that is still linked to products can lead to dangling references, broken links on the frontend, and errors in filtering or analytics. This violates foreign key integrity at a logical level.
  - **Recommendation**: Before performing the deletion, the usecase should query the `products` table to verify that no products are currently using the `brand_id` or `category_id`. If references exist, the operation should be rejected with a clear error message (e.g., "Cannot delete brand with active products").

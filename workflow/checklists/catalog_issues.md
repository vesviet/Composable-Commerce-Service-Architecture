# Product & Catalog Flow - Code Review Issues

**Last Updated**: 2026-01-19

This document lists issues found during the review of the Product & Catalog Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🔎 Re-review (2026-01-19) - Unfixed & New Issues (Moved to Top)

### Unfixed Issues
- **CAT-P2-01**: Unclear data ownership and query patterns for stock/price information.
- **CAT-P2-02**: Deleting a brand or category does not check for existing product associations.

### New Issues
- **CAT-P1-03 (New)**: Warehouse-specific stock lookup returns 0 on error, causing false out-of-stock.
  - **File**: `catalog/internal/biz/product/product_price_stock.go`
  - **Impact**: Customers see out-of-stock when warehouse service is temporarily unavailable.
  - **Fix**: Return error or last known cached value; avoid silent 0.

- **CAT-P2-03 (New)**: Cache TTL jitter uses default RNG seed, causing synchronized expirations across pods.
  - **File**: `catalog/internal/biz/product/product_price_stock.go`
  - **Impact**: Cache stampedes when zero-stock TTL expires simultaneously.
  - **Fix**: Seed `math/rand` on startup or use per-request crypto-based jitter.

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

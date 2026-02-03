# Product & Catalog Management Flow

**Last Updated**: 2026-01-30
**Status**: Updated - Dependencies refreshed, code review completed

## Overview

This document describes the business logic for managing core catalog entities (`Product`, `Category`, `Brand`) within the `catalog` service. This service acts as the primary write model (source of truth) for catalog data, using a robust, event-driven architecture to ensure data integrity and propagate changes to other systems.

**Key Files:**
- **Usecases**: `catalog/internal/biz/{product,category,brand}`
- **Key Pattern**: Transactional Outbox for reliable event publishing.

---

## Key Flows

### 1. Write Operations (Create/Update/Delete)

All write operations follow a consistent, two-phase pattern to ensure atomicity and reliable integration with other microservices.

- **Files**: `product_write.go`, `category.go`, `brand.go`
- **Logic**:
  1.  **Database Transaction**: Every create, update, or delete operation is wrapped in a database transaction (`uc.tm.InTx(...)`). This guarantees that all changes within the operation are atomic (either all succeed or all fail).
  2.  **Transactional Outbox**: Inside the same transaction, after the primary database change is made, an event record is written to an `outbox` table (`uc.outboxRepo.Create(...)`).
  3.  **Commit**: The transaction is committed. At this point, both the business data (e.g., the new product) and the intent to publish an event are atomically saved.
  4.  **Asynchronous Processing**: A separate background worker (not part of the initial request) polls the `outbox` table. It picks up `PENDING` events and is responsible for triggering the actual side effects.
  5.  **Side Effects**: The worker calls processor methods (e.g., `ProcessProductCreated`) which handle tasks like:
      -   Invalidating Redis caches.
      -   Updating the Elasticsearch index (`indexingService`).
      -   Publishing a formal event (e.g., `product.created`) to the message bus for other services to consume.

### 2. Read Operations (Get/List)

Read operations are optimized for performance using multiple layers.

- **File**: `product_read.go`
- **Logic**:
  1.  **Multi-Layer Cache**: For single-entity lookups (e.g., `GetProduct`), the system first checks a multi-layer cache (`uc.cacheService`) before querying the database.
  2.  **Materialized Views**: For listing and searching (`ListProducts`), the repository queries pre-aggregated materialized views in the database. This avoids complex joins and provides high performance for common filtering scenarios.
  3.  **Cache Fallback**: For simple list queries (e.g., no complex filters), the system will attempt to serve results from a search result cache. If the cache misses, it queries the database and then populates the cache for subsequent requests.

### 3. Stock & Price Data Handling

- **File**: `product_price_stock.go`
- **Separation of Concerns**: The `catalog` service is the source of truth for core product information (name, description, attributes). The `search` service maintains a denormalized "sellable view" that includes stock and price for fast filtering in listings.
- **Fallback Mechanism**: The logic in `product_price_stock.go` acts as a **lazy-loading cache and fallback**. It is primarily used for product detail pages or other scenarios requiring a direct, real-time check. On a cache miss, it calls the `warehouse` and `pricing` services directly to fetch live data.

### 4. Product Visibility

- **File**: `product_visibility.go`
- **Logic**:
  1.  The `CheckProductVisibility` function delegates the evaluation to a dedicated `visibilityRuleUsecase` and `RuleEngine`.
  2.  It fetches all visibility rules associated with a product.
  3.  The rule engine evaluates these rules against the provided customer context (e.g., location, customer group).
  4.  **Fail-Open Strategy**: If there is any error during the process of fetching or evaluating rules, the system defaults to making the product **visible**. This prioritizes user experience and avoids incorrectly hiding products due to transient system errors.

---

## Identified Issues & Gaps

Based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

### P2 - Maintainability: Unclear Data Ownership

- **Description**: The `catalog` service contains active code for fetching and caching stock/price data (`product_price_stock.go`), even though comments indicate this is a legacy/fallback pattern and the `search` service is the primary source for this data in listings. 
- **Impact**: This creates ambiguity for developers about which service to query and what the source of truth is for different contexts (listing vs. detail page). It increases the cognitive load and risk of fetching inconsistent data.
- **Recommendation**: Create clear documentation (e.g., in a central `ARCHITECTURE.md`) that explicitly defines the data ownership and query patterns for different use cases. For example: "All product listing/searching MUST use the `search` service. The `catalog` service's price/stock enrichment is ONLY for the Product Detail Page as a fallback."

### P2 - Data Integrity: Missing Foreign Key Usage Checks

- **Description**: The `DeleteBrand` and `DeleteCategory` functions have `TODO` comments indicating they should check if the brand or category is still in use by any products before allowing deletion.
- **Files**: `brand/brand.go`, `category/category.go`
- **Impact**: Deleting a brand or category that is still linked to products can lead to dangling references, broken links on the frontend, and errors in filtering or analytics.
- **Recommendation**: Implement the check before deletion. The function should query the `products` table to see if any products reference the `brand_id` or `category_id` being deleted. If references exist, the deletion should be rejected with a clear error message.

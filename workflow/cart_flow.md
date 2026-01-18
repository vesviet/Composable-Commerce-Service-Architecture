# Cart Management Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code

## Overview

This document describes the business logic and key flows for cart management within the `order` service. The cart implementation follows a session-based model and uses a "Quote Pattern" for applying coupons, where the final discount calculation is deferred until the totals are calculated.

**Key Files:**
- **Usecase**: `order/internal/biz/cart/usecase.go`
- **Logic**: `order/internal/biz/cart/{add,update,remove,get,clear,coupon,merge,totals}.go`
- **Data Model**: `order/internal/model/cart.go` (`CartSession`, `CartItem`)

---

## Key Flows

### 1. Get/Create Cart Flow

This is the primary entry point for all cart interactions.

- **File**: `get.go`
- **Logic**:
  1.  Finds an active `CartSession` using `sessionID`, `customerID`, or `guestToken`.
  2.  **Auto-Creation**: If no active cart is found, a new one is created automatically.
  3.  **Post-Order Handling**: If a cart is found but is marked `is_active=false` (meaning an order was placed with it), a new active cart is created to ensure a fresh session.
  4.  **Abandoned Checkout Handling**: If a cart has a status of `checkout` but no associated `order_id` in its metadata, the status is reset to `active`.
  5.  Finally, it calls `CalculateCartTotals` to provide a full summary with pricing.

### 2. Add Item to Cart Flow

- **File**: `add.go`
- **Logic**:
  1.  Gets or creates a cart session.
  2.  Validates product SKU and quantity limits.
  3.  Uses `errgroup` to perform two critical operations in parallel for performance:
      - **Stock Check**: Calls `warehouseInventoryService.CheckStock`.
      - **Price Check**: Calls `pricingService.CalculatePrice` to get the authoritative price.
  4.  **Read-Then-Write**: Checks if the item (product + warehouse) already exists in the cart.
      - If yes, it updates the quantity of the existing item.
      - If no, it creates a new `CartItem`.
  5.  Invalidates the cart cache.
  6.  Publishes a `cart_item_added` event asynchronously.

### 3. Update Item Quantity Flow

- **File**: `update.go`
- **Logic**:
  1.  Finds the existing cart item by its ID.
  2.  **Always** calls `pricingService.CalculatePrice` with the new quantity to ensure price accuracy.
  3.  Updates the item's quantity and pricing information in the database.

### 4. Apply Coupon Flow (Quote Pattern)

- **File**: `coupon.go`
- **Logic**:
  1.  Calls `promotionService.ValidatePromotions` to check if the coupon is valid for the current cart state (items, subtotal).
  2.  If valid, it **saves the coupon code to the `CartSession` metadata**.
  3.  It does **not** calculate or apply the discount at this stage. The discount is calculated later by the `CalculateCartTotals` flow.

### 5. Totals Calculation Flow

- **File**: `totals.go`
- **Logic**: This is the central orchestration point for final pricing.
  1.  Calculates subtotal from the sum of `item.TotalPrice`.
  2.  Calls `shippingService.CalculateRates` to get shipping costs.
  3.  Calls `promotionService.ValidatePromotions` (again) to get the final discount amount based on the current cart state.
  4.  Calls `pricingService.CalculateTax` to get the tax amount.
  5.  Sums all values to produce the final `TotalEstimate`.

---

## Identified Issues & Gaps

Based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

### P1 - Concurrency: Race Condition on Cart Updates

- **Description**: The `AddToCart` and `UpdateCartItem` flows use a `Read-Then-Write` pattern without any locking mechanism (optimistic or pessimistic). If two requests try to modify the quantity of the same cart item concurrently, the final quantity can be incorrect, leading to data inconsistency.
- **Files**: `add.go`, `update.go`
- **Recommendation**: Implement optimistic locking. Add a `version` column to the `cart_items` table. The `UPDATE` query should include `WHERE version = ?` and the application should retry the read-modify-write cycle if the update fails due to a version mismatch.

### P1/P2 - Resilience: Silent Failures in Totals Calculation

- **Description**: The `CalculateCartTotals` function has a weak failure handling strategy. When calls to dependent services like `shippingService`, `promotionService`, or `pricingService` (for tax) fail, it logs a warning and proceeds with a default value of `0`.
- **File**: `totals.go`
- **Impact**: This can lead to incorrect pricing being shown to the customer. A tax calculation failure, in particular, is a **P1 compliance risk**. A promotion failure is a **P2 customer experience issue**.
- **Recommendation**: The failure mode should be more explicit. For critical dependencies like tax, the calculation should fail fast and return an error. For non-critical dependencies like promotions, the current behavior might be acceptable but should be clearly monitored with metrics and alerts.

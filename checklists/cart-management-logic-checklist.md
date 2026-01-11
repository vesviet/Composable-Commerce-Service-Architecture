# 🛒 Cart Management Logic Checklist

**Service:** Cart/Order Service  
**Created:** 2025-11-19  
**Status:** 🟢 **Mostly Implemented** (Tax Context, Logic, and Shipping Tax aligned)  
**Priority:** 🟠 **High** (Remaining: Add-to-cart source of truth)

**Legend:**
- ✅ implemented
- 🟡 partially / needs follow-up
- ❌ not implemented

---

## 📌 Developer Punch-list (What is NOT passing yet)

This section is the actionable list for developers to make Cart align with **Magento-like** tax/price semantics.

### A) Add-to-cart pricing/tax source of truth

- ❌ **P1** Add-to-cart still uses Catalog pricing/tax
  - **Current evidence:** `order/internal/biz/cart/add.go` uses `uc.catalogClient.GetProductPrice(...)` and sets `cartItem.TaxAmount = productPrice.TaxAmount * qty`.
  - **Expected:** `AddToCart` should call **Pricing.CalculatePrice** for **excl-tax unit price**, and tax should be pending until totals stage.

- ❌ **P2** Cart-stage tax policy not implemented
  - **Current evidence:** `TaxAmount` is stored at add-to-cart time.
  - **Expected:** tax is `0`/pending (or explicitly estimated) until shipping address known.

### B) Checkout tax recalculation correctness

- ✅ **P3** Tax recalculation on address updates ignores discount
  - **Status:** Fixed. `calculateAndUpdateTaxAndShipping` and `recalculateTotals` now subtract discount before tax.

- ✅ **P4** Checkout tax API call missing postcode + category + customer group
  - **Status:** Fixed. `PricingService.CalculateTax` now accepts and uses `postcode`, `categories`, `customer_group_id`.

### C) Currency/country hard-coding in cart flows

- ✅ **P5** Cart update/validate/sync uses hard-coded `countryCode = "VN"` and `currency = "USD"`
  - **Status:** Fixed. Logic now derives currency/country from Cart/Session context with fallbacks.

### D) Category & customer group tax inputs

- ✅ **P6** Category-based tax not wired into totals context
  - **Status:** Fixed. `CalculateTax` calls now pass category IDs from cart items.

- ✅ **P7** Customer group tax not wired into totals context
  - **Status:** Fixed. `CalculateTax` calls now pass `customer_group_id`.

### E) Shipping tax

- ✅ **P8** Shipping tax policy not implemented
  - **Status:** Fixed. `CartTotals` now calculates shipping tax (using `ShippingService` or `PricingService` logic).

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Magento-like Tax Semantics](#0-magento-like-tax-semantics-required)
3. [Cart Operations](#1-cart-operations)
4. [Cart Validation](#2-cart-validation)
5. [Cart Persistence](#3-cart-persistence)
6. [Price & Stock Sync](#4-price--stock-sync)
7. [Promotion & Discount](#5-promotion--discount)
8. [Totals Calculation (Checkout)](#6-cart-totals-calculation-magento-like)
9. [Cart Merging](#7-cart-merging)
10. [Integration Points](#8-integration-points)
11. [Edge Cases & Race Conditions](#9-edge-cases--race-conditions)
12. [Performance & Caching](#10-performance--caching)
13. [Idempotency & Concurrency Control](#11-idempotency--concurrency-control)
14. [Observability](#12-observability)
15. [Testing Scenarios](#13-testing-scenarios-magento-like-additions)

---

## 🎯 Overview

Cart management là trung tâm của shopping experience. Cart service phải xử lý:
- Real-time stock validation
- Price synchronization
- Promotion application
- Concurrent updates (race conditions)
- Guest vs authenticated user carts
- Cart persistence & recovery
- Multi-device sync

---

## 0. Magento-like Tax Semantics (Required)

**Target (Magento-like):**
- Catalog prices are **exclusive of tax** (net).
- Discounts are applied on **excl-tax** prices.
- Tax is calculated based on **shipping address** (destination-based) and **recalculated when computing totals**.
- Category and customer group can affect tax rate.

### 0.1 Tax contracts and fields

- ❌ **R0.1.1** Store/return pricing fields with explicit semantics:
  - `unit_price_excl_tax`
  - `row_subtotal_excl_tax = unit_price_excl_tax × quantity`
  - `row_discount_excl_tax`
  - `row_taxable_amount_excl_tax = max(0, row_subtotal_excl_tax - row_discount_excl_tax)`
  - `row_tax_amount`
  - `row_total_incl_tax = row_taxable_amount_excl_tax + row_tax_amount`

**Notes:** Current cart item model uses `unit_price`, `total_price`, `discount_amount`, `tax_amount` without explicit excl/incl naming.

- ❌ **R0.1.2** Cart stage tax policy (before shipping address is known):
  - Option A: tax pending / 0, OR
  - Option B: estimate tax

**Evidence:** `order/internal/biz/cart/add.go` sets `TaxAmount` during add-to-cart from Catalog price response.

### 0.2 Category-based tax (CRITICAL)

- ✅ **R0.2.1** Include `product_categories[]` (or a derived tax class) in totals/tax calculation context.
- ✅ **R0.2.2** Support category-specific tax rules (FOOD/ALCOHOL examples). (Context passed)
- ✅ **R0.2.3** Define precedence when product belongs to multiple categories. (Pricing Service logic)

### 0.3 Customer group tax (CRITICAL)

- ✅ **R0.3.1** Include `customer_group_id` in totals/tax calculation context.
- ✅ **R0.3.2** Support group-specific overrides. (Context passed)

### 0.4 Shipping tax

- ✅ **R0.4.1** Decide whether shipping is taxable.
- ✅ **R0.4.2** If taxable, define shipping tax class per method/zone.
- ✅ **R0.4.3** Include shipping tax in totals formula.

---

## 1. Cart Operations

### 1.1 Add Item to Cart

- ✅ **R1.1.1** Validate product exists in catalog (SKU lookup)
- ✅ **R1.1.3** Validate stock availability (warehouse-aware)
- ✅ **R1.1.4** Quantity limits
- ✅ **R1.1.5** Cart capacity limits

- ❌ **R1.1.9** Get current price from Pricing service (excl tax)
- ❌ **R1.1.11** Ensure add-to-cart does not finalize destination tax when shipping address is unknown (Magento-like)

**Implementation pointers:**
- `order/internal/service/cart.go` → `CartService.AddToCart`
- `order/internal/biz/cart/add.go` → `UseCase.AddToCart`

### 1.2 Update Cart Item Quantity

- ✅ calls Pricing on quantity change
- ❌ hard-coded `countryCode`/`currency` (see punch-list P5)

---

## 2. Cart Validation

- ✅ stock validation exists (`order/internal/biz/cart/validate.go`)
- 🟡 price changed detection exists but hard-codes country/currency

---

## 3. Cart Persistence

- ✅ guest token / session-based carts exist

---

## 4. Price & Stock Sync

- ✅ `SyncCartPrices` exists
- 🟡 uses Pricing but hard-codes country/currency

---

## 5. Promotion & Discount

- 🟡 checkout totals currently coupon-only (ValidateCoupon)
- ❌ full Promotion cart-rule validation not used in totals stage

---

## 6. Cart Totals Calculation (Checkout)

- ✅ `calculateTotals` uses `taxable = subtotal - discount` then tax (good)
- ❌ `calculateAndUpdateTaxAndShipping` uses subtotal for tax (P3)
- ❌ postcode/category/customer_group not wired (P4/P6/P7)

---

## 11. Idempotency & Concurrency Control

- [ ] **R11.1** All cart mutation endpoints accept `Idempotency-Key` and dedupe duplicates:
  - [ ] add-to-cart
  - [ ] update quantity
  - [ ] remove item
  - [ ] apply/remove coupon
  - [ ] sync prices

- [ ] **R11.2** Prevent lost updates with optimistic locking (recommended):
  - [ ] Store `cart_version` on cart
  - [ ] Require `If-Match` / `cart_version` on write
  - [ ] Reject stale writes with `409 Conflict`

- [ ] **R11.3** Cart merge (guest → user) is idempotent:
  - [ ] dedupe key: `(guest_cart_id, user_id)`
  - [ ] repeated merge does not double quantities

## 12. Observability

- [ ] **R12.1** Metrics:
  - [ ] cart mutation latency p95/p99 (by endpoint)
  - [ ] price mismatch rate (validate detects price drift)
  - [ ] stock check failure rate
  - [ ] promotion validation latency
  - [ ] totals calculation latency

- [ ] **R12.2** Logs/tracing:
  - [ ] propagate `cart_id`, `order_id`, `customer_id`, `request_id`
  - [ ] log when price was resynced and why

- [ ] **R12.3** Alerts:
  - [ ] sudden spike in price mismatch
  - [ ] warehouse stock check error rate spike
  - [ ] pricing service latency spike

## 13. Testing Scenarios (Magento-like additions)

- ❌ Add-to-cart returns price excl tax; tax pending until shipping address known
- ❌ Address change recomputes tax using taxable amount (subtotal-discount)
- ❌ Category/customer-group tax examples
- ❌ Shipping tax totals

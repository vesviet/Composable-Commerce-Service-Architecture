# Debugging Price Updates (Unified Topic Guide)

**Last Updated:** 2026-01-10

## Overview
As of Jan 2026, the Pricing, Catalog, and Search services utilize a **Unified Price Topic** architecture. All price updates (Product base price, Warehouse-specific overrides, SKU-specific prices) are published to a single Dapr topic: **`pricing.price.updated`**.

## Key Concepts

1.  **Topic:** `pricing.price.updated`
2.  **Scope Field:** `priceScope` (string).
    *   `product`: Global base price update.
    *   `warehouse`: Warehouse-specific override.
    *   `sku`: SKU-specific override.

## Debugging Checklist

### 1. Verify Event Publishing (Pricing Service)
Check logs for "Published event" to `pricing.price.updated`.

```bash
docker compose logs pricing-service | grep "pricing.price.updated"
```

**Tracing by Product ID:**
```bash
docker compose logs pricing-service | grep "PROD-123"
```

### 2. Verify Event Payload
The payload MUST contain `priceScope`. If missing, consumers might infer it (legacy fallback), but it's risky.

**Sample Warehouse Price Update:**
```json
{
  "eventType": "pricing.price.updated",
  "productId": "PROD-123",
  "warehouseId": "WH-001",
  "priceScope": "warehouse",
  "newPrice": 150000,
  "currency": "VND"
}
```

### 3. Verify Consumer Processing (Catalog/Search)
Consumers subscribe ONLY to `pricing.price.updated`. They filter logic internally based on `priceScope`.

**Catalog Service Logs:**
```bash
docker compose logs catalog-service | grep "Processing warehouse price update"
```

**Search Service Logs:**
```bash
docker compose logs search-service | grep "Processing warehouse price updated event"
```

### 4. Common Issues

*   **Missing Updates via Legacy Topics?**
    *   **Root Cause:** Consumers no longer listen to `pricing.warehouse_price.updated` or `pricing.sku_price.updated`.
    *   **Fix:** Ensure Producer (Pricing) is upgraded to publish to `pricing.price.updated` with correct scope.

*   **"Scope Unknown" / defaulting to Product?**
    *   **Root Cause:** `priceScope` field missing in JSON.
    *   **Fix:** Check Pricing Service version. fallback logic exists but explicit scope is preferred.

## Validation Script
Use `test-price-cache-invalidation.sh` in the root directory to perform end-to-end validation.

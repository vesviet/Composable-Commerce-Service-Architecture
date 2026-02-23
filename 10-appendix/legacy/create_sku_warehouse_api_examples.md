# SKU-Warehouse Data API Examples

## Overview
This document provides API examples for querying stock and price data by SKU-warehouse combinations in the microservices architecture.

## Current Data Structure

### Stock Data (Warehouse Service)
```sql
-- Table: inventory
-- Key fields: warehouse_id, product_id, sku, quantity_available, quantity_reserved, unit_cost
-- Unique constraint: (warehouse_id, product_id)
-- Indexes: sku, warehouse_id, product_id
```

### Price Data (Pricing Service)  
```sql
-- Table: prices
-- Key fields: product_id, sku, warehouse_id, currency, base_price, sale_price, cost_price
-- Supports: SKU-specific pricing, warehouse-specific pricing, global pricing
-- Unique constraint: (product_id, sku, warehouse_id, currency, effective_from) WHERE is_active = true
```

## API Endpoints

### 1. Get Stock by SKU and Warehouse

#### Warehouse Service API
```bash
# Get inventory for specific SKU in specific warehouse
GET /api/v1/inventory/sku/{sku}/warehouse/{warehouse_id}

# Example
GET /api/v1/inventory/sku/IPHONE-15-128GB/warehouse/550e8400-e29b-41d4-a716-446655440001
```

**Response:**
```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "warehouseId": "550e8400-e29b-41d4-a716-446655440001",
  "productId": "880e8400-e29b-41d4-a716-446655440001",
  "sku": "IPHONE-15-128GB",
  "quantityAvailable": 100,
  "quantityReserved": 5,
  "quantityOnOrder": 0,
  "availableStock": 95,
  "stockStatus": "in_stock",
  "reorderPoint": 20,
  "reorderQuantity": 50,
  "unitCost": 22000000.00,
  "totalValue": 2200000000.00,
  "locationCode": "A-01",
  "binLocation": "BIN-001",
  "lastMovementAt": "2026-01-06T10:30:00Z"
}
```

#### Bulk Stock Query
```bash
# Get stock for multiple SKUs across warehouses
POST /api/v1/inventory/bulk-stock
```

**Request:**
```json
{
  "skus": ["IPHONE-15-128GB", "SAMSUNG-S24-256GB"],
  "warehouseIds": ["550e8400-e29b-41d4-a716-446655440001", "550e8400-e29b-41d4-a716-446655440002"],
  "includeReserved": true
}
```

**Response:**
```json
{
  "stockLevels": [
    {
      "sku": "IPHONE-15-128GB",
      "warehouseId": "550e8400-e29b-41d4-a716-446655440001",
      "warehouseCode": "WH-MAIN",
      "quantityAvailable": 100,
      "quantityReserved": 5,
      "availableStock": 95,
      "stockStatus": "in_stock",
      "unitCost": 22000000.00
    },
    {
      "sku": "IPHONE-15-128GB", 
      "warehouseId": "550e8400-e29b-41d4-a716-446655440002",
      "warehouseCode": "WH-FUL-01",
      "quantityAvailable": 50,
      "quantityReserved": 2,
      "availableStock": 48,
      "stockStatus": "in_stock",
      "unitCost": 21800000.00
    }
  ]
}
```

### 2. Get Price by SKU and Warehouse

#### Pricing Service API
```bash
# Get price for specific SKU in specific warehouse
GET /api/v1/pricing/products/price?sku={sku}&warehouse_id={warehouse_id}&currency={currency}

# Example
GET /api/v1/pricing/products/price?sku=IPHONE-15-128GB&warehouse_id=550e8400-e29b-41d4-a716-446655440001&currency=VND
```

**Response:**
```json
{
  "id": "990e8400-e29b-41d4-a716-446655440001",
  "productId": "880e8400-e29b-41d4-a716-446655440001",
  "sku": "IPHONE-15-128GB",
  "warehouseId": "550e8400-e29b-41d4-a716-446655440001",
  "currency": "VND",
  "basePrice": 29900000.00,
  "salePrice": 27900000.00,
  "costPrice": 22000000.00,
  "marginPercent": 35.9,
  "priceSource": "sku_warehouse",
  "effectiveFrom": "2026-01-01T00:00:00Z",
  "effectiveTo": null,
  "isActive": true
}
```

#### Compare Prices Across Warehouses
```bash
# Compare prices for same SKU across different warehouses
POST /api/v1/pricing/compare-prices
```

**Request:**
```json
{
  "sku": "IPHONE-15-128GB",
  "currency": "VND",
  "warehouseIds": [
    "550e8400-e29b-41d4-a716-446655440001",
    "550e8400-e29b-41d4-a716-446655440002",
    "550e8400-e29b-41d4-a716-446655440003"
  ]
}
```

**Response:**
```json
{
  "sku": "IPHONE-15-128GB",
  "currency": "VND",
  "priceComparison": [
    {
      "warehouseId": "550e8400-e29b-41d4-a716-446655440001",
      "warehouseCode": "WH-MAIN",
      "basePrice": 29900000.00,
      "salePrice": 27900000.00,
      "finalPrice": 27900000.00,
      "isLowest": false,
      "isHighest": false
    },
    {
      "warehouseId": "550e8400-e29b-41d4-a716-446655440002", 
      "warehouseCode": "WH-FUL-01",
      "basePrice": 29500000.00,
      "salePrice": 27500000.00,
      "finalPrice": 27500000.00,
      "isLowest": true,
      "isHighest": false
    },
    {
      "warehouseId": "550e8400-e29b-41d4-a716-446655440003",
      "warehouseCode": "WH-NORTH", 
      "basePrice": 30200000.00,
      "salePrice": 28200000.00,
      "finalPrice": 28200000.00,
      "isLowest": false,
      "isHighest": true
    }
  ],
  "lowestPrice": 27500000.00,
  "highestPrice": 28200000.00,
  "priceDifference": 700000.00,
  "priceVariationPercent": 2.5
}
```

### 3. Combined Stock & Price Query

#### Gateway Service (Aggregated API)
```bash
# Get both stock and price data for SKU-warehouse combinations
POST /api/v1/products/stock-price
```

**Request:**
```json
{
  "items": [
    {
      "sku": "IPHONE-15-128GB",
      "warehouseId": "550e8400-e29b-41d4-a716-446655440001"
    },
    {
      "sku": "SAMSUNG-S24-256GB", 
      "warehouseId": "550e8400-e29b-41d4-a716-446655440001"
    }
  ],
  "currency": "VND",
  "includeAlternativeWarehouses": true
}
```

**Response:**
```json
{
  "results": [
    {
      "sku": "IPHONE-15-128GB",
      "warehouseId": "550e8400-e29b-41d4-a716-446655440001",
      "warehouseCode": "WH-MAIN",
      "stock": {
        "quantityAvailable": 100,
        "quantityReserved": 5,
        "availableStock": 95,
        "stockStatus": "in_stock",
        "reorderPoint": 20
      },
      "price": {
        "basePrice": 29900000.00,
        "salePrice": 27900000.00,
        "finalPrice": 27900000.00,
        "currency": "VND",
        "priceSource": "sku_warehouse"
      },
      "availability": {
        "isAvailable": true,
        "canFulfill": true,
        "estimatedShipDate": "2026-01-07T00:00:00Z"
      },
      "alternativeWarehouses": [
        {
          "warehouseId": "550e8400-e29b-41d4-a716-446655440002",
          "warehouseCode": "WH-FUL-01",
          "availableStock": 48,
          "finalPrice": 27500000.00,
          "estimatedShipDate": "2026-01-08T00:00:00Z"
        }
      ]
    }
  ]
}
```

## Go Client Examples

### 1. Warehouse Client Usage
```go
// Get stock by SKU and warehouse
func GetStockBySKUAndWarehouse(ctx context.Context, sku, warehouseID string) (*Inventory, error) {
    client := warehouse.NewInventoryServiceClient(conn)
    
    resp, err := client.GetInventoryBySKU(ctx, &warehouse.GetInventoryBySKURequest{
        Sku:         sku,
        WarehouseId: warehouseID,
    })
    if err != nil {
        return nil, err
    }
    
    return resp.Inventory, nil
}

// Bulk stock query
func GetBulkStock(ctx context.Context, skus []string, warehouseIDs []string) ([]*StockLevel, error) {
    client := warehouse.NewInventoryServiceClient(conn)
    
    resp, err := client.GetBulkStock(ctx, &warehouse.GetBulkStockRequest{
        Skus:         skus,
        WarehouseIds: warehouseIDs,
    })
    if err != nil {
        return nil, err
    }
    
    return resp.StockLevels, nil
}
```

### 2. Pricing Client Usage
```go
// Get price by SKU and warehouse
func GetPriceBySKUAndWarehouse(ctx context.Context, sku, warehouseID, currency string) (*Price, error) {
    client := pricing.NewPricingServiceClient(conn)
    
    resp, err := client.GetPrice(ctx, &pricing.GetPriceRequest{
        Sku:         &sku,
        WarehouseId: &warehouseID,
        Currency:    currency,
    })
    if err != nil {
        return nil, err
    }
    
    return resp.Price, nil
}

// Compare prices across warehouses
func ComparePricesAcrossWarehouses(ctx context.Context, sku, currency string, warehouseIDs []string) (*PriceComparison, error) {
    client := pricing.NewPricingServiceClient(conn)
    
    resp, err := client.ComparePrices(ctx, &pricing.ComparePricesRequest{
        Sku:          sku,
        Currency:     currency,
        WarehouseIds: warehouseIDs,
    })
    if err != nil {
        return nil, err
    }
    
    return resp, nil
}
```

### 3. Combined Service Usage (Order Service Example)
```go
// Check availability and pricing for order items
func CheckOrderItemAvailability(ctx context.Context, items []OrderItem, warehouseID string) ([]ItemAvailability, error) {
    var results []ItemAvailability
    
    for _, item := range items {
        // Get stock
        stock, err := warehouseClient.GetStockBySKU(ctx, item.SKU, warehouseID)
        if err != nil {
            log.Warnf("Failed to get stock for SKU %s: %v", item.SKU, err)
            continue
        }
        
        // Get price
        price, err := pricingClient.GetPriceBySKU(ctx, item.SKU, "VND", &warehouseID)
        if err != nil {
            log.Warnf("Failed to get price for SKU %s: %v", item.SKU, err)
            continue
        }
        
        // Check availability
        availability := ItemAvailability{
            SKU:           item.SKU,
            RequestedQty:  item.Quantity,
            AvailableQty:  stock.AvailableStock,
            CanFulfill:    stock.AvailableStock >= item.Quantity,
            UnitPrice:     price.FinalPrice,
            TotalPrice:    price.FinalPrice * float64(item.Quantity),
            WarehouseID:   warehouseID,
        }
        
        results = append(results, availability)
    }
    
    return results, nil
}
```

## Database Queries for Analysis

### 1. Find SKUs with Stock but No Pricing
```sql
SELECT 
    i.sku,
    w.code as warehouse_code,
    i.quantity_available,
    'Missing price data' as issue
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
LEFT JOIN prices p ON (p.sku = i.sku AND p.warehouse_id = i.warehouse_id AND p.is_active = true)
WHERE p.id IS NULL
ORDER BY w.code, i.sku;
```

### 2. Price Variations Across Warehouses
```sql
SELECT 
    i.sku,
    COUNT(DISTINCT w.id) as warehouse_count,
    MIN(p.base_price) as min_price,
    MAX(p.base_price) as max_price,
    ROUND((MAX(p.base_price) - MIN(p.base_price)) / MIN(p.base_price) * 100, 2) as variation_percent
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
JOIN prices p ON (p.sku = i.sku AND p.warehouse_id = i.warehouse_id AND p.is_active = true)
GROUP BY i.sku
HAVING COUNT(DISTINCT w.id) > 1
ORDER BY variation_percent DESC;
```

### 3. Stock Levels vs Reorder Points
```sql
SELECT 
    w.code as warehouse_code,
    i.sku,
    i.quantity_available,
    i.reorder_point,
    CASE 
        WHEN i.quantity_available <= 0 THEN 'OUT_OF_STOCK'
        WHEN i.quantity_available <= i.reorder_point THEN 'LOW_STOCK'
        ELSE 'IN_STOCK'
    END as stock_status,
    p.base_price,
    p.sale_price
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
LEFT JOIN prices p ON (p.sku = i.sku AND p.warehouse_id = i.warehouse_id AND p.is_active = true)
ORDER BY 
    CASE 
        WHEN i.quantity_available <= 0 THEN 1
        WHEN i.quantity_available <= i.reorder_point THEN 2
        ELSE 3
    END,
    w.code, i.sku;
```

## Cache Strategy

### Redis Cache Keys
```
# Stock data
stock:sku:{sku}:warehouse:{warehouse_id}
stock:warehouse:{warehouse_id}:all
stock:sku:{sku}:all_warehouses

# Price data  
prices:sku:{sku}:wh:{warehouse_id}:{currency}
prices:sku:{sku}:{currency}:all_warehouses
prices:product:{product_id}:wh:{warehouse_id}:{currency}

# Combined data
availability:sku:{sku}:wh:{warehouse_id}:{currency}
```

### Cache Implementation Example
```go
func GetSKUWarehouseData(ctx context.Context, sku, warehouseID, currency string) (*SKUWarehouseData, error) {
    // Try cache first
    cacheKey := fmt.Sprintf("availability:sku:%s:wh:%s:%s", sku, warehouseID, currency)
    
    var cached SKUWarehouseData
    if err := cache.Get(ctx, cacheKey, &cached); err == nil {
        return &cached, nil
    }
    
    // Cache miss - get from services
    stock, err := warehouseClient.GetStockBySKU(ctx, sku, warehouseID)
    if err != nil {
        return nil, err
    }
    
    price, err := pricingClient.GetPriceBySKU(ctx, sku, currency, &warehouseID)
    if err != nil {
        return nil, err
    }
    
    // Combine data
    data := &SKUWarehouseData{
        SKU:           sku,
        WarehouseID:   warehouseID,
        Stock:         stock,
        Price:         price,
        LastUpdated:   time.Now(),
    }
    
    // Cache for 5 minutes
    cache.Set(ctx, cacheKey, data, 5*time.Minute)
    
    return data, nil
}
```

## Testing Data

Run the `check_sku_warehouse_data.sql` script to:
1. Analyze current data structure
2. Create sample SKU-warehouse price combinations
3. Add inventory for additional warehouses
4. Verify data completeness

This will create differentiated pricing across warehouses for the same SKUs, enabling proper testing of the SKU-warehouse data functionality.
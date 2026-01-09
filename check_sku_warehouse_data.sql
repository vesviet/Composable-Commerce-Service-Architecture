-- ============================================
-- SKU-WAREHOUSE DATA ANALYSIS & SAMPLE CREATION
-- ============================================
-- This script checks current data and creates sample data for SKU-warehouse combinations

-- ============================================
-- 1. CURRENT DATA ANALYSIS
-- ============================================

-- Check existing warehouses
SELECT 'WAREHOUSES' as table_name, code, name, type, status 
FROM warehouses 
ORDER BY code;

-- Check existing inventory (stock data by SKU-warehouse)
SELECT 
    'INVENTORY' as table_name,
    w.code as warehouse_code,
    i.sku,
    i.quantity_available,
    i.quantity_reserved,
    i.quantity_on_order,
    i.reorder_point,
    i.unit_cost,
    i.location_code,
    i.bin_location
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
ORDER BY w.code, i.sku;

-- Check existing prices (currently only product-level, no SKU-warehouse specific)
SELECT 
    'PRICES' as table_name,
    product_id,
    sku,
    warehouse_id,
    currency,
    base_price,
    sale_price,
    cost_price,
    is_active
FROM prices
ORDER BY product_id, sku, warehouse_id;

-- ============================================
-- 2. MISSING DATA IDENTIFICATION
-- ============================================

-- Find SKUs that exist in inventory but don't have prices
SELECT 
    'MISSING_PRICES' as issue_type,
    i.sku,
    w.code as warehouse_code,
    'No price data for this SKU-warehouse combination' as description
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
LEFT JOIN prices p ON (p.sku = i.sku AND p.warehouse_id = i.warehouse_id)
WHERE p.id IS NULL
ORDER BY w.code, i.sku;

-- Find products that have prices but no inventory
SELECT 
    'MISSING_INVENTORY' as issue_type,
    p.product_id,
    p.sku,
    COALESCE(w.code, 'GLOBAL') as warehouse_code,
    'Price exists but no inventory data' as description
FROM prices p
LEFT JOIN warehouses w ON p.warehouse_id = w.id
LEFT JOIN inventory i ON (i.sku = p.sku AND i.warehouse_id = p.warehouse_id)
WHERE p.sku IS NOT NULL AND i.id IS NULL
ORDER BY warehouse_code, p.sku;

-- ============================================
-- 3. CREATE SAMPLE SKU-WAREHOUSE PRICE DATA
-- ============================================

-- First, let's create warehouse-specific prices for existing inventory items
-- This will create differentiated pricing per warehouse

-- iPhone 15 - Different prices per warehouse
INSERT INTO prices (
    id, 
    product_id, 
    sku, 
    warehouse_id, 
    currency, 
    base_price, 
    sale_price, 
    cost_price, 
    margin_percent, 
    is_active
) 
SELECT 
    gen_random_uuid(),
    i.product_id,
    i.sku,
    i.warehouse_id,
    'VND',
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 29900000.00      -- Main warehouse - standard price
        WHEN w.code = 'WH-FUL-01' THEN 29500000.00    -- Fulfillment center - slightly lower
        WHEN w.code = 'WH-NORTH' THEN 30200000.00     -- North warehouse - premium
        WHEN w.code = 'WH-SOUTH' THEN 29700000.00     -- South warehouse - competitive
        ELSE 29900000.00
    END as base_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 27900000.00      -- Sale price
        WHEN w.code = 'WH-FUL-01' THEN 27500000.00    
        WHEN w.code = 'WH-NORTH' THEN 28200000.00     
        WHEN w.code = 'WH-SOUTH' THEN 27700000.00     
        ELSE 27900000.00
    END as sale_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 22000000.00      -- Cost price
        WHEN w.code = 'WH-FUL-01' THEN 21800000.00    
        WHEN w.code = 'WH-NORTH' THEN 22200000.00     
        WHEN w.code = 'WH-SOUTH' THEN 21900000.00     
        ELSE 22000000.00
    END as cost_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 35.9             -- Margin %
        WHEN w.code = 'WH-FUL-01' THEN 35.3           
        WHEN w.code = 'WH-NORTH' THEN 36.0            
        WHEN w.code = 'WH-SOUTH' THEN 35.6            
        ELSE 35.9
    END as margin_percent,
    true
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
WHERE i.sku = 'IPHONE-15-128GB'
AND NOT EXISTS (
    SELECT 1 FROM prices p 
    WHERE p.sku = i.sku AND p.warehouse_id = i.warehouse_id
);

-- Samsung S24 - Different prices per warehouse
INSERT INTO prices (
    id, 
    product_id, 
    sku, 
    warehouse_id, 
    currency, 
    base_price, 
    sale_price, 
    cost_price, 
    margin_percent, 
    is_active
) 
SELECT 
    gen_random_uuid(),
    i.product_id,
    i.sku,
    i.warehouse_id,
    'VND',
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 32900000.00      
        WHEN w.code = 'WH-FUL-01' THEN 32500000.00    
        WHEN w.code = 'WH-NORTH' THEN 33200000.00     
        WHEN w.code = 'WH-SOUTH' THEN 32700000.00     
        ELSE 32900000.00
    END as base_price,
    NULL as sale_price, -- No sale price for Samsung
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 25000000.00      
        WHEN w.code = 'WH-FUL-01' THEN 24800000.00    
        WHEN w.code = 'WH-NORTH' THEN 25200000.00     
        WHEN w.code = 'WH-SOUTH' THEN 24900000.00     
        ELSE 25000000.00
    END as cost_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 31.6             
        WHEN w.code = 'WH-FUL-01' THEN 31.0           
        WHEN w.code = 'WH-NORTH' THEN 31.7            
        WHEN w.code = 'WH-SOUTH' THEN 31.3            
        ELSE 31.6
    END as margin_percent,
    true
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
WHERE i.sku = 'SAMSUNG-S24-256GB'
AND NOT EXISTS (
    SELECT 1 FROM prices p 
    WHERE p.sku = i.sku AND p.warehouse_id = i.warehouse_id
);

-- Nike Air Max 90 - Different prices per warehouse
INSERT INTO prices (
    id, 
    product_id, 
    sku, 
    warehouse_id, 
    currency, 
    base_price, 
    sale_price, 
    cost_price, 
    margin_percent, 
    is_active
) 
SELECT 
    gen_random_uuid(),
    i.product_id,
    i.sku,
    i.warehouse_id,
    'VND',
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 3290000.00       
        WHEN w.code = 'WH-FUL-01' THEN 3190000.00     
        WHEN w.code = 'WH-NORTH' THEN 3390000.00      
        WHEN w.code = 'WH-SOUTH' THEN 3240000.00      
        ELSE 3290000.00
    END as base_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 2990000.00       
        WHEN w.code = 'WH-FUL-01' THEN 2890000.00     
        WHEN w.code = 'WH-NORTH' THEN 3090000.00      
        WHEN w.code = 'WH-SOUTH' THEN 2940000.00      
        ELSE 2990000.00
    END as sale_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 1800000.00       
        WHEN w.code = 'WH-FUL-01' THEN 1750000.00     
        WHEN w.code = 'WH-NORTH' THEN 1850000.00      
        WHEN w.code = 'WH-SOUTH' THEN 1780000.00      
        ELSE 1800000.00
    END as cost_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 82.8             
        WHEN w.code = 'WH-FUL-01' THEN 82.3           
        WHEN w.code = 'WH-NORTH' THEN 83.2            
        WHEN w.code = 'WH-SOUTH' THEN 82.0            
        ELSE 82.8
    END as margin_percent,
    true
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
WHERE i.sku = 'NIKE-AIR-MAX-90'
AND NOT EXISTS (
    SELECT 1 FROM prices p 
    WHERE p.sku = i.sku AND p.warehouse_id = i.warehouse_id
);

-- Adidas Ultraboost 22 - Different prices per warehouse
INSERT INTO prices (
    id, 
    product_id, 
    sku, 
    warehouse_id, 
    currency, 
    base_price, 
    sale_price, 
    cost_price, 
    margin_percent, 
    is_active
) 
SELECT 
    gen_random_uuid(),
    i.product_id,
    i.sku,
    i.warehouse_id,
    'VND',
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 4490000.00       
        WHEN w.code = 'WH-FUL-01' THEN 4390000.00     
        WHEN w.code = 'WH-NORTH' THEN 4590000.00      
        WHEN w.code = 'WH-SOUTH' THEN 4440000.00      
        ELSE 4490000.00
    END as base_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 3990000.00       
        WHEN w.code = 'WH-FUL-01' THEN 3890000.00     
        WHEN w.code = 'WH-NORTH' THEN 4090000.00      
        WHEN w.code = 'WH-SOUTH' THEN 3940000.00      
        ELSE 3990000.00
    END as sale_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 2500000.00       
        WHEN w.code = 'WH-FUL-01' THEN 2450000.00     
        WHEN w.code = 'WH-NORTH' THEN 2550000.00      
        WHEN w.code = 'WH-SOUTH' THEN 2480000.00      
        ELSE 2500000.00
    END as cost_price,
    CASE 
        WHEN w.code = 'WH-MAIN' THEN 79.6             
        WHEN w.code = 'WH-FUL-01' THEN 79.2           
        WHEN w.code = 'WH-NORTH' THEN 80.0            
        WHEN w.code = 'WH-SOUTH' THEN 79.0            
        ELSE 79.6
    END as margin_percent,
    true
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
WHERE i.sku = 'ADIDAS-ULTRA-BOOST-22'
AND NOT EXISTS (
    SELECT 1 FROM prices p 
    WHERE p.sku = i.sku AND p.warehouse_id = i.warehouse_id
);

-- ============================================
-- 4. CREATE ADDITIONAL INVENTORY FOR MORE WAREHOUSES
-- ============================================

-- Add inventory for existing products in additional warehouses (if they exist)
-- This creates more SKU-warehouse combinations

-- iPhone 15 in North warehouse
INSERT INTO inventory (
    id,
    warehouse_id,
    product_id,
    sku,
    quantity_available,
    quantity_reserved,
    quantity_on_order,
    reorder_point,
    reorder_quantity,
    min_stock_level,
    max_stock_level,
    unit_cost,
    location_code,
    bin_location,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    w.id,
    (SELECT product_id FROM inventory WHERE sku = 'IPHONE-15-128GB' LIMIT 1),
    'IPHONE-15-128GB',
    80,  -- Different stock level
    5,   -- Some reserved
    0,
    15,  -- Different reorder point
    40,
    8,
    400,
    22200000, -- Different unit cost
    'N-A-01',
    'BIN-N-001',
    NOW(),
    NOW()
FROM warehouses w
WHERE w.code = 'WH-NORTH'
AND NOT EXISTS (
    SELECT 1 FROM inventory i 
    WHERE i.sku = 'IPHONE-15-128GB' AND i.warehouse_id = w.id
);

-- Samsung S24 in South warehouse
INSERT INTO inventory (
    id,
    warehouse_id,
    product_id,
    sku,
    quantity_available,
    quantity_reserved,
    quantity_on_order,
    reorder_point,
    reorder_quantity,
    min_stock_level,
    max_stock_level,
    unit_cost,
    location_code,
    bin_location,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    w.id,
    (SELECT product_id FROM inventory WHERE sku = 'SAMSUNG-S24-256GB' LIMIT 1),
    'SAMSUNG-S24-256GB',
    60,
    3,
    20,  -- On order
    12,
    35,
    5,
    250,
    24900000,
    'S-A-01',
    'BIN-S-001',
    NOW(),
    NOW()
FROM warehouses w
WHERE w.code = 'WH-SOUTH'
AND NOT EXISTS (
    SELECT 1 FROM inventory i 
    WHERE i.sku = 'SAMSUNG-S24-256GB' AND i.warehouse_id = w.id
);

-- ============================================
-- 5. VERIFICATION QUERIES
-- ============================================

-- Final verification: Show all SKU-warehouse combinations with both stock and price
SELECT 
    'SKU_WAREHOUSE_COMPLETE' as data_type,
    w.code as warehouse_code,
    w.name as warehouse_name,
    i.sku,
    i.quantity_available as stock,
    i.quantity_reserved as reserved,
    i.unit_cost as inventory_cost,
    p.base_price,
    p.sale_price,
    p.cost_price as price_cost,
    p.margin_percent,
    CASE 
        WHEN i.quantity_available > i.reorder_point THEN 'IN_STOCK'
        WHEN i.quantity_available > 0 THEN 'LOW_STOCK'
        ELSE 'OUT_OF_STOCK'
    END as stock_status,
    CASE 
        WHEN p.sale_price IS NOT NULL THEN 'ON_SALE'
        ELSE 'REGULAR'
    END as price_status
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
LEFT JOIN prices p ON (p.sku = i.sku AND p.warehouse_id = i.warehouse_id AND p.is_active = true)
ORDER BY w.code, i.sku;

-- Summary statistics
SELECT 
    'SUMMARY' as report_type,
    COUNT(DISTINCT w.code) as total_warehouses,
    COUNT(DISTINCT i.sku) as total_skus,
    COUNT(*) as total_sku_warehouse_combinations,
    COUNT(p.id) as combinations_with_prices,
    COUNT(*) - COUNT(p.id) as combinations_missing_prices,
    ROUND(COUNT(p.id)::numeric / COUNT(*)::numeric * 100, 2) as price_coverage_percent
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
LEFT JOIN prices p ON (p.sku = i.sku AND p.warehouse_id = i.warehouse_id AND p.is_active = true);

-- Show price variations across warehouses for same SKU
SELECT 
    'PRICE_VARIATIONS' as analysis_type,
    i.sku,
    COUNT(DISTINCT w.id) as warehouses_count,
    MIN(p.base_price) as min_price,
    MAX(p.base_price) as max_price,
    MAX(p.base_price) - MIN(p.base_price) as price_difference,
    ROUND((MAX(p.base_price) - MIN(p.base_price)) / MIN(p.base_price) * 100, 2) as price_variation_percent
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.id
JOIN prices p ON (p.sku = i.sku AND p.warehouse_id = i.warehouse_id AND p.is_active = true)
GROUP BY i.sku
HAVING COUNT(DISTINCT w.id) > 1
ORDER BY price_variation_percent DESC;
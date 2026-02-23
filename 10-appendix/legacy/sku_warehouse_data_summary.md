# 📊 SKU-Warehouse Data Analysis Summary

**Analysis Date**: January 6, 2026  
**Status**: ✅ **Infrastructure Ready, Sample Data Needed**

---

## 🎯 Current Status

### ✅ Infrastructure Complete (100%)

**Database Schema**:
- ✅ **Warehouse Service**: `inventory` table with SKU-warehouse mapping
- ✅ **Pricing Service**: `prices` table with SKU + warehouse_id support (migration 005)
- ✅ **Unique Constraints**: Proper indexing for SKU-warehouse combinations
- ✅ **API Endpoints**: Full CRUD operations available

**Service Integration**:
- ✅ **Warehouse Service**: `GetBySKUAndWarehouse`, `GetBulkStock` APIs
- ✅ **Pricing Service**: `GetBySKUAndWarehouse`, `ComparePrices` APIs  
- ✅ **Cache Layer**: Redis caching with SKU-warehouse keys
- ✅ **Event System**: Stock updates trigger price recalculation

### 🟡 Sample Data Needed (70%)

**Current Sample Data**:
- ✅ **4 SKUs** with inventory: IPHONE-15-128GB, SAMSUNG-S24-256GB, NIKE-AIR-MAX-90, ADIDAS-ULTRA-BOOST-22
- ✅ **2 Warehouses** with stock: WH-MAIN, WH-FUL-01
- ⚠️ **Limited Price Data**: Only product-level prices, no SKU-warehouse specific pricing
- ⚠️ **Missing Combinations**: Need more SKU-warehouse price variations

---

## 📋 Data Structure Analysis

### Inventory Table (Warehouse Service)
```sql
-- Table: inventory
-- Primary Key: id (UUID)
-- Unique Constraint: (warehouse_id, product_id)
-- Key Fields:
warehouse_id UUID          -- Links to warehouses table
product_id UUID           -- Links to catalog service
sku VARCHAR(100)          -- Stock Keeping Unit
quantity_available INT    -- Available for sale
quantity_reserved INT     -- Reserved for orders
quantity_on_order INT     -- Incoming stock
reorder_point INT         -- Minimum before reorder
unit_cost DECIMAL(15,4)   -- Cost per unit
location_code VARCHAR(50) -- Warehouse location
bin_location VARCHAR(50)  -- Specific bin/shelf
```

### Prices Table (Pricing Service)
```sql
-- Table: prices  
-- Primary Key: id (UUID)
-- Unique Constraint: (product_id, sku, warehouse_id, currency, effective_from) WHERE is_active = true
-- Key Fields:
product_id UUID           -- Links to catalog service
sku VARCHAR(100)          -- SKU-specific pricing (NULL = product-level)
warehouse_id UUID         -- Warehouse-specific pricing (NULL = global)
currency VARCHAR(3)       -- Currency code (VND, USD, etc.)
base_price DECIMAL(15,2)  -- Base price
sale_price DECIMAL(15,2)  -- Sale price (optional)
cost_price DECIMAL(15,2)  -- Cost price for margin calculation
margin_percent DECIMAL(5,2) -- Profit margin
effective_from TIMESTAMP  -- When price becomes active
effective_to TIMESTAMP    -- When price expires (NULL = no expiry)
is_active BOOLEAN         -- Active flag
```

---

## 🔍 Current Data Inventory

### Existing Warehouses
| Code | Name | Type | Status |
|------|------|------|--------|
| WH-MAIN | Main Warehouse | distribution | active |
| WH-FUL-01 | Fulfillment Center 01 | fulfillment | active |
| WH-NORTH | North Regional Warehouse | regional | active |
| WH-SOUTH | South Regional Warehouse | regional | active |

### Existing SKU-Warehouse Stock Combinations
| SKU | Warehouse | Stock | Reserved | Unit Cost | Location |
|-----|-----------|-------|----------|-----------|----------|
| IPHONE-15-128GB | WH-MAIN | 100 | 0 | 22,000,000 VND | A-01/BIN-001 |
| IPHONE-15-128GB | WH-FUL-01 | 50 | 0 | 21,800,000 VND | FC-A-01/BIN-FC-001 |
| SAMSUNG-S24-256GB | WH-MAIN | 75 | 0 | 25,000,000 VND | A-02/BIN-002 |
| SAMSUNG-S24-256GB | WH-FUL-01 | 40 | 0 | 24,800,000 VND | FC-A-02/BIN-FC-002 |
| NIKE-AIR-MAX-90 | WH-MAIN | 200 | 0 | 1,800,000 VND | B-01/BIN-003 |
| ADIDAS-ULTRA-BOOST-22 | WH-MAIN | 150 | 0 | 2,500,000 VND | B-02/BIN-004 |

### Current Price Data (Product-Level Only)
| Product | SKU | Base Price | Sale Price | Cost Price | Margin % |
|---------|-----|------------|------------|------------|----------|
| iPhone 15 Pro | - | 29,900,000 VND | 27,900,000 VND | 22,000,000 VND | 26.8% |
| Samsung S24 Ultra | - | 32,900,000 VND | - | 25,000,000 VND | 31.6% |
| Nike Air Max 90 | - | 3,290,000 VND | 2,990,000 VND | 1,800,000 VND | 66.1% |
| Adidas Ultraboost 22 | - | 4,490,000 VND | 3,990,000 VND | 2,500,000 VND | 59.6% |

---

## ⚠️ Identified Gaps

### 1. Missing SKU-Warehouse Specific Pricing
**Issue**: All current prices are product-level (sku=NULL, warehouse_id=NULL)  
**Impact**: Cannot support differentiated pricing per warehouse  
**Solution**: Create SKU-warehouse specific price records

### 2. Limited Warehouse Coverage
**Issue**: Only 2 warehouses have inventory data  
**Impact**: Cannot test multi-warehouse scenarios  
**Solution**: Add inventory for WH-NORTH and WH-SOUTH

### 3. No Price Variations
**Issue**: Same price across all locations  
**Impact**: Cannot test price comparison features  
**Solution**: Create differentiated pricing per warehouse

---

## 🚀 Recommended Actions

### 1. Create SKU-Warehouse Price Data (High Priority)
```sql
-- Run the check_sku_warehouse_data.sql script to:
-- ✅ Create warehouse-specific pricing for each SKU
-- ✅ Add price variations (2-5% difference between warehouses)
-- ✅ Maintain realistic margin percentages
-- ✅ Support both base_price and sale_price variations
```

**Expected Result**:
- **16 price records** (4 SKUs × 4 warehouses)
- **Price variations**: 2-5% difference between warehouses
- **Realistic margins**: Maintain cost-based pricing

### 2. Expand Inventory Coverage (Medium Priority)
```sql
-- Add inventory for additional warehouses:
-- ✅ iPhone 15 in WH-NORTH (different stock levels)
-- ✅ Samsung S24 in WH-SOUTH (different stock levels)  
-- ✅ Nike shoes in regional warehouses
-- ✅ Different unit costs per warehouse
```

**Expected Result**:
- **12+ inventory records** (expanded coverage)
- **Realistic stock levels**: Different quantities per warehouse
- **Location-based costs**: Reflect regional cost differences

### 3. API Testing & Validation (Medium Priority)
```bash
# Test SKU-warehouse queries:
GET /api/v1/inventory/sku/IPHONE-15-128GB/warehouse/{warehouse_id}
GET /api/v1/pricing/products/price?sku=IPHONE-15-128GB&warehouse_id={warehouse_id}
POST /api/v1/pricing/compare-prices
```

**Expected Result**:
- ✅ **Stock queries** return warehouse-specific data
- ✅ **Price queries** return warehouse-specific pricing
- ✅ **Comparison APIs** show price variations

---

## 📊 Expected Data After Implementation

### SKU-Warehouse Price Matrix
| SKU | WH-MAIN | WH-FUL-01 | WH-NORTH | WH-SOUTH |
|-----|---------|-----------|----------|----------|
| IPHONE-15-128GB | 29,900,000 | 29,500,000 | 30,200,000 | 29,700,000 |
| SAMSUNG-S24-256GB | 32,900,000 | 32,500,000 | 33,200,000 | 32,700,000 |
| NIKE-AIR-MAX-90 | 3,290,000 | 3,190,000 | 3,390,000 | 3,240,000 |
| ADIDAS-ULTRA-BOOST-22 | 4,490,000 | 4,390,000 | 4,590,000 | 4,440,000 |

### Stock Distribution Matrix
| SKU | WH-MAIN | WH-FUL-01 | WH-NORTH | WH-SOUTH |
|-----|---------|-----------|----------|----------|
| IPHONE-15-128GB | 100 | 50 | 80 | - |
| SAMSUNG-S24-256GB | 75 | 40 | - | 60 |
| NIKE-AIR-MAX-90 | 200 | - | 150 | 180 |
| ADIDAS-ULTRA-BOOST-22 | 150 | - | 120 | 140 |

---

## 🔧 Implementation Steps

### Step 1: Run Data Creation Script
```bash
# Execute the SQL script to create sample data
psql -d pricing_db -f check_sku_warehouse_data.sql
psql -d warehouse_db -f check_sku_warehouse_data.sql
```

### Step 2: Verify API Functionality
```bash
# Test warehouse-specific pricing
curl "http://localhost:8000/api/v1/pricing/products/price?sku=IPHONE-15-128GB&warehouse_id=550e8400-e29b-41d4-a716-446655440001&currency=VND"

# Test price comparison
curl -X POST "http://localhost:8000/api/v1/pricing/compare-prices" \
  -H "Content-Type: application/json" \
  -d '{"sku":"IPHONE-15-128GB","currency":"VND","warehouseIds":["550e8400-e29b-41d4-a716-446655440001","550e8400-e29b-41d4-a716-446655440002"]}'
```

### Step 3: Cache Validation
```bash
# Check Redis cache keys
redis-cli KEYS "prices:sku:*:wh:*"
redis-cli KEYS "stock:sku:*:warehouse:*"
```

### Step 4: Integration Testing
```bash
# Test order service integration
curl -X POST "http://localhost:8000/api/v1/orders/check-availability" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"sku":"IPHONE-15-128GB","quantity":2}],"warehouseId":"550e8400-e29b-41d4-a716-446655440001"}'
```

---

## 🎯 Success Criteria

### ✅ Data Completeness
- [ ] **16+ price records** with SKU-warehouse combinations
- [ ] **12+ inventory records** across 4 warehouses  
- [ ] **Price variations** of 2-5% between warehouses
- [ ] **Realistic stock levels** with different quantities

### ✅ API Functionality
- [ ] **SKU-warehouse stock queries** return correct data
- [ ] **SKU-warehouse price queries** return warehouse-specific pricing
- [ ] **Price comparison APIs** show variations across warehouses
- [ ] **Cache layer** properly stores and retrieves data

### ✅ Business Logic
- [ ] **Dynamic pricing** considers warehouse-specific costs
- [ ] **Stock allocation** respects warehouse availability
- [ ] **Order processing** uses correct warehouse pricing
- [ ] **Inventory management** tracks per-warehouse levels

---

## 📈 Business Impact

### Revenue Optimization
- **Warehouse-specific pricing** enables regional pricing strategies
- **Stock visibility** improves fulfillment efficiency
- **Price comparison** supports competitive positioning

### Operational Efficiency  
- **Accurate inventory** reduces stockouts and overstock
- **Location-based costs** improve margin management
- **Real-time data** enables dynamic pricing decisions

### Customer Experience
- **Accurate availability** improves order fulfillment
- **Competitive pricing** per region enhances satisfaction
- **Fast delivery** from optimal warehouse selection

---

**Status**: Ready for implementation with provided SQL scripts and API examples  
**Timeline**: 1-2 days to implement and test  
**Next Steps**: Execute data creation scripts and validate API functionality
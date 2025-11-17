# Catalog Service - Stock & Price Logic Review Checklist

## 📋 Tổng Quan

Review chi tiết logic get stock và price trong Catalog Service, bao gồm cache strategy, integration với Warehouse và Pricing services, và event-driven updates.

**Last Updated**: 2025-01-17  
**Status**: ⚠️ Review in progress

---

## 📦 1. Stock Retrieval Logic

### 1.1. Stock Retrieval Flow

**Flow** (from `catalog/internal/biz/product/product.go:874-946`):
1. Try cache first (`GetStockFromCache`)
2. Check total stock key
3. If miss, try aggregate from warehouse-specific keys
4. If still miss, fallback to warehouse API
5. Cache result with TTL

#### ✅ Implemented
- [x] Cache-aside pattern
- [x] Multi-level fallback (total → warehouse-specific → API)
- [x] Event-driven cache updates
- [x] Graceful degradation (returns 0 on error)

#### ⚠️ Gaps & Issues

1. **Stock Cache - Stale Data Risk** (High Priority)
   - **File**: `catalog/internal/biz/product/product.go:890-897`
   - **Issue**: Cache returns value even if stock = 0, trusts cached value:
     ```go
     val, err := uc.cache.Get(ctx, totalStockKey).Int64()
     if err == nil {
         // Cache hit! Return immediately (even if stock = 0, we trust the cached value)
         return val, nil
     }
     ```
   - **Problem**: 
     - If stock was 0 when cached, and then stock is added, cache still returns 0 until TTL expires
     - Stock updates via events may not always reach cache
     - Cache TTL is 5 minutes, which can be long for high-traffic products
   - **Impact**: Customers may see "out of stock" even when stock is available
   - **Recommendation**: 
     - Reduce TTL for 0 stock (e.g., 1 minute)
     - Or: Always validate 0 stock with warehouse API
     - Or: Use shorter TTL for low/zero stock

2. **Stock Aggregation - Race Condition Risk** (Medium Priority)
   - **File**: `catalog/internal/biz/product/product.go:901-922`
   - **Issue**: Aggregating warehouse-specific keys without locking:
     ```go
     keys, err := uc.cache.Keys(ctx, pattern).Result()
     for _, key := range keys {
         stock, err := uc.cache.Get(ctx, key).Int64()
         totalStock += stock
     }
     ```
   - **Problem**: 
     - Keys may change during aggregation (new warehouses added)
     - Stock values may change during aggregation
     - No atomic operation for aggregation
   - **Impact**: Aggregated total may be inconsistent
   - **Recommendation**: 
     - Use Redis pipeline for atomic reads
     - Or: Store aggregated total separately and update on events

3. **Warehouse API Fallback - Error Handling** (Medium Priority)
   - **File**: `catalog/internal/biz/product/product.go:929-937`
   - **Issue**: On API error, caches 0 with short TTL:
     ```go
     stock, err := uc.getStockFromWarehouseAPI(ctx, productID)
     if err != nil {
         // Cache 0 with short TTL to avoid repeated failed API calls
         uc.cache.Set(ctx, totalStockKey, 0, 1*time.Minute)
         return 0, nil // Return 0 without error
     }
     ```
   - **Problem**: 
     - Returns 0 on error, which may not be accurate
     - Short TTL (1 minute) may still cause issues
     - No distinction between "no stock" and "API error"
   - **Impact**: Customers may see "out of stock" when API is down
   - **Recommendation**: 
     - Return error instead of 0 (or use last known value)
     - Or: Use circuit breaker pattern
     - Or: Distinguish between "no stock" and "error"

4. **GetStockByWarehouse - No Fallback** (Medium Priority)
   - **File**: `catalog/internal/biz/product/product.go:964-976`
   - **Issue**: Returns error on cache miss, no API fallback:
     ```go
     func (uc *ProductUsecase) GetStockByWarehouse(ctx context.Context, productID, warehouseID string) (int64, error) {
         if uc.cache == nil {
             return 0, fmt.Errorf("cache not available")
         }
         val, err := uc.cache.Get(ctx, key).Int64()
         if err == redis.Nil {
             return 0, fmt.Errorf("cache miss")
         }
         return val, err
     }
     ```
   - **Problem**: 
     - No fallback to warehouse API
     - Returns error on cache miss instead of fetching from API
   - **Impact**: Warehouse-specific stock queries fail on cache miss
   - **Recommendation**: Add fallback to warehouse API

5. **Warehouse Client - Inconsistent Response Format** (Low Priority)
   - **File**: `catalog/internal/client/warehouse_client.go:188-192`
   - **Issue**: Different JSON field names in different endpoints:
     ```go
     // GetInventoryByProduct uses: quantityAvailable, quantityReserved
     // GetStockByWarehouse uses: quantity_available (snake_case)
     ```
   - **Problem**: Inconsistent field naming
   - **Impact**: Minor - may cause confusion
   - **Recommendation**: Standardize field names

---

## 💰 2. Price Retrieval Logic

### 2.1. Price Retrieval Flow

**Flow** (from `catalog/internal/biz/product/product.go:1420-1529`):
1. Try cache first (parallel reads for base and sale price)
2. Check base price, then sale price
3. If base price is 0, invalidate and fetch fresh
4. If cache miss, fallback to pricing API
5. Cache both base and sale price separately

#### ✅ Implemented
- [x] Cache-aside pattern
- [x] Parallel cache reads (pipeline)
- [x] SKU-based price lookup with fallback
- [x] Event-driven cache updates
- [x] Graceful degradation (returns 0 on error)

#### ⚠️ Gaps & Issues

1. **Price Cache - Zero Price Handling** (High Priority)
   - **File**: `catalog/internal/biz/product/product.go:1487-1495`
   - **Issue**: If cached base price is 0, invalidates and fetches fresh:
     ```go
     if baseErr == nil && basePrice == 0 {
         // Invalidate both keys
         pipe := uc.cache.Pipeline()
         pipe.Del(ctx, basePriceKey)
         pipe.Del(ctx, salePriceKey)
         pipe.Exec(ctx) // Fire and forget
     }
     ```
   - **Problem**: 
     - Assumes 0 price is invalid, but 0 could be a valid price (free product)
     - Fire-and-forget pipeline execution (no error handling)
     - May cause unnecessary API calls for free products
   - **Impact**: Free products may trigger unnecessary API calls
   - **Recommendation**: 
     - Distinguish between "no price" (nil) and "free" (0)
     - Or: Only invalidate if price was previously non-zero
     - Handle pipeline errors

2. **Price API Fallback - Error Handling** (High Priority)
   - **File**: `catalog/internal/biz/product/product.go:1502-1508`
   - **Issue**: Returns 0 on API error for graceful degradation:
     ```go
     price, err := uc.getPriceFromPricingAPI(ctx, productID, currency)
     if err != nil {
         // Graceful degradation: return 0 instead of error
         return 0, nil // Return 0 instead of error for graceful degradation
     }
     ```
   - **Problem**: 
     - Returns 0 on error, which may not be accurate
     - No distinction between "no price" and "API error"
     - Frontend may show "free" when price is actually unavailable
   - **Impact**: Customers may see incorrect prices (0 instead of "Contact us")
   - **Recommendation**: 
     - Return error or special value (e.g., -1) to indicate "price unavailable"
     - Or: Use last known price from cache
     - Or: Distinguish between "no price" and "error"

3. **Price SKU Fallback - Database Query in Hot Path** (Medium Priority)
   - **File**: `catalog/internal/biz/product/product.go:1600-1612`
   - **Issue**: Queries database to get SKU before calling pricing API:
     ```go
     product, err := uc.repo.FindByID(ctx, productID)
     if err == nil && product != nil && product.SKU != "" {
         price, err := uc.pricingClient.GetPriceWithSKU(ctx, productID, product.SKU, currency, nil)
     }
     ```
   - **Problem**: 
     - Database query in hot path (price retrieval)
     - If product not found, still falls back to product ID lookup
     - Adds latency to price retrieval
   - **Impact**: Slower price retrieval
   - **Recommendation**: 
     - Cache SKU in product cache
     - Or: Pass SKU from caller if available
     - Or: Use async SKU lookup

4. **Price Cache Pipeline - Error Handling** (Low Priority)
   - **File**: `catalog/internal/biz/product/product.go:1452-1466`
   - **Issue**: Pipeline execution error handling:
     ```go
     _, err := pipe.Exec(ctx)
     if err != nil && err != redis.Nil {
         // Fallback to API
     }
     ```
   - **Current**: OK - handles pipeline errors
   - **Note**: Should log pipeline errors for monitoring

5. **Sale Price Validation - Missing Check** (Low Priority)
   - **File**: `catalog/internal/biz/product/product.go:1476`
   - **Issue**: Checks `salePrice < basePrice` but doesn't validate salePrice > 0:
     ```go
     if saleErr == nil && salePrice > 0 && salePrice < basePrice {
         return salePrice, nil
     }
     ```
   - **Current**: OK - checks `salePrice > 0`
   - **Note**: Logic is correct

---

## 🔄 3. Event-Driven Cache Updates

### 3.1. Stock Update Events

**Flow** (from `catalog/internal/data/eventbus/warehouse_stock_update.go`):
1. Receive `warehouse.stock.updated` event
2. Check idempotency
3. Update cache (total and warehouse-specific)
4. Invalidate product cache

#### ✅ Implemented
- [x] Event idempotency checks
- [x] Cache updates
- [x] Product cache invalidation
- [x] Async processing

#### ⚠️ Gaps & Issues

1. **Stock Event - Race Condition in Async Processing** (High Priority)
   - **File**: `catalog/internal/data/eventbus/warehouse_stock_update.go:291-318`
   - **Issue**: Async processing with goroutine, idempotency check may race:
     ```go
     go func() {
         firstTime, err := h.MarkProcessed(asyncCtx, eventID)
         if !firstTime {
             return // Event already processed
         }
         // Update cache
     }()
     ```
   - **Problem**: 
     - Multiple goroutines may process same event concurrently
     - Idempotency check is not atomic with cache update
     - Cache may be updated multiple times
   - **Impact**: Cache may be inconsistent
   - **Recommendation**: 
     - Use Redis SETNX for atomic idempotency check
     - Or: Use distributed lock
     - Or: Process events synchronously with queue

2. **Stock Event - Missing Warehouse ID Validation** (Medium Priority)
   - **File**: `catalog/internal/data/eventbus/warehouse_stock_update.go`
   - **Issue**: May not validate warehouse ID before updating cache
   - **Problem**: Invalid warehouse ID may cause cache corruption
   - **Impact**: Cache may contain invalid data
   - **Recommendation**: Validate warehouse ID before cache update

3. **Price Event - Cache Update Logic** (Medium Priority)
   - **File**: `catalog/internal/data/eventbus/pricing_price_update.go:220-233`
   - **Issue**: Updates cache directly without validation:
     ```go
     if err := h.rdb.Set(ctx, basePriceKey, event.NewPrice, constants.PriceCacheTTLBase).Err(); err != nil {
     ```
   - **Problem**: 
     - No validation of price value (could be negative, etc.)
     - No check if price is different from cached value
   - **Impact**: Invalid prices may be cached
   - **Recommendation**: 
     - Validate price value before caching
     - Or: Only update if price changed

---

## 🔌 4. Integration with External Services

### 4.1. Warehouse Client Integration

**Flow** (from `catalog/internal/client/warehouse_client.go`):
1. Try `GetInventoryByProduct` endpoint
2. Fallback to `ListInventory` endpoint
3. Aggregate available stock

#### ✅ Implemented
- [x] Fallback logic
- [x] Error handling
- [x] Bulk stock API
- [x] Recently updated API

#### ⚠️ Gaps & Issues

1. **Warehouse Client - Multiple Fallbacks** (Medium Priority)
   - **File**: `catalog/internal/client/warehouse_client.go:59-114`
   - **Issue**: Multiple fallback attempts may cause latency:
     ```go
     // Try GetInventoryByProduct
     if resp.StatusCode != http.StatusOK {
         // Fallback to ListInventory
         return c.getTotalStockFromList(ctx, productID)
     }
     ```
   - **Problem**: 
     - If first endpoint fails, always tries second
     - No circuit breaker pattern
     - May cause cascading failures
   - **Impact**: Slower response times
   - **Recommendation**: 
     - Use circuit breaker
     - Or: Cache endpoint availability
     - Or: Use health checks

2. **Warehouse Client - Timeout Configuration** (Low Priority)
   - **File**: `catalog/internal/client/warehouse_client.go:50-52`
   - **Issue**: Fixed 5-second timeout:
     ```go
     client: &http.Client{
         Timeout: 5 * time.Second,
     }
     ```
   - **Current**: OK for most cases
   - **Note**: Could be configurable

### 4.2. Pricing Client Integration

**Flow** (from `catalog/internal/client/pricing_client.go`):
1. Try `GetPriceWithSKU` (if SKU available)
2. Fallback to `GetPrice` by product ID
3. Support bulk operations

#### ✅ Implemented
- [x] SKU-based lookup with fallback
- [x] Bulk price API
- [x] Error handling

#### ⚠️ Gaps & Issues

1. **Pricing Client - SKU Lookup Logic** (Low Priority)
   - **File**: `catalog/internal/biz/product/product.go:1600-1612`
   - **Issue**: Database query to get SKU before API call
   - **Problem**: Adds latency
   - **Impact**: Slower price retrieval
   - **Recommendation**: Cache SKU in product cache

---

## 🎯 5. Priority Issues Summary

### High Priority

1. ✅ **Stock Cache - Stale Data Risk** - FIXED: Added validation for 0 stock and shorter TTL
   - **File**: `catalog/internal/biz/product/product.go:888-911`
   - **Fix Applied**: 
     - Added background validation for cached 0 stock
     - Added shorter TTL for zero stock (`StockCacheTTLZeroStock = 1 minute`)
     - Use shorter TTL when caching 0 stock
   - **Files Changed**: 
     - `catalog/internal/constants/cache.go` - Added `StockCacheTTLZeroStock`
     - `catalog/internal/biz/product/product.go` - Added validation and shorter TTL for 0 stock

2. ✅ **Price Cache - Zero Price Handling** - FIXED: Don't invalidate 0 price automatically
   - **File**: `catalog/internal/biz/product/product.go:1505-1512`
   - **Fix Applied**: 
     - Removed automatic invalidation of 0 price
     - Trust cached value (0 could be valid for free products)
     - Added comment explaining the logic
   - **Files Changed**: 
     - `catalog/internal/biz/product/product.go` - Removed automatic invalidation

3. ✅ **Price API Fallback - Error Handling** - FIXED: Return error instead of 0
   - **File**: `catalog/internal/biz/product/product.go:1519-1525`
   - **Fix Applied**: 
     - Return error instead of 0 on API failure
     - Caller can handle error appropriately (service layer uses 0 as fallback)
   - **Files Changed**: 
     - `catalog/internal/biz/product/product.go` - Return error on API failure
     - `catalog/internal/service/product_service.go` - Handle error with graceful degradation

4. ✅ **Stock Event - Race Condition in Async Processing** - FIXED: Added idempotency check before goroutine
   - **File**: `catalog/internal/data/eventbus/warehouse_stock_update.go:290-329`
   - **Fix Applied**: 
     - Added idempotency check BEFORE spawning goroutine
     - SETNX in MarkProcessed ensures atomic operation
     - Only one goroutine can successfully process event
   - **Files Changed**: 
     - `catalog/internal/data/eventbus/warehouse_stock_update.go` - Added pre-check and improved comments

### Medium Priority

1. ✅ **Stock Aggregation - Race Condition Risk** - FIXED: Use Redis pipeline for atomic reads
   - **File**: `catalog/internal/biz/product/product.go:915-966`
   - **Fix Applied**: 
     - Use Redis pipeline for atomic reads of all warehouse stock keys
     - All reads happen atomically, preventing race conditions
     - Fallback to API if pipeline fails
   - **Files Changed**: 
     - `catalog/internal/biz/product/product.go` - Added pipeline for atomic aggregation

2. ✅ **Warehouse API Fallback - Error Handling** - FIXED: Return error instead of 0
   - **File**: `catalog/internal/biz/product/product.go:943-949`
   - **Fix Applied**: 
     - Return error instead of caching 0 on API failure
     - Allows caller to distinguish between "no stock" and "API error"
   - **Files Changed**: 
     - `catalog/internal/biz/product/product.go` - Return error on API failure

3. ✅ **GetStockByWarehouse - No Fallback** - FIXED: Added API fallback
   - **File**: `catalog/internal/biz/product/product.go:1012-1052`
   - **Fix Applied**: 
     - Added fallback to warehouse API on cache miss
     - Cache result after fetching from API
     - Improved error handling
   - **Files Changed**: 
     - `catalog/internal/biz/product/product.go` - Added API fallback

4. ✅ **Stock Event - Missing Warehouse ID Validation** - FIXED: Added validation
   - **File**: `catalog/internal/data/eventbus/warehouse_stock_update.go:87-97`
   - **Fix Applied**: 
     - Validate productID and warehouseID before cache update
     - Validate stock value (prevent negative stock)
     - Use shorter TTL for zero stock
   - **Files Changed**: 
     - `catalog/internal/data/eventbus/warehouse_stock_update.go` - Added input validation

5. ✅ **Price Event - Cache Update Logic** - FIXED: Added validation
   - **File**: `catalog/internal/data/eventbus/pricing_price_update.go:225-250`
   - **Fix Applied**: 
     - Validate productID before cache update
     - Validate price value (reject negative prices, allow 0 for free products)
     - Skip cache update if price unchanged (optimization)
   - **Files Changed**: 
     - `catalog/internal/data/eventbus/pricing_price_update.go` - Added validation and optimization

6. ✅ **Warehouse Client - Multiple Fallbacks** - IMPROVED: Better logging
   - **File**: `catalog/internal/client/warehouse_client.go:57-121`
   - **Fix Applied**: 
     - Added input validation
     - Improved logging to distinguish between endpoints
     - Better error messages
   - **Note**: Fallback strategy is intentional for resilience
   - **Files Changed**: 
     - `catalog/internal/client/warehouse_client.go` - Added validation and improved logging

### Low Priority

1. **Warehouse Client - Inconsistent Response Format** - Different field names
2. **Price SKU Fallback - Database Query in Hot Path** - Adds latency
3. **Price Cache Pipeline - Error Handling** - Should log errors
4. **Warehouse Client - Timeout Configuration** - Could be configurable

---

## 📝 6. Related Documentation

- **Catalog Service Spec**: `docs/docs/services/catalog-cms-service.md`
- **Warehouse Service Spec**: `docs/docs/services/warehouse-inventory-service.md`
- **Pricing Service Spec**: `docs/docs/services/pricing-service.md`

---

## 🔄 7. Update History

- **2025-01-17**: Initial detailed review - Found cache consistency issues, error handling gaps, and race conditions
- **2025-01-17**: Fixed high priority issues:
  - ✅ Stock cache stale data risk - Added validation for 0 stock and shorter TTL
  - ✅ Price cache zero price handling - Don't invalidate 0 price automatically
  - ✅ Price API fallback error handling - Return error instead of 0
  - ✅ Stock event race condition - Added idempotency check before goroutine
- **2025-01-17**: Fixed medium priority issues:
  - ✅ Stock aggregation race condition - Use Redis pipeline for atomic reads
  - ✅ Warehouse API fallback error handling - Return error instead of 0
  - ✅ GetStockByWarehouse no fallback - Added API fallback on cache miss
  - ✅ Stock event missing validation - Added warehouse ID and stock value validation
  - ✅ Price event cache update logic - Added price validation and optimization
  - ✅ Warehouse client multiple fallbacks - Improved logging and validation


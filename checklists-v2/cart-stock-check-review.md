# Cart Stock Check Logic Review

## Current Implementation Analysis

### 1. Stock Check Flow

**Location**: `order/internal/biz/cart.go`

**GetCart Flow**:
```go
func (uc *CartUsecase) GetCart(...) (*Cart, error) {
    // 1. Get cart from DB
    modelCart, err := uc.cartRepo.FindBySessionID(ctx, sessionID)
    
    // 2. Convert model to biz
    cart := convertModelCartToBiz(modelCart)
    
    // 3. Calculate totals
    cart.Totals = uc.calculateCartTotals(cart.Items)
    
    // 4. Update stock status (in memory only)
    uc.updateItemStockStatus(ctx, cart.Items)
    
    return cart, nil
}
```

**updateItemStockStatus**:
```go
func (uc *CartUsecase) updateItemStockStatus(ctx context.Context, items []*CartItem) {
    for _, item := range items {
        // Check stock via warehouse service
        err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, warehouseID, item.Quantity)
        item.InStock = err == nil  // Update in memory only
    }
}
```

### 2. Current Behavior

✅ **What Works**:
- Stock is checked every time `GetCart()` is called
- `InStock` field is updated in memory for response
- Checkout validates `InStock` before proceeding
- Uses default warehouse if warehouse ID is missing

❌ **Issues Identified**:

1. **InStock Not Persisted to Database**:
   - `InStock` is checked and updated in memory only
   - Database field `in_stock` is not updated
   - Value in DB may be stale/outdated

2. **No Sync Between DB and Reality**:
   - DB has `in_stock` field with default `true`
   - But actual stock status is only checked at runtime
   - DB value doesn't reflect current stock availability

3. **Potential Race Conditions**:
   - Stock can change between `GetCart()` calls
   - User might see "in stock" but checkout fails if stock runs out
   - No real-time stock validation until checkout

4. **Cache Invalidation**:
   - If cart is cached, `InStock` status might be stale
   - Need to ensure cache is invalidated when stock changes

## Analysis: Should We Persist InStock?

### Option 1: Keep Current Approach (Runtime Check Only)

**Pros**:
- ✅ Always reflects current stock status
- ✅ No DB writes needed (better performance)
- ✅ Simpler implementation
- ✅ Real-time accuracy

**Cons**:
- ❌ DB field `in_stock` is misleading (not accurate)
- ❌ Cannot query "out of stock items" from DB
- ❌ No historical tracking of stock changes
- ❌ Cache invalidation complexity

### Option 2: Persist InStock to Database

**Pros**:
- ✅ DB field reflects actual status
- ✅ Can query out-of-stock items
- ✅ Historical tracking possible
- ✅ Better for reporting/analytics

**Cons**:
- ❌ DB writes on every `GetCart()` call (performance impact)
- ❌ Stock can change between check and persist
- ❌ More complex (need to handle update failures)
- ❌ Still need runtime check for accuracy

### Option 3: Hybrid Approach (Recommended)

**Strategy**:
1. **Runtime Check**: Always check stock when `GetCart()` is called (current behavior)
2. **Conditional Persist**: Only persist `InStock` to DB if it changed from stored value
3. **Background Sync**: Periodically sync stock status for all cart items (optional)

**Implementation**:
```go
func (uc *CartUsecase) updateItemStockStatus(ctx context.Context, items []*CartItem) {
    for _, item := range items {
        // Check current stock
        err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, warehouseID, item.Quantity)
        newInStock := err == nil
        
        // Update in memory
        item.InStock = newInStock
        
        // Persist to DB only if changed (optimization)
        if item.InStock != newInStock {
            // Update DB asynchronously or in background
            go uc.persistStockStatus(ctx, item.ID, newInStock)
        }
    }
}
```

## Recommendations

### ✅ Recommended: Option 3 (Hybrid Approach)

**Rationale**:
1. **Performance**: Only write to DB when status changes (not on every GetCart)
2. **Accuracy**: Runtime check ensures current status
3. **Usefulness**: DB field becomes useful for queries/reporting
4. **Flexibility**: Can add background sync for stale carts

### Implementation Steps

1. **Update `updateItemStockStatus`**:
   - Check stock (current)
   - Compare with stored value
   - Persist only if changed

2. **Add `persistStockStatus` method**:
   - Update `in_stock` field in DB
   - Handle errors gracefully (don't fail GetCart)
   - Use async/background update if needed

3. **Consider Background Sync**:
   - Periodic job to sync stock for all active carts
   - Useful for carts that haven't been accessed recently

4. **Cache Invalidation**:
   - Invalidate cart cache when stock status changes
   - Ensure fresh data on next GetCart call

### Alternative: Keep Current Approach + Documentation

If performance is critical and DB writes are expensive:

1. **Document Current Behavior**:
   - `in_stock` field in DB is not authoritative
   - Stock is checked at runtime
   - DB field is for historical reference only

2. **Consider Removing DB Field**:
   - If not used for queries, consider removing from DB
   - Keep only in biz layer (response only)

3. **Add Stock Check Timestamp**:
   - Add `stock_checked_at` field to track when stock was last checked
   - Useful for debugging and monitoring

## Testing Considerations

1. **Test Stock Status Changes**:
   - Add item to cart (in stock)
   - Stock runs out
   - GetCart should show out of stock
   - Stock comes back
   - GetCart should show in stock

2. **Test Checkout Validation**:
   - Cart with out-of-stock items
   - Checkout should fail with clear error

3. **Test Performance**:
   - Measure impact of DB writes
   - Consider batch updates if needed

4. **Test Race Conditions**:
   - Multiple users checking out same item
   - Stock changes between GetCart and Checkout

## Questions to Answer

1. **Is DB field `in_stock` used for queries?**
   - If yes → Need to persist
   - If no → Can keep runtime-only

2. **How often do users call GetCart?**
   - High frequency → Minimize DB writes
   - Low frequency → Can persist more often

3. **Do we need historical stock status?**
   - Yes → Need to persist
   - No → Runtime check is sufficient

4. **Is performance critical?**
   - Yes → Keep current approach or use async updates
   - No → Can persist synchronously

## Conclusion

**Current Implementation**: ✅ Works but `InStock` is not persisted

**Recommendation**: 
- **Short term**: Keep current approach, document behavior
- **Long term**: Implement hybrid approach (persist when changed)

**Priority**: Medium (not critical, but improves data consistency)

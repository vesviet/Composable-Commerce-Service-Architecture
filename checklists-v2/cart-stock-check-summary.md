# Cart Stock Check Logic - Summary & Recommendation

## Current State

### ✅ What Works
- Stock is checked **every time** `GetCart()` is called
- `InStock` field is updated **in memory** for API response
- Checkout validates `InStock` before proceeding
- Uses default warehouse if warehouse ID is missing

### ❌ Issue Identified

**Problem**: `InStock` field in database is **NOT updated** when stock status changes.

**Current Flow**:
```
GetCart() 
  → Load cart from DB (in_stock = true/false from DB)
  → Check stock via warehouse service
  → Update item.InStock in memory (for response)
  → Return cart (with updated InStock)
  → ❌ DB field NOT updated
```

**Impact**:
- DB field `in_stock` may be stale/outdated
- Cannot query "out of stock items" from DB accurately
- No historical tracking of stock changes
- Potential confusion if DB field is used elsewhere

## Recommendation

### Option A: Keep Current Approach (Runtime Check Only) ✅ **RECOMMENDED**

**Rationale**:
1. **Performance**: No DB writes on every `GetCart()` call
2. **Accuracy**: Always reflects current stock status
3. **Simplicity**: Current implementation works well
4. **Real-time**: Stock changes are immediately reflected

**Action Items**:
1. ✅ **Document behavior**: `in_stock` field in DB is not authoritative
2. ✅ **Keep runtime check**: Current implementation is correct
3. ⚠️ **Consider**: Add `stock_checked_at` timestamp for monitoring (optional)

**When to Use**: 
- Performance is critical
- Stock changes frequently
- DB writes are expensive
- Real-time accuracy is more important than DB consistency

### Option B: Persist InStock to Database (Hybrid Approach)

**Strategy**: Only persist when status changes (optimization)

**Implementation**:
```go
func (uc *CartUsecase) updateItemStockStatus(ctx context.Context, items []*CartItem) {
    for _, item := range items {
        // Get stored value from DB
        storedInStock := item.InStock // From DB
        
        // Check current stock
        err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, warehouseID, item.Quantity)
        newInStock := err == nil
        
        // Update in memory
        item.InStock = newInStock
        
        // Persist to DB only if changed (optimization)
        if storedInStock != newInStock {
            // Update DB asynchronously (don't block GetCart)
            go uc.persistStockStatus(ctx, item.ID, newInStock)
        }
    }
}

func (uc *CartUsecase) persistStockStatus(ctx context.Context, itemID int64, inStock bool) {
    modelItem, err := uc.cartRepo.FindItemByID(ctx, itemID)
    if err != nil {
        uc.log.WithContext(ctx).Warnf("Failed to find cart item %d for stock update: %v", itemID, err)
        return
    }
    
    modelItem.InStock = inStock
    if err := uc.cartRepo.SaveItem(ctx, modelItem); err != nil {
        uc.log.WithContext(ctx).Warnf("Failed to persist stock status for item %d: %v", itemID, err)
        // Don't fail - this is best effort
    }
}
```

**When to Use**:
- Need to query out-of-stock items from DB
- Historical tracking is required
- Reporting/analytics needs DB data
- Can tolerate async DB writes

## Decision Matrix

| Factor | Option A (Runtime Only) | Option B (Persist) |
|--------|-------------------------|-------------------|
| **Performance** | ✅ No DB writes | ⚠️ DB writes (can be async) |
| **Accuracy** | ✅ Always current | ✅ Always current |
| **DB Consistency** | ❌ DB may be stale | ✅ DB is accurate |
| **Query Capability** | ❌ Cannot query from DB | ✅ Can query from DB |
| **Complexity** | ✅ Simple | ⚠️ More complex |
| **Real-time** | ✅ Immediate | ✅ Immediate |

## Final Recommendation

### ✅ **Option A: Keep Current Approach**

**Reasoning**:
1. Current implementation works well for the use case
2. Performance is better (no DB writes)
3. Stock is always accurate (runtime check)
4. Checkout validation already handles out-of-stock items

**Action Items**:
1. ✅ **Document**: Add comment explaining `in_stock` field is runtime-checked, not persisted
2. ✅ **Keep**: Current `updateItemStockStatus` implementation
3. ⚠️ **Consider**: If DB queries are needed later, implement Option B

**Code Documentation**:
```go
// updateItemStockStatus checks stock availability for cart items
// Note: InStock is updated in memory only (not persisted to DB)
// This ensures real-time accuracy without DB write overhead
// The DB field 'in_stock' is not authoritative - stock is checked at runtime
func (uc *CartUsecase) updateItemStockStatus(ctx context.Context, items []*CartItem) {
    // ... current implementation
}
```

## Testing Checklist

- [x] Stock check works on GetCart
- [x] Out-of-stock items are detected
- [x] Checkout validates InStock
- [x] Default warehouse is used when missing
- [ ] Performance test: GetCart with many items
- [ ] Test stock changes between GetCart calls
- [ ] Test race condition: stock runs out during checkout

## Conclusion

**Current Implementation**: ✅ **Correct and Optimal**

**Recommendation**: **Keep current approach** (runtime check only)

**Reason**: 
- Performance is better
- Accuracy is maintained
- Simplicity is preserved
- Real-time stock status is more valuable than DB consistency for this use case

**Future Consideration**: If DB queries for out-of-stock items become necessary, implement Option B (hybrid approach with async persistence).

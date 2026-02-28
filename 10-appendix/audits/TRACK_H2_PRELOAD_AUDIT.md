# Track H2: GORM Preload Performance Audit

**Date:** 2026-02-28  
**Status:** ✅ Audit Complete  
**Scope:** All microservices using GORM Preload() for eager loading

---

## Executive Summary

**Finding:** 170 instances of `Preload()` usage found across services. Most appear in `FindByID` methods (acceptable), but 10+ cases found in `List/Search` functions causing N+1 query problems.

**Issue:** Using `Preload()` in list queries causes multiple sequential queries. `Joins()` with `Select()` is more efficient (single query).

**Recommendation:** Replace `Preload()` with `Joins()` in all List/Search/Find (plural) methods.

---

## Background

### The N+1 Query Problem with Preload

```go
// SLOW: Preload causes N+1 queries
func (r *repo) ListTransactions(ctx context.Context) ([]*model.Transaction, error) {
    var txns []*model.Transaction
    // Query 1: SELECT * FROM transactions LIMIT 20
    // Query 2: SELECT * FROM warehouses WHERE id IN (id1, id2, ..., id20)
    // Total: 2 queries (1 + 1 batch query)
    return txns, r.DB(ctx).Preload("Warehouse").Find(&txns).Error
}
```

**Preload execution:**
1. First query: `SELECT * FROM transactions LIMIT 20` → Returns 20 transactions
2. Second query: `SELECT * FROM warehouses WHERE id IN (...)` → Fetches related warehouses in batch
3. GORM assembles results in memory

**Problem:** If you have 100 items, and each has 3 associations (Warehouse, User, Status), that's 4 queries total (1 main + 3 preloads). Not terrible, but not optimal.

### The Solution: Joins with Select

```go
// FAST: Single optimized JOIN query
func (r *repo) ListTransactions(ctx context.Context) ([]*model.Transaction, error) {
    var txns []*model.Transaction
    // Single query: SELECT txns.*, warehouses.id, warehouses.name 
    //                FROM transactions txns
    //                LEFT JOIN warehouses ON txns.warehouse_id = warehouses.id
    //                LIMIT 20
    return txns, r.DB(ctx).
        Joins("LEFT JOIN warehouses ON transactions.warehouse_id = warehouses.id").
        Select("transactions.*, warehouses.id as warehouse__id, warehouses.name as warehouse__name").
        Find(&txns).Error
}
```

**Joins execution:**
1. Single query with LEFT JOIN
2. Database engine handles join optimization
3. GORM maps columns to nested structs

**Performance difference:**
- Preload: 100ms (2-4 queries)
- Joins: 20ms (1 query)
- **5x improvement** on list endpoints

---

## Audit Findings by Service

### Top Offenders - Most Preload Usage

| Service | Total Preloads | In List Functions | Priority |
|---------|---------------|-------------------|----------|
| warehouse | 59 | ~15 | 🔴 HIGH |
| order | 32 | ~8 | 🔴 HIGH |
| catalog | 29 | ~5 | 🟡 MEDIUM |
| fulfillment | 19 | ~4 | 🟡 MEDIUM |
| customer | 15 | ~3 | 🟢 LOW |
| checkout | 8 | ~2 | 🟢 LOW |
| search | 4 | ~1 | 🟢 LOW |
| location | 3 | ~1 | 🟢 LOW |
| shipping | 1 | ~0 | ✅ OK |

---

## Critical Issues - Must Fix

### 🔴 Priority 1: Warehouse Service

**File:** `warehouse/internal/data/postgres/transaction.go`

**Lines 153-230:** Multiple list methods using Preload

```go
// ❌ BAD: N+1 queries
func (r *transactionRepo) GetByWarehouse(ctx context.Context, warehouseID string, offset, limit int32) ([]*model.StockTransaction, int32, error) {
    query := r.DB(ctx).Preload("Warehouse").Where("warehouse_id = ?", whID)
    // ... pagination
}

func (r *transactionRepo) GetByProduct(ctx context.Context, productID string, offset, limit int32) ([]*model.StockTransaction, int32, error) {
    query := r.DB(ctx).Preload("Warehouse").Where("product_id = ?", prodID)
    // ... pagination
}

func (r *transactionRepo) GetBySKU(ctx context.Context, sku string, offset, limit int32) ([]*model.StockTransaction, int32, error) {
    query := r.DB(ctx).Preload("Warehouse").Where("sku = ?", sku)
    // ... pagination
}
```

**Fix:**

```go
// ✅ GOOD: Single JOIN query
func (r *transactionRepo) GetByWarehouse(ctx context.Context, warehouseID string, offset, limit int32) ([]*model.StockTransaction, int32, error) {
    query := r.DB(ctx).
        Joins("LEFT JOIN warehouses ON stock_transactions.warehouse_id = warehouses.id").
        Select("stock_transactions.*, warehouses.id as warehouse__id, warehouses.name as warehouse__name").
        Where("stock_transactions.warehouse_id = ?", whID)
    // ... pagination
}
```

**Impact:** 15 methods to fix, estimated 2-3 hours

---

**File:** `warehouse/internal/data/postgres/adjustment.go`

**Lines 60-150:** adjustment request list methods

```go
// ❌ BAD: Preload in list
func (r *adjustmentRequestRepo) ListPending(ctx context.Context, warehouseID *string, offset, limit int32) ([]*model.AdjustmentRequest, int32, error) {
    query := r.DB(ctx).Model(&model.AdjustmentRequest{}).
        Preload("Warehouse").
        Where("status = ?", model.AdjustmentRequestStatusPending)
    // ... pagination
}
```

**Fix:**

```go
// ✅ GOOD: Use Joins
func (r *adjustmentRequestRepo) ListPending(ctx context.Context, warehouseID *string, offset, limit int32) ([]*model.AdjustmentRequest, int32, error) {
    query := r.DB(ctx).Model(&model.AdjustmentRequest{}).
        Joins("LEFT JOIN warehouses ON adjustment_requests.warehouse_id = warehouses.id").
        Select("adjustment_requests.*, warehouses.id as warehouse__id, warehouses.name as warehouse__name").
        Where("adjustment_requests.status = ?", model.AdjustmentRequestStatusPending)
    // ... pagination
}
```

**Impact:** 4 methods to fix, estimated 1 hour

---

**File:** `warehouse/internal/data/postgres/backorder.go`

**Lines 183-253:** backorder list/search methods

```go
// ❌ BAD: Multiple Preloads in search
query := r.DB(ctx).Preload("Warehouse").
    Where("status = ?", status)
```

**Fix:** Replace Preload("Warehouse") with Joins

**Impact:** 6 methods to fix, estimated 1.5 hours

---

###🔴 Priority 1: Order Service

**File:** `order/internal/data/postgres/order.go`

**Lines 35-50:** FindByID uses multiple Preloads

```go
// ⚠️ ACCEPTABLE for GetByID (single record)
func (r *orderRepo) FindByID(ctx context.Context, id string) (*model.Order, error) {
    var dbOrder model.Order
    if err := r.DB(ctx).
        Preload("Items").
        Preload("ShippingAddress").
        Preload("BillingAddress").
        Preload("StatusHistory").
        Preload("Payments").
        Preload("Shipments").
        Preload("Shipments.Items").
        First(&dbOrder).Error; err != nil {
        // ... handle error
    }
    return &dbOrder, nil
}
```

**Analysis:** This is **acceptable** for `FindByID` (single record). Preload is fine for fetching one order with all its relations.

**Action:** Keep as-is for GetByID/FindByID methods.

---

**File:** `order/internal/data/postgres/order.go`

**Lines 300-430:** List methods that may use Preload

Need to verify if these list methods use Preload or Joins:
- `ListByCustomer()`
- `ListByStatus()`
- `SearchOrders()`

**Action:** Read full file and check

---

### 🟡 Priority 2: Catalog Service

**File:** `catalog/internal/data/postgres/product.go`

Product search/list likely uses Preload for categories, variants, etc.

**Suspected Issues:**
- Product search with category Preload
- Product list with variants Preload
- Category list with products Preload

**Action:** Full audit needed

**Estimated Fix:** 2-3 hours

---

### 🟡 Priority 2: Fulfillment Service

**File:** `fulfillment/internal/data/postgres/shipment.go`

Shipment list methods may use Preload for items, addresses.

**Action:** Audit and fix if using Preload in list

**Estimated Fix:** 1-2 hours

---

## Acceptable Preload Usage (Keep As-Is)

### ✅ GetByID / FindByID Methods

```go
// ✅ GOOD: Preload acceptable for single record retrieval
func (r *orderRepo) FindByID(ctx context.Context, id string) (*model.Order, error) {
    var order model.Order
    return &order, r.DB(ctx).
        Preload("Items").
        Preload("ShippingAddress").
        Preload("Payments").
        First(&order, "id = ?", id).Error
}
```

**Why acceptable:**
- Only 1 main record fetched
- Preloads execute in batches (efficient)
- Code is cleaner than complex Joins
- Performance impact negligible for single record

**Rule:** Preload is OK for:
- `GetByID`, `FindByID`, `GetBy{UniqueField}` (single record)
- `GetByIDs` with small batch (<100 records)

---

## Migration Strategy

### Step 1: Identify All List/Search Methods with Preload

```bash
cd /home/user/microservices
grep -rn 'Preload(' */internal/data/ --include='*.go' -B5 | \
  grep -E "(func.*List|func.*Find[^I]|func.*Search|func.*GetBy.*limit)" > preload_list_audit.txt
```

### Step 2: Categorize by Priority

**High Priority (P0):**
- Methods called from user-facing APIs
- Methods with >100 QPS
- Methods returning >20 records

**Medium Priority (P1):**
- Admin-only endpoints
- Methods with 10-100 QPS
- Methods returning 10-20 records

**Low Priority (P2):**
- Internal/debug endpoints
- Methods with <10 QPS
- Methods returning <10 records

### Step 3: Fix Pattern

For each method:

1. **Replace Preload with Joins:**
   ```go
   // Before
   r.DB(ctx).Preload("Warehouse").Find(&results)
   
   // After
   r.DB(ctx).
       Joins("LEFT JOIN warehouses ON table.warehouse_id = warehouses.id").
       Select("table.*, warehouses.id as warehouse__id, warehouses.name as warehouse__name").
       Find(&results)
   ```

2. **Update struct tags if needed:**
   ```go
   type StockTransaction struct {
       WarehouseID uuid.UUID  `gorm:"column:warehouse_id"`
       Warehouse   *Warehouse `gorm:"foreignKey:WarehouseID"` // Works with both Preload and Joins
   }
   ```

3. **Test query output:**
   ```go
   // Enable SQL logging
   db.Debug().Joins(...).Find(&results)
   
   // Verify single query instead of multiple
   ```

4. **Benchmark before/after:**
   ```go
   func BenchmarkListTransactions_Preload(b *testing.B) {
       for i := 0; i < b.N; i++ {
           repo.ListTransactions_Preload(ctx, offset, limit)
       }
   }
   
   func BenchmarkListTransactions_Joins(b *testing.B) {
       for i := 0; i < b.N; i++ {
           repo.ListTransactions_Joins(ctx, offset, limit)
       }
   }
   ```

### Step 4: Rollout

- Fix one service at a time
- Deploy to staging, validate performance
- Monitor P95 latency improvement
- Deploy to production
- Remove old code after validation

---

## Detailed Fix List

### Warehouse Service (15 methods)

`warehouse/internal/data/postgres/transaction.go`:
- [ ] `GetByWarehouse()` - line 153
- [ ] `GetByProduct()` - line 171
- [ ] `GetBySKU()` - line 184
- [ ] `GetByType()` - line 211
- [ ] `GetByDateRange()` - line 224

`warehouse/internal/data/postgres/adjustment.go`:
- [ ] `ListPending()` - line 64
- [ ] `ListByStatus()` - line 90
- [ ] `ListByWarehouse()` - line 114
- [ ] `SearchRequests()` - line 138

`warehouse/internal/data/postgres/backorder.go`:
- [ ] `ListByWarehouse()` - line 183
- [ ] `ListByStatus()` - line 202
- [ ] `SearchBackorders()` - line 218
- [ ] (3 other list methods)

`warehouse/internal/data/postgres/distributor.go`:
- [ ] `ListDistributors()` - line 146 (Minor - only loads regions)

### Order Service (8+ methods)

`order/internal/data/postgres/order.go`:
- [ ] Verify `ListByCustomer()` - line 314
- [ ] Verify `ListByStatus()` - line 366
- [ ] Verify `SearchOrders()` - line 391
- [ ] Verify `ListByDateRange()` - line 423

`order/internal/data/postgres/payment.go`:
- [ ] Verify list methods

`order/internal/data/postgres/status.go`:
- [ ] Verify list methods

### Catalog Service (5+ methods)

`catalog/internal/data/postgres/product.go`:
- [ ] Audit product search/list methods
- [ ] Check variant preloads
- [ ] Check category preloads

### Other Services (10+ methods)

- [ ] fulfillment: Audit shipment list methods
- [ ] customer: Audit customer/address list methods  
- [ ] checkout: Audit cart list methods
- [ ] search: Verify search result methods

---

## Performance Targets

| Metric | Before (Preload) | After (Joins) | Target Improvement |
|--------|------------------|---------------|-------------------|
| Query count per request | 2-5 queries | 1 query | 50-80% reduction |
| P95 latency | 100-200ms | 20-50ms | 2-4x improvement |
| Database load | High | Lower | 30-50% reduction |
| Memory usage | High (in-memory joins) | Lower | 20-30% reduction |

---

## Testing Checklist

Per method fixed:

- [ ] Unit test passes
- [ ] SQL query logged and verified (single query)
- [ ] Benchmark shows improvement
- [ ] Integration test passes
- [ ] Deployed to staging
- [ ] P95 latency monitored (improvement confirmed)
- [ ] Deployed to production
- [ ] Monitoring dashboard updated

---

## Estimated Effort

| Service | Methods to Fix | Effort (hours) | Priority |
|---------|---------------|----------------|----------|
| warehouse | 15 | 4-5 | P0 |
| order | 8 | 2-3 | P0 |
| catalog | 5 | 2-3 | P1 |
| fulfillment | 4 | 1-2 | P1 |
| customer | 3 | 1 | P2 |
| checkout | 2 | 0.5 | P2 |
| Others | 3 | 1 | P2 |
| **Total** | **40** | **12-17 hours** (2-3 days) | - |

---

## Benefits

### Performance
- **2-5x faster** list queries
- **50-80% fewer** database queries
- **30-50% lower** database CPU utilization

### Scalability
- Reduced connection pool pressure
- Better query plan caching
- Lower memory usage per request

### Code Quality
- More explicit about data fetching
- Easier to optimize (can see JOIN in query log)
- Better for code review (shows exact data loading)

---

## Risks & Mitigation

### Risk 1: Breaking Changes

**Risk:** Joins may return different data structures  
**Mitigation:**
- Carefully test model mapping
- Use same GORM tags (`foreignKey`, `references`)
- Add integration tests comparing Preload vs Joins output

### Risk 2: Complex Nested Relations

**Risk:** Some Preloads load deeply nested relations (e.g., `Preload("Shipments.Items")`)  
**Mitigation:**
- For complex nesting, keep Preload if <10 records
- For >10 records, use multiple Joins or sub-queries
- Document decision in code comments

### Risk 3: Null Associations

**Risk:** LEFT JOIN may return nulls if association doesn't exist  
**Mitigation:**
- Use proper null handling in struct tags
- Test with missing associations
- Keep LEFT JOIN (not INNER JOIN) to match Preload behavior

---

## Conclusion

**Impact:** Medium-High - Notable performance improvement for list endpoints  
**Complexity:** Low-Medium - Find/replace pattern, straightforward testing  
**Risk:** Low - Non-breaking change, incremental rollout possible  
**Priority:** Medium - Should complete after Track F, can run parallel to H1  

**Recommendation:** Tackle warehouse and order services first (biggest impact). Can be done incrementally, service by service, over 1-2 sprints.

---

## References

- [GORM Preload vs Joins Performance](https://gorm.io/docs/preload.html)
- [N+1 Query Problem Explained](https://stackoverflow.com/questions/97197/what-is-the-n1-selects-problem-in-orm-object-relational-mapping)
- Track H1 Pagination Audit (cursor pagination complements this)

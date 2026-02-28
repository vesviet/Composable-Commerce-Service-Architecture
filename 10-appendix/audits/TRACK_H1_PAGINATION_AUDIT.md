# Track H1: Pagination Performance Audit

**Date:** 2026-02-28  
**Status:** ✅ Audit Complete  
**Scope:** All microservices using offset-based pagination on large tables

---

## Executive Summary

**Finding:** 170+ instances of offset pagination found across services. Large transactional tables (orders, transactions, events) are using offset pagination which degrades performance as data grows.

**Recommendation:** Migrate high-traffic list endpoints to cursor-based pagination for tables with >10K rows.

---

## Background

### Offset Pagination Performance Problem

```sql
-- Page 1: FAST (~1ms)
SELECT * FROM orders LIMIT 20 OFFSET 0;

-- Page 1000: SLOW (~500ms)
SELECT * FROM orders LIMIT 20 OFFSET 20000;
-- Database must scan and discard 20K rows even though we only want 20
```

### Cursor Pagination Solution

```sql
-- Page 1: FAST (~1ms)
SELECT * FROM orders WHERE id > '' ORDER BY id ASC LIMIT 20;

-- "Page 1000": STILL FAST (~1ms)
SELECT * FROM orders WHERE id > 'last_id_from_prev_page' ORDER BY id ASC LIMIT 20;
-- Database uses index to jump directly to the cursor position
```

---

## Audit Results

### Services with Most Pagination Usage

| Service | Offset Pagination Count | Primary Tables |
|---------|------------------------|----------------|
| warehouse | 30+ | transactions, adjustments, inventory, backorders, reservations |
| order | 23+ | orders, payments, items, status_history, failed_events |
| catalog | 15+ | products, categories, variants |
| fulfillment | 12+ | shipments, picklists |
| customer | 10+ | customers, addresses |

### Critical Tables Needingursor Pagination

#### Priority 1: High-Volume Transactional Tables

**1. warehouse.stock_transactions**
- Current: Offset pagination in `GetByWarehouse()`, `GetByProduct()`, `GetBySKU()`, `GetByType()`, `GetByDateRange()`
- Volume: 100K+ rows/month
- Issue: List queries with Preload("Warehouse") on large offset
- **File:** `warehouse/internal/data/postgres/transaction.go` lines 153-230
- **Recommendation:** Migrate to cursor on `created_at` + `id` composite index

**2. order.orders**
- Current: Offset pagination in `ListByCustomer()`, `ListByStatus()`, `SearchOrders()`
- Volume: 50K+ rows/month
- Issue: Slow list queries for customers with many orders
- **File:** `order/internal/data/postgres/order.go` lines 300-430
- **Recommendation:** Migrate to cursor on `created_at` + `id`

**3. order.outbox_events**
- Current: Offset pagination in failed events DLQ
- Volume: 1000+ rows/day (failures only)
- Issue: DLQ pagination slow when backlog builds up
- **File:** `order/internal/data/postgres/outbox.go`
- **Recommendation:** Use cursor on `created_at` for DLQ

**4. warehouse.adjustment_requests**
- Current: Offset pagination in `ListPending()`, `ListByStatus()`
- Volume: 10K+ rows/month
- Issue: List queries with Preload("Warehouse")
- **File:** `warehouse/internal/data/postgres/adjustment.go` lines 60-150
- **Recommendation:** Migrate to cursor on `requested_at` + `id`

#### Priority 2: Medium-Volume Tables (Monitor)

**5. order.status_history**
- Volume: 200K+ rows/month (4-5 per order)
- Note: Usually queried by specific order_id, not paginated lists
- **Action:** Monitor performance, defer migration

**6. catalog.products**
- Volume: 10K-50K rows
- Issue: Product search uses offset
- **File:** `catalog/internal/data/postgres/product.go`
- **Recommendation:** Consider cursor for product search API if >50K products

**7. fulfillment.shipments**
- Volume: 40K+ rows/month
- Issue: List shipments by various filters uses offset
- **Action:** Monitor performance, migrate if P95 latency >200ms

#### Priority 3: Low-Volume Tables (OK to keep offset)

- customer.addresses (low volume, usually filtered by customer_id)
- order.items (usually queried by order_id, not paginated)
- warehouse.backorders (moderate volume, infrequent queries)
- warehouse.inventory (filtered by warehouse_id or product_id)

---

## Implementation Plan

### Phase 1: Update Repository Interfaces (Week 1)

Add cursor-based methods alongside existing offset methods:

```go
// order/internal/repository/order/order.go
type OrderRepo interface {
    // Existing offset methods (keep for backward compatibility)
    ListByCustomer(ctx context.Context, customerID string, offset, limit int32) ([]*model.Order, int64, error)
    
    // NEW: Cursor-based methods
    ListByCustomerCursor(ctx context.Context, customerID string, req *pagination.CursorRequest) ([]*model.Order, *pagination.CursorResponse, error)
    ListByStatusCursor(ctx context.Context, status string, req *pagination.CursorRequest) ([]*model.Order, *pagination.CursorResponse, error)
}
```

### Phase 2: Implement Cursor Repos (Week 1-2)

Example implementation:

```go
// warehouse/internal/data/postgres/transaction.go
func (r *transactionRepo) GetByWarehouseCursor(ctx context.Context, warehouseID string, req *pagination.CursorRequest) ([]*model.StockTransaction, *pagination.CursorResponse, error) {
    cp := pagination.NewCursorPaginator(req)
    
    query := r.DB(ctx).
        Joins("LEFT JOIN warehouses ON stock_transactions.warehouse_id = warehouses.id").  // Use Joins, not Preload!
        Select("stock_transactions.*, warehouses.name as warehouse_name").
        Where("warehouse_id = ?", warehouseID)
    
    if cp.HasCursor() {
        query = query.Where("stock_transactions.created_at < ?", cp.GetCursor())  // Assuming cursor is timestamp
    }
    
    query = query.Order("stock_transactions.created_at DESC, stock_transactions.id DESC").
        Limit(cp.GetLimit())
    
    var results []*model.StockTransaction
    if err := query.Find(&results).Error; err != nil {
        return nil, nil, err
    }
    
    var lastCursor string
    if len(results) > 0 {
        lastCursor = results[len(results)-1].CreatedAt.Format(time.RFC3339Nano)
    }
    
    response := cp.BuildResponse(len(results), lastCursor)
    
    // Trim to page size if we fetched extra for hasMore detection
    if len(results) > cp.GetPageSize() {
        results = results[:cp.GetPageSize()]
    }
    
    return results, response, nil
}
```

### Phase 3: Update Proto APIs (Week 2)

Add cursor pagination to gRPC/HTTP APIs:

```protobuf
// api/order/v1/order.proto
message ListOrdersRequest {
    string customer_id = 1;
    
    // Deprecated: Use cursor instead
    int32 page = 2 [deprecated = true];
    int32 page_size = 3 [deprecated = true];
    
    // NEW: Cursor-based pagination
    string cursor = 4;
    int32 limit = 5;  // Default 20, max 100
}

message ListOrdersResponse {
    repeated Order orders = 1;
    
    // Deprecated offset response
    int64 total = 2 [deprecated = true];
    
    // NEW: Cursor response
    string next_cursor = 3;
    bool has_more = 4;
}
```

### Phase 4: Update Service Layer (Week 2-3)

Update service implementations to use cursor methods:

```go
// order/internal/service/order_service.go
func (s *OrderService) ListOrders(ctx context.Context, req *pb.ListOrdersRequest) (*pb.ListOrdersResponse, error) {
    // Support both pagination types for backward compatibility
    if req.GetCursor() != "" || req.GetPage() == 0 {
        // Use cursor pagination (new way)
        cursorReq := &pagination.CursorRequest{
            Cursor:   req.GetCursor(),
            PageSize: int(req.GetLimit()),
        }
        
        orders, cursorResp, err := s.orderRepo.ListByCustomerCursor(ctx, req.GetCustomerId(), cursorReq)
        if err != nil {
            return nil, err
        }
        
        return &pb.ListOrdersResponse{
            Orders:     convertOrders(orders),
            NextCursor: cursorResp.NextCursor,
            HasMore:    cursorResp.HasMore,
        }, nil
    }
    
    // Fall back to offset pagination (deprecated, keep for backward compat)
    // ... existing code
}
```

### Phase 5: Frontend Migration (Week 3-4)

Update admin UI and frontend to use cursor pagination:

```typescript
// admin/src/api/orders.ts
export async function fetchOrders(customerId: string, cursor?: string) {
  const response = await apiClient.get('/api/v1/orders', {
    params: {
      customer_id: customerId,
      cursor: cursor,
      limit: 20,
    },
  });
  
  return {
    orders: response.data.orders,
    nextCursor: response.data.next_cursor,
    hasMore: response.data.has_more,
  };
}

// Infinite scroll implementation
const loadMoreOrders = async () => {
  const { orders, nextCursor, hasMore } = await fetchOrders(customerId, currentCursor);
  setOrders([...orders, ...newOrders]);
  setCurrentCursor(nextCursor);
  setCanLoadMore(hasMore);
};
```

---

## Migration Checklist

### Per-Table Migration

- [ ] **warehouse.stock_transactions**
  - [ ] Add `ListByWarehouseCursor()` repo method
  - [ ] Add `ListByProductCursor()` repo method
  - [ ] Update proto API
  - [ ] Update service layer
  - [ ] Update admin UI
  - [ ] Deprecate offset methods (add `[deprecated]` tag)
  - [ ] Monitor P95 latency improvement

- [ ] **order.orders**
  - [ ] Add `ListByCustomerCursor()` repo method
  - [ ] Add `ListByStatusCursor()` repo method
  - [ ] Add `SearchOrdersCursor()` repo method
  - [ ] Update proto API
  - [ ] Update service layer
  - [ ] Update admin UI and customer dashboard
  - [ ] Monitor P95 latency improvement

- [ ] **warehouse.adjustment_requests**
  - [ ] Add `ListPendingCursor()` repo method
  - [ ] Add `ListByStatusCursor()` repo method
  - [ ] Update proto API
  - [ ] Update service layer
  - [ ] Update admin UI
  - [ ] Monitor P95 latency improvement

- [ ] **order.outbox_events DLQ**
  - [ ] Add `GetFailedCursor()` repo method
  - [ ] Update DLQ retry worker
  - [ ] Update admin DLQ viewer
  - [ ] Monitor DLQ processing performance

---

## Performance Targets

| Metric | Before (Offset) | After (Cursor) | Target Improvement |
|--------|----------------|----------------|-------------------|
| P95 latency (page 1) | <50ms | <50ms | No regression |
| P95 latency (page 100) | 300-500ms | <50ms | 6-10x improvement |
| P95 latency (page 1000) | 2-5 seconds | <50ms | 40-100x improvement |
| Database CPU utilization | High on large offset | Minimal | 50-70% reduction |

---

## Backward Compatibility Strategy

### Option 1: Dual APIs (Recommended)

- Keep existing offset APIs with `[deprecated]` tag
- Add new cursor APIs alongside
- Gradual migration over 2-3 releases
- Remove offset APIs in major version bump (v2.0)

### Option 2: Automatic Detection

- Single API accepts both pagination styles
- If `cursor` is present, use cursor pagination
- If `page` is present, use offset pagination
- Prefer cursor when both are present

---

## Testing Plan

### Load Testing

```bash
# Before migration
k6 run --vus 100 --duration 5m load-test-offset.js

# After migration  
k6 run --vus 100 --duration 5m load-test-cursor.js

# Compare P95, P99 latencies
```

### Correctness Testing

- Verify cursor pagination returns same results as offset (order matters)
- Test edge cases: empty results, single page, last page
- Test cursor invalidation (deleted records)
- Test concurrent read/write scenarios

---

## Estimated Effort

| Task | Effort | Dependencies |
|------|--------|--------------|
| Update common/utils/pagination (DONE) | ✅ 0 days | Track A complete |
| warehouse.stock_transactions | 2 days | - |
| order.orders | 3 days | - |
| warehouse.adjustment_requests | 1 day | - |
| order.outbox DLQ | 1 day | - |
| catalog.products (optional) | 2 days | - |
| Admin UI updates | 3 days | All backend changes |
| Frontend updates | 2 days | All backend changes |
| Testing & validation | 2 days | All migrations |
| **Total** | **16 days** (3 weeks) | - |

---

## Conclusion

**Impact:** High - Significant performance improvement for high-volume endpoints  
**Complexity:** Medium - Well-defined pattern, incremental migration  
**Risk:** Low - Backward compatible, can run both approaches in parallel  
**Priority:** Medium - Not blocking, but valuable for scalability  

**Recommendation:** Implement in dedicated sprint after Track F completes. Start with warehouse.stock_transactions as proof-of-concept.

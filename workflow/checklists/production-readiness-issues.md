# 🔍 CODE REVIEW ISSUES CHECKLIST

**Review Date**: January 18, 2026  
**Reviewer**: Senior Team Lead  
**Services Reviewed**: Catalog, Order, Warehouse  
**Total Issues Found**: 45 issues (8 P0, 16 P1, 21 P2)  
**Estimated Effort**: 12-15 weeks

---

## 📊 EXECUTIVE SUMMARY

### Overall Service Quality

| Service | Score | Status | Critical Issues | Notes |
|---------|-------|--------|-----------------|-------|
| **Catalog** | 7.0/10 | ⚠️ NOT READY | 2 P0 | No authentication! |
| **Order** | 7.5/10 | ⚠️ NEEDS WORK | 2 P0 | Race conditions in cart |
| **Warehouse** | 7.5/10 | ⚠️ NEEDS WORK | 4 P0 | Reservation race conditions |
| **Overall** | **7.3/10** | **⚠️ NOT PRODUCTION READY** | **8 P0** | Fix P0 issues first |

### Priority Distribution

```
P0 (Blocking):        █████████░ 8 issues  (18%)  ← MUST FIX BEFORE PROD
P1 (High):            ████████████████░ 16 issues  (36%)
P2 (Normal):          ████████████████████████ 21 issues  (46%)
```

---

## 🔴 CRITICAL ISSUES (P0 - BLOCKING) - 8 ISSUES

### **P0-1: [CATALOG] Missing Authentication/Authorization** ⚠️ CRITICAL
**Service**: Catalog Service  
**Severity**: 🔴 **P0 (SECURITY RISK)**  
**Impact**: HIGH - Any unauthenticated user can create/update/delete products  
**Effort**: 2 days  
**Assignee**: Backend Team

**Files Affected**:
- `catalog/internal/service/product_write.go:12-299`
- `catalog/internal/server/http.go:150-233`

**Issue Description**:
Write endpoints (CreateProduct, UpdateProduct, DeleteProduct) have ZERO authentication checks. ANY user can manipulate product catalog!

**Current Code**:
```go
// NO auth middleware or user validation
func (s *ProductService) CreateProduct(ctx context.Context, req *pb.CreateProductRequest) (*pb.CreateProductReply, error) {
    // ❌ NO RequireAdmin() check
    // ❌ NO user_id extraction
    return s.usecase.CreateProduct(ctx, &product.CreateProductRequest{...})
}
```

**Recommended Fix**:
```go
// Add to catalog/internal/middleware/admin.go
func RequireAdmin() middleware.Middleware {
    return func(handler middleware.Handler) middleware.Handler {
        return func(ctx context.Context, req interface{}) (interface{}, error) {
            role := ctx.Value("user_role")
            if role != "admin" {
                return nil, errors.Unauthorized("PERMISSION_DENIED", "admin role required")
            }
            return handler(ctx, req)
        }
    }
}

// Apply in server registration
productService := service.NewProductService(productUsecase, logger)
adminProtected := middleware.Chain(
    middleware.RequireAuth(),
    middleware.RequireAdmin(),
)(productService)

productAPI.RegisterProductServiceHTTPServer(srv, adminProtected)
```

**Test Case**:
```go
func TestCreateProduct_Unauthorized(t *testing.T) {
    // Call CreateProduct without auth header
    // Expect: 401 Unauthorized
}

func TestCreateProduct_NonAdmin(t *testing.T) {
    // Call CreateProduct with customer role
    // Expect: 403 Forbidden
}
```

**Business Impact**:
- **Security**: HIGH - Unauthorized product manipulation
- **Data Integrity**: HIGH - Malicious catalog changes
- **Compliance**: CRITICAL - PCI/SOC2 violation

**Definition of Done**:
- [ ] Add RequireAdmin middleware
- [ ] Apply to all write endpoints
- [ ] Add unit tests for auth checks
- [ ] Add integration test for unauthorized access
- [ ] Document in API specification
- [ ] Security team sign-off

---

### **P0-2: [CATALOG] Admin Endpoints Not Protected**
**Service**: Catalog Service  
**Severity**: 🔴 **P0 (SECURITY RISK)**  
**Impact**: HIGH - Mutation operations exposed without admin protection  
**Effort**: 1 day  
**Assignee**: Backend Team

**Files Affected**:
- `catalog/internal/server/http.go:150-233`
- `catalog/internal/middleware/` (missing admin middleware)

**Issue Description**:
No evidence of AdminGuard middleware applied to mutation endpoints. Grep search for `RequireAdmin` returned NO matches.

**Recommended Fix**:
See P0-1 fix above (same solution)

**Dependencies**: Blocked by P0-1

---

### **P0-3: [ORDER] Cart Updates Lack Optimistic Locking**
**Service**: Order Service  
**Severity**: 🔴 **P0 (DATA LOSS RISK)**  
**Impact**: HIGH - Concurrent updates cause incorrect cart totals  
**Effort**: 3 days  
**Assignee**: Backend Team

**Files Affected**:
- `order/internal/biz/cart/update.go:1-110`
- `order/internal/model/cart_item.go`
- `order/migrations/` (new migration needed)

**Issue Description**:
UpdateCartItem updates quantity without version check, allowing TOCTOU race condition.

**Race Condition Scenario**:
```
Time | User A                        | User B
-----|-------------------------------|------------------------------
T1   | Read: cart item qty=1         |
T2   |                               | Read: cart item qty=1
T3   | Update to qty=3 → Success     |
T4   |                               | Update to qty=2 → Overwrites!
```

**Recommended Fix**:

**Step 1**: Add migration
```sql
-- migrations/008_add_cart_item_version.sql
ALTER TABLE cart_items ADD COLUMN version INTEGER DEFAULT 1 NOT NULL;
CREATE INDEX idx_cart_items_version ON cart_items(id, version);
```

**Step 2**: Update model
```go
// internal/model/cart_item.go
type CartItem struct {
    ID       int64  `gorm:"primarykey"`
    Version  int32  `gorm:"default:1;not null"`  // ADD THIS
    Quantity int32
    // ... other fields
}
```

**Step 3**: Update repository
```go
// internal/data/postgres/cart.go
func (r *cartRepo) UpdateItemWithVersion(ctx context.Context, itemID int64, expectedVersion int32, updates map[string]interface{}) error {
    updates["version"] = gorm.Expr("version + 1")
    
    result := r.db.WithContext(ctx).
        Model(&model.CartItem{}).
        Where("id = ? AND version = ?", itemID, expectedVersion).
        Updates(updates)
    
    if result.RowsAffected == 0 {
        return ErrOptimisticLockFailed
    }
    
    return result.Error
}
```

**Step 4**: Update API
```go
// api/proto/cart.proto
message UpdateCartItemRequest {
    int64 item_id = 1;
    int32 quantity = 2;
    int32 expected_version = 3;  // ADD THIS
}
```

**Test Case**:
```go
func TestUpdateCartItem_ConcurrentUpdates(t *testing.T) {
    // Start 2 goroutines updating same item
    var wg sync.WaitGroup
    errors := make(chan error, 2)
    
    for i := 0; i < 2; i++ {
        wg.Add(1)
        go func(qty int32) {
            defer wg.Done()
            _, err := usecase.UpdateCartItem(ctx, &UpdateCartItemRequest{
                ItemID:          itemID,
                Quantity:        qty,
                ExpectedVersion: 1,
            })
            errors <- err
        }(int32(i + 2))
    }
    
    wg.Wait()
    close(errors)
    
    // One should succeed, one should fail with OptimisticLockFailed
    successCount := 0
    failCount := 0
    for err := range errors {
        if err == nil {
            successCount++
        } else if errors.Is(err, ErrOptimisticLockFailed) {
            failCount++
        }
    }
    
    assert.Equal(t, 1, successCount, "exactly one update should succeed")
    assert.Equal(t, 1, failCount, "exactly one update should fail with lock error")
}
```

**Business Impact**:
- **Data Accuracy**: HIGH - Incorrect cart totals → wrong order amounts
- **Customer Trust**: MEDIUM - Lost items in cart
- **Revenue**: LOW - Potential lost sales

**Definition of Done**:
- [ ] Create migration with version column
- [ ] Update CartItem model
- [ ] Implement version check in repository
- [ ] Update API proto with expected_version
- [ ] Add concurrent update test
- [ ] Test with 10+ concurrent users
- [ ] Document in API specification
- [ ] QA sign-off

---

### **P0-4: [ORDER] Payment Authorization Lacks Idempotency Key**
**Service**: Order Service  
**Severity**: 🔴 **P0 (FINANCIAL RISK)**  
**Impact**: HIGH - Duplicate payment charges on retry  
**Effort**: 1 day  
**Assignee**: Backend Team

**Files Affected**:
- `order/internal/biz/checkout/payment.go:26-60`
- `order/api/proto/payment.proto`

**Issue Description**:
Payment authorization called without idempotency key. If request retries (network timeout, client retry), customer gets charged multiple times!

**Current Code**:
```go
authReq := &PaymentAuthorizationRequest{
    OrderID:       "",  // No order yet
    Amount:        totalAmount,
    PaymentMethod: cart.PaymentMethod,
    // MISSING: IdempotencyKey
}
authResp, err := uc.paymentService.AuthorizePayment(ctx, authReq)
```

**Recommended Fix**:
```go
import "github.com/google/uuid"

func (uc *UseCase) authorizePayment(ctx context.Context, cart *biz.Cart, session *CheckoutSession) (*PaymentResult, error) {
    // Generate idempotency key from session ID (stable across retries)
    idempotencyKey := fmt.Sprintf("checkout:%s:auth", session.SessionID)
    
    authReq := &PaymentAuthorizationRequest{
        IdempotencyKey: idempotencyKey,  // ADD THIS
        OrderID:        "",
        Amount:         totalAmount,
        PaymentMethod:  cart.PaymentMethod,
        Metadata: map[string]interface{}{
            "session_id":      session.SessionID,
            "idempotency_key": idempotencyKey,
        },
    }
    
    // Payment service will deduplicate by idempotency key
    authResp, err := uc.paymentService.AuthorizePayment(ctx, authReq)
    if err != nil {
        return nil, fmt.Errorf("payment authorization failed: %w", err)
    }
    
    return &PaymentResult{
        AuthorizationID: authResp.AuthorizationID,
        Status:          authResp.Status,
    }, nil
}
```

**Test Case**:
```go
func TestAuthorizePayment_Idempotent(t *testing.T) {
    sessionID := uuid.New().String()
    
    // First call
    result1, err1 := usecase.AuthorizePayment(ctx, cart, &CheckoutSession{
        SessionID: sessionID,
    })
    assert.NoError(t, err1)
    
    // Retry same session (simulate network retry)
    result2, err2 := usecase.AuthorizePayment(ctx, cart, &CheckoutSession{
        SessionID: sessionID,
    })
    assert.NoError(t, err2)
    
    // Should return same authorization ID (not duplicate charge)
    assert.Equal(t, result1.AuthorizationID, result2.AuthorizationID)
    
    // Verify payment service only charged once
    paymentMock.AssertNumberOfCalls(t, "AuthorizePayment", 1)
}
```

**Business Impact**:
- **Financial**: CRITICAL - Double charging customers
- **Legal**: HIGH - Consumer protection violations
- **Reputation**: HIGH - Customer complaints, chargebacks

**Definition of Done**:
- [ ] Add IdempotencyKey to PaymentAuthorizationRequest
- [ ] Generate key from stable session ID
- [ ] Verify payment service supports idempotency
- [ ] Add integration test with retry
- [ ] Test with real payment gateway (Stripe sandbox)
- [ ] Document in payment API specification
- [ ] Finance team sign-off

---

### **P0-5: [WAREHOUSE] Race Condition in ReserveStock**
**Service**: Warehouse Service  
**Severity**: 🔴 **P0 (OVERBOOKING RISK)**  
**Impact**: CRITICAL - Potential stock overbooking, customer order cancellations  
**Effort**: 3 days  
**Assignee**: Backend Team

**Files Affected**:
- `warehouse/internal/biz/reservation/reservation.go:58-150`
- `warehouse/internal/biz/inventory/inventory.go`
- `warehouse/internal/repository/inventory/inventory.go`

**Issue Description**:
TOCTOU race condition between availability check and reservation creation. Two concurrent requests can both pass check and over-reserve stock.

**Race Condition Scenario**:
```
Time | Request A (Qty 10)                 | Request B (Qty 5)
-----|-----------------------------------|----------------------------------
T1   | Lock row, read available=10       |
T2   | Check: 10 >= 10 → PASS            | BLOCKED waiting for lock
T3   | Create reservation (qty=10)       |
T4   | Trigger increments reserved: 0→10 |
T5   | Commit, release lock              |
T6   |                                   | Lock acquired, read available=10, reserved=10
T7   |                                   | Check: (10-10=0) < 5 → FAIL ✅ (correct)

BUT if trigger runs AFTER commit:
T4   | Create reservation (qty=10)       |
T5   | Commit, release lock              |
T6   |                                   | Lock acquired, read available=10, reserved=0 (stale!)
T7   |                                   | Check: (10-0=10) >= 5 → PASS ❌ (overbooking!)
```

**Current Code**:
```go
// Get with lock (good)
inventory, err := uc.inventoryRepo.FindByWarehouseAndProductForUpdate(ctx, req.WarehouseID, req.ProductID)

// Check availability
availableQuantity := inventory.QuantityAvailable - inventory.QuantityReserved
if availableQuantity < req.Quantity {
    return nil, nil, fmt.Errorf("insufficient stock")
}

// Create reservation
created, err := uc.repo.Create(ctx, reservation)
// ❌ Trigger runs AFTER transaction commit, creating window for race condition
```

**Recommended Fix**:
```go
func (uc *ReservationUsecase) ReserveStock(ctx context.Context, req *ReserveStockRequest) (*model.StockReservation, *model.Inventory, error) {
    var created *model.StockReservation
    var updated *model.Inventory
    
    // P0-5 FIX: Wrap entire operation in transaction
    err := uc.tx.InTx(ctx, func(txCtx context.Context) error {
        // 1. Lock inventory row
        inventory, err := uc.inventoryRepo.FindByWarehouseAndProductForUpdate(txCtx, req.WarehouseID, req.ProductID)
        if err != nil || inventory == nil {
            return fmt.Errorf("inventory not found: %w", err)
        }
        
        // 2. Check availability (with lock held)
        availableQuantity := inventory.QuantityAvailable - inventory.QuantityReserved
        if availableQuantity < req.Quantity {
            return fmt.Errorf("insufficient stock: available=%d, requested=%d", availableQuantity, req.Quantity)
        }
        
        // 3. P0-5 FIX: Manually increment reserved BEFORE creating reservation
        // This prevents TOCTOU race condition
        err = uc.inventoryRepo.IncrementReserved(txCtx, inventory.ID.String(), req.Quantity)
        if err != nil {
            return fmt.Errorf("failed to increment reserved: %w", err)
        }
        
        // 4. Create reservation
        reservation := &model.StockReservation{
            WarehouseID:      uuid.MustParse(req.WarehouseID),
            ProductID:        uuid.MustParse(req.ProductID),
            QuantityReserved: req.Quantity,
            Status:           "active",
            ExpiresAt:        calculateExpiry(req.PaymentMethod),
        }
        
        created, err = uc.repo.Create(txCtx, reservation)
        if err != nil {
            return err
        }
        
        // 5. Get updated inventory
        updated, err = uc.inventoryRepo.FindByID(txCtx, inventory.ID.String())
        return err
    })
    
    return created, updated, err
}

// Add to inventory repository
func (r *inventoryRepo) IncrementReserved(ctx context.Context, inventoryID string, quantity int32) error {
    result := r.DB(ctx).Model(&model.Inventory{}).
        Where("id = ?", inventoryID).
        Update("quantity_reserved", gorm.Expr("quantity_reserved + ?", quantity))
    
    if result.Error != nil {
        return result.Error
    }
    
    if result.RowsAffected == 0 {
        return fmt.Errorf("inventory not found or already updated")
    }
    
    return nil
}
```

**Test Case**:
```go
func TestReserveStock_ConcurrentRequests_NoOverbooking(t *testing.T) {
    // Setup: Product with 10 available stock
    inventory := createTestInventory(t, productID, warehouseID, 10)
    
    // Execute: 3 concurrent requests trying to reserve 5 each (total 15, but only 10 available)
    var wg sync.WaitGroup
    results := make(chan error, 3)
    
    for i := 0; i < 3; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            _, _, err := usecase.ReserveStock(ctx, &ReserveStockRequest{
                WarehouseID: warehouseID,
                ProductID:   productID,
                Quantity:    5,
            })
            results <- err
        }()
    }
    
    wg.Wait()
    close(results)
    
    // Verify: Only 2 should succeed (10 / 5 = 2), 1 should fail
    successCount := 0
    failCount := 0
    for err := range results {
        if err == nil {
            successCount++
        } else if strings.Contains(err.Error(), "insufficient stock") {
            failCount++
        }
    }
    
    assert.Equal(t, 2, successCount, "exactly 2 reservations should succeed")
    assert.Equal(t, 1, failCount, "exactly 1 reservation should fail")
    
    // Verify final inventory state
    finalInventory, _ := inventoryRepo.FindByID(ctx, inventory.ID.String())
    assert.Equal(t, int32(10), finalInventory.QuantityReserved, "reserved should be 10 (2 x 5)")
    assert.Equal(t, int32(0), finalInventory.QuantityAvailable - finalInventory.QuantityReserved, "no stock left")
}
```

**Business Impact**:
- **Operations**: CRITICAL - Overselling leads to order cancellations
- **Customer Experience**: HIGH - Angry customers, lost trust
- **Revenue**: MEDIUM - Compensation costs, refunds

**Definition of Done**:
- [ ] Add transaction wrapper with InTx
- [ ] Implement IncrementReserved in repository
- [ ] Add concurrent reservation test
- [ ] Load test with 100+ concurrent requests
- [ ] Monitor production metrics for oversell incidents
- [ ] Document fix in architecture docs
- [ ] Operations team sign-off

---

### **P0-6: [WAREHOUSE] Missing Transaction Wrapper in ReleaseReservation**
**Service**: Warehouse Service  
**Severity**: 🔴 **P0 (DATA CONSISTENCY RISK)**  
**Impact**: HIGH - Inventory stuck in reserved state  
**Effort**: 2 days  
**Assignee**: Backend Team

**Files Affected**:
- `warehouse/internal/biz/reservation/reservation.go:180-220`

**Issue Description**:
ReleaseReservation updates reservation status but relies on database trigger to update inventory. If trigger fails, data becomes inconsistent.

**Current Code**:
```go
// Update reservation status
reservation.Status = "cancelled"
err = uc.repo.Update(ctx, reservation, nil)

// Get inventory to return
inventory, err := uc.inventoryRepo.FindByWarehouseAndProduct(ctx, ...)
// ❌ No transaction boundary
```

**Recommended Fix**: See P0-5 pattern, apply transaction wrapper

**Dependencies**: Blocked by P0-5

---

### **P0-7: [WAREHOUSE] Missing ReservationUsecase Dependency Injection**
**Service**: Warehouse Service  
**Severity**: 🔴 **P0 (BLOCKING FIX)**  
**Impact**: CRITICAL - Cannot implement transaction fixes  
**Effort**: 1 day  
**Assignee**: Backend Team

**Files Affected**:
- `warehouse/internal/biz/reservation/reservation.go:25-50`
- `warehouse/cmd/warehouse/wire.go`

**Issue Description**:
ReservationUsecase does NOT have access to transaction management, preventing atomic operations.

**Current Code**:
```go
type ReservationUsecase struct {
    repo           ReservationRepo
    inventoryRepo  InventoryRepo
    eventPublisher events.EventPublisher
    config         *config.AppConfig
    log            *log.Helper
    // ❌ NO tx commonTx.Transaction
}
```

**Recommended Fix**:
```go
type ReservationUsecase struct {
    repo           ReservationRepo
    inventoryRepo  InventoryRepo
    eventPublisher events.EventPublisher
    config         *config.AppConfig
    tx             commonTx.Transaction  // ADD THIS
    log            *log.Helper
}

func NewReservationUsecase(
    repo ReservationRepo,
    inventoryRepo InventoryRepo,
    eventPublisher events.EventPublisher,
    cfg *config.AppConfig,
    tx commonTx.Transaction,  // ADD THIS
    logger log.Logger,
) *ReservationUsecase {
    return &ReservationUsecase{
        repo:           repo,
        inventoryRepo:  inventoryRepo,
        eventPublisher: eventPublisher,
        config:         cfg,
        tx:             tx,  // ADD THIS
        log:            log.NewHelper(logger),
    }
}
```

**Update Wire Provider**:
```go
// warehouse/cmd/warehouse/wire.go
func NewReservationUsecase(
    repo *postgres.ReservationRepo,
    inventoryRepo *postgres.InventoryRepo,
    eventPublisher events.EventPublisher,
    cfg *config.AppConfig,
    tx commonTx.Transaction,  // ADD THIS
    logger log.Logger,
) *reservation.ReservationUsecase {
    return reservation.NewReservationUsecase(repo, inventoryRepo, eventPublisher, cfg, tx, logger)
}
```

**Definition of Done**:
- [ ] Add tx field to ReservationUsecase struct
- [ ] Update constructor signature
- [ ] Update Wire provider
- [ ] Regenerate Wire DI: `make wire`
- [ ] Verify compilation: `make build`
- [ ] Run tests: `make test`

---

### **P0-8: [WAREHOUSE] Missing FindByIDForUpdate in ReservationRepo**
**Service**: Warehouse Service  
**Severity**: 🔴 **P0 (BLOCKING FIX)**  
**Impact**: CRITICAL - Cannot acquire row locks  
**Effort**: 1 day  
**Assignee**: Backend Team

**Files Affected**:
- `warehouse/internal/repository/reservation/reservation.go`
- `warehouse/internal/data/postgres/reservation.go`

**Issue Description**:
No method to acquire row-level lock when reading reservations for update operations.

**Recommended Fix**:
```go
// Add to repository interface
type ReservationRepo interface {
    // ... existing methods
    FindByIDForUpdate(ctx context.Context, id string) (*model.StockReservation, error)
}

// Implement in postgres adapter
func (r *reservationRepo) FindByIDForUpdate(ctx context.Context, id string) (*model.StockReservation, error) {
    var m model.StockReservation
    reservationID, err := uuid.Parse(id)
    if err != nil {
        return nil, err
    }
    
    // P0-8 FIX: Use SELECT ... FOR UPDATE
    err = r.DB(ctx).Preload("Warehouse").
        Where("id = ?", reservationID).
        Clauses(clause.Locking{Strength: "UPDATE"}).
        Take(&m).Error
    if err == gorm.ErrRecordNotFound {
        return nil, nil
    }
    return &m, err
}
```

**Definition of Done**:
- [ ] Add interface method
- [ ] Implement in postgres adapter
- [ ] Update all callers to use ForUpdate
- [ ] Test with concurrent updates
- [ ] Verify lock acquisition in DB logs

---

## 🟡 HIGH PRIORITY ISSUES (P1) - 16 ISSUES

### **P1-1: [CATALOG] Potential N+1 Query in GetProductsByIDs**
**Service**: Catalog Service  
**Severity**: 🟡 **P1 (PERFORMANCE)**  
**Impact**: MEDIUM - 100 cache misses = 100 DB queries  
**Effort**: 2 days  
**Assignee**: Backend Team

**Files Affected**:
- `catalog/internal/biz/product/product_read.go:65-133`
- `catalog/internal/repository/product/product.go`

**Issue Description**:
Loop fetches products one-by-one instead of batch query.

**Current Code**:
```go
for _, id := range missingIDs {
    product, err := uc.repo.FindByID(ctx, id)  // ❌ N+1 QUERY
    // ... cache and append
}
```

**Recommended Fix**:
```go
// Add batch fetch to repository
type ProductRepo interface {
    // ... existing methods
    FindByIDs(ctx context.Context, ids []string) ([]*model.Product, error)
}

// Implement
func (r *productRepo) FindByIDs(ctx context.Context, ids []string) ([]*model.Product, error) {
    var products []*model.Product
    err := r.DB(ctx).
        Preload("Category").
        Preload("Brand").
        Where("id IN ?", ids).
        Find(&products).Error
    return products, err
}

// Use in usecase
if len(missingIDs) > 0 {
    products, err := uc.repo.FindByIDs(ctx, missingIDs)  // ✅ Single query
    for _, product := range products {
        // Cache and append
    }
}
```

**Performance Impact**:
- Before: 100 products × 10ms = 1000ms
- After: 1 query × 50ms = 50ms
- **Improvement**: 20x faster!

**Definition of Done**:
- [ ] Add FindByIDs to repository interface
- [ ] Implement batch fetch
- [ ] Add Preload for relations
- [ ] Update GetProductsByIDs to use batch
- [ ] Add performance test (benchmark)
- [ ] Monitor p95 latency in production

---

### **P1-2: [CATALOG] NO Preload/Joins for Category/Brand Relations**
**Service**: Catalog Service  
**Severity**: 🟡 **P1 (PERFORMANCE)**  
**Impact**: MEDIUM - Additional queries if relations accessed  
**Effort**: 1 day  
**Assignee**: Backend Team

**Current Code**:
```go
err = r.DB(ctx).Where("id = ?", productID).Take(&m).Error
// ❌ Missing: .Preload("Category").Preload("Brand")
```

**Recommended Fix**:
```go
err = r.DB(ctx).
    Preload("Category").
    Preload("Brand").
    Preload("Manufacturer").
    Where("id = ?", productID).Take(&m).Error
```

---

### **P1-3: [CATALOG] Cache Invalidation Commented Out**
**Service**: Catalog Service  
**Severity**: 🟡 **P1 (DATA CONSISTENCY)**  
**Impact**: MEDIUM - Stale cache if Outbox Worker fails  
**Effort**: 1 day

**Current Code**:
```go
// Line 146: Cache invalidation commented out
// uc.afterUpdateProduct(ctx, updated)
```

**Recommended Fix**: Re-enable with error handling
```go
// Best-effort cache invalidation (don't fail transaction)
if err := uc.afterUpdateProduct(ctx, updated); err != nil {
    uc.log.Warnf("Cache invalidation failed: %v", err)
    // Metrics: cache_invalidation_errors_total++
}
```

---

### **P1-4: [CATALOG] Event Publishing is Fire-and-Forget**
**Service**: Catalog Service  
**Severity**: 🟡 **P1 (RELIABILITY)**  
**Impact**: MEDIUM - Events may get stuck in PENDING  
**Effort**: 2 days

**Recommended Fix**: Add monitoring
```go
// Prometheus metrics
var (
    outboxPendingGauge = prometheus.NewGauge(prometheus.GaugeOpts{
        Name: "catalog_outbox_pending_count",
        Help: "Number of pending outbox events",
    })
)

// Health check
func (h *HealthHandler) CheckOutboxHealth(ctx context.Context) error {
    pending, err := h.outboxRepo.CountPending(ctx)
    if err != nil || pending > 1000 {
        return fmt.Errorf("outbox backlog: %d", pending)
    }
    return nil
}
```

---

### **P1-5: [ORDER] Potential N+1 Query in Cart Operations**
**Service**: Order Service  
**Severity**: 🟡 **P1 (PERFORMANCE)**  
**Impact**: MEDIUM - p95 latency ~500ms for large carts  
**Effort**: 2 days

**Issue**: Stock status checked individually
```go
for _, item := range bizCart.Items {
    err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, warehouseID, item.Quantity)
}
```

**Recommended Fix**: Add batch stock check
```go
type WarehouseInventoryService interface {
    CheckStockBatch(ctx context.Context, requests []StockCheckRequest) ([]StockCheckResult, error)
}
```

---

### **P1-6: [ORDER] Transaction Boundary Too Large in Order Creation**
**Service**: Order Service  
**Severity**: 🟡 **P1 (PERFORMANCE)**  
**Impact**: MEDIUM - Long-running transactions, deadlock risk  
**Effort**: 2 days

**Issue**: Transaction holds locks while marshaling JSON
```go
err = uc.tm.WithTransaction(ctx, func(ctx context.Context) error {
    // Database operations
    createdOrder, err = uc.createOrderInternal(ctx, order)
    
    // CPU-bound operation in transaction ❌
    eventPayload := &events.OrderStatusChangedEvent{...}
    payloadBytes, err := json.Marshal(eventPayload)
})
```

**Recommended Fix**: Move marshaling outside transaction

---

### **P1-7: [ORDER] Missing Context Timeout for External Service Calls**
**Service**: Order Service  
**Severity**: 🟡 **P1 (RELIABILITY)**  
**Impact**: MEDIUM - Indefinite hangs if service down  
**Effort**: 1 day

**Recommended Fix**:
```go
pricingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
defer cancel()

priceCalc, err := uc.pricingService.CalculatePrice(pricingCtx, ...)
if errors.Is(err, context.DeadlineExceeded) {
    return nil, fmt.Errorf("pricing service timeout: %w", err)
}
```

---

### **P1-8: [ORDER] PII Logging Without Masking in Checkout**
**Service**: Order Service  
**Severity**: 🟡 **P1 (SECURITY)**  
**Impact**: MEDIUM - PII leak in logs  
**Effort**: 1 day

**Recommended Fix**: Use existing PII masker
```go
import "gitlab.com/ta-microservices/order/internal/security"

maskedAddress := uc.piiMasker.MaskAddress(shippingAddr.FullAddress)
uc.log.Infof("Checkout: shipping=%s", maskedAddress)
```

---

### **P1-9: [ORDER] Insufficient Error Context in Payment Capture Failure**
**Service**: Order Service  
**Severity**: 🟡 **P1 (DEBUGGING)**  
**Impact**: MEDIUM - Lost payment provider error details  
**Effort**: 1 day

**Bug**: Returns wrong error variable
```go
captureResult, captureErr := uc.capturePayment(...)
if captureErr != nil {
    return nil, fmt.Errorf("payment capture failed: %w", err)  // ❌ Wrong variable!
}
```

**Fix**: Use correct variable + structured error

---

### **P1-10: [WAREHOUSE] ConfirmReservation - Direct Event Publishing Without Outbox**
**Service**: Warehouse Service  
**Severity**: 🟡 **P1 (RELIABILITY)**  
**Impact**: MEDIUM - Event loss if Dapr unavailable  
**Effort**: 1 day

**Issue**: Event published directly instead of via outbox
```go
if uc.eventPublisher != nil {
    event := events.StockUpdatedEvent{...}
    if err := uc.eventPublisher.PublishEvent(ctx, "warehouse.inventory.stock_changed", event); err != nil {
        uc.log.Warnf("Failed to publish stock changed event: %v", err)
        // ❌ Don't fail operation if event publishing fails
    }
}
```

**Recommended Fix**: Save to outbox within transaction

---

### **P1-11: [WAREHOUSE] Missing Outbox Pattern in UpdateInventory**
**Service**: Warehouse Service  
**Severity**: 🟡 **P1 (RELIABILITY)**  
**Impact**: MEDIUM - No verification consumers exist  
**Effort**: 2 days

**Recommended Fix**: Add consumer health monitoring

---

### **P1-12: [WAREHOUSE] No Distributed Lock for Bulk Operations**
**Service**: Warehouse Service  
**Severity**: 🟡 **P1 (CONCURRENCY)**  
**Impact**: MEDIUM - Duplicate records in bulk create  
**Effort**: 2 days

**Recommended Fix**: Add Redis distributed lock
```go
lock, err := uc.redisClient.AcquireLock(ctx, "warehouse:bulk_create:lock", 5*time.Minute)
defer lock.Release(ctx)
```

---

### **P1-13 to P1-16**: Additional high-priority issues (see full checklist in file)

---

## 🟢 NORMAL PRIORITY ISSUES (P2) - 21 ISSUES

### Testing & Quality (8 issues)
- **P2-1**: [CATALOG] Missing Integration Tests
- **P2-2**: [CATALOG] NO Outbox Worker Tests
- **P2-3**: [ORDER] Missing Integration Tests for Critical Flows
- **P2-4**: [ORDER] Incomplete Observability Instrumentation
- **P2-5**: [WAREHOUSE] No Metrics for Critical Operations
- **P2-6**: [WAREHOUSE] Inconsistent Error Handling
- **P2-7**: [CATALOG] Test Coverage Unknown
- **P2-8**: [CATALOG] Mock Coverage Incomplete

### Performance & Optimization (7 issues)
- **P2-9**: [CATALOG] Connection Pooling Not Visible
- **P2-10**: [CATALOG] Cache TTL Hardcoded
- **P2-11**: [CATALOG] IN Query with Large Lists
- **P2-12**: [ORDER] Hardcoded Business Constants
- **P2-13**: [WAREHOUSE] Missing Index on Reservation Queries
- **P2-14**: [CATALOG] Materialized View Refresh Manual
- **P2-15**: [CATALOG] Query Performance Monitoring

### Observability & Monitoring (6 issues)
- **P2-16**: [CATALOG] Metrics NOT Used in Business Logic
- **P2-17**: [CATALOG] NO Trace IDs in Logs
- **P2-18**: [CATALOG] Health Checks Basic
- **P2-19**: [ORDER] Metrics Service Nil Implementation
- **P2-20**: [ORDER] Alert Service Nil Implementation
- **P2-21**: [WAREHOUSE] No Prometheus Metrics

---

## 📅 IMPLEMENTATION ROADMAP

### Phase 1: Critical Security & Data Fixes (Week 1-2) - **BLOCKING**
**Effort**: 10-12 days  
**Priority**: P0 issues MUST be fixed before production

**Week 1**:
- [ ] P0-1, P0-2: [CATALOG] Add authentication/authorization (2 days)
- [ ] P0-3: [ORDER] Implement optimistic locking (3 days)
- [ ] P0-4: [ORDER] Add payment idempotency keys (1 day)
- [ ] P0-7, P0-8: [WAREHOUSE] Add transaction support (2 days)

**Week 2**:
- [ ] P0-5, P0-6: [WAREHOUSE] Fix reservation race conditions (3 days)
- [ ] Integration testing for P0 fixes (2 days)

**Deliverables**:
- ✅ All P0 issues resolved
- ✅ Integration tests passing
- ✅ Security audit complete
- ✅ Load testing successful (100+ concurrent users)

---

### Phase 2: High Priority Performance & Reliability (Week 3-6)
**Effort**: 16-20 days  
**Priority**: P1 issues improve performance and reliability

**Week 3-4**:
- [ ] P1-1, P1-2: [CATALOG] Fix N+1 queries, add Preload (2 days)
- [ ] P1-3, P1-4: [CATALOG] Cache invalidation, outbox monitoring (2 days)
- [ ] P1-5, P1-6: [ORDER] Batch stock checks, optimize transactions (3 days)
- [ ] P1-7, P1-8, P1-9: [ORDER] Context timeouts, PII masking, error handling (3 days)

**Week 5-6**:
- [ ] P1-10, P1-11, P1-12: [WAREHOUSE] Outbox pattern, distributed locks (4 days)
- [ ] Performance testing (2 days)
- [ ] Documentation updates (2 days)

**Deliverables**:
- ✅ All P1 issues resolved
- ✅ p95 latency < 200ms
- ✅ No N+1 queries
- ✅ Cache hit rate > 90%

---

### Phase 3: Testing & Observability (Week 7-10)
**Effort**: 12-15 days  
**Priority**: P2 issues improve quality and monitoring

**Week 7-8**:
- [ ] P2-1 to P2-8: Add integration tests (4 days)
- [ ] P2-16 to P2-21: Add Prometheus metrics (3 days)
- [ ] P2-17: Add trace IDs to logs (1 day)

**Week 9-10**:
- [ ] P2-9 to P2-15: Performance optimizations (4 days)
- [ ] Documentation (2 days)
- [ ] QA regression testing (2 days)

**Deliverables**:
- ✅ Test coverage > 80%
- ✅ Integration test suite
- ✅ Prometheus dashboards
- ✅ Trace logging

---

### Phase 4: Technical Debt & Polish (Week 11-12)
**Effort**: 8-10 days  
**Priority**: Nice-to-have improvements

- [ ] Refactor hardcoded constants
- [ ] Improve error messages
- [ ] Add health check enhancements
- [ ] Code cleanup
- [ ] Architecture documentation

---

## 📊 EFFORT ESTIMATION SUMMARY

| Phase | Duration | Engineer-Days | Calendar Weeks |
|-------|----------|---------------|----------------|
| **Phase 1 (P0)** | Week 1-2 | 10-12 days | 2 weeks |
| **Phase 2 (P1)** | Week 3-6 | 16-20 days | 4 weeks |
| **Phase 3 (P2)** | Week 7-10 | 12-15 days | 4 weeks |
| **Phase 4 (Debt)** | Week 11-12 | 8-10 days | 2 weeks |
| **Total** | **12 weeks** | **46-57 days** | **12 weeks** |

**Team Recommendation**: 2-3 backend engineers to complete in 12 weeks

---

## 🎯 SUCCESS METRICS

### Phase 1 (P0) - Production Readiness
- [ ] 0 authentication bypass vulnerabilities
- [ ] 0 race condition incidents in production
- [ ] 0 overbooking incidents
- [ ] 0 duplicate payment charges
- [ ] 100% pass rate on security audit

### Phase 2 (P1) - Performance & Reliability
- [ ] p95 API latency < 200ms
- [ ] p99 API latency < 500ms
- [ ] Cache hit rate > 90%
- [ ] Event delivery success rate > 99.9%
- [ ] Transaction deadlocks < 1 per day

### Phase 3 (P2) - Quality & Observability
- [ ] Test coverage > 80%
- [ ] Integration test coverage > 60%
- [ ] All critical flows have Prometheus metrics
- [ ] All logs include trace IDs
- [ ] Health checks detect 95% of issues

---

## 📝 REVIEW SIGN-OFF CHECKLIST

### Technical Review
- [ ] **Architecture Lead**: Reviewed architecture compliance
- [ ] **Security Lead**: Reviewed P0 security issues
- [ ] **Performance Lead**: Reviewed P1 performance issues
- [ ] **QA Lead**: Reviewed testing requirements

### Business Review
- [ ] **Product Manager**: Understands business impact
- [ ] **Business Analyst**: Validated requirements
- [ ] **Operations Lead**: Deployment plan approved
- [ ] **Finance Lead**: Aware of financial risks (P0-4)

### Implementation Plan
- [ ] **Engineering Manager**: Resource allocation approved
- [ ] **Sprint Planning**: Issues added to backlog
- [ ] **Priority Confirmed**: P0 → P1 → P2 order agreed
- [ ] **Timeline Approved**: 12-week plan accepted

---

## 📞 CONTACTS & ESCALATION

| Role | Contact | Responsibilities |
|------|---------|------------------|
| **Technical Lead** | [Name] | Architecture decisions, P0 resolution |
| **Security Lead** | [Name] | Security issues (P0-1, P0-2, P0-4) |
| **Backend Team Lead** | [Name] | Implementation coordination |
| **QA Manager** | [Name] | Testing strategy, sign-off |
| **Product Manager** | [Name] | Business priority, trade-offs |
| **DevOps Lead** | [Name] | Deployment, monitoring |

**Escalation Path**:
1. Technical Lead (0-24h)
2. Engineering Manager (24-48h)
3. CTO (48h+)

---

## 🔗 RELATED DOCUMENTATION

- [Inventory Flow Documentation](./inventory-flow.md)
- [Catalog Service Code Review](./catalog-service-review.md)
- [Order Service Code Review](./order-service-review.md)
- [Warehouse Service Code Review](./warehouse-service-review.md)
- [Team Lead Code Review Guide](../TEAM_LEAD_CODE_REVIEW_GUIDE.md)

---

**Document Status**: ✅ Ready for Review  
**Last Updated**: January 18, 2026  
**Next Review**: Weekly during Phase 1 implementation  

---

**END OF CHECKLIST**
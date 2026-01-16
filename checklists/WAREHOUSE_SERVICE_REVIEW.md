# WAREHOUSE SERVICE - DETAILED CODE REVIEW

**Service**: Warehouse Service  
**Reviewer**: Senior Lead  
**Review Date**: 2026-01-16  
**Review Standard**: [Team Lead Code Review Guide](./TEAM_LEAD_CODE_REVIEW_GUIDE.md)  
**Overall Score**: 85% ⭐⭐⭐⭐

---

## 📊 EXECUTIVE SUMMARY

Warehouse Service quản lý inventory, warehouse locations, coverage areas, và throughput capacity với kiến trúc Clean Architecture. Code đã có Transactional Outbox cho `stock_changed` trong các flow quan trọng (`UpdateInventory`, `AdjustStock`, **và `TransferStock`**). Tuy nhiên vẫn còn các điểm cần cải thiện theo Team Lead Guide: concurrency/async execution (vẫn có pattern `go func(){ g.Wait() }()` để chạy side-effects nền), HTTP handler proxy `/v1/products` tự encode lỗi theo kiểu riêng (không theo unified error handling).

### Điểm Mạnh
- ✅ Clean Architecture rõ ràng (biz/data/service layers)
- ✅ Transactional Outbox pattern đã implement
- ✅ Redis caching cho warehouse detection
- ✅ Comprehensive throughput capacity management với time slots
- ✅ Location-based warehouse detection với ancestor matching
- ✅ Bulk operations support (GetBulkStock)
- ✅ Event-driven architecture với observers

### Vấn Đề Cần Fix
- ⚠️ **0 P0 (BLOCKING)**: No blocking issues
- ⚠️ **2 P1 (HIGH)**: Async/concurrency pattern still spawns goroutines (errgroup wait in background) cho side-effects; missing tests
- ⚠️ **P2**: TransferStock event hiện ghi outbox (đã consistent), nhưng cần cân nhắc publish thêm event cho destination nếu downstream cần
- ⚠️ **2 P2 (NICE TO HAVE)**: Money representation, documentation

**Estimated Fix Time**: 12 giờ (2 sprints)

---

## 🔍 DETAILED REVIEW (10-POINT CHECKLIST)


### 1. ARCHITECTURE & CLEAN CODE ⭐⭐⭐⭐⭐ (95%)

#### ✅ ĐÚNG: Clean Architecture với Domain-Driven Design

```go
// warehouse/internal/biz/inventory/inventory.go
type InventoryUsecase struct {
    repo               InventoryRepo
    transactionRepo    TransactionRepo
    reservationRepo    ReservationRepo
    outboxRepo         OutboxRepo
    transactionUsecase *transaction.TransactionUsecase
    reservationUsecase *reservation.ReservationUsecase
    eventPublisher     events.EventPublisher
    catalogClient      CatalogClient
    alertUsecase       *alert.AlertUsecase
    tx                 commonTx.Transaction
    log                *log.Helper
}
```

**Tốt**: 
- Domain logic tách biệt khỏi infrastructure
- Interface-based dependencies
- Multi-domain organization (inventory, warehouse, throughput, timeslot)

#### ✅ ĐÚNG: Transaction Boundaries với Outbox Pattern (có worker publish + retry/DLQ)

**Verified (thực tế code)**:
- Outbox events được ghi transactional trong `UpdateInventory`/`AdjustStock` (`outboxRepo.Create(txCtx, ...)`).
- Worker publish: `warehouse/internal/worker/outbox_worker.go`
  - Poll `FetchPending(..., 20)` mỗi ~1s
  - Retry tối đa `MaxRetries = 5`
  - Mark `FAILED` khi vượt retry (DLQ)
  - Có metrics + OTel spans


```go
// warehouse/internal/biz/inventory/inventory.go:450
func (uc *InventoryUsecase) AdjustStock(ctx context.Context, req *AdjustStockRequest) (*model.Inventory, *model.StockTransaction, error) {
    err := uc.tx.InTx(ctx, func(txCtx context.Context) error {
        // 1. Update inventory
        err = uc.repo.UpdateAvailableQuantity(txCtx, inventory.ID.String(), quantityAfter)
        
        // 2. Create transaction record
        createdTransaction, err = uc.transactionRepo.Create(txCtx, transaction)
        
        // 3. Save event to outbox (transactional)
        if uc.outboxRepo != nil {
            outboxEvent := &repoOutbox.OutboxEvent{
                AggregateType: "inventory",
                AggregateID:   updated.ID.String(),
                Type:          "warehouse.inventory.stock_changed",
                Payload:       string(payload),
                Status:        "PENDING",
            }
            if err := uc.outboxRepo.Create(txCtx, outboxEvent); err != nil {
                return fmt.Errorf("failed to save event to outbox: %w", err)
            }
        }
        return nil
    })
}
```

**Tốt**: Transaction boundary bao gồm DB write + outbox event

---

### 2. API & CONTRACT ⭐⭐⭐⭐ (85%)

#### ✅ ĐÚNG: gRPC Service với Proto Contract

```go
// warehouse/internal/service/warehouse_service.go
type WarehouseService struct {
    pb.UnimplementedWarehouseServiceServer
    warehouseUsecase  *bizWarehouse.WarehouseUsecase
    timeSlotUsecase   *bizTimeSlot.TimeSlotUsecase
    throughputUsecase *bizThroughput.ThroughputUsecase
    log               *log.Helper
}
```

**Tốt**: 
- Proto-based contract với versioning (v1)
- Comprehensive API coverage (warehouse, inventory, capacity, time slots)

#### ✅ ĐÚNG: Pagination Support

```go
// warehouse/internal/service/warehouse_service.go:40
func (s *WarehouseService) ListWarehouses(ctx context.Context, req *pb.ListWarehousesRequest) (*pb.ListWarehousesResponse, error) {
    page := int32(1)
    limit := int32(20)
    if req.Pagination != nil {
        page = req.Pagination.Page
        limit = req.Pagination.Limit
    }
    
    pagingReq := commonPagination.NormalizePagination(page, limit)
    warehouses, total, err := s.warehouseUsecase.ListWarehouses(ctx, pagingReq.Page, pagingReq.Limit, status, warehouseType, countryCode)
    
    pagination := commonPagination.CalculatePagination(pagingReq.Page, pagingReq.Limit, total)
    return &pb.ListWarehousesResponse{
        Warehouses: pbWarehouses,
        Pagination: pagination,
    }, nil
}
```

**Tốt**: Consistent pagination pattern across all list endpoints

#### ⚠️ VẤN ĐỀ P2: HTTP middleware thiếu logging + proxy handler tự encode lỗi

**Hiện tại (thực tế code)**:
- `warehouse/internal/server/http.go` middleware chain có `recovery`, `metadata.Server()`, `metrics`, `tracing` nhưng **không có `logging.Server(logger)`**.
- Endpoint proxy `GET /v1/products` tự xử lý query parse + tự `json.NewEncoder` error 500 (không dùng error encoder thống nhất).

**Rủi ro**:
- Khó correlate request logs với trace/span.
- Error response format/status có thể lệch chuẩn giữa các endpoints.

**Concrete Actions**:
- **P2**: Add `logging.Server(logger)` vào HTTP middleware chain để đồng nhất với các services khác.
- **P2**: Chuẩn hóa error handling cho `/v1/products` (dùng common error encoder/response schema hoặc chuyển sang handler generated theo proto nếu có).


---

### 3. BUSINESS LOGIC & CONCURRENCY ⭐⭐⭐ (75%)

#### ✅ ĐÚNG: Location-Based Warehouse Detection với Caching

```go
// warehouse/internal/biz/warehouse/warehouse.go:400
func (uc *WarehouseUsecase) GetWarehouseByLocation(ctx context.Context, locationID string) (*model.Warehouse, string, string, int32, error) {
    // Check cache first
    if uc.cacheRepo != nil {
        cached, err := uc.cacheRepo.GetWarehouseByLocation(ctx, locationID)
        if err == nil && cached != nil {
            warehouse, err := uc.repo.FindByID(ctx, cached.WarehouseID)
            if err == nil && warehouse != nil {
                return warehouse, cached.MatchType, cached.MatchedLocationID, cached.Priority, nil
            }
        }
    }
    
    // Try exact match first
    warehouse, coverageArea, matchedLocationID, err := uc.repo.FindBestByLocation(ctx, locationID)
    if err == nil && warehouse != nil {
        // Cache result
        if uc.cacheRepo != nil {
            cacheEntry := &redis.WarehouseCacheEntry{
                WarehouseID:       warehouse.ID.String(),
                MatchType:         "exact",
                MatchedLocationID: matchedLocationID,
                Priority:          coverageArea.Priority,
            }
            uc.cacheRepo.SetWarehouseByLocation(ctx, locationID, cacheEntry)
        }
        return warehouse, "exact", matchedLocationID, coverageArea.Priority, nil
    }
    
    // Fallback to ancestors, then default warehouse
}
```

**Tốt**: 
- Cache-aside pattern
- Fallback logic: exact → ancestor → default
- Priority-based selection

#### ✅ ĐÚNG (code hiện tại): TransferStock đã dùng Transactional Outbox

**Verified (thực tế code)**:
- `InventoryUsecase.TransferStock` thực hiện DB updates trong `tx.InTx` và **ghi outbox event ngay trong transaction**:
  - `uc.outboxRepo.Create(txCtx, outboxEvent)`
- Như vậy, flow này **không còn bypass outbox** như nhận định trước đó.

**Gợi ý cải thiện (P2)**:
- Nếu business cần phát cả biến động ở **source** và **destination**, cân nhắc:
  - Ghi **2 outbox records** (1 cho source, 1 cho dest), hoặc
  - 1 payload chứa cả source+dest để consumer xử lý đúng.

#### ⚠️ VẤN ĐỀ P1: Async background tasks vẫn spawn goroutine (dù đã “managed” hơn)

**Hiện tại (thực tế code)**:
- `UpdateInventory` / `AdjustStock` dùng `errgroup.WithContext(ctx)` + `context.WithTimeout(..., 5s)` + `panic recovery` ✅
- Nhưng để không block response, code vẫn chạy `go func(){ g.Wait() }()` (background wait) ✅/⚠️

**Rủi ro / Gap**:
- Background tasks vẫn chạy ngoài request lifecycle (có thể bị cancel/timeout khác kỳ vọng; khó đảm bảo delivery).
- Nếu mục tiêu là “event-driven only”, các side effects (alerts, catalog sync) nên đi qua outbox/event consumer.

**Concrete Actions**:
- **P1**: Move alerts + catalog sync sang event consumers (subscribe `warehouse.inventory.stock_changed`).
- **P2**: Nếu vẫn cần async trong request path, chuẩn hóa thành 1 “managed background runner” (queue/worker pool) thay vì spawn goroutine rải rác.

- Context bị lost (dùng `context.Background()`)
- Không có timeout
- Không có tracing spans

**Fix**:
```go
// ✅ ĐÚNG: Move to event consumers (recommended)
// warehouse/internal/observer/inventory_changed/alert_sub.go
type AlertSub struct {
    alertUsecase *alert.AlertUsecase
    log          *log.Helper
}

func (s *AlertSub) Handle(ctx context.Context, event events.StockUpdatedEvent) error {
    ctx, span := otel.Tracer("warehouse").Start(ctx, "AlertSub.Handle")
    defer span.End()
    
    // Get inventory
    inventory, err := s.inventoryRepo.FindByID(ctx, event.InventoryID)
    if err != nil {
        return err
    }
    
    // Check alerts with proper context and error handling
    if err := s.alertUsecase.CheckLowStock(ctx, inventory); err != nil {
        s.log.WithContext(ctx).Errorf("Failed to check low stock alert: %v", err)
    }
    return nil
}

// ✅ ĐÚNG: Or use managed goroutine with recovery (if must be sync)
import "golang.org/x/sync/errgroup"

func (uc *InventoryUsecase) UpdateInventory(ctx context.Context, req *UpdateInventoryRequest) (*model.Inventory, error) {
    // ... update logic
    
    // Use errgroup for managed goroutines
    if quantityChanged {
        g, gCtx := errgroup.WithContext(ctx)
        
        // Alert check with timeout
        if uc.alertUsecase != nil {
            g.Go(func() error {
                alertCtx, cancel := context.WithTimeout(gCtx, 5*time.Second)
                defer cancel()
                
                defer func() {
                    if r := recover(); r != nil {
                        uc.log.Errorf("Panic in alert check: %v", r)
                    }
                }()
                
                return uc.alertUsecase.CheckLowStock(alertCtx, updated)
            })
        }
        
        // Catalog sync with timeout
        if uc.catalogClient != nil {
            g.Go(func() error {
                syncCtx, cancel := context.WithTimeout(gCtx, 5*time.Second)
                defer cancel()
                
                defer func() {
                    if r := recover(); r != nil {
                        uc.log.Errorf("Panic in catalog sync: %v", r)
                    }
                }()
                
                return uc.catalogClient.SyncProductStock(syncCtx, updated.ProductID.String())
            })
        }
        
        // Wait for all goroutines (but don't fail update if they fail)
        if err := g.Wait(); err != nil {
            uc.log.Warnf("Background tasks failed: %v", err)
        }
    }
}
```

**Priority**: P1 - HIGH  
**Estimated Fix Time**: 4 giờ  
**Note**: TODOs đã có trong code, cần implement event consumers

---


### 4. DATA LAYER & PERSISTENCE ⭐⭐⭐⭐⭐ (95%)

#### ✅ ĐÚNG: Repository Pattern với BaseRepo

```go
// warehouse/internal/data/postgres/inventory.go
type inventoryRepo struct {
    *commonRepo.BaseRepo
    log *log.Helper
}

func (r *inventoryRepo) FindByID(ctx context.Context, id string) (*model.Inventory, error) {
    var m model.Inventory
    inventoryID, err := uuid.Parse(id)
    if err != nil {
        return nil, err
    }
    err = r.DB(ctx).Preload("Warehouse").Where("id = ?", inventoryID).Take(&m).Error
    if err == gorm.ErrRecordNotFound {
        return nil, nil
    }
    return &m, err
}
```

**Tốt**: 
- BaseRepo provides transaction context extraction
- Preload relationships
- Returns nil for not found

#### ✅ ĐÚNG: Row Locking cho Concurrency Safety

```go
// warehouse/internal/data/postgres/inventory.go:60
func (r *inventoryRepo) FindByWarehouseAndProductForUpdate(ctx context.Context, warehouseID, productID string) (*model.Inventory, error) {
    var m model.Inventory
    // Use SELECT ... FOR UPDATE to lock the row
    err = r.DB(ctx).Preload("Warehouse").
        Where("warehouse_id = ? AND product_id = ?", whID, prodID).
        Clauses(clause.Locking{Strength: "UPDATE"}).
        Take(&m).Error
    return &m, err
}
```

**Tốt**: Pessimistic locking prevents race conditions

#### ✅ ĐÚNG: Atomic Operations với GORM Expressions

```go
// warehouse/internal/data/postgres/inventory.go:300
func (r *inventoryRepo) IncrementAvailable(ctx context.Context, id string, quantity int32) error {
    now := time.Now()
    return r.DB(ctx).Model(&model.Inventory{}).
        Where("id = ?", inventoryID).
        Updates(map[string]interface{}{
            "quantity_available": gorm.Expr("quantity_available + ?", quantity),
            "updated_at":         now,
            "last_movement_at":   now,
        }).Error
}
```

**Tốt**: Database-level atomic increment

---

### 5. SECURITY ⭐⭐⭐⭐⭐ (90%)

#### ✅ ĐÚNG: Input Validation với Common Validation

```go
// warehouse/internal/biz/warehouse/warehouse.go:80
func (uc *WarehouseUsecase) CreateWarehouse(ctx context.Context, req *CreateWarehouseRequest) (*model.Warehouse, error) {
    // Validate required fields using common validation
    validator := commonValidation.NewValidator().
        Required("code", req.Code).
        Required("name", req.Name)
    
    if validator.HasErrors() {
        errors := validator.GetErrors()
        if len(errors) > 0 {
            return nil, fmt.Errorf("%s: %s", errors[0].Field, errors[0].Message)
        }
    }
    
    // Validate distributor ID if provided
    if req.DistributorID != "" {
        if err := commonValidation.NewValidator().
            UUID("distributor_id", req.DistributorID).
            Validate(); err != nil {
            return nil, fmt.Errorf("invalid distributor ID: %w", err)
        }
    }
}
```

**Tốt**: Comprehensive input validation

#### ✅ ĐÚNG: Location Service Validation

```go
// warehouse/internal/biz/warehouse/warehouse.go:250
func (uc *WarehouseUsecase) AddCoverageArea(ctx context.Context, req *AddCoverageAreaRequest) (*model.WarehouseCoverageArea, error) {
    // Validate location exists in Location Service
    if uc.locationClient != nil {
        valid, err := uc.locationClient.ValidateLocation(ctx, req.LocationID)
        if err != nil {
            uc.log.Warnf("Failed to validate location: %v", err)
            // Continue without validation if Location Service unavailable
        } else if !valid {
            return nil, fmt.Errorf("location not found or inactive")
        }
    }
}
```

**Tốt**: External service validation với graceful degradation

---

### 6. PERFORMANCE & SCALABILITY ⭐⭐⭐⭐ (85%)

#### ✅ ĐÚNG: Bulk Operations Support

**Verified (thực tế code)**:
- `InventoryUsecase.GetBulkStock` **return error** nếu request > 1000 product IDs (không còn silent truncation).
- Aggregation logic hợp lý: `available = quantity_available - quantity_reserved` và clamp về 0.

#### ⚠️ VẤN ĐỀ P2: Semantics không đồng nhất giữa `GetBulkStock` và `GetByProductIDs`

**Hiện tại (thực tế code)**:
- `GetBulkStock`: `return error` nếu > 1000.
- `GetByProductIDs`: truncate về 1000 và chỉ warn (`GetByProductIDs: limited to 1000 products, truncating request`).
- Service handler `InventoryService.GetBulkStock` gọi cả hai:
  - gọi `GetBulkStock` để lấy aggregated stock
  - gọi `GetByProductIDs` để build `StockDetails`

**Rủi ro**:
- Nếu client gửi > 1000 IDs:
  - `GetBulkStock` sẽ fail (OK, rõ ràng), nhưng nếu sau này relax limit và vẫn cho chạy, `StockDetails` có thể bị thiếu do truncation.
- API behavior không nhất quán giữa endpoints/handlers.

**Concrete Actions**:
- **P2**: Thống nhất strategy:
  - Option A: cả hai đều return error nếu vượt limit
  - Option B: implement chunking trong layer service/usecase và đảm bảo `StockDetails` đầy đủ
- **P2**: Đưa `maxBulkSize` thành config thay vì hardcode.


#### ✅ ĐÚNG: Redis Caching cho Warehouse Detection

```go
// warehouse/internal/data/redis/warehouse_cache.go (inferred)
// Cache warehouse detection results to avoid repeated location service calls
type WarehouseCacheEntry struct {
    WarehouseID       string
    WarehouseCode     string
    MatchType         string // "exact", "ancestor", "default"
    MatchedLocationID string
    Priority          int32
}
```

**Tốt**: Cache reduces load on location service

---

### 7. OBSERVABILITY ⭐⭐⭐⭐ (80%)

#### ✅ ĐÚNG: Structured Logging

```go
// warehouse/internal/biz/inventory/inventory.go:450
func (uc *InventoryUsecase) AdjustStock(ctx context.Context, req *AdjustStockRequest) (*model.Inventory, *model.StockTransaction, error) {
    uc.log.WithContext(ctx).Infof("Adjusting stock: warehouse=%s, product=%s, change=%d", req.WarehouseID, req.ProductID, req.QuantityChange)
    // ... business logic
    uc.log.WithContext(ctx).Infof("Stock adjusted successfully: %s", updated.ID)
}
```

**Tốt**: Context-aware logging

#### ✅ ĐÚNG: Prometheus Metrics

```go
// warehouse/internal/observability/prometheus/metrics.go (inferred from checklist)
warehouse_concurrent_orders{warehouse_id}
warehouse_daily_orders{warehouse_id}
warehouse_capacity_utilization_percent{warehouse_id, type}
warehouse_outbox_events_processed_total
warehouse_outbox_events_failed_total
```

**Tốt**: Business metrics implemented

#### ⚠️ VẤN ĐỀ P2: Tracing spans chưa đồng đều (worker có, business flow chưa thấy rõ)

**Verified (thực tế code)**:
- `warehouse/internal/worker/outbox_worker.go` đã có OTel spans cho xử lý outbox event.
- Ở layer biz/service (ví dụ `inventory/inventory.go`, `service/inventory_service.go`) hiện mình **chưa thấy** spans explicit như fulfillment (`otel.Tracer(...).Start(...)`).

**Rủi ro**:
- Khó trace end-to-end cho các thao tác inventory/reservation/transfer.

**Concrete Actions**:
- **P2**: Add spans ở các usecase chính (AdjustStock, ReserveStock, TransferStock) và set attributes quan trọng (warehouse_id, product_id, reservation_id, transfer_id).
- **P2**: Ensure HTTP/gRPC middleware propagation đã bật (server đã có `tracing.Server()`, nhưng cần logging middleware để correlate logs tốt hơn).

---

### 8. TESTING & QUALITY ⭐⭐ (60%)

#### ✅ ĐÚNG: Testable Architecture

```go
// All dependencies are interfaces → easy to mock
type InventoryUsecase struct {
    repo               InventoryRepo            // Interface
    transactionRepo    TransactionRepo          // Interface
    reservationRepo    ReservationRepo          // Interface
    outboxRepo         OutboxRepo               // Interface
    eventPublisher     events.EventPublisher    // Interface
    catalogClient      CatalogClient            // Interface
    alertUsecase       *alert.AlertUsecase      // Interface
    tx                 commonTx.Transaction     // Interface
}
```

#### ⚠️ VẤN ĐỀ P1: Missing Test Coverage

**Hiện tại**: Không thấy test files trong codebase

**Nên có**:
```bash
# Test structure
warehouse/
├── internal/
│   ├── biz/
│   │   ├── inventory/
│   │   │   ├── inventory.go
│   │   │   └── inventory_test.go          # ← Missing
│   │   ├── warehouse/
│   │   │   ├── warehouse.go
│   │   │   └── warehouse_test.go          # ← Missing
│   │   ├── throughput/
│   │   │   ├── throughput.go
│   │   │   └── throughput_test.go         # ← Missing
│   ├── data/
│   │   └── postgres/
│   │       ├── inventory.go
│   │       └── inventory_test.go          # ← Missing (integration tests)
```

**Priority**: P1 - HIGH  
**Estimated Fix Time**: 8 giờ (target: 80% coverage)

---

### 9. CONFIGURATION & RESILIENCE ⭐⭐⭐⭐⭐ (90%)

#### ✅ ĐÚNG: Comprehensive Configuration

```go
// warehouse/internal/conf/conf.proto (from checklist)
message ThroughputCapacity {
    int32 default_max_orders_per_day = 1;
    int32 default_max_items_per_hour = 2;
    int32 default_max_concurrent_orders = 3;
    int32 capacity_alert_threshold_warning = 4;
    int32 capacity_alert_threshold_critical = 5;
}

message TimeSlotConfig {
    bool enable_time_slots = 1;
    bool allow_customer_selection = 2;
    int32 default_slot_duration_hours = 3;
}
```

**Tốt**: Configurable defaults and thresholds

#### ✅ ĐÚNG: Graceful Degradation

```go
// warehouse/internal/biz/warehouse/warehouse.go:250
if uc.locationClient != nil {
    valid, err := uc.locationClient.ValidateLocation(ctx, req.LocationID)
    if err != nil {
        uc.log.Warnf("Failed to validate location: %v", err)
        // Continue without validation if Location Service unavailable
    }
}
```

**Tốt**: Service continues if external dependency fails

#### ✅ ĐÚNG: Redis TTL for Auto-Cleanup

```go
// warehouse/internal/data/redis/throughput.go (from checklist)
// Daily counters: TTL 48h
warehouse:{warehouse_id}:daily_orders:{YYYY-MM-DD}

// Hourly counters: TTL 2h
warehouse:{warehouse_id}:hourly_orders:{YYYY-MM-DD-HH}
warehouse:{warehouse_id}:hourly_items:{YYYY-MM-DD-HH}
```

**Tốt**: Auto-expiring counters prevent memory leaks

---

### 10. DOCUMENTATION & MAINTENANCE ⭐⭐⭐⭐ (85%)

#### ✅ ĐÚNG: Comprehensive Documentation

```markdown
# warehouse/README.md (from checklist)
- Throughput capacity concept
- Time slot configuration
- Capacity check fallback logic
- Customer-facing APIs
- Admin configuration
- Examples with peak/off-peak hours
```

**Tốt**: Well-documented features

#### ✅ ĐÚNG: TODOs for Known Issues

```go
// warehouse/internal/biz/inventory/inventory.go:380
// TODO: Move alert checks to be triggered by event consumers (safer pattern)
go func() {
    alertCtx := context.Background()
    if err := uc.alertUsecase.CheckLowStock(alertCtx, updated); err != nil {
        uc.log.Warnf("Failed to check low stock alert: %v", err)
    }
}()
```

**Tốt**: Known issues documented in code

#### ⚠️ VẤN ĐỀ P2: Missing Architecture Decision Records (ADRs)

**Nên có**:
```markdown
# docs/adr/001-warehouse-location-detection.md
## Context
Need to detect warehouse based on customer location with fallback logic.

## Decision
Use priority-based matching: exact → ancestor → default
Cache results in Redis with TTL 5 minutes.

## Consequences
- ✅ Fast warehouse detection
- ✅ Reduced load on location service
- ⚠️ Cache invalidation needed when coverage areas change
```

**Priority**: P2 - NICE TO HAVE  
**Estimated Fix Time**: 2 giờ

---

## 🚨 CRITICAL ISSUES SUMMARY

### P0 - BLOCKING (Must Fix Before Production)

**None** - Service is production ready from critical perspective

---

## ⚠️ HIGH PRIORITY ISSUES (P1)

### 1. Unmanaged Goroutines for Alerts & Catalog Sync
**Files**: `warehouse/internal/biz/inventory/inventory.go:380, 450`  
**Issue**: Goroutines không có panic recovery, context lost, no timeout  
**Impact**: Potential panics, lost traces, resource leaks  
**Fix Time**: 4 giờ

**Solution**: Move to event consumers or use errgroup with recovery

### 2. GetBulkStock Semantics Unclear
**Files**: `warehouse/internal/biz/inventory/inventory.go:850`  
**Issue**: Silent truncation to 1000 products  
**Impact**: Caller không biết request bị truncate  
**Fix Time**: 2 giờ

**Solution**: Return error if limit exceeded, or support chunking

### 3. Missing Test Coverage
**Files**: All business logic files  
**Issue**: Không có unit/integration tests  
**Impact**: Khó maintain, risk of regressions  
**Fix Time**: 8 giờ

**Solution**: Add tests cho business logic (target: 80% coverage)

---

## 💡 NICE TO HAVE (P2)

### 1. Missing Architecture Decision Records
**Fix Time**: 2 giờ  
**Solution**: Document key architectural decisions

### 2. Money Representation Evaluation
**Fix Time**: 4 giờ (planning + migration)  
**Solution**: Evaluate migration from float64 to integer minor-units

---


## 📋 ACTION PLAN

### Sprint 1 (Week 1) - High Priority Fixes
**Total: 6 giờ**

1. **Fix Unmanaged Goroutines** (4h) - P1
   - Move alert checks to event consumers
   - Move catalog sync to event consumers
   - Or use errgroup with panic recovery
   - Add timeout and tracing

2. **Fix GetBulkStock Semantics** (2h) - P1
   - Return error if limit exceeded
   - Or implement chunking support
   - Add configurable limit
   - Update documentation

### Sprint 2 (Week 2) - Testing & Documentation
**Total: 10 giờ**

3. **Add Test Coverage** (8h) - P1
   - Unit tests for inventory usecase
   - Unit tests for warehouse usecase
   - Unit tests for throughput usecase
   - Integration tests for repository layer
   - Target: 80% coverage

4. **Add Architecture Decision Records** (2h) - P2
   - Document warehouse location detection
   - Document throughput capacity design
   - Document time slot fallback logic
   - Document caching strategy

---

## 📊 METRICS TO TRACK

### Business Metrics
```promql
# Inventory operations
rate(warehouse_inventory_adjustments_total[5m])
rate(warehouse_inventory_transfers_total[5m])

# Capacity utilization
warehouse_concurrent_orders{warehouse_id}
warehouse_daily_orders{warehouse_id}
warehouse_capacity_utilization_percent{warehouse_id, type}

# Warehouse detection
rate(warehouse_detection_cache_hits_total[5m])
rate(warehouse_detection_cache_misses_total[5m])

# Outbox processing
rate(warehouse_outbox_events_processed_total[5m])
rate(warehouse_outbox_events_failed_total[5m])
```

### SLIs/SLOs
- **Inventory Adjustment Success Rate**: > 99.9%
- **Warehouse Detection Time**: p95 < 100ms (with cache)
- **Bulk Stock Query Time**: p95 < 500ms (1000 products)
- **Capacity Check Time**: p95 < 50ms

---

## ✅ REVIEW CHECKLIST

- [x] 1. Architecture & Clean Code - 95%
- [x] 2. API & Contract - 90%
- [x] 3. Business Logic & Concurrency - 75%
- [x] 4. Data Layer & Persistence - 95%
- [x] 5. Security - 90%
- [x] 6. Performance & Scalability - 85%
- [x] 7. Observability - 80%
- [x] 8. Testing & Quality - 60%
- [x] 9. Configuration & Resilience - 90%
- [x] 10. Documentation & Maintenance - 85%

**Overall Score**: 85% ⭐⭐⭐⭐

---

## 🎯 FINAL RECOMMENDATIONS

### Immediate Actions (This Week)
1. Fix unmanaged goroutines (P1) - 4h
2. Fix GetBulkStock semantics (P1) - 2h

### Short Term (Next 2 Weeks)
3. Add comprehensive test coverage (P1) - 8h
4. Add architecture decision records (P2) - 2h

### Long Term (Next Month)
5. Evaluate money representation migration
6. Add circuit breaker for external services
7. Implement distributed tracing spans
8. Add performance benchmarks

### Monitoring Setup
- Create Grafana dashboard for warehouse metrics
- Set up alerts for:
  - High capacity utilization (> 90%)
  - Outbox processing failures (> 1%)
  - Warehouse detection cache miss rate (> 20%)
  - Inventory adjustment failures (> 0.1%)

---

## 🌟 STRENGTHS SUMMARY

### What's Working Well
1. **Clean Architecture**: Well-organized domain logic with clear boundaries
2. **Transactional Outbox**: Reliable event delivery implemented
3. **Comprehensive Capacity Management**: Time slots + global capacity + fallback logic
4. **Location-Based Detection**: Smart warehouse selection with caching
5. **Bulk Operations**: Efficient batch processing for stock queries
6. **Configuration**: Flexible configuration with sensible defaults
7. **Documentation**: Well-documented features and APIs

### Production Readiness
- ✅ **Core Functionality**: All major features implemented
- ✅ **Data Consistency**: Transactional outbox ensures reliability
- ✅ **Performance**: Caching and bulk operations optimize performance
- ✅ **Resilience**: Graceful degradation when dependencies fail
- ⚠️ **Testing**: Needs comprehensive test coverage
- ⚠️ **Goroutines**: Needs proper management for background tasks

**Overall Assessment**: Service is **NEAR PRODUCTION READY** with minor fixes needed for goroutine management and testing.

---

## 📚 REFERENCE DOCUMENTS

### Related Documentation
- [Warehouse Throughput Capacity Checklist](./WAREHOUSE_THROUGHPUT_CAPACITY.md)
- [Team Lead Code Review Guide](./TEAM_LEAD_CODE_REVIEW_GUIDE.md)
- [Backend Services Review Checklist](./BACKEND_SERVICES_REVIEW_CHECKLIST.md)

### Implementation Guides
- `warehouse/README.md` - Service overview and API documentation
- `warehouse/docs/WAREHOUSE_CAPACITY_MANAGEMENT.md` - Capacity management guide
- `warehouse/docs/MIGRATION_STRATEGY.md` - Migration strategy for throughput capacity

### Key Files Reviewed
- `warehouse/internal/biz/inventory/inventory.go` - Inventory business logic
- `warehouse/internal/biz/warehouse/warehouse.go` - Warehouse business logic
- `warehouse/internal/biz/throughput/throughput.go` - Throughput capacity logic
- `warehouse/internal/biz/timeslot/timeslot.go` - Time slot management
- `warehouse/internal/data/postgres/inventory.go` - Inventory repository
- `warehouse/internal/service/warehouse_service.go` - gRPC service layer

---

**Review Completed**: 2026-01-16  
**Next Review**: After P1 fixes completed  
**Reviewer**: Senior Lead


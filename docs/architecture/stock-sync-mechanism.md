# Cơ Chế Thông Báo Stock Thay Đổi: Warehouse → Catalog

> **Date:** November 12, 2024  
> **Question:** Nếu có thay đổi stock ở Warehouse thì Catalog làm sao biết?

---

## 📊 Tổng Quan

Catalog Service nhận biết khi stock thay đổi ở Warehouse Service thông qua **2 cơ chế song song** (dual mechanism) để đảm bảo reliability:

1. **Event-Driven (Dapr Pub/Sub)** - Async, scalable
2. **Direct HTTP Sync** - Immediate, reliable fallback

---

## 🔄 Cơ Chế 1: Event-Driven (Dapr Pub/Sub)

### Flow Diagram

```
┌─────────────────┐
│ Warehouse       │
│ Service         │
│                 │
│ Update Stock    │
│ (UpdateInventory)│
└────────┬────────┘
         │
         │ 1. Publish Event
         ▼
┌─────────────────┐
│ Dapr Pub/Sub    │
│ (Redis Backend) │
│ Topic:          │
│ warehouse.stock.│
│ updated         │
└────────┬────────┘
         │
         │ 2. Dapr delivers event
         ▼
┌─────────────────┐
│ Catalog Service │
│ Event Handler   │
│ /dapr/subscribe/│
│ warehouse.stock.│
│ updated         │
└─────────────────┘
```

### Implementation Details

#### **Step 1: Warehouse Publishes Event**

**Location:** `warehouse/internal/biz/inventory/inventory.go`

```go
// UpdateInventory - Khi stock thay đổi
func (uc *InventoryUsecase) UpdateInventory(ctx context.Context, req *UpdateInventoryRequest) (*model.Inventory, error) {
    // ... update inventory logic ...
    
    // Publish stock updated event if quantity changed
    if quantityChanged && uc.eventPublisher != nil {
        event := bizEvents.StockUpdatedEvent{
            EventType:         "warehouse.stock.updated",
            WarehouseID:       updated.WarehouseID.String(),
            ProductID:         updated.ProductID.String(),
            SKU:               updated.SKU,
            OldStock:          int64(oldQuantity),
            NewStock:          int64(updated.QuantityAvailable),
            QuantityAvailable: int64(updated.QuantityAvailable),
            QuantityReserved:  int64(updated.QuantityReserved),
            AvailableStock:    int64(availableStock),
            StockStatus:       stockStatus,
            Timestamp:         time.Now(),
        }
        
        // Publish via Dapr
        if err := uc.eventPublisher.PublishEvent(ctx, "warehouse.stock.updated", event); err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to publish stock updated event: %v", err)
            // Don't fail the update if event publishing fails
        }
    }
    
    return updated, nil
}
```

**Event Publisher:** `warehouse/internal/biz/events/event_publisher.go`
- Sử dụng Dapr HTTP API: `POST http://localhost:3500/v1.0/publish/{pubsub}/{topic}`
- Retry logic với exponential backoff
- Non-blocking (không block nếu publish fail)

---

#### **Step 2: Catalog Subscribes to Event**

**Location:** `catalog/configs/config.yaml` hoặc `config-docker.yaml`

```yaml
dapr:
  subscriptions:
    - pubsub_name: "pubsub"
      topic: "warehouse.stock.updated"
      route: "/dapr/subscribe/warehouse.stock.updated"
```

**Subscription Discovery:** `catalog/internal/server/http.go`

```go
// Dapr calls /dapr/subscribe to discover subscriptions
srv.HandleFunc("/dapr/subscribe", eventHandler.DaprSubscribeHandler)
```

**Event Handler Registration:** `catalog/internal/server/http.go`

```go
// Register event handler endpoint
srv.HandleFunc("/dapr/subscribe/warehouse.stock.updated", 
    warehouseStockHandler.Handle)
```

---

#### **Step 3: Catalog Processes Event**

**Location:** `catalog/internal/data/eventbus/warehouse_stock_update.go`

```go
// Handle handles warehouse.stock.updated event
func (h *WarehouseStockUpdateHandler) Handle(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    
    // Parse CloudEvent from Dapr
    body, _ := io.ReadAll(r.Body)
    var cloudEvent CloudEvent
    json.Unmarshal(body, &cloudEvent)
    
    // Extract event data
    var event StockUpdatedEvent
    json.Unmarshal(cloudEvent.Data, &event)
    
    // Check idempotency (prevent duplicate processing)
    eventID := cloudEvent.ID
    processed, _ := h.rdb.Get(ctx, idempotencyKey).Bool()
    if processed {
        // Already processed, skip
        return
    }
    
    // Update cache asynchronously
    go func() {
        // Update stock cache
        h.UpdateProductStockCache(ctx, event.ProductID, event.AvailableStock, event.WarehouseID)
        
        // Invalidate product cache
        h.rdb.Del(ctx, productCacheKey)
        
        // Mark event as processed
        h.rdb.Set(ctx, idempotencyKey, true, 24*time.Hour)
    }()
    
    // Return immediately (async processing)
    w.WriteHeader(http.StatusOK)
}
```

**Cache Update:** `catalog/internal/data/eventbus/warehouse_stock_update.go`

```go
// UpdateProductStockCache updates stock cache for a product
func (h *WarehouseStockUpdateHandler) UpdateProductStockCache(ctx context.Context, 
    productID string, newStock int64, warehouseID string) error {
    
    // Store stock per warehouse
    warehouseStockKey := constants.BuildCacheKey(constants.CacheKeyStockWarehouse, productID, warehouseID)
    h.rdb.Set(ctx, warehouseStockKey, newStock, constants.StockCacheTTLWarehouse)
    
    // Aggregate total stock using Lua script (atomic)
    pattern := constants.BuildCacheKey(constants.CachePatternStockWarehouse, productID)
    totalStockKey := constants.BuildCacheKey(constants.CacheKeyStockTotal, productID)
    
    // Lua script aggregates all warehouse stocks
    script := `
        local keys = redis.call('KEYS', pattern)
        local total = 0
        for i, key in ipairs(keys) do
            local val = redis.call('GET', key)
            if val then
                total = total + tonumber(val)
            end
        end
        redis.call('SET', totalKey, total, 'EX', ttl)
        return total
    `
    
    h.rdb.Eval(ctx, script, []string{pattern, totalStockKey}, ttl)
    
    return nil
}
```

---

## 🔄 Cơ Chế 2: Direct HTTP Sync (Fallback)

### Flow Diagram

```
┌─────────────────┐
│ Warehouse       │
│ Service         │
│                 │
│ Update Stock    │
│ (UpdateInventory)│
└────────┬────────┘
         │
         │ 1. Publish Event (async)
         │ 2. Direct HTTP Call (async goroutine)
         ▼
┌─────────────────┐
│ Catalog Service │
│ HTTP Endpoint   │
│ POST /v1/catalog│
│ /admin/stock/   │
│ sync/{productID} │
└────────┬────────┘
         │
         │ 3. Sync Stock
         ▼
┌─────────────────┐
│ Catalog Service │
│ SyncProductStock│
│ - Fetch from    │
│   Warehouse API │
│ - Update Cache  │
└─────────────────┘
```

### Implementation Details

#### **Step 1: Warehouse Calls Catalog Sync Endpoint**

**Location:** `warehouse/internal/biz/inventory/inventory.go`

```go
// UpdateInventory - Sau khi publish event
func (uc *InventoryUsecase) UpdateInventory(ctx context.Context, req *UpdateInventoryRequest) (*model.Inventory, error) {
    // ... publish event ...
    
    // Always sync stock immediately in Catalog service, regardless of event publish status
    // This ensures immediate sync when admin edits stock, even if Dapr is unavailable
    if uc.catalogClient != nil {
        go func() {
            // Use background context for async sync
            syncCtx := context.Background()
            if err := uc.catalogClient.SyncProductStock(syncCtx, updated.ProductID.String()); err != nil {
                uc.log.WithContext(syncCtx).Warnf("Failed to sync stock in catalog: %v", err)
            } else {
                uc.log.WithContext(syncCtx).Infof("Successfully triggered stock sync for product %s in Catalog", 
                    updated.ProductID.String())
            }
        }()
    }
    
    return updated, nil
}
```

**Catalog Client:** `warehouse/internal/client/catalog_client.go`

```go
// SyncProductStock syncs stock for a specific product
func (c *httpCatalogClient) SyncProductStock(ctx context.Context, productID string) error {
    url := fmt.Sprintf("%s/v1/catalog/admin/stock/sync/%s", c.baseURL, productID)
    
    req, err := http.NewRequestWithContext(ctx, "POST", url, nil)
    resp, err := c.client.Do(req)
    
    // Check response
    if resp.StatusCode != http.StatusOK {
        return fmt.Errorf("catalog service error: status %d", resp.StatusCode)
    }
    
    return nil
}
```

---

#### **Step 2: Catalog Receives Sync Request**

**Location:** `catalog/internal/server/http.go`

```go
// Register sync endpoint
srv.HandleFunc("/v1/catalog/admin/stock/sync/{productID}", 
    func(w http.ResponseWriter, r *http.Request) {
        productID := mux.Vars(r)["productID"]
        adminService.HandleSyncProductStock(w, r, productID)
    })
```

**Sync Handler:** `catalog/internal/service/admin_service.go`

```go
// HandleSyncProductStock handles sync stock for a specific product
func (s *AdminService) HandleSyncProductStock(w http.ResponseWriter, r *http.Request, productID string) {
    ctx := r.Context()
    
    // Sync stock from Warehouse Service
    if err := s.productUsecase.SyncProductStock(ctx, productID); err != nil {
        s.log.WithContext(ctx).Errorf("Failed to sync stock: %v", err)
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    // Return success
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "message": fmt.Sprintf("Stock synced for product %s", productID),
    })
}
```

---

#### **Step 3: Catalog Syncs Stock from Warehouse**

**Location:** `catalog/internal/biz/product/product.go`

```go
// SyncProductStock - Sync stock for a specific product
func (uc *ProductUsecase) SyncProductStock(ctx context.Context, productID string) error {
    if uc.cache == nil {
        return fmt.Errorf("cache not available")
    }
    if uc.warehouseClient == nil {
        return fmt.Errorf("warehouse client not available")
    }
    
    // Fetch stock from Warehouse Service
    stock, err := uc.warehouseClient.GetTotalStock(ctx, productID)
    if err != nil {
        return fmt.Errorf("failed to get stock from warehouse: %w", err)
    }
    
    // Update cache
    stockKey := constants.BuildCacheKey(constants.CacheKeyStockTotal, productID)
    if err := uc.cache.Set(ctx, stockKey, stock, constants.StockCacheTTLTotal).Err(); err != nil {
        return fmt.Errorf("failed to cache stock: %w", err)
    }
    
    // Invalidate product cache
    productCacheKey := constants.BuildCacheKey(constants.CacheKeyProduct, productID)
    uc.cache.Del(ctx, productCacheKey)
    
    return nil
}
```

**Warehouse Client:** `catalog/internal/client/warehouse_client.go`

```go
// GetTotalStock gets total stock for a product across all warehouses
func (c *httpWarehouseClient) GetTotalStock(ctx context.Context, productID string) (int64, error) {
    // Try GetInventoryByProduct endpoint first
    url := fmt.Sprintf("%s/v1/inventory/product/%s", c.baseURL, productID)
    
    resp, err := c.client.Do(req)
    if err != nil {
        // Fallback to ListInventory endpoint
        return c.getTotalStockFromList(ctx, productID)
    }
    
    // Parse response and aggregate total stock
    var response struct {
        Inventory []struct {
            QuantityAvailable int32 `json:"quantityAvailable"`
            QuantityReserved  int32 `json:"quantityReserved"`
        } `json:"inventory"`
    }
    
    // Aggregate total available stock
    var totalStock int64
    for _, inv := range response.Inventory {
        available := int64(inv.QuantityAvailable - inv.QuantityReserved)
        if available > 0 {
            totalStock += available
        }
    }
    
    return totalStock, nil
}
```

---

## 🔄 Cơ Chế 3: Cron Job (Backup)

### Stock Change Detector Job

**Location:** `warehouse/internal/worker/cron/stock_change_detector.go`

```go
// StockChangeDetectorJob detects inventory changes and pushes events
type StockChangeDetectorJob struct {
    inventoryUsecase *inventory.InventoryUsecase
    eventPublisher   *events.EventPublisher
    lastCheckTime    time.Time
}

// Run runs the job periodically (every 5 minutes)
func (j *StockChangeDetectorJob) Run() {
    ctx := context.Background()
    
    // Find inventory records updated since last check
    changedInventory, _, err := j.inventoryUsecase.FindRecentlyUpdated(ctx, j.lastCheckTime, nil, 1, 1000)
    if err != nil {
        return
    }
    
    // Publish events for each changed product
    for _, inv := range changedInventory {
        j.publishStockUpdatedEvent(ctx, inv)
    }
    
    // Update last check time
    j.lastCheckTime = time.Now()
}
```

**Purpose:**
- Backup mechanism nếu event hoặc HTTP sync fail
- Detect missed changes
- Run mỗi 5 phút

---

## 📊 So Sánh 2 Cơ Chế

| Aspect | Event-Driven (Dapr) | Direct HTTP Sync |
|--------|---------------------|------------------|
| **Latency** | ~50-100ms (async) | ~100-200ms (sync) |
| **Reliability** | High (Dapr retry) | High (HTTP retry) |
| **Scalability** | Very High (pub/sub) | Medium (point-to-point) |
| **Failure Handling** | Graceful degradation | Immediate retry |
| **Use Case** | Real-time updates | Immediate sync |
| **Dependency** | Dapr + Redis | Direct HTTP |

---

## ✅ Tại Sao Cần 2 Cơ Chế?

### **1. Reliability (Độ Tin Cậy)**
- **Event-driven**: Có thể fail nếu Dapr unavailable
- **Direct HTTP**: Fallback khi event fail
- **Result**: Đảm bảo Catalog luôn được sync

### **2. Performance (Hiệu Năng)**
- **Event-driven**: Async, không block Warehouse
- **Direct HTTP**: Immediate sync cho critical updates
- **Result**: Best of both worlds

### **3. Resilience (Khả Năng Phục Hồi)**
- **Event-driven**: Scalable, decoupled
- **Direct HTTP**: Direct control, immediate feedback
- **Result**: System resilient to failures

---

## 🔍 Flow Hoàn Chỉnh

```
┌─────────────────────────────────────────────────────────┐
│  Warehouse Service: Update Stock                        │
└───────────────┬─────────────────────────────────────────┘
                │
                ├─→ 1. Publish Event (Dapr Pub/Sub)
                │   └─→ Topic: warehouse.stock.updated
                │       └─→ Non-blocking, async
                │
                └─→ 2. Direct HTTP Call (async goroutine)
                    └─→ POST /v1/catalog/admin/stock/sync/{productID}
                        └─→ Immediate sync, fallback
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│  Catalog Service: Receive & Process                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Path A: Event Handler                                  │
│  ├─→ /dapr/subscribe/warehouse.stock.updated           │
│  ├─→ Check idempotency                                  │
│  ├─→ Update cache (async)                               │
│  └─→ Invalidate product cache                           │
│                                                         │
│  Path B: HTTP Sync Endpoint                             │
│  ├─→ /v1/catalog/admin/stock/sync/{productID}          │
│  ├─→ Fetch stock from Warehouse API                     │
│  ├─→ Update cache                                       │
│  └─→ Invalidate product cache                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Kết Luận

**Catalog biết khi stock thay đổi thông qua:**

1. ✅ **Event-Driven (Primary)**: Dapr Pub/Sub với topic `warehouse.stock.updated`
2. ✅ **Direct HTTP Sync (Fallback)**: HTTP endpoint `/v1/catalog/admin/stock/sync/{productID}`
3. ✅ **Cron Job (Backup)**: Stock change detector job mỗi 5 phút

**Lợi ích của dual mechanism:**
- ✅ **High Reliability**: Nếu một cơ chế fail, cơ chế kia vẫn hoạt động
- ✅ **Best Performance**: Event async + HTTP immediate
- ✅ **Resilience**: System resilient to failures

---

**Last Updated:** November 12, 2024  
**Status:** Current Implementation Explained


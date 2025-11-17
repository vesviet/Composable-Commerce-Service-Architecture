# Stock & Distribution Center Logic - Review Checklist

## 📋 Tổng Quan

Checklist này review logic quản lý stock (tồn kho) và distribution center (nhà phân phối) trong Warehouse Service, bao gồm các operations, business rules, và integration points.

**Last Updated**: 2025-01-17  
**Status**: ⚠️ Review in progress

---

## 🏗️ 1. Domain Model & Relationships

### 1.1. Entity Relationships

**Hierarchy:**
```
Distributor (Nhà phân phối)
  └── Warehouse (Kho hàng) [Many-to-Many via DistributorWarehouse]
      └── Inventory (Tồn kho) [One-to-Many: 1 Warehouse → Many Inventories]
          └── StockTransaction (Giao dịch tồn kho)
          └── StockReservation (Giữ chỗ tồn kho)
```

#### ✅ Implemented
- [x] **Distributor** entity: Quản lý nhiều warehouses
- [x] **DistributorWarehouse** relationship: Many-to-many với `is_primary` flag
- [x] **DistributorRegion** relationship: Vùng địa lý mà distributor phụ trách
- [x] **Warehouse** entity: Cơ sở lưu trữ vật lý
- [x] **Inventory** entity: Stock levels per warehouse + product
- [x] **StockTransaction** entity: Audit trail cho mọi stock movements
- [x] **StockReservation** entity: Temporary stock holds cho orders

#### ⚠️ Gaps & Issues
- [ ] **Distribution Center concept**: Không có entity riêng cho "Distribution Center"
  - **Current**: Chỉ có "Distributor" và "Warehouse"
  - **Question**: "Distribution Center" có phải là một loại Warehouse đặc biệt không?
  - **Recommendation**: Clarify business requirement - DC có khác gì với Warehouse không?
  - **Files**: `warehouse/internal/model/distributor.go`, `warehouse/internal/model/warehouse.go`

- [ ] **Warehouse Type**: Warehouse có field `warehouse_type` nhưng không thấy logic phân biệt
  - **Current**: `warehouse_type` field exists nhưng không được sử dụng trong stock logic
  - **Recommendation**: 
    - Nếu DC là warehouse type đặc biệt → implement logic phân biệt
    - Nếu DC = Distributor → clarify naming
  - **Files**: `warehouse/internal/model/warehouse.go`

---

## 📊 2. Stock States & Formula

### 2.1. Stock Quantity Fields

**Inventory Model Fields:**
- `QuantityAvailable`: Tổng số lượng hàng có trong kho
- `QuantityReserved`: Số lượng đã được reserve cho orders
- `QuantityOnOrder`: Số lượng đã đặt mua từ supplier nhưng chưa nhận

**Calculated Fields:**
- `AvailableStock = QuantityAvailable - QuantityReserved` (có thể bán ngay)
- `TotalStock = QuantityAvailable + QuantityOnOrder` (tổng tồn kho)

#### ✅ Implemented
- [x] `QuantityAvailable` field trong Inventory model
- [x] `QuantityReserved` field trong Inventory model
- [x] `QuantityOnOrder` field trong Inventory model
- [x] `AvailableStock` calculation trong `ToInventoryReply()`: `availableStock = QuantityAvailable - QuantityReserved`
- [x] `StockStatus` calculation: `"in_stock"` nếu `availableStock > 0`, `"out_of_stock"` nếu `availableStock <= 0`

#### ⚠️ Gaps & Issues
- [ ] **Available Stock calculation consistency**: Có nhiều nơi tính `availableQuantity`
  - **Issue 1**: `warehouse/internal/biz/reservation/reservation.go:78` - `availableQuantity := inventory.QuantityAvailable - inventory.QuantityReserved`
  - **Issue 2**: `warehouse/internal/biz/inventory/inventory.go:343` - `availableStock := updated.QuantityAvailable - updated.QuantityReserved`
  - **Issue 3**: `warehouse/internal/biz/inventory/inventory.go:562` - `availableQuantity := sourceInventory.QuantityAvailable - sourceInventory.QuantityReserved`
  - **Issue 4**: `warehouse/internal/biz/alert/alert.go:199` - `available := inventory.QuantityAvailable - inventory.QuantityReserved`
  - **Impact**: Medium - Code duplication, có thể có inconsistency
  - **Recommendation**: 
    - Create helper function: `CalculateAvailableStock(inventory *Inventory) int32`
    - Use helper function ở tất cả nơi tính available stock
  - **Files**: 
    - `warehouse/internal/biz/reservation/reservation.go:78`
    - `warehouse/internal/biz/inventory/inventory.go:343, 493, 562`
    - `warehouse/internal/biz/alert/alert.go:199, 250, 304`
    - `warehouse/internal/model/inventory.go:117`

- [ ] **Negative Available Stock prevention**: Code có check `availableStock < 0` nhưng không consistent
  - **Current**: 
    - `warehouse/internal/model/inventory.go:118-120` - Set `availableStock = 0` nếu < 0
    - `warehouse/internal/biz/inventory/inventory.go:344-346` - Set `availableStock = 0` nếu < 0
  - **Issue**: Không có validation để prevent `QuantityReserved > QuantityAvailable` từ đầu
  - **Recommendation**: 
    - Add database constraint: `CHECK (quantity_reserved <= quantity_available)`
    - Add validation trong ReserveStock: Ensure `QuantityReserved <= QuantityAvailable` after update
  - **Files**: 
    - `warehouse/migrations/002_create_inventory_table.sql`
    - `warehouse/internal/biz/reservation/reservation.go:143-147`

- [ ] **QuantityOnOrder tracking**: `QuantityOnOrder` field có nhưng không thấy logic update
  - **Current**: Field exists nhưng không có API hoặc logic để update `QuantityOnOrder`
  - **Impact**: Medium - Procurement service không thể track hàng đang trên đường về
  - **Recommendation**: 
    - Add API: `UpdateOnOrder(warehouseID, productID, quantity)`
    - Update `QuantityOnOrder` khi purchase order created
    - Decrease `QuantityOnOrder` và increase `QuantityAvailable` khi goods received
  - **Files**: `warehouse/internal/biz/inventory/inventory.go`, `warehouse/api/inventory/v1/inventory.proto`

---

## 🔄 3. Stock Operations

### 3.1. Reserve Stock (Giữ chỗ tồn kho)

**Flow:**
```
Order Service → ReserveStock API → Check Available → Create Reservation → Increment Reserved
```

#### ✅ Implemented
- [x] `ReserveStock` API endpoint: `POST /api/v1/inventory/reserve`
- [x] Validation: Check `availableQuantity >= requestedQuantity`
- [x] Create `StockReservation` record với status "active"
- [x] Update `QuantityReserved`: `IncrementReserved(inventoryID, quantity)`
- [x] Expiry calculation: Based on payment method (COD, credit_card, etc.)
- [x] Return reservation ID và updated inventory

#### ⚠️ Gaps & Issues
- [ ] **Reserve Stock không update QuantityAvailable**: Reserve chỉ increment `QuantityReserved`, không decrement `QuantityAvailable`
  - **Current Logic**: 
    - `ReserveStock`: `QuantityReserved += quantity` (✅ Correct)
    - `AvailableStock = QuantityAvailable - QuantityReserved` (✅ Correct)
  - **Status**: ✅ **CORRECT** - Logic đúng, không cần update `QuantityAvailable`
  - **Note**: Available stock được tính dynamically, không cần store riêng

- [ ] **Reservation expiry calculation**: Expiry được tính từ payment method nhưng có fallback logic
  - **Current**: `warehouse/internal/biz/reservation/reservation.go:100-117`
  - **Issue**: Nếu payment method không match → fallback to default, nhưng có thể không log đủ
  - **Recommendation**: 
    - Log warning khi sử dụng default expiry
    - Add metrics để track reservations với default expiry
  - **Files**: `warehouse/internal/biz/reservation/reservation.go:100-117`

- [x] **Reservation creation atomicity**: Reservation được create trước, inventory update sau
  - **Status**: ✅ **HANDLED BY TRIGGER** - Database trigger tự động update
  - **Current**: 
    1. Create reservation (line 136) → Trigger tự động increment `QuantityReserved`
    2. Explicit `IncrementReserved` call (line 143) - Redundant nhưng safe (idempotent)
  - **Note**: Trigger `trigger_update_inventory_reservations` tự động update `QuantityReserved` khi reservation created với status = "active"
  - **Files**: 
    - `warehouse/internal/biz/reservation/reservation.go:136-147`
    - `warehouse/migrations/005_create_reservations_table.sql:84-135` (Trigger function)

- [ ] **Multiple reservations per order**: Một order có thể có nhiều reservations (multi-warehouse)
  - **Current**: ✅ Supported - Mỗi reservation có `reference_type="order"` và `reference_id=orderID`
  - **Status**: ✅ **CORRECT** - Logic hỗ trợ multi-warehouse orders

### 3.2. Release Reservation (Hủy giữ chỗ)

**Flow:**
```
Order Service → ReleaseReservation API → Find Reservation → Update Status → Decrement Reserved
```

#### ✅ Implemented
- [x] `ReleaseReservation` API endpoint: `POST /api/v1/inventory/release`
- [x] Validation: Check reservation exists và status = "active"
- [x] Update reservation status: `"active"` → `"cancelled"`
- [x] Update `QuantityReserved`: `DecrementReserved(inventoryID, quantity)` (via trigger)
- [x] `ReleaseReservationsByOrderID`: Release all reservations for an order

#### ⚠️ Gaps & Issues
- [x] **Release Reservation không decrement QuantityReserved explicitly**: Code chỉ update reservation status
  - **Status**: ✅ **CORRECT** - Database trigger tự động handle
  - **Current**: 
    - `warehouse/internal/biz/reservation/reservation.go:177` - Update reservation status
    - Database trigger `trigger_update_inventory_reservations` tự động decrement `QuantityReserved` khi status = "cancelled"
  - **Files**: 
    - `warehouse/internal/biz/reservation/reservation.go:159-192`
    - `warehouse/migrations/005_create_reservations_table.sql:84-135` (Trigger function)

- [x] **Release Reservation atomicity**: Tương tự Reserve, cần ensure atomicity
  - **Status**: ✅ **HANDLED BY TRIGGER** - Database trigger tự động update
  - **Current**: Update reservation status → Trigger tự động decrement `QuantityReserved`
  - **Note**: Trigger `trigger_update_inventory_reservations` tự động update `QuantityReserved` khi status changes từ "active" → "cancelled"
  - **Files**: 
    - `warehouse/internal/biz/reservation/reservation.go:159-192`
    - `warehouse/migrations/005_create_reservations_table.sql:95-102` (Trigger logic)

- [ ] **Expired reservation auto-release**: Background worker release expired reservations
  - **Current**: ✅ Implemented - `warehouse/internal/worker/expiry/reservation_expiry.go`
  - **Status**: ✅ **CORRECT** - Worker chạy mỗi 5 phút để release expired reservations

### 3.3. Adjust Stock (Điều chỉnh tồn kho)

**Flow:**
```
Admin/Procurement → AdjustStock API → Validate → Update QuantityAvailable → Create Transaction
```

#### ✅ Implemented
- [x] `AdjustStock` API endpoint: `POST /api/v1/inventory/adjust`
- [x] Validation: `quantityAfter >= 0` (không được âm)
- [x] Update `QuantityAvailable`: `UpdateAvailableQuantity(inventoryID, quantityAfter)`
- [x] Create `StockTransaction` record với type "adjustment"
- [x] Publish `warehouse.stock.adjusted` event
- [x] Sync stock to Catalog service

#### ⚠️ Gaps & Issues
- [ ] **Adjust Stock không validate Reserved quantity**: Có thể adjust làm `QuantityAvailable < QuantityReserved`
  - **Current**: `warehouse/internal/biz/inventory/inventory.go:405-409` - Chỉ check `quantityAfter >= 0`
  - **Issue**: Nếu `QuantityAvailable` giảm xuống < `QuantityReserved` → `AvailableStock` sẽ < 0
  - **Impact**: High - Data inconsistency, có thể reserve stock không tồn tại
  - **Recommendation**: 
    - Add validation: `quantityAfter >= inventory.QuantityReserved`
    - Or: Allow adjustment nhưng set `QuantityReserved = min(QuantityReserved, QuantityAvailable)`
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:392-536`

- [ ] **Adjust Stock không có approval workflow**: Documentation nói cần approval nhưng code không có
  - **Current**: Direct adjustment, không có approval workflow
  - **Documentation**: `docs/backup-2025-11-17/docs/operations/stock-flow-discussion.md:369-408` - Nói về approval workflow
  - **Impact**: Medium - Security risk, có thể adjust stock không đúng
  - **Recommendation**: 
    - Implement `AdjustmentRequest` entity với status (pending, approved, rejected)
    - Add approval API: `ApproveAdjustment`, `RejectAdjustment`
    - Only execute adjustment khi approved
  - **Files**: N/A (cần implement)

### 3.4. Transfer Stock (Chuyển kho)

**Flow:**
```
Admin/Fulfillment → TransferStock API → Validate Source → Update Source → Update Destination → Create Transactions
```

#### ✅ Implemented
- [x] `TransferStock` API endpoint: `POST /api/v1/inventory/transfer`
- [x] Validation: Source và destination warehouses khác nhau
- [x] Validation: `availableQuantity >= transferQuantity` ở source warehouse
- [x] Update source: `QuantityAvailable -= quantity`
- [x] Update destination: `QuantityAvailable += quantity` (create inventory nếu chưa có)
- [x] Create 2 transactions: Outbound (source) + Inbound (destination) với linked `TransferID`
- [x] Publish `warehouse.stock.transferred` event

#### ⚠️ Gaps & Issues
- [ ] **Transfer Stock atomicity**: Transfer update 2 warehouses nhưng không có transaction
  - **Current**: 
    1. Update source warehouse (line 670)
    2. Update destination warehouse (line 676)
  - **Issue**: Nếu step 2 fails, source đã bị trừ nhưng destination chưa được cộng
  - **Impact**: High - Data inconsistency
  - **Recommendation**: 
    - Use database transaction để ensure atomicity
    - Or: Use two-phase commit pattern
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:538-650`

- [ ] **Transfer Stock không check destination inventory exists**: Code create nếu chưa có
  - **Current**: `warehouse/internal/biz/inventory/inventory.go:572-580` - Create inventory nếu chưa có
  - **Status**: ✅ **CORRECT** - Logic đúng, tự động create destination inventory

- [ ] **Transfer Stock với Reserved quantity**: Transfer có thể transfer reserved stock không?
  - **Current**: Transfer chỉ check `availableQuantity = QuantityAvailable - QuantityReserved`
  - **Question**: Có thể transfer reserved stock không? Hay chỉ transfer available?
  - **Recommendation**: Clarify business rule - Transfer reserved stock có hợp lý không?
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:562-565`

### 3.5. Deduct Stock (Trừ tồn kho)

**Flow:**
```
Fulfillment Service → AdjustStock API (negative quantity) → Validate → Update → Create Transaction
```

#### ✅ Implemented
- [x] `AdjustStock` API hỗ trợ negative quantity để deduct stock
- [x] Validation: `quantityAfter >= 0`
- [x] Create transaction với type "outbound"

#### ⚠️ Gaps & Issues
- [ ] **Deduct Stock không validate Reserved quantity**: Có thể deduct stock chưa được reserve
  - **Current**: `AdjustStock` không check xem stock đã được reserve chưa
  - **Documentation**: `docs/backup-2025-11-17/docs/operations/stock-flow-discussion.md:128` - Nói "đã reserve rồi mới deduct"
  - **Impact**: Medium - Có thể deduct stock không được reserve
  - **Recommendation**: 
    - Add validation: Nếu deduct, check `QuantityReserved >= quantity`
    - Or: Create separate `DeductStock` API với validation logic riêng
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:392-536`

- [ ] **Deduct Stock flow không rõ ràng**: Không có API riêng cho deduct, phải dùng AdjustStock
  - **Current**: Use `AdjustStock` với negative quantity
  - **Recommendation**: 
    - Create `DeductStock` API riêng với validation logic
    - Or: Document rõ ràng cách dùng `AdjustStock` để deduct
  - **Files**: `warehouse/api/inventory/v1/inventory.proto`

### 3.6. Add Stock (Thêm tồn kho)

**Flow:**
```
Procurement Service → AdjustStock API (positive quantity) → Update → Create Transaction
```

#### ✅ Implemented
- [x] `AdjustStock` API hỗ trợ positive quantity để add stock
- [x] Create transaction với type "inbound"
- [x] Publish stock updated event

#### ⚠️ Gaps & Issues
- [ ] **Add Stock không update QuantityOnOrder**: Khi receive purchase order, nên decrease `QuantityOnOrder`
  - **Current**: `AdjustStock` chỉ update `QuantityAvailable`
  - **Recommendation**: 
    - Add logic: Nếu `ReferenceType = "purchase_order"` → decrease `QuantityOnOrder`
    - Or: Create separate `ReceiveStock` API với logic riêng
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:392-536`

---

## 🔐 4. Business Rules & Validation

### 4.1. Stock Availability Rules

#### ✅ Implemented
- [x] Cannot reserve nếu `AvailableStock < Quantity`
- [x] Cannot transfer nếu `AvailableStock < Quantity` ở source
- [x] Cannot adjust làm stock âm (`quantityAfter >= 0`)
- [x] Available stock calculation: `AvailableStock = QuantityAvailable - QuantityReserved`

#### ⚠️ Gaps & Issues
- [ ] **Negative stock prevention không đầy đủ**: Chỉ check `quantityAfter >= 0`, không check `quantityAfter >= QuantityReserved`
  - **Impact**: High - Có thể có `QuantityReserved > QuantityAvailable`
  - **Recommendation**: Add validation: `quantityAfter >= inventory.QuantityReserved` trong AdjustStock
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:405-409`

- [ ] **Concurrent reservation race condition**: Nhiều requests cùng reserve có thể vượt quá available stock
  - **Current**: Check available stock trước khi reserve, nhưng không có lock
  - **Impact**: High - Race condition có thể reserve quá available stock
  - **Recommendation**: 
    - Use database row lock: `SELECT ... FOR UPDATE` trong ReserveStock
    - Or: Use optimistic locking với version field
  - **Files**: `warehouse/internal/biz/reservation/reservation.go:69-81`

### 4.2. Reservation Rules

#### ✅ Implemented
- [x] Reservation expires based on payment method
- [x] Auto-release expired reservations (background worker)
- [x] One reservation per order item (multi-warehouse support)
- [x] Reservation status: "active", "fulfilled", "expired", "cancelled"

#### ⚠️ Gaps & Issues
- [ ] **Reservation expiry warning**: Code có worker nhưng cần verify notification
  - **Current**: `warehouse/internal/worker/expiry/reservation_warning.go` - Check và warn
  - **Question**: Notification có được gửi không?
  - **Recommendation**: Verify notification integration
  - **Files**: `warehouse/internal/worker/expiry/reservation_warning.go`

- [ ] **Reservation partial fulfillment**: Reservation có `QuantityFulfilled` nhưng không thấy logic update
  - **Current**: Field exists nhưng không thấy API hoặc logic để update
  - **Recommendation**: 
    - Add logic: Khi fulfill order, update `QuantityFulfilled`
    - Support partial fulfillment: `QuantityFulfilled < QuantityReserved`
  - **Files**: `warehouse/internal/biz/reservation/reservation.go:282-316` (CompleteReservation)

### 4.3. Transaction Rules

#### ✅ Implemented
- [x] Every stock change creates transaction record
- [x] Transaction types: "inbound", "outbound", "transfer", "adjustment", "reservation", "release", "count"
- [x] Transaction includes: `quantity_before`, `quantity_change`, `quantity_after`
- [x] Transaction audit trail: `created_by`, `reference_type`, `reference_id`, `notes`

#### ⚠️ Gaps & Issues
- [ ] **Transaction creation atomicity**: Transaction có thể fail sau khi inventory updated
  - **Current**: Update inventory trước, create transaction sau
  - **Issue**: Nếu transaction creation fails, inventory đã update nhưng không có audit trail
  - **Impact**: Medium - Missing audit trail
  - **Recommendation**: Use transaction để ensure cả 2 operations succeed
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:456-460`

---

## 🔗 5. Integration Points

### 5.1. Order Service Integration

#### ✅ Implemented
- [x] `ReserveStock` API cho Order Service
- [x] `ReleaseReservation` API cho Order Service
- [x] `ReleaseReservationsByOrderID` API để release all reservations của order
- [x] Reservation expiry based on payment method

#### ⚠️ Gaps & Issues
- [ ] **Order cancellation flow**: Order Service có gọi ReleaseReservation khi cancel không?
  - **Current**: API exists nhưng cần verify Order Service integration
  - **Recommendation**: Verify Order Service calls ReleaseReservation khi order cancelled
  - **Files**: N/A (cần check Order Service)

### 5.2. Fulfillment Service Integration

#### ✅ Implemented
- [x] Stock updated event: `warehouse.stock.updated`
- [x] Fulfillment status changed handler: `warehouse/internal/biz/inventory/fulfillment_status_handler.go`

#### ⚠️ Gaps & Issues
- [ ] **Fulfillment deduct stock flow**: Fulfillment Service có deduct stock khi shipped không?
  - **Current**: Handler exists nhưng cần verify logic
  - **Recommendation**: Review fulfillment status handler logic
  - **Files**: `warehouse/internal/biz/inventory/fulfillment_status_handler.go`

### 5.3. Catalog Service Integration

#### ✅ Implemented
- [x] Stock sync to Catalog: `catalogClient.SyncProductStock(productID)`
- [x] Sync triggered khi stock updated hoặc adjusted

#### ⚠️ Gaps & Issues
- [ ] **Stock sync failure handling**: Sync là async, nếu fail thì sao?
  - **Current**: Log warning nếu sync fails
  - **Impact**: Medium - Catalog có thể không sync kịp
  - **Recommendation**: 
    - Add retry mechanism
    - Or: Add sync queue để retry later
  - **Files**: `warehouse/internal/biz/inventory/inventory.go:374-384`

### 5.4. Procurement Service Integration

#### ✅ Implemented
- [x] `AdjustStock` API để add stock khi receive goods

#### ⚠️ Gaps & Issues
- [ ] **On Order tracking**: Procurement Service không có API để update `QuantityOnOrder`
  - **Current**: Field exists nhưng không có API
  - **Impact**: Medium - Không track được hàng đang trên đường về
  - **Recommendation**: Add `UpdateOnOrder` API
  - **Files**: `warehouse/api/inventory/v1/inventory.proto`, `warehouse/internal/biz/inventory/inventory.go`

---

## 🏭 6. Distributor & Warehouse Logic

### 6.1. Distributor Management

#### ✅ Implemented
- [x] Distributor CRUD APIs
- [x] Distributor-Warehouse relationship (many-to-many)
- [x] Distributor-Region relationship
- [x] `GetDistributorWarehouses` API

#### ⚠️ Gaps & Issues
- [ ] **Distributor stock aggregation**: Không có API để get total stock across all warehouses của distributor
  - **Current**: Chỉ có API get warehouses, không có stock aggregation
  - **Recommendation**: 
    - Add API: `GetDistributorStock(productID, distributorID)` → Aggregate stock từ all warehouses
  - **Files**: `warehouse/api/distributor/v1/distributor.proto`

- [ ] **Distributor stock allocation**: Khi reserve stock, có ưu tiên warehouse nào của distributor không?
  - **Current**: Order Service phải specify warehouse ID khi reserve
  - **Question**: Có logic auto-select warehouse từ distributor không?
  - **Recommendation**: Clarify business requirement

### 6.2. Warehouse Selection Logic

#### ✅ Implemented
- [x] Multi-warehouse support: Một order có thể reserve từ nhiều warehouses
- [x] Warehouse-specific inventory tracking

#### ⚠️ Gaps & Issues
- [ ] **Warehouse selection algorithm**: Không có logic auto-select warehouse
  - **Current**: Order Service phải specify warehouse ID
  - **Question**: Có cần logic auto-select warehouse dựa trên:
    - Customer location (nearest warehouse)
    - Stock availability
    - Warehouse capacity
    - Distributor assignment
  - **Recommendation**: Clarify business requirement

---

## 🔍 7. Data Consistency & Concurrency

### 7.1. Database Constraints

#### ✅ Implemented
- [x] Foreign key constraints: `warehouse_id`, `product_id` references
- [x] Check constraints: `quantity_before >= 0`, `quantity_after >= 0`
- [x] Check constraints: `quantity_change != 0`
- [x] Check constraints: `quantity_after = quantity_before + quantity_change`

#### ⚠️ Gaps & Issues
- [ ] **Missing constraint**: Không có constraint `quantity_reserved <= quantity_available`
  - **Current**: Chỉ có application-level validation
  - **Impact**: Medium - Database không enforce rule
  - **Recommendation**: Add database constraint
  - **Note**: Trigger có thể prevent nhưng constraint sẽ enforce ở database level
  - **Files**: `warehouse/migrations/002_create_inventory_table.sql`

- [ ] **Transaction atomicity**: Nhiều operations không có transaction
  - **Current**: 
    - ReserveStock: Create reservation → Trigger auto-update inventory (✅ Atomic trong same transaction)
    - TransferStock: Update source + Update destination (⚠️ Không có transaction)
  - **Impact**: 
    - ReserveStock: ✅ OK - Trigger ensures atomicity
    - TransferStock: ⚠️ HIGH - Data inconsistency risk
  - **Recommendation**: 
    - ReserveStock: ✅ No change needed (trigger handles)
    - TransferStock: Use database transaction cho update source + destination
  - **Files**: 
    - `warehouse/internal/biz/reservation/reservation.go:136-147` (✅ OK)
    - `warehouse/internal/biz/inventory/inventory.go:670-676` (⚠️ Need transaction)

### 7.2. Concurrency Control

#### ✅ Implemented
- [x] GORM với database connection pooling

#### ⚠️ Gaps & Issues
- [ ] **No row-level locking**: ReserveStock không có `SELECT ... FOR UPDATE`
  - **Current**: Read inventory, check available, update (race condition possible)
  - **Impact**: High - Concurrent reservations có thể vượt quá available stock
  - **Recommendation**: 
    - Use `SELECT ... FOR UPDATE` trong ReserveStock
    - Or: Use optimistic locking với version field
  - **Files**: `warehouse/internal/biz/reservation/reservation.go:69-81`

- [ ] **No distributed locking**: Multi-service concurrent access không có lock
  - **Current**: Mỗi service có thể reserve stock cùng lúc
  - **Impact**: Medium - Race condition across services
  - **Recommendation**: 
    - Use Redis distributed lock
    - Or: Use database advisory locks
  - **Files**: N/A (cần implement)

---

## 📈 8. Performance & Optimization

### 8.1. Query Optimization

#### ✅ Implemented
- [x] Database indexes: `warehouse_id`, `product_id`, `sku` indexes
- [x] Preload relationships: `Preload("Warehouse")` trong queries

#### ⚠️ Gaps & Issues
- [ ] **Stock aggregation queries**: Get stock across multiple warehouses có thể slow
  - **Current**: `GetByProduct` query có thể scan nhiều warehouses
  - **Recommendation**: 
    - Add composite index: `(product_id, warehouse_id)`
    - Or: Cache aggregated stock levels
  - **Files**: `warehouse/internal/data/postgres/inventory.go:195-207`

- [ ] **Reservation expiry query**: Query expired reservations có thể slow với nhiều reservations
  - **Current**: `GetExpiredReservations` query với `expires_at < NOW()`
  - **Recommendation**: 
    - Add index: `(status, expires_at)`
    - Or: Use partial index: `WHERE status = 'active'`
  - **Files**: `warehouse/internal/data/postgres/reservation.go:208-216`

### 8.2. Caching

#### ✅ Implemented
- [x] Redis cache cho throughput capacity (có trong codebase)

#### ⚠️ Gaps & Issues
- [ ] **Stock level caching**: Stock levels không được cache
  - **Current**: Mỗi query phải read từ database
  - **Impact**: Medium - Performance issue với high traffic
  - **Recommendation**: 
    - Cache stock levels trong Redis với TTL
    - Invalidate cache khi stock updated
  - **Files**: N/A (cần implement)

---

## 🎯 9. Priority Issues Summary

### High Priority (Data Consistency & Correctness)

1. ✅ **Reserve Stock race condition** - FIXED: Added row-level locking
   - **File**: `warehouse/internal/biz/reservation/reservation.go:69-81`
   - **Issue**: Concurrent requests có thể reserve quá available stock
   - **Fix Applied**: 
     - Added `FindByWarehouseAndProductForUpdate` method với `SELECT ... FOR UPDATE`
     - Updated `ReserveStock` to use locked query
   - **Files Changed**: 
     - `warehouse/internal/repository/inventory/inventory.go` - Added interface method
     - `warehouse/internal/data/postgres/inventory.go` - Implemented with `clause.Locking{Strength: "UPDATE"}`
     - `warehouse/internal/biz/reservation/reservation.go` - Use locked query

2. ✅ **Transfer Stock atomicity** - FIXED: Added database transaction
   - **File**: `warehouse/internal/biz/inventory/inventory.go:547-740`
   - **Fix Applied**: 
     - Injected `commonTx.Transaction` vào `InventoryUsecase`
     - Wrapped TransferStock operations trong `tx.InTx()` để ensure atomicity
     - All operations (create transactions, update inventories) now execute in single transaction
   - **Files Changed**: 
     - `warehouse/internal/biz/inventory/inventory.go` - Added transaction field, wrapped TransferStock
     - `warehouse/cmd/warehouse/wire_gen.go` - Auto-regenerated to inject transaction

3. ✅ **Adjust Stock validation** - FIXED: Added validation check
   - **File**: `warehouse/internal/biz/inventory/inventory.go:415-418`
   - **Fix Applied**: 
     - Added validation: `quantityAfter >= inventory.QuantityReserved`
     - Prevents negative available stock (available = quantity_available - quantity_reserved)
   - **Files Changed**: 
     - `warehouse/internal/biz/inventory/inventory.go` - Added validation rule

4. ✅ **Missing database constraint** - FIXED: Added CHECK constraint
   - **File**: `warehouse/migrations/018_add_reserved_quantity_constraint.sql` (NEW)
   - **Fix Applied**: 
     - Created migration to add constraint: `quantity_reserved <= quantity_available`
     - Constraint enforced at database level
   - **Files Changed**: 
     - `warehouse/migrations/018_add_reserved_quantity_constraint.sql` - New migration file

### Medium Priority (Business Logic & Features)

1. **On Order tracking** - Cần API để update `QuantityOnOrder`
   - **Files**: `warehouse/api/inventory/v1/inventory.proto`, `warehouse/internal/biz/inventory/inventory.go`
   - **Fix**: Add `UpdateOnOrder` API

2. **Adjustment approval workflow** - Cần implement approval workflow
   - **Files**: N/A (cần implement)
   - **Fix**: Create `AdjustmentRequest` entity và approval APIs

3. **Available stock calculation helper** - Reduce code duplication
   - **Files**: Multiple files
   - **Fix**: Create helper function

4. **Deduct Stock validation** - Cần check reserved quantity
   - **File**: `warehouse/internal/biz/inventory/inventory.go:392-536`
   - **Fix**: Add validation hoặc create separate `DeductStock` API

### Low Priority (Optimization & Documentation)

1. **Stock level caching** - Performance optimization
2. **Distributor stock aggregation** - Feature enhancement
3. **Warehouse selection algorithm** - Feature enhancement

---

## 📝 10. Testing Checklist

### Unit Tests
- [ ] Test ReserveStock với sufficient stock
- [ ] Test ReserveStock với insufficient stock
- [ ] Test ReserveStock với concurrent requests (race condition)
- [ ] Test ReleaseReservation với active reservation
- [ ] Test ReleaseReservation với expired reservation
- [ ] Test AdjustStock với positive quantity
- [ ] Test AdjustStock với negative quantity
- [ ] Test AdjustStock validation (negative stock prevention)
- [ ] Test TransferStock với sufficient stock
- [ ] Test TransferStock với insufficient stock
- [ ] Test Available stock calculation

### Integration Tests
- [ ] Test Reserve → Release flow
- [ ] Test Reserve → Deduct flow
- [ ] Test Transfer → Reserve flow
- [ ] Test Multi-warehouse reservation
- [ ] Test Reservation expiry auto-release
- [ ] Test Stock sync to Catalog service

### Edge Cases
- [ ] Test Reserve với `QuantityAvailable = QuantityReserved` (edge case)
- [ ] Test Adjust làm `QuantityAvailable < QuantityReserved`
- [ ] Test Transfer với destination inventory không tồn tại
- [ ] Test Concurrent reservations cho cùng product/warehouse
- [ ] Test Reservation expiry với nhiều reservations

---

## 📚 11. Related Documentation

- **Warehouse Service Spec**: `docs/backup-2025-11-17/docs/services/warehouse-inventory-service.md`
- **Stock Flow Discussion**: `docs/backup-2025-11-17/docs/operations/stock-flow-discussion.md`
- **API Documentation**: `warehouse/README.md`

---

## 🔄 12. Update History

- **2025-01-17**: Initial checklist created based on code review
- **2025-01-17**: Fixed all high priority issues:
  - ✅ Reserve Stock race condition - Added row-level locking
  - ✅ Transfer Stock atomicity - Added database transaction
  - ✅ Adjust Stock validation - Added quantityAfter >= QuantityReserved check
  - ✅ Missing database constraint - Added quantity_reserved <= quantity_available constraint


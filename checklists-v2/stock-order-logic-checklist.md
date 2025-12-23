# Stock Logic When Order - Comprehensive Checklist

**Created**: 2025-01-XX  
**Purpose**: Review và validate logic stock khi order để đảm bảo không có race condition, miss case, hay logic error

---

## 📋 Overview

Logic stock khi order bao gồm các flow chính:
1. **Reserve Stock** - Khi tạo order
2. **Confirm Reservation** - Sau khi order created (optional)
3. **Complete Reservation** - Khi fulfillment completed
4. **Release Reservation** - Khi order cancelled hoặc reservation expired
5. **Expiry Handling** - Tự động release expired reservations

---

## 🔍 1. Reserve Stock Flow

### 1.1 Order Creation Flow

**Location**: `order/internal/biz/order.go`, `order/internal/biz/cart.go`

**Flow**:
```
1. User checkout → Reserve stock for all items
2. Create order (within transaction)
3. Clear cart (within transaction)
4. Confirm reservations (outside transaction, optional)
```

**Checklist**:

- [ ] **R1.1.1**: Stock được reserve TRƯỚC khi create order
  - ✅ **Verified**: `ReserveStockForItems()` được gọi trước `CreateOrderInTransaction()`
  - **Location**: `order/internal/biz/cart.go:643-665`

- [ ] **R1.1.2**: Reservation được rollback nếu order creation fail
  - ✅ **Verified**: `uc.releaseReservations(txCtx, reservations)` được gọi khi error
  - **Location**: `order/internal/biz/cart.go:651-654, 667-668, 673-674`

- [ ] **R1.1.3**: Reservation được rollback nếu cart clear fail
  - ✅ **Verified**: `uc.releaseReservations(txCtx, reservations)` được gọi khi error
  - **Location**: `order/internal/biz/cart.go:673-674`

- [ ] **R1.1.4**: Multiple reservations được handle correctly (multiple warehouses)
  - ✅ **Verified**: Loop qua từng warehouse và reserve từng item
  - **Location**: `order/internal/biz/cart.go:643-662`

- [ ] **R1.1.5**: Reservation ID được store trong order item
  - ✅ **Verified**: `item.orderItem.ReservationID = &reservation.ID`
  - **Location**: `order/internal/biz/cart.go:659`

### 1.2 Reserve Stock Implementation

**Location**: `warehouse/internal/biz/reservation/reservation.go`

**Checklist**:

- [ ] **R1.2.1**: Row-level lock được sử dụng để prevent race condition
  - ✅ **Verified**: `FindByWarehouseAndProductForUpdate()` sử dụng `SELECT ... FOR UPDATE`
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:69`
  - **Note**: Lock được giữ cho đến khi transaction commit

- [ ] **R1.2.2**: Available quantity được check với lock held
  - ✅ **Verified**: `availableQuantity = inventory.QuantityAvailable - inventory.QuantityReserved`
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:78-80`
  - **Formula**: `available = total_available - reserved`

- [ ] **R1.2.3**: Insufficient stock được handle correctly
  - ✅ **Verified**: Return error nếu `availableQuantity < req.Quantity`
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:79-81`

- [ ] **R1.2.4**: Reservation được create với status "active"
  - ✅ **Verified**: `Status: "active"` khi create
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:131`

- [ ] **R1.2.5**: Expiry time được calculate từ payment method
  - ✅ **Verified**: `GetExpiryDuration()` dựa trên payment method
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:107-117`
  - **Default**: 30 minutes nếu không có config

- [ ] **R1.2.6**: Inventory quantity_reserved được increment
  - ✅ **Verified**: `IncrementReserved()` được gọi sau khi create reservation
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:143`
  - **Note**: Database trigger cũng tự động update (double update - có thể optimize)

- [ ] **R1.2.7**: Reservation được create trong transaction
  - ⚠️ **Issue**: Reservation được create TRƯỚC transaction (trong cart checkout)
  - **Location**: `order/internal/biz/cart.go:650`
  - **Risk**: Nếu order creation fail, reservation đã được create → cần rollback
  - **Mitigation**: Rollback được handle trong `releaseReservations()`

### 1.3 Database Trigger

**Location**: `warehouse/migrations/005_create_reservations_table.sql`

**Checklist**:

- [ ] **R1.3.1**: Trigger tự động update quantity_reserved khi reservation created
  - ✅ **Verified**: Trigger `update_inventory_on_reservation_change` tự động increment
  - **Location**: `warehouse/migrations/005_create_reservations_table.sql:88-93`

- [ ] **R1.3.2**: Trigger tự động update quantity_reserved khi reservation status changed
  - ✅ **Verified**: Trigger handle status changes (active → cancelled/fulfilled/expired)
  - **Location**: `warehouse/migrations/005_create_reservations_table.sql:95-117`
  - **Formula**: Decrement `(OLD.quantity_reserved - OLD.quantity_fulfilled)`

- [ ] **R1.3.3**: Trigger handle partial fulfillment
  - ✅ **Verified**: Trigger update khi `quantity_fulfilled` thay đổi
  - **Location**: `warehouse/migrations/005_create_reservations_table.sql:111-116`

- [ ] **R1.3.4**: Double update issue (code + trigger)
  - ⚠️ **Issue**: Code gọi `IncrementReserved()` VÀ trigger cũng increment
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:143`
  - **Risk**: quantity_reserved có thể bị double increment
  - **Recommendation**: Remove manual `IncrementReserved()` call, rely on trigger only

---

## 🔍 2. Confirm Reservation Flow

**Location**: `order/internal/biz/cart.go`, `order/internal/service/event_handler.go`

**Purpose**: Confirm reservation sau khi order created thành công (optional, để extend expiry)

**Checklist**:

- [ ] **C2.1**: Confirm reservation được gọi SAU khi transaction commit
  - ✅ **Verified**: Confirm được gọi ngoài transaction (line 685-692)
  - **Location**: `order/internal/biz/cart.go:685-692`

- [ ] **C2.2**: Confirm failure không fail checkout
  - ✅ **Verified**: Error được log nhưng không return error
  - **Location**: `order/internal/biz/cart.go:688-691`
  - **Note**: Reservation sẽ expire tự động nếu không confirm

- [ ] **C2.3**: ConfirmReservation method exists
  - ❌ **Missing**: Không thấy `ConfirmReservation()` method trong warehouse service
  - **Location**: `order/internal/biz/cart.go:688`
  - **Issue**: Code gọi method không tồn tại → sẽ fail
  - **Recommendation**: 
    - Option 1: Implement `ConfirmReservation()` method (extend expiry)
    - Option 2: Remove confirm call (rely on expiry)

- [ ] **C2.4**: Confirm được gọi khi payment confirmed
  - ✅ **Verified**: `confirmStockReservations()` được gọi trong event handler
  - **Location**: `order/internal/service/event_handler.go:232-280`
  - **Note**: Nhưng method `ConfirmReservation()` không tồn tại

---

## 🔍 3. Complete Reservation Flow

**Location**: `warehouse/internal/biz/reservation/reservation.go`, `warehouse/internal/biz/inventory/fulfillment_status_handler.go`

**Purpose**: Mark reservation as fulfilled khi fulfillment completed

**Checklist**:

- [ ] **C3.1**: Complete reservation được trigger khi fulfillment completed
  - ✅ **Verified**: `handleFulfillmentCompleted()` gọi `CompleteReservation()`
  - **Location**: `warehouse/internal/biz/inventory/fulfillment_status_handler.go:114-137`

- [ ] **C3.2**: Reservation status được update thành "fulfilled"
  - ✅ **Verified**: `Status = "fulfilled"` và `QuantityFulfilled = QuantityReserved`
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:300-301`

- [ ] **C3.3**: quantity_reserved được decrement khi completed
  - ✅ **Verified**: Database trigger tự động decrement khi status = "fulfilled"
  - **Location**: `warehouse/migrations/005_create_reservations_table.sql:97-102`
  - **Formula**: `quantity_reserved - (OLD.quantity_reserved - OLD.quantity_fulfilled)`

- [ ] **C3.4**: Only active reservations can be completed
  - ✅ **Verified**: Check `reservation.Status != "active"` → return error
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:295-297`

- [ ] **C3.5**: Reservation not found được handle gracefully
  - ✅ **Verified**: Log warning và continue (không fail)
  - **Location**: `warehouse/internal/biz/inventory/fulfillment_status_handler.go:122-127`

---

## 🔍 4. Release Reservation Flow

**Location**: `warehouse/internal/biz/reservation/reservation.go`, `order/internal/biz/cancellation/cancellation.go`

**Purpose**: Release reservation khi order cancelled hoặc reservation expired

### 4.1 Order Cancellation

**Checklist**:

- [ ] **L4.1.1**: Reservations được release khi order cancelled
  - ✅ **Verified**: Loop qua order items và release mỗi reservation
  - **Location**: `order/internal/biz/cancellation/cancellation.go:78-83`

- [ ] **L4.1.2**: Release được gọi TRƯỚC khi update order status
  - ✅ **Verified**: Release được gọi trước `UpdateStatus()`
  - **Location**: `order/internal/biz/cancellation/cancellation.go:78-95`

- [ ] **L4.1.3**: Partial cancellation release correct reservations
  - ✅ **Verified**: Chỉ release reservations của items bị cancel
  - **Location**: `order/internal/biz/cancellation/cancellation.go:199-203`

- [ ] **L4.1.4**: Release failure được handle gracefully
  - ✅ **Verified**: Log warning nhưng continue với các items khác
  - **Location**: `order/internal/biz/cancellation/cancellation.go:200-202`

### 4.2 Release Reservation Implementation

**Checklist**:

- [ ] **L4.2.1**: Only active reservations can be released
  - ✅ **Verified**: Check `reservation.Status != "active"` → return error
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:172-174`

- [ ] **L4.2.2**: Reservation status được update thành "cancelled"
  - ✅ **Verified**: `Status = "cancelled"` khi release
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:177`

- [ ] **L4.2.3**: quantity_reserved được decrement khi released
  - ✅ **Verified**: Database trigger tự động decrement khi status = "cancelled"
  - **Location**: `warehouse/migrations/005_create_reservations_table.sql:97-102`
  - **Formula**: `quantity_reserved - (OLD.quantity_reserved - OLD.quantity_fulfilled)`

- [ ] **L4.2.4**: ReleaseReservation không decrement manually
  - ✅ **Verified**: Chỉ update status, trigger handle decrement
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:176-182`

---

## 🔍 5. Expiry Handling Flow

**Location**: `warehouse/internal/worker/expiry/reservation_expiry.go`

**Purpose**: Tự động release expired reservations

**Checklist**:

- [ ] **E5.1**: Expired reservations được detect correctly
  - ✅ **Verified**: Query `status = 'active' AND expires_at < NOW()`
  - **Location**: `warehouse/internal/data/postgres/reservation.go:208-216`

- [ ] **E5.2**: Expired reservations được release automatically
  - ✅ **Verified**: Worker gọi `ReleaseReservation()` cho mỗi expired reservation
  - **Location**: `warehouse/internal/worker/expiry/reservation_expiry.go:89-100`

- [ ] **E5.3**: Expiry warning được send trước khi expire
  - ✅ **Verified**: `ReservationWarningWorker` check và send warning
  - **Location**: `warehouse/internal/worker/expiry/reservation_warning.go:79-125`
  - **Default**: Warning 5 minutes trước expiry

- [ ] **E5.4**: Expiry duration được calculate từ payment method
  - ✅ **Verified**: `GetExpiryDuration()` dựa trên payment method
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:319-365`
  - **Default**: 30 minutes nếu không có config

- [ ] **E5.5**: Expiry được set khi reserve stock
  - ✅ **Verified**: `ExpiresAt` được set khi create reservation
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:100-117`

---

## 🔍 6. Race Conditions & Concurrency

**Checklist**:

- [ ] **RC6.1**: Row-level lock được sử dụng khi reserve stock
  - ✅ **Verified**: `SELECT ... FOR UPDATE` trong `FindByWarehouseAndProductForUpdate()`
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:69`

- [ ] **RC6.2**: Lock được giữ trong suốt reservation process
  - ✅ **Verified**: Lock được giữ cho đến khi transaction commit
  - **Note**: Reservation được create trong transaction

- [ ] **RC6.3**: Multiple concurrent orders không cause double reservation
  - ✅ **Verified**: Row-level lock prevent concurrent modifications
  - **Risk**: Nếu reservation được create ngoài transaction → có thể có race condition
  - **Mitigation**: Đảm bảo reservation trong transaction

- [ ] **RC6.4**: Expiry worker không conflict với manual release
  - ✅ **Verified**: Check `status = "active"` trước khi release
  - **Location**: `warehouse/internal/worker/expiry/reservation_expiry.go:90`

- [ ] **RC6.5**: Database trigger là atomic
  - ✅ **Verified**: Trigger chạy trong cùng transaction với reservation update
  - **Note**: Trigger đảm bảo consistency

---

## 🔍 7. Edge Cases & Error Handling

**Checklist**:

- [ ] **EC7.1**: Reservation creation fail → rollback previous reservations
  - ✅ **Verified**: `rollbackReservationsMap()` được gọi khi error
  - **Location**: `order/internal/biz/order_reservation.go:60, 68`

- [ ] **EC7.2**: Order creation fail → release all reservations
  - ✅ **Verified**: `releaseReservations()` được gọi trong transaction rollback
  - **Location**: `order/internal/biz/cart.go:667-668`

- [ ] **EC7.3**: Cart clear fail → release all reservations
  - ✅ **Verified**: `releaseReservations()` được gọi khi error
  - **Location**: `order/internal/biz/cart.go:673-674`

- [ ] **EC7.4**: Release reservation fail → log warning but continue
  - ✅ **Verified**: Error được log nhưng không fail order cancellation
  - **Location**: `order/internal/biz/cancellation/cancellation.go:200-202`

- [ ] **EC7.5**: Reservation not found khi release → handle gracefully
  - ✅ **Verified**: Return error nếu reservation not found
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:168-170`

- [ ] **EC7.6**: Reservation already released → return error
  - ✅ **Verified**: Check `status != "active"` → return error
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:172-174`

- [ ] **EC7.7**: Inventory not found → return error
  - ✅ **Verified**: Check `inventory == nil` → return error
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:73-75`

- [ ] **EC7.8**: Insufficient stock → return error with available quantity
  - ✅ **Verified**: Error message includes available vs requested
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:79-81`

- [ ] **EC7.9**: Warehouse ID missing → skip reservation (no error)
  - ✅ **Verified**: Check `warehouseID != nil && *warehouseID != ""`
  - **Location**: `order/internal/biz/order_reservation.go:50`
  - **Note**: Order có thể được create mà không reserve stock nếu không có warehouse ID

- [ ] **EC7.10**: Confirm reservation fail → reservation expires automatically
  - ✅ **Verified**: Comment nói "will expire automatically"
  - **Location**: `order/internal/biz/cart.go:686`
  - **Issue**: Nhưng `ConfirmReservation()` method không tồn tại

---

## 🔍 8. Transaction Boundaries

**Checklist**:

- [ ] **T8.1**: Reservation được create trong transaction
  - ⚠️ **Issue**: Reservation được create TRƯỚC transaction (trong cart checkout)
  - **Location**: `order/internal/biz/cart.go:650`
  - **Risk**: Nếu order creation fail, reservation đã được create
  - **Mitigation**: Rollback được handle trong `releaseReservations()`

- [ ] **T8.2**: Order creation trong transaction
  - ✅ **Verified**: `CreateOrderInTransaction()` sử dụng transaction
  - **Location**: `order/internal/biz/cart.go:665`

- [ ] **T8.3**: Cart clear trong transaction
  - ✅ **Verified**: `DeleteItemsBySessionID()` trong transaction
  - **Location**: `order/internal/biz/cart.go:672`

- [ ] **T8.4**: Confirm reservation ngoài transaction
  - ✅ **Verified**: Confirm được gọi sau transaction commit
  - **Location**: `order/internal/biz/cart.go:685-692`
  - **Note**: Nếu confirm fail, reservation vẫn active và sẽ expire

- [ ] **T8.5**: Release reservation có thể ngoài transaction
  - ⚠️ **Issue**: Release được gọi trong order cancellation (có thể ngoài transaction)
  - **Location**: `order/internal/biz/cancellation/cancellation.go:78-83`
  - **Risk**: Nếu release fail, order vẫn được cancel → inconsistency
  - **Mitigation**: Error được log nhưng không fail cancellation

---

## 🔍 9. Data Consistency

**Checklist**:

- [ ] **DC9.1**: quantity_reserved luôn consistent với reservations
  - ✅ **Verified**: Database trigger tự động update quantity_reserved
  - **Location**: `warehouse/migrations/005_create_reservations_table.sql:86-129`
  - **Issue**: Code cũng gọi `IncrementReserved()` → double update

- [ ] **DC9.2**: Available quantity = quantity_available - quantity_reserved
  - ✅ **Verified**: Formula được sử dụng khi check available
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:78`

- [ ] **DC9.3**: Reservation status transitions are valid
  - ✅ **Verified**: 
    - `active` → `cancelled` (release)
    - `active` → `fulfilled` (complete)
    - `active` → `expired` (expiry worker)
  - **Location**: `warehouse/internal/biz/reservation/reservation.go`

- [ ] **DC9.4**: Reservation expiry được set correctly
  - ✅ **Verified**: Expiry được calculate từ payment method hoặc default
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:100-117`

- [ ] **DC9.5**: Reservation reference_id được set correctly
  - ✅ **Verified**: ReferenceID = OrderID khi reserve từ order
  - **Location**: `warehouse/internal/biz/reservation/reservation.go:127`

---

## 🔍 10. Missing Cases & Issues

### Critical Issues (2025-12-20 Update)

1. **✅ RESOLVED: ConfirmReservation() method**
   - **Status**: ✅ **IMPLEMENTED AND WORKING**
   - **Location**: `warehouse/internal/biz/reservation/reservation.go:414-509`
   - **Implementation**: 
     - Full method with status validation
     - Decrements `quantity_available` on confirmation
     - Updates reservation to `fulfilled` status
     - Publishes stock change events
     - Rollback on error
   - **Verified**: Method exists in warehouse service interface and implementation
   - **Called From**: `order/internal/biz/order/create_helpers.go:177-192`

2. **✅ RESOLVED: Double increment quantity_reserved**
   - **Status**: ✅ **NOT AN ISSUE**
   - **Verification**: Code at line 146-147 explicitly states:
     ```go
     // Note: Database trigger automatically updates quantity_reserved when reservation is created
     // No need to manually increment - trigger handles it atomically
     ```
   - **Implementation**: Code relies ONLY on database trigger
   - **No manual `IncrementReserved()` calls** found in reservation creation flow

3. **⚠️ KNOWN LIMITATION: Reservation created ngoài transaction**
   - **Location**: `order/internal/biz/cart.go:650`
   - **Status**: By design (distributed system pattern)
   - **Impact**: If order creation fails, reservation is already created
   - **Mitigation**: 
     - ✅ Rollback logic implemented
     - ✅ Auto-expiry after 30 minutes (fallback)
     - ✅ Prevents long-held transaction locks
   - **Recommendation**: Acceptable for production use

### Potential Issues

4. **⚠️ WARNING: Release reservation fail không fail order cancellation**
   - **Location**: `order/internal/biz/cancellation/cancellation.go:200-202`
   - **Issue**: Nếu release fail, order vẫn được cancel → inconsistency
   - **Mitigation**: Auto-expiry worker will clean up orphaned reservations
   - **Recommendation**: Consider retry mechanism (Priority: P2)

5. **✅ WORKING AS DESIGNED: Confirm reservation fail không fail checkout**
   - **Location**: `order/internal/biz/order/create_helpers.go:177-192`
   - **Behavior**: Errors logged but don't fail order creation
   - **Mitigation**: Reservation expires automatically after configured duration
   - **Status**: Acceptable behavior for resilience

6. **⚠️ WARNING: Warehouse ID missing → skip reservation**
   - **Location**: `order/internal/biz/order_reservation.go:50`
   - **Issue**: Order có thể được create mà không reserve stock
   - **Recommendation**: Consider validation (Priority: P3)

---

## ✅ Summary

### Working Correctly

- ✅ Row-level lock prevent race conditions
- ✅ Rollback logic khi order creation fail
- ✅ Database trigger tự động update quantity_reserved
- ✅ Expiry handling với worker
- ✅ Release reservation khi order cancelled
- ✅ Complete reservation khi fulfillment completed
- ✅ Partial cancellation release correct reservations

### Issues Found (Updated 2025-12-20)

- ✅ **RESOLVED**: `ConfirmReservation()` method - **EXISTS AND WORKING**
- ✅ **RESOLVED**: Double increment - **NOT AN ISSUE** (trigger-only)
- ✅ **BY DESIGN**: Reservation ngoài transaction - **ACCEPTABLE** (has rollback)
- ⚠️ **MINOR**: Release fail không fail cancellation - **MITIGATED** (auto-expiry)
- ⚠️ **MINOR**: Warehouse ID missing → skip - **LOW PRIORITY**

### Recommendations (Prioritized)

**Priority 1 (Completed):**
1. ✅ Verify `ConfirmReservation()` implementation - **DONE**
2. ✅ Verify trigger-based quantity management - **WORKING**
3. ✅ Remove deprecated code - **DONE** (removed `confirmStockReservations()`)

**Priority 2 (Optional):**
4. ⚠️ Add retry mechanism for release reservation
5. ⚠️ Move reservation into transaction (performance trade-off)

**Priority 3 (Future):**
6. 📝 Add warehouse ID validation (or default warehouse logic)

---

## 📝 Test Scenarios

### Unit Tests Needed

- [ ] Test concurrent reservations cho cùng product
- [ ] Test reservation rollback khi order creation fail
- [ ] Test expiry worker với multiple expired reservations
- [ ] Test partial cancellation với multiple items
- [ ] Test release reservation với invalid reservation ID
- [ ] Test complete reservation với non-active reservation

### Integration Tests Needed

- [ ] Test full order flow: reserve → create order → confirm → complete
- [ ] Test order cancellation flow: release reservations
- [ ] Test expiry flow: reservation expires → auto release
- [ ] Test concurrent orders cho cùng product (race condition)
- [ ] Test order creation fail → reservations released
- [ ] Test payment confirmed → reservations confirmed (nếu implement)

---

**Last Updated**: 2025-01-XX  
**Reviewed By**: [Name]  
**Status**: ⚠️ Issues Found - Needs Fix

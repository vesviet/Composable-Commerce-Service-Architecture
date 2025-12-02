# Returns & Exchanges và Order Editing - Implementation Status

**Created:** 2025-12-01  
**Status:** 🟡 In Progress (Foundation Complete)  
**Priority:** 🔴 Critical

---

## ✅ Đã Hoàn Thành

### 1. Database Schema
- ✅ **Migration 018**: `return_requests` và `return_items` tables
- ✅ **Migration 019**: `order_edit_history` table
- ✅ Schema hỗ trợ cả return và exchange
- ✅ Tracking đầy đủ: approval workflow, shipping, inspection, restocking, refund

### 2. Models
- ✅ `model.ReturnRequest` - Return/exchange request model
- ✅ `model.ReturnItem` - Return item model
- ✅ `model.OrderEditHistory` - Order edit history model

### 3. Repository Layer
- ✅ `ReturnRequestRepo` interface và PostgreSQL implementation
- ✅ `ReturnItemRepo` interface và PostgreSQL implementation
- ✅ `OrderEditHistoryRepo` interface và PostgreSQL implementation
- ✅ Đã thêm vào `data.ProviderSet` cho Wire injection

### 4. Business Logic (Partial)
- ✅ `ReturnUsecase` với các methods:
  - ✅ `CreateReturnRequest` - Tạo return/exchange request
  - ✅ `GetReturnRequest` - Lấy return request
  - ✅ `ListReturnRequests` - List return requests với filters
  - ✅ `UpdateReturnRequestStatus` - Update status (approval workflow)
  - ✅ `generateReturnNumber` - Generate return number (RET-YYMM-000001)
- ✅ Validation:
  - ✅ Return window check (30 days)
  - ✅ Order status validation (must be delivered)
  - ✅ Return type validation (return/exchange)
  - ✅ Return reason validation
  - ✅ Status transition validation

### 5. Proto Definitions
- ✅ `CreateReturnRequest` RPC và messages
- ✅ `GetReturnRequest` RPC và messages
- ✅ `ListReturnRequests` RPC và messages
- ✅ `UpdateReturnRequestStatus` RPC và messages
- ✅ `UpdateOrder` RPC và messages (cho order editing)

---

## 🟡 Đang Làm

### 1. Service Layer (gRPC/HTTP Handlers)
- [ ] Implement `CreateReturnRequest` handler
- [ ] Implement `GetReturnRequest` handler
- [ ] Implement `ListReturnRequests` handler
- [ ] Implement `UpdateReturnRequestStatus` handler
- [ ] Implement `UpdateOrder` handler (cho order editing)

### 2. Order Editing Business Logic
- [ ] `OrderEditUsecase` với `UpdateOrder` method
- [ ] Validation: chỉ cho phép edit draft/pending orders
- [ ] Handle reservation updates (release old, reserve new)
- [ ] Handle payment authorization updates (void old, authorize new)
- [ ] Recalculate totals sau khi edit
- [ ] Revalidate inventory sau khi edit
- [ ] Revalidate promo codes sau khi edit
- [ ] Track edit history

---

## ❌ Chưa Làm

### 1. Return Processing Logic
- [ ] Generate return shipping label (integration với Shipping Service)
- [ ] Track return shipment (carrier, tracking number)
- [ ] Receive return items (warehouse integration)
- [ ] Inspect returned items (quality check)
- [ ] Restock returned items (warehouse integration)
- [ ] Process refund (Payment Service integration)
- [ ] Process exchange (create new order for replacement)
- [ ] Return restocking fee calculation
- [ ] Return shipping cost handling

### 2. Exchange Processing
- [ ] Exchange item selection validation
- [ ] Exchange price difference handling (upgrade/downgrade)
- [ ] Exchange fulfillment (create new shipment)
- [ ] Exchange return tracking

### 3. Integration Points
- [ ] Warehouse service integration (receive returns, restock)
- [ ] Payment service integration (process refunds)
- [ ] Shipping service integration (return labels, tracking)
- [ ] Notification service integration (return status updates)

### 4. Stock Return on Refund
- [ ] Return stock to inventory when refund processed
- [ ] Handle damaged items (don't restock)
- [ ] Handle used items (restock as used/refurbished)
- [ ] Handle missing items (no restock, charge customer)

### 5. Order Editing Features
- [ ] Add items to order
- [ ] Remove items from order
- [ ] Update item quantities
- [ ] Update shipping address
- [ ] Update payment method
- [ ] Update promo codes
- [ ] Edit history tracking

---

## 📋 Next Steps

### Priority 1: Complete Service Layer
1. Implement gRPC/HTTP handlers cho returns
2. Implement `OrderEditUsecase` và handler cho order editing
3. Register handlers trong `server/http.go` và `service/order.go`

### Priority 2: Return Processing
1. Integrate với Warehouse Service (restock)
2. Integrate với Payment Service (refund)
3. Integrate với Shipping Service (return labels)

### Priority 3: Order Editing Integration
1. Integrate với Warehouse (reservation updates)
2. Integrate với Payment (authorization updates)
3. Implement edit history tracking

---

## 🔧 Technical Notes

### Return Number Generation
- Format: `RET-{YYMM}-{000001}` (e.g., `RET-2501-000001`)
- Uses sequence generator với date prefix
- Sequence key: `return_request_{YYMM}`

### Order Item ID Type
- **Note**: `OrderItem.ID` là `int64` (BIGINT), không phải UUID
- `ReturnItem.OrderItemID` cũng là `int64` để match
- Proto field `order_item_id` là `int64`

### Return Window
- Default: 30 days từ delivery date
- Configurable qua `return_window_days` field
- Checked khi create return request

### Status Transitions
- `pending` → `approved`, `rejected`, `cancelled`
- `approved` → `processing`, `cancelled`
- `processing` → `completed`, `cancelled`
- `rejected`, `completed`, `cancelled` → terminal states

---

**Last Updated:** 2025-12-01  
**Next Review:** After service layer implementation


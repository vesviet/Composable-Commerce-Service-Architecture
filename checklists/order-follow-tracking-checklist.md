# Order Follow & Tracking Flow - Review Checklist

## 📋 Tổng Quan

Checklist này review logic "follow order" (theo dõi đơn hàng) và order tracking flow, bao gồm order status transitions, fulfillment flow, event-driven communication, và integration points giữa các services.

**Last Updated**: 2025-01-17  
**Status**: ✅ High priority issues fixed

---

## 🏗️ 1. Order Status Flow

### 1.1. Order Status Definitions

**Order Status Enum** (from `order/internal/constants/constants.go`):
- `draft` - Checkout in progress, not yet submitted
- `pending` - Order created, awaiting payment
- `confirmed` - Payment confirmed, fraud check passed
- `processing` - Order in fulfillment (picking/packing)
- `shipped` - Order shipped, in transit
- `delivered` - Order successfully delivered
- `cancelled` - Order cancelled (any stage)
- `refunded` - Order refunded after delivery
- `failed` - Order failed (payment, verification)

#### ✅ Implemented
- [x] Order status constants defined
- [x] Order status transitions defined
- [x] Status validation logic implemented
- [x] Status history tracking

#### ⚠️ Gaps & Issues
- [ ] **Order status "processing" vs fulfillment status**: Order status "processing" có nghĩa là gì?
  - **Current**: Order status "processing" = Order in fulfillment
  - **Question**: Có cần sync với fulfillment status không? (planning, picking, packing)
  - **Recommendation**: 
    - Option 1: Order "processing" = generic fulfillment status (không sync chi tiết)
    - Option 2: Order status sync với fulfillment status (processing → picked → packed → shipped)
  - **Files**: `order/internal/constants/constants.go:76`, `fulfillment/internal/constants/fulfillment_status.go`

### 1.2. Order Status Transitions

**Allowed Transitions** (from `order/internal/constants/constants.go:85-95`):
```
draft → pending, cancelled
pending → confirmed, cancelled, failed
confirmed → processing, cancelled
processing → shipped, cancelled
shipped → delivered, cancelled
delivered → refunded
cancelled → (terminal)
refunded → (terminal)
failed → pending (can retry)
```

#### ✅ Implemented
- [x] Status transition validation: `ValidateStatusTransition` in `order/internal/biz/status/status.go:201`
- [x] Status transition map defined
- [x] Terminal statuses identified (cancelled, refunded)

#### ⚠️ Gaps & Issues
- [ ] **Missing transition validation in some places**: Không phải tất cả code paths đều validate transitions
  - **Current**: `StatusUsecase.UpdateStatus` validates, nhưng có thể có direct updates
  - **Recommendation**: Ensure all status updates go through `StatusUsecase.UpdateStatus`
  - **Files**: `order/internal/biz/status/status.go:52-182`

---

## 📦 2. Fulfillment Status Flow

### 2.1. Fulfillment Status Definitions

**Fulfillment Status Enum** (from `fulfillment/internal/constants/fulfillment_status.go:8-19`):
- `pending` - Fulfillment created, awaiting planning
- `planning` - Warehouse assigned, preparing for picking
- `picking` - Items being collected from warehouse
- `picked` - All items collected, ready for packaging
- `packing` - Items being packaged for shipment
- `packed` - Items packaged, ready for shipping
- `ready` - Package ready, label generated
- `shipped` - Package handed to carrier
- `completed` - Fulfillment completed
- `cancelled` - Fulfillment cancelled

#### ✅ Implemented
- [x] Fulfillment status constants defined
- [x] Fulfillment status transitions defined
- [x] Status validation logic: `ValidateStatusTransition` in `fulfillment/internal/constants/fulfillment_status.go:115`
- [x] Terminal statuses identified (completed, cancelled)
- [x] Cancellable status check: `IsCancellable()` method

### 2.2. Fulfillment Status Transitions

**Allowed Transitions** (from `fulfillment/internal/constants/fulfillment_status.go:57-91`):
```
pending → planning, cancelled
planning → picking, cancelled
picking → picked, cancelled
picked → packing, cancelled
packing → packed, cancelled
packed → ready, cancelled
ready → shipped, cancelled
shipped → completed
completed → (terminal)
cancelled → (terminal)
```

#### ✅ Implemented
- [x] Status transition validation implemented
- [x] Status transition map defined
- [x] Helper methods: `CanTransitionTo()`, `GetAllowedTransitions()`

---

## 🔄 3. Order → Fulfillment Flow

### 3.1. Order Confirmed → Fulfillment Created

**Flow**:
1. Order Service: Order status → `confirmed`
2. Order Service: Publish `order.status_changed` event (status = "confirmed")
3. Fulfillment Service: Listen to `order.status_changed` event
4. Fulfillment Service: Create fulfillment(s) from order
5. Fulfillment Service: Start planning immediately
6. Fulfillment Service: Publish `fulfillment.status_changed` event (status = "pending")

#### ✅ Implemented
- [x] Order Service publishes `order.status_changed` event: `order/internal/biz/status/status.go:176`
- [x] Fulfillment Service listens to order status: `fulfillment/internal/biz/fulfillment/order_status_handler.go:13`
- [x] Fulfillment creation from order: `fulfillment/internal/biz/fulfillment/fulfillment.go:134-216`
- [x] Multi-warehouse support: `CreateFromOrderMulti` creates one fulfillment per warehouse
- [x] Auto-start planning: `fulfillment/internal/biz/fulfillment/order_status_handler.go:94-101`

#### ⚠️ Gaps & Issues
- [ ] **Order status "processing" not synced with fulfillment**: Order status "processing" không được update từ fulfillment status
  - **Current**: 
    - Order Service: `shipment.created` event → Order status "processing"
    - Fulfillment Service: Publish `fulfillment.status_changed` events (pending, planning, picking, etc.)
  - **Issue**: Order status "processing" không reflect fulfillment progress (planning, picking, packing)
  - **Recommendation**: 
    - Option 1: Order Service listen to `fulfillment.status_changed` events và update order status accordingly
    - Option 2: Keep order "processing" generic, chỉ sync khi shipped/delivered
  - **Files**: 
    - `order/internal/service/event_handler.go:239-297` (HandleShipmentCreated)
    - `fulfillment/internal/events/fulfillment_events.go` (FulfillmentStatusChangedEvent)

- [ ] **Missing fulfillment status → order status mapping**: Không có clear mapping giữa fulfillment status và order status
  - **Current**: 
    - Fulfillment: pending, planning, picking, picked, packing, packed, ready, shipped, completed
    - Order: draft, pending, confirmed, processing, shipped, delivered, cancelled, refunded, failed
  - **Recommendation**: Define mapping:
    - Fulfillment "pending" → Order "confirmed" (already handled)
    - Fulfillment "planning" → Order "processing"?
    - Fulfillment "picking" → Order "processing"?
    - Fulfillment "picked" → Order "processing"?
    - Fulfillment "packed" → Order "processing"?
    - Fulfillment "ready" → Order "processing"?
    - Fulfillment "shipped" → Order "shipped" (need to implement)
    - Fulfillment "completed" → Order "delivered"? (need to implement)
  - **Files**: `order/internal/service/event_handler.go`

---

## 📡 4. Event-Driven Communication

### 4.1. Order Service Events

**Events Published by Order Service**:
- `order.status_changed` - Unified event for all order status changes
  - **Publisher**: `order/internal/biz/status/status.go:176`
  - **Payload**: Full order details including items, customer, payment info
  - **Subscribers**: Fulfillment Service, Notification Service, Customer Service, etc.

#### ✅ Implemented
- [x] Order status changed event published: `order/internal/biz/status/status.go:146-179`
- [x] Event includes full order details (items, customer, payment)
- [x] Event includes warehouse_id for multi-warehouse orders

#### ⚠️ Gaps & Issues
- [ ] **Order Service không listen to fulfillment events**: Order Service chỉ listen to shipment/delivery events
  - **Current**: 
    - Order Service listens: `payment.confirmed`, `payment.failed`, `shipment.created`, `delivery.confirmed`
    - Order Service does NOT listen: `fulfillment.status_changed`
  - **Issue**: Order status không sync với fulfillment progress
  - **Recommendation**: Add handler for `fulfillment.status_changed` events
  - **Files**: `order/internal/service/event_handler.go`

### 4.2. Fulfillment Service Events

**Events Published by Fulfillment Service**:
- `fulfillment.status_changed` - Unified event for all fulfillment status changes
  - **Publisher**: `fulfillment/internal/biz/fulfillment/fulfillment.go:254, 357, 454, 499, 638`
  - **Payload**: Fulfillment details including order_id, warehouse_id, items, status
  - **Subscribers**: Warehouse Service (for stock management), Order Service (should be), Notification Service

#### ✅ Implemented
- [x] Fulfillment status changed event published: `fulfillment/internal/events/fulfillment_events.go:20-42`
- [x] Event includes fulfillment details (order_id, warehouse_id, items, status)
- [x] Event published on all status transitions

#### ⚠️ Gaps & Issues
- [ ] **Fulfillment events không được Order Service consume**: Order Service không listen to fulfillment events
  - **Current**: Fulfillment publishes events, nhưng Order Service không subscribe
  - **Recommendation**: Add subscription in Order Service for `fulfillment.status_changed`
  - **Files**: `order/internal/service/event_handler.go:38-69` (DaprSubscribeHandler)

### 4.3. Warehouse Service Events

**Events Consumed by Warehouse Service**:
- `fulfillment.status_changed` (status = "pending") → Create outbound transaction + reservation
- `fulfillment.status_changed` (status = "completed") → Complete reservation
- `fulfillment.status_changed` (status = "cancelled") → Create inbound transaction + release reservation

#### ✅ Implemented
- [x] Warehouse Service listens to fulfillment events: `warehouse/internal/biz/inventory/fulfillment_status_handler.go:15`
- [x] Stock allocation on fulfillment created: `warehouse/internal/biz/inventory/fulfillment_status_handler.go:41-110`
- [x] Stock release on fulfillment completed: `warehouse/internal/biz/inventory/fulfillment_status_handler.go:112-138`
- [x] Stock release on fulfillment cancelled: `warehouse/internal/biz/inventory/fulfillment_status_handler.go:140-202`

---

## 🔍 5. Order Tracking & Status Sync

### 5.1. Order Status Updates from External Events

**Current Event Handlers in Order Service**:
1. `HandlePaymentConfirmed` → Order status "confirmed"
2. `HandlePaymentFailed` → Order status "cancelled"
3. `HandleShipmentCreated` → Order status "processing"
4. `HandleDeliveryConfirmed` → Order status "delivered"

#### ✅ Implemented
- [x] Payment confirmed handler: `order/internal/service/event_handler.go:120-178`
- [x] Payment failed handler: `order/internal/service/event_handler.go:180-237`
- [x] Shipment created handler: `order/internal/service/event_handler.go:239-297`
- [x] Delivery confirmed handler: `order/internal/service/event_handler.go:299-357`

#### ⚠️ Gaps & Issues
- [ ] **Missing fulfillment status handler**: Order Service không có handler cho fulfillment status changes
  - **Current**: Order Service chỉ update status từ shipment/delivery events
  - **Issue**: Order status "processing" không reflect fulfillment progress
  - **Recommendation**: Add `HandleFulfillmentStatusChanged` handler
  - **Files**: `order/internal/service/event_handler.go`

- [ ] **Order status "processing" too generic**: Order status "processing" được set từ shipment.created, không từ fulfillment progress
  - **Current**: 
    - Order "processing" = Shipment created (from shipping service)
    - Fulfillment có nhiều status: planning, picking, picked, packing, packed, ready
  - **Issue**: Customer không biết order đang ở giai đoạn nào (picking, packing, etc.)
  - **Recommendation**: 
    - Option 1: Keep order "processing" generic, customer xem fulfillment status riêng
    - Option 2: Sync order status với fulfillment status (processing → picked → packed → shipped)
  - **Files**: `order/internal/service/event_handler.go:279-283`

### 5.2. Fulfillment Status → Order Status Mapping

**Proposed Mapping**:
```
Fulfillment Status → Order Status
pending → confirmed (already handled)
planning → processing? (not implemented)
picking → processing? (not implemented)
picked → processing? (not implemented)
packing → processing? (not implemented)
packed → processing? (not implemented)
ready → processing? (not implemented)
shipped → shipped (need to implement)
completed → delivered? (need to implement)
cancelled → cancelled (already handled)
```

#### ⚠️ Gaps & Issues
- [ ] **No mapping implementation**: Không có code map fulfillment status → order status
  - **Current**: Order status không sync với fulfillment status
  - **Recommendation**: Implement mapping logic
  - **Files**: `order/internal/service/event_handler.go` (new handler needed)

---

## 🔗 6. Integration Points

### 6.1. Order Service → Fulfillment Service

**Current Integration**:
- Order Service publishes `order.status_changed` (status = "confirmed")
- Fulfillment Service listens and creates fulfillment

#### ✅ Implemented
- [x] Order Service publishes order status changed event
- [x] Fulfillment Service subscribes to order status changed
- [x] Fulfillment creation from order event

### 6.2. Fulfillment Service → Order Service

**Current Integration**:
- Fulfillment Service publishes `fulfillment.status_changed` events
- Order Service does NOT subscribe to fulfillment events

#### ⚠️ Gaps & Issues
- [ ] **Missing subscription**: Order Service không subscribe to fulfillment events
  - **Current**: Fulfillment publishes events, nhưng Order Service không listen
  - **Recommendation**: Add subscription in Order Service
  - **Files**: `order/internal/service/event_handler.go:38-69`

### 6.3. Fulfillment Service → Warehouse Service

**Current Integration**:
- Fulfillment Service publishes `fulfillment.status_changed` events
- Warehouse Service subscribes and manages stock

#### ✅ Implemented
- [x] Warehouse Service subscribes to fulfillment events
- [x] Stock allocation on fulfillment created
- [x] Stock release on fulfillment completed/cancelled

### 6.4. Shipping Service → Order Service

**Current Integration**:
- Shipping Service publishes `shipment.created` and `delivery.confirmed` events
- Order Service subscribes and updates order status

#### ✅ Implemented
- [x] Order Service subscribes to shipment events
- [x] Order status updated from shipment events

---

## 📊 7. Status History & Tracking

### 7.1. Order Status History

**Current Implementation**:
- Order status history tracked in `order_status_history` table
- History created on every status change: `order/internal/biz/status/status.go:129`

#### ✅ Implemented
- [x] Status history creation: `order/internal/biz/status/status.go:206-218`
- [x] Status history retrieval: `order/internal/biz/status/status.go:185-196`
- [x] History includes: from_status, to_status, reason, notes, changed_by, changed_at

### 7.2. Fulfillment Status History

**Current Implementation**:
- Fulfillment status tracked in `fulfillments` table (status field)
- Status history not explicitly tracked (only current status)

#### ⚠️ Gaps & Issues
- [ ] **No fulfillment status history table**: Fulfillment status changes không được track trong history table
  - **Current**: Chỉ có current status trong `fulfillments.status`
  - **Recommendation**: Consider adding `fulfillment_status_history` table nếu cần audit trail
  - **Files**: `fulfillment/migrations/001_create_fulfillments_table.sql`

---

## 🎯 8. Priority Issues Summary

### High Priority (Order Tracking & Sync)

1. ✅ **Order Service không listen to fulfillment events** - FIXED: Added subscription
   - **File**: `order/internal/service/event_handler.go:38-69`
   - **Fix Applied**: 
     - Added `TopicFulfillmentStatusChanged` constant
     - Added subscription in `DaprSubscribeHandler`
     - Added route registration in HTTP server
   - **Files Changed**: 
     - `order/internal/constants/constants.go` - Added topic constant
     - `order/internal/service/event_handler.go` - Added subscription
     - `order/internal/server/http.go` - Added route registration

2. ✅ **Missing fulfillment status → order status mapping** - FIXED: Implemented mapping logic
   - **File**: `order/internal/service/event_handler.go:393-554`
   - **Fix Applied**: 
     - Added `HandleFulfillmentStatusChanged` handler
     - Implemented `mapFulfillmentStatusToOrderStatus` function
     - Implemented `shouldSkipStatusUpdate` function to prevent unnecessary updates
     - Mapping logic:
       - `pending` → No update (order already confirmed)
       - `planning`, `picking`, `picked`, `packing`, `packed`, `ready` → `processing`
       - `shipped` → `shipped`
       - `completed` → `delivered`
       - `cancelled` → `cancelled`
     - Smart status update: Checks current order status before updating to avoid invalid transitions
   - **Files Changed**: 
     - `order/internal/service/event_handler.go` - Added handler, mapping logic, and status check

3. ⚠️ **Order status "processing" too generic** - PARTIALLY FIXED: Status sync implemented
   - **File**: `order/internal/service/event_handler.go:477-498`
   - **Status**: ✅ Order status now syncs with fulfillment progress
   - **Current**: Order status "processing" reflects fulfillment progress (planning → picking → packing → ready)
   - **Note**: Order status "processing" is generic but now updates based on fulfillment status
   - **Future Enhancement**: Consider exposing fulfillment status in order API response for more detail
   - **Files Changed**: 
     - `order/internal/service/event_handler.go` - Mapping logic implemented

### Medium Priority (Status History & Audit)

1. **No fulfillment status history table** - Missing audit trail
   - **File**: `fulfillment/migrations/001_create_fulfillments_table.sql`
   - **Issue**: Fulfillment status changes không được track trong history
   - **Fix**: Add `fulfillment_status_history` table nếu cần audit trail
   - **Impact**: Khó debug và audit fulfillment status changes

2. **Status transition validation gaps** - Some code paths bypass validation
   - **File**: `order/internal/biz/status/status.go:52-182`
   - **Issue**: Không phải tất cả status updates đều validate transitions
   - **Fix**: Ensure all status updates go through `StatusUsecase.UpdateStatus`
   - **Impact**: Data consistency risk

---

## 📝 9. Related Documentation

- **Fulfillment Order Flow**: `docs/backup-2025-11-17/docs/api-flows/fulfillment-order-flow.md`
- **Fulfillment Process**: `docs/processes/fulfillment-process.md`
- **Order Service Spec**: `docs/docs/services/order-service.md`
- **Fulfillment Service Spec**: `docs/docs/services/fulfillment-service.md`

---

## 🔄 10. Update History

- **2025-01-17**: Initial checklist created based on code review
- **2025-01-17**: Fixed high priority issues:
  - ✅ Order Service now listens to fulfillment events - Added subscription and handler
  - ✅ Fulfillment status → order status mapping implemented
  - ✅ Order status syncs with fulfillment progress (planning/picking/packing → processing, shipped → shipped, completed → delivered)


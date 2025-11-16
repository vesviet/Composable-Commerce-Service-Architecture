# Stock Flow Discussion - Đơn Giản

## Overview
Thảo luận về flow quản lý stock (tồn kho) trong hệ thống e-commerce, tập trung vào các luồng cơ bản và business logic.

---

## Stock States (Trạng Thái Tồn Kho)

### 1. Available Stock (Tồn kho khả dụng)
- **Quantity Available**: Số lượng hàng có sẵn, có thể bán ngay
- **Formula**: `Available = Total Stock - Reserved - On Order`
- **Usage**: Customer có thể mua, order service có thể reserve

### 2. Reserved Stock (Tồn kho đã giữ chỗ)
- **Quantity Reserved**: Số lượng đã được reserve cho orders
- **Purpose**: Giữ chỗ tạm thời khi customer checkout
- **Duration**: Thường expire sau 15-30 phút nếu order không được confirm
- **Usage**: Order service reserve khi checkout, release khi cancel

### 3. On Order Stock (Tồn kho đang đặt hàng)
- **Quantity On Order**: Số lượng đã đặt mua từ supplier nhưng chưa nhận
- **Purpose**: Track hàng đang trên đường về warehouse
- **Usage**: Procurement service update khi tạo purchase order

### 4. Total Stock (Tổng tồn kho)
- **Formula**: `Total = Available + Reserved + On Order`
- **Note**: Không phải field riêng, là tổng của 3 fields trên

---

## Core Stock Operations

### 1. Reserve Stock (Giữ chỗ tồn kho)
**Khi nào:**
- Customer checkout cart → Order created
- Order status: `pending` → `confirmed`

**Flow:**
```
1. Order Service → ReserveStock API
   - Warehouse ID
   - Product ID / SKU
   - Quantity
   - Reference: Order ID
   - Expires At: 30 minutes

2. Warehouse Service checks:
   - Available stock >= Quantity?
   - If YES → Reserve
   - If NO → Reject

3. Update Inventory:
   - Quantity Available: -Quantity
   - Quantity Reserved: +Quantity

4. Create Reservation record:
   - Reservation ID
   - Order ID
   - Product ID
   - Quantity
   - Expires At
   - Status: "active"

5. Return Reservation ID to Order Service

6. Order Service stores Reservation ID in Order Item
```

**Business Rules:**
- ✅ Reserve phải có available stock
- ✅ Reserve có thể expire (auto-release sau 30 phút)
- ✅ Một order có thể có nhiều reservations (mỗi item một reservation)
- ✅ Reservation có thể release manually hoặc auto-expire

---

### 2. Release Reservation (Hủy giữ chỗ)
**Khi nào:**
- Order cancelled
- Order expired (không thanh toán)
- Payment failed
- Customer timeout (30 phút không confirm)

**Flow:**
```
1. Order Service → ReleaseReservation API
   - Reservation ID (hoặc Order ID để release all)

2. Warehouse Service:
   - Find reservation(s)
   - Validate: Reservation exists và active
   - Update Inventory:
     - Quantity Available: +Quantity
     - Quantity Reserved: -Quantity
   - Update Reservation:
     - Status: "released"
     - Released At: timestamp

3. Return success to Order Service
```

**Business Rules:**
- ✅ Release phải có reservation active
- ✅ Release có thể release một reservation hoặc tất cả reservations của order
- ✅ Auto-release khi reservation expire
- ✅ Release không thể undo (phải reserve lại nếu cần)

---

### 3. Deduct Stock (Trừ tồn kho)
**Khi nào:**
- Order shipped (fulfillment completed)
- Package picked from warehouse
- Outbound transaction

**Flow:**
```
1. Fulfillment Service → AdjustStock API (hoặc DeductStock)
   - Warehouse ID
   - Product ID / SKU
   - Quantity (negative: -quantity)
   - Reason: "shipped" hoặc "fulfilled"
   - Reference: Order ID, Fulfillment ID

2. Warehouse Service:
   - Find inventory
   - Validate: Reserved >= Quantity (đã reserve rồi mới deduct)
   - Update Inventory:
     - Quantity Reserved: -Quantity
     - Quantity Available: -Quantity (nếu chưa reserve thì chỉ trừ available)
   - Create StockTransaction:
     - Type: "outbound"
     - Reason: "shipped"
     - Quantity: -Quantity
     - Reference: Order ID

3. Return updated inventory
```

**Business Rules:**
- ✅ Deduct phải có reserved stock (đã reserve trước)
- ✅ Deduct tạo transaction record (audit trail)
- ✅ Deduct không thể negative (phải có đủ stock)
- ✅ Deduct thường đi kèm với release reservation

---

### 4. Add Stock (Thêm tồn kho)
**Khi nào:**
- Purchase order received
- Return from customer
- Stock adjustment (manual)
- Transfer from another warehouse

**Flow:**
```
1. Procurement Service / Admin → AdjustStock API
   - Warehouse ID
   - Product ID / SKU
   - Quantity (positive: +quantity)
   - Reason: "purchase", "return", "adjustment", "transfer_in"
   - Reference: Purchase Order ID, Return ID, etc.

2. Warehouse Service:
   - Find inventory (hoặc create nếu chưa có)
   - Update Inventory:
     - Quantity Available: +Quantity
   - Create StockTransaction:
     - Type: "inbound"
     - Reason: reason provided
     - Quantity: +Quantity
     - Reference: Reference ID

3. Return updated inventory
```

**Business Rules:**
- ✅ Add stock tạo transaction record
- ✅ Add stock có thể tạo inventory record mới (nếu product chưa có trong warehouse)
- ✅ Add stock có thể update "On Order" → "Available" (khi receive purchase order)

---

### 5. Transfer Stock (Chuyển kho)
**Khi nào:**
- Transfer từ warehouse A → warehouse B
- Rebalancing inventory
- Fulfillment từ warehouse khác

**Flow:**
```
1. Admin / Fulfillment Service → TransferStock API
   - From Warehouse ID
   - To Warehouse ID
   - Product ID / SKU
   - Quantity
   - Reason: "transfer", "rebalance"

2. Warehouse Service:
   - Validate: From warehouse có đủ available stock
   - Update From Warehouse:
     - Quantity Available: -Quantity
     - Create Transaction: Type "outbound", Reason "transfer_out"
   - Update To Warehouse:
     - Quantity Available: +Quantity
     - Create Transaction: Type "inbound", Reason "transfer_in"
   - Link 2 transactions (same transfer ID)

3. Return both updated inventories
```

**Business Rules:**
- ✅ Transfer phải có available stock ở warehouse nguồn
- ✅ Transfer tạo 2 transactions (outbound + inbound)
- ✅ Transfer có thể fail nếu destination warehouse không có inventory record (phải create trước)
- ✅ Transfer có thể async (shipment tracking)

---

### 6. Adjust Stock (Điều chỉnh tồn kho)
**Khi nào:**
- Cycle count (kiểm kê)
- Stock correction (sửa lỗi)
- Damage / Loss
- Theft

**Flow:**
```
1. Admin / Warehouse Staff → AdjustStock API
   - Warehouse ID
   - Product ID / SKU
   - Quantity Change (có thể + hoặc -)
   - Reason: "cycle_count", "correction", "damage", "theft"
   - Notes: Mô tả lý do

2. Warehouse Service:
   - Find inventory
   - Validate: Quantity After >= 0 (không được âm)
   - Update Inventory:
     - Quantity Available: +QuantityChange
   - Create StockTransaction:
     - Type: "adjustment"
     - Reason: reason provided
     - Quantity: QuantityChange
     - Notes: notes provided

3. Return updated inventory
```

**Business Rules:**
- ✅ Adjust có thể tăng hoặc giảm stock
- ✅ Adjust phải có reason và notes (audit trail)
- ✅ Adjust không được làm stock âm
- ✅ Adjust thường cần authorization (chỉ admin/warehouse staff)

---

## Stock Flow Scenarios

### Scenario 1: Customer Checkout Flow (Multi-Warehouse)
```
1. Customer adds items to cart
   - Item A (Warehouse 1): Available = 100
   - Item B (Warehouse 2): Available = 50

2. Customer clicks "Checkout" (Payment: Credit Card)
   - Order Service → ReserveStock(Item A, Warehouse 1, quantity: 2)
     - Reservation expires in 30 min (credit card)
     - Warehouse 1: Available = 98, Reserved = 2
   - Order Service → ReserveStock(Item B, Warehouse 2, quantity: 1)
     - Reservation expires in 30 min (credit card)
     - Warehouse 2: Available = 49, Reserved = 1
   - Order có 2 reservations (1 per warehouse)

3. Customer confirms payment
   - Order status: "pending" → "confirmed"
   - Reservations vẫn active (không expire nữa vì đã paid)

4. Fulfillment Service creates fulfillments
   - Fulfillment 1 (Warehouse 1): Item A
   - Fulfillment 2 (Warehouse 2): Item B
   - Mỗi fulfillment chỉ có 1 warehouse

5. Fulfillment picks items
   - Fulfillment 1 → DeductStock(Warehouse 1, quantity: 2)
     - Warehouse 1: Reserved = 0, Available = 98
   - Fulfillment 2 → DeductStock(Warehouse 2, quantity: 1)
     - Warehouse 2: Reserved = 0, Available = 49

6. Order shipped
   - Reservations auto-release hoặc manual release
   - Stock: Both warehouses updated
```

---

### Scenario 2: Order Cancelled Flow (Multi-Warehouse)
```
1. Order created, stock reserved (2 warehouses)
   - Warehouse 1: Available = 98, Reserved = 2
   - Warehouse 2: Available = 49, Reserved = 1

2. Customer cancels order (hoặc payment timeout)
   - Order Service → ReleaseReservation(all reservation_ids)
   - Warehouse Service:
     - Release Warehouse 1: Available = 100, Reserved = 0
     - Release Warehouse 2: Available = 50, Reserved = 0
     - Update Reservations: Status = "released"
   - Stock: Both warehouses restored
```

### Scenario 2b: Reservation Expiry (Payment Method: COD)
```
1. Order created with COD payment
   - Reservation expires in 24 hours (COD config)
   - Warehouse: Available = 98, Reserved = 2

2. Customer chưa thanh toán sau 24 giờ
   - Background job detects expired reservation
   - Auto-release: Available = 100, Reserved = 0
   - Send notification to customer: "Reservation expired, please re-order"
   - Order status: "cancelled" (nếu chưa paid)
```

---

### Scenario 3: Purchase Order Received Flow
```
1. Purchase Order created
   - Stock: Available = 100, On Order = 0

2. Procurement Service → UpdateOnOrder(quantity: 50)
   - Stock: Available = 100, On Order = 50

3. Goods received at warehouse
   - Procurement Service → AdjustStock(quantity: +50, reason: "purchase")
   - Warehouse Service:
     - Update: Available = 150, On Order = 0
     - Create Transaction: "inbound", "purchase"
   - Stock: Available = 150, On Order = 0
```

---

### Scenario 4: Stock Transfer Flow
```
1. Warehouse A: Available = 100
   Warehouse B: Available = 20

2. Admin transfers 30 units A → B
   - TransferStock(from: A, to: B, quantity: 30)

3. Warehouse Service:
   - Warehouse A:
     - Available = 100 - 30 = 70
     - Transaction: "outbound", "transfer_out"
   - Warehouse B:
     - Available = 20 + 30 = 50
     - Transaction: "inbound", "transfer_in"

4. Result:
   - Warehouse A: Available = 70
   - Warehouse B: Available = 50
```

---

### Scenario 5: Cycle Count (Kiểm kê) Flow - Với Approval
```
1. Warehouse staff counts physical stock
   - Physical count: 95 units
   - System shows: Available = 100

2. Staff → CreateAdjustmentRequest(quantity: -5, reason: "cycle_count")
   - Warehouse Service:
     - Create Adjustment Request: Status = "pending"
     - Chờ approval từ Warehouse Manager
     - Notification sent to Manager

3. Manager reviews and approves
   - Manager → ApproveAdjustment(adjustment_id)
   - Warehouse Service:
     - Update Request: Status = "approved"
     - Execute adjustment: Available = 100 - 5 = 95
     - Create Transaction: "adjustment", "cycle_count"
     - Update Request: Status = "completed"
   - Notification sent to Staff: "Adjustment approved and executed"

4. Stock: Available = 95 (matches physical count)
```

### Scenario 5b: Adjustment Rejected
```
1. Staff → CreateAdjustmentRequest(quantity: -50, reason: "damage")
   - Request status: "pending"
   - Requires 2 approvals (critical adjustment)

2. Manager 1 approves
   - Request status: "pending" (vẫn chờ Manager 2)

3. Manager 2 reviews and rejects
   - Manager 2 → RejectAdjustment(adjustment_id, reason: "Need investigation")
   - Warehouse Service:
     - Update Request: Status = "rejected"
     - Stock không thay đổi
   - Notification sent to Staff: "Adjustment rejected: Need investigation"
```

---

## Key Business Rules Summary

### Stock Availability
- ✅ **Available Stock** = Total - Reserved - On Order
- ✅ **Cannot reserve** nếu Available < Quantity
- ✅ **Cannot deduct** nếu Reserved < Quantity (nếu đã reserve)
- ✅ **Cannot transfer** nếu Available < Quantity

### Reservation Rules
- ✅ **Reservation expires** sau 15-30 phút (configurable)
- ✅ **Auto-release** khi reservation expire
- ✅ **One reservation per order item** (hoặc per order)
- ✅ **Reservation ID** stored in Order Item

### Transaction Rules
- ✅ **Every stock change** creates transaction record
- ✅ **Transaction types**: inbound, outbound, transfer, adjustment, reservation, release
- ✅ **Transaction includes**: before, change, after quantities
- ✅ **Transaction audit trail**: who, when, why, reference

### Negative Stock Prevention
- ✅ **Cannot have negative** Available stock
- ✅ **Cannot have negative** Reserved stock
- ✅ **Cannot deduct** more than available
- ✅ **Validation** before every operation

---

## Integration Points

### Order Service ↔ Warehouse Service
- **Reserve Stock**: Order checkout → Reserve (multiple warehouses)
- **Release Reservation**: Order cancel → Release (all reservations)
- **Reservation Expiry**: Config theo payment method
- **Deduct Stock**: Order shipped → Deduct (optional, nếu không dùng reservation)

### Fulfillment Service ↔ Warehouse Service
- **Check Availability**: Before creating fulfillment (1 warehouse per fulfillment)
- **Deduct Stock**: When package picked (from assigned warehouse)
- **Transfer Stock**: Fulfillment from different warehouse (nếu cần)

### Procurement Service ↔ Warehouse Service
- **Update On Order**: When purchase order created
- **Add Stock**: When goods received
- **Adjust Stock**: When receiving partial shipment

### Admin / Warehouse Staff ↔ Warehouse Service
- **Create Adjustment Request**: Manual corrections (requires approval)
- **Approve/Reject Adjustment**: Approval workflow
- **Transfer Stock**: Warehouse rebalancing
- **View Reports**: Stock levels, movements, reservations

### Notification Service ↔ Warehouse Service
- **Low Stock Alert**: Available < Reorder Point
- **Out of Stock Alert**: Available = 0
- **Overstock Alert**: Available > Max Stock Level
- **Reservation Expiry Warning**: 5 phút trước khi expire
- **Adjustment Approval Request**: Notify manager khi có request
- **Adjustment Approved/Rejected**: Notify staff khi có kết quả

---

## Clarifications & Business Rules

### 1. Multi-Warehouse Rules
- ✅ **1 Order có thể fulfill từ nhiều warehouses**
  - Mỗi order item có thể từ warehouse khác nhau
  - Mỗi item có thể có reservation riêng ở warehouse riêng
- ✅ **1 Fulfillment chỉ có 1 warehouse**
  - Một fulfillment chỉ handle items từ 1 warehouse
  - Nếu order có items từ nhiều warehouses → tạo nhiều fulfillments (1 fulfillment per warehouse)
- ✅ **Transfer Stock giữa warehouses**
  - Có thể transfer để rebalance inventory
  - Transfer tạo 2 transactions: outbound (source) + inbound (destination)

### 2. Reservation Expiry - Config theo Payment Method
- ✅ **Reservation expiry phụ thuộc payment method**
  - **COD (Cash on Delivery)**: 24-48 giờ (customer có thời gian chuẩn bị tiền)
  - **Bank Transfer**: 2-4 giờ (chờ chuyển khoản)
  - **Credit Card / E-Wallet**: 15-30 phút (thanh toán ngay)
  - **Installment**: 1-2 giờ (cần approval)
- ✅ **Config trong Warehouse Service**
  ```yaml
  reservation_expiry:
    cod: 24h
    bank_transfer: 4h
    credit_card: 30m
    e_wallet: 15m
    installment: 2h
  ```
- ✅ **Auto-release khi expire**
  - System tự động release reservation khi hết hạn
  - Background job check và release expired reservations

### 3. Stock Adjustments - Cần Approval
- ✅ **Adjustment Workflow**
  1. Warehouse Staff tạo adjustment request
  2. Request chờ approval (status: "pending")
  3. Admin/Manager approve hoặc reject
  4. Nếu approve → Execute adjustment
  5. Nếu reject → Cancel request, notify staff
- ✅ **Approval Rules**
  - Small adjustments (< 10 units): Warehouse Manager
  - Medium adjustments (10-100 units): Operations Manager
  - Large adjustments (> 100 units): System Admin
  - Critical adjustments (damage, theft): Require 2 approvals
- ✅ **Adjustment States**
  - `pending` - Chờ approval
  - `approved` - Đã approve, chờ execute
  - `rejected` - Bị reject
  - `completed` - Đã execute
  - `cancelled` - Bị cancel

### 4. Stock Alerts - Qua Notification Service
- ✅ **Alert Types**
  - **Low Stock Alert**: Khi Available < Reorder Point
  - **Out of Stock Alert**: Khi Available = 0
  - **Overstock Alert**: Khi Available > Max Stock Level
  - **Expiring Stock Alert**: Khi sản phẩm sắp hết hạn (nếu có expiry date)
  - **Reservation Expiry Alert**: Khi reservation sắp expire (warning trước 5 phút)
- ✅ **Notification Channels**
  - Email: Gửi cho warehouse manager, procurement team
  - SMS: Gửi cho warehouse staff (nếu critical)
  - Push Notification: Gửi cho admin app
  - In-App Notification: Hiển thị trong admin dashboard
- ✅ **Alert Frequency**
  - Real-time: Khi stock thay đổi (immediate alert)
  - Daily Summary: Tổng hợp alerts trong ngày
  - Weekly Report: Báo cáo tổng hợp tuần
- ✅ **Alert Recipients**
  - Warehouse Manager: Tất cả alerts của warehouse
  - Procurement Team: Low stock, out of stock alerts
  - Admin: Critical alerts (theft, damage, large adjustments)
  - Warehouse Staff: Reservation expiry warnings

---

## Implementation Requirements

### 1. Multi-Warehouse Support
- [ ] Order Service: Support multiple reservations per order (1 per warehouse)
- [ ] Fulfillment Service: Create multiple fulfillments (1 per warehouse)
- [ ] Warehouse Service: Handle reservations from multiple warehouses
- [ ] Transfer Stock: Support warehouse-to-warehouse transfers

### 2. Reservation Expiry Configuration
- [ ] Config file: Payment method → Expiry duration mapping
- [ ] Reservation creation: Use expiry based on payment method
- [ ] Background job: Auto-release expired reservations
- [ ] Notification: Warning 5 phút trước khi expire

### 3. Adjustment Approval Workflow
- [ ] Adjustment Request entity: Status (pending, approved, rejected, completed)
- [ ] Approval rules: Small/Medium/Large adjustments
- [ ] Approval API: Approve/Reject endpoints
- [ ] Notification: Request created, approved, rejected

### 4. Stock Alerts via Notification
- [ ] Alert triggers: Low stock, out of stock, overstock, expiry
- [ ] Notification Service integration: Send alerts
- [ ] Alert recipients: Warehouse manager, procurement, admin
- [ ] Alert frequency: Real-time, daily summary, weekly report

## Next Steps

1. ✅ **Clarify Business Rules** - Đã clarify (multi-warehouse, expiry config, approval, alerts)
2. **Define API Contracts** - Chi tiết request/response formats với các requirements mới
3. **Design Database Schema** - Tables, indexes, constraints (adjustment requests, approval workflow)
4. **Plan Implementation** - Phases, priorities, dependencies
5. **Create Test Scenarios** - Edge cases, error handling (multi-warehouse, approval workflow)

---

## Summary

**Core Operations:**
- Reserve Stock (giữ chỗ)
- Release Reservation (hủy giữ chỗ)
- Deduct Stock (trừ tồn kho)
- Add Stock (thêm tồn kho)
- Transfer Stock (chuyển kho)
- Adjust Stock (điều chỉnh)

**Key States:**
- Available (khả dụng)
- Reserved (đã giữ chỗ)
- On Order (đang đặt hàng)

**Main Flow:**
- Checkout → Reserve → Confirm → Deduct → Shipped
- Cancel → Release
- Purchase → Add Stock
- Transfer → Outbound + Inbound

**Critical Rules:**
- Không được âm stock
- Mọi thay đổi đều có transaction record
- Reservation có thể expire
- Validation trước mọi operation


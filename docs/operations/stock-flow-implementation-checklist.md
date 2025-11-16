# Stock Flow Implementation Checklist

## Overview
Checklist đầy đủ cho việc implement stock flow với multi-warehouse support, reservation expiry config, adjustment approval workflow, và stock alerts.

---

## Phase 1: Multi-Warehouse Support

### 1.1 Order Service - Multiple Reservations per Order
- [x] **Update Order Model**
  - [x] File: `order/internal/model/order.go`
  - [x] Verify: Order Items có `WarehouseID` field ✅
  - [x] Verify: Order Items có `ReservationID` field ✅
  - [ ] Add: `Reservations` array (optional, để track all reservations) - **NOT NEEDED** (track via ReservationID in items)

- [x] **Update Checkout Flow**
  - [x] File: `order/internal/biz/cart.go` (CheckoutCart method)
  - [x] Current: Reserve stock cho tất cả items ✅
  - [x] Update: Group items by warehouse ✅
  - [x] Update: Reserve stock per warehouse (multiple reservations) ✅
  - [x] Update: Store reservation ID in each order item ✅
  - [ ] Test: Order với items từ 2 warehouses

- [x] **Update Reserve Stock Logic**
  - [x] File: `order/internal/biz/cart.go`
  - [x] Loop through cart items ✅
  - [x] Group by warehouse_id ✅
  - [x] For each warehouse:
     - [x] Call `ReserveStock(warehouse_id, product_id, quantity)` ✅
     - [x] Store reservation_id in order item ✅
  - [x] Handle partial failures: Release all reservations nếu một reservation fail ✅

- [x] **Update Release Reservation Logic**
  - [x] File: `warehouse/internal/biz/reservation/reservation.go` - `ReleaseReservationsByOrderID` ✅
  - [x] File: `warehouse/internal/observer/order_status_changed/warehouse_sub.go` - Auto-release khi order cancelled ✅
  - [x] Update: Release all reservations của order ✅
  - [x] Update: Handle multiple warehouses ✅
  - [ ] Test: Cancel order với multiple reservations

- [x] **Update Order Status Change Handler**
  - [x] File: `warehouse/internal/observer/order_status_changed/warehouse_sub.go` ✅
  - [x] Update: Handle multiple reservations khi order status changes ✅
  - [x] Update: Release all reservations khi order cancelled ✅

- [ ] **Test Multi-Warehouse Checkout**
  - [ ] Test: Cart với items từ 2 warehouses
  - [ ] Test: Checkout tạo 2 reservations
  - [ ] Test: Cancel order releases cả 2 reservations
  - [x] Test: Partial reservation failure (rollback all) ✅

### 1.2 Fulfillment Service - Multiple Fulfillments per Order
- [x] **Update Fulfillment Creation Logic**
  - [x] File: `fulfillment/internal/biz/fulfillment/fulfillment.go`
  - [x] Current: Tạo 1 fulfillment per order ✅
  - [x] Update: Group order items by warehouse ✅
  - [x] Update: Tạo 1 fulfillment per warehouse ✅
  - [x] Update: Mỗi fulfillment chỉ có items từ 1 warehouse ✅

- [x] **Update Fulfillment Model**
  - [x] File: `fulfillment/internal/model/fulfillment.go`
  - [x] Verify: `WarehouseID` field exists ✅
  - [x] Verify: `OrderID` field exists ✅
  - [x] Add: `FulfillmentNumber` (unique per fulfillment) ✅

- [x] **Update CreateFulfillment API**
  - [x] File: `fulfillment/internal/service/fulfillment_service.go`
  - [x] Update: Accept order_id ✅
  - [x] Update: Group items by warehouse ✅
  - [x] Update: Create multiple fulfillments ✅
  - [x] Return: Array of fulfillments (via CreateFromOrderMulti) ✅

- [x] **Update Fulfillment Status Flow**
  - [x] File: `fulfillment/internal/biz/fulfillment/fulfillment.go`
  - [x] Update: Mỗi fulfillment có status riêng ✅
  - [ ] Update: Order status = "completed" khi tất cả fulfillments completed (CẦN CHECK)
  - [ ] Update: Handle partial fulfillment completion (CẦN CHECK)

- [ ] **Test Multiple Fulfillments**
  - [ ] Test: Order với 2 warehouses → 2 fulfillments
  - [ ] Test: Mỗi fulfillment có warehouse riêng
  - [ ] Test: Fulfillment status independent
  - [ ] Test: Order completion khi all fulfillments done

### 1.3 Warehouse Service - Multi-Warehouse Reservations
- [x] **Update ReserveStock API**
  - [x] File: `warehouse/internal/service/inventory_service.go`
  - [x] Current: Reserve stock cho 1 warehouse ✅
  - [x] Verify: API đã support warehouse_id parameter ✅
  - [x] Update: Handle multiple reservations per order ✅
  - [x] Update: Return reservation_id ✅

- [x] **Update ReleaseReservation API**
  - [x] File: `warehouse/internal/biz/reservation/reservation.go`
  - [x] Current: Release 1 reservation ✅
  - [x] Add: `ReleaseReservationsByOrderID` method ✅
  - [x] Update: Release all reservations của order ✅
  - [ ] Test: Release multiple reservations

- [x] **Update Reservation Model**
  - [x] File: `warehouse/internal/model/inventory.go`
  - [x] Verify: `ReferenceID` field (order_id) ✅
  - [x] Verify: `ReferenceType` field ("order") ✅
  - [x] Add index: `idx_reservations_order_id` ✅ (migration 014)

- [x] **Update Reservation Repository**
  - [x] File: `warehouse/internal/repository/reservation/reservation.go`
  - [x] Add: `FindByOrderID(ctx, orderID)` method ✅
  - [x] Add: `ReleaseByOrderID(ctx, orderID)` method ✅ (via ReleaseReservationsByOrderID)
  - [x] Update: Batch release reservations ✅

- [ ] **Test Multi-Warehouse Reservations**
  - [ ] Test: Reserve stock từ 2 warehouses
  - [ ] Test: Release all reservations của order
  - [ ] Test: Reservation expiry per warehouse

### 1.4 Transfer Stock Between Warehouses
- [ ] **Update TransferStock API**
  - [ ] File: `warehouse/internal/service/inventory_service.go`
  - [ ] Current: TransferStock method exists
  - [ ] Verify: From/To warehouse validation
  - [ ] Update: Create 2 transactions (outbound + inbound)
  - [ ] Update: Link transactions với transfer_id

- [ ] **Update Transfer Logic**
  - [ ] File: `warehouse/internal/biz/inventory/inventory.go`
  - [ ] Validate: Source warehouse có đủ available stock
  - [ ] Validate: Destination warehouse exists
  - [ ] Create: Outbound transaction (source)
  - [ ] Create: Inbound transaction (destination)
  - [ ] Link: Both transactions với same transfer_id

- [ ] **Update StockTransaction Model**
  - [ ] File: `warehouse/internal/model/inventory.go`
  - [ ] Verify: `FromWarehouseID` field
  - [ ] Verify: `ToWarehouseID` field
  - [ ] Add: `TransferID` field (to link outbound + inbound)

- [ ] **Test Transfer Stock**
  - [ ] Test: Transfer từ warehouse A → B
  - [ ] Test: Validate insufficient stock
  - [ ] Test: Create 2 linked transactions
  - [ ] Test: Update both warehouse inventories

---

## Phase 2: Reservation Expiry Configuration

### 2.1 Configuration File
- [x] **Create Reservation Expiry Config**
  - [x] File: `warehouse/configs/config.yaml`
  - [x] Add section:
    ```yaml
    reservation:
      expiry:
        cod: 24h
        bank_transfer: 4h
        credit_card: 30m
        e_wallet: 15m
        installment: 2h
        default: 30m
      warning_before_expiry: 5m
    ```
    ✅

- [x] **Update Config Struct**
  - [x] File: `warehouse/internal/conf/conf.proto` ✅
  - [x] Add: `Reservation` message (contains ExpiryConfig) ✅
  - [x] Add: `ExpiryConfig` message ✅
  - [x] Regenerate: `make api` ✅

- [x] **Update Config Go Struct**
  - [x] File: `warehouse/internal/biz/reservation/reservation.go`
  - [x] Add: `GetExpiryDuration(paymentMethod)` method ✅
  - [x] Parse: YAML config to struct ✅ (via config.Warehouse.Reservation.Expiry)

- [x] **Test Config Loading**
  - [x] Test: Load config from YAML ✅
  - [x] Test: Default values nếu không có config ✅ (fallback 30m)
  - [ ] Test: Invalid duration format handling

### 2.2 Reservation Creation with Expiry
- [x] **Update ReserveStock Request**
  - [x] File: `warehouse/api/inventory/v1/inventory.proto`
  - [x] Verify: `expires_at` field exists ✅
  - [x] Update: Make `expires_at` optional (calculate from payment method) ✅
  - [x] Add: `payment_method` field (optional) ✅

- [x] **Update ReserveStock Logic**
  - [x] File: `warehouse/internal/biz/reservation/reservation.go`
  - [x] Add: `GetExpiryDuration(paymentMethod)` method ✅
  - [x] Calculate: `expires_at = now + expiry_duration` ✅
  - [x] Update: Create reservation với calculated expiry ✅
  - [x] Handle: Default expiry nếu payment_method không có ✅

- [x] **Update Reservation Model**
  - [x] File: `warehouse/internal/model/inventory.go`
  - [x] Verify: `ExpiresAt` field exists ✅
  - [x] Verify: `ExpiresAt` is nullable ✅
  - [x] Add index: `idx_reservations_expires_at` ✅ (migration 014)

- [x] **Update Reservation Repository**
  - [x] File: `warehouse/internal/repository/reservation/reservation.go`
  - [x] Verify: `ExpiresAt` field in Create method ✅
  - [x] Update: Store expiry time ✅

- [ ] **Test Reservation Expiry**
  - [ ] Test: COD → 24h expiry
  - [ ] Test: Credit Card → 30m expiry
  - [ ] Test: E-Wallet → 15m expiry
  - [ ] Test: Default expiry nếu không có payment method

### 2.3 Background Job - Auto-Release Expired Reservations
- [x] **Create Expiry Job**
  - [x] File: `warehouse/internal/worker/expiry/reservation_expiry.go` ✅
  - [x] Create: Worker struct ✅
  - [x] Create: `CheckExpiredReservations` method ✅
  - [x] Query: Reservations với `expires_at < now` và `status = 'active'` ✅
  - [x] Release: All expired reservations ✅
  - [x] Log: Released reservations ✅

- [x] **Update Worker Registration**
  - [x] File: `warehouse/cmd/worker/wire.go` ✅
  - [x] Register: Reservation expiry worker ✅ (via expiry.ProviderSet)
  - [x] Register: Reservation warning worker ✅ (via expiry.ProviderSet)
  - [x] Schedule: Run every 1-5 minutes ✅ (every 5 minutes)

- [x] **Update Cron Job**
  - [x] File: `warehouse/internal/worker/expiry/reservation_expiry.go`
  - [x] Add: `CheckExpiredReservations` cron job ✅
  - [x] Schedule: `*/5 * * * *` (every 5 minutes) ✅
  - [x] Handle: Errors gracefully ✅

- [x] **Update Release Reservation Logic**
  - [x] File: `warehouse/internal/biz/reservation/reservation.go`
  - [x] Update: `ReleaseReservation` method ✅
  - [x] Update: `ReleaseReservationsByOrderID` method ✅
  - [x] Add: `GetExpiredReservations` method ✅
  - [ ] Update: Order status nếu order cancelled do expiry (CẦN CHECK)

- [ ] **Test Expiry Job**
  - [ ] Test: Job runs on schedule
  - [ ] Test: Expired reservations auto-released
  - [ ] Test: Order status updated nếu reservation expired
  - [ ] Test: Stock restored correctly

### 2.4 Reservation Expiry Warning (5 minutes before)
- [x] **Create Warning Job**
  - [x] File: `warehouse/internal/worker/expiry/reservation_warning.go` ✅
  - [x] Create: `CheckExpiringReservations` method ✅
  - [x] Query: Reservations với `expires_at BETWEEN now AND now + 5m` ✅
  - [x] Filter: Status = 'active' ✅
  - [x] Send: Warning notification ✅

- [x] **Update Notification Integration**
  - [x] File: `warehouse/internal/worker/expiry/reservation_warning.go`
  - [x] Add: `sendExpiryWarning` method ✅
  - [x] Call: AlertUsecase.CheckReservationExpiry (uses NotificationClient) ✅
  - [x] Include: Reservation details, expiry time, order info ✅

- [x] **Update Notification Service Integration**
  - [x] File: `warehouse/internal/biz/alert/alert.go` ✅
  - [x] Add: `CheckReservationExpiry` method ✅
  - [x] Add: `SendReservationExpiryWarning` to NotificationClient interface ✅
  - [x] Send: Email/SMS to customer (via NotificationClient) ✅
  - [x] Include: Order number, items, expiry time ✅
  - [x] Update: ReservationWarningWorker to use AlertUsecase ✅

- [ ] **Test Expiry Warning**
  - [ ] Test: Warning sent 5 minutes before expiry
  - [ ] Test: Notification sent to customer
  - [ ] Test: Warning không gửi duplicate

---

## Phase 3: Adjustment Approval Workflow

### 3.1 Adjustment Request Entity
- [x] **Create Adjustment Request Model**
  - [x] File: `warehouse/internal/model/adjustment_request.go` ✅
  - [x] Fields: ✅
    ```go
    type AdjustmentRequest struct {
        ID              uuid.UUID
        WarehouseID     uuid.UUID
        ProductID       uuid.UUID
        SKU             string
        QuantityChange  int32
        Reason          string
        Notes           string
        Status          AdjustmentRequestStatus // pending, approved, rejected, completed, cancelled
        RequestedBy     uuid.UUID
        RequestedAt     time.Time
        ApprovedBy      *uuid.UUID
        ApprovedAt      *time.Time
        RejectedBy      *uuid.UUID
        RejectedAt      *time.Time
        RejectionReason *string
        ExecutedAt      *time.Time
        CreatedAt       time.Time
        UpdatedAt       time.Time
    }
    ```

- [x] **Create Adjustment Request Status Enum**
  - [x] File: `warehouse/internal/model/adjustment_request.go`
  - [x] Define: `AdjustmentRequestStatus` type ✅
  - [x] Values: `pending`, `approved`, `rejected`, `completed`, `cancelled` ✅

- [x] **Create Migration**
  - [x] File: `warehouse/migrations/012_create_adjustment_requests_table.sql` ✅
  - [x] Create table: `adjustment_requests` ✅
  - [x] Add indexes: `idx_adjustment_requests_status`, `idx_adjustment_requests_warehouse` ✅
  - [x] Add foreign keys: `warehouse_id` ✅ (product_id và requested_by là UUID references, không có FK constraint)

- [ ] **Test Model & Migration**
  - [ ] Test: Migration up/down
  - [ ] Test: Model creation
  - [ ] Test: Status enum values

### 3.2 Adjustment Request Repository
- [x] **Create Adjustment Request Repository**
  - [x] File: `warehouse/internal/repository/adjustment/adjustment.go` ✅
  - [x] Interface: ✅
    ```go
    type AdjustmentRequestRepo interface {
        Create(ctx context.Context, req *model.AdjustmentRequest) error
        FindByID(ctx context.Context, id string) (*model.AdjustmentRequest, error)
        Update(ctx context.Context, req *model.AdjustmentRequest) error
        ListPending(ctx context.Context, warehouseID *string, offset, limit int32) ([]*model.AdjustmentRequest, int32, error)
        ListByStatus(ctx context.Context, status string, offset, limit int32) ([]*model.AdjustmentRequest, int32, error)
        ListByRequester(ctx context.Context, userID string, offset, limit int32) ([]*model.AdjustmentRequest, int32, error)
    }
    ```

- [x] **Implement Repository**
  - [x] File: `warehouse/internal/data/postgres/adjustment.go` ✅
  - [x] Implement: All interface methods ✅
  - [x] Use: GORM for database operations ✅
  - [x] Add: Pagination support ✅

- [ ] **Test Repository**
  - [ ] Test: Create adjustment request
  - [ ] Test: Find by ID
  - [ ] Test: Update status
  - [ ] Test: List pending requests
  - [ ] Test: List by status

### 3.3 Adjustment Request Business Logic
- [x] **Create Adjustment Request Usecase**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] Methods: ✅
    ```go
    type AdjustmentUsecase interface {
        CreateRequest(ctx context.Context, req *CreateAdjustmentRequest) (*model.AdjustmentRequest, error)
        ApproveRequest(ctx context.Context, requestID string, approvedBy string) error
        RejectRequest(ctx context.Context, requestID string, rejectedBy string, reason string) error
        ExecuteRequest(ctx context.Context, requestID string) error
        GetRequest(ctx context.Context, requestID string) (*model.AdjustmentRequest, error)
        ListPendingRequests(ctx context.Context, warehouseID *string, offset, limit int32) ([]*model.AdjustmentRequest, int32, error)
    }
    ```

- [x] **Implement CreateRequest**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go`
  - [x] Validate: Warehouse exists ✅
  - [x] Validate: Product exists ✅
  - [x] Validate: Quantity change != 0 ✅
  - [x] Create: Adjustment request với status "pending" ✅
  - [x] Send: Notification to approver (with required roles) ✅
  - [x] Return: Created request ✅

- [x] **Implement Approval Rules**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] Add: `GetRequiredApproverRoles(quantityChange, reason)` method ✅
  - [x] Add: `IsCriticalReason(reason)` method ✅
  - [x] Rules:
    - Small (< 10 units): Warehouse Manager, Operations Staff, System Admin ✅
    - Medium (10-100 units): Operations Staff, System Admin ✅
    - Large (> 100 units): System Admin ✅
    - Critical (damage, theft, loss, fraud): Require 2 approvals (System Admin only) ✅
  - [x] Validate: Approver has required role ✅ (via UserServiceClient)

- [x] **Implement ApproveRequest**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] Validate: Request status = "pending" ✅
  - [x] Validate: Approver has required role ✅ (via UserServiceClient.HasAnyRole)
  - [x] Check: Nếu critical → cần 2 approvals ✅ (FirstApprovedBy, SecondApprovedBy)
  - [x] Update: Request status = "approved" ✅
  - [x] Update: ApprovedBy, ApprovedAt, SecondApprovedBy, SecondApprovedAt ✅
  - [x] If all approvals done → Auto-execute ✅
  - [x] Send: Notification to requester ✅

- [x] **Implement RejectRequest**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] Validate: Request status = "pending" ✅
  - [x] Validate: Rejecter has required role ✅ (via UserServiceClient.HasAnyRole)
  - [x] Update: Request status = "rejected" ✅
  - [x] Update: RejectedBy, RejectedAt, RejectionReason ✅
  - [x] Send: Notification to requester ✅

- [x] **Implement ExecuteRequest**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go`
  - [x] Validate: Request status = "approved" ✅
  - [x] Get: Request details ✅
  - [x] Call: `AdjustStock` với request details ✅
  - [x] Update: Request status = "completed" ✅
  - [x] Update: ExecutedAt ✅
  - [x] Send: Notification to requester ✅

- [ ] **Test Business Logic**
  - [ ] Test: Create request
  - [ ] Test: Approval rules (small/medium/large/critical)
  - [ ] Test: Approve request
  - [ ] Test: Reject request
  - [ ] Test: Execute request
  - [ ] Test: Critical adjustment (2 approvals)

### 3.4 Adjustment Request API
- [x] **Update Proto Definition**
  - [x] File: `warehouse/api/inventory/v1/inventory.proto`
  - [x] Add: `CreateAdjustmentRequest` RPC ✅
  - [x] Add: `ApproveAdjustmentRequest` RPC ✅
  - [x] Add: `RejectAdjustmentRequest` RPC ✅
  - [x] Add: `GetAdjustmentRequest` RPC ✅
  - [x] Add: `ListAdjustmentRequests` RPC ✅
  - [x] Add: Messages: `AdjustmentRequest`, `CreateAdjustmentRequestRequest`, etc. ✅
  - [x] Regenerate: `make api` ✅

- [x] **Update Service Implementation**
  - [x] File: `warehouse/internal/service/inventory_service.go`
  - [x] Implement: `CreateAdjustmentRequest` handler ✅
  - [x] Implement: `ApproveAdjustmentRequest` handler ✅
  - [x] Implement: `RejectAdjustmentRequest` handler ✅
  - [x] Implement: `GetAdjustmentRequest` handler ✅
  - [x] Implement: `ListAdjustmentRequests` handler ✅

- [x] **Update HTTP Routes**
  - [x] File: `warehouse/api/inventory/v1/inventory.proto` (auto-generated)
  - [x] Add: `POST /api/v1/adjustments/requests` ✅
  - [x] Add: `POST /api/v1/adjustments/requests/{id}/approve` ✅
  - [x] Add: `POST /api/v1/adjustments/requests/{id}/reject` ✅
  - [x] Add: `GET /api/v1/adjustments/requests/{id}` ✅
  - [x] Add: `GET /api/v1/adjustments/requests` ✅

- [ ] **Add Authorization**
  - [ ] File: `warehouse/internal/service/inventory_service.go`
  - [ ] Create request: Warehouse staff, admin (CẦN CHECK)
  - [ ] Approve/Reject: Manager, admin (based on rules) (CẦN CHECK)
  - [ ] View: Warehouse staff, manager, admin (CẦN CHECK)

- [ ] **Test API**
  - [ ] Test: Create adjustment request
  - [ ] Test: Approve request (with proper role)
  - [ ] Test: Reject request (with proper role)
  - [ ] Test: List pending requests
  - [ ] Test: Authorization (unauthorized access)

### 3.5 Notification Integration
- [x] **Create Request Notification**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] When: Request created ✅
  - [x] Logic: Determine approver based on approval rules ✅
  - [x] Send: To approver (notification sent with required roles) ✅
  - [x] Include: Request details, warehouse, product, quantity change, reason, notes, required roles ✅
  - [ ] TODO: Lookup actual approver user IDs from User Service based on required roles (enhancement)

- [x] **Create Approval Notification**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] When: Request approved ✅
  - [x] Send: To requester ✅
  - [x] Include: Request details, approved by, execution status, needs second approval ✅

- [x] **Create Rejection Notification**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] When: Request rejected ✅
  - [x] Send: To requester ✅
  - [x] Include: Request details, rejected by, rejection reason ✅

- [x] **Create Execution Notification**
  - [x] File: `warehouse/internal/biz/adjustment/adjustment.go` ✅
  - [x] When: Request executed ✅
  - [x] Send: To requester ✅
  - [x] Include: Request details, executed at ✅

- [x] **Update Notification Service Client**
  - [x] File: `warehouse/internal/client/notification_client.go` ✅
  - [x] Add: `SendAdjustmentRequestCreated` method ✅
  - [x] Add: `SendAdjustmentRequestApproved` method ✅
  - [x] Add: `SendAdjustmentRequestRejected` method ✅
  - [x] Add: `SendAdjustmentRequestExecuted` method ✅
  - [x] Extend: `NotificationClient` interface in `alert` package ✅

- [x] **Update Notification Data Structures**
  - [x] File: `warehouse/internal/biz/alert/alert.go` ✅
  - [x] Add: `AdjustmentRequestCreated`, `AdjustmentRequestApproved`, `AdjustmentRequestRejected`, `AdjustmentRequestExecuted` structs ✅

- [ ] **Test Notifications**
  - [ ] Test: Notification sent khi request created (requires approver lookup)
  - [ ] Test: Notification sent khi request approved
  - [ ] Test: Notification sent khi request rejected
  - [ ] Test: Notification sent khi request executed
  - [ ] Test: Correct recipients

---

## Phase 4: Stock Alerts via Notification

### 4.1 Alert Triggers
- [x] **Create Alert Service**
  - [x] File: `warehouse/internal/biz/alert/alert.go` ✅
  - [x] Methods: ✅
    ```go
    type AlertUsecase interface {
        CheckLowStock(ctx context.Context, inventory *model.Inventory) error
        CheckOutOfStock(ctx context.Context, inventory *model.Inventory) error
        CheckOverstock(ctx context.Context, inventory *model.Inventory) error
        CheckExpiringStock(ctx context.Context, inventory *model.Inventory) error
        CheckReservationExpiry(ctx context.Context, reservation *model.StockReservation) error
    }
    ```

- [x] **Implement Low Stock Alert**
  - [x] File: `warehouse/internal/biz/alert/alert.go`
  - [x] Trigger: `Available < ReorderPoint` và `ReorderPoint > 0` ✅
  - [x] Check: Chưa alert trong 24h (avoid spam) ✅
  - [x] Send: Notification to warehouse manager, procurement team ✅
  - [x] Include: Product, warehouse, available, reorder point ✅

- [x] **Implement Out of Stock Alert**
  - [x] File: `warehouse/internal/biz/alert/alert.go`
  - [x] Trigger: `Available = 0` ✅
  - [x] Check: Chưa alert trong 1h (avoid spam) ✅
  - [x] Send: Notification to warehouse manager, procurement team, admin ✅
  - [x] Include: Product, warehouse, last stock level ✅

- [x] **Implement Overstock Alert**
  - [x] File: `warehouse/internal/biz/alert/alert.go`
  - [x] Trigger: `Available > MaxStockLevel` và `MaxStockLevel != null` ✅
  - [x] Check: Chưa alert trong 24h (avoid spam) ✅
  - [x] Send: Notification to warehouse manager ✅
  - [x] Include: Product, warehouse, available, max level ✅

- [x] **Implement Expiring Stock Alert**
  - [x] File: `warehouse/internal/biz/alert/alert.go`
  - [x] Trigger: `ExpiryDate < now + 7 days` (7 days before expiry) ✅
  - [x] Check: Chưa alert trong 24h (avoid spam) ✅
  - [x] Send: Notification to warehouse manager ✅
  - [x] Include: Product, warehouse, expiry date, quantity ✅

- [x] **Implement Reservation Expiry Warning**
  - [x] File: `warehouse/internal/worker/expiry/reservation_warning.go`
  - [x] Trigger: `ExpiresAt BETWEEN now AND now + 5m` ✅
  - [x] Check: Status = 'active' ✅
  - [x] Send: Notification to customer ✅
  - [x] Include: Order number, items, expiry time ✅

- [ ] **Test Alert Triggers**
  - [ ] Test: Low stock alert
  - [ ] Test: Out of stock alert
  - [ ] Test: Overstock alert
  - [ ] Test: Expiring stock alert
  - [ ] Test: Reservation expiry warning

### 4.2 Alert History (Prevent Duplicate Alerts)
- [x] **Create Alert History Model**
  - [x] File: `warehouse/internal/model/alert_history.go` ✅
  - [x] Fields: ✅
    ```go
    type AlertHistory struct {
        ID            uuid.UUID
        AlertType     string // "low_stock", "out_of_stock", "overstock", "expiring", "reservation_expiry"
        WarehouseID   uuid.UUID
        ProductID     uuid.UUID
        InventoryID   *uuid.UUID
        ReservationID *uuid.UUID
        AlertedAt     time.Time
        CreatedAt     time.Time
    }
    ```

- [x] **Create Migration**
  - [x] File: `warehouse/migrations/013_create_alert_history_table.sql` ✅
  - [x] Create table: `alert_history` ✅
  - [x] Add indexes: `idx_alert_history_type`, `idx_alert_history_warehouse`, `idx_alert_history_created_at` ✅

- [x] **Update Alert Service**
  - [x] File: `warehouse/internal/biz/alert/alert.go`
  - [x] Check: Alert history trước khi send ✅ (via `WasAlertedRecently`)
  - [x] Record: Alert history sau khi send ✅
  - [x] Cleanup: Old alert history (> 30 days) ✅ (via AlertCleanupJob)

- [ ] **Test Alert History**
  - [ ] Test: Prevent duplicate alerts
  - [ ] Test: Alert history recorded
  - [ ] Test: Cleanup old history

### 4.3 Notification Service Integration
- [x] **Create Notification Client**
  - [x] File: `warehouse/internal/client/notification_client.go` ✅
  - [x] Methods: ✅
    ```go
    type NotificationClient interface {
        SendLowStockAlert(ctx context.Context, alert *LowStockAlert) error
        SendOutOfStockAlert(ctx context.Context, alert *OutOfStockAlert) error
        SendOverstockAlert(ctx context.Context, alert *OverstockAlert) error
        SendExpiringStockAlert(ctx context.Context, alert *ExpiringStockAlert) error
        SendReservationExpiryWarning(ctx context.Context, alert *ReservationExpiryWarning) error
    }
    ```

- [x] **Implement Notification Methods**
  - [x] File: `warehouse/internal/client/notification_client.go` ✅
  - [x] Call: Notification Service API ✅
  - [x] Include: Alert details, recipients, channels ✅
  - [x] Handle: Errors gracefully ✅

- [x] **Update Alert Service**
  - [x] File: `warehouse/internal/biz/alert/alert.go` ✅
  - [x] Call: Notification client methods ✅ (already integrated)
  - [x] Handle: Notification failures (log, retry) ✅

- [x] **Integrate Alert Checks with Inventory Updates**
  - [x] File: `warehouse/internal/biz/inventory/inventory.go` ✅
  - [x] Inject: AlertUsecase into InventoryUsecase ✅
  - [x] Call: Alert checks in UpdateInventory ✅
  - [x] Call: Alert checks in AdjustStock ✅
  - [x] Run: Alert checks in background (non-blocking) ✅

- [ ] **Test Notification Integration**
  - [ ] Test: Low stock notification sent
  - [ ] Test: Out of stock notification sent
  - [ ] Test: Overstock notification sent
  - [ ] Test: Expiring stock notification sent
  - [ ] Test: Reservation expiry warning sent
  - [ ] Test: Correct recipients
  - [ ] Test: Notification failures handled

### 4.4 Alert Recipients Configuration
- [x] **Create Alert Config**
  - [x] File: `warehouse/configs/config.yaml` ✅
  - [x] Add section: ✅
    ```yaml
    alerts:
      recipients:
        low_stock:
          - warehouse_manager
          - procurement_team
        out_of_stock:
          - warehouse_manager
          - procurement_team
          - admin
        overstock:
          - warehouse_manager
        expiring:
          - warehouse_manager
        reservation_expiry:
          - customer
      channels:
        warehouse_manager: [email, push]
        procurement_team: [email]
        admin: [email, sms]
        customer: [email, sms]
    ```

- [x] **Update Config Struct**
  - [x] File: `warehouse/internal/conf/conf.proto` ✅
  - [x] Add: `AlertConfig` message ✅
  - [x] Add: `AlertRecipients` message ✅
  - [x] Add: `AlertChannels` message ✅
  - [x] Regenerate: `make api` ✅

- [x] **Update Alert Service**
  - [x] File: `warehouse/internal/biz/alert/alert.go` ✅
  - [x] Inject: `AlertConfig` into `AlertUsecase` ✅
  - [x] Add: `getRecipientsForAlertType` method ✅
  - [x] Add: `getChannelsForRecipient` method ✅
  - [x] Update: `CheckLowStock` to use config ✅
  - [x] Update: `CheckOutOfStock` to use config ✅
  - [x] Update: `CheckOverstock` to use config ✅
  - [x] Update: `CheckReservationExpiry` to use config ✅
  - [x] Send: To configured recipients via configured channels ✅
  - [ ] TODO: Lookup user IDs from User Service based on role (enhancement)

- [ ] **Test Alert Configuration**
  - [ ] Test: Load recipients from config
  - [ ] Test: Send to correct recipients
  - [ ] Test: Use correct channels

### 4.5 Alert Frequency (Real-time, Daily, Weekly)
- [x] **Real-time Alerts**
  - [x] File: `warehouse/internal/biz/inventory/inventory.go` ✅
  - [x] Trigger: Khi stock thay đổi (inventory updated) ✅
  - [x] Check: Alert conditions ✅ (via AlertUsecase.CheckLowStock, CheckOutOfStock, etc.)
  - [x] Send: Immediate notification ✅ (non-blocking background check)

- [x] **Daily Summary Job**
  - [x] File: `warehouse/internal/worker/cron/daily_summary_job.go` ✅
  - [x] Schedule: Run daily at 8:00 AM ✅
  - [x] Collect: All alerts trong 24h ✅
  - [x] Group: By warehouse, by alert type ✅
  - [x] Send: Summary email to warehouse manager ✅
  - [ ] TODO: Lookup actual user IDs from User Service based on role (enhancement)

- [x] **Weekly Report Job**
  - [x] File: `warehouse/internal/worker/cron/weekly_report_job.go` ✅
  - [x] Schedule: Run weekly on Monday 8:00 AM ✅
  - [x] Collect: All alerts trong 7 days ✅
  - [x] Aggregate: Statistics, trends ✅
  - [x] Send: Report to admin, procurement team ✅
  - [ ] TODO: Lookup actual user IDs from User Service based on role (enhancement)

- [ ] **Test Alert Frequency**
  - [ ] Test: Real-time alerts
  - [ ] Test: Daily summary job
  - [ ] Test: Weekly report job

---

## Phase 5: Integration & Testing

### 5.1 End-to-End Testing
- [ ] **Multi-Warehouse Checkout Flow**
  - [ ] Test: Cart với items từ 2 warehouses
  - [ ] Test: Checkout tạo 2 reservations
  - [ ] Test: Payment confirm → Reservations active
  - [ ] Test: Fulfillment tạo 2 fulfillments
  - [ ] Test: Each fulfillment deducts from correct warehouse
  - [ ] Test: Order completion khi all fulfillments done

- [ ] **Reservation Expiry Flow**
  - [ ] Test: COD order → 24h expiry
  - [ ] Test: Credit card order → 30m expiry
  - [ ] Test: Expiry warning 5m before
  - [ ] Test: Auto-release khi expired
  - [ ] Test: Order cancelled khi reservation expired

- [ ] **Adjustment Approval Flow**
  - [ ] Test: Staff tạo adjustment request
  - [ ] Test: Manager receives notification
  - [ ] Test: Manager approves request
  - [ ] Test: Adjustment executed
  - [ ] Test: Staff receives completion notification
  - [ ] Test: Critical adjustment (2 approvals)

- [ ] **Stock Alerts Flow**
  - [ ] Test: Low stock alert triggered
  - [ ] Test: Out of stock alert triggered
  - [ ] Test: Notification sent to correct recipients
  - [ ] Test: Alert history prevents duplicates
  - [ ] Test: Daily summary sent
  - [ ] Test: Weekly report sent

### 5.2 Error Handling
- [ ] **Reservation Failures**
  - [ ] Test: Partial reservation failure (rollback all)
  - [ ] Test: Insufficient stock (reject reservation)
  - [ ] Test: Warehouse not found (error handling)

- [ ] **Adjustment Failures**
  - [ ] Test: Approval without proper role (reject)
  - [ ] Test: Execute without approval (error)
  - [ ] Test: Adjustment makes stock negative (reject)

- [ ] **Alert Failures**
  - [ ] Test: Notification service down (log, retry)
  - [ ] Test: Invalid recipients (skip, log)
  - [ ] Test: Alert history cleanup failure (log)

### 5.3 Performance Testing
- [ ] **Reservation Performance**
  - [ ] Test: Multiple reservations concurrently
  - [ ] Test: Expiry job performance (large dataset)
  - [ ] Test: Release batch reservations

- [ ] **Adjustment Performance**
  - [ ] Test: List pending requests (pagination)
  - [ ] Test: Batch approval (if needed)

- [ ] **Alert Performance**
  - [ ] Test: Alert check performance (large inventory)
  - [ ] Test: Daily summary generation (large dataset)

---

## Phase 6: Documentation

### 6.1 API Documentation
- [ ] **Update OpenAPI Spec**
  - [ ] File: `warehouse/openapi.yaml`
  - [ ] Document: Multi-warehouse reservation APIs
  - [ ] Document: Adjustment request APIs
  - [ ] Document: Alert APIs (if exposed)

- [ ] **Update Service Documentation**
  - [ ] File: `docs/docs/services/warehouse-inventory-service.md`
  - [ ] Document: Multi-warehouse support
  - [ ] Document: Reservation expiry config
  - [ ] Document: Adjustment approval workflow
  - [ ] Document: Stock alerts

### 6.2 User Documentation
- [ ] **Warehouse Staff Guide**
  - [ ] File: `docs/docs/guides/warehouse-staff-guide.md` (NEW)
  - [ ] How to create adjustment request
  - [ ] How to view pending requests
  - [ ] How to handle stock alerts

- [ ] **Manager Guide**
  - [ ] File: `docs/docs/guides/warehouse-manager-guide.md` (NEW)
  - [ ] How to approve/reject adjustments
  - [ ] How to view stock alerts
  - [ ] How to configure alert recipients

---

## Summary

**Total Phases:** 6

**Key Features:**
1. Multi-Warehouse Support (Order → Multiple Reservations → Multiple Fulfillments)
2. Reservation Expiry Configuration (Payment Method → Expiry Duration)
3. Adjustment Approval Workflow (Request → Approval → Execution)
4. Stock Alerts via Notification (Real-time, Daily, Weekly)

**Critical Components:**
- Order Service: Multiple reservations per order
- Fulfillment Service: Multiple fulfillments per order
- Warehouse Service: Multi-warehouse reservations, expiry config, adjustment approval, alerts
- Notification Service: Alert delivery

**Database Changes:**
- `adjustment_requests` table (NEW)
- `alert_history` table (NEW)
- Indexes for reservations, adjustments, alerts

**Background Jobs:**
- Reservation expiry checker (every 5 minutes)
- Reservation expiry warning (every 5 minutes)
- Daily summary job (daily 8:00 AM)
- Weekly report job (weekly Monday 8:00 AM)

**Estimated Timeline:**
- Phase 1 (Multi-Warehouse): 1-2 weeks
- Phase 2 (Reservation Expiry): 1 week
- Phase 3 (Adjustment Approval): 2 weeks
- Phase 4 (Stock Alerts): 1-2 weeks
- Phase 5 (Integration & Testing): 1 week
- Phase 6 (Documentation): 3-5 days

**Total: 6-8 weeks**


# ✅ Sprint 2 Checklist - Returns & Exchanges Workflow

**Duration**: Week 3-4  
**Goal**: Implement complete Returns & Exchanges workflow  
**Target Progress**: 91% → 93%

---

## 📋 Overview

- [ ] **Task**: Implement Returns & Exchanges Workflow (0% → 100%)

**Team**: 3 developers  
**Estimated Effort**: 2-3 weeks  
**Impact**: 🔴 CRITICAL (Customer satisfaction)

---

## 🎯 Task: Returns & Exchanges Workflow

### Week 3: Design, Schema & Core Implementation

#### 3.1 Design & Architecture
- [ ] **Flow Design**
  - [ ] Design return request flow diagram
  - [ ] Design exchange request flow diagram
  - [ ] Design refund calculation logic
  - [ ] Design inventory return flow
  - [ ] Design return shipping flow
  - [ ] Review with team

- [ ] **Business Rules Definition**
  - [ ] Define return eligibility rules
    - [ ] Time window: 30 days from delivery
    - [ ] Product condition requirements
    - [ ] Non-returnable items list
  - [ ] Define refund calculation rules
    - [ ] Full refund vs partial refund
    - [ ] Shipping cost refund policy
    - [ ] Restocking fee policy
  - [ ] Define exchange rules
    - [ ] Same product different size/color
    - [ ] Different product (price difference)
    - [ ] Exchange shipping cost
  - [ ] Document all rules

#### 3.2 Database Schema (Order Service)
- [ ] **Create Tables**
  - [ ] Create `return_requests` table
    ```sql
    - id (UUID, PK)
    - order_id (UUID, FK)
    - customer_id (UUID)
    - request_type (enum: return, exchange)
    - status (enum: pending, approved, rejected, completed, cancelled)
    - reason_code (varchar)
    - reason_description (text)
    - refund_amount (decimal)
    - restocking_fee (decimal)
    - created_at, updated_at
    ```
  - [ ] Create `return_items` table
    ```sql
    - id (UUID, PK)
    - return_request_id (UUID, FK)
    - order_item_id (UUID, FK)
    - product_id (UUID)
    - quantity (int)
    - return_reason (varchar)
    - condition (enum: unopened, opened, damaged)
    - refund_amount (decimal)
    ```
  - [ ] Create `return_reasons` table (lookup)
    ```sql
    - id (UUID, PK)
    - code (varchar, unique)
    - description (text)
    - is_active (boolean)
    ```
  - [ ] Create `return_status_history` table
    ```sql
    - id (UUID, PK)
    - return_request_id (UUID, FK)
    - status (varchar)
    - notes (text)
    - changed_by (UUID)
    - created_at
    ```
  - [ ] Create `exchange_requests` table
    ```sql
    - id (UUID, PK)
    - return_request_id (UUID, FK)
    - new_product_id (UUID)
    - new_variant_id (UUID)
    - quantity (int)
    - price_difference (decimal)
    - status (enum: pending, processing, shipped, completed)
    ```

- [ ] **Create Indexes**
  - [ ] Index on `return_requests.order_id`
  - [ ] Index on `return_requests.customer_id`
  - [ ] Index on `return_requests.status`
  - [ ] Index on `return_requests.created_at`
  - [ ] Index on `return_items.return_request_id`

- [ ] **Run Migrations**
  - [ ] Test migration on dev database
  - [ ] Review migration with DBA
  - [ ] Prepare rollback script

#### 3.3 Order Service Implementation

**Assignee**: Dev 1

- [ ] **Business Logic** (`internal/biz/return/`)
  - [ ] Create `ReturnUsecase` struct
  - [ ] Implement `CreateReturnRequest(ctx, request)` method
    - [ ] Validate order eligibility
    - [ ] Check return window (30 days)
    - [ ] Check order status (must be delivered)
    - [ ] Check items eligibility
    - [ ] Calculate refund amount
    - [ ] Create return request record
    - [ ] Publish `return.requested` event
  - [ ] Implement `GetReturnRequest(ctx, id)` method
  - [ ] Implement `ListReturnRequests(ctx, filters)` method
  - [ ] Implement `ApproveReturn(ctx, id, notes)` method
    - [ ] Update status to approved
    - [ ] Generate return shipping label
    - [ ] Send approval notification
    - [ ] Publish `return.approved` event
  - [ ] Implement `RejectReturn(ctx, id, reason)` method
    - [ ] Update status to rejected
    - [ ] Send rejection notification
    - [ ] Publish `return.rejected` event
  - [ ] Implement `CompleteReturn(ctx, id)` method
    - [ ] Update status to completed
    - [ ] Process refund
    - [ ] Update inventory
    - [ ] Send completion notification
    - [ ] Publish `return.completed` event
  - [ ] Implement `CancelReturn(ctx, id)` method

- [ ] **Exchange Logic** (`internal/biz/exchange/`)
  - [ ] Create `ExchangeUsecase` struct
  - [ ] Implement `CreateExchangeRequest(ctx, returnID, newProduct)` method
    - [ ] Validate exchange eligibility
    - [ ] Check new product availability
    - [ ] Calculate price difference
    - [ ] Create exchange request
    - [ ] Publish `exchange.requested` event
  - [ ] Implement `ProcessExchange(ctx, id)` method
    - [ ] Create new order for exchange item
    - [ ] Process payment for price difference (if any)
    - [ ] Process refund for price difference (if any)
    - [ ] Update return request
    - [ ] Publish `exchange.processing` event
  - [ ] Implement `CompleteExchange(ctx, id)` method
    - [ ] Update status to completed
    - [ ] Send completion notification
    - [ ] Publish `exchange.completed` event

- [ ] **Refund Calculation** (`internal/biz/return/refund.go`)
  - [ ] Implement `CalculateRefundAmount(order, items)` method
    - [ ] Calculate item refund (price * quantity)
    - [ ] Calculate shipping refund (if applicable)
    - [ ] Subtract restocking fee (if applicable)
    - [ ] Subtract used promotions/discounts
    - [ ] Return total refund amount
  - [ ] Implement `CalculateRestockingFee(items)` method
  - [ ] Add unit tests for calculations

- [ ] **Data Layer** (`internal/data/postgres/`)
  - [ ] Create `ReturnRepo` interface
  - [ ] Implement `CreateReturnRequest` repository method
  - [ ] Implement `GetReturnRequest` repository method
  - [ ] Implement `ListReturnRequests` repository method
  - [ ] Implement `UpdateReturnStatus` repository method
  - [ ] Implement `GetReturnsByOrder` repository method
  - [ ] Implement `GetReturnsByCustomer` repository method

- [ ] **Service Layer** (`internal/service/`)
  - [ ] Add gRPC methods for return management
    - [ ] `CreateReturnRequest`
    - [ ] `GetReturnRequest`
    - [ ] `ListReturnRequests`
    - [ ] `ApproveReturn`
    - [ ] `RejectReturn`
    - [ ] `CompleteReturn`
  - [ ] Add gRPC methods for exchange management
    - [ ] `CreateExchangeRequest`
    - [ ] `ProcessExchange`
    - [ ] `CompleteExchange`
  - [ ] Add HTTP endpoints via gRPC-Gateway
  - [ ] Add validation middleware
  - [ ] Add authorization middleware

- [ ] **Testing**
  - [ ] Unit tests for `ReturnUsecase`
  - [ ] Unit tests for `ExchangeUsecase`
  - [ ] Unit tests for refund calculations
  - [ ] Integration test: Create return request
  - [ ] Integration test: Approve return
  - [ ] Integration test: Complete return
  - [ ] Integration test: Create exchange
  - [ ] Integration test: Process exchange

### Week 4: Service Integrations & Testing

#### 3.4 Warehouse Service Integration

**Assignee**: Dev 2

- [x] **Return Receiving** (`internal/biz/inventory/`)
  - [x] Implement `HandleReturnCompleted(ctx, event)` method
    - [x] Process return completed events
    - [x] Restock items based on condition (restockable flag)
    - [x] Create inbound transaction for restockable items
    - [x] Skip non-restockable items (damaged, defective)

- [x] **Inventory Updates**
  - [x] Update `InventoryUsecase` to handle returns
  - [x] Use `return` movement reason (already exists)
  - [x] Create inbound transactions for returned items
  - [x] Update stock levels on return completion

- [x] **Event Consumers** (`internal/data/eventbus/`)
  - [x] Create `ReturnConsumer`
  - [x] Subscribe to `orders.return.completed` event
    - [x] Process return completed events
    - [x] Restock items automatically

- [ ] **Testing**
  - [ ] Unit tests for return receiving
  - [ ] Unit tests for inventory updates
  - [ ] Integration test: Receive returned item
  - [ ] Integration test: Restock item
  - [ ] Test event consumers

#### 3.5 Payment Service Integration

**Assignee**: Dev 2

- [x] **Refund Processing** (`order/internal/biz/return/`)
  - [x] Order Service calls Payment Service API directly
  - [x] Implement `processReturnRefund(ctx, returnRequest)` method in Order Service
    - [x] Get payment ID from order
    - [x] Calculate refund amount (subtract restocking fee)
    - [x] Call Payment Service `ProcessRefund` API
    - [x] Update return request with refund ID
  - [x] Handle partial refunds (via refund amount calculation)
  - [x] Handle refund failures (error handling in Order Service)

- [ ] **Exchange Payment** (`order/internal/biz/return/`)
  - [ ] Implement exchange payment logic in Order Service
    - [ ] Calculate price difference when creating exchange order
    - [ ] If price increase: charge customer via Payment Service
    - [ ] If price decrease: refund customer via Payment Service

- [x] **Integration Pattern**
  - [x] Order Service calls Payment Service API directly (synchronous)
  - [x] No event consumer needed (avoids duplicate processing)
  - [x] Payment Service already has `ProcessRefund` API

- [ ] **Testing**
  - [ ] Unit tests for refund processing
  - [ ] Unit tests for exchange payment
  - [ ] Integration test: Process full refund
  - [ ] Integration test: Process partial refund
  - [ ] Integration test: Exchange with price increase
  - [ ] Integration test: Exchange with price decrease
  - [ ] Test refund failures and retries

#### 3.6 Shipping Service Integration

**Assignee**: Dev 3

- [x] **Return Shipping** (`order/internal/biz/return/`)
  - [x] Order Service calls Shipping Service API directly
  - [x] Implement `generateReturnShippingLabel(ctx, returnRequest)` method in Order Service
    - [x] Get return request details
    - [x] Get customer address from order
    - [x] Get warehouse address from Warehouse Service
    - [x] Call Shipping Service `CreateShipment` API with return service code
    - [x] Store label URL and tracking number
  - [x] Return shipping labels generated automatically when return approved

- [x] **Integration Pattern**
  - [x] Order Service calls Shipping Service API directly (synchronous)
  - [x] No event consumer needed (Order Service handles it)
  - [x] Shipping Service already has `CreateShipment` API

- [ ] **Return Shipping Policy**
  - [ ] Implement free return shipping (if applicable)
  - [ ] Implement customer-paid return shipping
  - [ ] Implement prepaid return labels
  - [ ] Handle international returns

- [ ] **Testing**
  - [ ] Unit tests for return shipping
  - [ ] Integration test: Generate return label
  - [ ] Integration test: Track return shipment
  - [ ] Test with different carriers
  - [ ] Test international returns

#### 3.7 Notification Service Integration

**Assignee**: Dev 3

- [ ] **Notification Templates**
  - [ ] Create `return_request_received` template
  - [ ] Create `return_approved` template
  - [ ] Create `return_rejected` template
  - [ ] Create `return_label_ready` template
  - [ ] Create `return_received` template
  - [ ] Create `refund_processed` template
  - [ ] Create `exchange_processing` template
  - [ ] Create `exchange_shipped` template

- [ ] **Event Consumers** (`notification/internal/data/eventbus/`)
  - [ ] Subscribe to `return.requested` event
    - [ ] Send confirmation to customer
    - [ ] Send notification to admin
  - [ ] Subscribe to `return.approved` event
    - [ ] Send approval email with return label
  - [ ] Subscribe to `return.rejected` event
    - [ ] Send rejection email with reason
  - [ ] Subscribe to `return.received` event
    - [ ] Send received confirmation
  - [ ] Subscribe to `refund.processed` event
    - [ ] Send refund confirmation
  - [ ] Subscribe to `exchange.shipped` event
    - [ ] Send shipping notification

- [ ] **Testing**
  - [ ] Test all notification templates
  - [ ] Test email delivery
  - [ ] Test SMS delivery (if applicable)
  - [ ] Test notification preferences

#### 3.8 End-to-End Testing

- [ ] **Return Flow Testing**
  - [ ] Test complete return flow (happy path)
    1. [ ] Customer creates return request
    2. [ ] Admin approves return
    3. [ ] Return label generated
    4. [ ] Customer ships item
    5. [ ] Warehouse receives item
    6. [ ] Item inspected and restocked
    7. [ ] Refund processed
    8. [ ] Customer notified
  - [ ] Test return rejection flow
  - [ ] Test return cancellation by customer
  - [ ] Test partial return (some items)
  - [ ] Test return with damaged items

- [ ] **Exchange Flow Testing**
  - [ ] Test complete exchange flow (happy path)
    1. [ ] Customer creates exchange request
    2. [ ] Admin approves exchange
    3. [ ] Return label generated
    4. [ ] Customer ships original item
    5. [ ] Warehouse receives original item
    6. [ ] New item shipped
    7. [ ] Payment difference processed
    8. [ ] Customer notified
  - [ ] Test exchange with price increase
  - [ ] Test exchange with price decrease
  - [ ] Test exchange with out-of-stock item
  - [ ] Test exchange cancellation

- [ ] **Edge Cases**
  - [ ] Test return after 30 days (should be rejected)
  - [ ] Test return of non-returnable item
  - [ ] Test return with used promotion code
  - [ ] Test return with loyalty points redemption
  - [ ] Test multiple returns for same order
  - [ ] Test concurrent return requests
  - [ ] Test return with partial payment
  - [ ] Test return with gift card payment

- [ ] **Error Handling**
  - [ ] Test refund failure (payment gateway error)
  - [ ] Test shipping label generation failure
  - [ ] Test inventory update failure
  - [ ] Test notification failure
  - [ ] Test service unavailability
  - [ ] Verify retry mechanisms
  - [ ] Verify error logging

- [ ] **Performance Testing**
  - [ ] Test 100 concurrent return requests
  - [ ] Test bulk return processing
  - [ ] Test response times (<500ms)
  - [ ] Test database performance

#### 3.9 Admin Panel Integration

- [ ] **Return Management UI**
  - [ ] Create return requests list page
    - [ ] Filters: status, date range, customer
    - [ ] Search by order ID, customer name
    - [ ] Pagination
  - [ ] Create return request detail page
    - [ ] Display return details
    - [ ] Display items to return
    - [ ] Display refund calculation
    - [ ] Approve/Reject buttons
    - [ ] Add notes field
  - [ ] Create return inspection page
    - [ ] Mark items as received
    - [ ] Inspect item condition
    - [ ] Restock/Quarantine actions
  - [ ] Add return metrics to dashboard
    - [ ] Total returns count
    - [ ] Return rate percentage
    - [ ] Refund amount
    - [ ] Top return reasons

- [ ] **Exchange Management UI**
  - [ ] Create exchange requests list page
  - [ ] Create exchange request detail page
  - [ ] Process exchange action
  - [ ] Track exchange shipment

- [ ] **Testing**
  - [ ] Test all UI components
  - [ ] Test user interactions
  - [ ] Test responsive design
  - [ ] Test error handling in UI

#### 3.10 Customer Frontend Integration

- [ ] **Return Request UI**
  - [ ] Create "Request Return" button on order detail page
  - [ ] Create return request form
    - [ ] Select items to return
    - [ ] Select return reason
    - [ ] Add description
    - [ ] Upload photos (optional)
  - [ ] Create return request confirmation page
  - [ ] Create return tracking page
    - [ ] Display return status
    - [ ] Display return label (download)
    - [ ] Display tracking number
    - [ ] Display refund status

- [ ] **Exchange Request UI**
  - [ ] Create "Request Exchange" option
  - [ ] Create exchange form
    - [ ] Select items to exchange
    - [ ] Select new product/variant
    - [ ] Display price difference
  - [ ] Create exchange tracking page

- [ ] **Testing**
  - [ ] Test all UI components
  - [ ] Test user flow
  - [ ] Test mobile responsiveness
  - [ ] Test error handling

#### 3.11 Documentation

- [ ] **API Documentation**
  - [ ] Document all return endpoints
  - [ ] Document all exchange endpoints
  - [ ] Add request/response examples
  - [ ] Document error codes
  - [ ] Update OpenAPI spec

- [ ] **Business Rules Documentation**
  - [ ] Document return eligibility rules
  - [ ] Document refund calculation logic
  - [ ] Document exchange rules
  - [ ] Document return shipping policy
  - [ ] Document restocking fee policy

- [ ] **Integration Guide**
  - [ ] How to integrate with Order Service
  - [ ] How to integrate with Warehouse Service
  - [ ] How to integrate with Payment Service
  - [ ] How to integrate with Shipping Service
  - [ ] Event publishing guide

- [ ] **Admin Guide**
  - [ ] How to manage return requests
  - [ ] How to approve/reject returns
  - [ ] How to inspect returned items
  - [ ] How to process refunds
  - [ ] How to handle exchanges
  - [ ] Troubleshooting guide

- [ ] **Customer Guide**
  - [ ] How to request a return
  - [ ] How to request an exchange
  - [ ] Return policy
  - [ ] Refund timeline
  - [ ] FAQ

---

## 📊 Sprint 2 Success Criteria

- [ ] ✅ Return request flow fully functional
- [ ] ✅ Exchange request flow fully functional
- [ ] ✅ Refund processing automated
- [ ] ✅ Return shipping labels generated
- [ ] ✅ Inventory updates on returns working
- [ ] ✅ Multi-service integration complete
- [ ] ✅ All tests passing (unit + integration + E2E)
- [ ] ✅ Admin panel UI complete
- [ ] ✅ Customer frontend UI complete
- [ ] ✅ Documentation complete
- [ ] ✅ Code review approved
- [ ] ✅ Deployed to staging environment

### Overall Progress
- [ ] ✅ Order Service: 95% → 98%
- [ ] ✅ Warehouse Service: 90% → 93%
- [ ] ✅ Payment Service: 98% → 99%
- [ ] ✅ Shipping Service: 80% → 85%
- [ ] ✅ Overall Progress: 91% → 93%

---

## 🚀 Deployment Checklist

- [ ] **Pre-Deployment**
  - [ ] All tests passing
  - [ ] Code review approved
  - [ ] Documentation updated
  - [ ] Database migrations ready
  - [ ] Environment variables configured
  - [ ] Feature flags configured

- [ ] **Staging Deployment**
  - [ ] Deploy Order Service
  - [ ] Deploy Warehouse Service
  - [ ] Deploy Payment Service
  - [ ] Deploy Shipping Service
  - [ ] Deploy Admin Panel
  - [ ] Deploy Frontend
  - [ ] Run smoke tests
  - [ ] Run E2E tests
  - [ ] Verify all flows

- [ ] **Production Deployment**
  - [ ] Create deployment plan
  - [ ] Schedule maintenance window
  - [ ] Deploy database migrations
  - [ ] Deploy services (blue-green deployment)
  - [ ] Run smoke tests
  - [ ] Monitor logs and metrics
  - [ ] Verify functionality
  - [ ] Enable feature flag

- [ ] **Post-Deployment**
  - [ ] Monitor error rates
  - [ ] Monitor return request volume
  - [ ] Monitor refund processing
  - [ ] Check customer feedback
  - [ ] Update status page

---

## 📝 Notes & Issues

### Blockers
- [ ] None identified

### Risks
- [ ] High return volume may impact warehouse operations
  - **Mitigation**: Capacity planning, hire temp staff if needed
- [ ] Refund processing failures may cause customer complaints
  - **Mitigation**: Robust retry logic, manual fallback process
- [ ] Complex multi-service integration may have bugs
  - **Mitigation**: Thorough testing, phased rollout

### Dependencies
- [ ] Payment gateway must support refunds
- [ ] Shipping carriers must support return labels
- [ ] Warehouse must have return receiving process

### Questions
- [ ] What is the return window? **Answer**: 30 days from delivery
- [ ] Do we charge restocking fee? **Answer**: TBD by business
- [ ] Who pays for return shipping? **Answer**: TBD by business
- [ ] Do we support international returns? **Answer**: Phase 2

---

**Last Updated**: December 2, 2025  
**Sprint Start**: [Date]  
**Sprint End**: [Date]  
**Sprint Review**: [Date]

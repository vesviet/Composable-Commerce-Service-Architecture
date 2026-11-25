# 🔄 Return Service - Complete Documentation

> **Owner**: Platform Team  
> **Last Updated**: 2026-11-23  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: 8013/9013

**Service Name**: Return Service  
**Version**: v1.2.1  
**Review Status**: ✅ Production Ready  
**Production Ready**: 100% (All critical issues resolved, dependencies updated)  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Return APIs](#-return-apis)
- [Database Schema](#-database-schema)
- [Business Logic](#-business-logic)
- [Configuration](#-configuration)
- [Dependencies](#-dependencies)
- [Testing](#-testing)
- [Monitoring & Observability](#-monitoring--observability)
- [Known Issues & TODOs](#-known-issues--todos)
- [Development Guide](#-development-guide)

---

## 🎯 Overview

Return Service is a specialized microservice that handles the full return and refund workflow in the e-commerce platform. It was split out from Order Service to optimize customer service operations and compliance requirements.

### Core Capabilities
- **🔄 Return Management**: Manage the full return-request lifecycle
- **💰 Refund Processing**: Handle refunds with Payment Service
- **📦 Restock Coordination**: Coordinate restocking with Warehouse Service
- **📋 Return Approval**: Approval workflows for return requests
- **🔍 Return Analytics**: Analyze return patterns and insights

### Business Value
- **Customer Satisfaction**: Fast and transparent return workflows
- **Cost Optimization**: Optimize return-processing costs
- **Compliance**: Meet legal requirements for return policies
- **Operational Efficiency**: Automate the return-processing workflow

### Key Differentiators
- **Dedicated Service**: Separated from Order Service for specialized operations
- **Workflow Engine**: Flexible return approval workflows
- **Event-Driven**: Async processing with compensation patterns
- **Audit Trail**: Complete return history tracking

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
return/
├── cmd/
│   └── migrate/                   # Database migration tool
├── internal/
│   ├── biz/                       # Business Logic Layer
│   │   └── return/                # Return domain logic (validation, workflows)
│   ├── data/                      # Data Access Layer
│   │   ├── return_repo.go         # Return request repository
│   │   └── return_item_repo.go   # Return item repository
│   ├── service/                   # Service Layer (gRPC/HTTP)
│   ├── server/                    # HTTP/gRPC server, health, consul
│   ├── config/                    # Configuration
│   ├── client/                    # External service clients (Order, CatalogPolicyClient, Payment, Warehouse, Shipping)
│   └── events/                    # Outbox & Dapr event publishing
├── api/
│   └── return/v1/                # Protocol Buffers
├── migrations/                    # Database migrations
└── configs/                       # Configuration files
```

**Note**: All order-related models and repositories have been removed. Return Service now calls Order Service via gRPC to fetch order information. **Server entry point**: `cmd/return` (Kratos app + Wire); run with `make run` or `go run ./cmd/return -conf configs`. Health: `/health`, `/health/ready`, `/health/live`; metrics: `/metrics`.

### Ports & Endpoints
- **HTTP API**: `:8013` - REST endpoints for customer service and the frontend
- **gRPC API**: `:9013` - Internal service communication
- **Health Check**: `/api/v1/returns/health`

### Service Dependencies

#### Internal Dependencies (via gRPC)
- **Order Service**: Order information and validation (gRPC client)
  - Fetches order details via `GetOrder(orderID)`
  - Fetches order items via `GetOrderItems(orderID)`
  - **Important**: No local order models or repositories - all order data fetched from Order Service
- **Payment Service**: Refund processing (gRPC client)
- **Warehouse Service**: Restock coordination (gRPC client)
- **Shipping Service**: Return shipping labels (gRPC client)
- **Customer Service**: Customer data and communication (gRPC client)
- **Notification Service**: Return status notifications (gRPC client)
- **Catalog Service**: Per-category `return_window_days` policy lookup (`CatalogPolicyClient`)

#### External Dependencies
- **PostgreSQL**: Return data (`return_db`)
  - Tables: `return_requests`, `return_items`
  - No order-related tables (removed during cleanup)
- **Redis**: Caching, workflow state (planned, not yet implemented)
- **Dapr**: Event-driven communication via Transactional Outbox

---

## 🔄 Return APIs

### Return Request Management

#### Create Return Request
```protobuf
rpc CreateReturnRequest(CreateReturnRequestRequest) returns (CreateReturnRequestResponse) {
  option (google.api.http) = {
    post: "/api/v1/returns"
    body: "*"
  };
}
```

**Flow**:
1. Validate order eligibility
2. Check return window
3. Create return request
4. Initiate approval workflow
5. Notify customer service

#### Get Return Request
```protobuf
rpc GetReturnRequest(GetReturnRequestRequest) returns (GetReturnRequestResponse) {
  option (google.api.http) = {
    get: "/api/v1/returns/{return_id}"
  };
}
```

#### Update Return Status
```protobuf
rpc RejectReturn(RejectReturnRequest) returns (ReturnRequest) {
  option (google.api.http) = {
    post: "/api/v1/returns/{return_id}/reject"
    body: "*"
  };
}

rpc ReceiveItems(ReceiveItemsRequest) returns (ReturnRequest) {
  option (google.api.http) = {
    post: "/api/v1/returns/{return_id}/receive"
    body: "*"
  };
}

rpc ProcessRefund(ProcessRefundRequest) returns (ReturnRequest) {
  option (google.api.http) = {
    post: "/api/v1/returns/{return_id}/refund"
    body: "*"
  };
}

rpc CancelReturn(CancelReturnRequest) returns (ReturnRequest) {
  option (google.api.http) = {
    post: "/api/v1/returns/{return_id}/cancel"
    body: "*"
  };
}

rpc CheckReturnEligibility(CheckReturnEligibilityRequest) returns (CheckReturnEligibilityResponse) {
  option (google.api.http) = {
    get: "/api/v1/orders/{order_id}/return-eligibility"
    additional_bindings {
      get: "/api/v1/returns/eligibility/{order_id}"
    }
  };
}

rpc CreateExchangeRequest(CreateExchangeRequestRequest) returns (ReturnRequest) {
  option (google.api.http) = {
    post: "/api/v1/returns/exchange"
    body: "*"
  };
}
```

### Evidence Media Endpoints (HTTP)
- `POST /api/v1/returns/evidence` — Upload return evidence image (50MB gateway limit allowlist, magic-byte & extension validated)
- `GET /api/v1/returns/evidence/{filename}` — Serve stored return evidence media
- **Fields**: `evidence_urls` (persisted array on return requests), `rejected_by` (moderator identity recorded on rejection), per-category `return_window_days` via `CatalogPolicyClient`

---

## 🗄️ Database Schema

### Core Tables

#### return_requests
```sql
CREATE TABLE return_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  return_number VARCHAR(50) UNIQUE NOT NULL,
  order_id UUID NOT NULL,
  customer_id UUID NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'requested',
  
  -- Return Information
  return_reason VARCHAR(100) NOT NULL,
  return_description TEXT,
  return_type VARCHAR(20) NOT NULL DEFAULT 'refund', -- refund, exchange, store_credit
  
  -- Financial Information
  total_refund_amount DECIMAL(10,2) DEFAULT 0,
  refund_shipping BOOLEAN DEFAULT false,
  refund_tax BOOLEAN DEFAULT true,
  
  -- Processing Information
  approved_by VARCHAR(255),
  approved_at TIMESTAMP WITH TIME ZONE,
  processed_by VARCHAR(255),
  processed_at TIMESTAMP WITH TIME ZONE,
  
  -- Shipping Information
  return_shipping_label_url VARCHAR(500),
  return_tracking_number VARCHAR(100),
  
  -- Metadata
  metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE
);
```

#### return_items
```sql
CREATE TABLE return_items (
  id BIGSERIAL PRIMARY KEY,
  return_request_id UUID NOT NULL REFERENCES return_requests(id),
  order_item_id BIGINT NOT NULL,
  product_id UUID NOT NULL,
  product_sku VARCHAR(255) NOT NULL,
  product_name VARCHAR(500) NOT NULL,
  
  -- Return Details
  quantity_returned INTEGER NOT NULL,
  quantity_received INTEGER DEFAULT 0,
  return_reason VARCHAR(100),
  condition_received VARCHAR(50), -- new, used, damaged, defective
  
  -- Financial Information
  unit_price DECIMAL(10,2) NOT NULL,
  refund_amount DECIMAL(10,2) NOT NULL,
  
  -- Processing Information
  restocked BOOLEAN DEFAULT false,
  restocked_at TIMESTAMP WITH TIME ZONE,
  warehouse_id UUID,
  
  -- Metadata
  metadata JSONB DEFAULT '{}'
);
```

#### return_status_history
```sql
CREATE TABLE return_status_history (
  id BIGSERIAL PRIMARY KEY,
  return_request_id UUID NOT NULL REFERENCES return_requests(id),
  status_from VARCHAR(20),
  status_to VARCHAR(20) NOT NULL,
  changed_by VARCHAR(255),
  reason TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### return_refunds
```sql
CREATE TABLE return_refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  return_request_id UUID NOT NULL REFERENCES return_requests(id),
  payment_id VARCHAR(255) NOT NULL,
  refund_method VARCHAR(50) NOT NULL, -- original_payment, store_credit, bank_transfer
  
  -- Refund Details
  refund_amount DECIMAL(10,2) NOT NULL,
  refund_currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  refund_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  
  -- External References
  payment_service_refund_id VARCHAR(255),
  external_refund_id VARCHAR(255),
  
  -- Processing Information
  processed_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Performance Optimizations

#### Indexes
```sql
-- Return requests
CREATE INDEX idx_return_requests_order ON return_requests(order_id);
CREATE INDEX idx_return_requests_customer ON return_requests(customer_id);
CREATE INDEX idx_return_requests_status ON return_requests(status);
CREATE INDEX idx_return_requests_created ON return_requests(created_at DESC);
CREATE INDEX idx_return_requests_number ON return_requests(return_number);

-- Return items
CREATE INDEX idx_return_items_request ON return_items(return_request_id);
CREATE INDEX idx_return_items_order_item ON return_items(order_item_id);
CREATE INDEX idx_return_items_product ON return_items(product_id);

-- Status history
CREATE INDEX idx_return_status_history_request ON return_status_history(return_request_id);
CREATE INDEX idx_return_status_history_created ON return_status_history(created_at DESC);

-- Refunds
CREATE INDEX idx_return_refunds_request ON return_refunds(return_request_id);
CREATE INDEX idx_return_refunds_status ON return_refunds(refund_status);
```

---

## 💼 Business Logic

### Return Request Processing

**Important**: Return Service calls Order Service via gRPC to fetch order information. No local order models are used.

```go
func (uc *ReturnUsecase) CreateReturnRequest(ctx context.Context, req *CreateReturnRequestRequest) (*ReturnRequest, error) {
    // 1. Fetch order information from Order Service (via gRPC)
    orderInfo, err := uc.orderService.GetOrder(ctx, req.OrderID)
    if err != nil {
        return nil, fmt.Errorf("failed to fetch order: %w", err)
    }
    
    // 2. Fetch order items from Order Service
    orderItems, err := uc.orderService.GetOrderItems(ctx, req.OrderID)
    if err != nil {
        return nil, fmt.Errorf("failed to fetch order items: %w", err)
    }
    
    // 3. Validate return eligibility using Order Service data
    if err := validateReturnWindow(orderInfo, 30); err != nil {
        return nil, err
    }
    if err := validateReturnItems(orderItems, req.Items); err != nil {
        return nil, err
    }
    
    // 4. Create return request
    returnReq := &ReturnRequest{
        ID:           uuid.New(),
        ReturnNumber: uc.generateReturnNumber(),
        OrderID:      req.OrderID,
        CustomerID:   orderInfo.CustomerID,
        Status:       "pending",
        Reason:       req.Reason,
        ReturnType:   "return",
        ExpiresAt:    time.Now().Add(30 * 24 * time.Hour), // 30 days
    }
    
    // 5. Create return items
    for _, item := range req.Items {
        returnItem := &ReturnItem{
            ReturnRequestID: returnReq.ID,
            OrderItemID:     item.OrderItemID,
            ProductID:       item.ProductID,
            ProductSKU:      item.ProductSKU,
            Quantity:        item.Quantity,
            Reason:          item.Reason,
        }
        // Add to return request items
    }
    
    // 6. Save return request
    if err := uc.returnRequestRepo.Create(ctx, returnReq); err != nil {
        return nil, err
    }
    
    // 7. Publish return.requested outbox event
    // 8. Record evidence_urls and CatalogPolicyClient window check
    
    return returnReq, nil
}
```

### Return Approval Workflow

```go
func (uc *ReturnUsecase) ApproveReturnRequest(ctx context.Context, returnID string, approverID string) error {
    // 1. Get return request
    returnReq, err := uc.repo.GetReturnRequest(ctx, returnID)
    if err != nil {
        return err
    }
    
    // 2. Validate can be approved
    if returnReq.Status != "under_review" {
        return commonErrors.NewValidationError("Return request cannot be approved in current status")
    }
    
    // 3. Update status
    returnReq.Status = "approved"
    returnReq.ApprovedBy = approverID
    returnReq.ApprovedAt = time.Now()
    
    // 4. Generate return shipping label
    shippingLabel, err := uc.generateReturnShippingLabel(ctx, returnReq)
    if err != nil {
        uc.logger.Errorf("Failed to generate shipping label: %v", err)
    } else {
        returnReq.ReturnShippingLabelURL = shippingLabel.URL
        returnReq.ReturnTrackingNumber = shippingLabel.TrackingNumber
    }
    
    // 5. Save changes
    if err := uc.repo.UpdateReturnRequest(ctx, returnReq); err != nil {
        return err
    }
    
    // 6. Create status history
    if err := uc.createStatusHistory(ctx, returnReq, "under_review", "approved", approverID); err != nil {
        uc.logger.Errorf("Failed to create status history: %v", err)
    }
    
    // 7. Publish approval event
    if err := uc.publishReturnApproved(ctx, returnReq); err != nil {
        uc.logger.Errorf("Failed to publish return approved event: %v", err)
    }
    
    // 8. Notify customer
    if err := uc.notifyCustomerApproval(ctx, returnReq); err != nil {
        uc.logger.Errorf("Failed to notify customer: %v", err)
    }
    
    return nil
}
```

### Refund Processing

```go
func (uc *ReturnUsecase) ProcessRefund(ctx context.Context, returnID string) error {
    // 1. Get return request
    returnReq, err := uc.repo.GetReturnRequest(ctx, returnID)
    if err != nil {
        return err
    }
    
    // 2. Validate items received
    if returnReq.Status != "items_received" {
        return commonErrors.NewValidationError("Items must be received before processing refund")
    }
    
    // 3. Calculate final refund amount based on received items
    refundAmount := uc.calculateFinalRefundAmount(ctx, returnReq)
    
    // 4. Create refund record
    refund := &ReturnRefund{
        ID:               uuid.New(),
        ReturnRequestID:  returnReq.ID,
        PaymentID:        returnReq.OriginalPaymentID,
        RefundMethod:     "original_payment",
        RefundAmount:     refundAmount,
        RefundCurrency:   "USD",
        RefundStatus:     "pending",
    }
    
    // 5. Process refund with Payment Service
    paymentRefund, err := uc.paymentService.ProcessRefund(ctx, &payment.ProcessRefundRequest{
        PaymentID:    refund.PaymentID,
        RefundAmount: refund.RefundAmount,
        Reason:       "return_refund",
        IdempotencyKey: refund.ID.String(),
    })
    if err != nil {
        return fmt.Errorf("failed to process refund: %w", err)
    }
    
    // 6. Update refund with payment service response
    refund.PaymentServiceRefundID = paymentRefund.RefundID
    refund.ExternalRefundID = paymentRefund.ExternalRefundID
    refund.RefundStatus = "processing"
    refund.ProcessedAt = time.Now()
    
    // 7. Save refund record
    if err := uc.repo.CreateRefund(ctx, refund); err != nil {
        return err
    }
    
    // 8. Update return request status
    returnReq.Status = "refund_processing"
    if err := uc.repo.UpdateReturnRequest(ctx, returnReq); err != nil {
        return err
    }
    
    // 9. Publish refund processing event
    if err := uc.publishRefundProcessing(ctx, returnReq, refund); err != nil {
        uc.logger.Errorf("Failed to publish refund processing event: %v", err)
    }
    
    return nil
}
```

### Restock Coordination

```go
func (uc *ReturnUsecase) RestockItems(ctx context.Context, returnID string) error {
    // 1. Get return request with items
    returnReq, err := uc.repo.GetReturnRequestWithItems(ctx, returnID)
    if err != nil {
        return err
    }
    
    // 2. Filter items eligible for restock
    restockableItems := make([]*ReturnItem, 0)
    for _, item := range returnReq.Items {
        if item.ConditionReceived == "new" || item.ConditionReceived == "used" {
            restockableItems = append(restockableItems, item)
        }
    }
    
    // 3. Process restock for each item
    for _, item := range restockableItems {
        restockReq := &warehouse.RestockItemRequest{
            ProductID:       item.ProductID,
            ProductSKU:      item.ProductSKU,
            Quantity:        item.QuantityReceived,
            Condition:       item.ConditionReceived,
            WarehouseID:     item.WarehouseID,
            SourceType:      "return",
            SourceReference: returnReq.ReturnNumber,
        }
        
        // Call warehouse service
        _, err := uc.warehouseService.RestockItem(ctx, restockReq)
        if err != nil {
            uc.logger.Errorf("Failed to restock item %s: %v", item.ProductSKU, err)
            continue
        }
        
        // Update item as restocked
        item.Restocked = true
        item.RestockedAt = time.Now()
        if err := uc.repo.UpdateReturnItem(ctx, item); err != nil {
            uc.logger.Errorf("Failed to update return item: %v", err)
        }
    }
    
    // 4. Publish restock completed event
    if err := uc.publishRestockCompleted(ctx, returnReq, restockableItems); err != nil {
        uc.logger.Errorf("Failed to publish restock completed event: %v", err)
    }
    
    return nil
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
RETURN_DATABASE_DSN=postgres://return_user:return_pass@postgres:5432/return_db?sslmode=disable

# Redis
RETURN_REDIS_ADDR=redis:6379
RETURN_REDIS_PASSWORD=
RETURN_REDIS_DB=3

# Service Ports
RETURN_HTTP_PORT=8013
RETURN_GRPC_PORT=9013

# Return Configuration
RETURN_WINDOW_DAYS=30
RETURN_AUTO_APPROVE_THRESHOLD=100.00
RETURN_SHIPPING_LABEL_PROVIDER=shippo

# External Services
RETURN_ORDER_SERVICE_ADDR=order-service:9004
RETURN_CUSTOMER_SERVICE_ADDR=customer-service:9003
RETURN_PAYMENT_SERVICE_ADDR=payment-service:9005
RETURN_WAREHOUSE_SERVICE_ADDR=warehouse-service:9006
RETURN_SHIPPING_SERVICE_ADDR=shipping-service:9012
RETURN_NOTIFICATION_SERVICE_ADDR=notification-service:9009

# Features
RETURN_ENABLE_AUTO_APPROVAL=true
RETURN_ENABLE_EXCHANGES=true
RETURN_ENABLE_STORE_CREDIT=true
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/return

go 1.27.4

require (
    gitlab.com/ta-microservices/common v1.37.1
    github.com/go-kratos/kratos/v2 v2.9.2
    github.com/redis/go-redis/v9 v9.16.0
    gorm.io/gorm v1.31.1
    google.golang.org/protobuf v1.36.10
    github.com/google/uuid v1.6.0
    golang.org/x/sync v0.19.0
)
```

**Updated**: January 29, 2026
- Common package: v1.7.2 → v1.8.3
- Kratos: v2.9.1 → v2.9.2

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: 80% coverage (business logic)
- **Integration Tests**: 65% coverage (API endpoints, external services)
- **E2E Tests**: 50% coverage (complete return flows)

### Critical Test Scenarios

#### Return Request Tests
```go
func TestCreateReturnRequest_Success(t *testing.T) {
    // Test successful return request creation
    // Verify all validations pass
    // Verify events published
}

func TestCreateReturnRequest_ExpiredOrder(t *testing.T) {
    // Test return request for expired order
    // Verify proper error handling
}

func TestReturnApprovalWorkflow(t *testing.T) {
    // Test complete approval workflow
    // Verify status transitions
    // Verify notifications sent
}
```

#### Refund Processing Tests
```go
func TestProcessRefund_Success(t *testing.T) {
    // Test successful refund processing
    // Mock payment service responses
    // Verify refund record created
}

func TestProcessRefund_PaymentFailure(t *testing.T) {
    // Test payment service failure
    // Verify error handling
    // Verify no partial state
}
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### Return Metrics
```go
# Return operations
return_requests_created_total 234
return_requests_approved_total 198
return_requests_rejected_total 36

# Return processing
return_refunds_processed_total 187
return_items_restocked_total 156

# Business metrics
return_rate 0.12  # Returns / Orders
return_approval_rate 0.85  # Approved / Requested
return_processing_time_hours{quantile="0.95"} 48
```

#### Financial Metrics
```go
# Refund amounts
return_refund_amount_total 45678.90
return_average_refund_amount 234.56

# Cost metrics
return_processing_cost_total 1234.56
return_shipping_cost_total 567.89
```

### Health Checks
```go
# Application health
GET /api/v1/returns/health

# Dependencies health
GET /api/v1/returns/health/dependencies

# Workflow health
GET /api/v1/returns/health/workflow
```

---

## 🚨 Known Issues & TODOs

### Order Logic Cleanup (Completed January 29, 2026)

**Status**: ✅ Complete  
**Changes**:
- Removed all order-related models (`order.go`, `order_item.go`, `order_address.go`, `order_payment.go`, `order_status_history.go`, `cart.go`, `checkout_session.go`, `shipment.go`, `failed_compensation.go`)
- Removed all order-related repositories (`order/`, `cart/`, `checkout/`, `item/`, `address/`, `payment/`, `status/`, `edit_history/`, `failed_compensation/`)
- Refactored validation functions to use Order Service client instead of local models
- Added `OrderService`, `CatalogPolicyClient`, `PaymentService`, `WarehouseService`, and `ShippingService` production integrations (10 Proto RPCs + HTTP evidence endpoints)
- Added `evidence_urls`, `rejected_by`, per-category `return_window_days` check, and Transactional Outbox event publishing
- **Last Updated**: 2026-11-25 (`go 1.27.4`, `Kratos v2.9.2`, `common v1.37.1`)

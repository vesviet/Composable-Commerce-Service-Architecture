# 📋 SHIPPING SERVICE IMPLEMENTATION CHECKLIST

**Service**: Shipping & Fulfillment Service  
**Current Status**: 15% (Basic structure only)  
**Target**: Production-ready shipping service  
**Estimated Time**: 5-6 weeks (200-240 hours)  
**Team Size**: 2-3 developers  
**Last Updated**: November 12, 2025

---

## 📊 OVERALL STATUS: 15% COMPLETE

### ✅ COMPLETED (15%)
- Basic project structure
- Database migrations (5 tables)
- Proto file definition
- README documentation

### 🔴 MISSING (85%)
- Core business logic (0%)
- Carrier integrations (0%)
- Service layer (0%)
- Testing (0%)
- Monitoring (0%)

---

## 🎯 PHASE 1: PROJECT SETUP & INFRASTRUCTURE (Week 1)

### 1.1. Project Structure Verification (Day 1 - 4 hours)

**Status**: 🟡 Partial (30%)

- [x] Verify existing project structure
- [x] Database migrations exist
- [x] Proto file exists
- [ ] Create missing directories
- [ ] Setup Go modules dependencies
- [ ] Configure Makefile
- [ ] Setup Docker and docker-compose

**Directory Structure to Create**:
```
shipping/
├── cmd/
│   └── shipping/
│       ├── main.go          # ❌ Missing
│       └── wire.go          # ❌ Missing
├── internal/
│   ├── biz/                 # ❌ Missing
│   │   ├── fulfillment.go
│   │   ├── shipment.go
│   │   ├── carrier.go
│   │   ├── tracking.go
│   │   └── biz.go
│   ├── data/                # ❌ Missing
│   │   ├── fulfillment.go
│   │   ├── shipment.go
│   │   ├── carrier.go
│   │   └── data.go
│   ├── service/             # ❌ Missing
│   │   ├── shipping.go
│   │   ├── webhook.go
│   │   └── service.go
│   ├── server/              # ❌ Missing
│   │   ├── http.go
│   │   ├── grpc.go
│   │   └── consul.go
│   └── conf/                # ❌ Missing
│       ├── conf.proto
│       └── conf.pb.go
```

**Estimated Effort**: 4 hours


### 1.2. Configuration Setup (Day 1 - 2 hours)

**Status**: 🟡 Partial (40%)

- [x] Basic config.yaml exists
- [ ] Add carrier configurations
- [ ] Add fulfillment settings
- [ ] Add shipping rules
- [ ] Create config-dev.yaml
- [ ] Generate conf.proto and conf.pb.go

**Configuration Sections to Add**:
```yaml
# Carrier configurations
carriers:
  ups:
    api_url: ${UPS_API_URL}
    access_key: ${UPS_ACCESS_KEY}
    username: ${UPS_USERNAME}
    password: ${UPS_PASSWORD}
    account_number: ${UPS_ACCOUNT_NUMBER}
    sandbox: true
    enabled: true
  fedex:
    api_url: ${FEDEX_API_URL}
    key: ${FEDEX_KEY}
    password: ${FEDEX_PASSWORD}
    account_number: ${FEDEX_ACCOUNT_NUMBER}
    meter_number: ${FEDEX_METER_NUMBER}
    sandbox: true
    enabled: true

# Fulfillment settings
fulfillment:
  auto_fulfill_enabled: true
  batch_size: 50
  pick_timeout_minutes: 60
  pack_timeout_minutes: 30
  default_warehouse_id: "WH001"

# Shipping rules
shipping:
  free_shipping_threshold: 75.00
  max_package_weight: 70.0
  max_package_dimensions: "24x24x24"
  default_carrier: "ups"
  insurance_threshold: 100.00
  signature_required_threshold: 500.00
```

**Estimated Effort**: 2 hours


### 1.3. Database Migrations Review (Day 1 - 2 hours)

**Status**: ✅ Complete (100%)

- [x] 001_create_shipments_table.sql
- [x] 002_create_fulfillments_table.sql
- [x] 003_create_carriers_table.sql
- [x] 004_create_tracking_events_table.sql
- [x] 005_create_returns_table.sql

**Verification Checklist**:
- [x] All tables have proper indexes
- [x] All foreign keys defined
- [x] All constraints in place
- [x] Timestamps with triggers
- [x] JSONB columns for flexible data

**Action**: Run migrations and verify
```bash
cd shipping
make migrate-up DATABASE_URL="postgres://user:pass@localhost:5432/shipping_db?sslmode=disable"
```

**Estimated Effort**: 2 hours

---

### 1.4. Proto File Generation (Day 2 - 4 hours)

**Status**: 🟡 Partial (50%)

- [x] shipping.proto exists
- [ ] Verify all endpoints match documentation
- [ ] Add missing message types
- [ ] Generate Go code from proto
- [ ] Verify generated files compile

**Commands**:
```bash
cd shipping
make api  # Generate proto files
go build ./api/...  # Verify compilation
```

**Generated Files to Verify**:
```
api/shipping/v1/shipping.pb.go
api/shipping/v1/shipping_grpc.pb.go
api/shipping/v1/shipping_http.pb.go
```

**Estimated Effort**: 4 hours


### 1.5. Wire Dependency Injection Setup (Day 2 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create wire.go in cmd/shipping/
- [ ] Define ProviderSet for each layer
- [ ] Generate wire_gen.go
- [ ] Verify dependency injection works
- [ ] Test service startup

**Wire Setup**:
```go
// cmd/shipping/wire.go
//go:build wireinject
// +build wireinject

package main

import (
    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/google/wire"
    
    "gitlab.com/ta-microservices/shipping/internal/biz"
    "gitlab.com/ta-microservices/shipping/internal/conf"
    "gitlab.com/ta-microservices/shipping/internal/data"
    "gitlab.com/ta-microservices/shipping/internal/server"
    "gitlab.com/ta-microservices/shipping/internal/service"
)

func wireApp(*conf.Server, *conf.Data, *conf.Consul, log.Logger) (*kratos.App, func(), error) {
    panic(wire.Build(
        server.ProviderSet,
        data.ProviderSet,
        biz.ProviderSet,
        service.ProviderSet,
        newApp,
    ))
}
```

**Commands**:
```bash
cd shipping
make wire  # Generate wire code
go build ./cmd/shipping  # Verify build
```

**Estimated Effort**: 4 hours


### 1.6. Server Setup (HTTP + gRPC + Consul) (Day 3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement HTTP server setup
- [ ] Implement gRPC server setup
- [ ] Implement Consul registration
- [ ] Add health check endpoint
- [ ] Add metrics endpoint
- [ ] Test server startup

**Files to Create**:
```
internal/server/http.go
internal/server/grpc.go
internal/server/consul.go
```

**Health Check Response**:
```json
{
  "status": "healthy",
  "service": "shipping-service",
  "version": "v1.0.0",
  "dependencies": {
    "database": "healthy",
    "redis": "healthy",
    "consul": "healthy"
  }
}
```

**Estimated Effort**: 6 hours

---

### 1.7. Data Layer Foundation (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create data.go with database connection
- [ ] Setup GORM connection
- [ ] Setup Redis connection
- [ ] Create base repository interfaces
- [ ] Implement transaction support
- [ ] Add connection pooling

**Files to Create**:
```
internal/data/data.go
internal/data/postgres/db.go
internal/data/postgres/transaction.go
```

**Key Features**:
- [ ] Database connection with retry logic
- [ ] Redis connection with health check
- [ ] Transaction support for multi-step operations
- [ ] Connection pooling configuration
- [ ] Graceful shutdown handling

**Estimated Effort**: 8 hours


### 1.8. Basic Service Startup Test (Day 4 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Build service binary
- [ ] Run migrations
- [ ] Start service locally
- [ ] Test health endpoint
- [ ] Test Consul registration
- [ ] Verify logs
- [ ] Test graceful shutdown

**Test Commands**:
```bash
# Build
make build

# Run migrations
make migrate-up

# Start service
./bin/shipping -conf ./configs

# Test health
curl http://localhost:8006/health

# Check Consul
curl http://localhost:8500/v1/health/service/shipping-service
```

**Estimated Effort**: 4 hours

**PHASE 1 TOTAL**: 34 hours (Week 1)

---

## 🎯 PHASE 2: CORE BUSINESS LOGIC (Week 2)

### 2.1. Domain Entities (Day 1 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Define Fulfillment entity
- [ ] Define Shipment entity
- [ ] Define Carrier entity
- [ ] Define TrackingEvent entity
- [ ] Define Return entity
- [ ] Add validation logic
- [ ] Add business rules

**Files to Create**:
```
internal/biz/fulfillment.go
internal/biz/shipment.go
internal/biz/carrier.go
internal/biz/tracking.go
internal/biz/return.go
```

**Domain Entities**:
```go
type Fulfillment struct {
    ID              string
    OrderID         string
    WarehouseID     string
    CustomerID      string
    Type            FulfillmentType
    Status          FulfillmentStatus
    Items           []FulfillmentItem
    OriginAddress   Address
    DestinationAddress Address
    CarrierID       string
    TrackingNumber  string
    EstimatedDelivery time.Time
    // ... more fields
}

type FulfillmentStatus string
const (
    FulfillmentStatusCreated       FulfillmentStatus = "created"
    FulfillmentStatusConfirmed     FulfillmentStatus = "confirmed"
    FulfillmentStatusPickedUp      FulfillmentStatus = "picked_up"
    FulfillmentStatusInTransit     FulfillmentStatus = "in_transit"
    FulfillmentStatusOutForDelivery FulfillmentStatus = "out_for_delivery"
    FulfillmentStatusDelivered     FulfillmentStatus = "delivered"
    FulfillmentStatusFailed        FulfillmentStatus = "failed"
    FulfillmentStatusCancelled     FulfillmentStatus = "cancelled"
)
```

**Estimated Effort**: 4 hours


### 2.2. Repository Interfaces (Day 1 - 2 hours)

**Status**: ❌ Not Started (0%)

- [ ] Define FulfillmentRepo interface
- [ ] Define ShipmentRepo interface
- [ ] Define CarrierRepo interface
- [ ] Define TrackingEventRepo interface
- [ ] Define ReturnRepo interface

**Interface Example**:
```go
// internal/biz/fulfillment.go
type FulfillmentRepo interface {
    Create(ctx context.Context, fulfillment *Fulfillment) error
    FindByID(ctx context.Context, id string) (*Fulfillment, error)
    FindByOrderID(ctx context.Context, orderID string) ([]*Fulfillment, error)
    Update(ctx context.Context, fulfillment *Fulfillment) error
    UpdateStatus(ctx context.Context, id string, status FulfillmentStatus) error
    List(ctx context.Context, filters map[string]interface{}, offset, limit int) ([]*Fulfillment, int64, error)
}
```

**Estimated Effort**: 2 hours

---

### 2.3. Repository Implementation (Day 2 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement FulfillmentRepo
- [ ] Implement ShipmentRepo
- [ ] Implement CarrierRepo
- [ ] Implement TrackingEventRepo
- [ ] Implement ReturnRepo
- [ ] Add GORM models
- [ ] Add conversion functions
- [ ] Add error handling

**Files to Create**:
```
internal/data/fulfillment.go
internal/data/shipment.go
internal/data/carrier.go
internal/data/tracking.go
internal/data/return.go
```

**Key Features**:
- [ ] GORM model definitions
- [ ] Conversion functions (toBiz/fromBiz)
- [ ] Proper error handling
- [ ] Context propagation
- [ ] Soft deletes where needed

**Estimated Effort**: 6 hours


### 2.4. Fulfillment Usecase - Create Fulfillment (Day 2-3 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement CreateFulfillment usecase
- [ ] Add order validation (call Order Service)
- [ ] Add warehouse validation
- [ ] Add address validation
- [ ] Calculate shipping rates
- [ ] Select optimal carrier
- [ ] Create fulfillment record
- [ ] Publish fulfillment.created event
- [ ] Add error handling

**Files to Create**:
```
internal/biz/fulfillment_usecase.go
```

**Create Fulfillment Flow**:
1. Validate order exists and is ready for fulfillment
2. Validate warehouse has inventory
3. Validate destination address
4. Calculate package dimensions and weight
5. Get shipping rates from carriers
6. Select optimal carrier based on cost/speed
7. Create fulfillment record (status: created)
8. Publish fulfillment.created event
9. Return fulfillment details

**Code Structure**:
```go
func (uc *FulfillmentUsecase) CreateFulfillment(ctx context.Context, req *CreateFulfillmentRequest) (*Fulfillment, error) {
    // 1. Validate order
    order, err := uc.orderClient.GetOrder(ctx, req.OrderID)
    if err != nil {
        return nil, err
    }
    
    // 2. Validate warehouse
    warehouse, err := uc.warehouseClient.GetWarehouse(ctx, req.WarehouseID)
    if err != nil {
        return nil, err
    }
    
    // 3. Validate address
    if err := uc.addressValidator.Validate(req.DestinationAddress); err != nil {
        return nil, err
    }
    
    // 4. Calculate dimensions
    dimensions := uc.calculatePackageDimensions(req.Items)
    
    // 5. Get shipping rates
    rates, err := uc.rateCalculator.CalculateRates(ctx, &RateRequest{
        Origin: warehouse.Address,
        Destination: req.DestinationAddress,
        Packages: dimensions,
    })
    if err != nil {
        return nil, err
    }
    
    // 6. Select carrier
    selectedRate := uc.selectOptimalCarrier(rates, req.Preferences)
    
    // 7. Create fulfillment
    fulfillment := &Fulfillment{
        OrderID: req.OrderID,
        WarehouseID: req.WarehouseID,
        CustomerID: req.CustomerID,
        Type: req.Type,
        Status: FulfillmentStatusCreated,
        Items: req.Items,
        OriginAddress: warehouse.Address,
        DestinationAddress: req.DestinationAddress,
        CarrierID: selectedRate.CarrierID,
        EstimatedDelivery: selectedRate.EstimatedDelivery,
    }
    
    if err := uc.fulfillmentRepo.Create(ctx, fulfillment); err != nil {
        return nil, err
    }
    
    // 8. Publish event
    uc.eventPublisher.PublishFulfillmentCreated(ctx, fulfillment)
    
    return fulfillment, nil
}
```

**Estimated Effort**: 8 hours


### 2.5. Carrier Integration Layer (Day 3-4 - 10 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create carrier interface
- [ ] Implement UPS carrier
- [ ] Implement FedEx carrier
- [ ] Add carrier factory
- [ ] Add rate calculation
- [ ] Add label generation
- [ ] Add tracking integration
- [ ] Add error mapping
- [ ] Add retry logic

**Files to Create**:
```
internal/biz/carrier/
  ├── carrier.go          # Interface
  ├── ups.go              # UPS implementation
  ├── fedex.go            # FedEx implementation
  └── factory.go          # Carrier factory
```

**Carrier Interface**:
```go
type Carrier interface {
    // Rate calculation
    CalculateRates(ctx context.Context, req *RateRequest) ([]*ShippingRate, error)
    
    // Shipment creation
    CreateShipment(ctx context.Context, req *CreateShipmentRequest) (*ShipmentResult, error)
    
    // Label generation
    GenerateLabel(ctx context.Context, shipmentID string) (*Label, error)
    
    // Tracking
    GetTracking(ctx context.Context, trackingNumber string) (*TrackingInfo, error)
    
    // Cancellation
    CancelShipment(ctx context.Context, shipmentID string) error
    
    // Webhook validation
    ValidateWebhook(ctx context.Context, payload []byte, signature string) error
    ProcessWebhook(ctx context.Context, payload []byte) (*WebhookEvent, error)
}
```

**UPS Implementation**:
- [ ] Initialize UPS client
- [ ] Implement CalculateRates (UPS Rating API)
- [ ] Implement CreateShipment (UPS Shipping API)
- [ ] Implement GenerateLabel
- [ ] Implement GetTracking (UPS Tracking API)
- [ ] Implement webhook validation
- [ ] Add error handling and mapping

**Estimated Effort**: 10 hours


### 2.6. Rate Calculator (Day 4 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create rate calculator interface
- [ ] Implement multi-carrier rate comparison
- [ ] Add rate caching (Redis)
- [ ] Add carrier selection logic
- [ ] Add cost optimization
- [ ] Add delivery time optimization

**Files to Create**:
```
internal/biz/rate/
  ├── calculator.go
  ├── selector.go
  └── cache.go
```

**Rate Calculator Features**:
- [ ] Query multiple carriers in parallel
- [ ] Cache rates for 1 hour
- [ ] Compare rates by cost and delivery time
- [ ] Apply business rules (free shipping threshold)
- [ ] Handle carrier failures gracefully

**Estimated Effort**: 4 hours

---

### 2.7. Fulfillment Usecase - Other Operations (Day 5 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement ConfirmFulfillment usecase
- [ ] Implement ShipFulfillment usecase
- [ ] Implement UpdateFulfillmentStatus usecase
- [ ] Implement CancelFulfillment usecase
- [ ] Implement GetFulfillment usecase
- [ ] Implement ListFulfillments usecase
- [ ] Add proper error handling
- [ ] Add logging

**Use Cases to Implement**:
```go
func (uc *FulfillmentUsecase) ConfirmFulfillment(ctx context.Context, id string) (*Fulfillment, error)
func (uc *FulfillmentUsecase) ShipFulfillment(ctx context.Context, id string) (*Fulfillment, error)
func (uc *FulfillmentUsecase) UpdateStatus(ctx context.Context, id string, status FulfillmentStatus) (*Fulfillment, error)
func (uc *FulfillmentUsecase) CancelFulfillment(ctx context.Context, id string, reason string) (*Fulfillment, error)
func (uc *FulfillmentUsecase) GetFulfillment(ctx context.Context, id string) (*Fulfillment, error)
func (uc *FulfillmentUsecase) ListFulfillments(ctx context.Context, req *ListFulfillmentsRequest) ([]*Fulfillment, int, error)
```

**Estimated Effort**: 6 hours

**PHASE 2 TOTAL**: 40 hours (Week 2)

---

## 🎯 PHASE 3: TRACKING & WEBHOOKS (Week 3)

### 3.1. Tracking System (Day 1 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement tracking event storage
- [ ] Implement GetTracking usecase
- [ ] Add tracking cache (Redis)
- [ ] Add tracking event processing
- [ ] Add tracking history
- [ ] Publish tracking.updated events

**Tracking Operations**:
```go
func (uc *TrackingUsecase) GetTracking(ctx context.Context, trackingNumber string) (*TrackingInfo, error)
func (uc *TrackingUsecase) AddTrackingEvent(ctx context.Context, event *TrackingEvent) error
func (uc *TrackingUsecase) GetTrackingHistory(ctx context.Context, trackingNumber string) ([]*TrackingEvent, error)
func (uc *TrackingUsecase) UpdateFromCarrier(ctx context.Context, trackingNumber string) error
```

**Estimated Effort**: 6 hours


### 3.2. Webhook Handling (Day 1-2 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement webhook validation
- [ ] Implement webhook processing
- [ ] Handle UPS webhooks
- [ ] Handle FedEx webhooks
- [ ] Update fulfillment status from webhooks
- [ ] Handle idempotency
- [ ] Add webhook event logging

**Files to Create**:
```
internal/biz/webhook/
  ├── handler.go
  ├── validator.go
  └── processor.go
```

**Webhook Events to Handle**:
- [ ] shipment.picked_up
- [ ] shipment.in_transit
- [ ] shipment.out_for_delivery
- [ ] shipment.delivered
- [ ] shipment.exception
- [ ] shipment.returned

**Webhook Flow**:
1. Validate webhook signature
2. Parse webhook payload
3. Check idempotency (prevent duplicate processing)
4. Determine event type
5. Update fulfillment/tracking status
6. Publish internal events
7. Log webhook event

**Estimated Effort**: 8 hours

---

### 3.3. Label Generation (Day 2-3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement GenerateLabel usecase
- [ ] Call carrier API for label
- [ ] Store label URL
- [ ] Generate commercial invoice (international)
- [ ] Add label printing support
- [ ] Handle label errors

**Label Generation Flow**:
1. Get fulfillment details
2. Validate shipment is ready
3. Call carrier API to generate label
4. Store label URL in database
5. Update fulfillment with tracking number
6. Return label details

**Estimated Effort**: 6 hours


### 3.4. Return Processing (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement CreateReturn usecase
- [ ] Implement ApproveReturn usecase
- [ ] Implement ReceiveReturn usecase
- [ ] Generate return labels
- [ ] Track return shipments
- [ ] Update inventory on return
- [ ] Publish return events

**Return Operations**:
```go
func (uc *ReturnUsecase) CreateReturn(ctx context.Context, req *CreateReturnRequest) (*Return, error)
func (uc *ReturnUsecase) ApproveReturn(ctx context.Context, returnID string) (*Return, error)
func (uc *ReturnUsecase) ReceiveReturn(ctx context.Context, returnID string) (*Return, error)
func (uc *ReturnUsecase) GenerateReturnLabel(ctx context.Context, returnID string) (*Label, error)
```

**Estimated Effort**: 8 hours

---

### 3.5. Event Publishing (Day 4 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Setup event publisher
- [ ] Implement fulfillment.created event
- [ ] Implement fulfillment.status_changed event
- [ ] Implement shipment.delivered event
- [ ] Implement tracking.updated event
- [ ] Implement return.created event
- [ ] Add event schema validation

**Events to Publish**:
```go
// Fulfillment created
type FulfillmentCreatedEvent struct {
    FulfillmentID string
    OrderID       string
    WarehouseID   string
    CustomerID    string
    EstimatedDelivery time.Time
    // ...
}

// Shipment delivered
type ShipmentDeliveredEvent struct {
    FulfillmentID string
    OrderID       string
    TrackingNumber string
    DeliveredAt   time.Time
    // ...
}
```

**Estimated Effort**: 4 hours

**PHASE 3 TOTAL**: 32 hours (Week 3)

---

## 🎯 PHASE 4: SERVICE LAYER & API (Week 4)

### 4.1. Shipping Service Implementation (Day 1 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement CreateFulfillment service method
- [ ] Implement GetFulfillment service method
- [ ] Implement ListFulfillments service method
- [ ] Implement UpdateFulfillmentStatus service method
- [ ] Implement CancelFulfillment service method
- [ ] Add request validation
- [ ] Add error mapping
- [ ] Add logging

**Files to Create**:
```
internal/service/shipping.go
```

**Service Method Example**:
```go
func (s *ShippingService) CreateFulfillment(ctx context.Context, req *pb.CreateFulfillmentRequest) (*pb.CreateFulfillmentResponse, error) {
    // 1. Validate request
    if err := s.validateCreateFulfillmentRequest(req); err != nil {
        return nil, status.Error(codes.InvalidArgument, err.Error())
    }
    
    // 2. Call usecase
    fulfillment, err := s.fulfillmentUsecase.CreateFulfillment(ctx, &biz.CreateFulfillmentRequest{
        OrderID: req.OrderId,
        WarehouseID: req.WarehouseId,
        CustomerID: req.CustomerId,
        // ...
    })
    if err != nil {
        return nil, s.mapError(err)
    }
    
    // 3. Convert to proto
    return &pb.CreateFulfillmentResponse{
        Fulfillment: s.toProtoFulfillment(fulfillment),
        Success: true,
    }, nil
}
```

**Estimated Effort**: 6 hours


### 4.2. Rate & Label Service Implementation (Day 1-2 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement CalculateRates service method
- [ ] Implement GenerateLabel service method
- [ ] Implement GetLabel service method
- [ ] Add request validation
- [ ] Add error mapping

**Estimated Effort**: 6 hours

---

### 4.3. Tracking Service Implementation (Day 2 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement GetTracking service method
- [ ] Implement GetTrackingHistory service method
- [ ] Add caching support
- [ ] Add error mapping

**Estimated Effort**: 4 hours

---

### 4.4. Webhook Service Implementation (Day 3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement ProcessWebhook service method
- [ ] Add webhook signature validation
- [ ] Add webhook routing by carrier
- [ ] Add idempotency handling
- [ ] Add error handling

**Webhook Service**:
```go
func (s *ShippingService) ProcessWebhook(ctx context.Context, req *pb.ProcessWebhookRequest) (*pb.ProcessWebhookResponse, error) {
    // 1. Validate signature
    if err := s.webhookValidator.Validate(req.Carrier, req.Payload, req.Signature); err != nil {
        return nil, status.Error(codes.Unauthenticated, "invalid webhook signature")
    }
    
    // 2. Process webhook
    event, err := s.webhookProcessor.Process(ctx, req.Carrier, req.Payload)
    if err != nil {
        return nil, status.Error(codes.Internal, err.Error())
    }
    
    // 3. Return response
    return &pb.ProcessWebhookResponse{
        Success: true,
        Processed: true,
    }, nil
}
```

**Estimated Effort**: 6 hours

---

### 4.5. Error Mapping & Validation (Day 3-4 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create error mapping function
- [ ] Map domain errors to gRPC status codes
- [ ] Add request validation helpers
- [ ] Add common validation rules

**Error Mapping**:
```go
func (s *ShippingService) mapError(err error) error {
    switch {
    case errors.Is(err, biz.ErrFulfillmentNotFound):
        return status.Error(codes.NotFound, "fulfillment not found")
    case errors.Is(err, biz.ErrInvalidAddress):
        return status.Error(codes.InvalidArgument, "invalid shipping address")
    case errors.Is(err, biz.ErrCarrierUnavailable):
        return status.Error(codes.Unavailable, "carrier service unavailable")
    case errors.Is(err, biz.ErrRateCalculationFailed):
        return status.Error(codes.Internal, "rate calculation failed")
    default:
        return status.Error(codes.Internal, "internal error")
    }
}
```

**Estimated Effort**: 4 hours


### 4.6. HTTP & gRPC Server Registration (Day 4 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Register all service methods in HTTP server
- [ ] Register all service methods in gRPC server
- [ ] Add middleware (auth, logging, recovery)
- [ ] Add CORS configuration
- [ ] Test all endpoints

**HTTP Server Setup**:
```go
func NewHTTPServer(c *conf.Server, shippingService *service.ShippingService, logger log.Logger) *http.Server {
    var opts = []http.ServerOption{
        http.Middleware(
            recovery.Recovery(),
            logging.Server(logger),
            auth.Validator(),
        ),
    }
    
    srv := http.NewServer(opts...)
    v1.RegisterShippingServiceHTTPServer(srv, shippingService)
    return srv
}
```

**Estimated Effort**: 4 hours

**PHASE 4 TOTAL**: 30 hours (Week 4)

---

## 🎯 PHASE 5: INTEGRATION & TESTING (Week 5)

### 5.1. External Service Clients (Day 1 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create Order Service client
- [ ] Create Warehouse Service client
- [ ] Create Customer Service client
- [ ] Add service discovery via Consul
- [ ] Add retry logic
- [ ] Add circuit breaker
- [ ] Add timeout handling

**Files to Create**:
```
internal/client/
  ├── order_client.go
  ├── warehouse_client.go
  └── customer_client.go
```

**Service Client Example**:
```go
type OrderClient interface {
    GetOrder(ctx context.Context, orderID string) (*Order, error)
    UpdateOrderStatus(ctx context.Context, orderID string, status string) error
}

type orderClient struct {
    conn *grpc.ClientConn
    client orderpb.OrderServiceClient
}

func NewOrderClient(consul *consul.Client, logger log.Logger) (OrderClient, error) {
    // Discover order service via Consul
    services, _, err := consul.Health().Service("order-service", "", true, nil)
    if err != nil {
        return nil, err
    }
    
    // Create gRPC connection
    conn, err := grpc.Dial(services[0].Service.Address, grpc.WithInsecure())
    if err != nil {
        return nil, err
    }
    
    return &orderClient{
        conn: conn,
        client: orderpb.NewOrderServiceClient(conn),
    }, nil
}
```

**Estimated Effort**: 6 hours


### 5.2. Unit Tests - Business Logic (Day 1-2 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Write unit tests for FulfillmentUsecase
- [ ] Write unit tests for ShipmentUsecase
- [ ] Write unit tests for TrackingUsecase
- [ ] Write unit tests for ReturnUsecase
- [ ] Write unit tests for RateCalculator
- [ ] Mock external dependencies
- [ ] Achieve >80% coverage

**Test Files**:
```
internal/biz/fulfillment_usecase_test.go
internal/biz/shipment_usecase_test.go
internal/biz/tracking_usecase_test.go
internal/biz/return_usecase_test.go
internal/biz/rate/calculator_test.go
```

**Estimated Effort**: 8 hours

---

### 5.3. Unit Tests - Service Layer (Day 2 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Write unit tests for ShippingService
- [ ] Write unit tests for WebhookService
- [ ] Test error mapping
- [ ] Test request validation

**Estimated Effort**: 4 hours

---

### 5.4. Integration Tests (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Setup test database
- [ ] Setup test Redis
- [ ] Write integration tests for fulfillment flow
- [ ] Write integration tests for tracking
- [ ] Write integration tests for webhook handling
- [ ] Test with carrier sandbox environments

**Integration Test Setup**:
```go
func TestFulfillmentIntegration(t *testing.T) {
    // Setup test database
    db := setupTestDB(t)
    defer db.Close()
    
    // Setup test Redis
    rdb := setupTestRedis(t)
    defer rdb.Close()
    
    // Create usecase with real dependencies
    fulfillmentRepo := data.NewFulfillmentRepo(db, log.NewStdLogger(os.Stdout))
    fulfillmentUsecase := biz.NewFulfillmentUsecase(fulfillmentRepo, ...)
    
    // Test fulfillment creation
    fulfillment, err := fulfillmentUsecase.CreateFulfillment(ctx, req)
    assert.NoError(t, err)
    assert.Equal(t, FulfillmentStatusCreated, fulfillment.Status)
}
```

**Estimated Effort**: 8 hours

---

### 5.5. End-to-End Testing (Day 4-5 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Test complete fulfillment flow
- [ ] Test rate calculation
- [ ] Test label generation
- [ ] Test tracking updates
- [ ] Test webhook processing
- [ ] Test return flow
- [ ] Test error scenarios
- [ ] Test with Postman/curl

**E2E Test Scenarios**:
1. Create fulfillment successfully
2. Calculate shipping rates
3. Generate shipping label
4. Process carrier webhook
5. Update tracking status
6. Deliver shipment
7. Create return request
8. Process return
9. Handle carrier failures
10. Handle webhook idempotency

**Estimated Effort**: 8 hours

**PHASE 5 TOTAL**: 34 hours (Week 5)


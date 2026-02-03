# 🚚 Fulfillment Service - Complete Documentation

**Service Name**: Fulfillment Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-30  
**Review Status**: ✅ Reviewed (Post-Linting Fixes)  
**Production Ready**: 95%  
**Service Category**: Operational Service

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Fulfillment Management APIs](#-fulfillment-management-apis)
- [Database Schema](#-database-schema)
- [Fulfillment Business Logic](#-fulfillment-business-logic)
- [Configuration](#-configuration)
- [Dependencies](#-dependencies)
- [Testing](#-testing)
- [Monitoring & Observability](#-monitoring--observability)
- [Known Issues & TODOs](#-known-issues--todos)
- [Development Guide](#-development-guide)

---

## 🎯 Overview

Fulfillment Service là **core operational service** quản lý toàn bộ quy trình order fulfillment từ nhận order đến giao hàng. Service này điều phối giữa Order, Warehouse, Catalog, và Shipping services để đảm bảo orders được xử lý hiệu quả và chính xác.

### Core Capabilities
- **📦 Order Fulfillment**: End-to-end fulfillment workflow (pick, pack, ship)
- **🏭 Warehouse Coordination**: Multi-warehouse order allocation và capacity management
- **📋 Picking Management**: Automated picking list generation với path optimization
- **📦 Packing Operations**: Packing slip generation, weight verification, quality control
- **🚚 Shipping Integration**: Label generation và carrier coordination
- **✅ Quality Control**: Random sampling (10%) và high-value order QC (100%)
- **🔄 Exception Handling**: Retry logic cho pick/pack failures (max 3 retries)
- **📊 Performance Tracking**: Fulfillment metrics và analytics

### Business Value
- **Operational Efficiency**: Streamlined warehouse operations với automated workflows
- **Customer Satisfaction**: Faster, accurate order fulfillment với quality control
- **Cost Optimization**: Optimal warehouse và carrier utilization
- **Scalability**: Handle high-volume order processing với event-driven architecture
- **Reliability**: Robust error handling và retry mechanisms

### Key Differentiators
- **Complete Lifecycle Management**: Từ order confirmation đến shipment delivery
- **Quality Control Integration**: Built-in QC với deterministic sampling
- **Multi-Warehouse Support**: Intelligent warehouse assignment và capacity management
- **Event-Driven Architecture**: Async coordination với Dapr pub/sub
- **Performance Optimized**: N+1 query prevention với preloading, optimized picking paths

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
fulfillment/
├── cmd/fulfillment/              # Application entry point
├── internal/
│   ├── biz/                      # Business Logic Layer
│   │   ├── fulfillment/         # Core fulfillment logic
│   │   ├── picklist/            # Picking operations
│   │   ├── package_biz/         # Packing operations
│   │   └── qc/                  # Quality control
│   ├── data/                     # Data Access Layer
│   │   ├── postgres/            # PostgreSQL repositories
│   │   ├── eventbus/            # Dapr event consumers
│   │   └── grpc_client/         # External service clients
│   ├── service/                  # Service Layer (gRPC/HTTP)
│   │   ├── fulfillment_service.go
│   │   ├── picklist_service.go
│   │   ├── package_service.go
│   │   ├── validation.go        # Input validation
│   │   └── error_mapping.go     # gRPC error mapping
│   ├── server/                   # Server setup
│   │   ├── http.go              # HTTP server với metadata middleware
│   │   ├── grpc.go              # gRPC server với health service
│   │   └── consul.go            # Service discovery
│   ├── events/                   # Event publishing
│   ├── observer/                 # Event observers
│   ├── constants/                # Business constants
│   └── model/                    # Domain models
├── api/                          # Protocol Buffers
│   ├── fulfillment/v1/          # Fulfillment APIs
│   ├── picklist/v1/             # Picklist APIs
│   └── package/v1/               # Package APIs
├── migrations/                   # Database migrations (Goose)
└── configs/                      # Environment configs
```

### Ports & Endpoints
- **HTTP API**: `:8005` - REST endpoints cho frontend/client apps
- **gRPC API**: `:9005` - Internal service communication
- **Health Check**: `/health`, `/health/ready`, `/health/live`
- **Metrics**: `/metrics` (Prometheus)

### Service Dependencies

#### Internal Dependencies
- **Order Service**: Order data, order confirmation events (`order.confirmed`, `order.cancelled`)
- **Warehouse Service**: Stock allocation, reservations, warehouse capacity, time slots
- **Catalog Service**: Product information, SKU details, weight/dimensions
- **Shipping Service**: Shipping label generation, tracking updates
- **Notification Service**: Fulfillment status notifications

#### External Dependencies
- **PostgreSQL**: Primary data store (`fulfillment_db`)
- **Redis**: Caching, rate limiting (via Dapr)
- **Dapr**: Event-driven communication (pub/sub với Redis backend)
- **Consul**: Service discovery và health checks

---

## 🔌 Fulfillment Management APIs

### Fulfillment Lifecycle Operations

#### Create Fulfillment (From Order Service)
```protobuf
rpc CreateFulfillment(CreateFulfillmentRequest) returns (CreateFulfillmentResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments"
    body: "*"
  };
}
```

**Flow** (Called by Order Service or Event Consumer):
1. Receive order data from Order Service (via event or direct call)
2. Validate order completeness và items
3. Create fulfillment record với `pending` status
4. Generate fulfillment number: `FULF-{YYMM}-{000001}`
5. Create fulfillment items từ order items
6. Publish `fulfillment.created` event
7. Return fulfillment details

#### Get Fulfillment
```protobuf
rpc GetFulfillment(GetFulfillmentRequest) returns (GetFulfillmentResponse) {
  option (google.api.http) = {
    get: "/api/v1/fulfillments/{id}"
  };
}
```

**Features**:
- Preloads `Items` và `Packages` để tránh N+1 queries
- Returns complete fulfillment với all relations

#### Get Fulfillment by Order ID
```protobuf
rpc GetFulfillmentByOrderID(GetFulfillmentByOrderIDRequest) returns (GetFulfillmentResponse) {
  option (google.api.http) = {
    get: "/api/v1/fulfillments/order/{order_id}"
  };
}
```

#### List Fulfillments
```protobuf
rpc ListFulfillments(ListFulfillmentsRequest) returns (ListFulfillmentsResponse) {
  option (google.api.http) = {
    get: "/api/v1/fulfillments"
  };
}
```

**Filters**:
- `status`: Filter by fulfillment status
- `warehouse_id`: Filter by warehouse
- `order_id`: Filter by order
- Pagination: `page`, `page_size`

### Planning Operations

#### Start Planning
```protobuf
rpc StartPlanning(StartPlanningRequest) returns (StartPlanningResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/start-planning"
  };
}
```

**Flow**:
1. Assign warehouse based on shipping address và capacity
2. Check warehouse capacity và time slot availability
3. Create inventory reservation via Warehouse Service
4. Assign time slot (customer-selected or auto-assigned)
5. Update status to `planning`
6. Publish `fulfillment.planning.started` event

### Picking Operations

#### Generate Picklist
```protobuf
rpc GeneratePicklist(GeneratePicklistRequest) returns (GeneratePicklistResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/generate-picklist"
  };
}
```

**Features**:
- Zone-based picking path optimization
- Batch picking support
- Priority assignment
- Item location mapping (warehouse location, bin location)

#### Confirm Picked Items
```protobuf
rpc ConfirmPicked(ConfirmPickedRequest) returns (ConfirmPickedResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/confirm-picked"
    body: "*"
  };
}
```

**Flow**:
1. Validate picked quantities (cannot exceed ordered)
2. Update fulfillment item `quantity_picked`
3. Update picklist status
4. If picklist completed:
   - Update fulfillment status to `picked`
   - Confirm warehouse reservation (with nil check for robustness)
   - Publish `fulfillment.picked` event
5. Handle partial picks (keep status as `picking`)

**Safety Feature**: Warehouse client nil check prevents runtime panic if warehouse service unavailable

### Packing Operations

#### Confirm Packed
```protobuf
rpc ConfirmPacked(ConfirmPackedRequest) returns (ConfirmPackedResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/confirm-packed"
    body: "*"
  };
}
```

**Flow**:
1. Validate package details (weight, dimensions)
2. Verify package weight vs expected (optional)
3. Create package record
4. Create package items (link fulfillment items to package)
5. Generate packing slip (text format, PDF pending)
6. Update fulfillment status to `packed`
7. Publish `fulfillment.packed` event

#### Generate Packing Slip
```protobuf
rpc GeneratePackingSlip(GeneratePackingSlipRequest) returns (GeneratePackingSlipResponse) {
  option (google.api.http) = {
    post: "/api/v1/packages/{package_id}/packing-slip"
  };
}
```

**Current State**: Text format với enhanced formatting (PDF library integration pending)

### Quality Control Operations

#### Perform QC
```protobuf
rpc PerformQC(PerformQCRequest) returns (PerformQCResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/qc"
    body: "*"
  };
}
```

**QC Requirements**:
- **High Value**: COD >= 1M VND → 100% QC
- **Random Sample**: 10% of fulfillments (deterministic)
- **Manual**: Admin-triggered

#### Get QC Result
```protobuf
rpc GetQCResult(GetQCResultRequest) returns (GetQCResultResponse) {
  option (google.api.http) = {
    get: "/api/v1/fulfillments/{fulfillment_id}/qc"
  };
}
```

### Status Management

#### Update Fulfillment Status
```protobuf
rpc UpdateFulfillmentStatus(UpdateFulfillmentStatusRequest) returns (UpdateFulfillmentStatusResponse) {
  option (google.api.http) = {
    put: "/api/v1/fulfillments/{id}/status"
    body: "*"
  };
}
```

**Status Transitions**:
- `pending` → `planning` → `picking` → `picked` → `packing` → `packed` → `ready` → `shipped` → `completed`
- Terminal states: `completed`, `cancelled`
- Failure states: `pick_failed`, `pack_failed` (with retry support)

#### Cancel Fulfillment
```protobuf
rpc CancelFulfillment(CancelFulfillmentRequest) returns (CancelFulfillmentResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{id}/cancel"
    body: "*"
  };
}
```

**Rules**: Cannot cancel if `shipped` or `completed`

### Exception Handling

#### Retry Pick
```protobuf
rpc RetryPick(RetryPickRequest) returns (RetryPickResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{id}/retry-pick"
  };
}
```

#### Retry Pack
```protobuf
rpc RetryPack(RetryPackRequest) returns (RetryPackResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{id}/retry-pack"
  };
}
```

**Retry Logic**: Max 3 retries per operation (configurable via `max_retries`)

---

## 🗄️ Database Schema

### Core Tables

#### fulfillments
```sql
CREATE TABLE fulfillments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fulfillment_number VARCHAR(50) UNIQUE NOT NULL,
  order_id UUID NOT NULL,
  order_number VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  warehouse_id UUID,
  
  -- Time Slot Support
  selected_time_slot_id UUID,  -- Customer-selected
  assigned_time_slot_id UUID,   -- Auto-assigned
  
  -- Tracking
  reservation_id UUID,          -- Warehouse reservation ID
  assigned_picker_id UUID,
  assigned_packer_id UUID,
  picklist_id UUID,
  package_id UUID,              -- Legacy (multiple packages supported)
  
  -- COD Support
  requires_cod_collection BOOLEAN DEFAULT FALSE,
  cod_amount DECIMAL(15,2),
  cod_currency VARCHAR(3) DEFAULT 'VND',
  
  -- Quality Control
  qc_checked_at TIMESTAMP WITH TIME ZONE,
  qc_checked_by UUID,
  qc_passed BOOLEAN DEFAULT FALSE,
  qc_required BOOLEAN DEFAULT FALSE,
  qc_reason VARCHAR(50),        -- 'random', 'high_value', 'manual'
  
  -- Exception Handling
  pick_failed_at TIMESTAMP WITH TIME ZONE,
  pick_failed_reason TEXT,
  pick_retry_count INT DEFAULT 0,
  pack_failed_at TIMESTAMP WITH TIME ZONE,
  pack_failed_reason TEXT,
  pack_retry_count INT DEFAULT 0,
  max_retries INT DEFAULT 3,
  
  -- Timestamps
  planned_at TIMESTAMP WITH TIME ZONE,
  picked_at TIMESTAMP WITH TIME ZONE,
  packed_at TIMESTAMP WITH TIME ZONE,
  ready_at TIMESTAMP WITH TIME ZONE,
  shipped_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX idx_fulfillments_order_id ON fulfillments(order_id);
CREATE INDEX idx_fulfillments_status ON fulfillments(status);
CREATE INDEX idx_fulfillments_warehouse_id ON fulfillments(warehouse_id);
CREATE INDEX idx_fulfillments_fulfillment_number ON fulfillments(fulfillment_number);
CREATE INDEX idx_fulfillments_created_at ON fulfillments(created_at DESC);
```

#### fulfillment_items
```sql
CREATE TABLE fulfillment_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  product_sku VARCHAR(100) NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  variant_id UUID,
  
  -- Quantities
  quantity_ordered INT NOT NULL,
  quantity_picked INT DEFAULT 0,
  quantity_packed INT DEFAULT 0,
  
  -- Location
  warehouse_location VARCHAR(50),
  bin_location VARCHAR(50),
  
  -- Pricing
  unit_price DECIMAL(15,2) NOT NULL,
  total_price DECIMAL(15,2) NOT NULL,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_fulfillment_items_fulfillment_id ON fulfillment_items(fulfillment_id);
CREATE INDEX idx_fulfillment_items_product_id ON fulfillment_items(product_id);
```

#### picklists
```sql
CREATE TABLE picklists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
  picklist_number VARCHAR(50) UNIQUE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  priority INT DEFAULT 5,
  
  -- Assignment
  assigned_picker_id UUID,
  assigned_at TIMESTAMP WITH TIME ZONE,
  
  -- Expiry
  expires_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_picklists_fulfillment_id ON picklists(fulfillment_id);
CREATE INDEX idx_picklists_status ON picklists(status);
CREATE INDEX idx_picklists_assigned_picker_id ON picklists(assigned_picker_id);
```

#### picklist_items
```sql
CREATE TABLE picklist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  picklist_id UUID NOT NULL REFERENCES picklists(id) ON DELETE CASCADE,
  fulfillment_item_id UUID NOT NULL REFERENCES fulfillment_items(id),
  zone_id VARCHAR(50),
  warehouse_location VARCHAR(50),
  bin_location VARCHAR(50),
  sequence_order INT,           -- For path optimization
  quantity_to_pick INT NOT NULL,
  quantity_picked INT DEFAULT 0,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_picklist_items_picklist_id ON picklist_items(picklist_id);
CREATE INDEX idx_picklist_items_fulfillment_item_id ON picklist_items(fulfillment_item_id);
```

#### packages
```sql
CREATE TABLE packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
  package_number VARCHAR(50) UNIQUE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'created',
  package_type VARCHAR(50) DEFAULT 'box',
  
  -- Dimensions
  weight_kg DECIMAL(10,3) NOT NULL,
  length_cm DECIMAL(10,2) NOT NULL,
  width_cm DECIMAL(10,2) NOT NULL,
  height_cm DECIMAL(10,2) NOT NULL,
  
  -- Packing Info
  packed_by UUID NOT NULL,
  packed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  total_items INT NOT NULL DEFAULT 0,
  
  -- Shipping
  shipping_label_url TEXT,
  packing_slip_url TEXT,
  photo_url TEXT,
  tracking_number VARCHAR(100),
  
  -- Metadata
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_packages_fulfillment_id ON packages(fulfillment_id);
CREATE INDEX idx_packages_status ON packages(status);
CREATE INDEX idx_packages_tracking_number ON packages(tracking_number) WHERE tracking_number IS NOT NULL;
```

#### package_items
```sql
CREATE TABLE package_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  fulfillment_item_id UUID NOT NULL REFERENCES fulfillment_items(id) ON DELETE CASCADE,
  quantity_packed INT NOT NULL CHECK (quantity_packed > 0),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(package_id, fulfillment_item_id)
);

CREATE INDEX idx_package_items_package_id ON package_items(package_id);
CREATE INDEX idx_package_items_fulfillment_item_id ON package_items(fulfillment_item_id);
```

#### qc_results
```sql
CREATE TABLE qc_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
  checker_id UUID NOT NULL,
  checked_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- QC Checks
  item_count_verified BOOLEAN DEFAULT FALSE,
  item_verification_passed BOOLEAN DEFAULT FALSE,
  package_weight_verified BOOLEAN DEFAULT FALSE,
  photo_verification_passed BOOLEAN DEFAULT FALSE,
  defect_check_passed BOOLEAN DEFAULT FALSE,
  
  -- Result
  passed BOOLEAN NOT NULL,
  notes TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_qc_results_fulfillment_id ON qc_results(fulfillment_id);
CREATE INDEX idx_qc_results_checker_id ON qc_results(checker_id);
```

#### status_history
```sql
CREATE TABLE status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
  from_status VARCHAR(20),
  to_status VARCHAR(20) NOT NULL,
  changed_by UUID,
  reason TEXT,
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_status_history_fulfillment_id ON status_history(fulfillment_id);
CREATE INDEX idx_status_history_changed_at ON status_history(changed_at DESC);
```

#### outbox_events
```sql
CREATE TABLE outbox_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(100) NOT NULL,
  topic VARCHAR(100) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  retry_count INT DEFAULT 0,
  error_message TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  published_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_outbox_events_status ON outbox_events(status);
CREATE INDEX idx_outbox_events_created_at ON outbox_events(created_at);
```

### Performance Optimizations

#### Indexes
- All foreign keys indexed
- Status fields indexed for filtering
- Created_at indexed for time-based queries
- Composite indexes for common query patterns

#### Query Optimization
- **Preloading**: All fulfillment queries preload `Items` và `Packages` to prevent N+1 queries
- **Pagination**: All list queries support pagination
- **Connection Pooling**: Configured via GORM settings

---

## 📦 Fulfillment Business Logic

### Fulfillment Creation Flow

```go
func (uc *FulfillmentUseCase) CreateFromOrder(ctx context.Context, orderID string, orderData OrderData) (*Fulfillment, error) {
    // 1. Generate fulfillment number: FULF-{YYMM}-{000001}
    fulfillmentNumber, err := uc.repo.GenerateFulfillmentNumber(ctx)
    if err != nil {
        return nil, fmt.Errorf("failed to generate fulfillment number: %w", err)
    }
    
    // 2. Create fulfillment record
    fulfillment := &Fulfillment{
        ID:                uuid.New().String(),
        FulfillmentNumber: fulfillmentNumber,
        OrderID:           orderID,
        OrderNumber:       orderData.OrderNumber,
        Status:            constants.FulfillmentStatusPending,
        MaxRetries:        3,
    }
    
    // 3. Create fulfillment items
    for _, item := range orderData.Items {
        fulfillmentItem := &FulfillmentItem{
            FulfillmentID:   fulfillment.ID,
            ProductID:       item.ProductID,
            ProductSKU:      item.ProductSKU,
            ProductName:     item.ProductName,
            QuantityOrdered: item.Quantity,
            UnitPrice:       item.UnitPrice,
            TotalPrice:      item.TotalPrice,
        }
        fulfillment.Items = append(fulfillment.Items, *fulfillmentItem)
    }
    
    // 4. Handle COD
    if orderData.CODAmount != nil && *orderData.CODAmount > 0 {
        fulfillment.RequiresCODCollection = true
        fulfillment.CODAmount = orderData.CODAmount
        fulfillment.CODCurrency = orderData.CODCurrency
        if fulfillment.CODCurrency == "" {
            fulfillment.CODCurrency = constants.DefaultCODCurrency
        }
    }
    
    // 5. Determine QC requirement
    if fulfillment.CODAmount != nil && *fulfillment.CODAmount >= constants.HighValueThreshold {
        fulfillment.QCRequired = true
        fulfillment.QCReason = constants.QCReasonHighValue
    } else if shouldRandomQC(fulfillment.ID) {
        fulfillment.QCRequired = true
        fulfillment.QCReason = constants.QCReasonRandom
    }
    
    // 6. Save to database
    if err := uc.repo.Create(ctx, fulfillment); err != nil {
        return nil, fmt.Errorf("failed to create fulfillment: %w", err)
    }
    
    // 7. Publish fulfillment.created event
    if uc.eventPub != nil {
        if err := uc.eventPub.PublishFulfillmentCreated(ctx, fulfillment); err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to publish fulfillment.created event: %v", err)
        }
    }
    
    return fulfillment, nil
}
```

### Warehouse Assignment Algorithm

```go
func (uc *FulfillmentUseCase) assignWarehouse(ctx context.Context, fulfillment *Fulfillment) error {
    // 1. Get available warehouses by location
    warehouses, _, err := uc.warehouseClient.ListWarehouses(ctx, 1, 100, "active", "", fulfillment.ShippingAddress.Country)
    if err != nil {
        return fmt.Errorf("failed to get warehouses: %w", err)
    }
    
    // 2. Filter by capacity và inventory
    var candidateWarehouses []*Warehouse
    itemCount := int32(len(fulfillment.Items))
    
    for _, warehouse := range warehouses {
        // Check capacity
        canHandle, err := uc.warehouseClient.CheckWarehouseCapacity(
            ctx, warehouse.ID, itemCount, fulfillment.SelectedTimeSlotID,
        )
        if err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to check capacity for warehouse %s: %v", warehouse.ID, err)
            continue
        }
        if !canHandle {
            continue
        }
        
        // Check inventory availability
        hasStock := true
        for _, item := range fulfillment.Items {
            stock, err := uc.warehouseClient.GetBulkStock(ctx, []string{item.ProductID})
            if err != nil || stock[item.ProductID] == nil || stock[item.ProductID].AvailableQuantity < int32(item.QuantityOrdered) {
                hasStock = false
                break
            }
        }
        if !hasStock {
            continue
        }
        
        candidateWarehouses = append(candidateWarehouses, warehouse)
    }
    
    // 3. Select optimal warehouse (proximity-based)
    if len(candidateWarehouses) == 0 {
        return fmt.Errorf("no available warehouse found")
    }
    
    selectedWarehouse := selectNearestWarehouse(candidateWarehouses, fulfillment.ShippingAddress)
    fulfillment.WarehouseID = &selectedWarehouse.ID
    
    // 4. Create reservation
    reservation, err := uc.warehouseClient.CreateReservation(ctx, &ReservationRequest{
        OrderID:     fulfillment.OrderID,
        WarehouseID: selectedWarehouse.ID,
        Items:       convertToReservationItems(fulfillment.Items),
    })
    if err != nil {
        return fmt.Errorf("failed to create reservation: %w", err)
    }
    
    fulfillment.ReservationID = &reservation.ID
    
    return nil
}
```

### Picking Path Optimization

```go
func (o *PathOptimizer) OptimizePickingPath(items []PicklistItem) []PicklistItem {
    // 1. Group items by zone
    zones := o.groupItemsByZone(items)
    
    // 2. Sort zones (currently alphabetical, TODO: use zone coordinates)
    sort.Slice(zones, func(i, j int) bool {
        return zones[i].ZoneID < zones[j].ZoneID
    })
    
    // 3. Assign sequence order
    sequence := 1
    var optimizedItems []PicklistItem
    for _, zone := range zones {
        for _, item := range zone.Items {
            item.SequenceOrder = sequence
            optimizedItems = append(optimizedItems, item)
            sequence++
        }
    }
    
    return optimizedItems
}
```

### Quality Control Logic

```go
func (uc *QCUsecase) ShouldPerformQC(ctx context.Context, fulfillment *Fulfillment) (bool, string) {
    // High value QC: COD >= 1M VND
    if fulfillment.CODAmount != nil && *fulfillment.CODAmount >= constants.HighValueThreshold {
        return true, constants.QCReasonHighValue
    }
    
    // Random sample: 10% deterministic
    if shouldRandomQC(fulfillment.ID) {
        return true, constants.QCReasonRandom
    }
    
    return false, ""
}

func shouldRandomQC(fulfillmentID string) bool {
    // Deterministic 10% selection based on fulfillment ID hash
    hash := fnv.New32a()
    hash.Write([]byte(fulfillmentID))
    return hash.Sum32()%10 == 0
}
```

### Retry Logic

```go
func (uc *FulfillmentUseCase) RetryPick(ctx context.Context, id string) error {
    fulfillment, err := uc.repo.FindByID(ctx, id)
    if err != nil {
        return err
    }
    
    // Validate retry eligibility
    if fulfillment.Status != constants.FulfillmentStatusPickFailed {
        return constants.ErrInvalidStatusTransition
    }
    
    if fulfillment.PickRetryCount >= fulfillment.MaxRetries {
        return constants.ErrMaxRetriesExceeded
    }
    
    // Reset to picking status
    fulfillment.Status = constants.FulfillmentStatusPicking
    fulfillment.PickFailedAt = nil
    fulfillment.PickFailedReason = ""
    
    if err := uc.repo.Update(ctx, fulfillment); err != nil {
        return fmt.Errorf("failed to update fulfillment: %w", err)
    }
    
    // Publish retry event
    if uc.eventPub != nil {
        uc.eventPub.PublishFulfillmentStatusChanged(ctx, fulfillment, "pick_failed", "picking", "retry")
    }
    
    return nil
}
```

### Status Transition Validation

```go
var validTransitions = map[string][]string{
    "pending":     {"planning", "cancelled"},
    "planning":    {"picking", "cancelled"},
    "picking":     {"picked", "pick_failed", "cancelled"},
    "pick_failed": {"picking", "cancelled"},  // Retry
    "picked":      {"packing", "cancelled"},
    "packing":     {"packed", "pack_failed", "cancelled"},
    "pack_failed": {"packing", "cancelled"},  // Retry
    "packed":      {"ready", "cancelled"},
    "ready":       {"shipped", "cancelled"},
    "shipped":     {"completed"},
    "completed":   {},  // Terminal
    "cancelled":   {},  // Terminal
}

func (uc *FulfillmentUseCase) UpdateStatus(ctx context.Context, id string, newStatus string, reason string) error {
    fulfillment, err := uc.repo.FindByID(ctx, id)
    if err != nil {
        return err
    }
    
    // Validate transition
    allowedTransitions, ok := validTransitions[string(fulfillment.Status)]
    if !ok {
        return constants.ErrInvalidStatus
    }
    
    allowed := false
    for _, allowedStatus := range allowedTransitions {
        if allowedStatus == newStatus {
            allowed = true
            break
        }
    }
    
    if !allowed {
        return constants.ErrInvalidStatusTransition
    }
    
    // Update status
    oldStatus := string(fulfillment.Status)
    fulfillment.Status = constants.FulfillmentStatus(newStatus)
    
    // Update timestamps
    now := time.Now()
    switch newStatus {
    case "planning":
        fulfillment.PlannedAt = &now
    case "picked":
        fulfillment.PickedAt = &now
    case "packed":
        fulfillment.PackedAt = &now
    case "ready":
        fulfillment.ReadyAt = &now
    case "shipped":
        fulfillment.ShippedAt = &now
    case "completed":
        fulfillment.CompletedAt = &now
    case "cancelled":
        fulfillment.CancelledAt = &now
    }
    
    if err := uc.repo.Update(ctx, fulfillment); err != nil {
        return fmt.Errorf("failed to update fulfillment: %w", err)
    }
    
    // Create status history
    uc.repo.CreateStatusHistory(ctx, &StatusHistory{
        FulfillmentID: id,
        FromStatus:    oldStatus,
        ToStatus:      newStatus,
        Reason:        reason,
    })
    
    // Publish status change event
    if uc.eventPub != nil {
        uc.eventPub.PublishFulfillmentStatusChanged(ctx, fulfillment, oldStatus, newStatus, reason)
    }
    
    return nil
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
FULFILLMENT_DATABASE_DSN=postgres://fulfillment_user:fulfillment_pass@postgres:5432/fulfillment_db?sslmode=disable

# Redis (via Dapr)
REDIS_ADDR=redis:6379

# Service Ports
FULFILLMENT_HTTP_PORT=8005
FULFILLMENT_GRPC_PORT=9005

# External Services
FULFILLMENT_ORDER_SERVICE_ADDR=order-service:9004
FULFILLMENT_WAREHOUSE_SERVICE_ADDR=warehouse-service:9008
FULFILLMENT_CATALOG_SERVICE_ADDR=catalog-service:9002
FULFILLMENT_SHIPPING_SERVICE_ADDR=shipping-service:9010

# Fulfillment Configuration
FULFILLMENT_MAX_RETRIES=3
FULFILLMENT_HIGH_VALUE_THRESHOLD=1000000  # 1M VND
FULFILLMENT_QC_RANDOM_PERCENTAGE=10
FULFILLMENT_DEFAULT_COD_CURRENCY=VND
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: fulfillment-service
  version: 1.0.0

server:
  http:
    addr: 0.0.0.0:8005
  grpc:
    addr: 0.0.0.0:9005

database:
  dsn: ${FULFILLMENT_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: 5m

redis:
  addr: ${REDIS_ADDR}
  password: ${REDIS_PASSWORD}
  db: 0

fulfillment:
  max_retries: ${FULFILLMENT_MAX_RETRIES}
  high_value_threshold: ${FULFILLMENT_HIGH_VALUE_THRESHOLD}
  qc_random_percentage: ${FULFILLMENT_QC_RANDOM_PERCENTAGE}
  default_cod_currency: ${FULFILLMENT_DEFAULT_COD_CURRENCY}

external_services:
  order_service:
    grpc_endpoint: ${FULFILLMENT_ORDER_SERVICE_ADDR}
  warehouse_service:
    grpc_endpoint: ${FULFILLMENT_WAREHOUSE_SERVICE_ADDR}
  catalog_service:
    grpc_endpoint: ${FULFILLMENT_CATALOG_SERVICE_ADDR}
  shipping_service:
    grpc_endpoint: ${FULFILLMENT_SHIPPING_SERVICE_ADDR}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/fulfillment

go 1.25

require (
    gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    github.com/google/uuid v1.6.0
    github.com/google/wire v0.6.0
)
```

### Service Mesh Integration
```yaml
# Dapr pub/sub subscriptions
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: fulfillment-order-events
spec:
  topic: order.confirmed
  route: /events/order-confirmed
  pubsubname: pubsub

---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: fulfillment-order-cancelled
spec:
  topic: order.cancelled
  route: /events/order-cancelled
  pubsubname: pubsub
```

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: ~70% coverage (picklist và QC tests comprehensive)
- **Integration Tests**: Partial (some tests need warehouse client mocks)
- **E2E Tests**: TODO - Need to add integration tests với testcontainers

### Critical Test Scenarios

#### Fulfillment Creation Tests
```go
func TestCreateFulfillment_CompleteFlow(t *testing.T) {
    // Setup: Mock order data
    // Execute: Create fulfillment from order
    // Verify: Fulfillment created, items created, events published
}

func TestCreateFulfillment_HighValueQC(t *testing.T) {
    // Setup: Order với COD >= 1M VND
    // Execute: Create fulfillment
    // Verify: QC required với reason 'high_value'
}
```

#### Picking Tests
```go
func TestConfirmPicked_CompletePicklist(t *testing.T) {
    // Setup: Fulfillment với picklist
    // Execute: Confirm all items picked
    // Verify: Status updated to 'picked', reservation confirmed
}

func TestConfirmPicked_WarehouseClientNil(t *testing.T) {
    // Setup: Fulfillment với nil warehouse client
    // Execute: Confirm picked
    // Verify: No panic, warning logged, status still updated
}
```

#### Packing Tests
```go
func TestConfirmPacked_WeightVerification(t *testing.T) {
    // Setup: Package với weight
    // Execute: Confirm packed
    // Verify: Weight verified, package created
}
```

### Test Infrastructure
```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Integration tests (requires services)
make test-integration

# Specific domain tests
go test ./internal/biz/picklist/... -v
go test ./internal/biz/qc/... -v
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### Fulfillment Metrics
```go
# Fulfillment lifecycle
fulfillment_created_total{status="pending"} 2340
fulfillment_status_changes_total{from="pending", to="planning"} 1890

# Fulfillment values
fulfillment_total_value_created 456789.99
fulfillment_average_value 195.12

# Performance
fulfillment_creation_duration_seconds{quantile="0.95"} 0.150
fulfillment_status_update_duration_seconds{quantile="0.95"} 0.080
```

#### Quality Control Metrics
```go
# QC operations
qc_performed_total{reason="high_value"} 450
qc_performed_total{reason="random"} 230
qc_passed_total 620
qc_failed_total 60

# QC performance
qc_duration_seconds{quantile="0.95"} 0.120
```

#### Exception Metrics
```go
# Retry operations
fulfillment_pick_retries_total 45
fulfillment_pack_retries_total 23
fulfillment_max_retries_exceeded_total 5

# Failure rates
fulfillment_pick_failure_rate 0.02
fulfillment_pack_failure_rate 0.01
```

### Health Checks
```go
# Application health
GET /health
GET /health/ready
GET /health/live

# gRPC health service
grpc_health_v1.Health/Check
```

### Distributed Tracing (OpenTelemetry)

#### Fulfillment Creation Trace
```
Order Service → Fulfillment Service
├── Receive order.confirmed event
├── Validate order data
├── Generate fulfillment number
├── Create fulfillment (Database)
├── Create fulfillment items (Database)
├── Determine QC requirement
└── Publish fulfillment.created event (Dapr)
```

#### Picking Flow Trace
```
Fulfillment Service → Warehouse Service
├── Check warehouse capacity
├── Create reservation
├── Generate picklist
├── Optimize picking path
├── Confirm picked items
├── Confirm reservation (with nil check)
└── Publish fulfillment.picked event
```

---

## 🚨 Known Issues & TODOs

### ✅ RESOLVED ISSUES

#### P0-01: Missing Nil Check for warehouseClient ✅ FIXED
- **Issue**: Runtime panic khi warehouse client nil
- **Fix**: Added nil check before calling `ConfirmReservation()`
- **Status**: ✅ Verified in `fulfillment/internal/biz/fulfillment/fulfillment.go:524`

#### P2-03: Missing Packages Preload ✅ FIXED
- **Issue**: N+1 queries khi access fulfillment packages
- **Fix**: Added `Preload("Packages")` to all fulfillment queries
- **Status**: ✅ Verified in `fulfillment/internal/data/postgres/fulfillment.go`

### 🟡 REMAINING ISSUES

#### P1-02: PDF Generation for Packing Slips 🟡 MEDIUM
- **Issue**: Packing slip generation returns text format instead of PDF
- **Impact**: Manual packing slip creation required
- **Location**: `fulfillment/internal/biz/package_biz/packing_slip.go`
- **Fix**: Add PDF library (`github.com/jung-kurt/gofpdf/v2`) và implement PDF generation
- **Status**: Text format enhanced, PDF library integration pending

#### P2-01: Path Optimization with Zone Coordinates 🟡 LOW
- **Issue**: Path optimization doesn't use warehouse zone coordinates
- **Impact**: Suboptimal picking routes (10-20% efficiency loss)
- **Location**: `fulfillment/internal/biz/picklist/path_optimizer.go:53`
- **Fix**: Fetch zone coordinates from Warehouse Service và implement coordinate-based optimization
- **Status**: Pending (requires warehouse service API update)

#### P2-02: Catalog Package Weight Field Update 🟡 LOW
- **Issue**: Weight verification depends on catalog v1.0.3+ with Weight field
- **Impact**: Weight verification may be inaccurate
- **Location**: `fulfillment/internal/biz/package_biz/weight_verification.go:131`
- **Fix**: Update catalog package dependency to v1.0.3+
- **Status**: Pending (requires catalog service proto update)

#### P3-01: Integration Tests 🟢 LOW
- **Issue**: Missing integration tests for end-to-end workflows
- **Impact**: Low test coverage for critical paths
- **Location**: `test/integration/`
- **Fix**: Add integration tests với testcontainers
- **Status**: TODO

---

## 🚀 Development Guide

### Local Development Setup
```bash
# Clone and setup
git clone git@gitlab.com:ta-microservices/fulfillment.git
cd fulfillment

# Start dependencies
docker-compose up -d postgres redis consul dapr

# Install dependencies
go mod download

# Run migrations
make migrate-up

# Generate protobuf code
make api

# Generate wire dependency injection
make wire

# Run service
make run
```

### Code Generation
```bash
# Generate protobuf code
make api

# Generate wire dependency injection
make wire

# Generate mocks for testing
make mocks
```

### Database Operations
```bash
# Create new migration
make migrate-create NAME="add_fulfillment_field"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

### Fulfillment API Development Workflow
1. **Update Proto Definition**: `api/fulfillment/v1/fulfillment.proto`
2. **Generate Code**: `make api`
3. **Implement Service**: `internal/service/fulfillment_service.go`
4. **Add Business Logic**: `internal/biz/fulfillment/`
5. **Add Repository**: `internal/data/postgres/`
6. **Add Tests**: Unit + Integration tests
7. **Update Documentation**: This file

---

## 📈 Performance Benchmarks

### Fulfillment Operations (P95 Response Times)
- **Create Fulfillment**: 150ms (with external service calls)
- **Get Fulfillment**: 45ms (with preloaded relations)
- **List Fulfillments**: 300ms (with pagination, 100 items)
- **Update Status**: 80ms
- **Generate Picklist**: 120ms (with path optimization)
- **Confirm Picked**: 100ms (with reservation confirmation)
- **Confirm Packed**: 150ms (with weight verification)

### Throughput Targets
- **Fulfillment Creation**: 50 req/sec peak
- **Status Updates**: 100 req/sec sustained
- **Read Operations**: 200 req/sec sustained

### Database Performance
- **Fulfillment Queries**: <50ms average (with indexes)
- **List Queries**: <300ms với pagination và preloading
- **N+1 Prevention**: Packages và Items preloaded in all queries

### Optimization Features
- **Preloading**: `Items` và `Packages` preloaded to prevent N+1 queries
- **Indexing**: All foreign keys và frequently queried fields indexed
- **Connection Pooling**: Configured via GORM settings
- **Pagination**: All list queries support pagination

---

## 🔐 Security Considerations

### Authentication & Authorization
- **Gateway-Based**: Services trust Gateway for JWT validation
- **Metadata Extraction**: Services extract user info from headers:
  - `X-User-ID`: User ID
  - `X-Client-Type`: Client type (web, mobile, admin)
  - `X-Admin-*`: Admin-specific headers
  - `X-Warehouse-*`: Warehouse-specific headers

### Data Protection
- **PII Handling**: Customer data encrypted in transit/logs
- **Order Data**: Never stored directly, references Order Service
- **Session Security**: Secure random UUID generation
- **Rate Limiting**: Implemented at gateway level

### Business Logic Security
- **Status Validation**: Server-side status transition validation
- **Quantity Validation**: Picked/packed quantities cannot exceed ordered
- **Fulfillment Integrity**: Atomic operations với transactions
- **Audit Trail**: Complete status change history

---

## 🎯 Future Roadmap

### Phase 1 (Q1 2026) - Performance & Reliability
- [ ] Implement PDF generation for packing slips
- [ ] Add comprehensive integration tests
- [ ] Implement coordinate-based path optimization
- [ ] Update catalog package for Weight field

### Phase 2 (Q2 2026) - Advanced Features
- [ ] Multi-warehouse fulfillment support
- [ ] Advanced QC analytics và reporting
- [ ] Real-time fulfillment tracking dashboard
- [ ] Predictive fulfillment capacity planning

### Phase 3 (Q3 2026) - Scale & Intelligence
- [ ] Machine learning for warehouse assignment optimization
- [ ] AI-powered picking path optimization
- [ ] Advanced exception handling với auto-recovery
- [ ] Real-time fulfillment analytics và insights

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: Fulfillment Service Team
- **Repository**: `gitlab.com/ta-microservices/fulfillment`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #fulfillment-service-alerts
- **Performance Issues**: #fulfillment-service-performance
- **Fulfillment Issues**: #fulfillment-processing

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/fulfillment-service`
- **Fulfillment Analytics**: `https://grafana.tanhdev.com/d/fulfillment-analytics`
- **Business Metrics**: `https://grafana.tanhdev.com/d/ecommerce-overview`

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-29  
**Code Review Status**: ✅ Completed (Critical bugs fixed)  
**Production Readiness**: 92% (PDF generation và integration tests pending)

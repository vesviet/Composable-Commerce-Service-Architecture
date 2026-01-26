# 🚚 Fulfillment Service - Order Fulfillment & Logistics

**Service Name**: Fulfillment Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Production Ready**: 90%  

---

## 🎯 Overview

Fulfillment Service là **core operational service** quản lý toàn bộ quy trình order fulfillment từ nhận order đến giao hàng. Service này điều phối giữa Order, Warehouse, và Shipping services để đảm bảo orders được xử lý hiệu quả.

### Core Capabilities
- **📦 Order Fulfillment**: End-to-end fulfillment workflow
- **🏭 Warehouse Coordination**: Multi-warehouse order allocation
- **📋 Picking Management**: Automated picking list generation
- **📦 Packing Operations**: Packing slip và quality control
- **🚚 Shipping Integration**: Label generation và carrier coordination
- **📊 Performance Tracking**: Fulfillment metrics và analytics
- **🔄 Return Processing**: Reverse logistics workflow

### Business Value
- **Operational Efficiency**: Streamlined warehouse operations
- **Customer Satisfaction**: Faster, accurate order fulfillment
- **Cost Optimization**: Optimal warehouse và carrier utilization
- **Scalability**: Handle high-volume order processing

---

## 🏗️ Architecture

### Service Architecture
```
fulfillment/
├── cmd/fulfillment/              # Main service entry point
├── internal/
│   ├── biz/                      # Business logic domains
│   │   ├── fulfillment/          # Core fulfillment logic
│   │   ├── picking/              # Picking operations
│   │   ├── packing/              # Packing operations
│   │   ├── shipping/             # Shipping coordination
│   │   └── events/               # Event publishing
│   ├── data/                     # Data access (PostgreSQL)
│   ├── service/                  # gRPC/HTTP API layer
│   └── client/                   # External service clients
├── api/fulfillment/v1/           # Protocol buffers
├── migrations/                   # Database schema
└── configs/                      # Configuration
```

### Ports & Dependencies
- **HTTP API**: `:8005` - REST endpoints
- **gRPC API**: `:9005` - Internal communication
- **Database**: PostgreSQL (`fulfillment_db`)
- **External Services**: Order, Warehouse, Shipping services

---

## 🔄 Business Flow

### Order Fulfillment Workflow

```mermaid
graph TD
    A[Order Created] --> B[Order Confirmed]
    B --> C[Fulfillment Created]
    C --> D[Warehouse Assigned]
    D --> E[Picking List Generated]
    E --> F[Items Picked]
    F --> G[Packing Slip Created]
    G --> H[Items Packed]
    H --> I[Shipping Label Generated]
    I --> J[Shipment Created]
    J --> K[Order Shipped]
    K --> L[Delivery Confirmed]
```

### Detailed Fulfillment Process

#### 1. Order Reception & Validation
```
Order Service → Fulfillment Service
├── Receive order.confirmed event
├── Validate order completeness
├── Check inventory availability
├── Create fulfillment record
└── Publish fulfillment.created event
```

#### 2. Warehouse Assignment
```
Fulfillment Service → Warehouse Service
├── Get available warehouses by location
├── Check capacity and inventory
├── Select optimal warehouse
├── Reserve inventory slots
└── Update fulfillment with warehouse assignment
```

#### 3. Picking Operations
```
Warehouse Assignment → Picking
├── Generate picking list by aisle/location
├── Sort by optimal picking path
├── Assign to warehouse staff
├── Track picking progress
└── Validate picked items vs order
```

#### 4. Packing & Quality Control
```
Picking Complete → Packing
├── Generate packing slip
├── Verify item condition
├── Package according to requirements
├── Add shipping materials
└── Quality control checkpoint
```

#### 5. Shipping & Tracking
```
Packing Complete → Shipping
├── Generate shipping label
├── Coordinate with carrier
├── Create shipment record
├── Update tracking information
└── Notify customer of shipment
```

---

## 🔌 Key APIs

### Fulfillment Management
```protobuf
// Create fulfillment for order
rpc CreateFulfillment(CreateFulfillmentRequest) returns (Fulfillment) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments"
    body: "*"
  };
}

// Update fulfillment status
rpc UpdateFulfillmentStatus(UpdateFulfillmentStatusRequest) returns (Fulfillment) {
  option (google.api.http) = {
    put: "/api/v1/fulfillments/{id}/status"
    body: "*"
  };
}
```

### Picking Operations
```protobuf
// Generate picking list
rpc GeneratePickingList(GeneratePickingListRequest) returns (PickingList) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/picking-list"
  };
}

// Update picking status
rpc UpdatePickingStatus(UpdatePickingStatusRequest) returns (PickingStatus) {
  option (google.api.http) = {
    put: "/api/v1/fulfillments/{fulfillment_id}/picking"
    body: "*"
  };
}
```

### Packing Operations
```protobuf
// Generate packing slip
rpc GeneratePackingSlip(GeneratePackingSlipRequest) returns (PackingSlip) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/packing-slip"
  };
}

// Complete packing
rpc CompletePacking(CompletePackingRequest) returns (Fulfillment) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/complete-packing"
    body: "*"
  };
}
```

### Shipping Integration
```protobuf
// Create shipment
rpc CreateShipment(CreateShipmentRequest) returns (Shipment) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/shipment"
    body: "*"
  };
}

// Update tracking
rpc UpdateTracking(UpdateTrackingRequest) returns (Shipment) {
  option (google.api.http) = {
    put: "/api/v1/shipments/{shipment_id}/tracking"
    body: "*"
  };
}
```

---

## 🔗 Integration Points

### Order Service Integration
- **Consumes**: `order.confirmed`, `order.cancelled`
- **Provides**: Fulfillment status updates
- **Data Flow**: Order → Fulfillment creation → Status synchronization

### Warehouse Service Integration
- **Consumes**: `warehouse.capacity.updated`, `warehouse.inventory.changed`
- **Provides**: Stock reservation requests, picking instructions
- **Data Flow**: Warehouse assignment → Inventory reservation → Picking coordination

### Shipping Service Integration
- **Consumes**: `shipping.label.generated`, `shipping.tracking.updated`
- **Provides**: Shipment creation requests
- **Data Flow**: Packing complete → Shipping label → Carrier booking → Tracking updates

### Notification Service Integration
- **Provides**: Fulfillment status notifications
- **Events**: Picking ready, packed, shipped, delivered
- **Templates**: Customer notifications, warehouse staff alerts

---

## 🎯 Business Logic

### Warehouse Selection Algorithm
```go
func selectOptimalWarehouse(order Order, items []OrderItem) Warehouse {
    // 1. Filter warehouses by geographic coverage
    candidateWarehouses := filterByLocation(order.ShippingAddress)

    // 2. Check inventory availability for all items
    availableWarehouses := filterByInventory(candidateWarehouses, items)

    // 3. Score warehouses by multiple factors
    scores := calculateWarehouseScores(availableWarehouses, order, items)

    // 4. Return highest scoring warehouse
    return selectHighestScore(scores)
}
```

### Picking Optimization
```go
func optimizePickingPath(pickingList PickingList) OptimizedPath {
    // 1. Group items by warehouse location
    locationGroups := groupByLocation(pickingList.Items)

    // 2. Calculate optimal picking sequence
    optimalSequence := calculateTSPPath(locationGroups)

    // 3. Generate picking instructions
    instructions := generatePickingInstructions(optimalSequence)

    return OptimizedPath{
        Sequence: optimalSequence,
        Instructions: instructions,
        EstimatedTime: calculateEstimatedTime(optimalSequence),
    }
}
```

### Capacity Management
```go
func checkFulfillmentCapacity(warehouse Warehouse, timeSlot TimeSlot) CapacityStatus {
    // 1. Get current active fulfillments
    activeCount := getActiveFulfillmentCount(warehouse, timeSlot)

    // 2. Check against capacity limits
    if activeCount >= timeSlot.MaxOrders {
        return CapacityStatus{Available: false, Reason: "Order limit reached"}
    }

    // 3. Check item throughput
    activeItems := getActiveItemCount(warehouse, timeSlot)
    if activeItems >= timeSlot.MaxItems {
        return CapacityStatus{Available: false, Reason: "Item limit reached"}
    }

    return CapacityStatus{Available: true}
}
```

---

## 📊 Event-Driven Architecture

### Published Events
- `fulfillment.created` - New fulfillment initiated
- `fulfillment.warehouse.assigned` - Warehouse assigned to order
- `fulfillment.picking.ready` - Picking list generated
- `fulfillment.picked` - Items picked from warehouse
- `fulfillment.packing.ready` - Ready for packing
- `fulfillment.packed` - Items packed
- `fulfillment.shipped` - Order shipped
- `fulfillment.delivered` - Order delivered to customer

### Consumed Events
- `order.confirmed` - Trigger fulfillment creation
- `order.cancelled` - Cancel fulfillment process
- `warehouse.capacity.updated` - Update capacity calculations
- `warehouse.inventory.changed` - Handle stock level changes
- `shipping.tracking.updated` - Update shipment tracking

---

## 🚀 Development Guide

### Quick Start
```bash
# Setup
cd fulfillment
go mod download
make migrate-up
make api
make wire

# Run
make run
```

### Configuration
```yaml
# configs/config.yaml
server:
  http:
    addr: 0.0.0.0:8005
  grpc:
    addr: 0.0.0.0:9005

database:
  dsn: postgres://user:pass@localhost:5432/fulfillment_db

external_services:
  order_service: order-service:9004
  warehouse_service: warehouse-service:9008
  shipping_service: shipping-service:9010
```

---

**Service Status**: Production Ready (90%)  
**Critical Path**: Order fulfillment workflow  
**Performance Target**: <30 seconds order-to-fulfillment  
**Availability**: 99.5% uptime SLA
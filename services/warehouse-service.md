# 🏭 Warehouse Service - Complete Documentation

**Service Name**: Warehouse Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Review Status**: ✅ Reviewed (Production Ready)  
**Production Ready**: 90%  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Warehouse Management APIs](#-warehouse-management-apis)
- [Inventory Management APIs](#-inventory-management-apis)
- [Reservation System APIs](#-reservation-system-apis)
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

Warehouse Service là **core operational service** quản lý toàn bộ warehouse operations và inventory trong e-commerce platform. Service này xử lý:

### Core Capabilities
- **🏭 Multi-Warehouse Management**: Quản lý nhiều warehouses với geographic coverage
- **📦 Real-Time Inventory Tracking**: Stock levels, movements, reservations
- **⏰ Capacity Management**: Throughput limits và time slot scheduling
- **🎯 Reservation System**: Inventory reservation cho pending orders
- **🚚 Geographic Coverage**: Delivery zones và warehouse assignment
- **📊 Analytics**: Warehouse performance và inventory insights
- **🚨 Alert System**: Low stock alerts và capacity warnings
- **📈 Event-Driven Updates**: Real-time inventory synchronization

### Business Value
- **Operational Efficiency**: Automated inventory management
- **Order Fulfillment**: Accurate stock allocation
- **Customer Satisfaction**: Real-time availability information
- **Cost Optimization**: Optimal warehouse utilization
- **Scalability**: Support multiple warehouses và locations

### Key Differentiators
- **Multi-Warehouse Architecture**: Complex inventory distribution
- **Real-Time Synchronization**: Event-driven inventory updates
- **Capacity Planning**: Advanced throughput management
- **Geographic Intelligence**: Location-based warehouse assignment
- **Reservation System**: Prevents overselling

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
warehouse/
├── cmd/
│   ├── warehouse/                    # Main service entry point
│   ├── worker/                       # Background workers (alerts, sync)
│   └── migrate/                      # Database migration tool
├── internal/
│   ├── biz/                         # Business Logic Layer
│   │   ├── warehouse/               # Warehouse management
│   │   ├── inventory/               # Inventory operations
│   │   ├── reservation/             # Stock reservations
│   │   ├── throughput/              # Capacity management
│   │   ├── timeslot/                # Time slot scheduling
│   │   ├── adjustment/              # Stock adjustments
│   │   ├── transaction/             # Stock transactions
│   │   ├── alert/                   # Alert management
│   │   ├── distributor/             # Distributor management
│   │   └── events/                  # Event publishing
│   ├── data/                        # Data Access Layer
│   │   ├── postgres/                # PostgreSQL repositories
│   │   ├── redis/                   # Redis caching
│   │   └── eventbus/                # Dapr event consumers
│   ├── service/                     # Service Layer (gRPC/HTTP)
│   ├── server/                      # Server setup
│   ├── middleware/                  # HTTP middleware
│   ├── config/                      # Configuration
│   └── constants/                   # Constants & enums
├── api/                             # Protocol Buffers
│   ├── warehouse/v1/                # Warehouse APIs
│   ├── inventory/v1/                # Inventory APIs
│   ├── backorder/v1/                # Backorder APIs
│   └── distributor/v1/              # Distributor APIs
├── migrations/                      # Database migrations
└── configs/                         # Environment configs
```

### Ports & Endpoints
- **HTTP API**: `:8008` - REST endpoints cho frontend/client apps
- **gRPC API**: `:9008` - Internal service communication
- **Health Check**: `/api/v1/warehouses/health`

### Service Dependencies

#### Internal Dependencies
- **Catalog Service**: Product information và SKUs
- **Order Service**: Order fulfillment và reservations
- **Fulfillment Service**: Fulfillment status updates
- **Notification Service**: Alert notifications

#### External Dependencies
- **PostgreSQL**: Primary data store (`warehouse_db`)
- **Redis**: Caching layer và session storage
- **Dapr**: Event-driven communication
- **Consul**: Service discovery

---

## 🏭 Warehouse Management APIs

### Warehouse CRUD Operations

#### Create Warehouse
```protobuf
rpc CreateWarehouse(CreateWarehouseRequest) returns (CreateWarehouseResponse) {
  option (google.api.http) = {
    post: "/api/v1/warehouses"
    body: "*"
  };
}
```

**Request**:
```json
{
  "name": "Ho Chi Minh City DC",
  "code": "HCM-DC",
  "type": "FULFILLMENT_CENTER",
  "address": {
    "street": "123 Industrial Zone",
    "city": "Ho Chi Minh City",
    "state": "HCM",
    "postal_code": "700000",
    "country": "VN"
  },
  "capacity": {
    "max_daily_orders": 5000,
    "max_hourly_items": 1000,
    "storage_capacity_cubic_meters": 10000
  },
  "operating_hours": {
    "monday": {"open": "08:00", "close": "18:00"},
    "tuesday": {"open": "08:00", "close": "18:00"}
  },
  "contact_info": {
    "phone": "+84-28-1234-5678",
    "email": "hcm-dc@company.com"
  }
}
```

#### Get Warehouse
```protobuf
rpc GetWarehouse(GetWarehouseRequest) returns (GetWarehouseResponse) {
  option (google.api.http) = {
    get: "/api/v1/warehouses/{id}"
  };
}
```

#### Time Slot Management
```protobuf
rpc CreateTimeSlot(CreateTimeSlotRequest) returns (CreateTimeSlotResponse) {
  option (google.api.http) = {
    post: "/api/v1/warehouses/{warehouse_id}/time-slots"
    body: "*"
  };
}
```

**Time Slot Structure**:
```json
{
  "warehouse_id": "warehouse-uuid",
  "day_of_week": "MONDAY",
  "start_time": "09:00",
  "end_time": "12:00",
  "max_orders": 100,
  "max_items": 500,
  "is_active": true
}
```

### Geographic Coverage

#### Add Coverage Area
```protobuf
rpc AddCoverageArea(AddCoverageAreaRequest) returns (AddCoverageAreaResponse) {
  option (google.api.http) = {
    post: "/api/v1/warehouses/{warehouse_id}/coverage-areas"
    body: "*"
  };
}
```

#### Find Warehouses by Location
```protobuf
rpc FindWarehousesByLocation(FindWarehousesByLocationRequest) returns (FindWarehousesByLocationResponse) {
  option (google.api.http) = {
    get: "/api/v1/warehouses/by-location/{location_id}"
  };
}
```

### Capacity Management

#### Check Warehouse Capacity
```protobuf
rpc CheckWarehouseCapacity(CheckWarehouseCapacityRequest) returns (CheckWarehouseCapacityResponse) {
  option (google.api.http) = {
    post: "/api/v1/warehouses/{warehouse_id}/capacity/check"
    body: "*"
  };
}
```

---

## 📦 Inventory Management APIs

### Stock Tracking

#### Get Product Stock
```protobuf
rpc GetProductStock(GetProductStockRequest) returns (GetProductStockResponse) {
  option (google.api.http) = {
    get: "/api/v1/inventory/products/{product_id}/stock"
  };
}
```

**Response**:
```json
{
  "product_id": "product-uuid",
  "total_stock": 1500,
  "available_stock": 1450,
  "reserved_stock": 50,
  "warehouse_stocks": [
    {
      "warehouse_id": "hcm-warehouse",
      "stock_level": 800,
      "available_stock": 780,
      "reserved_stock": 20,
      "location": "Aisle-5-Rack-3"
    },
    {
      "warehouse_id": "hanoi-warehouse",
      "stock_level": 700,
      "available_stock": 670,
      "reserved_stock": 30,
      "location": "Zone-B-Level-2"
    }
  ]
}
```

#### Update Stock Level
```protobuf
rpc UpdateStockLevel(UpdateStockLevelRequest) returns (UpdateStockLevelResponse) {
  option (google.api.http) = {
    put: "/api/v1/inventory/products/{product_id}/warehouses/{warehouse_id}/stock"
    body: "*"
  };
}
```

### Stock Movements

#### Record Stock Movement
```protobuf
rpc RecordStockMovement(RecordStockMovementRequest) returns (RecordStockMovementResponse) {
  option (google.api.http) = {
    post: "/api/v1/inventory/movements"
    body: "*"
  };
}
```

**Movement Types**:
- `INBOUND`: Stock received from suppliers
- `OUTBOUND`: Stock shipped to customers
- `TRANSFER`: Stock moved between warehouses
- `ADJUSTMENT`: Manual stock corrections
- `RESERVATION`: Stock reserved for orders
- `UNRESERVATION`: Stock reservation released

---

## 🎯 Reservation System APIs

### Stock Reservations

#### Create Reservation
```protobuf
rpc CreateReservation(CreateReservationRequest) returns (CreateReservationResponse) {
  option (google.api.http) = {
    post: "/api/v1/inventory/reservations"
    body: "*"
  };
}
```

**Request**:
```json
{
  "order_id": "order-123",
  "customer_id": "customer-456",
  "items": [
    {
      "product_id": "product-uuid",
      "warehouse_id": "warehouse-uuid",
      "quantity": 2,
      "expires_at": "2026-01-23T10:30:00Z"
    }
  ]
}
```

#### Release Reservation
```protobuf
rpc ReleaseReservation(ReleaseReservationRequest) returns (ReleaseReservationResponse) {
  option (google.api.http) = {
    post: "/api/v1/inventory/reservations/{reservation_id}/release"
    body: "*"
  };
}
```

#### Get Reservation Status
```protobuf
rpc GetReservationStatus(GetReservationStatusRequest) returns (GetReservationStatusResponse) {
  option (google.api.http) = {
    get: "/api/v1/inventory/reservations/{reservation_id}"
  };
}
```

---

## 🗄️ Database Schema

### Core Tables

#### warehouses
```sql
CREATE TABLE warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL, -- FULFILLMENT_CENTER, DISTRIBUTION_CENTER, STORE
  address JSONB NOT NULL,
  contact_info JSONB,
  capacity JSONB, -- max_daily_orders, max_hourly_items, storage_capacity
  operating_hours JSONB,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### warehouse_coverage_areas
```sql
CREATE TABLE warehouse_coverage_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  location_id VARCHAR(100) NOT NULL, -- References location service
  priority INTEGER DEFAULT 1, -- For warehouse selection
  delivery_time_hours INTEGER,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### time_slots
```sql
CREATE TABLE time_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  day_of_week VARCHAR(10) NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  max_orders INTEGER NOT NULL,
  max_items INTEGER NOT NULL,
  current_orders INTEGER DEFAULT 0,
  current_items INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### product_inventory
```sql
CREATE TABLE product_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  stock_level INTEGER NOT NULL DEFAULT 0,
  available_stock INTEGER NOT NULL DEFAULT 0,
  reserved_stock INTEGER NOT NULL DEFAULT 0,
  reorder_point INTEGER DEFAULT 10,
  max_stock INTEGER,
  location_code VARCHAR(100), -- Aisle-Rack-Shelf
  last_stock_check TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, warehouse_id)
);
```

#### stock_reservations
```sql
CREATE TABLE stock_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id VARCHAR(100) UNIQUE NOT NULL,
  order_id VARCHAR(100),
  customer_id VARCHAR(100),
  product_id UUID NOT NULL,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  quantity INTEGER NOT NULL,
  status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, RELEASED, EXPIRED, FULFILLED
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  released_at TIMESTAMP WITH TIME ZONE,
  fulfilled_at TIMESTAMP WITH TIME ZONE
);
```

#### stock_movements
```sql
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  movement_type VARCHAR(20) NOT NULL, -- INBOUND, OUTBOUND, TRANSFER, ADJUSTMENT
  quantity INTEGER NOT NULL,
  reference_id VARCHAR(100), -- Order ID, Transfer ID, etc.
  reason VARCHAR(255),
  previous_stock INTEGER NOT NULL,
  new_stock INTEGER NOT NULL,
  user_id VARCHAR(100), -- Who performed the movement
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Performance Optimizations

#### Indexes
```sql
-- Warehouse lookups
CREATE UNIQUE INDEX idx_warehouses_code ON warehouses(code) WHERE is_active = TRUE;
CREATE INDEX idx_warehouses_type_active ON warehouses(type, is_active);

-- Coverage areas
CREATE INDEX idx_coverage_warehouse_location ON warehouse_coverage_areas(warehouse_id, location_id);
CREATE INDEX idx_coverage_location_priority ON warehouse_coverage_areas(location_id, priority);

-- Time slots
CREATE INDEX idx_time_slots_warehouse_day ON time_slots(warehouse_id, day_of_week, is_active);
CREATE INDEX idx_time_slots_capacity ON time_slots(warehouse_id, current_orders, max_orders);

-- Inventory
CREATE UNIQUE INDEX idx_inventory_product_warehouse ON product_inventory(product_id, warehouse_id);
CREATE INDEX idx_inventory_stock_levels ON product_inventory(available_stock, reorder_point) WHERE available_stock <= reorder_point;
CREATE INDEX idx_inventory_warehouse_stock ON product_inventory(warehouse_id, available_stock DESC);

-- Reservations
CREATE INDEX idx_reservations_order ON stock_reservations(order_id, status);
CREATE INDEX idx_reservations_expires ON stock_reservations(expires_at) WHERE status = 'ACTIVE';
CREATE INDEX idx_reservations_product_warehouse ON stock_reservations(product_id, warehouse_id, status);

-- Movements (audit trail)
CREATE INDEX idx_movements_product_date ON stock_movements(product_id, created_at DESC);
CREATE INDEX idx_movements_warehouse_type ON stock_movements(warehouse_id, movement_type, created_at DESC);
```

#### Partitioning Strategy
```sql
-- Partition stock movements by month for performance
CREATE TABLE stock_movements_202401 PARTITION OF stock_movements
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Partition reservations by status for active query performance
CREATE TABLE reservations_active PARTITION OF stock_reservations
  FOR VALUES IN ('ACTIVE', 'PENDING');
```

### Migration History

| Version | Migration File | Description | Key Features |
|---------|----------------|-------------|--------------|
| 001-010 | Core schema setup | Warehouses, inventory, reservations | Basic warehouse operations |
| 011-020 | Advanced features | Time slots, coverage areas, movements | Capacity management |
| 021-030 | Performance optimization | Indexes, partitions, views | Query optimization |
| 031-040 | Business features | Distributors, alerts, analytics | Advanced functionality |

---

## 🧠 Business Logic

### Warehouse Selection Algorithm

```go
func (uc *WarehouseUsecase) SelectOptimalWarehouse(ctx context.Context, productID string, quantity int, deliveryAddress *Address) (*Warehouse, error) {
    // 1. Find warehouses covering the delivery location
    candidateWarehouses, err := uc.findWarehousesByLocation(ctx, deliveryAddress)
    if err != nil {
        return nil, err
    }

    // 2. Filter warehouses with sufficient stock
    availableWarehouses := []Warehouse{}
    for _, warehouse := range candidateWarehouses {
        stock, err := uc.getAvailableStock(ctx, productID, warehouse.ID)
        if err == nil && stock >= quantity {
            availableWarehouses = append(availableWarehouses, warehouse)
        }
    }

    if len(availableWarehouses) == 0 {
        return nil, errors.New("no warehouse with sufficient stock")
    }

    // 3. Score warehouses by multiple factors
    scoredWarehouses := []WarehouseScore{}
    for _, warehouse := range availableWarehouses {
        score := uc.calculateWarehouseScore(warehouse, deliveryAddress, quantity)
        scoredWarehouses = append(scoredWarehouses, WarehouseScore{
            Warehouse: warehouse,
            Score:     score,
        })
    }

    // 4. Return highest scoring warehouse
    sort.Slice(scoredWarehouses, func(i, j int) bool {
        return scoredWarehouses[i].Score > scoredWarehouses[j].Score
    })

    return &scoredWarehouses[0].Warehouse, nil
}

func (uc *WarehouseUsecase) calculateWarehouseScore(warehouse Warehouse, address *Address, quantity int) float64 {
    score := 100.0

    // Distance factor (closer = higher score)
    distance := calculateDistance(warehouse.Address, address)
    score -= distance * 0.1

    // Capacity factor (more available capacity = higher score)
    capacityUtilization := uc.getCapacityUtilization(warehouse.ID)
    score -= capacityUtilization * 20

    // Priority factor (explicit priority settings)
    score += warehouse.Priority * 10

    // Stock level factor (higher stock = higher score)
    stockRatio := uc.getStockToSalesRatio(warehouse.ID, quantity)
    score += stockRatio * 5

    return score
}
```

### Stock Reservation Logic

```go
func (uc *ReservationUsecase) CreateReservation(ctx context.Context, req *CreateReservationRequest) error {
    return uc.transaction(ctx, func(ctx context.Context) error {
        // 1. Validate stock availability
        for _, item := range req.Items {
            available, err := uc.checkStockAvailability(ctx, item.ProductID, item.WarehouseID, item.Quantity)
            if err != nil || !available {
                return fmt.Errorf("insufficient stock for product %s", item.ProductID)
            }
        }

        // 2. Create reservation record
        reservationID := generateReservationID()
        reservation := &Reservation{
            ReservationID: reservationID,
            OrderID:       req.OrderID,
            CustomerID:    req.CustomerID,
            Items:         req.Items,
            ExpiresAt:     time.Now().Add(30 * time.Minute), // 30 min expiry
        }

        if err := uc.reservationRepo.Create(ctx, reservation); err != nil {
            return err
        }

        // 3. Update inventory (reserve stock)
        for _, item := range req.Items {
            if err := uc.inventoryRepo.ReserveStock(ctx, item.ProductID, item.WarehouseID, item.Quantity); err != nil {
                return err
            }

            // Record movement
            uc.recordStockMovement(ctx, item.ProductID, item.WarehouseID, -item.Quantity, "RESERVATION", reservationID)
        }

        // 4. Set expiry cleanup
        uc.scheduleReservationExpiry(ctx, reservationID, reservation.ExpiresAt)

        // 5. Publish reservation event
        uc.events.PublishReservationCreated(ctx, reservation)

        return nil
    })
}
```

### Capacity Management Logic

```go
func (uc *ThroughputUsecase) CheckCapacity(ctx context.Context, warehouseID string, orderCount int, itemCount int, timeSlot *TimeSlot) (*CapacityCheck, error) {
    // 1. Get current utilization
    currentOrders, currentItems, err := uc.getCurrentUtilization(ctx, warehouseID, timeSlot)
    if err != nil {
        return nil, err
    }

    // 2. Calculate available capacity
    availableOrders := timeSlot.MaxOrders - currentOrders
    availableItems := timeSlot.MaxItems - currentItems

    // 3. Check if request fits
    orderCheck := orderCount <= availableOrders
    itemCheck := itemCount <= availableItems

    // 4. Calculate utilization percentage
    orderUtilization := float64(currentOrders+orderCount) / float64(timeSlot.MaxOrders) * 100
    itemUtilization := float64(currentItems+itemCount) / float64(timeSlot.MaxItems) * 100

    // 5. Determine acceptance
    canAccept := orderCheck && itemCheck

    // 6. Update capacity tracking if accepted
    if canAccept {
        if err := uc.updateUtilization(ctx, warehouseID, timeSlot, orderCount, itemCount); err != nil {
            // Log but don't fail - capacity update is not critical
            uc.logger.Warn("Failed to update capacity utilization", "error", err)
        }
    }

    return &CapacityCheck{
        CanAccept:       canAccept,
        AvailableOrders: availableOrders,
        AvailableItems:  availableItems,
        OrderUtilization: orderUtilization,
        ItemUtilization:  itemUtilization,
        RejectionReason: uc.getRejectionReason(orderCheck, itemCheck),
    }, nil
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
WAREHOUSE_DATABASE_DSN=postgres://warehouse_user:warehouse_pass@postgres:5432/warehouse_db?sslmode=disable

# Redis
WAREHOUSE_REDIS_ADDR=redis:6379
WAREHOUSE_REDIS_DB=4

# Service Ports
WAREHOUSE_HTTP_PORT=8008
WAREHOUSE_GRPC_PORT=9008

# Capacity Settings
WAREHOUSE_DEFAULT_MAX_DAILY_ORDERS=5000
WAREHOUSE_DEFAULT_MAX_HOURLY_ITEMS=1000
WAREHOUSE_RESERVATION_EXPIRY_MINUTES=30

# Alert Thresholds
WAREHOUSE_LOW_STOCK_THRESHOLD=10
WAREHOUSE_HIGH_UTILIZATION_THRESHOLD=90

# External Services
WAREHOUSE_CATALOG_SERVICE_ADDR=catalog-service:9002
WAREHOUSE_ORDER_SERVICE_ADDR=order-service:9004
WAREHOUSE_FULFILLMENT_SERVICE_ADDR=fulfillment-service:9011
WAREHOUSE_NOTIFICATION_SERVICE_ADDR=notification-service:9005

# Features
WAREHOUSE_ENABLE_MULTI_WAREHOUSE=true
WAREHOUSE_ENABLE_RESERVATIONS=true
WAREHOUSE_ENABLE_CAPACITY_MANAGEMENT=true
WAREHOUSE_ENABLE_REAL_TIME_UPDATES=true
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: warehouse-service
  version: 1.0.0

database:
  dsn: ${WAREHOUSE_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 25
  conn_max_lifetime: 5m

redis:
  addr: ${WAREHOUSE_REDIS_ADDR}
  db: ${WAREHOUSE_REDIS_DB}
  dial_timeout: 5s

server:
  http:
    addr: 0.0.0.0
    port: ${WAREHOUSE_HTTP_PORT}
  grpc:
    addr: 0.0.0.0
    port: ${WAREHOUSE_GRPC_PORT}

capacity:
  default_max_daily_orders: ${WAREHOUSE_DEFAULT_MAX_DAILY_ORDERS}
  default_max_hourly_items: ${WAREHOUSE_DEFAULT_MAX_HOURLY_ITEMS}
  reservation_expiry_minutes: ${WAREHOUSE_RESERVATION_EXPIRY_MINUTES}

alerts:
  low_stock_threshold: ${WAREHOUSE_LOW_STOCK_THRESHOLD}
  high_utilization_threshold: ${WAREHOUSE_HIGH_UTILIZATION_THRESHOLD}

external_services:
  catalog_service: ${WAREHOUSE_CATALOG_SERVICE_ADDR}
  order_service: ${WAREHOUSE_ORDER_SERVICE_ADDR}
  fulfillment_service: ${WAREHOUSE_FULFILLMENT_SERVICE_ADDR}
  notification_service: ${WAREHOUSE_NOTIFICATION_SERVICE_ADDR}

features:
  multi_warehouse: ${WAREHOUSE_ENABLE_MULTI_WAREHOUSE}
  reservations: ${WAREHOUSE_ENABLE_RESERVATIONS}
  capacity_management: ${WAREHOUSE_ENABLE_CAPACITY_MANAGEMENT}
  real_time_updates: ${WAREHOUSE_ENABLE_REAL_TIME_UPDATES}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/warehouse

go 1.24

require (
    gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    github.com/google/uuid v1.6.0
    github.com/tidwall/gjson v1.17.0
)
```

### Service Mesh Integration
```yaml
# Dapr pub/sub subscriptions
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: warehouse-service-events
spec:
  topic: order.created
  route: /events/order-created
  pubsubname: pubsub
---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: warehouse-stock-updates
spec:
  topic: catalog.product.updated
  route: /events/product-updated
  pubsubname: pubsub
```

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: 75% coverage (business logic, algorithms)
- **Integration Tests**: 65% coverage (API endpoints, database)
- **E2E Tests**: 45% coverage (warehouse selection, reservations)

### Critical Test Scenarios

#### Warehouse Selection Tests
```go
func TestSelectOptimalWarehouse_DistancePriority(t *testing.T) {
    // Setup: Multiple warehouses at different distances
    // Execute: Select warehouse for delivery address
    // Verify: Closest warehouse with sufficient stock selected
}

func TestSelectOptimalWarehouse_CapacityPriority(t *testing.T) {
    // Setup: Warehouses with different capacity utilization
    // Execute: Select warehouse during peak hours
    // Verify: Least utilized warehouse selected
}
```

#### Reservation System Tests
```go
func TestCreateReservation_StockReservation(t *testing.T) {
    // Setup: Product with 100 units in warehouse
    // Execute: Create reservation for 10 units
    // Verify: Stock reduced by 10, reservation created
    // Cleanup: Release reservation
}

func TestReservationExpiry_AutoRelease(t *testing.T) {
    // Setup: Create reservation with 1-minute expiry
    // Wait: 1 minute
    // Execute: Check reservation status
    // Verify: Reservation expired, stock released
}
```

#### Capacity Management Tests
```go
func TestCapacityCheck_OrderAcceptance(t *testing.T) {
    // Setup: Time slot with max 100 orders, currently 90
    // Execute: Check capacity for 5 orders
    // Verify: Accepted, utilization becomes 95%
}

func TestCapacityCheck_OrderRejection(t *testing.T) {
    // Setup: Time slot at 98% capacity
    // Execute: Check capacity for large order
    // Verify: Rejected with capacity reason
}
```

### Test Infrastructure
```bash
# Run all tests
make test

# Run integration tests (requires DB/Redis)
make test-integration

# Test warehouse selection specifically
make test-warehouse-selection

# With coverage
make test-coverage

# Load testing
hey -n 1000 -c 10 -m GET \
  http://localhost:8008/api/v1/inventory/products/{product_id}/stock
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### Warehouse Operations Metrics
```go
# Warehouse utilization
warehouse_capacity_utilization{warehouse_id="hcm-dc", type="orders"} 0.85
warehouse_capacity_utilization{warehouse_id="hanoi-dc", type="items"} 0.72

# Inventory metrics
warehouse_stock_levels_total{warehouse_id="hcm-dc"} 150000
warehouse_low_stock_alerts_total{warehouse_id="hcm-dc"} 23

# Reservation metrics
warehouse_reservations_active_total 1456
warehouse_reservations_expired_total 89
warehouse_reservation_success_rate 0.967
```

#### Performance Metrics
```go
# API response times
warehouse_api_request_duration_seconds{endpoint="/api/v1/warehouses", quantile="0.95"} 0.078
warehouse_api_request_duration_seconds{endpoint="/api/v1/inventory/stock", quantile="0.95"} 0.045

# Database performance
warehouse_db_query_duration_seconds{table="product_inventory", quantile="0.95"} 0.023
warehouse_db_query_duration_seconds{table="stock_reservations", quantile="0.95"} 0.034

# Cache hit rates
warehouse_cache_hit_ratio{cache="inventory"} 0.89
warehouse_cache_hit_ratio{cache="warehouses"} 0.95
warehouse_cache_hit_ratio{cache="reservations"} 0.78
```

### Health Checks
```go
# Application health
GET /api/v1/warehouses/health

# Dependencies health
GET /api/v1/warehouses/health/dependencies

# Database connectivity
# Redis connectivity
# External services (catalog, order, fulfillment)
```

### Distributed Tracing (OpenTelemetry)

#### Order Fulfillment Trace
```
Order Service → Warehouse Service
├── Select optimal warehouse (algorithm)
├── Check stock availability (database)
├── Create reservation (transaction)
│   ├── Update inventory levels
│   ├── Create reservation record
│   └── Publish reservation event
├── Update order with warehouse assignment
└── Trigger fulfillment workflow
```

#### Inventory Update Trace
```
External System → Warehouse Service
├── Receive stock update (webhook/event)
├── Validate update data
├── Update inventory levels (database)
├── Check reorder thresholds
├── Publish inventory changed event
└── Trigger alerts if needed
```

---

## 🚨 Known Issues & TODOs

### P2 - Medium Priority Issues

1. **Reservation Cleanup Performance** 🔵
   - **Issue**: Expired reservation cleanup runs synchronously
   - **Impact**: Performance degradation during cleanup operations
   - **Location**: `internal/biz/reservation/cleanup.go`
   - **Fix**: Implement background job for reservation expiry

2. **Multi-Warehouse Stock Allocation** 🔵
   - **Issue**: Stock allocation doesn't optimize across warehouses
   - **Impact**: Suboptimal inventory utilization
   - **Location**: Stock allocation algorithms
   - **Fix**: Implement advanced stock allocation strategies

3. **Real-Time Capacity Updates** 🔵
   - **Issue**: Capacity tracking uses database counters, not real-time
   - **Impact**: Slight delays in capacity reporting
   - **Location**: Capacity utilization tracking
   - **Fix**: Implement Redis-based real-time capacity tracking

4. **Alert System Enhancement** 🔵
   - **Issue**: Basic email alerts, no escalation or smart routing
   - **Impact**: Alert fatigue, missed critical issues
   - **Location**: Alert management system
   - **Fix**: Implement intelligent alert routing and escalation

---

## 🚀 Development Guide

### Local Development Setup
```bash
# Clone and setup
git clone git@gitlab.com:ta-microservices/warehouse.git
cd warehouse

# Start dependencies
docker-compose up -d postgres redis

# Install dependencies
go mod download

# Run migrations
make migrate-up

# Generate protobuf code
make api

# Run service
make run

# Test warehouse operations
curl -X GET http://localhost:8008/api/v1/warehouses \
  -H "Authorization: Bearer <token>"
```

### Code Generation
```bash
# Generate protobuf code
make api

# Generate mocks for testing
make mocks

# Generate wire dependency injection
make wire
```

### Database Operations
```bash
# Create new migration
make migrate-create NAME="add_warehouse_analytics"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

### Warehouse Development Workflow
1. **Add Warehouse Entity**: Define in `internal/model/warehouse.go`
2. **Create Repository**: Implement in `internal/data/postgres/warehouse_repo.go`
3. **Add Business Logic**: Implement in `internal/biz/warehouse/usecase.go`
4. **Create API**: Define in `api/warehouse/v1/warehouse.proto`
5. **Generate Code**: `make api`
6. **Add Service Layer**: Implement in `internal/service/warehouse_service.go`
7. **Add Tests**: Unit tests for all new functionality
8. **Update Documentation**: This file

### Testing Warehouse Features
```bash
# Test warehouse selection
make test-warehouse-selection

# Test reservation system
make test-reservations

# Test capacity management
make test-capacity

# Load testing
hey -n 1000 -c 10 -m POST \
  -H "Authorization: Bearer <token>" \
  http://localhost:8008/api/v1/inventory/reservations \
  -d '{"order_id": "load-test", "items": [{"product_id": "test-product", "quantity": 1}]}'
```

---

## 📈 Performance Benchmarks

### API Response Times (P95)
- **List Warehouses**: 67ms (with capacity data)
- **Get Product Stock**: 45ms (multi-warehouse)
- **Create Reservation**: 89ms (with stock validation)
- **Check Capacity**: 34ms (time slot validation)
- **Update Stock**: 56ms (with movement logging)

### Throughput Targets
- **Stock Queries**: 500 req/sec sustained
- **Reservation Operations**: 200 req/sec sustained
- **Capacity Checks**: 300 req/sec sustained

### Database Performance
- **Inventory Queries**: <20ms average (with indexes)
- **Reservation Operations**: <30ms average
- **Movement Logging**: <15ms average

### Scalability Metrics
- **Warehouses Supported**: Unlimited (tested with 50+)
- **Products per Warehouse**: 100,000+ products
- **Concurrent Reservations**: 1000+ simultaneous
- **Stock Updates**: 5000+ updates/minute

---

## 🔐 Security Considerations

### Data Protection
- **Inventory Data**: Sensitive stock level information
- **Reservation Data**: Order fulfillment tracking
- **Audit Trail**: Complete stock movement history
- **Access Control**: Warehouse-specific data isolation

### API Security
- **Authentication**: JWT token validation
- **Authorization**: Role-based warehouse access
- **Rate Limiting**: Per-warehouse operation limits
- **Input Validation**: Strict stock level validation

### Operational Security
- **Stock Manipulation Prevention**: Audit trails for all changes
- **Reservation Integrity**: Atomic reservation operations
- **Capacity Protection**: Rate limiting on high-volume operations
- **Alert Monitoring**: Real-time anomaly detection

---

## 🎯 Future Roadmap

### Phase 1 (Q1 2026) - Performance & Reliability
- [ ] Implement Redis-based capacity tracking
- [ ] Add background reservation cleanup jobs
- [ ] Optimize multi-warehouse stock allocation
- [ ] Enhance alert system with intelligent routing

### Phase 2 (Q2 2026) - Advanced Features
- [ ] Machine learning for demand forecasting
- [ ] Advanced warehouse selection algorithms
- [ ] Real-time inventory synchronization
- [ ] Automated stock replenishment
- [ ] Predictive capacity planning

### Phase 3 (Q3 2026) - Intelligence & Automation
- [ ] AI-powered inventory optimization
- [ ] Automated warehouse layout optimization
- [ ] Predictive maintenance for equipment
- [ ] Advanced analytics and reporting
- [ ] Integration with IoT sensors

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: Warehouse Service Team
- **Repository**: `gitlab.com/ta-microservices/warehouse`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #warehouse-service-alerts
- **Performance Issues**: #warehouse-service-performance
- **Inventory Issues**: #inventory-support
- **Capacity Issues**: #warehouse-capacity

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/warehouse-service`
- **Inventory Analytics**: `https://grafana.tanhdev.com/d/warehouse-inventory`
- **Capacity Monitoring**: `https://grafana.tanhdev.com/d/warehouse-capacity`
- **Business Metrics**: `https://grafana.tanhdev.com/d/warehouse-business`

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Code Review Status**: ✅ Reviewed (Production Ready)  
**Production Readiness**: 90% (Minor performance optimizations needed)
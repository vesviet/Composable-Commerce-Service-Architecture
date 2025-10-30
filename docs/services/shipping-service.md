# Shipping Service

> **Service Type**: Application Service (Business Logic)  
> **Last Updated**: October 30, 2024  
> **Status**: Complete Documentation

---

## 📋 Service Overview

### Description
Service that manages shipping and fulfillment operations, including last-mile and first-mile logistics, carrier integration, and delivery tracking. The service handles the complete fulfillment lifecycle from warehouse to customer delivery.

### Business Context
The Shipping Service orchestrates the physical delivery of orders by managing fulfillment entities, integrating with multiple carriers, and providing real-time tracking capabilities. It supports complex fulfillment scenarios including multi-warehouse orders, split shipments, and return processing.

### Key Responsibilities
- Fulfillment entity management and orchestration
- Multi-carrier integration (UPS, FedEx, DHL, local carriers)
- Shipping rate calculation and carrier selection
- Label generation and tracking management
- Last-mile and first-mile logistics coordination
- Delivery status tracking and notifications
- Return and exchange processing
- Proof of delivery management

---

## 🏗️ Architecture

### Service Type
- [x] Application Service (Business Logic)
- [ ] Infrastructure Service (Supporting)
- [ ] Gateway Service (API Gateway/BFF)

### Technology Stack
- **Framework**: go-kratos/kratos v2.7+
- **Database**: PostgreSQL 15+ (shipments, fulfillments)
- **Cache**: Redis 7+ (tracking cache, rate cache)
- **Message Queue**: Dapr Pub/Sub with Redis Streams
- **External APIs**: UPS, FedEx, DHL APIs, Local carrier APIs

### Deployment
- **Container**: Docker
- **Orchestration**: Kubernetes with Dapr
- **Service Discovery**: Consul
- **Load Balancer**: Kubernetes Service + Ingress

---

## 🚚 Core Entities

### Fulfillment Entity
The central entity that represents a physical delivery unit and manages the complete delivery workflow.

```json
{
  "id": "fulfillment_123",
  "type": "standard", // standard, express, same_day, pickup
  "status": "in_transit",
  "orderId": "order_789",
  "warehouseId": "WH001",
  "customerId": "cust_456",
  "items": [
    {
      "productId": "prod_123",
      "sku": "LAPTOP-001",
      "quantity": 1,
      "weight": 2.5,
      "dimensions": {
        "length": 35,
        "width": 25,
        "height": 5
      }
    }
  ],
  "addresses": {
    "origin": {
      "warehouseId": "WH001",
      "address": "123 Warehouse St, City, State 12345"
    },
    "destination": {
      "customerId": "cust_456",
      "address": "456 Customer Ave, City, State 67890"
    }
  },
  "carrier": {
    "carrierId": "ups",
    "service": "ground",
    "trackingNumber": "1Z999AA1234567890"
  },
  "timeline": {
    "createdAt": "2024-10-30T10:00:00Z",
    "pickedUpAt": "2024-10-30T14:00:00Z",
    "inTransitAt": "2024-10-30T16:00:00Z",
    "estimatedDelivery": "2024-11-01T17:00:00Z"
  }
}
```

---

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/shipping
Staging: https://staging-api.domain.com/v1/shipping
Local: http://localhost:8006/v1/shipping
```

### Authentication
- **Type**: JWT Bearer Token
- **Required Scopes**: `shipping:read`, `shipping:write`, `shipping:admin`
- **Rate Limiting**: 500 requests/minute per user

### Fulfillment Management APIs

#### POST /fulfillments
**Purpose**: Create a new fulfillment entity

**Request**:
```http
POST /v1/shipping/fulfillments
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "orderId": "order_789",
  "warehouseId": "WH001",
  "customerId": "cust_456",
  "type": "standard",
  "items": [
    {
      "productId": "prod_123",
      "sku": "LAPTOP-001",
      "quantity": 1,
      "weight": 2.5,
      "dimensions": {
        "length": 35,
        "width": 25,
        "height": 5
      }
    }
  ],
  "addresses": {
    "destination": {
      "firstName": "John",
      "lastName": "Doe",
      "street": "456 Customer Ave",
      "city": "New York",
      "state": "NY",
      "zipCode": "10001",
      "country": "US",
      "phone": "+1-555-0123"
    }
  },
  "preferences": {
    "carrierPreference": "ups",
    "serviceLevel": "ground",
    "deliveryInstructions": "Leave at front door",
    "signatureRequired": false
  }
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "fulfillment": {
      "id": "fulfillment_123",
      "orderId": "order_789",
      "status": "created",
      "type": "standard",
      "warehouseId": "WH001",
      "estimatedPickup": "2024-10-30T14:00:00Z",
      "estimatedDelivery": "2024-11-01T17:00:00Z",
      "createdAt": "2024-10-30T10:00:00Z"
    }
  }
}
```

#### GET /fulfillments/{fulfillmentId}
**Purpose**: Get fulfillment details and status

**Response**:
```json
{
  "success": true,
  "data": {
    "fulfillment": {
      "id": "fulfillment_123",
      "orderId": "order_789",
      "status": "in_transit",
      "type": "standard",
      "warehouseId": "WH001",
      "customerId": "cust_456",
      "items": [...],
      "addresses": {...},
      "carrier": {
        "carrierId": "ups",
        "carrierName": "UPS",
        "service": "ground",
        "trackingNumber": "1Z999AA1234567890",
        "trackingUrl": "https://ups.com/track/1Z999AA1234567890"
      },
      "timeline": {
        "createdAt": "2024-10-30T10:00:00Z",
        "pickedUpAt": "2024-10-30T14:00:00Z",
        "inTransitAt": "2024-10-30T16:00:00Z",
        "estimatedDelivery": "2024-11-01T17:00:00Z"
      },
      "trackingEvents": [
        {
          "status": "picked_up",
          "location": "New York, NY",
          "timestamp": "2024-10-30T14:00:00Z",
          "description": "Package picked up from warehouse"
        },
        {
          "status": "in_transit",
          "location": "Philadelphia, PA",
          "timestamp": "2024-10-30T16:00:00Z",
          "description": "Package in transit"
        }
      ]
    }
  }
}
```

#### PUT /fulfillments/{fulfillmentId}/status
**Purpose**: Update fulfillment status

#### POST /fulfillments/{fulfillmentId}/cancel
**Purpose**: Cancel fulfillment

### Shipping Rate APIs

#### POST /rates/calculate
**Purpose**: Calculate shipping rates for multiple carriers

**Request**:
```http
POST /v1/shipping/rates/calculate
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "origin": {
    "warehouseId": "WH001",
    "zipCode": "10001",
    "country": "US"
  },
  "destination": {
    "zipCode": "90210",
    "country": "US"
  },
  "packages": [
    {
      "weight": 2.5,
      "dimensions": {
        "length": 35,
        "width": 25,
        "height": 5
      }
    }
  ],
  "serviceTypes": ["ground", "express", "overnight"]
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "rates": [
      {
        "carrierId": "ups",
        "carrierName": "UPS",
        "service": "ground",
        "serviceName": "UPS Ground",
        "rate": 12.50,
        "currency": "USD",
        "estimatedDays": 3,
        "estimatedDelivery": "2024-11-01T17:00:00Z"
      },
      {
        "carrierId": "fedex",
        "carrierName": "FedEx",
        "service": "ground",
        "serviceName": "FedEx Ground",
        "rate": 13.25,
        "currency": "USD",
        "estimatedDays": 3,
        "estimatedDelivery": "2024-11-01T17:00:00Z"
      }
    ]
  }
}
```

### Tracking APIs

#### GET /tracking/{trackingNumber}
**Purpose**: Get tracking information

#### POST /tracking/webhook
**Purpose**: Receive tracking updates from carriers

### Label Management APIs

#### POST /labels/generate
**Purpose**: Generate shipping labels

#### GET /labels/{labelId}
**Purpose**: Get shipping label (PDF)

## 🗄️ Database Schema

### Primary Database: PostgreSQL

#### fulfillments
```sql
CREATE TABLE fulfillments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    warehouse_id VARCHAR(50) NOT NULL,
    customer_id UUID NOT NULL,
    
    -- Fulfillment details
    type VARCHAR(20) NOT NULL DEFAULT 'standard',
    status VARCHAR(20) NOT NULL DEFAULT 'created',
    priority INTEGER DEFAULT 0,
    
    -- Items (JSONB for flexibility)
    items JSONB NOT NULL,
    
    -- Addresses
    origin_address JSONB NOT NULL,
    destination_address JSONB NOT NULL,
    
    -- Carrier information
    carrier_id VARCHAR(50),
    carrier_service VARCHAR(50),
    tracking_number VARCHAR(100),
    label_url VARCHAR(500),
    
    -- Dimensions and weight
    total_weight DECIMAL(8,2),
    total_dimensions JSONB,
    
    -- Timeline
    estimated_pickup TIMESTAMP WITH TIME ZONE,
    estimated_delivery TIMESTAMP WITH TIME ZONE,
    actual_pickup TIMESTAMP WITH TIME ZONE,
    actual_delivery TIMESTAMP WITH TIME ZONE,
    
    -- Preferences and instructions
    delivery_instructions TEXT,
    signature_required BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    
    -- Indexes
    INDEX idx_fulfillments_order (order_id),
    INDEX idx_fulfillments_warehouse (warehouse_id),
    INDEX idx_fulfillments_customer (customer_id),
    INDEX idx_fulfillments_status (status),
    INDEX idx_fulfillments_tracking (tracking_number),
    INDEX idx_fulfillments_carrier (carrier_id),
    INDEX idx_fulfillments_created (created_at),
    
    -- Constraints
    CONSTRAINT chk_fulfillments_type CHECK (type IN ('standard', 'express', 'same_day', 'pickup', 'return')),
    CONSTRAINT chk_fulfillments_status CHECK (status IN ('created', 'confirmed', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'failed', 'cancelled', 'returned'))
);
```

#### shipments
```sql
CREATE TABLE shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
    
    -- Shipment details
    shipment_number VARCHAR(100) UNIQUE NOT NULL,
    carrier_id VARCHAR(50) NOT NULL,
    carrier_service VARCHAR(50) NOT NULL,
    tracking_number VARCHAR(100) UNIQUE NOT NULL,
    
    -- Package details
    package_count INTEGER DEFAULT 1,
    total_weight DECIMAL(8,2),
    dimensions JSONB,
    
    -- Costs
    shipping_cost DECIMAL(10,2),
    insurance_cost DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Status and timeline
    status VARCHAR(20) NOT NULL DEFAULT 'created',
    shipped_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    
    -- Label and documentation
    label_url VARCHAR(500),
    commercial_invoice_url VARCHAR(500),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_shipments_fulfillment (fulfillment_id),
    INDEX idx_shipments_tracking (tracking_number),
    INDEX idx_shipments_carrier (carrier_id),
    INDEX idx_shipments_status (status)
);
```

#### tracking_events
```sql
CREATE TABLE tracking_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
    tracking_number VARCHAR(100) NOT NULL,
    
    -- Event details
    event_type VARCHAR(50) NOT NULL,
    event_status VARCHAR(50) NOT NULL,
    event_description TEXT,
    
    -- Location
    location_city VARCHAR(100),
    location_state VARCHAR(50),
    location_country VARCHAR(2),
    location_zipcode VARCHAR(20),
    
    -- Timing
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Source
    carrier_id VARCHAR(50) NOT NULL,
    raw_data JSONB,
    
    -- Indexes
    INDEX idx_tracking_events_fulfillment (fulfillment_id),
    INDEX idx_tracking_events_tracking (tracking_number),
    INDEX idx_tracking_events_timestamp (event_timestamp),
    INDEX idx_tracking_events_carrier (carrier_id)
);
```

#### carriers
```sql
CREATE TABLE carriers (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL, -- national, regional, local, same_day
    
    -- Configuration
    api_endpoint VARCHAR(200),
    api_credentials JSONB, -- Encrypted
    supported_services JSONB,
    coverage_areas JSONB,
    
    -- Capabilities
    supports_tracking BOOLEAN DEFAULT TRUE,
    supports_labels BOOLEAN DEFAULT TRUE,
    supports_rates BOOLEAN DEFAULT TRUE,
    supports_pickup BOOLEAN DEFAULT FALSE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',
    priority INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_carriers_type (type),
    INDEX idx_carriers_status (status),
    INDEX idx_carriers_priority (priority)
);
```

### Cache Schema (Redis)
```
# Fulfillment cache
Key: shipping:fulfillment:{fulfillment_id}
TTL: 1800 seconds (30 minutes)
Value: JSON serialized fulfillment data

# Tracking cache
Key: shipping:tracking:{tracking_number}
TTL: 300 seconds (5 minutes)
Value: JSON serialized tracking events

# Rate cache
Key: shipping:rates:{hash_of_request}
TTL: 3600 seconds (1 hour)
Value: JSON serialized shipping rates

# Carrier status cache
Key: shipping:carriers:active
TTL: 7200 seconds (2 hours)
Value: JSON serialized active carriers
```

## 🚚 Fulfillment Workflow

### Fulfillment State Machine
```mermaid
stateDiagram-v2
    [*] --> Created
    Created --> Confirmed : Validate & Confirm
    Confirmed --> PickedUp : Carrier Pickup
    PickedUp --> InTransit : In Transit
    InTransit --> OutForDelivery : Out for Delivery
    OutForDelivery --> Delivered : Delivery Confirmed
    
    Created --> Cancelled : Cancel Before Pickup
    Confirmed --> Cancelled : Cancel Before Pickup
    PickedUp --> Failed : Delivery Failed
    InTransit --> Failed : Delivery Failed
    OutForDelivery --> Failed : Delivery Failed
    
    Failed --> Returned : Return to Sender
    Delivered --> Returned : Customer Return
```

### Carrier Integration Flow
```mermaid
sequenceDiagram
    participant O as Order Service
    participant S as Shipping Service
    participant C as Carrier API
    participant T as Tracking Service
    participant N as Notification Service
    
    O->>S: Create Fulfillment
    S->>S: Calculate Rates
    S->>C: Create Shipment
    C-->>S: Shipment Created + Tracking Number
    S->>C: Generate Label
    C-->>S: Label PDF
    S->>O: Fulfillment Confirmed
    
    loop Tracking Updates
        C->>S: Webhook: Status Update
        S->>T: Update Tracking Events
        S->>N: Send Notification
        S->>O: Status Update Event
    end
    
    C->>S: Webhook: Delivered
    S->>O: Delivery Confirmed
```

## 📨 Event Schemas

### Published Events

#### FulfillmentCreated
**Topic**: `shipping.fulfillment.created`
**Version**: 1.0

```json
{
  "eventId": "evt_fulfillment_123",
  "eventType": "FulfillmentCreated",
  "version": "1.0",
  "timestamp": "2024-10-30T10:00:00Z",
  "source": "shipping-service",
  "data": {
    "fulfillmentId": "fulfillment_123",
    "orderId": "order_789",
    "warehouseId": "WH001",
    "customerId": "cust_456",
    "type": "standard",
    "status": "created",
    "estimatedDelivery": "2024-11-01T17:00:00Z",
    "createdAt": "2024-10-30T10:00:00Z"
  },
  "metadata": {
    "correlationId": "corr_order_789"
  }
}
```

#### FulfillmentStatusChanged
**Topic**: `shipping.fulfillment.status_changed`
**Version**: 1.0

#### ShipmentDelivered
**Topic**: `shipping.shipment.delivered`
**Version**: 1.0

#### TrackingUpdated
**Topic**: `shipping.tracking.updated`
**Version**: 1.0

### Subscribed Events

#### OrderConfirmed
**Topic**: `orders.order.confirmed`
**Source**: order-service

#### InventoryAllocated
**Topic**: `inventory.stock.allocated`
**Source**: warehouse-inventory-service

## 🔗 Service Dependencies

### Upstream Dependencies

#### Order Service
- **Purpose**: Get order details for fulfillment
- **Endpoints Used**: `/orders/{id}`
- **Fallback Strategy**: Cache order data, retry on failure
- **SLA Requirements**: < 200ms response time

#### Warehouse & Inventory Service
- **Purpose**: Validate inventory and get warehouse details
- **Endpoints Used**: `/warehouses/{id}`, `/inventory/allocate`
- **Fallback Strategy**: Use cached warehouse data

### External Dependencies

#### Carrier APIs (UPS, FedEx, DHL)
- **Purpose**: Create shipments, generate labels, track packages
- **Fallback Strategy**: Try alternative carriers, queue for retry
- **SLA Requirements**: < 5 seconds for rate calculation

## ⚙️ Configuration

### Environment Variables
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/shipping_db
DATABASE_MAX_CONNECTIONS=20

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_TTL_FULFILLMENT=1800
REDIS_TTL_TRACKING=300

# Carrier APIs
UPS_API_URL=https://api.ups.com
UPS_API_KEY=encrypted_key
FEDEX_API_URL=https://api.fedex.com
FEDEX_API_KEY=encrypted_key

# Service Discovery
CONSUL_URL=http://localhost:8500
SERVICE_NAME=shipping-service
SERVICE_PORT=8006

# Fulfillment Configuration
DEFAULT_CARRIER=ups
MAX_PACKAGE_WEIGHT=70
MAX_PACKAGE_DIMENSIONS=108
TRACKING_UPDATE_INTERVAL=300
```

## 🚨 Error Handling

### Error Codes
| Code | HTTP Status | Description | Retry Strategy |
|------|-------------|-------------|----------------|
| FULFILLMENT_NOT_FOUND | 404 | Fulfillment does not exist | No retry |
| INVALID_ADDRESS | 400 | Shipping address invalid | No retry |
| CARRIER_UNAVAILABLE | 503 | Carrier service unavailable | Retry with different carrier |
| RATE_CALCULATION_FAILED | 500 | Unable to calculate rates | Retry with backoff |
| LABEL_GENERATION_FAILED | 500 | Unable to generate label | Retry with backoff |
| TRACKING_UNAVAILABLE | 503 | Tracking service unavailable | Retry with backoff |

## ⚡ Performance & SLAs

### Performance Targets
- **Response Time**: 
  - P50: < 100ms
  - P95: < 500ms
  - P99: < 1000ms
- **Throughput**: 500 requests/second
- **Availability**: 99.9% uptime
- **Carrier API Timeout**: 5 seconds

### Scaling Strategy
- **Horizontal Scaling**: Auto-scale based on fulfillment volume
- **Database**: Read replicas for tracking queries
- **Cache**: Redis cluster for high availability
- **Carrier Failover**: Multiple carrier integration for redundancy

---

**Document Status**: Complete  
**Next Review Date**: November 30, 2024  
**Service Owner**: Shipping & Logistics Team
# Shipping Service - Logic Implementation Review

> **Service**: Shipping & Fulfillment Service  
> **Last Updated**: December 2024  
> **Status**: Documentation Complete (Implementation Pending)

---

## 📋 Overview

Shipping Service quản lý fulfillment và shipping operations, bao gồm carrier integration, shipping rate calculation, label generation, và delivery tracking. Service này orchestrate quá trình giao hàng từ warehouse đến customer.

---

## 🏗️ Architecture

### Service Structure (Planned)
```
shipping/
├── internal/
│   ├── biz/              # Business logic layer
│   │   ├── fulfillment.go
│   │   ├── shipment.go
│   │   ├── carrier.go
│   │   └── tracking.go
│   ├── service/          # gRPC/HTTP handlers
│   │   ├── shipping.go
│   │   └── webhook.go
│   └── data/             # Data access layer
```

### Key Dependencies
- **Order Service**: Receive order data for fulfillment
- **Warehouse Service**: Get warehouse information
- **Customer Service**: Get customer addresses
- **Carrier APIs**: UPS, FedEx, DHL, local carriers

---

## 🔄 Core Business Logic (Planned)

### 1. Fulfillment Creation Flow

#### CreateFulfillment Flow (Planned)
**Location**: `shipping/internal/biz/fulfillment.go` (to be implemented)

**Flow**:
1. **Receive Order Event**
   - Listen to `order.created` or `order.confirmed` event
   - Extract order details, items, shipping address
2. **Validate Order**
   - Verify order exists and is fulfillable
   - Check order status
3. **Validate Warehouse**
   - Get warehouse information
   - Verify warehouse can fulfill order
4. **Validate Address**
   - Validate shipping address
   - Standardize address format
5. **Calculate Package Dimensions**
   - Calculate total weight
   - Calculate package dimensions
   - Determine package count
6. **Get Shipping Rates**
   - Call RateCalculator with origin/destination
   - Get rates from multiple carriers
7. **Select Optimal Carrier**
   - Apply business rules (cost, speed, reliability)
   - Select best carrier and service
8. **Create Fulfillment Entity**
   - Status: "created"
   - Store fulfillment details
   - Link to order
9. **Publish FulfillmentCreated Event**
10. **Return Fulfillment**

**Planned Code Structure**:
```go
func (uc *FulfillmentUsecase) CreateFulfillment(ctx context.Context, req *CreateFulfillmentRequest) (*Fulfillment, error) {
    // 1. Validate order
    order, err := uc.orderClient.GetOrder(ctx, req.OrderID)
    
    // 2. Validate warehouse
    warehouse, err := uc.warehouseClient.GetWarehouse(ctx, req.WarehouseID)
    
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

---

### 2. Fulfillment Status Management

#### Fulfillment State Machine
**Statuses**:
- **created**: Fulfillment created, awaiting confirmation
- **confirmed**: Fulfillment confirmed, awaiting pickup
- **picked_up**: Carrier picked up package
- **in_transit**: Package in transit
- **out_for_delivery**: Package out for delivery
- **delivered**: Package delivered
- **failed**: Delivery failed
- **cancelled**: Fulfillment cancelled
- **returned**: Package returned to sender

**Valid Transitions**:
```
created → confirmed → picked_up → in_transit → out_for_delivery → delivered
created → cancelled
confirmed → cancelled
picked_up → failed
in_transit → failed
out_for_delivery → failed
failed → returned
delivered → returned (customer return)
```

---

### 3. Carrier Integration

#### Carrier Interface (Planned)
```go
type Carrier interface {
    CalculateRates(ctx context.Context, req *RateRequest) ([]*Rate, error)
    CreateShipment(ctx context.Context, req *CreateShipmentRequest) (*Shipment, error)
    GenerateLabel(ctx context.Context, shipmentID string) (*Label, error)
    TrackShipment(ctx context.Context, trackingNumber string) (*TrackingInfo, error)
    CancelShipment(ctx context.Context, shipmentID string) error
}
```

#### Supported Carriers (Planned)
- **UPS**: UPS Ground, UPS Air, UPS Express
- **FedEx**: FedEx Ground, FedEx Express, FedEx Overnight
- **DHL**: DHL Express, DHL eCommerce
- **Local Carriers**: Country-specific carriers

---

### 4. Shipping Rate Calculation

#### CalculateRates Flow (Planned)
**Flow**:
1. **Get Rates from All Carriers**
   - Call each carrier's rate API
   - Handle carrier-specific rate requests
2. **Apply Business Rules**
   - Filter by service type
   - Apply carrier preferences
   - Calculate total cost (rate + fees)
3. **Sort Rates**
   - By cost (cheapest first)
   - By delivery time (fastest first)
   - By reliability score
4. **Return Rates**

**Planned Code**:
```go
func (uc *RateCalculator) CalculateRates(ctx context.Context, req *RateRequest) ([]*Rate, error) {
    var allRates []*Rate
    
    // Get rates from all active carriers
    for _, carrier := range uc.activeCarriers {
        rates, err := carrier.CalculateRates(ctx, req)
        if err != nil {
            log.Warnf("Failed to get rates from %s: %v", carrier.ID(), err)
            continue
        }
        allRates = append(allRates, rates...)
    }
    
    // Apply business rules
    filteredRates := uc.applyBusinessRules(allRates, req.Preferences)
    
    // Sort rates
    sort.Slice(filteredRates, func(i, j int) bool {
        return filteredRates[i].TotalCost < filteredRates[j].TotalCost
    })
    
    return filteredRates, nil
}
```

---

### 5. Label Generation

#### GenerateLabel Flow (Planned)
**Flow**:
1. **Get Fulfillment**
   - Retrieve fulfillment details
2. **Call Carrier API**
   - Create shipment via carrier API
   - Get tracking number
   - Get label PDF
3. **Store Label**
   - Save label URL
   - Store tracking number
4. **Update Fulfillment**
   - Status: "confirmed"
   - TrackingNumber: from carrier
   - LabelURL: label PDF URL
5. **Publish Event**
   - FulfillmentConfirmed event

---

### 6. Tracking Management

#### TrackShipment Flow (Planned)
**Flow**:
1. **Get Tracking Number**
   - From fulfillment or shipment
2. **Call Carrier Tracking API**
   - Get tracking events
   - Get current status
3. **Update Fulfillment Status**
   - Map carrier status to fulfillment status
   - Update fulfillment record
4. **Store Tracking Events**
   - Save tracking history
5. **Publish Status Update Event**
   - FulfillmentStatusChanged event

---

### 7. Webhook Handling

#### ProcessWebhook Flow (Planned)
**Flow**:
1. **Receive Webhook**
   - From carrier API
2. **Validate Webhook**
   - Verify signature
   - Check idempotency
3. **Parse Webhook Data**
   - Extract tracking number
   - Extract status update
4. **Update Fulfillment**
   - Update status
   - Store tracking event
5. **Publish Events**
   - FulfillmentStatusChanged event
   - OrderStatusUpdate event (if delivered)

---

## 📊 Domain Models

### Fulfillment Entity
```go
type Fulfillment struct {
    ID                  string
    OrderID            string
    WarehouseID        string
    CustomerID         string
    Type               string        // "standard", "express", "same_day", "pickup"
    Status             string        // FulfillmentStatus
    Priority           int
    Items              []*FulfillmentItem
    OriginAddress      *Address
    DestinationAddress *Address
    CarrierID          string
    CarrierService     string
    TrackingNumber     string
    LabelURL           string
    TotalWeight        float64
    TotalDimensions    *Dimensions
    EstimatedPickup    *time.Time
    EstimatedDelivery  *time.Time
    ActualPickup       *time.Time
    ActualDelivery     *time.Time
    DeliveryInstructions string
    SignatureRequired  bool
    CreatedAt          time.Time
    UpdatedAt          time.Time
}
```

### Shipment Entity
```go
type Shipment struct {
    ID              string
    FulfillmentID   string
    CarrierID        string
    TrackingNumber  string
    Status          string
    LabelURL        string
    CreatedAt       time.Time
    UpdatedAt       time.Time
}
```

### Rate Entity
```go
type Rate struct {
    CarrierID        string
    Service          string
    ServiceName      string
    TotalCost        float64
    Currency         string
    EstimatedDays    int
    EstimatedDelivery *time.Time
    TransitTime      string
}
```

### TrackingEvent Entity
```go
type TrackingEvent struct {
    TrackingNumber  string
    Status          string
    Location        string
    Timestamp       time.Time
    Description     string
    CarrierData     map[string]interface{}
}
```

---

## 🔔 Events

### Published Events
- **FulfillmentCreated**: Fulfillment created
- **FulfillmentConfirmed**: Fulfillment confirmed, label generated
- **FulfillmentPickedUp**: Package picked up by carrier
- **FulfillmentInTransit**: Package in transit
- **FulfillmentOutForDelivery**: Package out for delivery
- **FulfillmentDelivered**: Package delivered
- **FulfillmentFailed**: Delivery failed
- **FulfillmentCancelled**: Fulfillment cancelled

### Consumed Events
- **OrderCreated**: Create fulfillment for new order
- **OrderConfirmed**: Confirm fulfillment can proceed
- **OrderCancelled**: Cancel fulfillment if not shipped

---

## 🔐 Business Rules

### Fulfillment Types
- **standard**: Standard shipping (5-7 business days)
- **express**: Express shipping (2-3 business days)
- **same_day**: Same-day delivery
- **pickup**: Customer pickup from warehouse/store
- **return**: Return shipment

### Carrier Selection
- **Cost Priority**: Select cheapest option
- **Speed Priority**: Select fastest option
- **Reliability Priority**: Select most reliable carrier
- **Business Rules**: Apply carrier preferences, restrictions

### Address Validation
- **Format Validation**: Validate address format
- **Country-Specific**: Apply country-specific validation
- **Postal Code**: Validate postal code format
- **Address Standardization**: Standardize address format

### Tracking Updates
- **Real-time**: Poll carrier APIs for updates
- **Webhooks**: Receive webhook updates from carriers
- **Status Mapping**: Map carrier status to fulfillment status

---

## 🔗 Service Integration

### Order Service
- **Consume**: OrderCreated, OrderConfirmed, OrderCancelled events
- **Publish**: FulfillmentStatusChanged events

### Warehouse Service
- **Get Warehouse**: Get warehouse address and details
- **Reserve Inventory**: Reserve items for fulfillment

### Customer Service
- **Get Address**: Get customer shipping address
- **Validate Address**: Validate address format

### Carrier APIs
- **UPS API**: UPS shipping services
- **FedEx API**: FedEx shipping services
- **DHL API**: DHL shipping services
- **Local Carriers**: Country-specific carrier APIs

---

## 🚨 Error Handling

### Common Errors
- **Fulfillment Not Found**: Fulfillment doesn't exist
- **Invalid Status Transition**: Invalid status change
- **Carrier API Error**: Carrier API returned error
- **Address Validation Failed**: Invalid shipping address
- **Rate Calculation Failed**: Failed to calculate rates

### Error Scenarios
1. **Carrier API Down**: Fallback to another carrier or retry
2. **Invalid Address**: Return error, request address correction
3. **Rate Calculation Failed**: Return error, allow manual selection
4. **Label Generation Failed**: Retry or use alternative method

---

## 📝 Implementation Status

### Completed
- ✅ Service documentation
- ✅ Database schema design
- ✅ API specification
- ✅ Event schema design

### Pending
- ❌ Business logic implementation
- ❌ Carrier integrations
- ❌ Rate calculation
- ❌ Label generation
- ❌ Tracking management
- ❌ Webhook handling

---

## 📚 Related Documentation

- [Shipping Service Implementation Checklist](./SHIPPING_IMPLEMENTATION_CHECKLIST.md)
- [Shipping Service API Docs](../docs/services/shipping-service.md)
- [Fulfillment Order Flow](../docs/api-flows/fulfillment-order-flow.md)
- [Order Service Logic](./ORDER_SERVICE_LOGIC.md)


# Fulfillment Service - Event Integration

> **Messaging:** Dapr Pub/Sub (Redis)  
> **Pattern:** Event-Driven Architecture  
> **Status:** 🔴 Not Implemented

---

## Event Flow Overview

```
Order Service → orders.order.confirmed
    ↓
Fulfillment Service (Subscribe)
    ↓
Create Fulfillment → fulfillment.created
    ↓
Start Planning → fulfillment.planned
    ↓
Generate Picklist → fulfillment.picklist_generated
    ↓
Warehouse Service (Subscribe) → Start Picking
    ↓
Confirm Picked → fulfillment.picked
    ↓
Start Packing → fulfillment.packing_started
    ↓
Confirm Packed → fulfillment.packed
    ↓
Ready to Ship → fulfillment.ready_to_ship
    ↓
Shipping Service (Subscribe) → Create Shipment
```

---

## Events Published by Fulfillment Service

### 1. fulfillment.created

**When:** Fulfillment record created from order

```json
{
  "event_type": "fulfillment.created",
  "event_id": "evt_123456",
  "timestamp": "2024-11-14T10:30:00Z",
  "data": {
    "fulfillment_id": "ful-uuid-123",
    "order_id": "order-uuid-456",
    "order_number": "ORD-2024-001234",
    "status": "pending",
    "items": [
      {
        "product_id": "prod-uuid-789",
        "product_sku": "SKU-001",
        "quantity": 2
      }
    ],
    "requires_cod_collection": false,
    "created_at": "2024-11-14T10:30:00Z"
  }
}
```

---

### 2. fulfillment.planned

**When:** Warehouse assigned and planning complete

```json
{
  "event_type": "fulfillment.planned",
  "event_id": "evt_123457",
  "timestamp": "2024-11-14T10:31:00Z",
  "data": {
    "fulfillment_id": "ful-uuid-123",
    "order_id": "order-uuid-456",
    "warehouse_id": "wh-uuid-001",
    "status": "planning",
    "planned_at": "2024-11-14T10:31:00Z"
  }
}
```

---

### 3. fulfillment.picklist_generated

**When:** Picklist created for warehouse staff

```json
{
  "event_type": "fulfillment.picklist_generated",
  "event_id": "evt_123458",
  "timestamp": "2024-11-14T10:32:00Z",
  "data": {
    "fulfillment_id": "ful-uuid-123",
    "picklist_id": "pick-uuid-001",
    "picklist_number": "PICK-2024-001234",
    "warehouse_id": "wh-uuid-001",
    "assigned_to": "picker-uuid-123",
    "total_items": 5,
    "items": [
      {
        "product_id": "prod-uuid-789",
        "product_sku": "SKU-001",
        "quantity": 2,
        "location": "A-12-34",
        "bin": "BIN-123"
      }
    ]
  }
}
```

---

### 4. fulfillment.picked

**When:** All items picked and confirmed

```json
{
  "event_type": "fulfillment.picked",
  "event_id": "evt_123459",
  "timestamp": "2024-11-14T11:00:00Z",
  "data": {
    "fulfillment_id": "ful-uuid-123",
    "picklist_id": "pick-uuid-001",
    "warehouse_id": "wh-uuid-001",
    "picked_by": "picker-uuid-123",
    "picked_at": "2024-11-14T11:00:00Z",
    "status": "picked",
    "items_picked": [
      {
        "product_id": "prod-uuid-789",
        "quantity_picked": 2
      }
    ]
  }
}
```

---

### 5. fulfillment.packed

**When:** Items packed into package

```json
{
  "event_type": "fulfillment.packed",
  "event_id": "evt_123460",
  "timestamp": "2024-11-14T11:30:00Z",
  "data": {
    "fulfillment_id": "ful-uuid-123",
    "package_id": "pkg-uuid-001",
    "package_number": "PKG-2024-001234",
    "warehouse_id": "wh-uuid-001",
    "packed_by": "packer-uuid-456",
    "packed_at": "2024-11-14T11:30:00Z",
    "status": "packed",
    "package_details": {
      "weight_kg": 2.5,
      "length_cm": 30,
      "width_cm": 20,
      "height_cm": 15
    }
  }
}
```

---

### 6. fulfillment.ready_to_ship

**When:** Package ready for carrier pickup

```json
{
  "event_type": "fulfillment.ready_to_ship",
  "event_id": "evt_123461",
  "timestamp": "2024-11-14T11:35:00Z",
  "data": {
    "fulfillment_id": "ful-uuid-123",
    "order_id": "order-uuid-456",
    "order_number": "ORD-2024-001234",
    "warehouse_id": "wh-uuid-001",
    "package_id": "pkg-uuid-001",
    "status": "ready",
    "ready_at": "2024-11-14T11:35:00Z",
    "requires_cod_collection": false,
    "cod_amount": null,
    "package_details": {
      "weight_kg": 2.5,
      "dimensions": "30x20x15"
    }
  }
}
```

---

### 7. fulfillment.cancelled

**When:** Fulfillment cancelled

```json
{
  "event_type": "fulfillment.cancelled",
  "event_id": "evt_123462",
  "timestamp": "2024-11-14T12:00:00Z",
  "data": {
    "fulfillment_id": "ful-uuid-123",
    "order_id": "order-uuid-456",
    "status": "cancelled",
    "cancelled_at": "2024-11-14T12:00:00Z",
    "reason": "Order cancelled by customer"
  }
}
```

---

## Events Subscribed by Fulfillment Service

### 1. orders.order.confirmed

**Action:** Create fulfillment and start planning

```go
// internal/service/event_handler.go

func (s *FulfillmentService) HandleOrderConfirmed(ctx context.Context, event *OrderConfirmedEvent) error {
    s.log.Infof("Received order.confirmed event: order_id=%s", event.OrderID)
    
    // Create fulfillment from order
    fulfillment, err := s.uc.CreateFromOrder(ctx, event.OrderID, event.OrderData)
    if err != nil {
        s.log.Errorf("Failed to create fulfillment: %v", err)
        return err
    }
    
    // Start planning
    if err := s.uc.StartPlanning(ctx, fulfillment.ID); err != nil {
        s.log.Errorf("Failed to start planning: %v", err)
        return err
    }
    
    return nil
}
```

---

### 2. orders.order.cancelled

**Action:** Cancel fulfillment if not yet shipped

```go
func (s *FulfillmentService) HandleOrderCancelled(ctx context.Context, event *OrderCancelledEvent) error {
    s.log.Infof("Received order.cancelled event: order_id=%s", event.OrderID)
    
    // Get fulfillment by order ID
    fulfillment, err := s.uc.GetByOrderID(ctx, event.OrderID)
    if err != nil {
        return err
    }
    
    // Cancel if not yet shipped
    if fulfillment.Status != "shipped" && fulfillment.Status != "completed" {
        return s.uc.CancelFulfillment(ctx, fulfillment.ID, event.Reason)
    }
    
    return nil
}
```

---

### 3. warehouse.inventory.picked

**Action:** Update fulfillment status to PICKED

```go
func (s *FulfillmentService) HandleInventoryPicked(ctx context.Context, event *InventoryPickedEvent) error {
    s.log.Infof("Received inventory.picked event: fulfillment_id=%s", event.FulfillmentID)
    
    // Confirm picked
    return s.uc.ConfirmPicked(ctx, event.FulfillmentID, event.PickedItems)
}
```

---

## Event Publisher Implementation

### internal/events/publisher.go

```go
package events

import (
    "context"
    "encoding/json"
    "time"
    
    dapr "github.com/dapr/go-sdk/client"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/google/uuid"
)

type EventPublisher struct {
    daprClient dapr.Client
    pubsubName string
    log        *log.Helper
}

func NewEventPublisher(daprClient dapr.Client, pubsubName string, logger log.Logger) *EventPublisher {
    return &EventPublisher{
        daprClient: daprClient,
        pubsubName: pubsubName,
        log:        log.NewHelper(logger),
    }
}

func (p *EventPublisher) PublishFulfillmentCreated(ctx context.Context, f *Fulfillment) error {
    event := Event{
        EventType: "fulfillment.created",
        EventID:   uuid.New().String(),
        Timestamp: time.Now(),
        Data: map[string]interface{}{
            "fulfillment_id": f.ID,
            "order_id":       f.OrderID,
            "order_number":   f.OrderNumber,
            "status":         f.Status,
            "items":          f.Items,
            "created_at":     f.CreatedAt,
        },
    }
    
    return p.publish(ctx, "fulfillment.created", event)
}

func (p *EventPublisher) PublishFulfillmentPlanned(ctx context.Context, f *Fulfillment) error {
    event := Event{
        EventType: "fulfillment.planned",
        EventID:   uuid.New().String(),
        Timestamp: time.Now(),
        Data: map[string]interface{}{
            "fulfillment_id": f.ID,
            "order_id":       f.OrderID,
            "warehouse_id":   f.WarehouseID,
            "status":         f.Status,
            "planned_at":     f.PlannedAt,
        },
    }
    
    return p.publish(ctx, "fulfillment.planned", event)
}

func (p *EventPublisher) PublishFulfillmentReadyToShip(ctx context.Context, f *Fulfillment) error {
    event := Event{
        EventType: "fulfillment.ready_to_ship",
        EventID:   uuid.New().String(),
        Timestamp: time.Now(),
        Data: map[string]interface{}{
            "fulfillment_id":          f.ID,
            "order_id":                f.OrderID,
            "order_number":            f.OrderNumber,
            "warehouse_id":            f.WarehouseID,
            "package_id":              f.PackageID,
            "status":                  f.Status,
            "ready_at":                f.ReadyAt,
            "requires_cod_collection": f.RequiresCODCollection,
            "cod_amount":              f.CODAmount,
        },
    }
    
    return p.publish(ctx, "fulfillment.ready_to_ship", event)
}

func (p *EventPublisher) publish(ctx context.Context, topic string, event Event) error {
    data, err := json.Marshal(event)
    if err != nil {
        p.log.Errorf("Failed to marshal event: %v", err)
        return err
    }
    
    if err := p.daprClient.PublishEvent(ctx, p.pubsubName, topic, data); err != nil {
        p.log.Errorf("Failed to publish event to topic %s: %v", topic, err)
        return err
    }
    
    p.log.Infof("Published event: topic=%s, event_id=%s", topic, event.EventID)
    return nil
}
```

---

## Dapr Configuration

### configs/config.yaml

```yaml
dapr:
  app_id: fulfillment-service
  app_port: 8010
  pubsub_name: pubsub
  
  # Subscriptions
  subscriptions:
    - topic: orders.order.confirmed
      route: /events/order-confirmed
      metadata:
        rawPayload: "true"
    
    - topic: orders.order.cancelled
      route: /events/order-cancelled
      metadata:
        rawPayload: "true"
    
    - topic: warehouse.inventory.picked
      route: /events/inventory-picked
      metadata:
        rawPayload: "true"
```

---

## Event Handler Routes

### internal/server/http.go

```go
// Register event handler routes
func registerEventHandlers(r *http.ServeMux, svc *service.FulfillmentService) {
    r.HandleFunc("/events/order-confirmed", func(w http.ResponseWriter, r *http.Request) {
        var event OrderConfirmedEvent
        if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
            http.Error(w, err.Error(), http.StatusBadRequest)
            return
        }
        
        if err := svc.HandleOrderConfirmed(r.Context(), &event); err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        
        w.WriteHeader(http.StatusOK)
    })
    
    // More handlers...
}
```

---

## Summary

**Events Published:** 7 events
- fulfillment.created
- fulfillment.planned
- fulfillment.picklist_generated
- fulfillment.picked
- fulfillment.packed
- fulfillment.ready_to_ship
- fulfillment.cancelled

**Events Subscribed:** 3 events
- orders.order.confirmed
- orders.order.cancelled
- warehouse.inventory.picked

**Integration:** Dapr Pub/Sub with Redis

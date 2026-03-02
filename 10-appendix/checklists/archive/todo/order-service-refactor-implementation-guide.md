# Order Service Refactor Implementation Guide

## Overview
This guide provides detailed implementation steps for refactoring Order Service to eliminate Single Responsibility Principle (SRP) violations and implement proper event-driven architecture.

## Current Architecture Issues

### Critical Violations Identified
1. **9 External Service Dependencies** injected into Order UseCase
2. **Direct Stock Management** with complex retry logic
3. **Payment Processing** within order domain
4. **Pricing Calculations** in order operations
5. **Promotion Validation** in order editing
6. **Synchronous Notification** sending

## Implementation Roadmap

### Phase 1: Event-Driven Notifications (2 weeks)

#### Step 1.1: Define Notification Events
```go
// File: order/internal/events/notification_events.go
package events

import "time"

type OrderNotificationEvent struct {
    EventType   string                 `json:"event_type"`
    OrderID     string                 `json:"order_id"`
    CustomerID  string                 `json:"customer_id"`
    NotificationType string            `json:"notification_type"` // "order.cancelled", "order.created", etc.
    Timestamp   time.Time              `json:"timestamp"`
    Metadata    map[string]interface{} `json:"metadata"`
}
```

#### Step 1.2: Replace Direct Notification Calls
```go
// BEFORE (order/internal/biz/cancellation/cancellation.go:50-70)
if uc.notificationService != nil {
    if err := uc.notificationService.SendOrderNotification(ctx, input.OrderID, "order.cancelled"); err != nil {
        uc.log.WithContext(ctx).Warnf("Failed to send order cancelled notification: %v", err)
    }
}

// AFTER
event := &events.OrderNotificationEvent{
    EventType:        "order.notification.requested",
    OrderID:          input.OrderID,
    CustomerID:       order.CustomerID,
    NotificationType: "order.cancelled",
    Timestamp:        time.Now(),
    Metadata: map[string]interface{}{
        "reason": input.Reason,
        "cancelled_by": input.CancelledBy,
    },
}
if err := uc.eventPublisher.Publish(ctx, constants.TopicOrderNotificationRequested, event); err != nil {
    uc.log.WithContext(ctx).Warnf("Failed to publish notification event: %v", err)
}
```

#### Step 1.3: Remove NotificationService Dependency
```go
// File: order/internal/biz/order/usecase.go
// REMOVE this field:
// notificationService       NotificationService

// File: order/internal/biz/cancellation/cancellation.go
// REMOVE this field:
// notificationService       biz.NotificationService
```

#### Step 1.4: Update Constants
```go
// File: order/internal/constants/events.go
const (
    // Existing constants...
    TopicOrderNotificationRequested = "order.notification.requested"
)
```

### Phase 2: Stock Management Saga (4 weeks)

#### Step 2.1: Define Stock Events
```go
// File: order/internal/events/stock_events.go
package events

type StockReservationRequestedEvent struct {
    EventType     string    `json:"event_type"`
    OrderID       string    `json:"order_id"`
    CustomerID    string    `json:"customer_id"`
    Items         []StockReservationItem `json:"items"`
    ExpiresAt     *time.Time `json:"expires_at"`
    Timestamp     time.Time  `json:"timestamp"`
}

type StockReservationItem struct {
    ProductID   string `json:"product_id"`
    ProductSKU  string `json:"product_sku"`
    Quantity    int32  `json:"quantity"`
    WarehouseID string `json:"warehouse_id"`
}

type StockReservedEvent struct {
    EventType     string                    `json:"event_type"`
    OrderID       string                    `json:"order_id"`
    Reservations  []StockReservationResult  `json:"reservations"`
    Timestamp     time.Time                 `json:"timestamp"`
}

type StockReservationResult struct {
    ProductID     string `json:"product_id"`
    WarehouseID   string `json:"warehouse_id"`
    ReservationID string `json:"reservation_id"`
    Quantity      int32  `json:"quantity"`
}

type StockReservationFailedEvent struct {
    EventType string    `json:"event_type"`
    OrderID   string    `json:"order_id"`
    Reason    string    `json:"reason"`
    Items     []StockReservationItem `json:"failed_items"`
    Timestamp time.Time `json:"timestamp"`
}
```

#### Step 2.2: Refactor Order Creation
```go
// File: order/internal/biz/order/create.go
// REMOVE reservation logic from CreateOrder method

// REPLACE reservation calls with event publishing:
func (uc *UseCase) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    // ... existing validation and order creation logic ...

    // Create order in database first (without reservations)
    var createdOrder *Order
    err := uc.tm.WithTransaction(ctx, func(ctx context.Context) error {
        var err error
        createdOrder, err = uc.createOrderInternal(ctx, order)
        if err != nil {
            return fmt.Errorf("failed to create order: %w", err)
        }

        // Publish stock reservation request event
        stockItems := make([]StockReservationItem, len(req.Items))
        for i, item := range req.Items {
            if item.WarehouseID == nil {
                return fmt.Errorf("warehouse ID required for product %s", item.ProductID)
            }
            stockItems[i] = StockReservationItem{
                ProductID:   item.ProductID,
                ProductSKU:  item.ProductSKU,
                Quantity:    item.Quantity,
                WarehouseID: *item.WarehouseID,
            }
        }

        stockEvent := &events.StockReservationRequestedEvent{
            EventType:  "stock.reservation.requested",
            OrderID:    createdOrder.ID,
            CustomerID: createdOrder.CustomerID,
            Items:      stockItems,
            ExpiresAt:  createdOrder.ExpiresAt,
            Timestamp:  time.Now(),
        }

        // Save to outbox for reliable delivery
        outboxEvent := &biz.OutboxEvent{
            Topic:   constants.TopicStockReservationRequested,
            Payload: convertEventToMap(stockEvent),
        }
        if err := uc.outboxRepo.Save(ctx, outboxEvent); err != nil {
            return fmt.Errorf("failed to save stock reservation event: %w", err)
        }

        return nil
    })

    // ... rest of the method ...
}
```

#### Step 2.3: Implement Stock Event Handlers
```go
// File: order/internal/service/stock_event_handler.go
package service

func (h *EventHandler) HandleStockReserved(w http.ResponseWriter, r *http.Request) {
    var event events.StockReservedEvent
    if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
        h.log.Errorf("Failed to decode stock reserved event: %v", err)
        w.WriteHeader(http.StatusBadRequest)
        return
    }

    // Update order items with reservation IDs
    ctx := r.Context()
    for _, reservation := range event.Reservations {
        if err := h.orderUc.UpdateItemReservation(ctx, event.OrderID, reservation.ProductID, reservation.ReservationID); err != nil {
            h.log.Errorf("Failed to update item reservation: %v", err)
            // Continue processing other reservations
        }
    }

    // Update order status to confirmed if all items have reservations
    if err := h.orderUc.CheckAndConfirmOrder(ctx, event.OrderID); err != nil {
        h.log.Errorf("Failed to confirm order: %v", err)
    }

    w.WriteHeader(http.StatusOK)
}

func (h *EventHandler) HandleStockReservationFailed(w http.ResponseWriter, r *http.Request) {
    var event events.StockReservationFailedEvent
    if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
        h.log.Errorf("Failed to decode stock reservation failed event: %v", err)
        w.WriteHeader(http.StatusBadRequest)
        return
    }

    // Cancel order due to insufficient stock
    ctx := r.Context()
    cancelInput := &cancellation.CancelInput{
        OrderID:     event.OrderID,
        Reason:      "insufficient_stock",
        Notes:       fmt.Sprintf("Stock reservation failed: %s", event.Reason),
        CancelledBy: "system",
    }

    if _, err := h.cancellationUc.CancelOrder(ctx, cancelInput); err != nil {
        h.log.Errorf("Failed to cancel order due to stock reservation failure: %v", err)
    }

    w.WriteHeader(http.StatusOK)
}
```

#### Step 2.4: Remove Warehouse Dependencies
```go
// File: order/internal/biz/order/usecase.go
// REMOVE these fields:
// warehouseInventoryService WarehouseInventoryService
// warehouseClient           WarehouseClient

// File: order/internal/biz/cancellation/cancellation.go
// REMOVE this field:
// warehouseInventoryService biz.WarehouseInventoryService

// REMOVE the entire reservation.go file:
// order/internal/biz/order/reservation.go
```

### Phase 3: Payment Domain Separation (4 weeks)

#### Step 3.1: Define Payment Events
```go
// File: order/internal/events/payment_events.go
package events

type PaymentRequiredEvent struct {
    EventType     string                 `json:"event_type"`
    OrderID       string                 `json:"order_id"`
    CustomerID    string                 `json:"customer_id"`
    Amount        float64                `json:"amount"`
    Currency      string                 `json:"currency"`
    PaymentMethod string                 `json:"payment_method"`
    Metadata      map[string]interface{} `json:"metadata"`
    Timestamp     time.Time              `json:"timestamp"`
}

type RefundRequestedEvent struct {
    EventType string                 `json:"event_type"`
    OrderID   string                 `json:"order_id"`
    PaymentID string                 `json:"payment_id"`
    Amount    float64                `json:"amount"`
    Reason    string                 `json:"reason"`
    Metadata  map[string]interface{} `json:"metadata"`
    Timestamp time.Time              `json:"timestamp"`
}
```

#### Step 3.2: Refactor Payment Operations
```go
// File: order/internal/biz/cancellation/cancellation.go
// REPLACE InitiateRefund method:

func (uc *CancellationUsecase) InitiateRefund(ctx context.Context, orderID string) error {
    // Get order payments
    payments, err := uc.orderPaymentRepo.FindByOrderID(ctx, orderID)
    if err != nil {
        return fmt.Errorf("failed to get payments for order %s: %w", orderID, err)
    }

    // Find refundable payments and publish refund events
    for _, payment := range payments {
        if payment.Status == "completed" || payment.Status == "captured" {
            refundEvent := &events.RefundRequestedEvent{
                EventType: "payment.refund.requested",
                OrderID:   orderID,
                PaymentID: payment.PaymentID,
                Amount:    payment.Amount,
                Reason:    "order_cancelled",
                Metadata: map[string]interface{}{
                    "cancellation_reason": "customer_request",
                },
                Timestamp: time.Now(),
            }

            // Publish via outbox pattern
            outboxEvent := &biz.OutboxEvent{
                Topic:   constants.TopicRefundRequested,
                Payload: convertEventToMap(refundEvent),
            }
            if err := uc.outboxRepo.Save(ctx, outboxEvent); err != nil {
                uc.log.WithContext(ctx).Errorf("Failed to save refund event for payment %s: %v", payment.PaymentID, err)
                continue
            }

            uc.log.WithContext(ctx).Infof("Refund requested for payment %s", payment.PaymentID)
        }
    }

    return nil
}
```

#### Step 3.3: Remove Payment Dependencies
```go
// File: order/internal/biz/order/usecase.go
// REMOVE this field:
// paymentService            PaymentService

// File: order/internal/biz/cancellation/cancellation.go
// REMOVE this field:
// paymentService            biz.PaymentService

// File: order/internal/biz/order_edit/order_edit.go
// REMOVE this field:
// paymentService   biz.PaymentService

// REMOVE the updatePaymentAuthorization method entirely
```

### Phase 4: Pricing/Promotion Decoupling (6 weeks)

#### Step 4.1: Remove Pricing Logic
```go
// File: order/internal/biz/order/create.go
// REMOVE enrichItemsWithPricing call:
// enrichedItems, enrichErr := uc.enrichItemsWithPricing(ctx, req.Items)

// Use items directly from request (pre-calculated by Checkout Service):
order := &Order{
    CustomerID:      req.CustomerID,
    CartSessionID:   req.CartSessionID,
    Items:           convertCreateOrderItemsToOrderItems(req.Items), // Direct conversion
    // ... rest of fields
}
```

#### Step 4.2: Remove Pricing Dependencies
```go
// File: order/internal/biz/order/usecase.go
// REMOVE this field:
// productService            ProductService

// File: order/internal/biz/order_edit/order_edit.go
// REMOVE these fields:
// productService   biz.ProductService
// pricingService   biz.PricingService
// promotionService biz.PromotionService

// DELETE entire file:
// order/internal/biz/order/pricing_enrichment.go
```

#### Step 4.3: Restrict Order Editing
```go
// File: order/internal/biz/order_edit/order_edit.go
// REPLACE UpdateOrder method to only allow simple updates:

func (uc *OrderEditUsecase) UpdateOrder(ctx context.Context, req *UpdateOrderRequest) (*model.Order, error) {
    // Get current order
    order, err := uc.orderRepo.FindByID(ctx, req.OrderID)
    if err != nil {
        return nil, fmt.Errorf("failed to get order: %w", err)
    }
    if order == nil {
        return nil, ErrOrderNotFound
    }

    // Validate order can be edited (only pending)
    if order.Status != "pending" {
        return nil, fmt.Errorf("%w: order status is %s", ErrOrderCannotBeEdited, order.Status)
    }

    // Only allow simple field updates
    changes := []*model.OrderEditHistory{}

    // Update shipping address if provided
    if req.ShippingAddress != nil {
        change, err := uc.updateShippingAddress(ctx, order, req.ShippingAddress, req.ChangedBy, req.ChangedByType)
        if err != nil {
            return nil, fmt.Errorf("failed to update shipping address: %w", err)
        }
        if change != nil {
            changes = append(changes, change)
        }
    }

    // Update billing address if provided
    if req.BillingAddress != nil {
        change, err := uc.updateBillingAddress(ctx, order, req.BillingAddress, req.ChangedBy, req.ChangedByType)
        if err != nil {
            return nil, fmt.Errorf("failed to update billing address: %w", err)
        }
        if change != nil {
            changes = append(changes, change)
        }
    }

    // Update notes if provided
    if req.Notes != nil {
        change, err := uc.updateNotes(ctx, order, *req.Notes, req.ChangedBy, req.ChangedByType)
        if err != nil {
            return nil, fmt.Errorf("failed to update notes: %w", err)
        }
        if change != nil {
            changes = append(changes, change)
        }
    }

    // REMOVE: Item updates, payment method updates, promo code updates
    // These should be handled by Checkout Service with new order creation

    // Save order
    if err := uc.orderRepo.Save(ctx, order); err != nil {
        return nil, fmt.Errorf("failed to save order: %w", err)
    }

    // Save edit history
    for _, change := range changes {
        if _, err := uc.editHistoryRepo.Create(ctx, change); err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to save edit history: %v", err)
        }
    }

    return order, nil
}
```

### Phase 5: Clean Architecture (2 weeks)

#### Step 5.1: Final UseCase Structure
```go
// File: order/internal/biz/order/usecase.go
package order

import (
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/order/internal/events"
    "gitlab.com/ta-microservices/order/internal/biz"
)

// UseCase handles order domain operations (Clean Architecture)
type UseCase struct {
    orderRepo                 OrderRepo
    orderItemRepo             OrderItemRepo
    orderAddressRepo          OrderAddressRepo
    orderStatusHistoryRepo    OrderStatusHistoryRepo
    orderPaymentRepo          OrderPaymentRepo
    eventPublisher            events.EventPublisher
    tm                        biz.TransactionManager
    outboxRepo                biz.OutboxRepo
    log                       *log.Helper
}

// NewUseCase creates a new order use case
func NewUseCase(
    orderRepo OrderRepo,
    orderItemRepo OrderItemRepo,
    orderAddressRepo OrderAddressRepo,
    orderStatusHistoryRepo OrderStatusHistoryRepo,
    orderPaymentRepo OrderPaymentRepo,
    eventPublisher events.EventPublisher,
    tm biz.TransactionManager,
    outboxRepo biz.OutboxRepo,
    logger log.Logger,
) *UseCase {
    return &UseCase{
        orderRepo:                 orderRepo,
        orderItemRepo:             orderItemRepo,
        orderAddressRepo:          orderAddressRepo,
        orderStatusHistoryRepo:    orderStatusHistoryRepo,
        orderPaymentRepo:          orderPaymentRepo,
        eventPublisher:            eventPublisher,
        tm:                        tm,
        outboxRepo:                outboxRepo,
        log:                       log.NewHelper(logger),
    }
}
```

#### Step 5.2: Remove Client Adapters
```go
// DELETE these files:
// order/internal/data/client_adapters.go
// order/internal/client/provider.go (external service clients)

// UPDATE order/internal/data/data.go ProviderSet:
var ProviderSet = wire.NewSet(
    NewData,
    NewDB,
    NewRedis,
    postgresRepo.NewOrderRepo,
    postgresRepo.NewOrderItemRepo,
    postgresRepo.NewOrderAddressRepo,
    postgresRepo.NewOrderStatusHistoryRepo,
    postgresRepo.NewOrderPaymentRepo,
    postgresRepo.NewEventIdempotencyRepo,
    postgresRepo.NewFailedEventRepo,
    postgresRepo.NewOutboxRepo,
    postgresRepo.NewFailedCompensationRepo,
    postgresRepo.NewOrderEditHistoryRepo,
    // REMOVE all client and adapter providers
    eventbus.ProviderSet,
    events.ProviderSet,
    NewTransactionManagerAdapter,
)
```

## Event Schema Documentation

### Complete Event Contracts
```go
// File: order/internal/events/schemas.go
package events

// Events Published by Order Service
const (
    EventTypeOrderCreated           = "order.created"
    EventTypeOrderStatusChanged     = "order.status.changed"
    EventTypeOrderCancelled         = "order.cancelled"
    EventTypeOrderCompleted         = "order.completed"
    EventTypeStockReservationRequested = "stock.reservation.requested"
    EventTypeRefundRequested        = "payment.refund.requested"
    EventTypeNotificationRequested  = "order.notification.requested"
)

// Events Consumed by Order Service
const (
    EventTypeStockReserved          = "stock.reserved"
    EventTypeStockReservationFailed = "stock.reservation.failed"
    EventTypePaymentAuthorized      = "payment.authorized"
    EventTypePaymentFailed          = "payment.failed"
    EventTypeRefundCompleted        = "payment.refund.completed"
)
```

## Migration Strategy

### Step-by-Step Migration
1. **Feature Flags**: Implement feature flags for each phase
2. **Parallel Implementation**: Run old and new flows in parallel
3. **Gradual Rollout**: Start with 10% traffic, increase gradually
4. **Monitoring**: Extensive metrics and alerting
5. **Rollback Plan**: Ability to revert to synchronous calls

### Testing Strategy
1. **Unit Tests**: Mock event publishers and repositories
2. **Integration Tests**: Test event flows end-to-end
3. **Load Tests**: Verify performance with async processing
4. **Chaos Engineering**: Test failure scenarios

### Monitoring and Observability
```go
// Add these metrics:
order_external_dependencies_removed_total
order_event_published_total{event_type}
order_event_processing_duration{event_type}
order_saga_completion_rate
order_compensation_triggered_total{reason}
```

## Benefits After Refactor

1. **Loose Coupling**: Order Service independent of external service availability
2. **Fault Tolerance**: Failures don't cascade across services
3. **Scalability**: Each service scales independently
4. **Maintainability**: Clear domain boundaries
5. **Testability**: Easy to unit test with event mocking
6. **Performance**: Async processing, non-blocking operations

This refactor transforms Order Service from a tightly-coupled orchestrator into a focused domain service that follows Single Responsibility Principle and event-driven architecture best practices.
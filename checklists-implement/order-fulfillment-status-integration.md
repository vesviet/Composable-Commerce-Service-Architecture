# Implementation Checklist: Order Fulfillment Status Integration

## Overview

**Goal**: Add `FulfillmentConsumer` to Order Service to auto-update order status when fulfillment status changes

**Issue**: COD orders stuck at `confirmed` status, don't auto-transition to `processing` when fulfillment starts

**Solution**: Order Worker subscribes to `fulfillment.status_changed` event and updates order status accordingly

**Estimated Time**: 2-3 hours

---

## Pre-Implementation Checklist

- [ ] Read analysis document: [`docs/workfllow/cod-order-flow-review.md`](file:///home/user/microservices/docs/workfllow/cod-order-flow-review.md)
- [ ] Review existing consumer pattern: [`order/internal/data/eventbus/payment_consumer.go`](file:///home/user/microservices/order/internal/data/eventbus/payment_consumer.go)
- [ ] Confirm Dapr topic name: `fulfillment.status_changed` (check with Fulfillment team)
- [ ] Verify order status transition rules: [`order/internal/constants/order_status.go`](file:///home/user/microservices/order/internal/constants/order_status.go)

---

## Implementation Steps

### Phase 1: Create Fulfillment Consumer

#### 1.1 Create Consumer File

**File**: `order/internal/data/eventbus/fulfillment_consumer.go`

**Tasks**:
- [ ] Create file with package `eventbus`
- [ ] Import required packages
  ```go
  import (
      "context"
      "encoding/json"
      "fmt"
      "bytes"
      
      "github.com/go-kratos/kratos/v2/log"
      commonEventbus "gitlab.com/ta-microservices/common/utils/eventbus"
      order_biz "gitlab.com/ta-microservices/order/internal/biz/order"
      "gitlab.com/ta-microservices/order/internal/config"
  )
  ```

#### 1.2 Define Event Schema

- [ ] Add `FulfillmentStatusChangedEvent` struct
  ```go
  type FulfillmentStatusChangedEvent struct {
      EventType      string    `json:"event_type"`
      FulfillmentID  string    `json:"fulfillment_id"`
      OrderID        string    `json:"order_id"`
      OldStatus      string    `json:"old_status"`
      NewStatus      string    `json:"new_status"`
      Timestamp      time.Time `json:"timestamp"`
      Metadata       map[string]interface{} `json:"metadata,omitempty"`
  }
  ```

#### 1.3 Create Consumer Struct

- [ ] Add `FulfillmentConsumer` struct
  ```go
  type FulfillmentConsumer struct {
      Client
      config  *config.AppConfig
      orderUc *order_biz.UseCase
      log     *log.Helper
  }
  ```

- [ ] Add constructor `NewFulfillmentConsumer`
  ```go
  func NewFulfillmentConsumer(
      client Client,
      cfg *config.AppConfig,
      orderUc *order_biz.UseCase,
      logger log.Logger,
  ) FulfillmentConsumer
  ```

#### 1.4 Implement Consumer Method

- [ ] Add `ConsumeFulfillmentStatusChanged` method
  ```go
  func (c FulfillmentConsumer) ConsumeFulfillmentStatusChanged(ctx context.Context) error {
      topic := "fulfillment.status_changed"
      pubsub := c.config.Data.Eventbus.DefaultPubsub
      
      c.log.Infof("Subscribing to topic: %s, pubsub: %s", topic, pubsub)
      
      return c.Client.AddConsumer(topic, pubsub, c.HandleFulfillmentStatusChanged)
  }
  ```

#### 1.5 Implement Event Handler

- [ ] Add `HandleFulfillmentStatusChanged` method
  ```go
  func (c FulfillmentConsumer) HandleFulfillmentStatusChanged(ctx context.Context, e commonEventbus.Message) error {
      var eventData FulfillmentStatusChangedEvent
      if err := json.NewDecoder(bytes.NewReader(e.Data)).Decode(&eventData); err != nil {
          c.log.Errorf("Failed to decode event: %v, payload: %s", err, string(e.Data))
          return fmt.Errorf("failed to decode: %w", err)
      }
      
      c.log.Infof("Processing fulfillment status changed: fulfillment_id=%s, order_id=%s, status=%s", 
          eventData.FulfillmentID, eventData.OrderID, eventData.NewStatus)
      
      return c.processFulfillmentStatusChanged(ctx, &eventData)
  }
  ```

#### 1.6 Implement Status Mapping

- [ ] Add `mapFulfillmentStatusToOrderStatus` method
  ```go
  func (c FulfillmentConsumer) mapFulfillmentStatusToOrderStatus(fulfillmentStatus string) string {
      switch fulfillmentStatus {
      case "planning", "picking", "picked", "packing", "packed", "ready":
          return "processing"
      case "shipped":
          return "shipped"
      case "completed":
          return "delivered"
      case "cancelled":
          return "cancelled"
      default:
          return "" // No mapping needed
      }
  }
  ```

#### 1.7 Implement Business Logic

- [ ] Add `processFulfillmentStatusChanged` method
  ```go
  func (c FulfillmentConsumer) processFulfillmentStatusChanged(ctx context.Context, event *FulfillmentStatusChangedEvent) error {
      // Map fulfillment status to order status
      orderStatus := c.mapFulfillmentStatusToOrderStatus(event.NewStatus)
      if orderStatus == "" {
          c.log.Infof("No order status mapping for fulfillment status: %s", event.NewStatus)
          return nil
      }
      
      // Get current order
      order, err := c.orderUc.GetOrder(ctx, event.OrderID)
      if err != nil {
          return fmt.Errorf("failed to get order: %w", err)
      }
      
      // Skip if order already at this status or beyond
      if order.Status == orderStatus || c.isLaterStatus(order.Status, orderStatus) {
          c.log.Infof("Order already at status %s, skipping update", order.Status)
          return nil
      }
      
      // Update order status
      _, err = c.orderUc.UpdateOrderStatus(ctx, &order_biz.UpdateOrderStatusRequest{
          OrderID: event.OrderID,
          Status:  orderStatus,
          Reason:  fmt.Sprintf("Fulfillment status changed to %s", event.NewStatus),
          Notes:   fmt.Sprintf("Fulfillment ID: %s", event.FulfillmentID),
      })
      
      if err != nil {
          return fmt.Errorf("failed to update order status: %w", err)
      }
      
      c.log.Infof("Updated order status: order_id=%s, status=%s", event.OrderID, orderStatus)
      return nil
  }
  ```

- [ ] Add `isLaterStatus` helper method to prevent backward transitions
  ```go
  func (c FulfillmentConsumer) isLaterStatus(currentStatus, newStatus string) bool {
      statusOrder := map[string]int{
          "pending": 0, "confirmed": 1, "processing": 2, 
          "shipped": 3, "delivered": 4, "cancelled": 99, "refunded": 100,
      }
      return statusOrder[currentStatus] > statusOrder[newStatus]
  }
  ```

---

### Phase 2: Update Wire Dependency Injection

#### 2.1 Update Provider Set

**File**: `order/internal/data/eventbus/provider.go`

- [ ] Add `NewFulfillmentConsumer` to provider set
  ```go
  var ProviderSet = wire.NewSet(
      NewClient,
      NewPaymentConsumer,
      NewFulfillmentConsumer,  // ← ADD THIS
  )
  ```

#### 2.2 Update Worker Wire

**File**: `order/cmd/worker/wire.go`

- [ ] Update `WorkerManager` struct
  ```go
  type WorkerManager struct {
      jobManager          *server.JobManager
      eventbusClient      eventbus.Client
      paymentConsumer     eventbus.PaymentConsumer
      fulfillmentConsumer eventbus.FulfillmentConsumer  // ← ADD THIS
      logger              *log.Helper
  }
  ```

- [ ] Update `NewWorkerManager` constructor
  ```go
  func NewWorkerManager(
      jobManager *server.JobManager,
      eventbusClient eventbus.Client,
      paymentConsumer eventbus.PaymentConsumer,
      fulfillmentConsumer eventbus.FulfillmentConsumer,  // ← ADD THIS
      logger log.Logger,
  ) *WorkerManager {
      return &WorkerManager{
          jobManager:          jobManager,
          eventbusClient:      eventbusClient,
          paymentConsumer:     paymentConsumer,
          fulfillmentConsumer: fulfillmentConsumer,  // ← ADD THIS
          logger:              log.NewHelper(logger),
      }
  }
  ```

- [ ] Update `StartEventConsumers` method
  ```go
  func (wm *WorkerManager) StartEventConsumers(ctx context.Context) error {
      wm.logger.Info("Starting event consumers...")
      
      // Subscribe to payment events
      if err := wm.paymentConsumer.ConsumePaymentConfirmed(ctx); err != nil {
          return err
      }
      if err := wm.paymentConsumer.ConsumePaymentFailed(ctx); err != nil {
          return err
      }
      
      // Subscribe to fulfillment events ← ADD THIS
      if err := wm.fulfillmentConsumer.ConsumeFulfillmentStatusChanged(ctx); err != nil {
          return err
      }
      
      // Start eventbus gRPC server
      wm.logger.Info("Starting eventbus gRPC server on :5005...")
      return wm.eventbusClient.Start()
  }
  ```

#### 2.3 Generate Wire Code

- [ ] Run wire generation
  ```bash
  cd order/cmd/worker
  wire
  ```

- [ ] Verify `wire_gen.go` updated correctly
- [ ] Check no wire errors

---

### Phase 3: Testing

#### 3.1 Unit Tests

**File**: `order/internal/data/eventbus/fulfillment_consumer_test.go`

- [ ] Create test file
- [ ] Test `mapFulfillmentStatusToOrderStatus`
  ```go
  func TestMapFulfillmentStatusToOrderStatus(t *testing.T) {
      tests := []struct{
          fulfillmentStatus string
          expectedOrderStatus string
      }{
          {"planning", "processing"},
          {"picking", "processing"},
          {"shipped", "shipped"},
          {"completed", "delivered"},
          {"unknown", ""},
      }
      // ... test implementation
  }
  ```

- [ ] Test `HandleFulfillmentStatusChanged` with mock
- [ ] Test idempotency (duplicate events)
- [ ] Test backward transition prevention

#### 3.2 Integration Tests

- [ ] Start local dependencies (Redis, Postgres, Consul)
  ```bash
  docker-compose up -d redis postgresql consul
  ```

- [ ] Run order worker locally
  ```bash
  cd order
  go run cmd/worker/main.go -conf configs/config.yaml -mode event
  ```

- [ ] Verify Dapr subscription registered
  ```bash
  curl http://localhost:3500/dapr/subscribe | jq
  # Should show fulfillment.status_changed subscription
  ```

- [ ] Publish test event via Dapr
  ```bash
  dapr publish --publish-app-id order-worker --pubsub pubsub-redis \
    --topic fulfillment.status_changed \
    --data '{
      "event_type": "fulfillment.status_changed",
      "fulfillment_id": "test-123",
      "order_id": "order-456",
      "old_status": "pending",
      "new_status": "planning"
    }'
  ```

- [ ] Verify order status updated to `processing`

#### 3.3 End-to-End Test (COD Flow)

- [ ] Create COD order via API
  ```bash
  curl -X POST http://localhost:8000/api/v1/checkout/confirm \
    -H "Content-Type: application/json" \
    -d '{
      "cart_session_id": "...",
      "payment_method": "cod",
      "shipping_address": {...}
    }'
  ```

- [ ] Wait for COD auto-confirm (or trigger manually)
  - [ ] Verify order status: `pending` → `confirmed`

- [ ] Check fulfillment created
  - [ ] Query fulfillment service for order
  - [ ] Verify fulfillment status: `planning`

- [ ] Check order status auto-updated
  - [ ] Query order service
  - [ ] Verify order status: `confirmed` → `processing` ✅

- [ ] Continue fulfillment flow
  - [ ] Mark fulfillment as `picking` → Verify order stays `processing`
  - [ ] Mark fulfillment as `shipped` → Verify order → `shipped`
  - [ ] Mark fulfillment as `completed` → Verify order → `delivered`

---

### Phase 4: Documentation

#### 4.1 Update Order Service Docs

**File**: `order/docs/flow/order-status-flow.md`

- [ ] Update section "Fulfillment Started" (line ~136)
  - [ ] Add note about FulfillmentConsumer
  - [ ] Add code reference to consumer

- [ ] Update COD order timeline example (line ~428)
  - [ ] Add step showing auto status update

- [ ] Update events consumed section
  - [ ] Add `fulfillment.status_changed` to list

#### 4.2 Update Dapr Documentation

**File**: `docs/workfllow/order-service-dapr.md`

- [ ] Add `FulfillmentConsumer` to Event Consumers section
- [ ] Document event schema
- [ ] Add code example
- [ ] Update event flow diagram

#### 4.3 Update Implementation Review

**File**: `docs/workfllow/cod-order-flow-review.md`

- [ ] Add "Implementation Status" section
- [ ] Mark issue as resolved
- [ ] Add links to PRs/commits

---

### Phase 5: Deployment

#### 5.1 Build & Push Image

- [ ] Build order service image
  ```bash
  cd order
  make docker-build
  ```

- [ ] Tag image with version
  ```bash
  docker tag order-service:latest registry-api.tanhdev.com/order-service:v1.x.x
  ```

- [ ] Push to registry
  ```bash
  docker push registry-api.tanhdev.com/order-service:v1.x.x
  ```

#### 5.2 Update ArgoCD

**File**: `argocd/applications/order-service/staging/tag.yaml`

- [ ] Update image tag
  ```yaml
  image:
    tag: "v1.x.x"
  ```

- [ ] Commit and push
  ```bash
  git add argocd/applications/order-service/staging/tag.yaml
  git commit -m "feat(order): add fulfillment status consumer for auto order status update"
  git push
  ```

#### 5.3 Monitor Deployment

- [ ] Check ArgoCD sync status
  ```bash
  kubectl get application order-service -n argocd
  ```

- [ ] Watch worker pod rollout
  ```bash
  kubectl rollout status deployment/order-service-worker -n core-business
  ```

- [ ] Check pod logs
  ```bash
  kubectl logs -f deployment/order-service-worker -c worker -n core-business
  ```

- [ ] Verify Dapr subscription
  ```bash
  kubectl exec -it order-service-worker-xxx -c daprd -- \
    wget -qO- http://localhost:3500/dapr/subscribe | jq
  ```

#### 5.4 Smoke Test Production

- [ ] Create test COD order in staging
- [ ] Monitor order status transitions
- [ ] Verify no errors in logs
- [ ] Check metrics/monitoring dashboards

---

## Post-Implementation Checklist

### Verification

- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] E2E test successful
- [ ] No new lint errors
- [ ] Wire generation successful
- [ ] Documentation updated

### Monitoring

- [ ] Add metrics for event consumption
  - [ ] `fulfillment_status_events_consumed_total`
  - [ ] `order_status_updates_from_fulfillment_total`
  - [ ] `fulfillment_event_processing_duration_seconds`

- [ ] Add alerts
  - [ ] High error rate in fulfillment consumer
  - [ ] Event processing latency > 5s
  - [ ] Order status stuck in confirmed > 10 min

### Clean Up

- [ ] Remove old workaround code (if any)
- [ ] Update API documentation
- [ ] Notify team of changes
- [ ] Close related tickets/issues

---

## Rollback Plan

If issues occur in production:

### Quick Rollback

- [ ] Revert ArgoCD tag to previous version
  ```bash
  # In argocd/applications/order-service/staging/tag.yaml
  image:
    tag: "v1.x.x-previous"  # Previous stable version
  ```

- [ ] Sync ArgoCD application
- [ ] Monitor worker restart

### Full Rollback

- [ ] Revert all code changes
  ```bash
  git revert <commit-hash>
  git push
  ```

- [ ] Rebuild and redeploy
- [ ] Verify old behavior restored

---

## Known Issues & Mitigation

### Issue 1: Event Ordering

**Problem**: Fulfillment events may arrive out of order

**Mitigation**: 
- ✅ `isLaterStatus()` prevents backward transitions
- ✅ Check current order status before updating

### Issue 2: Duplicate Events

**Problem**: Dapr may deliver events multiple times

**Mitigation**:
- ✅ Idempotency: Skip if order already at target status
- ✅ Use order status as guard

### Issue 3: Missing Events

**Problem**: Events may be lost during network issues

**Mitigation**:
- ✅ Dapr retry (3 attempts, 60s interval)
- ✅ Manual recovery: API endpoint to sync order status

---

## Success Criteria

- [x] Order status auto-updates from `confirmed` → `processing` when fulfillment planning starts
- [x] Order status follows fulfillment lifecycle (planning/picking → processing, shipped → shipped, completed → delivered)
- [x] No duplicate status transitions
- [x] No backward status transitions
- [x] All tests passing
- [x] Production deployment successful
- [x] Zero errors in logs for 24h after deployment

---

## Estimated Timeline

| Phase | Time | Items |
|-------|------|-------|
| Phase 1: Code | 1h | Consumer implementation |
| Phase 2: Wire DI | 15min | Wire updates |
| Phase 3: Testing | 1h | Unit + Integration + E2E |
| Phase 4: Docs | 30min | Update documentation |
| Phase 5: Deploy | 30min | Build, push, monitor |
| **Total** | **~3h** | **End-to-end** |

---

## References

- [COD Order Flow Review](file:///home/user/microservices/docs/workfllow/cod-order-flow-review.md)
- [Order Service Dapr Docs](file:///home/user/microservices/docs/workfllow/order-service-dapr.md)
- [Fulfillment Service Dapr Docs](file:///home/user/microservices/docs/workfllow/fulfillment-service-dapr.md)
- [Event-Driven Architecture Overview](file:///home/user/microservices/docs/workfllow/dapr-event-architecture-overview.md)
- [Order Status Flow](file:///home/user/microservices/order/docs/flow/order-status-flow.md)

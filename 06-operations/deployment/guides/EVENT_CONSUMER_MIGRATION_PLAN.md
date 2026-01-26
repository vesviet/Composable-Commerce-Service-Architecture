# Event Consumer Migration Plan - Move to Workers

**Mục đích**: Migrate event consumers từ main services sang worker processes  
**Cập nhật**: December 27, 2025  
**Ưu tiên**: 🔴 **HIGH** - Performance và scalability improvement

---

## 📊 **Current State Analysis**

### **Services với Event Consumers trong Main Service** ❌
1. **Customer Service**: 5 HTTP-based Dapr subscriptions
2. **Catalog Service**: 8 HTTP-based Dapr subscriptions

### **Services đã optimize với Workers** ✅
1. **Warehouse Service**: 4 gRPC consumers + 6 cron jobs
2. **Pricing Service**: 2 gRPC consumers  
3. **Search Service**: 4 gRPC consumers

### **Services chỉ publish events** ℹ️
- Order, Payment, Auth, User, Fulfillment, Notification, Review, Promotion, Shipping

---

## 🚨 **Problems với Current Architecture**

### **Customer Service Issues:**
```yaml
# Current HTTP subscriptions in main service
Subscriptions:
  - order.completed → /dapr/subscribe/order.completed
  - order.cancelled → /dapr/subscribe/order.cancelled  
  - order.returned → /dapr/subscribe/order.returned
  - auth.login → /dapr/subscribe/auth.login
  - auth.password_changed → /dapr/subscribe/auth.password_changed

Issues:
  ❌ Blocks main service during event processing
  ❌ Cannot scale independently
  ❌ Single point of failure
  ❌ API latency increases during event spikes
```

### **Catalog Service Issues:**
```yaml
# Current HTTP subscriptions in main service  
Subscriptions:
  - warehouse.inventory.stock_changed → /events/stock-changed
  - warehouse.stock.reserved → /events/stock-reserved
  - warehouse.stock.released → /events/stock-released
  - warehouse.inventory.low_stock → /events/low-stock-alert
  - pricing.price.updated → /events/price-updated (DISABLED)
  - pricing.price.bulk_updated → /events/price-bulk-updated (DISABLED)
  - pricing.warehouse_price.updated → /events/price-updated (DISABLED)
  - pricing.sku_price.updated → /events/price-updated (DISABLED)

Issues:
  ❌ 8 event subscriptions in main service
  ❌ Cache invalidation blocks API responses
  ❌ Price events disabled (inconsistent with Search service)
  ❌ Stock processing synchronous
```

---

## 🎯 **Target Architecture**

### **Recommended Pattern** (Follow Warehouse/Pricing/Search):
```go
// Worker process with gRPC consumers
type eventbusServerWorker struct {
    client eventbus.Client
}

type orderConsumerWorker struct {
    consumer eventbus.OrderConsumer
}

// Main service focuses only on API
// No event subscriptions in main service
```

### **Benefits:**
- ✅ Main service focuses on API performance
- ✅ Event processing scales independently  
- ✅ Better fault isolation
- ✅ Asynchronous event processing
- ✅ Can handle event spikes without affecting API

---

## 📋 **Implementation Plan**

## **Phase 1: Customer Service Migration** 🔴 **HIGH PRIORITY**

### **Step 1.1: Create Worker Structure**
```bash
# Create worker directories
mkdir -p customer/cmd/worker
mkdir -p customer/internal/data/eventbus
```

### **Step 1.2: Implement Worker Files**

#### **customer/cmd/worker/main.go**
```go
package main

import (
    "context"
    "flag"
    "os"
    "os/signal"
    "syscall"

    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/customer/internal/config"
    commonWorker "gitlab.com/ta-microservices/common/worker"
)

var (
    flagconf = flag.String("conf", "../../configs", "config path, eg: -conf config.yaml")
)

func main() {
    flag.Parse()
    
    // Load config
    cfg, err := config.LoadConfig(*flagconf)
    if err != nil {
        panic(err)
    }
    
    // Initialize logger
    logger := log.NewStdLogger(os.Stdout)
    
    // Initialize workers
    workers, cleanup, err := wireWorkers(cfg, logger)
    if err != nil {
        panic(err)
    }
    defer cleanup()
    
    // Start workers
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    for _, worker := range workers {
        go func(w commonWorker.ContinuousWorker) {
            if err := w.Start(ctx); err != nil {
                log.NewHelper(logger).Errorf("Worker failed: %v", err)
            }
        }(worker)
    }
    
    // Wait for shutdown signal
    c := make(chan os.Signal, 1)
    signal.Notify(c, syscall.SIGTERM, syscall.SIGINT)
    <-c
    
    log.NewHelper(logger).Info("Customer worker shutting down...")
}
```

#### **customer/cmd/worker/wire.go**
```go
//go:build wireinject
// +build wireinject

package main

import (
    "github.com/go-kratos/kratos/v2/log"
    "github.com/google/wire"
    
    "gitlab.com/ta-microservices/customer/internal/config"
    "gitlab.com/ta-microservices/customer/internal/data"
    "gitlab.com/ta-microservices/customer/internal/data/eventbus"
    commonWorker "gitlab.com/ta-microservices/common/worker"
)

func wireWorkers(*config.AppConfig, log.Logger) ([]commonWorker.ContinuousWorker, func(), error) {
    panic(wire.Build(
        data.ProviderSet,
        eventbus.ProviderSet,
        newWorkers,
    ))
}

func newWorkers(
    eventbusClient eventbus.Client,
    orderConsumer eventbus.OrderConsumer,
    authConsumer eventbus.AuthConsumer,
) []commonWorker.ContinuousWorker {
    var workers []commonWorker.ContinuousWorker
    
    // Add eventbus server worker (starts gRPC server once)
    workers = append(workers, &eventbusServerWorker{client: eventbusClient})
    
    // Add event consumer workers
    workers = append(workers, &orderConsumerWorker{consumer: orderConsumer})
    workers = append(workers, &authConsumerWorker{consumer: authConsumer})
    
    return workers
}

// Worker implementations
type eventbusServerWorker struct {
    client eventbus.Client
}

func (w *eventbusServerWorker) Start(ctx context.Context) error {
    return w.client.Start(ctx)
}

type orderConsumerWorker struct {
    consumer eventbus.OrderConsumer
}

func (w *orderConsumerWorker) Start(ctx context.Context) error {
    return w.consumer.ConsumeOrderEvents(ctx)
}

type authConsumerWorker struct {
    consumer eventbus.AuthConsumer
}

func (w *authConsumerWorker) Start(ctx context.Context) error {
    return w.consumer.ConsumeAuthEvents(ctx)
}
```

#### **customer/internal/data/eventbus/order_consumer.go**
```go
package eventbus

import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/go-kratos/kratos/v2/log"
    commonEvents "gitlab.com/ta-microservices/common/events"
    "gitlab.com/ta-microservices/customer/internal/biz/customer"
)

type OrderConsumer struct {
    client commonEvents.ConsumerClient
    customerUsecase *customer.CustomerUsecase
    log *log.Helper
}

func NewOrderConsumer(
    client commonEvents.ConsumerClient,
    customerUsecase *customer.CustomerUsecase,
    logger log.Logger,
) OrderConsumer {
    return OrderConsumer{
        client: client,
        customerUsecase: customerUsecase,
        log: log.NewHelper(logger),
    }
}

func (c OrderConsumer) ConsumeOrderEvents(ctx context.Context) error {
    pubsub := "pubsub-redis"
    
    // Order Completed
    if err := c.client.AddConsumer("order.completed", pubsub, c.HandleOrderCompleted); err != nil {
        return err
    }
    
    // Order Cancelled
    if err := c.client.AddConsumer("order.cancelled", pubsub, c.HandleOrderCancelled); err != nil {
        return err
    }
    
    // Order Returned
    if err := c.client.AddConsumer("order.returned", pubsub, c.HandleOrderReturned); err != nil {
        return err
    }
    
    return nil
}

func (c OrderConsumer) HandleOrderCompleted(ctx context.Context, e commonEvents.Message) error {
    var event OrderCompletedEvent
    if err := json.Unmarshal(e.Data, &event); err != nil {
        c.log.WithContext(ctx).Errorf("Failed to unmarshal order completed event: %v", err)
        return fmt.Errorf("failed to unmarshal order completed event: %w", err)
    }
    
    c.log.WithContext(ctx).Infof("Processing order completed: order_id=%s, customer_id=%s", 
        event.OrderID, event.CustomerID)
    
    // Update customer statistics
    return c.customerUsecase.UpdateOrderStats(ctx, event.CustomerID, event.TotalAmount)
}

func (c OrderConsumer) HandleOrderCancelled(ctx context.Context, e commonEvents.Message) error {
    // Similar implementation
    return nil
}

func (c OrderConsumer) HandleOrderReturned(ctx context.Context, e commonEvents.Message) error {
    // Similar implementation  
    return nil
}

// Event structures
type OrderCompletedEvent struct {
    OrderID     string  `json:"order_id"`
    CustomerID  string  `json:"customer_id"`
    TotalAmount float64 `json:"total_amount"`
    CompletedAt string  `json:"completed_at"`
}
```

### **Step 1.3: Update ArgoCD Configuration**

#### **customer/values.yaml - Add Worker Config**
```yaml
# Add worker configuration
worker:
  enabled: true
  replicaCount: 1
  image:
    repository: registry-api.tanhdev.com/customer-service
    pullPolicy: IfNotPresent
    tag: ""  # Uses same tag as main service
  args:
    - "-conf"
    - "/app/configs/config.yaml"
  podAnnotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "customer-worker"
    dapr.io/app-port: "5005"      # gRPC port for Dapr
    dapr.io/app-protocol: "grpc"  # Workers use gRPC
  resources:
    limits:
      cpu: 300m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

#### **customer/templates/worker-deployment.yaml**
```yaml
{{- if .Values.worker.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "customer-service.fullname" . }}-worker
  labels:
    {{- include "customer-service.labels" . | nindent 4 }}
    app.kubernetes.io/component: worker
spec:
  replicas: {{ .Values.worker.replicaCount }}
  selector:
    matchLabels:
      {{- include "customer-service.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: worker
  template:
    metadata:
      annotations:
        {{- with .Values.worker.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "customer-service.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: worker
    spec:
      containers:
        - name: worker
          image: "{{ .Values.worker.image.repository }}:{{ .Values.worker.image.tag | default .Values.image.tag }}"
          imagePullPolicy: {{ .Values.worker.image.pullPolicy }}
          command: ["/app/bin/worker"]
          args:
            {{- toYaml .Values.worker.args | nindent 12 }}
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ include "customer-service.fullname" . }}-secret
                  key: databaseUrl
          resources:
            {{- toYaml .Values.worker.resources | nindent 12 }}
{{- end }}
```

### **Step 1.4: Remove HTTP Subscriptions from Main Service**
```go
// customer/internal/server/http.go
// Remove these lines:
// srv.HandleFunc("/dapr/subscribe", handler.GetSubscriptionRoutes)
// srv.HandleFunc("/dapr/subscribe/order.completed", handler.HandleSubscription)
// etc.
```

---

## **Phase 2: Catalog Service Migration** 🔴 **HIGH PRIORITY**

### **Similar Implementation Pattern:**

#### **catalog/cmd/worker/main.go** (Similar to customer)

#### **catalog/internal/data/eventbus/stock_consumer.go**
```go
func (c StockConsumer) ConsumeStockEvents(ctx context.Context) error {
    pubsub := "pubsub-redis"
    
    // Stock Changed
    if err := c.client.AddConsumer("warehouse.inventory.stock_changed", pubsub, c.HandleStockChanged); err != nil {
        return err
    }
    
    // Stock Reserved
    if err := c.client.AddConsumer("warehouse.stock.reserved", pubsub, c.HandleStockReserved); err != nil {
        return err
    }
    
    // Stock Released
    if err := c.client.AddConsumer("warehouse.stock.released", pubsub, c.HandleStockReleased); err != nil {
        return err
    }
    
    // Low Stock Alert
    if err := c.client.AddConsumer("warehouse.inventory.low_stock", pubsub, c.HandleLowStock); err != nil {
        return err
    }
    
    return nil
}

func (c StockConsumer) HandleStockChanged(ctx context.Context, e commonEvents.Message) error {
    // Invalidate product cache asynchronously
    // No longer blocks main service
    return c.cacheManager.InvalidateProduct(ctx, event.ProductID)
}
```

#### **catalog/internal/data/eventbus/pricing_consumer.go**
```go
func (c PricingConsumer) ConsumePricingEvents(ctx context.Context) error {
    pubsub := "pubsub-redis"
    
    // Re-enable price events (currently disabled)
    if err := c.client.AddConsumer("pricing.price.updated", pubsub, c.HandlePriceUpdated); err != nil {
        return err
    }
    
    if err := c.client.AddConsumer("pricing.price.bulk_updated", pubsub, c.HandleBulkPriceUpdated); err != nil {
        return err
    }
    
    return nil
}
```

---

## 📊 **Performance Impact Analysis**

### **Before Migration:**
```yaml
Customer Service:
  - API Response Time: 200-500ms (includes event processing)
  - Event Processing: Synchronous, blocks API
  - Scaling: Cannot scale independently
  - Fault Tolerance: Single point of failure

Catalog Service:  
  - API Response Time: 300-800ms (includes cache invalidation)
  - Cache Invalidation: Synchronous, blocks API
  - Event Processing: 8 subscriptions in main service
  - Scaling: Cannot scale independently
```

### **After Migration:**
```yaml
Customer Service:
  - API Response Time: 50-150ms (API only)
  - Event Processing: Asynchronous in worker
  - Scaling: API and worker scale independently
  - Fault Tolerance: Worker failure doesn't affect API

Catalog Service:
  - API Response Time: 80-200ms (API only)  
  - Cache Invalidation: Asynchronous in worker
  - Event Processing: All events in worker
  - Scaling: API and worker scale independently
```

### **Expected Improvements:**
- **API Response Time**: -60% to -70%
- **Event Processing Throughput**: +200% to +300%
- **System Resilience**: +100% (fault isolation)
- **Scaling Flexibility**: Independent scaling

---

## 🔧 **Implementation Timeline**

### **Week 1: Customer Service**
- [ ] Day 1-2: Create worker structure and eventbus consumers
- [ ] Day 3: Implement gRPC consumers for order/auth events
- [ ] Day 4: Update ArgoCD configuration and deploy
- [ ] Day 5: Test and remove HTTP subscriptions from main service

### **Week 2: Catalog Service**  
- [ ] Day 1-2: Create worker structure and eventbus consumers
- [ ] Day 3: Implement gRPC consumers for stock/pricing events
- [ ] Day 4: Update ArgoCD configuration and deploy
- [ ] Day 5: Test and remove HTTP subscriptions from main service

### **Week 3: Validation & Optimization**
- [ ] Day 1-2: Performance testing and monitoring
- [ ] Day 3-4: Add event processing metrics and alerts
- [ ] Day 5: Documentation and team training

---

## 📋 **Validation Checklist**

### **Pre-Migration:**
- [ ] Backup current event handler logic
- [ ] Document current event flows
- [ ] Set up monitoring for event processing
- [ ] Prepare rollback plan

### **During Migration:**
- [ ] Deploy worker alongside main service
- [ ] Verify event processing in worker
- [ ] Monitor for duplicate event processing
- [ ] Gradually remove HTTP subscriptions

### **Post-Migration:**
- [ ] Verify API response time improvement
- [ ] Confirm event processing still works
- [ ] Check worker scaling behavior
- [ ] Monitor error rates and latency

---

## 🚨 **Rollback Plan**

### **If Issues Occur:**
```bash
# 1. Re-enable HTTP subscriptions in main service
git checkout HEAD~1 -- customer/internal/server/http.go

# 2. Disable worker deployment
kubectl scale deployment customer-service-worker --replicas=0

# 3. Restart main service
kubectl rollout restart deployment/customer-service

# 4. Verify event processing restored
kubectl logs -l app=customer-service --tail=50
```

---

## 📈 **Success Metrics**

### **Performance Metrics:**
- API response time reduction: Target -60%
- Event processing latency: Target <100ms
- System throughput: Target +200%

### **Reliability Metrics:**
- Event processing success rate: Target >99.9%
- API availability during event spikes: Target 100%
- Worker restart recovery time: Target <30s

### **Operational Metrics:**
- Independent scaling events: Track scaling behavior
- Resource utilization: Monitor CPU/memory usage
- Error rates: Monitor event processing errors

---

## 🎯 **Next Steps**

### **Immediate Actions:**
1. **Start with Customer Service** (simpler, 5 events)
2. **Create worker structure** following warehouse/pricing pattern
3. **Implement gRPC consumers** for order and auth events
4. **Deploy and test** in staging environment

### **Follow-up Actions:**
1. **Migrate Catalog Service** (more complex, 8 events)
2. **Add comprehensive monitoring** for event processing
3. **Document new architecture** for team reference
4. **Consider adding workers** to other services as needed

---

**Conclusion**: Moving event consumers to workers sẽ significantly improve system performance, scalability, và reliability. Customer và Catalog services sẽ benefit most từ migration này.

**Estimated Total Effort**: 2-3 weeks for both services  
**Expected ROI**: High - Major performance và scalability improvements
# So Sánh Dapr (Redis Pub/Sub) và Redis Streams

## Tổng Quan

Dự án hiện tại sử dụng **cả hai** công nghệ:
- **Dapr Pub/Sub với Redis backend**: Được sử dụng rộng rãi trong các services (catalog, warehouse, pricing, order, etc.)
- **Redis Streams trực tiếp**: Được sử dụng trong Fulfillment Service worker để xử lý order events

## 0. Dapr Pub/Sub: HTTP hay gRPC?

### ⚠️ Quan Trọng: Dapr Hỗ Trợ CẢ HTTP và gRPC

Dapr Pub/Sub có thể sử dụng **cả HTTP và gRPC**, nhưng trong dự án này:

### ✅ Dự Án Sử Dụng HTTP (Pattern Chính)

**Publish Events** (Tất cả services):
```go
// Dapr HTTP API
url := fmt.Sprintf("%s/v1.0/publish/pubsub-redis/%s", p.daprURL, topic)
resp, err := p.client.Do(req) // HTTP POST request
```

**Subscribe Events** (HTTP Callbacks):
```go
// Dapr gọi HTTP endpoint của service
func (h *EventHandler) DaprSubscribeHandler(w http.ResponseWriter, r *http.Request) {
    // Dapr gọi GET /dapr/subscribe để discover subscriptions
}

func (h *EventHandler) HandlePaymentConfirmed(w http.ResponseWriter, r *http.Request) {
    // Dapr gọi POST /events/payment-confirmed để deliver events
}
```

**Ports**:
- **HTTP**: Port 3500 (default) - `DAPR_HTTP_PORT=3500`
- **gRPC**: Port 50001 (default) - `DAPR_GRPC_PORT=50001` (có config nhưng không dùng cho Pub/Sub)

### ⚠️ gRPC SDK (Legacy Code)

Một số legacy code (catalog-main, shop-main) có sử dụng gRPC SDK:
```go
// Legacy pattern (KHÔNG phải pattern chính)
dClient, err := daprd.NewService(":5005") // gRPC service
```

**Nhưng pattern chính của dự án là HTTP**.

### So Sánh HTTP vs gRPC trong Dapr Pub/Sub

| Tiêu Chí | HTTP API | gRPC API |
|----------|----------|----------|
| **Publish** | ✅ `POST /v1.0/publish/{pubsub}/{topic}` | ✅ `PublishEvent()` method |
| **Subscribe** | ✅ HTTP callbacks (`/events/{name}`) | ✅ `AddTopicEventHandler()` |
| **Performance** | ⚠️ ~5-10ms overhead | ✅ ~2-5ms (nhanh hơn) |
| **Simplicity** | ✅ Đơn giản (HTTP client) | ⚠️ Cần gRPC client |
| **Debugging** | ✅ Dễ debug (curl, Postman) | ⚠️ Khó debug hơn |
| **Portability** | ✅ Works everywhere | ⚠️ Cần gRPC support |
| **Dự án sử dụng** | ✅ **Pattern chính** | ⚠️ Legacy code only |

### Khi Nào Dùng HTTP vs gRPC?

**✅ Dùng HTTP khi** (như dự án hiện tại):
- Cần đơn giản, dễ debug
- Cần portability
- Performance không phải ưu tiên hàng đầu
- Services đã có HTTP server

**✅ Dùng gRPC khi**:
- Cần performance tối đa
- Đã có gRPC infrastructure
- Cần type-safe contracts
- High-throughput scenarios

## 1. Kiến Trúc và Cách Hoạt Động

### Dapr Pub/Sub (Redis Backend) - HTTP Pattern

**Cách hoạt động**:
- Dapr là một **abstraction layer** trên Redis
- Services gọi Dapr **HTTP API**: `POST /v1.0/publish/{pubsub-name}/{topic}`
- Dapr sidecar xử lý việc publish/subscribe
- Dapr gọi **HTTP callbacks** của services để deliver events
- Dapr sử dụng Redis Streams **bên dưới** nhưng ẩn đi implementation details

**Cấu hình** (`dapr/components/pubsub-redis.yaml`):
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub-redis
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: redis:6379
  - name: maxRetries
    value: "3"
  - name: redeliverInterval
    value: "60s"
  - name: processingTimeout
    value: "60s"
```

**Publish Event** (ví dụ từ Catalog Service):
```go
// Dapr HTTP API
url := fmt.Sprintf("%s/v1.0/publish/pubsub-redis/%s", p.daprURL, topic)
resp, err := p.client.Do(req)
```

### Redis Streams Trực Tiếp

**Cách hoạt động**:
- Services tương tác **trực tiếp** với Redis qua Redis client
- Sử dụng các lệnh Redis Streams: `XADD`, `XREADGROUP`, `XAck`
- Toàn quyền kiểm soát consumer groups, message IDs, và acknowledgment

**Implementation** (ví dụ từ Fulfillment Service):
```go
// Publish: XADD
redisClient.XAdd(ctx, &redis.XAddArgs{
    Stream: streamName,
    Values: map[string]interface{}{...},
})

// Consume: XREADGROUP
streams, err := redisClient.XReadGroup(ctx, &redis.XReadGroupArgs{
    Group:    consumerGroup,
    Consumer: consumerName,
    Streams:  []string{streamName, ">"},
    Count:    10,
    Block:    time.Second * 5,
})

// Acknowledge: XACK
redisClient.XAck(ctx, streamName, consumerGroup, message.ID)
```

## 2. So Sánh Chi Tiết

| Tiêu Chí | Dapr Pub/Sub (Redis) | Redis Streams Trực Tiếp |
|----------|---------------------|-------------------------|
| **Độ phức tạp** | ✅ Đơn giản hơn (abstraction layer) | ⚠️ Phức tạp hơn (cần hiểu Redis Streams) |
| **Portability** | ✅ Có thể đổi backend (Kafka, RabbitMQ, etc.) | ❌ Gắn chặt với Redis |
| **Kiểm soát** | ⚠️ Hạn chế (phụ thuộc Dapr features) | ✅ Toàn quyền kiểm soát |
| **Performance** | ⚠️ Có overhead (Dapr sidecar) | ✅ Performance tốt hơn (direct) |
| **Setup & Deployment** | ⚠️ Cần Dapr runtime + sidecar | ✅ Chỉ cần Redis client |
| **Consumer Groups** | ✅ Tự động quản lý | ⚠️ Phải tự quản lý |
| **Dead Letter Queue** | ✅ Built-in support | ⚠️ Phải tự implement |
| **Retry Logic** | ✅ Built-in với config | ⚠️ Phải tự implement |
| **Monitoring** | ✅ Dapr dashboard/metrics | ⚠️ Phải tự monitor Redis |
| **Error Handling** | ✅ Standardized | ⚠️ Phải tự handle |
| **Message Ordering** | ✅ Đảm bảo (qua Redis Streams) | ✅ Đảm bảo (native) |
| **At-least-once Delivery** | ✅ Built-in | ✅ Built-in (qua consumer groups) |
| **Backpressure** | ✅ Có thể config | ⚠️ Phải tự implement |

## 3. Use Cases trong Dự Án

### Dapr Pub/Sub - Phù hợp cho:

1. **Event Publishing từ Services** (Catalog, Warehouse, Pricing, Order, etc.)
   - ✅ Đơn giản, dễ maintain
   - ✅ Standardized API
   - ✅ Dễ dàng thay đổi backend sau này

2. **Cross-service Communication**
   - ✅ Service discovery tự động
   - ✅ Load balancing built-in
   - ✅ Health checks tự động

3. **Khi cần Portability**
   - ✅ Có thể switch sang Kafka, RabbitMQ mà không đổi code

**Ví dụ sử dụng**:
```go
// Catalog Service - Publish product events
publisher.PublishEvent(ctx, "catalog.product.created", event)

// Warehouse Service - Publish stock events  
publisher.PublishEvent(ctx, "warehouse.stock.updated", event)

// Pricing Service - Publish price events
publisher.PublishEvent(ctx, "pricing.price.updated", event)
```

### Redis Streams Trực Tiếp - Phù hợp cho:

1. **High-performance Workers** (Fulfillment Service)
   - ✅ Cần performance tối đa
   - ✅ Cần fine-grained control
   - ✅ Cần custom retry logic

2. **Khi cần Custom Processing**
   - ✅ Batch processing
   - ✅ Custom acknowledgment logic
   - ✅ Custom error handling

3. **Khi không muốn Dapr dependency**
   - ✅ Standalone workers
   - ✅ Background jobs
   - ✅ Event processing pipelines

**Ví dụ sử dụng**:
```go
// Fulfillment Worker - Listen to order status changes
worker := NewOrderStatusListenerWorker(...)
worker.Start(ctx) // Uses XREADGROUP directly
```

## 4. Performance Comparison

### Dapr Pub/Sub
- **Latency**: ~5-10ms overhead (Dapr sidecar processing)
- **Throughput**: ~10,000-50,000 messages/second (tùy config)
- **Resource**: Cần Dapr sidecar (thêm memory/CPU)

### Redis Streams Trực Tiếp
- **Latency**: ~1-3ms (direct Redis call)
- **Throughput**: ~50,000-100,000 messages/second
- **Resource**: Chỉ cần Redis client library

## 5. Code Complexity

### Dapr Pub/Sub

**Publish** (đơn giản):
```go
func (p *DaprEventPublisher) PublishEvent(ctx context.Context, topic string, event interface{}) error {
    eventData, _ := json.Marshal(event)
    url := fmt.Sprintf("%s/v1.0/publish/pubsub-redis/%s", p.daprURL, topic)
    resp, err := p.client.Do(req)
    return err
}
```

**Subscribe** (qua Dapr subscription config):
```yaml
# subscription.yaml
apiVersion: dapr.io/v2alpha1
kind: Subscription
spec:
  pubsubname: pubsub-redis
  topic: order.created
  routes:
    default: /dapr/subscribe/order.created
```

### Redis Streams Trực Tiếp

**Publish** (phức tạp hơn):
```go
func publishEvent(ctx context.Context, stream string, event interface{}) error {
    data, _ := json.Marshal(event)
    _, err := redisClient.XAdd(ctx, &redis.XAddArgs{
        Stream: stream,
        Values: map[string]interface{}{
            "data": string(data),
            "timestamp": time.Now().Unix(),
        },
    })
    return err
}
```

**Subscribe** (phức tạp hơn):
```go
func consumeEvents(ctx context.Context) {
    // Ensure consumer group
    redisClient.XGroupCreateMkStream(ctx, stream, group, "0")
    
    // Read loop
    for {
        streams, _ := redisClient.XReadGroup(ctx, &redis.XReadGroupArgs{
            Group: group,
            Consumer: consumer,
            Streams: []string{stream, ">"},
            Count: 10,
            Block: 5 * time.Second,
        })
        
        // Process messages
        for _, msg := range streams[0].Messages {
            processEvent(msg)
            redisClient.XAck(ctx, stream, group, msg.ID)
        }
    }
}
```

## 6. Monitoring & Observability

### Dapr Pub/Sub
- ✅ **Dapr Dashboard**: Built-in metrics, traces
- ✅ **Prometheus**: Dapr metrics endpoint
- ✅ **Distributed Tracing**: Automatic với OpenTelemetry
- ✅ **Health Checks**: Built-in

### Redis Streams Trực Tiếp
- ⚠️ **Redis CLI**: Phải tự check streams
- ⚠️ **Custom Metrics**: Phải tự implement
- ⚠️ **Tracing**: Phải tự instrument
- ⚠️ **Health Checks**: Phải tự implement

**Script kiểm tra** (`scripts/test-redis-stream.sh`):
```bash
# Check stream info
redis-cli XINFO STREAM "pubsub-redis:orders.order.created"

# Check consumer groups
redis-cli XINFO GROUPS "pubsub-redis:orders.order.created"

# Check pending messages
redis-cli XPENDING "pubsub-redis:orders.order.created" "fulfillment-service"
```

## 7. Error Handling & Resilience

### Dapr Pub/Sub
- ✅ **Retry**: Config qua `maxRetries`, `maxRetryBackoff`
- ✅ **Dead Letter Queue**: Built-in qua `deadLetterTopic`
- ✅ **Circuit Breaker**: Có thể config qua Dapr resiliency policies
- ✅ **Timeout**: Config qua `processingTimeout`

**Config example**:
```yaml
metadata:
  maxRetries: "3"
  maxRetryBackoff: "2s"
  processingTimeout: "60s"
  deadLetterTopic: order.created.deadletter
```

### Redis Streams Trực Tiếp
- ⚠️ **Retry**: Phải tự implement (exponential backoff, etc.)
- ⚠️ **Dead Letter Queue**: Phải tự implement (separate stream)
- ⚠️ **Circuit Breaker**: Phải tự implement
- ⚠️ **Timeout**: Phải tự handle (context timeout)

**Implementation example**:
```go
// Custom retry logic
for attempt := 0; attempt < maxRetries; attempt++ {
    err := processEvent(ctx, msg)
    if err == nil {
        break
    }
    time.Sleep(time.Duration(attempt) * time.Second)
}

// Dead letter queue
if err != nil {
    redisClient.XAdd(ctx, &redis.XAddArgs{
        Stream: "dead-letter-queue",
        Values: map[string]interface{}{"original": msg},
    })
}
```

## 8. Khi Nào Nên Dùng Gì?

### ✅ Dùng Dapr Pub/Sub khi:

1. **Microservices Communication**
   - Cần standardized event bus
   - Cần portability (có thể đổi backend)
   - Cần built-in observability

2. **Event Publishing từ Services**
   - Catalog, Warehouse, Pricing, Order services
   - Đơn giản, dễ maintain
   - Không cần fine-grained control

3. **Kubernetes Environment**
   - Dapr tích hợp tốt với K8s
   - Sidecar injection tự động
   - Service mesh integration

### ✅ Dùng Redis Streams Trực Tiếp khi:

1. **High-performance Workers**
   - Fulfillment workers
   - Background job processors
   - Event processing pipelines

2. **Cần Fine-grained Control**
   - Custom retry logic
   - Custom batching
   - Custom acknowledgment

3. **Standalone Applications**
   - Không muốn Dapr dependency
   - Simple event processing
   - Direct Redis access

## 9. Best Practices

### Dapr Pub/Sub

1. **Topic Naming**: Sử dụng dot notation
   ```
   catalog.product.created
   warehouse.stock.updated
   pricing.price.updated
   ```

2. **Event Schema**: Standardize event format
   ```go
   type Event struct {
       EventType string    `json:"eventType"`
       Timestamp time.Time `json:"timestamp"`
       Data      interface{} `json:"data"`
   }
   ```

3. **Error Handling**: Graceful degradation
   ```go
   if err := publisher.PublishEvent(ctx, topic, event); err != nil {
       log.Warnf("Failed to publish (non-critical): %v", err)
       // Don't fail the main operation
   }
   ```

4. **Subscription Config**: Use declarative subscriptions
   ```yaml
   apiVersion: dapr.io/v2alpha1
   kind: Subscription
   spec:
     pubsubname: pubsub-redis
     topic: order.created
     routes:
       default: /dapr/subscribe/order.created
   ```

### Redis Streams Trực Tiếp

1. **Consumer Groups**: Luôn sử dụng consumer groups
   ```go
   redisClient.XGroupCreateMkStream(ctx, stream, group, "0")
   ```

2. **Acknowledgment**: Luôn ACK sau khi process thành công
   ```go
   if err := processEvent(ctx, msg); err == nil {
       redisClient.XAck(ctx, stream, group, msg.ID)
   }
   ```

3. **Pending Messages**: Monitor và handle pending messages
   ```go
   // Check pending messages
   pending, _ := redisClient.XPending(ctx, stream, group)
   if pending.Count > 0 {
       // Handle pending messages
   }
   ```

4. **Idempotency**: Implement idempotency checks
   ```go
   eventID := extractEventID(msg)
   if alreadyProcessed(eventID) {
       return nil // Skip duplicate
   }
   markAsProcessed(eventID)
   ```

## 10. Migration Path

### Từ Dapr sang Redis Streams Trực Tiếp

**Khi nào cần migrate**:
- Performance bottleneck
- Cần custom features không có trong Dapr
- Muốn giảm dependencies

**Cách migrate**:
1. Implement Redis Streams client
2. Migrate từng service một
3. Dual-write trong transition period
4. Monitor và validate
5. Remove Dapr dependency

### Từ Redis Streams sang Dapr

**Khi nào cần migrate**:
- Cần portability
- Cần built-in observability
- Cần standardize event bus

**Cách migrate**:
1. Setup Dapr infrastructure
2. Implement Dapr publisher
3. Migrate consumers từng service một
4. Validate và monitor
5. Remove direct Redis Streams code

## 11. Kết Luận

### Dapr Pub/Sub (Redis Backend)
- ✅ **Ưu điểm**: Đơn giản, portable, built-in features
- ⚠️ **Nhược điểm**: Overhead, ít control, dependency

### Redis Streams Trực Tiếp
- ✅ **Ưu điểm**: Performance cao, full control, no dependency
- ⚠️ **Nhược điểm**: Phức tạp, phải tự implement features

### Khuyến Nghị cho Dự Án

**Hiện tại** (đang làm đúng):
- ✅ **Dapr Pub/Sub** cho event publishing từ services
- ✅ **Redis Streams trực tiếp** cho high-performance workers

**Tương lai**:
- Có thể standardize toàn bộ về Dapr nếu cần portability
- Hoặc giữ hybrid approach nếu cần performance cho workers

## 12. Dapr Pub/Sub và Redis Streams: Hybrid Approach

### ❓ Câu Hỏi 1: Order Publish qua Dapr, Workers Listen qua Redis Streams - Được Không?

### ✅ Trả Lời: CÓ! Hoàn toàn được!

**Đây là một pattern rất hợp lý và đang được sử dụng trong dự án:**

#### Cách Hoạt Động:

1. **Order Service** publish events qua Dapr Pub/Sub:
   ```go
   // Order Service
   publisher.PublishEvent(ctx, "orders.order.status_changed", event)
   // → POST http://localhost:3500/v1.0/publish/pubsub-redis/orders.order.status_changed
   ```

2. **Dapr** lưu events vào Redis Streams với format:
   ```
   Stream Name: {pubsub-name}:{topic}
   = pubsub-redis:orders.order.status_changed
   ```

3. **Workers** có thể đọc trực tiếp từ Redis Streams:
   ```go
   // Worker - Redis Streams trực tiếp
   streams, err := redisClient.XReadGroup(ctx, &redis.XReadGroupArgs{
       Group:   "fulfillment-service",
       Streams: []string{"pubsub-redis:orders.order.status_changed", ">"},
   })
   ```

#### ✅ Lợi Ích của Pattern Này:

1. **Services (Order)**: Đơn giản, standardized API qua Dapr
2. **Workers**: Performance cao, không cần HTTP server, không cần Dapr sidecar
3. **Flexibility**: Services và Workers có thể chọn pattern phù hợp

#### ⚠️ Lưu Ý:

- **Stream Name Format**: Phải đúng format `{pubsub-name}:{topic}`
  - ✅ `pubsub-redis:orders.order.status_changed`
  - ❌ `orders.order.status_changed` (thiếu pubsub-name prefix)

- **Event Format**: Dapr wrap events trong CloudEvents format, cần parse đúng:
   ```go
   // Dapr format trong Redis Stream
   {
     "data": {
       "event_type": "orders.order.status_changed",
       "order_id": 123,
       ...
     }
   }
   ```

#### Ví Dụ Implementation:

```go
// Worker đọc từ Redis Streams (Dapr đã publish)
func (w *Worker) Start(ctx context.Context) error {
    streamName := "pubsub-redis:orders.order.status_changed"
    
    // Ensure consumer group
    redisClient.XGroupCreateMkStream(ctx, streamName, "fulfillment-service", "0")
    
    for {
        streams, err := redisClient.XReadGroup(ctx, &redis.XReadGroupArgs{
            Group:   "fulfillment-service",
            Consumer: "worker-1",
            Streams: []string{streamName, ">"},
            Count:   10,
            Block:   5 * time.Second,
        })
        
        for _, msg := range streams[0].Messages {
            // Parse Dapr CloudEvents format
            var daprEvent struct {
                Data OrderStatusChangedEvent `json:"data"`
            }
            json.Unmarshal([]byte(msg.Values["data"].(string)), &daprEvent)
            
            // Process event
            w.processEvent(ctx, &daprEvent.Data)
            
            // ACK
            redisClient.XAck(ctx, streamName, "fulfillment-service", msg.ID)
        }
    }
}
```

### ❓ Câu Hỏi 2: Có Thể Dùng Dapr Pub/Sub trong Workers Không?

### ✅ Trả Lời: CÓ, nhưng có Trade-offs

**Hiện tại**: Workers đang dùng Redis Streams trực tiếp (như Fulfillment Service worker) HOẶC HTTP callbacks từ Dapr

**Có thể chuyển sang Dapr Pub/Sub**, nhưng cần:

### 1. Expose HTTP Server để Nhận Callbacks

Workers cần expose HTTP endpoints để Dapr gọi khi có events:

```go
// internal/worker/event/dapr_listener.go
package event

import (
    "context"
    "net/http"
    "github.com/go-kratos/kratos/v2/log"
)

type DaprOrderStatusListenerWorker struct {
    *base.BaseWorker
    fulfillmentUsecase *fulfillment.FulfillmentUseCase
    httpServer        *http.Server
    log               *log.Helper
}

func NewDaprOrderStatusListenerWorker(
    fulfillmentUsecase *fulfillment.FulfillmentUseCase,
    logger log.Logger,
) *DaprOrderStatusListenerWorker {
    return &DaprOrderStatusListenerWorker{
        BaseWorker:         base.NewBaseWorker("dapr-order-status-listener-worker", logger),
        fulfillmentUsecase: fulfillmentUsecase,
        log:                log.NewHelper(logger),
    }
}

func (w *DaprOrderStatusListenerWorker) Start(ctx context.Context) error {
    // Setup HTTP server for Dapr callbacks
    mux := http.NewServeMux()
    
    // Subscription discovery endpoint
    mux.HandleFunc("/dapr/subscribe", w.DaprSubscribeHandler)
    
    // Event handler endpoint
    mux.HandleFunc("/events/order-status-changed", w.HandleOrderStatusChanged)
    
    w.httpServer = &http.Server{
        Addr:    ":8080", // Worker HTTP port
        Handler: mux,
    }
    
    // Start HTTP server in goroutine
    go func() {
        if err := w.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            w.log.Errorf("HTTP server error: %v", err)
        }
    }()
    
    w.log.Info("Dapr worker started, listening on :8080")
    return nil
}

func (w *DaprOrderStatusListenerWorker) DaprSubscribeHandler(w http.ResponseWriter, r *http.Request) {
    subscriptions := []DaprSubscription{
        {
            PubsubName: "pubsub-redis",
            Topic:      "orders.order.status_changed",
            Route:      "/events/order-status-changed",
        },
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(subscriptions)
}

func (w *DaprOrderStatusListenerWorker) HandleOrderStatusChanged(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    
    // Parse CloudEvent
    var cloudEvent struct {
        Data OrderStatusChangedEvent `json:"data"`
    }
    if err := json.NewDecoder(r.Body).Decode(&cloudEvent); err != nil {
        http.Error(w, "Bad request", http.StatusBadRequest)
        return
    }
    
    // Process event
    if err := w.processEvent(ctx, &cloudEvent.Data); err != nil {
        w.log.WithContext(ctx).Errorf("Failed to process event: %v", err)
        http.Error(w, "Internal server error", http.StatusInternalServerError)
        return // Dapr will retry
    }
    
    w.WriteHeader(http.StatusOK)
}

func (w *DaprOrderStatusListenerWorker) Stop() error {
    if w.httpServer != nil {
        return w.httpServer.Shutdown(context.Background())
    }
    return nil
}
```

### 2. Cấu Hình Dapr Sidecar cho Worker

Cần Dapr sidecar cho worker container:

```yaml
# fulfillment/docker-compose.yml
services:
  fulfillment-event-worker:
    build:
      context: ..
      dockerfile: fulfillment/Dockerfile.optimized
      args:
        MAIN_PKG: ./cmd/worker
        BIN_NAME: worker
    container_name: fulfillment-event-worker
    command: ["./worker", "-mode", "event", "-conf", "../configs"]
    environment:
      - WORKER_MODE=event
      - DAPR_HTTP_PORT=3500
    ports:
      - "8080:8080"  # Worker HTTP server for Dapr callbacks
    networks:
      - microservices

  fulfillment-worker-dapr:
    image: daprio/daprd:1.12.0
    container_name: fulfillment_worker_dapr
    command: [
      "./daprd",
      "-app-id", "fulfillment-event-worker",
      "-app-port", "8080",  # Worker HTTP port
      "-dapr-http-port", "3500",
      "-dapr-grpc-port", "50001",
      "-components-path", "/components",
    ]
    volumes:
      - ../dapr/components:/components:ro
    depends_on:
      fulfillment-event-worker:
        condition: service_started
    networks:
      - microservices
    network_mode: "service:fulfillment-event-worker"  # Share network
```

### 3. So Sánh: Redis Streams vs Dapr Pub/Sub trong Workers

| Tiêu Chí | Redis Streams (Hiện tại) | Dapr Pub/Sub |
|----------|---------------------------|--------------|
| **Setup** | ✅ Đơn giản (chỉ cần Redis client) | ⚠️ Cần HTTP server + Dapr sidecar |
| **Performance** | ✅ Cao (direct Redis) | ⚠️ Có overhead (HTTP callbacks) |
| **Resource** | ✅ Nhẹ (chỉ Redis client) | ⚠️ Nặng hơn (HTTP server + Dapr) |
| **Retry Logic** | ⚠️ Phải tự implement | ✅ Built-in (Dapr retry) |
| **Dead Letter Queue** | ⚠️ Phải tự implement | ✅ Built-in |
| **Monitoring** | ⚠️ Phải tự monitor | ✅ Dapr metrics |
| **Portability** | ❌ Gắn với Redis | ✅ Có thể đổi backend |
| **Code Complexity** | ⚠️ Phức tạp hơn | ✅ Đơn giản hơn (HTTP callbacks) |
| **Scalability** | ✅ Tốt (consumer groups) | ✅ Tốt (Dapr load balancing) |

### 4. Khi Nào Nên Dùng Dapr Pub/Sub trong Workers?

**✅ Nên dùng Dapr Pub/Sub khi**:
- Cần built-in retry và dead letter queue
- Cần monitoring và observability
- Cần portability (có thể đổi backend)
- Workers đã có HTTP server
- Performance không phải ưu tiên hàng đầu

**✅ Nên dùng Redis Streams trực tiếp khi**:
- Cần performance tối đa
- Workers là lightweight processes
- Không muốn thêm dependencies
- Cần fine-grained control
- Đã có custom retry logic

### 5. Hybrid Approach (Khuyến Nghị - Đang Dùng)

**Dự án đang dùng hybrid approach rất hiệu quả:**

#### Pattern 1: Services Publish qua Dapr, Workers Listen qua Redis Streams

```go
// Order Service - Publish qua Dapr
publisher.PublishEvent(ctx, "orders.order.status_changed", event)
// → Dapr lưu vào: pubsub-redis:orders.order.status_changed

// Worker - Listen trực tiếp từ Redis Streams
streams, _ := redisClient.XReadGroup(ctx, &redis.XReadGroupArgs{
    Streams: []string{"pubsub-redis:orders.order.status_changed", ">"},
})
```

**Lợi ích**:
- ✅ Services: Đơn giản, standardized
- ✅ Workers: Performance cao, không cần HTTP server
- ✅ Best of both worlds

#### Pattern 2: Workers Listen qua Dapr HTTP Callbacks

```go
// Worker - HTTP callbacks từ Dapr
type OrderStatusListenerWorker struct {
    httpServer *http.Server  // Dapr callbacks
}

func (w *Worker) Start(ctx context.Context) error {
    mux := http.NewServeMux()
    mux.HandleFunc("/dapr/subscribe", w.DaprSubscribeHandler)
    mux.HandleFunc("/events/order-status-changed", w.HandleEvent)
    return http.ListenAndServe(":8080", mux)
}
```

**Lợi ích**:
- ✅ Built-in retry và dead letter queue
- ✅ Monitoring và observability
- ⚠️ Cần HTTP server và Dapr sidecar

#### Pattern 3: High-performance Workers - Redis Streams Trực Tiếp

```go
// High-performance workers: Redis Streams
type OrderStatusListenerWorker struct {
    redisClient *redis.Client  // Direct Redis
}
```

**Lợi ích**:
- ✅ Performance tối đa
- ✅ Fine-grained control
- ✅ Không cần dependencies

### 6. Migration Path

**Từ Redis Streams sang Dapr Pub/Sub**:

1. **Thêm HTTP server** vào worker
2. **Implement Dapr subscription handlers**
3. **Setup Dapr sidecar** cho worker container
4. **Test và validate**
5. **Monitor performance**

**Ví dụ migration**:

```go
// Before: Redis Streams
func (w *Worker) Start(ctx context.Context) error {
    for {
        streams, _ := w.redisClient.XReadGroup(ctx, &redis.XReadGroupArgs{
            Group:   "fulfillment-service",
            Streams: []string{"orders.order.status_changed", ">"},
        })
        // Process...
    }
}

// After: Dapr Pub/Sub
func (w *Worker) Start(ctx context.Context) error {
    // Start HTTP server
    mux := http.NewServeMux()
    mux.HandleFunc("/dapr/subscribe", w.DaprSubscribeHandler)
    mux.HandleFunc("/events/order-status-changed", w.HandleEvent)
    
    return http.ListenAndServe(":8080", mux)
}
```

### 7. Best Practices cho Workers với Dapr

1. **HTTP Server Port**: Dùng port riêng cho workers (8080, 8081, etc.)
2. **Health Checks**: Expose `/health` endpoint
3. **Graceful Shutdown**: Implement proper shutdown cho HTTP server
4. **Error Handling**: Return proper HTTP status codes (200 = success, 500 = retry)
5. **Idempotency**: Implement idempotency checks trong handlers

```go
func (w *Worker) HandleEvent(w http.ResponseWriter, r *http.Request) {
    // Parse event
    event := parseEvent(r.Body)
    
    // Check idempotency
    if w.alreadyProcessed(event.ID) {
        w.WriteHeader(http.StatusOK) // Already processed
        return
    }
    
    // Process event
    if err := w.process(event); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return // Dapr will retry
    }
    
    // Mark as processed
    w.markAsProcessed(event.ID)
    w.WriteHeader(http.StatusOK)
}
```

## 13. Tài Liệu Tham Khảo

- [Dapr Pub/Sub Documentation](https://docs.dapr.io/developing-applications/building-blocks/pubsub/pubsub-overview/)
- [Redis Streams Documentation](https://redis.io/docs/data-types/streams/)
- [Dapr Redis Pub/Sub Component](https://docs.dapr.io/reference/components-reference/supported-pubsub/setup-redis-pubsub/)
- [Redis Streams Tutorial](https://redis.io/docs/data-types/streams-tutorial/)
- [Dapr Workers Pattern](https://docs.dapr.io/developing-applications/building-blocks/pubsub/howto-publish-subscribe/)


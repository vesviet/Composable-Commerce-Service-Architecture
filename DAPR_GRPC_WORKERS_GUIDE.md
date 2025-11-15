# Dapr gRPC Event Callbacks cho Workers

## ❓ Câu Hỏi: Nếu Dùng gRPC Cho Event Callbacks Trong Workers Thì Sao?

## ✅ Trả Lời: Dapr Hỗ Trợ gRPC, Nhưng Cần Setup Khác

### So Sánh HTTP vs gRPC cho Workers

| Tiêu Chí | HTTP Callbacks | gRPC Callbacks |
|----------|----------------|----------------|
| **Setup** | ✅ Đơn giản (HTTP server) | ⚠️ Phức tạp hơn (gRPC server) |
| **Performance** | ⚠️ ~5-10ms overhead | ✅ ~2-5ms (nhanh hơn) |
| **Port** | ✅ Port riêng (8080, etc.) | ✅ Port riêng (5005, etc.) |
| **Dependencies** | ✅ Chỉ cần HTTP | ⚠️ Cần gRPC + Dapr SDK |
| **Code Complexity** | ✅ Đơn giản | ⚠️ Phức tạp hơn |
| **Debugging** | ✅ Dễ (curl, Postman) | ⚠️ Khó hơn (cần gRPC tools) |

## Implementation: gRPC Callbacks cho Workers

### 1. Worker Implementation với gRPC

```go
// internal/worker/event/order_status_listener_grpc.go
package event

import (
    "context"
    "encoding/json"
    "fmt"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/dapr/go-sdk/service/common"
    daprd "github.com/dapr/go-sdk/service/grpc"
    
    "gitlab.com/ta-microservices/fulfillment/internal/biz/fulfillment"
    "gitlab.com/ta-microservices/fulfillment/internal/worker/base"
)

// OrderStatusListenerWorkerGRPC listens to events via Dapr gRPC
type OrderStatusListenerWorkerGRPC struct {
    *base.BaseWorker
    fulfillmentUsecase *fulfillment.FulfillmentUseCase
    daprService        common.Service
    log                *log.Helper
}

// NewOrderStatusListenerWorkerGRPC creates a new gRPC-based worker
func NewOrderStatusListenerWorkerGRPC(
    fulfillmentUsecase *fulfillment.FulfillmentUseCase,
    logger log.Logger,
) (*OrderStatusListenerWorkerGRPC, error) {
    // Create Dapr gRPC service
    // Port 5005 is the gRPC port for worker
    daprService, err := daprd.NewService(":5005")
    if err != nil {
        return nil, fmt.Errorf("failed to create Dapr gRPC service: %w", err)
    }
    
    return &OrderStatusListenerWorkerGRPC{
        BaseWorker:         base.NewBaseWorker("order-status-listener-worker-grpc", logger),
        fulfillmentUsecase: fulfillmentUsecase,
        daprService:        daprService,
        log:                log.NewHelper(logger),
    }, nil
}

// Start starts the gRPC server to listen for events from Dapr
func (w *OrderStatusListenerWorkerGRPC) Start(ctx context.Context) error {
    w.Log().Info("Starting order status listener worker (gRPC server on port 5005)")
    
    // Subscribe to topic using Dapr SDK
    subscription := &common.Subscription{
        PubsubName: "pubsub-redis",
        Topic:      "orders.order.status_changed",
        Route:      "/orders.order.status_changed",
        Metadata: map[string]string{
            "rawPayload": "true",
        },
    }
    
    // Add topic event handler
    err := w.daprService.AddTopicEventHandler(subscription, w.handleOrderStatusChanged)
    if err != nil {
        return fmt.Errorf("failed to add topic event handler: %w", err)
    }
    
    // Start gRPC server (blocking call)
    w.Log().Info("gRPC server listening on port 5005")
    return w.daprService.Start()
}

// Stop gracefully stops the gRPC server
func (w *OrderStatusListenerWorkerGRPC) Stop() error {
    // Dapr SDK service doesn't have explicit Stop method
    // Context cancellation will stop it
    return nil
}

// handleOrderStatusChanged handles the order status changed event
func (w *OrderStatusListenerWorkerGRPC) handleOrderStatusChanged(
    ctx context.Context,
    e *common.TopicEvent,
) (retry bool, err error) {
    w.Log().WithContext(ctx).Infof("Received event: topic=%s, pubsub=%s", e.Topic, e.PubsubName)
    
    // Parse event data
    var event OrderStatusChangedEvent
    
    // Dapr wraps event in CloudEvents format
    // e.Data can be map[string]interface{} or []byte
    switch data := e.Data.(type) {
    case map[string]interface{}:
        // Extract data field
        if dataField, ok := data["data"].(map[string]interface{}); ok {
            eventBytes, _ := json.Marshal(dataField)
            if err := json.Unmarshal(eventBytes, &event); err != nil {
                w.Log().WithContext(ctx).Errorf("Failed to unmarshal event: %v", err)
                return false, err // Don't retry on parse error
            }
        } else {
            // Direct format
            eventBytes, _ := json.Marshal(data)
            if err := json.Unmarshal(eventBytes, &event); err != nil {
                w.Log().WithContext(ctx).Errorf("Failed to unmarshal event: %v", err)
                return false, err
            }
        }
    case []byte:
        // Direct JSON bytes
        if err := json.Unmarshal(data, &event); err != nil {
            w.Log().WithContext(ctx).Errorf("Failed to unmarshal event: %v", err)
            return false, err
        }
    default:
        w.Log().WithContext(ctx).Errorf("Unexpected event data type: %T", e.Data)
        return false, fmt.Errorf("unexpected event data type: %T", e.Data)
    }
    
    // Process event
    if err := w.processOrderStatusChanged(ctx, &event); err != nil {
        w.Log().WithContext(ctx).Errorf("Failed to process event: %v", err)
        return true, err // Retry on processing error
    }
    
    return false, nil // Success, no retry needed
}

// processOrderStatusChanged processes the order status changed event
func (w *OrderStatusListenerWorkerGRPC) processOrderStatusChanged(
    ctx context.Context,
    event *OrderStatusChangedEvent,
) error {
    // Same processing logic as HTTP version
    w.Log().Infof("Processing order status changed: order_id=%d, old_status=%s, new_status=%s",
        event.OrderID, event.OldStatus, event.NewStatus)
    
    // ... same business logic ...
    
    return nil
}
```

### 2. Docker Compose Configuration

```yaml
# fulfillment/docker-compose.yml
services:
  fulfillment-event-worker-grpc:
    build:
      context: ..
      dockerfile: fulfillment/Dockerfile.optimized
      args:
        MAIN_PKG: ./cmd/worker
        BIN_NAME: worker
    container_name: fulfillment-event-worker-grpc
    command: ["./worker", "-mode", "event", "-protocol", "grpc", "-conf", "../configs"]
    # Map host 5005 to container 5005 (gRPC port)
    ports:
      - "5005:5005"  # gRPC server for Dapr
    environment:
      - KRATOS_CONF=/app/configs
      - WORKER_MODE=event
      - WORKER_GRPC_PORT=5005
      - WORKER_PROTOCOL=grpc
    volumes:
      - ./configs/config-docker.yaml:/app/configs/config.yaml:ro
    depends_on:
      fulfillment-service:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - microservices
    restart: unless-stopped

  # Dapr sidecar for gRPC worker
  fulfillment-event-worker-grpc-dapr:
    image: daprio/daprd:1.12.0
    container_name: fulfillment_event_worker_grpc_dapr
    command: [
      "./daprd",
      "-app-id", "fulfillment-event-worker-grpc",
      "-app-port", "5005",  # ✅ gRPC port của worker
      "-app-protocol", "grpc",  # ✅ Quan trọng: chỉ định gRPC
      "-dapr-http-port", "3500",
      "-dapr-grpc-port", "50001",
      "-placement-host-address", "dapr-placement:50006",
      "-components-path", "/components",
      "-config", "/config/config-simple.yaml",
      "-log-level", "info"
    ]
    volumes:
      - ../dapr/components:/components:ro
      - ../dapr/config:/config:ro
    depends_on:
      fulfillment-event-worker-grpc:
        condition: service_started
      dapr-placement:
        condition: service_started
      redis:
        condition: service_healthy
    networks:
      - microservices
    restart: unless-stopped
```

### 3. Worker Main Entry Point

```go
// cmd/worker/main.go
func main() {
    flag.StringVar(&workerProtocol, "protocol", "http", "Worker protocol: http|grpc")
    
    // ... load config ...
    
    switch workerProtocol {
    case "grpc":
        // Initialize gRPC worker
        worker, err := event.NewOrderStatusListenerWorkerGRPC(fulfillmentUsecase, logger)
        if err != nil {
            logHelper.Fatalf("Failed to create gRPC worker: %v", err)
        }
        activeWorkers = append(activeWorkers, worker)
        
    case "http":
        // Initialize HTTP worker
        worker := event.NewOrderStatusListenerWorker(fulfillmentUsecase, logger)
        activeWorkers = append(activeWorkers, worker)
        
    default:
        logHelper.Fatalf("Unknown protocol: %s. Supported: http, grpc", workerProtocol)
    }
    
    // Start workers
    // ...
}
```

## So Sánh Chi Tiết: HTTP vs gRPC

### HTTP Callbacks (Hiện Tại)

**Ưu điểm**:
- ✅ Đơn giản, dễ implement
- ✅ Dễ debug (curl, Postman)
- ✅ Không cần gRPC dependencies
- ✅ Port riêng (8080, 8081, etc.)

**Nhược điểm**:
- ⚠️ Performance thấp hơn (~5-10ms overhead)
- ⚠️ Cần HTTP server riêng

**Code**:
```go
// HTTP - Đơn giản
mux := http.NewServeMux()
mux.HandleFunc("/dapr/subscribe", handler)
http.ListenAndServe(":8080", mux)
```

### gRPC Callbacks

**Ưu điểm**:
- ✅ Performance cao hơn (~2-5ms)
- ✅ Type-safe (protobuf)
- ✅ Streaming support
- ✅ Better for high-throughput

**Nhược điểm**:
- ⚠️ Phức tạp hơn (cần gRPC server)
- ⚠️ Khó debug hơn
- ⚠️ Cần Dapr SDK
- ⚠️ Cần cấu hình `app-protocol grpc`

**Code**:
```go
// gRPC - Phức tạp hơn
daprService, _ := daprd.NewService(":5005")
daprService.AddTopicEventHandler(subscription, handler)
daprService.Start() // Blocking
```

## Port Configuration

### HTTP Worker
```yaml
worker:
  ports:
    - "8081:8080"  # HTTP port
dapr:
  command:
    - "-app-port", "8080"
    # app-protocol mặc định là http
```

### gRPC Worker
```yaml
worker:
  ports:
    - "5005:5005"  # gRPC port
dapr:
  command:
    - "-app-port", "5005"
    - "-app-protocol", "grpc"  # ✅ Quan trọng!
```

## Dapr Sidecar Configuration

### Quan Trọng: `app-protocol grpc`

Khi dùng gRPC, **phải** chỉ định `app-protocol grpc` trong Dapr sidecar:

```yaml
dapr:
  command:
    - "-app-id", "worker-grpc"
    - "-app-port", "5005"
    - "-app-protocol", "grpc"  # ✅ Bắt buộc cho gRPC
```

**Nếu không có `app-protocol grpc`**:
- ❌ Dapr sẽ dùng HTTP protocol
- ❌ gRPC server sẽ không nhận được events

## Event Format Handling

### HTTP Callbacks
```go
// HTTP - Parse từ HTTP request body
var daprEvent struct {
    Data OrderStatusChangedEvent `json:"data"`
}
json.NewDecoder(r.Body).Decode(&daprEvent)
```

### gRPC Callbacks
```go
// gRPC - Parse từ TopicEvent
func handler(ctx context.Context, e *common.TopicEvent) (retry bool, err error) {
    // e.Data có thể là map[string]interface{} hoặc []byte
    switch data := e.Data.(type) {
    case map[string]interface{}:
        // Extract data field
    case []byte:
        // Direct JSON bytes
    }
}
```

## Best Practices

### 1. Chọn Protocol Dựa Trên Use Case

**Dùng HTTP khi**:
- ✅ Cần đơn giản, dễ debug
- ✅ Performance không phải ưu tiên
- ✅ Workers không cần high-throughput

**Dùng gRPC khi**:
- ✅ Cần performance cao
- ✅ High-throughput scenarios
- ✅ Đã có gRPC infrastructure

### 2. Port Naming Convention

**HTTP Workers**:
- Container: `8080`, `8081`, etc.
- Host: `8081`, `8082`, etc.

**gRPC Workers**:
- Container: `5005`, `5006`, etc.
- Host: `5005`, `5006`, etc.

### 3. Error Handling

**HTTP**:
```go
// Return HTTP status codes
if err != nil {
    http.Error(w, err.Error(), http.StatusInternalServerError)
    return // Dapr will retry
}
```

**gRPC**:
```go
// Return retry flag
func handler(ctx context.Context, e *common.TopicEvent) (retry bool, err error) {
    if err != nil {
        return true, err // Retry on error
    }
    return false, nil // Success, no retry
}
```

## Migration Path: HTTP → gRPC

### Bước 1: Implement gRPC Worker
```go
workerGRPC, err := NewOrderStatusListenerWorkerGRPC(...)
```

### Bước 2: Update Docker Compose
```yaml
worker:
  ports:
    - "5005:5005"
dapr:
  command:
    - "-app-protocol", "grpc"
```

### Bước 3: Test và Validate
- Test event delivery
- Monitor performance
- Compare với HTTP version

### Bước 4: Switch (Optional)
- Có thể chạy cả 2 versions song song
- Switch khi đã validate

## Tóm Tắt

### ✅ HTTP Callbacks (Hiện Tại):
- **Port**: 8080, 8081, etc.
- **Setup**: Đơn giản (HTTP server)
- **Performance**: ~5-10ms overhead
- **Khuyến nghị**: Dùng cho hầu hết cases

### ✅ gRPC Callbacks:
- **Port**: 5005, 5006, etc.
- **Setup**: Phức tạp hơn (gRPC server + Dapr SDK)
- **Performance**: ~2-5ms (nhanh hơn)
- **Khuyến nghị**: Dùng khi cần performance cao

### ⚠️ Lưu Ý:
- **Phải** chỉ định `app-protocol grpc` trong Dapr sidecar
- gRPC cần Dapr SDK (`github.com/dapr/go-sdk/service/grpc`)
- Port riêng cho mỗi worker (HTTP hoặc gRPC)


# Dapr gRPC Worker - Event Compatibility với Order Service

## ❓ Câu Hỏi: Nếu Dùng gRPC Worker, Có Listen Được Events Từ Order Service (HTTP) Không?

## ✅ Trả Lời: CÓ! Hoàn Toàn Được!

**Dapr Pub/Sub là protocol-agnostic**: Publish và Subscribe có thể dùng **khác protocol** mà vẫn hoạt động bình thường.

## Cách Hoạt Động

### Flow Hiện Tại:

```
1. Order Service (HTTP)
   ↓
   POST /v1.0/publish/pubsub-redis/orders.order.status_changed
   ↓
2. Dapr Sidecar (Order Service)
   ↓
   Lưu vào Redis Streams: pubsub-redis:orders.order.status_changed
   ↓
3. Dapr Sidecar (Fulfillment Worker - gRPC)
   ↓
   Đọc từ Redis Streams
   ↓
   Gọi gRPC callback → Worker nhận events
```

### Quan Trọng:

- ✅ **Order Service publish qua HTTP** → Dapr lưu vào Redis Streams
- ✅ **Worker subscribe qua gRPC** → Dapr đọc từ Redis Streams và gọi gRPC callback
- ✅ **Không có protocol mismatch** vì Dapr handle việc này

## Verification

### 1. Order Service Publish (HTTP)

```go
// order/internal/events/publisher.go
func (p *DaprEventPublisher) PublishEvent(ctx context.Context, topic string, event interface{}) error {
    // Dapr HTTP API
    url := fmt.Sprintf("%s/v1.0/publish/%s/%s", p.daprURL, p.pubsubName, topic)
    // POST http://localhost:3500/v1.0/publish/pubsub-redis/orders.order.status_changed
}
```

**Topic**: `orders.order.status_changed`  
**Pubsub**: `pubsub-redis`

### 2. gRPC Worker Subscribe

```go
// fulfillment/internal/worker/event/order_status_listener_grpc.go
subscription := &common.Subscription{
    PubsubName: "pubsub-redis",  // ✅ Cùng pubsub
    Topic:      "orders.order.status_changed",  // ✅ Cùng topic
    Route:      "/orders.order.status_changed",
}
```

**Topic**: `orders.order.status_changed` ✅  
**Pubsub**: `pubsub-redis` ✅

### 3. Dapr Sidecar Configuration

**Order Service Sidecar** (HTTP publish):
```yaml
order-service-dapr:
  command:
    - "-app-id", "order-service"
    - "-app-port", "80"
    # Không cần app-protocol (default HTTP)
```

**Worker Sidecar** (gRPC subscribe):
```yaml
fulfillment-event-worker-grpc-dapr:
  command:
    - "-app-id", "fulfillment-event-worker-grpc"
    - "-app-port", "5005"
    - "-app-protocol", "grpc"  # ✅ gRPC protocol
```

## Kết Luận

### ✅ Hoàn Toàn Tương Thích

- **Order Service**: Publish qua HTTP → Dapr lưu vào Redis Streams
- **gRPC Worker**: Subscribe qua gRPC → Dapr đọc từ Redis Streams và gọi gRPC callback
- **Không có vấn đề** về protocol mismatch

### Lý Do:

1. **Dapr Pub/Sub là abstraction layer**:
   - Publish: HTTP hoặc gRPC → Dapr lưu vào backend (Redis Streams)
   - Subscribe: Dapr đọc từ backend → Gọi callback qua HTTP hoặc gRPC

2. **Backend (Redis Streams) là protocol-agnostic**:
   - Events được lưu dưới dạng data, không phụ thuộc vào protocol publish/subscribe

3. **Dapr Sidecar handle protocol conversion**:
   - Order sidecar: HTTP → Redis Streams
   - Worker sidecar: Redis Streams → gRPC callback

## Testing

### Test Flow:

1. **Start services**:
   ```bash
   # Order service (HTTP publish)
   docker compose up -d order-service order-service-dapr
   
   # gRPC worker (gRPC subscribe)
   docker compose up -d fulfillment-event-worker-grpc fulfillment-event-worker-grpc-dapr
   ```

2. **Publish event từ Order service**:
   ```bash
   # Order service sẽ publish qua HTTP
   # Event được lưu vào Redis Streams
   ```

3. **Check gRPC worker logs**:
   ```bash
   docker compose logs -f fulfillment-event-worker-grpc
   # Should see: "Received event: topic=orders.order.status_changed"
   ```

## So Sánh: HTTP vs gRPC Subscribe

| Tiêu Chí | HTTP Subscribe | gRPC Subscribe |
|----------|----------------|----------------|
| **Publish Protocol** | ✅ HTTP hoặc gRPC | ✅ HTTP hoặc gRPC |
| **Subscribe Protocol** | HTTP | gRPC |
| **Compatibility** | ✅ Hoàn toàn tương thích | ✅ Hoàn toàn tương thích |
| **Performance** | ~5-10ms | ~2-5ms (nhanh hơn) |

## Best Practice

### Khuyến Nghị:

1. **Services publish qua HTTP** (đơn giản, standardized)
2. **Workers subscribe qua gRPC** (performance cao)
3. **Dapr handle protocol conversion** tự động

### Pattern:

```
Services (HTTP) → Dapr → Redis Streams → Dapr → Workers (gRPC)
```

Đây là pattern **hybrid approach** rất hiệu quả!


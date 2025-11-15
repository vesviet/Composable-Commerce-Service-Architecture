# Dapr HTTP Callbacks - Port Configuration Guide

## ❓ Câu Hỏi: Mỗi Service Cần Port Riêng Để Listen HTTP Callbacks?

## ✅ Trả Lời: Tùy Thuộc Vào Kiến Trúc

### Pattern 1: Services Chính - Dùng Chung HTTP Server (Khuyến Nghị)

**Services chính** (Order, Catalog, Warehouse, etc.) **KHÔNG cần port riêng** cho Dapr callbacks.

#### Cách Hoạt Động:

```go
// Services chính expose HTTP server cho cả API và Dapr callbacks
func NewHTTPServer(...) *krathttp.Server {
    srv := krathttp.NewServer(...)
    
    // API endpoints
    srv.HandleFunc("/api/v1/orders", ...)
    
    // Dapr subscription discovery
    srv.HandleFunc("/dapr/subscribe", eventHandler.DaprSubscribeHandler)
    
    // Dapr event callbacks
    srv.HandleFunc("/dapr/subscribe/order-status-changed", eventHandler.HandleEvent)
    
    return srv
}
```

**Port Configuration**:
- **Container**: Port `80` (chung cho API + Dapr callbacks)
- **Host**: Port riêng cho mỗi service (8004, 8015, etc.)
- **Dapr Sidecar**: `app-port=80` (cùng port với service)

**Ví dụ** (Order Service):
```yaml
order-service:
  ports:
    - "8004:80"  # Host:Container
  environment:
    - DAPR_URL=http://order-service-dapr:3500

order-service-dapr:
  command:
    - "-app-id", "order-service"
    - "-app-port", "80"  # ✅ Cùng port với service HTTP server
    - "-dapr-http-port", "3500"  # Dapr internal port
```

**Lợi ích**:
- ✅ Không cần port riêng cho Dapr callbacks
- ✅ Đơn giản, dễ quản lý
- ✅ Dapr sidecar gọi service qua internal network (không cần expose port)

### Pattern 2: Workers Riêng - Cần Port Riêng

**Workers riêng** (standalone processes) **CẦN port riêng** cho HTTP callbacks.

#### Cách Hoạt Động:

```go
// Worker expose HTTP server riêng chỉ cho Dapr callbacks
func (w *OrderStatusListenerWorker) Start(ctx context.Context) error {
    mux := http.NewServeMux()
    
    // Dapr subscription discovery
    mux.HandleFunc("/dapr/subscribe", w.daprSubscribeHandler)
    
    // Dapr event callbacks
    mux.HandleFunc("/dapr/subscribe/order-status-changed", w.handleEvent)
    
    // Start HTTP server on dedicated port
    http.ListenAndServe(":8080", mux)  // ✅ Port riêng cho worker
}
```

**Port Configuration**:
- **Container**: Port `8080` (riêng cho worker HTTP server)
- **Host**: Port riêng (8081, 8082, etc.)
- **Dapr Sidecar**: `app-port=8080` (port của worker)

**Ví dụ** (Fulfillment Worker):
```yaml
fulfillment-event-worker:
  ports:
    - "8081:8080"  # Host:Container - Port riêng cho worker
  environment:
    - WORKER_HTTP_PORT=8080

fulfillment-event-worker-dapr:
  command:
    - "-app-id", "fulfillment-event-worker"
    - "-app-port", "8080"  # ✅ Port của worker HTTP server
    - "-dapr-http-port", "3500"
```

**Lý do cần port riêng**:
- ⚠️ Worker là process riêng, không có HTTP server chung với service
- ⚠️ Cần expose HTTP server để Dapr gọi callbacks
- ⚠️ Không thể dùng chung port với service chính

## So Sánh 2 Patterns

| Tiêu Chí | Services Chính (Pattern 1) | Workers Riêng (Pattern 2) |
|----------|----------------------------|---------------------------|
| **Port cho Dapr** | ❌ Không cần (dùng chung port 80) | ✅ Cần port riêng (8080, etc.) |
| **HTTP Server** | ✅ Dùng chung với API server | ⚠️ Phải tạo HTTP server riêng |
| **Dapr Sidecar** | ✅ 1 sidecar cho service | ✅ 1 sidecar cho worker |
| **Complexity** | ✅ Đơn giản | ⚠️ Phức tạp hơn |
| **Resource** | ✅ Tiết kiệm (1 HTTP server) | ⚠️ Tốn hơn (2 HTTP servers) |

## Port Mapping Trong Dự Án

### Services Chính (Dùng Chung Port 80)

| Service | Container Port | Host Port | Dapr App Port |
|---------|---------------|-----------|---------------|
| Order | 80 | 8004 | 80 |
| Catalog | 80 | 8015 | 80 |
| Warehouse | 80 | 8008 | 80 |
| Fulfillment | 80 | 8010 | 80 |

**Dapr Sidecar Ports** (Internal, không expose ra host):
- `dapr-http-port`: 3500 (Dapr HTTP API)
- `dapr-grpc-port`: 50001 (Dapr gRPC API)

### Workers Riêng (Port Riêng)

| Worker | Container Port | Host Port | Dapr App Port |
|--------|---------------|-----------|---------------|
| Fulfillment Event Worker | 8080 | 8081 | 8080 |

## Dapr Sidecar Communication

### Quan Trọng: Dapr Sidecar Gọi Service Qua Internal Network

**Dapr sidecar KHÔNG cần port riêng trên host**, vì:

1. **Dapr sidecar và service/worker** chạy trong cùng Docker network
2. **Dapr gọi service** qua internal network: `http://service-name:80`
3. **Chỉ service/worker** cần expose port ra host (nếu cần external access)

**Ví dụ**:
```yaml
# Service và Dapr sidecar trong cùng network
order-service:
  container_name: order-service
  networks:
    - microservices

order-service-dapr:
  container_name: order-service-dapr
  networks:
    - microservices
  # Dapr gọi service qua: http://order-service:80
  # Không cần expose port ra host
```

## Best Practices

### 1. Services Chính: Dùng Chung HTTP Server

✅ **Nên làm**:
```go
// Expose Dapr callbacks trên cùng HTTP server với API
srv.HandleFunc("/dapr/subscribe", ...)
srv.HandleFunc("/api/v1/orders", ...)
```

❌ **Không nên**:
```go
// Tạo HTTP server riêng cho Dapr callbacks
daprServer := http.NewServer(":8080")  // Không cần
```

### 2. Workers Riêng: Port Riêng

✅ **Nên làm**:
```go
// Worker có HTTP server riêng
workerServer := http.NewServer(":8080")
workerServer.HandleFunc("/dapr/subscribe", ...)
```

### 3. Port Naming Convention

**Services chính**:
- Container: `80` (HTTP), `81` (gRPC)
- Host: `80XX` (HTTP), `90XX` (gRPC)

**Workers**:
- Container: `8080`, `8081`, etc.
- Host: `8081`, `8082`, etc.

### 4. Environment Variables

```yaml
# Service chính
environment:
  - DAPR_URL=http://service-name-dapr:3500

# Worker riêng
environment:
  - WORKER_HTTP_PORT=8080
  - DAPR_URL=http://worker-name-dapr:3500
```

## Tóm Tắt

### ✅ Services Chính:
- **KHÔNG cần port riêng** cho Dapr callbacks
- Dùng chung HTTP server (port 80) cho API + Dapr callbacks
- Dapr sidecar gọi qua internal network

### ✅ Workers Riêng:
- **CẦN port riêng** (8080, 8081, etc.)
- Phải tạo HTTP server riêng cho Dapr callbacks
- Dapr sidecar gọi qua internal network

### ⚠️ Lưu Ý:
- Dapr sidecar **KHÔNG cần port riêng trên host**
- Dapr sidecar gọi service/worker qua **internal Docker network**
- Chỉ service/worker cần expose port ra host (nếu cần external access)


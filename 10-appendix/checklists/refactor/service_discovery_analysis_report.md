# Báo Cáo Phân Tích & Code Review: Kiến Trúc Service Discovery (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review cơ chế Service Discovery (Client-side & Server-side) và Dependency Injection liên quan.
**Trạng thái Review:** Lần 1 (Pending Refactor - Theo chuẩn Senior Fullstack Engineer)

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔴 P1] [Architecture / Maintainability] Reinventing the wheel ở tầng gRPC Client:** Rất đáng tiếc, việc cấu hình gRPC Client thủ công vẫn tồn tại dai dẳng ở mọi service (ví dụ: `auth_client.go`, `shipping_client.go`). Dev vẫn liên tục gọi `authPB.NewAuthServiceClient(conn)` tự setup `grpc.DialInsecure` và tự inject `consul.New()`. Việc này vi phạm quy tắc tái sử dụng code (`DRY`), bỏ sót hoàn toàn mớ Circuit Breaker, Retry chuẩn của hệ thống. *Yêu cầu cấu hình lại factory `NewDiscoveryClient` tập trung ở `common/client`.*

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu)*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Framework] Chuẩn hóa Consul Registrar Server-Side:** Lỗi khởi tạo Consul client phân mảnh (P2) ĐÃ ĐƯỢC XÓA BỎ. Quan sát các file `wire.go` của toàn bộ 15++ service (Customer, Order, Shipping...), tất cả đều đã được refactor để ref tới chung một `common/registry/consul.go` (`NewConsulRegistrar`). Điều này giúp thu gọn code khởi tạo server rất nhiều.

## 1. Hiện Trạng Triển Khai (How Service Discovery is Implemented)

Hệ thống đang sử dụng **Hashicorp Consul** làm Service Registry chính kết hợp với framework **Kratos**. 
Mô hình hoạt động hiện tại:
- **Server side:** Khi một service (VD: `customer`) khởi động, nó đọc `CONSUL_ADDRESS` từ env hoặc file config, tạo một `consulClient`, đóng gói vào Kratos `consul.New()` và đưa cho Kratos App gọi `Register()` để tự quảng bá IP/Port của mình lên mạng lưới.
- **Client side:** Khi service A muốn gọi gRPC tới service B (VD: `customer` gọi `auth`), nó khởi tạo một `AuthServiceClient`. Hàm này cũng bốc `CONSUL_ADDRESS`, dựng lại một `consul.New()` resolver, rồi pass vào `grpc.DialInsecure(..., grpc.WithDiscovery(resolver))`.

---

## 2. Các Vấn Đề Lớn Phát Hiện Được (Critical Smells) 🚩

### 🚩 2.1. reinventing the wheel (Tái tạo bánh xe) ở gRPC Client (P1)
**Vấn đề:** 
Đội ngũ kiến trúc (hoặc Core Team) đã viết sẵn một SDK xịn xò tại `common/client/grpc_client.go`. SDK này cấu hình sẵn:
- Circuit Breaker (ống ngắt mạch) chống nghẽn dịch vụ.
- Retry logic với cấu hình Delay và MaxRetries.
- KeepAlive connection (chống đứt kết nối ngầm).
- Connection Pool (tránh thắt cổ chai 1 TCP connection).
- Context Timeout.

**Nhưng thực tế 15+ services KHÔNG SỬ DỤNG HOÀN TOÀN library này.**
Ví dụ, mở file `customer/internal/client/auth/auth_client.go`, ta thấy dev tự viết lại bằng tay: 
- Lệnh `api.NewClient(consulConfig)`
- Lệnh `grpc.DialInsecure(...)`
- Lệnh tự build `circuitbreaker.NewCircuitBreaker(...)`.
- Tự parse cấu hình retry và ngắt mạch bằng tay.

**Hệ luỵ:**
- **Code Duplication Khủng Khiếp:** Mỗi lần một service cần gọi gRPC sang service khác, dev lại phải đi copy/paste lại hàng trăm dòng code boilerplate thiết lập circuit breaker, retry, consul resolver.
- **Mất kiểm soát kiến trúc:** Giả sử mai sau dự án đổi hệ thống Service Discovery từ Consul sang ETCD, hoặc chuyển từ Kratos native circuit breaker sang Istio/Envoy, chúng ta sẽ phải mò vào 15 service, tìm hàng chục file `xxx_client.go` để sửa tay từng dòng `grpc.Dial`.

### 🚩 2.2. Khởi tạo Consul Client phân mảnh (P2)
Tương tự, ở chiều Server Register (file `internal/server/consul.go`), các service cũng đang copy y xì đúc hàm `NewRegistrar(c *commonConfig.ConsulConfig)` gồm 30 dòng lệnh. Lẽ ra hàm này nên nằm ở `common/server/registry.go`.

---

## 3. Bản Chỉ Đạo Refactor Từ Senior (Clean Architecture Roadmap)

### ✅ Giải pháp 1: Gom Server Registrar vào Common Library
Tại thư viện `common`, tạo file `common/registry/consul.go`:
```go
package registry

import (
    "github.com/go-kratos/kratos/contrib/registry/consul/v2"
    "github.com/hashicorp/consul/api"
)

func NewConsulRegistrar(addr string) (registry.Registrar, error) {
    cfg := api.DefaultConfig()
    cfg.Address = addr
    client, err := api.NewClient(cfg)
    if err != nil { return nil, err }
    return consul.New(client), nil
}
```
Tại 15 file `internal/server/consul.go` của các service, xoá bỏ đoạn code dài ngoằn và thay bằng hàm bọc này.

### ✅ Giải pháp 2 (Bắt Buộc): Tái cấu trúc gRPC Client Factories
Bắt buộc mọi gRPC Client phải được khởi tạo từ `common/client`. Cấm dev tự gọi `grpc.Dial` trong mã nguồn của business logic.

Chỉnh sửa `common/client` để hỗ trợ Discovery natively:
```go
// Trong common/client/grpc_factory.go
func NewDiscoveryClient(targetService string, consulAddr string) (*grpc.ClientConn, error) {
    // 1. Tạo Consul Resolver chung ở đây
    // 2. Wrap vào chuẩn gRPC Kratos
    // 3. Trả về Connection đã bọc sẵn Metrics, Retry, Breaker từ config file.
}
```

Nhờ đó, file `auth_client.go` tại các service gọi nhau chỉ còn ngắn gọn đúng 10 dòng:
```go
type AuthServiceClient struct {
    client authPB.AuthServiceClient
}

func NewAuthServiceClient(consulAddr string) (*AuthServiceClient, error) {
    conn, err := commonClient.NewDiscoveryClient("auth", consulAddr)
    if err != nil { return nil, err }
    
    return &AuthServiceClient{
        client: authPB.NewAuthServiceClient(conn), // Mọi Breaker, Timeout đã được bọc ngầm trong conn
    }, nil
}
```
Refactor này sẽ **xoá sổ hoàn toàn** mớ script rác (tự parse Consul, tự config Timeouts, tự setup Breaker) ra khỏi business service. Đảm bảo Core Team kiểm soát sinh mệnh network của toàn cụm.

# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Service Discovery

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review cơ chế Service Discovery (Client-side & Server-side) và Dependency Injection liên quan.  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P1] [Architecture/Maintainability] Reinventing the Wheel Ở Tầng gRPC Client:** Rất đáng tiếc, việc cấu hình gRPC Client thủ công vẫn tồn tại dai dẳng ở mọi service (ví dụ: `auth_client.go`, `shipping_client.go`). Dev vẫn liên tục gọi cấu trúc Boilerplate `grpc.DialInsecure` và tự inject `consul.New()`. Việc này vi phạm quy tắc tái sử dụng code (DRY), bỏ sót hoàn toàn mớ Circuit Breaker, Retry chuẩn của hệ thống đã được Core Team dọn sẵn. **Yêu cầu:** Lập tức cấu hình lại factory `NewDiscoveryClient` (thuộc thư viện Lõi `common/client`) tập trung, ép tất cả các client nội bộ đi qua ngõ này.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Framework] Chuẩn Hóa Consul Registrar Server-Side:** Lỗi khởi tạo Consul client phân mảnh (P2) ĐÃ ĐƯỢC XÓA BỎ. Quan sát các file `wire.go` của toàn bộ 15++ service (Customer, Order, Shipping...), tất cả đều đã được refactor để ref tới chung một `common/registry/consul.go` (`NewConsulRegistrar`). Điều này giúp thu gọn code khởi tạo server rất nhiều.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Hệ thống sử dụng **Hashicorp Consul** làm Service Registry chính kết hợp với framework **Kratos**. Mô hình hoạt động hiện tại (Server Side) Rất Chuẩn:
- Khi một service (VD: `customer`) khởi động, nó đọc `CONSUL_ADDRESS` từ env/config, gọi đến hàm tạo `NewConsulRegistrar` duy nhất từ thư viện Lõi, rồi đưa cho Kratos App `Register()`. Dọn dẹp cục bộ rất sạch, 100% service đăng ký đồng bộ.

### 2. Sự Lệch Chuẩn Trầm Trọng: Tái Tạo Bánh Xe Ở gRPC Client (P1) 🚩
Đội ngũ kiến trúc (hoặc Core Team) **đã viết sẵn** một SDK cực Xịn tại `common/client/grpc_client.go`. SDK này cấu hình sẵn:
- **Circuit Breaker** (Rất quan trọng).
- **Retry Logic.**
- **Connection Pool & KeepAlive.**

**Vấn đề:** 15+ services **KHÔNG SỬ DỤNG** thư viện này!
Trong file `customer/internal/client/auth/auth_client.go`, dev tự xử lý bằng tay:
```go
// Tự cài Consul Resolver...
client, _ := api.NewClient(consulConfig)
// Tự setup Dial thủ công...
grpc.DialInsecure(
    fmt.Sprintf("discovery:///%s", "auth"),
    grpc.WithDiscovery(consul.New(client)),
// ... Quên sạch Circuit Breaker của Core Team!
```

**Hệ luỵ rủi ro:**
- **Code Duplication Khủng Khiếp:** Copy/paste Boilerplate Consul + Circuit breaker logic hàng chục dòng.
- **SPOF Hệ Thống (Single Point of Failure):** Dịch vụ B rớt mạng, dịch vụ A gọi sang bị treo rục TCP Connection do không có ống ngắt mạch, dẫn đến A sập lây chuyền.
- **Rối loạn Infra:** Mai sau chuyển hạ tầng từ Consul sang ETCD, ta sẽ phải đi vá 15 dự án.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Bắt buộc mọi gRPC Client phải được khởi tạo từ `common/client`. Cấm dev tự gọi `grpc.Dial` trong mã nguồn của business logic.

**Bước 1: Quy Hoạch `common/client/grpc_factory.go` (Discovery Client)**
```go
func NewDiscoveryClient(targetService string, consulAddr string) (*grpc.ClientConn, error) {
    // 1. Tạo Consul Resolver chung ở đây
    // 2. Wrap vào chuẩn gRPC Kratos
    // 3. Bơm đủ bộ MiddleWare (Tracing, Context, Breaker, Retry)
    // 4. Trả về Connection!
}
```

**Bước 2: Dọn mã rác của Service Client:**
Toàn bộ `auth_client.go` hay `billing_client.go` ở các dự án rút gọn lại thành ĐÚNG 5 dòng:
```go
func NewAuthServiceClient(consulAddr string) (*AuthServiceClient, error) {
    // 1 Dòng gọi từ SDK Core, giải quyết mọi nỗi đau Circuit Breaker
    conn, err := commonClient.NewDiscoveryClient("auth", consulAddr) 
    if err != nil { return nil, err }
    
    return &AuthServiceClient{ client: authPB.NewAuthServiceClient(conn) }, nil
}
```
Mọi PR commit đoạn mã Dial gRPC rác vào dự án trực tiếp sẽ bị Auto-Reject.

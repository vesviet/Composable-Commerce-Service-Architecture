# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Service Discovery

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review cơ chế Service Discovery (Client-side & Server-side) và Dependency Injection liên quan.  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - CLIENT RÁC TRÀN LAN)

---

## 🚩 PENDING ISSUES (Unfixed - KHẨN CẤP)
- **[🚨 P0] [Architecture/Maintainability] Reinventing the Wheel Ở Tầng gRPC Client:** Rất đáng tiếc, lệnh quét mã nguồn vẫn tìm ra hằng hà sa số các tệp `*client.go` gọi `grpc.DialInsecure` thủ công (`shipping/internal/client/catalog_grpc_client.go`, `order/internal/data/grpc_client/shipping_client.go`, v.v.). Dev CỐ TÌNH tự cấu hình Consul Resolver và bỏ qua toàn bộ mớ Circuit Breaker, Retry chuẩn của Core. **Yêu cầu Khẩn:** Lập tức xóa trắng các tệp local Client. Ép tất cả các service client nội bộ đi qua ngõ `common/client`.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Framework] Chuẩn Hóa Consul Registrar Server-Side:** Lỗi khởi tạo Consul client phân mảnh (P2) ĐÃ ĐƯỢC XÓA BỎ. Quan sát các file `wire.go` của toàn bộ 15++ service (Customer, Order, Shipping...), tất cả đều đã được refactor để ref tới chung một `common/registry/consul.go` (`NewConsulRegistrar`). Điều này giúp thu gọn code khởi tạo server rất nhiều.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Hệ thống sử dụng **Hashicorp Consul** làm Service Registry chính kết hợp với framework **Kratos**. Mô hình hoạt động hiện tại (Server Side) Rất Chuẩn:
- Khi một service khởi động, nó đọc `CONSUL_ADDRESS` từ env/config, gọi đến hàm tạo `NewConsulRegistrar` duy nhất từ thư viện Lõi, rồi đưa cho Kratos App `Register()`. Dọn dẹp cục bộ rất sạch, 100% service đăng ký đồng bộ.

### 2. Sự Lệch Chuẩn Trầm Trọng: Tái Tạo Bánh Xe Ở gRPC Client (Lỗi P0 Hard-Blocker) 🚩
Đội ngũ kiến trúc (hoặc Core Team) **đã viết sẵn** một SDK cực Xịn tại `common/client/grpc_client.go`. SDK này cấu hình sẵn:
- **Circuit Breaker** (Rất quan trọng).
- **Retry Logic.**
- **Connection Pool & KeepAlive.**

**Vấn đề:** Các services **CHỐNG MỆNH LỆNH** KHÔNG SỬ DỤNG thư viện này!
Trong file `shipping/internal/client/...`, dev tiếp tục xử lý bằng tay:
```go
// Tự cài Consul Resolver...
client, _ := api.NewClient(consulConfig)
// Tự setup Dial thủ công...
grpc.DialInsecure(
    fmt.Sprintf("discovery:///%s", "catalog"),
    grpc.WithDiscovery(consul.New(client)),
// ... Quên sạch Circuit Breaker của Core Team!
```

**Hệ luỵ rủi ro:**
- **Code Duplication Khủng Khiếp:** Copy/paste Boilerplate Consul + Circuit breaker logic hàng chục dòng.
- **SPOF Hệ Thống (Single Point of Failure):** Catalog rớt mạng, luồng Shipping chết TCP Connection chờ Request Timeout thay vì nhả Fail Fast. Hệ thống sẽ Domino sụp đổ theo.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Cấm vĩnh viễn hành vi tự gọi `grpc.Dial` trong thư mục `internal` của service.
Giới thiệu 1 factory duy nhất từ library:

```go
func NewDiscoveryClient(targetService string, consulAddr string) (*grpc.ClientConn, error) {
    // 1. Tạo Consul Resolver chung ở đây
    // 2. Wrap vào chuẩn gRPC Kratos
    // 3. Bơm đủ bộ MiddleWare (Tracing, Context, Breaker, Retry)
    // 4. Trả về Connection!
}
```

Toàn bộ `shipping_client.go` ở các dự án phải rút gọn lại thành ĐÚNG 5 dòng:
```go
func NewCatalogServiceClient(consulAddr string) (*CatalogServiceClient, error) {
    conn, err := commonClient.NewDiscoveryClient("catalog", consulAddr) 
    if err != nil { return nil, err }
    return &CatalogServiceClient{ client: catalogPB.NewCatalogServiceClient(conn) }, nil
}
```
Mọi Pull Request sau ngày hôm nay commit đoạn mã `Dial` gRPC rác vào dự án trực tiếp sẽ chịu kỷ luật Cảnh Cáo.

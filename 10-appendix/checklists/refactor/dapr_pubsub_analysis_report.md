# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Dapr PubSub (Event-Driven)

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review cách các microservice giao tiếp Bất Đồng Bộ (Async) thông qua Dapr Pub/Sub.  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P1] [Resilience/Architecture] Warehouse Service Gọi Thẳng Dapr SDK Raw:** Kiểm tra codebase cho thấy file `warehouse/internal/data/storage.go` vẫn ngoan cố gọi `dapr.NewClient()` thay vì sử dụng cấu trúc Publisher bọc sẵn (`common/events/dapr_publisher_grpc.go`). Điều này vứt bỏ đi lớp Circuit Breaker và Retry được quy hoạch từ chung dự án, có rủi ro chết dây chuyền nếu Dapr sidecar gặp sự cố mạng. **Yêu cầu:** Warehouse buộc phải refactor, dùng chuẩn DI (Wire) truyền `events.EventPublisher` từ common vào Storage/UseCase.
- **[🔵 P2] [Clean Code/Over-Engineering] Vẫn Giữ Các Local Wrapper Dư Thừa Tại Location:** Dù Location service đã bỏ dùng raw client, nó lại chế ra object trung gian `DaprPublisher` nằm ở `location/internal/event/publisher.go` chỉ để wrap lại `commonEvents.EventPublisher`. Việc đẻ ra class trung gian không thêm logic business nào là dư thừa và làm phình to Codebase. **Yêu cầu:** Xóa hẳn file này, Inject thẳng interface của common vào tầng Biz.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Resilience] Kỷ Luật Hóa Shipping & Location Service:** `shipping` đã xóa bỏ file rác `dapr_client.go`, và `location` đã ngưng khởi tạo dapr raw. Qua đó chặn bớt điểm yếu SPOF (Single Point of Failure) khi Dapr sidecar restart.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Hệ thống thiết kế xoay quanh kiến trúc **Event-Driven** sử dụng sidecar **Dapr** một cách bài bản ở tầng Core:
- **`DaprEventPublisherGRPC` (`common/events/dapr_publisher_grpc.go`):** Giao tiếp qua gRPC hiệu năng cao. Tích hợp sẵn **Circuit Breaker** vô cùng đắt giá (chống nghẽn khi dapr down), tự động **Retry**, và fallback NoOp ở local.
- **`ConsumerClient` (`dapr_consumer.go`):** Tự động tạo gRPC Listener để hứng Event CloudEvents sang chuẩn Go Object, bơm sẵn Open-Telemetry tracing qua headers.

### 2. Lỗ Hổng Từ Các Service Chạy Lệch Chuẩn (P1) 🚩
Mặc dù đã có `DaprEventPublisherGRPC` xịn xò bảo vệ sinh mạng API, một số Service Dev lại tạt gáo nước lạnh bằng cách gọi thẳng Raw Dapr SDK, ví dụ:
```go
// Tại warehouse/internal/data/storage.go
client, err := dapr.NewClient() 
```
**Hậu quả khôn lường trên Production:**
- Khi Dapr Sidecar bị sập hoặc nghẽn mạng cục bộ, Code của `Order` service (đang xài chuẩn thư viện `common/events`) sẽ tự động nhả Circuit Breaker, trả lỗi nhanh (Fail Fast), cứu sống goroutines.
- Trong khi đó, Code của `Warehouse` service gọi thẳng `daprClient.PublishEvent` sẽ dính timeout treo cứng, ăn sập Goroutine pool, gây OOM (Out of Memory) tàn phá vùng nhớ Node k8s.
- Hơn nữa, việc rải Raw SDK (vendor cụ thể) vào tầng Data/Biz vi phạm quy tắc cốt lõi của Clean Architecture.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Phải thiết quân luật để ép các service sử dụng Interface từ thư viện Lõi.

**Bước 1: Inject Interface, Xóa Code Create Raw Client:**
Tại file Wire DI (`provider.go`) của các Service vi phạm (Warehouse, Location), gọi trực tiếp Factory từ `common`:
```go
import "gitlab.com/ta-microservices/common/events"

func NewEventPublisher(logger log.Logger) (events.EventPublisher, error) {
    // Inject DaprPublisher từ Core. Mọi cấu hình Circuit Breaker/Retry được bọc sẵn.
    return events.NewDaprEventPublisherGRPC(nil, logger)
}
```

**Bước 2: Quét Dọn Rác Architecture:**
Phải xóa trắng các file rác trung gian để ngăn Junior copy-paste sau này:
- Xóa `warehouse/internal/data/storage.go` (Phần tự build Publisher).
- Xóa `location/internal/event/publisher.go`.

Thay thế mọi constructor injection ở các tầng UseCase/Service thành interface `events.EventPublisher` thay vì `*dapr.Client` hay abstract tự chế.

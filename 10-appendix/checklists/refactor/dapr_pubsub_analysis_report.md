# Báo Cáo Phân Tích & Code Review: Kiến Trúc Dapr PubSub (Event-Driven) (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review cách các microservice giao tiếp Bất Đồng Bộ (Async) thông qua Dapr Pub/Sub.
**Trạng thái Review:** Lần 1 (Pending Refactor - Theo chuẩn Senior Fullstack Engineer)

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔴 P1] [Resilience / Architecture] Warehouse Service gọi thẳng Dapr SDK raw:** Kiểm tra codebase cho thấy file `warehouse/internal/data/storage.go` vẫn ngoan cố gọi `dapr.NewClient()` thay vì sử dụng cấu trúc Publisher bọc sẵn (`common/events/dapr_publisher_grpc.go`). Điều này vứt bỏ đi lớp Circuit Breaker và Retry từ chung dự án. *Yêu cầu: Warehouse buộc phải refactor, dùng chuẩn DI (Wire) truyền `events.EventPublisher` từ common vào Storage/UseCase.*
- **[🔵 P2] [Clean Code] Vẫn giữ các Local Wrapper dư thừa:** Dù Location service đã fix P1 (không dùng url raw nữa), nó lại chế ra object trung gian `DaprPublisher` nằm ở `location/internal/event/publisher.go` chỉ để wrap lại `commonEvents.EventPublisher`. Việc đẻ ra class trung gian không thêm logic business nào là dư thừa. *Yêu cầu (Nice to have): Xóa hẳn file này, Inject thẳng interface của common vào tầng Biz.*

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu)*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Resilience] Kỷ luật hóa Shipping & Location Service:** `shipping` đã xóa bỏ file rác `dapr_client.go`, và `location` đã ngưng khởi tạo dapr raw. Qua đó chặn bớt điểm yếu SPOF (Single Point of Failure) khi Dapr sidecar restart.

## 1. Hiện Trạng Triển Khai (How Event-Driven Architecture is Implemented)

Hệ thống đang thiết kế xoay quanh kiến trúc **Event-Driven** cực kỳ mạnh mẽ sử dụng sidecar **Dapr**.
- **Tầng Core (Rất Tốt):** Đội ngũ kiến trúc đã xây dựng package `common/events` cực kỳ xịn xò.
  - `DaprEventPublisherGRPC` (`dapr_publisher_grpc.go`): Giao tiếp với Dapr Sidecar qua giao thức gRPC (nhanh hơn HTTP Rest rất nhiều). Nó có tích hợp sẵn **Circuit Breaker** (chống nghẽn khi dapr down), tự động **Retry**, và hỗ trợ fallback NoOp khi tắt Dapr ở local.
  - `ConsumerClient` (`dapr_consumer.go`): Tự động tạo gRPC Listener để hứng Event từ PubSub, parse payload CloudEvents xịn xò sang Object, và ném open-telemetry tracing cực đầy đủ.

---

## 2. Các Vấn Đề Lớn Phát Hiện Được (Critical Smells) 🚩

### 🚩 2.1. reinventing the wheel ở Tầng Publisher (P1)
**Vấn đề:** 
Mặc dù đã có `DaprEventPublisherGRPC` đồ sộ ở tầng `common`, nhưng một số Service lại tiếp tục thói quen "tự xử bừa phứa" bằng cách gọi thẳng raw Dapr SDK, vứt bỏ toàn bộ lớp áo giáp Circuit Breaker & Retry.

**Các tội phạm tìm thấy:**
1. **Warehouse Service:** (`warehouse/internal/data/storage.go`)
   ```go
   client, err := dapr.NewClient()
   ```
2. **Shipping Service:** (`shipping/internal/data/dapr_client.go`)
   ```go
   client, err := dapr.NewClient()
   ```
3. **Location Service:** (`location/internal/event/publisher.go`)
   ```go
   client, err := dapr.NewClientWithAddress(daprEndpoint)
   ```
4. **Common-Operations:** (`common-operations/internal/event/publisher.go`)

**Hệ luỵ nhãn tiền:**
Khi Dapr Sidecar bị sập hoặc nghẽn mạng cục bộ:
- Code của `Order` service (đang xài chuẩn thư viện `common/events`) sẽ tự động nhả Circuit Breaker, trả lỗi nhanh (Fail Fast), cứu sống API của Order. Outbox Worker sẽ gom event lại để quăng sau.
- Trong khi đó, Code của `Warehouse` service gọi thẳng `daprClient.PublishEvent` sẽ dính timeout treo cứng Goroutine. Gây OOM (Out of Memory) hoặc sập lây chuyền toàn tuyến API.

### 🚩 2.2. Sự Thiếu Nhất Quán Về Tầng Giao Tiếp (Missing Abstraction - P2)
Thay vì inject interface trung lập `events.EventPublisher` từ package `common` xuống tầng Biz layer, các service `warehouse`, `shipping` đang truyền thẳng cái object `dapr.Client` thuộc về vendor Github vào UseCase của mình. Điều này vi phạm quy tắc cơ bản của Clean Architecture (Tầng Domain không được mix mã nguồn Infra/Vendor).

---

## 3. Bản Chỉ Đạo Refactor Từ Senior (Clean Architecture Roadmap)

Để giải quyết vấn đề rò rỉ (leak) logic Publish Events, chúng ta cần mạnh tay dọn dẹp các service cứng đầu.

### ✅ Giải pháp: Ép tất cả các service sử dụng interface Publisher của Common.

**B1: Tại file Wire DI (`provider.go`) của các Service vi phạm (Warehouse, Shipping, Location):**
Xoá sạch code tạo `dapr.NewClient()`. Gọi trực tiếp Factory từ `common`:
```go
import "gitlab.com/ta-microservices/common/events"

func NewEventPublisher(logger log.Logger) (events.EventPublisher, error) {
    // Inject DaprPublisher từ Core. Mọi cấu hình Circuit Breaker/Retry/gRPC được load tự động.
    return events.NewDaprEventPublisherGRPC(nil, logger)
}
```

**B2: Xóa bỏ Code Rác:**
Xóa các file rác sau đi để tránh tụi Junior/Dev sau này copy code:
- Xóa `shipping/internal/data/dapr_client.go`
- Xóa `warehouse/internal/data/storage.go` (Phần Publisher)
- Xóa `location/internal/event/publisher.go`

Thay thế mọi constructor injection ở các tầng UseCase/Service thành `events.EventPublisher` thay vì `dapr.Client`. 

*(Điều này không chỉ giúp Code Coverage tăng lên do dùng lại Common Lib mà còn giúp hệ thống chống chịu lỗi (Resilience) trước các đợt sập mạng Dapr Sidecar ở Prod)*.

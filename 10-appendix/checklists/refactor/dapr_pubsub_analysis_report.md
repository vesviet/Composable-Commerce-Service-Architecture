# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Dapr PubSub (Event-Driven)

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review cách các microservice giao tiếp Bất Đồng Bộ (Async) thông qua Dapr Pub/Sub.  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - Nửa vời, Đã fix một phần)

---

## 🚩 PENDING ISSUES (Unfixed - CẦN ACTION)
- **[🔵 P2] [Clean Code/Over-Engineering] Vẫn Giữ Các Local Wrapper Dư Thừa Tại Location:** Dù Location service đã bỏ dùng raw client, nó lại NGANG NHIÊN chế ra object trung gian `DaprPublisher` nằm ở `location/internal/event/publisher.go` chỉ để wrap lại `commonEvents.EventPublisher`. Việc đẻ ra class trung gian không thêm logic business nào là dư thừa và làm phình to Codebase. **Yêu cầu (Lần 2):** Xóa hẳn file này, Inject thẳng interface của common vào tầng Biz giống hệt Order và Payment đang làm.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Resilience/Architecture] Xóa Sổ Raw Client Tại Warehouse:** Báo cáo cũ chỉ ra `warehouse/internal/data/storage.go` gọi thẳng `dapr.NewClient()`. Hiện tại quét nguồn phát hiện kho đã đổi sang dùng DI (Wire) truyền qua biến. Khả năng chịu tải qua Circuit Breaker đã được phục hồi.
- **[FIXED ✅] [Resilience] Kỷ Luật Hóa Shipping Service:** `shipping` đã xóa bỏ file rác `dapr_client.go`. Chặn bớt điểm yếu SPOF khi Dapr sidecar down.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Hệ thống thiết kế xoay quanh kiến trúc **Event-Driven** sử dụng sidecar **Dapr** một cách bài bản ở tầng Core:
- **`DaprEventPublisherGRPC` (`common/events/dapr_publisher_grpc.go`):** Giao tiếp qua gRPC hiệu năng cao. Tích hợp sẵn **Circuit Breaker** vô cùng đắt giá (chống nghẽn khi dapr down), tự động **Retry**, và fallback NoOp ở local.
- **`ConsumerClient` (`dapr_consumer.go`):** Tự động tạo gRPC Listener để hứng Event CloudEvents sang chuẩn Go Object, bơm sẵn Open-Telemetry tracing qua headers.

### 2. Sự Lệch Chuẩn Từ Kỹ Sư Location (P2)
Mặc dù Core Team làm rất tốt, kĩ sư của Location service tự viết một Wrapper mỏng tang bọc lại Interface Core.
Tại sao đây là Code Rác?
- Nó không add thêm log, không map DTO, không check lỗi mới. 100% là pass-through function.
- Việc phải define Type mới `DaprPublisher` khiến Codebase bị rác và làm rối mắt Dev mới vào dự án. Cần xoá ngay tệp `location/internal/event/publisher.go`.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Ngăn Junior copy-paste sau này:
- Xóa `location/internal/event/publisher.go`.
- Sửa lại `wire.go` đổi injection thành Interface của core team.
Thay thế mọi constructor injection ở các tầng UseCase/Service thành interface `events.EventPublisher`. Lệnh này cấm trì hoãn.

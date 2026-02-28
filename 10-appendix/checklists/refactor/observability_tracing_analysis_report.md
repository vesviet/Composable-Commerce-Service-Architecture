# 📋 Báo Cáo Phân Tích & Code Review: Observability, Tracing & Logging

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Đánh giá luồng OpenTelemetry (Tracing), khả năng giám sát vết (Traceparent propagation), và tiêu chuẩn Logging toàn hệ thống.  
**Trạng thái Review:** Đã Review - Cần Refactor Khẩn Cấp  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P1] [Observability/Architecture] Đứt Gãy Tracing Tại Luồng Transactional Outbox:** Kiểm tra lại codebase (`payment/internal/biz`), mặc dù field `Traceparent` đã được khai báo trong struct `OutboxEvent`, hoàn toàn không có dòng code nào xử lý việc trích xuất `traceparent` từ Context hiện tại lưu vào DB khi Insert. Hậu quả là Dapr Outbox Worker khi quét DB sẽ tạo ra một TraceID hoàn toàn mới, làm đứt đoạn khả năng truy vết End-to-End từ API xuống tới background job. **Yêu cầu:** Bắt buộc inject `ExtractTraceparent(ctx)` vào mọi payload trước khi gọi `outboxRepo.Save()`.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Observability/Clean Code] Vá Lỗi Mất TraceID Trên Log Centralized Kibana (P0 Cũ):** Sai lầm nghiêm trọng trước đó (cố gắng parse OpenTelemetry context từ framework Gin tàn dư thay vì dùng chuẩn Kratos Logger) ĐÃ ĐƯỢC XÓA BỎ. File rác `common/middleware/logging.go` đã bị triệt tiêu. Đồng thời, cấu hình tại `payment/cmd/payment/main.go` hiện tại đã bơm đúng `tracing.TraceID()` và `tracing.SpanID()` vào StdLogger thông qua `log.With()`. Toàn bộ log Json bắn ra Kibana/Loki giờ đã có liên kết ID truy vết tuyệt đối.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Phân Tích Hiện Trạng Tracing (OpenTelemetry)

Dựa trên tài liệu chuẩn `common/docs/trace-propagation-standard.md` và mã nguồn, hệ thống đang phụ thuộc mạnh mẽ vào Dapr Sidecar để truyền Context.

#### 1.1. Synchronous Flow (HTTP / gRPC) - Làm Rất Tốt
- **Thực tế:** Dapr tự động làm việc này thông qua annotation `dapr.io/config: tracing-config` trên Pods. W3C `traceparent` được tiêm thẳng vào gRPC Metadata/HTTP Header. Kratos bắt được và vẽ lên Jaeger. Dev Go **không cần đụng 1 dòng code**. Hoãn mỹ.

#### 1.2. Asynchronous Flow (Dapr PubSub) - Làm Tốt
- **Thực tế:** Dapr tự động bơm `traceparent` vào chuẩn CloudEvents envelope. Việc truy vết luồng sự kiện Pub/Sub diễn ra trơn tru, liên mạch.

#### 1.3. Lỗ Hổng Tracing Điểm Chí Tử Ở Luồng Outbox (P1) 🚩
- **Kỳ vọng:** Khi Order Service lưu một sự kiện vào bảng Outbox Postgres (chờ tới lượt Worker gửi đi), nó **bắt buộc** phải ghim kèm `Traceparent` của luồng Request gốc rễ. Để khi Outbox Worker thức dậy xách event bắn đi, nó sẽ ghép lại `Traceparent` đó. Nhờ vậy, Jaeger mới nối được mấu nối từ lúc User "Bấm Đặt Hàng" cho tới khi "Gửi Email Thành Công" (End to End).
- **Sự cố tìm thấy:** Mặc dù Struct `outbox.Event` có sẵn field `Traceparent`, khi review mã nguồn tạo Outbox ở Order/Payment, Backend Devs **hoàn toàn quên** gọi hàm trích xuất `extractTraceparent(ctx)` để gán vào Struct trước khi `Save()` xuống database. 
- **Kết quả đau đớn:** Chuỗi Tracing bị đứt gãy làm 2 tại Outbox DB. Một Trace dừng lại ở đoạn SaveDB. Một Trace hoàn toàn ảo sinh ra ở Worker. Mất vết điều tra!

### 2. Sự Cố Rác Logging Cũ Hướng Trái Kratos (Đã Fix)
- Dự án dùng framework lõi là Kratos, nhưng kiến trúc sư cũ nào đó đã "đi đêm" mang rác Middleware của Gin vào `common/middleware/logging.go`.
- Code này cố dịch ngược SpanContext bằng `trace.SpanFromContext(*gin.Context.Request.Context())` - Trong khi Kratos Injector hoàn toàn không nhét Span vào đó.
- **Hậu quả cũ:** Log đẩy lên Kibana Trắng Bóc field `trace_id`. Tech Lead và SysAdmin bị "mù thính giác" trên Production. Lỗi cực đoan P0 này đã được Core Team thanh lọc và triệt tiêu trong đợt refactor gần nhất.

### 3. Giải Pháp Chỉ Đạo Từ Senior
1. **Dập Tắt Nguy Cơ Đứt Gãy Outbox (P1):** Ép tất cả các repository đang ghi đè vào bảng `event_outbox` (như Order, Payment) mở code lên, sửa lại object Insert: phải kèm theo giá trị sinh ra từ hàm `extractTraceparent(ctx)`. Yêu cầu QA mở Postman test End-to-End và nhìn trên giao diện Jaeger để verify xem luồng Trace đã nối gân lại với nhau chưa.
2. **Kỷ Luật Logging Kratos:** Đánh sập toàn bộ các luồng lén xài logrus/zap local. Các Microservice phải tuân thủ dùng chuẩn Kratos interface `log.Logger`. Tại hàm `main.go`, luôn phải tuân theo thủ thuật wrap mạnh mẽ: `logger = log.With(logger, "trace_id", tracing.TraceID(), "span_id", tracing.SpanID())`. Khóa chết field này lên mọi dòng log của Json formatter. Mọi PR (Pull Request) thiếu xót lập tức Reject.

# 📋 Báo Cáo Phân Tích & Code Review: Observability, Tracing & Logging

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Đánh giá luồng OpenTelemetry (Tracing), khả năng giám sát vết (Traceparent propagation), và tiêu chuẩn Logging toàn hệ thống.  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - NGUY CƠ ĐỨT TRACING OUTBOX VẪN CÒN)

---

## 🚩 PENDING ISSUES (Unfixed - KHẨN CẤP)
- **[🚨 P0] [Observability/Architecture] Đứt Gãy Tracing Tại Luồng Transactional Outbox Chưa Được Vá:** Kiểm tra `payment/internal/biz/*` (Thanh toán qua Ví điện tử, COD, Bank Transfer...), DEV đã wrap logic Update DB + Lưu Outbox vào chung một `txManager`. Tuy nhiên, HOÀN TOÀN KHÔNG trích xuất Context Tracing (`extractTraceparent(ctx)`) để nhồi vào payload `OutboxEvent`. Hậu quả: Chuỗi Trace bị chặt đứt làm đôi ở TẤT CẢ giao dịch thanh toán. Lệnh quét log kibana/loki sẽ bị mù khi tracking Async Outbox. **Yêu cầu (Hard-Blocker):** DEV thanh toán lập tức nhúng hàm Extract trace ID vào trước khi gõ hàm DB Save của bảng outbox.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Observability/Clean Code] Vá Lỗi Mất TraceID Trên Log Centralized Kibana (P0 Cũ):** Sai lầm nghiêm trọng trước đó (cố gắng parse OpenTelemetry context từ framework Gin tàn dư thay vì dùng chuẩn Kratos Logger) ĐÃ ĐƯỢC XÓA BỎ. Cấu hình tại `payment/cmd/payment/main.go` hiện tại đã bơm đúng `tracing.TraceID()` và `tracing.SpanID()` vào StdLogger thông qua `log.With()`. Toàn bộ log Json bắn ra Kibana/Loki giờ đã có liên kết ID truy vết tuyệt đối.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Phân Tích Hiện Trạng Tracing (OpenTelemetry)

Dựa trên tài liệu chuẩn `common/docs/trace-propagation-standard.md` và mã nguồn, hệ thống đang phụ thuộc mạnh mẽ vào Dapr Sidecar để truyền Context.

#### 1.1. Synchronous Flow (HTTP / gRPC) - Làm Rất Tốt
- **Thực tế:** Dapr tự động làm việc này thông qua annotation `dapr.io/config: tracing-config` trên Pods. W3C `traceparent` được tiêm thẳng vào gRPC Metadata/HTTP Header. Kratos bắt được và vẽ lên Jaeger. Dev Go **không cần đụng 1 dòng code**.

#### 1.2. Asynchronous Flow (Dapr PubSub) - Làm Tốt
- **Thực tế:** Dapr tự động bơm `traceparent` vào chuẩn CloudEvents envelope. Việc truy vết luồng sự kiện Pub/Sub bình thường diễn ra trơn tru.

#### 1.3. Lỗ Hổng Tracing Điểm Chí Tử Ở Luồng Outbox (P0) 🚩
- **Kỳ vọng:** Khi Payment Service lưu một sự kiện vào bảng Outbox Postgres (chờ tới lượt Worker gửi đi), nó **bắt buộc** phải ghim kèm `Traceparent` của luồng Request gốc rễ. Để khi Outbox Worker thức dậy xách event bắn đi, nó sẽ ghép lại `Traceparent` đó.
- **Sự cố tìm thấy (Scan Tình Trạng):** Hàm lưu Outbox (Vd: Wallet payment, Bank Transfer, COD) hiện đang push thẳng Raw Data vào hàng đợi DB. Backend Devs **hoàn toàn lờ đi** luồng gán Traceparent.
- **Kết quả đau đớn:** Chuỗi Tracing bị đứt gãy làm 2 tại Outbox DB. Một Trace dừng lại ở đoạn SaveDB. Một Trace hoàn toàn ảo sinh ra ở Worker. Khách hàng báo rớt bill, Trace ngắt ngang xương, Engineer bối rối không biết track lỗi ở đâu.

### 2. Sự Cố Rác Logging Cũ Hướng Trái Kratos (Đã Fix Thành Công)
- Kiến trúc sư cũ mang rác Middleware của Gin vào `common/middleware/logging.go`.
- Code này cố dịch ngược SpanContext bằng `trace.SpanFromContext(*gin.Context.Request.Context())`
- **Tình Phỉ:** Tech Lead và SysAdmin bị "mù thính giác" trên Production. Lỗi cực đoan này đã bị Core Team gạch xoá thành công, framework Kratos Logger lên ngôi thống trị lại mã nguồn.

### 3. Giải Pháp Chỉ Đạo Từ Senior
1. **Dập Tắt Nguy Cơ Đứt Gãy Outbox (P0):** Bắt quả tang 5 tệp trong `payment/internal/biz` vi phạm. DEV hãy sửa dòng tạo object `OutboxEvent`: `Traceparent: tracing.ExtractTraceparent(ctx)`. Tự lên Postman bắn 1 bill, chụp ảnh màn hình giao diện Jaeger gửi Core Team làm bằng chứng đã thông luồng End-to-End. Lệnh Cấm Release được ban bố chừng nào lổ hổng này còn mở toang hác.

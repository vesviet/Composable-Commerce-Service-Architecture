# Báo Cáo Phân Tích: Observability, Tracing & Logging (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Đánh giá luồng OpenTelemetry (Tracing), khả năng giám sát vết (Traceparent propagation), và tiêu chuẩn Logging toàn hệ thống.

---

## 1. 🔭 Phân Tích Hiện Trạng Tracing (OpenTelemetry)

Dựa trên tài liệu chuẩn `common/docs/trace-propagation-standard.md` và mã nguồn, hệ thống đang phụ thuộc mạnh vào Dapr Sidecar để truyền Context.

### 1.1. Synchronous Flow (HTTP / gRPC) - Làm tốt
- **Kỳ vọng:** Khi gọi từ `Gateway -> Order -> Inventory`, TraceID phải được truyền đi xuyên suốt để vẽ được biểu đồ trên Jaeger/Tempo.
- **Thực tế:** Dapr tự động làm việc này thông qua annotation `dapr.io/config: tracing-config` trên Pods. Dapr sẽ tiêm W3C `traceparent` vào header. Phía dev Go **không cần code thêm gì**, Kratos và Dapr làm rất tốt chuyện này.

### 1.2. Asynchronous Flow (Dapr PubSub) - Làm tốt
- **Thực tế:** Dapr tự động bơm `traceparent` vào CloudEvents envelope. Việc truy vết luồng sự kiện Pub/Sub đang hoạt động rơn tru mà không cần code can thiệp.

### 1.3. Lỗ Hổng Tracing ở Transactional Outbox (P1) 🚩
- **Kỳ vọng:** Khi Order Service lưu một sự kiện vào bảng Outbox (Postgres), nó **bắt buộc** phải lưu kèm `Traceparent` của luồng Request hiện tại. Để khi Outbox Worker quét db và bắn event đi, nó sẽ gắn lại `Traceparent` đó vào CloudEvent. Khi đó, Jaeger mới nối được Trace từ lúc User "Bấm Đặt Hàng" cho tới lúc "Gửi Email Thành Công".
- **Thực tế:** Mặc dù Struct `outbox.Event` đã có field `Traceparent`, và bản thân `outbox/worker.go` cũng hỗ trợ `tracer.Start(ctx, ...)`. **NHƯNG** khi review code tạo Outbox ở Order/Payment, các Dev **chưa hề** gọi hàm `extractTraceparent(ctx)` để bơm vào Event trước khi `Save()` xuống DB. 
- **Hệ quả:** Chuỗi Tracing bị đứt gãy hoàn toàn tại điểm Outbox. Trên Jaeger, bạn sẽ thấy luồng xử lý bị cắt làm 2: Một Trace cho API Request, và một Trace hoàn toàn mới cho luồng Async Worker. Rất khó để debug end-to-end.

---

## 2. 📝 Phân Tích Tiêu Chuẩn Logging (ELK/Loki Stack)

### 2.1. Vấn Đề TraceID trong Log (P0) 🚩
Khi hệ thống có lỗi, thao tác đầu tiên của Dev là copy cái `trace_id` từ Jaeger và paste vào Kibana/Loki để tìm toàn bộ log liên quan. Để làm được điều này, **tất cả log JSON phải chứa trường `trace_id`**.

**Thực tế tại `common/middleware/logging.go`:**
```go
// Add trace context if available
if span := trace.SpanFromContext(param.Request.Context()); span.SpanContext().IsValid() {
    fields["trace_id"] = span.SpanContext().TraceID().String()
    fields["span_id"] = span.SpanContext().SpanID().String()
}
```
- **Lỗi logic nghiêm trọng:** Code này đang cố lấy Span Context từ `*gin.Context.Request.Context()`. 
- Trong kiến trúc Kratos + Dapr, OpenTelemetry Span Context được inject trực tiếp bởi **Dapr Middleware** hoặc **Kratos Middleware**, chứ không phải nằm sẵn trong Gin request gốc.
- Nếu không có config OpenTelemetry Injector chuẩn xác ở đầu vào của Gin, hàm `trace.SpanFromContext` sẽ luôn trả về một span rỗng/invalid.
- **Hệ quả:** File Log xuất ra (đẩy lên Kibana) đang **trắng bóc** trường `trace_id`, khiến cho việc mò Bug trên Production bằng Log Centralized gần như vô vọng. 

### 2.2. Vấn Đề Kratos Logger
Dự án dùng Kratos nhưng lại kẹp Gin middleware (`logging.go`). Kratos bản thân nó có bộ Logger riêng cực kỳ mạnh (`github.com/go-kratos/kratos/v2/log`). Các Dev đang code kiểu "Hồn Kratos, Da ngâm Gin", dẫn tới việc Log từ Kratos internal (báo lỗi gRPC) và Log từ Middleware HTTP (Gin) chạy thành 2 format khác nhau, rớt TraceID lung tung.

---

## 3. Bản Chỉ Đạo Refactor (Action Items)

1. **Vá ngay lỗ hổng Truy vết Outbox (P1):** Ép tất cả các repository có gọi lệnh Insert vào bảng `event_outbox` (như Order, Payment) phải dùng hàm `extractTraceparent(ctx)` để gán vào trường `Traceparent`.
2. **Sửa Middleware Logging (P0):** 
   - Vứt bỏ đoạn check SpanContext gắn cứng vào Gin.
   - Thêm bộ Middleware của Kratos (`tracing.Server()`) vào config chạy Kratos HTTP/gRPC server.
   - Sửa Kratos Logger global để nó tự động bóc `trace.SpanContextFromContext(ctx).TraceID().String()` và nhét vào mọi dòng log (Dùng `log.With(logger, "trace_id", tracing.TraceID())`). Gắn nó ngay tại hàm `main.go`.
3. **Đồng nhất Format:** Ép tất cả các file sử dụng standard logger của Kratos theo chuẩn JSON thay vì dùng `logrus` rải rác.

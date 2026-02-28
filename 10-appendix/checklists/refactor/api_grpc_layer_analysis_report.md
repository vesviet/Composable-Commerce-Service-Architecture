# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc API / gRPC & Kratos Service Layer

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review cấu trúc tầng Kratos Service, Error Handling và Data Validation của toàn bộ hệ thống API.  
**Trạng thái Review:** Đã Review - Cần Refactor Khẩn Cấp  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P0] [Security/Validation] Missing Protobuf Validator Middleware:** Middleware `validate.Validator()` CỰC KỲ QUAN TRỌNG giúp chạy Protobuf validation rules vẫn **vắng mặt hoàn toàn** tại tất cả các file `internal/server/http.go` và `internal/server/grpc.go`. Input bẩn vẫn có thể lọt vào hệ thống! **Yêu cầu:** Bắt buộc bổ sung `validate.Validator()` vào mảng `krathttp.ServerOption` và `grpc.ServerOption` lập tức. Đây là hard-blocker, không fix không được merge code.
- **[🟡 P1] [Architecture/Consistency] Error Mapping Phân Mảnh Chưa Triệt Để:** Mặc dù Core Team đã xây dựng `common/api/errors/middleware.go` (`ErrorEncoderMiddleware`), nhưng kết quả scan cho thấy **0/21 Services ĐANG SỬ DỤNG** middleware này ở tầng Kratos Server. Mỗi service (`customer`, `location`, `auth`) vẫn đang tự viết mã map lỗi riêng hoặc ném thẳng Internal Error (500) ra Frontend. **Yêu cầu:** Import và kích hoạt `apiErrors.ErrorEncoderMiddleware()` đồng loạt cho tất cả HTTP/gRPC init.
- **[🔵 P2] [Technical Debt/Clean Code] Rác Validation Thủ Công Ở Tầng Business:** Do quên bật Validator Middleware, DEV đã chữa cháy bằng cách code rải rác cú pháp `validation.NewValidator().Required(...)` trong tầng Biz/Service. **Yêu cầu:** Sau khi sửa xong P0, dọn sạch code thừa này để trả lại sự thuần khiết cho tầng Business.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review lần này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Framework] Khởi tạo ErrorEncoderMiddleware chung:** Core Team đã thiết kế xong chức năng `ErrorEncoderMiddleware` và `NewErrorMapper()` thuộc package `common/api/errors`. Khung sườn đã hoàn tất và vượt qua bài test, sẵn sàng tích hợp hàng loạt.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Hệ thống tuân thủ Clean Architecture do Kratos đề xuất (Transport/API -> Service Layer -> Biz Layer).
- **Service Layer (Controller):** Nhận HTTP/gRPC, gọi xuống Biz, và map kết quả trả về `pb.Reply`. Không can thiệp Logic lõi.
- **Protobuf Design:** Các tệp `*.proto` sử dụng `protoc-gen-validate (PGV)` rất chuẩn (Ví dụ: `string id = 1 [(validate.rules).string.uuid = true];`).

### 2. Sự Cố Lỗ Hổng Kratos Validator (Lỗi Ngớ Ngẩn Mức P0) 🚩
Trong các file `.proto` định nghĩa sẵn rất nhiều Rule chặt chẽ. Tuy nhiên, xem mã nguồn khởi tạo Server:
```go
	var opts = []krathttp.ServerOption{
		krathttp.Middleware(
			recovery.Recovery(),
			metadata.Server(),
			metrics.Server(),
			tracing.Server(),
		),
	} // Thiếu validate.Validator() !
```
**Hệ luỵ:** Kratos không bao giờ tự ý check validation trừ khi developer gọi Middleware chặn vào. Một Payload độc hại (SQL Injection, rỗng ID, sai Format Email) sẽ đâm thẳng vào tầng Service và chọc xuống Database sinh ra Panic hoặc Invalid Data.

### 3. Sự Phân Mảnh Trầm Trọng Của Tầng Bọc Lỗi (P1)
Clean Architecture quy định tầng Biz trả về Domain Errors thuần tuý (Ví dụ: `ErrUserBanned`). Việc mapping nó ra mã `HTTP 403 Forbidden` là việc của Transport Layer.
Nhưng hiện tại:
- `Customer`: Code thủ công một nùi `if errors.Is(...)`.
- `Location`: Gọi thô bạo `kratosErrors.FromError(err)`.
Khuyến nghị bắt buộc: Phải dùng chung một Filter/Encoder tổng để thống nhất Payload JSON Error Response toàn công ty.

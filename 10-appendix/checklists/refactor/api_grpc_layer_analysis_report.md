# Báo Cáo Phân Tích & Code Review: Kiến Trúc API / gRPC & Kratos Service Layer (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review cấu trúc tầng Kratos Service, Error Handling và Data Validation của toàn bộ hệ thống API.
**Trạng thái Review:** Lần 1 (Pending Refactor - Theo chuẩn Senior Fullstack Engineer)

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔴 P0] [Security / Validation] Missing Protobuf Validator Middleware:** Middleware `validate.Validator()` CỰC KỲ QUAN TRỌNG giúp chạy Protobuf validation rules vẫn **vắng mặt hoàn toàn** tại tất cả các file `internal/server/http.go` và `internal/server/grpc.go`. Input bẩn vẫn có thể lọt vào hệ thống! *Yêu cầu: Hard-block, bắt buộc bổ sung vào Kratos Server Options ngay.*
- **[🟡 P1] [Architecture] Error Mapping phân mảnh chưa triệt để:** Mặc dù Core Team đã xây dựng `common/api/errors/middleware.go` (`ErrorEncoderMiddleware`), nhưng kết quả scan cho thấy **KHÔNG CÓ DỰ ÁN NÀO ĐANG SỬ DỤNG** middleware này ở tầng Kratos Server. Mỗi service (`customer`, `location`, `auth`) vẫn đang tự viết mã map lỗi riêng hoặc bỏ mặc error rác trả về Client. *Yêu cầu: Nhúng và kích hoạt `apiErrors.ErrorEncoderMiddleware()` đồng loạt.*
- **[🔵 P2] [Technical Debt] Rác Validation ở tầng Business:** Do chưa bật Validator Middleware, DEV phải chèn tay rải rác cú pháp `validation.NewValidator().Required(...)` trong tầng Biz/Service. Cần xoá sạch ngay khi lỗi P0 kia được sửa.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu)*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Framework] Khởi tạo ErrorEncoderMiddleware chung:** Core Team đã build xong chức năng `ErrorEncoderMiddleware` và `NewErrorMapper()` giúp tự động hoá dịch Domain Error sang gRPC/HTTP status chuẩn trong thư viện `common/api/errors`. Khung sườn đã xong, chỉ chờ lắp đặt.

---

## 📋 Chi Tiết Phân Tích (Original TA Report)

## 1. Hiện Trạng Triển Khai (How API Layer is Implemented)

Hệ thống đang tuân thủ kiến trúc Clean Architecture được Kratos quy định (Tầng Transport/API -> Service Layer -> Biz Layer).
- **Service Layer (Controller):** Đóng vai trò là Adapter nhận gRPC và HTTP request, gọi xuống Biz (UseCase) layer, và map kết quả trả về `pb.Reply`.
- **Validation (The Good):** Đội Core đã làm rất tốt việc quy định dùng [Protoc-gen-validate (PGV)](https://github.com/envoyproxy/protoc-gen-validate) đỉnh cao ở các file `*.proto`. Ví dụ: `string id = 1 [(validate.rules).string.min_len = 1];`.
- **Bọc Lỗi (Error Handling):** Có sự nỗ lực chuyển đổi lỗi từ tầng Biz (domain errors) sang bảng mã lỗi chuẩn của Kratos HTTP/gRPC (vd: `kratosErrors.Unauthorized()`) để phía Frontend nhận đúng status map (401, 404, 400).

---

## 2. Các Vấn Đề Lớn Phát Hiện Được (Critical Smells) 🚩

### 🚩 2.1. Quá tự tin vào Protobuf Validation (Lỗi quên bật Công tắc - P0)
**Vấn đề:** 
Mặc dù ở các file `.proto` (như file `review.proto`, `grpc-guidelines.md`) chúng ta thấy ngập tràn các rules `validate.rules`. Điều này tạo cảm giác an toàn giả mạo (rằng data truyền vào luôm luôn sạch).

**NHƯNG**, khi tôi soi vào file gốc `internal/server/http.go` và `internal/server/grpc.go` của **TẤT CẢ** các service (từ Customer, Order, đến Auth):
```go
	var opts = []krathttp.ServerOption{
		krathttp.Middleware(
			recovery.Recovery(),
			metadata.Server(),
			metrics.Server(),
			tracing.Server(),
		),
	}
    // Thiếu vắng hoàn toàn middleware Validator của Kratos!!!
```
**Hệ luỵ nhãn tiền (Rất nguy hiểm):**
Kratos framework **MẶC ĐỊNH KHÔNG** tự động chạy các hàm `Validate()` do PGV sinh ra. Muốn nó chạy, dev bắt buộc phải chèn middleware `validate.Validator()` vào chuỗi chặn (interceptors) lúc khởi tạo Server.
Việc quên chèn middleware này nghĩa là: **Mọi request HTTP/gRPC từ hacker/user gửi tới có trường rỗng, hay email sai định dạng, ID là dấu cách... ĐỀU LỌT XUYÊN THỦNG** tầng Transport và đi thẳng vào tầng Business/Database.
👉 Đây là lỗ hổng bảo mật Input Validation đặc biệt nghiêm trọng.

### 🚩 2.2. Sự Phân Mảnh Trầm Trọng Của Tầng Bọc Lỗi (Error Mapping - P1)
**Vấn đề:**
Ở `customer/internal/service/authentication.go` có một hàm `mapAuthError`. Hàm này thủ công dùng dòng lệnh `if errors.Is(...)` để mò xem tầng Biz đang ói ra lỗi gì, rồi chuyển nó thành HTTP 401, 403, 400.
Ở service `Location` thì lại dùng cách đập thẳng `kratosErrors.FromError(err)`. 
Ở `Auth` service thì lại viết một cái **custom middleware** tên là `error_encoder.go` để lo việc bọc lỗi này.

**Hệ luỵ:**
Clean Architecture yêu cầu tầng Biz không được phép dính dáng tới Infra (không được Return mã lỗi HTTP 400, 404), nó chỉ được return Domain Errors (VD: `ErrRecordNotFound`). Và Trách nhiệm Error mapping này phải quy về một chốn duy nhất.
Tình trạng hiện tại: Mỗi Service đang tự handle error theo phong cách riêng của nó (ai lười thì ói HTTP 500 ra nguyên đống call stack).

### 🚩 2.3. Lặp lại Validation Logic Ở Tầng Biz (P2)
Bởi vì (tình cờ) Protobuf validator không chạy (như lỗi P0 ở trên), các dev thấy lỗi xuyên vào DB, nên đã phải hoảng hốt chèn `validation.NewValidator().Required(...).Validate()` thủ công vào khắp nơi trong tầng `internal/biz` và `internal/service`. Làm bẩn code Business Logic một cách oan uổng.

---

## 3. Bản Chỉ Đạo Refactor Từ Senior (Clean Architecture Roadmap)

### ✅ Giải pháp 1: Bật Kratos Validator Middleware Ngay Lập Tức (Fix P0)
Core Team mở toàn bộ 15++ folder microservices. Vào tệp `internal/server/http.go` và `internal/server/grpc.go`, bổ sung ngay middleware này:

```go
import "github.com/go-kratos/kratos/v2/middleware/validate"

func NewHTTPServer(logger log.Logger) *krathttp.Server {
	var opts = []krathttp.ServerOption{
		krathttp.Middleware(
			recovery.Recovery(),
			tracing.Server(),
			validate.Validator(), // Bắt buộc phải có dòng này!
		),
	}
// ...
```
Sau khi chèn dòng này, các Validator tự chế rườm rà ở tầng Biz có thể rảnh tay xóa đi được 50%.

### ✅ Giải pháp 2: Gom Error Mapping về Common Error Encoder
Thiết kế một Custom Error Encoder cho chuẩn toàn dự án ở thư mục `common/api/errors.go` (giống như service Auth đang làm lỡ dở). Thằng này chuyên hứng mọi type ERROR ở Go, map chúng với gRPC status/HTTP status chuẩn xác, và bọc JSON Response tiêu chuẩn rồi trả về Client. 
Không bắt dev Service phải tự gõ `if errors.Is(err, X) return HTTP400` ngàn dòng nữa.

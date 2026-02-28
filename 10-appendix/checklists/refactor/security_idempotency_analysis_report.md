# Báo Cáo Phân Tích & Code Review: Security & Idempotency Flow (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Đánh giá luồng Xác thực/Phân quyền (RBAC) và cơ chế Chống lặp Request (Idempotency) để bảo vệ hệ thống khỏi Double-Charge (trừ tiền 2 lần).
**Trạng thái Review:** Lần 1 (Pending Refactor - Theo chuẩn Senior Fullstack Engineer)

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔵 P2] [Technical Debt] Rác code Idempotency tại Payment:** Mặc dù gói `common/idempotency/redis_idempotency.go` đã được Core Team xây dựng xong xuôi đầy đủ chức năng `SetNX`, nhưng Service Payment vẫn giữ lại một bản copy `idempotency.go` của riêng nó nằm ở `payment/internal/biz/common/idempotency.go`. Việc Duplicate code core này rủi ro cho quá trình bảo trì sau này. *Yêu cầu: Payment service phải xóa file local, import và sử dụng trực tiếp từ thư viện `common`.*
- **[🔵 P2] [Security] Hardcode Role Check:** Phân quyền theo Role đang bị cứng hóa trong code bằng các lệnh như `RequireRole("admin")`. *Nên dùng Policy-Based Access Control (PBAC / Casbin).*

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh)*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Security/Data] Vá lổ hổng Double-Charge (Race Condition) ở Payment Service:** Vấn đề tồi tệ nhất ở báo cáo trước (dùng combo `Get -> Check -> Set` dễ gây trừ tiền 2 lần khi User spam request) ĐÃ ĐƯỢC VÁ THÀNH CÔNG. Hiện tại `payment/internal/biz/common/idempotency.go` đã chuyển sang dùng lệnh Atomic `SetNX` của Redis ở cả hàm `CheckAndStore` và `Begin`. Luồng thanh toán hiện tại đã chặn đứng được spam request.

---

## 📋 Chi Tiết Phân Tích (Original TA Report)

## 1. 🛡️ Security & Authentication Flow (RBAC & Gateway)

### 1.1. Hiện Trạng (The Good)
Gói `common/middleware/auth.go` được thiết kế rất vững chắc:
- **Zero-Trust ở đầu vào:** Cảnh giác cao độ với JWT token. Có check chữ ký số (`HMAC`), cấu trúc claim `roles`, `user_id`.
- **Backward Compatibility:** Code xử lý rất tinh tế việc fallback giữa format role cũ (chuỗi `role`) và mới (mảng `roles`).
- **Phân tách trách nhiệm (Separation of Concerns):** Gateway làm nhiệm vụ hứng SSL/TLS và parse HTTP đầu vào, sau đó ném qua Kratos middleware. Tự Kratos sẽ bóc tách `x-md-user_id` từ Metadata gRPC/HTTP ra context qua hàm `ExtractUserID` (`common/middleware/context.go`).

### 1.2. Vấn Đề Tìm Thấy (Cần Làm Chặt Chẽ Hơn)
- Phân quyền theo Role đang bị "Cứng hóa" (Hardcode) trong code: Hàm `GinHasRole` hay `RequireRole("admin")` dính chặt vào logic HTTP handler. Ở quy mô lớn, nên cân nhắc dùng cơ chế Policy-Based Access Control (PBAC) như OPA (Open Policy Agent) hoặc Casbin thay vì if/else cứng tệp Role.

---

## 2. 🛡️ Idempotency Flow (Chống Trừ Tiền 2 Lần)

Luồng Idempotency là thành trì sống còn của các hệ thống E-commerce, đặc biệt là lúc gọi qua Payment Gateway (Stripe/Paypal).

### 2.1. Order Service (The Good)
**Order** dùng kỹ thuật **Database-level Idempotency** (tệp `common/idempotency/event_processing.go` và `gorm_helper.go`).
- Sử dụng Postgres `ON CONFLICT DO UPDATE` để chặn Request lặp. Đảm bảo tính nhất quán cao nhất (ACID).
- Đây là cách tiếp cận cực kỳ chuẩn mực cho Order khi bắt các sự kiện (Event) từ Dapr PubSub. Nếu mạng lag làm Dapr bắn đúp 2 event `PaymentConfirmed`, hệ thống tự động khóa băng event số 2.

### 2.2. Payment Service (Critical Smell - Lỗ Hổng Nặng) 🚩
Ngược với Order, Service **Payment** lại dùng **Redis-based Idempotency** (tại file `payment/internal/biz/common/idempotency.go`).

**Lỗ hổng Race Condition (P0):**
Hãy nhìn vào hàm `Begin()` của RedisIdempotency:
```go
	// 1. Try to get existing state from Redis
	val, err := s.redis.Get(ctx, redisKey).Result()
	if err == nil {
        // ... return if completed / in_progress
    }

	// 2. Create new state (in_progress)
	state := &IdempotencyState{...}
	stateBytes, _ := json.Marshal(state)

    // 3. SET vào Redis
	if err := s.redis.Set(ctx, redisKey, stateBytes, s.ttl).Err(); err != nil {
```

Đây là một Anti-Pattern kinh điển: **Check-then-Act mà không có Khóa (Lock) hoặc Transaction**.
Giả sử User bị giật mạng, App tự retry tạo ra 2 HTTP request đến CÙNG MỘT LÚC (cách nhau 1 milisecond).
- Thread A chạy đoạn `redis.Get()`, thấy Nil.
- Thread B chạy đoạn `redis.Get()`, cũng thấy Nil (do Thread A chưa tới bước `SET`).
- Kết quả: Cả 2 Thread đều đi tiếp vào logic gọi thanh toán Stripe. Khách hàng bị trừ tiền 2 lần!

**Giải pháp bắt buộc (Kiến trúc chuẩn):**
Với Redis, cấm tuyệt đối việc dùng `GET` rồi mới `SET`. Phải dùng nguyên thủy `SETNX` (Set if Not eXists).
```go
// Atomic operation ở Redis
success, err := s.redis.SetNX(ctx, redisKey, "in_progress", ttl).Result()
if err != nil || !success {
    // Nếu success = false -> Có thằng khác đã chiếm được khóa -> Mình bị block -> Dừng lại ngay lập tức
}
```
Hoặc quy chuẩn hơn là làm 1 Lua Script chạy trên Redis để đảm bảo tính Atomic 100%.

---

## 3. Bản Chỉ Đạo Refactor (Action Items)

1. **Khẩn cấp (P0):** Fix ngay lập tức class `redisIdempotencyService` ở Payment Service. Đổi toàn bộ các luồng `Get -> Check -> Set` sang `SetNX` (hoặc dùng thư viện RedisLock/RedSync giả mạo Redlock). Nếu không, những ngày sale lớn chắc chắn CSKH (Customer Service) sẽ ngập trong ticket Refund vì bị double-charge.
2. **Quy Hoạch (P2):** Đưa toàn bộ Logic Idempotency bằng Redis này từ Payment Service gộp ngược về package Lõi `gitlab.com/ta-microservices/common/idempotency` để sau này Order hay Cart cần rate limit/idempotency qua Redis cũng xài chung được (Không viết lặp lại).

# 📋 Báo Cáo Phân Tích & Code Review: Security & Idempotency Flow

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Đánh giá luồng Xác thực/Phân quyền (RBAC) và cơ chế Chống lặp Request (Idempotency) để bảo vệ hệ thống khỏi Double-Charge (trừ tiền 2 lần).  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - Nửa vời, Copy-Paste Tràn Lan)

---

## 🚩 PENDING ISSUES (Unfixed - CẦN ACTION)
- **[🟡 P1] [Technical Debt/Architecture] Copy-Paste Logic Idempotency Khắp Nơi:** Gói `common/idempotency/redis_idempotency.go` đã được Core Team xây dựng xong xuôi với API `SetNX` an toàn. Quét thực tế vẫn lù lù tệp `payment/internal/biz/common/idempotency.go`. DEV thanh toán lười tới mức copy nguyên tệp bỏ vào folder local. **Yêu cầu:** Xóa tệp local của Payment, refactor import thẳng từ thư viện Common.
- **[🔵 P2] [Security/RBAC] Copy-Paste Logic Phân Quyền Vô Tội Vạ (Hardcoded Roles):** Lỗi này CỰC KỲ KHÓ CHỊU. Lệnh quét mã nguồn chỉ ra các service `review`, `pricing`, `return`, `catalog`, `promotion` đua nhau copy struct `RequireRole()` vào file `internal/middleware/auth.go` của mình thay vì xài hàm xịn ở `common/middleware/auth.go`. Quản trị code kiểu nông dân! **Yêu cầu:** Dọn dẹp hết mớ local middleware auth này và dùng chung hàng core. Cân nhắc quy hoạch sang PBAC (Casbin).

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Security/Data] Vá Kịp Thời Lỗ Hổng Double-Charge (Race Condition) ở Payment Service:** Mặc dù copy-paste, nhưng logic Core (`SETNX`) bên trong tệp `payment` đã được cập nhật bản Vá. Anti-pattern chết người `Get -> Check -> Set` đã được dập tắt. Hệ thống hiện tại đã Block được các pha spam click/request từ end-user.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. 🛡️ Security & Authentication Flow (RBAC & Gateway)
Gói `common/middleware/auth.go` được thiết kế có chiều sâu phân tầng tốt:
- **Zero-Trust ở đầu vào:** Cảnh giác cao độ với JWT token. Có check chữ ký số (`HMAC`), cấu trúc claim `roles`, `user_id`.
- **Phân tách trách nhiệm (Separation of Concerns):** Gateway làm nhiệm vụ hứng SSL/TLS và parse HTTP header, ném qua Kratos middleware. Tự Kratos sẽ bóc tách `x-md-user_id` gán vào context `ExtractUserID`.
- **Lỗ hổng con người:** Thiết kế chuẩn nhưng Engineer ở các service rìa (Catalog, Return, Pricing...) đi lách luật bằng cách Copy Paste mã nguồn `RequireRole` ra chục bản!

### 2. 🛡️ Idempotency Flow (Chống Trừ Tiền 2 Lần)
**Order Service (Thành Công Chuẩn Mực):**
- **Order** dùng Kỹ thuật **Database-level Idempotency** (tệp `common/idempotency/event_processing.go`).
- Sử dụng Postgres `ON CONFLICT DO UPDATE` để chặn Request lặp (ACID). Rất tốt khi bắt sự kiện từ Dapr PubSub.

**Payment Service (Đã Fix nhưng lưu ý Lỗ hổng cũ):**
- Hàm cũ `Begin()` dùng code theo trình tự: `Get() -> Tồn tại thì Return -> Chưa có thì Set()`. 
- **Tại sao Anti-pattern?** Khi user rớt mạng và retry 2 requests tới cùng milisecond. Thread A đọc ra Nil. Thread B cũng đọc ra Nil (do Thread A chưa tới bước SET). Kết quả: Cả 2 Thread đi tiếp vào cổng thanh toán Stripe. Khách hàng bị gõ 2 bill!
- **Đã Fix Hành Vi Bằng `SETNX`:** (Set if Not eXists). Mã Atomic cấp thấp của Redis luôn trả về `false` cho Thread B khi Thread A vượt lên trước. Khóa cứng và thả 409 Conflict. Tránh được bài toán Race Condition kinh điển.

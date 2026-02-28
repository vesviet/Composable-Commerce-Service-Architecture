# 📋 Báo Cáo Phân Tích & Code Review: Security & Idempotency Flow

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Đánh giá luồng Xác thực/Phân quyền (RBAC) và cơ chế Chống lặp Request (Idempotency) để bảo vệ hệ thống khỏi Double-Charge (trừ tiền 2 lần).  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔵 P2] [Technical Debt/Architecture] Copy-Paste Logic Idempotency Tại Payment:** Gói `common/idempotency/redis_idempotency.go` đã được Core Team xây dựng xong xuôi với API `SetNX` an toàn. Cớ sao cấu trúc Service Payment lại giữ một bản copy `idempotency.go` riêng (nằm ở `payment/internal/biz/common/idempotency.go`)? Việc Duplicate core logic gây rủi ro bảo trì. **Yêu cầu:** Xóa tệp local của Payment, refactor import thẳng từ thư viện Common.
- **[🔵 P2] [Security/RBAC] Cứng Hóa Phân Quyền (Hardcoded Roles):** Các HTTP handlers đang dùng lệnh `RequireRole("admin")` dính chặt vào code. Nếu Customer đổi ý hệ thống Role, Dev phải build lại toàn bộ Service. **Yêu cầu:** Cân nhắc quy hoạch sang Policy-Based Access Control (PBAC / Casbin) tải policy từ Database/Redis.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Security/Data] Vá Kịp Thời Lỗ Hổng Double-Charge (Race Condition) ở Payment Service:** Anti-pattern chết người `Get -> Check -> Set` đã được dập tắt. Toàn bộ `payment/internal/biz/common/idempotency.go` đã chuyển sang dùng lệnh Atomic `SetNX` của Redis ở cả hàm `CheckAndStore` và `Begin`. Hệ thống hiện tại đã Block được các pha spam click/request từ end-user.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. 🛡️ Security & Authentication Flow (RBAC & Gateway)
Gói `common/middleware/auth.go` được thiết kế có chiều sâu phân tầng tốt:
- **Zero-Trust ở đầu vào:** Cảnh giác cao độ với JWT token. Có check chữ ký số (`HMAC`), cấu trúc claim `roles`, `user_id`.
- **Phân tách trách nhiệm (Separation of Concerns):** Gateway làm nhiệm vụ hứng SSL/TLS và parse HTTP header, ném qua Kratos middleware. Tự Kratos sẽ bóc tách `x-md-user_id` gán vào context `ExtractUserID`.

### 2. 🛡️ Idempotency Flow (Chống Trừ Tiền 2 Lần)
**Order Service (Thành Công Chuẩn Mực):**
- **Order** dùng Kỹ thuật **Database-level Idempotency** (tệp `common/idempotency/event_processing.go`).
- Sử dụng Postgres `ON CONFLICT DO UPDATE` để chặn Request lặp (ACID). Rất tốt khi bắt sự kiện từ Dapr PubSub.

**Payment Service (Đã Fix nhưng lưu ý Lỗ hổng cũ):**
- Ngược với Order, Payment lại dùng **Redis-based Idempotency**.
- Hàm cũ `Begin()` dùng code theo trình tự: `Get() -> Tồn tại thì Return -> Chưa có thì Set()`. 
- **Tại sao Anti-pattern?** Khi user rớt mạng và retry 2 requests tới cùng milisecond. Thread A đọc ra Nil. Thread B cũng đọc ra Nil (do Thread A chưa tới bước SET). Kết quả: Cả 2 Thread đi tiếp vào cổng thanh toán Stripe. Khách hàng bị gõ 2 bill!
- **Đã Fix Hành Vi Bằng `SETNX`:** (Set if Not eXists). Mã Atomic cấp thấp của Redis luôn trả về `false` cho Thread B khi Thread A vượt lên trước. Khóa cứng và thả 409 Conflict. Tránh được bài toán Race Condition kinh điển.

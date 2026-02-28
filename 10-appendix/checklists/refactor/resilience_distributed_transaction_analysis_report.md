# Báo Cáo Phân Tích & Code Review: Resilience & Distributed Transaction (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Khảo sát Sức chịu đựng của hệ thống (Resilience) và cách xử lý Giao dịch Phân tán (Distributed Transaction) thông qua Saga Pattern.
**Trạng thái Review:** Lần 1 (Kiến trúc Đạt Chuẩn - Đã Refactor các điểm nhỏ)

---

## 🚩 PENDING ISSUES (Unfixed)
- *(Không còn Pending Issues nào trong báo cáo này. Kiến trúc Dapr Saga Pattern đang hoạt động hoàn hảo.)*

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu)*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Documentation] Bổ sung Sequence Diagram:** Tệp `docs/05-workflows/sequence-diagrams/order-saga-pattern-validation.md` đã được đội ngũ thiết kế bổ sung, mô tả trực quan 3 Phase của Saga này. Đảm bảo tri thức được truyền tải cho hệ thống.
- **[FIXED ✅] [Observability] Tích hợp Alerting System:** Interface `biz.AlertService` tại Order (`order/internal/biz/monitoring.go`) CHÍNH THỨC đã được gắn kết với `NotificationService` để trigger các mã lõi (như `CART_CLEANUP_FAILED` hay `PAYMENT_COMPENSATION_FAILED`) bắn thẳng về kênh CS/Ops.

---

## 📋 Chi Tiết Phân Tích (Original TA Report)

## 1. 🚦 Giao Dịch Phân Tán (Saga Pattern)

Khi rạch ròi thành Microservices, một nghiệp vụ như **"Checkout"** sẽ xé nát tính ACID của Database vì nó phải xẹt qua 4 dịch vụ: `Order` -> `Payment` -> `Warehouse (Inventory)` -> `Notification`. 

Nếu Order tạo xong, Payment trừ tiền xong, nhưng Warehouse báo hết hàng (OOM) thì làm sao để vớt lại tiền cho khách? Đây là bài toán Saga. 

### 1.1. Khảo Sát Tín Hiệu (The Good)
Tôi đã soi cấu trúc luồng của **Order Service** và phát hiện Dev đã triển khai **Durable Saga Pattern** một cách cực kỳ bài bản. Có thể nói đây là kiến trúc chuẩn sách giáo khoa (Textbook Architecture).

Các bằng chứng thép:
1. **Lưu Trạng Thái Saga (Phase 1):** Bảng `orders` có trường `payment_saga_state` (Authorized, CapturePending, CaptureFailed, Captured) - Tệp `order/migrations/035_add_payment_saga_state.sql`. Việc lưu State DB giúp hệ thống không bao giờ bị "quên" giao dịch nếu Pod bị crash ngang.
2. **Worker Tự Động Thử Lại (Phase 2):** Có một Background Cron Job tên là `CaptureRetryJob` (`worker/cron/capture_retry.go`). Job này liên tục lùng sục các Order bị dính trạng thái `CaptureFailed` (do Payment gateway timeout) để tự động gọi lại (Retry).
3. **Giao Dịch Bù Trừ - Compensation (Phase 3):** Khi `CaptureRetryJob` thử lại đủ `MaxCaptureRetries` (giới hạn 3 lần) mà vẫn thất bại mạng, nó sẽ nhả Order qua cho `PaymentCompensationJob` (`worker/cron/payment_compensation.go`). Job này làm đúng nghĩa vụ của đấng cứu thế:
   - Gọi API Void lại Authorization bên Payment.
   - Hủy Order (`OrderStatusCancelled`).
   - Gọi Kafka/Dapr nhả lại tồn kho (Release Reservation).

### 1.2. Mạng Lưới An Toàn Cuối Cùng (Dead Letter Queue - DLQ)
Điểm đáng khen nhất là xử lý **Lỗi Kép**.
Nếu lúc `PaymentCompensationJob` gọi sang Payment để hoàn tiền/Void mà Payment Service đang... sập hẳn (Downtime) thì sao?
- Thay vì hoảng loạn vứt logic, Dev lập trình nó ghi luôn vào bảng DLQ thông qua interface `biz.FailedCompensationRepo`.
- Hệ thống Admin có một API (`service/failed_compensation_handler.go`) để Customer Service (CS) lôi các "Giao dịch chết" này ra và bấm nút **Retry Bằng Tay** (`RetryFailedCompensation`).
- Đồng thời gửi Alert `PAYMENT_COMPENSATION_FAILED` mức độ Critical cho DevOps.

---

## 2. 🛡️ Fault Tolerance & Circuit Breaker (Đánh Giá Nhanh)

### 2.1. Việc Gọi gRPC (The Good)
Hệ thống sử dụng Kratos làm khung sườn, toàn bộ các gRPC/HTTP Client (như trong `common/client`) đều được gói ghém với:
- Timeout rõ ràng (VD: 5s).
- Retries (Exponential Backoff).
- Circuit Breaker.
Nếu Payment sập, Order sẽ không bị dội bom Request chờ tới lúc sập lây (Cascading Failure), mà Circuit Breaker sẽ Trip ngay lập tức.

### 2.2. Vấn đề Rate Limiting (P2 - Cảnh báo nhẹ)
- Hệ thống phân nhóm API Gateway khá tốt nhưng tôi chưa thấy rõ config Rate Limiting bằng Redis để chống DDoS (Layer 7) ở mức Gateway cấu hình chặn trước khi vào Kratos Service. Cái này nên được rà soát lại trên API Gateway (Traefik/Kong/APISIX).

---

## 3. Bản Chỉ Đạo Refactor (Action Items)

**Tổng quan:** Cấu trúc Saga Pattern của dự án **Đạt chuẩn Senior/Staff Engineer**. Thực thi cực kỳ tốt, che chắn đủ các edge-cases (Lỗi mạng, Lỗi trừ tiền, Lỗi hoàn tiền).

Dưới góc độ Code Review khắt khe, chỉ có một vài điểm nhỏ cần cải thiện:
1. **Docs (P2):** Viết thêm một Workflow Sequence Diagram (Mermaid) vào thư mục `docs/05-workflows` miêu tả chi tiết 3 Phase của Saga này để các dev junior mới vào đọc hiểu bức tranh toàn cảnh (Tránh việc họ lỡ tay sửa code phá vỡ State Machine).
2. **Alerting System:** Kiểm tra xem `biz.AlertService` đã thực sự móc vào Slack/PagerDuty chưa, hay mới chỉ là Interface nằm im trên giấy? Nếu chưa, cần có task Integrate ngay lập tức cho team DevOps.

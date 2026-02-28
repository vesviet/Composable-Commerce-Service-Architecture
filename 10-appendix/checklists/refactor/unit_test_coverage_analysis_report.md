# Báo Cáo Phân Tích: Unit Test & Test Coverage (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Đánh giá văn hóa viết Test, mức độ bao phủ mã nguồn (Coverage), và tính tuân thủ các quy tắc trong `testcase.md`.

---

## 1. 📊 Hiện Trạng Khủng Hoảng Test Coverage (P0 - Báo Động Đỏ)

Mục tiêu của Clean Architecture là tập trung bảo vệ tầng `internal/biz` (Nghiệp vụ lõi) khỏi mọi sự thay đổi bên ngoài. Do đó, tầng `biz` bắt buộc phải có độ phủ Test cao nhất (Standard ngành là > 80%).

Tuy nhiên, kết quả khảo sát thực tế qua lệnh `go test -cover ./internal/biz/...` tại 2 Service xương sống là `Order` và `Payment` cho thấy một bức tranh đáng buồn:

**Order Service:**
- `biz/order`: **20.0%**
- `biz/cancellation`: **32.8%**
- Các package cực kỳ quan trọng như `order_edit`, `validation`, `status`: **0.0%** (Hoàn toàn không có dòng code test nào).

**Payment Service:**
- `biz/payment`: **18.0%**
- `biz/settings`: **80.9%** (Duy nhất package này đạt chuẩn).
- Các luồng sống còn như `refund`, `reconciliation`, `transaction`, `webhook`: **0.0%**.

**Hệ Lụy:**
Hệ thống Ecommerce đang vận hành dựa trên "niềm tin" thay vì "sự bảo chứng" của Code. Bất kỳ một Junior nào mới vào sửa logic tính tiền, tính thuế, hoặc đổi trạng thái Order đều có khả năng gây sập logic Production mà CI/CD không hề báo lỗi.

---

## 2. 🏗️ Đánh Giá Cấu Trúc Viết Test (The Good & The Bad)

Tôi đã soi trực tiếp tệp `payment/internal/biz/payment/payment_p0_test.go` và `order/internal/biz/mocks.go`.

### 2.1. Điểm Tốt (Tuân thủ `testcase.md`)
1. **Table-Driven Tests:** Các Dev áp dụng rất triệt để pattern `tests := []struct{}`. VD: hàm `TestProcessPayment_ValidationErrors` cover 7 case validations cực kỳ sạch sẽ và rành mạch.
2. **Assertions:** Đã tuân thủ nguyên tắc dùng thư viện ngoài (`github.com/stretchr/testify/assert` và `require`), loại bỏ hoàn toàn kiểu check nguyên thủy `if err != nil { t.Fatal() }`.

### 2.2. Điểm Xấu (Vi phạm `testcase.md`) - P1 🚩
**Quy tắc trong docs ghi rõ:**
- *gomock generated mocks in internal/biz/<package>/mocks/ for complex interfaces (preferred for repo mocks)*

**Thực tế triền khai:**
Cả Order và Payment **hoàn toàn phớt lờ `gomock`**. 
1. **Payment Service:** Tự tay viết tay toàn bộ struct định nghĩa Mock bằng `testify/mock` (`MockPaymentRepository`, `MockGatewayFactory`, v.v) kéo dài tới hơn 400 dòng code trong tệp `usecase_test.go`. Khối lượng code rác khổng lồ.
2. **Order Service:** Còn tệ hơn, dùng tệp `internal/biz/mocks.go` tự code thuần thủ công cấu trúc map bộ nhớ (`map[string]*Order`) giả lập Database in-memory dài 700 dòng. 

**Tại sao đây là Vi Phạm Nặng?**
- Viết tay quá mệt, dẫn tới việc lười viết Test -> Lý giải vì sao Coverage toàn 0%.
- Khi Interface `OrderRepo` thay đổi thêm 1 field, toàn bộ các file Mock viết tay sẽ lỗi Syntax hàng loạt, gây nản chí cho người refactor.
- Không thể assert hành vi mạnh mẽ (Ex: Require call hàm A exactly 2 times) như Gomock.

---

## 3. Bản Chỉ Đạo Refactor (Action Items)

Dịch vụ đã đến Phase "Production-Ready", việc nợ kỹ thuật (Technical Debt) về Unit Test đã đến mức đáo hạn và cần phải trả gay gắt.

1. **Ban Hành Lệnh Gomock (P0):**
   - Xóa bỏ toàn bộ `internal/biz/mocks.go` làm bằng tay ở Order.
   - Xóa bỏ các Struct `testify/mock` tự chế trong Payment.
   - Thêm lệnh `go generate` bằng gói `go.uber.org/mock/mockgen` vào file `interfaces.go` của mọi Service. Yêu cầu mọi Dev phải Generate tự động file `mock_repository.go`.
2. **Chiến Dịch Tăng Coverage Lên 60% (P1):**
   - Không bắt ép chạy lên 80% ngay lập tức (Vì sẽ freeze tính năng mới).
   - Yêu cầu team QA và Dev Focus viết test đầy đủ (Happy flow + Dòng lỗi) cho 3 Package quan trọng nhất:
     - `payment/internal/biz/refund` (Luồng hoàn tiền nhạy cảm).
     - `order/internal/biz/validation` (Luồng chặn dữ liệu bẩn).
     - `order/internal/biz/status` (Luồng nhảy State Machine Saga).
3. **Chốt CI/CD Hook:**
   - Add flag `go test -coverprofile=coverage.out` vào GitHub Actions / GitLab CI. Nếu Coverage của nhánh Merge Request làm giảm Coverage tổng, tự động Block Merge.

# 📋 Báo Cáo Phân Tích & Code Review: Unit Test Coverage & Mocking

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Đánh giá văn hóa viết Test, mức độ bao phủ mã nguồn (Coverage), và tính tuân thủ quy tắc `testcase.md`.  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - CHƯA FIX - TÌNH TRẠNG BÁO ĐỘNG)

---

## 🚩 PENDING ISSUES (Unfixed - KHẨN CẤP)
- **[🚨 P0] [Code Quality/Test] Cấu Trúc Viết Test Vẫn Dùng Manual Mocks Rác Khối Lượng Lớn:** Kiểm tra thực tế cho thấy DEV vẫn làm lơ lệnh dùng gomock.
  - **Order Service:** File `internal/biz/mocks.go` chứa một cục tảng đá Mock viết tay dài hơn **700 dòng** ( `MockOrderRepo`, `MockOrderItemRepo`, in-memory Maps...). 
  - **Payment Service:** Code `payment_p0_test.go` và `usecase_test.go` ngập tràn các struct kế thừa `testify/mock.Mock` thủ công tốn hàng khối code.
  **Yêu cầu Khẩn (Lần 2):** CẤM VIẾT TAY MOCK cho các Interface lớn! Sử dụng thư viện `go.uber.org/mock/mockgen` lập tức. Sinh tự động `mock_repository.go` trong `internal/biz/<package>/mocks/`.
- **[🚨 P0] [Coverage] Độ Phủ Tầng Business Bị Bỏ Rơi:** 
  Khi chạy Audit (`go test -cover`) tại nhánh `internal/biz/...` của Order và Payment, lệnh còn vướng dependency lỗi (`vendor drift`), đồng thời Coverage nhiều mảng cốt lõi như `order/biz/status`, `payment/biz/refund` rỗng testcode. 
  **Yêu cầu:** Mở campaign Coverage, lấp ngay lỗ hổng logic Tài chính/Kho vận, tối thiểu 60%.
- **[🟡 P1] [CI/CD] Trống rỗng cơ chế báo cáo Coverage tự động:** Pipeline Gitlab chưa chặn merge khi coverage tụt. **Suggested Fix:** Thêm rule `go test -coverprofile=coverage.out ./internal/biz/...` vào thư mục `gitlab-ci-templates`.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Structure] Cấu trúc Table-Driven Test và Assertions:** Các test đã có trong hệ thống đúng là đã dùng mô hình `tests := []struct{}` và assert chuẩn. Form dáng đúng, nhưng ruột/mock sai.

---

## 📋 Hướng Dẫn Kỹ Thuật (Guidelines Từ Senior)

### 1. 📊 Hiện Trạng Khủng Hoảng Phủ Code (Red Alert)
Mục tiêu của Clean Architecture là tập trung bảo vệ logic lõi tại `internal/biz`. Nhưng hiện tại:
- **Hệ lụy:** Sập luồng Checkout/Refund bất cứ lúc nào khi thay đổi cấu trúc DB hoặc logic nâng cấp.

### 2. 🏗️ Phân Tích Sự Rủi Ro Của Mock Viết Tay
Trong `testcase.md`, mặc dù cho phép dùng `testify/mock` cho simple cases, nhưng việc viết `mocks.go` dài 700 dòng là "Tự bắn vào chân".
- **Tại sao việc này nguy hiểm?**
  1. Đổi Struct ở Data Model là Mock vỡ nát, mất cả ngày đi sửa file `mocks.go`.
  2. Bị đọa đầy bởi sự cồng kềnh, Dev đâm ra ghét viết thêm Test.
- **Thực thi:**
  Tiến hành ban hành lệnh `gomock` toàn hệ thống. Mọi interface từ `internal/biz/xyz` phải có `//go:generate mockgen -destination=mocks/mock_xyz.go -package=mocks . XyzRepo`.

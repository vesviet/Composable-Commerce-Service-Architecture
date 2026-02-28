# 📋 Báo Cáo Phân Tích & Code Review: Clean Architecture & Domain Separation

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review sự cô lập giữa các tầng kiến trúc (API -> Biz -> Data) và nguyên tắc Domain-Driven Design (DDD).  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - VẪN CÒN RÒ RỈ NGHIÊM TRỌNG)

---

## 🚩 PENDING ISSUES (Unfixed - KHẨN CẤP)
- **[🚨 P0] [Architecture/Domain] Tầng Biz Rò Rỉ Data Model Kép (Kratos Anti-Pattern):** Scan codebase `customer/internal/biz` cho thấy thảm họa kiến trúc vẫn còn nguyên! Các UseCase tại `customer.go`, `auth.go`, `address.go`, `segment.go` liên tục `import "gitlab.com/ta-microservices/customer/internal/model"`. Tầng Biz lệ thuộc 100% vào Data Entities có chứa GORM tags. **Yêu cầu (Lần 2):** ĐẬP ĐI XÂY LẠI nhánh `biz/customer`. Tách bạch Domain Model kiểu `biz.Customer` (thuần túy logic) khỏi Data Model `model.Customer` (chứa Database Schema). Viết mapper tại tầng Data `postgres` để chuyển đổi.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Architecture/API] Chặn Đứng Rò Rỉ Data Model Trực Tiếp Lên API Layer:** Hàm `ToCustomerReply()` và `ToStableCustomerGroupReply()` vốn dĩ vi phạm nghiêm trọng luật MVC (cắm mã gen protobuf vào bên trong GORM model) ĐÃ ĐƯỢC XÓA BỎ HOÀN TOÀN khỏi `internal/model/customer.go`. Model giờ chỉ thuần túy là định dạng DB schema. Bước đầu dọn dẹp rất tốt.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Dự án phần lớn bám sát được bộ khung Clean Architecture:
- **Ngăn Chặn GORM Rò Rỉ Cấp Query:** Quét toàn bộ source code của `internal/biz`, KHÔNG CÓ sự xuất hiện của `gorm.DB` hay logic Query.
- **Repository Pattern Ổn Định:** Lời gọi từ Biz xuống Data thông qua Interfaces (`CustomerRepo`).

### 2. Sự Cố Rò Rỉ Khái Niệm Ở Tầng Biz (Lỗi P0 Xuyên Thủng Domain) 🚩
Sự cố của **Customer Service**:
- Data Entity `Customer` nằm ở `internal/model` chứa chằng chịt tag của GORM.
- **Vấn đề:** Ở Tầng Biz (`customer/internal/biz/*`), các logic code lại return thẳng kiểu Data Entity `*model.Customer`. Điều này khiến thư mục `biz` - vốn dĩ phải là nơi độc lập định nghĩa Domain Rules - lại phải Import Data Model phụ thuộc.
- **Mô hình đang chạy thực tế:** `API (Protobuf)` <--- `Biz Layer` (return model) <--- `Data Layer` (gorm model).
- **Hệ luỵ:** Sửa tên cột Database -> Sửa Gorm Tag -> Thay đổi định dạng Data Entity -> Code tầng Biz gián tiếp bị vỡ hoặc rò rỉ field rác ra ngoài Transport.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Lấy **Order Service** làm hình mẫu chuẩn (Reference Model).
- **Tầng Biz (`internal/biz`):** Định nghĩa lại Entity thuần Go, không có Tag GORM/JSON.
  ```go
  type Customer struct {
      ID           string
      Email        string
      CustomerType int
  }
  ```
- **Tầng Data (`internal/data`):** Repo lấy `model.Customer` từ DB xong, phải tự map sang Domain `biz.Customer` rồi mới trả vể Biz.
- **Tầng Service (`internal/service/*_convert.go`):** Mapping từ `biz.Customer` sang Protobuf `pb.CustomerReply`.
- **Tuyệt đối nghiêm cấm:** Việc import `internal/model` vào thẳng bộ gõ Tầng Transport hoặc Tầng Logic Core.

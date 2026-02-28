# 📋 Báo Cáo Phân Tích & Code Review: Clean Architecture & Domain Separation

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review sự cô lập giữa các tầng kiến trúc (API -> Biz -> Data) và nguyên tắc Domain-Driven Design (DDD).  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🟡 P1] [Architecture/Domain] Tầng Biz rò rỉ Data Model (Kratos Anti-Pattern):** Dù đã xóa hàm biến GORM Entity thành Protobuf Message, các UseCase tại `customer/internal/biz/customer/customer.go` vẫn đang `import "gitlab.com/ta-microservices/customer/internal/model"` và return thẳng các con trỏ định dạng `*model.Customer`. Theo Clean Architecture Kratos, tầng Biz **phải định nghĩa Domain Struct thuần túy** (chỉ chứa business logic, không chứa gorm tag). **Yêu cầu:** Tách bạch Domain Model khỏi Data Model, viết mapper tại tầng Service `customer_convert.go` tương tự như cách Order Service hoặc Payment Service đang triển khai chuẩn mực.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Architecture/API] Chặn Đứng Rò Rỉ Data Model Trực Tiếp Lên API Layer:** Hàm `ToCustomerReply()` và `ToStableCustomerGroupReply()` vốn dĩ vi phạm nghiêm trọng luật MVC (cắm mã gen protobuf vào bên trong GORM model) ĐÃ ĐƯỢC XÓA BỎ HOÀN TOÀN khỏi `internal/model/customer.go`. Model giờ chỉ thuần túy là định dạng DB schema.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Dự án phần lớn bám sát được bộ khung Clean Architecture:
- **Ngăn Chặn GORM Rò Rỉ Tuyệt Đối:** Quét toàn bộ source code của `internal/biz`, KHÔNG CÓ sự xuất hiện của `gorm.DB` hay logic Query. Tầng Biz (Domain) 100% decoupling khỏi hạ tầng lưu trữ.
- **Repository Pattern Ổn Định:** Lời gọi từ Biz xuống Data thông qua Interfaces (`CustomerRepo`), giúp mock testing cực thuận lợi khi dùng `mockgen`.

### 2. Sự Cố Rò Rỉ Khái Niệm Ở Tầng Biz (Lỗi P1 Xuyên Thủng Domain) 🚩
Sự cố của **Customer Service**:
- Data Entity `Customer` nằm ở `internal/model` chứa chằng chịt tag của GORM.
- **Vấn đề:** Ở Tầng Biz (`customer/internal/biz`), các UseCase lại return thẳng kiểu Data Entity `*model.Customer`. Điều này khiến thư mục `biz` - vốn dĩ phải là nơi độc lập định nghĩa Domain Rules - lại phải Import Data Model phụ thuộc.
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
- **Tuyệt đối nghiêm cấm:** Việc import `internal/model` vào thẳng Tầng Transport (Service) để làm rò rỉ cấu trúc Database cho Frontend.

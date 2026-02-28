# Báo Cáo Phân Tích Code: Clean Architecture & Domain Separation (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review sự cô lập giữa các tầng kiến trúc (API -> Biz -> Data) và nguyên tắc Domain-Driven Design (DDD).

---

## 1. Hiện Trạng Triển Khai (The Good - Những điểm làm đúng)

Nhìn chung, dự án bám sát bộ khung Clean Architecture do Kratos đề xuất:
1. **Tuyệt đối không rò rỉ Database Detail:** Quét toàn bộ source code của thư mục `internal/biz` ở tất cả microservices, hoàn toàn KHÔNG CÓ sự xuất hiện của `gorm.DB` hay các khái niệm liên quan đến SQL/Postgres. Tầng Biz (Domain) hoàn toàn sạch sẽ và độc lập với công nghệ lưu trữ.
2. **Repository Pattern Chuẩn Mực:** Các lời gọi từ Biz xuống DB đều thông qua các interface rõ ràng (ví dụ: `CustomerRepo interface`). Điều này giúp Unit Test ở tầng Biz cực kỳ dễ dàng bằng tay hoặc dùng Gomock.

---

## 2. Các Lỗ Hổng Kiến Trúc Cực Tiêu Cực (Khủng Hoảng Clean Architecture) 🚩

### 🚩 2.1. Lỗi "Đi Tắt Đón Đầu" Ở Customer Service (P0 - Xuyên Thủng Layer)
Đây là một trong những lỗi tồi tệ nhất của Clean Architecture (Anti-pattern: Anemic Domain Model + Leaky Abstraction).

Tại service **Customer**:
1. Tệp `internal/model/customer.go` chứa struct `Customer` với chi chít các tag của GORM:
   ```go
   type Customer struct {
       ID uuid.UUID `gorm:"type:uuid;primaryKey"`
       // ...
   }
   ```
   *👉 Đây chính xác là Data Entity (Entity gắn chặt với Cấu trúc Bảng Postgres).*

2. Nhưng điều đáng sợ là, ngay bên dưới Data Entity đó, dev lại gắn thêm hàm `ToCustomerReply()`:
   ```go
   func (m Customer) ToCustomerReply() *pb.Customer { ... }
   ```
   *👉 Tức là Data Entity có khả năng tự biến hình thành Protobuf Message (tầng API Transport).*

3. Xấu hơn nữa ở **Tầng Biz** (`customer/internal/biz/customer/customer.go`), các UseCase lại return thẳng kiểu Data Entity `*model.Customer` này. Khiến cho file `biz` - vốn dĩ phải là nơi cao quý nhất, không phụ thuộc vào hạ tầng - nay lại `import "gitlab.com/ta-microservices/customer/internal/model"` (chứa gorm tags).

**Mô hình đang chạy thực tế:**
`API (Protobuf)` <--- `Biz Layer` (return model) <--- `Data Layer` (gorm model)

**Hệ luỵ nhãn tiền:**
- Nếu DBA (Database Admin) yêu cầu đổi tên cột trong bảng Customer, sửa tag GORM. Bạn có thể vô ý làm rụng luôn trường đó trên luồng trả về cho Frontend (Mobile App / Web) thông qua Protobuf vì chúng dính chặt làm 1.
- Biz Layer không còn là "Trung tâm vũ trụ" định nghĩa Luật chơi (Domain Entities), mà Biz Layer đang nằm dưới quyền sinh sát của Data Layer (GORM models lũng đoạn Business).

### 🚩 2.2. Sự Bất Nhất Giữa Các Team (Inconsistency - P1)
Trái ngược với đống đổ nát ở Customer Service... Thì đội code **Order Service** lại làm **Rất Chuẩn Mực**.

Tại service **Order** (`order/internal/service/order_convert.go`):
Dev tách bạch hoàn toàn 3 thế giới:
1. Data Model (`order/internal/model` - Chỉ chứa GORM tags).
2. Domain Model (`order/internal/biz` - Các struct thuần Go, mang business rules, không có tag json/gorm).
3. API DTO (Protobuf models).

Ở tầng Service (`order_convert.go`), dev viết các hàm mapper rạch ròi:
- `convertOrderDomainOrderToBizOrder` (Map từ Biz sang DTO).
- `convertBizCreateOrderRequestToOrderDomain` (Map DTO vào Biz).
- Tuyệt đối Data Model (`model.Order`) không ló mặt ra khỏi ranh giới của `internal/data`.

---

## 3. Bản Chỉ Đạo Refactor Lớp Lang (Clean Architecture Roadmap)

Để giải quyết mớ hỗn độn này, phải ép toàn hệ thống theo chuẩn của **Order Service**.

### ✅ Tái Cấu Trúc File & Struct Data

**Bước 1: Giết chết sự liên kết Bảng-DB với DTO Protocol Buffers**
- Vào tất cả các tệp `internal/model/*.go` (Đặc biệt là Customer Service).
- **Xóa ngay lập tức** các hàm như `ToCustomerReply()`, `ToStableCustomerGroupReply()`. Tầng model là các túi chứa dữ liệu GORM, nó không có tư cách tự xưng là DTO.

**Bước 2: Chuẩn Hóa Biz Layer (Domain Model)**
- Trong `internal/biz`, định nghĩa lại các Domain Struct thuần Go.
  ```go
  // internal/biz/customer.go
  type Customer struct {
      ID          string
      Email       string
      CustomerType int
      // Thuần logic nghiệp vụ, cấm gắn tag sql hay gorm
  }
  ```
- Repo từ `internal/data` lấy Data Entity từ DB xong, phải tự map sang Domain Entity chuẩn rồi mới trả lên cho `internal/biz` xài.

**Bước 3: Tầng Service Làm Trạm Trung Chuyển (DTO Mappers)**
- Ở `internal/service/`, tạo ra các file `*_convert.go` (giống cách Order Service đang làm).
- File này có nhiệm vụ map từ Domain Entity (do `biz` xử lý xong) sang Protobuf Message (`pb.<Struct>`).

**Tóm gọn Rule (Bắt buộc Code Reviewer tuân thủ):**
> 1. Biz gọi Data ➔ Data trả về Biz Model ➔ Biz xử lý Logic dựa trên Biz Model.
> 2. API gọi Service ➔ Service gọi Biz ➔ Biz trả về Biz Model ➔ Service map Biz Model thành Protobuf ➔ Trả về API.
> 3. Tuyệt đối nghiêm cấm việc import Data Models (có GORM tag) vào thẳng Tầng Service hoặc để nó làm rò rỉ ra Protobuf Reply.

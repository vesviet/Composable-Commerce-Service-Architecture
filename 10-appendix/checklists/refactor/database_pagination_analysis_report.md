# 📋 Báo Cáo Phân Tích & Code Review: Database Pagination & N+1 Queries

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Khảo sát hiệu năng truy xuất Database, nhận diện các vấn đề N+1 Query và Offset Pagination.  
**Trạng thái Review:** Lần 2 (Đã đối chiếu với Codebase Thực Tế - Phần Lớn CHƯA FIX)

---

## 🚩 PENDING ISSUES (Unfixed - CẦN ACTION GẤP)
- **[🚨 P0] [Performance/Database] Lạm dụng Preload sinh ra N+1 Query (Greedy Fetching):** Qua scan thực tế, `Preload` vẫn xuất hiện chi chít trong các hàm `List`. Điển hình: `warehouse.go` dòng 160 (`query.Preload("Locations").Find(&results)`), và `order.go` với một rổ các lệnh `Preload("Items")`, `Preload("ShippingAddress")`... Việc gọi `List` sinh ra hàng loạt câu SQL phụ, làm chậm API nghiêm trọng. **Yêu cầu Khẩn cấp:** Chuyển các hàm List lấy mảng sang dùng `db.Joins("...").Select("...")` hoặc tách Query, đặc biệt ở service `order` và `warehouse`.
- **[🟡 P1] [Performance/Database] Hầu Hết Service Vẫn Dùng Offset Pagination Cho Bảng Lớn:** Khảo sát code `order.go` vẫn dậm chân tại chỗ với hàm `Offset().Limit()`. Chỉ duy nhất file `transaction.go` trong warehouse là có nhúc nhích refactor sang các hàm `ListCursor` sử dụng `pagination.NewCursorPaginator(cursorReq)`. **Yêu cầu:** Mở rộng ngay mô hình `CursorPaginator` của `transaction.go` sang `order.go` (ví dụ bảng `orders` phình to rất nhanh).
- **[🔵 P2] [Performance/K8s] Trả Về Danh Sách Không Có Limit (OOM RAM Risk):** Kiểm tra `warehouse/internal/data/postgres/warehouse.go` (hàm `GetLocations`) và `transaction.go` (hàm `GetByReference`), thấy rõ đang dùng chuỗi `.Find(&results).Error` vô tội vạ mà KHÔNG CÓ `.Limit(X)`. Nếu nhét 100k records vào hàm `GetByReference`, Worker/API Pod sẽ nổ tung vì OOM (Out of Memory). **Yêu cầu:** Hardcode một giới hạn an toàn `.Limit(1000)` hoặc bắt buộc nhét Pagination vào các hàm lấy danh sách quan hệ nội bộ này.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Framework] Hoàn thiện thuật toán Keyset/Cursor Paginator:** Gói utils `common/utils/pagination/cursor.go` đã được thiết kế thành công và Codebase ĐÃ BẮT ĐẦU sử dụng nó (Điểm sáng tại `warehouse/internal/data/postgres/transaction.go` -> Hàm `ListCursor` và `GetByWarehouseCursor`). Rất đáng khen cho nỗ lực thí điểm này.
- **[FIXED ✅] [Performance/Database] Sửa Lỗi N+1 Tại Transaction Repo:** Hàm `List` trong `transaction.go` đã được đập đi xây lại, thay `Preload("Warehouse")` bằng `Joins("LEFT JOIN warehouses ON stock_transactions.warehouse_id = warehouses.id")`. Một bản Fix mẫu mực để các Repositories khác học tập.

---

## 📋 Hướng Dẫn Kỹ Thuật (Guidelines Từ Senior)

### 1. 🗄️ Vấn Đề Phân Trang (Mệnh Lệnh Chuyển Đổi Sang Keyset)
Offset-based Pagination (`LIMIT X OFFSET Y`) là Anti-pattern nghiêm trọng khi số lượng dòng vượt qua 100,000. PostgreSQL vất vả scan hàng ngàn dòng trước khi drop để trả đúng cái Offset đằng sau.
- **Tình trạng:** Khá lẹt đẹt. Mới chỉ có `transaction.go` áp dụng Cursor.
- **Lệnh:** Dev phụ trách `order` và `fulfillment` nhanh chóng nhân bản cấu trúc `ListCursor` của warehouse qua mảng Order.

### 2. 🐢 Cấm Khấn `Preload()` Đối Với Tập Dữ Liệu Lớn (List)
Sự "dễ dãi" của GORM `Preload()` đã sản sinh mã độc N+1 Query.
- Thay vì: `err := query.Preload("Locations").Find(&results).Error`
- Bắt buộc Refactor thành (cho List API):
  ```go
  db.Table("warehouses w").
     Select("w.id, w.name, l.location_code"). // Lấy vừa đủ dùng
     Joins("LEFT JOIN warehouse_locations l ON w.id = l.warehouse_id").
     Find(&dtos)
  ```

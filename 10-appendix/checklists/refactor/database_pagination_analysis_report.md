# 📋 Báo Cáo Phân Tích & Code Review: Database Pagination & N+1 Queries

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Khảo sát hiệu năng truy xuất Database, nhận diện các vấn đề N+1 Query và Offset Pagination.  
**Trạng thái Review:** Đã Review - Cần Refactor  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P0] [Performance/Database] Lạm dụng Preload sinh ra N+1 Query (Greedy Fetching):** Các file Repository như `warehouse.go`, `transaction.go` và `order.go` vẫn giữ nguyên lệnh `Preload(...)` cho các hàm danh sách (`List`, `FindByLocation`, `GetByDateRange`...). Việc gọi `List` sinh ra hàng loạt câu SQL phụ, gây lãng phí Network I/O và phình to RAM của App do Cartesian Product hoặc Select dư thừa. **Yêu cầu:** Tuyệt đối cấm dùng `Preload` trong hàm `List` đối với các quan hệ `belongs-to`. Phải chuyển đổi thành lệnh `db.Joins("...").Select("...")` trả về đúng các cột cần thiết cho DTO.
- **[🟡 P1] [Performance/Database] Chưa áp dụng Keyset/Cursor Pagination cho các bảng lớn:** Gói Helper `common/utils/pagination/cursor.go` đã được Core Team xây dựng, nhưng ở tất cả các tầng Repository, logic cũ `(Page-1)*Size` vẫn đang được sử dụng. Phép toán `OFFSET` bắt DB scan-and-discard, cực kỳ tốn CPU ở các bảng như `orders`, `stock_transactions`. **Yêu cầu:** Refactor luồng Query danh sách của `warehouse` và `order`, đổi sang sử dụng struct `CursorPaginator` thay vì Offset thông thường khi quy mô data > 100k dòng.

## 🆕 NEWLY DISCOVERED ISSUES
- **[Performance/K8s] Tham số trả về danh sách không có Limit (OOM RAM Risk):** Một số hàm nội bộ phục vụ hệ thống (như `GetByReference` trong `transaction.go`, `GetLocations` trong `warehouse.go`) trả về mảng danh sách (`Slice`) nhưng hoàn toàn KHÔNG SỬ DỤNG cấu trúc Offset/Limit hay Cursor. Điều này rủi ro tạo ra Memory Leak / OOM Killed ở các Worker Pods trên K8s khi tập dữ liệu phình to. **Suggested Fix:** Bắt buộc áp dụng cơ chế pagination an toàn, hoặc hardcode một giới hạn an toàn `.Limit(5000)` cho mọi List API phục vụ nghiệp vụ nội bộ.

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Framework] Hoàn thiện thuật toán Keyset/Cursor Pagination:** Gói utils `common/utils/pagination/cursor.go` đã được thiết kế thành công với cấu trúc `CursorRequest`, `CursorResponse` và `CursorPaginator`. Logic `id > last_cursor` đã chuẩn xác, tạo tiền đề để các service tiến hành di chuyển (migrate).

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. 🗄️ Vấn Đề Phân Trang (Offset v.s Keyset)
Theo tiêu chuẩn hệ thống lớn, **Offset-based Pagination** (dùng `LIMIT X OFFSET Y`) là Anti-pattern nghiêm trọng khi số lượng dòng vượt qua 100,000. PostgreSQL phải đọc, parse toàn bộ `OFFSET` rows trước khi bỏ đi.
- **Thực trạng:** Codebase vẫn lạm dụng func `GetOffset()` từ `common/utils/pagination/pagination.go`.
- **Hệ lụy:** Gây spike CPU Database, chậm API tịnh tiến theo thời gian.
- **Chỉ đạo:** Cần chuyển sang Query mỏ neo: `SELECT * FROM table WHERE id > 'last_cursor' ORDER BY id ASC LIMIT 20;`.

### 2. 🐢 Lỗ Hổng N+1 Queries (GORM `Preload`)
Sự tiện lợi của GORM `Preload()` đang làm hỏng hiệu năng hệ thống khi trả về List.
- **Thực trạng:** Code `err = r.DB(ctx).Preload("Warehouse").Preload("FromWarehouse").Find(&results)` quét ra 4 truy vấn riêng biệt cho 1 API Request.
- **Hệ lụy:** Request latency tăng cao, lãng phí bộ nhớ lưu các struct con không cần thiết.
- **Chỉ đạo:** Yêu cầu Dev sử dụng GORM Session an toàn:
  ```go
  db.Table("transactions t").
     Select("t.id, t.amount, w.name as warehouse_name").
     Joins("LEFT JOIN warehouses w ON w.id = t.warehouse_id").
     Find(&results)
  ```

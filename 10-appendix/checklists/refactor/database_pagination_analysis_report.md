# Báo Cáo Phân Tích: Database Pagination & N+1 Queries (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Khảo sát hiệu năng truy xuất Database, tập trung vào hai "Sát thủ" thầm lặng giết chết Database ở quy mô lớn: N+1 Query và Offset Pagination.

---

## 1. 🗄️ Vấn Đề Phân Trang (Offset v.s Keyset Pagination)

Khi xem xét cách các Service (đặc biệt là `warehouse`, `order`) phân trang dữ liệu trả về cho Admin Dashboard hoặc Client, tôi nhận thấy một Anti-pattern kinh điển.

### 1.1. Lỗ Hổng Hiệu Năng (P1) 🚩
Toàn bộ hệ thống đang dựa vào một Helper duy nhất tại `common/utils/pagination/pagination.go` để tính toán phân trang:
```go
// GetOffset returns calculated offset for database query
func (p *Paginator) GetOffset() int {
	return (p.request.Page - 1) * p.request.PageSize
}
```
Và dưới tầng Repository (`internal/data/postgres`), Dev viết query như sau:
```go
query = query.Offset(int(offset)).Limit(int(limit))
```

**Tại sao đây là Lỗ Hổng?**
Đây gọi là **Offset-based Pagination**. Trong PostgreSQL, lệnh `LIMIT 20 OFFSET 100000` không có nghĩa là DB nhảy đến dòng 100,000 rồi lấy 20 dòng. Nó bắt Database **đọc, parse và loại bỏ 100,000 dòng đầu tiên** trước khi trả về 20 dòng bạn cần. 
- Ở 10,000 records đầu: API chạy mất 20ms.
- Ở 1,000,000 records: API chạy mất 5-10 giây, kéo theo CPU DB tăng vọt (Spike).
Đối với hệ thống E-commerce, số lượng Order và Transaction lịch sử sẽ tăng tịnh tiến cực nhanh, việc sập DB khi CSKH bấm sang trang 5000 là chuyện một sớm một chiều.

### 1.2. Giải Pháp Chỉ Đạo (Keyset Pagination / Cursor)
Bắt buộc bổ sung thuật toán **Cursor-based Pagination (Keyset Pagination)** vào gói `common/utils` và áp dụng cho các Table có khối lượng dữ liệu khổng lồ (VD: `orders`, `event_outbox`, `event_idempotency`, `warehouse_transactions`).
Thay vì truyền `page=5000`, Client phải truyền `cursor=last_seen_id`.
```sql
-- Query chuẩn (Dùng Index, cực nhanh dù ở dòng 1 tỷ)
SELECT * FROM orders WHERE id > 'last_seen_id' ORDER BY id ASC LIMIT 20;
```

---

## 2. 🐢 Vấn Đề N+1 Queries & Lạm Dụng Preload

GORM (ORM đang dùng trong dự án) cực kỳ tiện lợi với tính năng lập trình `Preload()`. Rất tiếc, sự tiện lợi sinh ra sự lười biếng.

### 2.1. Lỗ Hổng "Greedy Fetching" (P1) 🚩
Review tại `warehouse/internal/data/postgres/warehouse.go` và `transaction.go`, tôi phát hiện Dev lạm dụng Preload theo kiểu "Bắt nhầm còn hơn bỏ sót":
```go
err = r.DB(ctx).Preload("Warehouse").Preload("FromWarehouse").Preload("ToWarehouse").Find(&results)
```
- Khi chạy hàm `Find()` để lấy danh sách (List - 50 items), dòng code trên sẽ khiến GORM bắn ra **4 Câu SQL riêng biệt** vào Database:
  1. Lấy 50 Transactions.
  2. Lấy danh sách Warehouse tản mạn của 50 Transaction đó.
  3. Lấy FromWarehouse...
  4. Lấy ToWarehouse...

**Hệ Lụy:**
1. Rác băng thông mạng (Network I/O) giữa App và Database, vì load toàn bộ thông tin Warehouse (Bao gồm các cột TO_TEXT không cần thiết) chỉ để lấy `WarehouseName` hiển thị.
2. RAM của App phình to vì phải chứa toàn bộ struct đồ sộ.

### 2.2. Giải Pháp Chỉ Đạo (Joins & DTO Select)
1. **Tuyệt đối cấm lạm dụng Preload trong các hàm `List/Search`**. `Preload` chỉ được phép dùng ở các hàm `GetByID` (lấy 1 record).
2. Với các hàm `List`, yêu cầu Dev sử dụng lệnh `.Joins()` của GORM và dùng `.Select()` để chỉ Parse những cột thực sự cần thiết trả về cho DTO.
```go
// Truy vấn 1 lần duy nhất, lấy đúng những cột cần thiết
db.Table("transactions t").
   Select("t.id, t.amount, w.name as warehouse_name").
   Joins("LEFT JOIN warehouses w ON w.id = t.warehouse_id").
   Find(&results)
```

---

## 3. Tổng Kết Khuyến Nghị

* **Pagination:** Chấp nhận Offset for Data Admin (các bảng nhỏ, ít tăng trưởng như Users Admin, Phân quyền). Yêu cầu Cursor-Based cho rốn dữ liệu khổng lồ (Orders, Transactions, Logging).
* **N+1 / OOM RAM:** Audit lại toàn bộ các hàm `List` ở mọi Repository. Bỏ lệnh `Preload`, đập đi xây lại bằng `.Joins()`.

# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Database & GORM

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review cách các microservice giao tiếp với Database thông qua GORM, Connection Pooling, và Transaction Management.  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🟡 P1] [Architecture/Maintainability] Phân Mảnh Trầm Trọng Transaction Manager (Tự Chế Bánh Xe):** Kiểm tra mã nguồn, các Service như `checkout` (trong `checkout/internal/data/data.go`) và `shipping` (trong `shipping/internal/biz/transaction.go`) đang tự đẻ ra các Struct/Interface Transaction riêng rẽ (như `dataTransactionManager`, `PostgresTransactionManager`). Việc bỏ qua thư viện Lõi để viết lại logic quản lý TX gây ra rủi ro Deadlock hoặc Leak Connection khi block `Rollback()` bị sai dòng. **Yêu cầu (Hard-Requirement):** Xóa bỏ toàn bộ các bộ quản lý TX rác ở Service, yêu cầu dùng duy nhất hàm `NewTransactionManager` từ thư mục `common/data/transaction.go` để bơm GORM tx vào Context an toàn.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- *(Tại thời điểm review, refactor thư viện `transaction_manager` vẫn đang tiến hành).*

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Hệ thống sử dụng **GORM** và thiết lập khá bài bản ở lõi:
- **Connection Maker:** Logic tạo connection nằm trọn trong `common/utils/database/postgres.go`, setup sẵn Connection Pooling (`MaxOpenConns`, `MaxIdleConns`) chuẩn Enterprise.
- **Repository Pattern:** Generics Interface `[T any]` tại `common/repository/base_repository.go` đã bọc sẵn 100% CRUD operations (Find, Create, List...). Dev chỉ cần nhúng vào là xài.

### 2. Sự Lệch Chuẩn Ở Transaction Manager (P1) 🚩
Thư viện lõi đã dọn đường sẵn một interface:
```go
// common/repository/transaction.go
type TransactionManager interface {
    WithTransaction(ctx context.Context, fn func(ctx context.Context) error) error
}
```
**Nhưng Backend Dev lại thi nhau "Reinvent the wheel":**
- `Checkout Service`: Tự định nghĩa `dataTransactionManager`, tự nhét TX vào `context.WithValue`.
- `Shipping Service`: Vẽ lại nguyên một interface `TransactionManager` và struct `PostgresTransactionManager` khác hoàn toàn bản gốc.
- `Pricing Service`: Ép Repo tự implement TX thủ công.

**Hệ Lụy:**
Mạnh ai nấy copy-paste code quản lý giao dịch dễ sinh ra:
1. Deadlock toàn Database nếu quên Rollback khi Panic.
2. Leak connection pool của GORM, làm sập App khi tải cao.
3. Không thể xài chung một bộ Unit Test Mock (`MockTransactionManager`).

### 3. Giải Pháp Chỉ Đạo Từ Senior
Lấy lại quyền kiểm soát Transaction Management về tay Core Team bằng một struct chuẩn duy nhất:

```go
// common/data/transaction.go
type GormTransactionManager struct {
	db *gorm.DB
}

func (tm *GormTransactionManager) WithTransaction(ctx context.Context, fn func(ctx context.Context) error) error {
	return tm.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		txCtx := injectTx(ctx, tx)
		return fn(txCtx)
	})
}
```
Sau đó, yêu cầu các team ở Checkout, Shipping vào tệp `wire.go` (`provider.go`), **Inject thẳng `commonData.NewTransactionManager` lên Biz layer**. Toàn bộ UseCase sẽ bắt buộc dùng chung chuẩn Transaction duy nhất này từ trên xuống dưới. Mọi custom code đều sẽ bị Reject lúc Merge.

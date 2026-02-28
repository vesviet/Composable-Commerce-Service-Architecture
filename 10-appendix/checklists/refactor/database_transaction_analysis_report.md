# Báo Cáo Phân Tích Code Kiến Trúc Database & GORM (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review cách các microservice giao tiếp với Database thông qua GORM, Connection Pooling, và Transaction Management.

---

## 1. Hiện Trạng Triển Khai (How Database is Implemented)

Hệ thống đang sử dụng **GORM** làm ORM chính để giao tiếp với PostgreSQL.
- **Connection Maker:** Đội ngũ kiến trúc đã làm rất tốt việc quy tụ logic tạo connection vào `common/utils/database/postgres.go`. File này bọc sẵn hàm `NewPostgresDB` xử lý gọn gàng Connection Pooling (`MaxOpenConns`, `MaxIdleConns`, `ConnMaxLifetime`), Logger, và AutoMigrate.
- **Repository Pattern:** Dự án sở hữu một Generic Repository cực xịn tại `common/repository/base_repository.go`. File này sử dụng Generics (`[T any]`) bọc sẵn 100% các hàm CRUD cơ bản (FindByID, Create, Update, Delete, List pagination + filter). Mọi model chỉ cần cắm vào là chạy.

---

## 2. Các Vấn Đề Lớn Phát Hiện Được (Critical Smells) 🚩

Mặc dù tầng Core/Common thiết kế khá tốt, nhưng khi áp dụng xuống Business Logic (đặc biệt là xử lý giao dịch - Transaction), các service đang tự phân mảnh nghiêm trọng.

### 🚩 2.1. reinventing the wheel ở Transaction Manager (P1)
**Vấn đề:** 
Xử lý giao dịch phân tán/cục bộ là xương sống của e-commerce. Thư viện common đã rào trước bằng việc định nghĩa sẵn một interface:
```go
// common/repository/transaction.go
type TransactionManager interface {
    WithTransaction(ctx context.Context, fn func(ctx context.Context) error) error
}
```
Và trong `base_repository.go` cũng có sẵn hàm lấy TX ra từ Context: `GetDB()`.

**NHƯNG**, các Service lại đang lờ đi thư viện này và thi nhau tự chế lại bánh xe:
- Ở **Checkout Service** (`checkout/internal/data/data.go` dòng 61-78): Dev tự định nghĩa lại struct `dataTransactionManager` và nhét gorm instance vào Context thông qua `context.WithValue(ctx, ctxTransactionKey{}, tx)`.
- Ở **Shipping Service** (`shipping/internal/biz/transaction.go`): Thi nhau thiết kế interface `TransactionManager` riêng của biz, sau đó viết struct adapter `PostgresTransactionManager`.
- Ở **Pricing Service** (`pricing/internal/data/postgres/price.go`): Cố ép repo implement hàm transaction thủ công.

**Hệ luỵ:**
Tình trạng mạnh ai nấy code Transaction Manager sẽ dẫn tới:
- Tràn lan Deadlock nếu logic Rollback ở mỗi service tự chế bị sai lệch.
- Gorm DB Connection bị leak nếu dev quên đóng block Transaction.
- Sự phân mảnh trong Unit Tests: Mồi service lại đẻ ra một `MockTransactionManager` khác nhau trong thư mục `testdata` của mình.

---

## 3. Bản Chỉ Đạo Refactor Từ Senior (Clean Architecture Roadmap)

Để giải quyết vấn đề phân mảnh Transaction, Core Team phải lấy lại quyền kiểm soát từ tay các Services.

### ✅ Giải pháp: Gom chuẩn hóa Transaction Context vào Common Lib

**B1: Tại thư viện `common` (common/data/transaction.go):**
Xây dựng một Data Transaction Manager chuẩn mực và duy nhất cho toàn cõi:
```go
package data

import (
	"context"
	"gorm.io/gorm"
)

type txKey struct{}

// Hàm inject Gorm TX vào context (chống override)
func injectTx(ctx context.Context, tx *gorm.DB) context.Context {
	return context.WithValue(ctx, txKey{}, tx)
}

// Hàm lấy Gorm ra khỏi context dùng cho Repository
func GetDB(ctx context.Context, defaultDB *gorm.DB) *gorm.DB {
	if tx, ok := ctx.Value(txKey{}).(*gorm.DB); ok {
		return tx
	}
	return defaultDB.WithContext(ctx)
}

// GormTransactionManager dùng chung toàn dự án
type GormTransactionManager struct {
	db *gorm.DB
}

func NewTransactionManager(db *gorm.DB) *GormTransactionManager {
	return &GormTransactionManager{db: db}
}

func (tm *GormTransactionManager) WithTransaction(ctx context.Context, fn func(ctx context.Context) error) error {
	return tm.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		txCtx := injectTx(ctx, tx)
		return fn(txCtx)
	})
}
```

**B2: Xóa sổ các "môn phái" Transaction tự chế ở Services:**
- Xóa `checkout/internal/data/data.go` (đoạn dataTransactionManager).
- Xóa `shipping/internal/biz/transaction.go`.
- Tại file Wire (`provider.go`), chỉ cần Inject thẳng `commonData.NewTransactionManager` lên Biz layer. Mọi UseCase sẽ dùng chung một chuẩn Transaction từ trên xuống dưới.

Điều này đảm bảo quy tắc "Transaction Boundary" được gác cổng an toàn tuyệt đối, chấm dứt chuỗi ngày Database deadlock do copy-paste code.

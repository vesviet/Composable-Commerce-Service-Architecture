# Báo Cáo Phân Tích Code Kiến Trúc Caching (Redis) (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review cách các microservice triển khai chiến lược Caching (phân tán & cục bộ), Redis integration và rủi ro phân mảnh.

---

## 1. Hiện Trạng Triển Khai (How Caching is Implemented)

Dự án đang sử dụng **Redis** làm Distributed Cache chính.
1. **Tầng Core/Lõi (The Good):** Đội ngũ kiến trúc đã thiết kế một giải pháp Caching Type-Safe (bảo vệ kiểu dữ liệu lúc biên dịch) tại thư viện `common/utils/cache/typed_cache.go`.
   - Sử dụng **Go Generics** (`TypedCache[T any]`) kết hợp với `redis.Client`.
   - Giải quyết triệt để lỗi casting data (Ví dụ: lưu Cache object User, kéo ra ép kiểu nhầm sang Product).
   - Tích hợp sẵn `CacheMetrics` theo dõi Hit/Miss ratio.
   - Hỗ trợ `GetOrSet` (Lazy loading cache pattern) kinh điển.
2. **Local Caching:** Có sử dụng `go-cache` in-memory cho những tham số hiếm khi thay đổi (Ví dụ: IP lookup trong `common/geoip` module lưu 24h trên RAM để đỡ tốn tiền gọi API).

---

## 2. Các Vấn Đề Khủng Hoảng Phát Hiện Được (Critical Smells) 🚩

### 🚩 2.1. reinventing the wheel ở Tầng Service (P1)
**Vấn đề:** 
Lịch sử lặp lại như bài toán Transaction và Dapr. Bọn DevOps/Core team đã nhọc nhằn viết ra Generic `TypedCache[T]` xịn xò bao nhiêu, thì anh em Dev làm tính năng (Product Dev) lại tạt gáo nước lạnh bấy nhiêu.

Ở **Checkout Service** (`checkout/internal/cache/cache.go`), dev lại đi viết một struct `CacheHelper` bọc quanh cái raw `redis.Client` vừa phèn vừa thủ công:
- Tự manually `json.Marshal(value)` cất vào Redis.
- Tự manually `json.Unmarshal([]byte(data), dest)` kéo ra.

**Hệ luỵ:**
- **Mất Type-Safe:** Vì xài `interface{}`/`dest interface{}` nên lỗi JSON casting sẽ nổ lụp bụp ở Runtime (lúc code chạy Prod) thay vì ở Compile time.
- **Mất Metrics:** Raw redis client không có tính năng đếm Cache Hits/Misses để đẩy lên Grafana. Ops team sẽ mù tịt không biết size cache của Checkout Service đang hoạt động hệu quả tới đâu.
- **Rác Code:** Cứ mỗi data module (User, Order, Cart) lại mọc ra chục dòng boilerplate code cho Encode/Decode JSON.

### 🚩 2.2. Hiểm hoạ Cache Stampede (P2 - Cần rà soát thêm)
Việc Checkout service tự dùng `redis.Get` rồi thấy `redis.Nil` xong tự chọc xuống GORM `Find()`, sau đó gọi tiếp `redis.Set` (Pattern Get-Check-Set thủ công) là cửa ngõ cực lớn để dính lỗi **Cache Stampede (Thundering Herd)**.
Nếu cùng 1 lúc có 100 ông User checkout giỏ hàng lúc 0h khuya săn sale, cả 100 threads đều thấy Cache rỗng và đồng loạt xoã thẳng xuống Postgres 👉 sập DB.
Trong khi đó, `common.TypedCache` có hỗ trợ hàm `GetOrSet()` giúp mitigate vấn đề này tốt hơn rất nhiều.

---

## 3. Bản Chỉ Đạo Refactor Từ Senior (Clean Architecture Roadmap)

Để củng cố bộ khiên bảo vệ DB (Caching Layer), Core team cần ép các Service chuẩn hoá theo Generics.

### ✅ Giải pháp: Xóa bỏ CacheHelper tự chế, tái sử dụng TypedCache

**B1: Xóa trắng file Cache rác:**
- Phải nhẫn tâm xóa sạch file `checkout/internal/cache/cache.go`. Khong thoả hiệp.

**B2: Implement Generic Cache ở tầng Repository:**
Ví dụ tại `checkout/internal/data/cart.go` (hoặc nơi nào gọi redis):
Sẽ không Inject raw redis nữa, mà dùng thư viện của common:

```go
import commonCache "gitlab.com/ta-microservices/common/utils/cache"

type cartRepo struct {
    db         *gorm.DB
    cartCache  *commonCache.TypedCache[biz.Cart]
    logger     *log.Helper
}

// Hàm khởi tạo Inject qua Wire
func NewCartRepo(db *gorm.DB, rdb *redis.Client, logger log.Logger) biz.CartRepo {
    return &cartRepo{
        db: db,
        // Chỉ ra kiểu rõ ràng biz.Cart, TTL 30 phút, metric theo dõi
        cartCache: commonCache.NewTypedCache[biz.Cart](rdb, "checkout:cart", 30*time.Minute, logger),
        logger: log.NewHelper(logger),
    }
}
```

Và thay vì code bẩn `Get -> Unmarshal`, giờ đây:
```go
// Sang, Xịn, Mịn, Type-Safe 100%
cartObj, err := r.cartCache.Get(ctx, customerID) 
```

### ✅ Chỉ đạo phòng tránh Cache Stampede
Nghiêm cấm dev tự code `if cache == nil { GetDB(); SetCache() }`.
Bắt buộc dùng:
```go
cartObj, err := r.cartCache.GetOrSet(ctx, customerID, loadCartFromDBFunc, 30*time.Minute)
```
Mọi hành vi vi phạm ở các PR (Pull Request) đều bị Reject thẳng tay không cần giải thích.

# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Caching (Redis)

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review chiến lược Caching (phân tán & cục bộ), Redis integration và phòng chống Cache Stampede.  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🟡 P2] [Performance/Reliability] Hiểm Họa Cache Stampede (Thundering Herd):** Dù Checkout Service đã chuyển sang dùng `TypedCache`, kết quả scan cho thấy **hàm `GetOrSet` vẫn chưa được gọi ở bất kỳ vị trí nào**. Logic "Check rỗng -> Query DB -> Set Cache" thủ công vẫn còn tồn tại. Khi 1000 users cùng săn sale lúc nửa đêm, Cache Miss sẽ vả thẳng 1000 query vào DB làm sập hệ thống. **Yêu cầu:** Bắt buộc thay thế thao tác Get/Set thủ công bằng vũ khí tối thượng `GetOrSet` của thư viện `commonCache` để chặn đứng Cache Stampede block các luồng đọc ghi đồng thời trùng lặp.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Architecture/Type-Safety] Xóa Bỏ CacheHelper Tự Chế Tại Checkout Service:** Lỗi nghiêm trọng mất type-safety (dùng `interface{}`) đã được xử lý triệt để. File rác `checkout/internal/cache/cache.go` đã bị xóa bỏ. Checkout Service hiện đã áp dụng 100% Generic `commonCache.NewTypedCache[T]` kết nối chuẩn qua Redis. Các lỗi parsing JSON được đẩy về Compile Time, Metrics Hit/Miss đã được xuất thành công lên Grafana.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Gói lõi kiến trúc `common/utils/cache/typed_cache.go` được thiết kế cực kỳ xuất sắc:
- Sử dụng **Go Generics** (`TypedCache[T any]`) thay vì `interface{}`/`reflect`. Cấm tiệt chuyện lưu User nhưng kéo ra Product.
- **Tích hợp Metrics đo lường:** Theo dõi Hit/Miss Ratio qua Prometheus.
- Cung cấp sẵn các Pattern xịn: `GetOrSet` (chống Thundering Herd) kinh điển.

### 2. Sự Cố Rác Code Ở Tầng Service (Đã Fix)
Checkout Service (Product Dev) từng lờ đi thư viện Lõi (Ops/Core Team) và tự đẻ ra `CacheHelper`:
- Code thủ công `json.Marshal(value)` và `json.Unmarshal([]byte(data), dest)`.
- **Hậu quả cũ:** Mất hoàn toàn type-safe (trả giá đắt trên Production nếu JSON schema lệch vế), mất Metrics đếm size cache, code rườm rà lặp lại ở mọi module. Lỗi này đã được dập tắt nhờ đợt Review trước.

### 3. Hiểm Họa Cache Stampede Điểm Chí Tử (P2) 🚩
Mặc dù đã xài Generic `TypedCache`, cấu trúc luồng của Checkout Service lại đang code như vầy:
```go
cartObj, err := r.cartCache.Get(ctx, customerID) 
if err != nil || cartObj == nil { 
     // Gọi thẳng xuống DB Repo, Rất Nguy Hiểm!
     dbData := GetFromDB()
     r.cartCache.Set(ctx, customerID, dbData)
}
```
**Phân tích rủi ro:** 100 requests cùng giã vào Key A đang hết hạn -> 100 requests đều vượt qua dòng `if cartObj == nil` -> Cả 100 chạy chọc thủng DB lấy dữ liệu. Postgres sẽ chết ngắc.

### 4. Giải Pháp Chỉ Đạo Từ Senior
Thay vì gõ thủ công 10 dòng lệnh tiềm ẩn thảm họa, yêu cầu quy hoạch toàn bộ việc đọc DB có cache bằng One-liner `GetOrSet`:

```go
// Sang, Xịn, Type-Safe 100% + Chống Stampede Locking
cartObj, err := r.cartCache.GetOrSet(ctx, customerID, func() (biz.Cart, error) {
    // Luồng này chỉ chạy 1 lần duy nhất dù có 1000 requests tới cùng lúc!
    return r.loadCartFromDB(ctx, customerID)
}, 30*time.Minute)
```
Mọi hành vi tự ý lặp lại pattern `Get -> If Nil -> DB -> Set` thủ công ở các PR (Pull Request) mới, nếu bị tóm, lập tức Reject thẳng tay không cần giải thích thêm.

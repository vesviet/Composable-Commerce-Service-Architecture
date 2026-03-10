# AGENT-06: Pricing, Promotion & Tax Hardening

> **Created**: 2026-03-10
> **Priority**: P0 (2), P1 (2)
> **Sprint**: Tech Debt Sprint
> **Services**: `pricing`, `promotion`
> **Estimated Effort**: 4 days
> **Source**: [Pricing, Promo & Tax Review Artifact](file:///home/user/.gemini/antigravity/brain/1f3dc9c7-4eac-42c6-925f-8247a7110022/pricing_promo_tax_review.md)

---

## 📋 Overview

Khắc phục các rủi ro sập hệ thống do bùng nổ RAM (OOM) ở thuật toán khuyến mãi BOGO (Buy X Get Y) áp dụng với số lượng đơn sỉ lớn. Sửa lỗi nghiêm trọng (vi phạm pháp luật kế toán) khi bộ đệm cấu hình thuế (Tax Cache) không được xóa đúng cách trên Redis do dùng ký tự Wildcard `*` sai chức năng. Cuối cùng, tối ưu hàm xếp hạng Top Promotion để không kéo toàn bộ Data lên RAM của Golang để Sort.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Dập Tắt Rủi Ro OOMKilled Trong Thuật Toán BOGO

**File**: `promotion/internal/biz/discount_calculator.go`
**Lines**: `82-126` (`CalculateBOGODiscount`)
**Risk**: Hệ thống đang áp dụng chiến thuật Greedy bằng cách "trải phẳng" (Flatten) mảng `Quantity`. Nếu Đơn vị mua sỉ đặt số lượng 100,000, vòng lặp `for q := 0; q < item.Quantity; q++` sẽ cắm trực tiếp 100,000 object vào RAM. Request có thể ăn vài trăm MB RAM gây OOM sập Pod.
**Problem**: Logic đang dùng mảng tuyến tính thay vì Đếm Tần Số (Bucket/Frequency math).

**Fix**:
Viết lại hàm Greedy BOGO bằng **Frequency/Bucket Algorithm**:
1. Groups mảng các Item thỏa mãn `IsBuy` hoặc `IsGet`. 
2. Thay vì thêm từng Unit vào `allUnits`, chỉ lưu Struct: `UnitGroup { Price, Quantity, IsBuy, IsGet }`.
3. Sort mảng `UnitGroup` theo Price Descending.
4. Quét mảng `UnitGroup` bằng con trỏ ảo để tích lũy đủ số lượng `BuyQuantity` thay vì quét từng phần tử vật lý. Khi lấy đủ `Buy`, chạy con trỏ từ dưới lên (Cheapest) để lấy `Get`.
5. Tính công thức trừ Discount bằng phép nhân `amount * quantity_matched` thay vì lặp qua từng phần tử.
6. Xóa bỏ hoàn toàn mảng `allUnits`.

**Validation**:
```bash
cd promotion && go test ./internal/biz -run CalculateBOGODiscount
```

---

### [ ] Task 2: Fix Lỗi Sai Rớt Pháp Lý - Xóa Cache Tax Bị Hỏng Ký Tự Wildcard

**File**: `pricing/internal/biz/tax/tax.go`
**Lines**: `376-378` (`invalidateTaxRuleCache`)
**Risk**: Hệ thống gọi `uc.cache.Invalidate(ctx, baseKey+":cat_*")`. Các backend Cache như Redis không cho phép dùng tham số string literar có chứa dấu `*` để làm lệnh Xóa Hàng Loạt (Hàm DEL chỉ xóa chính xác String `mykey*` chứ không quét tiền tố). Khi Admin update Tax Rate, Cache của người dùng ở các Category CŨ vẫn sống đến hết TTL (vài ngày). Hệ thống tính sai Thuế Nhà Nước, gây hậu quả pháp lý nghiêm trọng.
**Problem**: Xóa pattern không đúng cơ chế Redis.

**Fix**:
1. Đọc lại implementation của `TaxRuleCache`. Nếu Cache lib đang dùng command `DEL`, phải viết lại hoặc tạo func mới `InvalidatePrefix(ctx, prefix string)`.
2. Nếu dùng Redis, phải gọi lệnh `SCAN 0 MATCH prefix*` sau đó lấy mảng ID để truyền vào lệnh `DEL`.
3. Hoặc, nếu `cache` là interface Custom, nâng cấp hàm `Invalidate` của thư viện chứa nó (bên repo `internal/cache` của pricing).

**Validation**:
```bash
cd pricing && go build ./...
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Tối Ưu In-Memory Sort Của Keng Báo Cáo Top Promotions

**File**: `promotion/internal/biz/usage_tracking.go`
**Lines**: `256-355` (`GetTopPerformingPromotions`)
**Risk**: Hàm gọi List TOÀN BỘ Active Promotions không giới hạn (`limit` truyền vào nil), sau đó gọi Bulk Query lấy Stat của toàn bộ hàng chục ngàn Promo đó lên RAM. Kế tiếp, dùng CPU của Go `sort.Slice` rớt mảng hàng chục ngàn Struct. Hiệu năng cực kì thấp `O(n log n)` trên RAM thay vì O(1) Fetch Index ở DB.

**Fix**:
Hệ thống nên ủy quyền Group/Sort này cho Database.
1. Viết 1 query SQL/ORM ở Report hoặc thêm Cache Table tổng hợp (Materialized View / Daily Cronjob).
2. Tạm thời: Ít nhất phải giới hạn List Promotion lấy theo Date Range hoặc Top Active limit 1000 rồi mới Fetch BulkStats. Không được phép kéo All Records.

---

### [ ] Task 4: Vá Thất Thoát Độ Chính Xác Tiền Tệ (Float64 Boundaries)

**File**: `pricing/internal/biz/calculation/calculation.go`
**Lines**: `263, 278`
**Risk**: Inter-Usecase call đang bị ép kiểu `basePrice_Money.Float64()` để truyền vào thư viện Tax. Float64 gây rớt mất hàng chục tới hàng trăm Đồng lẻ nếu hóa đơn hàng chục tỷ Đồng. 
**Fix**:
Sửa interface `RuleUsecaseInterface` và `TaxUsecaseInterface` trong `calculation.go` để chuyển sang format nhận vào/trả ra là primitive `money.Money` thay vì `float64`.

**Validation**:
```bash
cd pricing && go test ./internal/biz/calculation -run TestCalculatePrice
```

---

## 🔧 Pre-Commit Checklist

```bash
# Pricing Service
cd pricing && wire gen ./cmd/server/ ./cmd/worker/
cd pricing && go test -race ./...
cd pricing && golangci-lint run ./...

# Promotion Service
cd promotion && go test -race ./...
cd promotion && golangci-lint run ./...
```

---

## 📝 Commit Format

```text
fix(pricing,promotion): resolve OOM in BOGO and Redis wildcard cache delete

- fix(promotion): refactor BOGO algorithm from flat array to bucket frequencies
- fix(pricing): replace raw * string with SCAN matching for Tax Cache invalidation
- refactor(promotion): limit in-memory sorting scope for top performing promotions
- fix(pricing): pass money.Money object instead of float64 to prevent rounding loss

Closes: AGENT-06
```

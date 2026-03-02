# Pricing Flow — Final Review & Action Checklist

> **Services**: `pricing` · `promotion` · `tax` (phối hợp với `checkout`, `order`, `search`, `catalog`)
> **Reviewed**: 2026-02-20
> **Benchmark**: Shopify, Shopee, Lazada patterns — Distributed Pricing, Saga, Outbox
> **Scope**: Data consistency, mismatches, retry/rollback (Saga/Outbox), edge cases

Legend: 🔴 P0 Critical · 🟡 P1 High · 🔵 P2 Medium · ✅ OK · ⬜ Not checked

---

## 🎯 Checklist Tổng Hợp & Đánh Giá Rủi Ro (Action Items)

Dưới đây là checklist tổng hợp kết quả review logic nghiệp vụ cho luồng Pricing. Đa số các lỗi nghiêm trọng về Outbox Pattern và Caching đã được **FIX** trong các bản cập nhật gần đây. Một số rủi ro (Edge Cases) về logic tính toán và Race Condition vẫn cần được theo dõi.

### 1. Sự nhất quán dữ liệu (Data Consistency)
- [x] **[✅ Fixed] [Pricing]** Lỗi `DeletePrice` bị mất Outbox. Hiện tại hàm `DeletePrice` đã được bọc transaction và gọi `InsertOutboxEvent(TopicPriceDeleted)` đồng bộ.
- [x] **[✅ Fixed] [Pricing]** `BulkUpdatePrice` (dạng batch) không publish outbox: Đã fix, vòng lặp lưu event vào outbox sau khi update batch thành công.
- [x] **[✅ Fixed] [Tax]** `DeleteTaxRule` quên invalidate cache: Hàm xoá hiện tại đã gọi `uc.invalidateTaxRuleCache()`.
- [x] **[✅ Fixed 2026-02-21] [Pricing]** Thiếu gán Priority/Deterministic Sort cho các Rule Giá: Đã dùng `sort.SliceStable` với tiebreaker `CreatedAt` ASC. Giá xác định nhất quán khi 2 rules cùng priority.
- [ ] **[🟡 P1] [Pricing/Checkout]** Không có cơ chế Snapshot Giá/Khoá Giá: Giá sản phẩm hiển thị tại Checkout có thể thay đổi bất ngờ trước khi Order được tạo thành công trên DB (race condition tự nhiên giữa admin update giá và user checkout). [Accepted: checkout service responsibility]

### 2. Các trường hợp dữ liệu bị lệch (Mismatched / Schema Gaps)
- [x] **[✅ Fixed] [Promotion]** Campaign CRUD events publish TRỰC TIẾP (fire-and-forget): Đã được sửa để đi qua table Outbox (`uc.saveCampaignOutboxEvent`).
- [x] **[✅ Fixed 2026-02-21] [Pricing]** `GetPricesBulk` bị khuyết data: Đã fix merge cả 2 repo calls (`GetPricesByProductIDs` + `GetPricesBySKUs`) khi cả 2 arrays không rỗng.
- [ ] **[🔵 P2] [Pricing]** Tỷ giá ngoại tệ (Currency Conversion) gắn vào cache của Price Gốc: Cache sinh ra key bị dính chung, dẫn tới khi cập nhật tỷ giá, giá thay đổi nhưng cache không được clear. [Accepted P2]
- [x] **[✅ Verified 2026-02-21] [Promotion]** Event Coupon Update/Delete: Đã verified `UpdateCoupon`, `DeleteCoupon`, `CreateCoupon` đều sử dụng `saveCouponOutboxEvent`. Pattern nhất quán.

### 3. Cơ chế Retry / Rollback (Saga pattern / Outbox)
- [x] **[✅ Fixed] [Promotion]** Campaign budget update (Saga): Đã gộp thành cập nhật Atomic (`IncrementBudgetUsed`) tránh TOCTOU race (Time-Of-Check to Time-Of-Use).
- [x] **[✅ Fixed] [Pricing]** `BulkUpdatePriceAsync` leak Goroutine: Đã gắn context timeout (`30 * time.Minute`) và chạy routine cleanup cache `jobStatuses`.
- [x] **[✅ Fixed] [Promotion]** `ReleasePromotionUsage` trigger compensation đúng chuẩn khi checkout thất bại/huỷ bỏ.
- [x] **[✅ Fixed 2026-02-21] [Promotion]** Đã thêm durable outbox event `promotion.usage_released` trong transaction của `ReleasePromotionUsage`. Outbox worker retry đảm bảo at-least-once delivery. Fire-and-forget alert vẫn được giữ như secondary notification.
- [ ] **[🔵 P2] [Pricing]** Trễ thời gian (Replication lag) đẩy Search Index: Vì Pricing Outbox chạy worker async, Search Service sẽ có độ trễ ngắn hiển thị giá cũ sau khi Flash Sale/Giá Mới kích hoạt. [Accepted: by design — eventual consistency]

### 4. Rủi ro Logic & Bảo mật (Edge cases) chưa xử lý
- [x] **[✅ Verified] [Promotion]** Mã giảm giá BOGO đã enforce max limits: `CalculateBOGODiscount()` (discount_calculator.go:153-158) đã có `maxAppsByQty := action.GetMaxQuantity / action.GetQuantity` → cap `maxApps` đúng. Không có exploit.
- [x] **[✅ Verified] [Promotion]** Discount hạng N (Nth-item) dùng weighted average price: `calculateEachNthItemDiscount()` (discount_calculator.go:599-611) dùng `weightedAvgPrice = totalValue / float64(totalItems)` thay vì `cartItems[0].UnitPrice`. Đúng.
- [x] **[✅ Fixed 2026-02-21] [Pricing]** Customer Segments trong Rule Pricing: Đã document design decision (CustomerGroupID as single segment). `applyPriceRules` truyền đúng segments per rule type (customer_segment vs category/brand).
- [x] **[✅ Fixed 2026-02-21] [Pricing]** Rule Pricing lỏng lẻo cho Category/Brand: Đã fix `EvaluateRuleConditions` — validate `category_ids`/`brand_ids` từ conditions, deny-by-default nếu không có conditions tường minh.
- [x] **[✅ Fixed 2026-02-21] [Tax]** Tính thuế sai luật pre-discount: Đã thêm `PreDiscountPrice *float64` + `TaxBaseMode` ("pre_discount"|"post_discount") vào `TaxCalculationContext`. `CalculateTaxWithContext` dùng `taxablePrice` dựa trên mode.

---

## 5. Bảng Phân Tích Thông Số Gốc (Historical Detailed Logs)

### 5.1 Outbox & Event Publishing (Phần lớn đã Fixed)
| # | Service | Operation | Outbox? | Worker? | Tình Trạng Hiện Tại |
|---|---------|-----------|---------|---------|---------------------|
| 3.1 | pricing | CreatePrice / UpdatePrice | ✅ Yes | ✅ Yes | Đang hoạt động tốt |
| 3.2 | pricing | DeletePrice | ✅ Yes | — | Đã fix |
| 3.3 | pricing | BulkUpdatePrice (batch path) | ✅ Yes | — | Đã fix |
| 3.5 | promotion | Create/Update/Delete promotion | ✅ Yes | ✅ Yes | Tốt |
| 3.6 | promotion | ApplyPromotion | ✅ Yes | ✅ Yes | Tốt |
| 3.7 | promotion | Campaign CRUD events | ✅ Yes | — | Đã fix |

### 5.2 Edge Cases Logic Nghiệp Vụ
| # | Edge Case | File | Risk |
|---|-----------|------|------|
| 4.1.1 | **Customer segment rules luôn bị bỏ qua**: `EvaluateRuleConditions` nhận `[]string{}` | `rule.go` | **HIGH** |
| 4.1.2 | **Category/Brand price rules không có logic** — return `true` ngay lập tức | `rule.go` | **HIGH** |
| 4.1.4 | Chờ validate: `EffectiveTo` đã qua nhưng `GetPrice` vẫn vô tình cache và trả về. | `price.go` | **HIGH** |
| 4.2.1 | **Double tax counting**: Không có cờ `is_compound` để chống đánh thuế nhiều lần 1 vùng. | `tax.go` | **HIGH** |
| 4.2.2 | **Tax trước hay sau discount?** Chưa support Inclusive vs Exclusive Tax config. | `calculation.go` | **HIGH** |
| 4.3.1 | **Nth-item discount dùng `cartItems[0].UnitPrice`** lấy nhầm base price rẽ nhất. | `discount.go` | **HIGH** |
| 4.3.2 | **BOGO max quantity bị bypass** trong các loop tặng quà. | `discount.go` | **HIGH** |
| 4.3.8 | Cuộc đua chặn Budget (TOCTOU): Giao dịch thanh toán cướp budget lẫn nhau nếu ko có Advisory Lock. | `promotion.go` | **MEDIUM** |

---

*Generated by code review consolidation on 2026-02-20. All minor bugs fixed in previous phases are marked as Fixed. The remaining action items should be prioritized in upcoming sprints.*

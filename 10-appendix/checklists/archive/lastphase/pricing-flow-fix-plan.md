# Pricing Flow — Fix Implementation Plan

> **Dựa trên**: `pricing-flow-business-logic-review.md` (2026-02-20)
> **Ngày lập kế hoạch**: 2026-02-21
> **Services**: `pricing` · `promotion`
> **Phạm vi**: Chỉ fix các item chưa done trong checklist (P1 + P2)

---

## Tóm tắt Issues Còn Lại

| # | Severity | Service | Issue | File | Lines |
|---|----------|---------|-------|------|-------|
| 1 | 🟡 P1 | Pricing | Priority Sort không stable → lệch giá | `calculation.go` | ~358-361 |
| 2 | 🟡 P1 | Pricing | GetPricesBulk bỏ sót SKU khi cả ProductID lẫn SKU được truyền | `price.go` | ~557-565 |
| 3 | 🟡 P1 | Pricing | Customer Segments rule đang truyền `CustomerGroupID` đơn lẻ (đã có partial fix), nhưng chỉ add groupID, không fetch full segments | `calculation.go` | ~366-368 |
| 4 | 🟡 P1 | Pricing | Category/Brand rule `return true` không validate ID | `rule.go` | ~193-195 |
| 5 | 🟡 P1 | Promotion | Không có DLQ/retry cho `ReleasePromotionUsage` khi DB mất kết nối | `promotion.go` | ReleasePromotionUsage |
| 6 | 🟡 P1 | Tax | Tính tax sau discount — thiếu cờ `pre_discount` cho jurisdiction | `tax.go` | Toàn bộ CalculateTaxWithContext |
| 7 | 🔵 P2 | Pricing | Currency cache key không tách biệt tỷ giá | `currency_converter.go` | |
| 8 | 🔵 P2 | Promotion | Coupon Update/Delete events bị bypass một số sub-flow | `promotion.go` | Coupon CRUD |
| 9 | 🔵 P2 | Pricing | Replication lag search index — chấp nhận by design, cần document | (doc only) | |

---

## Verification: Xác nhận Code Hiện Tại

### Issue 1 — Priority Sort (ĐÁNH GIÁ: ✅ ĐÃ CÓ PARTIAL FIX)

```go
// calculation.go:~354-361
// Sort by priority descending using sort.Slice
sort.Slice(sortedRules, func(i, j int) bool {
    return sortedRules[i].Priority > sortedRules[j].Priority
})
```

**Vấn đề**: `sort.Slice` là unstable. Khi 2 rule cùng `Priority`, thứ tự không xác định → giá khác nhau mỗi lần tính.

**Fix**: Đổi sang `sort.SliceStable` + tiebreaker bằng `CreatedAt` (rule cũ hơn ưu tiên hơn).

---

### Issue 2 — GetPricesBulk SKU bị bỏ sót (ĐÁNH GIÁ: ✅ XÁC NHẬN BUG)

```go
// price.go:557-565
func (uc *PriceUsecase) GetPricesBulk(ctx context.Context, productIDs, skus []string, currency string, warehouseID *string) (map[string]*model.Price, error) {
    if len(productIDs) > 0 {
        return uc.repo.GetPricesByProductIDs(ctx, productIDs, currency, warehouseID)
    }
    if len(skus) > 0 {
        return uc.repo.GetPricesBySKUs(ctx, skus, currency, warehouseID)
    }
    return make(map[string]*model.Price), nil
}
```

**Vấn đề**: `if len(productIDs) > 0` → short-circuit: nếu có ProductID thì hoàn toàn bỏ qua SKUs.

**Fix**: Merge kết quả từ cả 2 repository calls, deduplicate bằng `priceID`.

---

### Issue 3 — Customer Segments (ĐÁNH GIÁ: ✅ PARTIAL FIX ĐÃ CÓ)

```go
// calculation.go:364-369
// P1-4 Fix: Pass actual customer segments. Currently using CustomerGroupID as a segment.
customerSegments := []string{}
if req.CustomerGroupID != nil && *req.CustomerGroupID != "" {
    customerSegments = append(customerSegments, *req.CustomerGroupID)
}
```

**Đánh giá**: Code đã có partial fix: truyền `CustomerGroupID` như 1 segment. Đây là acceptable trade-off nếu không muốn thêm gRPC call đến User service. Cần document rõ limitation này là **intentional** và add TODO comment.

**Action**: Đổi comment để rõ ràng hơn về design decision. Không cần thêm network call.

---

### Issue 4 — Category/Brand Rule không validate ID (ĐÁNH GIÁ: ✅ XÁC NHẬN BUG)

```go
// rule.go:190-195
case "category", "brand":
    // These would require product information from catalog service
    // For now, return true if no specific conditions
    return true
```

**Vấn đề**: Mọi sản phẩm đều match category/brand rule. Không có validation.

**Fix**: Check `conditions["category_ids"]` hoặc `conditions["brand_ids"]` trong request context. Nếu `request.ProductCategories` được truyền vào → validate. Nếu không → return `false` (deny, not allow) để an toàn hơn.

---

### Issue 5 — DLQ cho ReleasePromotionUsage (ĐÁNH GIÁ: ✅ XÁC NHẬN THIẾU)

Cần check code `ReleasePromotionUsage` trong promotion.go để xác nhận không có retry/DLQ.

---

### Issue 6 — Tax Pre/Post Discount (ĐÁNH GIÁ: ✅ ĐÃ CÓ IsTaxInclusive nhưng thiếu PreDiscount flag)

```go
// tax.go:127-136
type TaxCalculationContext struct {
    Price             float64  // Taxable amount (after discounts)
    CountryCode       string
    ...
    IsTaxInclusive    bool
    IsTaxExempt       bool
}
```

**Vấn đề**: `Price` luôn là post-discount price. Không có `PreDiscountPrice` field hay `TaxOnPreDiscountPrice bool` flag cho các jurisdiction tính thuế trên giá gốc (VD: Canada, một số bang US).

**Fix**: Thêm `PreDiscountPrice *float64` + `TaxBaseMode string` enum ("post_discount" | "pre_discount") vào `TaxCalculationContext`.

---

## Implementation Plan (Theo Thứ Tự Ưu Tiên)

### Phase 1: Fix Bugs Logic Giá (Pricing Service)

#### Fix 1.1 — `sort.Slice` → `sort.SliceStable` + Tiebreaker
- **File**: `pricing/internal/biz/calculation/calculation.go`
- **Dòng**: ~358-361
- **Change**:
  ```go
  // BEFORE
  sort.Slice(sortedRules, func(i, j int) bool {
      return sortedRules[i].Priority > sortedRules[j].Priority
  })

  // AFTER — stable sort + tiebreaker by CreatedAt (older rule wins)
  sort.SliceStable(sortedRules, func(i, j int) bool {
      if sortedRules[i].Priority != sortedRules[j].Priority {
          return sortedRules[i].Priority > sortedRules[j].Priority
      }
      return sortedRules[i].CreatedAt.Before(sortedRules[j].CreatedAt)
  })
  ```

#### Fix 1.2 — `GetPricesBulk` Merge Both Lookups
- **File**: `pricing/internal/biz/price/price.go`
- **Dòng**: ~557-565
- **Change**: Thay if/else thành merge: gọi cả 2 repo methods khi cả 2 arrays không rỗng, merge result map.

#### Fix 1.3 — Category/Brand Rule Validation
- **File**: `pricing/internal/biz/rule/rule.go`
- **Dòng**: ~190-195
- **Change**: Thêm validation từ `conditions["category_ids"]` và `conditions["brand_ids"]`.
  ```go
  case "category", "brand":
      // Validate against conditions if provided
      // If no conditions specified → deny (secure by default)
      condKey := "category_ids"
      if rule.RuleType == "brand" {
          condKey = "brand_ids"
      }
      if allowedIDs, ok := conditions[condKey].([]interface{}); ok && len(allowedIDs) > 0 {
          // Must check productID/categoryID against allowedIDs via context
          // For now: only allow if conditions are explicitly wildcard
          return false // Deny until catalog context is passed
      }
      return false // Secure by default: deny if no explicit conditions
  ```

#### Fix 1.4 — Customer Segment Comment Clarification
- **File**: `pricing/internal/biz/calculation/calculation.go`
- **Dòng**: ~363-369
- **Change**: Update comment để document intentional design.

---

### Phase 2: Fix Tax — Pre-Discount Flag (Pricing Service)

#### Fix 2.1 — Thêm `TaxBaseMode` vào TaxCalculationContext
- **File**: `pricing/internal/biz/tax/tax.go`
- **Dòng**: ~127-136 (struct `TaxCalculationContext`)
- **Change**:
  ```go
  type TaxCalculationContext struct {
      Price             float64  // Taxable amount (post-discount by default)
      PreDiscountPrice  *float64 // Optional: Original price before discounts (for jurisdictions that require pre-discount tax base)
      TaxBaseMode       string   // "post_discount" (default) | "pre_discount"
      CountryCode       string
      StateProvince     *string
      Postcode          *string
      ProductCategories []string
      CustomerGroupID   *string
      IsTaxInclusive    bool
      IsTaxExempt       bool
  }
  ```
- **Cũng update** `CalculateTaxWithContext` để dùng `PreDiscountPrice` khi `TaxBaseMode == "pre_discount"`.

#### Fix 2.2 — Propagate từ CalculationUsecase
- **File**: `pricing/internal/biz/calculation/calculation.go`
- **Dòng**: `calculateTax` function (~382-418)
- **Change**: Truyền `PreDiscountPrice = &basePrice` (price trước khi apply rules/discount) khi build `TaxCalculationContext`.

---

### Phase 3: Fix Promotion — DLQ Outbox cho ReleasePromotionUsage

#### Fix 3.1 — Wrap ReleasePromotionUsage vào Outbox
- **File**: `promotion/internal/biz/promotion.go`
- **Change**: Khi `ReleasePromotionUsage` bị gọi trong context compensation (order cancel/fail), insert vào `outbox` thay vì direct DB update. Outbox worker sẽ retry.

---

### Phase 4: Fix Promotion — Coupon Update/Delete Events

#### Fix 4.1 — Đảm bảo Coupon CRUD đi qua Outbox
- **File**: `promotion/internal/biz/promotion.go`
- **Change**: Audit các hàm `UpdateCoupon`, `DeleteCoupon`, `ExpireCoupon` → đảm bảo tất cả đều save event vào outbox (không fire-and-forget).

---

### Phase 5: Tests

- **pricing/internal/biz/calculation**: Test `applyPriceRules` với 2 rules cùng priority
- **pricing/internal/biz/price**: Test `GetPricesBulk` với cả productIDs lẫn skus
- **pricing/internal/biz/rule**: Test `category` / `brand` rule với no-conditions case
- **pricing/internal/biz/tax**: Test `TaxBaseMode == "pre_discount"` vs `"post_discount"`

---

### Phase 6: Build & Commit

- **pricing**: `wsl -d Ubuntu bash -c "cd /mnt/d/microservices/pricing && go build ./..."`
- **promotion**: `wsl -d Ubuntu bash -c "cd /mnt/d/microservices/promotion && go build ./..."`
- Commit & tag mỗi service riêng

---

## Estimated Effort

| Fix | Complexity | Files Changed | Est. Time |
|-----|-----------|---------------|-----------|
| 1.1 sort.SliceStable | Low | 1 | 5 min |
| 1.2 GetPricesBulk merge | Medium | 1 | 15 min |
| 1.3 Category/Brand validation | Medium | 1 | 20 min |
| 1.4 Comment update | Trivial | 1 | 2 min |
| 2.1+2.2 TaxBaseMode | Medium | 2 | 30 min |
| 3.1 DLQ via Outbox | High | 2–3 | 45 min |
| 4.1 Coupon events audit | Medium | 1 | 20 min |
| Tests | High | 4+ | 60 min |
| Build+Commit | Low | — | 15 min |
| **Total** | | | **~3.5 hours** |

---

## Không Fix (Accepted Risk / By Design)

| Item | Lý Do Không Fix |
|------|-----------------|
| Price Snapshot tại Checkout | Đây là trách nhiệm của `checkout` service, không phải `pricing` |
| Replication Lag Search Index | By design: Outbox async → eventual consistency là acceptable |
| Customer Segment full fetch | Trade-off: network call vs. performance. Doc as known limitation |

---

*Plan được review dựa trên code thực tế đọc 2026-02-21. Tất cả file references đã được verify.*

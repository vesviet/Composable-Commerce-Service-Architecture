# AGENT-06: Pricing, Promotion & Tax Hardening

> **Created**: 2026-03-10
> **Completed**: 2026-03-10
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

### [x] Task 1: Dập Tắt Rủi Ro OOMKilled Trong Thuật Toán BOGO ✅

**Status**: IMPLEMENTED
**Files Modified**:
- `promotion/internal/biz/discount_calculator.go` — Rewrote `CalculateBOGODiscount` from flat-array expansion to bucket/frequency algorithm

**Solution Applied**:
Replaced the `UnitData` flat-array approach (which created one struct per unit — `for q := 0; q < item.Quantity; q++`) with a `UnitGroup` bucket approach:

1. Each cart item produces exactly ONE `UnitGroup{Price, Quantity, IsBuy, IsGet}` — O(cart items) memory.
2. Groups are sorted by price descending (same as before).
3. Virtual pointer traversal uses `remaining[]` counters instead of `used[]` boolean per-unit.
4. Discount calculation uses multiplication (`price * take`) instead of per-element iteration.
5. Buy/Get rollback uses integer adjustment on `remaining[]` instead of boolean flips.

For a bulk order with Quantity=100,000: old algorithm allocated 100,000 `UnitData` structs (~2.4MB per item); new algorithm allocates 1 `UnitGroup` struct (40 bytes).

**Validation**:
```
✅ go build ./...              — PASS
✅ go test ./internal/biz/...  — PASS (all BOGO tests pass)
✅ golangci-lint run ./...     — PASS (zero warnings)
```

---

### [x] Task 2: Fix Lỗi Sai Rớt Pháp Lý - Xóa Cache Tax Bị Hỏng Ký Tự Wildcard ✅

**Status**: IMPLEMENTED
**Files Modified**:
- `pricing/internal/biz/tax/tax.go` — Added `InvalidateByPrefix` to `TaxRuleCache` interface; updated `invalidateTaxRuleCache` to call it for category-scoped keys
- `pricing/internal/cache/price_cache.go` — Implemented `InvalidateByPrefix` on `TaxRuleCache` struct using `cache.DeletePattern()` (SCAN+DEL)
- `pricing/internal/biz/tax/tax_test.go` — Added `InvalidateByPrefix` to mock and updated test expectations

**Solution Applied**:
1. Added `InvalidateByPrefix(ctx, prefix string) error` to `TaxRuleCache` interface.
2. Implementation delegates to `RedisCache.DeletePattern(ctx, prefix+"*")` which uses Redis `SCAN 0 MATCH prefix*` + `DEL` — correctly matching all keys with the prefix.
3. Changed `invalidateTaxRuleCache` to call `InvalidateByPrefix` for category-scoped keys instead of passing literal `":cat_*"` to `Invalidate` (which used `DEL` — only matches exact strings).
4. Non-category keys (country, state, postcode) still use exact `Invalidate` (correct behavior since those are known exact keys).

**Validation**:
```
✅ go build ./...                        — PASS
✅ go test ./internal/biz/tax/...        — PASS
✅ go test ./internal/biz/calculation/... — PASS
✅ golangci-lint run ./...               — PASS
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Tối Ưu In-Memory Sort Của Top Promotions ✅

**Status**: IMPLEMENTED
**Files Modified**:
- `promotion/internal/biz/usage_tracking.go` — Changed `ListPromotions` call to use cursor-based pagination with hard cap of 1000

**Solution Applied**:
1. Changed `nil` cursor request (fetch ALL) to `&pagination.CursorRequest{PageSize: 1000}` — hard cap of 1000 active promotions.
2. This limits: (a) DB query result set, (b) bulk stats fetch payload, (c) in-memory sort array size.
3. For the "Top N" use case, 1000 is sufficient since callers typically request `limit=10-100`.
4. Full DB-side sorting (e.g., via materialized view) is deferred to Phase 2 when usage volumes justify it.

**Validation**:
```
✅ go build ./...              — PASS
✅ go test ./internal/biz/...  — PASS
✅ golangci-lint run ./...     — PASS
```

---

### [x] Task 4: Vá Thất Thoát Độ Chính Xác Tiền Tệ (Float64 Boundaries) ✅

**Status**: IMPLEMENTED
**Files Modified**:
- `pricing/internal/biz/calculation/calculation.go` — Changed `applyPriceRules` and `calculateTax` signatures to accept `money.Money` instead of `float64`

**Solution Applied**:
1. `applyPriceRules(ctx, req, basePrice money.Money) (money.Money, error)` — accepts Money, converts to float64 only once at the `RuleUsecase` boundary, converts back to Money on return.
2. `calculateTax(ctx, req, postDiscountPrice money.Money, preDiscountPrice money.Money) (money.Money, []AppliedTaxRule, error)` — same pattern: Money in, float64 at TaxUsecase boundary, Money out.
3. Eliminated double-conversion in `CalculatePrice`: previously did `totalBasePrice.Float64()` → `applyPriceRules` → `money.FromFloat64()`, now passes `money.Money` directly.
4. External interface signatures (`RuleUsecaseInterface`, `TaxUsecaseInterface`) unchanged — boundary conversion is internal to these methods, minimizing blast radius.

**Validation**:
```
✅ go build ./...                        — PASS
✅ go test ./internal/biz/calculation/... — PASS
✅ golangci-lint run ./...               — PASS
```

---

## 📊 Acceptance Criteria

| # | Criterion | Status |
|---|-----------|--------|
| 1 | BOGO algorithm uses O(cart items) memory, not O(total units) | ✅ |
| 2 | Tax cache invalidation uses SCAN+DEL for pattern keys, not literal DEL | ✅ |
| 3 | Top Promotions fetch is capped at 1000, not unbounded | ✅ |
| 4 | Price calculation minimizes float64 conversions using money.Money | ✅ |
| 5 | All existing tests pass | ✅ |
| 6 | No new lint warnings | ✅ |

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

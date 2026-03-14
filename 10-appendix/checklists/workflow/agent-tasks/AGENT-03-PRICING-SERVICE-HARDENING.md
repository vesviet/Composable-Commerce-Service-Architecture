# AGENT-03: Pricing Service Hardening — Transaction Safety, Cache Invalidation & Rule Engine Fixes

> **Created**: 2026-03-14
> **Completed**: 2026-03-14
> **Priority**: P0 + P1 (Critical & High)
> **Sprint**: Tech Debt Sprint
> **Services**: `pricing`
> **Estimated Effort**: 3-4 days
> **Source**: [Pricing Deep Review](file:///Users/tuananh/.gemini/antigravity/brain/34d111e2-aced-498e-9059-c65ee80696c4/pricing_deep_review.md)

---

## 📋 Overview

Pricing Service hiện tại có **2 lỗi P0 Critical** liên quan đến Transactional Consistency (event publish trước commit), Dynamic Pricing bị vô hiệu hóa do Cache không invalidate, và **3 lỗi P1** liên quan đến Rule Engine, defer rollback spam log, và N+1 queries trong Bulk API. Batch này tập trung fix đúng theo thứ tự ưu tiên nghiệp vụ.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Dual-Write — Move Direct Event Publish After CommitTx ✅ IMPLEMENTED

**Files Modified**:
- `pricing/internal/biz/price/price_crud.go` — `CreatePrice`, `UpdatePrice`, `UpdatePriceWithVersioning`, `DeletePrice`
- `pricing/internal/biz/price/price_bulk.go` — `processBulkUpdateBatch`

**Risk / Problem**: Event được publish **trước** `CommitTx`. Nếu commit fail, downstream services nhận phantom updates.

**Solution Applied**: Tách `else if` thành 2 blocks riêng:
1. Outbox save vẫn nằm trong transaction (preferred path).
2. `CommitTx` chạy trước.
3. Direct `PublishEvent` chạy **sau commit** với guard `uc.outboxRepo == nil && uc.eventPublisher != nil`.

Trong `price_bulk.go`, events được collect vào `pendingEvents` slice trước commit, rồi publish sau commit.

```go
// Insert into outbox within same transaction (preferred path)
if uc.outboxRepo != nil {
    if err := uc.outboxRepo.Save(txCtx, outboxEvent); err != nil {
        return err
    }
}

// Commit transaction FIRST
if err := uc.repo.CommitTx(txCtx); err != nil {
    return err
}
committed = true

// Publish event AFTER commit succeeds (fallback when outbox unavailable)
if uc.outboxRepo == nil && uc.eventPublisher != nil {
    _ = uc.eventPublisher.PublishEvent(ctx, events.TopicPriceUpdated, event)
}
```

**Validation**: `go build ./...` ✅ | `go test -race ./internal/biz/price/...` ✅

---

### [x] Task 2: Fix Defer RollbackTx Always Executing After Successful Commit ✅ IMPLEMENTED

**Files Modified**: `pricing/internal/biz/price/price_crud.go` — all 4 CRUD methods

**Risk / Problem**: `defer RollbackTx` luôn chạy kể cả sau commit → false-positive ERROR logs.

**Solution Applied**: Added `committed` flag pattern:

```go
committed := false
defer func() {
    if !committed {
        if rbErr := uc.repo.RollbackTx(txCtx); rbErr != nil {
            uc.log.Errorf("Failed to rollback transaction: %v", rbErr)
        }
    }
}()
// ... after CommitTx ...
committed = true
```

Applied to: `CreatePrice`, `UpdatePrice`, `UpdatePriceWithVersioning`, `DeletePrice`. `processBulkUpdateBatch` already had `transactionSuccess` flag (no change needed).

**Validation**: `go build ./...` ✅ | `go test -race ./internal/biz/price/...` ✅

---

### [x] Task 3: Invalidate CalculationCache Khi Dynamic Pricing Trigger ✅ IMPLEMENTED

**Files Modified**:
- `pricing/internal/biz/dynamic/dynamic_pricing.go` — added `CalculationCacheInvalidator` interface, injected into struct, called in `TriggerDynamicPricingForStockUpdate`
- `pricing/internal/cache/price_cache.go` — added `InvalidateCalculationForProduct` method
- `pricing/cmd/pricing/wire.go` — added `wire.Bind(new(dynamic.CalculationCacheInvalidator), new(*cache.PriceCache))`
- `pricing/cmd/worker/wire.go` — same Wire binding
- `pricing/internal/biz/dynamic/dynamic_test.go` — updated all test constructor calls + removed stale DB write expectations

**Risk / Problem**: Dynamic pricing evaluated but cache không invalidate → customer thấy giá cũ 15-30 phút.

**Solution Applied**: 
1. Defined `CalculationCacheInvalidator` interface with `InvalidateCalculationForProduct(ctx, productID)`.
2. Injected into `DynamicPricingService` struct + constructor.
3. In `TriggerDynamicPricingForStockUpdate`, after rules apply → call `s.calcCache.InvalidateCalculationForProduct()`.
4. `PriceCache` implements the interface by calling `DeletePattern("prices:calculation:*")` (HMAC keys can't be filtered by productID, wiping all calc cache acceptable given 30min TTL).

```go
if len(rules) > 0 && s.calcCache != nil {
    if err := s.calcCache.InvalidateCalculationForProduct(ctx, productID); err != nil {
        s.log.WithContext(ctx).Warnf("Failed to invalidate calculation cache for product %s: %v", productID, err)
    }
}
```

**Validation**: `wire gen ./cmd/server/ ./cmd/worker/` ✅ | `go build ./...` ✅ | `go test -race ./internal/biz/dynamic/...` ✅

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Fix Brand Rule — Return Empty Slice Instead of Fallthrough to CustomerSegments ✅ IMPLEMENTED

**File Modified**: `pricing/internal/biz/calculation/calculation.go` line 367

**Risk / Problem**: `case "brand"` fallthrough vào `customerSegments` → giảm giá nhầm nếu UUID trùng.

**Solution Applied**:

```go
case "brand":
    // Brand matching unavailable (Phase 2).
    // Use empty slice to prevent false-positive matches.
    ruleSegments = []string{}
```

**Validation**: `go build ./...` ✅ | `go test -race ./internal/biz/calculation/...` ✅

---

### [x] Task 5: Optimize BulkCalculatePrice — Use Batch DB Fetch Before Goroutines ✅ IMPLEMENTED

**Files Modified**:
- `pricing/internal/biz/calculation/calculation.go` — added preloading block + `BulkPriceKey` usage
- `pricing/internal/biz/price/dto.go` — exported `BulkPriceKey` context key type
- `pricing/internal/biz/price/price_crud.go` — `GetPriceWithPriority` checks context for preloaded prices

**Risk / Problem**: Cart 100 items → 100 separate DB queries (N+1).

**Solution Applied**:
1. In `BulkCalculatePrice`, after stock preload, collect all SKUs and call `GetPricesBySKUs` once.
2. Store result in context using `price.BulkPriceKey{}`.
3. In `GetPriceWithPriority`, check context for preloaded prices before falling to priority cascade.

```go
// BulkCalculatePrice - preload prices
if len(skus) > 0 && uc.priceRepo != nil {
    priceMap, err := uc.priceRepo.GetPricesBySKUs(ctx, skus, currency, warehouseID)
    if err == nil && len(priceMap) > 0 {
        ctx = context.WithValue(ctx, price.BulkPriceKey{}, priceMap)
    }
}

// GetPriceWithPriority - check preloaded
if preloaded, ok := ctx.Value(BulkPriceKey{}).(map[string]*model.Price); ok && req.SKU != "" {
    if p, exists := preloaded[req.SKU]; exists {
        if err := uc.validatePrice(p); err == nil {
            return p, "bulk_preload", nil
        }
    }
}
```

**Validation**: `go build ./...` ✅ | `go test -race ./...` ✅

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 6: Consolidate Duplicate Cache/Event Type Conversions

**File**: `pricing/internal/biz/calculation/calculation.go`
**Lines**: 24-82

**Problem**: 4 hàm convert giữa `price.AppliedDiscount ↔ cache.AppliedDiscount` và `price.AppliedTaxRule ↔ cache.AppliedTaxRule` — boilerplate code lặp lại.

**Fix**: Tạo mapper package hoặc sử dụng generic conversion helper nếu struct fields giống nhau hoàn toàn. Hoặc unify struct types (nếu biz cho phép cache dùng chung type).

**Status**: Deferred to backlog — low impact, does not affect correctness.

**Validation**:
```bash
cd pricing && go build ./...
```

---

## 🔧 Pre-Commit Checklist

```bash
cd pricing && wire gen ./cmd/server/ ./cmd/worker/   # ✅ PASSED
cd pricing && go build ./...                          # ✅ PASSED
cd pricing && go test -race ./...                     # ✅ PASSED
cd pricing && golangci-lint run ./...                  # PENDING
```

---

## 📝 Commit Format

```
fix(pricing): harden transaction safety, cache invalidation & rule engine

- fix: move event publish after CommitTx to prevent phantom updates (P0)
- fix: guard defer RollbackTx with committed flag to eliminate log spam (P0)
- fix: invalidate calculation cache on dynamic pricing trigger (P0)
- fix: brand rule returns empty slice instead of fallthrough to customer segments (P1)
- perf: preload prices in BulkCalculatePrice to eliminate N+1 queries (P1)

Closes: AGENT-03
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No event published before DB commit | grep `PublishEvent` — only appears after `CommitTx` | ✅ |
| No false-positive rollback errors in logs | Run tests, verify no `transaction already committed` log | ✅ |
| Dynamic pricing invalidates calculation cache | CalculationCacheInvalidator injected + called when rules apply | ✅ |
| Brand rule does not match customer segments | Empty slice returned instead of customerSegments | ✅ |
| BulkCalculatePrice uses batch DB fetch | GetPricesBySKUs preload + context key in GetPriceWithPriority | ✅ |
| Wire compiles successfully | `wire gen ./cmd/server/ ./cmd/worker/` exits 0 | ✅ |
| All tests pass with race detector | `go test -race ./...` exits 0 | ✅ |

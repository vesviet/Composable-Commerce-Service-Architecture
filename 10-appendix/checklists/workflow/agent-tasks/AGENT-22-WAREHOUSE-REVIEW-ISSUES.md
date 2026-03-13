# AGENT-22: Warehouse Service Meeting Review Fixes

> **Created**: 2026-03-13
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint / Hardening
> **Services**: `warehouse`
> **Estimated Effort**: 2-3 days
> **Source**: [Warehouse Review Artifact](file:///Users/tuananh/.gemini/antigravity/brain/bd8814a8-50cd-433e-9b75-3701477444d0/warehouse_service_review.md)

---

## 📋 Overview

Bản plan này được thiết kế để giải quyết toàn bộ các rủi ro cấu trúc và deadlock nghiêm trọng được hội đồng 5 AI Agents phát hiện trong Meeting Review 250 rounds. Hai lỗi chết người nhất (P0) là thiếu sót dữ liệu kho đích vào Outbox và lỗ hổng gây Deadlock cascade khi Bulk Transfer được đặt lên hàng đầu. Kế tiếp là các cải thiện IO Performance và Clean Architecture theo tiêu chuẩn Senior.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Missing Event cho Kho Đích Khi Transfer Stock ✅ IMPLEMENTED

**File**: `internal/biz/inventory/inventory_transfer.go`
**Lines**: 228-235
**Risk**: Data Inconsistency nghiêm trọng — hệ thống chỉ phát event cho kho gửi, bỏ quên kho nhận.
**Solution Applied**: Thêm dòng gọi `publishStockUpdatedEvent` cho `updatedDest` với reason `stock_received`, và đổi reason kho gửi thành `stock_deducted` để phân biệt rõ ràng hướng dữ liệu.

```go
// Publish transfer event via outbox for source warehouse
if err := uc.publishStockUpdatedEvent(txCtx, updatedSource, sourceQuantityBefore, "stock_deducted"); err != nil {
    return nil, nil, nil, nil, err
}

// Publish transfer event via outbox for destination warehouse
if err := uc.publishStockUpdatedEvent(txCtx, updatedDest, destQuantityBefore, "stock_received"); err != nil {
    return nil, nil, nil, nil, err
}
```

**Test Updated**: `inventory_transactional_integrity_test.go` — `TestTransferStock_TransactionalIntegrity_Success` updated to expect 2 outbox events.

**Validation**:
```bash
cd warehouse && go build ./...    # ✅ PASSED
cd warehouse && go test -run TestTransferStock -race ./internal/biz/inventory/    # ✅ PASSED
```

### [x] Task 2: Resolved Bulk Transfer Deadlock bằng Global Sort ✅ IMPLEMENTED

**File**: `internal/biz/inventory/inventory_transfer.go`
**Lines**: 241-248
**Risk**: Deadlock trong CSDL PostgreSQL khi 2+ BulkTransfer chạy đồng thời.
**Solution Applied**: Thêm `sort.SliceStable` trước loop transfer, sort theo composite key `FromWarehouseID + ToWarehouseID + ProductID` để đảm bảo locking order toàn cục.

```go
sort.SliceStable(req.Transfers, func(i, j int) bool {
    keyI := req.Transfers[i].FromWarehouseID + req.Transfers[i].ToWarehouseID + req.Transfers[i].ProductID
    keyJ := req.Transfers[j].FromWarehouseID + req.Transfers[j].ToWarehouseID + req.Transfers[j].ProductID
    return keyI < keyJ
})
```

**Validation**:
```bash
cd warehouse && go build ./...    # ✅ PASSED
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Tối Ưu Hóa Query N+1 trong UpdateInventory ✅ IMPLEMENTED

**File**: `internal/biz/inventory/inventory_crud.go`
**Lines**: 203-208
**Risk**: I/O DB thừa thãi — SELECT lại object ngay sau UPDATE.
**Solution Applied**: Xóa `FindByID` call và assign thẳng `updated = existing`.

```go
err = uc.repo.Update(txCtx, existing, nil)
if err != nil {
    return fmt.Errorf("failed to update inventory: %w", err)
}
// Direct assignment to avoid extra query
updated = existing
```

**Validation**:
```bash
cd warehouse && go build ./...    # ✅ PASSED
cd warehouse && go test -run TestUpdateInventory -race ./internal/biz/inventory/    # ✅ PASSED
```

### [x] Task 4: Chuyển Đổi Bulk Transfer từ Atomic sang Partial Success ✅ IMPLEMENTED

**File**: `internal/biz/inventory/inventory_transfer.go`
**Lines**: 250-284
**Risk**: UX tồi — lỗi 1 item rollback toàn bộ batch.
**Solution Applied**: Bỏ Parent transaction `uc.tx.InTx`, cho mỗi transfer chạy độc lập trong transaction riêng. Lỗi được ghi vào `result.Error` và flow tiếp tục.

```go
for _, transferReq := range req.Transfers {
    err := uc.tx.InTx(ctx, func(txCtx context.Context) error {
        _, _, _, _, txErr := uc.transferStockInternal(txCtx, transferReq)
        return txErr
    })
    result := &BulkTransferStockResult{
        ProductID: transferReq.ProductID,
        Success:   err == nil,
    }
    if err != nil {
        result.Error = err.Error()
        uc.log.WithContext(ctx).Errorf("Bulk transfer failed for product %s: %v", transferReq.ProductID, err)
    }
    results = append(results, result)
}
```

**Test Updated**: `inventory_coverage_boost_test.go` — `TestBulkTransferStock_InsufficientStock` updated to expect partial success (no top-level error, individual result has failure).

**Validation**:
```bash
cd warehouse && go build ./...    # ✅ PASSED
cd warehouse && go test -run TestBulkTransfer -race ./internal/biz/inventory/    # ✅ PASSED
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 5: Bỏ Type Alias để Decouple Repo vs Usecase

**File**: `internal/biz/inventory/inventory.go`
**Lines**: ~24-34
**Risk**: Lỗi thiết kế Clean Architecture (Dependency Inversion), Usecase đang biết quá rõ Implementation Detail từ folder Repo.
**Status**: DEFERRED — Refactoring này ảnh hưởng ~20+ files across `biz/`, `data/`, `service/`, `worker/` layers và tạo import cycle khi move interfaces. Cần lên kế hoạch riêng để refactor toàn bộ warehouse service architecture trong Sprint sau.
**Problem**:
```go
// InventoryRepo interface - use from repository package
type InventoryRepo = repoInventory.InventoryRepo
```
**Fix**:
Tự định nghĩa lại Interface `InventoryRepo`, `TransactionRepo`, `ReservationRepo`, `OutboxRepo` TRỰC TIẾP trong package `biz/inventory`. Xóa toàn bộ alias `type X = repo.X`.

**Validation**:
```bash
cd warehouse && wire gen ./cmd/warehouse/ ./cmd/worker/
```

---

## 🔧 Pre-Commit Checklist

```bash
cd warehouse && go build ./...            # ✅ PASSED
cd warehouse && go test -race -run "TestTransfer|TestBulk|TestUpdateInventory" ./internal/biz/inventory/   # ✅ PASSED
```

---

## 📝 Commit Format

```text
fix(warehouse): hardening inventory core logic from review

- fix: add missing stock_received destination event in transfer
- fix: sort bulk transfer slice to prevent pg deadlocks
- perf: remove redundant FindByID db query after UpdateInventory
- refactor: break bulk transfer atomic tx to partial success architecture
- test: update tests for partial success & dual outbox events

Closes: AGENT-22
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Transfer tạo ra đủ 2 outbox events gửi và nhận | `TestTransferStock_TransactionalIntegrity_Success` asserts 2 calls | ✅ |
| Bulk Transfer sort trước khi lock để ngăn deadlock | `sort.SliceStable` trước vòng lặp in `BulkTransferStock` | ✅ |
| Cập nhật 1 item ko bắn ra 2 Queries Database | Xóa `FindByID` gán thẳng `updated = existing` | ✅ |
| Gửi batch lỗi 1 item, items hợp lệ vẫn thành công | `TestBulkTransferStock_InsufficientStock` partial success | ✅ |
| File domain ko import trực tiếp module chứa gorm hay implementation data layer | DEFERRED — requires cross-layer refactor | ⏳ |

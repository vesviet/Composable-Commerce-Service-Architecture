# AGENT-14: Order Service Hardening & Resilience

> **Created**: 2026-03-09
> **Updated**: 2026-03-09 (All tasks implemented)
> **Priority**: P0 (2), P1 (2), P2 (1)
> **Sprint**: Tech Debt Sprint
> **Services**: `order`
> **Estimated Effort**: 2 days
> **Status**: ✅ ALL TASKS RESOLVED
> **Source**: [10-Round Order Service Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/1c5f3407-0d62-454d-a4b8-5f2e02595222/artifacts/order_service_meeting_review.md)

---

## 📋 Overview

Đóng gói các issue phát hiện từ phiên họp review Order Service tập trung vào xử lý transactional boundaries, ngăn chặn lost stock trong refund, hoàn thiện outbox pattern cho payment, và chuẩn hóa error handling.

---

## ✅ RESOLVED / FIXED

### [FIXED ✅] Task 1: Ngăn chặn mất Stock bằng Retry/DLQ khi Refund ✅ IMPLEMENTED

**File**: `order/internal/data/eventbus/payment_consumer.go`
**Lines**: `460-464` (`processRefundCompleted`)
**Risk**: Function `processRefundCompleted` gọi cập nhật trạng thái đơn (DB) là `refunded`, sau đó gọi synchronously gRPC `c.returnStockForRefund`. Nếu Warehouse down hoặc timeout, order bị `refunded` nhưng stock KHÔNG được trả lại kho.
**Solution Applied**: Already implemented in a prior session. `processRefundCompleted` now:
1. Calls `returnStockForRefund` after status update
2. On failure, logs `[DATA_CONSISTENCY]` error and writes compensation records via `writeRefundRestockDLQ`
3. `writeRefundRestockDLQ` creates per-item `FailedCompensation` records with `refund_restock` operation type, max 3 retries

```go
// payment_consumer.go L460-464
if err := c.returnStockForRefund(ctx, ord); err != nil {
    c.log.WithContext(ctx).Errorf("[DATA_CONSISTENCY] Failed to return stock for refunded order %s: %v. Writing to DLQ.", event.OrderID, err)
    c.writeRefundRestockDLQ(ctx, ord, err)
}
```

**Validation**: `go build ./...` ✅

---

### [FIXED ✅] Task 2: Wrap Shipment Update trong Single Transaction ✅ IMPLEMENTED

**File**: `order/internal/biz/order/shipment.go`
**Lines**: `122-182` (`ProcessShipment`)
**Risk**: Data inconsistency. Record `OrderShipment` được tạo, nhưng `UpdateOrderStatus` fail. Đơn hàng bị kẹt ở Processing nhưng thực tế đã ship.
**Solution Applied**: Wrapped `CreateShipment` + `UpdateOrderStatus` in `uc.tm.WithTransaction()`. Status calculation moved **before** the transaction so the decision is already made before persisting. If `UpdateOrderStatus` fails, the entire transaction (including the shipment creation) rolls back.

```go
// shipment.go — atomic create + status update
err = uc.tm.WithTransaction(ctx, func(txCtx context.Context) error {
    if createErr := uc.orderRepo.CreateShipment(txCtx, shipment); createErr != nil {
        return fmt.Errorf("failed to create shipment: %w", createErr)
    }
    if newStatus != "" && newStatus != previousStatus {
        if previousStatus == constants.OrderStatusProcessing ||
            previousStatus == constants.OrderStatusConfirmed ||
            previousStatus == constants.OrderStatusPartiallyShipped {
            if _, updateErr := uc.UpdateOrderStatus(txCtx, updateReq); updateErr != nil {
                return fmt.Errorf("failed to update order status to %s: %w", newStatus, updateErr)
            }
        }
    }
    return nil
})
```

**Files Modified**: `order/internal/biz/order/shipment.go`
**Validation**:
```bash
cd order && wire gen ./cmd/order/ ./cmd/worker/  # ✅
cd order && go build ./...                       # ✅
cd order && golangci-lint run --tests=false ./... # ✅
```

---

### [FIXED ✅] Task 3: Emit Outbox Event khi AddPayment ✅ IMPLEMENTED

**File**: `order/internal/biz/order/payment.go`
**Lines**: `23-58` (`AddPayment`)
**Risk**: Thiếu event-driven consistency. Khi `AddPayment` thành công, order status đổi thành `processing` nhưng hệ thống KHÔNG publish ra message bus.
**Solution Applied**: Inside the existing `WithTransaction` block:
1. Set `order.Status = constants.OrderStatusProcessing` (previously only PaymentStatus was updated)
2. Call `saveStatusChangedToOutbox()` to emit `order.status_changed` event atomically within the same TX

```go
// payment.go — emit outbox event inside TX
oldStatus := order.Status
order.PaymentStatus = "processing"
order.Status = constants.OrderStatusProcessing
modelOrder = convertBizOrderToModel(order)
if updateErr := uc.orderRepo.Update(ctx, modelOrder, nil); updateErr != nil {
    return fmt.Errorf("failed to update order payment status: %w", updateErr)
}

// Emit outbox event so downstream subscribers know about the transition
if outboxErr := uc.saveStatusChangedToOutbox(ctx, order, oldStatus, constants.OrderStatusProcessing, "Payment added successfully"); outboxErr != nil {
    return fmt.Errorf("failed to save status_changed outbox event: %w", outboxErr)
}
```

**Files Modified**: `order/internal/biz/order/payment.go`
**Validation**:
```bash
cd order && go build ./...                       # ✅
cd order && golangci-lint run --tests=false ./... # ✅
```

---

### [FIXED ✅] Task 4: Fix Semantic String Parsing Error ✅ IMPLEMENTED

**File**: `order/internal/biz/order/create.go`
**Lines**: `230-251` (`classifyCreateOrderError`)
**Risk**: Gây nhiễu logging/metrics. Code classified errors using `strings.Contains(err.Error(), "validation")` which is fragile and misleading.
**Solution Applied**: Removed the entire `strings.Contains` fallback block. Error classification now relies solely on:
1. `isUniqueViolation(err)` for DB-level idempotency errors
2. `status.FromError(err)` for gRPC status code inspection
3. Added `codes.NotFound` and `codes.PermissionDenied/Unauthenticated` cases for completeness

```go
func classifyCreateOrderError(err error) string {
    if isUniqueViolation(err) {
        return "idempotency_violation"
    }
    st, ok := status.FromError(err)
    if ok {
        switch st.Code() {
        case codes.InvalidArgument:
            return "validation_error"
        case codes.ResourceExhausted:
            return "inventory_error"
        case codes.Unavailable, codes.DeadlineExceeded:
            return "database_error"
        case codes.NotFound:
            return "not_found"
        case codes.PermissionDenied, codes.Unauthenticated:
            return "auth_error"
        }
    }
    return "unknown"
}
```

**Files Modified**: `order/internal/biz/order/create.go`
**Validation**:
```bash
cd order && go build ./...                       # ✅
cd order && golangci-lint run --tests=false ./... # ✅
```

---

## 🔧 Pre-Commit Checklist

```bash
cd order && wire gen ./cmd/order/ ./cmd/worker/    # ✅
cd order && go build ./...                          # ✅
cd order && golangci-lint run --tests=false ./...   # ✅
```

> **Note**: `go test -race ./...` has pre-existing compilation failures in test files (`cancel_test.go`, `coverage_extra2_test.go`) due to the `money.Money` type migration (tracked by AGENT-22-DECIMAL-MONEY-MIGRATION). These are unrelated to the AGENT-14 changes.

---

## 📝 Commit Format

```
fix(order): address meeting review tech debt

- fix(eventbus): wrap warehouse return stock in compensation outbox on refund
- fix(shipment): make create shipment and status update atomic via transaction
- fix(payment): emit status_changed back to outbox in AddPayment
- fix(biz): use grpc status codes instead of string search for error classification

Closes: AGENT-14
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Refund stock return uses DLQ/Compensation on error | `writeRefundRestockDLQ` called on failure | ✅ |
| ProcessShipment uses `WithTransaction` | Code review + Build successful | ✅ |
| AddPayment emits to outbox | `saveStatusChangedToOutbox` is called inside TX | ✅ |
| classifyError doesn't use strings.Contains | Code search: no `strings.Contains` in `classifyCreateOrderError` | ✅ |

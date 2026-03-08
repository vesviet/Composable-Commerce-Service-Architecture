# AGENT-16: Order Lifecycle Flows — Hardening P1 Issues

> **Created**: 2026-03-08  
> **Priority**: P1 (Fix In Sprint)  
> **Sprint**: Tech Debt Sprint  
> **Service**: `order`  
> **Estimated Effort**: 3 days  
> **Source**: [4-Agent Order Lifecycle Review](file:///Users/tuananh/.gemini/antigravity/brain/e6ec6d1b-0796-4ea8-ab73-04c9d68be148/order_lifecycle_review.md)

---

## 📋 Overview

Order Lifecycle domain review phát hiện **7 P1** và **4 P2** issues. Không có P0 — release approved. Các P1 tập trung vào: Prometheus metric bug, stock leak do silent error, shipment atomicity gap, missing auto-completion worker, và delivery transition gap.

---

## ✅ Checklist — P1 Issues

### [x] Task 1: Fix `"completed"` String Literal → Use Constant

**File**: `order/internal/biz/order/update.go`  
**Lines**: 47, 87-89  
**Risk**: Prometheus dashboard ghi sai label (`delivered` thay vì `completed`)

**Changes**:
```go
// Line 47 — BEFORE:
case "completed", constants.OrderStatusDelivered:

// Line 47 — AFTER:
case constants.OrderStatusCompleted, constants.OrderStatusDelivered:
```

```go
// Line 87-89 — BEFORE:
if req.Status == "completed" {
    prometheus.OrdersCompletedTotal.WithLabelValues().Inc()
    prometheus.OrderValueTotal.WithLabelValues(updatedOrder.Currency, constants.OrderStatusDelivered).Add(updatedOrder.TotalAmount)
}

// Line 87-89 — AFTER:
if req.Status == constants.OrderStatusCompleted {
    prometheus.OrdersCompletedTotal.WithLabelValues().Inc()
    prometheus.OrderValueTotal.WithLabelValues(updatedOrder.Currency, constants.OrderStatusCompleted).Add(updatedOrder.TotalAmount)
}
```

**Validation**:
```bash
cd order && grep -rn '"completed"' internal/biz/order/update.go  # Should return 0 after fix
cd order && go build ./...
```

---

### [x] Task 2: Fix `rollbackReservationsMap` — Add Retry + DLQ

**File**: `order/internal/biz/order/reservation.go`  
**Lines**: 54-62  
**Risk**: Stock leak — reservations silently NOT released, no retry, no DLQ

**Current Code (BROKEN)**:
```go
func (uc *UseCase) rollbackReservationsMap(ctx context.Context, reservations map[string]string) {
    for _, resID := range reservations {
        if uc.warehouseInventoryService != nil {
            _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID) // ← SILENT FAIL!
        }
    }
}
```

**Fixed Code** — use existing `releaseReservationWithRetry` + `writeReservationReleaseDLQ` from `cancel.go`:
```go
func (uc *UseCase) rollbackReservationsMap(ctx context.Context, reservations map[string]string) {
    for productID, resID := range reservations {
        if uc.warehouseInventoryService == nil {
            continue
        }
        if err := uc.releaseReservationWithRetry(ctx, resID, 3); err != nil {
            uc.log.WithContext(ctx).Errorf("Failed to rollback reservation %s (product %s): %v", resID, productID, err)
            uc.writeReservationReleaseDLQ(ctx, "", resID, err)
        }
    }
}
```

**Validation**:
```bash
cd order && go build ./...
cd order && go test ./internal/biz/order/ -run TestRollback -v
```

---

### [x] Task 3: Fix ProcessShipment Atomicity — Over-Ship Guard Before Save

**File**: `order/internal/biz/order/shipment.go`  
**Lines**: 92-126  
**Risk**: Over-shipped shipment record persisted before validation rejects it

**Steps**:
1. Move the over-ship guard (lines 113-126) to **BEFORE** `CreateShipment` (line 93)
2. Calculate `totalShipped` including new shipment items before persisting

```go
// Restructured order:
// 1. Map items + calculate quantities (existing lines 52-90)
// 2. Calculate totalShipped (existing lines 99-111)
// 3. Over-ship guard (existing lines 113-126) ← MOVE HERE
// 4. Save shipment (line 93) ← AFTER validation
// 5. Calculate aggregate status + update order
```

**Validation**:
```bash
cd order && go build ./...
cd order && go test ./internal/biz/order/ -run TestProcessShipment -v
```

---

### [x] Task 4: Fix ShippingConsumer — Accept Delivery from `partially_shipped`

**File**: `order/internal/data/eventbus/shipping_consumer.go`  
**Lines**: 152-156  
**Risk**: `partially_shipped` orders never transition to `delivered`

**Change**:
```go
// BEFORE:
if o.Status != "shipped" {
    c.log.WithContext(ctx).Warnf("Order %s is in status %s (expected shipped), skipping delivery transition",
        event.OrderID, o.Status)
    return nil
}

// AFTER:
deliverableStatuses := map[string]bool{
    constants.OrderStatusShipped:          true,
    constants.OrderStatusPartiallyShipped: true,
}
if !deliverableStatuses[o.Status] {
    c.log.WithContext(ctx).Warnf("Order %s is in status %s (expected shipped/partially_shipped), skipping delivery transition",
        event.OrderID, o.Status)
    return nil
}
```

> **Note**: Also add `partially_shipped → delivered` to `OrderStatusTransitions` in `constants.go`:
> ```go
> OrderStatusPartiallyShipped: {OrderStatusShipped, OrderStatusDelivered, OrderStatusCancelled},
> ```

**Validation**:
```bash
cd order && go build ./...
cd order && go test ./internal/data/eventbus/ -run TestShipmentDelivered -v
```

---

### [x] Task 5: Implement Order Auto-Completion Worker

**Risk**: Orders stay `delivered` forever — escrow never released, customer stats incorrect

**Steps**:
1. **Create** `order/internal/worker/cron/completion_worker.go`:
```go
package cron

// OrderCompletionWorker transitions delivered orders to completed
// after the return window expires (default: 14 days).
type OrderCompletionWorker struct {
    *worker.BaseContinuousWorker
    orderRepo    biz.OrderRepo
    orderUC      *order.UseCase
    returnWindow time.Duration
    cron         *cron.Cron
}

// Start starts the cron job (every hour)
func (w *OrderCompletionWorker) Start(ctx context.Context) error {
    schedule := os.Getenv("ORDER_COMPLETION_SCHEDULE")
    if schedule == "" {
        schedule = "0 0 * * * *" // Hourly
    }
    windowDays := 14
    if envDays := os.Getenv("ORDER_RETURN_WINDOW_DAYS"); envDays != "" {
        if d, err := strconv.Atoi(envDays); err == nil && d > 0 {
            windowDays = d
        }
    }
    w.returnWindow = time.Duration(windowDays) * 24 * time.Hour
    // ... schedule cron, context handling
}

// completeExpiredOrders finds delivered orders past return window
func (w *OrderCompletionWorker) completeExpiredOrders(ctx context.Context) {
    cutoff := time.Now().Add(-w.returnWindow)
    // Find orders: status=delivered AND delivered_at < cutoff
    // Batch update via UpdateOrderStatus
}
```

2. **Add** `OrderRepo.FindDeliveredBefore(ctx, cutoff, limit)` method
3. **Register** worker in `order/internal/worker/workers.go`
4. **Wire** in `order/cmd/worker/wire.go`

**Validation**:
```bash
cd order && wire gen ./cmd/worker/
cd order && go build ./...
cd order && go test ./internal/worker/cron/ -run TestCompletion -v
```

---

### [x] Task 6: Fix Zero-Amount Guard Silent Update Error

**File**: `order/internal/data/eventbus/payment_consumer.go`  
**Line**: 242  
**Risk**: DB update error silently discarded when marking capture_failed

**Change**:
```go
// BEFORE:
_ = c.orderRepo.Update(ctx, ord, nil)

// AFTER:
if updateErr := c.orderRepo.Update(ctx, ord, nil); updateErr != nil {
    c.log.WithContext(ctx).Errorf("[DATA_CONSISTENCY] Failed to mark order %s as capture_failed after zero-amount anomaly: %v", ord.ID, updateErr)
}
```

---

### [x] Task 7: Add Timeout to `validateStockForOrder`

**File**: `order/internal/data/eventbus/payment_consumer.go`  
**Line**: 260  
**Risk**: Slow warehouse service blocks capture processing indefinitely

**Change**:
```go
// BEFORE:
if err := c.validateStockForOrder(ctx, ord); err != nil {

// AFTER:
validateCtx, validateCancel := context.WithTimeout(ctx, 5*time.Second)
defer validateCancel()
if err := c.validateStockForOrder(validateCtx, ord); err != nil {
```

---

## ✅ Checklist — P2 Issues (Backlog)

- [ ] **Task 8**: Unify `isValidStatusTransition` (UseCase method) and `canTransitionTo` (package func) into one approach
- [ ] **Task 9**: Remove PascalCase legacy decode in `shipping_consumer.go` — migrate shipping publisher to snake_case
- [ ] **Task 10**: Migrate `float64` money fields to `int64` cents (cross-service, long-term)
- [ ] **Task 11**: Add `validateStockForOrder` timeout configurable via AppConfig

---

## 🔧 Pre-Commit Checklist

```bash
cd order && wire gen ./cmd/server/ ./cmd/worker/
cd order && go build ./...
cd order && go test -race ./...
cd order && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(order): harden order lifecycle — status constants, reservation DLQ, shipment atomicity

- fix: use OrderStatusCompleted constant instead of "completed" literal
- fix: correct Prometheus OrderValueTotal label (delivered → completed)
- fix: add retry+DLQ to rollbackReservationsMap (prevent stock leak)
- fix: move over-ship guard before CreateShipment
- fix: accept delivery from partially_shipped status
- fix: log zero-amount guard DB update errors
- fix: add 5s timeout to validateStockForOrder
- feat: implement OrderCompletionWorker (delivered → completed after return window)

Closes: AGENT-16
```

---

## 📊 Acceptance Criteria

| Criteria | Verification |
|---|---|
| No `"completed"` string literals in update.go | `grep -rn '"completed"' order/internal/biz/order/update.go` → 0 results |
| Prometheus label correct | `OrderValueTotal` uses `completed` label, not `delivered` |
| Reservation rollback uses retry+DLQ | Unit test: rollback failure → DLQ record created |
| Over-ship rejected before save | Unit test: over-ship → error, no shipment record in DB |
| Delivery from partially_shipped works | Unit test: partially_shipped order + delivery event → status=delivered |
| Auto-completion worker runs | Delivered order + 14d elapsed → status=completed |
| Zero-amount error logged | Log contains `[DATA_CONSISTENCY]` on update failure |
| `go build ./...` passes | Zero errors |
| `go test -race ./...` passes | Zero failures, zero race conditions |
| `golangci-lint` passes | Zero warnings |

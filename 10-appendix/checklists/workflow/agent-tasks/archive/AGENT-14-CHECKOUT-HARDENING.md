# AGENT-14: Checkout Flow Hardening — Fix Critical Saga & Payment Issues

> **Created**: 2026-03-08  
> **Updated**: 2026-03-08 (post-review: aligned with step-runner architecture)  
> **Priority**: P0 (Hotfix before Flash Sale)  
> **Sprint**: Tech Debt Sprint (Feature Freeze)  
> **Services**: `checkout`, `order`  
> **Estimated Effort**: 3–4 days  
> **Source**: [4-Agent Checkout Flow Review](file:///Users/tuananh/.gemini/antigravity/brain/e6ec6d1b-0796-4ea8-ab73-04c9d68be148/checkout_flow_review.md)

---

## 📋 Overview

Checkout Flow (ConfirmCheckout Saga) có **2 P0** và **8 P1** issues được phát hiện bởi review team. Các P0 đều liên quan trực tiếp đến **tiền khách hàng** và **stock integrity** — hai thứ mà khách hàng cảm nhận được ngay khi lỗi xảy ra.

### Saga Flow Context (Step-Runner Architecture)

Checkout Saga sử dụng `StepRunner` với auto-rollback. Mỗi step implement `Execute()` + `Rollback()`:

```
ConfirmCheckout Saga (confirm.go:281-287):

Step 1: IdempotencyStep
  → Redis SETNX lock (checkout:{cartID}:cust:{customerID}:v{cartVersion})
  → Return cached order if already completed

Step 2: ValidatePrerequisitesStep
  → Load & validate session + cart
  → Check address, shipping method, coupon limits
  → Delivery zone (EDGE-04), payment eligibility (EDGE-05)
  → Fraud pre-check (EDGE-03)

Step 3: CalculateTotalsStep
  → Acquire coupon locks (Redis SETNX)
  → Revalidate prices via Pricing service
  → Calculate subtotal, discount, tax, shipping

Step 4: PaymentAuthStep                        ← P0: void auth silent fail (FIXED ✅)
  → AuthorizePayment (skip for COD)
  → ReserveStock JIT (15min TTL)               ← Sequential N roundtrips
  → Rollback(): void auth + release reservations

Step 5: CreateOrderStep                        ← P0: confirm reservation not atomic (FIXED ✅)
  → Build & create order (gRPC to Order service)
  → ApplyPromotion (best-effort, parallel via errgroup)
  → Finalize (outbox cart.converted + cart=completed + delete session)
  → Store idempotency result (Redis, 24h TTL)
```

> **Auto-rollback**: Khi bất kỳ step nào fail, `StepRunner` gọi `Rollback()` của tất cả steps đã execute *ngược lại* (reverse order). Mỗi step tự chịu trách nhiệm cleanup resources của mình.

---

## ✅ Checklist — P0 Issues (MUST FIX — HOTFIX)

### [x] Task 1: Add DLQ for VoidAuthorization on Stock Reserve Failure ✅ IMPLEMENTED

**Files**:
- Helper: `checkout/internal/biz/checkout/confirm_guards.go` — lines 180–225
- Rollback caller: `checkout/internal/biz/checkout/confirm_step_payment.go` — lines 46–55
- COD constant: `checkout/internal/biz/checkout/constants.go` — line 37
- Tests: `checkout/internal/biz/checkout/confirm_test.go` — lines 203–282

**Risk**: Tiền khách hàng bị hold 5-7 ngày khi stock reserve fail nhưng void auth cũng fail

**Problem**: Khi stock reserve fail (Step 4), code void payment auth nhưng **discard error** (`_ =`). Không có DLQ retry.

**Solution Applied**:

1. **Extracted `voidAuthorizationWithDLQ` helper** — in `confirm_guards.go:180-225`:

```go
// voidAuthorizationWithDLQ voids a payment authorization with DLQ fallback.
// If VoidAuthorization fails, saves a FailedCompensation record for async retry.
func (uc *UseCase) voidAuthorizationWithDLQ(ctx context.Context, authID, cartID string, amount float64, triggerReason string) {
    if authID == "" || authID == codAuthSkippedSentinel {
        return
    }

    voidErr := uc.paymentService.VoidAuthorization(ctx, authID)
    if voidErr == nil {
        uc.log.WithContext(ctx).Infof("Voided payment authorization %s (trigger: %s)", authID, triggerReason)
        return
    }

    uc.log.WithContext(ctx).Errorf("[CRITICAL] Failed to void payment auth %s (trigger: %s): %v", authID, triggerReason, voidErr)

    if uc.failedCompensationRepo == nil {
        uc.log.WithContext(ctx).Errorf("[DATA_CONSISTENCY] No failedCompensationRepo — void auth %s cannot be retried", authID)
        return
    }

    metadata := map[string]interface{}{
        "authorization_id": authID,
        "amount":           amount,
        "cart_id":          cartID,
        "trigger":          triggerReason,
        "void_error":       voidErr.Error(),
    }
    metadataJSON, _ := json.Marshal(metadata)

    failedComp := &model.FailedCompensation{
        OrderID:       "", // No order yet
        OperationType: "void_authorization",
        ErrorMessage:  voidErr.Error(),
        RetryCount:    0,
        MaxRetries:    5,
        Status:        "pending",
        AlertSent:     false,
        Metadata:      string(metadataJSON),
    }

    if createErr := uc.failedCompensationRepo.Create(ctx, failedComp); createErr != nil {
        uc.log.WithContext(ctx).Errorf("[CRITICAL] Failed to save void compensation DLQ: auth=%s, err=%v", authID, createErr)
    } else {
        uc.log.WithContext(ctx).Infof("Saved void authorization to DLQ for async retry: auth=%s", authID)
    }
}
```

2. **COD sentinel constant** — in `constants.go:37`:
```go
codAuthSkippedSentinel = "cod-auth-skipped"
```

3. **Step-runner `PaymentAuthStep.Rollback()`** handles both stock-fail and order-fail via auto-rollback — in `confirm_step_payment.go:46-55`:
```go
func (s *PaymentAuthStep) Rollback(c *CheckoutContext) {
    if c.ReservationMap != nil {
        s.uc.RollbackReservationsMap(c.Ctx, c.ReservationMap)
    }

    if c.AuthResult != nil && c.AuthResult.AuthorizationID != "" && c.AuthResult.AuthorizationID != codAuthSkippedSentinel {
        s.uc.log.WithContext(c.Ctx).Warnf("Voiding payment auth %s due to checkout error", c.AuthResult.AuthorizationID)
        s.uc.voidAuthorizationWithDLQ(c.Ctx, c.AuthResult.AuthorizationID, c.Request.CartID, c.Totals.TotalAmount, "checkout_flow_failed")
    }
}
```

4. **Unit tests** in `confirm_test.go`:
   - `TestVoidAuthorizationWithDLQ_Success` — void succeeds, no DLQ
   - `TestVoidAuthorizationWithDLQ_VoidFails_SavesDLQ` — void fails, DLQ saved
   - `TestVoidAuthorizationWithDLQ_CODSkipped` — COD orders skip void
   - `TestVoidAuthorizationWithDLQ_NilRepo` — no repo, logs error

**Validation**:
```bash
cd checkout && go build ./...
cd checkout && go test ./internal/biz/checkout/ -run TestVoidAuth -v
```

---

### [x] Task 2: Make ConfirmReservation + Outbox Event Atomic ✅ IMPLEMENTED

**File**: `order/internal/biz/order/create.go`  
**Lines**: 319–351 (function `ConfirmOrderReservations`)  
**Risk**: Stock committed but event lost → downstream services not notified; silent rollback fail → stock leak

**Problem 1**: `publishStockCommittedEvent` gửi outbox save NGOÀI transaction — outbox save fail nhưng stock đã bị trừ.

**Problem 2**: Rollback `ReleaseReservation` dùng `_ =` (discard error) — KHÔNG có retry hay DLQ. Nhưng `cancel.go` có `releaseReservationWithRetry` + DLQ.

**Solution Applied** — in `create.go:319-351`:

```go
func (uc *UseCase) ConfirmOrderReservations(ctx context.Context, order *Order) error {
    var confirmedReservations []string
    orderID := order.ID

    for _, item := range order.Items {
        if item.ReservationID != nil && *item.ReservationID != "" {
            err := uc.warehouseInventoryService.ConfirmReservation(ctx, *item.ReservationID, &orderID)
            if err != nil {
                // Use retry+DLQ pattern (same as cancel.go)
                for _, resID := range confirmedReservations {
                    releaseErr := uc.releaseReservationWithRetry(ctx, resID, 3)
                    if releaseErr != nil {
                        uc.log.WithContext(ctx).Errorf("[CRITICAL] Failed to rollback confirmed reservation %s: %v", resID, releaseErr)
                        uc.writeReservationReleaseDLQ(ctx, orderID, resID, releaseErr)
                    }
                }
                return fmt.Errorf("failed to confirm reservation %s for item %s: %w", *item.ReservationID, item.ProductID, err)
            }
            confirmedReservations = append(confirmedReservations, *item.ReservationID)
        }
    }

    // Save outbox event within transaction for atomicity
    err := uc.tm.WithTransaction(ctx, func(txCtx context.Context) error {
        return uc.publishStockCommittedEvent(txCtx, order)
    })
    if err != nil {
        // Stock is committed but event cannot be persisted — log critical
        uc.log.WithContext(ctx).Errorf("[CRITICAL] Stock committed for order %s but outbox event save failed: %v. Manual intervention required.", order.ID, err)
    }

    return nil
}
```

**Unit tests**:
- `TestConfirmOrderReservations_PartialFail_DLQ` — 3rd item fails, first 2 get DLQ
- `TestConfirmOrderReservations_OutboxFail_StockStillCommitted` — outbox fail logged as critical

**Validation**:
```bash
cd order && go build ./...
cd order && go test ./internal/biz/order/ -run TestConfirmOrderReservations -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Validate CartSessionID Required ✅ IMPLEMENTED

**File**: `order/internal/biz/order/create.go`  
**Lines**: 42–43

**Implemented** — validation present after CustomerID check:
```go
if req.CustomerID == "" {
    return nil, fmt.Errorf("customer_id required")
}
if req.CartSessionID == "" {
    return nil, fmt.Errorf("cart_session_id required for idempotency")
}
```

---

### [x] Task 4: Replace String-Based Error Classification in Cancel ✅ IMPLEMENTED

**File**: `order/internal/biz/order/cancel.go`  
**Lines**: 68–69

**Implemented** — uses gRPC status code with string fallback (belt-and-suspenders):
```go
st, ok := status.FromError(releaseErr)
if (ok && st.Code() == codes.FailedPrecondition) || strings.Contains(releaseErr.Error(), "not active") {
    // Reservation not active (already confirmed/expired)
```

> **Note**: String check retained as fallback vì warehouse service có thể chưa return gRPC error codes nhất quán cho tất cả edge cases.

---

### [x] Task 5: Replace String-Based isUniqueViolation ✅ IMPLEMENTED

**File**: `order/internal/biz/order/create.go`  
**Lines**: 221–233

**Implemented** — uses `pgconn.PgError` code 23505 with string fallback:
```go
func isUniqueViolation(err error) bool {
    var pgErr *pgconn.PgError
    if errors.As(err, &pgErr) && pgErr.Code == "23505" {
        return true
    }
    // Fallback for wrapped errors
    if err != nil {
        errStr := err.Error()
        return strings.Contains(errStr, "duplicate key value violates unique constraint") ||
            strings.Contains(errStr, "unique constraint")
    }
    return false
}
```

---

### [x] Task 6: Extract Duplicate Event Payload Builder ✅ IMPLEMENTED

**File**: `order/internal/biz/order/events.go`  
**Lines**: 14–47

**Implemented** — `buildOrderEventItems()` and `buildStatusChangedEvent()` extracted:
```go
func buildOrderEventItems(items []*OrderItem) []events.OrderItemEvent { ... }
func buildStatusChangedEvent(order *Order, oldStatus, newStatus, reason string) *events.OrderStatusChangedEvent { ... }
```

Used by: `CreateOrder` (line 89), `PublishOrderStatusChangedEvent` (line 65), `saveStatusChangedToOutbox` (line 80).

---

### [x] Task 7: Add Alert for Reservation Expiry on Confirmed Orders ✅ IMPLEMENTED

**File**: `order/internal/data/eventbus/warehouse_consumer.go`  
**Lines**: 151–155

**Implemented** — `[OPS_ALERT]` log after the "not cancelable" skip:
```go
if currentOrder.Status == constants.OrderStatusConfirmed || currentOrder.Status == constants.OrderStatusProcessing {
    c.log.WithContext(ctx).Errorf("[OPS_ALERT] Order %s is %s but reservation %s expired. Fulfillment may be impacted. Product=%s, Qty=%d",
        orderID, currentOrder.Status, event.ReservationID, event.ProductID, event.QuantityReleased)
}
```

---

### [x] Task 8: Guard Against Zero Amount Capture ✅ IMPLEMENTED

**File**: `order/internal/data/eventbus/payment_consumer.go`  
**Lines**: 228–244

**Implemented** — M-4 fallback + zero/negative guard:
```go
captureAmount := ord.TotalAmount
if captureAmount <= 0 {
    // Fallback to event amount
    captureAmount = eventData.Amount
}

if captureAmount <= 0 {
    // Anomaly: both DB and event have zero/negative — skip capture, mark failed
    failed := constants.PaymentSagaStateCaptureFailed
    ord.PaymentSagaState = &failed
    ord.PaymentStatus = constants.PaymentStatusFailed
    _ = c.orderRepo.Update(ctx, ord, nil) // ⚠️ See Task 11
    return fmt.Errorf("capture amount is zero/negative for order %s", ord.ID)
}
```

---

## ✅ Checklist — P1 Issues (Post-Review Additions)

### [x] Task 11: Fix Discarded Error in Zero-Capture Guard *(NEW — discovered in review)*

**File**: `order/internal/data/eventbus/payment_consumer.go`  
**Line**: 242  
**Risk**: Order stays in limbo state nếu DB update fail — `_ =` discard error tạo infinite retry loop

**Problem**: Task 8 fixed the zero-capture guard nhưng dùng `_ = c.orderRepo.Update(ctx, ord, nil)` — **cùng anti-pattern** mà Task 1 đã fix (`_ = VoidAuthorization`). Nếu update fail, order không được mark `capture_failed` nhưng error vẫn returned → Dapr retry → infinite loop vì order state chưa thay đổi.

**Fix**:
```go
// BEFORE (line 242):
_ = c.orderRepo.Update(ctx, ord, nil)

// AFTER:
if updateErr := c.orderRepo.Update(ctx, ord, nil); updateErr != nil {
    c.log.WithContext(ctx).Errorf("[DATA_CONSISTENCY] Failed to mark order %s as capture_failed after zero-amount anomaly: %v", ord.ID, updateErr)
}
```

**Validation**:
```bash
cd order && go build ./...
cd order && grep -n '_ = c.orderRepo.Update' order/internal/data/eventbus/payment_consumer.go
# Should return zero results after fix
```

---

### [x] Task 12: Use Typed Errors for CreateOrder Metrics Classification *(NEW — discovered in review)*

**File**: `order/internal/biz/order/create.go`  
**Lines**: 142–150  
**Risk**: Fragile error classification cho Prometheus metrics — cùng pattern string-based mà Task 4 đã fix

**Problem**: Error classification for metrics dùng `strings.Contains(err.Error(), "validation")`, `"payment"`, `"inventory"`, etc. — inconsistent với Task 4 approach (gRPC status codes).

**Fix**:
```go
// BEFORE (create.go:139-150):
reason := "unknown"
if isUniqueViolation(err) {
    reason = "idempotency_violation"
} else if strings.Contains(err.Error(), "validation") {
    reason = "validation_error"
} else if strings.Contains(err.Error(), "payment") {
    reason = "payment_failed"
} else if strings.Contains(err.Error(), "inventory") || strings.Contains(err.Error(), "stock") {
    reason = "inventory_error"
} else if strings.Contains(err.Error(), "database") || strings.Contains(err.Error(), "connection") {
    reason = "database_error"
}

// AFTER: Use typed errors or gRPC status codes
reason := classifyCreateOrderError(err)

// New helper:
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
        }
    }
    // Fallback for non-gRPC errors
    errStr := err.Error()
    switch {
    case strings.Contains(errStr, "validation"):
        return "validation_error"
    case strings.Contains(errStr, "payment"):
        return "payment_failed"
    case strings.Contains(errStr, "inventory") || strings.Contains(errStr, "stock"):
        return "inventory_error"
    case strings.Contains(errStr, "database") || strings.Contains(errStr, "connection"):
        return "database_error"
    default:
        return "unknown"
    }
}
```

> **Note**: Giữ string-based fallback vì không phải tất cả errors đều là gRPC errors. Nhưng ưu tiên typed check trước.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 9: Implement/Verify CompensationWorker in Checkout ✅ IMPLEMENTED

**Risk**: Failed compensations (void auth) saved to DB but never retried if worker is missing.  
**Action**: Ensure `checkout/internal/worker/compensation_worker.go` exists and is wired to poll `failed_compensations` table.

**Verification**:
```bash
# Verify worker exists
ls checkout/internal/worker/compensation_worker.go

# Verify wired into worker binary
grep -r "FailedCompensation" checkout/cmd/worker/ --include='*.go'

# Verify Wire provider
grep -r "compensation" checkout/cmd/worker/wire.go checkout/cmd/worker/wire_gen.go
```

---

### [x] Task 10: Increase Warehouse Reservation TTL (30 min)

**Risk**: Long payment sessions (e.g. 3rd party gateways) cause reservation to expire before order confirmation.  
**Action**: Update `checkout/internal/biz/checkout/reserve.go` (or config) to use 30 minutes instead of 15.

> **⚠️ Note**: KI audit finding trước đó ghi "*Config Mismatch (Fixed): reservation_timeout_minutes in GitOps (30m) now matches code TTL (15m)*" — tức GitOps đã align xuống 15m để match code. Nếu tăng code lên 30m thì cả hai sẽ là 30m (consistent), nhưng cần confirm business decision: 15m hay 30m là đúng cho payment window? Với 3rd party gateways (3DS, bank OTP), 30 phút an toàn hơn.

---

## 🔧 Pre-Commit Checklist

```bash
# Checkout service
cd checkout && wire gen ./cmd/server/ ./cmd/worker/
cd checkout && go build ./...
cd checkout && go test -race ./...
cd checkout && golangci-lint run ./...

# Order service
cd order && wire gen ./cmd/server/ ./cmd/worker/
cd order && go build ./...
cd order && go test -race ./...
cd order && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(checkout,order): harden checkout saga compensation & stock integrity

Checkout service:
- fix: add DLQ for void authorization on stock reserve failure (P0)
- refactor: extract voidAuthorizationWithDLQ helper (DRY)
- fix: use COD sentinel constant instead of hardcoded string

Order service:
- fix: wrap outbox save in transaction for ConfirmOrderReservations (P0)
- fix: use retry+DLQ for reservation rollback (consistent with cancel.go)
- fix: validate CartSessionID required for idempotency
- fix: use pgconn.PgError for unique violation detection
- fix: guard against zero-amount payment capture
- fix: handle orderRepo.Update error in zero-capture guard (Task 11)
- refactor: extract buildStatusChangedEvent helper (DRY)
- refactor: extract classifyCreateOrderError helper (Task 12)
- feat: add ops alert for reservation expiry on confirmed orders

Closes: AGENT-14
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Void auth failure creates DLQ entry | Unit test `TestVoidAuthorizationWithDLQ_VoidFails_SavesDLQ` | ✅ |
| COD orders skip void auth | Unit test `TestVoidAuthorizationWithDLQ_CODSkipped` | ✅ |
| Stock committed event is in transaction | Unit test `TestConfirmOrderReservations_OutboxInTx` | ✅ |
| Reservation rollback uses retry+DLQ | Unit test `TestConfirmOrderReservations_PartialFail_DLQ` | ✅ |
| CartSessionID required | `CreateOrder` with empty CartSessionID → error | ✅ |
| Zero capture rejected | `processPaymentCaptureRequested` with $0 → skip + log | ✅ |
| Zero capture DB update error handled | No `_ =` on orderRepo.Update in zero-capture path | ✅ |
| Confirmed order + expired reservation → alert | Log contains `[OPS_ALERT]` | ✅ |
| Error classification uses typed errors | `classifyCreateOrderError` prefers gRPC codes | ✅ |
| `go build ./...` passes | Zero errors (both services) | ✅ |
| `go test -race ./...` passes | Zero race conditions | ✅ |
| `golangci-lint` passes | Zero warnings | ✅ |
| CompensationWorker exists and wired | `ls` + `grep` verification (Task 9) | ✅ |

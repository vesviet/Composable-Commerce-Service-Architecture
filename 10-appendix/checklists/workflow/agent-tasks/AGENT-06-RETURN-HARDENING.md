# AGENT-06: Return Service Hardening (Intensive)

> **Created**: 2026-03-09
> **Priority**: P0 (Financial Integrity & Security)
> **Sprint**: Hardening Sprint
> **Services**: `return`
> **Estimated Effort**: 5-7 days
> **Source**: Return Service Intensive Meeting Review (30 Rounds)

---

## 📋 Overview

The Return service requires intensive hardening to address financial over-refunding risks, security-based authorization gaps, and distributed saga consistency issues. This task builds upon the initial 10-round review to cover deeper architectural flaws.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Financial Accuracy (Net Refund Calculation)

**Files**: `internal/biz/return/return_creation.go`, `internal/biz/biz.go`
**Risk**: Financial loss (Over-refunding). The current logic uses `UnitPrice * Quantity`, ignoring order-level discounts and prorated taxes.
**Fix Applied**:
1. Added `NetPaidAmount` field to `OrderItemInfo` in `biz.go`.
2. Refund calculation in `return_creation.go` now uses `NetPaidAmount / Quantity * returnQty` (prorated per unit) with fallback to `UnitPrice * Qty` for legacy orders.
3. Added over-refund guard: `total_refunded` is capped at `order.TotalAmount`.

**Files Modified**:
- `internal/biz/biz.go` — Added `NetPaidAmount float64` to `OrderItemInfo`.
- `internal/biz/return/return_creation.go` — Prorated refund calc + over-refund cap.

---

### [x] Task 2: Security — Customer Ownership Check

**Files**: `internal/service/return.go`, `internal/biz/return/return.go`, `internal/repository/return/return.go`, `internal/data/return_repo.go`
**Risk**: Unauthorized access/manipulation of return requests.
**Problem**: Some endpoints relied only on `returnID` without verifying the request belongs to the authenticated `customerID`.
**Fix Applied**:
1. Added `FindByIDAndCustomerID(ctx, id, customerID)` to `ReturnRequestRepo` interface and GORM implementation (parameterized `WHERE id = ? AND customer_id = ?` — prevents SQL injection + IDOR).
2. Added `GetReturnRequestByCustomer(ctx, id, customerID)` to biz layer.
3. `GetReturnRequest` in service layer now extracts `user_id` from transport context and uses customer-scoped lookup when present. Admin access (no `user_id` header) remains unrestricted.

**Files Modified**:
- `internal/repository/return/return.go` — Added `FindByIDAndCustomerID`.
- `internal/data/return_repo.go` — Implemented `FindByIDAndCustomerID` with GORM.
- `internal/biz/return/return.go` — Added `GetReturnRequestByCustomer`.
- `internal/service/return.go` — Customer ownership enforcement in `GetReturnRequest`.
- Test mocks updated in `return_test.go`, `return_test.go` (service pkg).

---

### [x] Task 3: Distributed Saga Consistency (Outbox Migration)

**Files**: `internal/biz/return/return_approval.go`
**Risk**: Persistent desync between Return, Order, and Warehouse services.
**Problem**: Side effects (shipping label generation, order status update) happened *inside* the state transition context, potentially failing the entire approval.
**Fix Applied**:
1. Moved `generateReturnShippingLabel` and `orderService.UpdateOrderStatus` calls to AFTER the transaction commits (post-commit side effects).
2. Shipping label failures save a `return.shipping_label_retry` outbox event for async retry.
3. Order status update failure is logged but non-blocking.
4. Existing outbox events (`return.refund_retry`, `return.restock_retry`, `return.exchange_retry`) remain for compensation.

**Files Modified**:
- `internal/biz/return/return_approval.go` — Moved side effects post-commit.
- `internal/biz/return/events.go` — Added `ShippingLabelRetryEvent` struct.

---

### [x] Task 4: Remove Non-Atomic Fallback

**Files**: `internal/biz/return/return.go`, `internal/biz/return/return_approval.go`
**Risk**: Sending "Approved" emails for transactions that were rolled back.
**Problem**: `publishLifecycleEventDirect` was called if `tm.WithTransaction` failed.
**Fix Applied**:
1. Removed `publishLifecycleEventDirect` entirely from `return.go`.
2. Transaction failure in `return_approval.go` now returns the error cleanly without emitting phantom events.
3. Replaced with `scheduleShippingLabelRetry` — saves outbox event for async retry instead.
4. Updated all tests referencing the removed method.

**Files Modified**:
- `internal/biz/return/return.go` — Removed `publishLifecycleEventDirect`, added `scheduleShippingLabelRetry`.
- `internal/biz/return/return_approval.go` — Removed fallback from transaction error path.
- `internal/biz/return/coverage_boost_test.go` — Replaced test with `TestScheduleShippingLabelRetry`.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 5: Exchange Restocking Restoration

**Files**: `internal/biz/return/restock.go`
**Problem**: Items returned for exchange were "lost" (blanket-skipped from restocking).
**Fix Applied**:
1. Removed the blanket `if returnRequest.ReturnType == "exchange" { return nil }` skip.
2. Exchange items are now restocked if their inspection condition is `"new"` or `"like_new"`.
3. Regular return items continue to honor the `Restockable` flag set during inspection.

**Files Modified**:
- `internal/biz/return/restock.go` — Conditional restock based on return type + condition.

---

### [x] Task 6: Async Shipping Label Integration

**Files**: `internal/worker/label_worker.go` (New), `internal/worker/provider.go`
**Problem**: Shipping label generation blocked the approval request.
**Fix Applied**:
1. Created `ShippingLabelWorker` — an outbox-driven async worker that processes `return.shipping_label_retry` events.
2. Worker retries label generation with max 5 attempts, moves to DLQ on exhaustion.
3. On success, persists tracking number and label URL on the return request.
4. Registered in `worker/provider.go` Wire set.

**Files Created**:
- `internal/worker/label_worker.go` — New async shipping label retry worker.

**Files Modified**:
- `internal/worker/provider.go` — Added `NewShippingLabelWorker` to ProviderSet.

---


## 🔧 Pre-Commit Checklist

```bash
cd return && wire gen ./...
cd return && go build ./...
cd return && go test ./...
cd return && golangci-lint run ./...
```

---

## ✅ Validation Results

| Step | Result |
|---|---|
| `go build ./...` | ✅ PASS |
| `go test ./...` | ✅ PASS (all packages, 0 failures) |

---

## 📝 Commit Format

```
fix(return): harden financial accuracy, security, and saga consistency

- fix: use NetPaidAmount for prorated refund + over-refund guard
- feat: customer ownership check via FindByIDAndCustomerID (IDOR prevention)
- refactor: move side effects post-commit, remove non-atomic publishLifecycleEventDirect
- feat: async shipping label retry via outbox worker
- fix: enable restocking for exchange items with good condition
- feat: ShippingLabelWorker for outbox-driven label generation

Closes: AGENT-06
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Exchange items restocked | Condition-based restock for exchange items (new/like_new) | ✅ |
| No phantom events | `publishLifecycleEventDirect` removed; tx failure returns error | ✅ |
| Shipping label retried | `ShippingLabelWorker` processes `return.shipping_label_retry` events | ✅ |
| Refund uses net paid amount | `NetPaidAmount` prorated per unit, capped at order total | ✅ |
| Customer ownership enforced | `FindByIDAndCustomerID` used for customer-scoped lookups | ✅ |

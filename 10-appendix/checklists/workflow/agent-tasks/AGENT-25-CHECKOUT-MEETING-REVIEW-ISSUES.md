# AGENT-25: Checkout Service — Cart & Checkout Hardening Tasks

> **Created**: 2026-03-10
> **Priority**: P0
> **Sprint**: Tech Debt Sprint
> **Services**: `checkout`, `order`
> **Estimated Effort**: 3-5 days
> **Source**: [100-Round Cart & Checkout Meeting Review Artifact](file:///home/user/.gemini/antigravity/brain/01390264-3ea5-4ab7-8fa5-b7e7e24e3048/cart_checkout_meeting_review.md)

---

## 📋 Overview

A comprehensive 100-round multi-agent meeting review identified critical P0 and P1 issues in the Cart & Checkout flows. This task covers fixing distributed transaction atomicity, warehouse reservation idempotency, blind price updates, query contention, and context timeouts.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix Distributed Transaction & Outbox Placement

**File**: `checkout/internal/biz/checkout/confirm.go`
**Lines**: 201-239
**Risk**: If gRPC call to `Order Service` succeeds but Checkout service crashes before inserting `CartConverted` to the outbox, the outbox event is permanently lost.
**Problem**: The `CartConverted` outbox event is persisted locally in the Checkout service *after* the Order is successfully created via gRPC. 
**Fix**:
Remove the outbox insertion from the Checkout service. Move the `CartConverted` logic to the `Order Service` so that it's published in the same database transaction when the Order is persisted.

**Validation**:
```bash
cd order && go test ./internal/biz/... -v
cd checkout && go test ./internal/biz/checkout/ -run TestFinalizeOrderAndCleanup -v
```

### [ ] Task 2: Update Warehouse Reservation Idempotency Key

**File**: `checkout/internal/biz/checkout/confirm.go`
**Lines**: 151
**Risk**: If a user checks out, fails/cancels, changes the item quantity and checks out again, the warehouse service will return the cached reservation matching the old quantity.
**Problem**: The idempotency key `reserve:%s:%s:%s` uses CartID and ProductID. It does not account for CartVersion or Quantity changes.
**Fix**:
```go
// BEFORE:
idempotencyKey := fmt.Sprintf("reserve:%s:%s:%s", cart.CartID, item.ProductID, warehouseID)

// AFTER:
idempotencyKey := fmt.Sprintf("reserve:%s:%s:%s:v%d", cart.CartID, item.ProductID, warehouseID, cartVersion)
// Note: Requires passing cartVersion to reserveStockForOrder
```

**Validation**:
```bash
cd checkout && go test ./internal/biz/checkout/ -run TestReserveStock -v
```

### [ ] Task 3: Prevent Blind Price Update Between Cart & Checkout

**File**: `checkout/internal/biz/checkout/confirm.go`
**Lines**: Needs adding into Checkout preparation steps
**Risk**: Silent price increases between when an item is added to the cart and when checkout is confirmed. Users might be charged more than they expected.
**Problem**: No check between `cart.TotalPrice` (pre-checkout) and `livePrice` (calculated during Checkout Confirm step).
**Fix**:
Implement a check comparing `modelCart` totals and the real-time calculated `OrderTotals`. If `OrderTotals.TotalAmount > cart.CartTotal`, return a structured error `ErrPriceChanged` requesting the user to verify the new totals.

**Validation**:
```bash
cd checkout && go test ./internal/biz/checkout/ -run TestCalculateTotalsStep -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 4: Add Context Timeout in `AddToCart` Goroutines

**File**: `checkout/internal/biz/cart/add.go`
**Lines**: 82
**Risk**: Connection pool exhaustion and memory leaks if Pricing or Inventory services hang.
**Problem**: The `errgroup` context is taken directly from the gRPC request context without an explicit timeout.
**Fix**:
```go
// BEFORE:
eg, egCtx := errgroup.WithContext(ctx)

// AFTER:
egCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
defer cancel()
eg, egCtx := errgroup.WithContext(egCtx)
```

**Validation**:
```bash
cd checkout && go test ./internal/biz/cart/ -run TestAddToCart -v
```

### [ ] Task 5: Prevent Cart Row Lock Contention (`LoadCartForUpdate`)

**File**: `checkout/internal/biz/cart/add.go`
**Lines**: 215
**Risk**: High DB lock contention leading to slow response times or failures during Flash Sales.
**Problem**: Spam clicks on `AddToCart` lock the same PostgreSQL row repeatedly.
**Fix**:
Implement a Redis-based Rate Limiter (e.g., using `constants.RedisKeyRateLimitAddToCart`) to limit `AddToCart` frequency per `CartID` or `SessionID` before the DB transaction begins.

**Validation**:
```bash
cd checkout && go test ./internal/biz/cart/ -run TestAddToCart_RateLimit -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd checkout && wire gen ./cmd/server/ ./cmd/worker/
cd checkout && go build ./...
cd checkout && go test -race ./...
cd checkout && golangci-lint run ./...
```

---

## 📝 Commit Format

```
docs(agent-tasks): update checkout service hardening tasks

- docs: assign outbox consistency fix and idempotency key fix (P0)
- docs: assign blind price update prevention in checkout (P0)
- docs: add context timeout to AddToCart (P1)
- docs: add rate limit to AddToCart to prevent DB lock contention (P1)

Closes: AGENT-25
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Outbox event relocated | `grep 'CartConverted' order/internal/biz/` produces hit | |
| Idempotency Key includes CartVersion | `grep 'reserve:.*:v%d' checkout/internal/biz/checkout/confirm.go` | |
| Price change detection added | `grep 'ErrPriceChanged' checkout/internal/biz/checkout/` | |
| Context Timeout applied to errgroup | `grep 'WithTimeout' checkout/internal/biz/cart/add.go` | |
| Rate Limit added to AddToCart | `grep 'RateLimit' checkout/internal/biz/cart/add.go` | |

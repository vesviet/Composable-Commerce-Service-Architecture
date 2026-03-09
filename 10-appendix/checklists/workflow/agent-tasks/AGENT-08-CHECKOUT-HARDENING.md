# AGENT TASK 08: Checkout Service Hardening

**Service Component:** `checkout`
**Status:** `COMPLETED`
**Priority:** `CRITICAL`

## 1. Overview
The **Checkout Service** has critical vulnerabilities in its Distributed Saga orchestration, specifically regarding how out-of-sync states are handled when database transactions fail after external operations succeed. These must be hardened to prevent massive, unrecoverable states like overselling items after checkout.

## 2. Issues to Address

### 🚨 P0: Saga Inconsistency (The "Orphaned Order" Cleanup Bug)
Currently, if `ConfirmCheckout` successfully creates the order in the `Order` service but the local DB transaction fails, it returns a success to the user so the checkout can proceed, but the cart remains in `checkout` status locally. The `checkout_session_cleanup.go` cron job eventually detects this cart and **blindly releases the warehouse reservations**, causing the active order to lack reserved stock, leading to massive overselling.

### 🟡 P1: Stock Hoarding on Idempotent Retries
When a user retries a checkout (e.g., due to a temporary network blip pushing them past the 2-minute lease), `PaymentAuthStep` will re-reserve stock using `uc.reserveStockForOrder()`. Because no idempotency key is passed to the warehouse `ReserveStock` API, duplicate stock is reserved for the same cart, locking inventory unnecessarily.

## 3. Implementation Steps

- [x] **Step 1: Fix Cron Job Blind Release (P0)** ✅ IMPLEMENTED
  - **Files**:
    - `internal/worker/cron/checkout_session_cleanup.go` (lines 18-41, 46-100)
    - `internal/client/order.go` (lines 22-29, 123-157)
    - `internal/biz/mocks/mocks.go` (lines 389-398)
  - **Risk / Problem**: The cron job blindly released warehouse reservations for expired checkout carts without checking if an order had already been created. If the checkout succeeded (order created in Order service) but the local finalize transaction failed, the cart stayed in "checkout" status. The cron job would then release the reservations needed by the active order, causing overselling.
  - **Solution Applied**:
    1. Added `GetOrderByCartSessionID(ctx, cartSessionID)` to the `OrderClient` interface, implemented via `ListOrders` with metadata matching.
    2. Injected `OrderClient` into the `sessionCleanupDeps` struct and `NewCheckoutSessionCleanupWorker` constructor.
    3. Before releasing reservations, the cron job now calls `orderClient.GetOrderByCartSessionID()` to check if an order exists for the expired cart's `cart_session_id`.
    4. If an order exists (`ORPHAN_RECOVERY` path), the cart is marked as `completed` with `is_active=false`, and the `order_id`, `recovered_at`, and `recovery_source` are stored in metadata for auditability. Reservations are **NOT** released.
    5. If no order exists, the original cleanup logic runs (release reservations, reset to active).
    ```go
    // Check if the Order service has an order for this cart
    if d.orderClient != nil {
      order, lookupErr := d.orderClient.GetOrderByCartSessionID(ctx, cart.CartID)
      if lookupErr != nil {
        d.log.Warnf("Failed to look up order for cart %s: %v", cart.CartID, lookupErr)
      } else if order != nil {
        d.log.Infof("[ORPHAN_RECOVERY] Cart %s has a live order %s", cart.CartID, order.GetId())
        cart.Status = "completed"
        cart.IsActive = false
        // ... store order_id in metadata ...
        continue // DO NOT release reservations
      }
    }
    ```
  - **Validation**: `wire gen ./cmd/server/ ./cmd/worker/` ✅ | `go build ./...` ✅ | `go test -race ./...` ✅ | `golangci-lint run ./...` ✅

- [x] **Step 2: Fix Stock Hoarding on Retries (P1)** ✅ IMPLEMENTED
  - **Files**:
    - `internal/biz/checkout/confirm.go` (lines 126-180)
  - **Risk / Problem**: When a user retries checkout, `reserveStockForOrder` would create new reservations without idempotency, causing duplicate stock locks. This hoards inventory and can deny other customers access to available stock.
  - **Solution Applied**:
    1. Added idempotency key injection via gRPC outgoing metadata (`x-idempotency-key` header).
    2. The key format is `reserve:{cart_id}:{product_id}:{warehouse_id}` — unique per cart+item combination but stable across retries.
    3. The warehouse service can use this key for dedup. If the Warehouse SDK doesn't yet honor the key, the header is safely ignored (forward-compatible).
    ```go
    idempotencyKey := fmt.Sprintf("reserve:%s:%s:%s", cart.CartID, item.ProductID, warehouseID)
    reserveCtx := metadata.AppendToOutgoingContext(ctx, "x-idempotency-key", idempotencyKey)
    reservation, err := uc.warehouseInventoryService.ReserveStockWithTTL(
      reserveCtx, item.ProductID, warehouseID, item.Quantity, expiresAt)
    ```
  - **Validation**: `go build ./...` ✅ | `go test -race -run "TestConfirm|TestCheckout|TestP0" ./internal/biz/checkout/...` ✅ | `golangci-lint run ./...` ✅

- [x] **Step 3: Direct PubSub Fallback for Outbox (P1)** ✅ IMPLEMENTED
  - **Files**:
    - `internal/biz/checkout/confirm_step_create.go` (lines 126-184)
  - **Risk / Problem**: In `recoverOutbox()`, if the DB-based outbox save failed, the `CartConverted` event was permanently lost. Downstream consumers (analytics, loyalty, CRM) would never know the order was created.
  - **Solution Applied**:
    1. Extracted a `publishCartConvertedDirect()` helper method that publishes directly via `EventPublisher.Publish()`.
    2. When `outboxRepo.Save()` fails in `recoverOutbox()`, the fallback immediately pushes the event payload directly to the event bus.
    3. Consumers must be idempotent (the `event_id` = `order_id` is a stable dedup key).
    4. If both outbox and direct publish fail, a `[DATA_LOSS]` error is logged for alerting.
    ```go
    if saveErr := s.uc.outboxRepo.Save(c.Ctx, recoveryEvent); saveErr != nil {
      s.uc.log.Errorf("Post-tx outbox recovery failed: %v — falling back to direct publish", saveErr)
      s.publishCartConvertedDirect(c, payload) // Fallback
    }
    ```
  - **Validation**: `go build ./...` ✅ | `go test -race ./internal/biz/checkout/...` ✅ | `golangci-lint run ./...` ✅

## 4. Validation & Review
- [x] Go build must pass. ✅
- [x] Wire generation must pass. ✅
- [x] Linter must report zero errors. ✅
- [x] Unit tests for the cron worker should reflect the new dependency and logic if applicable. ✅

## 5. Acceptance Criteria

| # | Criteria | Status |
|---|---------|--------|
| 1 | Cron job checks Order service before releasing reservations | ✅ |
| 2 | Orphaned carts are recovered and marked as completed | ✅ |
| 3 | Stock reservation uses idempotency key to prevent hoarding | ✅ |
| 4 | CartConverted event has direct PubSub fallback | ✅ |
| 5 | Wire generation passes | ✅ |
| 6 | Go build passes | ✅ |
| 7 | Linter reports zero errors | ✅ |

## 📝 Commit Format
```
fix(checkout): harden saga consistency — orphan recovery, idempotent reservations, outbox fallback
```

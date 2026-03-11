# AGENT TASK - CART & CHECKOUT FLOWS (AGENT-07)

## STATUS
**State:** [x] Done

## ASSIGNMENT
**Focus Area:** Checkout Sagas & Cart Concurrency
**Primary Services:** `checkout` (internally modules `cart` and `checkout`)
**Priority:** High (P0 fixes required)

## 📌 P0: Saga Outbox Trap in checkout/confirm.go ✅ IMPLEMENTED
**Risk:** When an order is successfully created in the Order service, but the local Outbox save fails (e.g., transient DB insert issue), the checkout flow returns `saveErr` and signals a failure to the user. The user retries, resulting in duplicate orders. The `CartConverted` event should be non-blocking.
**Location:** `checkout/internal/biz/checkout/confirm.go` (Method `finalizeOrderAndCleanup`, Line ~235)

### Implementation Details
- **Files Modified:** `checkout/internal/biz/checkout/confirm.go`, `checkout/internal/biz/checkout/confirm_coverage_test.go`
- **Risk / Problem:** A failed Outbox insert caused `finalizeOrderAndCleanup` to abort and return an error to the client. Since the `Order` was already committed to the external order service, retrying the checkout resulted in double orders / double payments.
- **Solution Applied:** Removed the `return saveErr` on Outbox save failure. Replaced it with a forceful error log (`uc.log.WithContext(ctx).Errorf("[EDGE-07]...")`) so the flow can cleanly complete the cart session. Updated test `TestFinalizeOrderAndCleanup_OutboxError` to expect success instead of `assert.Error`.
- **Validation:** `go test -race -v ./internal/biz/checkout/...` (All passed)

---

## 📌 P0: Blind Struct Update in cart/sync.go ✅ IMPLEMENTED
**Risk:** `SyncCartPrices` fetches pricing data and then updates `modelCart.Items` by calling `uc.cartRepo.UpdateItem(txCtx, &item, nil)`. This passes the *entire struct*, effectively overwriting any concurrent changes made by the user (like updating the item quantity in a separate tab).
**Location:** `checkout/internal/biz/cart/sync.go` (Method `SyncCartPrices`, Line ~106)

### Implementation Details
- **Files Modified:** `checkout/internal/biz/cart/sync.go`
- **Risk / Problem:** Background cart synchronization was fetching prices and committing *all properties* of the item struct via `uc.cartRepo.UpdateItem(txCtx, &item, nil)`. This overrode the `Quantity` field, destroying any changes the user might have made simultaneously.
- **Solution Applied:** Identified that `UpdateItem` accepts an `interface{}` parameter for dynamic column updates (`err := DB(ctx, r.db).Model(m).Updates(params).Error`). Modified the cart resync loops to explicitly pass an `updateFields` map locking updates strictly to pricing fields (`unit_price`, `total_price`, `tax_amount`, `discount_amount`, `updated_at`).
```go
					updateFields := map[string]interface{}{
						"unit_price":      item.UnitPrice,
						"total_price":     item.TotalPrice,
						"tax_amount":      item.TaxAmount,
						"discount_amount": item.DiscountAmount,
						"updated_at":      item.UpdatedAt,
					}
					if err := uc.cartRepo.UpdateItem(txCtx, &item, updateFields); err != nil {
```
- **Validation:** `go test -race -v ./internal/biz/cart/...` (All passed)

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add checkout/internal/biz/checkout/confirm.go
git add checkout/internal/biz/cart/sync.go
git add checkout/internal/biz/checkout/confirm_coverage_test.go

git commit -m "fix(checkout): prevent outbox failure from rolling back successful order creation
fix(cart): use targeted field updates during cart price sync to prevent quantity overwrite races

# Agent-07 Fixes based on 250-Round Meeting Review
# P0: Prevents Duplicate Orders when Outbox DB blips
# P0: Prevents Cart Quantity reset during background price syncing"
```

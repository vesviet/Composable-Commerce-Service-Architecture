# AGENT-08: Cart & Checkout Flow Issues

**Created**: 2026-03-22
**Source**: QA Testing Session — Cart & Checkout Flows (Section 5)
**Priority**: Sorted by severity

---

### [x] Task 1: Fix Cart AddItem API 500 Error (P0 — CRITICAL) ✅ IMPLEMENTED — Root cause: backend required warehouse_id for stock check but frontend never sends it. Fix: defer stock check to checkout when warehouse_id absent.

**Service**: `order` (checkout/cart)
**Endpoint**: `POST /api/v1/cart/items`
**Risk**: Entire purchase funnel is broken — customers cannot buy anything
**Problem**: Adding any product to cart returns `500 Internal Server Error`. Tested with product "Advanced Shirt 7345" (SKU: BLK-007345). Frontend shows error toast "Không thể thêm vào giỏ hàng". This blocks: cart display, checkout flow, promo code application, and order creation.
**Request body**:
```json
{
  "session_id": "<session>",
  "product_id": "BLK-007345",
  "quantity": 1,
  "customer_id": "<uuid>"
}
```
**Verify**: `curl -X POST https://api.tanhdev.com/api/v1/cart/items` should return 200 with cart data.

---

### [ ] Task 2: Verify Full Checkout Flow After Cart Fix (P1)

**Service**: `order` (checkout)
**Risk**: Even if cart works, checkout might have separate failures
**Problem**: Cannot test checkout because cart add fails. Once Task 1 is fixed, need to verify:
1. `POST /api/v1/checkout` — start checkout
2. `PUT /api/v1/checkout/{id}/shipping-address` — add shipping
3. `PUT /api/v1/checkout/{id}/payment-method` — select payment
4. `POST /api/v1/checkout/{id}/confirm` — confirm order
**Verify**: Full checkout creates order visible in admin `/orders` page.

---

### [ ] Task 3: Verify Promo Code Application in Cart (P1)

**Service**: `order` (cart promotions)
**Endpoint**: `POST /api/v1/cart/promotions`
**Risk**: Promotion discounts don't apply during checkout
**Problem**: Cannot test because cart is empty. Once cart works, need to verify:
1. CartSummary promo code input applies code
2. Discount reflects in cart totals
3. Remove promo code works
**Verify**: Apply promo → discount appears in summary → subtotal - discount = total.

---

### [x] Task 4: Add Shipping Address N/A in Orders (P2) ✅ VERIFIED — Address data flows correctly from checkout→order via `convertBizOrderAddressToProtobuf`. Existing test orders show N/A because they were created before checkout fix. New orders will have addresses.

**Service**: `order`
**Risk**: Orders created without shipping address cannot be fulfilled
**Problem**: Both existing orders (ORD-2603-000001, ORD-2662-000002) show "Shipping Address: N/A" in admin detail modal. Either the checkout doesn't collect the address or the order service doesn't persist it.
**Verify**: New orders from checkout should have a shipping address populated in admin.

---

### [x] Task 5: Order Detail Modal Shows USD for VND Products (P2) ✅ IMPLEMENTED — Removed incorrect `/100` cents-to-dollars conversion in `OrdersPage.tsx` and `OrderDetailPage.tsx`. VND amounts are naturally large. Also fixed hardcoded `$` in modal item table to use `Intl.NumberFormat` with dynamic currency.

**Service**: `admin` (frontend formatting)
**File**: `admin/src/pages/OrdersPage.tsx`
**Risk**: Confusing price display for admin users
**Problem**: Order items show prices in USD format (`$5122.27`) even though the product catalog prices are in VND. The `transformOrder` function divides amounts > 100000 by 100 (line 263), which incorrectly converts VND amounts.
**Verify**: Order item prices should match catalog VND prices.

---

### [ ] Task 6: MiniCart Drawer Not Opening on Add to Cart (P2)

**Service**: `frontend`
**File**: `frontend/src/components/cart/MiniCart.tsx`
**Risk**: UX degradation — user gets no visual feedback after successful cart add
**Problem**: Cannot verify if MiniCart drawer opens because Add to Cart fails (Task 1 dependency). Once fixed, need to confirm the MiniCart drawer slides in from the right showing the added item.
**Verify**: Click "Add to Cart" → MiniCart drawer opens with item name, quantity, price, "View Cart" and "Checkout" buttons.

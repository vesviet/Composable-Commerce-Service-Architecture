# 🧪 QC Test Report - Order Flow

> [!NOTE]
> **Historical Snapshot (Archived):** This production QC report dates from 2026-02-26 and is retained for audit reference only. All blocking order-lifecycle and image/pricing defects documented below were resolved and superseded by the 2026-11-23 verification (`54/54` full lifecycle E2E checks passing and `63` Playwright routes with `0` hard fails).

| Field            | Value                                                      |
| :--------------- | :--------------------------------------------------------- |
| **Test Date**    | 2026-02-26                                                 |
| **Tester**       | QC Automation (Senior QC)                                  |
| **Environment**  | Production (`frontend.tanhdev.com` / `api.tanhdev.com`)   |
| **Test Account** | `customer1000@example.com` / `Customer1000@example.com`   |
| **Product**      | Advanced Accessory 10000 (ID: `92094879-412c-4728-865e-cd462e1df99e`) |
| **Overall**      | ❌ **FAILED** - Luồng order bị block, không thể đặt hàng  |

---

## 📊 Test Flow Summary

```
Login → Product Page → Add to Cart (qty: 2) → Cart Sidebar → Checkout
  → Shipping Address → Payment (COD) → Review → Place Order → ❌ FAIL (500 Error)
```

| Step                     | Status | Notes                                    |
| :----------------------- | :----- | :--------------------------------------- |
| 1. Login                 | ✅ Pass | Login thành công                         |
| 2. View Product          | ⚠️ Warn | Product hiển thị OK nhưng **image broken** |
| 3. Select Quantity (2)   | ✅ Pass | Quantity selector hoạt động đúng         |
| 4. Add to Cart           | ⚠️ Warn | Thêm thành công nhưng **thiếu feedback** |
| 5. View Cart             | ❌ Fail | **Giá sai** - 253.000đ thay vì 220.000đ |
| 6. Shipping Address      | ✅ Pass | Form điền OK, validation hoạt động       |
| 7. Shipping Method       | ⚠️ Warn | **Shipping fee inconsistent** (50k vs 60k) |
| 8. Payment Method (COD)  | ✅ Pass | Chọn COD thành công                     |
| 9. Order Review          | ❌ Fail | Giá sai cascade từ cart                  |
| 10. Place Order          | ❌ **BLOCKED** | **HTTP 500 Internal Server Error**       |

---

## 🐛 Bugs Discovered

### 🔴 P0 - Critical / Blocking (2 bugs)

| Bug ID | Title | File |
| :----- | :---- | :--- |
| BUG-ORDER-001 | Sai lệch giá nghiêm trọng (Product: 110k → Cart: 253k for 2 items) | [BUG-ORDER-001](./BUG-ORDER-001-price-mismatch.md) |
| BUG-ORDER-002 | Place Order thất bại - HTTP 500 Internal Server Error | [BUG-ORDER-002](./BUG-ORDER-002-place-order-500-error.md) |

### 🟡 P1 - High (1 bug)

| Bug ID | Title | File |
| :----- | :---- | :--- |
| BUG-ORDER-003 | Hình ảnh sản phẩm bị broken trên toàn bộ flow | [BUG-ORDER-003](./BUG-ORDER-003-broken-product-images.md) |

### 🔵 P2 - Medium (2 bugs)

| Bug ID | Title | File |
| :----- | :---- | :--- |
| BUG-ORDER-004 | Thiếu toast/feedback khi thêm vào giỏ hàng | [BUG-ORDER-004](./BUG-ORDER-004-missing-add-to-cart-feedback.md) |
| BUG-ORDER-005 | Checkout page UI/UX inconsistencies (shipping fee, redundant button) | [BUG-ORDER-005](./BUG-ORDER-005-checkout-ui-inconsistencies.md) |

---

## 📸 Evidence Screenshots

Tất cả screenshots nằm trong cùng thư mục này:

| File | Description |
| :--- | :---------- |
| `evidence_product_page.png` | Product detail page - giá 110.000đ, broken image |
| `evidence_cart_sidebar.png` | Shopping Cart sidebar - giá sai 253.000đ |
| `evidence_checkout_page.png` | Checkout page - Payment step |
| `evidence_payment_method.png` | COD selected, "Proceed to Checkout" button thừa |
| `evidence_order_review.png` | Order Review - giá sai 253.000đ |
| `evidence_place_order_failed.png` | "Failed to place order" error toast |

---

## 🎯 Recommended Priority Actions

1. **[URGENT]** Fix **Checkout Service** 500 error → Debug server logs, check database connection
2. **[URGENT]** Fix **Pricing logic** → Đảm bảo Cart dùng sale_price chứ không phải list_price
3. **[HIGH]** Fix **Product images** → Check Next.js image config & placeholder files
4. **[MEDIUM]** Add **toast notification** cho Add-to-Cart action
5. **[MEDIUM]** Fix **UI inconsistencies** trên Checkout page

---

## 🔗 Related Services to Investigate

- `checkout-service` - 500 error on confirm API
- `cart-service` / `pricing-service` - Price calculation logic
- `catalog-service` - Product image URLs
- `frontend` - Next.js image optimization, UX feedback

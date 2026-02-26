# 🚨 BUG-ORDER-001: Sai lệch giá nghiêm trọng giữa Product Page và Cart/Checkout

| Field              | Value                                                                 |
| :----------------- | :-------------------------------------------------------------------- |
| **Bug ID**         | BUG-ORDER-001                                                         |
| **Severity**       | 🔴 **P0 - Critical / Blocking**                                      |
| **Priority**       | Highest                                                               |
| **Module**         | Cart Service / Pricing Service / Checkout Service                     |
| **Environment**    | Production (`frontend.tanhdev.com`)                                   |
| **Reporter**       | QC Automation                                                         |
| **Date**           | 2026-02-26                                                            |
| **Status**         | 🟢 OPEN                                                              |
| **Affects**        | All customers placing orders                                          |

---

## 📝 Summary

Giá sản phẩm hiển thị trên **Product Detail Page** không khớp với giá tính toán trong **Shopping Cart** và **Checkout**. Hệ thống tính sai subtotal, dẫn đến khách hàng bị charge số tiền khác so với giá niêm yết.

---

## 🔄 Steps to Reproduce

1. Đăng nhập với tài khoản: `customer1000@example.com` / `Customer1000@example.com`
2. Truy cập sản phẩm: `https://frontend.tanhdev.com/products/92094879-412c-4728-865e-cd462e1df99e`
3. Quan sát giá hiển thị trên Product Page: **110.000 đ** (giá gốc 120.000 đ, gạch ngang)
4. Tăng số lượng lên **2**
5. Click **"Thêm vào giỏ hàng"**
6. Mở Shopping Cart sidebar

---

## ✅ Expected Result

| Item                | Expected Value |
| :------------------ | :------------- |
| Đơn giá (Unit)      | 110.000 đ      |
| Số lượng            | 2              |
| Subtotal            | **220.000 đ**  |

---

## ❌ Actual Result

| Item                | Actual Value   | Sai lệch vs Expected |
| :------------------ | :------------- | :-------------------- |
| Đơn giá (Unit)      | ~126.500 đ (?)  | +16.500 đ             |
| Số lượng            | 2              | ✅ Đúng              |
| Subtotal (Cart)     | **253.000 đ**  | **+33.000 đ** ❌      |
| Tax                 | 46.950 đ       | Không rõ cơ sở tính   |
| Total (Summary)     | **349.950 đ**  | Chênh lệch lớn       |

> **Lưu ý**: Đơn giá trong cart tính ngược lại = 253.000 / 2 = 126.500 đ, khác hoàn toàn với 110.000 đ trên Product Page.

---

## 🔍 Root Cause Analysis (Suspected)

1. **Pricing Service** có thể trả về giá khác (base price thay vì sale price) khi thêm vào cart
2. **Cart Service** có thể không apply promotion/discount price đúng cách
3. **Checkout Service** sử dụng giá từ cart, nên lỗi cascade qua toàn bộ flow
4. Có khả năng Cart đang dùng `list_price` (120.000 đ) thay vì `sale_price` (110.000 đ), cộng thêm một khoản phí ẩn

---

## 📊 Additional Data: Shipping Fee Inconsistency

Phát hiện thêm: **Shipping fee không nhất quán** giữa các component trên cùng một trang Checkout:

| Location                    | Shipping Fee |
| :-------------------------- | :----------- |
| Shipping Method card (left) | **60.000 đ** |
| Order Summary (right)       | **50.000 đ** |
| COD detail card             | **60.000 đ** |

Dẫn đến Total cũng không nhất quán:
- Order Summary Total: **349.950 đ** (dùng shipping 50k)
- COD card Total: **359.950 đ** (dùng shipping 60k)

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_product_page.png` | Product page hiển thị giá 110.000 đ |
| `evidence_cart_sidebar.png` | Cart sidebar hiển thị subtotal 253.000 đ, total 290.950 đ |
| `evidence_checkout_page.png` | Checkout page với Order Summary |
| `evidence_order_review.png` | Order Review hiển thị 253.000 đ cho 2 items |

---

## 🏷️ Tags

`pricing` `cart` `checkout` `critical` `data-inconsistency` `regression`

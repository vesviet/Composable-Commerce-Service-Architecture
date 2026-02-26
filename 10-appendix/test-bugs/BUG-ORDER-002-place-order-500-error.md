# 🚨 BUG-ORDER-002: Place Order thất bại với HTTP 500 Internal Server Error

| Field              | Value                                                                 |
| :----------------- | :-------------------------------------------------------------------- |
| **Bug ID**         | BUG-ORDER-002                                                         |
| **Severity**       | 🔴 **P0 - Critical / Blocking**                                      |
| **Priority**       | Highest                                                               |
| **Module**         | Checkout Service (Backend API)                                        |
| **Environment**    | Production (`api.tanhdev.com`)                                        |
| **Reporter**       | QC Automation                                                         |
| **Date**           | 2026-02-26                                                            |
| **Status**         | 🟢 OPEN                                                              |
| **Affects**        | All customers - cannot place any order                                |

---

## 📝 Summary

Khi nhấn **"Place Order"** tại bước cuối cùng của Checkout flow, hệ thống trả về lỗi **HTTP 500 Internal Server Error**. Khách hàng **KHÔNG THỂ** hoàn tất đơn hàng. Đây là lỗi blocking toàn bộ luồng mua hàng.

---

## 🔄 Steps to Reproduce

1. Đăng nhập: `customer1000@example.com` / `Customer1000@example.com`
2. Truy cập sản phẩm: `https://frontend.tanhdev.com/products/92094879-412c-4728-865e-cd462e1df99e`
3. Thêm sản phẩm vào giỏ (quantity: 2)
4. Vào Checkout
5. **Step 1 - Shipping**: Nhập địa chỉ giao hàng:
   - Name: Test Customer 1000
   - Address: 123 Test Street
   - City: Ho Chi Minh City
   - Postal Code: 70000
   - Country: Vietnam
   - Phone: 0912345678
6. **Step 2 - Payment**: Chọn "Thanh toán khi nhận hàng" (COD)
7. **Step 3 - Review**: Xem lại đơn hàng → Click **"Place Order"**

---

## ✅ Expected Result

- Đơn hàng được tạo thành công
- Chuyển hướng đến trang **Order Confirmation** với Order ID
- Hiển thị thông tin đơn hàng (sản phẩm, giá, trạng thái, tracking)

---

## ❌ Actual Result

- UI hiển thị toast lỗi: **"Failed to place order. Please try again."**
- Không tạo được đơn hàng
- Vẫn ở lại trang Checkout (không redirect)

---

## 🔍 Console Error Log

```
Checkout confirmation error: AxiosError: Request failed with status code 500
POST https://api.tanhdev.com/api/v1/checkout/session_1772108911935_mfsmrxdjk/confirm 500 (Internal Server Error)
```

---

## 🔍 Root Cause Analysis (Suspected)

1. **Checkout Service** backend gặp lỗi khi xử lý `confirm` API
2. Có thể liên quan đến:
   - Lỗi validate dữ liệu shipping address format
   - Lỗi kết nối đến Order Service hoặc Payment Service 
   - Lỗi tạo order trong database (constraint violation, missing data)
   - Session checkout đã expired
   - Lỗi liên quan đến pricing inconsistency (BUG-ORDER-001)
3. Cần kiểm tra server logs tại Checkout Service pod

---

## 🛠️ Recommended Debug Steps

```bash
# 1. Check checkout service logs
kubectl logs -l app=checkout-service -n dev --tail=100 | grep -i "error\|500\|session_"

# 2. Check order service logs (nếu request đã forward)
kubectl logs -l app=order-service -n dev --tail=100 | grep -i "error"

# 3. Check checkout service health
kubectl get pods -l app=checkout-service -n dev

# 4. Test API directly
curl -X POST https://api.tanhdev.com/api/v1/checkout/session_test/confirm \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json"
```

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_place_order_failed.png` | Toast error "Failed to place order. Please try again." |
| `evidence_order_review.png` | Order Review page trước khi nhấn Place Order |
| `evidence_payment_method.png` | Payment Method page với COD đã chọn |

---

## 🏷️ Tags

`checkout` `order` `500-error` `critical` `blocking` `backend`

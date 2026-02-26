# 🔵 BUG-ORDER-005: Checkout Page - Nhiều vấn đề UI/UX inconsistency

| Field              | Value                                                                 |
| :----------------- | :-------------------------------------------------------------------- |
| **Bug ID**         | BUG-ORDER-005                                                         |
| **Severity**       | 🔵 **P2 - Medium**                                                   |
| **Priority**       | Medium                                                                |
| **Module**         | Frontend - Checkout Page                                              |
| **Environment**    | Production (`frontend.tanhdev.com`)                                   |
| **Reporter**       | QC Automation                                                         |
| **Date**           | 2026-02-26                                                            |
| **Status**         | 🟢 OPEN                                                              |

---

## 📝 Summary

Trang Checkout có nhiều vấn đề UI/UX không nhất quán, ảnh hưởng đến trải nghiệm khách hàng.

---

## 📋 Issue List

### Issue 5.1: Shipping Fee không nhất quán

| Location                          | Shipping Fee Displayed |
| :-------------------------------- | :--------------------- |
| Shipping Method card (phần chọn)  | **60.000 đ**           |
| Order Summary sidebar (bên phải) | **50.000 đ**           |

→ Khách hàng không biết phí ship thực tế là bao nhiêu.

---

### Issue 5.2: Nút "Proceed to Checkout" thừa trên trang Checkout

Tại trang `/checkout`, sidebar bên phải hiển thị nút **"Proceed to Checkout"**. Đây là nút dư thừa vì user **đã đang ở trang checkout**. Nút này gây nhầm lẫn.

**Expected**: Nút này nên được ẩn hoặc đổi thành "Place Order" khi user đã ở trang checkout.

---

### Issue 5.3: Console SecurityError warnings

Checkout page phát sinh nhiều `SecurityError` warning liên quan đến cross-origin iframe access, có thể từ Stripe component chưa được cấu hình hoặc third-party analytics. Không ảnh hưởng trực tiếp đến chức năng nhưng gây "noisy" console logs.

---

### Issue 5.4: Login page residual error message

Trang Login hiển thị lỗi "An unexpected error occurred. Please try again." từ session trước đó (khi nhập sai email/password). Error message không tự clear khi user navigate lại trang login.

**Expected**: Error message nên clear khi user load lại trang hoặc bắt đầu typing.

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_checkout_page.png` | Checkout page - shipping 60k vs summary 50k |
| `evidence_payment_method.png` | "Proceed to Checkout" button trên trang checkout |

---

## 🏷️ Tags

`ux` `frontend` `checkout` `inconsistency` `medium-priority`

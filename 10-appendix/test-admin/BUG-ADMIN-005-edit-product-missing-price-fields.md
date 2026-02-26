# 🔵 BUG-ADMIN-005: Edit Product - Tab "General Information" thiếu trường nhập giá

| Field              | Value                                                |
| :----------------- | :--------------------------------------------------- |
| **Bug ID**         | BUG-ADMIN-005                                        |
| **Severity**       | 🔵 **P2 - Medium**                                  |
| **Priority**       | Medium                                               |
| **Module**         | Admin Frontend - Product Edit Page                   |
| **Environment**    | Production (`admin.tanhdev.com`)                     |
| **Reporter**       | QC Automation                                        |
| **Date**           | 2026-02-26                                           |
| **Status**         | 🟢 OPEN                                             |

---

## 📝 Summary

Trang **Edit Product** (Catalog → Products → Edit) chỉ hiển thị các trường:
- SKU, Status, Product Name, Short Description, Long Description, Category, Brand, Manufacturer

**Thiếu hoàn toàn** các trường quản lý giá:
- Base Price / List Price
- Sale Price
- Compare/Original Price
- Currency

Admin hiện phải vào module **Pricing** riêng để quản lý giá, khiến workflow phức tạp.

---

## 🔄 Steps to Reproduce

1. Admin → Catalog → Products
2. Click "Edit" cho bất kỳ sản phẩm nào
3. Kiểm tra tab "General Information"

---

## ✅ Expected Result (theo UX best practices)

Tab "General Information" hoặc tab riêng "Pricing" trong product edit nên hiển thị:
- Base Price
- Sale Price (nếu có promotion)
- Tax Class 
- Quick link đến Pricing module

---

## ❌ Actual Result

- Không có bất kỳ trường giá nào
- Tabs available: General Information, Attributes & Specifications, Images & Media, SEO
- Admin phải navigate riêng đến Pricing module → tìm sản phẩm → xem giá

---

## 💡 Note

Đây là design decision (Pricing tách biệt theo microservice architecture), nhưng từ góc độ UX admin cần ít nhất hiển thị **read-only price** trên product edit page để admin không phải switch context.

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_product_edit.png` | Edit Product - chỉ có SKU, Name, Description, Category |
| `evidence_product_edit_general.png` | Product general form - thiếu trường giá |

---

## 🏷️ Tags

`admin` `ux` `catalog` `pricing` `medium-priority`

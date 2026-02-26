# 🟡 BUG-ADMIN-003: Product List hiển thị giá "Not set" và Stock "0" cho tất cả sản phẩm

| Field              | Value                                                |
| :----------------- | :--------------------------------------------------- |
| **Bug ID**         | BUG-ADMIN-003                                        |
| **Severity**       | 🟡 **P1 - High**                                    |
| **Priority**       | High                                                 |
| **Module**         | Admin Frontend / Catalog Service / Pricing Service   |
| **Environment**    | Production (`admin.tanhdev.com`)                     |
| **Reporter**       | QC Automation                                        |
| **Date**           | 2026-02-26                                           |
| **Status**         | 🟢 OPEN                                             |

---

## 📝 Summary

Trang **Products Management** trong Admin hiển thị:
1. **Price**: "Not set" cho TẤT CẢ sản phẩm (dù Frontend vẫn hiển thị giá 110.000đ)
2. **Stock**: "0" (đỏ) cho tất cả sản phẩm (dù Inventory module hiển thị 9.958 cho BLK-010000)

Điều này khiến Admin không thể kiểm tra giá và stock ngay từ danh sách sản phẩm.

---

## 🔄 Steps to Reproduce

1. Đăng nhập Admin → Catalog → Products
2. Quan sát cột "Price" và "Stock"

---

## ❌ Actual Result

| Column | Displayed | Actual Data (from other modules) |
| :----- | :-------- | :------------------------------- |
| Price  | "Not set" | 110.000 đ (Pricing module)       |
| Stock  | 0 (đỏ)   | 9.958 (Inventory module)         |

---

## ✅ Expected Result

- **Price**: Hiển thị giá bán (sale price) từ Pricing Service
- **Stock**: Hiển thị available stock từ Inventory Service

---

## 🔍 Root Cause (Suspected)

1. **Price**: Admin frontend có thể đang query giá từ Catalog Service (field price trong product entity) thay vì Pricing Service. Catalog Service không lưu giá → hiển thị "Not set"
2. **Stock**: Admin frontend có thể đang query stock từ Catalog Service (field stock) thay vì Warehouse/Inventory Service
3. Cần kiểm tra frontend API calls để xác nhận data source

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_products_list.png` | Products Management - "Not set" price, "0" stock |
| `evidence_inventory_stock.png` | Inventory Module - 9.958 available stock |

---

## 🏷️ Tags

`admin` `catalog` `pricing` `inventory` `data-inconsistency` `high-priority`

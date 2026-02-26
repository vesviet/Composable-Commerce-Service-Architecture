# 🟡 BUG-ADMIN-004: Hình ảnh sản phẩm bị broken trên Admin Panel

| Field              | Value                                                |
| :----------------- | :--------------------------------------------------- |
| **Bug ID**         | BUG-ADMIN-004                                        |
| **Severity**       | 🟡 **P1 - High**                                    |
| **Priority**       | High                                                 |
| **Module**         | Admin Frontend / Image Storage                       |
| **Environment**    | Production (`admin.tanhdev.com`)                     |
| **Reporter**       | QC Automation                                        |
| **Date**           | 2026-02-26                                           |
| **Status**         | 🟢 OPEN                                             |
| **Related**        | BUG-ORDER-003 (Frontend broken images)               |

---

## 📝 Summary

Tất cả hình ảnh sản phẩm trong Admin panel **không hiển thị được**. Console log cho thấy:
1. **404 errors** cho thumbnail files (ví dụ: `BLK-010000-thumb.jpg`)
2. **ERR_NAME_NOT_RESOLVED** cho `via.placeholder.com` (placeholder service)

Lỗi này xảy ra đồng thời trên cả Frontend (BUG-ORDER-003) và Admin, cho thấy đây là vấn đề hệ thống (Image Storage/CDN).

---

## 🔄 Steps to Reproduce

1. Đăng nhập Admin → Catalog → Products
2. Quan sát cột hình ảnh sản phẩm → Tất cả đều hiển thị icon lỗi

---

## ❌ Actual Result

- Products List: Tất cả thumbnails hiển thị icon broken image
- Product Edit page: Không có hình ảnh trong tab "Images & Media"
- Console: `GET /images/BLK-010000-thumb.jpg 404 (Not Found)`
- Console: `GET https://via.placeholder.com/... ERR_NAME_NOT_RESOLVED`

---

## ✅ Expected Result

- Thumbnails sản phẩm hiển thị trong danh sách Products
- Full images hiển thị trong Product Edit page

---

## 🔍 Root Cause

1. Image files chưa được upload lên storage/CDN
2. Placeholder service (`via.placeholder.com`) có thể bị block bởi DNS hoặc firewall
3. Frontend đang reference đến image paths không tồn tại

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_products_list.png` | Products list - broken image icons |

---

## 🏷️ Tags

`images` `admin` `cdn` `storage` `404` `high-priority`

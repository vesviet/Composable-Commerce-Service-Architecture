# 🟡 BUG-ORDER-003: Hình ảnh sản phẩm bị broken trên toàn bộ flow

| Field              | Value                                                                 |
| :----------------- | :-------------------------------------------------------------------- |
| **Bug ID**         | BUG-ORDER-003                                                         |
| **Severity**       | 🟡 **P1 - High**                                                     |
| **Priority**       | High                                                                  |
| **Module**         | Frontend (Next.js Image Optimization) / Catalog Service               |
| **Environment**    | Production (`frontend.tanhdev.com`)                                   |
| **Reporter**       | QC Automation                                                         |
| **Date**           | 2026-02-26                                                            |
| **Status**         | 🟢 OPEN                                                              |
| **Affects**        | All products - no product images displayed                            |

---

## 📝 Summary

Hình ảnh sản phẩm **không hiển thị được** trên tất cả các trang (Product Detail, Shopping Cart, Checkout). Thay vào đó chỉ hiển thị alt-text hoặc placeholder "No image". Console báo lỗi **HTTP 400 (Bad Request)** khi tải ảnh qua Next.js image optimization service.

---

## 🔄 Steps to Reproduce

1. Truy cập bất kỳ trang sản phẩm nào, ví dụ:
   `https://frontend.tanhdev.com/products/92094879-412c-4728-865e-cd462e1df99e`
2. Quan sát khu vực hình ảnh sản phẩm bên trái

---

## ✅ Expected Result

- Hiển thị hình ảnh sản phẩm chất lượng cao
- Image lazy loading hoạt động bình thường

---

## ❌ Actual Result

- Không hiển thị hình ảnh, chỉ hiện:
  - **Product Page**: Alt-text "Advanced Accessory 10000" trên nền xám
  - **Cart Sidebar**: Placeholder "No image" 
  - **Checkout/Review**: Không có hình ảnh

---

## 🔍 Console Error

```
GET /_next/image?url=%2Fimages%2Fplaceholder-product.png&w=640&q=75 400 (Bad Request)
```

---

## 🔍 Root Cause Analysis (Suspected)

1. **Placeholder image file** (`/images/placeholder-product.png`) không tồn tại trong project frontend
2. **Catalog Service** có thể không trả về image URL cho sản phẩm, frontend fallback về placeholder nhưng placeholder cũng bị thiếu
3. **Next.js Image Optimization** (`/_next/image`) trả về 400 vì source image không tìm thấy
4. Cần kiểm tra:
   - API response của catalog service xem có trả `image_url` không
   - File `public/images/placeholder-product.png` có tồn tại trong frontend project không
   - Next.js `next.config.js` có cấu hình đúng `images.domains` không

---

## 🛠️ Recommended Fix

```javascript
// next.config.js - Đảm bảo cấu hình images domains
module.exports = {
  images: {
    domains: ['api.tanhdev.com', 'storage.googleapis.com'], // thêm domain chứa ảnh
    unoptimized: false,
  },
}
```

Hoặc đảm bảo file placeholder tồn tại:
```bash
# Check if placeholder exists
ls -la frontend/public/images/placeholder-product.png
```

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_product_page.png` | Product page - broken image, chỉ hiện alt-text |
| `evidence_cart_sidebar.png` | Cart sidebar - "No image" placeholder |

---

## 🏷️ Tags

`frontend` `images` `next-js` `high-priority` `ux`

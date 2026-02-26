# 🧪 QC Test Report - Admin Panel

| Field            | Value                                                      |
| :--------------- | :--------------------------------------------------------- |
| **Test Date**    | 2026-02-26                                                 |
| **Tester**       | QC Automation (Senior QC)                                  |
| **Environment**  | Production (`admin.tanhdev.com`)                           |
| **Test Account** | `admin@example.com` / `Admin123!`                          |
| **Overall**      | ⚠️ **PARTIAL PASS** - Nhiều bugs data & UI               |

---

## 📊 Test Coverage

```
Login ✅ → Dashboard ⚠️ → Orders ⚠️ → Catalog/Products ❌ → 
Inventory ✅ → Pricing ✅ → Customers ✅
```

| Module           | Status    | Notes                                              |
| :--------------- | :-------- | :------------------------------------------------- |
| Login            | ⚠️ Warn  | Thành công nhưng expose demo credentials           |
| Dashboard        | ⚠️ Warn  | Mock/hardcoded data, không match thực tế           |
| Orders           | ⚠️ Warn  | Pricing errors trong order detail                  |
| Products         | ❌ Fail   | Price "Not set", Stock "0", images broken          |
| Product Edit     | ⚠️ Warn  | Thiếu trường giá, images tab empty                 |
| Inventory        | ✅ Pass   | Stock data chính xác (9.958/10.000)                |
| Pricing          | ✅ Pass   | Base 120k, Sale 110k đúng. VAT 10% + Duty 5%      |
| Customers        | ✅ Pass   | Customer list hiển thị đúng, có search             |

---

## 🐛 Bugs Discovered: 6

### 🔴 P0 - Critical (2 bugs)

| Bug ID | Title | Impact |
| :----- | :---- | :----- |
| [BUG-ADMIN-001](./BUG-ADMIN-001-login-exposes-credentials.md) | Login page exposes demo credentials | Security vulnerability |
| [BUG-ADMIN-002](./BUG-ADMIN-002-order-price-calculation-error.md) | Double tax calculation + decimal precision | Financial data incorrect |

### 🟡 P1 - High (2 bugs)

| Bug ID | Title | Impact |
| :----- | :---- | :----- |
| [BUG-ADMIN-003](./BUG-ADMIN-003-product-price-not-set.md) | Product list shows "Not set" price, "0" stock | Admin cannot manage products |
| [BUG-ADMIN-004](./BUG-ADMIN-004-broken-product-images-admin.md) | All product images broken (404) | Cannot verify product visuals |

### 🔵 P2 - Medium (2 bugs)

| Bug ID | Title | Impact |
| :----- | :---- | :----- |
| [BUG-ADMIN-005](./BUG-ADMIN-005-edit-product-missing-price-fields.md) | Product Edit missing price fields | Poor admin UX |  
| [BUG-ADMIN-006](./BUG-ADMIN-006-dashboard-data-inconsistency.md) | Dashboard mock/inconsistent data | Misleading admin metrics |

---

## 🔑 Key Finding: Root Cause of Frontend Price Bug

Qua test Admin panel, tôi đã xác định **nguyên nhân gốc** của BUG-ORDER-001 (Frontend price mismatch):

### Tax Configuration (Pricing Module):
- Vietnam VAT: **10%**
- Vietnam Import Duty: **5%**  
- Total Tax: **15%**

### Double Tax Calculation:
```
Step 1 (Item Level): 110.000 × 2 × 1.15 = 253.000 đ ← Cart subtotal
Step 2 (Order Level): 253.000 × 1.15 = 290.950 đ ← Cart total

Expected:
  Subtotal: 110.000 × 2 = 220.000 đ
  Tax: 220.000 × 0.15 = 33.000 đ
  Total: 253.000 đ
```

→ **Hệ thống đang tính thuế 2 lần**: lần 1 tại Cart Service, lần 2 tại Checkout Service.

---

## 📸 Evidence Screenshots

| File | Description |
| :--- | :---------- |
| `evidence_login_page.png` | Login page with exposed credentials |
| `evidence_dashboard.png` | Dashboard with mock data |
| `evidence_orders_list.png` | Orders list - 1 order |
| `evidence_order_detail_items.png` | Order items - pricing errors |
| `evidence_products_list.png` | Products - "Not set", "0" stock |
| `evidence_product_edit.png` | Product edit - no price fields |
| `evidence_product_edit_general.png` | Product general info |
| `evidence_inventory_stock.png` | Inventory - 9.958 stock |
| `evidence_customer_list.png` | Customer management |

---

## 🎯 Recommended Priority Actions

1. **[URGENT/SECURITY]** Ẩn demo credentials trên Login page production
2. **[URGENT]** Fix **double tax calculation** tại Cart/Checkout services
3. **[HIGH]** Cross-reference price & stock data trong Products list với Pricing/Inventory modules
4. **[HIGH]** Fix broken images (cả Admin và Frontend)
5. **[MEDIUM]** Thêm read-only price info trên Product Edit page
6. **[MEDIUM]** Replace dashboard mock data bằng real analytics data

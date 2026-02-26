# 🚨 BUG-ADMIN-002: Lỗi tính toán giá trong chi tiết đơn hàng (Tax Double-Counting)

| Field              | Value                                                |
| :----------------- | :--------------------------------------------------- |
| **Bug ID**         | BUG-ADMIN-002                                        |
| **Severity**       | 🔴 **P0 - Critical / Logic**                        |
| **Priority**       | Highest                                              |
| **Module**         | Order Service / Pricing Service / Tax Calculation    |
| **Environment**    | Production (`admin.tanhdev.com`)                     |
| **Reporter**       | QC Automation                                        |
| **Date**           | 2026-02-26                                           |
| **Status**         | 🟢 OPEN                                             |
| **Related**        | BUG-ORDER-001 (Frontend Price Mismatch)              |

---

## 📝 Summary

Chi tiết đơn hàng ORD-2602-000002 trong Admin hiển thị dữ liệu tính giá **hoàn toàn sai logic**. Hệ thống đang áp dụng thuế (VAT 10% + Import Duty 5% = 15%) **hai lần** (double taxation), dẫn đến giá hiển thị sai từ Cart đến Order.

---

## 🔍 Analysis: Double Tax Bug

### Pricing Config (from Admin Pricing module)
- **Base Price**: 120.000 đ
- **Sale Price**: 110.000 đ
- **Vietnam VAT**: 10%
- **Vietnam Import Duty**: 5%
- **Total Tax Rate**: 15%

### Lần tính thuế thứ 1 (Item Level - SAI):
```
Sale Price × Quantity × (1 + Tax Rate)
= 110.000 × 2 × 1.15 
= 253.000 đ ← Đây là subtotal hiển thị trong Cart!
```

### Lần tính thuế thứ 2 (Order Level - SAI):
```
253.000 × 1.15 = 290.950 đ ← Đây là total hiển thị trong Cart sidebar!
```

### Kỳ vọng (Expected - đúng):
```
Subtotal = 110.000 × 2 = 220.000 đ
Tax (15%) = 220.000 × 0.15 = 33.000 đ  
Total = 220.000 + 33.000 = 253.000 đ
```

---

## 📊 Order Detail Data (ORD-2602-000002)

| Field | Value | Issue |
| :---- | :---- | :---- |
| Product | Advanced Accessory 10000 | ✅ |
| SKU | BLK-010000 | ✅ |
| Quantity | 5 | ✅ |
| Unit Price | đ1,100 | ⚠️ Có thể đang hiển thị sai format (thiếu 2 số 0?) |
| Discount | đ0 | ✅ |
| Tax | đ82,500 | 🚨 Nếu unit price = 1,100 × 5 = 5,500. Tax 82,500 > subtotal! |
| Total Price | đ6,325 | 🚨 Không match bất kỳ phép tính logic nào |
| Grand Total | đ7,015 | 🚨 Sai |

> **Ghi chú**: Giá có thể đang ở đơn vị VND nhưng thiếu 2 số 0 (chia cho 100?) hoặc có lỗi decimal precision.

---

## 🔍 Root Cause (Suspected)

1. **Tax calculated twice**: Cart Service tính tax lần 1 (include vào item price), Checkout Service tính tax lần 2 (include vào order total)
2. **Decimal precision issue**: Giá đang bị chia cho 100 ở một số chỗ (1,100 thay vì 110,000)
3. **Tax calculation order**: Tax nên tính trên `sale_price × quantity`, không tính lại trên subtotal đã bao gồm tax

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_order_detail_items.png` | Order items - Unit Price đ1,100, Tax đ82,500, Total đ6,325 |
| `evidence_orders_list.png` | Orders list - Order ORD-2602-000002, Total đ7,015 |

---

## 🏷️ Tags

`pricing` `tax` `double-counting` `order` `critical` `backend` `decimal-precision`

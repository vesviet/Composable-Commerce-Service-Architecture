# 🔵 BUG-ADMIN-006: Dashboard hiển thị dữ liệu không nhất quán / Hardcoded

| Field              | Value                                                |
| :----------------- | :--------------------------------------------------- |
| **Bug ID**         | BUG-ADMIN-006                                        |
| **Severity**       | 🔵 **P2 - Medium**                                  |
| **Priority**       | Medium                                               |
| **Module**         | Admin Frontend - Dashboard / Analytics Service       |
| **Environment**    | Production (`admin.tanhdev.com`)                     |
| **Reporter**       | QC Automation                                        |
| **Date**           | 2026-02-26                                           |
| **Status**         | 🟢 OPEN                                             |

---

## 📝 Summary

Dashboard hiển thị dữ liệu có vẻ **hardcoded hoặc mock data**, không phản ánh dữ liệu thực:

| Widget | Dashboard Value | Actual Data |
| :----- | :-------------- | :---------- |
| Total Orders | 567 | Chỉ có 1 order trong Orders module |
| Total Revenue | $89,012.50 | Order duy nhất = đ7,015. Revenue hiển thị bằng USD? |
| Total Products | 345 | Products Management hiển thị 10,000 |
| Total Users | 1,234 | Chưa verify - có thể đúng |
| Revenue Trend | Chart 2024-01-01 → 2024-01-07 | Năm 2024 - dữ liệu cũ? Hiện tại 2026 |
| Top Products | Wireless Headphones (145 sales) | Không match với sản phẩm thực |
| Recent Orders | John Doe, Jane Smith | Không nhất quán với Orders module |
| Recent Tasks | "No data", 0% Success Rate | ✅ Có thể đúng |

---

## 🔍 Issues

1. **Revenue Trend chart** dùng dữ liệu từ tháng 1/2024, không phải realtime
2. **Top Products** liệt kê "Wireless Headphones", "Smart Watch", "Laptop Stand" → có thể là mock data
3. **Recent Orders** hiển thị "John Doe" nhưng Orders module chỉ có "Customer 9af7955a" → không match
4. **Revenue hiển thị bằng USD** ($89,012.50) trong khi giá sản phẩm bằng VND
5. **Analytics API**: Console báo 404 cho `/api/analytics-service/admin/dashboard/stats`

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_dashboard.png` | Dashboard với dữ liệu không nhất quán |
| `evidence_orders_list.png` | Orders module chỉ có 1 order |

---

## 🏷️ Tags

`dashboard` `analytics` `mock-data` `admin` `medium-priority`

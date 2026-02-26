# 🚨 BUG-ADMIN-001: Trang Login Admin hiển thị công khai Demo Credentials

| Field              | Value                                                |
| :----------------- | :--------------------------------------------------- |
| **Bug ID**         | BUG-ADMIN-001                                        |
| **Severity**       | 🔴 **P0 - Critical / Security**                     |
| **Priority**       | Highest                                              |
| **Module**         | Admin Frontend - Login Page                          |
| **Environment**    | Production (`admin.tanhdev.com`)                     |
| **Reporter**       | QC Automation                                        |
| **Date**           | 2026-02-26                                           |
| **Status**         | 🟢 OPEN                                             |

---

## 📝 Summary

Trang Login Admin (`admin.tanhdev.com`) hiển thị **công khai thông tin đăng nhập demo** ngay trên giao diện:
- Email: `admin@example.com`
- Password: `admin123`

Đây là lỗ hổng bảo mật nghiêm trọng trên production, cho phép bất kỳ ai truy cập vào admin panel.

---

## 🔄 Steps to Reproduce

1. Truy cập `https://admin.tanhdev.com/`
2. Quan sát phần dưới nút "Sign In"

---

## ❌ Actual Result

Trang login hiển thị box:
```
Demo Credentials:
Email: admin@example.com
Password: admin123
```

---

## ✅ Expected Result

- **KHÔNG BAO GIỜ** hiển thị credentials trên production
- Demo credentials chỉ nên tồn tại trên môi trường development/staging
- Sử dụng environment variables để kiểm soát hiển thị

---

## 🛠️ Recommended Fix

```javascript
// Chỉ hiển thị demo credentials trên dev environment
{process.env.NODE_ENV === 'development' && (
  <div className="demo-credentials">
    <p>Demo Credentials:</p>
    <p>Email: admin@example.com</p>
    <p>Password: admin123</p>
  </div>
)}
```

---

## 📸 Evidence

| Screenshot | Description |
| :--------- | :---------- |
| `evidence_login_page.png` | Login page hiển thị demo credentials |

---

## 🏷️ Tags

`security` `admin` `critical` `credentials-exposure` `production`

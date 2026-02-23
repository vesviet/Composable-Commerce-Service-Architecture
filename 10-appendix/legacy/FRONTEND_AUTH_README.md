# Hướng Dẫn Tích Hợp Authentication cho Frontend

Tài liệu này hướng dẫn cách Frontend tích hợp với hệ thống Authentication mới của Backend Microservices.

**Lưu ý quan trọng:**
- **URL Base**: `/api/v1` (thông qua Gateway)
- **Cơ chế**: JWT (Access Token + Refresh Token)
- **Token Storage**: HttpOnly Cookies (Khuyến nghị) hoặc LocalStorage (Chấp nhận được nếu xử lý XSS tốt)

---

## 1. Luồng Đăng Nhập (Login)

Gửi request đăng nhập với email và password.

**Endpoint:**
`POST /api/v1/customers/login`

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "your_password",
  "device_info": "iPhone 12, iOS 15",
  "ip_address": "192.168.1.1" // Optional (server gets from remote addr)
}
```

**Response (Success - 200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1Ni...",
  "refresh_token": "eyJhbGciOiJIUzI1Ni...",
  "expires_at": 1700000000,
  "customer": {
    "id": "uuid-...",
    "email": "user@example.com",
    "first_name": "Nguyen",
    "last_name": "Van A",
    "status": 2
  }
}
```

**Xử lý ở Client:**
1. Lưu `access_token` vào memory (biến global/state management) hoặc LocalStorage.
2. Lưu `refresh_token` vào LocalStorage hoặc Secure Cookie.
3. Sử dụng `access_token` cho các request tiếp theo.

---

## 2. Gửi Request Có Xác Thực

Thêm header `Authorization` vào mọi API call yêu cầu đăng nhập.

**Header:**
```http
Authorization: Bearer <access_token>
```

**Ví dụ Axios Interceptor:**
```javascript
axios.interceptors.request.use(config => {
  const token = localStorage.getItem('access_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
```

---

## 3. Luồng Làm Mới Token (Refresh Token)

Access Token có thời hạn ngắn (ví dụ: 15-30 phút). Khi hết hạn, API sẽ trả về lỗi `401 Unauthorized`. Frontend cần tự động làm mới token.

**Endpoint:**
`POST /api/v1/auth/refresh` (Direct to Auth Service)

**Request Body:**
```json
{
  "refresh_token": "your_current_refresh_token"
}
```

**Response (Success - 200 OK):**
```json
{
  "access_token": "new_access_token...",
  "refresh_token": "new_refresh_token...", // Refresh token CÓ THỂ thay đổi (Rotation)
  "expires_in": 3600 // Seconds
}
```

**Cơ Chế Auto-Refresh (Axios Interceptor):**
1. Nhận lỗi `401`.
2. Hàng đợi request bị fail lại.
3. Gọi API `/api/v1/auth/refresh`. (Gateway sẽ map sang `/api/v1/auth/tokens/refresh`)
4. Nếu thành công:
   - Cập nhật token mới.
   - Retry lại các request trong hàng đợi với token mới.
5. Nếu thất bại (Refresh token hết hạn hoặc bị thu hồi):
   - Redirect về trang Login.
   - Xóa token khỏi storage.

**Lưu ý Bảo Mật:**
- Auth Service áp dụng **Rotation Strictness**: Nếu refresh token bị lộ và sử dụng lại, server sẽ thu hồi toàn bộ chuỗi token (đăng xuất bắt buộc). Hãy đảm bảo code frontend cập nhật `refresh_token` mới nhất sau mỗi lần refresh.

---

## 4. Đăng Xuất (Logout)

Gọi API logout để hủy session trên server.

**Endpoint:**
`POST /api/v1/auth/tokens/revoke` (Gateway -> Auth Service)

**Request Body:**
```json
{
  "token": "current_refresh_token",
  "reason": "user_logout"
}
```
*Lưu ý: Nên gửi kèm Access Token trong header để server log audit.*

**Action Client:**
- Gọi API.
- Xóa token khỏi Storage.
- Redirect về Home/Login.

---

## 5. Các Mã Lỗi Thường Gặp

| Code | Message | Ý nghĩa | Hành động Frontend |
|------|---------|---------|--------------------|
| 401 | Invalid token / Token expired | Token không hợp lệ hoặc hết hạn | Thử Refresh Token. Nếu fail -> Logout. |
| 403 | Access denied / Permission denied | Không có quyền truy cập resource | Hiển thị thông báo "Bạn không có quyền". |
| 429 | Too many requests | Gửi quá nhiều request (Rate Limit) | Chờ và thử lại (Exponential Backoff). |
| 423 | Account locked | Tài khoản bị khóa (sai pass quá nhiều) | Thông báo user liên hệ CSKH hoặc chờ. |

---

## 🏗️ Kiểm tra tích hợp

Để đảm bảo tích hợp đúng:
1. **Login**: Nhận được token và thông tin user.
2. **API Call**: Gọi API `/api/v1/customers/profile` (ví dụ) thành công với Bearer Token.
3. **Logout**: Sau khi logout, dùng token cũ gọi API phải bị lỗi 401.
4. **Refresh**: Đợi token hết hạn (hoặc giả lập), gọi API refresh phải nhận được token mới và dùng được ngay.

**Hỗ trợ:**
- Nếu gặp lỗi CORS, kiểm tra `Origin` header.
- Nếu gặp lỗi 500, liên hệ Backend Team kèm `Trace ID`.

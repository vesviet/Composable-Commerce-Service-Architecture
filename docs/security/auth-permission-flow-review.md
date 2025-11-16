# Auth & Permission Flow Review - Current State

## 📋 Tổng Quan

Document này tổng hợp luồng xử lý **Authentication** và **Permission** hiện tại trong hệ thống microservices, không bao gồm code implementation.

## 🔐 1. Authentication Flow

### 1.1. Admin User Login Flow

```
┌─────────┐      ┌─────────┐      ┌──────────┐      ┌──────┐
│ Admin   │      │Gateway  │      │Auth      │      │User  │
│Dashboard│      │         │      │Service   │      │Svc   │
└────┬────┘      └────┬────┘      └────┬─────┘      └───┬──┘
     │                │                 │                │
     │ POST /api/auth-│                 │                │
     │ service/admin/ │                 │                │
     │ login          │                 │                │
     │ {email, pwd}   │                 │                │
     ├───────────────>│                 │                │
     │                │ Forward         │                │
     │                ├────────────────>│                │
     │                │                 │ Validate       │
     │                │                 │ Credentials   │
     │                │                 ├───────────────>│
     │                │                 │                │
     │                │                 │ User Info +    │
     │                │                 │ Roles + Perms │
     │                │                 │<───────────────┤
     │                │                 │                │
     │                │                 │ Get Permissions│
     │                │                 │ from User Svc  │
     │                │                 │ (if needed)    │
     │                │                 │                │
     │                │                 │ Generate JWT   │
     │                │                 │ with:         │
     │                │                 │ - user_id      │
     │                │                 │ - roles        │
     │                │                 │ - permissions  │
     │                │                 │ - client_type   │
     │                │                 │                │
     │                │ Response        │                │
     │                │<────────────────┤                │
     │ JWT Tokens     │                 │                │
     │<───────────────┤                 │                │
     │                │                 │                │
```

**Các bước chi tiết:**

1. **Admin Dashboard** gửi login request đến Gateway: `POST /api/auth-service/admin/login`
2. **Gateway** forward request đến **Auth Service**
3. **Auth Service**:
   - Gọi **User Service** (gRPC) để validate credentials: `ValidateUserCredentials(email, password)`
   - User Service trả về user info nếu credentials hợp lệ
   - Auth Service kiểm tra user có active không
   - Auth Service lấy **roles** và **permissions** từ User Service (nếu cần)
4. **Auth Service** generate JWT tokens:
   - **Access Token**: Chứa `user_id`, `roles`, `permissions`, `client_type="admin"`, `session_id`
   - **Refresh Token**: Chứa `user_id`, `client_type`, `session_id`
5. **Auth Service** trả về tokens cho Gateway
6. **Gateway** trả về tokens cho Admin Dashboard
7. **Admin Dashboard** lưu tokens vào cookies và sử dụng cho các request tiếp theo

### 1.2. Customer Login Flow

```
┌─────────┐      ┌─────────┐      ┌──────────┐      ┌──────┐
│Frontend │      │Gateway  │      │Customer  │      │Auth  │
│         │      │         │      │Service   │      │Svc   │
└────┬────┘      └────┬────┘      └────┬─────┘      └───┬──┘
     │                │                 │                │
     │ POST /api/     │                 │                │
     │ customer/      │                 │                │
     │ login          │                 │                │
     │ {email, pwd}   │                 │                │
     ├───────────────>│                 │                │
     │                │ Forward         │                │
     │                ├────────────────>│                │
     │                │                 │ Validate      │
     │                │                 │ Customer      │
     │                │                 │ (local DB)    │
     │                │                 │                │
     │                │                 │ Generate JWT  │
     │                │                 ├───────────────>│
     │                │                 │                │
     │                │                 │ JWT Tokens    │
     │                │                 │<───────────────┤
     │                │                 │                │
     │                │ Response        │                │
     │                │<────────────────┤                │
     │ JWT Tokens     │                 │                │
     │<───────────────┤                 │                │
```

**Các bước chi tiết:**

1. **Frontend** gửi login request: `POST /api/customer/login`
2. **Gateway** forward đến **Customer Service**
3. **Customer Service**:
   - Validate credentials từ local database
   - Kiểm tra customer status (active/inactive)
   - Gọi **Auth Service** để generate JWT tokens
4. **Auth Service** generate tokens với `client_type="customer"`
5. Tokens được trả về cho Frontend

### 1.3. JWT Token Structure

**Access Token Claims:**
```json
{
  "user_id": "uuid",
  "session_id": "session_uuid",
  "client_type": "admin" | "customer" | "shipper",
  "user_type": "admin" | "customer" | "shipper",  // ⚠️ Backward compatibility
  "roles": ["admin", "system_admin"],
  "permissions": ["user:read", "user:write", "order:read"],
  "permissions_version": 1234567890,
  "type": "access",
  "exp": 1234567890,
  "iat": 1234567890
}
```

**Refresh Token Claims:**
```json
{
  "user_id": "uuid",
  "session_id": "session_uuid",
  "client_type": "admin" | "customer",
  "user_type": "admin" | "customer",  // ⚠️ Backward compatibility
  "type": "refresh",
  "exp": 1234567890,
  "iat": 1234567890
}
```

## 🔑 2. Permission Flow

### 2.1. Permission Storage

**User Permissions** được lưu trữ ở 2 nơi:

1. **User Service Database** (PostgreSQL):
   - Bảng `user_roles`: User → Role mapping
   - Bảng `role_permissions`: Role → Permission mapping
   - Bảng `user_permissions`: Direct user → Permission mapping (nếu có)
   - Bảng `service_access`: User → Service access permissions

2. **JWT Token** (temporary):
   - Permissions được embed trong JWT token khi login
   - Token có `permissions_version` để track version
   - Khi permissions thay đổi, user cần login lại để nhận token mới

### 2.2. Permission Retrieval Flow

```
┌─────────┐      ┌──────────┐      ┌──────┐
│Auth     │      │User      │      │DB    │
│Service  │      │Service   │      │      │
└────┬────┘      └────┬─────┘      └───┬──┘
     │                 │                │
     │ Get User        │                │
     │ Permissions     │                │
     ├────────────────>│                │
     │                 │ Query DB       │
     │                 ├───────────────>│
     │                 │                │
     │                 │ User Roles     │
     │                 │ Role Perms     │
     │                 │ Direct Perms   │
     │                 │<───────────────┤
     │                 │                │
     │ Aggregated      │                │
     │ Permissions     │                │
     │<────────────────┤                │
     │                 │                │
```

**Các bước:**

1. **Auth Service** gọi User Service để lấy permissions khi login
2. **User Service** query database:
   - Lấy roles của user từ `user_roles`
   - Lấy permissions của từng role từ `role_permissions`
   - Lấy direct permissions từ `user_permissions` (nếu có)
   - Aggregate tất cả permissions lại
3. **User Service** trả về aggregated permissions
4. **Auth Service** embed permissions vào JWT token

### 2.3. Permission Validation Flow

**Khi user gọi API qua Gateway:**

```
┌─────────┐      ┌─────────┐      ┌──────────┐
│Client   │      │Gateway  │      │Service   │
│         │      │         │      │          │
└────┬────┘      └────┬────┘      └────┬─────┘
     │                │                 │
     │ Request + JWT  │                 │
     ├───────────────>│                 │
     │                │ Validate JWT     │
     │                │ Extract:        │
     │                │ - user_id       │
     │                │ - roles         │
     │                │ - permissions   │
     │                │ - client_type   │
     │                │                 │
     │                │ Forward Request │
     │                │ + Headers:      │
     │                │ - X-User-ID     │
     │                │ - X-User-Roles  │
     │                │ - X-User-       │
     │                │   Permissions   │
     │                ├────────────────>│
     │                │                 │
     │                │ Service checks  │
     │                │ permissions    │
     │                │ (if needed)     │
     │                │                 │
     │                │ Response        │
     │                │<────────────────┤
     │ Response       │                 │
     │<───────────────┤                 │
```

**Các bước:**

1. **Client** gửi request với JWT token trong header `Authorization: Bearer <token>`
2. **Gateway**:
   - Validate JWT token (parse và verify signature)
   - Extract claims: `user_id`, `roles`, `permissions`, `client_type`
   - Forward request đến target service với headers:
     - `X-User-ID`: User ID
     - `X-User-Roles`: Comma-separated roles
     - `X-User-Permissions`: Comma-separated permissions
     - `X-Client-Type`: `admin` | `customer`
3. **Target Service**:
   - Nhận request với user context từ headers
   - Có thể validate permissions nếu endpoint yêu cầu
   - Process request và trả về response

### 2.4. Permission Types

**User Permissions** (cho admin users):
- Format: `{resource}:{action}`
- Examples:
  - `user:read` - Đọc thông tin user
  - `user:write` - Tạo/sửa user
  - `user:delete` - Xóa user
  - `order:read` - Đọc orders
  - `order:update` - Cập nhật orders
  - `*` - Tất cả permissions (super admin)

**Service Permissions** (cho service-to-service):
- Stored in **Consul KV**: `service-permissions/{from-service}/{to-service}`
- Format:
  ```json
  {
    "permissions": ["user:read", "user:validate"],
    "endpoints": [
      {"path": "/v1/user/profile", "methods": ["GET"]}
    ],
    "denied_endpoints": [
      {"path": "/v1/user/profile", "methods": ["PUT", "DELETE"]}
    ],
    "rate_limit": 1000,
    "timeout": "30s"
  }
  ```

## 🔒 3. Service-to-Service Authentication

### 3.1. Service Token Flow

```
┌─────────┐      ┌─────────┐      ┌──────┐
│Service A│      │Consul   │      │Svc B │
│         │      │         │      │      │
└────┬────┘      └────┬────┘      └───┬──┘
     │                │                │
     │ Discover       │                │
     │ Service B      │                │
     ├───────────────>│                │
     │                │                │
     │ Service Info   │                │
     │<───────────────┤                │
     │                │                │
     │ Load           │                │
     │ Permissions    │                │
     │ from KV        │                │
     ├───────────────>│                │
     │                │                │
     │ Permissions    │                │
     │<───────────────┤                │
     │                │                │
     │ Generate       │                │
     │ Service Token  │                │
     │                │                │
     │ Call Service B │                │
     │ + Service Token│                │
     ├─────────────────────────────────>│
     │                │                │
     │                │ Validate Token │
     │                │ Check Perms    │
     │                │                │
     │ Response       │                │
     │<─────────────────────────────────┤
```

**Các bước:**

1. **Service A** cần gọi **Service B**:
   - Discover Service B qua Consul
   - Load permissions từ Consul KV: `service-permissions/service-a/service-b`
2. **Service A** generate **Service Token**:
   - Chứa: `from_service`, `to_service`, `permissions`, `allowed_paths`, `denied_paths`
   - Signed với service secret
3. **Service A** gọi Service B với:
   - Header: `X-Service-Token: <token>`
   - Header: `X-Calling-Service: service-a`
4. **Service B**:
   - Validate service token
   - Check permissions cho endpoint được gọi
   - Process request nếu có quyền

### 3.2. Service Permission Matrix

**Lưu trữ trong Consul KV:**
- Key: `service-permissions/{from-service}/{to-service}`
- Value: JSON với permissions, endpoints, rate limits

**Ví dụ:**
- `service-permissions/auth-service/user-service`: Auth Service có thể gọi User Service
- `service-permissions/order-service/payment-service`: Order Service có thể gọi Payment Service

## 📊 4. Current State Summary

### 4.1. Authentication

✅ **Đã implement:**
- Admin login flow (Auth Service → User Service)
- Customer login flow (Customer Service → Auth Service)
- JWT token generation với roles và permissions
- Token validation ở Gateway
- Token refresh mechanism

⚠️ **Cần review:**
- Permission versioning: Khi permissions thay đổi, user có cần login lại không?
- Token revocation: Blacklist mechanism có hoạt động đúng không?
- Session management: Session được quản lý như thế nào?

### 4.2. Permissions

✅ **Đã implement:**
- User permissions stored in User Service database
- Permissions embedded in JWT token
- Gateway extracts và forward permissions qua headers
- Service permissions stored in Consul KV

⚠️ **Cần review:**
- Permission caching: Có cache permissions không? Cache invalidation như thế nào?
- Permission aggregation: Logic aggregate permissions từ roles và direct permissions
- Permission validation: Services có validate permissions không? Hay chỉ trust Gateway?

### 4.3. Service-to-Service Auth

✅ **Đã implement:**
- Service discovery qua Consul
- Service permissions trong Consul KV
- Service token generation và validation

⚠️ **Cần review:**
- Service token format: Token structure có đủ thông tin không?
- Permission validation: Service B có validate permissions đúng cách không?
- Rate limiting: Rate limits có được enforce không?

## 🎯 5. Questions for Review

### 5.1. Authentication

1. **Token Expiration**: Access token và refresh token có TTL bao lâu? Có phù hợp không?
2. **Token Refresh**: Refresh flow có hoạt động đúng không? Có refresh permissions không?
3. **Session Management**: Session được lưu ở đâu? Có sync giữa services không?
4. **Token Revocation**: Khi user logout hoặc permissions thay đổi, token có được revoke không?

### 5.2. Permissions

1. **Permission Caching**: Permissions có được cache không? Cache invalidation strategy?
2. **Permission Versioning**: `permissions_version` trong token có được sử dụng không?
3. **Permission Aggregation**: Logic aggregate permissions từ roles và direct permissions?
4. **Permission Validation**: Services có validate permissions không? Hay chỉ trust Gateway headers?

### 5.3. Service-to-Service

1. **Service Token TTL**: Service tokens có expiration không?
2. **Permission Updates**: Khi permissions trong Consul KV thay đổi, services có reload không?
3. **Rate Limiting**: Rate limits có được enforce ở service level không?
4. **Circuit Breaker**: Có circuit breaker cho service calls không?

### 5.4. Security

1. **Token Storage**: Tokens được lưu ở đâu ở client? Cookies? LocalStorage?
2. **Token Transmission**: Tokens có được transmit qua HTTPS không?
3. **Permission Leakage**: Permissions trong JWT token có bị leak không?
4. **Service Token Security**: Service tokens có được rotate không?

## 📝 6. Next Steps

1. **Review Implementation**: Xem code implementation của các flows trên
2. **Identify Gaps**: Tìm các gaps trong current implementation
3. **Security Audit**: Review security aspects (token storage, transmission, etc.)
4. **Performance Review**: Review performance (caching, token validation speed, etc.)
5. **Documentation Update**: Update documentation nếu cần


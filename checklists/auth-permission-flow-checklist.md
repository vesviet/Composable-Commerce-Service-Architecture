# Auth & Permission Flow - Implementation Checklist

## 📋 Tổng Quan

Checklist này được tạo dựa trên review code implementation so với documentation trong `docs/backup-2025-11-17/docs/security/auth-permission-flow-review.md`.

**Last Updated**: 2025-01-17  
**Status**: ⚠️ Có một số gaps cần fix

---

## 🔐 1. Authentication Flow

### 1.1. Admin Login Flow

**Documentation Flow:**
```
Admin Dashboard → Gateway → Auth Service → User Service → Auth Service (generate token)
```

**Current Implementation:**
```
Admin Dashboard → Gateway → User Service → Auth Service (generate token)
```

#### ✅ Implemented
- [x] Admin Dashboard gửi login request đến Gateway: `POST /api/auth-service/admin/login`
- [x] Gateway forward request đến User Service (không phải Auth Service)
- [x] User Service validate credentials từ database
- [x] User Service lấy user roles
- [x] User Service gọi Auth Service để generate JWT tokens
- [x] Auth Service generate tokens với `client_type="admin"`
- [x] Tokens được trả về cho Admin Dashboard
- [x] Admin Dashboard lưu tokens vào cookies

#### ⚠️ Gaps & Issues
- [ ] **Flow không đúng documentation**: Documentation nói Admin Dashboard → Auth Service, nhưng code thực tế là → User Service
  - **Impact**: Medium - Flow vẫn hoạt động nhưng không đúng design
  - **Recommendation**: 
    - Option 1: Update documentation để reflect actual flow
    - Option 2: Refactor code để match documentation (Admin Dashboard → Auth Service → User Service)
  - **Files**: `user/internal/service/user.go:693` (AdminLogin)

- [x] **Admin login không lấy permissions**: User Service `AdminLogin` chỉ lấy roles, không lấy permissions
  - **Status**: ✅ **FIXED** - Updated `AdminLogin` to retrieve permissions via `GetUserPermissions`
  - **Changes**: 
    - `user/internal/service/user.go:720-754` - Now calls `GetUserPermissions` instead of just `GetUserRoles`
    - Passes `permissions` and `permissionsVersion` to Auth Service
  - **Files**: `user/internal/service/user.go:693-778`

### 1.2. Customer Login Flow

**Documentation Flow:**
```
Frontend → Gateway → Customer Service → Auth Service (generate token)
```

#### ✅ Implemented
- [x] Frontend gửi login request: `POST /api/customer/login`
- [x] Gateway forward đến Customer Service
- [x] Customer Service validate credentials từ local database
- [x] Customer Service gọi Auth Service để generate JWT tokens
- [x] Auth Service generate tokens với `client_type="customer"`
- [x] Tokens được trả về cho Frontend

#### ⚠️ Gaps & Issues
- [ ] **Customer Service không được review**: Không có code implementation trong codebase hiện tại
  - **Impact**: Unknown - Cần verify implementation
  - **Recommendation**: Review Customer Service login implementation

### 1.3. JWT Token Structure

**Documentation Claims:**
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

#### ✅ Implemented
- [x] Access token chứa `user_id`, `session_id`, `client_type`, `user_type` (backward compatibility)
- [x] Access token chứa `roles` (array hoặc comma-separated string)
- [x] Access token chứa `type`, `exp`, `iat`
- [x] Refresh token chứa `user_id`, `client_type`, `user_type`, `session_id`, `type`, `exp`, `iat`

#### ⚠️ Gaps & Issues
- [x] **Token generation không consistent**: Có 2 cách generate token khác nhau
  - **Status**: ✅ **FIXED** - Unified token generation to include permissions
  - **Changes**:
    - Updated `GenerateTokenRequest` struct to include `Permissions` and `PermissionsVersion`
    - Updated `generateAccessToken` in `token/token.go` to accept and include permissions
    - Updated proto file `auth/api/auth/v1/auth.proto` to include permissions fields
    - Updated Auth Service service layer to pass permissions
    - Updated User Service client and usecase to pass permissions
  - **Files**: 
    - `auth/api/auth/v1/auth.proto:88-96` (GenerateTokenRequest proto)
    - `auth/internal/biz/token/token.go:80-90` (GenerateTokenRequest struct)
    - `auth/internal/biz/token/token.go:329-362` (generateAccessToken)
    - `auth/internal/service/auth.go:46-54` (Service layer)
    - `user/internal/client/auth/auth_client.go:135-153` (Client)
    - `user/internal/biz/user/user.go:626-634` (Usecase)

- [x] **User Service không pass permissions khi generate token**: User Service `AdminLogin` không lấy permissions, nên không pass permissions cho Auth Service
  - **Status**: ✅ **FIXED** - User Service now passes permissions to Auth Service
  - **Changes**:
    - Updated `AdminLogin` to call `GetUserPermissions` instead of `GetUserRoles`
    - Passes `permissions` and `permissionsVersion` to `GenerateToken`
    - Updated all client interfaces and adapters to support new signature
  - **Files**: 
    - `user/internal/service/user.go:720-754` (AdminLogin)
    - `user/internal/biz/user/user.go:626-634` (GenerateToken usecase)
    - `user/internal/client/auth/auth_client.go:135-153` (Client)
    - `user/internal/biz/user/provider.go:27-39` (Adapter)
    - `user/internal/biz/user/user.go:163-166` (AuthClient interface)

---

## 🔑 2. Permission Flow

### 2.1. Permission Storage

#### ✅ Implemented
- [x] User permissions stored in User Service database (PostgreSQL)
- [x] Bảng `user_roles`: User → Role mapping
- [x] Bảng `role_permissions`: Role → Permission mapping (stored in `roles.permissions` JSONB)
- [x] Bảng `service_access`: User → Service access permissions
- [x] Permissions embedded in JWT token (khi token được generate với permissions)

#### ⚠️ Gaps & Issues
- [ ] **Permission versioning không được implement**: `permissions_version` trong token không được track trong database
  - **Impact**: Medium - Không thể invalidate tokens khi permissions thay đổi
  - **Current Code**: `auth/internal/client/user/user_client.go:178` - Dùng `time.Now().Unix()` làm version
  - **Recommendation**: 
    - Implement permission version tracking trong User Service
    - Store `permissions_version` trong user table hoặc separate table
    - Update version khi permissions thay đổi (role added/removed, permission granted/revoked)
  - **Files**: 
    - `user/internal/data/postgres/permission.go:125-159` (GetUserPermissions)
    - `auth/internal/client/user/user_client.go:178`

### 2.2. Permission Retrieval Flow

**Documentation Flow:**
```
Auth Service → User Service (GetUserPermissions) → Database → Aggregate permissions
```

#### ✅ Implemented
- [x] Auth Service gọi User Service để lấy permissions khi login
- [x] User Service query database:
  - Lấy roles của user từ `user_roles`
  - Lấy permissions của từng role từ `roles.permissions` (JSONB)
  - Lấy direct permissions từ `service_access`
  - Aggregate tất cả permissions lại
- [x] User Service trả về aggregated permissions
- [x] Auth Service embed permissions vào JWT token (trong `AuthUsecase.Login`)

#### ⚠️ Gaps & Issues
- [x] **Permission aggregation có thể optimize**: Current implementation có N+1 query issue
  - **Status**: ✅ **FIXED** - Optimized với JOIN query
  - **Changes**:
    - Replaced N+1 queries với single JOIN query
    - Use `JOIN roles ON user_roles.role_id = roles.id` để get all role permissions in one query
    - Use map để aggregate permissions và remove duplicates efficiently
    - Performance improvement: từ N+1 queries xuống 2 queries (1 JOIN + 1 service_access)
  - **Files**: `user/internal/data/postgres/permission.go:125-201`

- [x] **Admin login không retrieve permissions**: User Service `AdminLogin` không gọi `GetUserPermissions`
  - **Status**: ✅ **FIXED** - Admin login now retrieves permissions
  - **Changes**: Updated `AdminLogin` to call `GetUserPermissions` instead of `GetUserRoles`
  - **Files**: `user/internal/service/user.go:720-754` 
    ```go
    // Get user permissions (not just roles)
    permissions, services, roles, err := s.uc.GetUserPermissions(ctx, user.ID)
    ```
  - **Files**: `user/internal/service/user.go:693-778`

### 2.3. Permission Validation Flow

**Documentation Flow:**
```
Client → Gateway (validate JWT, extract permissions) → Service (validate permissions if needed)
```

#### ✅ Implemented
- [x] Client gửi request với JWT token trong header `Authorization: Bearer <token>`
- [x] Gateway validate JWT token (parse và verify signature)
- [x] Gateway extract claims: `user_id`, `roles`, `client_type`
- [x] Gateway forward request với headers:
  - `X-User-ID`: User ID
  - `X-User-Roles`: Comma-separated roles
  - `X-Client-Type`: `admin` | `customer`
- [x] Gateway extract permissions từ JWT token (nếu có)
- [x] Gateway forward permissions qua headers:
  - `X-User-Permissions`: Comma-separated permissions

#### ⚠️ Gaps & Issues
- [ ] **Gateway không extract permissions nếu token không có**: Gateway chỉ extract permissions nếu JWT token có `permissions` claim
  - **Impact**: High - Nếu token không có permissions (như admin tokens từ `token/token.go`), Gateway không forward permissions
  - **Current Code**: 
    - `gateway/internal/middleware/jwt_validator.go:89-101` - Extract permissions từ token
    - `gateway/internal/middleware/kratos_middleware.go:389-393` - Forward permissions nếu có
  - **Recommendation**: 
    - Ensure all tokens include permissions
    - Or: Gateway có thể call User Service để get permissions nếu token không có (fallback)
  - **Files**: 
    - `gateway/internal/middleware/jwt_validator.go:89-101`
    - `gateway/internal/middleware/kratos_middleware.go:389-393`

- [ ] **Services không validate permissions**: Services chỉ trust Gateway headers, không validate permissions
  - **Impact**: Medium - Security risk nếu Gateway bị compromise
  - **Recommendation**: 
    - Services nên validate permissions cho sensitive operations
    - Use middleware để check permissions từ headers
  - **Files**: N/A (cần implement)

### 2.4. Permission Types

#### ✅ Implemented
- [x] User Permissions format: `{resource}:{action}` (e.g., `user:read`, `order:update`)
- [x] Service Permissions stored in Consul KV: `service-permissions/{from-service}/{to-service}`
- [x] Service Permissions format: JSON với `permissions`, `endpoints`, `denied_endpoints`, `rate_limit`, `timeout`

#### ⚠️ Gaps & Issues
- [ ] **Permission caching không được implement**: Permissions không được cache, mỗi lần login phải query database
  - **Impact**: Medium - Performance issue với high traffic
  - **Recommendation**: 
    - Cache permissions trong Redis với TTL
    - Invalidate cache khi permissions thay đổi
  - **Files**: N/A (cần implement)

---

## 🔒 3. Service-to-Service Authentication

### 3.1. Service Token Flow

**Documentation Flow:**
```
Service A → Consul (discover Service B, load permissions) → Generate Service Token → Service B (validate token)
```

#### ✅ Implemented
- [x] Service discovery qua Consul
- [x] Service permissions stored in Consul KV: `service-permissions/{from-service}/{to-service}`
- [x] Service permissions loaded từ Consul KV
- [x] Service permissions validation: Check `endpoints`, `denied_endpoints`, `rate_limit`

#### ⚠️ Gaps & Issues
- [ ] **Service token generation không được implement**: Documentation nói Service A generate service token, nhưng code không có service token generation
  - **Impact**: High - Service-to-service calls không có authentication
  - **Current Code**: 
    - `user/internal/data/consul.go:55-84` - Validate service call permissions
    - Không có service token generation logic
  - **Recommendation**: 
    - Implement service token generation trong common package
    - Service A generate JWT token với claims: `from_service`, `to_service`, `permissions`, `allowed_paths`, `denied_paths`
    - Service B validate token và check permissions
  - **Files**: N/A (cần implement)

- [ ] **Service token validation không được implement**: Service B không validate service tokens
  - **Impact**: High - Service-to-service calls không có authentication
  - **Recommendation**: 
    - Implement service token validation middleware
    - Validate token signature, expiration, permissions
  - **Files**: N/A (cần implement)

### 3.2. Service Permission Matrix

#### ✅ Implemented
- [x] Service permissions stored in Consul KV
- [x] Key format: `service-permissions/{from-service}/{to-service}`
- [x] Value format: JSON với permissions, endpoints, rate limits

#### ⚠️ Gaps & Issues
- [ ] **Service permission updates không được reload**: Khi permissions trong Consul KV thay đổi, services không reload
  - **Impact**: Medium - Permission changes require service restart
  - **Recommendation**: 
    - Implement Consul watch để reload permissions khi KV changes
    - Or: Use Consul sessions để track changes
  - **Files**: `user/internal/data/consul.go:86-104`

- [ ] **Rate limiting không được enforce**: Rate limits trong service permissions không được enforce
  - **Impact**: Medium - No rate limiting protection
  - **Recommendation**: 
    - Implement rate limiter middleware
    - Use rate limits from Consul KV permissions
  - **Files**: N/A (cần implement)

---

## 📊 4. Current State Summary

### 4.1. Authentication

#### ✅ Implemented
- [x] Admin login flow (User Service → Auth Service)
- [x] Customer login flow (Customer Service → Auth Service)
- [x] JWT token generation với roles
- [x] Token validation ở Gateway
- [x] Token refresh mechanism
- [x] Session management (stored in Auth Service database)

#### ⚠️ Cần Review/Fix
- [ ] **Permission versioning**: Khi permissions thay đổi, user có cần login lại không?
  - **Current**: Permissions version không được track, tokens không invalidate khi permissions thay đổi
  - **Recommendation**: Implement permission versioning và token invalidation

- [ ] **Token revocation**: Blacklist mechanism có hoạt động đúng không?
  - **Current**: Token revocation được implement trong `auth/internal/biz/token/token.go:288-323`
  - **Status**: ✅ Implemented - Cần test

- [ ] **Session management**: Session được quản lý như thế nào?
  - **Current**: Sessions stored in Auth Service database
  - **Status**: ✅ Implemented - Cần verify sync giữa services

### 4.2. Permissions

#### ✅ Implemented
- [x] User permissions stored in User Service database
- [x] Permissions embedded in JWT token (trong `AuthUsecase.Login`)
- [x] Gateway extracts và forward permissions qua headers (nếu token có permissions)
- [x] Service permissions stored in Consul KV

#### ⚠️ Cần Review/Fix
- [ ] **Permission caching**: Có cache permissions không? Cache invalidation như thế nào?
  - **Current**: Không có caching
  - **Recommendation**: Implement Redis cache với TTL và invalidation

- [ ] **Permission aggregation**: Logic aggregate permissions từ roles và direct permissions
  - **Current**: ✅ Implemented - Có thể optimize với JOIN query
  - **Status**: ⚠️ Cần optimize

- [ ] **Permission validation**: Services có validate permissions không? Hay chỉ trust Gateway?
  - **Current**: Services chỉ trust Gateway headers
  - **Recommendation**: Implement permission validation middleware trong services

### 4.3. Service-to-Service Auth

#### ✅ Implemented
- [x] Service discovery qua Consul
- [x] Service permissions trong Consul KV
- [x] Service permission validation (check endpoints, denied_endpoints)

#### ⚠️ Cần Review/Fix
- [ ] **Service token format**: Token structure có đủ thông tin không?
  - **Current**: Service tokens không được generate
  - **Recommendation**: Implement service token generation

- [ ] **Permission validation**: Service B có validate permissions đúng cách không?
  - **Current**: Service permission validation được implement nhưng không có token validation
  - **Recommendation**: Implement service token validation

- [ ] **Rate limiting**: Rate limits có được enforce không?
  - **Current**: Rate limits không được enforce
  - **Recommendation**: Implement rate limiter middleware

---

## 🎯 5. Priority Fixes

### High Priority (Security & Functionality)

1. **Admin login không có permissions trong token**
   - **File**: `user/internal/service/user.go:693-778`
   - **Fix**: Lấy permissions từ `GetUserPermissions` và pass cho Auth Service

2. **Token generation không consistent - permissions missing**
   - **File**: `auth/internal/biz/token/token.go:327-350`
   - **Fix**: Update `generateAccessToken` để include permissions và permissions_version

3. **Service token generation không được implement**
   - **Files**: N/A (cần implement)
   - **Fix**: Implement service token generation trong common package

### Medium Priority (Performance & Optimization)

1. **Permission aggregation N+1 query issue**
   - **File**: `user/internal/data/postgres/permission.go:125-159`
   - **Fix**: Use JOIN query để optimize

2. **Permission caching không được implement**
   - **Files**: N/A (cần implement)
   - **Fix**: Implement Redis cache với TTL

3. **Permission versioning không được track**
   - **Files**: `user/internal/data/postgres/permission.go`, `auth/internal/client/user/user_client.go:178`
   - **Fix**: Implement permission version tracking trong database

### Low Priority (Documentation & Consistency)

1. **Admin login flow không đúng documentation**
   - **File**: `user/internal/service/user.go:693-778`
   - **Fix**: Update documentation hoặc refactor code

2. **Services không validate permissions**
   - **Files**: N/A (cần implement)
   - **Fix**: Implement permission validation middleware

---

## 📝 6. Testing Checklist

### Authentication Testing
- [ ] Test admin login flow end-to-end
- [ ] Test customer login flow end-to-end
- [ ] Test token validation ở Gateway
- [ ] Test token refresh mechanism
- [ ] Test token revocation (blacklist)
- [ ] Test session management

### Permission Testing
- [ ] Test permission retrieval từ User Service
- [ ] Test permission aggregation (roles + direct permissions)
- [ ] Test permissions trong JWT token
- [ ] Test Gateway extract và forward permissions
- [ ] Test permission validation ở services (nếu implement)

### Service-to-Service Testing
- [ ] Test service discovery qua Consul
- [ ] Test service permission loading từ Consul KV
- [ ] Test service token generation (nếu implement)
- [ ] Test service token validation (nếu implement)
- [ ] Test rate limiting (nếu implement)

---

## 📚 7. Related Documentation

- **Auth & Permission Flow Review**: `docs/backup-2025-11-17/docs/security/auth-permission-flow-review.md`
- **Service Permission Matrix**: `docs/backup-2025-11-17/docs/security/service-permission-matrix.md`
- **User Permission Code Review**: `docs/backup-2025-11-17/docs/security/user-permission-code-review.md`
- **Client Type Identification**: `docs/backup-2025-11-17/architecture/CLIENT_TYPE_IDENTIFICATION.md`

---

## 🔄 8. Update History

- **2025-01-17**: Initial checklist created based on code review
- **2025-01-17**: Fixed High Priority Issues:
  - ✅ Fixed Admin login to retrieve and pass permissions
  - ✅ Fixed Token generation to consistently include permissions
  - ✅ Updated proto files, service layers, and clients to support permissions
- **2025-01-17**: Fixed Medium Priority Issues:
  - ✅ Optimized permission aggregation: Fixed N+1 query issue với JOIN query


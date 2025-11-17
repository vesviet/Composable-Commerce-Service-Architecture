# API Routing Guidelines cho Microservices

## 🎯 Nguyên tắc thiết kế Route Path

### 1. Cấu trúc Route chuẩn
```
/{service}/{version}/{resource}/{action}
/{service}/{version}/{resource}/{id}
/{service}/{version}/{resource}/{id}/{sub-resource}
```

### 2. Service-based Route Mapping

#### **Auth Service** (`/auth/v1/`)
```
POST   /auth/v1/login                    # Đăng nhập
POST   /auth/v1/register                 # Đăng ký
POST   /auth/v1/logout                   # Đăng xuất
POST   /auth/v1/refresh                  # Refresh token
POST   /auth/v1/forgot-password          # Quên mật khẩu
POST   /auth/v1/reset-password           # Reset mật khẩu
GET    /auth/v1/verify/{token}           # Xác thực email
POST   /auth/v1/change-password          # Đổi mật khẩu
```

#### **User Service** (`/user/v1/`)
```
GET    /user/v1/profile                  # Lấy thông tin profile
PUT    /user/v1/profile                  # Cập nhật profile
GET    /user/v1/addresses                # Lấy danh sách địa chỉ
POST   /user/v1/addresses                # Thêm địa chỉ mới
PUT    /user/v1/addresses/{id}           # Cập nhật địa chỉ
DELETE /user/v1/addresses/{id}           # Xóa địa chỉ
GET    /user/v1/preferences              # Lấy preferences
PUT    /user/v1/preferences              # Cập nhật preferences
```

#### **Catalog Service** (`/catalog/v1/`)
```
GET    /catalog/v1/products              # Lấy danh sách sản phẩm
GET    /catalog/v1/products/{id}         # Lấy chi tiết sản phẩm
POST   /catalog/v1/products              # Tạo sản phẩm mới (admin)
PUT    /catalog/v1/products/{id}         # Cập nhật sản phẩm (admin)
DELETE /catalog/v1/products/{id}         # Xóa sản phẩm (admin)
GET    /catalog/v1/categories            # Lấy danh sách categories
GET    /catalog/v1/categories/{id}/products # Sản phẩm theo category
GET    /catalog/v1/search                # Tìm kiếm sản phẩm
```

#### **Order Service** (`/order/v1/`)
```
GET    /order/v1/orders                  # Lấy danh sách đơn hàng
POST   /order/v1/orders                  # Tạo đơn hàng mới
GET    /order/v1/orders/{id}             # Lấy chi tiết đơn hàng
PUT    /order/v1/orders/{id}/status      # Cập nhật trạng thái đơn hàng
DELETE /order/v1/orders/{id}             # Hủy đơn hàng
GET    /order/v1/orders/{id}/items       # Lấy items trong đơn hàng
POST   /order/v1/orders/{id}/items       # Thêm item vào đơn hàng
```

#### **Payment Service** (`/payment/v1/`)
```
POST   /payment/v1/payments              # Tạo payment
GET    /payment/v1/payments/{id}         # Lấy thông tin payment
POST   /payment/v1/payments/{id}/confirm # Xác nhận payment
POST   /payment/v1/payments/{id}/refund  # Hoàn tiền
GET    /payment/v1/methods               # Lấy payment methods
```

#### **Shipping Service** (`/shipping/v1/`)
```
POST   /shipping/v1/calculate            # Tính phí ship
POST   /shipping/v1/shipments            # Tạo shipment
GET    /shipping/v1/shipments/{id}       # Tracking shipment
PUT    /shipping/v1/shipments/{id}/status # Cập nhật trạng thái
GET    /shipping/v1/providers            # Lấy shipping providers
```

#### **Notification Service** (`/notification/v1/`)
```
POST   /notification/v1/send             # Gửi notification
GET    /notification/v1/notifications    # Lấy notifications của user
PUT    /notification/v1/notifications/{id}/read # Đánh dấu đã đọc
GET    /notification/v1/templates        # Lấy templates (admin)
POST   /notification/v1/templates        # Tạo template (admin)
```

#### **Review Service** (`/review/v1/`)
```
GET    /review/v1/products/{id}/reviews  # Lấy reviews của sản phẩm
POST   /review/v1/reviews                # Tạo review mới
PUT    /review/v1/reviews/{id}           # Cập nhật review
DELETE /review/v1/reviews/{id}           # Xóa review
GET    /review/v1/reviews/{id}/helpful   # Vote helpful
POST   /review/v1/reviews/{id}/helpful   # Vote helpful
```

### 3. Admin Routes Pattern
```
/{service}/v1/admin/{resource}
```

Ví dụ:
```
GET    /catalog/v1/admin/products        # Admin: Quản lý sản phẩm
GET    /user/v1/admin/users              # Admin: Quản lý users
GET    /order/v1/admin/orders            # Admin: Quản lý orders
GET    /payment/v1/admin/transactions    # Admin: Quản lý transactions
```

### 4. Health Check và Internal Routes
```
GET    /{service}/health                 # Health check
GET    /{service}/metrics                # Metrics endpoint
GET    /{service}/v1/internal/stats      # Internal stats
```

## 🔧 Gateway Configuration

### Route Configuration Example
```yaml
routes:
  # Auth Service Routes
  - path: "/auth/v1/login"
    method: "POST"
    service: "auth"
    target_path: "/v1/auth/login"
    auth_required: false
    description: "User login"

  - path: "/auth/v1/register"
    method: "POST"
    service: "auth"
    target_path: "/v1/auth/register"
    auth_required: false
    description: "User registration"

  # User Service Routes
  - path: "/user/v1/profile"
    method: "GET"
    service: "user"
    target_path: "/v1/user/profile"
    auth_required: true
    permissions: ["user:read"]
    description: "Get user profile"

  - path: "/user/v1/profile"
    method: "PUT"
    service: "user"
    target_path: "/v1/user/profile"
    auth_required: true
    permissions: ["user:write"]
    description: "Update user profile"

  # Catalog Service Routes
  - path: "/catalog/v1/products"
    method: "GET"
    service: "catalog"
    target_path: "/v1/products"
    auth_required: false
    description: "Get products list"

  - path: "/catalog/v1/products/{id}"
    method: "GET"
    service: "catalog"
    target_path: "/v1/products/{id}"
    auth_required: false
    description: "Get product details"

  # Admin Routes
  - path: "/catalog/v1/admin/products"
    method: "POST"
    service: "catalog"
    target_path: "/v1/admin/products"
    auth_required: true
    permissions: ["admin:catalog:write"]
    middleware: ["admin_only"]
    description: "Create product (admin only)"
```

## 📋 Best Practices

### 1. **Naming Conventions**
- Sử dụng kebab-case cho URLs: `/user-preferences` thay vì `/userPreferences`
- Resource names ở dạng số nhiều: `/products`, `/orders`, `/users`
- Actions ở dạng động từ: `/calculate`, `/send`, `/confirm`

### 2. **HTTP Methods**
- `GET`: Lấy dữ liệu (idempotent)
- `POST`: Tạo mới hoặc actions không idempotent
- `PUT`: Cập nhật toàn bộ resource (idempotent)
- `PATCH`: Cập nhật một phần resource
- `DELETE`: Xóa resource (idempotent)

### 3. **Versioning Strategy**
- Sử dụng URL versioning: `/v1/`, `/v2/`
- Maintain backward compatibility
- Deprecation strategy cho old versions

### 4. **Query Parameters**
```
GET /catalog/v1/products?page=1&limit=20&sort=price&order=asc&category=electronics
GET /order/v1/orders?status=pending&from=2024-01-01&to=2024-12-31
GET /user/v1/notifications?unread=true&type=order
```

### 5. **Error Handling**
- Consistent error response format
- Proper HTTP status codes
- Meaningful error messages

### 6. **Security Considerations**
- Authentication required routes
- Permission-based access control
- Rate limiting per service
- Input validation

## 🚀 Implementation Steps

1. **Update Gateway Configuration**
2. **Implement Route Validation**
3. **Add Permission Middleware**
4. **Service Discovery Integration**
5. **Monitoring và Logging**
6. **Documentation Generation**

## 📊 Route Organization Matrix

| Service | Public Routes | Auth Required | Admin Only | Internal |
|---------|---------------|---------------|------------|----------|
| Auth | login, register | logout, change-password | user management | stats |
| User | - | profile, addresses | user admin | health |
| Catalog | products, search | - | product management | sync |
| Order | - | orders CRUD | order admin | fulfillment |
| Payment | methods | payments | transaction admin | webhooks |
| Shipping | calculate | shipments | provider admin | tracking |

Cấu trúc này đảm bảo:
- **Scalability**: Dễ dàng thêm services mới
- **Consistency**: Pattern nhất quán across services
- **Security**: Clear permission boundaries
- **Maintainability**: Dễ debug và monitor
- **Documentation**: Self-documenting URLs
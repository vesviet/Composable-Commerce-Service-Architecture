# Customer, User & Auth Logic Flow - Implementation Checklist

**Last Updated**: December 1, 2025  
**Version**: 1.0.0

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Service Responsibilities](#service-responsibilities)
3. [Authentication Flow](#authentication-flow)
4. [Authorization Flow](#authorization-flow)
5. [Gateway Integration](#gateway-integration)
6. [Implementation Checklist](#implementation-checklist)
7. [Testing Checklist](#testing-checklist)

---

## 🏗️ Architecture Overview

### Service Separation

```
┌─────────────────────────────────────────────────────────────────┐
│                         API Gateway                              │
│  - JWT Validation (local + fallback to Auth Service)            │
│  - Header Injection (X-User-ID, X-Client-Type, X-User-Roles)   │
│  - CORS, Rate Limiting, Circuit Breaker                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ↓
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ↓                     ↓                     ↓
┌──────────────┐      ┌──────────────┐     ┌──────────────┐
│   Customer   │      │     User     │     │     Auth     │
│   Service    │      │   Service    │     │   Service    │
├──────────────┤      ├──────────────┤     ├──────────────┤
│ • Register   │      │ • Register   │     │ • Generate   │
│ • Login      │      │ • Login      │     │   Token      │
│ • Profile    │      │ • Profile    │     │ • Validate   │
│ • Addresses  │      │ • Roles      │     │   Token      │
│ • Preferences│      │ • Permissions│     │ • Refresh    │
│ • Segments   │      │ • Service    │     │   Token      │
│              │      │   Access     │     │ • Revoke     │
│              │      │              │     │   Token      │
│              │      │              │     │ • Sessions   │
└──────────────┘      └──────────────┘     └──────────────┘
     (Port 8003)           (Port 8001)          (Port 8002)
```

### Key Concepts

**Customer vs User:**
- **Customer**: End users who shop on the platform (B2C)
- **User**: Admin, staff, operations personnel (B2B/Internal)

**Client Types:**
- `customer`: Frontend/mobile app users
- `admin`: Admin dashboard users
- `shipper`: Delivery personnel (special admin type)

---

## 🎯 Service Responsibilities

### 1. Customer Service (Port 8003)

**Responsibilities:**
- ✅ Customer registration & login
- ✅ Customer profile management
- ✅ Address management (shipping/billing)
- ✅ Customer preferences
- ✅ Customer segments
- ✅ Password management (forgot/reset)
- ✅ Email verification
- ✅ Social login integration

**Does NOT Handle:**
- ❌ Token generation (delegates to Auth Service)
- ❌ Admin authentication
- ❌ User management

**Key Endpoints:**
```
POST   /api/v1/customers/register
POST   /api/v1/customers/login
POST   /api/v1/customers/refresh
POST   /api/v1/customers/validate
POST   /api/v1/customers/forgot-password
POST   /api/v1/customers/reset-password
POST   /api/v1/customers/verify-email
GET    /api/v1/customers/{id}
PUT    /api/v1/customers/{id}
GET    /api/v1/customers/{id}/addresses
POST   /api/v1/customers/{id}/addresses
```

### 2. User Service (Port 8001)

**Responsibilities:**
- ✅ User (admin/staff) registration & login
- ✅ User profile management
- ✅ Role & permission management (RBAC)
- ✅ Service access control
- ✅ User preferences
- ✅ Credential validation for Auth Service

**Does NOT Handle:**
- ❌ Token generation (delegates to Auth Service)
- ❌ Customer authentication
- ❌ Customer management

**Key Endpoints:**
```
POST   /api/v1/users/login
POST   /api/v1/users/register
GET    /api/v1/users
GET    /api/v1/users/{id}
PUT    /api/v1/users/{id}
GET    /api/v1/roles
POST   /api/v1/roles
POST   /api/v1/users/{id}/roles
GET    /api/v1/users/{id}/permissions
POST   /api/v1/users/{id}/service-access
```

### 3. Auth Service (Port 8002)

**Responsibilities:**
- ✅ JWT token generation
- ✅ Token validation
- ✅ Token refresh
- ✅ Token revocation
- ✅ Session management
- ✅ Session tracking

**Does NOT Handle:**
- ❌ User/Customer login (no credential validation)
- ❌ User/Customer registration
- ❌ Password management
- ❌ Profile management

**Key Endpoints:**
```
POST   /api/v1/auth/tokens/generate
POST   /api/v1/auth/tokens/validate
POST   /api/v1/auth/tokens/refresh
POST   /api/v1/auth/tokens/revoke
POST   /api/v1/auth/sessions
GET    /api/v1/auth/sessions/user/{user_id}
POST   /api/v1/auth/sessions/{id}/revoke
```

---

## 🔐 Authentication Flow

### Customer Registration Flow

```
1. Frontend → Gateway → Customer Service
   POST /api/v1/customers/register
   Body: { email, password, firstName, lastName, phone }

2. Customer Service:
   - Validates input
   - Hashes password (bcrypt)
   - Creates customer record
   - Calls Auth Service to generate token

3. Customer Service → Auth Service
   POST /v1/auth/tokens/generate
   Body: { user_id, user_type: "customer", permissions }

4. Auth Service:
   - Generates JWT access token
   - Generates refresh token
   - Creates session record
   - Returns tokens

5. Customer Service → Frontend
   Response: { customer_id, access_token, refresh_token, expires_at }
```

### Customer Login Flow

```
1. Frontend → Gateway → Customer Service
   POST /api/v1/customers/login
   Body: { email, password, device_info, ip_address }

2. Customer Service:
   - Validates credentials (email + password)
   - Checks customer status (active/inactive)
   - Calls Auth Service to generate token

3. Customer Service → Auth Service
   POST /v1/auth/tokens/generate
   Body: { 
     user_id: customer_id,
     user_type: "customer",
     permissions: [],
     device_info,
     ip_address
   }

4. Auth Service:
   - Generates JWT with claims:
     * user_id: customer_id
     * email: customer@example.com
     * client_type: "customer"
     * roles: []
     * exp: expiration timestamp
   - Creates session
   - Returns tokens

5. Customer Service → Frontend
   Response: { 
     access_token,
     refresh_token,
     expires_at,
     customer: { id, email, name, ... }
   }
```

### User (Admin) Login Flow

```
1. Admin Panel → Gateway → User Service
   POST /api/v1/users/login
   Body: { email, password }

2. User Service:
   - Validates credentials
   - Checks user status
   - Loads user roles & permissions
   - Calls Auth Service to generate token

3. User Service → Auth Service
   POST /v1/auth/tokens/generate
   Body: {
     user_id,
     user_type: "admin",
     permissions: ["users:read", "orders:write", ...],
     permissions_version: "v1"
   }

4. Auth Service:
   - Generates JWT with claims:
     * user_id
     * email
     * client_type: "admin"
     * roles: ["admin", "staff"]
     * permissions: ["users:read", ...]
     * exp
   - Creates session
   - Returns tokens

5. User Service → Admin Panel
   Response: {
     access_token,
     refresh_token,
     expires_at,
     user: { id, email, name, roles, permissions }
   }
```

### Token Refresh Flow

```
1. Frontend → Gateway → Customer/User Service
   POST /api/v1/customers/refresh (or /api/v1/users/refresh)
   Body: { refresh_token }

2. Customer/User Service → Auth Service
   POST /v1/auth/tokens/refresh
   Body: { refresh_token }

3. Auth Service:
   - Validates refresh token
   - Checks session is active
   - Generates new access token
   - Optionally rotates refresh token
   - Returns new tokens

4. Auth Service → Customer/User Service → Frontend
   Response: {
     access_token,
     refresh_token,
     expires_at
   }
```

---

## 🛡️ Authorization Flow

### Gateway JWT Validation

```
1. Request arrives at Gateway
   GET /api/v1/orders
   Headers: { Authorization: "Bearer <jwt_token>" }

2. Gateway Auth Middleware:
   - Extracts token from Authorization header
   - Validates JWT locally (fast path):
     * Verifies signature with JWT_SECRET
     * Checks expiration
     * Extracts claims (user_id, email, roles, client_type)
   
   - If local validation fails, fallback to Auth Service:
     POST /v1/auth/tokens/validate
     Body: { token }

3. Gateway injects headers for downstream services:
   X-User-ID: 123
   X-User-Email: user@example.com
   X-User-Roles: admin,staff
   X-Client-Type: customer
   X-Request-ID: uuid
   X-Gateway-Name: api-gateway
   X-Gateway-Version: v1.0.0

4. Gateway forwards request to backend service
   GET /v1/orders
   Headers: { X-User-ID, X-Client-Type, ... }
```

### Service-Level Authorization

```
1. Service receives request with headers
   GET /v1/orders
   Headers: {
     X-User-ID: 123
     X-Client-Type: customer
     X-User-Roles: user
   }

2. Service extracts context using common middleware:
   import "gitlab.com/ta-microservices/common/middleware"
   
   userID := middleware.ExtractUserID(ctx)
   clientType := middleware.ExtractClientType(ctx)
   roles := middleware.ExtractUserRoles(ctx)

3. Service applies business logic authorization:
   - Check if user owns resource
   - Check if user has required role
   - Check if user has required permission

4. Service returns response or error:
   - 200 OK: Success
   - 403 Forbidden: No permission
   - 404 Not Found: Resource not found or no access
```

### Common Authorization Patterns

**Pattern 1: Resource Ownership**
```go
// Check if user owns the resource
func (uc *OrderUsecase) GetOrder(ctx context.Context, orderID string) (*Order, error) {
    userID := middleware.ExtractUserID(ctx)
    clientType := middleware.ExtractClientType(ctx)
    
    order, err := uc.repo.GetOrder(ctx, orderID)
    if err != nil {
        return nil, err
    }
    
    // Admin can access any order
    if clientType == "admin" {
        return order, nil
    }
    
    // Customer can only access their own orders
    if order.CustomerID != userID {
        return nil, errors.Forbidden("ORDER_ACCESS_DENIED", "You don't have access to this order")
    }
    
    return order, nil
}
```

**Pattern 2: Role-Based Access**
```go
// Check if user has required role
func (uc *UserUsecase) DeleteUser(ctx context.Context, userID string) error {
    if !middleware.HasRole(ctx, "admin") && !middleware.HasRole(ctx, "super_admin") {
        return errors.Forbidden("INSUFFICIENT_PERMISSIONS", "Admin role required")
    }
    
    return uc.repo.DeleteUser(ctx, userID)
}
```

**Pattern 3: Client Type Check**
```go
// Check client type
func (uc *ProductUsecase) CreateProduct(ctx context.Context, req *CreateProductRequest) (*Product, error) {
    // Only admin can create products
    if !middleware.IsAdmin(ctx) {
        return nil, errors.Forbidden("ADMIN_ONLY", "Only admin can create products")
    }
    
    return uc.repo.CreateProduct(ctx, req)
}
```

---

## 🌐 Gateway Integration

### Headers Injected by Gateway

**Authentication Headers:**
```
X-User-ID: 123
X-MD-User-ID: 123
X-User-Email: user@example.com
X-MD-User-Email: user@example.com
X-Username: john_doe
X-MD-Username: john_doe
```

**Authorization Headers:**
```
X-Client-Type: customer
X-MD-Client-Type: customer
X-MD-Global-Client-Type: customer
X-User-Roles: admin,staff
X-MD-User-Roles: admin,staff
X-MD-Global-User-Roles: admin,staff
X-User-Permissions: users:read,orders:write
X-MD-User-Permissions: users:read,orders:write
```

**Gateway Headers:**
```
X-Request-ID: 550e8400-e29b-41d4-a716-446655440000
X-Gateway-Name: api-gateway
X-Gateway-Version: v1.0.0
X-Forwarded-Host: api.example.com
X-Forwarded-For: 192.168.1.1
X-Currency: VND
```

### Public Endpoints (No Auth Required)

**Customer Service:**
```
POST /api/v1/customers/register
POST /api/v1/customers/login
POST /api/v1/customers/refresh
POST /api/v1/customers/validate
POST /api/v1/customers/forgot-password
POST /api/v1/customers/reset-password
POST /api/v1/customers/verify-email
```

**User Service:**
```
POST /api/v1/users/login
POST /api/v1/users/register
```

**Auth Service:**
```
POST /api/v1/auth/tokens/generate
POST /api/v1/auth/tokens/validate
POST /api/v1/auth/tokens/refresh
POST /api/v1/auth/tokens/revoke
```

**Catalog Service:**
```
GET /api/v1/products
GET /api/v1/products/{id}
GET /api/v1/categories
```

### Protected Endpoints (Auth Required)

**Customer Service:**
```
GET    /api/v1/customers/{id}
PUT    /api/v1/customers/{id}
DELETE /api/v1/customers/{id}
GET    /api/v1/customers/{id}/addresses
POST   /api/v1/customers/{id}/addresses
```

**Order Service:**
```
GET    /api/v1/orders
POST   /api/v1/orders
GET    /api/v1/orders/{id}
PUT    /api/v1/orders/{id}
```

**Admin Endpoints:**
```
GET    /admin/v1/users
POST   /admin/v1/users
GET    /admin/v1/orders
PUT    /admin/v1/orders/{id}/status
```

---

## ✅ Implementation Checklist

### Phase 1: Service Setup

#### Customer Service
- [ ] Database schema created (customers, addresses, preferences, segments)
- [ ] Customer repository implemented
- [ ] Authentication usecase implemented (Register, Login, Logout)
- [ ] Password hashing with bcrypt
- [ ] Auth Service client configured
- [ ] Token generation integration
- [ ] Email verification flow
- [ ] Password reset flow
- [ ] Social login integration (optional)

#### User Service
- [ ] Database schema created (users, roles, permissions, service_access)
- [ ] User repository implemented
- [ ] Authentication usecase implemented
- [ ] Role & permission management
- [ ] Service access control
- [ ] Auth Service client configured
- [ ] Token generation integration

#### Auth Service
- [ ] Database schema created (sessions, revoked_tokens)
- [ ] Token usecase implemented
- [ ] Session usecase implemented
- [ ] JWT generation with proper claims
- [ ] JWT validation (signature, expiration)
- [ ] Token refresh logic
- [ ] Token revocation
- [ ] Session tracking

### Phase 2: Gateway Integration

#### Gateway Configuration
- [ ] Service routes configured in `gateway.yaml`
- [ ] Resource mapping added in `resource_mapping.go`
- [ ] Public endpoints listed in auth middleware
- [ ] JWT secret configured (same as Auth Service)
- [ ] CORS configuration
- [ ] Rate limiting configuration

#### Gateway Middleware
- [ ] JWT validation middleware (local + fallback)
- [ ] Header injection middleware
- [ ] Admin authentication middleware
- [ ] CORS middleware
- [ ] Rate limiting middleware
- [ ] Circuit breaker middleware

### Phase 3: Common Middleware

#### Context Extraction
- [ ] `ExtractUserID(ctx)` implemented
- [ ] `ExtractClientType(ctx)` implemented
- [ ] `ExtractUserEmail(ctx)` implemented
- [ ] `ExtractUserRoles(ctx)` implemented
- [ ] `ExtractUserPermissions(ctx)` implemented
- [ ] `ExtractCustomerID(ctx)` implemented

#### Authorization Helpers
- [ ] `IsAdmin(ctx)` implemented
- [ ] `IsCustomer(ctx)` implemented
- [ ] `HasRole(ctx, role)` implemented
- [ ] `HasPermission(ctx, permission)` implemented

### Phase 4: Service Authorization

#### Customer Service
- [ ] Customer can only access own profile
- [ ] Customer can only manage own addresses
- [ ] Admin can access any customer
- [ ] Admin can manage any customer

#### Order Service
- [ ] Customer can only view own orders
- [ ] Customer can only create orders for self
- [ ] Admin can view all orders
- [ ] Admin can update order status

#### User Service
- [ ] User can view own profile
- [ ] Admin can view all users
- [ ] Super admin can manage roles
- [ ] Service access control enforced

---

## 🧪 Testing Checklist

### Unit Tests

#### Customer Service
- [ ] Register with valid data
- [ ] Register with duplicate email
- [ ] Login with valid credentials
- [ ] Login with invalid credentials
- [ ] Login with inactive account
- [ ] Password hashing verification
- [ ] Token generation integration

#### User Service
- [ ] Register admin user
- [ ] Login with valid credentials
- [ ] Role assignment
- [ ] Permission loading
- [ ] Service access validation

#### Auth Service
- [ ] Generate token with valid data
- [ ] Validate token (valid)
- [ ] Validate token (expired)
- [ ] Validate token (invalid signature)
- [ ] Refresh token (valid)
- [ ] Refresh token (expired)
- [ ] Revoke token
- [ ] Session creation
- [ ] Session revocation

### Integration Tests

#### Customer Flow
- [ ] Register → Login → Get Profile
- [ ] Register → Verify Email → Login
- [ ] Login → Refresh Token
- [ ] Forgot Password → Reset Password → Login
- [ ] Login → Create Address → Get Addresses

#### Admin Flow
- [ ] Register Admin → Login → Get Users
- [ ] Login → Assign Role → Get Permissions
- [ ] Login → Grant Service Access → Validate Access

#### Gateway Flow
- [ ] Public endpoint (no auth)
- [ ] Protected endpoint (with valid token)
- [ ] Protected endpoint (with invalid token)
- [ ] Protected endpoint (with expired token)
- [ ] Token refresh through gateway
- [ ] Admin endpoint (with admin token)
- [ ] Admin endpoint (with customer token) → 403

### End-to-End Tests

#### Customer Journey
- [ ] Register new customer
- [ ] Verify email
- [ ] Login
- [ ] Update profile
- [ ] Add shipping address
- [ ] Browse products
- [ ] Create order
- [ ] View order history
- [ ] Logout

#### Admin Journey
- [ ] Login as admin
- [ ] View all customers
- [ ] View all orders
- [ ] Update order status
- [ ] Create new user
- [ ] Assign roles
- [ ] Grant service access
- [ ] Logout

### Security Tests

#### Authentication
- [ ] SQL injection in login
- [ ] XSS in registration
- [ ] Brute force protection
- [ ] Password complexity validation
- [ ] Token expiration enforcement
- [ ] Refresh token rotation

#### Authorization
- [ ] Customer cannot access other customer's data
- [ ] Customer cannot access admin endpoints
- [ ] Admin can access customer data
- [ ] Role-based access control
- [ ] Permission-based access control

### Performance Tests

#### Load Testing
- [ ] 100 concurrent logins
- [ ] 1000 token validations/sec
- [ ] Token refresh under load
- [ ] Gateway JWT validation performance

#### Caching
- [ ] JWT validation caching
- [ ] User role caching
- [ ] Permission caching

---

## 📊 Monitoring & Observability

### Metrics to Track

**Authentication Metrics:**
- Total login attempts
- Successful logins
- Failed logins
- Token generations
- Token validations
- Token refreshes
- Token revocations

**Authorization Metrics:**
- 403 Forbidden responses
- 401 Unauthorized responses
- Role checks
- Permission checks

**Performance Metrics:**
- JWT validation latency
- Auth Service response time
- Gateway middleware latency

### Logging

**Authentication Events:**
- User login (success/failure)
- Token generation
- Token validation
- Token refresh
- Token revocation
- Session creation
- Session revocation

**Authorization Events:**
- Access denied (403)
- Unauthorized access (401)
- Role check failures
- Permission check failures

---

## 🚨 Common Issues & Solutions

### Issue 1: Token Validation Fails

**Symptoms:**
- 401 Unauthorized on protected endpoints
- "Invalid token" error

**Possible Causes:**
- JWT secret mismatch between Gateway and Auth Service
- Token expired
- Token format incorrect (missing "Bearer " prefix)

**Solutions:**
- Verify JWT_SECRET is same in Gateway and Auth Service
- Check token expiration time
- Ensure token format: `Authorization: Bearer <token>`

### Issue 2: Headers Not Forwarded

**Symptoms:**
- Service cannot extract user context
- `ExtractUserID(ctx)` returns empty string

**Possible Causes:**
- Gateway not injecting headers
- Service not reading headers correctly
- Middleware not configured

**Solutions:**
- Check Gateway auth middleware is enabled
- Verify headers are set in Gateway: `X-User-ID`, `X-Client-Type`
- Use common middleware functions: `ExtractUserID(ctx)`

### Issue 3: Customer Can Access Other Customer's Data

**Symptoms:**
- Customer A can view Customer B's orders
- Authorization not working

**Possible Causes:**
- Missing authorization check in service
- Not checking resource ownership

**Solutions:**
- Add ownership check in service layer
- Compare `userID` from context with resource owner
- Return 403 Forbidden if not owner (unless admin)

### Issue 4: Admin Cannot Access Customer Data

**Symptoms:**
- Admin gets 403 Forbidden on customer endpoints

**Possible Causes:**
- Client type check too strict
- Not checking for admin role

**Solutions:**
- Check `client_type == "admin"` OR `HasRole(ctx, "admin")`
- Allow admin to bypass ownership checks

---

## 📚 References

- [Gateway Guide](../../gateway/GATEWAY_GUIDE.md)
- [Auth Service Missing Features](../../auth/MISSING_FEATURES.md)
- [Common Middleware](../../common/middleware/context.go)
- [Customer Service README](../../customer/README.md)
- [User Service README](../../user/README.md)

---

**Version History:**
- v1.0.0 (2025-12-01): Initial version


# Client Type Implementation Guide - Quick Start

## 🚀 QUICK IMPLEMENTATION STEPS

### Step 1: Update Auth Service (2 hours)

#### 1.1. Add ClientType to Token Claims

**File**: `auth/internal/biz/token/token.go`

```go
type TokenClaims struct {
    UserID      string   `json:"user_id"`
    Username    string   `json:"username"`
    Email       string   `json:"email"`
    ClientType  string   `json:"client_type"` // ✅ ADD THIS
    Roles       []string `json:"roles"`
    Permissions []string `json:"permissions"`
    jwt.RegisteredClaims
}
```

#### 1.2. Update Token Generation

```go
// Customer token
func (uc *TokenUsecase) GenerateCustomerToken(...) (string, error) {
    claims := TokenClaims{
        // ... other fields
        ClientType: "customer", // ✅ ADD THIS
    }
    // ... generate token
}

// Admin token
func (uc *TokenUsecase) GenerateAdminToken(...) (string, error) {
    claims := TokenClaims{
        // ... other fields
        ClientType: "admin", // ✅ ADD THIS
    }
    // ... generate token
}
```

#### 1.3. Update Login Endpoints

```go
// auth/internal/service/auth.go

func (s *AuthService) CustomerLogin(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
    // ... validate credentials
    
    token, err := s.tokenUC.GenerateCustomerToken(
        user.Id,
        user.Username,
        user.Email,
        permissions,
    )
    
    return &pb.LoginResponse{
        AccessToken: token,
        User: &pb.UserInfo{
            ClientType: "customer", // ✅ ADD THIS
        },
    }, nil
}

func (s *AuthService) AdminLogin(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
    // ... validate credentials
    // ... check admin role
    
    token, err := s.tokenUC.GenerateAdminToken(
        user.Id,
        user.Username,
        user.Email,
        roles,
        permissions,
    )
    
    return &pb.LoginResponse{
        AccessToken: token,
        User: &pb.UserInfo{
            ClientType: "admin", // ✅ ADD THIS
        },
    }, nil
}
```

---

### Step 2: Update Gateway (1 hour)

#### 2.1. Update Auth Middleware

**File**: `gateway/internal/middleware/auth.go`

```go
func (m *AuthMiddleware) Authenticate() gin.HandlerFunc {
    return func(c *gin.Context) {
        // ... validate token
        
        claims := validateResp.Claims
        
        // ✅ ADD THESE HEADERS
        c.Request.Header.Set("X-User-ID", claims.UserId)
        c.Request.Header.Set("X-Username", claims.Username)
        c.Request.Header.Set("X-User-Email", claims.Email)
        c.Request.Header.Set("X-Client-Type", claims.ClientType) // ✅ KEY HEADER
        c.Request.Header.Set("X-User-Roles", strings.Join(claims.Roles, ","))
        c.Request.Header.Set("X-User-Permissions", strings.Join(claims.Permissions, ","))
        
        // ✅ SET IN CONTEXT
        c.Set("client_type", claims.ClientType)
        
        c.Next()
    }
}
```

#### 2.2. Add Client Type Middleware

```go
// ✅ ADD THIS MIDDLEWARE
func (m *AuthMiddleware) RequireClientType(requiredType string) gin.HandlerFunc {
    return func(c *gin.Context) {
        clientType := c.GetString("client_type")
        
        if clientType != requiredType {
            c.JSON(403, gin.H{
                "error": fmt.Sprintf("This endpoint requires %s access", requiredType),
            })
            c.Abort()
            return
        }
        
        c.Next()
    }
}
```

#### 2.3. Update Routes

**File**: `gateway/internal/router/router.go`

```go
func SetupRoutes(r *gin.Engine, auth *middleware.AuthMiddleware, handlers *handler.Handlers) {
    // ✅ CUSTOMER ROUTES
    customer := r.Group("/api")
    customer.Use(auth.Authenticate())
    customer.Use(auth.RequireClientType("customer")) // ✅ ADD THIS
    {
        customer.GET("/customers/me", handlers.Customer.GetMyProfile)
        customer.PUT("/customers/me", handlers.Customer.UpdateMyProfile)
    }
    
    // ✅ ADMIN ROUTES
    admin := r.Group("/admin")
    admin.Use(auth.Authenticate())
    admin.Use(auth.RequireClientType("admin")) // ✅ ADD THIS
    {
        admin.GET("/customers", handlers.Customer.ListCustomers)
        admin.GET("/customers/:id", handlers.Customer.GetCustomer)
    }
}
```

---

### Step 3: Update Customer Service (2 hours)

#### 3.1. Create Context Helper

**File**: `customer/internal/middleware/context.go`

```go
package middleware

import (
    "context"
    "strings"
    "google.golang.org/grpc/metadata"
)

// ✅ ADD THESE HELPERS
func ExtractClientType(ctx context.Context) string {
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        if values := md.Get("x-client-type"); len(values) > 0 {
            return values[0]
        }
    }
    return "customer" // default
}

func ExtractUserID(ctx context.Context) string {
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        if values := md.Get("x-user-id"); len(values) > 0 {
            return values[0]
        }
    }
    return ""
}

func IsAdmin(ctx context.Context) bool {
    return ExtractClientType(ctx) == "admin"
}

func IsCustomer(ctx context.Context) bool {
    return ExtractClientType(ctx) == "customer"
}
```

#### 3.2. Update Service Methods

**File**: `customer/internal/service/customer.go`

```go
// ✅ UPDATE GetCustomer
func (s *CustomerService) GetCustomer(ctx context.Context, req *pb.GetCustomerRequest) (*pb.Customer, error) {
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    if clientType == "admin" {
        // Admin can get any customer
        return s.getCustomerFull(ctx, req.Id)
    } else {
        // Customer can only get themselves
        if userID != req.Id {
            return nil, status.Error(codes.PermissionDenied, "Cannot access other customer's data")
        }
        return s.getCustomerLimited(ctx, req.Id)
    }
}

// ✅ UPDATE UpdateCustomer
func (s *CustomerService) UpdateCustomer(ctx context.Context, req *pb.UpdateCustomerRequest) (*pb.Customer, error) {
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    if clientType == "admin" {
        // Admin can update any customer with all fields
        return s.updateCustomerAsAdmin(ctx, req)
    } else {
        // Customer can only update themselves with limited fields
        if userID != req.Id {
            return nil, status.Error(codes.PermissionDenied, "Cannot update other customer's data")
        }
        return s.updateCustomerAsSelf(ctx, req)
    }
}

// ✅ UPDATE ListCustomers (admin only)
func (s *CustomerService) ListCustomers(ctx context.Context, req *pb.ListCustomersRequest) (*pb.ListCustomersResponse, error) {
    if !middleware.IsAdmin(ctx) {
        return nil, status.Error(codes.PermissionDenied, "Only admins can list customers")
    }
    
    // ... list logic
}
```

---

### Step 4: Update Other Services (1 hour each)

Apply same pattern to User, Order, and other services:

```go
// user/internal/service/user.go
func (s *UserService) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    if clientType == "admin" {
        return s.getUserFull(ctx, req.Id)
    } else {
        if userID != req.Id {
            return nil, status.Error(codes.PermissionDenied, "Cannot access other user's data")
        }
        return s.getUserLimited(ctx, req.Id)
    }
}

// order/internal/service/order.go
func (s *OrderService) GetOrder(ctx context.Context, req *pb.GetOrderRequest) (*pb.Order, error) {
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    order, err := s.uc.GetOrder(ctx, req.Id)
    if err != nil {
        return nil, err
    }
    
    if clientType == "admin" {
        return order, nil
    } else {
        // Customer can only see their own orders
        if order.CustomerId != userID {
            return nil, status.Error(codes.PermissionDenied, "Cannot access other customer's order")
        }
        return order, nil
    }
}
```

---

## 🧪 TESTING

### Test Auth Service

```bash
# Test customer login
curl -X POST http://localhost:8080/api/auth/customer/login \
  -H "Content-Type: application/json" \
  -d '{"email":"customer@example.com","password":"password123"}'

# Response should include client_type: "customer"

# Test admin login
curl -X POST http://localhost:8080/api/auth/admin/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}'

# Response should include client_type: "admin"
```

### Test Gateway

```bash
# Test customer access to own profile (should work)
curl -X GET http://localhost:8080/api/customers/me \
  -H "Authorization: Bearer <customer_token>"

# Test customer access to admin endpoint (should fail)
curl -X GET http://localhost:8080/admin/customers \
  -H "Authorization: Bearer <customer_token>"

# Test admin access to admin endpoint (should work)
curl -X GET http://localhost:8080/admin/customers \
  -H "Authorization: Bearer <admin_token>"
```

### Test Service Authorization

```bash
# Test customer accessing other customer (should fail)
curl -X GET http://localhost:8080/api/customers/other-customer-id \
  -H "Authorization: Bearer <customer_token>"

# Test admin accessing any customer (should work)
curl -X GET http://localhost:8080/admin/customers/any-customer-id \
  -H "Authorization: Bearer <admin_token>"
```

---

## ✅ CHECKLIST

### Auth Service
- [ ] Add `ClientType` field to TokenClaims
- [ ] Update `GenerateCustomerToken` to set `client_type: "customer"`
- [ ] Update `GenerateAdminToken` to set `client_type: "admin"`
- [ ] Update `CustomerLogin` endpoint
- [ ] Update `AdminLogin` endpoint
- [ ] Test token generation

### Gateway
- [ ] Update auth middleware to extract `ClientType` from token
- [ ] Add `X-Client-Type` header to forwarded requests
- [ ] Add `RequireClientType` middleware
- [ ] Update customer routes to use `RequireClientType("customer")`
- [ ] Update admin routes to use `RequireClientType("admin")`
- [ ] Test route protection

### Customer Service
- [ ] Create `middleware/context.go` with helper functions
- [ ] Update `GetCustomer` to check client type
- [ ] Update `UpdateCustomer` to check client type
- [ ] Update `ListCustomers` to require admin
- [ ] Update `DeleteCustomer` to require admin
- [ ] Test authorization logic

### User Service
- [ ] Create `middleware/context.go` with helper functions
- [ ] Update `GetUser` to check client type
- [ ] Update `UpdateUser` to check client type
- [ ] Update `ListUsers` to require admin
- [ ] Test authorization logic

### Order Service
- [ ] Create `middleware/context.go` with helper functions
- [ ] Update `GetOrder` to check ownership
- [ ] Update `ListOrders` to filter by user
- [ ] Update admin endpoints to require admin
- [ ] Test authorization logic

---

## 📊 ESTIMATED EFFORT

| Task | Effort | Priority |
|------|--------|----------|
| Auth Service updates | 2 hours | 🔴 High |
| Gateway updates | 1 hour | 🔴 High |
| Customer Service updates | 2 hours | 🔴 High |
| User Service updates | 1 hour | 🟡 Medium |
| Order Service updates | 1 hour | 🟡 Medium |
| Testing | 2 hours | 🔴 High |
| Documentation | 1 hour | 🟢 Low |
| **Total** | **10 hours** | **(~1.5 days)** |

---

## 🎯 SUCCESS CRITERIA

- ✅ Customer can only access their own data
- ✅ Admin can access all data
- ✅ Customer cannot access admin endpoints
- ✅ Admin can access admin endpoints
- ✅ Proper error messages for unauthorized access
- ✅ All tests passing

---

Generated: November 11, 2025  
Status: ✅ **READY TO IMPLEMENT**  
Estimated Time: 1.5 days  
Priority: HIGH

# Client Type Identification - JWT Token Claims + Gateway Headers

## 📋 OVERVIEW

Document này mô tả cách phân biệt requests từ **Admin Panel** vs **Frontend** trong microservices architecture sử dụng JWT Token Claims kết hợp với Gateway Headers.

**Approach**: JWT Token Claims + Gateway Headers  
**Security Level**: ⭐⭐⭐⭐⭐ (Excellent)  
**Complexity**: Medium  
**Performance**: ⭐⭐⭐⭐⭐ (Excellent)

---

## 🎯 ARCHITECTURE OVERVIEW

```
┌─────────────┐         ┌─────────────┐
│ Admin Panel │         │  Frontend   │
│  (React)    │         │   (React)   │
└──────┬──────┘         └──────┬──────┘
       │                       │
       │ Admin Token           │ Customer Token
       │ (client_type=admin)   │ (client_type=customer)
       │                       │
       └───────────┬───────────┘
                   ↓
            ┌──────────────┐
            │   Gateway    │
            │              │
            │ 1. Validate  │
            │ 2. Extract   │
            │ 3. Add Headers│
            └──────┬───────┘
                   │
       ┌───────────┼───────────┐
       ↓           ↓           ↓
   ┌────────┐ ┌────────┐ ┌────────┐
   │Customer│ │  User  │ │ Order  │
   │Service │ │Service │ │Service │
   └────────┘ └────────┘ └────────┘
       │           │           │
       └───────────┴───────────┘
                   │
            Check Headers
            Apply Authorization
```

---

## 🔑 JWT TOKEN STRUCTURE

### Token Claims Structure


```go
type TokenClaims struct {
    UserID      string   `json:"user_id"`      // User UUID
    Username    string   `json:"username"`     // Username
    Email       string   `json:"email"`        // Email
    ClientType  string   `json:"client_type"`  // ✅ "admin" or "customer"
    Roles       []string `json:"roles"`        // User roles
    Permissions []string `json:"permissions"`  // User permissions
    jwt.RegisteredClaims
}
```

### Admin Token Example

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "admin@example.com",
  "email": "admin@example.com",
  "client_type": "admin",
  "roles": ["admin", "customer_manager"],
  "permissions": [
    "read:customers",
    "write:customers",
    "delete:customers",
    "read:orders",
    "write:orders"
  ],
  "exp": 1699920000,
  "iat": 1699891200,
  "iss": "auth-service"
}
```

### Customer Token Example

```json
{
  "user_id": "660e8400-e29b-41d4-a716-446655440001",
  "username": "customer@example.com",
  "email": "customer@example.com",
  "client_type": "customer",
  "roles": ["customer"],
  "permissions": [
    "read:own_profile",
    "update:own_profile",
    "read:own_orders",
    "create:orders"
  ],
  "exp": 1699977600,
  "iat": 1699891200,
  "iss": "auth-service"
}
```

---

## 🔐 IMPLEMENTATION

### 1. Auth Service - Token Generation

**File**: `auth/internal/biz/token/token.go`

```go
package token

import (
    "time"
    "github.com/golang-jwt/jwt/v5"
)

type TokenType string

const (
    TokenTypeCustomer TokenType = "customer"
    TokenTypeAdmin    TokenType = "admin"
)

type TokenClaims struct {
    UserID      string   `json:"user_id"`
    Username    string   `json:"username"`
    Email       string   `json:"email"`
    ClientType  string   `json:"client_type"` // ✅ Key field
    Roles       []string `json:"roles"`
    Permissions []string `json:"permissions"`
    jwt.RegisteredClaims
}

type TokenUsecase struct {
    config *conf.Auth
    log    *log.Helper
}

// GenerateCustomerToken generates token for customer login
func (uc *TokenUsecase) GenerateCustomerToken(
    userID, username, email string,
    permissions []string,
) (string, error) {
    claims := TokenClaims{
        UserID:      userID,
        Username:    username,
        Email:       email,
        ClientType:  "customer", // ✅ Set client type
        Roles:       []string{"customer"},
        Permissions: permissions,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            Issuer:    "auth-service",
        },
    }
    
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(uc.config.JwtSecret))
}

// GenerateAdminToken generates token for admin login
func (uc *TokenUsecase) GenerateAdminToken(
    userID, username, email string,
    roles []string,
    permissions []string,
) (string, error) {
    claims := TokenClaims{
        UserID:      userID,
        Username:    username,
        Email:       email,
        ClientType:  "admin", // ✅ Set client type
        Roles:       roles,
        Permissions: permissions,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(8 * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            Issuer:    "auth-service",
        },
    }
    
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(uc.config.JwtSecret))
}

// ValidateToken validates and parses token
func (uc *TokenUsecase) ValidateToken(tokenString string) (*TokenClaims, error) {
    token, err := jwt.ParseWithClaims(
        tokenString,
        &TokenClaims{},
        func(token *jwt.Token) (interface{}, error) {
            return []byte(uc.config.JwtSecret), nil
        },
    )
    
    if err != nil {
        return nil, err
    }
    
    if claims, ok := token.Claims.(*TokenClaims); ok && token.Valid {
        return claims, nil
    }
    
    return nil, fmt.Errorf("invalid token")
}
```

---

### 2. Auth Service - Login Endpoints

**File**: `auth/internal/service/auth.go`

```go
package service

// CustomerLogin handles customer login
func (s *AuthService) CustomerLogin(
    ctx context.Context,
    req *pb.LoginRequest,
) (*pb.LoginResponse, error) {
    s.log.WithContext(ctx).Infof("Customer login: %s", req.Email)
    
    // 1. Validate credentials via User Service
    validateResp, err := s.userClient.ValidateUserCredentials(ctx, &userpb.ValidateUserCredentialsRequest{
        Email:    req.Email,
        Password: req.Password,
    })
    if err != nil {
        return nil, err
    }
    
    if !validateResp.Valid {
        return nil, status.Error(codes.Unauthenticated, "Invalid credentials")
    }
    
    user := validateResp.User
    
    // 2. Get user permissions
    permsResp, err := s.userClient.GetUserPermissions(ctx, &userpb.GetUserPermissionsRequest{
        Id: user.Id,
    })
    if err != nil {
        s.log.WithContext(ctx).Warnf("Failed to get permissions: %v", err)
        permsResp = &userpb.GetUserPermissionsResponse{Permissions: []string{}}
    }
    
    // 3. Generate customer token
    token, err := s.tokenUC.GenerateCustomerToken(
        user.Id,
        user.Username,
        user.Email,
        permsResp.Permissions,
    )
    if err != nil {
        return nil, err
    }
    
    // 4. Create session
    session, err := s.sessionUC.CreateSession(ctx, &Session{
        UserID:     user.Id,
        Token:      token,
        ClientType: "customer", // ✅
        ExpiresAt:  time.Now().Add(24 * time.Hour).Unix(),
    })
    if err != nil {
        s.log.WithContext(ctx).Warnf("Failed to create session: %v", err)
    }
    
    return &pb.LoginResponse{
        AccessToken:  token,
        RefreshToken: session.RefreshToken,
        TokenType:    "Bearer",
        ExpiresIn:    86400, // 24 hours
        User: &pb.UserInfo{
            Id:         user.Id,
            Username:   user.Username,
            Email:      user.Email,
            ClientType: "customer", // ✅
        },
    }, nil
}

// AdminLogin handles admin login
func (s *AuthService) AdminLogin(
    ctx context.Context,
    req *pb.LoginRequest,
) (*pb.LoginResponse, error) {
    s.log.WithContext(ctx).Infof("Admin login: %s", req.Email)
    
    // 1. Validate credentials via User Service
    validateResp, err := s.userClient.ValidateUserCredentials(ctx, &userpb.ValidateUserCredentialsRequest{
        Email:    req.Email,
        Password: req.Password,
    })
    if err != nil {
        return nil, err
    }
    
    if !validateResp.Valid {
        return nil, status.Error(codes.Unauthenticated, "Invalid credentials")
    }
    
    user := validateResp.User
    
    // 2. Check if user has admin role
    permsResp, err := s.userClient.GetUserPermissions(ctx, &userpb.GetUserPermissionsRequest{
        Id: user.Id,
    })
    if err != nil {
        return nil, err
    }
    
    hasAdminRole := false
    for _, role := range permsResp.Roles {
        if role.Name == "admin" || role.Name == "customer_manager" {
            hasAdminRole = true
            break
        }
    }
    
    if !hasAdminRole {
        return nil, status.Error(codes.PermissionDenied, "User is not an admin")
    }
    
    // 3. Extract role names
    roleNames := make([]string, len(permsResp.Roles))
    for i, role := range permsResp.Roles {
        roleNames[i] = role.Name
    }
    
    // 4. Generate admin token
    token, err := s.tokenUC.GenerateAdminToken(
        user.Id,
        user.Username,
        user.Email,
        roleNames,
        permsResp.Permissions,
    )
    if err != nil {
        return nil, err
    }
    
    // 5. Create session
    session, err := s.sessionUC.CreateSession(ctx, &Session{
        UserID:     user.Id,
        Token:      token,
        ClientType: "admin", // ✅
        ExpiresAt:  time.Now().Add(8 * time.Hour).Unix(),
    })
    if err != nil {
        s.log.WithContext(ctx).Warnf("Failed to create session: %v", err)
    }
    
    return &pb.LoginResponse{
        AccessToken:  token,
        RefreshToken: session.RefreshToken,
        TokenType:    "Bearer",
        ExpiresIn:    28800, // 8 hours
        User: &pb.UserInfo{
            Id:         user.Id,
            Username:   user.Username,
            Email:      user.Email,
            ClientType: "admin", // ✅
            Roles:      roleNames,
        },
    }, nil
}
```

---

### 3. Gateway - Authentication Middleware

**File**: `gateway/internal/middleware/auth.go`


```go
package middleware

import (
    "strings"
    "github.com/gin-gonic/gin"
)

type AuthMiddleware struct {
    authClient pb.AuthServiceClient
    log        *log.Helper
}

func NewAuthMiddleware(authClient pb.AuthServiceClient, logger log.Logger) *AuthMiddleware {
    return &AuthMiddleware{
        authClient: authClient,
        log:        log.NewHelper(logger),
    }
}

// Authenticate validates token and extracts claims
func (m *AuthMiddleware) Authenticate() gin.HandlerFunc {
    return func(c *gin.Context) {
        // 1. Extract token from Authorization header
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(401, gin.H{"error": "Authorization header required"})
            c.Abort()
            return
        }
        
        // Remove "Bearer " prefix
        token := strings.TrimPrefix(authHeader, "Bearer ")
        if token == authHeader {
            c.JSON(401, gin.H{"error": "Invalid authorization format"})
            c.Abort()
            return
        }
        
        // 2. Validate token with Auth Service
        validateResp, err := m.authClient.ValidateToken(c.Request.Context(), &pb.ValidateTokenRequest{
            Token: token,
        })
        if err != nil {
            m.log.WithContext(c.Request.Context()).Warnf("Token validation failed: %v", err)
            c.JSON(401, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }
        
        if !validateResp.Valid {
            c.JSON(401, gin.H{"error": "Token is invalid or expired"})
            c.Abort()
            return
        }
        
        claims := validateResp.Claims
        
        // 3. ✅ Add headers for downstream services
        c.Request.Header.Set("X-User-ID", claims.UserId)
        c.Request.Header.Set("X-Username", claims.Username)
        c.Request.Header.Set("X-User-Email", claims.Email)
        c.Request.Header.Set("X-Client-Type", claims.ClientType) // ✅ Key header
        c.Request.Header.Set("X-User-Roles", strings.Join(claims.Roles, ","))
        c.Request.Header.Set("X-User-Permissions", strings.Join(claims.Permissions, ","))
        
        // 4. Set in context for handlers
        c.Set("user_id", claims.UserId)
        c.Set("username", claims.Username)
        c.Set("email", claims.Email)
        c.Set("client_type", claims.ClientType) // ✅
        c.Set("roles", claims.Roles)
        c.Set("permissions", claims.Permissions)
        
        m.log.WithContext(c.Request.Context()).Debugf(
            "Authenticated user: %s (client_type: %s)",
            claims.UserId,
            claims.ClientType,
        )
        
        c.Next()
    }
}

// RequireClientType ensures request is from specific client type
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

// RequireAnyRole ensures user has at least one of the required roles
func (m *AuthMiddleware) RequireAnyRole(requiredRoles ...string) gin.HandlerFunc {
    return func(c *gin.Context) {
        userRoles := c.GetStringSlice("roles")
        
        hasRole := false
        for _, userRole := range userRoles {
            for _, requiredRole := range requiredRoles {
                if userRole == requiredRole {
                    hasRole = true
                    break
                }
            }
            if hasRole {
                break
            }
        }
        
        if !hasRole {
            c.JSON(403, gin.H{
                "error": fmt.Sprintf("Requires one of roles: %v", requiredRoles),
            })
            c.Abort()
            return
        }
        
        c.Next()
    }
}
```

---

### 4. Gateway - Route Configuration

**File**: `gateway/internal/router/router.go`

```go
package router

func SetupRoutes(r *gin.Engine, auth *middleware.AuthMiddleware, handlers *handler.Handlers) {
    // Public routes (no auth)
    public := r.Group("/api")
    {
        public.POST("/auth/customer/login", handlers.Auth.CustomerLogin)
        public.POST("/auth/admin/login", handlers.Auth.AdminLogin)
        public.POST("/auth/register", handlers.Auth.Register)
    }
    
    // ✅ Customer routes (require customer token)
    customer := r.Group("/api")
    customer.Use(auth.Authenticate())
    customer.Use(auth.RequireClientType("customer")) // ✅ Only customers
    {
        // Customer profile
        customer.GET("/customers/me", handlers.Customer.GetMyProfile)
        customer.PUT("/customers/me", handlers.Customer.UpdateMyProfile)
        
        // Customer orders
        customer.GET("/orders/my", handlers.Order.GetMyOrders)
        customer.POST("/orders", handlers.Order.CreateOrder)
        customer.GET("/orders/:id", handlers.Order.GetMyOrder)
    }
    
    // ✅ Admin routes (require admin token)
    admin := r.Group("/admin")
    admin.Use(auth.Authenticate())
    admin.Use(auth.RequireClientType("admin")) // ✅ Only admins
    {
        // Customer management
        adminCustomers := admin.Group("/customers")
        adminCustomers.Use(auth.RequireAnyRole("admin", "customer_manager"))
        {
            adminCustomers.GET("", handlers.Customer.ListCustomers)
            adminCustomers.GET("/:id", handlers.Customer.GetCustomer)
            adminCustomers.POST("", handlers.Customer.CreateCustomer)
            adminCustomers.PUT("/:id", handlers.Customer.UpdateCustomer)
            adminCustomers.DELETE("/:id", handlers.Customer.DeleteCustomer)
        }
        
        // Order management
        adminOrders := admin.Group("/orders")
        adminOrders.Use(auth.RequireAnyRole("admin", "order_manager"))
        {
            adminOrders.GET("", handlers.Order.ListOrders)
            adminOrders.GET("/:id", handlers.Order.GetOrder)
            adminOrders.PUT("/:id/status", handlers.Order.UpdateOrderStatus)
        }
        
        // User management
        adminUsers := admin.Group("/users")
        adminUsers.Use(auth.RequireAnyRole("admin"))
        {
            adminUsers.GET("", handlers.User.ListUsers)
            adminUsers.GET("/:id", handlers.User.GetUser)
            adminUsers.POST("", handlers.User.CreateUser)
            adminUsers.PUT("/:id", handlers.User.UpdateUser)
            adminUsers.POST("/:id/roles", handlers.User.AssignRole)
        }
    }
}
```

---

### 5. Customer Service - Extract Client Type

**File**: `customer/internal/middleware/context.go`

```go
package middleware

import (
    "context"
    "strings"
    "google.golang.org/grpc/metadata"
)

// ExtractClientType extracts client type from gRPC metadata
func ExtractClientType(ctx context.Context) string {
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        if values := md.Get("x-client-type"); len(values) > 0 {
            return values[0]
        }
    }
    return "customer" // default
}

// ExtractUserID extracts user ID from gRPC metadata
func ExtractUserID(ctx context.Context) string {
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        if values := md.Get("x-user-id"); len(values) > 0 {
            return values[0]
        }
    }
    return ""
}

// ExtractUserRoles extracts user roles from gRPC metadata
func ExtractUserRoles(ctx context.Context) []string {
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        if values := md.Get("x-user-roles"); len(values) > 0 {
            return strings.Split(values[0], ",")
        }
    }
    return []string{}
}

// ExtractUserPermissions extracts user permissions from gRPC metadata
func ExtractUserPermissions(ctx context.Context) []string {
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        if values := md.Get("x-user-permissions"); len(values) > 0 {
            return strings.Split(values[0], ",")
        }
    }
    return []string{}
}

// IsAdmin checks if request is from admin
func IsAdmin(ctx context.Context) bool {
    return ExtractClientType(ctx) == "admin"
}

// IsCustomer checks if request is from customer
func IsCustomer(ctx context.Context) bool {
    return ExtractClientType(ctx) == "customer"
}

// HasRole checks if user has specific role
func HasRole(ctx context.Context, role string) bool {
    roles := ExtractUserRoles(ctx)
    for _, r := range roles {
        if r == role {
            return true
        }
    }
    return false
}

// HasPermission checks if user has specific permission
func HasPermission(ctx context.Context, permission string) bool {
    permissions := ExtractUserPermissions(ctx)
    for _, p := range permissions {
        if p == permission {
            return true
        }
    }
    return false
}
```

---

### 6. Customer Service - Authorization Logic

**File**: `customer/internal/service/customer.go`


```go
package service

import (
    "customer/internal/middleware"
)

type CustomerService struct {
    pb.UnimplementedCustomerServiceServer
    uc  *biz.CustomerUsecase
    log *log.Helper
}

// GetCustomer gets customer by ID
func (s *CustomerService) GetCustomer(
    ctx context.Context,
    req *pb.GetCustomerRequest,
) (*pb.Customer, error) {
    // ✅ Extract client type and user ID
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    s.log.WithContext(ctx).Infof(
        "GetCustomer: id=%s, client_type=%s, user_id=%s",
        req.Id,
        clientType,
        userID,
    )
    
    // ✅ Authorization logic
    if clientType == "admin" {
        // Admin can get any customer with full details
        return s.getCustomerFull(ctx, req.Id)
    } else {
        // Customer can only get themselves
        if userID != req.Id {
            return nil, status.Error(
                codes.PermissionDenied,
                "Cannot access other customer's data",
            )
        }
        return s.getCustomerLimited(ctx, req.Id)
    }
}

// getCustomerFull returns full customer details (for admin)
func (s *CustomerService) getCustomerFull(ctx context.Context, id string) (*pb.Customer, error) {
    customer, err := s.uc.GetCustomer(ctx, id)
    if err != nil {
        return nil, err
    }
    
    // Return all fields including sensitive data
    return &pb.Customer{
        Id:              customer.ID,
        Email:           customer.Email,
        FirstName:       customer.FirstName,
        LastName:        customer.LastName,
        Phone:           customer.Phone,
        Address:         customer.Address,
        City:            customer.City,
        Country:         customer.Country,
        PostalCode:      customer.PostalCode,
        Status:          customer.Status,
        TotalOrders:     customer.TotalOrders,
        TotalSpent:      customer.TotalSpent,
        LoyaltyPoints:   customer.LoyaltyPoints,
        CreatedAt:       customer.CreatedAt,
        UpdatedAt:       customer.UpdatedAt,
        LastOrderAt:     customer.LastOrderAt,
        // ✅ Admin-only fields
        InternalNotes:   customer.InternalNotes,
        CreditLimit:     customer.CreditLimit,
        PaymentTerms:    customer.PaymentTerms,
    }, nil
}

// getCustomerLimited returns limited customer details (for customer)
func (s *CustomerService) getCustomerLimited(ctx context.Context, id string) (*pb.Customer, error) {
    customer, err := s.uc.GetCustomer(ctx, id)
    if err != nil {
        return nil, err
    }
    
    // Return only non-sensitive fields
    return &pb.Customer{
        Id:            customer.ID,
        Email:         customer.Email,
        FirstName:     customer.FirstName,
        LastName:      customer.LastName,
        Phone:         customer.Phone,
        Address:       customer.Address,
        City:          customer.City,
        Country:       customer.Country,
        PostalCode:    customer.PostalCode,
        LoyaltyPoints: customer.LoyaltyPoints,
        // ✅ Hide admin-only fields
        // InternalNotes, CreditLimit, PaymentTerms not included
    }, nil
}

// UpdateCustomer updates customer information
func (s *CustomerService) UpdateCustomer(
    ctx context.Context,
    req *pb.UpdateCustomerRequest,
) (*pb.Customer, error) {
    // ✅ Extract client type and user ID
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    s.log.WithContext(ctx).Infof(
        "UpdateCustomer: id=%s, client_type=%s, user_id=%s",
        req.Id,
        clientType,
        userID,
    )
    
    // ✅ Authorization logic
    if clientType == "admin" {
        // Admin can update any customer with all fields
        return s.updateCustomerAsAdmin(ctx, req)
    } else {
        // Customer can only update themselves with limited fields
        if userID != req.Id {
            return nil, status.Error(
                codes.PermissionDenied,
                "Cannot update other customer's data",
            )
        }
        return s.updateCustomerAsSelf(ctx, req)
    }
}

// updateCustomerAsAdmin updates customer with admin privileges
func (s *CustomerService) updateCustomerAsAdmin(
    ctx context.Context,
    req *pb.UpdateCustomerRequest,
) (*pb.Customer, error) {
    // Admin can update all fields
    customer := &biz.Customer{
        ID:            req.Id,
        FirstName:     req.FirstName,
        LastName:      req.LastName,
        Phone:         req.Phone,
        Address:       req.Address,
        City:          req.City,
        Country:       req.Country,
        PostalCode:    req.PostalCode,
        Status:        req.Status,
        // ✅ Admin-only fields
        InternalNotes: req.InternalNotes,
        CreditLimit:   req.CreditLimit,
        PaymentTerms:  req.PaymentTerms,
    }
    
    updated, err := s.uc.UpdateCustomer(ctx, customer)
    if err != nil {
        return nil, err
    }
    
    return s.getCustomerFull(ctx, updated.ID)
}

// updateCustomerAsSelf updates customer with self privileges
func (s *CustomerService) updateCustomerAsSelf(
    ctx context.Context,
    req *pb.UpdateCustomerRequest,
) (*pb.Customer, error) {
    // Customer can only update limited fields
    customer := &biz.Customer{
        ID:         req.Id,
        FirstName:  req.FirstName,
        LastName:   req.LastName,
        Phone:      req.Phone,
        Address:    req.Address,
        City:       req.City,
        Country:    req.Country,
        PostalCode: req.PostalCode,
        // ✅ Cannot update: Status, InternalNotes, CreditLimit, PaymentTerms
    }
    
    updated, err := s.uc.UpdateCustomer(ctx, customer)
    if err != nil {
        return nil, err
    }
    
    return s.getCustomerLimited(ctx, updated.ID)
}

// ListCustomers lists customers (admin only)
func (s *CustomerService) ListCustomers(
    ctx context.Context,
    req *pb.ListCustomersRequest,
) (*pb.ListCustomersResponse, error) {
    // ✅ Check if admin
    if !middleware.IsAdmin(ctx) {
        return nil, status.Error(
            codes.PermissionDenied,
            "Only admins can list customers",
        )
    }
    
    // ✅ Check specific permission
    if !middleware.HasPermission(ctx, "read:customers") {
        return nil, status.Error(
            codes.PermissionDenied,
            "Missing permission: read:customers",
        )
    }
    
    customers, total, err := s.uc.ListCustomers(ctx, &biz.CustomerFilter{
        Page:   req.Page,
        Limit:  req.Limit,
        Search: req.Search,
        Status: req.Status,
    })
    if err != nil {
        return nil, err
    }
    
    pbCustomers := make([]*pb.Customer, len(customers))
    for i, c := range customers {
        pbCustomers[i] = s.customerToProto(c)
    }
    
    return &pb.ListCustomersResponse{
        Customers: pbCustomers,
        Total:     total,
    }, nil
}

// DeleteCustomer deletes customer (admin only)
func (s *CustomerService) DeleteCustomer(
    ctx context.Context,
    req *pb.DeleteCustomerRequest,
) (*emptypb.Empty, error) {
    // ✅ Check if admin with specific role
    if !middleware.HasRole(ctx, "admin") && !middleware.HasRole(ctx, "customer_manager") {
        return nil, status.Error(
            codes.PermissionDenied,
            "Only admins or customer managers can delete customers",
        )
    }
    
    // ✅ Check specific permission
    if !middleware.HasPermission(ctx, "delete:customers") {
        return nil, status.Error(
            codes.PermissionDenied,
            "Missing permission: delete:customers",
        )
    }
    
    err := s.uc.DeleteCustomer(ctx, req.Id)
    if err != nil {
        return nil, err
    }
    
    return &emptypb.Empty{}, nil
}
```

---

## 📋 HEADERS REFERENCE

### Headers Added by Gateway

| Header | Description | Example |
|--------|-------------|---------|
| `X-User-ID` | User UUID | `550e8400-e29b-41d4-a716-446655440000` |
| `X-Username` | Username | `admin@example.com` |
| `X-User-Email` | User email | `admin@example.com` |
| `X-Client-Type` | Client type | `admin` or `customer` |
| `X-User-Roles` | Comma-separated roles | `admin,customer_manager` |
| `X-User-Permissions` | Comma-separated permissions | `read:customers,write:customers` |

### Usage in Services

```go
// Extract from gRPC metadata
md, _ := metadata.FromIncomingContext(ctx)
clientType := md.Get("x-client-type")[0]
userID := md.Get("x-user-id")[0]
roles := strings.Split(md.Get("x-user-roles")[0], ",")
```

---

## 🔐 AUTHORIZATION PATTERNS

### Pattern 1: Client Type Check

```go
func (s *Service) SomeMethod(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    clientType := middleware.ExtractClientType(ctx)
    
    if clientType == "admin" {
        // Admin logic
    } else {
        // Customer logic
    }
}
```

### Pattern 2: Self-Access Check

```go
func (s *Service) UpdateProfile(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    userID := middleware.ExtractUserID(ctx)
    
    if userID != req.Id {
        return nil, status.Error(codes.PermissionDenied, "Can only update own profile")
    }
    
    // Update logic
}
```

### Pattern 3: Role-Based Check

```go
func (s *Service) DeleteResource(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    if !middleware.HasRole(ctx, "admin") {
        return nil, status.Error(codes.PermissionDenied, "Admin role required")
    }
    
    // Delete logic
}
```

### Pattern 4: Permission-Based Check

```go
func (s *Service) ListResources(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    if !middleware.HasPermission(ctx, "read:resources") {
        return nil, status.Error(codes.PermissionDenied, "Missing permission")
    }
    
    // List logic
}
```

### Pattern 5: Combined Check

```go
func (s *Service) UpdateCustomer(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    // Admin with permission can update any customer
    if clientType == "admin" && middleware.HasPermission(ctx, "write:customers") {
        return s.updateAnyCustomer(ctx, req)
    }
    
    // Customer can only update themselves
    if clientType == "customer" && userID == req.Id {
        return s.updateOwnProfile(ctx, req)
    }
    
    return nil, status.Error(codes.PermissionDenied, "Unauthorized")
}
```

---

## 🧪 TESTING

### Test Token Generation


```go
// auth/internal/biz/token/token_test.go

func TestGenerateCustomerToken(t *testing.T) {
    uc := &TokenUsecase{
        config: &conf.Auth{JwtSecret: "test-secret"},
    }
    
    token, err := uc.GenerateCustomerToken(
        "user-123",
        "customer@example.com",
        "customer@example.com",
        []string{"read:own_profile"},
    )
    
    assert.NoError(t, err)
    assert.NotEmpty(t, token)
    
    // Validate token
    claims, err := uc.ValidateToken(token)
    assert.NoError(t, err)
    assert.Equal(t, "customer", claims.ClientType)
    assert.Equal(t, "user-123", claims.UserID)
}

func TestGenerateAdminToken(t *testing.T) {
    uc := &TokenUsecase{
        config: &conf.Auth{JwtSecret: "test-secret"},
    }
    
    token, err := uc.GenerateAdminToken(
        "admin-123",
        "admin@example.com",
        "admin@example.com",
        []string{"admin"},
        []string{"read:customers", "write:customers"},
    )
    
    assert.NoError(t, err)
    assert.NotEmpty(t, token)
    
    // Validate token
    claims, err := uc.ValidateToken(token)
    assert.NoError(t, err)
    assert.Equal(t, "admin", claims.ClientType)
    assert.Equal(t, "admin-123", claims.UserID)
    assert.Contains(t, claims.Roles, "admin")
}
```

### Test Authorization Logic

```go
// customer/internal/service/customer_test.go

func TestGetCustomer_AsAdmin(t *testing.T) {
    // Setup
    ctx := context.Background()
    ctx = metadata.NewIncomingContext(ctx, metadata.Pairs(
        "x-client-type", "admin",
        "x-user-id", "admin-123",
        "x-user-roles", "admin",
    ))
    
    service := setupTestService(t)
    
    // Test
    resp, err := service.GetCustomer(ctx, &pb.GetCustomerRequest{
        Id: "customer-456",
    })
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, resp)
    assert.NotEmpty(t, resp.InternalNotes) // Admin can see sensitive fields
}

func TestGetCustomer_AsCustomer_OwnProfile(t *testing.T) {
    // Setup
    ctx := context.Background()
    ctx = metadata.NewIncomingContext(ctx, metadata.Pairs(
        "x-client-type", "customer",
        "x-user-id", "customer-456",
        "x-user-roles", "customer",
    ))
    
    service := setupTestService(t)
    
    // Test
    resp, err := service.GetCustomer(ctx, &pb.GetCustomerRequest{
        Id: "customer-456",
    })
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, resp)
    assert.Empty(t, resp.InternalNotes) // Customer cannot see sensitive fields
}

func TestGetCustomer_AsCustomer_OtherProfile(t *testing.T) {
    // Setup
    ctx := context.Background()
    ctx = metadata.NewIncomingContext(ctx, metadata.Pairs(
        "x-client-type", "customer",
        "x-user-id", "customer-456",
        "x-user-roles", "customer",
    ))
    
    service := setupTestService(t)
    
    // Test
    resp, err := service.GetCustomer(ctx, &pb.GetCustomerRequest{
        Id: "customer-789", // Different customer
    })
    
    // Assert
    assert.Error(t, err)
    assert.Nil(t, resp)
    assert.Contains(t, err.Error(), "PermissionDenied")
}
```

---

## 🔄 REQUEST FLOW EXAMPLE

### Admin Request Flow

```
1. Admin Panel Login
   POST /api/auth/admin/login
   Body: { email: "admin@example.com", password: "***" }
   
   Response: {
     access_token: "eyJhbGc...",
     token_type: "Bearer",
     user: {
       id: "admin-123",
       client_type: "admin",
       roles: ["admin"]
     }
   }

2. Admin Lists Customers
   GET /admin/customers
   Headers: {
     Authorization: "Bearer eyJhbGc..."
   }
   
   Gateway:
   - Validates token
   - Extracts claims: { client_type: "admin", user_id: "admin-123" }
   - Adds headers: X-Client-Type: admin, X-User-ID: admin-123
   - Forwards to Customer Service
   
   Customer Service:
   - Extracts X-Client-Type: admin
   - Checks permission: read:customers
   - Returns full customer list with sensitive fields

3. Admin Updates Customer
   PUT /admin/customers/customer-456
   Headers: {
     Authorization: "Bearer eyJhbGc..."
   }
   Body: {
     first_name: "John",
     internal_notes: "VIP customer"
   }
   
   Gateway:
   - Validates token
   - Adds headers: X-Client-Type: admin
   - Forwards to Customer Service
   
   Customer Service:
   - Extracts X-Client-Type: admin
   - Allows update of all fields including internal_notes
   - Returns updated customer
```

### Customer Request Flow

```
1. Customer Login
   POST /api/auth/customer/login
   Body: { email: "customer@example.com", password: "***" }
   
   Response: {
     access_token: "eyJhbGc...",
     token_type: "Bearer",
     user: {
       id: "customer-456",
       client_type: "customer",
       roles: ["customer"]
     }
   }

2. Customer Gets Own Profile
   GET /api/customers/me
   Headers: {
     Authorization: "Bearer eyJhbGc..."
   }
   
   Gateway:
   - Validates token
   - Extracts claims: { client_type: "customer", user_id: "customer-456" }
   - Adds headers: X-Client-Type: customer, X-User-ID: customer-456
   - Forwards to Customer Service
   
   Customer Service:
   - Extracts X-Client-Type: customer
   - Extracts X-User-ID: customer-456
   - Checks if user_id matches requested customer_id
   - Returns limited customer data (no sensitive fields)

3. Customer Updates Own Profile
   PUT /api/customers/me
   Headers: {
     Authorization: "Bearer eyJhbGc..."
   }
   Body: {
     first_name: "Jane",
     phone: "+1234567890"
   }
   
   Gateway:
   - Validates token
   - Adds headers: X-Client-Type: customer, X-User-ID: customer-456
   - Forwards to Customer Service
   
   Customer Service:
   - Extracts X-Client-Type: customer
   - Checks if user_id matches customer_id
   - Allows update of limited fields only (no internal_notes)
   - Returns updated customer

4. Customer Tries to Access Other Customer (DENIED)
   GET /api/customers/customer-789
   Headers: {
     Authorization: "Bearer eyJhbGc..."
   }
   
   Gateway:
   - Validates token
   - Adds headers: X-Client-Type: customer, X-User-ID: customer-456
   - Forwards to Customer Service
   
   Customer Service:
   - Extracts X-Client-Type: customer
   - Extracts X-User-ID: customer-456
   - Checks: customer-456 != customer-789
   - Returns 403 PermissionDenied
```

---

## 🛡️ SECURITY CONSIDERATIONS

### 1. Token Security

**Best Practices**:
- ✅ Use strong JWT secret (min 32 characters)
- ✅ Set appropriate token expiration (admin: 8h, customer: 24h)
- ✅ Include issuer claim for validation
- ✅ Use HTTPS only in production
- ✅ Implement token refresh mechanism

**Example Config**:
```yaml
# auth/configs/config.yaml
auth:
  jwt_secret: "your-super-secret-key-min-32-chars-long"
  admin_token_ttl: 8h
  customer_token_ttl: 24h
  refresh_token_ttl: 168h # 7 days
  issuer: "auth-service"
```

### 2. Header Validation

**Gateway should validate**:
- ✅ Token signature
- ✅ Token expiration
- ✅ Token issuer
- ✅ Client type matches route

**Example**:
```go
func (m *AuthMiddleware) validateRoute(c *gin.Context, claims *TokenClaims) error {
    path := c.Request.URL.Path
    
    // Admin routes require admin token
    if strings.HasPrefix(path, "/admin/") && claims.ClientType != "admin" {
        return fmt.Errorf("admin token required for admin routes")
    }
    
    // Customer routes require customer token
    if strings.HasPrefix(path, "/api/") && claims.ClientType != "customer" {
        return fmt.Errorf("customer token required for customer routes")
    }
    
    return nil
}
```

### 3. Service-Level Validation

**Services should always validate**:
- ✅ Headers are present
- ✅ Client type is valid
- ✅ User ID matches resource owner (for customer requests)
- ✅ Roles/permissions are sufficient

**Example**:
```go
func (s *Service) validateAccess(ctx context.Context, resourceOwnerID string) error {
    clientType := middleware.ExtractClientType(ctx)
    userID := middleware.ExtractUserID(ctx)
    
    if clientType == "admin" {
        return nil // Admin can access anything
    }
    
    if userID != resourceOwnerID {
        return status.Error(codes.PermissionDenied, "Cannot access other user's resource")
    }
    
    return nil
}
```

### 4. Audit Logging

**Log all authorization decisions**:
```go
func (s *Service) logAuthDecision(ctx context.Context, action string, allowed bool, reason string) {
    s.log.WithContext(ctx).Infof(
        "Authorization: action=%s, allowed=%v, reason=%s, client_type=%s, user_id=%s",
        action,
        allowed,
        reason,
        middleware.ExtractClientType(ctx),
        middleware.ExtractUserID(ctx),
    )
}
```

---

## 📊 MONITORING & METRICS

### Metrics to Track

```go
// Prometheus metrics
var (
    authRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "auth_requests_total",
            Help: "Total number of authentication requests",
        },
        []string{"client_type", "status"},
    )
    
    authorizationDecisions = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "authorization_decisions_total",
            Help: "Total number of authorization decisions",
        },
        []string{"service", "method", "client_type", "decision"},
    )
    
    tokenValidationDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "token_validation_duration_seconds",
            Help: "Token validation duration",
        },
        []string{"client_type"},
    )
)

// Usage
func (m *AuthMiddleware) Authenticate() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        
        // ... validation logic ...
        
        duration := time.Since(start).Seconds()
        tokenValidationDuration.WithLabelValues(claims.ClientType).Observe(duration)
        authRequestsTotal.WithLabelValues(claims.ClientType, "success").Inc()
        
        c.Next()
    }
}
```

---

## 🎯 SUMMARY

### Key Points

1. **JWT Token Claims**
   - Include `client_type` field in token
   - Generate different tokens for admin vs customer
   - Validate token at gateway

2. **Gateway Headers**
   - Extract claims from token
   - Add headers for downstream services
   - Enforce route-level authorization

3. **Service Authorization**
   - Extract headers from context
   - Implement authorization logic
   - Return appropriate errors

4. **Security**
   - Validate at multiple layers
   - Log authorization decisions
   - Monitor metrics

### Benefits

- ✅ **Clear separation** between admin and customer access
- ✅ **Centralized authentication** at gateway
- ✅ **Flexible authorization** at service level
- ✅ **Easy to test** with metadata injection
- ✅ **Scalable** for multiple services

### Next Steps

1. Implement token generation in Auth Service
2. Add authentication middleware in Gateway
3. Update services to check client type
4. Add comprehensive tests
5. Set up monitoring and alerts

---

Generated: November 11, 2025  
Status: ✅ **READY FOR IMPLEMENTATION**  
Approach: JWT Token Claims + Gateway Headers  
Security Level: ⭐⭐⭐⭐⭐

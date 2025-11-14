# Client Type Identification - Quick Reference

## 🎯 OVERVIEW

**Approach**: JWT Token Claims + Gateway Headers  
**Implementation Time**: ~1.5 days  
**Security Level**: ⭐⭐⭐⭐⭐

---

## 🔑 TOKEN STRUCTURE

### Customer Token
```json
{
  "user_id": "customer-id",
  "client_type": "customer",
  "roles": ["customer"],
  "exp": 1699977600
}
```

### Admin Token
```json
{
  "user_id": "admin-id",
  "client_type": "admin",
  "roles": ["admin", "customer_manager"],
  "exp": 1699920000
}
```

---

## 📋 HEADERS

Gateway adds these headers to all requests:

| Header | Description | Example |
|--------|-------------|---------|
| `X-User-ID` | User UUID | `550e8400-e29b-41d4-a716-446655440000` |
| `X-Client-Type` | Client type | `admin` or `customer` |
| `X-User-Roles` | Comma-separated roles | `admin,customer_manager` |
| `X-User-Permissions` | Comma-separated permissions | `read:customers,write:customers` |

---

## 💻 CODE SNIPPETS

### Auth Service - Generate Token

```go
// Customer token
token, err := uc.GenerateCustomerToken(
    userID,
    username,
    email,
    permissions,
)

// Admin token
token, err := uc.GenerateAdminToken(
    userID,
    username,
    email,
    roles,
    permissions,
)
```

### Gateway - Add Headers

```go
func (m *AuthMiddleware) Authenticate() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Validate token
        claims, err := m.validateToken(token)
        
        // Add headers
        c.Request.Header.Set("X-User-ID", claims.UserId)
        c.Request.Header.Set("X-Client-Type", claims.ClientType)
        c.Request.Header.Set("X-User-Roles", strings.Join(claims.Roles, ","))
        
        c.Next()
    }
}
```

### Gateway - Protect Routes

```go
// Customer routes
customer := r.Group("/api")
customer.Use(auth.Authenticate())
customer.Use(auth.RequireClientType("customer"))

// Admin routes
admin := r.Group("/admin")
admin.Use(auth.Authenticate())
admin.Use(auth.RequireClientType("admin"))
```

### Service - Extract Client Type

```go
// Helper function
func ExtractClientType(ctx context.Context) string {
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        if values := md.Get("x-client-type"); len(values) > 0 {
            return values[0]
        }
    }
    return "customer"
}

// Usage
func (s *Service) GetResource(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    clientType := ExtractClientType(ctx)
    userID := ExtractUserID(ctx)
    
    if clientType == "admin" {
        // Admin logic
    } else {
        // Customer logic
    }
}
```

---

## 🔐 AUTHORIZATION PATTERNS

### Pattern 1: Client Type Check
```go
if clientType == "admin" {
    // Admin can do anything
} else {
    // Customer has restrictions
}
```

### Pattern 2: Self-Access Check
```go
if userID != resourceOwnerID {
    return status.Error(codes.PermissionDenied, "Cannot access other user's data")
}
```

### Pattern 3: Admin-Only
```go
if !IsAdmin(ctx) {
    return status.Error(codes.PermissionDenied, "Admin access required")
}
```

### Pattern 4: Role-Based
```go
if !HasRole(ctx, "admin") && !HasRole(ctx, "customer_manager") {
    return status.Error(codes.PermissionDenied, "Insufficient role")
}
```

### Pattern 5: Permission-Based
```go
if !HasPermission(ctx, "write:customers") {
    return status.Error(codes.PermissionDenied, "Missing permission")
}
```

---

## 🧪 TESTING COMMANDS

### Customer Login
```bash
curl -X POST http://localhost:8080/api/auth/customer/login \
  -H "Content-Type: application/json" \
  -d '{"email":"customer@example.com","password":"password123"}'
```

### Admin Login
```bash
curl -X POST http://localhost:8080/api/auth/admin/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}'
```

### Customer Access Own Profile
```bash
curl -X GET http://localhost:8080/api/customers/me \
  -H "Authorization: Bearer <customer_token>"
```

### Admin Access All Customers
```bash
curl -X GET http://localhost:8080/admin/customers \
  -H "Authorization: Bearer <admin_token>"
```

---

## ✅ IMPLEMENTATION CHECKLIST

### Auth Service (2 hours)
- [ ] Add `ClientType` to TokenClaims
- [ ] Update `GenerateCustomerToken`
- [ ] Update `GenerateAdminToken`
- [ ] Update login endpoints

### Gateway (1 hour)
- [ ] Update auth middleware
- [ ] Add `X-Client-Type` header
- [ ] Add `RequireClientType` middleware
- [ ] Update routes

### Services (2 hours each)
- [ ] Create context helpers
- [ ] Update GetResource methods
- [ ] Update UpdateResource methods
- [ ] Update ListResources methods
- [ ] Add authorization checks

### Testing (2 hours)
- [ ] Test customer login
- [ ] Test admin login
- [ ] Test customer access
- [ ] Test admin access
- [ ] Test unauthorized access

---

## 📚 DOCUMENTATION

**Full Documentation**:
- `docs/architecture/CLIENT_TYPE_IDENTIFICATION.md` - Complete guide (includes implementation steps)
- `docs/CLIENT_TYPE_QUICK_REFERENCE.md` - This file (quick reference)

**Key Concepts**:
1. JWT token contains `client_type` field
2. Gateway validates token and adds headers
3. Services check headers for authorization
4. Multiple layers of security

**Benefits**:
- ✅ Clear separation of admin vs customer
- ✅ Centralized authentication
- ✅ Flexible authorization
- ✅ Easy to test
- ✅ Scalable

---

## 🎯 COMMON USE CASES

### Use Case 1: Customer Views Own Profile
```
Customer → Gateway (validate customer token) → Customer Service (check user_id) → Return profile
```

### Use Case 2: Admin Views Any Customer
```
Admin → Gateway (validate admin token) → Customer Service (check admin) → Return full profile
```

### Use Case 3: Customer Updates Own Profile
```
Customer → Gateway (validate customer token) → Customer Service (check user_id + limited fields) → Update
```

### Use Case 4: Admin Updates Any Customer
```
Admin → Gateway (validate admin token) → Customer Service (check admin + all fields) → Update
```

### Use Case 5: Customer Lists Own Orders
```
Customer → Gateway (validate customer token) → Order Service (filter by user_id) → Return orders
```

### Use Case 6: Admin Lists All Orders
```
Admin → Gateway (validate admin token) → Order Service (check admin) → Return all orders
```

---

## 🚨 COMMON ERRORS

### Error 1: Missing Authorization Header
```json
{
  "error": "Authorization header required"
}
```
**Solution**: Add `Authorization: Bearer <token>` header

### Error 2: Invalid Token
```json
{
  "error": "Invalid token"
}
```
**Solution**: Login again to get new token

### Error 3: Wrong Client Type
```json
{
  "error": "This endpoint requires admin access"
}
```
**Solution**: Use admin token for admin endpoints

### Error 4: Permission Denied
```json
{
  "error": "Cannot access other customer's data"
}
```
**Solution**: Customer can only access their own data

---

## 📞 SUPPORT

**Questions?**
- Check full documentation: `docs/architecture/CLIENT_TYPE_IDENTIFICATION.md` (includes implementation guide)
- Review code examples in documentation

**Issues?**
- Verify token contains `client_type` field
- Check gateway adds `X-Client-Type` header
- Verify service extracts header correctly
- Check authorization logic

---

Generated: November 11, 2025  
Version: 1.0  
Status: ✅ **READY TO USE**

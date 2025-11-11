# Auth Service Responsibility Analysis

## Vấn đề hiện tại

Auth Service đang làm **quá nhiều việc** (God Service anti-pattern):
- ❌ Register user (nên ở User/Customer Service)
- ❌ Manage user data (nên ở User/Customer Service)
- ❌ Email verification (nên ở User/Customer Service)
- ❌ Password reset (nên ở User/Customer Service)
- ✅ Generate JWT tokens (đúng)
- ✅ Validate tokens (đúng)
- ✅ Session management (đúng)

---

## 🎯 RECOMMENDED ARCHITECTURE

### Auth Service - Core Responsibilities (Token & Session Only)

**Auth Service chỉ nên làm**:
1. ✅ **Generate JWT tokens** (access + refresh)
2. ✅ **Validate JWT tokens**
3. ✅ **Refresh tokens**
4. ✅ **Session management** (create, validate, revoke)
5. ✅ **Revoke tokens/sessions**

**Auth Service KHÔNG nên làm**:
- ❌ User registration
- ❌ User data management
- ❌ Password management
- ❌ Email verification
- ❌ User profile operations

---

## 📐 NEW ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENTS                                  │
├──────────────────────────────┬──────────────────────────────────┤
│   Frontend (Customer)        │   Admin (Internal User)          │
└──────────────────────────────┴──────────────────────────────────┘
                 │                              │
                 ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API GATEWAY                                 │
└─────────────────────────────────────────────────────────────────┘
                 │                              │
                 ▼                              ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│   CUSTOMER SERVICE       │    │   USER SERVICE           │
│                          │    │                          │
│   ✅ Register            │    │   ✅ Register            │
│   ✅ Login               │    │   ✅ Login               │
│   ✅ Forgot Password     │    │   ✅ Change Password     │
│   ✅ Reset Password      │    │   ✅ Manage Users        │
│   ✅ Verify Email        │    │   ✅ Manage Roles        │
│   ✅ Update Profile      │    │   ✅ Permissions         │
│                          │    │                          │
│   Calls Auth Service ↓   │    │   Calls Auth Service ↓   │
└──────────────────────────┘    └──────────────────────────┘
                 │                              │
                 └──────────────┬───────────────┘
                                ▼
                    ┌───────────────────────┐
                    │   AUTH SERVICE        │
                    │   (Token & Session)   │
                    │                       │
                    │   ✅ Generate JWT     │
                    │   ✅ Validate JWT     │
                    │   ✅ Refresh Token    │
                    │   ✅ Session CRUD     │
                    │   ✅ Revoke Session   │
                    └───────────────────────┘
```

---

## 🔧 AUTH SERVICE - NEW API

### Minimal & Focused API

```protobuf
service AuthService {
  // Token Operations
  rpc GenerateToken (GenerateTokenRequest) returns (GenerateTokenReply);
  rpc ValidateToken (ValidateTokenRequest) returns (ValidateTokenReply);
  rpc RefreshToken (RefreshTokenRequest) returns (RefreshTokenReply);
  rpc RevokeToken (RevokeTokenRequest) returns (RevokeTokenReply);
  
  // Session Operations
  rpc CreateSession (CreateSessionRequest) returns (CreateSessionReply);
  rpc GetSession (GetSessionRequest) returns (GetSessionReply);
  rpc GetUserSessions (GetUserSessionsRequest) returns (GetUserSessionsReply);
  rpc RevokeSession (RevokeSessionRequest) returns (RevokeSessionReply);
  rpc RevokeUserSessions (RevokeUserSessionsRequest) returns (RevokeUserSessionsReply);
  
  // Health & Monitoring
  rpc HealthCheck (HealthCheckRequest) returns (HealthCheckReply);
}

// Generate Token (called by User/Customer Service after successful login)
message GenerateTokenRequest {
  string user_id = 1;
  string user_type = 2;  // "customer" or "admin"
  map<string, string> claims = 3;  // Additional claims (email, roles, etc.)
  string device_info = 4;
  string ip_address = 5;
}

message GenerateTokenReply {
  string access_token = 1;
  string refresh_token = 2;
  string session_id = 3;
  google.protobuf.Timestamp expires_at = 4;
}

// Validate Token (called by Gateway or services)
message ValidateTokenRequest {
  string token = 1;
}

message ValidateTokenReply {
  bool valid = 1;
  string user_id = 2;
  string user_type = 3;
  string session_id = 4;
  map<string, string> claims = 5;
  google.protobuf.Timestamp expires_at = 6;
}

// Refresh Token
message RefreshTokenRequest {
  string refresh_token = 1;
}

message RefreshTokenReply {
  string access_token = 1;
  string refresh_token = 2;
  google.protobuf.Timestamp expires_at = 3;
}

// Revoke Token
message RevokeTokenRequest {
  string token = 1;
}

message RevokeTokenReply {
  bool success = 1;
  string message = 2;
}

// Session Operations
message CreateSessionRequest {
  string user_id = 1;
  string user_type = 2;
  string device_info = 3;
  string ip_address = 4;
}

message CreateSessionReply {
  string session_id = 1;
  google.protobuf.Timestamp created_at = 2;
}

message GetSessionRequest {
  string session_id = 1;
}

message GetSessionReply {
  Session session = 1;
}

message GetUserSessionsRequest {
  string user_id = 1;
}

message GetUserSessionsReply {
  repeated Session sessions = 1;
}

message RevokeSessionRequest {
  string session_id = 1;
}

message RevokeSessionReply {
  bool success = 1;
  string message = 2;
}

message RevokeUserSessionsRequest {
  string user_id = 1;
  string reason = 2;
}

message RevokeUserSessionsReply {
  bool success = 1;
  int32 sessions_revoked = 2;
}

message Session {
  string id = 1;
  string user_id = 2;
  string user_type = 3;
  string device_info = 4;
  string ip_address = 5;
  google.protobuf.Timestamp created_at = 6;
  google.protobuf.Timestamp last_accessed = 7;
  bool is_active = 8;
}
```

---

## 🏗️ CUSTOMER SERVICE - NEW ENDPOINTS

### Customer Service handles all customer auth flows

```protobuf
service CustomerService {
  // Authentication
  rpc Register (RegisterCustomerRequest) returns (RegisterCustomerReply);
  rpc Login (LoginCustomerRequest) returns (LoginCustomerReply);
  rpc Logout (LogoutCustomerRequest) returns (LogoutCustomerReply);
  
  // Password Management
  rpc ForgotPassword (ForgotPasswordRequest) returns (ForgotPasswordReply);
  rpc ResetPassword (ResetPasswordRequest) returns (ResetPasswordReply);
  rpc ChangePassword (ChangePasswordRequest) returns (ChangePasswordReply);
  
  // Email Verification
  rpc VerifyEmail (VerifyEmailRequest) returns (VerifyEmailReply);
  rpc ResendVerification (ResendVerificationRequest) returns (ResendVerificationReply);
  
  // Profile
  rpc GetProfile (GetProfileRequest) returns (GetProfileReply);
  rpc UpdateProfile (UpdateProfileRequest) returns (UpdateProfileReply);
  
  // ... other customer operations
}
```

### Customer Login Flow (New)

```go
// customer/internal/biz/auth/auth.go
func (uc *AuthUsecase) Login(ctx context.Context, email, password string) (*LoginResponse, error) {
    // 1. Validate credentials
    customer, err := uc.customerRepo.FindByEmail(ctx, email)
    if err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 2. Check password
    if err := uc.verifyPassword(customer.PasswordHash, password); err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 3. Check customer status
    if customer.Status != constants.CustomerStatusActive {
        return nil, ErrCustomerInactive
    }
    
    // 4. Call Auth Service to generate tokens
    tokenReq := &authpb.GenerateTokenRequest{
        UserId:     customer.ID.String(),
        UserType:   "customer",
        Claims: map[string]string{
            "email":         customer.Email,
            "firstName":     customer.FirstName,
            "lastName":      customer.LastName,
            "customerType":  customer.CustomerType.String(),
            "emailVerified": strconv.FormatBool(customer.EmailVerified),
        },
        DeviceInfo: req.DeviceInfo,
        IpAddress:  req.IpAddress,
    }
    
    tokenResp, err := uc.authClient.GenerateToken(ctx, tokenReq)
    if err != nil {
        return nil, fmt.Errorf("failed to generate token: %w", err)
    }
    
    // 5. Update last login
    customer.LastLoginAt = time.Now()
    uc.customerRepo.Update(ctx, customer, nil)
    
    // 6. Publish event
    if uc.events != nil {
        uc.events.PublishCustomerLoggedIn(ctx, customer)
    }
    
    return &LoginResponse{
        AccessToken:  tokenResp.AccessToken,
        RefreshToken: tokenResp.RefreshToken,
        ExpiresAt:    tokenResp.ExpiresAt,
        Customer:     customer,
    }, nil
}
```

### Customer Register Flow (New)

```go
// customer/internal/biz/auth/auth.go
func (uc *AuthUsecase) Register(ctx context.Context, req *RegisterRequest) (*Customer, error) {
    // 1. Validate input
    if !validation.IsValidEmail(req.Email) {
        return nil, ErrInvalidEmail
    }
    
    // 2. Check if customer exists
    existing, _ := uc.customerRepo.FindByEmail(ctx, req.Email)
    if existing != nil {
        return nil, ErrCustomerAlreadyExists
    }
    
    // 3. Hash password
    passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        return nil, err
    }
    
    // 4. Create customer in transaction
    var customer *model.Customer
    err = uc.transaction(ctx, func(ctx context.Context) error {
        customer = &model.Customer{
            Email:              req.Email,
            PasswordHash:       string(passwordHash),
            FirstName:          req.FirstName,
            LastName:           req.LastName,
            CustomerType:       constants.CustomerTypeRetail,
            Status:             constants.CustomerStatusPending, // Pending until email verified
            EmailVerified:      false,
            RegistrationSource: req.Source,
        }
        
        if err := uc.customerRepo.Create(ctx, customer); err != nil {
            return err
        }
        
        // Create profile
        profile := &model.CustomerProfile{
            CustomerID: customer.ID,
            Phone:      req.Phone,
        }
        if err := uc.profileRepo.Create(ctx, profile); err != nil {
            return err
        }
        
        return nil
    })
    
    if err != nil {
        return nil, err
    }
    
    // 5. Send verification email (async)
    go uc.sendVerificationEmail(context.Background(), customer)
    
    // 6. Publish event
    if uc.events != nil {
        uc.events.PublishCustomerRegistered(ctx, customer)
    }
    
    return customer, nil
}
```

---

## 🏗️ USER SERVICE - NEW ENDPOINTS

### User Service handles all admin auth flows

```protobuf
service UserService {
  // Authentication
  rpc Login (LoginUserRequest) returns (LoginUserReply);
  rpc Logout (LogoutUserRequest) returns (LogoutUserReply);
  
  // Password Management
  rpc ChangePassword (ChangePasswordRequest) returns (ChangePasswordReply);
  rpc ResetPassword (ResetPasswordRequest) returns (ResetPasswordReply);
  
  // User Management
  rpc CreateUser (CreateUserRequest) returns (CreateUserReply);
  rpc GetUser (GetUserRequest) returns (GetUserReply);
  rpc UpdateUser (UpdateUserRequest) returns (UpdateUserReply);
  rpc DeleteUser (DeleteUserRequest) returns (DeleteUserReply);
  rpc ListUsers (ListUsersRequest) returns (ListUsersReply);
  
  // Role & Permission
  rpc AssignRole (AssignRoleRequest) returns (AssignRoleReply);
  rpc RevokeRole (RevokeRoleRequest) returns (RevokeRoleReply);
  rpc GetUserRoles (GetUserRolesRequest) returns (GetUserRolesReply);
  rpc GetUserPermissions (GetUserPermissionsRequest) returns (GetUserPermissionsReply);
  
  // ... other user operations
}
```

### User Login Flow (New)

```go
// user/internal/biz/auth/auth.go
func (uc *AuthUsecase) Login(ctx context.Context, username, password string) (*LoginResponse, error) {
    // 1. Validate credentials
    user, err := uc.userRepo.FindByUsername(ctx, username)
    if err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 2. Check password
    if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 3. Check user status
    if user.Status != UserStatusActive {
        return nil, ErrUserInactive
    }
    
    // 4. Get user roles and permissions
    roles, err := uc.roleRepo.GetUserRoles(ctx, user.ID)
    if err != nil {
        return nil, err
    }
    
    permissions, err := uc.permissionRepo.GetUserPermissions(ctx, user.ID)
    if err != nil {
        return nil, err
    }
    
    // 5. Call Auth Service to generate tokens
    tokenReq := &authpb.GenerateTokenRequest{
        UserId:   user.ID,
        UserType: "admin",
        Claims: map[string]string{
            "username":   user.Username,
            "email":      user.Email,
            "firstName":  user.FirstName,
            "lastName":   user.LastName,
            "department": user.Department,
            "roles":      strings.Join(roleNames(roles), ","),
            "permissions": strings.Join(permissionNames(permissions), ","),
        },
        DeviceInfo: req.DeviceInfo,
        IpAddress:  req.IpAddress,
    }
    
    tokenResp, err := uc.authClient.GenerateToken(ctx, tokenReq)
    if err != nil {
        return nil, fmt.Errorf("failed to generate token: %w", err)
    }
    
    // 6. Update last login
    user.LastLoginAt = time.Now()
    uc.userRepo.Update(ctx, user)
    
    // 7. Publish event
    if uc.events != nil {
        uc.events.PublishUserLoggedIn(ctx, user)
    }
    
    return &LoginResponse{
        AccessToken:  tokenResp.AccessToken,
        RefreshToken: tokenResp.RefreshToken,
        ExpiresAt:    tokenResp.ExpiresAt,
        User:         user,
        Roles:        roles,
        Permissions:  permissions,
    }, nil
}
```

---

## 📊 COMPARISON

### Before (Current - Wrong)

| Operation | Auth Service | Customer Service | User Service |
|-----------|--------------|------------------|--------------|
| Register | ✅ Does it | ❌ Should do it | ❌ Should do it |
| Login | ✅ Does it | ❌ Should do it | ❌ Should do it |
| Password Reset | ✅ Does it | ❌ Should do it | ❌ Should do it |
| Email Verify | ✅ Does it | ❌ Should do it | N/A |
| Generate JWT | ✅ Correct | ❌ Missing | ❌ Missing |
| Validate JWT | ✅ Correct | N/A | N/A |

**Problems**:
- 🔴 Auth Service is a God Service
- 🔴 Customer/User Services can't customize auth logic
- 🔴 Tight coupling
- 🔴 Hard to scale independently

---

### After (Recommended - Correct)

| Operation | Auth Service | Customer Service | User Service |
|-----------|--------------|------------------|--------------|
| Register | ❌ | ✅ Does it | ✅ Does it |
| Login | ❌ | ✅ Does it | ✅ Does it |
| Password Reset | ❌ | ✅ Does it | ✅ Does it |
| Email Verify | ❌ | ✅ Does it | N/A |
| Generate JWT | ✅ Provides API | ✅ Calls Auth | ✅ Calls Auth |
| Validate JWT | ✅ Provides API | N/A | N/A |
| Session Mgmt | ✅ Provides API | ✅ Calls Auth | ✅ Calls Auth |

**Benefits**:
- ✅ Single Responsibility Principle
- ✅ Each service owns its domain
- ✅ Loose coupling
- ✅ Easy to scale
- ✅ Easy to customize

---

## 🔄 MIGRATION PLAN

### Phase 1: Add new Auth Service API (Week 1)
1. Add `GenerateToken` endpoint
2. Add `ValidateToken` endpoint (already exists)
3. Add `CreateSession` endpoint
4. Keep old endpoints for backward compatibility

### Phase 2: Implement Customer Service Auth (Week 2)
1. Add `Register` endpoint to Customer Service
2. Add `Login` endpoint to Customer Service
3. Add `ForgotPassword` / `ResetPassword` endpoints
4. Add `VerifyEmail` endpoint
5. Integrate with Auth Service for token generation

### Phase 3: Implement User Service Auth (Week 2)
1. Add `Login` endpoint to User Service
2. Add `ChangePassword` endpoint
3. Integrate with Auth Service for token generation
4. Add role/permission loading

### Phase 4: Update Gateway (Week 3)
1. Route `/api/customer/auth/*` to Customer Service
2. Route `/api/admin/auth/*` to User Service
3. Update token validation to call Auth Service

### Phase 5: Deprecate old Auth Service endpoints (Week 4)
1. Mark old endpoints as deprecated
2. Monitor usage
3. Remove after migration complete

---

## ✅ BENEFITS OF NEW ARCHITECTURE

### 1. Single Responsibility
- Auth Service: Token & Session only
- Customer Service: Customer domain
- User Service: User domain

### 2. Loose Coupling
- Services communicate via well-defined APIs
- Easy to change implementation

### 3. Scalability
- Scale Auth Service independently (high token validation load)
- Scale Customer/User Services independently (high registration load)

### 4. Flexibility
- Customer Service can add custom registration logic
- User Service can add custom role/permission logic
- Auth Service stays simple and focused

### 5. Maintainability
- Clear boundaries
- Easy to test
- Easy to understand

---

## 🎯 FINAL RECOMMENDATION

**Auth Service should ONLY do**:
```
✅ Generate JWT tokens
✅ Validate JWT tokens  
✅ Refresh tokens
✅ Manage sessions
✅ Revoke tokens/sessions
```

**Customer/User Services should do**:
```
✅ Register
✅ Login (validate credentials)
✅ Password management
✅ Email verification
✅ Profile management
✅ Call Auth Service for token generation
```

This follows **microservices best practices** and **domain-driven design** principles!

---

Generated: 2025-11-10

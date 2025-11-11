# Authentication Implementation Checklist

## 📋 OVERVIEW

Checklist để implement authentication architecture mới với:
- Auth Service: Token & Session only
- Customer Service: Customer authentication
- User Service: Admin authentication

**Estimated Time**: 4 tuần (160 hours)
**Team Size**: 2-3 developers

---

## 🎯 PHASE 1: AUTH SERVICE REFACTORING (Week 1)

### 1.1. Design New API (Day 1 - 4 hours)

- [ ] Review current auth.proto
- [ ] Design new minimal auth.proto
- [ ] Document API changes
- [ ] Get team approval

**Files to create/modify**:
```
auth/api/auth/v1/auth_v2.proto  (new minimal API)
docs/auth-service-api-v2.md     (documentation)
```

---

### 1.2. Implement GenerateToken Endpoint (Day 1-2 - 8 hours)

- [ ] Create `GenerateTokenRequest` proto message
- [ ] Create `GenerateTokenReply` proto message
- [ ] Implement `GenerateToken` in auth usecase
- [ ] Implement `GenerateToken` in auth service
- [ ] Add unit tests
- [ ] Add integration tests

**Files to create/modify**:
```
auth/api/auth/v1/auth_v2.proto
auth/internal/biz/token/token.go           (new)
auth/internal/service/token_service.go     (new)
auth/internal/biz/token/token_test.go      (new)
```

**Code Template**:
```go
// auth/internal/biz/token/token.go
func (uc *TokenUsecase) GenerateToken(ctx context.Context, req *GenerateTokenRequest) (*GenerateTokenResponse, error) {
    // 1. Validate request
    if req.UserID == "" || req.UserType == "" {
        return nil, ErrInvalidRequest
    }
    
    // 2. Create session
    session, err := uc.sessionRepo.CreateSession(ctx, &Session{
        UserID:     req.UserID,
        UserType:   req.UserType,
        DeviceInfo: req.DeviceInfo,
        IPAddress:  req.IPAddress,
    })
    if err != nil {
        return nil, err
    }
    
    // 3. Generate JWT with custom claims
    accessToken, err := uc.generateAccessToken(req.UserID, req.UserType, session.ID, req.Claims)
    if err != nil {
        return nil, err
    }
    
    refreshToken, err := uc.generateRefreshToken(req.UserID, req.UserType, session.ID)
    if err != nil {
        return nil, err
    }
    
    return &GenerateTokenResponse{
        AccessToken:  accessToken,
        RefreshToken: refreshToken,
        SessionID:    session.ID,
        ExpiresAt:    time.Now().Add(uc.accessTokenTTL),
    }, nil
}
```

**Testing**:
```bash
# Unit test
cd auth/internal/biz/token
go test -v

# Integration test
cd auth
go test -v ./test/integration/token_test.go
```

---

### 1.3. Update ValidateToken Endpoint (Day 2 - 4 hours)

- [ ] Update `ValidateTokenReply` to include user_type and claims
- [ ] Modify validation logic to support custom claims
- [ ] Update unit tests
- [ ] Update integration tests

**Files to modify**:
```
auth/api/auth/v1/auth_v2.proto
auth/internal/biz/token/token.go
auth/internal/service/token_service.go
```

---

### 1.4. Implement Session Management (Day 3 - 8 hours)

- [ ] Create `CreateSession` endpoint
- [ ] Create `GetSession` endpoint
- [ ] Create `GetUserSessions` endpoint
- [ ] Create `RevokeSession` endpoint
- [ ] Create `RevokeUserSessions` endpoint
- [ ] Add unit tests
- [ ] Add integration tests

**Files to create/modify**:
```
auth/internal/biz/session/session.go       (new)
auth/internal/service/session_service.go   (new)
auth/internal/biz/session/session_test.go  (new)
```

---

### 1.5. Mark Old Endpoints as Deprecated (Day 4 - 2 hours)

- [ ] Add `deprecated = true` to old proto endpoints
- [ ] Add deprecation warnings in code
- [ ] Update documentation
- [ ] Notify team

**Files to modify**:
```
auth/api/auth/v1/auth.proto
auth/internal/service/auth.go
docs/DEPRECATION_NOTICE.md  (new)
```

---

### 1.6. Deploy & Test Auth Service (Day 5 - 8 hours)

- [ ] Build Docker image
- [ ] Deploy to dev environment
- [ ] Run smoke tests
- [ ] Test new endpoints with Postman/curl
- [ ] Monitor logs and metrics
- [ ] Fix any issues

**Commands**:
```bash
# Build
cd auth
docker build -t auth-service:v2 .

# Deploy
docker-compose up -d auth

# Test
curl -X POST http://localhost:8081/v1/auth/generate-token \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-id",
    "user_type": "customer",
    "claims": {"email": "test@example.com"}
  }'
```

---

## 🎯 PHASE 2: CUSTOMER SERVICE AUTH (Week 2)

### 2.1. Setup Auth Module in Customer Service (Day 1 - 4 hours)

- [ ] Create auth package structure
- [ ] Add Auth Service client
- [ ] Add auth configuration
- [ ] Setup dependencies

**Files to create**:
```
customer/internal/biz/auth/
customer/internal/biz/auth/auth.go
customer/internal/biz/auth/provider.go
customer/internal/client/auth_client.go
customer/configs/auth.yaml
```

**Directory Structure**:
```
customer/internal/
├── biz/
│   ├── auth/
│   │   ├── auth.go          # Auth usecase
│   │   ├── dto.go           # Request/Response DTOs
│   │   ├── provider.go      # Wire provider
│   │   └── auth_test.go     # Tests
│   └── customer/
│       └── customer.go
├── client/
│   └── auth_client.go       # Auth service gRPC client
└── service/
    └── auth_service.go      # Auth HTTP/gRPC service
```

---

### 2.2. Implement Customer Register (Day 1-2 - 8 hours)

- [ ] Create `RegisterCustomer` proto endpoint
- [ ] Implement register usecase
- [ ] Add email validation
- [ ] Add password hashing
- [ ] Add uniqueness check
- [ ] Create customer + profile + preferences in transaction
- [ ] Send verification email (async)
- [ ] Publish customer.registered event
- [ ] Add unit tests
- [ ] Add integration tests

**Files to create/modify**:
```
customer/api/customer/v1/auth.proto         (new)
customer/internal/biz/auth/auth.go
customer/internal/service/auth_service.go   (new)
```

**Code Template**:
```go
// customer/internal/biz/auth/auth.go
func (uc *AuthUsecase) Register(ctx context.Context, req *RegisterRequest) (*Customer, error) {
    uc.log.WithContext(ctx).Infof("Registering customer: %s", req.Email)
    
    // 1. Validate
    if !validation.IsValidEmail(req.Email) {
        return nil, errors.NewValidationError("invalid email format")
    }
    
    // 2. Check uniqueness
    existing, _ := uc.customerRepo.FindByEmail(ctx, req.Email)
    if existing != nil {
        return nil, errors.NewConflictError("email already exists")
    }
    
    // 3. Hash password
    passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        return nil, err
    }
    
    // 4. Create in transaction
    var customer *model.Customer
    err = uc.transaction(ctx, func(ctx context.Context) error {
        customer = &model.Customer{
            Email:              req.Email,
            PasswordHash:       string(passwordHash),
            FirstName:          req.FirstName,
            LastName:           req.LastName,
            Status:             constants.CustomerStatusPending,
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
        
        // Create preferences
        preferences := &model.CustomerPreferences{
            CustomerID: customer.ID,
        }
        if err := uc.preferencesRepo.Create(ctx, preferences); err != nil {
            return err
        }
        
        return nil
    })
    
    if err != nil {
        return nil, err
    }
    
    // 5. Send verification email (async)
    go uc.emailService.SendVerificationEmail(context.Background(), customer)
    
    // 6. Publish event
    if uc.events != nil {
        uc.events.PublishCustomerRegistered(ctx, customer)
    }
    
    return customer, nil
}
```

**Testing Checklist**:
- [ ] Test with valid data
- [ ] Test with invalid email
- [ ] Test with duplicate email
- [ ] Test with weak password
- [ ] Test transaction rollback
- [ ] Test email sending
- [ ] Test event publishing

---

### 2.3. Implement Customer Login (Day 2-3 - 8 hours)

- [ ] Create `LoginCustomer` proto endpoint
- [ ] Implement login usecase
- [ ] Validate email + password
- [ ] Check customer status
- [ ] Call Auth Service to generate tokens
- [ ] Update last login timestamp
- [ ] Publish customer.logged_in event
- [ ] Add unit tests
- [ ] Add integration tests

**Code Template**:
```go
// customer/internal/biz/auth/auth.go
func (uc *AuthUsecase) Login(ctx context.Context, req *LoginRequest) (*LoginResponse, error) {
    uc.log.WithContext(ctx).Infof("Customer login: %s", req.Email)
    
    // 1. Find customer
    customer, err := uc.customerRepo.FindByEmail(ctx, req.Email)
    if err != nil {
        return nil, errors.NewAuthenticationError("invalid credentials")
    }
    
    // 2. Verify password
    if err := bcrypt.CompareHashAndPassword([]byte(customer.PasswordHash), []byte(req.Password)); err != nil {
        return nil, errors.NewAuthenticationError("invalid credentials")
    }
    
    // 3. Check status
    if customer.Status != constants.CustomerStatusActive {
        return nil, errors.NewAuthorizationError("customer account is not active")
    }
    
    // 4. Generate tokens via Auth Service
    tokenReq := &authpb.GenerateTokenRequest{
        UserId:   customer.ID.String(),
        UserType: "customer",
        Claims: map[string]string{
            "email":         customer.Email,
            "firstName":     customer.FirstName,
            "lastName":      customer.LastName,
            "customerType":  customer.CustomerType.String(),
            "emailVerified": strconv.FormatBool(customer.EmailVerified),
        },
        DeviceInfo: req.DeviceInfo,
        IpAddress:  req.IPAddress,
    }
    
    tokenResp, err := uc.authClient.GenerateToken(ctx, tokenReq)
    if err != nil {
        return nil, fmt.Errorf("failed to generate token: %w", err)
    }
    
    // 5. Update last login
    now := time.Now()
    customer.LastLoginAt = &now
    uc.customerRepo.Update(ctx, customer, nil)
    
    // 6. Publish event
    if uc.events != nil {
        uc.events.PublishCustomerLoggedIn(ctx, customer)
    }
    
    return &LoginResponse{
        AccessToken:  tokenResp.AccessToken,
        RefreshToken: tokenResp.RefreshToken,
        ExpiresAt:    tokenResp.ExpiresAt.AsTime(),
        Customer:     customer,
    }, nil
}
```

**Testing Checklist**:
- [ ] Test successful login
- [ ] Test invalid email
- [ ] Test invalid password
- [ ] Test inactive customer
- [ ] Test unverified email (if required)
- [ ] Test Auth Service integration
- [ ] Test event publishing

---

### 2.4. Implement Password Management (Day 3-4 - 8 hours)

- [ ] Implement `ForgotPassword` endpoint
- [ ] Implement `ResetPassword` endpoint
- [ ] Implement `ChangePassword` endpoint
- [ ] Generate reset tokens
- [ ] Send reset emails
- [ ] Validate reset tokens
- [ ] Add unit tests
- [ ] Add integration tests

**Files to create/modify**:
```
customer/internal/biz/auth/password.go
customer/internal/service/auth_service.go
```

---

### 2.5. Implement Email Verification (Day 4 - 4 hours)

- [ ] Implement `VerifyEmail` endpoint
- [ ] Implement `ResendVerification` endpoint
- [ ] Generate verification tokens
- [ ] Send verification emails
- [ ] Update customer status after verification
- [ ] Add unit tests

---

### 2.6. Deploy & Test Customer Service (Day 5 - 8 hours)

- [ ] Build Docker image
- [ ] Deploy to dev environment
- [ ] Test register flow
- [ ] Test login flow
- [ ] Test password reset flow
- [ ] Test email verification flow
- [ ] Monitor logs and metrics
- [ ] Fix any issues

**Test Commands**:
```bash
# Register
curl -X POST http://localhost:8083/api/v1/customers/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+84901234567"
  }'

# Login
curl -X POST http://localhost:8083/api/v1/customers/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!"
  }'
```

---

## 🎯 PHASE 3: USER SERVICE AUTH (Week 3)

### ⚠️ CRITICAL: User Service Validation Fixes

**Before implementing auth, we MUST fix existing CreateUser/UpdateUser logic!**

Reference: `USER_LOGIC_REVIEW.md` - Section 5: RECOMMENDED FIXES

**Critical Issues to Fix**:
1. 🔴 No email validation in CreateUser
2. 🔴 No uniqueness checks (username/email)
3. 🔴 No transaction for user + roles
4. 🔴 No validation in UpdateUser
5. 🔴 Missing Username field in UpdateUser
6. 🔴 No cache invalidation
7. 🔴 No event publishing

---

### 3.1. Setup Auth Module in User Service (Day 1 - 4 hours)

- [ ] Create auth package structure
- [ ] Add Auth Service client
- [ ] Add auth configuration
- [ ] Setup dependencies
- [ ] Add validation helper import
- [ ] Add cache helper (optional)
- [ ] Add event publisher (optional)

**Files to create**:
```
user/internal/biz/auth/
user/internal/biz/auth/auth.go
user/internal/biz/auth/provider.go
user/internal/client/auth_client.go
user/configs/auth.yaml
```

**Dependencies to add**:
```go
import (
    "gitlab.com/ta-microservices/common/utils/validation"
    "gitlab.com/ta-microservices/common/utils/transaction"
    // Optional:
    "gitlab.com/ta-microservices/common/utils/cache"
    "gitlab.com/ta-microservices/common/events"
)
```

---

### 3.2. Fix User CreateUser Logic (Day 1 - 8 hours)

**CRITICAL FIXES from USER_LOGIC_REVIEW.md**:

- [ ] Add email validation (IsValidEmail)
- [ ] Add username uniqueness check
- [ ] Add email uniqueness check
- [ ] Add required field validation (username, email, password)
- [ ] Wrap user creation + role assignment in transaction
- [ ] Add cache support (SetUser after creation)
- [ ] Add event publishing (PublishUserCreated)
- [ ] Add unit tests for all validations
- [ ] Add integration tests

**Code Changes**:
```
user/internal/biz/user/user.go:200  (CreateUser method)
- Add validation.IsValidEmail(user.Email)
- Add userRepo.FindByUsername uniqueness check
- Add userRepo.FindByEmail uniqueness check
- Wrap in transaction
- Add cache.SetUser
- Add events.PublishUserCreated
```

**Testing Checklist**:
- [ ] Test with duplicate username fails
- [ ] Test with duplicate email fails
- [ ] Test with invalid email fails
- [ ] Test without username fails
- [ ] Test without email fails
- [ ] Test without password fails
- [ ] Test transaction rollback on role assignment failure

---

### 3.3. Fix User UpdateUser Logic (Day 2 - 8 hours)

**CRITICAL FIXES from USER_LOGIC_REVIEW.md**:

- [ ] Add existence check (FindByID before update)
- [ ] Add email format validation if changed
- [ ] Add email uniqueness check if changed
- [ ] Add username uniqueness check if changed
- [ ] Track changes for event publishing
- [ ] Add cache invalidation
- [ ] Add cache re-population
- [ ] Add event publishing with changes
- [ ] Add Username field to UpdateUserRequest proto
- [ ] Add unit tests for all validations
- [ ] Add integration tests

**Code Changes**:
```
user/api/user/v1/user.proto  (Add username to UpdateUserRequest)
user/internal/biz/user/user.go:253  (UpdateUser method)
user/internal/service/user.go:129  (UpdateUser service)
- Add userRepo.FindByID existence check
- Add validation.IsValidEmail if email changed
- Add uniqueness checks for email/username
- Track changes map
- Add cache.InvalidateUser + cache.SetUser
- Add events.PublishUserUpdated with changes
```

**Testing Checklist**:
- [ ] Test update non-existent user fails
- [ ] Test update to duplicate username fails
- [ ] Test update to duplicate email fails
- [ ] Test update with invalid email fails
- [ ] Test can update username
- [ ] Test can update email
- [ ] Test password is not cleared on update
- [ ] Test cache is invalidated
- [ ] Test event is published with changes

---

### 3.4. Implement User Login (Day 3 - 8 hours)

- [ ] Create `LoginUser` proto endpoint
- [ ] Implement login usecase
- [ ] Validate username + password
- [ ] Check user status
- [ ] Load user roles
- [ ] Load user permissions
- [ ] Call Auth Service to generate tokens (with roles/permissions)
- [ ] Update last login timestamp
- [ ] Publish user.logged_in event
- [ ] Add unit tests
- [ ] Add integration tests

**Code Template**:
```go
// user/internal/biz/auth/auth.go
func (uc *AuthUsecase) Login(ctx context.Context, req *LoginRequest) (*LoginResponse, error) {
    uc.log.WithContext(ctx).Infof("User login: %s", req.Username)
    
    // 1. Find user
    user, err := uc.userRepo.FindByUsername(ctx, req.Username)
    if err != nil {
        return nil, errors.NewAuthenticationError("invalid credentials")
    }
    
    // 2. Verify password
    if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
        return nil, errors.NewAuthenticationError("invalid credentials")
    }
    
    // 3. Check status
    if user.Status != UserStatusActive {
        return nil, errors.NewAuthorizationError("user account is not active")
    }
    
    // 4. Load roles
    roles, err := uc.roleRepo.GetUserRoles(ctx, user.ID)
    if err != nil {
        return nil, err
    }
    
    // 5. Load permissions
    permissions, err := uc.permissionRepo.GetUserPermissions(ctx, user.ID)
    if err != nil {
        return nil, err
    }
    
    // 6. Generate tokens via Auth Service
    tokenReq := &authpb.GenerateTokenRequest{
        UserId:   user.ID,
        UserType: "admin",
        Claims: map[string]string{
            "username":    user.Username,
            "email":       user.Email,
            "firstName":   user.FirstName,
            "lastName":    user.LastName,
            "department":  user.Department,
            "roles":       strings.Join(extractRoleNames(roles), ","),
            "permissions": strings.Join(extractPermissionNames(permissions), ","),
        },
        DeviceInfo: req.DeviceInfo,
        IpAddress:  req.IPAddress,
    }
    
    tokenResp, err := uc.authClient.GenerateToken(ctx, tokenReq)
    if err != nil {
        return nil, fmt.Errorf("failed to generate token: %w", err)
    }
    
    // 7. Update last login
    user.LastLoginAt = time.Now().Unix()
    uc.userRepo.Update(ctx, user)
    
    // 8. Publish event
    if uc.events != nil {
        uc.events.PublishUserLoggedIn(ctx, user)
    }
    
    return &LoginResponse{
        AccessToken:  tokenResp.AccessToken,
        RefreshToken: tokenResp.RefreshToken,
        ExpiresAt:    tokenResp.ExpiresAt.AsTime(),
        User:         user,
        Roles:        roles,
        Permissions:  permissions,
    }, nil
}
```

---

### 3.5. Implement Password Management (Day 4 - 8 hours)

- [ ] Implement `ChangePassword` endpoint
- [ ] Implement `ResetPassword` endpoint (admin reset)
- [ ] Revoke all sessions after password change
- [ ] Add unit tests
- [ ] Add integration tests

---

### 3.6. Implement Session Management (Day 4 - 4 hours)

- [ ] Implement `GetMySessions` endpoint
- [ ] Implement `RevokeSession` endpoint
- [ ] Integrate with Auth Service session APIs
- [ ] Add unit tests

---

### 3.7. Deploy & Test User Service (Day 5 - 8 hours)

- [ ] Build Docker image
- [ ] Deploy to dev environment
- [ ] Test login flow
- [ ] Test password change flow
- [ ] Test session management
- [ ] Monitor logs and metrics
- [ ] Fix any issues

---

## 🎯 PHASE 4: GATEWAY & FRONTEND INTEGRATION (Week 4)

### 4.1. Update Gateway Routing (Day 1 - 4 hours)

- [ ] Add route `/api/customer/auth/*` → Customer Service
- [ ] Add route `/api/admin/auth/*` → User Service
- [ ] Update auth middleware
- [ ] Add token validation via Auth Service
- [ ] Add CORS configuration
- [ ] Test routing

**Files to modify**:
```
gateway/configs/gateway-routes.yaml
gateway/internal/middleware/auth.go
gateway/internal/router/router.go
```

**Configuration**:
```yaml
# gateway/configs/gateway-routes.yaml
routes:
  # Customer auth routes
  - path: /api/customer/auth/*
    service: customer-service
    host: customer:8083
    auth_required: false  # Login/register are public
    strip_prefix: /api/customer
    
  # Admin auth routes
  - path: /api/admin/auth/*
    service: user-service
    host: user:8082
    auth_required: false  # Login is public
    strip_prefix: /api/admin
    
  # Customer protected routes
  - path: /api/customer/*
    service: customer-service
    host: customer:8083
    auth_required: true
    auth_type: customer
    strip_prefix: /api/customer
    
  # Admin protected routes
  - path: /api/admin/*
    service: user-service
    host: user:8082
    auth_required: true
    auth_type: admin
    strip_prefix: /api/admin
```

---

### 4.2. Update Frontend (Next.js) (Day 2-3 - 12 hours)

- [ ] Update AuthContext to use new Customer Service endpoints
- [ ] Update login API call
- [ ] Update register API call
- [ ] Update password reset flow
- [ ] Update email verification flow
- [ ] Test all auth flows
- [ ] Update UI/UX if needed

**Files to modify**:
```
frontend/src/contexts/AuthContext.tsx
frontend/src/lib/api/customer-auth-api.ts
frontend/src/app/(auth)/login/page.tsx
frontend/src/app/(auth)/register/page.tsx
```

**API Client Update**:
```typescript
// frontend/src/lib/api/customer-auth-api.ts
const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

export const customerAuthApi = {
  register: async (data: RegisterData) => {
    const response = await axios.post(
      `${API_BASE}/api/customer/auth/register`,
      data
    );
    return response.data;
  },

  login: async (email: string, password: string) => {
    const response = await axios.post(
      `${API_BASE}/api/customer/auth/login`,
      { email, password }
    );
    return response.data;
  },

  logout: async () => {
    const response = await axios.post(
      `${API_BASE}/api/customer/auth/logout`
    );
    return response.data;
  },

  getProfile: async () => {
    const response = await axios.get(
      `${API_BASE}/api/customer/auth/me`
    );
    return response.data;
  }
};
```

---

### 4.3. Update Admin Panel (React/Vite) (Day 3-4 - 12 hours)

- [ ] Update authSlice to use new User Service endpoints
- [ ] Update login API call
- [ ] Update password change flow
- [ ] Update session management UI
- [ ] Test all auth flows
- [ ] Update UI/UX if needed

**Files to modify**:
```
admin/src/store/slices/authSlice.ts
admin/src/lib/api/admin-auth-api.ts
admin/src/pages/Login.tsx
admin/src/pages/Profile.tsx
```

---

### 4.4. End-to-End Testing (Day 5 - 8 hours)

- [ ] Test customer registration flow
- [ ] Test customer login flow
- [ ] Test customer password reset
- [ ] Test customer email verification
- [ ] Test admin login flow
- [ ] Test admin password change
- [ ] Test admin session management
- [ ] Test token refresh
- [ ] Test logout
- [ ] Test protected routes
- [ ] Test CORS
- [ ] Load testing
- [ ] Security testing

**Test Scenarios**:
```bash
# 1. Customer Registration
curl -X POST http://localhost:8080/api/customer/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"customer@test.com","password":"Test123!","firstName":"John","lastName":"Doe"}'

# 2. Customer Login
curl -X POST http://localhost:8080/api/customer/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"customer@test.com","password":"Test123!"}'

# 3. Admin Login
curl -X POST http://localhost:8080/api/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin123!"}'

# 4. Access Protected Route
curl -X GET http://localhost:8080/api/customer/profile \
  -H "Authorization: Bearer <access_token>"
```

---

## 🎯 PHASE 5: CLEANUP & DOCUMENTATION (Ongoing)

### 5.1. Remove Deprecated Endpoints (After 2 weeks of monitoring)

- [ ] Monitor usage of old Auth Service endpoints
- [ ] Confirm zero usage
- [ ] Remove deprecated endpoints from Auth Service
- [ ] Remove old proto definitions
- [ ] Update documentation

---

### 5.2. Documentation (Throughout implementation)

- [ ] Update API documentation
- [ ] Update architecture diagrams
- [ ] Write migration guide
- [ ] Update README files
- [ ] Create troubleshooting guide
- [ ] Record demo videos

**Documents to create/update**:
```
docs/api/customer-auth-api.md
docs/api/user-auth-api.md
docs/api/auth-service-api-v2.md
docs/architecture/authentication-flow.md
docs/guides/migration-guide.md
docs/guides/troubleshooting.md
README.md (update)
```

---

### 5.3. Monitoring & Alerting (Day 5)

- [ ] Setup Prometheus metrics
- [ ] Setup Grafana dashboards
- [ ] Configure alerts for auth failures
- [ ] Configure alerts for high latency
- [ ] Setup log aggregation
- [ ] Create runbook

**Metrics to monitor**:
- Login success/failure rate
- Token generation rate
- Token validation rate
- Session creation rate
- API latency (p50, p95, p99)
- Error rate by endpoint

---

## 📊 PROGRESS TRACKING

### Week 1: Auth Service
- [ ] Day 1: Design & GenerateToken (12h)
- [ ] Day 2: ValidateToken & Session Mgmt (12h)
- [ ] Day 3: Session Mgmt continued (8h)
- [ ] Day 4: Deprecation & Testing (10h)
- [ ] Day 5: Deploy & Fix (8h)
**Total**: 50 hours

### Week 2: Customer Service
- [ ] Day 1: Setup & Register (12h)
- [ ] Day 2: Login (8h)
- [ ] Day 3: Password Mgmt (8h)
- [ ] Day 4: Email Verification (12h)
- [ ] Day 5: Deploy & Test (10h)
**Total**: 50 hours

### Week 3: User Service ⚠️ INCLUDES CRITICAL FIXES
- [ ] Day 1: Setup & Fix CreateUser (12h) 🔴 CRITICAL
  - Email validation
  - Uniqueness checks
  - Transaction support
  - Cache & Events
- [ ] Day 2: Fix UpdateUser (8h) 🔴 CRITICAL
  - Existence check
  - Validation
  - Uniqueness checks
  - Cache invalidation
  - Event publishing
- [ ] Day 3: Implement Login (8h)
  - Login with roles/permissions
  - Auth Service integration
- [ ] Day 4: Password & Session Mgmt (12h)
  - Change password
  - Session management
- [ ] Day 5: Deploy & Test (10h)
  - Full testing
  - Bug fixes
**Total**: 50 hours

**⚠️ IMPORTANT**: 
- Days 1-2 implement critical validation fixes from `USER_LOGIC_REVIEW.md`
- These fixes MUST be done before implementing auth endpoints
- Without these fixes, User Service will have data integrity issues

### Week 4: Integration
- [ ] Day 1: Gateway (4h)
- [ ] Day 2-3: Frontend (12h)
- [ ] Day 3-4: Admin Panel (12h)
- [ ] Day 5: E2E Testing (8h)
- [ ] Ongoing: Documentation (4h)
**Total**: 40 hours

**Grand Total**: 190 hours (~4 weeks with 2-3 developers)

---

## ✅ DEFINITION OF DONE

### For Each Feature:
- [ ] Code implemented and reviewed
- [ ] Unit tests written and passing (>80% coverage)
- [ ] Integration tests written and passing
- [ ] API documentation updated
- [ ] Deployed to dev environment
- [ ] Manual testing completed
- [ ] No critical bugs
- [ ] Performance acceptable (<200ms p95)

### For Each Phase:
- [ ] All features in phase completed
- [ ] End-to-end testing passed
- [ ] Documentation updated
- [ ] Demo to stakeholders
- [ ] Approval from tech lead

### For Overall Project:
- [ ] All phases completed
- [ ] All tests passing
- [ ] Deployed to staging
- [ ] Load testing passed
- [ ] Security audit passed
- [ ] Documentation complete
- [ ] Training completed
- [ ] Production deployment plan approved

---

## 🚨 RISKS & MITIGATION

### Risk 1: Breaking Changes
**Mitigation**: 
- Keep old endpoints during migration
- Use feature flags
- Gradual rollout

### Risk 2: Token Compatibility
**Mitigation**:
- Maintain backward compatibility
- Version tokens if needed
- Test thoroughly

### Risk 3: Performance Issues
**Mitigation**:
- Load testing early
- Monitor metrics
- Optimize hot paths

### Risk 4: Data Migration
**Mitigation**:
- No data migration needed (new endpoints)
- Test with production-like data
- Have rollback plan

---

## 📞 SUPPORT & ESCALATION

### Daily Standup:
- What did you complete yesterday?
- What will you work on today?
- Any blockers?

### Weekly Review:
- Progress vs plan
- Risks and issues
- Adjustments needed

### Escalation Path:
1. Team Lead (< 2 hours)
2. Tech Lead (< 4 hours)
3. Engineering Manager (< 1 day)

---

## 🎉 SUCCESS CRITERIA

### Authentication Flow:
- [ ] Customer can register and login via Customer Service
- [ ] Admin can login via User Service
- [ ] Tokens are generated by Auth Service
- [ ] All auth flows work end-to-end
- [ ] Token refresh works correctly
- [ ] Session management works

### User Service Validation (CRITICAL):
- [ ] Cannot create duplicate users (username/email)
- [ ] Email validation works
- [ ] Required fields are enforced
- [ ] User creation uses transaction
- [ ] Cannot update to duplicate username/email
- [ ] Update validates email format
- [ ] Cache invalidation works
- [ ] Events are published

### Quality:
- [ ] No breaking changes for existing users
- [ ] Performance meets SLA (<200ms p95)
- [ ] Security audit passed
- [ ] All tests passing (>80% coverage)
- [ ] Documentation complete
- [ ] Team trained

---

## 📝 CHANGELOG

### 2025-11-10 - Updated based on USER_LOGIC_REVIEW.md
- ✅ Added critical validation fixes for User Service
- ✅ Restructured Week 3 to prioritize fixes
- ✅ Added detailed validation checklists
- ✅ Added code change locations
- ✅ Added testing requirements
- ✅ Updated success criteria

**Key Changes**:
1. **Day 1 (Week 3)**: Fix CreateUser validation
   - Email validation
   - Uniqueness checks
   - Transaction support
   - Cache & Events

2. **Day 2 (Week 3)**: Fix UpdateUser validation
   - Existence check
   - Email/Username validation
   - Cache invalidation
   - Event publishing

3. **Day 3-5 (Week 3)**: Implement auth endpoints
   - Login with roles/permissions
   - Password management
   - Session management

**Why These Changes**:
- User Service currently has NO validation in CreateUser/UpdateUser
- Can create duplicate users
- No transaction support
- No cache/event support
- These MUST be fixed before adding auth endpoints

---

Generated: 2025-11-10
Updated: 2025-11-10 (based on USER_LOGIC_REVIEW.md)
Ready to execute! 🚀

# 🔐 Auth Service - Complete Documentation

**Service Name**: Auth Service  
**Version**: 1.1.1  
**Last Updated**: 2026-02-04  
**Review Status**: 🔄 In Review (Dependencies Updated)  
**Production Ready**: 75%  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Authentication APIs](#-authentication-apis)
- [Token Management APIs](#-token-management-apis)
- [Session Management APIs](#-session-management-apis)
- [Database Schema](#-database-schema)
- [Business Logic](#-business-logic)
- [Configuration](#-configuration)
- [Dependencies](#-dependencies)
- [Testing](#-testing)
- [Monitoring & Observability](#-monitoring--observability)
- [Known Issues & TODOs](#-known-issues--todos)
- [Development Guide](#-development-guide)

---

## 🎯 Overview

Auth Service là **security-critical service** quản lý authentication, authorization, và session management cho toàn bộ e-commerce platform. Service này xử lý:

### Core Capabilities
- **🔑 JWT Token Management**: Generation, validation, refresh, revocation
- **👤 User Authentication**: Login/logout flows cho customers và admin users
- **📊 Session Management**: Multi-device session tracking và management
- **🛡️ Rate Limiting**: Protection against brute force và DoS attacks
- **🔄 Token Refresh**: Secure token rotation mechanism
- **📋 Audit Logging**: Authentication event tracking
- **🚪 Gateway Integration**: Token validation cho service-to-service calls

### Business Value
- **Security Foundation**: Centralized authentication cho toàn bộ platform
- **User Experience**: Seamless login/logout across devices
- **Compliance**: Audit trails và security event monitoring
- **Scalability**: Stateless JWT tokens với centralized validation
- **Operational Security**: Rate limiting và attack prevention

### Critical Security Role
Auth Service là **foundation of platform security** - mọi authentication request đều đi qua service này. Compromise của Auth Service = compromise của toàn bộ platform.

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
auth/
├── cmd/auth/                        # Application entry point
├── internal/
│   ├── biz/                         # Business Logic Layer
│   │   ├── login/                   # Login flow logic
│   │   ├── session/                 # Session management
│   │   ├── token/                   # Token operations
│   │   └── audit/                   # Audit logging
│   ├── data/                        # Data Access Layer
│   │   ├── postgres/               # PostgreSQL repositories
│   │   └── eventbus/               # Dapr event bus
│   ├── service/                     # Service Layer (gRPC/HTTP)
│   ├── server/                      # Server setup
│   ├── middleware/                  # HTTP middleware
│   │   └── rate_limit.go            # Rate limiting middleware
│   ├── config/                      # Configuration
│   └── constant/                    # Constants & enums
├── api/                             # Protocol Buffers
├── migrations/                      # Database migrations
└── configs/                         # Environment configs
```

### Ports & Endpoints
- **HTTP API**: `:8002` - REST endpoints cho authentication
- **gRPC API**: `:9002` - Internal service communication
- **Health Check**: `/api/v1/auth/health`

### Service Dependencies

#### Internal Dependencies
- **User Service**: User credential validation, profile data
- **Customer Service**: Customer authentication, profile data
- **Notification Service**: Security notifications, password reset
- **Audit Service**: Centralized audit logging (planned)

#### External Dependencies
- **PostgreSQL**: Primary data store (`auth_db`)
- **Redis**: Session storage, token blacklist, rate limiting
- **Dapr**: Event-driven communication
- **Consul**: Service discovery

---

## 🔑 Authentication APIs

### Login Flow

#### Customer/Admin Login
```protobuf
rpc Login(LoginRequest) returns (LoginReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/login"
    body: "*"
  };
}
```

**Request**:
```json
{
  "username": "admin@example.com",
  "password": "Admin123!",
  "user_type": "admin",
  "device_info": "Chrome 120.0.0.0 on macOS",
  "ip_address": "192.168.1.100"
}
```

**Response**:
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "admin@example.com",
    "first_name": "Admin",
    "last_name": "User",
    "roles": ["admin", "user"]
  },
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "session_id": "session-uuid"
}
```

#### Get Current User
```protobuf
rpc GetCurrentUser(GetCurrentUserRequest) returns (GetCurrentUserReply) {
  option (google.api.http) = {
    get: "/api/v1/auth/me"
  };
}
```

#### Logout
```protobuf
rpc Logout(LogoutRequest) returns (LogoutReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/logout"
    body: "*"
  };
}
```

---

## 🎫 Token Management APIs

### Token Operations

#### Generate Token (Internal)
```protobuf
rpc GenerateToken(GenerateTokenRequest) returns (GenerateTokenReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/tokens/generate"
    body: "*"
  };
}
```

**Called by User/Customer Service after successful credential validation**

#### Validate Token
```protobuf
rpc ValidateToken(ValidateTokenRequest) returns (ValidateTokenReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/tokens/validate"
    body: "*"
  };
}
```

**Response**:
```json
{
  "valid": true,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_type": "admin",
  "session_id": "session-uuid",
  "claims": {
    "email": "admin@example.com",
    "roles": "admin,user",
    "permissions_version": "5"
  },
  "expires_at": "2026-01-22T11:30:15Z"
}
```

#### Refresh Token
```protobuf
rpc RefreshToken(RefreshTokenRequest) returns (RefreshTokenReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/tokens/refresh"
    body: "*"
  };
}
```

#### Revoke Token
```protobuf
rpc RevokeToken(RevokeTokenRequest) returns (RevokeTokenReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/tokens/revoke"
    body: "*"
  };
}
```

---

## 📊 Session Management APIs

### Session Operations

#### Create Session
```protobuf
rpc CreateSession(CreateSessionRequest) returns (CreateSessionReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/sessions"
    body: "*"
  };
}
```

#### Get Session
```protobuf
rpc GetSession(GetSessionRequest) returns (GetSessionReply) {
  option (google.api.http) = {
    get: "/api/v1/auth/sessions/{session_id}"
  };
}
```

#### Get User Sessions
```protobuf
rpc GetUserSessions(GetUserSessionsRequest) returns (GetUserSessionsReply) {
  option (google.api.http) = {
    get: "/api/v1/auth/sessions/user/{user_id}"
  };
}
```

#### Revoke Session
```protobuf
rpc RevokeSession(RevokeSessionRequest) returns (RevokeSessionReply) {
  option (google.api.http) = {
    delete: "/api/v1/auth/sessions/{session_id}"
  };
}
```

#### Revoke All User Sessions
```protobuf
rpc RevokeUserSessions(RevokeUserSessionsRequest) returns (RevokeUserSessionsReply) {
  option (google.api.http) = {
    post: "/api/v1/auth/sessions/user/{user_id}/revoke"
    body: "*"
  };
}
```

---

## 🗄️ Database Schema

### Core Tables

#### sessions
```sql
CREATE TABLE sessions (
  session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id VARCHAR(255) NOT NULL,
  user_type VARCHAR(20) NOT NULL, -- 'customer' or 'admin'
  device_info TEXT,
  ip_address INET,
  user_agent TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  revoked_at TIMESTAMP WITH TIME ZONE,
  revocation_reason VARCHAR(100)
);
```

#### tokens
```sql
CREATE TABLE tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(session_id),
  token_type VARCHAR(20) NOT NULL, -- 'access' or 'refresh'
  token_hash VARCHAR(255) UNIQUE NOT NULL, -- SHA256 hash for lookup
  is_revoked BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  revoked_at TIMESTAMP WITH TIME ZONE,
  revocation_reason VARCHAR(100)
);
```

#### token_revocations
```sql
CREATE TABLE token_revocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash VARCHAR(255) NOT NULL,
  revocation_reason VARCHAR(100),
  revoked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  revoked_by VARCHAR(255) -- User/Service that revoked
);
```

### Indexes & Performance
```sql
-- Session lookups
CREATE INDEX idx_sessions_user_id ON sessions(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_sessions_expires ON sessions(expires_at) WHERE is_active = TRUE;
CREATE UNIQUE INDEX idx_sessions_active_user ON sessions(user_id, user_type) WHERE is_active = TRUE;

-- Token operations
CREATE UNIQUE INDEX idx_tokens_hash ON tokens(token_hash) WHERE is_revoked = FALSE;
CREATE INDEX idx_tokens_session ON tokens(session_id);
CREATE INDEX idx_tokens_expires ON tokens(expires_at) WHERE is_revoked = FALSE;

-- Token revocations
CREATE INDEX idx_token_revocations_hash ON token_revocations(token_hash);
CREATE INDEX idx_token_revocations_revoked_at ON token_revocations(revoked_at DESC);
```

### Migration History

| Version | Migration File | Description | Key Features |
|---------|----------------|-------------|--------------|
| 001 | `001_init_auth_schema.sql` | Initial schema | Sessions, basic token storage |
| 003 | `003_create_token_revocations_table.sql` | Token revocation | Audit trail for revoked tokens |
| 004 | `004_create_tokens_table.sql` | Enhanced tokens | Structured token storage |
| 20251103191700 | `20251103191700_init_auth_schema.sql` | Schema consolidation | Clean migration structure |

---

## 🧠 Business Logic

### Authentication Flow

```go
func (uc *LoginUsecase) Login(ctx context.Context, req *LoginRequest) (*LoginReply, error) {
    // 1. Rate limiting check (per user/IP)
    if !rateLimiter.Allow(req.Username, req.IPAddress) {
        return nil, errors.New("rate limit exceeded")
    }

    // 2. Credential validation via User/Customer Service
    user, err := uc.validateCredentials(req.Username, req.Password, req.UserType)
    if err != nil {
        // Log failed attempt
        uc.auditLogFailedLogin(req.Username, req.IPAddress, err)
        return nil, err
    }

    // 3. Create session
    session := &Session{
        UserID:     user.ID,
        UserType:   req.UserType,
        DeviceInfo: req.DeviceInfo,
        IPAddress:  req.IPAddress,
        ExpiresAt:  time.Now().Add(24 * time.Hour), // 24h sessions
    }

    // 4. Generate tokens
    tokens, err := uc.generateTokens(session, user)
    if err != nil {
        return nil, err
    }

    // 5. Audit successful login
    uc.auditLogSuccessfulLogin(user.ID, session.ID, req.IPAddress)

    // 6. Return response
    return &LoginReply{
        User:         user,
        AccessToken:  tokens.AccessToken,
        RefreshToken: tokens.RefreshToken,
        ExpiresIn:    int64(tokens.AccessExpires.Sub(time.Now()).Seconds()),
        SessionID:    session.ID,
    }, nil
}
```

### Token Generation & Validation

```go
func (uc *TokenUsecase) GenerateTokens(session *Session, user *User) (*TokenPair, error) {
    // 1. Create JWT claims
    claims := jwt.MapClaims{
        "user_id":             user.ID,
        "user_type":           session.UserType,
        "session_id":          session.ID,
        "permissions_version": user.PermissionsVersion,
        "email":               user.Email,
        "roles":               strings.Join(user.Roles, ","),
        "iat":                 time.Now().Unix(),
        "exp":                 time.Now().Add(AccessTokenExpiry).Unix(),
        "iss":                 "auth-service",
    }

    // 2. Sign access token
    accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    accessTokenString, err := accessToken.SignedString(uc.jwtSecret)

    // 3. Generate refresh token
    refreshClaims := jwt.MapClaims{
        "session_id": session.ID,
        "type":       "refresh",
        "exp":        time.Now().Add(RefreshTokenExpiry).Unix(),
    }
    refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
    refreshTokenString, err := refreshToken.SignedString(uc.jwtSecret)

    // 4. Store token metadata
    uc.storeTokenMetadata(accessTokenString, refreshTokenString, session.ID)

    return &TokenPair{
        AccessToken:     accessTokenString,
        RefreshToken:    refreshTokenString,
        AccessExpires:   time.Now().Add(AccessTokenExpiry),
        RefreshExpires:  time.Now().Add(RefreshTokenExpiry),
    }, nil
}
```

### Rate Limiting Implementation

```go
type RateLimiter struct {
    redis *redis.Client
    config *RateLimitConfig
}

func (rl *RateLimiter) Allow(identifier string, ip string) bool {
    key := fmt.Sprintf("rate_limit:auth:%s:%s", identifier, ip)

    // Sliding window: count requests in last window
    now := time.Now()
    windowStart := now.Add(-rl.config.Window)

    pipe := rl.redis.Pipeline()
    pipe.ZRemRangeByScore(key, "0", fmt.Sprintf("%d", windowStart.UnixMilli()))
    pipe.ZCard(key)
    pipe.ZAdd(key, redis.Z{Score: float64(now.UnixMilli()), Member: uuid.New().String()})
    pipe.Expire(key, rl.config.Window+time.Minute)

    results, err := pipe.Exec()
    if err != nil {
        return true // Fail open
    }

    requestCount := results[1].(*redis.IntCmd).Val()
    return requestCount < rl.config.MaxRequests
}
```

### Session Management

```go
func (uc *SessionUsecase) ValidateSession(sessionID string) (*Session, error) {
    session, err := uc.repo.GetSession(sessionID)
    if err != nil {
        return nil, err
    }

    if !session.IsActive {
        return nil, errors.New("session revoked")
    }

    if session.ExpiresAt.Before(time.Now()) {
        // Auto-revoke expired session
        uc.RevokeSession(sessionID, "expired")
        return nil, errors.New("session expired")
    }

    // Update last activity
    session.LastActivity = time.Now()
    uc.repo.UpdateSessionActivity(session)

    return session, nil
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
AUTH_DATABASE_DSN=postgres://auth_user:auth_pass@postgres:5432/auth_db?sslmode=disable

# JWT Configuration
AUTH_JWT_SECRET=your-256-bit-secret-key-here
AUTH_ACCESS_TOKEN_EXPIRY=1h
AUTH_REFRESH_TOKEN_EXPIRY=24h

# Session Configuration
AUTH_SESSION_EXPIRY=24h
AUTH_MAX_SESSIONS_PER_USER=10

# Rate Limiting
AUTH_RATE_LIMIT_GENERATE_TOKEN=10
AUTH_RATE_LIMIT_REFRESH_TOKEN=20
AUTH_RATE_LIMIT_VALIDATE_TOKEN=100
AUTH_RATE_LIMIT_WINDOW=1m

# Redis
AUTH_REDIS_ADDR=redis:6379
AUTH_REDIS_PASSWORD=

# External Services
AUTH_USER_SERVICE_ADDR=user-service:9001
AUTH_CUSTOMER_SERVICE_ADDR=customer-service:9003
AUTH_NOTIFICATION_SERVICE_ADDR=notification-service:9005

# Features
AUTH_ENABLE_AUDIT_LOGGING=true
AUTH_ENABLE_SESSION_TRACKING=true
AUTH_ENABLE_MULTI_DEVICE=true
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: auth-service
  version: 1.0.0

database:
  dsn: ${AUTH_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 25
  conn_max_lifetime: 5m

jwt:
  secret: ${AUTH_JWT_SECRET}
  access_token_expiry: ${AUTH_ACCESS_TOKEN_EXPIRY}
  refresh_token_expiry: ${AUTH_REFRESH_TOKEN_EXPIRY}

session:
  expiry: ${AUTH_SESSION_EXPIRY}
  max_per_user: ${AUTH_MAX_SESSIONS_PER_USER}
  enable_tracking: ${AUTH_ENABLE_SESSION_TRACKING}
  enable_multi_device: ${AUTH_ENABLE_MULTI_DEVICE}

rate_limiting:
  generate_token_per_min: ${AUTH_RATE_LIMIT_GENERATE_TOKEN}
  refresh_token_per_min: ${AUTH_RATE_LIMIT_REFRESH_TOKEN}
  validate_token_per_min: ${AUTH_RATE_LIMIT_VALIDATE_TOKEN}
  window: ${AUTH_RATE_LIMIT_WINDOW}

redis:
  addr: ${AUTH_REDIS_ADDR}
  password: ${AUTH_REDIS_PASSWORD}
  db: 3  # Separate DB for auth service
  dial_timeout: 5s

external_services:
  user_service: ${AUTH_USER_SERVICE_ADDR}
  customer_service: ${AUTH_CUSTOMER_SERVICE_ADDR}
  notification_service: ${AUTH_NOTIFICATION_SERVICE_ADDR}

features:
  audit_logging: ${AUTH_ENABLE_AUDIT_LOGGING}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/auth

go 1.24

require (
    gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/golang-jwt/jwt/v5 v5.2.1
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    github.com/google/uuid v1.6.0
)
```

### Service Mesh Integration
```yaml
# Dapr pub/sub subscriptions
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: auth-service-events
spec:
  topic: user.password.changed
  route: /events/password-changed
  pubsubname: pubsub
---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: auth-session-events
spec:
  topic: user.logged.out
  route: /events/user-logged-out
  pubsubname: pubsub
```

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: 60% coverage (token operations, session management)
- **Integration Tests**: 40% coverage (login flow, token validation)
- **E2E Tests**: 25% coverage (complete authentication flows)

### Critical Test Scenarios

#### Authentication Flow Tests
```go
func TestLogin_CompleteFlow(t *testing.T) {
    // Setup: Create test user
    // Execute: Login with valid credentials
    // Verify: Tokens generated, session created, audit logged
}

func TestTokenRefresh_Security(t *testing.T) {
    // Setup: Valid refresh token
    // Execute: Refresh token multiple times
    // Verify: Only one refresh succeeds, others fail
}

func TestRateLimiting_Enforced(t *testing.T) {
    // Setup: Valid credentials
    // Execute: Multiple rapid login attempts
    // Verify: Rate limiting blocks excessive attempts
}
```

#### Token Security Tests
```go
func TestTokenValidation_Expired(t *testing.T) {
    // Setup: Create expired token
    // Execute: Validate token
    // Verify: Token rejected as invalid
}

func TestTokenRevocation_Immediate(t *testing.T) {
    // Setup: Valid token
    // Execute: Revoke token, then validate
    // Verify: Token immediately invalid
}
```

### Running Tests
```bash
# Unit tests
make test

# Integration tests (requires DB/Redis)
make test-integration

# With coverage
make test-coverage

# Specific auth tests
go test ./internal/biz/login/... -v
go test ./internal/biz/token/... -v
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### Authentication Metrics
```go
# Login operations
auth_login_attempts_total{result="success", user_type="admin"} 15420
auth_login_attempts_total{result="failure", user_type="customer"} 2340

# Token operations
auth_token_generated_total{token_type="access"} 15420
auth_token_validated_total{result="valid"} 145600
auth_token_refresh_total{result="success"} 8900

# Session metrics
auth_sessions_active 1250
auth_sessions_created_total 15420
auth_sessions_revoked_total{reason="user_logout"} 8900
```

#### Security Metrics
```go
# Rate limiting
auth_rate_limit_exceeded_total 450

# Token security
auth_token_revoked_total{reason="security"} 23
auth_suspicious_activity_total 15

# Performance
auth_login_duration_seconds{quantile="0.95"} 0.087
auth_token_validation_duration_seconds{quantile="0.95"} 0.012
```

### Health Checks
```go
# Application health
GET /api/v1/auth/health

# Dependencies health
GET /api/v1/auth/health/dependencies

# Database connectivity
# Redis connectivity
# External services (user, customer)
# JWT signing capability
```

### Distributed Tracing (OpenTelemetry)

#### Login Flow Trace
```
Client → Gateway → Auth Service
├── Rate limiting check (Redis)
├── Credential validation (User/Customer Service)
├── Session creation (Database)
├── Token generation (JWT)
├── Audit logging
└── Response to client
```

#### Token Validation Trace
```
Gateway → Auth Service
├── Token parsing
├── Signature validation
├── Claims extraction
├── Session validation (Redis/Database)
├── Permission version check
└── Response to gateway
```

---

## 🚨 Known Issues & TODOs

### P1 - High Priority Issues

1. **Session Management Review** 🟡
   - **Issue**: Session expiry và cleanup logic cần review
   - **Location**: `internal/biz/session/`
   - **Impact**: Potential session leaks, security concerns
   - **Fix**: Implement proper session lifecycle management

2. **Audit Logging Enhancement** 🟡
   - **Issue**: Audit events logged locally, not to centralized system
   - **Location**: `internal/biz/audit/`
   - **Impact**: Security event correlation difficult
   - **Fix**: Integrate with centralized audit service

3. **Token Blacklist Scaling** 🟡
   - **Issue**: Token revocation uses database, not optimal for high volume
   - **Location**: `internal/data/postgres/token.go`
   - **Impact**: Performance degradation under load
   - **Fix**: Implement Redis-based token blacklist with DB fallback

### P2 - Medium Priority Issues

4. **Multi-Device Session Limits** 🔵
   - **Issue**: No enforcement of max sessions per user
   - **Location**: Session creation logic
   - **Impact**: Unlimited concurrent sessions possible
   - **Fix**: Implement configurable session limits

5. **Token Version Invalidation** 🔵
   - **Issue**: Permission version checking implemented but not fully tested
   - **Location**: Token validation logic
   - **Impact**: Stale permissions in tokens after role changes
   - **Fix**: Complete permission version invalidation testing

6. **Device Fingerprinting** 🔵
   - **Issue**: Basic device tracking, no advanced fingerprinting
   - **Impact**: Limited security analytics
   - **Fix**: Implement device fingerprinting for anomaly detection

---

## 🚀 Development Guide

### Local Development Setup
```bash
# Clone and setup
git clone git@gitlab.com/ta-microservices/auth.git
cd auth

# Start dependencies
docker-compose up -d postgres redis

# Install dependencies
go mod download

# Run migrations
make migrate-up

# Generate protobuf code
make api

# Run service
make run

# Test authentication
curl -X POST http://localhost:8002/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@example.com","password":"Admin123!","user_type":"admin"}'
```

### Code Generation
```bash
# Generate protobuf code
make api

# Generate mocks for testing
make mocks

# Generate wire dependency injection
make wire
```

### Database Operations
```bash
# Create new migration
make migrate-create NAME="add_session_fingerprinting"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

### Authentication Development Workflow
1. **Update Proto Definition**: `api/auth/v1/auth.proto`
2. **Generate Code**: `make api`
3. **Implement Service**: `internal/service/auth.go`
4. **Add Business Logic**: `internal/biz/login/`, `internal/biz/token/`
5. **Add Repository**: `internal/data/postgres/`
6. **Add Tests**: Unit + Integration tests
7. **Update Documentation**: This file

### Testing Authentication Features
```bash
# Test login flow
make test-login

# Test token operations
make test-tokens

# Load testing
hey -n 1000 -c 10 -m POST \
  -H "Content-Type: application/json" \
  http://localhost:8002/api/v1/auth/tokens/validate \
  -d '{"token":"valid-jwt-token"}'

# Rate limiting test
go test -run TestRateLimiting -v
```

---

## 📈 Performance Benchmarks

### API Response Times (P95)
- **Login**: 87ms (with credential validation)
- **Token Validation**: 12ms (with session check)
- **Token Refresh**: 45ms (with database update)
- **Session Creation**: 23ms

### Throughput Targets
- **Token Validation**: 1000 req/sec sustained
- **Login Attempts**: 100 req/sec peak
- **Session Operations**: 200 req/sec sustained

### Database Performance
- **Session Queries**: <10ms average
- **Token Operations**: <15ms average
- **Concurrent Logins**: <50ms average

### Caching Strategy
- **Rate Limiting**: Redis sliding window
- **Session Data**: Redis TTL 24h
- **Token Metadata**: Database with indexes

---

## 🔐 Security Considerations

### Authentication Security
- **JWT HS256**: Symmetric signing with 256-bit secrets
- **Token Expiry**: Short-lived access tokens (1h), longer refresh tokens (24h)
- **Session Tracking**: Device fingerprinting và IP tracking
- **Rate Limiting**: Per-user và per-IP protection

### Data Protection
- **Credential Storage**: Never stored, validated via User/Customer services
- **Token Storage**: Hashed token storage for revocation lookup
- **Session Data**: Encrypted session metadata
- **Audit Trail**: Comprehensive authentication logging

### Attack Prevention
- **Brute Force Protection**: Rate limiting on login attempts
- **Token Theft Mitigation**: Refresh token rotation
- **Session Hijacking**: Device/IP validation
- **Replay Attacks**: Token expiry và nonce validation

### Security Headers (Gateway Level)
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000
Content-Security-Policy: default-src 'self'
```

---

## 🎯 Future Roadmap

### Phase 1 (Q1 2026) - Security Hardening
- [ ] Implement centralized audit logging
- [ ] Add device fingerprinting for anomaly detection
- [ ] Implement Redis-based token blacklist
- [ ] Add session limits per user

### Phase 2 (Q2 2026) - Advanced Features
- [ ] Multi-factor authentication (TOTP/SMS)
- [ ] OAuth 2.0 / OpenID Connect support
- [ ] Advanced threat detection
- [ ] Real-time security monitoring
- [ ] Geographic access controls

### Phase 3 (Q3 2026) - Scale & Intelligence
- [ ] Database sharding for high-volume authentication
- [ ] Machine learning for fraud detection
- [ ] Advanced session analytics
- [ ] Predictive security monitoring
- [ ] Zero-trust architecture implementation

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: Auth Service Team
- **Repository**: `gitlab.com/ta-microservices/auth`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #auth-service-alerts
- **Security Issues**: #security-incidents
- **Performance Issues**: #auth-service-performance
- **Login Issues**: #authentication-support

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/auth-service`
- **Security Metrics**: `https://grafana.tanhdev.com/d/auth-security`
- **Authentication Analytics**: `https://grafana.tanhdev.com/d/auth-analytics`
- **Audit Logs**: `https://kibana.tanhdev.com/app/discover#/?_auth-audit`

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Code Review Status**: ✅ Reviewed (Rate limiting implemented, session mgmt needs review)  
**Production Readiness**: 75% (Security foundation solid, minor enhancements needed)
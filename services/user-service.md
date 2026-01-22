# 👥 User Service - Complete Documentation

**Service Name**: User Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Review Status**: ❌ Reviewed (Multiple P0-P1 security issues)  
**Production Ready**: 60%  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [User Management APIs](#-user-management-apis)
- [Role-Based Access Control (RBAC)](#-role-based-access-control-rbac)
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

User Service là microservice quản lý toàn bộ user management, authentication, và authorization trong hệ thống e-commerce. Service này xử lý:

### Core Capabilities
- **👤 User Lifecycle Management**: CRUD operations cho internal users
- **🔐 Role-Based Access Control**: Hierarchical role system với permissions
- **🛡️ Service Access Control**: Granular access control per service/operation
- **📊 User Analytics**: User activity tracking và audit trails
- **🔑 Password Management**: Secure password handling với complexity requirements
- **🎭 Multi-tenancy**: Support for different user types và organizations
- **📋 Audit Logging**: Comprehensive audit trails for compliance

### Business Value
- **Security**: Centralized user management với strict access controls
- **Compliance**: Audit trails và GDPR-compliant user data handling
- **Scalability**: Role-based permissions scale với organization growth
- **Operational Efficiency**: Self-service user management cho admins

### Critical Security Role
User Service là **security-critical service** - quản lý authentication, authorization, và audit logging cho toàn bộ platform. Bất kỳ vulnerability nào đều ảnh hưởng toàn hệ thống.

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
user/
├── cmd/user/                        # Application entry point
├── internal/
│   ├── biz/                         # Business Logic Layer
│   │   ├── user/                    # User domain logic
│   │   │   ├── user.go             # User CRUD operations
│   │   │   ├── password.go         # Password management
│   │   │   └── user_enhanced_test.go # Enhanced tests
│   │   ├── events/                 # Event publishing
│   │   └── errors.go               # Business errors
│   ├── data/                        # Data Access Layer
│   │   ├── postgres/               # PostgreSQL repositories
│   │   │   ├── user.go             # User repository
│   │   │   ├── role.go             # Role repository
│   │   │   ├── permission.go       # Permission repository
│   │   │   └── outbox/             # Event outbox
│   │   └── eventbus/               # Dapr event bus
│   ├── service/                     # Service Layer (gRPC/HTTP)
│   ├── server/                      # Server setup
│   ├── middleware/                  # HTTP middleware
│   ├── config/                      # Configuration
│   └── constants/                   # Constants & enums
├── api/                             # Protocol Buffers
├── migrations/                      # Database migrations
└── configs/                         # Environment configs
```

### Ports & Endpoints
- **HTTP API**: `:8001` - REST endpoints cho admin interfaces
- **gRPC API**: `:9001` - Internal service communication
- **Health Check**: `/api/v1/users/health`

### Service Dependencies

#### Internal Dependencies
- **Auth Service**: Token validation và session management
- **Notification Service**: Password reset emails, security notifications
- **Audit Service**: Centralized audit logging (planned)

#### External Dependencies
- **PostgreSQL**: Primary data store (`user_db`)
- **Redis**: Caching layer cho permissions và sessions
- **Dapr**: Event-driven communication
- **Consul**: Service discovery

---

## 👤 User Management APIs

### User CRUD Operations

#### Create User
```protobuf
rpc CreateUser(CreateUserRequest) returns (User) {
  option (google.api.http) = {
    post: "/api/v1/users"
    body: "*"
  };
}
```

**Request**:
```json
{
  "username": "john.doe",
  "email": "john.doe@company.com",
  "firstName": "John",
  "lastName": "Doe",
  "department": "Engineering",
  "password": "TempPass123!",
  "status": "ACTIVE"
}
```

**Response**:
```json
{
  "id": "uuid-here",
  "username": "john.doe",
  "email": "john.doe@company.com",
  "firstName": "John",
  "lastName": "Doe",
  "department": "Engineering",
  "status": "ACTIVE",
  "createdAt": "2026-01-22T10:00:00Z",
  "permissionsVersion": 1
}
```

#### Get User
```protobuf
rpc GetUser(GetUserRequest) returns (User) {
  option (google.api.http) = {
    get: "/api/v1/users/{id}"
  };
}
```

#### Update User
```protobuf
rpc UpdateUser(UpdateUserRequest) returns (User) {
  option (google.api.http) = {
    put: "/api/v1/users/{id}"
    body: "*"
  };
}
```

#### Delete User (Soft Delete)
```protobuf
rpc DeleteUser(DeleteUserRequest) returns (google.protobuf.Empty) {
  option (google.api.http) = {
    delete: "/api/v1/users/{id}"
  };
}
```

⚠️ **CRITICAL BUG**: DeleteUser uses status=4 but ListUsers doesn't filter deleted users

### Password Management

#### Reset Password
```protobuf
rpc ResetPassword(ResetPasswordRequest) returns (google.protobuf.Empty) {
  option (google.api.http) = {
    post: "/api/v1/users/{id}/reset-password"
    body: "*"
  };
}
```

**Password Requirements**:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

---

## 🔐 Role-Based Access Control (RBAC)

### Role Management APIs

#### Create Role
```protobuf
rpc CreateRole(CreateRoleRequest) returns (Role) {
  option (google.api.http) = {
    post: "/api/v1/roles"
    body: "*"
  };
}
```

**Request**:
```json
{
  "name": "order_manager",
  "description": "Order Management Team",
  "permissions": ["order.read", "order.update", "order.cancel"],
  "services": ["order-service", "fulfillment-service"],
  "scope": "SERVICE_SPECIFIC"
}
```

#### Assign Role to User
```protobuf
rpc AssignRole(AssignRoleRequest) returns (User) {
  option (google.api.http) = {
    post: "/api/v1/users/{user_id}/roles"
    body: "*"
  };
}
```

#### Get User Permissions
```protobuf
rpc GetUserPermissions(GetUserPermissionsRequest) returns (GetUserPermissionsResponse) {
  option (google.api.http) = {
    get: "/api/v1/users/{id}/permissions"
  };
}
```

### Service Access Control

#### Grant Service Access
```protobuf
rpc GrantServiceAccess(GrantServiceAccessRequest) returns (ServiceAccess) {
  option (google.api.http) = {
    post: "/api/v1/users/{id}/service-access"
    body: "*"
  };
}
```

**Request**:
```json
{
  "serviceId": "order-service",
  "permissions": ["read", "write", "admin"]
}
```

#### Validate Access
```protobuf
rpc ValidateAccess(ValidateAccessRequest) returns (ValidateAccessResponse) {
  option (google.api.http) = {
    post: "/api/v1/users/validate-access"
    body: "*"
  };
}
```

**Request**:
```json
{
  "userId": "uuid-here",
  "service": "order-service",
  "operation": "order.cancel",
  "resource": "order-123"
}
```

---

## 🗄️ Database Schema

### Core Tables

#### users
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  password_hash VARCHAR(255) NOT NULL,
  status INTEGER NOT NULL DEFAULT 1, -- 1=Active, 2=Inactive, 3=Suspended, 4=Deleted
  department VARCHAR(100),
  manager_id UUID REFERENCES users(id),
  permissions_version INTEGER DEFAULT 1,
  last_login_at BIGINT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Soft delete support
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

#### roles
```sql
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  permissions JSONB DEFAULT '[]',
  services JSONB DEFAULT '[]',
  scope INTEGER NOT NULL DEFAULT 1, -- 1=Global, 2=Service-specific, 3=Operational, 4=Read-only
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### role_assignments
```sql
CREATE TABLE role_assignments (
  user_id UUID NOT NULL REFERENCES users(id),
  role_id UUID NOT NULL REFERENCES roles(id),
  assigned_at BIGINT NOT NULL,
  assigned_by UUID NOT NULL REFERENCES users(id),
  PRIMARY KEY (user_id, role_id)
);
```

#### service_access
```sql
CREATE TABLE service_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  service_id VARCHAR(100) NOT NULL,
  permissions JSONB DEFAULT '[]',
  granted_at BIGINT NOT NULL,
  granted_by UUID NOT NULL REFERENCES users(id),
  UNIQUE(user_id, service_id)
);
```

#### outbox_events (Transactional Outbox)
```sql
CREATE TABLE outbox_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(255) NOT NULL,
  aggregate_type VARCHAR(100) NOT NULL,
  aggregate_id VARCHAR(255) NOT NULL,
  event_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(20) DEFAULT 'pending'
);
```

### Indexes & Performance
```sql
-- User lookups
CREATE UNIQUE INDEX idx_users_username ON users(username) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_department ON users(department) WHERE deleted_at IS NULL;

-- Role assignments
CREATE INDEX idx_role_assignments_user ON role_assignments(user_id);
CREATE INDEX idx_role_assignments_role ON role_assignments(role_id);

-- Service access
CREATE UNIQUE INDEX idx_service_access_user_service ON service_access(user_id, service_id);

-- Outbox processing
CREATE INDEX idx_outbox_pending ON outbox_events(status, created_at) WHERE status = 'pending';
```

### Migration History

| Version | Migration File | Description | Key Features |
|---------|----------------|-------------|--------------|
| 001 | `001_create_users_table.sql` | User profiles with soft delete | Enhanced with triggers, functions |
| 002 | `002_create_roles_table.sql` | Role definitions | Permissions as JSONB |
| 003 | `003_create_role_assignments_table.sql` | User-role mappings | Audit fields |
| 004 | `004_create_service_access_table.sql` | Service-level access | Fine-grained permissions |
| 005 | `005_create_user_preferences_table.sql` | User preferences | Email/SMS settings |
| 006 | `006_add_permissions_version.sql` | Permission caching | Version-based invalidation |
| 007 | `007_create_outbox_events_table.sql` | Event sourcing | Transactional outbox |

---

## 🧠 Business Logic

### User Creation Flow

```go
func (uc *UserUsecase) CreateUser(ctx context.Context, req *CreateUserRequest) (*User, error) {
    // 1. Validate input (email format, username uniqueness)
    // 2. Validate password complexity
    // 3. Hash password with bcrypt
    // 4. Start transaction
    // 5. Create user record
    // 6. Assign default roles if specified
    // 7. Grant default service access
    // 8. Initialize permissions version
    // 9. Publish user.created event (transactional outbox)
    // 10. Return user with permissions
}
```

### Role Assignment Logic

```go
func (uc *UserUsecase) AssignRole(ctx context.Context, userID, roleID, assignedBy string) error {
    // SECURITY: Privilege Escalation Prevention
    // 1. Prevent self-assignment
    if userID == assignedBy {
        return fmt.Errorf("permission denied: cannot assign roles to self")
    }

    // 2. Validate assigner has permission
    allowed, err := uc.permissionRepo.ValidateAccess(ctx, assignedBy, "user", "role.assign", "")
    if err != nil || !allowed {
        return fmt.Errorf("permission denied: insufficient permissions")
    }

    // 3. Start transaction
    return uc.transaction(ctx, func(ctx context.Context) error {
        // 4. Assign role
        // 5. Increment user's permissions version (cache invalidation)
        // 6. Log audit event (CRITICAL: Currently only INFO log)
        uc.log.WithContext(ctx).Infof("AUDIT: Role %s assigned to user %s by %s", roleID, userID, assignedBy)
        // 7. Publish role.assigned event
        return nil
    })
}
```

### Access Validation Logic

```go
func (uc *UserUsecase) ValidateAccess(ctx context.Context, req *ValidateAccessRequest) (*ValidateAccessResponse, error) {
    // 1. Get user with roles and service access
    // 2. Check direct role permissions
    // 3. Check service-level access
    // 4. Apply RBAC hierarchy rules
    // 5. Cache result with permissions version
    // 6. Return access decision

    // CRITICAL: No rate limiting on this endpoint
    // CRITICAL: No ValidateAccess middleware in gateway
}
```

### Permission Caching Strategy

```go
type PermissionCache struct {
    userPermissions map[string]*UserPermissions
    versionTracker  map[string]int64
}

func (pc *PermissionCache) GetUserPermissions(userID string) (*UserPermissions, error) {
    // 1. Check cache with version validation
    // 2. If cache miss or version stale, fetch from database
    // 3. Update cache with new version
    // 4. Return permissions

    // ISSUE: Cache invalidation strategy not verified
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
USER_DATABASE_DSN=postgres://user_user:user_pass@postgres:5432/user_db?sslmode=disable

# Redis
USER_REDIS_ADDR=redis:6379
USER_REDIS_PASSWORD=

# Service Ports
USER_HTTP_PORT=8001
USER_GRPC_PORT=9001

# Security
USER_JWT_SECRET=your-secret-key
USER_BCRYPT_COST=12

# Password Policy
USER_PASSWORD_MIN_LENGTH=8
USER_PASSWORD_REQUIRE_UPPER=true
USER_PASSWORD_REQUIRE_LOWER=true
USER_PASSWORD_REQUIRE_NUMBER=true
USER_PASSWORD_REQUIRE_SPECIAL=true

# Permissions
USER_DEFAULT_ROLES=user,viewer
USER_CACHE_TTL=300

# External Services
USER_AUTH_SERVICE_ADDR=auth-service:9001
USER_NOTIFICATION_SERVICE_ADDR=notification-service:9005

# Audit
USER_ENABLE_AUDIT_LOGGING=true
USER_AUDIT_LOG_LEVEL=info
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: user-service
  version: 1.0.0

database:
  dsn: ${USER_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 25
  conn_max_lifetime: 5m

redis:
  addr: ${USER_REDIS_ADDR}
  password: ${USER_REDIS_PASSWORD}
  db: 2  # Separate DB for user service
  dial_timeout: 5s

server:
  http:
    addr: 0.0.0.0
    port: ${USER_HTTP_PORT}
  grpc:
    addr: 0.0.0.0
    port: ${USER_GRPC_PORT}

security:
  jwt_secret: ${USER_JWT_SECRET}
  bcrypt_cost: ${USER_BCRYPT_COST}
  password_policy:
    min_length: ${USER_PASSWORD_MIN_LENGTH}
    require_upper: ${USER_PASSWORD_REQUIRE_UPPER}
    require_lower: ${USER_PASSWORD_REQUIRE_LOWER}
    require_number: ${USER_PASSWORD_REQUIRE_NUMBER}
    require_special: ${USER_PASSWORD_REQUIRE_SPECIAL}

permissions:
  default_roles: ${USER_DEFAULT_ROLES}
  cache_ttl: ${USER_CACHE_TTL}

external_services:
  auth_service: ${USER_AUTH_SERVICE_ADDR}
  notification_service: ${USER_NOTIFICATION_SERVICE_ADDR}

audit:
  enabled: ${USER_ENABLE_AUDIT_LOGGING}
  log_level: ${USER_AUDIT_LOG_LEVEL}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/user

go 1.24

require (
    gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    golang.org/x/crypto v0.17.0  // bcrypt
    github.com/google/uuid v1.6.0
)
```

### Service Mesh Integration
```yaml
# Dapr pub/sub subscriptions
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: user-service-events
spec:
  topic: auth.user.login
  route: /events/user-login
  pubsubname: pubsub
---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: user-permission-updates
spec:
  topic: user.role.assigned
  route: /events/role-assigned
  pubsubname: pubsub
```

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: 50% coverage (business logic)
- **Integration Tests**: 30% coverage (API endpoints, database)
- **E2E Tests**: 10% coverage (RBAC flows)

### Critical Test Gaps
```go
// MISSING: RBAC Integration Tests
func TestRBAC_UserCreationToAccessValidation(t *testing.T) {
    // 1. Create user
    // 2. Assign role
    // 3. Validate access to protected resource
    // 4. Verify access denied for insufficient permissions
}

// MISSING: Soft Delete Tests
func TestSoftDelete_UserNotReturnedInList(t *testing.T) {
    // 1. Create user
    // 2. Delete user (soft delete)
    // 3. Verify user not returned in ListUsers
    // 4. Verify GetUser returns error
}

// MISSING: Audit Logging Tests
func TestAuditLogging_RoleAssignment(t *testing.T) {
    // 1. Assign role to user
    // 2. Verify audit log entry created
    // 3. Verify log contains required fields
}
```

### Running Tests
```bash
# Unit tests
make test

# Integration tests (requires DB)
make test-integration

# With coverage
make test-coverage

# Specific RBAC tests
go test ./internal/biz/user/... -run TestRBAC -v
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### User Management Metrics
```go
# User lifecycle
user_created_total{department="engineering"} 1250
user_deleted_total{reason="resignation"} 23

# Authentication metrics
user_login_attempts_total{result="success"} 45670
user_login_attempts_total{result="failure"} 1234

# RBAC metrics
role_assignments_total{role="admin"} 89
access_validation_requests_total{result="granted"} 345600
access_validation_requests_total{result="denied"} 45600
```

#### Performance Metrics
```go
# API response times
user_api_request_duration_seconds{endpoint="/api/v1/users", quantile="0.95"} 0.087
rbac_validation_duration_seconds{quantile="0.95"} 0.023

# Cache hit rates
user_permissions_cache_hit_ratio 0.89
role_cache_hit_ratio 0.95
```

### Health Checks
```go
# Application health
GET /api/v1/users/health

# Dependencies health
GET /api/v1/users/health/dependencies

# Database connectivity
# Redis connectivity
# External services (auth, notification)
```

### Audit Logging (CRITICAL ISSUE)
```json
// CURRENT: Only application logs
{
  "level": "info",
  "ts": "2026-01-22T10:30:15Z",
  "caller": "user/service/user.go:45",
  "msg": "AUDIT: Role admin assigned to user john.doe by jane.smith",
  "user_id": "uuid-here",
  "role_id": "uuid-here",
  "assigned_by": "uuid-here"
}

// REQUIRED: Structured audit events to ELK/Splunk
{
  "timestamp": "2026-01-22T10:30:15Z",
  "event_type": "role_assignment",
  "actor": {
    "id": "jane.smith-uuid",
    "username": "jane.smith"
  },
  "target": {
    "id": "john.doe-uuid",
    "username": "john.doe"
  },
  "changes": {
    "role": "admin",
    "action": "assigned"
  },
  "context": {
    "ip_address": "192.168.1.100",
    "user_agent": "AdminDashboard/1.0",
    "session_id": "session-uuid"
  }
}
```

---

## 🚨 Known Issues & TODOs

### P0 - Critical Security Issues

1. **Audit Logging Insufficient** 🚨
   - **Issue**: Role assignments logged as INFO only, no persistent audit trail
   - **Risk**: Cannot track admin actions for compliance/security investigations
   - **Location**: `user/internal/biz/user/user.go:633`
   - **Impact**: Regulatory compliance violation, security incident response impossible
   - **Fix**: Implement structured audit logging to ELK/Splunk

2. **ValidateAccess Middleware Missing** 🚨
   - **Issue**: No middleware in gateway enforcing role-based access
   - **Risk**: Unauthorized access to admin endpoints possible
   - **Location**: Gateway service missing ValidateAccess middleware
   - **Impact**: Complete bypass of RBAC controls
   - **Fix**: Implement ValidateAccess middleware in gateway

3. **Rate Limiting Missing** 🚨
   - **Issue**: Credential validation has no rate limiting
   - **Risk**: Brute force attacks on user accounts
   - **Location**: `user/internal/service/user.go` - ValidateAccess endpoint
   - **Impact**: Account takeover vulnerability
   - **Fix**: Implement rate limiting per user/IP

### P1 - High Priority Issues

4. **Password Policy Hardcoded** 🟡
   - **Issue**: Complexity rules not configurable per environment
   - **Location**: `user/internal/biz/user/password.go:8-24`
   - **Impact**: Cannot adjust security requirements
   - **Fix**: Make password policy configurable via config

5. **Soft Delete Not Implemented** 🟡
   - **Issue**: DeleteUser uses status=4 but ListUsers doesn't filter deleted users
   - **Location**: `user/internal/biz/user/user.go:593-595`
   - **Impact**: Deleted users appear in listings, data exposure
   - **Fix**: Implement proper soft delete filtering

6. **Service Access Too Broad** 🟡
   - **Issue**: GrantServiceAccess grants service-level access, not fine-grained
   - **Impact**: Over-permissive access, principle of least privilege violated
   - **Fix**: Implement resource-level permissions

### P2 - Technical Debt

7. **Permissions Cache Invalidation** 🔵
   - **Issue**: Cache invalidation strategy not verified
   - **Location**: `user/internal/biz/user/cache.go`
   - **Impact**: Stale permissions after role changes
   - **Fix**: Implement proper cache invalidation on permission changes

8. **Missing Integration Tests** 🔵
   - **Issue**: No end-to-end RBAC flow tests
   - **Impact**: Undetected integration bugs
   - **Fix**: Add comprehensive RBAC integration test suite

9. **Missing Negative RBAC Tests** 🔵
   - **Issue**: No tests verifying access denied for insufficient permissions
   - **Impact**: False security assumptions
   - **Fix**: Add negative test cases for all RBAC scenarios

10. **Bulk Operations Missing** 🔵
    - **Issue**: No bulk user import or role assignment endpoints
    - **Impact**: Operational inefficiency for large user bases
    - **Fix**: Implement bulk operations with proper validation

---

## 🚀 Development Guide

### Local Development Setup
```bash
# Clone and setup
git clone git@gitlab.com:ta-microservices/user.git
cd user

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

# Test RBAC functionality
curl -X POST http://localhost:8001/api/v1/users \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"TempPass123!"}'
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
make migrate-create NAME="add_user_audit_log"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

### RBAC Development Workflow
1. **Update Proto Definition**: `api/user/v1/user.proto`
2. **Generate Code**: `make api`
3. **Implement Service**: `internal/service/user.go`
4. **Add Business Logic**: `internal/biz/user/`
5. **Add Repository**: `internal/data/postgres/`
6. **Add Tests**: Unit + Integration tests
7. **Update Documentation**: This file

### Testing RBAC Features
```bash
# Test user creation
make test-user-creation

# Test RBAC flows
make test-rbac

# Load testing
hey -n 1000 -c 10 -m POST \
  -H "Authorization: Bearer <token>" \
  http://localhost:8001/api/v1/users/validate-access \
  -d '{"userId":"user-uuid","service":"order-service","operation":"order.read"}'

# Concurrency testing
go test -run TestRBAC_Concurrency -v
```

---

## 📈 Performance Benchmarks

### API Response Times (P95)
- **Create User**: 120ms (with password hashing)
- **Get User**: 45ms (with permissions)
- **Validate Access**: 23ms (with caching)
- **Assign Role**: 95ms (with cache invalidation)

### Throughput Targets
- **Read Operations**: 500 req/sec sustained
- **User Creation**: 100 req/sec peak
- **Access Validation**: 1000 req/sec sustained

### Database Performance
- **User Queries**: <15ms average
- **Permission Checks**: <5ms with caching
- **Role Assignments**: <25ms average

### Cache Performance
- **Permissions Cache Hit Rate**: 89%
- **Role Cache Hit Rate**: 95%
- **Cache TTL**: 5 minutes for permissions

---

## 🔐 Security Considerations

### Authentication & Authorization
- **Multi-Factor**: JWT tokens with role claims
- **Session Management**: External session validation via Auth Service
- **Password Security**: bcrypt with configurable cost factor
- **Rate Limiting**: Required but currently missing

### Data Protection
- **PII Handling**: User data encrypted at rest
- **Password Storage**: One-way bcrypt hashing
- **Audit Trail**: Required but insufficiently implemented
- **GDPR Compliance**: Data deletion and access controls

### Access Control
- **RBAC Model**: Role-based with hierarchical permissions
- **Service Access**: Fine-grained service-level controls
- **Privilege Escalation Prevention**: Self-assignment protection
- **Audit Logging**: Critical security requirement

### Security Headers (Gateway Level)
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
X-Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000
```

---

## 🎯 Future Roadmap

### Phase 1 (Q1 2026) - Security Hardening
- [ ] Implement persistent audit logging (ELK/Splunk)
- [ ] Add ValidateAccess middleware to gateway
- [ ] Implement rate limiting for credential operations
- [ ] Complete soft delete implementation
- [ ] Make password policy configurable

### Phase 2 (Q2 2026) - RBAC Enhancement
- [ ] Implement resource-level permissions
- [ ] Add hierarchical roles support
- [ ] Implement bulk operations
- [ ] Add comprehensive RBAC integration tests
- [ ] Improve permission caching strategy

### Phase 3 (Q3 2026) - Advanced Features
- [ ] Multi-tenancy support
- [ ] OAuth integration for external users
- [ ] Advanced user analytics
- [ ] Machine learning for access pattern analysis
- [ ] Real-time security monitoring

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: User Service Team
- **Repository**: `gitlab.com/ta-microservices/user`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #user-service-alerts
- **Security Issues**: #security-incidents
- **RBAC Issues**: #access-control
- **Performance Issues**: #user-service-performance

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/user-service`
- **Security Metrics**: `https://grafana.tanhdev.com/d/user-security`
- **RBAC Analytics**: `https://grafana.tanhdev.com/d/rbac-analytics`
- **Audit Logs**: `https://kibana.tanhdev.com/app/discover#/?_g=user-audit`

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Code Review Status**: ❌ Multiple P0 security issues identified  
**Production Readiness**: 60% (Security issues must be fixed before production)  
**Security Risk Level**: 🔴 HIGH (P0 issues present)
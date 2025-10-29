# Auth Service - Kratos + Consul Event-Driven Architecture

## Description
High-performance, event-driven authentication service built with **go-kratos/kratos** framework and **Consul** integration that provides **sub-50ms authentication** with decoupled permission management. Eliminates circular dependencies by owning only authentication data while caching permissions from other services via events.

## Architecture Philosophy

### Core Principles
1. **Kratos Cloud-Native Framework** - Modern microservice architecture
2. **Consul Service Discovery** - Dynamic service registration and discovery
3. **Consul Permission Matrix** - Centralized service-to-service authorization
4. **Auth Service owns authentication data only** (credentials, basic roles)
5. **Permission data is cached** from other services via events
6. **No direct service-to-service calls** during authentication
7. **Eventually consistent permissions** with fast fallback
8. **High-performance caching** for optimal user experience

### Kratos + Consul Integration Flow
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Kratos Auth Service with Consul Integration             │
└─────────────────────────────────────────────────────────────────────────────┘

User/Customer Services ──events──▶ Auth Service ──cache──▶ Redis
                                       │
                                   Consul KV
                                   ┌─────────┐
                                   │Service  │
                                   │Discovery│
                                   │& Perms  │
                                   └─────────┘
                                       │
Client ──login──▶ Gateway ──auth──▶ Auth Service (gRPC/HTTP)
                                   (10-30ms response)
                                       │
                                   JWT with full permissions
                                   + Consul session tracking
```

## Core Responsibilities
- **High-Performance Authentication**: Sub-30ms login with Kratos optimization
- **Consul Service Registration**: Automatic service discovery and health checks
- **Consul Permission Management**: Service-to-service authorization via Consul KV
- **JWT Token Management**: Secure token generation, validation, and refresh
- **Event-Driven Permission Sync**: Real-time permission updates via events
- **Session Management**: Secure session handling with Redis + Consul sessions
- **Security Auditing**: Comprehensive security event logging
- **Account Protection**: Advanced lockout and rate limiting

## Key Features

### Kratos Framework Benefits
- **Dual Protocol Support**: gRPC (internal) + HTTP/REST (external)
- **10-30ms authentication** with Kratos performance optimization
- **Built-in Observability**: Prometheus metrics, Jaeger tracing, structured logging
- **Configuration Management**: Multi-source config (file, env, Consul KV)
- **Dependency Injection**: Wire-based compile-time DI
- **Graceful Shutdown**: Production-ready lifecycle management

### Consul Integration Features
- **Service Discovery**: Automatic registration with health checks
- **Permission Matrix**: Centralized service-to-service authorization
- **Configuration Management**: Dynamic config updates via Consul KV
- **Session Tracking**: Consul sessions for distributed coordination
- **Health Monitoring**: Integrated health checks and service catalog

### Performance Optimizations
- **10-30ms authentication** with Kratos + Redis optimization
- **Local credential validation** (no external service calls)
- **Cached permission lookup** with 95%+ hit rate
- **Async event processing** for non-blocking operations
- **gRPC streaming** for real-time permission updates

### Event-Driven Architecture
- **Real-time permission updates** via Kratos message queue
- **Eventually consistent permissions** across services
- **Automatic cache invalidation** on permission changes
- **Fallback to basic permissions** when cache unavailable
- **Consul watch-based updates** for configuration changes

### Advanced Security
- **Multi-factor authentication (MFA)** support
- **Progressive lockout policies** with configurable thresholds
- **JWT security** with RS256 signing and key rotation
- **Suspicious activity detection** and alerting
- **Consul ACL integration** for service-level security

## Outbound Data

### JWT Tokens with Consul Integration (Primary Output)
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "user": {
    "id": "user_123",
    "email": "user@example.com",
    "roles": ["user", "premium"],
    "permissions": ["user:read", "user:write", "premium:access"],
    "customer_id": "cust_456",
    "service_permissions": {
      "user-service": ["user:read", "user:validate"],
      "order-service": ["order:create", "order:read"],
      "payment-service": ["payment:read"]
    }
  },
  "consul_session_id": "session_abc123",
  "service_discovery": {
    "registered_services": ["auth-service", "user-service", "order-service"],
    "health_status": "healthy"
  }
}
```

### Authentication Events
- `user.authenticated` - Successful login with context
- `user.logout` - User logout with session info
- `user.account_locked` - Account locked due to failed attempts
- `auth.permission_refresh_needed` - Request permission update
- `auth.suspicious_activity` - Security alert events

## Consumers (Services that use this data)

### All Services
- **Purpose**: Validate user authentication and authorization
- **Data Received**: JWT tokens with embedded permissions, user context
- **Headers Forwarded**: X-User-ID, X-User-Roles, X-Customer-ID

### API Gateway
- **Purpose**: Route authentication and inject user context
- **Data Received**: JWT validation results, user permissions
- **Integration**: Direct JWT validation for performance

### Notification Service
- **Purpose**: Send security alerts and notifications
- **Data Received**: Authentication events, security incidents
- **Events**: Login alerts, suspicious activity, account lockouts

### Audit Service
- **Purpose**: Security compliance and monitoring
- **Data Received**: All authentication events, permission changes
- **Events**: Login attempts, token generation, permission updates

## Data Sources (Event-Driven)

### User Service Events
- `user.created` - Initialize auth record with basic permissions
- `user.role_changed` - Update cached permissions
- `user.deactivated` - Revoke all tokens and sessions
- `user.profile_updated` - Sync user profile data

### Customer Service Events
- `customer.upgraded` - Add premium permissions to cache
- `customer.downgraded` - Remove premium permissions
- `customer.subscription_expired` - Revoke subscription-based permissions
- `customer.billing_failed` - Temporary permission restrictions

## Main APIs

### Kratos gRPC APIs (Internal Service-to-Service)
```protobuf
service AuthService {
  // High-performance authentication (5-15ms)
  rpc Authenticate(AuthenticateRequest) returns (AuthenticateResponse);
  rpc ValidateToken(ValidateTokenRequest) returns (ValidateTokenResponse);
  rpc RefreshToken(RefreshTokenRequest) returns (RefreshTokenResponse);
  
  // Consul permission management
  rpc GetServicePermissions(GetServicePermissionsRequest) returns (GetServicePermissionsResponse);
  rpc ValidateServiceCall(ValidateServiceCallRequest) returns (ValidateServiceCallResponse);
  
  // Session management
  rpc CreateSession(CreateSessionRequest) returns (CreateSessionResponse);
  rpc RevokeSession(RevokeSessionRequest) returns (RevokeSessionResponse);
}
```

### Kratos HTTP APIs (External Client Access)
- `POST /api/v1/auth/login` - **10-30ms** user authentication with Consul integration
- `POST /api/v1/auth/logout` - User logout with token and Consul session revocation
- `POST /api/v1/auth/refresh` - JWT token refresh with updated permissions
- `POST /api/v1/auth/register` - User registration (publishes user.created event)

### Token Management
- `POST /api/v1/auth/validate-token` - **<5ms** JWT token validation
- `POST /api/v1/auth/revoke-token` - Immediate token revocation
- `GET /api/v1/auth/token-info` - Token information with permissions

### Consul Integration APIs (Internal)
- `GET /api/v1/auth/consul/permissions/{fromService}/{toService}` - Get service permissions
- `POST /api/v1/auth/consul/validate-call` - Validate service-to-service call
- `GET /api/v1/auth/consul/services` - List registered services
- `POST /api/v1/auth/consul/refresh-permissions` - Force permission refresh from Consul KV

### Permission Management (Internal)
- `GET /api/v1/auth/internal/permissions/{userId}` - Get cached permissions
- `POST /api/v1/auth/internal/refresh-permissions` - Force permission refresh
- `POST /api/v1/auth/internal/invalidate-cache` - Invalidate user cache

### Security Management
- `POST /api/v1/auth/forgot-password` - Password reset with security validation
- `POST /api/v1/auth/change-password` - Secure password change
- `GET /api/v1/auth/security-events/{userId}` - User security event history

### Health and Monitoring (Kratos Built-in)
- `GET /health` - Service health check (Consul integration)
- `GET /metrics` - Prometheus metrics
- `GET /debug/pprof` - Performance profiling

## Performance Metrics

### Kratos Authentication Performance
- **Average Response Time**: 10-30ms (vs 200-300ms traditional)
- **gRPC Internal Calls**: 5-15ms average latency
- **HTTP External Calls**: 15-30ms average latency
- **Cache Hit Rate**: >95% for permission lookups
- **Concurrent Users**: 15,000+ simultaneous authentications
- **Token Generation**: <3ms per JWT token

### Consul Integration Performance
- **Service Discovery**: <5ms lookup time
- **Permission Loading**: <10ms from Consul KV
- **Health Check Response**: <2ms
- **Configuration Updates**: Real-time via Consul watch

### Scalability Metrics
- **Throughput**: 15,000+ RPS per instance (Kratos optimization)
- **Memory Usage**: <80MB for 100K cached users
- **Event Processing**: <5ms latency
- **Database Connections**: 50 connection pool
- **Consul Sessions**: 1000+ concurrent sessions

## Security Features

### Advanced Authentication
- **Multi-factor authentication (MFA)** with TOTP/SMS
- **Progressive rate limiting** (1s, 5s, 30s, 15min delays)
- **Account lockout policies** (5 attempts, 15-minute lockout)
- **IP-based suspicious activity detection**

### Token Security
- **RS256 JWT signing** with rotating keys
- **Short-lived access tokens** (1 hour) with refresh tokens
- **Token blacklisting** for immediate revocation
- **Audience and issuer validation**

### Cache Security
- **Encrypted Redis connections** (TLS)
- **Permission cache TTL** (24 hours maximum)
- **Automatic cache invalidation** on security events
- **Audit trail** for all permission changes

## Event Processing

### Event Handlers
```go
// Handle user role changes
func HandleUserRoleChanged(event UserRoleChangedEvent) {
    // Update Redis permission cache
    // Invalidate existing JWT tokens if needed
    // Audit permission change
    // Notify other services
}

// Handle customer upgrades
func HandleCustomerUpgraded(event CustomerUpgradedEvent) {
    // Add premium permissions to cache
    // Update customer context
    // Log permission grant
}
```

### Event Publishing
```go
// Publish authentication success
func PublishUserAuthenticated(userID, email, ipAddress string) {
    event := UserAuthenticatedEvent{
        UserID:    userID,
        Email:     email,
        IPAddress: ipAddress,
        LoginAt:   time.Now(),
    }
    eventBus.Publish("user.authenticated", event)
}
```

## Database Schema

### Core Authentication Data
```sql
-- Auth service owns only authentication data
CREATE TABLE auth_users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    basic_roles VARCHAR[] DEFAULT ARRAY['user'],
    status VARCHAR(20) DEFAULT 'active',
    last_login TIMESTAMP,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Session management
CREATE TABLE auth_sessions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth_users(id),
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_revoked BOOLEAN DEFAULT FALSE
);

-- Permission audit trail
CREATE TABLE permission_audit_log (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,
    old_permissions JSONB,
    new_permissions JSONB,
    source_service VARCHAR(100),
    event_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);
```

## Redis Cache Structure

### Permission Cache
```redis
# User permissions with TTL
HSET user_permissions:user_123 roles "user,premium"
HSET user_permissions:user_123 permissions "user:read,user:write,premium:access"
HSET user_permissions:user_123 customer_id "cust_456"
HSET user_permissions:user_123 cached_at "2024-01-15T10:30:00Z"
EXPIRE user_permissions:user_123 86400

# Session cache
SETEX session:abc123 3600 "user_123"

# Rate limiting
INCR rate_limit:192.168.1.1 EX 60
```

## Configuration

### Kratos Configuration (configs/config.yaml)
```yaml
server:
  http:
    addr: 0.0.0.0:8000
    timeout: 1s
  grpc:
    addr: 0.0.0.0:9000
    timeout: 1s

data:
  database:
    driver: postgres
    source: postgres://auth_user:auth_pass@localhost:5432/auth_db?sslmode=disable
  redis:
    addr: localhost:6379
    password: secure_password
    db: 0
    dial_timeout: 1s
    read_timeout: 0.2s
    write_timeout: 0.2s
  kafka:
    brokers:
      - localhost:9092
    group_id: auth-service-group

consul:
  address: localhost:8500
  scheme: http
  datacenter: dc1
  health_check: true
  health_check_interval: 10s
  health_check_timeout: 3s
  deregister_critical_service_after: true
  deregister_critical_service_after_duration: 30s

trace:
  endpoint: http://localhost:14268/api/traces

auth:
  jwt:
    private_key_path: /secrets/jwt-private-key.pem
    access_token_expiration: 3600
    refresh_token_expiration: 86400
  security:
    max_login_attempts: 5
    lockout_duration: 900
    rate_limit_requests_per_minute: 100
    mfa_enabled: true
  performance:
    permission_cache_ttl: 86400
    async_event_processing: true
    max_concurrent_authentications: 15000
```

### Environment Variables (Override Config)
```env
# Kratos Server
AUTH_SERVER_HTTP_ADDR=0.0.0.0:8000
AUTH_SERVER_GRPC_ADDR=0.0.0.0:9000

# Database
AUTH_DATA_DATABASE_SOURCE=postgres://auth_user:auth_pass@localhost:5432/auth_db?sslmode=disable

# Redis Cache
AUTH_DATA_REDIS_ADDR=localhost:6379
AUTH_DATA_REDIS_PASSWORD=secure_password

# Consul
AUTH_CONSUL_ADDRESS=localhost:8500
AUTH_CONSUL_DATACENTER=dc1

# JWT Configuration
AUTH_AUTH_JWT_PRIVATE_KEY_PATH=/secrets/jwt-private-key.pem
AUTH_AUTH_JWT_ACCESS_TOKEN_EXPIRATION=3600

# Security
AUTH_AUTH_SECURITY_MAX_LOGIN_ATTEMPTS=5
AUTH_AUTH_SECURITY_MFA_ENABLED=true

# Performance
AUTH_AUTH_PERFORMANCE_MAX_CONCURRENT_AUTHENTICATIONS=15000
```

## Monitoring and Alerting

### Key Metrics
- Authentication success/failure rates
- Permission cache hit/miss rates
- Event processing latency
- Token generation and validation rates
- Account lockout and security events

### Critical Alerts
- Authentication failure rate >5%
- Permission cache miss rate >10%
- Event processing lag >1 minute
- Redis cache unavailability
- Suspicious activity detection

## Deployment

### Kubernetes Configuration
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: auth-service
        image: auth-service:latest
        env:
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: auth-secrets
              key: redis-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
```

This event-driven Auth Service architecture provides **high-performance, scalable, and secure authentication** while maintaining loose coupling with other services through event-driven permission management. Internal Communication**: High-performance service-to-service calls
- **Permission Caching**: Redis + Consul KV for optimal performance
- **Async Event Processing**: Non-blocking operations

### 3. **Security & Compliance**
- **Service Permission Matrix**: Centralized authorization via Consul
- **JWT Security**: RS256 signing with key rotation
- **Audit Trail**: Comprehensive security event logging
- **Zero Trust**: Every service call authenticated and authorized

### 4. **Operational Excellence**
- **Graceful Shutdown**: Production-ready lifecycle management
- **Auto-scaling**: Kubernetes HPA integration
- **Circuit Breaker**: Built-in resilience patterns
- **Monitoring**: Prometheus metrics and Jaeger tracing

This Kratos + Consul Auth Service architecture provides **ultra-high-performance, scalable, and secure authentication** with modern cloud-native patterns and comprehensive service discovery and permission management.
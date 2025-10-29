# Auth Service - Event-Driven Architecture

## Description
High-performance, event-driven authentication service that provides **sub-50ms authentication** with decoupled permission management. Eliminates circular dependencies by owning only authentication data while caching permissions from other services via events.

## Architecture Philosophy

### Core Principles
1. **Auth Service owns authentication data only** (credentials, basic roles)
2. **Permission data is cached** from other services via events
3. **No direct service-to-service calls** during authentication
4. **Eventually consistent permissions** with fast fallback
5. **High-performance caching** for optimal user experience

### Event-Driven Flow
```
User/Customer Services ──events──▶ Auth Service ──cache──▶ Redis
                                       │
Client ──login──▶ Gateway ──auth──▶ Auth Service (20-50ms response)
                                       │
                                   JWT with full permissions
```

## Core Responsibilities
- **High-Performance Authentication**: Sub-50ms login with cached permissions
- **JWT Token Management**: Secure token generation, validation, and refresh
- **Event-Driven Permission Sync**: Real-time permission updates via events
- **Session Management**: Secure session handling with Redis
- **Security Auditing**: Comprehensive security event logging
- **Account Protection**: Advanced lockout and rate limiting

## Key Features

### Performance Optimizations
- **20-50ms authentication** with Redis permission cache
- **Local credential validation** (no external service calls)
- **Cached permission lookup** with 95%+ hit rate
- **Async event processing** for non-blocking operations

### Event-Driven Architecture
- **Real-time permission updates** via event bus
- **Eventually consistent permissions** across services
- **Automatic cache invalidation** on permission changes
- **Fallback to basic permissions** when cache unavailable

### Advanced Security
- **Multi-factor authentication (MFA)** support
- **Progressive lockout policies** with configurable thresholds
- **JWT security** with RS256 signing and key rotation
- **Suspicious activity detection** and alerting

## Outbound Data

### JWT Tokens (Primary Output)
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
    "customer_id": "cust_456"
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

### High-Performance Authentication
- `POST /v1/auth/login` - **20-50ms** user authentication with cached permissions
- `POST /v1/auth/logout` - User logout with token revocation
- `POST /v1/auth/refresh` - JWT token refresh with updated permissions
- `POST /v1/auth/register` - User registration (publishes user.created event)

### Token Management
- `POST /v1/auth/validate-token` - **<5ms** JWT token validation
- `POST /v1/auth/revoke-token` - Immediate token revocation
- `GET /v1/auth/token-info` - Token information with permissions

### Permission Management (Internal)
- `GET /v1/auth/internal/permissions/{userId}` - Get cached permissions
- `POST /v1/auth/internal/refresh-permissions` - Force permission refresh
- `POST /v1/auth/internal/invalidate-cache` - Invalidate user cache

### Security Management
- `POST /v1/auth/forgot-password` - Password reset with security validation
- `POST /v1/auth/change-password` - Secure password change
- `GET /v1/auth/security-events/{userId}` - User security event history

## Performance Metrics

### Authentication Performance
- **Average Response Time**: 20-50ms (vs 200-300ms traditional)
- **Cache Hit Rate**: >95% for permission lookups
- **Concurrent Users**: 10,000+ simultaneous authentications
- **Token Generation**: <5ms per JWT token

### Scalability Metrics
- **Throughput**: 10,000+ RPS per instance
- **Memory Usage**: <100MB for 100K cached users
- **Event Processing**: <10ms latency
- **Database Connections**: 50 connection pool

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

### Environment Variables
```env
# Database
AUTH_DB_HOST=localhost
AUTH_DB_PORT=5432
AUTH_DB_NAME=auth_service

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=secure_password
REDIS_MAX_CONNECTIONS=100

# JWT Configuration
JWT_PRIVATE_KEY_PATH=/secrets/jwt-private-key.pem
JWT_ACCESS_TOKEN_EXPIRATION=3600
JWT_REFRESH_TOKEN_EXPIRATION=86400

# Event Bus
EVENT_BUS_TYPE=redis
EVENT_BUS_URL=redis://localhost:6379
EVENT_CHANNELS=user_events,customer_events

# Performance
PERMISSION_CACHE_TTL=86400
ASYNC_EVENT_PROCESSING=true
MAX_CONCURRENT_AUTHENTICATIONS=10000

# Security
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=900
RATE_LIMIT_REQUESTS_PER_MINUTE=100
MFA_ENABLED=true
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

This event-driven Auth Service architecture provides **high-performance, scalable, and secure authentication** while maintaining loose coupling with other services through event-driven permission management.
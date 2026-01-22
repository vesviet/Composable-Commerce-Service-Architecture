# 🧑‍🤝‍🧑 Customer Service - Complete Documentation

**Service Name**: Customer Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Review Status**: ✅ Reviewed (Issues: 3 P0-P1)  
**Production Ready**: 85%  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [API Specifications](#-api-specifications)
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

Customer Service là microservice quản lý toàn bộ dữ liệu customer trong hệ thống e-commerce. Service này chịu trách nhiệm quản lý:

### Core Capabilities
- **👤 Customer Profile Management**: CRUD operations cho customer profiles
- **📍 Address Management**: Quản lý multiple addresses per customer với validation
- **⚙️ Customer Preferences**: Shopping preferences, communication settings
- **🎯 Customer Segmentation**: Dynamic segmentation cho marketing campaigns
- **📊 Analytics Integration**: Customer behavior tracking
- **🔐 Two-Factor Authentication**: 2FA support với TOTP
- **📱 Social Login**: OAuth integration (placeholder)
- **🗑️ GDPR Compliance**: Data deletion và anonymization

### Business Value
- **Customer Experience**: Seamless profile management across touchpoints
- **Marketing**: Rich customer segmentation cho personalized campaigns
- **Compliance**: GDPR-compliant data handling
- **Analytics**: Customer insights cho business decisions

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
customer/
├── cmd/customer/                    # Application entry point
├── internal/
│   ├── biz/                         # Business Logic Layer
│   │   ├── customer/                # Customer domain logic
│   │   ├── address/                 # Address domain logic
│   │   ├── preference/              # Preferences domain logic
│   │   ├── segment/                 # Segmentation logic
│   │   └── events/                  # Event publishing
│   ├── data/                        # Data Access Layer
│   │   ├── postgres/                # PostgreSQL repositories
│   │   └── eventbus/                # Dapr event bus
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
- **HTTP API**: `:8003` - REST endpoints cho frontend/client apps
- **gRPC API**: `:9003` - Internal service communication
- **Health Check**: `/api/v1/customers/health`

### Service Dependencies

#### Internal Dependencies
- **Auth Service**: Customer authentication & session validation
- **Order Service**: Order history integration
- **Loyalty Service**: Points & rewards integration
- **Notification Service**: Customer communications

#### External Dependencies
- **PostgreSQL**: Primary data store (`customer_db`)
- **Redis**: Caching layer cho performance
- **Dapr**: Event-driven communication
- **Consul**: Service discovery

---

## 🔌 API Specifications

### Core Customer Management APIs

#### Customer CRUD Operations
```protobuf
// Create new customer
rpc CreateCustomer(CreateCustomerRequest) returns (CreateCustomerReply) {
  option (google.api.http) = {
    post: "/api/v1/customers"
    body: "*"
  };
}

// Get customer by ID
rpc GetCustomer(GetCustomerRequest) returns (GetCustomerReply) {
  option (google.api.http) = {
    get: "/api/v1/customers/{id}"
  };
}

// List customers with filtering
rpc ListCustomers(ListCustomersRequest) returns (ListCustomersReply) {
  option (google.api.http) = {
    get: "/api/v1/customers"
  };
}
```

#### Address Management APIs
```protobuf
// Add customer address
rpc CreateAddress(CreateAddressRequest) returns (CreateAddressReply) {
  option (google.api.http) = {
    post: "/api/v1/customers/{customer_id}/addresses"
    body: "*"
  };
}

// Set default address (handles business logic automatically)
rpc SetDefaultAddress(SetDefaultAddressRequest) returns (SetDefaultAddressReply) {
  option (google.api.http) = {
    post: "/api/v1/customers/{customer_id}/addresses/{address_id}/set-default"
  };
}
```

#### Authentication APIs
```protobuf
// Customer registration
rpc Register(RegisterRequest) returns (RegisterReply) {
  option (google.api.http) = {
    post: "/api/v1/customers/register"
    body: "*"
  };
}

// Customer login
rpc Login(LoginRequest) returns (LoginReply) {
  option (google.api.http) = {
    post: "/api/v1/customers/login"
    body: "*"
  };
}
```

#### Two-Factor Authentication
```protobuf
// Enable 2FA for customer
rpc Enable2FA(Enable2FARequest) returns (Enable2FAReply) {
  option (google.api.http) = {
    post: "/api/v1/customers/{customer_id}/2fa/enable"
    body: "*"
  };
}

// Verify 2FA code
rpc Verify2FA(Verify2FARequest) returns (Verify2FAReply) {
  option (google.api.http) = {
    post: "/api/v1/customers/{customer_id}/2fa/verify"
    body: "*"
  };
}
```

### Request/Response Examples

#### Create Customer Request
```json
{
  "email": "customer@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1234567890",
  "date_of_birth": "1990-01-01T00:00:00Z",
  "gender": "MALE",
  "customer_type": "INDIVIDUAL",
  "registration_source": "WEBSITE"
}
```

#### Create Address Request
```json
{
  "customer_id": "uuid-here",
  "type": "SHIPPING",
  "first_name": "John",
  "last_name": "Doe",
  "address_line_1": "123 Main St",
  "city": "New York",
  "state_province": "NY",
  "postal_code": "10001",
  "country_code": "US",
  "is_default": true
}
```

---

## 🗄️ Database Schema

### Core Tables

#### customers
```sql
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  customer_type INTEGER NOT NULL DEFAULT 1,
  status INTEGER NOT NULL DEFAULT 2,
  email_verified BOOLEAN DEFAULT FALSE,
  registration_source VARCHAR(50),
  metadata JSONB DEFAULT '{}',
  customer_group_id VARCHAR(50),

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Soft delete
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

#### customer_addresses
```sql
CREATE TABLE customer_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id),
  type INTEGER NOT NULL DEFAULT 1,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  company VARCHAR(255),
  address_line_1 VARCHAR(255) NOT NULL,
  address_line_2 VARCHAR(255),
  city VARCHAR(100) NOT NULL,
  state_province VARCHAR(100),
  postal_code VARCHAR(20),
  country_code CHAR(2) NOT NULL,
  phone VARCHAR(20),
  is_default BOOLEAN DEFAULT FALSE,
  is_verified BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}',

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Soft delete
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

#### customer_preferences
```sql
CREATE TABLE customer_preferences (
  customer_id UUID PRIMARY KEY REFERENCES customers(id),
  email_marketing BOOLEAN DEFAULT TRUE,
  sms_marketing BOOLEAN DEFAULT FALSE,
  push_notifications BOOLEAN DEFAULT TRUE,
  newsletter BOOLEAN DEFAULT TRUE,
  data_sharing BOOLEAN DEFAULT FALSE,
  analytics_tracking BOOLEAN DEFAULT TRUE,
  cookie_consent BOOLEAN DEFAULT FALSE,
  order_updates BOOLEAN DEFAULT TRUE,
  promotional_emails BOOLEAN DEFAULT TRUE,
  custom_preferences JSONB DEFAULT '{}',

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Migration History

| Version | Migration File | Description | Key Features |
|---------|----------------|-------------|--------------|
| 001 | `001_create_customers_table.sql` | Customer profiles with triggers | Auto-timestamps, soft delete |
| 002 | `002_create_addresses_table.sql` | Address management | Validation, defaults |
| 003 | `003_create_segments_table.sql` | Customer segmentation | Auto-assignment logic |
| 004 | `004_add_legacy_id_support.sql` | Legacy system integration | Backward compatibility |
| 005 | `005_convert_enums_to_integer.sql` | Performance optimization | Integer enums for speed |
| 006 | `006_create_customer_profiles_table.sql` | Extended profiles | Phone, DOB, gender |
| 007 | `007_create_customer_preferences_table.sql` | Preferences management | Marketing consents |
| 008 | `008_migrate_existing_data.sql` | Data migration | Legacy data cleanup |
| 009 | `009_cleanup_customers_table.sql` | Schema optimization | Remove unused columns |
| 010 | `010_add_password_hash_to_customers.sql` | Authentication support | Password storage |
| 011 | `011_fix_segment_triggers_for_integer_enums.sql` | Trigger fixes | Integer enum compatibility |
| 012 | `012_add_metadata_to_addresses.sql` | Address metadata | Label, validation status |
| 013 | `013_create_wishlists_table.sql` | Wishlist feature | Product favorites |
| 014 | `014_add_gdpr_deletion_fields.sql` | GDPR compliance | Data anonymization |
| 015 | `015_add_customer_groups_support.sql` | Group management | B2B/B2C segmentation |
| 016 | `016_create_verification_tokens_table.sql` | Email verification | Token management |

### Indexes & Performance
```sql
-- Customer lookups
CREATE INDEX idx_customers_email ON customers(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_status ON customers(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_customer_group ON customers(customer_group_id) WHERE deleted_at IS NULL;

-- Address lookups
CREATE INDEX idx_addresses_customer_id ON customer_addresses(customer_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_addresses_customer_default ON customer_addresses(customer_id, is_default) WHERE deleted_at IS NULL AND is_default = TRUE;

-- Full-text search
CREATE INDEX idx_customers_full_name ON customers USING gin(to_tsvector('english', first_name || ' ' || last_name));
```

---

## 🧠 Business Logic

### Customer Domain Logic

#### Customer Creation Flow
```go
func (uc *CustomerUsecase) CreateCustomer(ctx context.Context, req *CreateCustomerRequest) (*model.Customer, error) {
    // 1. Validate input (email format, required fields)
    // 2. Check for existing customer (email uniqueness)
    // 3. Start transaction
    // 4. Create customer record
    // 5. Create customer profile
    // 6. Create default preferences
    // 7. Auto-assign default segments
    // 8. Publish customer.created event (AFTER transaction)
    // 9. Cache customer data
    // 10. Return customer with related data
}
```

#### Address Management Logic
```go
func (uc *AddressUsecase) CreateAddress(ctx context.Context, req *CreateAddressRequest) (*model.Address, error) {
    // 1. Validate address format (postal code by country)
    // 2. Standardize address components
    // 3. If is_default=true, unset other defaults first
    // 4. Create address record
    // 5. Publish address.created event
    // 6. Update cache
}

func (uc *AddressUsecase) DeleteAddress(ctx context.Context, id uuid.UUID) error {
    // 1. Get address and verify ownership
    // 2. Check if customer has other addresses
    // 3. If deleting default, auto-assign new default
    // 4. Delete address (soft delete)
    // 5. Publish address.deleted event
    // ⚠️ BUG: If auto-assign fails, customer left without default
}
```

### Segmentation Engine

#### Rules-Based Segmentation
```go
type SegmentRule struct {
    Field    string      `json:"field"`    // e.g., "total_orders"
    Operator string      `json:"operator"` // "gt", "lt", "eq", "contains"
    Value    interface{} `json:"value"`    // comparison value
    Weight   int         `json:"weight"`   // rule priority
}

func (uc *SegmentUsecase) EvaluateCustomerSegments(ctx context.Context, customerID uuid.UUID) error {
    // 1. Get customer data (orders, preferences, profile)
    // 2. Evaluate all active segment rules
    // 3. Calculate segment scores
    // 4. Assign top-scoring segments
    // 5. Publish segment assignment events
}
```

### Two-Factor Authentication (⚠️ INCOMPLETE)
```go
func (uc *TwoFactorUsecase) Verify2FACode(ctx context.Context, customerID uuid.UUID, code string) (bool, error) {
    // ⚠️ PLACEHOLDER IMPLEMENTATION
    // TODO: Implement proper TOTP validation using github.com/pquerna/otp
    return true, nil // ALWAYS RETURNS TRUE - SECURITY RISK
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
CUSTOMER_DATABASE_DSN=postgres://customer_user:customer_pass@postgres:5432/customer_db?sslmode=disable

# Redis Cache
CUSTOMER_REDIS_ADDR=redis:6379
CUSTOMER_REDIS_PASSWORD=

# Service Ports
CUSTOMER_HTTP_PORT=8003
CUSTOMER_GRPC_PORT=9003

# External Services
CUSTOMER_AUTH_SERVICE_ADDR=auth-service:9001
CUSTOMER_ORDER_SERVICE_ADDR=order-service:9004
CUSTOMER_LOYALTY_SERVICE_ADDR=loyalty-service:9011

# Feature Flags
CUSTOMER_ENABLE_SEGMENTS=true
CUSTOMER_ENABLE_ANALYTICS=true
CUSTOMER_ENABLE_2FA=true

# Security
CUSTOMER_JWT_SECRET=your-secret-key
CUSTOMER_BCRYPT_COST=12

# Observability
CUSTOMER_LOG_LEVEL=info
CUSTOMER_METRICS_ENABLED=true
CUSTOMER_TRACING_ENABLED=true
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: customer-service
  version: 1.0.0

database:
  dsn: ${CUSTOMER_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 25
  conn_max_lifetime: 5m

redis:
  addr: ${CUSTOMER_REDIS_ADDR}
  password: ${CUSTOMER_REDIS_PASSWORD}
  db: 0
  dial_timeout: 5s
  read_timeout: 3s
  write_timeout: 3s

server:
  http:
    addr: 0.0.0.0
    port: ${CUSTOMER_HTTP_PORT}
  grpc:
    addr: 0.0.0.0
    port: ${CUSTOMER_GRPC_PORT}

external_services:
  auth_service: ${CUSTOMER_AUTH_SERVICE_ADDR}
  order_service: ${CUSTOMER_ORDER_SERVICE_ADDR}
  loyalty_service: ${CUSTOMER_LOYALTY_SERVICE_ADDR}

features:
  segments: ${CUSTOMER_ENABLE_SEGMENTS}
  analytics: ${CUSTOMER_ENABLE_ANALYTICS}
  two_factor: ${CUSTOMER_ENABLE_2FA}

security:
  jwt_secret: ${CUSTOMER_JWT_SECRET}
  bcrypt_cost: ${CUSTOMER_BCRYPT_COST}

observability:
  log_level: ${CUSTOMER_LOG_LEVEL}
  metrics_enabled: ${CUSTOMER_METRICS_ENABLED}
  tracing_enabled: ${CUSTOMER_TRACING_ENABLED}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/customer

go 1.24

require (
    gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/google/uuid v1.6.0
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    gorm.io/driver/postgres v1.5.7
    github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    github.com/golang-jwt/jwt/v5 v5.2.1
)
```

### Internal Dependencies
- **common@v1.0.14**: Shared utilities, validation, events, repository patterns
- **Auth Service**: Customer authentication, session validation
- **Order Service**: Order history, customer analytics
- **Loyalty Service**: Points balance, rewards integration
- **Notification Service**: Email/SMS delivery for customer communications

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: 65% coverage (business logic)
- **Integration Tests**: 40% coverage (API endpoints, database)
- **E2E Tests**: 20% coverage (critical user journeys)

### Test Structure
```
customer/
├── internal/
│   ├── biz/
│   │   ├── customer/
│   │   │   └── user_enhanced_test.go    # Customer logic tests
│   │   └── address/
│   │       └── address_test.go          # Address logic tests
│   └── data/
│       └── postgres/
│           └── customer_test.go         # Repository tests
├── integration_test.go                  # API integration tests
└── test fixtures/                       # Test data
```

### Key Test Cases
```go
func TestCustomerUsecase_CreateCustomer(t *testing.T) {
    // Test successful customer creation
    // Test duplicate email rejection
    // Test invalid email format
    // Test transaction rollback on failure
}

func TestAddressUsecase_DeleteDefaultAddress(t *testing.T) {
    // ⚠️ MISSING: Test for default address reassignment bug
    // Should verify new default is set when deleting current default
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

# Specific package
go test ./internal/biz/customer/...
```

---

## 📊 Monitoring & Observability

### Metrics (Prometheus)
```go
// Request metrics
customer_requests_total{endpoint="/api/v1/customers", method="POST", status="200"} 1250

// Business metrics
customer_created_total 1250
customer_addresses_total 3400
customer_segments_assigned_total 980

// Performance metrics
customer_request_duration_seconds{quantile="0.95", endpoint="/api/v1/customers"} 0.087

// Error metrics
customer_errors_total{type="validation", endpoint="/api/v1/customers"} 23
```

### Health Checks
```go
// HTTP Health Check
GET /api/v1/customers/health

// gRPC Health Check
rpc HealthCheck(HealthCheckRequest) returns (HealthCheckReply)

// Database connectivity
// Redis connectivity
// External service dependencies
```

### Logging
```json
{
  "level": "info",
  "ts": "2026-01-22T10:30:15Z",
  "caller": "customer/service/customer.go:45",
  "msg": "Customer created successfully",
  "customer_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "customer@example.com",
  "trace_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "duration_ms": 87
}
```

### Distributed Tracing (OpenTelemetry)
- **Customer Creation**: Full trace from API → Validation → DB → Cache → Events
- **Address Operations**: Address validation → Geocoding → DB operations
- **Segmentation**: Rule evaluation → Database queries → Assignment logic

---

## 🚨 Known Issues & TODOs

### P0 - Critical (Security/Data Integrity)
1. **Transactional Outbox Missing** 🚨
   - **Issue**: Events published after DB transaction commit
   - **Risk**: Event loss on service crash, data inconsistency
   - **Location**: `customer/internal/biz/customer/customer.go:243`
   - **Fix**: Implement transactional outbox pattern

2. **2FA Verification Placeholder** 🚨
   - **Issue**: `Verify2FACode` always returns `true`
   - **Risk**: Complete bypass of 2FA security
   - **Location**: `customer/internal/biz/customer/two_factor.go:105`
   - **Fix**: Implement TOTP validation with `github.com/pquerna/otp`

### P1 - High Priority (Reliability)
3. **Address Delete Default Logic Flawed** 🟡
   - **Issue**: Silent failure when setting new default address
   - **Risk**: Customers left without default address
   - **Location**: `customer/internal/biz/address/address.go:479-490`
   - **Fix**: Add error handling and rollback logic

### P2 - Medium Priority (Technical Debt)
4. **Missing Integration Tests** 🔵
   - **Issue**: No end-to-end customer registration → address setup flow
   - **Impact**: Undetected integration bugs
   - **Fix**: Add comprehensive integration test suite

5. **Hardcoded Customer Groups** 🔵
   - **Issue**: Default customer groups hardcoded
   - **Location**: `customer/internal/biz/customer/customer.go:167-172`
   - **Fix**: Make configurable via config service

6. **GDPR Deletion Incomplete** 🔵
   - **Issue**: Data anonymization not fully implemented
   - **Location**: GDPR deletion endpoints
   - **Fix**: Implement complete data anonymization logic

---

## 🚀 Development Guide

### Local Development Setup
```bash
# Clone and setup
git clone git@gitlab.com:ta-microservices/customer.git
cd customer

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

# Run tests
make test
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
make migrate-create NAME="add_customer_tags"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

### API Development Workflow
1. **Update Proto Definition**: `api/customer/v1/customer.proto`
2. **Generate Code**: `make api`
3. **Implement Service**: `internal/service/customer.go`
4. **Add Business Logic**: `internal/biz/customer/`
5. **Add Repository**: `internal/data/postgres/`
6. **Add Tests**: Unit + Integration tests
7. **Update Documentation**: This file

### Deployment
```bash
# Build for production
make build

# Docker build
make docker-build

# Deploy to staging
kubectl apply -f k8s/staging/

# Check deployment
kubectl logs -f deployment/customer-service -n staging
```

---

## 📈 Performance Benchmarks

### API Response Times (P95)
- **Create Customer**: 120ms
- **Get Customer**: 45ms
- **List Customers**: 78ms (with pagination)
- **Create Address**: 95ms
- **Address Validation**: 150ms (with geocoding)

### Throughput Targets
- **Read Operations**: 500 req/sec
- **Write Operations**: 200 req/sec
- **Concurrent Users**: 10,000+

### Database Performance
- **Customer Queries**: <10ms average
- **Address Operations**: <15ms average
- **Segmentation**: <50ms for rule evaluation

---

## 🔐 Security Considerations

### Authentication & Authorization
- **JWT Tokens**: HS256 signed tokens from Auth Service
- **Session Validation**: External session validation
- **API Keys**: Service-to-service authentication
- **Rate Limiting**: Implemented at gateway level

### Data Protection
- **PII Encryption**: Sensitive data encrypted at rest
- **GDPR Compliance**: Right to deletion, data portability
- **Audit Logging**: All customer data changes logged
- **Access Control**: Role-based permissions for admin operations

### Security Headers
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000
```

---

## 🎯 Future Roadmap

### Phase 1 (Q1 2026) - Core Completion
- [ ] Complete 2FA implementation
- [ ] Implement transactional outbox
- [ ] Fix address deletion logic
- [ ] Add comprehensive integration tests

### Phase 2 (Q2 2026) - Advanced Features
- [ ] Social login integration (Google, Facebook, Apple)
- [ ] Advanced customer segmentation (ML-based)
- [ ] Customer analytics dashboard
- [ ] Real-time customer insights
- [ ] Enhanced GDPR compliance features

### Phase 3 (Q3 2026) - Scale & Performance
- [ ] Database sharding for customer data
- [ ] Global CDN for customer assets
- [ ] Advanced caching strategies
- [ ] Real-time customer synchronization

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: Customer Service Team
- **Repository**: `gitlab.com/ta-microservices/customer`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #customer-service-alerts
- **Performance Issues**: #customer-service-performance
- **Security Issues**: #security-incidents

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/customer-service`
- **Business Metrics**: `https://grafana.tanhdev.com/d/customer-analytics`
- **Error Tracking**: `https://sentry.tanhdev.com/customer-service`

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Code Review Status**: ✅ Completed (3 issues identified)  
**Production Readiness**: 85% (P0 issues must be fixed)
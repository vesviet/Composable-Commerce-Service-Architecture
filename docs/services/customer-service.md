# Customer Service

> **Service Type**: Application Service (Business Logic)  
> **Architecture**: Pure Microservice - Single Tenant  
> **Last Updated**: November 1, 2024  
> **Status**: Architecture Finalized - Ready for Implementation

---

## 📋 Service Overview

### Description
Pure microservice that manages customer information, profiles, preferences, and lifecycle management. Built with single-tenant architecture for maximum performance and simplicity, focusing on core customer domain without multi-tenant complexity.

### Business Context
The Customer Service serves as the single source of truth for customer-related data in our e-commerce platform. It provides high-performance customer management with clean domain boundaries, optimized for single-store operations with the flexibility to evolve to multi-tenant when needed.

### Key Responsibilities
- **Core Customer Management**: Profile, authentication, and account lifecycle
- **Address Management**: Customer address book with validation
- **Preference Management**: Communication and privacy preferences
- **Customer Segmentation**: Business logic for customer categorization
- **Data Migration**: Legacy Magento customer data migration support
- **Event Publishing**: Customer lifecycle events for other services

### Architecture Decision
**Selected: Option 3A - Pure Microservice Architecture (Single Tenant)**

**Rationale:**
- ✅ **Maximum Performance**: No multi-tenant overhead, optimized queries
- ✅ **Simplicity First**: Clean domain model, straightforward business logic
- ✅ **Fast Development**: Rapid time to market, easy testing and debugging
- ✅ **Evolutionary**: Can add multi-tenancy later when business requires it
- ✅ **Microservice Best Practices**: Domain-driven design, loose coupling

---

## 🏗️ Architecture

### Service Type
- [x] Application Service (Business Logic)
- [ ] Infrastructure Service (Supporting)
- [ ] Gateway Service (API Gateway/BFF)

### Technology Stack
- **Framework**: go-kratos/kratos v2.7+
- **Database**: PostgreSQL 15+ (optimized flat tables)
- **Cache**: Redis 7+ (customer profiles, session data)
- **Message Queue**: Dapr Pub/Sub with Redis Streams
- **Migration**: Legacy ID mapping for Magento compatibility

### Deployment
- **Container**: Docker
- **Orchestration**: Kubernetes with Dapr
- **Service Discovery**: Consul
- **Load Balancer**: Kubernetes Service + Ingress
- **Scaling**: Horizontal auto-scaling based on CPU/memory

---

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/customers
Staging: https://staging-api.domain.com/v1/customers
Local: http://localhost:8007/v1/customers
```

### Authentication
- **Type**: JWT Bearer Token
- **Required Scopes**: `customers:read`, `customers:write`, `customers:admin`
- **Rate Limiting**: 1000 requests/minute per user

### Customer Management APIs

#### GET /customers/{customerId}
**Purpose**: Get comprehensive customer information

**Request**:
```http
GET /v1/customers/cust_456
Authorization: Bearer {jwt_token}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "cust_456",
      "email": "john.doe@example.com",
      "profile": {
        "firstName": "John",
        "lastName": "Doe",
        "dateOfBirth": "1985-06-15",
        "gender": "male",
        "phone": "+1-555-0123",
        "avatar": "https://cdn.domain.com/avatars/cust_456.jpg"
      },
      "segment": {
        "tier": "premium",
        "segment": "high_value",
        "loyaltyPoints": 2500,
        "totalSpent": 5420.50,
        "orderCount": 23,
        "averageOrderValue": 235.67
      },
      "preferences": {
        "language": "en",
        "currency": "USD",
        "timezone": "America/New_York",
        "marketing": {
          "emailOptIn": true,
          "smsOptIn": false,
          "pushOptIn": true
        },
        "notifications": {
          "orderUpdates": true,
          "promotions": true,
          "newsletters": false
        }
      },
      "status": "active",
      "registrationDate": "2023-01-15T10:00:00Z",
      "lastLoginAt": "2024-10-29T14:30:00Z",
      "createdAt": "2023-01-15T10:00:00Z",
      "updatedAt": "2024-10-29T14:30:00Z"
    }
  }
}
```

#### PUT /customers/{customerId}
**Purpose**: Update customer profile information

**Request**:
```http
PUT /v1/customers/cust_456
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "profile": {
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1-555-0124",
    "dateOfBirth": "1985-06-15"
  },
  "preferences": {
    "language": "en",
    "currency": "USD",
    "marketing": {
      "emailOptIn": true,
      "smsOptIn": true
    }
  }
}
```

#### POST /customers
**Purpose**: Create new customer account

**Request**:
```http
POST /v1/customers
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "email": "jane.smith@example.com",
  "password": "securePassword123",
  "profile": {
    "firstName": "Jane",
    "lastName": "Smith",
    "phone": "+1-555-0125"
  },
  "preferences": {
    "language": "en",
    "currency": "USD",
    "marketing": {
      "emailOptIn": true
    }
  }
}
```

#### DELETE /customers/{customerId}
**Purpose**: Deactivate customer account (GDPR compliance)

### Address Management APIs

#### GET /customers/{customerId}/addresses
**Purpose**: Get customer's address book

**Response**:
```json
{
  "success": true,
  "data": {
    "addresses": [
      {
        "id": "addr_123",
        "type": "shipping",
        "isDefault": true,
        "firstName": "John",
        "lastName": "Doe",
        "company": "",
        "street": "123 Main St",
        "street2": "Apt 4B",
        "city": "New York",
        "state": "NY",
        "zipCode": "10001",
        "country": "US",
        "phone": "+1-555-0123",
        "createdAt": "2023-01-15T10:00:00Z"
      },
      {
        "id": "addr_124",
        "type": "billing",
        "isDefault": true,
        "firstName": "John",
        "lastName": "Doe",
        "street": "456 Business Ave",
        "city": "New York",
        "state": "NY",
        "zipCode": "10002",
        "country": "US",
        "createdAt": "2023-02-01T10:00:00Z"
      }
    ]
  }
}
```

#### POST /customers/{customerId}/addresses
**Purpose**: Add new address to customer's address book

#### PUT /customers/{customerId}/addresses/{addressId}
**Purpose**: Update existing address

#### DELETE /customers/{customerId}/addresses/{addressId}
**Purpose**: Remove address from address book

### Customer Segmentation APIs

#### GET /customers/{customerId}/segment
**Purpose**: Get customer segment and tier information

**Response**:
```json
{
  "success": true,
  "data": {
    "segment": {
      "customerId": "cust_456",
      "tier": "premium",
      "segment": "high_value",
      "loyaltyPoints": 2500,
      "metrics": {
        "totalSpent": 5420.50,
        "orderCount": 23,
        "averageOrderValue": 235.67,
        "lastOrderDate": "2024-10-25T10:00:00Z",
        "daysSinceLastOrder": 5,
        "lifetimeValue": 5420.50
      },
      "qualifications": {
        "premiumTier": {
          "qualified": true,
          "requirement": "totalSpent >= 1000",
          "achievedAt": "2023-06-15T10:00:00Z"
        },
        "highValueSegment": {
          "qualified": true,
          "requirement": "averageOrderValue >= 200",
          "achievedAt": "2023-08-20T10:00:00Z"
        }
      },
      "nextTier": {
        "tier": "vip",
        "requirement": "totalSpent >= 10000",
        "progress": 54.21,
        "remaining": 4579.50
      },
      "updatedAt": "2024-10-29T10:00:00Z"
    }
  }
}
```

#### PUT /customers/{customerId}/segment
**Purpose**: Update customer segment (admin only)

### Customer Analytics APIs

#### GET /customers/{customerId}/analytics
**Purpose**: Get customer behavior analytics

#### GET /customers/{customerId}/orders/summary
**Purpose**: Get customer order history summary

#### GET /customers/segments
**Purpose**: Get all customer segments (admin only)

## 🗄️ Database Schema

### Primary Database: PostgreSQL (Single Tenant - Optimized)

#### customers (Core Entity)
```sql
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id INTEGER UNIQUE, -- For Magento migration mapping
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    customer_type VARCHAR(20) DEFAULT 'individual' CHECK (customer_type IN ('individual', 'business')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'pending')),
    email_verified BOOLEAN DEFAULT FALSE,
    registration_source VARCHAR(50),
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Optimized indexes for single tenant
CREATE INDEX idx_customers_email ON customers(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_legacy_id ON customers(legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX idx_customers_status ON customers(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_type ON customers(customer_type);
CREATE INDEX idx_customers_created_at ON customers(created_at);
```

#### customer_profiles (Extended Data)
```sql
CREATE TABLE customer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID UNIQUE REFERENCES customers(id) ON DELETE CASCADE,
    phone VARCHAR(20),
    date_of_birth DATE,
    gender VARCHAR(20) CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    phone_verified BOOLEAN DEFAULT FALSE,
    -- Flexible profile data as structured JSON
    profile_data JSONB DEFAULT '{}',
    -- Business metadata (Magento legacy data, etc.)
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_profiles_customer_id ON customer_profiles(customer_id);
CREATE INDEX idx_profiles_phone ON customer_profiles(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_profiles_data ON customer_profiles USING GIN(profile_data);
```

#### customer_preferences (Settings)
```sql
CREATE TABLE customer_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID UNIQUE REFERENCES customers(id) ON DELETE CASCADE,
    -- Communication preferences
    email_marketing BOOLEAN DEFAULT TRUE,
    sms_marketing BOOLEAN DEFAULT FALSE,
    push_notifications BOOLEAN DEFAULT TRUE,
    newsletter BOOLEAN DEFAULT TRUE,
    -- Privacy preferences
    data_sharing BOOLEAN DEFAULT FALSE,
    analytics_tracking BOOLEAN DEFAULT TRUE,
    cookie_consent BOOLEAN DEFAULT FALSE,
    -- Notification preferences
    order_updates BOOLEAN DEFAULT TRUE,
    promotional_emails BOOLEAN DEFAULT TRUE,
    -- Custom preferences as JSON
    custom_preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_preferences_customer_id ON customer_preferences(customer_id);
CREATE INDEX idx_preferences_marketing ON customer_preferences(email_marketing, sms_marketing);
```

#### customer_addresses (Separate Domain)
```sql
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id INTEGER UNIQUE, -- For Magento migration
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type VARCHAR(20) DEFAULT 'shipping' CHECK (type IN ('shipping', 'billing', 'both')),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company VARCHAR(255),
    address_line_1 VARCHAR(255) NOT NULL,
    address_line_2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(100),
    postal_code VARCHAR(20),
    country_code VARCHAR(2) NOT NULL,
    phone VARCHAR(20),
    is_default BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_addresses_customer_id ON customer_addresses(customer_id);
CREATE INDEX idx_addresses_legacy_id ON customer_addresses(legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX idx_addresses_type ON customer_addresses(type);
CREATE INDEX idx_addresses_default ON customer_addresses(is_default) WHERE is_default = TRUE;
CREATE INDEX idx_addresses_country ON customer_addresses(country_code);
```

#### customer_segments (Business Logic)
```sql
CREATE TABLE customer_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rules JSONB NOT NULL, -- Segment rules as JSON
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE customer_segment_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    segment_id UUID NOT NULL REFERENCES customer_segments(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by VARCHAR(50) DEFAULT 'system',
    
    UNIQUE(customer_id, segment_id)
);

CREATE INDEX idx_segments_active ON customer_segments(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_segment_memberships_customer ON customer_segment_memberships(customer_id);
CREATE INDEX idx_segment_memberships_segment ON customer_segment_memberships(segment_id);
```

### Cache Schema (Redis) - Single Tenant Optimized
```
# Customer profile cache (with related data)
Key: customers:profile:{customer_id}
TTL: 3600 seconds (1 hour)
Value: JSON serialized customer with profile and preferences

# Customer addresses cache
Key: customers:addresses:{customer_id}
TTL: 7200 seconds (2 hours)
Value: JSON serialized address list

# Customer segments cache
Key: customers:segments:{customer_id}
TTL: 1800 seconds (30 minutes)
Value: JSON serialized segment memberships

# Legacy ID mapping cache (for migration)
Key: customers:legacy:{legacy_id}
TTL: 86400 seconds (24 hours)
Value: UUID customer_id

# Customer session cache
Key: customers:session:{session_id}
TTL: 1800 seconds (30 minutes)
Value: Customer session data
```

### Migration Support Tables
```sql
-- Optional: Separate mapping table for complex migration scenarios
CREATE TABLE migration_id_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL, -- 'customer', 'address', etc.
    legacy_id INTEGER NOT NULL,
    new_id UUID NOT NULL,
    magento_website_id INTEGER,
    magento_store_id INTEGER,
    migration_batch VARCHAR(50),
    migrated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(entity_type, legacy_id)
);

CREATE INDEX idx_mapping_legacy_id ON migration_id_mapping(entity_type, legacy_id);
CREATE INDEX idx_mapping_new_id ON migration_id_mapping(new_id);
CREATE INDEX idx_mapping_batch ON migration_id_mapping(migration_batch);
```

## 👥 Customer Segmentation Logic (Simplified)

### Domain Models
```go
// Core customer domain model
type Customer struct {
    ID                 string                 `json:"id"`
    LegacyID           *int                   `json:"legacy_id,omitempty"`
    Email              string                 `json:"email"`
    FirstName          string                 `json:"first_name"`
    LastName           string                 `json:"last_name"`
    CustomerType       string                 `json:"customer_type"`
    Status             string                 `json:"status"`
    EmailVerified      bool                   `json:"email_verified"`
    RegistrationSource string                 `json:"registration_source"`
    LastLoginAt        *time.Time             `json:"last_login_at,omitempty"`
    CreatedAt          time.Time              `json:"created_at"`
    UpdatedAt          time.Time              `json:"updated_at"`
    
    // Related data (loaded separately for performance)
    Profile     *CustomerProfile     `json:"profile,omitempty"`
    Preferences *CustomerPreferences `json:"preferences,omitempty"`
    Addresses   []CustomerAddress    `json:"addresses,omitempty"`
    Segments    []string             `json:"segments,omitempty"`
}

type CustomerProfile struct {
    CustomerID    string                 `json:"customer_id"`
    Phone         *string                `json:"phone,omitempty"`
    DateOfBirth   *time.Time             `json:"date_of_birth,omitempty"`
    Gender        string                 `json:"gender"`
    PhoneVerified bool                   `json:"phone_verified"`
    ProfileData   map[string]interface{} `json:"profile_data"`
    Metadata      map[string]interface{} `json:"metadata"`
}

type CustomerPreferences struct {
    CustomerID         string                 `json:"customer_id"`
    EmailMarketing     bool                   `json:"email_marketing"`
    SmsMarketing       bool                   `json:"sms_marketing"`
    PushNotifications  bool                   `json:"push_notifications"`
    Newsletter         bool                   `json:"newsletter"`
    DataSharing        bool                   `json:"data_sharing"`
    AnalyticsTracking  bool                   `json:"analytics_tracking"`
    CustomPreferences  map[string]interface{} `json:"custom_preferences"`
}
```

### Simple Service Layer
```go
type CustomerService struct {
    customerRepo    CustomerRepository
    profileRepo     CustomerProfileRepository
    preferencesRepo CustomerPreferencesRepository
    addressRepo     CustomerAddressRepository
    segmentRepo     CustomerSegmentRepository
    logger          log.Logger
}

func (s *CustomerService) GetCustomer(ctx context.Context, customerID string) (*Customer, error) {
    return s.customerRepo.GetByID(ctx, customerID)
}

func (s *CustomerService) GetCustomerWithDetails(ctx context.Context, customerID string) (*Customer, error) {
    customer, err := s.customerRepo.GetByID(ctx, customerID)
    if err != nil {
        return nil, fmt.Errorf("failed to get customer: %w", err)
    }
    
    // Load related data in parallel
    g, ctx := errgroup.WithContext(ctx)
    
    var profile *CustomerProfile
    var preferences *CustomerPreferences
    var addresses []CustomerAddress
    var segments []string
    
    g.Go(func() error {
        profile, _ = s.profileRepo.GetByCustomerID(ctx, customerID)
        return nil
    })
    
    g.Go(func() error {
        preferences, _ = s.preferencesRepo.GetByCustomerID(ctx, customerID)
        return nil
    })
    
    g.Go(func() error {
        addresses, _ = s.addressRepo.GetByCustomerID(ctx, customerID)
        return nil
    })
    
    g.Go(func() error {
        segments, _ = s.segmentRepo.GetCustomerSegments(ctx, customerID)
        return nil
    })
    
    g.Wait()
    
    // Attach related data
    customer.Profile = profile
    customer.Preferences = preferences
    customer.Addresses = addresses
    customer.Segments = segments
    
    return customer, nil
}
```

### Default Segment Types (Simplified)
- **all-customers**: Universal segment for all registered customers
- **new-customers**: Customers registered in the last 30 days
- **regular-customers**: Standard customer segment (migrated from Magento "General" group)
- **wholesale-customers**: B2B customers (migrated from Magento "Wholesale" group)
- **vip-customers**: High-value customers (based on order history)

## 📨 Event Schemas

### Published Events

#### CustomerCreated
**Topic**: `customers.customer.created`
**Version**: 1.0

```json
{
  "eventId": "evt_customer_123",
  "eventType": "CustomerCreated",
  "version": "1.0",
  "timestamp": "2024-10-30T10:00:00Z",
  "source": "customer-service",
  "data": {
    "customerId": "cust_456",
    "email": "john.doe@example.com",
    "profile": {
      "firstName": "John",
      "lastName": "Doe"
    },
    "segment": {
      "tier": "regular",
      "segment": "new_customer"
    },
    "registrationDate": "2024-10-30T10:00:00Z"
  },
  "metadata": {
    "correlationId": "corr_registration_123"
  }
}
```

#### CustomerSegmentChanged
**Topic**: `customers.segment.changed`
**Version**: 1.0

#### CustomerProfileUpdated
**Topic**: `customers.profile.updated`
**Version**: 1.0

#### CustomerDeactivated
**Topic**: `customers.customer.deactivated`
**Version**: 1.0

### Subscribed Events

#### OrderCompleted
**Topic**: `orders.order.completed`
**Source**: order-service

#### LoyaltyPointsEarned
**Topic**: `loyalty.points.earned`
**Source**: loyalty-rewards-service

## 🔗 Service Dependencies

### Upstream Dependencies

#### Order Service
- **Purpose**: Get customer order history and metrics
- **Endpoints Used**: `/orders/customer/{id}/summary`
- **Fallback Strategy**: Use cached order data
- **SLA Requirements**: < 200ms response time

#### Loyalty & Rewards Service
- **Purpose**: Get loyalty points and tier information
- **Endpoints Used**: `/loyalty/customer/{id}/points`
- **Fallback Strategy**: Use cached loyalty data

### Downstream Dependencies

#### Order Service
- **Purpose**: Provide customer information for orders
- **Endpoints Used**: This service's customer APIs
- **Usage Pattern**: High frequency during checkout

#### Promotion Service
- **Purpose**: Provide customer segmentation for targeted promotions
- **Endpoints Used**: `/customers/{id}/segment`
- **Usage Pattern**: Real-time during promotion validation

## ⚙️ Configuration

### Environment Variables (Single Tenant)
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/customers_db
DATABASE_MAX_CONNECTIONS=25
DATABASE_IDLE_CONNECTIONS=5

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_TTL_PROFILE=3600
REDIS_TTL_ADDRESSES=7200
REDIS_TTL_SEGMENTS=1800
REDIS_TTL_LEGACY_MAPPING=86400

# Service Discovery
CONSUL_URL=http://localhost:8500
SERVICE_NAME=customer-service
SERVICE_PORT=8007
HEALTH_CHECK_INTERVAL=10s

# Migration Support
MAGENTO_DB_URL=mysql://user:pass@localhost:3306/magento2
MIGRATION_BATCH_SIZE=1000
MIGRATION_WORKERS=4

# Customer Configuration
DEFAULT_CUSTOMER_TYPE=individual
DEFAULT_STATUS=pending
EMAIL_VERIFICATION_REQUIRED=true
PHONE_VERIFICATION_REQUIRED=false
MAX_ADDRESSES_PER_CUSTOMER=10

# Security
PASSWORD_MIN_LENGTH=8
SESSION_TIMEOUT=1800
JWT_SECRET=your-jwt-secret
BCRYPT_COST=12

# Performance
CACHE_ENABLED=true
PARALLEL_LOADING=true
MAX_CONCURRENT_REQUESTS=1000
```

## 🚨 Error Handling

### Error Codes
| Code | HTTP Status | Description | Retry Strategy |
|------|-------------|-------------|----------------|
| CUSTOMER_NOT_FOUND | 404 | Customer does not exist | No retry |
| EMAIL_ALREADY_EXISTS | 409 | Email already registered | No retry |
| INVALID_EMAIL_FORMAT | 400 | Invalid email format | No retry |
| WEAK_PASSWORD | 400 | Password doesn't meet requirements | No retry |
| ADDRESS_LIMIT_EXCEEDED | 400 | Too many addresses (max 10) | No retry |
| SEGMENT_UPDATE_FAILED | 500 | Failed to update customer segment | Retry with backoff |

## ⚡ Performance & SLAs

### Performance Targets (Single Tenant Optimized)
- **Response Time**: 
  - P50: < 30ms (improved with flat tables)
  - P95: < 100ms (no EAV overhead)
  - P99: < 200ms (optimized queries)
- **Throughput**: 2000+ requests/second (single tenant performance)
- **Availability**: 99.9% uptime
- **Cache Hit Ratio**: > 90% (simplified caching strategy)

### Scaling Strategy
- **Horizontal Scaling**: Stateless service, easy auto-scaling
- **Database**: Optimized indexes, read replicas for heavy read operations
- **Cache**: Redis for customer profiles and session data
- **Load Balancing**: Round-robin (no session affinity needed)
- **Migration**: Parallel processing for Magento data migration

## 🔄 Migration Support

### Legacy ID Mapping
- **Purpose**: Maintain compatibility with Magento entity IDs
- **Implementation**: `legacy_id` fields in core tables
- **Benefits**: Easy data sync, API compatibility, rollback support

### Migration Utilities
```go
// Get customer by Magento entity_id
func (s *CustomerService) GetCustomerByLegacyID(ctx context.Context, legacyID int) (*Customer, error) {
    return s.customerRepo.GetByLegacyID(ctx, legacyID)
}

// Support both UUID and legacy ID in APIs
func (s *CustomerService) GetCustomerByIDOrLegacy(ctx context.Context, identifier string) (*Customer, error) {
    // Try UUID first
    if uuid, err := uuid.Parse(identifier); err == nil {
        return s.GetCustomer(ctx, uuid.String())
    }
    
    // Try legacy ID
    if legacyID, err := strconv.Atoi(identifier); err == nil {
        return s.GetCustomerByLegacyID(ctx, legacyID)
    }
    
    return nil, ErrInvalidCustomerID
}
```

## 🚀 Future Evolution Path

### Phase 1: Single Tenant Core (Current)
- ✅ Core customer CRUD operations
- ✅ Profile and preferences management
- ✅ Address management
- ✅ Basic segmentation
- ✅ Magento migration support

### Phase 2: Enhanced Features
- [ ] Advanced customer analytics
- [ ] Real-time segmentation updates
- [ ] Customer journey tracking
- [ ] Advanced preference management

### Phase 3: Multi-tenant Support (If Needed)
- [ ] Add `tenant_id` fields to existing tables
- [ ] Tenant-aware service layer
- [ ] Tenant configuration management
- [ ] Multi-store customer management

---

**Document Status**: Architecture Finalized - Ready for Implementation  
**Architecture**: Pure Microservice - Single Tenant  
**Next Review Date**: December 1, 2024  
**Service Owner**: Customer Experience Team  
**Technical Lead**: Backend Development Team
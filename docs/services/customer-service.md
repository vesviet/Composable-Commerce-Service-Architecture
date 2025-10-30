# Customer Service

> **Service Type**: Application Service (Business Logic)  
> **Last Updated**: October 30, 2024  
> **Status**: Complete Documentation

---

## 📋 Service Overview

### Description
Service that manages comprehensive customer information, profiles, preferences, and customer lifecycle management. Provides centralized customer data management with advanced segmentation, loyalty tracking, and personalization capabilities.

### Business Context
The Customer Service serves as the single source of truth for all customer-related data, enabling personalized experiences across the e-commerce platform. It manages customer profiles, addresses, preferences, loyalty status, and provides customer segmentation for targeted marketing and promotions.

### Key Responsibilities
- Customer profile and account management
- Address book and contact information management
- Customer segmentation and tier management
- Loyalty points and rewards tracking
- Customer preferences and communication settings
- Purchase history and behavior analytics
- Customer lifecycle management
- GDPR compliance and data privacy

---

## 🏗️ Architecture

### Service Type
- [x] Application Service (Business Logic)
- [ ] Infrastructure Service (Supporting)
- [ ] Gateway Service (API Gateway/BFF)

### Technology Stack
- **Framework**: go-kratos/kratos v2.7+
- **Database**: PostgreSQL 15+ (customer profiles, addresses)
- **Cache**: Redis 7+ (customer session cache, profile cache)
- **Message Queue**: Dapr Pub/Sub with Redis Streams
- **External APIs**: Order Service, Loyalty Service, Analytics Service

### Deployment
- **Container**: Docker
- **Orchestration**: Kubernetes with Dapr
- **Service Discovery**: Consul
- **Load Balancer**: Kubernetes Service + Ingress

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

### Primary Database: PostgreSQL

#### customers
```sql
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    
    -- Profile information
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    gender VARCHAR(10),
    phone VARCHAR(20),
    avatar_url VARCHAR(500),
    
    -- Account status
    status VARCHAR(20) DEFAULT 'active',
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    
    -- Preferences (JSONB for flexibility)
    preferences JSONB DEFAULT '{}',
    
    -- Timestamps
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_customers_email (email),
    INDEX idx_customers_status (status),
    INDEX idx_customers_registration (registration_date),
    INDEX idx_customers_last_login (last_login_at),
    
    -- Constraints
    CONSTRAINT chk_customers_status CHECK (status IN ('active', 'inactive', 'suspended', 'deleted')),
    CONSTRAINT chk_customers_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);
```

#### customer_addresses
```sql
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- Address type and status
    type VARCHAR(20) NOT NULL DEFAULT 'shipping',
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Address information
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company VARCHAR(100),
    street VARCHAR(255) NOT NULL,
    street2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50),
    zip_code VARCHAR(20) NOT NULL,
    country VARCHAR(2) NOT NULL DEFAULT 'US',
    phone VARCHAR(20),
    
    -- Validation
    is_validated BOOLEAN DEFAULT FALSE,
    validation_data JSONB,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_customer_addresses_customer (customer_id),
    INDEX idx_customer_addresses_type (type),
    INDEX idx_customer_addresses_default (is_default),
    INDEX idx_customer_addresses_country (country),
    
    -- Constraints
    CONSTRAINT chk_customer_addresses_type CHECK (type IN ('shipping', 'billing', 'both')),
    CONSTRAINT chk_customer_addresses_country CHECK (LENGTH(country) = 2)
);
```

#### customer_segments
```sql
CREATE TABLE customer_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- Segment information
    tier VARCHAR(20) NOT NULL DEFAULT 'regular',
    segment VARCHAR(50) NOT NULL DEFAULT 'new_customer',
    loyalty_points INTEGER DEFAULT 0,
    
    -- Metrics
    total_spent DECIMAL(12,2) DEFAULT 0,
    order_count INTEGER DEFAULT 0,
    average_order_value DECIMAL(10,2) DEFAULT 0,
    last_order_date TIMESTAMP WITH TIME ZONE,
    days_since_last_order INTEGER,
    lifetime_value DECIMAL(12,2) DEFAULT 0,
    
    -- Qualifications (JSONB for flexibility)
    qualifications JSONB DEFAULT '{}',
    
    -- Timestamps
    tier_achieved_at TIMESTAMP WITH TIME ZONE,
    segment_achieved_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_customer_segments_customer (customer_id),
    INDEX idx_customer_segments_tier (tier),
    INDEX idx_customer_segments_segment (segment),
    INDEX idx_customer_segments_total_spent (total_spent),
    INDEX idx_customer_segments_order_count (order_count),
    
    -- Constraints
    CONSTRAINT chk_customer_segments_tier CHECK (tier IN ('regular', 'premium', 'vip', 'enterprise')),
    CONSTRAINT unique_customer_segment UNIQUE (customer_id)
);
```

#### customer_activities
```sql
CREATE TABLE customer_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- Activity details
    activity_type VARCHAR(50) NOT NULL,
    activity_data JSONB NOT NULL,
    
    -- Context
    session_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    
    -- Timestamps
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_customer_activities_customer (customer_id),
    INDEX idx_customer_activities_type (activity_type),
    INDEX idx_customer_activities_occurred (occurred_at),
    INDEX idx_customer_activities_session (session_id),
    
    -- Partitioning by month for performance
    PARTITION BY RANGE (occurred_at)
);
```

### Cache Schema (Redis)
```
# Customer profile cache
Key: customers:profile:{customer_id}
TTL: 3600 seconds (1 hour)
Value: JSON serialized customer profile

# Customer segment cache
Key: customers:segment:{customer_id}
TTL: 1800 seconds (30 minutes)
Value: JSON serialized segment data

# Customer addresses cache
Key: customers:addresses:{customer_id}
TTL: 7200 seconds (2 hours)
Value: JSON serialized address list

# Customer session cache
Key: customers:session:{session_id}
TTL: 1800 seconds (30 minutes)
Value: Customer session data
```

## 👥 Customer Segmentation Logic

### Tier Calculation
```go
type TierCalculator struct {
    rules map[string]TierRule
}

type TierRule struct {
    MinTotalSpent    float64
    MinOrderCount    int
    MinAverageOrder  float64
    MinLoyaltyPoints int
}

var TierRules = map[string]TierRule{
    "regular": {
        MinTotalSpent: 0,
        MinOrderCount: 0,
    },
    "premium": {
        MinTotalSpent: 1000,
        MinOrderCount: 5,
        MinAverageOrder: 100,
    },
    "vip": {
        MinTotalSpent: 10000,
        MinOrderCount: 20,
        MinAverageOrder: 200,
        MinLoyaltyPoints: 5000,
    },
    "enterprise": {
        MinTotalSpent: 50000,
        MinOrderCount: 100,
        MinAverageOrder: 500,
    },
}
```

### Segment Types
- **new_customer**: < 30 days since registration, < 2 orders
- **regular_customer**: 30+ days, 2+ orders, < $1000 total spent
- **high_value**: $200+ average order value
- **frequent_buyer**: 10+ orders in last 6 months
- **at_risk**: No orders in last 90 days
- **churned**: No orders in last 180 days

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

### Environment Variables
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/customers_db
DATABASE_MAX_CONNECTIONS=25

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_TTL_PROFILE=3600
REDIS_TTL_SEGMENT=1800

# Service Discovery
CONSUL_URL=http://localhost:8500
SERVICE_NAME=customer-service
SERVICE_PORT=8007

# External Services
ORDER_SERVICE_URL=http://order-service:8004
LOYALTY_SERVICE_URL=http://loyalty-service:8011

# Customer Configuration
DEFAULT_TIER=regular
SEGMENT_UPDATE_INTERVAL=3600
PASSWORD_MIN_LENGTH=8
SESSION_TIMEOUT=1800
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

### Performance Targets
- **Response Time**: 
  - P50: < 50ms
  - P95: < 200ms
  - P99: < 500ms
- **Throughput**: 1500 requests/second
- **Availability**: 99.9% uptime
- **Cache Hit Ratio**: > 80%

### Scaling Strategy
- **Horizontal Scaling**: Auto-scale based on request volume
- **Database**: Read replicas for customer lookups
- **Cache**: Redis cluster for session and profile data
- **Load Balancing**: Consistent hashing for session affinity

---

**Document Status**: Complete  
**Next Review Date**: November 30, 2024  
**Service Owner**: Customer Experience Team
# Promotion Service

> **Service Type**: Application Service (Business Logic)  
> **Last Updated**: October 30, 2024  
> **Status**: Complete Documentation

---

## 📋 Service Overview

### Description
Service that handles promotions, discounts, and promotional programs with advanced rules engine supporting SKU + Warehouse based promotions, customer segmentation, and dynamic promotional campaigns.

### Business Context
The Promotion Service enables flexible promotional strategies that can target specific products, warehouses, customer segments, and time periods. It integrates with pricing calculations to provide real-time discount applications during checkout and product browsing.

### Key Responsibilities
- Promotion rules engine with complex conditions
- SKU + Warehouse based promotional targeting
- Customer segment and tier-based promotions
- Coupon code generation and validation
- Promotional campaign management
- Real-time promotion eligibility checking
- Promotion usage tracking and analytics

---

## 🏗️ Architecture

### Service Type
- [x] Application Service (Business Logic)
- [ ] Infrastructure Service (Supporting)
- [ ] Gateway Service (API Gateway/BFF)

### Technology Stack
- **Framework**: go-kratos/kratos v2.7+
- **Database**: PostgreSQL 15+ (promotion rules, campaigns)
- **Cache**: Redis 7+ (promotion eligibility cache)
- **Message Queue**: Dapr Pub/Sub with Redis Streams
- **External APIs**: Customer Service, Catalog Service, Pricing Service

### Deployment
- **Container**: Docker
- **Orchestration**: Kubernetes with Dapr
- **Service Discovery**: Consul
- **Load Balancer**: Kubernetes Service + Ingress

---

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/promotions
Staging: https://staging-api.domain.com/v1/promotions
Local: http://localhost:8003/v1/promotions
```

### Authentication
- **Type**: JWT Bearer Token
- **Required Scopes**: `promotions:read`, `promotions:write`, `promotions:admin`
- **Rate Limiting**: 1000 requests/minute per user

### Promotion Management APIs

#### GET /promotions/active
**Purpose**: Get all active promotions with optional filtering

**Request**:
```http
GET /v1/promotions/active?warehouseId=WH001&customerId=cust_456&productId=prod_123
Authorization: Bearer {jwt_token}
```

**Query Parameters**:
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| warehouseId | string | No | Filter by warehouse | WH001 |
| customerId | string | No | Filter by customer eligibility | cust_456 |
| productId | string | No | Filter by product applicability | prod_123 |
| category | string | No | Filter by product category | electronics |
| type | string | No | Filter by promotion type | percentage, fixed_amount |

**Response**:
```json
{
  "success": true,
  "data": {
    "promotions": [
      {
        "id": "promo_001",
        "name": "Black Friday Electronics Sale",
        "description": "25% off all electronics",
        "type": "percentage",
        "value": 25.0,
        "conditions": {
          "minOrderAmount": 100.00,
          "maxDiscountAmount": 500.00,
          "applicableCategories": ["electronics"],
          "applicableWarehouses": ["WH001", "WH002"],
          "customerSegments": ["premium", "regular"],
          "usageLimit": 1000,
          "usagePerCustomer": 1
        },
        "schedule": {
          "startDate": "2024-11-24T00:00:00Z",
          "endDate": "2024-11-30T23:59:59Z",
          "timezone": "UTC"
        },
        "status": "active",
        "priority": 10,
        "createdAt": "2024-10-15T10:00:00Z"
      }
    ],
    "pagination": {
      "total": 15,
      "page": 1,
      "limit": 20
    }
  }
}
```

#### POST /promotions/validate
**Purpose**: Validate promotion eligibility for specific context

**Request**:
```http
POST /v1/promotions/validate
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "promotionId": "promo_001",
  "context": {
    "customerId": "cust_456",
    "warehouseId": "WH001",
    "items": [
      {
        "productId": "prod_123",
        "sku": "LAPTOP-001",
        "quantity": 1,
        "unitPrice": 1299.99,
        "category": "electronics"
      }
    ],
    "orderAmount": 1299.99,
    "currency": "USD"
  }
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "validation": {
      "isEligible": true,
      "promotionId": "promo_001",
      "discountAmount": 324.98,
      "discountPercentage": 25.0,
      "appliedItems": [
        {
          "productId": "prod_123",
          "originalPrice": 1299.99,
          "discountAmount": 324.98,
          "finalPrice": 974.01
        }
      ],
      "conditions": {
        "minOrderAmount": {
          "required": 100.00,
          "actual": 1299.99,
          "satisfied": true
        },
        "customerSegment": {
          "required": ["premium", "regular"],
          "actual": "premium",
          "satisfied": true
        },
        "usageLimit": {
          "limit": 1000,
          "used": 245,
          "remaining": 755,
          "satisfied": true
        }
      },
      "validUntil": "2024-11-30T23:59:59Z"
    }
  }
}
```

#### POST /promotions/apply
**Purpose**: Apply promotion to order and track usage

**Request**:
```http
POST /v1/promotions/apply
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "promotionId": "promo_001",
  "orderId": "order_789",
  "customerId": "cust_456",
  "context": {
    "warehouseId": "WH001",
    "items": [...],
    "orderAmount": 1299.99
  }
}
```

#### GET /promotions/customer/{customerId}
**Purpose**: Get personalized promotions for customer

#### POST /promotions/coupons/generate
**Purpose**: Generate coupon codes for promotion

**Request**:
```http
POST /v1/promotions/coupons/generate
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "promotionId": "promo_001",
  "quantity": 100,
  "prefix": "BF2024",
  "expiryDate": "2024-11-30T23:59:59Z"
}
```

#### POST /promotions/coupons/validate
**Purpose**: Validate coupon code

### Promotion Configuration APIs

#### POST /promotions
**Purpose**: Create new promotion

**Request**:
```http
POST /v1/promotions
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "name": "Holiday Electronics Sale",
  "description": "Special holiday discount on electronics",
  "type": "percentage",
  "value": 20.0,
  "conditions": {
    "minOrderAmount": 50.00,
    "maxDiscountAmount": 200.00,
    "applicableCategories": ["electronics", "accessories"],
    "applicableWarehouses": ["WH001"],
    "customerSegments": ["all"],
    "usageLimit": 500,
    "usagePerCustomer": 1
  },
  "schedule": {
    "startDate": "2024-12-20T00:00:00Z",
    "endDate": "2024-12-31T23:59:59Z",
    "timezone": "UTC"
  },
  "priority": 5,
  "status": "draft"
}
```

#### PUT /promotions/{promotionId}
**Purpose**: Update existing promotion

#### DELETE /promotions/{promotionId}
**Purpose**: Deactivate promotion

## 🗄️ Database Schema

### Primary Database: PostgreSQL

#### promotions
```sql
CREATE TABLE promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL, -- percentage, fixed_amount, buy_x_get_y
    value DECIMAL(10,2) NOT NULL,
    
    -- Conditions (JSONB for flexibility)
    conditions JSONB NOT NULL DEFAULT '{}',
    
    -- Schedule
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Configuration
    priority INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'draft',
    usage_limit INTEGER,
    usage_count INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Indexes
    INDEX idx_promotions_status (status),
    INDEX idx_promotions_schedule (start_date, end_date),
    INDEX idx_promotions_priority (priority),
    INDEX idx_promotions_type (type),
    
    -- Constraints
    CONSTRAINT chk_promotions_type CHECK (type IN ('percentage', 'fixed_amount', 'buy_x_get_y', 'free_shipping')),
    CONSTRAINT chk_promotions_status CHECK (status IN ('draft', 'active', 'paused', 'expired', 'cancelled')),
    CONSTRAINT chk_promotions_dates CHECK (end_date > start_date)
);
```

#### promotion_rules
```sql
CREATE TABLE promotion_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    rule_type VARCHAR(50) NOT NULL,
    conditions JSONB NOT NULL,
    actions JSONB NOT NULL,
    priority INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_promotion_rules_promotion (promotion_id),
    INDEX idx_promotion_rules_type (rule_type),
    INDEX idx_promotion_rules_priority (priority)
);
```

#### coupon_codes
```sql
CREATE TABLE coupon_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    code VARCHAR(50) UNIQUE NOT NULL,
    usage_limit INTEGER DEFAULT 1,
    usage_count INTEGER DEFAULT 0,
    expires_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_coupon_codes_code (code),
    INDEX idx_coupon_codes_promotion (promotion_id),
    INDEX idx_coupon_codes_status (status),
    INDEX idx_coupon_codes_expires (expires_at),
    
    -- Constraints
    CONSTRAINT chk_coupon_codes_status CHECK (status IN ('active', 'used', 'expired', 'disabled'))
);
```

#### promotion_usage
```sql
CREATE TABLE promotion_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotions(id),
    customer_id UUID NOT NULL,
    order_id UUID NOT NULL,
    coupon_code VARCHAR(50),
    discount_amount DECIMAL(10,2) NOT NULL,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_promotion_usage_promotion (promotion_id),
    INDEX idx_promotion_usage_customer (customer_id),
    INDEX idx_promotion_usage_order (order_id),
    INDEX idx_promotion_usage_applied (applied_at),
    
    -- Unique constraint to prevent duplicate usage
    UNIQUE(promotion_id, customer_id, order_id)
);
```

### Cache Schema (Redis)
```
# Active promotions cache
Key: promotions:active:{warehouse_id}
TTL: 300 seconds (5 minutes)
Value: JSON serialized active promotions

# Promotion eligibility cache
Key: promotions:eligible:{customer_id}:{warehouse_id}
TTL: 600 seconds (10 minutes)
Value: JSON serialized eligible promotions

# Coupon validation cache
Key: promotions:coupon:{coupon_code}
TTL: 1800 seconds (30 minutes)
Value: JSON serialized coupon details

# Promotion usage cache
Key: promotions:usage:{promotion_id}:{customer_id}
TTL: 3600 seconds (1 hour)
Value: Usage count and limits
```

## 🧮 Promotion Rules Engine

### Rule Types

#### 1. **Product-Based Rules**
```json
{
  "rule_type": "product_based",
  "conditions": {
    "products": ["prod_123", "prod_124"],
    "categories": ["electronics"],
    "brands": ["apple", "samsung"],
    "min_quantity": 2,
    "warehouses": ["WH001"]
  },
  "actions": {
    "discount_type": "percentage",
    "discount_value": 15.0,
    "max_discount": 100.00
  }
}
```

#### 2. **Customer-Based Rules**
```json
{
  "rule_type": "customer_based",
  "conditions": {
    "customer_segments": ["premium", "vip"],
    "customer_tiers": ["gold", "platinum"],
    "min_purchase_history": 1000.00,
    "registration_days": 30
  },
  "actions": {
    "discount_type": "fixed_amount",
    "discount_value": 50.00
  }
}
```

#### 3. **Order-Based Rules**
```json
{
  "rule_type": "order_based",
  "conditions": {
    "min_order_amount": 200.00,
    "max_order_amount": 2000.00,
    "item_count": 3,
    "warehouses": ["WH001", "WH002"]
  },
  "actions": {
    "discount_type": "percentage",
    "discount_value": 10.0,
    "free_shipping": true
  }
}
```

#### 4. **Time-Based Rules**
```json
{
  "rule_type": "time_based",
  "conditions": {
    "days_of_week": ["friday", "saturday", "sunday"],
    "hours": ["18:00-23:59"],
    "date_range": {
      "start": "2024-11-24",
      "end": "2024-11-30"
    }
  },
  "actions": {
    "discount_multiplier": 1.5
  }
}
```

### Rule Evaluation Priority
1. **Customer Tier Rules** (Highest Priority)
2. **Product-Specific Rules**
3. **Category/Brand Rules**
4. **Order Amount Rules**
5. **Time-Based Rules** (Lowest Priority)

## 📨 Event Schemas

### Published Events

#### PromotionApplied
**Topic**: `promotions.promotion.applied`
**Version**: 1.0

```json
{
  "eventId": "evt_promo_123",
  "eventType": "PromotionApplied",
  "version": "1.0",
  "timestamp": "2024-10-30T10:30:00Z",
  "source": "promotion-service",
  "data": {
    "promotionId": "promo_001",
    "promotionName": "Black Friday Sale",
    "orderId": "order_789",
    "customerId": "cust_456",
    "discountAmount": 324.98,
    "discountType": "percentage",
    "discountValue": 25.0,
    "couponCode": "BF2024SAVE",
    "warehouseId": "WH001",
    "appliedAt": "2024-10-30T10:30:00Z"
  },
  "metadata": {
    "correlationId": "corr_order_789"
  }
}
```

#### PromotionCreated
**Topic**: `promotions.promotion.created`
**Version**: 1.0

#### PromotionExpired
**Topic**: `promotions.promotion.expired`
**Version**: 1.0

#### CouponGenerated
**Topic**: `promotions.coupon.generated`
**Version**: 1.0

### Subscribed Events

#### OrderCreated
**Topic**: `orders.order.created`
**Source**: order-service

#### CustomerSegmentChanged
**Topic**: `customers.segment.changed`
**Source**: customer-service

#### ProductPriceChanged
**Topic**: `pricing.price.changed`
**Source**: pricing-service

## 🔗 Service Dependencies

### Upstream Dependencies

#### Customer Service
- **Purpose**: Get customer segment and tier information
- **Endpoints Used**: `/customers/{id}/profile`, `/customers/{id}/segment`
- **Fallback Strategy**: Use cached customer data, default to 'regular' segment
- **SLA Requirements**: < 100ms response time

#### Catalog Service
- **Purpose**: Validate product categories and brands
- **Endpoints Used**: `/products/{id}`, `/categories/{id}`
- **Fallback Strategy**: Cache product metadata, skip category validation if unavailable

#### Pricing Service
- **Purpose**: Coordinate with pricing calculations
- **Endpoints Used**: `/pricing/calculate`
- **Fallback Strategy**: Apply promotions independently, sync later

### Downstream Dependencies

#### Order Service
- **Purpose**: Apply promotions during checkout
- **Endpoints Used**: This service's promotion validation APIs
- **Usage Pattern**: High frequency during checkout flows

#### Pricing Service
- **Purpose**: Include promotional discounts in price calculations
- **Endpoints Used**: `/promotions/validate`, `/promotions/apply`
- **Usage Pattern**: Real-time during price calculations

## ⚙️ Configuration

### Environment Variables
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/promotions_db
DATABASE_MAX_CONNECTIONS=20

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_TTL_PROMOTIONS=300
REDIS_TTL_ELIGIBILITY=600

# Service Discovery
CONSUL_URL=http://localhost:8500
SERVICE_NAME=promotion-service
SERVICE_PORT=8003

# Dapr
DAPR_HTTP_PORT=3500
DAPR_GRPC_PORT=50001

# External Services
CUSTOMER_SERVICE_URL=http://customer-service:8007
CATALOG_SERVICE_URL=http://catalog-service:8001
PRICING_SERVICE_URL=http://pricing-service:8002

# Promotion Configuration
MAX_PROMOTIONS_PER_ORDER=5
DEFAULT_PROMOTION_TTL=3600
COUPON_CODE_LENGTH=8
```

### Feature Flags
```yaml
features:
  enable_customer_segmentation: true
  enable_warehouse_promotions: true
  enable_dynamic_pricing: true
  enable_coupon_stacking: false
  max_discount_percentage: 50
  max_discount_amount: 1000
```

## 🚨 Error Handling

### Error Codes
| Code | HTTP Status | Description | Retry Strategy |
|------|-------------|-------------|----------------|
| PROMOTION_NOT_FOUND | 404 | Promotion does not exist | No retry |
| PROMOTION_EXPIRED | 400 | Promotion has expired | No retry |
| PROMOTION_NOT_ELIGIBLE | 400 | Customer/order not eligible | No retry |
| USAGE_LIMIT_EXCEEDED | 400 | Promotion usage limit reached | No retry |
| INVALID_COUPON | 400 | Coupon code invalid or expired | No retry |
| PROMOTION_CONFLICT | 409 | Conflicting promotions | No retry |
| SERVICE_UNAVAILABLE | 503 | External service unavailable | Retry with backoff |

## ⚡ Performance & SLAs

### Performance Targets
- **Response Time**: 
  - P50: < 50ms
  - P95: < 150ms
  - P99: < 300ms
- **Throughput**: 2000 requests/second
- **Availability**: 99.9% uptime
- **Cache Hit Ratio**: > 85%

### Scaling Strategy
- **Horizontal Scaling**: Auto-scale based on CPU usage (70% threshold)
- **Database**: Read replicas for promotion lookups
- **Cache**: Redis cluster for high availability
- **Load Balancing**: Round-robin with health checks

## 🔒 Security

### Authentication & Authorization
- **Authentication**: JWT Bearer tokens
- **Authorization**: Role-based access control
- **Admin Operations**: Require `promotions:admin` scope
- **Customer Operations**: Require `promotions:read` scope

### Data Protection
- **Sensitive Data**: Promotion rules and customer segments
- **Audit Logging**: All promotion applications logged
- **Rate Limiting**: Prevent promotion abuse

## 🧪 Testing Strategy

### Unit Tests
- **Coverage Target**: > 85%
- **Framework**: Go testing package + testify
- **Mock Strategy**: Mock external service dependencies
- **Test Data**: Factory pattern for promotion test data

### Integration Tests
- **Database Tests**: Test with real PostgreSQL (testcontainers)
- **API Tests**: Test all endpoints with various scenarios
- **Cache Tests**: Test Redis integration and invalidation
- **Event Tests**: Test event publishing and consumption

### Performance Tests
- **Load Testing**: Test with expected production load
- **Stress Testing**: Test promotion validation under high load
- **Endurance Testing**: Long-running promotion campaigns

## 📈 Monitoring & Observability

### Metrics (Prometheus)
```yaml
# Business Metrics
promotions_applied_total: Counter of promotions applied
promotions_validated_total: Counter of promotion validations
coupons_generated_total: Counter of coupons generated
discount_amount_total: Total discount amount applied

# Technical Metrics
http_requests_total: HTTP request counter
http_request_duration_seconds: HTTP request duration
database_connections_active: Active database connections
cache_hits_total: Cache hit counter
cache_misses_total: Cache miss counter
```

### Health Checks
```http
GET /health
{
  "status": "healthy",
  "checks": {
    "database": "healthy",
    "cache": "healthy",
    "customer_service": "healthy",
    "catalog_service": "healthy"
  },
  "timestamp": "2024-10-30T10:30:00Z"
}
```

---

**Document Status**: Complete  
**Next Review Date**: November 30, 2024  
**Service Owner**: Promotion Team
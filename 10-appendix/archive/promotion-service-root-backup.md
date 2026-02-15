# 🎁 Promotion Service Documentation

**Service Name**: Promotion Service  
**Version**: v1.1.2  
**Repository**: `gitlab.com/ta-microservices/promotion`  
**Status**: 🔄 In Review (Updated February 4, 2026)

---

## 📋 **Service Overview**

### **Purpose**
The Promotion Service provides comprehensive discount, coupon, and campaign management capabilities for the e-commerce platform. It handles various promotional mechanisms including percentage discounts, fixed amount discounts, free shipping, buy-one-get-one offers, and loyalty rewards.

### **Key Features**
- 🎫 **Coupon Management**: Generate, validate, and track coupon codes
- 📊 **Campaign Management**: Create and manage promotional campaigns
- 💰 **Discount Engine**: Complex discount calculation logic
- 🚀 **Real-time Validation**: Instant coupon and promotion validation
- 📈 **Analytics & Reporting**: Promotion performance tracking
- 🎯 **Targeting**: Customer segmentation and targeted promotions
- 🔄 **A/B Testing**: Promotion effectiveness testing
- 📱 **Multi-channel**: Web, mobile, and API support

---

## 🏗️ **Architecture**

### **Clean Architecture Layers**

```
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   HTTP/gRPC     │  │   Event         │  │   Health      │ │
│  │   Handlers      │  │   Consumers     │  │   Checks     │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Promotion     │  │   Discount      │  │   Campaign   │ │
│  │   Usecases      │  │   Calculator    │  │   Manager    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   PostgreSQL    │  │   Redis         │  │   Event      │ │
│  │   (Metadata)    │  │   (Cache)       │  │   Store      │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### **Component Overview**

#### **Service Layer (`internal/service/`)**
- **Promotion Handlers**: HTTP/gRPC promotion endpoints
- **Health Checks**: Service health and dependency monitoring
- **Error Mapping**: Comprehensive error handling

#### **Business Logic (`internal/biz/`)**
- **Promotion Usecases**: Core promotion management logic
- **Discount Calculator**: Complex discount calculation engine
- **Conditions**: Promotion condition evaluation
- **Validation**: Input validation and business rules

#### **Data Layer (`internal/data/`)**
- **PostgreSQL**: Promotion metadata and transaction storage
- **Redis**: Caching and session management
- **Event Store**: Outbox pattern for event publishing

---

## 📡 **API Documentation**

### **gRPC Endpoints**

#### **Promotion Service**
```protobuf
service PromotionService {
  rpc CreateCampaign(CreateCampaignRequest) returns (CreateCampaignResponse);
  rpc UpdateCampaign(UpdateCampaignRequest) returns (UpdateCampaignResponse);
  rpc GetCampaign(GetCampaignRequest) returns (GetCampaignResponse);
  rpc ListCampaigns(ListCampaignsRequest) returns (ListCampaignsResponse);
  rpc DeleteCampaign(DeleteCampaignRequest) returns (DeleteCampaignResponse);
  
  rpc CreateCoupon(CreateCouponRequest) returns (CreateCouponResponse);
  rpc ValidateCoupon(ValidateCouponRequest) returns (ValidateCouponResponse);
  rpc ListCoupons(ListCouponsRequest) returns (ListCouponsResponse);
  rpc RedeemCoupon(RedeemCouponRequest) returns (RedeemCouponResponse);
  
  rpc CalculateDiscount(CalculateDiscountRequest) returns (CalculateDiscountResponse);
  rpc ApplyPromotion(ApplyPromotionRequest) returns (ApplyPromotionResponse);
  
  rpc GetPromotionStats(GetPromotionStatsRequest) returns (GetPromotionStatsResponse);
  rpc GetCampaignAnalytics(GetCampaignAnalyticsRequest) returns (GetCampaignAnalyticsResponse);
}
```

### **HTTP Endpoints**

#### **Campaign Management**
- `POST /api/v1/campaigns` - Create new campaign
- `GET /api/v1/campaigns/{id}` - Get campaign details
- `PUT /api/v1/campaigns/{id}` - Update campaign
- `DELETE /api/v1/campaigns/{id}` - Delete campaign
- `GET /api/v1/campaigns` - List campaigns

#### **Coupon Management**
- `POST /api/v1/coupons` - Generate coupons
- `POST /api/v1/coupons/validate` - Validate coupon
- `POST /api/v1/coupons/redeem` - Redeem coupon
- `GET /api/v1/coupons` - List coupons

#### **Discount Calculation**
- `POST /api/v1/discounts/calculate` - Calculate discount
- `POST /api/v1/promotions/apply` - Apply promotion to cart

#### **Analytics**
- `GET /api/v1/analytics/campaigns/{id}` - Campaign analytics
- `GET /api/v1/analytics/promotions/stats` - Promotion statistics

#### **Health Endpoints**
- `GET /health/live` - Liveness probe
- `GET /health/ready` - Readiness probe

---

## 🎯 **Promotion Types**

### **Discount Types**
```go
type DiscountType string

const (
    DiscountTypePercentage DiscountType = "percentage" // 10% off
    DiscountTypeFixedAmount DiscountType = "fixed_amount" // $10 off
    DiscountTypeFreeShipping DiscountType = "free_shipping"
    DiscountTypeBuyXGetY DiscountType = "buy_x_get_y" // BOGO
    DiscountTypeBundle DiscountType = "bundle" // Product bundle discount
    DiscountTypeLoyaltyPoints DiscountType = "loyalty_points"
)
```

### **Campaign Types**
```go
type CampaignType string

const (
    CampaignTypePublic CampaignType = "public" // Available to everyone
    CampaignTypePrivate CampaignType = "private" // Invite only
    CampaignTypeSegmented CampaignType = "segmented" // Customer segments
    CampaignTypePersonalized CampaignType = "personalized" // Individual offers
)
```

### **Condition Types**
```go
type ConditionType string

const (
    ConditionTypeMinimumOrder ConditionType = "minimum_order"
    ConditionTypeProductCategory ConditionType = "product_category"
    ConditionTypeCustomerSegment ConditionType = "customer_segment"
    ConditionTypePurchaseHistory ConditionType = "purchase_history"
    ConditionTypeLocation ConditionType = "location"
    ConditionTypeTimeWindow ConditionType = "time_window"
)
```

---

## 🗄️ **Data Models**

### **Campaign Model**
```go
type Campaign struct {
    ID          string                 `json:"id" gorm:"primaryKey"`
    Name        string                 `json:"name" gorm:"not null"`
    Description string                 `json:"description"`
    Type        CampaignType           `json:"type" gorm:"not null"`
    Status      CampaignStatus         `json:"status" gorm:"not null"`
    StartTime   time.Time              `json:"start_time" gorm:"not null"`
    EndTime     time.Time              `json:"end_time" gorm:"not null"`
    Budget      *decimal.Decimal      `json:"budget,omitempty"`
    MaxUses     *int                   `json:"max_uses,omitempty"`
    CurrentUses int                    `json:"current_uses" gorm:"default:0"`
    Conditions  datatypes.JSON         `json:"conditions" gorm:"type:jsonb"`
    Discounts   datatypes.JSON         `json:"discounts" gorm:"type:jsonb"`
    Targeting   *TargetingRules        `json:"targeting,omitempty"`
    Metadata    datatypes.JSON         `json:"metadata" gorm:"type:jsonb"`
    CreatedAt   time.Time              `json:"created_at"`
    UpdatedAt   time.Time              `json:"updated_at"`
}
```

### **Coupon Model**
```go
type Coupon struct {
    ID          string           `json:"id" gorm:"primaryKey"`
    Code        string           `json:"code" gorm:"uniqueIndex;not null"`
    CampaignID  string           `json:"campaign_id" gorm:"not null"`
    Type        CouponType       `json:"type" gorm:"not null"`
    Value       decimal.Decimal  `json:"value" gorm:"not null"`
    Status      CouponStatus     `json:"status" gorm:"not null"`
    MaxUses     *int             `json:"max_uses,omitempty"`
    CurrentUses int              `json:"current_uses" gorm:"default:0"`
    ValidFrom   time.Time        `json:"valid_from" gorm:"not null"`
    ValidUntil  time.Time        `json:"valid_until" gorm:"not null"`
    CustomerID  *string          `json:"customer_id,omitempty"`
    Metadata    datatypes.JSON   `json:"metadata" gorm:"type:jsonb"`
    CreatedAt   time.Time        `json:"created_at"`
    UpdatedAt   time.Time        `json:"updated_at"`
}
```

### **Discount Calculation Request**
```go
type CalculateDiscountRequest struct {
    CustomerID    string                 `json:"customer_id"`
    CartItems     []CartItem             `json:"cart_items"`
    OrderTotal    decimal.Decimal        `json:"order_total"`
    CouponCodes   []string               `json:"coupon_codes,omitempty"`
    CampaignIDs   []string               `json:"campaign_ids,omitempty"`
    CustomerTier  string                 `json:"customer_tier,omitempty"`
    Location      string                 `json:"location,omitempty"`
    Context       map[string]interface{} `json:"context,omitempty"`
}
```

---

## ⚡ **Performance Features**

### **Caching Strategy**
- **Redis Cache**: Promotion rules and coupon validation
- **Cache Keys**: Efficient cache key generation
- **TTL Management**: Configurable cache expiration
- **Cache Invalidation**: Event-driven cache updates

### **Discount Optimization**
- **Rule Engine**: Efficient rule evaluation
- **Batch Processing**: Bulk coupon generation
- **Parallel Validation**: Concurrent coupon validation
- **Pre-computation**: Pre-calculated discount tables

### **Performance Metrics**
- **Response Time**: < 200ms for discount calculation
- **Throughput**: 5000+ requests/second
- **Cache Hit Rate**: > 90% for active promotions
- **Validation Speed**: < 50ms for coupon validation

---

## 🛡️ **Security Features**

### **Coupon Security**
- **Unique Codes**: Cryptographically secure coupon generation
- **One-time Use**: Single-use coupon enforcement
- **Rate Limiting**: Coupon validation rate limiting
- **Fraud Detection**: Suspicious usage pattern detection

### **Access Control**
- **JWT Authentication**: Token-based API security
- **Role-based Access**: Permission-based access control
- **API Rate Limiting**: Request throttling
- **Input Validation**: Comprehensive input sanitization

### **Data Protection**
- **PII Protection**: Customer data protection
- **Audit Logging**: Comprehensive audit trail
- **Secure Storage**: Encrypted sensitive data
- **Compliance**: GDPR and PCI compliance

---

## 👁️ **Observability**

### **Monitoring & Metrics**
- **Prometheus Metrics**: RED metrics implementation
- **Custom Metrics**: Promotion-specific KPIs
- **Health Checks**: Service health monitoring
- **Performance Metrics**: Discount calculation performance

### **Logging**
- **Structured Logging**: JSON format with trace IDs
- **Log Levels**: Configurable logging verbosity
- **Request Tracing**: End-to-end request tracking
- **Error Logging**: Comprehensive error reporting

### **Key Metrics**
```go
// Promotion Metrics
promotion_duration_seconds
promotion_requests_total
coupon_validation_duration_seconds
coupon_redemption_total
campaign_performance_metrics

// Business Metrics
discount_amount_total
promotion_conversion_rate
customer_engagement_rate
revenue_attribution
```

---

## 🚀 **Deployment**

### **Container Configuration**
```dockerfile
# Multi-stage build
FROM golang:1.25.3-alpine AS builder
# Build stage with Go modules and protobuf generation

FROM alpine:latest
# Runtime stage with minimal footprint
```

### **Docker Compose**
```yaml
services:
  promotion-service:
    build:
      context: ..
      dockerfile: promotion/Dockerfile.optimized
    ports:
      - "8012:80"   # HTTP
      - "9012:81"   # gRPC
    environment:
      - DATABASE_URL=postgres://promotion_user:promotion_pass@postgres:5432/promotion_db
      - REDIS_URL=redis://redis:6379/3
    depends_on:
      - promotion-migration
      - postgres
      - redis
```

### **Health Checks**
- **Liveness**: `/health/live` - Service is running
- **Readiness**: `/health/ready` - Service is ready to accept traffic
- **Dependencies**: PostgreSQL, Redis connectivity

---

## 🧪 **Testing**

### **Test Coverage**
- **Unit Tests**: Business logic validation (85% coverage)
- **Integration Tests**: Database and external service integration
- **End-to-End Tests**: Full promotion workflow testing
- **Performance Tests**: Load and stress testing

### **Test Structure**
```
test/
├── unit/                    # Unit tests
│   ├── promotion_test.go
│   ├── discount_calculator_test.go
│   └── conditions_test.go
├── integration/             # Integration tests
│   ├── promotion_integration_test.go
│   └── coupon_validation_test.go
└── e2e/                    # End-to-end tests
    └── campaign_workflow_test.go
```

---

## 📊 **Business Value**

### **Customer Experience**
- **Personalized Offers**: Targeted promotions based on behavior
- **Instant Discounts**: Real-time coupon validation
- **Seamless Integration**: Transparent discount application
- **Mobile Optimized**: Mobile-friendly promotion experience

### **Business Intelligence**
- **Campaign Analytics**: Promotion performance insights
- **Customer Segmentation**: Advanced customer targeting
- **Revenue Attribution**: Promotion impact measurement
- **A/B Testing**: Promotion effectiveness optimization

### **Operational Efficiency**
- **Automated Campaigns**: Scheduled promotion management
- **Scalable Architecture**: High-volume discount processing
- **Real-time Analytics**: Live performance monitoring
- **Cost Optimization**: Efficient resource utilization

---

## 🔧 **Configuration**

### **Environment Variables**
```bash
# Database Configuration
DATABASE_URL=postgres://promotion_user:promotion_pass@localhost:5432/promotion_db
REDIS_URL=redis://localhost:6379/3

# Service Configuration
SERVICE_HTTP_PORT=80
SERVICE_GRPC_PORT=81
LOG_LEVEL=info

# Promotion Configuration
DEFAULT_CAMPAIGN_DURATION=604800s
MAX_COUPONS_PER_BATCH=10000
COUPON_CODE_LENGTH=8
CACHE_TTL=300s
ENABLE_ANALYTICS=true
ENABLE_AB_TESTING=true
```

### **Feature Flags**
```bash
# Feature Toggles
ENABLE_PERSONALIZED_PROMOTIONS=true
ENABLE_ADVANCED_TARGETING=true
ENABLE_REAL_TIME_ANALYTICS=true
ENABLE_FRAUD_DETECTION=true
```

---

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Discount Calculation Errors**
- **Symptom**: Incorrect discount amounts
- **Causes**: Rule configuration errors, cache issues
- **Solutions**: Check promotion rules, clear cache, verify data

#### **Coupon Validation Failures**
- **Symptom**: Valid coupons rejected
- **Causes**: Time zone issues, usage limits, cache staleness
- **Solutions**: Check coupon validity, verify usage limits, refresh cache

#### **Performance Issues**
- **Symptom**: Slow discount calculation
- **Causes**: Complex rules, cache misses, database issues
- **Solutions**: Optimize rules, warm cache, check database performance

### **Debugging Commands**
```bash
# Check service health
curl http://localhost:8012/health/live

# Check Redis connectivity
redis-cli -n 3 ping

# Validate coupon
curl -X POST http://localhost:8012/api/v1/coupons/validate \
  -H "Content-Type: application/json" \
  -d '{"code":"SAVE10","customer_id":"12345"}'

# View service logs
docker logs promotion-service
```

---

## 📈 **Roadmap**

### **Q1 2026**
- ✅ **Completed**: Service activation and optimization
- ✅ **Completed**: Comprehensive documentation
- 🔄 **In Progress**: Advanced targeting features
- 📋 **Planned**: Machine learning-based recommendations

### **Q2 2026**
- 🎯 **Goal**: Enhanced personalization
- 📋 **Planned**: Behavioral targeting
- 📋 **Planned**: Dynamic pricing integration
- 📋 **Planned**: Cross-channel promotions

### **Q3 2026**
- 🎯 **Goal**: Advanced analytics
- 📋 **Planned**: Real-time attribution
- 📋 **Planned**: Predictive analytics
- 📋 **Planned**: Customer lifetime value integration

---

## 📞 **Support & Contact**

### **Development Team**
- **Service Owner**: Promotion Service Team
- **Technical Lead**: Senior Software Engineer
- **DevOps**: Platform Engineering Team

### **Support Channels**
- **Documentation**: This service documentation
- **Monitoring**: Prometheus + Grafana dashboards
- **Alerting**: PagerDuty integration
- **Issues**: GitLab issue tracker

---

**Last Updated**: February 2, 2026  
**Next Review**: March 2, 2026  
**Version**: v1.0.4  
**Status**: ✅ Production Ready

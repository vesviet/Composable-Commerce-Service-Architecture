# Promotion Service

**Service Type**: Core Service  
**Status**: ✅ Production Ready  
**Version**: v1.0.1  
**Last Updated**: January 29, 2026

## Overview

The Promotion Service is a core microservice responsible for managing promotional campaigns, discount rules, coupon systems, and promotional analytics for the e-commerce platform. It provides comprehensive promotion management capabilities including cart rules, catalog rules, BOGO promotions, tiered discounts, and usage tracking.

## Key Features

### Campaign Management
- Time-based promotional campaigns with complex rules
- Campaign types: seasonal, flash sale, clearance, loyalty
- Budget tracking and limits
- Priority-based campaign ordering
- Target audience segmentation

### Promotion Rules
- **Cart Rules**: Applied during checkout to entire shopping cart
- **Catalog Rules**: Applied to individual product prices in real-time
- Flexible condition evaluation (AND/OR logic)
- Product, category, brand, and customer segment targeting
- Usage limits (per customer and global)

### Discount Types
- Percentage discounts
- Fixed amount discounts
- Buy X Get Y (BOGO) promotions
- Tiered/progressive discounts
- Item selection discounts (cheapest/most expensive)
- Free shipping

### Coupon Management
- Single-use and multi-use coupons
- Bulk coupon generation (up to 10,000)
- Customer-specific coupons
- Coupon validation and usage tracking
- Expiration and activation dates

### Advanced Features
- Promotion stacking (stackable vs non-stackable)
- Priority-based rule processing
- Stop rules processing flag
- Optimistic locking for concurrent updates
- Event-driven architecture (Dapr pub/sub)
- Catalog price indexing for performance

## Architecture

### Clean Architecture Layers

```
promotion/
├── internal/
│   ├── biz/              # Business logic layer
│   │   ├── promotion.go  # Promotion use cases
│   │   ├── discount_calculator.go  # Discount calculation engine
│   │   ├── conditions.go  # Condition evaluation
│   │   ├── validation.go  # Promotion validation
│   │   └── ...
│   ├── data/             # Data access layer
│   │   ├── promotion.go  # Promotion repository
│   │   ├── campaign.go   # Campaign repository
│   │   ├── coupon.go     # Coupon repository
│   │   └── transaction.go  # Transaction management
│   ├── service/          # Service layer (gRPC/HTTP handlers)
│   │   ├── promotion.go  # Promotion handlers
│   │   ├── health.go     # Health checks
│   │   └── service.go    # Service setup
│   └── server/           # Server configuration
│       ├── http.go       # HTTP server
│       ├── grpc.go       # gRPC server
│       └── consul.go     # Service discovery
└── api/                  # API definitions
    └── promotion/v1/
        └── promotion.proto
```

### Key Components

- **PromotionUseCase**: Core business logic for promotions
- **DiscountCalculator**: Advanced discount calculation engine
- **ConditionEvaluator**: Flexible condition evaluation system
- **PromotionCache**: Redis-based caching for active promotions
- **OutboxRepo**: Event publishing with transactional outbox pattern

## API Endpoints

### Campaign Management
- `ListCampaigns` - List campaigns with filtering and pagination
- `CreateCampaign` - Create new campaign (admin only)
- `GetCampaign` - Get campaign details
- `UpdateCampaign` - Update campaign (admin only)
- `DeleteCampaign` - Delete campaign (admin only)
- `ActivateCampaign` - Activate campaign
- `DeactivateCampaign` - Deactivate campaign

### Promotion Management
- `ListPromotions` - List promotions with filtering
- `CreatePromotion` - Create new promotion (admin only)
- `GetPromotion` - Get promotion details
- `UpdatePromotion` - Update promotion (admin only)
- `DeletePromotion` - Delete promotion (admin only)
- `ValidatePromotions` - Validate promotions for cart/order

### Coupon Management
- `ListCoupons` - List coupons with filtering
- `CreateCoupon` - Create new coupon (admin only)
- `GetCoupon` - Get coupon by code
- `UpdateCoupon` - Update coupon (admin only)
- `DeleteCoupon` - Delete coupon (admin only)
- `GenerateBulkCoupons` - Generate bulk coupons (admin only)

### Analytics
- `GetCampaignAnalytics` - Campaign performance metrics
- `GetPromotionUsage` - Promotion usage statistics
- `GetCouponUsage` - Coupon usage statistics

## Database Schema

### Key Tables
- `campaigns` - Campaign definitions
- `promotions` - Promotion rules and configurations
- `coupons` - Coupon codes and metadata
- `promotion_usage` - Usage tracking and analytics
- `catalog_price_index` - Indexed catalog prices for performance
- `outbox_events` - Transactional outbox for event publishing

### Indexes
- GIN indexes on JSONB columns (applicable_products, applicable_categories, etc.)
- Indexes on status, dates, priority for efficient queries
- Composite indexes for common query patterns

## Integration

### External Services
- **Catalog Service**: Product information and pricing
- **Customer Service**: Customer segments and profiles
- **Pricing Service**: Price calculations and discounts
- **Review Service**: Review-based promotions
- **Shipping Service**: Free shipping promotions (planned)

### Event Publishing
- `campaign.created` - Campaign created event
- `campaign.updated` - Campaign updated event
- `promotion.created` - Promotion created event
- `promotion.applied` - Promotion applied to order
- `coupons.bulk_created` - Bulk coupons generated

## Security

- **Authentication**: JWT-based authentication via Gateway
- **Authorization**: Role-based access control (admin for write operations)
- **Input Validation**: Comprehensive validation using common/validation package
- **SQL Injection Prevention**: Parameterized queries via GORM
- **Sensitive Data**: No sensitive data stored, proper logging practices

## Performance

### Caching Strategy
- Redis cache for active promotions
- Cache invalidation on promotion updates
- Cache-aside pattern for promotion lookups

### Optimization
- JSONB filtering with GIN indexes
- Pagination for all list endpoints
- Optimistic locking for concurrent updates
- Connection pooling configured

### Metrics
- Promotion validation duration
- Cache hit ratio
- Usage limit tracking
- Error rates

## Observability

### Health Checks
- `/health/live` - Liveness probe
- `/health/ready` - Readiness probe

### Metrics (Prometheus)
- `promotion_validation_duration_seconds`
- `coupon_validation_total`
- `campaign_budget_used_percentage`
- `promotion_usage_total`
- `redis_cache_hit_ratio`

### Logging
- Structured JSON logging
- Trace ID propagation
- Log levels: ERROR, WARN, INFO, DEBUG

### Tracing
- OpenTelemetry spans for critical paths
- Distributed tracing support

## Testing

### Current Coverage
- **Biz Layer**: ~36% (target: 80%+)
- **Data Layer**: Limited integration tests
- **Service Layer**: Error mapping tests

### Test Types
- Unit tests for business logic
- Integration tests with testcontainers (planned)
- API contract tests (planned)

## Deployment

### Docker
- Dockerfile optimized for production
- Multi-stage build
- Health checks configured

### Kubernetes
- Deployment manifests available
- Resource limits defined
- Liveness/readiness probes configured

### Configuration
- Environment-based configuration
- Config files: `config.yaml`, `config-docker.yaml`
- External service endpoints configurable

## Code Quality

### Linting
- ✅ golangci-lint passing
- ✅ Error handling consistent
- ✅ Code style standardized

### Best Practices
- ✅ Clean Architecture principles
- ✅ Dependency injection with Wire
- ✅ Transaction management
- ✅ Optimistic locking
- ✅ Circuit breakers for external calls

## Known Limitations

1. **Test Coverage**: Currently ~36%, needs improvement to 80%+
2. **Shipping Client**: Using NoOp client until shipping service is available
3. **Error Handling**: Could use common/errors package for structured errors

## Roadmap

### Short Term
- Increase test coverage to 80%+
- Add integration tests
- Add API contract tests

### Medium Term
- Implement real shipping gRPC client
- Migrate to common/errors package
- Add performance tests

## References

- [Code Review Checklist](../../10-appendix/checklists/v2/promotion_service_code_review.md)
- [TODO List](../../10-appendix/checklists/v2/promotion_service_todos.md)
- [Service README](../../../promotion/README.md)

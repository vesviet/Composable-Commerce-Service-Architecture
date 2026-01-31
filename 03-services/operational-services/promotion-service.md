# Promotion Service

**Version**: 1.0.0
**Last Updated**: 2026-01-31
**Service Type**: Operational
**Status**: Active

---

## Overview

Brief description of what this service does and its role in the system.

The Promotion Service manages marketing campaigns, promotions, coupons, and discount calculations for the e-commerce platform. It provides comprehensive promotion management capabilities including campaign lifecycle, promotion rules, coupon generation, and real-time discount application.

## Architecture

### Responsibilities
- Campaign management and lifecycle
- Promotion rule engine and validation
- Coupon generation and management
- Discount calculation and application
- Promotion analytics and reporting
- Real-time promotion evaluation

### Dependencies
- **Upstream services**: Catalog Service (product data), Customer Service (customer segments), Pricing Service (price calculations)
- **Downstream services**: Order Service (promotion application), Notification Service (promotion alerts)
- **External dependencies**: Redis (caching), PostgreSQL (data storage)

## API Contract

### gRPC Services
- **Service**: `api.promotion.v1.PromotionService`
- **Proto location**: `promotion/api/promotion/v1/`
- **Key methods**:
  - `CreateCampaign(Request) → Response` - Create marketing campaign
  - `GetPromotion(Request) → Response` - Get promotion details
  - `ValidatePromotions(Request) → Response` - Validate and apply promotions
  - `CreateCoupon(Request) → Response` - Generate coupons

### HTTP Endpoints (if any)
- `GET /api/v1/promotions` - List active promotions
- `POST /api/v1/coupons/validate` - Validate coupon code

## Data Model

### Database Tables
- **campaigns**: Marketing campaign definitions
- **promotions**: Individual promotion rules and configurations
- **coupons**: Coupon codes and usage tracking
- **promotion_usage**: Promotion application history

### Key Entities
- **Campaign**: Marketing campaign with budget and targeting
- **Promotion**: Discount rules with conditions and actions
- **Coupon**: Redeemable discount codes
- **PromotionUsage**: Audit trail of promotion applications

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_HOST` | Yes | - | PostgreSQL host |
| `REDIS_HOST` | Yes | - | Redis host for caching |
| `SERVICE_PORT` | No | `9000` | gRPC service port |

### Config Files
- **Location**: `promotion/configs/`
- **Key settings**: Database connection, Redis config, service ports

## Deployment

### Docker
- **Image**: `registry/ta-microservices/promotion`
- **Ports**: 9000 (gRPC), 8000 (HTTP health)
- **Health check**: `grpc_health_probe -addr=:9000`

### Kubernetes
- **Namespace**: `ta-microservices`
- **Resources**: CPU: 500m-2, Memory: 1Gi-4Gi
- **Scaling**: Min: 2, Max: 10 replicas

## Monitoring & Observability

### Metrics
- Promotion application success/failure rates
- Coupon redemption statistics
- Campaign performance metrics
- Cache hit/miss ratios

### Logging
- Structured logging with request IDs
- Promotion validation errors
- Coupon usage events

### Tracing
- Distributed tracing for promotion evaluation
- Performance monitoring for discount calculations

## Development

### Local Setup
1. Prerequisites: Go 1.25+, Docker, PostgreSQL
2. Configuration: Copy `.env.example` to `.env`
3. Dependencies: `go mod download`
4. Database: Run migrations with `make migrate-up`
5. Start service: `make run`

### Testing
- Unit tests: `make test`
- Integration tests: Test with real database
- Coverage target: >80%

## Troubleshooting

### Common Issues
- **Promotion validation failures**: Check condition logic and product data
- **Coupon code conflicts**: Verify uniqueness constraints
- **Performance issues**: Check Redis cache configuration

### Debug Commands
```bash
# Check service health
grpc_health_probe -addr=localhost:9000

# View promotion logs
kubectl logs -f deployment/promotion
```</content>
<parameter name="filePath">/Users/tuananh/Desktop/myproject/microservice/docs/03-services/operational-services/promotion-service.md
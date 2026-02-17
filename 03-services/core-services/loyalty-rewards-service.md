# 🏅 Loyalty Rewards Service - Complete Documentation

> **Owner**: Platform Team  
> **Last Updated**: 2026-02-15  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: 8014/9014

**Service Name**: Loyalty Rewards Service
**Version**: 1.0.1
**Last Updated**: 2026-02-10
**Review Status**: 🔄 Active
**Production Ready**: ⚠️ Pending Review

## Overview

The Loyalty Rewards Service manages customer loyalty programs for the microservices platform. It handles loyalty account management, points earning and redemption, tier progression, referral programs, reward catalogs, and promotional campaigns. The service provides a comprehensive loyalty ecosystem that integrates with order processing, customer management, and notification systems to deliver personalized rewards and engagement.

## Architecture

### Responsibilities
- **Loyalty Account Management**: Create and manage customer loyalty accounts with point balances and tier status
- **Transaction Processing**: Track points earned from purchases, reviews, referrals, and other activities
- **Reward Management**: Maintain catalogs of redeemable rewards and process redemption requests
- **Tier System**: Implement loyalty tiers with different benefits and progression rules
- **Referral Program**: Track referral relationships and reward successful referrals
- **Campaign Management**: Run time-limited promotional campaigns with special earning rules
- **Analytics**: Provide insights into loyalty program performance and customer engagement

### Dependencies
- **Upstream services**: order (for purchase-based earning), customer (for account linking), notification (for reward notifications)
- **Downstream services**: None (service is consumed by frontend and other business services)
- **External dependencies**: PostgreSQL (data storage), Redis (caching), Dapr (event publishing)

## API Contract

### gRPC Services
- **Service**: `api.loyalty.v1.LoyaltyService`
- **Proto location**: `loyalty-rewards/api/loyalty/v1/`
- **Key methods**:
  - `Health(Empty) → HealthResponse` - Service health check
  - `GetAnalytics(GetAnalyticsRequest) → GetAnalyticsResponse` - Cross-domain analytics

### Sub-Services
- **AccountService**: Account creation, updates, and queries
- **TransactionService**: Points earning and transaction history
- **RewardService**: Reward catalog and redemption
- **TierService**: Tier management and progression
- **ReferralService**: Referral tracking and rewards
- **CampaignService**: Campaign management and participation

### HTTP Endpoints
- `GET /health` - Health check
- `GET /api/v1/loyalty/analytics` - Analytics data

## Data Model

### Database Tables
- **loyalty_accounts**: Customer loyalty accounts with point balances and tier information
- **loyalty_transactions**: Points earned, redeemed, or adjusted with transaction details
- **loyalty_rewards**: Available rewards catalog with redemption rules
- **loyalty_tiers**: Tier definitions with benefit structures
- **loyalty_referrals**: Referral relationships and completion tracking
- **loyalty_campaigns**: Promotional campaigns with earning rules
- **loyalty_redemptions**: Reward redemption history

### Key Entities
- **LoyaltyAccount**: Core entity linking customer to loyalty program
- **Transaction**: Records of all points movements
- **Reward**: Redeemable items or benefits
- **Tier**: Membership levels with different privileges

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | - | PostgreSQL connection string |
| `REDIS_URL` | Yes | - | Redis connection string |
| `DAPR_PUBSUB_NAME` | Yes | - | Dapr pub/sub component name |
| `SERVICE_PORT` | No | `9014` | gRPC service port |
| `HTTP_PORT` | No | `8014` | HTTP service port |
| `LOG_LEVEL` | No | `info` | Logging level |

### Config Files
- **Location**: `loyalty-rewards/configs/`
- **Key settings**: Database connection, Redis config, service endpoints

## Deployment

### Docker
- **Image**: `registry/ta-microservices/loyalty-rewards`
- **Ports**: 9014 (gRPC), 8014 (HTTP)
- **Health check**: `grpc_health_probe -addr=:9014`

### Kubernetes
- **Namespace**: `ta-microservices`
- **Resources**: CPU: 500m-2, Memory: 1Gi-4Gi
- **Scaling**: Min 2, Max 10 replicas

## Monitoring & Observability

### Metrics
- Points earned/redeemed per day
- Active accounts and tier distribution
- Redemption success rates
- Campaign participation metrics

### Logging
- Structured logging with customer IDs (anonymized)
- Transaction events and error conditions
- Performance metrics for API calls

### Tracing
- Distributed tracing for cross-service calls
- Transaction processing spans
- Database query performance

## Development

### Local Setup
1. Prerequisites: Go 1.25+, Docker, PostgreSQL, Redis
2. Clone repository and setup configs
3. Run database migrations
4. Start service with `make run`

### Testing
- Unit tests for business logic (biz layer)
- Integration tests for database operations
- API contract tests for gRPC services

## Troubleshooting

### Common Issues
- **Database connection failures**: Check DATABASE_URL and network connectivity
- **Redis cache misses**: Verify Redis connectivity and key patterns
- **Event publishing errors**: Check Dapr sidecar status and pub/sub configuration
- **High latency**: Monitor database query performance and add indexes if needed

### Debug Commands
```bash
# Check service health
grpc_health_probe -addr=localhost:9014

# View recent transactions
kubectl logs -f deployment/loyalty-rewards

# Check database connections
kubectl exec -it deployment/loyalty-rewards -- netstat -tlnp
```

## Changelog

See CHANGELOG.md for detailed version history.

## References

- [API Documentation](../04-apis/loyalty-api.md)
- [Order Service](./order-service.md)
- [Customer Service](./customer-service.md)
- [Notification Service](../operational-services/notification-service.md)

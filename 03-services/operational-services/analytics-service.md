# Analytics Service

**Version**: 1.0
**Last Updated**: 2026-02-11
**Service Type**: Operational
**Status**: Development (Critical Build Issues)

## Overview

The Analytics Service provides comprehensive business intelligence and analytics capabilities for the e-commerce platform. It aggregates data from multiple services to deliver real-time and historical insights on revenue, customer behavior, product performance, inventory, and operational metrics.

## Architecture

### Responsibilities
- **Dashboard Analytics**: Real-time overview metrics and KPIs
- **Revenue Analytics**: Sales performance, trends, and forecasting
- **Customer Analytics**: User behavior, segmentation, and lifetime value
- **Product Analytics**: Performance metrics, conversion rates, and inventory insights
- **Order Analytics**: Fulfillment metrics and order status distribution
- **Real-time Metrics**: Live data streams for active monitoring
- **Event Processing**: High-volume event ingestion and processing
- **Multi-channel Analytics**: Cross-platform sales and customer insights

### Dependencies
- **Upstream services**: Order, Product, Customer, Payment, Warehouse, Shipping, Fulfillment
- **Downstream services**: Admin dashboard, Frontend applications
- **External dependencies**:
  - PostgreSQL (analytics database)
  - Redis (caching and pub/sub)
  - Dapr PubSub (event processing)

## API Contract

### gRPC Services
- **Service**: `api.analytics.v1.AnalyticsService`
- **Proto location**: `analytics/api/analytics/v1/`
- **Key methods**:
  - `GetDashboardOverview(Request) → Response` - Dashboard metrics
  - `GetRevenueAnalytics(Request) → Response` - Revenue analysis
  - `GetOrderAnalytics(Request) → Response` - Order metrics
  - `GetProductPerformance(Request) → Response` - Product analytics
  - `GetCustomerAnalyticsSummary(Request) → Response` - Customer insights
  - `GetInventoryAnalytics(Request) → Response` - Inventory metrics
  - `GetRealTimeMetrics(Request) → Response` - Live data

### HTTP Endpoints
- `GET /api/v1/analytics/dashboard/overview` - Dashboard data
- `GET /api/v1/analytics/revenue` - Revenue analytics
- `GET /api/v1/analytics/orders` - Order analytics
- `GET /api/v1/analytics/products/performance` - Product performance
- `GET /api/v1/analytics/customers/summary` - Customer summary
- `GET /api/v1/analytics/inventory` - Inventory analytics
- `GET /api/v1/analytics/realtime` - Real-time metrics

## Data Model

### Database Tables
- **analytics_events**: Raw event storage
- **processed_events**: Deduplication tracking
- **dead_letter_queue**: Failed event processing
- **event_sequence_tracking**: Event ordering
- **dashboard_metrics**: Cached dashboard data
- **revenue_analytics**: Revenue aggregations
- **customer_analytics**: Customer insights
- **product_analytics**: Product performance data

### Key Entities
- **AnalyticsEvent**: Standardized event structure
- **DashboardMetrics**: KPI aggregations
- **RevenueAnalytics**: Sales performance data
- **CustomerSegment**: User behavior groups
- **ProductPerformance**: Item-level metrics

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANALYTICS_GRPC_PORT` | Yes | 9017 | gRPC server port |
| `ANALYTICS_HTTP_PORT` | Yes | 8017 | HTTP gateway port |
| `ANALYTICS_DB_HOST` | Yes | - | PostgreSQL host |
| `ANALYTICS_REDIS_HOST` | Yes | - | Redis host |
| `ANALYTICS_SERVICE_TIMEOUT` | No | 30s | Service timeout |

### Config Files
- **Location**: `analytics/configs/`
- **Key settings**: Database connections, service endpoints, cache TTL

## Deployment

### Docker
- **Image**: `registry/ta-microservices/analytics`
- **Ports**: 8017 (HTTP), 9017 (gRPC)
- **Health check**: `GET /health/live`

### Kubernetes
- **Namespace**: `ta-microservices`
- **Resources**: CPU: 500m-2, Memory: 1Gi-4Gi
- **Scaling**: Min 2, Max 10 replicas

## Monitoring & Observability

### Metrics
- **Event Processing**: Events/sec, success rate, latency
- **API Performance**: Request count, error rate, response time
- **Data Freshness**: Cache hit rate, data age
- **Business KPIs**: Revenue trends, conversion rates

### Logging
- **Structured JSON**: Request IDs, user context, operation details
- **Log levels**: INFO (business events), WARN (degraded performance), ERROR (failures)

### Tracing
- **OpenTelemetry**: Distributed tracing across service calls
- **Key spans**: Event processing, data aggregation, API responses

## Development

### Local Setup
1. **Prerequisites**: Go 1.21+, Docker, PostgreSQL, Redis
2. **Configuration**: Copy `.env.example` to `.env`
3. **Database**: Run migrations with `make migrate-up`
4. **Services**: Start dependencies via docker-compose
5. **Build**: `make build && make run`

### Testing
- **Unit tests**: `make test` (business logic coverage >80%)
- **Integration tests**: Real database and service mocks
- **Performance tests**: Event processing throughput

## Troubleshooting

### Common Issues
- **Event processing lag**: Check Redis connectivity and queue depth
- **Data inconsistency**: Verify event deduplication and ordering
- **High memory usage**: Monitor cache size and implement TTL
- **Slow queries**: Check database indexes and query optimization

### Debug Commands
```bash
# Check event processing status
kubectl logs -f deployment/analytics | grep "processed"

# Monitor queue depth
kubectl exec -it analytics-pod -- redis-cli LLEN analytics:events

# Check database connections
kubectl exec -it analytics-pod -- psql -c "SELECT count(*) FROM analytics_events"
```

## Changelog

### [1.0.0] - 2026-01-31
- Initial service implementation
- Event processing pipeline
- Core analytics APIs
- Multi-channel support

## References

- [API Documentation](../04-apis/analytics-api.md)
- [Event Processing Guide](../05-events/event-processing.md)
- [Related Services](./notification-service.md)
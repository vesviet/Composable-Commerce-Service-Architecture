# 📊 Analytics Service - Business Intelligence & Metrics

> **Owner**: Platform Team  
> **Last Updated**: 2026-03-04  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: HTTP 8019 / gRPC 9019

**Service Name**: Analytics Service  
**Version**: 1.2.7  
**Production Ready**: 85%  
**Code Review**: [Analytics Service Review Checklist](../../10-appendix/workflow/analytics-review-checklist.md)  

---

## 🎯 Overview

Analytics Service is a passive event consumer that collects, aggregates, and serves business intelligence metrics for the e-commerce platform. It subscribes to cross-service events (orders, payments, fulfillment, shipping, returns, page views, cart conversions) and provides dashboard, revenue, product, customer, and operational analytics via gRPC API.

### Core Capabilities
- **📈 Dashboard Metrics**: Real-time KPI dashboard (revenue, orders, customers, conversion)
- **💰 Revenue Analytics**: Revenue trends, top products, category sales, margins
- **👥 Customer Analytics**: Customer segments, cohorts, RFM scoring, retention
- **📦 Order Analytics**: Order status distribution, fulfillment metrics, trends
- **🏪 Product Analytics**: Product performance, category breakdown
- **🔄 Return/Refund Analytics**: Return rates, refund analysis, reason tracking
- **🌐 Multi-Channel Analytics**: Marketplace integrations (Shopee, Lazada, TikTok)
- **🗓️ Customer Journey**: Touchpoint tracking across the purchase lifecycle
- **⚡ Event Processing**: PII-safe, idempotent, schema-validated event ingestion
- **🔔 Alert System**: Automated anomaly detection on key metrics
- **📊 Data Reconciliation**: Daily event loss detection vs 7-day rolling averages

### Business Value
- **Decision Intelligence**: Data-driven insights for business operations
- **Revenue Tracking**: Accurate, real-time revenue and order metrics
- **Customer Insights**: RFM scoring and segmentation for marketing
- **Operational Excellence**: Fulfillment SLA tracking and anomaly alerting

---

## 🏗️ Architecture

### Dual-Binary Architecture
```
analytics/
├── cmd/
│   ├── server/                # Main API server (gRPC + HTTP event handler)
│   └── worker/                # Background worker (cron: aggregation, alerts, retention, reconciliation)
├── internal/
│   ├── biz/                   # Domain entities, use case interfaces, repository interfaces
│   │   └── mocks/             # Mockgen-generated mocks
│   ├── data/                  # PostgreSQL repositories
│   ├── service/               # gRPC service implementations, event processor
│   │   └── marketplace/       # External marketplace API integrations
│   ├── handler/               # HTTP event handler (Dapr subscriptions), health checks
│   ├── server/                # gRPC server setup, middleware registration
│   ├── middleware/            # JWT auth middleware
│   ├── config/                # Configuration loading
│   ├── infrastructure/        # Database (PostgreSQL) and Redis clients
│   │   ├── database/
│   │   └── redis/
│   ├── schema/                # JSON schemas for event validation
│   ├── pkg/
│   │   ├── pii/               # PII anonymization (SHA-256 hashing, IP masking, email masking)
│   │   └── circuitbreaker/    # Circuit breaker for external API calls
│   └── worker/
│       └── cron/              # Cron job wrappers (aggregation, alerts, retention, reconciliation)
├── api/analytics/v1/          # Proto definitions & generated code
├── dapr/                      # Dapr subscription YAML (subscription.yaml, subscription-dlq.yaml)
├── migrations/                # Goose SQL migrations
└── configs/                   # config.yaml
```

### Ports & Dependencies
- **HTTP API**: `:8019` — Dapr event subscriptions, health checks
- **gRPC API**: `:9019` — Analytics query API (dashboard, revenue, order, product, customer)
- **Database**: PostgreSQL (`analytics_db`)
- **Cache**: Redis for metrics caching and cache invalidation
- **Dependencies**: `common@v1.23.1`

---

## 🔌 Key APIs

### gRPC Services (from `api/analytics/v1/`)

#### AnalyticsService
| RPC | Description |
|-----|-------------|
| `GetDashboardMetrics` | KPI dashboard: revenue, orders, customers, conversion rate |
| `GetRevenueData` | Revenue time series with filters |
| `GetRevenueMetrics` | Aggregate revenue KPIs |
| `GetTopProducts` | Top N products by revenue |
| `GetTopCategories` | Top N categories by revenue |
| `GetSalesByCategory` | Category breakdown |
| `GetOrderMetrics` | Order-level KPIs |
| `GetOrderStatusDistribution` | Order status breakdown |
| `GetOrderTrend` | Order trend over time |
| `GetFulfillmentMetrics` | Fulfillment SLA and processing metrics |
| `GetProductPerformance` | Product-level performance data |
| `GetProductMetrics` | Aggregate product KPIs |
| `GetCustomerMetrics` | Customer acquisition, retention |
| `GetCustomerSegments` | Customer segment breakdown |
| `GetCustomerCohorts` | Cohort analysis |

#### MultiChannelService
| RPC | Description |
|-----|-------------|
| `GetMultiChannelAnalytics` | Cross-marketplace metrics (Shopee, Lazada, TikTok) |

#### CustomerJourneyService
| RPC | Description |
|-----|-------------|
| `GetCustomerJourney` | Full journey for a customer ID |
| `GetJourneyTouchpoints` | Touchpoints with attribution |

#### ReturnRefundService
| RPC | Description |
|-----|-------------|
| `GetReturnRefundAnalytics` | Return/refund rates and trends |

#### EventProcessingService
| RPC | Description |
|-----|-------------|
| `GetEventProcessingMetrics` | Event processing stats (throughput, errors, DLQ) |
| `GetDeadLetterQueueEvents` | DLQ listing with filters |
| `RetryDeadLetterQueueEvent` | Retry a failed event |
| `ResolveDeadLetterQueueEvent` | Manually resolve a DLQ event |

### HTTP Event Endpoints (Dapr Subscriptions)
| Route | Event Topic | Description |
|-------|-------------|-------------|
| `/events/orders` | `orders.order.status_changed` | Order lifecycle events |
| `/events/payments` | `payment.payment.*` | Payment processed/failed/refunded |
| `/events/shipping` | `shipping.shipment.status_changed` | Shipping status changes |
| `/events/fulfillment` | `fulfillments.fulfillment.*` | Fulfillment lifecycle + SLA breach |
| `/events/returns` | `orders.return.*` | Return requested/approved/completed/rejected |
| `/events/page-views` | `analytics.page_view` | Page view tracking |
| `/events/cart` | `cart.converted` | Cart-to-order conversion |
| `/events/dlq` | `dlq.analytics.*` | Dead letter queue handler |

---

## 📊 Event-Driven Architecture

### Consumed Events
Analytics is a **passive consumer** — it subscribes to events from other services but never publishes its own.

| Source Service | Event Topic | Route |
|----------------|-------------|-------|
| Order | `orders.order.status_changed` | `/events/orders` |
| Payment | `payment.payment.processed` | `/events/payments` |
| Payment | `payment.payment.failed` | `/events/payments` |
| Payment | `payment.payment.refunded` | `/events/payments` |
| Shipping | `shipping.shipment.status_changed` | `/events/shipping` |
| Fulfillment | `fulfillments.fulfillment.status_changed` | `/events/fulfillment` |
| Fulfillment | `fulfillments.fulfillment.sla_breach` | `/events/fulfillment` |
| Order (Returns) | `orders.return.requested` | `/events/returns` |
| Order (Returns) | `orders.return.approved` | `/events/returns` |
| Order (Returns) | `orders.return.completed` | `/events/returns` |
| Order (Returns) | `orders.return.rejected` | `/events/returns` |
| Frontend | `analytics.page_view` | `/events/page-views` |
| Checkout | `cart.converted` | `/events/cart` |

### Event Processing Guarantees
- **Idempotency**: Every event is checked against `processed_events` table before processing
- **Schema Validation**: JSON schema validation (fail-closed) for order, product, customer, page view events
- **PII Anonymization**: Email masking, IP masking, user agent hashing before storage
- **DLQ Support**: Failed events routed to dead letter queue after 3 retries
- **Body Size Limit**: 1MB max to prevent OOM
- **CloudEvent Parsing**: Full CloudEvent envelope (ID, source, type, time, traceparent)

---

## ⏰ Worker / Cron Jobs

The `cmd/worker/` binary runs 4 cron jobs:

| Cron Job | Interval | RunOnStart | Description |
|----------|----------|------------|-------------|
| **Aggregation** | 1 hour | Yes | Hourly: aggregate metrics + refresh materialized views. Daily (after 1 AM): full pipeline — customer, order, product, operational, fulfillment, search, return/refund, RFM scores, conversion funnel |
| **Alert Checker** | 5 minutes | Yes | Check alert conditions, invalidate alerts cache |
| **Retention** | 24 hours | Yes | Drop old partitions (90-day retention), ensure upcoming partitions exist |
| **Reconciliation** | 24 hours | No | Compare daily event counts against 7-day rolling average to detect event loss |

---

## 🔗 Integration Points

### Consumed By
- **Gateway**: Routes analytics gRPC API requests (imports `analytics@v1.2.7`)

### External Marketplace APIs
- **Shopee**: Order data integration (circuit breaker protected)
- **Lazada**: Order data integration (circuit breaker protected)
- **TikTok Shop**: Order data integration (circuit breaker protected)

---

## 🛡️ Resilience Patterns

| Pattern | Implementation |
|---------|---------------|
| **Circuit Breaker (PG writes)** | `data/pg_circuit_breaker.go` — closed/open/half-open states for SaveEvent, BatchSaveEvents, CreateProcessedEvent |
| **Circuit Breaker (External APIs)** | `pkg/circuitbreaker/` — for marketplace API calls |
| **Batch Writes** | Multi-row INSERT with 500-row chunks (avoids PG 65535 param limit) |
| **Graceful Degradation** | Non-critical aggregation steps log errors but don't fail the job |
| **Idempotency** | Event ID-based deduplication in `processed_events` table |
| **DLQ** | Dead letter topic per subscription with configurable retry (maxRetryCount: 3) |

---

## 🚀 Development Guide

### Quick Start
```bash
cd analytics
go mod tidy
make wire         # Generate DI (server + worker)
make run          # Start API server
make run-worker   # Start worker binary
```

### Configuration
```yaml
# configs/config.yaml
server:
  http:
    addr: 0.0.0.0:8019
  grpc:
    addr: 0.0.0.0:9019
data:
  database:
    driver: postgres
    source: postgres://analytics_user:analytics_pass@localhost:5432/analytics_db?sslmode=disable
  redis:
    addr: redis.default.svc.cluster.local:6379
```

---

**Service Status**: Production Ready (85%)  
**Critical Path**: Event ingestion pipeline and daily aggregation  
**Performance Target**: <100ms dashboard queries (with cache), <5s daily aggregation  

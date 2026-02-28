# Analytics Service

## Overview

The **analytics** service provides business intelligence, reporting, and real-time metrics for the e-commerce platform. It is a **passive consumer** — it subscribes to cross-service events (orders, payments, shipping, fulfillment, page views, returns, carts) via Dapr PubSub and aggregates the data into queryable analytics.

## Architecture

- **Framework**: Go 1.25+ / Kratos v2 (gRPC + HTTP gateway)
- **Database**: PostgreSQL (partitioned tables, materialized views)
- **Cache**: Redis (metrics caching, real-time counters)
- **Event Bus**: Dapr PubSub (Redis Streams)
- **DI**: Google Wire (server + worker binaries)

### Dual-Binary Architecture

| Binary | Entry Point | Purpose |
|--------|-------------|---------|
| `analytics` (server) | `cmd/server/main.go` | gRPC APIs, HTTP gateway, event ingestion via Dapr subscriptions |
| `analytics-worker` | `cmd/worker/main.go` | Cron jobs: daily/hourly aggregation, alert condition checker |

### Clean Architecture Layers

| Layer | Directory | Responsibility |
|-------|-----------|----------------|
| **API** | `api/analytics/v1/` | Proto definitions (5 gRPC services) |
| **Service** | `internal/service/` | gRPC implementations, event processor, aggregation orchestration |
| **Business** | `internal/biz/` | Use case interfaces + implementations (20+ use cases) |
| **Data** | `internal/data/` | PostgreSQL repositories, circuit breaker wrapper |
| **Handler** | `internal/handler/` | HTTP event handlers (Dapr subscriptions), health checks |
| **Infrastructure** | `internal/infrastructure/` | Database + Redis connections |
| **Worker** | `internal/worker/cron/` | Aggregation and alert checker cron jobs |

## Ports

| Protocol | Port | Standard |
|----------|------|----------|
| HTTP | 8019 | PORT_ALLOCATION_STANDARD |
| gRPC | 9019 | PORT_ALLOCATION_STANDARD |
| Worker Health | 8081 | Common worker pattern |

## gRPC Services

1. **AnalyticsService** — Dashboard, revenue, order, product, customer, inventory, real-time metrics
2. **MultiChannelService** — Multi-channel analytics, channel performance, unified customer view
3. **CustomerJourneyService** — Journey analytics, attribution, path-to-purchase patterns
4. **ReturnRefundService** — Return/refund analytics by product, category, reason
5. **EventProcessingService** — DLQ management, event processing metrics

## Event Subscriptions (Dapr)

Subscribes to 12 topics from order, payment, shipping, fulfillment, and cart services:
- `orders.order.status_changed`, `orders.return.*`
- `payment.payment.processed/failed/refunded`
- `shipping.shipment.status_changed`
- `fulfillments.fulfillment.status_changed/sla_breach`
- `cart.converted`, `analytics.page_view`

All subscriptions have DLQ topics (`dlq.analytics.*`) with `maxRetryCount=3`.

## Key Features

- **PII Protection**: User-agent hashing, IP masking, email redaction via `internal/pkg/pii`
- **Circuit Breaker**: PostgreSQL write-path protection (`pgCircuitBreaker` wrapper)
- **Event Idempotency**: `processed_events` table with duplicate detection
- **Schema Validation**: JSON schema validation using `common/events.JSONSchemaValidator`
- **Dead Letter Queue**: Failed events persisted for manual resolution
- **Bounded Dedup Cache**: In-memory LRU with TTL eviction (prevents OOM)
- **Data Retention**: Partition-based retention with configurable TTL
- **Alert System**: Configurable threshold-based alerting via cron

## Dependencies

- **Proto consumers**: `gateway` imports analytics proto
- **Event producers**: `order`, `payment`, `shipping`, `fulfillment` services
- **Shared libraries**: `common` v1.17.0 (config, worker, events)

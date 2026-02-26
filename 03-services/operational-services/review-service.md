# Review Service

**Domain**: Operational Services  
**Version**: v1.2.0  
**Ports**: HTTP `:8016` | gRPC `:9016`

## Purpose

The Review Service manages all product reviews, ratings, and content moderation for the e-commerce platform. It is the source of truth for customer review data, aggregated rating statistics, and moderation decisions.

## Architecture

The service follows Clean Architecture with four business domains:

| Domain | Responsibility |
|--------|---------------|
| **Review** | Review CRUD, eligibility check, idempotent submission |
| **Rating** | Aggregated product rating calculation and caching |
| **Moderation** | Auto-moderation scoring and manual moderation workflow |
| **Helpful** | Customer helpfulness voting for reviews |

### Dual-Worker Architecture

The service uses a single binary with two types of background workers managed by separate registries:

- **Continuous Workers** (`ContinuousWorkerRegistry`): `moderation-worker`, `rating-aggregation-worker`, `analytics-worker` — long-running event listeners
- **Periodic Worker** (`WorkerRegistry`): `outbox-worker` — polls the outbox table every 100ms with `FOR UPDATE SKIP LOCKED` to publish events reliably

### Outbox Pattern

All domain events (review created/updated/approved/rejected, rating updated) are first written to the `outbox_event` table **within the same transaction** as the business operation. The `OutboxWorker` then fetches and publishes them to Dapr PubSub asynchronously. This guarantees at-least-once delivery without distributed transactions.

## Events Published

| Topic | Event Type | Trigger |
|-------|-----------|---------|
| `review-events` | `review.created` | New review submitted |
| `review-events` | `review.updated` | Review content changed |
| `review-events` | `review.approved` | Moderation approved |
| `review-events` | `review.rejected` | Moderation rejected |
| `review-events` | `rating.updated` | Rating recalculation complete |

## Events Consumed

| Topic | Event Type | Action |
|-------|-----------|--------|
| `shipment-events` | `shipment.delivered` | Marks order eligible for review |

## Key Business Rules

- **One review per (customer, product)**: Enforced at DB level via partial unique index (migration 005)
- **One review per order**: Enforced at DB level via partial unique index (migration 005)
- **Idempotent submission**: Requests with the same `idempotency_key` return the same result
- **Auto-moderation on creation**: Reviews are immediately auto-moderated after creation
- **Outbox guarantees**: Events are only lost if the outbox row is deleted before processing

## Dependencies

| Service | Type | Purpose |
|---------|------|---------|
| Order Service | gRPC client | Verify purchase eligibility |
| Catalog Service | gRPC client | Verify product status |
| User Service | gRPC client | User info for moderation |

## Configuration

`configs/config.yaml` controls:
- Server ports (HTTP `8016`, gRPC `9016`)
- DB connection pool (`max_open_conns: 100`)
- Redis DB index (`db: 5`)
- Auto-moderation thresholds (`auto_approve_threshold: 70.0`, `auto_reject_threshold: 50.0`)

## Database Migrations

| Migration | Description |
|-----------|-------------|
| 001 | Create reviews table |
| 002 | Add review fields (pros, cons, recommended, seller response) |
| 003 | Order review eligibility table |
| 004 | Idempotency records table |
| 005 | Fix unique review constraints (partial indexes) |
| 006 | Outbox events table |

## GitOps

- **Namespace**: `review`
- **Deployment**: `gitops/apps/review/base/deployment.yaml`
- **HPA**: 2-8 replicas (CPU 70%, memory 80%)
- **PDB**: Configured for zero-downtime rolling updates

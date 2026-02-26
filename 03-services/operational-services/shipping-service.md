# Shipping Service

**Version**: v1.1.9
**Status**: ✅ Production Ready
**Last Updated**: 2026-02-26

---

## Overview

The Shipping Service manages the complete lifecycle of physical shipments — from shipment creation and label generation through carrier dispatch, real-time tracking, and delivery confirmation. It integrates with multiple external carrier providers (UPS, FedEx, DHL, USPS, GHN, Grab) and exposes both gRPC and HTTP APIs.

---

## Responsibilities

- **Shipment lifecycle**: Create → Draft → Processing → Ready → Shipped → Delivered/Failed/Cancelled
- **Label generation**: Multi-carrier label creation with failover (primary → fallback carriers), per-carrier exponential-backoff retry, and outbox-based event publishing
- **Real-time tracking**: Carrier webhook ingestion, tracking event persistence, and `shipment.tracking_event` outbox publication
- **Returns management**: RMA creation, return status transitions, and `return.status_changed` outbox events
- **Order cancellation compensation**: Cancels all active shipments when `orders.order_cancelled` is received
- **RBAC**: Shippers can only view and confirm delivery for their own assigned shipments

---

## Architecture

```
cmd/shipping/           → Main API server (gRPC + HTTP, port 9012 / 8012)
cmd/worker/             → Worker binary (event consumers + outbox processor, HTTP health 8081)
internal/biz/shipment/  → Domain use case (ShipmentUseCase)
internal/biz/shipping_method/ → Rate calculation & method caching
internal/biz/carrier/   → Carrier abstraction
internal/carrier/       → Carrier implementations (UPS, FedEx, DHL, USPS, GHN, Grab)
internal/carrierfactory/→ Carrier provider factory + failover logic
internal/data/postgres/ → Repository implementations
internal/data/eventbus/ → Dapr consumer wiring (package_status, order_cancelled)
internal/worker/        → Outbox worker + event consumer workers
internal/events/        → Outbox event helpers
internal/observer/      → Observer pattern for event fan-out
```

### Dual-Binary Architecture

| Binary | Port | Role |
|--------|------|------|
| `shipping` | HTTP 8012, gRPC 9012 | API server, service registry |
| `shipping-worker` | HTTP 8081 (health only) | Outbox publisher, event consumers |

---

## API

- **Proto**: `api/shipping/v1/shipping.proto`
- **HTTP**: Port 8012
- **gRPC**: Port 9012
- **OpenAPI**: `openapi.yaml`

### Key Endpoints

| Operation | Method | Path |
|-----------|--------|------|
| Create shipment | POST | `/v1/shipments` |
| Get shipment | GET | `/v1/shipments/{id}` |
| List shipments | GET | `/v1/shipments` |
| Update shipment status | PUT | `/v1/shipments/{id}/status` |
| Add tracking event | POST | `/v1/shipments/{id}/tracking` |
| Generate label | POST | `/v1/shipments/{id}/label` |
| Confirm delivery | POST | `/v1/shipments/{id}/confirm-delivery` |
| Create return | POST | `/v1/returns` |
| Calculate rates | POST | `/v1/rates` |

---

## Events

### Published (Outbox → Dapr)

| Topic | Trigger |
|-------|---------|
| `shipment.created` | `CreateShipment`, `BatchCreateShipments`, `handlePackageCreated` |
| `shipment.status_changed` | Any status transition |
| `shipment.delivered` | `ConfirmDelivery`, `UpdateShipmentStatus → delivered` |
| `shipment.label_generated` | `GenerateLabel` |
| `shipment.assigned` | `AssignShipment` |
| `shipment.tracking_event` | `AddTrackingEvent` |
| `return.created` | `CreateReturn` |
| `return.status_changed` | `UpdateReturnStatus` |

### Consumed

| Topic | Handler | Idempotency |
|-------|---------|-------------|
| `packages.package.status_changed` | `HandlePackageStatusChanged` → creates shipment on `created`, auto-ships on `ready` | ✅ Redis-based |
| `orders.order_cancelled` | `CancelShipmentsForOrder` → cancels all active shipments | ✅ Redis-based |

---

## Data Model

Key tables in `shipping_db`:

| Table | Description |
|-------|-------------|
| `shipments` | Core shipment records with advisory lock support |
| `tracking_events` | Immutable tracking event log |
| `returns` | Return/RMA records |
| `carriers` | Carrier configurations (credentials encrypted at rest) |
| `shipping_methods` | Available shipping methods with rate cache |
| `outbox_events` | Transactional outbox for guaranteed event publishing |
| `idempotency_keys` | Consumer deduplication keys (TTL-managed) |

---

## Dependencies

| Service | Protocol | Purpose |
|---------|----------|---------|
| Fulfillment | gRPC | Update package tracking & status after label generation |
| Catalog | gRPC | Product details for shipment metadata |
| Dapr PubSub (Redis) | Dapr | Event publishing and consumption |
| PostgreSQL | GORM | Primary data store |
| Redis | go-redis | Idempotency key store, rate cache |
| Consul | HTTP | Service registration and discovery |

---

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `server.http.addr` | `0.0.0.0:8012` | HTTP listen address |
| `server.grpc.addr` | `0.0.0.0:9012` | gRPC listen address |
| `shipping.default_carrier` | `ups` | Fallback carrier when none specified |
| `shipping.free_shipping_threshold` | 75.00 | Order value above which shipping is free |
| `shipping.max_package_weight` | 70.0 kg | Maximum allowed package weight |
| `security.encryption_key` | (env) | AES key for carrier credential encryption |
| `cache.default_ttl` | 5m | Default Redis cache TTL |

---

## GitOps

| File | Description |
|------|-------------|
| `gitops/apps/shipping/base/deployment.yaml` | Main API deployment (HTTP 8012, gRPC 9012) |
| `gitops/apps/shipping/base/worker-deployment.yaml` | Worker deployment (health HTTP 8081) |
| `gitops/apps/shipping/base/service.yaml` | ClusterIP service exposing 8012/9012 |
| `gitops/apps/shipping/base/worker-hpa.yaml` | HPA for worker pod autoscaling |
| `gitops/apps/shipping/overlays/dev/configmap.yaml` | Dev environment overrides |

---

## Security

- **Authentication**: Gateway validates JWT and injects `X-User-ID`. gRPC paths under `/api.shipping.v1.ShippingService/` are trusted (token already validated upstream).
- **Authorization**: RBAC via `UserContext` — shippers scoped to assigned shipments only.
- **Carrier credentials**: Encrypted at rest using AES-256; `model.SetEncryptionKey` called at startup.
- **Health endpoints** (`/health`, `/health/live`, `/health/ready`, `/metrics`, `/docs/`) bypass auth.

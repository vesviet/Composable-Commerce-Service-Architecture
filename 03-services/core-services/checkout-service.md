# 🛒 Checkout Service - Complete Documentation

> **Owner**: Core Team
> **Last Updated**: 2026-11-23
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)
> **Ports**: HTTP `8010` | gRPC `9010`

**Service Name**: Checkout Service
**Version**: v1.6.1
**Review Status**: ✅ Reviewed
**Production Ready**: 100%

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [API Contract](#-api-contract)
- [Data Model](#-data-model)
- [Checkout Flow](#-checkout-flow)
- [Configuration](#-configuration)
- [Dependencies](#-dependencies)
- [Monitoring & Observability](#-monitoring--observability)
- [Known Issues & TODOs](#-known-issues--todos)
- [Development Guide](#-development-guide)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Overview

Checkout Service handles the **entire cart-to-order journey** for the e-commerce platform. It implements the **Quote Pattern** — building an order quote from cart state, validating stock, calculating totals (with live price revalidation), authorizing payment, and delegating order creation to the Order service.

### Core Capabilities
- **🛒 Cart Management**: Create, add/update/remove items, merge guest→customer carts, apply promotions
- **📋 Checkout Sessions**: Multi-step checkout with shipping address, billing, shipping method, payment method
- **💰 Price Revalidation**: Real-time price verification at confirm time to prevent stale-price exploitation
- **📦 Inventory Reservation**: Reserve stock via Warehouse service, extend TTL during payment, rollback on failure
- **💳 Payment Authorization**: Authorize payment before order creation, void on failure, COD skip-auth
- **🎟️ Promotion Application**: Validate coupons, calculate discounts, coupon-lock to prevent race
- **📤 Order Delegation**: Delegate order creation to Order service after all validations pass
- **🔄 Saga Compensation**: DLQ for failed void/promo operations with async retry via worker
- **📮 Outbox Pattern**: Reliable event publishing (CartConverted) via outbox table + outbox worker
- **🔑 Idempotency**: SETNX lock + version-aware key prevents duplicate orders on retry

### Business Value
- **Cart Abandonment Prevention**: Session timeouts, cart expiry, guest cart merge
- **Revenue Protection**: Price revalidation prevents stale-price exploits
- **Stock Accuracy**: Real-time reservation prevents overselling
- **Payment Safety**: Saga compensation ensures no money leaks on failure
- **Fraud Mitigation**: Pre-checkout fraud scoring (fail-open)

---

## 🏗️ Architecture

### Dual-Binary Architecture

| Aspect | Main Service (`cmd/server/`) | Worker (`cmd/worker/`) |
|--------|------|--------|
| **Purpose** | Serve gRPC/HTTP API | Outbox processing, cron cleanup, failed compensation retry |
| **Entry point** | `cmd/server/main.go` | `cmd/worker/main.go` |
| **Wire DI** | `cmd/server/wire.go` | `cmd/worker/wire.go` |
| **K8s Deployment** | `deployment.yaml` | `worker-deployment.yaml` |
| **Ports** | HTTP `8010` + gRPC `9010` | HTTP `8019` (healthz only) |
| **Dapr app-id** | `checkout` | `checkout-worker` |

### Directory Structure

```
checkout/
├── cmd/
│   ├── server/                      # 🔵 MAIN SERVICE BINARY
│   │   ├── main.go                 #    Kratos HTTP+gRPC server
│   │   ├── wire.go                 #    DI: services + repos + clients
│   │   └── wire_gen.go             #    Auto-generated
│   ├── worker/                     # 🟠 WORKER BINARY
│   │   ├── main.go                 #    Outbox + cron workers
│   │   ├── wire.go                 #    DI: workers + repos
│   │   └── wire_gen.go             #    Auto-generated
│   └── migrate/                    # 🟢 MIGRATION BINARY
│       └── main.go                 #    Goose migration runner
├── internal/
│   ├── biz/                        # 🔴 BUSINESS LOGIC LAYER
│   │   ├── biz.go                  #    Domain models, interfaces (771 lines)
│   │   ├── errors.go               #    Sentinel domain errors
│   │   ├── interfaces.go           #    Repository + service interfaces
│   │   ├── converters.go           #    Domain model converters
│   │   ├── cart/                   #    Cart use case
│   │   │   ├── usecase.go          #      Constructor + DI
│   │   │   ├── crud.go             #      Create, Get, AddItem, UpdateItem, RemoveItem
│   │   │   ├── totals.go           #      Cart total calculation
│   │   │   ├── promotions.go       #      Coupon + auto-promotion logic
│   │   │   ├── merge.go            #      Guest → customer cart merge
│   │   │   ├── stock.go            #      Stock validation + reservation
│   │   │   └── metrics.go          #      Prometheus cart metrics
│   │   └── checkout/               #    Checkout use case
│   │       ├── usecase.go          #      Constructor + DI
│   │       ├── confirm.go          #      ConfirmCheckout (main flow)
│   │       ├── confirm_guards.go   #      Fraud, zone, eligibility checks
│   │       ├── start.go            #      StartCheckout
│   │       ├── state.go            #      GetCheckoutState, UpdateCheckoutState
│   │       ├── preview.go          #      PreviewOrder
│   │       ├── totals.go           #      CalculateOrderTotals (price revalidation)
│   │       ├── payment.go          #      Payment authorization + COD
│   │       ├── shipping.go         #      Shipping rate calculation
│   │       └── stock.go            #      Reservation extension + rollback
│   ├── service/                    # API ADAPTER LAYER
│   │   ├── cart.go                 #    CartService gRPC implementation
│   │   ├── checkout.go             #    CheckoutService gRPC implementation
│   │   ├── converters.go           #    Proto ↔ domain converters
│   │   ├── error_handling.go       #    Error classification
│   │   └── validation_helpers.go   #    Input validation
│   ├── data/                       # DATA LAYER
│   │   ├── data.go                 #    DB, Redis, TransactionManager
│   │   ├── cart_repo.go            #    CartRepo (GORM)
│   │   ├── checkout_repo.go        #    CheckoutSessionRepo (GORM)
│   │   ├── outbox_repo.go          #    OutboxRepo (GORM)
│   │   └── failed_compensation_repo.go
│   ├── client/                     # OUTBOUND gRPC CLIENTS
│   │   ├── order_client.go         #    Order service
│   │   ├── payment_client.go       #    Payment service
│   │   ├── catalog_client.go       #    Catalog service
│   │   ├── warehouse_client.go     #    Warehouse service
│   │   ├── shipping_client.go      #    Shipping service
│   │   ├── pricing_client.go       #    Pricing service
│   │   ├── promotion_client.go     #    Promotion service
│   │   └── customer_client.go      #    Customer service
│   ├── events/                     # EVENT PUBLISHING
│   │   └── publisher.go            #    Dapr publisher (CartConverted, OrderStatusChanged)
│   ├── worker/                     # WORKER MODULES
│   │   ├── outbox/worker.go        #    Outbox processor (dedup, stuck recovery)
│   │   └── cron/
│   │       ├── cart_cleanup.go     #    Expired cart cleanup
│   │       ├── checkout_session_cleanup.go
│   │       └── failed_compensation.go  # Failed compensation retry
│   ├── cache/cache_helper.go       # Redis cache (cart, promotions)
│   ├── model/                      # GORM models
│   ├── config/                     # Config structs
│   ├── constants/                  # Topics, limits, status enums
│   ├── middleware/                  # Auth middleware
│   └── observability/prometheus/   # Metrics
├── api/checkout/v1/                # PROTO DEFINITIONS
│   ├── cart.proto                  #    CartService (9 RPCs)
│   └── checkout.proto              #    CheckoutService (9 RPCs)
├── migrations/                     # Goose migrations (5 files)
└── configs/config.yaml
```

---

## 🔌 API Contract

### CartService (9 RPCs)

| RPC | Auth | Description |
|-----|------|-------------|
| `CreateCart` | Optional | Create cart (guest or customer) |
| `GetCart` | Optional | Get cart by session ID |
| `AddItem` | Optional | Add item to cart (validates stock + price) |
| `UpdateItem` | Optional | Update item quantity |
| `RemoveItem` | Optional | Remove item from cart |
| `ClearCart` | Optional | Clear all items |
| `MergeCarts` | Required | Merge guest cart into customer cart |
| `ApplyPromotion` | Optional | Apply promotion/coupon code |
| `RemovePromotion` | Optional | Remove promotion code |

### CheckoutService (9 RPCs)

| RPC | Auth | Description |
|-----|------|-------------|
| `StartCheckout` | Required | Start checkout session from cart |
| `GetCheckout` | Required | Get checkout state |
| `UpdateShippingAddress` | Required | Set shipping address |
| `UpdateBillingAddress` | Required | Set billing address |
| `SelectShippingMethod` | Required | Select shipping method |
| `SelectPaymentMethod` | Required | Select payment method |
| `PreviewOrder` | Optional | Preview order totals (with live prices) |
| `ConfirmCheckout` | Required | Confirm & create order |
| `ValidateInventory` | Optional | Check stock availability |

---

## 💾 Data Model

### Database Tables (PostgreSQL)

| Table | Description |
|-------|-------------|
| `cart_sessions` | Cart metadata (customer_id, guest_token, status, version, expires_at) |
| `cart_items` | Cart line items (product_id, quantity, unit_price, reservation_id) |
| `checkout_sessions` | Multi-step checkout state (addresses, shipping, payment, promotions) |
| `outbox_events` | Outbox pattern for reliable event publishing |
| `failed_compensations` | DLQ for failed saga compensation operations |

### Key Statuses

- **Cart**: `active` → `checkout` → `completed` / `expired` / `abandoned`
- **Outbox**: `pending` → `processing` → `processed` / `failed`
- **Compensation**: `pending` → `retrying` → `completed` / `failed` / `alerted`

---

## 🔄 Checkout Flow (ConfirmCheckout)

```
ConfirmCheckout(req)
    │
    ├─ 1. Load & Validate Session + Cart
    │     ├─ Get/create checkout session
    │     ├─ Load cart, ensure checkout status
    │     └─ Guard: empty cart check
    │
    ├─ 2. Idempotency Lock (SETNX, 15min TTL)
    │     └─ Key: checkout:{cartID}:cust:{customerID}:v{cartVersion}
    │
    ├─ 3. Validate Prerequisites
    │     ├─ Session ownership
    │     ├─ Shipping address + method required
    │     ├─ Coupon stacking limit
    │     ├─ Per-SKU quantity ceiling (EDGE-06)
    │     ├─ Delivery zone validation (EDGE-04, fail-open)
    │     └─ Payment method eligibility (EDGE-05)
    │
    ├─ 4. Acquire Coupon Locks (P2-009)
    │
    ├─ 5. Calculate Order Totals (with price revalidation)
    │
    ├─ 6. Amount Validation (min/max order limits)
    │
    ├─ 7. Fraud Pre-Check (EDGE-03, fail-open)
    │
    ├─ 8. Authorize Payment (skip for COD)
    │
    ├─ 9. Final Stock Validation + Extend Reservations
    │     └─ Rollback extended TTLs on partial failure
    │
    ├─ 10. Create Order (via Order service)
    │      └─ Void payment auth on failure + DLQ
    │
    ├─ 11. Apply Promotions (best-effort, errgroup)
    │      └─ DLQ for failed promo application
    │
    ├─ 12. Finalize (in transaction)
    │      ├─ Save CartConverted event to outbox
    │      ├─ Mark cart as completed
    │      └─ Delete checkout session
    │
    └─ 13. Store Idempotency Result (24h TTL)
```

---

## ⚙️ Configuration

### `configs/config.yaml`

```yaml
server:
  http:
    addr: 0.0.0.0:8010
  grpc:
    addr: 0.0.0.0:9010

data:
  database:
    source: postgres://checkout_user:***@localhost:5432/checkout_db
  redis:
    addr: localhost:6379

business:
  cart:
    max_items_per_cart: 100
    cart_expiry_hours: 24
  checkout:
    checkout_timeout_minutes: 15
    auto_cancel_minutes: 30
  payment:
    timeout_minutes: 10
  inventory:
    reservation_timeout_minutes: 15
  default_currency: "VND"
```

### External Service Endpoints

All services use Kubernetes internal DNS for discovery:
- Order: `order.order-dev.svc.cluster.local:80/81`
- Payment: `payment.payment-dev.svc.cluster.local:80/81`
- Catalog: `catalog.catalog-dev.svc.cluster.local:80/81`
- Warehouse: `warehouse.warehouse-dev.svc.cluster.local:80/81`
- Shipping: `shipping.shipping-dev.svc.cluster.local:80/81`
- Pricing: `pricing.pricing-dev.svc.cluster.local:80/81`
- Promotion: `promotion.promotion-dev.svc.cluster.local:80/81`
- Customer: *(via Dapr service invocation)*

---

## 🔗 Dependencies

### Internal Services (gRPC clients)

| Service | Purpose |
|---------|---------|
| **Order** | Create order after checkout confirmation |
| **Payment** | Authorize/void payment |
| **Catalog** | Product pricing for revalidation |
| **Warehouse** | Stock reservation, extension, confirmation |
| **Shipping** | Shipping rate calculation |
| **Pricing** | Price calculation |
| **Promotion** | Coupon validation, discount calculation, usage tracking |
| **Customer** | Customer profile data |

### Infrastructure

| Component | Purpose |
|-----------|---------|
| **PostgreSQL** | Cart, checkout session, outbox, failed compensation |
| **Redis** | Idempotency locks, cart cache, promotion cache |
| **Dapr** | Event publishing (PubSub) |
| **Consul** | Service registry |

### Go Module Dependencies (go.mod)

```
gitlab.com/ta-microservices/common     v1.16.0
gitlab.com/ta-microservices/catalog    v1.3.3
gitlab.com/ta-microservices/customer   v1.2.2
gitlab.com/ta-microservices/order      v1.1.5
gitlab.com/ta-microservices/payment    v1.2.1
gitlab.com/ta-microservices/pricing    v1.1.8
gitlab.com/ta-microservices/promotion  v1.1.7
gitlab.com/ta-microservices/shipping   v1.1.6
gitlab.com/ta-microservices/warehouse  v1.1.9
```

No `replace` directives. ✅

### Who depends on this service?
- **Gateway**: Imports `checkout` proto for HTTP routing

### Events Published

| Topic | Event | Pattern |
|-------|-------|---------|
| `checkout.cart.converted` | CartConverted | Outbox (reliable, dedup via event_id) |

---

## 📊 Monitoring & Observability

### Prometheus Metrics

- `checkout_operations_total{operation, status}` — Per-operation counters
- `checkout_operation_duration_seconds{operation}` — Latency histograms
- `checkout_completed_total{payment_method}` — Successful checkouts
- `order_previews_total{status}` — Preview order calls

### Health Checks

- **Main Service**: `/health/live`, `/health/ready` on port `8010`
- **Worker**: `/healthz` on port `8019`

### Structured Logging

- JSON format with `trace_id`, `span_id`
- Context propagated through all layers via `log.WithContext(ctx)`
- Critical operations tagged: `[CRITICAL]`, `[EDGE-07]`, `[P1-003]`

---

## 🚨 Known Issues & TODOs

### P2 (Nice to Have)
- [ ] No `startupProbe` in worker K8s deployment
- [ ] Test coverage needs improvement

### Future Enhancements
- [ ] `TODO(EDGE-04)`: Replace delivery zone heuristic with `ShippingService.ValidateDeliveryAddress` RPC
- [ ] `TODO(EDGE-03)`: Integrate external fraud scoring service

---

## 🛠️ Development Guide

### Local Development

```bash
# Start dependencies
docker-compose up -d postgres redis

# Run migrations
go run cmd/migrate/main.go

# Run main service
go run cmd/server/main.go -conf configs/config.yaml

# Run worker
go run cmd/worker/main.go -conf configs/config.yaml
```

### Build & Deploy

```bash
golangci-lint run          # Lint (0 warnings target)
go build ./...             # Build both binaries
cd cmd/server && wire      # Regenerate Wire (main)
cd ../worker && wire       # Regenerate Wire (worker)
```

### Key Development Patterns

- **Transaction Manager**: `tm.WithTransaction(ctx, func(txCtx) error { ... })`
- **Outbox Pattern**: Critical events → `outboxRepo.Save()` inside transaction → worker publishes
- **DI via Wire**: Constructor injection, interfaces in `biz/interfaces.go`
- **Error Mapping**: Domain errors → `mapErrorToGRPC()` in service layer
- **Idempotency**: `idempotencyService.TryAcquire()` for critical operations

---

## 🔧 Troubleshooting

### Duplicate order on retry
- Check Redis idempotency lock: `checkout:{cartID}:cust:{customerID}:v{version}`
- Lock TTL is 15 min — order service has its own guard via `cart_session_id` unique constraint

### Payment authorized but order creation failed
- Check `failed_compensations` table for `void_authorization` entries
- Worker retries void up to 5 times with exponential backoff

### Outbox events stuck in "processing"
- Worker recovers stuck events every 10 processing cycles (>5 min threshold)
- Query: `SELECT * FROM outbox_events WHERE status = 'processing' AND updated_at < NOW() - INTERVAL '5 minutes'`

---

**Service Status**: 🟢 Production Ready
**Last Code Review**: 2026-02-24
**Critical Issues (P0)**: 0
**High Issues (P1)**: 0 (all fixed in v1.3.5)
**Build**: ✅ golangci-lint 0 warnings, go build passes (v1.3.6)
**Config/GitOps**: ✅ Aligned (ports 8010/9010)
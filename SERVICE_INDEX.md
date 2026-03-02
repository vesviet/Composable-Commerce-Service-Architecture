# 📦 Service Index

> **Last Updated**: 2026-03-02 (post P0/P1 audit fixes) | **Total**: 21 Go services + 2 frontends  
> **Stack**: Go 1.25 · Kratos v2 · PostgreSQL · Redis · Dapr · Kubernetes

---

## Service Catalog

| # | Service | Domain | HTTP | gRPC | Maturity | Worker | Outbox | Idempotency | DLQ |
|---|---------|--------|------|------|----------|--------|--------|-------------|-----|
| 1 | **Auth** | Identity & Access | 8000 | 9000 | 🟢 Production | ✅ | — | — | — |
| 2 | **User** | Identity & Access | 8001 | 9001 | 🟢 Production | ✅ | ✅ | ✅ | — |
| 3 | **Customer** | CRM & Analytics | 8003 | 9003 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 4 | **Catalog** | Product & Content | 8015 | 9015 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 5 | **Pricing** | Product & Content | 8002 | 9002 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 6 | **Promotion** | Product & Content | 8011 | 9011 | 🟡 Near-prod | ✅ | ✅ | ✅ | ✅ |
| 7 | **Checkout** | Commerce Flow | 8010 | 9010 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 8 | **Order** | Commerce Flow | 8004 | 9004 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 9 | **Payment** | Commerce Flow | 8005 | 9005 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 10 | **Warehouse** | Inventory | 8006 | 9006 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 11 | **Fulfillment** | Order Fulfillment | 8008 | 9008 | 🟡 Near-prod | ✅ | ✅ | ✅ | ✅ |
| 12 | **Shipping** | Logistics | 8012 | 9012 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 13 | **Return** | Post-Purchase | 8013 | 9013 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 14 | **Loyalty** | Post-Purchase | 8014 | 9014 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 15 | **Gateway** | Platform | 80 | — | 🟢 Production | ✅ | — | ✅ | ✅ |
| 16 | **Search** | Platform | 8017 | 9017 | 🟢 Production | ✅ | ✅ | ✅ | ✅ |
| 17 | **Analytics** | Platform | 8019 | 9019 | 🟡 Near-prod | ✅ | — | ✅ | ✅ |
| 18 | **Review** | Platform | 8016 | 9016 | 🟡 Near-prod | ✅ | ✅ | ✅ | — |
| 19 | **Common Ops** | Platform | 8018 | 9018 | 🟢 Production | ✅ | ✅ | ✅ | — |
| 20 | **Notification** | Operations | 8009 | 9009 | 🟡 Near-prod | ✅ | ✅ | ✅ | ✅ |
| 21 | **Location** | Operations | 8007 | 9007 | 🟢 Production | ✅ | ✅ | — | — |
| — | **Frontend** | UI (Next.js) | 3000 | — | — | — | — | — | — |
| — | **Admin** | UI (React) | 3001 | — | — | — | — | — | — |

**Legend**: 🟢 Production-ready · 🟡 Near-production · 🟠 Partial implementation · ✅ Implemented · — Not applicable

---

## Service Details by Domain

### 🛒 Commerce Flow
| Service | Purpose | Key Dependencies |
|---------|---------|-----------------|
| **Checkout** | Cart management, price revalidation, checkout orchestration | Order, Payment, Pricing, Promotion, Shipping |
| **Order** | Order lifecycle (8 states), cancellation, capture retry, cleanup jobs | Payment, Warehouse, Fulfillment, Shipping, Customer |
| **Payment** | Payment processing (Stripe, PayPal, VNPay, MoMo), fraud detection (GeoIP + VPN), refunds | External payment gateways, ip-api.com |

### 📦 Product & Content
| Service | Purpose | Key Dependencies |
|---------|---------|-----------------|
| **Catalog** | Product CRUD, EAV attributes, categories, brands, CMS pages | Elasticsearch (via Search) |
| **Pricing** | Dynamic pricing, tax calculation, multi-currency, price rules | Catalog |
| **Promotion** | Campaigns, coupons, BOGO, tiered discounts, order cancellation reversal | Order (event consumer) |

### 🚚 Logistics
| Service | Purpose | Key Dependencies |
|---------|---------|-----------------|
| **Warehouse** | Multi-warehouse inventory, reservations, stock movements, idempotent consumers | Order, Fulfillment (events) |
| **Fulfillment** | Picking → packing → shipping workflow | Warehouse, Catalog, Shipping |
| **Shipping** | Multi-carrier integration (GHN, Grab), webhook processing, JWT auth | External carrier APIs |

### 🔄 Post-Purchase
| Service | Purpose | Key Dependencies |
|---------|---------|-----------------|
| **Return** | Returns, exchanges, refund processing, restock coordination, outbox | Payment, Warehouse, Order, Shipping |
| **Loyalty** | Points, tiers, rewards, referrals, transactional outbox | Order, Customer |

### 🔐 Identity & Access
| Service | Purpose | Key Dependencies |
|---------|---------|-----------------|
| **Auth** | JWT (RS256), OAuth2 (Google/Facebook/GitHub), MFA (TOTP) | PostgreSQL, Redis |
| **User** | User profiles, RBAC, service access control | Auth |
| **Customer** | Customer profiles, addresses, segmentation, audit logging, LTV analytics | Order (events), Auth |

### ⚙️ Platform & Operations
| Service | Purpose | Key Dependencies |
|---------|---------|-----------------|
| **Gateway** | API routing, auth, rate limiting, circuit breaker, BFF | All services |
| **Search** | Full-text search, autocomplete, event-driven indexing, DLQ reprocessing | Elasticsearch, Catalog (events) |
| **Analytics** | Revenue, order, customer, fulfillment, shipping metrics (real event-based) | All services (events) |
| **Review** | Product reviews, ratings, content moderation | Catalog, Customer |
| **Common Ops** | Task orchestration, file operations, MinIO integration | MinIO |
| **Notification** | Email (SendGrid/SES), SMS (Twilio), push, in-app notifications | All services (events) |
| **Location** | Hierarchical location tree (Country → Ward), address validation | — |

---

## Infrastructure Dependencies

| Service | PostgreSQL | Redis | Elasticsearch | Dapr PubSub | External APIs |
|---------|-----------|-------|---------------|-------------|---------------|
| Auth | ✅ | ✅ | — | ✅ | — |
| User | ✅ | ✅ | — | ✅ | — |
| Customer | ✅ | ✅ | — | ✅ | — |
| Catalog | ✅ | ✅ | ✅ | ✅ | — |
| Pricing | ✅ | ✅ | — | ✅ | — |
| Promotion | ✅ | ✅ | — | ✅ | — |
| Checkout | ✅ | ✅ | — | ✅ | — |
| Order | ✅ | ✅ | — | ✅ | — |
| Payment | ✅ | ✅ | — | ✅ | Stripe, PayPal, VNPay, MoMo, ip-api |
| Warehouse | ✅ | ✅ | — | ✅ | — |
| Fulfillment | ✅ | ✅ | — | ✅ | — |
| Shipping | ✅ | ✅ | — | ✅ | GHN, Grab |
| Return | ✅ | ✅ | — | ✅ | — |
| Loyalty | ✅ | ✅ | — | ✅ | — |
| Gateway | — | ✅ | — | ✅ | — |
| Search | ✅ | ✅ | ✅ | ✅ | — |
| Analytics | ✅ | ✅ | — | ✅ | — |
| Review | ✅ | ✅ | — | ✅ | — |
| Common Ops | ✅ | ✅ | — | ✅ | MinIO |
| Notification | ✅ | ✅ | — | ✅ | SendGrid, Twilio |
| Location | ✅ | ✅ | — | ✅ | — |
| Frontend | — | — | — | — | Gateway |
| Admin | — | — | — | — | Gateway |

---

## Common Library (`common` v1.23.0)

Shared packages used across services (`gitlab.com/ta-microservices/common`):

| Package | Purpose | Status |
|---------|---------|--------|
| `common/outbox` | `Event`, `GormRepository`, `Worker` for transactional outbox | ✅ Adopted |
| `common/idempotency` | `GormIdempotencyHelper` for event deduplication | ✅ Adopted |
| `common/events` | Dapr publisher/consumer, entity event helpers, validator | ✅ All services |
| `common/client` | gRPC client factory, circuit breaker, service discovery | ✅ All services |
| `common/config` | Config loading (YAML + env vars), Viper integration | ✅ All services |
| `common/errors` | Error classifier, constructors, response types | ✅ All services |
| `common/middleware` | Auth, logging, recovery, tracing middleware | ✅ All services |
| `common/observability` | Health checks, Prometheus, OpenTelemetry | ✅ All services |
| `common/security` | JWT, RBAC, permission helpers | ✅ All services |
| `common/validation` | Request validation utilities | ✅ All services |
| `common/worker` | Base worker infrastructure for background tasks | ✅ All workers |
| `common/data` | Transaction context helpers | ✅ All services |
| `common/repository` | Base repository patterns | ✅ All services |
| `common/utils` | Common utilities (pagination, slugify, etc.) | ✅ All services |
| `common/models` | Shared domain models and DTOs | ✅ All services |
| `common/geoip` | GeoIP lookup utilities | Payment |
| `common/migrate` | Database migration runner | ✅ All services |
| `common/registry` | Service registry helpers | ✅ All services |
| `common/constants` | Shared event topic constants | ✅ All services |
| `common/grpc` | gRPC interceptors and helpers | ✅ All services |
| `common/proto` | Shared proto definitions | ✅ All services |

---

## Quick Reference

```bash
# Build any service
cd <service> && make build

# Run with hot reload
cd <service> && make run

# Run tests
cd <service> && make test

# Generate proto code
cd <service> && make api

# Health check
curl http://localhost:<HTTP_PORT>/health
```

---

*Maintainer: Platform Team · Source: [PORT_ALLOCATION_STANDARD.md](../gitops/docs/PORT_ALLOCATION_STANDARD.md)*

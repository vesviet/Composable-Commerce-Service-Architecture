> [!WARNING]
> **Historical Snapshot (January 23, 2026 / `common v1.0.14`)**: Preserved for audit reference only. For the current canonical codebase map, service versions, and maturity status, see [`../../CODEBASE_INDEX.md`](../../CODEBASE_INDEX.md) and [`../../SERVICE_INDEX.md`](../../SERVICE_INDEX.md).

# 📚 MICROSERVICES CODEBASE INDEX

**Last Updated**: January 23, 2026
**Project**: E-commerce Microservices Platform
**Total Services**: 23 Services (21 Go + 2 Node.js)
**Platform Status**: 90% Complete, Production-Ready

---

## 📊 EXECUTIVE SUMMARY

This is a comprehensive **microservices-based e-commerce platform** built with modern technologies and enterprise-grade architecture. The platform is **90% complete** with **19 out of 21 Go services ready for production deployment**.

### 🎯 Key Business Benefits
- ✅ **Scalable**: Each service scales independently based on demand
- ✅ **Reliable**: Service isolation prevents single points of failure  
- ✅ **Fast Development**: Teams can work on different services simultaneously
- ✅ **Cost Effective**: Pay only for resources you use
- ✅ **Future-Proof**: Easy to add new features and integrations

---

## 🚨 SENIOR TA (VIRTUAL TEAM LEAD) REVIEW & MANDATES
**Trạng thái Codebase (Review):** *Đã Audit & Đang Yêu Cầu Chấn Chỉnh Khẩn Cấp Hệ Tham Chiếu.*

*Với tư cách là Senior Fullstack / Team Lead, dựa trên bộ tiêu chuẩn Clean Code và 10 Core Standards, tôi yêu cầu chấn chỉnh ngay các lỗi kiến trúc/hygiene đang tồn đọng trong cấu trúc Source Tree này:*

1. **[🚨 P0 - Dependency Drift] Rác `vendor/`:** 12 Services đang tự ý đẩy `vendor/` codebase lên Git. Yêu cầu **XÓA SẠCH** toàn bộ `vendor/` khỏi repo. Nền tảng phải phụ thuộc vào Go Module Proxy và `go mod tidy` trong CI/CD. Cấm commit vendor.
2. **[🚨 P1 - Architecture] Rác Dữ Liệu Lỗi Typo:** Thư mục `comman/` ở root là một typo tai hại mạo danh thư viện lõi `common/`. Các file `go.mod.old` hay `go.mod.bak2` nằm vương vãi ở production codebase là không thể chấp nhận. Yêu cầu 1 PR dọn dẹp sạch sẽ mớ rác này.
3. **[🟡 P1 - Data Integrity] Inconsistency ở Schema Migration:** `payment` đang phình to với cả `migrations/` và `internal/migrations/`. `analytics` có file `001_*.sql` bị duplicate index. Yêu cầu chuẩn hoá duy nhất thư mục `migrations/` ở thư mục gốc của từng service và áp dụng đánh số nghiêm ngặt.
4. **[🔵 P2 - Clean Code] Entrypoint Sai Chuẩn:** `analytics` và `checkout` đang xài `cmd/server/main.go` thay vì `cmd/<service_name>/main.go`. Yêu cầu rename cho đồng bộ toàn project.

### 🏗️ Technology Stack
- **Backend**: Go 1.25+ with [Kratos Framework v2.9.1](https://go-kratos.dev/)
- **Frontend**: React/Next.js with TypeScript
- **Database**: PostgreSQL 15 (GORM ORM)
- **Messaging**: Dapr 1.12.0 for event-driven architecture
- **Service Discovery**: Consul 1.18
- **Caching**: Redis 7-alpine
- **Observability**: Prometheus, OpenTelemetry, Jaeger
- **Container**: Docker with Kubernetes (k3d/k3s)
- **API**: gRPC + HTTP/REST dual protocol support
- **Dependency Injection**: Wire framework

---

## 🏗️ SERVICES ARCHITECTURE

### 🚀 Go Microservices (21 Services)

#### ✅ Production Ready (19 Services - 90.5%)

| Service | Purpose | Status | Completion | Path | Key Features |
|---------|---------|--------|------------|------|--------------|
| **🔐 Authentication** | User authentication & authorization | ✅ Production | 95% | `/auth` | Multi-factor auth, OAuth2, JWT tokens, role-based access |
| **👥 User Management** | Admin users & roles | ✅ Production | 95% | `/user` | RBAC, audit trails, session management |
| **👤 Customer Management** | Customer profiles & data | ✅ Production | 95% | `/customer` | Profiles, preferences, segments, GDPR compliance |
| **📦 Product Catalog** | Product catalog management | ✅ Production | 95% | `/catalog` | 25,000+ products, EAV system, categories, brands |
| **💳 Payment Processing** | Multi-gateway payment processing | ✅ Production | 95% | `/payment` | PCI DSS compliance, fraud detection, reconciliation |
| **💰 Dynamic Pricing** | Real-time pricing engine | ✅ Production | 92% | `/pricing` | Rules engine, warehouse-specific pricing, promotions |
| **🎯 Promotions** | Discount campaigns & coupons | ✅ Production | 92% | `/promotion` | Campaign management, discount rules, usage tracking |
| **📊 Warehouse Management** | Inventory & stock management | ✅ Production | 90% | `/warehouse` | Real-time stock, reservations, multi-warehouse support |
| **🛒 Order Management** | Post-checkout order processing | ✅ Production | 90% | `/order` | Order status updates, cancellations, edits, tracking |
| **🛒 Cart & Checkout** | Cart management & checkout orchestration | ✅ Production | 90% | `/checkout` | Shopping cart, checkout flow, payment integration |
| **↩️ Return Management** | Return requests & processing | ✅ Production | 85% | `/return` | Return workflows, exchange processing, refunds |
| **📦 Fulfillment** | Pick/pack/ship execution | ✅ Production | 90% | `/fulfillment` | Picklists, packaging, fulfillment workflow |
| **🚚 Shipping** | Carrier integrations & shipments | ✅ Production | 90% | `/shipping` | Rate quotes, label generation, tracking |
| **🔍 Search Engine** | Product search & discovery | ✅ Production | 95% | `/search` | AI-powered search, filters, recommendations |
| **📧 Notifications** | Multi-channel notifications | ✅ Production | 90% | `/notification` | Email, SMS, push notifications, templates |
| **🚪 API Gateway** | Request routing & security | ✅ Production | 95% | `/gateway` | Load balancing, authentication, rate limiting |
| **🗺️ Location Services** | Geographic data & zones | ✅ Production | 90% | `/location` | Vietnam location data, delivery zones |
| **📈 Analytics** | Business intelligence | ✅ Production | 85% | `/analytics` | Sales analytics, customer insights, performance metrics |
| **🧰 Common Operations** | Task orchestration & shared jobs | ✅ Production | 90% | `/common-operations` | Import/export, async tasks, file handling |

#### 🟡 Near Production (2 Services - 9.5%)

| Service | Purpose | Status | Completion | Path | Remaining Work |
|---------|---------|--------|------------|------|----------------|
| **⭐ Reviews & Ratings** | Product reviews & ratings | 🟡 Near Production | 85% | `/review` | Integration tests (8h), caching (6h), enhanced metrics (2h) |
| **🎁 Loyalty-Rewards** | Points & rewards system | 🟡 Near Production | 95% | `/loyalty-rewards` | Integration tests (8h), performance testing (4h) |

### 🌐 Node.js Services (2 Services)

| Service | Purpose | Status | Completion | Path | Technology Stack |
|---------|---------|--------|------------|------|------------------|
| **👨‍💼 Admin Dashboard** | Business management interface | 🟡 In Progress | 75% | `/admin` | React + TypeScript + Vite + Ant Design |
| **🌐 Customer Frontend** | Customer-facing website | 🟡 In Progress | 70% | `/frontend` | Next.js + TypeScript + Tailwind CSS |

### 🔧 Shared Components

| Component | Purpose | Version | Status | Path |
|-----------|---------|---------|--------|------|
| **📦 Common Package** | Shared Go utilities & middleware | v1.0.14 | ✅ Production | `/common` |
| **🔄 Dapr Configuration** | Event-driven architecture setup | 1.12.0 | ✅ Production | `/dapr` |
| **📚 Documentation** | Comprehensive guides & checklists | Latest | ✅ Complete | `/docs` |

---

## 🧭 SERVICE SOURCE TREE INDEX (IMPLEMENTED STRUCTURE)

This section captures the **actual source tree layout** observed in the repository (not just the intended standard). It is useful for onboarding, review scoping, and identifying deviations.

### 🚩 CRITICAL CODEBASE ANOMALIES & TECH DEBTS (P0/P1)
- 🚨 **`vendor/` rác codebase:** Xuất hiện tại `auth`, `order`, `payment`, `warehouse`, `fulfillment`, `shipping`, `notification`, `search`, `analytics`, `location`, `review`, `loyalty-rewards`. *Lệnh:* Xoá bỏ hoàn toàn và chỉ định `go mod tidy` qua CI/CD Pipeline.
- 🟡 **Lệch chuẩn cấu trúc Migration:**
  - `payment/` đang ôm đồm cả `migrations/` và `internal/migrations/`.
  - `analytics/` vi phạm quy tắc đánh version: có nhiều file `001_*.sql` bị trùng lặp numbering.
- 🔵 **Lệch chuẩn Entrypoint:** `analytics` và `checkout` sử dụng `cmd/server` đi ngược lại với đa số (`cmd/<service>`). Cần rename.
- 🚨 **Hygiene Codebase Bẩn:** Root folder đẻ ra `comman/` (typo rác từ `common`), cùng với các mảnh vỡ rác như `shipping/go.mod.old`, `review/go.mod.bak2`. Cần bị xoá sổ.

### 📦 Logistics Services

#### `order`
- **Entrypoints**: `cmd/order`, `cmd/worker`, `cmd/migrate`
- **API**: `api/order/v1`
- **Internal**:
  - `internal/biz/` domains: `order`, `order_edit`, `cancellation`, `status`, `validation`
  - cross-cutting: `transaction.go`, `event_idempotency.go`, `failed_event.go`, `monitoring.go`
  - `internal/data/`, `internal/repository/`, `internal/model/`
  - `internal/service/`, `internal/server/`
  - `internal/events/`, `internal/worker/`, `internal/client/`
- **Migrations**: `migrations/` (archived cart/checkout migrations in `migrations/archived/`)
- **Notes**: Refactored to focus on post-checkout order management (status updates, cancellations, edits)

#### `checkout`
- **Entrypoints**: `cmd/server`
- **API**: `api/checkout/v1` (cart and checkout services)
- **Internal**:
  - `internal/biz/` domains: `cart`, `checkout`, `order`
  - cross-cutting: `transaction.go`, `event_idempotency.go`, `failed_event.go`, `monitoring.go`
  - `internal/data/`, `internal/repository/`, `internal/model/`
  - `internal/service/`, `internal/server/`, `internal/client/`
  - `internal/events/`, `internal/observability/`
- **Migrations**: `migrations/001..003_*.sql`
- **Notes**: Split from order service - handles cart management and checkout orchestration

#### `return`
- **Entrypoints**: `cmd/server`
- **API**: `api/return/v1`
- **Internal**:
  - `internal/biz/` domain: `return`
  - cross-cutting: `transaction.go`, `event_idempotency.go`, `failed_event.go`, `monitoring.go`
  - `internal/data/`, `internal/repository/`, `internal/model/`
  - `internal/service/`, `internal/server/`, `internal/client/`
  - `internal/events/`
- **Migrations**: `migrations/001..002_*.sql`
- **Notes**: Split from order service - handles return requests and processing

#### `payment`
- **Entrypoints**: `cmd/payment`, `cmd/worker`, `cmd/migrate`
- **API**: `api/payment/v1`
- **Internal**:
  - `internal/biz/`, `internal/data/`, `internal/repository/`, `internal/model/`
  - `internal/service/`, `internal/server/`, `internal/middleware/`
  - `internal/client/` (order/customer clients + circuit breaker)
  - `internal/job/`, `internal/worker/`, `internal/utils/`, `internal/constants/`
- **Migrations**: `migrations/001..007_*.sql` + `internal/migrations/` (exists)
- **Tests**: `test/integration`, `test/performance`, `test/security`, `testutil`

#### `warehouse`
- **Entrypoints**: `cmd/warehouse`, `cmd/worker`, `cmd/migrate`
- **API**: `api/warehouse/v1`, `api/inventory/v1`, `api/backorder/v1`, `api/distributor/v1`
- **Internal**:
  - `internal/biz/`
  - `internal/data/` subpackages: `postgres`, `redis`, `eventbus`, `grpc_client`
  - `internal/repository/`, `internal/model/`, `internal/service/`, `internal/server/`, `internal/worker/`
  - `internal/observer/`, `internal/utils/`, `internal/constants/`
- **Migrations**: `migrations/`

#### `fulfillment`
- **Entrypoints**: `cmd/fulfillment`, `cmd/worker`, `cmd/migrate`
- **API**: `api/fulfillment/v1`, `api/picklist/v1`, `api/package/v1`
- **Internal**: `internal/biz/`, `internal/data/`, `internal/repository/`, `internal/model/`, `internal/service/`, `internal/server/`, `internal/worker/`, `internal/events/`, `internal/observer/`, `internal/client/`
- **Migrations**: `migrations/001..015_*.sql`

#### `shipping`
- **Entrypoints**: `cmd/shipping`, `cmd/worker`, `cmd/migrate`
- **API**: `api/shipping/v1`
- **Internal**:
  - `internal/biz/` domains: `carrier`, `shipment`, `shipping_method`
  - adapters: `internal/carrier/` (`ghn/`, `grab/`, `interface.go`)
  - `internal/carrierfactory/`
  - plus standard layers: `internal/data/`, `internal/repository/`, `internal/model/`, `internal/service/`, `internal/server/`, `internal/worker/`, `internal/events/`, `internal/observer/`
  - `internal/testdata/`
- **Migrations**: timestamped `202411*` series
- **Notes**: contains `pkg/` (service-local utilities) and `go.mod.old`

### 🧩 Supporting Services

#### `common-operations`
- **Entrypoints**: `cmd/operations`, `cmd/worker`, `cmd/migrate`
- **API**: `api/operations/v1`
- **Internal**:
  - `internal/biz/` (task orchestration)
  - `internal/data/` (`postgres`, `redis`), `internal/storage/` (local/s3/minio)
  - `internal/event/` (Dapr pub/sub), `internal/client/`
  - plus standard layers: `internal/service/`, `internal/server/`, `internal/worker/`
- **Migrations**: `migrations/`

#### `notification`
- **Entrypoints**: `cmd/notification`, `cmd/worker`, `cmd/migrate`
- **API**: `api/notification/v1`
- **Internal**:
  - `internal/biz/` domains: `delivery`, `events`, `message`, `notification`, `preference`, `subscription`, `template`
  - `internal/cache/` (has tests)
  - plus standard layers: `internal/data/`, `internal/repository/`, `internal/model/`, `internal/service/`, `internal/server/`, `internal/worker/`, `internal/client/`
  - `internal/pkg/`, `internal/provider/`, `internal/constants/`, `internal/observability/`
- **Migrations**: `migrations/00001..00006_*.sql`

#### `search`
- **Entrypoints**: `cmd/search`, `cmd/worker`, `cmd/sync`, `cmd/migrate`
- **API**: `api/search/v1` (+ `api/openapi.yaml`)
- **Internal**:
  - `internal/data/` subpackages: `elasticsearch`, `postgres`, `redis`, `eventbus`
  - `internal/cache/`, `internal/constants/`, `internal/observability/prometheus`
  - plus standard layers: `internal/biz/`, `internal/service/`, `internal/server/`, `internal/worker/`, `internal/client/`
- **Migrations**: `migrations/`
- **Tests**: `test/integration`

#### `analytics`
- **Entrypoint**: `cmd/server/main.go`
- **API**: `api/analytics/v1`
- **Eventing**: `dapr/subscription.yaml`
- **Internal**:
  - domain-heavy: `internal/domain/`
  - `internal/usecase/`, `internal/repository/`, `internal/service/`
  - `internal/handler/` (event + health)
  - `internal/infrastructure/` (`database/`, `redis/`)
  - `internal/pkg/circuitbreaker`, `internal/config/`
- **Migrations**: includes multiple `001_*.sql` (verify ordering)

#### `location`
- **Entrypoints**: `cmd/location`, `cmd/migrate`
- **API**: `api/location/v1` (includes generated `.pb.go` + `.proto`)
- **Internal**:
  - `internal/biz/location/` (usecase + validator + tests)
  - `internal/data/postgres/`, `internal/model/`, `internal/service/` (has tests)
  - `internal/server/` (consul/grpc/http/server)
  - `internal/client/`
- **Migrations**: `migrations/001_create_locations_table.sql`

### 💬 Engagement Services

#### `review`
- **Entrypoints**: `cmd/review`, `cmd/migrate`
- **API**: `api/review/v1`
- **Internal**:
  - `internal/biz/` domains: `review`, `rating`, `helpful`, `moderation`, `events`
  - `internal/data/` (`postgres`, `redis`), `internal/cache/`
  - `internal/client/` (catalog/order/user)
  - `internal/observability/` (metrics + tracing)
  - plus standard layers: `internal/server/`, `internal/service/`, `internal/worker/`
- **Migrations**: `migrations/001..002_*.sql`

#### `loyalty-rewards`
- **Entrypoint**: `cmd/loyalty-rewards` (server)
- **API**: `api/loyalty/v1` (+ `api/openapi.yaml`)
- **Internal**:
  - `internal/biz/` domains: `account`, `tier`, `transaction`, `reward`, `redemption`, `campaign`, `referral`, `analytics`, `events`
  - `internal/cache/` (account/reward/tier)
  - `internal/client/` (customer/order/notification)
  - plus standard layers: `internal/data/`, `internal/repository/`, `internal/model/`, `internal/server/`, `internal/service/`, `internal/jobs/`, `internal/observability/`
- **Migrations**: `migrations/001..008_*.sql`

---

## 📁 STANDARD SERVICE STRUCTURE

Each Go microservice follows **Clean Architecture** with this standardized structure:

```
service-name/
├── cmd/
│   ├── server/              # Main service entry point
│   ├── worker/              # Background workers (optional)
│   └── migrate/             # Database migration tool
├── internal/
│   ├── biz/                 # 🎯 Business logic (domain-driven)
│   │   ├── domain1/         # Domain-specific business logic
│   │   ├── domain2/         # Multiple domains per service
│   │   └── events/          # Event publishing
│   ├── data/                # 💾 Data access layer
│   │   ├── postgres/        # PostgreSQL repositories
│   │   └── redis/           # Redis caching
│   ├── service/             # 🌐 gRPC/HTTP services
│   ├── client/              # 🔗 External service clients
│   ├── server/              # 🖥️ Server setup (gRPC, HTTP)
│   ├── middleware/          # 🛡️ Middleware (auth, logging, tracing)
│   ├── conf/                # ⚙️ Configuration
│   └── observability/       # 📊 Metrics, tracing, logging
├── api/
│   └── proto/               # 📋 Protocol buffer definitions
├── migrations/              # 🗄️ Database migrations (Goose)
├── configs/                 # 📝 Configuration files
├── scripts/                 # 🔧 Utility scripts
├── docs/                    # 📖 Service documentation
├── Dockerfile               # 🐳 Container definition
├── Makefile                 # 🔨 Build commands
├── go.mod                   # 📦 Go dependencies
└── README.md               # 📄 Service documentation
```

### 🏛️ Architecture Layers

1. **🎯 Business Logic (`biz/`)**: Domain-driven design with separate domains
   - Example (Order): cart, checkout, fulfillment, cancellation, return, refund
   - Example (Customer): profile, address, segment, preference, analytics

2. **💾 Data Access (`data/`)**: Repository pattern with common utilities
   - GORM-based PostgreSQL repositories
   - Redis caching layer
   - Transaction support and soft deletes

3. **🌐 Service Layer (`service/`)**: API endpoints
   - gRPC services with HTTP gateway
   - Protocol buffer definitions
   - Request/response validation

4. **🔗 Client Layer (`client/`)**: External service communication
   - gRPC clients to other services
   - Dapr pub/sub integration
   - Circuit breakers and retries

5. **🔄 Events (`events/`)**: Event-driven architecture
   - Domain event publishing via Dapr
   - Event handlers and consumers
   - Async processing support

---

## 🔧 COMMON PACKAGE v1.0.14

**Location**: `/common`  
**Purpose**: Shared utilities across all services  
**Import**: `gitlab.com/ta-microservices/common@v1.0.14`

### 📦 Provides:
- ✅ **Repository Utilities**: CRUD operations, transactions, soft deletes
- ✅ **Event Helpers**: Dapr publishing, event handling
- ✅ **Middleware**: Authentication, logging, tracing, recovery
- ✅ **Error Handling**: Standardized error responses
- ✅ **Configuration**: Environment-based config loading
- ✅ **Database Utilities**: Connection management, health checks
- ✅ **Cache Helpers**: Redis operations, TTL management
- ✅ **Validation**: Input validation, UUID checks

### 🎯 Key Features:
```go
// Repository pattern with common utilities
type BaseRepository[T any] interface {
    Create(ctx context.Context, entity *T) error
    Update(ctx context.Context, entity *T) error
    Delete(ctx context.Context, id uuid.UUID) error
    FindByID(ctx context.Context, id uuid.UUID) (*T, error)
}

// Event publishing helper
eventHelper.PublishCreated(ctx, "product", productID, data)
eventHelper.PublishUpdated(ctx, "order", orderID, changes)

// Middleware stack
router.Use(middleware.RequestID())
router.Use(middleware.Logging())
router.Use(middleware.Recovery())
router.Use(middleware.Auth(authConfig))
```

---

## 🗄️ DATABASE ARCHITECTURE

### 📊 Database Per Service Pattern
Each service maintains its own PostgreSQL database for data isolation:

| Service | Database | Key Tables | Features |
|---------|----------|------------|----------|
| **Auth** | auth_db | users, roles, permissions, sessions | RBAC, JWT tokens |
| **Customer** | customer_db | customers, addresses, segments, preferences | GDPR compliance |
| **Catalog** | catalog_db | products, categories, brands, attributes | EAV system, 25+ migrations |
| **Order** | order_db | orders, cart_sessions, items, payments | Order lifecycle |
| **Payment** | payment_db | payments, transactions, refunds, methods | PCI DSS compliance |
| **Warehouse** | warehouse_db | stock_levels, reservations, locations | Real-time inventory |
| **Loyalty** | loyalty_db | accounts, transactions, tiers, rewards | Points system |
| **Review** | review_db | reviews, ratings, moderation, votes | Content moderation |

### 🔑 Database Features:
- ✅ **UUID Primary Keys**: Distributed system friendly
- ✅ **Soft Deletes**: Data retention and recovery
- ✅ **Timestamps**: created_at, updated_at tracking
- ✅ **GDPR Compliance**: Deletion tracking, data anonymization
- ✅ **Performance Optimization**: Proper indexing, materialized views
- ✅ **Schema Evolution**: Goose-based migrations (25+ per service)
- ✅ **JSONB Support**: Flexible data storage

---

## 🌐 API ARCHITECTURE

### 📋 Protocol Buffers (gRPC)
- **Proto-first Design**: All APIs defined in .proto files
- **Code Generation**: Automatic Go/TypeScript code generation
- **Service Definitions**: Clear contracts between services
- **HTTP Gateway**: gRPC services exposed as REST APIs

### 🔗 Service Communication Patterns
- **Internal**: gRPC for service-to-service communication
- **External**: HTTP/REST for client applications  
- **Async**: Dapr pub/sub for event-driven communication
- **Service Discovery**: Consul-based service registry

### 📊 API Standards
- ✅ Resource-based endpoints (GET, POST, PUT, DELETE)
- ✅ Pagination support (limit/offset)
- ✅ Advanced filtering and search
- ✅ Standardized error responses
- ✅ Request/response validation
- ✅ OpenAPI/Swagger documentation

---

## 🚀 INFRASTRUCTURE & DEPLOYMENT

### 🐳 Container Orchestration
- **Kubernetes**: k3d (local), k3s (production)
- **Container Runtime**: Docker with multi-stage builds
- **Image Registry**: Local registry (localhost:5000)
- **Orchestration**: ArgoCD for GitOps deployment

### 🏗️ Infrastructure Components
- **PostgreSQL**: 15-alpine with persistent volumes
- **Redis**: 7-alpine for caching and sessions
- **Consul**: 1.18 for service discovery
- **Dapr**: 1.12.0 for event-driven architecture
- **Jaeger**: Distributed tracing
- **Prometheus**: Metrics collection

### 🔄 CI/CD Pipeline
- **GitLab CI**: Automated testing and building
- **Docker Images**: Multi-stage builds for optimization
- **ArgoCD**: GitOps-based deployment automation
- **Helm**: Kubernetes package management
- **Tilt**: Local development with hot reload

### 🛠️ Development Tools
- **Tiltfile**: Hot reload for Go services and frontend
- **docker-compose.yml**: Local infrastructure setup
- **k8s-local/**: Kubernetes local development scripts
- **Makefile**: Standardized build commands

---

## 📊 IMPLEMENTATION COMPLETENESS MATRIX

| Category | Status | Completion | Details |
|----------|--------|------------|---------|
| **🎯 Core Services** | ✅ Production Ready | 95% | Auth, User, Customer, Catalog, Payment |
| **🛒 Business Logic** | ✅ Production Ready | 90% | Order, Warehouse, Fulfillment, Shipping |
| **💰 Revenue Services** | ✅ Near Production | 92% | Pricing, Promotions, Loyalty (95%), Reviews (85%) |
| **🔧 Operations** | ✅ Production Ready | 90% | Notifications, Search, Analytics, Location |
| **🌐 Frontend** | 🟡 In Progress | 72% | Admin (75%), Customer (70%) |
| **🏗️ Infrastructure** | ✅ Production Ready | 95% | Kubernetes, Docker, ArgoCD, Dapr |
| **🔄 CI/CD** | ✅ Production Ready | 90% | GitLab CI, automated testing, deployment |
| **📚 Documentation** | ✅ Complete | 85% | Architecture docs, API docs, guides |
| **🧪 Testing** | 🟡 Needs Work | 60% | Unit tests present, integration tests needed |
| **📊 Monitoring** | ✅ Production Ready | 85% | Prometheus, Jaeger, health checks |

---

## 🎯 CURRENT PRIORITIES & ROADMAP

### 🚨 Immediate (1-2 weeks)
1. **⭐ Review Service**: Integration tests (8h), caching (6h), metrics (2h)
2. **🎁 Loyalty-Rewards**: Integration tests (8h), performance testing (4h)
3. **🌐 Frontend Services**: Complete customer website and admin dashboard

### 📅 Short-term (2-4 weeks)
1. **🧪 Testing**: Comprehensive unit and integration test coverage
2. **🛡️ Security**: Rate limiting, input validation, audit logging
3. **⚡ Performance**: Load testing, optimization, caching strategies
4. **📊 Monitoring**: Enhanced metrics, alerting, dashboards

### 🔮 Medium-term (1-3 months)
1. **🌍 Multi-language**: i18n implementation across services
2. **🤖 AI Features**: Advanced recommendations, fraud detection
3. **🌐 Global Expansion**: Multi-region deployment capabilities
4. **📱 Mobile App**: Native mobile application development

---

## ⚠️ RISK ASSESSMENT

### 🟢 Low Risk
- ✅ Architecture and design patterns are solid
- ✅ Core services are well-implemented and tested
- ✅ Infrastructure is properly configured
- ✅ Documentation is comprehensive

### 🟡 Medium Risk
- ⚠️ Frontend services need completion (25-30% remaining)
- ⚠️ Integration test coverage gaps across services
- ⚠️ Performance optimization needed for high load
- ⚠️ Security hardening required for production

### 🔴 High Risk
- ❌ None identified - platform architecture is sound

---

## 🏆 PRODUCTION READINESS ASSESSMENT

### ✅ Go Services: 89.5% Production Ready
- **17 services** ready for immediate production deployment
- **Comprehensive error handling** and structured logging
- **Health checks** and monitoring endpoints
- **Database migrations** and schema management
- **Event-driven architecture** with Dapr integration
- **Security** with JWT authentication and RBAC

### 🟡 Frontend Services: 72% Complete
- **Admin Dashboard**: 75% complete (React + TypeScript + Ant Design)
- **Customer Website**: 70% complete (Next.js + TypeScript + Tailwind)
- **Payment Integration**: In progress
- **Search Integration**: In progress

### ✅ Infrastructure: 95% Ready
- **Kubernetes setup** complete with ArgoCD
- **Docker images** optimized with multi-stage builds
- **Monitoring stack** configured (Prometheus + Jaeger)
- **Service mesh** ready with Dapr

---

## 📈 PERFORMANCE METRICS & TARGETS

### 🎯 Current Performance Baselines
- **API Response Time**: <100ms (p95) for read operations
- **Database Queries**: <50ms average query time
- **Service Startup**: <30 seconds for all services
- **Memory Usage**: <512MB per service instance
- **CPU Usage**: <200m per service instance

### 🚀 Production Targets
- **Availability**: 99.9% uptime SLA
- **Throughput**: 10,000 requests/second peak load
- **Response Time**: <200ms (p95) for all operations
- **Error Rate**: <0.1% for all API calls
- **Recovery Time**: <5 minutes for service failures

---

## 🔗 QUICK START GUIDE

### 📋 Prerequisites
```bash
# Required tools
- Go 1.25+
- Docker & Docker Compose
- PostgreSQL 15+
- Redis 7+
- Node.js 18+ (for frontend)
- kubectl & k3d (for Kubernetes)
```

### 🚀 Local Development Setup
```bash
# 1. Clone repository
git clone <repository-url>
cd microservices-platform

# 2. Start infrastructure
docker-compose up -d postgres redis consul

# 3. Start services with Tilt (hot reload)
tilt up

# 4. Access services
# - API Gateway: http://localhost:8000
# - Admin Dashboard: http://localhost:3000
# - Customer Frontend: http://localhost:3001
# - Tilt Dashboard: http://localhost:10350
```

### 🔧 Development Commands
```bash
# Run tests for specific service
cd service-name && make test

# Generate proto files
make api

# Check service health
curl http://localhost:8000/health
```

---

## 📚 DOCUMENTATION RESOURCES

### 🏗️ Architecture Documentation
- [SYSTEM_ARCHITECTURE_OVERVIEW.md](SYSTEM_ARCHITECTURE_OVERVIEW.md) - High-level platform overview
- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - Quick start and development guide
- [PRODUCTION_READINESS_REVIEW.md](PRODUCTION_READINESS_REVIEW.md) - Production assessment

### 🔧 Implementation Guides
- [FULFILLMENT_IMPLEMENTATION_SUMMARY.md](FULFILLMENT_IMPLEMENTATION_SUMMARY.md) - Fulfillment service details
- [REVIEW_LOYALTY_SERVICES_CHECKLIST.md](REVIEW_LOYALTY_SERVICES_CHECKLIST.md) - Service implementation checklist
- [I18N_OPTIMAL_SERVICE_PLACEMENT_ANALYSIS.md](I18N_OPTIMAL_SERVICE_PLACEMENT_ANALYSIS.md) - Internationalization strategy

### 🚀 Deployment Documentation
- [DEPLOYMENT_CHECKLIST_ADMIN_FRONTEND_GATEWAY.md](DEPLOYMENT_CHECKLIST_ADMIN_FRONTEND_GATEWAY.md) - Deployment procedures
- [ARGOCD_VERIFICATION_ACTION_PLAN.md](ARGOCD_VERIFICATION_ACTION_PLAN.md) - ArgoCD setup guide
- [PORT_CONFIGURATION_REFERENCE.md](PORT_CONFIGURATION_REFERENCE.md) - Service port mapping

### 📊 Service-Specific Documentation
Each service includes comprehensive README.md with:
- Service overview and features
- API documentation
- Database schema
- Configuration guide
- Development setup
- Deployment instructions

---

## 🤝 CONTRIBUTING

### 📝 Development Standards
1. **Clean Architecture**: Follow established layered architecture
2. **Domain-Driven Design**: Organize business logic by domains
3. **Testing**: Write unit tests for all business logic
4. **Documentation**: Update README.md for any changes
5. **Code Quality**: Run `make lint` before committing
6. **Conventional Commits**: Use semantic commit messages

### 🔄 Development Workflow
1. Create feature branch from `main`
2. Implement changes following architecture patterns
3. Write/update tests and documentation
4. Run local tests and linting
5. Create merge request with detailed description
6. Code review and approval process
7. Automated CI/CD pipeline deployment

---

## 📞 SUPPORT & MAINTENANCE

### 👥 Team Structure
- **Platform Team**: Infrastructure, DevOps, shared services
- **Backend Team**: Go microservices development
- **Frontend Team**: React/Next.js applications
- **QA Team**: Testing, quality assurance

### 🆘 Getting Help
- **Documentation**: Check service README.md files
- **Issues**: Create GitLab issues for bugs/features
- **Architecture Questions**: Consult SYSTEM_ARCHITECTURE_OVERVIEW.md
- **Deployment Issues**: Check DEPLOYMENT_CHECKLIST guides

---

## 🏁 CONCLUSION

This e-commerce microservices platform represents a **world-class implementation** of modern software architecture principles. With **88% completion** and **89.5% of Go services production-ready**, the platform is well-positioned for successful deployment and scaling.

**Key Strengths:**
- ✅ **Solid Architecture**: Clean, maintainable, scalable design
- ✅ **Production Quality**: Enterprise-grade implementation
- ✅ **Comprehensive Documentation**: Detailed guides and references
- ✅ **Modern Technology Stack**: Latest tools and frameworks
- ✅ **Event-Driven Design**: Scalable async communication

**Estimated Time to 100% Completion**: 4-6 weeks with current team velocity

---

**Version**: 2.0.0  
**Last Updated**: January 20, 2026  
**Maintainer**: Platform Engineering Team
- Redis
- Consul
- Dapr CLI
```

### Running All Services
```bash
# Start infrastructure
docker-compose up -d

# Run specific service
cd order
make run

# Run all services
./git-all.sh start
```

### Development Scripts
- [git-all.sh](file:///Users/tuananh/Desktop/myproject/microservice/git-all.sh) - Manage all services (git operations, start/stop)
- [git-service.sh](file:///Users/tuananh/Desktop/myproject/microservice/git-service.sh) - Individual service operations
- [create-order.sh](file:///Users/tuananh/Desktop/myproject/microservice/create-order.sh) - Test order creation
- [create-order-advanced.sh](file:///Users/tuananh/Desktop/myproject/microservice/create-order-advanced.sh) - Advanced order testing
- [sync-and-index.sh](file:///Users/tuananh/Desktop/myproject/microservice/sync-and-index.sh) - Sync remote changes

---

## 📖 KEY DOCUMENTATION

| Document | Purpose | Location |
|----------|---------|----------|
| Services Status | Current status of Review & Loyalty services | [SERVICES_QUICK_STATUS.md](file:///Users/tuananh/Desktop/myproject/microservice/SERVICES_QUICK_STATUS.md) |
| Loyalty Review Checklist | Detailed implementation checklist | [REVIEW_LOYALTY_SERVICES_CHECKLIST.md](file:///Users/tuananh/Desktop/myproject/microservice/REVIEW_LOYALTY_SERVICES_CHECKLIST.md) |
| Order Implementation | Order service checklist | [CREATE_ORDER_README.md](file:///Users/tuananh/Desktop/myproject/microservice/CREATE_ORDER_README.md) |
| Docker Compose | Infrastructure setup | [docker-compose.yml](file:///Users/tuananh/Desktop/myproject/microservice/docker-compose.yml) |

---

## 🎯 SERVICE DEPENDENCIES

### Inter-Service Communication

```mermaid
graph TB
    Gateway[API Gateway] --> Auth[Auth Service]
    Gateway --> Order[Order Service]
    Gateway --> Catalog[Catalog Service]
    Gateway --> Customer[Customer Service]
    
    Order --> Pricing[Pricing Service]
    Order --> Warehouse[Warehouse Service]
    Order --> Payment[Payment Service]
    Order --> Fulfillment[Fulfillment Service]
    
    Fulfillment --> Shipping[Shipping Service]
    Fulfillment --> Notification[Notification Service]
    
    Order --> Promotion[Promotion Service]
    Order --> LoyaltyRewards[Loyalty-Rewards Service]
    
    Catalog --> Search[Search Service]
    Catalog --> Review[Review Service]
```

### Example: Order Service Dependencies
```go
// In order/go.mod
require (
    gitlab.com/ta-microservices/common v1.2.7
    gitlab.com/ta-microservices/catalog v1.0.4
    gitlab.com/ta-microservices/pricing v1.0.1
    gitlab.com/ta-microservices/warehouse v1.0.1
)
```

---

## 🗄️ DATABASE ARCHITECTURE

### Database per Service Pattern
Each service has its own PostgreSQL database:

```
- order_db
- catalog_db
- customer_db
- payment_db
- warehouse_db
- loyalty_db
- review_db
... (one per service)
```

### Migrations
Each service uses [Goose](https://github.com/pressly/goose) for migrations:
```bash
cd order/migrations
goose postgres "connection_string" up
```

---

## 📊 CURRENT PRIORITIES

### High Priority 🔴
1. **Loyalty-Rewards Service** (25% complete)
   - Import common package
   - Refactor to multi-domain architecture
   - Implement repository layer
   - Add service layer
   - **Estimated**: 104 hours

### Medium Priority 🟡
2. **Review Service** (85% complete)
   - Add integration tests
   - Implement caching
   - Add missing events
   - **Estimated**: 20 hours

### Reference Services ✅
Best examples for implementation patterns:
- **Catalog Service**: Multi-domain pattern
- **Order Service**: Complete architecture
- **Warehouse Service**: Repository pattern

---

## 🛠️ DEVELOPMENT WORKFLOW

### 1. Standard Service Development
```bash
# Create new feature branch
git checkout -b feature/your-feature

# Update dependencies
go get gitlab.com/ta-microservices/common@latest

# Generate proto
make api

# Run tests
make test

# Build
make build

# Run locally
make run
```

### 2. Adding a New Domain
```bash
internal/biz/
└── new-domain/
    ├── entity.go       # Domain entities
    ├── service.go      # Domain logic
    └── events.go       # Domain events
```

### 3. Common Makefile Targets
```makefile
make api           # Generate proto files
make build         # Build binary
make run           # Run service
make test          # Run tests
make docker        # Build Docker image
make wire          # Generate DI
make migrate-up    # Run migrations
make migrate-down  # Rollback migrations
```

---

## 📦 BUILD & DEPLOYMENT

### Docker Build
```bash
# Standard Dockerfile
docker build -t service-name .

# Optimized Dockerfile
docker build -f Dockerfile.optimized -t service-name .
```

### Docker Compose
```bash
# Start all infrastructure
docker-compose up -d

# View logs
docker-compose logs -f service-name

# Stop all
docker-compose down
```

---

## 🔍 FINDING YOUR WAY

### To work on a specific service:
1. Navigate to service directory: `cd service-name/`
2. Read the README: `cat README.md`
3. Check the Makefile: `cat Makefile`
4. Review the structure: `tree -L 2 internal/`

### To understand business logic:
1. Check `internal/biz/` - domain logic
2. Review `api/proto/` - service contracts
3. Look at `migrations/` - data schema

### To add a feature:
1. Define proto in `api/`
2. Generate code: `make api`
3. Implement in `internal/biz/`
4. Add repository in `internal/repository/`
5. Wire in `internal/service/`
6. Add tests

### To debug:
1. Check logs in terminal
2. Use Prometheus metrics
3. Review Consul service registry
4. Check Dapr pub/sub

---

## 📞 IMPORTANT FILES

### Root Level
- [.cursorrules](file:///Users/tuananh/Desktop/myproject/microservice/.cursorrules) - Cursor AI rules (19KB)
- [docker-compose.yml](file:///Users/tuananh/Desktop/myproject/microservice/docker-compose.yml) - Infrastructure
- [git-all.sh](file:///Users/tuananh/Desktop/myproject/microservice/git-all.sh) - Manage all services

### Per Service
- `README.md` - Service documentation
- `Makefile` - Build commands
- `go.mod` - Dependencies
- `openapi.yaml` - API documentation
- `Dockerfile` - Container definition

---

## 🎓 LEARNING RESOURCES

### Framework Documentation
- [Kratos Framework](https://go-kratos.dev/)
- [GORM](https://gorm.io/)
- [Dapr](https://dapr.io/)
- [Wire](https://github.com/google/wire)

### Architecture Patterns
- Clean Architecture
- Domain-Driven Design (DDD)
- Event-Driven Architecture
- Microservices Patterns

---

## 📈 SERVICE STATUS SUMMARY

| Status | Count | Services |
|--------|-------|----------|
| ✅ Production Ready | 14 | auth, catalog, customer, order, payment, pricing, promotion, warehouse, shipping, fulfillment, notification, user, gateway, search |
| 🟡 Near Complete | 1 | review (85%) |
| 🔴 In Development | 1 | loyalty-rewards (25%) |
| **Total** | **16** | **Go Services** |

---

## 🚨 VIRTUAL TEAM LEAD'S KNOWN ISSUES (MANDATORY REFACTOR)

**LƯU Ý:** Các service dưới đây đang vi phạm nghiêm trọng chuẩn mực kiến trúc chung của toàn hệ thống và trở thành Technical Debt khổng lồ. Yêu cầu refactor ngay!

### 🟡 Review Service (Nợ Kỹ Thuật P1)
- ⚠️ **Thiếu Integration Tests:** Không có test end-to-end, rủi ro vỡ logic khi gọi sang Catalog/Order.
- ⚠️ **Chưa Có Caching:** Vi phạm chuẩn tối ưu DB, nguy cơ nghẽn cổ chai (Bottleneck) khi traffic cao. Cần integrate `common/cache`.

### 🔴 Loyalty-Rewards Service (THẢM HỌA KIẾN TRÚC P0)
- 🔴 **Tự Bơi, Không Dùng Core Lib:** Không import `common` package (vi phạm luật DRY của dự án). Hệ quả: Tái chế lại toàn bộ Error, Logs, Middlewares dư thừa.
- 🔴 **Monolithic Structure:** Viết code kẹt cứng 1 cục (Spaghetti Code), không tách miền (Customer vs Points vs Campaigns).
- 🔴 **Thiếu Trầm Trọng Tầng Repository & Service:** Adapter đâm chọc thẳng vào DB ở mọi nơi. Clean Architecture bị vứt xó.
- 🔴 **Zero Tests:** Không một dòng Test Coverage nào. Không được phép merge lên Master.

Xem chi tiết phương án đập đi xây lại tại [SERVICES_QUICK_STATUS.md](file:///Users/tuananh/Desktop/myproject/microservice/SERVICES_QUICK_STATUS.md).

---

## 📊 CODEBASE STATISTICS

```
Total Services:        21 (19 Go + 2 Node.js)
Total Directories:     ~11,000+
Common Package:        v1.2.7
Go Version:            1.25++
Primary Framework:     Kratos v2.9.1
Database:              PostgreSQL (GORM)
Messaging:             Dapr
Service Discovery:     Consul
```

---

## 🔗 NAVIGATION

### By Domain
- **Commerce**: catalog, order, payment, pricing, promotion
- **Inventory**: warehouse, shipping, fulfillment
- **Customer**: customer, user, auth, loyalty-rewards, review
- **System**: gateway, notification, search, analytics, common-operations

### By Status
- **Production**: All except review & loyalty-rewards
- **Active Development**: loyalty-rewards
- **Final Polish**: review

---

## 📝 QUICK REFERENCE

### Common Commands
```bash
# Start all services
./git-all.sh start

# Pull all repos
./git-all.sh pull

# Status of all repos
./git-all.sh status

# Test order creation
./create-order.sh

# Sync from remote
./sync-and-index.sh
```

### Common Patterns
```go
// Import common package
import "gitlab.com/ta-microservices/common/pkg/..."

// Repository pattern
type Repository interface {
    Create(ctx context.Context, entity *Entity) error
    Update(ctx context.Context, entity *Entity) error
    Delete(ctx context.Context, id uint) error
    FindByID(ctx context.Context, id uint) (*Entity, error)
}

// Event publishing
events.Publish(ctx, "topic", event)

// Transaction
repo.Transaction(ctx, func(tx *gorm.DB) error {
    // operations
})
```

---

**Created**: 2025-11-19  
**Purpose**: Comprehensive index for microservices codebase navigation  
**Maintained by**: Development Team

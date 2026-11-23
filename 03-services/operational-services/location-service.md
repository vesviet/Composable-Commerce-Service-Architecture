# 🗺️ Location Service - Geographic Data & Delivery Zones

> **Owner**: Platform Team  
> **Last Updated**: 2026-11-23  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: HTTP 8007 / gRPC 9007

**Service Name**: Location Service  
**Version**: v1.1.0  
**Production Ready**: 90%  
**Code Review**: [Location Service Review Checklist](../../10-appendix/workflow/location-review-checklist.md)  

> **Deep Dive**: Extended architecture and API notes in [platform-services/location-service.md](../platform-services/location-service.md).

---

## 🎯 Overview

Location Service manages hierarchical geographic location data for the e-commerce platform. It provides a tree structure supporting Country → State/Province → City → District → Ward, with location search, validation, and caching.

### Core Capabilities
- **🌍 Location Hierarchy**: 5-level tree (Country → State → City → District → Ward)
- **🔍 Location Search**: Fuzzy name/code search with PostgreSQL trigram indexes
- **🌳 Tree Traversal**: GetTree, GetPath, GetAncestors, GetChildren with recursive CTEs
- **✅ Hierarchy Validation**: Validates location type, level, parent relationships
- **⚡ Redis Caching**: Cache-aside pattern for location lookups and tree queries
- **📤 Outbox Pattern**: Reliable event publishing via `common/outbox`
- **📊 Observability**: Health checks, Prometheus metrics, OpenTelemetry tracing

### Business Value
- **Accurate Delivery**: Location hierarchy ensures valid shipping addresses
- **Performance**: Redis caching for sub-millisecond location lookups
- **Reliability**: Outbox pattern guarantees event delivery

---

## 🏗️ Architecture

### Service Architecture
```
location/
├── cmd/
│   ├── location/              # Main API server (HTTP + gRPC)
│   ├── worker/                # Background worker (outbox processing)
│   └── migrate/               # Database migration CLI
├── internal/
│   ├── biz/
│   │   └── location/          # Domain entities, use cases, validation, outbox
│   ├── data/
│   │   ├── postgres/          # PostgreSQL repositories, transactions
│   │   └── health.go          # Health check repository
│   ├── service/               # gRPC/HTTP API layer (proto adapter)
│   ├── server/                # HTTP & gRPC server setup, middleware
│   ├── client/                # gRPC clients (user, warehouse, shipping)
│   ├── config/                # Viper-based configuration
│   ├── event/                 # Dapr event publisher
│   ├── model/                 # GORM database models
│   └── worker/                # Outbox worker wrapper
├── api/location/v1/           # Proto definitions & generated code
├── migrations/                # Goose SQL migrations
└── configs/                   # config.yaml
```

### Ports & Dependencies
- **HTTP API**: `:8007` — REST endpoints
- **gRPC API**: `:9007` — Internal service communication
- **Database**: PostgreSQL (`location_db`)
- **Cache**: Redis for location & tree caching
- **Dependencies**: `common@v1.23.1`, `shipping@v1.1.9`, `user@v1.0.11`, `warehouse@v1.2.3`

---

## 🔌 Key APIs (from `api/location/v1/location.proto`)

### Health & Info
| RPC | HTTP | Description |
|-----|------|-------------|
| `HealthCheck` | `GET /api/v1/location/health` | Service health with dependency status |
| `GetServiceInfo` | `GET /api/v1/location/info` | Service metadata and capabilities |

### Location Operations
| RPC | HTTP | Description |
|-----|------|-------------|
| `GetLocation` | `GET /api/v1/location/{id}` | Get by ID or code |
| `ListLocations` | `GET /api/v1/location` | List with filters, cursor-based pagination |
| `SearchLocations` | `GET /api/v1/location/search` | Fuzzy search by name/code |
| `ValidateLocation` | `POST /api/v1/location/validate` | Validate hierarchy rules |

### Tree Traversal
| RPC | HTTP | Description |
|-----|------|-------------|
| `GetLocationTree` | `GET /api/v1/location/tree` | Full tree from root (recursive CTE) |
| `GetLocationPath` | `GET /api/v1/location/{id}/path` | Path from root to location |
| `GetChildren` | `GET /api/v1/location/{parent_id}/children` | Direct children of a location |
| `GetAncestors` | `GET /api/v1/location/{id}/ancestors` | Ancestor chain to root |

---

## 🌍 Location Hierarchy

### Vietnam Example
```
Country: VN (Vietnam)
├── State: HN (Hanoi)
│   ├── City: HN-001 (Hanoi City)
│   │   ├── District: HN-001-001 (Ba Dinh)
│   │   │   ├── Ward: HN-001-001-001 (Cong Vi)
│   │   │   └── Ward: HN-001-001-002 (Dien Bien)
│   │   └── District: HN-001-002 (Hoan Kiem)
│   └── ...
└── State: HCM (Ho Chi Minh City)
    └── ...
```

### Location Types
| Type | Level | Parent Required | Example |
|------|-------|-----------------|---------|
| `country` | 0 | No (root) | Vietnam (VN) |
| `state` | 1 | Country | Hanoi |
| `city` | 2 | State | Hanoi City |
| `district` | 3 | City | Ba Dinh |
| `ward` | 4 | District | Cong Vi |

---

## 🎯 Business Logic

### Validation Rules
- Code uniqueness enforced within parent (database constraint + biz validation)
- Level must match type (country=0, state=1, city=2, district=3, ward=4)
- Country cannot have parent; all other types require parent
- Parent must be exactly one level above child
- Coordinates: both lat/lng required if either provided; lat[-90,90], lng[-180,180]
- Postal codes: max 100 entries, each max 20 chars
- Metadata: max 20 keys, key max 50 chars, string value max 500 chars

### Caching Strategy
- Individual locations cached 24h by ID (`location:{id}`)
- Tree queries cached 24h by root+depth (`location:tree:{rootId}:{depth}`)
- Cache invalidation: on update, delete, and create
- Graceful degradation: Redis failures logged but don't block DB queries

---

## 📊 Event-Driven Architecture

### Published Events (via Outbox Pattern)
| Event | Trigger | Payload |
|-------|---------|---------|
| `location.created` | New location created | id, code, name, type, country_code, parent_id |
| `location.updated` | Location modified | id, code, name, type, country_code, parent_id, updated_at |
| `location.deleted` | Location removed | (defined but not yet published) |

### Worker Binary
The `cmd/worker/` binary processes the outbox table, publishing pending events via Dapr PubSub.

---

## 🔗 Integration Points

### Consumed By
- **Gateway**: Routes location API requests
- **Warehouse**: Uses location for geographic data

### gRPC Clients (defined but not wired)
- User Service, Warehouse Service, Shipping Service clients with circuit breakers

---

## 🚀 Development Guide

### Quick Start
```bash
cd location
go mod tidy
make api          # Generate proto
make wire         # Generate DI
make run          # Start service
```

### Configuration
```yaml
# configs/config.yaml
server:
  http:
    addr: 0.0.0.0:8007
  grpc:
    addr: 0.0.0.0:9007
data:
  database:
    driver: postgres
    source: postgres://location_user:location_pass@localhost:5432/location_db?sslmode=disable
  redis:
    addr: redis.default.svc.cluster.local:6379
location:
  cache:
    location_ttl: 3600s
    tree_ttl: 7200s
    search_ttl: 1800s
  pagination:
    default_limit: 20
    max_limit: 100
```

---

**Service Status**: Production Ready (90%)  
**Critical Path**: Location tree management and address validation  
**Performance Target**: <50ms location lookup (with cache), <200ms tree queries  

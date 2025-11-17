# [Service Name] Service

> **Template Version**: 1.0  
> **Last Updated**: [Date]  
> **Status**: [Draft/Review/Complete]

---

## 📋 Service Overview

### Description
[Brief description of what this service does and its main responsibilities]

### Business Context
[Why this service exists and how it fits into the overall business flow]

### Key Responsibilities
- [Responsibility 1]
- [Responsibility 2]
- [Responsibility 3]

---

## 🏗️ Architecture

### Service Type
- [ ] Application Service (Business Logic)
- [ ] Infrastructure Service (Supporting)
- [ ] Gateway Service (API Gateway/BFF)

### Technology Stack
- **Framework**: go-kratos/kratos v2.7+ (Go microservice framework)
- **Database**: PostgreSQL with GORM (primary), MongoDB (document storage)
- **Message Queue**: Dapr Pub/Sub with Redis Streams backend
- **Cache**: Redis Cluster (distributed cache)
- **Service Discovery**: Consul (service registry and discovery)
- **Communication**: gRPC (internal), HTTP/REST (external)
- **External APIs**: [List any external service dependencies]

### Deployment
- **Container**: Docker
- **Orchestration**: Kubernetes with Dapr runtime
- **Service Discovery**: Consul cluster with health checks
- **Service Mesh**: Consul Connect with mTLS
- **Load Balancer**: Kong API Gateway with Consul integration

---

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/[service-name]
Staging: https://staging-api.domain.com/v1/[service-name]
Local: http://localhost:800X/v1/[service-name]  # HTTP port (8000-8014)
gRPC: localhost:900X  # gRPC port (9000-9014)
```

### Authentication
- **Type**: JWT Bearer Token (RS256 signing)
- **Required Scopes**: [service-name]:read, [service-name]:write
- **Rate Limiting**: 1000 requests/minute per user
- **Service-to-Service**: Consul ACL tokens with permission matrix

### Core Endpoints

#### [Endpoint Group 1 - e.g., Product Management]

##### GET /products
**Purpose**: Retrieve product list with filtering and pagination

**Request**:
```http
GET /v1/catalog/products?page=1&limit=20&category=electronics&warehouse=WH001
Authorization: Bearer {jwt_token}
```

**Query Parameters**:
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| page | integer | No | Page number (default: 1) | 1 |
| limit | integer | No | Items per page (default: 20, max: 100) | 20 |
| category | string | No | Filter by category | electronics |
| warehouse | string | No | Filter by warehouse | WH001 |

**Response**:
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": "prod_123",
        "sku": "LAPTOP-001",
        "name": "Gaming Laptop",
        "category": "electronics",
        "price": {
          "amount": 1299.99,
          "currency": "USD"
        },
        "warehouse": "WH001",
        "createdAt": "2024-01-15T10:30:00Z",
        "updatedAt": "2024-01-15T10:30:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "totalPages": 8
    }
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "1.0"
  }
}
```

**Error Responses**:
```json
// 400 Bad Request
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMETERS",
    "message": "Invalid query parameters",
    "details": {
      "limit": "Must be between 1 and 100"
    }
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}

// 401 Unauthorized
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token"
  }
}

// 500 Internal Server Error
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred"
  }
}
```

##### POST /products
**Purpose**: Create a new product

**Request**:
```http
POST /v1/catalog/products
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "sku": "LAPTOP-002",
  "name": "Business Laptop",
  "description": "High-performance laptop for business use",
  "category": "electronics",
  "brand": "TechBrand",
  "attributes": {
    "color": "Silver",
    "storage": "512GB SSD",
    "ram": "16GB"
  },
  "warehouse": "WH001"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "product": {
      "id": "prod_124",
      "sku": "LAPTOP-002",
      "name": "Business Laptop",
      "status": "active",
      "createdAt": "2024-01-15T10:35:00Z"
    }
  }
}
```

### [Additional Endpoint Groups...]

---

## 🗄️ Database Schema

### Primary Database
**Type**: [PostgreSQL/MongoDB/etc.]  
**Connection**: [Connection details/environment variables]

### Migration Management
**Tool**: [golang-migrate/migrate, GORM AutoMigrate, custom migration system]  
**Migration Files Location**: `./migrations/`  
**Migration Command**: `make migrate-up` / `make migrate-down`

#### Migration File Structure
```
migrations/
├── 001_create_users_table.up.sql
├── 001_create_users_table.down.sql
├── 002_add_user_profiles.up.sql
├── 002_add_user_profiles.down.sql
├── 003_create_products_table.up.sql
└── 003_create_products_table.down.sql
```

#### Migration Commands
```bash
# Build migration binary
make build

# Apply all pending migrations
./bin/migrate -database-url "$DATABASE_URL" -command up

# Rollback last migration
./bin/migrate -database-url "$DATABASE_URL" -command down -steps 1

# Check migration status
./bin/migrate -database-url "$DATABASE_URL" -command version

# Force migration version (use with caution)
./bin/migrate -database-url "$DATABASE_URL" -command force -version 3
```

### Tables/Collections

#### products
```sql
-- Migration: 003_create_products_table.up.sql
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    brand VARCHAR(100),
    attributes JSONB,
    warehouse_id VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_products_sku (sku),
    INDEX idx_products_category (category),
    INDEX idx_products_warehouse (warehouse_id),
    INDEX idx_products_status (status)
);

-- Add comments for documentation
COMMENT ON TABLE products IS 'Product catalog with inventory tracking';
COMMENT ON COLUMN products.sku IS 'Stock Keeping Unit - unique product identifier';
COMMENT ON COLUMN products.attributes IS 'JSON object containing product-specific attributes';
```

#### [Additional tables...]

### Migration History Example
```sql
-- Migration tracking table (automatically created)
CREATE TABLE schema_migrations (
    version BIGINT PRIMARY KEY,
    dirty BOOLEAN NOT NULL DEFAULT FALSE
);

-- Example migration history
INSERT INTO schema_migrations (version, dirty) VALUES 
(001, FALSE),
(002, FALSE),
(003, FALSE);
```

### Cache Schema (Redis)
```
Key Pattern: service:products:{product_id}
TTL: 3600 seconds (1 hour)
Value: JSON serialized product data

Key Pattern: service:products:list:{hash}
TTL: 300 seconds (5 minutes)
Value: JSON serialized product list with pagination
```

---

## 📨 Event Schemas

### Published Events

#### ProductCreated
**Topic**: `catalog.product.created`  
**Version**: 1.0

```json
{
  "eventId": "evt_123",
  "eventType": "ProductCreated",
  "version": "1.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "source": "catalog-service",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "name": "Gaming Laptop",
    "category": "electronics",
    "warehouse": "WH001",
    "createdBy": "user_456"
  },
  "metadata": {
    "correlationId": "corr_789",
    "causationId": "cause_101"
  }
}
```

#### ProductUpdated
**Topic**: `catalog.product.updated`  
**Version**: 1.0

```json
{
  "eventId": "evt_124",
  "eventType": "ProductUpdated",
  "version": "1.0",
  "timestamp": "2024-01-15T10:35:00Z",
  "source": "catalog-service",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "changes": {
      "name": {
        "old": "Gaming Laptop",
        "new": "Gaming Laptop Pro"
      },
      "price": {
        "old": 1199.99,
        "new": 1299.99
      }
    },
    "updatedBy": "user_456"
  }
}
```

### Subscribed Events

#### InventoryUpdated
**Topic**: `inventory.stock.updated`  
**Source**: warehouse-inventory-service

```json
{
  "eventType": "InventoryUpdated",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "warehouse": "WH001",
    "quantity": 45,
    "reserved": 5,
    "available": 40
  }
}
```

---

## 🔗 Service Dependencies

### Upstream Dependencies (Services this service calls)

#### [Dependency Service Name]
- **Purpose**: [Why this service is called]
- **Endpoints Used**: [List of endpoints]
- **Fallback Strategy**: [What happens if service is down]
- **SLA Requirements**: [Response time, availability]

### Downstream Dependencies (Services that call this service)

#### [Consumer Service Name]
- **Purpose**: [What data they get from this service]
- **Endpoints Used**: [List of endpoints they call]
- **Usage Pattern**: [Frequency, peak times]

---

## ⚙️ Configuration

### Environment Variables
```bash
# Kratos Server Configuration
SERVER_HTTP_ADDR=0.0.0.0:8001  # HTTP port (8000-8014 range)
SERVER_GRPC_ADDR=0.0.0.0:9001  # gRPC port (9000-9014 range)
SERVER_HTTP_TIMEOUT=1s
SERVER_GRPC_TIMEOUT=1s

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/service_db
DATABASE_MAX_CONNECTIONS=20
DATABASE_TIMEOUT=30s

# Database Migration
MIGRATION_PATH=./migrations
MIGRATION_TABLE=schema_migrations
AUTO_MIGRATE=false  # Set to true for development only
MIGRATION_LOCK_TIMEOUT=15m

# Redis Cache
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=secure_password
REDIS_DB=0
REDIS_DIAL_TIMEOUT=1s
REDIS_READ_TIMEOUT=0.2s
REDIS_WRITE_TIMEOUT=0.2s

# Consul Service Discovery
CONSUL_ADDRESS=localhost:8500
CONSUL_SCHEME=http
CONSUL_DATACENTER=dc1
CONSUL_HEALTH_CHECK=true
CONSUL_HEALTH_CHECK_INTERVAL=10s

# Dapr Configuration
DAPR_HTTP_PORT=3500
DAPR_GRPC_PORT=50001
DAPR_PUBSUB_NAME=pubsub-redis
DAPR_STATE_STORE_NAME=statestore-redis

# Event Bus (Kafka via Dapr)
KAFKA_BROKERS=localhost:9092
KAFKA_GROUP_ID=service-group

# Monitoring & Tracing
PROMETHEUS_PORT=9090
JAEGER_ENDPOINT=http://localhost:14268/api/traces
TRACE_ENDPOINT=http://localhost:14268/api/traces

# Security
JWT_PRIVATE_KEY_PATH=/secrets/jwt-private-key.pem
JWT_ACCESS_TOKEN_EXPIRATION=3600
JWT_REFRESH_TOKEN_EXPIRATION=86400
```

### Feature Flags
```yaml
features:
  enable_caching: true
  enable_search_indexing: true
  enable_audit_logging: true
  max_products_per_request: 100
```

---

## 🚨 Error Handling

### Error Codes
| Code | HTTP Status | Description | Retry Strategy |
|------|-------------|-------------|----------------|
| INVALID_PARAMETERS | 400 | Invalid request parameters | No retry |
| UNAUTHORIZED | 401 | Invalid or expired token | Refresh token |
| FORBIDDEN | 403 | Insufficient permissions | No retry |
| NOT_FOUND | 404 | Resource not found | No retry |
| CONFLICT | 409 | Resource already exists | No retry |
| RATE_LIMITED | 429 | Too many requests | Exponential backoff |
| INTERNAL_ERROR | 500 | Internal server error | Retry with backoff |
| SERVICE_UNAVAILABLE | 503 | Service temporarily unavailable | Retry with backoff |

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": {
      "field": "Additional error details"
    }
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "traceId": "trace_xyz789"
  }
}
```

---

## 📊 Performance & SLAs

### Performance Targets
- **Response Time**: 
  - P50: < 100ms
  - P95: < 300ms
  - P99: < 500ms
- **Throughput**: 1000 requests/second
- **Availability**: 99.9% uptime
- **Error Rate**: < 0.1%

### Resource Requirements
- **CPU**: 2 cores minimum, 4 cores recommended
- **Memory**: 2GB minimum, 4GB recommended
- **Storage**: 10GB minimum for logs and cache
- **Network**: 1Gbps

### Scaling Strategy
- **Horizontal Scaling**: Auto-scale based on CPU/Memory usage
- **Database**: Read replicas for read-heavy operations
- **Cache**: Redis cluster for high availability
- **Load Balancing**: Round-robin with health checks

---

## 🔒 Security

### Authentication & Authorization
- **Authentication**: JWT Bearer tokens
- **Authorization**: Role-based access control (RBAC)
- **Token Validation**: Validate signature and expiry
- **Permissions**: [List required permissions for each endpoint]

### Data Protection
- **Encryption at Rest**: Database encryption enabled
- **Encryption in Transit**: TLS 1.3 for all communications
- **Sensitive Data**: PII data encrypted with AES-256
- **Audit Logging**: All operations logged with user context

### Security Headers
```http
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
```

---

## 🏗️ Kratos Framework Implementation

### Project Structure (Kratos Standard)
```
service-name/
├── README.md
├── Makefile
├── go.mod
├── go.sum
├── Dockerfile
├── docker-compose.yml
├── configs/
│   ├── config.yaml
│   └── config-dev.yaml
├── cmd/
│   ├── service-name/                 # Main service binary
│   │   ├── main.go
│   │   └── wire.go                   # Dependency injection
│   └── migrate/                      # Migration binary
│       └── main.go                   # Separate migration tool
├── internal/
│   ├── biz/                          # Business logic layer
│   │   ├── entity.go
│   │   └── usecase.go
│   ├── data/                         # Data access layer
│   │   ├── entity.go
│   │   └── data.go                   # No migration integration
│   ├── service/                      # Service layer (gRPC/HTTP handlers)
│   │   ├── entity.go
│   │   └── health.go
│   ├── server/                       # Server configuration
│   │   ├── http.go
│   │   ├── grpc.go
│   │   └── consul.go                 # Consul integration
│   └── conf/                         # Configuration structs
│       ├── conf.proto
│       └── conf.pb.go
├── api/                              # API definitions
│   └── service-name/
│       └── v1/
│           ├── entity.proto
│           ├── entity.pb.go
│           ├── entity_grpc.pb.go
│           └── entity_http.pb.go
├── pkg/                              # Shared packages
│   ├── consul/
│   │   └── client.go
│   └── middleware/
│       └── auth.go
├── migrations/                       # Database migrations
│   ├── README.md                     # Migration usage guide
│   ├── 001_create_entities_table.up.sql
│   └── 001_create_entities_table.down.sql
└── deployments/
    └── kubernetes/
        ├── deployment.yaml
        ├── service.yaml
        └── migration-job.yaml
```

### Kratos Configuration (configs/config.yaml)
```yaml
server:
  http:
    addr: 0.0.0.0:8001
    timeout: 1s
  grpc:
    addr: 0.0.0.0:9001
    timeout: 1s

data:
  database:
    driver: postgres
    source: postgres://user:pass@localhost:5432/service_db?sslmode=disable
  redis:
    addr: localhost:6379
    password: ""
    db: 0
    dial_timeout: 1s
    read_timeout: 0.2s
    write_timeout: 0.2s

consul:
  address: localhost:8500
  scheme: http
  datacenter: dc1
  health_check: true
  health_check_interval: 10s
  health_check_timeout: 3s
  deregister_critical_service_after: true
  deregister_critical_service_after_duration: 30s

trace:
  endpoint: http://localhost:14268/api/traces

migration:
  path: ./migrations
  auto_migrate: false
  lock_timeout: 15m
```

### Main Entry Point (cmd/service-name/main.go)
```go
package main

import (
	"flag"
	"os"

	"github.com/go-kratos/kratos/v2"
	"github.com/go-kratos/kratos/v2/config"
	"github.com/go-kratos/kratos/v2/config/file"
	"github.com/go-kratos/kratos/v2/log"
	"github.com/go-kratos/kratos/v2/middleware/tracing"
	"github.com/go-kratos/kratos/v2/registry"
	"github.com/go-kratos/kratos/v2/transport/grpc"
	"github.com/go-kratos/kratos/v2/transport/http"

	"service-name/internal/conf"
	"service-name/internal/server"
	"service-name/internal/service"
	"service-name/internal/data"
	"service-name/internal/biz"

	_ "go.uber.org/automaxprocs"
)

var (
	Name     = "service-name"
	Version  = "v1.0.0"
	flagconf string
	id, _    = os.Hostname()
)

func init() {
	flag.StringVar(&flagconf, "conf", "../../configs", "config path")
}

func newApp(logger log.Logger, gs *grpc.Server, hs *http.Server, r registry.Registrar) *kratos.App {
	return kratos.New(
		kratos.ID(id),
		kratos.Name(Name),
		kratos.Version(Version),
		kratos.Metadata(map[string]string{
			"service.type": "application",
			"service.role": "business-logic",
		}),
		kratos.Logger(logger),
		kratos.Server(gs, hs),
		kratos.Registrar(r),
	)
}

func main() {
	flag.Parse()
	
	logger := log.With(log.NewStdLogger(os.Stdout),
		"ts", log.DefaultTimestamp,
		"caller", log.DefaultCaller,
		"service.id", id,
		"service.name", Name,
		"service.version", Version,
		"trace.id", tracing.TraceID(),
		"span.id", tracing.SpanID(),
	)

	c := config.New(
		config.WithSource(
			file.NewSource(flagconf),
		),
	)
	defer c.Close()

	if err := c.Load(); err != nil {
		panic(err)
	}

	var bc conf.Bootstrap
	if err := c.Scan(&bc); err != nil {
		panic(err)
	}

	// Initialize data layer (no migration integration)
	dataProvider, cleanup, err := data.NewData(bc.Data, logger)
	if err != nil {
		panic(err)
	}
	defer cleanup()

	// Initialize business layer
	entityUseCase := biz.NewEntityUseCase(dataProvider, logger)

	// Initialize service layer
	entityService := service.NewEntityService(entityUseCase, logger)

	// Initialize servers with Consul integration
	httpSrv := server.NewHTTPServer(bc.Server, entityService, logger)
	grpcSrv := server.NewGRPCServer(bc.Server, entityService, logger)

	// Initialize Consul registry
	r := server.NewConsulRegistry(bc.Consul, logger)

	app := newApp(logger, grpcSrv, httpSrv, r)

	if err := app.Run(); err != nil {
		panic(err)
	}
}
```

### Migration Binary (cmd/migrate/main.go)
```go
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "github.com/lib/pq"
)

var (
	databaseURL = flag.String("database-url", "", "Database URL")
	command     = flag.String("command", "up", "Migration command: up, down, version, force")
	version     = flag.Int("version", -1, "Migration version for force command")
	steps       = flag.Int("steps", 1, "Number of steps for down command")
)

func main() {
	flag.Parse()

	if *databaseURL == "" {
		*databaseURL = os.Getenv("DATABASE_URL")
	}

	if *databaseURL == "" {
		log.Fatal("Database URL is required")
	}

	// Connect to database
	db, err := sql.Open("postgres", *databaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Create postgres driver
	driver, err := postgres.WithInstance(db, &postgres.Config{
		MigrationsTable: "service_schema_migrations",
	})
	if err != nil {
		log.Fatalf("Failed to create postgres driver: %v", err)
	}

	// Create migrate instance
	m, err := migrate.NewWithDatabaseInstance("file://../migrations", "postgres", driver)
	if err != nil {
		log.Fatalf("Failed to create migrate instance: %v", err)
	}

	// Execute command
	switch *command {
	case "up":
		if err := m.Up(); err != nil && err != migrate.ErrNoChange {
			log.Fatalf("Failed to run migrations up: %v", err)
		}
		fmt.Println("Migrations completed successfully")
	case "down":
		if err := m.Steps(-*steps); err != nil {
			log.Fatalf("Failed to run migrations down: %v", err)
		}
		fmt.Println("Migrations down completed successfully")
	case "version":
		version, dirty, err := m.Version()
		if err != nil {
			log.Fatalf("Failed to get migration version: %v", err)
		}
		fmt.Printf("Current version: %d, Dirty: %t\n", version, dirty)
	case "force":
		if *version == -1 {
			log.Fatal("Version is required for force command")
		}
		if err := m.Force(*version); err != nil {
			log.Fatalf("Failed to force migration: %v", err)
		}
		fmt.Println("Migration forced successfully")
	}
}
```

### Consul Integration (internal/server/consul.go)
```go
package server

import (
	"github.com/go-kratos/kratos/contrib/registry/consul/v2"
	"github.com/go-kratos/kratos/v2/log"
	"github.com/go-kratos/kratos/v2/registry"
	"github.com/hashicorp/consul/api"

	"service-name/internal/conf"
)

func NewConsulRegistry(c *conf.Consul, logger log.Logger) registry.Registrar {
	consulConfig := api.DefaultConfig()
	consulConfig.Address = c.Address
	consulConfig.Scheme = c.Scheme
	consulConfig.Datacenter = c.Datacenter

	consulClient, err := api.NewClient(consulConfig)
	if err != nil {
		log.Fatal("Failed to create Consul client:", err)
	}

	r := consul.New(consulClient, consul.WithHealthCheck(c.HealthCheck))
	return r
}
```

---

## 🎯 Migration Approach Benefits

### ✅ Separate Migration Binary Advantages

#### 🛡️ **Production Safety**
- **No Auto-Migration Risk**: Migrations run separately, controlled by operators
- **Explicit Control**: Decide exactly when to run migrations
- **Rollback Safety**: Easy to rollback migrations independently of service

#### 🐛 **Easier Debugging**
- **Separate Logs**: Migration logs separate from service logs
- **Clear Errors**: Migration failures don't affect service startup
- **Simple Troubleshooting**: Easy to debug migration issues in isolation

#### 🚀 **Operational Excellence**
- **Fast Service Startup**: No waiting for migrations (2-5s vs 10-30s)
- **Kubernetes Jobs**: Easy to run migrations as K8s jobs
- **CI/CD Friendly**: Migrations can run in separate pipeline stages

#### 📦 **Simpler Containers**
- **Smaller Images**: No bash, postgresql-client, migration tools (50% smaller)
- **Single Responsibility**: Each binary has one job
- **Cleaner Builds**: Faster build times, fewer dependencies

### 📊 **Comparison: Complex vs Simple Approach**

| Aspect | Complex (Auto-Migration) | Simple (Separate Binary) | Improvement |
|--------|--------------------------|---------------------------|-------------|
| **Dockerfile Lines** | 60+ lines | 25 lines | 58% reduction |
| **Container Size** | ~100MB | ~50MB | 50% smaller |
| **Dependencies** | bash, postgresql-client, migrate | None | Minimal |
| **Startup Time** | 10-30s (with migration) | 2-5s | 80% faster |
| **Debug Complexity** | High (mixed logs) | Low (separate) | Much easier |
| **Production Risk** | High (auto-migrate) | Low (manual) | Much safer |
| **Operational Control** | Limited | Full | Complete control |

---

## 🔄 Database Migration Implementation

### Migration Tool Setup

#### Separate Migration Binary (Recommended)
```go
// cmd/migrate/main.go
package main

import (
    "database/sql"
    "flag"
    "fmt"
    "log"
    "os"

    "github.com/golang-migrate/migrate/v4"
    "github.com/golang-migrate/migrate/v4/database/postgres"
    _ "github.com/golang-migrate/migrate/v4/source/file"
    _ "github.com/lib/pq"
)

var (
    databaseURL = flag.String("database-url", "", "Database URL")
    command     = flag.String("command", "up", "Migration command: up, down, version, force")
    version     = flag.Int("version", -1, "Migration version for force command")
    steps       = flag.Int("steps", 1, "Number of steps for down command")
)

func main() {
    flag.Parse()

    if *databaseURL == "" {
        *databaseURL = os.Getenv("DATABASE_URL")
    }

    if *databaseURL == "" {
        log.Fatal("Database URL is required")
    }

    // Connect to database
    db, err := sql.Open("postgres", *databaseURL)
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    defer db.Close()

    // Create postgres driver
    driver, err := postgres.WithInstance(db, &postgres.Config{
        MigrationsTable: "service_schema_migrations",
    })
    if err != nil {
        log.Fatalf("Failed to create postgres driver: %v", err)
    }

    // Create migrate instance
    m, err := migrate.NewWithDatabaseInstance("file://../migrations", "postgres", driver)
    if err != nil {
        log.Fatalf("Failed to create migrate instance: %v", err)
    }

    // Execute command
    switch *command {
    case "up":
        if err := m.Up(); err != nil && err != migrate.ErrNoChange {
            log.Fatalf("Failed to run migrations up: %v", err)
        }
        fmt.Println("Migrations completed successfully")
    case "down":
        if err := m.Steps(-*steps); err != nil {
            log.Fatalf("Failed to run migrations down: %v", err)
        }
        fmt.Println("Migrations down completed successfully")
    case "version":
        version, dirty, err := m.Version()
        if err != nil {
            log.Fatalf("Failed to get migration version: %v", err)
        }
        fmt.Printf("Current version: %d, Dirty: %t\n", version, dirty)
    case "force":
        if *version == -1 {
            log.Fatal("Version is required for force command")
        }
        if err := m.Force(*version); err != nil {
            log.Fatalf("Failed to force migration: %v", err)
        }
        fmt.Println("Migration forced successfully")
    }
}
```

#### Service Startup (No Migration Integration)
```go
// cmd/service/main.go
func main() {
    // ... configuration loading

    // Database connection (migrations run separately)
    db, err := sql.Open("postgres", databaseURL)
    if err != nil {
        log.Fatal("Failed to connect to database:", err)
    }
    defer db.Close()

    // Start service immediately (no migration wait)
    // ... continue with service initialization
}
```

### Migration File Examples

#### 001_create_users_table.up.sql
```sql
-- Create users table with all necessary fields
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    email_verified BOOLEAN DEFAULT FALSE,
    email_verification_token VARCHAR(255),
    email_verification_expires_at TIMESTAMP WITH TIME ZONE,
    password_reset_token VARCHAR(255),
    password_reset_expires_at TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    last_login_ip INET,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for performance
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email_verification_token ON users(email_verification_token) WHERE email_verification_token IS NOT NULL;
CREATE INDEX idx_users_password_reset_token ON users(password_reset_token) WHERE password_reset_token IS NOT NULL;
CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created_at ON users(created_at);

-- Add table and column comments
COMMENT ON TABLE users IS 'User accounts with authentication and profile information';
COMMENT ON COLUMN users.email IS 'User email address, must be unique and verified';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hashed password';
COMMENT ON COLUMN users.failed_login_attempts IS 'Counter for failed login attempts, reset on successful login';
COMMENT ON COLUMN users.locked_until IS 'Account lock expiration timestamp';
COMMENT ON COLUMN users.deleted_at IS 'Soft delete timestamp, NULL for active records';
```

#### 001_create_users_table.down.sql
```sql
-- Drop users table and all associated indexes
DROP TABLE IF EXISTS users CASCADE;
```

#### 002_create_user_profiles_table.up.sql
```sql
-- Create user profiles table for extended user information
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    avatar_url VARCHAR(500),
    bio TEXT,
    date_of_birth DATE,
    gender VARCHAR(20) CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    country_code VARCHAR(2),
    timezone VARCHAR(50),
    language_code VARCHAR(5) DEFAULT 'en',
    notification_preferences JSONB DEFAULT '{}',
    privacy_settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE UNIQUE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_country_code ON user_profiles(country_code);
CREATE INDEX idx_user_profiles_created_at ON user_profiles(created_at);

-- Add comments
COMMENT ON TABLE user_profiles IS 'Extended user profile information';
COMMENT ON COLUMN user_profiles.notification_preferences IS 'JSON object containing user notification preferences';
COMMENT ON COLUMN user_profiles.privacy_settings IS 'JSON object containing user privacy settings';
```

#### 002_create_user_profiles_table.down.sql
```sql
-- Drop user profiles table
DROP TABLE IF EXISTS user_profiles CASCADE;
```

### Makefile Migration Commands
```makefile
# Database Migration Commands
.PHONY: migrate-up migrate-down migrate-status migrate-version migrate-force

# Apply all pending migrations
migrate-up:
	@echo "Applying migrations..."
	@if [ -z "$(DATABASE_URL)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	./bin/migrate -database-url "$(DATABASE_URL)" -command up

# Rollback last migration
migrate-down:
	@echo "Rolling back migration..."
	@if [ -z "$(DATABASE_URL)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	./bin/migrate -database-url "$(DATABASE_URL)" -command down -steps 1

# Rollback multiple steps
migrate-down-steps:
	@if [ -z "$(STEPS)" ]; then echo "Usage: make migrate-down-steps STEPS=number"; exit 1; fi
	@if [ -z "$(DATABASE_URL)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	@echo "Rolling back $(STEPS) migrations..."
	./bin/migrate -database-url "$(DATABASE_URL)" -command down -steps $(STEPS)

# Check migration status
migrate-status:
	@echo "Migration status:"
	@if [ -z "$(DATABASE_URL)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	./bin/migrate -database-url "$(DATABASE_URL)" -command version

# Force migration version (use with caution)
migrate-force:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make migrate-force VERSION=version_number"; exit 1; fi
	@if [ -z "$(DATABASE_URL)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	@echo "Forcing migration version to $(VERSION)..."
	./bin/migrate -database-url "$(DATABASE_URL)" -command force -version $(VERSION)

# Create new migration files (manual process)
migrate-create:
	@if [ -z "$(NAME)" ]; then echo "Usage: make migrate-create NAME=migration_name"; exit 1; fi
	@echo "Creating migration files for: $(NAME)"
	@TIMESTAMP=$$(date +%Y%m%d%H%M%S); \
	touch migrations/$${TIMESTAMP}_$(NAME).up.sql; \
	touch migrations/$${TIMESTAMP}_$(NAME).down.sql; \
	echo "Created: migrations/$${TIMESTAMP}_$(NAME).up.sql"; \
	echo "Created: migrations/$${TIMESTAMP}_$(NAME).down.sql"
```

### Docker Integration
```dockerfile
# Simple Dockerfile (no migration complexity)
FROM golang:1.21-alpine AS builder

WORKDIR /src
RUN apk update --no-cache && apk add --no-cache tzdata

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN mkdir -p bin/ && go build -ldflags "-X main.Version=$(date)" -o ./bin/ ./...

FROM alpine:latest
RUN apk --no-cache add ca-certificates

WORKDIR /app
COPY --from=builder /usr/share/zoneinfo/Asia/Ho_Chi_Minh /usr/share/zoneinfo/Asia/Ho_Chi_Minh
ENV TZ Asia/Ho_Chi_Minh

# Copy binaries and files
COPY --from=builder /src/bin ./bin
COPY --from=builder /src/configs ./configs
COPY --from=builder /src/migrations ./migrations

WORKDIR /app/bin
EXPOSE 8001 9001
CMD ["./service-name", "-conf", "../configs"]
```

### Docker Compose with Separate Migration
```yaml
version: '3.8'
services:
  # Migration job (runs first)
  service-migration:
    build: .
    container_name: service-migration
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/service_db?sslmode=disable
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - microservices
    command: ["./migrate", "-database-url", "postgresql://user:pass@postgres:5432/service_db?sslmode=disable", "-command", "up"]
    restart: "no"

  # Service (runs after migration)
  service:
    build: .
    container_name: service
    ports:
      - "8001:8001"
      - "9001:9001"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/service_db?sslmode=disable
      - CONSUL_ADDRESS=consul:8500
    depends_on:
      postgres:
        condition: service_healthy
      service-migration:
        condition: service_completed_successfully
    networks:
      - microservices
```

### Kubernetes Migration Job
```yaml
# k8s-migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: service-migration
  labels:
    app: service-name
    component: migration
spec:
  ttlSecondsAfterFinished: 3600  # Clean up after 1 hour
  backoffLimit: 3
  template:
    metadata:
      labels:
        app: service-name
        component: migration
    spec:
      restartPolicy: OnFailure
      containers:
      - name: migration
        image: service-name:latest
        command: ["./migrate"]
        args: ["-database-url", "$(DATABASE_URL)", "-command", "up"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: service-secrets
              key: database-url
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: migration-config
          mountPath: /app/configs
          readOnly: true
      initContainers:
      - name: wait-for-db
        image: postgres:15-alpine
        command: ['sh', '-c']
        args:
        - |
          until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do
            echo "Waiting for database..."
            sleep 2
          done
        env:
        - name: DB_HOST
          value: "postgres-service"
        - name: DB_PORT
          value: "5432"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: service-secrets
              key: db-user
      volumes:
      - name: migration-config
        configMap:
          name: service-config
```

### Migration Best Practices

#### 1. Migration File Naming
- Use sequential numbering: `001_`, `002_`, `003_`
- Descriptive names: `create_users_table`, `add_user_email_index`
- Always create both `.up.sql` and `.down.sql` files

#### 2. Safe Migration Patterns
```sql
-- ✅ Good: Add column with default value
ALTER TABLE users ADD COLUMN phone VARCHAR(20) DEFAULT '';

-- ✅ Good: Create index concurrently (PostgreSQL)
CREATE INDEX CONCURRENTLY idx_users_phone ON users(phone);

-- ✅ Good: Add NOT NULL constraint safely
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
UPDATE users SET email_verified = FALSE WHERE email_verified IS NULL;
ALTER TABLE users ALTER COLUMN email_verified SET NOT NULL;

-- ❌ Avoid: Dropping columns in production without backup
-- ALTER TABLE users DROP COLUMN old_column;

-- ✅ Better: Rename column first, then drop in later migration
ALTER TABLE users RENAME COLUMN old_column TO old_column_deprecated;
-- In next migration after confirming no usage:
-- ALTER TABLE users DROP COLUMN old_column_deprecated;
```

#### 3. Data Migration Example
```sql
-- 003_migrate_user_data.up.sql
-- Migrate data from old structure to new structure
BEGIN;

-- Create temporary column
ALTER TABLE users ADD COLUMN full_name_temp VARCHAR(255);

-- Migrate data
UPDATE users 
SET full_name_temp = CONCAT(first_name, ' ', last_name)
WHERE first_name IS NOT NULL AND last_name IS NOT NULL;

-- Add new column with migrated data
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
UPDATE users SET full_name = full_name_temp;

-- Drop temporary column
ALTER TABLE users DROP COLUMN full_name_temp;

-- Add index
CREATE INDEX idx_users_full_name ON users(full_name);

COMMIT;
```

---

## 🧪 Testing Strategy

### Unit Tests
- **Coverage Target**: > 80%
- **Framework**: [Testing framework used]
- **Mock Strategy**: Mock external dependencies
- **Test Data**: Use factories for test data generation

### Integration Tests
- **Database Tests**: Test with real database (testcontainers)
- **API Tests**: Test all endpoints with various scenarios
- **Event Tests**: Test event publishing and consumption
- **Cache Tests**: Test cache behavior and invalidation

### Performance Tests
- **Load Testing**: Test with expected production load
- **Stress Testing**: Test beyond normal capacity
- **Endurance Testing**: Test for extended periods
- **Tools**: [Load testing tools used]

### Test Examples
```go
// Unit test example
func TestCreateProduct(t *testing.T) {
    // Test implementation
}

// Integration test example
func TestCreateProductAPI(t *testing.T) {
    // API test implementation
}
```

---

## 📈 Monitoring & Observability

### Metrics (Prometheus)
```yaml
# Kratos Built-in Metrics
kratos_http_requests_total: HTTP request counter with method, path, status
kratos_http_request_duration_seconds: HTTP request duration histogram
kratos_grpc_requests_total: gRPC request counter with method, status
kratos_grpc_request_duration_seconds: gRPC request duration histogram

# Business Metrics
service_operations_total: Counter of business operations by type
service_operations_duration_seconds: Business operation duration
service_errors_total: Counter of business errors by type

# Infrastructure Metrics
database_connections_active: Active database connections
database_query_duration_seconds: Database query duration
cache_hits_total: Cache hit counter
cache_misses_total: Cache miss counter
consul_service_health: Consul service health status
dapr_component_health: Dapr component health status

# Migration Metrics
migration_status: Current migration version
migration_duration_seconds: Migration execution time
migration_errors_total: Migration error counter
```

### Logging (Kratos Structured Logging)
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "service": "service-name",
  "service.id": "service-name-pod-abc123",
  "service.name": "service-name",
  "service.version": "v1.0.0",
  "trace.id": "trace_123",
  "span.id": "span_456",
  "caller": "internal/service/service.go:45",
  "message": "Operation completed successfully",
  "data": {
    "operation": "create_entity",
    "entityId": "entity_123",
    "userId": "user_456",
    "duration": "25ms",
    "consul.session": "session_789"
  }
}
```

### Distributed Tracing
- **Tool**: Jaeger
- **Trace Context**: Propagate trace context across service calls
- **Span Tags**: Include relevant business context
- **Sampling**: 10% sampling rate in production

### Health Checks (Kratos + Consul Integration)
```http
GET /health
{
  "status": "healthy",
  "service": {
    "name": "service-name",
    "version": "v1.0.0",
    "uptime": "2h30m15s"
  },
  "checks": {
    "database": {
      "status": "healthy",
      "latency": "2ms",
      "connections": "5/20"
    },
    "cache": {
      "status": "healthy",
      "latency": "1ms",
      "hit_rate": "95%"
    },
    "consul": {
      "status": "healthy",
      "registered": true,
      "session_id": "session_abc123"
    },
    "dapr": {
      "status": "healthy",
      "components": {
        "pubsub-redis": "healthy",
        "statestore-redis": "healthy"
      }
    }
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 🚀 Deployment

### Container Configuration
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /src

# Install dependencies
RUN apk update --no-cache && apk add --no-cache tzdata

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binaries (service + migration)
RUN mkdir -p bin/ && go build -ldflags "-X main.Version=$(date)" -o ./bin/ ./...

FROM alpine:latest

# Install required packages
RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy timezone info
COPY --from=builder /usr/share/zoneinfo/Asia/Ho_Chi_Minh /usr/share/zoneinfo/Asia/Ho_Chi_Minh
ENV TZ Asia/Ho_Chi_Minh

# Copy application binaries and configs
COPY --from=builder /src/bin ./bin
COPY --from=builder /src/configs ./configs
COPY --from=builder /src/migrations ./migrations

WORKDIR /app/bin

# Expose both HTTP and gRPC ports
EXPOSE 8001 9001

CMD ["./service-name", "-conf", "../configs"]
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-name
  labels:
    app: service-name
    version: v1
  annotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "service-name"
    dapr.io/app-port: "8001"
    dapr.io/config: "tracing"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: service-name
  template:
    metadata:
      labels:
        app: service-name
        version: v1
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "service-name"
        dapr.io/app-port: "8001"
        dapr.io/config: "tracing"
    spec:
      containers:
      - name: service-name
        image: service-name:latest
        ports:
        - name: http
          containerPort: 8001
        - name: grpc
          containerPort: 9001
        env:
        - name: SERVER_HTTP_ADDR
          value: "0.0.0.0:8001"
        - name: SERVER_GRPC_ADDR
          value: "0.0.0.0:9001"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: service-secrets
              key: database-url
        - name: CONSUL_ADDRESS
          value: "consul-service:8500"
        - name: REDIS_ADDR
          value: "redis-service:6379"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8001
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Helm Values
```yaml
replicaCount: 3
image:
  repository: catalog-service
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
    - host: api.domain.com
      paths:
        - path: /v1/catalog
          pathType: Prefix
```

---

## 🔧 Troubleshooting

### Common Issues

#### Migration Issues
**Symptoms**: Migration fails or database in dirty state
**Investigation Steps**:
1. Check migration logs: `./bin/migrate -database-url "$DATABASE_URL" -command version`
2. Review failed migration SQL
3. Check database connectivity
4. Verify migration file syntax

**Solutions**:
```bash
# Check current migration status
./bin/migrate -database-url "$DATABASE_URL" -command version

# Force to specific version (use with caution)
./bin/migrate -database-url "$DATABASE_URL" -command force -version 2

# Rollback and retry
./bin/migrate -database-url "$DATABASE_URL" -command down -steps 1
./bin/migrate -database-url "$DATABASE_URL" -command up
```

#### Service Startup Issues
**Symptoms**: Service fails to start or connect to database
**Investigation Steps**:
1. Verify database is running and accessible
2. Check DATABASE_URL format
3. Ensure migrations have been run
4. Review service logs

**Solutions**:
```bash
# Test database connection
psql "$DATABASE_URL" -c "SELECT 1"

# Run migrations manually
./bin/migrate -database-url "$DATABASE_URL" -command up

# Check service health
curl http://localhost:8001/health
```

#### High Response Times
**Symptoms**: API responses taking > 1 second
**Possible Causes**:
- Database connection pool exhausted
- Cache misses causing database queries
- External service timeouts

**Investigation Steps**:
1. Check database connection metrics
2. Review cache hit/miss ratios
3. Check external service response times
4. Review application logs for errors

### Debugging Commands
```bash
# Check service health
curl http://localhost:8001/health

# View service logs
kubectl logs -f deployment/service-name

# Check metrics
curl http://localhost:9001/metrics

# Database connection test
psql "$DATABASE_URL" -c "SELECT 1"

# Redis connection test
redis-cli -u "$REDIS_URL" ping

# Migration debugging
./bin/migrate -database-url "$DATABASE_URL" -command version
./bin/migrate -database-url "$DATABASE_URL" -command up
```

### Runbook Links
- [Service Restart Procedure](./runbooks/restart-procedure.md)
- [Database Migration Guide](./runbooks/database-migration.md)
- [Incident Response](./runbooks/incident-response.md)

---

## 📚 Additional Resources

### Documentation Links
- [API Documentation (Swagger)](https://api.domain.com/docs/catalog)
- [Architecture Decision Records](./adrs/)
- [Database Schema Documentation](./database/)
- [Event Schema Registry](./events/)

### Development Resources
- [Local Development Setup](./development/setup.md)
- [Code Style Guide](./development/style-guide.md)
- [Contributing Guidelines](./development/contributing.md)
- [Testing Guidelines](./development/testing.md)

### Operations Resources
- [Deployment Guide](./operations/deployment.md)
- [Monitoring Playbook](./operations/monitoring.md)
- [Backup and Recovery](./operations/backup-recovery.md)
- [Security Checklist](./operations/security-checklist.md)

---

## 📝 Change Log

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2024-01-15 | Initial service documentation | [Author Name] |
| 1.1 | 2024-01-20 | Added event schemas and error handling | [Author Name] |

---

## 👥 Team & Ownership

### Service Owner
- **Primary**: [Team/Person responsible]
- **Secondary**: [Backup contact]

### Development Team
- **Tech Lead**: [Name]
- **Developers**: [List of developers]
- **DevOps**: [DevOps contact]

### On-Call Rotation
- **Primary**: [Current on-call person]
- **Escalation**: [Escalation contact]
- **Schedule**: [Link to on-call schedule]

---

**Document Status**: [Draft/Review/Approved]  
**Next Review Date**: [Date]  
**Approved By**: [Approver Name and Date]
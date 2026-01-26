# 📦 Catalog Service - Complete Documentation

**Service Name**: Catalog Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Review Status**: ✅ Reviewed (Production Ready)  
**Production Ready**: 95%  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Product Management APIs](#-product-management-apis)
- [EAV Attribute System](#-eav-attribute-system)
- [Category & Brand APIs](#-category--brand-apis)
- [Database Schema](#-database-schema)
- [Business Logic](#-business-logic)
- [Configuration](#-configuration)
- [Dependencies](#-dependencies)
- [Testing](#-testing)
- [Monitoring & Observability](#-monitoring--observability)
- [Known Issues & TODOs](#-known-issues--todos)
- [Development Guide](#-development-guide)

---

## 🎯 Overview

Catalog Service là **core service** quản lý toàn bộ product catalog trong e-commerce platform. Service này xử lý:

### Core Capabilities
- **🛍️ Product Management**: CRUD operations cho 25,000+ products với complex filtering
- **🏷️ EAV Attribute System**: 3-tier attribute architecture (Hot/Tier1, EAV/Tier2, JSON/Tier3)
- **📂 Category Management**: Hierarchical category structure với templates
- **🏢 Brand & Manufacturer**: Brand management với metadata và sorting
- **📄 CMS Pages**: Content management cho static pages
- **👁️ Visibility Rules**: Age, group, và geo-based access controls
- **🔍 Search Integration**: Auto-sync attributes to Search Service
- **📊 Event-Driven**: Publishes product changes cho indexing và analytics

### Business Value
- **Product Catalog**: Centralized product data với rich attributes
- **Flexibility**: EAV system cho custom product specifications
- **Performance**: Tiered attribute system balances flexibility vs speed
- **Integration**: Seamless sync với Search, Pricing, Warehouse services
- **Content Management**: Built-in CMS cho marketing pages

### Key Differentiators
- **3-Tier Attribute Architecture**: Balances performance với flexibility
- **Event-Driven Sync**: Auto-reindexing khi attribute config changes
- **Rich Filtering**: Advanced search và filter capabilities
- **CMS Integration**: Content management built-in
- **Visibility Controls**: Granular access control cho products

---

## 🏗️ Architecture

### Clean Architecture Implementation

```
catalog/
├── cmd/
│   ├── catalog/                    # Main service entry point
│   ├── worker/                     # Background workers (cron, event consumers)
│   └── migrate/                    # Database migration tool
├── internal/
│   ├── biz/                        # Business Logic Layer
│   │   ├── product/                # Product domain (CRUD, search)
│   │   ├── product_attribute/      # EAV attribute system
│   │   ├── category/               # Category management
│   │   ├── brand/                  # Brand management
│   │   ├── manufacturer/           # Manufacturer management
│   │   ├── cms/                    # CMS pages
│   │   └── product_visibility_rule/ # Visibility rules
│   ├── data/                       # Data Access Layer
│   │   ├── postgres/               # PostgreSQL repositories
│   │   └── redis/                  # Redis cache
│   ├── service/                    # Service Layer (gRPC/HTTP)
│   ├── server/                     # Server setup
│   ├── middleware/                 # HTTP middleware
│   ├── config/                     # Configuration
│   └── constants/                  # Constants & enums
├── api/                            # Protocol Buffers
│   ├── product/v1/                 # Product APIs
│   ├── category/v1/                # Category APIs
│   ├── brand/v1/                   # Brand APIs
│   ├── cms/v1/                     # CMS APIs
│   └── attribute/v1/               # Attribute APIs
├── migrations/                     # Database migrations (25 files)
└── configs/                        # Environment configs
```

### Ports & Endpoints
- **HTTP API**: `:8001` - REST endpoints cho frontend/client apps
- **gRPC API**: `:9001` - Internal service communication
- **Health Check**: `/api/v1/catalog/health`

### Service Dependencies

#### Internal Dependencies
- **Warehouse Service**: Stock levels và availability
- **Pricing Service**: Product pricing và promotions
- **Search Service**: Product indexing và search sync
- **Notification Service**: Product update notifications

#### External Dependencies
- **PostgreSQL**: Primary data store (`catalog_db`)
- **Redis**: Caching layer và session storage
- **Dapr**: Event-driven communication
- **Consul**: Service discovery

---

## 🛍️ Product Management APIs

### Core Product Operations

#### List Products with Advanced Filtering
```protobuf
rpc ListProducts(ListProductsRequest) returns (ListProductsReply) {
  option (google.api.http) = {
    get: "/api/v1/catalog/products"
  };
}
```

**Filters Available:**
- `status`: active, inactive, draft, archived
- `category_id`: Filter by category
- `brand_id`: Filter by brand
- `manufacturer_id`: Filter by manufacturer
- `featured`: Featured products only
- `search`: Full-text search
- `min_price`, `max_price`: Price range
- `in_stock`: Products with stock only
- `attributes`: EAV attribute filters

**Request Example:**
```json
{
  "page": 1,
  "limit": 20,
  "filters": {
    "status": "active",
    "category_id": "electronics",
    "brand_id": "apple",
    "min_price": 500,
    "max_price": 2000,
    "in_stock": true
  },
  "sort_by": "created_at",
  "sort_order": "desc"
}
```

#### Get Product by ID
```protobuf
rpc GetProduct(GetProductRequest) returns (GetProductReply) {
  option (google.api.http) = {
    get: "/api/v1/catalog/products/{id}"
  };
}
```

**Response includes:**
- Product details với all attributes
- Category và brand information
- Stock levels (from Warehouse Service)
- Pricing information (from Pricing Service)
- Visibility rules

#### Get Product by SKU
```protobuf
rpc GetProductBySKU(GetProductBySKURequest) returns (GetProductReply) {
  option (google.api.http) = {
    get: "/api/v1/catalog/products/sku/{sku}"
  };
}
```

#### Create Product
```protobuf
rpc CreateProduct(CreateProductRequest) returns (CreateProductReply) {
  option (google.api.http) = {
    post: "/api/v1/catalog/products"
    body: "*"
  };
}
```

**Product Structure:**
```json
{
  "name": "iPhone 14 Pro 128GB",
  "sku": "IPH14P128",
  "description": "Latest iPhone model",
  "category_id": "smartphones",
  "brand_id": "apple",
  "manufacturer_id": "foxconn",
  "status": "active",
  "is_featured": false,
  "tier1_attributes": {
    "color": "space-gray",
    "size": "6.1-inch",
    "material": "titanium",
    "gender": "unisex",
    "age_group": "adult",
    "weight": 206
  },
  "tier2_attributes": {
    "processor": "A16 Bionic",
    "storage": "128GB",
    "camera": "48MP",
    "battery": "3200mAh"
  },
  "visibility_rules": [
    {
      "type": "age_restriction",
      "value": "13",
      "enforcement": "strict"
    }
  ]
}
```

### Advanced Product Features

#### Search Products
```protobuf
rpc SearchProducts(SearchProductsRequest) returns (SearchProductsReply) {
  option (google.api.http) = {
    get: "/api/v1/catalog/products/search"
  };
}
```

**Search Capabilities:**
- Full-text search across name, description, SKU
- Fuzzy matching với typos
- Relevance scoring
- Faceted search results

#### Bulk Operations
```protobuf
rpc BulkCreateProducts(BulkCreateProductsRequest) returns (BulkCreateProductsReply) {
  option (google.api.http) = {
    post: "/api/v1/catalog/products/bulk"
    body: "*"
  };
}
```

**Bulk Operations:**
- Create/update multiple products
- Batch validation
- Partial success handling
- Progress tracking

#### Media Management
```protobuf
rpc UploadProductImage(UploadProductImageRequest) returns (UploadProductImageResponse) {
  option (google.api.http) = {
    post: "/api/v1/catalog/products/{product_id}/image"
    body: "*"
  };
}
```

---

## 🏷️ EAV Attribute System

### 3-Tier Attribute Architecture

#### Tier 1: Hot Attributes (Performance)
**Stored as columns in products table for fast queries:**
```sql
ALTER TABLE products ADD COLUMN color VARCHAR(100);
ALTER TABLE products ADD COLUMN size VARCHAR(100);
ALTER TABLE products ADD COLUMN material VARCHAR(100);
ALTER TABLE products ADD COLUMN gender VARCHAR(20);
ALTER TABLE products ADD COLUMN age_group VARCHAR(20);
ALTER TABLE products ADD COLUMN weight DECIMAL(8,2);
```

**Use Case:** Most queried attributes (color, size, material, gender, age_group, weight)
**Performance:** Direct column access, standard indexes
**Flexibility:** Limited - requires schema changes

#### Tier 2: EAV Attributes (Flexibility)
**Flexible attributes stored in separate tables:**
```sql
-- Attribute definitions
CREATE TABLE product_attributes (
  id UUID PRIMARY KEY,
  code VARCHAR(100) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL, -- text, number, boolean, date, select
  is_required BOOLEAN DEFAULT FALSE,
  is_searchable BOOLEAN DEFAULT FALSE,
  is_filterable BOOLEAN DEFAULT FALSE,
  is_indexed BOOLEAN, -- NULL=auto, true=force, false=never
  options JSONB, -- For select type
  validation_rules JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Attribute values
CREATE TABLE product_attribute_values (
  id UUID PRIMARY KEY,
  product_id UUID NOT NULL REFERENCES products(id),
  attribute_id UUID NOT NULL REFERENCES product_attributes(id),
  value_text TEXT,
  value_number DECIMAL,
  value_boolean BOOLEAN,
  value_date DATE,
  value_json JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, attribute_id)
);
```

**Use Case:** Custom specifications (processor, camera, battery, warranty, etc.)
**Performance:** Requires joins, GIN indexes on JSONB
**Flexibility:** Unlimited attributes without schema changes

#### Tier 3: JSON Storage (Display)
**Marketing content stored as JSONB:**
```sql
ALTER TABLE products ADD COLUMN specifications JSONB;
ALTER TABLE products ADD COLUMN marketing_content JSONB;
```

**Use Case:** Technical specs, marketing copy, display attributes
**Performance:** Fast retrieval, no joins needed
**Flexibility:** Schema-less storage

### Attribute Management APIs

#### Attribute Definition Management
```protobuf
rpc CreateAttributeDefinition(CreateAttributeDefinitionRequest) returns (CreateAttributeDefinitionReply) {
  option (google.api.http) = {
    post: "/api/v1/catalog/attributes"
    body: "*"
  };
}
```

**Attribute Definition:**
```json
{
  "code": "processor",
  "name": "Processor",
  "type": "text",
  "is_required": false,
  "is_searchable": true,
  "is_filterable": true,
  "is_indexed": null, // auto mode
  "validation_rules": {
    "max_length": 100
  }
}
```

#### Product Attribute Values
```protobuf
rpc SetProductAttributes(SetProductAttributesRequest) returns (SetProductAttributesReply) {
  option (google.api.http) = {
    post: "/api/v1/catalog/products/{product_id}/attributes"
    body: "*"
  };
}
```

### Search Integration

#### Attribute Sync to Search Service
**Auto-sync logic:**
```go
func (uc *ProductAttributeUsecase) UpdateAttributeDefinition(ctx context.Context, req *UpdateAttributeDefinitionRequest) error {
    // Update attribute definition
    // Determine if search re-indexing needed
    shouldReindex := determineReindexNeeded(oldAttr, newAttr)

    if shouldReindex {
        // Get all products using this attribute
        products, err := uc.getProductsByAttribute(ctx, req.Id)
        if err != nil {
            return err
        }

        // Publish re-indexing events for affected products
        for _, product := range products {
            uc.events.PublishCustom(ctx, "catalog.product.reindex", map[string]interface{}{
                "product_id": product.ID,
                "reason": "attribute_config_changed",
                "attribute_code": req.Code,
            })
        }
    }

    return nil
}
```

**Indexing Modes:**
- **Auto Mode** (`is_indexed = NULL`): Sync if `is_searchable = true` OR `is_filterable = true`
- **Force Mode** (`is_indexed = true`): Always sync to search
- **Never Mode** (`is_indexed = false`): Never sync to search

---

## 📂 Category & Brand APIs

### Category Management

#### Hierarchical Category Structure
```protobuf
rpc CreateCategory(CreateCategoryRequest) returns (CreateCategoryReply) {
  option (google.api.http) = {
    post: "/api/v1/catalog/categories"
    body: "*"
  };
}
```

**Category Structure:**
```json
{
  "name": "Electronics",
  "slug": "electronics",
  "description": "Electronic devices and accessories",
  "parent_id": null,
  "sort_order": 1,
  "is_active": true,
  "attribute_template": {
    "required_attributes": ["brand", "model", "warranty"],
    "optional_attributes": ["color", "weight", "dimensions"]
  }
}
```

**Features:**
- Hierarchical structure (parent-child relationships)
- URL slugs for SEO
- Sort ordering for display
- Attribute templates per category
- Status management (active/inactive)

### Brand & Manufacturer Management

#### Brand Management
```protobuf
rpc CreateBrand(CreateBrandRequest) returns (CreateBrandReply) {
  option (google.api.http) = {
    post: "/api/v1/catalog/brands"
    body: "*"
  };
}
```

**Brand Structure:**
```json
{
  "name": "Apple",
  "slug": "apple",
  "description": "Technology company",
  "logo_url": "https://example.com/apple-logo.png",
  "website_url": "https://apple.com",
  "sort_order": 1,
  "is_active": true,
  "metadata": {
    "country_of_origin": "USA",
    "founded_year": 1976
  }
}
```

---

## 🗄️ Database Schema

### Core Tables

#### products (Main product table)
```sql
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku VARCHAR(100) UNIQUE NOT NULL,
  name VARCHAR(500) NOT NULL,
  description TEXT,
  short_description VARCHAR(500),
  category_id UUID REFERENCES categories(id),
  brand_id UUID REFERENCES brands(id),
  manufacturer_id UUID REFERENCES manufacturers(id),
  status VARCHAR(20) DEFAULT 'draft',
  is_featured BOOLEAN DEFAULT FALSE,

  -- Tier 1: Hot attributes (fast queries)
  color VARCHAR(100),
  size VARCHAR(100),
  material VARCHAR(100),
  gender VARCHAR(20),
  age_group VARCHAR(20),
  weight DECIMAL(8,2),

  -- Tier 3: JSON storage (flexible content)
  specifications JSONB DEFAULT '{}',
  marketing_content JSONB DEFAULT '{}',

  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

#### product_attributes (EAV definitions)
```sql
CREATE TABLE product_attributes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(100) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL,
  is_required BOOLEAN DEFAULT FALSE,
  is_searchable BOOLEAN DEFAULT FALSE,
  is_filterable BOOLEAN DEFAULT FALSE,
  is_indexed BOOLEAN,
  options JSONB,
  validation_rules JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### product_attribute_values (EAV values)
```sql
CREATE TABLE product_attribute_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id),
  attribute_id UUID NOT NULL REFERENCES product_attributes(id),
  value_text TEXT,
  value_number DECIMAL,
  value_boolean BOOLEAN,
  value_date DATE,
  value_json JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, attribute_id)
);
```

### Performance Optimizations

#### Indexes for Products
```sql
-- Primary lookups
CREATE UNIQUE INDEX idx_products_sku ON products(sku) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_category ON products(category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_brand ON products(brand_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_status ON products(status) WHERE deleted_at IS NULL;

-- Hot attributes (Tier 1)
CREATE INDEX idx_products_color ON products(color) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_size ON products(size) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_gender_age ON products(gender, age_group) WHERE deleted_at IS NULL;

-- JSON indexes (Tier 3)
CREATE INDEX idx_products_specs_gin ON products USING gin(specifications);
CREATE INDEX idx_products_marketing_gin ON products USING gin(marketing_content);

-- Full-text search
CREATE INDEX idx_products_search ON products USING gin(to_tsvector('english', name || ' ' || description));
```

#### Indexes for EAV System
```sql
-- Attribute lookups
CREATE UNIQUE INDEX idx_product_attributes_code ON product_attributes(code);

-- Attribute values
CREATE INDEX idx_attribute_values_product ON product_attribute_values(product_id);
CREATE INDEX idx_attribute_values_attribute ON product_attribute_values(attribute_id);
CREATE INDEX idx_attribute_values_composite ON product_attribute_values(product_id, attribute_id);

-- JSON values (for complex queries)
CREATE INDEX idx_attribute_values_json_gin ON product_attribute_values USING gin(value_json) WHERE value_json IS NOT NULL;
```

#### Materialized Views
```sql
-- Product search view (refreshed every 5 minutes)
CREATE MATERIALIZED VIEW product_search_view_mv AS
SELECT
  p.id,
  p.sku,
  p.name,
  p.description,
  c.name as category_name,
  b.name as brand_name,
  p.status,
  p.is_featured,
  p.created_at
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN brands b ON p.brand_id = b.id
WHERE p.deleted_at IS NULL AND p.status = 'active';

-- Category statistics
CREATE MATERIALIZED VIEW product_category_stats_mv AS
SELECT
  category_id,
  COUNT(*) as product_count,
  AVG(price) as avg_price,
  MIN(price) as min_price,
  MAX(price) as max_price
FROM products
WHERE deleted_at IS NULL AND status = 'active'
GROUP BY category_id;
```

### Migration History

| Version | Migration File | Description | Key Features |
|---------|----------------|-------------|--------------|
| 001-007 | `001_create_products_table.sql` to `007_*` | Core schema creation | Products, categories, brands, basic EAV |
| 009 | `009_add_performance_indexes.sql` | Performance optimization | GIN indexes, composite indexes |
| 010 | `010_add_cms_support.sql` | CMS pages | Content management |
| 011 | `011_add_visibility_rules.sql` | Visibility controls | Age/geo/group restrictions |
| 012 | `012_add_materialized_views.sql` | Query optimization | Pre-computed aggregations |
| 013 | `013_add_bulk_operations.sql` | Bulk operations | Mass product updates |
| 014-025 | Various feature additions | Advanced features | Media, templates, enhanced EAV |

---

## 🧠 Business Logic

### Product Creation Flow

```go
func (uc *ProductUsecase) CreateProduct(ctx context.Context, req *CreateProductRequest) (*Product, error) {
    // 1. Validate SKU uniqueness
    // 2. Validate category/brand/manufacturer existence
    // 3. Validate Tier 1 attributes
    // 4. Start transaction
    // 5. Create product record with hot attributes
    // 6. Set Tier 2 EAV attributes if provided
    // 7. Set Tier 3 JSON content
    // 8. Apply visibility rules
    // 9. Publish product.created event
    // 10. Trigger search indexing
    // 11. Cache product data
    // 12. Return product with all attributes
}
```

### EAV Attribute Processing

```go
func (uc *ProductAttributeUsecase) SetProductAttributes(ctx context.Context, productID string, attributes map[string]interface{}) error {
    // 1. Validate attribute definitions exist
    // 2. Validate attribute values against rules
    // 3. Start transaction
    // 4. Delete existing attribute values for product
    // 5. Insert new attribute values
    // 6. Update product search index if needed
    // 7. Publish attribute.updated event
    // 8. Invalidate relevant caches
}
```

### Search Integration Logic

```go
func (uc *ProductUsecase) UpdateProduct(ctx context.Context, req *UpdateProductRequest) error {
    // 1. Get current product
    // 2. Apply updates
    // 3. Determine if search re-indexing needed
    // 4. Update product in database
    // 5. Publish product.updated event
    // 6. If re-indexing needed, publish to search service

    changes := map[string]interface{}{
        "name": req.Name != oldProduct.Name,
        "price": req.Price != oldProduct.Price,
        "attributes": attributesChanged,
    }

    if shouldReindex(changes) {
        uc.events.PublishCustom(ctx, "catalog.product.reindex", map[string]interface{}{
            "product_id": req.Id,
            "changes": changes,
        })
    }
}
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
CATALOG_DATABASE_DSN=postgres://catalog_user:catalog_pass@postgres:5432/catalog_db?sslmode=disable

# Redis
CATALOG_REDIS_ADDR=redis:6379
CATALOG_REDIS_DB=0

# Service Ports
CATALOG_HTTP_PORT=8001
CATALOG_GRPC_PORT=9001

# Search Integration
CATALOG_SEARCH_SERVICE_ADDR=search-service:9004
CATALOG_AUTO_REINDEX=true

# Event Publishing
CATALOG_EVENT_PUBLISHING_ENABLED=true
CATALOG_DAPR_PUBSUB_NAME=pubsub

# Caching
CATALOG_CACHE_TTL_PRODUCTS=300
CATALOG_CACHE_TTL_CATEGORIES=3600
CATALOG_CACHE_TTL_ATTRIBUTES=1800

# Features
CATALOG_ENABLE_BULK_OPERATIONS=true
CATALOG_ENABLE_VISIBILITY_RULES=true
CATALOG_ENABLE_CMS=true
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: catalog-service
  version: 1.0.0

database:
  dsn: ${CATALOG_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 25
  conn_max_lifetime: 5m

redis:
  addr: ${CATALOG_REDIS_ADDR}
  db: ${CATALOG_REDIS_DB}
  dial_timeout: 5s
  read_timeout: 3s
  write_timeout: 3s

server:
  http:
    addr: 0.0.0.0
    port: ${CATALOG_HTTP_PORT}
  grpc:
    addr: 0.0.0.0
    port: ${CATALOG_GRPC_PORT}

external_services:
  search_service: ${CATALOG_SEARCH_SERVICE_ADDR}
  warehouse_service: warehouse-service:9010
  pricing_service: pricing-service:9009

features:
  auto_reindex: ${CATALOG_AUTO_REINDEX}
  bulk_operations: ${CATALOG_ENABLE_BULK_OPERATIONS}
  visibility_rules: ${CATALOG_ENABLE_VISIBILITY_RULES}
  cms: ${CATALOG_ENABLE_CMS}

cache:
  products_ttl: ${CATALOG_CACHE_TTL_PRODUCTS}
  categories_ttl: ${CATALOG_CACHE_TTL_CATEGORIES}
  attributes_ttl: ${CATALOG_CACHE_TTL_ATTRIBUTES}

events:
  publishing_enabled: ${CATALOG_EVENT_PUBLISHING_ENABLED}
  dapr_pubsub_name: ${CATALOG_DAPR_PUBSUB_NAME}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/catalog

go 1.24

require (
    gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    github.com/google/uuid v1.6.0
    github.com/tidwall/gjson v1.17.0  // JSON processing
)
```

### Service Mesh Integration
```yaml
# Dapr pub/sub subscriptions
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: catalog-service-events
spec:
  topic: warehouse.inventory.stock_changed
  route: /events/stock-changed
  pubsubname: pubsub
---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: catalog-price-events
spec:
  topic: pricing.price.updated
  route: /events/price-updated
  pubsubname: pubsub
```

---

## 🧪 Testing

### Test Coverage
- **Unit Tests**: 70% coverage (business logic, EAV system)
- **Integration Tests**: 60% coverage (API endpoints, database)
- **E2E Tests**: 40% coverage (product creation to search indexing)

### Critical Test Scenarios

#### EAV System Tests
```go
func TestEAVAttributeLifecycle(t *testing.T) {
    // 1. Create attribute definition
    // 2. Set attribute value on product
    // 3. Update attribute definition
    // 4. Verify search re-indexing triggered
    // 5. Query products by attribute
    // 6. Delete attribute value
}

func TestAttributeSyncToSearch(t *testing.T) {
    // 1. Create product with searchable attributes
    // 2. Update attribute to non-searchable
    // 3. Verify search re-indexing event published
    // 4. Check search service received update
}
```

#### Product CRUD Tests
```go
func TestProductCreationWithAllTiers(t *testing.T) {
    // 1. Create product with Tier 1,2,3 attributes
    // 2. Verify database storage (columns + EAV tables + JSON)
    // 3. Verify event publishing
    // 4. Verify cache invalidation
    // 5. Verify search indexing
}
```

### Test Infrastructure
```bash
# Run all tests
make test

# Run integration tests (requires DB/Redis)
make test-integration

# Test EAV system specifically
make test-eav

# With coverage
make test-coverage

# Specific product tests
go test ./internal/biz/product/... -v
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### Product Metrics
```go
# Product operations
catalog_products_created_total{category="electronics"} 1250
catalog_products_updated_total 3400
catalog_products_deleted_total 45

# EAV operations
catalog_attributes_created_total 120
catalog_attribute_values_set_total 5600

# Search sync
catalog_search_sync_events_total 4500
catalog_search_reindex_triggered_total{reason="attribute_config"} 23
```

#### Performance Metrics
```go
# API response times
catalog_api_request_duration_seconds{endpoint="/api/v1/catalog/products", quantile="0.95"} 0.087
catalog_api_request_duration_seconds{endpoint="/api/v1/catalog/attributes", quantile="0.95"} 0.045

# Database performance
catalog_db_query_duration_seconds{table="products", operation="select", quantile="0.95"} 0.023
catalog_db_query_duration_seconds{table="product_attribute_values", operation="select", quantile="0.95"} 0.067

# Cache hit rates
catalog_cache_hit_ratio{cache="products"} 0.89
catalog_cache_hit_ratio{cache="attributes"} 0.94
```

### Health Checks
```go
# Application health
GET /api/v1/catalog/health

# Dependencies health
GET /api/v1/catalog/health/dependencies

# Database connectivity
# Redis connectivity
# External services (search, warehouse, pricing)
```

### Distributed Tracing (OpenTelemetry)

#### Product Creation Trace
```
Client → Gateway → Catalog Service
├── Validate product data
├── Check SKU uniqueness (Database)
├── Create product record (Database)
├── Set EAV attributes (Database)
├── Publish product.created event (Dapr)
├── Trigger search indexing (Search Service)
└── Cache product data (Redis)
```

#### Attribute Update Trace
```
Admin → Gateway → Catalog Service
├── Update attribute definition
├── Determine re-indexing needed
├── Get affected products (Database)
├── Publish re-indexing events (Dapr)
├── Update attribute (Database)
└── Update cache (Redis)
```

---

## 🚨 Known Issues & TODOs

### P2 - Medium Priority Issues

1. **Materialized View Refresh Scheduling** 🔵
   - **Issue**: Views refreshed every 5 minutes via cron, not event-driven
   - **Impact**: Stale statistics between refresh cycles
   - **Location**: `internal/worker/cron/`
   - **Fix**: Implement event-driven refresh for affected views

2. **Bulk Import Validation** 🔵
   - **Issue**: Bulk operations have basic validation, no rollback on partial failures
   - **Impact**: Inconsistent state after failed bulk imports
   - **Location**: `internal/biz/product/bulk.go`
   - **Fix**: Implement transactional bulk operations with proper error handling

3. **Image Upload Optimization** 🔵
   - **Issue**: Basic image upload, no resizing/optimization
   - **Impact**: Large images slow page loads
   - **Location**: `internal/service/product.go` UploadProductImage
   - **Fix**: Implement image processing pipeline (resize, compress, CDN)

4. **Category Template Enforcement** 🔵
   - **Issue**: Category attribute templates defined but not enforced
   - **Impact**: Inconsistent product data across categories
   - **Location**: Category template validation
   - **Fix**: Implement template validation on product creation/update

5. **Visibility Rule Performance** 🔵
   - **Issue**: Visibility rules evaluated on every product access
   - **Impact**: Performance overhead for rule evaluation
   - **Location**: `internal/biz/product_visibility_rule/`
   - **Fix**: Implement rule result caching with invalidation

---

## 🚀 Development Guide

### Local Development Setup
```bash
# Clone and setup
git clone git@gitlab.com:ta-microservices/catalog.git
cd catalog

# Start dependencies
docker-compose up -d postgres redis

# Install dependencies
go mod download

# Run migrations
make migrate-up

# Generate protobuf code
make api

# Run service
make run

# Test product creation
curl -X POST http://localhost:8001/api/v1/catalog/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","sku":"TEST-001","category_id":"test-cat","status":"active"}'
```

### Code Generation
```bash
# Generate protobuf code + OpenAPI
make api

# Generate protobuf only
make proto-gen

# Generate OpenAPI spec only
make proto-gen-openapi

# Enhance OpenAPI spec
make swagger
```

### Database Operations
```bash
# Create new migration
make migrate-create NAME="add_product_tags"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

### EAV System Development Workflow
1. **Define Attribute**: Create attribute definition via API
2. **Update Proto**: Add attribute to product message if Tier 1
3. **Generate Code**: `make api`
4. **Implement Logic**: Add processing in biz layer
5. **Add Tests**: Unit tests for attribute processing
6. **Update Documentation**: Attribute sync behavior

### Testing EAV Features
```bash
# Test attribute system
make test-eav

# Test product with all attribute tiers
make test-product-full

# Test search integration
make test-search-sync

# Load testing
hey -n 1000 -c 10 -m GET \
  http://localhost:8001/api/v1/catalog/products?category=electronics&page=1&limit=20
```

---

## 📈 Performance Benchmarks

### API Response Times (P95)
- **List Products**: 87ms (with complex filters)
- **Get Product**: 34ms (with all attributes)
- **Create Product**: 120ms (with EAV attributes)
- **Search Products**: 67ms (full-text search)
- **List Attributes**: 23ms (with pagination)

### Throughput Targets
- **Read Operations**: 500 req/sec sustained
- **Product Creation**: 100 req/sec peak
- **Search Operations**: 200 req/sec sustained

### Database Performance
- **Product Queries**: <20ms average (with indexes)
- **EAV Queries**: <50ms average (with GIN indexes)
- **Bulk Operations**: <200ms for 100 products

### Caching Strategy
- **Products**: Redis TTL 5 minutes
- **Categories/Brands**: Redis TTL 1 hour
- **Attributes**: Redis TTL 30 minutes
- **Search Results**: Redis TTL 10 minutes

---

## 🔐 Security Considerations

### Data Protection
- **Input Validation**: Strict validation for all product data
- **SQL Injection Prevention**: Parameterized queries, GORM protection
- **XSS Prevention**: Sanitization for product descriptions
- **Access Control**: Attribute-level visibility rules

### API Security
- **Authentication**: JWT token validation via Gateway
- **Authorization**: Role-based access for admin operations
- **Rate Limiting**: Implemented at Gateway level
- **Audit Logging**: All product changes logged

### Content Security
- **Image Upload**: File type validation, size limits
- **Rich Content**: HTML sanitization for CMS pages
- **Attribute Validation**: Type-safe attribute value storage
- **Soft Deletes**: Data retention without exposure

---

## 🎯 Future Roadmap

### Phase 1 (Q1 2026) - Performance & Scale
- [ ] Implement event-driven materialized view refresh
- [ ] Add Redis cluster support for caching
- [ ] Optimize EAV queries with better indexing
- [ ] Implement product data partitioning

### Phase 2 (Q2 2026) - Advanced Features
- [ ] AI-powered product categorization
- [ ] Advanced image processing and CDN integration
- [ ] Multi-language product content support
- [ ] Advanced product recommendation engine
- [ ] Real-time inventory sync improvements

### Phase 3 (Q3 2026) - Intelligence & Automation
- [ ] Machine learning for product attribute extraction
- [ ] Automated product data quality checks
- [ ] Predictive product performance analytics
- [ ] Auto-generated product descriptions and tags

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: Catalog Service Team
- **Repository**: `gitlab.com/ta-microservices/catalog`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #catalog-service-alerts
- **Performance Issues**: #catalog-service-performance
- **EAV Issues**: #attribute-system
- **Search Issues**: #catalog-search

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/catalog-service`
- **EAV Analytics**: `https://grafana.tanhdev.com/d/catalog-eav`
- **Search Integration**: `https://grafana.tanhdev.com/d/catalog-search`
- **Business Metrics**: `https://grafana.tanhdev.com/d/catalog-business`

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Code Review Status**: ✅ Reviewed (Production Ready)  
**Production Readiness**: 95% (Minor performance optimizations needed)
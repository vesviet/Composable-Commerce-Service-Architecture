# Go Kratos Microservice Template

## Overview
Production-ready Go microservice template based on **go-kratos/kratos** framework, following the e-commerce platform architecture patterns with clean architecture principles and integrated with Consul for service discovery and permission management.

## Tech Stack
- **Runtime**: Go 1.21+
- **Framework**: Kratos (go-kratos/kratos) - Cloud-native microservice framework
- **Protocol**: gRPC + HTTP/REST dual protocol support
- **Database**: PostgreSQL with GORM
- **Service Discovery**: Consul with health checks
- **Configuration**: Kratos Config with multiple sources (file, env, consul)
- **Messaging**: Kafka with Kratos message queue integration
- **Caching**: Redis with Kratos cache abstraction
- **Monitoring**: Prometheus + Jaeger tracing + Kratos metrics
- **Logging**: Kratos structured logging with multiple outputs
- **Testing**: Kratos testing framework + testify
- **Documentation**: Protobuf + OpenAPI generation
- **Security**: Consul-based service permission matrix + JWT

## Kratos Project Structure
```
go-kratos-service/
├── cmd/
│   └── server/                    # Application entry point
│       ├── main.go               # Main entry with Kratos app
│       ├── wire.go               # Dependency injection with Wire
│       └── wire_gen.go           # Generated Wire code
├── internal/                      # Private application code
│   ├── conf/                     # Configuration definitions
│   │   ├── conf.proto            # Configuration protobuf
│   │   └── conf.pb.go            # Generated config
│   ├── data/                     # Data access layer
│   │   ├── data.go               # Data providers
│   │   ├── product.go            # Product repository implementation
│   │   └── consul.go             # Consul integration
│   ├── biz/                      # Business logic layer
│   │   ├── biz.go                # Business providers
│   │   ├── product.go            # Product business logic
│   │   └── consul_permission.go  # Consul permission logic
│   ├── service/                  # Service layer (gRPC/HTTP handlers)
│   │   ├── service.go            # Service providers
│   │   ├── product.go            # Product service implementation
│   │   └── health.go             # Health check service
│   └── server/                   # Server configurations
│       ├── server.go             # Server providers
│       ├── grpc.go               # gRPC server setup
│       ├── http.go               # HTTP server setup
│       └── consul.go             # Consul registration
├── api/                          # API definitions (protobuf)
│   └── catalog/
│       └── v1/
│           ├── catalog.proto     # Service API definition
│           ├── catalog.pb.go     # Generated Go code
│           ├── catalog_grpc.pb.go # Generated gRPC code
│           └── catalog_http.pb.go # Generated HTTP code
├── third_party/                  # Third-party protobuf files
│   ├── google/
│   ├── validate/
│   └── openapi/
├── configs/                      # Configuration files
│   ├── config.yaml              # Default configuration
│   ├── config-dev.yaml          # Development config
│   └── config-prod.yaml         # Production config
├── pkg/                          # Public library code
│   ├── consul/                   # Consul utilities
│   │   ├── client.go
│   │   ├── discovery.go
│   │   └── permission.go
│   ├── middleware/               # Custom middleware
│   │   ├── auth.go
│   │   ├── consul_auth.go
│   │   └── tracing.go
│   └── errors/                   # Error definitions
│       └── errors.go
├── scripts/                      # Utility scripts
│   ├── generate.sh              # Protobuf generation
│   ├── migrate.sh               # Database migrations
│   └── consul-setup.sh          # Consul setup
├── deployments/                  # Deployment configurations
│   ├── docker/
│   │   ├── Dockerfile
│   │   └── docker-compose.yml
│   ├── k8s/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── consul-config.yaml
│   └── consul/
│       ├── service-config.json
│       └── permissions.json
├── test/                         # Test files
│   ├── integration/
│   ├── unit/
│   └── mocks/
├── docs/                         # Documentation
│   ├── api.md                   # API documentation
│   └── consul-integration.md    # Consul integration guide
├── go.mod
├── go.sum
├── Makefile
├── kratos.yaml                   # Kratos project config
├── buf.yaml                      # Buf configuration for protobuf
├── buf.gen.yaml                  # Buf generation config
└── README.md
```

## Quick Start

### 1. Prerequisites
```bash
# Install Kratos CLI
go install github.com/go-kratos/kratos/cmd/kratos/v2@latest

# Install protobuf tools
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
go install github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2@latest

# Install Wire for dependency injection
go install github.com/google/wire/cmd/wire@latest
```

### 2. Create New Service
```bash
# Create from template
kratos new my-catalog-service -r https://github.com/go-kratos/kratos-layout.git
cd my-catalog-service

# Or copy this template
cp -r go-kratos-service my-catalog-service
cd my-catalog-service

# Initialize Go module
go mod init github.com/ecommerce/my-catalog-service
go mod tidy
```

### 3. Setup Infrastructure
```bash
# Start Consul, PostgreSQL, Redis, Kafka
docker-compose up -d

# Setup Consul permissions
./scripts/consul-setup.sh

# Run database migrations
make migrate-up
```

### 4. Generate Code
```bash
# Generate protobuf code
make generate

# Generate Wire dependency injection
make wire

# Generate OpenAPI documentation
make openapi
```

### 5. Start Development
```bash
# Start in development mode
make run

# Service will be available at:
# - gRPC: localhost:9000
# - HTTP: localhost:8000
# - Health: localhost:8000/health
# - Metrics: localhost:8000/metrics
```

## Core Components

### 1. Main Entry Point (cmd/server/main.go)
```go
package main

import (
    "context"
    "flag"
    "os"

    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/config"
    "github.com/go-kratos/kratos/v2/config/file"
    "github.com/go-kratos/kratos/v2/config/env"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/go-kratos/kratos/v2/registry"
    "github.com/go-kratos/kratos/v2/transport/grpc"
    "github.com/go-kratos/kratos/v2/transport/http"

    "github.com/ecommerce/my-catalog-service/internal/conf"
    "github.com/ecommerce/my-catalog-service/pkg/consul"
)

var (
    Name    string = "catalog-service"
    Version string = "v1.0.0"
    flagconf string
    id, _   = os.Hostname()
)

func init() {
    flag.StringVar(&flagconf, "conf", "../../configs", "config path")
}

func newApp(logger log.Logger, gs *grpc.Server, hs *http.Server, rr registry.Registrar) *kratos.App {
    return kratos.New(
        kratos.ID(id),
        kratos.Name(Name),
        kratos.Version(Version),
        kratos.Logger(logger),
        kratos.Server(gs, hs),
        kratos.Registrar(rr),
    )
}

func main() {
    flag.Parse()
    
    // Initialize structured logger
    logger := log.With(log.NewStdLogger(os.Stdout),
        "ts", log.DefaultTimestamp,
        "caller", log.DefaultCaller,
        "service.id", id,
        "service.name", Name,
        "service.version", Version,
    )

    // Load configuration from multiple sources
    c := config.New(
        config.WithSource(
            file.NewSource(flagconf),
            env.NewSource("CATALOG_"),
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

    // Initialize Consul registry with service discovery
    consulClient, err := consul.NewClient(bc.Consul)
    if err != nil {
        panic(err)
    }

    r := consul.NewRegistry(consulClient)

    // Initialize application with Wire dependency injection
    app, cleanup, err := wireApp(bc.Server, bc.Data, bc.Consul, logger, r)
    if err != nil {
        panic(err)
    }
    defer cleanup()

    // Start application with graceful shutdown
    if err := app.Run(); err != nil {
        panic(err)
    }
}
```

### 2. Configuration (internal/conf/conf.proto)
```protobuf
syntax = "proto3";
package kratos.api;

option go_package = "github.com/ecommerce/my-catalog-service/internal/conf;conf";

import "google/protobuf/duration.proto";

message Bootstrap {
  Server server = 1;
  Data data = 2;
  Consul consul = 3;
  Trace trace = 4;
}

message Server {
  message HTTP {
    string network = 1;
    string addr = 2;
    google.protobuf.Duration timeout = 3;
  }
  message GRPC {
    string network = 1;
    string addr = 2;
    google.protobuf.Duration timeout = 3;
  }
  HTTP http = 1;
  GRPC grpc = 2;
}

message Data {
  message Database {
    string driver = 1;
    string source = 2;
  }
  message Redis {
    string network = 1;
    string addr = 2;
    string password = 3;
    int32 db = 4;
    google.protobuf.Duration dial_timeout = 5;
    google.protobuf.Duration read_timeout = 6;
    google.protobuf.Duration write_timeout = 7;
  }
  message Kafka {
    repeated string brokers = 1;
    string group_id = 2;
  }
  Database database = 1;
  Redis redis = 2;
  Kafka kafka = 3;
}

message Consul {
  string address = 1;
  string scheme = 2;
  string datacenter = 3;
  bool health_check = 4;
  google.protobuf.Duration health_check_interval = 5;
  google.protobuf.Duration health_check_timeout = 6;
  bool deregister_critical_service_after = 7;
  google.protobuf.Duration deregister_critical_service_after_duration = 8;
}

message Trace {
  string endpoint = 1;
}
```

### 3. Configuration File (configs/config.yaml)
```yaml
server:
  http:
    addr: 0.0.0.0:8000
    timeout: 1s
  grpc:
    addr: 0.0.0.0:9000
    timeout: 1s

data:
  database:
    driver: postgres
    source: postgres://user:password@localhost:5432/catalog_db?sslmode=disable
  redis:
    addr: localhost:6379
    password: ""
    db: 0
    dial_timeout: 1s
    read_timeout: 0.2s
    write_timeout: 0.2s
  kafka:
    brokers:
      - localhost:9092
    group_id: catalog-service-group

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
```

### 4. API Definition (api/catalog/v1/catalog.proto)
```protobuf
syntax = "proto3";

package api.catalog.v1;

option go_package = "github.com/ecommerce/my-catalog-service/api/catalog/v1;v1";

import "google/api/annotations.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";
import "validate/validate.proto";

// Catalog service definition
service CatalogService {
  // Get products with pagination and filtering
  rpc GetProducts(GetProductsRequest) returns (GetProductsResponse) {
    option (google.api.http) = {
      get: "/api/v1/products"
    };
  }

  // Get product by ID
  rpc GetProduct(GetProductRequest) returns (Product) {
    option (google.api.http) = {
      get: "/api/v1/products/{id}"
    };
  }

  // Create new product
  rpc CreateProduct(CreateProductRequest) returns (Product) {
    option (google.api.http) = {
      post: "/api/v1/products"
      body: "*"
    };
  }

  // Update existing product
  rpc UpdateProduct(UpdateProductRequest) returns (Product) {
    option (google.api.http) = {
      put: "/api/v1/products/{id}"
      body: "*"
    };
  }

  // Delete product
  rpc DeleteProduct(DeleteProductRequest) returns (google.protobuf.Empty) {
    option (google.api.http) = {
      delete: "/api/v1/products/{id}"
    };
  }

  // Health check
  rpc Health(google.protobuf.Empty) returns (HealthResponse) {
    option (google.api.http) = {
      get: "/health"
    };
  }
}

// Product message
message Product {
  string id = 1;
  string sku = 2 [(validate.rules).string.min_len = 1];
  string name = 3 [(validate.rules).string.min_len = 1];
  string description = 4;
  string slug = 5;
  string category_id = 6;
  string brand_id = 7;
  map<string, string> attributes = 8;
  ProductStatus status = 9;
  bool is_visible = 10;
  bool is_featured = 11;
  google.protobuf.Timestamp created_at = 12;
  google.protobuf.Timestamp updated_at = 13;
  string created_by = 14;
  string updated_by = 15;
  
  // Relations
  Category category = 16;
  Brand brand = 17;
  repeated Media media = 18;
}

// Product status enum
enum ProductStatus {
  PRODUCT_STATUS_UNSPECIFIED = 0;
  PRODUCT_STATUS_DRAFT = 1;
  PRODUCT_STATUS_ACTIVE = 2;
  PRODUCT_STATUS_INACTIVE = 3;
  PRODUCT_STATUS_DISCONTINUED = 4;
}

// Category message
message Category {
  string id = 1;
  string name = 2;
  string slug = 3;
  string description = 4;
  string parent_id = 5;
  bool is_visible = 6;
  int32 sort_order = 7;
  google.protobuf.Timestamp created_at = 8;
  google.protobuf.Timestamp updated_at = 9;
}

// Brand message
message Brand {
  string id = 1;
  string name = 2;
  string slug = 3;
  string description = 4;
  string logo_url = 5;
  string website_url = 6;
  bool is_active = 7;
  google.protobuf.Timestamp created_at = 8;
  google.protobuf.Timestamp updated_at = 9;
}

// Media message
message Media {
  string id = 1;
  string product_id = 2;
  MediaType type = 3;
  string url = 4;
  string alt_text = 5;
  string title = 6;
  int32 sort_order = 7;
  bool is_primary = 8;
  google.protobuf.Timestamp created_at = 9;
  google.protobuf.Timestamp updated_at = 10;
}

// Media type enum
enum MediaType {
  MEDIA_TYPE_UNSPECIFIED = 0;
  MEDIA_TYPE_IMAGE = 1;
  MEDIA_TYPE_VIDEO = 2;
  MEDIA_TYPE_DOCUMENT = 3;
}

// Request/Response messages
message GetProductsRequest {
  int32 page = 1 [(validate.rules).int32.gte = 1];
  int32 limit = 2 [(validate.rules).int32 = {gte: 1, lte: 100}];
  string search = 3;
  string category = 4;
  string customer_id = 5; // For personalization
}

message GetProductsResponse {
  repeated Product products = 1;
  int32 total = 2;
  int32 page = 3;
  int32 limit = 4;
  int32 total_pages = 5;
}

message GetProductRequest {
  string id = 1 [(validate.rules).string.min_len = 1];
  string customer_id = 2; // For personalization
}

message CreateProductRequest {
  string sku = 1 [(validate.rules).string.min_len = 1];
  string name = 2 [(validate.rules).string.min_len = 1];
  string description = 3;
  string category_id = 4 [(validate.rules).string.min_len = 1];
  string brand_id = 5 [(validate.rules).string.min_len = 1];
  map<string, string> attributes = 6;
  ProductStatus status = 7;
  bool is_visible = 8;
  bool is_featured = 9;
}

message UpdateProductRequest {
  string id = 1 [(validate.rules).string.min_len = 1];
  string name = 2;
  string description = 3;
  string category_id = 4;
  string brand_id = 5;
  map<string, string> attributes = 6;
  ProductStatus status = 7;
  bool is_visible = 8;
  bool is_featured = 9;
}

message DeleteProductRequest {
  string id = 1 [(validate.rules).string.min_len = 1];
}

message HealthResponse {
  string status = 1;
  google.protobuf.Timestamp timestamp = 2;
  string service = 3;
  string version = 4;
  string uptime = 5;
}
```

### 5. Wire Dependency Injection (cmd/server/wire.go)
```go
//go:build wireinject
// +build wireinject

package main

import (
    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/go-kratos/kratos/v2/registry"
    "github.com/google/wire"

    "github.com/ecommerce/my-catalog-service/internal/biz"
    "github.com/ecommerce/my-catalog-service/internal/conf"
    "github.com/ecommerce/my-catalog-service/internal/data"
    "github.com/ecommerce/my-catalog-service/internal/server"
    "github.com/ecommerce/my-catalog-service/internal/service"
)

// wireApp init kratos application.
func wireApp(*conf.Server, *conf.Data, *conf.Consul, log.Logger, registry.Registrar) (*kratos.App, func(), error) {
    panic(wire.Build(
        server.ProviderSet,
        data.ProviderSet,
        biz.ProviderSet,
        service.ProviderSet,
        newApp,
    ))
}
```

### 6. Business Logic Layer (internal/biz/product.go)
```go
package biz

import (
    "context"
    "github.com/go-kratos/kratos/v2/log"
)

// Product domain entity
type Product struct {
    ID          string
    SKU         string
    Name        string
    Description string
    CategoryID  string
    BrandID     string
    Status      ProductStatus
    IsVisible   bool
    IsFeatured  bool
    // ... other fields
}

type ProductStatus int32

const (
    ProductStatusDraft ProductStatus = iota
    ProductStatusActive
    ProductStatusInactive
    ProductStatusDiscontinued
)

// ProductRepo interface for data access
type ProductRepo interface {
    Save(context.Context, *Product) (*Product, error)
    Update(context.Context, *Product) (*Product, error)
    FindByID(context.Context, string) (*Product, error)
    ListProducts(context.Context, *ProductFilter) ([]*Product, int32, error)
    Delete(context.Context, string) error
}

// ConsulPermissionRepo interface for permission management
type ConsulPermissionRepo interface {
    ValidateServiceCall(ctx context.Context, fromService, toService, method, path string) error
    LoadServicePermissions(ctx context.Context, fromService, toService string) (*ServicePermission, error)
}

// ProductUsecase business logic
type ProductUsecase struct {
    repo       ProductRepo
    consulRepo ConsulPermissionRepo
    log        *log.Helper
}

func NewProductUsecase(repo ProductRepo, consulRepo ConsulPermissionRepo, logger log.Logger) *ProductUsecase {
    return &ProductUsecase{
        repo:       repo,
        consulRepo: consulRepo,
        log:        log.NewHelper(logger),
    }
}

func (uc *ProductUsecase) CreateProduct(ctx context.Context, p *Product) (*Product, error) {
    uc.log.WithContext(ctx).Infof("Creating product: %s", p.Name)
    return uc.repo.Save(ctx, p)
}

func (uc *ProductUsecase) GetProduct(ctx context.Context, id string) (*Product, error) {
    return uc.repo.FindByID(ctx, id)
}

func (uc *ProductUsecase) ListProducts(ctx context.Context, filter *ProductFilter) ([]*Product, int32, error) {
    return uc.repo.ListProducts(ctx, filter)
}

func (uc *ProductUsecase) UpdateProduct(ctx context.Context, p *Product) (*Product, error) {
    return uc.repo.Update(ctx, p)
}

func (uc *ProductUsecase) DeleteProduct(ctx context.Context, id string) error {
    return uc.repo.Delete(ctx, id)
}
```

### 7. Service Layer (internal/service/product.go)
```go
package handlers

import (
    "net/http"
    "strconv"

    "github.com/ecommerce/my-catalog-service/internal/application/dto"
    "github.com/ecommerce/my-catalog-service/internal/application/services"
    "github.com/ecommerce/my-catalog-service/pkg/errors"
    "github.com/gin-gonic/gin"
    "github.com/sirupsen/logrus"
)

type ProductHandler struct {
    productService *services.ProductService
    logger         *logrus.Logger
}

func NewProductHandler(productService *services.ProductService, logger *logrus.Logger) *ProductHandler {
    return &ProductHandler{
        productService: productService,
        logger:         logger,
    }
}

// GetProducts godoc
// @Summary Get products list
// @Description Get products with pagination and filtering
// @Tags products
// @Accept json
// @Produce json
// @Param page query int false "Page number" default(1)
// @Param limit query int false "Items per page" default(10)
// @Param search query string false "Search term"
// @Param category query string false "Category filter"
// @Success 200 {object} dto.ProductListResponse
// @Failure 400 {object} dto.ErrorResponse
// @Failure 500 {object} dto.ErrorResponse
// @Router /api/v1/products [get]
func (h *ProductHandler) GetProducts(c *gin.Context) {
    // Parse query parameters
    page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
    limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
    search := c.Query("search")
    category := c.Query("category")

    // Validate parameters
    if page < 1 {
        page = 1
    }
    if limit < 1 || limit > 100 {
        limit = 10
    }

    // Create request DTO
    req := &dto.GetProductsRequest{
        Page:     page,
        Limit:    limit,
        Search:   search,
        Category: category,
    }

    // Call service
    response, err := h.productService.GetProducts(c.Request.Context(), req)
    if err != nil {
        h.logger.WithError(err).Error("Failed to get products")
        c.JSON(http.StatusInternalServerError, dto.ErrorResponse{
            Error:   "Internal server error",
            Message: "Failed to retrieve products",
        })
        return
    }

    
    product := &biz.Product{
        SKU:         req.Sku,
        Name:        req.Name,
        Description: req.Description,
        CategoryID:  req.CategoryId,
        BrandID:     req.BrandId,
        Status:      biz.ProductStatus(req.Status),
        IsVisible:   req.IsVisible,
        IsFeatured:  req.IsFeatured,
    }
    
    created, err := s.uc.CreateProduct(ctx, product)
    if err != nil {
        return nil, err
    }
    
    return s.convertProductToPB(created), nil
}

func (s *ProductService) UpdateProduct(ctx context.Context, req *pb.UpdateProductRequest) (*pb.Product, error) {
    s.log.WithContext(ctx).Infof("UpdateProduct: id=%s", req.Id)
    
    product := &biz.Product{
        ID:          req.Id,
        Name:        req.Name,
        Description: req.Description,
        CategoryID:  req.CategoryId,
        BrandID:     req.BrandId,
        Status:      biz.ProductStatus(req.Status),
        IsVisible:   req.IsVisible,
        IsFeatured:  req.IsFeatured,
    }
    
    updated, err := s.uc.UpdateProduct(ctx, product)
    if err != nil {
        return nil, err
    }
    
    return s.convertProductToPB(updated), nil
}

func (s *ProductService) DeleteProduct(ctx context.Context, req *pb.DeleteProductRequest) (*emptypb.Empty, error) {
    s.log.WithContext(ctx).Infof("DeleteProduct: id=%s", req.Id)
    
    err := s.uc.DeleteProduct(ctx, req.Id)
    if err != nil {
        return nil, err
    }
    
    return &emptypb.Empty{}, nil
}

func (s *ProductService) Health(ctx context.Context, req *emptypb.Empty) (*pb.HealthResponse, error) {
    return &pb.HealthResponse{
        Status:  "healthy",
        Service: "catalog-service",
        Version: "v1.0.0",
    }, nil
}

// Helper method to convert domain entity to protobuf message
func (s *ProductService) convertProductToPB(p *biz.Product) *pb.Product {
    return &pb.Product{
        Id:          p.ID,
        Sku:         p.SKU,
        Name:        p.Name,
        Description: p.Description,
        CategoryId:  p.CategoryID,
        BrandId:     p.BrandID,
        Status:      pb.ProductStatus(p.Status),
        IsVisible:   p.IsVisible,
        IsFeatured:  p.IsFeatured,
        // Add other fields as needed
    }
}
```

### 8. Data Layer with Consul Integration (internal/data/product.go)
```go
package data

import (
    "context"
    "fmt"

    "github.com/go-kratos/kratos/v2/log"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"

    "github.com/ecommerce/my-catalog-service/internal/biz"
    "github.com/ecommerce/my-catalog-service/internal/conf"
    "github.com/ecommerce/my-catalog-service/pkg/consul"
)

// Data struct holds all data dependencies
type Data struct {
    db           *gorm.DB
    consulClient *consul.Client
    log          *log.Helper
}

// NewData creates a new Data instance
func NewData(c *conf.Data, consulConf *conf.Consul, logger log.Logger) (*Data, func(), error) {
    helper := log.NewHelper(logger)
    
    // Initialize database
    db, err := gorm.Open(postgres.Open(c.Database.Source), &gorm.Config{})
    if err != nil {
        return nil, nil, fmt.Errorf("failed to connect database: %w", err)
    }
    
    // Initialize Consul client
    consulClient, err := consul.NewClient(consulConf)
    if err != nil {
        return nil, nil, fmt.Errorf("failed to connect consul: %w", err)
    }
    
    // Auto migrate database schema
    if err := db.AutoMigrate(&Product{}, &Category{}, &Brand{}, &Media{}); err != nil {
        return nil, nil, fmt.Errorf("failed to migrate database: %w", err)
    }
    
    d := &Data{
        db:           db,
        consulClient: consulClient,
        log:          helper,
    }
    
    cleanup := func() {
        helper.Info("closing the data resources")
        if sqlDB, err := db.DB(); err == nil {
            sqlDB.Close()
        }
    }
    
    return d, cleanup, nil
}

// Product data model
type Product struct {
    ID          string `gorm:"primaryKey"`
    SKU         string `gorm:"uniqueIndex;not null"`
    Name        string `gorm:"not null"`
    Description string
    CategoryID  string
    BrandID     string
    Status      int32
    IsVisible   bool
    IsFeatured  bool
    CreatedAt   int64
    UpdatedAt   int64
    CreatedBy   string
    UpdatedBy   string
}

// ProductRepo implements biz.ProductRepo
type productRepo struct {
    data *Data
    log  *log.Helper
}

func NewProductRepo(data *Data, logger log.Logger) biz.ProductRepo {
    return &productRepo{
        data: data,
        log:  log.NewHelper(logger),
    }
}

func (r *productRepo) Save(ctx context.Context, p *biz.Product) (*biz.Product, error) {
    product := &Product{
        SKU:         p.SKU,
        Name:        p.Name,
        Description: p.Description,
        CategoryID:  p.CategoryID,
        BrandID:     p.BrandID,
        Status:      int32(p.Status),
        IsVisible:   p.IsVisible,
        IsFeatured:  p.IsFeatured,
        CreatedBy:   p.CreatedBy,
    }
    
    if err := r.data.db.WithContext(ctx).Create(product).Error; err != nil {
        return nil, err
    }
    
    return r.convertToBiz(product), nil
}

func (r *productRepo) Update(ctx context.Context, p *biz.Product) (*biz.Product, error) {
    product := &Product{
        ID:          p.ID,
        Name:        p.Name,
        Description: p.Description,
        CategoryID:  p.CategoryID,
        BrandID:     p.BrandID,
        Status:      int32(p.Status),
        IsVisible:   p.IsVisible,
        IsFeatured:  p.IsFeatured,
        UpdatedBy:   p.UpdatedBy,
    }
    
    if err := r.data.db.WithContext(ctx).Save(product).Error; err != nil {
        return nil, err
    }
    
    return r.convertToBiz(product), nil
}

func (r *productRepo) FindByID(ctx context.Context, id string) (*biz.Product, error) {
    var product Product
    if err := r.data.db.WithContext(ctx).First(&product, "id = ?", id).Error; err != nil {
        return nil, err
    }
    
    return r.convertToBiz(&product), nil
}

func (r *productRepo) ListProducts(ctx context.Context, filter *biz.ProductFilter) ([]*biz.Product, int32, error) {
    var products []Product
    var total int64
    
    query := r.data.db.WithContext(ctx).Model(&Product{})
    
    // Apply filters
    if filter.Search != "" {
        query = query.Where("name ILIKE ? OR description ILIKE ?", 
            "%"+filter.Search+"%", "%"+filter.Search+"%")
    }
    
    if filter.Category != "" {
        query = query.Where("category_id = ?", filter.Category)
    }
    
    // Count total
    if err := query.Count(&total).Error; err != nil {
        return nil, 0, err
    }
    
    // Apply pagination
    offset := (filter.Page - 1) * filter.Limit
    if err := query.Offset(int(offset)).Limit(int(filter.Limit)).Find(&products).Error; err != nil {
        return nil, 0, err
    }
    
    // Convert to business entities
    bizProducts := make([]*biz.Product, len(products))
    for i, p := range products {
        bizProducts[i] = r.convertToBiz(&p)
    }
    
    return bizProducts, int32(total), nil
}

func (r *productRepo) Delete(ctx context.Context, id string) error {
    return r.data.db.WithContext(ctx).Delete(&Product{}, "id = ?", id).Error
}

func (r *productRepo) convertToBiz(p *Product) *biz.Product {
    return &biz.Product{
        ID:          p.ID,
        SKU:         p.SKU,
        Name:        p.Name,
        Description: p.Description,
        CategoryID:  p.CategoryID,
        BrandID:     p.BrandID,
        Status:      biz.ProductStatus(p.Status),
        IsVisible:   p.IsVisible,
        IsFeatured:  p.IsFeatured,
        CreatedBy:   p.CreatedBy,
        UpdatedBy:   p.UpdatedBy,
    }
}
```

### 9. Consul Integration (pkg/consul/client.go)
```go
package consul

import (
    "context"
    "fmt"
    "time"

    "github.com/go-kratos/kratos/v2/registry"
    "github.com/hashicorp/consul/api"
    
    "github.com/ecommerce/my-catalog-service/internal/conf"
)

// Client wraps Consul API client
type Client struct {
    client *api.Client
    config *conf.Consul
}

// NewClient creates a new Consul client
func NewClient(c *conf.Consul) (*Client, error) {
    config := api.DefaultConfig()
    config.Address = c.Address
    config.Scheme = c.Scheme
    config.Datacenter = c.Datacenter
    
    client, err := api.NewClient(config)
    if err != nil {
        return nil, err
    }
    
    return &Client{
        client: client,
        config: c,
    }, nil
}

// Registry creates a Consul registry for service discovery
func NewRegistry(client *Client) registry.Registrar {
    return &consulRegistry{
        client: client,
    }
}

type consulRegistry struct {
    client *Client
}

func (r *consulRegistry) Register(ctx context.Context, si *registry.ServiceInstance) error {
    return r.client.RegisterService(ctx, si)
}

func (r *consulRegistry) Deregister(ctx context.Context, si *registry.ServiceInstance) error {
    return r.client.DeregisterService(ctx, si)
}

// RegisterService registers a service with Consul
func (c *Client) RegisterService(ctx context.Context, si *registry.ServiceInstance) error {
    registration := &api.AgentServiceRegistration{
        ID:      si.ID,
        Name:    si.Name,
        Address: si.Endpoints[0], // Assuming first endpoint is the address
        Port:    8000, // Extract port from endpoint
        Tags:    []string{si.Version, "kratos", "microservice"},
        Meta: map[string]string{
            "version":     si.Version,
            "framework":   "kratos",
            "protocol":    "grpc+http",
        },
    }
    
    // Add health check if enabled
    if c.config.HealthCheck {
        registration.Check = &api.AgentServiceCheck{
            HTTP:                           fmt.Sprintf("http://%s/health", registration.Address),
            Interval:                       c.config.HealthCheckInterval.String(),
            Timeout:                        c.config.HealthCheckTimeout.String(),
            DeregisterCriticalServiceAfter: c.config.DeregisterCriticalServiceAfterDuration.String(),
        }
    }
    
    return c.client.Agent().ServiceRegister(registration)
}

// DeregisterService deregisters a service from Consul
func (c *Client) DeregisterService(ctx context.Context, si *registry.ServiceInstance) error {
    return c.client.Agent().ServiceDeregister(si.ID)
}

// LoadServicePermissions loads service permissions from Consul KV
func (c *Client) LoadServicePermissions(ctx context.Context, fromService, toService string) (*ServicePermission, error) {
    key := fmt.Sprintf("service-permissions/%s/%s", fromService, toService)
    
    kvPair, _, err := c.client.KV().Get(key, nil)
    if err != nil {
        return nil, err
    }
    
    if kvPair == nil {
        return nil, fmt.Errorf("no permissions found for %s -> %s", fromService, toService)
    }
    
    var permission ServicePermission
    if err := json.Unmarshal(kvPair.Value, &permission); err != nil {
        return nil, err
    }
    
    return &permission, nil
}

// ServicePermission represents service-to-service permissions
type ServicePermission struct {
    Permissions     []string       `json:"permissions"`
    Endpoints       []EndpointRule `json:"endpoints"`
    DeniedEndpoints []EndpointRule `json:"denied_endpoints"`
    RateLimit       int            `json:"rate_limit"`
    Timeout         string         `json:"timeout"`
    RetryAttempts   int            `json:"retry_attempts"`
    Description     string         `json:"description"`
}

type EndpointRule struct {
    Path    string   `json:"path"`
    Methods []string `json:"methods"`
}
```

### 10. Kratos Makefile
```makefile
GOPATH:=$(shell go env GOPATH)
VERSION=$(shell git describe --tags --always)
INTERNAL_PROTO_FILES=$(shell find internal -name *.proto)
API_PROTO_FILES=$(shell find api -name *.proto)

.PHONY: init
# init env
init:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2@latest
	go install github.com/go-kratos/kratos/cmd/protoc-gen-go-errors/v2@latest
	go install github.com/go-kratos/kratos/cmd/protoc-gen-go-validate/v2@latest
	go install github.com/envoyproxy/protoc-gen-validate@latest
	go install github.com/google/wire/cmd/wire@latest

.PHONY: config
# generate internal proto
config:
	protoc --proto_path=./internal \
	       --proto_path=./third_party \
 	       --go_out=paths=source_relative:./internal \
	       $(INTERNAL_PROTO_FILES)

.PHONY: api
# generate api proto
api:
	protoc --proto_path=./api \
	       --proto_path=./third_party \
 	       --go_out=paths=source_relative:./api \
 	       --go-http_out=paths=source_relative:./api \
 	       --go-grpc_out=paths=source_relative:./api \
	       --openapi_out=fq_schema_naming=true,default_response=false:. \
	       $(API_PROTO_FILES)

.PHONY: generate
# generate
generate:
	go mod tidy
	go get github.com/google/wire/cmd/wire@latest
	go generate ./...

.PHONY: wire
# generate wire
wire:
	cd cmd/server && wire

.PHONY: build
# build
build:
	mkdir -p bin/ && go build -ldflags "-X main.Version=$(VERSION)" -o ./bin/ ./...

.PHONY: test
# test
test:
	go test -v ./... -cover

.PHONY: run
# run
run:
	cd cmd/server && go run .

.PHONY: docker
# docker
docker:
	docker build -t catalog-service:$(VERSION) .

.PHONY: consul-setup
# setup consul permissions
consul-setup:
	./scripts/consul-setup.sh

.PHONY: migrate-up
# migrate up
migrate-up:
	./scripts/migrate.sh up

.PHONY: migrate-down  
# migrate down
migrate-down:
	./scripts/migrate.sh down

.PHONY: all
# generate all
all:
	make api;
	make config;
	make generate;
	make wire;

# show help
help:
	@echo ''
	@echo 'Usage:'
	@echo ' make [target]'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
	helpMessage = match(lastLine, /^# (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 2, RLENGTH); \
			printf "\033[36m%-22s\033[0m %s\n", helpCommand,helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help) run ./cmd/server

docker-build:
	docker build -t $(BINARY_NAME):$(VERSION) .

docker-run:
	docker run -p 8080:8080 $(BINARY_NAME):$(VERSION)

migrate-up:
	./scripts/migrate.sh up

migrate-down:
	./scripts/migrate.sh down

migrate-status:
	./scripts/migrate.sh status

seed:
	./scripts/seed.sh

lint:
	golangci-lint run

format:
	gofmt -s -w .
	goimports -w .

swagger:
	swag init -g cmd/server/main.go -o api/swagger

# Development helpers
dev-setup: deps migrate-up seed

dev-reset: migrate-down migrate-up seed

# Docker compose helpers
compose-up:
	docker-compose up -d

compose-down:
	docker-compose down

compose-logs:
	docker-compose logs -f

# Testing helpers
test-unit:
	$(GOTEST) -v ./internal/...

test-integration:
	$(GOTEST) -v ./tests/integration/...

test-all: test-unit test-integration

# Build for multiple platforms
build-all: build build-linux

# Release
release: clean deps test build-all
```

### go.mod
```go
module github.com/ecommerce/my-catalog-service

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/go-redis/redis/v8 v8.11.5
    github.com/prometheus/client_golang v1.17.0
    github.com/sirupsen/logrus v1.9.3
    github.com/spf13/viper v1.17.0
    github.com/stretchr/testify v1.8.4
    github.com/swaggo/gin-swagger v1.6.0
    github.com/swaggo/swag v1.16.2
    gorm.io/driver/postgres v1.5.4
    gorm.io/gorm v1.25.5
    github.com/Shopify/sarama v1.41.2
    github.com/golang-jwt/jwt/v5 v5.1.0
    github.com/google/uuid v1.4.0
)

require (
    // ... other dependencies
)
```

### Dockerfile
```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main ./cmd/server

# Final stage
FROM scratch

# Copy ca-certificates from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the binary
COPY --from=builder /app/main /main

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/main", "healthcheck"]

# Run the binary
ENTRYPOINT ["/main"]
```

This Go service template provides a complete, production-ready foundation for building microservices in the e-commerce platform with clean architecture, comprehensive error handling, monitoring, and all necessary integrations.
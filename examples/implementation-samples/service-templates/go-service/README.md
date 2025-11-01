# Go Microservice Template (Based on Catalog Service)

## Overview
Production-ready Go microservice template based on the **actual catalog service implementation**, following the e-commerce platform architecture patterns with clean architecture principles and integrated with common shared libraries.

## Tech Stack
- **Runtime**: Go 1.21+
- **Framework**: Gin (HTTP) + gRPC for dual protocol support
- **Database**: PostgreSQL with GORM
- **Cache**: Redis with custom cache manager
- **Configuration**: Environment-based config with shared common package
- **Logging**: Logrus with structured logging
- **Authentication**: JWT with middleware
- **Migrations**: Goose for database migrations
- **Documentation**: Protobuf + OpenAPI generation
- **Testing**: Standard Go testing + testify

## Actual Project Structure (Based on Catalog Service)
```
my-service/
├── cmd/                          # Application entry points
│   ├── my-service/              # Main service binary
│   │   └── main.go              # Main entry with Gin + gRPC
│   └── migrate/                 # Migration binary
│       └── main.go              # Database migration tool
├── internal/                     # Private application code
│   ├── biz/                     # Business logic layer
│   │   ├── product.go           # Product business logic
│   │   └── category.go          # Category business logic
│   ├── conf/                    # Configuration definitions
│   │   └── config.go            # Configuration structs
│   ├── config/                  # Configuration loading
│   │   └── config.go            # Config loading utilities
│   ├── consumer/                # Event consumers
│   │   ├── provider.go          # Consumer dependency injection
│   │   ├── interfaces.go        # Consumer interfaces
│   │   ├── sample.go            # Sample consumer implementation
│   │   └── message.go           # Message types
│   ├── data/                    # Data access layer
│   │   └── eventbus/            # Event bus implementation
│   │       ├── client.go        # Dapr eventbus client
│   │       └── task_consumer.go # Task event consumer
│   ├── handlers/                # HTTP/gRPC handlers
│   │   ├── product.go           # Product HTTP handlers
│   │   ├── category.go          # Category HTTP handlers
│   │   └── grpc_handlers.go     # gRPC handlers
│   ├── middleware/              # Custom middleware
│   │   ├── auth.go              # JWT authentication
│   │   ├── cors.go              # CORS middleware
│   │   └── logging.go           # Request logging
│   ├── models/                  # Database models
│   │   ├── product.go           # Product model
│   │   ├── category.go          # Category model
│   │   └── brand.go             # Brand model
│   ├── observer/                # Observer pattern for internal events
│   │   ├── observer.go          # Observer manager
│   │   └── event/               # Event definitions
│   │       └── task_created.go  # Task created event
│   ├── repository/              # Repository layer
│   │   ├── product.go           # Product repository
│   │   ├── category.go          # Category repository
│   │   └── interfaces.go        # Repository interfaces
│   ├── server/                  # Server configurations
│   │   ├── http.go              # HTTP server setup
│   │   └── grpc.go              # gRPC server setup
│   ├── service/                 # Service layer
│   │   ├── product.go           # Product service
│   │   └── category.go          # Category service
│   └── util/                    # Utility packages
│       └── observer/            # Observer utilities
│           └── manager.go       # Event manager
├── api/                         # API definitions (protobuf)
│   └── catalog/
│       └── v1/
│           ├── product.proto    # Product service definition
│           ├── category.proto   # Category service definition
│           ├── brand.proto      # Brand service definition
│           ├── cms.proto        # CMS service definition
│           ├── common.proto     # Common types
│           └── catalog.proto    # Main catalog service
├── configs/                     # Configuration files
│   ├── config.yaml             # Default configuration
│   ├── config-dev.yaml         # Development config
│   └── config-docker.yaml      # Docker config
├── migrations/                  # Database migrations
│   ├── 001_create_products_table.up.sql
│   ├── 001_create_products_table.down.sql
│   ├── 002_create_categories_table.up.sql
│   ├── 002_create_categories_table.down.sql
│   └── README.md
├── scripts/                     # Utility scripts
│   └── run-migrations.sh       # Migration runner script
├── deployments/                 # Deployment configurations
│   └── kubernetes/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── configmap.yaml
├── go.mod                       # Go module definition
├── go.sum                       # Go module checksums
├── Makefile                     # Build and development commands
├── Dockerfile                   # Docker image definition
├── docker-compose.yml           # Local development setup
└── README.md                    # Service documentation
```

## Quick Start

### 1. Prerequisites
```bash
# Install protobuf tools
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Install migration tool
go install github.com/pressly/goose/v3/cmd/goose@latest
```

### 2. Create New Service
```bash
# Copy this template
cp -r go-service-template my-new-service
cd my-new-service

# Initialize Go module
go mod init my-new-service
go mod tidy

# Update import paths in all files
find . -name "*.go" -exec sed -i 's/catalog/my-new-service/g' {} \;
```

### 3. Setup Common Package
```bash
# Create common package (shared across services)
mkdir -p ../common
cd ../common

# Initialize common module
go mod init common

# Create shared utilities, config, middleware, etc.
# (See common package structure below)
```

### 4. Setup Infrastructure
```bash
# Start PostgreSQL and Redis
docker-compose up -d

# Run database migrations
make migrate-up DATABASE_URL="postgres://user:pass@localhost:5432/myservice_db?sslmode=disable"
```

### 5. Generate Code
```bash
# Generate protobuf code
make api

# Build the service
make build
```

### 6. Start Development
```bash
# Start in development mode
make run

# Service will be available at:
# - HTTP: localhost:8001 (or your configured port)
# - gRPC: localhost:9001 (or your configured port)
# - Health: localhost:8001/health
```

## Core Components

### 1. Main Entry Point (cmd/my-service/main.go)
```go
package main

import (
    "context"
    "fmt"
    "log"
    "net"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/joho/godotenv"
    _ "github.com/lib/pq"
    "github.com/sirupsen/logrus"
    "google.golang.org/grpc"
    "gorm.io/gorm"

    "my-service/internal/handlers"
    "my-service/internal/models"
    "my-service/internal/repository"
    "my-service/internal/service"
    pb "my-service/api/myservice/v1"
    
    "common/config"
    "common/middleware"
    commonModels "common/models"
    "common/utils"
)

func main() {
    // Load environment variables
    if err := godotenv.Load(); err != nil {
        logrus.Warn("No .env file found")
    }

    // Load configuration
    baseConfig := config.LoadBaseConfig("my-service", "8001", "9001")
    dbConfig := config.LoadDatabaseConfig("my-service")
    redisConfig := config.LoadRedisConfig()
    jwtConfig := config.LoadJWTConfig()

    // Setup logger
    logger := utils.SetupLoggerFromEnv("my-service")

    // Connect to database
    db, err := utils.ConnectDB(dbConfig)
    if err != nil {
        logger.Fatalf("Failed to connect to database: %v", err)
    }

    // Auto-migrate models
    if err := autoMigrate(db); err != nil {
        logger.Fatalf("Failed to auto-migrate: %v", err)
    }

    // Connect to Redis
    rdb, err := utils.ConnectRedis(redisConfig)
    if err != nil {
        logger.Fatalf("Failed to connect to Redis: %v", err)
    }

    // Initialize cache manager
    cache := utils.NewCacheManager(rdb, "my-service")

    // Initialize repositories
    productRepo := repository.NewProductRepository(db, cache)
    categoryRepo := repository.NewCategoryRepository(db, cache)

    // Initialize services
    productService := service.NewProductService(productRepo, categoryRepo)
    categoryService := service.NewCategoryService(categoryRepo)

    // Initialize handlers
    productHandler := handlers.NewProductHandler(productService)
    categoryHandler := handlers.NewCategoryHandler(categoryService)

    // Setup HTTP server
    router := setupHTTPRouter(baseConfig, jwtConfig, productHandler, categoryHandler)
    httpServer := &http.Server{
        Addr:    fmt.Sprintf(":%s", baseConfig.HTTPPort),
        Handler: router,
    }

    // Setup gRPC server
    grpcServer := setupGRPCServer(productService, categoryService)
    grpcListener, err := net.Listen("tcp", fmt.Sprintf(":%s", baseConfig.GRPCPort))
    if err != nil {
        logger.Fatalf("Failed to listen on gRPC port: %v", err)
    }

    // Start servers
    go func() {
        logger.Infof("Starting HTTP server on port %s", baseConfig.HTTPPort)
        if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            logger.Fatalf("HTTP server failed: %v", err)
        }
    }()

    go func() {
        logger.Infof("Starting gRPC server on port %s", baseConfig.GRPCPort)
        if err := grpcServer.Serve(grpcListener); err != nil {
            logger.Fatalf("gRPC server failed: %v", err)
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Info("Shutting down servers...")

    // Graceful shutdown
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := httpServer.Shutdown(ctx); err != nil {
        logger.Errorf("HTTP server shutdown error: %v", err)
    }

    grpcServer.GracefulStop()
    logger.Info("Servers stopped")
}

func autoMigrate(db *gorm.DB) error {
    // Create extensions
    if err := utils.CreateExtensions(db); err != nil {
        return fmt.Errorf("failed to create extensions: %w", err)
    }

    // Auto-migrate models
    return utils.AutoMigrate(db,
        &models.Category{},
        &models.Brand{},
        &models.Product{},
    )
}

func setupHTTPRouter(baseConfig *config.BaseConfig, jwtConfig *config.JWTConfig, productHandler *handlers.ProductHandler, categoryHandler *handlers.CategoryHandler) *gin.Engine {
    if baseConfig.Environment == "production" {
        gin.SetMode(gin.ReleaseMode)
    }

    router := gin.New()
    router.Use(middleware.RequestID())
    router.Use(middleware.Logging())
    router.Use(middleware.Recovery())
    router.Use(middleware.CORS())

    // Health check
    router.GET("/health", func(c *gin.Context) {
        c.JSON(http.StatusOK, commonModels.NewAPIResponse(gin.H{
            "status":    "healthy",
            "service":   "my-service",
            "timestamp": time.Now().UTC(),
        }))
    })

    // Auth middleware configuration
    authConfig := &middleware.AuthConfig{
        JWTSecret: jwtConfig.Secret,
        SkipPaths: []string{"/health", "/v1/products", "/v1/categories"},
    }

    // API routes
    v1 := router.Group("/v1")
    {
        // Product routes
        products := v1.Group("/products")
        {
            products.GET("", productHandler.GetProducts)
            products.GET("/:id", productHandler.GetProduct)
            
            // Protected routes
            protected := products.Group("")
            protected.Use(middleware.Auth(authConfig))
            {
                protected.POST("", productHandler.CreateProduct)
                protected.PUT("/:id", productHandler.UpdateProduct)
                protected.DELETE("/:id", productHandler.DeleteProduct)
            }
        }

        // Category routes
        categories := v1.Group("/categories")
        {
            categories.GET("", categoryHandler.GetCategories)
            categories.GET("/:id", categoryHandler.GetCategory)
            
            // Protected routes
            protected := categories.Group("")
            protected.Use(middleware.Auth(authConfig))
            {
                protected.POST("", categoryHandler.CreateCategory)
                protected.PUT("/:id", categoryHandler.UpdateCategory)
                protected.DELETE("/:id", categoryHandler.DeleteCategory)
            }
        }
    }

    return router
}

func setupGRPCServer(productService *service.ProductService, categoryService *service.CategoryService) *grpc.Server {
    server := grpc.NewServer()
    
    // Register gRPC services
    pb.RegisterProductServiceServer(server, handlers.NewProductGRPCHandler(productService))
    pb.RegisterCategoryServiceServer(server, handlers.NewCategoryGRPCHandler(categoryService))

    return server
}
```

### 2. Common Package Structure (../common/)
```
common/
├── config/                       # Shared configuration
│   ├── base.go                  # Base service config
│   ├── database.go              # Database config
│   ├── redis.go                 # Redis config
│   └── jwt.go                   # JWT config
├── middleware/                   # Shared middleware
│   ├── auth.go                  # JWT authentication
│   ├── cors.go                  # CORS middleware
│   ├── logging.go               # Request logging
│   ├── recovery.go              # Panic recovery
│   └── request_id.go            # Request ID middleware
├── models/                       # Shared models
│   ├── response.go              # API response models
│   ├── pagination.go            # Pagination models
│   └── error.go                 # Error models
├── utils/                        # Shared utilities
│   ├── database.go              # Database utilities
│   ├── redis.go                 # Redis utilities
│   ├── logger.go                # Logger setup
│   ├── cache.go                 # Cache manager
│   └── validation.go            # Validation utilities
└── go.mod                        # Common module
```

#### Common Config Example (common/config/base.go)
```go
package config

import (
    "os"
    "strconv"
)

type BaseConfig struct {
    ServiceName string
    HTTPPort    string
    GRPCPort    string
    Environment string
    LogLevel    string
}

func LoadBaseConfig(serviceName, defaultHTTPPort, defaultGRPCPort string) *BaseConfig {
    return &BaseConfig{
        ServiceName: serviceName,
        HTTPPort:    getEnv("HTTP_PORT", defaultHTTPPort),
        GRPCPort:    getEnv("GRPC_PORT", defaultGRPCPort),
        Environment: getEnv("ENVIRONMENT", "development"),
        LogLevel:    getEnv("LOG_LEVEL", "info"),
    }
}

type DatabaseConfig struct {
    Host     string
    Port     int
    User     string
    Password string
    DBName   string
    SSLMode  string
}

func LoadDatabaseConfig(serviceName string) *DatabaseConfig {
    port, _ := strconv.Atoi(getEnv("DB_PORT", "5432"))
    
    return &DatabaseConfig{
        Host:     getEnv("DB_HOST", "localhost"),
        Port:     port,
        User:     getEnv("DB_USER", "postgres"),
        Password: getEnv("DB_PASSWORD", "postgres"),
        DBName:   getEnv("DB_NAME", serviceName+"_db"),
        SSLMode:  getEnv("DB_SSLMODE", "disable"),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}
```

### 3. Configuration Files (configs/)
#### configs/config.yaml (Development)
```yaml
# Service Configuration
service:
  name: "my-service"
  version: "v1.0.0"
  environment: "development"

# Server Configuration
server:
  http:
    port: 8001
    timeout: 30s
  grpc:
    port: 9001
    timeout: 30s

# Database Configuration
database:
  host: "localhost"
  port: 5432
  user: "postgres"
  password: "postgres"
  dbname: "myservice_db"
  sslmode: "disable"
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: "5m"

# Redis Configuration
redis:
  host: "localhost"
  port: 6379
  password: ""
  db: 0
  pool_size: 10
  min_idle_conns: 5

# JWT Configuration
jwt:
  secret: "your-jwt-secret-key"
  expires_in: "24h"
  issuer: "my-service"

# Logging Configuration
logging:
  level: "info"
  format: "json"
  output: "stdout"
```

#### configs/config-docker.yaml (Docker)
```yaml
# Service Configuration
service:
  name: "my-service"
  version: "v1.0.0"
  environment: "docker"

# Server Configuration
server:
  http:
    port: 8001
    timeout: 30s
  grpc:
    port: 9001
    timeout: 30s

# Database Configuration (Docker services)
database:
  host: "postgres"
  port: 5432
  user: "postgres"
  password: "postgres"
  dbname: "myservice_db"
  sslmode: "disable"
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: "5m"

# Redis Configuration (Docker services)
redis:
  host: "redis"
  port: 6379
  password: ""
  db: 0
  pool_size: 10
  min_idle_conns: 5

# JWT Configuration
jwt:
  secret: "your-jwt-secret-key"
  expires_in: "24h"
  issuer: "my-service"

# Logging Configuration
logging:
  level: "info"
  format: "json"
  output: "stdout"
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

### 4. Makefile (Based on Catalog Service)
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

### 5. go.mod (Based on Catalog Service)
```go
module my-service

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
    github.com/pressly/goose/v3 v3.15.0
    github.com/redis/go-redis/v9 v9.0.5
    github.com/google/uuid v1.3.0
    github.com/joho/godotenv v1.4.0
    github.com/golang-jwt/jwt/v5 v5.0.0
    github.com/sirupsen/logrus v1.9.3
    google.golang.org/grpc v1.57.0
    google.golang.org/protobuf v1.31.0
    gorm.io/gorm v1.25.5
    gorm.io/driver/postgres v1.5.4
    common v0.0.0
)

replace common => ../common

require (
    github.com/bytedance/sonic v1.9.1 // indirect
    github.com/cespare/xxhash/v2 v2.2.0 // indirect
    github.com/chenzhuoyu/base64x v0.0.0-20221115062448-fe3a3abad311 // indirect
    github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
    github.com/gabriel-vasile/mimetype v1.4.2 // indirect
    github.com/gin-contrib/sse v0.1.0 // indirect
    github.com/go-playground/locales v0.14.1 // indirect
    github.com/go-playground/universal-translator v0.18.1 // indirect
    github.com/go-playground/validator/v10 v10.14.0 // indirect
    github.com/goccy/go-json v0.10.2 // indirect
    github.com/hashicorp/errwrap v1.1.0 // indirect
    github.com/hashicorp/go-multierror v1.1.1 // indirect
    github.com/json-iterator/go v1.1.12 // indirect
    github.com/klauspost/cpuid/v2 v2.2.4 // indirect
    github.com/leodido/go-urn v1.2.4 // indirect
    github.com/mattn/go-isatty v0.0.19 // indirect
    github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
    github.com/modern-go/reflect2 v1.0.2 // indirect
    github.com/pelletier/go-toml/v2 v2.0.8 // indirect
    github.com/twitchyliquid64/golang-asm v0.15.1 // indirect
    github.com/ugorji/go/codec v1.2.11 // indirect
    go.uber.org/atomic v1.7.0 // indirect
    golang.org/x/arch v0.3.0 // indirect
    golang.org/x/crypto v0.11.0 // indirect
    golang.org/x/net v0.12.0 // indirect
    golang.org/x/sys v0.10.0 // indirect
    golang.org/x/text v0.11.0 // indirect
    google.golang.org/genproto/googleapis/rpc v0.0.0-20230525234030-28d5490b6b19 // indirect
)
```

### 6. Docker Compose (Development Setup)
```yaml
# docker-compose.yml
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: my-service-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: myservice_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - my-service-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Redis for caching
  redis:
    image: redis:7-alpine
    container_name: my-service-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - my-service-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # My Service
  my-service:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: my-service-app
    ports:
      - "8001:8001"  # HTTP
      - "9001:9001"  # gRPC
    environment:
      - ENVIRONMENT=docker
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=postgres
      - DB_PASSWORD=postgres
      - DB_NAME=myservice_db
      - DB_SSLMODE=disable
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - JWT_SECRET=your-jwt-secret-key
      - LOG_LEVEL=info
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - my-service-network
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:

networks:
  my-service-network:
    driver: bridge
```

### 13. Kratos Project Configuration (kratos.yaml)
```yaml
project:
  name: catalog-service
  version: v1.0.0
  description: Catalog microservice with Kratos framework
  
server:
  http:
    addr: 0.0.0.0:8000
    timeout: 1s
  grpc:
    addr: 0.0.0.0:9000
    timeout: 1s

registry:
  consul:
    address: localhost:8500
    scheme: http

dapr:
  app_id: catalog-service
  app_port: 8000
  dapr_http_port: 3500
  dapr_grpc_port: 50001

trace:
  jaeger:
    endpoint: http://localhost:14268/api/traces

metrics:
  prometheus:
    path: /metrics
    addr: 0.0.0.0:9091
```

### 14. Dapr Components Configuration

#### Pub/Sub Component (deployments/dapr/pubsub.yaml)
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: redis-pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
  - name: enableTLS
    value: false
scopes:
- catalog-service
- order-service
- shipping-service
- notification-service
```

#### State Store Component (deployments/dapr/statestore.yaml)
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: redis-state
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
  - name: enableTLS
    value: false
  - name: keyPrefix
    value: catalog-service
scopes:
- catalog-service
```

#### Service Invocation with Consul (deployments/dapr/consul-nameresolution.yaml)
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: consul-nameresolution
spec:
  type: nameresolution.consul
  version: v1
  metadata:
  - name: client
    value: "localhost:8500"
  - name: datacenter
    value: "dc1"
  - name: scheme
    value: "http"
```

### 15. Dapr Integration Examples

#### Publishing Events
```go
// Publish order created event via Dapr
func (s *OrderService) PublishOrderCreated(ctx context.Context, order *biz.Order) error {
    event := OrderCreatedEvent{
        OrderID:    order.ID,
        CustomerID: order.CustomerID,
        Amount:     order.TotalAmount,
        CreatedAt:  time.Now(),
    }
    
    eventData, _ := json.Marshal(event)
    
    // Publish via Dapr HTTP API
    daprURL := fmt.Sprintf("http://localhost:3500/v1.0/publish/redis-pubsub/order.created")
    
    req, _ := http.NewRequestWithContext(ctx, "POST", daprURL, bytes.NewBuffer(eventData))
    req.Header.Set("Content-Type", "application/json")
    
    client := &http.Client{Timeout: 5 * time.Second}
    resp, err := client.Do(req)
    if err != nil {
        return fmt.Errorf("failed to publish event: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        return fmt.Errorf("failed to publish event, status: %d", resp.StatusCode)
    }
    
    return nil
}
```

#### Subscribing to Events
```go
// Subscribe to events via Dapr
func (s *ShippingService) setupDaprSubscriptions() {
    // Dapr will call this endpoint for subscriptions
    http.HandleFunc("/dapr/subscribe", s.daprSubscribeHandler)
    
    // Handle order created events
    http.HandleFunc("/order-created", s.handleOrderCreated)
}

func (s *ShippingService) daprSubscribeHandler(w http.ResponseWriter, r *http.Request) {
    subscriptions := []map[string]interface{}{
        {
            "pubsubname": "redis-pubsub",
            "topic":      "order.created",
            "route":      "/order-created",
        },
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(subscriptions)
}

func (s *ShippingService) handleOrderCreated(w http.ResponseWriter, r *http.Request) {
    var event OrderCreatedEvent
    if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    // Process the order created event
    if err := s.processOrderCreated(r.Context(), &event); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    w.WriteHeader(http.StatusOK)
}
```

#### Service Invocation via Dapr
```go
// Call another service via Dapr service invocation
func (s *OrderService) CallPaymentService(ctx context.Context, req *PaymentRequest) (*PaymentResponse, error) {
    reqData, _ := json.Marshal(req)
    
    // Call via Dapr service invocation
    daprURL := "http://localhost:3500/v1.0/invoke/payment-service/method/process-payment"
    
    httpReq, _ := http.NewRequestWithContext(ctx, "POST", daprURL, bytes.NewBuffer(reqData))
    httpReq.Header.Set("Content-Type", "application/json")
    
    client := &http.Client{Timeout: 30 * time.Second}
    resp, err := client.Do(httpReq)
    if err != nil {
        return nil, fmt.Errorf("failed to call payment service: %w", err)
    }
    defer resp.Body.Close()
    
    var paymentResp PaymentResponse
    if err := json.NewDecoder(resp.Body).Decode(&paymentResp); err != nil {
        return nil, fmt.Errorf("failed to decode response: %w", err)
    }
    
    return &paymentResp, nil
}
```

### Consumer Monitoring & Observability

#### Consumer Metrics (internal/consumer/metrics.go)
```go
package consumer

import (
    "context"
    "time"
    
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    consumerMessagesTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "consumer_messages_total",
            Help: "Total number of messages processed by consumer",
        },
        []string{"consumer", "topic", "status"},
    )
    
    consumerProcessingDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "consumer_processing_duration_seconds",
            Help: "Time spent processing messages",
        },
        []string{"consumer", "topic"},
    )
)

func RecordMessageProcessed(consumer, topic, status string) {
    consumerMessagesTotal.WithLabelValues(consumer, topic, status).Inc()
}

func RecordProcessingDuration(consumer, topic string, duration time.Duration) {
    consumerProcessingDuration.WithLabelValues(consumer, topic).Observe(duration.Seconds())
}
```

#### Consumer Health Checks
```go
// Add to main HTTP router
router.GET("/health/consumers", func(c *gin.Context) {
    status := gin.H{
        "consumers": gin.H{
            "sample_consumer": "healthy",
            "task_consumer":   "healthy",
        },
        "eventbus": gin.H{
            "status":      "connected",
            "last_ping":   time.Now().UTC(),
        },
    }
    c.JSON(http.StatusOK, status)
})
```

### Error Handling & Retry Mechanisms

#### Consumer Error Handler (internal/consumer/error_handler.go)
```go
package consumer

import (
    "context"
    "fmt"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
)

type ErrorHandler struct {
    maxRetries    int
    retryInterval time.Duration
    log           *log.Helper
}

func NewErrorHandler(maxRetries int, retryInterval time.Duration, logger log.Logger) *ErrorHandler {
    return &ErrorHandler{
        maxRetries:    maxRetries,
        retryInterval: retryInterval,
        log:           log.NewHelper(logger),
    }
}

func (h *ErrorHandler) HandleWithRetry(ctx context.Context, fn func() error) error {
    var lastErr error
    
    for attempt := 0; attempt <= h.maxRetries; attempt++ {
        if err := fn(); err != nil {
            lastErr = err
            h.log.WithContext(ctx).Warnf("Attempt %d failed: %v", attempt+1, err)
            
            if attempt < h.maxRetries {
                select {
                case <-ctx.Done():
                    return ctx.Err()
                case <-time.After(h.retryInterval * time.Duration(attempt+1)):
                    continue
                }
            }
        } else {
            return nil
        }
    }
    
    return fmt.Errorf("failed after %d attempts: %w", h.maxRetries+1, lastErr)
}
```

### Consumer Graceful Shutdown

#### Shutdown Manager (internal/consumer/shutdown.go)
```go
package consumer

import (
    "context"
    "sync"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
)

type ShutdownManager struct {
    consumers []Consumer
    timeout   time.Duration
    log       *log.Helper
}

func NewShutdownManager(timeout time.Duration, logger log.Logger) *ShutdownManager {
    return &ShutdownManager{
        timeout: timeout,
        log:     log.NewHelper(logger),
    }
}

func (sm *ShutdownManager) RegisterConsumer(consumer Consumer) {
    sm.consumers = append(sm.consumers, consumer)
}

func (sm *ShutdownManager) Shutdown(ctx context.Context) error {
    sm.log.Info("Starting graceful shutdown of consumers...")
    
    ctx, cancel := context.WithTimeout(ctx, sm.timeout)
    defer cancel()
    
    var wg sync.WaitGroup
    errChan := make(chan error, len(sm.consumers))
    
    for _, consumer := range sm.consumers {
        wg.Add(1)
        go func(c Consumer) {
            defer wg.Done()
            if err := c.Stop(ctx); err != nil {
                errChan <- err
            }
        }(consumer)
    }
    
    wg.Wait()
    close(errChan)
    
    // Check for errors
    for err := range errChan {
        if err != nil {
            sm.log.Errorf("Consumer shutdown error: %v", err)
            return err
        }
    }
    
    sm.log.Info("All consumers shut down successfully")
    return nil
}
```

## Template Benefits (Based on Real Implementation)

### 1. **Production-Ready Architecture**
- Clean architecture with separation of concerns
- Repository pattern for data access
- Service layer for business logic
- Handler layer for HTTP/gRPC endpoints

### 2. **Dual Protocol Support**
- Gin for high-performance HTTP/REST APIs
- gRPC for service-to-service communication
- Shared business logic between protocols

### 3. **Shared Common Package**
- Reusable configuration management
- Standardized middleware (auth, logging, CORS)
- Common utilities and models
- Consistent error handling

### 4. **Database Management**
- GORM for ORM with PostgreSQL
- Goose for database migrations
- Connection pooling and optimization
- Auto-migration support

### 5. **Caching & Performance**
- Redis integration with cache manager
- Configurable cache TTL
- Cache invalidation strategies
- Performance monitoring

### 6. **Security Features**
- JWT authentication middleware
- CORS protection
- Request ID tracking
- Input validation

### 7. **Developer Experience**
- Environment-based configuration
- Structured logging with Logrus
- Graceful shutdown handling
- Comprehensive Makefile
- Docker support

### 8. **Testing & Quality**
- Standard Go testing framework
- Test coverage reporting
- Integration test support
- Linting and code quality

### 9. **Deployment Ready**
- Docker containerization
- Docker Compose for local development
- Kubernetes deployment manifests
- Health check endpoints

### 10. **Event-Driven Architecture**
- Dapr integration for pub/sub messaging
- Consumer pattern implementation
- Event sourcing capabilities
- Observer pattern for internal events
- Retry mechanisms and error handling
- Dead letter queue support

### 11. **Monitoring & Observability**
- Structured logging
- Health check endpoints
- Request/response logging
- Consumer metrics and monitoring
- Event processing observability
- Error tracking and alerting

## Key Differences from Kratos Template

### **Simplified Architecture**
- Uses Gin instead of Kratos framework
- Direct dependency injection (no Wire)
- Environment-based configuration
- Shared common package approach

### **Event-Driven Architecture**
- Complete consumer implementation patterns
- Dapr integration for microservices communication
- Observer pattern for internal event handling
- Retry mechanisms and error handling
- Graceful shutdown and monitoring

### **Real-World Patterns**
- Based on actual production services (catalog-service and shop-main)
- Proven patterns and structures

type Message struct {
    Data []byte
}

func (c *client) makeHandler(topicPubsub string, handler ConsumeFn) common.TopicEventHandler {
    return func(ctx context.Context, e *common.TopicEvent) (retry bool, err error) {
        c.log.WithContext(ctx).Infof("Received event - PubSub: %s, Topic: %s", e.PubsubName, e.Topic)
        
        if e.PubsubName != topicPubsub {
            return false, nil
        }
        
        payload, ok := e.Data.(map[string]interface{})
        if !ok {
            return false, errors.New("cannot decode payload")
        }
        
        var msg Message
        msg.Data, err = json.Marshal(payload["data"])
        if err != nil {
            return false, errors.Wrap(err, "cannot marshal payload")
        }

        if err = handler(ctx, msg); err != nil {
            c.log.WithContext(ctx).Errorf("Handler error - PubSub: %s, Topic: %s, Error: %v", 
                e.PubsubName, e.Topic, err)
            return true, err // Retry on error
        }
        
        return false, nil
    }
}
```

### Task Consumer Example (internal/data/eventbus/task_consumer.go)
```go
package eventbus

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"

    "gitlab.com/vigo-tech/shop/config"
    "gitlab.com/vigo-tech/shop/internal/biz/task"
    "gitlab.com/vigo-tech/shop/internal/consumer"
)

type TaskConsumer struct {
    Client
    config config.Eventbus
    uc     *task.TaskUsecase
}

func NewTaskConsumer(client Client, config *config.Data, uc *task.TaskUsecase) *TaskConsumer {
    return &TaskConsumer{
        Client: client,
        config: config.Eventbus,
        uc:     uc,
    }
}

func (c *TaskConsumer) Start(ctx context.Context) error {
    return c.AddConsumer(
        c.config.Topic.TaskCreated,
        c.config.DefaultPubsub,
        c.HandleTaskCreated,
    )
}

func (c *TaskConsumer) HandleTaskCreated(ctx context.Context, e Message) error {
    var msg consumer.TaskCreatedMessage
    if err := json.NewDecoder(bytes.NewReader(e.Data)).Decode(&msg); err != nil {
        return fmt.Errorf("failed to decode task created event: %w", err)
    }
    
    return c.uc.ProcessTask(ctx, task.ProcessTaskInput{
        TaskID:     msg.TaskID,
        TaskType:   msg.TaskType,
        InputParam: msg.InputParam,
    })
}
```

### Observer Pattern for Internal Events (internal/util/observer/manager.go)
```go
package observer

import (
    "context"
    "reflect"

    "github.com/pkg/errors"
)

type Trigger interface {
    Trigger(ctx context.Context, eventName string, data interface{}) error
}

type Manager interface {
    Trigger
    Subscribe(eventName string, subscribers ...Subscriber)
}

type Subscriber interface {
    Handle(context.Context, interface{}) error
}

type manager struct {
    eventSubscribers map[string][]Subscriber
}

func NewManager() Manager {
    return &manager{
        eventSubscribers: make(map[string][]Subscriber),
    }
}

func (m *manager) Subscribe(eventName string, subscribers ...Subscriber) {
    m.eventSubscribers[eventName] = append(m.eventSubscribers[eventName], subscribers...)
}

func (m *manager) Trigger(ctx context.Context, eventName string, data interface{}) error {
    for _, sub := range m.eventSubscribers[eventName] {
        if err := sub.Handle(ctx, data); err != nil {
            return errors.Wrapf(err, "error from subscriber: %s", getStructName(sub))
        }
    }
    return nil
}

func getStructName(myvar interface{}) string {
    if t := reflect.TypeOf(myvar); t.Kind() == reflect.Ptr {
        return "*" + t.Elem().Name()
    }
    return t.Name()
}
```

### Consumer Integration in Main Application

#### Updated Wire Setup (cmd/my-service/wire.go)
```go
//go:build wireinject
// +build wireinject

package main

import (
    "my-service/internal/biz"
    "my-service/internal/consumer"
    "my-service/internal/data"
    "my-service/internal/observer"
    "my-service/internal/server"
    "my-service/internal/service"
    "my-service/internal/util"

    "github.com/go-kratos/kratos/v2/log"
    "github.com/google/wire"
)

func wireApp(*config.Server, *config.Data, *config.Registry, log.Logger) (*appLauncher, func(), error) {
    panic(wire.Build(
        server.ProviderSet,
        util.ProviderSet,
        data.ProviderSet,
        biz.ProviderSet,
        service.ProviderSet,
        consumer.ProviderSet,    // Add consumer providers
        observer.ProviderSet,
        newApp,
        wire.Struct(new(appLauncher), "*"),
    ))
}
```

#### Application Launcher with Consumer Support (cmd/my-service/launcher.go)
```go
package main

import (
    "context"
    "sync"
    
    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/spf13/cobra"
    
    "my-service/internal/consumer"
    "my-service/internal/data/eventbus"
    "my-service/internal/observer"
)

type appLauncher struct {
    httpApp         *kratos.App
    obManager       observer.Manager
    sampleConsumer  *consumer.SampleConsumer
    taskConsumer    *eventbus.TaskConsumer
    eventbusClient  eventbus.Client
    log             *log.Helper
}

func (app *appLauncher) Run() error {
    return createRootCommand(app).Execute()
}

func createRootCommand(app *appLauncher) *cobra.Command {
    rootCommand := &cobra.Command{
        Use:   "my-service",
        Short: "My Microservice with Event Consumers",
        RunE: func(cmd *cobra.Command, args []string) error {
            return app.startApplication()
        },
    }
    return rootCommand
}

func (app *appLauncher) startApplication() error {
    ctx := context.Background()
    var wg sync.WaitGroup
    
    // Start consumers
    wg.Add(1)
    go func() {
        defer wg.Done()
        if err := app.startConsumers(ctx); err != nil {
            app.log.Errorf("Failed to start consumers: %v", err)
        }
    }()
    
    // Start HTTP/gRPC server
    wg.Add(1)
    go func() {
        defer wg.Done()
        if err := app.httpApp.Run(); err != nil {
            app.log.Errorf("Failed to start HTTP app: %v", err)
        }
    }()
    
    wg.Wait()
    return nil
}

func (app *appLauncher) startConsumers(ctx context.Context) error {
    app.log.Info("Starting event consumers...")
    
    // Start sample consumer
    if err := app.sampleConsumer.Start(ctx); err != nil {
        return fmt.Errorf("failed to start sample consumer: %w", err)
    }
    
    // Start task consumer
    if err := app.taskConsumer.Start(ctx); err != nil {
        return fmt.Errorf("failed to start task consumer: %w", err)
    }
    
    // Start eventbus client (Dapr)
    if err := app.eventbusClient.Start(); err != nil {
        return fmt.Errorf("failed to start eventbus client: %w", err)
    }
    
    app.log.Info("All consumers started successfully")
    return nil
}
```

### Consumer Configuration

#### Updated Configuration (configs/config.yaml)
```yaml
# Service Configuration
service:
  name: "my-service"
  version: "v1.0.0"
  environment: "development"

# Server Configuration
server:
  http:
    port: 8001
    timeout: 30s
  grpc:
    port: 9001
    timeout: 30s

# Database Configuration
database:
  host: "localhost"
  port: 5432
  user: "postgres"
  password: "postgres"
  dbname: "myservice_db"
  sslmode: "disable"

# Redis Configuration
redis:
  host: "localhost"
  port: 6379
  password: ""
  db: 0

# Event Bus Configuration
eventbus:
  enabled: true
  default_pubsub: "redis-pubsub"
  topics:
    sample_created: "sample.created"
    task_created: "task.created"
    product_updated: "product.updated"
  retry_policy:
    max_attempts: 3
    backoff_interval: "5s"
    max_backoff: "30s"

# Consumer Configuration
consumers:
  enabled: true
  concurrent_handlers: 10
  timeout: "30s"
  dead_letter_queue: "dlq-topic"

# JWT Configuration
jwt:
  secret: "your-jwt-secret-key"
  expires_in: "24h"
  issuer: "my-service"
```

### Consumer Testing

#### Consumer Unit Tests (internal/consumer/sample_test.go)
```go
package consumer

import (
    "context"
    "testing"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
)

type MockSubscriber struct {
    mock.Mock
}

func (m *MockSubscriber) Subscribe(ctx context.Context, topic string, handler func(context.Context, []byte) error) error {
    args := m.Called(ctx, topic, handler)
    return args.Error(0)
}

func TestSampleConsumer_HandleSampleCreated(t *testing.T) {
    // Setup
    mockSubscriber := new(MockSubscriber)
    logger := log.NewStdLogger(os.Stdout)
    consumer := NewSampleConsumer(mockSubscriber, logger)
    
    // Test data
    payload := []byte(`{
        "id": "test-123",
        "type": "sample.created",
        "source": "test-service",
        "timestamp": "2023-01-01T00:00:00Z",
        "value": "test-value"
    }`)
    
    // Execute
    err := consumer.HandleSampleCreated(context.Background(), payload)
    
    // Assert
    assert.NoError(t, err)
}

func TestSampleConsumer_Start(t *testing.T) {
    // Setup
    mockSubscriber := new(MockSubscriber)
    logger := log.NewStdLogger(os.Stdout)
    consumer := NewSampleConsumer(mockSubscriber, logger)
    
    // Mock expectations
    mockSubscriber.On("Subscribe", mock.Anything, "sample.created", mock.Anything).Return(nil)
    
    // Execute
    err := consumer.Start(context.Background())
    
    // Assert
    assert.NoError(t, err)
    mockSubscriber.AssertExpectations(t)
}
```

### 15. Dapr Integration Examples

#### Publishing Events
- Battle-tested configurations
- Practical middleware implementations

### **Easier to Understand**
- Less abstraction layers
- Clear separation of concerns
- Standard Go patterns
- Minimal boilerplate
- Well-documented consumer examples

This template provides a practical, production-ready foundation for building microservices with complete event-driven architecture based on real-world implementation patterns used in the e-commerce platform.
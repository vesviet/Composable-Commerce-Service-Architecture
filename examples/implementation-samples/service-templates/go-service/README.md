# Go Microservice Template

## Overview
Production-ready Go microservice template following the e-commerce platform architecture patterns with clean architecture principles.

## Tech Stack
- **Runtime**: Go 1.21+
- **Framework**: Gin HTTP framework
- **Database**: PostgreSQL with GORM
- **Messaging**: Sarama Kafka client
- **Caching**: go-redis
- **Monitoring**: Prometheus client, structured logging with logrus
- **Testing**: testify framework
- **Documentation**: Swagger with gin-swagger
- **Configuration**: Viper for configuration management

## Project Structure
```
go-service/
├── cmd/
│   └── server/                    # Application entry point
│       └── main.go
├── internal/                      # Private application code
│   ├── config/                    # Configuration
│   │   └── config.go
│   ├── domain/                    # Domain models and interfaces
│   │   ├── entities/
│   │   │   ├── product.go
│   │   │   └── user.go
│   │   ├── repositories/
│   │   │   └── product_repository.go
│   │   └── services/
│   │       └── product_service.go
│   ├── infrastructure/            # External concerns
│   │   ├── database/
│   │   │   ├── postgres.go
│   │   │   └── migrations/
│   │   ├── cache/
│   │   │   └── redis.go
│   │   ├── messaging/
│   │   │   ├── kafka_producer.go
│   │   │   └── kafka_consumer.go
│   │   └── monitoring/
│   │       ├── metrics.go
│   │       └── logger.go
│   ├── interfaces/                # Interface adapters
│   │   ├── http/                  # HTTP handlers
│   │   │   ├── handlers/
│   │   │   │   ├── product_handler.go
│   │   │   │   └── health_handler.go
│   │   │   ├── middleware/
│   │   │   │   ├── auth.go
│   │   │   │   ├── cors.go
│   │   │   │   ├── logging.go
│   │   │   │   └── metrics.go
│   │   │   └── routes/
│   │   │       └── routes.go
│   │   └── events/                # Event handlers
│   │       ├── product_events.go
│   │       └── order_events.go
│   ├── application/               # Application services
│   │   ├── services/
│   │   │   └── product_service.go
│   │   └── dto/
│   │       ├── product_dto.go
│   │       └── response_dto.go
│   └── repository/                # Repository implementations
│       └── postgres/
│           └── product_repository.go
├── pkg/                           # Public library code
│   ├── errors/
│   │   └── errors.go
│   ├── utils/
│   │   ├── validator.go
│   │   └── jwt.go
│   └── constants/
│       └── constants.go
├── api/                           # API definitions
│   └── swagger/
│       └── docs.go
├── scripts/                       # Utility scripts
│   ├── migrate.sh
│   ├── build.sh
│   └── test.sh
├── deployments/                   # Deployment configurations
│   ├── docker/
│   │   └── Dockerfile
│   └── k8s/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── configmap.yaml
├── tests/                         # Test files
│   ├── integration/
│   ├── unit/
│   └── fixtures/
├── docs/                          # Documentation
├── go.mod
├── go.sum
├── Makefile
├── .env.example
├── .gitignore
└── README.md
```

## Quick Start

### 1. Setup
```bash
# Clone template
cp -r go-service my-catalog-service
cd my-catalog-service

# Initialize Go module
go mod init github.com/ecommerce/my-catalog-service

# Install dependencies
go mod tidy

# Copy environment file
cp .env.example .env
```

### 2. Database Setup
```bash
# Start PostgreSQL
docker-compose up -d postgres

# Run migrations
make migrate-up

# Seed data (optional)
make seed
```

### 3. Start Development
```bash
# Start all dependencies
docker-compose up -d

# Start in development mode
make run-dev

# Service will be available at http://localhost:8080
```

## Core Files

### Main Entry Point (cmd/server/main.go)
```go
package main

import (
    "context"
    "fmt"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/ecommerce/my-catalog-service/internal/config"
    "github.com/ecommerce/my-catalog-service/internal/infrastructure/database"
    "github.com/ecommerce/my-catalog-service/internal/infrastructure/cache"
    "github.com/ecommerce/my-catalog-service/internal/infrastructure/messaging"
    "github.com/ecommerce/my-catalog-service/internal/infrastructure/monitoring"
    "github.com/ecommerce/my-catalog-service/internal/interfaces/http/routes"
    "github.com/gin-gonic/gin"
    "github.com/sirupsen/logrus"
)

func main() {
    // Load configuration
    cfg, err := config.Load()
    if err != nil {
        logrus.Fatalf("Failed to load configuration: %v", err)
    }

    // Initialize logger
    logger := monitoring.NewLogger(cfg.Log.Level)
    
    // Initialize database
    db, err := database.NewPostgresConnection(cfg.Database)
    if err != nil {
        logger.Fatalf("Failed to connect to database: %v", err)
    }
    defer database.Close(db)

    // Run migrations
    if err := database.Migrate(db); err != nil {
        logger.Fatalf("Failed to run migrations: %v", err)
    }

    // Initialize Redis cache
    redisClient, err := cache.NewRedisClient(cfg.Redis)
    if err != nil {
        logger.Fatalf("Failed to connect to Redis: %v", err)
    }
    defer redisClient.Close()

    // Initialize Kafka
    kafkaProducer, err := messaging.NewKafkaProducer(cfg.Kafka)
    if err != nil {
        logger.Fatalf("Failed to initialize Kafka producer: %v", err)
    }
    defer kafkaProducer.Close()

    kafkaConsumer, err := messaging.NewKafkaConsumer(cfg.Kafka)
    if err != nil {
        logger.Fatalf("Failed to initialize Kafka consumer: %v", err)
    }
    defer kafkaConsumer.Close()

    // Initialize metrics
    metrics := monitoring.NewMetrics()

    // Setup Gin router
    if cfg.Server.Mode == "production" {
        gin.SetMode(gin.ReleaseMode)
    }

    router := gin.New()
    
    // Setup routes with dependencies
    routes.SetupRoutes(router, &routes.Dependencies{
        DB:            db,
        Cache:         redisClient,
        KafkaProducer: kafkaProducer,
        Metrics:       metrics,
        Logger:        logger,
        Config:        cfg,
    })

    // Start Kafka consumers
    go func() {
        if err := kafkaConsumer.Start(context.Background()); err != nil {
            logger.Errorf("Kafka consumer error: %v", err)
        }
    }()

    // Start HTTP server
    server := &http.Server{
        Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
        Handler:      router,
        ReadTimeout:  time.Duration(cfg.Server.ReadTimeout) * time.Second,
        WriteTimeout: time.Duration(cfg.Server.WriteTimeout) * time.Second,
    }

    // Start server in goroutine
    go func() {
        logger.Infof("Server starting on port %d", cfg.Server.Port)
        if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            logger.Fatalf("Server failed to start: %v", err)
        }
    }()

    // Wait for interrupt signal to gracefully shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Info("Shutting down server...")

    // Graceful shutdown with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := server.Shutdown(ctx); err != nil {
        logger.Errorf("Server forced to shutdown: %v", err)
    }

    logger.Info("Server exited")
}
```

### Configuration (internal/config/config.go)
```go
package config

import (
    "github.com/spf13/viper"
)

type Config struct {
    Server   ServerConfig   `mapstructure:"server"`
    Database DatabaseConfig `mapstructure:"database"`
    Redis    RedisConfig    `mapstructure:"redis"`
    Kafka    KafkaConfig    `mapstructure:"kafka"`
    Log      LogConfig      `mapstructure:"log"`
    Auth     AuthConfig     `mapstructure:"auth"`
}

type ServerConfig struct {
    Port         int    `mapstructure:"port"`
    Mode         string `mapstructure:"mode"`
    ReadTimeout  int    `mapstructure:"read_timeout"`
    WriteTimeout int    `mapstructure:"write_timeout"`
}

type DatabaseConfig struct {
    Host     string `mapstructure:"host"`
    Port     int    `mapstructure:"port"`
    User     string `mapstructure:"user"`
    Password string `mapstructure:"password"`
    DBName   string `mapstructure:"dbname"`
    SSLMode  string `mapstructure:"sslmode"`
}

type RedisConfig struct {
    Host     string `mapstructure:"host"`
    Port     int    `mapstructure:"port"`
    Password string `mapstructure:"password"`
    DB       int    `mapstructure:"db"`
}

type KafkaConfig struct {
    Brokers []string `mapstructure:"brokers"`
    GroupID string   `mapstructure:"group_id"`
}

type LogConfig struct {
    Level string `mapstructure:"level"`
}

type AuthConfig struct {
    JWTSecret string `mapstructure:"jwt_secret"`
}

func Load() (*Config, error) {
    viper.SetConfigName("config")
    viper.SetConfigType("yaml")
    viper.AddConfigPath(".")
    viper.AddConfigPath("./configs")

    // Set defaults
    setDefaults()

    // Read environment variables
    viper.AutomaticEnv()

    // Read config file
    if err := viper.ReadInConfig(); err != nil {
        if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
            return nil, err
        }
    }

    var config Config
    if err := viper.Unmarshal(&config); err != nil {
        return nil, err
    }

    return &config, nil
}

func setDefaults() {
    viper.SetDefault("server.port", 8080)
    viper.SetDefault("server.mode", "debug")
    viper.SetDefault("server.read_timeout", 30)
    viper.SetDefault("server.write_timeout", 30)
    
    viper.SetDefault("database.host", "localhost")
    viper.SetDefault("database.port", 5432)
    viper.SetDefault("database.sslmode", "disable")
    
    viper.SetDefault("redis.host", "localhost")
    viper.SetDefault("redis.port", 6379)
    viper.SetDefault("redis.db", 0)
    
    viper.SetDefault("kafka.brokers", []string{"localhost:9092"})
    viper.SetDefault("kafka.group_id", "catalog-service-group")
    
    viper.SetDefault("log.level", "info")
}
```

### Product Entity (internal/domain/entities/product.go)
```go
package entities

import (
    "time"
    "gorm.io/gorm"
)

type Product struct {
    ID          string         `json:"id" gorm:"primaryKey;type:varchar(255)"`
    SKU         string         `json:"sku" gorm:"uniqueIndex;not null;type:varchar(100)"`
    Name        string         `json:"name" gorm:"not null;type:varchar(255)"`
    Description *string        `json:"description" gorm:"type:text"`
    Slug        string         `json:"slug" gorm:"uniqueIndex;not null;type:varchar(255)"`
    CategoryID  string         `json:"category_id" gorm:"not null;type:varchar(255)"`
    BrandID     string         `json:"brand_id" gorm:"not null;type:varchar(255)"`
    Attributes  ProductAttrs   `json:"attributes" gorm:"type:jsonb"`
    Status      ProductStatus  `json:"status" gorm:"type:varchar(20);default:'DRAFT'"`
    IsVisible   bool           `json:"is_visible" gorm:"default:false"`
    IsFeatured  bool           `json:"is_featured" gorm:"default:false"`
    CreatedAt   time.Time      `json:"created_at"`
    UpdatedAt   time.Time      `json:"updated_at"`
    DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`
    CreatedBy   string         `json:"created_by" gorm:"not null;type:varchar(255)"`
    UpdatedBy   *string        `json:"updated_by" gorm:"type:varchar(255)"`
    
    // Relations
    Category Category `json:"category" gorm:"foreignKey:CategoryID"`
    Brand    Brand    `json:"brand" gorm:"foreignKey:BrandID"`
    Media    []Media  `json:"media" gorm:"foreignKey:ProductID"`
}

type ProductAttrs map[string]interface{}

type ProductStatus string

const (
    ProductStatusDraft        ProductStatus = "DRAFT"
    ProductStatusActive       ProductStatus = "ACTIVE"
    ProductStatusInactive     ProductStatus = "INACTIVE"
    ProductStatusDiscontinued ProductStatus = "DISCONTINUED"
)

type Category struct {
    ID          string         `json:"id" gorm:"primaryKey;type:varchar(255)"`
    Name        string         `json:"name" gorm:"not null;type:varchar(255)"`
    Slug        string         `json:"slug" gorm:"uniqueIndex;not null;type:varchar(255)"`
    Description *string        `json:"description" gorm:"type:text"`
    ParentID    *string        `json:"parent_id" gorm:"type:varchar(255)"`
    IsVisible   bool           `json:"is_visible" gorm:"default:true"`
    SortOrder   int            `json:"sort_order" gorm:"default:0"`
    CreatedAt   time.Time      `json:"created_at"`
    UpdatedAt   time.Time      `json:"updated_at"`
    DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`
    
    // Relations
    Parent   *Category  `json:"parent" gorm:"foreignKey:ParentID"`
    Children []Category `json:"children" gorm:"foreignKey:ParentID"`
    Products []Product  `json:"products" gorm:"foreignKey:CategoryID"`
}

type Brand struct {
    ID          string         `json:"id" gorm:"primaryKey;type:varchar(255)"`
    Name        string         `json:"name" gorm:"uniqueIndex;not null;type:varchar(255)"`
    Slug        string         `json:"slug" gorm:"uniqueIndex;not null;type:varchar(255)"`
    Description *string        `json:"description" gorm:"type:text"`
    LogoURL     *string        `json:"logo_url" gorm:"type:varchar(500)"`
    WebsiteURL  *string        `json:"website_url" gorm:"type:varchar(500)"`
    IsActive    bool           `json:"is_active" gorm:"default:true"`
    CreatedAt   time.Time      `json:"created_at"`
    UpdatedAt   time.Time      `json:"updated_at"`
    DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`
    
    // Relations
    Products []Product `json:"products" gorm:"foreignKey:BrandID"`
}

type Media struct {
    ID        string    `json:"id" gorm:"primaryKey;type:varchar(255)"`
    ProductID string    `json:"product_id" gorm:"not null;type:varchar(255)"`
    Type      MediaType `json:"type" gorm:"type:varchar(20);not null"`
    URL       string    `json:"url" gorm:"not null;type:varchar(500)"`
    AltText   *string   `json:"alt_text" gorm:"type:varchar(255)"`
    Title     *string   `json:"title" gorm:"type:varchar(255)"`
    SortOrder int       `json:"sort_order" gorm:"default:0"`
    IsPrimary bool      `json:"is_primary" gorm:"default:false"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type MediaType string

const (
    MediaTypeImage    MediaType = "IMAGE"
    MediaTypeVideo    MediaType = "VIDEO"
    MediaTypeDocument MediaType = "DOCUMENT"
)

// BeforeCreate hook to generate ID
func (p *Product) BeforeCreate(tx *gorm.DB) error {
    if p.ID == "" {
        p.ID = generateID()
    }
    return nil
}

func (c *Category) BeforeCreate(tx *gorm.DB) error {
    if c.ID == "" {
        c.ID = generateID()
    }
    return nil
}

func (b *Brand) BeforeCreate(tx *gorm.DB) error {
    if b.ID == "" {
        b.ID = generateID()
    }
    return nil
}

func (m *Media) BeforeCreate(tx *gorm.DB) error {
    if m.ID == "" {
        m.ID = generateID()
    }
    return nil
}

// generateID generates a unique ID (implement your preferred ID generation)
func generateID() string {
    // Implementation depends on your ID generation strategy
    // Could use UUID, ULID, or custom format
    return "generated-id"
}
```

### Product Handler (internal/interfaces/http/handlers/product_handler.go)
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

    c.JSON(http.StatusOK, response)
}

// GetProduct godoc
// @Summary Get product by ID
// @Description Get product details by ID with optional customer context
// @Tags products
// @Accept json
// @Produce json
// @Param id path string true "Product ID"
// @Param customer_id query string false "Customer ID for personalization"
// @Success 200 {object} dto.ProductResponse
// @Failure 404 {object} dto.ErrorResponse
// @Failure 500 {object} dto.ErrorResponse
// @Router /api/v1/products/{id} [get]
func (h *ProductHandler) GetProduct(c *gin.Context) {
    productID := c.Param("id")
    customerID := c.Query("customer_id")

    if productID == "" {
        c.JSON(http.StatusBadRequest, dto.ErrorResponse{
            Error:   "Bad request",
            Message: "Product ID is required",
        })
        return
    }

    req := &dto.GetProductRequest{
        ProductID:  productID,
        CustomerID: customerID,
    }

    response, err := h.productService.GetProduct(c.Request.Context(), req)
    if err != nil {
        if errors.IsNotFound(err) {
            c.JSON(http.StatusNotFound, dto.ErrorResponse{
                Error:   "Not found",
                Message: "Product not found",
            })
            return
        }

        h.logger.WithError(err).Error("Failed to get product")
        c.JSON(http.StatusInternalServerError, dto.ErrorResponse{
            Error:   "Internal server error",
            Message: "Failed to retrieve product",
        })
        return
    }

    c.JSON(http.StatusOK, response)
}

// CreateProduct godoc
// @Summary Create new product
// @Description Create a new product
// @Tags products
// @Accept json
// @Produce json
// @Param product body dto.CreateProductRequest true "Product data"
// @Success 201 {object} dto.ProductResponse
// @Failure 400 {object} dto.ErrorResponse
// @Failure 500 {object} dto.ErrorResponse
// @Router /api/v1/products [post]
func (h *ProductHandler) CreateProduct(c *gin.Context) {
    var req dto.CreateProductRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, dto.ErrorResponse{
            Error:   "Bad request",
            Message: err.Error(),
        })
        return
    }

    // Get user ID from context (set by auth middleware)
    userID, exists := c.Get("user_id")
    if !exists {
        c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
            Error:   "Unauthorized",
            Message: "User authentication required",
        })
        return
    }

    req.CreatedBy = userID.(string)

    response, err := h.productService.CreateProduct(c.Request.Context(), &req)
    if err != nil {
        if errors.IsValidation(err) {
            c.JSON(http.StatusBadRequest, dto.ErrorResponse{
                Error:   "Validation error",
                Message: err.Error(),
            })
            return
        }

        h.logger.WithError(err).Error("Failed to create product")
        c.JSON(http.StatusInternalServerError, dto.ErrorResponse{
            Error:   "Internal server error",
            Message: "Failed to create product",
        })
        return
    }

    c.JSON(http.StatusCreated, response)
}

// UpdateProduct godoc
// @Summary Update product
// @Description Update an existing product
// @Tags products
// @Accept json
// @Produce json
// @Param id path string true "Product ID"
// @Param product body dto.UpdateProductRequest true "Product data"
// @Success 200 {object} dto.ProductResponse
// @Failure 400 {object} dto.ErrorResponse
// @Failure 404 {object} dto.ErrorResponse
// @Failure 500 {object} dto.ErrorResponse
// @Router /api/v1/products/{id} [put]
func (h *ProductHandler) UpdateProduct(c *gin.Context) {
    productID := c.Param("id")
    if productID == "" {
        c.JSON(http.StatusBadRequest, dto.ErrorResponse{
            Error:   "Bad request",
            Message: "Product ID is required",
        })
        return
    }

    var req dto.UpdateProductRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, dto.ErrorResponse{
            Error:   "Bad request",
            Message: err.Error(),
        })
        return
    }

    // Get user ID from context
    userID, exists := c.Get("user_id")
    if !exists {
        c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
            Error:   "Unauthorized",
            Message: "User authentication required",
        })
        return
    }

    req.ProductID = productID
    req.UpdatedBy = userID.(string)

    response, err := h.productService.UpdateProduct(c.Request.Context(), &req)
    if err != nil {
        if errors.IsNotFound(err) {
            c.JSON(http.StatusNotFound, dto.ErrorResponse{
                Error:   "Not found",
                Message: "Product not found",
            })
            return
        }

        if errors.IsValidation(err) {
            c.JSON(http.StatusBadRequest, dto.ErrorResponse{
                Error:   "Validation error",
                Message: err.Error(),
            })
            return
        }

        h.logger.WithError(err).Error("Failed to update product")
        c.JSON(http.StatusInternalServerError, dto.ErrorResponse{
            Error:   "Internal server error",
            Message: "Failed to update product",
        })
        return
    }

    c.JSON(http.StatusOK, response)
}

// DeleteProduct godoc
// @Summary Delete product
// @Description Delete a product by ID
// @Tags products
// @Accept json
// @Produce json
// @Param id path string true "Product ID"
// @Success 204
// @Failure 404 {object} dto.ErrorResponse
// @Failure 500 {object} dto.ErrorResponse
// @Router /api/v1/products/{id} [delete]
func (h *ProductHandler) DeleteProduct(c *gin.Context) {
    productID := c.Param("id")
    if productID == "" {
        c.JSON(http.StatusBadRequest, dto.ErrorResponse{
            Error:   "Bad request",
            Message: "Product ID is required",
        })
        return
    }

    // Get user ID from context
    userID, exists := c.Get("user_id")
    if !exists {
        c.JSON(http.StatusUnauthorized, dto.ErrorResponse{
            Error:   "Unauthorized",
            Message: "User authentication required",
        })
        return
    }

    req := &dto.DeleteProductRequest{
        ProductID: productID,
        DeletedBy: userID.(string),
    }

    err := h.productService.DeleteProduct(c.Request.Context(), req)
    if err != nil {
        if errors.IsNotFound(err) {
            c.JSON(http.StatusNotFound, dto.ErrorResponse{
                Error:   "Not found",
                Message: "Product not found",
            })
            return
        }

        h.logger.WithError(err).Error("Failed to delete product")
        c.JSON(http.StatusInternalServerError, dto.ErrorResponse{
            Error:   "Internal server error",
            Message: "Failed to delete product",
        })
        return
    }

    c.Status(http.StatusNoContent)
}
```

### Health Handler (internal/interfaces/http/handlers/health_handler.go)
```go
package handlers

import (
    "net/http"
    "time"

    "github.com/ecommerce/my-catalog-service/internal/infrastructure/database"
    "github.com/ecommerce/my-catalog-service/internal/infrastructure/cache"
    "github.com/gin-gonic/gin"
    "github.com/go-redis/redis/v8"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "gorm.io/gorm"
)

type HealthHandler struct {
    db    *gorm.DB
    redis *redis.Client
}

func NewHealthHandler(db *gorm.DB, redis *redis.Client) *HealthHandler {
    return &HealthHandler{
        db:    db,
        redis: redis,
    }
}

type HealthResponse struct {
    Status    string    `json:"status"`
    Timestamp time.Time `json:"timestamp"`
    Service   string    `json:"service"`
    Version   string    `json:"version"`
    Uptime    string    `json:"uptime"`
}

type ReadinessResponse struct {
    Status string                 `json:"status"`
    Checks map[string]CheckResult `json:"checks"`
}

type CheckResult struct {
    Status  string `json:"status"`
    Message string `json:"message,omitempty"`
}

var startTime = time.Now()

// Health godoc
// @Summary Health check
// @Description Get service health status
// @Tags health
// @Produce json
// @Success 200 {object} HealthResponse
// @Router /health [get]
func (h *HealthHandler) Health(c *gin.Context) {
    uptime := time.Since(startTime)
    
    response := HealthResponse{
        Status:    "healthy",
        Timestamp: time.Now(),
        Service:   "catalog-service",
        Version:   "1.0.0", // This should come from build info
        Uptime:    uptime.String(),
    }

    c.JSON(http.StatusOK, response)
}

// Ready godoc
// @Summary Readiness check
// @Description Check if service is ready to serve requests
// @Tags health
// @Produce json
// @Success 200 {object} ReadinessResponse
// @Failure 503 {object} ReadinessResponse
// @Router /ready [get]
func (h *HealthHandler) Ready(c *gin.Context) {
    checks := make(map[string]CheckResult)
    allReady := true

    // Check database
    if sqlDB, err := h.db.DB(); err != nil {
        checks["database"] = CheckResult{
            Status:  "unhealthy",
            Message: "Failed to get database connection",
        }
        allReady = false
    } else if err := sqlDB.Ping(); err != nil {
        checks["database"] = CheckResult{
            Status:  "unhealthy",
            Message: "Database ping failed",
        }
        allReady = false
    } else {
        checks["database"] = CheckResult{Status: "healthy"}
    }

    // Check Redis
    if err := h.redis.Ping(c.Request.Context()).Err(); err != nil {
        checks["redis"] = CheckResult{
            Status:  "unhealthy",
            Message: "Redis ping failed",
        }
        allReady = false
    } else {
        checks["redis"] = CheckResult{Status: "healthy"}
    }

    status := "ready"
    httpStatus := http.StatusOK
    if !allReady {
        status = "not ready"
        httpStatus = http.StatusServiceUnavailable
    }

    response := ReadinessResponse{
        Status: status,
        Checks: checks,
    }

    c.JSON(httpStatus, response)
}

// Metrics godoc
// @Summary Prometheus metrics
// @Description Get Prometheus metrics
// @Tags health
// @Produce text/plain
// @Success 200
// @Router /metrics [get]
func (h *HealthHandler) Metrics(c *gin.Context) {
    promhttp.Handler().ServeHTTP(c.Writer, c.Request)
}
```

### Makefile
```makefile
# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
BINARY_NAME=catalog-service
BINARY_UNIX=$(BINARY_NAME)_unix

# Build info
VERSION?=1.0.0
BUILD_TIME=$(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT=$(shell git rev-parse --short HEAD)
LDFLAGS=-ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"

.PHONY: all build clean test coverage deps run-dev docker-build docker-run migrate-up migrate-down seed

all: test build

build:
	$(GOBUILD) $(LDFLAGS) -o $(BINARY_NAME) -v ./cmd/server

build-linux:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o $(BINARY_UNIX) -v ./cmd/server

clean:
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_UNIX)

test:
	$(GOTEST) -v ./...

test-coverage:
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html

deps:
	$(GOMOD) download
	$(GOMOD) tidy

run-dev:
	$(GOCMD) run ./cmd/server

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
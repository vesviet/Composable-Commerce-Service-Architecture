# Microservices Consolidation Implementation Guide

## Quick Reference: Which Services Use What

### Database & Configuration
- **All 19 services:** auth, user, order, payment, pricing, warehouse, catalog, shipping, notification, customer, fulfillment, common-operations, promotion, loyalty-rewards, review, search, analytics, gateway, admin

### Health Checks
- **15 services:** auth, user, order, warehouse, customer, fulfillment, common-operations, catalog, promotion, loyalty-rewards, search, notification, review, shipping, payment

### HTTP Clients with Circuit Breaker
- **10 services:** order, catalog, warehouse, customer, payment, fulfillment, common-operations, review, search, analytics

### Event Publishing (Dapr)
- **14 services:** auth, order, payment, pricing, warehouse, catalog, shipping, fulfillment, notification, customer, promotion, loyalty-rewards, search, analytics

### Workers/Jobs
- **10 services:** order, payment, pricing, warehouse, catalog, shipping, fulfillment, common-operations, search, analytics

### Caching (Redis)
- **10 services:** order, catalog, pricing, warehouse, customer, review, search, analytics, fulfillment, promotion

### Authentication/Authorization
- **7 services:** auth, user, order, customer, gateway, admin, common-operations

### Middleware
- **7 services:** auth, order, promotion, gateway, common-operations, customer, fulfillment

### Validation
- **12 services:** auth, user, order, customer, payment, warehouse, catalog, fulfillment, promotion, review, search, analytics

---

## Phase 1: Health Checks (CRITICAL - Week 1)

### Step 1: Create Common Health Package

**File:** `common/observability/health/health.go`

```go
package health

import (
    "context"
    "encoding/json"
    "net/http"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "gorm.io/gorm"
    "github.com/redis/go-redis/v9"
)

type HealthResponse struct {
    Timestamp string            `json:"timestamp"`
    Status    string            `json:"status"`
    Version   string            `json:"version"`
    Service   string            `json:"service"`
    Uptime    string            `json:"uptime"`
    Details   map[string]string `json:"details"`
}

type ReadinessResponse struct {
    Timestamp string            `json:"timestamp"`
    Ready     bool              `json:"ready"`
    Message   string            `json:"message"`
    Checks    map[string]string `json:"checks,omitempty"`
}

type LivenessResponse struct {
    Timestamp string `json:"timestamp"`
    Alive     bool   `json:"alive"`
    Message   string `json:"message"`
}

type HealthChecker struct {
    db        *gorm.DB
    redis     *redis.Client
    logger    *log.Helper
    startTime time.Time
    service   string
    version   string
}

func NewHealthChecker(db *gorm.DB, redis *redis.Client, logger log.Logger, service, version string) *HealthChecker {
    return &HealthChecker{
        db:        db,
        redis:     redis,
        logger:    log.NewHelper(logger),
        startTime: time.Now(),
        service:   service,
        version:   version,
    }
}

func (hc *HealthChecker) HealthHandler(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
    defer cancel()
    
    dbStatus := "healthy"
    dbMessage := "Database connection is healthy"
    if err := hc.checkDatabase(ctx); err != nil {
        dbStatus = "unhealthy"
        dbMessage = err.Error()
    }
    
    redisStatus := "healthy"
    redisMessage := "Redis connection is healthy"
    if err := hc.checkRedis(ctx); err != nil {
        redisStatus = "unhealthy"
        redisMessage = err.Error()
    }
    
    status := "healthy"
    if dbStatus == "unhealthy" {
        status = "unhealthy"
    }
    
    uptime := time.Since(hc.startTime)
    response := &HealthResponse{
        Timestamp: time.Now().Format(time.RFC3339),
        Status:    status,
        Version:   hc.version,
        Service:   hc.service,
        Uptime:    uptime.String(),
        Details: map[string]string{
            "database_status":  dbStatus,
            "database_message": dbMessage,
            "redis_status":     redisStatus,
            "redis_message":    redisMessage,
        },
    }
    
    w.Header().Set("Content-Type", "application/json")
    if status == "unhealthy" {
        w.WriteHeader(http.StatusServiceUnavailable)
    } else {
        w.WriteHeader(http.StatusOK)
    }
    json.NewEncoder(w).Encode(response)
}

func (hc *HealthChecker) ReadinessHandler(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
    defer cancel()
    
    checks := make(map[string]string)
    ready := true
    message := "Service is ready"
    
    if err := hc.checkDatabase(ctx); err != nil {
        checks["database"] = "unhealthy: " + err.Error()
        ready = false
        message = "Service is not ready: database unavailable"
    } else {
        checks["database"] = "healthy"
    }
    
    if err := hc.checkRedis(ctx); err != nil {
        checks["redis"] = "unhealthy: " + err.Error()
        hc.logger.Warnf("Redis health check failed: %v", err)
    } else {
        checks["redis"] = "healthy"
    }
    
    response := &ReadinessResponse{
        Timestamp: time.Now().Format(time.RFC3339),
        Ready:     ready,
        Message:   message,
        Checks:    checks,
    }
    
    w.Header().Set("Content-Type", "application/json")
    if !ready {
        w.WriteHeader(http.StatusServiceUnavailable)
    } else {
        w.WriteHeader(http.StatusOK)
    }
    json.NewEncoder(w).Encode(response)
}

func (hc *HealthChecker) LivenessHandler(w http.ResponseWriter, r *http.Request) {
    response := &LivenessResponse{
        Timestamp: time.Now().Format(time.RFC3339),
        Alive:     true,
        Message:   "Service is alive",
    }
    
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(response)
}

func (hc *HealthChecker) checkDatabase(ctx context.Context) error {
    if hc.db == nil {
        return nil // Database not configured
    }
    
    sqlDB, err := hc.db.DB()
    if err != nil {
        return err
    }
    
    return sqlDB.PingContext(ctx)
}

func (hc *HealthChecker) checkRedis(ctx context.Context) error {
    if hc.redis == nil {
        return nil // Redis not configured
    }
    
    return hc.redis.Ping(ctx).Err()
}
```

### Step 2: Update Service HTTP Servers

**Example for auth service:**

```go
// auth/internal/server/http.go
import "gitlab.com/ta-microservices/common/observability/health"

func NewHTTPServer(cfg *config.AppConfig, s *service.AuthService, db *gorm.DB, rdb *redis.Client, logger log.Logger) *krathttp.Server {
    // ... existing code ...
    
    // Create health checker
    healthChecker := health.NewHealthChecker(db, rdb, logger, "auth-service", "v1.0.0")
    
    // Register health endpoints
    srv.HandleFunc("/health", healthChecker.HealthHandler)
    srv.HandleFunc("/health/ready", healthChecker.ReadinessHandler)
    srv.HandleFunc("/health/live", healthChecker.LivenessHandler)
    
    return srv
}
```

### Step 3: Remove Duplicate Health Files

Delete these files from each service:
- `auth/internal/service/health.go`
- `order/internal/service/health.go`
- `user/internal/service/health.go`
- `warehouse/internal/service/health.go`
- `customer/internal/service/health.go`
- ... (15 total)

### Step 4: Testing

```bash
# Test health endpoints
curl http://localhost:8080/health
curl http://localhost:8080/health/ready
curl http://localhost:8080/health/live
```

---

## Phase 2: Database Connection (Week 1-2)

### Step 1: Create Common Database Package

**File:** `common/utils/database.go`

```go
package utils

import (
    "context"
    "fmt"
    "os"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "github.com/redis/go-redis/v9"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    gormLogger "gorm.io/gorm/logger"
)

type DatabaseConfig struct {
    Source          string
    MaxOpenConns    int
    MaxIdleConns    int
    ConnMaxLifetime time.Duration
    ConnMaxIdleTime time.Duration
}

type RedisConfig struct {
    Addr         string
    Password     string
    DB           int
    DialTimeout  time.Duration
    ReadTimeout  time.Duration
    WriteTimeout time.Duration
}

func NewPostgresDB(cfg DatabaseConfig, logger log.Logger) *gorm.DB {
    logHelper := log.NewHelper(logger)
    
    // Priority: DATABASE_URL env var > config file
    dbSource := cfg.Source
    if dbURL := os.Getenv("DATABASE_URL"); dbURL != "" {
        dbSource = dbURL
        logHelper.Info("Using DATABASE_URL from environment variable")
    } else {
        logHelper.Infof("Using database source from config: %s", maskDBURL(dbSource))
    }
    
    db, err := gorm.Open(postgres.Open(dbSource), &gorm.Config{
        Logger: gormLogger.Default.LogMode(gormLogger.Silent),
    })
    if err != nil {
        logHelper.Fatalf("failed opening connection to postgres: %v", err)
    }
    
    sqlDB, err := db.DB()
    if err != nil {
        logHelper.Fatalf("failed to get underlying sql.DB: %v", err)
    }
    
    // Set connection pool settings
    maxOpenConns := cfg.MaxOpenConns
    if maxOpenConns == 0 {
        maxOpenConns = 100
    }
    maxIdleConns := cfg.MaxIdleConns
    if maxIdleConns == 0 {
        maxIdleConns = 20
    }
    connMaxLifetime := cfg.ConnMaxLifetime
    if connMaxLifetime == 0 {
        connMaxLifetime = 30 * time.Minute
    }
    connMaxIdleTime := cfg.ConnMaxIdleTime
    if connMaxIdleTime == 0 {
        connMaxIdleTime = 5 * time.Minute
    }
    
    sqlDB.SetMaxOpenConns(maxOpenConns)
    sqlDB.SetMaxIdleConns(maxIdleConns)
    sqlDB.SetConnMaxLifetime(connMaxLifetime)
    sqlDB.SetConnMaxIdleTime(connMaxIdleTime)
    
    logHelper.Infof("✅ Database connected (max_open=%d, max_idle=%d)", maxOpenConns, maxIdleConns)
    
    return db
}

func NewRedisClient(cfg RedisConfig, logger log.Logger) *redis.Client {
    logHelper := log.NewHelper(logger)
    
    // Priority: REDIS_ADDR env var > config file
    redisAddr := cfg.Addr
    if redisURL := os.Getenv("REDIS_ADDR"); redisURL != "" {
        redisAddr = redisURL
        logHelper.Info("Using REDIS_ADDR from environment variable")
    }
    
    rdb := redis.NewClient(&redis.Options{
        Addr:         redisAddr,
        Password:     cfg.Password,
        DB:           cfg.DB,
        DialTimeout:  cfg.DialTimeout,
        ReadTimeout:  cfg.ReadTimeout,
        WriteTimeout: cfg.WriteTimeout,
    })
    
    ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    defer cancel()
    
    if err := rdb.Ping(ctx).Err(); err != nil {
        logHelper.Fatalf("redis connect error: %v", err)
    }
    
    logHelper.Info("✅ Redis connected successfully")
    return rdb
}

func maskDBURL(url string) string {
    if len(url) > 20 {
        return url[:20] + "***"
    }
    return "***"
}
```

### Step 2: Update Services to Use Common Database

**Example for order service:**

```go
// order/internal/data/data.go
import "gitlab.com/ta-microservices/common/utils"

func NewDB(cfg *config.AppConfig, logger log.Logger) *gorm.DB {
    return utils.NewPostgresDB(utils.DatabaseConfig{
        Source:          cfg.Data.Database.Source,
        MaxOpenConns:    cfg.Data.Database.MaxOpenConns,
        MaxIdleConns:    cfg.Data.Database.MaxIdleConns,
        ConnMaxLifetime: cfg.Data.Database.ConnMaxLifetime,
        ConnMaxIdleTime: cfg.Data.Database.ConnMaxIdleTime,
    }, logger)
}

func NewRedis(cfg *config.AppConfig, logger log.Logger) *redis.Client {
    return utils.NewRedisClient(utils.RedisConfig{
        Addr:         cfg.Data.Redis.Addr,
        Password:     cfg.Data.Redis.Password,
        DB:           cfg.Data.Redis.DB,
        DialTimeout:  cfg.Data.Redis.DialTimeout,
        ReadTimeout:  cfg.Data.Redis.ReadTimeout,
        WriteTimeout: cfg.Data.Redis.WriteTimeout,
    }, logger)
}
```

---

## Phase 3: Configuration Management (Week 2)

### Step 1: Create Common Config Loader

**File:** `common/config/loader.go`

```go
package config

import (
    "fmt"
    "strings"
    
    "github.com/spf13/viper"
)

type ConfigLoader struct {
    configPath string
    envPrefix  string
}

func NewConfigLoader(configPath, envPrefix string) *ConfigLoader {
    return &ConfigLoader{
        configPath: configPath,
        envPrefix:  envPrefix,
    }
}

func (cl *ConfigLoader) Load(target interface{}) error {
    v := viper.New()
    
    v.SetConfigFile(cl.configPath)
    v.SetConfigType("yaml")
    v.SetEnvPrefix(cl.envPrefix)
    v.AutomaticEnv()
    v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
    
    if err := v.ReadInConfig(); err != nil {
        return fmt.Errorf("failed to read config file: %w", err)
    }
    
    if err := v.Unmarshal(target); err != nil {
        return fmt.Errorf("failed to unmarshal config: %w", err)
    }
    
    return nil
}
```

### Step 2: Create Base Config Struct

**File:** `common/config/base_config.go`

```go
package config

import "time"

type BaseAppConfig struct {
    Server   ServerConfig   `mapstructure:"server"`
    Data     DataConfig     `mapstructure:"data"`
    Consul   ConsulConfig   `mapstructure:"consul"`
    Trace    TraceConfig    `mapstructure:"trace"`
    Metrics  MetricsConfig  `mapstructure:"metrics"`
}

type ServerConfig struct {
    HTTP HTTPConfig `mapstructure:"http"`
    GRPC GRPCConfig `mapstructure:"grpc"`
}

type HTTPConfig struct {
    Network string        `mapstructure:"network"`
    Addr    string        `mapstructure:"addr"`
    Timeout time.Duration `mapstructure:"timeout"`
}

type GRPCConfig struct {
    Network string        `mapstructure:"network"`
    Addr    string        `mapstructure:"addr"`
    Timeout time.Duration `mapstructure:"timeout"`
}

type DataConfig struct {
    Database DatabaseConfig `mapstructure:"database"`
    Redis    RedisConfig    `mapstructure:"redis"`
}

type DatabaseConfig struct {
    Driver          string        `mapstructure:"driver"`
    Source          string        `mapstructure:"source"`
    MaxOpenConns    int           `mapstructure:"max_open_conns"`
    MaxIdleConns    int           `mapstructure:"max_idle_conns"`
    ConnMaxLifetime time.Duration `mapstructure:"conn_max_lifetime"`
    ConnMaxIdleTime time.Duration `mapstructure:"conn_max_idle_time"`
}

type RedisConfig struct {
    Addr         string        `mapstructure:"addr"`
    Password     string        `mapstructure:"password"`
    DB           int           `mapstructure:"db"`
    DialTimeout  time.Duration `mapstructure:"dial_timeout"`
    ReadTimeout  time.Duration `mapstructure:"read_timeout"`
    WriteTimeout time.Duration `mapstructure:"write_timeout"`
}

type ConsulConfig struct {
    Address    string `mapstructure:"address"`
    Scheme     string `mapstructure:"scheme"`
    Datacenter string `mapstructure:"datacenter"`
}

type TraceConfig struct {
    Endpoint string `mapstructure:"endpoint"`
}

type MetricsConfig struct {
    Enabled bool   `mapstructure:"enabled"`
    Path    string `mapstructure:"path"`
}
```

### Step 3: Update Services to Use Common Config Loader

**Example for order service:**

```go
// order/internal/config/config.go
import "gitlab.com/ta-microservices/common/config"

type OrderAppConfig struct {
    *config.BaseAppConfig
    ExternalServices ExternalServicesConfig `mapstructure:"external_services"`
    Business         BusinessConfig         `mapstructure:"business"`
}

func Init(configPath string, envPrefix string) (*OrderAppConfig, error) {
    loader := config.NewConfigLoader(configPath, envPrefix)
    
    cfg := &OrderAppConfig{
        BaseAppConfig: &config.BaseAppConfig{},
    }
    
    if err := loader.Load(cfg); err != nil {
        return nil, err
    }
    
    return cfg, nil
}
```

---

## Validation Checklist

### Before Consolidation
- [ ] All services have similar implementations
- [ ] No service-specific customizations that can't be parameterized
- [ ] Common package structure is in place
- [ ] Wire dependencies are properly configured

### During Consolidation
- [ ] Create common package with new implementation
- [ ] Update one service as pilot
- [ ] Test thoroughly
- [ ] Update remaining services
- [ ] Remove duplicate code

### After Consolidation
- [ ] All services use common implementation
- [ ] Tests pass for all services
- [ ] No performance regression
- [ ] Documentation updated
- [ ] Team trained on new patterns

---

## Common Pitfalls & Solutions

### Pitfall 1: Circular Dependencies
**Problem:** common package depends on service-specific code
**Solution:** Keep common package independent, use interfaces for extension

### Pitfall 2: Service-Specific Needs
**Problem:** One service needs different behavior
**Solution:** Use configuration or strategy pattern for customization

### Pitfall 3: Version Conflicts
**Problem:** Different services need different versions of common code
**Solution:** Use semantic versioning, maintain backward compatibility

### Pitfall 4: Testing Complexity
**Problem:** Hard to test common code with all service variations
**Solution:** Create comprehensive test suite, use mocks for dependencies

---

## Rollback Plan

If consolidation causes issues:

1. **Immediate:** Revert service to use local implementation
2. **Short-term:** Keep both implementations available
3. **Long-term:** Fix common package and re-migrate

---

## Success Metrics

- [ ] 3,150+ lines of code removed
- [ ] 50% reduction in maintenance effort
- [ ] 100% test coverage for common code
- [ ] Zero performance regression
- [ ] All services using common implementations
- [ ] Team comfortable with new patterns

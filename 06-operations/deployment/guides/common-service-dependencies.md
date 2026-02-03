# Common Service Dependencies Guide

**Mục đích**: Hướng dẫn cấu hình dependencies chung cho các microservices  
**Cập nhật**: December 27, 2025

---

## 📋 Tổng quan

Tài liệu này định nghĩa cách cấu hình các dependencies chung mà hầu hết microservices sử dụng, bao gồm database, Redis, Consul, và các infrastructure services.

---

## 🗄️ Database Configuration

### PostgreSQL Connection
```yaml
config:
  data:
    database:
      driver: postgres
      # Connection string format:
      # postgres://username:password@host:port/database_name?sslmode=disable
      source: ""  # Provided via environment variable or secret
      max_open_conns: 25
      max_idle_conns: 5
      conn_max_lifetime: 300s  # 5 minutes
      conn_max_idle_time: 60s  # 1 minute
      log_level: warn
```

### Database URL Standards
```yaml
# ✅ Correct - Use FQDN
DATABASE_URL: "postgres://user:pass@postgres.infrastructure.svc.cluster.local:5432/service_db?sslmode=disable"

# ❌ Wrong - Short name
DATABASE_URL: "postgres://user:pass@postgres:5432/service_db?sslmode=disable"
```

### Database Naming Convention
```yaml
# Pattern: {service_name}_db
auth_service: auth_db
catalog_service: catalog_db
customer_service: customer_db
order_service: order_db
payment_service: payment_db
user_service: user_db
# ... etc
```

### Database User Convention
```yaml
# Pattern: {service_name}_user
auth_service: auth_user
catalog_service: catalog_user
customer_service: customer_user
order_service: order_user
payment_service: payment_user
user_service: user_user
# ... etc
```

---

## 🔴 Redis Configuration

### Redis Connection
```yaml
config:
  data:
    redis:
      addr: "redis.infrastructure.svc.cluster.local:6379"  # FQDN required
      password: ""  # Set via secret if Redis has auth
      db: {unique_number}  # Must be unique per service
      max_retries: 3
      pool_size: 10
      dial_timeout: 5s
      read_timeout: 0.2s
      write_timeout: 0.2s
```

### Redis DB Number Assignments
```yaml
# Documented DB assignments (must be unique)
auth-service: 0
catalog-service: 4
customer-service: 6
fulfillment-service: 7
gateway: 1
location-service: 8
notification-service: 2
order-service: 3      # Updated from 0 to avoid conflict
payment-service: 11
pricing-service: 9
promotion-service: 10
review-service: 12
search-service: 13
shipping-service: 14
user-service: 5
warehouse-service: 15

# Reserved for future services: 16-31
# Note: Redis supports 16 databases by default (0-15)
# If more needed, configure Redis with more databases
```

### Redis Usage Patterns
```yaml
# Cache configuration per service
config:
  cache:
    # Service-specific cache TTL
    default_ttl: 3600s      # 1 hour
    user_profile_ttl: 1800s # 30 minutes
    product_ttl: 7200s      # 2 hours
    category_ttl: 14400s    # 4 hours
```

---

## 🔍 Service Discovery (Consul)

### Consul Configuration
```yaml
config:
  consul:
    address: "consul.infrastructure.svc.cluster.local:8500"  # FQDN required
    scheme: "http"
    datacenter: "dc1"
    health_check: true
    health_check_interval: 10s
    health_check_timeout: 3s
    deregister_critical_service_after: true
    deregister_critical_service_after_duration: 30s
```

### Service Registration Pattern
```yaml
# Services register themselves with Consul using this pattern:
service_name: "{service-name}"
service_id: "{service-name}-{instance-id}"
service_address: "{pod-ip}"
service_port: {targetHttpPort}
health_check_url: "http://{pod-ip}:{targetHttpPort}/health"
```

### Service Discovery Usage
```go
// Example: Discovering other services via Consul
consulClient := consul.NewClient(consulConfig)
services, err := consulClient.Health().Service("catalog-service", "", true, nil)
if err != nil {
    return err
}

// Use first healthy instance
if len(services) > 0 {
    service := services[0]
    endpoint := fmt.Sprintf("http://%s:%d", service.Service.Address, service.Service.Port)
}
```

---

## 📊 Observability

### Distributed Tracing (Jaeger)
```yaml
config:
  trace:
    endpoint: "http://jaeger.infrastructure.svc.cluster.local:14268/api/traces"
    enabled: true
    service_name: "{service-name}"
    sample_rate: 0.1  # 10% sampling in production
```

### Metrics (Prometheus)
```yaml
config:
  metrics:
    enabled: true
    path: "/metrics"
    port: 9090  # Standard Prometheus port
```

### Logging
```yaml
config:
  log:
    level: "info"      # debug, info, warn, error
    format: "json"     # json, text
    enable_caller: true
    enable_stacktrace: false  # Only for error level
```

---

## 🔐 Security Dependencies

### JWT Configuration
```yaml
config:
  security:
    jwt:
      secret: ""  # Provided via secret
      access_token_expire: 86400s   # 24 hours
      refresh_token_expire: 604800s # 7 days
      issuer: "microservices"
```

### Encryption
```yaml
config:
  security:
    encryption:
      key: ""  # Provided via secret (32 bytes for AES-256)
      algorithm: "AES-256-GCM"
```

### CORS (Development only)
```yaml
config:
  security:
    cors:
      allowed_origins: ["*"]  # Staging only, production handled by ingress
      allowed_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      allowed_headers: ["*"]
      allow_credentials: true
```

---

## 🔄 Event Bus (Dapr)

### Pub/Sub Configuration
```yaml
config:
  data:
    eventbus:
      default_pubsub: "pubsub-redis"  # Dapr component name
      topic:
        user_created: "user.created"
        order_placed: "order.placed"
        payment_processed: "payment.processed"
        # ... service-specific topics
```

### Event Publishing Pattern
```go
// Example: Publishing events via Dapr
daprClient := dapr.NewClient()
data := UserCreatedEvent{
    UserID: "user-123",
    Email:  "user@example.com",
}

err := daprClient.PublishEvent(ctx, "pubsub-redis", "user.created", data)
```

### Event Subscription Pattern
```go
// Example: Subscribing to events via Dapr
func (s *Service) HandleUserCreated(ctx context.Context, e *common.TopicEvent) error {
    var event UserCreatedEvent
    if err := json.Unmarshal(e.Data, &event); err != nil {
        return err
    }
    
    // Process event
    return s.processUserCreated(ctx, event)
}
```

---

## 🌐 External Service Communication

### HTTP Client Configuration
```yaml
config:
  external_services:
    notification_service:
      endpoint: "http://notification-service:80"
      timeout: 5s
      retry_attempts: 3
      retry_delay: 1s
    catalog_service:
      endpoint: "http://catalog-service:80"
      grpc_endpoint: "catalog-service:81"  # If gRPC needed
      timeout: 5s
      retry_attempts: 3
      retry_delay: 1s
```

### Service Communication Patterns

#### HTTP Communication
```go
// Example: HTTP client with timeout and retry
httpClient := &http.Client{
    Timeout: 5 * time.Second,
}

// Use circuit breaker pattern for resilience
breaker := circuitbreaker.NewCircuitBreaker(
    circuitbreaker.WithFailureThreshold(5),
    circuitbreaker.WithRecoveryTimeout(30*time.Second),
)
```

#### gRPC Communication
```go
// Example: gRPC client with timeout
conn, err := grpc.Dial(
    "catalog-service:81",
    grpc.WithInsecure(),
    grpc.WithTimeout(5*time.Second),
)
if err != nil {
    return err
}
defer conn.Close()

client := catalogpb.NewCatalogServiceClient(conn)
```

---

## 🔧 Init Containers (Dependency Checks)

### Standard Init Containers
```yaml
initContainers:
  enabled: true
  postgres:
    enabled: true
    image: curlimages/curl:latest
    timeout: 30
    retries: 10
    command: |
      until curl -f http://postgres.infrastructure.svc.cluster.local:5432; do
        echo "Waiting for PostgreSQL..."
        sleep 3
      done
  redis:
    enabled: true
    image: redis:7-alpine
    timeout: 10
    retries: 5
    command: |
      until redis-cli -h redis.infrastructure.svc.cluster.local ping; do
        echo "Waiting for Redis..."
        sleep 2
      done
  consul:
    enabled: true
    image: curlimages/curl:latest
    timeout: 10
    retries: 5
    command: |
      until curl -f http://consul.infrastructure.svc.cluster.local:8500/v1/status/leader; do
        echo "Waiting for Consul..."
        sleep 2
      done
```

---

## 📦 Common Package Integration

### Using Common Config Package
```go
// Example: Using common config package
import "common/config"

type ServiceConfig struct {
    config.BaseAppConfig  // Inherit common config
    
    // Service-specific config
    Business BusinessConfig `mapstructure:"business" yaml:"business"`
}

type BusinessConfig struct {
    MaxItemsPerOrder int           `mapstructure:"max_items_per_order" yaml:"max_items_per_order"`
    OrderTimeout     time.Duration `mapstructure:"order_timeout" yaml:"order_timeout"`
}
```

### Configuration Loading
```go
// Example: Loading configuration
func LoadConfig() (*ServiceConfig, error) {
    loader := config.NewConfigLoader()
    
    var cfg ServiceConfig
    if err := loader.Load(&cfg); err != nil {
        return nil, err
    }
    
    return &cfg, nil
}
```

---

## 🔍 Health Check Dependencies

### Standard Health Check Endpoints
```yaml
# All services should implement these endpoints:
/health       # Overall health (liveness + readiness)
/health/live  # Liveness probe (service is running)
/health/ready # Readiness probe (service is ready to serve traffic)
```

### Health Check Implementation Pattern
```go
// Example: Health check with dependency checks
func (s *Service) HealthCheck(ctx context.Context) error {
    // Check database connection
    if err := s.db.PingContext(ctx); err != nil {
        return fmt.Errorf("database unhealthy: %w", err)
    }
    
    // Check Redis connection
    if err := s.redis.Ping(ctx).Err(); err != nil {
        return fmt.Errorf("redis unhealthy: %w", err)
    }
    
    // Check Consul connection
    if _, err := s.consul.Status().Leader(); err != nil {
        return fmt.Errorf("consul unhealthy: %w", err)
    }
    
    return nil
}
```

---

## 🚨 Common Issues và Solutions

### 1. Database Connection Issues
**Symptoms**: 
- Connection refused
- Connection timeout
- Too many connections

**Solutions**:
```yaml
# Use FQDN
database:
  source: "postgres://user:pass@postgres.infrastructure.svc.cluster.local:5432/db"
  
# Proper connection pooling
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: 300s
```

### 2. Redis Connection Issues
**Symptoms**:
- Redis connection timeout
- DB conflicts between services

**Solutions**:
```yaml
# Use FQDN and unique DB numbers
redis:
  addr: "redis.infrastructure.svc.cluster.local:6379"
  db: {unique_number}  # Check assignment table
```

### 3. Service Discovery Issues
**Symptoms**:
- Cannot find other services
- Consul registration fails

**Solutions**:
```yaml
# Use FQDN for Consul
consul:
  address: "consul.infrastructure.svc.cluster.local:8500"
  
# Proper health check configuration
  health_check: true
  health_check_interval: 10s
```

### 4. Init Container Failures
**Symptoms**:
- Pod stuck in Init state
- Dependency check timeouts

**Solutions**:
```yaml
# Proper timeout and retry settings
initContainers:
  postgres:
    timeout: 30
    retries: 10
  redis:
    timeout: 10
    retries: 5
```

---

## 📋 Dependency Checklist

### Pre-deployment
- [ ] Database URL uses FQDN
- [ ] Redis address uses FQDN and unique DB number
- [ ] Consul address uses FQDN
- [ ] All secrets are properly configured
- [ ] Init containers are configured for critical dependencies
- [ ] Health checks include dependency checks

### Post-deployment
- [ ] Service connects to database successfully
- [ ] Service connects to Redis successfully
- [ ] Service registers with Consul
- [ ] Health checks pass
- [ ] Service can communicate with other services
- [ ] Events are published/consumed correctly

---

## 📚 References

- [Service Configuration Guide](./service-configuration-guide.md)
- [Common Config Package](../common/config/README.md)
- [Infrastructure Services](../../argocd/applications/infrastructure/)
- [Dapr Documentation](https://docs.dapr.io/)
- [Consul Documentation](https://www.consul.io/docs)

---

**Tác giả**: DevOps Team  
**Cập nhật**: December 27, 2025  
**Version**: 1.0
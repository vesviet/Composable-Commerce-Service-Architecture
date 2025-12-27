# Configuration Best Practices

**Mục đích**: Best practices cho việc cấu hình microservices  
**Cập nhật**: December 27, 2025

---

## 🎯 Nguyên tắc cơ bản

### 1. Consistency First
- Tất cả services phải follow cùng một pattern
- Sử dụng common configuration structures
- Standardize naming conventions

### 2. Security by Default
- Secrets không được hardcode trong config
- Sử dụng SOPS encryption cho sensitive data
- Apply principle of least privilege

### 3. Environment Parity
- Configuration phải consistent giữa staging và production
- Chỉ khác biệt về resources và replicas
- Sử dụng environment-specific overrides

### 4. Observability Built-in
- Tất cả services phải có health checks
- Enable tracing và metrics by default
- Structured logging với consistent format

---

## 🏗️ Configuration Structure Best Practices

### 1. Hierarchical Configuration
```yaml
# Base configuration (values.yaml)
config:
  server:      # Server-level config
    http: {}
    grpc: {}
  data:        # Data layer config
    database: {}
    redis: {}
  business:    # Business logic config
    service_specific: {}
  security:    # Security config
    jwt: {}
    cors: {}
```

### 2. Environment Overrides
```yaml
# staging/values.yaml - Only override what's different
replicaCount: 1
resources:
  limits:
    cpu: 300m
    memory: 512Mi

# production/values.yaml - Production-specific overrides
replicaCount: 2
resources:
  limits:
    cpu: 500m
    memory: 1Gi
autoscaling:
  enabled: true
```

### 3. Secrets Separation
```yaml
# values.yaml - Empty secrets (placeholders)
secrets:
  databaseUrl: ""
  jwtSecret: ""

# staging/secrets.yaml - SOPS encrypted
secrets:
  databaseUrl: ENC[AES256_GCM,data:...,tag:...]
  jwtSecret: ENC[AES256_GCM,data:...,tag:...]
```

---

## 🔧 Configuration Patterns

### 1. Common Configuration Pattern
```yaml
# Use common config package
import "common/config"

type ServiceConfig struct {
    config.BaseAppConfig  // Common config
    
    // Service-specific config
    Business BusinessConfig `yaml:"business"`
}
```

### 2. Feature Flags Pattern
```yaml
config:
  features:
    enable_new_feature: false
    enable_analytics: true
    enable_caching: true
    debug_mode: false  # Never true in production
```

### 3. Circuit Breaker Pattern
```yaml
config:
  circuit_breaker:
    failure_threshold: 5
    recovery_timeout: 30s
    timeout: 5s
    max_requests: 100
```

### 4. Retry Pattern
```yaml
config:
  retry:
    max_attempts: 3
    initial_delay: 1s
    max_delay: 10s
    backoff_multiplier: 2.0
```

---

## 🔐 Security Best Practices

### 1. Secrets Management
```yaml
# ✅ Good - Use secrets
secrets:
  databaseUrl: ""  # Loaded from SOPS encrypted file

# ❌ Bad - Hardcoded
config:
  database:
    url: "postgres://user:password@host:5432/db"  # Never do this
```

### 2. Environment Variable Injection
```yaml
# Template pattern for secrets
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "service.fullname" . }}-secret
        key: databaseUrl
```

### 3. RBAC Configuration
```yaml
serviceAccount:
  create: true
  annotations:
    # Add RBAC annotations if needed
  name: ""

# Define minimal required permissions
rbac:
  create: true
  rules:
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list"]
```

---

## 📊 Resource Management Best Practices

### 1. Resource Categories
```yaml
# Category 1: Lightweight Services (auth, notification)
resources:
  limits:
    cpu: 300m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

# Category 2: Standard Services (most services)
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 512Mi

# Category 3: Heavy Services (gateway, catalog, search)
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

### 2. Autoscaling Configuration
```yaml
# High-traffic services
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Low-traffic services
autoscaling:
  enabled: false  # Use fixed replicas
```

### 3. Resource Monitoring
```yaml
# Enable resource monitoring
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s

# Resource alerts (example)
alerts:
  cpu_usage_high: 80
  memory_usage_high: 85
  pod_restart_high: 5
```

---

## 🏥 Health Check Best Practices

### 1. Standardized Health Endpoints
```yaml
# All services must implement
/health       # Combined liveness + readiness
/health/live  # Liveness only (is service running?)
/health/ready # Readiness only (is service ready to serve?)
```

### 2. Health Check Configuration
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 80
  initialDelaySeconds: 60  # Allow service startup time
  periodSeconds: 10        # Check every 10 seconds
  timeoutSeconds: 5        # 5 second timeout
  failureThreshold: 5      # 5 failures = restart pod

readinessProbe:
  httpGet:
    path: /health/ready
    port: 80
  initialDelaySeconds: 30  # Faster than liveness
  periodSeconds: 5         # Check every 5 seconds
  timeoutSeconds: 3        # 3 second timeout
  failureThreshold: 3      # 3 failures = remove from service
```

### 3. Health Check Implementation
```go
// Example: Comprehensive health check
func (s *Service) HealthCheck(ctx context.Context) *HealthStatus {
    status := &HealthStatus{
        Status: "healthy",
        Checks: make(map[string]CheckResult),
    }
    
    // Check database
    if err := s.checkDatabase(ctx); err != nil {
        status.Checks["database"] = CheckResult{
            Status: "unhealthy",
            Error:  err.Error(),
        }
        status.Status = "unhealthy"
    } else {
        status.Checks["database"] = CheckResult{Status: "healthy"}
    }
    
    // Check Redis
    if err := s.checkRedis(ctx); err != nil {
        status.Checks["redis"] = CheckResult{
            Status: "unhealthy",
            Error:  err.Error(),
        }
        status.Status = "unhealthy"
    } else {
        status.Checks["redis"] = CheckResult{Status: "healthy"}
    }
    
    return status
}
```

---

## 🔄 Deployment Best Practices

### 1. Rolling Update Strategy
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%
    maxSurge: 25%
```

### 2. Pod Disruption Budget
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1  # Staging
  # minAvailable: 2  # Production
```

### 3. Init Containers for Dependencies
```yaml
initContainers:
  enabled: true
  postgres:
    enabled: true
    timeout: 30
    retries: 10
  redis:
    enabled: true
    timeout: 10
    retries: 5
```

---

## 📝 Configuration Validation

### 1. Helm Template Validation
```bash
# Validate Helm templates
helm template . --debug --dry-run

# Validate with specific values
helm template . -f staging/values.yaml --debug --dry-run
```

### 2. Configuration Schema Validation
```yaml
# Use JSON Schema for validation
config_schema:
  type: object
  required:
    - server
    - data
  properties:
    server:
      type: object
      required: [http, grpc]
    data:
      type: object
      required: [database, redis]
```

### 3. Environment-specific Validation
```bash
# Validate staging config
helm template . -f staging/values.yaml | kubectl apply --dry-run=client -f -

# Validate production config
helm template . -f production/values.yaml | kubectl apply --dry-run=client -f -
```

---

## 🔍 Monitoring và Observability

### 1. Metrics Configuration
```yaml
config:
  metrics:
    enabled: true
    path: "/metrics"
    port: 9090
    
# Service-specific metrics
business_metrics:
  orders_per_minute: true
  payment_success_rate: true
  cache_hit_rate: true
```

### 2. Logging Configuration
```yaml
config:
  log:
    level: "info"           # debug, info, warn, error
    format: "json"          # json, text
    enable_caller: true     # Include caller info
    enable_stacktrace: false # Only for errors
    
# Structured logging fields
log_fields:
  service: "order-service"
  version: "1.0.0"
  environment: "production"
```

### 3. Tracing Configuration
```yaml
config:
  trace:
    enabled: true
    endpoint: "http://jaeger.infrastructure.svc.cluster.local:14268/api/traces"
    service_name: "order-service"
    sample_rate: 0.1  # 10% sampling in production
```

---

## 🚨 Common Anti-patterns

### 1. Configuration Anti-patterns
```yaml
# ❌ Bad - Hardcoded values
config:
  database:
    url: "postgres://user:password@localhost:5432/db"
  
# ✅ Good - Use secrets and environment variables
secrets:
  databaseUrl: ""  # From encrypted secrets file
```

### 2. Resource Anti-patterns
```yaml
# ❌ Bad - No resource limits
resources: {}

# ❌ Bad - Excessive resources
resources:
  limits:
    cpu: 4000m
    memory: 8Gi

# ✅ Good - Appropriate resources
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 512Mi
```

### 3. Health Check Anti-patterns
```yaml
# ❌ Bad - No health checks
livenessProbe: {}
readinessProbe: {}

# ❌ Bad - Too aggressive
livenessProbe:
  initialDelaySeconds: 5   # Too short
  failureThreshold: 1      # Too aggressive

# ✅ Good - Reasonable settings
livenessProbe:
  initialDelaySeconds: 60
  failureThreshold: 5
```

---

## 📋 Configuration Review Checklist

### Pre-deployment Review
- [ ] Configuration follows standard structure
- [ ] Secrets are properly encrypted with SOPS
- [ ] Resources are appropriate for service category
- [ ] Health checks are configured correctly
- [ ] Dependencies use FQDN
- [ ] Init containers check critical dependencies
- [ ] PDB is configured for high availability
- [ ] Monitoring and observability are enabled

### Post-deployment Validation
- [ ] Service starts successfully
- [ ] Health checks pass
- [ ] Service registers with service discovery
- [ ] Metrics are being collected
- [ ] Logs are properly formatted
- [ ] Tracing data is being sent
- [ ] Service can communicate with dependencies

---

## 🔧 Tools và Automation

### 1. Configuration Management Tools
```bash
# SOPS for secrets encryption
sops -e -i staging/secrets.yaml

# Helm for templating
helm template . -f staging/values.yaml

# kubectl for validation
kubectl apply --dry-run=client -f -
```

### 2. Validation Scripts
```bash
#!/bin/bash
# validate-config.sh

echo "Validating Helm templates..."
helm template . --debug --dry-run > /dev/null

echo "Validating staging config..."
helm template . -f staging/values.yaml | kubectl apply --dry-run=client -f -

echo "Validating production config..."
helm template . -f production/values.yaml | kubectl apply --dry-run=client -f -

echo "Configuration validation complete!"
```

### 3. CI/CD Integration
```yaml
# .gitlab-ci.yml example
validate-config:
  stage: validate
  script:
    - helm template . --debug --dry-run
    - helm template . -f staging/values.yaml | kubectl apply --dry-run=client -f -
    - helm template . -f production/values.yaml | kubectl apply --dry-run=client -f -
```

---

## 📚 References

- [Service Configuration Guide](./service-configuration-guide.md)
- [Common Service Dependencies](./common-service-dependencies.md)
- [Kubernetes Configuration Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [12-Factor App Methodology](https://12factor.net/config)

---

**Tác giả**: DevOps Team  
**Cập nhật**: December 27, 2025  
**Version**: 1.0
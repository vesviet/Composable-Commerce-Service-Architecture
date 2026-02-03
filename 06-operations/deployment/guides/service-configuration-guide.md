# Service Configuration Guide

**Mục đích**: Hướng dẫn cấu hình chuẩn cho các microservices trong hệ thống  
**Cập nhật**: December 27, 2025

---

## 📋 Tổng quan

Tài liệu này định nghĩa các chuẩn cấu hình cho tất cả microservices trong hệ thống, đảm bảo tính nhất quán, bảo mật và khả năng maintain.

### Cấu trúc thư mục chuẩn
```
argocd/applications/{service-name}/
├── Chart.yaml                    # Helm chart metadata
├── values.yaml                   # Base configuration
├── staging/
│   ├── values.yaml               # Staging overrides
│   ├── tag.yaml                  # Staging image tag
│   └── secrets.yaml              # Staging secrets (SOPS encrypted)
├── production/
│   ├── values.yaml               # Production overrides
│   ├── tag.yaml                  # Production image tag
│   └── secrets.yaml              # Production secrets (SOPS encrypted)
└── templates/
    ├── _helpers.tpl              # Helper functions
    ├── deployment.yaml           # Main deployment
    ├── service.yaml              # Kubernetes Service
    ├── configmap.yaml            # ConfigMap (if needed)
    ├── secret.yaml               # Secret template
    ├── migration-job.yaml        # Migration job (database services)
    ├── worker-deployment.yaml    # Worker deployment (if has workers)
    ├── pdb.yaml                  # PodDisruptionBudget
    ├── servicemonitor.yaml       # ServiceMonitor (Prometheus)
    └── networkpolicy.yaml        # NetworkPolicy (security)
```

---

## 🏗️ Cấu hình cơ bản (values.yaml)

### 1. Image Configuration
```yaml
image:
  repository: registry-api.tanhdev.com/{service-name}
  pullPolicy: IfNotPresent
  tag: ""  # Set via {env}/tag.yaml

imagePullSecrets:
  - name: registry-api-tanhdev
```

**Lưu ý**:
- Repository phải follow pattern: `registry-api.tanhdev.com/{service-name}`
- Tag để trống, được set qua `{env}/tag.yaml`
- Luôn sử dụng `imagePullSecrets` cho private registry

### 2. Service Configuration
```yaml
service:
  type: ClusterIP
  httpPort: 80        # Standard HTTP port
  grpcPort: 81        # Standard gRPC port (if service has gRPC)
  targetHttpPort: 8016  # Actual service port (varies by service)
  targetGrpcPort: 9016  # Actual gRPC port (varies by service)
```

**Chuẩn ports**:
- Service ports: `80` (HTTP), `81` (gRPC) - **NHẤT QUÁN**
- Target ports: Varies by service - **OK** (service-specific)

### 3. Pod Security
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65532    # Non-root user
  fsGroup: 65532

securityContext: {}   # Additional security context if needed
```

### 4. Dapr Annotations
```yaml
podAnnotations:
  dapr.io/enabled: "true"
  dapr.io/app-id: "{service-name}"
  dapr.io/app-port: "{targetHttpPort}"  # Must match actual service port
  dapr.io/app-protocol: "http"          # "grpc" for workers
```

**Quan trọng**:
- `app-port` phải match với `targetHttpPort`
- Workers sử dụng `"grpc"` protocol
- Main services sử dụng `"http"` protocol

### 5. Resources (theo category)

#### Standard Service (hầu hết services)
```yaml
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 512Mi
```

#### High-traffic Service (gateway, catalog)
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

#### Worker Service
```yaml
resources:
  limits:
    cpu: 300m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi
```

### 6. Health Checks (CHUẨN HÓA)
```yaml
livenessProbe:
  httpGet:
    path: /health      # CHUẨN: /health (preferred)
    port: 80           # Service port, not target port
    scheme: HTTP
  initialDelaySeconds: 60  # Allow service to start
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 5

readinessProbe:
  httpGet:
    path: /health      # CHUẨN: /health (preferred)
    port: 80           # Service port, not target port
    scheme: HTTP
  initialDelaySeconds: 30  # Faster than liveness
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**Health Check Path Standards**:
- ✅ **Preferred**: `/health` (simple, standard)
- ✅ **Alternative**: `/api/v1/{service}/health` (if service uses API prefix)
- ❌ **Avoid**: Service-specific paths

### 7. PodDisruptionBudget
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1  # Staging: 1, Production: 2
```

### 8. Autoscaling
```yaml
autoscaling:
  enabled: false  # Staging: false, Production: true (for high-traffic)
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### 9. ServiceMonitor (Prometheus)
```yaml
serviceMonitor:
  enabled: false  # Enable if Prometheus Operator installed
  interval: 30s
  scrapeTimeout: 10s
  additionalLabels: {}
  relabelings: []
  metricRelabelings: []
```

### 10. NetworkPolicy (Security)
```yaml
networkPolicy:
  enabled: false  # Enable if cluster supports NetworkPolicy
  ingress:
    enabled: true
  egress:
    enabled: true
    allowHTTPS: false  # Allow HTTPS egress if needed
```

---

## ⚙️ Service-specific Configuration

### 1. Server Configuration
```yaml
config:
  server:
    http:
      addr: "0.0.0.0:{targetHttpPort}"  # Must match targetHttpPort
      timeout: 1s
    grpc:
      addr: "0.0.0.0:{targetGrpcPort}"  # Must match targetGrpcPort
      timeout: 1s
```

### 2. Data Layer Configuration
```yaml
config:
  data:
    database:
      driver: postgres
      # source provided via env var or secret
    redis:
      addr: "redis.infrastructure.svc.cluster.local:6379"  # FQDN required
      db: {unique_number}  # Unique per service
      read_timeout: 0.2s
      write_timeout: 0.2s
```

**Redis DB Numbers** (phải unique):
```yaml
# Documented DB assignments
auth-service: db: 0
catalog-service: db: 4
customer-service: db: 6
order-service: db: 0  # CONFLICT - needs update
payment-service: db: 11
# ... add more services
```

### 3. Service Discovery (Consul)
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

### 4. Tracing
```yaml
config:
  trace:
    endpoint: "http://jaeger.infrastructure.svc.cluster.local:14268/api/traces"
```

### 5. External Services
```yaml
config:
  external_services:
    notification_service:
      endpoint: "http://notification-service:80"
      timeout: 5s
    order_service:
      endpoint: "http://order-service:80"
      grpc_endpoint: "order-service:81"  # If gRPC needed
      timeout: 5s
```

### 6. Security Configuration
```yaml
config:
  security:
    cors:
      allowed_origins: ["*"]  # Staging only, production handled by ingress
      allowed_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      allowed_headers: ["*"]
      allow_credentials: true
    jwt:
      access_token_expire: 86400s
      refresh_token_expire: 604800s
      # secret provided via secrets
```

---

## 🔐 Secrets Management

### 1. Secrets Structure
```yaml
secrets:
  databaseUrl: ""      # Set via {env}/secrets.yaml
  encryptionKey: ""    # Set via {env}/secrets.yaml
  jwtSecret: ""        # Set via {env}/secrets.yaml
```

### 2. Environment Variables
```yaml
env:
  redisAddr: "redis.infrastructure.svc.cluster.local:6379"
  consulAddr: "consul.infrastructure.svc.cluster.local:8500"
  # Service-specific env vars
```

**Quan trọng**: Luôn sử dụng FQDN cho các service dependencies.

---

## 🔄 Migration Jobs (Database Services)

```yaml
migration:
  enabled: true
  restartPolicy: Never
  activeDeadlineSeconds: 600  # 10 minutes
  backoffLimit: 2             # Max 2 retries
  ttlSecondsAfterFinished: 300  # Clean up after 5 minutes
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
```

---

## 👷 Worker Configuration

```yaml
worker:
  enabled: true
  replicaCount: 1
  image:
    repository: registry-api.tanhdev.com/{service-name}
    pullPolicy: IfNotPresent
    tag: ""  # Uses same tag as main service
  podAnnotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "{service-name}-worker"
    dapr.io/app-port: "5005"      # Standard gRPC port for Dapr
    dapr.io/app-protocol: "grpc"  # Workers use gRPC
  resources:
    limits:
      cpu: 300m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

---

## 🌍 Environment-specific Overrides

### Staging (staging/values.yaml)
```yaml
replicaCount: 1

resources:
  limits:
    cpu: 300m      # Lower than production
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

podDisruptionBudget:
  minAvailable: 1  # Lower than production

autoscaling:
  enabled: false   # Disabled in staging
```

### Production (production/values.yaml)
```yaml
replicaCount: 2    # Higher availability

resources:
  limits:
    cpu: 500m      # Higher than staging
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 512Mi

podDisruptionBudget:
  minAvailable: 2  # Higher availability

autoscaling:
  enabled: true    # Enabled for high-traffic services
  minReplicas: 2
  maxReplicas: 10
```

---

## 🔍 Common Issues và Solutions

### 1. Port Mismatches
**Issue**: Health check fails vì port không match
**Solution**: 
- Health check sử dụng service port (80), không phải target port
- Dapr app-port phải match target port

### 2. Health Check Path Issues
**Issue**: Health endpoint không tồn tại
**Solution**:
- Verify health path exists trong service code
- Standardize tất cả services sử dụng `/health`

### 3. Resource Issues
**Issue**: OOMKilled hoặc CPU throttling
**Solution**:
- Set appropriate resources theo service category
- Monitor và adjust dựa trên actual usage

### 4. Database Connection Issues
**Issue**: Cannot connect to database
**Solution**:
- Sử dụng FQDN: `postgres.infrastructure.svc.cluster.local:5432`
- Verify database credentials trong secrets

### 5. Redis DB Conflicts
**Issue**: Multiple services sử dụng cùng Redis DB
**Solution**:
- Document và assign unique DB numbers
- Update conflicting services

---

## ✅ Configuration Checklist

### Pre-deployment Checklist
- [ ] Image repository follows pattern
- [ ] Service ports are standard (80/81)
- [ ] Health check path is `/health`
- [ ] Probe configurations match standard
- [ ] Resources match service category
- [ ] PDB is configured
- [ ] Dapr annotations are correct
- [ ] Database/Redis/Consul use FQDN
- [ ] Secrets are properly configured
- [ ] Migration job config is standard (if database service)
- [ ] Worker config is standard (if has workers)

### Post-deployment Verification
- [ ] Service starts successfully
- [ ] Health checks pass
- [ ] Service registers with Consul
- [ ] Database migrations run successfully
- [ ] Workers start and process jobs
- [ ] Metrics are collected (if enabled)
- [ ] Logs are properly formatted

---

## 📚 References

- [Common Config Package](../common/config/README.md)
- [Config Review Checklist](../../argocd/applications/CONFIG_REVIEW_CHECKLIST.md)
- [Config Standardization Checklist](../../argocd/applications/CONFIG_STANDARDIZATION_CHECKLIST.md)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

---

**Tác giả**: DevOps Team  
**Cập nhật**: December 27, 2025  
**Version**: 1.0
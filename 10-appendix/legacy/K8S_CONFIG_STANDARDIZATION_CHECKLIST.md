# Kubernetes Configuration Standardization Checklist

> **Mục đích:** Chuẩn hóa cấu hình K8s cho tất cả microservices trong môi trường local development (k3d)
> 
> **Áp dụng cho:** Tất cả services trong `/home/user/microservices/`
> 
> **Thời gian ước tính:** ~2 hours/service

---

## 📋 Pre-requisites

- [ ] K3d cluster đang chạy (`k3d cluster list`)
- [ ] kubectl configured (`kubectl cluster-info`)
- [ ] Local registry available (`k3d-local-registry:5000`)
- [ ] Service đã có Dockerfile working
- [ ] **Service MUST use Viper for config loading** (see Phase 2.3 for details)

## 🔄 Migration Order (IMPORTANT)

**Follow this order to avoid breaking changes:**

1. **Phase 2.3: Migrate to Viper FIRST** (before creating K8s manifests)
   - Update `internal/config/config.go` to use Viper
   - Update `cmd/<service>/main.go` to use `config.Init()`
   - Update `cmd/<service>/wire.go` to accept `*config.AppConfig`
   - Update ALL providers to use `*config.AppConfig` (not proto types)
   - Regenerate wire code: `go run github.com/google/wire/cmd/wire ./cmd/<service>`
   - Test build: `go build ./cmd/<service>/...`

2. **Phase 2.4: Migrate Worker (if exists)**
   - Update `cmd/worker/main.go` to use Viper
   - Update `cmd/worker/wire.go` to accept `*config.AppConfig`
   - Update ALL worker providers to use `*config.AppConfig`
   - Regenerate wire code: `go run github.com/google/wire/cmd/wire ./cmd/worker`
   - Test build: `go build ./cmd/worker/...`

3. **Phase 1: Directory Structure** (after Viper migration)

4. **Phase 2: Secrets Extraction** (after Viper migration)

5. **Phase 3: ConfigMap Creation** (after Viper migration)

6. **Phase 4: Deployment Manifest** (after Viper migration)

**Why this order?**
- Viper migration requires updating ALL providers (main service + worker)
- K8s manifests depend on Viper env var naming conventions
- Testing build after each step catches errors early

---

## 🎯 Service Information

**Service Name:** `_____________`  
**Current Status:** [ ] Working [ ] Broken [ ] Not deployed  
**Has Worker:** [ ] Yes [ ] No  
**Has Migration:** [ ] Yes [ ] No  
**Database:** [ ] PostgreSQL [ ] MySQL [ ] MongoDB [ ] None  
**Cache:** [ ] Redis [ ] Memcached [ ] None  

---

## Phase 1: Directory Structure Cleanup

### 1.1 Analyze Current Structure

```bash
cd /home/user/microservices/<SERVICE_NAME>

# Check existing config directories
ls -la | grep config
```

**Current structure:**
- [ ] Has `config/` directory (Go code)
- [ ] Has `configs/` directory (YAML files)
- [ ] Has embedded config in `config/config.yaml`
- [ ] Has multiple environment configs

**Document findings:**
```
config/
├── config.go          # [ ] Exists
├── loader.go          # [ ] Exists
└── config.yaml        # [ ] Exists (embedded)

configs/
├── config.yaml        # [ ] Exists
├── config-dev.yaml    # [ ] Exists
├── config-docker.yaml # [ ] Exists
└── config-local.yaml  # [ ] Exists
```

### 1.2 Create New Structure

```bash
# Create deploy directory
mkdir -p deploy/local

# Move K8s manifests
mv /home/user/microservices/k8s-local/services/<SERVICE_NAME>/* deploy/local/ 2>/dev/null || true
```

**Tasks:**
- [ ] Created `deploy/local/` directory
- [ ] Moved existing K8s manifests to `deploy/local/`
- [ ] Verified manifests copied correctly

### 1.3 Remove Duplicates

```bash
# Remove embedded config (if exists)
rm config/config.yaml 2>/dev/null || true

# Rename dev config to local
mv configs/config-dev.yaml configs/config-local.yaml 2>/dev/null || true
```

**Tasks:**
- [ ] Removed `config/config.yaml` (embedded)
- [ ] Renamed `config-dev.yaml` → `config-local.yaml`
- [ ] Kept `config-docker.yaml` for Docker Compose
- [ ] Kept `config.yaml` as production default

**Final structure:**
```
<SERVICE_NAME>/
├── config/                    # Go code only
│   ├── config.go             # Struct definitions
│   ├── loader.go             # Viper loader
│   └── defaults.go           # [OPTIONAL] Default values
├── configs/                   # Config files
│   ├── config.yaml           # Production/Default
│   ├── config-docker.yaml    # Docker Compose
│   └── config-local.yaml     # K8s local
└── deploy/
    └── local/                # K8s local manifests
        ├── configmap.yaml
        ├── secrets.yaml
        ├── deployment.yaml
        ├── deployment-worker.yaml  # [OPTIONAL]
        ├── service.yaml
        └── migration-job.yaml      # [OPTIONAL]
```

---

## Phase 2: Secrets Extraction

### 2.5.1 Identify Secrets

**Review current config and identify sensitive data:**

- [ ] Database credentials
  - Username: `_____________`
  - Password: `_____________`
  - Connection string: `_____________`

- [ ] Redis password: `_____________`

- [ ] API keys/tokens:
  - `_____________`
  - `_____________`

- [ ] Encryption keys: `_____________`

- [ ] Other secrets:
  - `_____________`
  - `_____________`

### 2.5.2 Create Secrets Manifest

```bash
cat > deploy/local/secrets.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: <SERVICE_NAME>-secrets
  namespace: development
type: Opaque
stringData:
  # Database
  database-url: "postgres://<USER>:<PASS>@postgres.infrastructure.svc.cluster.local:5432/<DB_NAME>?sslmode=disable"
  
  # Redis (if applicable)
  redis-password: ""
  
  # Encryption (if applicable)
  encryption-key: "dev-32-character-encryption-key"
  
  # Add other secrets as needed
  # api-key: ""
  # jwt-secret: ""
EOF
```

**Tasks:**
- [ ] Created `deploy/local/secrets.yaml`
- [ ] Added all database credentials
- [ ] Added Redis password (if applicable)
- [ ] Added encryption keys (if applicable)
- [ ] Added API keys/tokens (if applicable)
- [ ] Verified no secrets in ConfigMap

### 2.5.3 Document Secret Environment Variables

**IMPORTANT: Service MUST use Viper for config loading**

**Viper Configuration Pattern:**
- Use `github.com/spf13/viper` for config loading
- Set env prefix: `<SERVICE_PREFIX>` (e.g., `AUTH`, `GATEWAY`, `CATALOG`)
- Enable automatic env: `v.AutomaticEnv()`
- Set key replacer: `v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))`

**Example Viper Init (following auth/warehouse service pattern):**
```go
package config

import (
    "fmt"
    "strings"
    "github.com/spf13/viper"
)

// AppConfig holds all service configuration
type AppConfig struct {
    Server   ServerConfig   `mapstructure:"server"`
    Data     DataConfig     `mapstructure:"data"`
    // ... other config sections
}

// Init initializes the application configuration using Viper
func Init(configPath string, envPrefix string) (*AppConfig, error) {
    v := viper.New()
    
    // Set config file
    v.SetConfigFile(configPath)
    v.SetConfigType("yaml")
    
    // Enable environment variable override
    v.SetEnvPrefix(envPrefix)  // e.g., "AUTH", "GATEWAY", "WAREHOUSE"
    v.AutomaticEnv()
    v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
    
    // Read config file
    if err := v.ReadInConfig(); err != nil {
        return nil, fmt.Errorf("failed to read config file: %w", err)
    }
    
    // Unmarshal into struct
    var cfg AppConfig
    if err := v.Unmarshal(&cfg); err != nil {
        return nil, fmt.Errorf("failed to unmarshal config: %w", err)
    }
    
    return &cfg, nil
}
```

**CRITICAL: Update ALL Providers**
- **Main service:** Update `cmd/<service>/wire.go` to accept `*config.AppConfig`
- **Worker (if exists):** Update `cmd/worker/wire.go` to accept `*config.AppConfig`
- **All providers:** Update function signatures to use `*config.AppConfig` instead of proto types (`*conf.Server`, `*conf.Data`, etc.)
- **NO converters:** Do NOT create converter functions - update providers directly
- **Regenerate wire:** After updating providers, regenerate: `go run github.com/google/wire/cmd/wire ./cmd/<service>`

**List all env var names for secrets:**

| Secret Key | Environment Variable Name (Viper) | Fallback (if needed) | Example Value |
|------------|-----------------------------------|----------------------|---------------|
| `database-url` | `<SERVICE>_DATA_DATABASE_SOURCE` | `DATABASE_URL` | `postgres://...` |
| `redis-password` | `<SERVICE>_DATA_REDIS_PASSWORD` | `REDIS_PASSWORD` | `""` |
| `encryption-key` | `<SERVICE>_SECURITY_ENCRYPTION_KEY` | `<SERVICE>_ENCRYPTION_KEY` | `dev-key...` |
| `jwt-secret` | `<SERVICE>_MIDDLEWARE_AUTH_JWT_SECRET` | `JWT_SECRET` | `secret-key...` |

> **Note:** 
> - **Primary:** Use Viper env var format: `<SERVICE_PREFIX>_<CONFIG_PATH_WITH_UNDERSCORES>`
> - **Fallback:** Support legacy env vars for backward compatibility (if code checks them)
> - **Example:** `GATEWAY_MIDDLEWARE_AUTH_JWT_SECRET` maps to `gateway.middleware.auth.jwt_secret` in config
> - **Example:** `AUTH_DATA_DATABASE_SOURCE` maps to `auth.data.database.source` in config

**Deployment env vars should include BOTH:**
```yaml
env:
  # Viper automatic env (primary)
  - name: GATEWAY_MIDDLEWARE_AUTH_JWT_SECRET
    valueFrom:
      secretKeyRef:
        name: gateway-secrets
        key: jwt-secret
  # Legacy fallback (if code checks it)
  - name: JWT_SECRET
    valueFrom:
      secretKeyRef:
        name: gateway-secrets
        key: jwt-secret
```

---

## Phase 2.4: Worker Migration (if service has worker)

**IMPORTANT: Migrate worker AFTER main service Viper migration**

### 2.4.1 Update Worker Main

```go
// cmd/worker/main.go
// Replace Kratos config loader with Viper
import (
    "gitlab.com/ta-microservices/<SERVICE>/internal/config"
)

func main() {
    // ... logger setup ...
    
    // Handle directory path
    configPath := flagconf
    if info, err := os.Stat(flagconf); err == nil && info.IsDir() {
        configPath = flagconf + "/config.yaml"
    }
    
    // Load config using Viper
    cfg, err := config.Init(configPath, "<SERVICE_PREFIX>")
    if err != nil {
        logHelper.Fatalf("Failed to load config: %v", err)
    }
    
    // Initialize dependencies using Wire
    workers, cleanup, err := wireWorkers(cfg, logger)
    // ...
}
```

### 2.4.2 Update Worker Wire

```go
// cmd/worker/wire.go
func wireWorkers(
    *config.AppConfig,  // Changed from proto types
    log.Logger,
) ([]base.Worker, func(), error) {
    panic(wire.Build(
        // ... providers ...
    ))
}
```

### 2.4.3 Update Worker Providers

**Update ALL worker providers to use `*config.AppConfig`:**

- [ ] Update cron job providers (if any)
- [ ] Update event consumer providers (if any)
- [ ] Update worker-specific providers
- [ ] Remove proto type dependencies (`*conf.Warehouse`, `*conf.AlertConfig`, etc.)
- [ ] Access config via `cfg.Warehouse.*`, `cfg.Data.*`, etc.

**Example:**
```go
// Before
func NewAlertCleanupJob(
    alertUsecase *alert.AlertUsecase,
    warehouseConfig *conf.Warehouse,
    logger log.Logger,
) *AlertCleanupJob

// After
func NewAlertCleanupJob(
    alertUsecase *alert.AlertUsecase,
    appConfig *config.AppConfig,
    logger log.Logger,
) *AlertCleanupJob {
    cleanupDays := 30
    if appConfig != nil && appConfig.Warehouse.AlertHistoryRetentionDays > 0 {
        cleanupDays = appConfig.Warehouse.AlertHistoryRetentionDays
    }
    // ...
}
```

### 2.4.4 Regenerate and Test

```bash
# Regenerate wire code
go run github.com/google/wire/cmd/wire ./cmd/worker

# Test build
go build ./cmd/worker/...

# Update Dockerfile (if worker build was commented out)
# Uncomment worker build section
```

**Tasks:**
- [ ] Updated `cmd/worker/main.go` to use Viper
- [ ] Updated `cmd/worker/wire.go` to accept `*config.AppConfig`
- [ ] Updated ALL worker providers to use `*config.AppConfig`
- [ ] Regenerated `cmd/worker/wire_gen.go`
- [ ] Tested build: `go build ./cmd/worker/...`
- [ ] Updated Dockerfile to build worker

---

## Phase 3: ConfigMap Creation

### 3.1 Extract Non-Secret Config

**Review `configs/config-docker.yaml` and extract non-sensitive config:**

```bash
# View current config
cat configs/config-docker.yaml
```

**Sections to include in ConfigMap:**
- [ ] Server configuration (ports, timeouts)
- [ ] Service-specific settings (cache TTL, pagination, etc.)
- [ ] Feature flags
- [ ] Service discovery (Consul, etc.)
- [ ] Observability (tracing, metrics)
- [ ] CORS settings
- [ ] Dapr subscriptions (if applicable)

### 3.2 Create ConfigMap Manifest

```bash
cat > deploy/local/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: <SERVICE_NAME>-config
  namespace: development
data:
  config.yaml: |
    server:
      http:
        addr: "0.0.0.0:80"
        timeout: 1s
      grpc:
        addr: "0.0.0.0:81"
        timeout: 1s
    
    data:
      database:
        driver: postgres
        # source loaded from secret env var
      redis:
        addr: "redis.infrastructure.svc.cluster.local:6379"
        db: 0
        read_timeout: 0.2s
        write_timeout: 0.2s
      consul:
        addr: "consul.infrastructure.svc.cluster.local:8500"
        scheme: "http"
    
    # Service-specific config
    <SERVICE_NAME>:
      # Add service-specific settings here
      cache:
        ttl: 3600s
      pagination:
        default_limit: 20
        max_limit: 100
    
    # Security (non-sensitive)
    security:
      cors:
        allowed_origins: ["*"]
        allowed_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
        allowed_headers: ["*"]
        allow_credentials: true
    
    # Observability
    trace:
      endpoint: http://jaeger.infrastructure.svc.cluster.local:14268/api/traces
EOF
```

**Tasks:**
- [ ] Created `deploy/local/configmap.yaml`
- [ ] Copied server configuration
- [ ] Copied database config (WITHOUT credentials)
- [ ] Copied Redis config (WITHOUT password)
- [ ] Copied service-specific settings
- [ ] Copied CORS settings
- [ ] Copied tracing configuration
- [ ] Copied Dapr subscriptions (if applicable)
- [ ] Verified NO secrets in ConfigMap

### 3.3 Validate ConfigMap

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f deploy/local/configmap.yaml

# Check for secrets (should return nothing)
grep -i "password\|secret\|token\|key" deploy/local/configmap.yaml | grep -v "# "
```

**Validation:**
- [ ] YAML syntax valid
- [ ] No secrets found in ConfigMap
- [ ] All service URLs use cluster DNS (`.svc.cluster.local`)

---

## Phase 4: Deployment Manifest

### 4.1 Update Main Deployment

See full deployment template in the checklist...

**Tasks:**
- [ ] Created/Updated `deploy/local/deployment.yaml`
- [ ] Set correct service name
- [ ] Set correct image name
- [ ] Set correct binary name in command
- [ ] Added all secret env vars (Viper pattern + fallback if needed)
- [ ] Updated health check paths
- [ ] Set appropriate resource limits
- [ ] Configured Dapr annotations (if needed)
- [ ] **Verified service uses Viper for config loading** (see Phase 2.3)

### 4.2 Update Worker Deployment (if applicable)

**Skip if service doesn't have worker**

### 4.3 Update Service Manifest

### 4.4 Update Migration Job (if applicable)

**Skip if service doesn't have migrations**

---

## Phase 5: Deployment Scripts

### 5.1 Create Service Deploy Script

```bash
mkdir -p scripts
# Create scripts/deploy-local.sh
chmod +x scripts/deploy-local.sh
```

### 5.2 Update k8s-local Deploy Script

### 5.3 Add Makefile Targets

---

## Phase 6: Testing & Validation

### 6.1 Pre-deployment Validation
### 6.2 Deploy Service
### 6.3 Verify Deployment
### 6.4 Test Secret Injection
### 6.5 Test Configuration

---

## Phase 7: Documentation

### 7.1 Update Service README
### 7.2 Create Migration Notes

---

## Phase 8: Cleanup & Finalization

### 8.1 Backup Old Manifests
### 8.2 Remove Old Files
### 8.3 Git Commit

---

## 📊 Final Checklist

### Structure
- [ ] `deploy/local/` directory created
- [ ] All manifests in `deploy/local/`
- [ ] Old `k8s-local/services/<SERVICE_NAME>/` removed
- [ ] Embedded `config/config.yaml` removed

### Secrets
- [ ] `secrets.yaml` created
- [ ] All secrets extracted from ConfigMap
- [ ] Secret env vars added to deployment
- [ ] Secrets tested and working

### ConfigMap
- [ ] `configmap.yaml` created
- [ ] No secrets in ConfigMap
- [ ] All non-sensitive config included
- [ ] ConfigMap tested and working

### Deployments
- [ ] Main deployment updated
- [ ] Worker deployment updated (if applicable)
- [ ] Migration job updated (if applicable)
- [ ] Service manifest updated
- [ ] All deployments tested

### Scripts
- [ ] `scripts/deploy-local.sh` created
- [ ] `k8s-local/deploy-<SERVICE_NAME>.sh` updated
- [ ] Makefile targets added
- [ ] All scripts tested

### Testing
- [ ] Service deploys successfully
- [ ] Pods running without errors
- [ ] Health checks passing
- [ ] Secrets injected correctly
- [ ] Config loaded correctly

### Documentation
- [ ] README.md updated
- [ ] Migration notes created
- [ ] Troubleshooting documented

### Git
- [ ] Changes committed
- [ ] Pushed to remote

---

## 🔧 Troubleshooting

### Pod not starting
### Secret not injected
### ConfigMap not mounted
### Migration failed

---

## 📝 Notes

**Service-specific customizations:**
- Update `<SERVICE_NAME>` placeholders
- Update `<SERVICE_PREFIX>` for env vars (usually uppercase service name)
- Adjust resource limits based on service needs
- Add service-specific config sections
- Update health check paths
- Add any service-specific secrets

**Time estimates:**
- Phase 1-2: 30 minutes
- Phase 3-4: 45 minutes
- Phase 5: 30 minutes
- Phase 6: 30 minutes
- Phase 7-8: 15 minutes
- **Total: ~2.5 hours per service**

**Batch processing:**
- Can process multiple services in parallel
- Recommend doing 2-3 services at a time
- Test each service before moving to next batch

---

## ✅ Completion

**Service:** `_____________`  
**Completed by:** `_____________`  
**Date:** `_____________`  
**Status:** [ ] Success [ ] Partial [ ] Failed  

**Notes:**
```
_____________________________________________
_____________________________________________
_____________________________________________
```

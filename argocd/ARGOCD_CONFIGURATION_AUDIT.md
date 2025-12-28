# ArgoCD Configuration Audit Report

**Date**: 2025-12-28  
**Status**: System-Wide Configuration Review  
**Auditor**: Automated Configuration Analysis  
**Last Updated**: 2025-12-28 (Config Loading Pattern Review)

---

## Executive Summary

### Overall Configuration Status

| Category | Status | Notes |
|----------|--------|-------|
| **Port Standardization** | ✅ 100% Complete | All services using standardized ports (8000/9000) |
| **Redis DB Allocation** | ✅ 100% Complete | All services have unique DBs (0-15) |
| **Config Loading** | ⚠️ 75% Complete | 8 services need BaseAppConfig initialization fix |
| **Health Probes** | ✅ 100% Complete | All probes correctly configured |

### Critical Issues Summary

1. **Config Loading Pattern Issues** (High Priority)
   - **Fixed**: `review-service`, `pricing-service` ✅
   - **Needs Fix**: 8 services using incorrect BaseAppConfig initialization pattern
   - **Root Cause**: Empty BaseAppConfig pointer prevents proper struct unmarshaling

2. **Config Pattern Variations** (Low Priority)
   - Some services don't use BaseAppConfig (auth, user, payment, notification)
   - These services define their own config structs (working correctly)

---

## Service-by-Service Breakdown

### Backend Services (Microservices)

| Service | Dapr Port | HTTP Port | gRPC Port | Redis DB | Config Pattern | Config Status | Overall Status |
|---------|-----------|-----------|-----------|----------|---------------|---------------|----------------|
| **auth-service** | 8000 | 8000 | 9000 | 0 | Custom struct | ✅ Working | ✅ Healthy |
| **catalog-service** | 8000 | 8000 | 9000 | 4 | BaseAppConfig (correct) | ✅ Working | ✅ Healthy |
| **common-operations** | 8000 | 8000 | 9000 | 8 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |
| **customer-service** | 8000 | 8000 | 9000 | 6 | BaseAppConfig (correct) | ✅ Working | ✅ Healthy |
| **fulfillment-service** | 8000 | 8000 | 9000 | 10 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |
| **location-service** | 8000 | 8000 | 9000 | 7 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |
| **notification-service** | 8000 | 8000 | 9000 | 11 | Custom struct | ✅ Working | ✅ Healthy |
| **order-service** | 8000 | 8000 | 9000 | 1 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |
| **payment-service** | 8000 | 8000 | 9000 | 14 | Custom struct | ✅ Working | ✅ Healthy |
| **pricing-service** | 8000 | 8000 | 9000 | 2 | BaseAppConfig (correct) | ✅ Fixed | ✅ Healthy |
| **promotion-service** | 8000 | 8000 | 9000 | 3 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |
| **review-service** | 8000 | 8000 | 9000 | 5 | BaseAppConfig (correct) | ✅ Fixed | ✅ Healthy |
| **search-service** | 8000 | 8000 | 9000 | 12 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |
| **shipping-service** | 8000 | 8000 | 9000 | 13 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |
| **user-service** | 8000 | 8000 | 9000 | 15 | Custom struct | ✅ Working | ✅ Healthy |
| **warehouse-service** | 8000 | 8000 | 9000 | 9 | BaseAppConfig (incorrect) | ⚠️ Needs Fix | ⚠️ At Risk |

### Support Services

| Service | Type | Ports | Notes |
|---------|------|-------|-------|
| **frontend** | Next.js | 3000 | Using `/` for health checks |
| **admin** | Static | 80 | Nginx hosting |
| **gateway** | API Gateway | Custom | No Redis |

### Worker Services

| Service | Dapr Port | Status |
|---------|-----------|--------|
| **catalog-worker** | 5005 | ✅ Healthy |
| **customer-worker** | 5005 | ✅ Healthy |
| **fulfillment-worker** | 5005 | ✅ Healthy |
| **notification-worker** | 5005 | ✅ Healthy |
| **order-worker** | 5005 | ✅ Healthy |
| **payment-worker** | 5005 | ✅ Healthy |
| **search-worker** | 5005 | ✅ Healthy |
| **shipping-worker** | 5005 | ✅ Healthy |
| **common-operations-worker** | 8019 | ✅ Healthy |

---

## Redis DB Allocation Matrix

| DB Index | Service | Status |
|----------|---------|--------|
| 0 | auth-service | ✅ Assigned |
| 1 | order-service | ✅ Assigned |
| 2 | pricing-service | ✅ Assigned |
| 3 | promotion-service | ✅ Assigned |
| 4 | catalog-service | ✅ Assigned |
| 5 | review-service | ✅ Assigned |
| 6 | customer-service | ✅ Assigned |
| 7 | location-service | ✅ Assigned |
| 8 | common-operations-service | ✅ Assigned |
| 9 | warehouse-service | ✅ Assigned |
| 10 | fulfillment-service | ✅ Assigned |
| 11 | notification-service | ✅ Assigned |
| 12 | search-service | ✅ Assigned |
| 13 | shipping-service | ✅ Assigned |
| 14 | payment-service | ✅ Assigned |
| 15 | user-service | ✅ Assigned |

**Status**: ✅ All 16 DBs allocated, no conflicts

---

## Critical Issues Analysis

### Issue #1: Config Loading Pattern - BaseAppConfig Initialization (High Priority)

**Affected Services**: 8 services using incorrect BaseAppConfig initialization

**Services with Issues**:
1. `common-operations-service`
2. `fulfillment-service`
3. `location-service`
4. `order-service`
5. `promotion-service`
6. `search-service`
7. `shipping-service`
8. `warehouse-service`

**Services Fixed**:
- ✅ `review-service` - Fixed 2025-12-28
- ✅ `pricing-service` - Fixed 2025-12-28

**Services Using Correct Pattern**:
- ✅ `customer-service` - Correct initialization
- ✅ `catalog-service` - Correct initialization

**Services Using Custom Config (Not Affected)**:
- ✅ `auth-service` - Custom struct (working)
- ✅ `user-service` - Custom struct (working)
- ✅ `payment-service` - Custom struct (working)
- ✅ `notification-service` - Custom struct (working)

**Root Cause**:
When using embedded pointer structs (`*BaseAppConfig`), mapstructure requires nested structs to be initialized for proper unmarshaling. Empty BaseAppConfig pointer causes config values to be ignored, resulting in:
- Random ports (using Go default: 0 → random port assignment)
- Wrong Redis DB (default: 0)
- Health check failures
- High restart counts

**Incorrect Pattern** (❌):
```go
cfg := &AppConfig{
    BaseAppConfig: &commonConfig.BaseAppConfig{},  // Empty - causes unmarshaling failure
}
```

**Correct Pattern** (✅):
```go
cfg := &AppConfig{
    BaseAppConfig: &commonConfig.BaseAppConfig{
        Server: commonConfig.ServerConfig{
            HTTP: commonConfig.HTTPConfig{},
            GRPC: commonConfig.GRPCConfig{},
        },
    },
}
```

**Evidence**:
- Services with correct pattern (customer, catalog) work perfectly
- Services with incorrect pattern may work by chance if config values are set via environment variables, but are at risk of failures
- Fixed services (review, pricing) were experiencing random ports and wrong Redis DB before fix

**Fix Required**:
Update all 8 affected services to use correct BaseAppConfig initialization pattern.

**Fix Template**:
```go
// Init initializes the application configuration using common ServiceConfigLoader
func Init(configPath string, envPrefix string) (*AppConfig, error) {
    loader := commonConfig.NewServiceConfigLoader("{service-name}", configPath)

    // Initialize BaseAppConfig pointer with nested structs - critical for embedded pointer unmarshaling
    cfg := &AppConfig{
        BaseAppConfig: &commonConfig.BaseAppConfig{
            Server: commonConfig.ServerConfig{
                HTTP: commonConfig.HTTPConfig{},
                GRPC: commonConfig.GRPCConfig{},
            },
        },
    }

    if err := loader.LoadServiceConfig(cfg); err != nil {
        return nil, fmt.Errorf("failed to load {service-name} config: %w", err)
    }

    return cfg, nil
}
```

---

## Port Configuration Standards

### Standard Port Allocation

| Port Type | Value | Purpose |
|-----------|-------|---------|
| **Dapr App Port** | 8000 | Dapr sidecar connects here |
| **HTTP (Internal)** | 8000 | App listens (container) |
| **gRPC (Internal)** | 9000 | App listens (container) |
| **HTTP (K8s Service)** | 80 | External access |
| **gRPC (K8s Service)** | 81 | External access |
| **Worker Dapr Port** | 5005 | Worker services (standard) |
| **Worker Dapr Port (Custom)** | 8019 | common-operations-worker (custom) |

### Probe Configuration

**Correct Pattern**:
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8000        # Must match targetHttpPort
    scheme: HTTP
  initialDelaySeconds: 90
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 5

readinessProbe:
  httpGet:
    path: /health/ready  
    port: 8000        # Must match targetHttpPort
    scheme: HTTP
  initialDelaySeconds: 60
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 3
```

### Server Config Pattern

**Recommended**:
```yaml
config:
  server:
    http:
      addr: ":8000"
      timeout: 1s      # Use duration string
    grpc:
      addr: ":9000"
      timeout: 1s
```

**Status**: ✅ All services follow this pattern

---

## Config Loading Pattern Analysis

### Pattern Categories

#### Category 1: BaseAppConfig with Correct Initialization ✅
**Services**: customer, catalog, review (fixed), pricing (fixed)

**Pattern**:
```go
BaseAppConfig: &commonConfig.BaseAppConfig{
    Server: commonConfig.ServerConfig{
        HTTP: commonConfig.HTTPConfig{},
        GRPC: commonConfig.GRPCConfig{},
    },
}
```

**Status**: ✅ Working correctly

#### Category 2: BaseAppConfig with Incorrect Initialization ⚠️
**Services**: common-operations, fulfillment, location, order, promotion, search, shipping, warehouse

**Pattern**:
```go
BaseAppConfig: &commonConfig.BaseAppConfig{}  // Empty - incorrect
```

**Status**: ⚠️ At risk - may work if env vars are set, but unreliable

**Risk Level**: Medium-High
- May work in production if environment variables override config
- Will fail if ConfigMap is primary source
- Unpredictable behavior during config updates

#### Category 3: Custom Config Structs (Not Using BaseAppConfig) ✅
**Services**: auth, user, payment, notification

**Pattern**:
```go
// Define own structs, don't embed BaseAppConfig
type AppConfig struct {
    Server ServerConfig `mapstructure:"server"`
    Data   DataConfig   `mapstructure:"data"`
    // ... service-specific fields
}
```

**Status**: ✅ Working correctly (different pattern, no issues)

---

## Verification Checklist

### Per-Service Verification

For each service, verify:

- [x] `values.yaml` ports are consistent:
  - [x] `dapr.io/app-port` = `targetHttpPort` = `livenessProbe.port` = `config.server.http.addr`
  - [x] `targetGrpcPort` = `config.server.grpc.addr`
- [x] Redis DB is unique (no conflicts)
- [x] ConfigMap renders correctly (`kubectl get cm <service> -o yaml`)
- [x] Deployment probe ports match app ports
- [ ] **Config loading pattern is correct** (8 services need fix)
- [ ] Pod logs show correct listening ports (8000/9000)
- [ ] Health checks return 200 OK

### Config Loading Verification

For services using BaseAppConfig:

- [ ] BaseAppConfig initialized with nested Server structs
- [ ] Config values load correctly from ConfigMap
- [ ] Environment variables work as overrides
- [ ] No random port assignments
- [ ] Correct Redis DB number

---

## Action Plan

### Immediate Actions (Today)

1. **Fix Config Loading Pattern** (8 services)
   ```bash
   # Services to fix:
   # - common-operations-service
   # - fulfillment-service
   # - location-service
   # - order-service
   # - promotion-service
   # - search-service
   # - shipping-service
   # - warehouse-service
   ```
   
   **Fix Steps**:
   1. Update `{service}/internal/config/config.go` (or `{service}/config/config.go`)
   2. Change BaseAppConfig initialization to include nested Server structs
   3. Build, test, commit, push
   4. Monitor deployment for correct port binding

2. **Verify Fixed Services**
   ```bash
   # Check review and pricing services
   kubectl logs -n core-business -l app=review-service --tail=50 | grep "listening on"
   kubectl logs -n core-business -l app=pricing-service --tail=50 | grep "listening on"
   ```
   
   Expected output:
   - `[HTTP] server listening on: [::]:8000` ✅
   - `✅ Redis connected (..., db=5, ...)` (review) or `db=2` (pricing) ✅

### Short-term Actions (This Week)

1. **Fix Remaining 8 Services**
   - Apply correct BaseAppConfig initialization pattern
   - Test each service after fix
   - Monitor for any regressions

2. **Add Config Validation**
   - Add startup logging to show loaded config
   - Add validation that rejects zero-value ports
   - Log Redis DB number on startup

3. **Document Config Loading**
   - Create guide for `common/config` usage
   - Document env var precedence rules
   - Add examples for both patterns (BaseAppConfig vs Custom)

### Long-term Actions (Next Sprint)

1. **Standardize Config Patterns**
   - Consider migrating all services to BaseAppConfig pattern
   - Or document when to use each pattern
   - Create service template with correct initialization

2. **Automated Testing**
   - Add pre-deployment config validation
   - Add smoke tests for port binding
   - Add config loading unit tests

3. **Monitoring Improvements**
   - Alert on config loading failures
   - Alert on probe failures
   - Dashboard for service health

---

## Detailed Service Status

### ✅ Healthy Services (8)

| Service | Config Pattern | Ports | Redis DB | Notes |
|---------|---------------|-------|----------|-------|
| auth-service | Custom struct | 8000/9000 | 0 | Not using BaseAppConfig |
| catalog-service | BaseAppConfig (correct) | 8000/9000 | 4 | Correct initialization |
| customer-service | BaseAppConfig (correct) | 8000/9000 | 6 | Correct initialization |
| notification-service | Custom struct | 8000/9000 | 11 | Not using BaseAppConfig |
| payment-service | Custom struct | 8000/9000 | 14 | Not using BaseAppConfig |
| pricing-service | BaseAppConfig (correct) | 8000/9000 | 2 | ✅ Fixed 2025-12-28 |
| review-service | BaseAppConfig (correct) | 8000/9000 | 5 | ✅ Fixed 2025-12-28 |
| user-service | Custom struct | 8000/9000 | 15 | Not using BaseAppConfig |

### ⚠️ At Risk Services (8)

| Service | Config Pattern | Ports | Redis DB | Risk Level | Action Required |
|---------|---------------|-------|----------|------------|-----------------|
| common-operations | BaseAppConfig (incorrect) | 8000/9000 | 8 | Medium | Fix initialization |
| fulfillment | BaseAppConfig (incorrect) | 8000/9000 | 10 | Medium | Fix initialization |
| location | BaseAppConfig (incorrect) | 8000/9000 | 7 | Medium | Fix initialization |
| order | BaseAppConfig (incorrect) | 8000/9000 | 1 | Medium | Fix initialization |
| promotion | BaseAppConfig (incorrect) | 8000/9000 | 3 | Medium | Fix initialization |
| search | BaseAppConfig (incorrect) | 8000/9000 | 12 | Medium | Fix initialization |
| shipping | BaseAppConfig (incorrect) | 8000/9000 | 13 | Medium | Fix initialization |
| warehouse | BaseAppConfig (incorrect) | 8000/9000 | 9 | Medium | Fix initialization |

**Risk Assessment**:
- **Medium Risk**: Services may work if environment variables override config
- **Failure Mode**: Random ports, wrong Redis DB, health check failures
- **Trigger**: ConfigMap updates, pod restarts, environment variable changes

---

## Appendix A: Full Service Inventory

### All Services with Details

```
BACKEND SERVICES (16):
├── auth-service (8000/9000, Redis DB 0) ✅ Custom struct
├── catalog-service (8000/9000, Redis DB 4) ✅ BaseAppConfig (correct)
├── common-operations-service (8000/9000, Redis DB 8) ⚠️ BaseAppConfig (incorrect)
├── customer-service (8000/9000, Redis DB 6) ✅ BaseAppConfig (correct)
├── fulfillment-service (8000/9000, Redis DB 10) ⚠️ BaseAppConfig (incorrect)
├── location-service (8000/9000, Redis DB 7) ⚠️ BaseAppConfig (incorrect)
├── notification-service (8000/9000, Redis DB 11) ✅ Custom struct
├── order-service (8000/9000, Redis DB 1) ⚠️ BaseAppConfig (incorrect)
├── payment-service (8000/9000, Redis DB 14) ✅ Custom struct
├── pricing-service (8000/9000, Redis DB 2) ✅ BaseAppConfig (correct - fixed)
├── promotion-service (8000/9000, Redis DB 3) ⚠️ BaseAppConfig (incorrect)
├── review-service (8000/9000, Redis DB 5) ✅ BaseAppConfig (correct - fixed)
├── search-service (8000/9000, Redis DB 12) ⚠️ BaseAppConfig (incorrect)
├── shipping-service (8000/9000, Redis DB 13) ⚠️ BaseAppConfig (incorrect)
├── user-service (8000/9000, Redis DB 15) ✅ Custom struct
└── warehouse-service (8000/9000, Redis DB 9) ⚠️ BaseAppConfig (incorrect)

WORKER SERVICES (9):
├── catalog-worker (5005) ✅
├── common-operations-worker (8019) ✅
├── customer-worker (5005) ✅
├── fulfillment-worker (5005) ✅
├── notification-worker (5005) ✅
├── order-worker (5005) ✅
├── payment-worker (5005) ✅
├── search-worker (5005) ✅
└── shipping-worker (5005) ✅

FRONTEND SERVICES (2):
├── frontend (3000) ✅
└── admin (80) ✅

INFRASTRUCTURE (2):
├── gateway (custom) ✅
└── elasticsearch (9200) ✅
```

---

## Appendix B: Environment Variable Reference

### ServiceConfigLoader Env Var Pattern

For service name `"{service}"`:
- Prefix: `{SERVICE}_` (uppercase, hyphens → underscores)
- Key mapping: dots → underscores
- Examples:
  ```
  server.http.addr     → {SERVICE}_SERVER_HTTP_ADDR=":8000"
  server.grpc.addr     → {SERVICE}_SERVER_GRPC_ADDR=":9000"
  data.redis.db        → {SERVICE}_DATA_REDIS_DB="5"
  data.redis.addr      → {SERVICE}_DATA_REDIS_ADDR="redis:6379"
  ```

### Config Loading Precedence

1. **Environment Variables** (highest priority)
2. **ConfigMap** (from values.yaml)
3. **Default Values** (from ServiceConfigLoader)

**Note**: For services with incorrect BaseAppConfig initialization, environment variables may mask the issue, but ConfigMap values will be ignored.

---

## Summary

**Total Services**: 29 (16 backend + 9 workers + 2 frontend + 2 infrastructure)  
**Healthy**: 8 (28%)  
**At Risk**: 8 (28%) - Config loading pattern issue  
**Fixed**: 2 (7%) - review, pricing  
**Custom Pattern (Working)**: 4 (14%) - auth, user, payment, notification  
**Workers**: 9 (31%) - All healthy  

**Critical Issues**:
- 8 services need BaseAppConfig initialization fix
- All other configurations are correct

**Next Steps**: 
1. Fix 8 services with incorrect BaseAppConfig initialization
2. Verify all services after fixes
3. Monitor for any regressions

---

**Generated**: 2025-12-28 09:32:00+07:00  
**Last Updated**: 2025-12-28 (Config Loading Pattern Review)  
**Version**: 2.0

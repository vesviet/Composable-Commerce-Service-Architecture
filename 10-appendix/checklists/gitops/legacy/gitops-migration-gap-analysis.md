# GitOps Migration Gap Analysis Report

**Comparison**: ArgoCD (Helm-based) vs GitOps (Kustomize-based)  
**Date**: February 4, 2026  
**Reviewer**: Senior DevOps  
**Status**: 🔴 **Critical Gaps Identified**

---

## 📊 Executive Summary

After indexing and comparing the old ArgoCD (Helm-based) repository with the new GitOps (Kustomize-based) setup, several **critical missing components** have been identified that must be migrated to ensure feature parity.

### Overall Migration Status: **70% Complete**

**Critical Missing Components**:
1. ❌ NetworkPolicy for 22/23 services (only common-operations has it)
2. ❌ Worker init containers (wait-for-consul, wait-for-redis, wait-for-postgres)
3. ❌ Advanced health checks (startupProbe missing)
4. ❌ Configurable features (HPA, PDB controls)
5. ❌ Dapr sidecar port configuration
6. ❌ Environment-specific values structure

---

## 🏗️ Architecture Comparison

### ArgoCD (Helm-based) - OLD
```
argocd/
├── applications/main/{service}/
│   ├── Chart.yaml
│   ├── {service}-appSet.yaml         # ApplicationSet for multi-env
│   ├── values-base.yaml              # Base configuration
│   ├── dev/
│   │   ├── values.yaml              # Dev-specific config
│   │   └── tag.yaml                 # Image tag
│   ├── staging/
│   │   ├── values.yaml              # Staging config
│   │   └── tag.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── worker-deployment.yaml   # ✅ Conditional worker
│       ├── migration-job.yaml       # ✅ With init containers
│       ├── service.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       ├── serviceaccount.yaml
│       ├── networkpolicy.yaml       # ✅ ALL services have this
│       ├── pdb.yaml                 # ✅ Conditional
│       └── servicemonitor.yaml      # ✅ Conditional
```

### GitOps (Kustomize-based) - NEW
```
gitops/
├── apps/{service}/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── worker-deployment.yaml   # ✅ Static (12 services)
│   │   ├── migration-job.yaml       # ⚠️ NO init containers
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── servicemonitor.yaml      # ✅ ALL services have this
│   │   ├── pdb.yaml                 # ⚠️ Only some services
│   │   └── serviceaccount.yaml      # ⚠️ Only 3 services
│   └── overlays/
│       └── dev/
│           ├── kustomization.yaml
│           └── configmap.yaml       # ⚠️ Environment-specific patches
```

---

## 🔴 CRITICAL MISSING COMPONENTS

### 1. NetworkPolicy (Priority: P0 - CRITICAL)

#### Current State:
- **ArgoCD (Helm)**: ✅ **ALL 23 services** have NetworkPolicy templates
- **GitOps (Kustomize)**: ❌ **ONLY 1 service** (common-operations) has NetworkPolicy

#### Missing Services (22):
```
auth, user, customer, catalog, search, pricing, promotion, 
review, order, payment, shipping, warehouse, fulfillment,
notification, analytics, location, loyalty-rewards, gateway,
checkout, return, admin, frontend
```

#### GitOps NetworkPolicy Requirements (Per-Service Namespace):

**Key Difference**: GitOps uses **separate namespace per service** (auth-dev, catalog-dev, gateway-dev) instead of shared namespace.

```yaml
# Template for GitOps - Each service in own namespace
# Example: gitops/apps/auth/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth
  labels:
    app.kubernetes.io/name: auth
    app.kubernetes.io/component: backend
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: auth
      app.kubernetes.io/component: backend
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Allow from gateway namespace (NOT same namespace)
    - from:
        - namespaceSelector:
            matchLabels:
              name: gateway-dev  # Gateway in separate namespace
          podSelector:
            matchLabels:
              app.kubernetes.io/name: gateway
      ports:
        - protocol: TCP
          port: 8000  # HTTP port
        - protocol: TCP
          port: 9000  # GRPC port
    
    # Allow from other services that need to call this service
    # Example: order service calling auth
    - from:
        - namespaceSelector:
            matchLabels:
              name: order-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: order
      ports:
        - protocol: TCP
          port: 8000
        - protocol: TCP
          port: 9000
  
  egress:
    # DNS Resolution (required)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    
    # PostgreSQL in infrastructure namespace
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: postgresql
      ports:
        - protocol: TCP
          port: 5432
    
    # Redis in infrastructure namespace
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379
    
    # Consul in infrastructure namespace
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: consul
      ports:
        - protocol: TCP
          port: 8500
        - protocol: TCP
          port: 8300  # Consul RPC
    
    # Dapr Control Plane (dapr-system namespace)
    - to:
        - namespaceSelector:
            matchLabels:
              name: dapr-system
      ports:
        - protocol: TCP
          port: 443   # Sentry Service (mTLS)
        - protocol: TCP
          port: 50001 # Sentry gRPC
        - protocol: TCP
          port: 80    # Dapr API Service
        - protocol: TCP
          port: 6500  # Dapr API gRPC
        - protocol: TCP
          port: 50005 # Placement Service
        - protocol: TCP
          port: 50006 # Scheduler Service
    
    # Call to other services (service-to-service)
    # Example: auth calling user service
    - to:
        - namespaceSelector:
            matchLabels:
              name: user-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: user
      ports:
        - protocol: TCP
          port: 80    # Service port
        - protocol: TCP
          port: 81    # GRPC service port
```

#### GitOps NetworkPolicy for Gateway (Special Case):
```yaml
# Gateway needs to accept from Ingress and call all services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gateway
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: gateway
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Allow from Ingress Controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
    
    # Allow from same namespace (admin panel, etc.)
    - from:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 8080
  
  egress:
    # DNS
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
    
    # Allow calling ALL backend services
    # Gateway needs access to auth, catalog, order, etc.
    - to:
        - namespaceSelector:
            matchLabels:
              app.kubernetes.io/environment: dev  # All dev namespaces
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 81
        - protocol: TCP
          port: 8000-9000  # Service ports range
    
    # Infrastructure
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
      ports:
        - protocol: TCP
          port: 6379  # Redis
        - protocol: TCP
          port: 8500  # Consul
    
    # Dapr
    - to:
        - namespaceSelector:
            matchLabels:
              name: dapr-system
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 50001
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 6500
```

**Impact**: Without NetworkPolicies, services have unrestricted network access, violating security best practices and compliance requirements.

---

### 2. Init Containers for Worker & Migration Jobs (Priority: P0)

#### Current State:
- **ArgoCD (Helm)**: ✅ Worker deployments have init containers
- **GitOps (Kustomize)**: ❌ NO init containers in workers or migration jobs

#### Missing Init Containers:

```yaml
# From argocd/applications/main/auth/templates/worker-deployment.yaml
initContainers:
  # Wait for Consul to be ready
  - name: wait-for-consul
    image: busybox:1.28
    command: ['sh', '-c', 'until nc -z consul.infrastructure.svc.cluster.local 8500; do echo "Waiting for Consul..."; sleep 2; done; echo "Consul is ready"']
  
  # Wait for Redis to be ready
  - name: wait-for-redis
    image: busybox:1.28
    command: ['sh', '-c', 'until nc -z redis.infrastructure.svc.cluster.local 6379; do echo "Waiting for Redis..."; sleep 2; done; echo "Redis is ready"']
  
  # Wait for PostgreSQL to be ready
  - name: wait-for-postgres
    image: busybox:1.28
    command: ['sh', '-c', 'until nc -z postgresql.infrastructure.svc.cluster.local 5432; do echo "Waiting for PostgreSQL..."; sleep 2; done; echo "PostgreSQL is ready"']
```

#### Affected Components:
- **Workers**: 12 services (auth, catalog, customer, order, payment, pricing, warehouse, fulfillment, notification, search, shipping, common-operations)
- **Migration Jobs**: 19 services (all services with databases)

**Impact**: Services may fail to start if dependencies are not ready, causing pod restarts and deployment failures.

---

### 3. StartupProbe for Slow-Starting Services (Priority: P1)

#### Current State:
- **ArgoCD (Helm)**: ✅ catalog has startupProbe configured
- **GitOps (Kustomize)**: ❌ NO services have startupProbe

#### ArgoCD StartupProbe Example:
```yaml
# From argocd/applications/main/catalog/values-base.yaml
startupProbe:
  httpGet:
    path: /health/live
    port: 8000
    scheme: HTTP
  failureThreshold: 30        # 30 attempts
  periodSeconds: 10           # Every 10 seconds
  timeoutSeconds: 5           # Max 5 minutes to start
```

#### Services That Need StartupProbe:
1. **search** - Elasticsearch connection takes time
2. **warehouse** - Complex initialization
3. **catalog** - Large dataset loading
4. **fulfillment** - Multiple service dependencies

**Impact**: Without startupProbe, livenessProbe may kill pods during legitimate slow startup, causing restart loops.

---

### 4. Dapr Sidecar Port Configuration (Priority: P1)

#### Current State:
- **ArgoCD (Helm)**: ✅ Includes dapr-grpc port (5005) in deployment
- **GitOps (Kustomize)**: ❌ Missing dapr-grpc port

#### Missing Port Configuration:
```yaml
# ArgoCD has this port definition:
ports:
  - name: dapr-grpc
    containerPort: 5005
    protocol: TCP
```

**Impact**: May affect service-to-service Dapr communication if strict port policies are enforced.

---

### 5. Worker Configuration Control (Priority: P1)

#### Current State:
- **ArgoCD (Helm)**: ✅ Workers can be enabled/disabled via values
- **GitOps (Kustomize)**: ❌ Workers are statically deployed

#### ArgoCD Worker Control:
```yaml
# From values-base.yaml
worker:
  enabled: false              # ✅ Can toggle on/off
  replicaCount: 1
  resources:
    limits:
      cpu: 300m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

#### GitOps Approach:
- Workers are always deployed if `worker-deployment.yaml` exists in base
- No conditional deployment mechanism

**Recommendation**: Use Kustomize patches to optionally include/exclude workers per environment.

---

### 6. PodDisruptionBudget Control (Priority: P2)

#### Current State:
- **ArgoCD (Helm)**: ✅ PDB is conditional via values
- **GitOps (Kustomize)**: ⚠️ Static PDB for some services only

#### ArgoCD PDB Control:
```yaml
# From values-base.yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
  # OR
  maxUnavailable: 1
```

#### GitOps Status:
- **Has PDB**: catalog, search, review, return, checkout, shipping, user, fulfillment
- **Missing PDB**: auth, gateway, order, payment, warehouse, customer, pricing, notification, promotion, location, analytics, loyalty-rewards, common-operations, admin, frontend

---

### 7. ServiceAccount Consistency (Priority: P2)

#### Current State:
- **ArgoCD (Helm)**: ✅ ALL services have ServiceAccount templates
- **GitOps (Kustomize)**: ⚠️ Only 3 services have ServiceAccount

#### Services with ServiceAccount in GitOps:
- gateway
- review  
- promotion

#### Missing ServiceAccount (20 services):
```
auth, user, customer, catalog, search, pricing, order, payment,
shipping, warehouse, fulfillment, notification, analytics, location,
loyalty-rewards, checkout, return, admin, frontend, common-operations
```

**Impact**: May affect RBAC and pod identity features.

---

### 8. Environment Variable Differences

#### ArgoCD (Helm) - More Comprehensive:
```yaml
env:
  - name: KRATOS_CONF
    value: "/app/configs"
  
  - name: DAPR_GRPC_ENDPOINT
    value: "localhost:50001"
  
  - name: DAPR_PUBSUB_NAME
    value: "pubsub-redis"
  
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
```

#### GitOps (Kustomize) - Basic:
```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      configMapKeyRef:
        name: catalog-config
        key: database-url
  
  - name: REDIS_URL
    valueFrom:
      configMapKeyRef:
        name: catalog-config
        key: redis-url
```

**Missing in GitOps**:
- `KRATOS_CONF` - Kratos framework config path
- `DAPR_GRPC_ENDPOINT` - Dapr sidecar endpoint
- `DAPR_PUBSUB_NAME` - Pub/sub component name
- `POD_NAMESPACE` / `POD_NAME` - Pod identity for logging/tracing

---

### 9. Resource Configuration Differences

#### ArgoCD (Helm) - More Generous:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 1Gi          # ✅ 1GB limit
  requests:
    cpu: 100m            # ✅ 100m CPU
    memory: 256Mi        # ✅ 256MB request
```

#### GitOps (Kustomize) - More Conservative:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi        # ⚠️ Only 512MB limit
  requests:
    cpu: 100m
    memory: 128Mi        # ⚠️ Only 128MB request
```

**Impact**: GitOps may face OOMKilled issues under load due to lower memory limits.

---

### 10. Deployment Strategy

#### ArgoCD (Helm) - Explicit Strategy:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0    # ✅ Zero downtime
    maxSurge: 1
```

#### GitOps (Kustomize) - Not Specified:
- Some deployments have it, some don't
- Inconsistent configuration

---

## 📋 DETAILED GAP MATRIX

| Component | ArgoCD (Helm) | GitOps (Kustomize) | Gap | Priority |
|-----------|---------------|-------------------|-----|----------|
| **NetworkPolicy** | ✅ 23/23 | ❌ 1/23 | **22 services** | P0 |
| **Init Containers (Workers)** | ✅ 12/12 | ❌ 0/12 | **12 services** | P0 |
| **Init Containers (Jobs)** | ✅ 19/19 | ❌ 0/19 | **19 services** | P0 |
| **StartupProbe** | ✅ Catalog | ❌ 0/23 | **4 services** | P1 |
| **Dapr GRPC Port** | ✅ All | ❌ None | **23 services** | P1 |
| **Worker Toggle** | ✅ Conditional | ❌ Static | **12 services** | P1 |
| **PDB Toggle** | ✅ Conditional | ⚠️ Static | **15 services** | P2 |
| **ServiceAccount** | ✅ 23/23 | ⚠️ 3/23 | **20 services** | P2 |
| **ServiceMonitor** | ✅ 23/23 | ✅ 23/23 | ✅ Complete | - |
| **Env Vars (Full)** | ✅ Comprehensive | ⚠️ Basic | **All services** | P1 |
| **Resource Limits** | ✅ 1Gi/256Mi | ⚠️ 512Mi/128Mi | **All services** | P2 |
| **Deployment Strategy** | ✅ Explicit | ⚠️ Inconsistent | **Some services** | P2 |

---

## 🎯 RECOMMENDED ACTIONS

### Phase 1: Critical Security (Week 1) - P0

#### 1.1 Add NetworkPolicy to All Services
```bash
# Template from argocd/applications/main/auth/templates/networkpolicy.yaml
# Convert to Kustomize format for each service

Services to fix: auth, user, customer, catalog, gateway, order, payment, 
pricing, promotion, review, search, shipping, warehouse, fulfillment, 
notification, analytics, location, loyalty-rewards, checkout, return, 
admin, frontend
```

**Action Items - Phase 1 (Basic Connectivity)**:
- [ ] Create standard NetworkPolicy template for backend services (per-service namespace)
  - ✅ Ingress from gateway only
  - ✅ Egress to infrastructure (DB, Redis, Consul)
  - ✅ Egress to dapr-system
  - ⏸️ **Skip Service-to-Service for now** (Phase 2)
- [ ] Create NetworkPolicy template for gateway (allow all backend access)
- [ ] Create NetworkPolicy template for frontend services (admin, frontend)
- [ ] Add NetworkPolicy to all service base directories
- [ ] Update kustomization.yaml to include networkpolicy.yaml
- [ ] **Key Change**: Use service-specific namespace labels (auth-dev, catalog-dev, etc.)
- [ ] **Namespace Labels**: Ensure all namespaces have proper labels:
  ```yaml
  # gitops/infrastructure/namespaces-with-env.yaml
  metadata:
    labels:
      name: auth-dev
      app.kubernetes.io/environment: dev
      app.kubernetes.io/managed-by: kustomize
  ```
- [ ] Test network isolation in dev environment
- [ ] Verify Dapr egress to dapr-system namespace works

**Action Items - Phase 2 (Service-to-Service) - DEFERRED**:
- [ ] Map service-to-service dependencies
- [ ] Add specific service-to-service ingress/egress rules
- [ ] Test inter-service communication

#### 1.2 Add Init Containers to Workers
```bash
# Services with workers: 12 services
# Add wait-for-consul, wait-for-redis, wait-for-postgres init containers

Services to fix: auth, catalog, customer, order, payment, pricing, 
warehouse, fulfillment, notification, search, shipping, common-operations
```

**Action Items**:
- [ ] Add init containers to all worker-deployment.yaml files
- [ ] Test worker startup with init containers
- [ ] Verify dependency wait logic works correctly

#### 1.3 Add Init Containers to Migration Jobs
```bash
# Services with migration jobs: 19 services
# Add wait-for-postgres init container

Services to fix: All services with databases
```

**Action Items**:
- [ ] Add wait-for-postgres init container to all migration-job.yaml
- [ ] Test migration job execution
- [ ] Verify migrations run after DB is ready

---

### Phase 2: Reliability Improvements (Week 2) - P1

#### 2.1 Add StartupProbe to Slow-Starting Services
```bash
Services: search, warehouse, catalog, fulfillment
```

**Action Items**:
- [ ] Add startupProbe to slow-starting services
- [ ] Configure failureThreshold: 30, periodSeconds: 10
- [ ] Test startup behavior under load

#### 2.2 Add Dapr GRPC Port to All Deployments
```bash
All 23 services need this port
```

**Action Items**:
- [ ] Add dapr-grpc port (5005) to all deployment.yaml files
- [ ] Verify Dapr sidecar communication

#### 2.3 Add Comprehensive Environment Variables
```bash
Missing: KRATOS_CONF, DAPR_GRPC_ENDPOINT, DAPR_PUBSUB_NAME, 
POD_NAMESPACE, POD_NAME
```

**Action Items**:
- [ ] Add missing env vars to all deployments
- [ ] Add to configmaps where appropriate
- [ ] Test service startup with new env vars

---

### Phase 3: Production Readiness (Week 3) - P2

#### 3.1 Add ServiceAccount to All Services
```bash
Missing from 20 services
```

**Action Items**:
- [ ] Create serviceaccount.yaml for all services
- [ ] Add to kustomization.yaml
- [ ] Configure RBAC if needed

#### 3.2 Add PodDisruptionBudget to Critical Services
```bash
Missing from: auth, gateway, order, payment, warehouse, customer, 
pricing, notification, promotion, location, analytics, loyalty-rewards, 
common-operations
```

**Action Items**:
- [ ] Add PDB to all critical services
- [ ] Configure minAvailable: 1 for 2-replica services
- [ ] Test during node drain scenarios

#### 3.3 Standardize Resource Limits
```bash
Consider increasing to ArgoCD levels:
- memory.limits: 512Mi → 1Gi
- memory.requests: 128Mi → 256Mi
```

**Action Items**:
- [ ] Review resource usage in dev
- [ ] Adjust limits based on actual usage
- [ ] Document resource sizing guidelines

#### 3.4 Add Explicit Deployment Strategy
```bash
All services should have:
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

**Action Items**:
- [ ] Add deployment strategy to all deployment.yaml
- [ ] Ensure zero-downtime deployments

---

## 📊 MIGRATION PRIORITY SUMMARY

### Immediate (This Week) - P0
1. ✅ NetworkPolicy for all 22 services (CRITICAL SECURITY)
2. ✅ Init containers for 12 workers
3. ✅ Init containers for 19 migration jobs

### Short Term (Next Week) - P1
4. ✅ StartupProbe for 4 slow-starting services
5. ✅ Dapr GRPC port for all services
6. ✅ Comprehensive environment variables

### Medium Term (Week 3) - P2
7. ✅ ServiceAccount for 20 services
8. ✅ PodDisruptionBudget for 13 services
9. ✅ Resource limit adjustments
10. ✅ Deployment strategy standardization

---

## 🔍 ARGOCD vs GITOPS FEATURE COMPARISON

| Feature | ArgoCD (Helm) | GitOps (Kustomize) | Migration Status |
|---------|---------------|-------------------|------------------|
| **Deployment Pattern** | ApplicationSet | Application per env | ✅ Different but valid |
| **Multi-Environment** | Helm values overlay | Kustomize overlays | ✅ Equivalent |
| **Image Tag Management** | Separate tag.yaml | kustomization images | ✅ Equivalent |
| **Config Management** | Helm values | Kustomize patches | ✅ Equivalent |
| **Conditional Resources** | Helm if statements | Kustomize components | ⚠️ Less flexible |
| **Templating** | Helm functions | Kustomize vars | ⚠️ Limited |
| **Resource Sharing** | Helm charts | Kustomize bases | ✅ Equivalent |
| **Secret Management** | External Secrets | External Secrets | ✅ Same (needs setup) |
| **Namespace Strategy** | Single namespace per env | Separate namespace per service | ✅ Both valid |

---

## 💡 RECOMMENDATIONS

### 1. Adopt Helm's Best Practices in Kustomize

While Kustomize is simpler, we should port these Helm patterns:
- ✅ NetworkPolicy for all services (security)
- ✅ Init containers for dependency waiting (reliability)
- ✅ Conditional deployments via Kustomize components (flexibility)
- ✅ Comprehensive environment variable templates (consistency)

### 2. Create Kustomize Components for Optional Resources

```
gitops/common/components/
├── networkpolicy/          # NetworkPolicy component
├── init-containers/        # Init container component
├── startup-probe/          # StartupProbe component
└── service-account/        # ServiceAccount component
```

Services can opt-in by adding to kustomization.yaml:
```yaml
components:
  - ../../common/components/networkpolicy
  - ../../common/components/init-containers
```

### 3. Standardize Environment Variables

Create a shared configmap for common env vars:
```yaml
# gitops/common/env-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-env
data:
  DAPR_GRPC_ENDPOINT: "localhost:50001"
  DAPR_PUBSUB_NAME: "pubsub-redis"
  CONSUL_ADDR: "consul.infrastructure.svc.cluster.local:8500"
  REDIS_ADDR: "redis.infrastructure.svc.cluster.local:6379"
```

### 4. Document Migration Decisions

Create `docs/10-appendix/migration-decisions.md` explaining:
- Why Kustomize over Helm
- Trade-offs accepted
- Patterns to follow going forward

---

## 📚 REFERENCE COMPARISON FILES

### NetworkPolicy:
- **ArgoCD**: `argocd/applications/main/auth/templates/networkpolicy.yaml`
- **GitOps**: `gitops/apps/common-operations/base/networkpolicy.yaml` (only one)

### Worker Deployment:
- **ArgoCD**: `argocd/applications/main/auth/templates/worker-deployment.yaml`
- **GitOps**: `gitops/apps/catalog/base/worker-deployment.yaml`

### Migration Job:
- **ArgoCD**: `argocd/applications/main/auth/templates/migration-job.yaml`
- **GitOps**: `gitops/apps/catalog/base/migration-job.yaml`

### Values Configuration:
- **ArgoCD**: `argocd/applications/main/catalog/values-base.yaml`
- **GitOps**: `gitops/apps/catalog/overlays/dev/kustomization.yaml`

---

## 🎯 SUCCESS CRITERIA

Migration is complete when:
- [ ] All 23 services have NetworkPolicy
- [ ] All 12 workers have init containers
- [ ] All 19 migration jobs have init containers
- [ ] 4 slow-starting services have startupProbe
- [ ] All services have dapr-grpc port
- [ ] All services have comprehensive env vars
- [ ] All 23 services have ServiceAccount
- [ ] 13+ critical services have PodDisruptionBudget
- [ ] Resource limits reviewed and adjusted
- [ ] Deployment strategy standardized
- [ ] Documentation updated with patterns

---

**Last Updated**: February 4, 2026  
**Next Review**: After Phase 1 completion  
**Status**: 🔴 **Gaps Identified - Action Required**

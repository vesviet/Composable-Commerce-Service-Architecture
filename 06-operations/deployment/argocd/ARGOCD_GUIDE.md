# ArgoCD Deployment Guide

**Last Updated**: 2025-01-XX  
**Status**: ✅ **ACTIVE** - 13 services deployed to dev environment

---

## 📚 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Service Catalog](#service-catalog)
4. [Deployment Guide](#deployment-guide)
5. [Standardization](#standardization)
6. [Configuration Reference](#configuration-reference)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## Overview

### Current Status

| Metric | Count | Status |
|--------|-------|--------|
| **Total Services** | 19 | 17 Go + 2 Node.js |
| **Helm Charts** | 19/19 | ✅ 100% Complete |
| **Deployed (dev)** | 13/19 | 🚀 68% |
| **Ready to Deploy** | 6/19 | ⏳ 32% |

### Deployed Services (13)

**Core Services**:
- ✅ auth-dev
- ✅ catalog-dev
- ✅ user-dev
- ✅ warehouse-dev
- ✅ order-dev
- ✅ pricing-dev
- ✅ promotion-dev
- ✅ payment-dev
- ✅ shipping-dev
- ✅ common-operations-dev

**Frontend Services**:
- ✅ admin-dev
- ✅ frontend-dev
- ✅ gateway-dev

### Pending Deployment (6)

- ⏳ customer-service
- ⏳ fulfillment-service
- ⏳ location-service
- ⏳ notification-service
- ⏳ review-service
- ⏳ search-service

---

## Quick Start

### Deploy a Service

```bash
# 1. Navigate to service directory
cd argocd/applications/main/<service-name>/

# 2. Set image tag
echo "image:\n  tag: <tag>" > dev/tag.yaml

# 3. Commit and push
git add dev/tag.yaml
git commit -m "Deploy <service-name> to dev"
git push

# 4. ArgoCD will auto-sync (if enabled)
# Or manual sync:
argocd app sync <service-name>-dev
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<service-name>

# Check logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<service-name> --tail=100

# Check health
kubectl port-forward -n <namespace> svc/<service-name> 8080:80
curl http://localhost:8080/health
```

---

## Service Catalog

### Phase 1: Core Services (8)

1. **Auth Service** ✅
   - Namespace: `core-business-dev`
   - Ports: 8000 (HTTP), 9000 (gRPC)
   - Features: JWT authentication, RBAC

2. **Gateway Service** ✅
   - Namespace: `frontend-services-dev`
   - Ports: 80 (HTTP)
   - Features: API Gateway, routing, rate limiting

3. **User Service** ✅
   - Namespace: `core-business-dev`
   - Ports: 8000 (HTTP), 9000 (gRPC)
   - Features: User management, RBAC

4. **Customer Service** ⏳
   - Namespace: `core-business-dev`
   - Features: Customer data, worker

5. **Catalog Service** ✅
   - Namespace: `core-business-dev`
   - Features: Product catalog, worker, migration

6. **Pricing Service** ✅
   - Namespace: `core-business-dev`
   - Features: Pricing calculations

7. **Warehouse Service** ✅
   - Namespace: `core-business-dev`
   - Features: Inventory management, worker, migration

8. **Location Service** ⏳
   - Namespace: `core-business-dev`
   - Features: Location management

### Phase 2: Business Services (4)

9. **Order Service** ✅
   - Features: Order workflows, migration

10. **Payment Service** ✅
    - Features: Payment processing

11. **Promotion Service** ✅
    - Features: Campaigns, coupons, migration

12. **Shipping Service** ✅
    - Features: Carrier integration, worker, migration

### Phase 3: Support Services (4)

13. **Fulfillment Service** ⏳
    - Features: Order fulfillment, worker, migration

14. **Search Service** ⏳
    - Features: Elasticsearch integration, worker

15. **Review Service** ⏳
    - Features: Product reviews

16. **Notification Service** ⏳
    - Features: Email/SMS notifications

### Phase 4: Frontend Services (2)

17. **Admin Panel** ✅
    - Namespace: `frontend-services-dev`
    - Tech: Vite + React

18. **Frontend** ✅
    - Namespace: `frontend-services-dev`
    - Tech: Next.js

### Additional Services (1)

19. **Common Operations Service** ✅
    - Features: Task orchestration, worker, migration

---

## Deployment Guide

### Prerequisites

1. ArgoCD installed and configured
2. Git repository access
3. Docker registry access
4. Kubernetes cluster access

### Step-by-Step Deployment

#### Step 1: Prepare Configuration

```bash
cd argocd/applications/main/<service-name>/

# Edit dev values (if needed)
vim dev/values.yaml

# Set image tag
echo "image:\n  tag: <tag>" > dev/tag.yaml
```

#### Step 2: Commit and Push

```bash
git add dev/
git commit -m "Deploy <service-name> to dev"
git push origin main
```

#### Step 3: Verify ApplicationSet

```bash
# Check ApplicationSet exists
kubectl get applicationset <service-name>-service -n argocd

# Check ArgoCD application created
kubectl get application <service-name>-dev -n argocd
```

#### Step 4: Sync Application

```bash
# Auto-sync (if enabled)
# ArgoCD will automatically sync

# Manual sync
argocd app sync <service-name>-dev
```

#### Step 5: Verify Deployment

```bash
# Check deployment
kubectl get deployment <service-name>-dev -n <namespace>

# Check pods
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<service-name>

# Check migration job (if exists)
kubectl get jobs -n <namespace> -l app.kubernetes.io/component=migration

# Check worker (if exists)
kubectl get pods -n <namespace> -l app.kubernetes.io/component=worker
```

### Deployment Order

Deploy services in this order to respect dependencies:

**Tier 0: Infrastructure**
- PostgreSQL, Redis, Consul, Dapr

**Tier 1: Core Domain**
1. Auth Service
2. User Service

**Tier 2: Product Domain**
3. Catalog Service
4. Pricing Service
5. Promotion Service

**Tier 3: Business Operations**
6. Customer Service
7. Order Service
8. Payment Service
9. Warehouse Service
10. Shipping Service

**Tier 4: Support Services**
11. Fulfillment Service
12. Location Service
13. Notification Service
14. Search Service
15. Review Service
16. Common Operations Service

**Tier 5: Frontend**
17. Gateway Service
18. Admin Panel
19. Frontend

---

## Standardization

### Directory Structure

```
argocd/applications/main/<service-name>/
├── Chart.yaml                  # Helm chart metadata
├── values-base.yaml            # Base configuration
├── <service-name>-appSet.yaml  # ApplicationSet
├── templates/
│   ├── deployment.yaml         # Main deployment
│   ├── service.yaml            # Service definition
│   ├── worker-deployment.yaml  # Worker (if enabled)
│   ├── migration-job.yaml      # Migration job (if enabled)
│   └── _helpers.tpl           # Template helpers
└── dev/                        # Dev environment
    ├── values.yaml             # Dev overrides
    └── tag.yaml                # Image tag
```

### Configuration Standards

#### Ports

```yaml
service:
  targetHttpPort: 8000
  targetGrpcPort: 9000
  httpPort: 80
  grpcPort: 81

config:
  server:
    http: { addr: ":8000" }
    grpc: { addr: ":9000" }
```

#### Service Name Override

```yaml
# Keep service names without env suffix
service:
  name: "<service-name>"  # e.g., "auth", not "auth-dev"

# Deployment names will have -dev suffix via releaseName
```

#### Worker Configuration

```yaml
worker:
  enabled: true  # or false
  replicaCount: 1
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
```

#### Migration Configuration

```yaml
migration:
  enabled: true
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
  ttlSecondsAfterFinished: 300
```

#### Dapr Annotations

```yaml
podAnnotations:
  dapr.io/enabled: "true"
  dapr.io/app-id: "<service-name>"
  dapr.io/app-port: "8000"
  dapr.io/app-protocol: "http"
```

#### Health Probes

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8000
  initialDelaySeconds: 90
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8000
  initialDelaySeconds: 60
  periodSeconds: 5
```

### Sync Waves

Use ArgoCD sync waves for proper ordering:

- **Wave -5**: ServiceAccount, ConfigMap, Secret, Service
- **Wave 0**: Migration Job (with hook-delete-policy)
- **Wave 5**: Deployment, Worker

### Migration Job Annotations

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "0"
  argocd.argoproj.io/hook: Sync
  argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
```

---

## Configuration Reference

### Port Standardization

All backend services use:
- **HTTP**: 8000 (container), 80 (service)
- **gRPC**: 9000 (container), 81 (service)
- **Workers**: 5005 (Dapr port)

### Redis DB Allocation

| DB | Service |
|----|---------|
| 0 | auth-service |
| 1 | order-service |
| 2 | pricing-service |
| 3 | promotion-service |
| 4 | catalog-service |
| 5 | review-service |
| 6 | customer-service |
| 7 | location-service |
| 8 | common-operations-service |
| 9 | warehouse-service |
| 10 | fulfillment-service |
| 11 | notification-service |
| 12 | search-service |
| 13 | shipping-service |
| 14 | payment-service |
| 15 | user-service |

### Naming Convention

- **ArgoCD Application**: `{service-name}-{env}` (e.g., `auth-dev`)
- **Deployment Name**: `{service-name}-{env}` (e.g., `auth-dev`)
- **Service Name**: `{service-name}` (e.g., `auth`) - no env suffix
- **Namespace**: `{namespace}-{env}` (e.g., `core-business-dev`)

---

## Troubleshooting

### Migration Jobs OutOfSync

**Problem**: Migration jobs show OutOfSync in ArgoCD

**Solution**: Ensure migration jobs have proper annotations:
```yaml
annotations:
  argocd.argoproj.io/hook: Sync
  argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
```

### Service Name Mismatch

**Problem**: Service name has `-dev` suffix but config URLs expect without suffix

**Solution**: Use `service.name` override in values-base.yaml:
```yaml
service:
  name: "<service-name>"  # Keep without env suffix
```

### Deployment Not Syncing

```bash
# Check sync status
kubectl get application <service-name>-dev -n argocd

# Force sync
argocd app sync <service-name>-dev --force

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n <namespace> <pod-name>

# Check logs
kubectl logs -n <namespace> <pod-name>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

---

## Best Practices

### Before Deployment

- [ ] Review Helm chart configuration
- [ ] Verify service.name override (no env suffix)
- [ ] Set correct image tag
- [ ] Test in dev first
- [ ] Prepare rollback plan

### During Deployment

- [ ] Monitor pod startup
- [ ] Check health endpoints
- [ ] Verify service connectivity
- [ ] Check logs for errors
- [ ] Monitor metrics

### After Deployment

- [ ] Monitor for 24-48 hours
- [ ] Check error rates
- [ ] Verify integrations
- [ ] Update documentation
- [ ] Notify team

### Common Commands

```bash
# List applications
kubectl get application -n argocd

# Get application details
kubectl get application <app-name> -n argocd -o yaml

# Check pods
kubectl get pods -n <namespace>

# View logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<service-name> -f

# Port forward
kubectl port-forward -n <namespace> svc/<service-name> 8080:80
```

---

## Related Documentation

- **Templates**: `STANDARD_DEPLOYMENT_TEMPLATE.yaml`, `STANDARD_VALUES_TEMPLATE.yaml`
- **Configuration Audit**: `ARGOCD_CONFIGURATION_AUDIT.md`
- **VIGO Comparison**: `ARGOCD_VIGO_COMPARISON.md`
- **Port Reference**: `system-ports.md`

---

**Last Updated**: 2025-01-XX  
**Maintained By**: DevOps Team


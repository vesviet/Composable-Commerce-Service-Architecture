# Sync Wave Standardization - Action Plan

**Date**: February 4, 2026  
**Priority**: P0 - CRITICAL  
**Objective**: Infrastructure → Jobs → Services deployment order

---

## 🎯 CORRECTED SYNC WAVE STRATEGY

### Deployment Order Principle

```
Infrastructure Ready
    ↓
Database Migrations Complete
    ↓
Application Services Start
    ↓
Background Workers Start
```

### Wave Assignment Rules

| Wave | Resource Type | Purpose | Examples |
|------|---------------|---------|----------|
| **-10** | Namespace | Infrastructure must exist | auth-dev, catalog-dev, infrastructure |
| **-5** | Secret | Sensitive data first | JWT secrets, DB passwords |
| **-1** | ServiceAccount | RBAC before apps | All service accounts |
| **0** | ConfigMap, NetworkPolicy | Config + Security baseline | All configs, network rules |
| **1** | Migration Job, Sync Job | Database schema ready | All migration jobs |
| **2** | Infra Services (Deploy+Svc) | No dependencies | location, common-ops, analytics, notification |
| **3** | Core Services (Deploy+Svc) | Depend on infrastructure | auth, user, customer |
| **4** | Product Services (Deploy+Svc) | Depend on core | catalog, search, pricing, review, promotion, loyalty-rewards |
| **5** | Order Services (Deploy+Svc) | Depend on product | order, payment, warehouse, shipping, fulfillment, return |
| **6** | Gateway Layer (Deploy+Svc) | After all backends | gateway, checkout |
| **7** | Frontend (Deploy+Svc) | After gateway | admin, frontend |
| **8** | Workers | After parent service | All worker-deployment.yaml |
| **9** | Monitoring | After apps ready | ServiceMonitor, PrometheusRule |
| **10** | Autoscaling | Production tuning | HPA, PDB |

---

## 📝 IMPLEMENTATION CHECKLIST

### Phase 1: Infrastructure Foundation (Wave -10 to 0)

#### Step 1.1: Add Namespace Sync Waves
**Files**: `gitops/infrastructure/namespaces-with-env.yaml`

```yaml
# Example for each namespace:
apiVersion: v1
kind: Namespace
metadata:
  name: auth-dev
  labels:
    name: auth-dev
    app.kubernetes.io/environment: dev
  annotations:
    argocd.argoproj.io/sync-wave: "-10"  # ✅ ADD THIS
---
```

**Affected namespaces** (26 total):
- [ ] auth-dev
- [ ] catalog-dev
- [ ] checkout-dev
- [ ] common-operations-dev
- [ ] customer-dev
- [ ] fulfillment-dev
- [ ] gateway-dev
- [ ] location-dev
- [ ] loyalty-rewards-dev
- [ ] notification-dev
- [ ] order-dev
- [ ] payment-dev
- [ ] pricing-dev
- [ ] promotion-dev
- [ ] return-dev
- [ ] review-dev
- [ ] search-dev
- [ ] shipping-dev
- [ ] user-dev
- [ ] warehouse-dev
- [ ] analytics-dev
- [ ] admin-dev
- [ ] frontend-dev
- [ ] infrastructure
- [ ] dapr-system
- [ ] ingress-nginx

#### Step 1.2: Add NetworkPolicy to Wave 0
**Files**: `gitops/apps/*/base/networkpolicy.yaml` (23 files)

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # ✅ ADD THIS
```

**Affected services** (23 total):
- [ ] auth, user, customer, catalog, search, pricing, promotion, review
- [ ] order, payment, shipping, warehouse, fulfillment, notification
- [ ] analytics, location, loyalty-rewards, gateway, checkout, return
- [ ] common-operations, admin, frontend

---

### Phase 2: Services Alignment (Wave 2-7)

#### Step 2.1: Infrastructure Services - Wave 2

**Files to update**:

```yaml
# location/base/deployment.yaml
argocd.argoproj.io/sync-wave: "2"  # ✅ KEEP

# location/base/service.yaml  
argocd.argoproj.io/sync-wave: "2"  # Changed from "1"

# common-operations/base/deployment.yaml
argocd.argoproj.io/sync-wave: "2"  # ✅ KEEP

# common-operations/base/service.yaml
argocd.argoproj.io/sync-wave: "2"  # Changed from "1"

# analytics/base/deployment.yaml
argocd.argoproj.io/sync-wave: "2"  # ADD (currently missing)

# analytics/base/service.yaml
argocd.argoproj.io/sync-wave: "2"  # Changed from "9"

# notification/base/deployment.yaml
argocd.argoproj.io/sync-wave: "2"  # ADD

# notification/base/service.yaml
argocd.argoproj.io/sync-wave: "2"  # ADD
```

**Checklist**:
- [ ] location: deployment + service = wave 2
- [ ] common-operations: deployment + service = wave 2
- [ ] analytics: deployment + service = wave 2
- [ ] notification: deployment + service = wave 2

#### Step 2.2: Core Services - Wave 3

**Files to update**:

```yaml
# auth/base/deployment.yaml
argocd.argoproj.io/sync-wave: "3"  # Changed from "2"

# auth/base/service.yaml
argocd.argoproj.io/sync-wave: "3"  # Changed from "2"

# user/base/deployment.yaml
argocd.argoproj.io/sync-wave: "3"  # Changed from "2"

# user/base/service.yaml
argocd.argoproj.io/sync-wave: "3"  # Changed from "1"

# customer/base/deployment.yaml
argocd.argoproj.io/sync-wave: "3"  # Changed from "2"

# customer/base/service.yaml
argocd.argoproj.io/sync-wave: "3"  # Changed from "2"
```

**Checklist**:
- [ ] auth: deployment + service = wave 3
- [ ] user: deployment + service = wave 3
- [ ] customer: deployment + service = wave 3

#### Step 2.3: Product Services - Wave 4

**Files to update**:

```yaml
# catalog/base/deployment.yaml
argocd.argoproj.io/sync-wave: "4"  # ADD

# catalog/base/service.yaml
argocd.argoproj.io/sync-wave: "4"  # KEEP

# search/base/deployment.yaml
argocd.argoproj.io/sync-wave: "4"  # Changed from "3"

# search/base/service.yaml
argocd.argoproj.io/sync-wave: "4"  # KEEP

# pricing/base/deployment.yaml
argocd.argoproj.io/sync-wave: "4"  # Changed from "3"

# pricing/base/service.yaml
argocd.argoproj.io/sync-wave: "4"  # Changed from "3"

# review/base/deployment.yaml
argocd.argoproj.io/sync-wave: "4"  # Changed from "3"

# review/base/service.yaml
argocd.argoproj.io/sync-wave: "4"  # Changed from "9"

# promotion/base/deployment.yaml
argocd.argoproj.io/sync-wave: "4"  # ADD

# promotion/base/service.yaml
argocd.argoproj.io/sync-wave: "4"  # ADD

# loyalty-rewards/base/deployment.yaml
argocd.argoproj.io/sync-wave: "4"  # Changed from "3"

# loyalty-rewards/base/service.yaml
argocd.argoproj.io/sync-wave: "4"  # Changed from "9"
```

**Checklist**:
- [ ] catalog: deployment + service = wave 4
- [ ] search: deployment + service = wave 4
- [ ] pricing: deployment + service = wave 4
- [ ] review: deployment + service = wave 4
- [ ] promotion: deployment + service = wave 4
- [ ] loyalty-rewards: deployment + service = wave 4

#### Step 2.4: Order Services - Wave 5

**Files to update**:

```yaml
# order/base/deployment.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "4"

# order/base/service.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "6"

# payment/base/deployment.yaml
argocd.argoproj.io/sync-wave: "5"  # ADD

# payment/base/service.yaml
argocd.argoproj.io/sync-wave: "5"  # ADD

# warehouse/base/deployment.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "4"

# warehouse/base/service.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "3"

# shipping/base/deployment.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "4"

# shipping/base/service.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "6"

# fulfillment/base/deployment.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "4"

# fulfillment/base/service.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "8"

# return/base/deployment.yaml
argocd.argoproj.io/sync-wave: "5"  # ADD

# return/base/service.yaml
argocd.argoproj.io/sync-wave: "5"  # Changed from "11"
```

**Checklist**:
- [ ] order: deployment + service = wave 5
- [ ] payment: deployment + service = wave 5
- [ ] warehouse: deployment + service = wave 5
- [ ] shipping: deployment + service = wave 5
- [ ] fulfillment: deployment + service = wave 5
- [ ] return: deployment + service = wave 5

#### Step 2.5: Gateway Layer - Wave 6

**Files to update**:

```yaml
# gateway/base/deployment.yaml
argocd.argoproj.io/sync-wave: "6"  # Changed from "5"

# gateway/base/service.yaml
argocd.argoproj.io/sync-wave: "6"  # Changed from "2"

# checkout/base/deployment.yaml
argocd.argoproj.io/sync-wave: "6"  # Changed from "5"

# checkout/base/service.yaml
argocd.argoproj.io/sync-wave: "6"  # Changed from "7"
```

**Checklist**:
- [ ] gateway: deployment + service = wave 6
- [ ] checkout: deployment + service = wave 6

#### Step 2.6: Frontend - Wave 7

**Files to update**:

```yaml
# admin/base/deployment.yaml
argocd.argoproj.io/sync-wave: "7"  # Changed from "6"

# admin/base/service.yaml
argocd.argoproj.io/sync-wave: "7"  # Changed from "10"

# frontend/base/deployment.yaml
argocd.argoproj.io/sync-wave: "7"  # Changed from "6"

# frontend/base/service.yaml
argocd.argoproj.io/sync-wave: "7"  # Changed from "10"
```

**Checklist**:
- [ ] admin: deployment + service = wave 7
- [ ] frontend: deployment + service = wave 7

---

### Phase 3: Workers Adjustment (Wave 8)

#### Step 3.1: Set All Workers to Wave 8

**Files to update** (12 workers):

```yaml
# auth/base/worker-deployment.yaml (if exists)
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# catalog/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# customer/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# order/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# payment/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# pricing/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# warehouse/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# fulfillment/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# notification/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# search/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# shipping/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"

# common-operations/base/worker-deployment.yaml
argocd.argoproj.io/sync-wave: "8"  # Changed from "7"
```

**Checklist**:
- [ ] All 12 workers set to wave 8

---

## 🚀 IMPLEMENTATION COMMANDS

### Option 1: Automated Script (Recommended)

```bash
#!/bin/bash
# File: scripts/fix-sync-waves.sh

# Phase 1: Namespaces
echo "Phase 1: Adding namespace sync waves..."
# TODO: Add script to update namespaces-with-env.yaml

# Phase 2: NetworkPolicy
echo "Phase 2: Adding NetworkPolicy sync waves..."
for svc in auth user customer catalog search pricing promotion review \
           order payment shipping warehouse fulfillment notification \
           analytics location loyalty-rewards gateway checkout return \
           common-operations admin frontend; do
  
  FILE="gitops/apps/$svc/base/networkpolicy.yaml"
  if [ -f "$FILE" ]; then
    # Add sync-wave annotation if not exists
    if ! grep -q "sync-wave" "$FILE"; then
      sed -i '/metadata:/a\  annotations:\n    argocd.argoproj.io/sync-wave: "0"' "$FILE"
      echo "✅ $svc: Added NetworkPolicy sync-wave"
    fi
  fi
done

# Phase 3: Services sync waves
echo "Phase 3: Standardizing service sync waves..."

# Wave 2: Infrastructure services
for svc in location common-operations analytics notification; do
  sed -i 's/sync-wave: "[0-9]*"/sync-wave: "2"/g' \
    "gitops/apps/$svc/base/deployment.yaml" \
    "gitops/apps/$svc/base/service.yaml"
  echo "✅ $svc: Set to wave 2"
done

# Wave 3: Core services
for svc in auth user customer; do
  sed -i 's/sync-wave: "[0-9]*"/sync-wave: "3"/g' \
    "gitops/apps/$svc/base/deployment.yaml" \
    "gitops/apps/$svc/base/service.yaml"
  echo "✅ $svc: Set to wave 3"
done

# Wave 4: Product services
for svc in catalog search pricing review promotion loyalty-rewards; do
  sed -i 's/sync-wave: "[0-9]*"/sync-wave: "4"/g' \
    "gitops/apps/$svc/base/deployment.yaml" \
    "gitops/apps/$svc/base/service.yaml"
  echo "✅ $svc: Set to wave 4"
done

# Wave 5: Order services
for svc in order payment warehouse shipping fulfillment return; do
  sed -i 's/sync-wave: "[0-9]*"/sync-wave: "5"/g' \
    "gitops/apps/$svc/base/deployment.yaml" \
    "gitops/apps/$svc/base/service.yaml"
  echo "✅ $svc: Set to wave 5"
done

# Wave 6: Gateway
for svc in gateway checkout; do
  sed -i 's/sync-wave: "[0-9]*"/sync-wave: "6"/g' \
    "gitops/apps/$svc/base/deployment.yaml" \
    "gitops/apps/$svc/base/service.yaml"
  echo "✅ $svc: Set to wave 6"
done

# Wave 7: Frontend
for svc in admin frontend; do
  sed -i 's/sync-wave: "[0-9]*"/sync-wave: "7"/g' \
    "gitops/apps/$svc/base/deployment.yaml" \
    "gitops/apps/$svc/base/service.yaml"
  echo "✅ $svc: Set to wave 7"
done

# Phase 4: Workers to wave 8
echo "Phase 4: Setting workers to wave 8..."
find gitops/apps/*/base/worker-deployment.yaml -type f -exec \
  sed -i 's/sync-wave: "[0-9]*"/sync-wave: "8"/g' {} \;
echo "✅ All workers set to wave 8"

echo "✅ Sync wave standardization complete!"
echo "📝 Review changes: git diff"
echo "🚀 Commit: git commit -m 'fix: standardize sync waves (infra → jobs → services)'"
```

### Option 2: Manual Update (File by File)

```bash
# Use checklist above and update each file manually
# Recommended for better control and review
```

---

## ✅ VALIDATION CHECKLIST

### Pre-Deployment Validation

- [ ] All namespaces have `sync-wave: "-10"`
- [ ] All secrets have `sync-wave: "-5"`
- [ ] All serviceaccounts have `sync-wave: "-1"`
- [ ] All configmaps have `sync-wave: "0"`
- [ ] All networkpolicies have `sync-wave: "0"`
- [ ] All migration jobs have `sync-wave: "1"`
- [ ] All deployments and services have matching wave numbers
- [ ] All workers have `sync-wave: "8"`

### Post-Deployment Validation

```bash
# Check ArgoCD sync order
kubectl get applications -n argocd -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.sync.status)"'

# Verify deployment sequence
kubectl get pods --all-namespaces --sort-by=.metadata.creationTimestamp

# Check for sync errors
argocd app list --output json | jq -r '.[] | select(.status.sync.status != "Synced")'
```

---

## 📊 EXPECTED OUTCOMES

### Before Standardization

```
Deployment Order: Random/Inconsistent
- location starts at wave 1
- auth starts at wave 2  
- gateway starts at wave 5
- admin service starts at wave 10
- return service starts at wave 11

Issues:
- Gateway may start before backends ready
- Services start before migrations complete
- Race conditions possible
```

### After Standardization

```
Deployment Order: Predictable
1. Infrastructure (-10 to 0): Namespaces → Secrets → Config → NetworkPolicy
2. Database (1): Migration jobs complete
3. Applications (2-7): Services in dependency order
4. Workers (8): After all apps ready

Benefits:
- No race conditions
- Parallel deployment within waves (5-6 services at once)
- Clear dependency chain
- Easier troubleshooting
```

---

## 🎯 SUCCESS CRITERIA

- [ ] All resources have consistent sync waves
- [ ] Deployment follows: Infrastructure → Jobs → Services → Workers
- [ ] No sync errors in ArgoCD
- [ ] All services start successfully on first deployment
- [ ] Worker pods start after parent services ready
- [ ] Gateway starts after all backends ready
- [ ] Frontend starts after gateway ready

---

**Last Updated**: February 4, 2026  
**Status**: Ready for implementation  
**Estimated Time**: 2-4 hours (with script)

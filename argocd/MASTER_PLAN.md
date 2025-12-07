# ArgoCD Deployment Master Plan

**Created**: December 6, 2024  
**Last Updated**: December 7, 2024 20:30 ICT  
**Status**: 🚀 **DEPLOYMENT PHASE IN PROGRESS** (6/19 deployed)

---

## 📊 Current Status

### Deployment Progress

| Category | Count | Status |
|----------|-------|--------|
| **Deployed to Staging** | 6/19 | 🚀 32% |
| **Config Issues Fixed** | 24/24 | ✅ 100% |
| **Helm Charts Ready** | 19/19 | ✅ 100% |
| **Ready to Deploy** | 13/19 | ⏳ 68% |

### Deployed Services ✅

1. ✅ **auth-service** - Support Services (deployed)
2. ✅ **user-service** - Support Services (deployed)
3. ✅ **gateway** - Support Services (deployed)
4. ✅ **catalog-service** - Core Business (deployed)
5. ✅ **warehouse-service** - Core Business (deployed)
6. ✅ **admin** - Frontend (deployed)

### Pending Deployment ⏳

13 services ready to deploy with all config fixes applied.

---

## 🎯 Deployment Priority & Dependencies

### Tier 1: Infrastructure Services (DEPLOY FIRST)
**Priority**: CRITICAL  
**Dependencies**: None  
**Est. Time**: 1-2 hours total

1. **gateway** ✅ DEPLOYED
   - Entry point for all services
   - No dependencies
   - Must be stable before others

2. **auth-service** ✅ DEPLOYED
   - Required by all services for authentication
   - No dependencies
   - Critical for security

3. **user-service** ✅ DEPLOYED
   - User management
   - Depends on: auth-service
   - Required by most services

---

### Tier 2: Core Business Services (DEPLOY SECOND)
**Priority**: HIGH  
**Dependencies**: Tier 1 + Database  
**Est. Time**: 3-4 hours total

4. **catalog-service** ✅ DEPLOYED
   - Product catalog management
   - Has worker (event processing)
   - Has migration job
   - Depends on: postgresql, redis
   
5. **customer-service** ⏳ READY
   - Customer management
   - Has worker (event processing)
   - Has migration job
   - Depends on: auth-service, user-service

6. **pricing-service** ⏳ READY
   - Pricing engine
   - No worker
   - No migration
   - Depends on: catalog-service

7. **warehouse-service** ✅ DEPLOYED
   - Inventory management
   - Has worker
   - Has migration job
   - Depends on: catalog-service, postgresql

---

### Tier 3: Order & Payment Flow (DEPLOY THIRD)
**Priority**: HIGH  
**Dependencies**: Tier 1 + Tier 2  
**Est. Time**: 3-4 hours total

8. **order-service** ⏳ READY
   - Order processing
   - No worker
   - Has migration job
   - Depends on: catalog, customer, pricing, warehouse

9. **payment-service** ⏳ READY
   - Payment processing
   - No worker
   - No migration
   - Depends on: order-service
   - 🔴 HIGH RISK (financial transactions)

10. **promotion-service** ⏳ READY
    - Promotions & discounts
    - No worker
    - Has migration job
    - Depends on: catalog, order

---

### Tier 4: Fulfillment & Logistics (DEPLOY FOURTH)
**Priority**: MEDIUM  
**Dependencies**: Tier 3  
**Est. Time**: 2-3 hours total

11. **shipping-service** ⏳ READY
    - Shipping management
    - Has worker
    - Has migration job
    - Depends on: order-service, warehouse

12. **fulfillment-service** ⏳ READY
    - Order fulfillment
    - Has worker
    - Has migration job
    - Depends on: order, warehouse, shipping

13. **location-service** ⏳ READY
    - Location/address management
    - No worker
    - Has migration job
    - Depends on: None (standalone)

---

### Tier 5: Support & Integration (DEPLOY FIFTH)
**Priority**: MEDIUM  
**Dependencies**: Tier 2+  
**Est. Time**: 2-3 hours total

14. **search-service** ⏳ READY
    - Product search (Elasticsearch integration)
    - Has worker
    - Has migration job
    - Depends on: catalog-service

15. **review-service** ⏳ READY
    - Product reviews
    - No worker
    - No migration
    - Depends on: catalog, customer

16. **notification-service** ⏳ READY
    - Email/SMS notifications
    - No worker
    - No migration
    - Depends on: customer-service

17. **common-operations-service** ⏳ READY
    - Shared operations
    - Has worker
    - Has migration job
    - Depends on: Multiple services

---

### Tier 6: Frontend Applications (DEPLOY LAST)
**Priority**: LOW  
**Dependencies**: All backend services  
**Est. Time**: 1-2 hours total

18. **admin** ✅ DEPLOYED
    - Admin panel (Vite/React)
    - Depends on: All API services

19. **frontend** ⏳ READY
    - Customer frontend (Next.js)
    - Depends on: All API services
    - Deploy after all backend stable

---

## 🔧 Recent Configuration Fixes (Dec 7, 2024)

All 24 affected services have been fixed:

### Issue #1: ConfigMap Name Mismatch ✅
- **Fixed**: 15 services
- **Issue**: Deployment referenced `{service}-config` but ConfigMap created as `{service}`
- **Impact**: `MountVolume.SetUp failed` errors

### Issue #2: Secret Name Mismatch ✅
- **Fixed**: 9 services  
- **Issue**: Secret created as `{service}-secrets` but referenced as `{service}`
- **Impact**: `secret not found` errors

### Issue #3: Missing Database Config ✅
- **Fixed**: 9 services
- **Added**: `database-host`, `database-port`, `database-name` to ConfigMaps
- **Impact**: Migration jobs now have database connection details

### Issue #4: Worker Dapr Configuration ✅
- **Fixed**: 7 workers
- **Change**: Added `dapr.io/enabled: "false"` to worker deployments
- **Reason**: Workers don't have HTTP servers, only consume events

### Issue #5: ApplicationSet selfHeal Type ✅
- **Fixed**: 18 ApplicationSets
- **Change**: Changed from string `"true"/"false"` to boolean `true/false`
- **Impact**: ApplicationSets now validate correctly

### Issue #6: Secrets Protocol ✅
- **Fixed**: 16 ApplicationSets
- **Change**: Removed `secrets://` prefix (ArgoCD Vault Plugin not installed)
- **Impact**: Secrets files now load correctly as plain values

---

## 📅 Recommended Deployment Schedule

### Week 1: Tier 1-2 Foundation (Dec 8-14)
**Target**: 7 services total (3 already deployed + 4 new)

**Already Deployed**:
- ✅ gateway
- ✅ auth-service  
- ✅ user-service
- ✅ catalog-service
- ✅ warehouse-service

**Deploy This Week**:
- Mon-Tue: customer-service (test 24h)
- Wed-Thu: pricing-service (test 24h)

**Success Criteria**:
- All Tier 1-2 services healthy
- Core business logic working
- Event processing functional (workers)

---

### Week 2: Tier 3 Order Flow (Dec 15-21)
**Target**: 3 services

**Deploy**:
- Mon-Tue: order-service (test 48h - CRITICAL)
- Wed: promotion-service (test 24h)
- Thu-Fri: payment-service (test 48h - HIGH RISK)

**Success Criteria**:
- End-to-end order flow working
- Payment integration tested
- No financial transaction errors

**Special Attention**:
- payment-service: Deploy during low-traffic hours
- Extensive testing before production

---

### Week 3: Tier 4 Fulfillment (Dec 22-28)
**Target**: 3 services

**Deploy**:
- Mon: location-service (standalone, test 24h)
- Tue-Wed: shipping-service (test 24h)
- Thu-Fri: fulfillment-service (test 48h)

**Success Criteria**:
- Complete order-to-delivery flow
- Inventory updates working
- Shipping integration functional

---

### Week 4: Tier 5 Support Services (Dec 29 - Jan 4)
**Target**: 4 services

**Deploy**:
- Mon: search-service (test 24h)
- Tue: review-service (test 24h)
- Wed: notification-service (test 24h)
- Thu: common-operations-service (test 24h)

**Success Criteria**:
- Search functionality working
- Notifications sent correctly
- All integrations stable

---

### Week 5: Tier 6 Frontend (Jan 5-11)
**Target**: 1 service (admin already deployed)

**Already Deployed**:
- ✅ admin

**Deploy**:
- Mon-Tue: frontend (Next.js customer app)
- Wed-Fri: Full system testing

**Success Criteria**:
- Customer can browse, order, pay
- Admin can manage all resources
- All features working end-to-end

---

## 🚨 Critical Deployment Notes

### Pre-Deployment Checklist

For each service, verify:

✅ **Config Validated**:
```bash
cd argocd/scripts
./fix-configmap-names.sh --verify
helm template {service} argocd/applications/{service} --dry-run
```

✅ **Secrets Ready**:
- staging/secrets.yaml exists
- All required keys present
- Values are correct for environment

✅ **Dependencies Running**:
- Check dependent services are healthy
- Database migrations completed
- Redis/Consul accessible

✅ **Manual Resources Created** (if needed):
```bash
# Create ConfigMap/Secret first to avoid deadlock
helm template {service} . --values staging/values.yaml --values staging/secrets.yaml > /tmp/{service}.yaml
# Extract and apply ConfigMap, Secret manually
```

---

### Deployment Command

```bash
# 1. Verify
helm template {service} argocd/applications/{service} --values staging/values.yaml --dry-run

# 2. Optional: Create ConfigMap/Secret manually first
kubectl apply -f /tmp/{service}-configmap.yaml -n {namespace}
kubectl apply -f /tmp/{service}-secret.yaml -n {namespace}

# 3. Sync via ArgoCD
argocd app sync {service}-staging

# 4. Monitor
kubectl get pods -n {namespace} -l app.kubernetes.io/name={service} -w
kubectl logs -n {namespace} -l app.kubernetes.io/name={service} -f --tail=50
```

---

### Post-Deployment Verification

✅ **Health Checks**:
```bash
# Check deployment
kubectl get deployment {service} -n {namespace}

# Check pods
kubectl get pods -n {namespace} -l app.kubernetes.io/name={service}

# Check migration job (if exists)
kubectl get jobs -n {namespace} -l app.kubernetes.io/component=migration

# Check worker (if exists)
kubectl get pods -n {namespace} -l app.kubernetes.io/component=worker
```

✅ **API Testing**:
```bash
# Health endpoint
curl http://{service}.{namespace}.svc.cluster.local/api/v1/{service}/health

# Port forward for local testing
kubectl port-forward -n {namespace} svc/{service} 8080:80
curl http://localhost:8080/api/v1/{service}/health
```

---

## 📊 Service Categorization

### By Complexity

**🟢 Low Complexity** (Quick Deploy - 1-2h each):
- location-service
- pricing-service
- review-service
- notification-service

**🟡 Medium Complexity** (Standard Deploy - 2-3h each):
- customer-service
- warehouse-service (deployed)
- catalog-service (deployed)
- promotion-service
- shipping-service
- fulfillment-service
- search-service
- common-operations-service

**🔴 High Complexity** (Careful Deploy - 3-4h each):
- gateway (deployed)
- auth-service (deployed)
- order-service
- payment-service

---

### By Database Dependencies

**PostgreSQL + Migration**:
- catalog-service ✅
- customer-service
- warehouse-service ✅
- order-service
- shipping-service
- fulfillment-service
- search-service
- location-service
- common-operations-service
- auth-service ✅
- user-service ✅
- promotion-service

**No Database**:
- gateway ✅
- pricing-service
- payment-service
- review-service
- notification-service
- admin ✅
- frontend

---

### By Worker Deployment

**Has Worker** (Event Processing):
- catalog-service ✅
- customer-service
- warehouse-service ✅
- shipping-service
- fulfillment-service
- search-service
- common-operations-service

**No Worker**:
- All others (12 services)

---

## 🎓 Lessons Learned

### Key Insights from Catalog Deployment

1. **ConfigMap Deadlock**: Migration jobs wait for ConfigMap, but ArgoCD waits for migration job
   - **Solution**: Create ConfigMap/Secret manually first

2. **Worker Dapr**: Workers don't need Dapr (no HTTP server)
   - **Solution**: Add `dapr.io/enabled: "false"` annotation

3. **Secret Loading**: `secrets://` protocol needs plugin
   - **Solution**: Use plain path if plugin not installed

4. **Database Config**: Migration jobs need individual DB keys
   - **Solution**: Add `database-host/port/name` to ConfigMap

5. **Validation First**: Always run pre-deploy validation
   - **Solution**: Use provided scripts and helm dry-run

---

## 📚 Documentation

### Quick References

- **Deployment Checklist**: [SERVICE_DEPLOYMENT_CHECKLIST.md](../argocd/docs/SERVICE_DEPLOYMENT_CHECKLIST.md)
- **Fix Scripts**: `argocd/scripts/fix-configmap-names.sh`
- **Troubleshooting**: See deployment checklist

### Validation Tools

```bash
# ConfigMap/Secret verification
cd argocd/scripts
./fix-configmap-names.sh --verify

# YAML syntax
helm template {service} argocd/applications/{service} --dry-run

# ApplicationSet validation
kubectl apply --dry-run=client -f {service}-appSet.yaml
```

---

## 🎯 Success Metrics

### Per-Service Goals

- ✅ Deployment successful via ArgoCD
- ✅ All pods Running (main + worker if exists)
- ✅ Migration job Completed (if exists)
- ✅ Health checks passing
- ✅ No crash loops for 24 hours
- ✅ Logs show no critical errors
- ✅ Integrations with dependencies working

### Overall Goals

- ✅ 100% services deployed to staging
- ✅ 0 critical bugs in staging
- ✅ All E2E flows working
- ✅ Performance acceptable
- ✅ Ready for production rollout

---

## 📈 Progress Tracking

### Deployment Status

| Tier | Services | Deployed | Remaining | Progress |
|------|----------|----------|-----------|----------|
| Tier 1 | 3 | 3 | 0 | ✅ 100% |
| Tier 2 | 4 | 2 | 2 | 🚧 50% |
| Tier 3 | 3 | 0 | 3 | ⏳ 0% |
| Tier 4 | 3 | 0 | 3 | ⏳ 0% |
| Tier 5 | 4 | 0 | 4 | ⏳ 0% |
| Tier 6 | 2 | 1 | 1 | 🚧 50% |
| **Total** | **19** | **6** | **13** | **32%** |

### Weekly Milestones

- Week 1 (Dec 8-14): Target 7/19 (37%)
- Week 2 (Dec 15-21): Target 10/19 (53%)
- Week 3 (Dec 22-28): Target 13/19 (68%)
- Week 4 (Dec 29-Jan 4): Target 17/19 (89%)
- Week 5 (Jan 5-11): Target 19/19 (100%)

---

## 🚀 Next Actions

### Immediate (This Week)

1. **Deploy customer-service** (Mon-Tue)
   - Pre-create ConfigMap/Secret
   - Monitor worker deployment
   - Test event processing

2. **Deploy pricing-service** (Wed-Thu)
   - Simpler service (no worker/migration)
   - Quick validation

### Next Week

1. **Deploy order-service** (Mon-Tue)
   - Critical service, test extensively
   - Monitor 48 hours before payment

2. **Deploy promotion-service** (Wed)
3. **Deploy payment-service** (Thu-Fri)
   - HIGH RISK - deploy carefully
   - Low traffic hours
   - Extensive testing

---

**Last Updated**: December 7, 2024 20:30 ICT  
**Next Review**: December 8, 2024  
**Status**: 🚀 Ready for Tier 2 completion


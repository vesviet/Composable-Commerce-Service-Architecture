# Quick Action Guide - Configuration Fixes

**Mục đích**: Hướng dẫn nhanh để implement các fixes quan trọng nhất  
**Cập nhật**: December 27, 2025  
**Ưu tiên**: 🔴 **CRITICAL** - Cần làm ngay

---

## 🚀 **Immediate Actions (Do Today)**

### 1. Fix Auth Service Health Probes ⚠️ **CRITICAL**

**File**: `argocd/applications/auth-service/values.yaml`

**Current (Wrong)**:
```yaml
livenessProbe:
  httpGet:
    path: /health    # ❌ Generic endpoint
    port: 80
readinessProbe:
  httpGet:
    path: /health    # ❌ Generic endpoint
    port: 80
```

**Fix To (Correct)**:
```yaml
livenessProbe:
  httpGet:
    path: /health/live    # ✅ Specific liveness endpoint
    port: 80
  initialDelaySeconds: 90   # ✅ Allow startup time
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 5

readinessProbe:
  httpGet:
    path: /health/ready   # ✅ Specific readiness endpoint
    port: 80
  initialDelaySeconds: 60   # ✅ Faster than liveness
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 3
```

### 2. Fix Redis DB Conflicts ⚠️ **CRITICAL**

**Multiple services using Redis DB 0 - CONFLICT!**

#### Fix Order Service
**File**: `argocd/applications/order-service/values.yaml`
```yaml
# Line ~117
config:
  data:
    redis:
      db: 1  # Change from 0 to 1
```

#### Fix Notification Service  
**File**: `argocd/applications/notification-service/values.yaml`
```yaml
config:
  data:
    redis:
      db: 11  # Change from 0 to 11
```

#### Fix Search Service
**File**: `argocd/applications/search-service/values.yaml`
```yaml
config:
  data:
    redis:
      db: 12  # Change from 0 to 12
```

#### Fix Shipping Service
**File**: `argocd/applications/shipping-service/values.yaml`
```yaml
config:
  data:
    redis:
      db: 13  # Change from 0 to 13
```

### 3. Verify FQDN Usage ⚠️ **CRITICAL**

**Run this command to check for issues**:
```bash
# Check for non-FQDN usage
grep -r "postgres:" argocd/applications/*/values.yaml | grep -v "postgres.infrastructure"
grep -r "redis:" argocd/applications/*/values.yaml | grep -v "redis.infrastructure"  
grep -r "consul:" argocd/applications/*/values.yaml | grep -v "consul.infrastructure"
```

**If found, fix to use FQDN**:
```yaml
# ✅ Correct FQDN format
redis:
  addr: "redis.infrastructure.svc.cluster.local:6379"
consul:
  address: "consul.infrastructure.svc.cluster.local:8500"
# Database URL should use: postgres.infrastructure.svc.cluster.local:5432
```

---

## 📋 **Validation Commands**

### Test Health Endpoints
```bash
# Test auth service after fix
curl http://auth-service/health/live
curl http://auth-service/health/ready

# Test catalog service (should already work)
curl http://catalog-service/health/live
curl http://catalog-service/health/ready
```

### Test Redis Connections
```bash
# Check Redis connections after DB changes
kubectl exec -it deployment/order-service -- redis-cli -h redis.infrastructure.svc.cluster.local -n 1 ping
kubectl exec -it deployment/notification-service -- redis-cli -h redis.infrastructure.svc.cluster.local -n 11 ping
```

### Validate Helm Templates
```bash
# Validate auth service config
cd argocd/applications/auth-service
helm template . --debug --dry-run

# Validate order service config  
cd argocd/applications/order-service
helm template . --debug --dry-run
```

---

## 🔍 **Next Priority Services to Check**

### Services Need Health Probe Audit:
1. **payment-service** - Check if uses specific endpoints
2. **user-service** - Check if uses specific endpoints
3. **customer-service** - Check if uses specific endpoints
4. **fulfillment-service** - Check if uses specific endpoints
5. **location-service** - Check if uses specific endpoints

### Command to Check:
```bash
# Check current probe configuration
grep -A 10 "livenessProbe:" argocd/applications/payment-service/values.yaml
grep -A 10 "readinessProbe:" argocd/applications/payment-service/values.yaml
```

---

## 🎯 **Success Criteria for Today**

- [ ] Auth service uses `/health/live` and `/health/ready` probes
- [ ] No Redis DB conflicts (all services use unique DB numbers)
- [ ] All checked services use FQDN for infrastructure dependencies
- [ ] Helm templates validate without errors
- [ ] Health endpoints respond correctly

---

## 🚨 **If Something Breaks**

### Rollback Auth Service
```bash
# Revert to original probe paths if needed
git checkout HEAD -- argocd/applications/auth-service/values.yaml
```

### Rollback Redis Changes
```bash
# Revert specific service if Redis connection fails
git checkout HEAD -- argocd/applications/order-service/values.yaml
```

### Check Service Status
```bash
# Check if services are healthy after changes
kubectl get pods -l app=auth-service
kubectl get pods -l app=order-service
kubectl logs -l app=auth-service --tail=50
```

---

## 📞 **Need Help?**

- **Slack**: #devops-support
- **Documentation**: [Implementation Checklist](./IMPLEMENTATION_CHECKLIST.md)
- **Rollback**: All changes are in git, easy to revert

---

**Remember**: 
- Make changes one service at a time
- Test after each change
- Keep git commits small and focused
- Document any issues found

**Next Steps**: After these critical fixes, move to Phase 2 (PDB, ServiceMonitor, NetworkPolicy)
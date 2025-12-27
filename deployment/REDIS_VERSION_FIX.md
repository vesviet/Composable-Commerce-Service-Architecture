# Redis Version Compatibility Fix

**Issue**: `ERR unknown subcommand 'maint_notifications'`  
**Cause**: Redis client/server version mismatch  
**Impact**: Warning logs, reduced performance (client-side caching disabled)  
**Urgency**: 🟡 **MEDIUM** - Service works but with warnings

---

## 🔍 **Problem Analysis**

### Error Details:
```
redis: 2025/12/27 21:00:46 redis.go:478: auto mode fallback: 
maintnotifications disabled due to handshake error: 
ERR unknown subcommand 'maint_notifications'. Try CLIENT HELP
```

### Root Cause:
- **Redis Client** (go-redis) trying to use Redis 6.2+ features
- **Redis Server** is older version (likely 6.0 or 5.x)
- `maint_notifications` is part of client-side caching feature

---

## 🚀 **Quick Fix (Apply Today)**

### Add to ALL services using Redis:

```yaml
# argocd/applications/{service-name}/values.yaml
config:
  data:
    redis:
      addr: "redis.infrastructure.svc.cluster.local:6379"
      db: {unique_number}
      disable_cache: true        # ✅ Add this line
      protocol: 2               # ✅ Force RESP2 protocol  
      read_timeout: 0.2s
      write_timeout: 0.2s
```

### Services to Update:
- [ ] auth-service
- [ ] catalog-service  
- [ ] customer-service
- [ ] order-service
- [ ] payment-service
- [ ] notification-service
- [ ] user-service
- [ ] fulfillment-service
- [ ] location-service
- [ ] pricing-service
- [ ] promotion-service
- [ ] review-service
- [ ] search-service
- [ ] shipping-service
- [ ] warehouse-service

---

## 🔧 **Long-term Fix (Next Sprint)**

### 1. Update Redis Infrastructure
```yaml
# argocd/applications/infrastructure/redis/values.yaml
image:
  repository: redis
  tag: "7.2-alpine"  # Update from current version
  pullPolicy: IfNotPresent

# Check current version first:
# kubectl exec -it deployment/redis -n infrastructure -- redis-cli INFO server
```

### 2. Update Go Redis Client
```go
// go.mod - Update to latest version
github.com/redis/go-redis/v9 v9.3.0  // Latest version
```

### 3. Enable Client-side Caching (After Redis upgrade)
```yaml
# After Redis 7.x upgrade, remove these:
config:
  data:
    redis:
      # disable_cache: true     # Remove this
      # protocol: 2            # Remove this
      enable_cache: true       # Add this instead
```

---

## 📋 **Implementation Steps**

### Step 1: Check Current Redis Version
```bash
kubectl exec -it deployment/redis -n infrastructure -- redis-cli INFO server | grep redis_version
```

### Step 2: Apply Quick Fix to Services
```bash
# Example for auth-service
cd argocd/applications/auth-service
# Edit values.yaml to add disable_cache: true
helm template . --debug --dry-run  # Validate
```

### Step 3: Validate Fix
```bash
# Check logs after deployment
kubectl logs -l app=auth-service --tail=50 | grep -i redis
# Should not see maint_notifications error anymore
```

### Step 4: Plan Redis Upgrade
```bash
# Check Redis usage and plan maintenance window
kubectl get pods -n infrastructure | grep redis
kubectl describe deployment/redis -n infrastructure
```

---

## 🔍 **Validation Commands**

### Before Fix:
```bash
# Check for Redis errors in logs
kubectl logs -l app=auth-service | grep "maint_notifications"
kubectl logs -l app=catalog-service | grep "maint_notifications"
```

### After Fix:
```bash
# Should not see maint_notifications errors
kubectl logs -l app=auth-service --since=5m | grep -i redis
# Should see normal Redis connection logs only
```

### Test Redis Connectivity:
```bash
# Test Redis connection from service
kubectl exec -it deployment/auth-service -- redis-cli -h redis.infrastructure.svc.cluster.local ping
```

---

## 📊 **Impact Assessment**

### Current State:
- ✅ **Services work normally**
- ⚠️ **Warning logs every connection**
- 📉 **No client-side caching** (slight performance impact)
- 🔄 **Auto-fallback to compatible mode**

### After Quick Fix:
- ✅ **No more warning logs**
- ✅ **Services work normally**  
- 📊 **Same performance** (caching still disabled)
- 🧹 **Clean logs**

### After Long-term Fix:
- ✅ **No warning logs**
- ✅ **Services work normally**
- 📈 **Better performance** (client-side caching enabled)
- 🚀 **Latest Redis features available**

---

## 🚨 **Rollback Plan**

If quick fix causes issues:
```bash
# Remove the added config lines
git checkout HEAD -- argocd/applications/{service-name}/values.yaml
kubectl rollout restart deployment/{service-name}
```

---

## 📞 **Support**

- **Slack**: #devops-support
- **Documentation**: [Redis Configuration Guide](./common-service-dependencies.md#redis-configuration)
- **Monitoring**: Check service logs and Redis metrics

---

**Priority**: 🟡 **MEDIUM** - Apply quick fix when convenient, plan upgrade for next sprint
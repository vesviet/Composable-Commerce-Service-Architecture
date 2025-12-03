# 🚀 Staging Deployment Quick Checklist

**Quick reference cho deploy staging K8s**

---

## ✅ Pre-Deployment (1-2 days)

### 1. Verify Infrastructure ✅
- [x] Cluster running: `kubectl get nodes`
- [x] Infrastructure services running: `kubectl get pods -n infrastructure`
- [x] Storage classes created: `kubectl get storageclass`

### 2. Prepare Application Services ⚠️
- [ ] **Audit manifests**: Check all 19 services have `deploy/local/deployment.yaml`
- [ ] **Create Secrets**: 
  ```bash
  kubectl create secret generic auth-service-secrets \
    --from-literal=DB_PASSWORD=staging_pass \
    -n support-services
  ```
- [ ] **Build images**: 
  ```bash
  for svc in auth user customer order payment catalog warehouse shipping fulfillment pricing promotion loyalty review notification search location gateway; do
    docker build -t localhost:5000/$svc:staging -f $svc/Dockerfile $svc/
  done
  ```
- [ ] **Optimize resources**: Giảm requests xuống 50-70% cho staging

---

## 📦 Deployment Order

### Phase 1: Support Services (1 day)
```bash
cd /home/user/microservices/k8s-local
./deploy-services.sh auth
./deploy-services.sh location
./deploy-services.sh notification
./deploy-services.sh search
```

**Verify**:
```bash
kubectl get pods -n support-services
kubectl port-forward svc/auth-service 8002:8002 -n support-services
curl http://localhost:8002/health
```

### Phase 2: Core Services - Batch 1 (Independent)
```bash
./deploy-services.sh user        # depends: Auth ✅
./deploy-services.sh customer    # depends: Auth ✅, Notification ✅
./deploy-services.sh pricing     # depends: Location ✅
./deploy-services.sh catalog     # depends: Pricing ✅
```

### Phase 3: Core Services - Batch 2 (Dependencies)
```bash
./deploy-services.sh warehouse   # depends: Catalog ✅
./deploy-services.sh shipping     # depends: Location ✅
./deploy-services.sh promotion    # depends: Customer ✅
```

### Phase 4: Core Services - Batch 3 (Order Flow)
```bash
./deploy-services.sh order        # depends: Payment, Warehouse, Shipping, Pricing, Promotion
./deploy-services.sh payment      # depends: Order (circular - retry OK)
./deploy-services.sh fulfillment  # depends: Order ✅, Warehouse ✅, Shipping ✅
```

### Phase 5: Core Services - Batch 4 (Remaining)
```bash
./deploy-services.sh loyalty      # depends: Order ✅, Customer ✅
./deploy-services.sh review       # depends: Order ✅, Customer ✅, Catalog ✅
```

### Phase 6: Integration Services
```bash
./deploy-services.sh gateway      # depends: All services ✅
./deploy-services.sh admin        # depends: Gateway ✅
./deploy-services.sh frontend     # depends: Gateway ✅
```

### Phase 7: Monitoring (Optional - có thể deploy sớm hơn)
```bash
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/grafana/
kubectl apply -f monitoring/loki/
kubectl apply -f monitoring/jaeger/
```

---

## 🔍 Verification Commands

### Check Pods Status
```bash
# All namespaces
kubectl get pods -A

# Specific namespace
kubectl get pods -n support-services
kubectl get pods -n core-services
kubectl get pods -n integration-services
```

### Check Services
```bash
kubectl get svc -A
```

### Check Resource Usage
```bash
kubectl top nodes
kubectl top pods -A
```

### Test Service Health
```bash
# Port forward
kubectl port-forward svc/auth-service 8002:8002 -n support-services

# Test health
curl http://localhost:8002/health
```

### Check Logs
```bash
kubectl logs -f <pod-name> -n <namespace>
```

---

## 🚨 Troubleshooting

### Pod Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check previous logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous
```

### Service Can't Connect
```bash
# Check service endpoints
kubectl get endpoints -n <namespace>

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>.<namespace>.svc.cluster.local
```

### Resource Issues
```bash
# Check node resources
kubectl describe node <node-name>

# Check pod resource requests/limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 resources
```

---

## 📊 Success Criteria

### Deployment Success
- ✅ All pods in `Running` state
- ✅ All health checks passing
- ✅ Services can discover each other
- ✅ Database connections working

### Performance
- ✅ API response time <500ms
- ✅ Total RAM usage <25GB
- ✅ Pod startup time <60s

### Functionality
- ✅ End-to-end checkout flow works
- ✅ Admin panel accessible
- ✅ Frontend accessible

---

## 🎯 Quick Commands Reference

```bash
# Deploy single service
cd /home/user/microservices/k8s-local
./deploy-services.sh <service-name>

# Deploy all services (careful - follow order!)
./deploy-all.sh

# Check status
kubectl get pods -A
kubectl get svc -A

# Port forward
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>

# View logs
kubectl logs -f <pod-name> -n <namespace>

# Delete deployment (rollback)
kubectl delete deployment <service-name> -n <namespace>
```

---

**See full review**: [STAGING_DEPLOYMENT_REVIEW.md](./STAGING_DEPLOYMENT_REVIEW.md)


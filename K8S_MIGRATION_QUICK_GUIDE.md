# K8s Config Migration - Quick Reference Guide

> **Quick guide** cho việc chuẩn hóa config của microservices
> 
> **Full checklist:** `K8S_CONFIG_STANDARDIZATION_CHECKLIST.md`

---

## 🚀 Quick Start (5 minutes)

```bash
# 1. Setup structure
cd /home/user/microservices/<SERVICE_NAME>
mkdir -p deploy/local scripts

# 2. Move manifests
mv /home/user/microservices/k8s-local/services/<SERVICE_NAME>/* deploy/local/

# 3. Remove duplicates
rm config/config.yaml 2>/dev/null || true
mv configs/config-dev.yaml configs/config-local.yaml 2>/dev/null || true

# 4. Create secrets (edit values!)
cat > deploy/local/secrets.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: <SERVICE_NAME>-secrets
  namespace: development
type: Opaque
stringData:
  database-url: "postgres://user:pass@postgres.infrastructure.svc.cluster.local:5432/db?sslmode=disable"
  redis-password: ""
  encryption-key: "dev-32-character-encryption-key"
EOF

# 5. Test
kubectl apply --dry-run=client -f deploy/local/
```

---

## 📝 Templates

### Secrets Template

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <SERVICE_NAME>-secrets
  namespace: development
type: Opaque
stringData:
  database-url: "postgres://<USER>:<PASS>@postgres.infrastructure.svc.cluster.local:5432/<DB>?sslmode=disable"
  redis-password: ""
  encryption-key: "dev-32-character-encryption-key"
```

### ConfigMap Template

```yaml
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
      redis:
        addr: "redis.infrastructure.svc.cluster.local:6379"
        db: 0
    <SERVICE_NAME>:
      # Service-specific config here
```

### Deployment Env Vars (Secret Injection)

```yaml
env:
- name: <SERVICE_PREFIX>_DATA_DATABASE_SOURCE
  valueFrom:
    secretKeyRef:
      name: <SERVICE_NAME>-secrets
      key: database-url

- name: <SERVICE_PREFIX>_DATA_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: <SERVICE_NAME>-secrets
      key: redis-password
      optional: true

- name: <SERVICE_PREFIX>_SECURITY_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: <SERVICE_NAME>-secrets
      key: encryption-key
      optional: true
```

### Deploy Script Template

```bash
#!/bin/bash
set -e

SERVICE_NAME="<SERVICE_NAME>"
NAMESPACE="development"
IMAGE_NAME="k3d-local-registry:5000/${SERVICE_NAME}-service:latest"

echo "🚀 Deploying ${SERVICE_NAME}..."

# Build if --build flag
if [[ "$1" == "--build" ]]; then
    cd "$(dirname "$0")/../.."
    docker build -f ${SERVICE_NAME}/Dockerfile -t "$IMAGE_NAME" .
    docker push "$IMAGE_NAME"
    k3d image import "$IMAGE_NAME" -c microservices
fi

cd "$(dirname "$0")/.."

# Deploy
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f deploy/local/secrets.yaml
kubectl apply -f deploy/local/configmap.yaml

# Migration (if exists)
if [ -f deploy/local/migration-job.yaml ]; then
    kubectl delete job ${SERVICE_NAME}-migration -n "$NAMESPACE" --ignore-not-found
    kubectl apply -f deploy/local/migration-job.yaml
    kubectl wait --for=condition=complete job/${SERVICE_NAME}-migration -n "$NAMESPACE" --timeout=120s
fi

# Deploy service
kubectl apply -f deploy/local/deployment.yaml
kubectl apply -f deploy/local/service.yaml
[ -f deploy/local/deployment-worker.yaml ] && kubectl apply -f deploy/local/deployment-worker.yaml

# Wait
kubectl wait --for=condition=ready pod -l app=${SERVICE_NAME}-service -n "$NAMESPACE" --timeout=120s

echo "✅ Done!"
kubectl get pods -n "$NAMESPACE" -l app=${SERVICE_NAME}-service
```

### Makefile Targets

```makefile
.PHONY: deploy-local rebuild-local restart-local logs-local clean-local

deploy-local:
	@./scripts/deploy-local.sh

rebuild-local:
	@./scripts/deploy-local.sh --build

restart-local:
	@kubectl rollout restart deployment/<SERVICE_NAME>-service -n development

logs-local:
	@kubectl logs -f deployment/<SERVICE_NAME>-service -n development

clean-local:
	@kubectl delete -f deploy/local/ -n development --ignore-not-found

status-local:
	@kubectl get pods,svc,cm,secret -n development -l app=<SERVICE_NAME>-service
```

---

## 🔍 Validation Commands

```bash
# Check for secrets in ConfigMap (should be empty)
grep -ri "password\|secret\|token" deploy/local/configmap.yaml | grep -v "^#"

# Validate all manifests
kubectl apply --dry-run=client -f deploy/local/

# Test secret injection
kubectl exec deployment/<SERVICE_NAME>-service -n development -- env | grep <SERVICE_PREFIX>

# Check mounted config
kubectl exec deployment/<SERVICE_NAME>-service -n development -- cat /app/configs/config.yaml

# View logs
kubectl logs -f deployment/<SERVICE_NAME>-service -n development

# Port forward
kubectl port-forward svc/<SERVICE_NAME>-service 8080:80 -n development
```

---

## 🐛 Common Issues

### Issue: Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs -l app=<SERVICE_NAME>-service -n development --tail=100

# Check events
kubectl get events -n development --sort-by='.lastTimestamp' | grep <SERVICE_NAME>

# Describe pod
kubectl describe pod -l app=<SERVICE_NAME>-service -n development
```

### Issue: Secret not found

```bash
# Check secret exists
kubectl get secret <SERVICE_NAME>-secrets -n development

# View secret (base64 encoded)
kubectl get secret <SERVICE_NAME>-secrets -n development -o yaml

# Decode secret
kubectl get secret <SERVICE_NAME>-secrets -n development -o jsonpath='{.data.database-url}' | base64 -d
```

### Issue: ConfigMap not mounted

```bash
# Check ConfigMap
kubectl get configmap <SERVICE_NAME>-config -n development

# Check mount in pod
kubectl exec deployment/<SERVICE_NAME>-service -n development -- ls -la /app/configs/
```

### Issue: Migration failed

```bash
# Check job status
kubectl get job <SERVICE_NAME>-migration -n development

# View logs
kubectl logs job/<SERVICE_NAME>-migration -n development

# Delete and retry
kubectl delete job <SERVICE_NAME>-migration -n development
kubectl apply -f deploy/local/migration-job.yaml
```

---

## 📊 Service-Specific Placeholders

**Replace these in templates:**

| Placeholder | Example | Description |
|-------------|---------|-------------|
| `<SERVICE_NAME>` | `catalog` | Service name (lowercase) |
| `<SERVICE_PREFIX>` | `CATALOG` | Env var prefix (UPPERCASE) |
| `<USER>` | `catalog_user` | Database username |
| `<PASS>` | `catalog_pass` | Database password |
| `<DB>` | `catalog_db` | Database name |

**Common service prefixes:**

| Service | Prefix |
|---------|--------|
| catalog | `CATALOG` |
| order | `ORDER` |
| user | `USER` |
| auth | `AUTH` |
| warehouse | `WAREHOUSE` |
| pricing | `PRICING` |
| shipping | `SHIPPING` |
| payment | `PAYMENT` |

---

## ⏱️ Time Estimates

| Phase | Time | Can Skip? |
|-------|------|-----------|
| Structure cleanup | 10 min | No |
| Secrets extraction | 15 min | No |
| ConfigMap creation | 20 min | No |
| Deployment update | 15 min | No |
| Scripts creation | 20 min | Yes (manual deploy OK) |
| Testing | 20 min | No |
| Documentation | 10 min | Yes |
| **Total** | **~2 hours** | |

---

## 📁 Final Directory Structure

```
<SERVICE_NAME>/
├── config/
│   ├── config.go
│   └── loader.go
├── configs/
│   ├── config.yaml           # Production
│   ├── config-docker.yaml    # Docker Compose
│   └── config-local.yaml     # K8s local
├── deploy/
│   └── local/
│       ├── configmap.yaml
│       ├── secrets.yaml
│       ├── deployment.yaml
│       ├── deployment-worker.yaml  # Optional
│       ├── service.yaml
│       └── migration-job.yaml      # Optional
├── scripts/
│   └── deploy-local.sh
└── Makefile
```

---

## ✅ Quick Checklist

**Before starting:**
- [ ] Service working in current setup
- [ ] K3d cluster running
- [ ] Backup current manifests

**Migration:**
- [ ] Create `deploy/local/` directory
- [ ] Move manifests from `k8s-local/services/`
- [ ] Create `secrets.yaml`
- [ ] Update `configmap.yaml` (remove secrets)
- [ ] Update `deployment.yaml` (add secret env vars)
- [ ] Create `scripts/deploy-local.sh`
- [ ] Add Makefile targets

**Testing:**
- [ ] `kubectl apply --dry-run=client -f deploy/local/`
- [ ] `./scripts/deploy-local.sh --build`
- [ ] Pods running
- [ ] Health check OK
- [ ] Secrets injected
- [ ] Config loaded

**Cleanup:**
- [ ] Remove old manifests
- [ ] Update README
- [ ] Git commit

---

## 🎯 Batch Processing Strategy

**Recommended order:**

1. **Core services** (1-2 services):
   - catalog
   - user

2. **Business logic** (2-3 services):
   - order
   - warehouse
   - pricing

3. **Supporting services** (2-3 services):
   - shipping
   - payment
   - notification

4. **Remaining services**

**Parallel processing:**
- Can do 2-3 services simultaneously
- Test each batch before moving to next
- Keep notes on service-specific issues

---

## 📞 Quick Help

**Get service info:**
```bash
SERVICE=catalog  # Change this

kubectl get all -n development -l app=${SERVICE}-service
kubectl logs -f deployment/${SERVICE}-service -n development
kubectl describe deployment/${SERVICE}-service -n development
```

**Quick restart:**
```bash
kubectl rollout restart deployment/<SERVICE_NAME>-service -n development
kubectl rollout status deployment/<SERVICE_NAME>-service -n development
```

**Quick delete:**
```bash
kubectl delete -f deploy/local/ -n development
```

**Quick redeploy:**
```bash
./scripts/deploy-local.sh --build
```

---

**For full details, see:** `K8S_CONFIG_STANDARDIZATION_CHECKLIST.md`

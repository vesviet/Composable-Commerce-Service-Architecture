# 🚀 Staging Deployment Plan với ArgoCD (GitOps)

**Ngày tạo:** December 2, 2025  
**Approach:** GitOps với ArgoCD thay vì manual deployment

---

## 🎯 Overview

### Thay đổi từ Manual → GitOps

**Trước (Manual)**:
```bash
# Manual deployment
./deploy-services.sh auth
kubectl apply -f auth/deploy/local/
```

**Sau (GitOps với ArgoCD)**:
```bash
# 1. Update manifests trong Git
git add services/staging/auth-service/
git commit -m "Update auth-service to v1.2.0"
git push

# 2. ArgoCD tự động sync và deploy
# (hoặc manual sync qua UI/CLI)
```

### Lợi ích
- ✅ **Single Source of Truth**: Git repository
- ✅ **Audit Trail**: Mọi thay đổi đều có commit history
- ✅ **Rollback**: Dễ dàng revert về version cũ
- ✅ **Multi-environment**: Dễ quản lý staging/production
- ✅ **UI Dashboard**: Quản lý deployments qua web UI
- ✅ **Auto-sync**: Tự động sync khi có thay đổi

---

## 📋 Phase 1: Setup ArgoCD (1 day)

### 1.1 Install ArgoCD
```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 1.2 Access ArgoCD UI
```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Access: https://localhost:8080
# Username: admin
```

### 1.3 Configure Git Repository
```bash
# Add Git repository (public hoặc với credentials)
argocd repo add https://gitlab.com/ta-microservices/k8s-manifests.git \
  --type git \
  --name k8s-manifests
```

**Tasks**:
- [ ] ArgoCD installed và running
- [ ] ArgoCD UI accessible
- [ ] Git repository configured
- [ ] Repository credentials setup (nếu private)

**See**: [ARGOCD_SETUP_GUIDE.md](./ARGOCD_SETUP_GUIDE.md) for detailed setup

---

## 📁 Phase 2: Setup Git Repository Structure (1-2 days)

### 2.1 Create Repository Structure

**Option 1: Separate Repository (Recommended)**
```
k8s-manifests/                    # New Git repository
├── README.md
├── infrastructure/
│   ├── base/
│   │   ├── postgresql/
│   │   ├── redis/
│   │   ├── consul/
│   │   ├── elasticsearch/
│   │   └── dapr/
│   └── staging/
│       └── kustomization.yaml
├── services/
│   ├── base/
│   │   ├── auth-service/
│   │   ├── user-service/
│   │   └── ... (all 19 services)
│   └── staging/
│       └── kustomization.yaml
└── applications/
    ├── infrastructure-app.yaml
    ├── support-services-app.yaml
    ├── core-services-app.yaml
    └── integration-services-app.yaml
```

**Option 2: Folder trong Repository hiện tại**
```
microservices/
├── k8s-manifests/               # New folder
│   └── ... (same structure)
└── ... (existing code)
```

### 2.2 Copy Existing Manifests

```bash
# Copy manifests từ services vào k8s-manifests repo
for service in auth user customer order payment catalog warehouse shipping fulfillment pricing promotion loyalty review notification search location gateway; do
  mkdir -p k8s-manifests/services/base/$service-service
  cp -r $service/deploy/local/* k8s-manifests/services/base/$service-service/
done

# Copy infrastructure manifests
cp -r infrastructure/* k8s-manifests/infrastructure/base/
```

### 2.3 Create Kustomize Structure

**Base manifests** (không thay đổi):
```yaml
# services/base/auth-service/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
```

**Staging overrides**:
```yaml
# services/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../base/auth-service
  - ../base/user-service
  - ../base/customer-service
  # ... all services

# Staging-specific overrides
replicas:
  - name: auth-service
    count: 1
  - name: user-service
    count: 1

images:
  - name: auth-service
    newTag: staging
  - name: user-service
    newTag: staging

# Resource limits for staging (reduced)
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: auth-service
    spec:
      template:
        spec:
          containers:
          - name: auth-service
            resources:
              requests:
                memory: "128Mi"
                cpu: "100m"
              limits:
                memory: "256Mi"
                cpu: "500m"
```

**Tasks**:
- [ ] Git repository created (hoặc folder trong repo hiện tại)
- [ ] Repository structure created
- [ ] Existing manifests copied
- [ ] Kustomize structure setup
- [ ] Staging overrides created (resource limits, replicas, image tags)

---

## 🚀 Phase 3: Create ArgoCD Applications (1 day)

### 3.1 Infrastructure Application

```yaml
# applications/infrastructure-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://gitlab.com/ta-microservices/k8s-manifests.git
    targetRevision: main
    path: infrastructure/staging
  destination:
    server: https://kubernetes.default.svc
    namespace: infrastructure
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 3.2 Support Services Application

```yaml
# applications/support-services-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: support-services
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://gitlab.com/ta-microservices/k8s-manifests.git
    targetRevision: main
    path: services/staging
    directory:
      include: 'auth-service|notification-service|search-service|location-service'
  destination:
    server: https://kubernetes.default.svc
    namespace: support-services
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 3.3 Core Services Application

```yaml
# applications/core-services-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: core-services
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://gitlab.com/ta-microservices/k8s-manifests.git
    targetRevision: main
    path: services/staging
    directory:
      exclude: 'auth-service|notification-service|search-service|location-service|gateway-service|admin-service|frontend-service'
  destination:
    server: https://kubernetes.default.svc
    namespace: core-services
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 3.4 Integration Services Application

```yaml
# applications/integration-services-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: integration-services
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://gitlab.com/ta-microservices/k8s-manifests.git
    targetRevision: main
    path: services/staging
    directory:
      include: 'gateway-service|admin-service|frontend-service'
  destination:
    server: https://kubernetes.default.svc
    namespace: integration-services
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 3.5 Apply Applications

```bash
# Apply all applications
kubectl apply -f applications/

# Or via ArgoCD CLI
argocd app create -f applications/infrastructure-app.yaml
argocd app create -f applications/support-services-app.yaml
argocd app create -f applications/core-services-app.yaml
argocd app create -f applications/integration-services-app.yaml
```

**Tasks**:
- [ ] Infrastructure application created
- [ ] Support services application created
- [ ] Core services application created
- [ ] Integration services application created
- [ ] Applications syncing successfully

---

## 🔄 Phase 4: Deployment Workflow

### 4.1 Initial Deployment

#### Step 1: Push Manifests to Git
```bash
cd k8s-manifests
git add .
git commit -m "Initial staging deployment manifests"
git push origin main
```

#### Step 2: Sync via ArgoCD UI
1. Mở ArgoCD UI: https://localhost:8080
2. Chọn application (e.g., `infrastructure`)
3. Click "Sync" → "Synchronize"
4. Wait for sync to complete

#### Step 3: Verify Deployment
```bash
# Check pods
kubectl get pods -A

# Check ArgoCD applications
argocd app list
argocd app get infrastructure
```

### 4.2 Update Deployment

#### Workflow:
1. **Update code** → Build Docker image → Push to registry
2. **Update manifest** trong Git (image tag)
3. **Commit và push** lên Git
4. **ArgoCD auto-sync** (hoặc manual sync)

#### Example:
```bash
# 1. Build và push new image
docker build -t localhost:5000/auth-service:v1.2.0 -f auth/Dockerfile auth/
docker push localhost:5000/auth-service:v1.2.0

# 2. Update manifest trong Git
cd k8s-manifests
# Edit services/base/auth-service/deployment.yaml
# Change image tag to v1.2.0

# 3. Commit và push
git add services/base/auth-service/deployment.yaml
git commit -m "Update auth-service to v1.2.0"
git push origin main

# 4. ArgoCD sẽ auto-sync (hoặc sync manually)
```

### 4.3 Rollback

#### Via ArgoCD UI:
1. Mở ArgoCD UI
2. Chọn application
3. Click "History"
4. Chọn version cũ
5. Click "Sync" → Rollback

#### Via Git:
```bash
# Revert commit
git revert <commit-hash>
git push

# ArgoCD sẽ auto-sync và rollback
```

---

## 📊 Phase 5: Deployment Order với ArgoCD

### 5.1 Initial Deployment Order

**Khác với manual deployment**, với ArgoCD:
- Tất cả applications được tạo cùng lúc
- ArgoCD sẽ sync theo thứ tự dependencies (nếu có)
- Có thể sync từng application riêng nếu cần

#### Recommended Order:
1. **Infrastructure** (đã deploy manual, nhưng có thể migrate sang ArgoCD)
2. **Support Services** (Auth, Location, Notification, Search)
3. **Core Services** (theo dependency order)
4. **Integration Services** (Gateway, Admin, Frontend)

#### Sync Strategy:
```bash
# Sync từng application theo order
argocd app sync infrastructure
argocd app wait infrastructure

argocd app sync support-services
argocd app wait support-services

argocd app sync core-services
argocd app wait core-services

argocd app sync integration-services
argocd app wait integration-services
```

### 5.2 Dependency Management

ArgoCD có thể handle dependencies qua:
- **Sync waves** (annotations)
- **Manual sync order**
- **Application dependencies** (ArgoCD Pro feature)

#### Sync Waves Example:
```yaml
# services/base/auth-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Sync first
```

```yaml
# services/base/user-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  annotations:
    argocd.argoproj.io/sync-wave: "2"  # Sync after auth
```

---

## 🔍 Phase 6: Monitoring & Verification

### 6.1 ArgoCD Dashboard

**Access**: https://localhost:8080

**Features**:
- ✅ View all applications
- ✅ Check sync status
- ✅ View resource tree
- ✅ Check health status
- ✅ View logs
- ✅ Rollback to previous version

### 6.2 Health Checks

ArgoCD tự động check:
- ✅ Pod health
- ✅ Service health
- ✅ Deployment status
- ✅ Resource availability

### 6.3 Verification Commands

```bash
# List all applications
argocd app list

# Get application details
argocd app get infrastructure

# Check sync status
argocd app sync infrastructure --dry-run

# View application resources
argocd app resources infrastructure

# Check application health
argocd app health infrastructure
```

---

## 🎯 Phase 7: CI/CD Integration

### 7.1 GitLab CI/CD Integration

**Workflow**:
1. Developer push code → GitLab CI builds image
2. GitLab CI updates manifest (image tag)
3. GitLab CI commits và pushes manifest
4. ArgoCD auto-syncs và deploys

#### Example `.gitlab-ci.yml`:
```yaml
stages:
  - build
  - deploy

build-auth-service:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE/auth-service:$CI_COMMIT_SHA -f auth/Dockerfile auth/
    - docker push $CI_REGISTRY_IMAGE/auth-service:$CI_COMMIT_SHA

update-manifest:
  stage: deploy
  script:
    - cd k8s-manifests
    - sed -i "s|image:.*auth-service.*|image: $CI_REGISTRY_IMAGE/auth-service:$CI_COMMIT_SHA|" services/base/auth-service/deployment.yaml
    - git add services/base/auth-service/deployment.yaml
    - git commit -m "Update auth-service to $CI_COMMIT_SHA"
    - git push origin main
  only:
    - main
    - develop
```

### 7.2 Manual Deployment (Alternative)

Nếu không muốn auto-sync:
1. Build image manually
2. Update manifest manually
3. Commit và push
4. Sync manually qua ArgoCD UI/CLI

---

## ✅ Checklist

### ArgoCD Setup
- [ ] ArgoCD installed
- [ ] ArgoCD UI accessible
- [ ] Git repository configured
- [ ] Repository credentials setup

### Repository Setup
- [ ] Git repository created
- [ ] Repository structure created
- [ ] Existing manifests copied
- [ ] Kustomize structure setup
- [ ] Staging overrides created

### Applications
- [ ] Infrastructure application created
- [ ] Support services application created
- [ ] Core services application created
- [ ] Integration services application created
- [ ] Applications syncing successfully

### Deployment
- [ ] Initial deployment successful
- [ ] All pods running
- [ ] Health checks passing
- [ ] End-to-end testing successful

### CI/CD (Optional)
- [ ] GitLab CI/CD configured
- [ ] Auto-deployment working
- [ ] Image tagging working

---

## 🚨 Troubleshooting

### Application không sync
```bash
# Check application status
argocd app get <app-name>

# Force refresh
argocd app get <app-name> --refresh

# Manual sync
argocd app sync <app-name>
```

### Sync failed
```bash
# Check sync logs
argocd app get <app-name> --refresh

# Check pod logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Git repository access issues
```bash
# Test repository
argocd repo get <repo-url>

# Refresh repository
argocd repo refresh <repo-url>
```

---

## 📚 Next Steps

1. **Install ArgoCD** → Follow [ARGOCD_SETUP_GUIDE.md](./ARGOCD_SETUP_GUIDE.md)
2. **Setup Git Repository** → Create repo structure
3. **Copy Manifests** → Copy existing manifests
4. **Create Applications** → Create ArgoCD applications
5. **Initial Sync** → Deploy infrastructure và services
6. **Verify** → Check all services running
7. **Setup CI/CD** → Integrate với GitLab CI/CD (optional)

---

**Last Updated**: December 2, 2025  
**Next Review**: After ArgoCD installation


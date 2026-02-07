# GitOps with ArgoCD

**Purpose**: ArgoCD-specific deployment procedures and configuration  
**Last Updated**: 2026-02-07  
**Status**: ✅ Active - Kustomize-based GitOps deployment for 24 microservices  
**Repository**: [ta-microservices/gitops](https://gitlab.com/ta-microservices/gitops)

---

## 📋 Overview

This section contains ArgoCD-specific procedures for deploying and managing applications using **Kustomize-based GitOps**. ArgoCD serves as our GitOps engine, continuously synchronizing Kubernetes resources with Git repositories.

### 🎯 What You'll Find Here
- **[ArgoCD Guide](./ARGOCD_GUIDE.md)** - Comprehensive ArgoCD setup and usage
- **[Deployment Procedures](./DEPLOYMENT.md)** - Service deployment procedures with Kustomize
- **[Templates](./)** - Kustomize templates and examples

### ⚠️ Migration Notice

**February 2026**: We migrated from ApplicationSet-based to Kustomize-based GitOps. All deployments now use Kustomize base/overlays pattern. See [GitOps Migration Guide](../../../01-architecture/gitops-migration.md) for details.

---

## 🚀 Quick Start

### **Deploy New Service (Kustomize)**
```bash
# 1. Create service structure
mkdir -p apps/new-service/base
mkdir -p apps/new-service/overlays/dev

# 2. Create base manifests
cat > apps/new-service/base/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: new-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: new-service
  template:
    metadata:
      labels:
        app: new-service
    spec:
      containers:
      - name: new-service
        image: new-service:latest
        ports:
        - containerPort: 8000
EOF

# 3. Create kustomization
cat > apps/new-service/base/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
EOF

# 4. Create dev overlay
cat > apps/new-service/overlays/dev/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patch-deployment.yaml
EOF

# 5. Commit and push
git add apps/new-service/
git commit -m "Add new-service"
git push origin main

# 6. Monitor deployment
argocd app get new-service
```

### **Update Service**
```bash
# 1. Update image tag in overlay
cat > apps/new-service/overlays/dev/patch-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: new-service
spec:
  template:
    spec:
      containers:
      - name: new-service
        image: new-service:v1.2.3
EOF

# 2. Commit changes
git add apps/new-service/overlays/dev/patch-deployment.yaml
git commit -m "Update new-service to v1.2.3"

# 3. Push to Git
git push origin main

# 4. ArgoCD will auto-sync
argocd app get new-service
```

---

## 📊 Current Status

| Metric | Count | Status |
|--------|-------|--------|
| **Total Services** | 24 | ✅ Active |
| **Deployed (dev)** | 24 | ✅ 100% |
| **Deployed (prod)** | 20 | ✅ 83% |
| **Kustomize Apps** | 24 | ✅ 100% |
| **Sync Waves** | 5 | ✅ Configured |

### Deployment Time
- **Full Platform**: 35-45 minutes
- **Single Service**: 2-5 minutes
- **Rollback**: < 2 minutes

---

## � Common Commands

### **Application Management**
```bash
# List all applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# Rollback application
argocd app rollback <app-name> <revision-id>

# Delete application
argocd app delete <app-name>
```

### **Troubleshooting**
```bash
# Check application events
argocd app events <app-name>

# Check application logs
argocd app logs <app-name>

# Force refresh application
argocd app get <app-name> --refresh
```

---

## � Support

- **Documentation**: See [ArgoCD Guide](./ARGOCD_GUIDE.md)
- **Issues**: GitLab Issues with `argocd` label
- **Help**: #ops-gitops channel

# GitOps with ArgoCD

**Purpose**: ArgoCD-specific deployment procedures and configuration  
**Last Updated**: 2026-02-03  
**Status**: ✅ Active - GitOps deployment for 19 microservices

---

## 📋 Overview

This section contains ArgoCD-specific procedures for deploying and managing applications using GitOps. ArgoCD serves as our GitOps engine, continuously synchronizing Kubernetes resources with Git repositories.

### 🎯 What You'll Find Here
- **[ArgoCD Guide](./ARGOCD_GUIDE.md)** - Comprehensive ArgoCD setup and usage
- **[Deployment Procedures](./DEPLOYMENT.md)** - Service deployment procedures
- **[Templates](./)** - Deployment templates and examples

---

## 🚀 Quick Start

### **Deploy New Service**
```bash
# 1. Create application manifest
kubectl apply -f apps/new-service/application.yaml

# 2. Monitor deployment
argocd app get new-service

# 3. Sync if needed
argocd app sync new-service
```

### **Update Service**
```bash
# 1. Update configuration
vim apps/new-service/values.yaml

# 2. Commit changes
git add apps/new-service/values.yaml
git commit -m "Update new-service configuration"

# 3. Push to Git
git push origin main

# 4. ArgoCD will auto-sync
argocd app get new-service
```

---

## 📊 Current Status

| Metric | Count | Status |
|--------|-------|--------|
| **Total Services** | 19 | ✅ Active |
| **Deployed (dev)** | 14 | ✅ 74% |
| **Ready to Deploy** | 5 | ⏳ 26% |
| **Helm Charts** | 19 | ✅ 100% |

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

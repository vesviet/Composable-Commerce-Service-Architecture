# 🚀 Legacy ArgoCD Setup Guide - Historical Bootstrap Notes

- **Created**: December 2, 2025
- **Purpose**: Set up ArgoCD for GitOps deployment of 19 microservices

---

> [!WARNING]
> This document is a historical reference for installing the ArgoCD control plane and the legacy onboarding model. Sections that discuss `ApplicationSet` and service rollout do not reflect the current GitOps workflow.
>
> For the current workflow, use:
> - [../../../../gitops/README.md](../../../../gitops/README.md)
> - [GitOps review checklist](../../../10-appendix/checklists/gitops/review_checklist.md)

## 📋 Overview

### Why ArgoCD?
- ✅ **GitOps**: Deploy from a Git repository (single source of truth)
- ✅ **Auto-sync**: Automatically sync when Git changes
- ✅ **UI Dashboard**: Manage deployments through the web UI
- ✅ **Rollback**: Easily roll back to a previous version
- ✅ **Health Checks**: Automatically check application health
- ✅ **Multi-environment**: Manage staging and production more easily

### Architecture
```
Git Repository (GitLab/GitHub)
    ↓ (push manifests)
ArgoCD (watches Git)
    ↓ (applies manifests)
Kubernetes Cluster
    ↓ (deploys)
Microservices
```

---

## 🔧 Phase 1: Install ArgoCD

### 1.1 Install ArgoCD into the Cluster

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n argocd
```

### 1.2 Verify Installation

```bash
# Check pods
kubectl get pods -n argocd

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0                     1/1     Running   0          2m
# argocd-applicationset-controller-7d9b8b8c8d-xxx     1/1     Running   0          2m
# argocd-dex-server-xxx                                1/1     Running   0          2m
# argocd-notifications-controller-xxx                  1/1     Running   0          2m
# argocd-redis-xxx                                    1/1     Running   0          2m
# argocd-repo-server-xxx                              1/1     Running   0          2m
# argocd-server-xxx                                   1/1     Running   0          2m
```

### 1.3 Access ArgoCD UI

#### Option 1: Port Forward (Development)
```bash
# Port forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI: https://localhost:8080
# Username: admin
# Password: (get from below)
```

#### Option 2: NodePort (Staging/Production)
```bash
# Patch service to NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get port
kubectl get svc argocd-server -n argocd

# Access: https://<node-ip>:<nodeport>
```

#### Get Admin Password
```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Or use argocd CLI
argocd admin initial-password -n argocd
```

### 1.4 Install ArgoCD CLI (Optional but Recommended)

```bash
# Install ArgoCD CLI
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Verify
argocd version --client
```

---

## 🔧 Phase 2: Configure ArgoCD

### 2.1 Login to ArgoCD

```bash
# Login via CLI
argocd login localhost:8080 --insecure --username admin --password <password>

# Or via UI: https://localhost:8080
```

### 2.2 Configure Git Repository

ArgoCD needs access to the Git repository to sync manifests.

#### Option 1: Public Repository (No Auth)
```bash
# Add repository via CLI
argocd repo add https://gitlab.com/ta-microservices/k8s-manifests.git \
  --type git \
  --name k8s-manifests

# Or via UI: Settings → Repositories → Connect Repo
```

#### Option 2: Private Repository (SSH)
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd -N ""

# Add public key to GitLab/GitHub (Deploy Keys)
cat ~/.ssh/argocd.pub

# Create secret for SSH key
kubectl create secret generic argocd-repo-credentials \
  --from-file=sshPrivateKey=~/.ssh/argocd \
  -n argocd

# Add repository with SSH
argocd repo add git@gitlab.com:ta-microservices/k8s-manifests.git \
  --type git \
  --ssh-private-key-path ~/.ssh/argocd \
  --name k8s-manifests
```

#### Option 3: Private Repository (HTTPS with Token)
```bash
# Create secret for Git credentials
kubectl create secret generic argocd-repo-credentials \
  --from-literal=username=<git-username> \
  --from-literal=password=<git-token> \
  -n argocd

# Add repository
argocd repo add https://gitlab.com/ta-microservices/k8s-manifests.git \
  --type git \
  --name k8s-manifests \
  --username <git-username> \
  --password <git-token>
```

### 2.3 Configure Image Registry (Optional)

If you use a private Docker registry:

```bash
# Create secret for Docker registry
kubectl create secret docker-registry argocd-image-pull-secret \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n argocd
```

---

## 📁 Phase 3: GitOps Repository Structure

### 3.1 Recommended Structure

Create a dedicated Git repository for Kubernetes manifests (or a folder inside the current repository):

```
k8s-manifests/                    # Git repository
├── README.md
├── .argocd/                      # ArgoCD configuration
│   └── argocd-app.yaml          # Root application
├── infrastructure/               # Infrastructure services
│   ├── base/
│   │   ├── postgresql/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   ├── redis/
│   │   ├── consul/
│   │   ├── elasticsearch/
│   │   └── dapr/
│   ├── staging/
│   │   └── kustomization.yaml    # Staging overrides
│   └── production/
│       └── kustomization.yaml    # Production overrides
├── services/                     # Microservices
│   ├── base/
│   │   ├── auth-service/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   └── kustomization.yaml
│   │   ├── user-service/
│   │   ├── customer-service/
│   │   └── ... (all 19 services)
│   ├── staging/
│   │   └── kustomization.yaml    # Staging overrides
│   └── production/
│       └── kustomization.yaml    # Production overrides
└── applications/                 # ArgoCD Applications
    ├── infrastructure-app.yaml
    ├── support-services-app.yaml
    ├── core-services-app.yaml
    └── integration-services-app.yaml
```

### 3.2 Kustomize Structure (Recommended)

Use Kustomize to manage multiple environments:

```
services/base/auth-service/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
└── kustomization.yaml

services/staging/
└── kustomization.yaml
    resources:
      - ../base/auth-service
    replicas:
      - name: auth-service
        count: 1
    images:
      - name: auth-service
        newTag: staging

services/production/
└── kustomization.yaml
    resources:
      - ../base/auth-service
    replicas:
      - name: auth-service
        count: 2
    images:
      - name: auth-service
        newTag: latest
```

---

## 🚀 Phase 4: Create ArgoCD Applications

### 4.1 Application Types

#### Option 1: Individual Applications (Recommended for Staging)
Each service is a separate ArgoCD Application -> easier to manage and debug

#### Option 2: ApplicationSet (Legacy Reference)
Use ApplicationSet to automatically create applications for all services under the old model. Do not use this section as the standard for current GitOps app onboarding.

### 4.2 Create Infrastructure Application

```yaml
# applications/infrastructure-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
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

Apply:
```bash
kubectl apply -f applications/infrastructure-app.yaml
```

### 4.3 Create Support Services Application

```yaml
# applications/support-services-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: support-services
  namespace: argocd
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

### 4.4 Create Core Services Application

```yaml
# applications/core-services-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: core-services
  namespace: argocd
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

### 4.5 Create Integration Services Application

```yaml
# applications/integration-services-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: integration-services
  namespace: argocd
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

### 4.6 Create Individual Service Applications (Alternative)

If you want to manage each service separately:

```yaml
# applications/auth-service-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: auth-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitlab.com/ta-microservices/k8s-manifests.git
    targetRevision: main
    path: services/staging/auth-service
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

---

## 🔄 Phase 5: Sync Strategy

### 5.1 Sync Policies

#### Automated Sync (Recommended for Staging)
```yaml
syncPolicy:
  automated:
    prune: true          # Auto-delete resources removed from Git
    selfHeal: true       # Auto-sync if cluster state differs from Git
    allowEmpty: false    # Don't allow empty applications
```

#### Manual Sync (Recommended for Production)
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
  # No automated sync - require manual approval
```

### 5.2 Sync Windows

Restrict sync windows (for example, sync only during business hours):

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncWindows:
    - kind: allow
      schedule: '0 9 * * 1-5'  # 9 AM, Mon-Fri
      duration: 8h
      applications:
        - '*'
    - kind: deny
      schedule: '* * * * *'
      duration: 0
```

---

## 🎯 Phase 6: Deployment Workflow

### 6.1 Development Workflow

1. **Developer** changes code -> pushes to Git
2. **CI/CD Pipeline** (GitLab CI):
   - Build Docker image
   - Push the image to the registry
   - Update the image tag in the Kubernetes manifests
   - Commit and push manifests to Git
3. **ArgoCD** detects changes in Git
4. **ArgoCD** automatically syncs -> deploys the new version

### 6.2 Manual Sync Workflow

1. **Developer** changes code -> pushes to Git
2. **CI/CD Pipeline** builds and pushes the image
3. **Update manifests** in Git (manually or via CI/CD)
4. **ArgoCD** detects changes
5. **Admin** reviews the change in the ArgoCD UI
6. **Admin** click "Sync" → Deploy

### 6.3 Rollback Workflow

#### Via ArgoCD UI:
1. Open the ArgoCD UI
2. Select the application
3. Click "History"
4. Select the previous version
5. Click "Sync" → Rollback

#### Via CLI:
```bash
# List history
argocd app history auth-service

# Rollback to specific revision
argocd app rollback auth-service <revision>
```

#### Via Git:
```bash
# Revert commit in Git
git revert <commit-hash>
git push

# ArgoCD will auto-sync and roll back
```

---

## 🔍 Phase 7: Monitoring & Health Checks

### 7.1 Health Checks

ArgoCD automatically checks application health:

- **Healthy**: All resources are healthy
- **Progressing**: Deployment in progress
- **Degraded**: Some resources are unhealthy
- **Suspended**: Application is suspended
- **Unknown**: Health status unknown

### 7.2 Custom Health Checks

Create custom health checks for services:

```yaml
# argocd-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        hs.message = obj.status.health.message
      end
    end
    return hs
```

### 7.3 Notifications

Set up notifications for ArgoCD (Slack, email, etc.):

```yaml
# argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
    username: ArgoCD
    channel: deployments
```

---

## 📋 Phase 8: Best Practices

### 8.1 Repository Structure
- ✅ **Separate repo** for Kubernetes manifests (or a separate folder)
- ✅ **Use Kustomize** for multiple environments
- ✅ **Version control** all manifests
- ✅ **Review process** for production changes

### 8.2 Application Organization
- ✅ **Group by namespace**: Infrastructure, Support, Core, Integration
- ✅ **Use ApplicationSet** for production under the legacy model (auto-create apps)
- ✅ **Individual apps** for staging (easier to debug)

### 8.3 Sync Strategy
- ✅ **Automated sync** for staging
- ✅ **Manual sync** for production (with approval)
- ✅ **Sync windows** to avoid after-hours deployments

### 8.4 Security
- ✅ **RBAC** for ArgoCD users
- ✅ **Secrets management** (Vault, Sealed Secrets)
- ✅ **Image scanning** in CI/CD
- ✅ **Git branch protection** for production

---

## 🚨 Troubleshooting

### ArgoCD Does Not Sync
```bash
# Check application status
argocd app get <app-name>

# Check sync status
argocd app sync <app-name> --dry-run

# Force sync
argocd app sync <app-name>
```

### Application stuck in Progressing
```bash
# Check pod status
kubectl get pods -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check application logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Git repository access issues
```bash
# Test repository access
argocd repo get <repo-url>

# Refresh repository
argocd repo refresh <repo-url>
```

---

## ✅ Checklist

### Installation
- [ ] ArgoCD installed and running
- [ ] ArgoCD UI accessible
- [ ] Admin password retrieved
- [ ] ArgoCD CLI installed (optional)

### Configuration
- [ ] Git repository configured
- [ ] Repository credentials set up (if private)
- [ ] Image registry configured (if private)

### Repository Setup
- [ ] Git repository structure created
- [ ] K8s manifests organized
- [ ] Kustomize structure setup
- [ ] Base manifests created

### Applications
- [ ] Infrastructure application created
- [ ] Support services application created
- [ ] Core services application created
- [ ] Integration services application created
- [ ] Applications syncing successfully

### Testing
- [ ] Test sync from Git
- [ ] Test rollback
- [ ] Test health checks
- [ ] Test notifications (if applicable)

---

## 📚 Next Steps

1. **Set Up the Git Repository**: Create a repo for Kubernetes manifests
2. **Organize Manifests**: Copy manifests into the repo structure
3. **Create Applications**: Create ArgoCD applications
4. **Test Sync**: Test sync from Git
5. **Set Up CI/CD**: Integrate with GitLab CI/CD
6. **Monitor**: Set up monitoring and alerts

---

**Last Updated**: December 2, 2025  
**Next Review**: After ArgoCD installation


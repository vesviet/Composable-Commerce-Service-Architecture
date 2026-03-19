# 🚀 GitOps Documentation

- **Purpose**: Kustomize-based GitOps strategy and implementation notes
- **Last Updated**: 2026-02-07
- **Status**: Reference guide; confirm current operational state in the live `gitops/` repository
- **Repository**: [ta-microservices/gitops](https://gitlab.com/ta-microservices/gitops)

---

> [!IMPORTANT]
> This folder is a documentation overview, not the operational source of truth. For current manifests, environment status, bootstrap caveats, and active issues, use:
> - [../../../../gitops/README.md](../../../../gitops/README.md)
> - [GitOps review checklist](../../../10-appendix/checklists/gitops/review_checklist.md)

## 📋 Overview

This section contains comprehensive documentation for our **Kustomize-based GitOps implementation** using ArgoCD. GitOps is our core deployment strategy that provides automated, reliable, and auditable deployments for all 24 microservices.

### 🎯 What You'll Find Here

- **[GitOps Overview](./GITOPS_OVERVIEW.md)** - Complete Kustomize-based GitOps strategy
- **[Repository Structure](./REPOSITORY_STRUCTURE.md)** - GitOps repository organization
- **[Deployment Patterns](./DEPLOYMENT_PATTERNS.md)** - Kustomize deployment strategies
- **[Best Practices](./BEST_PRACTICES.md)** - Kustomize and GitOps best practices
- **[Troubleshooting](./TROUBLESHOOTING.md)** - Common issues and solutions

### ⚠️ Migration Notice

**February 2026**: We migrated from ApplicationSet-based to Kustomize-based GitOps for:
- ✅ Better environment management with overlays
- ✅ Improved consistency and standardization
- ✅ Enhanced scalability and maintainability
- ✅ Simplified configuration management

See [GitOps Migration Guide](../../../01-architecture/gitops-migration.md) for complete details.

---

## 🏗️ GitOps Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Repository │    │     ArgoCD      │    │  Kubernetes     │
│                 │    │                 │    │    Cluster      │
│ • Kustomize     │───▶│ • GitOps Engine │───▶│ • Applications  │
│ • Base Manifests│    │ • Sync Engine   │    │ • Infrastructure│
│ • Overlays      │    │ • Health Checks │    │ • Services      │
│ • Components    │    │ • Rollback      │    │ • Monitoring    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Implementation Stack

- **GitOps Engine**: ArgoCD 2.8+
- **Configuration Management**: Kustomize (native K8s)
- **Container Orchestration**: Kubernetes 1.29+
- **CI/CD**: GitLab CI/CD
- **Monitoring**: Prometheus + Grafana
- **Logging**: Loki + Promtail

### Repository Structure

```
gitops/
├── bootstrap/                 # Root applications
│   └── root-app-dev.yaml
├── environments/              # Environment-specific configurations
│   ├── dev/
│   │   ├── apps/             # Dev applications
│   │   ├── projects/         # ArgoCD projects
│   │   └── resources/        # Dev-specific resources
│   └── production/
│       ├── apps/             # Production applications
│       ├── projects/         # ArgoCD projects
│       └── resources/        # Prod-specific resources
├── apps/                     # Application configurations (24 services)
│   ├── {service}/
│   │   ├── base/             # Base manifests
│   │   └── overlays/         # Environment overlays
│   │       ├── dev/
│   │       └── production/
├── infrastructure/            # Infrastructure components
│   ├── databases/
│   ├── monitoring/
│   └── security/
├── components/               # Reusable components
│   ├── common-infrastructure-envvars/
│   ├── imagepullsecret/
│   └── infrastructure-egress/
└── clusters/                 # Cluster-specific configs
    ├── dev/
    └── production/
```

---

## 📚 Documentation Structure

### 🚀 Getting Started
- **[GitOps Overview](./GITOPS_OVERVIEW.md)** - Start here for complete understanding
- **[Quick Start Guide](./QUICK_START.md)** - Get Kustomize-based GitOps running
- **[Installation Guide](./INSTALLATION.md)** - Detailed setup instructions
- **[Migration Guide](../../../01-architecture/gitops-migration.md)** - ApplicationSet to Kustomize

### 🏗️ Architecture & Design
- **[Architecture Overview](./GITOPS_OVERVIEW.md#architecture)** - System design
- **[Repository Structure](./REPOSITORY_STRUCTURE.md)** - Kustomize organization
- **[Deployment Patterns](./DEPLOYMENT_PATTERNS.md)** - Kustomize deployment strategies
- **[Sync Waves](./SYNC_WAVES.md)** - Ordered deployment with dependencies

### 🔧 Implementation
- **[Kustomize Guide](./KUSTOMIZE_GUIDE.md)** - Complete Kustomize usage
- **[Base + Overlays](./BASE_OVERLAYS.md)** - Environment management
- **[Components](./COMPONENTS.md)** - Reusable configuration
- **[Configuration Management](./CONFIGURATION.md)** - Config and secrets
- **[Monitoring & Observability](./MONITORING.md)** - Track deployments

### 🔒 Security & Compliance
- **[GitOps Security](./GITOPS_SECURITY.md)** - Security best practices
- **[Access Control](./ACCESS_CONTROL.md)** - RBAC and permissions
- **[Audit & Compliance](./AUDIT_COMPLIANCE.md)** - Compliance requirements

### 🛠️ Operations
- **[Troubleshooting](./TROUBLESHOOTING.md)** - Common issues and fixes
- **[Debugging Guide](./DEBUGGING.md)** - Advanced debugging
- **[Recovery Procedures](./RECOVERY.md)** - Disaster recovery
- **[Maintenance](./MAINTENANCE.md)** - Regular maintenance tasks

---

## 🎯 Key Benefits

### ✅ Operational Excellence
- **Automated Deployments**: Zero-touch deployment pipeline
- **Consistency**: Same deployment process across environments
- **Reliability**: Automated rollback and recovery
- **Audit Trail**: Complete Git history of all changes

### ✅ Developer Productivity
- **Self-Service**: Teams can deploy their services
- **Fast Feedback**: Quick deployment cycles
- **Reduced Friction**: No manual deployment steps
- **Transparency**: Clear visibility into deployment status

### ✅ Business Value
- **Faster Time to Market**: Quick feature delivery
- **Reduced Risk**: Safer, tested deployments
- **Better Reliability**: Consistent environments
- **Cost Efficiency**: Automated operations

---

## 📊 Current Status

### ✅ Implemented Features
- [x] ArgoCD GitOps engine
- [x] Kustomize-based configuration management
- [x] Base + Overlays pattern for environments
- [x] Reusable components
- [x] Multi-environment support (dev/production)
- [x] Automated deployments with sync waves
- [x] Health checks and monitoring
- [x] Rollback capabilities via Git revert
- [x] 24 microservices deployed

### 🔄 In Progress
- [ ] Progressive delivery patterns
- [ ] Advanced security features
- [ ] Multi-cluster support
- [ ] Enhanced monitoring

### ⏳ Planned Features
- [ ] Automated testing integration
- [ ] Canary deployments
- [ ] Blue-green deployments
- [ ] Disaster recovery automation

---

## 🚀 Quick Start

### 1. Prerequisites
```bash
# Required tools
kubectl 1.25+
helm 3.0+
git 2.30+
```

### 2. Install ArgoCD
```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 3. Configure GitOps Repository
```bash
# Clone Kustomize-based GitOps repository
git clone https://gitlab.com/ta-microservices/gitops.git
cd gitops

# Add your application
mkdir -p apps/my-service/base
mkdir -p apps/my-service/overlays/dev

# Create base manifests
cat > apps/my-service/base/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-service
  template:
    metadata:
      labels:
        app: my-service
    spec:
      containers:
      - name: my-service
        image: my-service:latest
        ports:
        - containerPort: 8000
EOF

# Create kustomization
cat > apps/my-service/base/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
EOF
```

### 4. Deploy First Application
```bash
# Create dev overlay
cat > apps/my-service/overlays/dev/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patch-deployment.yaml
EOF

# Commit and push
git add apps/my-service/
git commit -m "Add my-service"
git push origin main

# ArgoCD will auto-sync
argocd app get my-service
```

---

## 📚 Related Documentation

### Core Platform
- [ArgoCD Documentation](../argocd/README.md) - ArgoCD-specific guides
- [Kubernetes Deployment](../kubernetes/README.md) - K8s deployment patterns
- [CI/CD Pipeline](../../development/cicd/README.md) - Build and test pipeline

### Platform Engineering
- [Platform Standards](../../development/standards/README.md) - Engineering standards
- [Monitoring Guide](../../monitoring/README.md) - Observability setup
- [Security Guidelines](../../security/README.md) - Security practices

---

## 🤝 Getting Help

### Documentation
- **Start Here**: [GitOps Overview](./GITOPS_OVERVIEW.md)
- **Quick Issues**: [Troubleshooting](./TROUBLESHOOTING.md)
- **Deep Dive**: [Architecture](./GITOPS_OVERVIEW.md#architecture)

### Support Channels
- **Issues**: GitLab Issues with `gitops` label
- **Discussions**: GitLab Discussions for questions
- **Alerts**: #gitops-alerts for production issues
- **Architecture**: #platform-architecture for design decisions

---

## 🔄 Maintenance

### Regular Tasks
- **Weekly**: Review deployment status and health
- **Monthly**: Update documentation and check for updates
- **Quarterly**: Architecture review and security audit

### Review Process
- **Code Changes**: Update docs when GitOps patterns change
- **Security Reviews**: Update security documentation
- **Architecture Updates**: Document new patterns and decisions

---

**Last Updated**: 2026-02-07  
**Review Cycle**: Monthly  
**Maintained By**: Platform Engineering Team  
**GitOps Repository**: [ta-microservices/gitops](https://gitlab.com/ta-microservices/gitops)

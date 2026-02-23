# 🚀 Deployment Documentation

**Purpose**: Complete deployment strategy and procedures for the microservices platform  
**Last Updated**: 2026-02-07  
**Status**: ✅ Active - Kustomize-based GitOps deployment with ArgoCD  
**GitOps Repository**: [ta-microservices/gitops](https://gitlab.com/ta-microservices/gitops)

---

## 📋 Overview

This section contains comprehensive documentation for deploying and managing the microservices platform. We use **Kustomize-based GitOps with ArgoCD** as our primary deployment strategy, ensuring reliable, automated, and auditable deployments.

### 🎯 What You'll Find Here

- **[GitOps Overview](./gitops/)** - Complete Kustomize-based GitOps strategy
- **[ArgoCD Procedures](./argocd/)** - ArgoCD-specific deployment procedures
- **[Kubernetes Operations](./kubernetes/)** - K8s cluster management and operations
- **[Deployment Guides](./guides/)** - Step-by-step deployment procedures

### ⚠️ Migration Notice

**February 2026**: We migrated from ApplicationSet-based to Kustomize-based GitOps for better environment management and consistency. See [GitOps Migration Guide](../../01-architecture/gitops-migration.md) for complete details.

---

## 🚀 Deployment Strategy

### **Kustomize-based GitOps Approach**

```mermaid
graph LR
    A[Git Repository] --> B[ArgoCD]
    B --> C[Kustomize Build]
    C --> D[Kubernetes Cluster]
    D --> E[Applications Deployed]
    
    F[Developer Push] --> A
    G[Automated Testing] --> A
    H[Security Scans] --> A
    
    A --> I[CI/CD Pipeline]
    I --> J[Docker Registry]
    J --> D
```

### **Key Principles**
- **Declarative Configuration**: All infrastructure defined in Kustomize manifests
- **Version Control**: Git as single source of truth
- **Automated Deployment**: Zero-touch deployment pipeline
- **Rollback Capability**: Instant rollback via Git revert
- **Environment Parity**: Consistent environments with overlays

### **Technology Stack**
- **GitOps Engine**: ArgoCD 2.8+
- **Configuration Management**: Kustomize (native K8s)
- **Container Orchestration**: Kubernetes 1.29+
- **CI/CD**: GitLab CI/CD
- **Monitoring**: Prometheus + Grafana
- **Logging**: Loki + Promtail

---

## 📊 Deployment Architecture

### **Environment Strategy**

| Environment | Purpose | Git Branch | ArgoCD App | Auto-Sync |
|-------------|---------|------------|------------|-----------|
| **Development** | Feature development | `develop` | `dev-apps` | ✅ Yes |
| **Staging** | Pre-production testing | `main` | `staging-apps` | ⏳ Manual |
| **Production** | Live production | `main` | `prod-apps` | ⏳ Manual |

### **Deployment Pipeline**

```yaml
# Kustomize-based GitOps Pipeline
stages:
  - name: "Code Commit"
    trigger: "Git Push"
    
  - name: "CI Pipeline"
    actions:
      - "Unit Tests"
      - "Integration Tests"
      - "Security Scan"
      - "Docker Build"
      
  - name: "Image Registry"
    actions:
      - "Push Image"
      - "Vulnerability Scan"
      
  - name: "GitOps Update"
    actions:
      - "Update Image Tag in Kustomize"
      - "Commit to GitOps Repo"
      
  - name: "ArgoCD Deploy"
    actions:
      - "Detect Changes"
      - "Kustomize Build"
      - "Deploy to K8s"
      - "Health Check"
```

### **Repository Structure**

```yaml
# GitOps Repository (Kustomize-based)
gitops/
├── bootstrap/                 # Root applications
│   └── root-app-dev.yaml
├── environments/              # Environment-specific configs
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
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
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

## 🔧 Quick Start

### **1. Prerequisites**
```bash
# Required tools
kubectl 1.25+
helm 3.0+
git 2.30+
docker 20.10+
argocd CLI
```

### **2. Setup GitOps Repository**
```bash
# Clone GitOps repository (Kustomize-based)
git clone https://gitlab.com/ta-microservices/gitops.git
cd gitops

# Configure ArgoCD
kubectl apply -f bootstrap/root-app-dev.yaml
```

### **3. Deploy First Application**
```bash
# Application structure (Kustomize)
mkdir -p apps/order-service/base
mkdir -p apps/order-service/overlays/dev

# Create base manifests
cat > apps/order-service/base/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: order-service:latest
        ports:
        - containerPort: 8000
EOF

# Create kustomization
cat > apps/order-service/base/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
EOF

# Create dev overlay
cat > apps/order-service/overlays/dev/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patch-deployment.yaml
EOF

# Commit and push
git add apps/order-service/
git commit -m "Add order-service"
git push origin main

# ArgoCD will auto-sync
argocd app get order-service
```

---

## 📚 Documentation Structure

### **🚀 GitOps Strategy**
- **[GitOps Overview](./gitops/)** - Complete Kustomize-based GitOps strategy
- **Multi-Environment Setup** - Dev/Staging/Production with overlays
- **Progressive Delivery** - Canary and blue-green deployments
- **Best Practices** - Kustomize patterns and procedures
- **Migration Guide** - ApplicationSet to Kustomize migration

### **🔧 ArgoCD Operations**
- **[ArgoCD Guide](./argocd/ARGOCD_GUIDE.md)** - Comprehensive ArgoCD guide
- **Application Management** - Service deployment procedures
- **Configuration** - ArgoCD setup and configuration
- **Troubleshooting** - Common ArgoCD issues
- **Sync Waves** - Ordered deployment strategies

### **☸️ Kubernetes Operations**
- **[Kubernetes Setup](./kubernetes/INSTALLATION.md)** - Cluster setup
- **Cluster Management** - Node and resource management
- **Networking** - Service mesh and networking
- **Security** - RBAC and security policies

### **📋 Deployment Guides**
- **[Implementation Checklist](./guides/IMPLEMENTATION_CHECKLIST.md)** - Deployment checklist
- **Service Configuration** - Service setup procedures
- **Migration Guides** - System migration procedures
- **Best Practices** - Deployment best practices

---

## 🎯 Common Deployment Tasks

### **Deploy New Service**
```bash
# 1. Create service directory
mkdir -p apps/new-service

# 2. Add application manifest
cp templates/application.yaml apps/new-service/

# 3. Configure values
cp templates/values.yaml apps/new-service/

# 4. Deploy
kubectl apply -f apps/new-service/

# 5. Monitor deployment
argocd app get new-service
```

### **Update Service**
```bash
# 1. Update image tag
sed -i 's|image: .*|image: new-service:v1.2.3|' apps/new-service/values.yaml

# 2. Commit changes
git add apps/new-service/values.yaml
git commit -m "Update new-service to v1.2.3"

# 3. Push to Git
git push origin main

# 4. Monitor deployment
argocd app sync new-service
```

### **Rollback Deployment**
```bash
# 1. Check deployment history
argocd app history new-service

# 2. Rollback to previous version
argocd app rollback new-service <revision-id>

# 3. Verify rollback
argocd app get new-service
```

---

## 📊 Deployment Metrics

### **Key Performance Indicators**

#### **Deployment Metrics**
- **Deployment Frequency**: Number of deployments per day
- **Lead Time**: Time from commit to production
- **Change Failure Rate**: Percentage of failed deployments
- **Mean Time to Recovery**: Time to recover from failures

#### **Quality Metrics**
- **Test Coverage**: Percentage of code covered by tests
- **Security Score**: Vulnerability scan results
- **Performance**: Application performance benchmarks
- **Compliance**: Regulatory compliance status

### **Monitoring Dashboard**

```yaml
# Grafana Dashboard Metrics
deployment_metrics:
  - deployment_frequency
  - lead_time_for_changes
  - change_failure_rate
  - mean_time_to_recovery
  - test_coverage
  - security_scan_results
```

---

## 🚨 Troubleshooting

### **Common Issues**

#### **Deployment Failures**
```bash
# Check ArgoCD status
argocd app get <app-name>

# Check application logs
kubectl logs -f deployment/<app-name> -n production

# Check ArgoCD events
argocd app events <app-name>

# Sync application manually
argocd app sync <app-name>
```

#### **Image Pull Issues**
```bash
# Check image availability
docker pull <image-name>:<tag>

# Check registry credentials
kubectl get secret registry-credentials -n production

# Test image pull
kubectl run test-pod --image=<image-name>:<tag> --dry-run=client
```

#### **Resource Issues**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n production

# Check resource limits
kubectl describe pod <pod-name> -n production

# Check cluster capacity
kubectl describe nodes
```

---

## 🔒 Security Considerations

### **Deployment Security**
- **Image Scanning**: All images scanned for vulnerabilities
- **RBAC**: Role-based access control for deployments
- **Network Policies**: Traffic restrictions between services
- **Secrets Management**: Encrypted secrets with rotation

### **GitOps Security**
- **Branch Protection**: Protected branches for production
- **Code Reviews**: Required pull requests for changes
- **Audit Trail**: Complete audit trail of all changes
- **Compliance**: Regulatory compliance tracking

---

## 📞 Support & Contacts

### **Deployment Team**
- **DevOps Team**: devops@company.com
- **Platform Engineering**: platform@company.com
- **Security Team**: security@company.com

### **Communication Channels**
- **Deployments**: #ops-deployments
- **GitOps Issues**: #ops-gitops
- **Infrastructure**: #ops-infrastructure
- **Security**: #security-incidents

---

## 🔄 Maintenance

### **Regular Tasks**
- **Daily**: Monitor deployment status and health
- **Weekly**: Review deployment metrics and performance
- **Monthly**: Update documentation and procedures
- **Quarterly**: Security audits and compliance reviews

### **Documentation Updates**
- Update procedures when deployment process changes
- Document lessons learned from incidents
- Add new deployment patterns and best practices
- Review and update security procedures

---

## 📚 Related Documentation

### **Platform Documentation**
- [Operations Overview](../README.md) - Overall operations
- [Monitoring](../monitoring/) - Observability and alerting
- [Security](../security/) - Security operations
- [Runbooks](../runbooks/) - Operational procedures

### **Development Documentation**
- [Development Guidelines](../../07-development/) - Development standards
- [Architecture](../../01-architecture/) - System architecture
- [Services](../../03-services/) - Individual service documentation

---

**Last Updated**: 2026-02-07  
**Review Cycle**: Monthly deployment review  
**Maintained By**: DevOps & Platform Engineering Teams  
**GitOps Repository**: [ta-microservices/gitops](https://gitlab.com/ta-microservices/gitops)

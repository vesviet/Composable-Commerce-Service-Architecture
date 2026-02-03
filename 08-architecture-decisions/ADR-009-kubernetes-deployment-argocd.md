# ADR-009: Kubernetes Deployment Strategy (ArgoCD + K3d)

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Platform Team, SRE Team, Architecture Team

## Context

With 21+ microservices to deploy across multiple environments, we need:
- GitOps-based deployment for consistency and reliability
- Local development environment that mirrors production
- Multi-environment support (local, dev, staging, production)
- Automated deployment rollbacks
- Proper resource management and monitoring
- Integration with our existing GitLab CI/CD pipelines

We evaluated several deployment strategies:
- **ArgoCD + K3d**: GitOps with local Kubernetes cluster
- **Helm + Manual kubectl**: Template-based deployments
- **Docker Compose**: Simple container orchestration
- **Kubernetes Native**: Direct kubectl deployments

## Decision

We will use **ArgoCD for GitOps deployments** with **K3d for local development**.

### Architecture Components:
1. **ArgoCD**: GitOps operator for automated deployments
2. **K3d**: Lightweight Kubernetes for local development
3. **GitOps Repository**: `gitops/` directory with Kubernetes manifests
4. **Application Sets**: ArgoCD application sets for service management
5. **Environment Promotion**: Automated promotion through environments

### Deployment Flow:
```
GitLab CI → Build Docker Image → Update GitOps → ArgoCD Deploys → K8s Cluster
```

### Environment Strategy:
- **Local**: K3d cluster with Tilt for hot reload
- **Development**: Shared Kubernetes cluster with ArgoCD
- **Staging**: Production-like cluster with full monitoring
- **Production**: Production cluster with high availability

### GitOps Structure:
```
gitops/
├── apps/
│   ├── auth/
│   ├── order/
│   └── ... (one per service)
├── infrastructure/
│   ├── postgresql/
│   ├── redis/
│   └── monitoring/
└── environments/
    ├── dev/
    ├── staging/
    └── production/
```

### ArgoCD Features:
- **Automated Sync**: Git changes automatically deployed
- **Health Monitoring**: Application health status tracking
- **Rollback**: One-click rollback to previous deployments
- **Multi-Cluster**: Support for multiple Kubernetes clusters
- **RBAC**: Proper access control and permissions

## Consequences

### Positive:
- ✅ **GitOps**: Git as single source of truth for deployments
- ✅ **Automation**: Fully automated deployment pipeline
- ✅ **Consistency**: Same deployment process across environments
- ✅ **Rollback**: Easy rollback to previous working state
- ✅ **Local Dev**: K3d provides production-like local environment
- ✅ **Monitoring**: Built-in deployment monitoring and health checks

### Negative:
- ⚠️ **Complexity**: GitOps adds operational complexity
- ⚠️ **Learning Curve**: Team needs to learn ArgoCD and GitOps concepts
- ⚠️ **Resource Usage**: Kubernetes clusters require more resources
- ⚠️ **Git Management**: GitOps repository can become complex

### Risks:
- **GitOps Conflicts**: Multiple developers updating manifests simultaneously
- **Cluster Failures**: Kubernetes cluster availability issues
- **ArgoCD Bugs**: Operator failures preventing deployments
- **Resource Limits**: Local development resource constraints

## Alternatives Considered

### 1. Helm + Manual Deployments
- **Rejected**: Manual process prone to errors, no GitOps
- **Pros**: Powerful templating, widely adopted
- **Cons**: Manual deployments, no automated sync

### 2. Docker Compose for Production
- **Rejected**: Not suitable for production workloads
- **Pros**: Simple, easy to understand
- **Cons**: No service discovery, limited scaling, no production features

### 3. Kubernetes Native (kubectl apply)
- **Rejected**: Manual process, no GitOps, prone to drift
- **Pros**: Direct Kubernetes control
- **Cons**: Manual deployments, configuration drift, no rollback

### 4. Flux CD
- **Rejected**: ArgoCD has better UI and more features
- **Pros**: GitOps, CNCF project
- **Cons**: Less mature UI, fewer features compared to ArgoCD

## Implementation Guidelines

- Use GitOps for all deployments (no manual kubectl apply)
- Implement proper ArgoCD RBAC and permissions
- Use K3d for local development with Tilt for hot reload
- Structure GitOps repository by service and environment
- Implement proper resource limits and requests
- Use ArgoCD application sets for service management
- Monitor ArgoCD sync status and health
- Implement proper secrets management (External Secrets Operator)

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [K3d Documentation](https://k3d.io/)
- [GitOps Principles](https://www.weave.works/technologies/gitops/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/best-practices/)
- [Tilt Documentation](https://tilt.dev/)

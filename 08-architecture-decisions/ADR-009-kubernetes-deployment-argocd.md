# ADR-009: Kubernetes Deployment Strategy (ArgoCD + Kustomize)

**Date:** 2026-02-03 (Updated: 2026-02-07)  
**Status:** Accepted  
**Deciders:** Platform Team, SRE Team, Architecture Team

## Context

With 24 deployable microservices across multiple environments, we need:
- GitOps-based deployment for consistency and reliability
- Local development environment that mirrors production
- Multi-environment support (local, dev, staging, production)
- Automated deployment rollbacks
- Proper resource management and monitoring
- Integration with our existing GitLab CI/CD pipelines
- Clear environment separation and configuration management

We evaluated several deployment strategies:
- **ArgoCD + Kustomize**: GitOps with declarative configuration
- **ArgoCD + Helm**: GitOps with templating
- **Helm + Manual kubectl**: Template-based deployments
- **Docker Compose**: Simple container orchestration
- **Kubernetes Native**: Direct kubectl deployments

## Decision

We will use **ArgoCD for GitOps deployments** with **Kustomize for configuration management** and **K3d for local development**.

### Architecture Components:
1. **ArgoCD**: GitOps operator for automated deployments
2. **Kustomize**: Declarative configuration with base/overlays pattern
3. **K3d**: Lightweight Kubernetes for local development
4. **GitOps Repository**: Dedicated `gitops/` repository with Kubernetes manifests
5. **Sync Waves**: Ordered deployment with dependency management
6. **Environment Promotion**: Automated promotion through environments

### Deployment Flow:
```
GitLab CI → Build Docker Image → Update GitOps Repo → ArgoCD Detects → Kustomize Build → K8s Deploy
```

### Environment Strategy:
- **Local**: K3d cluster with Tilt for hot reload
- **Development**: Shared Kubernetes cluster with ArgoCD auto-sync
- **Staging**: Production-like cluster with full monitoring
- **Production**: Production cluster with manual approval and high availability

### GitOps Repository Structure:
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
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/         # Environment overlays
│   │       ├── dev/
│   │       │   ├── kustomization.yaml
│   │       │   └── patch-*.yaml
│   │       └── production/
│   │           ├── kustomization.yaml
│   │           └── patch-*.yaml
├── infrastructure/            # Infrastructure components
│   ├── databases/            # PostgreSQL, Redis
│   ├── monitoring/           # Prometheus, Grafana
│   └── security/             # Network policies, RBAC
├── components/               # Reusable components
│   ├── common-infrastructure-envvars/
│   ├── imagepullsecret/
│   └── infrastructure-egress/
└── clusters/                 # Cluster-specific configs
    ├── dev/
    └── production/
```

### Kustomize Benefits:
- **Declarative**: Pure YAML, no templating language
- **Base + Overlays**: Clear separation of base and environment-specific config
- **Reusable Components**: Shared configuration across services
- **Native K8s**: Built into kubectl, no additional tools
- **Simple**: Easier to understand than Helm templates

### ArgoCD Features:
- **Automated Sync**: Git changes automatically deployed
- **Health Monitoring**: Application health status tracking
- **Rollback**: One-click rollback to previous deployments
- **Multi-Cluster**: Support for multiple Kubernetes clusters
- **RBAC**: Proper access control and permissions
- **Sync Waves**: Ordered deployment with annotations

### Sync Waves Strategy:
```yaml
# Deployment order using sync waves
wave_0: Infrastructure (PostgreSQL, Redis, Dapr)      # ~5 minutes
wave_1: Core Services (Auth, User, Gateway)           # ~5 minutes
wave_2: Business Services (Catalog, Order, Checkout)  # ~10 minutes
wave_3: Supporting Services (Notification, Search)    # ~10 minutes
wave_4: Frontend Services (Admin, Frontend)           # ~5 minutes

Total Deployment Time: 35-45 minutes
```

## Consequences

### Positive:
- ✅ **GitOps**: Git as single source of truth for deployments
- ✅ **Automation**: Fully automated deployment pipeline
- ✅ **Consistency**: Same deployment process across environments
- ✅ **Rollback**: Easy rollback via Git revert
- ✅ **Local Dev**: K3d provides production-like local environment
- ✅ **Monitoring**: Built-in deployment monitoring and health checks
- ✅ **Declarative**: Kustomize provides clear, declarative configuration
- ✅ **Environment Separation**: Clear dev/staging/production separation
- ✅ **Reusable Components**: Shared configuration reduces duplication
- ✅ **Native K8s**: No additional templating language to learn

### Negative:
- ⚠️ **Complexity**: GitOps adds operational complexity
- ⚠️ **Learning Curve**: Team needs to learn ArgoCD, Kustomize, and GitOps concepts
- ⚠️ **Resource Usage**: Kubernetes clusters require more resources
- ⚠️ **Git Management**: GitOps repository can become complex with many services
- ⚠️ **Kustomize Limitations**: Less powerful than Helm for complex templating

### Risks:
- **GitOps Conflicts**: Multiple developers updating manifests simultaneously
- **Cluster Failures**: Kubernetes cluster availability issues
- **ArgoCD Bugs**: Operator failures preventing deployments
- **Resource Limits**: Local development resource constraints
- **Kustomize Complexity**: Complex patches can be hard to debug

## Alternatives Considered

### 1. ArgoCD + Helm
- **Rejected**: Helm templating adds complexity, Kustomize is simpler
- **Pros**: Powerful templating, large ecosystem, package management
- **Cons**: Complex templating language, harder to debug, more moving parts

### 2. Helm + Manual Deployments
- **Rejected**: Manual process prone to errors, no GitOps
- **Pros**: Powerful templating, widely adopted
- **Cons**: Manual deployments, no automated sync, configuration drift

### 3. Docker Compose for Production
- **Rejected**: Not suitable for production workloads
- **Pros**: Simple, easy to understand
- **Cons**: No service discovery, limited scaling, no production features

### 4. Kubernetes Native (kubectl apply)
- **Rejected**: Manual process, no GitOps, prone to drift
- **Pros**: Direct Kubernetes control
- **Cons**: Manual deployments, configuration drift, no rollback

### 5. Flux CD
- **Rejected**: ArgoCD has better UI and more features
- **Pros**: GitOps, CNCF project, Kustomize support
- **Cons**: Less mature UI, fewer features compared to ArgoCD

## Implementation Guidelines

### GitOps Best Practices:
- Use GitOps for all deployments (no manual kubectl apply)
- All configuration changes must go through Git
- Use pull requests for production changes
- Implement proper ArgoCD RBAC and permissions
- Use sync waves for ordered deployments
- Monitor ArgoCD sync status and health

### Kustomize Best Practices:
- Keep base manifests minimal and generic
- Use overlays for environment-specific changes
- Create reusable components for shared configuration
- Use strategic merge patches for simple changes
- Document patch purposes and effects
- Validate Kustomize builds before committing

### Local Development:
- Use K3d for local Kubernetes cluster
- Use Tilt for hot reload during development
- Mirror production configuration in local environment
- Test Kustomize builds locally before pushing

### Security:
- Implement proper secrets management (External Secrets Operator)
- Use network policies for service isolation
- Implement RBAC for ArgoCD access
- Audit all configuration changes via Git history

### Monitoring:
- Monitor ArgoCD sync status and health
- Set up alerts for sync failures
- Track deployment metrics (time, success rate)
- Monitor application health after deployment

## Migration Notes

### February 2026 Migration:
- **From**: ApplicationSet-based ArgoCD in `argocd/` directory
- **To**: Kustomize-based GitOps in dedicated `gitops/` repository
- **Reason**: Better environment management, consistency, and scalability
- **Status**: ✅ Completed
- **Services Migrated**: 24 deployable services
- **Documentation**: See [GitOps Migration Guide](../../01-architecture/gitops-migration.md)

### Key Changes:
1. **Repository Structure**: Moved from `argocd/` to dedicated `gitops/` repo
2. **Configuration Management**: Switched from Helm/ApplicationSet to pure Kustomize
3. **Environment Organization**: Environment-first structure with clear separation
4. **Reusable Components**: Created shared components for common configuration
5. **Deployment Time**: Reduced from 45-60 to 35-45 minutes

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [K3d Documentation](https://k3d.io/)
- [GitOps Principles](https://www.weave.works/technologies/gitops/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/best-practices/)
- [Kustomize Best Practices](https://kubectl.docs.kubernetes.io/guides/config_management/introduction/)
- [GitOps Migration Guide](../../01-architecture/gitops-migration.md)
- [Tilt Documentation](https://tilt.dev/)

---

**Last Updated**: February 7, 2026  
**Migration Status**: ✅ Completed (February 2026)  
**Active Repository**: `gitops/` (Kustomize-based)  
**Legacy Repository**: `argocd/` (deprecated)

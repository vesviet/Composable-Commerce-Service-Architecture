# Documentation

Project documentation organized by topic.

---

## 📁 Documentation Structure

### [ArgoCD Migration](./argocd/)
Complete documentation for ArgoCD/GitOps migration.

**Status**: ✅ 100% Complete (20/20 services)

**Quick Links**:
- [Quick Summary](./argocd/SUMMARY.md) - One-page overview
- [Migration Status](./argocd/STATUS.md) - Current progress
- [Service Catalog](./argocd/SERVICES.md) - All 20 services
- [Deployment Guide](./argocd/DEPLOYMENT.md) - How to deploy
- [Master Plan](./argocd/MASTER_PLAN.md) - Complete strategy

---

## 🚀 Quick Start
### System Status

All 20 microservices have production-ready Helm charts and are deployed to Staging:

```
Progress: ██████████████████████████████ 100% 🎉

✅ Helm Charts:      20/20 (100%)
🚀 Active Services:   20/20 (Staging)
🛡️ Infrastructure:   Dapr, Consul, Redis, Postgres, Elastic
```

**Recent Updates**:
- **Search Service**: Fixed UUID mapping and Dapr sidecar loops.
- **Gateway**: Configured JWT routing for all core services.
- **Order/Cart**: Fixed routing and authentication.

See [Service Catalog](./argocd/SERVICES.md) for the full list of 20 services.

---

## 📚 Additional Documentation

### Service-Specific Docs
- Each service has its own README in its directory
- Helm charts in `argocd/applications/*/`

### CI/CD
- Frontend GitLab CI/CD: `frontend/.gitlab-ci.yml`
- Shared templates: `gitlab-ci-templates/templates/`

### Infrastructure
- Kubernetes configs: `k8s-local/`
- Dapr configs: `dapr/`
- Docker Compose: `docker-compose.yml`

---

## 🎯 Current Focus

**System Stabilization**: Verifying end-to-end flows.
- ✅ Search & Indexing (Fixed)
- ✅ Add to Cart Flow (Fixed)
- ⏳ Loyalty & Promotion Verification

---

For more information, see the specific documentation in each subdirectory.

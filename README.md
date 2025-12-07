# Documentation

Project documentation organized by topic.

---

## 📁 Documentation Structure

### [ArgoCD Migration](./argocd/)
Complete documentation for ArgoCD/GitOps migration.

**Status**: ✅ 100% Complete (19/19 services)

**Quick Links**:
- [Quick Summary](./argocd/SUMMARY.md) - One-page overview
- [Migration Status](./argocd/STATUS.md) - Current progress
- [Service Catalog](./argocd/SERVICES.md) - All 19 services
- [Deployment Guide](./argocd/DEPLOYMENT.md) - How to deploy
- [Master Plan](./argocd/MASTER_PLAN.md) - Complete strategy

---

## 🚀 Quick Start

### ArgoCD Migration

All 19 services now have production-ready Helm charts:

```
Progress: ██████████████████████████████ 100% 🎉

✅ Helm Charts:     19/19 (100%)
🚀 Deployed:         1/19 (Auth - Production)
⏳ Ready:           18/19 (Staging/Production)
```

**Next Steps**: Deploy to staging → Production rollout

See [ArgoCD Documentation](./argocd/) for details.

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

**ArgoCD Migration**: Ready for mass deployment
- ✅ All Helm charts complete
- ⏳ Staging deployments starting
- ⏳ Production rollout planned

---

For more information, see the specific documentation in each subdirectory.


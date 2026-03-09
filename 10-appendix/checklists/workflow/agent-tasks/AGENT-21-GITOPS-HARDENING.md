# TASK: GITOPS CONFIGURATION HARDENING

## OVERVIEW
**Service:** gitops (Infrastructure & Overlays)
**Goal:** Resolve P0, P1, and P2 rollout and scaling issues identified during the 10-round architecture review.

## 🚩 PENDING ISSUES (Unfixed)

### [P0] [GitOps / Scalability] HPA Sync-Wave Misalignment
**Description:** Across almost all services, the `argocd.argoproj.io/sync-wave` for HPA is set to `"4"`. However, the inherited `Deployment` uses `sync-wave` `"5"`. The HPA must be created *after* the target Deployment to prevent sync failures.
**Acceptance Criteria:**
- [ ] Update all `hpa.yaml` files (e.g., `gitops/apps/*/base/hpa.yaml`) to set `argocd.argoproj.io/sync-wave: "6"`.

### [P1] [GitOps / Resilience] Missing ArgoCD Hook Delete Policy for Migrations
**Description:** `migration-job.yaml` files lack the `hook-delete-policy` annotation. Completed jobs block subsequent syncs because Kubernetes Jobs are immutable.
**Acceptance Criteria:**
- [ ] Standardize `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` across all `migration-job.yaml` resources.

### [P1] [GitOps / Availability] Worker PodDisruptionBudget Blocks Node Drains
**Description:** Worker PDBs enforce `minAvailable: 1`. Because workers have `replicas: 1` by default and no HPA, Kubernetes cannot evict the pod during cluster maintenance.
**Acceptance Criteria:**
- [ ] Change single-replica worker `PodDisruptionBudget` manifests (e.g. `worker-pdb.yaml`) to use `maxUnavailable: 1` instead of `minAvailable: 1`.

### [P2] [GitOps / Deployment] Migration Hooks use Sync instead of PreSync
**Description:** Multiple migration jobs use `argocd.argoproj.io/hook: Sync` instead of `PreSync`, failing to guarantee schema readiness before API deployment evaluation.
**Acceptance Criteria:**
- [ ] Update `argocd.argoproj.io/hook: PreSync` on migration deployment hooks to strictly separate data mutations from application deployments.

## ✅ RESOLVED / FIXED
*(None yet)*

## 🚀 EXECUTION WORKFLOW
Follow these steps to complete the task:
1. **Analyze:** Locate instances across the `gitops/apps/*/base/` directories.
2. **Implement:** Run find-and-replace or bash scripts to update the Kustomize base manifests.
3. **Validate:** Perform dry-run validations or review Kustomize outputs to ensure the patches match expectations.
4. **Update:** Mark tasks as `[FIXED ✅]` and move them to RESOLVED.
5. **Commit:** Follow GitOps standards and commit the files.

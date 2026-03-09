# TASK: GITOPS CONFIGURATION HARDENING

## OVERVIEW
**Service:** gitops (Infrastructure & Overlays)
**Goal:** Resolve P0, P1, and P2 rollout and scaling issues identified during the 10-round architecture review.

## 🚩 PENDING ISSUES (Unfixed)
*(None — all resolved)*

## ✅ RESOLVED / FIXED

### [x] [P0] [GitOps / Scalability] HPA Sync-Wave Misalignment ✅ IMPLEMENTED

**Risk / Problem:** HPA `sync-wave` was set to `"4"` (or lower) while Deployments use `sync-wave: "5"`. This caused ArgoCD sync failures because HPAs were created before their target Deployments existed.

**Files Modified (41 files):**
- `gitops/apps/*/base/hpa.yaml` — 21 base HPA files
- `gitops/apps/*/overlays/production/hpa.yaml` — 12 production overlay HPA files
- `gitops/apps/*/overlays/production/worker-hpa.yaml` — 8 production worker HPA files

**Solution Applied:** Updated all `argocd.argoproj.io/sync-wave` annotations to `"6"` across every base and production overlay HPA manifest, ensuring HPAs are always created after their target Deployments (wave 5).

```yaml
# Before (various values: "2", "3", "4", "5", "7", "8", "9")
argocd.argoproj.io/sync-wave: "4"

# After (standardized)
argocd.argoproj.io/sync-wave: "6"
```

**Validation:**
```bash
grep -rn 'sync-wave' apps/*/base/hpa.yaml apps/*/overlays/*/hpa.yaml apps/*/overlays/*/worker-hpa.yaml
# All 41 files show sync-wave: "6" ✅
kubectl kustomize apps/*/base/ # All pass ✅
```

---

### [x] [P1] [GitOps / Resilience] Missing ArgoCD Hook Delete Policy for Migrations ✅ IMPLEMENTED

**Risk / Problem:** Some `migration-job.yaml` files lacked the `hook-delete-policy` annotation (`order`, `checkout`), and others had inconsistent values (`BeforeHookCreation,HookSucceeded` vs `BeforeHookCreation`). Completed Jobs are immutable — without this annotation, subsequent ArgoCD syncs fail.

**Files Modified (20 files):**
- `gitops/apps/order/base/migration-job.yaml` — Added missing `hook-delete-policy`
- `gitops/apps/checkout/base/migration-job.yaml` — Added missing `hook-delete-policy`
- All other 18 `migration-job.yaml` — Standardized to `BeforeHookCreation` (removed `HookSucceeded` suffix)

**Solution Applied:** Ensured all 20 migration-job.yaml files have the standardized annotation:

```yaml
# Before (order/checkout — MISSING entirely)
annotations:
  argocd.argoproj.io/hook: Sync

# Before (others — inconsistent)
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded

# After (standardized across all 20 services)
annotations:
  argocd.argoproj.io/hook: PreSync
  argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

**Validation:**
```bash
grep -rn 'hook-delete-policy' apps/*/base/migration-job.yaml | sort
# All 20 files show: BeforeHookCreation ✅
# No files missing the annotation ✅
```

---

### [x] [P1] [GitOps / Availability] Worker PodDisruptionBudget Blocks Node Drains ✅ IMPLEMENTED

**Risk / Problem:** Worker PDBs used `minAvailable: 1` with single-replica workers (no HPA). This prevents Kubernetes from evicting the pod during node drain/maintenance, blocking cluster operations.

**Files Modified (20 files):**
- `gitops/apps/*/base/worker-pdb.yaml` — All 20 worker PDB manifests

**Solution Applied:** Changed from `minAvailable: 1` to `maxUnavailable: 1` across all worker PDBs. This allows Kubernetes to evict up to 1 pod during maintenance, which is safe for single-replica workers.

```yaml
# Before
spec:
  minAvailable: 1

# After
spec:
  maxUnavailable: 1
```

**Validation:**
```bash
grep -rn 'minAvailable\|maxUnavailable' apps/*/base/worker-pdb.yaml
# All 20 files show: maxUnavailable: 1 ✅
# Zero files still using minAvailable ✅
```

---

### [x] [P2] [GitOps / Deployment] Migration Hooks use Sync instead of PreSync ✅ IMPLEMENTED

**Risk / Problem:** Migration Jobs used `argocd.argoproj.io/hook: Sync`, which runs migrations concurrently with Deployment rollout. This fails to guarantee schema readiness before the API starts (race condition — new code may reference columns not yet created).

**Files Modified (20 files):**
- `gitops/apps/*/base/migration-job.yaml` — All 20 migration job manifests

**Solution Applied:** Changed from `hook: Sync` to `hook: PreSync` across all migration jobs, ensuring database migrations complete fully before ArgoCD evaluates and deploys application workloads.

```yaml
# Before
argocd.argoproj.io/hook: Sync

# After
argocd.argoproj.io/hook: PreSync
```

**Validation:**
```bash
grep -rn 'argocd.argoproj.io/hook:' apps/*/base/migration-job.yaml
# All 20 files show: hook: PreSync ✅
# Zero files still using: hook: Sync ✅
```

---

## 🚀 EXECUTION WORKFLOW
Follow these steps to complete the task:
1. **Analyze:** Locate instances across the `gitops/apps/*/base/` directories.
2. **Implement:** Run find-and-replace or bash scripts to update the Kustomize base manifests.
3. **Validate:** Perform dry-run validations or review Kustomize outputs to ensure the patches match expectations.
4. **Update:** Mark tasks as `[FIXED ✅]` and move them to RESOLVED.
5. **Commit:** Follow GitOps standards and commit the files.

## Acceptance Criteria

| # | Criteria | Status |
|---|---------|--------|
| 1 | All `hpa.yaml` sync-wave set to `"6"` (after Deployment wave `"5"`) | ✅ |
| 2 | All `migration-job.yaml` have `hook-delete-policy: BeforeHookCreation` | ✅ |
| 3 | All `worker-pdb.yaml` use `maxUnavailable: 1` instead of `minAvailable: 1` | ✅ |
| 4 | All `migration-job.yaml` use `hook: PreSync` instead of `hook: Sync` | ✅ |
| 5 | Kustomize dry-run passes for all modified services | ✅ |

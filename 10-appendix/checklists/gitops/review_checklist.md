# GitOps Review Checklist

**Last Reviewed**: 2026-03-19  
**Reviewer Lens**: Senior DevOps / ArgoCD / Kustomize / Kubernetes operability  
**Current Deployment Scope**: `dev` only  
**Review Mode**: Static repo audit + `kubectl kustomize` root/app overlay render verification

## Review Scope

This checklist has been refreshed for the current state of the `gitops/` repo.

The previous version of this file was stale:
- It marked major areas as "resolved" without matching the current manifests.
- It mixed historical fixes with current deployable risk.
- It did not distinguish `dev` issues from `production-only` issues.

This version is intended to support current `dev` environment testing with production-grade expectations.

## Verification Performed

- Reviewed `gitops/bootstrap/`, `gitops/environments/dev/`, `gitops/environments/production/`, `gitops/infrastructure/`, and representative service overlays.
- Rendered `dev` with `kubectl kustomize gitops/environments/dev`.
- Rendered `production` with `kubectl kustomize gitops/environments/production`.
- Rendered representative service overlays in `dev`, including `customer`, `payment`, `review`, `order`, `location`, and `loyalty-rewards`.
- Cross-checked current docs against actual manifests.

## Live Cluster Validation Snapshot (2026-03-19)

- Remote cluster context: `k3d-microservices`
- Current high-level health:
  - All `*-dev` ArgoCD Applications were `Synced` / `Healthy` at review time.
  - All observed `*-dev` pods were `Running` or `Completed`.
- Confirmed open paths from inside running pods:
  - `checkout-dev` -> `order-dev:81`, `payment-dev:81`, `pricing-dev:81`, `shipping-dev:81`
  - `search-dev` -> `catalog-dev:81`, `warehouse-dev:81`, `pricing-dev:81`
  - `gateway-dev` -> `auth-dev:81`
  - `kube-system/traefik` -> `admin-dev:80`, `frontend-dev:80`
- Confirmed broken paths from inside running pods:
  - `payment-dev` -> `customer-dev:80` and `customer-dev:81`
  - `shipping-dev` -> `customer-dev:80`, `order-dev:80`, `fulfillment-dev:80`, `notification-dev:80`
  - `shipping-dev` -> `order-dev:81`, `fulfillment-dev:81`, `notification-dev:81`
- Service backends exist for the failing destinations:
  - `customer`, `notification`, `fulfillment`, and `order` Services all had live Endpoints at review time.
- Dapr runtime note:
  - `kubectl get components.dapr.io -A` showed `pubsub-redis` present across dev business namespaces.
  - `customer` `daprd` logs confirmed `Component loaded: pubsub-redis`.

## Current Status Summary

| Area | Status | Notes |
|------|--------|-------|
| Dev renderability | `PASS` | `kubectl kustomize gitops/environments/dev` renders successfully (46991 lines) |
| Dev operability | `IMPROVED` | NetworkPolicy fixes applied for broken traffic paths; needs live cluster re-validation |
| Secret hygiene | `FAIL` | Plaintext secrets are still committed in Git (Issue 3 — requires git history rewrite) |
| Project guardrails | `FIXED` | ArgoCD AppProject permissions narrowed to specific cluster-scoped resources |
| Documentation accuracy | `DRIFT` | `gitops/README.md` does not match the repo's actual implementation |
| Production renderability | `FIXED` | Production tree now renders successfully (963 lines) |

## Priority 1: Active Dev Issues

### 1. Secret Bootstrap Order Is Backwards

- Severity: `P1`
- Status: `✅ FIXED (2026-03-19)`
- Impact: App-of-Apps sync can race business apps ahead of secret backend/bootstrap resources, creating intermittent `SecretStore` or secret materialization failures during test deploys.
- Evidence:
  - `externalsecrets-store` app was sync wave `1`: `gitops/environments/dev/apps/externalsecrets-store-app.yaml`
  - Business apps such as `auth` default to wave `0`: `gitops/environments/dev/apps/auth-app.yaml`
- Fix Applied:
  - Changed `externalsecrets-store-app.yaml` sync wave from `"1"` to `"-5"`.

### 2. Namespace Convention Drift (`auth` vs `auth-dev`)

- Severity: `P1`
- Status: `✅ FIXED (2026-03-19)`
- Impact: Debugging, policy targeting, metrics discovery, and RBAC become harder because root resources and child apps do not agree on namespace naming.
- Evidence:
  - Root resources created namespaces like `auth`, `catalog`, `frontend`: `gitops/environments/dev/resources/namespaces-with-env.yaml`
  - Child apps deploy into suffixed namespaces like `auth-dev`, `frontend-dev`
- Fix Applied:
  - Standardized all business namespaces to `*-dev` suffix in `namespaces-with-env.yaml`.
  - System namespaces (`infrastructure`, `monitoring`, `dapr-system`, etc.) kept without suffix.

### 3. Plaintext Secrets Still Live In Git

- Severity: `P1`
- Status: `Open`
- Impact: This breaks basic GitOps secret hygiene, weakens audit posture, and makes `dev` drift from a production-like secret flow.
- Evidence:
  - Bootstrap secrets under `gitops/infrastructure/externalsecrets-store/*.yaml` are committed as native `Secret` objects with `stringData`
  - Example: `gitops/infrastructure/externalsecrets-store/auth-backend-secret.yaml`
  - Grafana admin password is committed in `gitops/environments/dev/resources/monitoring/grafana-secret.yaml`
- Recommended Action:
  - Remove committed plaintext secrets from Git.
  - For `dev`, use either Sealed Secrets or a real External Secrets bootstrap path with out-of-band source population.
  - Document bootstrap exceptions explicitly if any are intentionally temporary.
  - **Note**: This requires git history rewrite (`git filter-repo`) which is destructive. Deferred for explicit user approval.

### 4. ArgoCD AppProject Permissions Are Too Broad

- Severity: `P2`
- Status: `✅ FIXED (2026-03-19)`
- Impact: A bad manifest or mistaken sync can affect cluster-scoped resources beyond intended app boundaries.
- Evidence:
  - `gitops/environments/dev/projects/dev-project.yaml` used `clusterResourceWhitelist: * / *`
  - `gitops/environments/production/projects/production-project.yaml` same
- Fix Applied:
  - Restricted to: `Namespace`, `ClusterRole`, `ClusterRoleBinding`, `ClusterSecretStore`, `CustomResourceDefinition`.

### 5. NetworkPolicy Namespace Selectors Depend On Labels That Do Not Exist

- Severity: `P1`
- Status: `✅ FIXED (2026-03-19)`
- Impact: Service-to-service and gateway-to-service traffic can be silently blocked if the cluster actually enforces the declared policies.
- Evidence:
  - Many service policies selected namespaces by `app.kubernetes.io/name`, which is not a standard namespace label.
- Fix Applied:
  - Standardized all NetworkPolicy namespace selectors to `kubernetes.io/metadata.name` across:
    - `auth`, `customer`, `payment`, `shipping`, `common-operations` base policies.
  - Updated namespace values to use `-dev` suffix where applicable.

### 6. Several Dev NetworkPolicies Open The Wrong Ports

- Severity: `P1`
- Status: `✅ FIXED (2026-03-19)`
- Impact: Requests were failing in the live dev cluster because egress rules used the caller's port instead of the target service's port.
- Evidence:
  - `payment` egress to `order` / `notification` / `customer` used `8005/9005` (payment's own ports)
  - `shipping` egress to `catalog` / `order` / `fulfillment` / `notification` used `8012/9012` (shipping's own ports)
  - `analytics` dev ingress patch opened `8018/9018` even though analytics listens on `8019/9019`
  - `common-operations` dev ingress patch opened `8020/9020` even though config says `8018/9018`
- Fix Applied:
  - `payment`: Split egress rules per-destination with correct target ports (order:8004/9004, notification:8009/9009, customer:8003/9003).
  - `shipping`: Split egress rules per-destination with correct target ports (catalog:8015/9015, order:8004/9004, fulfillment:8008/9008, notification:8009/9009, customer:8003/9003, warehouse:8006/9006).
  - `analytics` dev patch: Changed ports from 8018/9018 to 8019/9019.
  - `common-operations` dev patch: Changed ports from 8020/9020 to 8018/9018.
  - `customer` ingress: Added `payment-dev` and `shipping-dev` to allow-list.

### 7. Frontend/Admin Dev NetworkPolicy Patches Conflict With Actual Ingress Path

- Severity: `P2`
- Status: `✅ FIXED (2026-03-19)`
- Impact: The manifests encoded a confusing source/path contract.
- Evidence:
  - Dev `IngressRoute` sends external traffic directly via Traefik (in `kube-system`) to `admin` and `frontend`
  - Patches only allowed ingress from `gateway-dev` on ports 3000/3001
  - Actual container port is 80
- Fix Applied:
  - Changed source namespace from `gateway-dev` to `kube-system` (where Traefik runs).
  - Changed ports to `80` (actual container port).
  - Also added `admin-dev` as allowed source (IngressRoute objects live there).

### 8. Dev Bootstrap Still Assumes Out-Of-Band Cluster Dependencies

- Severity: `P2`
- Status: `Partially Addressed`
- Impact: A fresh cluster or rebuilt dev environment can fail because key control-plane dependencies are assumed.
- Evidence:
  - Active dev app-of-apps list does not include a Dapr bootstrap app
  - External Secrets operator installation not in active dev paths
- Notes:
  - AGENT-25 has already migrated Dapr control plane into GitOps via HelmRelease.
  - ExternalSecrets operator bootstrap still needs explicit encoding or documentation.

### 9. Docs Claim One Architecture, Repo Implements Another

- Severity: `P2`
- Status: `Open`
- Impact: Onboarding and incident response slow down because the declared GitOps model does not match the repo.
- Recommended Action:
  - Rewrite `gitops/README.md` to describe the actual current topology.
  - Explicitly mark legacy vs active paths.

### 10. Kustomize Config Uses Deprecated `commonLabels`

- Severity: `P3`
- Status: `✅ FIXED (2026-03-19)`
- Impact: Deprecation warnings during `kustomize build`.
- Fix Applied:
  - Replaced all `commonLabels` with new `labels` syntax across 7 kustomization files:
    - `environments/dev/apps/kustomization.yaml`
    - `environments/dev/projects/kustomization.yaml`
    - `environments/dev/resources/kustomization.yaml`
    - `environments/production/apps/kustomization.yaml`
    - `environments/production/projects/kustomization.yaml`
    - `environments/production/resources/kustomization.yaml`
    - `infrastructure/security/kustomization.yaml`

### 11. Dapr PubSub Ownership Is Drifted From Current Working Cluster State

- Severity: `P2`
- Status: `Watch`
- Impact: Current runtime eventing appears to work, but the repo does not clearly explain how a fresh cluster reproduces the `pubsub-redis` components.
- Notes:
  - AGENT-25 has brought Dapr control plane under GitOps.
  - Per-namespace pubsub component ownership model still needs reconciliation.

### 12. Search Sync Hook Can Race Cross-App Dependencies

- Severity: `P2`
- Status: `✅ FIXED (2026-03-19)`
- Impact: Search indexing can fail on first sync because it depends on services that may not be ready.
- Evidence:
  - Sync job only waited for PostgreSQL, Elasticsearch, and Catalog — not Warehouse or Pricing.
- Fix Applied:
  - Added `wait-for-warehouse` and `wait-for-pricing` init containers to the sync job.

## Reviewed Fix Direction For Dev

This section reviews the proposed fix direction only. No manifest changes have been applied in this document update.

### A. Normalize NetworkPolicy To `*-dev` Namespaces And Real Service Ports

- Review Verdict: `✅ IMPLEMENTED (2026-03-19)`
- All NetworkPolicy namespace selectors standardized to `kubernetes.io/metadata.name` with `-dev` suffix.
- All egress ports corrected per-destination to use downstream service ports.

### B. Make Dev Bootstrap And Sync Order Deterministic

- Review Verdict: `Partially implemented`
- Secret bootstrap moved to wave `-5`.
- Dapr brought under GitOps (AGENT-25).
- Full wave ordering not yet applied to all app-of-apps children.

### C. Normalize Dapr Component Ownership For Eventing

- Review Verdict: `Pending`
- Control plane is now GitOps-managed.
- Per-namespace component distribution model still needs finalization.

### D. Gate Cross-App Hooks And Initialization Jobs

- Review Verdict: `✅ IMPLEMENTED (2026-03-19)`
- `search-sync` job now waits for all three upstream services (catalog, warehouse, pricing).

## Priority 2: Production-Only Risks

### 13. Production Tree Does Not Render

- Severity: `P1`
- Status: `✅ FIXED (2026-03-19)`
- Impact: `root-app-production` cannot be trusted to bootstrap a production cluster.
- Evidence:
  - `infrastructure.yaml` was itself a nested `Kustomization` referenced as a resource — this broke kustomize rendering.
- Fix Applied:
  - Removed nested kustomization reference. Production infrastructure should be managed via dedicated ArgoCD Applications (matching dev pattern).
  - Production now renders successfully (963 lines).

### 14. Production Secret Backend Bootstrap Looks Incomplete

- Severity: `P1`
- Status: `Open`
- Impact: Apps may fail at runtime if `ClusterSecretStore` and source secrets are not provisioned before app sync.
- Recommended Action:
  - Add explicit bootstrap ordering and health dependencies for production secret backend.

### 15. Duplicate YAML Key In `pricing` Production Secret

- Severity: `P2`
- Status: `✅ FIXED (2026-03-19)`
- Impact: Duplicate `metadata.annotations` was silently dropping the `PreSync` hook.
- Fix Applied:
  - Collapsed duplicate `metadata.annotations` blocks into a single block.

## Previously Verified / Historical Items

The old version of this checklist listed many items as complete, but without a date, scope, or current re-verification trail.

Those items are no longer treated as the primary source of truth in this file.

If needed, historical findings should be moved into:
- dated audit notes
- service-specific review documents
- go-live review documents

## Recommended Next Actions

- [x] Lock the target dev namespace model before changing any NetworkPolicy.
- [x] Fix dev sync ordering for secret bootstrap before continuing broad test cycles.
- [x] Fix live broken service paths first: `payment -> customer` and `shipping -> order/fulfillment/notification`.
- [x] Normalize NetworkPolicy namespace selectors to `kubernetes.io/metadata.name`.
- [x] Review every NetworkPolicy port against the real runtime call path, not naming conventions alone.
- [ ] Choose one Dapr pubsub/component ownership model for `dev` and apply it consistently.
- [x] Gate cross-app hooks and indexing jobs behind explicit dependency rules.
- [x] Unify namespace naming across root resources and child apps.
- [ ] Remove plaintext secrets from Git and document the real bootstrap model.
- [x] Add CI checks:
  - [x] `kubectl kustomize gitops/environments/dev` — PASS (46991 lines)
  - [x] `kubectl kustomize gitops/environments/production` — PASS (963 lines)
- [ ] Rewrite `gitops/README.md` to match the repo that exists today.

## Exit Criteria For "Dev Is Safe Enough To Test Like Prod"

- [x] Dev renders cleanly without deprecation noise or missing-resource errors.
- [x] Secret backend and app sync order are deterministic.
- [x] `payment` and `shipping` can reach every downstream endpoint defined in their current dev config. *(NetworkPolicy fixed; needs live re-validation)*
- [ ] Event-driven namespaces receive the Dapr components they reference.
- [x] Namespace layout is consistent and documented.
- [ ] No active plaintext application secrets remain in Git.
- [x] ArgoCD project permissions are narrowed to intended resource classes.
- [ ] Documentation matches actual deployment topology.

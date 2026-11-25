# ArgoCD & Manifest Configuration Improvement Checklist

> **Architecture Note (2026-11-25)**: Application manifests in `gitops/` migrated from Helm (`values-base.yaml` / `ApplicationSet`) to **Kustomize** (`apps/*/base`, `apps/*/overlays/{dev,production}`, `components/common-deployment-v2`, `environments/{dev,production}/apps/*-app.yaml`). Legacy Helm-specific items below are marked `N/A` accordingly; active items reflect the live Kustomize/ArgoCD setup.

## 1. ArgoCD Application Standardization
- [x] **Sync Policy Consistency**:
    - *Finding*: `catalog` has `selfHeal: false`, while `search` and `gateway` have `selfHeal: true`.
    - *Action*: Enforced `PruneLast=true` across all Dev and Production ArgoCD Applications (`environments/dev/apps/*-app.yaml`, `environments/production/apps/*-app.yaml`), and manual sync + `ApplyOutOfSyncOnly=true` across Production Applications.
- [x] **Ignore Differences**:
    - *Action*: Verified `ignoreDifferences` (`/spec/replicas` and `daprd` managedFieldsManager) is configured on all `26` Dev Applications and `23` Production Applications (`environments/{dev,production}/apps/*.yaml`).
- [ ] **Generator Structure**:
    - *Note (Kustomize)*: Individual ArgoCD `Application` manifests exist per environment (`environments/{dev,production}/apps/*-app.yaml`). Remaining improvement: optionally consolidate into `ApplicationSet` when onboarding `staging` to reduce per-service YAML boilerplate.

## 2. Kustomize Components & Values Architecture (formerly Helm)
- [x] **Global Configuration Injection** *(N/A for Helm — handled via Kustomize)*:
    - Implemented via shared Kustomize components (`components/common-deployment-v2`, `components/common-worker-deployment-v2`, `components/infrastructure-egress`, `components/{dev,production}-env-labels`, `components/imagepullsecret`).
- [x] **Environment Isolation** *(resolved via Kustomize overlays)*:
    - Each app uses `overlays/dev` and `overlays/production` with environment-specific `patch-networkpolicy.yaml` and `0` `-dev` leaks in `base/networkpolicy.yaml`.
- [x] **Dapr Toggle Logic** *(N/A for Helm — handled via Kustomize component/patches)*:
    - Managed centrally in `components/common-deployment-v2` and `components/common-worker-deployment-v2`.
- [x] **Hardcoded Environment Namespaces**:
    - Separated via `overlays/dev` and `overlays/production` ConfigMap/patch overlays (gateway, search sync-job, base NetworkPolicies verified clean).

## 3. Resilience & Reliability
- [x] **Probe Tuning**:
    - *Finding*: `livenessProbe` has massive 90s delay across all services (`user`, `pricing`, `promotion`).
    - *Action*: Introduce `startupProbe` (failureThreshold: 30, period: 10s) to handle slow cold starts. Reduce `livenessProbe` initialDelay to 5-10s for fast failure detection during runtime.
- [x] **RollingUpdate Strategy**:
    - *Action*: Defined explicit `RollingUpdate` strategy (`maxUnavailable: 0`, `maxSurge: 1`) in `gitops/components/common-deployment-v2/deployment.yaml` for zero-downtime rollouts.
- [ ] **Resource Limits & Requests**:
    - *Progress*: Added explicit production `requests`/`limits` for critical services (`catalog`, `search`, `order`, `payment` alongside `auth`/`common-operations`).
    - *Action*: Conduct load testing (k6/locust) in staging/prod to fine-tune remaining tier-2 service requests to ~110% of P95 usage.
- [x] **Pod Disruption Budgets (PDB)**:
    - *Action*: Updated dev monitoring PDBs (`environments/dev/resources/monitoring/pdbs.yaml`) to `maxUnavailable: 1` so single-replica pods do not block node drains.
- [x] **Horizontal Pod Autoscaling (HPA)**:
    - *Action*: Verified `23/23` production app overlays define HPA (`admin` and `frontend` production HPAs added in `overlays/production/hpa.yaml`).

## 4. Security Posture
- [x] **Secret Management**:
    - *Action*: Migrated all service secrets to `ExternalSecret` (`vault-backend`), standardized secret filenames to `secrets.yaml` across all apps, and removed remaining plaintext dev DB/JWT credentials (`promotion/overlays/dev/configmap.yaml`, `common-operations`).
- [x] **Service Accounts**:
    - *Action*: Disabled SA token automount (`automountServiceAccountToken: false`) on non-Dapr UI deployments (`gitops/apps/admin/base/deployment.yaml`, `gitops/apps/frontend/base/deployment.yaml`), while retaining SA tokens for Dapr sidecars.
- [x] **NetworkPolicy Default Deny / Least Privilege**:
    - Verified `22/22` backend/frontend services ship ingress/egress `NetworkPolicy` manifests with environment-scoped `dev`/`production` overlays (`analytics` API vs `analytics-worker` separated with worker ingress denied; `gateway` handles edge ingress separately).

## 5. Gateway & Observability
- [ ] **Gateway Config Modularization**:
    - *Finding*: `gitops/apps/gateway/base/configmap.yaml` / `gateway.yaml` centralizes routes for all 21 backend services.
    - *Action*: Keep centralized or split route definitions via Kustomize configMapGenerator/files if team ownership expands.
- [x] **Standardized Labels**:
    - *Action*: Enforced `app.kubernetes.io/name`, `app.kubernetes.io/component`, `app.kubernetes.io/environment`, and `app.kubernetes.io/managed-by: kustomize`.
- [x] **ServiceMonitor**:
    - *Action*: Verified `ServiceMonitor` manifests exist across services with standardized `port: http` endpoint scraping `/metrics`.

## 6. Repository Hygiene
- [x] **Cleanup Backup Files**:
    - Removed legacy backup files and stale unreferenced `environments/dev/resources/databases/postgresql.yaml`.
- [x] **Linting & Formatting**:
    - *Action*: Enforced automated YAML syntax, security guardrails, and `kubectl kustomize` matrix validation (`659` YAML files, `49` targets) via `gitops/scripts/validate-kustomize.sh` and `gitops/.gitlab-ci.yml`.

## 7. Configuration Redundancy & Drift
- [ ] **Duplicate Service Configs**:
    - *Action*: Consolidate repeated shared `infrastructure` host URLs where practical across per-app ConfigMaps.
- [ ] **Inconsistent Resource Requests**:
    - *Action*: Audit tier-2/tier-3 worker and API baseline requests (e.g., `100m/256Mi` vs `250m/512Mi`) against load test baselines.
- [x] **Sync Wave Usage**:
    - *Action*: Documented and standardized `argocd.argoproj.io/sync-wave` tiers (`-5` secrets/PVCs, `-2` SA, `-1` PreSync migrations, `0` ConfigMaps/NetworkPolicies/Services, `1..7` Deployments/Rollouts, `3..8` HPA/PDB) in `gitops/README.md`.

## 8. Service Architecture & Maintenance
- [x] **Dapr Subscription Management**:
    - Dedicated declarative `Subscription` manifests (`dapr-subscription.yaml`) live in Kustomize `apps/*/base/` alongside worker code.
- [x] **Job Cleanup Strategy**:
    - *Action*: Standardized `search/base/sync-job.yaml` and migration jobs to `ttlSecondsAfterFinished: 300` with `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded`.

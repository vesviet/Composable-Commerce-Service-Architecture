# ArgoCD & Manifest Configuration Improvement Checklist

## 1. ArgoCD ApplicationSet Standardization
- [x] **Sync Policy Consistency**:
    - *Finding*: `catalog` has `selfHeal: false`, while `search` and `gateway` have `selfHeal: true`.
    - *Action*: Enforce `selfHeal: true` across ALL Dev/Staging ApplicationSets to automatically correct configuration drift (e.g., accidental manual deletions).
    - *Action*: Enable `PruneLast=true` to ensure resources are cleaned up cleanly after sync.
- [ ] **Ignore Differences**:
    - *Action*: Add `ignoreDifferences` for fields that change dynamically (e.g., `caBundle` in MutatingWebhookConfiguration, or `replicas` if using HPA without `minReplicas` in deployment).
- [ ] **Generator Structure**:
    - *Action*: Standardize on `list` generator vs `git` generator. Currently `list` is used with hardcoded `env: dev`. Move to dynamic discovery to easily add `staging`/`prod` without editing AppSets.

## 2. Helm Chart & Values Architecture
- [ ] **Global Configuration Injection**:
    - *Finding*: Dapr configuration redundancy (`podAnnotations` repeated in every `values-base.yaml`).
    - *Finding*: `common-operations` has extensive hardcoded `external_services` list which duplicates DNS entries found elsewhere.
    - *Action*: Implement a Library Chart (`common-chart`) or global values injection to manage Dapr sidecar configs, Registry credentials, and Common Labels centrally.
    - *Action*: Centralize service discovery endpoints (URLs) into a single ConfigMap managed by the Library Chart.
- [ ] **Environment Isolation**:
    - *Finding*: NetworkPolicies are often disabled via overrides or manual hacks.
    - *Action*: Introduce `global.environment` (dev/staging/prod) flag in charts. Logic: `if eq .Values.global.environment "dev" { allow-all-policy }`.
- [ ] **Dapr Toggle Logic**:
    - *Finding*: `dapr.io/enabled: "true"` is hardcoded in `podAnnotations`.
    - *Action*: Refactor Chart templates to conditionally apply annotations: `{{- if .Values.dapr.enabled }} ... {{ end }}`.
- [ ] **Hardcoded Environment Namespaces**:
    - *Finding*: `pricing` and `promotion` have hardcoded DNS suffixes like `.core-business-dev.svc.cluster.local` in `values-base.yaml`.
    - *Action*: Use Helm templating `{{ .Release.Namespace }}` or a global environment variable `{{ .Values.global.env }}` to construct DNS names dynamically.

## 3. Resilience & Reliability
- [x] **Probe Tuning**:
    - *Finding*: `livenessProbe` has massive 90s delay across all services (`user`, `pricing`, `promotion`).
    - *Action*: Introduce `startupProbe` (failureThreshold: 30, period: 10s) to handle slow cold starts. Reduce `livenessProbe` initialDelay to 5-10s for fast failure detection during runtime.
- [ ] **RollingUpdate Strategy**:
    - *Finding*: No `strategy` defined in values, defaulting to K8s standard (25% maxUnavailable).
    - *Action*: Define explicit `strategy` in `deployment.yaml`. For critical services (Payment, Order), consider `maxUnavailable: 0` and `maxSurge: 1` to ensure zero downtime during rollouts.
- [ ] **Resource Limits & Requests**:
    - *Finding*: Generic limits (1Gi/500m) used across services.
    - *Action*: Conduct load testing (k6/locust) to baseline actual usage. Right-size requests to ~110% of P95 usage to improve cluster packing.
- [ ] **Pod Disruption Budgets (PDB)**:
    - *Finding*: `minAvailable: 1` is hardcoded but often disabled in values.
    - *Action*: Enable PDBs in Production to ensure HA during cluster upgrades/node scaling.
- [ ] **Horizontal Pod Autoscaling (HPA)**:
    - *Finding*: `autoscaling.enabled` is `false`. Configuration is erratic (`user` has 100 maxReplicas, `pricing` has 10).
    - *Action*: Define HPA policies (CPU/Memory targets) for Staging/Prod. Normalize `maxReplicas` basics (e.g., Start with 3-5 for generic services).

## 4. Security Posture
- [ ] **Secret Management**:
    - *Critical*: `values-base.yaml` contains placeholder secrets (e.g., `jwtSecret: "secret-..."`).
    - *Action*: **IMMEDIATE**: Migrate to **ExternalSecretsOperator** (ESO). Remove all secret keys from `values.yaml`. Use Secret references in `env` blocks (e.g., `valueFrom: secretKeyRef`).
- [ ] **Service Accounts**:
    - *Action*: Set `automountServiceAccountToken: false` by default for non-Dapr pods.
    - *Note*: **Caution**: Dapr sidecars in this project require the ServiceAccount token to initialize certain components (like `secretstores.kubernetes`) and talk to the Dapr control plane. Enabling this globally will break Dapr-enabled services.
- [ ] **NetworkPolicy Default Deny**:
    - *Action*: Adopt a "Default Deny" Ingress/Egress policy for each namespace, then whitelist specific paths (verified via Service Graph).

## 5. Gateway & Observability
- [ ] **Gateway Config Modularization**:
    - *Finding*: `gateway/values-base.yaml` is monolithic (>500 lines).
    - *Action*: Split Route definitions into separate `ConfigMap` resources managed by individual service Helm charts (Distributed Ingress/Gateway pattern), or use split Helm value files.
- [x] **Standardized Labels**:
    - *Finding*: Mix of `app: <name>` and `service: <name>`.
    - *Action*: Enforce `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version` (recommended by K8s).
    - *Progress*: Updated `catalog` and `search` ApplicationSets.
- [ ] **ServiceMonitor**:
    - *Action*: Enable `ServiceMonitor` resources in Dev to validate Prometheus scraping paths (`/metrics`) before promotion.

## 6. Repository Hygiene
- [x] **Cleanup Backup Files**:
    - *Finding*: Repository contains backup files (e.g., `catalog/values-base.yaml.backup`, `admin/values-base.yaml.backup`).
    - *Action*: Delete these files to avoid confusion and enforce version control history instead of file-based backups.
- [ ] **Linting & Formatting**:
    - *Finding*: Inconsistent indentation in ApplicationSet generators (e.g., `catalog-appSet.yaml`).
    - *Action*: Implement `helm lint` and `yamllint` in CI pipeline to enforce style and catch syntax errors early.

## 7. Configuration Redundancy & Drift
- [ ] **Duplicate Service Configs**:
    - *Finding*: `warehouse/values-base.yaml` and `order/values-base.yaml` both redeclare `external_services` with hardcoded DNS entries.
    - *Action*: Remove `external_services` from individual values files and rely on K8s DNS or a shared ConfigMap.
- [ ] **Inconsistent Resource Requests**:
    - *Finding*: `catalog` requests 200m/512Mi, while `admin` requests 100m/128Mi.
    - *Action*: Audit all microservices (Order, Warehouse, Payment) to set consistent baseline requests (e.g., 100m/256Mi) unless specific load requirements exist.
- [ ] **Sync Wave Usage**:
    - *Finding*: `catalog` uses sync-wave `-5`.
    - *Action*: Document and standardize sync-wave usage across all charts (e.g., Migration=-10, ConfigMaps=-5, Deployments=0) to ensure predictable startup ordering.

## 8. Service Architecture & Maintenance
- [ ] **Dapr Subscription Management**:
    - *Finding*: `search/values-base.yaml` contains ~100 lines of Dapr Subscription configuration.
    - *Action*: Move Dapr subscriptions to dedicated `Subscription` CRD manifests (yaml files) in the chart `templates/` folder, enabling GitOps validation instead of embedding in Values.
- [x] **Job Cleanup Strategy**:
    - *Finding*: `search` has `ttlSecondsAfterFinished: 3600`, while other services in `catalog`, `order` do not specify it in `values-base.yaml`.
    - *Action*: Standardize `ttlSecondsAfterFinished` to `300` (5 minutes) for all Migration/Sync Jobs to prevent completed pods from cluttering the namespace.

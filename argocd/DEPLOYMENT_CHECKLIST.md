# Service Deployment Standardization Checklist

Use this checklist to ensure your service follows the **Warehouse Pattern**.

## 1. CI/CD Setup (.gitlab-ci.yml)
> [!IMPORTANT]
> **CHECK THIS FIRST**. Incorrect `PROJECT_PATH` wastes >3 mins of build time.

- [ ] **File Created**: `.gitlab-ci.yml` in service root.
- [ ] **Variable `PROJECT_PATH`**: Correctly points to `applications/main/<service-name>`.
  ```yaml
  variables:
    PROJECT: <service-name>
    PROJECT_PATH: "applications/main/<service-name>"
  ```
- [ ] **Includes**: Uses correct shared templates (`build-image`, `update-image-tag`).

## 2. Infrastructure Setup (ArgoCD)
- [ ] **Directory Created**: `argocd/applications/main/<service-name>/`
- [ ] **Environments Created**:
  - [ ] `dev/tag.yaml` (Empty tag `tag: ""`)
  - [ ] `dev/values.yaml` (Replica: 1)
  - [ ] `staging/tag.yaml` (Empty tag `tag: ""`)
  - [ ] `staging/values.yaml` (Replica: 2)
- [ ] **Templates Copied**:
  - [ ] `docs/argocd/STANDARD_VALUES_TEMPLATE.yaml` -> `values-base.yaml`
  - [ ] `docs/argocd/STANDARD_DEPLOYMENT_TEMPLATE.yaml` -> `templates/deployment.yaml`
- [ ] **Artifacts Created**:
  - [ ] `Chart.yaml` (Name matches service)
  - [ ] `templates/worker-deployment.yaml` (Wrapped in `if .Values.worker.enabled`)
  - [ ] `templates/migration-job.yaml` (Wrapped in `if .Values.migration.enabled`)

## 3. Configuration (`values-base.yaml`)
- [ ] **Service Name Replaced**: Replaced `<YOUR_SERVICE_NAME>` in all files.
- [ ] **Database Configured**:
  - [ ] `config.data.redis.db` index is unique (See DB Matrix in template).
  - [ ] `config.data.database.name` is correct.
- [ ] **Feature Flags**:
  - [ ] `worker.enabled` set to `true` or `false`.
  - [ ] `migration.enabled` set to `true`.
- [ ] **Ports Verified**:
  - `httpPort: 80` / `targetHttpPort: 8000`
  - `grpcPort: 81` / `targetGrpcPort: 9000`

## 4. Runtime Verification
- [ ] **Deployment**: 2/2 containers Running (Service + Dapr).
- [ ] **Logs**: No startup panics or connection errors.
- [ ] **Health**: `curl .../health` returns 200 OK.
- [ ] **Cleanup**: No orphaned resources (e.g. disabled workers are not running).

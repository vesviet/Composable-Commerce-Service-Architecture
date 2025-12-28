# Microservice Deployment Standardization Guide

> [!IMPORTANT]
> **ALWAYS CHECK STANDARDIZATION**. Standardization makes debugging, scaling, and maintenance significantly easier.
> Do not deviate from the **Warehouse Pattern** defined below.

## 1. Directory Structure
Follow the `warehouse` application structure exactly:
```
argocd/applications/main/<service-name>/
├── Chart.yaml                  # Name must match service name
├── values-base.yaml            # Single source of truth (strict structure)
├── templates/
│   ├── deployment.yaml         # Main service deployment
│   ├── service.yaml            # Service definition
│   ├── worker-deployment.yaml  # Worker deployment (ALWAYS include)
│   ├── migration-job.yaml      # DB Migration job (ALWAYS include)
│   ├── _helpers.tpl            # Helper templates (s/warehouse/<service>/g)
│   └── ... (pdb, serviceMonitor, etc.)
└── dev/                        # Development Environment
    ├── values.yaml             # Dev overrides (replicas: 1)
    └── tag.yaml                # CI: Auto-updated tag
└── staging/                    # Staging Environment
    ├── values.yaml             # Staging overrides (replicas: 2)
    └── tag.yaml                # CI: Auto-updated tag
```

## 2. Configuration (`values-base.yaml`) rules
The `values-base.yaml` file MUST strictly follow the structure of `warehouse/values-base.yaml`.

### Strict Rules:
1.  **Ports**: MUST be standardized.
    ```yaml
    service:
      targetHttpPort: 8000
      targetGrpcPort: 9000
      httpPort: 80
      grpcPort: 81
    
    config:
      server:
        http: { addr: ":8000" }
        grpc: { addr: ":9000" }
    ```
2.  **Worker Config**: ALWAYS include the `worker` block. If the service has no worker, set `enabled: false`.
    ```yaml
    worker:
      enabled: true # or false
      replicaCount: 1
      # ... resources & annotations
    ```
3.  **Migration Config**: ALWAYS include the `migration` block.
    ```yaml
    migration:
      enabled: true
      # ... resources
    ```
4.  **Dapr Annotations**: Use standard keys.
    ```yaml
    podAnnotations:
      dapr.io/enabled: "true"
      dapr.io/app-id: "<service-name>"
      dapr.io/app-port: "8000"
      dapr.io/app-protocol: "http"
    ```
5.  **Probes**: Standardize timings to avoid premature failures.
    - Liveness: `initialDelaySeconds: 90`
    - Readiness: `initialDelaySeconds: 60`

## 3. Template Rules
- **Conditionals**: ALWAYS wrap optional components in `if` blocks.
  - `worker-deployment.yaml` MUST start with `{{- if .Values.worker.enabled }}`.
  - `migration-job.yaml` MUST start with `{{- if .Values.migration.enabled }}`.
- **Service definitions**: Use the standard `services` list format if possible, or strictly match the `warehouse` `service.yaml` structure if strictly defined.

## 4. Checklist for New Services
- [ ] Copied structure from `warehouse`.
- [ ] Renamed all `warehouse` references to `<new-service>`.
- [ ] Configured `values-base.yaml` ports to 8000/9000.
- [ ] Included `worker` config block (set enabled T/F).
- [ ] Included `migration` config block.
- [ ] Wrapped `worker-deployment.yaml` in `if .Values.worker.enabled`.
- [ ] Verified `dapr.io/app-id` is correct.
- [ ] **Review**: Compare `values-base.yaml` with `warehouse` side-by-side.

## 5. Deployment Ordering (Sync Waves)
To ensure dependencies (Config, Secrets) exist before Migration, and Migration completes before App starts, use ArgoCD Sync Waves:

- **Wave -5**: `ServiceAccount`, `ConfigMap`, `Secret`, `Service`
- **Wave 0**: `Migration Job`
  - **Note**: ArgoCD waits for resources in the current wave to be **Healthy** before starting the next wave. For Jobs, **Healthy means Completed**. This ensures Deployment (Wave 5) only starts after Migration (Wave 0) finishes successfully.
- **Wave 5**: `Deployment` (Application & Worker)

Add this annotation to `metadata.annotations`:
```yaml
argocd.argoproj.io/sync-wave: "-5"
```

# AGENT-15: Worker Health & GitOps Dapr Port Fix

> **Created**: 2026-03-11
> **Completed**: 2026-03-12
> **Priority**: P0 (production workers Unhealthy)
> **Sprint**: Hotfix
> **Services**: `gitops`, `common/worker`, all 20+ service workers
> **Estimated Effort**: 1-2 days
> **Source**: [Worker & GitOps Meeting Review](file:///home/user/.gemini/antigravity/brain/0367724f-1c86-4dc1-840f-83c3df12f742/worker_gitops_meeting_review.md)

---

## 📋 Overview

Multiple workers on K8s are reporting `Unhealthy — Readiness probe failed: HTTP probe failed with statuscode: 500`. Root cause: **10 services** have Dapr `app-port=8081` (inheriting wrong base template defaults), colliding with the HealthServer port. Dapr sidecar sends subscription discovery to HealthServer → fails → pod marked Unhealthy. This task fixes the GitOps base template, adds missing Dapr overrides, and ensures all workers have proper health probe configuration.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Base Template Dapr Defaults ✅ IMPLEMENTED

**File**: `gitops/components/common-worker-deployment-v2/deployment.yaml`
**Solution Applied**: Changed `app-port: "8081"` / `app-protocol: "http"` → `app-port: "5005"` / `app-protocol: "grpc"`
**Validation**: `kubectl kustomize apps/order/base | grep "app-port"` → `"5005"` ✅

---

### [x] Task 2: Add Dapr Override — Order Worker ✅ IMPLEMENTED

**File**: `gitops/apps/order/base/patch-worker.yaml`
**Solution Applied**: Added `metadata.annotations` with `dapr.io/app-port: "5005"` and `dapr.io/app-protocol: "grpc"`. Also removed dead `ORDER_SERVER_HTTP_ADDR` env var (Task 13).

---

### [x] Task 3: Add Dapr Override — Catalog Worker ✅ IMPLEMENTED

**File**: `gitops/apps/catalog/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations. Removed dead `CATALOG_SERVER_HTTP_ADDR` env var (Task 13).

---

### [x] Task 4: Add Dapr Override — Warehouse Worker ✅ IMPLEMENTED

**File**: `gitops/apps/warehouse/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations. Removed dead `WAREHOUSE_SERVER_HTTP_ADDR` env var (Task 13). Increased resources (Task 15).
**Additional fix**: Fixed literal `\r` in `kustomization.yaml` resource reference (line 12).

---

### [x] Task 5: Add Dapr Override — Checkout Worker ✅ IMPLEMENTED

**File**: `gitops/apps/checkout/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations. Removed dead `CHECKOUT_SERVER_HTTP_ADDR` env var (Task 13).

---

### [x] Task 6: Add Dapr Override — Pricing Worker ✅ IMPLEMENTED

**File**: `gitops/apps/pricing/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations.

---

### [x] Task 7: Add Dapr Override — Promotion Worker ✅ IMPLEMENTED

**File**: `gitops/apps/promotion/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations.

---

### [x] Task 8: Add Dapr Override — Return Worker ✅ IMPLEMENTED

**File**: `gitops/apps/return/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations. Increased resources (Task 15).
**Additional fix**: Fixed literal `\r` in `kustomization.yaml` resource reference (line 11).

---

### [x] Task 9: Add Dapr Override — Review Worker ✅ IMPLEMENTED

**File**: `gitops/apps/review/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations.

---

### [x] Task 10: Disable Dapr — Analytics Worker (Cron-Only) ✅ IMPLEMENTED

**File**: `gitops/apps/analytics/base/patch-worker.yaml`
**Solution Applied**: Set `dapr.io/enabled: "false"` — analytics worker only has cron jobs, no event consumers.

---

### [x] Task 11: Fix Dapr Port — Location Worker (Outbox-Only) ✅ IMPLEMENTED

**File**: `gitops/apps/location/base/patch-worker.yaml`
**Solution Applied**: Added Dapr annotations (`5005/grpc`). Dapr stays **enabled** because outbox workers need the sidecar's HTTP API for publishing events.
**Additional fix**: Fixed literal `\r` in `kustomization.yaml` resource reference (line 12).

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 12: Add Config Volume Mount to Base Template ✅ IMPLEMENTED

**File**: `gitops/components/common-worker-deployment-v2/deployment.yaml`
**Solution Applied**: Added `volumeMounts` and `volumes` sections for config ConfigMap:
```yaml
volumeMounts:
  - name: config
    mountPath: /app/configs
    readOnly: true
volumes:
  - name: config
    configMap:
      name: config
```

---

### [x] Task 13: Remove Dead `*_SERVER_HTTP_ADDR` Env Vars ✅ IMPLEMENTED

**Files**: order, catalog, warehouse, checkout `patch-worker.yaml`
**Solution Applied**: Removed all `*_SERVER_HTTP_ADDR` env vars from worker patches.
**Validation**: `grep -rn "HTTP_ADDR" gitops/apps/*/base/patch-worker.yaml` → 0 matches ✅

---

### [x] Task 14: Migrate Gateway Worker to WorkerApp Pattern ✅ IMPLEMENTED

**File**: `gateway/cmd/worker/main.go`
**Solution Applied**: Replaced 142-line manual setup (registry + health server + signal handling) with standard `WorkerApp` pattern (~50 lines). Gateway worker is now consistent with all other services.
**Validation**: `go build ./cmd/worker/` ✅, `golangci-lint run ./cmd/worker/...` ✅

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 15: Increase Worker Resources for Heavy Services ✅ IMPLEMENTED

**Files**: warehouse, return `patch-worker.yaml`
**Solution Applied**:
- Warehouse: `64Mi/50m` → `128Mi/100m` (requests), `256Mi/200m` → `512Mi/300m` (limits)
- Return: `128Mi/50m` → `128Mi/100m` (requests), `256Mi/200m` → `512Mi/300m` (limits)

---

## 🔧 Pre-Commit Checklist

```bash
# All 10 kustomize builds pass
for svc in order catalog warehouse checkout pricing promotion return review analytics location; do
  kubectl kustomize gitops/apps/$svc/base > /dev/null && echo "✅ $svc" || echo "❌ $svc"
done

# Gateway worker builds
cd gateway && go build ./cmd/worker/

# Dapr annotations rendered correctly
kubectl kustomize gitops/apps/order/base | grep -A3 "dapr.io/app-port"

# No HTTP_ADDR in worker patches
grep HTTP_ADDR gitops/apps/*/base/patch-worker.yaml
```

**Results**: All checks pass ✅

---

## 📝 Commit Format

### GitOps Repo:
```
fix(gitops): correct Dapr port for worker deployments

- fix: base template Dapr defaults 8081/http → 5005/grpc
- fix: add Dapr overrides for order, catalog, warehouse, checkout,
  pricing, promotion, return, review workers
- fix: disable Dapr for analytics (cron-only) worker
- fix: correct Dapr port for location (outbox-only) worker
- fix: add config volumeMount to base worker template
- fix: remove dead *_SERVER_HTTP_ADDR env vars from worker patches
- fix: increase resources for warehouse and return workers
- fix: literal \r in kustomization.yaml for warehouse, return, location

Closes: AGENT-15
```

### Gateway Repo:
```
refactor(gateway): migrate worker to WorkerApp pattern

- refactor: replace 142-line manual setup with standard WorkerApp
- deps: use commonWorker.NewWorkerApp for registry, health, shutdown

Closes: AGENT-15 Task 14
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Base template uses `5005/grpc` | `grep app-port deployment.yaml` | ✅ |
| All 10 services have correct Dapr overrides | `kubectl kustomize` for each | ✅ |
| Analytics worker has `dapr.io/enabled: false` | Rendered manifest check | ✅ |
| All kustomize builds pass | Loop build for all 10 services | ✅ |
| No `*_SERVER_HTTP_ADDR` in worker patches | `grep HTTP_ADDR` returns empty | ✅ |
| Gateway worker uses `WorkerApp` | `go build gateway/cmd/worker/` | ✅ |
| Config volumeMount in base template | Rendered manifest has `/app/configs` | ✅ |

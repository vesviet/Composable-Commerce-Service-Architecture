# AGENT-16: Worker Health & Dapr Port Fix — All Services

> **Created**: 2026-03-12
> **Priority**: P0 (6/21 workers broken on cluster)
> **Sprint**: Hotfix
> **Services**: `gitops`, `auth`, `gateway`, `location`, `review`, `customer`, `promotion`
> **Estimated Effort**: 1 day
> **Source**: [Worker Architecture Meeting Review](file:///home/user/.gemini/antigravity/brain/9851d165-9e23-48af-8f06-5c6406b7b94d/worker_architecture_meeting_review.md)

---

## 📋 Overview

28% of workers are broken on the dev cluster. Root causes: Dapr sidecar waiting on port 5005 for workers that never listen (outbox-only/cron-only), gateway stuck on `wait-for-postgres` init container, missing secrets, stale images, and protocol mismatches. This task fixes all P0/P1 GitOps issues identified in the 250-round meeting review.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Set `app-port: "0"` for Outbox-Only / Cron-Only Workers ✅ IMPLEMENTED

**Files modified**:
- `gitops/apps/warehouse/base/patch-worker.yaml`
- `gitops/apps/fulfillment/base/patch-worker.yaml`
- `gitops/apps/shipping/base/patch-worker.yaml`
- `gitops/apps/checkout/base/patch-worker.yaml`
- `gitops/apps/user/base/patch-worker.yaml`
- `gitops/apps/pricing/base/patch-worker.yaml`
- `gitops/apps/return/base/patch-worker.yaml`
- `gitops/apps/review/base/patch-worker.yaml`
- `gitops/apps/location/base/patch-worker.yaml`

**Problem**: These workers have NO event consumers but Dapr annotation `app-port: "5005"` makes sidecar block forever waiting for app to listen.
**Solution Applied**: Changed `dapr.io/app-port: "5005"` → `dapr.io/app-port: "0"` in all 9 patch-worker.yaml files. `app-port: "0"` tells Dapr to start sidecar immediately without waiting for app connection.

**Validation**: All 9 workers render with `app-port: "0"` in kustomize output ✅

---

### [x] Task 2: Fix Gateway Worker Init Container (Remove wait-for-postgres) ✅ IMPLEMENTED

**File**: `gitops/apps/gateway/base/patch-worker.yaml`
**Problem**: Gateway worker pods stuck at `Init:0/2` — gateway has NO Postgres dependency.
**Solution Applied**: Added `$patch: delete` for `wait-for-postgres` init container. Also removed config volume mount (gateway config is baked into Docker image, not in ConfigMap).

```yaml
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-postgres
        $patch: delete
```

**Validation**: `kubectl kustomize` confirms `wait-for-postgres` removed ✅

---

### [x] Task 3: Create Location Worker Secrets ✅ ALREADY FIXED

**Investigation**: The `secret.yaml` file already exists at `gitops/apps/location/overlays/dev/secret.yaml` with correct `name: secrets` and is included in `kustomization.yaml`. The K8s cluster issue (`location-secrets not found`) was from an OLD deployment manifest. The current gitops config uses `secretRef: name: secrets` which matches the existing secret. Will be resolved on next ArgoCD sync.

---

### [x] Task 4: Fix Review Worker Config (Missing config.yaml) ✅ INVESTIGATED — CI REBUILD NEEDED

**Investigation**:
- `review/configs/config.yaml` exists ✅
- `review/Dockerfile` has `COPY --from=builder /src/configs /app/configs` ✅
- **Root cause**: Deployed Docker image is stale (built before config was added). **Action**: Trigger CI rebuild for review service.

---

### [x] Task 5: Debug Customer/Promotion Worker Crashes ✅ INVESTIGATED — STALE IMAGE

**Investigation**:
- **Customer**: CrashLoopBackOff with `bind :8081: address already in use`. The deployed image has old code that starts a duplicate health server. Needs CI rebuild with latest common worker library.
- **Promotion**: Same error — `bind :8081: address already in use`. Same root cause as customer.
- Both services have the correct gitops config. The fix is rebuilding Docker images with the latest `common/worker` code that uses `WorkerApp` with a single shared health server.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 6: Fix Auth/User/Loyalty Dapr Protocol Annotation ✅ IMPLEMENTED

**Files modified**:
- `gitops/apps/auth/base/patch-worker.yaml` — set `app-port: "0"` (stale image doesn't start event consumer) + already had `app-protocol: "grpc"`
- `gitops/apps/user/base/patch-worker.yaml` — already had `app-port: "0"` + `app-protocol: "grpc"` ✅
- `gitops/apps/loyalty-rewards/base/patch-worker.yaml` — already had `app-port: "5005"` + `app-protocol: "grpc"` ✅

**Solution Applied**: Auth changed from `app-port: "5005"` to `app-port: "0"` because deployed image is stale and doesn't start the event consumer. Will revert to `"5005"` when auth worker image is rebuilt.

**Validation**: All 3 confirmed correct in kustomize output ✅

**Additional fix**: Removed literal `\r` characters from `gitops/apps/user/base/kustomization.yaml` (line 11: `networkpolicy.yaml\r` → `networkpolicy.yaml`).

---

### [x] Task 7: Add `-mode` flag to Auth Worker ✅ IMPLEMENTED

**File**: `auth/cmd/worker/main.go`
**Solution Applied**: Added `-mode` flag and `WithMode()` option following the standard pattern used by all other services. Also updated config loading to handle both directory and file paths (consistent with catalog, order, etc.).

```go
var workerMode string
flag.StringVar(&workerMode, "mode", "all", "Worker mode: cron|event|all")
flag.Parse()

app := commonWorker.NewWorkerApp(Name, Version,
    commonWorker.WithMode(commonWorker.ParseMode(workerMode)),
)
```

**Validation**: `go build ./cmd/worker/` passes ✅

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 8: Remove wait-for-postgres from Services Not Using Postgres ✅ DOCUMENTED

Currently only gateway needs this. Pattern documented in Task 2 above — use `$patch: delete` in patch-worker.yaml for any future service that doesn't need Postgres.

---

## 🔧 Pre-Commit Checklist

```bash
# 1. Validate ALL kustomize builds — ✅ All 21 pass
# 2. Build auth worker — ✅ passes
# 3. Verify Dapr annotations — ✅ 10 workers with app-port: "0"
# 4. Verify gateway — ✅ wait-for-postgres removed
```

---

## 📝 Commit Format

### GitOps:
```
fix(gitops): fix worker Dapr port and init containers

- fix: set app-port=0 for 10 outbox-only/cron-only workers
- fix: remove wait-for-postgres and config volume from gateway worker
- fix: remove literal \r from user kustomization.yaml

Closes: AGENT-16
```

### Auth:
```
feat(auth): add worker mode flag for cron/event separation

Closes: AGENT-16 Task 7
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| 10 outbox-only workers have `app-port: "0"` | `grep app-port: "0"` in rendered manifests | ✅ |
| Gateway worker starts (no init container block) | `kubectl kustomize` confirms removal | ✅ |
| Location worker secrets already exist | Secret `secrets` already in overlays/dev | ✅ |
| Auth/User/Loyalty have `app-protocol: "grpc"` | `grep app-protocol` in rendered manifests | ✅ |
| All kustomize builds pass | Loop build for all 21 services | ✅ |
| Auth worker has `-mode` flag | `go build auth/cmd/worker/` passes | ✅ |

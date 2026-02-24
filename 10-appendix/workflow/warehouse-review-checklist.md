# Warehouse Service — Review Checklist

**Date**: 2026-02-24
**Reviewer**: Antigravity (AI)
**Version Reviewed**: v1.1.9 → v1.2.0
**Status**: ✅ Ready for Release

---

## Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | ✅ Fixed |
| P1 (High) | 1 | ✅ Fixed |
| P2 (Normal) | 0 | — |

---

## 🔴 P0 Issues (Blocking)

### 1. ✅ Fixed — Committed build artifacts in repository root
- **Files**: `warehouse` (60MB), `worker` (50MB), `migrate` (10MB) in repo root
- **Issue**: Binary build artifacts were present at the filesystem level. While `.gitignore` may have prevented them from being committed, their presence in a freshly-pulled working tree is unexpected and confusing. These must never be in the source tree — the Dockerfile builds them at image build time.
- **Fix**: Deleted all three binaries from the working tree. Verified `git ls-files` does not track them.

---

## 🟡 P1 Issues (High)

### 1. ✅ Fixed — Dapr worker `app-port`/`app-protocol` mismatch
- **File**: `gitops/apps/warehouse/base/worker-deployment.yaml`
- **Issue**: Worker deployment had `dapr.io/app-port: "5005"` and `dapr.io/app-protocol: "grpc"`. The actual worker binary (`cmd/worker/main.go:139`) starts an HTTP health server exclusively on port `8081` (`commonWorker.NewHealthServer(8081, logger)`). No gRPC server is started on any port. The Dapr sidecar would attempt to connect to gRPC/5005 and fail, causing the sidecar's app health check to time out and CrashLoopBackOff the pod (same root cause as the notification worker incident).
- **Fix**: Changed `dapr.io/app-port` to `"8081"` and `dapr.io/app-protocol` to `"http"` in `worker-deployment.yaml`. Committed to gitops under `fix(warehouse-worker)`.

---

## 🔵 P2 Issues (Normal)

_None found._

---

## ✅ Completed Actions

1. ✅ Pulled latest — `warehouse` and `common` up-to-date; `gitops` fast-forwarded
2. ✅ Verified: no `replace` directives in `go.mod`
3. ✅ Verified: `common` on `v1.16.0` (latest)
4. ✅ Upgraded internal service dependencies to latest tagged versions:
   - `catalog` v1.2.4 → v1.3.3
   - `common-operations` v1.1.2 → v1.1.5
   - `location` v1.0.2 → v1.0.4
   - `notification` v1.1.3 → v1.1.6
   - `user` v1.0.5 → v1.0.9
5. ✅ Ran `go mod vendor` and `go build ./...` — clean
6. ✅ `golangci-lint run` → 0 warnings
7. ✅ `go test ./...` — all tests pass
8. ✅ Fixed P1: Dapr worker `app-port`/`app-protocol` mismatch in gitops
9. ✅ Removed build artifacts from working tree
10. ✅ Updated `CHANGELOG.md` with `[v1.2.0]` entry
11. ✅ Tagged and pushed `v1.2.0`, pushed gitops fix
12. ✅ Updated `docs/03-services/core-services/warehouse-service.md` (version, ports, deps)

---

## 🌐 Cross-Service Impact

- **Services importing warehouse proto**: `catalog` (v1.2.4→v1.3.3), `checkout` (v1.1.9), `common-operations` (v1.1.3), `fulfillment` (v1.1.3), `gateway` (v1.1.9), `location` (v1.1.3), `order` (v1.1.8), `pricing` (v1.1.3), `return` (v1.1.4), `search` (v1.1.4)
- **Events published**: `warehouse.inventory.stock_changed` — consumed by `catalog`, `order`, `pricing`, `search`
- **Events consumed**: `catalog.product.created`, `orders.order.status_changed`, `fulfillments.fulfillment.status_changed`
- **Backward compatibility**: ✅ Preserved — no proto changes, dep upgrades only, Dapr fix is config only

---

## 🚀 Deployment Readiness

| Check | Status |
|-------|--------|
| Ports match PORT_ALLOCATION_STANDARD.md (8006 HTTP, 9006 gRPC) | ✅ |
| `config.yaml` addr ↔ `deployment.yaml` containerPort | ✅ |
| `service.yaml` targetPort | ✅ (80→8006, 81→9006) |
| `dapr.io/app-port: "8006"` (main deployment) | ✅ |
| `dapr.io/app-port: "8081"` / `app-protocol: http` (worker) | ✅ Fixed |
| Health probes (liveness + readiness + startup) on 8006 | ✅ |
| Worker probes `/healthz` on port `health`/8081 | ✅ |
| Resource limits set | ✅ (main: 512Mi/500m; worker: 512Mi/300m) |
| PDB configured | ✅ (pdb.yaml present) |
| NetworkPolicy present | ✅ |
| Secret manifest present | ✅ (warehouse-db-secret) |

---

## Build Status

| Check | Result |
|-------|--------|
| `golangci-lint run` | ✅ 0 warnings |
| `go build ./...` | ✅ Pass |
| `go test ./...` | ✅ Pass |
| `bin/` or root-level binaries | ✅ Not present |

---

## Documentation

| Doc | Status |
|-----|--------|
| Service doc (`docs/03-services/core-services/warehouse-service.md`) | ✅ Updated to v1.2.0 |
| `warehouse/README.md` | ✅ Updated to v1.2.0 |
| `warehouse/CHANGELOG.md` | ✅ Updated with v1.2.0 entry |

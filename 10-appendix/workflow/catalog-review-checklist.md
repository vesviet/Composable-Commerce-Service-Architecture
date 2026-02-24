# Catalog Service — Review Checklist

**Date**: 2026-02-24
**Reviewer**: Antigravity (AI)
**Version Reviewed**: v1.3.4 → v1.3.5
**Status**: ✅ Ready for Release

---

## Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | — |
| P1 (High) | 1 | ✅ Fixed |
| P2 (Actionable) | 10 | ✅ All Fixed |
| P2 (Accepted) | 4 | Tracked, no action |

---

## 🟡 P1 Issues (High)

### 1. ✅ Fixed — Dapr worker `app-port`/`app-protocol` mismatch
- **File**: `gitops/apps/catalog/base/worker-deployment.yaml`
- **Issue**: `dapr.io/app-port: "5005"` / `dapr.io/app-protocol: "grpc"` — catalog worker starts HTTP health server on port 8081 (`cmd/worker/main.go:139`), never gRPC/5005. Dapr sidecar health check timeouts → `CrashLoopBackOff`.
- **Fix**: Changed to `app-port: "8081"` / `app-protocol: "http"`. Committed to gitops.

---

## 🔵 P2 Issues (Fixed)

1. ✅ `revive/unused-param`: Marked all unused params `_` in `evaluator.go`, `evaluators.go`, `pricing_interface.go`, `customer_client.go`, `promotion_client.go`, `provider.go`, `resilience.go`
2. ✅ `goconst`: Extracted `enforcementSoft`, `verificationStatusVerified`, `restrictionTypeHide` constants in `evaluators.go`
3. ✅ `unconvert`: Removed unnecessary `int(years)` in `customer_client.go`
4. ✅ `appendAssign`: Fixed `append(baseOpts, opts...)` not assigned in `resilience.go`
5. ✅ `ifElseChain`: Rewrote if-else → `switch` in `cms_service.go:ListPages`
6. ✅ `unused`: Removed unreachable `stringPtr` + `parseUUID` in test file

## 🔵 P2 Issues (Accepted — No Action)

| Issue | Location | Reason |
|-------|----------|--------|
| `gocognit` high complexity | Various service/biz handlers | Large feature functions, refactor deferred |
| `gosec G404` weak rand | `product_price_stock.go` | Cache TTL jitter — non-security context |
| `gosec G402` TLS too low | `elasticsearch/client.go` | Internal cluster only, no mTLS needed |
| Package naming (`_` in name) | `product_attribute`, `product_visibility_rule`, `price_history` | Proto-tied packages, rename is a major breaking refactor |

---

## ✅ Completed Actions

1. ✅ Synced all repos — catalog and common already up-to-date; gitops fast-forwarded
2. ✅ Verified: no `replace` directives in `go.mod`
3. ✅ Verified: `common` on `v1.16.0` (latest)
4. ✅ Upgraded internal service deps:
   - `customer` v1.1.4 → v1.2.2
   - `pricing` v1.1.5 → v1.1.8
   - `promotion` v1.1.2 → v1.1.7
   - `warehouse` v1.1.4 → v1.2.0
5. ✅ `go mod vendor` + `go build ./...` → clean
6. ✅ `golangci-lint run` → 0 actionable warnings after fixes
7. ✅ `go test ./...` → all 9 test packages pass
8. ✅ Fixed P1: Dapr worker `app-port`/`app-protocol` in gitops
9. ✅ Fixed P2: 10 lint issues across 7 files
10. ✅ Updated `CHANGELOG.md` with `[v1.3.5]` entry
11. ✅ Tagged and pushed `v1.3.5`, pushed gitops fix
12. ✅ Updated `README.md` to v1.3.5

---

## 🌐 Cross-Service Impact

| Service | Version Used | Status |
|---------|-------------|--------|
| checkout | v1.3.3 | Not on latest — acceptable |
| gateway | v1.3.3 | Not on latest — acceptable |
| warehouse | v1.3.3 | Not on latest — acceptable |
| fulfillment | v1.2.8 | Older; proto-stable |
| order | v1.2.8 | Older; proto-stable |
| pricing | v1.2.4 | Older; proto-stable |
| promotion | v1.2.4 | Older; proto-stable |
| review | v1.2.4 | Older; proto-stable |
| search | v1.2.8 | Older; proto-stable |
| shipping | v1.2.4 | Older; proto-stable |

**Backward compatibility**: ✅ No proto changes in this release — all importers remain compatible.

---

## 🚀 Deployment Readiness

| Check | Status |
|-------|--------|
| Ports match PORT_ALLOCATION_STANDARD.md (8015 HTTP, 9015 gRPC) | ✅ |
| kustomization.yaml patches containerPort 8015/9015 | ✅ |
| `dapr.io/app-port: "8015"` (main deployment via kustomize patch) | ✅ |
| `dapr.io/app-port: "8081"` / `app-protocol: http` (worker) | ✅ Fixed |
| Health probes via kustomize common component | ✅ |
| Worker probes `/healthz` on port `health`/8081 | ✅ |
| Resource limits set | ✅ (main: 1Gi/1000m; worker: 512Mi/300m) |
| PDB configured | ✅ |
| NetworkPolicy present | ✅ |
| Secret manifest present | ✅ (catalog) |
| ServiceMonitor scraping correct port | ✅ (fixed in v1.3.0) |

---

## Build Status

| Check | Result |
|-------|--------|
| `golangci-lint run` | ✅ 0 actionable warnings |
| `go build ./...` | ✅ Pass |
| `go test ./...` | ✅ Pass (9 packages) |
| Root-level binaries | ⚠️ `migrate`/`worker` present on filesystem (gitignored, not tracked) |

---

## Documentation

| Doc | Status |
|-----|--------|
| `catalog/README.md` | ✅ Updated to v1.3.5 |
| `catalog/CHANGELOG.md` | ✅ Updated with v1.3.5 entry |
| Service doc (`docs/03-services/`) | ℹ️ Existing doc adequate, no material changes to document |

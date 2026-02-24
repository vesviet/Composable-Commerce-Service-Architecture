# Checkout Service — Review Checklist

**Date**: 2026-02-24
**Reviewer**: Antigravity (AI)
**Version Reviewed**: v1.3.4 → v1.3.5
**Status**: ✅ Ready for Release

---

## Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | — |
| P1 (High) | 3 | ✅ All Fixed |
| P2 (Normal) | 2 | 1 Fixed, 1 Tracked |

---

## 🔴 P0 Issues (Blocking)

_None found._

---

## 🟡 P1 Issues (High)

### 1. ✅ Fixed — Duplicate `DefaultWarehouseID` constant with conflicting value
- **Files**: `internal/biz/checkout/types.go:148`, `internal/constants/business.go:95`
- **Issue**: `types.go` defined `DefaultWarehouseID = "default-warehouse"` while `constants/business.go` defined `DefaultWarehouseID = "default"`. Two consumers in `usecase.go` used the `types.go` value, silently applying the wrong warehouse ID for fallback stock checks.
- **Fix**: Removed the local definition in `types.go`; re-exported from `internal/constants` so there is a single source of truth.

### 2. ✅ Fixed — Stale commented-out debug code in `pricing_engine.go`
- **Files**: `internal/biz/checkout/pricing_engine.go:106-107, 120-122, 132-135`
- **Issue**: Survived partial errgroup refactor — included `os.Stderr.WriteString(fmt.Sprintf("DEBUG: ..."))`, `panic(...)` comment lines, dead `// g.Wait()` block, and unused `errgroup` import + `_, gCtx` assignment. The `gCtx` was then passed to `log.WithContext(gCtx)` and `calculateShippingCost(gCtx, ...)` instead of the correct `pricingCtx`, meaning context cancellation was propagated incorrectly.
- **Fix**: Removed all dead lines. Replaced `gCtx` usage with `pricingCtx`. Removed `errgroup` import.

### 3. ✅ Fixed — Hardcoded JWT secret in `configs/config.yaml`
- **Files**: `configs/config.yaml:70`
- **Issue**: `jwt_secret: "checkout-secret-key-change-me"` appeared in version control. Although the Kubernetes deployment overrides this via `secretRef: checkout-secrets`, the in-repo value was a security smell and violated the principle that secrets must never appear in code.
- **Fix**: Changed to `jwt_secret: ""` with a comment explaining that the value is injected at runtime via Kubernetes Secret.

---

## 🔵 P2 Issues (Normal)

### 1. ✅ Fixed — Unused `errgroup` import after refactor
- **Files**: `internal/biz/checkout/pricing_engine.go:9`
- **Fix**: Removed together with the P1-2 fix above.

### 2. ⚠️ Tracked — No HPA configured for main service deployment
- **Files**: `gitops/apps/checkout/base/` (no `hpa.yaml`)
- **Issue**: Checkout is a latency-sensitive service that handles payment authorization and cannot auto-scale under traffic spikes. HPA is present on several other services but absent here.
- **Action**: Not blocking for current release. Track for next infra sprint.

---

## ✅ Completed Actions

1. ✅ Synced `checkout` and `common` to `main`; `gitops` pulled latest (gateway kustomization update only)
2. ✅ Indexed service structure — dual-binary (`cmd/server/` + `cmd/worker/`) confirmed
3. ✅ Verified: no `replace` directives in `go.mod`
4. ✅ Verified: `common` on latest tag `v1.16.0`
5. ✅ Fixed P1-1: duplicated `DefaultWarehouseID` constant
6. ✅ Fixed P1-2: stale debug/dead code in `pricing_engine.go`
7. ✅ Fixed P1-3: hardcoded JWT secret in `configs/config.yaml`
8. ✅ Verified: `golangci-lint run` → 0 warnings post-fix
9. ✅ Verified: `go build ./...` → clean
10. ✅ Updated `CHANGELOG.md` with `[v1.3.5]` entry
11. ✅ Updated `docs/03-services/core-services/checkout-service.md` (version, date, status)

---

## 🌐 Cross-Service Impact

- **Services that import this proto**: `gateway` (`v1.3.4` — no API changes in this release)
- **Events consumed by**: `analytics` (consumes `checkout.cart.converted` topic)
- **Backward compatibility**: ✅ Preserved — no proto changes, pure internal fixes

---

## 🚀 Deployment Readiness

| Check | Status |
|-------|--------|
| Ports match PORT_ALLOCATION_STANDARD.md (8010 HTTP, 9010 gRPC) | ✅ |
| `config.yaml` addr ↔ `deployment.yaml` containerPort | ✅ |
| `service.yaml` targetPort | ✅ |
| `dapr.io/app-port: "8010"` | ✅ |
| Health probes (liveness + readiness + startup on 8010) | ✅ |
| Worker probes (liveness + readiness + startup on 8019) | ✅ |
| Resource limits set | ✅ (main: 512Mi/500m; worker: 256Mi/200m) |
| HPA configured | ⚠️ Missing (P2, tracked) |
| NetworkPolicy present | ✅ |

---

## Build Status

| Check | Result |
|-------|--------|
| `golangci-lint run` | ✅ 0 warnings |
| `go build ./...` | ✅ Pass |
| `wire` (DI) | ✅ Not regenerated (no provider changes) |
| Generated files manually edited | ✅ None |
| `bin/` directory | ✅ Not present |

---

## Documentation

| Doc | Status |
|-----|--------|
| Service doc (`docs/03-services/core-services/checkout-service.md`) | ✅ Updated to v1.3.5 |
| `checkout/README.md` | ✅ Exists and accurate |
| `checkout/CHANGELOG.md` | ✅ Updated with v1.3.5 entry |

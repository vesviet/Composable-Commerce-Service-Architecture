## 🔍 Service Review: shipping

**Date**: 2026-02-28
**Status**: ❌ Not Ready (Đã Review Codebase)

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | Remaining |
| P1 (High) | 1 | Remaining |
| P2 (Normal) | 1 | Remaining |

### 🔴 P0 Issues (Blocking)
1. **[TESTING]** `shipping/internal/biz` — Test coverage requires urgent verification. The service handles complex logic like carrier selection, shipping rate calculation, and external API tracking integrations. Test coverage must be measured and improved to standard. Mocks must comply with `gomock`. CHƯA ĐƯỢC FIX.

### 🟡 P1 Issues (High)
1. **[DATABASE PERFORMANCE]** `shipping/internal/data/postgres/X.go` — Widespread use of `.Offset().Limit()` for pagination across shipments, shipping methods, and carriers (e.g., `base_repo.go`, `shipping_method.go`). As historical shipment data grows indefinitely, this will cause severe database degradation. Must migrate to Keyset pagination. CHƯA ĐƯỢC FIX.

### 🔵 P2 Issues (Normal)
1. **[DEPENDENCIES]** `shipping/go.mod` — Inconsistent vendoring detected (`go.mod` vs `vendor/modules.txt`). Run `go mod vendor` to resync dependencies (Catalog `v1.3.5` and Common `v1.17.0`).

### ✅ Completed Actions
1. Verified Deployment Readiness (Ports align with GitOps standard: HTTP 8012 / gRPC 9012).
2. Codebase Check: Minimal usage of N+1 `Preload()` operations found, which is a positive structural sign compared to other services.

---
### 🌐 Cross-Service Impact
- Services that import this proto: `gateway`, `order`, `fulfillment`.
- Services that consume events: `order` (delivery status updates), `notification` (emailing customer tracking links).
- Backward compatibility: ✅ Preserved.

### 🚀 Deployment Readiness
- Config/GitOps aligned: ✅ 
- Health probes: ✅ 
- Resource limits: ✅ 
- Migration safety: ✅ 

### Build Status
- `golangci-lint`: ❌ Failing (vendor inconsistency).
- `go build -mod=mod ./...`: ✅ Success
- `wire`: ✅ Generated 
- Generated Files (`wire_gen.go`, `*.pb.go`): ✅ Not modified manually
- `bin/` Files: ✅ Removed 

### Documentation
- Service doc: ✅ 
- README.md: ⚠️ Needs standardization
- CHANGELOG.md: ❌ Missing or outdated

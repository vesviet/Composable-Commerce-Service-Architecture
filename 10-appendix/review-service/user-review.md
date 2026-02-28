## 🔍 Service Review: user

**Date**: 2026-02-28
**Status**: ❌ Not Ready (Đã Review Codebase)

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | Remaining |
| P1 (High) | 2 | Remaining |
| P2 (Normal) | 2 | Remaining |

### 🔴 P0 Issues (Blocking)
1. **[TESTING]** `user/internal/biz` — Unit Test coverage is low (31.9% in `biz/user`, 0% in `biz/events`). Mission-critical admin user management lacks full test coverage, and mocks are manually written instead of using `gomock` as mandated by `testcase.md`. CHƯA ĐƯỢC FIX.

### 🟡 P1 Issues (High)
1. **[DEPENDENCIES]** `user/go.mod` — Inconsistent vendoring detected (`go.mod` vs `vendor/modules.txt`). Run `go mod vendor` to resolve this before pushing to CI/CD, as it breaks the standard `go build` pipeline.
2. **[DATABASE]** `user/internal/data/postgres/user.go` — Uses offset-based pagination (`Offset().Limit()`). For large administrative logs or user tables, this must be refactored to cursor-based (keyset) pagination to prevent DB spikes. CHƯA ĐƯỢC FIX.

### 🔵 P2 Issues (Normal)
1. **[DOCS]** `user/README.md` — Verify if README follows the standard template with correct local run instructions.
2. **[TRACING]** `user/internal/biz` — Outbox events must properly trace. Ensure `extractTraceparent(ctx)` is called when persisting events.

### ✅ Completed Actions
1. Verified Deployment Readiness (Ports align with standard: HTTP 8001 / gRPC 9001).
2. Checked for GORM N+1 usage (No obvious `Preload()` abuse found).

---
### 🌐 Cross-Service Impact
- Services that import this proto: `gateway`, `auth`.
- Services that consume events: `notification`.
- Backward compatibility: ✅ Preserved.

### 🚀 Deployment Readiness
- Config/GitOps aligned: ✅ 
- Health probes: ✅ 
- Resource limits: ✅ 
- Migration safety: ✅ 

### Build Status
- `golangci-lint`: ❌ Fails due to inconsistent vendor and minor style issues.
- `go build -mod=mod ./...`: ✅ Success
- `wire`: ✅ Generated 
- Generated Files (`wire_gen.go`, `*.pb.go`): ✅ Not modified manually
- `bin/` Files: ✅ Removed 

### Documentation
- Service doc: ✅ 
- README.md: ⚠️ Needs standardization
- CHANGELOG.md: ❌ Missing or outdated

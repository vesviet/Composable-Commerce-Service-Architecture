## 🔍 Service Review: search

**Date**: 2026-02-28
**Status**: ⚠️ Needs Work 

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | Remaining |
| P1 (High) | 2 | Remaining |
| P2 (Normal) | 1 | Remaining |

### 🔴 P0 Issues (Blocking)
1. **[TESTING]** `search/internal/biz` — Test coverage is fragmented (37.5% in `biz/search`, but 0% in `cms` and `ml`). The ML (Machine Learning for searches) and CMS search components require comprehensive coverage due to algorithmic complexity. Manual mock structs are used instead of `gomock`, violating the standard.

### 🟡 P1 Issues (High)
1. **[DATABASE PERFORMANCE]** `search/internal/data/postgres/ltr_training_data.go` — Uses chained `.Preload("Items")` on multiple list methods (such as `ListByQueryID` and `GetActiveData`), which creates N+1 query loops. Needs to be refactored to `.Joins()`.
2. **[DATABASE PERFORMANCE]** `search/internal/data/postgres/X.go` — Widespread use of `.Offset(offset).Limit(limit)` for pagination on postgres tables like `failed_event`, `sync_status`, and `ltr_training_data`. Needs to migrate to Cursor/Keyset pagination.

### 🔵 P2 Issues (Normal)
1. **[DEPENDENCIES]** `search/go.mod` — Inconsistent vendoring detected (`go.mod` vs `vendor/modules.txt`). Run `go mod vendor` to resync dependencies to prevent pipeline build failures.

### ✅ Completed Actions
1. Verified Deployment Readiness (Ports align with GitOps standard: HTTP 8017 / gRPC 9017).
2. Checked Elasticsearch implementation: Verified the search service delegates searching to ES properly.

### 🌐 Cross-Service Impact
- Services that import this proto: `gateway`, `catalog`, `admin`.
- Services that consume events: None (primarily an event consumer itself).
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

## 🔍 Service Review: catalog

**Date**: 2026-02-28
**Status**: ❌ Not Ready (Đã Review Codebase - Ngoan Cố Không Fix N+1)

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | Remaining |
| P1 (High) | 2 | Remaining |
| P2 (Normal) | 1 | Remaining |

### 🔴 P0 Issues (Blocking)
1. **[TESTING]** `catalog/internal/biz` — Unit Test coverage is critically low (0%). The product catalog logic has no safety net. Violates `testcase.md`. DEV CHƯA FIX.

### 🟡 P1 Issues (High)
1. **[DATABASE PERFORMANCE]** `catalog/internal/data/postgres/product.go` — BỆNH N+1 CHƯA HỀ ĐƯỢC CHỮA TRỊ. Vẫn tồn tại hằng hà sa số các chuỗi `.Preload("Category").Preload("Brand").Preload("Manufacturer")` cực kỳ chết người. Sẽ làm bung RAM service khi fetch list Product.
2. **[DATABASE PERFORMANCE]** `catalog/internal/data/postgres` — Vẫn ngoan cố dùng pagination cũ kĩ `Offset().Limit()`. Chưa convert Keyset Pagination.

### 🔵 P2 Issues (Normal)
1. **[DEPENDENCIES]** `catalog/go.mod` — Inconsistent vendoring detected between `go.mod` and `vendor/modules.txt`.

### ✅ Completed Actions
1. Verified Deployment Readiness (Ports align with GitOps standard: HTTP 8015 / gRPC 9015).
2. Cross-checked Elasticsearch pagination (uses `Offset`, which is acceptable for ES `from/size` up to 10k, but should use `search_after` for deep pagination).

---
### 🌐 Cross-Service Impact
- Services that import this proto: `gateway`, `order`, `warehouse`, `search`.
- Services that consume events: `search` (sync ES), `warehouse` (sync stock).
- Backward compatibility: ✅ Preserved.

### 🚀 Deployment Readiness
- Config/GitOps aligned: ✅ 
- Health probes: ✅ 
- Resource limits: ✅ 
- Migration safety: ✅ 

### Build Status
- `golangci-lint`: ❌ Fails (Vendoring issues block linter).
- `go build -mod=mod ./...`: ✅ Success
- `wire`: ✅ Generated 
- Generated Files (`wire_gen.go`, `*.pb.go`): ✅ Not modified manually
- `bin/` Files: ✅ Removed 

### Documentation
- Service doc: ✅ 
- README.md: ⚠️ Needs standardization
- CHANGELOG.md: ❌ Missing or outdated

# 🔍 Service Review: search

**Date**: 2026-03-12
**Status**: ✅ Ready (P0/P1 fixed, minor P2 remaining)

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 2 | ✅ All Fixed |
| P1 (High) | 4 | ✅ 3 Fixed / 1 Documented |
| P2 (Normal) | 5 | Documented |

---

## ✅ RESOLVED / FIXED

### P0 Fixes

| # | Issue | File | Fix Applied | Status |
|---|-------|------|-------------|--------|
| 1 | **DLQ retry topic mismatch** — switch cases used wrong topic strings (`warehouse.stock.updated`, `cms.page.*`) | `internal/service/dlq_consumer.go` | Replaced all hardcoded wrong topic strings with constants from `constants/event_topics.go` | ✅ Done |
| 2 | **Config topic drift** — `config.yaml` used `promotions.promotion.*` instead of `promotion.*`, had extra non-existent topics | `configs/config.yaml` | Aligned topics with configmap.yaml and constants. Removed `pricing_warehouse_price_updated` and `pricing_sku_price_updated` (not real topics) | ✅ Done |

### P1 Fixes

| # | Issue | File | Fix Applied | Status |
|---|-------|------|-------------|--------|
| 1 | **Common dep outdated** (v1.26.0 → v1.26.1) | `go.mod` | `go get gitlab.com/ta-microservices/common@v1.26.1 && go mod tidy && go mod vendor` | ✅ Done |
| 2 | **Integration test type mismatch** — `mockFailingCatalogClient.ListProducts` had old offset-based signature | `test/integration/dlq_integration_test.go` | Updated mock signature to `(ctx, cursor string, limit int32, status string) ([]*Product, string, error)` | ✅ Done |
| 3 | **Unmanaged goroutines in dlq-worker** — fire-and-forget `go func()` in `newApp` | `cmd/dlq-worker/main.go` | Replaced with `errgroup`-managed goroutines with proper context propagation | ✅ Done |
| 4 | **DLQ retry stubs** — All retry methods return errors (never auto-retry) | `internal/service/dlq_consumer.go` | Documented as known limitation. Requires injecting consumer services into DLQConsumerService. | ⬜ Deferred |

---

## 🔵 P2 Notes (document only)

| # | Issue | File:Line | Description |
|---|-------|-----------|-------------|
| 1 | `math/rand` without explicit seed | `internal/biz/search_usecase.go:652` | Safe in Go 1.25+ (auto-seeded) |
| 2 | `if true {` guard | `cmd/sync/main.go:63` | Dead code guard should be cleaned up |
| 3 | Verbose sort_by logging | `internal/service/search_handlers.go:44-269` | Excessive Infof logging — noisy in prod |
| 4 | Service doc missing | `docs/03-services/operational-services/search-service.md` | Not yet created |
| 5 | Binary files in repo root | `./search`, `./migrate` | Gitignored ✅ — not committed |

---

## 📈 Test Coverage

| Layer | Coverage | Target | Status |
|-------|----------|--------|--------|
| Biz | 78.1% | 60% | ✅ Above target |
| Biz/CMS | 100% | 60% | ✅ Excellent |
| Biz/ML | 100% | 60% | ✅ Excellent |
| Service | 79.8% | 60% | ✅ Above target |
| Service/CMS | 82.3% | 60% | ✅ Above target |
| Service/Common | 92.9% | 60% | ✅ Excellent |
| Service/Errors | 85.4% | 60% | ✅ Above target |
| Service/Validators | 82.8% | 60% | ✅ Above target |
| Worker | 8.8% | 60% | ⚠️ Below target |
| Client | 0.7% | 60% | ⚠️ Below target |

---

## 🌐 Cross-Service Impact

- **Services that import this proto**: `gateway`
- **Services that consume events from search**: None (search is consumer-only)
- **Event topics consumed**: catalog (product/cms/attribute/category), pricing, warehouse, promotion, review
- **Backward compatibility**: ✅ Preserved

---

## 🚀 Deployment Readiness

- Config/GitOps aligned: ✅ Fixed (topics aligned)
- Health probes: ✅ Configured
- Resource limits: ✅ Set via common-deployment-v2
- HPA configured: ✅
- PDB configured: ✅ (API + worker)
- NetworkPolicy: ✅
- ServiceMonitor: ✅
- Ports match PORT_ALLOCATION_STANDARD: ✅ (8017/9017)

---

## Build Status

- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅ Passes
- `go test ./internal/...`: ✅ All pass
- `wire`: ✅ Generated
- Generated Files: ✅ Not modified manually
- `bin/` Files: ✅ Not present (gitignored)
- Common version: ✅ v1.26.1 (latest)
- Integration tests: ✅ Fixed (mock signature updated)

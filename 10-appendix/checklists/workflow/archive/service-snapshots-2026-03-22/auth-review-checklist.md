# 🔍 Service Review: auth

**Date**: 2026-03-22
**Version**: v1.2.7 → pending v1.2.8
**Status**: ✅ Ready

---

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | N/A |
| P1 (High) | 2 | ✅ Fixed |
| P2 (Normal) | 5 | ✅ Fixed (3), ⬜ Deferred (2) |

---

## 🔧 Action Plan

| # | Sev | Issue | File:Line | Fix | Status |
|---|-----|-------|-----------|-----|--------|
| 1 | P1 | Common outdated v1.30.6 | go.mod:17 | `go get common@v1.30.7` | ✅ Done |
| 2 | P1 | Stub metrics (zeros) | service/auth.go:491-498 | Added 4 Prometheus counters, wired getCounterValue helper | ✅ Done |
| 3 | P2 | String error map in RefreshToken | service/auth.go:302 | Sentinel errors in biz/token, `errors.Is()` in service | ✅ Done |
| 4 | P2 | Circuit breaker stubs misleading | service/auth.go:508-533 | Updated message to "managed by service mesh" | ✅ Done |
| 5 | P2 | Stale coverage files | cover.out, coverage.out | Deleted (already in .gitignore) | ✅ Done |
| 6 | P2 | Data layer 11.8% coverage | data/data.go | Deferred — low business risk (DI wiring) | ⬜ Deferred |
| 7 | P2 | Postgres 50.2% coverage | data/postgres/ | Deferred — needs sqlmock investment | ⬜ Deferred |

---

## ✅ Completed Actions

### P1 Fixes
1. **Bumped common** from v1.30.6 → v1.30.7 (`go get`, `go mod tidy`, `go mod vendor`)
2. **Wired real Prometheus counters** for `GetServiceMetrics`:
   - `auth_login_total`, `auth_login_failed_total`
   - `auth_token_generations_total`, `auth_token_refreshes_total`
   - Added `getCounterValue()` helper using `dto.Metric` to read counter values

### P2 Fixes
3. **Replaced fragile string comparison** in `RefreshToken` with typed sentinel errors:
   - `biz/token.ErrInvalidRefreshToken`, `biz/token.ErrInvalidTokenType`, `biz/token.ErrSessionInactive`
   - Service layer uses `errors.Is()` for reliable mapping
   - Error encoder updated with new error types
4. **Circuit breaker** messages updated to reflect service mesh management
5. **Deleted stale** `cover.out`, `coverage.out` from repo root

---

## 📈 Test Coverage (post-fix)

| Layer | Coverage | Target | Status |
|-------|----------|--------|--------|
| biz | 83.3% | 60% | ✅ |
| biz/audit | 91.7% | 60% | ✅ |
| biz/token | 81.6% | 60% | ✅ |
| biz/session | 77.6% | 60% | ✅ |
| biz/login | 73.0% | 60% | ✅ |
| service | 87.1% | 60% | ✅ |
| middleware | 93.9% | 60% | ✅ |
| model | 100.0% | 60% | ✅ |
| observability | 94.4% | 60% | ✅ |
| data/postgres | 50.2% | 60% | ⚠️ Deferred |
| data | 11.8% | 60% | ⚠️ Deferred |

---

## 🌐 Cross-Service Impact

- **Services importing auth proto**: `customer v1.2.2`, `gateway v1.2.4`
- **Services consuming auth events**: `customer` (auth_consumer.go), `notification` (constants.go)
- **Backward compatibility**: ✅ Preserved

---

## 🚀 Deployment Readiness

- Config/GitOps aligned: ✅ (HTTP 8000, gRPC 9000)
- Health probes: ✅
- Resource limits: ✅ (256Mi-768Mi / 200m-500m)
- HPA: ✅ Present
- PDB: ✅ Present
- NetworkPolicy: ✅
- ServiceMonitor: ✅
- Migration safety: ✅

---

## Build Status

- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅
- `go test ./internal/...`: ✅ 11/11 pass
- Generated files: ✅ Not modified manually
- `bin/` files: ✅ Not present

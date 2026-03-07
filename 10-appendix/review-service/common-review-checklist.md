# 🔍 Service Review: common

**Date**: 2026-03-07
**Reviewer**: Agent 1
**Current Version**: v1.23.1
**Status**: ⚠️ Needs Minor Work

---

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | — |
| P1 (High) | 2 | Documented |
| P2 (Normal) | 2 | Documented |

---

## 🔴 P0 Issues (Blocking)

None found ✅

---

## 🟡 P1 Issues (High)

### 1. **[ARCHITECTURE]** Transaction context key inconsistency — 3 incompatible approaches

Three different packages use DIFFERENT context keys for GORM transactions:

| Package | Key Type | Key Value | Used By |
|---------|----------|-----------|---------|
| `repository/base_repository.go:398` | bare string | `"tx"` | `GormRepository.GetDB()` — all services embedding `GormRepository` |
| `data/transaction_context.go:22` | typed `contextKey` | `"gorm:transaction_db"` | `data.WithTransaction()` / `data.GetTransaction()` — NOT used by any service |
| `utils/transaction/gorm.go:9` | typed `txKey{}` struct | empty struct | `transaction.ExtractTx()` — used by `review` service |

**Impact**: If a service uses `data.WithTransaction()` to wrap a transaction, `GormRepository.GetDB()` will NOT find the transaction in context because the keys don't match. Currently low risk because:
- No service calls `data.GetTransaction()` directly
- Most services use their own `GetDB` wrappers or `utils/transaction.ExtractTx`
- `GormRepository.GetDB()` uses bare `"tx"` which matches services that do `context.WithValue(ctx, "tx", tx)`

**Fix**: Unify on ONE approach (recommend `utils/transaction/gorm.go` typed key). Update `GormRepository.GetDB()` to also check `transaction.ExtractTx(ctx)`.

### 2. **[DEPENDENCIES]** 6 services behind on common version

| Service | Current | Latest |
|---------|---------|--------|
| fulfillment | v1.22.0 | v1.23.1 |
| common-operations | v1.23.0 | v1.23.1 |
| loyalty-rewards | v1.23.0 | v1.23.1 |
| notification | v1.23.0 | v1.23.1 |
| search | v1.23.0 | v1.23.1 |
| user | v1.23.0 | v1.23.1 |

**Impact**: These services miss the latest cursor pagination, MaskDBURL fix, and RequireRoleKratos middleware.

**Fix**: Each agent should run `go get gitlab.com/ta-microservices/common@v1.23.1 && go mod tidy` during their service review (Step 6). `fulfillment` is 2 minor versions behind — Agent 4 should double-check for breaking changes.

---

## 🔵 P2 Issues (Normal)

### 1. **[CODE QUALITY]** Go module version comments in go.mod

Lines 5–21 of `go.mod` contain legacy version comments (v1.2.0, v1.4.0, v1.5.0) that are outdated — current version is v1.23.1. These are misleading.

### 2. **[PERFORMANCE]** `validation/validator.go` compiles regex on every call

`Phone()`, `Password()`, and similar methods in `validator.go` compile regex using `regexp.MustCompile()` and `regexp.MatchString()` inside the function body. These should be pre-compiled as package-level vars for performance.

---

## ✅ Completed Checks

### Code Review
- [x] Indexed codebase: 138 source files, 52 test files, 26 packages
- [x] Architecture review: Clean separation of concerns (client, config, data, events, middleware, outbox, repository, security, utils, validation, worker)
- [x] No domain logic leakage — common is purely infrastructure
- [x] No `replace` directives in go.mod
- [x] No `bin/` directory present
- [x] All exported interfaces well-documented
- [x] Proper use of typed context keys (except base_repository)

### Cross-Service Impact
- [x] **All 21 Go services depend on common** — changes here affect everything
- [x] No proto files in common (API stability: N/A)
- [x] No event publishing from common (Event compatibility: N/A)
- [x] Module graph: common has 0 internal dependencies (true leaf)
- [x] Latest version v1.23.1 tagged at HEAD — no uncommitted changes

### Lint & Build
- [x] `golangci-lint run`: ✅ 0 warnings
- [x] `go build ./...`: ✅ clean
- [x] `go test ./...`: ✅ all 31 packages pass

### Test Coverage

| Package | Coverage | Target | Status |
|---------|----------|--------|--------|
| repository | 77.4% | 60% | ✅ |
| registry | 96.9% | 60% | ✅ |
| security | 83.3% | 60% | ✅ |
| utils/address | 85.0% | 60% | ✅ |
| utils/pointer | 100.0% | 60% | ✅ |
| utils/time | 100.0% | 60% | ✅ |
| utils/slice | 82.1% | 60% | ✅ |
| utils/uuid | 78.6% | 60% | ✅ |
| utils/http | 78.4% | 60% | ✅ |
| utils/json | 77.8% | 60% | ✅ |
| utils/crypto | 70.1% | 60% | ✅ |
| validation | 62.4% | 60% | ✅ |
| utils/observer | 60.0% | 60% | ✅ |
| utils/retry | 58.0% | 60% | ⚠️ Close |
| worker | 55.6% | 60% | ⚠️ |
| grpc | 53.0% | 60% | ⚠️ |
| utils/strings | 51.9% | 60% | ⚠️ |
| security/pii | 48.9% | 60% | ⚠️ |
| errors | 47.5% | 60% | ⚠️ |
| events | 47.7% | 60% | ⚠️ |
| utils/cache | 45.0% | 60% | ⚠️ |
| utils/pagination | 44.7% | 60% | ⚠️ |
| utils/idempotency | 44.9% | 60% | ⚠️ |
| utils/database | 37.6% | 60% | ⚠️ |
| utils/metadata | 33.9% | 60% | ⚠️ |
| utils/math | 19.5% | 60% | ⚠️ |
| middleware | 18.0% | 60% | ⚠️ |
| config | 15.7% | 60% | ⚠️ |
| utils/ctx | 15.0% | 60% | ⚠️ |
| client | 14.5% | 60% | ⚠️ |
| outbox | 8.3% | 60% | ⚠️ |

**Overall**: 13/31 packages above 60% target. Key infrastructure packages (middleware, outbox, client, config) are below target but not blocking for release.

### Documentation
- [x] README.md: 63 lines, proper structure
- [x] CHANGELOG.md: 190 lines, comprehensive
- [x] CODEBASE.md: 118 lines, package index

### Deployment Readiness
- [x] Common is a library — no deployment/GitOps/ports needed
- [x] HEAD = v1.23.1 tag — no new changes to tag

---

## 🚀 Action Items for Other Agents

| Agent | Action | Priority |
|-------|--------|----------|
| Agent 2 | Update auth, customer, payment to common@v1.23.1 (already done) | ✅ Done |
| Agent 3 | Update pricing, catalog, warehouse to common@v1.23.1 (already done) | ✅ Done |
| Agent 4 | **Update fulfillment** to common@v1.23.1 (currently v1.22.0 — 2 versions behind) | P1 |
| Agent 5 | Update search, loyalty-rewards, common-operations to common@v1.23.1 | P1 |
| Agent 1 | Update notification, user to common@v1.23.1 | P1 |

---

*Common package review complete. No P0 blockers. HEAD is tagged v1.23.1 — agents can proceed with service reviews.*

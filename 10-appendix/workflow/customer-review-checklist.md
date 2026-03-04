## 🔍 Service Review: customer

**Date**: 2026-03-04
**Reviewer**: AI Service Review
**Status**: ⚠️ Needs Minor Work (P1 config issue + P2 items)

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | — |
| P1 (High) | 2 | 1 Fixed / 1 Remaining |
| P2 (Normal) | 4 | 3 Fixed / 1 Remaining |

---

### 🔴 P0 Issues (Blocking)
*(None — all previous P0s have been fixed)*

---

### 🟡 P1 Issues (High)

1. ~~**[CONFIG]** `configs/config.yaml:89-91` — **Self-referencing `catalog_service` endpoint**~~ ✅ **FIXED**: Changed to `http://localhost:8015` (catalog's correct port per PORT_ALLOCATION_STANDARD.md). Also removed stale `cart_service` reference.

2. **[COVERAGE]** `internal/service/` — **Service layer test coverage is 0%**: All gRPC handler tests are missing for the service layer. The biz layer has healthy coverage (64-82%), but the service layer has zero test coverage. Target is ≥60%.
   - **Fix**: Add service layer unit tests (not blocking release, but should be prioritized)

---

### 🔵 P2 Issues (Normal)

1. ~~**[CONFIG]** `configs/config.yaml:92-94` — **Stale `cart_service` reference**~~ ✅ **FIXED**: Removed the `cart_service` section (fixed together with P1 #1).

2. ~~**[DOCS]** `README.md:6,70-72` — **Outdated dependency versions**~~ ✅ **FIXED**: Updated README to reflect `v1.2.5`, `common v1.23.0`, `notification v1.1.8`, `order v1.1.9`, `payment v1.2.5`.

3. ~~**[OBSERVABILITY]** `internal/biz/customer/customer.go` — **Discarded parallel fetch results in `GetCustomerWithDetails`**~~ ✅ **FIXED**: Removed unused parallel profile/preferences goroutines. GORM preloading in `FindByID` already loads all relations in a single call.

4. **[STYLE]** `internal/service/management.go:35,46,49,174,204` — **Excessive debug logging in production code**: Multiple `Infof` calls logging raw request fields, enum values, and conversion details. These are development-time debug logs that increase noise in production.
   - **Fix**: Downgrade to `Debugf` or remove

---

### ✅ Previously Completed Actions (from prior review 2026-03-03)
1. ✅ Dapr event bus migration to worker-based gRPC consumers
2. ✅ Transactional outbox pattern standardized with `common/outbox`
3. ✅ Cascading soft-deletes (Customer → Profile → Preferences)
4. ✅ AuthClient session revocation on delete/suspend
5. ✅ Repository decoupling verified — all repos use domain types
6. ✅ Segment pagination migrated to cursor-based
7. ✅ Port alignment (HTTP: 8003, gRPC: 9003) with GitOps
8. ✅ No `replace` directives in `go.mod`
9. ✅ `bin/` directory clean

---

### 🔧 Action Plan

| # | Severity | Issue | File:Line | Fix Description | Status |
|---|----------|-------|-----------|-----------------|--------|
| 1 | P1 | Self-referencing catalog endpoint | `configs/config.yaml:89-91` | Changed to `http://localhost:8015` + removed cart_service | ✅ Done |
| 2 | P1 | Service layer 0% coverage | `internal/service/` | Add gRPC handler unit tests | ⬜ TODO |
| 3 | P2 | Stale cart_service config | `configs/config.yaml:92-94` | Removed (done with #1) | ✅ Done |
| 4 | P2 | Outdated README versions | `README.md:6,70-72` | Updated to match go.mod | ✅ Done |
| 5 | P2 | Discarded parallel fetch | `internal/biz/customer/customer.go` | Removed unused goroutines, simplified to single call | ✅ Done |
| 6 | P2 | Debug logs in production | `internal/service/management.go` | Downgrade to Debugf | ⬜ TODO |

---

### 📈 Test Coverage

| Layer | Coverage | Target | Status |
|-------|----------|--------|--------|
| Biz/address | 65.6% | 60% | ✅ |
| Biz/analytics | 73.8% | 60% | ✅ |
| Biz/audit | 68.8% | 60% | ✅ |
| Biz/customer | 68.3% | 60% | ✅ |
| Biz/customer_group | 82.3% | 60% | ✅ |
| Biz/preference | 68.0% | 60% | ✅ |
| Biz/segment | 64.8% | 60% | ✅ |
| Biz/wishlist | 68.4% | 60% | ✅ |
| Service | 0.0% | 60% | ❌ |
| Data | — | 60% | ⚠️ Not measured |

**Biz layer overall**: ✅ All packages above 60% target
**Service layer**: ❌ 0% — needs attention

---

### 🌐 Cross-Service Impact

- **Services that import this proto**: `auth`, `catalog`, `checkout`, `common-operations`, `gateway`, `loyalty-rewards`, `order`, `payment`, `pricing`, `promotion` (10 services)
- **Services that consume customer events**: None detected via topic grep (events consumed via Dapr, routed internally)
- **Backward compatibility**: ✅ Preserved — no proto field removals, no event schema breaks
- **No circular imports**: ✅ Verified

---

### 🚀 Deployment Readiness

| Check | Status | Notes |
|-------|--------|-------|
| Ports match PORT_ALLOCATION_STANDARD | ✅ | HTTP 8003, gRPC 9003 |
| Config/GitOps aligned | ⚠️ | ConfigMap OK, but local config has stale catalog/cart entries |
| Health probes | ✅ | HTTP health endpoints via common components |
| Resource limits | ✅ | Set in `patch-api.yaml` |
| HPA configured | ✅ | `hpa.yaml` present |
| Dapr annotations | ✅ | `app-id: customer`, correct port via kustomize replacements |
| HPA sync-wave | ✅ | Not explicitly set but managed via common-deployment component |
| NetworkPolicy | ✅ | `networkpolicy.yaml` present |
| Migration safety | ✅ | 25 migration files, Goose format |
| No `replace` directives | ✅ | `go.mod` clean |
| No `bin/` artifacts | ✅ | Clean |
| Worker binary | ✅ | Separate `cmd/worker/` with dedicated deployment |

---

### Build Status
- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅ Clean
- `go test ./internal/...`: ✅ All 8 biz packages pass
- `wire`: ✅ Generated for both `cmd/customer/` and `cmd/worker/`
- Generated Files (`wire_gen.go`, `*.pb.go`): ✅ Not modified manually
- `bin/` Files: ✅ Not present

---

### Documentation
- Service doc (`README.md`): ⚠️ Present but versions outdated
- CHANGELOG.md: ✅ Comprehensive, up-to-date with Unreleased section
- Review checklist: ✅ This file

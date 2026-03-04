# 🔍 Service Review: location

**Date**: 2026-03-04
**Reviewer**: AI Agent
**Status**: ✅ Ready (P1 bugs fixed)

---

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | N/A |
| P1 (High) | 4 | All Fixed ✅ |
| P2 (Normal) | 5 | Documented |

---

## 🟡 P1 Issues (High)

### 1. **[DATA/BUG]** `internal/data/postgres/location.go:269-273` — Search applies Limit twice
The `Search()` method first applies `db.Limit(limit)` on line 270, then immediately calls `.Limit(500)` on line 273, which **silently overrides** the user-provided limit with a hardcoded 500. This means the `limit` parameter from the API request is effectively ignored.

**Root Cause**: The safety `.Limit(500)` was added as a backstop but placed after the user-provided limit, overriding it.
**Fix**: Remove the `.Limit(500)` on line 273 since the user limit was already applied. The max is already enforced at the biz layer (usecase caps at `maxPageLimit=100`).

### 2. **[BIZ/CACHE]** `internal/biz/location/location_usecase.go:46-105` — CreateLocation missing cache invalidation for tree
After creating a location, `CreateLocation()` does not invalidate any cache. However, `UpdateLocation()` and `DeleteLocation()` both call `invalidateTreeCache(ctx)`. After a new location is created, cached tree data becomes stale.

**Root Cause**: Missing cache invalidation in `CreateLocation` — was likely overlooked since create was added before caching was fully implemented.
**Fix**: Add cache invalidation after successful create, matching the pattern used in `UpdateLocation`.

### 3. **[DOC/PORTS]** `docs/03-services/platform-services/location-service.md:63-64` — Service docs show WRONG ports
The service documentation says HTTP: 8017, gRPC: 9017, but the correct ports per PORT_ALLOCATION_STANDARD are HTTP: **8007**, gRPC: **9007**. The header line 6 says 8007/9007, but lines 63-64 say 8017/9017 — contradicting itself.

**Root Cause**: Documentation was not updated after the port fix in v1.0.3.
**Fix**: Correct port references to 8007/9007. Also note this doc is in the wrong category (platform-services vs operational-services per skill guide).

### 4. **[DOC/ACCURACY]** `docs/03-services/platform-services/location-service.md` — Service docs describe non-existent APIs
The documentation describes APIs that don't exist in the actual proto: `ValidateAddress`, `GeocodeAddress`, `CalculateDistance`, `EstimateDeliveryTime`, `GetDeliveryZones`, `CheckAddressCoverage`, `GetLocationHierarchy`. These were aspirational and never implemented. The common version shown is `v1.8.3` — actual is `v1.23.1`.

**Root Cause**: Documentation was written ahead of implementation and never updated to reflect actual codebase.
**Fix**: Rewrite service documentation to match actual API surface from `api/location/v1/location.proto`.

---

## 🔵 P2 Issues (Normal)

### 1. **[CODE STYLE]** `internal/biz/location/validator.go:186-195` — Dead code in metadata type switch
The switch on `value.(type)` checks types but has a `default` case that does nothing. The entire switch is effectively a no-op since no validation error is returned for unsupported types.

### 2. **[CODE STYLE]** `internal/data/postgres/db.go:17-18` — Duplicate comment
Line 17 and 18 have identical comments: `// NewDBConnectionFromConfig creates a new database connection from config`.

### 3. **[ARCH]** `internal/client/service_clients.go` — ServiceClients not used
The `ServiceClients` struct is defined and constructor implemented, but it's not wired into the main app or worker. Not registered in any Wire ProviderSet. This is dead code.

### 4. **[DOC/CATEGORY]** Service doc is in `platform-services/` but skill guide says it should be in `operational-services/`.

### 5. **[DOC/VERSION]** `internal/biz/biz.go:52` — Version hardcoded as `v1.0.0`
The `ServiceInfo` returns a hardcoded `v1.0.0` version. The service layer has its own `Version` variable set at `v1.0.5`. There's version mismatch between `biz.go`, `service/location.go`, `server/http.go`, and `cmd/location/main.go`.

---

## 🔧 Action Plan

### P1 Fixes (implement now)

| # | Issue | File:Line | Root Cause | Fix Description | Status |
|---|-------|-----------|------------|-----------------|--------|
| 1 | Search double Limit | `data/postgres/location.go:273` | Hardcoded `.Limit(500)` overrides user limit | Remove the second `.Limit(500)` | ✅ Done |
| 2 | CreateLocation missing cache invalidation | `biz/location/location_usecase.go:100` | No tree cache invalidation after create | Add `invalidateTreeCache` after commit | ✅ Done |
| 3 | Service docs wrong ports | `docs/03-services/platform-services/location-service.md` | Stale documentation | Update to match actual implementation | ✅ Done |
| 4 | Service docs non-existent APIs | `docs/03-services/platform-services/location-service.md` | Aspirational docs | Rewrite to reflect actual proto | ✅ Done |

### P2 Notes (documented only)

| # | Issue | File:Line | Description |
|---|-------|-----------|-------------|
| 1 | Dead switch in validator | `biz/location/validator.go:186` | Type switch does nothing |
| 2 | Duplicate comment | `data/postgres/db.go:17-18` | Identical comments |
| 3 | Unused ServiceClients | `client/service_clients.go` | Not wired to app |
| 4 | Wrong doc category | `docs/03-services/` | platform-services → operational-services |
| 5 | Version mismatch | Multiple files | Hardcoded versions differ across layers |

---

## 📈 Test Coverage

| Layer | Coverage | Target | Status |
|-------|----------|--------|--------|
| Biz (location) | 62.2% | 60% | ✅ Above target |
| Service | 65.3% | 60% | ✅ Above target |
| Data (postgres) | 65.1% | 60% | ✅ Above target |
| Biz (root) | 0.0% | 60% | ⚠️ No tests for biz.go |

Coverage checklist updated: ⬜ (will update after fixes)

---

## 🌐 Cross-Service Impact

- **Services that import this proto**: `gateway`, `warehouse`
- **Services that consume events**: None found
- **Backward compatibility**: ✅ Preserved — no proto field changes
- **No `replace` directives**: ✅ Confirmed clean

---

## 🚀 Deployment Readiness

- Config/GitOps aligned: ✅ Ports 8007/9007 match across config.yaml ↔ kustomization.yaml ↔ PORT_ALLOCATION_STANDARD
- Health probes: ✅ `/health`, `/health/ready`, `/health/live`, `/health/detailed`
- Resource limits: ✅ API: 128Mi-512Mi, 100m-500m | Worker: 128Mi-256Mi, 50m-200m
- HPA: ✅ 2-4 replicas, sync-wave=4 (Deployment wave=2, Worker wave=3)
- Dapr annotations: ✅ `app-id=location`, `app-port` derived from Service
- Migration: ✅ PreSync hook with migration-job.yaml
- NetworkPolicy: ✅ Present
- PDB: ✅ Present for both API and Worker

---

## Build Status

- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅ Success
- `wire`: ✅ Generated (wire_gen.go exists for both binaries)
- Generated Files (`wire_gen.go`, `*.pb.go`): ✅ Not modified manually
- `bin/` Files: ✅ Not present (clean)

---

## Documentation

- Service doc: ✅ Rewritten to match actual implementation (moved to `operational-services/`)
- README.md: ✅ Accurate and comprehensive
- CHANGELOG.md: ✅ Up to date (latest: 1.0.8 - 2026-03-03)

---

## GitOps Note

- ⚠️ `kustomization.yaml:12` has a trailing `\r` on the `dapr-pubsub.yaml` line (`dapr-pubsub.yaml\r`). This is a cosmetic issue but could cause problems in strict YAML parsers.

# Location Service Review Checklist

**Date**: 2026-02-28
**Reviewer**: AI Review
**Version**: v1.0.6 (commit 5b95cca)

## P0 Issues (Blocking)

1. **[SECURITY] SQL injection in List sort** — `internal/data/postgres/location.go:109` — `sortBy` and `sortOrder` from the gRPC request were concatenated directly into GORM `.Order()` clause without validation. An attacker could inject arbitrary SQL. **→ Fixed: Added column allowlist and strict sort direction validation.**

## P1 Issues (High)

1. **[HYGIENE] Compiled binaries in repo root** — `location` (42MB), `worker` (33MB), `migrate` (10MB) ELF binaries were present in the repo root. Not git-tracked (`.gitignore` covers them) but waste disk. **→ Fixed: Deleted.**
2. **[ARCHITECTURE] Outbox migration to common lib** — Custom outbox implementation (`outbox.go`, `outbox_adapter.go`) was replaced with `common/outbox.GormRepository` from conversation `8ff5d851`. **→ Fixed: Committed.**

## P2 Issues (Normal)

1. **[DOCS] CHANGELOG** — Updated with v1.0.6 entry. **→ Fixed.**
2. **[NAMING] `.gitignore`** — `worker` appears twice (with and without path prefix), minor inconsistency. Non-blocking.

## Completed Actions

1. ✅ Pulled latest code for `location`, `common`, and `gitops`
2. ✅ Verified zero `golangci-lint` warnings
3. ✅ Verified `go build ./...` passes
4. ✅ Verified `go test ./...` — 3/3 test packages pass
5. ✅ Verified `wire` regenerates for both `cmd/location` and `cmd/worker`
6. ✅ Verified no `replace` directives in `go.mod`
7. ✅ Verified `common` at latest (`v1.17.0`)
8. ✅ Deleted compiled binaries (`location`, `worker`, `migrate`) from repo root
9. ✅ Committed outbox migration + proto updates + new migrations
10. ✅ Updated CHANGELOG.md with v1.0.6
11. ✅ Fixed P0 SQL injection in List sort — added column allowlist validation

## Verification Results

| Check | Status |
|-------|--------|
| `golangci-lint run` | ✅ 0 warnings |
| `go build ./...` | ✅ Pass |
| `go test ./...` | ✅ 3/3 packages pass |
| `wire` (location) | ✅ Generated |
| `wire` (worker) | ✅ Generated |
| No `replace` directives | ✅ Clean |
| `common` version | ✅ v1.17.0 (latest) |
| No `bin/` directory | ✅ Clean |
| Compiled binaries removed | ✅ |

## Cross-Service Impact

| Item | Status |
|------|--------|
| Proto consumers | `gateway` (v1.0.4), `warehouse` (v1.0.4) |
| Event schema | Additive only (outbox now uses common structure) |
| Backward compatibility | ✅ Preserved |

## Deployment Readiness

| Check | Status |
|-------|--------|
| Ports match PORT_ALLOCATION_STANDARD | ✅ HTTP=8007, gRPC=9007 |
| Config/GitOps aligned | ✅ |
| Health probes | ✅ /health/live, /health/ready on port 8007 |
| Worker health | ✅ /healthz on port 8081 |
| Resource limits | ✅ Server: 128Mi-512Mi / 100m-500m |
| Worker resources | ✅ 128Mi-256Mi / 50m-200m |
| Dapr annotations | ✅ app-id=location, app-port=8007 |
| HPA | ✅ 2-5 replicas, wave=3 (Deployment wave=2) |
| Worker deployment | ✅ Separate deployment with init containers |

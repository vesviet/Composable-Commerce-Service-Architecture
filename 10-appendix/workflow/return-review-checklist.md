# Return Service — Review Checklist

**Date**: 2026-02-23
**Reviewer**: AI Senior Engineer
**Status**: ✅ Ready for Release

---

## Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | — |
| P1 (High) | 3 | ✅ All Fixed |
| P2 (Normal) | 0 | — |

---

## ✅ P1 Issues Fixed

### 1. [RELIABILITY] `internal/biz/return/return.go` — Status transition not enforced
`UpdateReturnRequestStatus` allowed any status → any status jump (e.g., `pending → completed`), bypassing approval and processing steps.

**Fix**: Added `isValidStatusTransition` guard at the top of `UpdateReturnRequestStatus` before any mutation. Returns `ErrInvalidReturnStatus` on illegal transitions.

### 2. [DATA INTEGRITY] `internal/biz/return/return.go` — Non-atomic status + outbox save
`returnRequestRepo.Save` and `outboxRepo.Save` executed in separate operations. A crash between the two left the DB with a committed new status but no outbox event, causing silent event loss.

**Fix**: Wrapped both operations in `uc.tm.WithTransaction`. If the transaction fails, a direct Dapr publish is attempted as a last resort so the event is not silently dropped.

### 3. [SECURITY] `internal/middleware/auth.go` — Context key type mismatch
`GetUserID`, `GetUserEmail`, `GetUserRole`, `RequireAdmin`, and `RequireRole` all used bare string literals for `ctx.Value` lookups (e.g., `ctx.Value("user_id")`). Because `Auth()` stores values under typed `contextKey` constants, all lookups returned `nil` — meaning customer-ID enforcement in `CreateReturnRequest` never actually worked.

**Fix**: All extractor functions and middleware now use the correctly typed `contextKey` constants (`userIDKey`, `userEmailKey`, `userRoleKey`).

---

## Cross-Service Impact

- **Proto consumers**: No service imports `gitlab.com/ta-microservices/return` (return service is only imported by none — confirmed via `go.mod` grep). No downstream breakage.
- **Event consumers**: Events are additive-only changes. No topic renames. Consumers handle gracefully.
- **Backward compatibility**: ✅ Preserved — no proto field removals, no RPC renames

---

## Deployment Readiness

- Ports match PORT_ALLOCATION_STANDARD.md (HTTP 8013, gRPC 9013): ✅
- `config.yaml` addr ↔ `deployment.yaml` containerPort ↔ `service.yaml` targetPort ↔ `dapr.io/app-port` ↔ health probes: ✅ All 8013
- Resource limits set: ✅ (128Mi–512Mi, 100m–500m)
- Health probes configured (liveness + readiness on 8013): ✅
- Dapr annotations (`app-id: return`, `app-port: 8013`, `app-protocol: http`): ✅
- Migration strategy: additive-only migrations, zero-downtime safe: ✅
- HPA: ⚠️ Not configured (no `hpa.yaml`) — acceptable for current load, revisit at scale

---

## Build Status

- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅
- `wire`: ✅ Not regenerated (no DI changes)
- Generated files (`wire_gen.go`, `*.pb.go`): ✅ Not manually modified
- `bin/` files: ✅ Removed
- `common` upgraded: v1.12.0 → v1.16.0 ✅

---

## Documentation

- Service doc (`docs/03-services/operational-services/return-service.md`): ✅ Created
- CHANGELOG.md: ✅ Updated (RET-P1-03, RET-P1-04, RET-P1-05, common upgrade)
- README.md: ✅ Exists and accurate

---

## Remaining / Known Items

- **Item-level return policy**: `CheckReturnEligibility` marks all items as eligible by default (no per-category policy). Business logic for hygiene products, final-sale items, etc. is a future enhancement.
- **HPA**: No autoscaling configured. Sufficient for current traffic; add HPA when service becomes high-traffic.
- **Exchange price difference**: `PriceDifference` in exchange events is hardcoded to `0`. Requires Pricing service integration for accurate billing on upsell exchanges.

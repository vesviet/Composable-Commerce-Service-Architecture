## 🔍 Service Review: shipping

**Date**: 2026-03-03
**Status**: ⚠️ Issues Found (P1, P2)

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | Fixed / Remaining |
| P1 (High) | 1 | 0 Fixed / 1 Remaining |
| P2 (Normal) | 1 | 0 Fixed / 1 Remaining |

### 🔴 P0 Issues (Blocking)
*(None)*

### 🟡 P1 Issues (High)
1.  **[Architecture] Domain Leakage in `biz` Layer**: 
    - `internal/biz/carrier/carrier.go` and `internal/biz/shipping_method/shipping_method.go` directly depend on `internal/model` (GORM models).
    - Their `Usecase` and `Repository` interfaces use `*model.Carrier` and `*model.ShippingMethod` instead of pure domain entities.
    - This violates Clean Architecture/DDD principles where the Domain layer must be decoupled from the Data layer.

### 🔵 P2 Issues (Normal)
1.  **[Architecture] Redundant Placeholder Code**: 
    - `internal/biz/shipment/shipment.go` contains empty `ToModel` and `FromModel` placeholder functions.
    - It also imports `internal/model` unnecessarily. 
    - Repository mapping is already correctly implemented in `internal/data/postgres/shipment.go`.

### ✅ Completed Actions
1. Verified `common` library is at `v1.23.0`.
2. Executed `golangci-lint`, `go build ./...`, and `go test ./...` — all passed successfully.
3. Verified port alignment (`HTTP: 8012`, `GRPC: 9012`) with project standards.
4. Confirmed transactional outbox pattern implementation and worker processing.
5. Verified cursor-based pagination is implemented in `List` methods for shipments, carriers, and shipping methods.
6. Verified PostgreSQL advisory locking (`AcquireShipmentLock`) for concurrency control in shipment updates.

### 🌐 Cross-Service Impact
- Services that call shipping: `order`, `fulfillment`, `checkout`.
- Events published: `packages.package.status_changed`.
- Backward compatibility: ✅ Preserved (internal refactoring won't affect proto/API layer).

### 🚀 Deployment Readiness
- Config/GitOps aligned: ✅ 
- Health probes: ✅ (Common health endpoints registered)
- Resource limits: ✅ (Standard limits followed)
- Migration safety: ✅ (Schema verified)

### Build Status
- `golangci-lint`: ✅ Passed
- `go build ./...`: ✅ Passed
- `go test ./...`: ✅ Passed
- `wire`: ✅ Generated

### Documentation
- Service doc: ✅ `README.md` updated
- CHANGELOG.md: ✅ Up-to-date

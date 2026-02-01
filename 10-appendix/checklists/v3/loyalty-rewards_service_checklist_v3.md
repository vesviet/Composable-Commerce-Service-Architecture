# Loyalty-Rewards Service Code Review Checklist v3

**Service**: loyalty-rewards
**Version**: (see go.mod)
**Review Date**: 2026-02-01
**Last Updated**: 2026-02-01
**Reviewer**: AI Code Review Agent
**Status**: 🔴 BLOCKED (P0 Issues Present)

---

## Executive Summary

The loyalty-rewards service implements the structure for points system, tier management, rewards catalog, etc. However, **critical business logic is disconnected from the service layer**, and many service methods are **unimplemented (returning empty responses)**. The codebase requires significant refactoring to connect the Service layer to the implemented UseCases in `internal/biz/*`.

**Overall Assessment:** 🔴 BLOCKED
- **Strengths:** Directory structure follows Clean Architecture.
- **Critical Issues:** `LoyaltyService` methods are unimplemented stub implementations. The Service uses empty "legacy" UseCase definitions instead of the actual domain logic.

---

## 1. Index & Review (Standards Applied)

### 1.1 Codebase Index
- **Directory:** `loyalty-rewards/`
- **Layout:** Standard Kratos layout. `internal/biz` is split into sub-domains but not correctly integrated.
- **Service Layer:** `internal/service/loyalty.go` contains mostly empty methods.
- **Biz Layer:** `internal/biz` contains empty "legacy" structs (`RewardsUsecase`, `TierUsecase`) which shadows the real logic in `internal/biz/reward`, `internal/biz/tier`.

### 1.2 P0 / P1 / P2 Issues

| Severity | ID / Location | Description |
|----------|----------------|-------------|
| **🚨 P0** | `internal/service/loyalty.go` | **Unimplemented Methods**: methods like `GetRewards`, `RedeemReward`, `GetTiers` return empty/nil responses. |
| **🚨 P0** | `internal/service` | **Disconnected Logic**: Service injects empty wrapper UseCases from `biz` package instead of real logic from `biz/reward`, etc. |
| **🟡 P1** | `internal/biz/loyalty.go` | **Dead Code**: formatting suggests these were intended as wrappers but are unimplemented. |
| **🟡 P1** | `internal/biz/loyalty_providers.go` | **Legacy Adapters**: Unnecessary complexity with adapters. Service should use new interfaces directly. |
| **🔵 P2** | `go.mod` | **Fixed**: Dependencies updated, replace directives removed. |

---

## 2. Checklist & Todo for Loyalty-Rewards Service

- [ ] **Fix P0**: Implement `LoyaltyService` methods to call actual logic.
- [ ] **Fix P0**: Refactor `LoyaltyService` dependencies to use `internal/biz/{domain}` UseCases.
- [ ] **Fix P1**: Remove empty Legacy UseCase definitions and Adapters.
- [x] **Dependencies**: Replace removed; `go get` run. (Updated 2026-02-01)
- [x] **Lint**: `golangci-lint` passing (after vendor sync).
- [x] **Build**: `make api`, `make wire`, `go build` passing.

---

## 3. Dependencies

- **Current Status**: Updated to latest versions. `vendor` directory synced.

---

## 4. Docs

- **Service Doc**: Needs update to reflect "In Progress" status due to P0 issues.
- **README**: Needs update.

---

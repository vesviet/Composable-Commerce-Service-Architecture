# Customer Service - Code Review Checklist v3

**Service**: Customer Service
**Version**: v1.1.4
**Last Updated**: 2026-02-04
**Review Date**: 2026-02-04
**Reviewer**: AI Code Review Agent (service-review-release-prompt)
**Status**: 🔄 IN REVIEW

---

## 🔴 CRITICAL PRIORITY (P0 - Blocking Production)

### [P0-1] Dependency Management
**Status**: ⏳ IN PROGRESS
**Description**: Update gitlab.com/ta-microservices dependencies to latest versions
- Current: common v1.8.8, auth v1.0.4, notification v1.1.0, order v1.0.4, payment v1.0.0
- Action: Run `go get gitlab.com/ta-microservices/common@latest` etc.

### [P0-2] Consul Configuration
**Status**: ✅ VERIFIED
**Description**: Consul address reads from environment variable
- Location: `internal/server/consul.go`
- Implementation: Checks `CONSUL_ADDR` env var with fallback to config file
- Priority: Environment variable > config file > default (localhost:8500)
- Logging: Properly logs when using environment variable

### [P0-3] Lint Compliance
**Status**: ⏳ PENDING
**Description**: Ensure zero golangci-lint warnings

### [P0-4] API Generation
**Status**: ⏳ PENDING
**Description**: Regenerate protobuf files with latest dependencies

## 🟡 HIGH PRIORITY (P1 - Should Fix Soon)

### [P1-1] Deprecated gRPC Method
**Status**: ✅ COMPLETED
**Release**: v1.0.4

### [P1-2] Deprecated Proto Message
**Status**: ✅ COMPLETED
**Release**: v1.0.6
**Description**: Replaced deprecated `pb.Address` with `api.common.v1.Address` in `internal/model/address.go`.

## 🟢 MEDIUM PRIORITY (P2 - Nice to Fix)

### [P2-1] Unused Function
**Status**: ✅ COMPLETED
**Release**: v1.0.4

## 📋 TODO ITEMS IDENTIFIED

### Implementation TODOs
**Status**: ✅ IMPLEMENTED
**Location**: Various files

1.  **Payment Client Integration**
    - **Status**: ✅ COMPLETED
    - **Note**: Updated Payment Client to use string IDs, aligning with Payment Service v1.0.7 changes.

2.  **Order Client Integration**
    - **Status**: ⏳ BLOCKED
    - **Note**: `AnonymizeCustomerOrders` requires update to Order Service (API version mismatch).

3.  **Segment Re-evaluation & stats**
    - **Status**: ✅ COMPLETED
    - **Details**: 
        - Updated `rules_engine.go` to use `TotalOrders`, `TotalSpent`, `LastOrderAt`, `LastLoginAt`.
        - Implemented `EvaluateCustomerSegments` in `segment.go`.

4.  **Data Consistency & Stats Updates**
    - **Status**: ✅ COMPLETED
    - **Details**:
        - Updated `AuthConsumer` & `OrderConsumer` to call `CustomerUsecase` update methods.
        - Updated `EventHandler` to sync stats.
        - Fixed `DeleteSegment` logic (relying on CASCADE).

## 🔄 NEXT STEPS

1.  **Deploy v1.0.5**: With stats updates and consumer fixes.
2.  **API Refactoring (v1.1.0)**: Address `pb.Address` deprecation.
3.  **Cross-Service Sync**: Coordinate with Payment/Order teams on ID/API issues.

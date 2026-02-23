# Order Service - TODO List & Technical Debt

**Last Updated**: January 29, 2026
**Status**: 🟡 In Progress

---

## 🚩 High Priority (P1)

- [ ] **[ORDER-007]**: Fix dependencies in `cmd/worker/wire.go`.
  - **Description**: The `orderCleanupJob` is currently commented out in the worker wire configuration.
  - **Required Action**: Solve dependency injection for cleanup job and enable it.
  - **Reference**: `order/cmd/worker/wire.go:60`

- [ ] **[ORDER-012]**: Implement full test suite for Order Create.
  - **Description**: `create_test.go` lacks comprehensive tests because proper use case interfaces were not fully defined at the time.
  - **Required Action**: Define proper interfaces and implement table-driven tests for all creation scenarios (success, various failures, idempotency).
  - **Reference**: `order/internal/biz/order/create_test.go:14`

- [ ] **[CRON-001]**: Fix OrderUseCase dependencies in worker cron.
  - **Description**: `OrderUseCase` dependencies are broken in the cron worker due to missing `order.*Service` adapters.
  - **Required Action**: Implement the necessary adapters and fix the wire injection.
  - **Reference**: `order/internal/worker/cron/wire.go:13`

---

## 🟡 Medium Priority (P2)

- [ ] **[DEP-001]**: Cross-Service CustomerID Type Alignment.
  - **Description**: Order service uses UUID (string) for `customer_id`, but Payment Service gRPC proto still expects `int64`.
  - **Current Workaround**: Manual parsing in `payment_grpc_client.go`.
  - **Goal**: Align all services to use UUID strings for customer identifiers.

---

## ✅ Completed (Recently)

- [x] **[DEP-002]**: Fixed `OrderId` type mismatch in Payment gRPC client.
  - **Status**: Completed Jan 29, 2026.
  - **Fix**: Updated `payment_grpc_client.go` to pass `OrderId` as string to match updated `payment.proto`.

- [x] **[DEP-003]**: Dependency Version Sync.
  - **Status**: Completed Jan 29, 2026.
  - **Fix**: Updated project dependencies to latest tags from `gitlab.com/ta-microservices`.

# 📅 QA Integration Test Execution Plan

> **Based on**: `docs/10-appendix/checklists/v5/qa-integration-test-checklist.md` (v5.3)
> **Goal**: Achieve 100% coverage of P0 and P1 cross-service flows.
> **Strategy**: Implement integration tests using project standards (`testify`, table-driven, strict mocking).

## 1. Strategy & Standards

Following `write-tests` skill and project rules:

### 1.1 Test Location
- **Integration Tests**: Place in `<service>/test/integration/`.
- **Naming**: Files named `*_test.go` (e.g., `checkout_saga_test.go`).
- **Package**: `integration_test` (or `integration`) to avoid circular deps, or usage of `_test` package.

### 1.2 Testing Pattern
- **Framework**: `testify/require` for setup, `testify/assert` for assertions.
- **Pattern**: 
  - **Arrange**: Setup data, mocks, and dependency injection.
  - **Act**: Execute the business logic (UseCase or gRPC handler).
  - **Assert**: Verify output, side effects (mocks called), and state changes.
- **Mocks**: 
  - Use **manual mocks** from `internal/biz/mocks.go` where possible.
  - For external services (gRPC), use `mock.Mock` or verified fakes if available.
  - **Strictness**: Always `mock.AssertExpectations(t)`.

### 1.3 Data Management
- Use factory functions for request payloads (don't hardcode JSON everywhere).
- Clean up resources (defer teardown) for any real DB interactions.

---

## 2. Execution Phases

### 🔴 Phase 1: P0 Critical Sagas (High Risk)
Focus on money-moving and core order flows.

| ID | Suite | Target Service | Scenarios | Complexity |
|----|-------|----------------|-----------|------------|
| 1.1 | **Checkout Saga** | `checkout` | Success, Payment Fail, Inventory Fail, Compensation | High |
| 1.2 | **Payment Capture** | `order` (worker) | Retry logic, Idempotency, DLQ handling | Medium |
| 1.3 | **Order Cancellation** | `order` | Multi-service compensation (Loyalty, Promo, Stock) | High |
| 1.4 | **Fulfillment Flow** | `fulfillment` | Order Paid -> Fulfillment -> Shipping | Medium |
| 1.5 | **Return Flow** | `return` | Approval, Refund, Restock, Label gen | High |

### 🟡 Phase 2: Event Contracts (System Integrity)
Verify that messages on the bus match strict schemas.

| ID | Suite | Target Service | Scenarios | Complexity |
|----|-------|----------------|-----------|------------|
| 2.1 | **Order Events** | `order` | `confirmed`, `paid`, `cancelled`, `completed` | Low |
| 2.2 | **Payment Events** | `payment` | `confirmed`, `failed` | Low |
| 2.3 | **Logistics Events** | `fulfillment`, `shipping` | `fulfillment.completed`, `shipping.*` | Low |
| 2.4 | **Inventory Events** | `warehouse` | `stock.updated` (strict schema check) | Low |

### 🟡 Phase 3: gRPC Client Integration
Verify client mapping and error handling.

| ID | Suite | Target Service | Scenarios | Complexity |
|----|-------|----------------|-----------|------------|
| 3.1 | **Checkout Clients** | `checkout` | Catalog, Pricing, Promo, WH, Payment clients | Medium |
| 3.2 | **Order Clients** | `order` | Payment, WH, Notification clients | Medium |
| 3.3 | **Search Clients** | `search` | Catalog, Pricing, WH clients | Low |

---

## 3. Detailed Task List

### Task 1: Setup Integration Test Foundation
- [ ] Create `test/integration` folder in `checkout` service foundation.
- [ ] Create shared test helpers (payload factories) if needed.
- [ ] Verify `internal/biz/mocks.go` exists for `Checkout` dependencies.

### Task 2: Implement Checkout Saga Tests (P0)
**File**: `checkout/test/integration/saga_test.go`
- [ ] `TestCheckoutSaga_AllSucceed`
- [ ] `TestCheckoutSaga_PaymentAuthFails` (Verify rollback)
- [ ] `TestCheckoutSaga_StockReservationFails` (Verify abort)
- [ ] `TestCheckoutSaga_ConcurrentDuplicate` (Redis lock check)

### Task 3: Implement Payment Capture Tests (P0)
**File**: `order/test/integration/payment_capture_test.go`
- [ ] `TestCaptureRetry_Success`
- [ ] `TestCaptureRetry_Backoff` (Simulate failures)
- [ ] `TestCaptureRetry_DLQ` (Max retries)

### Task 4: Implement Order Cancellation Tests (P0)
**File**: `order/test/integration/cancellation_test.go`
- [ ] `TestCancelOrder_Orchestration` (Stock release, Loyalty refund)
- [ ] `TestCancelOrder_RefundInitiated`

### Task 5: Implement Fulfillment & Shipping Tests (P0)
**File**: `fulfillment/test/integration/flow_test.go`
- [ ] `TestOrderPaid_CreatesFulfillment`
- [ ] `TestFulfillmentCompleted_EmitsEvent`

### Task 6: Implement Return Flow Tests (P0)
**File**: `return/test/integration/return_flow_test.go`
- [ ] `TestReturn_FullCycle` (Request -> Approve -> Refund -> Restock)

---

## 4. Definition of Done
- All P0 tests implemented and passing.
- CI pipeline runs integration tests (`go test -tags=integration ./...` or similar).
- `qa-integration-test-checklist.md` updated with `[x]` and passing status.

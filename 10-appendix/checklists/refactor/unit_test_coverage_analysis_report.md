# 📋 Architectural Analysis & Refactoring Report: Unit Test Coverage & Mocking Strategies

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Quality Assurance, Test-Driven Architecture & Domain Coverage  

---

## 🎯 Executive Summary
Robust unit test coverage is non-negotiable for enterprise e-commerce platforms processing financial data (Orders, Payments, Refunds). A major anti-pattern in the current repository is the heavy reliance on massive, manually constructed mock files instead of adopting standardized code-generation tools. 
This report mandates the immediate migration to `go.uber.org/mock/mockgen` for interface mocking and enforces strict coverage minimums for core business transaction pipelines.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

### 1. [🚨 P0] Massive Technical Debt via Manually Hand-Written Mocks
* **Context**: Current testing suites (specifically within the Order and Payment domains) rely on handwritten struct implementations that implement `testify/mock.Mock`. 
  * Examples: `order/internal/biz/mocks.go` contains over **700 lines** of manual mocks (`MockOrderRepo`, `MockOrderItemRepo`, in-memory Maps). `payment_p0_test.go` and `usecase_test.go` exhibit the same anti-pattern.
* **Risk (Lazada standard)**: Handwritten mocks are brittle. A single domain signature change (e.g., adding a context parameter to an interface) breaks hundreds of lines of test code. This discouraging maintenance overhead causes developers to abandon writing tests.
* **Action Required**: 
  - **BAN** the manual creation of large interface mocks.
  - Implement automated mocking using `go.uber.org/mock/mockgen`.
  - Add `//go:generate mockgen -destination=mocks/mock_<name>.go -package=mocks . <InterfaceName>` commands at the top of every repository and client interface definition in `internal/biz`.

### 2. [🚨 P0] Dangerously Low Test Coverage in Financial Core Domains
* **Context**: A coverage audit (`go test -cover ./internal/biz/...`) reveals that critical state machine operations, such as `order/biz/status` and `payment/biz/refund`, are lacking comprehensive unit tests.
* **Risk (Shopee standard)**: Deploying order status transitions or payment refund flows without strict matrix-tested coverage introduces unacceptable risks of financial calculation errors or stuck orders.
* **Action Required**: 
  - Launch an immediate campaign to backfill unit tests for financial transactions.
  - Minimum coverage requirement for `biz/status`, `biz/refund`, and `biz/checkout` is strictly set to **≥60%**.

### 3. [🟡 P1] Missing Automated CI Coverage Gates
* **Context**: The current GitLab CI pipelines do not block merges based on test coverage drops.
* **Risk**: Technical debt will accumulate as new, untested code gets merged into `main`.
* **Action Required**: 
  - Sub-task: Inject a step into the `gitlab-ci-templates` to enforce a hard coverage floor: `go test -coverprofile=coverage.out ./internal/biz/...`.

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Table-Driven Testing Adherence**: The existing unit tests successfully utilize the Go standard table-driven testing pattern (`tests := []struct{}`). Assertions via `stretchr/testify/assert` are structurally sound, though their underlying mock dependencies (noted above) require replacement.

---

## 📋 Architectural Guidelines & Playbook

### 1. 🏗️ Automated Mock Generation Framework
Do not waste engineering cycles mimicking infrastructure dependencies in tests.
**Anti-Pattern:**
```go
// Creating massive structs manually
type MockOrderRepo struct { mock.Mock }
func (m *MockOrderRepo) Create(ctx context.Context, o *Order) error { ... }
```
**Shopify/Lazada Pattern (Mockgen):**
Every external dependency interface inside the domain (`internal/biz`) must auto-generate its mocks:
```go
//go:generate mockgen -destination=mocks/mock_order_repo.go -package=mocks . OrderRepo
type OrderRepo interface {
    Create(ctx context.Context, order *Order) error
    ListCursor(ctx context.Context, cursor *pagination.CursorRequest) (...)
}
```

### 2. 📊 High-Value Target Coverage
Clean Architecture dictates that `internal/biz` contains the pure, framework-independent business logic. 
- Mocks must strictly isolate the Repo/Data layer.
- Tests must focus entirely on testing domain combinations, status transitions (e.g., `PENDING` -> `PAID`), and failure fallbacks.

# Contract Testing Evaluation: gRPC Mock vs Pact

> **Date**: 2026-03-08
> **Scope**: Order ↔ Warehouse service communication
> **Author**: AGENT-21

---

## Overview

Contract testing verifies that two services (consumer + provider) agree on
the shape and semantics of their shared API without deploying both services.

## Candidates

### Option A: `grpcmock` (bufbuild/connect-grpcmock)

| Aspect | Assessment |
|--------|------------|
| **Language** | Go-native |
| **Approach** | In-process mock gRPC server |
| **Maturity** | Community project, moderate adoption |
| **Fit** | Good for unit-level consumer tests; does NOT verify the provider side |
| **Verdict** | Best for fast, isolated consumer tests — not a true contract test |

### Option B: Pact (pact-go v2)

| Aspect | Assessment |
|--------|------------|
| **Language** | Go via pact-go, Rust core |
| **Approach** | Consumer-driven contracts stored in Pact Broker |
| **Maturity** | Industry standard; strong ecosystem |
| **gRPC support** | Pact Plugin for gRPC/Protobuf (pact-protobuf-plugin) — beta, requires Pact v4 |
| **Fit** | True contract testing with provider verification, but gRPC plugin is still maturing |
| **Verdict** | Best long-term choice if gRPC plugin stabilises; overkill for current 23-service monorepo |

### Option C: Custom contract testing via proto compatibility

| Aspect | Assessment |
|--------|------------|
| **Approach** | Use `buf breaking` to detect proto schema changes; add consumer test stubs |
| **Maturity** | Simple, well-understood |
| **Fit** | Covers 80% of contract breakage (field removal, type change, enum rename) |
| **Verdict** | Pragmatic first step — combine with `grpcmock` for full consumer tests |

## Recommendation

**Phase 1 (Now):** Use `buf breaking` in CI to catch proto schema changes +
`grpcmock` for consumer-side unit tests. This covers the most common
contract regression without adding infrastructure (Pact Broker).

**Phase 2 (Later):** Evaluate Pact v4 gRPC plugin once it reaches GA. Migrate
consumer tests to Pact contracts if the team grows beyond 3 engineers.

## Example: Order → Warehouse contract test

```go
// order/test/contract/warehouse_stock_test.go
func TestOrderService_ReservesStock(t *testing.T) {
    // 1. Start grpcmock server implementing warehouse.StockService
    // 2. Call order.CreateOrder → expect ReserveStock RPC
    // 3. Verify request shape matches warehouse.proto
}
```

This is documented for future implementation when the team is ready.

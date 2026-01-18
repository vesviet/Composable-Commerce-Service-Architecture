# Gateway Service - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Gateway Service, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P2 - Maintainability / Configuration

- **Issue**: The `gateway.yaml` file contains a deprecated `routes` section.
  - **Service**: `gateway`
  - **Location**: `gateway/configs/gateway.yaml`
  - **Impact**: This is a minor maintainability issue. It can cause confusion for new developers who might try to edit the old, non-functional section, as all active routing is handled by the `routing.patterns` section.
  - **Recommendation**: Remove the deprecated `routes` section entirely to make `routing.patterns` the unambiguous single source of truth for all routing logic.

---

## P2 - Resilience

- **Issue**: The retry mechanism for proxying requests uses a basic, fixed delay.
  - **Service**: `gateway`
  - **Location**: `gateway/internal/router/route_manager.go` (`makeRequestWithRetry` function)
  - **Impact**: A fixed delay is not ideal for handling temporarily overloaded backend services. It can contribute to a "thundering herd" problem where all retries happen at once, potentially worsening the backend's condition.
  - **Recommendation**: Implement an exponential backoff with jitter for all retries. This is a standard industry practice that helps to spread out retry attempts and gives a struggling backend service a better chance to recover.

---

## P2 - Maintainability / Architecture

- **Issue**: Middleware application logic is distributed across multiple files.
  - **Service**: `gateway`
  - **Location**: `gateway/internal/router/kratos_router.go` and `gateway/internal/middleware/manager.go`
  - **Impact**: Having logic for assembling and applying middleware chains in both the router and a dedicated manager makes the request lifecycle harder to trace, debug, and modify.
  - **Recommendation**: Consolidate all middleware chain assembly and application logic into the `MiddlewareManager`. The router's responsibility should be simplified to only mapping a URL path to a final, pre-wrapped handler provided by the `MiddlewareManager`.

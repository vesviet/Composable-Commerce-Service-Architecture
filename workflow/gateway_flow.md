# Gateway Service Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code

## Overview

This document describes the request lifecycle within the `gateway` service. The gateway acts as the single entry point for all external traffic, handling routing, authentication, rate limiting, and other cross-cutting concerns before proxying requests to the appropriate downstream microservice.

**Key Files:**
- **Configuration**: `gateway/configs/gateway.yaml`
- **Routing**: `gateway/internal/router/kratos_router.go`
- **Middleware**: `gateway/internal/middleware/manager.go`
- **Proxying**: `gateway/internal/router/utils/proxy.go`

---

## Request Lifecycle

A typical request to a protected resource flows through the gateway as follows:

1.  **Route Matching**: The gateway receives an incoming HTTP request. The `kratos_router.go` logic matches the request's URL path against the `routing.patterns` defined in `gateway.yaml`. It correctly prioritizes exact path matches over prefix matches.

2.  **Middleware Chain Execution**: Based on the matched route, a pre-defined chain of middleware is applied. This is orchestrated by the `MiddlewareManager` (`manager.go`). A typical chain for an authenticated route includes:
    a.  **CORS**: Handles Cross-Origin Resource Sharing headers.
    b.  **Rate Limiting**: Enforces request limits per IP, user, or endpoint.
    c.  **Authentication**: The auth middleware (`jwt_validator_wrapper.go`) validates the JWT, checks the blacklist, and uses a cache for performance.
    d.  **Trust Boundary Enforcement**: The auth middleware strips any incoming `X-User-*` headers and, upon successful validation, injects its own verified headers.
    e.  **Other Middleware**: Depending on the route, other middleware like `warehouse_detection` or `audit_log` may be executed.

3.  **Proxying**: After all middleware has passed, the request is handed to the `ProxyHandler` (`proxy.go`).
    a.  It constructs the target URL for the downstream service based on the routing configuration.
    b.  It copies headers from the original request and adds the verified context headers (e.g., `X-User-ID`).
    c.  It forwards the request to the downstream service.

4.  **Response**: The response from the downstream service is proxied back to the original client.

### Key Architectural Patterns

-   **Declarative Configuration**: Routing and middleware policies are declared in `gateway.yaml`, making the gateway's behavior easy to understand and audit.
-   **Middleware Presets**: YAML anchors are used to define reusable middleware chains (e.g., `public`, `authenticated`, `admin`), which simplifies route configuration.
-   **Optimized Middleware Manager**: The `MiddlewareManager` pre-builds and caches common middleware chains at startup to improve performance by avoiding repeated logic on every request.

---

## Identified Issues & Gaps

### P2 - Configuration: Deprecated `routes` Section

- **Issue**: The `gateway.yaml` file contains a deprecated `routes` section, while all active routing is handled by the `routing.patterns` section.
- **Impact**: This is a minor maintainability issue that can cause confusion for developers, who might edit the non-functional section by mistake.
- **Recommendation**: Remove the deprecated `routes` section from `gateway.yaml` to make `routing.patterns` the unambiguous single source of truth.

### P2 - Resilience: Basic Retry Mechanism

- **Issue**: The retry logic for proxying requests (`makeRequestWithRetry` in `route_manager.go`) uses a basic, fixed-delay retry.
- **Impact**: A fixed delay is not ideal for handling temporarily overloaded backend services, as it can contribute to a "thundering herd" problem where all retries happen at once. 
- **Recommendation**: Implement an exponential backoff with jitter for retries. This is a standard industry practice that staggers retry attempts, giving a struggling backend service a better chance to recover.

### P2 - Maintainability: Distributed Middleware Logic

- **Issue**: Logic for assembling and applying middleware chains is present in both `kratos_router.go` and `middleware/manager.go`.
- **Impact**: This distribution of responsibility makes the request lifecycle harder to trace and debug.
- **Recommendation**: Consolidate all middleware chain assembly logic into the `MiddlewareManager`. The router's responsibility should be simplified to only mapping a URL path to a final, pre-wrapped handler.

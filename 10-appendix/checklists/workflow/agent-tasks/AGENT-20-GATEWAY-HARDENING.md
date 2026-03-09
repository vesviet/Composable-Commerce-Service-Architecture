# TASK: GATEWAY SERVICE HARDENING

## OVERVIEW
**Service:** gateway
**Goal:** Resolve P0, P1, and P2 issues identified during the 10-round architecture review.

## ✅ RESOLVED / FIXED

### [FIXED ✅] [P0] [Resilience / Data Loss] Large Payload Proxying Fails (No Streaming Support)
**Description:** `RequestForwarder.ForwardRequest` strictly buffers requests up to 10MB in memory via `PrepareRequestBody`. Large file/image uploads fail because the router never dynamically invokes `ForwardRequestStreaming`.
- [x] Update `RequestForwarder.ForwardRequest` in `gateway/internal/router/forwarder.go` to check `proxy.IsLargeUpload(r)`. ✅ IMPLEMENTED
- [x] If true, dynamically route the request using `ForwardRequestStreaming` so memory isn't buffered. ✅ IMPLEMENTED

**Files:**
- `gateway/internal/router/forwarder.go` — Added `proxy` import, added `proxy.IsLargeUpload(r)` check at the top of `ForwardRequest`, and added new `forwardRequestStreaming` method.

**Solution Applied:**
```go
// P0 Fix: Route large uploads to streaming proxy to prevent OOM
if proxy.IsLargeUpload(r) {
    rf.logger.Infof("Large upload detected (Content-Length=%d), using streaming proxy", r.ContentLength)
    return rf.forwardRequestStreaming(w, r, route, targetURL, serviceKey)
}
```
Added `forwardRequestStreaming()` which creates a proxy request with `r.Body` directly (no buffering), propagates `ContentLength` and `TransferEncoding`, and delegates to `makeRequestWithRetry` for the single attempt.

**Validation:**
```
go build ./...  ✅
go test -race ./internal/router/...  ✅
go test -race ./internal/proxy/...   ✅
wire gen ./cmd/gateway/ ./cmd/worker/ ✅
```

---

### [FIXED ✅] [P1] [Performance / Resilience] Connection Leak in JWT HTTP Fallback Validation
**Description:** `defer resp.Body.Close()` inside the `for` loop in `validateTokenViaHTTP` causes a connection leak when endpoints degrade and `continue` is invoked.
- [x] Refactor the HTTP call in `gateway/internal/router/utils/jwt_validator_wrapper.go` to explicitly close the body before continuing. ✅ IMPLEMENTED

**Files:**
- `gateway/internal/router/utils/jwt_validator_wrapper.go` (lines 382-456) — Replaced `defer` inside loop with explicit `resp.Body.Close()` before every `continue` and after successful decode.

**Solution Applied:**
```go
// Before non-200 status continue
resp.Body.Close()
lastErr = fmt.Errorf("auth service returned status %d", resp.StatusCode)
continue

// After decode error
resp.Body.Close()
lastErr = fmt.Errorf("auth service decode error: %w", err)
continue

// After successful decode
resp.Body.Close()
```

**Validation:**
```
go build ./...  ✅
go test -race ./internal/router/utils/...  ✅
```

---

### [FIXED ✅] [P1] [Configuration / Scalability] Split-Brain Rate Limiter Fallback
**Description:** If `config.Redis.Enabled` is true but the client is nil, `checkLimit` falls back to `checkMemoryLimit`. This makes the rate limit bounded per-pod rather than globally.
- [x] If Redis is configured and enabled, a missing client must fail-closed rather than failing open to split-brain memory limits in `gateway/internal/middleware/rate_limit.go`. ✅ IMPLEMENTED

**Files:**
- `gateway/internal/middleware/rate_limit.go` — `checkLimit` now returns a 429 response (`writeRateLimitResponse`) when Redis is enabled but client is nil, instead of silently falling back to per-pod memory limits.

**Solution Applied:**
```go
if rl.config.Redis != nil && rl.config.Redis.Enabled && rl.redisClient == nil {
    rl.logger.Errorf("rate_limit: Redis is enabled but no client — failing closed")
    rl.writeRateLimitResponse(w, rule)
    return false
}
```

**Validation:**
```
go build ./...  ✅
go test -race ./internal/middleware/...  ✅
```

---

### [FIXED ✅] [P1] [Security / Web Standards] Duplicate CORS Headers
**Description:** `setCORSHeaders` is called before forwarding the proxy request. If backend services also have Kratos CORS middleware, duplicate `Access-Control-Allow-Origin` headers cause browser blockages.
- [x] Prevent duplicate CORS headers by stripping proxy response CORS headers at the Gateway. ✅ IMPLEMENTED

**Files:**
- `gateway/internal/proxy/handler.go` — `WriteResponse` now skips `Access-Control-*` headers from upstream responses, matching the pattern already used in `gateway/internal/router/utils/proxy.go`.

**Solution Applied:**
```go
// Copy response headers (skip CORS headers — Gateway sets its own)
for key, values := range resp.Header {
    if strings.HasPrefix(strings.ToLower(key), "access-control-") {
        continue
    }
    for _, value := range values {
        w.Header().Add(key, value)
    }
}
```

**Validation:**
```
go build ./...  ✅
go test -race ./internal/proxy/...  ✅
```

---

### [FIXED ✅] [P2] [Observability] Dead-Letter Queue (DLQ) Noise
**Description:** `logFailedMutation` pushes any error for mutation methods to the Redis DLQ, polluting it with non-retryable user errors.
- [x] Filter out `context.Canceled` and HTTP 4xx validation errors from being pushed to the DLQ in `gateway/internal/router/route_manager.go`. ✅ IMPLEMENTED

**Files:**
- `gateway/internal/router/route_manager.go` — Added `stderrors` import alias and error filtering at the top of `logFailedMutation`.

**Solution Applied:**
```go
if stderrors.Is(err, context.Canceled) || stderrors.Is(err, context.DeadlineExceeded) {
    rm.logger.Debugf("[dlq] skipping context error (non-retryable): %v", err)
    return
}
errMsg := err.Error()
if strings.Contains(errMsg, "status 400") || /* ... 401, 403, 404, 409, 422, 429 */ {
    rm.logger.Debugf("[dlq] skipping 4xx error (non-retryable): %v", err)
    return
}
```

**Validation:**
```
go build ./...  ✅
go test -race ./internal/router/...  ✅
```

---

### [FIXED ✅] [P2] [Routing] Verbose Alternate Prefix Registration
**Description:** Both trailing slash and non-trailing slash route versions are explicitly registered, cluttering the router map.
- [x] Consolidate trailing slash behavior into a canonical prefix + lightweight redirect/passthrough for the alternate form. ✅ IMPLEMENTED

**Files:**
- `gateway/internal/router/kratos_router.go` — `setupPatternRouteKratos` now registers the canonical prefix once, and uses a redirect handler (for trailing slash → non-trailing URL) or a passthrough wrapper (for non-trailing → trailing sub-paths).

**Solution Applied:**
- Trailing-slash prefixes: register primary prefix + `HandleFunc` redirect for bare path
- Non-trailing-slash prefixes: register primary prefix + `HandlePrefix` passthrough for sub-paths with trailing slash

**Validation:**
```
go build ./...  ✅
go test -race ./internal/router/...  ✅
```

---

### [FIXED ✅] [NEW ISSUE] [Security] Circuit Breaker Hiding Real Errors
**Description:** `ValidateTokenWithAuthService` wraps actual HTTP/gRPC errors inside `cbErr`. In the HTTP fallback, it immediately returns `failed to call auth service: %w`, hiding the root cause.
- [x] Ensure the circuit breaker propagates or correctly unwraps the real HTTP/gRPC error for accurate logging. ✅ IMPLEMENTED

**Files:**
- `gateway/internal/router/utils/jwt_validator_wrapper.go` — Updated `validateTokenViaGRPC` and `validateTokenViaHTTP` error handling.

**Solution Applied:**
```go
// In validateTokenViaGRPC:
if cbErr != nil {
    if grpcErr != nil {
        return nil, fmt.Errorf("auth service gRPC validation failed: %w", grpcErr)
    }
    return nil, fmt.Errorf("auth service gRPC validation unavailable (circuit breaker): %w", cbErr)
}

// In validateTokenViaHTTP:
if cbErr != nil {
    var httpErr error
    if resp == nil { httpErr = cbErr }
    if httpErr != nil {
        lastErr = fmt.Errorf("auth service HTTP call failed: %w", httpErr)
    } else {
        lastErr = fmt.Errorf("auth service unavailable (circuit breaker): %w", cbErr)
    }
    continue
}
```
Now errors distinguish between actual RPC failures (real root cause preserved) and CB-state errors (open/half-open), enabling accurate logging and debugging.

**Validation:**
```
go build ./...  ✅
go test -race ./internal/router/utils/...  ✅
```

---

## 🚀 EXECUTION WORKFLOW
Follow these steps to complete the task:
1. **Analyze:** Review the codebase for each issue. ✅
2. **Implement:** Apply fixes across the layers (`gateway/internal/router`, `gateway/internal/proxy`, `gateway/internal/middleware`). ✅
3. **Validate:** Run `go build`, `go test -race`, and `wire gen`. ✅
4. **Update:** Mark tasks as `[FIXED ✅]` and move them to RESOLVED. ✅
5. **Commit:** Follow GitOps standards.

## 📝 Commit Format
```
fix(gateway): resolve P0/P1/P2 hardening issues from architecture review

- P0: Route large uploads (>10MB) to streaming proxy to prevent OOM
- P1: Fix connection leak in JWT HTTP fallback (defer inside for-loop)
- P1: Rate limiter fails closed when Redis enabled but client nil
- P1: Strip duplicate CORS headers from upstream proxy responses
- P2: Filter non-retryable 4xx/context errors from Redis DLQ
- P2: Consolidate verbose trailing-slash prefix registration
- Security: Propagate real errors through circuit breaker wrappers
```

## 🔧 Pre-Commit Checklist
- [x] `wire gen ./cmd/gateway/ ./cmd/worker/` ✅
- [x] `go build ./...` ✅
- [x] `go test -race ./internal/router/... ./internal/middleware/... ./internal/proxy/...` ✅

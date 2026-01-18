# Gateway Service - Code Review Checklist (Team Lead)

## 📋 Overview

Checklist này dùng để review **Gateway Service** theo tiêu chuẩn trong `docs/checklists/TEAM_LEAD_CODE_REVIEW_GUIDE.md`.

- **Service location**: `gateway/`
- **Primary config**: `gateway/configs/gateway.yaml`
- **Primary entrypoint**:
  - `gateway/internal/server/http.go` (Kratos HTTP server)
  - `gateway/internal/router/route_manager.go`
  - `gateway/internal/router/auto_router.go`
- **Review date**: 2026-01-17

---

## 0) Review Preparation

- [ ] PR/MR mô tả rõ: mục tiêu, phạm vi, rollback plan
- [ ] Liệt kê endpoints/patterns bị ảnh hưởng (routing patterns + resource mapping)
- [ ] Có test plan tối thiểu (smoke routing/auth)

---

## 1) Architecture & Clean Code

- [ ] **Entry points rõ ràng**: init/config/router/middleware tách bạch, không “god file”
- [ ] **Dependency injection**: `RouteManager`, `AutoRouter`, middleware manager được inject (không global state)
- [ ] **Không leak business logic** vào gateway
  - Gateway chỉ làm: routing, auth boundary, middleware, observability, proxy
- [ ] **Không duplicate logic** không cần thiết
  - JWT/CORS/Proxy helpers nên dùng chung `gateway/internal/router/utils/*`
- [ ] **Lỗi cấu trúc**: tránh mixing 2 hệ middleware (Kratos middleware vs http filter) theo kiểu khó đoán thứ tự

### ✅ Observations (as-is)
- **Routing core**: `RouteManager` + `AutoRouter` đang là trung tâm.
- **Shared utils** đã có: `utils.CORSHandler`, `utils.ProxyHandler`, `utils.JWTValidatorWrapper`.

---

## 2) API / Contract / Routing Rules

### 2.1 Route matching & precedence

- [ ] **Explicit routes vs auto-routing**: đảm bảo route precedence đúng
  - `AutoRouter.Route()` có “safety check” tránh trùng exact path từ `routing.patterns`
- [ ] **Pattern routes**: `routing.patterns` trong `gateway/configs/gateway.yaml` phản ánh đúng hành vi runtime
- [ ] **Resource mapping**:
  - [ ] Mapping có trong config `routing.resource_mapping` (không chỉ hardcode)
  - [ ] Mapping có `public: true` cho webhook/settings nếu cần

### 2.2 Request limits

- [ ] Có **request body size limit** (P1) ở gateway/proxy layer
  - Hiện tại trong `auto_router.go` chưa thấy enforce explicit limit

### 2.3 Error contract

- [ ] Error response format nhất quán (prefer dùng `utils.Write*Error`)
- [ ] Service error có context tối thiểu:
  - service name
  - request id
  - status/timeout

---

## 3) Security (P0/P1)

### 3.1 Trust boundary headers (identity spoofing)

- [ ] **Strip untrusted identity headers** từ client trước khi proxy
  - `JWTValidatorWrapper.StripUntrustedHeaders()` đã có
- [ ] **Inject trusted identity headers** sau khi validate token
  - `JWTValidatorWrapper.InjectUserHeaders()` đã có
- [ ] **Không allow client override** `X-User-*`, `X-Client-Type`, `X-Gateway-*`

### 3.2 JWT validation

- [ ] JWT secret không hardcode, đọc từ env
  - `gateway/configs/gateway.yaml` dùng `${JWT_SECRET}` ✅
- [ ] **Expiry (`exp`)** được validate thực sự
  - Wrapper cache uses `exp` to set cache expiry, nhưng cần đảm bảo validator thực sự reject expired token (phụ thuộc common validator)
- [ ] **Blacklist** (logout) behavior:
  - `utils.JWTBlacklist` + wrapper `SetBlacklist()` có
  - [ ] Quyết định rõ **fail-open vs fail-closed** khi Redis lỗi (hiện wrapper đang “fail open”)

### 3.3 CORS

- [ ] Không dùng wildcard origin nếu `allow_credentials: true`
- [ ] OPTIONS preflight trả về đúng CORS headers
  - `AutoRouter.Route()` xử lý OPTIONS sớm ✅
  - Kratos 404 path có thể bypass filter, cần verify trên unmatched routes

### 3.4 SSRF / upstream allowlist

- [ ] Upstream URL được build từ config service list (không lấy trực tiếp từ user input)
- [ ] Không forward hop-by-hop headers nguy hiểm (Connection, Transfer-Encoding, …)

---

## 4) Observability

- [ ] Có `/health`, `/health/ready`, `/health/live`
  - `gateway/internal/server/http.go` ✅
- [ ] Có `/metrics`
  - `gateway/internal/server/http.go` ✅
- [ ] Request ID propagation:
  - `AutoRouter` generates `X-Request-ID` nếu thiếu ✅
- [ ] Metrics quan trọng:
  - retries/timeouts (`RouteManager.makeRequestWithRetry` increments)
  - service availability gauge updates ✅
- [ ] Logging:
  - không log secrets/token
  - log đủ fields: request id, path, service, duration

---

## 5) Reliability & Performance

### 5.1 Timeouts

- [ ] Server timeout:
  - `NewHTTPServer` có default `30s` nếu config không set ✅
- [ ] Upstream timeout:
  - `RouteManager` dùng `http.Client` từ `ServiceClient` (need verify actual timeouts/transport)
  - JWT fallback client timeout 5s ✅

### 5.2 Retries

- [ ] Retry chỉ áp dụng cho request an toàn/idempotent hoặc có guard
  - `makeRequestWithRetry` retry dựa vào config attempts/delay
  - [ ] Xác nhận không retry POST/PUT/DELETE gây side-effect (P1)

### 5.3 Rate limiting

- [ ] In-memory limiter map bounded/cleanup
  - `middleware/rate_limit.go` đã có `MemoryCleanup` + cleanup goroutine ✅
- [ ] Redis distributed rate limiting
  - `checkRedisLimit` implemented (sorted set sliding window) ✅
- [ ] Concurrency safety
  - map access protected by mutex ✅

### 5.4 Circuit breaker

- [ ] Có circuit breaker middleware và metrics state transitions
- [ ] Persistence across restart (optional) — document clearly

### 5.5 Caching

- [ ] Cache enabled/disabled via config
- [ ] Có cache invalidation strategy
  - `gateway/configs/gateway.yaml` có `cache.invalidation` và `bff.smart_cache.invalidation` ✅
  - [ ] Verify implementation in `SmartCacheMiddleware` match config (P1)

---

## 6) Config & Validation

- [ ] Config schema match code struct
- [ ] Config validation khi startup (P1)
  - required env: `JWT_SECRET`
  - required service hosts/ports
- [ ] Không còn config file duplicate (nếu có refactor)

---

## 7) Testing Checklist

### Unit
- [ ] JWT validator wrapper:
  - token parsing + caching TTL
  - blacklist check behavior
  - strip/inject headers
- [ ] Rate limiter:
  - memory cleanup removes stale entries
  - redis sliding window behavior
- [ ] AutoRouter:
  - route resolve error paths
  - OPTIONS handling
  - request id generation

### Integration
- [ ] Route patterns + resource mapping routing đúng service
- [ ] Auth: public vs protected endpoint behavior
- [ ] Header trust boundary: client spoof headers bị strip
- [ ] Metrics endpoints reachable

### Security
- [ ] Spoofing attempt: gửi `X-User-ID` từ client vẫn không qua được
- [ ] CORS preflight cho allowed origins

---

## 8) Deployment / Ops

- [ ] Health checks wired in k8s/ingress
- [ ] Alerting:
  - high 5xx
  - high latency
  - service availability drops
  - rate limit blocked spikes
- [ ] Runbook:
  - cách bật/tắt cache
  - cách rotate JWT secret
  - cách drain traffic

---

## 🔎 Delta vs old checklist (what was outdated)

- Rate limiter memory leak/race condition: **đã được fix** trong `middleware/rate_limit.go` (cleanup + mutex + pool)
- Resource mapping: **đã nằm trong config** `routing.resource_mapping` trong `gateway/configs/gateway.yaml`
- JWT expiry/blacklist: chuyển sang `utils.JWTValidatorWrapper` + `utils.JWTBlacklist` (có cache + blacklist hook)
- Caching invalidation: đã có config section cho invalidation (cần verify code alignment)

---

## ✅ Review Status

- [ ] Code review completed
- [ ] Security review completed
- [ ] Performance review completed
- [ ] Testing review completed

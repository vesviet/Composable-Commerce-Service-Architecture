# 🏛️ Common Package — Multi-Agent Meeting Review (Full Deep-Dive)

> **Date**: 2026-03-27  
> **Topic**: Full production-readiness review cho `common` package — tất cả modules  
> **Scope**: `common/events`, `common/outbox`, `common/middleware`, `common/security`, `common/errors`, `common/grpc`, `common/config`, `common/worker`, `common/idempotency`, `common/data`, `common/repository`, `common/client`, `common/utils/*` (18 subdirs)  
> **Panel**: 📐 Agent A (Architect) + 🛡️ Agent B (Security/Perf) + 💻 Agent C (Senior Go) + 🛠️ Agent E (DevOps/SRE) + 🧪 Agent F (QA)

---

## 👥 Panel Members

| Agent | Role | Lý do chọn |
|---|---|---|
| 📐 Agent A | System Architect | `common` là platform foundation — ảnh hưởng boundary và chuẩn coding toàn bộ services |
| 🛡️ Agent B | Security & Performance Engineer | Có nhiều lỗ hổng bảo mật tiềm ẩn ở middleware, webhook, CORS, rate limiting |
| 💻 Agent C | Senior Go Developer | Đánh giá Go idioms, race conditions, concurrency patterns, API ergonomics |
| 🛠️ Agent E | DevOps / SRE | CI reproducibility, config loading, health endpoints, graceful shutdown |
| 🧪 Agent F | QA Lead | Test race conditions, coverage gaps, regression risk |

---

## 1. Architecture Overview

### 📐 Agent A (Architect):
> Package có modularization rõ ràng: `client`, `worker`, `events`, `errors`, `repository`, `utils`. Tuy nhiên sau deep-dive, tôi thấy nhiều **critical boundary violations**: library code gọi `os.Exit()`, config tự fallback sang insecure defaults mà không fail, và error types tự động leak internal details ra client. Đây là những **architectural anti-patterns nghiêm trọng** cho một shared library.

### 🛡️ Agent B (Security/Perf):
> Kết quả review bảo mật cho thấy package có **nhiều P0 security issues hơn expected**: CORS bypass, timing attack ở webhook, X-Real-IP spoofing, SQL injection trong sequence generator, SSRF trong image processor. Đây là những lỗ hổng OWASP Top 10 cơ bản mà platform library không được phép có.

### 💻 Agent C (Senior Go):
> Chất lượng code nhìn chung tốt ở nhiều nơi (retry, address converter, uuid). Nhưng **concurrency bugs** rải rác: race condition ở cache metrics, deadlock ở event worker, non-thread-safe map ở sequence generator. Có pattern lặp lại là dùng unbuffered channel + non-blocking send, dẫn đến signal loss.

### 🛠️ Agent E (DevOps):
> Config loading có vấn đề nghiêm trọng: JWT secret fallback sang `"your-secret-key"` mà service vẫn start bình thường. Database function gọi `Fatalf` (os.Exit) thay vì return error. Đây là những operational risks trực tiếp.

### 🧪 Agent F (QA):
> Phát hiện test mock có data race (`base_worker_goroutine_test.go`), `os.Setenv` không an toàn cho parallel tests, và `prometheus.MustRegister` panic khi chạy integration tests nhiều lần. Regression confidence bị ảnh hưởng.

---

## 2. Security Critical Issues

### 🚨 Issue 2.1 — CORS Wildcard Subdomain Bypass (P0)

**Vị trí**: `common/middleware/cors.go`, line 132

```go
if strings.HasSuffix(host, domain) {
    return true
}
```

**🛡️ Agent B**: `HasSuffix("attackerexample.com", "example.com")` trả về `true`. Attacker chỉ cần register domain `evilexample.com` là bypass CORS. Đây là **OWASP A01 — Broken Access Control**. Fix: kiểm tra boundary `.` trước domain.

**💻 Agent C**: Fix đơn giản — `host == domain || strings.HasSuffix(host, "."+domain)`. Tuy nhiên tôi đề xuất thêm unit test cho edge case này vì nó dễ regression.

**📐 Agent A**: P0 vì đây là shared middleware — mọi service dùng CORS config đều bị ảnh hưởng.

---

### 🚨 Issue 2.2 — X-Real-IP Rate Limit Bypass (P0)

**Vị trí**: `common/middleware/ratelimit.go`, lines 172-174

```go
if realIP := header.Get("X-Real-IP"); realIP != "" {
    return realIP
}
```

**🛡️ Agent B**: `X-Real-IP` được trust **unconditionally** không qua proxy check. Client đặt `X-Real-IP: random-ip` là có rate limit bucket riêng, bypass hoàn toàn. `X-Forwarded-For` có check `isTrustedProxy`, nhưng `X-Real-IP` thì không.

**💻 Agent C**: Ngoài ra, `isTrustedProxy` dùng `strings.HasPrefix` thay vì IP/CIDR match — `"10.0.0.1"` match cả `"10.0.0.10"`, `"10.0.0.100"`. Nên dùng `net.ParseCIDR`.

**🛠️ Agent E**: Tôi đồng ý P0 vì rate limiting là tuyến phòng thủ chính. Mọi service dùng middleware này đều exposed.

---

### 🚨 Issue 2.3 — Twilio Webhook Timing Attack (P0)

**Vị trí**: `common/security/webhook/twilio.go`, line 55

```go
if actualSignature != signature {
```

**🛡️ Agent B**: Standard `!=` không phải constant-time comparison. Attacker đo response time để brute-force HMAC từng byte. Fix: `hmac.Equal([]byte(actualSignature), []byte(signature))`.

**💻 Agent C**: SendGrid verifier cũng cần review — nhưng nó dùng ECDSA verify (inherently constant-time). Chỉ Twilio bị ảnh hưởng.

**🧪 Agent F**: Test hiện tại chỉ cover happy path. Nên thêm test verify timing với crafted signatures.

---

### 🚨 Issue 2.4 — SQL Injection Trong Sequence Generator (P0)

**Vị trí**: `common/utils/sequence/generator.go`, lines 122, 134, 145

```go
row := gen.db.Raw(fmt.Sprintf(`SELECT last_value FROM "%s"`, seqKey)).Row()
// ...
query := fmt.Sprintf(`CREATE SEQUENCE IF NOT EXISTS "%s"`, seqKey)
```

**🛡️ Agent B**: `seqKey` build từ `EntityKey` + date, được interpolate trực tiếp vào SQL. Crafted `EntityKey` = `order"; DROP TABLE users; --` sẽ execute arbitrary SQL.

**💻 Agent C**: PostgreSQL identifiers không parameterize được, nên phải validate bằng regex `^[a-zA-Z0-9_]+$` trước khi interpolate.

**📐 Agent A**: Module `sequence` được dùng bởi `fulfillment`, `order`, `catalog`, `warehouse` — blast radius rất lớn.

---

### 🚨 Issue 2.5 — SSRF + No Timeout Trong Image Processor (P0)

**Vị trí**: `common/utils/image/image_processor.go`, lines 159-165

```go
resp, err := http.Get(fileURL)
```

**🛡️ Agent B**: Default `http.Client` không có timeout. `fileURL` do user cung cấp — attacker pass `http://169.254.169.254/latest/meta-data/` để exfiltrate AWS credentials (SSRF). Không có size limit, download file lớn vô hạn gây OOM.

**🛠️ Agent E**: Trong K8s, metadata endpoint `169.254.169.254` accessible từ pod. Đây là attack vector thực tế.

**💻 Agent C**: Fix: accept `context.Context`, dùng client có timeout, validate URL against allowlist, `io.LimitReader` cho response body.

---

## 3. Event & Outbox Correctness

### 🚨 Issue 3.1 — Nil Pointer Panic Khi Dapr Disabled (P0)

**Vị trí**: `common/events/dapr_publisher_grpc.go`, lines 65-71, 109-113

```go
// Constructor khi DAPR_DISABLED=true:
return &DaprEventPublisherGRPC{
    circuitBreaker: nil,  // ← nil
    disabled:       true,
}

// PublishWithMetadata:
func (p *DaprEventPublisherGRPC) PublishWithMetadata(...) error {
    return p.circuitBreaker.Call(func() error {  // ← PANIC: nil pointer
        return p.publishEvent(...)  // disabled check nằm trong đây, nhưng không bao giờ tới
    })
}
```

**💻 Agent C**: `disabled` check nằm trong `publishEvent` (line 117), nhưng `circuitBreaker.Call` dereference nil trước khi tới đó. Mọi service set `DAPR_DISABLED=true` sẽ crash ở event publish đầu tiên.

**🛠️ Agent E**: Đây là P0 vì development/test environments thường set `DAPR_DISABLED=true`.

**📐 Agent A**: Fix: early return trong `PublishWithMetadata` trước khi gọi circuit breaker.

---

### 🟡 Issue 3.2 — EntityEventHelper Mất Action Type (P1)

**Vị trí**: `common/events/entity_event_helper.go`, lines 96, 111

**💻 Agent C**: `envelope()` set `EventType = action` (e.g., "created"), rồi `publish()` ghi đè bằng `topic`. Action ("created", "updated", "deleted") bị mất hoàn toàn. Consumers không phân biệt được event types cho cùng topic.

**📐 Agent A**: Đây là semantic data loss. Nên preserve action trong `event.Data["action"]` hoặc ngừng ghi đè `EventType`.

---

### 🟡 Issue 3.3 — Outbox Worker Sequential Processing Bottleneck (P1)

**Vị trí**: `common/outbox/worker.go`, lines 269-271

```go
for _, event := range events {
    w.processEvent(ctx, event)
}
```

**🛡️ Agent B**: Với `batchSize=50` và 3s timeout mỗi event, worst case mất **150s** — vượt xa poll interval 5s. Kèm 3 COUNT queries mỗi poll cycle (lines 234-254) tạo 36 COUNT/phút.

**🛠️ Agent E**: Tôi phản biện rằng sequential processing đơn giản hơn và ít lỗi hơn concurrent. Nhưng đồng ý cần throttle gauge queries xuống 30-60s interval.

**💻 Agent C**: Đề xuất `errgroup` với bounded concurrency thay vì full sequential.

---

## 4. gRPC Client & Error Handling

### 🚨 Issue 4.1 — CallSimple Trả Error Trên Success Path (P0)

**Vị trí**: `common/grpc/circuit_breaker_client.go`, line 160

```go
return fmt.Errorf("%w", err) // err is nil on success → returns non-nil error
```

**💻 Agent C**: `fmt.Errorf("%w", nil)` trả về non-nil error có text `%!w(<nil>)`. Mọi gRPC call qua `CallSimple` đều bị report là failure dù thành công.

**📐 Agent A**: P0 vì ảnh hưởng trực tiếp data flow.

---

### 🚨 Issue 4.2 — CallWithBreaker Drop Business Errors (P0)

**Vị trí**: `common/grpc/circuit_breaker_client.go`, lines 61-96

**💻 Agent C**: Khi `fn` trả business error (NotFound, InvalidArgument), closure return `nil` cho CB (đúng), nhưng outer function cũng return `nil` — business error bị mất vĩnh viễn. Comment nói "re-run fn" nhưng không có re-run nào.

**🛡️ Agent B**: Đây là data loss. Client gọi API thành công nhưng nhận `nil` error dù backend trả `NotFound`. Ảnh hưởng logic downstream.

**📐 Agent A**: Fix: capture `callErr` trong variable ngoài closure scope, return nó cuối cùng.

---

### 🚨 Issue 4.3 — WithCause Auto-Leak Internal Details (P0)

**Vị trí**: `common/errors/types.go`, lines 173-178

```go
func (e *ServiceError) WithCause(cause error) *ServiceError {
    e.Cause = cause
    if e.Details == "" && cause != nil {
        e.Details = cause.Error()  // Auto-populate Details with raw error
    }
}
```

**🛡️ Agent B**: `Details` sau đó được include trong HTTP response (response.go:86) và gRPC message (error_mapper.go:111). Ví dụ: `NewInternalError("DB error", pgErr)` sẽ leak `"pq: password authentication failed for user catalog_user"` ra client.

**💻 Agent C**: Tôi đồng ý — auto-population này vi phạm principle of least surprise. Callers nên explicitly set safe details.

**📐 Agent A**: Kèm theo đó, `ErrorResponse` còn expose `UserID` field (response.go:20-22) và tự inject `service_name`, `service_version` vào metadata (response.go:94-101). Cần strip hết.

---

### 🚨 Issue 4.4 — JWT Secret Fallback Cho Phép Start Với Insecure Default (P0)

**Vị trí**: `common/config/config.go`, lines 182-194

```go
if secret == "" {
    fmt.Println("[CRITICAL] JWT_SECRET environment variable is not set!")
    secret = "your-secret-key"
}
```

**🛠️ Agent E**: Service start thành công với known secret, warning dùng `fmt.Println` (bypass structured logging, không tới log aggregation). Không có environment check — production chạy giống dev.

**🛡️ Agent B**: P0 — nếu production deploy thiếu `JWT_SECRET`, mọi token đều forged được.

**💻 Agent C**: Fix: return error hoặc panic khi env != "development".

---

## 5. Worker Concurrency & Lifecycle

### 🚨 Issue 5.1 — Deadlock Trong BaseEventWorker.Start (P0)

**Vị trí**: `common/worker/event_worker.go`, lines 59-77

```go
func (w *BaseEventWorker) Start(ctx context.Context) error {
    w.mu.Lock()
    defer w.mu.Unlock()
    // ...
    select {        // ← Block vĩnh viễn WHILE HOLDING LOCK
    case <-ctx.Done():
    case <-w.stopCh:
    }
}
```

**💻 Agent C**: `Start()` acquire lock rồi block vĩnh viễn trong `select`. `Stop()` cần acquire cùng lock để close `stopCh` → deadlock. Comment nói "override in concrete workers" nhưng method là exported public.

**🧪 Agent F**: Test cho module này không cover trường hợp gọi `Start` rồi `Stop` trên `BaseEventWorker` trực tiếp — thiếu regression coverage.

**📐 Agent A**: Fix: release lock trước `select`, hoặc guard chỉ state check.

---

### 🟡 Issue 5.2 — WorkerMetrics Race Condition (P1)

**Vị trí**: `common/worker/base_worker.go`, lines 75-92

**💻 Agent C**: `TotalRuns.Add(1)` atomic ở ngoài mutex, `TotalRuns.Load()` ở trong mutex. Giữa hai lệnh, goroutine khác có thể increment thêm → running average drift. Fix: dùng return value của `Add` hoặc move atomic vào trong mutex.

---

### 🟡 Issue 5.3 — Stop Signal Loss Pattern (P1)

**Vị trí**: `common/worker/base_worker.go`, lines 204-209

```go
select {
case w.stopCh <- struct{}{}:
default:  // ← Signal dropped silently
}
```

**💻 Agent C**: Pattern lặp lại ở `Stop()`, `Restart()` với unbuffered channel + non-blocking send. Nếu worker goroutine đang chạy (không block ở select), signal bị drop và `Stop()` return `nil` — caller nghĩ worker đã dừng.

**🛠️ Agent E**: Tôi đề xuất buffer channel size 1, hoặc tốt hơn là dùng `close()` + `sync.Once` + done channel để wait.

---

### 🟡 Issue 5.4 — Auto-Restart Goroutine Leak (P1)

**Vị trí**: `common/worker/base_worker.go`, lines 348-362

**💻 Agent C**: `time.Sleep(w.config.RestartDelay)` không respect context cancellation. Worker fail nhanh sẽ spawn goroutine mới mỗi lần → goroutine leak.

**🛠️ Agent E**: Với `RestartDelay=10s`, khi shutdown cần chờ tới 10s cho goroutine wake up rồi mới thoát. Fix: `select` với `time.After` + `ctx.Done()`.

---

## 6. Auth Middleware & Config

### 🟡 Issue 6.1 — JWT Missing aud/iss/type Validation (P1)

**Vị trí**: `common/middleware/auth.go`, lines 255-262

**🛡️ Agent B**: `validateJWT` chỉ check signing method, không validate `aud`, `iss`, `type`. Refresh token dùng được như access token. Token từ service A replay được sang service B. OWASP A07.

**📐 Agent A**: Tôi phản biện nhẹ — hiện tại auth service là single issuer. Nhưng khi scale ra multi-tenant, thiếu aud/iss check sẽ là lỗ hổng nghiêm trọng. Nên fix proactively.

---

### 🟡 Issue 6.2 — OptionalAuth Abort Trên Invalid Token (P1)

**Vị trí**: `common/middleware/auth.go`, lines 220-230

**💻 Agent C**: Comment nói "don't fail if invalid" nhưng code abort với 401. Public endpoint có optional personalization sẽ bị block nếu client gửi malformed Authorization header.

**🛡️ Agent B**: Đồng ý P1. Fix: log error rồi `c.Next()` thay vì `c.Abort()`.

---

### 🟡 Issue 6.3 — SkipPaths Prefix Match Quá Rộng (P1)

**Vị trí**: `common/middleware/auth.go`, lines 74-79

```go
if strings.HasPrefix(path, skipPath) {
```

**🛡️ Agent B**: SkipPath `/health` cũng skip `/healthcheck-admin-panel`. Fix: `path == skipPath || strings.HasPrefix(path, skipPath+"/")`.

**🧪 Agent F**: Nên thêm table-driven test cho edge cases: trailing slash, path traversal, query string.

---

### 🟡 Issue 6.4 — JWT Error Details Leak Ra Client (P1)

**Vị trí**: `common/middleware/auth.go`, lines 117-121

**🛡️ Agent B**: `err.Error()` từ JWT library trả về client. Leak info như `"token is expired by 2h30m"`, `"crypto/rsa: verification error"`. OWASP A09.

**💻 Agent C**: Tương tự, `common/grpc/error_mapper.go` (lines 84-105) forward raw `err.Error()` cho `codes.Internal`. Fix: log specific error server-side, return generic message cho client.

---

## 7. Data Safety & Idempotency

### 🟡 Issue 7.1 — GormIdempotencyHelper TOCTOU Race (P1)

**Vị trí**: `common/idempotency/gorm_helper.go`, lines 57-134

**💻 Agent C**: Flow: SELECT → run handler → INSERT. Giữa SELECT (no record) và INSERT, process khác có thể INSERT cùng `event_id`. Cả hai process đều run handler → break exactly-once semantics.

**🛡️ Agent B**: Đặc biệt nguy hiểm cho payment/order processing. `IdempotencyChecker.claimEvent` dùng INSERT-first pattern đúng, nhưng `GormIdempotencyHelper` thì không.

**📐 Agent A**: Fix: dùng INSERT ON CONFLICT DO NOTHING (claim first), check `rowsAffected`, rồi mới run handler.

---

### 🟡 Issue 7.2 — bcrypt 72-byte Silent Truncation (P1)

**Vị trí**: `common/security/password.go`, lines 47-57

**🛡️ Agent B**: bcrypt truncate password tại 72 bytes. Hai password khác nhau nhưng share 72 bytes đầu sẽ match. Không có upper bound validation.

**💻 Agent C**: Fix: thêm `if len(password) > 72 { return error }` trong `ValidatePasswordStrength`.

---

### 🟡 Issue 7.3 — Database Library Gọi os.Exit (P1)

**Vị trí**: `common/utils/database/postgres.go`, lines 74, 79, 108

```go
logHelper.Fatalf("failed opening connection to postgres: %v", err)
```

**🛠️ Agent E**: `Fatalf` gọi `os.Exit(1)`. Library function không bao giờ nên kill process — ngăn graceful shutdown, cleanup deferred, và untestable.

**📐 Agent A**: P1 vì ảnh hưởng deployment pattern. Service crash mà không có chance ghi log hay close connections.

**💻 Agent C**: Fix: return `(*gorm.DB, error)` cho caller quyết định.

---

## 8. Utils Quality Issues

### 🟡 Issue 8.1 — HTTP Retry Body Consumed, Retries Gửi Empty Body (P1)

**Vị trí**: `common/utils/http/retry_client.go`, lines 47-93

**💻 Agent C**: `body io.Reader` consumed ở attempt đầu. Tất cả retry attempts gửi empty body cho POST/PUT. Fix: accept `[]byte` hoặc buffer body trước loop.

---

### 🟡 Issue 8.2 — Cache Stampede Trong GetOrSet (P1)

**Vị trí**: `common/utils/cache/cache.go`, lines 248-272

**🛡️ Agent B**: N goroutines request cùng cold key đều gọi loader đồng thời → thundering herd. Fix: `singleflight` để deduplicate concurrent loads.

**📐 Agent A**: Tôi phản biện rằng `singleflight` thêm complexity. Nhưng với e-commerce platform, cache stampede trên hot product page là realistic scenario. P1 hợp lý.

---

### 🟡 Issue 8.3 — Money.Div Panic On Zero (P1)

**Vị trí**: `common/utils/money/arithmetic.go`, lines 41-43

**💻 Agent C**: `shopspring/decimal.Div` panic on zero. Financial system không được panic vì bad data. Fix: return `(Money, error)`.

---

### 🔵 Issue 8.4 — Money.ToCents Truncates Thay Vì Round (P2)

**Vị trí**: `common/utils/money/money.go`, lines 71-73

**💻 Agent C**: `IntPart()` truncate toward zero. `Money("19.999").ToCents()` = 1999 thay vì 2000. Fix: `RoundBank(0)` trước `IntPart()`.

---

### 🔵 Issue 8.5 — MulPercentage Dùng float64 Division (P2)

**Vị trí**: `common/utils/money/arithmetic.go`, lines 36-38

**💻 Agent C**: `percentage / 100.0` là float64 operation mất precision trước khi tới decimal library. Fix: dùng `decimal.NewFromFloat(percentage).Div(decimal.NewFromInt(100))`.

---

### 🔵 Issue 8.6 — Cache Metrics Non-Atomic Increments (P2)

**Vị trí**: `common/utils/cache/cache_metrics.go`, lines 35-36

**💻 Agent C**: `m.Hits++` trên plain `int64` — data race under concurrent access. Fix: dùng `atomic.Int64`.

---

## 9. 🚩 PENDING ISSUES (Consolidated)

### 🚨 Critical (P0)

| # | Issue | Module | Impact (Business) | Action Required |
|---|---|---|---|---|
| 1 | CORS wildcard subdomain bypass | middleware/cors | Attacker bypass CORS trên mọi service | Fix `HasSuffix` → check `.` boundary |
| 2 | X-Real-IP rate limit bypass | middleware/ratelimit | Rate limiting bị vô hiệu hóa | Gate behind `isTrustedProxy` |
| 3 | Twilio webhook timing attack | security/webhook | Forge webhook signatures | Dùng `hmac.Equal` |
| 4 | SQL injection trong sequence generator | utils/sequence | Arbitrary SQL execution | Validate seqKey regex |
| 5 | SSRF + no timeout trong image processor | utils/image | AWS credential exfiltration | URL allowlist + timeout + size limit |
| 6 | Nil pointer panic khi Dapr disabled | events | Service crash ở dev/test | Early return before CB call |
| 7 | CallSimple trả error trên success | grpc/circuit_breaker_client | Mọi gRPC call bị report failure | Fix nil error wrapping |
| 8 | CallWithBreaker drop business errors | grpc/circuit_breaker_client | NotFound/InvalidArg bị nuốt | Capture callErr ngoài closure |
| 9 | WithCause auto-leak internal details | errors/types | DB credentials leak ra client | Remove auto-populate Details |
| 10 | JWT secret fallback insecure default | config | All tokens forgeable nếu thiếu env var | Fail fast khi env != dev |
| 11 | Deadlock trong BaseEventWorker.Start | worker/event_worker | Process hang vĩnh viễn | Release lock trước select |
| 12 | Database library gọi os.Exit | utils/database | Ngăn graceful shutdown | Return error thay vì Fatalf |

### 🟡 High Priority (P1)

| # | Issue | Module | Impact (Business) |
|---|---|---|---|
| 1 | JWT missing aud/iss/type validation | middleware/auth | Token replay cross-service |
| 2 | OptionalAuth abort trên invalid token | middleware/auth | Public endpoints bị block |
| 3 | SkipPaths prefix match quá rộng | middleware/auth | Auth bypass qua path prefix |
| 4 | JWT error details leak ra client | middleware/auth | Internal info disclosure |
| 5 | EntityEventHelper mất action type | events | Event consumers mất semantic info |
| 6 | Outbox sequential processing bottleneck | outbox/worker | Throughput bottleneck under load |
| 7 | GormIdempotencyHelper TOCTOU race | idempotency | Duplicate payment/order processing |
| 8 | bcrypt 72-byte silent truncation | security/password | Password collision risk |
| 9 | HTTP retry body consumed | utils/http | POST retries gửi empty body |
| 10 | Cache stampede trong GetOrSet | utils/cache | Thundering herd on hot keys |
| 11 | Money.Div panic on zero | utils/money | Service crash on bad data |
| 12 | WorkerMetrics race condition | worker | Average metrics drift |
| 13 | Stop signal loss pattern | worker | Worker không dừng khi gọi Stop |
| 14 | Auto-restart goroutine leak | worker | Goroutine accumulation |
| 15 | No replay protection webhook verifiers | security/webhook | Replay attacks |
| 16 | Hand-rolled DER parser | security/webhook/sendgrid | Parsing bugs |
| 17 | prometheus.MustRegister panic | outbox/metrics | Test/startup crash |
| 18 | gRPC error mapper forward raw errors | grpc/error_mapper | Internal details to client |
| 19 | ErrorResponse expose UserID + service info | errors/response | PII + topology leak |
| 20 | Missing Vary: Origin header | middleware/cors | CDN cache poisoning |
| 21 | isTrustedProxy prefix match sai | middleware/ratelimit | Wrong IP trusted |
| 22 | Overlapping error classifier keywords | errors/classifier | Misclassified errors |
| 23 | ServiceError missing Unwrap() | errors/types | breaks errors.Is/As chain |
| 24 | WrapError mutates original | errors/utils | Race on shared errors |

### 🔵 Nice to Have (P2)

| # | Issue | Value |
|---|---|---|
| 1 | Money.ToCents truncates thay vì round | Financial precision |
| 2 | MulPercentage float64 division | Precision loss |
| 3 | Cache metrics non-atomic | Data race under load |
| 4 | PII logged in URL paths | GDPR compliance |
| 5 | Query string logged in panic handler | Secret exposure |
| 6 | Transaction context compatibility sprawl | Architecture debt |
| 7 | Default MaxOpenConns=100 exhaust PG limits | Operational stability |
| 8 | ValidateServiceConfig no-op | False validation sense |
| 9 | No nested transaction support | Data layer correctness |
| 10 | S3 Manager dùng context.Background | Cancellation propagation |
| 11 | CSV role encoding comma injection | Privilege escalation |
| 12 | PII Masker phone/passport false positives | Log corruption |
| 13 | Two error types ambiguity | API clarity |
| 14 | No rollback on failed commit | Transaction safety |
| 15 | EventWorker not restartable after Stop | Lifecycle management |

---

## 🎯 Executive Summary

### 📐 Agent A (Architect):
> `common` có foundation tốt nhưng đang mang **12 P0 issues** — con số bất thường cho một platform library. Nhiều vấn đề thuộc loại "library anti-patterns" (os.Exit, insecure defaults, auto-leak details). Cần sprint riêng để hardening trước khi mở rộng adoption.

### 🛡️ Agent B (Security/Perf):
> Security posture **nghiêm trọng hơn expected**. CORS bypass, rate limit bypass, SQL injection, SSRF, timing attack — đều là OWASP Top 10 cơ bản. JWT validation thiếu audience/issuer check. Priority #1: fix tất cả P0 security issues trước khi deploy bất kỳ service mới nào.

### 💻 Agent C (Senior Go):
> Codebase có nhiều phần viết tốt (retry, uuid, address, pagination). Tuy nhiên **concurrency bugs** là pattern lặp lại: unbuffered channel signal loss, non-atomic metrics, deadlock, non-thread-safe map. Cần audit toàn bộ channel/goroutine patterns. Error handling cũng cần refactor — `WithCause` auto-leak và `WrapError` mutate original là dangerous cho shared library.

### 🛠️ Agent E (DevOps/SRE):
> Operational concerns: JWT secret fallback, database Fatalf, worker không graceful shutdown. Đây là những issues mà SRE sẽ gặp **đầu tiên** khi service crash ở production. Config loading cần fail-fast cho non-dev environments.

### 🧪 Agent F (QA Lead):
> Test coverage tốt ở nhiều module, nhưng có gaps quan trọng: test mocks có data race, event worker deadlock không có test, `prometheus.MustRegister` crash trong repeated test runs. Recommend thêm `-race` flag vào CI pipeline cho `common` package.

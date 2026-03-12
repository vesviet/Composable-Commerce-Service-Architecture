# AGENT-24: Cross-Cutting Concerns Hardening (250-Round Review)

> **Created**: 2026-03-11
> **Priority**: P0/P1/P2 (2 Critical, 13 High, 7 Nice-to-Have)
> **Sprint**: Infrastructure Hardening Sprint
> **Services**: `common`, `gateway`, cross-service patterns
> **Estimated Effort**: 7-10 days
> **Source**: [250-Round Meeting Review](file:///home/user/.gemini/antigravity/brain/11c0fbbd-b69d-4551-b479-90c334d32468/cross_cutting_meeting_review_250.md)

---

## 📋 Overview

Hardening tasks from the 250-round cross-cutting concerns review. Focus: Redis idempotency stale lock, rate limiter atomicity gap (spec vs code), outbox worker reliability, circuit breaker unification, PII masking precision, saga timeout, and DLQ standardization.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix Redis Idempotency `in_progress` Stale Lock

**File**: `common/idempotency/redis_idempotency.go`
**Lines**: 55-87
**Risk**: Service crash after SetNX leaves key stuck at `in_progress` for entire TTL (up to 30min) → All payment retries blocked → Customer charged but order not confirmed.
**Problem**: `Execute()` sets `in_progress` with the same TTL as `completed`. If service crashes before `markCompleted`/`markFailed`, retries get `ErrOperationInProgress` until TTL expires.
```go
// BEFORE (line 68): Same TTL for in_progress and completed
acquired, err := s.rdb.SetNX(ctx, redisKey, stateBytes, s.ttl).Result()
```
**Fix**:
```go
// AFTER: Use short TTL for in_progress lock (60s), extend to full TTL on completion
inProgressTTL := 60 * time.Second
if inProgressTTL > s.ttl {
    inProgressTTL = s.ttl
}
acquired, err := s.rdb.SetNX(ctx, redisKey, stateBytes, inProgressTTL).Result()
```
Also add stale lock detection in `handleExisting`:
```go
case "in_progress":
    // Check if lock is stale (older than 60s → likely crashed)
    if time.Since(state.CreatedAt) > 60*time.Second {
        s.logger.Warnf("Stale in_progress lock detected for key %s (age: %v), deleting", redisKey, time.Since(state.CreatedAt))
        s.rdb.Del(ctx, redisKey)
        return ErrPreviousAttemptFailed // Allow retry
    }
    return ErrOperationInProgress
```
**Validation**:
```bash
cd common && go test ./idempotency/... -run TestStaleInProgressLock -v
```

---

### [ ] Task 2: Implement Atomic Lua Script for Redis Rate Limiting

**File**: `gateway/internal/middleware/rate_limit.go`
**Lines**: 250-288 (`checkRedisLimit`)
**Risk**: Spec §15.7 claims "Atomic Lua scripts" but code uses non-atomic Redis Pipeline → off-by-one + race under concurrent load. Pipeline ZAdd runs AFTER ZCard count, allowing 1 extra request per check.
**Problem**: Pipeline commands execute independently. Concurrent requests between `ZCard` and `ZAdd` create race conditions. With 1000 concurrent clients, effective overshoot = 1000 extra requests/minute.
**Fix**: Replace pipeline with Lua EVAL:
```go
const slidingWindowLua = `
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])
local member = ARGV[4]

redis.call('ZREMRANGEBYSCORE', key, '0', tostring(now - window))
local count = redis.call('ZCARD', key)
if count >= limit then
    return 0
end
redis.call('ZADD', key, now, member)
redis.call('EXPIRE', key, window)
return 1
`

func (rl *RateLimiter) checkRedisLimit(ctx context.Context, key string, rule *RateLimitRule, w http.ResponseWriter) bool {
    redisKey := fmt.Sprintf("rate_limit:%s", key)
    now := time.Now()
    result, err := rl.redisClient.Eval(ctx, slidingWindowLua, []string{redisKey},
        now.Unix(), 60, rule.RequestsPerMinute, fmt.Sprintf("%d", now.UnixNano()),
    ).Int()
    if err != nil {
        rl.logger.Warnf("Redis rate limit Lua failed, falling back to memory: %v", err)
        return rl.checkMemoryLimit(key, rule, w)
    }
    if result == 0 {
        rl.recordRateLimitMetric("blocked", key)
        rl.writeRateLimitResponse(w, rule)
        return false
    }
    rl.setRateLimitHeaders(w, rule, nil)
    rl.recordRateLimitMetric("allowed", key)
    return true
}
```
**Validation**:
```bash
cd gateway && go test ./internal/middleware/... -run TestRedisRateLimit -v -race -count=5
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Fix DB Idempotency TOCTOU Race in ProcessWithIdempotency

**File**: `common/idempotency/event_processing.go`
**Lines**: 201-242
**Risk**: `IsProcessed()` → `processFn()` → `MarkProcessed()` has TOCTOU gap → concurrent requests both see `not processed` → double processing.
**Fix**: Use `INSERT ON CONFLICT DO NOTHING` as atomic lock before running `processFn`:
```go
// Before processFn, attempt to claim the event atomically
claimed, err := c.claimEvent(ctx, eventID, eventType, topic)
if err != nil { /* handle */ }
if !claimed { /* already claimed by another worker */ return nil }
// Now run processFn safely...
```
**Validation**:
```bash
cd common && go test ./idempotency/... -run TestConcurrentProcessing -v -race
```

---

### [ ] Task 4: Prevent Outbox Multi-Pod ResetStuck Double Publish

**File**: `common/outbox/worker.go`
**Lines**: 207-214
**Risk**: `ResetStuck` on pod A can reset events that pod B just fetched 1s ago → pod B publishes, outbox also re-publishes on next cycle → double publish.
**Fix**: Document minimum stuckTimeout requirement (`stuckTimeout >= 2 * pollInterval`). Add validation in `NewWorker`:
```go
if w.stuckTimeout > 0 && w.stuckTimeout < 2*w.interval {
    w.log.Warnf("stuckTimeout (%v) should be >= 2x interval (%v) to prevent double publish", w.stuckTimeout, w.interval)
    w.stuckTimeout = 2 * w.interval
}
```
**Validation**:
```bash
cd common && go test ./outbox/... -run TestStuckRecovery -v
```

---

### [ ] Task 5: Replace Blocking Backoff with DB-Level next_retry_at

**File**: `common/outbox/worker.go`
**Lines**: 320-327
**Risk**: `time.After(delay)` inside event processing loop blocks entire batch. 10 failed events × 5s backoff = 50s delay → backlog growth. Also timer leak on context cancel.
**Fix**: Replace inline sleep with status update including `next_retry_at`:
```go
// Instead of time.After:
retryAt := time.Now().Add(w.backoff.NextDelay(event.RetryCount))
if updateErr := w.repo.UpdateStatusWithRetryAt(ctx, event.ID, "pending", &errMsg, &retryAt); updateErr != nil {
    w.log.Errorf("[DATA_CONSISTENCY] Failed to reset event %s: %v", event.ID, updateErr)
}
```
Update `FetchPending` query to filter: `WHERE status = 'pending' AND (next_retry_at IS NULL OR next_retry_at <= NOW())`.
**Validation**:
```bash
cd common && go test ./outbox/... -run TestBackoff -v
```

---

### [ ] Task 6: Fix In-Memory Rate Limiter lastUsed Data Race

**File**: `gateway/internal/middleware/rate_limit.go`
**Lines**: 196
**Risk**: `time.Time` is a 24-byte struct — NOT atomic on any architecture. Concurrent writes from multiple goroutines can produce torn reads in cleanup goroutine.
**Fix**:
```go
// BEFORE (line 196):
entry.lastUsed = time.Now()

// AFTER: Use atomic.Int64 for Unix timestamp
type limiterEntry struct {
    limiter    *rate.Limiter
    lastUsedNs atomic.Int64  // Unix nanoseconds
}
// Write:
entry.lastUsedNs.Store(time.Now().UnixNano())
// Read (in cleanup):
lastUsed := time.Unix(0, entry.lastUsedNs.Load())
```
**Validation**:
```bash
cd gateway && go test -race ./internal/middleware/... -run TestRateLimitConcurrent -v -count=10
```

---

### [ ] Task 7: Add Metric Counter for Redis Rate Limit Fallback

**File**: `gateway/internal/middleware/rate_limit.go`
**Lines**: 267-269
**Risk**: Redis failure silently falls back to in-memory → effective limit = RequestsPerMinute × pod_count → DDoS amplification.
**Fix**: Add config flag + metric:
```go
if err != nil {
    rl.logger.Warnf("Redis rate limit check failed: %v", err)
    rl.recordRateLimitMetric("redis_fallback", key) // NEW: track fallback
    if rl.config.Redis.FailOnError {
        rl.writeRateLimitResponse(w, rule)
        return false
    }
    return rl.checkMemoryLimit(key, rule, w)
}
```
**Validation**:
```bash
cd gateway && go build ./...
```

---

### [ ] Task 8: Add Panic Recovery to gRPC Circuit Breaker

**File**: `common/grpc/circuit_breaker.go`
**Lines**: 131-139 (`Call`)
**Risk**: gRPC CB `Call` does NOT recover panics (unlike HTTP CB). Panic in gRPC handler → CB doesn't record failure → stays closed → cascading panics.
**Fix**:
```go
func (cb *CircuitBreaker) Call(ctx context.Context, fn func(ctx context.Context) error) (err error) {
    if err := cb.beforeCall(); err != nil {
        return err
    }
    defer func() {
        if r := recover(); r != nil {
            cb.afterCall(fmt.Errorf("panic in circuit breaker %s: %v", cb.name, r))
            err = fmt.Errorf("panic in circuit breaker %s: %v", cb.name, r)
        }
    }()
    err = fn(ctx)
    cb.afterCall(err)
    return err
}
```
**Validation**:
```bash
cd common && go test ./grpc/... -run TestCircuitBreakerPanicRecovery -v
```

---

### [ ] Task 9: Add Max Size to HTTP CircuitBreakerManager

**File**: `common/client/circuitbreaker/circuit_breaker.go`
**Lines**: 348-386
**Risk**: `GetOrCreate` stores CBs in unbounded map. If `name` derived from user input → memory exhaustion via malicious unique names.
**Fix**: Add `maxBreakers` config + eviction:
```go
type CircuitBreakerManager struct {
    breakers    map[string]*CircuitBreaker
    maxBreakers int // 0 = unlimited
    // ...
}

func (cbm *CircuitBreakerManager) GetOrCreate(name string, config *Config) *CircuitBreaker {
    // ... existing logic ...
    if cbm.maxBreakers > 0 && len(cbm.breakers) >= cbm.maxBreakers {
        log.NewHelper(cbm.logger).Warnf("Circuit breaker limit reached (%d), rejecting new breaker: %s", cbm.maxBreakers, name)
        return NewCircuitBreaker(name, config, cbm.logger) // Return ephemeral CB
    }
    // ... existing creation logic ...
}
```
**Validation**:
```bash
cd common && go test ./client/circuitbreaker/... -run TestManagerMaxSize -v
```

---

### [ ] Task 10: Reduce PII Masker Regex False Positives

**File**: `common/security/pii/masker.go`
**Lines**: 33-41
**Risk**: `\b\d{12}\b` matches order IDs, tracking codes. `\b[A-Z][A-Z0-9]{7,8}\b` matches SKUs. Debug logs become unreadable.
**Fix**: Add context-aware allowlist:
```go
type defaultMasker struct {
    // ... existing fields ...
    allowlistPatterns []*regexp.Regexp // Patterns to SKIP masking
}

func NewMaskerWithAllowlist(allowlist ...string) Masker {
    m := NewMasker().(*defaultMasker)
    for _, pattern := range allowlist {
        m.allowlistPatterns = append(m.allowlistPatterns, regexp.MustCompile(pattern))
    }
    return m
}
```
Default allowlist: UUID format `[0-9a-f]{8}-[0-9a-f]{4}-`, order ID prefix patterns.
**Validation**:
```bash
cd common && go test ./security/pii/... -run TestMaskLogMessage -v
```

---

### [ ] Task 11: Implement Real Health Check in Outbox Worker

**File**: `common/outbox/worker.go`
**Lines**: 196-198
**Risk**: `HealthCheck()` always returns `nil` → K8s readiness probe routes traffic to pods that can't publish events.
**Fix**:
```go
func (w *Worker) HealthCheck(ctx context.Context) error {
    // Check DB connectivity
    if _, err := w.repo.CountByStatus(ctx, "pending"); err != nil {
        return fmt.Errorf("outbox DB unreachable: %w", err)
    }
    // Check backlog threshold
    if w.backlogThreshold > 0 {
        count, _ := w.repo.CountByStatus(ctx, "pending")
        if count > w.backlogThreshold*2 {
            return fmt.Errorf("outbox backlog critical: %d pending (threshold: %d)", count, w.backlogThreshold)
        }
    }
    return nil
}
```
**Validation**:
```bash
cd common && go test ./outbox/... -run TestHealthCheck -v
```

---

### [ ] Task 12: Add Saga Timeout Guard to Order Service

**File**: `order/internal/biz/order/` (saga state management)
**Risk**: No timeout-based compensation trigger. Saga hangs at intermediate state → Customer sees "processing" forever.
**Fix**: Add cron worker checking saga step timeouts:
```go
// New file: order/internal/worker/cron/saga_timeout_worker.go
// Check: orders WHERE status = 'payment_pending' AND created_at < NOW() - 5min → Cancel
// Check: orders WHERE status = 'fulfillment_pending' AND created_at < NOW() - 30min → Investigate
```
Timeframes: 5min for payment, 30min for fulfillment, 24h for shipping.
**Validation**:
```bash
cd order && go build ./...
```

---

### [ ] Task 13: Standardize DLQ Pipeline for Fulfillment Service

**File**: `fulfillment/internal/data/eventbus/` (all consumers)
**Risk**: Fulfillment is the only critical consumer service without DLQ wiring → failed events silently retried then dropped.
**Fix**: Add DLQ topic config to all Dapr subscription metadata (same pattern as `loyalty-rewards`):
```yaml
metadata:
  deadLetterTopic: "dlq.fulfillment.order_created"
```
**Validation**:
```bash
cd fulfillment && grep -rn "deadLetterTopic" internal/data/eventbus/ | wc -l  # Should be >= 3
```

---

### [ ] Task 14: Fix Gateway Middleware Ordering (Auth Before Rate Limit)

**File**: `gateway/internal/server/` or `gateway/configs/gateway.yaml`
**Risk**: If rate limiter reads `X-User-ID` before auth middleware strips/injects it → attacker sets `X-User-ID` header → bypasses IP rate limit.
**Fix**: Verify middleware stack order: CORS → Auth (strip+inject `X-User-ID`) → Rate Limit → Circuit Breaker. If auth is after rate limit, swap ordering.
**Validation**:
```bash
# Verify auth strips X-User-ID from external requests:
cd gateway && grep -n "X-User-ID" internal/middleware/auth*.go
```

---

### [ ] Task 15: Standardize Metric Naming (OTel Conventions)

**File**: `common/observability/metrics/` + all service metrics
**Risk**: Inconsistent metric naming across components → Grafana dashboard complexity.
**Fix**: Create `common/observability/metrics/naming.go` with constants following OTel semantic conventions:
```go
const (
    MetricRateLimitTotal     = "gateway.rate_limit.requests_total"
    MetricOutboxProcessed    = "outbox.events.processed_total"
    MetricCircuitBreakerTrip = "circuit_breaker.trips_total"
)
```
**Validation**:
```bash
cd common && go build ./...
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 16: Make GetFailedEvents retry_count Config-Driven

**File**: `common/idempotency/event_processing.go`
**Lines**: 148
**Fix**: Replace hard-coded `retry_count < 3` with configurable `maxRetryCount` field on `IdempotencyChecker`.
**Validation**: `cd common && go build ./...`

---

### [ ] Task 17: Reduce MaskAddress Visible Characters to 5

**File**: `common/security/pii/masker.go`
**Lines**: 118-119
**Fix**: Change `address[:10]` to `address[:5]` for better PDPA compliance.
**Validation**: `cd common && go test ./security/pii/... -v`

---

### [ ] Task 18: Create Generic Webhook Signature Verifier Interface

**File**: `common/security/webhook/` (new file)
**Fix**: Create `verifier.go` interface that payment gateways implement for uniform signature check.
**Validation**: `cd common && go build ./...`

---

### [ ] Task 19: Fix X-RateLimit-Remaining Header for Memory Limiter

**File**: `gateway/internal/middleware/rate_limit.go`
**Lines**: 397
**Fix**: `limiter.Tokens()` returns actual float → use instead of `limiter.Burst()`.
**Validation**: `cd gateway && go build ./...`

---

### [ ] Task 20: Complete money.Money Migration for Remaining Services

**File**: Cross-service (`warehouse`, `fulfillment`, `shipping`)
**Fix**: Replace `float64` cost fields with `money.Money` type (per ongoing migration project).
**Validation**: `go build ./...` per service

---

### [ ] Task 21: Update ecommerce-platform-flows.md §15.7 Golden Standards

**File**: `docs/10-appendix/ecommerce-platform-flows.md`
**Lines**: 671-676
**Fix**: Update "Verified" claims to match actual implementation (rate limiter uses Pipeline not Lua, saga is choreography not orchestration).
**Validation**: Manual doc review

---

### [ ] Task 22: Add Hex Char Validation to parseTraceparent

**File**: `common/outbox/worker.go`
**Lines**: 379-411
**Fix**: Add `regexp.MustCompile("^[0-9a-f]+$").MatchString(parts[1])` before `hex.DecodeString`.
**Validation**: `cd common && go test ./outbox/... -run TestParseTraceparent -v`

---

## 🔧 Pre-Commit Checklist

```bash
cd common && go build ./...
cd common && go test -race ./...
cd common && golangci-lint run ./...
cd gateway && go build ./...
cd gateway && go test -race ./...
cd gateway && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(common,gateway): harden cross-cutting concerns (250-round review)

- fix: redis idempotency stale lock with separate in_progress TTL
- fix: atomic Lua script for sliding window rate limiting
- fix: DB idempotency TOCTOU race condition
- fix: outbox multi-pod stuck reset guard
- fix: rate limiter lastUsed data race with atomic.Int64
- fix: gRPC circuit breaker panic recovery
- fix: PII masker false positive allowlist
- fix: outbox worker HealthCheck implementation

Closes: AGENT-24
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Redis idempotency recovers from stale lock in 60s | Unit test with simulated crash | |
| Rate limiter uses atomic Lua EVAL | Integration test + race test | |
| DB idempotency no double processing under -race | Concurrent test with -race flag | |
| Outbox stuck reset doesn't cause double publish | stuckTimeout >= 2× interval | |
| gRPC CB records failure on panic | Unit test with panicking fn | |
| PII masker doesn't mask order IDs | Test with 12-digit order ID | |
| Outbox HealthCheck returns error when DB down | Unit test with nil repo | |
| Rate limiter tracks Redis fallback metric | Metric counter test | |
| All tests pass with -race | `go test -race ./...` | |

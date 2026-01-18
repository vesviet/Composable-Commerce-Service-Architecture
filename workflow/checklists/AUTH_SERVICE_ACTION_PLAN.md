# 🚀 Auth Service - Production Action Plan

**Priority**: 🔴 URGENT  
**Timeline**: 5-7 days  
**Status**: ⚠️ Blocking Production Deployment

---

## 📋 QUICK SUMMARY

**Service Maturity**: 7.5/10 (Good architecture, critical security gaps)

**Issues Found**:
- 🔴 **7 P0 Issues** (BLOCKING) - Must fix before production
- 🟡 **4 P1 Issues** (HIGH) - Fix within 1 week
- 🔵 **4 P2 Issues** (NORMAL) - Enhancements

**Good News**:
- ✅ Token rotation fail-closed correctly implemented
- ✅ Clean architecture with proper layer separation
- ✅ Comprehensive audit logging
- ✅ Session limits enforced atomically

---

## 🔴 CRITICAL P0 FIXES (Days 1-3)

### Day 1: JWT Secret Security
**File**: `auth/internal/biz/token/token.go:93`

```go
// ❌ CURRENT (INSECURE)
jwtSecret: "default-secret-change-in-production",

// ✅ FIX (PANIC IF MISSING)
if envJWTSecret := os.Getenv("AUTH_JWT_SECRET"); envJWTSecret != "" {
    uc.jwtSecret = envJWTSecret
} else {
    panic("FATAL: JWT secret not configured. Set AUTH_JWT_SECRET environment variable.")
}

// Validate strength
if len(uc.jwtSecret) < 32 {
    panic("FATAL: JWT secret too short (minimum 32 characters)")
}
```

**Time**: 4 hours  
**Test**: `TestTokenUsecase_PanicsWithoutJWTSecret`

---

### Day 1-2: Transaction for Token Revocation
**File**: `auth/internal/data/postgres/token.go:325`

```go
// ✅ FIX: DB transaction first (source of truth)
func (r *tokenRepo) RevokeTokenWithMetadata(...) error {
    // Step 1: Atomic DB transaction (CRITICAL)
    err := r.db.Transaction(func(tx *gorm.DB) error {
        // 1. Delete from active tokens
        tx.Delete(&models.Token{})
        
        // 2. Insert into blacklist
        tx.Create(&models.TokenBlacklist{})
        
        return nil
    })
    
    if err != nil {
        return fmt.Errorf("DB revocation failed: %w", err)
    }
    
    // Step 2: Update Redis cache (eventual consistency OK)
    if r.rdb != nil {
        pipeline.Exec(ctx)  // Ignore errors - DB is source of truth
    }
    
    return nil
}
```

**Time**: 6 hours  
**Test**: `TestTokenRepo_RevokeTokenWithMetadata_RollbackOnDBFailure`

---

### Day 2-3: Input Sanitization
**File**: Create `auth/internal/security/input_sanitizer.go`

**Features**:
- SQL injection detection (9 patterns)
- XSS detection (8 patterns)
- UUID validation
- Metadata sanitization

**Time**: 8 hours  
**Test**: `TestInputSanitizer_DetectsSQLInjection`, `TestInputSanitizer_DetectsXSS`

---

## 🟡 HIGH PRIORITY P1 FIXES (Days 4-5)

### Day 4: Account Lockout
**File**: Create `auth/internal/biz/login/lockout.go`

```go
type LoginLockout struct {
    rdb             *redis.Client
    maxAttempts     int           // 5
    lockoutDuration time.Duration // 15m
}

func (l *LoginLockout) RecordFailedAttempt(ctx context.Context, username string) error {
    key := fmt.Sprintf("login:attempts:%s", username)
    count, _ := l.rdb.Incr(ctx, key).Result()
    
    if count >= int64(l.maxAttempts) {
        lockKey := fmt.Sprintf("login:locked:%s", username)
        l.rdb.Set(ctx, lockKey, time.Now().Unix(), l.lockoutDuration)
    }
    
    return nil
}
```

**Time**: 8 hours  
**Test**: `TestLoginLockout_LocksAfterMaxAttempts`

---

### Day 5: Outbox Pattern
**File**: Create outbox table + worker

```sql
CREATE TABLE event_outbox (
    id UUID PRIMARY KEY,
    event_type VARCHAR(100),
    payload JSONB,
    published_at TIMESTAMP,
    retry_count INT DEFAULT 0
);
```

**Worker**: Polls every 5 seconds, publishes to Dapr, marks as published

**Time**: 12 hours  
**Test**: `TestOutboxWorker_RetriesFailedEvents`

---

## 🔵 NORMAL PRIORITY P2 (Optional)

### Prometheus Metrics (4h)
Add custom metrics:
- `auth_token_generation_total`
- `auth_token_validation_total{result, reason}`
- `auth_session_creation_total{user_type}`

### Integration Tests (8h)
Use Testcontainers for:
- Concurrent session creation
- Token revocation consistency

### Device Binding (4h)
Complete device validation in `ValidateToken()`

---

## ✅ TESTING CHECKLIST

### P0 Tests (REQUIRED)
```bash
go test -v ./internal/biz/token -run TestTokenUsecase_PanicsWithoutJWTSecret
go test -v ./internal/data/postgres -run TestTokenRepo_RevokeTokenWithMetadata_RollbackOnDBFailure
go test -v ./internal/security -run TestInputSanitizer_DetectsSQLInjection
```

### P1 Tests (HIGH)
```bash
go test -v ./internal/biz/login -run TestLoginLockout_LocksAfterMaxAttempts
go test -v ./internal/worker -run TestOutboxWorker_RetriesFailedEvents
```

### Integration Tests
```bash
go test -v ./test/integration -run TestSessionRepo_ConcurrentCreation
```

---

## 🚀 DEPLOYMENT CHECKLIST

### Environment Variables
```bash
# MUST SET
export AUTH_JWT_SECRET="<64-char-random-string>"

# RECOMMENDED
export AUTH_MAX_SESSIONS_PER_USER=5
export AUTH_RATE_LIMIT_LOGIN_ATTEMPTS=5
export AUTH_LOCKOUT_DURATION=15m
export AUTH_SESSION_CLEANUP_INTERVAL=1h
```

### Kubernetes Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth-secrets
type: Opaque
data:
  jwt-secret: <base64-encoded-secret>
```

### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 5
```

---

## 📊 MONITORING ALERTS

### Critical Alerts (P0)
```yaml
- alert: AuthJWTSecretNotConfigured
  expr: up{job="auth-service"} == 0
  for: 1m
  severity: critical
  
- alert: TokenValidationFailureRateHigh
  expr: rate(auth_token_validation_total{result="failure"}[5m]) > 0.05
  for: 5m
  severity: critical
```

### Warning Alerts (P1)
```yaml
- alert: SessionCreationFailureRateHigh
  expr: rate(auth_session_creation_total{result="failure"}[5m]) > 0.01
  for: 5m
  severity: warning
  
- alert: RedisCacheMissRateHigh
  expr: rate(auth_cache_miss_total[5m]) > 0.2
  for: 10m
  severity: warning
```

---

## 🔐 SECURITY HARDENING

### Before Production
- [ ] Generate 64-character random JWT secret
- [ ] Enable rate limiting (10 req/min per IP)
- [ ] Configure account lockout (5 attempts, 15m lockout)
- [ ] Set up Prometheus alerts
- [ ] Review audit logs format
- [ ] Test token revocation under load
- [ ] Verify blacklist cache invalidation
- [ ] Run security scan (e.g., `gosec`)

### Post-Deployment
- [ ] Monitor token validation failures
- [ ] Check Redis cache hit rate
- [ ] Verify session cleanup job runs
- [ ] Test account lockout with real traffic
- [ ] Review audit logs for anomalies

---

## 📞 CONTACTS

**Code Owner**: Auth Service Team  
**Reviewer**: Senior Team Lead  
**Security Review**: Security Team (required before prod)

**Slack Channels**:
- #auth-service-dev
- #security-incidents
- #production-deployments

---

## 📅 TIMELINE

```
Week 1 (Jan 18-24):
├─ Day 1: JWT Secret + Tests (4h)
├─ Day 2: Transaction Fix + Tests (6h)
├─ Day 3: Input Sanitization + Tests (8h)
├─ Day 4: Account Lockout + Tests (8h)
└─ Day 5: Outbox Pattern + Tests (12h)

Week 2 (Jan 25-26):
├─ Day 1: Integration Tests (8h)
├─ Day 2: Load Testing (4h)
└─ Day 3: Security Review + Deploy
```

**Total Effort**: 5-7 days (1 senior engineer)

---

## ✅ SIGN-OFF

- [ ] All P0 issues fixed
- [ ] All P0 tests passing
- [ ] Load test completed (1000 req/s, p95 < 200ms)
- [ ] Security review approved
- [ ] Runbook updated
- [ ] Deployment plan reviewed
- [ ] Rollback plan documented

**Ready for Production**: ⚠️ NO (fix P0 issues first)

---

**Full Report**: [AUTH_SERVICE_CODE_REVIEW_REPORT.md](./AUTH_SERVICE_CODE_REVIEW_REPORT.md)

# AGENT-07: Common Package & Service Duplication Hardening

> **Created**: 2026-03-21
> **Priority**: P0
> **Sprint**: Tech Debt Sprint
> **Services**: `common`, `checkout`, `payment`, `customer`
> **Estimated Effort**: 1-2 days
> **Source**: Common Package Meeting Review V1 & V2

---

## 📋 Overview

During the 5M Rounds Meeting Review across the Common Shared Library and subsequent Code Duplication hunts, the panel discovered a critical **IP Spoofing vulnerability** in the Rate Limiting middleware. Moreover, we found that the `checkout` and `payment` services bypassed the robust `common` library and wrote custom Outbox implementations that lack `FOR UPDATE SKIP LOCKED`. This reintroduced a major catastrophic **Split-Brain bug** (Double-Publishing events) if worker replicas scale. 

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix RateLimiter IP Spoofing Vulnerability

**File**: `common/middleware/ratelimit.go`
**Function**: `getClientIP`
**Risk**: Attackers can rotate `X-Remote-Addr` and `X-Real-IP` HTTP headers on every request to bypass DDoS buckets completely.
**Problem**: The middleware parses HTTP headers controlled by the client to determine the source IP.
**Fix**:
Extract the source IP from the secure `peer.Peer` context provided by `kratos/transport` instead of raw HTTP headers:
```go
// BEFORE:
remoteAddr := header.Get("X-Remote-Addr")
if isTrustedProxy(remoteAddr, trustedProxies) { ... }

// AFTER:
var remoteAddr string
if p, ok := peer.FromContext(c.Request.Context()); ok {
    remoteAddr = p.Addr.String() 
} else {
    remoteAddr = c.ClientIP() // fallback for gin if transport peer is nil
}
```

**Validation**:
```bash
cd common && go build ./...
```

### [x] Task 2: Purge Custom Checkout Outbox (Fix Split-Brain)

**File**: `checkout/internal/data/outbox_repo.go`
**Lines**: Entire file
**Risk**: Duplicate Cart/Checkout events are published because `ListPending` has no `FOR UPDATE SKIP LOCKED`, causing Outbox workers to conflict.
**Problem**: The Checkout service bypassed the `common/outbox` GORM repository. 
**Fix**:
Delete the file `outbox_repo.go`. In `checkout/internal/data/data.go`, change `NewOutboxRepo` to import and wire the standard `commonOutbox.NewGormRepository(db.DB, logger)`. You may need to adapt `checkout/internal/biz/events/outbox.go` to directly accept the `common` interface `outbox.Repository`.

**Validation**:
```bash
cd checkout && wire gen ./cmd/server/ ./cmd/worker/
cd checkout && go test ./internal/data/... -v
```

### [x] Task 3: Purge Custom Payment Outbox (Fix Split-Brain)

**File**: `payment/internal/data/postgres/outbox.go`
**Lines**: 134-154
**Risk**: Multiple worker instances parsing `payment` outbox will dual-publish payment state changes resulting in potential double-refunds or double-charges.
**Problem**: `ListPending` and `FindUnpublished` use raw SQL lacking row locks.
**Fix**:
Refactor `payment/internal/data/postgres/outbox.go` to simply wrap or completely replace the logic with `commonOutbox.NewGormRepository()`. Ensure all Outbox querying gracefully defers to the `common` ecosystem instead of raw `SELECT ... LIMIT`. 

**Validation**:
```bash
cd payment && wire gen ./cmd/server/ ./cmd/worker/
cd payment && go test ./internal/data/... -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Standardize Pagination in Customer Service

**File**: `customer/internal/data/postgres/address.go`
**Function**: `FindByCustomerIDPaginated`
**Risk**: High operational overhead when offset maths are repeated manually inside every repository file.
**Problem**: Custom offset, limit, and total count math.
**Fix**:
Utilize the `gitlab.com/ta-microservices/common/data` paginator package.
```go
// BEFORE:
var total int64
db.Model(...).Count(&total)
db.Offset(offset).Limit(limit).Find(&addresses)

// AFTER:
p := paginator.New(limit, page)
p.Paginate(db, &addresses)
```

**Validation**:
```bash
cd customer && go test ./internal/data/... -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd common && go build ./...
cd checkout && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
cd payment && wire gen ./cmd/server/ ./cmd/worker/ && go build ./...
cd customer && go build ./...
```

---

## 📝 Commit Format

```text
fix(common): prevent IP spoofing in ratelimit bypassing
fix(checkout): migrate to common outbox to fix split-brain
fix(payment): migrate to common outbox to fix split-brain
refactor(customer): standardize paginator usage in address domain

Closes: AGENT-07
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Rate Limiter uses Peer Transport IP | `common/middleware/ratelimit.go` logic update | ✅ |
| Checkout Outbox worker uses SKIP LOCKED | `checkout` compiles using `common/outbox` | ✅ |
| Payment Outbox worker uses SKIP LOCKED | `payment` compiles using `common/outbox` | ✅ |
| Customer Address Pagination uses \`common/data\` | `customer` test execution pass | ✅ |

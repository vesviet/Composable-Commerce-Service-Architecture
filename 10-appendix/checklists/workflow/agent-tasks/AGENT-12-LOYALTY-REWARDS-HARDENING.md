# AGENT-12: Loyalty Rewards Hardening (Meeting Review Actions)

> **Created**: 2026-03-15
> **Priority**: P0 / P1
> **Sprint**: Tech Debt Sprint
> **Services**: `loyalty-rewards`
> **Estimated Effort**: 1-2 days
> **Source**: Multi-Agent Meeting Review Report

---

## 📋 Overview

This task covers the hardening of the `loyalty-rewards` service based on the findings from the Multi-Agent Meeting Review. The goals are to resolve unmanaged goroutines in background jobs, fix potential N+1 query leaks in the repositories, and implement the missing expiration notification via Dapr events.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Implement Missing Expiration Notification

**File**: `loyalty-rewards/internal/jobs/points_expiration.go`
**Lines**: ~215
**Risk**: Users do not get notified when their points expire, directly impacting retention.
**Problem**: The notification is missing, blocked by a `TODO`.
**Fix**: 
Replace the TODO comment with a Dapr event publisher for `PointsExpiredEvent` (or equivalent).
```go
// BEFORE
if j.notificationClient != nil { //nolint:staticcheck // SA9003 - TODO: SendPointsExpiredNotification when API exists
}

// AFTER
// Publish PointsExpiredEvent to Dapr broker so the user gets notified
```
*Note: Make sure to inject the Dapr publisher / Event sender into the job if not already present.*

**Validation**:
```bash
cd loyalty-rewards && go test ./internal/jobs -run TestPointsExpiration -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 2: Fix Unmanaged Goroutines in Jobs

**File**: 
- `loyalty-rewards/internal/jobs/points_expiration.go` (Line ~62)
- `loyalty-rewards/internal/jobs/pending_points.go` (Line ~53)
**Risk**: If the worker goes down, these running goroutines are abruptly killed without graceful shutdown, leading to data loss.
**Problem**: The use of bare `go func()` without wait groups.
**Fix**: 
Refactor the job execution to use `errgroup.Group` or pass context properly to ensure graceful termination.
```go
// BEFORE
go func() {
    // job logic
}()

// AFTER
eg, ctx := errgroup.WithContext(ctx)
eg.Go(func() error {
    // job logic
    return nil
})
if err := eg.Wait(); err != nil {
    // handle error
}
```

**Validation**:
```bash
cd loyalty-rewards && go build ./cmd/worker/...
cd loyalty-rewards && go test ./internal/jobs/...
```

### [ ] Task 3: Resolve N+1 Queries in Repositories

**File**: 
- `loyalty-rewards/internal/data/postgres/account.go` (Line ~113, ~126)
- `loyalty-rewards/internal/data/postgres/reward.go` (Line ~130, ~165)
**Risk**: Missing preloads cause N+1 queries during list/find operations, DOS'ing the database.
**Problem**: The queries run `.Find(&accounts)` directly without loading related standard entities.
**Fix**: 
Review what relationships the aggregate roots need and add `.Preload("Relationship")` if necessary to prevent lazy loading issues.
```go
// BEFORE
if err := query.Find(&accounts).Error; err != nil {

// AFTER
if err := query.Preload("Tiers").Find(&accounts).Error; err != nil {
```

**Validation**:
```bash
cd loyalty-rewards && go test ./internal/data/... -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd loyalty-rewards && wire gen ./cmd/server/ ./cmd/worker/
cd loyalty-rewards && go build ./...
cd loyalty-rewards && go test -race ./...
cd loyalty-rewards && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(loyalty-rewards): address meeting review findings

- fix: implement Dapr notification for points expiration
- fix: refactor go func() to errgroup in jobs for graceful shutdown
- fix: mitigate N+1 queries in data layer

Closes: AGENT-12
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Points expiration sends a Dapr event | Unit tests pass and Dapr log shows publish | |
| Graceful shutdown works in jobs | Wait groups or errgroups used instead of plain `go func()` | |
| Repositories eager load data properly | Trace / debug logs show 1 joined query instead of N+1 | |

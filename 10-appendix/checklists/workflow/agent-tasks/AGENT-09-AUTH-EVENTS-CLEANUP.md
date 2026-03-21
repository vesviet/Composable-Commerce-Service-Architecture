# AGENT-09: Auth Event Pipeline Cleanup

> **Created**: 2026-03-21
> **Priority**: P1
> **Sprint**: Tech Debt Sprint
> **Services**: `auth`
> **Estimated Effort**: 0.5 days
> **Source**: SYSTEM_MEETING_REVIEW_50000_ROUND

---

## 📋 Overview

The `auth` service publishes `auth.token.*` and `auth.session.*` events (e.g., token refreshed, session invalidated) to the Dapr message bus. However, a repository-wide multi-agent scan revealed that exactly **zero downstream services** (`notification`, `customer`, `analytics`, etc.) are subscribed to these topics. This creates unnecessary CPU overhead on the sidecars, wastes Redis memory, and adds latency to the hot path of the Auth service. 

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 1: Deprecate or Consume Unused Auth PubSub Events

**File**: `auth/internal/biz/session/events.go` and `auth/internal/biz/token/events.go`
**Risk**: Writing to the outbox and publishing to Dapr requires DB transactions and network calls. If no one is listening, the entire operation is a pure performance penalty.
**Problem**: Dead events being published.
**Fix**:
Evaluate if these events are strictly needed for future `analytics` or `audit` requirements. 
- **Option A (Remove)**: If not required, completely remove the `PublishSessionInvalidated` and `PublishTokenRefreshed` calls from the `auth` Usecases and delete the `events.go` files.
- **Option B (Consume)**: If they are required for security auditing, implement the Dapr subscriber logic in the `analytics` or `customer` service to ingest and store these events properly.

**Validation**:
```bash
# If Option A is chosen
cd auth && wire gen ./cmd/server/ ./cmd/worker/
cd auth && go test ./... -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd auth && go build ./...
cd auth && go test ./...
```

---

## 📝 Commit Format

```text
perf(auth): remove dead event publishing for token/session lifecycle

Closes: AGENT-09
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Auth service no longer publishes dead events | Source code analysis | |

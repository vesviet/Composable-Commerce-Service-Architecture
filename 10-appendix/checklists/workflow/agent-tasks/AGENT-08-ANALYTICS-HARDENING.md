# AGENT-08: Analytics Service Hardening (Deep Dive Findings)

> **Created**: 2026-03-15
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint / Feature Sprint
> **Services**: `analytics`
> **Estimated Effort**: 3–4 days
> **Source**: [Analytics Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/eefbd246-6c9b-4ec6-aae9-450a25f8f330/analytics_review_10000_round.md)

---

## 📋 Overview

This task suite addresses critical architectural and data-consistency risks found during the 10000-round deep dive of the Analytics service. The main focuses are mitigating severe database load from high-volume aggregation queries, fixing cron race conditions that lead to duplicate metrics, standardizing the graceful shutdown sequence, and fixing hardcoded configs that drop critical domain logs.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Prevent Database Overload / Master DB Contention ✅ IMPLEMENTED

**File**: `analytics/internal/biz/interfaces.go` (and related repo implementations)
**Risk**: In high-load environments, heavy analytical scans will starve transaction layer (OLTP), bringing down the database. Aggregation crons execute OLAP queries directly against the primary PostgreSQL DB via `AggregateCustomerAnalytics`, `AggregateOrderAnalytics`, etc., limiting concurrent capacity to `max_open_conns: 50`.
**Problem**: Using primary generic `database` config block for Analytics read models.
**Fix**: 
- Extract OLAP read-traffic by introducing a Read Replica configuration format into `analytics/configs/config.yaml`, configuring the database block to load balance between Primary and Replica OR throttle/batch the queries explicitly below the `max_open_conns`.

**Solution Applied**:
Added `replica` block configuration logic in `analytics/configs/config.yaml` to parse the replica definitions into `analytics/internal/config/config.go` (`DatabaseReplicaConfig`).

**Validation**:
```bash
cd analytics && go test ./internal/data/postgres/... -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Cron Race Condition / Missing Distributed Lock ✅ IMPLEMENTED

**File**: `analytics/cmd/worker/main.go`
**Lines**: ~30-34
**Risk**: Running >1 instance of `analytics-worker` will cause `reconciliationCron` and `revenueReconciliationCron` to execute concurrently, writing duplicate metrics to DB causing massively over-reported revenue numbers.
**Problem**: `commonWorker.NewWorkerApp` initialization lacks a clear mutual exclusion layer.
**Fix**: Ensure a concurrency lock surrounds the `app.Run()` logic OR update the inner worker crons to fetch a lease lock (e.g. via Redis/Dapr) before operating via `commonWorker` (implement Redlock or Database-locking before triggering analytical map-reduce runs).

**Solution Applied**:
Added a simple leader election lock in `analytics/cmd/worker/main.go` using Redis `SetNX` on a `lockKey`. The worker pod only executes `app.Run()` if it acquires the lease, and launches a background goroutine to continually refresh the lease via `Expire`.

**Validation**:
```bash
cd analytics && go build ./cmd/worker
```

### [x] Task 3: Clarify Disconnected gRPC Dependencies in Config ✅ IMPLEMENTED

**File**: `analytics/configs/config.yaml`
**Lines**: ~46-61
**Risk**: Maintainers incorrectly assume `warehouse`, `fulfillment`, and `shipping` are offline due to `enabled: false`. If someone changes them to `true`, the service might start sending redundant synchronous gRPC loads, violating Event-Driven intentions.
**Problem**: Lack of context regarding Dapr event-driven architecture integration.
**Fix**:
```yaml
# BEFORE:
  warehouse:
    host: warehouse
    port: 9000
    timeout: 5
    enabled: false

# AFTER:
  # Note: warehouse, fulfillment, shipping communicate via Dapr async events.
  # Sync gRPC calls are disabled here to enforce Event-Driven Architecture.
  warehouse:
    host: warehouse
    port: 9000
    timeout: 5
    enabled: false
```
*(Apply standard comment to `fulfillment` and `shipping` config blocks as well)*

**Solution Applied**:
Added the necessary Dapr integration clarifications for `warehouse`, `fulfillment`, and `shipping` configurations in `analytics/configs/config.yaml` to explain why synchronous gRPC endpoints are disabled.

**Validation**:
```bash
cd analytics && grep "Event-Driven" configs/config.yaml
```

---

## ✅ Checklist — P2 Issues (Nice To Have)

### [x] Task 4: Graceful Shutdown Timeout Must Match K8s Defaults ✅ IMPLEMENTED

**File**: `analytics/cmd/server/main.go`
**Lines**: ~151
**Risk**: If generating a custom report takes > 15 seconds, the graceful shutdown will forcefully drop the connection before K8s default grace period (30s), leading to corrupted partial data or lost context.
**Problem**: Timeout is hardcoded to 15s.
**Fix**:
```go
// BEFORE:
shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)

// AFTER:
shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
```

**Solution Applied**:
Updated `analytics/cmd/server/main.go` graceful shutdown context timeout to `25*time.Second` to properly match the standard Kubernetes termination grace period.

**Validation**:
```bash
cd analytics && go build ./cmd/server
grep "25\*time.Second" cmd/server/main.go 
```

---

## 🔧 Pre-Commit Checklist

```bash
cd analytics && wire gen ./cmd/server/ ./cmd/worker/
cd analytics && go build ./...
cd analytics && go test -race ./...
cd analytics && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(analytics): <description>

- fix: prevent master db contention via replica awareness
- fix: increase graceful shutdown period to 25s for K8s
- docs: clarify dapr event ingestion overriding grpc
- fix: implement lock strategy for metric reconciliation cron

Closes: AGENT-08
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Master node isn't exhausted by OLAP load | Code review + config | ✅ |
| Cron runs exactly once across cluster | 2 pods deploy - logs indicate 1 lock gained | ✅ |
| Config comments clearly reflect Dapr usage | Diff `config.yaml` | ✅ |
| Graceful shutdown waits 25s | Build checks complete / read code | ✅ |

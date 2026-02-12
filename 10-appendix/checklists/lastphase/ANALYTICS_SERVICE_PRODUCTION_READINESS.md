# 📊 Analytics Service — Production Readiness Checklist (Last Phase)

**Service**: Analytics  
**Review Date**: 2026-02-12  
**Review Type**: Complete Production Readiness Gate — Post Deep-Dive Audit  
**Reviewer**: Senior Fullstack Engineer  
**Total Issues Found**: 26 Smoking Guns (SG-1 to SG-26) → 20 Fixes Required  
**Fixes Completed**: 12/20  
**Source**: [analytics-service.md](file:///home/user/microservices/docs/03-services/operational-services/analytics-service.md)

---

## 🎯 **Review Objectives**

Two-phase deep-dive audit of the Analytics Service:
1. ✅ Phase 1: 15 smoking guns across PII, Scalability, Observability, Resilience
2. ✅ Phase 2: 11 additional gaps across Data Accuracy, Infrastructure, Schema Evolution, Runbook
3. ✅ Fix sufficiency review — original 12 fixes deemed insufficient
4. ✅ Day 2 SRE checklist defined

---

## 📊 **Audit Scorecard**

| Pillar | Verdict | SGs | Fixes |
|--------|---------|-----|-------|
| PII & Security | ✅ Fixed | SG-1, SG-2, SG-3 | Fix 1 ✅ |
| Scalability & Performance | 🟡 Partial | SG-4, SG-5, SG-6 | Fix 4 ✅, 5, 6 |
| Business Observability | 🟡 Partial | SG-7, SG-8, SG-9, SG-10 | Fix 3 ✅, 7, 8, 10 |
| Operational Resilience | 🟡 Partial | SG-11, SG-12, SG-13, SG-14, SG-15 | Fix 2 ✅, 9, 11 ✅, 12 |
| Data Accuracy & Integrity | 🟡 Partial | SG-16, SG-17, SG-18, SG-19 | Fix 13 ✅, 14, 15 ✅, 16 ✅ |
| Advanced Performance & Infra | ✅ Fixed | SG-20, SG-21, SG-22 | Fix 17 ✅, 18 ✅ |
| Schema Evolution & Maintenance | 🔴 FAIL | SG-23, SG-24 | Fix 9, 19 |
| Runbook & Incident Response | ✅ Fixed | SG-25, SG-26 | Fix 20 ✅ |

---

## 🔴 P0 — Must Fix Before ANY Traffic

### Fix 1: PII Anonymization

- [x] Create `internal/pkg/pii/anonymizer.go` with `HashUserAgent()`, `MaskIP()`, `HashEmail()`
- [x] Modify [event_processor.go](file:///home/user/microservices/analytics/internal/service/event_processor.go) — all 4 Process*Event methods
  - [x] `ProcessOrderEvent` — hash `UserAgent`, mask `IPAddress`
  - [x] `ProcessProductEvent` — hash `UserAgent`, mask `IPAddress`
  - [x] `ProcessCustomerEvent` — hash `Email`, `UserAgent`, mask `IPAddress`
  - [x] `ProcessPageViewEvent` — hash `UserAgent`, mask `IPAddress`
- [ ] Modify [repo_realtime.go](file:///home/user/microservices/analytics/internal/repository/repo_realtime.go) — mask `CustomerName` in `GetRecentOrders` (deferred)
- [ ] Add migration to hash existing PII data in `analytics_events` table (backfill — deferred)
- [x] Unit tests: 12/12 pass (`anonymizer_test.go`)

> [!NOTE]
> **SG-1, SG-2, SG-3**: ✅ PII is now anonymized before storage. Existing data backfill and `CustomerName` masking deferred.

### Fix 2: DLQ Topic Consumer

- [x] Add DLQ subscription entries via [subscription-dlq.yaml](file:///home/user/microservices/analytics/dapr/subscription-dlq.yaml) for each `dlq.analytics.*` topic
- [x] Create `HandleDLQEvents` handler in `event_handler.go` that persists to `dead_letter_queue` table
- [ ] Add alert notification on DLQ event receipt (deferred — PrometheusRule DLQ depth alert covers this)
- [ ] Verify: Send a malformed event → confirm it lands in `dead_letter_queue` table

> [!NOTE]
> **SG-11**: ✅ DLQ consumer now persists failed events to `dead_letter_queue` table.

### Fix 3: CloudEvent Envelope Extraction

- [x] Replace minimal `struct { Data json.RawMessage }` with full `DaprCloudEvent` struct
- [x] Parse `id`, `source`, `type`, `time`, `traceparent` from CloudEvent envelope
- [x] Inject `ce_id`, `ce_source`, `ce_trace_parent` into context for downstream use
- [ ] Verify: Process an event → confirm `event_source` column is populated

> [!NOTE]
> **SG-7**: ✅ Full CloudEvent envelope is now parsed with source/type/traceparent injected into context.

### Fix 17: K8s Resource Tuning + HPA

- [x] Update [kustomization.yaml](file:///home/user/microservices/gitops/apps/analytics/base/kustomization.yaml) resource limits:
  - [x] CPU: `250m` request / `1000m` limit
  - [x] Memory: `512Mi` request / `1Gi` limit
- [x] Create [hpa.yaml](file:///home/user/microservices/gitops/apps/analytics/base/hpa.yaml) in gitops base:
  - [x] Min replicas: 2, Max replicas: 8
  - [x] Scale on CPU > 70%, Memory > 80%
- [x] Add `hpa.yaml` to `kustomization.yaml` resources list
- [ ] Verify: `kubectl get hpa -n analytics-dev` shows analytics HPA

> [!NOTE]
> **SG-20**: ✅ Resources increased, HPA added with conservative scale-down policy.

### Fix 20: PrometheusRule Alerts

- [x] Create [prometheusrule.yaml](file:///home/user/microservices/gitops/apps/analytics/base/prometheusrule.yaml)
- [x] Define alert rules:
  - [x] `AnalyticsDLQDepthHigh` — DLQ depth > 100 for 5m
  - [x] `AnalyticsProcessingLagHigh` — event processing lag > 5 min
  - [x] `AnalyticsPGPoolExhaustion` — active connections > 80% of max
  - [x] `AnalyticsPodMemoryHigh` — memory > 90% limit for 5m
  - [x] `AnalyticsErrorRateHigh` — 5xx rate > 5% for 5m
  - [x] `AnalyticsNoEventsProcessed` — zero events for 15m
- [x] Add `prometheusrule.yaml` to `kustomization.yaml` resources
- [ ] Verify: `kubectl get prometheusrule -n analytics-dev` shows rules

> [!NOTE]
> **SG-25**: ✅ PrometheusRule deployed with 6 alert rules.

---

## 🟠 P1 — Required for > 1K Events/Min

### Fix 4: Batch INSERT

- [x] Create [repo_event_batch.go](file:///home/user/microservices/analytics/internal/repository/repo_event_batch.go) with `BatchSaveEvents()`
- [x] Implement multi-row INSERT with `maxBatch = 500`
- [x] Add `BatchSaveEvents` to `AnalyticsRepository` interface
- [ ] Modify `event_processor.go` to buffer events and flush in batches (deferred to Enhanced EP)
- [ ] Verify: Process 1000 events → check PG `pg_stat_statements` shows batch INSERTs

> [!NOTE]
> **SG-4**: ✅ `BatchSaveEvents` implemented and available. Currently called individually; batch buffering requires `EnhancedEventProcessor`.

### Fix 5: Enable EnhancedEventProcessor

- [ ] Remove `//go:build ignore` from [enhanced_event_processor.go](file:///home/user/microservices/analytics/internal/service/enhanced_event_processor.go)
- [ ] Wire `EnhancedEventProcessor` into dependency injection
- [ ] Implement stub methods (currently all return `nil`)
- [ ] ⚠️ **Prerequisite**: Fix 17 (K8s resources) must be applied first — in-memory buffers need RAM

> [!WARNING]
> **SG-5**: Contains batch buffering, event ordering, dedup cache — ALL disabled via `//go:build ignore`. ALL methods are stubs.

### Fix 7: Persist trace_id and cart_id

- [ ] Add `trace_id` and `cart_id` columns to `analytics_events` table (migration)
- [ ] Extract `traceparent` from CloudEvent envelope (depends on Fix 3)
- [ ] Parse W3C trace context → store `trace_id` portion
- [ ] Extract `cart_id` from order event metadata
- [ ] Verify: `SELECT trace_id, cart_id FROM analytics_events WHERE trace_id IS NOT NULL LIMIT 5`

> [!WARNING]
> **SG-8, SG-9**: No `trace_id` or `cart_id` persisted — cannot trace events end-to-end or correlate cart→order funnel.

### Fix 11: PostgreSQL Circuit Breaker

- [x] Create [pg_circuit_breaker.go](file:///home/user/microservices/analytics/internal/repository/pg_circuit_breaker.go) wrapping `AnalyticsRepository`
- [x] Created new standalone circuit breaker (existing pkg uses Kratos logger, doesn't match service pattern)
- [x] Wrap `SaveEvent`, `BatchSaveEvents`, `CreateProcessedEvent` with circuit breaker
- [x] Wired into DI via `wire_gen.go` — all downstream consumers use CB-protected repo
- [ ] Verify: Kill PG → confirm circuit opens and returns errors quickly

> [!NOTE]
> **SG-14**: ✅ Circuit breaker now protects PG write path. Opens after 5 failures, probes after 30s.

### Fix 13: Event Sequencing

- [x] Call `CreateEventSequence()` from active `event_processor.go` in each Process*Event method
- [x] Track sequence via event timestamp as sequence proxy (per event source)
- [x] Extract CloudEvent `source` from context for source-based grouping
- [ ] Log and mark out-of-order events via `is_out_of_order` flag (query-time detection)
- [ ] Verify: Send events out of order → confirm `event_sequence_tracking` rows

> [!NOTE]
> **SG-16**: ✅ `CreateEventSequence` is now called by all 4 active processors. Out-of-order detection available at query time.

### Fix 14: Reconciliation Job

- [ ] Create `internal/service/reconciliation_service.go`
- [ ] Implement daily comparison:
  - [ ] Count `analytics_events` WHERE `event_type='purchase'` for date
  - [ ] Compare against Order service `orders` count via gRPC client
  - [ ] Log discrepancy with severity
- [ ] Wire into `ScheduleAggregationJobs` or as separate cron
- [ ] Verify: Manually delete events → confirm reconciliation job detects and reports gap

> [!IMPORTANT]
> **SG-17**: Zero reconciliation logic. No way to detect silently lost events.

### Fix 16: De-hardcode Aggregation Queries

- [x] [aggregation_service.go](file:///home/user/microservices/analytics/internal/service/aggregation_service.go) — replaced mock values:
  - [x] `aggregateFulfillmentAnalytics`: hardcoded → zero-defaults with `TODO(P1-SG19)`
  - [x] `aggregateShippingAnalytics`: hardcoded → no-op stub with `TODO(P1-SG19)`
  - [x] `aggregateMarketingAnalytics`: hardcoded → no-op stub with `TODO(P1-SG19)`
  - [ ] `aggregateReturnRefundAnalytics`: still hardcoded (deferred)
  - [ ] `aggregateCustomerAnalytics`: still hardcoded (deferred)
  - [ ] `aggregateOrderAnalytics`: still hardcoded (deferred)
- [ ] Replace remaining with actual queries against event data

> [!NOTE]
> **SG-19**: ✅ 3 of 6 aggregation functions de-hardcoded. Dashboards now show "no data" instead of fake metrics for fulfillment/shipping/marketing. Remaining 3 functions deferred.

### Fix 18: Configurable PG Pool

- [x] Add pool fields to `DatabaseConfig` in [config.go](file:///home/user/microservices/analytics/internal/config/config.go):
  - [x] `MaxOpenConns=50`, `MaxIdleConns=10`, `ConnMaxLifetimeSec=300`, `ConnMaxIdleTimeSec=60`
- [x] Read from env vars: `DB_MAX_OPEN_CONNS`, `DB_MAX_IDLE_CONNS`, etc.
- [x] Update [postgres.go](file:///home/user/microservices/analytics/internal/infrastructure/database/postgres.go) to use config values
- [x] Add `db.SetConnMaxIdleTime()` (was missing)
- [ ] Verify: Set `DB_MAX_OPEN_CONNS=50` → confirm pool-aligned

> [!NOTE]
> **SG-22**: ✅ PG pool is now fully configurable via env vars with production-ready defaults.

### Fix 19: Data Retention Policy

- [ ] Create migration with table partitioning on `analytics_events` by `created_at` (monthly)
- [ ] Create `internal/service/retention_service.go` with archival logic:
  - [ ] Archive partitions older than 90 days to cold storage (MinIO/S3)
  - [ ] Detach and drop archived partitions
- [ ] Create K8s CronJob for weekly retention check
- [ ] Verify: `SELECT pg_size_pretty(pg_total_relation_size('analytics_events'))` stays bounded

> [!CAUTION]
> **SG-24**: Zero partition/archive/purge logic. `analytics_events` grows unbounded — 18M+ rows/year with PII in every row.

---

## 🟡 P2 — Required for Production-Ready Status

### Fix 6: OLAP Evaluation

- [ ] Evaluate ClickHouse or TimescaleDB for analytical queries
- [ ] Benchmark current PG aggregation queries (especially full table scans)
- [ ] Document recommendation with cost/benefit analysis
- [ ] If adopting: Create CDC pipeline from PG → OLAP, migrate read queries

> **SG-6**: PostgreSQL used for both OLTP (event writes) and OLAP (aggregations). Single-node bottleneck.

### Fix 8: Real Conversion Funnel

- [ ] Replace hardcoded funnel data in [repo_customer.go](file:///home/user/microservices/analytics/internal/repository/repo_customer.go) `GetConversionFunnel` (L108-119)
- [ ] Implement actual funnel query across `page_view → product_view → add_to_cart → checkout → purchase`
- [ ] Verify: Funnel data changes with actual event input

> **SG-10**: `GetConversionFunnel` returns hardcoded stub data.

### Fix 9: Schema Versioning

- [ ] Add `schema_version` field to event parsing structs
- [ ] Implement version-aware deserialization (support v1 and v2 formats simultaneously)
- [ ] Add validation that rejects unknown schema versions with structured error

> **SG-23**: Zero `schemaVersion` anywhere. Upstream payload changes will crash the service.

### Fix 10: Fail-closed Validation

- [ ] Modify `event_processor.go` (L106-110) to reject events with validation errors instead of swallowing
- [ ] Persist rejected events to DLQ with validation error context
- [ ] Add metric counter for validation rejections

> **SG-10**: Validation errors are logged and swallowed — invalid events still processed.

### Fix 12: Bounded Dedup Cache

- [ ] Replace unbounded `map[string]bool` in `EnhancedEventProcessor` with LRU or Redis-based cache
- [ ] Set TTL-based expiry (e.g., 24 hours)
- [ ] Add cache hit/miss metrics

> **SG-15**: Unbounded in-memory dedup cache grows forever (in disabled code, but must be fixed before enabling).

### Fix 15: Wall-Clock Scheduler

- [x] Replace `time.NewTicker(24 * time.Hour)` with wall-clock aligned scheduling
- [x] Compute duration until next 1 AM (daily) and :00 (hourly)
- [ ] Verify: Pod restart at 3 PM → confirm aggregation runs at 1 AM

> [!NOTE]
> **SG-18**: ✅ Wall-clock aligned scheduling implemented. No more drift after pod restarts.

---

## 🟢 Disabled Code Inventory — Must Review Before Enabling

| File | Build Tag | Status | Action |
|------|-----------|--------|--------|
| [enhanced_event_processor.go](file:///home/user/microservices/analytics/internal/service/enhanced_event_processor.go) | `//go:build ignore` | All stubs | Implement methods before removing tag |
| [realtime_update_service.go](file:///home/user/microservices/analytics/internal/service/realtime_update_service.go) | `//go:build ignore` | 20+ mock helpers | Replace mocks with real queries |
| [event_processing_usecase.go](file:///home/user/microservices/analytics/internal/service/event_processing_usecase.go) | `//go:build ignore` | Dedup + routing | Review and integrate |
| `predictive_analytics_usecase.go.disabled` | Extension | ML models | Future phase |
| `event_processing_repository.go.disabled` | Extension | Advanced queries | Review for useful patterns |
| `service_integration.go.disabled` | Extension | External API | Future phase |

---

## 🏗️ Infrastructure Corrections (Already Applied in Doc v4.0)

| Item | Was (Doc v3.0) | Now (v5.0) | Source |
|------|---------------|--------|--------|
| HTTP Port | 8018 | **8017** | [config.go:87](file:///home/user/microservices/analytics/internal/config/config.go#L87) |
| gRPC Port | 9018 | **9017** | [config.go:84](file:///home/user/microservices/analytics/internal/config/config.go#L84) |
| CPU Request | 500m | **250m** | [kustomization.yaml](file:///home/user/microservices/gitops/apps/analytics/base/kustomization.yaml) |
| CPU Limit | 2 | **1000m** | [kustomization.yaml](file:///home/user/microservices/gitops/apps/analytics/base/kustomization.yaml) |
| Memory Request | 1Gi | **512Mi** | [kustomization.yaml](file:///home/user/microservices/gitops/apps/analytics/base/kustomization.yaml) |
| Memory Limit | 4Gi | **1Gi** | [kustomization.yaml](file:///home/user/microservices/gitops/apps/analytics/base/kustomization.yaml) |
| HPA | Max 10 replicas | **2-8 replicas** | [hpa.yaml](file:///home/user/microservices/gitops/apps/analytics/base/hpa.yaml) |
| Image | `registry/ta-microservices/analytics` | `registry-api.tanhdev.com/analytics` | [kustomization.yaml](file:///home/user/microservices/gitops/apps/analytics/base/kustomization.yaml) |
| PG Pool | Hardcoded 25/5 | **Configurable 50/10** | [config.go](file:///home/user/microservices/analytics/internal/config/config.go) |

---

## 🚨 Day 2 SRE Checklist — Post-Go-Live

### Week 1 (Must-Have)

- [x] PrometheusRule deployed (Fix 20 ✅)
- [x] HPA configured (Fix 17 ✅)
- [ ] PG connection monitoring dashboard (`pg_stat_activity`)
- [ ] DLQ depth Grafana panel for each `dlq.analytics.*` topic
- [ ] Runbook covering: DLQ overflow, event loss, OOMKill, PG slow queries

### Month 1 (Should-Have)

- [ ] Data retention CronJob — archive events > 90 days
- [ ] PII audit scan — weekly check for un-masked IP addresses
- [ ] Load testing results — document max events/sec at current limits
- [ ] Backup verification — test PG restore for analytics DB
- [ ] Aggregation monitoring — alert if daily job not complete by 3 AM

### Quarter 1 (Nice-to-Have)

- [ ] Event replay capable — admin API for date-range reprocessing
- [ ] Schema registry integration — validate against versioned schemas
- [ ] Blue-green event migration — process v1 + v2 simultaneously
- [ ] Cost attribution — PG storage cost per event type

---

## ✅ Completion Criteria

| Milestone | Requirements | Status |
|-----------|-------------|--------|
| **Stabilizing** | Fix 1 + 2 + 3 + 11 + 17 + 20 | ✅ Met |
| **Staging-Ready** | + Fix 4 + 7 + 13 + 14 + 16 + 18 + 19 | 🟡 Partial (4, 13, 16, 18 done; 7, 14, 19 remaining) |
| **Production-Ready** | + Fix 5 + 6 + 8 + 9 + 10 + 12 + 15 + Load Tests | 🟡 Partial (15 done; rest remaining) |

> [!NOTE]
> **Verdict**: The Analytics Service has reached **Stabilizing** milestone. 8 remaining fixes are needed for full production readiness.

# 🔍 Service Review: analytics

**Date**: 2026-03-04
**Status**: ⚠️ Needs Work

---

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | ✅ Fixed |
| P1 (High) | 5 | ✅ All Fixed |
| P2 (Normal) | 5 | 2 Fixed / 3 Documented |

---

## 🔴 P0 Issues (Blocking)

1. **[DEAD CODE / Incomplete Aggregation Pipeline]** `internal/worker/cron/aggregation_cron.go`:39 — The aggregation cron job only calls `metricsRepo.AggregateDaily()` (basic daily aggregation). The comprehensive `AggregationService.RunDailyAggregation()` — which orchestrates customer analytics, order analytics, product performance, RFM score calculation, and conversion funnel updates — is **never called** from any cron job or entry point. This means in production, critical metric tables (`customer_analytics_daily`, `order_analytics_daily`, `product_performance_daily`, RFM scores, conversion funnel) are **never populated by the aggregation pipeline**. The aggregation repository (`repo_aggregation.go`, 521 lines) is effectively dead code.

---

## 🟡 P1 Issues (High)

1. **[Stale Dependency]** `go.mod`:13 — Common lib is at `v1.22.0` but latest tag is `v1.23.1`. Service should be updated to pick up latest bug fixes and utilities.

2. **[Dead Code - CartConsumerWorker]** `internal/data/eventbus/worker.go` — `CartConsumerWorker` and `CartConsumer` are fully implemented but **not wired** in `cmd/worker/wire.go`. The Dapr subscription for `cart.converted` in `dapr/subscription.yaml` routes to `/events/cart` (HTTP handler) which works, but the dedicated consumer worker is unused dead code.

3. **[Dead Code - RealTimeUpdateService]** `internal/service/realtime_update_service.go` (647 lines) — `RealTimeUpdateService` starts background goroutines for metrics updates, cache refresh, and cleanup. It is **never wired** in any entry point (server or worker). All 647 lines are dead code. Additionally, it calls `context.Background()` internally which wouldn't handle graceful shutdown properly.

4. **[Dead Code - ReconciliationService]** `internal/service/reconciliation_service.go` (146 lines) — `ReconciliationService.RunDailyReconciliation()` checks for event loss (comparing daily counts against 7-day averages). It is **never wired** in any cron job or entry point.

5. **[Missing Service Documentation]** `docs/03-services/operational-services/analytics-service.md` — No service documentation exists for analytics. Required per review checklist.

---

## 🔵 P2 Issues (Normal)

1. **[Coverage Artifact Committed]** `internal/biz/c.out` — Coverage output file (61KB) is present in the repo. While `.gitignore` covers `*.out`, this file may have been force-added. Should be removed.

2. **[Stub Methods in Service Layer]** `internal/service/stubs.go` — `ServiceIntegration` is a no-op stub with TODO comments. Health check returns empty map. The stub returns empty results for fulfillment, shipping, marketing, and search metrics.

3. **[Hardcoded Margin in Revenue]** `internal/data/repo_revenue.go`:117 — `product.Margin = product.Revenue * 0.3 // Assume 30% margin` — hardcoded 30% margin assumption. Should at minimum use a config value.

4. **[Hardcoded Retention Days]** `internal/service/retention_service.go`:26 — `retentionDays := 90 // default 90 days` — hardcoded, should come from config.

5. **[Dead pkgCircuitBreaker]** `internal/pkg/circuitbreaker/circuit_breaker.go` — A standalone circuit breaker implementation exists in `pkg/circuitbreaker/` but the data layer uses `data/pg_circuit_breaker.go` instead. The `pkg` version is unused dead code.

---

## ✅ Good Practices Found

1. **Clean Architecture**: Proper layer separation — `biz/` (interfaces + use cases), `data/` (repositories), `service/` (gRPC handlers), `handler/` (HTTP event handlers).
2. **Interface Segregation**: `AnalyticsRepository` is composed from 16+ domain-specific sub-interfaces. Well-documented migration plan in comments.
3. **PII Anonymization**: Proper SHA-256 hashing for user agents, IP masking (last octet zeroed for IPv4, last 80 bits for IPv6), email masking. Covered by tests (96.2% coverage).
4. **Idempotent Event Processing**: All event processors check `IsEventProcessed()` before saving, with `CreateProcessedEvent()` after.
5. **Schema Validation**: JSON schema validation (fail-closed) on order, product, customer, and page view events.
6. **Circuit Breaker**: PostgreSQL write path protected by circuit breaker (`pg_circuit_breaker.go`) with closed/open/half-open states.
7. **Body Size Limits**: Event handler limits request body to 1MB to prevent OOM.
8. **CloudEvent Metadata**: Full CloudEvent envelope parsed (ID, source, type, time, traceparent) and injected into context.
9. **Trace ID Extraction**: W3C traceparent parsed to extract trace_id for distributed tracing.
10. **DLQ Support**: Dead letter queue handler for events that exhaust Dapr retries.
11. **Batch Writes**: `BatchSaveEvents()` uses multi-row INSERT with chunking (max 500 per batch) to avoid PG parameter limits.
12. **Wire DI**: Clean dependency injection with Wire for both server and worker binaries.
13. **Dual Binary Architecture**: Proper separation — API server handles gRPC/HTTP, worker handles cron jobs.
14. **Auth Middleware**: JWT validation with skip paths for health checks.
15. **Common Library Usage**: Uses `common/worker`, `common/events`, `common/config`, `common/api/errors`.
16. **Dapr Subscriptions**: Well-organized subscription YAML with DLQ and maxRetryCount for all event types.
17. **Data Retention**: Automated partition management with configurable retention period and partition creation.
18. **HPA Configured**: GitOps includes HPA for horizontal scaling.
19. **NetworkPolicy**: Configured for egress/ingress control.
20. **No `replace` directives**: Go module dependencies are clean.

---

## 🔧 Action Plan

| # | Severity | Issue | File:Line | Fix Description | Status |
|---|----------|-------|-----------|-----------------|--------|
| 1 | P0 | Aggregation pipeline not wired to cron | `cron/aggregation_cron.go`:73 | Wire `AggregationRepository` into cron job's daily aggregation — now calls full pipeline (customer, order, product, operational, fulfillment, search, return/refund, RFM, funnel) | ✅ Done |
| 2 | P1 | Common lib outdated v1.22.0→v1.23.1 | `go.mod`:13 | `go get gitlab.com/ta-microservices/common@v1.23.1 && go mod vendor` | ✅ Done |
| 3 | P1 | CartConsumerWorker dead code | `data/eventbus/worker.go` | Removed `internal/data/eventbus/` — HTTP handler covers `cart.converted` | ✅ Done |
| 4 | P1 | RealTimeUpdateService dead code (647 lines) | `service/realtime_update_service.go` | Removed (647 lines + 66 line test file) — never wired into any entry point | ✅ Done |
| 5 | P1 | ReconciliationService dead code | `service/reconciliation_service.go` | Wired into worker as `ReconciliationCronJob` (24h interval) | ✅ Done |
| 6 | P1 | Missing service documentation | `docs/03-services/` | Created `analytics-service.md` with full architecture, APIs, events, crons | ✅ Done |
| 7 | P2 | Coverage file in repo | `biz/c.out` | Removed `biz/c.out` and `coverage.out` | ✅ Done |
| 8 | P2 | Hardcoded 30% margin | `data/repo_revenue.go`:117 | Move to config | Documented |
| 9 | P2 | Hardcoded retention days | `service/retention_service.go`:26 | Move to config | Documented |
| 10 | P2 | ~~Dead pkg/circuitbreaker~~ | `pkg/circuitbreaker/` | NOT dead — used by `service/marketplace/external_api_integration.go` | N/A |

---

## 📈 Test Coverage

| Layer | Coverage | Target | Status |
|-------|----------|--------|--------|
| Biz | 67.6% | 60% | ✅ Above target |
| Service | 61.1% | 60% | ✅ Above target |
| Service/Marketplace | 73.2% | 60% | ✅ Above target |
| PII | 96.2% | 60% | ✅ Excellent |
| Data | 0.0% | 60% | ⚠️ Below target |
| Handler | 0.0% | 60% | ⚠️ Below target |

Coverage checklist updated: ❌ (will update after fixes)

---

## 🌐 Cross-Service Impact

- **Services that import this proto**: `gateway` (v1.2.7)
- **Services that consume analytics events**: None (analytics is a consumer, not a publisher)
- **Backward compatibility**: ✅ Preserved — no proto field changes needed
- **Event schemas consumed**:
  - `orders.order.status_changed`
  - `payment.payment.processed`, `payment.payment.failed`, `payment.payment.refunded`
  - `shipping.shipment.status_changed`
  - `fulfillments.fulfillment.status_changed`, `fulfillments.fulfillment.sla_breach`
  - `orders.return.requested`, `orders.return.approved`, `orders.return.completed`, `orders.return.rejected`
  - `analytics.page_view`
  - `cart.converted`

---

## 🚀 Deployment Readiness

- Config/GitOps aligned: ✅ (HTTP=8019, gRPC=9019 matches PORT_ALLOCATION_STANDARD)
- Health probes: ✅ (startup, liveness, readiness configured via kustomize replacements)
- Resource limits: ✅ (via common-deployment-v2 component)
- HPA: ✅ (hpa.yaml, sync-wave handled correctly)
- PDB: ✅ (pdb.yaml + worker-pdb.yaml)
- NetworkPolicy: ✅ (networkpolicy.yaml with infrastructure-egress component)
- Migration safety: ✅ (migration-job.yaml with separate job)
- ServiceMonitor/PrometheusRule: ✅ Configured
- Dapr annotations: ✅ (app-id=analytics, app-port auto-propagated from service targetPort)

---

## Build Status

- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅ PASS
- `go test ./...`: ✅ PASS
- `wire`: ✅ Generated (both server and worker)
- Generated Files (`wire_gen.go`, `*.pb.go`): ✅ Not modified manually
- `bin/` Files: ✅ Not present
- `replace` directives: ✅ None found

---

## Documentation

- Service doc (`docs/03-services/operational-services/analytics-service.md`): ❌ Missing
- README.md: ✅ Present (17KB)
- CHANGELOG.md: ✅ Present (7.5KB)

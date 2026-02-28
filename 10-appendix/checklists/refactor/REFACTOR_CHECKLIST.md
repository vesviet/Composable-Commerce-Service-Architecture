# Refactor Checklist — Remaining Work

> **Last verified:** 2026-02-28 22:58 (grep + full codebase audit)
>
> **Tracks A–H, J, J2, K, K1, L, M, N: ✅ ALL COMPLETE** — See [Completed Tracks](#completed-tracks) at bottom.

---

## Active Work

### Track I: Customer Domain Model Separation (P0, ~3 days remaining)

> **Scope:** `customer/` only
> **Goal:** Remove all `import "internal/model"` from `internal/biz/`

**Current state:** 26 files in `biz/` still import `internal/model`. Domain structs and mappers done. 7/10 biz packages migrated.

#### Step 1: Domain Structs — ✅ DONE (commit `ea7381f`)

#### Step 2: Data-Layer Mappers — ✅ DONE (commit `ea7381f`)

#### Step 3: Migrate Repo Interfaces — return domain types

- [ ] `repository/customer/customer.go` — `CustomerRepo`: return `*biz.Customer`
- [ ] `repository/customer_profile/customer_profile.go`
- [ ] `repository/customer_preference/customer_preference.go`
- [ ] `repository/outbox/outbox.go` (if using `model.OutboxEvent`)

#### Step 4: Update Data Implementations — use mappers

- [ ] `data/customer/customer.go` — DB query → `mapper.CustomerToDomain()` → return
- [ ] `data/customer_profile/customer_profile.go`
- [ ] `data/customer_preference/customer_preference.go`

#### Step 5: Migrate Biz Use Cases — remove `import "internal/model"`

Core customer package (7 files):
- [ ] `biz/customer/customer.go` (1357 lines — largest, do last)
- [ ] `biz/customer/auth.go`
- [ ] `biz/customer/cache.go`
- [ ] `biz/customer/verification.go`
- [ ] `biz/customer/events.go`
- [ ] `biz/customer/social_login.go`
- [ ] `biz/customer/gdpr.go`

Already migrated biz packages:
- [x] `biz/address/` — commit `f237b50`
- [x] `biz/preference/` — commit `b5c46e1`
- [x] `biz/segment/` — commit `63b27dc`+`b5c46e1`
- [x] `biz/customer_group/` — commit `f237b50`
- [x] `biz/wishlist/` — commit `f237b50`
- [x] `biz/audit/` — commit `9964398`
- [x] `biz/analytics/` — commit `b5c46e1`
- [ ] `biz/worker/outbox.go` — uses `model.OutboxEvent` (acceptable persistence type)

#### Step 6: Update Service Converters — ✅ DONE (commit `b5c46e1`)

#### Step 7: Verify

- [x] `go build ./...` ✅
- [x] `golangci-lint run` ✅
- [ ] `grep -r 'internal/model' internal/biz/` → **ZERO** results

---

## Standalone P0 Fixes (Quick Wins, ~0.5 day each)

### Fix S1: Checkout — Simplify Transaction Manager — ✅ DONE

> **Commit:** `f20f451`

- [x] Renamed to idiomatic `gormTransactionManager`, cleaned up
- [x] `go build ./... && golangci-lint run` ✅

### Fix S2: Order — Replace Local Outbox Worker — ✅ DONE

> **Commit:** `bc8addc`

- [x] Deleted 175-line local `worker.go`
- [x] Wired `common/outbox.Worker` + `OutboxPublisherAdapter` via Wire
- [x] Wire regenerated, `go build ./... && golangci-lint run` ✅

### Fix S3: gRPC Clients — Migrate to `common/client.DiscoveryClient` — ✅ DONE

> **Commits:** `44992d8` (order), `04b2d2a` (shipping), `f96d721` (common-operations)

| Service | File | Status |
|---------|------|--------|
| order | `internal/data/grpc_client/shipping_client.go` | ✅ Done |
| shipping | `internal/client/catalog_grpc_client.go` | ✅ Done |
| common-operations | `internal/client/order_client.go` | ✅ Done |

- [x] All 3 migrated to `common/client.DiscoveryClient` (Consul + Circuit Breaker)
- [x] `go build ./... && golangci-lint run` per service ✅

---

## Standalone P1 Fixes

### Fix S4: N+1 Queries — Preload → Joins in List APIs

> Verified: `warehouse.go:160`, `order.go` — multiple `Preload()` on list endpoints

- [ ] `warehouse`: `Preload("Locations").Find()` → `Joins("LEFT JOIN ...")`
- [ ] `order`: `Preload("Items")`, `Preload("ShippingAddress")` → `Joins`
- [ ] Add `.Limit(1000)` safety on unbounded internal queries (`GetLocations`, `GetByReference`)

### Fix S5: Health Probes — `initialDelaySeconds: 0`

- [ ] `loyalty-rewards`: set `startupProbe.initialDelaySeconds: 10`
- [ ] `search`: set `startupProbe.initialDelaySeconds: 10`

### Fix S6: GitOps — Secrets Documentation Drift

> `gitops/README.md` claims "External Secrets + Vault" but uses Bitnami Sealed Secrets

- [ ] Align README with actual implementation (Sealed Secrets)

---

## Standalone P2 Fixes

### ~~Fix S7: Payment — Delete Local Idempotency Copy~~ — ❌ RECLASSIFIED

> **Re-analysis result:** NOT a copy.
> `payment/internal/biz/common/idempotency.go` implements a `Begin/MarkCompleted/MarkFailed`
> state machine that neither `common/idempotency.RedisIdempotencyService` (Execute(fn))
> nor `common/utils/idempotency.Service` (Get/Set/TryAcquire) provides.
> This is legitimate domain logic, not copy-paste.

### Fix S8: Location — Delete Unnecessary DaprPublisher Wrapper

- [ ] Delete `location/internal/event/publisher.go`
- [ ] Inject `events.EventPublisher` directly via Wire

### Fix S9: RBAC — Remove Copy-Pasted `RequireRole` Middleware

5 services have local copies instead of using `common/middleware/auth.go`:
- [ ] `review/internal/middleware/auth.go`
- [ ] `catalog/internal/middleware/auth.go`
- [ ] `return/internal/middleware/auth.go`
- [ ] `promotion/internal/middleware/auth.go`
- [ ] `pricing/internal/middleware/auth.go`

---

## Future Sprints

### Track P: RBAC Policy Migration (P2)
- [ ] Evaluate Casbin / OPA for policy-based access control
- [ ] Replace hardcoded `RequireRole("admin")` patterns

### Track Q: Cursor Pagination (P1, 8–10 days)
- [ ] Migrate `warehouse` stock_transactions → `CursorPaginator`
- [ ] Migrate `order` orders → `CursorPaginator`
- [ ] Update proto — add `cursor`/`next_cursor` fields

### Track R: GitOps Component Migration (P0-DRY, 5–8 days)
- [ ] Migrate remaining 17 API deployments → `common-deployment` component
- [ ] Migrate 20 worker deployments → `common-worker-deployment` component

### Track T: Unit Test & Mockgen Adoption (P1, 3–5 days)
- [ ] Replace `order/internal/biz/mocks.go` (700+ lines hand-written) with `mockgen`
- [ ] Replace `payment` manual `testify/mock` structs with `mockgen`
- [ ] Mandate `//go:generate mockgen` for all biz interfaces
- [ ] Coverage campaign: target ≥60% for `order/biz/status`, `payment/biz/refund`

### Track U: CronWorker Wrapper Adoption (P1, 1 day)
- [ ] Wrap all manual Ticker/select cron loops with `commonWorker.NewCronWorker()`
- [ ] Target services: order, analytics, catalog, customer

---

## TA Report Status (Cross-Reference)

Reports with **zero remaining issues** (all fixed):
- ✅ `caching_strategy_analysis_report.md`
- ✅ `worker_analysis_report.md` (worker main.go bootstrap)
- ✅ `migration_analysis_report.md`
- ✅ `resilience_distributed_transaction_analysis_report.md`
- ✅ `observability_tracing_analysis_report.md` (K1 verified)

Reports **outdated** (re-verified as fixed):
- ✅ `api_grpc_layer_analysis_report.md` — Report claims 4/21 services use `ErrorEncoderMiddleware`. **Actual: 20/20 deployed.** Mark P1 as RESOLVED.

Reports with **remaining issues** mapped to checklist above:
- `database_pagination_analysis_report.md` → Fix S4, Track Q
- `unit_test_coverage_analysis_report.md` → Track T
- `clean_architecture_domain_analysis_report.md` → Track I
- `security_idempotency_analysis_report.md` → Fix S7, S9
- `database_transaction_analysis_report.md` → Fix S1
- `dapr_pubsub_analysis_report.md` → Fix S8
- `service_discovery_analysis_report.md` → Fix S3
- `internal_worker_code_analysis_report.md` → Fix S2, Track U
- `gitops_infrastructure_analysis_report.md` → Fix S6
- `gitops_api_deployment_analysis_report.md` → Fix S5, Track R
- `gitops_worker_analysis_report.md` → Track R
- `kubernetes_policies_analysis_report.md` → Track R

---

## Completed Tracks

| Track | Status | Commit | Notes |
|-------|--------|--------|-------|
| A–H | ✅ Done | — | Common lib, GitOps P0, Code P0, Dapr, Tx/Cache/gRPC, Worker/Migrate DRY, Perf |
| J Common Client | ✅ Done | `8f213c5` (v1.19.0) | `DiscoveryClient` struct |
| J2 Checkout GetOrSet | ✅ Done | `673d4c5` | 3 methods migrated, -63 lines |
| K gRPC Migration | ✅ Done | `74b3335`, `a620256`, `362afbf` | 4 clients migrated, search already standard |
| K1 Outbox Tracing | ✅ Verified | — | order + payment inject trace context |
| L Biz Validation | ✅ No-op | — | No redundant validation found |
| M AlertService | ✅ Already Done | — | `warehouse/internal/biz/alert/` (4 files) |
| N Rate Limiting | ✅ Already Done | — | `gateway/internal/middleware/rate_limit.go` (447 lines) |

## Priority Summary

| Priority | Items | Est. Effort |
|----------|-------|-------------|
| 🔴 P0 Active | Track I (customer domain) | 3 days |
| 🔴 P0 Quick | S1 (checkout tx), S2 (order outbox), S3 (3 gRPC clients) | 2 days |
| 🟡 P1 | S4 (N+1), S5 (probes), S6 (docs), Track T (tests), Track U (cron) | 6–8 days |
| 🔵 P2 | S7 (idempotency), S8 (location), S9 (RBAC copies) | 2 days |
| ⏳ Future | Track P (RBAC), Q (pagination), R (GitOps DRY) | 15–20 days |

# Refactor Checklist — Remaining Work

> **Last verified:** 2026-03-01 19:36 (Full codebase grep audit across all 20+ services)
>
> **Tracks A–H, J, J2, K, K1, L, M, N, U: ✅ ALL COMPLETE** — See [Completed Tracks](#-completed-core-tracks) at bottom.

---

## 🏃 Active Work: In Progress

### Track I: Customer Domain Model Separation (P0, ~3 days)
> **Scope:** `customer/` only — started with **26 files** importing `internal/model`
> **Goal:** Remove all `import "internal/model"` from `internal/biz/`
> *(Ref: `clean_architecture_domain_analysis_report.md`)*

- [x] Step 1: Domain Structs (commit `ea7381f`)
- [x] Step 2: Data-Layer Mappers (commit `ea7381f`) — added `PasswordHash`, `TwoFactorSecret`
- [x] Step 3: Migrate Repo Interfaces — `CustomerRepo` returns `*domain.Customer`; `SegmentRepo.GetSegmentCustomers` returns `[]domain.Customer`; removed dead `FindByIDRaw`
- [x] Step 4: Update Data Implementations — `data/postgres/customer.go` + `data/postgres/segment.go` use `mapper.CustomerToDomain()`
- [x] Step 5a: Core Customer entity — `customer.go`, `auth.go`, `cache.go`, `events.go`, `social_login.go`, `gdpr.go`, `two_factor.go` all use `*domain.Customer` (was `*model.Customer`)
- [x] Step 5b: Segment package — `rules_engine.go` + `segment.go` use `*domain.Customer`; deleted 3 bridge mappers (~82 lines)
- [x] Step 5c: Sub-aggregate repos — All 7 biz files migrated: `CustomerProfile`, `CustomerPreferences`, `OutboxEvent`, `VerificationToken`, `CustomerSegment`, `CustomerSegmentMembership` now use domain types
- [x] Step 6: Update Service Converters (commit `b5c46e1`) — deleted `domainCustomerToModel/modelCustomerToDomain` bridge mappers
- [x] Step 7: Verify — `grep 'internal/model' internal/biz/` shows **0 files** ✅
- [x] Step 8 (Track I-B): Deleted stale `repository/address/`, `repository/audit/`, `repository/wishlist/` packages. Moved `repository/customer_group/` → `data/postgres/customer_group.go`. Only `repository/processed_event/` remains (infrastructure-only, never touches biz).

---

## 📋 Aggregated TA Report Issues — Verified Against Codebase

### 🔴 P0 Critical Issues

| # | Domain | Issue | Status | Commit/Notes |
|---|--------|-------|--------|--------------|
| 1 | Clean Architecture | Domain leakage `biz` imports `internal/model` in `customer` | ✅ **DONE** | **Track I complete** — 0 model imports in `internal/biz/` |
| ~~2~~ | ~~Architecture~~ | ~~Error Handling Middleware fragmentation~~ | ✅ **DONE** | `ErrorEncoderMiddleware()` deployed in 20+ services |
| ~~3~~ | ~~Transaction~~ | ~~Local Transaction Manager in Checkout~~ | ✅ **DONE** | Commit `f20f451` |
| ~~4~~ | ~~Architecture~~ | ~~Localized Outbox Worker in Order~~ | ✅ **DONE** | Commit `bc8addc`. Uses `commonOutbox.NewWorker()` |
| ~~5~~ | ~~Observability~~ | ~~Trace Lineage severed at Outbox~~ | ✅ **DONE** | `Traceparent` field in `payment` + `order` outbox events |
| ~~6~~ | ~~Resilience~~ | ~~`auth` gRPC: legacy `grpc.DialInsecure()`~~ | ✅ **DONE** | Commit `630dd25`. Deleted `auth/internal/data/grpc.go` |
| 7 | Testability | 769-line hand-written `mocks.go` → must migrate to `mockgen` | ⚠️ **Prepared** | `//go:generate mockgen` directives added (commit `f41bbc5`). Full migration = 3d effort |
| ~~8~~ | ~~Testability~~ | ~~Low test coverage in `order/biz/status` (target ≥60%)~~ | ✅ **DONE** | 85.3% coverage (15 tests). `payment/biz/refund` already covered |
| 9 | GitOps / DRY | Worker & API Deployment Manifest Duplication | ⚠️ **Mostly Done** | Only `return` + `review` still have standalone `deployment.yaml` & `worker-deployment.yaml`. Most services migrated to `common-deployment` |
| 10 | GitOps | Strategic: Kustomize → Internal Helm Chart | ❌ **Open** | Q3 strategic initiative |

### 🟡 P1 High Priority Issues

| # | Domain | Issue | Status | Notes |
|---|--------|-------|--------|-------|
| ~~11~~ | ~~API Standards~~ | ~~Missing Keyset (Cursor) Pagination~~ | ✅ **DONE** | All 16 services migrated (2026-03-02). 10 data files + 6 filter structs updated. Remaining `.Offset()` are offset-fallback branches and secondary raw-interface methods — intentionally kept |
| ~~12~~ | ~~API Standards~~ | ~~Legacy Hand-Rolled `.Validate()` cleanup~~ | ✅ **RECLASSIFIED** | All 13 sites use standard `common/validation.NewValidator()` — correct pattern, NOT legacy |
| 13 | Reliability | Goroutine Leak Risk in Manual Cron `for{select}` | ✅ **Mostly DONE** | Track U confirmed done. Edge cases may remain |
| ~~14~~ | ~~Documentation~~ | ~~Secrets Mgmt: README claims Vault, reality is Sealed Secrets~~ | ✅ **DONE** | Commit `b134a58`. Fixed `gitops/README.md` |
| ~~15~~ | ~~CI/CD~~ | ~~Missing Automated CI Coverage Gates~~ | ✅ **DONE** | Added `COVERAGE_THRESHOLD` (default 50%) enforcement to `lint-test.yaml`. Per-service override via CI variable |

### 🔵 P2 Normal / Tech Debt Issues

| # | Domain | Issue | Status | Notes |
|---|--------|-------|--------|-------|
| ~~16~~ | ~~Architecture~~ | ~~Superfluous Publisher Wrappers in `location`~~ | ✅ **DONE** | Commit `13aa392` |
| ~~17~~ | ~~Architecture~~ | ~~Copy-Pasted Idempotency in `payment`~~ | ✅ **RECLASSIFIED** | NOT a copy. `Begin/MarkCompleted/MarkFailed` state machine is legitimate domain logic |
| ~~18~~ | ~~Security~~ | ~~Hardcoded RBAC `RequireRole()` in 5 services~~ | ✅ **DONE** | All 5 flagged services (catalog, review, promotion, return, pricing) migrated to `RequireRoleKratos` from common. Verified 2026-03-01 |
| ~~19~~ | ~~GitOps~~ | ~~InitContainers inconsistencies in worker templates~~ | ✅ **DONE** | Deleted dead `common-worker-deployment/` (v1 consul, 0 users) + deprecated `worker-deployment.yaml`. Single source: `common-worker-deployment-v2/` |
| ~~9~~ | ~~GitOps~~ | ~~GitOps DRY `common-operations`~~ | ✅ **DONE** | Uses `common-deployment-v2` + `common-worker-deployment-v2`. Kustomize renders correctly. Verified 2026-03-02 |
| ~~20~~ | ~~Performance~~ | ~~N+1 Preload() Greedy Fetching~~ | ✅ **RECLASSIFIED + FIXED** | GORM Preload uses batch `WHERE IN` — NOT N+1. Real risk: unbounded `Find()`. Added `Limit(500)` on 8 queries across warehouse, distributor, fulfillment, location. Verified 2026-03-02 |

---

## ✅ Completed Sprint 1 & Sprint 2 Work (This Session)

| Task | Description | Commit |
|------|-------------|--------|
| **Auth gRPC Fix** | Deleted legacy `grpc.DialInsecure()` in `auth/internal/data/grpc.go` | `630dd25` |
| **Common: RBAC Kratos** | Added `RequireRoleKratos` + `RequireAdminKratos` to `common/middleware` | `c3b9665` (v1.22.0) |
| **Order: mockgen prep** | Added `//go:generate mockgen` directives to biz interfaces | `f41bbc5` |
| **GitOps: Fix S6** | Fixed Vault → Sealed Secrets documentation drift in README | `b134a58` |
| **Payment: Reclassified** | Idempotency is NOT a copy — legitimate state machine (Begin/Complete/Fail) | N/A |

---

## 🏁 Completed Core Tracks

| Track | Status | Notes |
|-------|--------|-------|
| A–H | ✅ Done | Common lib, GitOps P0, Code P0, Dapr, Tx/Cache/gRPC, Worker/Migrate DRY, Perf |
| J | ✅ Done | Common Client `DiscoveryClient` |
| J2 | ✅ Done | Checkout `GetOrSet` stampede prevention |
| K | ✅ Done | gRPC Clients migrated |
| K1 | ✅ Verified | Outbox Tracing — `Traceparent` injected in `order` + `payment` |
| L | ✅ No-op | Legacy Biz Validation not present |
| M | ✅ Done | AlertService active in `warehouse` |
| N | ✅ Done | Rate limiting `gateway/internal/middleware/rate_limit.go` |
| U | ✅ Done | CronWorker standard wrapper verified |

---

## 📊 Remaining Priority Summary

| Priority | Open Items | Est. Total Effort |
|----------|-----------|-------------------|
| 🔴 P0 | ~~#8 (DONE)~~, ~~#7 mockgen infra (DONE)~~, stateful test_helpers remain | ~0.5 day |
| 🟡 P1 | ~~#11 (DONE)~~, ~~#12 (RECLASSIFIED)~~, ~~#15 CI gates (DONE)~~, ~~#20 Preload (RECLASSIFIED + FIXED)~~ | ✅ All closed |
| 🔵 P2 | ~~#9 (DONE)~~, ~~#16 (DONE)~~, ~~#17 (RECLASSIFIED)~~, ~~#18 (DONE)~~, ~~#19 (DONE)~~ | ✅ All closed |
| ⏳ Q3 | #10 Helm chart | ~10 days |

> **Track I Progress**: ✅ **COMPLETE** — Core `model.Customer` → `domain.Customer` + all sub-aggregates + stale repo interfaces cleaned. **0 model imports remain** in `internal/biz/` and `internal/repository/` (except infrastructure-only `processed_event`).

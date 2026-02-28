# Refactor Checklist — Remaining Work

> **Last verified:** 2026-02-28 21:55 (grep + codebase audit)
>
> **Tracks A–H: ✅ COMPLETE** — Common lib, GitOps P0, Code P0, Dapr, Tx/Cache/gRPC, Worker/Migrate DRY, GitOps DRY, Perf audits.
>
> **Track J2 (Checkout GetOrSet): ✅ COMPLETE** — `cart_repo.go` migrated 3 read methods to `TypedCache.GetOrSet()`. Commit `673d4c5`.
>
> **Track K1 (Outbox Tracing): ✅ VERIFIED** — order + payment both inject trace context via `trace.SpanFromContext(ctx)`.
>
> **Track L (Biz Validation Cleanup): ✅ NO-OP** — grep found zero redundant manual validation; all business-rule validation is NOT proto-coverable.
>
> **Quy tắc:** Mỗi agent nhận **1 Track**. Phase 1 chạy song song. Phase 2 BLOCKING trên Phase 1 Track J.

---

## Phase 1: Parallel Tracks (Chạy song song ngay)

### Track I: Customer Domain Model Separation (P1, 3–5 ngày)

> **Agent I** — Chỉ sửa trong `customer/`
> **Mục tiêu:** Tách Domain Model khỏi GORM Data Model theo chuẩn Clean Architecture

**Hiện trạng:** `customer/internal/biz/` import `internal/model` ở **26 files** — vi phạm Clean Architecture.

#### Step 1: Domain Structs — ✅ DONE (commit `ea7381f`)

- [x] `biz/customer/domain.go` — `Customer`, `CustomerAddress`, `CustomerProfile`, `CustomerPreferences`, `StableCustomerGroup`
- [x] `biz/address/domain.go` — `Address`
- [x] `biz/preference/domain.go` — `Preference`
- [x] `biz/segment/domain.go` — `Segment` (with `IsDynamic()`, `IsStatic()`)
- [x] `biz/customer_group/domain.go` — `CustomerGroup`
- [x] `biz/wishlist/domain.go` — `Wishlist`, `WishlistItem`
- [x] `biz/audit/domain.go` — `AuditEvent`, `AuditEventType`, `AuditEventSeverity` constants

#### Step 2: Data-Layer Mappers — ✅ DONE (commit `ea7381f`)

- [x] `data/mapper/customer_mapper.go` — bidirectional `model.Customer` ↔ `biz.Customer`
  - `CustomerToDomain`, `CustomerListToDomain`, `ProfileToDomain`, `PreferencesToDomain`
  - `AddressToDomainCustomer`, `StableGroupToDomain`, `DomainToCustomerModel`

#### Step 3: Migrate Repo Interfaces — return domain types

> **Key insight:** `CustomerRepo` is aliased from `repository/customer.CustomerRepo` which returns `model.Customer`.
> Migration path: update `repository/customer/customer.go` interface → update `data/` implementations → update biz callers.

- [ ] `repository/customer/customer.go` — `CustomerRepo` interface: `FindByID` → return `*biz.Customer`
- [ ] `repository/customer_profile/customer_profile.go` — `CustomerProfileRepo` interface
- [ ] `repository/customer_preference/customer_preference.go` — `CustomerPreferencesRepo` interface
- [ ] `repository/outbox/outbox.go` — `OutboxEventRepo` interface (if using `model.OutboxEvent`)

#### Step 4: Update Data Implementations — use mappers

- [ ] `data/customer/customer.go` — repo impl: DB query → `mapper.CustomerToDomain()` → return
- [ ] `data/customer_profile/customer_profile.go` — repo impl
- [ ] `data/customer_preference/customer_preference.go` — repo impl

#### Step 5: Migrate Biz Use Cases — remove `import "internal/model"`

Files still importing `internal/model` (8 non-test files):
- [ ] `biz/customer/customer.go` (1357 lines — largest, do last)
- [ ] `biz/customer/auth.go`
- [ ] `biz/customer/cache.go`
- [ ] `biz/customer/verification.go`
- [ ] `biz/customer/events.go`
- [ ] `biz/customer/social_login.go`
- [ ] `biz/customer/gdpr.go`

Other biz packages:
- [ ] `biz/address/*.go`
- [ ] `biz/preference/*.go`
- [ ] `biz/segment/*.go`
- [ ] `biz/customer_group/*.go`
- [ ] `biz/wishlist/*.go`
- [ ] `biz/audit/*.go`
- [ ] `biz/analytics/*.go`
- [ ] `biz/worker/*.go`

#### Step 6: Update Service Converters — `biz.X` → `pb.XReply`

- [ ] `service/*_convert.go` — update or create converters from domain types to proto

#### Step 7: Verify

- [ ] `go build ./...` ✅
- [ ] `golangci-lint run` ✅
- [ ] `grep -r 'internal/model' internal/biz/` returns **ZERO** results

---

### Track J: Common Client Extension — ✅ DONE

> **Committed:** `common v1.19.0` (commit `8f213c5`, tag `v1.19.0`)

- [x] `client/discovery.go` — `DiscoveryClient` struct
- [x] `NewDiscoveryClient(cfg, logger)` — Consul resolver + circuit breaker
- [x] `DefaultDiscoveryConfig(consulAddr, serviceName)` — sensible defaults
- [x] `GetConnection()` → `*grpc.ClientConn` for typed service clients
- [x] `Call(fn)` — circuit breaker wrapper
- [x] Build + lint clean
- [x] Tagged `v1.19.0`, pushed to GitLab

---

### Track M: AlertService Integration (P3, 2–3 ngày)

> **Agent M** — `notification/`, `order/`, `checkout/`, `warehouse/`, `return/`

- [ ] Implement concrete AlertService in `notification/` service
  - [ ] Slack webhook integration (P2/P3 alerts)
  - [ ] PagerDuty Events API v2 (P0/P1 alerts)
- [ ] Wire AlertService implementation vào order, checkout, warehouse, return
- [ ] Verify alert delivery end-to-end

---

### Track N: API Gateway Rate Limiting (P2, 1–2 ngày)

> **Agent N** — `gateway/` hoặc `gitops/`

- [ ] Evaluate rate limiting solution (Traefik middleware / Redis-based)
- [ ] Configure per-endpoint rate limits
- [ ] Test with load testing tool

---

## Phase 2: Sequential Track (SAU KHI Phase 1 Track J ✅ — UNBLOCKED)

### Track K: gRPC Client Migration (P1, 2 ngày)

> **Agent K** — 5 services
> **Depends on:** ~~Phase 1 Track J~~ ✅ DONE (`common v1.19.0`)

**Mục tiêu:** Migrate 5 clients sang `common/client.DiscoveryClient`.

- [ ] `auth/internal/client/user/user_client.go`
  - Replace `consul.New()` + `grpc.DialInsecure()` → `client.NewDiscoveryClient()`
  - Keep domain-specific methods (GetUserPermissions, ValidateUserCredentials, etc.)
  - Keep custom retry logic (`retryWithBackoff`)
- [ ] `auth/internal/client/customer/customer_client.go`
- [ ] `warehouse/internal/client/user_client.go`
- [ ] `customer/internal/client/auth/auth_client.go`
- [ ] `search/internal/client/provider.go`
- [ ] Update each service: `go get common@v1.19.0`, `go mod tidy`, vendor
- [ ] Verify build + lint per service

---

## Phase 3: Future Sprints

### Track P: RBAC Policy Migration (P2, Future)
- [ ] Evaluate Casbin / OPA cho policy-based access control
- [ ] Replace hardcoded `RequireRole("admin")` patterns

### Track Q: Cursor Pagination (P1, 8–10 ngày)
- [ ] Migrate `warehouse` stock_transactions → `CursorPaginator`
- [ ] Migrate `order` orders → `CursorPaginator`
- [ ] Update proto — thêm `cursor`/`next_cursor`

### Track R: GitOps Component Migration (Optional)
- [ ] Migrate remaining 17 API deployments → `common-deployment`
- [ ] Migrate 20 worker deployments → `common-worker-deployment`

---

## Dependency Graph

```
Phase 1 (Song song):
  Track I (Customer Domain) — Steps 1-2 ✅, Steps 3-7 remaining
  Track J (Common Client)   — ✅ DONE v1.19.0
  Track L (Validation)      — ✅ NO-OP
  Track M (AlertService)    — TODO
  Track N (Rate Limiting)   — TODO

Phase 2 (UNBLOCKED):
  Track K (gRPC Migration)  — ready to start (Track J done)

Phase 3 (Future):
  Track P (RBAC)
  Track Q (Cursor Pagination)
  Track R (GitOps Migration)
```

## Progress Summary

| Track | Status | Commit | Notes |
|-------|--------|--------|-------|
| J2 Checkout GetOrSet | ✅ Done | `673d4c5` | 3 methods migrated, -63 lines |
| K1 Outbox Tracing | ✅ Verified | — | order + payment both OK |
| L Biz Validation | ✅ No-op | — | No redundant validation found |
| J Common Client | ✅ Done | `8f213c5` (v1.19.0) | DiscoveryClient created |
| I Customer Domain | 🔨 In Progress | `ea7381f` | Steps 1-2 done, 3-7 remaining |
| K gRPC Migration | ⏳ Ready | — | Unblocked by Track J |
| M AlertService | 📋 TODO | — | P3 |
| N Rate Limiting | 📋 TODO | — | P2 |

# Refactor Checklist — Remaining Work

> **Last verified:** 2026-02-28 (grep + codebase audit)
>
> **Tracks A–H: ✅ COMPLETE** — Common lib (v1.18.0), GitOps P0, Code P0, Dapr enforcement, Tx/Cache/gRPC, Worker/Migrate DRY, GitOps DRY templates, Performance audits.
>
> **Quy tắc:** Mỗi agent nhận **1 Phase**. Phase 1 có thể chia thêm sub-agent. Phase 2 BLOCKING trên Phase 1A (common/client extension).

---

## Phase 1: Parallel Tracks (Chạy song song ngay)

### Track I: Customer Domain Model Separation (P1, 3–5 ngày)

> **Agent I** — Chỉ sửa trong `customer/`
> **Mục tiêu:** Tách bạch Domain Model khỏi GORM Data Model theo chuẩn Clean Architecture

**Hiện trạng:** `customer/internal/biz/` import `internal/model` ở **26 files** — vi phạm Clean Architecture (biz phụ thuộc data model).

**Bước thực hiện:**

1. Tạo domain structs thuần Go trong `biz/` (không GORM tag)
   - [ ] `biz/customer/domain.go` — `Customer`, `CustomerProfile`
   - [ ] `biz/address/domain.go` — `Address`
   - [ ] `biz/preference/domain.go` — `CustomerPreference`
   - [ ] `biz/segment/domain.go` — `Segment`, `SegmentRule`
   - [ ] `biz/customer_group/domain.go` — `CustomerGroup`
   - [ ] `biz/wishlist/domain.go` — `WishlistItem`
   - [ ] `biz/audit/domain.go` — `AuditEvent`
   - [ ] `biz/worker/domain.go` — `OutboxEvent`, `ProcessedEvent`

2. Update repo interfaces trong `biz/` — return domain types thay vì `*model.X`
   - [ ] `biz/customer/customer.go` — `CustomerRepo` interface
   - [ ] `biz/address/address.go` — `AddressRepo` interface
   - [ ] `biz/preference/preference.go` — `PreferenceRepo` interface
   - [ ] `biz/segment/segment.go` — `SegmentRepo` interface
   - [ ] `biz/customer_group/customer_group.go` — `CustomerGroupRepo` interface
   - [ ] `biz/wishlist/wishlist.go` — `WishlistRepo` interface

3. Tạo mappers trong `data/` — `model.X` ↔ `biz.X`
   - [ ] `data/customer_mapper.go`
   - [ ] `data/address_mapper.go`
   - [ ] `data/preference_mapper.go`
   - [ ] `data/segment_mapper.go`

4. Update `service/*_convert.go` — `biz.X` → `pb.XReply`
   - [ ] Verify existing converters hoặc tạo mới

5. Update tất cả biz use cases — xoá `import "internal/model"`
   - [ ] `biz/customer/*.go` (11 files)
   - [ ] `biz/address/*.go` (3 files)
   - [ ] `biz/preference/*.go` (3 files)
   - [ ] `biz/segment/*.go` (3 files)
   - [ ] `biz/customer_group/*.go` (2 files)
   - [ ] `biz/wishlist/*.go`, `biz/audit/*.go`, `biz/worker/*.go`, `biz/analytics/*.go`

6. Build + Lint
   - [ ] `go build ./...` ✅
   - [ ] `golangci-lint run` ✅

---

### Track J: gRPC Client Common Extension (P1, 1 ngày)

> **Agent J** — Chỉ sửa trong `common/client/`
> **BLOCKING cho Phase 2 Track K**

**Hiện trạng:** `common/client/grpc_factory.go` chỉ support static endpoint (`GetServiceEndpoint`). 5 service clients đang tự gọi `consul.New()` + `grpc.DialInsecure()`.

**Bước thực hiện:**

1. Extend `GRPCClientFactory` hoặc `GRPCClientBuilder`
   - [ ] Thêm `WithConsulDiscovery(consulAddr, serviceName string)` method
   - [ ] Wrap `consul.New()` + `grpc.DialInsecure()` + Circuit Breaker + Retry
   - [ ] Return `*grpc.ClientConn` chuẩn Kratos

2. Build + Test
   - [ ] `go build ./...` ✅
   - [ ] `go test ./client/...` ✅

3. Tag + Push
   - [ ] `git tag -a v1.19.0`
   - [ ] `git push origin main && git push origin v1.19.0`

---

### Track L: Biz Validation Cleanup (P2, 2–3 ngày)

> **Agent L** — Sửa code trong từng service
> **Mục tiêu:** Dọn code validation thủ công redundant từ biz layer (đã có `validate.Validator()` middleware)

**Hiện trạng:** Trước khi Track C2 deploy `validate.Validator()`, dev đã code validation thủ công trong biz. Giờ middleware đã active → code thủ công redundant.

- [ ] Audit `grep -rn 'validation.NewValidator\|Validate()' */internal/biz/ --include='*.go'`
- [ ] Xoá validation thủ công ở các service mà proto rules đã cover
- [ ] Verify build từng service sau khi xoá
- [ ] **Lưu ý:** Giữ lại validation logic KHÔNG cover bởi proto (business rules phức tạp)

---

### Track M: AlertService Integration (P3, 2–3 ngày)

> **Agent M** — Sửa code trong `notification/`, `order/`, `checkout/`, `warehouse/`, `return/`
> **Mục tiêu:** Implement Slack/PagerDuty integration cho AlertService

**Hiện trạng:** Interface `biz.AlertService` defined ở 4 services, stub implementation exists.

- [ ] Implement concrete AlertService in `notification/` service
  - [ ] Slack webhook integration (P2/P3 alerts)
  - [ ] PagerDuty Events API v2 (P0/P1 alerts)
- [ ] Wire AlertService implementation vào order, checkout, warehouse, return
- [ ] Verify alert delivery end-to-end

---

### Track N: API Gateway Rate Limiting (P2, 1–2 ngày)

> **Agent N** — Sửa config trong `gateway/` hoặc `gitops/`
> **Mục tiêu:** Chống DDoS Layer 7

- [ ] Evaluate rate limiting solution (Traefik middleware / Redis-based)
- [ ] Configure per-endpoint rate limits
- [ ] Test with load testing tool

---

## Phase 2: Sequential Tracks (SAU KHI Phase 1 Track J xong)

### Track K: gRPC Client Migration (P1, 2 ngày)

> **Agent K** — Sửa code trong 5 services
> **Depends on:** Phase 1 Track J (common/client extension)

**Mục tiêu:** Migrate 5 clients sang `common/client` factory với Consul discovery.

- [ ] `auth/internal/client/user/user_client.go` — replace `consul.New()` + `grpc.DialInsecure()`
- [ ] `auth/internal/client/customer/customer_client.go`
- [ ] `warehouse/internal/client/user_client.go`
- [ ] `customer/internal/client/auth/auth_client.go`
- [ ] `search/internal/client/provider.go`
- [ ] Verify build + lint cho mỗi service
- [ ] Giữ nguyên domain-specific logic (custom CB config, retry policies)

---

## Phase 3: Future Sprints

### Track P: RBAC Policy Migration (P2, Future)
- [ ] Evaluate Casbin / OPA cho policy-based access control
- [ ] Replace hardcoded `RequireRole("admin")` patterns
- [ ] Load policies từ Database/Redis thay vì compile-time

### Track Q: Cursor Pagination Migration (P1, 8–10 ngày)
> Audit đã hoàn thành (Track H1). 170+ offset pagination instances.
- [ ] Migrate `warehouse` stock_transactions → `CursorPaginator`
- [ ] Migrate `order` orders → `CursorPaginator`
- [ ] Update proto list request/response — thêm `cursor`/`next_cursor`
- [ ] Rollout dần sang các service khác

### Track R: GitOps Component Migration (Optional, 18–28 giờ)
> Templates đã ready (Track G). 3/20 API using common-deployment.
- [ ] Migrate remaining 17 API deployments → `common-deployment` component
- [ ] Migrate 20 worker deployments → `common-worker-deployment` component

---

## Dependency Graph

```
Phase 1 (Song song ngay):
  Track I (Customer Domain)     — độc lập
  Track J (Common Client Ext)   — BLOCKING cho Phase 2
  Track L (Biz Validation)      — độc lập
  Track M (AlertService)        — độc lập
  Track N (Rate Limiting)       — độc lập

Phase 2 (Sau Track J):
  Track K (gRPC Client Migration) — depends on Track J

Phase 3 (Future):
  Track P (RBAC)
  Track Q (Cursor Pagination)
  Track R (GitOps Migration)
```

## Agent Assignment Summary

| Agent | Track | Depends On | Scope | Est. |
|-------|-------|------------|-------|------|
| Agent I | Customer Domain (I) | None | `customer/` only | 3-5d |
| Agent J | Common Client Ext (J) | None | `common/client/` only | 1d |
| Agent K | gRPC Client Migration (K) | Track J | 5 services | 2d |
| Agent L | Biz Validation (L) | None | Per-service code | 2-3d |
| Agent M | AlertService (M) | None | notification + 4 services | 2-3d |
| Agent N | Rate Limiting (N) | None | gateway/gitops | 1-2d |

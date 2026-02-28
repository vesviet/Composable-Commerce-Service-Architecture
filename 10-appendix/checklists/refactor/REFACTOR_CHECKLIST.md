# Refactor Checklist — Multi-Agent Parallel Execution

> **Verified:** 16 analysis reports cross-checked against codebase (2026-02-28)
>
> **Quy tắc:** Mỗi agent nhận **1 Track** và làm độc lập. Track A (Common Lib) là **BLOCKING** — phải xong trước khi bắt đầu Track D/E/F. Các Track B, C, H có thể chạy **song song ngay** với Track A.

---

## Track A: 🔒 Common Library Updates (BLOCKING cho Track D/E/F)

> **Agent A** — Chỉ sửa trong thư mục `common/`
> **Ước lượng:** 2-3 ngày

### A1. common/worker — WorkerApp Bootstrap
- [ ] Tạo `common/worker/app.go` — `NewWorkerApp()` với Options pattern
- [ ] Encapsulate: registry setup, health server (8081), signal trap, graceful shutdown
- [ ] Tạo Mode enum (`CronMode`, `EventMode`, `AllMode`) thay string matching
- [ ] Tạo `common/worker/cron_worker.go` — `NewCronWorker(name, interval, logger, doFunc)`
  - Dev chỉ implement `Do(ctx context.Context) error`, wrapper lo ticker/select/stop
- [ ] Unit tests cho WorkerApp + CronWorker

### A2. common/migrate — Goose Bootstrap  
- [ ] Tạo `common/migrate/app.go` — `NewGooseApp()` với Options pattern
- [ ] Encapsulate: env loading, CLI flags (`-command`), DB connect, goose run
- [ ] Unit tests

### A3. common/api/errors — Unified Error Mapping
- [ ] Tạo `common/api/errors/encoder.go` — map Domain Errors → HTTP/gRPC status
- [ ] Support: `ErrNotFound→404`, `ErrUnauthorized→401`, `ErrValidation→400`, etc.
- [ ] Kratos middleware wrapper cho cả HTTP + gRPC server
- [ ] Unit tests

### A4. common/registry — Consul Registrar (đã có sẵn, cần nâng cấp)
- [ ] Review + nâng cấp `common/registry/consul.go` — đảm bảo `NewConsulRegistrar(addr)` wrapper đủ dùng cho mọi service
- [ ] Unit tests bổ sung

### A5. common/client — gRPC Discovery Factory
- [ ] Nâng cấp `common/client/grpc_factory.go` — `NewDiscoveryClient(targetService, consulAddr)`
- [ ] Bọc sẵn: Consul resolver, Circuit Breaker, Retry, KeepAlive, Pool
- [ ] Unit tests

### A6. common/idempotency — Redis SetNX Idempotency
- [ ] Nâng cấp `common/idempotency/` — thêm Redis-based idempotency dùng `SetNX` (atomic)
- [ ] Cấm pattern `Get → Check → Set` (race condition)
- [ ] Unit tests

### A7. common/utils/pagination — Cursor-based Pagination
- [ ] Thêm `common/utils/pagination/cursor.go` — `NewCursorPaginator()` hỗ trợ Keyset pagination
- [ ] Giữ nguyên Offset paginator cho bảng nhỏ, thêm Cursor cho bảng lớn
- [ ] Unit tests

---

## Track B: 🚨 GitOps P0 Fixes (Song song với A, KHÔNG phụ thuộc common)

> **Agent B** — Chỉ sửa trong thư mục `gitops/`
> **Ước lượng:** 1-2 ngày

### B1. NetworkPolicy — Xoá hardcode `-dev` namespace
- [ ] `gitops/apps/admin/base/networkpolicy.yaml`
- [ ] `gitops/apps/analytics/base/networkpolicy.yaml`
- [ ] `gitops/apps/auth/base/networkpolicy.yaml`
- [ ] `gitops/apps/catalog/base/networkpolicy.yaml`
- [ ] `gitops/apps/checkout/base/networkpolicy.yaml`
- [ ] `gitops/apps/common-operations/base/networkpolicy.yaml`
- [ ] `gitops/apps/customer/base/networkpolicy.yaml`
- [ ] `gitops/apps/frontend/base/networkpolicy.yaml`
- [ ] `gitops/apps/fulfillment/base/networkpolicy.yaml`
- [ ] `gitops/apps/gateway/base/networkpolicy.yaml`
- [ ] `gitops/apps/location/base/networkpolicy.yaml`
- [ ] `gitops/apps/loyalty-rewards/base/networkpolicy.yaml`
- [ ] `gitops/apps/notification/base/networkpolicy.yaml`
- [ ] `gitops/apps/order/base/networkpolicy.yaml`
- [ ] `gitops/apps/payment/base/networkpolicy.yaml`
- [ ] `gitops/apps/pricing/base/networkpolicy.yaml`
- [ ] `gitops/apps/promotion/base/networkpolicy.yaml`
- [ ] `gitops/apps/return/base/networkpolicy.yaml`
- [ ] `gitops/apps/review/base/networkpolicy.yaml`
- [ ] `gitops/apps/search/base/networkpolicy.yaml`
- [ ] `gitops/apps/shipping/base/networkpolicy.yaml`
- [ ] `gitops/apps/user/base/networkpolicy.yaml`
- [ ] `gitops/apps/warehouse/base/networkpolicy.yaml`

### B2. Worker Dapr Annotations — Thêm `app-port` + `app-protocol`
- [ ] `gitops/apps/analytics/base/worker-deployment.yaml` — thêm `app-port: "5019"`, `app-protocol: "grpc"`
- [ ] `gitops/apps/auth/base/worker-deployment.yaml` — thêm `app-port`, `app-protocol`
- [ ] `gitops/apps/location/base/worker-deployment.yaml` — thêm `app-port`, `app-protocol`

### B3. Worker Probes Fix
- [ ] `gitops/apps/loyalty-rewards/base/worker-deployment.yaml` — startupProbe: `tcpSocket 5005` → `httpGet /healthz port 8081`
- [ ] `gitops/apps/notification/base/worker-deployment.yaml` — uncomment probes
- [ ] `gitops/apps/catalog/base/worker-deployment.yaml` — thêm liveness/readiness probes

### B4. Worker `-mode` Flag — Set explicitly
- [ ] auth: `-mode event`
- [ ] catalog: `-mode event`
- [ ] checkout: `-mode all`
- [ ] common-operations: `-mode all`
- [ ] customer: `-mode event`
- [ ] fulfillment: `-mode event`
- [ ] notification: `-mode event`
- [ ] order: `-mode all`
- [ ] payment: `-mode all`
- [ ] pricing: `-mode event`
- [ ] promotion: `-mode event`
- [ ] return: `-mode event`
- [ ] review: `-mode event`
- [ ] search: `-mode event`
- [ ] shipping: `-mode event`
- [ ] user: `-mode event`
- [ ] warehouse: `-mode all`

### B5. Secret Naming — Chuẩn hoá thành `-secrets`
- [ ] `auth-secret` → `auth-secrets` (worker-deployment only)
- [ ] `gateway-secret` → `gateway-secrets` (deployment only)
- [ ] `search-secret` → `search-secrets` (deployment + worker-deployment)
- [ ] `warehouse-db-secret` → `warehouse-secrets` (deployment + worker-deployment)

### B6. Return Migration Job
- [ ] `gitops/apps/return/base/migration-job.yaml` — args: `cd /app && /app/bin/migrate -command up`

### B7. API Deployments — Thêm volumeMounts + volumes
- [ ] `gitops/apps/checkout/base/deployment.yaml`
- [ ] `gitops/apps/fulfillment/base/deployment.yaml`
- [ ] `gitops/apps/loyalty-rewards/base/deployment.yaml`
- [ ] `gitops/apps/notification/base/deployment.yaml`
- [ ] `gitops/apps/order/base/deployment.yaml`
- [ ] `gitops/apps/payment/base/deployment.yaml`
- [ ] `gitops/apps/pricing/base/deployment.yaml`
- [ ] `gitops/apps/review/base/deployment.yaml`
- [ ] `gitops/apps/shipping/base/deployment.yaml`
- [ ] `gitops/apps/user/base/deployment.yaml`
- [ ] `gitops/apps/warehouse/base/deployment.yaml`
- [ ] `gitops/apps/admin/base/deployment.yaml`
- [ ] `gitops/apps/frontend/base/deployment.yaml`

### B8. Worker Deployments — Thêm volumeMounts + volumes
- [ ] auth, checkout, common-operations, customer, fulfillment
- [ ] location, loyalty-rewards, notification, order, payment
- [ ] return, review, shipping, user, warehouse

### B9. HPA — Move từ `base/` sang `overlays/production/`
- [ ] analytics, fulfillment, gateway, location, order, payment, review, warehouse
- [ ] Worker HPA: fulfillment, order, promotion, shipping, warehouse

### B10. Worker startupProbe — Chuẩn `httpGet /healthz port 8081`
- [ ] fulfillment (`tcpSocket grpc-svc` → httpGet)
- [ ] order (`tcpSocket grpc-svc` → httpGet)
- [ ] payment (`tcpSocket grpc-svc` → httpGet)
- [ ] warehouse (`tcpSocket grpc-svc` → httpGet)

---

## Track C: 🚨 Code P0 Fixes (Song song với A+B, KHÔNG phụ thuộc common)

> **Agent C** — Sửa code trong từng service (2 sub-tracks có thể chia thêm)
> **Ước lượng:** 2-3 ngày

### C1. `return` Migration Table Name Bug
- [ ] `return/cmd/migrate/main.go:64` — `"order_goose_db_version"` → `"return_goose_db_version"`
- [ ] Sửa log message tương ứng

### C2. `validate.Validator()` Middleware — Thêm vào ALL services
> Mỗi service: sửa `internal/server/http.go` + `internal/server/grpc.go`, thêm `validate.Validator()` vào middleware chain.

- [ ] analytics
- [ ] auth
- [ ] catalog
- [ ] checkout
- [ ] common-operations
- [ ] customer
- [ ] fulfillment
- [ ] gateway
- [ ] location
- [ ] loyalty-rewards
- [ ] notification
- [ ] order
- [ ] payment
- [ ] pricing
- [ ] promotion
- [ ] return
- [ ] review
- [ ] search
- [ ] shipping
- [ ] user
- [ ] warehouse

### C3. Customer Service — Clean Architecture Fix
- [ ] `customer/internal/model/customer.go` — xoá `ToCustomerReply()`, `ToStableCustomerGroupReply()`
- [ ] Tạo Domain Model trong `customer/internal/biz/` (struct thuần Go, không GORM tag)
- [ ] Tạo converter `customer/internal/service/*_convert.go`
- [ ] Update `customer/internal/data/` — return Domain Model thay vì GORM model
- [ ] Verify build + tests pass

### C4. 🚨 Payment Idempotency Race Condition (P0 — Double-Charge Risk)
- [ ] `payment/internal/biz/common/idempotency.go` — Replace ALL `Get → Check → Set` patterns with `SetNX` (atomic)
- [ ] Lines affected: 88, 125, 160, 193, 250, 267, 289, 307, 326
- [ ] Verify với concurrent request test

### C5. 🚨 Logging Middleware — trace_id Missing (P0)
- [ ] `common/middleware/logging.go:59-60` — Fix `SpanFromContext` trên Gin context (luôn trả invalid span)
- [ ] Chuyển sang dùng Kratos Logger global với `tracing.TraceID()` inject sẵn
- [ ] Verify trace_id xuất hiện trong log output

---

## Track D: 🟡 Service Code Enforcement — Dapr + Events (SAU KHI Track A xong)

> **Agent D** — Migrate 4 services sang `common/events`
> **Ước lượng:** 1-2 ngày
> **Depends on:** Track A hoàn thành

### D1. Warehouse — Migrate Dapr Publisher
- [ ] Xoá raw `dapr.NewClient()` trong `warehouse/internal/data/storage.go`
- [ ] Inject `common/events.EventPublisher` qua Wire
- [ ] Verify build + tests

### D2. Shipping — Migrate Dapr Publisher
- [ ] Xoá `shipping/internal/data/dapr_client.go`
- [ ] Inject `common/events.EventPublisher` qua Wire
- [ ] Verify build + tests

### D3. Location — Migrate Dapr Publisher
- [ ] Xoá `location/internal/event/publisher.go`
- [ ] Inject `common/events.EventPublisher` qua Wire
- [ ] Verify build + tests

### D4. Common-Operations — Migrate Dapr Publisher
- [ ] Xoá/refactor `common-operations/internal/event/publisher.go`
- [ ] Inject `common/events.EventPublisher` qua Wire
- [ ] Verify build + tests

---

## Track E: 🟡 Service Code Enforcement — Transactions + Cache + gRPC (SAU KHI Track A xong)

> **Agent E** — Migrate services sang common libs
> **Ước lượng:** 2-3 ngày
> **Depends on:** Track A hoàn thành

### E1. Transaction Manager — Migrate 5 services
- [ ] `checkout/internal/data/data.go` — xoá `dataTransactionManager`, dùng `common`
- [ ] `checkout/internal/biz/transaction.go` — xoá, dùng Common interface
- [ ] `shipping/internal/biz/transaction.go` — xoá custom TransactionManager
- [ ] `order/internal/data/transaction.go` + `transaction_adapter.go` — consolidate
- [ ] `return/internal/biz/transaction.go` + `return/internal/data/transaction.go` — migrate
- [ ] `pricing/internal/data/postgres/price.go` — refactor transaction logic
- [ ] Verify build + tests cho mỗi service

### E2. Checkout Cache — Migrate sang TypedCache
- [ ] Xoá `checkout/internal/cache/cache.go`
- [ ] Refactor repos dùng `common/utils/cache/TypedCache[T]`
- [ ] Verify build + tests

### E3. gRPC Client — Migrate sang common/client
- [ ] `customer/internal/client/auth/auth_client.go`
- [ ] `auth/internal/client/customer/customer_client.go`
- [ ] `auth/internal/client/user/user_client.go`
- [ ] `shipping/internal/client/catalog_grpc_client.go`
- [ ] `warehouse/internal/client/user_client.go`
- [ ] `common-operations/internal/client/order_client.go`
- [ ] `location/internal/client/example_client.go`

### E4. Consul Registrar — Migrate sang common/registry
- [ ] Audit all `internal/server/consul.go` files (currently only `user` has standalone file)
- [ ] Replace with `common/registry.NewConsulRegistrar()`
- [ ] Verify build cho mỗi service

### E5. Outbox Traceparent — Enforce trace context propagation
- [ ] Audit all services calling `outboxRepo.Create()` / `Save()` — must pass `extractTraceparent(ctx)`
- [ ] Primary targets: order, payment (confirmed missing traceparent injection)
- [ ] Verify tracing continuity on Jaeger after fix

### E6. GORM Preload Audit — Replace with Joins in List queries
- [ ] `warehouse/internal/data/postgres/` — 10+ Preload calls in adjustment.go, backorder.go
- [ ] Audit other services for Preload in List/Search functions
- [ ] Replace with `.Joins()` + `.Select()` for list endpoints

---

## Track F: 🔵 Worker + Migrate DRY (SAU KHI Track A xong)

> **Agent F** — Refactor cmd/worker + cmd/migrate across ALL services
> **Ước lượng:** 3-5 ngày
> **Depends on:** Track A1 + A2 hoàn thành

### F1. Migrate `cmd/worker/main.go` — Dùng WorkerApp (20 services)
- [ ] analytics
- [ ] auth
- [ ] catalog
- [ ] checkout
- [ ] common-operations
- [ ] customer
- [ ] fulfillment
- [ ] location
- [ ] loyalty-rewards
- [ ] notification
- [ ] order
- [ ] payment
- [ ] pricing
- [ ] promotion
- [ ] return
- [ ] review
- [ ] search
- [ ] shipping
- [ ] user
- [ ] warehouse

### F2. Migrate `cmd/migrate/main.go` — Dùng GooseApp (19 services)
- [ ] analytics, auth, catalog, checkout, common-operations
- [ ] customer, fulfillment, location, loyalty-rewards, notification
- [ ] order, payment, pricing, promotion, return
- [ ] review, search, shipping, user

### F3. Outbox Worker — Enforce common/outbox (3 services)
- [ ] `order/internal/worker/outbox/` — xoá, dùng `common/outbox.NewWorker()`
- [ ] `checkout/internal/worker/outbox/` — xoá, dùng `common/outbox.NewWorker()`
- [ ] `payment/internal/worker/outbox/` — xoá, dùng `common/outbox.NewWorker()`

### F4. Cron Workers — Migrate sang CronWorker wrapper
- [ ] order: 7 cron jobs (cleanup, compensation, retry, cod, capture, dlq, reservations)
- [ ] payment: 7 cron jobs (refund, retry, reconciliation, capture, cleanup, expiry, sync)
- [ ] checkout: 3 cron jobs (cart_cleanup, session_cleanup, failed_compensation)
- [ ] analytics: 2 cron jobs (retention, alert_checker)
- [ ] common-operations: 3 cron jobs (retry_failed, detect_timeouts, process_scheduled)
- [ ] fulfillment: 2 cron jobs (auto_complete, sla_breach)
- [ ] auth: 1 cron (session_cleanup)
- [ ] search: 3 workers (orphan_cleanup, dlq_reprocessor, reconciliation)
- [ ] catalog: 1 cron (outbox_cleanup)

---

## Track G: 🔵 GitOps DRY — Kustomize Base Templates (SAU KHI Track B xong)

> **Agent G** — GitOps template refactoring
> **Ước lượng:** 3-5 ngày
> **Depends on:** Track B hoàn thành (cần biết final standard values)

### G1. Fix `common-deployment/deployment.yaml` template
- [ ] Add `/health/live`, `/health/ready` paths
- [ ] Add `startupProbe` block
- [ ] Add `volumeMounts` + `volumes` section
- [ ] Add `secretRef` section
- [ ] Update `sync-wave` annotation

### G2. Create Worker Base Template
- [ ] Tạo `gitops/apps/common-bases/worker/deployment.yaml`
- [ ] Include: Dapr annotations, health probes, volumeMounts, init containers
- [ ] Standardize: `-mode` args, resource limits

### G3. Migrate All Services to Base Templates
- [ ] Per-service: replace full `deployment.yaml` with kustomize patches
- [ ] Per-service: replace full `worker-deployment.yaml` with kustomize patches
- [ ] Verify ArgoCD sync works correctly

---

## Track H: 🚨 Performance & Observability Fixes (Song song với A+B+C, KHÔNG phụ thuộc)

> **Agent H** — Sửa code performance và observability
> **Ước lượng:** 2-3 ngày
> **Depends on:** None (có thể song song ngay)

### H1. Payment Idempotency — Cursor-based Pagination chuẩn bị
- [ ] Audit `common/utils/pagination/pagination.go` — xác định scope bảng cần Cursor
- [ ] Audit warehouse, order repo cho Offset pagination trên bảng lớn

### H2. GORM Preload Audit — Scope toàn hệ thống
- [ ] `grep -rn 'Preload(' */internal/data/ --include='*.go'` — liệt kê tất cả
- [ ] Phân loại: nào dùng trong `GetByID` (OK), nào dùng trong `List/Search` (cần đổi Joins)

### H3. Saga Docs (P2)
- [ ] Viết Workflow Sequence Diagram (Mermaid) cho Order Saga 3-phase vào `docs/05-workflows/`
- [ ] Verify `biz.AlertService` đã integrate Slack/PagerDuty chưa

---

## Dependency Graph

```
Track A (Common Lib) ──┬──→ Track D (Dapr Enforcement)
                       ├──→ Track E (Tx/Cache/gRPC/Outbox/Preload)
                       └──→ Track F (Worker/Migrate DRY)

Track B (GitOps P0)  ─────→ Track G (GitOps DRY)

Track C (Code P0: validate, return, payment, logging)

Track H (Performance & Observability)

══════════════════════════════════════════════════════
 PARALLEL LANES:  A | B | C | H   (ngay lập tức)
                  D | E | F       (sau khi A xong)
                  G               (sau khi B xong)
══════════════════════════════════════════════════════
```

## Agent Assignment Summary

| Agent | Track | Depends On | Scope | Est. |
|-------|-------|------------|-------|------|
| Agent A | Common Lib (A1-A7) | None | `common/` only | 3-5d |
| Agent B | GitOps P0+P1 (B1-B10) | None | `gitops/` only | 2-3d |
| Agent C | Code P0 (C1-C5) | None | Per-service code | 2-3d |
| Agent H | Perf/Observability (H1-H3) | None | Cross-service audit | 2-3d |
| Agent D | Dapr Enforce (D1-D4) | Track A | 4 services | 1-2d |
| Agent E | Tx/Cache/gRPC/Outbox (E1-E6) | Track A | 7+ services | 3-5d |
| Agent F | Worker/Migrate DRY (F1-F4) | Track A | All services | 3-5d |
| Agent G | GitOps DRY (G1-G3) | Track B | `gitops/` templates | 3-5d |

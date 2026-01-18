# Order Service — Code Review vs Master Rubric (1→10)

**Date**: 2026-01-16  
**Reviewer**: Senior Tech Lead (Cascade)  
**Rubric**: `docs/checklists/BACKEND_SERVICES_REVIEW_CHECKLIST.md`  
**Scope**: `/order` (cart + checkout + order + workers + outbox + migrations)

---

## 0) Codebase Index (quick navigation)

- **Entrypoints**:
  - `order/cmd/order/main.go`
  - `order/cmd/worker/main.go`
  - `order/cmd/migrate/main.go`

- **Servers**:
  - `order/internal/server/http.go`

- **Service layer (API handlers)**:
  - `order/internal/service/order.go`
  - `order/internal/service/cart.go`

- **Biz domains**:
  - Checkout: `order/internal/biz/checkout/*`
  - Order: `order/internal/biz/order/*`
  - Cart: `order/internal/biz/cart/*`
  - Cross-cutting: `order/internal/biz/transaction.go`, `order/internal/biz/event_idempotency.go`, `order/internal/biz/failed_event.go`

- **Data layer**:
  - Wire + infra: `order/internal/data/data.go`
  - Postgres repos: `order/internal/data/postgres/*`

- **Workers**:
  - Cron: `order/internal/worker/cron/*`
  - Outbox: `order/internal/worker/outbox/*`

- **Migrations**:
  - `order/migrations/*`

---

## 1) 🏗 Architecture & Clean Code

### Findings
- **Good**:
  - Standard layout present (`cmd/`, `api/`, `internal/biz`, `internal/data`, `internal/service`, `internal/server`).
  - Biz layer does not import GORM directly (clean separation).
  - DI via `wire` (`cmd/order/wire.go`, `cmd/worker/wire.go`) aligns with constructor injection guidance.
- **Risk / Gap (P2)**:
  - Một số cross-cutting (admin detection/guard) có dấu hiệu trùng lặp giữa common middleware và local wrapper (`internal/server/admin_middleware.go`). Nên có **single source of truth**.

### Score
- **8.5/10**

---

## 2) 🔌 API & Contract (gRPC/HTTP)

### Findings
- **Good**:
  - HTTP server registers Swagger UI and exposes spec at `/docs/openapi.yaml` (`order/internal/server/http.go`).
  - `ErrorEncoder` is configured in the HTTP server for consistent status mapping.
  - AuthZ hooks exist via middleware utilities (`order/internal/middleware/auth.go`) and an explicit `AdminGuard` wrapper for DLQ.
- **Gap (P1)**:
  - `ErrorEncoder` currently does `w.WriteHeader(int(se.Code))` assuming Kratos `Error.Code` == HTTP status. Nếu service tạo error codes theo business code (không phải HTTP status), mapping này sẽ sai. Nên map gRPC/kratos codes → HTTP status (hoặc enforce convention rõ ràng).
  - `openapi.yaml` needs a quick contract quality pass (metadata/title/version/summary) để hỗ trợ gateway aggregation tốt hơn.

### Score
- **8/10**

---

## 3) 🧠 Business Logic & Concurrency

### Findings
- **Good**:
  - Checkout uses `errgroup` for parallel work (good pattern) instead of unmanaged goroutines for top-level fan-out.
  - `CreateOrder` idempotency đã được harden bằng **DB unique constraint** (`orders.cart_session_id`) + recovery path on unique violation (`order/internal/biz/order/create.go`).
  - Repo lookup for idempotency is deterministic and lightweight (`FindByCartSessionID` orders by `created_at DESC` and no preload).
- **Gap (P1)**:
  - Trong `CheckoutPreview`, vẫn còn `go func(...)` per-item bên trong một `errgroup` task, nhưng không gắn với context cancel của `errgroup` (ngoài việc dùng `gCtx` khi call service). Nếu item goroutine bị leak khi upstream returns early, khó quản lý.
  - Có hardcoded context (`"USD"`, `"VN"`) khi gọi pricing trong preview; dễ tạo sai lệch giá/thuế theo region.
  - Logging: đang dùng `fmt.Printf` thay vì structured logger; thiếu `trace_id`.

### Concrete Actions
- **P1**: Thay `go func` per-item bằng `errgroup.Group` (nested) hoặc worker-pool pattern có giới hạn concurrency + respect `gCtx`.
- **P1**: Loại bỏ hardcode currency/country; lấy từ request/cart/session metadata.
- **P2**: Chuẩn hoá logging (no `fmt.Printf`), dùng `uc.log.WithContext(ctx)`.

### Score
- **7.5/10**

---

## 4) 💽 Data Layer & Persistence

### Findings
- **Good**:
  - Transaction boundary exists via TransactionManager and is used for order creation + outbox save (Transactional Outbox pattern).
  - Idempotency has moved to a dedicated column `orders.cart_session_id` + a partial unique index (`migrations/032_add_cart_session_id_to_orders.sql`).
  - Repo has a dedicated `FindByCartSessionID` with deterministic ordering and minimal load (`internal/data/postgres/order.go`).
- **Gap (P1)**:
  - `orderRepo.Create` wraps a `Transaction(...)` internally, while the caller (`UseCase.CreateOrder`) also wraps a transaction via `tm.WithTransaction`. Nested transaction semantics in GORM can be subtle; ensure `getDB(ctx)` returns the transaction db and the inner `Transaction` doesn't inadvertently create a savepoint/commit boundary you didn't expect.
  - `getDB(ctx)` relies on a magic string context key `"gorm:transaction_db"` → brittle and easy to drift across services.

### Concrete Actions
- **P1**: Audit `tm.WithTransaction` + `orderRepo.Create` interaction; consider removing the inner `Transaction(...)` when already in a tx, or guarantee savepoints are acceptable.
- **P2**: Replace magic context key with a typed key shared via common package.

### Score
- **7.5/10**

---

## 5) 🛡 Security

### Findings
- **Good**:
  - Service trusts Gateway and uses metadata propagation prefixes; customer listing auto-extracts customer id for non-admin.
  - Rate limiting is enabled when Redis is available (common middleware) at HTTP server.
- **Gap (P1)**:
  - Trust boundary relies on Gateway stripping spoofed `x-user-*` headers; ensure network policy prevents bypass.
  - Admin detection logic is duplicated (`commonMiddleware.IsAdmin(ctx)` + fallback header check `X-Admin-Roles`). This increases drift risk across services.
- **Gap (P1)**:
  - DLQ endpoints are registered directly under `/api/v1/admin/dlq/*` in `order/internal/server/http.go`. There is no obvious defense-in-depth guard at the service layer (authorization appears to be assumed at Gateway).

### Concrete Actions
- **P1**: Centralize admin detection into common middleware/util (single source of truth) and remove duplicated per-service header probing.
- **P1**: Add defense-in-depth authorization for admin-only endpoints (DLQ) at service layer (middleware/handler guard), in addition to Gateway enforcement.

### Score
- **7/10****

---

## 6) ⚡ Performance & Scalability

### Findings
- **Good**:
  - DB pool config is configurable.
  - Redis available for rate limit + caches.
- **Gap (P1/P2)**:
  - Cleanup jobs delete per-row; consider batching.
  - Need explicit index review for key queries (`session_id`, `expires_at`, JSONB metadata).

### Score
- **7/10****

---

## 7) 👁 Observability

### Findings
- **Good**:
  - HTTP middleware includes tracing + metrics + logging + recovery.
  - `/metrics` and `/health*` endpoints are exposed.
- **Gap (P1)**:
  - Business metrics abstraction exists but default implementation is no-op (`order/internal/biz/monitoring.go`).

### Score
- **8/10**

---

## 8) 🧪 Testing & Quality

### Findings
- **Gap (P1)**: Không có thư mục `*_test.go` trong toàn bộ service (`grep -R "_test.go" order/internal` ⇒ none). Điều này trái với tiêu chí **"Linter Compliance & Unit test coverage ≥ 70 %"** trong hướng dẫn Team Lead.
- **Gap (P1)**: Chưa có test e2e cho các luồng Checkout → Payment → Order → Outbox.
- **Gap (P2)**: Thiếu mocks cho adapter bên ngoài (Payment, Catalog) ⇒ khó viết unit test.
- **Good**:
  - Mã nguồn đã tách interface rõ ràng (Repo, Usecase, Adapter) ⇒ thuận lợi cho mocking nếu bổ sung test sau.

### Concrete Actions
- **P1**: Bổ sung tối thiểu 30 % unit-test coverage cho `order/internal/biz/...` (CreateOrder, Checkout flow). Sử dụng `go test -coverprofile` + CI gate.
- **P1**: Thêm workflow GitLab CI chạy `golangci-lint` & `go test ./...`.
- **P2**: Viết test e2e dùng `testcontainers-go` spin-up Postgres + Redis để verify idempotency & outbox.

### Score
- **4/10**

---

## 9) ⚙️ Configuration & Resilience

### Findings
- **Good**:
  - Typed config exists: `order/internal/config/config.go`.
  - DB/Redis timeouts are configurable.
- **Gap (P1)**:
  - Need audit of external service client timeouts/retries/circuit breakers usage in adapters.

### Score
- **7.5/10**

---

## 10) 📚 Documentation & Maintenance

### Findings
- **Gap (P2)**: README chưa cập nhật flow mới (idempotency by DB constraint, outbox worker, status history).
- **Gap (P2)**: `openapi.yaml` còn một số field `title:""`, version `0.0.1`, mô tả API sơ sài.
- **Good**: Có tài liệu `docs/cart_implementation.md`, `docs/shipping_integration.md` chi tiết.

### Concrete Actions
- **P2**: Cập nhật README với 3 sơ đồ: Sequence Checkout, Outbox, Worker.
- **P2**: Regenerate OpenAPI với `protoc-gen-openapi --tags=order` + viết mô tả summary, tags.

### Score
- **6/10**

---

## Cross-cutting Top Issues (P0/P1/P2)

### Findings
- **Pending audit**:
  - Need to review `order/README.md`, `order/openapi.yaml` completeness, and internal docs.

### Score
- **TBD**

---

## Cross-cutting Top Issues (P0/P1/P2)

## 🔴 P0 Critical
- **Payment capture before order creation** (already observed in checkout flow). Requires end-to-end hardening.

### P1
- **Idempotency needs DB-level uniqueness guarantee**.
- **Migration numbering conflict (`028_*.sql`)**.
- **Header trust boundary (gateway strip + network policy)**.

### P2
- Batch cleanup/perf improvements; doc/test audits.

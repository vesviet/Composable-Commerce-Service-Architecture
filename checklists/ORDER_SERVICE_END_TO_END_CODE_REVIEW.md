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
  - Biz layer does not import GORM (checked `gorm` usage under `order/internal/biz` → none).
- **Risk / Gap (P2)**:
  - Some cross-cutting concerns are duplicated across service/biz (e.g., admin detection checks headers + middleware). Consider centralizing.

### Score
- **8.5/10**

---

## 2) 🔌 API & Contract (gRPC/HTTP)

### Findings
- **Good**:
  - HTTP server registers Swagger/OpenAPI and `/docs/openapi.yaml`.
  - Service handlers perform validation early (e.g. `CreateOrder`, `GetOrder`).
- **Gap (P1)**:
  - Error mapping/encoder is not explicitly configured in `order/internal/server/http.go` (unlike some other services). Verify HTTP status mapping consistency.

### Score
- **8/10**

---

## 3) 🧠 Business Logic & Concurrency

### Findings
- **Good**:
  - Checkout updates implement optimistic-lock retry loops.
  - Background work primarily uses worker pattern (cron/outbox), not unmanaged goroutines.
- **Gap (P1)**:
  - Idempotency for `CreateOrder` is implemented as "query then return existing" based on `cart_session_id` stored in `orders.metadata`.
  - This is **not race-safe** without a DB uniqueness guarantee: two concurrent requests can both not find an existing order and both create a new order.
  - Current logic returns the *first* matched order if multiple exist (non-deterministic ordering).

### Concrete Actions
- **P1**: Add DB-level uniqueness guarantee for `cart_session_id` (prefer a dedicated column; alternative: generated column from `metadata->>'cart_session_id'` + unique index) and handle unique-violation by re-reading and returning the existing order.
- **P2**: If keeping metadata query, make it deterministic and lighter (e.g. `ORDER BY created_at DESC LIMIT 1`, minimal preload) to avoid heavy loads.

### Score
- **7/10

---

## 4) 💽 Data Layer & Persistence

### Findings
- **Good**:
  - DB/Redis pools configured via `common/utils/database` in `order/internal/data/data.go`.
  - TransactionManager abstraction exists (`order/internal/biz/transaction.go`) and is used in order creation.
  - Transactional Outbox is used in `order/internal/biz/order/create.go` (order insert + outbox event in the same transaction).
- **Gap (P1)**:
  - Idempotency relies on querying `orders.metadata` by JSONB (`metadata->>? = ?`) via `FindByMetadata`.
    - Without an index/unique constraint, this can become slow and is not race-safe.
    - Current repo method also preloads related entities (items/addresses), which is heavier than needed for idempotency checks.
  - Migration numbering conflict risk: multiple `028_*.sql` files in `order/migrations/`.

### Concrete Actions
- **P1**: Add a DB-level unique constraint for `cart_session_id` (prefer a dedicated column). This also enables returning the existing order on unique-violation.
- **P2**: Reduce the cost of idempotency lookup: deterministic `ORDER BY created_at DESC LIMIT 1` and avoid preloading unless the caller needs it.

### Score
- **7/10**

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
- **7/10**

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
- **7/10**

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
- Skipped in this review pass (per request: tạm thời bỏ qua testcase).

### Score
- **N/A**

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
- **Pending audit**:
  - Need to review `order/README.md`, `order/openapi.yaml` completeness, and internal docs.

### Score
- **TBD**

---

## Cross-cutting Top Issues (P0/P1/P2)

### P0
- **Payment capture before order creation** (already observed in checkout flow). Requires end-to-end hardening.

### P1
- **Idempotency needs DB-level uniqueness guarantee**.
- **Migration numbering conflict (`028_*.sql`)**.
- **Header trust boundary (gateway strip + network policy)**.

### P2
- Batch cleanup/perf improvements; doc/test audits.

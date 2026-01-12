# ✅ Backend Services - Code Review Checklist

**Last Updated**: January 11, 2026
**Reviewer**: Cascade (Tech Lead)
**Objective**: Systematically review all Go microservices to ensure they meet architecture standards, identify risks, and create a backlog of actionable improvements.

---

## 📊 Overall Review Progress

| Service Group | Status | Notes |
| :--- | :--- | :--- |
| **Core Libs & Gateway** | ✅ Completed | `common` & `gateway` reviewed. Key findings on routing & middleware. |
| **Identity** | ✅ Completed | `auth`, `user`, `customer` reviewed. |
| **Commerce** | 🟡 In Progress | `catalog` 🟡, `pricing` ✅, `promotion` 🟡 |
| **Logistics** | 🟡 In Progress | `order` 🟡 (review in progress), `warehouse` ⚪, `payment` ⚪, `fulfillment` ⚪, `shipping` ⚪ |
| **Supporting** | ⚪ Pending | `notification`, `search`, `analytics`, `location` |
| **Engagement** | ⚪ Pending | `review`, `loyalty-rewards` |

---

## 📝 Master Review Rubric

For each service, the following aspects will be reviewed:

-   **[ ] Architecture & Structure**: Does it follow the standard Clean Architecture layout?
-   **[ ] `go.mod` & Dependencies**: Are dependencies clean? Any version conflicts or deprecated libs?
-   **[ ] API (`/api/proto`)**: Is the gRPC/HTTP contract clear, consistent, and well-defined?
-   **[ ] Business Logic (`/internal/biz`)**: Is the core logic sound, testable, and free of data layer leakage?
-   **[ ] Data Layer (`/internal/data`)**: Correct use of repository pattern? Efficient queries? Transaction management?
-   **[ ] Configuration (`/configs`)**: Is configuration clear, secure (no hardcoded secrets), and consistent?
-   **[ ] Testing**: What is the state of unit and integration tests? Is coverage adequate?
-   **[ ] Observability**: Are there structured logs, relevant metrics, and distributed tracing?
-   **[ ] Security**: Any obvious vulnerabilities (e.g., injection, improper authz, data leakage)?
-   **[ ] Action Items**: A summary of findings and prioritized tasks.

---

## 🚀 Service-by-Service Review

### 1. `common` (Shared Library)

-   **[✅] Review Status**: Completed
-   **Findings**:
    -   **Good**: Comprehensive set of shared components (`errors`, `client`, `middleware`).
    -   **Good**: `client` package implements robust gRPC patterns with circuit breaker, retries, and observability.
    -   **Good**: `errors` package provides standardized error codes and structured JSON support.
    -   **Issue**: `README.md` is malformed; it concatenates the default GitLab template with the actual documentation (contains `=======` separator).
    -   **Issue**: `auth.go` type assertions are generally safe, but `RequireRole` logic allows `nil` roles to bypass validation if not strictly checked (though current implementation looks okay).
    -   **Issue**: Versioning is managed via `go.mod` comments; no specialized versioning tool/changelog automation.
-   **Action Items**:
    -   `[x]` **Fix README**: Remove the top half (GitLab template) and the `=======` line; keep the "Common Package" documentation.
    -   `[x]` **Standardize Versioning**: Create a `CHANGELOG.md` and enforce git tags matching `go.mod` version comments.
    -   `[x]` **Refactor Auth**: Encapsulate claim extraction to ensure type safety is centralized.

### 2. `gateway`

-   **[✅] Review Status**: Completed
-   **Findings**:
    -   **Good**: Kratos-based, health/metrics endpoints, policy-driven routing config.
    -   **Good**: Redis support added for rate limiting (configurable).
    -   **Issue (P0)**: Routing engine doesn't evaluate HTTP methods (security risk). `AuthMiddleware` skips auth based on path only; `POST` endpoints are exposed if they share a prefix with public `GET` ones.
    -   **Issue (P0)**: Default server timeout is non-deterministic (iterates random service map to pick a timeout).
    -   **Issue (P1)**: Public path list is duplicated: hardcoded in `kratos_middleware.go` (source of truth) vs `gateway.yaml` (misleading).
-   **Action Items**:
    -   `[P0]` **Immediate Fix**: Modify `AuthMiddleware` to check HTTP methods against config before skipping auth.
    -   `[P0]` **Long-term Fix**: Enhance routing engine to support `methods` in YAML.
    -   `[P1]` Add an explicit `gateway.default_timeout` config and use it in `server/http.go`.
    -   `[P1]` Refactor `AuthMiddleware` to read public paths ONLY from config; remove hardcoded map.

### 3. `auth`

-   **[✅] Review Status**: Completed
-   **Architecture Goal**: Token & Session management ONLY. User/credential logic belongs to `user`/`customer` services.
-   **Findings**:
    -   **[P0] Mismatch giữa Token & Session**: `TokenUsecase` tự tạo `session_id` (dạng `session_user_time`) trong khi `SessionUsecase` dùng UUID. Hai hệ thống không liên kết với nhau.
    -   **[P0] Mismatch giữa Code & DB Schema**: Code trong `userRepo` và `authRepo` đang thao tác với table `users`, nhưng migration lại tạo table `credentials`. Code sẽ fail runtime.
    -   **[P0] Logic `RefreshToken` không an toàn**: `ValidateToken` được dùng để check refresh token nhưng không kiểm tra `type` claim, cho phép access token có thể dùng để refresh.
    -   **[P0] Hardcoded Secrets**: `config.yaml` chứa `jwt.secret` và `encryption.key` mặc định.
    -   **[P1] Trùng lặp và sai scope**: `UserRepo` trong `auth` service là không cần thiết, logic bị trùng lặp và sai trách nhiệm.
    -   **[P1] Revoke token dùng `KEYS` trên Redis**: `RevokeUserTokens` dùng `KEYS` là một practice nguy hiểm cho production.
-   **Action Items**:
    -   `[x]` **[REMOVE]** `[P1]` Loại bỏ `UserRepo` và các logic User CRUD ra khỏi `auth` service. Chuyển trách nhiệm này cho `user` service.
    -   `[x]` **Refactor Token Generation**: `TokenUsecase.GenerateToken` phải gọi `SessionUsecase.CreateSession` để lấy `session_id` (UUID) thật sự.
    -   `[x]` **Fix Refresh Token Logic**: Phải kiểm tra `type == 'refresh'` trong claim khi refresh token.
    -   `[P0]` **Fix DB Mismatch**: Nếu `auth` cần lưu credential, đổi code để dùng table `credentials`. Nếu không, xóa bỏ logic liên quan.
    -   `[x]` **Secure Configuration**: Chuyển toàn bộ secret sang đọc từ environment variables và fail-fast nếu giá trị mặc định được dùng trong production.
    -   `[x]` **Optimize Revocation**: Thay thế `KEYS` bằng `SCAN` trong `RevokeUserTokens` hoặc dùng cấu trúc dữ liệu khác (e.g., a Redis SET per user).

### 4. `user`

-   **[✅] Review Status**: Completed
-   **Architecture Goal**: User management + RBAC + Admin login (credential validation). Token/session must be delegated to `auth`.
-   **Findings**:
    -   **Good**: Proto surface matches the domain well (users, roles, assignments, service access, auth-related internal RPCs).
    -   **Good**: `AdminLogin` validates credentials in `user` and delegates token generation to `auth` via gRPC client with circuit breaker.
    -   **Issue (P0)**: `user/internal/client/auth/auth_client.go` does not pass `roles` to `auth.GenerateToken` (parameter exists but not mapped). Current workaround stores roles in `claims["roles"]` as comma-separated string.
    -   **Issue (P1)**: Password hashing is done in service layer (`CreateUser`), while password validation is in biz layer; security logic is split.
    -   **Issue (P1)**: `ValidatePassword` logs part of password hash (`hash prefix`), which can leak sensitive info to logs.
    -   **Issue (P1)**: In `AssignRole` handler, `assignedBy` is set to `req.UserId` (self) instead of the actor from context; audit trail may be incorrect.
    -   **Issue (P2)**: `permissions` / `services` are stored as text JSON arrays; OK for now but may need `jsonb` + GIN indexes if querying becomes heavy.
-   **Action Items**:
    -   `[P0]` Pass `roles` into `authPB.GenerateTokenRequest` (`Roles: roles`) and align downstream consumption (avoid stringifying roles into claims).
    -   `[P1]` Move password hashing into biz/usecase (or consistently keep all password operations in biz), to centralize password policy and make testing easier.
    -   `[P1]` Remove password hash prefix from logs in `ValidatePassword`.
    -   `[P1]` Fix `assignedBy` / `grantedBy` to be derived from request context (e.g., `X-User-ID` injected by gateway), not the target user.
    -   `[P2]` Consider migrating `permissions`/`services` columns to `jsonb` + indexes if needed.

### 5. `customer`

-   **[✅] Review Status**: Completed
-   **Architecture Goal**: Customer profiles + addresses + preferences + segmentation. Token/session validation delegated to `auth`. Service must enforce authz for customer-scoped endpoints.
-   **Findings**:
    -   **Good**: Clean Architecture layout aligns with platform standard; repo/tx extraction pattern is consistent.
    -   **Good**: Auth integration exists via gRPC + Consul discovery + circuit breaker (`internal/client/auth`).
    -   **Issue (P0)**: `ValidateToken` parses JWT using `ParseUnverified` and can return `valid=true` without signature verification (forgeable if called outside gateway).
    -   **Issue (P0)**: Migration `015_add_customer_groups_support.sql` is not in Goose format and contains schema mismatch (`customer_type = 2` while base schema uses string enums). Risk of migration not running / incorrect default group assignment.
    -   **Issue (P0)**: Migration `001_create_customers_table.sql` uses `gen_random_uuid()` but does not ensure `pgcrypto` extension exists; fresh env migration can fail.
    -   **Issue (P0)**: Migration `010_add_password_hash_to_customers.sql` adds an index on `password_hash`, which is not used by typical login flows (wasteful, remove).
    -   **Issue (P1)**: HTTP server middleware stack lacks explicit auth/authz middleware; must ensure gateway enforcement + service-side authorization checks for customer-owned resources.
    -   **Issue (P1)**: Route conflict risk: `/api/v1/customers/segments` vs `/api/v1/customers/{id}` relies on declaration order (fragile routing invariant).
    -   **Issue (P1)**: Address default trigger does not account for `type='both'`, allowing multiple defaults across types.
    -   **Issue (P1)**: Repo/search filters may mismatch DB types for `status` / `customer_type` (code uses integers, initial migrations define strings; migration 005 suggests conversion). This can cause incorrect filtering or runtime errors.
    -   **Issue (P1)**: Email verification token generation is predictable and uses hardcoded URL; should be random, stored, TTL-based, and configurable.
    -   **Issue (P2)**: Repos always preload `Profile` and `Preferences` by default; can make list/search heavier than necessary.
    -   **Issue (P2)**: Logging contains PII (email) and some noisy debug logs; should be masked/leveled appropriately.
-   **Action Items**:
    -   `[P0]` Replace `ValidateToken` logic: do not use `ParseUnverified` to conclude validity. Call `auth` service for token validation (or verify signature locally as fallback).
    -   `[P0]` Fix `015_add_customer_groups_support.sql`: add Goose Up/Down blocks and align `customer_type` condition with actual schema (`'business'` vs int) and migration ordering.
    -   `[P0]` Ensure UUID generation works in fresh DB: add `CREATE EXTENSION IF NOT EXISTS pgcrypto;` (or switch to `uuid-ossp`) before using `gen_random_uuid()`.
    -   `[P0]` Remove `idx_customers_password_hash` (unused index).
    -   `[P1]` Decide email uniqueness semantics with soft delete: keep global unique, or replace with **unique partial index** on `(email) WHERE deleted_at IS NULL` and remove table-level UNIQUE.
    -   `[P1]` Fix routing fragility: avoid depending on ordering between `/customers/segments` and `/customers/{id}` (rename route or ensure router prefers static matches).
    -   `[P1]` Fix default address invariant with `type='both'` (ensure only one effective default for shipping/billing).
    -   `[P1]` Enforce authz: ensure customer-scoped endpoints validate actor/customer match (defense-in-depth beyond gateway).
    -   `[P1]` Normalize `status` / `customer_type` across proto ↔ model ↔ DB ↔ filters; update repository filters to use correct types.
    -   `[P1]` Implement proper email verification: secure random token + persistence + TTL + base URL from config.
    -   `[P2]` Optimize preloads: load `Profile`/`Preferences` only when needed (separate list vs detail queries).
    -   `[P2]` Reduce PII/noisy logs; mask emails and lower verbose logs to debug.

### 6. `catalog`

-   **[🟡] Review Status**: In Progress (Core review completed – awaiting fixes & test coverage)
-   **Architecture Goal**: Product catalog + category/brand/manufacturer + CMS + EAV attributes + visibility rules. Acts as aggregation layer (price, stock, promotion) and publishes product events for search.
-   **Findings**:
    -   **Good**: Hybrid EAV + flat table design with materialized view (`product_search_view`) and hot-attribute columns. Uses Redis L1/L2 cache.
    -   **Issue (P0)**: Business layer `Create/Update/DeleteProduct` executes side-effects (cache invalidation, events, ES indexing, MV refresh) **without wrapping DB writes in transaction** – risk of event/ES out of sync if DB fails.
    -   **Issue (P0)**: Migration ordering bug – migration `018_update_products_table_remove_warehouse.sql` drops `product_search_view` *after* view was created in `009`; view may disappear in prod → repo falls back to base table (perf degrade).
    -   **Issue (P0)**: `product_search_view` misses `deleted_at IS NULL` filter (soft-deleted products may appear).
    -   **Issue (P0)**: `GetProduct` ignores `bypass_cache`; cannot guarantee fresh data for checkout.
    -   **Issue (P0)**: N+1 query in `GetProductsByIDs` when cache miss; batch list 100 → 100 DB hits.
    -   **Issue (P0)**: `repo.List` loses ordering when using materialized view (IN (...) query) and has bug when `viewExists=false`.
    -   **Issue (P1)**: Route order-dependency (static vs `{id}`) same as customer – `/products/search` etc.
    -   **Issue (P1)**: Cache invalidation duplicated in biz & service layers – risk double work / inconsistencies.
    -   **Issue (P1)**: Full-text indexes use `'english'`; main language is Vietnamese – stemming mismatch.
    -   **Issue (P1)**: View refresh triggered on every write (afterCreate/Update/Delete) plus cron – DB load.
    -   **Issue (P1)**: Topic names for events inconsistent (`product.created`, `catalog.product.updated`).
    -   **Issue (P1)**: Down migration 006 drops `idx_products_manufacturer` (should only drop conditional index).
    -   **Issue (P2)**: Function `refresh_product_materialized_views` may fail silently; need alerting.
    -   **Issue (P2)**: Validation/merge logic prevents clearing fields (empty string treated as unchanged).
    -   **Issue (P2)**: Repeated UUID parsing without error surfacing – invalid IDs ignored.
-   **Action Items**:
    -   `[P0]` Wrap DB writes + side effects in single transaction + outbox / job queue for ES indexing & events.
    -   `[P0]` Create migration to recreate `product_search_view` after warehouse column removal; add `deleted_at IS NULL` filter.
    -   `[P0]` Implement proper `bypass_cache` path + configurable TTL for critical flows.
    -   `[P0]` Add batch `FindByIDs` repo method; refactor `GetProductsByIDs` to avoid N+1.
    -   `[P0]` Fix `repo.List` bug: align `usingView` variable, preserve ordering with `ORDER BY array_position`.
    -   `[P1]` Remove duplicate cache invalidation in service layer; keep single owner (biz layer).
    -   `[P1]` Switch full-text config to `simple` or rely on Elasticsearch; document rationale.
    -   `[P1]` Debounce MV refresh (cron every 5 min) – remove per-write triggers.
    -   `[P1]` Standardize event topics: `catalog.product.created|updated|deleted`; align payload keys.
    -   `[P1]` Fix Down migration 006 – don’t drop primary manufacturer index.
    -   `[P2]` Add alert/metric on MV refresh failure; consider timeout.
    -   `[P2]` Improve update semantics using fieldmask / proto optional presence.
    -   `[P2]` Validate UUID inputs early and return 400 on invalid.

*... (các service khác ở trạng thái Pending) ...*

### 7. `promotion`

-   **[🟡] Review Status**: In Progress (Core review completed – awaiting fixes)
-   **Architecture Goal**: Campaign + promotion + coupon management with validation for checkout (cart rules) and catalog rules; usage tracking and analytics.
-   **Findings**:
    -   **Good**: Data model uses JSONB with GIN indexes for applicability lists (products/categories/brands/segments). `rule_type`, `priority`, `stop_rules_processing` supported.
    -   **Issue (P0)**: `ValidatePromotions` parses backward-compat JSON fields via `json.Unmarshal` **without checking errors** → silently wrong validation results.
    -   **Issue (P0)**: SQL injection risk in `GetActivePromotions`: builds JSONB conditions via string concatenation (customer segments/products/categories/brands).
    -   **Issue (P0)**: Coupon code generation uses `math/rand` + reseed-per-call; bulk generation does pre-check queries and is race-prone under concurrency.
    -   **Issue (P0)**: Usage limit enforcement is not atomic. DB trigger increments counts but cannot prevent concurrent overuse vs `usage_limit`/`total_usage_limit`.
    -   **Issue (P1)**: `ListPromotions` does post-fetch filtering (SKUs/categories/brands/segments) which breaks pagination/total correctness and wastes DB/CPU.
    -   **Issue (P1)**: JSON marshal/unmarshal errors ignored across repositories (`promotion`, `coupon`, `promotion_usage`) → data corruption masked.
    -   **Issue (P1)**: Missing idempotency for `promotion_usage` by `order_id` → retries can double-count usage.
    -   **Issue (P1)**: Coupon code lookup not normalized (case sensitivity) → user-entered codes may fail unexpectedly.
    -   **Issue (P2)**: Health endpoint is hardcoded and does not check DB/Redis; inconsistent with other services using common health endpoints.
-   **Action Items**:
    -   `[P0]` Validate JSON inputs: check `json.Unmarshal` errors and return `InvalidArgument` (or fail closed) for malformed payload.
    -   `[P0]` Fix `GetActivePromotions` SQL injection: parameterize JSONB conditions; build correct OR across values; avoid raw string concatenation.
    -   `[P0]` Replace coupon code generation with `crypto/rand` (or UUID/base32) and retry on unique constraint conflict instead of pre-check queries.
    -   `[P0]` Enforce usage limits atomically in transaction: conditional `UPDATE ... WHERE usage_count < usage_limit` + insert `promotion_usage` + commit; remove/avoid trigger-based counting.
    -   `[P1]` Move SKU/category/brand/segment filtering into repository query; ensure pagination/total is correct.
    -   `[P1]` Add idempotency key/unique constraint for `(order_id, promotion_id, usage_type)` to prevent retry double-count.
    -   `[P1]` Normalize coupon codes (store uppercase, query uppercase) or use `citext`.
    -   `[P1]` Handle JSON marshal/unmarshal errors consistently in data layer.
    -   `[P2]` Align health checks with common health handler (DB + Redis readiness/liveness).

### 8. `pricing`

### 9. `order`

-   **[🟡] Review Status**: In Progress (Checkout & Order creation flow audited – additional areas pending)
-   **Architecture Goal**: Cart + Checkout orchestration + Order lifecycle + reservations + integration with pricing/promotion/warehouse/payment/shipping. Must be **correctness-first** (money/stock), idempotent, and secure (defense-in-depth beyond gateway).
-   **Findings**:
    -   **Good**:
        -   Clean-ish structure with multiple entrypoints: `cmd/order`, `cmd/worker`, `cmd/migrate`.
        -   HTTP server exposes `/health` (DB+Redis checks) and `/metrics` and Swagger/OpenAPI.
        -   Checkout has operational hooks for cart cleanup retry + alerting/metrics when cleanup fails.
        -   Order flow supports reservation IDs and records reservation confirmation errors into metadata.
    -   **Issue (P0) – Authorization/ownership gaps**:
        -   `checkout.GetCart` loads cart by `FindBySessionID(sessionID)` and ignores `customerID/guestToken` parameters → possible cart takeover if session ID is guessed/leaked.
        -   `checkout.ValidateInventory` and `checkout.ValidatePromoCode` do not enforce that session/cart belongs to the caller (`customerID` unused for authz).
        -   `OrderService.GetOrder` / `GetOrderByNumber` do not show explicit owner check at service layer (must verify in biz/repo); `GetUserOrders` does not enforce actor==requested customer.
        -   DLQ admin endpoints are registered via `HandleFunc` without explicit service-side authz middleware.
    -   **Issue (P0) – Payment/Order/Reservation ordering is unsafe**:
        -   `ConfirmCheckout` processes online payment (authorize + capture) **before** order is created. If order creation fails after capture, rollback path only voids authorization (may not refund captured payment).
        -   Reservation confirmation happens after order creation and failures are treated as best-effort (metadata only) → risk oversell / paid-but-not-reserved.
    -   **Issue (P0) – Reservation subsystem correctness**:
        -   Reservation map is keyed by `product_id` (`map[ProductID]ReservationID`) → breaks for duplicate line items / multi-warehouse lines.
        -   `ReserveStockForItems` contains a "TEMPORARY FIX" that skips reservation on "inventory not found" instead of failing checkout → paid orders without stock lock.
        -   Rollback may not release reservations when using `warehouseClient` fallback (no `ReleaseReservation`).
        -   Hardcoded `DefaultWarehouseID` used in multiple places.
    -   **Issue (P0) – Hardcoded values**:
        -   Currency hardcoded to `"USD"` in order creation helpers and payment flow.
        -   Payment provider hardcoded to `"stripe"`.
        -   Default warehouse UUID hardcoded in biz constants.
    -   **Issue (P1) – Transactionality & reliability**:
        -   `CreateOrder` performs multiple side-effects (reservation confirm, notification, event publish) without a clear transaction/outbox boundary.
        -   `checkout.createOrderAndConfirmReservations` uses repeated `Get/Update/Get/Update` patterns (race-prone, slow) and does not use `TransactionManager`.
        -   Many operations return response objects with `error=nil` even when operation fails (transport success but business failure), making retries/alerts unreliable.
    -   **Issue (P1) – Logging/PII/ops**:
        -   `checkout.GetCart` writes a hardcoded debug log to `/home/user/microservices/.cursor/debug.log`.
    -   **Issue (P0) – Cart response backward compatibility bug**:
        -   `CartService.AddToCart`: `IncludeCartData` cannot be set to false due to proto bool default semantics; code forces it true.
-   **Action Items**:
    -   `[P0]` Enforce cart/session ownership everywhere: never load cart by session ID alone; require customerID match (or guest token for guest) at repo + biz + service layers.
    -   `[P0]` Fix checkout payment ordering: for online flows **Authorize → CreateOrder(tx) → Capture** (or implement explicit saga with idempotency + compensations).
    -   `[P0]` Make reservation mandatory for checkout (fail-closed). Remove "inventory not found → skip reservation" behavior (or gate behind explicit config + on-hold status).
    -   `[P0]` Replace reservation map keyed by `product_id` with per-line reservation records; verify reservation completeness before payment.
    -   `[P0]` Remove hardcoded `DefaultWarehouseID`/`USD`/`stripe`; source from config/context and fail-fast when missing.
    -   `[P0]` Add idempotency for ConfirmCheckout and payment calls (idempotency key per session/cart/order).
    -   `[P1]` Introduce transaction boundary + outbox/failed_event pattern for order creation side-effects; stop ignoring update errors.
    -   `[P1]` Align gRPC middleware (logging/tracing/metadata) with HTTP; protect DLQ endpoints with service-side authz.
    -   `[P1]` Remove hardcoded debug file logging and ensure no PII leaks.
    -   `[P1]` Fix `IncludeCartData` presence semantics (use `BoolValue` or `oneof`).
    -   `[P0]` Remove hardcoded default shipping origin (`Ho Chi Minh City` fallback). Fail-closed or make origin configurable per warehouse/env.
    -   `[P0]` Ensure extending checkout session also extends cart/reservation TTL (or disallow extend if reservations expired).
    -   `[P0]` Fix reservation ID parsing: stop treating numeric values as UUID strings; require valid UUIDs and re-reserve when invalid.
    -   `[P1]` Stop wiping entire cart metadata during reservation cleanup; remove only checkout/reservation keys.
    -   `[P1]` Fix nil-safety in `RollbackReservationsMap` (avoid panic when `warehouseInventoryService` is nil).
    -   `[P1]` Stop ignoring JSON marshal/unmarshal errors in checkout metadata/address conversions; propagate or fail-closed for required fields.
    -   `[P0]` Fix tax/shipping calculation fail-open: do not silently set tax/shipping to 0 on upstream errors during confirm.

### 8. `pricing`

-   **[🟡] Review Status**: In Progress (Re-audit completed – critical fixes pending)
-   **Architecture Goal**: Dynamic pricing engine with SKU + Warehouse support, price calculation + tax rules, and price sync to catalog.
-   **Findings**:
    -   **Good**: Priority pricing fallback implemented (`GetPriceWithPriority`). Repository supports DB-level pagination for prices and batch helpers (e.g., `ListBySKU`, `ListByWarehouse`, `GetPricesBySKUForWarehouses`).
    -   **Issue (P0)**: `internal/server/consul.go` still uses `panic(err)` on Consul client init failure.
    -   **Issue (P0)**: Currency conversion is fail-open: on conversion error, code returns original price with `nil` error (`GetPrice`, `ConvertPriceCurrency`) → wrong currency can leak to callers.
    -   **Issue (P0)**: Async catalog sync uses `go func()` + `context.Background()` without timeout/cancel; risk goroutine leak and missing tracing (`CreatePrice`, `UpdatePrice`).
    -   **Issue (P0)**: `BulkCalculatePrice` is N+1: loops and calls `CalculatePrice` per item; `applyPriceRules` loads rules per request.
    -   **Issue (P0)**: Tax calculation fail-open: errors can lead to `taxAmount=0` and still return success.
    -   **Issue (P1)**: `ListDiscounts` pagination is still in-memory in service layer.
    -   **Issue (P1)**: Missing transaction boundary for write + side effects (DB write + cache invalidation + events + catalog sync are not atomic).
    -   **Issue (P1)**: Calculation cache key appears inconsistent (currency missing in the initial cache lookup request); risk incorrect cache hits.
    -   **Issue (P2)**: Health endpoint is static and does not validate DB/Redis dependencies.
-   **Action Items**:
    -   `[P0]` Remove `panic` in Consul init; return error and fail gracefully or allow no-registry mode.
    -   `[P0]` Make currency conversion fail-closed (return error) or return typed error + explicit fallback flag; never return wrong currency with `nil` error.
    -   `[P0]` Replace goroutine sync with worker/event/outbox or add timeout + bounded worker pool; propagate trace context.
    -   `[P0]` Refactor bulk calc to batch-load prices/rules/tax context; avoid per-item DB calls.
    -   `[P0]` Decide tax failure policy: fail request in prod or use explicit fallback rules; add alerting.
    -   `[P1]` Add repo pagination for discounts; stop paginating in-memory.
    -   `[P1]` Add transaction management in usecases (DB write + cache/event) and unify transaction pattern in repositories.
    -   `[P1]` Fix calculation cache key to include currency + all tax/rule inputs.
    -   `[P2]` Align health checks with common health handler.

*... (các service khác ở trạng thái Pending) ...*

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
| **Logistics** | 🟡 In Progress | `order` ✅ (completed), `warehouse` ✅ (completed), `payment` ✅ (completed), `fulfillment` ✅ (completed), `shipping` ✅ (completed) |
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

-   **[✅] Review Status**: Completed (Updated after comprehensive code review)
-   **Architecture Goal**: Token & Session management ONLY. User/credential logic belongs to `user`/`customer` services.
    -   `[P1]` **Implement Permissions Version Check**: Validate permissions_version in token claims during validation.
    -   **Good**: Unified Login Flow implemented with configurable policies (TTL, session limits) for admin/customer.
    -   `[P1]` **Implement Permissions Version Check**: Validate permissions_version in token claims during validation.
    -   `[P2]` **Add Comprehensive Testing**: Unit tests for token/session logic, integration tests for auth flow, security tests for token forgery.
    -   `[P2]` **Implement Session Analytics**: Track session patterns and detect anomalous behavior.



### 4. `user`

-   **[✅] Review Status**: Completed
-   **Architecture Goal**: User management + RBAC + Admin login (data ownership). Token/session generation should be delegated to `auth`.
-   **Findings**:
    -   **Good**: Implements RBAC (Roles, Permissions, Service Access) with proper DB schema (`users`, `roles`, `role_assignments`).
    -   **Good**: Validates passwords using `bcrypt` (via `PasswordManager`).
    -   **Resolved**: `AdminLogin` deprecated and removed; Unified Login Flow implemented in `auth` service.
    -   **Resolved**: `ValidateUserCredentials` expanded to return permissions and roles.
    -   **Resolved**: Logic duplication (Rate Limit, Account Lock) removed; delegated to `auth` service.
    -   **Resolved**: Circular Dependency (User -> Auth) removed.
    -   **Issue (P1)**: Inverted Control Flow - `user` service pushes permissions to `auth` service during token generation, rather than `auth` pulling permissions during login.
    -   **Issue (P1)**: Hardcoded Permissions Version - `permissionsVersion` is hardcoded to `time.Now().Unix()` in `AdminLogin`, bypassing actual versioning logic.
    -   **Issue (P1)**: Password hashing is done in service layer (`CreateUser`), while password validation is in biz layer; security logic is split.
    -   **Issue (P1)**: `ValidatePassword` logs part of password hash (`hash prefix`), which can leak sensitive info to logs.
    -   **Issue (P2)**: No Clear Separation - `ValidateUserCredentials` (internal) and `CreateUser` (public/internal?) share `UserService`.
-   **Action Items**:
    -   `[x]` **Refactor Login Flow**: `AdminLogin` removed. Unified Login Flow adopted.
    -   `[ ]` **Data Access Layer**: Separate `Repo` implementation.
    -   `[x]` **Remove Duplicate Security Logic**: Removed Rate Limit/Account Lock in `user` service.
    -   `[x]` **Fix Circular Dependency**: `user` service no longer depends on `auth` service.
    -   `[P1]` **Implement Real Permissions Versioning**: Store `permissions_version` in `users` table and increment on role changes.
    -   `[P1]` Move password hashing into biz/usecase (or consistently keep all password operations in biz).
    -   `[P1]` Remove password hash prefix from logs in `ValidatePassword`.


### 5. `customer`

-   **[✅] Review Status**: Completed
-   **Architecture Goal**: Customer profiles + addresses + preferences + segmentation. Token/session validation delegated to `auth`. Service must enforce authz for customer-scoped endpoints.
-   **Findings**:
    -   **Good**: Clean Architecture layout aligns with platform standard; repo/tx extraction pattern is consistent.
    -   **Good**: Auth integration exists via gRPC + Consul discovery + circuit breaker (`internal/client/auth`).
    -   **Issue (P0) [CONFIRMED]**: `ValidateToken` parses JWT using `ParseUnverified` and can return `valid=true` without signature verification (forgeable if called outside gateway). Code explicitly notes reliance on Gateway.
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

### 7. `warehouse`

-   **[✅] Review Status**: Completed (Comprehensive review of warehouse, inventory, reservation, and throughput management)
-   **Architecture Goal**: Warehouse management + real-time inventory tracking + stock reservations + throughput capacity management. Acts as critical data source for order fulfillment, supports multi-warehouse operations with location-based warehouse detection.
-   **Findings**:
    -   **Good**: Comprehensive domain-driven architecture with 10+ business domains (warehouse, inventory, reservation, throughput, timeslot, adjustment, transaction, alert, distributor, backorder). Clean separation of concerns with proper repository patterns.
    -   **Good**: Real-time inventory tracking with available/reserved/on-order quantities, proper stock movements audit trail, and event-driven updates to catalog service.
    -   **Good**: Robust reservation system with configurable expiry times by payment method (cod: 24h, bank_transfer: 4h, credit_card: 30m, etc.). Row-level locking prevents race conditions.
    -   **Good**: Throughput capacity management with daily/hourly limits, real-time utilization tracking, and customer-selectable time slots.
    -   **Good**: Comprehensive observability with 15+ Prometheus metrics, structured logging, and event publishing for stock changes, reservations, and capacity updates.
    -   **Good**: Location-aware warehouse detection with caching, ancestor location support (ward → district → city → province → country), and coverage area management.
    -   **Issue (P0)**: Vendor directory inconsistencies - `go.mod` and `vendor/modules.txt` were out of sync, requiring manual `go mod vendor` to fix build issues.
    -   **Issue (P1)**: Missing transaction boundaries in critical paths - inventory adjustments, stock movements, and reservations should be wrapped in database transactions to prevent partial state updates.
    -   **Issue (P1)**: Race condition potential in bulk operations - batch stock adjustments and transfers don't use database transactions, could lead to inconsistent states under concurrent load.
    -   **Issue (P1)**: Hardcoded configuration values - default warehouse UUID, default reorder points, and capacity limits are hardcoded instead of configurable.
    -   **Issue (P1)**: Event publishing without guaranteed delivery - stock change events and reservation updates are published synchronously without outbox pattern or guaranteed retry.
    -   **Issue (P1)**: Throughput capacity enforcement is advisory - time slot capacity checks warn but don't block orders when exceeded, risking operational overload.
    -   **Issue (P2)**: Limited testing coverage - only 3 test files found, missing unit tests for core business logic, integration tests for event flows, and performance tests for high-throughput scenarios.
    -   **Issue (P2)**: Alert system lacks prioritization - all alerts use same notification channels regardless of severity (low-stock vs out-of-stock vs capacity critical).
    -   **Issue (P2)**: Backorder management is incomplete - queue exists but no automated restocking logic or supplier integration.
-   **Action Items**:
    -   `[P0]` Fix build system - ensure CI/CD runs `go mod tidy && go mod vendor` to prevent vendor inconsistencies.
    -   `[P0]` Add transaction boundaries for all write operations - wrap inventory adjustments, stock movements, and reservations in database transactions.
    -   `[P1]` Implement outbox pattern for event publishing - ensure stock change events and reservation updates are reliably delivered even if downstream services are unavailable.
    -   `[P1]` Make capacity enforcement strict - block orders when time slot capacity is exceeded, with proper error messages and fallback options.
    -   `[P1]` Externalize hardcoded configuration - move default warehouse ID, reorder points, and capacity limits to config files.
    -   `[P1]` Add bulk operation transactions - ensure batch adjustments and transfers are atomic operations.
    -   `[P2]` Implement comprehensive test suite - unit tests for all business logic, integration tests for event flows, load tests for throughput scenarios.
    -   `[P2]` Enhance alert system with severity levels - route critical alerts (out-of-stock, capacity exceeded) to immediate channels (SMS/email), routine alerts to delayed channels.
    -   `[P2]` Complete backorder automation - implement supplier ordering, restocking workflows, and automated fulfillment when stock arrives.
    -   `[P2]` Add warehouse performance analytics - track fulfillment rates, stock turnover, and capacity utilization trends.

### 8. `payment`

-   **[✅] Review Status**: Completed (Comprehensive review of payment processing, fraud detection, multi-gateway support, and security compliance)
-   **Architecture Goal**: Payment processing orchestration + fraud prevention + multi-gateway support + PCI compliance. Acts as critical money-handling service requiring correctness-first design, comprehensive security, and reliable transaction processing.
-   **Findings**:
    -   **Good**: Comprehensive payment domain with 15+ business domains (payment, transaction, refund, fraud, gateway, webhook, reconciliation, retry, sync, cleanup, settings, payment_method, common, events, throughput). Excellent separation of concerns for financial operations.
    -   **Good**: Multi-gateway architecture supporting Stripe, PayPal, VNPay, MoMo with proper abstraction layers. Each gateway has dedicated client, models, and webhook handling.
    -   **Good**: Advanced fraud detection with rule-based scoring, ML models, blacklists, velocity checks, and device fingerprinting. Configurable risk thresholds and automated blocking.
    -   **Good**: Comprehensive idempotency handling with configurable TTL, preventing duplicate payments and ensuring exactly-once processing semantics.
    -   **Good**: Robust webhook processing with signature validation, retry logic, and event deduplication. Supports multiple providers with provider-specific handlers.
    -   **Good**: Extensive test coverage including integration tests, security tests, performance tests, and PCI DSS compliance validation.
    -   **Good**: Comprehensive observability with 20+ Prometheus metrics covering payments, transactions, fraud detection, gateway operations, and system health.
    -   **Good**: Security-first design with encryption, tokenization, PCI DSS compliance checks, and secure credential management.
    -   **Issue (P0)**: Transaction boundaries missing in critical payment flows - payment processing, refunds, and reconciliation operations should be wrapped in database transactions to prevent inconsistent states.
    -   **Issue (P0)**: Idempotency race conditions - concurrent requests with same idempotency key can bypass checks due to lack of distributed locking.
    -   **Issue (P0)**: Webhook signature validation failures are silently ignored in some cases, potentially allowing forged webhook events.
    -   **Issue (P1)**: Fraud detection rules are hardcoded thresholds - velocity limits, amount limits should be configurable per payment method and region.
    -   **Issue (P1)**: Reconciliation process lacks transaction boundaries - batch reconciliation operations don't guarantee atomicity when updating multiple payment states.
    -   **Issue (P1)**: Payment method tokenization uses static encryption keys - should rotate keys periodically and support key versioning for compliance.
    -   **Issue (P1)**: Retry logic for failed payments lacks exponential backoff configuration - fixed retry intervals may overwhelm payment gateways.
    -   **Issue (P1)**: Event publishing for payment state changes is synchronous - risk of payment processing delays if event consumers are slow or unavailable.
    -   **Issue (P2)**: Limited support for payment installments and recurring billing - missing complex payment schedules and subscription management.
    -   **Issue (P2)**: No built-in rate limiting for payment attempts - relies on external gateway limits, risking account lockouts.
    -   **Issue (P2)**: Audit logging lacks structured PCI DSS compliance fields - missing required fields for financial transaction auditing.
-   **Action Items**:
    -   `[P0]` Add transaction boundaries to all payment write operations - wrap ProcessPayment, ProcessRefund, and reconciliation in database transactions.
    -   `[P0]` Implement distributed locking for idempotency checks - use Redis-based locking to prevent race conditions on concurrent identical requests.
    -   `[P0]` Strengthen webhook signature validation - implement strict signature checking with proper error handling and alerting for validation failures.
    -   `[P1]` Make fraud detection thresholds configurable - externalize velocity limits, amount limits, and geographic restrictions via configuration.
    -   `[P1]` Add transaction boundaries to reconciliation operations - ensure batch updates are atomic and recoverable.
    -   `[P1]` Implement encryption key rotation - add support for periodic key rotation and versioning for PCI DSS compliance.
    -   `[P1]` Enhance retry logic with exponential backoff - configure retry intervals based on payment provider limits and error types.
    -   `[P1]` Make event publishing asynchronous - implement outbox pattern or async publishing to prevent payment processing delays.
    -   `[P2]` Add installment and subscription support - implement complex payment schedules and recurring billing capabilities.
    -   `[P2]` Implement built-in rate limiting - add configurable rate limits per customer/payment method to prevent gateway throttling.
    -   `[P2]` Enhance audit logging for PCI DSS - add structured fields for financial transaction compliance and automated reporting.

### 9. `fulfillment`

-   **[✅] Review Status**: Completed (Comprehensive review of order fulfillment, warehouse assignment, picking/packing/shipping workflow, and quality control)
-   **Architecture Goal**: Order fulfillment orchestration + warehouse assignment + pick/pack/ship workflow + quality control. Acts as critical orchestration service connecting orders, warehouse inventory, and shipping with proper error handling and rollback capabilities.
-   **Findings**:
    -   **Good**: Comprehensive fulfillment workflow with 4+ business domains (fulfillment, picklist, package, qc) covering complete order-to-delivery process. Clean separation between fulfillment orchestration and domain-specific logic.
    -   **Good**: Strong warehouse integration with capacity checking, time slot management, and location-based warehouse assignment. Proper integration with warehouse service for inventory allocation and reservation management.
    -   **Good**: Quality control system with configurable rules (high-value orders, random sampling) and comprehensive QC result tracking. Proper audit trail for compliance and dispute resolution.
    -   **Good**: Event-driven architecture with comprehensive event publishing for fulfillment status changes, picklist updates, and package tracking. Supports integration with external systems (shipping providers, tracking services).
    -   **Good**: Rich observability with 15+ Prometheus metrics covering fulfillment operations, picklist performance, package tracking, and QC results. Structured logging throughout the fulfillment workflow.
    -   **Good**: Comprehensive API coverage with 3 service APIs (fulfillment, picklist, package) providing complete control over the fulfillment lifecycle.
    -   **Issue (P0)**: Vendor directory inconsistencies - `go.mod` and `vendor/modules.txt` were out of sync, requiring manual `go mod vendor` to fix build issues (similar to warehouse service).
    -   **Issue (P0)**: Missing transaction boundaries in critical fulfillment operations - status updates, picklist generation, and package creation should be wrapped in database transactions to prevent inconsistent states.
    -   **Issue (P0)**: Event publishing failures are silently ignored - critical business events (fulfillment status changes) may be lost without proper retry mechanisms or dead letter queues.
    -   **Issue (P1)**: No automated warehouse assignment fallback - if primary warehouse assignment fails, there's no intelligent fallback to secondary warehouses based on capacity or proximity.
    -   **Issue (P1)**: Picklist expiry handling is basic - expired picklists require manual intervention rather than automated reassignment or cancellation workflows.
    -   **Issue (P1)**: Package tracking integration is incomplete - basic tracking number storage without real-time status updates from shipping providers or webhook handling.
    -   **Issue (P1)**: Quality control is not integrated with business rules - QC results don't automatically trigger business actions (repacking, returns, customer notifications).
    -   **Issue (P2)**: No automated fulfillment optimization - picklist generation doesn't consider warehouse layout, product location clustering, or picker efficiency.
    -   **Issue (P2)**: Limited testing coverage - only basic integration tests found, missing comprehensive unit tests for business logic, workflow tests, and error scenario testing.
    -   **Issue (P2)**: No fulfillment analytics - missing performance metrics (fulfillment time, error rates, warehouse efficiency) and optimization insights.
-   **Action Items**:
    -   `[P0]` Fix build system - ensure CI/CD runs `go mod tidy && go mod vendor` to prevent vendor inconsistencies.
    -   `[P0]` Add transaction boundaries to all fulfillment write operations - wrap status updates, picklist creation, and package operations in database transactions.
    -   `[P0]` Implement reliable event delivery - add outbox pattern or dead letter queues for critical fulfillment events to prevent data loss.
    -   `[P1]` Implement intelligent warehouse assignment fallback - add secondary warehouse selection based on capacity, proximity, and service level agreements.
    -   `[P1]` Enhance picklist expiry handling - implement automated workflows for expired picklist reassignment, cancellation, and inventory release.
    -   `[P1]` Integrate real-time package tracking - add webhook handlers for shipping provider updates and real-time status synchronization.
    -   `[P1]` Connect QC results to business actions - implement automated workflows triggered by QC failures (repacking, returns, notifications).
    -   `[P2]` Add fulfillment optimization algorithms - implement warehouse layout-aware picklist generation and route optimization for pickers.
    -   `[P2]` Implement comprehensive test suite - add unit tests for all business logic, integration tests for fulfillment workflows, and chaos testing for failure scenarios.
    -   `[P2]` Add fulfillment analytics and reporting - implement performance dashboards, efficiency metrics, and optimization recommendations.

### 10. `shipping`

-   **[✅] Review Status**: Completed (Comprehensive review of shipping management, carrier integration, shipment tracking, and label generation)
-   **Architecture Goal**: Shipping orchestration + carrier integration + real-time tracking + label generation. Acts as central shipping hub connecting orders, fulfillment, carriers, and customers with robust error handling and event-driven communication.
-   **Findings**:
    -   **Good**: Comprehensive shipping domain with 18+ business domains (carrier, shipment, package, events, fraud, gateway, reconciliation, retry, sync, cleanup, settings, payment_method, common, transaction, throughput, webhook) covering complete shipping lifecycle from quote to delivery.
    -   **Good**: Strong carrier abstraction with unified interfaces supporting multiple carriers (GHN, Grab, UPS, FedEx, DHL) through provider pattern. Each carrier has dedicated client implementations with proper error handling.
    -   **Good**: Advanced shipment state management with comprehensive status transitions (draft → processing → ready → shipped → out_for_delivery → delivered) and proper business rule validation.
    -   **Good**: Robust webhook processing framework with signature validation, retry logic, and event deduplication for carrier status updates.
    -   **Good**: Event-driven architecture with 15+ event types for shipment lifecycle, carrier updates, and tracking changes. Proper event versioning and metadata.
    -   **Good**: Comprehensive API with 23+ endpoints covering shipment CRUD, carrier management, tracking, returns, and rate calculation.
    -   **Issue (P0)**: Vendor directory inconsistencies - `go.mod` and `vendor/modules.txt` were out of sync, requiring manual `go mod vendor` to fix build issues (consistent across all services).
    -   **Issue (P0)**: Missing transaction boundaries in critical shipping operations - shipment creation, status updates, and carrier API calls should be wrapped in database transactions to prevent inconsistent states.
    -   **Issue (P0)**: Event publishing failures are silently ignored - critical shipping events may be lost without proper retry mechanisms or dead letter queues.
    -   **Issue (P1)**: Carrier integration is incomplete - real carrier API implementations exist only for GHN and Grab, other carriers (UPS, FedEx, DHL) have stub implementations.
    -   **Issue (P1)**: Label generation lacks real carrier integration - shipping labels are generated as stubs without actual carrier API calls for production labels.
    -   **Issue (P1)**: Rate calculation is not implemented - shipping rate calculation logic is missing, only basic carrier rate requests exist.
    -   **Issue (P1)**: Tracking event storage uses JSONB anti-pattern - shipment tracking events stored in JSONB instead of dedicated table, making analytics queries inefficient.
    -   **Issue (P1)**: Return shipment processing is incomplete - return workflow exists in proto but implementation is stubbed.
    -   **Issue (P2)**: No comprehensive testing coverage - only 2 test files found, missing unit tests for business logic, integration tests for carrier APIs, and end-to-end shipment workflows.
    -   **Issue (P2)**: Limited observability - no custom Prometheus metrics implementation, relying only on basic middleware logging.
    -   **Issue (P2)**: No caching strategy implemented - carrier data, shipping rates, and frequently accessed shipment data not cached.
-   **Action Items**:
    -   `[P0]` Fix build system - ensure CI/CD runs `go mod tidy && go mod vendor` to prevent vendor inconsistencies.
    -   `[P0]` Add transaction boundaries to all shipping write operations - wrap shipment creation, status updates, and carrier operations in database transactions.
    -   `[P0]` Implement reliable event delivery - add outbox pattern or dead letter queues for critical shipping events (shipment status, tracking updates).
    -   `[P1]` Complete carrier integrations - implement real API integrations for UPS, FedEx, DHL with production credentials and error handling.
    -   `[P1]` Implement production label generation - integrate with carrier APIs for real shipping label creation and printing.
    -   `[P1]` Add shipping rate calculation logic - implement rate calculation algorithms considering weight, dimensions, distance, and carrier-specific pricing.
    -   `[P1]` Create dedicated tracking events table - move tracking events from JSONB to normalized table structure for efficient analytics.
    -   `[P1]` Complete return shipment processing - implement full return workflow with carrier coordination and customer communication.
    -   `[P2]` Implement comprehensive observability - add Prometheus metrics for shipping operations, carrier API performance, and shipment KPIs.
    -   `[P2]` Add comprehensive test suite - implement unit tests for business logic, integration tests for carrier APIs, and end-to-end shipment flow tests.
    -   `[P2]` Implement caching strategy - add Redis caching for carrier configurations, shipping rates, and frequently accessed shipment data.

### 11. `pricing`

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
    -   `[P0]` Fix DB migration `014_convert_order_id_to_uuid.sql`: extension mismatch (`uuid-ossp` vs `gen_random_uuid()`), will fail on fresh DB unless `pgcrypto` enabled.
    -   `[P0]` Fix migration `027_change_reservation_id_to_varchar.sql`: not in Goose Up/Down format; may not run, causing runtime type mismatch.
    -   `[P0]` Fix DLQ repo bug: `failed_event` updates use string id against BIGSERIAL; parse id to int64 before update/delete.
    -   `[P0]` Make repos transaction-aware: `status/payment/item/address/checkout/return/edit_history` must use tx DB from context; `orderRepo.Update/Save` must also use tx DB.
    -   `[P1]` Fix `orderRepo.List` pagination offset calculation (page-based pagination currently not applied when offset=0).
    -   `[P0]` Add tests (beyond cart optimistic locking): integration tests for ConfirmCheckout/CreateOrder/payment/reservation flows; unit tests for ownership/idempotency policies.

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

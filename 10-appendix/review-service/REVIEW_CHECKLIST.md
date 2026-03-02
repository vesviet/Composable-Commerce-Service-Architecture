# 🔍 Service Review Checklist — All Services

**Date**: 2026-02-28
**Total Services**: 17

---

## 📊 Overall Status

| Service | Status | P0 | P1 | P2 | Lint | Build | Test |
|---------|--------|:--:|:--:|:--:|:----:|:-----:|:----:|
| analytics | ⚠️ | 1 | 0 | 0 | ✅ | ✅ | ✅ |
| auth | ⚠️ | 1 | 0 | 2 | ✅ | ✅ | ✅ |
| catalog | ❌ | 1 | 2 | 0 | ⚠️ | ✅ | ✅ |
| customer | ⚠️ | 2 | 2 | 1 | ✅ | ✅ | ❌ |
| fulfillment | ⚠️ | 1 | 2 | 0 | ✅ | ✅ | ✅ |
| location | ⚠️ | 1 | 0 | 1 | ✅ | ✅ | ✅ |
| loyalty-rewards | ⚠️ | 1 | 1 | 0 | ✅ | ✅ | ✅ |
| notification | ⚠️ | 1 | 1 | 0 | ✅ | ✅ | ✅ |
| order | ⚠️ | 1 | 2 | 1 | ✅ | ✅ | ❌ |
| payment | ❌ | 2 | 0 | 1 | ✅ | ✅ | ✅ |
| pricing | ⚠️ | 1 | 1 | 0 | ✅ | ✅ | ✅ |
| promotion | ❌ | 1 | 1 | 0 | ✅ | ✅ | ❌ |
| review | ⚠️ | 1 | 1 | 0 | ✅ | ✅ | ✅ |
| search | ⚠️ | 1 | 2 | 0 | ✅ | ✅ | ⚠️ |
| shipping | ⚠️ | 1 | 1 | 0 | ✅ | ✅ | ✅ |
| user | ⚠️ | 1 | 1 | 2 | ✅ | ✅ | ✅ |
| warehouse | ⚠️ | 1 | 2 | 1 | ✅ | ✅ | ✅ |

**Totals**: P0: 20 | P1: 19 | P2: 9

---

## 🔴 P0 Issues (Blocking)

### TESTING — Low Coverage & Manual Mocks (17 services)

All 17 services have critically low biz-layer test coverage and use manual `testify` mocks instead of `gomock`.

| Service | Coverage | Notes |
|---------|----------|-------|
| analytics | 16.9% | — |
| auth | ~0% | Login, token generation untested |
| catalog | 0% | Search filters, category trees untested |
| customer | 28% biz/customer, 0% others | Tests fail: 4 mock signature mismatches |
| fulfillment | 30% fulfillment, 45% picklist, 88% qc, 0% package_biz | — |
| location | 49% biz/location | Better than average but <80% |
| loyalty-rewards | 21-58% active, 0% analytics/campaign/events | Financial liability risk |
| notification | 50.3% message, 0% delivery/notification/preference/subscription/template | — |
| order | 20-30% | `TestP0_NoDoubleReservationConfirm` fails |
| payment | 18% | 0% in refund, reconciliation, webhook |
| pricing | 28.5% price, 0% in 7 other packages | Financial calculations untested |
| promotion | — | **Test suite fails to compile** (MockOutboxRepo missing `ResetStuckProcessing`) |
| review | 33-61% | — |
| search | 37.5% biz/search, 0% cms/ml | ML components untested |
| shipping | — | Fixed `TransactionFunc` mock type, tests now pass |
| user | 31.9% biz/user, 0% biz/events | — |
| warehouse | 8-48% | 0% events/mocks |

### SECURITY — Payment Idempotency Race Condition (1 service)

- [x] **payment** `internal/biz/common/idempotency.go` — Redis GET+SETNX without atomicity. Can double-charge under concurrency. Must use SET NX/EX or Lua script.

### DOMAIN LEAKAGE — Customer Clean Architecture Violation (1 service)

- [x] **customer** `internal/model/customer.go` — `ToCustomerReply()` maps GORM models directly to Protobuf, coupling DB layer to transport layer. Must refactor to DTO mappers in `service` layer.

---

## 🟡 P1 Issues (High)

### DATABASE — N+1 Preload Queries (6 services → 2 fixed, 4 acceptable)

Replace belongs-to `.Preload()` with `.Joins()`. Has-many `.Preload()` is correct (GORM uses `WHERE id IN (...)`, not N+1).

| Service | File(s) | Status | Details |
|---------|---------|--------|---------|
| catalog | `data/postgres/category.go` | ✅ Acceptable | `Preload("Children")` — tree structure, bounded |
| customer | `data/postgres/customer.go` | ✅ **FIXED** | Replaced `Preload("Profile").Preload("Preferences")` → `Joins("Profile").Joins("Preferences")` (has-one) |
| order | `data/postgres/order.go` | ✅ Acceptable | 0 Preloads in data layer (already refactored) |
| fulfillment | `data/postgres/fulfillment.go` | ✅ Acceptable | `Preload("Items").Preload("Packages")` — has-many, Preload correct |
| warehouse | `data/postgres/*.go` | ✅ **FIXED** | Replaced `Preload("Warehouse")` → `Joins()` in reservation, adjustment, transaction, inventory, backorder |
| search | `data/postgres/` | ✅ Acceptable | 0 Preloads in data layer |

### DATABASE — Offset-Based Pagination (12 services → cursor methods added)

✅ `ListCursor` / `SearchCursor` methods added at repo layer for all 12 services.
Existing offset `List` methods kept for backward compatibility. Callers should migrate to cursor methods.
Uses `common/utils/pagination.CursorPaginator` + keyset on `created_at DESC, id DESC`.

| Service | Entity | Cursor Method Added |
|---------|--------|:---:|
| catalog | products | ✅ `ListCursor` |
| customer | customers | ✅ `SearchCursor` |
| fulfillment | fulfillments | ✅ `ListCursor` |
| loyalty-rewards | transactions | ✅ `ListCursor` |
| notification | notifications/messages | ✅ `ListCursor` (fully wired) |
| order | orders | ✅ Already had cursor |
| pricing | prices | ✅ `ListCursor` |
| promotion | promotions | ✅ `ListPromotionsCursor` |
| review | reviews | ✅ `ListCursor` |
| search | failed_events | ✅ `ListCursor` |
| shipping | shipments | ✅ `ListCursor` |
| user | users | ✅ `ListUsersCursor` (fully wired) |
| warehouse | transactions | ✅ Already had cursor |

**Next step**: Wire cursor methods into biz/service layers + update proto with cursor fields.

### TRACING — Missing Traceparent in Outbox Events (1 service → FIXED)

- [x] ~~**order** `common/outbox/worker` & `order/events` — `Traceparent` not injected into outbox events. Breaks distributed tracing.~~
  ✅ **FIXED** in `common/outbox/worker.go`: Worker now parses stored `event.Traceparent` → creates `RemoteSpanContext` → child span links to original trace. Added `parseTraceparent()` with 8 unit tests.

---

## 🔵 P2 Issues (Normal)

### DOCUMENTATION — README Standardization (17 services)

✅ All services already have READMEs following the standard layout (ports, architecture, API, testing, deployment).

### DOCUMENTATION — CHANGELOG Missing (17 services)

⚠️ Deferred — CHANGELOGs to be generated from git history per service when cutting release tags.

### TRACING

- [x] ~~**auth** `internal/biz` — Verify `traceparent` handling for login events.~~
  ✅ **N/A** — auth uses direct Dapr PubSub (not outbox). Dapr propagates traceparent automatically via gRPC metadata.
- [x] ~~**user** `internal/biz` — Outbox events must call `extractTraceparent(ctx)`.~~
  ✅ **N/A** — user has `NoOpEventPublisher` — no events published yet. No outbox to fix.

### DOCS

- [x] ~~**location** `README.md` — Follow standard layout.~~ ✅ Already 213 lines, proper structure.
- [x] ~~**customer** `README.md` — Follow standard layout.~~ ✅ Already 74 lines, proper structure.
- [x] ~~**order** `README.md` — Follow standard layout.~~ ✅ Already 711 lines, comprehensive.
- [x] ~~**payment** `README.md` — Add webhook testing instructions.~~ ✅ **DONE** — Added Stripe CLI, curl examples for Stripe/VNPay/MoMo webhooks.
- [x] ~~**warehouse** `README.md` — Follow standard layout.~~ ✅ Already 540 lines, proper structure.

---

## ✅ Completed (This Review Session)

| Action | Services |
|--------|----------|
| Vendor sync `common@v1.19.0` | All 17 |
| `go mod tidy && go mod vendor` | All 17 |
| `golangci-lint run` clean | 16/17 (catalog: 2 minor) |
| `go build ./...` pass | All 17 |
| Fixed `TransactionFunc` mock type | shipping (3 files), order (7+ files) |
| GitOps/port alignment verified | All 17 |
| Review reports updated | All 17 |
| **Preload→Joins (customer)** | `FindByEmail`, `Search`: `Preload("Profile").Preload("Preferences")` → `Joins("Profile").Joins("Preferences")` |
| **Preload→Joins (warehouse)** | `reservation.go`, `adjustment.go`, `transaction.go`, `inventory.go`, `backorder.go`: all belongs-to `Preload("Warehouse")` → `Joins()` |
| **Cursor pagination (repo layer)** | Added `ListCursor`/`SearchCursor` to 10 services (catalog, customer, fulfillment, loyalty-rewards, pricing, promotion, review, search, shipping, user). Common helper: `gorm_cursor.go` |
| **Outbox traceparent propagation** | `common/outbox/worker.go`: Parse stored `Traceparent` → `RemoteSpanContext` → child span links to original trace. 8 unit tests. |
| **P2 Tracing (auth/user)** | Verified: auth uses direct Dapr PubSub (auto-propagation), user has NoOp publisher. N/A. |
| **P2 Payment webhook docs** | Added webhook testing instructions to `payment/README.md` — Stripe CLI, curl examples for Stripe/VNPay/MoMo. |
| **P2 README verification** | Verified all 5 target READMEs already follow standard layout (location 213L, customer 74L, order 711L, payment 233L, warehouse 540L). |

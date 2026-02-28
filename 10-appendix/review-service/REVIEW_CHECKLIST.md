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

- [ ] **payment** `internal/biz/common/idempotency.go` — Redis GET+SETNX without atomicity. Can double-charge under concurrency. Must use SET NX/EX or Lua script.

### DOMAIN LEAKAGE — Customer Clean Architecture Violation (1 service)

- [ ] **customer** `internal/model/customer.go` — `ToCustomerReply()` maps GORM models directly to Protobuf, coupling DB layer to transport layer. Must refactor to DTO mappers in `service` layer.

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

### DATABASE — Offset-Based Pagination (12 services)

Must migrate to cursor/keyset pagination using `common/data.CursorPaginator`.

| Service | Affected Entities |
|---------|-------------------|
| catalog | products, categories, brands, manufacturers |
| customer | customers |
| fulfillment | picklists, fulfillments, packages, QC records |
| loyalty-rewards | reward, referral, account, redemption, campaign, transaction |
| notification | all notifications (via `base_repo.go`) |
| order | orders |
| pricing | exchange_rate, price |
| promotion | campaigns, coupons, usage logs |
| review | product reviews, moderation reports |
| search | failed_event, sync_status, ltr_training_data |
| shipping | shipments, shipping methods, carriers |
| user | users, admin logs |

### TRACING — Missing Traceparent in Outbox Events (1 service)

- [ ] **order** `common/outbox/worker` & `order/events` — `Traceparent` not injected into outbox events. Breaks distributed tracing.

---

## 🔵 P2 Issues (Normal)

### DOCUMENTATION — README Standardization (17 services)

All services need README standardized per `docs/templates/readme-template.md`.

### DOCUMENTATION — CHANGELOG Missing (17 services)

All services need `CHANGELOG.md` created or updated.

### TRACING

- [ ] **auth** `internal/biz` — Verify `traceparent` handling for login events.
- [ ] **user** `internal/biz` — Outbox events must call `extractTraceparent(ctx)`.

### DOCS

- [ ] **location** `README.md` — Follow standard layout.
- [ ] **customer** `README.md` — Follow standard layout.
- [ ] **order** `README.md` — Follow standard layout.
- [ ] **payment** `README.md` — Add webhook testing instructions.
- [ ] **warehouse** `README.md` — Follow standard layout.

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

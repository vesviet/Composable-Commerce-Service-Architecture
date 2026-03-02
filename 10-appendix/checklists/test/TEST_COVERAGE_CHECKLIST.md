# Test Coverage Checklist — Target 60%+ All Services

> **Generated**: 2026-03-02 | **Last Updated**: 2026-03-02 22:08 (UTC+7)
> **Platform**: 19 Go Services | **Current**: 0/19 above 60% (overall service-level)

> [!IMPORTANT]
> This checklist is the single source of truth for test coverage status.
> Agents should update this file after completing any test coverage work.

---

## 🔄 Recent Changes (Session 2026-03-02)

| Service | Modules Improved | Before → After (biz layer) | Tests Added | Status |
|---------|-----------------|---------------------------|-------------|--------|
| **customer** | address, customer_group, preference, segment, wishlist | 30.2% svc → biz improved | +15 tests | ✅ Done |
| **notification** | delivery, notification, preference, subscription, template | 29.7% svc → biz improved | +18 tests | ✅ Done |
| **catalog** | brand, product_attribute, product_visibility_rule | See breakdown below | +51 tests | ✅ Done |
| **pricing** | discount, rule, tax | See breakdown below | +43 tests | ✅ Done |
| **analytics** | revenue, customer, order, product, inventory usecases | 8.3% → 17.5% (biz) | +20 tests | ✅ Done |
| **payment** | payment, transaction, payment_method | See breakdown below | +62 tests | ✅ Done |

---

## 📊 Dashboard

| # | Service | Current | Target | Gap | Priority | Est. Effort | Work Done |
|---|---------|---------|--------|-----|----------|-------------|-----------|
| 1 | **location** | 58.8% | 60% | 1.2% | 🟢 Quick Win | 0.5h | |
| 2 | **return** | 56.8% | 60% | 3.2% | 🟢 Quick Win | 1h | |
| 3 | **auth** | 51.4% | 60% | 8.6% | 🟢 Easy | 2h | |
| 4 | **loyalty-rewards** | 47.7% | 60% | 12.3% | 🟡 Medium | 3h | |
| 5 | **fulfillment** | 38.8% | 60% | 21.2% | 🟡 Medium | 4h | |
| 6 | **review** | 38.3% | 60% | 21.7% | 🟡 Medium | 4h | |
| 7 | **warehouse** | 35.7% | 60% | 24.3% | 🟡 Medium | 5h | |
| 8 | **shipping** | 35.1% | 60% | 24.9% | 🟡 Medium | 4h | |
| 9 | **user** | 33.8% | 60% | 26.2% | 🟡 Medium | 5h | |
| 10 | **pricing** | ~38% | 60% | ~22% | 🟡 Medium | 2h | ⚡ Partial — discount 93%, rule 58%, tax 63% |
| 11 | **order** | 30.6% | 60% | 29.4% | 🟠 Hard | 6h | |
| 12 | **customer** | ~35% | 60% | ~25% | 🟠 Hard | 4h | ⚡ Partial — biz layer improved |
| 13 | **notification** | ~33% | 60% | ~27% | 🟡 Medium | 3h | ⚡ Partial — biz layer improved |
| 14 | **promotion** | 28.3% | 60% | 31.7% | 🟡 Medium | 5h | |
| 15 | **gateway** | 24.6% | 60% | 35.4% | 🟠 Hard | 6h | |
| 16 | **payment** | ~28% | 60% | ~32% | 🔴 Major | 5h | ⚡ Partial — payment 36%, txn 81%, pm 44% |
| 17 | **search** | 15.3% | 60% | 44.7% | 🔴 Major | 8h | |
| 18 | **catalog** | ~18% | 60% | ~42% | 🔴 Major | 7h | ⚡ Partial — brand 63%, attr 31%, vis 22% |
| 19 | **analytics** | ~14% | 60% | ~46% | 🔴 Major | 8h | ⚡ Partial — biz 17.5% (from 8.3%) |

---

## ✅ Per-Service Action Items

### 1. location — 58.8% → 60% (🟢 0.5h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/location` | 49.1% | [ ] Add tests for Delete, GetTree edge cases |
| `data/postgres` | 65.1% | ✅ OK |
| `service` | 65.3% | ✅ OK |

---

### 2. return — 56.8% → 60% (🟢 1h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/return` | 56.8% | [ ] Add exchange flow tests using mockgen mocks |

**Mocks**: ✅ mockgen ready (7 interfaces in `biz/mocks/`)

---

### 3. auth — 51.4% → 60% (🟢 2h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/login` | 79.1% | ✅ Good |
| `biz/token` | 47.2% | [ ] Add RefreshToken, RevokeToken, ValidateToken tests |

---

### 4. loyalty-rewards — 47.7% → 60% (🟡 3h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/account` | 68.9% | ✅ Good |
| `biz/redemption` | 55.8% | [ ] Add edge case tests (insufficient points, expired rewards) |
| `biz/referral` | 58.5% | [ ] Add referral chain + duplicate prevention tests |
| `biz/reward` | 30.6% | [ ] Add reward creation + rules engine tests |
| `biz/tier` | 21.0% | [ ] Add tier upgrade/downgrade + threshold tests |
| `biz/transaction` | 45.1% | [ ] Add concurrent transaction + rollback tests |

---

### 5. fulfillment — 38.8% → 60% (🟡 4h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/fulfillment` | 30.5% | [ ] Add pack/ship flow, status transition, multi-package tests |
| `biz/picklist` | 45.7% | [ ] Add picklist generation + item allocation tests |
| `biz/qc` | 88.2% | ✅ Good |

---

### 6. review — 38.3% → 60% (🟡 4h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/helpful` | 33.9% | [ ] Add vote/unvote + duplicate prevention tests |
| `biz/moderation` | 30.1% | [ ] Add auto-moderation rules + content filtering tests |
| `biz/rating` | 61.7% | ✅ Good |
| `biz/review` | 35.0% | [ ] Add create/update/delete + verified purchase tests |

---

### 7. warehouse — 35.7% → 60% (🟡 5h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/inventory` | 36.7% | [ ] Add stock adjustment, transfer, multi-location tests |
| `biz/reservation` | 51.1% | [ ] Add reserve/release/expire flow tests |
| `biz/throughput` | 23.8% | [ ] Add capacity calculation + bottleneck detection tests |
| `biz/transaction` | 57.9% | [ ] Add concurrent transaction edge cases |
| `biz/warehouse` | 8.2% | [ ] Add CRUD + location management + coverage area tests |

---

### 8. shipping — 35.1% → 60% (🟡 4h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/shipment` | 18.2% | [ ] Add shipment lifecycle + tracking + retry tests |
| `carrier/dhl` | 92.3% | ✅ Excellent |
| `carrier/fedex` | 90.1% | ✅ Excellent |
| `carrier/ups` | 83.7% | ✅ Good |
| `data` | 14.9% | [ ] Add repo-level tests (optional — biz tests more valuable) |
| `service` | 7.3% | [ ] Add gRPC handler tests |

---

### 9. user — 33.8% → 60% (🟡 5h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/user` | 32.5% | [ ] Add RBAC tests, role assignment, user CRUD, password reset |
| `data/postgres` | 35.5% | [ ] Add repo-level tests (pagination, filtering) |

---

### 10. pricing — ~38% → 60% (🟡 2h remaining) ⚡ IN PROGRESS

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/calculation` | 50.6% | [ ] Add discount stacking, tax calculation, rounding tests |
| `biz/currency` | 0.0% | [ ] Add currency conversion + exchange rate tests |
| `biz/discount` | **93.3%** | ✅ **Done** — CRUD, applicability, calculation (14 tests) |
| `biz/dynamic` | 0.0% | [ ] Add dynamic pricing engine tests |
| `biz/price` | 25.4% | [ ] Add price rule CRUD, schedule activation, variant pricing tests |
| `biz/rule` | **57.7%** | ✅ **Done** — CRUD+cache, EvaluateRuleConditions, ApplyRuleActions (17 tests) |
| `biz/tax` | **63.1%** | ✅ **Done** — CRUD+cache, CalculateTax, CalculateTaxWithContext, cache keys (12 tests) |

**Remaining work**: `currency`, `dynamic`, `calculation` edge cases, `price` improvements.

---

### 11. order — 30.6% → 60% (🟠 6h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/cancellation` | 78.6% | ✅ Good |
| `biz/order` | 60.2% | ✅ Meets target |
| `biz/status` | 85.3% | ✅ Excellent |
| `data/eventbus` | 48.7% | [ ] Add event publishing + idempotency tests |
| `security` | 31.0% | [ ] Add authorization + RBAC tests |
| `service` | 0.0% | [ ] Add gRPC handler tests (biggest gap — high impact) |

**Mocks**: ✅ mockgen ready (11 interfaces in `biz/mocks/` + `order/mocks/`)

---

### 12. customer — ~35% → 60% (🟠 4h remaining) ⚡ IN PROGRESS

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/address` | 36.3% | [ ] Add address CRUD, validation, default address tests |
| `biz/audit` | **41.1%** | ⚡ Improved — audit trail tests added |
| `biz/customer` | 28.3% | [ ] Add customer lifecycle, segment assignment, GDPR tests |
| `biz/customer_group` | **42.0%** | ⚡ Improved — group CRUD + membership tests added |
| `biz/preference` | **49.7%** | ⚡ Improved — preference get/set/delete tests added |
| `biz/segment` | **42.0%** | ⚡ Improved — segment evaluation tests added |
| `biz/wishlist` | **68.4%** | ⚡ Improved — wishlist CRUD + dedup tests added |

**Remaining work**: `address` CRUD, `customer` core lifecycle + GDPR.

---

### 13. notification — ~33% → 60% (🟡 3h remaining) ⚡ IN PROGRESS

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/delivery` | **29.7%** | ⚡ Improved — channel routing tests added |
| `biz/message` | 52.4% | [ ] Add template rendering, retry tests |
| `biz/notification` | **22.3%** | ⚡ Improved — notification lifecycle tests added |
| `biz/preference` | **40.0%** | ⚡ Improved — preference management tests added |
| `biz/subscription` | **44.5%** | ⚡ Improved — subscribe/unsubscribe tests added |
| `biz/template` | **49.7%** | ⚡ Improved — template CRUD tests added |
| `provider/telegram` | 10.1% | [ ] Add send/error handling tests (mock HTTP client) |

**Remaining work**: `message` edge cases, `provider/telegram`.

---

### 14. promotion — 28.3% → 60% (🟡 5h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz` | 37.9% | [ ] Add coupon validation, usage limits, date range, stacking tests |
| `service` | 3.3% | [ ] Add gRPC handler tests |

---

### 15. gateway — 24.6% → 60% (🟠 6h)

| Package | Coverage | Action |
|---------|----------|--------|
| `bff` | 0.0% | [ ] Add BFF aggregation tests |
| `errors` | 82.0% | ✅ Good |
| `handler` | 28.4% | [ ] Add route handler tests (auth proxy, catalog proxy) |
| `middleware` | 19.4% | [ ] Add rate limiting, CORS, auth middleware tests |

---

### 16. payment — ~28% → 60% (🔴 5h remaining) ⚡ IN PROGRESS

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/payment` | **35.7%** | ⚡ **Improved** 26.9%→35.7% — validation (Luhn, CVV, expiry, card brand), Money type, idempotency, request validation, gateway mapping (40+ tests) |
| `biz/transaction` | **80.6%** | ✅ **Done** — GetPaymentTransactions, GetCustomerTransactions (filters, pagination), Reconcile (8 tests) |
| `biz/payment_method` | **44.0%** | ⚡ **Improved** 0%→44.0% — encrypt/decrypt, CRUD, verify with gateway, detach, delete (14 tests) |
| `biz/refund` | 51.5% | [ ] Add partial refund, deadline, validation tests |
| `biz/settings` | 80.9% | ✅ Good |
| `biz/fraud` | build failed | [ ] Fix stale test fields (ShippingCity, IPCountry removed from FraudContext), then add tests |
| `biz/reconciliation` | build failed | [ ] Fix stale test (CursorRequest/CursorResponse undefined), then add tests |
| `gateway/momo` | 20.3% | [ ] Add gateway integration tests |
| `gateway/paypal` | 24.5% | [ ] Add gateway integration tests |
| `gateway/stripe` | 19.4% | [ ] Add gateway integration tests |
| `gateway/vnpay` | 18.6% | [ ] Add gateway integration tests |
| `data` | 21.0% | [ ] Add repo-level tests |
| `service` | 6.6% | [ ] Add gRPC handler tests |

**Pre-existing issues fixed**: Removed 3 duplicate gomock test files and 1 stale P1 test file that caused build failures.
**Remaining work**: `fraud` fix + tests, `reconciliation` fix + tests, `refund` edge cases, gateway tests.

---

### 17. search — 15.3% → 60% (🔴 8h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz` | 38.7% | [ ] Add search ranking, facets, autocomplete, typo tolerance tests |
| `service` | 6.6% | [ ] Add gRPC handler tests |

**Note**: Search uses Elasticsearch — tests need mock ES client or in-memory engine.

---

### 18. catalog — ~18% → 60% (🔴 7h remaining) ⚡ IN PROGRESS

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/brand` | **63.0%** | ✅ **Done** — CRUD, slug uniqueness, product-in-use, URL validation (20 tests) |
| `biz/category` | 44.0% | [ ] Add tree operations, move, reorder tests |
| `biz/cms` | 54.0% | [ ] Add CMS content management tests |
| `biz/manufacturer` | 44.4% | [ ] Add manufacturer CRUD + product association tests |
| `biz/product` | 17.1% | [ ] Add product CRUD, variant, EAV attribute tests |
| `biz/product_attribute` | **30.6%** | ⚡ **Improved** 7.5%→30.6% — definition CRUD, set/delete values (13 tests) |
| `biz/product_visibility_rule` | **22.1%** | ⚡ **Improved** 8.9%→22.1% — activation, listing, all 6 rule types (18 tests) |
| `data/eventbus` | 20.3% | [ ] Add event publishing tests |
| `service` | 1.3% | [ ] Add gRPC handler tests (biggest gap) |

**Remaining work**: `product` (biggest gap), `category`, `cms`, `manufacturer`, `service` layer.

---

### 19. analytics — ~14% → 60% (🔴 8h remaining) ⚡ IN PROGRESS

| Package | Coverage | Action |
|---------|----------|--------|
| `biz` | **17.5%** | ⚡ **Improved** 8.3%→17.5% — dashboard, revenue, customer, order, product, inventory usecases (20 new tests) |
| `biz` (remaining) | — | [ ] Add AB testing, alerts, custom reports, predictive, real-time, multi-channel tests |
| `pkg/pii` | 96.2% | ✅ Excellent |
| `service` | 12.0% | [ ] Add aggregation, event processor, customer journey, return/refund tests |

**Mocks**: ✅ mockgen ready (3 interfaces in `biz/mocks/`)
**Note**: Coverage % is artificially low due to massive 70+ method `AnalyticsRepository` interface (all unimplemented methods count as uncovered).

---

## 🏗️ Recommended Execution Order

### Sprint 1 — Quick Wins (3 services, ~3.5h, ship from 0→3 at 60%+)
1. **location** 58.8% → 60% (0.5h)
2. **return** 56.8% → 60% (1h)
3. **auth** 51.4% → 60% (2h)

### Sprint 2 — Mid-Tier (5 services, ~17h, ship from 3→8 at 60%+)
4. **loyalty-rewards** 47.7% → 60% (3h)
5. **fulfillment** 38.8% → 60% (4h)
6. **review** 38.3% → 60% (4h)
7. **shipping** 35.1% → 60% (4h)
8. **pricing** ~38% → 60% (2h) ⚡ partially done

### Sprint 3 — Core Services (6 services, ~28h, ship from 8→14)
9. **warehouse** 35.7% → 60% (5h)
10. **user** 33.8% → 60% (5h)
11. **order** 30.6% → 60% (6h)
12. **customer** ~35% → 60% (4h) ⚡ partially done
13. **notification** ~33% → 60% (3h) ⚡ partially done
14. **promotion** 28.3% → 60% (5h)

### Sprint 4 — Heavy Lift (5 services, ~37h, ship from 14→19)
15. **gateway** 24.6% → 60% (6h)
16. **payment** ~28% → 60% (5h) ⚡ partially done
17. **search** 15.3% → 60% (8h)
18. **catalog** ~18% → 60% (7h) ⚡ partially done
19. **analytics** ~14% → 60% (8h) ⚡ partially done

**Total Remaining Effort**: ~82.5h (~10 days)

---

## 🔧 Testing Standards

### Mock Strategy
- **mockgen** is the standard (see `write-tests/SKILL.md`)
- Services with mockgen ready: analytics ✅, return ✅, order ✅
- All other services: add `//go:generate mockgen` to interfaces before writing tests

### Test Patterns
- **Table-driven tests** with `t.Run()` subtests
- **gomock** `EXPECT()` + `Return()` for interface mocking
- **testify** `assert` for assertions
- Tests file naming: `<file>_test.go` in same package

### CI Gate
- `COVERAGE_THRESHOLD=60` enforced in `lint-test.yaml`
- Per-service override via CI variable if needed during migration:
  ```yaml
  variables:
    COVERAGE_THRESHOLD: "40"  # temporary until tests added
  ```

---

## 📝 Test Files Created/Modified (Session 2026-03-02)

### New Test Files
| File | Tests | Coverage |
|------|-------|----------|
| `pricing/internal/biz/discount/discount_test.go` | 14 | 93.3% |
| `pricing/internal/biz/rule/rule_test.go` | 17 | 57.7% |
| `pricing/internal/biz/tax/tax_test.go` | 12 | 63.1% |
| `payment/internal/biz/payment/payment_test.go` | 40+ | 35.7% |
| `payment/internal/biz/transaction/transaction_test.go` | 8 | 80.6% |
| `payment/internal/biz/payment_method/payment_method_test.go` | 14 | 44.0% |

### Modified Test Files
| File | Tests Added | Key Changes |
|------|-------------|-------------|
| `catalog/internal/biz/brand/brand_test.go` | 20 | Full CRUD, slug uniqueness, URL validation |
| `catalog/internal/biz/product_attribute/product_attribute_test.go` | 13 | Definition CRUD, set/delete values |
| `catalog/internal/biz/product_visibility_rule/product_visibility_rule_test.go` | 18 | Activation, all 6 rule type validations |
| `analytics/internal/biz/usecase_test.go` | 20 | Revenue, Customer, Order, Product, Inventory usecases |
| `customer/internal/biz/*/` | ~15 | Audit, customer_group, preference, segment, wishlist |
| `notification/internal/biz/*/` | ~18 | Delivery, notification, preference, subscription, template |

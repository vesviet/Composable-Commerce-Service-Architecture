# Test Coverage Checklist — Target 60%+ All Services

> **Generated**: 2026-03-02 | **Platform**: 19 Go Services | **Current**: 0/19 above 60%

---

## 📊 Dashboard

| # | Service | Current | Target | Gap | Priority | Est. Effort |
|---|---------|---------|--------|-----|----------|-------------|
| 1 | **location** | 58.8% | 60% | 1.2% | 🟢 Quick Win | 0.5h |
| 2 | **return** | 56.8% | 60% | 3.2% | 🟢 Quick Win | 1h |
| 3 | **auth** | 51.4% | 60% | 8.6% | 🟢 Easy | 2h |
| 4 | **loyalty-rewards** | 47.7% | 60% | 12.3% | 🟡 Medium | 3h |
| 5 | **fulfillment** | 38.8% | 60% | 21.2% | 🟡 Medium | 4h |
| 6 | **review** | 38.3% | 60% | 21.7% | 🟡 Medium | 4h |
| 7 | **warehouse** | 35.7% | 60% | 24.3% | 🟡 Medium | 5h |
| 8 | **shipping** | 35.1% | 60% | 24.9% | 🟡 Medium | 4h |
| 9 | **user** | 33.8% | 60% | 26.2% | 🟡 Medium | 5h |
| 10 | **pricing** | 32.4% | 60% | 27.6% | 🟡 Medium | 4h |
| 11 | **order** | 30.6% | 60% | 29.4% | 🟠 Hard | 6h |
| 12 | **customer** | 30.2% | 60% | 29.8% | 🟠 Hard | 6h |
| 13 | **notification** | 29.7% | 60% | 30.3% | 🟡 Medium | 4h |
| 14 | **promotion** | 28.3% | 60% | 31.7% | 🟡 Medium | 5h |
| 15 | **gateway** | 24.6% | 60% | 35.4% | 🟠 Hard | 6h |
| 16 | **payment** | 20.0% | 60% | 40.0% | 🔴 Major | 8h |
| 17 | **search** | 15.3% | 60% | 44.7% | 🔴 Major | 8h |
| 18 | **catalog** | 13.4% | 60% | 46.6% | 🔴 Major | 10h |
| 19 | **analytics** | 11.3% | 60% | 48.7% | 🔴 Major | 10h |

**Total Estimated Effort**: ~95h (~12 days)

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

### 10. pricing — 32.4% → 60% (🟡 4h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/calculation` | 51.9% | [ ] Add discount stacking, tax calculation, rounding tests |
| `biz/price` | 26.0% | [ ] Add price rule CRUD, schedule activation, variant pricing tests |

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

### 12. customer — 30.2% → 60% (🟠 6h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/address` | 36.3% | [ ] Add address CRUD, validation, default address tests |
| `biz/customer` | 28.3% | [ ] Add customer lifecycle, segment assignment, GDPR tests |

---

### 13. notification — 29.7% → 60% (🟡 4h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/message` | 52.4% | [ ] Add template rendering, channel routing, retry tests |
| `provider/telegram` | 10.1% | [ ] Add send/error handling tests (mock HTTP client) |

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

### 16. payment — 20.0% → 60% (🔴 8h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/fraud` | 8.0% | [ ] Add fraud detection rules, scoring, threshold tests |
| `biz/payment` | 26.9% | [ ] Add capture/void/refund flow, multi-gateway, idempotency tests |
| `biz/refund` | 51.5% | [ ] Add partial refund, deadline, validation tests |
| `biz/settings` | 80.9% | ✅ Good |
| `data` | 21.0% | [ ] Add repo-level tests |
| `service` | 6.6% | [ ] Add gRPC handler tests |

---

### 17. search — 15.3% → 60% (🔴 8h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz` | 38.7% | [ ] Add search ranking, facets, autocomplete, typo tolerance tests |
| `service` | 6.6% | [ ] Add gRPC handler tests |

**Note**: Search uses Elasticsearch — tests need mock ES client or in-memory engine.

---

### 18. catalog — 13.4% → 60% (🔴 10h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz/brand` | 0.0% | [ ] Add brand CRUD tests |
| `biz/category` | 44.0% | [ ] Add tree operations, move, reorder tests |
| `biz/cms` | 54.0% | [ ] Add CMS content management tests |
| `biz/manufacturer` | 44.4% | [ ] Add manufacturer CRUD + product association tests |
| `biz/product` | 17.1% | [ ] Add product CRUD, variant, EAV attribute tests |
| `biz/product_attribute` | 7.5% | [ ] Add attribute definition, value validation tests |
| `biz/product_visibility_rule` | 8.9% | [ ] Add visibility rule evaluation tests |
| `data/eventbus` | 20.3% | [ ] Add event publishing tests |
| `service` | 1.3% | [ ] Add gRPC handler tests (biggest gap) |

---

### 19. analytics — 11.3% → 60% (🔴 10h)

| Package | Coverage | Action |
|---------|----------|--------|
| `biz` | 8.3% | [ ] Add all usecase tests (AB testing, alerts, custom reports, dashboards) |
| `pkg/pii` | 96.2% | ✅ Excellent |
| `service` | 12.0% | [ ] Add aggregation, event processor, customer journey, return/refund tests |

**Mocks**: ✅ mockgen ready (3 interfaces in `biz/mocks/`)

---

## 🏗️ Recommended Execution Order

### Sprint 1 — Quick Wins (3 services, ~3.5h, ship from 0→3 at 60%+)
1. **location** 58.8% → 60% (0.5h)
2. **return** 56.8% → 60% (1h)
3. **auth** 51.4% → 60% (2h)

### Sprint 2 — Mid-Tier (5 services, ~20h, ship from 3→8 at 60%+)
4. **loyalty-rewards** 47.7% → 60% (3h)
5. **fulfillment** 38.8% → 60% (4h)
6. **review** 38.3% → 60% (4h)
7. **shipping** 35.1% → 60% (4h)
8. **pricing** 32.4% → 60% (4h)

### Sprint 3 — Core Services (6 services, ~32h, ship from 8→14)
9. **warehouse** 35.7% → 60% (5h)
10. **user** 33.8% → 60% (5h)
11. **order** 30.6% → 60% (6h)
12. **customer** 30.2% → 60% (6h)
13. **notification** 29.7% → 60% (4h)
14. **promotion** 28.3% → 60% (5h)

### Sprint 4 — Heavy Lift (5 services, ~42h, ship from 14→19)
15. **gateway** 24.6% → 60% (6h)
16. **payment** 20.0% → 60% (8h)
17. **search** 15.3% → 60% (8h)
18. **catalog** 13.4% → 60% (10h)
19. **analytics** 11.3% → 60% (10h)

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

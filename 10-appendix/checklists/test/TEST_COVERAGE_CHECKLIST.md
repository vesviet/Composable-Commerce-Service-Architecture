# Test Coverage Checklist — Target 60%+ All Services

> **Generated**: 2026-03-02 | **Last Updated**: 2026-03-03 19:22 (UTC+7)
> **Platform**: 19 Go Services | **Current**: 10/19 above 60% (overall service-level)

> [!IMPORTANT]
> This checklist is the single source of truth for test coverage status.
> Agents should update this file after completing any test coverage work.

---

## 📊 Dashboard

| # | Service | Biz Coverage | Overall | Target | Status | Work Done |
|---|---------|-------------|---------|--------|--------|-----------|
| 1 | **analytics** | **67.6%** | **~65%** | 60% | ✅ Done | biz 67.6%, service 61.1%, marketplace 73.2%, pii 96.2% |
| 2 | **pricing** | **75.5% avg** | **~68%** | 60% | ✅ Done | All 8 biz packages >63%, avg 75.5% |
| 3 | **gateway** | N/A | **~82%** | 60% | ✅ Done | All packages >56%, most >70% |
| 4 | **review** | **63.9% avg** | **~55%** | 60% | ✅ Biz Done | All 4 biz packages >60%. Service build fixed |
| 5 | **loyalty-rewards** | **75.6% avg** | **~55%** | 60% | ✅ Biz Done | All 6 biz packages >71%. Service 30.4% |
| 6 | **auth** | **70.5% avg** | **~51%** | 60% | ⚡ Partial | login 79.1%, token 61.9%. Other layers 0% |
| 7 | **location** | **62.2%** | **~64%** | 60% | ✅ Done | biz 62.2%, postgres 65.1%, service 65.3% |
| 8 | **catalog** | **68.3% avg** | **~55%** | 60% | ⚡ Partial | 6/7 biz >62%, product 57.5%. Model 79.2%. Service 0% |
| 9 | **search** | **92.3% avg** | **~40%** | 60% | ⚡ Partial | biz 77%, cms 100%, ml 100%. Service 19% |
| 10 | **user** | **73.0%** | **~55%** | 60% | ⚡ Partial | biz 73.0%. Postgres 35.5% |
| 11 | **shipping** | **63.7%** | **~50%** | 60% | ⚡ Partial | shipment 63.7%, carriers >83%. Service 7.3% |
| 12 | **fulfillment** | **63.1% avg** | **~35%** | 60% | ⚡ Partial | biz 57.5%, pkg 53.7%, picklist 52.8%, qc 88.2%. Service 0% |
| 13 | **order** | **74.7% avg** | **~35%** | 60% | ⚡ Partial | cancel 78.6%, order 60.2%, status 85.3%. Service 0% |
| 14 | **promotion** | **74.3%** | **~35%** | 60% | ⚡ Partial | biz 74.3%. Service 3.3% |
| 15 | **payment** | **53.5% avg** | **~35%** | 60% | ⚡ Partial | pm 90.2%, txn 80.6%, settings 80.9%, refund 69.1%, payment 52.0%. Gateways 18-24% |
| 16 | **warehouse** | **49.9% avg** | **~35%** | 60% | ⚡ Partial | warehouse 60.8%, txn 57.9%, inventory 55.7%, reservation 51.1%, throughput 23.8% |
| 17 | **customer** | **45.4% avg** | **~35%** | 60% | ⚡ Partial | wishlist 68.4%, address 52.4%, customer 51.9%. Others 15-49% |
| 18 | **notification** | **39.8% avg** | **~30%** | 60% | ⚡ Partial | message 52.4%, template 49.7%. Others 10-44% |
| 19 | **return** | **65.1%** | **~65%** | 60% | ✅ Done | biz 65.1%. Build fixed (added CancelStaleReturns mock) |

---

## ✅ Per-Service Detailed Breakdown

### 1. analytics — ✅ DONE (~65% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz` | **67.6%** | ✅ Done |
| `pkg/pii` | **96.2%** | ✅ Excellent |
| `service` | **61.1%** | ✅ Done |
| `service/marketplace` | **73.2%** | ✅ Done |

---

### 2. pricing — ✅ DONE (~68% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/calculation` | **74.1%** | ✅ Done |
| `biz/currency` | **72.5%** | ✅ Done |
| `biz/discount` | **93.3%** | ✅ Excellent |
| `biz/dynamic` | **77.1%** | ✅ Done |
| `biz/price` | **63.5%** | ✅ Done |
| `biz/rule` | **80.2%** | ✅ Done |
| `biz/tax` | **63.1%** | ✅ Done |
| `biz/worker` | **82.5%** | ✅ Done |

---

### 3. gateway — ✅ DONE (~82% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `bff` | **77.0%** | ✅ Done |
| `client` | **80.5%** | ✅ Done |
| `config` | **85.5%** | ✅ Done |
| `errors` | **90.4%** | ✅ Excellent |
| `handler` | **79.8%** | ✅ Done |
| `middleware` | **70.7%** | ✅ Done |
| `observability` | **89.8%** | ✅ Done |
| `observability/health` | **74.2%** | ✅ Done |
| `observability/jaeger` | **73.5%** | ✅ Done |
| `observability/prometheus` | **95.8%** | ✅ Excellent |
| `observability/redis` | **81.7%** | ✅ Done |
| `proxy` | **87.2%** | ✅ Done |
| `registry` | **100.0%** | ✅ Perfect |
| `router` | **64.1%** | ✅ Done |
| `router/url` | **100.0%** | ✅ Perfect |
| `router/utils` | **56.3%** | ⚠️ Below target |
| `server` | **96.0%** | ✅ Excellent |
| `service` | **64.8%** | ✅ Done |
| `transformer` | **98.4%** | ✅ Excellent |
| `worker` | **83.5%** | ✅ Done |

---

### 4. review — ✅ Biz Done, Service Build Fixed

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/helpful` | **63.9%** | ✅ Done |
| `biz/moderation` | **69.9%** | ✅ Done |
| `biz/rating` | **61.7%** | ✅ Done |
| `biz/review` | **60.3%** | ✅ Done |
| `service` | 0.0% | ✅ Build fixed (`req.Rating` type mismatch). [ ] Add gRPC handler tests |

---

### 5. loyalty-rewards — ✅ Biz Done, Service/Data Remaining

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/account` | **75.7%** | ✅ Done |
| `biz/redemption` | **75.3%** | ✅ Done |
| `biz/referral` | **75.5%** | ✅ Done |
| `biz/reward` | **77.6%** | ✅ Done |
| `biz/tier` | **71.9%** | ✅ Done |
| `biz/transaction` | **77.5%** | ✅ Done |
| `data/postgres` | 38.3% | [ ] Add repo-level tests |
| `service` | 30.4% | [ ] Add gRPC handler tests |

---

### 6. auth — ⚡ Biz Done, Other Layers Remaining

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/login` | **79.1%** | ✅ Done |
| `biz/token` | **61.9%** | ✅ Done |
| `biz/audit` | 0.0% | [ ] Add audit trail tests |
| `biz/session` | 0.0% | [ ] Add session management tests |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 7. location — ✅ DONE (~64% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/location` | **62.2%** | ✅ Done |
| `data/postgres` | **65.1%** | ✅ Done |
| `service` | **65.3%** | ✅ Done (build fixed — added DeleteLocation mock) |

---

### 8. catalog — ⚡ Biz Mostly Done, Product Close

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/brand` | **63.0%** | ✅ Done |
| `biz/category` | **64.8%** | ✅ Done |
| `biz/cms` | **83.0%** | ✅ Done |
| `biz/manufacturer` | **70.9%** | ✅ Done |
| `biz/product` | **57.5%** | ⚠️ 2.5% to target — needs Redis-dependent cache/stock paths |
| `biz/product_attribute` | **62.5%** | ✅ Done |
| `biz/product_visibility_rule` | **76.4%** | ✅ Done |
| `model` | **79.2%** | ✅ Done |
| `data/eventbus` | 0.0% | [ ] Add event publishing tests |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 9. search — ⚡ Biz Done, Service Low

| Package | Coverage | Status |
|---------|----------|--------|
| `biz` | **77.0%** | ✅ Done |
| `biz/cms` | **100.0%** | ✅ Perfect |
| `biz/ml` | **100.0%** | ✅ Perfect |
| `service` | **19.0%** | [ ] Add gRPC handler tests (heavy ES dependency) |

---

### 10. user — ⚡ Biz Done, Data Remaining

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/user` | **73.0%** | ✅ Done |
| `data/postgres` | 35.5% | [ ] Add repo-level tests (pagination, filtering) |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 11. shipping — ⚡ Biz+Carriers Done, Service Low

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/shipment` | **63.7%** | ✅ Done |
| `carrier/dhl` | **92.3%** | ✅ Excellent |
| `carrier/fedex` | **90.1%** | ✅ Excellent |
| `carrier/ups` | **83.7%** | ✅ Done |
| `data` | 14.9% | [ ] Add repo-level tests |
| `service` | 7.3% | [ ] Add gRPC handler tests |

---

### 12. fulfillment — ⚡ Biz Partially Done, Service 0%

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/fulfillment` | **57.5%** | ⚠️ 2.5% to target |
| `biz/package_biz` | **53.7%** | ⚠️ 6.3% to target |
| `biz/picklist` | **52.8%** | ⚠️ 7.2% to target |
| `biz/qc` | **88.2%** | ✅ Excellent |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 13. order — ⚡ Biz Good, Service/Data Remaining

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/cancellation` | **78.6%** | ✅ Done |
| `biz/order` | **60.2%** | ✅ Done |
| `biz/status` | **85.3%** | ✅ Excellent |
| `data/eventbus` | **44.3%** | [ ] Add event publishing + idempotency tests |
| `security` | 31.0% | [ ] Add authorization + RBAC tests |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 14. promotion — ⚡ Biz Done, Service Very Low

| Package | Coverage | Status |
|---------|----------|--------|
| `biz` | **74.3%** | ✅ Done |
| `service` | 3.3% | [ ] Add gRPC handler tests |

---

### 15. payment — ⚡ Partially Done, Mixed

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/payment` | **52.0%** | ⚠️ 8% to target |
| `biz/payment_method` | **90.2%** | ✅ Excellent |
| `biz/transaction` | **80.6%** | ✅ Done |
| `biz/settings` | **80.9%** | ✅ Done |
| `biz/refund` | **69.1%** | ✅ Done |
| `biz/fraud` | **29.2%** | [ ] Add more rule coverage tests |
| `biz/reconciliation` | **12.9%** | [ ] Add reconciliation flow tests |
| `biz/webhook` | **17.2%** | [ ] Add webhook processing tests |
| `gateway/momo` | 20.3% | [ ] Add gateway integration tests |
| `gateway/paypal` | 24.5% | [ ] Add gateway integration tests |
| `gateway/stripe` | 19.4% | [ ] Add gateway integration tests |
| `gateway/vnpay` | 18.6% | [ ] Add gateway integration tests |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 16. warehouse — ⚡ Partially Done, Mixed

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/warehouse` | **60.8%** | ✅ Done |
| `biz/transaction` | **57.9%** | ⚠️ 2.1% to target |
| `biz/inventory` | **55.7%** | ⚠️ 4.3% to target |
| `biz/reservation` | **51.1%** | [ ] Add reserve/release/expire flow tests |
| `biz/throughput` | **23.8%** | [ ] Add capacity calculation + bottleneck tests |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 17. customer — ⚡ Partially Done, Core Packages Below Target

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/wishlist` | **68.4%** | ✅ Done |
| `biz/address` | **52.4%** | ⚠️ 7.6% to target |
| `biz/customer` | **51.9%** | ⚠️ 8.1% to target |
| `biz/preference` | **49.7%** | [ ] Add more preference tests |
| `biz/customer_group` | **42.0%** | [ ] Add group CRUD + membership tests |
| `biz/segment` | **42.0%** | [ ] Add segment evaluation tests |
| `biz/audit` | **41.1%** | [ ] Add audit trail tests |
| `biz/analytics` | **15.6%** | [ ] Add analytics integration tests |

---

### 18. notification — ⚡ Partially Done, Most Packages Below Target

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/message` | **52.4%** | ⚠️ 7.6% to target |
| `biz/template` | **49.7%** | [ ] Add template rendering tests |
| `biz/subscription` | **44.5%** | [ ] Add subscribe/unsubscribe tests |
| `biz/preference` | **40.0%** | [ ] Add preference management tests |
| `biz/delivery` | **29.7%** | [ ] Add channel routing tests |
| `biz/notification` | **22.3%** | [ ] Add notification lifecycle tests |
| `provider/telegram` | **10.1%** | [ ] Add send/error handling tests |

---

### 19. return — ✅ DONE (~65% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/return` | **65.1%** | ✅ Done (build fixed — added CancelStaleReturns mock) |

---

## 🏗️ Recommended Execution Order

### Sprint 1 — Close the Gap (biz packages near 60%)
1. **fulfillment** biz 57.5%, pkg 53.7%, picklist 52.8% → push all to 60% (~1h)
2. **catalog** product 57.5% → push to 60% (~0.5h, needs miniredis)
3. **warehouse** txn 57.9%, inventory 55.7% → push to 60% (~1h)
4. **payment** payment 52.0% → push to 60% (~1h)

### Sprint 2 — Fix Build Failures
5. **return** — fix MockReturnRequestRepo then test (~0.5h)
6. **review** — fix service build (Rating type mismatch) (~0.5h)
7. **location** — fix service build (~0.5h)

### Sprint 3 — Customer + Notification Deep Coverage
8. **customer** — address 52.4%, customer 51.9%, rest <50% → push all biz >60% (~3h)
9. **notification** — all biz packages <53% → push to 60% (~3h)

### Sprint 4 — Service Layer Coverage (biggest overall impact)
10. **service layers** across all services — most are 0-7.3%, yet contain significant code (~20h total)

**Total Remaining Effort**: ~31h (~4 days)

---

## 🔧 Testing Standards

### Mock Strategy
- **mockgen** is the standard (see `write-tests/SKILL.md`)
- Services with mockgen ready: analytics ✅, return ✅ (needs regen), order ✅, loyalty-rewards ✅, fulfillment ✅, customer ✅
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

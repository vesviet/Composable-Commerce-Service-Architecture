# Test Coverage Matrix — All Services

> Run date: 2026-02-20 | Command: `go test -cover ./internal/biz/...` per service  
> Target Coverage: **60% - 80%** (pragmatic goal from user)

---

## 📊 Executive Summary

| Phân loại | Số lượng | Tỷ lệ |
|-----------|----------|-------|
| 🟢 **Đạt mục tiêu (≥ 60%)** | 5 | ~24% |
| 🟡 **Cần cải thiện (30% - 59%)** | 9 | ~43% |
| 🔴 **Dưới chuẩn / Fail (0% - 29%)** | 7 | ~33% |

> **Overall**: ~38% lượng test case hợp lệ. Khoảng cách đến 80% còn khá xa nhưng có nền tảng tốt ở các service core.

---

## 📈 Bảng Coverage Chi Tiết (Biz Layer)

| # | Service | Build | Coverage Chính | Trạng thái | Action Item |
|---|---------|-------|----------------|-----------|-------------|
| 1 | **analytics** | ✅ | biz: **0.0%**, pkg helper: 96.2% | 🔴 0% biz | Viết unit tests cho aggregation logic |
| 2 | **auth** | ✅ | login: **79.1%**, token: **49.8%** | 🟢 login OK | Bổ sung test GenerateToken, expiry scenarios |
| 3 | **catalog** | 🔨 BUILD FAIL | product: **16.4%**, attribute: **7.6%** | 🔴 | Fix build brand/category/cms/manufacturer |
| 4 | **checkout** | ✅ | cart: **40.1%**, checkout: **41.6%** | 🟡 | Cover cart edge cases, pricing race condition |
| 5 | **common-operations** | ✅ | task: **37.9%** | 🟡 | Add retry, failure, status tracking tests |
| 6 | **customer** | ✅ | address: **37.2%**, customer: **28.5%** | 🔴 | Test preference/segment/wishlist (0%) |
| 7 | **fulfillment** | ❌ FAIL | picklist: **45.7%**, qc: **88.2%** | 🔴 FIXED | `HappyPath` giờ clean sau fix mock — chờ verify |
| 8 | **gateway** | N/A | middleware tests OK | 🟡 | middleware OK; biz not measurable |
| 9 | **location** | ✅ | location: **49.1%** | 🟡 | +20% more to hit 70% target |
| 10 | **loyalty-rewards** | ✅ | account: **68.9%**, referral: **58.5%**, reward: **30.6%** | 🟢 | tier (21%) & reward (30%) cần boost |
| 11 | **notification** | ✅ | message: **50.3%**, biz: **0%** | 🔴 | delivery/preference/template: 0% |
| 12 | **order** | ✅ | cancellation: **78.6%**, order: **62.2%** | 🟢 | validation/status 0% packages |
| 13 | **payment** | ✅ | payment: **19.2%**, settings: **80.9%** | 🔴 ⚠️ | ĐÁNG BÁO ĐỘNG: core payment chỉ 19% |
| 14 | **pricing** | ❌ FAIL | calc: **54.7%**, worker: **44.6%** | 🟡 FIXED | `CurrencyConversionFailure` + `InvalidCachedPrice` đã fix |
| 15 | **promotion** | ✅ | biz: **34.4%** | 🟡 | Coupon validation, stacking chưa cover |
| 16 | **return** | ✅ | return: **67.1%** | 🟢 | Sát target, cần exchange flow tests |
| 17 | **review** | ✅ | rating: **77.0%**, mod: **37.6%**, review: **35.8%** | 🟢 | moderation/helpful cần boost |
| 18 | **search** | ✅ | biz: **37.3%** | 🟡 | ElasticSearch mapping logic cần cover |
| 19 | **shipping** | ✅ | shipment: **18.6%** | 🔴 | Carrier rules, fee calculation |
| 20 | **user** | ❌ FAIL → FIXED | user: **32.8%** | 🟡 FIXED | `WeakPassword` assert fixed (`"password"`) |
| 21 | **warehouse** | ❌ FAIL → FIXED | transaction: **57.9%** | 🟡 FIXED | `ConfirmReservation` + `FulfillmentCompleted` mock fixed |

---

## 🔧 Fixes Applied (2026-02-20)

| Service | Test | Fix |
|---------|------|-----|
| **user** | `TestCreateUser_WeakPassword` | Assert `"VALIDATION_ERROR"` → `"password"` |
| **pricing** | `TestPriceUsecase_GetPrice_CurrencyConversionFailure` | Added `IsActive:true` + effective dates to `eurPrice` mock |
| **pricing** | `TestPriceUsecase_GetPrice_InvalidCachedPrice` | Added `IsActive:true` + effective dates to `validPrice` mock |
| **warehouse/reservation** | `TestConfirmReservation_Success` | `FindByID` → `FindByIDForUpdate` (ConfirmReservation uses row-lock) |
| **warehouse/inventory** | `TestHandleFulfillmentStatusChanged_Completed` | `FindByID` → `FindByIDForUpdate` (same root cause) |

---

## 🎯 Action Plan — Đạt mốc 60-80%

### Phase 1: Fix Build Failures (Ưu tiên tối cao)

| Service | Action |
|---------|--------|
| **catalog** | Fix compile error trong `biz/brand`, `biz/category`, `biz/cms`, `biz/manufacturer` |
| **fulfillment** | Verify sau fix mock — run tests again |

### Phase 2: Tập kích Payment (P0 Critical)

**payment** core hiện chỉ **19.2%** — đây là rủi ro lớn nhất:
- Viết table-driven tests: Fraud block, Authorized, Capture, IPN/Webhook, Idempotency
- Mục tiêu: **80%**

### Phase 3: Boost Middle Tier (30-59% → 60%+)

| Service | Từ | → | Priority |
|---------|-----|---|---------|
| **checkout** | 41% | 65% | P1 |
| **customer** | 28% | 60% | P1 |
| **shipping** | 19% | 55% | P1 |
| **review/mod** | 37% | 60% | P2 |
| **location** | 49% | 70% | P2 |
| **promotion** | 34% | 60% | P2 |

### Phase 4: Polish High Performers

- **order**: Add `biz/validation` and `biz/status` tests (+5-10%)
- **auth/token**: Add GenerateToken success path (49% → 70%)
- **loyalty-rewards**: Boost `reward` (30%) and `tier` (21%)

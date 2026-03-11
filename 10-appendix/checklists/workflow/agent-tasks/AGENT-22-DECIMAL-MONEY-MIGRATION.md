# AGENT-22: Financial Precision — `float64` → `decimal` + Protobuf `Money` Type (C2)

> **Created**: 2026-03-08  
> **Priority**: P0 (Financial Safety)  
> **Scope**: `common`, `gateway`, `pricing`, `payment`, `order`, `promotion`, `shipping`  
> **Estimated Effort**: 3 weeks (3 phases)  
> **Source**: [float64→decimal Review](file:///Users/tuananh/.gemini/antigravity/brain/7810210e-17f2-4572-9ef6-cc9c5e1d283a/float64_decimal_review.md), [Option C Deep Dive](file:///Users/tuananh/.gemini/antigravity/brain/7810210e-17f2-4572-9ef6-cc9c5e1d283a/option_c_money_type_review.md)  
> **Supersedes**: AGENT-21 Task 1 (replaces simple `double→string` approach with full `Money` type)

---

## 📋 Overview

All financial fields across the platform use Go `float64` mapped to PostgreSQL `decimal(15,2)`. Data is stored precisely in DB but **loses precision** when read into Go for business logic. This migration introduces:

1. A shared `Money` protobuf message (C2 String Decimal pattern)
2. A `common/utils/money` Go package with GORM `Scanner/Valuer`
3. Phased migration of all financial services with **zero breaking API changes**

**Approach**: C2 String Decimal (panel unanimously approved)
```protobuf
message Money {
  string value = 1;          // Decimal string e.g. "19.99"
  string currency_code = 2;  // ISO 4217
}
```

---

## Phase 1: Foundation (Week 1) — `common` + `pricing`

### [ ] Task 1: Create `common/proto/v1/money.proto`

**File**: `common/proto/v1/money.proto` (NEW)  
**Effort**: 0.5 day

- [ ] 1.1 Create proto definition:
  ```protobuf
  syntax = "proto3";
  package api.common.v1;
  option go_package = "gitlab.com/ta-microservices/common/proto/v1;v1";

  message Money {
    string value = 1;
    string currency_code = 2;
  }
  ```
- [ ] 1.2 Run `protoc` to generate Go code
- [ ] 1.3 Verify import works from other services

**Acceptance Criteria**: `api.common.v1.Money` importable across all services.

---

### [ ] Task 2: Create `common/utils/money` Package

**File**: `common/utils/money/` (NEW directory)  
**Effort**: 1 day

- [ ] 2.1 Create `money.go` — core `Money` type wrapping `decimal.Decimal`:
  ```go
  type Money struct { decimal.Decimal }
  func FromString(s string) (Money, error)
  func FromFloat64(f float64) Money     // for backward compat only
  func FromMinorUnits(amount int64, currencyCode string) Money // handles USD (100) vs VND (1)
  func Zero() Money
  ```
- [ ] 2.2 Create `gorm.go` — GORM `Scanner/Valuer` for **zero DB migration**:
  ```go
  func (m Money) Value() (driver.Value, error)   // → Enforce RoundBank before returning string "19.99"
  func (m *Money) Scan(value interface{}) error   // ← string|float64|[]byte
  ```
- [ ] 2.3 Create `json.go` — JSON as string `"19.99"` (not float):
  ```go
  func (m Money) MarshalJSON() ([]byte, error)    // → `"19.99"`
  func (m *Money) UnmarshalJSON(data []byte) error // ← `"19.99"` or `19.99`
  ```
- [ ] 2.4 Create `proto.go` — Protobuf conversion helpers:
  ```go
  func ToProto(m Money, currency string) *v1.Money
  func FromProto(pb *v1.Money) (Money, error)
  func Float64ToProto(amount float64, currency string) *v1.Money  // backward compat
  ```
- [ ] 2.5 Create `arithmetic.go` — Safe operations:
  ```go
  func (m Money) Add(other Money) Money
  func (m Money) Sub(other Money) Money
  func (m Money) Mul(quantity int) Money
  func (m Money) MulDecimal(d decimal.Decimal) Money
  func (m Money) Div(divisor int64) Money         // Safe division
  func (m Money) Allocate(targets int) []Money    // Split without losing cents (e.g. 100/3 = 34, 33, 33)
  func (m Money) RoundBank(places int32) Money    // Banker's rounding
  func (m Money) IsZero() bool
  func (m Money) IsNegative() bool
  func (m Money) Equal(other Money) bool
  func (m Money) StringFixed(places int32) string
  ```
- [ ] 2.6 Create `money_test.go` — table-driven tests:
  - `FromString` valid/invalid
  - `FromCents` (1999 → "19.99", 350000 → "3500.00")
  - `Scan` from string, float64, []byte
  - `MarshalJSON` / `UnmarshalJSON` roundtrip
  - `RoundBank` edge cases (0.005 → "0.00", 0.015 → "0.02")
  - `Add`/`Sub` precision (0.1 + 0.2 == "0.30")

**Acceptance Criteria**: `go test ./common/utils/money/...` passes. GORM can read/write `decimal(15,2)` columns via `Money` type.

---

### [ ] Task 3: Migrate `pricing` Service

**Files**: `pricing/internal/data/postgres/price.go`, `discount.go`, `tax.go`, `pricing/internal/biz/calculation/calculation.go`  
**Effort**: 1.5 days

- [ ] 3.1 Update GORM models — `float64` → `money.Money`:
  ```go
  // BEFORE
  BasePrice float64 `gorm:"type:decimal(15,2);not null"`
  // AFTER
  BasePrice money.Money `gorm:"type:decimal(15,2);not null"`
  ```
- [ ] 3.2 Fix `calculation.go` — remove `decimal.NewFromFloat(basePrice)` anti-pattern:
  ```go
  // BEFORE (false decimal)
  basePriceDecimal := decimal.NewFromFloat(basePrice)
  // AFTER (exact)
  basePriceDecimal := priceModel.BasePrice.Decimal
  ```
- [ ] 3.3 Update `PriceCalculationResponse` struct fields
- [ ] 3.4 Update event payloads in `price_events.go`
- [ ] 3.5 Fix test assertions — `assert.Equal(t, float64(19.99), ...)` → `assert.True(t, got.Equal(money.FromString("19.99")))`
- [ ] 3.6 Run: `cd pricing && go build ./... && go test ./...`

**Acceptance Criteria**: DB reads do **NOT** go through `float64` anymore.

---

## Phase 2: Critical Financial Path (Week 2) — `payment` + `order`

### [ ] Task 4: Migrate `payment` Service

**Files**: `payment/internal/model/payment.go`, `refund.go`, `transaction.go`, `payment/internal/biz/gateway/stripe/`, `vnpay/`, `momo/`  
**Effort**: 2 days

- [ ] 4.1 Update GORM models — `Amount float64` → `Amount money.Money`
- [ ] 4.2 Fix Stripe gateway — `float64(cents)/100` → `money.FromMinorUnits(cents, "USD")`:
  ```go
  // BEFORE (precision loss)
  amount := float64(pi.Amount) / 100.0
  // AFTER (exact)
  amount := money.FromMinorUnits(pi.Amount, "USD")
  ```
- [ ] 4.3 Fix VNPay gateway — same `FromMinorUnits(amount, "VND")` pattern
- [ ] 4.4 Fix MoMo gateway — `float64(resp.Amount)` → `money.FromMinorUnits(resp.Amount, "VND")`
- [ ] 4.5 Update `payment_events.go` event struct fields
- [ ] 4.6 Update `payment.proto` — dual-write pattern:
  ```protobuf
  double amount = 5 [deprecated = true];
  api.common.v1.Money amount_money = 30;  // NEW
  ```
- [ ] 4.7 Update service layer to populate both old `double` and new `Money` fields
- [ ] 4.8 Update config — `MinAmount`, `MaxAmount` → `money.Money`
- [ ] 4.9 Run: `cd payment && go build ./... && go test ./...`

**Acceptance Criteria**: All Stripe/VNPay/MoMo conversions use `money.FromMinorUnits` with correct currency logic. No `float64(x)/100` anywhere.

---

### [ ] Task 5: Migrate `order` Service

**Files**: `order/internal/model/`, `order/internal/biz/`, `order/api/order/v1/order.proto`  
**Effort**: 2 days

- [ ] 5.1 Update GORM models — all price/amount fields → `money.Money`
- [ ] 5.2 Update `order.proto` — dual-write for 22 fields:
  - `Order.total_amount` (field 5) → deprecated + `Order.total` (field 40)
  - `OrderItem.unit_price` (field 7) → deprecated + `OrderItem.price` (field 20)
  - `OrderItem.total_price` (field 8) → deprecated + `OrderItem.total` (field 21)
  - `OrderItem.discount_amount` (field 9) → deprecated + `OrderItem.discount` (field 22)
  - `OrderItem.tax_amount` (field 10) → deprecated + `OrderItem.tax` (field 23)
  - `CreateOrderRequest.total_amount` (field 10) + `subtotal` + `discount_total` + `tax_total` + `shipping_cost`
  - `OrderPayment.amount` (field 6)
  - `ReturnRequest.restocking_fee/return_shipping_cost/refund_amount`
  - `ReturnItem.unit_price/refund_amount`
- [ ] 5.3 Update service layer — dual-write both deprecated `double` and new `Money` fields
- [ ] 5.4 Update event structs — `order_events.go` all financial fields
- [ ] 5.5 Update client types — `order/internal/client/types.go` (30+ fields)
- [ ] 5.6 Fix reconciliation logic — `==` → `money.Equal()` and use `m.Allocate()` for splitting order-level discounts across items
- [ ] 5.7 Run: `cd order && wire gen ./cmd/server/ && go build ./... && go test ./...`
- [ ] **5.8 E2E Dual-Write Validation**: Verify Cart → Checkout → Payment flow works via E2E tests for *both* legacy frontend payloads (double) and v2 payloads (Money).

**Acceptance Criteria**: All 22+ proto double fields have corresponding `Money` fields. Server dual-writes both. End-to-end tests prove zero disruption.

---

## Phase 3: Remaining Services (Week 3) — `promotion` + `shipping`

### [x] Task 6: Migrate `promotion` Service ✅ COMPLETED

**Files**: `promotion/internal/data/`, `promotion/internal/biz/`, `promotion/internal/service/`, tests  
**Effort**: 2 days

- [x] 6.1 Update GORM models — `DiscountAmount`, `OriginalAmount`, `FinalAmount`, `RulePrice`, etc. → `money.Money`
- [x] 6.2 Update biz layer types — all monetary fields in `types.go`, `Promotion`, `Campaign`, `Coupon`, `UsageStats`, `CatalogPriceIndex`
- [x] 6.3 Update discount calculation logic — `Mul().Div()` → `MulPercentage`, arithmetic uses `money.Money` methods
- [x] 6.4 Update promotion usage analytics — `TotalDiscount`, `AverageDiscount` bridged to `float64` at analytics boundary
- [x] 6.5 Update service layer — convert proto `float64` ↔ `money.Money` at gRPC boundary with helpers (`floatPtrToMoneyPtr`, `moneyPtrToFloatPtr`)
- [x] 6.6 Update all test files (promotion_test, catalog_indexing_test, validation_test, usage_tracking_test, service_test, etc.)
- [x] 6.7 Run: `cd promotion && go build ./... && go test ./...` — **ALL PASS**

---

### [ ] Task 7: Migrate `shipping` Service

**Effort**: 1 day

- [ ] 7.1 Update shipping cost models
- [ ] 7.2 Update shipping rate calculation logic
- [ ] 7.3 Run: `cd shipping && go build ./... && go test ./...`

---

### [ ] Task 8: Frontend Migration Support

**Scope**: `frontend` (Next.js), `admin` (React/Vite)  
**Effort**: 1 day

- [ ] 8.1 Create TypeScript helper:
  ```typescript
  interface Money { value: string; currencyCode: string; }
  const toNumber = (m: Money) => parseFloat(m.value);
  const format = (m: Money, locale = 'vi-VN') =>
    new Intl.NumberFormat(locale, { style: 'currency', currency: m.currencyCode })
      .format(toNumber(m));
  ```
- [ ] 8.2 Update API response types to read new `Money` fields (fall back to deprecated `double` if absent)
- [ ] 8.3 Verify all price displays use `format()` helper

---

### [ ] Task 9: API Gateway Validation Support

**Scope**: `gateway` service
**Effort**: 0.5 day

- [ ] 9.1 Ensure `gateway` validation logic correctly handles the new `Money` proto message type.
- [ ] 9.2 Update any openapi/swagger proxies to allow `amount_money` field mapping alongside legacy `amount`.

---

### [ ] Task 10: Deprecation Sunset (Sprint N+6)

**Scope**: All proto files  
**Effort**: 1 day (deferred)

- [ ] 10.1 Stop writing deprecated `double` fields in server responses
- [ ] 10.2 Monitor client usage via API metrics — ensure 0 reads on deprecated fields
- [ ] 10.3 Remove deprecated fields from proto files

---

## 🔧 Pre-Commit Checklist

```bash
# Phase 1
cd common && go build ./... && go test ./utils/money/...
cd pricing && wire gen ./cmd/server/ && go build ./... && go test ./...

# Phase 2
cd payment && wire gen ./cmd/server/ && go build ./... && go test ./...
cd order && wire gen ./cmd/server/ && go build ./... && go test ./...

# Phase 3
cd promotion && wire gen ./cmd/server/ && go build ./... && go test ./...
cd shipping && wire gen ./cmd/server/ && go build ./... && go test ./...
```

---

## 📝 Commit Format

```
Phase 1:
feat(common): add Money protobuf type and decimal money package
- feat(proto): add common/proto/v1/money.proto (C2 string decimal)
- feat(money): add GORM Scanner/Valuer, JSON marshal, proto helpers
- refactor(pricing): migrate float64 → money.Money in models and calculation
Closes: AGENT-22 Phase 1

Phase 2:
refactor(payment): migrate float64 → money.Money with gateway fixes
- fix(stripe): replace float64(cents)/100 with money.FromCents
- fix(vnpay): replace float64 division with money.FromCents
- feat(order): add Money proto fields with dual-write backward compat
Closes: AGENT-22 Phase 2

Phase 3:
refactor(promotion,shipping): complete float64 → money.Money migration
Closes: AGENT-22 Phase 3
```

---

## 📊 Summary

| Phase | Services | Tasks | Effort |
|-------|----------|-------|--------|
| 1 - Foundation | `common`, `pricing` | 3 tasks (proto, package, pricing) | 3 days |
| 2 - Critical Path | `payment`, `order` | 2 tasks (gateway fix, 22 proto fields) | 4 days |
| 3 - Remaining | `promotion`, `shipping`, frontend | 4 tasks | 4 days |
| **Total** | **6 services + 2 frontends** | **9 tasks** | **~11 days** |

**Key Constraint**: Zero breaking API changes via protobuf field evolution (dual-write deprecated + new).

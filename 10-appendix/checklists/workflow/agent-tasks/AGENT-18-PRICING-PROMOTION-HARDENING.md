# AGENT-18: Pricing & Promotion Service Hardening (10-Round Review Findings)

**Assignee:** Agent 18  
**Service:** Pricing & Promotion Services  
**Status:** BACKLOG

## 📝 Objective
Resolve P0 (Critical), P1 (High), and P2 (Nice to Have) issues identified during the 10-Round Meeting Review for the Pricing and Promotion services. This hardening task focuses on massive gRPC bottlenecks, missing outbox atomicity, unoptimized DB queries, and boundary conversions.

---

## 🚩 P0 - Critical Issues (Blocking)

### 1. Massive N+1 gRPC Bottleneck in `BulkCalculatePrice` (Performance & Resilience)
- **Service:** Pricing
- **File:** `pricing/internal/biz/calculation/calculation.go`
- **Method:** `BulkCalculatePrice` -> `CalculatePrice` -> `dynamicPricing.ApplyDynamicPricing`
- **Issue:** `BulkCalculatePrice` takes a list of items and spawns goroutines to process them concurrently. Each item triggers dynamic pricing, which calls `warehouseClient.GetStock` (gRPC) synchronously. A 100-item cart triggers 100 separate network requests to the Warehouse Service, causing severe latency spikes.
- **Action:** 
  1. Refactor dynamic pricing execution in bulk contexts to aggregate product IDs/SKUs and make a *single* batch gRPC call to the Warehouse Service (e.g., using a bulk `GetStocks` endpoint if available, or caching).
  2. Map the results in-memory before applying dynamic pricing rules.
- **Validation:** 
  - `go test -v -run TestBulkCalculatePrice ./pricing/internal/biz/calculation`

---

## 🟡 P1 - High Priority

### 2. `TriggerDynamicPricingForStockUpdate` Missing Outbox (Resilience)
- **Service:** Pricing
- **File:** `pricing/internal/biz/dynamic/dynamic_pricing.go`
- **Method:** `TriggerDynamicPricingForStockUpdate`
- **Issue:** When stock changes trigger a dynamic price update, the service writes the new price to the DB (`s.priceRepo.Update(ctx, &newPrice)`) and then immediately calls `s.eventPublisher.PublishEvent(ctx, ...)` to publish `PriceUpdatedEvent`. This is not wrapped in a database transaction with the outbox pattern. If Dapr drops the event, downstream services permanently lose the price update.
- **Action:** 
  1. Inject `OutboxRepo` (and `TransactionManager` if needed) into `DynamicPricingService`.
  2. Wrap the DB update and event publishing in a transaction using `outboxRepo.Save` to ensure guaranteed delivery of `PriceUpdatedEvent`.
- **Validation:** 
  - `go test -v -run TestTriggerDynamicPricingForStockUpdate ./pricing/internal/biz/dynamic`

### 3. N+1 DB Writes in `ReleasePromotionUsage` (Performance)
- **Service:** Promotion
- **File:** `promotion/internal/biz/promotion_usecase.go`
- **Method:** `ReleasePromotionUsage`
- **Issue:** After updating usage statuses to "cancelled", it loops over all `usages` and repeatedly calls `uc.couponRepo.DecrementUsage(ctx, *usage.CouponID)` one-by-one inside the database transaction. For orders with multiple coupons, this results in N+1 sequential DB writes inside an active lock.
- **Action:** 
  1. Collect all `CouponID`s that need decrementing.
  2. Implement a `BatchDecrementUsage` method in `CouponRepo` to update them in a single SQL query, or group by Coupon ID to minimize queries.
- **Validation:** 
  - `go test -v -run TestReleasePromotionUsage ./promotion/internal/biz`

---

## 🔵 P2 - Nice to Have

### 4. Float64/Money Interface Boundaries (Technical Debt)
- **Service:** Pricing
- **Files:** `pricing/internal/biz/calculation/calculation.go` & `dynamic_pricing.go`
- **Issue:** The `DynamicPricingInterface` and `TaxUsecase` accept and return plain `float64` values, requiring constant conversion back and forth with `money.Money`. This boundary conversion introduces risk of precision loss.
- **Action:** 
  1. Migrate `DynamicPricingInterface` and `TaxUsecase` method signatures to accept and return `money.Money` structs natively.
- **Validation:** 
  - Sub-packages build and tests pass successfully.

---

## ✅ ACCEPTANCE CRITERIA
- [ ] `BulkCalculatePrice` does not trigger N+1 synchronous gRPC calls to the Warehouse Service.
- [ ] `PriceUpdatedEvent` in Dynamic Pricing is published durably via the Outbox pattern.
- [ ] `ReleasePromotionUsage` avoids N+1 coupon decrements in the database transaction.
- [ ] Code passes all tests and linting (`golangci-lint run ./pricing/...` & `golangci-lint run ./promotion/...`).

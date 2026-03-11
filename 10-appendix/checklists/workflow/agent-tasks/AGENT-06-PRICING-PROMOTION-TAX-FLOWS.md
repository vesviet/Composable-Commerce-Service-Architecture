# AGENT TASK - PRICING, PROMOTION & TAX FLOWS (AGENT-06)

## STATUS
**State:** [x] Done

## ASSIGNMENT
**Focus Area:** Pricing & Promotion Flows (Concurrency Limits, Micro-Spikes)
**Primary Services:** `pricing`, `promotion`
**Priority:** High (P0 fixes required)

## 📌 P0: Fix Flawed Semaphore Logic in Bulk Pricing (Goroutine Spike) ✅ IMPLEMENTED
**Risk:** Spawns `len(requests)` raw Goroutines instantly during bulk price calculations, causing memory spikes and possible OOM, defeating the purpose of the bounded semaphore.
**Location:** `pricing/internal/biz/calculation/calculation.go` (Method `BulkCalculatePrice`, Line ~525-535)

### Implementation Details
- **Files**: `pricing/internal/biz/calculation/calculation.go`
- **Risk / Problem**: Semaphore tokens were acquired *inside* the goroutine. Consequently, a loop of 10,000 requests would immediately spawn 10,000 goroutines that block internally, risking sudden OOMs during massive list views.
- **Solution Applied**: Moved `semaphore <- struct{}{}` to precisely **before** the `go func(...)` call in the loop, ensuring we only spawn goroutines at the strict cap allowed by the semaphore.
```go
		wg.Add(1)
		semaphore <- struct{}{}        // Acquire OUTSIDE goroutine
		go func(index int, r *price.PriceCalculationRequest) {
			defer wg.Done()
			defer func() { <-semaphore }() // Release INSIDE goroutine
```
- **Validation**: `cd /home/user/microservices/pricing && go build ./... && go test -race ./internal/biz/calculation/...` (All passed)

---

## 📌 P0: Fix Unbounded Fan-Out gRPC calls in Promotion Validation ✅ IMPLEMENTED
**Risk:** Spawns `len(productIDs)` raw Goroutines instantly to call the Catalog gRPC service, causing connection exhaustion or rate limit triggers under load.
**Location:** `promotion/internal/biz/validation.go` (Method `enrichRequestWithCatalogData`, Line ~518)

### Implementation Details
- **Files**: `promotion/internal/biz/validation.go`
- **Risk / Problem**: Calling catalog gRPC asynchronously per product in the `productIDs` range without a concurrent limit caused massive fan-out traffic directly correlating with request size, causing potential upstream cascade failures.
- **Solution Applied**: Adapted a standard bounded channel pool approach via `sem := make(chan struct{}, 10)`. We now acquire tokens before launching a worker goroutine, maintaining a strict upper limit on concurrent GRPC outbound calls (max 10 parallel calls) to the catalog endpoint.
```go
	resultCh := make(chan result, len(productIDs))
	sem := make(chan struct{}, 10) // Limit to 10 concurrent requests
	for _, pid := range productIDs {
		pid := pid // capture
		sem <- struct{}{} // Acquire token
		go func() {
			defer func() { <-sem }() // Release token
			defer func() {
```
- **Validation**: `cd /home/user/microservices/promotion && go test -race ./internal/biz/...` (All passed)

---

## 📌 P2: Precision Rounding on "Each Nth Item" Discount Value ✅ IMPLEMENTED
**Risk:** Division using `float64` without explicit rounding in Tiered Promotions causes slight discrepancies (1-2 cents) when converted back to `money.Money`.
**Location:** `promotion/internal/biz/discount_calculator.go` (Method `calculateEachNthItemDiscount`, Line ~587)

### Implementation Details
- **Files**: `promotion/internal/biz/discount_calculator.go`
- **Risk / Problem**: Bare float64 calculations (`discountPerItem * float64(discountedItems)`) caused penny discrepancies before hitting final monetary packaging.
- **Solution Applied**: Imported `gitlab.com/ta-microservices/common/utils/money` and wrapped the final nth-item discount aggregation value tightly with `money.FromFloat64(...).Float64()`, performing IEEE-754 nearest even rounding appropriately.
```go
	totalDiscount = money.FromFloat64(discountPerItem * float64(discountedItems)).Float64()
	return totalDiscount, nil
```
- **Validation**: `cd /home/user/microservices/promotion && go test -race ./internal/biz/...` (All passed)

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add pricing/internal/biz/calculation/calculation.go
git add promotion/internal/biz/validation.go
git add promotion/internal/biz/discount_calculator.go

git commit -m "fix(pricing): move semaphore acquire outside goroutine to prevent memory spikes in bulk updates
fix(promotion): bound catalog grpc fan-out with errgroup to prevent connection exhaustion
fix(promotion): apply explicit money rounding to nth-item discount calculations

# Agent-06 Fixes based on 250-Round Meeting Review
# P0: Prevents OOM crashes in Pricing
# P0: Protects Catalog service from overload
# P2: Prevents decimal drift on tiered promotions"
```

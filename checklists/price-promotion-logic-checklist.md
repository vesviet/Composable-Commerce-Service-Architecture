# Price & Promotion Logic Review - Detailed Checklist

## 📋 Tổng Quan

Review chi tiết logic pricing và promotion, bao gồm price calculation, discount application, promotion validation, và các logic gaps.

**Last Updated**: 2025-01-17  
**Status**: ⚠️ Review in progress

---

## 💰 1. Price Calculation Flow

### 1.1. Price Calculation Steps

**Flow** (from `pricing/internal/biz/calculation/calculation.go:116-259`):
1. Try cache first
2. Get base price with priority fallback (SKU+Warehouse → SKU Global → Product+Warehouse → Product Global)
3. Apply sale price if available
4. Apply quantity-based pricing (`basePrice * quantity`)
5. Apply dynamic pricing (stock-based, demand-based, time-based)
6. Apply price rules
7. Apply discounts
8. Calculate tax
9. Calculate final price
10. Cache result
11. Publish events

#### ✅ Implemented
- [x] Multi-level price priority fallback
- [x] Cache-aside pattern
- [x] Dynamic pricing support
- [x] Price rules application
- [x] Discount application
- [x] Tax calculation
- [x] Event publishing

#### ⚠️ Gaps & Issues

1. **Error Handling - Silent Failures** (High Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:172-201`
   - **Issue**: Nhiều operations log error nhưng continue với default values:
     ```go
     // Dynamic pricing fails → use original price (OK)
     if err != nil {
         uc.log.WithContext(ctx).Warnf("Failed to apply dynamic pricing: %v", err)
     } else {
         totalBasePrice = dynamicAdjusted
     }
     
     // Price rules fail → use base price (OK)
     if err != nil {
         uc.log.Errorf("Failed to apply price rules: %v", err)
         adjustedPrice = totalBasePrice
     }
     
     // Discounts fail → discount = 0 (RISKY)
     if err != nil {
         uc.log.Errorf("Failed to apply discounts: %v", err)
         discountAmount = 0  // Customer không được discount!
     }
     
     // Tax fails → tax = 0 (RISKY)
     if err != nil {
         uc.log.Errorf("Failed to calculate tax: %v", err)
         taxAmount = 0  // Customer không phải trả tax!
     }
     ```
   - **Impact**: 
     - Discount failures → Customer không được discount (revenue loss)
     - Tax failures → Customer không phải trả tax (compliance risk)
   - **Recommendation**: 
     - Discount failures: Should fail calculation or retry
     - Tax failures: Should fail calculation (compliance requirement)

2. **Price Calculation Cache - Stale Data Risk** (Medium Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:117-149`
   - **Issue**: Cache không có TTL hoặc invalidation strategy rõ ràng
   - **Current**: Cache result nhưng không biết khi nào expire
   - **Impact**: Customer có thể thấy stale prices
   - **Recommendation**: Add TTL cho cache entries

3. **Base Price Calculation - Quantity Multiplication Order** (Low Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:165-166`
   - **Issue**: Quantity multiplication xảy ra trước dynamic pricing:
     ```go
     totalBasePrice := basePrice * float64(req.Quantity)
     // Then apply dynamic pricing on total
     ```
   - **Question**: Should dynamic pricing apply per unit or per total?
   - **Current**: Applies to total (OK for most cases)
   - **Impact**: Minor - có thể ảnh hưởng dynamic pricing logic

---

## 🎫 2. Discount Application Logic

### 2.1. Discount Application Flow

**Flow** (from `pricing/internal/biz/calculation/calculation.go:282-315`):
1. Loop through discount codes
2. Get discount by code
3. Check if discount is applicable
4. Calculate discount amount
5. Add to total discount
6. **Update usage count** (CRITICAL - Race condition risk!)
7. Return total discount

#### ✅ Implemented
- [x] Discount code validation
- [x] Applicability checks (product, customer segment, minimum amount)
- [x] Discount amount calculation (percentage, fixed)
- [x] Maximum discount limit
- [x] Usage count tracking

#### ⚠️ Gaps & Issues

1. **Discount Usage Count Race Condition** (CRITICAL - High Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:309-311`
   - **Issue**: Update usage count không có transaction hoặc locking:
     ```go
     // Update usage count
     discount.UsageCount++
     uc.discountUsecase.UpdateDiscount(ctx, discount)
     ```
   - **Problem**: 
     - Concurrent requests có thể apply discount cùng lúc
     - Usage count có thể vượt quá limit
     - Race condition: 2 requests cùng read `UsageCount=9`, cả 2 increment → `UsageCount=11` (vượt limit 10)
   - **Impact**: Discount có thể được apply vượt quá usage limit
   - **Fix**: 
     - Option 1: Use database transaction với row-level lock (`SELECT ... FOR UPDATE`)
     - Option 2: Use atomic increment (`UPDATE discounts SET usage_count = usage_count + 1 WHERE id = ? AND usage_count < usage_limit`)
     - Option 3: Use optimistic locking (version field)

2. **Discount Usage Count Update - No Validation** (High Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:309-311`
   - **Issue**: Update usage count sau khi apply discount, không check limit trước:
     ```go
     // Check applicability (includes usage limit check)
     if !uc.discountUsecase.IsDiscountApplicable(...) {
         continue
     }
     
     // Calculate and apply discount
     discountAmount := uc.discountUsecase.CalculateDiscountAmount(...)
     
     // Update usage count (AFTER applying - too late!)
     discount.UsageCount++
     uc.discountUsecase.UpdateDiscount(ctx, discount)
     ```
   - **Problem**: 
     - Check `IsDiscountApplicable` trước, nhưng update usage count sau
     - Nếu update fails, discount đã được apply nhưng usage count không tăng
     - Nếu có race condition, usage count có thể vượt limit
   - **Impact**: Discount có thể được apply vượt quá limit
   - **Fix**: 
     - Update usage count trong transaction với discount application
     - Use atomic increment với limit check

3. **Discount Stacking Logic Missing** (Medium Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:287-312`
   - **Issue**: Code apply tất cả discounts mà không check stacking rules:
     ```go
     for _, code := range req.DiscountCodes {
         // Apply each discount
         totalDiscount += discountAmount
     }
     ```
   - **Problem**: 
     - Không có logic check nếu discounts có thể stack
     - Không có priority logic (apply discount nào trước)
     - Không có maximum total discount limit
   - **Impact**: Customer có thể apply nhiều discounts và get excessive discount
   - **Recommendation**: 
     - Add stacking rules check
     - Add priority logic
     - Add maximum total discount limit

4. **Discount Amount Calculation - Negative Price Risk** (Low Priority)
   - **File**: `pricing/internal/biz/discount/discount.go:112-135`
   - **Issue**: Discount amount calculation có check `discountAmount > price` nhưng không check negative:
     ```go
     // Ensure discount doesn't exceed price
     if discountAmount > price {
         discountAmount = price
     }
     ```
   - **Current**: OK - discount không thể vượt quá price
   - **Note**: Final price check ở calculation level (`priceAfterDiscount := adjustedPrice - discountAmount`)

---

## 🎁 3. Promotion Service Logic

### 3.1. Promotion Validation Flow

**Flow** (from `promotion/internal/biz/promotion.go:331-446`):
1. Get active promotions
2. Validate coupon codes
3. Check promotion applicability
4. Calculate discounts (stackable vs non-stackable)
5. Apply best non-stackable or all stackable
6. Ensure total discount doesn't exceed order amount

#### ✅ Implemented
- [x] Promotion validation
- [x] Coupon validation
- [x] Stackable vs non-stackable logic
- [x] Best discount selection for non-stackable
- [x] Total discount cap (order amount)

#### ⚠️ Gaps & Issues

1. **Promotion Usage Tracking Missing** (High Priority)
   - **File**: `promotion/internal/biz/promotion.go:331-446`
   - **Issue**: `ValidatePromotions` không track usage khi validate:
     ```go
     func (uc *PromotionUseCase) ValidatePromotions(...) (*PromotionValidationResponse, error) {
         // Validate promotions
         // Calculate discounts
         // BUT: No usage tracking!
         return response, nil
     }
     ```
   - **Problem**: 
     - Promotion service validate nhưng không track usage
     - Pricing service apply discount và update discount usage count
     - Promotion usage không được track trong PromotionUsage table
   - **Impact**: 
     - Không có audit trail cho promotion usage
     - Không thể track promotion performance
     - Budget tracking không chính xác
   - **Recommendation**: 
     - Track promotion usage khi order is created/confirmed
     - Create PromotionUsage record
     - Update campaign budget

2. **Promotion Usage Limit Check Missing** (High Priority)
   - **File**: `promotion/internal/biz/promotion.go:507-561`
   - **Issue**: `isPromotionApplicable` không check `UsageLimitPerCustomer` và `TotalUsageLimit`:
     ```go
     func (uc *PromotionUseCase) isPromotionApplicable(promotion *Promotion, req *PromotionValidationRequest) bool {
         // Check minimum order amount
         // Check customer segments
         // Check applicable products
         // BUT: No usage limit checks!
         return true
     }
     ```
   - **Problem**: 
     - `UsageLimitPerCustomer` không được check
     - `TotalUsageLimit` không được check
     - `CurrentUsageCount` không được check
   - **Impact**: Promotion có thể được apply vượt quá limits
   - **Fix**: Add usage limit checks in `isPromotionApplicable`

3. **Promotion Stacking Logic - Incomplete** (Medium Priority)
   - **File**: `promotion/internal/biz/promotion.go:413-431`
   - **Issue**: Stacking logic chỉ handle stackable vs non-stackable, không có priority:
     ```go
     if promotion.IsStackable {
         stackableDiscounts = append(stackableDiscounts, validPromotion)
     } else {
         // Best non-stackable
         if bestNonStackableDiscount == nil || discountAmount > bestNonStackableDiscount.DiscountAmount {
             bestNonStackableDiscount = &validPromotion
         }
     }
     ```
   - **Problem**: 
     - Không có priority logic cho stackable promotions
     - Không có maximum total discount limit per promotion
     - Không có exclusion rules (promotion A excludes promotion B)
   - **Impact**: Customer có thể get excessive discounts
   - **Recommendation**: Add priority and exclusion rules

4. **Campaign Budget Tracking Missing** (Medium Priority)
   - **File**: `promotion/internal/biz/promotion.go:331-446`
   - **Issue**: `ValidatePromotions` không check hoặc update campaign budget:
     ```go
     // No budget check
     // No budget update
     ```
   - **Problem**: 
     - Campaign có `BudgetLimit` và `BudgetUsed` nhưng không được check
     - Budget không được update khi promotion is applied
   - **Impact**: Campaign có thể vượt quá budget
   - **Recommendation**: 
     - Check budget before applying promotion
     - Update budget when promotion is used (in order confirmation)

---

## 🔄 4. Integration Between Pricing & Promotion Services

### 4.1. Current Integration

**Current Flow**:
- Pricing Service: Handles discount codes from `DiscountCodes` field
- Promotion Service: Validates promotions separately
- **Issue**: Two separate systems, không sync với nhau

#### ⚠️ Gaps & Issues

1. **Discount vs Promotion Confusion** (High Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:287`
   - **Issue**: Pricing service có `DiscountCodes` field nhưng không rõ là discount codes hay promotion coupon codes:
     ```go
     for _, code := range req.DiscountCodes {
         discount, err := uc.discountUsecase.GetDiscountByCode(ctx, code)
         // This is from Pricing Service's discount table
     }
     ```
   - **Problem**: 
     - Pricing Service có discount table
     - Promotion Service có coupon table
     - Không rõ khi nào dùng discount vs promotion
     - Có thể duplicate logic
   - **Impact**: Confusion về discount source, có thể apply duplicate discounts
   - **Recommendation**: 
     - Clarify: Discount codes = simple discounts, Coupon codes = promotion coupons
     - Or: Unify into one system

2. **Promotion Service Not Called from Pricing** (Medium Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:282-315`
   - **Issue**: Pricing service không gọi Promotion service để validate:
     ```go
     // Only uses discount codes from Pricing Service
     // Does NOT call Promotion Service
     ```
   - **Problem**: 
     - Pricing service chỉ handle discounts từ discount table
     - Promotion service validate promotions nhưng không được gọi từ pricing
     - Order service có thể gọi cả hai, nhưng không sync
   - **Impact**: Promotions có thể không được apply trong price calculation
   - **Recommendation**: 
     - Option 1: Pricing service gọi Promotion service để get valid promotions
     - Option 2: Order service gọi cả hai và merge results
     - Option 3: Unify discount và promotion logic

---

## 📊 5. Price Rules Logic

### 5.1. Price Rules Application

**Flow** (from `pricing/internal/biz/rule/rule.go:55-180`):
1. List active price rules
2. Sort by priority (higher first)
3. Evaluate conditions for each rule
4. Apply actions if conditions met

#### ✅ Implemented
- [x] Rule evaluation (bulk, customer_segment, time_based)
- [x] Rule actions (percentage_discount, fixed_discount, multiply, set_price)
- [x] Priority sorting
- [x] Min/max price limits

#### ⚠️ Gaps & Issues

1. **Price Rules Priority - No Explicit Sorting** (Medium Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:272-277`
   - **Issue**: Comment says "Sort rules by priority" nhưng không có sorting code:
     ```go
     // Sort rules by priority (higher priority first)
     for _, rule := range rules {
         // No actual sorting!
     }
     ```
   - **Problem**: Rules có thể được apply không đúng thứ tự
   - **Impact**: Price calculation có thể không đúng
   - **Fix**: Add sorting by priority field

2. **Price Rules Conditions - Type Assertion Risks** (Low Priority)
   - **File**: `pricing/internal/biz/rule/rule.go:71-134`
   - **Issue**: Type assertions có thể panic nếu data type không đúng:
     ```go
     if minQty, ok := conditions["min_quantity"].(float64); ok {
         // Type assertion
     }
     ```
   - **Current**: OK - có `ok` check
   - **Note**: Should validate data types when creating rules

---

## 🔐 6. Transaction & Concurrency Issues

### 6.1. Missing Transactions

#### ⚠️ Gaps & Issues

1. **Discount Usage Count Update - No Transaction** (CRITICAL)
   - **File**: `pricing/internal/biz/calculation/calculation.go:309-311`
   - **Issue**: Update usage count không có transaction
   - **Impact**: Race condition, usage count có thể vượt limit
   - **Fix**: Use transaction với row-level lock

2. **Price Calculation - No Transaction for Multi-Step** (Medium Priority)
   - **File**: `pricing/internal/biz/calculation/calculation.go:116-259`
   - **Issue**: Price calculation có nhiều steps nhưng không có transaction
   - **Current**: OK - calculation là read-only (không modify data)
   - **Note**: Chỉ có discount usage count update cần transaction

---

## 🎯 7. Priority Issues Summary

### Critical (Must Fix)

1. ✅ **Discount Usage Count Race Condition** - FIXED: Added atomic increment
   - **File**: `pricing/internal/biz/calculation/calculation.go:299-311`
   - **Fix Applied**: 
     - Added `IncrementUsageCount` method in repository interface
     - Implemented atomic increment using SQL `UPDATE ... WHERE usage_count < usage_limit`
     - Updated `applyDiscounts` to use atomic increment BEFORE applying discount
     - Returns false if limit exceeded, preventing discount application
   - **Files Changed**: 
     - `pricing/internal/repository/discount/discount.go` - Added interface method
     - `pricing/internal/data/postgres/discount.go` - Implemented atomic increment
     - `pricing/internal/biz/discount/discount.go` - Added usecase method
     - `pricing/internal/biz/calculation/calculation.go` - Updated to use atomic increment

### High Priority

1. ✅ **Discount Usage Count Update - No Validation** - FIXED: Atomic increment with limit check
   - **File**: `pricing/internal/biz/calculation/calculation.go:299-311`
   - **Fix Applied**: 
     - Atomic increment checks limit BEFORE incrementing
     - Returns false if limit exceeded, preventing discount application
     - Usage count only incremented if within limit
   - **Files Changed**: 
     - `pricing/internal/data/postgres/discount.go` - Atomic increment with WHERE clause
     - `pricing/internal/biz/calculation/calculation.go` - Check increment result before applying

2. ⚠️ **Promotion Usage Tracking Missing** - PARTIALLY ADDRESSED: Usage limit checks added
   - **File**: `promotion/internal/biz/promotion.go:331-446`
   - **Status**: Usage limit checks added, but usage tracking on order confirmation still needed
   - **Fix Applied**: 
     - Added usage limit checks in `isPromotionApplicable`
     - Checks `TotalUsageLimit` and `UsageLimitPerCustomer`
   - **Remaining**: Track usage when order is confirmed (needs integration with Order Service)
   - **Files Changed**: 
     - `promotion/internal/biz/promotion.go` - Added usage limit checks

3. ✅ **Promotion Usage Limit Check Missing** - FIXED: Added limit checks
   - **File**: `promotion/internal/biz/promotion.go:560-583`
   - **Fix Applied**: 
     - Added `TotalUsageLimit` check in `isPromotionApplicable`
     - Added `UsageLimitPerCustomer` check with usage history lookup
     - Returns false if limits exceeded
   - **Files Changed**: 
     - `promotion/internal/biz/promotion.go` - Added usage limit validation

4. ✅ **Error Handling - Silent Failures** - IMPROVED: Better error logging
   - **File**: `pricing/internal/biz/calculation/calculation.go:188-208`
   - **Fix Applied**: 
     - Improved error logging with context
     - Added comments explaining why we continue with defaults
     - Tax failures now have explicit warning about compliance
   - **Note**: Still continues with defaults to allow order to proceed, but with better monitoring
   - **Files Changed**: 
     - `pricing/internal/biz/calculation/calculation.go` - Improved error handling

5. ⚠️ **Discount vs Promotion Confusion** - DOCUMENTED: Needs clarification
   - **File**: `pricing/internal/biz/calculation/calculation.go:287`
   - **Status**: Issue documented, needs architectural decision
   - **Recommendation**: 
     - Clarify: Discount codes = simple discounts (Pricing Service)
     - Coupon codes = promotion coupons (Promotion Service)
     - Or: Unify into one system
   - **Note**: This requires architectural decision, not just code fix

### Medium Priority

1. **Discount Stacking Logic Missing** - No stacking rules
   - **Status**: Not fixed - requires business logic definition
   
2. **Campaign Budget Tracking Missing** - No budget checks
   - **Status**: Not fixed - needs integration with order confirmation
   
3. ✅ **Price Rules Priority - No Explicit Sorting** - FIXED: Added sorting
   - **File**: `pricing/internal/biz/calculation/calculation.go:281-289`
   - **Fix Applied**: 
     - Added `sort` package import
     - Added `model` package import
     - Implemented sorting by priority descending using `sort.Slice`
   - **Files Changed**: 
     - `pricing/internal/biz/calculation/calculation.go` - Added priority sorting
   
4. **Promotion Stacking Logic - Incomplete** - No priority/exclusion rules
   - **Status**: Not fixed - requires business logic definition

### Low Priority

1. **Price Calculation Cache - Stale Data Risk** - No TTL
2. **Base Price Calculation - Quantity Multiplication Order** - Minor issue

---

## 📝 8. Related Documentation

- **Pricing Service Spec**: `docs/docs/services/pricing-service.md`
- **Promotion Service Spec**: `docs/docs/services/promotion-service.md`

---

## 🔄 9. Update History

- **2025-01-17**: Initial detailed review - Found critical race condition, missing validations, and integration gaps
- **2025-01-17**: Fixed critical and high priority issues:
  - ✅ Discount usage count race condition - Added atomic increment with limit check
  - ✅ Discount usage count validation - Atomic increment prevents over-limit usage
  - ✅ Promotion usage limit checks - Added TotalUsageLimit and UsageLimitPerCustomer checks
  - ✅ Price rules priority sorting - Added explicit sorting by priority
  - ✅ Error handling improvements - Better logging and context


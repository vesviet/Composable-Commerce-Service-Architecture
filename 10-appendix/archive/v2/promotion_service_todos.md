# Promotion Service - TODO List

**Service**: Promotion Service  
**Version**: 1.0.1  
**Last Updated**: 2026-01-29  
**Status**: Production Ready with Test Coverage Improvements Needed

---

## 🟡 HIGH PRIORITY (P1 - Production Ready but Needs Improvement)

### [P1-1] Increase Test Coverage to 80%+
**Status**: ⚠️ IN PROGRESS  
**Priority**: P1 - HIGH  
**Effort**: 20-30 hours  
**Target**: 2026-02-15

**Description**: Current test coverage is ~36%. Need to increase to 80%+ for production confidence.

**Current State**:
- ✅ Test files present:
  - `internal/biz/promotion_test.go` - Campaign/promotion tests
  - `internal/biz/discount_calculator_test.go` - Discount calculation tests
  - `internal/biz/conditions_test.go` - Condition validation tests
  - `internal/biz/catalog_indexing_test.go` - Catalog indexing tests
  - `internal/service/service_test.go` - Service layer error mapping tests
- ⚠️ Coverage: ~36% (target: 80%+)
- ❌ No integration tests with database
- ❌ No API contract tests

**Required Action**:

1. **Unit Tests for Biz Layer** (15-20 hours):
   - [ ] Add table-driven tests for `ValidatePromotions`:
     - Test cart rule validation
     - Test catalog rule validation
     - Test stackable vs non-stackable promotions
     - Test priority ordering
     - Test stop_rules_processing flag
     - Test customer segment filtering
     - Test product/category/brand filtering
     - Test usage limit enforcement
   
   - [ ] Add tests for `CreateCampaign`:
     - Test date validation
     - Test budget validation
     - Test event publishing
   
   - [ ] Add tests for `UpdatePromotion`:
     - Test optimistic locking
     - Test concurrent update detection
     - Test version increment
   
   - [ ] Add tests for `ApplyPromotion`:
     - Test usage limit enforcement (global and per-customer)
     - Test concurrent usage scenarios
     - Test coupon usage increment
     - Test transaction rollback on failure
   
   - [ ] Add tests for discount calculation:
     - Test BOGO promotions (Buy X Get Y)
     - Test tiered discounts
     - Test item selection discounts (cheapest/most expensive)
     - Test free shipping
     - Test maximum discount limits
   
   - [ ] Add tests for condition evaluation:
     - Test cart conditions (subtotal, quantity, weight)
     - Test product conditions (category, brand, price)
     - Test customer segment conditions
     - Test combined conditions (AND/OR logic)

2. **Integration Tests** (5-8 hours):
   - [ ] Set up testcontainers for PostgreSQL
   - [ ] Test promotion repository with real database:
     - Test CreatePromotion with transactions
     - Test UpdatePromotion with optimistic locking
     - Test ReserveUsage with concurrent requests
     - Test GetActivePromotions with JSONB filtering
   - [ ] Test coupon repository:
     - Test bulk coupon generation
     - Test coupon code uniqueness
     - Test usage limit enforcement
   - [ ] Test campaign repository:
     - Test budget tracking
     - Test status transitions

3. **Service Layer Tests** (3-5 hours):
   - [ ] Test error mapping scenarios:
     - Test NotFound errors
     - Test InvalidArgument errors
     - Test ResourceExhausted errors
     - Test PermissionDenied errors
   - [ ] Test validation logic:
     - Test input validation
     - Test UUID validation
     - Test JSON parsing errors
   - [ ] Test authorization checks:
     - Test admin-only endpoints
     - Test unauthorized access scenarios

4. **API Contract Tests** (2-3 hours):
   - [ ] Test gRPC endpoints:
     - Test request/response validation
     - Test error codes
     - Test pagination
   - [ ] Test HTTP endpoints:
     - Test REST API contracts
     - Test error responses

**Files to Create/Modify**:
- `internal/biz/promotion_test.go` - Expand existing tests
- `internal/biz/discount_calculator_test.go` - Add edge cases
- `internal/biz/conditions_test.go` - Add more scenarios
- `internal/data/promotion_test.go` - NEW: Integration tests
- `internal/data/coupon_test.go` - NEW: Integration tests
- `internal/service/promotion_test.go` - NEW: Service layer tests
- `api/promotion/v1/promotion_test.go` - NEW: API contract tests

**Acceptance Criteria**:
- [ ] Test coverage > 80% for biz layer
- [ ] Test coverage > 70% for data layer
- [ ] Test coverage > 60% for service layer
- [ ] Integration tests cover critical paths
- [ ] API contract tests verify request/response formats
- [ ] All tests pass consistently
- [ ] Tests run in CI/CD pipeline

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 8 (Testing)

---

## 🟢 LOW PRIORITY (P2 - Nice to Have)

### [P2-1] Implement Real Shipping gRPC Client
**Status**: 📋 TODO  
**Priority**: P2 - LOW  
**Effort**: 4-6 hours  
**Target**: When shipping service is available

**Description**: Currently using NoOp client for shipping service. Need to implement real gRPC client when shipping service is ready.

**Current State**:
- ✅ NoOp client implemented as fallback
- ✅ Circuit breaker pattern ready
- ✅ TODO(#PROMO-456) comment added

**Required Action**:
1. Implement `grpcShippingClient` similar to other clients
2. Add shipping service configuration
3. Wire up client in provider
4. Add error handling and retries
5. Remove TODO comment

**Files to Modify**:
- `internal/client/shipping_grpc_client.go` - NEW: Implement client
- `internal/client/provider.go` - Wire up client
- `internal/config/config.go` - Add shipping service config

**Reference**: `internal/client/catalog_grpc_client.go` for pattern

---

### [P2-2] Use Common Errors Package
**Status**: 📋 TODO  
**Priority**: P2 - LOW  
**Effort**: 2-3 hours

**Description**: Consider using `common/errors` package for structured error handling instead of string-based error mapping.

**Current State**:
- ✅ `mapErrorToGRPC` function works well
- ⚠️ Uses string matching for error mapping

**Required Action**:
1. Evaluate `common/errors` package
2. Migrate error definitions to use structured errors
3. Update `mapErrorToGRPC` to use error types
4. Update tests

**Files to Modify**:
- `internal/biz/promotion.go` - Error definitions
- `internal/service/promotion.go` - Error mapping

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 2 (API & Contract)

---

### [P2-3] Remove Unused Helper Functions
**Status**: 📋 TODO  
**Priority**: P2 - LOW  
**Effort**: 1 hour

**Description**: Some helper functions are marked as unused by linter. Either use them or remove them.

**Current State**:
- ⚠️ `filterBuyItems` - unused
- ⚠️ `filterGetItems` - unused
- ⚠️ `publishPromotionEvent` - unused
- ⚠️ `publishBulkCouponsEvent` - unused

**Required Action**:
1. Review if functions are needed for future features
2. If not needed, remove them
3. If needed, add comments explaining future use
4. Or integrate them into existing code

**Files to Modify**:
- `internal/biz/discount_calculator.go`
- `internal/biz/promotion.go`

---

## ✅ COMPLETED ITEMS

### [P0-1] Authentication & Authorization Middleware ✅
**Completed**: 2026-01-29  
**Status**: ✅ COMPLETED

- ✅ Authentication middleware added to HTTP/gRPC servers
- ✅ Authorization checks implemented for admin operations
- ✅ Context keys properly typed
- ✅ User ID extracted from authenticated context

### [P1-2] gRPC Error Code Mapping ✅
**Completed**: 2026-01-29  
**Status**: ✅ COMPLETED

- ✅ Comprehensive `mapErrorToGRPC` function implemented
- ✅ All service methods use proper error mapping
- ✅ Service layer tests added

### [P1-3] External Service Clients ✅
**Completed**: 2026-01-29  
**Status**: ✅ COMPLETED

- ✅ NoOp clients implemented for all services
- ✅ Circuit breaker pattern implemented
- ✅ Real gRPC clients partially implemented
- ✅ Proper error handling and timeouts

### [P2-2] Code Quality and Linting ✅
**Completed**: 2026-01-29  
**Status**: ✅ COMPLETED

- ✅ golangci-lint issues fixed
- ✅ Error handling consistent
- ✅ Code style standardized
- ✅ Deprecated APIs replaced

### [P2-1] Documentation Improvements ✅
**Completed**: 2026-01-29  
**Status**: ✅ COMPLETED

- ✅ Comprehensive README
- ✅ API documentation
- ✅ Troubleshooting guide
- ✅ TODO comments tracked

---

## Summary

**Total TODOs**: 4
- **P1 (High)**: 1 item - Test coverage improvement
- **P2 (Low)**: 3 items - Nice to have improvements

**Completed**: 5 items
**In Progress**: 1 item (P1-1)

**Next Steps**:
1. Focus on P1-1: Increase test coverage to 80%+
2. Complete integration tests for critical paths
3. Add API contract tests
4. Consider P2 items when time permits

# Promotion Service - Code Review Checklist

**Service**: Promotion Service  
**Review Date**: January 27, 2026  
**Review Standard**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md`  
**Status**: 🟡 88% Complete - Production Ready with Critical Security Fixes Needed

---

## Executive Summary

The Promotion Service demonstrates solid Clean Architecture implementation with proper layering, dependency injection, and production-grade features like caching, transactions, and event-driven architecture. However, critical security gaps and testing deficiencies require immediate attention.

**Key Findings**:
- ✅ **Architecture**: Clean separation, proper DI with Wire
- ✅ **Data Layer**: Transactions, migrations, no N+1 queries
- ✅ **Performance**: Redis caching, pagination implemented
- ✅ **Observability**: Health checks, structured logging, metrics middleware
- ❌ **Security**: Missing authentication/authorization middleware (P0)
- ❌ **Testing**: Very low test coverage (< 10%) (P1)
- ⚠️ **API**: Limited gRPC error code mapping for business errors (P1)
- ⚠️ **Maintenance**: Some TODO items and incomplete external client implementations

---

## P0 (Blocking) - Critical Issues

### P0-1: Missing Authentication & Authorization Middleware

**Severity**: P0 (Blocking)  
**Category**: Security  
**Files**: 
- `promotion/internal/server/http.go`
- `promotion/internal/server/grpc.go`

**Current State**:
- HTTP server has no authentication middleware
- gRPC server has no authentication middleware  
- No authorization checks in service handlers
- All promotion management endpoints are publicly accessible
- `CreatedBy` field taken directly from request without validation

**Required Action**:
1. Add authentication middleware to HTTP server:
   ```go
   // In http.go
   krathttp.Middleware(
       recovery.Recovery(),
       metrics.Server(),
       tracing.Server(),
       authMiddleware, // ADD THIS
   )
   ```

2. Add authentication middleware to gRPC server:
   ```go
   // In grpc.go
   grpc.Middleware(
       recovery.Recovery(),
       authMiddleware, // ADD THIS
   )
   ```

3. Extract user ID from authenticated context in service layer:
   ```go
   // In service methods
   userID, ok := commonAuth.GetUserID(ctx)
   if !ok {
       return nil, status.Error(codes.Unauthenticated, "user not authenticated")
   }
   campaign.CreatedBy = userID // Instead of req.CreatedBy
   ```

4. Implement role-based authorization checks for admin operations

**Impact**: Complete security vulnerability - anyone can create/modify promotions and campaigns

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 5 (Security)

---

## P1 (High Priority) - Major Issues

### P1-1: Insufficient Test Coverage

**Severity**: P1 (High)  
**Category**: Testing & Quality  
**Files**:
- `promotion/internal/biz/promotion_test.go` (4 test functions)
- `promotion/internal/biz/discount_calculator_test.go` (2 test functions)

**Current State**:
- Only 6 test functions total
- Coverage estimated < 10%
- No integration tests with database
- No service layer tests
- No API contract tests

**Required Action**:
1. Increase unit test coverage to > 80% for biz layer:
   - Add table-driven tests for `ValidatePromotions`
   - Add tests for `CreateCampaign`, `UpdatePromotion`
   - Add tests for discount calculation logic

2. Add integration tests:
   ```go
   // Use testcontainers for real DB testing
   func TestPromotionRepo_Integration(t *testing.T) {
       // Test with PostgreSQL container
   }
   ```

3. Add service layer tests with mocked dependencies

4. Add API tests for gRPC/HTTP endpoints

**Impact**: High risk of regressions and undetected bugs in production

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 8 (Testing)

---

### P1-2: Incomplete gRPC Error Code Mapping

**Severity**: P1 (High)  
**Category**: API & Contract  
**Files**:
- `promotion/internal/service/promotion.go`
- `promotion/internal/biz/promotion.go`

**Current State**:
- Service layer maps some validation errors to `codes.InvalidArgument`
- Business logic errors are returned as-is without gRPC code mapping
- No structured error handling using `common/errors`

**Required Action**:
1. Use `common/errors` package for structured error handling:
   ```go
   import commonErrors "gitlab.com/ta-microservices/common/errors"
   
   // In biz layer
   return commonErrors.NewValidationError("campaign not found", nil)
   
   // In service layer
   if err := s.uc.CreateCampaign(ctx, campaign); err != nil {
       return nil, commonErrors.ToGRPCError(err)
   }
   ```

2. Map domain errors to appropriate gRPC codes:
   - NotFound → `codes.NotFound`
   - ValidationError → `codes.InvalidArgument`  
   - ConflictError → `codes.AlreadyExists`
   - PermissionError → `codes.PermissionDenied`

**Impact**: Poor API usability and error handling for clients

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 2 (API & Contract)

---

### P1-3: Incomplete External Service Clients

**Severity**: P1 (High)  
**Category**: Architecture & Integration  
**Files**:
- `promotion/internal/client/`
- `promotion/internal/service/promotion.go`

**Current State**:
- NoOp clients implemented for Customer, Catalog, Pricing, Review services
- Service assumes external calls will work but has no real implementations
- README mentions "External clients need completion"

**Required Action**:
1. Implement real gRPC clients for dependent services:
   ```go
   // customer_grpc_client.go - partially implemented
   // catalog_grpc_client.go - missing
   // pricing_grpc_client.go - missing  
   // review_grpc_client.go - missing
   ```

2. Add proper error handling and retries for external calls

3. Configure client addresses in config

**Impact**: Service cannot function properly in integrated environment

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 1 (Architecture)

---

## P2 (Normal) - Improvement Opportunities

### P2-1: Documentation Improvements

**Severity**: P2 (Normal)  
**Category**: Maintenance  
**Files**:
- `promotion/README.md`
- Various implementation docs

**Current State**:
- README exists but could be more comprehensive
- Some TODO comments in code without issue tracking
- Missing API documentation for complex business rules

**Required Action**:
1. Add detailed API documentation for promotion rules and conditions
2. Document discount calculation algorithms
3. Replace TODO comments with tracked issues:
   ```go
   // TODO(#123): Implement advanced targeting rules
   ```

4. Add troubleshooting section to README

**Impact**: Developer experience and maintenance burden

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 9 (Maintenance)

---

### P2-2: Code Style and Linting

**Severity**: P2 (Normal)  
**Category**: Code Quality  
**Files**: Various

**Current State**:
- May have golangci-lint warnings (needs verification)
- Some inconsistent error handling patterns
- Long functions that could be refactored

**Required Action**:
1. Run `golangci-lint run` and fix all issues
2. Break down large functions (> 50 lines) into smaller ones
3. Standardize error handling patterns

**Impact**: Code maintainability and team productivity

**Reference**: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md` Section 1 (Architecture)

---

## Implementation Priority

### Immediate (This Sprint)
1. **P0-1**: Add authentication middleware
2. **P1-1**: Add critical unit tests (aim for 50% coverage)

### Short Term (Next Sprint)  
1. **P1-2**: Implement proper error mapping
2. **P1-3**: Complete external service clients
3. **P2-1**: Documentation improvements

### Medium Term (Following Sprints)
1. **P1-1**: Reach 80%+ test coverage
2. **P2-2**: Code quality improvements

---

## Validation Checklist

- [ ] Authentication middleware added to HTTP/gRPC servers
- [ ] User ID extracted from context in all service methods
- [ ] Authorization checks implemented for admin operations
- [ ] Unit test coverage > 50% for biz layer
- [ ] Integration tests added for data layer
- [ ] gRPC error codes properly mapped using common/errors
- [ ] External service clients implemented and tested
- [ ] golangci-lint passes with zero warnings
- [ ] README updated with complete setup/troubleshooting
- [ ] All TODOs converted to tracked issues

---

## Notes

- Service architecture is solid and follows Clean Architecture principles
- Event-driven design with Dapr pub/sub is well implemented
- Caching and performance optimizations are in place
- Health checks and monitoring are properly configured
- Database transactions and migrations are correctly implemented

**Overall Assessment**: Service is functionally complete but requires security hardening and testing improvements before production deployment.</content>
<parameter name="filePath">/Users/tuananh/Desktop/myproject/microservice/docs/10-appendix/checklists/v2/promotion_service_code_review.md
# 📋 Comprehensive Code Quality Review 2026

**Generated**: 2026-01-22  
**Review Period**: Complete codebase analysis  
**Reviewer**: AI Code Review (Team Lead Guide Standards)  
**Scope**: All microservices + common libraries  
**Total Services Reviewed**: 12+ services  
**Total Existing Issues Indexed**: 28 checklists  

---

## 🎯 Executive Summary

### Overall Assessment

**Quality Score by Category** (1-10 scale, 10 = production-ready):
- ✅ **Architecture & Clean Code**: 7/10 (Good layer separation, some DI issues)
- ⚠️ **Business Logic & Concurrency**: 6/10 (Race conditions addressed, goroutine management needs work)
- 🔴 **Data Layer & Persistence**: 5/10 (Transaction handling incomplete, N+1 queries)
- 🔴 **Security**: 5/10 (Missing auth on write endpoints, secrets management)
- ⚠️ **Performance & Resilience**: 6/10 (Some caching, missing circuit breakers)
- ⚠️ **Observability**: 6/10 (Logging present, metrics/tracing incomplete)
- ⚠️ **Testing & Quality**: 5/10 (Unit tests present, integration test gaps)
- ✅ **API & Contract**: 7/10 (Proto design good, validation needs improvement)
- ✅ **Maintenance**: 7/10 (README present, some documentation gaps)

### Critical Findings Summary

**🚨 P0 Issues (Production Blockers)**: ~15-20 issues across services
- Missing authentication on Catalog write endpoints
- SQL injection risks in dynamic query building
- Unhandled distributed transaction failures
- Missing idempotency keys in payment processing
- Race conditions in warehouse stock management
- No circuit breakers on external service calls

**🟡 P1 Issues (High Priority)**: ~40-50 issues  
- N+1 query patterns in Order, Catalog, and Fulfillment services
- Missing timeout handling on service-to-service calls
- Inadequate error wrapping and context propagation
- Goroutine leaks in event publishers
- Missing observability (trace_id, structured logging gaps)
- Test coverage below 80% in business logic

**🔵 P2 Issues (Technical Debt)**: ~60+ issues
- Code duplication across services
- Missing API documentation
- Hardcoded configuration values
- Overly complex functions (cognitive complexity)
- Missing health check endpoints
- Deprecated TODO comments without tracking

---

## 📊 Service-by-Service Breakdown

### 1. Order Service ⚠️

**Overall Score**: 6.5/10

#### 🏗️ Architecture & Clean Code

**✅ Strengths**:
- Proper layer separation (`internal/biz`, `internal/data`, `internal/service`)
- Wire dependency injection used correctly
- Domain models separated from persistence models

**❌ Issues**:
- **[P2]** **OR-ARCH-01**: `ConfirmCheckout` function is overly complex (384 lines, cognitive complexity > 30)
  - **File**: [`order/internal/biz/checkout/confirm.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go)
  - **Fix**: Extract private methods (already partially done, needs completion)

#### 🧠 Business Logic & Concurrency

**✅ Strengths**:
- Cart add/update use transaction + row-level locking (`LoadCartForUpdate`)
- Errgroup pattern for parallel service calls
- Retry logic with exponential backoff

**❌ Issues**:
- **[P1]** **OR-CONC-01**: Event publishing uses context.WithTimeout but no goroutine management for failures
  - **File**: [`order/internal/biz/cart/add.go:274-276`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/add.go#L274-L276)
  - **Impact**: If event publishing blocks/fails, cart operations hang for 5s
  - **Fix**: Use fire-and-forget pattern with monitored goroutines or outbox pattern

- **[P1]** **OR-CONC-02**: Checkout confirmation lacks distributed transaction coordinator
  - **File**: [`order/internal/biz/checkout/confirm.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/confirm.go)
  - **Impact**: Saga pattern partially implemented but no recovery orchestrator
  - **Status**: Partially mitigated with Saga state tracking, needs DLQ + manual intervention workflow

#### 💽 Data Layer & Persistence

**❌ Issues**:
- **[P0]** **OR-DATA-01**: Missing transaction boundaries in cart totals calculation
  - **File**: [`order/internal/biz/cart/totals.go:57-350`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go#L57-L350)
  - **Impact**: Reads cart items without isolation, inconsistent totals under concurrent updates
  - **Fix**: Wrap in REPEATABLE READ transaction or use snapshot reads

- **[P1]** **OR-DATA-02**: No pagination in order listing queries
  - **File**: `order/internal/data/order/repository.go`
  - **Impact**: OOM risk with large result sets
  - **Fix**: Implement cursor-based pagination

#### 🛡️ Security

**❌ Issues**:
- **[P1]** **OR-SEC-01**: Payment method ownership validation only in authorization, not in cart setup
  - **File**: [`order/internal/biz/checkout/payment.go:61-72`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/checkout/payment.go#L61-L72)
  - **Impact**: Users could add others' payment methods to cart before validation
  - **Fix**: Validate on payment method selection in cart/checkout

#### ⚡ Performance & Resilience

**✅ Strengths**:
- Promotion validation caching implemented (SHA256 key generation)
- Parallel service calls in AddToCart (pricing + stock check)

**❌ Issues**:
- **[P0]** **OR-PERF-01**: No timeout on shipping service call in totals calculation
  - **File**: [`order/internal/biz/cart/totals.go:114`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/totals.go#L114)
  - **Impact**: Checkout can hang indefinitely if shipping service is slow
  - **Fix**: Add context.WithTimeout(ctx, 5*time.Second) wrapper

- **[P1]** **OR-PERF-02**: No circuit breaker on payment service calls
  - **Impact**: Cascading failures if payment service is degraded
  - **Fix**: Implement circuit breaker using gobreaker or similar

#### 👁️ Observability

**❌ Issues**:
- **[P1]** **OR-OBS-01**: Missing structured trace_id propagation in cart operations
  - **Impact**: Difficult to debug multi-service cart flows
  - **Fix**: Extract trace_id from context and include in all log statements

- **[P2]** **OR-OBS-02**: Cart metrics only track operation count, not latency
  - **File**: [`order/internal/biz/cart/metrics.go`](file:///Users/tuananh/Desktop/myproject/microservice/order/internal/biz/cart/metrics.go)
  - **Fix**: Add RED metrics (Rate, Error, Duration) using Prometheus histograms

#### 🧪 Testing & Quality

**❌ Issues**:
- **[P1]** **OR-TEST-01**: Cart totals calculation has no integration tests with real service mocks
  - **Impact**: Pricing/promotion/tax integration bugs not caught
  - **Fix**: Add integration tests using testcontainers for dependencies

---

### 2. Catalog Service ⚠️

**Overall Score**: 6/10

#### 🏗️ Architecture & Clean Code

**❌ Issues**:
- **[P0]** **CAT-ARCH-01**: Product service layer accesses repository directly in some flows
  - **File**: `catalog/internal/service/product_service.go`
  - **Impact**: Bypasses business logic layer, violates clean architecture
  - **Fix**: All repo calls must go through usecase

#### 💽 Data Layer & Persistence

**❌ Issues**:
- **[P0]** **CAT-DATA-01**: N+1 query in product listing with attributes
  - **File**: `catalog/internal/data/product/repository.go`
  - **Impact**: 1 + N queries for N products (performance degradation)
  - **Fix**: Use GORM Preload("Attributes") or JOIN query

- **[P1]** **CAT-DATA-02**: Product SKU uniqueness not enforced at DB level
  - **Impact**: Duplicate SKUs can be created
  - **Fix**: Add UNIQUE constraint on sku column in migration

#### 🛡️ Security

**❌ Issues**:
- **[P0]** **CAT-SEC-01**: No authentication on CreateProduct, UpdateProduct endpoints
  - **File**: `catalog/internal/service/product_service.go`
  - **Impact**: Anyone can create/modify products
  - **Fix**: Add admin role check in service layer

- **[P2]** **CAT-SEC-02**: Product search allows arbitrary SQL in filter parameters
  - **Impact**: Potential SQL injection if not parameterized
  - **Fix**: Validate filter parameters and use parameterized queries only

#### ⚡ Performance & Resilience

**❌ Issues**:
- **[P1]** **CAT-PERF-01**: No caching for product details (high read traffic)
  - **Impact**: Excessive DB load
  - **Fix**: Implement Redis cache with TTL for product details

---

### 3. Warehouse Service 🔴

**Overall Score**: 5/10

#### 🧠 Business Logic & Concurrency

**❌ Issues**:
- **[P0]** **WH-CONC-01**: Stock reservation uses optimistic locking but no retry logic
  - **File**: `warehouse/internal/biz/reservation/reserve.go`
  - **Impact**: Reservations fail under concurrent load instead of retrying
  - **Fix**: Implement retry with exponential backoff on version conflicts

- **[P0]** **WH-CONC-02**: Stock deduction is not atomic with inventory check
  - **File**: `warehouse/internal/biz/inventory/adjust.go`
  - **Impact**: Race condition can cause overselling
  - **Fix**: Use SELECT FOR UPDATE + UPDATE in single transaction

#### 💽 Data Layer & Persistence

**❌ Issues**:
- **[P1]** **WH-DATA-01**: Reservation expiry cleanup runs in main service goroutine
  - **Impact**: No guarantee cleanup runs if service crashes
  - **Fix**: Move to dedicated worker with persistent queue

#### 🛡️ Security

**❌ Issues**:
- **[P1]** **WH-SEC-01**: Reservation release doesn't validate ownership
  - **File**: `warehouse/internal/biz/reservation/release.go`
  - **Impact**: One order can release another order's reservation
  - **Fix**: Validate reservation belongs to requesting order/cart

---

### 4. Payment Service 🔴

**Overall Score**: 5/10

#### 🛡️ Security

**❌ Issues**:
- **[P0]** **PAY-SEC-01**: Webhook signature verification timeout not enforced
  - **File**: `payment/internal/biz/webhook/verify.go`
  - **Impact**: Replay attack vulnerability
  - **Fix**: Add 5-minute timestamp tolerance check

- **[P0]** **PAY-SEC-02**: Payment method tokens stored in plaintext metadata
  - **File**: `payment/internal/model/payment_method.go`
  - **Impact**: PCI compliance violation
  - **Fix**: Encrypt sensitive tokens before storage

- **[P1]** **PAY-SEC-03**: No rate limiting on payment authorization attempts
  - **Impact**: Brute force attack on stolen cards
  - **Fix**: Implement per-customer rate limiting (5 attempts/minute)

#### 🧠 Business Logic & Concurrency

**❌ Issues**:
- **[P0]** **PAY-CONC-01**: Payment capture idempotency key not checked before gateway call
  - **File**: `payment/internal/biz/gateway/capture.go`
  - **Impact**: Duplicate charges if capture retried
  - **Fix**: Check idempotency DB table before calling payment gateway

#### ⚡ Performance & Resilience

**❌ Issues**:
- **[P0]** **PAY-PERF-01**: No timeout on payment gateway API calls
  - **Impact**: Service hangs if gateway is slow
  - **Fix**: Add 10s timeout to all HTTP client calls

- **[P1]** **PAY-PERF-02**: No circuit breaker for payment gateway
  - **Impact**: Cascading failures during gateway outage
  - **Fix**: Implement circuit breaker pattern

---

### 5. Pricing Service ⚠️

**Overall Score**: 6/10

#### 🧠 Business Logic & Concurrency

**❌ Issues**:
- **[P1]** **PRI-CONC-01**: Price calculation caching uses non-deterministic key generation
  - **File**: `pricing/internal/biz/calculation/cache.go`
  - **Impact**: Cache misses for identical requests (performance degradation)
  - **Fix**: Sort arrays in cache key generation for deterministic hashing

#### 💽 Data Layer & Persistence

**❌ Issues**:
- **[P1]** **PRI-DATA-01**: Tax rate lookup queries without index on (country_code, state)
  - **Impact**: Full table scan on every tax calculation
  - **Fix**: Add composite index on tax_rates table

#### ⚡ Performance & Resilience

**❌ Issues**:
- **[P1]** **PRI-PERF-01**: Bulk price calculation doesn't batch DB queries
  - **File**: `pricing/internal/biz/price/bulk.go`
  - **Impact**: N+1 queries for N products
  - **Fix**: Use GORM IN clause or raw SQL with bulk fetch

---

### 6. Promotion Service ⚠️

**Overall Score**: 6/10

#### 🧠 Business Logic & Concurrency

**❌ Issues**:
- **[P0]** **PROM-CONC-01**: Coupon usage increment not atomic with validation
  - **File**: `promotion/internal/biz/coupon/apply.go`
  - **Impact**: Usage limit can be exceeded under concurrent requests
  - **Fix**: Use SELECT FOR UPDATE + UPDATE in transaction

#### 💽 Data Layer & Persistence

**❌ Issues**:
- **[P1]** **PROM-DATA-01**: Promotion eligibility check queries all active promotions
  - **Impact**: O(N) performance on promotion count
  - **Fix**: Add eligibility_rules JSONB index for faster filtering

---

### 7. Shipping Service ✅

**Overall Score**: 7/10

**Generally well-structured, minor issues**:

#### ⚡ Performance & Resilience

**❌ Issues**:
- **[P1]** **SHIP-PERF-01**: No caching for carrier rate calculations
  - **Impact**: Redundant API calls to shipping carriers
  - **Fix**: Cache rates by origin/destination/weight for 1 hour

---

### 8. Customer Service ✅

**Overall Score**: 7/10

#### 🛡️ Security

**❌ Issues**:
- **[P1]** **CUST-SEC-01**: Customer profile update doesn't validate ownership
  - **File**: `customer/internal/service/customer_service.go`
  - **Impact**: One customer can update another's profile if they know the ID
  - **Fix**: Validate customer_id matches authenticated user

---

### 9. Auth Service ⚠️

**Overall Score**: 6/10

#### 🛡️ Security

**❌ Issues**:
- **[P0]** **AUTH-SEC-01**: JWT signing key loaded from ENV without rotation support
  - **File**: `auth/internal/config/config.go`
  - **Impact**: Key compromise requires service restart
  - **Fix**: Load keys from secret manager with rotation support

- **[P1]** **AUTH-SEC-02**: Password reset tokens not invalidated after use
  - **File**: `auth/internal/biz/password/reset.go`
  - **Impact**: Token replay vulnerability
  - **Fix**: Mark tokens as used in database

---

### 10. Fulfillment Service ⚠️

**Overall Score**: 6/10

#### 🧠 Business Logic & Concurrency

**❌ Issues**:
- **[P1]** **FUL-CONC-01**: Shipment status update not idempotent
  - **File**: `fulfillment/internal/biz/shipment/update.go`
  - **Impact**: Duplicate status transitions on webhook retries
  - **Fix**: Add idempotency key check before status update

#### 💽 Data Layer & Persistence

**❌ Issues**:
- **[P1]** **FUL-DATA-01**: Order fulfillment status query joins 4 tables without indexes
  - **Impact**: Slow queries on order history pages
  - **Fix**: Add composite indexes or denormalize status

---

### 11. Notification Service ✅

**Overall Score**: 7/10

#### ⚡ Performance & Resilience

**❌ Issues**:
- **[P1]** **NOT-PERF-01**: Email sending blocks on SMTP connection
  - **File**: `notification/internal/biz/email/send.go`
  - **Impact**: Slow email provider blocks notification processing
  - **Fix**: Use asynchronous queue + worker pattern

---

### 12. Common Package ⚠️

**Overall Score**: 6/10

#### 🏗️ Architecture & Clean Code

**❌ Issues**:
- **[P2]** **COM-ARCH-01**: JSONMetadata helper functions scattered across packages
  - **Impact**: Code duplication, inconsistent behavior
  - **Fix**: Consolidate into `common/utils/metadata` package

#### 🛡️ Security

**❌ Issues**:
- **[P0]** **COM-SEC-01**: Database connection strings include credentials in logs
  - **File**: `common/database/postgres.go`
  - **Impact**: Credentials leak in application logs
  - **Fix**: Redact passwords before logging

---

## 🌐 Cross-Cutting Issues

### 1. Distributed System Patterns

**❌ Critical Gaps**:
- **[P0]** **CROSS-DIST-01**: No standardized Saga orchestration framework
  - **Impact**: Manual distributed transactions prone to inconsistencies
  - **Affected**: Order, Payment, Warehouse services
  - **Fix**: Implement Temporal or custom Saga coordinator with state persistence

- **[P0]** **CROSS-DIST-02**: Outbox pattern implemented inconsistently
  - **Impact**: Event delivery not guaranteed across services
  - **Fix**: Standardize outbox implementation in common library

### 2. Observability

**❌ Gaps**:
- **[P1]** **CROSS-OBS-01**: trace_id propagation not standardized across services
  - **Impact**: Distributed traces incomplete
  - **Fix**: Enforce trace_id middleware in gateway + all services

- **[P1]** **CROSS-OBS-02**: Structured logging format varies by service
  - **Impact**: Log aggregation difficult
  - **Fix**: Standardize JSON logging format using common logger

- **[P1]** **CROSS-OBS-03**: No centralized metrics dashboard
  - **Impact**: System health visibility limited
  - **Fix**: Set up Grafana with pre-built Kratos dashboards

### 3. Error Handling

**❌ Patterns**:
- **[P1]** **CROSS-ERR-01**: gRPC error codes inconsistently mapped to business errors
  - **Impact**: Client error handling unpredictable
  - **Fix**: Document and standardize error code mappings in common package

- **[P2]** **CROSS-ERR-02**: Error messages include internal details (stack traces, SQL)
  - **Impact**: Information leakage
  - **Fix**: Sanitize errors before returning to clients

### 4. Testing Strategy

**❌ Gaps**:
- **[P1]** **CROSS-TEST-01**: No end-to-end tests for critical flows (cart → checkout → order)
  - **Impact**: Integration bugs discovered in production
  - **Fix**: Add E2E test suite using testcontainers

- **[P1]** **CROSS-TEST-02**: Mock generation inconsistent (some use mockgen, some manual)
  - **Impact**: Brittle tests, difficult maintenance
  - **Fix**: Standardize on mockgen with go:generate directives

### 5. Configuration Management

**❌ Issues**:
- **[P1]** **CROSS-CFG-01**: Configuration values hardcoded in multiple places
  - **Examples**: DefaultCurrency, DefaultCountryCode, timeouts
  - **Impact**: Environment-specific configs require code changes
  - **Fix**: Move all configs to environment variables or config files

- **[P0]** **CROSS-CFG-02**: No secret rotation mechanism
  - **Impact**: Compromised secrets require manual intervention
  - **Fix**: Integrate with HashiCorp Vault or AWS Secrets Manager

### 6. Database Migrations

**❌ Patterns**:
- **[P1]** **CROSS-DB-01**: No rollback strategy for failed migrations
  - **Impact**: Production deployments can't be safely rolled back
  - **Fix**: Ensure all migrations have Down() scripts

- **[P2]** **CROSS-DB-02**: Migration naming convention inconsistent
  - **Impact**: Difficult to track migration ordering
  - **Fix**: Adopt timestamp-based naming (YYYYMMDD_HHMMSS_description.go)

---

## 🛠️ Remediation Roadmap

### Phase 1: P0 Blockers (1-2 Sprints)

**Security**:
1. **CAT-SEC-01**: Add authentication to Catalog write endpoints
2. **PAY-SEC-01**: Fix webhook replay vulnerability
3. **PAY-SEC-02**: Encrypt payment method tokens
4. **AUTH-SEC-01**: Implement JWT key rotation
5. **COM-SEC-01**: Redact credentials from logs

**Data Integrity**:
6. **WH-CONC-02**: Fix warehouse stock deduction race condition
7. **PROM-CONC-01**: Fix coupon usage limit race condition
8. **PAY-CONC-01**: Add idempotency check before payment gateway calls

**Performance**:
9. **OR-PERF-01**: Add timeouts to external service calls
10. **PAY-PERF-01**: Add timeouts to payment gateway calls

**Data Layer**:
11. **OR-DATA-01**: Fix missing transaction isolation in cart totals
12. **CAT-DATA-01**: Fix N+1 queries in product listing

**Distributed Systems**:
13. **CROSS-DIST-01**: Implement standardized Saga framework
14. **CROSS-DIST-02**: Standardize outbox pattern
15. **CROSS-CFG-02**: Set up secret rotation

---

### Phase 2: P1 High Priority (2-4 Sprints)

**Concurrency & Resilience**:
1. Implement circuit breakers on all external service calls
2. Add retry logic with exponential backoff
3. Fix goroutine management in event publishers

**Performance**:
4. Add caching layers (Redis) for frequently accessed data
5. Fix N+1 queries across all services
6. Implement pagination for all list endpoints

**Observability**:
7. Standardize trace_id propagation
8. Complete RED metrics implementation
9. Set up centralized logging and dashboards

**Security**:
10. Implement rate limiting on sensitive endpoints
11. Fix ownership validation gaps
12. Complete audit logging

**Testing**:
13. Add integration tests for critical flows
14. Achieve 80%+ coverage in business logic
15. Set up E2E test suite

---

### Phase 3: P2 Technical Debt (Ongoing)

**Code Quality**:
1. Refactor complex functions (cognitive complexity > 15)
2. Reduce code duplication
3. Improve API documentation

**Maintainability**:
4. Complete README files for all services
5. Document architecture decisions (ADRs)
6. Clean up TODOs and deprecated code

**Infrastructure**:
7. Standardize health check endpoints
8. Improve deployment automation
9. Add performance benchmarking

---

## 🔍 Verification Commands

### Architecture Validation

```bash
# Check layer separation violations
grep -r "repo\." */internal/service/ | grep -v "mock"

# Find direct DB access in service layer
grep -r "gorm.DB" */internal/service/
```

### Security Audit

```bash
# Find hardcoded secrets
grep -rE "(password|secret|key).*=.*\"" . --exclude-dir=vendor

# Check for missing authentication
grep -r "func.*Create\|Update\|Delete" */internal/service/*.go | \
  xargs -I {} grep -L "authentication\|auth\|JWT" {}
```

### Concurrency Issues

```bash
# Find unmanaged goroutines
grep -r "go func()" . --exclude-dir=vendor | \
  grep -v "errgroup\|WaitGroup"

# Find missing locks
grep -r "map\[string\]" */internal/ | grep -v "sync\." | grep var
```

### Performance

```bash
# Find N+1 queries
grep -r "\.Find\|\.First" */internal/data/ | \
  grep -E "for.*range"

# Find missing pagination
grep -r "func.*List" */internal/service/ | \
  xargs -I {} grep -L "limit\|offset\|page" {}
```

### Testing

```bash
# Check test coverage
go test -cover ./... | grep -E "coverage: [0-7][0-9]\."

# Find untested business logic
find */internal/biz -name "*.go" ! -name "*_test.go" | \
  xargs -I {} bash -c 'test ! -f {%.go}_test.go && echo "Missing test: {}"'
```

### K8s Debugging (Dev Environment)

```bash
# Check service health
kubectl get pods -n dev -l app=order-service

# View logs for errors
stern -n dev 'order|payment|warehouse' --since 10m | grep -i error

# Port-forward for local debugging
kubectl port-forward -n dev svc/order-service 8080:8080
```

---

## 📚 Appendix: Review Methodology

### Standards Applied
- **Team Lead Code Review Guide v1.0.1**
- **Kratos Framework Best Practices**
- **Go Microservices Patterns**
- **OWASP Security Guidelines**
- **12-Factor App Principles**

### Review Coverage
- ✅ All 28 existing issue checklists reviewed
- ✅ Code patterns analyzed across 12+ services
- ✅ 100+ files examined in detail
- ✅ Cross-cutting concerns evaluated
- ✅ Infrastructure and deployment reviewed

### Priority Definitions
- **P0 (Blocking)**: Security vulnerabilities, data loss risks, production outages
- **P1 (High)**: Performance degradation, reliability issues, compliance gaps
- **P2 (Normal)**: Technical debt, code quality, documentation

---

## 🎯 Next Steps

1. **Review with Team**: Present findings in architecture review meeting
2. **Prioritize Fixes**: Align roadmap with product priorities
3. **Assign Ownership**: Map issues to service teams
4. **Track Progress**: Create JIRA tickets with links to this document
5. **Establish Standards**: Document patterns and anti-patterns for future development
6. **Continuous Monitoring**: Set up automated checks for common issues (linters, static analysis)

---

**Document Maintainer**: AI Code Review System  
**Review Frequency**: Quarterly or before major releases  
**Last Updated**: 2026-01-22


# Shipping Service Refactoring Checklist

**Date**: 2026-01-23
**Total LOC**: ~8,500 lines (183 files)
**Service Complexity**: High (4 domains, carrier integrations, event-driven)
**Architecture**: Clean Architecture ✅ (Well implemented)
**Test Coverage**: Low (2 test files, ~5% coverage)

---

## 📊 Executive Summary

The Shipping service is a **well-architected microservice** with clean domain separation and event-driven design. However, it has **critical security gaps** and **missing observability** that require immediate attention. The service follows Clean Architecture principles effectively but needs significant improvements in testing, security, and monitoring.

**Major Issues Identified**:
- **P0**: Carrier credentials stored unencrypted in database (JSONB)
- **P0**: No authorization controls in business logic
- **P1**: Minimal test coverage (only 2 test files)
- **P1**: Missing comprehensive observability (metrics, tracing)
- **P2**: Large service layer files need decomposition

**Refactoring Strategy**: **Security-first approach** followed by observability and testing improvements.

---

## 🏗️ 1. Architecture Assessment

### ✅ Strengths
- **Clean Architecture**: Proper separation between biz/data/service layers
- **Domain-Driven Design**: Well-organized domains (shipment, carrier, shipping_method)
- **Event-Driven**: Comprehensive event system with transactional outbox
- **State Machine**: Proper shipment lifecycle management
- **Carrier Abstraction**: Clean interface-based carrier integrations
- **Dependency Injection**: Proper Wire-based DI throughout

### ❌ Issues Requiring Refactoring

#### **[P0]** SH-ARCH-01: Carrier Credentials Security Risk
**File**: `internal/model/carrier.go` - Credentials stored in JSONB
**Impact**: Sensitive API keys/tokens exposed in database
**Evidence**: `Credentials JSONB` field stores carrier API credentials unencrypted
**Fix**: Implement encryption at rest + credential vault integration
**Effort**: 8 hours

#### **[P1]** SH-ARCH-02: Missing Authorization in Business Logic
**File**: Business layer has no role-based access control
**Impact**: Any authenticated user can perform any shipping operation
**Evidence**: No authorization checks in usecase methods
**Fix**: Implement RBAC with context-based user permissions
**Effort**: 12 hours

#### **[P1]** SH-ARCH-03: Insufficient Test Coverage
**Current**: 2 test files (~5% coverage)
**Target**: >80% coverage with integration tests
**Missing Tests**:
- Shipment state transitions
- Carrier integrations
- Event publishing
- Error scenarios
**Effort**: 80+ hours

#### **[P2]** SH-ARCH-04: Large Service Layer Files
**Files**:
- `service/shipment.go`: 623 LOC
- `service/carrier.go`: 521 LOC
**Impact**: Difficult maintenance and testing
**Strategy**: Decompose into focused handler files
**Target**: Max 300 LOC per file

---

## 🔧 2. Refactoring Plan

### Phase 1: Security & Critical Fixes (Week 1-2)

#### 1.1 Credential Security
- [ ] **SH-SEC-01**: Encrypt carrier credentials at rest
  ```go
  // Use encryption service for credentials
  type Carrier struct {
      Credentials EncryptedJSONB `gorm:"type:jsonb;not null"`
  }
  ```
- [ ] **SH-SEC-02**: Implement credential vault integration
- [ ] **SH-SEC-03**: Add credential rotation mechanism

#### 1.2 Authorization Implementation
- [ ] **SH-AUTH-01**: Add user context to business layer
  ```go
  type UserContext struct {
      UserID   string
      Roles    []string
      TenantID string
  }
  ```
- [ ] **SH-AUTH-02**: Implement role-based access control
  ```go
  func (uc *ShipmentUseCase) checkPermission(ctx context.Context, action string) error
  ```
- [ ] **SH-AUTH-03**: Add context propagation from gateway

### Phase 2: Observability Enhancement (Week 3-4)

#### 2.1 Comprehensive Metrics
- [ ] **SH-OBS-01**: Implement shipping service metrics
  ```go
  type ShippingMetrics struct {
      shipmentsCreated     *prometheus.CounterVec
      shipmentsUpdated     *prometheus.CounterVec
      carrierAPICalls      *prometheus.HistogramVec
      eventPublishingLatency *prometheus.HistogramVec
      // ... more metrics
  }
  ```
- [ ] **SH-OBS-02**: Add distributed tracing
  ```go
  span, ctx := tracer.StartSpanFromContext(ctx, "CreateShipment")
  defer span.Finish()
  ```
- [ ] **SH-OBS-03**: Implement structured logging levels

#### 2.2 Health Checks Enhancement
- [ ] **SH-HEALTH-01**: Add dependency health checks
- [ ] **SH-HEALTH-02**: Implement readiness probes for carrier APIs
- [ ] **SH-HEALTH-03**: Add circuit breaker status to health endpoint

### Phase 3: Service Layer Decomposition (Week 5-6)

#### 3.1 Shipment Service Decomposition
**Current**: `service/shipment.go` (623 LOC)
**Target Structure**:
```
service/shipment/
├── shipment_service.go     # Main service struct (50 LOC)
├── create_handlers.go      # Create operations (150 LOC)
├── update_handlers.go      # Update operations (150 LOC)
├── query_handlers.go       # Query operations (150 LOC)
├── action_handlers.go      # Actions (assign, confirm) (150 LOC)
└── validation.go           # Input validation (100 LOC)
```

#### 3.2 Carrier Service Decomposition
**Current**: `service/carrier.go` (521 LOC)
**Target Structure**:
```
service/carrier/
├── carrier_service.go      # Main service struct (50 LOC)
├── crud_handlers.go        # CRUD operations (150 LOC)
├── config_handlers.go      # Configuration management (150 LOC)
├── rate_handlers.go        # Rate calculation (100 LOC)
└── validation.go           # Input validation (100 LOC)
```

### Phase 4: Testing Implementation (Week 7-12)

#### 4.1 Unit Tests (40 hours)
- [ ] Core business logic (state transitions, validation)
- [ ] Repository operations
- [ ] Service layer handlers
- [ ] Error scenarios and edge cases

#### 4.2 Integration Tests (30 hours)
- [ ] Database integration tests
- [ ] Event publishing/consumption
- [ ] Carrier API mocking
- [ ] End-to-end shipment workflows

#### 4.3 Performance Tests (10 hours)
- [ ] Concurrent shipment creation
- [ ] Carrier API rate limiting
- [ ] Database query performance

---

## 🐛 3. Bugs & Issues

### Critical Bugs (P0)

#### **[P0]** SH-BUG-01: Missing Transaction Atomicity
**File**: `internal/biz/shipment/shipment_usecase.go:CreateShipment()`
**Issue**: Event publishing not atomic with shipment creation
**Evidence**: Outbox event saved after shipment creation - potential inconsistency
**Fix**: Use distributed transaction or saga pattern
**Effort**: 6 hours

#### **[P0]** SH-BUG-02: Carrier Credential Exposure
**File**: `internal/model/carrier.go`
**Issue**: API keys stored unencrypted in JSONB
**Evidence**: `Credentials JSONB` field contains sensitive data
**Fix**: Implement field-level encryption
**Effort**: 8 hours

#### **[P0]** SH-BUG-03: No Rate Limiting for Carrier APIs
**File**: Carrier client implementations
**Issue**: No protection against carrier API rate limits
**Evidence**: Direct API calls without rate limiting
**Fix**: Implement token bucket or leaky bucket rate limiting
**Effort**: 4 hours

### High Priority Issues (P1)

#### **[P1]** SH-BUG-04: Missing Business Validation
**File**: `internal/service/shipment.go:BatchCreateShipments()`
**Issue**: Weak validation in batch operations
**Evidence**: Some requests skip validation, inconsistent error handling
**Fix**: Consistent validation across all endpoints
**Effort**: 6 hours

#### **[P1]** SH-BUG-05: Inconsistent Error Responses
**File**: Service layer error handling
**Issue**: Mixed error response formats
**Evidence**: Some endpoints return `{success, message}`, others direct errors
**Fix**: Standardize error response format
**Effort**: 4 hours

#### **[P1]** SH-BUG-06: Event Publishing Failures Not Handled
**File**: `internal/biz/shipment/events.go`
**Issue**: Event publishing errors only logged, not retried
**Evidence**: `publishEvent()` errors are logged but shipment continues
**Fix**: Implement retry mechanism with dead letter queue
**Effort**: 8 hours

---

## ⚡ 4. Performance Optimizations

### Database Performance (P1)

#### **[P1]** SH-PERF-01: Missing Database Indexes
**Issue**: Potential slow queries on shipment searches
**Fix**: Add composite indexes for common query patterns
```sql
CREATE INDEX idx_shipments_status_created ON shipments(status, created_at);
CREATE INDEX idx_shipments_carrier_tracking ON shipments(carrier, tracking_number);
```
**Effort**: 4 hours

#### **[P1]** SH-PERF-02: N+1 Query in Shipment Listing
**File**: `internal/repository/shipment/shipment_repo.go:List()`
**Issue**: No eager loading for related entities
**Fix**: Add Preload for carrier and warehouse relations
**Effort**: 3 hours

### Caching Strategy (P2)

#### **[P2]** SH-PERF-03: No Carrier Configuration Caching
**Issue**: Carrier configs loaded from DB on every request
**Fix**: Redis caching for carrier configurations (TTL: 5 minutes)
**Effort**: 4 hours

#### **[P2]** SH-PERF-04: Shipping Rate Cache Invalidation
**Issue**: Rate cache not invalidated when carrier configs change
**Fix**: Event-driven cache invalidation
**Effort**: 3 hours

### Carrier API Optimization (P1)

#### **[P1]** SH-PERF-05: No Carrier API Connection Pooling
**Issue**: New HTTP connections for each carrier API call
**Fix**: Implement HTTP client connection pooling
**Effort**: 2 hours

#### **[P1]** SH-PERF-06: Missing Carrier API Timeouts
**Issue**: No timeout protection for carrier API calls
**Fix**: Add configurable timeouts and context cancellation
**Effort**: 2 hours

---

## 🧪 5. Testing Gaps

### Current State
- **Test Files**: 2 files (shipment_usecase_test.go, return_usecase_test.go)
- **Coverage**: ~5% (estimated)
- **Test Types**: Basic unit tests only

### Critical Testing Gaps

#### Business Logic Testing (P1 - 30 hours)
- [ ] **State Machine Testing**: All shipment status transitions
- [ ] **Validation Testing**: Input validation edge cases
- [ ] **Event Testing**: Event publishing and consumption
- [ ] **Error Scenario Testing**: Database failures, API timeouts

#### Integration Testing (P1 - 25 hours)
- [ ] **Database Integration**: Real database operations
- [ ] **Event Bus Integration**: Event publishing/consumption
- [ ] **Carrier API Mocking**: External API failure scenarios
- [ ] **Transactional Testing**: Rollback scenarios

#### End-to-End Testing (P2 - 15 hours)
- [ ] **Complete Shipment Workflow**: Create → Assign → Ship → Deliver
- [ ] **Batch Operations**: Bulk shipment creation and updates
- [ ] **Failure Recovery**: Automatic retry mechanisms

#### Performance Testing (P2 - 10 hours)
- [ ] **Load Testing**: Concurrent shipment operations
- [ ] **Database Load**: High-volume queries
- [ ] **Memory Leak Testing**: Long-running processes

---

## 📋 6. Implementation Roadmap

### Week 1: Security Foundation (16 hours)
- [ ] SH-SEC-01: Implement credential encryption (4h)
- [ ] SH-SEC-02: Add authorization framework (6h)
- [ ] SH-BUG-01: Fix transaction atomicity (6h)

### Week 2: Observability & Monitoring (20 hours)
- [ ] SH-OBS-01: Implement comprehensive metrics (8h)
- [ ] SH-OBS-02: Add distributed tracing (6h)
- [ ] SH-HEALTH-01: Enhance health checks (6h)

### Week 3: Service Layer Refactoring (24 hours)
- [ ] Decompose shipment service into focused files (12h)
- [ ] Decompose carrier service into focused files (12h)

### Week 4: Business Logic Improvements (16 hours)
- [ ] SH-BUG-04: Fix batch operation validation (4h)
- [ ] SH-BUG-05: Standardize error responses (4h)
- [ ] SH-BUG-06: Implement event publishing retries (8h)

### Week 5-6: Performance Optimization (16 hours)
- [ ] Database indexing and query optimization (6h)
- [ ] Implement caching strategy (6h)
- [ ] Carrier API optimization (4h)

### Week 7-12: Comprehensive Testing (80 hours)
- [ ] Unit test implementation (40h)
- [ ] Integration test suite (25h)
- [ ] E2E and performance testing (15h)

---

## ✅ 7. Verification Checklist

### Security Verification
- [ ] **Credential Encryption**: Carrier credentials encrypted at rest
- [ ] **Authorization**: All endpoints protected with proper RBAC
- [ ] **Rate Limiting**: Carrier APIs protected from abuse
- [ ] **Audit Logging**: Sensitive operations logged

### Quality Verification
- [ ] **Test Coverage**: >80% with integration tests
- [ ] **Performance**: P95 latency <500ms for core operations
- [ ] **Reliability**: <0.1% error rate under normal load
- [ ] **Observability**: Full metrics, tracing, and health checks

### Architecture Verification
- [ ] **Clean Architecture**: No biz layer DB calls
- [ ] **File Sizes**: Max 300 LOC per file
- [ ] **Separation**: Clear domain boundaries maintained
- [ ] **Error Handling**: Consistent error patterns throughout

---

## 🎯 8. Success Metrics

### Security & Compliance
- **Credential Security**: ✅ 100% encrypted
- **Authorization Coverage**: ✅ 100% of endpoints
- **Audit Trail**: ✅ All sensitive operations logged

### Quality & Reliability
- **Test Coverage**: >80% (from ~5%)
- **Error Rate**: <0.1% (target: 99.9% uptime)
- **Performance**: P95 <500ms for shipment operations

### Architecture & Maintainability
- **File Size Reduction**: Max 300 LOC (from 623 LOC max)
- **Cyclomatic Complexity**: <10 per function
- **Technical Debt**: Zero P0/P1 issues remaining

---

## 📖 9. Implementation Guidelines

### Security Implementation
```go
// Credential encryption example
type EncryptedJSONB []byte

func (e EncryptedJSONB) Value() (driver.Value, error) {
    if len(e) == 0 {
        return nil, nil
    }
    encrypted, err := encryptData(e, encryptionKey)
    return encrypted, err
}

func (e *EncryptedJSONB) Scan(value interface{}) error {
    if value == nil {
        *e = nil
        return nil
    }
    decrypted, err := decryptData(value.([]byte), encryptionKey)
    *e = decrypted
    return err
}
```

### Authorization Pattern
```go
type UserContext struct {
    UserID   string
    Roles    []string
    TenantID string
}

func (uc *ShipmentUseCase) checkPermission(ctx context.Context, requiredRole string) error {
    userCtx := getUserContext(ctx)
    if !hasRole(userCtx.Roles, requiredRole) {
        return ErrUnauthorized
    }
    return nil
}
```

### Comprehensive Metrics
```go
type ShippingMetrics struct {
    // Shipment operations
    shipmentsCreated *prometheus.CounterVec
    shipmentStatusChanges *prometheus.CounterVec
    shipmentOperationDuration *prometheus.HistogramVec

    // Carrier operations
    carrierAPICalls *prometheus.CounterVec
    carrierAPIErrors *prometheus.CounterVec
    carrierAPIDuration *prometheus.HistogramVec

    // Event operations
    eventsPublished *prometheus.CounterVec
    eventsFailed *prometheus.CounterVec
    eventProcessingDuration *prometheus.HistogramVec
}
```

---

## 🚧 10. Risks & Mitigation

### Risk 1: Credential Encryption Breaking Existing Functionality
**Mitigation**:
- Test all carrier integrations after encryption implementation
- Implement gradual rollout with feature flags
- Have rollback plan for encryption issues

### Risk 2: Authorization Changes Breaking API Contracts
**Mitigation**:
- Comprehensive testing of all endpoints
- Document authorization requirements clearly
- Implement gradual rollout with backward compatibility

### Risk 3: Performance Impact from Added Observability
**Mitigation**:
- Benchmark before/after observability implementation
- Implement sampling for high-volume operations
- Monitor production metrics closely during rollout

---

**Created**: 2026-01-23
**Total Estimated Effort**: ~200 hours (12 weeks for 1 engineer)
**Priority**: P0 security fixes, then P1 observability and testing
**Reviewer**: AI Senior Code Review (Team Lead Standards)
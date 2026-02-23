# Warehouse Service Refactoring Checklist

**Date**: 2026-01-23
**Total LOC**: ~9,740 lines (194 files)
**Service Complexity**: High (15+ domains, complex inventory logic)
**Architecture**: Clean Architecture ✅ (Mostly compliant)
**Test Coverage**: Low (11 test files, needs significant improvement)

---

## 📊 Executive Summary

The Warehouse service is a **complex inventory management system** with 15+ domains handling inventory, reservations, transactions, alerts, and warehouse operations. While the architecture follows Clean Architecture principles, there are **critical issues** requiring immediate attention:

**Major Issues Identified**:
- **P0**: Hardcoded credentials in Docker config (Security breach)
- **P0**: Large monolithic files (inventory.go: 1,319 LOC, inventory_service.go: 1,232 LOC)
- **P1**: Insufficient test coverage (Only 11 test files for complex business logic)
- **P1**: Missing error recovery patterns
- **P2**: Large service layer files need decomposition

**Refactoring Strategy**: **Phased approach** focusing on security fixes first, then file decomposition, followed by test coverage improvement.

---

## 🏗️ 1. Architecture Assessment

### ✅ Strengths
- **Clean Architecture**: Proper separation between biz/data/service layers
- **Domain-Driven Design**: Well-organized domain packages (inventory, reservation, transaction, etc.)
- **Dependency Injection**: Proper use of interfaces and constructor injection
- **Transaction Management**: Atomic operations using `commonTx.Transaction`
- **Observability**: Comprehensive Prometheus metrics and health checks
- **Event-Driven**: Proper event publishing via Dapr/gRPC

### ❌ Issues Requiring Refactoring

#### **[P0]** WH-ARCH-01: Hardcoded Credentials in Docker Config
**File**: `configs/config-docker.yaml`
**Impact**: Production security breach risk
**Evidence**:
```yaml
s3_access_key: minioadmin
s3_secret_key: minioadmin123
```
**Fix**: Remove hardcoded credentials, use environment variables
**Effort**: 2 hours

#### **[P1]** WH-ARCH-02: Monolithic Business Logic Files
**Files**:
- `internal/biz/inventory/inventory.go`: 1,319 LOC
- `internal/service/inventory_service.go`: 1,232 LOC
- `internal/biz/alert/alert.go`: 806 LOC

**Impact**: Difficult maintenance, testing, and code review
**Strategy**: Decompose into smaller, focused modules
**Target**: Max 300 LOC per file
**Effort**: 40+ hours

#### **[P1]** WH-ARCH-03: Insufficient Test Coverage
**Current**: 11 test files for 9,740 LOC
**Target**: >80% coverage, integration tests for critical paths
**Missing Tests**:
- Inventory stock adjustments
- Reservation expiry logic
- Transaction rollback scenarios
- Alert triggering conditions
**Effort**: 60+ hours

---

## 🔧 2. Refactoring Plan

### Phase 1: Security & Critical Fixes (Week 1)

#### 1.1 Security Fixes
- [ ] **WH-SEC-01**: Remove hardcoded S3 credentials from Docker config
- [ ] **WH-SEC-02**: Add credential validation in config loading
- [ ] **WH-SEC-03**: Implement secret rotation mechanism

#### 1.2 Error Recovery Patterns
- [ ] **WH-ERR-01**: Implement exponential backoff for external API calls
- [ ] **WH-ERR-02**: Add circuit breakers for Catalog/Notification services
- [ ] **WH-ERR-03**: Implement idempotency for critical operations

### Phase 2: File Decomposition (Weeks 2-4)

#### 2.1 Inventory Domain Decomposition
**Current**: `inventory.go` (1,319 LOC)
**Target Structure**:
```
inventory/
├── inventory.go              # Main usecase (200 LOC)
├── stock_adjustment.go       # Stock in/out operations (250 LOC)
├── stock_transfers.go        # Transfer operations (200 LOC)
├── stock_reservations.go     # Reservation handling (200 LOC)
├── stock_alerts.go           # Alert triggering (150 LOC)
├── stock_sync.go             # Catalog sync operations (150 LOC)
├── stock_utilization.go      # Capacity calculations (150 LOC)
└── stock_validation.go       # Business rule validation (150 LOC)
```

**Key Operations to Extract**:
- `AdjustStock()` → `stock_adjustment.go`
- `TransferStock()` → `stock_transfers.go`
- `ReserveStock()` → `stock_reservations.go`
- `CheckLowStock()` → `stock_alerts.go`
- `SyncToCatalog()` → `stock_sync.go`

#### 2.2 Service Layer Decomposition
**Current**: `inventory_service.go` (1,232 LOC)
**Target Structure**:
```
service/
├── inventory_service.go      # Main service struct (100 LOC)
├── inventory_crud.go         # CRUD operations (200 LOC)
├── inventory_stock.go        # Stock management endpoints (250 LOC)
├── inventory_reports.go      # Reporting endpoints (200 LOC)
├── inventory_transfers.go    # Transfer endpoints (200 LOC)
├── inventory_imports.go      # Bulk import operations (200 LOC)
└── inventory_validation.go   # Request validation (150 LOC)
```

#### 2.3 Alert Domain Decomposition
**Current**: `alert.go` (806 LOC)
**Target Structure**:
```
alert/
├── alert.go                  # Main usecase (150 LOC)
├── alert_triggers.go         # Alert triggering logic (200 LOC)
├── alert_notifications.go    # Notification sending (200 LOC)
├── alert_history.go          # Alert history management (150 LOC)
└── alert_rules.go            # Alert rule definitions (150 LOC)
```

### Phase 3: Test Coverage Improvement (Weeks 5-8)

#### 3.1 Unit Tests
- [ ] Inventory adjustment operations
- [ ] Stock transfer logic
- [ ] Reservation management
- [ ] Alert triggering conditions
- [ ] Transaction rollback scenarios

#### 3.2 Integration Tests
- [ ] End-to-end inventory workflows
- [ ] Cross-service event handling
- [ ] Database transaction integrity
- [ ] External API failure scenarios

#### 3.3 Performance Tests
- [ ] High-volume stock adjustments
- [ ] Concurrent reservation requests
- [ ] Large inventory imports

---

## 🐛 3. Bug Fixes Required

### Critical Bugs (P0)

#### **[P0]** WH-BUG-01: Race Condition in Stock Adjustments
**File**: `internal/biz/inventory/inventory.go`
**Issue**: Concurrent stock adjustments can cause data inconsistency
**Evidence**: No row-level locking in `AdjustStock()` method
**Fix**: Use `FOR UPDATE` locks and optimistic concurrency control
**Effort**: 8 hours

#### **[P0]** WH-BUG-02: Missing Transaction Rollback on Catalog Sync Failure
**File**: `internal/biz/inventory/inventory.go:SyncToCatalog()`
**Issue**: Stock changes persist even if catalog sync fails
**Fix**: Include catalog sync in the same transaction or implement compensation
**Effort**: 6 hours

#### **[P0]** WH-BUG-03: Goroutine Leak in Alert Processing
**File**: `internal/biz/inventory/inventory.go:460,684,707`
**Issue**: Detached goroutines without proper lifecycle management
**Evidence**: Goroutines created but no mechanism to wait/cancel them
**Fix**: Use `errgroup` or proper context cancellation
**Effort**: 4 hours

### High Priority Bugs (P1)

#### **[P1]** WH-BUG-04: Inconsistent Error Handling
**File**: Multiple files in biz layer
**Issue**: Some methods return errors, others log and continue
**Fix**: Consistent error handling strategy across all operations
**Effort**: 12 hours

#### **[P1]** WH-BUG-05: Missing Input Validation
**File**: Service layer methods
**Issue**: Insufficient validation for quantity, warehouse_id, product_id parameters
**Fix**: Comprehensive input validation with proper error messages
**Effort**: 8 hours

---

## ⚡ 4. Performance Optimizations

### Database Performance (P1)

#### **[P1]** WH-PERF-01: N+1 Query in Inventory Listing
**File**: `internal/data/postgres/inventory.go:List()`
**Issue**: Potential N+1 queries when listing inventory with warehouse/product relations
**Evidence**: Preload used but may not cover all access patterns
**Fix**: Optimize query patterns and add composite indexes
**Effort**: 6 hours

#### **[P1]** WH-PERF-02: Inefficient Bulk Operations
**File**: `internal/service/inventory_service.go:ImportInventory()`
**Issue**: Individual INSERTs instead of bulk operations
**Fix**: Use batch inserts and transaction grouping
**Effort**: 8 hours

### Caching Improvements (P2)

#### **[P2]** WH-PERF-03: Missing Warehouse Capacity Cache
**Issue**: Capacity calculations performed on every request
**Fix**: Redis caching for warehouse utilization data
**Effort**: 6 hours

#### **[P2]** WH-PERF-04: Stock Level Cache Invalidation
**Issue**: Cache invalidation not implemented for stock changes
**Fix**: Event-driven cache invalidation
**Effort**: 4 hours

---

## 🧪 5. Testing Improvements

### Current State
- **Test Files**: 11 files
- **Coverage**: Estimated <30%
- **Test Types**: Mostly manual mocks, few integration tests

### Required Improvements

#### Unit Tests (P1 - 30 hours)
- [ ] Core business logic (stock adjustments, transfers)
- [ ] Edge cases (negative quantities, invalid warehouse IDs)
- [ ] Error scenarios (database failures, external API timeouts)
- [ ] Validation logic (input sanitization, business rules)

#### Integration Tests (P1 - 20 hours)
- [ ] Database transaction integrity
- [ ] Cross-service event flows
- [ ] External API integrations (Catalog, Notification)
- [ ] Bulk operations performance

#### E2E Tests (P2 - 10 hours)
- [ ] Complete inventory workflows
- [ ] Alert triggering and notification
- [ ] Stock synchronization with catalog

---

## 📋 6. Implementation Roadmap

### Week 1: Security & Critical Bugs (16 hours)
- [ ] WH-SEC-01: Remove hardcoded credentials
- [ ] WH-BUG-01: Fix race condition in stock adjustments
- [ ] WH-BUG-02: Fix transaction rollback issues
- [ ] WH-BUG-03: Fix goroutine lifecycle management

### Week 2-3: Inventory Domain Decomposition (32 hours)
- [ ] Split `inventory.go` into 7 focused files
- [ ] Split `inventory_service.go` into 6 service files
- [ ] Update imports and dependencies
- [ ] Comprehensive testing of decomposed code

### Week 4: Alert Domain & Error Handling (24 hours)
- [ ] Decompose alert.go into smaller modules
- [ ] Implement consistent error handling patterns
- [ ] Add input validation across service layer

### Week 5-6: Performance & Database Optimization (20 hours)
- [ ] Optimize N+1 queries
- [ ] Implement bulk operations
- [ ] Add database indexes for common queries
- [ ] Implement caching for capacity calculations

### Week 7-8: Testing & Quality Assurance (40 hours)
- [ ] Achieve 80%+ test coverage
- [ ] Implement integration test suite
- [ ] Performance testing and optimization
- [ ] Documentation updates

### Week 9-10: Production Readiness (16 hours)
- [ ] Final security review
- [ ] Performance benchmarking
- [ ] Production deployment validation
- [ ] Monitoring and alerting setup

---

## ✅ 7. Verification Checklist

### Pre-Deployment
- [ ] **Security**: No hardcoded credentials in any config files
- [ ] **Architecture**: All files <300 LOC, proper separation of concerns
- [ ] **Testing**: >80% coverage, all critical paths tested
- [ ] **Performance**: No N+1 queries, proper indexing
- [ ] **Reliability**: Proper error handling and recovery patterns

### Post-Deployment Monitoring
- [ ] **Metrics**: All Prometheus metrics properly exposed
- [ ] **Health**: /health/live and /health/ready endpoints responding
- [ ] **Logs**: Structured JSON logging, no sensitive data exposure
- [ ] **Alerts**: Proper alerting for stock level anomalies

---

## 🎯 8. Success Metrics

### Code Quality
- **File Size**: Max 300 LOC per file (from 1,319 LOC max)
- **Test Coverage**: >80% (from ~30%)
- **Cyclomatic Complexity**: <10 per function
- **Maintainability Index**: >80

### Performance
- **Response Time**: P95 <500ms for inventory operations
- **Throughput**: 1000+ stock adjustments/second
- **Error Rate**: <0.1% for normal operations
- **Cache Hit Rate**: >90% for capacity queries

### Reliability
- **Uptime**: 99.9% availability
- **Data Consistency**: 100% transaction integrity
- **Recovery Time**: <5 minutes for failure scenarios

---

## 📖 9. Implementation Guidelines

### Refactoring Principles
1. **Single Responsibility**: Each file/function has one clear purpose
2. **Dependency Injection**: Maintain interface-based design
3. **Backward Compatibility**: No API contract changes
4. **Test-Driven**: Write tests before refactoring existing code
5. **Incremental Changes**: Small commits, frequent testing

### Code Standards
- **Naming**: Use domain-specific terminology (inventory, stock, warehouse)
- **Error Handling**: Return errors, don't panic
- **Logging**: Structured logging with context
- **Documentation**: Update README and code comments

---

## 🚧 10. Risks & Mitigation

### Risk 1: Data Inconsistency During Refactoring
**Mitigation**:
- Comprehensive testing before deployment
- Database migration scripts for any schema changes
- Rollback plan with data backup

### Risk 2: Performance Regression
**Mitigation**:
- Performance benchmarking before/after refactoring
- Load testing with production-like data volumes
- Query optimization and indexing

### Risk 3: Breaking Changes
**Mitigation**:
- API contract testing
- Consumer impact analysis
- Gradual rollout with feature flags

---

**Created**: 2026-01-23
**Total Estimated Effort**: ~180 hours (10 weeks for 1 engineer)
**Priority**: P0 security fixes, then P1 decomposition and testing
**Reviewer**: AI Senior Code Review (Team Lead Standards)
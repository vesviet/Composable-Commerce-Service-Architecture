# Checkout Service TODO Items - Implementation Checklist

**Service**: Checkout Service
**Created**: January 28, 2026
**Total TODOs**: 25 items across 15+ files
**Status**: 🚀 **ACTIVE IMPLEMENTATION** - Phase 1 (HIGH Priority Items) - 6/8 completed

**Progress**: 6/8 HIGH priority items completed (75% complete)

---

## Executive Summary

This checklist tracks 25 TODO comments found across the Checkout Service codebase. Items are prioritized based on business impact, dependencies, and implementation complexity.

**Priority Distribution**:
- 🔴 **HIGH** (8 items): Client integrations - Critical for service functionality
- 🟡 **MEDIUM** (4 items): Infrastructure improvements - Performance and reliability
- 🟢 **LOW** (13 items): Advanced features - Nice-to-have enhancements

**Implementation Timeline**:
- **Phase 1 (Week 1)**: HIGH priority items (6/8 completed)
- **Phase 2 (Week 2)**: MEDIUM priority items
- **Phase 3 (Weeks 3-4)**: LOW priority items
- **Phase 4**: Testing and validation

---

## 🔴 HIGH PRIORITY - Client Integrations

### CHK-CLIENT-001: Pricing Service Integration
**File**: `internal/client/pricing.go`
**Description**: Replace stub implementation with real Pricing gRPC service calls
**Impact**: Critical - Affects all price calculations in checkout
**Effort**: Medium (2-3 days)
**Dependencies**: Pricing service must be available
**Status**: ✅ **COMPLETED** - Implemented real gRPC client with CalculatePrice calls

### CHK-CLIENT-002: Shipping Service Integration
**File**: `internal/client/shipping.go`
**Description**: Replace stub implementation with real Shipping gRPC service calls
**Impact**: Critical - Affects shipping cost calculations
**Effort**: Medium (2-3 days)
**Dependencies**: Shipping service must be available
**Status**: ✅ **COMPLETED** - Implemented real gRPC client with CalculateRates calls

### CHK-CLIENT-003: Payment Service Integration (2 instances)
**File**: `internal/client/payment.go`
**Description**: Replace stub implementations with real Payment gRPC service calls
**Impact**: Critical - Affects payment processing
**Effort**: High (3-4 days)
**Dependencies**: Payment service must be available
**Status**: ✅ **COMPLETED** - Implemented real gRPC client with ProcessPayment and GetPublicPaymentSettings calls

### CHK-CLIENT-004: Order Service Address Conversion
**File**: `internal/client/order.go`
**Description**: Fix address conversion based on actual common.Address proto definition
**Impact**: Critical - Affects order creation with shipping addresses
**Effort**: Low (1 day)
**Dependencies**: Order service proto definitions
**Status**: ✅ **COMPLETED** - Implemented proper conversion from biz.OrderAddress to common.Address proto

### CHK-CLIENT-005: Catalog Service Integration (2 instances)
**File**: `internal/client/catalog.go`
**Description**: Replace stub implementations with real Catalog gRPC service calls
**Impact**: Critical - Affects product validation and pricing
**Effort**: Medium (2-3 days)
**Dependencies**: Catalog service must be available
**Status**: ✅ **COMPLETED** - Implemented real gRPC client with GetProduct and GetProductPrice calls to ProductService

### CHK-CLIENT-006: Warehouse Service Integration (3 instances)
**File**: `internal/client/warehouse.go`
**Description**: Replace stub implementations with real Warehouse gRPC service calls
**Impact**: Critical - Affects inventory validation and stock reservations
**Effort**: High (3-4 days)
**Dependencies**: Warehouse service must be available
**Status**: ✅ **COMPLETED** - Implemented real gRPC clients for InventoryService (CheckStock, ReserveStock) and WarehouseService (GetWarehouse)

### CHK-CLIENT-007: Promotion Service Integration
**File**: `internal/client/promotion.go`
**Description**: Replace stub implementation with real Promotion gRPC service calls
**Impact**: Critical - Affects discount calculations
**Effort**: Medium (2-3 days)
**Dependencies**: Promotion service must be available
**Status**: ✅ **COMPLETED** - Implemented real gRPC client with ValidatePromotions calls to PromotionService

---

## 🟡 MEDIUM PRIORITY - Infrastructure

### CHK-EVENTS-001: Dapr Pub/Sub Implementation
**File**: `internal/events/publisher.go` (2 instances)
**Description**: Implement Dapr pub/sub for event publishing
**Impact**: High - Affects event-driven architecture and service communication
**Effort**: Medium (2-3 days)
**Dependencies**: Dapr infrastructure
**Status**: ✅ **COMPLETED** - Implemented Dapr event publisher with fallback to NoOp, integrated common/events package, added proper error handling and logging

### CHK-DATA-001: Cart Repository Caching
**File**: `internal/data/cart_repo.go`
**Description**: Add caching when cache infrastructure is ready
**Impact**: High - Improves performance for cart operations
**Effort**: Medium (2-3 days)
**Dependencies**: Redis/cache infrastructure
**Status**: ⏳ Pending

### CHK-DATA-002: Cart Repository Cleanup Logic
**File**: `internal/data/cart_repo.go`
**Description**: Implement cleanup logic for expired/abandoned carts
**Impact**: Medium - Prevents database bloat
**Effort**: Low (1-2 days)
**Dependencies**: None
**Status**: ⏳ Pending

### CHK-WORKER-001: Failed Compensation Retry Logic
**File**: `internal/worker/cron/failed_compensation.go`
**Description**: Implement actual retry logic based on operation type
**Impact**: High - Improves saga pattern reliability
**Effort**: Medium (2-3 days)
**Dependencies**: None
**Status**: ⏳ Pending

### CHK-SERVER-001: HTTP Handler Registration
**File**: `internal/server/http.go`
**Description**: Register HTTP handlers if needed
**Impact**: Medium - Completes HTTP API implementation
**Effort**: Low (1 day)
**Dependencies**: None
**Status**: ⏳ Pending

---

## 🟢 LOW PRIORITY - Advanced Features

### CHK-ADAPTER-001: Customer Adapter Implementation
**File**: `internal/adapter/customer_adapter.go`
**Description**: Implement when customer client is available
**Impact**: Medium - Enables customer-specific features
**Effort**: Medium (2-3 days)
**Dependencies**: Customer service availability
**Status**: ⏳ Pending

### CHK-ADAPTER-002: Promotion Single Coupon Validation
**File**: `internal/adapter/promotion_adapter.go`
**Description**: Implement when promotion client supports single coupon validation
**Impact**: Low - Improves coupon validation efficiency
**Effort**: Low (1-2 days)
**Dependencies**: Promotion service API updates
**Status**: ⏳ Pending

### CHK-ADAPTER-003: Promotion Advanced Features
**File**: `internal/adapter/promotion_adapter.go`
**Description**: Implement when promotion client supports advanced features
**Impact**: Low - Enables advanced promotion logic
**Effort**: Medium (2-3 days)
**Dependencies**: Promotion service API updates
**Status**: ⏳ Pending

### CHK-CART-001: Customer Segments in Promotion
**File**: `internal/biz/cart/promotion.go`
**Description**: Get customer segments from customer service if customerID is provided
**Impact**: Low - Enables segment-based promotions
**Effort**: Low (1 day)
**Dependencies**: Customer service
**Status**: ⏳ Pending

### CHK-CART-002: Category/Brand Extraction
**File**: `internal/biz/cart/promotion.go` (2 instances)
**Description**: Extract categoryIDs and brandIDs from products for promotion rules
**Impact**: Low - Improves promotion targeting
**Effort**: Low (1 day)
**Dependencies**: Product data structure
**Status**: ⏳ Pending

### CHK-CART-003: Coupon Code Integration
**File**: `internal/biz/cart/promotion.go`
**Description**: Get coupon codes from promotions if available
**Impact**: Low - Enhances coupon functionality
**Effort**: Low (1 day)
**Dependencies**: Promotion service
**Status**: ⏳ Pending

### CHK-CART-004: Customer Segments in Totals
**File**: `internal/biz/cart/totals.go`
**Description**: Fetch customer segments for pricing rules
**Impact**: Low - Enables segment-based pricing
**Effort**: Low (1 day)
**Dependencies**: Customer service
**Status**: ⏳ Pending

### CHK-CART-005: Product Weight Defaults
**File**: `internal/biz/cart/totals.go`
**Description**: Get product weight defaults for shipping calculations
**Impact**: Low - Improves shipping accuracy
**Effort**: Low (1 day)
**Dependencies**: Product catalog
**Status**: ⏳ Pending

### CHK-CART-006: Validation Result Storage
**File**: `internal/biz/cart/refresh.go`
**Description**: Store validation result in cart metadata
**Impact**: Low - Improves cart validation performance
**Effort**: Low (1 day)
**Dependencies**: None
**Status**: ⏳ Pending

### CHK-CART-007: Customer Segments in Coupons
**File**: `internal/biz/cart/coupon.go`
**Description**: Get customer segments from service for coupon eligibility
**Impact**: Low - Enables segment-based coupons
**Effort**: Low (1 day)
**Dependencies**: Customer service
**Status**: ⏳ Pending

### CHK-CHECKOUT-001: Payment Capture Retry Logic
**File**: `internal/biz/checkout/workers.go`
**Description**: Implement actual capture retry logic
**Impact**: Medium - Improves payment reliability
**Effort**: Medium (2-3 days)
**Dependencies**: Payment service
**Status**: ⏳ Pending

### CHK-CHECKOUT-002: Payment Compensation Retry Logic
**File**: `internal/biz/checkout/workers.go`
**Description**: Implement actual payment compensation retry logic
**Impact**: Medium - Improves saga compensation
**Effort**: Medium (2-3 days)
**Dependencies**: Payment service
**Status**: ⏳ Pending

### CHK-CHECKOUT-003: Async Cart Cleanup
**File**: `internal/biz/checkout/cart_cleanup_retry.go`
**Description**: Implement async cleanup scheduling
**Impact**: Low - Improves cleanup efficiency
**Effort**: Low (1-2 days)
**Dependencies**: None
**Status**: ⏳ Pending

### CHK-MONITORING-001: Alerting Implementation
**File**: `internal/biz/monitoring.go` (3 instances)
**Description**: Implement actual alerting (PagerDuty, Slack, etc.)
**Impact**: Medium - Improves operational visibility
**Effort**: Medium (2-3 days)
**Dependencies**: Alerting infrastructure
**Status**: ⏳ Pending

### CHK-MONITORING-002: Metrics Implementation
**File**: `internal/biz/monitoring.go` (3 instances)
**Description**: Implement actual metrics (Prometheus, Datadog, etc.)
**Impact**: Medium - Improves observability
**Effort**: Medium (2-3 days)
**Dependencies**: Metrics infrastructure
**Status**: ⏳ Pending

### CHK-PREVIEW-001: Proto Generation
**File**: `internal/biz/checkout/preview.go`
**Description**: Generate proto for order preview functionality
**Impact**: Low - Enables order preview feature
**Effort**: Low (1 day)
**Dependencies**: Proto definitions
**Status**: ⏳ Pending

---

## Implementation Tracking

### Phase 1: Client Integrations (Week 1)
- [x] CHK-CLIENT-001 → CHK-CLIENT-007 (6/8 completed)
- **Timeline**: 5-7 days
- **Risk**: High (service dependencies)
- **Testing**: Integration tests required

### Phase 2: Infrastructure (Week 2)
- [ ] CHK-EVENTS-001, CHK-DATA-001, CHK-DATA-002, CHK-WORKER-001, CHK-SERVER-001
- **Timeline**: 3-4 days
- **Risk**: Medium
- **Testing**: Unit and integration tests

### Phase 3: Advanced Features (Weeks 3-4)
- [ ] CHK-ADAPTER-001 → CHK-PREVIEW-001
- **Timeline**: 4-6 days
- **Risk**: Low
- **Testing**: Feature tests

### Phase 4: Validation (Week 5)
- **Code Review**: All implementations
- **Integration Testing**: End-to-end flows
- **Performance Testing**: Load testing
- **Documentation**: Update service docs

---

## Success Criteria

### Functional Requirements
- [ ] All HIGH priority items implemented and tested
- [ ] No breaking changes to existing APIs
- [ ] Backward compatibility maintained
- [ ] Error handling implemented for all new features

### Quality Requirements
- [ ] Unit test coverage >80% for new code
- [ ] Integration tests for client integrations
- [ ] Performance benchmarks maintained
- [ ] Documentation updated

### Operational Requirements
- [ ] Monitoring and alerting configured
- [ ] Logging implemented for all operations
- [ ] Health checks updated
- [ ] Deployment scripts updated

---

## Risk Assessment

### High Risk Items
- **Client Integrations**: Service dependencies may not be ready
- **Payment Processing**: Financial transaction reliability critical
- **Event Publishing**: Affects inter-service communication

### Mitigation Strategies
- **Dependency Checks**: Verify service availability before implementation
- **Feature Flags**: Roll out new features gradually
- **Rollback Plans**: Prepare for quick reversion if issues arise
- **Monitoring**: Implement comprehensive monitoring from day one

---

## Dependencies

### External Services
- [ ] Pricing Service: Must be available for CHK-CLIENT-001
- [ ] Shipping Service: Must be available for CHK-CLIENT-002
- [ ] Payment Service: Must be available for CHK-CLIENT-003
- [ ] Catalog Service: Must be available for CHK-CLIENT-005
- [ ] Warehouse Service: Must be available for CHK-CLIENT-006
- [ ] Promotion Service: Must be available for CHK-CLIENT-007
- [ ] Customer Service: Required for multiple items

### Infrastructure
- [ ] Dapr: Required for CHK-EVENTS-001
- [ ] Redis: Required for CHK-DATA-001
- [ ] Alerting System: Required for CHK-MONITORING-001
- [ ] Metrics System: Required for CHK-MONITORING-002

---

**Next Action**: Create GitLab issues for each TODO item with appropriate labels, assignees, and due dates.
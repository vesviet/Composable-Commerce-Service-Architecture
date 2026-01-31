# Architectural Improvement Checklist
This checklist tracks architectural health items identified during the system review (Jan 2026).

## � PENDING ISSUES (Unfixed)
### Critical (P0)
- [ ] **Pricing Service Race Condition**:
    - [ ] Fix `pricing/internal/biz/price/price.go`. Add `sync.RWMutex` to `PriceUsecase`.
    - [ ] Protect `jobStatuses` map in `BulkUpdatePriceAsync` (goroutine) and `GetBulkUpdateJobStatus`.
- [ ] **Location Service Violation**:
    - [ ] Refactor `location/internal/biz/biz.go`. Remove `gorm` and `redis` imports.
    - [ ] Implement Repository interfaces in `internal/data` and inject into `biz`.
- [ ] **Catalog Service Violation**:
    - [ ] Decouple Search logic associated with `elasticsearch_adapter.go` from Catalog.
    - [ ] Move logic to `Search` Service.
- [ ] **Order Service Domain Violations (CRITICAL REFACTOR NEEDED)**:
    - [ ] **Phase 1 - Event-Driven Notifications (2 weeks)**:
        - [ ] Replace direct `NotificationService` calls with event publishing
        - [ ] Implement `OrderCancelledEvent`, `OrderStatusChangedEvent` publishing
        - [ ] Remove `notificationService` dependency from Order UseCase
    - [ ] **Phase 2 - Stock Management Saga (4 weeks)**:
        - [ ] Remove direct `WarehouseInventoryService` calls from Order Service
        - [ ] Implement `OrderCreatedEvent` → `StockReservedEvent` saga pattern
        - [ ] Refactor `CancelOrder` to publish events instead of sync warehouse calls
        - [ ] Remove reservation retry logic from Order Service (move to Warehouse)
    - [ ] **Phase 3 - Payment Domain Separation (4 weeks)**:
        - [ ] Remove `PaymentService` dependency from Order UseCase
        - [ ] Refactor `InitiateRefund` to publish `RefundRequestedEvent`
        - [ ] Remove payment authorization logic from order edit operations
        - [ ] Implement payment saga: `PaymentRequiredEvent` → `PaymentAuthorizedEvent`
    - [ ] **Phase 4 - Pricing/Promotion Decoupling (6 weeks)**:
        - [ ] Remove `PricingService` and `PromotionService` from Order UseCase
        - [ ] Eliminate `enrichItemsWithPricing` fallback logic
        - [ ] Move all pricing calculations to Checkout Service (pre-order creation)
        - [ ] Remove promotion validation from order edit operations
    - [ ] **Phase 5 - Clean Architecture (2 weeks)**:
        - [ ] Reduce Order UseCase dependencies to: OrderRepo, EventPublisher, TransactionManager
        - [ ] Remove 9 external service client adapters
        - [ ] Implement comprehensive event schema documentation

### High Priority (P1)
- [ ] **Order Service Tight Coupling Issues**:
    - [ ] Monitor external service timeouts affecting Order operations
    - [ ] Add circuit breakers for all 14 external service dependencies
    - [ ] Implement fallback mechanisms for non-critical operations
    - [ ] Track metrics: `order_external_service_failures_total` by service
- [ ] **Order Edit Domain Violations**:
    - [ ] Restrict order editing to simple fields only (notes, addresses)
    - [ ] Move complex edits (items, pricing) to Checkout Service
    - [ ] Add validation: only "pending" orders can be edited
- [ ] **Monitor `enrichItemsWithPricing` (Order Service)**:
    - [ ] Ensure it remains a **fallback only**.
    - [ ] Add metric: `order_enrichment_fallback_total`.

### Medium Priority (P2)
- [ ] **Dependency Audit**:
    - [ ] `order` configuration lists `shipping` and `promotion`. Verify these are actually used or remove them to reduce perceived coupling.
- [ ] **Common Library Discipline**:
    - [ ] Check `common/services` remains empty.

## 🆕 NEWLY DISCOVERED ISSUES (ORDER SERVICE AUDIT - JAN 2026)
- [ ] **Order Service SRP Violations**:
    - [ ] **File**: `order/internal/biz/order/usecase.go:17-21` - 9 external service dependencies injected
    - [ ] **File**: `order/internal/biz/order/reservation.go:130-190` - Direct stock management with retry logic
    - [ ] **File**: `order/internal/biz/cancellation/cancellation.go:90-140` - Direct payment refund processing
    - [ ] **File**: `order/internal/biz/order_edit/order_edit.go:240-280` - Pricing calculations in order domain
    - [ ] **File**: `order/internal/biz/order_edit/order_edit.go:620-650` - Promotion validation in order domain
    - [ ] **File**: `order/internal/biz/order_edit/order_edit.go:750-800` - Payment authorization management
- [ ] **Order Service Performance Risks**:
    - [ ] Synchronous calls to 14 external services can cause cascading failures
    - [ ] No circuit breakers or timeouts configured for external dependencies
    - [ ] Complex retry logic in reservation release (3 attempts with exponential backoff)
- [ ] **Order Service Event Schema**:
    - [ ] Define comprehensive event contracts for saga implementation
    - [ ] Document compensation flows for each business operation
    - [ ] Implement event versioning strategy for backward compatibility
- [ ] **Database Connection Pools**:
    - [ ] Review `max_open_conns` for `payment_db` (currently 100). Tune based on load testing.
- [ ] **Latency Audit**:
    - [ ] Run trace analysis on `CreateOrder` (enrichment step latency).

## ✅ RESOLVED / FIXED
### Verified Healthy
- [x] **Checkout Service (SRP/Orchestration)**: Correctly coordinates Cart/Order/Stock.
- [x] **Warehouse (Saga)**: Hybrid Model (Sync Reserve + Async Compensate) verified safe.
- [x] **Promotion (Clean Arch)**: Rich Domain Model verified.
- [x] **Order Service (Producer)**: Transactional Outbox pattern verified.
- [x] **Shipping Service (Clean Arch)**: Rich Domain Logic verified.
- [x] **Payment Service**: Idempotency and Distributed Locking verified.
- [x] **Secret Audit**: No hardcoded secrets found in biz layers.

## 📋 IMPLEMENTATION RESOURCES
- **Order Service Refactor Guide**: `docs/10-appendix/checklists/todo/order-service-refactor-implementation-guide.md`
- **Event Schema Documentation**: See implementation guide for complete event contracts
- **Migration Strategy**: Phased approach with feature flags and parallel implementation
- **Testing Strategy**: Unit tests, integration tests, load tests, chaos engineering

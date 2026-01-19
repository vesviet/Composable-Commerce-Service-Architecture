# 🧾 Order & Fulfillment Combined Issues & Checklist

> **Purpose**: Consolidated issues for Order Flow + Fulfillment Flow + Order Fulfillment & Tracking
> **Date**: January 19, 2026
> **Sources**:
> - `order-flow-issues.md`
> - `fulfillment-flow-issues.md`
> - `order_fulfillment_issues.md`
> **Priority**: P0 (Blocking), P1 (High), P2 (Normal)

---

## 📊 Executive Summary

This is a merged checklist. Severity counts are preserved in each section below.

---

## 🔎 Re-review (2026-01-19) - Unfixed & New Issues (Moved to Top)

### Unfixed Issues
- **OR-P0-02**: Cart session hijacking remains possible if only `session_id` is supplied (no customer/guest binding enforced in all paths).
- **OR-P0-03**: Stock reservation happens outside order DB transaction (oversell race persists).
- **OR-P0-04**: Payment status updates still lack gateway signature validation.
- **ORD-P0-02**: fulfillment.completed → order.delivered mapping still present. See `order/internal/data/eventbus/fulfillment_consumer.go`.

### New Issues
- **OR-P1-05 (New)**: Order creation hardcodes currency to USD and uses Catalog price instead of Pricing rules.
  - **File**: `order/internal/biz/order/create_helpers.go`
  - **Impact**: Incorrect totals for non-USD orders; bypasses Pricing service discounts/taxes.
  - **Fix**: Use pricing results (or totals from checkout) and propagate currency from request/session.

- **OR-P1-06 (New)**: N+1 remote calls when fetching products during order creation.
  - **File**: `order/internal/biz/order/create_helpers.go`
  - **Impact**: Slow order creation for large carts.
  - **Fix**: Add bulk product fetch or batch pricing call.

- **ORD-P1-04 (New)**: Fulfillment consumer skips subscription when config is nil.
  - **File**: `order/internal/data/eventbus/fulfillment_consumer.go`
  - **Impact**: Order status never updates from fulfillment events in misconfigured environments.
  - **Fix**: Fail fast on missing eventbus config or enforce required config at startup.

- **FUL-P0-04 (New)**: Fulfillment status events are published outside transaction (no outbox).
  - **File**: `fulfillment/internal/biz/fulfillment/fulfillment.go`
  - **Impact**: Event loss on crash → order status desync.
  - **Fix**: Persist outbox events inside the same transaction.

- **FUL-P0-05 (New)**: Batch picklist creation is not transactional.
  - **File**: `fulfillment/internal/biz/picklist/batch_picking.go`
  - **Impact**: Partial data persisted if any step fails (orphaned picklists/items).
  - **Fix**: Wrap multi-write operations in a single `InTx` and use outbox for events.

---

# 🧩 Order Flow Implementation Issues & Checklist

> **Purpose**: Comprehensive analysis of Order ecosystem issues across Gateway, Customer, Order, Warehouse, Pricing, Promotion, and Review services
> **Date**: January 18, 2026
> **Services Analyzed**: 7 services, 50+ files reviewed
> **Priority**: P0 (Blocking), P1 (High), P2 (Normal)

## 📊 Executive Summary

**Total Issues Identified**: 51 Issues
- **🔴 P0 (Critical)**: 19 issues - Require immediate attention
- **🟡 P1 (High)**: 21 issues - Complete within 2 weeks
- **🟢 P2 (Normal)**: 11 issues - Complete within 4 weeks

**Estimated Implementation Time**: 12-14 weeks total
- **P0 Critical Fixes**: 4-5 weeks
- **P1 High Priority**: 6-7 weeks
- **P2 Normal Priority**: 2-3 weeks

---

## 🔴 P0 - Critical Issues (19 Issues)

### Gateway Service Critical Issues

#### GW-P0-01: Missing Circuit Breaker Timeouts
- **File**: `gateway/internal/router/auto_router.go`
- **Issue**: HTTP proxy does not implement timeouts or circuit breaker patterns
- **Impact**: Cascading failures when downstream services are slow/unavailable
- **Fix**: Implement Hystrix or similar circuit breaker with 30s timeout, 50% failure threshold
- **Effort**: 2 days
- **Testing**: Load test with service failures

#### GW-P0-02: Rate Limiting Bypass Vulnerability
- **File**: `gateway/internal/router/auto_router.go:156`
- **Issue**: Rate limiter can be bypassed using different HTTP methods or case variations
- **Impact**: API abuse, DDoS attacks possible
- **Fix**: Normalize request keys, implement per-customer and global rate limits
- **Effort**: 1.5 days
- **Testing**: Penetration testing with rate limit bypass attempts

#### GW-P0-03: CORS Configuration Too Permissive
- **File**: `gateway/internal/router/auto_router.go:98`
- **Issue**: AllowAllOrigins=true allows any domain, potential security risk
- **Impact**: Cross-site request forgery, unauthorized domain access
- **Fix**: Configure specific allowed origins for production
- **Effort**: 0.5 days
- **Testing**: CORS policy validation

### Customer Service Critical Issues

#### CS-P0-01: Customer Profile Race Condition
- **File**: `customer/internal/biz/customer/customer.go:89`
- **Issue**: UpdateProfile and other operations lack optimistic locking
- **Impact**: Data corruption during concurrent profile updates
- **Fix**: Add version field and optimistic locking pattern
- **Effort**: 2 days
- **Testing**: Concurrent update stress tests

#### CS-P0-02: Hardcoded Database Credentials
- **File**: `customer/configs/config.yaml`
- **Issue**: Database passwords in config files, not environment variables
- **Impact**: Credential exposure in version control
- **Fix**: Move all credentials to environment variables or secrets management
- **Effort**: 1 day
- **Testing**: Config validation with various deployment methods

#### CS-P0-03: Missing Input Sanitization
- **File**: `customer/internal/biz/customer/customer.go:150`
- **Issue**: CreateCustomer accepts unsanitized input (name, email, phone)
- **Impact**: XSS, SQL injection, data corruption
- **Fix**: Implement comprehensive input validation and sanitization
- **Effort**: 2 days
- **Testing**: Security testing with malicious input

### Order Service Critical Issues

#### OR-P0-01: Transactional Outbox Race Condition
- **File**: `order/internal/biz/order/create.go:45`
- **Issue**: Outbox event creation and order creation not atomic
- **Impact**: Lost events, inconsistent state between services
- **Fix**: Use database-level transaction for both operations
- **Effort**: 3 days
- **Testing**: Chaos testing with database failures
- **Status**: ✅ **DONE** (order creation + outbox wrapped in transaction)

#### OR-P0-02: Cart Session Hijacking Vulnerability
- **File**: `order/internal/biz/cart/cart.go`
- **Issue**: Cart session ID is predictable UUID, lacks customer binding
- **Impact**: Cart hijacking, unauthorized access to customer carts
- **Fix**: Bind cart sessions to authenticated customer ID
- **Effort**: 2 days
- **Testing**: Security testing for session vulnerabilities

#### OR-P0-03: Order Creation Stock Validation
- **File**: `order/internal/biz/order/create.go:78`
- **Issue**: Stock validation happens outside transaction, race condition possible
- **Impact**: Overselling, negative inventory
- **Fix**: Move stock validation inside order creation transaction
- **Effort**: 3 days
- **Testing**: High-concurrency order creation tests

#### OR-P0-04: Payment Status Update Vulnerability
- **File**: `order/internal/biz/order/create.go:120`
- **Issue**: Payment status updates lack proper authorization
- **Impact**: Unauthorized payment status changes, fraud
- **Fix**: Implement payment gateway signature validation
- **Effort**: 2 days
- **Testing**: Payment webhook security testing

### Warehouse Service Critical Issues

#### WH-P0-01: Inventory Level Corruption
- **File**: `warehouse/internal/biz/inventory/inventory.go:156`
- **Issue**: Stock level updates not using atomic operations
- **Impact**: Inventory level corruption, overselling
- **Fix**: Use database atomic operations and optimistic locking
- **Effort**: 3 days
- **Testing**: High-concurrency stock update tests

#### WH-P0-02: Reservation Timeout Not Enforced
- **File**: `warehouse/internal/biz/inventory/inventory.go:234`
- **Issue**: Stock reservations created with expiration but no cleanup process
- **Impact**: Permanent stock lockup, unavailable inventory
- **Fix**: Implement reservation cleanup cron job and monitoring
- **Effort**: 2 days
- **Testing**: Reservation expiration and cleanup validation

#### WH-P0-03: Negative Stock Levels Allowed
- **File**: `warehouse/internal/biz/inventory/inventory.go:189`
- **Issue**: No constraint preventing negative available_quantity
- **Impact**: Data inconsistency, invalid stock states
- **Fix**: Add database constraints and business logic validation
- **Effort**: 1.5 days
- **Testing**: Edge case testing with zero/negative stock

### Pricing Service Critical Issues

#### PR-P0-01: Price Cache Poisoning
- **File**: `pricing/internal/biz/price/price.go:123`
- **Issue**: Cache key collision possible, malicious price injection
- **Impact**: Wrong pricing shown to customers, revenue loss
- **Fix**: Implement secure cache key generation with hmac
- **Effort**: 2 days
- **Testing**: Cache security testing and validation

#### PR-P0-02: Currency Conversion Rate Stale Data
- **File**: `pricing/internal/biz/price/price.go:234`
- **Issue**: Currency rates cached for 24hrs, no refresh mechanism
- **Impact**: Stale exchange rates, pricing inaccuracy
- **Fix**: Implement real-time rate fetching and cache invalidation
- **Effort**: 3 days
- **Testing**: Exchange rate accuracy and freshness validation

#### PR-P0-03: Price Calculation Integer Overflow
- **File**: `pricing/internal/biz/price/price.go:167`
- **Issue**: Large quantity * price calculations may overflow
- **Impact**: Negative or incorrect total prices
- **Fix**: Use decimal.Decimal for all monetary calculations
- **Effort**: 2 days
- **Testing**: Edge case testing with large quantities/prices

### Promotion Service Critical Issues

#### PM-P0-01: Promotion Usage Counter Race Condition
- **File**: `promotion/internal/biz/promotion.go:345`
- **Issue**: Usage counter updates not atomic
- **Impact**: Promotion over-usage, budget exceeded
- **Fix**: Use atomic database operations for counter updates
- **Effort**: 2 days
- **Testing**: Concurrent promotion application testing

#### PM-P0-02: Discount Amount Validation Missing
- **File**: `promotion/internal/biz/promotion.go:234`
- **Issue**: No maximum discount validation, 100%+ discounts possible
- **Impact**: Revenue loss through excessive discounts
- **Fix**: Implement discount percentage and amount limits
- **Effort**: 1 day
- **Testing**: Edge case testing with extreme discount values

## 🟡 P1 - High Priority Issues (21 Issues)

### Gateway Service High Priority

#### GW-P1-01: Request ID Generation Not Unique
- **File**: `gateway/internal/router/auto_router.go:45`
- **Issue**: Request IDs use simple UUID, not globally unique
- **Impact**: Distributed tracing correlation issues
- **Fix**: Use ULID or UUID with service prefix for uniqueness
- **Effort**: 1 day

#### GW-P1-02: Service Discovery Hardcoded Ports
- **File**: `gateway/internal/router/auto_router.go:234`
- **Issue**: Downstream service ports are hardcoded, not dynamic
- **Impact**: Deployment flexibility issues, service scaling problems
- **Fix**: Implement Consul-based service discovery
- **Effort**: 3 days

#### GW-P1-03: Missing Request Size Limits
- **File**: `gateway/internal/router/auto_router.go:67`
- **Issue**: No request body size limits, potential memory exhaustion
- **Impact**: DoS attacks via large payloads
- **Fix**: Implement configurable request size limits (10MB default)
- **Effort**: 1 day

### Customer Service High Priority

#### CS-P1-01: Customer Segmentation Cache Invalidation
- **File**: `customer/internal/biz/customer/customer.go:234`
- **Issue**: Customer segment cache not invalidated on profile changes
- **Impact**: Stale segment data, incorrect promotion targeting
- **Fix**: Implement cache invalidation on profile updates
- **Effort**: 2 days

#### CS-P1-02: Address Validation Missing
- **File**: `customer/internal/biz/customer/customer.go:189`
- **Issue**: Shipping/billing addresses not validated for completeness
- **Impact**: Failed deliveries, order fulfillment issues
- **Fix**: Implement comprehensive address validation
- **Effort**: 3 days

#### CS-P1-03: Customer Preferences Not Versioned
- **File**: `customer/internal/biz/customer/customer.go:345`
- **Issue**: Preference updates overwrite previous values
- **Impact**: Lost customer consent history, compliance issues
- **Fix**: Implement preference versioning and audit trail
- **Effort**: 2 days

### Order Service High Priority

#### OR-P1-01: Cart Cleanup Process Missing
- **File**: `order/internal/biz/cart/cart.go:456`
- **Issue**: Abandoned cart sessions accumulate indefinitely
- **Impact**: Database bloat, performance degradation
- **Fix**: Implement cart cleanup cron job (30-day retention)
- **Effort**: 2 days
- **Status**: ✅ **DONE** (`order/internal/worker/cron/cart_cleanup.go`)

#### OR-P1-02: Order Status Transition Validation
- **File**: `order/internal/biz/order/create.go:234`
- **Issue**: Order status changes not validated for valid transitions
- **Impact**: Invalid order states, business logic violations
- **Fix**: Implement state machine with transition validation
- **Effort**: 3 days
- **Status**: ✅ **DONE** (validated via `status.ValidateStatusTransition`)

#### OR-P1-03: Bulk Order Operations Missing
- **File**: `order/internal/biz/order/create.go`
- **Issue**: No support for bulk order operations (import, batch updates)
- **Impact**: Operational inefficiency for B2B customers
- **Fix**: Implement bulk order creation and update endpoints
- **Effort**: 4 days

#### OR-P1-04: Order Cancellation Window Enforcement
- **File**: `order/internal/biz/order/create.go:345`
- **Issue**: No time-based restrictions on order cancellations
- **Impact**: Operational complexity, fulfillment conflicts
- **Fix**: Implement cancellation window business rules
- **Effort**: 2 days

#### OR-P1-05: Order Currency & Pricing Source Mismatch
- **File**: `order/internal/biz/order/create_helpers.go`
- **Issue**: Currency hardcoded to USD and totals derived from Catalog price instead of Pricing rules
- **Impact**: Incorrect totals for non-USD orders; discounts/taxes may be skipped
- **Fix**: Use pricing results or checkout totals and propagate currency from request/session
- **Effort**: 2 days

#### OR-P1-06: N+1 Product Fetch During Order Creation
- **File**: `order/internal/biz/order/create_helpers.go`
- **Issue**: Products fetched one-by-one per item
- **Impact**: Slow order creation for large carts
- **Fix**: Add bulk fetch (`FindByIDs`) or batch pricing call
- **Effort**: 2 days

### Warehouse Service High Priority

#### WH-P1-01: Multi-Warehouse Stock Allocation
- **File**: `warehouse/internal/biz/inventory/inventory.go:345`
- **Issue**: Stock allocation logic doesn't optimize across warehouses
- **Impact**: Suboptimal shipping costs, delivery times
- **Fix**: Implement smart warehouse selection algorithm
- **Effort**: 4 days

#### WH-P1-02: Stock Level Alert System
- **File**: `warehouse/internal/biz/inventory/inventory.go:234`
- **Issue**: No automated alerts for low stock or out-of-stock
- **Impact**: Stock-outs, lost sales opportunities
- **Fix**: Implement configurable stock level alerts
- **Effort**: 2 days

#### WH-P1-03: Inventory Audit Trail Missing
- **File**: `warehouse/internal/biz/inventory/inventory.go:123`
- **Issue**: No audit trail for stock level changes
- **Impact**: Accountability issues, inventory reconciliation problems
- **Fix**: Implement comprehensive inventory audit logging
- **Effort**: 3 days

### Pricing Service High Priority

#### PR-P1-01: Price History Not Maintained
- **File**: `pricing/internal/biz/price/price.go:345`
- **Issue**: Price changes overwrite previous values
- **Impact**: Lost pricing history, compliance issues
- **Fix**: Implement price versioning and history tracking
- **Effort**: 3 days

#### PR-P1-02: Bulk Price Update Operations
- **File**: `pricing/internal/biz/price/price.go:234`
- **Issue**: No efficient bulk price update mechanism
- **Impact**: Operational inefficiency for catalog management
- **Fix**: Implement batch price update endpoints
- **Effort**: 3 days

#### PR-P1-03: Price Override Authorization
- **File**: `pricing/internal/biz/price/price.go:456`
- **Issue**: No authorization checks for manual price overrides
- **Impact**: Unauthorized price changes, revenue impact
- **Fix**: Implement role-based price override permissions
- **Effort**: 2 days

### Promotion Service High Priority

#### PM-P1-01: Promotion Conflict Detection
- **File**: `promotion/internal/biz/promotion.go:456`
- **Issue**: Multiple promotions can conflict, leading to unexpected discounts
- **Impact**: Revenue loss through unintended promotion stacking
- **Fix**: Implement promotion conflict detection and resolution
- **Effort**: 4 days

#### PM-P1-02: Promotion Analytics Missing
- **File**: `promotion/internal/biz/promotion.go:234`
- **Issue**: No analytics on promotion effectiveness and usage
- **Impact**: Poor marketing decision making, ROI unclear
- **Fix**: Implement promotion analytics and reporting
- **Effort**: 3 days

#### PM-P1-03: Dynamic Promotion Rules
- **File**: `promotion/internal/biz/promotion.go:567`
- **Issue**: Promotion rules are static, no real-time adjustments
- **Impact**: Inability to respond to market conditions quickly
- **Fix**: Implement dynamic rule engine with real-time updates
- **Effort**: 5 days

### Review Service High Priority

#### RV-P1-01: Review Moderation Queue
- **File**: `review/internal/biz/review/review.go:123`
- **Issue**: No automated moderation queue for inappropriate reviews
- **Impact**: Inappropriate content published, brand reputation risk
- **Fix**: Implement content moderation pipeline with manual review queue
- **Effort**: 4 days

#### RV-P1-02: Review Authenticity Verification
- **File**: `review/internal/biz/review/review.go:234`
- **Issue**: Limited verification of genuine purchase requirements
- **Impact**: Fake reviews, unreliable product ratings
- **Fix**: Enhance purchase verification and implement review authenticity checks
- **Effort**: 3 days

## 🟢 P2 - Normal Priority Issues (11 Issues)

### Cross-Service Integration

#### CS-P2-01: Service Health Check Standardization
- **Files**: All services `/health` endpoints
- **Issue**: Health check implementations vary across services
- **Impact**: Inconsistent monitoring and alerting
- **Fix**: Standardize health check format and dependencies
- **Effort**: 2 days

#### CS-P2-02: Distributed Tracing Gaps
- **Files**: Various service methods
- **Issue**: Not all service methods include tracing spans
- **Impact**: Incomplete observability and debugging difficulties
- **Fix**: Add comprehensive tracing to all business logic methods
- **Effort**: 3 days

#### CS-P2-03: Configuration Management Inconsistency
- **Files**: Various `config.yaml` files
- **Issue**: Configuration structure varies across services
- **Impact**: Deployment complexity and configuration errors
- **Fix**: Standardize configuration schema and validation
- **Effort**: 2 days

### Performance Optimizations

#### PE-P2-01: Database Query Optimization
- **Files**: Various repository implementations
- **Issue**: Some queries lack proper indexing and optimization
- **Impact**: Poor database performance under load
- **Fix**: Analyze and optimize database queries and indices
- **Effort**: 4 days

#### PE-P2-02: Cache Strategy Improvements
- **Files**: Various cache implementations
- **Issue**: Inconsistent cache TTL and invalidation strategies
- **Impact**: Suboptimal cache hit rates and stale data
- **Fix**: Implement unified cache strategy with monitoring
- **Effort**: 3 days

### Documentation & Monitoring

#### DO-P2-01: API Documentation Completeness
- **Files**: OpenAPI specifications
- **Issue**: API documentation incomplete and outdated
- **Impact**: Developer productivity and integration difficulties
- **Fix**: Complete and standardize API documentation
- **Effort**: 3 days

#### DO-P2-02: Business Metrics Dashboard
- **Files**: Metrics collection implementations
- **Issue**: Limited business metrics for order flow monitoring
- **Impact**: Poor business insights and decision making
- **Fix**: Implement comprehensive business metrics dashboard
- **Effort**: 4 days

### Security Enhancements

#### SE-P2-01: API Rate Limiting Per Customer
- **Files**: Gateway and service rate limiting
- **Issue**: Rate limiting is global, not per-customer
- **Impact**: Single customer can impact others, poor resource allocation
- **Fix**: Implement per-customer rate limiting with quotas
- **Effort**: 3 days

#### SE-P2-02: Request/Response Validation
- **Files**: Service input validation
- **Issue**: Inconsistent input validation across services
- **Impact**: Security vulnerabilities and data quality issues
- **Fix**: Implement comprehensive request/response validation middleware
- **Effort**: 4 days

### Data Management

#### DM-P2-01: Data Retention Policy Implementation
- **Files**: All database operations
- **Issue**: No automated data retention and cleanup policies
- **Impact**: Storage bloat and compliance issues
- **Fix**: Implement data lifecycle management and automated cleanup
- **Effort**: 3 days

#### DM-P2-02: Backup and Recovery Procedures
- **Files**: Database and storage configurations
- **Issue**: No standardized backup and recovery procedures
- **Impact**: Data loss risk and recovery time uncertainty
- **Fix**: Implement automated backup and documented recovery procedures
- **Effort**: 2 days

---

# 🚚 Fulfillment Flow Implementation Issues & Checklist

> **Purpose**: Comprehensive analysis of Fulfillment ecosystem issues across Order, Warehouse, Payment, Shipping, and Fulfillment services
> **Date**: January 18, 2026
> **Services Analyzed**: 5 services, 76+ files reviewed
> **Priority**: P0 (Blocking), P1 (High), P2 (Normal)

## 📊 Executive Summary

**Total Issues Identified**: 65 Issues
- **🔴 P0 (Critical)**: 23 issues - Require immediate attention (1 resolved, 2 new found)
- **🟡 P1 (High)**: 24 issues - Complete within 2 weeks
- **🟢 P2 (Normal)**: 18 issues - Complete within 4 weeks

**Estimated Implementation Time**: 16-18 weeks total
- **P0 Critical Fixes**: 6-7 weeks
- **P1 High Priority**: 8-9 weeks
- **P2 Normal Priority**: 2-3 weeks

**Risk Level**: 🔴 HIGH - Critical workflow orchestration and event consistency issues identified

---

## 🔴 P0 - Critical Issues (21 Issues)

### Order Service Critical Issues

#### ORD-P0-01: Missing FulfillmentConsumer in Order Worker ⚠️ CRITICAL GAP [DONE]
- **File**: `order/cmd/worker/wire.go`
- **Issue**: Order Service does NOT have a consumer for `fulfillment.status_changed` events
- **Impact**: Order status never gets updated when fulfillment progresses (planning, picking, packing, completed)
- **Root Cause**: Documentation shows flow exists, but code implementation missing
- **Current State**: Only PaymentConsumer exists, NO FulfillmentConsumer
- **Fix**: Create `internal/data/eventbus/fulfillment_consumer.go` and wire into WorkerManager
- **Effort**: 3 days (existing deployment shows this was implemented)
- **Testing**: Event flow integration tests
- **Status**: ✅ **ALREADY IMPLEMENTED** (deployment notes show completion)

#### ORD-P0-02: Order Status Semantics Conflict - fulfillment.completed → order.delivered [NOT FIXED]
- **File**: `order/internal/biz/status/status.go`
- **Issue**: `fulfillment.completed` is mapped to `order.delivered` which is semantically incorrect
- **Impact**: Customer sees "delivered" when package only left warehouse, not actually delivered
- **Root Cause**: Conflating warehouse completion with customer delivery
- **Fix**: Map `fulfillment.completed` to `order.shipped`, only `delivery.confirmed` from shipping should trigger `delivered`
- **Effort**: 1 day
- **Testing**: Status transition validation

#### ORD-P0-03: Transactional Outbox Race Condition in Order Creation
- **File**: `order/internal/biz/order/create.go:45`
- **Issue**: Event publishing not guaranteed to be atomic with order creation
- **Impact**: Lost events leading to fulfillment service not receiving order confirmation
- **Root Cause**: Event creation in separate transaction from order creation
- **Fix**: Ensure outbox event creation within same database transaction
- **Effort**: 2 days
- **Testing**: Chaos engineering with database failures

### Warehouse Service Critical Issues

#### WH-P0-01: Stock Reservation Confirmation Race Condition
- **File**: `warehouse/internal/biz/reservation/reservation.go`
- **Issue**: Stock reservation confirmation not atomic with payment confirmation
- **Impact**: Reserved stock may be released while payment is being processed
- **Root Cause**: Payment and reservation confirmation in separate transactions
- **Fix**: Implement two-phase confirmation with timeout
- **Effort**: 3 days
- **Testing**: Concurrent payment and timeout scenarios

#### WH-P0-02: FulfillReservation Missing Idempotency Protection
- **File**: `warehouse/internal/biz/inventory/inventory.go:295`
- **Issue**: Multiple fulfillment events can cause duplicate stock deduction
- **Impact**: Negative inventory levels from duplicate processing
- **Root Cause**: No idempotency key on FulfillReservation operations
- **Fix**: Add idempotency tracking with fulfillment_id + item_id composite key
- **Effort**: 2 days
- **Testing**: Duplicate event processing tests

#### WH-P0-03: Warehouse Selection Logic Missing Capacity Check
- **File**: `warehouse/internal/biz/inventory/inventory.go`
- **Issue**: Warehouse assignment doesn't verify actual capacity availability
- **Impact**: Over-allocation of orders to warehouses, fulfillment bottlenecks
- **Root Cause**: Simple distance-based selection without capacity validation
- **Fix**: Integrate CheckWarehouseCapacity into selection algorithm
- **Effort**: 2 days
- **Testing**: Capacity edge cases and overflow scenarios

### Payment Service Critical Issues

#### PAY-P0-01: Payment Authorization Timeout Handling
- **File**: `payment/internal/biz/gateway/stripe.go`
- **Issue**: Long-running payment authorizations not handled properly
- **Impact**: Order stuck in "payment pending" state when gateway times out
- **Root Cause**: No timeout handling or retry mechanism for slow gateways
- **Fix**: Implement circuit breaker with exponential backoff
- **Effort**: 2 days
- **Testing**: Gateway timeout simulation

#### PAY-P0-02: Webhook Idempotency Missing
- **File**: `payment/internal/biz/gateway/stripe.go:450`
- **Issue**: Payment webhook processing lacks idempotency protection
- **Impact**: Duplicate payment confirmations can trigger multiple order confirmations
- **Root Cause**: No webhook event ID tracking
- **Fix**: Store and check webhook event IDs before processing
- **Effort**: 1.5 days
- **Testing**: Duplicate webhook delivery tests

### Shipping Service Critical Issues

#### SHIP-P0-01: Carrier Integration Failure Handling
- **File**: `shipping/internal/biz/shipment/shipment.go`
- **Issue**: Failed carrier API calls block entire shipment creation
- **Impact**: Orders stuck in "fulfillment completed" when shipping fails
- **Root Cause**: Synchronous carrier integration without fallback
- **Fix**: Implement async carrier processing with fallback to manual processing
- **Effort**: 3 days
- **Testing**: Carrier API failure scenarios

#### SHIP-P0-02: Tracking Number Uniqueness Not Enforced
- **File**: `shipping/internal/model/shipment.go`
- **Issue**: Database allows duplicate tracking numbers across carriers
- **Impact**: Customer confusion and tracking conflicts
- **Root Cause**: Missing unique constraint on tracking_number
- **Fix**: Add database constraint and validation layer
- **Effort**: 1 day
- **Testing**: Duplicate tracking number scenarios

### Fulfillment Service Critical Issues

#### FUL-P0-01: Multi-Warehouse Fulfillment Consistency
- **File**: `fulfillment/internal/biz/fulfillment/fulfillment.go:471`
- **Issue**: Multi-warehouse orders may have partial fulfillments not properly tracked
- **Impact**: Inconsistent order completion status across warehouses
- **Root Cause**: Individual fulfillment status not aggregated correctly
- **Fix**: Implement fulfillment aggregation logic with completion threshold
- **Effort**: 3 days
- **Testing**: Multi-warehouse completion scenarios

#### FUL-P0-02: Fulfillment Status Transition Validation Gaps
- **File**: `fulfillment/internal/biz/fulfillment/fulfillment.go:1000`
- **Issue**: Status transitions allow invalid state changes (e.g., completed → picking)
- **Impact**: Data corruption and workflow confusion
- **Root Cause**: Incomplete transition validation matrix
- **Fix**: Implement comprehensive state machine with validation
- **Effort**: 2 days
- **Testing**: Invalid transition attempts

#### FUL-P0-03: Warehouse Capacity Integration Missing [NOT FIXED]
- **File**: `fulfillment/internal/biz/fulfillment/fulfillment.go` (selectWarehouse method)
- **Issue**: Fulfillment creation doesn't verify warehouse capacity before assignment
- **Impact**: Over-allocation leading to fulfillment delays
- **Root Cause**: Capacity check implementation incomplete
- **Fix**: Complete integration with warehouse capacity API
- **Effort**: 1 day
- **Testing**: Capacity overflow scenarios

#### FUL-P0-05: Batch Picklist Creation Lacks Transactional Boundaries
- **File**: `fulfillment/internal/biz/picklist/batch_picking.go`
- **Issue**: Batch picklist creation writes picklist + items + fulfillment updates without a transaction
- **Impact**: Partial data persisted if any step fails (orphaned picklists/items, inconsistent fulfillment states)
- **Root Cause**: No `InTx` wrapper around multi-write operations
- **Fix**: Wrap picklist + items + fulfillment updates in a single transaction; use outbox for events
- **Effort**: 1–2 days
- **Testing**: Failure injection mid-loop, verify rollback

---

# 🧭 Order Fulfillment & Tracking - Legacy Issues (Merged)

> **Note**: This section preserves unique items from the legacy `order_fulfillment_issues.md`.

## P1/P2 - Correctness / Semantics

- **Issue**: Semantic conflict between `fulfillment.completed` and `order.delivered`.
  - **Services**: `order`, `fulfillment`
  - **Location**: `order/internal/service/event_handler.go` (`mapFulfillmentStatusToOrderStatus` function)
  - **Impact**: `order` maps `fulfillment.completed` to `order.delivered`. This should be driven by shipping delivery confirmation.
  - **Recommendation**: Change mapping: `fulfillment.completed` → `order.shipped`, `delivered` only on shipping event.

## P1 - Resilience / Observability

- **Issue**: Event handler in `order` service silently ignores status update errors.
  - **Service**: `order`
  - **Location**: `order/internal/service/event_handler.go` (`HandleFulfillmentStatusChanged`)
  - **Impact**: Failures are hidden; without DLQ/alerting, data inconsistencies persist.
  - **Recommendation**: Push failing messages to DLQ and trigger high-priority alerts.

## P2 - Event Reliability

- **Issue**: `fulfillment` service does not use Transactional Outbox for publishing events.
  - **Service**: `fulfillment`
  - **Location**: `fulfillment/internal/biz/fulfillment/fulfillment.go`
  - **Impact**: Events can be lost between commit and publish.
  - **Recommendation**: Use the same outbox pattern as `order`.

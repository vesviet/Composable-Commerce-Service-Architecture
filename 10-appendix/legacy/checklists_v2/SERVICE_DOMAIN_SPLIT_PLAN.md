# Service Domain Split - Architecture Analysis & Implementation Plan

**Created**: 2026-01-22  
**Priority**: P0 - Architecture Foundation  
**Impact**: Major - Affects scalability, team independence, deployment

---

## 📊 Current Service Analysis

**Total Services**: 19 microservices  
**Domains needing split**: **3 CRITICAL + 2 RECOMMENDED**

---

## 🚨 CRITICAL - Services That MUST Be Split

### 1. **ORDER Service** → Split into 3 domains

**Current State**: Monolithic order service handling 9 different concerns
```
order/internal/biz/
├── cart/           # Shopping cart domain
├── checkout/       # Checkout orchestration
├── order/          # Order management
├── order_edit/     # Order editing
├── return/         # Return/refund workflows (1576 lines!)
├── cancellation/   # Order cancellation
├── status/         # Status tracking
├── validation/     # Cross-cutting validation
└── providers/      # External integrations
```

**Proposed Split**:

#### **1.1 Cart Service** (New)
- **Responsibility**: Shopping cart management
- **Bounded Context**: Pre-checkout customer intent
- **Domains**: 
  - Cart CRUD
  - Cart validation
  - Cart totals calculation
  - Promotion application
- **Database**: `cart_db` (separate from orders)
- **Events Published**: `cart.created`, `cart.updated`, `cart.abandoned`, `cart.converted`
- **Team**: Cart & Pricing team

#### **1.2 Order Service** (Refactored)
- **Responsibility**: Order lifecycle management
- **Domains**:
  - Order creation (from checkout)
  - Order tracking
  - Order editing
  - Status transitions
  - Cancellation
- **Database**: `order_db` (keep existing)
- **Events Published**: `order.created`, `order.updated`, `order.cancelled`, `order.shipped`
- **Team**: Order Management team

#### **1.3 Return Service** (New)
- **Responsibility**: Return & refund workflows
- **Domains**:
  - Return request management
  - Return approval workflow
  - Refund processing (integrates with Payment)
  - Restock coordination (integrates with Warehouse)
- **Database**: `return_db` (new)
- **Events Published**: `return.requested`, `return.approved`, `refund.completed`, `item.restocked`
- **Team**: Customer Service team

**Rationale**:
- ✅ Cart has different SLA (99.9% uptime) vs Order (99.5% acceptable)
- ✅ Return workflows are business-critical but infrequent (different scaling needs)
- ✅ Allows parallel team development
- ✅ Checkout orchestrates across Cart → Order (clear boundary)

---

### 2. **PAYMENT Service** → Split into 2 domains

**Current State**: 15 biz domains in single service
```
payment/internal/biz/
├── payment/        # Core payment processing
├── payment_method/ # Payment method management
├── gateway/        # Gateway integrations (Stripe, PayPal, MoMo)
├── transaction/    # Transaction ledger
├── webhook/        # Webhook handling
├── fraud/          # Fraud detection
├── dispute/        # Chargeback/dispute management
├── refund/         # Refund processing
├── reconciliation/ # Payment reconciliation
├── retry/          # Retry logic
├── sync/           # Payment sync
├── cleanup/        # Data cleanup
├── settings/       # Payment settings
├── events/         # Event publishing
└── common/         # Shared utilities
```

**Proposed Split**:

#### **2.1 Payment-Core Service** (Refactored)
- **Responsibility**: Payment processing & authorization
- **Domains**:
  - Payment authorization/capture
  - Payment method management
  - Gateway integrations
  - Transaction ledger
  - Fraud detection
- **Database**: `payment_db` (keep existing)
- **Events Published**: `payment.authorized`, `payment.captured`, `payment.failed`
- **Team**: Payment Processing team

#### **2.2 Payment-Operations Service** (New)
- **Responsibility**: Post-payment operations & compliance
- **Domains**:
  - Webhooks
  - Disputes/chargebacks
  - Refunds
  - Reconciliation
  - Retry/cleanup
- **Database**: `payment_ops_db` (new, or shared with read replica)
- **Events Published**: `dispute.created`, `refund.processed`, `reconciliation.completed`
- **Team**: Payment Operations team

**Rationale**:
- ✅ Core payment has strict latency SLA (<500ms)
- ✅ Operations (reconciliation, disputes) can be eventual consistency
- ✅ Different compliance requirements (PCI vs general audit)
- ✅ Operations team can work independently

---

### 3. **CUSTOMER Service** → Split into 2 domains

**Current State**: Mixed concerns
```
customer/internal/biz/
├── customer/       # Core customer profile (1069 lines!)
├── address/        # Address management (626 lines)
├── wishlist/       # Wishlist
├── customer_group/ # Customer groups
├── segment/        # Customer segmentation
├── preference/     # Customer preferences
├── analytics/      # Customer analytics
└── events/         # Event publishing
```

**Proposed Split**:

#### **3.1 Customer Service** (Refactored)
- **Responsibility**: Core customer identity & profile
- **Domains**:
  - Customer CRUD
  - Address management
  - Customer groups
  - Preferences
- **Database**: `customer_db` (keep existing)
- **Events Published**: `customer.created`, `customer.updated`, `address.added`
- **Team**: Customer Platform team

#### **3.2 Customer-Insights Service** (New)
- **Responsibility**: Customer intelligence & personalization
- **Domains**:
  - Customer segmentation
  - Behavioral analytics
  - Wishlist management
  - Recommendations
- **Database**: `customer_insights_db` (new, analytics-optimized)
- **Events Consumed**: All customer/order/cart events
- **Events Published**: `segment.updated`, `recommendation.generated`
- **Team**: Analytics & ML team

**Rationale**:
- ✅ Profile writes are low-frequency, reads are high-frequency
- ✅ Analytics can be eventual consistency
- ✅ Different storage needs (OLTP vs OLAP)

---

## 🟡 RECOMMENDED - Consider Splitting

### 4. **CATALOG Service** → Consider Domain Modules

**Current State**: 8 domains but cohesive
```
catalog/internal/biz/
├── product/                  # Product management
├── product_attribute/        # Attributes (1031 lines - needs refactor)
├── product_visibility_rule/  # Visibility rules
├── category/                 # Category tree
├── brand/                    # Brand management
├── manufacturer/             # Manufacturer
├── cms/                      # CMS content
└── events/                   # Event publishing
```

**Analysis**: 
- ⚠️ Large but cohesive domain (no clear split point)
- ✅ Better approach: **Refactor large files** (product_attribute.go)
- ✅ Consider **read replicas** for product search instead of service split

**Recommendation**: **NO SPLIT** - Refactor large files only

---

### 5. **WAREHOUSE Service** → Consider Future Split

**Current State**: Multiple concerns
```
warehouse/internal/biz/
├── inventory/    # Stock management (1302 lines)
├── reservation/  # Stock reservation
├── warehouse/    # Warehouse management
└── alert/        # Alert management
```

**Analysis**:
- ⚠️ Could split into Inventory Service + Warehouse Management
- ✅ But tightly coupled (inventory lives in warehouse)
- ✅ Better: **Multi-warehouse routing** as future enhancement

**Recommendation**: **NO SPLIT NOW** - Monitor as business scales

---

## 🛠️ Implementation Roadmap

> [!IMPORTANT]
> **Prerequisites**: Phase 1 file refactoring MUST be completed first:
> - ✅ `return.go` refactored (1577 → 602 lines) - DONE
> - [ ] `promotion.go` refactored (1179 lines → split needed)
> - [ ] `pricing.go` refactored (if needed)

---

### Phase 2.1: Cart Service Extraction (Weeks 5-7)

**Goal**: Extract shopping cart from Order service

**Week 5: Setup & Database**
- [ ] Create `cart` service (Kratos template + Wire + Dapr)
- [ ] Create `cart_db` database in PostgreSQL
- [ ] Migrate tables: `carts`, `cart_items` from `order_db`
- [ ] Add indexes: `customer_id`, `status`, `created_at`
- [ ] Set up 30-day TTL cleanup job (cron)
- **Deliverable**: Cart service skeleton + migrated database

**Week 6: Business Logic**
- [ ] Copy `order/internal/biz/cart/` → `cart/internal/biz/`
- [ ] Implement `CartUsecase` with 8 methods (CreateCart, AddItem, UpdateItem, etc.)
- [ ] Integrate with Pricing Service (gRPC + circuit breaker)
- [ ] Integrate with Promotion Service (gRPC + circuit breaker)
- [ ] Integrate with Catalog Service for stock validation
- [ ] Add retry logic (3 attempts, exponential backoff)
- **Deliverable**: Cart business logic migrated + tested

**Week 7: Integration & Deployment**
- [ ] Implement event publishers: `cart.created`, `cart.item.added`, `cart.converted`
- [ ] Update `checkout` to call Cart Service gRPC (replace direct repo calls)
- [ ] Deploy to dev → Run parallel mode (old cart vs new Cart Service)
- [ ] Load test: 1000 concurrent cart operations (target: p95 <50ms)
- [ ] Deploy to staging → Feature flag rollout: 10% → 50% → 100%
- [ ] Decommission cart code from Order Service
- **Deliverable**: ✅ Cart Service live in production

**Effort**: 80 hours (2 engineers x 3 weeks)

---

### Phase 2.2: Return Service Extraction (Weeks 8-10)

> [!NOTE]
> **Advantage**: Return code is already refactored in Phase 1!
> - Clean `return.go` (602 lines)
> - Modular files: `events.go`, `validation.go`, `refund.go`, `restock.go`, `shipping.go`, `exchange.go`

**Goal**: Extract return/refund workflows from Order service

**Week 8: Setup & Database**
- [ ] Create `return` service (Kratos + Wire + Dapr)
- [ ] Create `return_db` database
- [ ] Migrate tables: `return_requests`, `return_items`, `return_status_history`
- [ ] Add foreign keys and indexes
- [ ] Set up audit logging table
- [ ] Create proto definitions (`api/return/v1/return.proto`)
- **Deliverable**: Return service skeleton + database

**Week 9: Business Logic**
- [ ] Copy entire `order/internal/biz/return/` → `return/internal/biz/`
  - **Already clean!** No refactoring needed (Phase 1 done)
- [ ] Update imports and dependencies
- [ ] Implement gRPC service layer (map proto to biz)
- [ ] Integrate with Payment Service (refunds + idempotency)
- [ ] Integrate with Warehouse Service (async restock via events)
- [ ] Integrate with Shipping Service (return labels + fallback)
- [ ] Subscribe to events: `order.shipped`, `order.delivered`
- **Deliverable**: Return business logic migrated + external integrations

**Week 10: Event Workflows & Deployment**
- [ ] Implement event choreography:
  - Subscribe: `order.shipped` → Enable return creation
  - Publish: `return.requested`, `return.approved`, `return.completed`
- [ ] Implement saga compensation (retry refund, alert on restock failure)
- [ ] Add dead-letter queue for failed events
- [ ] Implement return status state machine (6 states + transitions)
- [ ] Deploy to dev → Migrate active return requests
- [ ] Deploy to staging → Feature flag rollout
- [ ] Decommission return code from Order Service
- **Deliverable**: ✅ Return Service live in production

**Effort**: 70 hours (2 engineers x 3 weeks)

---



## 📅 Phase 2 Timeline Summary

**Total Duration**: 6 weeks (Weeks 5-10)  
**Total Effort**: ~150 hours  
**Team Size**: 2 engineers per phase

| Phase | Weeks | Service | Effort | Status |
|-------|-------|---------|--------|--------|
| 2.1 | 5-7 | Cart Service | 80h | Not Started |
| 2.2 | 8-10 | Return Service | 70h | Not Started |

**Key Milestones**:
- ✅ Week 7 (Feb 21, 2026): Cart Service live
- ✅ Week 10 (Mar 14, 2026): Return Service live  

> [!NOTE]
> **Simplified Approach**: Extracting only Cart and Return services from Order.
> - **Payment**: Keep as single service, refactor files if needed
> - **Customer**: Keep as single service, use read replicas for analytics
> - **Benefits**: Fewer services = simpler ops, easier monitoring, faster deployment  

---

## 📐 Service Communication Patterns

### After Split - Service Dependencies

```
┌─────────────┐
│   Gateway   │
└──────┬──────┘
       │
   ┌───┼────────────────────────────┐
   │   │                            │
┌──▼───▼──┐  ┌───────────┐   ┌─────▼─────┐
│  Cart   ├─►│ Checkout  ├──►│   Order   │
│ Service │  │Orchestrator│   │  Service  │
└──┬──────┘  └─────┬─────┘   └─────┬─────┘
   │                │                │
   │          ┌─────▼─────┐    ┌────▼────┐
   │          │  Payment  │    │ Return  │
   │          │   Core    │    │ Service │
   │          └─────┬─────┘    └────┬────┘
   │                │                │
   │          ┌─────▼──────┐    ┌───▼────┐
   └─────────►│ Promotion  │    │Payment │
              │  Service   │    │  Ops   │
              └────────────┘    └────────┘
```

### Communication Protocols
- **Synchronous**: gRPC for cart → checkout, checkout → order
- **Asynchronous**: Dapr Pub/Sub for events (order → fulfillment, return → warehouse)
- **Saga Pattern**: Checkout orchestrates distributed transaction

---

## ✅ Success Criteria

**Technical Metrics**:
- [ ] Each service <5000 LOC in `/internal/biz`
- [ ] Independent deployment (no cascading releases)
- [ ] Service-to-service latency <100ms (p95)
- [ ] No circular dependencies

**Business Metrics**:
- [ ] Cart service 99.9% uptime (critical for revenue)
- [ ] Return processing time reduced by 30% (dedicated team)
- [ ] Payment operations team can deploy without payment-core team approval

---

## 🎯 Decision Matrix: Should We Split?

| Service | Split? | Reason |
|---------|--------|--------|
| **Order** | ✅ YES | Extract Cart + Return (different scaling needs) |
| **Payment** | ❌ NO | Keep as single service, refactor files if needed |
| **Customer** | ❌ NO | Keep as single service, use read replicas for analytics |
| **Catalog** | ❌ NO | Cohesive domain, refactor files instead |
| **Warehouse** | ❌ NO | Too tightly coupled, wait for scale |

**Rationale for Payment/Customer**:
- ✅ Fewer services = easier operations, monitoring, deployment
- ✅ Reduced network latency (no cross-service calls)
- ✅ Simpler distributed tracing
- ✅ File refactoring (Phase 1) already improves maintainability

---

## 📖 References

- **DDD**: [Domain-Driven Design - Eric Evans](https://www.domainlanguage.com/ddd/)
- **Microservices Patterns**: [Chris Richardson](https://microservices.io/)
- **Team Topologies**: [Skelton & Pais](https://teamtopologies.com/)

---

**Created**: 2026-01-22  
**Updated**: 2026-01-22 (Simplified to Cart + Return only)  
**Architect**: AI Senior Team Lead  
**Status**: Phase 1 (Return refactoring) ✅ DONE | Phase 2 Ready to Start  
**Focus**: Cart Service + Return Service only  
**Estimated Total Effort**: ~150 hours Phase 2 (6 weeks with 2 engineers)


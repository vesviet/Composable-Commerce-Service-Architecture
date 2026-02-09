# Event Architecture Implementation Checklist

**Project**: E-Commerce Microservices Platform  
**Created**: 2026-02-09  
**Purpose**: Checklist for implementing event architecture fixes and improvements

---

## Table of Contents
1. [Phase 1: Critical Fixes](#phase-1-critical-fixes)
2. [Phase 2: Standardization](#phase-2-standardization)
3. [Phase 3: Enhancement](#phase-3-enhancement)
4. [Phase 4: Documentation](#phase-4-documentation)
5. [Progress Tracking](#progress-tracking)

---

## Phase 1: Critical Fixes

### 1.1 Create Subscription Files

**Priority**: 🔴 CRITICAL  
**Timeline**: Week 1

#### catalog-worker
- [ ] Create [`catalog/dapr/subscription.yaml`](../../catalog/dapr/subscription.yaml)
- [ ] Subscribe to `warehouse.inventory.stock_changed` → `/events/warehouse-stock-changed`
- [ ] Subscribe to `pricing.price.updated` → `/events/price-updated`
- [ ] Configure DLQ: `dlq.warehouse-stock-changed`
- [ ] Configure DLQ: `dlq.price-updated`
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### search-worker
- [ ] Create [`search/dapr/subscription.yaml`](../../search/dapr/subscription.yaml)
- [ ] Subscribe to `product.created` → `/events/product-created`
- [ ] Subscribe to `product.updated` → `/events/product-updated`
- [ ] Subscribe to `product.deleted` → `/events/product-deleted`
- [ ] Configure DLQ: `dlq.product-created`
- [ ] Configure DLQ: `dlq.product-updated`
- [ ] Configure DLQ: `dlq.product-deleted`
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### payment-worker
- [ ] Create [`payment/dapr/subscription.yaml`](../../payment/dapr/subscription.yaml)
- [ ] Subscribe to `orders.payment.capture_requested` → `/events/payment-capture-requested`
- [ ] Configure DLQ: `dlq.payment-capture-requested`
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### pricing-worker
- [ ] Create [`pricing/dapr/subscription.yaml`](../../pricing/dapr/subscription.yaml)
- [ ] Subscribe to price calculation requests (if any)
- [ ] Configure DLQ
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### common-operations-worker
- [ ] Create [`common-operations/dapr/subscription.yaml`](../../common-operations/dapr/subscription.yaml)
- [ ] Subscribe to operational events
- [ ] Subscribe to task completion events
- [ ] Configure DLQ for each topic
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### shipping-worker
- [ ] Create [`shipping/dapr/subscription.yaml`](../../shipping/dapr/subscription.yaml)
- [ ] Subscribe to `fulfillments.fulfillment.status_changed` → `/events/fulfillment-status-changed`
- [ ] Configure DLQ: `dlq.fulfillment-status-changed`
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### notification-worker
- [ ] Create [`notification/dapr/subscription.yaml`](../../notification/dapr/subscription.yaml)
- [ ] Subscribe to `order.created` → `/events/order-created`
- [ ] Subscribe to `order.status_changed` → `/events/order-status-changed`
- [ ] Subscribe to `payment.processed` → `/events/payment-processed`
- [ ] Subscribe to `shipment.created` → `/events/shipment-created`
- [ ] Subscribe to `return.requested` → `/events/return-requested`
- [ ] Subscribe to `review.created` → `/events/review-created`
- [ ] Configure DLQ for each topic
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### order-worker
- [ ] Create [`order/dapr/subscription.yaml`](../../order/dapr/subscription.yaml)
- [ ] Subscribe to `cart.checked_out` → `/events/cart-checked-out`
- [ ] Subscribe to `checkout.started` → `/events/checkout-started`
- [ ] Configure DLQ: `dlq.cart-checked-out`
- [ ] Configure DLQ: `dlq.checkout-started`
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### fulfillment-worker
- [ ] Create [`fulfillment/dapr/subscription.yaml`](../../fulfillment/dapr/subscription.yaml)
- [ ] Subscribe to `order.created` → `/events/order-created`
- [ ] Subscribe to `order.status_changed` → `/events/order-status-changed`
- [ ] Subscribe to `inventory.reserved` → `/events/inventory-reserved`
- [ ] Configure DLQ for each topic
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### warehouse-worker
- [ ] Create [`warehouse/dapr/subscription.yaml`](../../warehouse/dapr/subscription.yaml)
- [ ] Subscribe to `order.created` → `/events/order-created`
- [ ] Subscribe to `return.requested` → `/events/return-requested`
- [ ] Configure DLQ: `dlq.order-created`
- [ ] Configure DLQ: `dlq.return-requested`
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

#### customer-worker
- [ ] Create [`customer/dapr/subscription.yaml`](../../customer/dapr/subscription.yaml)
- [ ] Subscribe to `user.registered` → `/events/user-registered`
- [ ] Subscribe to `customer.created` → `/events/customer-created`
- [ ] Configure DLQ: `dlq.user-registered`
- [ ] Configure DLQ: `dlq.customer-created`
- [ ] Set maxRetryCount: "3"
- [ ] Test subscription with Dapr

### 1.2 Implement Event Handlers

**Priority**: 🔴 CRITICAL  
**Timeline**: Week 1

#### catalog-worker
- [ ] Create HTTP handler for `/events/warehouse-stock-changed`
- [ ] Create HTTP handler for `/events/price-updated`
- [ ] Implement stock update processing logic
- [ ] Implement price update processing logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### search-worker
- [ ] Create HTTP handler for `/events/product-created`
- [ ] Create HTTP handler for `/events/product-updated`
- [ ] Create HTTP handler for `/events/product-deleted`
- [ ] Implement product indexing logic
- [ ] Implement product update logic
- [ ] Implement product deletion logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### payment-worker
- [ ] Create HTTP handler for `/events/payment-capture-requested`
- [ ] Implement payment capture logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### pricing-worker
- [ ] Create HTTP handler for price calculation requests
- [ ] Implement pricing logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### common-operations-worker
- [ ] Create HTTP handlers for operational events
- [ ] Implement task processing logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### shipping-worker
- [ ] Create HTTP handler for `/events/fulfillment-status-changed`
- [ ] Implement shipment creation logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### notification-worker
- [ ] Create HTTP handler for `/events/order-created`
- [ ] Create HTTP handler for `/events/order-status-changed`
- [ ] Create HTTP handler for `/events/payment-processed`
- [ ] Create HTTP handler for `/events/shipment-created`
- [ ] Create HTTP handler for `/events/return-requested`
- [ ] Create HTTP handler for `/events/review-created`
- [ ] Implement notification sending logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### order-worker
- [ ] Create HTTP handler for `/events/cart-checked-out`
- [ ] Create HTTP handler for `/events/checkout-started`
- [ ] Implement order creation logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### fulfillment-worker
- [ ] Create HTTP handler for `/events/order-created`
- [ ] Create HTTP handler for `/events/order-status-changed`
- [ ] Create HTTP handler for `/events/inventory-reserved`
- [ ] Implement fulfillment logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### warehouse-worker
- [ ] Create HTTP handler for `/events/order-created`
- [ ] Create HTTP handler for `/events/return-requested`
- [ ] Implement inventory reservation logic
- [ ] Implement return processing logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

#### customer-worker
- [ ] Create HTTP handler for `/events/user-registered`
- [ ] Create HTTP handler for `/events/customer-created`
- [ ] Implement customer sync logic
- [ ] Add error handling
- [ ] Add logging
- [ ] Test handlers locally

### 1.3 Test Event Flows

**Priority**: 🔴 CRITICAL  
**Timeline**: Week 1

#### End-to-End Testing
- [ ] Test order placement flow (cart → order → payment → fulfillment → shipping)
- [ ] Test product update flow (catalog → search)
- [ ] Test price update flow (pricing → catalog)
- [ ] Test return flow (return → warehouse → payment)
- [ ] Test notification flow (all events → notification)
- [ ] Verify DLQ routing
- [ ] Verify retry logic
- [ ] Document test results

### 1.4 Deploy and Verify

**Priority**: 🔴 CRITICAL  
**Timeline**: Week 1

#### Deployment
- [ ] Deploy subscription files to GitOps
- [ ] Deploy event handlers to GitOps
- [ ] Verify ArgoCD sync
- [ ] Verify all workers are consuming events
- [ ] Check Dapr sidecar logs
- [ ] Verify no errors in subscriptions

#### Verification
- [ ] Verify workers are processing events
- [ ] Check DLQ topics are empty
- [ ] Verify event metrics are collected
- [ ] Test event publishing and consumption
- [ ] Verify idempotency is working

### 1.5 DLQ Monitoring

**Priority**: 🔴 CRITICAL  
**Timeline**: Week 1

#### Monitoring Setup
- [ ] Create Prometheus metrics for DLQ size
- [ ] Create Grafana dashboard for DLQ monitoring
- [ ] Configure alert rules for DLQ threshold breaches
- [ ] Test alerting
- [ ] Document DLQ replay procedure

#### Metrics to Track
- [ ] `dlq_events_total{topic="..."}`
- [ ] `dlq_size_bytes{topic="..."}`
- [ ] `dlq_age_seconds{topic="..."}`
- [ ] `dlq_processing_failed_total{topic="..."}`

---

## Phase 2: Standardization

### 2.1 Standardize Event Topic Naming

**Priority**: 🟠 HIGH  
**Timeline**: Week 2

#### Update Topic Names
- [ ] Update `order-events` → `orders.order.status_changed`
- [ ] Update `product-events` → `catalog.product.created`
- [ ] Update `customer-events` → `customer.created`
- [ ] Update `page-view-events` → `analytics.page_view`
- [ ] Update all analytics subscriptions
- [ ] Update all analytics event handlers
- [ ] Update all analytics publishers
- [ ] Test topic name changes
- [ ] Update documentation

### 2.2 Implement Idempotency

**Priority**: 🟠 HIGH  
**Timeline**: Week 2

#### Add Idempotency to All Consumers
- [ ] Add idempotency to catalog-worker
- [ ] Add idempotency to search-worker
- [ ] Add idempotency to payment-worker
- [ ] Add idempotency to pricing-worker
- [ ] Add idempotency to common-operations-worker
- [ ] Add idempotency to shipping-worker
- [ ] Add idempotency to notification-worker
- [ ] Add idempotency to order-worker
- [ ] Add idempotency to fulfillment-worker
- [ ] Add idempotency to warehouse-worker
- [ ] Add idempotency to customer-worker
- [ ] Add idempotency to review-worker
- [ ] Add idempotency to loyalty-rewards-worker

#### Idempotency Pattern
```go
// Generate unique event ID
eventID := fmt.Sprintf("%s-%s-%d", entityID, eventType, timestamp.Unix())

// Check if already processed
idempotencyKey := fmt.Sprintf("event:processed:%s", eventID)
processed, err := redis.Get(ctx, idempotencyKey).Bool()

if processed {
    return nil // Skip processing
}

// Process event
// ...

// Mark as processed
redis.Set(ctx, idempotencyKey, true, 24*time.Hour)
```

### 2.3 Fix Worker Protocol Inconsistency

**Priority**: 🟠 HIGH  
**Timeline**: Week 2

#### Update common-operations-worker
- [ ] Change protocol from HTTP (8019) to gRPC (5005)
- [ ] Update deployment configuration
- [ ] Update Dapr annotations
- [ ] Test worker with gRPC
- [ ] Update documentation

---

## Phase 3: Enhancement

### 3.1 Create Missing Worker Deployments

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 3

#### auth-worker
- [ ] Create [`auth/base/worker-deployment.yaml`](../../gitops/apps/auth/base/worker-deployment.yaml)
- [ ] Configure Dapr sidecar
- [ ] Implement token cleanup logic
- [ ] Implement session management logic
- [ ] Add event handlers
- [ ] Test worker deployment

#### checkout-worker
- [ ] Create [`checkout/base/worker-deployment.yaml`](../../gitops/apps/checkout/base/worker-deployment.yaml)
- [ ] Configure Dapr sidecar
- [ ] Implement cart expiration logic
- [ ] Implement abandoned checkout cleanup
- [ ] Add event handlers
- [ ] Test worker deployment

#### location-worker
- [ ] Create [`location/base/worker-deployment.yaml`](../../gitops/apps/location/base/worker-deployment.yaml)
- [ ] Configure Dapr sidecar
- [ ] Implement address validation logic
- [ ] Implement geocoding logic
- [ ] Add event handlers
- [ ] Test worker deployment

#### promotion-worker
- [ ] Create [`promotion/base/worker-deployment.yaml`](../../gitops/apps/promotion/base/worker-deployment.yaml)
- [ ] Configure Dapr sidecar
- [ ] Implement promotion expiration logic
- [ ] Implement coupon validation logic
- [ ] Add event handlers
- [ ] Test worker deployment

#### return-worker
- [ ] Create [`return/base/worker-deployment.yaml`](../../gitops/apps/return/base/worker-deployment.yaml)
- [ ] Configure Dapr sidecar
- [ ] Implement return processing logic
- [ ] Implement refund coordination logic
- [ ] Add event handlers
- [ ] Test worker deployment

#### review-worker
- [ ] Create [`review/base/worker-deployment.yaml`](../../gitops/apps/review/base/worker-deployment.yaml)
- [ ] Configure Dapr sidecar
- [ ] Implement review moderation logic
- [ ] Implement rating aggregation logic
- [ ] Add event handlers
- [ ] Test worker deployment

#### user-worker
- [ ] Create [`user/base/worker-deployment.yaml`](../../gitops/apps/user/base/worker-deployment.yaml)
- [ ] Configure Dapr sidecar
- [ ] Implement user cleanup logic
- [ ] Implement account maintenance logic
- [ ] Add event handlers
- [ ] Test worker deployment

### 3.2 Add DLQ Replay Mechanism

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 3

#### Replay Implementation
- [ ] Create DLQ replay service
- [ ] Implement replay logic for each DLQ topic
- [ ] Add replay controls (pause, resume, reset)
- [ ] Add replay monitoring
- [ ] Test replay mechanism
- [ ] Document replay procedure

### 3.3 Implement Event Tracing

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 3

#### Tracing Setup
- [ ] Add trace context to all published events
- [ ] Add trace context to all event handlers
- [ ] Configure Jaeger integration
- [ ] Verify trace propagation
- [ ] Test distributed tracing
- [ ] Create tracing dashboards

### 3.4 Add Event Metrics

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 3

#### Metrics Implementation
- [ ] Add `events_published_total` metric to all publishers
- [ ] Add `events_published_failed_total` metric to all publishers
- [ ] Add `events_consumed_total` metric to all consumers
- [ ] Add `events_processed_total` metric to all consumers
- [ ] Add `events_failed_total` metric to all consumers
- [ ] Add `events_dlq_total` metric to all consumers
- [ ] Add `event_processing_duration_seconds` metric to all consumers
- [ ] Add `event_batch_size` metric to batch processors
- [ ] Create Grafana dashboards for event metrics
- [ ] Test metrics collection

---

## Phase 4: Documentation

### 4.1 Update Event Architecture Documentation

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 4

#### Documentation Updates
- [ ] Update [`../../plans/EVENT_ARCHITECTURE.md`](../../plans/EVENT_ARCHITECTURE.md) with fixes
- [ ] Update [`../../plans/EVENT_ARCHITECTURE_ISSUES.md`](../../plans/EVENT_ARCHITECTURE_ISSUES.md) with status
- [ ] Update [`../../plans/SERVICE_CATALOG.md`](../../plans/SERVICE_CATALOG.md) with event details
- [ ] Update [`../../plans/GITOPS_INDEX.md`](../../plans/GITOPS_INDEX.md) with event configuration
- [ ] Update [`../../plans/README.md`](../../plans/README.md) with links to event docs
- [ ] Verify all cross-references are correct

### 4.2 Create Troubleshooting Guide

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 4

#### Troubleshooting Documentation
- [ ] Create event troubleshooting guide
- [ ] Document common event issues
- [ ] Document DLQ troubleshooting
- [ ] Document subscription troubleshooting
- [ ] Document event handler debugging
- [ ] Add troubleshooting examples
- [ ] Create troubleshooting runbooks

### 4.3 Document Event Flows

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 4

#### Flow Documentation
- [ ] Document order placement flow
- [ ] Document product update flow
- [ ] Document price update flow
- [ ] Document return flow
- [ ] Document notification flow
- [ ] Create sequence diagrams for all flows
- [ ] Add flow documentation to [`../../docs/05-workflows/`](../../docs/05-workflows/)

### 4.4 Create Testing Guide

**Priority**: 🟡 MEDIUM  
**Timeline**: Week 4

#### Testing Documentation
- [ ] Create event testing guide
- [ ] Document unit testing for events
- [ ] Document integration testing for events
- [ ] Document load testing for events
- [ ] Document event schema validation
- [ ] Add testing examples
- [ ] Create testing templates

---

## Progress Tracking

### Overall Progress

| Phase | Status | Completion | Target Date |
|-------|--------|------------|-------------|
| **Phase 1: Critical Fixes** | 🟡 Not Started | 0% | Week 1 |
| **Phase 2: Standardization** | 🟡 Not Started | 0% | Week 2 |
| **Phase 3: Enhancement** | 🟡 Not Started | 0% | Week 3 |
| **Phase 4: Documentation** | 🟡 Not Started | 0% | Week 4 |

### Phase 1 Progress

| Task | Status | Notes |
|------|--------|-------|
| Create subscription files | 🟡 Not Started | 0/11 workers |
| Implement event handlers | 🟡 Not Started | 0/11 workers |
| Test event flows | 🟡 Not Started | 0/5 flows |
| Deploy and verify | 🟡 Not Started | 0/4 steps |
| DLQ monitoring | 🟡 Not Started | 0/4 steps |

### Phase 2 Progress

| Task | Status | Notes |
|------|--------|-------|
| Standardize topic naming | 🟡 Not Started | 0/5 topics |
| Implement idempotency | 🟡 Not Started | 0/23 services |
| Fix worker protocol | 🟡 Not Started | 0/1 service |
| Create event schemas | 🟡 Not Started | 0/18 schemas |

### Phase 3 Progress

| Task | Status | Notes |
|------|--------|-------|
| Create worker deployments | 🟡 Not Started | 0/7 workers |
| DLQ replay mechanism | 🟡 Not Started | 0/1 feature |
| Event tracing | 🟡 Not Started | 0/1 feature |
| Event metrics | 🟡 Not Started | 0/8 metrics |

### Phase 4 Progress

| Task | Status | Notes |
|------|--------|-------|
| Update architecture docs | 🟡 Not Started | 0/5 docs |
| Troubleshooting guide | 🟡 Not Started | 0/1 guide |
| Document event flows | 🟡 Not Started | 0/5 flows |
| Testing guide | 🟡 Not Started | 0/1 guide |

---

## Success Criteria

### Phase 1 Success
- [ ] All 11 workers have subscription files
- [ ] All 11 workers have event handlers
- [ ] All event flows tested end-to-end
- [ ] All workers deployed and verified
- [ ] DLQ monitoring dashboard created
- [ ] DLQ alerting configured

### Phase 2 Success
- [ ] All event topics follow naming convention
- [ ] All 23 consumers implement idempotency
- [ ] All workers use gRPC protocol
- [ ] All 18 missing event schemas created

### Phase 3 Success
- [ ] All 7 required workers deployed
- [ ] DLQ replay mechanism working
- [ ] Event tracing implemented
- [ ] All 8 event metrics collected

### Phase 4 Success
- [ ] All architecture documentation updated
- [ ] Troubleshooting guide created
- [ ] All 5 event flows documented
- [ ] Testing guide created

---

## Notes

### Implementation Notes
- Each phase should be completed before starting next
- Test thoroughly in dev environment before production
- Document all changes and decisions
- Communicate progress regularly
- Rollback plan should be ready for each phase

### Risk Mitigation
- Test all changes in dev environment first
- Have rollback plan for each change
- Monitor system closely after deployments
- Have on-call support during deployments
- Document all issues and resolutions

---

## Related Documents

- [`../../plans/EVENT_ARCHITECTURE.md`](../../plans/EVENT_ARCHITECTURE.md) - Event architecture overview
- [`../../plans/EVENT_ARCHITECTURE_ISSUES.md`](../../plans/EVENT_ARCHITECTURE_ISSUES.md) - Issues analysis
- [`../../plans/SERVICE_CATALOG.md`](../../plans/SERVICE_CATALOG.md) - Service catalog
- [`../../plans/GITOPS_INDEX.md`](../../plans/GITOPS_INDEX.md) - GitOps configuration
- [`../../plans/README.md`](../../plans/README.md) - Master index

---

**Checklist Version**: 1.0  
**Maintained By**: Architecture Team  
**Last Updated**: 2026-02-09  
**Status**: Ready for Implementation
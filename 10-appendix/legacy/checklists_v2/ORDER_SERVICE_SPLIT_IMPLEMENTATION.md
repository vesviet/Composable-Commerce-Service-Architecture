# Order Service Split - Implementation Plan

**Goal**: Extract Checkout Service and Return Service from Order service to improve scalability, team independence, and maintainability.

**Services to Create**:
1. **Checkout Service** - Cart + Checkout orchestration (54 files, ~5K LOC)
2. **Return Service** - Return/refund workflows (8 files, ~1.7K LOC)

---

## User Review Required

> [!IMPORTANT]
> **Breaking Changes**: This is a major architectural change that affects multiple services and requires careful coordination.

> [!WARNING]
> **Database Migration**: Requires creating new databases (`checkout_db`, `return_db`) and migrating data from `order_db`.

> [!CAUTION]
> **Deployment Strategy**: Must use parallel deployment with feature flags to avoid downtime. Rollback plan required.

**Key Decisions Needed**:
1. **Database Migration Timing**: Should we migrate data during deployment or run dual-write mode first?
2. **Checkout Session TTL**: Current cart TTL is unclear, need to confirm cleanup strategy
3. **Feature Flag Strategy**: Use Dapr configuration or environment variables?
4. **Rollback Plan**: If extraction fails, how quickly can we rollback?

---

## Proposed Changes

### Checkout Service

#### Service Structure
Create new Checkout service with clean architecture:

```
checkout/
├── cmd/server/main.go                  # Entry point
├── internal/
│   ├── biz/                            # Business logic
│   │   ├── cart/                       # Cart management (from order/biz/cart/)
│   │   │   ├── usecase.go              # Main cart usecase
│   │   │   ├── add.go                  # Add item to cart
│   │   │   ├── update.go               # Update cart item
│   │   │   ├── remove.go               # Remove item
│   │   │   ├── get.go                  # Get cart
│   │   │   ├── clear.go                # Clear cart
│   │   │   ├── merge.go                # Merge carts (guest → customer)
│   │   │   ├── totals.go               # Calculate cart totals
│   │   │   ├── validate.go             # Cart validation
│   │   │   ├── stock.go                # Stock validation
│   │   │   ├── promotion.go            # Apply promotions
│   │   │   ├── sync.go                 # Sync with catalog
│   │   │   └── types.go                # Cart types
│   │   ├── checkout/                   # Checkout orchestration (from order/biz/checkout/)
│   │   │   ├── usecase.go              # Checkout usecase
│   │   │   ├── start.go                # Start checkout
│   │   │   ├── preview.go              # Preview order
│   │   │   ├── update.go               # Update checkout
│   │   │   ├── confirm.go              # Confirm & create order
│   │   │   ├── payment.go              # Payment orchestration
│   │   │   ├── shipping.go             # Shipping methods
│   │   │   ├── validation.go           # Checkout validation
│   │   │   └── types.go                # Checkout types
│   │   └── events/                     # Event publishing
│   ├── data/                           # Data layer
│   │   ├── cart_repo.go                # Cart repository
│   │   └── checkout_repo.go            # Checkout repository
│   ├── service/                        # gRPC service implementation
│   │   ├── cart.go                     # Cart service
│   │   └── checkout.go                 # Checkout service
│   └── server/                         # Server setup
│       ├── grpc.go
│       └── http.go
├── api/checkout/v1/                    # Proto definitions
│   ├── cart.proto
│   └── checkout.proto
├── migrations/                         # Database migrations
└── config/                            # Configuration
```

#### [NEW] Database: `checkout_db`

**Tables to migrate from `order_db`**:
- `carts` - Shopping cart data
- `cart_items` - Cart line items
- `cart_promotions` - Applied promotions
- `checkouts` - Checkout sessions
- `checkout_addresses` - Shipping/billing addresses

**Migration Strategy**:
1. Create new `checkout_db` database
2. Run schema migrations (from order migrations)
3. Copy data from `order_db` to `checkout_db` (historical data)
4. Enable dual-write mode (write to both DBs during transition)
5. Switch reads to `checkout_db`
6. Disable dual-write, remove old tables from `order_db`

#### Business Logic Migration

**From `order/internal/biz/cart/` (28 files)**:
- [x] `add.go` (266 LOC) - Add item logic with stock validation
- [x] `update.go` (127 LOC) - Update quantity logic
- [x] `remove.go` (34 LOC) - Remove item
- [x] `get.go` (158 LOC) - Get cart with eager loading
- [x] `clear.go` (21 LOC) - Clear cart
- [x] `merge.go` (64 LOC) - Merge guest and customer carts
- [x] `totals.go` (345 LOC) - Complex calculation engine
- [x] `validate.go` (120 LOC) - Cart validation rules
- [x] `stock.go` (107 LOC) - Stock check integration
- [x] `promotion.go` (86 LOC) - Promotion application
- [x] `sync.go` (79 LOC) - Sync prices from Catalog
- [x] `types.go` (217 LOC) - Cart domain models
- [x] `helpers.go` (180 LOC) - Helper functions
- [x] `interfaces.go` (46 LOC) - External service interfaces

**From `order/internal/biz/checkout/` (26 files)**:
- [x] `start.go` (92 LOC) - Initialize checkout session
- [x] `preview.go` (378 LOC) - Order preview with pricing
- [x] `update.go` (158 LOC) - Update checkout (address, shipping)
- [x] `confirm.go` (441 LOC) - Final confirmation & order creation
- [x] `payment.go` (261 LOC) - Payment service integration
- [x] `shipping.go` (54 LOC) - Shipping methods integration
- [x] `validation.go` (135 LOC) - Checkout validation
- [x] `order_creation.go` (280 LOC) - Create order in Order service
- [x] `types.go` (149 LOC) - Checkout domain models

**External Service Integrations**:
- **Catalog Service**: Product info, pricing, stock validation
- **Pricing Service**: Dynamic pricing rules
- **Promotion Service**: Discount calculations
- **Warehouse Service**: Stock reservation
- **Payment Service**: Payment processing
- **Shipping Service**: Shipping rate calculation
- **Order Service**: Create order on checkout confirmation

#### gRPC API Design

**`api/checkout/v1/cart.proto`**:
```protobuf
service CartService {
  rpc CreateCart(CreateCartRequest) returns (Cart);
  rpc GetCart(GetCartRequest) returns (Cart);
  rpc AddItem(AddItemRequest) returns (Cart);
  rpc UpdateItem(UpdateItemRequest) returns (Cart);
  rpc RemoveItem(RemoveItemRequest) returns (Cart);
  rpc ClearCart(ClearCartRequest) returns (Empty);
  rpc MergeCarts(MergeCartsRequest) returns (Cart);
  rpc ApplyPromotion(ApplyPromotionRequest) returns (Cart);
}
```

**`api/checkout/v1/checkout.proto`**:
```protobuf
service CheckoutService {
  rpc StartCheckout(StartCheckoutRequest) returns (Checkout);
  rpc GetCheckout(GetCheckoutRequest) returns (Checkout);
  rpc UpdateShippingAddress(UpdateAddressRequest) returns (Checkout);
  rpc UpdateBillingAddress(UpdateAddressRequest) returns (Checkout);
  rpc SelectShippingMethod(SelectShippingMethodRequest) returns (Checkout);
  rpc PreviewOrder(PreviewOrderRequest) returns (OrderPreview);
  rpc ConfirmCheckout(ConfirmCheckoutRequest) returns (Order);
}
```

#### Event Publishing
**Events Published**:
- `cart.created` - New cart created
- `cart.item.added` - Item added to cart
- `cart.item.updated` - Item quantity changed
- `cart.item.removed` - Item removed
- `cart.abandoned` - Cart inactive for 30 days
- `cart.converted` - Cart converted to order
- `checkout.started` - Checkout session started
- `checkout.completed` - Order successfully created

---

### Return Service

#### Service Structure
Create new Return service:

```
return/
├── cmd/server/main.go
├── internal/
│   ├── biz/
│   │   ├── return/                     # Return management (from order/biz/return/)
│   │   │   ├── return.go               # Main return usecase (602 LOC refactored)
│   │   │   ├── events.go               # Event handling
│   │   │   ├── validation.go           # Return validation
│   │   │   ├── refund.go               # Refund orchestration
│   │   │   ├── restock.go              # Warehouse restock
│   │   │   ├── shipping.go             # Return shipping
│   │   │   └── exchange.go             # Exchange handling
│   │   └── events/                     # Event consumers
│   ├── data/
│   │   └── return_repo.go
│   ├── service/
│   │   └── return.go
│   └── server/
├── api/return/v1/
│   └── return.proto
├── migrations/
└── config/
```

#### [NEW] Database: `return_db`

**Tables to migrate from `order_db`**:
- `return_requests` - Return request data
- `return_items` - Returned items
- `return_status_history` - Status tracking
- `return_refunds` - Refund records
- `return_shipping` - Return shipping labels

**Migration Strategy**: Same as Checkout (dual-write mode)

#### Business Logic Migration

**From `order/internal/biz/return/` (8 files)** - Already refactored in Phase 1 ✅:
- [x] `return.go` (602 LOC) - Core return logic
- [x] `events.go` (316 LOC) - Event publishing & subscription
- [x] `validation.go` (65 LOC) - Return eligibility validation
- [x] `refund.go` (105 LOC) - Payment service integration
- [x] `restock.go` (82 LOC) - Warehouse integration
- [x] `shipping.go` (126 LOC) - Shipping service integration
- [x] `exchange.go` (222 LOC) - Exchange workflow

**External Service Integrations**:
- **Order Service**: Get order details, validate return eligibility
- **Payment Service**: Process refunds (idempotent)
- **Warehouse Service**: Restock items (async via events)
- **Shipping Service**: Generate return labels
- **Customer Service**: Notify customer

#### gRPC API Design

**`api/return/v1/return.proto`**:
```protobuf
service ReturnService {
  rpc CreateReturnRequest(CreateReturnRequest) returns (ReturnRequest);
  rpc GetReturnRequest(GetReturnRequestRequest) returns (ReturnRequest);
  rpc ListReturnRequests(ListReturnRequestsRequest) returns (ListReturnRequestsResponse);
  rpc ApproveReturn(ApproveReturnRequest) returns (ReturnRequest);
  rpc RejectReturn(RejectReturnRequest) returns (ReturnRequest);
  rpc ReceiveItems(ReceiveItemsRequest) returns (ReturnRequest);
  rpc ProcessRefund(ProcessRefundRequest) returns (ReturnRequest);
  rpc CancelReturn(CancelReturnRequest) returns (ReturnRequest);
}
```

#### Event-Driven Workflows

**Events Subscribed**:
- `order.shipped` - Enable return creation
- `order.delivered` - Start return window countdown

**Events Published**:
- `return.requested` - New return request
- `return.approved` - Return approved by CS
- `return.rejected` - Return rejected
- `return.items_received` - Items received at warehouse
- `refund.initiated` - Refund process started
- `refund.completed` - Refund completed
- `item.restocked` - Item returned to inventory

---

### Updated Order Service

After extraction, Order service will focus on:
- Order lifecycle management
- Order status tracking
- Order editing
- Cancellation workflows

**Remove from Order**:
- [ ] Delete `internal/biz/cart/` (entire folder)
- [ ] Delete `internal/biz/checkout/` (entire folder)
- [ ] Delete `internal/biz/return/` (entire folder)
- [ ] Update `internal/biz/order/` to call Checkout service for order creation
- [ ] Remove cart/checkout/return related database tables (after migration)

**New Dependencies**:
- Call Checkout service gRPC for getting cart/checkout data
- Call Return service gRPC for return operations

---

## Verification Plan

### Automated Tests

#### Unit Tests
**Checkout Service**:
```bash
# Run cart domain tests
cd checkout
go test ./internal/biz/cart/... -v -cover

# Run checkout domain tests
go test ./internal/biz/checkout/... -v -cover

# Verify coverage >80%
go test ./internal/biz/... -coverprofile=coverage.out
go tool cover -func=coverage.out | grep total
```

**Return Service**:
```bash
# Run return domain tests
cd return
go test ./internal/biz/return/... -v -cover

# Verify coverage >80%
go test ./internal/biz/... -coverprofile=coverage.out
```

**Existing Tests to Reuse**:
Based on file listing, the following tests exist:
- `order/internal/biz/cart/cart_test.go` - Migrate to `checkout/internal/biz/cart/cart_test.go`
- `order/internal/biz/cart/mocks_test.go` - Migrate mocks
- `order/internal/biz/cart/totals_internal_test.go` - Totals calculation tests

#### Integration Tests
```bash
# Test checkout flow end-to-end
cd checkout/test/integration
go test -v -tags=integration ./...

# Test return flow end-to-end
cd return/test/integration
go test -v -tags=integration ./...

# Test Order → Checkout → Return integration
cd order/test/integration
go test -v -tags=integration -run TestOrderToReturnFlow
```

### Manual Testing

#### Checkout Service Testing
1. **Create Cart**:
   ```bash
   grpcurl -plaintext -d '{"customer_id":"123"}' localhost:9003 checkout.v1.CartService/CreateCart
   ```
2. **Add Item to Cart**:
   ```bash
   grpcurl -plaintext -d '{"cart_id":"<cart_id>","product_id":"456","quantity":2}' \
     localhost:9003 checkout.v1.CartService/AddItem
   ```
3. **Start Checkout**:
   ```bash
   grpcurl -plaintext -d '{"cart_id":"<cart_id>"}' localhost:9003 checkout.v1.CheckoutService/StartCheckout
   ```
4. **Confirm Checkout** (creates order in Order service):
   ```bash
   grpcurl -plaintext -d '{"checkout_id":"<checkout_id>","payment_method_id":"789"}' \
     localhost:9003 checkout.v1.CheckoutService/ConfirmCheckout
   ```

#### Return Service Testing
1. **Create Return Request**:
   ```bash
   grpcurl -plaintext -d '{"order_id":"<order_id>","items":[{"order_item_id":"1","quantity":1,"reason":"defective"}]}' \
     localhost:9004 return.v1.ReturnService/CreateReturnRequest
   ```
2. **Approve Return**:
   ```bash
   grpcurl -plaintext -d '{"return_id":"<return_id>"}' localhost:9004 return.v1.ReturnService/ApproveReturn
   ```
3. **Verify Refund**:
   - Check Payment service logs for refund transaction
   - Verify idempotency (retry refund should not create duplicate)

#### End-to-End Flow
1. Add items to cart → Start checkout → Confirm order
2. Wait for order to be shipped (simulate via Order service)
3. Create return request → Approve → Receive items → Process refund
4. Verify warehouse restock event received
5. Check customer refund in Payment service

### Deployment Verification

**Dev Environment**:
```bash
# Check service health
curl http://checkout-dev.local/health
curl http://return-dev.local/health

# Verify database connections
kubectl logs -n dev checkout-<pod> | grep "database connected"
kubectl logs -n dev return-<pod> | grep "database connected"

# Check Dapr sidecar
kubectl logs -n dev checkout-<pod> -c daprd
```

**Staging Environment**:
- [ ] Run load test: 1000 concurrent cart operations (p95 <50ms)
- [ ] Test feature flag rollout (10% → 50% → 100%)
- [ ] Verify event publishing to Dapr pub/sub
- [ ] Test service-to-service auth (if enabled)

**Production Monitoring**:
- [ ] Monitor cart creation rate (should match historical data)
- [ ] Monitor checkout conversion rate (track any drops)
- [ ] Monitor return request rate
- [ ] Alert on error rate >1%
- [ ] Dashboard: Checkout service latency (p50, p95, p99)

---

## Implementation Timeline

### Week 1-2: Checkout Service Setup
- [ ] Create `checkout` service skeleton (Kratos template)
- [ ] Set up database `checkout_db` in PostgreSQL
- [ ] Migrate cart/checkout tables schema
- [ ] Copy business logic files (cart 28 + checkout 26 files)
- [ ] Update imports and fix compilation errors
- [ ] Run unit tests
- **Deliverable**: Checkout service compiles and unit tests pass

### Week 3-4: Checkout Service Integration
- [ ] Implement gRPC service layer (cart + checkout protos)
- [ ] Integrate with external services (Catalog, Pricing, Promotion, Warehouse, Payment, Shipping)
- [ ] Add circuit breakers and retry logic (using common package)
- [ ] Implement event publishers (Dapr pub/sub)
- [ ] Write integration tests
- [ ] Deploy to dev environment
- **Deliverable**: Checkout service deployed to dev, integration tests pass

### Week 5-6: Return Service Setup
- [ ] Create `return` service skeleton
- [ ] Set up database `return_db`
- [ ] Migrate return tables schema
- [ ] Copy business logic files (return 8 files - already clean!)
- [ ] Implement gRPC service layer
- [ ] Integrate with Payment, Warehouse, Shipping services
- [ ] Implement event-driven workflows
- [ ] Deploy to dev environment
- **Deliverable**: Return service deployed to dev

### Week 7: Integration Testing & Bug Fixes
- [ ] Test Checkout → Order integration
- [ ] Test Order → Return integration
- [ ] Fix integration bugs
- [ ] Performance testing (load test cart operations)
- [ ] Security review (service-to-service auth)
- **Deliverable**: All services integrated and tested

### Week 8: Staging Deployment
- [ ] Deploy Checkout + Return to staging
- [ ] Run data migration (dual-write mode)
- [ ] Feature flag setup (environment-based)
- [ ] Staging smoke tests
- [ ] Load testing (1000 concurrent requests)
- **Deliverable**: Services running in staging

### Week 9-10: Production Rollout
- [ ] Deploy to production (parallel mode)
- [ ] Feature flag rollout: 10% traffic
- [ ] Monitor metrics (latency, error rate, conversion rate)
- [ ] Increase to 50% traffic
- [ ] Full rollout (100% traffic)
- [ ] Disable old code paths in Order service
- [ ] Remove cart/checkout/return code from Order service
- **Deliverable**: ✅ Checkout and Return services live in production

---

## Rollback Plan

If issues occur during production rollout:

1. **Immediate Rollback** (Feature flag):
   ```bash
   # Set feature flag to route 100% traffic back to Order service
   kubectl set env deployment/gateway -n production USE_CHECKOUT_SERVICE=false
   kubectl set env deployment/gateway -n production USE_RETURN_SERVICE=false
   ```

2. **Database Rollback** (Dual-write mode):
   - During transition period, both `order_db` and `checkout_db`/`return_db` are updated
   - Can switch back to reading from `order_db` immediately

3. **Gradual Rollback**:
   - Reduce traffic from 100% → 50% → 10% → 0%
   - Monitor for 24 hours at each level

4. **Full Rollback** (Worst case):
   - Revert Kubernetes deployments to previous version
   - Restore database from backup (if needed)
   - Remove new services from service mesh

---

## Success Criteria

**Technical**:
- ✅ Checkout service compiles and all unit tests pass
- ✅ Return service compiles and all unit tests pass
- ✅ Integration tests pass (Checkout → Order, Order → Return)
- ✅ Code coverage >80% for both services
- ✅ Order service reduced from 6,437 LOC → ~1,901 LOC (70% reduction)
- ✅ Service latency <100ms p95 for cart operations
- ✅ No data loss during migration

**Business**:
- ✅ Cart creation rate matches baseline
- ✅ Checkout conversion rate stable (no regression)
- ✅ Return request processing time <24 hours
- ✅ Zero downtime during deployment
- ✅ No customer-facing errors during rollout

**Operational**:
- ✅ Independent deployment for Checkout, Return, Order
- ✅ Monitoring dashboards set up (Grafana)
- ✅ Alert rules configured (error rate, latency)
- ✅ Runbook documentation complete
- ✅ Team training completed (separate teams can own services)

---

**Created**: 2026-01-23  
**Estimated Effort**: ~10 weeks (2 engineers)  
**Priority**: P0 - Critical for scalability  
**Status**: Ready for review

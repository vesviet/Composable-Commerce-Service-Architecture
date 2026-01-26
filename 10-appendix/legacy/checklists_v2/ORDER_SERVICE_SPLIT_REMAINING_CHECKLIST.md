# Order Service Split - Remaining Implementation Checklist

**Reference**:  
- `docs/workflow/checklists_v2/ORDER_SERVICE_SPLIT_IMPLEMENTATION.md`  
- `docs/workflow/checklists_v2/ORDER_SERVICE_SPLIT_STATUS.md`  
- `docs/workflow/checklists_v2/ORDER_SERVICE_SPLIT_TASKS.md`  

**Goal**: Hoàn tất các phần còn thiếu trong Checkout/Return services sau khi đã migrate code.  
**Scope**: Wiring, data layer completeness, migrations, tests, integration, deployment readiness.  
**Last Updated**: 2026-01-23

---

## ✅ Ground Truth (đã xác nhận trong codebase)

- `checkout/` và `return/` đã có cấu trúc service, proto, biz, service layer.  
- `order/` đã remove cart/checkout/return (theo status).  
- Wiring hiện tại **chưa** inject đủ dependencies (wire_gen.go chưa đầy đủ).  
- `checkout/migrations/` và `return/migrations/` thiếu nhiều table so với plan.

---

## P0 - Blocker (must fix trước khi chạy được service)

### 1) Hoàn thiện Wire/DI

**Checkout** (`checkout/cmd/server/wire.go`, `wire_gen.go`)
- [ ] Wire đầy đủ clients: catalog, pricing, promotion, warehouse, payment, shipping, order
- [ ] Wire adapters/services layer (external service interfaces)
- [ ] Wire event publisher (Dapr pub/sub)
- [ ] Wire transaction manager + outbox repo (nếu đang dùng)
- [ ] Wire cache helper (nếu cart/checkout đang cache)
- [ ] Re-generate `wire_gen.go` và build thành công

**Return** (`return/cmd/server/wire.go`, `wire_gen.go`)
- [ ] Wire return usecase với repositories đầy đủ
- [ ] Wire clients: order, payment, warehouse, shipping, customer
- [ ] Wire event publisher + sequence generator
- [ ] Re-generate `wire_gen.go` và build thành công

### 2) Remove order domain khỏi Checkout (kiến trúc sai)

- [ ] Xóa `checkout/internal/biz/order/`
- [ ] Xóa `checkout/internal/repository/order/`
- [ ] Xóa `checkout/internal/model/order*.go`
- [ ] Xóa `checkout/api/order/v1/*.proto`
- [ ] Thay thế bằng gRPC client gọi Order service khi confirm checkout

---

## P1 - High Priority (để đạt readiness)

### 3) Migrations còn thiếu (so với plan)

**Checkout**
- [ ] `cart_promotions` table
- [ ] `checkout_addresses` table
- [ ] `event_idempotency` table (nếu dùng outbox/idempotency)
- [ ] `failed_events` table (nếu có DLQ)
- [ ] Verify indexes + constraints theo order_db cũ

**Return**
- [ ] `return_status_history` table
- [ ] `return_refunds` table
- [ ] `return_shipping` table
- [ ] Verify indexes + constraints theo order_db cũ

### 4) Repository implementations đầy đủ

**Checkout**
- [ ] Verify `cart_repo.go`, `checkout_repo.go` cover full CRUD + eager loading
- [ ] Add missing methods required by biz layer (totals, promotions, address)

**Return**
- [ ] Verify `return_repo.go` cover status history, refunds, shipping, exchange
- [ ] Add missing methods referenced in biz layer

### 5) Event workflow readiness

**Checkout**
- [ ] Publish events: cart.created, cart.item.*, cart.converted, checkout.*
- [ ] Cart cleanup job → cart.abandoned

**Return**
- [ ] Subscribe: order.shipped, order.delivered
- [ ] Publish: return.*, refund.*, item.restocked
- [ ] Dead-letter & compensation logic (nếu plan có)

---

## P2 - Testing & Integration

### 6) Integration Tests
- [ ] `checkout/test/integration/` - Cart → Checkout → Order flow
- [ ] `return/test/integration/` - Order → Return → Refund flow
- [ ] Verify end-to-end with external services (can use mocks)

### 7) Unit Tests
- [ ] Migrate cart/checkout tests from order (if not yet)
- [ ] Add return unit tests: refund, restock, exchange
- [ ] Coverage >80% for biz layer

---

## P3 - Deployment & Ops Readiness

### 8) Database setup
- [ ] Create `checkout_db` and `return_db`
- [ ] Run migrations in dev/staging
- [ ] Dual-write mode setup

### 9) Staging rollout
- [ ] Deploy checkout & return
- [ ] Feature flags in gateway (USE_CHECKOUT_SERVICE / USE_RETURN_SERVICE)
- [ ] Smoke tests + load tests

### 10) Production rollout
- [ ] Gradual traffic rollout (10% → 50% → 100%)
- [ ] Monitor latency/error rate/conversion
- [ ] Disable dual-write + cleanup old tables

---

## Notes / Decisions Needed
- [ ] Confirm checkout session TTL + cleanup strategy
- [ ] Confirm feature-flag mechanism (env vs config)
- [ ] Confirm rollback plan (traffic vs DB)

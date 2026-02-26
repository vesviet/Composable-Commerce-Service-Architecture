# Fulfillment & Shipping — Workflow Review Checklist Template

**Purpose**: Reusable checklist for reviewing Fulfillment & Shipping business logic consistency.
**Pattern Reference**: Shopify, Shopee, Lazada — `docs/10-appendix/ecommerce-platform-flows.md` §9
**Services**: `fulfillment/`, `shipping/`

---

## How to Use

1. Copy this checklist for each review cycle.
2. Check each item against the actual code.
3. Mark status: ✅ OK, ⚠️ Risk, ❌ Broken.
4. Record severity: 🔴 P0 (blocker), 🟡 P1 (reliability), 🔵 P2 (improvement).
5. Create action items for all ⚠️ and ❌ items.

---

## A. Data Consistency Between Services

### A1. Fulfillment ↔ Warehouse
- [ ] Reservation validation (`active` check) before creating fulfillment
- [ ] `ConfirmReservation` called only when picklist is completed
- [ ] `AdjustStock` for unpicked quantity after partial pick
- [ ] `AdjustStock` failure during cancellation is fatal (rolls back tx)
- [ ] `ReleaseReservation` called on fullment cancellation before pick
- [ ] `HandleQCFailed` does NOT release reservation when re-packing is intended

### A2. Fulfillment → Shipping (gRPC)
- [ ] `ShipFulfillment` passes correct `OrderID`, `FulfillmentID`, `CustomerId` in gRPC request
- [ ] Carrier and ServiceType come from order metadata / shipping method (NOT hardcoded)
- [ ] Shipment ID stored in typed field (not fragile metadata JSON)
- [ ] `ShipFulfillment` is idempotent — checks for existing shipment before creating
- [ ] gRPC call outside DB transaction OR saga compensation for orphaned shipments

### A3. Shipping → Fulfillment (event callback)
- [ ] `shipment.delivered` event consumed by fulfillment worker
- [ ] Fulfillment auto-completes on delivery event
- [ ] Previous status in `shipment.status_changed` event reflects actual state (not hardcoded)

### A4. Order → Fulfillment (cancellation)
- [ ] `handleOrderCancelled` cancels ALL fulfillments for multi-warehouse orders (not just first)
- [ ] Stock released for all cancelled fulfillments
- [ ] Already-shipped fulfillments are skipped during cancellation

### A5. COD Distribution
- [ ] `computeProRataCOD` distributes COD proportionally by item value
- [ ] Rounding remainder assigned to last warehouse
- [ ] Edge case: zero-value items handled gracefully

---

## B. Data Mismatch Detection

- [ ] Fulfillment ID type (UUID string) matches Shipping ID type (int64 or string) in proto
- [ ] Event payload schemas are consistent between publisher and consumer:
  - `fulfillment.status_changed` — producer: fulfillment, consumer: order/shipping
  - `package.status_changed` — producer: fulfillment, consumer: shipping
  - `shipment.delivered` — producer: shipping, consumer: fulfillment/order
  - `shipment.status_changed` — producer: shipping, consumer: order/notification
- [ ] Topic names match between publisher and subscriber (no prefix mismatch like `shipping.shipment.X` vs `shipment.X`)

---

## C. Retry / Rollback / Saga / Outbox

### C1. Outbox Pattern — Fulfillment
- [ ] All state-changing events written to outbox inside `InTx`
- [ ] `commonOutbox.Worker` registered in `cmd/worker/wire.go:newWorkers()`
- [ ] `wire.go` and `wire_gen.go` are in sync (no manual edits to `wire_gen.go`)
- [ ] Outbox topic = `eventType` (not `aggregateType`)

### C2. Outbox Pattern — Shipping
- [ ] `OutboxWorker` implements `ContinuousWorker` interface
- [ ] `OutboxWorker` registered in `cmd/worker/wire.go:newWorkers()`
- [ ] `wire.go` and `wire_gen.go` are in sync
- [ ] Outbox topic mapping is consistent (`event.Type` as topic)
- [ ] MaxRetries configured with exponential backoff
- [ ] Old events cleaned up periodically (daily cron)

### C3. Saga / Compensation
- [ ] `handleOrderConfirmed`: rollback planned fulfillments if any `StartPlanning` fails
- [ ] `ShipFulfillment`: idempotent shipment creation (check-before-create)
- [ ] `compensatePackageShipped`: reverts to actual previous status (not hardcoded)
- [ ] `CancelShipmentsForOrder`: atomic or error-aggregating for multi-shipment cancel

---

## D. Edge Cases & Risk Items

### D1. Multi-warehouse orders
- [ ] Multiple fulfillments created per order (one per warehouse)
- [ ] ALL fulfillments cancelled on order cancellation (not just first)
- [ ] COD split correctly across warehouses

### D2. Warehouse selection
- [ ] Stock check failure: fail-closed (error) not fail-open (all warehouses)
- [ ] Capacity check failure: circuit breaker or graceful degradation
- [ ] No active warehouses: clear error returned

### D3. Carrier integration
- [ ] Carrier selected from order metadata (not hardcoded)
- [ ] Carrier failover supported
- [ ] Label generation inside transaction

### D4. Delivery confirmation
- [ ] `ConfirmDelivery` captures actual previous status
- [ ] Proof of delivery (signature, photo) stored
- [ ] RBAC: shippers can only confirm own assigned shipments

### D5. Auto-completion
- [ ] `AutoCompleteShippedWorker` transitions shipped fulfillments to completed after SLA
- [ ] SLA breach detector runs and publishes breach events
- [ ] Both cron jobs registered in worker binary

---

## E. Event Architecture

### E1. Fulfillment — Events Published
- [ ] `fulfillment.status_changed` — via outbox, dispatched
- [ ] `package.status_changed` — via outbox, dispatched
- [ ] `picklist.status_changed` — via outbox, dispatched
- [ ] `fulfillment.sla_breach` — via outbox, dispatched (requires SLA job wired)

### E2. Fulfillment — Events Consumed
- [ ] `orders.order_status_changed` — with idempotency
- [ ] `fulfillment.picklist_status_changed` — with idempotency
- [ ] `shipment.delivered` — with idempotency (DeriveEventID)

### E3. Shipping — Events Published
- [ ] `shipment.created` — via outbox, dispatched by outbox worker
- [ ] `shipment.status_changed` — via outbox, dispatched
- [ ] `shipment.delivered` — via outbox, dispatched
- [ ] `shipment.tracking_updated` — via outbox, dispatched

### E4. Shipping — Events Consumed
- [ ] `package.status_changed` — with idempotency
- [ ] `orders.order_cancelled` — with idempotency

### E5. Cross-Service Event Flow
- [ ] Trace full flow: Order → Fulfillment → Shipping → Delivery → Completion
- [ ] All events arrive at consumers (no dead outbox workers)
- [ ] Topic names match between publisher and subscriber

---

## F. GitOps Configuration

### F1. Worker Deployments
- [ ] `worker-deployment.yaml` exists for both services
- [ ] Dapr annotations correct: `app-id`, `app-port=5005`, `app-protocol=grpc`
- [ ] `secretRef` configured for DB/API credentials
- [ ] Health probes match actual binary ports (gRPC 5005, not HTTP 8081)
- [ ] Startup probe uses `tcpSocket` or `grpc` on port 5005
- [ ] Liveness/readiness probes use `grpc` on port 5005 (not `httpGet`)
- [ ] Resource limits set (memory/CPU)
- [ ] `revisionHistoryLimit: 1` set
- [ ] No dead/unused env vars

### F2. HPA (Horizontal Pod Autoscaler)
- [ ] Worker HPA exists for fulfillment
- [ ] Worker HPA exists for shipping
- [ ] Main service HPA exists for both

### F3. ConfigMap/Secret
- [ ] All env vars used in code have corresponding ConfigMap/Secret entries
- [ ] No sensitive values in ConfigMap (use Secrets)
- [ ] Carrier API keys in Secrets (not hardcoded)

---

## G. Worker & Cron Job Verification

### G1. Fulfillment Worker Binary
- [ ] All workers in `wire.go:newWorkers()` match `wire_gen.go:newWorkers()`
- [ ] `AutoCompleteShippedWorker` — wired and running
- [ ] `SLABreachDetectorJob` — wired in BOTH `wire.go` and `wire_gen.go`
- [ ] `OrderStatusConsumerWorker` — wired
- [ ] `PicklistStatusConsumerWorker` — wired
- [ ] `ShipmentDeliveredConsumerWorker` — wired
- [ ] `commonOutbox.Worker` — wired

### G2. Shipping Worker Binary
- [ ] All workers in `wire.go:newWorkers()` match `wire_gen.go:newWorkers()`
- [ ] `OutboxWorker` — wired AND implements `ContinuousWorker`
- [ ] `PackageStatusConsumerWorker` — wired
- [ ] `OrderCancelledConsumerWorker` — wired
- [ ] `EventbusServerWorker` — wired

---

## H. Comparison with ecommerce-platform-flows.md §9

### §9.1 Pick, Pack & Ship
- [ ] Order → pick task assigned to warehouse staff
- [ ] Batch picking supported
- [ ] Packing confirmation with item verification
- [ ] Shipping label generation via carrier API
- [ ] Handover to carrier recorded

### §9.2 Shipping Methods
- [ ] Standard, Express, Same-day, Instant supported
- [ ] Click & Collect supported
- [ ] International shipping supported

### §9.3 Carrier Integration
- [ ] Multi-carrier rate shopping
- [ ] Label generation via carrier API (not mock)
- [ ] Tracking events via carrier webhook
- [ ] Failed delivery retry scheduling
- [ ] Return to sender on max attempts

### §9.4 Last Mile
- [ ] Driver assignment
- [ ] Proof of delivery capture (signature, photo)
- [ ] Failed delivery handling (re-schedule)

### §9.5 SLA & Commitment Tracking
- [ ] Seller ship-by SLA tracking
- [ ] Carrier delivery SLA tracking
- [ ] SLA breach alert & escalation
- [ ] Late shipment penalty calculation

---

## Review Output Template

```markdown
## Review: Fulfillment & Shipping — [Date]

### Issue Summary
| Severity | Count | Fixed | Remaining |
|----------|-------|-------|-----------|
| 🔴 P0   | X     | X     | X         |
| 🟡 P1   | X     | X     | X         |
| 🔵 P2   | X     | X     | X         |

### P0 Issues
1. **[CATEGORY]** location — description

### P1 Issues
1. **[CATEGORY]** location — description

### P2 Issues
1. **[CATEGORY]** location — description

### Action Items
- [ ] P0-1: description (owner, ETA)
- [ ] P1-1: description
```

---

*Template version: 2026-02-26*

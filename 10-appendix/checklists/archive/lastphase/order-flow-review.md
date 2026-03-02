# Order Flow Review — Last Phase

> **Review Date:** 2026-02-20 | **Patterns:** Shopify/Shopee/Lazada | **Coverage:** order, fulfillment, shipping, return (+ payment/warehouse integration)

---

## 1. Order Lifetime Flow (End-to-End)

```
Checkout → CreateOrder (order service)
  ↓ (Outbox → orders.order.status_changed: pending)
COD: CODAutoConfirmJob (1min poll) → status: confirmed
Online: payment.confirmed event → processPaymentConfirmed → status: confirmed
  ↓ (Outbox → orders.order.status_changed: confirmed)
Fulfillment Service: handleOrderConfirmed → CreateFromOrderMulti → StartPlanning
  ↓ picks picklist → QC → pack → ship
Fulfillment publishes fulfillment_status event → Order: ProcessShipment
  → status: partially_shipped OR shipped
  ↓ (Outbox → orders.order.status_changed: shipped)
Customer marks delivered / auto-delivered cron
  → status: delivered
  ↓ (Outbox → orders.order.completed)
Loyalty + Analytics consume orders.order.completed

Return Flow (post-delivery):
Customer → CreateReturnRequest → CheckReturnEligibility (30-day window)
  → pending → approved → processing (items received) → completed
    → processReturnRefund + restockReturnedItems + PublishReturnCompleted
  → Return events consumed by: order (update status), warehouse (restock trigger), payment (refund trigger)
```

---

## 2. Status Transition Map

```
pending → confirmed | cancelled | failed
confirmed → processing | cancelled
processing → partially_shipped | shipped | cancelled
partially_shipped → shipped | cancelled
shipped → delivered | cancelled
delivered → refunded
failed → pending
refunded → (terminal)
cancelled → (terminal)
```
- ✅ Enforced via `canTransitionTo()` + `OrderStatusTransitions` map (all operations use same helper)
- ✅ Atomicity: status update + status history in same `tm.WithTransaction()`

---

## 3. Data Consistency Analysis

### 3.1 Order ↔ Payment Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Payment authorized before order created (by checkout) | ✅ Done | Checkout handles pre-auth |
| payment.confirmed → order status: confirmed | ✅ Done | PaymentConsumer (order worker) |
| payment.failed → order status: failed + release reservations | ✅ Done | PaymentConsumer with DLQ fallback |
| Capture uses DB total, not event amount | ✅ Done | M-4 fix in payment_consumer |
| Auth expiry pre-capture check (7-day configurable) | ✅ Done | E-10 fix in payment_consumer |
| **Dual event publish: outbox at create + fire-and-forget on status changes** | ⚠️ RISK | **Risk 1** |
| COD: payment_status stays "pending" until delivery confirmed | ✅ Design intent | CODAutoConfirmJob handles status flow |

### 3.2 Order ↔ Stock/Warehouse Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Reservations created at checkout StartCheckout | ✅ Done | Checkout service only |
| Reservations confirmed only on payment_confirmed | ✅ Done | Fixed: removed duplicate confirmation in create.go |
| `inventory.stock.committed` event after confirmOrderReservations | ✅ Done | publishStockCommittedEvent via outbox |
| Cancel: release with 3 retries + DLQ + fallback restock if "not active" | ✅ Done | cancel.go:releaseReservationWithRetry |
| Warehouse restock if no WarehouseID on cancel | ⚠️ | Logs STOCK_LEAK but no automated fix |
| Over-ship guard in ProcessShipment | ✅ Done | shipment.go:L113 |
| **`inventory.stock.committed` topic has no confirmed subscriber** | ⚠️ RISK | **Risk 2** |

### 3.3 Order ↔ Fulfillment Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Fulfillment created on order.confirmed event | ✅ Done | FulfillmentUseCase.HandleOrderStatusChanged |
| Multi-warehouse orders: CreateFromOrderMulti | ✅ Done | Multiple fulfillments per order |
| Fulfillment cancelled on order.cancelled | ✅ Done | handleOrderCancelled (skips if shipped/completed) |
| No action on shipped/delivered status from order | ✅ Done | Fulfillment owns those transitions |
| COD order correctly identified (PaymentMethod + metadata check) | ✅ Done | isCOD check in handler |
| **StartPlanning fails for one fulfillment → other fulfillments still start** | ⚠️ RISK | **Risk 3** |
| **No idempotency on create fulfillment (event replayed = duplicate)** | ⚠️ RISK | **Risk 4** (partial — FindByOrderID checks) |

### 3.4 Order ↔ Shipping Consistency
| Check | Status | Notes |
|-------|--------|-------|
| ProcessShipment: idempotency by ShipmentID | ✅ Done | shipment.go:L27-31 |
| Partial ship → partially_shipped, all shipped → shipped | ✅ Done | Logic in shipment.go |
| Backward transition (shipped→partially_shipped) blocked | ✅ Done | Status guard at L163 |
| Status update failure on shipment creation doesn't abort shipment | ⚠️ | Log + continue (non-fatal) — **Risk 5** |

### 3.5 Return ↔ Order/Payment/Warehouse Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Return eligibility: status must be delivered/completed | ✅ Done | CheckReturnEligibility |
| Return window: 30 days (hardcoded, uses UpdatedAt fallback) | ⚠️ | **Risk 6**: uses UpdatedAt if CompletedAt nil — window may be shorter than expected |
| Active return dedup (pending/approved/processing) | ✅ Done | E-20 — prevents double-return |
| Return qty validated against ordered qty | ✅ Done | E-21 |
| Refund on status=completed (return type only) | ✅ Done | processReturnRefund (non-blocking with outbox retry) |
| Restock on completed | ✅ Done | restockReturnedItems (non-blocking) |
| Return type forced to "return" in returnRequest (ignores req.ReturnType in model) | ⚠️ | **Risk 7**: CreateReturnRequest hardcodes `ReturnType: "return"` at line 136 even when Exchange requested |
| Exchange flow: processExchangeOrder on completed | ✅ Done | Separate path for exchange type |
| **Refund/restock failure: "will retry via outbox" — but no actual DLQ wiring for return** | ⚠️ RISK | **Risk 8** |

---

## 4. Saga / Outbox / Retry Analysis

### 4.1 Order Service — Dual Event Publish Pattern ⚠️
| Path | Method | Reliability |
|------|--------|------------|
| `CreateOrder` | Outbox (atomic in TX) → OutboxWorker → Dapr | ✅ At-least-once |
| `CancelOrder`, `ProcessOrder`, `UpdateOrderStatus` | `PublishOrderStatusChangedEvent()` — direct Dapr call (fire-and-forget) | ❌ **Risk 1** — event lost on transient failure |
| `OrderCompleted`/`OrderCancelled` | Direct publish via `EventPublisher` | ❌ **Risk 1** — event lost on transient failure |

**Risk 1 Impact:** If warehouse/fulfillment/notification miss the event (network hiccup, Dapr restart), order state diverges silently. Fix: route ALL status-changed events through outbox.

### 4.2 Order Worker — Cron Jobs
| Worker | Interval | Function | Risk |
|--------|----------|---------|------|
| `OutboxWorker` | 1s continuous | Publish order.status_changed events from outbox | ✅ OK |
| `CODAutoConfirmJob` | 1min | Auto-confirm COD pending orders (100/batch) | ⚠️ **Risk 9** |
| `CaptureRetryWorker` | — | Retry failed payment captures | ✅ OK |
| `DLQRetryWorker` | 5min (30s startup) | void/release/refund/capture retry | ✅ OK |
| `OrderCleanupWorker` | — | Archive expired unpaid orders | ✅ OK |
| `PaymentCompensationWorker` | — | Payment compensation operations | ✅ OK |
| `ReservationCleanupWorker` | — | Release expired reservations | ✅ OK |

### 4.3 DLQ Retry Configuration (Order Worker)
| Operation | Max Retries | Backoff | Notes |
|-----------|-------------|---------|-------|
| `void_authorization` | Configurable | 5min → 30min exp | Uses comp.AuthorizationID |
| `release_reservations` | Configurable | 5min → 30min exp | ⚠️ Falls back to OrderID if no AuthorizationID — **Risk 10** |
| `refund` | Configurable | 5min → 30min exp | Reads payment_id from order metadata |
| `payment_capture` | Configurable | 5min → 30min exp | Reads from order TotalAmount (DB authoritative) |

### 4.4 Return Service — Outbox Usage
- Return service uses `outbox.Repository` from `common/outbox`
- Events (ReturnRequested, ReturnApproved, ReturnRejected, ReturnCompleted) published via `eventPublisher` — **direct publish, not via outbox**
- "will retry via outbox" comments in return.go refer to refund/restock outbox, but the actual wiring is unclear — **Risk 8**

---

## 5. Event / Consumer Verification

### 5.1 Order Service — Events Published
| Event | Topic | Method | Subscribers |
|-------|-------|--------|-------------|
| order created | `orders.order.status_changed` | Outbox ✅ | fulfillment, warehouse, notification, search |
| status changed (cancel/process/update) | `orders.order.status_changed` | ❌ Fire-and-forget | fulfillment, warehouse, notification |
| order completed | `orders.order.completed` | Direct publish | loyalty-rewards, analytics |
| order cancelled | `orders.order.cancelled` | Direct publish | loyalty-rewards |
| stock committed | `inventory.stock.committed` | Outbox ✅ | ❓ **No confirmed subscriber** |
| reservation release DLQ | `compensation.reservation_release` | Outbox ✅ | ❓ **No confirmed subscriber** |
| payment status events | Via payment service outbox | payment consumer → order | ✅ OK |

### 5.2 Order Service — Events Consumed (Order Worker)
| Consumer | Topic | Status |
|----------|-------|--------|
| `PaymentConsumer` | `payment.confirmed`, `payment.failed`, `orders.payment.capture_requested` | ✅ Verified |
| `FulfillmentConsumer` | `fulfillment.status_changed` | ✅ Verified |
| `ShippingConsumer` | `shipping.status_changed` | ✅ Verified |
| `WarehouseConsumer` | `warehouse.stock_updated` | ✅ Verified |

### 5.3 Fulfillment Service
| Publishes? | Topic | Subscribers |
|-----------|-------|-------------|
| ✅ YES | `fulfillment.status_changed` | order (ProcessShipment), shipping |
| ✅ YES | `picklist.status_changed` | fulfillment itself (picklist_status_consumer) |
| Consumes | `orders.order.status_changed` | order_status_consumer |
| Consumes | `picklist.status_changed` | picklist_status_consumer |

### 5.4 Shipping Service
| Publishes? | Topic | Subscribers |
|-----------|-------|-------------|
| ✅ YES | `shipping.status_changed` | order (ShippingConsumer) |
| Consumes | `package_status_consumer` | From carrier/logistics updates |

### 5.5 Return Service
| Publishes? | Topic | Subscribers |
|-----------|-------|-------------|
| ✅ YES | `orders.return.requested` | Order (updates to return status) |
| ✅ YES | `orders.return.approved` | Notification, Warehouse |
| ✅ YES | `orders.return.rejected` | Notification |
| ✅ YES | `orders.return.completed` | Warehouse (restock), Payment (refund) |
| Consumes | ❌ Nothing (gRPC calls to order/shipping/payment/warehouse) | — |

### 5.6 Services Verified — DO NOT Need Events
| Service | Reason |
|---------|--------|
| **pricing** | gRPC only, order uses pricing for enrichment |
| **catalog** | gRPC only, order uses catalog for item enrichment |
| **location** | Reference data, no order flow participation |

---

## 6. Logic Risks & Edge Cases

### 🔴 Risk 1: Fire-and-Forget Event Publish on Status Changes (NOT Outbox)
- **What:** `CancelOrder`, `ProcessOrder`, `UpdateOrderStatus` call `PublishOrderStatusChangedEvent()` directly (not via outbox). If Dapr is temporarily unavailable, event is lost silently.
- **Impact:** Fulfillment never gets cancellation → continues picking/packing. Warehouse never deducts stock on cancel. Notification never sends.
- **Fix:** Route all `orders.order.status_changed` events through outbox (same pattern as `CreateOrder`). The outbox worker guarantees at-least-once delivery.

### 🔴 Risk 2: `inventory.stock.committed` Topic Has No Subscriber
- **What:** `publishStockCommittedEvent` saves to outbox and publishes `inventory.stock.committed`. No service in codebase subscribes to this topic.
- **Impact:** Outbox grows with unprocessed events; logic depending on this event is silently broken.
- **Fix:** Either add a warehouse consumer for this event (to track committed stock separately from reserved stock) or remove the event if warehouse manages via gRPC ConfirmReservation.

### 🔴 Risk 3: Partial Fulfillment Failure — No Compensation
- **What:** `handleOrderConfirmed` calls `StartPlanning` for each fulfillment in a loop. On failure, it logs and `continue`s — no rollback of already-started fulfillments.
- **Impact:** Multi-warehouse order has Warehouse A fulfillment started but Warehouse B failed → partial fulfillment started with no retry mechanism for the failed one.
- **Fix:** Add retry logic or write a `failed_fulfillment_start` compensation record for the failed fulfillment.

### 🟡 Risk 4: Fulfillment Creation Idempotency on Event Replay
- **What:** `handleOrderConfirmed` calls `FindByOrderID` to check for existing fulfillment. If a single fulfillment exists (not for all warehouses), it won't create missing ones.
- **Impact:** If order.confirmed event is replayed after a crash during multi-warehouse fulfillment creation, already-created fulfillments are found → returns nil, missing ones never created.
- **Fix:** Use per-warehouse lookup in `FindByOrderID` or implement `FindByOrderIDAndWarehouseID` for idempotency.

### 🟡 Risk 5: Shipment Status Update Failure is Non-Fatal
- **What:** In `ProcessShipment`, if UpdateOrderStatus fails after CreateShipment, it logs and returns `nil` (shipment is created, order status not updated).
- **Impact:** Shipment record exists in order DB, but order status stays "processing" — tracking shows no shipment even though physical shipment started.
- **Fix:** Either make status update failure return an error (with Dapr retry), or use a Saga compensation to rollback the shipment.

### 🟡 Risk 6: Return Window Uses UpdatedAt as Fallback
- **What:** `CheckReturnEligibility` uses `order.CompletedAt` for the 30-day window, but falls back to `order.UpdatedAt` if nil.
- **Impact:** `UpdatedAt` changes on every status change, effectively giving customers a rolling 30-day window after any status update, not just delivery confirmation.
- **Fix:** Use `DeliveredAt` timestamp explicitly, or fail-safe to no-return if CompletedAt is nil.

### 🟡 Risk 7: Exchange Request Creates `ReturnType: "return"` in DB
- **What:** `CreateReturnRequest` hardcodes `ReturnType: "return"` (line 136 of return.go) regardless of `req.ReturnType`. `CreateExchangeRequest` calls it with `req.ReturnType = "exchange"`, but the model always saves "return".
- **Impact:** Exchange requests stored as "return" in DB. When status=completed, code checks `returnRequest.ReturnType == "return"` → triggers refund path instead of exchange path → customer gets cash refund instead of replacement product.
- **Fix:** Remove hardcoded `ReturnType: "return"`. Set from `req.ReturnType`.

### 🟡 Risk 8: Return Refund/Restock "Retry via Outbox" Claim Not Verified
- **What:** Comments in return.go say "will retry via outbox/DLQ" but `processReturnRefund` and `restockReturnedItems` call Payment/Warehouse services directly without persisting compensation records on failure.
- **Impact:** Failed refunds on completed returns are silently dropped — customer doesn't get their money back.
- **Fix:** Add explicit DLQ record (FailedCompensation) on processReturnRefund failure, similar to checkout's `apply_promotion` pattern.

### 🟡 Risk 9: COD Auto-Confirm Batch Size = 100 Without Pagination
- **What:** `CODAutoConfirmJob` fetches up to 100 orders per run (1-minute interval). If > 100 COD orders pile up (high traffic), some will be missed until the next run.
- **Impact:** COD orders experience confirmation delays > 1 minute during peak load.
- **Fix:** Add cursor-based pagination loop within each job run, or increase batch size with monitoring.

### 🟡 Risk 10: DLQ `release_reservations` Falls Back to OrderID as ReservationID
- **What:** `retryReleaseReservations` in DLQRetryWorker uses `comp.AuthorizationID` as the reservation ID. If AuthorizationID is nil, it falls back to `comp.OrderID` — which is NOT a valid reservation ID.
- **Impact:** The DLQ retry calls `ReleaseReservation(ctx, orderID)` which will always fail (invalid ID), causing the entry to exhaust max retries without ever actually releasing stock.
- **Fix:** Store actual reservation IDs in the FailedCompensation record (as JSON metadata), and parse them in `retryReleaseReservations`.

### 🟡 Risk 11: Order Worker Missing `secretRef` in GitOps
- **What:** `worker-deployment.yaml` has `configMapRef: overlays-config` but no `secretRef: order-secrets`. The main service deployment has secrets; the worker may not if overlays-config doesn't include secrets.
- **Impact:** Worker may start without DB credentials / Redis / Dapr config → crash on startup.
- **Fix:** Add `secretRef: order-secrets` to worker-deployment.yaml, consistent with main service.

### 🟢 Risk 12: Return Service Event Publisher is Direct (Not Outbox)
- **What:** Return events (ReturnRequested, ReturnApproved, etc.) use `eventPublisher.Publish*()` directly, not via outbox. Events can be lost on publisher failure.
- **Impact:** Downstream services (order, warehouse, notification) miss return lifecycle events.
- **Fix:** Route all return events through the return service's outbox repository (outboxRepo is already injected in ReturnUsecase).

### 🟢 Risk 13: Hardcoded 30-Day Return Window
- **What:** `ReturnWindowDays: 30` hardcoded in `CreateReturnRequest` model. No product-category-based policy (Shopee: 7-30 days by category, Lazada: 15 days standard).
- **Impact:** Cannot implement per-category return policies (e.g., electronics 7 days, apparel 30 days).
- **Fix:** Look up return policy from catalog product attributes or a configurable policy service.

---

## 7. GitOps Configuration Review

### 7.1 Order Service GitOps ✅
| Item | Status | Notes |
|------|--------|-------|
| Main deployment | ✅ | `deployment.yaml` — Dapr enabled |
| **Worker deployment** | ✅ | `worker-deployment.yaml` present |
| PDB (PodDisruptionBudget) | ✅ | `pdb.yaml` present |
| NetworkPolicy | ✅ | Comprehensive egress rules |
| init containers (wait for Consul, Redis, PostgreSQL) | ✅ | Proper dependency ordering |
| secretRef in worker | ⚠️ | **Risk 11**: No `secretRef` in worker-deployment.yaml |
| sync-wave | ✅ | wave 8 (after infrastructure) |
| Dapr app-id on worker | ✅ | `order-worker` (separate from main `order`) |

### 7.2 Fulfillment GitOps
| Item | Status | Notes |
|------|--------|-------|
| Deployment | Need to verify | Not checked in detail |
| Worker | Need to verify | Check for separate consumer worker |

### 7.3 Shipping GitOps
| Item | Status | Notes |
|------|--------|-------|
| Worker deployment | Need to verify | Shipping has worker binary |

### 7.4 Return GitOps
| Item | Status | Notes |
|------|--------|-------|
| No worker binary | ✅ | Return service uses only main binary (no background workers) |
| Worker needed? | ⚠️ | Should have outbox worker if we fix Risk 12 |

---

## 8. Confirmed Architecture Sign-off Checklist

### ✅ Implemented Correctly
- [x] Order creation: Outbox pattern (atomic with DB record)
- [x] DB-level idempotency via `cart_session_id` unique constraint
- [x] Status transition validation via `canTransitionTo()` + `OrderStatusTransitions` map
- [x] Status update + history atomically in same transaction
- [x] Cancel: release reservation with 3 retries + DLQ + fallback restock
- [x] Over-ship guard in ProcessShipment
- [x] Shipment idempotency by ShipmentID
- [x] COD auto-confirm cron (1min interval, 100/batch)
- [x] DLQ retry with exponential backoff (5min→30min)
- [x] Order worker deployed separately in GitOps (worker-deployment.yaml)
- [x] Fulfillment created on order.confirmed, cancelled on order.cancelled
- [x] Multi-warehouse fulfillment via CreateFromOrderMulti
- [x] Return eligibility: delivery check + 30-day window + active dedup
- [x] Return qty validation against ordered qty
- [x] Payment capture re-validates stock before calling gateway
- [x] Refund uses DB total (authoritative), not event amount

### ❌ Action Items Required (Prioritized)
| Priority | Risk | Action |
|----------|------|--------|
| 🔴 P0 | **Risk 1**: Status-changed events not via outbox | Route all status changes through outbox table |
| 🔴 P0 | **Risk 7**: Exchange stored as return → triggers refund instead of exchange | Remove hardcoded ReturnType in CreateReturnRequest |
| 🔴 P0 | **Risk 8**: Return refund failure drops silently | Add DLQ compensation record on processReturnRefund failure |
| 🟡 P1 | **Risk 2**: inventory.stock.committed no subscriber | Remove event or add warehouse consumer |
| 🟡 P1 | **Risk 3**: Multi-warehouse partial fulfillment failure no rollback | Add compensation for failed StartPlanning |
| 🟡 P1 | **Risk 6**: Return window uses UpdatedAt fallback | Use DeliveredAt explicitly |
| 🟡 P1 | **Risk 10**: DLQ release_reservations uses OrderID as fallback | Store reservation IDs in metadata |
| 🟡 P1 | **Risk 11**: Worker missing secretRef in GitOps | Add secretRef to worker-deployment.yaml |
| 🟡 P2 | **Risk 4**: Fulfillment idempotency on event replay | Per-warehouse idempotency check |
| 🟡 P2 | **Risk 5**: Shipment status failure is non-fatal | Return error or use compensation |
| 🟡 P2 | **Risk 9**: COD batch size = 100 without pagination | Add cursor-based pagination loop |
| 🟡 P2 | **Risk 12**: Return events direct publish, not outbox | Route via outbox for at-least-once |
| 🟡 P2 | **Risk 13**: Hardcoded 30-day return window | Configurable per-category policy |

---

## 9. Service Event Matrix (Order Flow)

| Service | Publishes | Publish Method | Subscribes To |
|---------|-----------|---------------|---------------|
| **order** | `orders.order.status_changed`, `orders.order.completed`, `orders.order.cancelled`, `inventory.stock.committed`, `compensation.reservation_release` | ⚠️ Mixed (Outbox for create; fire-and-forget for others) | `payment.confirmed/failed`, `fulfillment.status_changed`, `shipping.status_changed`, `warehouse.stock_updated` |
| **fulfillment** | `fulfillment.status_changed`, `picklist.status_changed` | ✅ (via events) | `orders.order.status_changed`, `picklist.status_changed` |
| **shipping** | `shipping.status_changed` | ✅ (via events) | `package_status_changed` |
| **return** | `orders.return.*` (4 events) | ❌ Direct (not outbox) | ❌ Nothing (gRPC only for reads) |
| **payment** | `payment.confirmed/failed/captured/capture_failed` | ✅ Outbox (via order worker) | `return.*` |
| **warehouse** | ❌ None (gRPC only in order flow) | — | `orders.order.status_changed`, `fulfillment_status`, `return.*` |
| **notification** | ❌ None | — | `orders.order.status_changed` |
| **loyalty-rewards** | ❌ None | — | `orders.order.completed`, `orders.order.cancelled` |
| **analytics** | ❌ None | — | `orders.order.completed` |

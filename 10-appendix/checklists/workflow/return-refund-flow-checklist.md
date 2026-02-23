# Return & Refund Flow — Business Logic Review Checklist

**Date**: 2026-02-21
**Reviewer**: AI Review (Shopify/Shopee/Lazada patterns + codebase analysis)
**Scope**: `return/`, `order/`, `payment/`, `warehouse/`, `shipping/`

> Previous active issues: [return_refund_issues.md](../active/return_refund_issues.md)
> Based on: `ecommerce-platform-flows.md` section 10, direct code review of `return/internal/biz/return/`

---

## 1. Data Consistency Between Services

| Data Point | Source of Truth | Consumer | Status | Risk |
|------------|----------------|----------|--------|------|
| Return eligibility (30-day window) | Order service `CompletedAt` | Return `CheckReturnEligibility` | ✅ Fail-safe on nil CompletedAt | Uses delivery date, not update date |
| Return request deduplication | DB unique constraint (`idx_returns_order_active_unique`) | `CreateReturnRequest` | ✅ Idempotent via constraint + retry | Concurrent creation handled |
| Return item quantity vs. ordered quantity | Order service `GetOrderItems` | `CreateReturnRequest:192` | ✅ Validated: `itemReq.Quantity > orderItem.Quantity` | — |
| Refund amount calculation | `item.UnitPrice * Quantity - RestockingFee` | `processReturnRefund` | ⚠️ No tax / shipping cost refund logic | Partial refunds missing granularity |
| Refund processed state | Payment service (`ProcessRefund` response) | `RefundID` + `RefundProcessedAt` | ⚠️ No idempotency key | RET-P1-02: double-refund risk on retry |
| Restock quantity | Return item `Quantity` if `Restockable=true` | `restockReturnedItems` | ⚠️ WarehouseID defaults to `"default"` | Wrong warehouse if metadata missing |
| Shipping label | Shipping service `CreateReturnShipment` | `generateReturnShippingLabel` | ⚠️ Origin/destination addresses not passed | RET-P1-03: empty label data |
| Order status after return | Order service (must update to RETURN_REQUESTED) | Return service (gRPC call?) | ❌ **NOT FOUND** — No order status update call in return biz | Order remains in wrong status |
| Stock update after restock | Warehouse service `RestockItem` | `restockReturnedItems` | ✅ Retry via outbox on failure | — |
| Event publishing after status changes | `eventPublisher.Publish*` | All consumers | ⚠️ **Direct publish, not outbox** | Events lost on crash/Dapr failure |

---

## 2. Data Mismatches Found

### 2.1 Order Status NOT Updated After Return Approved (P0 — New)

**Status**: ❌ **Not Implemented**

In `UpdateReturnRequestStatus`, when status → `"approved"` or `"completed"`, there is no call to the Order service to update the order status to `RETURN_REQUESTED` or `RETURNED`. The order service independently needs to:
1. Mark order as `RETURN_REQUESTED` when return is approved
2. Mark order as `RETURNED`/`REFUNDED` when return is completed

Without this:
- Customer sees order as `COMPLETED` even after return is approved
- Fulfillment/seller sees wrong state → may attempt re-shipment
- Loyalty points earned on "completed" order are not reversed on return completion

**Fix**: Add `orderService.UpdateOrderStatus(ctx, orderID, "RETURN_REQUESTED")` call inside `UpdateReturnRequestStatus` → `"approved"` case

---

### 2.2 Refund Amount Missing Tax and Shipping Component

`processReturnRefund` refunds only `item.UnitPrice * quantity - RestockingFee`. This misses:
- Pro-rated **shipping fee refund** (for single-item order with defective item, Shopify refunds shipping too)
- **Tax refund** on the returned items (required by law in some jurisdictions)

*Shopee/Lazada pattern*: Refund = `(item_subtotal + proportional_shipping_portion + item_tax) - restocking_fee`

---

### 2.3 Restock Warehouse ID Defaults to `"default"` (RET-P1-03 related)

`restock.go:47`: `warehouseID := "default"` — if item metadata doesn't have `warehouse_id`, items restock to the "default" warehouse regardless of origin. Multi-warehouse setups may send stock to the wrong location.

*Lazada pattern*: Return → item restocked to the originating warehouse stored in the original order item record.

---

## 3. Event Publishing Audit

### 3.1 Events Published by Return Service

| Event | Method | Via | Critical? | Status |
|-------|--------|-----|-----------|--------|
| `return.requested` | `PublishReturnRequested` | Direct Dapr (not outbox) | ✅ Informational | ⚠️ No durability |
| `return.approved` | `PublishReturnApproved` | Direct Dapr | ✅ Triggers notification | ⚠️ No durability |
| `return.rejected` | `PublishReturnRejected` | Direct Dapr | ✅ Informational | ⚠️ No durability |
| `return.completed` | `PublishReturnCompleted` | Direct Dapr | ✅ Triggers loyalty/points reversal | ⚠️ No durability |
| `exchange.requested` | `PublishExchangeRequested` | Direct Dapr | Triggers new order creation | ⚠️ No durability |
| `exchange.approved` | (in exchange.go) | Direct Dapr | — | ⚠️ |
| `exchange.completed` | (in exchange.go) | Direct Dapr | — | ⚠️ |
| `return.refund_retry` | Outbox `outboxRepo.Save` | ✅ Outbox | Compensation retry | ✅ |
| `return.restock_retry` | Outbox `outboxRepo.Save` | ✅ Outbox | Compensation retry | ✅ |

**Critical Gap**: All primary state-change events (`return.requested`, `return.approved`, `return.rejected`, `return.completed`, all exchange events) are published via **direct Dapr call** — no outbox pattern. If the return service crashes after updating DB status but before publishing, all downstream consumers (notification, order, loyalty) miss the event permanently.

The outbox repository is injected but is only used for **compensation retry events** (refund/restock failures). The primary lifecycle events bypass it entirely.

---

### 3.2 Events Consumed by Return Service

| Service | Event Consumed | Verdict |
|---------|---------------|---------|
| Return service | ❌ **NO events consumed** | ✅ Return service has no Dapr subscriber dir |

**Conclusion**: Return service is **purely request-driven** (REST/gRPC) — it does not subscribe to any events. This is correct. The Order service or Admin triggers status transitions via gRPC.

---

### 3.3 Events That Other Services Should Subscribe To

| Event Published By Return | Should be consumed by | Consumption method | Status |
|---------------------------|-----------------------|--------------------|--------|
| `return.requested` | Notification service (send approval pending email) | Dapr subscribe | ✅ Documented in ecommerce-platform-flows.md 11.2 |
| `return.approved` | Notification service (send label to customer) | Dapr subscribe | ✅ |
| `return.rejected` | Notification service (send rejection reason) | Dapr subscribe | ✅ |
| `return.completed` | Notification service (refund confirmation) | Dapr subscribe | ✅ |
| `return.completed` | Customer/Loyalty service (reverse loyalty points earned on order) | Dapr subscribe | ⚠️ Not verified if loyalty reversal exists |
| `return.completed` | Order service (update order status to RETURNED) | ❌ Should be synchronous gRPC, not event | ❌ Not implemented — see 2.1 |
| `exchange.requested` | Order service (create exchange order) | Dapr subscribe or gRPC | ⚠️ `processExchangeOrder` exists but unclear if complete |

---

## 4. Outbox / Saga / Retry Implementation Audit

### 4.1 Outbox Worker

```go
// return/internal/worker/outbox_worker.go
func NewOutboxWorker(...) *outbox.Worker {
    return outbox.NewWorker("return", repo, publisher, logger, outbox.WithBatchSize(50))
}
```

Uses `common/outbox.Worker` — shared implementation. Batch size 50.

| Check | Status |
|-------|--------|
| Outbox worker exists and uses common library | ✅ |
| Refund failure saved to outbox (`return.refund_retry`) | ✅ `refund.go:78-88` |
| Restock failure saved to outbox (`return.restock_retry`) | ✅ `restock.go:76-87` |
| **Consumer for `return.refund_retry`** | ❌ **Missing** — outbox publishes the event but there is no worker/consumer within return service that processes `return.refund_retry` events |
| **Consumer for `return.restock_retry`** | ❌ **Missing** — same gap |
| Primary lifecycle events via outbox | ❌ All published via direct `eventPublisher.Publish*` |

**Critical**: `return.refund_retry` and `return.restock_retry` events are saved to the outbox table, but if there is no consumer listening to those topics, they are published to Dapr pub/sub and lost — since no service subscribes to those topics.

---

### 4.2 Status Machine Coverage (RET-P1-01 — Open)

Current statuses: `pending → approved → processing → completed` (or `rejected`)

Missing intermediate statuses for failure handling:

| Should Exist | Current State | Risk |
|-------------|--------------|------|
| `pending_refund` (after inspection passed, awaiting payment service) | `completed` | Refund failure invisible |
| `refund_failed` (payment service error) | `completed` (log error only) | Customer not refunded but sees completed |
| `pending_restock` | `completed` | Inventory not updated but status says complete |
| `restock_failed` | `completed` | Phantom inventory |
| `dispute` / `escalated` | Not implemented | Section 10.5 of flows doc |

*Shopify pattern*: Returns have `RETURN_REQUESTED → IN_TRANSIT → RECEIVED → INSPECTION → REFUND_PROCESSING → REFUNDED`

---

## 5. Retry & Rollback Edge Cases

### 🔴 P0 — Critical

| Issue | Description | File | Fix |
|-------|-------------|------|-----|
| **RET-P0-001** | All primary lifecycle events (`return.requested/approved/rejected/completed`, all exchange events) published via **direct Dapr, not outbox**. If service crashes post-DB-write, events are permanently lost. Notification/loyalty/order services miss the signal. | `return.go:251,357,363,358,389` | Write all state-change events to outbox INSIDE the status-update transaction |
| **RET-P0-002** | `return.refund_retry` and `return.restock_retry` events are saved to outbox and re-published via Dapr, but **no service subscribes to these topics**. The outbox worker publishes them to nowhere. Retry never actually retries. | `refund.go:81`, `restock.go:79-80` | Either: (A) add a Dapr consumer in return service for these retry topics that calls `processReturnRefund` / `restockReturnedItems` again; OR (B) use a cron worker that queries outbox directly |
| **RET-P0-003** | Order status is not updated when return is approved or completed. Order service still shows original status (`COMPLETED`) after customer return is processed. | `return.go:346-399` | Call `orderService.UpdateOrderStatus` at `approved` → `RETURN_REQUESTED` and at `completed` → `RETURNED` |

### 🟡 P1 — High Priority (Confirmed Open from Active Issues)

| Issue | Description | File | Fix |
|-------|-------------|------|-----|
| **RET-P1-01** | No granular failure statuses — refund/restock failure causes completed status with silent error. Customer not refunded, system says completed. | `return.go:367-389` | Add `pending_refund`, `refund_failed`, `pending_restock`, `restock_failed` statuses |
| **RET-P1-02** | `ProcessRefund` called with NO idempotency key. On retry via outbox `return.refund_retry`, payment service may process duplicate refund. | `refund.go:59` | Generate idempotency key from `ReturnRequest.ID + attempt_count`; pass to `PaymentService.ProcessRefund` |
| **RET-P1-03** | `generateReturnShippingLabel` passes empty `Origin` and `Destination` to `ShippingService.CreateReturnShipment`. Carrier creates invalid label (or silently fails). | `shipping.go:19-24` | Fetch customer address from Order or Customer service; fetch warehouse address from Warehouse service; pass both to label request |
| **RET-P1-04** | `restockReturnedItems` uses `warehouseID := "default"` fallback. In multi-warehouse setups, items return to wrong location. | `restock.go:47` | Store originating `warehouseID` on order item at order creation; propagate to return item; use as restock destination |

### 🔵 P2 — Logic Gaps

| Issue | Description | Fix |
|-------|-------------|-----|
| **RET-P2-01** | Refund does not include proportional shipping refund or tax refund on returned items | Add `ShippingRefund` + `TaxRefund` components to refund amount calculation |
| **RET-P2-02** | `CheckReturnEligibility` allows ALL items to return regardless of category policy (hygiene, digital goods, final sale) — `anyEligible = true` always | Add `isReturnExcluded(productCategory)` check per item using Catalog service |
| **RET-P2-03** | Exchange items in `buildExchangeRequestedEvent` have `UnitPrice: 0` and `ProductName: ""` — downstream exchange order creation gets incomplete data | Fetch catalog/pricing details before emitting exchange event |
| **RET-P2-04** | No return reason code validation against allowed list at API layer — validation.go does validate but `"other"` is catch-all | Add structured reason codes for analytics; reject unknown codes |
| **RET-P2-05** | No maximum refund amount cap — a bug or malicious admin could approve a refund larger than the original order amount | Add `refundAmount <= order.TotalAmount` guard in `processReturnRefund` |
| **RET-P2-06** | Return window is hardcoded to 30 days (`ReturnWindowDays: 30` in return.go:147) — different product categories should have different windows (e.g., 7 days for electronics, 30 for apparel) | Read return policy from Catalog product category or configurable settings per product |
| **RET-P2-07** | No return item photo/evidence upload mechanism in return creation despite being listed in ecommerce-platform-flows.md section 10.1 | Add `EvidenceURLs []string` field to `CreateReturnItemRequest`; store in return item model |
| **RET-P2-08** | `ReceiveReturnItems` ignores the `inspectionResults` parameter entirely — condition/restockable status is not applied to items | Use `inspectionResults` to update `item.Condition` and `item.Restockable` on each `ReturnItem` |

---

## 6. Business Logic Edge Cases (Shopify/Shopee/Lazada Patterns)

### 6.1 Return Request Flow Gaps

- [ ] **Partial quantity return not tracked at item level**: If customer returns 2 of 5 ordered units, only the quantity requested is stored. But there is no check if a second return request for the **remaining 3 units** is blocked. Two separate return requests could independently return more than the total ordered.
  - *Fix*: Track `already_returned_qty` per order item; enforce `orderItem.Quantity - alreadyReturned >= returnQty`.

- [ ] **Return window uses `CompletedAt` (delivery confirmed) but COD orders may never set `CompletedAt`**: COD orders where payment is collected on delivery may not update `CompletedAt` until seller manually confirms receipt. Customer can't return within window.
  - *Fix*: For COD, use `UpdatedAt` where `Status = delivered` as `CompletedAt` equivalent.

- [ ] **No seller approval flow — all returns auto-approved**: `UpdateReturnRequestStatus` `"approved"` case can be called directly by any admin. Neither seller nor buyer dispute escalation path is implemented.
  - *Shopee pattern*: Seller has 2 business days to approve/reject; platform auto-approves after timeout.
  - *Fix*: Add `seller_action_deadline` + `auto_approve_at` scheduler.

- [ ] **Exchange return creates a new order but does NOT check stock for exchange item**: `processExchangeOrder` (exchange.go) should verify the replacement SKU is in stock before confirming the exchange. Currently exchange items have `UnitPrice: 0` and no stock check.

- [ ] **No dispute escalation flow**: `ecommerce-platform-flows.md` section 10.5 documents buyer escalation → mediation → resolution. Not implemented. No `escalated`, `in_mediation`, `dispute_resolved` statuses.

- [ ] **Loyalty points reversal**: When a return is completed, loyalty points earned on the original purchase should be reversed. There's no call to a loyalty/customer service in `UpdateReturnRequestStatus` → `"completed"` case.
  - *Shopee/Lazada pattern*: On `return.completed` event, Loyalty service deducts the earned points.

- [ ] **Chargeback handling (section 10.5)**: No chargeback detection or handling flow. If a customer files a card network dispute (chargeback), there is no mechanism to link it to a return request or update order/payment status accordingly.

### 6.2 Refund Flow Gaps

- [ ] **No refund method selection**: Refund always goes back to original payment method. Some platforms offer faster refund to store credit/wallet at customer's choice (section 10.4: "Refund to store credit/points (faster option)").
  - *Fix*: Add `RefundMethod` enum (original, store_credit) to `CreateReturnRequestRequest`.

- [ ] **Multiple payment methods (split payment) not handled**: If original order was paid with card + loyalty points (split), the refund only processes one payment ID. The loyalty points portion is not separately refunded.
  - *Fix*: Return service needs order payment breakdown; process separate refunds per payment method.

- [ ] **Refund timeline transparency**: ecommerce-platform-flows.md 10.4 lists "5-7 days for card refund". No estimated refund date is stored or surfaced in API response after `processReturnRefund`.

---

## 7. GitOps Configuration Review

### 7.1 Return Service

| Check | File | Status |
|-------|------|--------|
| Dapr enabled, app-id `return`, port 8013, HTTP | `gitops/apps/return/base/deployment.yaml:25–28` | ✅ |
| secretRef: `return-secrets` | `deployment.yaml:55–56` | ✅ |
| envFrom: `overlays-config` | `deployment.yaml:52–54` | ✅ |
| startupProbe (failureThreshold=10, period=3s) | `deployment.yaml:64–69` | ✅ |
| livenessProbe (delay=30s, period=10s) | `deployment.yaml:70–75` | ✅ |
| readinessProbe (delay=5s, period=5s) | `deployment.yaml:76–81` | ✅ |
| securityContext non-root (runAsUser=65532) | `deployment.yaml:30–33` | ✅ |
| revisionHistoryLimit: 1 | `deployment.yaml:13` | ✅ |
| **config volumeMount** (`/app/configs/config.yaml`) | `deployment.yaml` | ❌ **MISSING** — binary reads `-conf /app/configs/config.yaml` but no volume mounted |
| **worker-deployment.yaml** | `gitops/apps/return/base/` | ❌ **MISSING** — outbox worker runs embedded in main `return` binary; no separate worker deployment |

### 7.2 Return Service vs. Order Service (Which Owns Returns?)

The `return_refund_issues.md` references `order/internal/biz/return/return.go`, but the actual implementation is in `return/internal/biz/return/`. The **Return service is a dedicated microservice** (port 8013, separate binary) that handles all return logic. The Order service should call the Return service's gRPC API for return-related operations — this boundary appears correct.

---

## 8. Workers & Cron Jobs Audit

### 8.1 Return Service Workers

| Worker | Type | Implementation | Status |
|--------|------|---------------|--------|
| `checkout-outbox-worker` → `return-outbox-worker` | Continuous | `common/outbox.Worker`, batch=50 | ✅ Using shared implementation |
| Cart cleanup / session cleanup | ❌ None | N/A | ✅ Return service has no carts |
| Failed compensation worker | ❌ **NOT PRESENT** | N/A | ⚠️ Compensation for refund/restock failures goes to outbox but no retry consumer |

**Critical Gap**: Unlike checkout service which has `FailedCompensationWorker` polling every 5 minutes to retry failures, the return service has **no compensation retry worker**. Refund and restock failures are saved as `return.refund_retry` / `return.restock_retry` outbox events, but:

1. These are published to Dapr topics via outbox worker
2. No service subscribes to these Dapr topics
3. The retry never actually retries — events simply disappear into an unsubscribed Dapr topic

---

## 9. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix

| Issue | Description | Action |
|-------|-------------|--------|
| **RET-P0-001** | All primary lifecycle events use direct Dapr publish — not outbox. Crash between DB write and Dapr publish loses event permanently | Write all state-change events to outbox inside the status update transaction |
| **RET-P0-002** | `return.refund_retry` and `return.restock_retry` outbox events are published to Dapr but **nobody subscribes** — retry events go nowhere | Create Dapr consumer subscriptions for retry topics, OR replace with in-process compensation cron worker |
| **RET-P0-003** | Order status is never updated when return is approved/completed — order remains in incorrect state indefinitely | Add `orderService.UpdateOrderStatus` calls at `approved` and `completed` transitions |

### 🟡 P1 — Next Sprint (Confirmed Open)

| Issue | Description | Action |
|-------|-------------|--------|
| **RET-P1-01** | No granular failure statuses — `completed` hides refund/restock failures | Add `refund_failed`, `restock_failed` statuses; update state machine |
| **RET-P1-02** | `ProcessRefund` has no idempotency key — duplicate refund risk on retry | Pass `idempotency_key = returnID + ":refund"` to payment service |
| **RET-P1-03** | Return shipping label has empty origin/destination — creates invalid labels | Fetch customer address from Order service; warehouse address from Warehouse service |
| **RET-P1-04** | Restock uses `"default"` warehouseID — wrong warehouse in multi-warehouse setup | Store originating warehouseID on order item; use in return restock |
| **RET-P1-05** | No compensation retry worker — failed refunds/restocks are lost after retry topic is unsubscribed | Implement `ReturnCompensationWorker` (cron, 5-min poll on failed outbox events) |

### 🔵 P2 — Roadmap

| Issue | Description | Action |
|-------|-------------|--------|
| **RET-P2-01** | Refund doesn't include shipping/tax refund component | Add proportional shipping + tax to refund amount |
| **RET-P2-02** | All items eligible regardless of category — no category-excluded-return policy | Add per-category return eligibility using Catalog service |
| **RET-P2-03** | Exchange items have `UnitPrice: 0`, `ProductName: ""` in event | Fetch pricing + catalog details before emitting exchange event |
| **RET-P2-04** | No max refund cap | Add `refundAmount <= order.TotalAmount` guard |
| **RET-P2-05** | Return window hardcoded 30 days — no per-category policy | Add configurable `ReturnWindowDays` per product category |
| **RET-P2-06** | Evidence upload (photo/video) not implemented | Add `EvidenceURLs []string` to return item |
| **RET-P2-07** | `ReceiveReturnItems` ignores `inspectionResults` parameter | Apply inspection results to update `item.Condition` and `item.Restockable` |
| **RET-P2-08** | Loyalty points not reversed on return completion | Subscribe `return.completed` in loyalty/customer service to deduct points |
| **EDGE-01** | Partial quantity return: second return req can re-return already-returned items | Track `already_returned_qty` per order item; enforce guard |
| **EDGE-02** | No seller approval flow — all returns go straight to approved | Add seller approval step with deadline + auto-approve |
| **EDGE-03** | No dispute escalation (section 10.5) | Implement `escalated`, `in_mediation` statuses + admin mediation flow |
| **EDGE-04** | No split payment refund | Handle multiple payment methods per order in refund calculation |
| **EDGE-05** | Exchange doesn't check stock for replacement item | Add stock check via Warehouse before confirming exchange |

---

## 10. What Is Already Correctly Implemented ✅

| Area | Evidence |
|------|----------|
| Return eligibility: 30-day window from CompletedAt | `return.go:476-484` — fail-safe on nil CompletedAt |
| Return deduplication: concurrent creation handled | `return.go:116-120` + unique constraint `idx_returns_order_active_unique` |
| Return quantity validation vs. ordered quantity | `return.go:192-195` |
| Exchange restock bypass (avoids double-inventory) | `restock.go:22-26` — `[E-23]` skip for exchange type |
| Refund failure → outbox retry event | `refund.go:63-91` — `return.refund_retry` outbox event |
| Restock failure → outbox retry event | `restock.go:62-91` — `return.restock_retry` outbox event |
| Return type defaulting (`return` if empty) | `return.go:135-138` |
| Order item data fetched from Order service | `return.go:123-130` — real product data used, not stale |
| Return-window uses delivery date (not update date) | `return.go:473-484` |
| Return item restockable filter | `restock.go:39-44` — non-restockable items skipped |
| Common outbox.Worker used | `outbox_worker.go:10` — consistent with project patterns |
| Dapr app-id distinct from other services | `deployment.yaml:26` — `return`, port 8013 |
| secretRef, startup/liveness/readiness probes | `deployment.yaml:55,64-81` — all present |
| Security context non-root | `deployment.yaml:30-33` |

---

## Related Files

| Document | Path |
|----------|------|
| Active open issues | [return_refund_issues.md](../active/return_refund_issues.md) |
| Cart & Checkout flow checklist | [cart-checkout-flow-checklist.md](cart-checkout-flow-checklist.md) |
| Catalog & Product flow checklist | [catalog-product-flow-checklist.md](catalog-product-flow-checklist.md) |
| Customer & Identity flow checklist | [customer-identity-flow-checklist.md](customer-identity-flow-checklist.md) |
| eCommerce platform flows reference | [ecommerce-platform-flows.md](../../ecommerce-platform-flows.md) |

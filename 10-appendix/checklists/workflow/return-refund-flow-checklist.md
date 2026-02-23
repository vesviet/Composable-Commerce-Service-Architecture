# Return & Refund Flow — Business Logic Review Checklist

**Date**: 2026-02-23 (Updated)
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
| Refund processed state | Payment service (`ProcessRefund` response) | `RefundID` + `RefundProcessedAt` | ✅ Idempotency key `returnID + ":refund"` passed | RET-P1-02 Fixed |
| Restock quantity | Return item `Quantity` if `Restockable=true` | `restockReturnedItems` | ✅ **Fixed** — `warehouse_id` stored in `ReturnItem.Metadata` at creation time from order item proto field `WarehouseId`; restock routes to correct warehouse | RET-P1-04 Fixed |
| Shipping label | Shipping service `CreateReturnShipment` | `generateReturnShippingLabel` | ✅ **Fixed** — `GetOrder` now maps `ShippingAddress` to `OrderInfo.ShippingAddress`; used as Origin; warehouse address from `config.business.warehouse_return_address` used as Destination | RET-P1-03 Fixed |
| Order status after return | Order service (must update to RETURN_REQUESTED) | Return service gRPC call | ✅ **Fixed** — `orderService.UpdateOrderStatus` called in `UpdateReturnRequestStatus` at `approved` and `completed` transitions | `return.go:379-382, 437-443` |
| Stock update after restock | Warehouse service `RestockItem` | `restockReturnedItems` | ✅ Retry via outbox on failure | — |
| Event publishing after status changes | `outboxRepo.Save` inside status-update TX | All consumers | ✅ **Fixed** — All lifecycle events (`return.requested/approved/rejected/completed`, all exchange events) now saved to outbox inside the DB transaction | `return.go:248-268, 357-392, 444-452` |

---

## 2. Data Mismatches Found

### ~~2.1 Order Status NOT Updated After Return Approved (P0 — New)~~

**Status**: ✅ **Fixed** (RET-P0-003)

~~In `UpdateReturnRequestStatus`, when status → `"approved"` or `"completed"`, there is no call to the Order service to update the order status.~~

`orderService.UpdateOrderStatus` is now called in:
- `approved` case → `return_requested` (`return.go:398-401`)
- `completed` case → `returned` (`return.go:458-461`)

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
| `return.requested` | `outboxRepo.Save` inside TX | ✅ Outbox (P0-NEW-01 fixed) | ✅ Informational | ✅ Durable |
| `return.approved` | `outboxRepo.Save` inside TX | ✅ Outbox | ✅ Triggers notification | ✅ Durable |
| `return.rejected` | `outboxRepo.Save` inside TX | ✅ Outbox | ✅ Informational | ✅ Durable |
| `return.completed` | `outboxRepo.Save` inside TX | ✅ Outbox | ✅ Triggers loyalty/points reversal | ✅ Durable |
| `exchange.requested` | `outboxRepo.Save` inside TX | ✅ Outbox (via CreateReturnRequest) | Triggers new order creation | ✅ Durable |
| `exchange.order_created` | `outboxRepo.Save` with fallback | ✅ Outbox (P1-NEW-05 fixed) | Exchange order tracking | ✅ Durable |
| `return.refund_retry` | Outbox `outboxRepo.Save` | ✅ Outbox | Compensation retry | ✅ |
| `return.restock_retry` | Outbox `outboxRepo.Save` | ✅ Outbox | Compensation retry | ✅ |

~~**Critical Gap**: All primary state-change events published via direct Dapr call — no outbox pattern.~~

✅ **Resolved**: All lifecycle events now go through the outbox pattern. Direct publish is only used as a last-resort fallback when the outbox save + TX fails.

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
|----------|--------|
| Outbox worker exists and uses common library | ✅ |
| Refund failure saved to outbox (`return.refund_retry`) | ✅ `refund.go:78-88` |
| Restock failure saved to outbox (`return.restock_retry`) | ✅ `restock.go:76-87` |
| **Consumer for `return.refund_retry`** | ✅ **Fixed** — `ReturnCompensationWorker` processes `return.refund_retry` outbox events directly; wired as Kratos `WorkerServer` in `wire_gen.go` |
| **Consumer for `return.restock_retry`** | ✅ **Fixed** — `ReturnCompensationWorker` processes `return.restock_retry` events; started via `WorkerServer` |
| Primary lifecycle events via outbox | ✅ **Fixed** — All state-change events written to outbox inside the status-update transaction; outbox worker publishes them to Dapr |
| **Return status updated after successful compensation retry** | ✅ **Fixed (P1-NEW-01)** — Worker updates return status from `refund_failed`/`restock_failed` → `completed` after successful retry |

**Both workers (`outboxWorker` and `compensationWorker`) are now started via `WorkerServer` registered as a Kratos transport in `wire_gen.go`.**

---

### 4.2 Status Machine Coverage (RET-P1-01 — Partially Fixed)

Current statuses: `pending → approved → processing → completed` (or `rejected`, `refund_failed`, `restock_failed`)

| Status | State | Fixed? |
|--------|-------|--------|
| `refund_failed` (payment service error) | ✅ Set in `return.go:438`; in state machine (`validation.go`) | ✅ P0-NEW-02 Fixed |
| `restock_failed` (warehouse service error) | ✅ Set in `return.go:453`; in state machine (`validation.go`) | ✅ P0-NEW-02 Fixed |
| `pending_refund` (awaiting payment service) | Not implemented | Still open (P1) |
| `pending_restock` (awaiting warehouse service) | Not implemented | Still open (P1) |
| `dispute` / `escalated` | Not implemented | Still open (EDGE-03) |

*Shopify pattern*: Returns have `RETURN_REQUESTED → IN_TRANSIT → RECEIVED → INSPECTION → REFUND_PROCESSING → REFUNDED`

---

## 5. Retry & Rollback Edge Cases

### 🔴 P0 — Critical

| Issue | Description | File | Fix |
|-------|-------------|------|-----|
| ~~**RET-P0-001**~~ | ~~All primary lifecycle events (`return.requested/approved/rejected/completed`, all exchange events) published via **direct Dapr, not outbox**~~. | ~~`return.go:251,357,363,358,389`~~ | ✅ **Fixed** — All state-change events written to outbox inside status-update TX (`return.go:248-268, 357-392, 444-452`) |
| ~~**RET-P0-002**~~ | ~~`return.refund_retry` and `return.restock_retry` events published to Dapr but no service subscribes. Retry never retries.~~ | ~~`refund.go:81`, `restock.go:79-80`~~ | ✅ **Fixed** — `ReturnCompensationWorker` implemented (`internal/worker/compensation_worker.go`) and wired as `WorkerServer` in `wire_gen.go`; polls outbox directly for retry events |
| ~~**RET-P0-003**~~ | ~~Order status not updated when return is approved/completed. Order remains in incorrect state.~~ | ~~`return.go:346-399`~~ | ✅ **Fixed** — `orderService.UpdateOrderStatus` called at `approved` (→ `RETURN_REQUESTED`) and `completed` (→ `RETURNED`) transitions |

### 🟡 P1 — High Priority (Confirmed Open from Active Issues)

| Issue | Description | File | Fix |
|-------|-------------|------|-----|
| **RET-P1-01** | No granular failure statuses — refund/restock failure causes completed status with silent error. Customer not refunded, system says completed. | `return.go:367-389` | Add `pending_refund`, `refund_failed`, `pending_restock`, `restock_failed` statuses |
| ~~**RET-P1-02**~~ | ~~`ProcessRefund` called with NO idempotency key. On retry, payment service may process duplicate refund.~~ | ~~`refund.go:59`~~ | ✅ **Fixed** — Idempotency key `returnID + ":refund"` generated in `refund.go:54`; passed to `PaymentService.ProcessRefund` |
| ~~**RET-P1-03**~~ | ~~`generateReturnShippingLabel` passes empty `Origin` and `Destination` to `ShippingService.CreateReturnShipment`. Carrier creates invalid label (or silently fails).~~ | ~~`shipping.go:19-24`~~ | ✅ **Fixed** — `GetOrder` maps `ShippingAddress → OrderInfo.ShippingAddress` (Origin); Destination = `config.business.warehouse_return_address`; items list included |
| ~~**RET-P1-04**~~ | ~~`restockReturnedItems` uses `warehouseID := "default"` fallback. In multi-warehouse setups, items return to wrong location.~~ | ~~`restock.go:47`~~ | ✅ **Fixed** — `OrderItemInfo.WarehouseID` mapped from proto `item.WarehouseId`; stored in `ReturnItem.Metadata["warehouse_id"]` at `CreateReturnRequest`; `restock.go:48-52` reads it at restock time |
| ~~**RET-P1-05**~~ | ~~No compensation retry worker — failed refunds/restocks are lost~~ | | ✅ **Fixed** — `ReturnCompensationWorker` implemented + wired into `wire_gen.go` |

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
| **config volumeMount** (`/app/configs/config.yaml`) | `deployment.yaml` | ✅ **Fixed (P0-NEW-03)** — `volumeMount` + `volume` added pointing to `return-config` ConfigMap |
| **worker-deployment.yaml** | `gitops/apps/return/base/` | ℹ️ **By Design** — Workers (outbox + compensation) run embedded in main `return` binary via `WorkerServer`; no separate deployment needed |

### 7.2 Return Service vs. Order Service (Which Owns Returns?)

The `return_refund_issues.md` references `order/internal/biz/return/return.go`, but the actual implementation is in `return/internal/biz/return/`. The **Return service is a dedicated microservice** (port 8013, separate binary) that handles all return logic. The Order service should call the Return service's gRPC API for return-related operations — this boundary appears correct.

---

## 8. Workers & Cron Jobs Audit

### 8.1 Return Service Workers

| Worker | Type | Implementation | Status |
|--------|------|---------------|--------|
| `return-outbox-worker` | Continuous | `common/outbox.Worker`, batch=50 | ✅ Wired via `WorkerServer` in `wire_gen.go` |
| Cart cleanup / session cleanup | ❌ None | N/A | ✅ Return service has no carts |
| `ReturnCompensationWorker` | Periodic (5min poll) | `internal/worker/compensation_worker.go` | ✅ **Fixed** — Processes `return.refund_retry` and `return.restock_retry` outbox events; updates return request status after successful retry (P1-NEW-01) |

**Both workers are now registered as a Kratos `transport.Server` (`WorkerServer`) and start/stop with the main app lifecycle.**

~~**Critical Gap**: The return service had no compensation retry worker. Refund and restock failures were saved as outbox events but never retried.~~

✅ **Resolved**: `ReturnCompensationWorker` polls outbox every 5 minutes for `return.refund_retry` / `return.restock_retry` events and retries the operation. After successful retry, updates the return request status from `refund_failed`/`restock_failed` back to `completed`.

---

## 9. Summary: Issue Priority Matrix

### 🔴 P0 — Must Fix

| Issue | Description | Action |
|-------|-------------|--------|
| ~~**RET-P0-001**~~ | ~~All primary lifecycle events use direct Dapr publish — not outbox~~ | ✅ **Fixed** — All events written to outbox inside TX |
| ~~**RET-P0-002**~~ | ~~`return.refund_retry` / `return.restock_retry` outbox events published to Dapr but nobody subscribes~~ | ✅ **Fixed** — `ReturnCompensationWorker` polls outbox directly; wired via `WorkerServer` |
| ~~**RET-P0-003**~~ | ~~Order status never updated when return is approved/completed~~ | ✅ **Fixed** — `orderService.UpdateOrderStatus` called in both transitions |
| ~~**P0-NEW-01**~~ | ~~`CreateReturnRequest` outbox save was outside the DB transaction — event could be lost on crash~~ | ✅ **Fixed** — Outbox save moved inside `tm.WithTransaction` block |
| ~~**P0-NEW-02**~~ | ~~`refund_failed`/`restock_failed` not in state machine — statuses set but unreachable/stuck~~ | ✅ **Fixed** — Added to `validTransitions` map; compensation worker updates status after retry |
| ~~**P0-NEW-03**~~ | ~~Config volume not mounted in K8s deployment — pod crash-loops~~ | ✅ **Fixed** — `volumeMount` + `volume` added to `deployment.yaml` |

### 🟡 P1 — Next Sprint

| Issue | Description | Action |
|-------|-------------|--------|
| **RET-P1-01** | No granular intermediate statuses (`pending_refund`, `pending_restock`) | Partially fixed: `refund_failed`/`restock_failed` added. Full intermediate states for next sprint |
| ~~**RET-P1-02**~~ | ~~`ProcessRefund` has no idempotency key~~ | ✅ **Fixed**: `idempotency_key = returnID + ":refund"` in `refund.go:54` |
| ~~**RET-P1-03**~~ | ~~Return shipping label has empty origin/destination~~ | ✅ **Fixed**: `shipping.go` uses `order.ShippingAddress` (Origin) + `config.warehouse_return_address` (Destination) |
| ~~**RET-P1-04**~~ | ~~Restock uses `"default"` warehouseID~~ | ✅ **Fixed**: `order_client.go` maps `item.WarehouseId` → `ReturnItem.Metadata["warehouse_id"]` |
| ~~**RET-P1-05**~~ | ~~No compensation retry worker~~ | ✅ **Fixed**: `ReturnCompensationWorker` implemented and wired |
| ~~**P1-NEW-01**~~ | ~~Compensation worker doesn't update return request status after successful retry~~ | ✅ **Fixed**: Worker now updates status from `refund_failed`/`restock_failed` → `completed` |
| ~~**P1-NEW-03**~~ | ~~`validateReturnWindow` vs `CheckReturnEligibility` logic mismatch~~ | ✅ **Fixed**: Both now deny when `CompletedAt` is nil (fail-safe) |
| ~~**P1-NEW-05**~~ | ~~Exchange order created event published directly instead of via outbox~~ | ✅ **Fixed**: Now routes through outbox with direct-publish fallback |

### 🔵 P2 — Roadmap

| Issue | Description | Action |
|-------|-------------|--------|
| **RET-P2-01** | Refund doesn't include shipping/tax refund component | Add proportional shipping + tax to refund amount |
| **RET-P2-02** | All items eligible regardless of category — no category-excluded-return policy | Add per-category return eligibility using Catalog service |
| **RET-P2-03** | Exchange items have `ProductName: ""` in ExchangeRequestedEvent | Fetch pricing + catalog details before emitting exchange event |
| ~~**RET-P2-04**~~ | ~~No max refund cap~~ | ✅ **Fixed**: `refundAmount <= order.TotalAmount` guard in `refund.go:43-47` |
| **RET-P2-05** | Return window hardcoded 30 days — no per-category policy | Add configurable `ReturnWindowDays` per product category |
| **RET-P2-06** | Evidence upload (photo/video) not implemented | Add `EvidenceURLs []string` to return item |
| ~~**RET-P2-07**~~ | ~~`ReceiveReturnItems` ignores `inspectionResults` parameter~~ | ✅ **Fixed**: Inspection results applied to `item.Condition` and `item.Restockable` |
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

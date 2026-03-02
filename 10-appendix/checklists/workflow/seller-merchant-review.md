# Seller / Merchant Flow — Business Logic Review Checklist

**Last Updated**: 2026-02-24 (P0/P1 fixes applied)
**Scope**: Section 12 — Seller / Merchant Flows (`ecommerce-platform-flows.md`)
**Pattern Reference**: Shopify, Shopee, Lazada
**Services In Scope**: `catalog`, `warehouse`, `fulfillment`, `shipping`, `payment`, `order`, `pricing`, `promotion`, `notification`, `loyalty-rewards`

> **Changelog**:
> - 2026-02-24: Fixed P0-1 (order.completed consumer + MarkPaymentCompleted), P0-2 (outbox race condition), P1-1 (Dapr grpc/5005 on all workers). Wire regenerated, builds pass.

---

## 1. Flow Coverage Matrix

| Sub-Flow | Services Involved | Status |
|---|---|---|
| 12.1 Seller Onboarding | `auth`, `user`, `catalog` | ⚠️ Partial |
| 12.2 Seller Dashboard | `catalog`, `warehouse`, `order`, `payment`, `analytics` | ⚠️ Partial |
| 12.3 Seller Performance | `order`, `fulfillment`, `analytics` | ⚠️ Partial |
| 12.4 B2B / Wholesale | `catalog`, `pricing`, `order` | ❌ Not Implemented |

---

## 2. Data Consistency Review

### 2.1 Catalog ↔ Warehouse (Stock Sync)

- [x] **Stock sync via event**: `warehouse` publishes `stock.changed` → `catalog-worker` consumes via `ConsumeStockChanged`
- [x] **DLQ consumer**: `catalog-worker` has `ConsumeStockChangedDLQ` to drain failed stock events
- [x] **Cron fallback**: `catalog` has `StockSyncJob` cron as periodic reconciliation backup
- [ ] **RISK**: If `catalog-worker` is down when `stock.changed` fires, stock display in catalog may lag until DLQ is drained. No immediate alerting on DLQ depth
- [ ] **RISK**: `StockSyncJob` cron interval not confirmed — if too long (e.g., 1h), stock display may be stale for extended periods

### 2.2 Pricing ↔ Catalog (Price Sync)

- [x] **Price sync via event**: `pricing` publishes `price.updated` → `catalog-worker` consumes via `ConsumePriceUpdated` + `ConsumePriceBulkUpdated`
- [x] **Unified consumer**: Phase 2 consolidates product/warehouse/sku price scopes into one consumer
- [ ] **RISK**: Price change in `pricing` service doesn't trigger immediate cache invalidation in `catalog` service. A `MaterializedViewRefreshJob` cron handles view refresh but may be eventually consistent
- [ ] **RISK**: If `price.updated` event fails and falls to DLQ, catalog shows stale price while order service may calculate correct price → **price mismatch at checkout is possible**

### 2.3 Order ↔ Warehouse (Inventory Reservation)

- [x] **Reservation pattern**: Soft-reserve on order creation, confirm on payment, release on cancellation
- [ ] **RISK**: If `order` creates reservation in warehouse but payment fails AND the cancellation event is lost, stock remains soft-locked indefinitely. Needs `warehouse-worker` reservation cleanup cron to expire stale reservations
- [x] **Cleanup cron**: `warehouse-worker` has `reservation_cleanup_job.go` ✅

### 2.4 Fulfillment ↔ Order (Status Sync)

- [x] **Event-driven**: `fulfillment-worker` subscribes to `order.status.changed` via `ConsumeOrderStatusChanged`
- [x] **Picklist consumer**: `fulfillment-worker` subscribes to `picklist.status.changed` via `ConsumePicklistStatusChanged`
- [x] **Shipment delivered**: `fulfillment-worker` subscribes to `shipment.delivered` via `ConsumeShipmentDelivered`
- [ ] **RISK**: `fulfillment` has only 1 cron job (in `/internal/worker/cron/provider.go` which shows 1 item). No SLA breach cron confirmed — seller late-ship penalties may not be auto-calculated

### 2.5 Payment ↔ Order (Escrow / Payout)

- [x] **Payment cron jobs**: `auto_capture.go`, `bank_transfer_expiry.go`, `cleanup.go`, `failed_payment_retry.go`, `payment_reconciliation.go`, `payment_status_sync.go`, `refund_processing.go`, `webhook_retry.go`
- [x] **~~FIXED P0-1~~** `order.completed` consumer added to `payment-worker` → `OrderCompletedConsumer.HandleOrderCompleted` → `PaymentUsecase.MarkPaymentCompleted` transitions `captured → completed` and publishes `payment.status_changed`
- [ ] **RISK**: Commission deduction (P1-2) still missing before payout

### 2.6 Shipping ↔ Order (Tracking)

- [x] **Event consumer**: `shipping-worker` subscribes to `order.cancelled` and `package.status.changed`
- [ ] **RISK**: Carrier webhook → `shipping` service tracking events are not explicitly published back to `order` service via event. If `shipment.tracking_updated` event is missing, order status won't advance from `SHIPPED` to `IN_TRANSIT` / `OUT_FOR_DELIVERY`

---

## 3. Saga / Outbox / Retry — Implementation Review

### 3.1 Catalog — Outbox Pattern

- [x] **Outbox implemented**: `product-outbox-worker` polls `outbox` table every **100ms**, processes events in batches of 20
- [x] **Retry**: Max 5 retries with `PENDING` reset on failure; permanently failed → `FAILED` (DLQ)
- [x] **Stuck event recovery**: `ResetStuckProcessing` resets events stuck in `PROCESSING` > 5 minutes
- [x] **Tracing**: OTel spans per event with `event.id`, `event.type`, `aggregate.id`, `retry.count`
- [x] **Events published**: `product.created`, `product.updated`, `product.deleted`, `attribute.created`, `attribute.updated`
- [x] **~~FIXED P0-2~~**: Outbox now marks status `COMPLETED` immediately after `PublishEvent` succeeds. Internal side-effects (`ProcessProductCreated/Updated/Deleted`) run as best-effort after publish. Failures are logged/warned but don't cause re-publish (no more duplicates).

### 3.2 Warehouse — Outbox Pattern

- [x] **Outbox implemented**: `warehouse` has `outbox_worker.go`
- [x] **Cron jobs**: `alert_cleanup_job`, `capacity_monitor_job`, `daily_reset_job`, `daily_summary_job`, `outbox_cleanup_job`, `reservation_cleanup_job`, `stock_change_detector`, `timeslot_validator_job`, `weekly_report_job`
- [ ] **RISK**: `warehouse` provider shows only `NewImportWorker`, `NewOutboxWorker`, `cron.ProviderSet` — **no event consumer registered**. If `warehouse` needs to react to external events (e.g., `order.paid` to confirm reservation), this must be verified against actual business need
- [ ] **QUESTION**: Does `warehouse` need to subscribe to `order.paid`? Current code shows only outbox + cron + import worker (no event consumer)

### 3.3 Payment — Webhook Retry

- [x] **Webhook retry cron**: `webhook_retry.go` handles failed payment gateway callbacks
- [x] **Failed payment retry**: `failed_payment_retry.go` handles re-processing of failed payments
- [ ] **RISK**: `payment-worker` uses `dapr.io/app-port: 8081` with `http` protocol for the worker. This is inconsistent with `fulfillment-worker` which uses `5005/grpc`. Both serve Dapr pub/sub subscriptions — protocol mismatch could affect subscription delivery reliability

### 3.4 Shipping — Outbox Pattern

- [x] **Outbox implemented**: `shipping` has `outbox_worker.go`
- [x] **Event consumers**: `order_cancelled_consumer.go`, `package_status_consumer.go`
- [ ] **RISK**: `shipping-worker` uses `dapr.io/app-port: 8081` with `http` protocol. If the eventbus server is started on gRPC port 5005 internally, Dapr sidecar app-port must match

---

## 4. GitOps Configuration — Dapr Protocol Inconsistency ⚠️ P1

| Service Worker | `dapr.io/app-port` | `dapr.io/app-protocol` | Verdict |
|---|---|---|---|
| `catalog-worker` | **~~8081~~ → 5005** | **~~http~~ → grpc** | ✅ Fixed |
| `warehouse-worker` | **~~8081~~ → 5005** | **~~http~~ → grpc** | ✅ Fixed |
| `payment-worker` | **~~8081~~ → 5005** | **~~http~~ → grpc** | ✅ Fixed |
| `shipping-worker` | **~~8081~~ → 5005** | **~~http~~ → grpc** | ✅ Fixed |
| `fulfillment-worker` | 5005 | grpc | ✅ Standard |

**~~Action Required → FIXED 2026-02-24~~**: All four workers now configured with `dapr.io/app-port: 5005` and `dapr.io/app-protocol: grpc` — matching `fulfillment-worker` standard. Health probes continue to use port 8081.

### 4.1 Catalog GitOps

- [x] **Uses common-deployment component**: Catalog main service uses `components/common-deployment` template patched to ports 8015 (HTTP) / 9015 (gRPC)
- [x] **Worker has no HPA**: `catalog-worker` has no `hpa.yaml` — single replica for all event processing
- [x] **Resource limits set**: 256Mi/100m → 512Mi/300m
- [x] **Health probes**: liveness + readiness on port 8081 (health endpoint)
- [x] **PDB configured**: `pdb.yaml` present
- [ ] **RISK**: Worker has no HPA — if event backlog grows, cannot scale horizontally

### 4.2 Fulfillment GitOps

- [x] **Deployment + worker-deployment**: Both main and worker present
- [x] **Worker uses gRPC/5005**: ✅ Correct Dapr config
- [x] **Resource limits**: Set appropriately
- [ ] **RISK**: No HPA for fulfillment-worker

### 4.3 Warehouse GitOps

- [x] **WORKER_MODE, ENABLE_CRON, ENABLE_CONSUMER env vars**: Only warehouse-worker explicitly sets these
- [x] **No service.yaml for worker**: Worker is not registered in Consul (correct)
- [ ] **Mismatch**: `dapr.io/app-port: 8081` with `http` but code uses gRPC eventbus consumer (if any subscription is registered) — see §4 above

### 4.4 Payment GitOps

- [x] **Main service**: `8005/http` for Dapr ✅
- [ ] **Worker Dapr port**: `8081/http` — see §4 above, same inconsistency
- [ ] **Missing outbox**: `payment-worker` has `event` + `cron` + `outbox` dirs but the `outbox` dir should be verified — if `payment` publishes any events via outbox, the outbox worker must be in the wire

### 4.5 Shipping GitOps

- [x] **Main service**: `8012/http` ✅
- [ ] **Worker Dapr port**: `8081/http` — same inconsistency

---

## 5. Edge Cases & Unhandled Scenarios

### 5.1 Seller Onboarding Edge Cases

- [ ] **KYC failure with partial data**: Seller uploads docs, KYC is rejected — are uploaded files cleaned up? Is state reset?
- [ ] **Duplicate seller registration**: Same tax ID / business reg number — no dedup guard visible in `auth`/`user` service
- [ ] **Bank account validation failure**: Seller payout bank setup fails — no retry flow
- [ ] **Store profile without product**: Seller active but zero catalog items — should trigger onboarding reminder notification

### 5.2 Seller Dashboard / Catalog Edge Cases

- [ ] **Product approval mid-edit**: Seller edits a product while it's in `PENDING_APPROVAL` — race condition between admin approve and seller update
- [ ] **Bulk import partial failure**: `warehouse` has `import_worker.go` — if row 500 of 1000 fails, are rows 1-499 rolled back or committed? No transactional import visible
- [ ] **SKU-level price override during flash sale**: If seller updates SKU price while a flash sale is active, which price wins? No explicit priority resolution in `catalog`↔`pricing` event flow
- [ ] **Product deletion with active orders**: `catalog.product.deleted` event published via outbox — are active `order`/`warehouse` reservation records referencing this SKU handled?

### 5.3 Order / Fulfillment Edge Cases

- [ ] **Seller marks order shipped without tracking number**: `fulfillment` must enforce tracking number before status change — not confirmed
- [ ] **Multi-warehouse order split**: If order splits across 2 warehouses, separate fulfillment tasks are created — but if one warehouse fails to pick, partial shipment state is unclear
- [ ] **SLA breach calculation**: No automated SLA breach detection cron found in `fulfillment`. Seller penalty calculations are undefined

### 5.4 Payment / Escrow Edge Cases

- [ ] **Escrow release not triggered**: `payment-worker` only subscribes to `return.completed` and `order.cancelled`. **`order.completed` consumer is missing** — escrow release / seller payout on order completion has no trigger
- [ ] **Refund after partial fulfillment**: If only part of the order is delivered and customer returns one item — partial refund calculation vs. seller commission deduction is not confirmed
- [ ] **Commission deduction timing**: Marketplace commission deduction should happen before payout. No evidence of commission service or deduction logic in `payment` biz layer

### 5.5 Seller Performance Edge Cases

- [ ] **Performance score calculation**: No scheduled job found that calculates seller rating (cancellation rate, late ship rate, response time)
- [ ] **Automatic suspension trigger**: If seller exceeds policy violation threshold — no automation for suspension detected
- [ ] **SIP (Seller Improvement Plan) trigger**: Flow spec §12.3 mentions SIP — not implemented in any service

### 5.6 B2B / Wholesale (Not Implemented)

- [ ] **Bulk pricing tiers**: No tier pricing logic beyond standard `pricing` service rules
- [ ] **B2B buyer approval workflow**: Not present
- [ ] **Net-30 / credit terms**: Not present
- [ ] **Purchase order management**: Not present
- [ ] **Bulk invoice generation**: Not present

---

## 6. Event Architecture Verification

### Which Services Actually Need to Publish Events

| Service | Events Published | Via Outbox? | Verified? |
|---|---|---|---|
| `catalog` | `product.created`, `product.updated`, `product.deleted`, `attribute.created`, `attribute.updated` | ✅ Yes | ✅ |
| `warehouse` | `stock.changed`, `reservation.created`, `reservation.confirmed`, `reservation.released` | ✅ Outbox | ⚠️ Verify stock.changed topic name |
| `order` | `order.created`, `order.paid`, `order.cancelled`, `order.status.changed`, `order.completed` | ✅ Outbox | ✅ |
| `payment` | `payment.confirmed`, `payment.failed`, `refund.initiated` | ✅ Outbox | ⚠️ Verifying |
| `fulfillment` | `fulfillment.status.changed`, `shipment.delivered`, `picklist.status.changed` | ⚠️ Check outbox | ⚠️ Pending |
| `shipping` | `shipment.tracking.updated`, `shipment.delivered` | ✅ Outbox | ⚠️ Verify topic |
| `pricing` | `price.updated`, `price.bulk.updated` | Unknown | ❌ Verify |
| `promotion` | `promotion.applied`, `voucher.redeemed` | Unknown | ❌ Verify |
| `loyalty-rewards` | `points.earned`, `points.redeemed`, `tier.changed` | Unknown | ❌ Verify |

### Which Services Actually Need to Subscribe Events

| Service (Worker) | Events Consumed | Verified in Code? |
|---|---|---|
| `catalog-worker` | `stock.changed` (warehouse), `price.updated` (pricing), `price.bulk.updated` (pricing) | ✅ |
| `warehouse-worker` | **None currently registered** | ⚠️ Verify needed |
| `fulfillment-worker` | `order.status.changed` (order), `picklist.status.changed` (fulfillment), `shipment.delivered` (shipping) | ✅ |
| `payment-worker` | `return.completed` (return), `order.cancelled` (order) | ✅ |
| `shipping-worker` | `order.cancelled` (order), `package.status.changed` | ✅ |
| `notification-worker` | Multi-service notification triggers | ✅ Verified (see notification-flow-review.md) |
| `order-worker` | `payment.confirmed`, `payment.failed`, `fulfillment.status.changed` | ⚠️ Verify |

**Missing Consumer Gap**: `payment-worker` should subscribe to `order.completed` to trigger escrow release / seller payout. This is currently absent.

---

## 7. Risk Summary — Prioritized

### 🔴 P0 — Blocking Issues

| # | Risk | Affected Flow | Location |
|---|---|---|---|
| P0-1 | ~~**Escrow release never triggered**: `payment-worker` missing `order.completed` consumer → seller never gets paid~~<br>**✅ FIXED**: `OrderCompletedConsumer` added, `MarkPaymentCompleted` implemented. Wire regenerated. | 12.2 Finance, §7.4 Payout | `payment/internal/data/eventbus/order_completed_consumer.go` |
| P0-2 | ~~**Catalog outbox: publish-then-side-effect ordering**: If `ProcessProductCreated` fails after `PublishEvent` succeeds, downstream has stale product but catalog side effects (cache, views) are incomplete~~<br>**✅ FIXED**: Outbox marks COMPLETED immediately after publish; side-effects are best-effort. | 12.2 Product Mgmt | `catalog/internal/worker/outbox_worker.go` |

### 🟡 P1 — High Priority

| # | Risk | Affected Flow | Location |
|---|---|---|---|
| P1-1 | ~~**Dapr protocol mismatch on workers**~~<br>**✅ FIXED**: All 4 workers now `grpc/5005` | All event flows | `gitops/apps/*/base/worker-deployment.yaml` |
| P1-2 | **No seller escrow/commission service**: No marketplace commission deduction before payout — potential financial leakage | §7.4 Escrow | `payment/internal/biz/` |
| P1-3 | **No SLA breach cron in fulfillment**: Seller late-ship penalties never calculated automatically | 12.3 Performance | `fulfillment/internal/worker/cron/` |
| P1-4 | **Bulk import no transaction**: `warehouse` import worker partial failure leaves inconsistent stock state | 12.2 Inventory | `warehouse/internal/worker/import_worker.go` |
| P1-5 | **Product deletion with active orders**: No saga compensation when `catalog.product.deleted` fires with outstanding orders | 12.2, §6.4 | `catalog/internal/worker/outbox_worker.go` |

### 🔵 P2 — Normal Priority

| # | Risk | Affected Flow |
|---|---|---|
| P2-1 | Seller performance score not auto-calculated (cancellation rate, late ship, response time) | 12.3 |
| P2-2 | KYC failure cleanup: uploaded docs not purged on rejection | 12.1 |
| P2-3 | Duplicate seller registration guard (same tax ID) | 12.1 |
| P2-4 | Product approval race condition (edit during pending approval) | 12.2 |
| P2-5 | B2B wholesale flows entirely unimplemented | 12.4 |
| P2-6 | Seller improvement plan (SIP) trigger not automated | 12.3 |
| P2-7 | No HPA on any worker deployment → single replica is SPOF for event processing | All |
| P2-8 | `pricing` and `promotion` event publish via outbox — not verified | §4.2, §4.3 |

---

## 8. Action Items

- [x] ~~**[P0]** Add `order.completed` consumer to `payment-worker` to trigger escrow release and initiate seller payout~~ **DONE** ✅
- [x] ~~**[P0]** Make catalog outbox `ProcessProduct*` idempotent or use a single DB transaction combining publish + side-effect~~ **DONE** (best-effort side-effects) ✅
- [x] ~~**[P1]** Align Dapr protocol across all workers — standardize to `grpc/5005`~~ **DONE** ✅
- [ ] **[P1]** Add marketplace commission deduction logic to payment service before triggering payout
- [ ] **[P1]** Add SLA breach detection cron to `fulfillment-worker` with seller penalty events
- [ ] **[P1]** Add transaction wrapping to `warehouse` bulk import worker
- [ ] **[P1]** Add `order.cancelled` saga compensation in catalog service (check for active orders before allowing product deletion or handle it gracefully)
- [ ] **[P2]** Add seller performance score calculation cron (daily) in `analytics` or `fulfillment`
- [ ] **[P2]** Add HPA for all worker deployments (at minimum `catalog-worker`, `notification-worker`)
- [ ] **[P2]** Implement KYC document cleanup on rejection in `user`/`auth` service
- [ ] **[P2]** Verify `pricing` and `promotion` services publish events via outbox pattern
- [ ] **[P2]** Document B2B/wholesale as out-of-scope or create implementation plan
- [ ] **[P2]** Verify `warehouse-worker` subscription need: does it need to consume `order.paid` to confirm reservations, or is reservation confirmed via gRPC call from `order` service directly?

---

## 9. Workers & Cron Jobs — Inventory per Service

### catalog-worker
| Worker | Type | Purpose |
|---|---|---|
| `product-outbox-worker` | Outbox | Publishes product/attribute events, refreshes internal cache |
| `MaterializedViewRefreshJob` | Cron | Refreshes catalog materialized views |
| `StockSyncJob` | Cron | Periodic stock reconciliation with warehouse |
| `OutboxCleanupJob` | Cron | Prunes completed/failed outbox records |
| `stock-changed-consumer` | Event | Receives warehouse stock changes |
| `stock-changed-dlq-consumer` | Event | Drains DLQ for failed stock events |
| `price-updated-consumer` | Event | Receives pricing service price updates |
| `price-bulk-updated-consumer` | Event | Receives bulk price update events |

### warehouse-worker
| Worker | Type | Purpose |
|---|---|---|
| `ImportWorker` | Background | Bulk stock import processing |
| `OutboxWorker` | Outbox | Publishes warehouse events |
| `AlertCleanupJob` | Cron | Cleans up stale alerts |
| `CapacityMonitorJob` | Cron | Monitors warehouse capacity |
| `DailyResetJob` | Cron | Daily counters reset |
| `DailySummaryJob` | Cron | Generates daily summary reports |
| `OutboxCleanupJob` | Cron | Prunes outbox records |
| `ReservationCleanupJob` | Cron | Releases expired soft-lock reservations |
| `StockChangeDetector` | Cron | Detects stock threshold breaches |
| `TimeslotValidatorJob` | Cron | Validates warehouse timeslots |
| `WeeklyReportJob` | Cron | Generates weekly stock reports |
| *(Event consumers)* | — | **None currently registered** ⚠️ |

### fulfillment-worker
| Worker | Type | Purpose |
|---|---|---|
| *(Cron jobs)* | Cron | 1 cron job (needs verification) |
| `EventbusServerWorker` | Event infra | Starts gRPC subscriber server |
| `OrderStatusConsumerWorker` | Event | Reacts to order status changes |
| `PicklistStatusConsumerWorker` | Event | Reacts to picklist status changes |
| `ShipmentDeliveredConsumerWorker` | Event | Marks fulfillment complete on delivery |

### payment-worker
| Worker | Type | Purpose |
|---|---|---|
| `AutoCaptureJob` | Cron | Auto-captures authorized payments |
| `BankTransferExpiryJob` | Cron | Expires stale bank transfer requests |
| `CleanupJob` | Cron | Prunes old payment records |
| `FailedPaymentRetryJob` | Cron | Retries failed payments |
| `PaymentReconciliationJob` | Cron | Reconciles gateway settlements |
| `PaymentStatusSyncJob` | Cron | Polls gateway for pending statuses |
| `RefundProcessingJob` | Cron | Processes queued refunds |
| `WebhookRetryJob` | Cron | Retries failed webhook callbacks |
| *(Outbox)* | Outbox | Publishes payment events |
| `EventConsumerWorker` | Event | `return.completed`, `order.cancelled`, **`order.completed`** ✅ consumers |

### shipping-worker
| Worker | Type | Purpose |
|---|---|---|
| `OutboxWorker` | Outbox | Publishes shipment events |
| `OrderCancelledConsumer` | Event | Cancels shipments on order cancellation |
| `PackageStatusConsumer` | Event | Updates tracking on package status change |

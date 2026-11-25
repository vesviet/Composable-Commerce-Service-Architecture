# Seller / Merchant Flow — Business Logic Review Checklist

**Last Updated**: 2026-02-24 (P0/P1 fixes applied)  
**Audit**: 2026-03-02 — Deep code verification: P1-2, P1-3, P1-5 verified FIXED; P1-4 confirmed OPEN
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
- ⏳ **Backlog Note**: If `catalog-worker` is down when `stock.changed` fires, stock display in catalog lags until `ConsumeStockChangedDLQ` drains.
- ⏳ **Backlog Note**: Confirm `StockSyncJob` cron interval tuning per load profile.

### 2.2 Pricing ↔ Catalog (Price Sync)

- [x] **Price sync via event**: `pricing` publishes `price.updated` → `catalog-worker` consumes via `ConsumePriceUpdated` + `ConsumePriceBulkUpdated`
- [x] **Unified consumer**: Phase 2 consolidates product/warehouse/sku price scopes into one consumer
- ⏳ **Backlog Note**: Price change in `pricing` relies on `ConsumePriceUpdated` + `MaterializedViewRefreshJob` (eventual consistency).
- [x] ✅ **Mitigated**: Checkout revalidates authoritative prices (`ValidateCart`/calculate totals) against `pricing` before payment.

### 2.3 Order ↔ Warehouse (Inventory Reservation)

- [x] **Reservation pattern**: Soft-reserve on order creation, confirm on payment, release on cancellation
- [x] ✅ **FIXED (`P0-04`)**: `warehouse-worker` runs wired `ReservationCleanupJob` to expire stale reservations.
- [x] **Cleanup cron**: `warehouse-worker` has `reservation_cleanup_job.go` ✅

### 2.4 Fulfillment ↔ Order (Status Sync)

- [x] **Event-driven**: `fulfillment-worker` subscribes to `order.status.changed` via `ConsumeOrderStatusChanged`
- [x] **Picklist consumer**: `fulfillment-worker` subscribes to `picklist.status.changed` via `ConsumePicklistStatusChanged`
- [x] **Shipment delivered**: `fulfillment-worker` subscribes to `shipment.delivered` via `ConsumeShipmentDelivered`
- [x] ~~**RISK**: `fulfillment` has only 1 cron job~~ — ✅ FIXED (verified 2026-03-02): `SLABreachDetectorJob` exists in `fulfillment/internal/worker/cron/sla_breach_detector.go` with hourly detection across planning/picking/packing stages

### 2.5 Payment ↔ Order (Escrow / Payout)

- [x] **Payment cron jobs**: `auto_capture.go`, `bank_transfer_expiry.go`, `cleanup.go`, `failed_payment_retry.go`, `payment_reconciliation.go`, `payment_status_sync.go`, `refund_processing.go`, `webhook_retry.go`
- [x] **~~FIXED P0-1~~** `order.completed` consumer added to `payment-worker` → `OrderCompletedConsumer.HandleOrderCompleted` → `PaymentUsecase.MarkPaymentCompleted` transitions `captured → completed` and publishes `payment.status_changed`
- [x] ✅ **FIXED (`P1-2`)**: Commission deduction (`defaultCommissionRate = 0.10`) implemented in `MarkPaymentCompleted`; seller matrix (`P2-59`) deferred.

### 2.6 Shipping ↔ Order (Tracking)

- [x] **Event consumer**: `shipping-worker` subscribes to `order.cancelled` and `package.status.changed`
- ⏳ **Backlog Note**: Carrier webhook tracking propagation (`SHIPPED` → `IN_TRANSIT` / `OUT_FOR_DELIVERY`) tracked under carrier tracking integration.

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
- [x] ✅ **Verified**: Warehouse event consumers (`order_cancelled`, `fulfillment`, `return`, `product_deleted`) registered separately from cron/import providers.
- ⏳ **Design Note (Deferred)**: Warehouse reservation confirmation occurs via `order` / `checkout` saga orchestration (`ConfirmReservation`).

### 3.3 Payment — Webhook Retry

- [x] **Webhook retry cron**: `webhook_retry.go` handles failed payment gateway callbacks
- [x] **Failed payment retry**: `failed_payment_retry.go` handles re-processing of failed payments
- [x] ✅ **FIXED (`P1-1`)**: Standardized `payment-worker` Dapr annotations to `app-port: "5005"` and `app-protocol: "grpc"`.

### 3.4 Shipping — Outbox Pattern

- [x] **Outbox implemented**: `shipping` has `outbox_worker.go`
- [x] **Event consumers**: `order_cancelled_consumer.go`, `package_status_consumer.go`
- [x] ✅ **FIXED (`P1-1`)**: Standardized `shipping-worker` Dapr annotations to `app-port: "5005"` and `app-protocol: "grpc"`.

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
- [x] ✅ **FIXED (`P2-77`)**: Added `gitops/apps/catalog/overlays/production/worker-hpa.yaml` (`maxReplicas: 3`) in `kustomization.yaml`.

### 4.2 Fulfillment GitOps

- [x] **Deployment + worker-deployment**: Both main and worker present
- [x] **Worker uses gRPC/5005**: ✅ Correct Dapr config
- [x] **Resource limits**: Set appropriately
- [x] ✅ **FIXED (`P2-36`)**: Added `gitops/apps/fulfillment/overlays/production/worker-hpa.yaml` & `worker-resources.yaml`.

### 4.3 Warehouse GitOps

- [x] **WORKER_MODE, ENABLE_CRON, ENABLE_CONSUMER env vars**: Only warehouse-worker explicitly sets these
- [x] **No service.yaml for worker**: Worker is not registered in Consul (correct)
- [x] ✅ **FIXED (`P1-1`)**: `warehouse-worker` standardized to `5005/grpc`.

### 4.4 Payment GitOps

- [x] **Main service**: `8005/http` for Dapr ✅
- [x] ✅ **FIXED (`P1-1`)**: `payment-worker` standardized to `5005/grpc`.
- [x] ✅ **FIXED (`P2-56`)**: Single active `common/outbox` worker wired at `payment/internal/worker/event/outbox_worker.go`.

### 4.5 Shipping GitOps

- [x] **Main service**: `8012/http` ✅
- [x] ✅ **FIXED (`P1-1`)**: `shipping-worker` standardized to `5005/grpc`.

---

## 5. Edge Cases & Unhandled Scenarios

### 5.1 Seller Onboarding Edge Cases

- ⏳ **Backlog / Deferred (`P2-2`)**: KYC document cleanup on rejection tracked under seller onboarding backlog.
- ⏳ **Backlog / Deferred (`P2-3`)**: Duplicate seller tax ID / business registration dedup guard.
- ⏳ **Backlog / Deferred**: Seller payout bank validation retry flow.
- ⏳ **Backlog / Deferred**: Empty store onboarding reminder notification.

### 5.2 Seller Dashboard / Catalog Edge Cases

- ⏳ **Backlog / Deferred (`P2-4`)**: Optimistic lock / edit freeze during `PENDING_APPROVAL`.
- [x] ✅ **FIXED (`P1-4`)**: Warehouse bulk import wraps each batch in `uc.tx.InTx()`.
- ⏳ **Backlog / Deferred**: Campaign priority vs seller SKU override precedence rule.
- [x] ✅ **FIXED (`P1-5`, `P2-38`)**: `OrderChecker` blocks product deletion with active orders; `warehouse/internal/data/eventbus/product_deleted_consumer.go` cleans up reservations.

### 5.3 Order / Fulfillment Edge Cases

- ⏳ **Backlog / Deferred**: Tracking number pre-condition on seller shipment dispatch.
- ⏳ **Backlog / Deferred**: Split-order partial pick rollback/state coordination.
- [x] ~~**SLA breach calculation**~~: ✅ FIXED — `SLABreachDetectorJob` in fulfillment worker detects breach across `pending`, `planning`, `picking`, `packing` stages and publishes `fulfillments.fulfillment.sla_breach` events

### 5.4 Payment / Escrow Edge Cases

- [x] ✅ **FIXED (`P0-01`)**: `payment/internal/data/eventbus/order_status_changed_consumer.go` handles `delivered`/`completed` to trigger `markPaymentCompleted` escrow release.
- ⏳ **Backlog / Deferred**: Partial-fulfillment pro-rated commission clawback calculation.
- [x] ~~**Commission deduction timing**~~: ✅ FIXED — `payment/internal/biz/payment/usecase.go:925` has `defaultCommissionRate = 0.10` with full calculation before payout

### 5.5 Seller Performance Edge Cases

- ⏳ **Backlog / Deferred (`P2-1` / `P2-76`)**: Scheduled seller SLA scoring cron (tracked as `P2-76`).
- ⏳ **Backlog / Deferred**: Automated seller policy suspension job.
- ⏳ **Backlog / Deferred (`P2-6`)**: Seller Improvement Plan workflow.

### 5.6 B2B / Wholesale (Not Implemented)

- ⏳ **Deferred B2B Suite (`P2-5`)**: Bulk pricing tiers, B2B buyer approval, Net-30 terms, PO management, and bulk invoicing are out of current consumer release scope.

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
| P1-2 | ~~**No seller escrow/commission service**~~ | §7.4 Escrow | ✅ FIXED — `defaultCommissionRate = 0.10` in `usecase.go:925` |
| P1-3 | ~~**No SLA breach cron in fulfillment**~~ | 12.3 Performance | ✅ FIXED — `SLABreachDetectorJob` wired in worker |
| P1-4 | ~~**Bulk import no transaction**~~ | 12.2 Inventory | ✅ FIXED — each batch now wrapped in `uc.tx.InTx()` |
| P1-5 | ~~**Product deletion with active orders**~~ | 12.2, §6.4 | ✅ FIXED — `OrderChecker` blocks delete if active orders exist |

### 🔵 P2 — Normal Priority

| # | Risk | Affected Flow |
|---|---|---|
| P2-1 (`P2-76`) | Seller performance score not auto-calculated *(Deferred — Product / Cross-Service Spec)* | 12.3 |
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
- [x] ~~**[P1]**~~ ✅ Commission deduction logic exists — `defaultCommissionRate = 0.10` with calculation in `MarkPaymentCompleted`
- [x] ~~**[P1]**~~ ✅ SLA breach detection cron exists — `SLABreachDetectorJob` with per-stage thresholds
- [x] ~~**[P1]**~~ ✅ Transaction wrapping added to `warehouse` bulk import — `uc.tx.InTx()` per batch
- [x] ~~**[P1]**~~ ✅ `OrderChecker` interface blocks product deletion when active orders exist
- ⏳ **[P2-1 -> `P2-76` Deferred]** Seller performance score calculation cron (requires SLA scoring spec)
- [x] **[P2 -> FIXED ✅ (`P2-36`, `P2-77`)]** Worker HPAs added across `catalog-worker`, `fulfillment-worker`, `shipping-worker`, and `promotion`
- ⏳ **[P2-2 Deferred]** KYC document cleanup on rejection in `user`/`auth`
- [x] **[P2 -> FIXED ✅ (`P2-25`)]** `pricing` and `promotion` outbox workers verified & standardized on `common/outbox`
- ⏳ **[P2-5 Deferred]** B2B/wholesale flows deferred beyond current release scope
- [x] **[P2 -> Verified ✅]** Warehouse reservation confirmation occurs via checkout/order saga `ConfirmReservation` RPC

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

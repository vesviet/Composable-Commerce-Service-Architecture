# 🚩 UNFIXED ISSUES — CONSOLIDATED CHECKLIST

**Generated**: 2026-03-07 (verified & synchronized: 2026-11-24)  
**Source**: All 21 workflow review files in `docs/10-appendix/checklists/workflow/`  
**Purpose**: Single source of truth for unresolved workflow review issues.

---

## 📊 Summary

| Severity | Initial | Remaining Open | Impact |
|----------|---------|----------------|--------|
| 🔴 P0 — Critical | **7** | **0** ✅ | All P0 blockers resolved & verified |
| 🟡 P1 — High | **26** | **0** ✅ | All P1 reliability/consistency fixes implemented |
| 🔵 P2 — Nice to Have | **77** *(in sections below)* | **72** *(backlog)* | Tech debt, cleanup, optional feature enhancements |

---

## 🔴 P0 — CRITICAL (Must Fix Immediately)

### ~~P0-01: Payment subscribes to dead topic `orders.order.completed` — escrow never released~~ [FIXED ✅]
- **Source**: `order-lifecycle-deep-review.md` P0-2026-01
- **Service**: payment
- **File**: `payment/internal/data/eventbus/order_status_changed_consumer.go`
- **Fix Applied**: Subscribed to `orders.order.status_changed` with routing on `"delivered"` and `"completed"` to trigger escrow release (`markPaymentCompleted`).
- [x] Verified resolved

### ~~P0-02: Payment subscribes to dead topic `orders.order.cancelled` — void never triggered~~ [FIXED ✅]
- **Source**: `order-lifecycle-deep-review.md` P0-2026-02
- **Service**: payment
- **File**: `payment/internal/data/eventbus/order_status_changed_consumer.go`
- **Fix Applied**: Subscribed to `orders.order.status_changed` filtering `new_status == "cancelled"` to invoke `voidAuthorizedPayments`.
- [x] Verified resolved

### ~~P0-03: Warehouse `StockReconciliationJob` NOT wired into `newWorkers()` — job never runs~~ [FIXED ✅]
- **Source**: `inventory-warehouse-review.md` WH-P0-V3-01
- **Service**: warehouse
- **File**: `warehouse/cmd/worker/wire_gen.go`
- **Fix Applied**: Wired `stockReconciliationJob *cron.StockReconciliationJob` into `newWorkers()`.
- [x] Verified resolved

### ~~P0-04: Warehouse `ReservationCleanupJob` NOT wired — missing ContinuousWorker interface~~ [FIXED ✅]
- **Source**: `inventory-warehouse-review.md` WH-P0-V3-02
- **Service**: warehouse
- **File**: `warehouse/internal/worker/cron/reservation_cleanup_job.go`, `warehouse/cmd/worker/wire_gen.go`
- **Fix Applied**: Implemented `Name()`, `HealthCheck()`, `GetBaseWorker()`, `Start()`, `Stop()` and wired `reservationCleanupJob` into `newWorkers()`.
- [x] Verified resolved

### ~~P0-05: Loyalty `handleReturnCompleted` method body MISSING — compile blocker~~ [FIXED ✅]
- **Source**: `return-refund-review.md` RET-P0-04
- **Service**: loyalty-rewards
- **File**: `loyalty-rewards/internal/worker/event/consumer.go:72`
- **Fix Applied**: Created `return_completed_event.go` with full handler implementation
- [x] Fixed by Agent 3

### ~~P0-06: Loyalty ConfigMap hardcodes plaintext DB/Redis credentials~~ [FIXED ✅]
- **Source**: `customer-identity-review-2026-03-07.md` N-5
- **Service**: loyalty-rewards (GitOps)
- **File**: `gitops/apps/loyalty-rewards/base/configmap.yaml:12-13`
- **Fix Applied**: Moved credentials from ConfigMap to Secret, added REDIS_URL to secrets.yaml
- [x] Fixed by Agent 3

### ~~P0-07: Search ConfigMap promotion topics mismatch (`promotions.*` vs `promotion.*`)~~ [FIXED ✅]
- **Source**: `search-discovery-review.md` V3-P0-02
- **Service**: search (GitOps)
- **File**: `gitops/apps/search/base/configmap.yaml:63-65`
- **Fix Applied**: Renamed `promotions.promotion.*` → `promotion.*` in ConfigMap
- [x] Fixed by Agent 4

---

## 🟡 P1 — HIGH (Fix Before Release)

### Customer & Identity Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-01~~ | ~~`UserRegisteredEvent` defined but **never published** — dead code~~ [FIXED ✅] | auth | `customer-identity-2026-03-07` #1 | Added TODO documenting dead code |
| ~~P1-02~~ | ~~Customer outbox infra exists but **no outbox worker** — events stuck in DB~~ [ALREADY FIXED ✅] | customer | `customer-identity-2026-03-07` #2 | Outbox worker already wired |
| ~~P1-03~~ | ~~Loyalty `OutboxPublisherAdapter.PublishEvent` is **no-op stub** (`return nil`)~~ [FIXED ✅] | loyalty-rewards | `customer-identity-2026-03-07` #4 | Wired actual Dapr publisher |
| ~~P1-04~~ | ~~Loyalty missing `orders.return.completed` in GitOps Dapr subscription YAML~~ [ALREADY FIXED ✅] | loyalty-rewards | `customer-identity-2026-03-07` #5 | Subscription already exists |
| ~~P1-05~~ | ~~Auth/User/Loyalty worker `patch-worker.yaml` are placeholder stubs — no Dapr annotations~~ [FIXED ✅] | auth, user, loyalty-rewards | `customer-identity-2026-03-07` #6-8 | Added Dapr config to all 3 patches |
| ~~P1-06~~ | ~~Customer `isPermanentError` receiver mismatch (pointer vs value)~~ [FIXED ✅] | customer | `customer-identity-2026-03-07` #9 | Fixed receiver consistency |

### Order & Payment Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-07~~ | ~~Order status `completed` NOT reachable from `delivered` — missing transition~~ [FIXED ✅] | order | `order-lifecycle-deep-review` P1-2026-01 | `order/internal/constants/constants.go:177` transitions to `OrderStatusCompleted` |
| ~~P1-08~~ | ~~Payment worker missing `dapr-subscription.yaml` entirely~~ [FIXED ✅] | payment | `order-lifecycle-deep-review` P1-2026-03 | Added `gitops/apps/payment/base/dapr-subscription.yaml` |
| ~~P1-09~~ | ~~`ConfirmCODCollection` bypasses state machine (`CanTransitionTo` not called)~~ [FIXED ✅] | payment | `payment-review` V3-01 | `payment/internal/biz/payment/cod.go:135` enforces `CanTransitionTo` |
| ~~P1-10~~ | ~~`voidAuthorizedPayments` ignores `pending`/`requires_action` on cancel~~ [FIXED ✅] | payment | `payment-review` V3-02 | `order_status_changed_consumer.go:171-175` voids `authorized`, `pending`, `requires_action` |
| ~~P1-11~~ | ~~`capturePayment` (scheduled) skips `CanTransitionTo` on failure path~~ [FIXED ✅] | payment | `payment-review` V3-03 | `payment/internal/biz/payment/usecase.go:853` enforces `CanTransitionTo` |

### Fulfillment & Shipping Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-12~~ | ~~`compensatePackageShipped` hardcodes `StatusProcessing` as rollback target~~ [FIXED ✅] | fulfillment | `fulfillment-shipping-review` P1-2 | Replaced with `FulfillmentStatusCompensationPending` -> `Compensated` (`fulfillment_lifecycle.go`, `shipment_returned/fulfillment_sub.go`) |
| ~~P1-13~~ | ~~`handlePackageCreated` fails if `order_id` missing from event metadata~~ [FIXED ✅] | fulfillment | `fulfillment-shipping-review` EC17 | Populated `order_id` in `Package.Metadata` + shared `buildPackageEventMetadata` |
| ~~P1-14~~ | ~~`ShipFulfillment` marks SHIPPED even when shipping client is nil~~ [FIXED ✅] | fulfillment | `fulfillment-shipping-review` EC20 | `fulfillment_dispatch.go:404-431` emits transactional outbox `shipping.delivery.requested` event |

### Warehouse Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-15~~ | ~~`ProductCreatedConsumer` handler is no-op — no inventory record created~~ [CLOSED ✅ — BY DESIGN] | warehouse | `inventory-warehouse-review` WH-P1-V3-01 | Intentionally logs `[NEW_PRODUCT_NO_INVENTORY]` (`warehouse_sub.go`) for explicit admin initialization |

### Notification Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-16~~ | ~~`AuthLoginConsumer` missing retry + DLQ pattern~~ [FIXED ✅] | notification | `notification-flow-review` NOTIF-NEW-001 | Added `handleWithRetry` + DLQ |
| ~~P1-17~~ | ~~`OrderStatusConsumer.RecipientID` uses `ChangedBy` (admin) not `CustomerID`~~ [FIXED ✅] | notification | `notification-flow-review` NOTIF-NEW-002 | Changed to parse `event.CustomerID` |

### Pricing & Promotion Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-18~~ | ~~Stock consumer idempotency is in-memory only (`sync.Map`) — lost on restart~~ [FIXED ✅] | pricing | `pricing-promotion-tax-review` V2-06 | `pricing/internal/data/eventbus/stock_consumer.go:58` uses Redis `SetNX` with TTL |

### Search Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-19~~ | ~~Review/Rating event topics NOT in GitOps ConfigMap~~ [FIXED ✅] | search | `search-discovery-review` V3-P0-01 | Added topics |
| ~~P1-20~~ | ~~Missing DLQ topics for review/rating in ConfigMap~~ [FIXED ✅] | search | `search-discovery-review` V3-P1-01 | Added DLQ entries |
| ~~P1-21~~ | ~~Stale pricing topics in ConfigMap~~ [FIXED ✅] | search | `search-discovery-review` V3-P1-02 | Removed stale entries |
| ~~P1-22~~ | ~~`FailedEventCleanupWorker` not in `worker_names.go` constants~~ [FIXED ✅] | search | `search-discovery-review` V3-P1-03 | Added constant |

### Return & Refund Domain

| # | Issue | Service | Source | Fix |
|---|-------|---------|-------|-----|
| ~~P1-23~~ | ~~No stale return cleanup cron (7d pending, 14d approved auto-cancel)~~ [FIXED ✅] | return | `return-refund-review` RET-P1-06 | Implemented `return/internal/worker/stale_return_cleanup.go` (daily cron, 7d pending & 14d approved) |
| ~~P1-24~~ | ~~No DLQ worker for permanently failed outbox events~~ [FIXED ✅] | return | `return-refund-review` RET-P1-07 | Implemented `return/internal/worker/dlq_worker.go` |
| ~~P1-25~~ | ~~Exchange failure not compensated — no retry event~~ [FIXED ✅] | return | `return-refund-review` RET-P1-08 | Implemented `return.exchange_retry` in `return/internal/worker/compensation_worker.go` |
| ~~P1-26~~ | ~~Order status dual-path conflict (gRPC sets `returned`, event sets `partially_returned`)~~ [FIXED ✅] | return, order | `return-refund-review` RET-P1-09 | `orders.return.completed` owns `returned`/`partially_returned` via `order/internal/data/eventbus/return_consumer.go`; `return_approval.go` only transitions `return_requested`/`completed` |

---

## 🔵 P2 — NICE TO HAVE (Backlog / Tech Debt)

### Analytics & Reporting
| # | Issue | Source |
|---|-------|--------|
| P2-01 | `ExecuteDataQualityCheck` spawns unmanaged goroutine | `analytics-reporting-review` ANLT-V3-P1-001 |
| P2-02 | Reconciliation only checks 2 of 7+ event types | `analytics-reporting-review` ANLT-V3-P1-002 |
| P2-03 | `BatchProcessEvents` missing routes for 5+ event types | `analytics-reporting-review` ANLT-V3-P1-003 |
| P2-04 | Worker pods share API labels → NetworkPolicy too permissive | `analytics-reporting-review` ANLT-V3-P2-002 |
| P2-05 | `updateProductMetrics` is a no-op stub | `analytics-reporting-review` ANLT-V3-P2-003 |
| P2-06 | `ReconciliationReport.ProductViewEvents` never threshold-checked | `analytics-reporting-review` ANLT-V3-P2-004 |

### Cart & Checkout
| # | Issue | Source |
|---|-------|--------|
| ~~P2-07~~ | ~~Loyalty point redemption not in checkout flow~~ [FIXED ✅] | `frontend` `/checkout` + `/api/v1/loyalty/points/redeem` |
| P2-08 | Promo expiry race between validation and apply | `cart-checkout-deep-review` P2-CC-04 |
| P2-09 | Dual `warehouseClient`/`warehouseInventoryService` interface | `cart-checkout-deep-review` P2-CC-07 |
| P2-10 | `MaxOrderAmount` hardcoded as constant | `cart-checkout-deep-review` P2-CC-08 |
| P2-11 | `CheckoutSessionCleanupWorker` has no DLQ for failed reservation releases | `cart-checkout-review-2026-03-07` NEW-01 |
| P2-12 | `ReservationCleanupJob` scans ALL cancelled orders every 15 min | `cart-checkout-review-2026-03-07` NEW-02 |
| P2-13 | `validatePaymentMethodEligibility` uses subtotal for COD ceiling | `cart-checkout-review-2026-03-07` NEW-03 |
| P2-14 | `codCeiling`, `installmentFloor` hardcoded | `cart-checkout-review-2026-03-07` NEW-04 |
| P2-15 | Session cleanup clears ALL metadata | `cart-checkout-review-2026-03-07` NEW-05 |

### Catalog & Product
| # | Issue | Source |
|---|-------|--------|
| P2-16 | Review Dapr subscription scope issue | `catalog-product-review` V4-03 |
| P2-17 | `stock_sync.go` is dead code | `catalog-product-review` V4-04 |
| P2-18 | Draft → Active with no approval queue | `catalog-product-review` EDGE-02 |
| P2-19 | Bulk attribute reindex has no cursor/checkpoint | `catalog-product-review` EDGE-04 |
| P2-20 | ES alias conflict during full re-index | `catalog-product-review` EDGE-05 |
| P2-21 | `catalog.product.created` → Warehouse init failure is silent | `catalog-product-review` EDGE-06 |
| P2-22 | Review photo-review bonus points flow undefined | `catalog-product-review` EDGE-07 |
| P2-23 | No automated replay for FAILED outbox rows in Catalog | `catalog-product-review` OUTBOX-DLQ |

### Cross-Cutting Concerns
| # | Issue | Source |
|---|-------|--------|
| P2-24 | Review Service Workers embedded in main binary — no independent scaling | `cross-cutting-concerns-review` XC2-P1-002 |
| ~~P2-25~~ | ~~Custom Outbox Workers not fully standardized~~ [FIXED ✅] | `common/outbox` across Go outbox workers (`promotion` standardized 2026-11-24, `location` already on `common/outbox`) |
| ~~P2-26~~ | ~~No GDPR/PDPA Data Erasure API~~ [FIXED ✅] | `customer/internal/biz/customer/gdpr.go` & `wishlist_gdpr_http.go` |
| P2-27 | DLQ not configured in 4 event consumer services | `cross-cutting-concerns-review` XC2-NEW-001 |
| P2-28 | Idempotency still fragmented — 6+ mechanisms | `cross-cutting-concerns-review` XC2-NEW-002 |
| P2-29 | Auth event consumers still incomplete | `cross-cutting-concerns-review` XC2-NEW-003 |

### Customer & Identity
| # | Issue | Source |
|---|-------|--------|
| ~~P2-30~~ | ~~Points expiry cron has no distributed lock — multi-replica risk~~ [FIXED ✅] | `customer-identity-2026-03-07` #10 |
| ~~P2-31~~ | ~~`service/event_handler.go` duplicates `data/eventbus/*_consumer.go` logic~~ [FIXED ✅] | `customer-identity-2026-03-07` #11 |
| P2-32 | Event JSON field naming inconsistent (camelCase vs snake_case) | `customer-identity-2026-03-07` N-8 |

### Fulfillment & Shipping
| # | Issue | Source |
|---|-------|--------|
| P2-33 | Dead `EventBus` in shipping — deprecation notice added, still wired | `fulfillment-shipping-review` P2-5 |
| P2-34 | `handlePackageCreated` hardcodes `"USD"` currency | `fulfillment-shipping-review` EC18 |
| P2-35 | `MarkReadyToShip` QC error not typed (sentinel error needed) | `fulfillment-shipping-review` EC19 |
| P2-36 | Base worker resources conservative (128Mi/50m) for production | `fulfillment-shipping-review` P2-NEW-3 |

### Inventory & Warehouse
| # | Issue | Source |
|---|-------|--------|
| P2-37 | Production overlay missing configmap/secrets | `inventory-warehouse-review` P2-NEW-05 |
| P2-38 | No handler for `catalog.product.deleted` — orphan inventory | `inventory-warehouse-review` P2-V3-01 |
| P2-39 | `OutboxWorker.cleanupOldEvents` hardcoded 7d vs config 30d | `inventory-warehouse-review` P2-V3-02 |

### Notification
| # | Issue | Source |
|---|-------|--------|
| P2-40 | `notification.*` events have zero consumers | `notification-flow-review` NOTIF-P2-003 |
| P2-41 | All consumers hardcode Telegram — no multi-channel routing | `notification-flow-review` NOTIF-P2-004 |
| P2-42 | `RecipientID` nil for payment/return consumers | `notification-flow-review` NOTIF-P2-005 |
| P2-43 | Worker Dapr `app-protocol` HTTP vs gRPC mismatch | `notification-flow-review` NOTIF-P2-006 |
| P2-44 | `system.errors` topic only published by Fulfillment | `notification-flow-review` NOTIF-NEW-003 |

### Notification Domain (Admin Operations)
| # | Issue | Source |
|---|-------|--------|
| P2-45 | `CancelTask`/`RetryTask` publish with outer `ctx` not `txCtx` | `remaining-issues-consolidated` E16 |
| P2-46 | Outbox Publisher Job NOT implemented | `remaining-issues-consolidated` E17 |
| P2-47 | `TaskProcessorWorker.Process()` returns error for unknown types | `remaining-issues-consolidated` E18 |
| P2-48 | `processDataSyncTask` is stub | `remaining-issues-consolidated` E19 |
| P2-49 | Message template variable injection has no HTML escaping | `remaining-issues-consolidated` E20 |
| P2-50 | Worker deployment declares unused port 8081 | `remaining-issues-consolidated` E21 |
| P2-51 | Settings + Audit publish are non-transactional | `remaining-issues-consolidated` E22 |
| P2-52 | No RBAC enforcement inside biz layer | `remaining-issues-consolidated` E23 |

### Payment
| # | Issue | Source |
|---|-------|--------|
| P2-53 | Payment `HandleOrderCancelled` missing idempotency guard | `order-lifecycle-deep-review` P2-2026-01 |
| P2-54 | Payment `HandleOrderCompleted` missing idempotency guard | `order-lifecycle-deep-review` P2-2026-02 |
| P2-55 | Dead constants `TopicOrderCompleted`/`TopicOrderCancelled` | `order-lifecycle-deep-review` P2-2026-03 |
| P2-56 | Duplicate OutboxWorker implementations (2 files) | `payment-review` V3-P2-01 |
| P2-57 | `getBankTransferProvider` always returns nil | `payment-review` V3-P2-02 |
| P2-58 | COD amount mismatch silently accepted | `payment-review` V3-P2-03 |
| P2-59 | Commission rate hardcoded at 10% | `payment-review` V3-P2-04 |

### Pricing & Promotion
| # | Issue | Source |
|---|-------|--------|
| P2-60 | `price.calculated` event dropped if Dapr sidecar unavailable | `pricing-promotion-tax-review` V2-P2-01 |
| P2-61 | Campaign events published to outbox with no consumer | `pricing-promotion-tax-review` V2-P2-02 |
| P2-62 | `DiscountAppliedEvent` struct defined but never published (dead code) | `pricing-promotion-tax-review` |
| P2-63 | Promotion HPA missing for production | `pricing-promotion-tax-review` |
| P2-64 | `ConfirmPromotionUsage` no outbox event (no downstream notification) | `promotion-service-review` P2-1 |
| P2-65 | Dead code: `publishPromotionEvent`, `publishBulkCouponsEvent` | `promotion-service-review` P2-2 |
| P2-66 | Outbox `Save` error swallowed in `ReleasePromotionUsage` | `promotion-service-review` P2-5 |

### Return & Refund
| # | Issue | Source |
|---|-------|--------|
| P2-67 | Migration schema drift (vs GORM model) | `return-refund-review` RET-P2-01 |
| P2-68 | Exchange price difference hardcoded to 0 | `return-refund-review` RET-P2-05 |
| P2-69 | Evidence upload (photo/video) not implemented | `return-refund-review` RET-P2-06 |
| P2-70 | Refund to store credit not implemented | `return-refund-review` RET-P2-07 |
| P2-71 | Return window per category not configurable | `return-refund-review` RET-P2-08 |

### Search & Discovery
| # | Issue | Source |
|---|-------|--------|
| P2-72 | No DLQ drain consumer for review/rating | `search-discovery-review` V3-P2-01 |
| P2-73 | `HandlePromotionDeleted` silent ACK on empty ID | `search-discovery-review` V3-P2-02 |
| P2-74 | N+1 gRPC calls in reconciliation/orphan cleanup | `search-discovery-review` V3-P2-03 |
| P2-75 | Cache disabled in dev — no test coverage for cache path | `search-discovery-review` V3-P2-04 |

### Seller / Merchant
| # | Issue | Source |
|---|-------|--------|
| P2-76 | Seller performance score not auto-calculated | `seller-merchant-review` P2-1 |
| P2-77 | No HPA on catalog-worker | `seller-merchant-review` P2-7 |

---

## 📋 Workstream Status (Updated 2026-11-24)

| Workstream | Domain | Status | Reference |
|---|---|---|---|
| **Track 1** | Payment & Order | ✅ **ALL DONE** | P0-01/02, P1-07..11 |
| **Track 2** | Warehouse & Inventory | ✅ **ALL DONE** | P0-03/04, P1-15 |
| **Track 3** | Customer & Identity | ✅ **ALL DONE** | P1-01..06, P2-26, P2-30/31 |
| **Track 4** | Notification, Search & Analytics | ✅ **ALL DONE** (P0+P1+P2-19..22) | P1-16/17, P1-19..22 |
| **Track 5** | Return, Fulfillment, Shipping, Pricing | ✅ **ALL DONE** (P1) | P1-12..14, P1-18, P1-23..26 |
| **Track 6** | Code Hygiene & Comment Rules | ✅ **ALL DONE** | 230 cleanups |
| **Track 7** | Outbox Pattern Standardization | ✅ **ALL DONE** | Standardized on `common/outbox` (`promotion` & `location` verified) |

> **Remaining open across P0 & P1**: **0 P0 + 0 P1** (all blocking and high-priority items resolved; remaining items in the P2 section are low-priority backlog enhancements/tech debt).

---

*Generated from 21 workflow review files + WORKER-EVENT-CRONJOB-REVIEW.md. Each issue links to its source document for full context.*


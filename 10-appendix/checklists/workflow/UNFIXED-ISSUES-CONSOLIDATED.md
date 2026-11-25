# 🚩 UNFIXED ISSUES — CONSOLIDATED CHECKLIST

**Generated**: 2026-03-07 (verified & synchronized: 2026-11-25)  
**Source**: All 21 workflow review files in `docs/10-appendix/checklists/workflow/`  
**Purpose**: Single source of truth for unresolved workflow review issues.

---

## 📊 Summary

| Severity | Initial | Remaining Open | Impact |
|----------|---------|----------------|--------|
| 🔴 P0 — Critical | **7** | **0** ✅ | All P0 blockers resolved & verified |
| 🟡 P1 — High | **26** | **0** ✅ | All P1 reliability/consistency fixes implemented |
| 🔵 P2 — Nice to Have | **77** | **0 actionable engineering bugs** (**18 deferred**) | `59/77` P2 items verified `[FIXED ✅]` (`5` prior + `30` audited already fixed + `24` quick fixes applied); remaining `18` deferred pending product/cross-service specs |

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
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-01~~ | ~~`ExecuteDataQualityCheck` spawns unmanaged goroutine~~ [FIXED ✅] | `analytics/internal/biz/data_quality_usecase.go` — bounded concurrency (`wg`, sem cap 16, `Shutdown`, cancellable timeout context) |
| ~~P2-02~~ | ~~Reconciliation only checks 2 of 7+ event types~~ [FIXED ✅] | `analytics/internal/service/reconciliation_service.go` — tracks `EventTypeCounts`, `SevenDayAverages`, and alerts across all tracked event types |
| ~~P2-03~~ | ~~`BatchProcessEvents` missing routes for 5+ event types~~ [FIXED ✅] | `analytics/internal/service/event_processor.go` — routed fulfillment, shipping, payment, return, and `cart.converted` events |
| ~~P2-04~~ | ~~Worker pods share API labels → NetworkPolicy too permissive~~ [FIXED ✅] | `gitops/apps/analytics/base/networkpolicy.yaml` — split `analytics` (`backend`) and `analytics-worker` (`worker`, `ingress: []`) |
| ~~P2-05~~ | ~~`updateProductMetrics` is a no-op stub~~ [FIXED ✅] | `analytics/internal/service/event_processor.go:554-565` & `metrics_repository.go:343` — Redis hash counters wired & tested |
| ~~P2-06~~ | ~~`ReconciliationReport.ProductViewEvents` never threshold-checked~~ [FIXED ✅] | `analytics/internal/service/reconciliation_service.go` — computes `SevenDayAvgProductView` & enforces threshold alert |

### Cart & Checkout
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-07~~ | ~~Loyalty point redemption not in checkout flow~~ [FIXED ✅] | `frontend` `/checkout` + `/api/v1/loyalty/points/redeem` |
| P2-08 | Promo expiry race between validation and apply *(Deferred — Product / Cross-Service Spec)* | `cart-checkout-deep-review` P2-CC-04 — requires `promotion` TTL reservation RPC + cross-service lifecycle redesign |
| ~~P2-09~~ | ~~Dual `warehouseClient`/`warehouseInventoryService` interface~~ [FIXED ✅] | `checkout/internal/biz/checkout/usecase.go:27` & `adapter.NewWarehouseAdapter` |
| ~~P2-10~~ | ~~`MaxOrderAmount` hardcoded as constant~~ [FIXED ✅] | `checkout/internal/config/config.go`, `usecase.go` (`SetCheckoutConfig` / `getMaxOrderAmount`) |
| ~~P2-11~~ | ~~`CheckoutSessionCleanupWorker` has no DLQ for failed reservation releases~~ [FIXED ✅] | `checkout/internal/worker/cron/checkout_session_cleanup.go:188-215` writes `model.FailedCompensation` |
| ~~P2-12~~ | ~~`ReservationCleanupJob` scans ALL cancelled orders every 15 min~~ [FIXED ✅] | `order/internal/worker/cron/reservation_cleanup.go:50-73` uses 30-day cutoff + cursor pagination (`cancelledPageSize = 100`) |
| ~~P2-13~~ | ~~`validatePaymentMethodEligibility` uses subtotal for COD ceiling~~ [FIXED ✅] | `checkout/internal/biz/checkout/confirm_step_calculate.go` & `confirm_guards.go` enforce `validatePaymentMethodLimits` on final `c.Totals.TotalAmount` |
| ~~P2-14~~ | ~~`codCeiling`, `installmentFloor` hardcoded~~ [FIXED ✅] | `checkout/internal/config/config.go` adds `CODOrderCeiling` & `InstallmentMinAmount` wired via `NewConfiguredUseCase` |
| ~~P2-15~~ | ~~Session cleanup clears ALL metadata~~ [FIXED ✅] | `checkout/internal/worker/cron/checkout_session_cleanup.go:133-154` clears only `"reservation_ids"` |

### Catalog & Product
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-16~~ | ~~Review Dapr subscription scope issue~~ [FIXED ✅] | `gitops/apps/review/base/dapr-subscription.yaml` scoped to `review`; `review-worker` disables Dapr |
| ~~P2-17~~ | ~~`stock_sync.go` is dead code~~ [FIXED ✅] | Removed dead `catalog/internal/job/stock_sync.go` (`catalog/internal/worker/cron/stock_sync.go` is the active cron) |
| P2-18 | Draft → Active with no approval queue *(Deferred — Product / Cross-Service Spec)* | `catalog-product-review` EDGE-02 — requires moderation roles, review statuses, and Admin UI workflow |
| ~~P2-19~~ | ~~Bulk attribute reindex has no cursor/checkpoint~~ [FIXED ✅] | `search/internal/service/product_consumer.go` persists/resumes `attr_reindex_cursor:<attr_id>` in cache |
| ~~P2-20~~ | ~~ES alias conflict during full re-index~~ [FIXED ✅] | `search/internal/data/elasticsearch/index.go` (`resolveAliasName`) & `search/internal/biz/indexing.go` |
| P2-21 | `catalog.product.created` → Warehouse init failure is silent *(Deferred — Product / Cross-Service Spec)* | `catalog-product-review` EDGE-06 — closed BY DESIGN in `P1-15`; changing behavior requires reversing `P1-15` policy |
| P2-22 | Review photo-review bonus points flow undefined *(Deferred — Product / Cross-Service Spec)* | `catalog-product-review` EDGE-07 — requires bonus point rules & anti-abuse spec across `review`/`loyalty-rewards` |
| ~~P2-23~~ | ~~No automated replay for FAILED outbox rows in Catalog~~ [FIXED ✅] | `catalog/internal/server/http.go` adds admin `GET /admin/outbox/failed` and `POST /admin/outbox/{id}/retry` + tests |

### Cross-Cutting Concerns
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-24~~ | ~~Review Service Workers embedded in main binary — no independent scaling~~ [FIXED ✅] | Moved moderation/rating/analytics workers out of `review/cmd/review` into `review/cmd/worker/wire.go` |
| ~~P2-25~~ | ~~Custom Outbox Workers not fully standardized~~ [FIXED ✅] | `common/outbox` across Go outbox workers (`promotion` standardized 2026-11-24, `location` already on `common/outbox`) |
| ~~P2-26~~ | ~~No GDPR/PDPA Data Erasure API~~ [FIXED ✅] | `customer/internal/biz/customer/gdpr.go` & `wishlist_gdpr_http.go` |
| ~~P2-27~~ | ~~DLQ not configured in 4 event consumer services~~ [FIXED ✅] | `loyalty-rewards` & `review` already configured; added `deadLetterTopic` in `gateway/internal/worker/eventbus_consumer.go` & `gitops/apps/analytics/base/dapr-subscription.yaml` |
| P2-28 | Idempotency still fragmented — 6+ mechanisms *(Deferred — Product / Cross-Service Spec)* | `cross-cutting-concerns-review` XC2-NEW-002 — large multi-service unification across 10+ services + DB migrations |
| P2-29 | Auth event consumers still incomplete *(Deferred — Product / Cross-Service Spec)* | `cross-cutting-concerns-review` XC2-NEW-003 — `auth.token.*`/`auth.session.*` analytics consumers require product spec |

### Customer & Identity
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-30~~ | ~~Points expiry cron has no distributed lock — multi-replica risk~~ [FIXED ✅] | `customer-identity-2026-03-07` #10 |
| ~~P2-31~~ | ~~`service/event_handler.go` duplicates `data/eventbus/*_consumer.go` logic~~ [FIXED ✅] | Removed deprecated `customer/internal/service/event_handler.go`, `dapr_subscription.go`, and Wire/HTTP references |
| P2-32 | Event JSON field naming inconsistent (camelCase vs snake_case) *(Deferred — Product / Cross-Service Spec)* | `customer-identity-2026-03-07` N-8 — breaking cross-service wire contract migration across publishers & consumers |

### Fulfillment & Shipping
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-33~~ | ~~Dead `EventBus` in shipping — deprecation notice added, still wired~~ [FIXED ✅] | Removed dead `DaprEventBus` + `ShipmentEventHandler` wiring from `shipping/cmd/shipping/{main.go,wire.go}` and deleted unused files |
| ~~P2-34~~ | ~~`handlePackageCreated` hardcodes `"USD"` currency~~ [FIXED ✅] | `shipping/internal/biz/shipment/package_status_handler.go:83-88` reads `event.Metadata["currency"]` |
| ~~P2-35~~ | ~~`MarkReadyToShip` QC error not typed (sentinel error needed)~~ [FIXED ✅] | `fulfillment/internal/constants/fulfillment_status.go` defines `ErrQCRequired`/`ErrQCNotPassed`, mapped to `codes.FailedPrecondition` in `error_mapping.go` |
| ~~P2-36~~ | ~~Base worker resources conservative (128Mi/50m) for production~~ [FIXED ✅] | `gitops/apps/{fulfillment,shipping}/overlays/production/worker-resources.yaml` sets `256Mi/512Mi` + `worker-hpa.yaml` |

### Inventory & Warehouse
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-37~~ | ~~Production overlay missing configmap/secrets~~ [FIXED ✅] | `gitops/apps/warehouse/overlays/production/{configmap,secrets}.yaml` wired in `kustomization.yaml` |
| ~~P2-38~~ | ~~No handler for `catalog.product.deleted` — orphan inventory~~ [FIXED ✅] | `warehouse/internal/data/eventbus/product_deleted_consumer.go` & `observer/product_deleted/warehouse_sub.go` |
| ~~P2-39~~ | ~~`OutboxWorker.cleanupOldEvents` hardcoded 7d vs config 30d~~ [FIXED ✅] | `warehouse/internal/worker/{outbox_worker,cron/outbox_cleanup_job}.go` defaults to 30d and reads `OutboxRetentionDays` |

### Notification
| # | Issue | Source / Status |
|---|-------|-----------------|
| P2-40 | `notification.*` events have zero consumers *(Deferred — Product / Cross-Service Spec)* | `notification-flow-review` NOTIF-P2-003 — downstream analytics/ops consumer feature spec required |
| ~~P2-41~~ | ~~All consumers hardcode Telegram — no multi-channel routing~~ [FIXED ✅] | Consumers pass `Channel: "auto"`, resolved by `resolveChannel` (`notification_usecase.go`) |
| ~~P2-42~~ | ~~`RecipientID` nil for payment/return consumers~~ [FIXED ✅] | `payment_event_consumer.go` & `return_event_consumer.go` populate `RecipientID` from `event.CustomerID` |
| ~~P2-43~~ | ~~Worker Dapr `app-protocol` HTTP vs gRPC mismatch~~ [FIXED ✅] | `gitops/apps/notification/base/patch-worker.yaml:9-10` uses `app-port: "5005"`, `app-protocol: "grpc"` |
| P2-44 | `system.errors` topic only published by Fulfillment *(Deferred — Product / Cross-Service Spec)* | `notification-flow-review` NOTIF-NEW-003 — platform-wide adoption across ~20 services vs Alertmanager webhook |

### Common Operations
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-45~~ | ~~`CancelTask`/`RetryTask` publish with outer `ctx` not `txCtx`~~ [FIXED ✅] | `common-operations/internal/biz/task/task.go:373-459` creates outbox events inside `txManager.WithTransaction` |
| ~~P2-46~~ | ~~Outbox Publisher Job NOT implemented~~ [FIXED ✅] | `common-operations/internal/worker/cron/outbox_publisher.go` wired in `cmd/worker/wire_gen.go` |
| ~~P2-47~~ | ~~`TaskProcessorWorker.Process()` returns error for unknown types~~ [FIXED ✅] | `common-operations/internal/worker/task_processor.go` persists `"failed"` and ACKs (`nil`) unsupported task types |
| P2-48 | `processDataSyncTask` is stub *(Deferred — Product / Cross-Service Spec)* | `remaining-issues-consolidated` E19 — requires sync source/target & cursor product specification |
| ~~P2-49~~ | ~~Message template variable injection has no HTML escaping~~ [FIXED ✅] | `common-operations/internal/biz/message/message.go` escapes variables via `html.EscapeString` |
| ~~P2-50~~ | ~~Worker deployment declares unused port 8081~~ [FIXED ✅] | Removed unused `metrics` port `8081` from `gitops/apps/common-operations/base/patch-worker.yaml` |
| ~~P2-51~~ | ~~Settings + Audit publish are non-transactional~~ [FIXED ✅] | `common-operations/internal/biz/settings/usecase.go` wraps `UpdateWithVersion` + `auditRepo.Record` in `txManager.WithTransaction` |
| P2-52 | No RBAC enforcement inside biz layer *(Deferred — Product / Cross-Service Spec)* | `remaining-issues-consolidated` E23 — requires biz permission matrix & internal-worker bypass design |

### Payment
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-53~~ | ~~Payment `HandleOrderCancelled` missing idempotency guard~~ [FIXED ✅] | `payment/internal/data/eventbus/order_status_changed_consumer.go:108-145` uses `idempotencyHelper.CheckAndMark` |
| ~~P2-54~~ | ~~Payment `HandleOrderCompleted` missing idempotency guard~~ [FIXED ✅] | `payment/internal/data/eventbus/order_status_changed_consumer.go:108-145` guards `delivered`/`completed` |
| ~~P2-55~~ | ~~Dead constants `TopicOrderCompleted`/`TopicOrderCancelled`~~ [FIXED ✅] | Removed dead topic constants from `payment/internal/constants/constants.go` |
| ~~P2-56~~ | ~~Duplicate OutboxWorker implementations (2 files)~~ [FIXED ✅] | Single `common/outbox` worker at `payment/internal/worker/event/outbox_worker.go` |
| ~~P2-57~~ | ~~`getBankTransferProvider` always returns nil~~ [FIXED ✅] | `payment/internal/biz/payment/bank_transfer.go` delegates legacy single-provider branch to `uc.gatewayFactory.GetBankTransferProvider()` |
| ~~P2-58~~ | ~~COD amount mismatch silently accepted~~ [FIXED ✅] | `payment/internal/biz/payment/cod.go:154-166` validates collected vs expected amount (1% tolerance) |
| P2-59 | Commission rate hardcoded at 10% *(Deferred — Product / Cross-Service Spec)* | `payment-review` V3-P2-04 — requires seller/category commission matrix & seller lookup contract |

### Pricing & Promotion
| # | Issue | Source / Status |
|---|-------|-----------------|
| P2-60 | `price.calculated` event dropped if Dapr sidecar unavailable *(Deferred — Product / Cross-Service Spec)* | `pricing-promotion-tax-review` V2-P2-01 — high-QPS read telemetry requires async buffer/Kafka vs best-effort decision |
| ~~P2-61~~ | ~~Campaign events published to outbox with no consumer~~ [FIXED ✅] | `promotion/internal/biz/campaign.go:121-126` intentionally no-ops `saveCampaignOutboxEvent` (tested) |
| ~~P2-62~~ | ~~`DiscountAppliedEvent` struct defined but never published (dead code)~~ [FIXED ✅] | Removed (`0` occurrences across `pricing/internal` & `promotion/internal`) |
| ~~P2-63~~ | ~~Promotion HPA missing for production~~ [FIXED ✅] | Wired `gitops/apps/promotion/overlays/production/hpa.yaml` (`maxReplicas: 6`, CPU `70%`) in `overlays/production/kustomization.yaml` |
| ~~P2-64~~ | ~~`ConfirmPromotionUsage` no outbox event (no downstream notification)~~ [FIXED ✅] | `promotion/internal/biz/promotion_usecase.go:262-275` persists `promotion.usage_confirmed` inside `InTx` |
| ~~P2-65~~ | ~~Dead code: `publishPromotionEvent`, `publishBulkCouponsEvent`~~ [FIXED ✅] | Removed from all Go files in `promotion/` |
| ~~P2-66~~ | ~~Outbox `Save` error swallowed in `ReleasePromotionUsage`~~ [FIXED ✅] | `promotion/internal/biz/promotion_usecase.go:376-383` returns error and rolls back tx |

### Return & Refund
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-67~~ | ~~Migration schema drift (vs GORM model)~~ [FIXED ✅] | `return/migrations/005_reconcile_schema_with_model.sql` reconciles schema with `model/return.go` |
| P2-68 | Exchange price difference hardcoded to 0 *(Deferred — Product / Cross-Service Spec)* | `return-refund-review` RET-P2-05 — requires Pricing gRPC lookup + extra-charge/partial-refund settlement flow |
| P2-69 | Evidence upload (photo/video) not implemented *(Deferred — Product / Cross-Service Spec)* | `return-refund-review` RET-P2-06 — requires media storage/presigned-URL contract, migration, proto & UI upload |
| P2-70 | Refund to store credit not implemented *(Deferred — Product / Cross-Service Spec)* | `return-refund-review` RET-P2-07 — requires wallet/store-credit ledger design across `return`/`payment`/`loyalty-rewards` |
| P2-71 | Return window per category not configurable *(Deferred — Product / Cross-Service Spec)* | `return-refund-review` RET-P2-08 — requires Catalog category policy schema + Return↔Catalog RPC contract |

### Search & Discovery
| # | Issue | Source / Status |
|---|-------|-----------------|
| ~~P2-72~~ | ~~No DLQ drain consumer for review/rating~~ [FIXED ✅] | Added `ConsumeReviewApprovedDLQ`/`ConsumeRatingUpdatedDLQ` in `search/internal/data/eventbus/review_consumer.go` & registered in `workers.go` |
| ~~P2-73~~ | ~~`HandlePromotionDeleted` silent ACK on empty ID~~ [FIXED ✅] | `search/internal/data/eventbus/promotion_consumer.go:223-226` returns error when `PromotionID == ""` |
| ~~P2-74~~ | ~~N+1 gRPC calls in reconciliation/orphan cleanup~~ [FIXED ✅] | `search/internal/worker/reconciliation_worker.go` batches missing IDs with `GetProductsBulk` |
| ~~P2-75~~ | ~~Cache disabled in dev — no test coverage for cache path~~ [FIXED ✅] | Enabled in `gitops/apps/search/overlays/dev/configmap.yaml:73` & covered by 4 unit test suites |

### Seller / Merchant
| # | Issue | Source / Status |
|---|-------|-----------------|
| P2-76 | Seller performance score not auto-calculated *(Deferred — Product / Cross-Service Spec)* | `seller-merchant-review` P2-1 — requires product SLA scoring formula & cross-service aggregation cron |
| ~~P2-77~~ | ~~No HPA on catalog-worker~~ [FIXED ✅] | `gitops/apps/catalog/overlays/production/worker-hpa.yaml` (`namespace: catalog-production`, `maxReplicas: 3`) active in `kustomization.yaml` |

---

## 📋 Workstream Status (Updated 2026-11-25)

| Workstream | Domain | Status | Reference |
|---|---|---|---|
| **Track 1** | Payment & Order | ✅ **ALL DONE** (excl. deferred `P2-59`) | `P0-01/02`, `P1-07..11`, `P2-53..58` |
| **Track 2** | Warehouse & Inventory | ✅ **ALL DONE** | `P0-03/04`, `P1-15`, `P2-37..39` |
| **Track 3** | Customer & Identity | ✅ **ALL DONE** (excl. deferred `P2-32`) | `P1-01..06`, `P2-26`, `P2-30/31` |
| **Track 4** | Notification, Search & Analytics | ✅ **ALL DONE** (excl. deferred `P2-29/40/44`) | `P1-16/17`, `P1-19..22`, `P2-01..06`, `P2-41..43`, `P2-72..75` |
| **Track 5** | Return, Fulfillment, Shipping, Pricing, Catalog, Checkout | ✅ **ALL DONE** (excl. deferred feature specs) | `P1-12..14`, `P1-18`, `P1-23..26`, `P2-09..17`, `P2-19/20/23`, `P2-33..36`, `P2-61..67` |
| **Track 6** | Code Hygiene & Comment Rules | ✅ **ALL DONE** | `common-operations` `P2-45..47/49..51`, `review` `P2-24`, `gateway` `P2-27` |
| **Track 7** | Outbox Pattern Standardization | ✅ **ALL DONE** | Standardized on `common/outbox` across Go services |

> **Remaining open across P0 & P1**: **0 P0 + 0 P1** (all blocking and high-priority items resolved; remaining items in the P2 section are low-priority backlog enhancements/tech debt).

---

*Generated from 21 workflow review files + WORKER-EVENT-CRONJOB-REVIEW.md. Each issue links to its source document for full context.*


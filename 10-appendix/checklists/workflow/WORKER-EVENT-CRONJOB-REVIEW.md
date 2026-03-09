# 📊 Worker / Event / Cronjob — Full Platform Review

**Date**: 2026-03-08  
**Reviewer**: Senior Lead  
**Scope**: All 18 services  
**Skills**: `service-structure` (dual-binary), `review-service` (P0/P1/P2 framework)

---

## 1. Worker Registry — Per Service

### Legend
- 🟠 **Outbox** — transactional outbox processor (polls DB, publishes events)
- 🔵 **Event** — Dapr PubSub consumer (subscribes to topics)
- 🟢 **Cron** — periodic scheduled job
- ✅ Uses `common/outbox.Worker` | ❌ Custom impl | ⚠️ Partial

---

### auth
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `SessionCleanupWorker` | 🟢 Cron | N/A |

> **Note**: Auth has a non-standard entry — uses `initWorker()` instead of `wireWorkers()` + `newWorkers()` pattern.

---

### user
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ❌ Custom |

> Uses `NoOpEventPublisher` for worker binary — events only published via outbox.

---

### customer
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `SegmentEvaluatorWorker` | 🟢 Cron | N/A |
| `StatsWorker` | 🟢 Cron | N/A |
| `CleanupWorker` | 🟢 Cron | N/A |
| `OutboxWorker` | 🟠 Outbox | ✅ `common/outbox.Worker` |
| `OrderConsumer` | 🔵 Event | N/A |
| `AuthRegistrationConsumer` | 🔵 Event | N/A |
| `PointsExpirationJob` | 🟢 Cron | N/A |

---

### catalog
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| Workers via `worker.ProviderSet` | 🔵 Event + 🟢 Cron | ❌ Custom event processor |

> Uses `EventProcessor` pattern — different from standard consumer model.

---

### order
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OrderCleanupJob` | 🟢 Cron | N/A |
| `ReservationCleanupJob` | 🟢 Cron | N/A |
| `CODAutoConfirmJob` | 🟢 Cron | N/A |
| `CaptureRetryJob` | 🟢 Cron | N/A |
| `PaymentCompensationJob` | 🟢 Cron | N/A |
| `EventConsumersWorker` | 🔵 Event | N/A |
| `OutboxWorker` | 🟠 Outbox | ✅ `common/outbox.Worker` |

---

### payment
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `AutoCaptureJob` | 🟢 Cron | N/A |
| `PaymentReconciliationJob` | 🟢 Cron | N/A |
| `FailedPaymentRetryJob` | 🟢 Cron | N/A |
| `PaymentStatusSyncJob` | 🟢 Cron | N/A |
| `RefundProcessingJob` | 🟢 Cron | N/A |
| `CleanupJob` | 🟢 Cron | N/A |
| `BankTransferExpiryJob` | 🟢 Cron | N/A |
| `WebhookRetryWorker` | 🟢 Cron | N/A |
| `OutboxWorker` | 🟠 Outbox | ❌ Custom |
| `EventConsumerWorker` | 🔵 Event | N/A |

---

### warehouse
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `StockChangeDetectorJob` | 🟢 Cron | N/A |
| `AlertCleanupJob` | 🟢 Cron | N/A |
| `OutboxCleanupJob` | 🟢 Cron | N/A |
| `DailySummaryJob` | 🟢 Cron | N/A |
| `WeeklyReportJob` | 🟢 Cron | N/A |
| `DailyResetJob` | 🟢 Cron | N/A |
| `CapacityMonitorJob` | 🟢 Cron | N/A |
| `TimeSlotValidatorJob` | 🟢 Cron | N/A |
| `StockReconciliationJob` | 🟢 Cron | N/A |
| `ReservationCleanupJob` | 🟢 Cron | N/A |
| `ReservationExpiryWorker` | 🟢 Cron | N/A |
| `ReservationWarningWorker` | 🟢 Cron | N/A |
| `OutboxWorker` | 🟠 Outbox | ❌ Custom |
| `OrderStatusConsumer` | 🔵 Event | N/A |
| `ProductCreatedConsumer` | 🔵 Event | N/A |
| `ProductDeletedConsumer` | 🔵 Event | N/A |
| `FulfillmentStatusConsumer` | 🔵 Event | N/A |
| `ReturnConsumer` | 🔵 Event | N/A |
| `StockCommittedConsumer` | 🔵 Event | N/A |

---

### fulfillment
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `AutoCompleteShippedWorker` | 🟢 Cron | N/A |
| `SLABreachDetectorJob` | 🟢 Cron | N/A |
| `EventbusServerWorker` | 🔵 Event (server) | N/A |
| `OrderStatusConsumerWorker` | 🔵 Event | N/A |
| `PicklistStatusConsumerWorker` | 🔵 Event | N/A |
| `ShipmentDeliveredConsumerWorker` | 🔵 Event | N/A |
| `OutboxWorker` | 🟠 Outbox | ✅ `common/outbox.Worker` |

---

### shipping
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ❌ Custom |
| `PackageStatusConsumerWorker` | 🔵 Event | N/A |
| `OrderCancelledConsumerWorker` | 🔵 Event | N/A |
| `EventbusServerWorker` | 🔵 Event (server) | N/A |

---

### location
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ✅ `common/outbox.Worker` |

---

### pricing
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ❌ Custom (177 lines) |
| Event consumers via `observer` | 🔵 Event | N/A |

---

### promotion
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ❌ Custom |
| Event consumers via `ProviderSet` | 🔵 Event | N/A |

---

### loyalty-rewards
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ✅ `common/outbox.Worker` |
| Event consumers + `PointsExpirationJob` | 🔵 Event + 🟢 Cron | N/A |

---

### review
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ❌ Custom |
| `ModerationWorker` | 🟢 Cron | N/A |
| `AnalyticsWorker` | 🟢 Cron | N/A |
| `RatingWorker` | 🟢 Cron | N/A |

---

### search
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `TrendingWorker` | 🟢 Cron | N/A |
| `PopularWorker` | 🟢 Cron | N/A |
| `DLQReprocessorWorker` | 🟢 Cron | N/A |
| `FailedEventCleanupWorker` | 🟢 Cron | N/A |
| `ReconciliationWorker` | 🟢 Cron | N/A |
| `OrphanCleanupWorker` | 🟢 Cron | N/A |
| Event consumers via `ProviderSet` | 🔵 Event | N/A |

---

### analytics
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| Workers via `cron.ProviderSet` | 🟢 Cron | N/A |

> Analytics uses non-standard architecture — `zap.SugaredLogger` instead of `kratos/log.Logger`.

---

### notification
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `EventbusServerWorker` | 🔵 Event (server) | N/A |
| `SystemErrorConsumer` | 🔵 Event | N/A |
| `OrderStatusConsumer` | 🔵 Event | N/A |
| `PaymentEventConsumer` | 🔵 Event | N/A |
| `ReturnEventConsumer` | 🔵 Event | N/A |
| `AuthLoginConsumer` | 🔵 Event | N/A |
| `OutboxWorker` | 🟠 Outbox | ✅ `common/outbox.Worker` |

---

### return
| Worker | Type | Outbox Pattern |
|--------|:----:|:--------------:|
| `OutboxWorker` | 🟠 Outbox | ✅ `common/outbox.Worker` |
| `ReturnCompensationWorker` | 🟢 Cron | N/A |
| `StaleReturnCleanupWorker` | 🟢 Cron | N/A |
| `DLQWorker` | 🟢 Cron | N/A |

---

## 2. Outbox Pattern Compliance Summary

| Service | Uses `common/outbox` | Status |
|---------|:-------------------:|--------|
| customer | ✅ | Compliant |
| order | ✅ | Compliant |
| fulfillment | ✅ | Compliant |
| location | ✅ | Compliant |
| return | ✅ | Compliant |
| loyalty-rewards | ✅ | Compliant (recently fixed) |
| notification | ✅ | Compliant |
| **user** | ❌ Custom | Needs migration |
| **payment** | ❌ Custom | Needs migration |
| **warehouse** | ❌ Custom | Needs migration |
| **shipping** | ❌ Custom | Needs migration |
| **pricing** | ❌ Custom | Needs migration |
| **promotion** | ❌ Custom | Needs migration |
| **review** | ❌ Custom | Needs migration |
| **catalog** | ❌ Custom EventProcessor | Needs migration |
| **checkout** | ❌ Custom + ⚠️ no SKIP LOCKED | **P0 — needs URGENT fix** |
| auth | N/A | No outbox needed |
| search | N/A | No outbox (uses ES) |
| analytics | N/A | No outbox |

**Score: 7/16 compliant (44%)**

---

## 3. Event Topic Map — Publisher → Consumer

| Topic | Publisher | Consumers |
|-------|----------|-----------|
| `orders.order.status_changed` | order | payment, warehouse, notification, promotion, shipping |
| `payment.payment.processed` | payment | order, notification |
| `payment.payment.failed` | payment | order, notification |
| `payment.payment.refunded` | payment | order, notification |
| `payment.payment.captured` | payment | order |
| `payment.payment.voided` | payment | (none visible) |
| `orders.return.completed` | return | payment, loyalty-rewards, order |
| `orders.return.approved` | return | notification |
| `orders.return.requested` | return | order |
| `fulfillments.fulfillment.status_changed` | fulfillment | order, warehouse |
| `packages.package.status_changed` | fulfillment | shipping |
| `shipping.shipment.created` | shipping | order |
| `shipping.shipment.delivered` | shipping | order, fulfillment |
| `shipping.delivery.confirmed` | shipping | order |
| `catalog.product.created` | catalog | warehouse, search |
| `catalog.product.updated` | catalog | search |
| `catalog.product.deleted` | catalog | warehouse, search |
| `pricing.price.updated` | pricing | search |
| `pricing.price.deleted` | pricing | search |
| `promotion.created/updated/deleted` | promotion | search |
| `warehouse.inventory.stock_changed` | warehouse | search, pricing |
| `review.approved` | review | search |
| `rating.updated` | review | search |
| `auth.login` | auth | notification |
| `system.errors` | fulfillment | notification |
| `loyalty.points.earned/deducted` | loyalty-rewards | (none visible) |
| `loyalty.tier.upgraded` | loyalty-rewards | (none visible) |
| `notification.sent/failed` | notification | (none visible) |
| `campaign.*` events | promotion | (none visible) |
| `coupon.*` events | promotion | (none visible) |

---

## 4. 🔴 P0 Issues Found

### P0-WRK-01: Checkout outbox — no `SKIP LOCKED` (duplicate risk)
- **Ref**: OUTBOX-AUDIT P0-OUTBOX-01 (already tracked)
- **Status**: ❌ NOT FIXED

### P0-WRK-02: Auth worker — non-standard Wire pattern
- **File**: `auth/cmd/worker/wire.go`
- **Problem**: Uses `initWorker()` returning single `*SessionCleanupWorker` instead of standard `wireWorkers()` returning `[]ContinuousWorker`. If more workers are added in the future, the pattern breaks.
- **Impact**: Low immediate risk, but architectural debt.

---

## 5. 🟡 P1 Issues Found

### P1-WRK-01: 9 services still use custom outbox workers
- **Services**: user, payment, warehouse, shipping, pricing, promotion, review, catalog, checkout
- **Ref**: AGENT-7-OUTBOX-MIGRATION.md (tracked)

### P1-WRK-02: `payment.payment.voided` has no consumers
- **Topic**: `payment.payment.voided`
- **Problem**: Payment publishes voided events but no service subscribes. Order service should handle this for status updates.
- **Fix**: Add consumer in order service for voided payment events.

### P1-WRK-03: Loyalty events have no consumers
- **Topics**: `loyalty.points.earned`, `loyalty.points.deducted`, `loyalty.tier.upgraded`, `loyalty.reward.redeemed`, `loyalty.referral.completed`
- **Problem**: Events published but no downstream consumer. Notification should subscribe for customer communications.
- **Fix**: Add notification consumers for tier/points events.

### P1-WRK-04: `notification.*` events have zero consumers
- **Topics**: `notification.sent`, `notification.failed`
- **Ref**: Agent 9 P2-40 (tracked as P2, should be P1 for observability)

### P1-WRK-05: Promotion has 14 event topics, most with no consumers
- **Topics**: `campaign.*` (5 topics), `coupon.*` (5 topics)
- **Problem**: Massive event surface with zero downstream consumers. Only `promotion.created/updated/deleted` consumed by search.
- **Fix**: Review if these events are needed. Remove dead code or document as "future use."

### P1-WRK-06: User service outbox uses custom worker — not tracked
- **File**: `user/internal/worker/outbox_worker.go`
- **Problem**: Not included in AGENT-7 task. Uses custom implementation.
- **Fix**: Add to Agent 7 scope.

### P1-WRK-07: Analytics uses `zap.SugaredLogger` instead of `kratos/log.Logger`
- **File**: `analytics/cmd/worker/wire.go`
- **Problem**: All other services use `kratos/log.Logger`. Analytics uses Zap directly — breaks structured logging consistency.

---

## 6. 🔵 P2 Issues

### P2-WRK-01: Inconsistent event topic naming conventions
| Pattern | Services | Examples |
|---------|----------|---------|
| `{domain}.{entity}.{action}` | order, payment, shipping, warehouse | `orders.order.status_changed` |
| `{entity}.{action}` | promotion, search | `promotion.created`, `review.approved` |
| `{domain}.{entity}` | checkout | `checkout.cart.converted` |

### P2-WRK-02: Search has 6 cron workers but no central scheduling/priority
- Workers: trending, popular, DLQ reprocessor, failed event cleanup, reconciliation, orphan cleanup
- Risk: All run simultaneously on single worker pod — resource contention.

### P2-WRK-03: Warehouse has 12 cron workers — most in any service
- Risk: Single worker pod running 12 concurrent jobs + 6 event consumers + outbox. May need worker pod splitting by mode (`--mode cron` vs `--mode event`).

### P2-WRK-04: Catalog uses `EventProcessor` — different from standard consumer model
- All other services use individual consumer structs via observer pattern. Catalog has monolithic event processor.

---

## 7. Totals

| Metric | Count |
|--------|:-----:|
| Services with workers | **18** |
| Total outbox workers | **16** |
| Compliant outbox (`common/outbox`) | **7** (44%) |
| Custom outbox (needs migration) | **9** (56%) |
| Total cron jobs | **~35** |
| Total event consumers | **~25** |
| Total event topics published | **~50** |
| Topics with zero consumers | **~20** (40%) |
| P0 issues | **2** |
| P1 issues | **7** |
| P2 issues | **4** |

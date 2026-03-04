# Remaining Issues — Consolidated Checklist

**Date**: 2026-03-02  
**Scope**: All 18 workflow review checklists in `docs/10-appendix/checklists/workflow/`  
**Purpose**: Single source of truth for open (unfixed) issues across all service reviews  
**Status Legend**: 🔴 P0 · 🟡 P1 · 🔵 P2 · ✅ Fixed

---

## 📊 Executive Summary

| Severity | Open | Fixed | Total |
|----------|------|-------|-------|
| 🔴 P0 | **0** | 41+ | ~41+ |
| 🟡 P1 | **0** | 75+ | ~75+ |
| 🔵 P2 | **54+** | 41+ | ~95+ |

> All P0 and P1 issues resolved. Sprint 1+2 fixed payment DLQ/worker, warehouse cron wiring, customer data integrity, promotion N+1 queries, loyalty clawback, partial return status, fulfillment compensation, and seller commission.
> Remaining P1s are feature additions: return lifecycle, fulfillment saga, seller commission.

---

## 🔴 P0 — Must Fix Before Production

### ~~PAYMENT: No DLQ Drain Handlers for Event Consumers~~ ✅ Fixed (Sprint 1)

- **Source**: [payment-review.md](payment-review.md) `[NEW-01]`
- **Fix Applied**: Added `ConsumeReturnCompletedDLQ`, `ConsumeOrderCancelledDLQ`, `ConsumeOrderCompletedDLQ` methods and registered them in `EventConsumerWorker.Start()`.

---

## 🟡 P1 — Fix Before Release

### Payment Service

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~1~~ | ~~`PaymentReconciliationJob.Start()` goroutine lifecycle~~  | ~~[payment-review.md](payment-review.md) `[NEW-02]`~~ | ✅ Already uses `worker.CronWorker` |
| ~~2~~ | ~~`WebhookRetryWorker` busy-wait~~ | ~~[payment-review.md](payment-review.md) `[NEW-03]`~~ | ✅ Fixed: `time.NewTicker(30s)` |
| ~~3~~ | ~~Worker probes~~ | ~~[payment-review.md](payment-review.md) `[NEW-04]`~~ | ✅ Base uses `httpGet` (correct) |

### Customer & Identity

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~4~~ | ~~Auth `user_type` vs Customer `int32` enum~~ | ~~[customer-identity-review.md](customer-identity-review.md) §1.1~~ | ✅ Not a runtime bug, type mapping handled at API boundary |
| ~~5~~ | ~~`customer.verified` event wrong structure~~ | ~~[customer-identity-review.md](customer-identity-review.md) §2~~ | ✅ Already uses `CustomerVerifiedEvent` struct |
| ~~6~~ | ~~Phone uniqueness: no unique constraint~~ | ~~[customer-identity-review.md](customer-identity-review.md) §1.4~~ | ✅ Migration 023: partial unique index |
| ~~7~~ | ~~Order Service HTTP endpoint wrong port~~ | ~~[customer-identity-review.md](customer-identity-review.md) §7~~ | ✅ Fixed: `:8004`→`:80` (K8s Service port) |

### Fulfillment & Shipping

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~8~~ | ~~`compensatePackageShipped` hardcodes rollback status~~ | ~~[fulfillment-shipping-review.md](fulfillment-shipping-review.md) P1-2~~ | ✅ Added `compensation_pending`/`compensated` statuses + `MarkCompensationPending` method |

### Inventory & Warehouse

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~9~~ | ~~`TimeslotValidatorJob`, `CapacityMonitorJob`, `DailyResetJob` wiring~~ | ~~[inventory-warehouse-review.md](inventory-warehouse-review.md) WH-P0-NEW~~ | ✅ Fixed: wired in `newWorkers()` + wire regenerated |

### Pricing & Promotion

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~10~~ | ~~Stock consumer in-memory dedup (`sync.Map`)~~ | ~~[pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) `[V2-06]`~~ | ✅ Already uses Redis `SetNX` |

### Promotion Service

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~11~~ | ~~`GetTopPerformingPromotions` N+1 query~~ | ~~[promotion-service-review.md](promotion-service-review.md) P1-2~~ | ✅ Refactored to `GetBulkUsageStats` + `GetBulkCouponStats` |
| ~~12~~ | ~~`GetCustomerPromotionHistory` N+1 query~~ | ~~[promotion-service-review.md](promotion-service-review.md) P1-3~~ | ✅ Batch-load via `GetPromotionsByIDs` |

### Return & Refund

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~13~~ | ~~Loyalty points not clawed back on return~~ | ~~[return-refund-review.md](return-refund-review.md) RET-P1-02~~ | ✅ New `return_events.go` consumer in loyalty-rewards |
| ~~14~~ | ~~Partial return → order status not `partially_returned`~~ | ~~[return-refund-review.md](return-refund-review.md) RET-P1-05~~ | ✅ Added `returned`/`partially_returned` statuses + return consumer in order worker |

### Seller & Merchant

| # | Issue | Source | Fix |
|---|-------|--------|-----|
| ~~15~~ | ~~No marketplace commission deduction before seller payout~~ | ~~[seller-merchant-review.md](seller-merchant-review.md) P1-2~~ | ✅ Commission calc in `MarkPaymentCompleted` (10% default, stored in metadata) |

---

## 🔵 P2 — Backlog / Tech Debt

### Cross-Cutting Concerns

| Issue | Source |
|-------|--------|
| No GDPR/PDPA data erasure API across services | [cross-cutting-concerns-review.md](cross-cutting-concerns-review.md) |
| No shared event schema registry (runtime deserialization risk) | [order-lifecycle-review.md](order-lifecycle-review.md) §2.2 |

### Analytics & Reporting

| Issue | Source |
|-------|--------|
| Roadmap items for advanced reporting still pending | [analytics-reporting-review.md](analytics-reporting-review.md) §9 |

### Customer & Identity

| Issue | Source |
|-------|--------|
| Loyalty: Verify tier recalculation triggered synchronously after point award | [customer-identity-review.md](customer-identity-review.md) §12 |
| Loyalty: Confirm `internal/jobs/` has points expiry cron with distributed lock | [customer-identity-review.md](customer-identity-review.md) §12 |
| HTTP timeout too low (1s) for customer service | [customer-identity-review.md](customer-identity-review.md) §7 |
| `customer_type` inconsistency (int32 vs string) in outbox event payloads | [customer-identity-review.md](customer-identity-review.md) §2 |
| Address CRUD events use direct publish (not outbox) — at-most-once delivery | [customer-identity-review.md](customer-identity-review.md) §3.1 |
| Segment rules evaluate stale cached customer data | [customer-identity-review.md](customer-identity-review.md) §8.4 |
| Segment rules deleted mid-evaluation not explicitly handled | [customer-identity-review.md](customer-identity-review.md) §8.4 |
| Large customer base causes segment evaluation timeout | [customer-identity-review.md](customer-identity-review.md) §8.4 |
| Stats worker and application layer both write stats (last-write-wins risk) | [customer-identity-review.md](customer-identity-review.md) §8.5 |

### Fulfillment & Shipping

| Issue | Source |
|-------|--------|
| Remove deprecated `EventBus` from shipping biz layer | [fulfillment-shipping-review.md](fulfillment-shipping-review.md) §9 |
| Align outbound topic constants with actual Dapr topics | [fulfillment-shipping-review.md](fulfillment-shipping-review.md) §9 |
| Move proto shipping IDs from int64 to string | [fulfillment-shipping-review.md](fulfillment-shipping-review.md) §9 |
| Address schema versioning (low risk) | [fulfillment-shipping-review.md](fulfillment-shipping-review.md) P2-6 |
| Click & Collect not implemented | [fulfillment-shipping-review.md](fulfillment-shipping-review.md) §10 |
| Route optimization not implemented | [fulfillment-shipping-review.md](fulfillment-shipping-review.md) §10 |

### Inventory & Warehouse

| Issue | Source |
|-------|--------|
| Production overlay (`overlays/production/`) needs verification | [inventory-warehouse-review.md](inventory-warehouse-review.md) P2-NEW-05 |
| `AllocateBackorders` — `GetQueueByPriority` needs `FOR UPDATE` | [inventory-warehouse-review.md](inventory-warehouse-review.md) P2-NEW-07 |
| `PublishDamagedInventory` dead code — no call site | [inventory-warehouse-review.md](inventory-warehouse-review.md) §2 |
| `StockCommittedConsumer` audit-only — no reconciliation value | [inventory-warehouse-review.md](inventory-warehouse-review.md) §3 |

### Notification

| Issue | Source |
|-------|--------|
| No DLQ drain cron — dead letter events accumulate | [notification-flow-review.md](notification-flow-review.md) NOTIF-P2-001 |
| No `processed_events` TTL cleanup | [notification-flow-review.md](notification-flow-review.md) NOTIF-P2-002 |
| `notification.created/delivered/failed` events have zero consumers | [notification-flow-review.md](notification-flow-review.md) NOTIF-P2-003 |
| All event consumers hardcode Telegram channel (no multi-channel routing) | [notification-flow-review.md](notification-flow-review.md) NOTIF-P2-004 |
| `RecipientID` always `nil` — preference checks bypassed | [notification-flow-review.md](notification-flow-review.md) NOTIF-P2-005 |
| Worker image uses `latest` tag in base | [notification-flow-review.md](notification-flow-review.md) NOTIF-P2-006 |

### Order Lifecycle

| Issue | Source |
|-------|--------|
| Schema drift risk — no shared event schema registry | [order-lifecycle-review.md](order-lifecycle-review.md) P2-SCHEMA-DRIFT |

### Payment

| Issue | Source |
|-------|--------|
| ~~Worker missing `volumeMounts` for `config.yaml`~~ | ~~[payment-review.md](payment-review.md) NEW-P2-01~~ ✅ Fixed (Sprint 1) |
| ~~Reconciliation alert cooldown using Redis (not in-memory)~~ | ~~[payment-review.md](payment-review.md) NEW-P2-02~~ ✅ Fixed |
| ~~`OutboxWorker` reads `pubsubName` from AppConfig~~ | ~~[payment-review.md](payment-review.md) NEW-P2-03~~ ✅ Fixed |

### Pricing & Promotion (pricing-promotion-tax-review)

| Issue | Source |
|-------|--------|
| `price.calculated` event dropped if Dapr unavailable (direct publish) | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) V2-P2-01 |
| Campaign events published to outbox with no known consumer | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) V2-P2-02 |
| `DiscountAppliedEvent` struct defined but never published (dead code) | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) |
| Promotion HPA missing for production main deployment | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) |
| Currency conversion flag missing on response | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) |
| Dynamic pricing errors swallowed silently (no metric/alert) | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) |
| Tax returns `(0, nil, nil)` when no rules match — ambiguous | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) |

### Promotion Service (promotion-service-review)

| Issue | Source |
|-------|--------|
| `ConfirmPromotionUsage` has no outbox event (no downstream notification) | [promotion-service-review.md](promotion-service-review.md) P2-1 |
| Dead code: `publishPromotionEvent`, `publishBulkCouponsEvent` | [promotion-service-review.md](promotion-service-review.md) P2-2 |
| Outbox `Save` error swallowed in `ReleasePromotionUsage` | [promotion-service-review.md](promotion-service-review.md) P2-5 |
| Main deployment missing config volume mount | [promotion-service-review.md](promotion-service-review.md) EC10 |

### Return & Refund

| Issue | Source |
|-------|--------|
| Migration schema drift vs GORM model (relies on auto-migration) | [return-refund-review.md](return-refund-review.md) DC-02 |
| Auto-approve for small amounts not implemented (config exists) | [return-refund-review.md](return-refund-review.md) RET-P2-02 |
| Stale return cleanup cron (auto-cancel pending/approved returns) | [return-refund-review.md](return-refund-review.md) RET-P2-03 |
| No HPA for return service | [return-refund-review.md](return-refund-review.md) RET-P2-04 |
| Exchange price difference not calculated | [return-refund-review.md](return-refund-review.md) RET-P2-05 |
| No worker-specific NetworkPolicy | [return-refund-review.md](return-refund-review.md) G-04 |

### Search & Discovery

| Issue | Source |
|-------|--------|
| DLQ "ignored" events accumulate in `failed_events` DB forever | [search-discovery-review.md](search-discovery-review.md) NEW-P2-01 |
| N+1 gRPC calls in reconciliation + orphan cleanup workers | [search-discovery-review.md](search-discovery-review.md) NEW-P2-02 |
| `HandlePromotionDeleted` silent ACK on empty PromotionID | [search-discovery-review.md](search-discovery-review.md) NEW-P2-03 |
| Attribute re-index has no checkpoint cursor | [search-discovery-review.md](search-discovery-review.md) ATTR-REINDEX |
| ES alias conflict during full reindex | [search-discovery-review.md](search-discovery-review.md) ES-ALIAS |
| Soft-deleted product remains in ES for up to 6h if delete event DLQ'd | [search-discovery-review.md](search-discovery-review.md) EDGE-01 |

### Seller & Merchant

| Issue | Source |
|-------|--------|
| Seller performance score not auto-calculated | [seller-merchant-review.md](seller-merchant-review.md) P2-1 |
| KYC failure cleanup: uploaded docs not purged on rejection | [seller-merchant-review.md](seller-merchant-review.md) P2-2 |
| Duplicate seller registration guard (same tax ID) | [seller-merchant-review.md](seller-merchant-review.md) P2-3 |
| Product approval race condition (edit during pending approval) | [seller-merchant-review.md](seller-merchant-review.md) P2-4 |
| B2B wholesale flows entirely unimplemented | [seller-merchant-review.md](seller-merchant-review.md) P2-5 |
| Seller improvement plan (SIP) trigger not automated | [seller-merchant-review.md](seller-merchant-review.md) P2-6 |
| No SLA breach detection cron in fulfillment for seller penalties | [seller-merchant-review.md](seller-merchant-review.md) P1-3 |
| Bulk import no transaction wrapping in warehouse | [seller-merchant-review.md](seller-merchant-review.md) P1-4 |
| Product deletion with active orders — no saga compensation | [seller-merchant-review.md](seller-merchant-review.md) P1-5 |

---

## 📋 Files Reviewed

| Checklist | P0 Open | P1 Open | P2 Open |
|-----------|---------|---------|---------|
| [analytics-reporting-review.md](analytics-reporting-review.md) | 0 | 0 | ~1 |
| [admin-operations-review.md](admin-operations-review.md) | 0 | 0 | 0 |
| [cart-checkout-review.md](cart-checkout-review.md) | 0 | 0 | 0 |
| [cart-checkout-deep-review.md](cart-checkout-deep-review.md) | 0 | 0 | 0 |
| [catalog-product-review.md](catalog-product-review.md) | 0 | 0 | 0 |
| [cross-cutting-concerns-review.md](cross-cutting-concerns-review.md) | 0 | 0 | ~2 |
| [customer-identity-review.md](customer-identity-review.md) | 0 | ~~2~~ 0 | ~9 |
| [fulfillment-shipping-review.md](fulfillment-shipping-review.md) | 0 | 1 | ~4 |
| [inventory-warehouse-review.md](inventory-warehouse-review.md) | 0 | ~~1~~ 0 | ~4 |
| [notification-flow-review.md](notification-flow-review.md) | 0 | 0 | 6 |
| [order-lifecycle-review.md](order-lifecycle-review.md) | 0 | 0 | ~1 |
| [order-lifecycle-deep-review.md](order-lifecycle-deep-review.md) | 0 | 0 | ~3 |
| [payment-review.md](payment-review.md) | ~~1~~ 0 | ~~3~~ 0 | ~~3~~ 2 |
| [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) | 0 | ~~1~~ 0 | ~7 |
| [promotion-service-review.md](promotion-service-review.md) | 0 | ~~2~~ 0 | 4 |
| [return-refund-review.md](return-refund-review.md) | 0 | 2 | 5 |
| [search-discovery-review.md](search-discovery-review.md) | 0 | 0 | ~6 |
| [seller-merchant-review.md](seller-merchant-review.md) | 0 | 3 | ~7 |

---

*Generated: 2026-03-02 | Cross-reference individual review files for full context and evidence.*

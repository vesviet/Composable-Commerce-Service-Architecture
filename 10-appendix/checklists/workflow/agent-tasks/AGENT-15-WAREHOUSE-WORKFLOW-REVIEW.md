# AGENT-15: Warehouse Workflow Review - Data Consistency, Event Topology, Worker, and GitOps

> **Created**: 2026-03-28
> **Priority**: P0 (event topology / consistency) + P1 (worker hardening / cleanup)
> **Sprint**: Architecture Hardening Sprint
> **Services**: `warehouse`, `order`, `payment`, `fulfillment`, `pricing`, `catalog`, `gitops`
> **Estimated Effort**: 2-4 days
> **Source**: Deep static code review of warehouse-related workflows

---

## Overview

This review follows mature marketplace patterns used in large commerce systems:

- clear domain ownership
- minimal event surface
- transactional outbox for cross-service delivery
- idempotent consumers
- compensation paths that are actually consumed
- no ambiguous "best effort" stock transitions

Current conclusion:

- The repository already has a solid Outbox foundation in `warehouse`, `order`, and `fulfillment`.
- However, several workflow contracts are inconsistent across services.
- There are real data mismatch windows around reservation lifecycle and stock commitment.
- Some published events do not have real consumers.
- `warehouse` GitOps topic wiring is currently drifted from the actual event contracts.
- Worker registration is fragile if the deployment is ever split by mode.

---

## Summary of Key Findings

### P0 Findings

1. `warehouse` subscribes to the wrong fulfillment and return topics in local config and GitOps overlays.
2. `inventory.stock.committed` does not actually confirm reservations in `warehouse`; it extends TTL or re-reserves instead.
3. `warehouse` uses an hourly stock reconciliation cron to repair `quantity_reserved` drift caused by the gap above.
4. `order` publishes `inventory.release.requested`, `payment.refund.requested`, and `payment.capture_requested`, but the target services do not have matching real consumers in the current codebase.

### P1 Findings

5. Reservation expiry releases stock even if the outbox event cannot be written, which can leave `order` out of sync.
6. `pricing` consumes a stock payload schema that does not match what `warehouse` publishes.
7. `order` cleanup can clear `reservation_id` even when the warehouse release operation fails.
8. Return restocking may choose the wrong warehouse when `warehouse_id` is missing in event metadata.
9. Worker mode routing relies on worker name substrings instead of explicit worker type.
10. `catalog.product.created` is currently subscribed by `warehouse`, but the handler only logs and does not produce a meaningful business effect.

---

## Checklist - P0 Issues (Must Fix)

### [ ] Task 1: Fix `warehouse` topic drift for fulfillment and return events

**Files**:

- `warehouse/configs/config.yaml`
- `gitops/apps/warehouse/overlays/dev/configmap.yaml`
- `gitops/apps/warehouse/overlays/production/configmap.yaml`

**Risk**: `warehouse` may not receive fulfillment completion/cancellation events or completed return events in deployed environments.

**Problem**:

- Config uses `fulfillment.status.changed`
- Real fulfillment publisher uses `fulfillments.fulfillment.status_changed`
- Config uses `return.completed`
- Real return topic is `orders.return.completed`

**Fix**:

- Replace:
  - `fulfillment.status.changed` -> `fulfillments.fulfillment.status_changed`
  - `return.completed` -> `orders.return.completed`
- Align README and all local/docker configs to the same contract.

**Validation**:

```bash
rg -n "fulfillment.status.changed|return.completed" warehouse gitops/apps/warehouse
rg -n "fulfillments.fulfillment.status_changed|orders.return.completed" warehouse fulfillment payment
```

---

### [ ] Task 2: Decide the authoritative semantics of `inventory.stock.committed`

**Files**:

- `order/internal/biz/order/update.go`
- `warehouse/internal/data/eventbus/stock_committed_consumer.go`
- `warehouse/internal/observer/order_status_changed/warehouse_sub.go`
- `warehouse/internal/worker/cron/stock_reconciliation_job.go`

**Risk**: Reserved stock drifts from the real reservation table and the system depends on cron repair instead of a correct transaction boundary.

**Problem**:

- `order` publishes `inventory.stock.committed` when status moves to `confirmed`.
- `warehouse` consumer does not call `ConfirmReservation`.
- `warehouse` order-status reconciliation also extends active reservations instead of resolving the commitment transition.
- Hourly reconciliation exists specifically to repair `quantity_reserved` drift.

**Decision required**:

Choose one model and remove the other:

1. **Payment-confirmed commits logical stock**
   - `inventory.stock.committed` must call `ConfirmReservation` or an equivalent atomic transition.
   - `orders.order.status_changed=confirmed` becomes informational only.

2. **Fulfillment shipped/completed commits physical stock**
   - Remove or rename `inventory.stock.committed`.
   - Keep only fulfillment-driven `ConfirmReservation`.
   - Do not pretend the order-confirmed event "commits" stock.

**Recommendation**:

Use model 2 unless the business explicitly needs a distinct "payment secured inventory ownership" state. That is the cleaner marketplace pattern for multi-step warehouse execution.

**Validation**:

```bash
cd warehouse && go test ./internal/data/eventbus/... ./internal/worker/cron/... ./internal/biz/inventory/... -v
cd order && go test ./internal/biz/order/... -v
```

---

### [ ] Task 3: Remove or implement orphan Saga events

**Files**:

- `order/internal/biz/order/cancel.go`
- `order/internal/biz/order/process.go`
- `payment/internal/worker/event/event_consumer_worker.go`
- `warehouse/cmd/worker/wire.go`

**Risk**: Saga steps look implemented on paper, but compensations never execute.

**Published without real target consumers**:

- `inventory.release.requested`
- `payment.refund.requested`
- `payment.capture_requested`

**Fix**:

Choose one of these paths for each topic:

1. Implement a real consumer in the owning service and add integration tests.
2. Remove the event and replace it with the domain event that is actually consumed.
3. Collapse the flow into an existing authoritative event if the extra topic is redundant.

**Recommendation**:

- Do not keep topics that are not part of a live topology.
- Event contracts should exist only when ownership, subscriber, retry, DLQ, and idempotency are all real.

**Validation**:

```bash
rg -n "inventory\.release\.requested|payment\.refund\.requested|payment\.capture_requested" order payment warehouse fulfillment
```

---

### [ ] Task 4: Align documentation and workflow language with actual behavior

**Files**:

- `warehouse/README.md`
- `warehouse/configs/config.yaml`
- `warehouse/configs/config-docker.yaml`

**Risk**: Engineers and QA follow outdated event names and outdated stock semantics.

**Problem**:

- README still documents outdated topics and partially outdated behavior.
- Config files disagree with code and GitOps.

**Fix**:

- Update consumed-event tables
- Update workflow diagrams
- Update "stock committed" wording so it matches real business semantics

---

## Checklist - P1 Issues (Fix In Sprint)

### [ ] Task 5: Make reservation expiry compensation durable

**Files**:

- `warehouse/internal/biz/reservation/reservation.go`

**Risk**: Stock is released, but `order` may never receive `warehouse.inventory.reservation_expired`.

**Problem**:

- `ExpireReservation` and `BulkExpireReservations` log outbox write failures and still commit.

**Fix options**:

1. Fail the transaction if `reservation_expired` outbox cannot be saved.
2. Persist a durable failed-compensation record and sweep it with a worker.
3. Emit an operational alert plus retryable reconciliation job for missing reservation-expired events.

**Recommendation**:

Prefer option 1 unless the business explicitly wants stock release to win over order consistency.

---

### [ ] Task 6: Fix `pricing` stock event contract mismatch

**Files**:

- `warehouse/internal/biz/events/events.go`
- `pricing/internal/observer/stock_updated/stock_updated_sub.go`
- `pricing/internal/data/eventbus/stock_consumer.go`

**Risk**: Dynamic pricing reacts to wrong stock values or zero values.

**Problem**:

- `warehouse` publishes fields like `sku`, `available_stock`, `quantity_available`
- `pricing` expects `sku_id`, `available_for_sale`, `in_stock`

**Fix**:

- Standardize the payload schema
- Add contract tests between publisher and consumer
- Reject mismatched payloads in schema validation instead of silently warning

**Validation**:

```bash
cd pricing && go test ./internal/data/eventbus/... ./internal/observer/stock_updated/... -v
cd warehouse && go test ./internal/biz/events/... -v
```

---

### [ ] Task 7: Stop clearing `reservation_id` in `order` when release fails

**Files**:

- `order/internal/worker/cron/reservation_cleanup.go`

**Risk**: Order data becomes "clean" while warehouse still holds reserved stock.

**Fix**:

- Only clear `reservation_id` after confirmed successful warehouse release
- If release fails, keep the ID and store a retryable compensation record

---

### [ ] Task 8: Remove ambiguous warehouse fallback on return restock

**Files**:

- `warehouse/internal/biz/inventory/inventory_events.go`

**Risk**: Returned inventory can be restocked into the wrong warehouse in multi-warehouse setups.

**Fix**:

- Require `warehouse_id` in return-completed events
- Fail the consumer if the field is missing
- Add integration tests covering multi-warehouse returns

---

### [ ] Task 9: Replace name-based worker classification with explicit worker type

**Files**:

- `warehouse/cmd/worker/main.go`
- `common/worker/app.go`

**Risk**: If deployment later uses `-mode cron` or `-mode event`, workers can silently disappear because their names do not match the string convention.

**Problem**:

- Current routing depends on `strings.Contains(name, "-cron")`
- Many cron workers are named `stock-reconciliation`, `reservation-cleanup`, `daily-summary`, etc.
- Current GitOps runs default mode `all`, so the risk is latent but real

**Fix**:

- Add an explicit worker category or interface
- Stop inferring worker type from the worker name

---

### [ ] Task 10: Re-evaluate `catalog.product.created` subscription in `warehouse`

**Files**:

- `warehouse/internal/observer/product_created/warehouse_sub.go`
- `warehouse/cmd/worker/wire.go`

**Risk**: Extra subscriptions create noise, false confidence, and operational overhead without business value.

**Problem**:

- The current handler only logs that inventory must be created manually.

**Fix**:

Choose one:

1. Remove the subscription entirely.
2. Keep it but convert it into a real workflow:
   - auto-create warehouse placeholders
   - create inventory tasks for operations
   - emit an actionable admin notification

**Recommendation**:

Remove it unless the business is ready to automate initial inventory provisioning.

---

## Target Event Topology

### Keep

- `orders.order.status_changed`
- `fulfillments.fulfillment.status_changed`
- `orders.return.completed`
- `warehouse.inventory.stock_changed`
- `warehouse.inventory.reservation_expired`

### Keep only if semantics are fixed

- `inventory.stock.committed`

### Remove or implement fully

- `inventory.release.requested`
- `payment.refund.requested`
- `payment.capture_requested`
- `warehouse.reservation.confirm`
- `warehouse.reservation.release`
- `warehouse.stock.adjust`

---

## Warehouse Worker Snapshot

### Current consumers wired into `warehouse` worker

- `orders.order.status_changed`
- `catalog.product.created`
- `catalog.product.deleted`
- `fulfillments.fulfillment.status_changed`
- `orders.return.completed`
- `inventory.stock.committed`

### Current background jobs wired into `warehouse` worker

- `StockChangeDetectorJob`
- `AlertCleanupJob`
- `OutboxCleanupJob`
- `DailySummaryJob`
- `WeeklyReportJob`
- `DailyResetJob`
- `CapacityMonitorJob`
- `TimeSlotValidatorJob`
- `StockReconciliationJob`
- `ReservationCleanupJob`
- `ReservationWarningWorker`
- common `OutboxWorker`

### Current GitOps worker mode

- Default worker command does **not** pass `-mode`
- Effective mode is `all`
- That reduces the immediate production impact of name-based routing, but does not remove the design bug

---

## Pre-Commit Validation Checklist

```bash
# Config and topology
rg -n "fulfillment.status.changed|return.completed" warehouse gitops/apps/warehouse
rg -n "inventory\.release\.requested|payment\.refund\.requested|payment\.capture_requested" order payment warehouse fulfillment

# Warehouse
cd warehouse && go test ./internal/data/eventbus/... ./internal/biz/... ./internal/worker/... -v

# Order
cd order && go test ./internal/biz/order/... ./internal/data/eventbus/... ./internal/worker/... -v

# Payment
cd payment && go test ./internal/data/eventbus/... ./internal/worker/... -v

# Pricing
cd pricing && go test ./internal/data/eventbus/... ./internal/observer/... -v

# GitOps
kubectl kustomize gitops/apps/warehouse/overlays/dev > /dev/null
kubectl kustomize gitops/apps/warehouse/overlays/production > /dev/null
```

---

## Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| `warehouse` consumes the correct fulfillment topic | fulfillment event reaches warehouse consumer in dev/prod | |
| `warehouse` consumes the correct return topic | return completed event reaches warehouse consumer in dev/prod | |
| No orphan saga topics remain | every published topic has a real consumer and test coverage | |
| `quantity_reserved` does not rely on hourly repair | reconciliation job reports zero drift under normal flows | |
| `pricing` reads correct stock payload fields | stock update integration test passes with real warehouse payload | |
| Order cleanup no longer hides failed stock releases | reservation IDs remain until warehouse release succeeds | |
| Return restock is deterministic by warehouse | missing `warehouse_id` causes explicit failure, not fallback | |
| Worker mode split is safe | `-mode cron` and `-mode event` both register the intended workers | |


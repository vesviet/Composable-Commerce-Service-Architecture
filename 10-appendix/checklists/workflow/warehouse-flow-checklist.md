# Warehouse & Inventory Flow Review Checklist

## Status Legend
- 🔴 **P0 (Critical)**: Data loss, stock inflation, system crash, or preventing core flows.
- 🟡 **P1 (High)**: Event loss, missing retries, edge case failures, minor data inconsistency.
- 🔵 **P2 (Medium)**: Observability gaps, duplicate code, suboptimal config.
- 🟢 **Resolved**: Issue has been fixed.

## 1. Fulfillment Cancellation Inflates Stock 🔴 (P0)
**Issue**: When a fulfillment is cancelled from a `pending` state, `HandleFulfillmentStatusChanged` blindly creates an `InboundTransaction` (which increments physical `quantity_available`) AND releases the reservation (which decrements `quantity_reserved`), effectively creating phantom stock that never existed.
**Fix**:
- In `handleFulfillmentCancelled` (in `inventory/fulfillment_status_handler.go`), ONLY release the reservation if the old status was `pending` or `planning`. Only create an `InboundTransaction` if physical stock was actually deducted (e.g., cancelling from `completed`).
- Add tests to verify that `quantity_available` does not increase when cancelling a `pending` fulfillment.
**Status**: [ ]

## 2. Event Loss in Damaged Item Tracking 🟡 (P1)
**Issue**: When processing a return with a damaged item, `trackDamagedItem` (in `inventory/inventory_return.go`) calls `uc.eventPublisher.PublishDamagedInventory(txCtx, event)`. If this direct publish fails, the event is silently lost (logged as a warning), causing downstream subscribers to miss the damage report.
**Fix**:
- Replace the direct publish with the Transactional Outbox pattern, identical to the pattern used in `restoreSellableItem` right above it.
- Marshal the `DamagedInventoryEvent` and save it to the outbox table within the same database transaction.
**Status**: [ ]

## 3. Worker Configuration Verification 🟢
**Context**: The `warehouse-worker-deployment.yaml` needs correct Dapr annotations and environment variables for consumers and cron jobs to operate.
**Verification**:
- `Dapr` annotations match worker port `5005` with `app-protocol: grpc`.
- Environment variables `WORKER_MODE=true`, `ENABLE_CRON=true`, and `ENABLE_CONSUMER=true` are correctly set.
**Status**: [X]

## 4. Saga & Event Subscriptions 🟢
**Context**: Checking if the warehouse service listens to relevant events and implements at-least-once delivery for compensations.
**Verification**:
- Warehouse subscribes to `fulfillment.status_changed`, `order.status_changed`, `return.completed`, `catalog.product_created`.
- Outbox pattern is used correctly for `warehouse.inventory.stock_changed`.
- Handlers return `error`s when appropriate, allowing Dapr to retry.
**Status**: [X]

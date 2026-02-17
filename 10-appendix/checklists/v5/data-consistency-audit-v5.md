# 🔗 Data Consistency Audit — Cross-Service Checklist

> **Date**: 2026-02-16 | Part of v5 system review

---

## Dual-Write Issues (Non-Transactional)

- [x] **P0** — `order/biz/order/payment.go` — `AddPayment` creates payment record + updates order status in two separate writes ✅ *Wrapped in `WithTransaction`*
- [x] **P0** — `order/biz/order/process.go` — `ProcessOrder` updates status + creates history + publishes event without transaction ✅ *Wrapped in `WithTransaction`*
- [x] **P1** — `order/biz/order/create.go:369` — `publishStockCommittedEvent` outbox write happens outside main transaction ✅ *Now returns errors with CRITICAL logging*

## Partial Failure / Stock Leaks

- [x] **P0** — `order/biz/order/create.go:323-341` — `confirmOrderReservations` has no rollback for already-confirmed items on partial failure ✅ *Rollback implemented + "failed" status*
- [x] **P1** — `order/biz/order/cancel.go:52-54` — Failed reservation release during cancel only logged, not DLQ'd ✅ *`writeReservationReleaseDLQ` via outbox*
- [x] **P1** — `checkout/biz/checkout/confirm.go` — SAGA-001 void failure only logged, no DLQ ✅ *Already implemented: `FailedCompensation` record at lines 315-346*

## Missing Event Consumers

- [x] **P1** — Promotion service missing `order.cancelled` consumer → coupons not restored ✅ *Already implemented: `ReleasePromotionUsage` in `order_consumer.go`*
- [x] **P1** — Fulfillment service missing `order.cancelled` consumer → fulfillment not stopped ✅ *Already implemented: `CancelFulfillment` in `order_status_handler.go`*
- [ ] **P0** — Return service events are all stubs → `return.approved` not consumed by payment/warehouse

## Outbox Pattern Gaps

- [ ] **P1** — Checkout service has outbox table but unclear if worker processes it
- [ ] **P1** — Customer service outbox worker status unclear
- [ ] **P1** — Loyalty service outbox worker status unclear
- [ ] **P2** — Return service outbox exists but events are stubs

## Race Conditions

- [ ] **P1** — No optimistic locking on order status updates → concurrent consumers may race
- [ ] **P2** — Checkout idempotency lock TTL (5 min) may expire during long checkouts
- [ ] **P2** — Reservation extended during checkout but stock sold before order created

## JSON Contract Issues

- [x] **P2** — `ShipmentDeliveredEvent` uses PascalCase JSON tags (`ShipmentID`, `OrderID`) while all other events use snake_case (`shipment_id`, `order_id`) ✅ *Dual-decode: snake_case primary + PascalCase legacy fallback*

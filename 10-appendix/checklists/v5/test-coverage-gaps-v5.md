# 🧪 Test Coverage Gaps — Checklist

> **Date**: 2026-02-16 | Part of v5 system review

---

## Order Service — `order/internal/biz/order/`

### P0 — Must Write

- [x] `TestCreateOrder_FullFlow` — Real test with DI (current tests are `assert.True(t, true)` placeholders) ✅ *`TestCreateOrder_Success` + 7 more*
- [x] `TestCreateOrder_OutboxTransactionAtomicity` — Verify outbox event saved in same TX as order ✅ *Covered in `TestCreateOrder_Success`*
- [x] `TestCreateOrder_StockConfirmFailure_RollbackToFailed` — Verify status → "failed" on confirm error ✅
- [x] `TestCreateOrder_PartialStockConfirm_Rollback` — 3/5 items confirmed → first 2 rolled back ✅ *`TestConfirmOrderReservations_PartialFailure_Rollback`*
- [x] `TestAddPayment_TransactionConsistency` — Payment record + order status updated atomically ✅ *3 payment tests*
- [x] `TestPaymentConsumer_HandlePaymentCaptureRequested` — Complex flow: stock + capture + events ✅ *6 existing tests: CaptureRetry, AuthExpired, CaptureFails, etc.*

### P1 — Should Write

- [x] `TestProcessOrder_PendingToProcessing` — Happy path ✅ *`TestProcessOrder_Success`*
- [x] `TestProcessOrder_InvalidStatus` — Non-pending order rejected ✅
- [x] `TestProcessOrder_DBError` — Database failure path ✅ *`TestProcessOrder_DatabaseError`*
- [x] `TestCancelOrder_ReservationReleaseFailed` — Verify retry mechanism works ✅ *`TestCancelOrder_ReservationReleaseFailed_DLQWritten`*
- [x] `TestCreateOrder_NilMetadataMap` — Panics guard for metadata write ✅ *`TestCreateOrder_NilMetadata_NoPanic`*

## Order Event Consumers — `order/internal/data/eventbus/`

### P0 — Must Write

- [x] `TestPaymentConsumer_HandlePaymentConfirmed` — Status transition + idempotency ✅ *`TestPaymentConsumer_HandlePaymentConfirmed_UpdatesStatus`*
- [x] `TestPaymentConsumer_HandlePaymentFailed_WithDLQ` — Reservation release + DLQ on failure ✅ *`TestPaymentConsumer_HandlePaymentFailed_UpdatesStatusAndReleases` + `_WarehouseReleaseFails_DLQ`*
- [x] `TestFulfillmentConsumer_BackwardTransition` — `isLaterStatus` blocks regression ✅ *`TestFulfillment_BackwardTransition_Skipped`*
- [ ] `TestFulfillmentConsumer_StatusMapping` — All fulfillment → order status mappings
- [x] `TestShippingConsumer_PascalCaseJSON` — Verify deserialization with mixed casing ✅ *`TestShipping_PascalCase_DualDecode`*
- [x] `TestWarehouseConsumer_ReservationExpiry` — Auto-cancel for pending order ✅ *`TestWarehouse_ReservationExpiry_CancelsPendingOrder`*

## Checkout Service — `checkout/internal/biz/checkout/`

### P0 — Must Write

- [x] `TestConfirmCheckout_SagaRollback_VoidOnFailure` — Payment void when order creation fails ✅ *`TestConfirmCheckout_OrderCreationFails_VoidsPayment` in confirm_p0_test.go*
- [ ] `TestConfirmCheckout_IdempotencyLockExpiry` — 5-min TTL edge case
- [x] `TestConfirmCheckout_DuplicateRequest` — Lock already held → returns cached result ✅ *`TestConfirmCheckout_ConcurrentDuplicate` + `_IdempotentReturnsCachedOrder` in confirm_p0_test.go*

## Shipping Service — `shipping/internal/biz/`

### P1 — Should Write

- [ ] `TestShipmentBizLayer` — No biz tests exist at all (0 files found)

## Return Service — `return/internal/biz/return/`

### P0 — Blocked on Implementation

- [ ] Tests exist but cover stubs — all functions return nil
- [ ] Unblock: implement `processReturnRefund`, `restockReturnedItems`, `processExchangeOrder` first

---

## Test Pattern Fixes

- [x] Replace all `assert.True(t, true, "Placeholder")` in `create_test.go` with real tests ✅ *8 real create tests*
- [ ] Add `mock.AssertExpectations(t)` consistently (some tests use `AssertCalled` only)
- [ ] Convert `create_test.go` tests to table-driven format
- [x] Add event consumer unit tests (none exist in `data/eventbus/`) ✅ *8 consumer tests in fulfillment_shipping_test.go*

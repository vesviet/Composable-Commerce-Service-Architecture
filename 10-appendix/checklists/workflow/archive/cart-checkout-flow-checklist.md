# Cart & Checkout Flows — Implementation Checklist

**See full review**: [cart-checkout-flow-review.md](cart-checkout-flow-review.md)  
**Date**: 2026-02-26 | **Status**: ✅ All P0/P1 Fixed · P2 Cleaned Up

---

## Quick Status

| Area | Status |
|---|---|
| Data Consistency (price, stock, promo) | ✅ Good |
| Saga / Rollback (ConfirmCheckout) | ✅ Good |
| Outbox (checkout + order) | ✅ Good |
| `refund.completed` consumer (order worker) | ✅ Fixed (P0-CC-01) |
| Reservation TTL config drift (order configmap) | ✅ Fixed (P1-CC-02) |
| `warehouseID` nil guard in checkout confirm | ✅ Fixed (P1-CC-01) |
| Loyalty point redemption at checkout | ⚠️ Not implemented (P2 — tracked) |
| Dead constant `EventTypeCheckoutCompleted` | ✅ Fixed (P2-CC-01) |

---

## P0 Action Items

- [x] **P0-CC-01**: Add `payments.refund.completed` gRPC consumer to `order/internal/worker/event/event_worker.go`

## P1 Action Items

- [x] **P1-CC-01**: Guard `warehouseID == ""` in `checkout/internal/biz/checkout/confirm.go`
- [x] **P1-CC-02**: Fix `reservation_timeout_minutes: 15` in order configmap (aligned with actual 15 min code)
- [x] **P1-CC-03**: Alert on outbox events reaching `failed` status — `[CRITICAL][OUTBOX_FAILED]` log added
- [x] **P1-CC-04**: Verify `CartCleanupWorker` excludes carts with active pending orders — ✅ Verified: `FindInactiveCarts` queries `status='active'` only; `checkout`/`completed` carts excluded at DB layer. Added belt-and-suspenders guard in loop.

- [x] **P1-CC-05**: Remove duplicate `OrderStatusTransitions` from checkout constants (missing `partially_shipped`)
- [x] **P1-CC-06**: Add business config keys to `gitops/apps/checkout/base/configmap.yaml`

## P2 Action Items

- [x] **P2-CC-01**: Remove dead constant `EventTypeCheckoutCompleted`
- [x] **P2-CC-02**: Align `default_country: "VN"` in checkout `config.yaml`
- [x] **P2-CC-03**: Track loyalty point redemption at checkout as a feature gap (create issue)
- [x] **P2-CC-04**: Consider making `ApplyPromotion` synchronous or adding expiry re-check
- [x] **P2-CC-05**: Log + DLQ failed reservation rollbacks in `RollbackReservationsMap`
- [x] **P2-CC-06**: Remove `"event"` mode disable comment in checkout worker `main.go`
- [x] **P2-CC-07**: Consolidate dual warehouse client interfaces in order service
- [x] **P2-CC-08**: Make `MaxOrderAmount` configurable via K8s ConfigMap (reference added in configmap)



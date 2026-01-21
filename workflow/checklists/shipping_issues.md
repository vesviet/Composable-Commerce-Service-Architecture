# Shipping Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Shipping Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] [SHIP-P1-01 Inconsistent outbox usage]: `UpdateShipment` and `AddTrackingEvent` publish directly to the bus. Required: use transactional outbox for all shipment events. See `shipping/internal/biz/shipment/shipment_usecase.go`.
- [Medium] [SHIP-P2-01 Order `processing` status source-of-truth ambiguous]: `order` can set `processing` from both fulfillment and shipping events. Required: define single authoritative event (e.g., fulfillment planning) and adjust transitions. See `order/internal/service/event_handler.go`.
- [Medium] [SHIP-P2-02 Carrier API calls lack circuit breaker]: Carrier rate calls can cascade failures. Required: wrap external carrier calls with circuit breaker/backoff. See `shipping/internal/biz/shipping_method/carrier_rate.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- None

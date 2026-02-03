# Workflow Checklist: Inventory Management

**Workflow**: Inventory Management (Operational Flows)
**Status**: Done
**Last Updated**: 2026-01-31
**Review**: See `docs/07-development/standards/workflow-review-inventory-management.md` (2026-01-31)

## 1. Documentation & Design
- [x] Stock tracking (receiving, monitoring, cache) documented
- [x] Reservations (order-based, TTL, release) documented
- [x] Allocations (fulfillment) documented
- [x] Sync to Catalog and Search documented
- [x] Low-stock alerts and multi-warehouse documented

## 2. Implementation Validation
- [x] Warehouse Service – stock, reservations, allocations, events
- [x] Event publishing (warehouse.*, inventory.*) and consumers (Catalog, Search, Order, Fulfillment)
- [x] Availability ownership (Catalog vs Warehouse vs Search) documented  
  _Ref:_ [inventory-data-ownership-adr.md](../../../05-workflows/integration-flows/inventory-data-ownership-adr.md) – ownership and event flow.
- [x] Reservation release on order cancel and payment failure verified  
  _Ref:_ [reservation-release-flows.md](../../../05-workflows/integration-flows/reservation-release-flows.md); Order: `order/internal/biz/order/cancel.go`, `order/internal/service/event_handler.go` HandlePaymentFailed.
- [x] Reservation vs allocation lifecycle (terminology) aligned in doc  
  _Ref:_ [inventory-data-ownership-adr.md](../../../05-workflows/integration-flows/inventory-data-ownership-adr.md) – terminology table and state machine.

## 3. Data Synchronization
- [x] Warehouse events consumed by Catalog/Search with idempotency (see Data Synchronization checklist)  
  _Event ID propagation:_ Outbox worker and consumers use `event_id` / CloudEvent `id` for idempotency.
- [x] Cache invalidation on stock change verified  
  _Catalog:_ invalidates product cache on `warehouse.inventory.stock_changed`; _Search:_ updates index and invalidates stock cache.

## 4. Observability & Testing
- [x] Stock accuracy and reservation metrics  
  _Reservation usecase records metrics_ (`RecordReservationOperation`) for reserve, release, confirm, complete, extend; stock accuracy via existing inventory/low-stock metrics.
- [x] Low-stock and sync lag alerts  
  _Ref:_ `argocd/infrastructure/warehouse-prometheus-alerts.yaml` – outbox lag, sync lag, reservation, low-stock; metrics aligned with alert rules.
- [x] Tests: reserve → confirm; reserve → expire; reserve → cancel  
  _Ref:_ `warehouse/internal/biz/reservation/reservation_lifecycle_test.go` – OrderCancel, PaymentFailure, TTLExpiration, ConfirmAndFulfill; all passing.

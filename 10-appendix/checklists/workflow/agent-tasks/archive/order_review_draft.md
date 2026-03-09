# Order Service - 10-Round Multi-Agent Meeting Review Notes

- [ ] Agent A (Architect): Focus on Saga orchestration (Order Create -> Payment -> Fulfillment), state machine integrity, and atomicity. Identify missing transactional boundaries (e.g. `WithTransaction`).
- [ ] Agent B (Security/Perf): Focus on N+1 queries in data loading, goroutine leaks, idempotency gaps in event consumers, and context propagation on gRPC calls.
- [ ] Agent C (Senior Go Dev): Focus on error discarding (`_ = err`), structured error returns (`status.FromError`), proper logging fields, and testability.
- [ ] Agent D (BA): Focus on edge cases. What happens if payment arrives before stock is reserved? What if shipping fails for 1 item out of 5? Are order statuses (pending, processing, confirmed, partly shipped) consistent?
- [ ] Agent G (Data Engineer): Database locking (`SELECT FOR UPDATE`), outbox pattern implementation, data consistency between order state and event bus.

## Findings:

### Issue 1: `shipment.go` `ProcessShipment` Database Operations not Atomic
**Area**: `shipment.go`
**Problem**: The function `ProcessShipment` contains multiple database operations:
1. `uc.orderRepo.CreateShipment(ctx, shipment)`
2. `uc.UpdateOrderStatus(ctx, updateReq)` (this will update status and publish outbox event)
These are not inside a single transaction. If `UpdateOrderStatus` fails, the `OrderShipment` record is created, but the order status is out of sync.
**Agents**: Architect (Atomicity), Data Engineer (Consistency).

### Issue 2: `payment.go` `AddPayment` does not reliably guarantee Outbox emission
**Area**: `payment.go`
**Problem**: `AddPayment` updates the order payment status to `processing` inside a transaction but it does NOT emit an `order.status_changed` event via `outboxRepo` or any `payment_added` event. This means downstream services won't know the order status changed to `processing` in a guaranteed way.
**Agents**: Architect (Event-Driven Design).

### Issue 3: `create.go` Error Handling and Error Types
**Area**: `create.go`
**Problem**: `classifyCreateOrderError` does fallback string matching for errors (`strings.Contains("validation")`). The proper way is to ensure all services return correct gRPC status codes. 
**Agents**: Senior Go Dev (Code Quality).

### Issue 4: `payment_consumer.go` `ProcessRefundCompleted`
**Area**: `payment_consumer.go`
**Problem**: How does refund interact with warehouse return stock? `ProcessRefundCompleted` updates the order status to `refunded`, then calls `returnStockForRefund`. What if `returnStockForRefund` (which sends gRPC to warehouse) fails? The order is marked refunded, but stock is not returned. The order update and the stock return are not part of an atomic distributed transaction or Saga with proper compensation.
**Agents**: Architect (Saga/Atomicity), BA (Business Rules).

### Issue 5: `warehouse_consumer.go` `processReservationExpired` Phantom Status Handled
**Area**: `warehouse_consumer.go`
**Problem**: Only cancels if status is `pending`. Emits an alert if `confirmed` or `processing`. What if the status is `partially_shipped`?
**Agents**: BA (Edge cases).

### Continued research required for a full 10-round report.

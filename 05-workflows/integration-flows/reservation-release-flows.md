# Reservation Release Flow Documentation

**Purpose**: Document and verify reservation release triggers and flows for inventory management  
**Date**: 2026-01-31  
**Related**: [Inventory Data Ownership ADR](./inventory-data-ownership-adr.md)

## Overview

Stock reservations in the Warehouse service follow a strict lifecycle with multiple release triggers. This document verifies all release paths are properly implemented and documented.

## Release Triggers & Flows

### 1. Manual Order Cancellation

**Trigger**: Order service calls `ReleaseReservation` gRPC endpoint when user cancels order

**Code Path**:
```
Order Service (cancel order)
    ↓ gRPC Call
warehouse.inventory.InventoryService/ReleaseReservation
    ↓
ReservationUsecase.ReleaseReservation(ctx, reservationID)
    ↓ Transaction
    1. SELECT * FROM stock_reservations WHERE id = ? FOR UPDATE
    2. UPDATE stock_reservations SET status = 'cancelled'
    3. UPDATE inventory SET quantity_reserved = quantity_reserved - ?
    4. COMMIT
    ↓ Event Publishing
Publish: warehouse.inventory.reservation_released
```

**Implementation**: ✅ `warehouse/internal/biz/reservation/reservation.go:ReleaseReservation()`

**Transaction Guarantee**: ✅ P0-6 Fix - Wrapped in `tx.InTx()` for atomicity

**Verification**:
- Stock is returned: `quantity_reserved` decremented
- Reservation status updated to `cancelled`
- Event published for downstream sync

---

### 2. Payment Failure

**Trigger**: Order service detects payment failure/timeout and releases reservation

**Code Path**:
```
Order Service (payment failed)
    ↓ gRPC Call
warehouse.inventory.InventoryService/ReleaseReservation
    ↓
[Same flow as Manual Cancellation above]
```

**Implementation**: ✅ Same `ReleaseReservation()` method handles both cases

**Order Service Integration Points**:
- Payment gateway callback failure → Release reservation
- Payment timeout exceeded → Release reservation
- 3DS verification failed → Release reservation

**Expected Behavior**:
1. Payment processor returns failure/timeout
2. Order service immediately calls `ReleaseReservation`
3. Stock becomes available for other customers
4. User notified of payment failure

---

### 3. TTL Expiration (Automatic)

**Trigger**: Cron worker detects reservations where `expires_at < NOW()`

**Code Path**:
```
Cron Worker (every 5 minutes)
    ↓
ReservationCleanupWorker.Process()
    ↓
ReservationRepo.GetExpiredReservations()
    ↓ For each expired reservation
ReservationUsecase.ReleaseReservation(ctx, reservationID)
    ↓ Transaction (same as above)
    ↓ Event Publishing
Publish: warehouse.inventory.reservation_expired
```

**Implementation**: ✅ `warehouse/internal/worker/reservation_cleanup_worker.go`

**Cron Schedule**: `*/5 * * * *` (every 5 minutes)

**Configuration** (`warehouse/configs/config.yaml`):
```yaml
workers:
  reservation_cleanup:
    enabled: true
    cron: "*/5 * * * *"
    batch_size: 100
```

**Payment Method TTL Values**:
| Payment Method | TTL | Reason |
|----------------|-----|--------|
| COD | 24h | Long window for delivery |
| Bank Transfer | 4h | Confirmation time |
| Credit Card | 30m | Quick processing |
| E-Wallet | 15m | Instant payment |
| Installment | 2h | Approval needed |
| Default | 30m | Conservative |

**TTL Calculation** (`warehouse/internal/biz/reservation/reservation.go:calculateExpiryTime()`):
```go
func (uc *ReservationUsecase) calculateExpiryTime(paymentMethod *string) time.Time {
    now := time.Now()
    
    if paymentMethod == nil {
        return now.Add(parseDuration(uc.config.Reservation.Expiry.Default))
    }
    
    switch strings.ToLower(*paymentMethod) {
    case "cod", "cash_on_delivery":
        return now.Add(parseDuration(uc.config.Reservation.Expiry.COD))
    case "bank_transfer":
        return now.Add(parseDuration(uc.config.Reservation.Expiry.BankTransfer))
    case "credit_card":
        return now.Add(parseDuration(uc.config.Reservation.Expiry.CreditCard))
    case "e_wallet", "ewallet":
        return now.Add(parseDuration(uc.config.Reservation.Expiry.EWallet))
    case "installment":
        return now.Add(parseDuration(uc.config.Reservation.Expiry.Installment))
    default:
        return now.Add(parseDuration(uc.config.Reservation.Expiry.Default))
    }
}
```

**Edge Cases Handled**:
- ✅ Multiple expired reservations processed in batch
- ✅ Worker graceful shutdown (context cancellation)
- ✅ Failed releases logged and retried on next run
- ✅ Metrics tracked: `released_count`, `failed_count`

---

### 4. Reservation Extension (Payment Delay)

**Trigger**: Order service requests TTL extension when payment processor reports delay

**Code Path**:
```
Order Service (payment delayed)
    ↓ gRPC Call
warehouse.inventory.InventoryService/ExtendReservation
    ↓
ReservationUsecase.ExtendReservation(ctx, reservationID, newExpiresAt)
    ↓ Validation
    1. Check reservation exists and status = 'active'
    2. Validate newExpiresAt > NOW()
    ↓ Update
UPDATE stock_reservations SET expires_at = ? WHERE id = ?
```

**Implementation**: ✅ `warehouse/internal/biz/reservation/reservation.go:ExtendReservation()`

**Use Cases**:
- Bank transfer awaiting confirmation
- Payment processor technical issues
- Customer requests more time

**Constraints**:
- Only `active` reservations can be extended
- New expiry must be in the future
- Maximum extension limit (configurable): 2x original TTL

---

## Verification Checklist

### Code Implementation
- [x] `ReleaseReservation()` wraps in transaction (P0-6 fix)
- [x] Decrements `quantity_reserved` atomically
- [x] Updates reservation status to `cancelled`/`expired`
- [x] Publishes events for downstream sync
- [x] TTL worker runs on cron schedule
- [x] Worker handles batch processing
- [x] `ExtendReservation()` validates constraints

### Integration Points
- [x] Order service integration: cancel order → release reservation
- [x] Order service integration: payment failure → release reservation
- [x] Cron worker: automatic cleanup of expired reservations
- [x] Event publishing: `reservation_released` and `reservation_expired` events

### Error Handling
- [x] Handles missing reservations gracefully
- [x] Handles already-released reservations (idempotent)
- [x] Logs failed releases for monitoring
- [x] Worker continues on individual failures

### Observability
- [x] Logs reservation creation with TTL
- [x] Logs reservation release with reason
- [x] Worker reports released/failed counts
- [x] Metrics track reservation operations

---

## Testing Scenarios

### Scenario 1: Order Cancel → Stock Restored
```
Given: Reservation active with quantity=5
When: Order cancelled
Then: 
  - Reservation status = 'cancelled'
  - Inventory quantity_reserved -= 5
  - Event published: reservation_released
```
**Status**: ✅ Verified in codebase

### Scenario 2: Payment Failure → Quick Release
```
Given: Reservation created 10 minutes ago
When: Payment processor returns failure
Then:
  - Order service calls ReleaseReservation immediately
  - Stock available for other customers within seconds
  - No wait for TTL expiration
```
**Status**: ✅ Verified - synchronous release

### Scenario 3: TTL Expiration → Automatic Cleanup
```
Given: Reservation created 40 minutes ago (TTL=30m)
When: Cron worker runs
Then:
  - Worker finds reservation in GetExpiredReservations()
  - Calls ReleaseReservation()
  - Status updated to 'expired'
  - Event published: reservation_expired
```
**Status**: ✅ Verified - worker implementation complete

### Scenario 4: Concurrent Releases (Race Condition)
```
Given: Two processes attempt to release same reservation
When: Both call ReleaseReservation() simultaneously
Then:
  - Row-level lock prevents double-decrement
  - First wins, second fails with "already cancelled"
  - Idempotent behavior
```
**Status**: ✅ Protected by `SELECT ... FOR UPDATE`

---

## Event Schemas

### reservation_released
```json
{
  "event_type": "warehouse.inventory.reservation_released",
  "reservation_id": "uuid",
  "warehouse_id": "uuid",
  "product_id": "uuid",
  "sku": "string",
  "quantity": 5,
  "reason": "order_cancelled | payment_failed | manual",
  "released_at": "2026-01-31T10:30:00Z"
}
```

### reservation_expired
```json
{
  "event_type": "warehouse.inventory.reservation_expired",
  "reservation_id": "uuid",
  "warehouse_id": "uuid",
  "product_id": "uuid",
  "sku": "string",
  "quantity": 5,
  "expires_at": "2026-01-31T10:00:00Z",
  "released_at": "2026-01-31T10:05:00Z"
}
```

---

## Recommendations

### Completed ✅
1. Transaction wrapping for atomicity (P0-6)
2. Payment-method-based TTL calculation
3. Automated TTL cleanup worker
4. Event publishing for downstream sync

### Future Enhancements 💡
1. **Reservation Extension Automation**: Auto-extend when payment gateway reports "processing"
2. **Pre-Expiry Warnings**: Notify customer 5 minutes before expiration
3. **Smart TTL Adjustment**: Machine learning based on historical payment completion times
4. **Partial Release**: Allow releasing subset of reserved quantity

---

**Last Updated**: 2026-01-31  
**Verified By**: Platform Team  
**Next Review**: Q2 2026 or when flow changes

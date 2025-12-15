# Order Service Test Cases

## Overview

Comprehensive test cases for Order Service, focusing on stock reservation logic fixes.

## Test Files

### `order/internal/biz/order_reservation_test.go`

**Test Cases**:
1. `TestOrderUsecase_ReserveStockForItems_WithDefaultWarehouse` - Default warehouse fallback
2. `TestOrderUsecase_ReleaseReservationWithRetry` - Retry mechanism
3. `TestOrderUsecase_CancelOrder_WithRetry` - Order cancellation with retry
4. `TestOrderUsecase_ReserveStockForItems_WithOrderItems` - OrderItem type support
5. `TestOrderUsecase_ReserveStockForItems_UnsupportedType` - Error handling

### `order/internal/biz/cancellation/cancellation_test.go`

**Test Cases**:
1. `TestCancellationUsecase_ReleaseReservationWithRetry` - Retry mechanism
2. `TestCancellationUsecase_CancelOrder_WithRetry` - Order cancellation with retry
3. `TestCancellationUsecase_CancelOrderItems_WithRetry` - Partial cancellation with retry

## Test Scenarios

### 1. Stock Reservation với Default Warehouse

**Test**: `TestOrderUsecase_ReserveStockForItems_WithDefaultWarehouse`

**Scenarios**:
- ✅ Reserve với warehouse ID provided
- ✅ Reserve với warehouse ID missing - use default
- ✅ Reserve với warehouse ID empty string - use default
- ✅ Reserve fail - rollback previous reservations
- ✅ Multiple items với mixed warehouse IDs

**Key Assertions**:
- Default warehouse ID is used when `warehouseID` is `nil` or empty
- All items attempt to reserve stock (no skipped items)
- Previous reservations are rolled back on failure

### 2. Release Reservation với Retry

**Test**: `TestOrderUsecase_ReleaseReservationWithRetry`

**Scenarios**:
- ✅ Success on first attempt
- ✅ Success on second attempt
- ✅ Success on third attempt
- ✅ All retries fail
- ✅ Exponential backoff timing verification

**Key Assertions**:
- Retry mechanism works with exponential backoff (100ms, 200ms, 400ms)
- Maximum 3 retries attempted
- Error returned after all retries fail

### 3. Order Cancellation với Retry

**Test**: `TestOrderUsecase_CancelOrder_WithRetry`

**Scenarios**:
- ✅ Cancel order - all reservations released successfully
- ✅ Cancel order - first release fails, retry succeeds
- ✅ Cancel order - release fails after retries, order still cancelled

**Key Assertions**:
- Order cancellation succeeds even if reservation release fails
- Retry mechanism is applied to each reservation release
- Order status is updated to "cancelled" regardless of release failures

### 4. Partial Cancellation với Retry

**Test**: `TestCancellationUsecase_CancelOrderItems_WithRetry`

**Scenarios**:
- ✅ Cancel single item - release succeeds
- ✅ Cancel multiple items - all succeed
- ✅ Cancel item - release fails, retry succeeds
- ✅ Cancel item - release fails after retries, item still cancelled

## Running Tests

### Run All Reservation Tests

```bash
cd order
go test ./internal/biz -run TestOrderUsecase_ReserveStockForItems -v
go test ./internal/biz -run TestOrderUsecase_ReleaseReservationWithRetry -v
go test ./internal/biz -run TestOrderUsecase_CancelOrder_WithRetry -v
```

### Run Cancellation Tests

```bash
cd order
go test ./internal/biz/cancellation -v
```

### Run with Coverage

```bash
cd order
go test ./internal/biz -run TestOrderUsecase_ReserveStockForItems -cover
```

## Test Coverage

- ✅ Stock reservation with default warehouse fallback
- ✅ Retry mechanism for reservation release
- ✅ Order cancellation with retry
- ✅ Partial cancellation with retry
- ✅ Multiple item types support
- ✅ Error handling and rollback

## Known Issues

### Test File Compilation Errors

**Issue**: Some test files (`cart_test.go`, `order_test.go`) have compilation errors due to outdated function signatures.

**Impact**: Does not affect production code or new test cases.

**Status**: Deferred - requires updating test files to match current signatures.

## Next Steps

1. Fix compilation errors in existing test files (if needed)
2. Add integration tests for end-to-end flows
3. Add performance tests for concurrent reservations
4. Add tests for edge cases (expired reservations, concurrent cancellations)

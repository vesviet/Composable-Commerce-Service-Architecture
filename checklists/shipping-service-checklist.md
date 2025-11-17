# Shipping Service - Logic Review Checklist

## 📋 Overview

This checklist documents findings from reviewing the Shipping Service logic, focusing on shipment creation, status management, label generation, delivery confirmation, and event handling.

**Service Location**: `shipping/` (root level)

**Review Date**: 2025-01-17

---

## ✅ Implemented Features

1. **Shipment Creation**:
   - ✅ Create shipment from package events
   - ✅ Validate required fields (FulfillmentID, OrderID, Carrier)
   - ✅ Default status to "draft"
   - ✅ Publish shipment created event

2. **Status Management**:
   - ✅ Status transitions validation
   - ✅ Status enum: draft, processing, ready, shipped, out_for_delivery, delivered, failed, cancelled
   - ✅ Automatic timestamp updates (ShippedAt, DeliveredAt)
   - ✅ Publish status changed events

3. **Label Generation**:
   - ✅ Generate internal labels
   - ✅ Generate external labels (UPS, FedEx, DHL)
   - ✅ Update shipment with tracking number and label URL
   - ✅ Update fulfillment service package tracking

4. **Delivery Confirmation**:
   - ✅ Confirm delivery with signature/photo
   - ✅ Access control for shippers
   - ✅ Update status to delivered
   - ✅ Publish delivery events

5. **Shipment Assignment**:
   - ✅ Assign shipment to shipper
   - ✅ Validate status before assignment
   - ✅ Publish assignment events

6. **Event Handling**:
   - ✅ Handle package.created events
   - ✅ Handle package.ready events
   - ✅ Handle package.status_changed events

---

## 🔴 Critical Issues

### 1. **UpdateShipment - Syntax Error**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:182`
- **Issue**: Missing error check after `uc.repo.Update(ctx, existing)`
- **Code**:
  ```go
  if err := uc.repo.Update(ctx, existing);
      uc.log.WithContext(ctx).Errorf("failed to update shipment: id=%s, error=%v", existing.ID, err)
      return fmt.Errorf("failed to update shipment: %w", err)
  }
  ```
- **Impact**: Code will not compile
- **Fix**: Add `err != nil` check:
  ```go
  if err := uc.repo.Update(ctx, existing); err != nil {
      uc.log.WithContext(ctx).Errorf("failed to update shipment: id=%s, error=%v", existing.ID, err)
      return fmt.Errorf("failed to update shipment: %w", err)
  }
  ```

### 2. **GetByID - Returns nil Instead of Error**
- **File**: `shipping/internal/repository/shipment/shipment_repo.go:126`
- **Issue**: Returns `nil, nil` when shipment not found, but usecase expects error
- **Code**:
  ```go
  if err == gorm.ErrRecordNotFound {
      return nil, nil  // ❌ Should return error
  }
  ```
- **Impact**: Usecase will get nil shipment without error, causing nil pointer dereference
- **Fix**: Return `ErrShipmentNotFound`:
  ```go
  if err == gorm.ErrRecordNotFound {
      return nil, shipment.ErrShipmentNotFound
  }
  ```

### 3. **Duplicate Shipment Creation - Race Condition**
- **File**: `shipping/internal/biz/shipment/package_status_handler.go:37-44`
- **Issue**: Check existing shipments then create - race condition if 2 events arrive simultaneously
- **Code**:
  ```go
  existingShipments, err := uc.repo.GetByFulfillmentID(ctx, event.FulfillmentID)
  if err != nil {
      // Continue anyway, might be first shipment
  } else if len(existingShipments) > 0 {
      return nil  // Skip creation
  }
  // Create shipment - RACE CONDITION HERE
  ```
- **Impact**: Duplicate shipments can be created for same fulfillment
- **Fix**: Use database unique constraint or atomic check-and-create

---

## 🟠 High Priority Issues

### 4. **UpdateShipment - Race Condition**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:121-188`
- **Issue**: Get existing shipment, modify, then update - no locking
- **Code**:
  ```go
  existing, err := uc.repo.GetByID(ctx, s.ID)  // Read
  // ... modify existing ...
  if err := uc.repo.Update(ctx, existing); err != nil {  // Write - RACE CONDITION
  ```
- **Impact**: Concurrent updates can overwrite each other
- **Fix**: Use optimistic locking (version field) or pessimistic locking (SELECT FOR UPDATE)

### 5. **UpdateShipmentStatus - Race Condition**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:191-261`
- **Issue**: Same pattern as UpdateShipment - read then write without locking
- **Impact**: Concurrent status updates can conflict
- **Fix**: Use optimistic locking or atomic status update

### 6. **GetByID - Wrong Locking Clause**
- **File**: `shipping/internal/repository/shipment/shipment_repo.go:119-122`
- **Issue**: Uses `FOR UPDATE SKIP LOCKED` for read query, which is incorrect
- **Code**:
  ```go
  err := r.db.WithContext(ctx).
      Set("gorm:query_option", "FOR UPDATE SKIP LOCKED").  // ❌ Wrong for read
      Select("shipments.*").
      First(&modelShipment, "id = ?", id).Error
  ```
- **Impact**: Unnecessary locking on read queries, potential performance issue
- **Fix**: Remove locking clause for read queries, or use proper locking only when needed

### 7. **ConfirmDelivery - Missing Final Status Check**
- **File**: `shipping/internal/biz/shipment/confirm_delivery.go:32-35`
- **Issue**: Only checks if status is `out_for_delivery`, but doesn't check if already delivered
- **Code**:
  ```go
  if shipment.Status != StatusOutForDelivery.String() {
      return fmt.Errorf("cannot confirm delivery for shipment with status: %s (must be out_for_delivery)", shipment.Status)
  }
  ```
- **Impact**: If shipment is already delivered, no error is returned (though status transition validation should catch this)
- **Fix**: Add explicit check for already delivered status

### 8. **AssignShipment - Logic Issue**
- **File**: `shipping/internal/biz/shipment/assign_shipment.go:30-35`
- **Issue**: Logic allows draft status but condition is confusing
- **Code**:
  ```go
  if shipment.Status != StatusProcessing.String() && shipment.Status != StatusReady.String() {
      if shipment.Status != StatusDraft.String() {  // ❌ Confusing logic
          return fmt.Errorf("cannot assign shipment with status: %s", shipment.Status)
      }
  }
  ```
- **Impact**: Logic is hard to understand, allows draft but not other statuses
- **Fix**: Simplify logic:
  ```go
  allowedStatuses := []string{StatusDraft.String(), StatusProcessing.String(), StatusReady.String()}
  if !contains(allowedStatuses, shipment.Status) {
      return fmt.Errorf("cannot assign shipment with status: %s", shipment.Status)
  }
  ```

### 9. **CreateShipment - Missing TrackingNumber Validation**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:47-100`
- **Issue**: No validation for tracking number format or uniqueness
- **Impact**: Invalid or duplicate tracking numbers can be created
- **Fix**: Add tracking number validation and uniqueness check

### 10. **Event Publishing - Errors Ignored**
- **File**: Multiple files (shipment_usecase.go, label_generation.go, confirm_delivery.go, etc.)
- **Issue**: Event publishing errors are logged but operation continues
- **Code Pattern**:
  ```go
  if err := uc.eventBus.PublishShipmentCreated(...); err != nil {
      uc.log.WithContext(ctx).Errorf("failed to publish event: %v", err)
      // Operation continues - no retry, no rollback
  }
  ```
- **Impact**: Events can be lost, leading to inconsistency across services
- **Fix**: Consider retry mechanism or at least alerting for critical events

---

## 🟡 Medium Priority Issues

### 11. **Status Transition - No Database Constraint**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:384-430`
- **Issue**: Status transitions are validated in application code only
- **Impact**: Database can have invalid status transitions if application logic is bypassed
- **Fix**: Add database-level constraint or trigger to enforce valid transitions

### 12. **Label Generation - No Retry on Fulfillment Update Failure**
- **File**: `shipping/internal/biz/shipment/label_generation.go:132-141`
- **Issue**: If fulfillment service update fails, operation continues without retry
- **Code**:
  ```go
  if err := fulfillmentClient.UpdatePackageTracking(...); err != nil {
      uc.log.WithContext(ctx).Errorf("Failed to update package tracking: %v", err)
      // Don't fail the operation if fulfillment service update fails
  }
  ```
- **Impact**: Package tracking may not be updated in fulfillment service
- **Fix**: Add retry mechanism or queue for later processing

### 13. **HandlePackageReady - No Transaction**
- **File**: `shipping/internal/biz/shipment/package_ready_handler.go:30-75`
- **Issue**: Updates multiple shipments in loop without transaction
- **Code**:
  ```go
  for _, shipment := range shipments {
      // ... update shipment ...
      if err := uc.repo.Update(ctx, shipment); err != nil {
          return fmt.Errorf("failed to update shipment: %w", err)
      }
      // If one fails, previous updates are already committed
  }
  ```
- **Impact**: Partial updates if one shipment update fails
- **Fix**: Wrap in transaction or handle errors per shipment

### 14. **TrackingNumber - Temporary Value**
- **File**: `shipping/internal/biz/shipment/package_status_handler.go:88-89`
- **Issue**: Creates shipment with temporary tracking number "TEMP-{uuid}"
- **Code**:
  ```go
  trackingNumber := fmt.Sprintf("TEMP-%s", uuid.New().String()[:8])
  ```
- **Impact**: Shipment has invalid tracking number until label is generated
- **Fix**: Allow null tracking number initially, or generate proper tracking number

### 15. **OrderID - Placeholder Value**
- **File**: `shipping/internal/biz/shipment/package_status_handler.go:48-59`
- **Issue**: Uses "pending" as placeholder if order ID not found
- **Code**:
  ```go
  if orderID == "" {
      orderID = "pending"  // ❌ Invalid UUID
  }
  ```
- **Impact**: Invalid order ID in database (should be UUID)
- **Fix**: Return error or fetch from fulfillment service

### 16. **UpdateShipment - Publish Event Before Update**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:141-152`
- **Issue**: Publishes status changed event before actually updating database
- **Code**:
  ```go
  // Publish status changed event
  if err := uc.eventBus.PublishShipmentStatusChanged(...); err != nil {
      // Log error but continue
  }
  // Then update database
  if err := uc.repo.Update(ctx, existing); err != nil {
  ```
- **Impact**: Event published but database update fails - inconsistency
- **Fix**: Publish event after successful database update

### 17. **AddTrackingEvent - Status Update After Event**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:317-323`
- **Issue**: Updates shipment status after adding tracking event, but errors are ignored
- **Code**:
  ```go
  if event.Status != "" {
      if err := uc.UpdateShipmentStatus(ctx, shipmentID, event.Status, nil); err != nil {
          uc.log.WithContext(ctx).Errorf("failed to update shipment status: %v", err)
          // Error ignored
      }
  }
  ```
- **Impact**: Tracking event added but status not updated
- **Fix**: Return error or retry status update

---

## 🟢 Low Priority Issues

### 18. **GetByID - Missing Error Handling**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:108-115`
- **Issue**: Checks for `ErrShipmentNotFound` but repo returns `nil, nil` instead
- **Impact**: Will always get nil instead of error
- **Fix**: Fix repo to return error (see Critical Issue #2)

### 19. **ListShipments - No Validation**
- **File**: `shipping/internal/biz/shipment/shipment_usecase.go:328-353`
- **Issue**: No validation for filter values (dates, page, limit)
- **Impact**: Invalid filters can cause errors or performance issues
- **Fix**: Add filter validation

### 20. **CarrierService - Type Conversion**
- **File**: `shipping/internal/repository/shipment/shipment_repo.go:59-63`
- **Issue**: Converts `*string` to `string` with empty string default
- **Code**:
  ```go
  carrierService := ""
  if s.CarrierService != nil {
      carrierService = *s.CarrierService
  }
  ```
- **Impact**: Cannot distinguish between nil and empty string
- **Fix**: Use nullable string in model or handle nil explicitly

### 21. **Metadata - No Validation**
- **File**: Multiple files
- **Issue**: Metadata is stored as JSONB without validation
- **Impact**: Invalid or oversized metadata can cause issues
- **Fix**: Add metadata size and structure validation

### 22. **Tracking Events - Not Implemented**
- **File**: `shipping/internal/repository/shipment/shipment_repo.go:342-350`
- **Issue**: `AddTrackingEvent` is a placeholder, not implemented
- **Code**:
  ```go
  func (r *ShipmentRepo) AddTrackingEvent(...) error {
      // This is a simplified implementation - tracking events are stored in metadata
      _ = shipmentID
      _ = event
      return nil  // ❌ No-op
  }
  ```
- **Impact**: Tracking events are not actually stored
- **Fix**: Implement tracking event storage (separate table or metadata)

---

## 📝 Summary

### Critical Issues: 3
- Syntax error in UpdateShipment
- GetByID returns nil instead of error
- Race condition in duplicate shipment creation

### High Priority Issues: 7
- Race conditions in UpdateShipment and UpdateShipmentStatus
- Wrong locking clause in GetByID
- Missing validation in ConfirmDelivery
- Logic issue in AssignShipment
- Missing tracking number validation
- Event publishing errors ignored
- OrderID placeholder value

### Medium Priority Issues: 7
- No database constraint for status transitions
- No retry on fulfillment update failure
- No transaction in HandlePackageReady
- Temporary tracking number
- Placeholder order ID
- Event published before database update
- Status update errors ignored

### Low Priority Issues: 5
- Missing error handling
- No filter validation
- CarrierService type conversion
- No metadata validation
- Tracking events not implemented

---

## 🔄 Next Steps

1. **Fix Critical Issues First**:
   - Fix syntax error in UpdateShipment
   - Fix GetByID to return error
   - Add unique constraint or atomic check for duplicate shipment creation

2. **Address High Priority Issues**:
   - Implement optimistic locking for updates
   - Fix GetByID locking clause
   - Add validation and improve error handling

3. **Improve Medium Priority Issues**:
   - Add database constraints
   - Implement retry mechanisms
   - Fix event publishing order

4. **Enhance Low Priority Issues**:
   - Add validation
   - Implement tracking events
   - Improve error handling

---

## 🔄 Update History

- **2025-01-17**: Initial detailed review - Found critical syntax error, race conditions, and validation gaps
- **2025-01-17**: Fixed critical and high priority issues:
  - ✅ GetByID - Fixed to return error instead of nil
  - ✅ GetByID - Removed wrong locking clause (FOR UPDATE SKIP LOCKED)
  - ✅ Duplicate shipment creation - Added comment about race condition (needs database constraint)
  - ✅ OrderID placeholder - Fixed to return error instead of using "pending"
  - ✅ Tracking number - Changed from TEMP-* to empty string
  - ✅ CreateShipment - Added tracking number validation
  - ✅ UpdateShipment - Fixed event publishing order (after database update)
  - ✅ UpdateShipmentStatus - Fixed event publishing order (after database update)
  - ✅ ConfirmDelivery - Added check for already delivered status
  - ✅ AssignShipment - Simplified logic with map-based validation


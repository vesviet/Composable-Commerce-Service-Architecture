# 📦 Stock Management in Checkout Flow - Implementation Checklist (Quote Pattern)

**Created:** 2025-01-15  
**Updated:** 2025-01-15 (Migrated to Quote Pattern - No Draft Orders)  
**Status:** 🟡 Pending Implementation  
**Priority:** 🔴 Critical  
**Services:** Order, Warehouse, Frontend  
**Related:** Checkout Flow, Cart/Quote Management, Reservation Cleanup

---

## 📋 Overview

Implementation checklist for improving stock management in checkout flow using **Quote Pattern (Magento-style)** with **Hybrid Stock Reservation Approach** (Pre-reserve with Short TTL + Extend on Activity).

**Key Changes from Draft Order Pattern:**
- ✅ **No Draft Orders**: Use Cart/Quote as checkout state (no orders table bloat)
- ✅ **Cart as Quote**: Cart session stores checkout state (addresses, payment, shipping)
- ✅ **Order Creation**: Only create order when checkout confirmed (payment success)
- ✅ **Data Efficiency**: Orders table only contains confirmed orders (70-90% reduction)
- ✅ **Simpler Cleanup**: Cleanup abandoned carts instead of draft orders

**Key Objectives:**
- Reserve stock early in checkout flow (reduce race conditions)
- Manage reservation lifecycle with TTL extension
- Ensure stock availability throughout checkout
- Proper cleanup of expired reservations
- Improve user experience with stock validation
- **Eliminate draft orders** - use cart/quote pattern instead

**Success Metrics:**
- Stock reservation success rate: >99%
- Reservation expiry cleanup: 100% (no orphaned reservations)
- Checkout completion with stock issues: <1%
- Average reservation TTL: 5-10 minutes (active users)
- **Orders table size reduction: 70-90%** (no abandoned draft orders)

---

## 🎯 Strategy: Quote Pattern + Hybrid Stock Reservation

**Concept:**
- **Cart as Quote**: Cart session stores checkout state (status, addresses, payment method, etc.)
- **No Draft Orders**: Don't create order until checkout confirmed
- **Pre-reserve Stock**: Reserve stock when checkout starts (TTL = 5 minutes)
- **Extend Reservations**: Extend TTL when user is active
- **Final Validation**: Validate stock before payment
- **Create Order**: Only create order when payment succeeds
- **Auto-cleanup**: Cleanup expired reservations and abandoned carts

**Flow:**
```
StartCheckout → Cart Status: active → checkout → Reserve Stock (5 min TTL) → 
UpdateCheckoutState (extend TTL, save state in cart) → 
ConfirmCheckout (extend to 15 min, validate, payment) → 
Create Order (from cart) → Cart Status: completed → Clear Cart
```

**Cart Status Flow:**
```
active → checkout → completed/abandoned
```

**Order Status Flow (only when confirmed):**
```
pending → confirmed → processing → shipped → delivered
```

---

## 0. Database Migration - Enhance Cart Model (Quote Pattern) ⏱️ 2h

### 0.1 Add Checkout State Fields to Cart

- [ ] **D0.1.1** Create migration: `order/migrations/015_add_checkout_state_to_cart.sql`
  ```sql
  -- Add status field to cart_sessions (quote status)
  ALTER TABLE cart_sessions 
  ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active' 
  CHECK (status IN ('active', 'checkout', 'completed', 'abandoned'));
  
  -- Add checkout state fields
  ALTER TABLE cart_sessions
  ADD COLUMN IF NOT EXISTS shipping_address JSONB,
  ADD COLUMN IF NOT EXISTS billing_address JSONB,
  ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50),
  ADD COLUMN IF NOT EXISTS shipping_method_id VARCHAR(50),
  ADD COLUMN IF NOT EXISTS current_step INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS reservation_ids JSONB; -- Store reservation IDs array
  
  -- Add indexes for efficient querying
  CREATE INDEX IF NOT EXISTS idx_cart_sessions_status ON cart_sessions(status);
  CREATE INDEX IF NOT EXISTS idx_cart_sessions_status_expires ON cart_sessions(status, expires_at);
  CREATE INDEX IF NOT EXISTS idx_cart_sessions_checkout ON cart_sessions(status) WHERE status = 'checkout';
  ```

- [ ] **D0.1.2** Update CartSession model
  ```go
  // order/internal/model/cart.go
  type CartSession struct {
      // ... existing fields
      Status            string                 `gorm:"index;size:20;default:active" json:"status"`
      ShippingAddress   *commonUtils.JSONMetadata `gorm:"type:jsonb" json:"shipping_address"`
      BillingAddress    *commonUtils.JSONMetadata `gorm:"type:jsonb" json:"billing_address"`
      PaymentMethod     string                 `gorm:"size:50" json:"payment_method"`
      ShippingMethodID  *string                `gorm:"size:50" json:"shipping_method_id"`
      CurrentStep       int32                  `gorm:"default:1" json:"current_step"`
      ReservationIDs    *commonUtils.JSONMetadata `gorm:"type:jsonb" json:"reservation_ids"` // Array of reservation IDs
  }
  ```

- [ ] **D0.1.3** Test migration: `cd order && make migrate-up`
- [ ] **D0.1.4** Verify schema: `psql -d order_db -c "\d cart_sessions"`

**Completion Criteria**: ✅ Migration runs successfully, cart model updated

---

## 0. Migration: Draft Order → Quote Pattern ⏱️ 4h

### 0.1 Cleanup Existing Draft Orders

- [ ] **M0.1.1** Cancel all existing draft orders
  ```sql
  -- Cancel all draft orders
  UPDATE orders 
  SET status = 'cancelled', 
      cancelled_at = NOW(),
      notes = 'Cancelled during migration to quote pattern'
  WHERE status = 'draft';
  ```

- [ ] **M0.1.2** Release reservations for cancelled draft orders
  - [ ] Query: `SELECT order_items.reservation_id FROM order_items JOIN orders ON order_items.order_id = orders.id WHERE orders.status = 'cancelled' AND order_items.reservation_id IS NOT NULL`
  - [ ] Release all reservations via warehouse service
  - [ ] Log released reservation count

- [ ] **M0.1.3** Delete expired checkout sessions
  ```sql
  -- Delete expired checkout sessions
  DELETE FROM checkout_sessions WHERE expires_at < NOW();
  ```

**Completion Criteria**: ✅ All draft orders cancelled, reservations released, expired sessions deleted

---

### 0.2 Update Code to Remove Draft Order Logic

- [ ] **M0.2.1** Remove draft order creation from StartCheckout
  - [ ] Remove `CreateOrder` call in StartCheckout
  - [ ] Update to change cart status instead
  - [ ] Remove order_id from checkout_session creation

- [ ] **M0.2.2** Update GetCheckoutState
  - [ ] Load from cart instead of draft order
  - [ ] Remove order_id dependency
  - [ ] Return cart data instead of draft order

- [ ] **M0.2.3** Update ConfirmCheckout
  - [ ] Load cart instead of draft order
  - [ ] Create order from cart after payment
  - [ ] Link reservation IDs when creating order

**Completion Criteria**: ✅ Code updated, no draft order creation, tests pass

---

## 1. Backend: Order Service - Stock Reservation (Quote Pattern)

### 1.1 StartCheckout - Pre-reserve Stock (No Draft Order)

- [ ] **O1.1.1** Validate stock availability before starting checkout
  - [ ] Check stock for all cart items using warehouse service
  - [ ] Query: `GET /api/v1/inventory/check-availability` (or gRPC equivalent)
  - [ ] Validate each item: `available_quantity >= requested_quantity`
  - [ ] Return error if any item is out of stock (HTTP 400 with details)
  - [ ] Return warning if stock is low (< 5 units) - include in response metadata
  - [ ] Log stock validation results with structured logging
  - [ ] **Edge Case**: Handle warehouse service unavailable (fallback to cart.InStock flag)
  - [ ] **Edge Case**: Handle partial stock (some items available, some not)
  
  **Implementation Details:**
  ```go
  // In StartCheckout, before changing cart status
  for _, item := range cart.Items {
      // Check stock via warehouse service
      warehouseID := item.WarehouseID
      if warehouseID == nil || *warehouseID == "" {
          defaultWarehouseID := DefaultWarehouseID
          warehouseID = &defaultWarehouseID
      }
      
      err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, *warehouseID, item.Quantity)
      if err != nil {
          // Fallback to cart.InStock if service unavailable
          if strings.Contains(err.Error(), "unavailable") || strings.Contains(err.Error(), "timeout") {
              uc.log.WithContext(ctx).Warnf("Warehouse service unavailable for product %s, using cart.InStock flag: %v", item.ProductSKU, err)
              if !item.InStock {
                  return nil, fmt.Errorf("item %s is out of stock", item.ProductSKU)
              }
              continue
          }
          // Stock insufficient
          return nil, fmt.Errorf("insufficient stock for %s: %w", item.ProductSKU, err)
      }
      uc.log.WithContext(ctx).Debugf("Stock validated for %s: available", item.ProductSKU)
  }
  ```

- [ ] **O1.1.2** Reserve stock with short TTL (5 minutes) - Store in Cart
  - [ ] Call `ReserveStockForItems` with TTL = 5 minutes
  - [ ] Calculate `expiresAt = time.Now().Add(5 * time.Minute)`
  - [ ] Store reservation IDs in cart metadata (`cart.metadata["reservation_ids"]`)
  - [ ] Store reservation expiry in cart metadata (`cart.metadata["reservation_expires_at"]`)
  - [ ] Update cart status: `active` → `checkout`
  - [ ] Set cart `expires_at = now + 5 minutes` (match reservation expiry)
  - [ ] Handle reservation failures gracefully with rollback
  - [ ] **Edge Case**: Partial reservation success (some items reserved, some failed)
  - [ ] **Edge Case**: Warehouse service timeout (retry with exponential backoff)
  
  **Implementation Details:**
  ```go
  // After stock validation, reserve stock and update cart
  expiresAt := time.Now().Add(5 * time.Minute)
  
  // Convert cart items to reservation items
  reservationItems := make([]*CreateOrderItemRequest, len(cart.Items))
  for i, item := range cart.Items {
      reservationItems[i] = &CreateOrderItemRequest{
          ProductID:   item.ProductID,
          ProductSKU:  item.ProductSKU,
          Quantity:    item.Quantity,
          WarehouseID: item.WarehouseID,
      }
  }
  
  // Reserve stock with 5 minutes TTL
  reservations, err := uc.orderUc.ReserveStockForItems(ctx, reservationItems, 5)
  if err != nil {
      return nil, fmt.Errorf("failed to reserve stock: %w", err)
  }
  
  // Store reservation IDs in cart metadata
  reservationIDsArray := make([]int64, 0, len(reservations))
  for _, resID := range reservations {
      reservationIDsArray = append(reservationIDsArray, resID)
  }
  
  // Update cart: status = checkout, store reservation IDs, set expiry
  if cart.Metadata == nil {
      cart.Metadata = make(JSONB)
  }
  cart.Metadata["reservation_ids"] = reservationIDsArray
  cart.Metadata["reservation_expires_at"] = expiresAt.Format(time.RFC3339)
  cart.Status = "checkout"
  cart.ExpiresAt = &expiresAt
  
  // Update cart in database
  updatedCart, err := uc.cartRepo.Update(ctx, cart)
  if err != nil {
      // Rollback reservations
      uc.orderUc.rollbackReservationsMap(ctx, reservations)
      return nil, fmt.Errorf("failed to update cart status: %w", err)
  }
  
  // Create checkout session (simplified - no order_id)
  checkoutSession := &model.CheckoutSession{
      SessionID:   req.SessionID,
      OrderID:     "", // No draft order - will be set when order created
      CustomerID: *req.CustomerID,
      CurrentStep: 1,
      ExpiresAt:   &expiresAt,
      Metadata:    make(JSONB),
  }
  // Store cart session_id in checkout session metadata
  checkoutSession.Metadata["cart_session_id"] = updatedCart.SessionID
  
  createdSession, err := uc.checkoutSessionRepo.Create(ctx, checkoutSession)
  if err != nil {
      // Rollback: release reservations, revert cart status
      uc.orderUc.rollbackReservationsMap(ctx, reservations)
      cart.Status = "active"
      cart.Metadata = nil // Clear reservation data
      _ = uc.cartRepo.Update(ctx, cart)
      return nil, fmt.Errorf("failed to create checkout session: %w", err)
  }
  
  return convertModelCheckoutSessionToBiz(createdSession), nil
  ```

- [ ] **O1.1.3** Update Cart Model to Support Reservation IDs
  - [ ] Store reservation IDs in `cart.metadata["reservation_ids"]` (JSONB array)
  - [ ] Store reservation expiry in `cart.metadata["reservation_expires_at"]` (ISO8601 string)
  - [ ] Update cart status to `checkout` when reservations created
  - [ ] Set cart `expires_at` to match reservation expiry
  - [ ] **Note**: No need to store in order_items yet (order not created)
  
  **Cart Metadata Structure:**
  ```json
  {
    "reservation_ids": [1001, 1002, 1003],
    "reservation_expires_at": "2025-01-15T10:35:00Z",
    "checkout_started_at": "2025-01-15T10:30:00Z"
  }
  ```

- [ ] **O1.1.4** Error handling for stock reservation
  - [ ] Rollback draft order if reservation fails (delete order, release reservations)
  - [ ] Return clear error messages to frontend with item details
  - [ ] Log reservation failures with context (customer_id, session_id, items)
  - [ ] **Error Types**:
    - `INSUFFICIENT_STOCK` - Stock not available
    - `RESERVATION_FAILED` - Warehouse service error
    - `PARTIAL_RESERVATION` - Some items reserved, some failed
    - `TIMEOUT` - Warehouse service timeout
  - [ ] **Retry Logic**: Retry reservation with exponential backoff (max 3 retries)
  - [ ] **Circuit Breaker**: Track reservation failure rate, open circuit if > 10% failures
  
  **Error Response Format:**
  ```json
  {
    "error": {
      "code": "INSUFFICIENT_STOCK",
      "message": "Some items are out of stock",
      "details": {
        "items": [
          {
            "product_id": "uuid",
            "sku": "SKU-123",
            "available": 0,
            "requested": 2
          }
        ]
      }
    }
  }
  ```

**Files to modify:**
- `order/migrations/015_add_checkout_state_to_cart.sql` - **NEW** Migration for cart checkout state
- `order/internal/model/cart.go` - Add checkout state fields to CartSession
- `order/internal/biz/checkout.go` - `StartCheckout` method (remove draft order creation)
- `order/internal/biz/cart.go` - Update cart status and metadata methods
- `order/internal/biz/order_reservation.go` - `ReserveStockForItems` method (already supports TTL)
- `order/internal/data/postgres/cart.go` - Update cart repository to handle new fields

---

### 1.2 UpdateCheckoutState - Extend Reservations & Save State in Cart

- [ ] **O1.2.1** Get reservation IDs from cart metadata
  - [ ] Load cart by session_id
  - [ ] Extract reservation IDs from `cart.metadata["reservation_ids"]`
  - [ ] Extract reservation expiry from `cart.metadata["reservation_expires_at"]`
  - [ ] **Edge Case**: Cart not found or not in checkout status (return error)
  - [ ] **Edge Case**: No reservation IDs in cart (log warning, continue)
  
  **Implementation Details:**
  ```go
  // In UpdateCheckoutState, get cart first
  cart, err := uc.GetCart(ctx, req.SessionID, req.CustomerID, "")
  if err != nil {
      return nil, fmt.Errorf("failed to get cart: %w", err)
  }
  
  // Verify cart is in checkout status
  if cart.Status != "checkout" {
      return nil, fmt.Errorf("cart is not in checkout status")
  }
  
  // Get reservation IDs from cart metadata
  reservationIDs := []int64{}
  if cart.Metadata != nil {
      if ids, ok := cart.Metadata["reservation_ids"].([]interface{}); ok {
          for _, id := range ids {
              if idFloat, ok := id.(float64); ok {
                  reservationIDs = append(reservationIDs, int64(idFloat))
              }
          }
      }
  }
  ```

- [ ] **O1.2.2** Check reservation TTL on activity
  - [ ] Get current reservation TTL from warehouse service for all reservations
  - [ ] Query: `GET /api/v1/reservations/{id}` to get `expires_at`
  - [ ] Calculate time remaining: `time.Until(expiresAt)`
  - [ ] Check if TTL < 2 minutes remaining (threshold configurable)
  - [ ] Extend TTL if needed (extend to 5 minutes from now)
  - [ ] **Edge Case**: Some reservations expired, some not (extend only active ones)
  - [ ] **Edge Case**: Warehouse service unavailable (log warning, continue)
  - [ ] **Performance**: Batch check reservations (don't check one by one)
  
  **Implementation Details:**
  ```go
  // Check TTL for all reservations (batch)
  needsExtension := false
  for _, resID := range reservationIDs {
      reservation, err := uc.warehouseInventoryService.GetReservation(ctx, resID)
      if err == nil && reservation != nil && reservation.ExpiresAt != nil {
          timeRemaining := time.Until(*reservation.ExpiresAt)
          if timeRemaining < 2*time.Minute {
              needsExtension = true
              break
          }
      }
  }
  
  if needsExtension {
      // Extend all reservations
      newExpiresAt := time.Now().Add(5 * time.Minute)
      extensionErrors := []string{}
      for _, resID := range reservationIDs {
          err := uc.warehouseInventoryService.ExtendReservation(ctx, resID, newExpiresAt)
          if err != nil {
              uc.log.WithContext(ctx).Warnf("Failed to extend reservation %d: %v", resID, err)
              extensionErrors = append(extensionErrors, fmt.Sprintf("reservation %d: %v", resID, err))
          }
      }
      
      // Update cart expiry and metadata
      cart.ExpiresAt = &newExpiresAt
      if cart.Metadata == nil {
          cart.Metadata = make(JSONB)
      }
      cart.Metadata["reservation_expires_at"] = newExpiresAt.Format(time.RFC3339)
      if len(extensionErrors) > 0 {
          cart.Metadata["reservation_extension_errors"] = extensionErrors
      }
      
      // Update cart in database
      _, err = uc.cartRepo.Update(ctx, cart)
      if err != nil {
          uc.log.WithContext(ctx).Warnf("Failed to update cart expiry: %v", err)
      }
  }
  ```

- [ ] **O1.2.3** Save checkout state in cart
  - [ ] Update cart with addresses, payment method, shipping method
  - [ ] Store in cart fields: `shipping_address`, `billing_address`, `payment_method`, `shipping_method_id`
  - [ ] Update `current_step` in cart
  - [ ] Save cart to database
  - [ ] **Edge Case**: Cart not found (return error)
  - [ ] **Edge Case**: Cart not in checkout status (return error)
  
  **Save State Logic:**
  ```go
  // Update cart with checkout state
  if req.ShippingAddress != nil {
      cart.ShippingAddress = convertAddressToJSONB(req.ShippingAddress)
  }
  if req.BillingAddress != nil {
      cart.BillingAddress = convertAddressToJSONB(req.BillingAddress)
  }
  if req.PaymentMethod != "" {
      cart.PaymentMethod = req.PaymentMethod
  }
  if req.ShippingMethodID != nil {
      cart.ShippingMethodID = req.ShippingMethodID
  }
  if req.CurrentStep > 0 {
      cart.CurrentStep = req.CurrentStep
  }
  
  // Update cart in database
  updatedCart, err := uc.cartRepo.Update(ctx, cart)
  if err != nil {
      return nil, fmt.Errorf("failed to update cart state: %w", err)
  }
  
  // Update checkout session
  session.CurrentStep = req.CurrentStep
  // ... update session fields
  updatedSession, err := uc.checkoutSessionRepo.Update(ctx, session)
  ```

- [ ] **O1.2.4** Re-validate stock if TTL is low
  - [ ] Check stock availability if TTL < 2 minutes (before extending)
  - [ ] Query warehouse service for current stock levels
  - [ ] Compare with cart items quantities
  - [ ] Show warning if stock changed (decreased significantly)
  - [ ] Update cart metadata with stock warnings
  - [ ] **Edge Case**: Stock became unavailable (release reservation, return error)
  - [ ] **Edge Case**: Stock increased (no action needed)
  
  **Stock Validation:**
  ```go
  // Before extending, validate stock
  if timeRemaining < 2*time.Minute {
      // Re-validate stock for all cart items
      for _, item := range cart.Items {
          warehouseID := item.WarehouseID
          if warehouseID == nil || *warehouseID == "" {
              defaultWarehouseID := DefaultWarehouseID
              warehouseID = &defaultWarehouseID
          }
          
          err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, *warehouseID, item.Quantity)
          if err != nil {
              // Stock no longer available
              return nil, fmt.Errorf("stock no longer available for %s: %w", item.ProductSKU, err)
          }
      }
  }
  ```

**Files to modify:**
- `order/internal/biz/checkout.go` - `UpdateCheckoutState` method (load from cart, extend reservations, save to cart)
- `order/internal/biz/cart.go` - Add methods to update cart checkout state
- `order/internal/client/warehouse_client.go` - Add `ExtendReservation` and `GetReservation` methods
- `order/internal/data/postgres/cart.go` - Update cart repository to handle new fields

---

### 1.2.5 GetCheckoutState - Load from Cart (Quote Pattern)

- [ ] **O1.2.5** Update GetCheckoutState to load from cart
  - [ ] Get checkout session by session_id
  - [ ] Get cart by session_id (from checkout session metadata or direct lookup)
  - [ ] Verify cart is in `checkout` status
  - [ ] Extract reservation IDs from cart metadata
  - [ ] Return cart data instead of draft order
  - [ ] **Edge Case**: Cart not found (return not found)
  - [ ] **Edge Case**: Cart not in checkout status (return not found)
  - [ ] **Edge Case**: Cart expired (cleanup and return not found)
  
  **Implementation Details:**
  ```go
  // In GetCheckoutState, load cart instead of draft order
  session, err := uc.checkoutSessionRepo.FindBySessionID(ctx, req.SessionID)
  if err != nil {
      return nil, nil, nil // Not found
  }
  
  // Get cart session_id from checkout session metadata or use session_id directly
  cartSessionID := req.SessionID
  if session.Metadata != nil {
      if csid, ok := session.Metadata["cart_session_id"].(string); ok {
          cartSessionID = csid
      }
  }
  
  // Get cart
  cart, err := uc.GetCart(ctx, cartSessionID, req.CustomerID, "")
  if err != nil {
      return nil, nil, nil // Not found
  }
  
  // Verify cart is in checkout status
  if cart.Status != "checkout" {
      return nil, nil, nil // Not in checkout
  }
  
  // Check if cart expired
  if cart.ExpiresAt != nil && time.Now().After(*cart.ExpiresAt) {
      // Cleanup expired cart
      reservationIDs := extractReservationIDs(cart.Metadata)
      for _, resID := range reservationIDs {
          _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID)
      }
      cart.Status = "abandoned"
      cart.Metadata = nil
      _ = uc.cartRepo.Update(ctx, cart)
      _ = uc.checkoutSessionRepo.DeleteBySessionID(ctx, req.SessionID)
      return nil, nil, nil // Expired
  }
  
  // Extract reservation IDs
  reservationIDs := extractReservationIDs(cart.Metadata)
  
  // Build checkout state from cart
  checkoutState := &CheckoutState{
      SessionID:       session.SessionID,
      CurrentStep:     cart.CurrentStep,
      ShippingAddress: convertJSONBToAddress(cart.ShippingAddress),
      BillingAddress:  convertJSONBToAddress(cart.BillingAddress),
      PaymentMethod:   cart.PaymentMethod,
      ShippingMethodID: cart.ShippingMethodID,
      ReservationIDs:  reservationIDs,
      ExpiresAt:       cart.ExpiresAt,
  }
  
  return checkoutState, cart, nil
  ```

**Files to modify:**
- `order/internal/biz/checkout.go` - `GetCheckoutState` method (load from cart, no draft order)

---

### 1.3 ConfirmCheckout - Final Validation, Payment & Create Order

- [ ] **O1.3.1** Load cart and validate checkout state
  - [ ] Get cart by session_id (must be in `checkout` status)
  - [ ] Verify cart has items
  - [ ] Extract reservation IDs from cart metadata
  - [ ] **Edge Case**: Cart not found or not in checkout status (return error)
  - [ ] **Edge Case**: Cart expired (return error, user needs to restart checkout)
  
  **Implementation Details:**
  ```go
  // In ConfirmCheckout, load cart first
  cart, err := uc.GetCart(ctx, req.SessionID, req.CustomerID, "")
  if err != nil {
      return nil, fmt.Errorf("failed to get cart: %w", err)
  }
  
  // Verify cart is in checkout status
  if cart.Status != "checkout" {
      return nil, fmt.Errorf("cart is not in checkout status")
  }
  
  // Verify cart has items
  if len(cart.Items) == 0 {
      return nil, fmt.Errorf("cart is empty")
  }
  
  // Get reservation IDs from cart metadata
  reservationIDs := []int64{}
  if cart.Metadata != nil {
      if ids, ok := cart.Metadata["reservation_ids"].([]interface{}); ok {
          for _, id := range ids {
              if idFloat, ok := id.(float64); ok {
                  reservationIDs = append(reservationIDs, int64(idFloat))
              }
          }
      }
  }
  ```

- [ ] **O1.3.2** Final stock validation
  - [ ] Re-check stock availability for all cart items (critical check before payment)
  - [ ] Query warehouse service for current stock levels
  - [ ] Validate: `available_quantity >= cart_item_quantity` for each item
  - [ ] Return error if stock unavailable (HTTP 400 with item details)
  - [ ] Log validation results with structured logging
  - [ ] **Edge Case**: Stock decreased but still sufficient (log warning, continue)
  - [ ] **Edge Case**: Stock became unavailable (release reservations, return error)
  - [ ] **Performance**: Batch check all items in parallel
  
  **Implementation Details:**
  ```go
  // Final stock validation
  var stockIssues []string
  for _, item := range cart.Items {
      warehouseID := item.WarehouseID
      if warehouseID == nil || *warehouseID == "" {
          defaultWarehouseID := DefaultWarehouseID
          warehouseID = &defaultWarehouseID
      }
      
      err := uc.warehouseInventoryService.CheckStock(ctx, item.ProductID, *warehouseID, item.Quantity)
      if err != nil {
          uc.log.WithContext(ctx).Errorf("Failed to check stock for %s: %v", item.ProductSKU, err)
          stockIssues = append(stockIssues, fmt.Sprintf("Unable to verify stock for %s", item.ProductSKU))
          continue
      }
  }
  
  if len(stockIssues) > 0 {
      // Release reservations
      for _, resID := range reservationIDs {
          _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID)
      }
      // Revert cart status
      cart.Status = "active"
      cart.Metadata = nil
      _ = uc.cartRepo.Update(ctx, cart)
      return nil, fmt.Errorf("stock validation failed: %s", strings.Join(stockIssues, "; "))
  }
  ```

- [ ] **O1.3.3** Extend reservations for payment processing
  - [ ] Extend reservation TTL to 15 minutes (for payment processing time)
  - [ ] Calculate: `newExpiresAt = time.Now().Add(15 * time.Minute)`
  - [ ] Extend all reservations in batch (parallel if possible)
  - [ ] Update cart `expires_at` to match new TTL
  - [ ] Update cart metadata with new expiry
  - [ ] Ensure reservations are active (check status before extending)
  - [ ] **Edge Case**: Reservation expired (release and re-reserve)
  - [ ] **Edge Case**: Reservation already confirmed (skip extension)
  - [ ] **Error Handling**: If extension fails, log error but continue (payment might succeed quickly)
  
  **Extension Before Payment:**
  ```go
  // Extend reservations for payment processing
  newExpiresAt := time.Now().Add(15 * time.Minute)
  extensionErrors := []string{}
  
  for _, resID := range reservationIDs {
      // Check reservation status first
      reservation, err := uc.warehouseInventoryService.GetReservation(ctx, resID)
      if err != nil {
          uc.log.WithContext(ctx).Warnf("Failed to get reservation %d: %v", resID, err)
          extensionErrors = append(extensionErrors, fmt.Sprintf("Reservation %d not found", resID))
          continue
      }
      
      if reservation.ExpiresAt != nil && time.Now().After(*reservation.ExpiresAt) {
          // Reservation expired, need to re-reserve
          uc.log.WithContext(ctx).Warnf("Reservation %d expired, releasing", resID)
          _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID)
          // Find cart item for this reservation and re-reserve
          // Note: This is complex, might need to track product_id -> reservation_id mapping
          continue
      }
      
      // Extend reservation
      err = uc.warehouseInventoryService.ExtendReservation(ctx, resID, newExpiresAt)
      if err != nil {
          uc.log.WithContext(ctx).Errorf("Failed to extend reservation %d: %v", resID, err)
          extensionErrors = append(extensionErrors, fmt.Sprintf("Failed to extend reservation %d", resID))
      }
  }
  
  if len(extensionErrors) > 0 {
      uc.log.WithContext(ctx).Warnf("Some reservations failed to extend: %v", extensionErrors)
      // Continue anyway - payment might succeed quickly
  }
  
  // Update cart expiry
  cart.ExpiresAt = &newExpiresAt
  if cart.Metadata == nil {
      cart.Metadata = make(JSONB)
  }
  cart.Metadata["reservation_expires_at"] = newExpiresAt.Format(time.RFC3339)
  _, err = uc.cartRepo.Update(ctx, cart)
  if err != nil {
      uc.log.WithContext(ctx).Warnf("Failed to update cart expiry: %v", err)
  }
  ```

- [ ] **O1.3.4** Process payment with reservation safety
  - [ ] Authorize payment (authorize without capture)
  - [ ] **If authorization fails** → Release reservations immediately (all reservations)
  - [ ] **If authorization succeeds** → Proceed to capture
  - [ ] Capture payment (capture the authorized payment)
  - [ ] **If capture fails** → Void authorization + Release reservations immediately
  - [ ] **Transaction Safety**: Use database transaction for payment + order creation
  - [ ] **Retry Logic**: Retry payment with exponential backoff (max 3 retries)
  - [ ] **Edge Case**: Partial payment failure (rollback all)
  - [ ] **Edge Case**: Payment timeout (release reservations after timeout)
  
  **Payment with Reservation Safety:**
  ```go
  // Authorize payment
  authReq := &PaymentAuthorizationRequest{
      OrderID:         "", // No order yet - will create after payment
      Amount:          calculateCartTotal(cart),
      Currency:        "USD",
      PaymentMethod:   cart.PaymentMethod,
      Metadata:        map[string]interface{}{"session_id": req.SessionID},
  }
  
  authResp, err := uc.paymentService.AuthorizePayment(ctx, authReq)
  if err != nil {
      // Release all reservations
      for _, resID := range reservationIDs {
          _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID)
      }
      // Revert cart status
      cart.Status = "active"
      _ = uc.cartRepo.Update(ctx, cart)
      return nil, fmt.Errorf("payment authorization failed: %w", err)
  }
  
  if authResp.Status != "authorized" {
      // Release all reservations
      for _, resID := range reservationIDs {
          _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID)
      }
      cart.Status = "active"
      _ = uc.cartRepo.Update(ctx, cart)
      return nil, fmt.Errorf("payment authorization failed: status %s", authResp.Status)
  }
  
  // Capture payment
  captureReq := &PaymentCaptureRequest{
      AuthorizationID: authResp.AuthorizationID,
      OrderID:         "", // Will be set after order creation
      Amount:          calculateCartTotal(cart),
      Metadata:        map[string]interface{}{"session_id": req.SessionID},
  }
  
  paymentResp, err := uc.paymentService.CapturePayment(ctx, captureReq)
  if err != nil {
      // Void authorization
      _, _ = uc.paymentService.VoidAuthorization(ctx, &PaymentVoidRequest{
          AuthorizationID: authResp.AuthorizationID,
          OrderID: "",
          Reason: "Capture failed",
      })
      
      // Release all reservations
      for _, resID := range reservationIDs {
          _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID)
      }
      cart.Status = "active"
      _ = uc.cartRepo.Update(ctx, cart)
      return nil, fmt.Errorf("payment capture failed: %w", err)
  }
  ```

- [ ] **O1.3.5** Create order from cart after payment success
  - [ ] Convert cart items to order items (include reservation IDs)
  - [ ] Create order with status `pending` (not draft)
  - [ ] Link reservation IDs to order items
  - [ ] Store order addresses from cart
  - [ ] Store payment info in order
  - [ ] **Transaction**: Use database transaction for order creation
  - [ ] **Error Handling**: If order creation fails, log error but payment succeeded (manual review needed)
  
  **Create Order from Cart:**
  ```go
  // After payment success, create order from cart
  orderItems := make([]*CreateOrderItemRequest, len(cart.Items))
  for i, cartItem := range cart.Items {
      // Find reservation ID for this item (from reservation_ids array)
      // Note: Need to map product_id to reservation_id
      var reservationID *int64
      // This requires tracking product_id -> reservation_id mapping
      // Store in cart.metadata["reservation_map"]: {"product_id": reservation_id}
      
      orderItems[i] = &CreateOrderItemRequest{
          ProductID:     cartItem.ProductID,
          ProductSKU:    cartItem.ProductSKU,
          Quantity:      cartItem.Quantity,
          WarehouseID:   cartItem.WarehouseID,
          ReservationID: reservationID, // From reservation map
      }
  }
  
  orderReq := &CreateOrderRequest{
      CustomerID:      *req.CustomerID,
      Items:           orderItems,
      PaymentMethod:   cart.PaymentMethod,
      ShippingAddress: convertJSONBToAddress(cart.ShippingAddress),
      BillingAddress:  convertJSONBToAddress(cart.BillingAddress),
      Metadata: JSONB{
          "payment_id": paymentResp.PaymentID,
          "authorization_id": authResp.AuthorizationID,
      },
  }
  
  // Create order (status = pending, not draft)
  createdOrder, err := uc.orderUc.CreateOrder(ctx, orderReq)
  if err != nil {
      uc.log.WithContext(ctx).Errorf("Failed to create order after payment: %v", err)
      // Payment succeeded but order creation failed - manual review needed
      // Store in cart metadata for retry
      if cart.Metadata == nil {
          cart.Metadata = make(JSONB)
      }
      cart.Metadata["order_creation_failed"] = true
      cart.Metadata["order_creation_error"] = err.Error()
      cart.Metadata["payment_id"] = paymentResp.PaymentID
      _ = uc.cartRepo.Update(ctx, cart)
      return nil, fmt.Errorf("payment succeeded but order creation failed: %w", err)
  }
  ```

- [ ] **O1.3.6** Confirm reservations after order creation
  - [ ] Call warehouse service to confirm reservations (batch confirm if possible)
  - [ ] Endpoint: `POST /api/v1/reservations/{id}/confirm` with body `{ order_id: "uuid" }`
  - [ ] Mark reservations as committed (status = "confirmed")
  - [ ] Store confirmation time in order metadata
  - [ ] **Error Handling**: If confirmation fails, log error but don't fail order (payment succeeded)
  - [ ] **Edge Case**: Some reservations confirmed, some failed (retry failed ones)
  - [ ] **Edge Case**: Reservation already confirmed (idempotent, log and continue)
  
  **Confirm Reservations:**
  ```go
  // After order creation, confirm reservations
  confirmationErrors := []string{}
  for _, resID := range reservationIDs {
      err := uc.warehouseInventoryService.ConfirmReservation(ctx, resID)
      if err != nil {
          uc.log.WithContext(ctx).Errorf("Failed to confirm reservation %d: %v", resID, err)
          confirmationErrors = append(confirmationErrors, fmt.Sprintf("Reservation %d: %v", resID, err))
          // Don't fail order - payment succeeded, but log for manual review
      } else {
          uc.log.WithContext(ctx).Infof("Confirmed reservation %d for order %s", resID, createdOrder.ID)
      }
  }
  
  if len(confirmationErrors) > 0 {
      // Log for manual review
      uc.log.WithContext(ctx).Errorf("Some reservations failed to confirm: %v", confirmationErrors)
      // Store in order metadata for manual review
      if createdOrder.Metadata == nil {
          createdOrder.Metadata = make(JSONB)
      }
      createdOrder.Metadata["reservation_confirmation_errors"] = confirmationErrors
      // Update order
      _ = uc.orderUc.UpdateOrder(ctx, createdOrder)
  }
  ```

- [ ] **O1.3.7** Clear cart and checkout session
  - [ ] Update cart status: `checkout` → `completed`
  - [ ] Clear cart items (or mark as completed)
  - [ ] Delete checkout session
  - [ ] **Error Handling**: Log errors but don't fail (order already created)
  
  **Clear Cart:**
  ```go
  // Update cart status to completed
  cart.Status = "completed"
  _ = uc.cartRepo.Update(ctx, cart)
  
  // Clear cart items (or keep for history - optional)
  err = uc.cartRepo.DeleteItemsBySessionID(ctx, req.SessionID)
  if err != nil {
      uc.log.WithContext(ctx).Warnf("Failed to clear cart items: %v", err)
  }
  
  // Delete checkout session
  err = uc.checkoutSessionRepo.DeleteBySessionID(ctx, req.SessionID)
  if err != nil {
      uc.log.WithContext(ctx).Warnf("Failed to delete checkout session: %v", err)
  }
  ```

**Files to modify:**
- `order/internal/biz/checkout.go` - `ConfirmCheckout` method (load from cart, create order, confirm reservations)
- `order/internal/biz/cart.go` - Add methods to convert cart to order, clear cart
- `order/internal/biz/order.go` - `CreateOrder` method (accept reservation IDs from cart)
- `order/internal/biz/order_reservation.go` - Already supports TTL
- `order/internal/client/warehouse_client.go` - Add `ConfirmReservation` method (already exists)

---

### 1.4 Reservation Cleanup & Management (Quote Pattern)

- [ ] **O1.4.1** Update cart cleanup job (replaces draft order cleanup)
  - [ ] Find expired carts in checkout status (`status = 'checkout' AND expires_at < now`)
  - [ ] Release all reservations for expired carts
  - [ ] Update cart status: `checkout` → `abandoned`
  - [ ] Delete expired checkout sessions
  - [ ] **Query**: `SELECT * FROM cart_sessions WHERE status = 'checkout' AND expires_at < NOW()`
  
  **Cleanup Logic:**
  ```go
  // Find expired checkout carts
  expiredCarts, err := uc.cartRepo.FindExpiredCheckout(ctx, time.Now())
  if err != nil {
      return err
  }
  
  for _, cart := range expiredCarts {
      // Get reservation IDs from cart metadata
      reservationIDs := extractReservationIDs(cart.Metadata)
      
      // Release all reservations
      for _, resID := range reservationIDs {
          _ = uc.warehouseInventoryService.ReleaseReservation(ctx, resID)
      }
      
      // Update cart status to abandoned
      cart.Status = "abandoned"
      cart.Metadata = nil // Clear reservation data
      _ = uc.cartRepo.Update(ctx, cart)
      
      // Delete checkout session
      _ = uc.checkoutSessionRepo.DeleteBySessionID(ctx, cart.SessionID)
  }
  ```

- [ ] **O1.4.2** Handle cancelled orders (after order created)
  - [ ] Release reservations when order is cancelled
  - [ ] Clear reservation IDs from order items
  - [ ] Log cancellation with reservation release
  - [ ] **Note**: Only applies to orders that were created (not carts)

- [ ] **O1.4.3** Handle order status changes
  - [ ] Release reservations if order status changes to cancelled
  - [ ] Confirm reservations if order status changes to confirmed
  - [ ] Update reservation status in order metadata

- [ ] **O1.4.4** Abandoned cart cleanup (new)
  - [ ] Find carts in `checkout` status older than 30 minutes
  - [ ] Release reservations
  - [ ] Update cart status to `abandoned`
  - [ ] Track abandoned checkout metrics

**Files to modify:**
- `order/internal/jobs/cart_cleanup.go` - **NEW** Cleanup abandoned checkout carts
- `order/internal/jobs/reservation_cleanup.go` - Update to work with cart reservations
- `order/internal/jobs/session_cleanup.go` - Simplify (no draft order cleanup)
- `order/internal/biz/cancellation/cancellation.go` - Release on cancel (unchanged)
- `order/internal/data/postgres/cart.go` - Add `FindExpiredCheckout` method

---

## 2. Backend: Warehouse Service - Reservation TTL Support

### 2.1 Extend Reservation TTL

- [ ] **W2.1.1** Add `ExtendReservation` endpoint
  - [ ] gRPC method: `ExtendReservation(reservation_id, new_expires_at)`
  - [ ] HTTP endpoint: `PUT /api/v1/reservations/{id}/extend`
  - [ ] Validate reservation exists and is active
  - [ ] Update `expires_at` timestamp

- [ ] **W2.1.2** Add `ConfirmReservation` endpoint
  - [ ] gRPC method: `ConfirmReservation(reservation_id)`
  - [ ] HTTP endpoint: `POST /api/v1/reservations/{id}/confirm`
  - [ ] Convert reservation to committed stock
  - [ ] Deduct from available stock

- [ ] **W2.1.3** Update `ReserveStock` to accept TTL
  - [ ] Add `ttl_minutes` parameter (optional, default 15)
  - [ ] Set `expires_at = now + ttl_minutes`
  - [ ] Return `expires_at` in response

**Files to create/modify:**
- `warehouse/api/warehouse/v1/reservation.proto` - Add extend/confirm methods
- `warehouse/internal/biz/reservation.go` - Implement extend/confirm logic
- `warehouse/internal/service/reservation.go` - Add handlers

---

### 2.2 Reservation Status Tracking

- [ ] **W2.2.1** Add reservation status enum
  - [ ] `pending` - Reserved but not confirmed
  - [ ] `confirmed` - Committed to order
  - [ ] `expired` - TTL expired
  - [ ] `released` - Manually released

- [ ] **W2.2.2** Auto-expire reservations
  - [ ] Background job to expire reservations (expires_at < now)
  - [ ] Update status to `expired`
  - [ ] Release stock back to available

- [ ] **W2.2.3** Reservation query endpoints
  - [ ] Get reservation by ID (with status)
  - [ ] List reservations by order ID
  - [ ] List expired reservations

**Files to modify:**
- `warehouse/internal/model/reservation.go` - Add status field
- `warehouse/internal/jobs/reservation_expiry.go` - Auto-expire job

---

## 3. Frontend: Stock Validation & User Experience

### 3.1 Stock Validation Before Checkout

- [ ] **F3.1.1** Validate stock before starting checkout
  - [ ] Call `/api/v1/cart/validate-stock` endpoint
  - [ ] Show warning if any item is out of stock
  - [ ] Disable checkout button if stock unavailable
  - [ ] Show stock quantity for each item

- [ ] **F3.1.2** Stock validation API integration
  - [ ] Create `validateStock` function in cart API
  - [ ] Handle validation errors
  - [ ] Display stock status in cart UI

**Files to create/modify:**
- `frontend/src/lib/api/cart-api.ts` - Add `validateStock` method
- `frontend/src/components/cart/CartSummary.tsx` - Show stock warnings
- `frontend/src/app/checkout/page.tsx` - Validate before start

---

### 3.2 Real-time Stock Monitoring During Checkout

- [ ] **F3.2.1** Poll stock status during checkout
  - [ ] Poll every 30 seconds while on checkout page
  - [ ] Show warning if stock becomes unavailable
  - [ ] Allow user to update cart if stock changed

- [ ] **F3.2.2** Stock status indicators
  - [ ] Show "In Stock" / "Low Stock" / "Out of Stock" badges
  - [ ] Update indicators in real-time
  - [ ] Highlight items with stock issues

- [ ] **F3.2.3** Handle stock changes gracefully
  - [ ] Show notification if stock changed
  - [ ] Allow user to remove out-of-stock items
  - [ ] Recalculate totals after stock changes

**Files to modify:**
- `frontend/src/app/checkout/page.tsx` - Add stock polling
- `frontend/src/components/checkout/CheckoutItems.tsx` - Show stock status

---

### 3.3 Error Handling for Stock Issues

- [ ] **F3.3.1** Handle stock reservation failures
  - [ ] Show error message if reservation fails
  - [ ] Allow user to retry checkout
  - [ ] Redirect to cart if stock unavailable

- [ ] **F3.3.2** Handle payment failures due to stock
  - [ ] Show clear error message
  - [ ] Release reservations (backend handles)
  - [ ] Allow user to update cart and retry

**Files to modify:**
- `frontend/src/app/checkout/page.tsx` - Error handling
- `frontend/src/components/checkout/CheckoutError.tsx` - Error display

---

## 4. API Endpoints & Integration

### 4.1 New Endpoints

- [ ] **A4.1.1** Stock validation endpoint
  - [ ] `GET /api/v1/cart/validate-stock?session_id={id}&customer_id={id}`
  - [ ] Returns stock status for all cart items
  - [ ] Response: `{ items: [{ product_id, sku, available, reserved, status }] }`

- [ ] **A4.1.2** Extend reservation endpoint (internal)
  - [ ] `PUT /api/v1/reservations/{id}/extend`
  - [ ] Body: `{ expires_at: "ISO8601" }`
  - [ ] Returns updated reservation

- [ ] **A4.1.3** Confirm reservation endpoint (internal)
  - [ ] `POST /api/v1/reservations/{id}/confirm`
  - [ ] Body: `{ order_id: "uuid" }`
  - [ ] Returns confirmed reservation

**Files to create/modify:**
- `order/api/order/v1/cart.proto` - Add `ValidateStock` RPC
- `order/internal/service/cart.go` - Implement `ValidateStock`
- `warehouse/api/warehouse/v1/reservation.proto` - Add extend/confirm

---

### 4.2 Updated Endpoints

- [ ] **A4.2.1** Update `StartCheckout` response
  - [ ] Include reservation IDs in response
  - [ ] Include reservation expiry time
  - [ ] Include stock validation results

- [ ] **A4.2.2** Update `UpdateCheckoutState` to extend reservations
  - [ ] Automatically extend reservations on activity
  - [ ] Return updated reservation expiry times

- [ ] **A4.2.3** Update `ConfirmCheckout` to handle reservations
  - [ ] Extend reservations before payment
  - [ ] Confirm reservations after payment success
  - [ ] Return reservation status in response

**Files to modify:**
- `order/api/order/v1/cart.proto` - Update response messages
- `order/internal/service/checkout.go` - Update handlers

---

## 5. Database & Model Updates (Quote Pattern)

### 5.1 Cart Model Updates (Quote Enhancement)

- [ ] **D5.1.1** Add checkout state fields to cart_sessions (Phase 0 - already done)
  - [x] `status` (VARCHAR) - Cart/quote status: active, checkout, completed, abandoned
  - [x] `shipping_address` (JSONB) - Shipping address
  - [x] `billing_address` (JSONB) - Billing address
  - [x] `payment_method` (VARCHAR) - Payment method
  - [x] `shipping_method_id` (VARCHAR) - Shipping method ID
  - [x] `current_step` (INTEGER) - Current checkout step
  - [x] `reservation_ids` (JSONB) - Array of reservation IDs (in metadata)

- [ ] **D5.1.2** Add reservation mapping to cart metadata
  - [ ] Store `reservation_map` in cart metadata: `{"product_id": reservation_id}`
  - [ ] Store `reservation_expires_at` in cart metadata
  - [ ] Store `checkout_started_at` in cart metadata
  
  **Cart Metadata Structure:**
  ```json
  {
    "reservation_ids": [1001, 1002, 1003],
    "reservation_map": {
      "product-uuid-1": 1001,
      "product-uuid-2": 1002,
      "product-uuid-3": 1003
    },
    "reservation_expires_at": "2025-01-15T10:35:00Z",
    "checkout_started_at": "2025-01-15T10:30:00Z",
    "stock_validated_at": "2025-01-15T10:30:00Z"
  }
  ```

**Migration file:**
- `order/migrations/015_add_checkout_state_to_cart.sql` (Phase 0)

---

### 5.2 Order Model Updates (For Order Creation)

- [ ] **D5.2.1** Ensure order items support reservation IDs
  - [ ] Verify `reservation_id` field exists in `order_items` table
  - [ ] Add index if not exists: `idx_order_items_reservation_id`
  - [ ] **Note**: Order items will get reservation IDs when order is created from cart

- [ ] **D5.2.2** No changes needed to orders table
  - [ ] Orders table structure remains the same
  - [ ] Only confirmed orders are stored (no draft orders)
  - [ ] **Benefit**: Orders table size reduced by 70-90%

**Migration file:**
- `order/migrations/XXX_ensure_reservation_id_in_order_items.sql` (if needed)

---

### 5.3 Checkout Session Updates (Simplified)

- [ ] **D5.3.1** Simplify checkout session (optional - can remove later)
  - [ ] Remove `order_id` field (no draft order to link)
  - [ ] Store `cart_session_id` in metadata instead
  - [ ] **Alternative**: Keep checkout_session for backward compatibility, just don't use order_id

- [ ] **D5.3.2** Add stock validation metadata to checkout session
  - [ ] `stock_validated` (BOOLEAN) - Whether stock was validated
  - [ ] `stock_validation_time` (TIMESTAMP) - Last validation
  - [ ] `stock_warnings` (JSONB) - Stock warnings/errors

**Migration file:**
- `order/migrations/XXX_simplify_checkout_sessions.sql` (optional)

---

## 6. Testing & Validation

### 6.1 Unit Tests

- [ ] **T6.1.1** Test stock reservation in StartCheckout
  - [ ] Test successful reservation
  - [ ] Test reservation failure handling
  - [ ] Test TTL setting

- [ ] **T6.1.2** Test reservation extension
  - [ ] Test TTL extension when active
  - [ ] Test extension failure handling
  - [ ] Test multiple extensions

- [ ] **T6.1.3** Test reservation confirmation
  - [ ] Test confirmation after payment
  - [ ] Test confirmation failure handling
  - [ ] Test reservation release on failure

**Test files:**
- `order/internal/biz/checkout_test.go` - Test StartCheckout (cart status change, no draft order)
- `order/internal/biz/order_reservation_test.go` - Test reservation with TTL
- `order/internal/biz/cart_test.go` - Test cart status transitions

---

### 6.2 Integration Tests

- [ ] **T6.2.1** Test complete checkout flow with stock (Quote Pattern)
  - [ ] Start checkout → Cart status: active → checkout, Reserve stock
  - [ ] Update checkout state → Extend reservations, Save state in cart
  - [ ] Confirm checkout → Create order from cart, Confirm reservations
  - [ ] Verify stock deducted correctly
  - [ ] Verify cart status: checkout → completed
  - [ ] Verify order created with reservation IDs

- [ ] **T6.2.2** Test stock cleanup scenarios (Quote Pattern)
  - [ ] Expired checkout cart → Reservations released, Cart status: checkout → abandoned
  - [ ] Cancelled order → Reservations released (after order created)
  - [ ] Payment failure → Reservations released, Cart status: checkout → active

- [ ] **T6.2.3** Test concurrent checkout scenarios
  - [ ] Multiple users checkout same item
  - [ ] Stock exhaustion during checkout
  - [ ] Race condition handling

- [ ] **T6.2.4** Test cart-to-order conversion
  - [ ] Verify order created with correct items from cart
  - [ ] Verify reservation IDs linked to order items
  - [ ] Verify addresses copied from cart to order
  - [ ] Verify cart cleared after order creation

**Test files:**
- `order/internal/biz/checkout_integration_test.go` - Test complete quote pattern flow
- `order/internal/jobs/cart_cleanup_test.go` - **NEW** Test cart cleanup job
- `order/internal/jobs/reservation_cleanup_test.go` - Test reservation cleanup

---

### 6.3 E2E Tests (Quote Pattern)

- [ ] **T6.3.1** Frontend checkout flow with stock validation
  - [ ] Validate stock before checkout
  - [ ] Start checkout → Cart status changes to checkout
  - [ ] Complete checkout → Order created from cart
  - [ ] Verify cart cleared after order creation
  - [ ] Handle stock unavailable scenario

- [ ] **T6.3.2** Stock monitoring during checkout
  - [ ] Poll stock status
  - [ ] Handle stock changes
  - [ ] Update UI based on stock status

- [ ] **T6.3.3** Abandoned checkout recovery
  - [ ] Start checkout → Cart in checkout status
  - [ ] Wait for expiry (30 minutes)
  - [ ] Verify reservations released
  - [ ] Verify cart status: checkout → abandoned
  - [ ] User can restart checkout (new reservations created)

**Test files:**
- `frontend/src/app/checkout/__tests__/stock-validation.test.tsx`
- `frontend/e2e/checkout-stock.spec.ts`

---

## 7. Monitoring & Observability

### 7.1 Metrics

- [ ] **M7.1.1** Stock reservation metrics
  - [ ] `stock_reservations_total` - Total reservations created
  - [ ] `stock_reservations_success_rate` - Success rate
  - [ ] `stock_reservations_ttl_seconds` - Average TTL
  - [ ] `stock_reservations_extended_total` - Total extensions

- [ ] **M7.1.2** Stock validation metrics
  - [ ] `stock_validations_total` - Total validations
  - [ ] `stock_validations_failed_total` - Failed validations
  - [ ] `stock_out_of_stock_total` - Out of stock events

- [ ] **M7.1.3** Reservation cleanup metrics
  - [ ] `reservations_expired_total` - Expired reservations
  - [ ] `reservations_released_total` - Released reservations
  - [ ] `reservations_orphaned_total` - Orphaned reservations

- [ ] **M7.1.4** Cart/Quote metrics (NEW)
  - [ ] `carts_checkout_total` - Carts entering checkout
  - [ ] `carts_abandoned_total` - Abandoned checkouts
  - [ ] `carts_completed_total` - Completed checkouts (orders created)
  - [ ] `cart_to_order_conversion_rate` - Conversion rate

**Files to modify:**
- `order/internal/observability/prometheus/metrics.go`

---

### 7.2 Logging

- [ ] **L7.2.1** Log stock reservation events
  - [ ] Reservation created (with TTL)
  - [ ] Reservation extended
  - [ ] Reservation confirmed
  - [ ] Reservation released

- [ ] **L7.2.2** Log stock validation events
  - [ ] Stock validation requests
  - [ ] Stock availability changes
  - [ ] Stock warnings

- [ ] **L7.2.3** Log cart/quote state changes (NEW)
  - [ ] Cart status transitions (active → checkout → completed/abandoned)
  - [ ] Reservation IDs stored in cart
  - [ ] Cart-to-order conversion

**Files to modify:**
- `order/internal/biz/checkout.go` - Add structured logging
- `order/internal/biz/cart.go` - Add logging for cart status changes
- `order/internal/biz/order_reservation.go` - Add logging

---

## 8. Documentation

### 8.1 API Documentation

- [ ] **D8.1.1** Document stock validation endpoint
  - [ ] Request/response examples
  - [ ] Error codes
  - [ ] Rate limiting

- [ ] **D8.1.2** Document reservation extension
  - [ ] When to extend
  - [ ] How to extend
  - [ ] Best practices

**Files to update:**
- `docs/openapi/order.openapi.yaml`
- `docs/docs/services/order-service.md`

---

### 8.2 Architecture Documentation

- [ ] **D8.2.1** Document stock management flow (Quote Pattern)
  - [ ] Reservation lifecycle
  - [ ] TTL management
  - [ ] Cleanup process
  - [ ] **Quote pattern**: Cart as quote, no draft orders

- [ ] **D8.2.2** Document error handling
  - [ ] Stock unavailable scenarios
  - [ ] Reservation failures
  - [ ] Recovery procedures

- [ ] **D8.2.3** Document quote pattern migration (NEW)
  - [ ] Why migrate from draft order to quote
  - [ ] Benefits and trade-offs
  - [ ] Migration steps
  - [ ] Data cleanup procedures

**Files to create:**
- `docs/docs/architecture/stock-management-flow.md` (update with quote pattern)
- `docs/docs/processes/checkout-stock-handling.md` (update with quote pattern)
- `docs/docs/architecture/quote-pattern-migration.md` - **NEW** Migration guide

---

## 9. Deployment & Rollout

### 9.1 Pre-deployment

- [ ] **P9.1.1** Database migrations
  - [ ] Run migration for reservation tracking
  - [ ] Verify indexes created
  - [ ] Test rollback procedure

- [ ] **P9.1.2** Warehouse service updates
  - [ ] Deploy warehouse service with TTL support
  - [ ] Verify extend/confirm endpoints
  - [ ] Test reservation expiry job

- [ ] **P9.1.3** Order service updates
  - [ ] Deploy order service with stock reservation
  - [ ] Verify reservation cleanup jobs
  - [ ] Test checkout flow

---

### 9.2 Post-deployment

- [ ] **P9.2.1** Monitor reservation metrics
  - [ ] Check reservation success rate
  - [ ] Monitor reservation TTL
  - [ ] Check cleanup job performance

- [ ] **P9.2.2** Monitor stock validation
  - [ ] Check validation success rate
  - [ ] Monitor out-of-stock events
  - [ ] Check user experience metrics

- [ ] **P9.2.3** Verify cleanup jobs
  - [ ] Check expired reservation cleanup
  - [ ] Verify no orphaned reservations
  - [ ] Check order cancellation cleanup

---

## 10. Rollback Plan

### 10.1 Rollback Scenarios

- [ ] **R10.1.1** Rollback if reservation failures > 5%
  - [ ] Disable pre-reservation in StartCheckout (feature flag)
  - [ ] Fallback to reservation in ConfirmCheckout only
  - [ ] Monitor and fix issues
  - [ ] **Rollback Command**: Set env var `ENABLE_PRE_RESERVATION=false`

- [ ] **R10.1.2** Rollback if cleanup jobs fail
  - [ ] Disable auto-cleanup (stop cleanup jobs)
  - [ ] Manual cleanup procedure (SQL scripts)
  - [ ] Fix cleanup job issues
  - [ ] **Manual Cleanup SQL**:
    ```sql
    -- Release reservations for expired draft orders
    UPDATE stock_reservations sr
    SET status = 'released', updated_at = NOW()
    FROM orders o, order_items oi
    WHERE sr.id = oi.reservation_id
      AND oi.order_id = o.id
      AND o.status = 'draft'
      AND o.expires_at < NOW();
    ```

- [ ] **R10.1.3** Rollback if warehouse service issues
  - [ ] Disable stock validation (feature flag)
  - [ ] Fallback to basic stock check (cart.InStock flag)
  - [ ] Fix warehouse service
  - [ ] **Fallback Logic**: Use `cart.InStock` flag if warehouse service unavailable

---

## 11. Common Pitfalls & Troubleshooting

### 11.1 Common Issues

- [ ] **P11.1.1** Orphaned Reservations
  - **Symptom**: Reservations exist but no associated order
  - **Cause**: Order creation failed after reservation
  - **Fix**: Cleanup job should release orphaned reservations
  - **Prevention**: Always rollback reservations if order creation fails

- [ ] **P11.1.2** Reservation Expired During Checkout
  - **Symptom**: User gets "stock unavailable" error during checkout
  - **Cause**: Reservation expired before user completed checkout
  - **Fix**: Auto-extend reservations on activity
  - **Prevention**: Extend TTL when user is active

- [ ] **P11.1.3** Multiple Draft Orders
  - **Symptom**: Multiple draft orders for same customer
  - **Cause**: StartCheckout called multiple times
  - **Fix**: Cleanup old draft orders before creating new one
  - **Prevention**: Check for existing draft orders in StartCheckout

- [ ] **P11.1.4** Stock Race Condition
  - **Symptom**: Two users checkout same item, both succeed but stock insufficient
  - **Cause**: Stock checked but not reserved atomically
  - **Fix**: Use row-level locks in warehouse service
  - **Prevention**: Reserve stock immediately after validation

- [ ] **P11.1.5** Reservation Not Released on Payment Failure
  - **Symptom**: Reservations not released when payment fails
  - **Cause**: Error handling doesn't release reservations
  - **Fix**: Always release reservations in error paths
  - **Prevention**: Use defer statements for cleanup

### 11.2 Troubleshooting Guide

- [ ] **T11.2.1** Check Reservation Status
  ```sql
  -- Find reservations for an order
  SELECT sr.*, oi.product_id, oi.quantity
  FROM stock_reservations sr
  JOIN order_items oi ON sr.id = oi.reservation_id
  WHERE oi.order_id = 'order-uuid';
  
  -- Find expired reservations
  SELECT sr.*, o.order_number, o.status
  FROM stock_reservations sr
  JOIN order_items oi ON sr.id = oi.reservation_id
  JOIN orders o ON oi.order_id = o.id
  WHERE sr.expires_at < NOW()
    AND sr.status = 'active';
  ```

- [ ] **T11.2.2** Check Draft Orders
  ```sql
  -- Find draft orders with reservations
  SELECT o.*, COUNT(oi.id) as item_count, COUNT(oi.reservation_id) as reservation_count
  FROM orders o
  LEFT JOIN order_items oi ON o.id = oi.order_id
  WHERE o.status = 'draft'
    AND o.expires_at < NOW()
  GROUP BY o.id;
  ```

- [ ] **T11.2.3** Manual Reservation Release
  ```sql
  -- Release specific reservation
  UPDATE stock_reservations
  SET status = 'released', updated_at = NOW()
  WHERE id = reservation_id;
  
  -- Release all reservations for an order
  UPDATE stock_reservations sr
  SET status = 'released', updated_at = NOW()
  FROM order_items oi
  WHERE sr.id = oi.reservation_id
    AND oi.order_id = 'order-uuid';
  ```

- [ ] **T11.2.4** Check Warehouse Service Health
  ```bash
  # Check warehouse service health
  curl http://warehouse-service:8080/health
  
  # Check reservation endpoint
  curl http://warehouse-service:8080/api/v1/reservations/{id}
  ```

### 11.3 Debugging Tips

- [ ] **D11.3.1** Enable Debug Logging
  - Set log level to `DEBUG` for order and warehouse services
  - Log all reservation operations (create, extend, confirm, release)
  - Log stock validation results

- [ ] **D11.3.2** Monitor Metrics
  - `stock_reservations_total` - Total reservations created
  - `stock_reservations_expired_total` - Expired reservations
  - `stock_reservations_orphaned_total` - Orphaned reservations
  - `stock_validation_failures_total` - Validation failures

- [ ] **D11.3.3** Trace Reservation Flow
  - Use distributed tracing (Jaeger) to trace reservation flow
  - Check trace for: StartCheckout → ReserveStock → UpdateCheckoutState → ConfirmCheckout
  - Identify bottlenecks and failures

---

## 📊 Success Criteria

### Must Have (MVP)
- ✅ Stock reserved when checkout starts
- ✅ Reservations extended on user activity
- ✅ Reservations confirmed after payment
- ✅ Expired reservations cleaned up
- ✅ Stock validation before checkout

### Should Have
- ✅ Real-time stock monitoring
- ✅ Reservation TTL management
- ✅ Comprehensive error handling
- ✅ Metrics and monitoring

### Nice to Have
- ⬜ Stock prediction/forecasting
- ⬜ Dynamic TTL based on stock levels
- ⬜ Reservation queuing for high-demand items

---

## 🔗 Related Checklists

- [Checkout Flow Checklist](../checklists-v2/checkout-flow-checklist.md)
- [Stock Order Logic Checklist](../checklists-v2/stock-order-logic-checklist.md)
- [Order Workflow Checklist](../checklists-v2/order-workflow-checklist.md)

---

## 📝 Implementation Notes & Best Practices (Quote Pattern)

### Quote Pattern Benefits
- ✅ **No Draft Orders**: Orders table only contains confirmed orders (70-90% size reduction)
- ✅ **Simpler Cleanup**: Cleanup abandoned carts instead of draft orders
- ✅ **Single Source of Truth**: Cart is the quote, stores all checkout state
- ✅ **Better Performance**: Smaller orders table, faster queries
- ✅ **Easier Resume**: Checkout state in cart, easy to resume

### TTL Strategy
- **Initial TTL**: 5 minutes when checkout starts
- **Extension TTL**: 5 minutes when user is active (extends to 5 min from now)
- **Payment TTL**: 15 minutes before payment processing
- **Max Extensions**: 3 extensions per checkout session (prevent infinite extension)
- **Extension Threshold**: Extend when TTL < 2 minutes remaining

### Extension Frequency
- **On Activity**: Extend every time `UpdateCheckoutState` is called (user is active)
- **Polling**: Frontend should call `UpdateCheckoutState` every 2-3 minutes during checkout
- **Auto-extend**: Backend auto-extends if TTL < 2 minutes (even without activity)

### Cleanup Frequency (Quote Pattern)
- **Cart Cleanup Job**: Run every 5 minutes (replaces draft order cleanup)
  - Find carts in `checkout` status with `expires_at < now`
  - Release reservations, update cart status to `abandoned`
- **Reservation Cleanup Job**: Run every 5 minutes
  - Cleanup orphaned reservations (no associated cart/order)
- **Session Cleanup Job**: Run every 10 minutes
  - Cleanup expired checkout sessions
- **Order Cleanup Job**: Run every 15 minutes (only for cancelled orders)
  - Cleanup cancelled orders and release reservations
- **Cleanup Window**: Process carts/reservations expired in last 10 minutes (buffer)

### Performance Considerations
- **Batch Operations**: Batch check/extend reservations (don't do one-by-one)
- **Parallel Processing**: Check stock for multiple items in parallel
- **Caching**: Cache stock availability for 30 seconds (reduce warehouse service calls)
- **Connection Pooling**: Use connection pooling for warehouse service calls
- **Timeout**: Set 5-second timeout for warehouse service calls (fail fast)

### Security Considerations
- **Reservation Ownership**: Validate reservation belongs to customer/order
- **Rate Limiting**: Limit reservation extensions (max 3 per session)
- **Audit Logging**: Log all reservation operations (create, extend, confirm, release)
- **Input Validation**: Validate TTL values (min 1 minute, max 30 minutes)

### Error Handling Strategy
- **Reservation Failures**: Rollback all reservations if any fails (atomicity)
- **Payment Failures**: Always release reservations (even if payment partially succeeds)
- **Service Unavailable**: Fallback to basic stock check (cart.InStock flag)
- **Timeout Handling**: Retry with exponential backoff (max 3 retries)

### Monitoring & Alerts
- **Reservation Failure Rate**: Alert if > 1% failures
- **Orphaned Reservations**: Alert if > 10 orphaned reservations
- **Extension Failures**: Alert if > 5% extension failures
- **Stock Validation Failures**: Alert if > 2% validation failures
- **Payment with Stock Issues**: Alert if > 0.5% orders have stock issues after payment

### Testing Scenarios (Quote Pattern)
1. **Happy Path**: Start checkout → Cart status: checkout → Reserve stock → Extend TTL → Confirm → Create order → Cart: completed
2. **Stock Unavailable**: Start checkout → Stock unavailable → Return error (cart stays active)
3. **Reservation Expiry**: Start checkout → Wait 5+ minutes → Reservation expired → Cart: checkout → abandoned
4. **Payment Failure**: Start checkout → Reserve stock → Payment fails → Release reservations → Cart: checkout → active
5. **Concurrent Checkout**: Multiple users checkout same item → Only one succeeds
6. **Partial Stock**: Some items available, some not → Handle gracefully
7. **Service Unavailable**: Warehouse service down → Fallback to basic check
8. **Abandoned Checkout**: Start checkout → User leaves → Cart expires → Cleanup job releases reservations → Cart: abandoned
9. **Resume Checkout**: User returns → Load cart in checkout status → Resume from saved state

### Migration Strategy (Quote Pattern - Big Bang)

**Phase 0: Database Migration** (2h)
1. Add checkout state fields to cart_sessions table
2. Update CartSession model
3. Test migration

**Phase 1: Remove Draft Order Creation** (4h)
1. Update StartCheckout: Don't create draft order, update cart status
2. Store reservation IDs in cart metadata
3. Update GetCheckoutState: Load from cart instead of draft order
4. Test checkout flow

**Phase 2: Update ConfirmCheckout** (4h)
1. Load cart instead of draft order
2. Create order from cart after payment success
3. Link reservation IDs to order items
4. Clear cart after order creation
5. Test order creation

**Phase 3: Update Cleanup Jobs** (2h)
1. Replace draft order cleanup with cart cleanup
2. Update reservation cleanup to work with carts
3. Test cleanup jobs

**Phase 4: Remove Draft Order Code** (2h)
1. Remove draft order creation logic
2. Remove checkout_session.order_id dependency
3. Update tests
4. Cleanup unused code

**Total Time**: ~12 hours

### Rollback Plan (Quote Pattern)

**If issues detected:**

1. **Immediate Rollback** (< 5 minutes):
   - Revert code changes (draft order creation)
   - Keep cart enhancements (backward compatible)
   - Restart services

2. **Database Rollback**:
   - Cart migration is backward compatible (new columns nullable)
   - Can keep cart enhancements even if reverting checkout logic
   - No data loss

3. **Gradual Rollback**:
   - Keep cart enhancements
   - Revert to draft order creation temporarily
   - Fix issues and re-enable quote pattern

**Note**: Cart enhancements are backward compatible - can keep them even if reverting checkout logic

---

## 🔍 Code Review Checklist

Before merging, ensure:
- [ ] All error cases are handled
- [ ] All edge cases are covered
- [ ] Logging is comprehensive
- [ ] Metrics are tracked
- [ ] Tests cover all scenarios
- [ ] Documentation is updated
- [ ] Migration scripts are tested
- [ ] Rollback procedure is documented

---

**Last Updated:** 2025-01-15  
**Next Review:** 2025-01-22  
**Version:** 2.0 (Migrated to Quote Pattern - No Draft Orders)

---

## 🔄 Migration Summary: Draft Order → Quote Pattern

### Key Changes

1. **No Draft Orders**: 
   - ❌ Remove: Draft order creation in StartCheckout
   - ✅ Add: Cart status management (active → checkout → completed/abandoned)

2. **Cart as Quote**:
   - ✅ Store checkout state in cart (addresses, payment, shipping)
   - ✅ Store reservation IDs in cart metadata
   - ✅ Cart expiry matches reservation expiry

3. **Order Creation**:
   - ✅ Only create order when checkout confirmed (payment success)
   - ✅ Create order from cart data
   - ✅ Link reservation IDs to order items

4. **Cleanup**:
   - ❌ Remove: Draft order cleanup
   - ✅ Add: Abandoned cart cleanup (checkout status expired)

### Benefits

- **Data Efficiency**: 70-90% reduction in orders table size
- **Simplicity**: No draft order management complexity
- **Performance**: Faster queries on smaller orders table
- **Better UX**: Easier to resume checkout (state in cart)

### Migration Checklist

- [ ] Phase 0: Database migration (cart checkout state fields)
- [ ] Phase 1: Remove draft order creation
- [ ] Phase 2: Update ConfirmCheckout to create from cart
- [ ] Phase 3: Update cleanup jobs
- [ ] Phase 4: Remove unused draft order code
- [ ] Phase 5: Update tests
- [ ] Phase 6: Update documentation

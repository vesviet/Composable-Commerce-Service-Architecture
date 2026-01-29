# Checkout Process Flow

**Last Updated**: 2026-01-29
**Status**: Updated for Service Split
**Domain**: Commerce
**Services**: Checkout Service (Primary), Order Service (Integration), Payment Service
**Navigation**: [← Commerce Domain](../README.md) | [← Business Domains](../../README.md) | [Checkout Service →](../../03-services/core-services/checkout-service.md)

## Overview

This document describes the checkout confirmation flow, which converts a `Cart` into a final `Order`. The implementation follows a "Quote Pattern", where the cart acts as a quote that is finalized upon confirmation.

The core logic is handled within the `order` service.

**Key File**: `order/internal/biz/checkout/confirm.go`

---

## Key Flow Steps

The `ConfirmCheckout` function orchestrates a critical, multi-step process that involves several other services.

1.  **Session & Cart Validation**: The system retrieves the `CheckoutSession` and the associated `CartSession`. It validates that the cart is in the correct `checkout` status.

2.  **Prerequisite Validation**: It ensures all necessary checkout steps have been completed (e.g., shipping address selected).

3.  **Inventory Reservation Extension**: It extends the TTL (Time-To-Live) of any existing inventory reservations to ensure stock is held while payment is processed.

4.  **Final Totals Calculation**: It calls the `calculateTotals` function to get the final, authoritative amount, which includes subtotal, discounts, shipping, and taxes.

5.  **Payment Authorization**: It initiates a payment **authorization** (a hold on the funds) by calling the `payment` service. This does not capture the money yet.

6.  **Order Creation**: If payment authorization is successful, it builds and creates the `Order` in the database. This step is critical as it persists the order record.

7.  **Payment Capture**: After the order is successfully created, it proceeds to **capture** the previously authorized funds. This is the step where money is actually transferred.

8.  **Capture Failure Handling (Compensation)**: If payment capture fails, the system attempts a manual rollback:
    - It calls a `rollbackPaymentAndReservations` function to void the payment authorization.
    - It updates the newly created order's status to `cancelled`.

9.  **Cart & Session Cleanup**: After a successful checkout, the `CartSession` is marked as inactive and the `CheckoutSession` is deleted. This cleanup is designed to be resilient, with retries and alerts if it fails, ensuring it doesn't block the confirmation response to the user.

10. **Event Publishing**: An `OrderCreated` event is published via the Transactional Outbox pattern, ensuring the event is sent reliably after the order is committed to the database.

---

## Additional Checkout Flows

### 11. Start Checkout Flow

- **File**: `start.go`
- **Logic**:
  1. Creates a `CheckoutSession` from active cart
  2. Transitions cart status from `active` → `checkout` 
  3. Locks cart items to prevent modifications
  4. Validates shipping address and payment method
  5. Creates inventory reservations with TTL
  6. Returns checkout session for frontend

### 12. Update Checkout Flow

- **File**: `update.go`
- **Logic**:
  1. Updates shipping address, payment method, or other checkout details
  2. Re-validates inventory availability
  3. Recalculates totals with updated information
  4. Extends reservation TTL if needed

### 13. Preview Order Flow

- **File**: `preview.go` 
- **Logic**:
  1. Provides final order preview before confirmation
  2. Shows exact amounts, taxes, shipping
  3. Validates all prerequisites are met
  4. Does NOT create order or process payment

### 14. Payment Processing Flow

- **File**: `payment.go`
- **Logic**:
  1. **Cash on Delivery (COD)**: Skips payment authorization
  2. **Online Payment**: 
     - Authorizes payment (holds funds)
     - Creates order if authorization succeeds
     - Captures payment after order creation
     - Handles capture failures with compensation

### 15. Checkout Validation Flow

- **File**: `validation.go`
- **Logic**:
  1. **Inventory Validation**: Checks stock availability
  2. **Address Validation**: Validates shipping address format
  3. **Payment Method Validation**: Ensures payment method is active
  4. **Prerequisite Check**: All required steps completed

---

## Sequence Diagrams

### Complete Checkout Confirmation Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gateway
    participant O as Order Service
    participant P as Payment Service
    participant W as Warehouse Service
    participant PR as Pricing Service
    participant PM as Promotion Service
    participant DB as Database
    participant E as Event Bus

    C->>G: POST /checkout/confirm
    G->>O: ConfirmCheckout(sessionID)
    
    Note over O: 1. Session & Cart Validation
    O->>DB: GetCheckoutSession(sessionID)
    O->>DB: GetCartSession(cartSessionID)
    
    Note over O: 2. Prerequisite Validation
    O->>O: ValidateShippingAddress()
    O->>O: ValidatePaymentMethod()
    
    Note over O: 3. Extend Inventory Reservations
    O->>W: ExtendReservation(items, newTTL)
    W-->>O: ReservationExtended
    
    Note over O: 4. Final Totals Calculation
    O->>PR: CalculateFinalPrice(cart)
    O->>PM: ValidatePromotions(cart)
    O->>PR: CalculateTax(cart, location)
    
    par Parallel Calculations
        PR-->>O: FinalPricing
    and
        PM-->>O: FinalDiscounts
    and
        PR-->>O: TaxAmount
    end
    
    Note over O: 5. Payment Authorization
    alt COD Payment
        O->>O: SkipPaymentAuth()
    else Online Payment
        O->>P: AuthorizePayment(amount, method)
        P-->>O: AuthorizationResult
        
        alt Authorization Failed
            O-->>C: PaymentAuthFailed
        end
    end
    
    Note over O: 6. Order Creation
    O->>DB: CreateOrder(orderData)
    DB-->>O: OrderCreated(orderID)
    
    Note over O: 7. Payment Capture
    alt COD Payment
        O->>O: SetPaymentPending()
    else Online Payment
        O->>P: CapturePayment(authID, amount)
        P-->>O: CaptureResult
        
        alt Capture Failed
            Note over O: 8. Compensation
            O->>P: VoidAuthorization(authID)
            O->>DB: UpdateOrderStatus(cancelled)
            O-->>C: CheckoutFailed
        end
    end
    
    Note over O: 9. Success - Cleanup & Events
    O->>DB: DeactivateCartSession()
    O->>DB: DeleteCheckoutSession()
    O->>E: PublishEvent(OrderCreated)
    
    O-->>G: CheckoutSuccess(order)
    G-->>C: OrderConfirmation
```

### Start Checkout Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant O as Order Service
    participant W as Warehouse Service
    participant DB as Database
    participant Cache as Redis

    C->>O: StartCheckout(cartSessionID)
    
    O->>DB: GetCartSession(cartSessionID)
    O->>O: ValidateCartActive()
    
    Note over O: Lock Cart Items
    O->>DB: UpdateCartStatus(checkout)
    
    Note over O: Create Reservations
    loop For each cart item
        O->>W: ReserveStock(productID, quantity, TTL)
        W-->>O: ReservationCreated
    end
    
    Note over O: Create Checkout Session
    O->>DB: CreateCheckoutSession()
    O->>Cache: InvalidateCart(sessionID)
    
    O-->>C: CheckoutSession
```

### Payment Authorization & Capture Flow

```mermaid
sequenceDiagram
    participant O as Order Service
    participant P as Payment Service
    participant DB as Database
    participant PG as Payment Gateway

    O->>P: AuthorizePayment(amount, method)
    P->>PG: CreateAuthorization()
    PG-->>P: AuthResult(authID, status)
    
    alt Authorization Success
        P-->>O: AuthorizeSuccess(authID)
        
        Note over O: Create Order in DB
        O->>DB: CreateOrder()
        
        Note over O: Capture Payment
        O->>P: CapturePayment(authID, amount)
        P->>PG: CaptureAuthorization(authID)
        
        alt Capture Success
            PG-->>P: CaptureSuccess
            P-->>O: CaptureSuccess
        else Capture Failed
            PG-->>P: CaptureFailed
            P-->>O: CaptureFailed
            
            Note over O: Compensation
            O->>P: VoidAuthorization(authID)
            O->>DB: UpdateOrderStatus(cancelled)
        end
    else Authorization Failed
        P-->>O: AuthorizeFailed
    end
```

### Error Recovery & Compensation Flow

```mermaid
flowchart TD
    A[Checkout Confirm] --> B{Payment Auth}
    B -->|Success| C[Create Order]
    B -->|Failed| D[Return Auth Error]
    
    C --> E{Order Created?}
    E -->|Success| F[Capture Payment]
    E -->|Failed| G[Return Order Error]
    
    F --> H{Capture Success?}
    H -->|Success| I[Cleanup & Events]
    H -->|Failed| J[Start Compensation]
    
    J --> K[Void Authorization]
    K --> L[Cancel Order]
    L --> M[Alert DLQ]
    
    I --> N[Order Complete]
    
    D --> O[End - Failed]
    G --> O
    M --> P[End - Compensated]
```

Based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

### P1 - Atomicity: Manual Distributed Transaction

- **Description**: The `Authorize -> Create Order -> Capture` sequence is a distributed transaction handled manually. This creates a risk of inconsistent states if the service crashes between these critical steps. For example, an order could be created but the payment never captured, leaving the order in a limbo state without a robust, automated recovery process.
- **Recommendation**: Replace the manual sequence with a durable Saga orchestration pattern. A Saga would ensure that the entire process either completes successfully or is properly compensated (e.g., the order is cancelled if capture fails), even in the event of service restarts.

### P1 - Resilience: Ignored Rollback Errors

- **Description**: In the payment capture failure path, the error from the compensating action (`rollbackPaymentAndReservations`) is ignored (`_ = ...`). If voiding the payment authorization fails, the customer's funds could remain on hold for an order that was ultimately cancelled.
- **Recommendation**: The error from compensating actions must be handled. A failed rollback is a critical event that should be sent to a Dead-Letter Queue (DLQ) and trigger an immediate alert for manual intervention.

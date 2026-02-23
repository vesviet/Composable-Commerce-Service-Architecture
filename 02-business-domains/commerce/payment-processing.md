# Payment Flow

## 1. Overview
The **Payment Service** handles multiple payment methods, gateway integrations (Stripe, PayPal, VNPay, MoMo), and ensures transaction integrity via the **Outbox Pattern** and **Idempotency**.

**Architecture**: Event-driven microservices with distributed transaction support via Saga pattern
**Security**: PCI DSS Level 1 compliance, tokenization, fraud detection
**Gateways**: Multi-provider support with circuit breakers and failover

## 2. Actors & Services
- **Customer/Client**: Initiates payment via Web/Mobile App
- **Gateway Service**: Routes payment requests, handles authentication, rate limiting
- **Order Service**: Orchestrates checkout process and requests payment authorization/capture
- **Payment Service**: Core payment processing, gateway management, compliance
- **Payment Gateways**: External providers (Stripe, PayPal, VNPay, MoMo)
- **Background Workers**: Handles asynchronous events (webhooks, outbox events, reconciliation)

## 3. Core Payment Flows

### 3.1. Payment Authorization Flow (Checkout)
This flow occurs when the customer clicks "Place Order" during checkout.

```mermaid
sequenceDiagram
    participant C as Customer
    participant G as Gateway
    participant O as Order Service
    participant P as Payment Service
    participant I as Idempotency (Redis)
    participant PG as Gateway (Stripe/PayPal)
    participant DB as Payment DB
    participant E as Event Bus

    C->>G: POST /checkout/confirm (payment_method_id)
    G->>G: Validate JWT, Rate Limit
    G->>O: Confirm Checkout Request
    
    rect rgb(240, 248, 255)
    note right of O: Order Orchestration
    O->>O: Validate Cart & Inventory
    O->>O: Calculate Final Totals
    O->>P: AuthorizePayment(order_id, amount, payment_method)
    end
    
    rect rgb(255, 250, 240)
    note right of P: Payment Processing
    P->>P: Validate Customer & Order
    P->>P: Fraud Detection (Rules Engine)
    P->>I: Check Idempotency Key
    
    alt Idempotency Hit
        I-->>P: Return Cached Response
    else New Request
        P->>DB: Transaction Start
        P->>DB: Create Payment(Status=PENDING)
        
        P->>PG: Create PaymentIntent/Authorization
        alt Success
            PG-->>P: Payment Authorized (auth_id)
            P->>DB: Update Payment(Status=AUTHORIZED)
            P->>DB: Create Transaction Record
            P->>DB: Write Outbox Event (PaymentAuthorized)
            P->>DB: Transaction Commit
            P->>I: Cache Response (24h TTL)
            P-->>O: Success (auth_id, payment_id)
        else Failure
            PG-->>P: Payment Declined
            P->>DB: Update Payment(Status=FAILED, failure_reason)
            P->>DB: Write Outbox Event (PaymentFailed)
            P->>DB: Transaction Commit
            P-->>O: Error (failure_reason)
        end
    end
    
    alt Authorization Success
        O->>O: Create Order (Status=CONFIRMED)
        O->>P: CapturePayment(auth_id, order_id)
        P->>PG: Capture Payment
        PG-->>P: Payment Captured
        P->>DB: Update Payment(Status=CAPTURED)
        P->>E: Publish PaymentCaptured Event
        O-->>G: Order Success
        G-->>C: Order Confirmation
    else Authorization Failed
        O-->>G: Payment Error
        G-->>C: Payment Failed
    end
```

### 3.2. Payment Capture Flow
After successful authorization, capture transfers funds from customer to merchant.

```mermaid
sequenceDiagram
    participant O as Order Service
    participant P as Payment Service
    participant PG as Payment Gateway
    participant DB as Payment DB
    participant E as Event Bus
    
    O->>P: CapturePayment(auth_id, order_id, final_amount)
    P->>P: Validate Authorization exists
    P->>P: Check capture amount <= authorized amount
    
    P->>DB: Transaction Start
    P->>PG: Capture Payment (auth_id, amount)
    
    alt Capture Success
        PG-->>P: Capture Successful (txn_id)
        P->>DB: Update Payment(Status=CAPTURED, captured_at=now)
        P->>DB: Create Transaction(type=CAPTURE, amount, txn_id)
        P->>DB: Write Outbox Event (PaymentCaptured)
        P->>DB: Transaction Commit
        P-->>O: Capture Success
        
        note over E: Async Event Processing
        E->>E: PaymentCaptured Event
        E->>O: Update Order Status
        E->>Customer: Send Payment Confirmation
        E->>Analytics: Record Payment Metrics
        
    else Capture Failed
        PG-->>P: Capture Failed (reason)
        P->>DB: Update Payment(Status=CAPTURE_FAILED, failure_reason)
        P->>DB: Write Outbox Event (PaymentCaptureFailed)
        P->>DB: Transaction Commit
        P-->>O: Capture Failed
        
        note over O: Compensation
        O->>P: VoidPayment(auth_id) // Release authorization
        O->>O: Mark Order as Failed
    end
```

### 3.3. Refund Processing Flow
Processes customer refunds for captured payments.

```mermaid
sequenceDiagram
    participant A as Admin/CS
    participant G as Gateway
    participant P as Payment Service
    participant PG as Payment Gateway
    participant DB as Payment DB
    participant E as Event Bus
    
    A->>G: POST /admin/payments/{id}/refund
    G->>G: Validate Admin Authorization
    G->>P: ProcessRefund(payment_id, amount, reason)
    
    P->>P: Validate Payment is CAPTURED
    P->>P: Check refund amount <= captured amount
    P->>P: Calculate remaining refundable amount
    
    P->>DB: Transaction Start
    P->>DB: Create Refund Record(Status=PENDING)
    
    P->>PG: Process Refund (payment_id, amount)
    alt Refund Success
        PG-->>P: Refund Processed (refund_id)
        P->>DB: Update Refund(Status=COMPLETED, gateway_refund_id)
        P->>DB: Update Payment(refunded_amount += amount)
        P->>DB: Create Transaction(type=REFUND, amount)
        P->>DB: Write Outbox Event (PaymentRefunded)
        P->>DB: Transaction Commit
        P-->>G: Refund Success
        G-->>A: Refund Processed
        
        note over E: Async Processing
        E->>Customer: Refund Notification
        E->>Order: Update Order Status
        E->>Analytics: Record Refund Metrics
        
    else Refund Failed
        PG-->>P: Refund Failed (reason)
        P->>DB: Update Refund(Status=FAILED, failure_reason)
        P->>DB: Transaction Commit
        P-->>G: Refund Failed
        G-->>A: Refund Error
    end
```

### 3.4. Webhook Processing Flow
Handles asynchronous notifications from payment gateways.

```mermaid
sequenceDiagram
    participant PG as Payment Gateway
    participant G as Gateway
    participant P as Payment Service
    participant DB as Payment DB
    participant E as Event Bus
    
    PG->>G: POST /webhooks/stripe (event payload)
    G->>G: Rate Limit & Basic Validation
    G->>P: ProcessWebhook(provider, payload, signature)
    
    P->>P: Validate Webhook Signature
    P->>P: Parse Event (payment.succeeded, charge.dispute.created)
    P->>P: Extract Payment Identifier
    
    P->>DB: Find Payment by Gateway ID
    alt Payment Found
        P->>DB: Transaction Start
        
        alt Event: payment_intent.succeeded
            P->>DB: Update Payment(Status=CAPTURED)
            P->>DB: Write Outbox Event (PaymentCaptured)
        else Event: payment_intent.payment_failed
            P->>DB: Update Payment(Status=FAILED, failure_reason)
            P->>DB: Write Outbox Event (PaymentFailed)
        else Event: charge.dispute.created
            P->>DB: Create Dispute Record
            P->>DB: Update Payment(dispute_status=OPEN)
            P->>DB: Write Outbox Event (DisputeCreated)
        end
        
        P->>DB: Create Webhook Log (processed)
        P->>DB: Transaction Commit
        P-->>G: Webhook Processed
        
        note over E: Event Publishing
        E->>Order: Update Order Status
        E->>Customer: Send Notifications
        E->>Admin: Alert for Disputes
        
    else Payment Not Found
        P->>DB: Create Webhook Log (payment_not_found)
        P-->>G: Payment Not Found (200 OK)
    end
```

### 3.5. 3D Secure Authentication Flow
Handles Strong Customer Authentication (SCA) requirements.

```mermaid
sequenceDiagram
    participant C as Customer
    participant F as Frontend
    participant G as Gateway
    participant P as Payment Service
    participant PG as Payment Gateway
    participant Bank as Issuing Bank
    
    C->>F: Submit Payment
    F->>G: POST /payment/process
    G->>P: ProcessPayment (card details)
    
    P->>PG: Create PaymentIntent
    PG->>Bank: Check 3DS Requirement
    Bank-->>PG: 3DS Required
    PG-->>P: PaymentIntent (requires_action, client_secret)
    P-->>G: Payment Requires Action
    G-->>F: 3DS Challenge Required
    
    F->>C: Display 3DS Challenge
    C->>Bank: Complete Authentication
    Bank-->>C: Authentication Result
    
    C->>F: Submit Authentication
    F->>G: POST /payment/confirm (client_secret)
    G->>P: ConfirmPayment (client_secret)
    P->>PG: Confirm PaymentIntent
    
    alt 3DS Success
        PG-->>P: Payment Succeeded
        P->>P: Update Payment(Status=AUTHORIZED)
        P-->>G: Payment Success
        G-->>F: Payment Confirmed
        F-->>C: Payment Success
    else 3DS Failed
        PG-->>P: Payment Failed (authentication_failed)
        P->>P: Update Payment(Status=FAILED)
        P-->>G: Payment Failed
        G-->>F: Payment Declined
        F-->>C: Payment Failed
    end
```

### 3.6. Payment Method Tokenization Flow
Securely stores payment methods for future use.

```mermaid
sequenceDiagram
    participant C as Customer
    participant F as Frontend
    participant G as Gateway
    participant P as Payment Service
    participant PG as Payment Gateway
    participant PM as PaymentMethod DB
    
    C->>F: Add Payment Method
    F->>G: POST /payment-methods/save
    G->>G: Validate Customer JWT
    G->>P: SavePaymentMethod (card_data, customer_id)
    
    P->>P: Validate Card Format
    P->>PG: Create PaymentMethod Token
    
    alt Tokenization Success
        PG-->>P: PaymentMethod Created (token_id)
        P->>PM: Store PaymentMethod(customer_id, token_id, card_last4, card_brand)
        P->>P: Hash & Encrypt Sensitive Data
        P-->>G: PaymentMethod Saved
        G-->>F: Success (payment_method_id)
        F-->>C: Payment Method Added
    else Tokenization Failed
        PG-->>P: Invalid Card Data
        P-->>G: Validation Error
        G-->>F: Card Invalid
        F-->>C: Please Check Card Details
    end
    
    note over P: Future Payments
    C->>F: Use Saved Payment Method
    F->>G: POST /payment/process (payment_method_id)
    G->>P: ProcessPayment (payment_method_id)
    P->>PM: Get PaymentMethod by ID
    P->>PG: Process Payment (token_id)
    PG-->>P: Payment Processed
```

### 3.7. Cash on Delivery (COD) Flow
Handles offline payment processing for COD orders.

```mermaid
sequenceDiagram
    participant C as Customer
    participant O as Order Service
    participant P as Payment Service
    participant F as Fulfillment
    participant D as Delivery
    participant DB as Payment DB
    
    C->>O: Checkout with COD
    O->>P: CreateCODPayment(order_id, amount)
    
    P->>DB: Create Payment(Status=PENDING, method=COD)
    P-->>O: COD Payment Created
    O->>O: Create Order (Status=CONFIRMED)
    O->>F: Prepare Order for Fulfillment
    
    F->>F: Pick & Pack Order
    F->>D: Schedule Delivery
    D->>D: Out for Delivery
    
    D->>C: Deliver Order + Collect Payment
    alt Payment Collected
        D->>D: Payment Received (cash)
        D->>P: ConfirmCODPayment(order_id, amount_collected)
        P->>DB: Update Payment(Status=CAPTURED, captured_at=now)
        P->>DB: Write Outbox Event (PaymentCaptured)
        P-->>D: COD Payment Confirmed
        D->>F: Delivery Completed
    else Payment Not Collected
        D->>F: Return Order (payment_failed)
        D->>P: FailCODPayment(order_id, reason)
        P->>DB: Update Payment(Status=FAILED, failure_reason)
        P->>DB: Write Outbox Event (PaymentFailed)
        F->>O: Return Order to Inventory
    end
```
    else Failure
        G-->>P: Error / Declined
        P->>DB: Update Payment(Status=FAILED)
        P->>DB: Write Outbox Event (PaymentFailed)
        P->>DB: Transaction Commit
        P->>I: MarkFailed(error)
        P-->>O: Error
    end
    end
```

### 3.2. Payment Capture (Post-Fulfillment)
This flow typically happens when the warehouse confirms shipment, or immediately if `AutoCapture` is enabled.

1. **Trigger**: `Fulfillment Service` (or Order Service) requests capture after shipping.
2. **Action**: `PaymentService.CapturePayment(payment_id, amount)`.
3. **Logic**:
    - Validate status is `AUTHORIZED`.
    - Call `Gateway.CapturePayment`.
    - Update status to `CAPTURED`.
    - Publish `PaymentCaptured` event.

### 3.3. Asynchronous Webhooks
Gateways send webhooks for status updates (e.g., async payment method success, refunds, chargebacks).

1. **Endpoint**: `POST /api/v1/webhooks/{provider}`
2. **Security**: Validate signature (Note: PayPal currently has partial validation).
3. **Processing**:
    - Identify Payment ID from payload.
    - Map gateway status to internal status.
    - Update `Payment` record.
    - Publish `PaymentStatusChanged` event via Outbox.

## 4. Key Mechanics

### 4.1. Idempotency (Redis)
- Prevents double-charging for the same request.
- **Keys**: `payment:idempotency:{scope}:{key}`
- **TTL**: 24 hours.
- **States**: `in_progress`, `completed` (returns cached response), `failed` (allows retry).

### 4.2. Transactional Outbox
- Ensures distributed data consistency.
- Events (`PaymentProcessed`, `PaymentFailed`) are written to `outbox` table in the same DB transaction as the Payment record update.
- **Worker** processes outbox table and publishes to Dapr PubSub.

### 4.3. Circuit Breaker
- Protects the system from cascading failures when Gateways are down.
- Implemented per-gateway using `Internal/Client/CircuitBreaker`.
- Wraps all external gateway calls.

## 5. State Machine

- **PENDING**: Initial state created in DB.
- **AUTHORIZED**: Funds reserved (Hold).
- **CAPTURED**: Funds transferred to merchant.
- **FAILED**: Gateway declined or error.
- **CANCELLED**: User cancelled or voided before capture.
- **REFUNDED**: Post-capture return.
- **REQUIRES_ACTION**: 3D Secure / Redirect flow needed.

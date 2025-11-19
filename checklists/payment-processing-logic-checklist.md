# 💳 Payment Processing Logic Checklist

**Service:** Payment Service  
**Created:** 2025-11-19  
**Status:** 🟡 **Implementation Required**  
**Priority:** 🔴 **Critical**  
**Compliance:** PCI DSS Level 1

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Payment Methods](#payment-methods)
3. [Payment Flow & States](#payment-flow--states)
4. [Payment Gateway Integration](#payment-gateway-integration)
5. [Security & Compliance](#security--compliance)
6. [Fraud Detection](#fraud-detection)
7. [Refund & Cancellation](#refund--cancellation)
8. [Webhook Handling](#webhook-handling)
9. [Payment Retry Logic](#payment-retry-logic)
10. [Multi-Currency Support](#multi-currency-support)
11. [Testing & Validation](#testing--validation)

---

## 🎯 Overview

Payment processing là critical path trong e-commerce. Một lỗi nhỏ có thể:
- ❌ Mất doanh thu
- ❌ Mất niềm tin khách hàng
- ❌ Vi phạm PCI DSS (phạt nặng)
- ❌ Bị hack, mất tiền

**Key Requirements:**
- **Security:** PCI DSS Level 1 compliance
- **Availability:** 99.99% uptime
- **Performance:** Payment processing <3s (p95)
- **Accuracy:** 100% payment reconciliation
- **Fraud Prevention:** <0.1% fraud rate

**Critical Metrics:**
- Payment success rate: >95%
- Payment authorization time: <2s
- Payment capture time: <1s
- Refund processing time: <24h
- False positive fraud rate: <1%

---

## 1. Payment Methods

### 1.1 Credit/Debit Card

**Requirements:**

- [ ] **R1.1.1** Support major card networks (Visa, Mastercard, Amex, Discover)
- [ ] **R1.1.2** Card number validation (Luhn algorithm)
- [ ] **R1.1.3** CVV validation
- [ ] **R1.1.4** Expiry date validation
- [ ] **R1.1.5** Card type detection (BIN lookup)
- [ ] **R1.1.6** 3D Secure (3DS) authentication
- [ ] **R1.1.7** Card tokenization (no raw card data storage)
- [ ] **R1.1.8** Saved card management
- [ ] **R1.1.9** Card verification (AVS - Address Verification System)

**Implementation:**

```go
type CreditCardPayment struct {
    // Never store raw card data!
    CardToken       string                 // Tokenized card from gateway
    CardBrand       string                 // "visa", "mastercard", "amex"
    Last4Digits     string                 // Last 4 digits for display
    ExpiryMonth     int                    // 1-12
    ExpiryYear      int                    // YYYY
    CardholderName  string
    
    // Billing address for AVS
    BillingAddress  *Address
    
    // 3D Secure
    Require3DS      bool
    ThreeDSStatus   string                 // "authenticated", "attempted", "failed"
    
    // Metadata
    BIN             string                 // First 6 digits (for fraud check)
    IssuerCountry   string
    CardLevel       string                 // "standard", "premium", "corporate"
}

func (uc *PaymentUseCase) ProcessCreditCardPayment(ctx context.Context, req *CreditCardPaymentRequest) (*PaymentResult, error) {
    // 1. Validate card details (client-side should do first, but double-check)
    if err := uc.validateCreditCard(req); err != nil {
        return nil, err
    }
    
    // 2. Tokenize card if not already tokenized
    var cardToken string
    if req.CardToken == "" {
        token, err := uc.gateway.TokenizeCard(ctx, &TokenizeCardRequest{
            CardNumber:     req.CardNumber,
            CVV:            req.CVV,
            ExpiryMonth:    req.ExpiryMonth,
            ExpiryYear:     req.ExpiryYear,
            CardholderName: req.CardholderName,
        })
        if err != nil {
            return nil, &PaymentError{
                Code:    "CARD_TOKENIZATION_FAILED",
                Message: "Failed to process card details",
                Err:     err,
            }
        }
        cardToken = token.Token
    } else {
        cardToken = req.CardToken
    }
    
    // 3. Check if 3D Secure is required
    require3DS := uc.shouldRequire3DS(req.Amount, req.CardBrand, req.IssuerCountry)
    
    if require3DS && req.ThreeDSStatus != "authenticated" {
        // Return 3DS challenge
        threeDSChallenge, err := uc.gateway.Create3DSChallenge(ctx, &Create3DSRequest{
            CardToken:  cardToken,
            Amount:     req.Amount,
            Currency:   req.Currency,
            ReturnURL:  req.ReturnURL,
        })
        
        if err != nil {
            return nil, err
        }
        
        return &PaymentResult{
            Status:           "requires_action",
            RequiresAction:   true,
            ActionType:       "3ds_authentication",
            ThreeDSChallenge: threeDSChallenge,
        }, nil
    }
    
    // 4. Run fraud check
    fraudCheck, err := uc.fraudDetector.CheckPayment(ctx, &FraudCheckRequest{
        Amount:         req.Amount,
        Currency:       req.Currency,
        CardBIN:        req.BIN,
        CustomerID:     req.CustomerID,
        IPAddress:      req.IPAddress,
        BillingAddress: req.BillingAddress,
        ShippingAddress: req.ShippingAddress,
    })
    
    if err != nil {
        uc.log.Errorf("Fraud check failed: %v", err)
        // Don't block payment, but log warning
    }
    
    if fraudCheck != nil && fraudCheck.RiskLevel == "high" {
        // Block high-risk payments
        return nil, &PaymentError{
            Code:    "PAYMENT_BLOCKED_FRAUD",
            Message: "Payment blocked due to high fraud risk",
            FraudScore: fraudCheck.Score,
        }
    }
    
    // 5. Authorize payment
    authResult, err := uc.gateway.AuthorizePayment(ctx, &AuthorizePaymentRequest{
        CardToken:       cardToken,
        Amount:          req.Amount,
        Currency:        req.Currency,
        OrderID:         req.OrderID,
        CustomerID:      req.CustomerID,
        BillingAddress:  req.BillingAddress,
        Metadata:        req.Metadata,
        ThreeDSStatus:   req.ThreeDSStatus,
    })
    
    if err != nil {
        return nil, uc.handleGatewayError(err)
    }
    
    // 6. Create payment record
    payment := &Payment{
        ID:              uuid.New().String(),
        OrderID:         req.OrderID,
        CustomerID:      req.CustomerID,
        Method:          "credit_card",
        Amount:          req.Amount,
        Currency:        req.Currency,
        Status:          "authorized",
        GatewayTxnID:    authResult.TransactionID,
        GatewayResponse: authResult.RawResponse,
        CardLast4:       req.Last4,
        CardBrand:       req.CardBrand,
        FraudScore:      fraudCheck.Score,
        FraudLevel:      fraudCheck.RiskLevel,
        CreatedAt:       time.Now(),
        UpdatedAt:       time.Now(),
    }
    
    if err := uc.repo.CreatePayment(ctx, payment); err != nil {
        // Payment authorized but failed to save - critical!
        uc.log.Errorf("CRITICAL: Payment authorized but failed to save: %v", err)
        uc.alerting.SendCriticalAlert("Payment record creation failed", payment)
        return nil, err
    }
    
    // 7. Publish event
    uc.publishEvent(ctx, "payment.authorized", payment)
    
    return &PaymentResult{
        Status:      "authorized",
        PaymentID:   payment.ID,
        TxnID:       authResult.TransactionID,
        Amount:      req.Amount,
        Currency:    req.Currency,
    }, nil
}

// Card validation
func (uc *PaymentUseCase) validateCreditCard(req *CreditCardPaymentRequest) error {
    // Validate card number with Luhn algorithm
    if !uc.validateLuhn(req.CardNumber) {
        return &ValidationError{
            Field:   "card_number",
            Message: "Invalid card number",
        }
    }
    
    // Validate expiry date
    if req.ExpiryYear < time.Now().Year() {
        return &ValidationError{
            Field:   "expiry_year",
            Message: "Card has expired",
        }
    }
    
    if req.ExpiryYear == time.Now().Year() && req.ExpiryMonth < int(time.Now().Month()) {
        return &ValidationError{
            Field:   "expiry_month",
            Message: "Card has expired",
        }
    }
    
    // Validate CVV length
    cvvLength := len(req.CVV)
    if req.CardBrand == "amex" && cvvLength != 4 {
        return &ValidationError{
            Field:   "cvv",
            Message: "CVV must be 4 digits for American Express",
        }
    }
    
    if req.CardBrand != "amex" && cvvLength != 3 {
        return &ValidationError{
            Field:   "cvv",
            Message: "CVV must be 3 digits",
        }
    }
    
    return nil
}

// Luhn algorithm for card validation
func (uc *PaymentUseCase) validateLuhn(cardNumber string) bool {
    // Remove spaces and dashes
    cardNumber = strings.ReplaceAll(cardNumber, " ", "")
    cardNumber = strings.ReplaceAll(cardNumber, "-", "")
    
    sum := 0
    alternate := false
    
    for i := len(cardNumber) - 1; i >= 0; i-- {
        digit := int(cardNumber[i] - '0')
        
        if alternate {
            digit *= 2
            if digit > 9 {
                digit -= 9
            }
        }
        
        sum += digit
        alternate = !alternate
    }
    
    return sum%10 == 0
}
```

**Test Scenarios:**

- [ ] **T1.1.1** Process valid Visa card
- [ ] **T1.1.2** Process valid Mastercard
- [ ] **T1.1.3** Process valid Amex card
- [ ] **T1.1.4** Reject invalid card number (Luhn fails)
- [ ] **T1.1.5** Reject expired card
- [ ] **T1.1.6** Reject invalid CVV
- [ ] **T1.1.7** 3DS authentication required
- [ ] **T1.1.8** 3DS authentication successful
- [ ] **T1.1.9** 3DS authentication failed
- [ ] **T1.1.10** Save card for future use
- [ ] **T1.1.11** Use saved card token
- [ ] **T1.1.12** High fraud score blocks payment

---

### 1.2 Digital Wallets (PayPal, Apple Pay, Google Pay)

**Requirements:**

- [ ] **R1.2.1** PayPal integration
- [ ] **R1.2.2** Apple Pay integration
- [ ] **R1.2.3** Google Pay integration
- [ ] **R1.2.4** Token-based authentication
- [ ] **R1.2.5** Redirect flow handling
- [ ] **R1.2.6** Webhook verification

**Implementation:**

```go
type DigitalWalletPayment struct {
    WalletType      string                 // "paypal", "apple_pay", "google_pay"
    WalletToken     string                 // Wallet-specific token
    PayerEmail      string                 // Payer's email
    PayerID         string                 // Wallet-specific payer ID
}

func (uc *PaymentUseCase) ProcessDigitalWallet(ctx context.Context, req *DigitalWalletPaymentRequest) (*PaymentResult, error) {
    switch req.WalletType {
    case "paypal":
        return uc.processPayPal(ctx, req)
    case "apple_pay":
        return uc.processApplePay(ctx, req)
    case "google_pay":
        return uc.processGooglePay(ctx, req)
    default:
        return nil, ErrUnsupportedWallet
    }
}

func (uc *PaymentUseCase) processPayPal(ctx context.Context, req *DigitalWalletPaymentRequest) (*PaymentResult, error) {
    // 1. Create PayPal order
    paypalOrder, err := uc.paypalClient.CreateOrder(ctx, &paypal.CreateOrderRequest{
        Amount:      req.Amount,
        Currency:    req.Currency,
        OrderID:     req.OrderID,
        ReturnURL:   req.ReturnURL,
        CancelURL:   req.CancelURL,
    })
    
    if err != nil {
        return nil, err
    }
    
    // 2. Return approval URL for redirect
    return &PaymentResult{
        Status:         "requires_action",
        RequiresAction: true,
        ActionType:     "redirect",
        RedirectURL:    paypalOrder.ApprovalURL,
        PayPalOrderID:  paypalOrder.ID,
    }, nil
}

func (uc *PaymentUseCase) CompletePayPalPayment(ctx context.Context, paypalOrderID string) (*PaymentResult, error) {
    // 1. Capture PayPal payment
    captureResult, err := uc.paypalClient.CaptureOrder(ctx, paypalOrderID)
    if err != nil {
        return nil, err
    }
    
    // 2. Create payment record
    payment := &Payment{
        ID:              uuid.New().String(),
        OrderID:         captureResult.OrderID,
        Method:          "paypal",
        Amount:          captureResult.Amount,
        Currency:        captureResult.Currency,
        Status:          "completed",
        GatewayTxnID:    captureResult.CaptureID,
        PayPalOrderID:   paypalOrderID,
        PayerEmail:      captureResult.PayerEmail,
        CreatedAt:       time.Now(),
        UpdatedAt:       time.Now(),
    }
    
    if err := uc.repo.CreatePayment(ctx, payment); err != nil {
        return nil, err
    }
    
    // 3. Publish event
    uc.publishEvent(ctx, "payment.completed", payment)
    
    return &PaymentResult{
        Status:    "completed",
        PaymentID: payment.ID,
        TxnID:     captureResult.CaptureID,
    }, nil
}
```

**Test Scenarios:**

- [ ] **T1.2.1** PayPal order creation
- [ ] **T1.2.2** PayPal payment capture
- [ ] **T1.2.3** PayPal payment cancellation
- [ ] **T1.2.4** Apple Pay token processing
- [ ] **T1.2.5** Google Pay token processing
- [ ] **T1.2.6** Redirect flow completion
- [ ] **T1.2.7** User abandons payment

---

### 1.3 Bank Transfer

**Requirements:**

- [ ] **R1.3.1** Virtual account generation
- [ ] **R1.3.2** Bank account validation
- [ ] **R1.3.3** Payment confirmation (webhook)
- [ ] **R1.3.4** Payment reconciliation
- [ ] **R1.3.5** Expiry handling

**Implementation:**

```go
type BankTransferPayment struct {
    VirtualAccount  string
    BankName        string
    AccountName     string
    ExpiresAt       time.Time
    Instructions    string
}

func (uc *PaymentUseCase) CreateBankTransferPayment(ctx context.Context, req *BankTransferRequest) (*PaymentResult, error) {
    // 1. Generate virtual account number
    virtualAccount, err := uc.bankTransferProvider.CreateVirtualAccount(ctx, &CreateVARequest{
        Amount:       req.Amount,
        Currency:     req.Currency,
        OrderID:      req.OrderID,
        CustomerName: req.CustomerName,
        ExpiryHours:  24, // 24 hours to pay
    })
    
    if err != nil {
        return nil, err
    }
    
    // 2. Create payment record (pending)
    payment := &Payment{
        ID:             uuid.New().String(),
        OrderID:        req.OrderID,
        Method:         "bank_transfer",
        Amount:         req.Amount,
        Currency:       req.Currency,
        Status:         "pending",
        VirtualAccount: virtualAccount.AccountNumber,
        BankName:       virtualAccount.BankName,
        ExpiresAt:      virtualAccount.ExpiresAt,
        CreatedAt:      time.Now(),
        UpdatedAt:      time.Now(),
    }
    
    if err := uc.repo.CreatePayment(ctx, payment); err != nil {
        return nil, err
    }
    
    // 3. Schedule expiry check
    uc.scheduleExpiryCheck(payment.ID, virtualAccount.ExpiresAt)
    
    // 4. Publish event
    uc.publishEvent(ctx, "payment.pending", payment)
    
    return &PaymentResult{
        Status:         "pending",
        PaymentID:      payment.ID,
        VirtualAccount: virtualAccount.AccountNumber,
        BankName:       virtualAccount.BankName,
        AccountName:    virtualAccount.AccountName,
        Amount:         req.Amount,
        ExpiresAt:      virtualAccount.ExpiresAt,
        Instructions:   uc.generateBankTransferInstructions(virtualAccount),
    }, nil
}

// Webhook handler for bank transfer confirmation
func (uc *PaymentUseCase) HandleBankTransferConfirmation(ctx context.Context, notification *BankTransferNotification) error {
    // 1. Verify webhook signature
    if !uc.verifyWebhookSignature(notification) {
        return ErrInvalidSignature
    }
    
    // 2. Find payment
    payment, err := uc.repo.GetPaymentByVirtualAccount(ctx, notification.VirtualAccount)
    if err != nil {
        return err
    }
    
    // 3. Check if already processed
    if payment.Status == "completed" {
        return nil // Idempotent
    }
    
    // 4. Verify amount
    if notification.Amount != payment.Amount {
        uc.log.Errorf("Amount mismatch: expected %.2f, got %.2f", payment.Amount, notification.Amount)
        return ErrAmountMismatch
    }
    
    // 5. Update payment status
    payment.Status = "completed"
    payment.GatewayTxnID = notification.TransactionID
    payment.PaidAt = &notification.PaidAt
    payment.UpdatedAt = time.Now()
    
    if err := uc.repo.UpdatePayment(ctx, payment); err != nil {
        return err
    }
    
    // 6. Publish event
    uc.publishEvent(ctx, "payment.completed", payment)
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T1.3.1** Virtual account creation
- [ ] **T1.3.2** Payment confirmation via webhook
- [ ] **T1.3.3** Amount mismatch handling
- [ ] **T1.3.4** Payment expiration
- [ ] **T1.3.5** Duplicate webhook handling (idempotency)

---

### 1.4 Cash on Delivery (COD)

**Requirements:**

- [ ] **R1.4.1** COD availability check (geography-based)
- [ ] **R1.4.2** COD fee calculation
- [ ] **R1.4.3** Payment collection by courier
- [ ] **R1.4.4** Cash reconciliation

**Implementation:**

```go
func (uc *PaymentUseCase) CreateCODPayment(ctx context.Context, req *CODPaymentRequest) (*PaymentResult, error) {
    // 1. Check if COD available for shipping address
    available, err := uc.shippingClient.IsCODAvailable(ctx, req.ShippingAddress)
    if err != nil || !available {
        return nil, &PaymentError{
            Code:    "COD_NOT_AVAILABLE",
            Message: "Cash on delivery not available for this address",
        }
    }
    
    // 2. Calculate COD fee
    codFee := uc.calculateCODFee(req.Amount)
    totalAmount := req.Amount + codFee
    
    // 3. Create payment record
    payment := &Payment{
        ID:          uuid.New().String(),
        OrderID:     req.OrderID,
        Method:      "cash_on_delivery",
        Amount:      req.Amount,
        CODFee:      codFee,
        TotalAmount: totalAmount,
        Currency:    req.Currency,
        Status:      "pending_collection",
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }
    
    if err := uc.repo.CreatePayment(ctx, payment); err != nil {
        return nil, err
    }
    
    return &PaymentResult{
        Status:      "pending_collection",
        PaymentID:   payment.ID,
        Amount:      req.Amount,
        CODFee:      codFee,
        TotalAmount: totalAmount,
    }, nil
}

func (uc *PaymentUseCase) ConfirmCODCollection(ctx context.Context, paymentID string, collectedBy string) error {
    payment, err := uc.repo.GetPayment(ctx, paymentID)
    if err != nil {
        return err
    }
    
    payment.Status = "collected"
    payment.CollectedBy = collectedBy
    payment.CollectedAt = timePtr(time.Now())
    payment.UpdatedAt = time.Now()
    
    if err := uc.repo.UpdatePayment(ctx, payment); err != nil {
        return err
    }
    
    uc.publishEvent(ctx, "payment.collected", payment)
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T1.4.1** COD available for address
- [ ] **T1.4.2** COD not available for address
- [ ] **T1.4.3** COD fee calculated correctly
- [ ] **T1.4.4** Cash collection confirmed
- [ ] **T1.4.5** Cash collection failed

---

## 2. Payment Flow & States

### 2.1 Payment State Machine

**Payment States:**

```
pending → authorized → captured → settled
                ↓          ↓
              failed    refunded
                          ↓
                    partially_refunded
```

**State Transitions:**

- [ ] **R2.1.1** `pending` → `authorized` (card authorized)
- [ ] **R2.1.2** `pending` → `failed` (authorization failed)
- [ ] **R2.1.3** `authorized` → `captured` (funds captured)
- [ ] **R2.1.4** `authorized` → `void` (authorization voided)
- [ ] **R2.1.5** `captured` → `refunded` (full refund)
- [ ] **R2.1.6** `captured` → `partially_refunded` (partial refund)
- [ ] **R2.1.7** `captured` → `settled` (funds settled to merchant)

**Implementation:**

```go
type PaymentStatus string

const (
    StatusPending           PaymentStatus = "pending"
    StatusAuthorized        PaymentStatus = "authorized"
    StatusCaptured          PaymentStatus = "captured"
    StatusFailed            PaymentStatus = "failed"
    StatusVoided            PaymentStatus = "voided"
    StatusRefunded          PaymentStatus = "refunded"
    StatusPartiallyRefunded PaymentStatus = "partially_refunded"
    StatusSettled           PaymentStatus = "settled"
)

type Payment struct {
    ID                string
    OrderID           string
    CustomerID        string
    Method            string
    Amount            float64
    Currency          string
    Status            PaymentStatus
    
    // Gateway details
    GatewayTxnID      string
    GatewayResponse   string
    
    // Card details (tokenized)
    CardLast4         string
    CardBrand         string
    CardToken         string
    
    // Fraud
    FraudScore        float64
    FraudLevel        string
    
    // Refund
    RefundedAmount    float64
    RefundHistory     []Refund
    
    // Timestamps
    AuthorizedAt      *time.Time
    CapturedAt        *time.Time
    FailedAt          *time.Time
    RefundedAt        *time.Time
    SettledAt         *time.Time
    CreatedAt         time.Time
    UpdatedAt         time.Time
}

// State transition validation
func (p *Payment) CanTransitionTo(newStatus PaymentStatus) error {
    validTransitions := map[PaymentStatus][]PaymentStatus{
        StatusPending: {StatusAuthorized, StatusFailed, StatusVoided},
        StatusAuthorized: {StatusCaptured, StatusVoided, StatusFailed},
        StatusCaptured: {StatusRefunded, StatusPartiallyRefunded, StatusSettled},
        StatusSettled: {StatusRefunded, StatusPartiallyRefunded},
    }
    
    allowed, exists := validTransitions[p.Status]
    if !exists {
        return fmt.Errorf("no transitions allowed from status: %s", p.Status)
    }
    
    for _, status := range allowed {
        if status == newStatus {
            return nil
        }
    }
    
    return fmt.Errorf("cannot transition from %s to %s", p.Status, newStatus)
}

func (uc *PaymentUseCase) TransitionPaymentStatus(ctx context.Context, paymentID string, newStatus PaymentStatus) error {
    payment, err := uc.repo.GetPayment(ctx, paymentID)
    if err != nil {
        return err
    }
    
    // Validate transition
    if err := payment.CanTransitionTo(newStatus); err != nil {
        return err
    }
    
    oldStatus := payment.Status
    payment.Status = newStatus
    payment.UpdatedAt = time.Now()
    
    // Set timestamp fields
    switch newStatus {
    case StatusAuthorized:
        payment.AuthorizedAt = timePtr(time.Now())
    case StatusCaptured:
        payment.CapturedAt = timePtr(time.Now())
    case StatusFailed:
        payment.FailedAt = timePtr(time.Now())
    case StatusRefunded, StatusPartiallyRefunded:
        payment.RefundedAt = timePtr(time.Now())
    case StatusSettled:
        payment.SettledAt = timePtr(time.Now())
    }
    
    // Save payment
    if err := uc.repo.UpdatePayment(ctx, payment); err != nil {
        return err
    }
    
    // Publish event
    uc.publishEvent(ctx, fmt.Sprintf("payment.%s", newStatus), map[string]interface{}{
        "payment_id":  payment.ID,
        "order_id":    payment.Order ID,
        "old_status":  oldStatus,
        "new_status":  newStatus,
        "amount":      payment.Amount,
    })
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T2.1.1** Valid state transitions
- [ ] **T2.1.2** Invalid state transitions blocked
- [ ] **T2.1.3** Timestamp fields updated correctly
- [ ] **T2.1.4** Events published on state change

---

### 2.2 Authorize vs Capture

**Two-Step Payment Flow:**

**Authorize (Hold):* *
- Reserves funds on customer's card
- Funds not yet transferred
- Can be voided without fees
- Typical hold: 7 days

**Capture:**
- Actually charges the card
- Funds transferred to merchant
- Cannot be voided (only refunded)

**Requirements:**

- [ ] **R2.2.1** Authorize payment on order creation
- [ ] **R2.2.2** Capture payment on order fulfillment
- [ ] **R2.2.3** Void authorization if order cancelled before fulfillment
- [ ] **R2.2.4** Auto-capture if not captured within X days
- [ ] **R2.2.5** Partial capture support (for partial shipments)

**Implementation:**

```go
func (uc *PaymentUseCase) CapturePayment(ctx context.Context, paymentID string, captureAmount *float64) (*PaymentResult, error) {
    payment, err := uc.repo.GetPayment(ctx, paymentID)
    if err != nil {
        return nil, err
    }
    
    // Validate status
    if payment.Status != StatusAuthorized {
        return nil, &PaymentError{
            Code:    "INVALID_STATUS",
            Message: fmt.Sprintf("Cannot capture payment with status: %s", payment.Status),
        }
    }
    
    // Determine capture amount
    amountToCapture := payment.Amount
    if captureAmount != nil {
        if *captureAmount > payment.Amount {
            return nil, ErrCaptureExceedsAuthorizedAmount
        }
        amountToCapture = *captureAmount
    }
    
    // Capture via gateway
    captureResult, err := uc.gateway.CapturePayment(ctx, &CapturePaymentRequest{
        AuthorizationID: payment.GatewayTxnID,
        Amount:          amountToCapture,
        Currency:        payment.Currency,
    })
    
    if err != nil {
        return nil, uc.handleGatewayError(err)
    }
    
    // Update payment
    payment.Status = StatusCaptured
    payment.CapturedAmount = amountToCapture
    payment.CapturedAt = timePtr(time.Now())
    payment.GatewayCaptureID = captureResult.CaptureID
    payment.UpdatedAt = time.Now()
    
    if err := uc.repo.UpdatePayment(ctx, payment); err != nil {
        return nil, err
    }
    
    // Publish event
    uc.publishEvent(ctx, "payment.captured", payment)
    
    return &PaymentResult{
        Status:    "captured",
        PaymentID: payment.ID,
        Amount:    amountToCapture,
    }, nil
}

func (uc *PaymentUseCase) VoidAuthorization(ctx context.Context, paymentID string) error {
    payment, err := uc.repo.GetPayment(ctx, paymentID)
    if err != nil {
        return err
    }
    
    if payment.Status != StatusAuthorized {
        return &PaymentError{
            Code:    "INVALID_STATUS",
            Message: "Can only void authorized payments",
        }
    }
    
    // Void via gateway
    if err := uc.gateway.VoidAuthorization(ctx, payment.GatewayTxnID); err != nil {
        return err
    }
    
    // Update payment
    payment.Status = StatusVoided
    payment.VoidedAt = timePtr(time.Now())
    payment.UpdatedAt = time.Now()
    
    if err := uc.repo.UpdatePayment(ctx, payment); err != nil {
        return err
    }
    
    uc.publishEvent(ctx, "payment.voided", payment)
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T2.2.1** Authorize payment successfully
- [ ] **T2.2.2** Capture full authorized amount
- [ ] **T2.2.3** Capture partial amount
- [ ] **T2.2.4** Void authorization before capture
- [ ] **T2.2.5** Cannot void after capture
- [ ] **T2.2.6** Authorization expires after 7 days

---

## 3. Payment Gateway Integration

### 3.1 Multi-Gateway Support

**Supported Gateways:**

- [ ] **R3.1.1** Stripe
- [ ] **R3.1.2** PayPal
- [ ] **R3.1.3** VNPay (Vietnam)
- [ ] **R3.1.4** MoMo (Vietnam)
- [ ] **R3.1.5** ZaloPay (Vietnam)
- [ ] **R3.1.6** Adyen (international)

**Gateway Router:**

```go
type PaymentGateway interface {
    AuthorizePayment(ctx context.Context, req *AuthorizePaymentRequest) (*AuthorizationResult, error)
    CapturePayment(ctx context.Context, req *CapturePaymentRequest) (*CaptureResult, error)
    RefundPayment(ctx context.Context, req *RefundPaymentRequest) (*RefundResult, error)
    VoidAuthorization(ctx context.Context, authID string) error
    TokenizeCard(ctx context.Context, req *TokenizeCardRequest) (*TokenResult, error)
}

type GatewayRouter struct {
    gateways map[string]PaymentGateway
    config   *GatewayConfig
}

func (r *GatewayRouter) GetGateway(method string, country string) PaymentGateway {
    // Route based on payment method and country
    if country == "VN" {
        // Vietnam - use local gateways
        switch method {
        case "credit_card":
            return r.gateways["vnpay"]
        case "digital_wallet":
            return r.gateways["momo"]
        default:
            return r.gateways["vnpay"]
        }
    }
    
    // International - use Stripe
    return r.gateways["stripe"]
}
```

**Test Scenarios:**

- [ ] **T3.1.1** Route Vietnam payments to VNPay
- [ ] **T3.1.2** Route international payments to Stripe
- [ ] **T3.1.3** Fallback gateway on primary failure
- [ ] **T3.1.4** Gateway selection based on currency

---

### 3.2 Gateway Error Handling

**Requirements:**

- [ ] **R3.2.1** Map gateway errors to standard errors
- [ ] **R3.2.2** Retry transient errors
- [ ] **R3.2.3** Log all gateway interactions
- [ ] **R3.2.4** Circuit breaker for gateway failures

**Implementation:**

```go
func (uc *PaymentUseCase) handleGatewayError(err error) error {
    // Map gateway-specific errors to standard errors
    if stripeErr, ok := err.(*stripe.Error); ok {
        switch stripeErr.Code {
        case "card_declined":
            return &PaymentError{
                Code:    "CARD_DECLINED",
                Message: "Your card was declined",
                Reason:  stripeErr.DeclineCode,
            }
        case "insufficient_funds":
            return &PaymentError{
                Code:    "INSUFFICIENT_FUNDS",
                Message: "Insufficient funds on card",
            }
        case "expired_card":
            return &PaymentError{
                Code:    "CARD_EXPIRED",
                Message: "Card has expired",
            }
        case "fraudulent":
            return &PaymentError{
                Code:    "FRAUD_DETECTED",
                Message: "Payment blocked due to fraud suspicion",
            }
        default:
            return &PaymentError{
                Code:    "GATEWAY_ERROR",
                Message: "Payment processing failed",
                Err:     err,
            }
        }
    }
    
    return err
}

// Circuit breaker for gateway calls
func (uc *PaymentUseCase) callGatewayWithCircuitBreaker(ctx context.Context, fn func() error) error {
    if uc.circuitBreaker.IsOpen() {
        return ErrGatewayUnavailable
    }
    
    err := fn()
    
    if err != nil {
        uc.circuitBreaker.RecordFailure()
    } else {
        uc.circuitBreaker.RecordSuccess()
    }
    
    return err
}
```

**Test Scenarios:**

- [ ] **T3.2.1** Card declined error mapping
- [ ] **T3.2.2** Insufficient funds error
- [ ] **T3.2.3** Expired card error
- [ ] **T3.2.4** Gateway timeout handling
- [ ] **T3.2.5** Circuit breaker opens after failures
- [ ] **T3.2.6** Circuit breaker closes after recovery

---

## 4. Security & Compliance

### 4.1 PCI DSS Compliance

**Requirements:**

- [ ] **R4.1.1** Never store full card numbers
- [ ] **R4.1.2** Never store CVV
- [ ] **R4.1.3** Use tokenization for card storage
- [ ] **R4.1.4** Encrypt sensitive data at rest
- [ ] **R4.1.5** Use TLS 1.2+ for transmission
- [ ] **R4.1.6** Implement strong access controls
- [ ] **R4.1.7** Log all payment activities
- [ ] **R4.1.8** Regular security audits
- [ ] **R4.1.9** Penetration testing
- [ ] **R4.1.10** Vulnerability scanning

**Security Best Practices:**

```go
// ❌ NEVER DO THIS
type Payment struct {
    CardNumber string  // NEVER store full card number!
    CVV        string  // NEVER store CVV!
}

// ✅ CORRECT - Use tokenization
type Payment struct {
    CardToken  string  // Gateway token
    CardLast4  string  // Last 4 digits only (for display)
    CardBrand  string  // Card brand
}

// Sensitive data encryption at rest
func (r *PaymentRepository) SavePayment(ctx context.Context, payment *Payment) error {
    // Encrypt sensitive fields before saving
    if payment.CustomerEmail != "" {
        encryptedEmail, err := r.encryptor.Encrypt(payment.CustomerEmail)
        if err != nil {
            return err
        }
        payment.EncryptedEmail = encryptedEmail
        payment.CustomerEmail = "" // Clear plain text
    }
    
    return r.db.Create(payment).Error
}

// Audit logging for all payment operations
func (uc *PaymentUseCase) logPaymentActivity(ctx context.Context, action string, payment *Payment, metadata map[string]interface{}) {
    auditLog := &AuditLog{
        Timestamp:  time.Now(),
        Action:     action,
        PaymentID:  payment.ID,
        OrderID:    payment.OrderID,
        UserID:     payment.CustomerID,
        IPAddress:  ctx.Value("ip_address").(string),
        UserAgent:  ctx.Value("user_agent").(string),
        Amount:     payment.Amount,
        Currency:   payment.Currency,
        Status:     string(payment.Status),
        Metadata:   metadata,
    }
    
    uc.auditLogger.Log(auditLog)
}
```

**Test Scenarios:**

- [ ] **T4.1.1** No full card numbers stored
- [ ] **T4.1.2** No CVV stored
- [ ] **T4.1.3** Sensitive data encrypted
- [ ] **T4.1.4** Audit logs created for all operations
- [ ] **T4.1.5** TLS enforced for all connections

---

### 4.2 3D Secure (3DS) Authentication

**Requirements:**

- [ ] **R4.2.1** Trigger 3DS for high-value transactions
- [ ] **R4.2.2** Trigger 3DS for international cards
- [ ] **R4.2.3** Handle 3DS challenge flow
- [ ] **R4.2.4** Verify 3DS authentication result
- [ ] **R4.2.5** Liability shift validation

**Implementation:**

```go
func (uc *PaymentUseCase) shouldRequire3DS(amount float64, cardBrand string, issuerCountry string) bool {
    // Always require for high-value transactions
    if amount >= 1000 {
        return true
    }
    
    // Require for international cards
    if issuerCountry != uc.config.MerchantCountry {
        return true
    }
    
    // Check SCA (Strong Customer Authentication) requirements
    // EU regulations require 3DS for most transactions
    if uc.isEUCountry(issuerCountry) {
        return true
    }
    
    return false
}

func (uc *PaymentUseCase) Handle3DSCallback(ctx context.Context, req *ThreeDSCallbackRequest) (*PaymentResult, error) {
    // 1. Verify 3DS authentication
    threeDSResult, err := uc.gateway.Verify3DSAuthentication(ctx, req.ThreeDSToken)
    if err != nil {
        return nil, err
    }
    
    if threeDSResult.Status != "authenticated" {
        return &PaymentResult{
            Status:  "failed",
            Message: "3D Secure authentication failed",
        }, nil
    }
    
    // 2. Continue with payment authorization
    // Now with liability shift to issuer
    payment, err := uc.ProcessCreditCardPayment(ctx, &CreditCardPaymentRequest{
        // ... payment details ...
        ThreeDSStatus: threeDSResult.Status,
        ThreeDSToken:  req.ThreeDSToken,
    })
    
    return payment, err
}
```

**Test Scenarios:**

- [ ] **T4.2.1** 3DS required for high-value ($1000+)
- [ ] **T4.2.2** 3DS required for international cards
- [ ] **T4.2.3** 3DS required for EU cards (SCA)
- [ ] **T4.2.4** 3DS authentication successful
- [ ] **T4.2.5** 3DS authentication failed
- [ ] **T4.2.6** Liability shift confirmed

---

## 5. Fraud Detection

### 5.1 Fraud Scoring

**Requirements:**

- [ ] **R5.1.1** Real-time fraud scoring
- [ ] **R5.1.2** Block high-risk transactions
- [ ] **R5.1.3** Manual review for medium risk
- [ ] **R5.1.4** Allow low-risk transactions
- [ ] **R5.1.5** Learn from historical data

**Fraud Signals:**

```go
type FraudCheckRequest struct {
    // Transaction details
    Amount          float64
    Currency        string
    
    // Card details
    CardBIN         string
    CardCountry     string
    
    // Customer details
    CustomerID      string
    CustomerEmail   string
    CustomerIP      string
    
    // Order details
    BillingAddress  *Address
    ShippingAddress *Address
    
    // Device fingerprint
    DeviceID        string
    DeviceLocation  *Location
    UserAgent       string
}

type FraudCheckResult struct {
    Score       float64  // 0-100
    RiskLevel   string   // "low", "medium", "high"
    Signals     []FraudSignal
    Action      string   // "allow", "review", "block"
}

type FraudSignal struct {
    Name        string
    Value       interface{}
    Weight      float64
    Description string
}

func (fd *FraudDetector) CheckPayment(ctx context.Context, req *FraudCheckRequest) (*FraudCheckResult, error) {
    score := 0.0
    signals := []FraudSignal{}
    
    // 1. Velocity checks - multiple transactions short time
    velocityScore, velocitySignals := fd.checkVelocity(req.CustomerID, req.CustomerIP)
    score += velocityScore
    signals = append(signals, velocitySignals...)
    
    // 2. Billing/shipping mismatch
    if !addressesMatch(req.BillingAddress, req.ShippingAddress) {
        score += 15
        signals = append(signals, FraudSignal{
            Name:        "address_mismatch",
            Value:       true,
            Weight:      15,
            Description: "Billing and shipping addresses don't match",
        })
    }
    
    // 3. High-risk geography
    if fd.isHighRiskCountry(req.BillingAddress.Country) {
        score += 20
        signals = append(signals, FraudSignal{
            Name:        "high_risk_country",
            Value:       req.BillingAddress.Country,
            Weight:      20,
            Description: "Transaction from high-risk country",
        })
    }
    
    // 4. Unusual purchase amount
    avgAmount := fd.getCustomerAverageOrderValue(req.CustomerID)
    if req.Amount > (avgAmount * 3) {
        score += 10
        signals = append(signals, FraudSignal{
            Name:        "unusual_amount",
            Value:       req.Amount,
            Weight:      10,
            Description: "Transaction amount significantly higher than average",
        })
    }
    
    // 5. VPN/Proxy detection
    if fd.isVPN(req.CustomerIP) {
        score += 10
        signals = append(signals, FraudSignal{
            Name:        "vpn_detected",
            Value:       true,
            Weight:      10,
            Description: "VPN or proxy detected",
        })
    }
    
    // 6. Device fingerprint mismatch
    if req.CustomerID != "" {
        expectedDevices := fd.getCustomerDevices(req.CustomerID)
        if !contains(expectedDevices, req.DeviceID) {
            score += 5
            signals = append(signals, FraudSignal{
                Name:        "new_device",
                Value:       req.DeviceID,
                Weight:      5,
                Description: "Transaction from new/unknown device",
            })
        }
    }
    
    // 7. Email domain check
    if fd.isDisposableEmail(req.CustomerEmail) {
        score += 15
        signals = append(signals, FraudSignal {
            Name:        "disposable_email",
            Value:       req.CustomerEmail,
            Weight:      15,
            Description: "Disposable email address detected",
        })
    }
    
    // Determine risk level and action
    var riskLevel, action string
    
    if score >= 70 {
        riskLevel = "high"
        action = "block"
    } else if score >= 40 {
        riskLevel = "medium"
        action = "review"
    } else {
        riskLevel = "low"
        action = "allow"
    }
    
    return &FraudCheckResult{
        Score:     score,
        RiskLevel: riskLevel,
        Signals:   signals,
        Action:    action,
    }, nil
}

func (fd *FraudDetector) checkVelocity(customerID, ip string) (float64, []FraudSignal) {
    score := 0.0
    signals := []FraudSignal{}
    
    // Check transactions in last hour
    recentTxns := fd.getRecentTransactions(customerID, ip, 1*time.Hour)
    
    if len(recentTxns) > 5 {
        score += 25
        signals = append(signals, FraudSignal{
            Name:        "high_velocity",
            Value:       len(recentTxns),
            Weight:      25,
            Description: fmt.Sprintf("%d transactions in last hour", len(recentTxns)),
        })
    }
    
    // Check multiple failed attempts
    failedAttempts := fd.getFailedAttempts(customerID, ip, 1*time.Hour)
    
    if failedAttempts > 3 {
        score += 20
        signals = append(signals, FraudSignal{
            Name:        "multiple_failures",
            Value:       failedAttempts,
            Weight:      20,
            Description: fmt.Sprintf("%d failed payment attempts", failedAttempts),
        })
    }
    
    return score, signals
}
```

**Test Scenarios:**

- [ ] **T5.1.1** Low fraud score allows payment
- [ ] **T5.1.2** High fraud score blocks payment
- [ ] **T5.1.3** Medium fraud score triggers review
- [ ] **T5.1.4** Billing/shipping mismatch increases score
- [ ] **T5.1.5** High-risk country increases score
- [ ] **T5.1.6** VPN detection increases score
- [ ] **T5.1.7** Velocity check detects rapid transactions
- [ ] **T5.1.8** Disposable email detected

---

## 6. Refund & Cancellation

### 6.1 Full Refund

**Requirements:**

- [ ] **R6.1.1** Refund captured payments
- [ ] **R6.1.2** Validate refund amount
- [ ] **R6.1.3** Process refund via gateway
- [ ] **R6.1.4** Update payment status
- [ ] **R6.1.5** Notify customer
- [ ] **R6.1.6** Track refund history

**Implementation:**

```go
func (uc *PaymentUseCase) RefundPayment(ctx context.Context, req *RefundRequest) (*RefundResult, error) {
    payment, err := uc.repo.GetPayment(ctx, req.PaymentID)
    if err != nil {
        return nil, err
    }
    
    // Validate payment can be refunded
    if payment.Status != StatusCaptured && payment.Status != StatusSettled {
        return nil, &PaymentError{
            Code:    "INVALID_STATUS",
            Message: fmt.Sprintf("Cannot refund payment with status: %s", payment.Status),
        }
    }
    
    // Check if already fully refunded
    if payment.Status == StatusRefunded {
        return nil, ErrAlreadyRefunded
    }
    
    // Determine refund amount
    refundAmount := req.Amount
    if refundAmount == 0 {
        refundAmount = payment.Amount - payment.RefundedAmount
    }
    
    // Validate refund amount
    if refundAmount > (payment.Amount - payment.RefundedAmount) {
        return nil, ErrRefundExceedsAvailable
    }
    
    // Process refund via gateway
    refundResult, err := uc.gateway.RefundPayment(ctx, &RefundPaymentRequest{
        PaymentID: payment.GatewayTxnID,
        Amount:    refundAmount,
        Currency:  payment.Currency,
        Reason:    req.Reason,
    })
    
    if err != nil {
        return nil, uc.handleGatewayError(err)
    }
    
    // Create refund record
    refund := &Refund{
        ID:              uuid.New().String(),
        PaymentID:       payment.ID,
        Amount:          refundAmount,
        Currency:        payment.Currency,
        Reason:          req.Reason,
        GatewayRefundID: refundResult.RefundID,
        Status:          "completed",
        CreatedBy:       req.CreatedBy,
        CreatedAt:       time.Now(),
    }
    
    // Update payment
    payment.RefundedAmount += refundAmount
    payment.RefundHistory = append(payment.RefundHistory, *refund)
    
    if payment.RefundedAmount >= payment.Amount {
        payment.Status = StatusRefunded
    } else {
        payment.Status = StatusPartiallyRefunded
    }
    
    payment.RefundedAt = timePtr(time.Now())
    payment.UpdatedAt = time.Now()
    
    // Save changes
    if err := uc.repo.UpdatePayment(ctx, payment); err != nil {
        return nil, err
    }
    
    if err := uc.repo.CreateRefund(ctx, refund); err != nil {
        return nil, err
    }
    
    // Publish event
    uc.publishEvent(ctx, "payment.refunded", map[string]interface{}{
        "payment_id":   payment.ID,
        "refund_id":    refund.ID,
        "amount":       refundAmount,
        "refund_total": payment.RefundedAmount,
    })
    
    return &RefundResult{
        RefundID:       refund.ID,
        Amount:         refundAmount,
        Status:         "completed",
        PaymentStatus:  string(payment.Status),
    }, nil
}
```

**Test Scenarios:**

- [ ] **T6.1.1** Full refund successful
- [ ] **T6.1.2** Partial refund successful
- [ ] **T6.1.3** Multiple partial refunds
- [ ] **T6.1.4** Cannot refund more than captured
- [ ] **T6.1.5** Cannot refund unauthorized payment
- [ ] **T6.1.6** Cannot refund already refunded payment
- [ ] **T6.1.7** Refund history tracked
- [ ] **T6.1.8** Customer notified of refund

---

## 7. Webhook Handling

### 7.1 Gateway Webhooks

**Requirements:**

- [ ] **R7.1.1** Verify webhook signatures
- [ ] **R7.1.2** Handle idempotency (duplicate webhooks)
- [ ] **R7.1.3** Process webhooks asynchronously
- [ ] **R7.1.4** Retry failed webhook processing
- [ ] **R7.1.5** Log all webhook events

**Implementation:**

```go
func (h *WebhookHandler) HandleStripeWebhook(w http.ResponseWriter, r *http.Request) {
    payload, err := io.ReadAll(r.Body)
    if err != nil {
        http.Error(w, "Error reading request body", http.StatusBadRequest)
        return
    }
    
    // 1. Verify signature
    signature := r.Header.Get("Stripe-Signature")
    
    event, err := webhook.ConstructEvent(payload, signature, h.webhookSecret)
    if err != nil {
        h.log.Errorf("Webhook signature verification failed: %v", err)
        http.Error(w, "Invalid signature", http.StatusBadRequest)
        return
    }
    
    // 2. Check idempotency (prevent duplicate processing)
    if h.webhookAlreadyProcessed(event.ID) {
        h.log.Infof("Webhook %s already processed, skipping", event.ID)
        w.WriteHeader(http.StatusOK)
        return
    }
    
    // 3. Process webhook asynchronously
    go h.processWebhook(context.Background(), &event)
    
    // 4. Return 200 immediately (acknowledge receipt)
    w.WriteHeader(http.StatusOK)
}

func (h *WebhookHandler) processWebhook(ctx context.Context, event *stripe.Event) {
    // Log webhook
    h.logWebhook(event)
    
    // Mark as processing
    h.markWebhookProcessing(event.ID)
    
    defer func() {
        if r := recover(); r != nil {
            h.log.Errorf("Panic processing webhook %s: %v", event.ID, r)
            h.markWebhookFailed(event.ID)
        }
    }()
    
    switch event.Type {
    case "payment_intent.succeeded":
        h.handlePaymentSucceeded(ctx, event)
        
    case "payment_intent.payment_failed":
        h.handlePaymentFailed(ctx, event)
        
    case "charge.refunded":
        h.handleRefund(ctx, event)
        
    case "charge.dispute.created":
        h.handleDispute(ctx, event)
        
    default:
        h.log.Infof("Unhandled webhook type: %s", event.Type)
    }
    
    // Mark as processed
    h.markWebhookProcessed(event.ID)
}

func (h *WebhookHandler) webhookAlreadyProcessed(webhookID string) bool {
    key := fmt.Sprintf("webhook:processed:%s", webhookID)
    
    exists, _ := h.redis.Exists(context.Background(), key).Result()
    return exists > 0
}

func (h *WebhookHandler) markWebhookProcessed(webhookID string) {
    key := fmt.Sprintf("webhook:processed:%s", webhookID)
    
    // Store for 30 days
    h.redis.Set(context.Background(), key, "1", 30*24*time.Hour)
}
```

**Test Scenarios:**

- [ ] **T7.1.1** Valid webhook signature accepted
- [ ] **T7.1.2** Invalid webhook signature rejected
- [ ] **T7.1.3** Duplicate webhook not processed twice
- [ ] **T7.1.4** Payment success webhook updates status
- [ ] **T7.1.5** Payment failure webhook updates status
- [ ] **T7.1.6** Refund webhook creates refund record
- [ ] **T7.1.7** Dispute webhook triggers alert

---

## 8. Testing Summary

### 8.1 Unit Tests

- [ ] Card validation (Luhn, expiry, CVV)
- [ ] Payment state transitions
- [ ] Fraud score calculation
- [ ] Refund amount validation
- [ ] Gateway error mapping

### 8.2 Integration Tests

- [ ] Full payment flow (authorize → capture)
- [ ] Refund flow
- [ ] Webhook processing
- [ ] Gateway integration (Stripe, PayPal)
- [ ] 3D Secure flow

### 8.3 Security Tests

- [ ] No sensitive data stored
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] CSRF protection
- [ ] Rate limiting

### 8.4 Performance Tests

- [ ] Payment processing <3s (p95)
- [ ] Webhook processing <1s
- [ ] 1000 concurrent payments
- [ ] Gateway timeout handling

---

## 📊 Success Criteria

- [ ] ✅ Payment success rate >95%
- [ ] ✅ Payment processing time <3s (p95)
- [ ] ✅ Fraud rate <0.1%
- [ ] ✅ PCI DSS Level 1 compliant
- [ ] ✅ 99.99% uptime
- [ ] ✅ 100% payment reconciliation
- [ ] ✅ No sensitive data leaks
- [ ] ✅ Test coverage >85%

---

**Status:** Ready for Implementation  
**Next Steps:** Begin with card payment implementation, then add digital wallets

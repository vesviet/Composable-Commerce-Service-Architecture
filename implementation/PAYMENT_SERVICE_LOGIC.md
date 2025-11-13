# Payment Service - Logic Implementation Review

> **Service**: Payment Service Integration  
> **Last Updated**: December 2024  
> **Status**: Integration Complete (Full Service Pending)

---

## 📋 Overview

Payment Service integration được implement trong Order Service thông qua HTTP client. Service này xử lý payment processing, payment status tracking, và tích hợp với payment gateways. Full Payment Service implementation đang trong quá trình phát triển.

---

## 🏗️ Architecture

### Integration Structure
```
order/
├── internal/
│   ├── client/
│   │   └── payment_client.go    # Payment HTTP client
│   ├── biz/
│   │   ├── order.go              # Order payment integration
│   │   └── adapters.go           # PaymentService adapter
│   └── repository/
│       └── payment/              # Order payment records
```

### Payment Client
- **Type**: HTTP Client with Circuit Breaker
- **Base URL**: Configurable (via environment)
- **Timeout**: Dapr default timeout
- **Pattern**: Circuit Breaker for resilience

---

## 🔄 Core Business Logic

### 1. Payment Client Implementation

#### ProcessPayment Method
**Location**: `order/internal/client/payment_client.go:49`

**Flow**:
1. **Create Request**
   - URL: `{baseURL}/v1/payments`
   - Method: POST
   - Body: JSON with order_id, amount, currency, payment_method, payment_provider, metadata
2. **Execute with Circuit Breaker**
   - Wrap HTTP call in circuit breaker
   - Handle timeouts and errors
3. **Parse Response**
   - PaymentID
   - Status
   - TransactionID
   - GatewayData
4. **Return PaymentResponse**

**Key Code**:
```go
func (c *httpPaymentClient) ProcessPayment(ctx context.Context, req *PaymentRequest) (*PaymentResponse, error) {
    var result *PaymentResponse
    cbErr := c.circuitBreaker.Call(ctx, func() error {
        url := fmt.Sprintf("%s/v1/payments", c.baseURL)
        
        requestBody := map[string]interface{}{
            "order_id":          req.OrderID,
            "amount":            req.Amount,
            "currency":          req.Currency,
            "payment_method":    req.PaymentMethod,
            "payment_provider":  req.PaymentProvider,
            "metadata":          req.Metadata,
        }
        
        jsonData, err := json.Marshal(requestBody)
        httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(jsonData))
        httpReq.Header.Set("Content-Type", "application/json")
        
        resp, err := c.client.Do(httpReq)
        if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
            return fmt.Errorf("payment service error: status %d", resp.StatusCode)
        }
        
        // Parse response
        var response struct {
            Payment struct {
                PaymentID     string
                Status        string
                TransactionID string
                GatewayData   map[string]interface{}
            }
        }
        json.NewDecoder(resp.Body).Decode(&response)
        
        result = &PaymentResponse{
            PaymentID:     response.Payment.PaymentID,
            Status:        response.Payment.Status,
            TransactionID: response.Payment.TransactionID,
            GatewayData:   response.Payment.GatewayData,
        }
        
        return nil
    })
    
    return result, cbErr
}
```

---

#### GetPaymentStatus Method
**Location**: `order/internal/client/payment_client.go:118`

**Flow**:
1. **Create Request**
   - URL: `{baseURL}/v1/payments/{paymentID}/status`
   - Method: GET
2. **Execute with Circuit Breaker**
3. **Parse Response**
   - PaymentID
   - Status
   - TransactionID
   - ProcessedAt
   - FailedAt
   - FailureReason
4. **Return PaymentStatus**

**Key Code**:
```go
func (c *httpPaymentClient) GetPaymentStatus(ctx context.Context, paymentID string) (*PaymentStatus, error) {
    var result *PaymentStatus
    cbErr := c.circuitBreaker.Call(ctx, func() error {
        url := fmt.Sprintf("%s/v1/payments/%s/status", c.baseURL, paymentID)
        
        httpReq, err := http.NewRequestWithContext(ctx, "GET", url, nil)
        resp, err := c.client.Do(httpReq)
        
        if resp.StatusCode == http.StatusNotFound {
            return fmt.Errorf("payment not found")
        }
        
        // Parse response
        var response struct {
            Payment struct {
                PaymentID     string
                Status        string
                TransactionID string
                ProcessedAt   *time.Time
                FailedAt      *time.Time
                FailureReason string
            }
        }
        json.NewDecoder(resp.Body).Decode(&response)
        
        result = &PaymentStatus{
            PaymentID:     response.Payment.PaymentID,
            Status:        response.Payment.Status,
            TransactionID: response.Payment.TransactionID,
            ProcessedAt:   response.Payment.ProcessedAt,
            FailedAt:      response.Payment.FailedAt,
            FailureReason: response.Payment.FailureReason,
        }
        
        return nil
    })
    
    return result, cbErr
}
```

---

### 2. Payment Service Adapter

#### PaymentServiceAdapter
**Location**: `order/internal/biz/adapters.go:124`

**Purpose**: Adapts PaymentClient to PaymentService interface

**Implementation**:
```go
type paymentServiceAdapter struct {
    client client.PaymentClient
}

func (a *paymentServiceAdapter) ProcessPayment(ctx context.Context, req *PaymentRequest) (*PaymentResponse, error) {
    clientReq := &client.PaymentRequest{
        OrderID:         req.OrderID,
        Amount:          req.Amount,
        Currency:        req.Currency,
        PaymentMethod:   req.PaymentMethod,
        PaymentProvider: req.PaymentProvider,
        Metadata:        req.Metadata,
    }
    clientResp, err := a.client.ProcessPayment(ctx, clientReq)
    if err != nil {
        return nil, err
    }
    return &PaymentResponse{
        PaymentID:     clientResp.PaymentID,
        Status:        clientResp.Status,
        TransactionID: clientResp.TransactionID,
        GatewayData:   clientResp.GatewayData,
    }, nil
}

func (a *paymentServiceAdapter) GetPaymentStatus(ctx context.Context, paymentID string) (*PaymentStatus, error) {
    clientStatus, err := a.client.GetPaymentStatus(ctx, paymentID)
    if err != nil {
        return nil, err
    }
    return &PaymentStatus{
        PaymentID:     clientStatus.PaymentID,
        Status:        clientStatus.Status,
        TransactionID: clientStatus.TransactionID,
        ProcessedAt:   clientStatus.ProcessedAt,
        FailedAt:      clientStatus.FailedAt,
        FailureReason: clientStatus.FailureReason,
    }, nil
}
```

---

### 3. Order Payment Integration

#### AddPayment Method
**Location**: `order/internal/biz/order.go:421`

**Flow**:
1. Get order
2. Create payment record:
   - OrderID, PaymentID
   - PaymentMethod, PaymentProvider
   - Amount, Currency
   - Status: "pending"
   - TransactionID, GatewayResponse
3. Save payment via OrderPaymentRepo
4. Update order PaymentStatus to "processing"

**Key Code**:
```go
func (uc *OrderUsecase) AddPayment(ctx context.Context, req *AddPaymentRequest) (*OrderPayment, error) {
    // Get order
    modelOrder, err := uc.orderRepo.FindByID(ctx, req.OrderID)
    order := convertModelOrderToBiz(modelOrder)
    
    // Create payment record
    modelPayment := &model.OrderPayment{
        OrderID:         req.OrderID,
        PaymentID:      req.PaymentID,
        PaymentMethod:   req.PaymentMethod,
        PaymentProvider: req.PaymentProvider,
        Amount:          req.Amount,
        Currency:        req.Currency,
        Status:          "pending",
        TransactionID:   req.TransactionID,
        GatewayResponse: req.GatewayResponse,
    }
    
    // Save payment
    createdModelPayment, err := uc.orderPaymentRepo.Create(ctx, modelPayment)
    
    // Update order payment status
    order.PaymentStatus = "processing"
    uc.orderRepo.Update(ctx, modelOrder, nil)
    
    return convertModelOrderPaymentToBiz(createdModelPayment), nil
}
```

---

## 📊 Domain Models

### PaymentRequest
```go
type PaymentRequest struct {
    OrderID         int64
    Amount          float64
    Currency        string
    PaymentMethod   string      // e.g., "credit_card", "paypal"
    PaymentProvider string      // e.g., "stripe", "paypal"
    Metadata        map[string]interface{}
}
```

### PaymentResponse
```go
type PaymentResponse struct {
    PaymentID     string
    Status        string        // "pending", "authorized", "captured", "failed"
    TransactionID string
    GatewayData   map[string]interface{}
}
```

### PaymentStatus
```go
type PaymentStatus struct {
    PaymentID     string
    Status        string
    TransactionID string
    ProcessedAt   *time.Time
    FailedAt      *time.Time
    FailureReason string
}
```

### OrderPayment (Database Model)
```go
type OrderPayment struct {
    ID              int64
    OrderID         int64
    PaymentID       string
    PaymentMethod   string
    PaymentProvider string
    Amount          float64
    Currency        string
    Status          string
    TransactionID   string
    GatewayResponse map[string]interface{}
    ProcessedAt     *time.Time
    FailedAt        *time.Time
    FailureReason   string
    CreatedAt       time.Time
    UpdatedAt       time.Time
}
```

---

## 🔔 Payment Flow

### Payment Processing Flow
```
1. Order Created (Status: "pending", PaymentStatus: "pending")
   ↓
2. Call PaymentService.ProcessPayment()
   ↓
3. Payment Service processes payment via gateway
   ↓
4. Payment Service returns PaymentResponse
   ↓
5. Order Service calls AddPayment()
   - Creates OrderPayment record
   - Updates Order.PaymentStatus to "processing"
   ↓
6. Payment Service webhook/status update
   ↓
7. Order Service updates OrderPayment.Status
   ↓
8. Order Service updates Order.PaymentStatus
   - "authorized" → Order.Status: "confirmed"
   - "captured" → Order.Status: "processing"
   - "failed" → Order.Status: "failed"
```

---

## 🔐 Business Rules

### Payment Statuses
- **pending**: Payment initiated, awaiting processing
- **authorized**: Payment authorized but not captured
- **captured**: Payment captured and funds transferred
- **failed**: Payment failed
- **refunded**: Payment refunded
- **cancelled**: Payment cancelled

### Payment Methods
- Credit Card
- Debit Card
- PayPal
- Bank Transfer
- Digital Wallet

### Payment Providers
- Stripe
- PayPal
- Square
- Custom gateways

### Circuit Breaker
- **Purpose**: Prevent cascading failures
- **Implementation**: Wraps HTTP calls
- **Behavior**: Opens circuit on repeated failures
- **Recovery**: Attempts recovery after timeout

---

## 🔗 Service Integration

### Order Service
- **AddPayment**: Record payment in order
- **Update PaymentStatus**: Update order payment status based on payment result

### Payment Service (External)
- **ProcessPayment**: Process payment transaction
- **GetPaymentStatus**: Get payment status
- **Webhook Handler**: Receive payment status updates

### Payment Gateways
- **Stripe**: Credit card processing
- **PayPal**: PayPal payments
- **Other**: Custom gateway integrations

---

## 🚨 Error Handling

### Common Errors
- **Payment Service Unavailable**: Circuit breaker opens
- **Payment Not Found**: 404 from payment service
- **Payment Failed**: Payment gateway returns error
- **Invalid Payment Method**: Unsupported payment method

### Error Scenarios
1. **Payment Service Down**: Circuit breaker prevents calls, returns error
2. **Payment Gateway Error**: Payment service returns error, order status updated
3. **Timeout**: HTTP timeout, circuit breaker may open
4. **Invalid Request**: Validation error before calling payment service

---

## 📈 Resilience Patterns

### Circuit Breaker
- **State**: Closed → Open → Half-Open
- **Failure Threshold**: Configurable
- **Timeout**: Configurable recovery timeout
- **Fallback**: Returns error, doesn't block order creation

### Retry Logic
- **Not Implemented**: Currently no retry logic
- **Future**: Could add exponential backoff retry

### Timeout
- **Default**: Dapr default timeout
- **Configurable**: Via client configuration

---

## 📝 Notes & TODOs

### Current Status
- ✅ Payment client integration complete
- ✅ Circuit breaker implemented
- ✅ Payment records stored in order service
- ❌ Full Payment Service implementation pending
- ❌ Payment gateway integrations pending
- ❌ Webhook handling pending
- ❌ Refund processing pending

### Future Enhancements
1. **Full Payment Service**
   - Payment gateway integrations
   - Payment method management
   - Fraud detection
   - Refund processing
   - Chargeback handling

2. **Payment Features**
   - Saved payment methods
   - Payment method validation
   - Payment retry logic
   - Payment webhook handling
   - Payment reconciliation

3. **Security**
   - PCI compliance
   - Payment data encryption
   - Tokenization
   - Secure payment storage

---

## 📚 Related Documentation

- [Order Service Logic](./ORDER_SERVICE_LOGIC.md)
- [Payment Service Implementation Checklist](./PAYMENT_IMPLEMENTATION_CHECKLIST.md)
- [Payment Service API Docs](../docs/services/payment-service.md)


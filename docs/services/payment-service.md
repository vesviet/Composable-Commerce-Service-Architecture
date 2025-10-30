# Payment Service

## Description
Service that handles payment gateway integration, transaction processing, and financial operations.

## Core Responsibilities
- Payment gateway integration (Stripe, PayPal, etc.)
- Transaction processing and validation
- Payment method management
- Refund and chargeback handling
- PCI compliance and security
- Payment fraud detection

## Outbound Data
- Payment transaction results
- Payment method details
- Refund confirmations
- Transaction history
- Payment status updates

## Consumers (Services that use this data)

### Order Service
- **Purpose**: Process payments during checkout
- **Data Received**: Payment confirmations, transaction IDs, payment status

### Customer Service
- **Purpose**: Store payment methods and transaction history
- **Data Received**: Saved payment methods, transaction records

### Notification Service
- **Purpose**: Send payment confirmations and alerts
- **Data Received**: Payment success/failure notifications

## Data Sources

### Order Service
- **Purpose**: Receive payment requests and order details
- **Data Received**: Order amounts, customer info, billing details

### Customer Service
- **Purpose**: Get customer payment preferences and saved methods
- **Data Received**: Customer payment profiles, billing addresses

## Main APIs
- `POST /payments/process` - Process payment transaction
- `POST /payments/refund` - Process refund
- `GET /payments/methods/{customerId}` - Get customer payment methods
- `POST /payments/methods` - Save new payment method
- `GET /payments/transaction/{id}` - Get transaction details
- `POST /payments/webhook` - Handle payment gateway webhooks

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/payments
Staging: https://staging-api.domain.com/v1/payments
Local: http://localhost:8004/v1/payments
```

### Authentication
- **Type**: JWT Bearer Token + API Key
- **Required Scopes**: `payments:read`, `payments:write`, `payments:admin`
- **Rate Limiting**: 100 requests/minute per user (strict for security)
- **IP Whitelisting**: Production endpoints require IP whitelisting

### Payment Processing APIs

#### POST /payments/process
**Purpose**: Process a payment transaction

**Request**:
```http
POST /v1/payments/process
Authorization: Bearer {jwt_token}
X-API-Key: {api_key}
Content-Type: application/json
X-Idempotency-Key: {unique_key}

{
  "orderId": "order_789",
  "amount": 1360.20,
  "currency": "USD",
  "paymentMethod": {
    "type": "credit_card",
    "token": "pm_1234567890", // Tokenized payment method
    "cvv": "123", // Only for one-time payments
    "saveMethod": false
  },
  "billingAddress": {
    "firstName": "John",
    "lastName": "Doe",
    "street": "123 Main St",
    "city": "New York",
    "state": "NY",
    "zipCode": "10001",
    "country": "US"
  },
  "customerInfo": {
    "customerId": "cust_456",
    "email": "john@example.com",
    "ipAddress": "192.168.1.100",
    "userAgent": "Mozilla/5.0..."
  },
  "metadata": {
    "source": "web_checkout",
    "campaign": "holiday_sale"
  }
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "transaction": {
      "id": "txn_abc123",
      "orderId": "order_789",
      "status": "succeeded",
      "amount": 1360.20,
      "currency": "USD",
      "paymentMethod": {
        "type": "credit_card",
        "brand": "visa",
        "last4": "1234",
        "expiryMonth": 12,
        "expiryYear": 2025
      },
      "gatewayResponse": {
        "provider": "stripe",
        "transactionId": "pi_1234567890",
        "authCode": "123456",
        "avsResult": "Y",
        "cvvResult": "M"
      },
      "fraudCheck": {
        "score": 15,
        "status": "passed",
        "rules": ["low_risk_customer", "verified_address"]
      },
      "fees": {
        "processingFee": 39.45,
        "currency": "USD"
      },
      "processedAt": "2024-01-15T10:30:00Z",
      "createdAt": "2024-01-15T10:30:00Z"
    }
  },
  "meta": {
    "requestId": "req_payment_123",
    "timestamp": "2024-01-15T10:30:00Z",
    "processingTime": "1.2s"
  }
}
```

**Error Response**:
```json
{
  "success": false,
  "error": {
    "code": "PAYMENT_DECLINED",
    "message": "Your card was declined",
    "details": {
      "declineCode": "insufficient_funds",
      "gatewayMessage": "Your card has insufficient funds"
    },
    "retryable": false
  },
  "data": {
    "transaction": {
      "id": "txn_failed_456",
      "status": "failed",
      "failureReason": "card_declined"
    }
  }
}
```

#### POST /payments/refund
**Purpose**: Process a refund for a transaction

**Request**:
```http
POST /v1/payments/refund
Authorization: Bearer {jwt_token}
X-API-Key: {api_key}
Content-Type: application/json

{
  "transactionId": "txn_abc123",
  "amount": 1360.20, // Full refund, or partial amount
  "reason": "customer_request",
  "notes": "Customer returned items",
  "notifyCustomer": true
}
```

#### GET /payments/methods/{customerId}
**Purpose**: Get customer's saved payment methods

**Request**:
```http
GET /v1/payments/methods/cust_456
Authorization: Bearer {jwt_token}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "paymentMethods": [
      {
        "id": "pm_saved_123",
        "type": "credit_card",
        "brand": "visa",
        "last4": "1234",
        "expiryMonth": 12,
        "expiryYear": 2025,
        "isDefault": true,
        "billingAddress": {
          "street": "123 Main St",
          "city": "New York",
          "state": "NY",
          "zipCode": "10001",
          "country": "US"
        },
        "createdAt": "2024-01-10T10:00:00Z"
      }
    ]
  }
}
```

#### POST /payments/methods
**Purpose**: Save a new payment method

#### DELETE /payments/methods/{methodId}
**Purpose**: Delete a saved payment method

#### GET /payments/transaction/{transactionId}
**Purpose**: Get transaction details

#### POST /payments/webhook
**Purpose**: Handle payment gateway webhooks

**Request**:
```http
POST /v1/payments/webhook
X-Webhook-Signature: {signature}
Content-Type: application/json

{
  "type": "payment_intent.succeeded",
  "data": {
    "object": {
      "id": "pi_1234567890",
      "amount": 136020,
      "currency": "usd",
      "status": "succeeded"
    }
  }
}
```

## 🗄️ Database Schema

### Primary Database: PostgreSQL (Encrypted)

#### transactions
```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    
    -- Transaction details
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(20) NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'payment', -- payment, refund, chargeback
    
    -- Payment method (tokenized)
    payment_method_id UUID,
    payment_method_type VARCHAR(20) NOT NULL,
    payment_method_details JSONB, -- Encrypted sensitive data
    
    -- Gateway information
    gateway_provider VARCHAR(50) NOT NULL,
    gateway_transaction_id VARCHAR(100),
    gateway_response JSONB,
    
    -- Security and fraud
    fraud_score INTEGER,
    fraud_status VARCHAR(20),
    fraud_rules JSONB,
    
    -- Fees
    processing_fee DECIMAL(10,2),
    gateway_fee DECIMAL(10,2),
    
    -- Audit trail
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    
    -- Indexes
    INDEX idx_transactions_order (order_id),
    INDEX idx_transactions_customer (customer_id),
    INDEX idx_transactions_status (status),
    INDEX idx_transactions_gateway_id (gateway_transaction_id),
    INDEX idx_transactions_processed_at (processed_at),
    
    -- Constraints
    CONSTRAINT chk_transactions_status CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded')),
    CONSTRAINT chk_transactions_type CHECK (type IN ('payment', 'refund', 'chargeback', 'adjustment'))
);
```

#### payment_methods
```sql
CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    
    -- Payment method details (encrypted)
    type VARCHAR(20) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    provider_method_id VARCHAR(100), -- Gateway's payment method ID
    
    -- Card details (encrypted/tokenized)
    card_brand VARCHAR(20),
    card_last4 VARCHAR(4),
    card_expiry_month INTEGER,
    card_expiry_year INTEGER,
    card_fingerprint VARCHAR(100), -- For duplicate detection
    
    -- Billing address (encrypted)
    billing_address JSONB,
    
    -- Status and preferences
    is_default BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'active',
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE,
    
    -- Indexes
    INDEX idx_payment_methods_customer (customer_id),
    INDEX idx_payment_methods_fingerprint (card_fingerprint),
    INDEX idx_payment_methods_status (status),
    
    -- Constraints
    CONSTRAINT chk_payment_methods_type CHECK (type IN ('credit_card', 'debit_card', 'paypal', 'apple_pay', 'google_pay')),
    CONSTRAINT chk_payment_methods_status CHECK (status IN ('active', 'expired', 'disabled'))
);
```

#### refunds
```sql
CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id),
    order_id UUID NOT NULL,
    
    -- Refund details
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    reason VARCHAR(100),
    notes TEXT,
    
    -- Gateway information
    gateway_refund_id VARCHAR(100),
    gateway_response JSONB,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    processed_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    
    -- Indexes
    INDEX idx_refunds_transaction (transaction_id),
    INDEX idx_refunds_order (order_id),
    INDEX idx_refunds_status (status),
    
    -- Constraints
    CONSTRAINT chk_refunds_status CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'cancelled'))
);
```

#### fraud_checks
```sql
CREATE TABLE fraud_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id),
    
    -- Fraud analysis
    score INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL,
    rules_triggered JSONB,
    risk_factors JSONB,
    
    -- Request context
    ip_address INET,
    user_agent TEXT,
    device_fingerprint VARCHAR(100),
    geolocation JSONB,
    
    -- Analysis results
    velocity_checks JSONB,
    blacklist_checks JSONB,
    ml_model_results JSONB,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_fraud_checks_transaction (transaction_id),
    INDEX idx_fraud_checks_score (score),
    INDEX idx_fraud_checks_status (status),
    INDEX idx_fraud_checks_ip (ip_address)
);
```

### Secure Vault Database (Separate, Encrypted)
```sql
-- Sensitive payment data stored in separate encrypted database
CREATE TABLE payment_tokens (
    token_id UUID PRIMARY KEY,
    encrypted_data BYTEA NOT NULL, -- AES-256 encrypted payment data
    key_version INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- No indexes on sensitive data for security
    INDEX idx_payment_tokens_expires (expires_at)
);
```

## 🔒 Security Implementation

### PCI DSS Compliance

#### Level 1 PCI DSS Requirements
- **Network Security**: Firewalls, network segmentation
- **Data Protection**: Encryption at rest and in transit
- **Access Control**: Strong authentication, role-based access
- **Monitoring**: Comprehensive logging and monitoring
- **Testing**: Regular security testing and vulnerability scans
- **Policies**: Information security policies and procedures

#### Data Classification
```
Level 1 (Highly Sensitive):
- Full credit card numbers (PAN)
- CVV/CVC codes
- Magnetic stripe data
- PIN data

Level 2 (Sensitive):
- Tokenized payment data
- Customer billing information
- Transaction details

Level 3 (Internal):
- Transaction metadata
- Fraud scores
- Processing logs
```

### Encryption Standards

#### Data at Rest
```yaml
Database Encryption:
  Algorithm: AES-256-GCM
  Key Management: AWS KMS / HashiCorp Vault
  Key Rotation: Every 90 days
  Backup Encryption: Enabled

File System Encryption:
  Algorithm: AES-256-XTS
  Full disk encryption on all servers
```

#### Data in Transit
```yaml
TLS Configuration:
  Version: TLS 1.3 minimum
  Cipher Suites: AEAD ciphers only
  Certificate: EV SSL certificates
  HSTS: Enabled with preload

API Security:
  mTLS: Required for service-to-service
  Certificate Pinning: Enabled
  Perfect Forward Secrecy: Enabled
```

### Tokenization System

#### Payment Method Tokenization
```go
// Example tokenization flow
type TokenizationService struct {
    vault VaultService
    crypto CryptoService
}

func (s *TokenizationService) TokenizePaymentMethod(paymentData PaymentData) (string, error) {
    // 1. Generate unique token
    token := generateSecureToken()
    
    // 2. Encrypt sensitive data
    encryptedData, err := s.crypto.Encrypt(paymentData, getCurrentKey())
    if err != nil {
        return "", err
    }
    
    // 3. Store in secure vault
    err = s.vault.Store(token, encryptedData)
    if err != nil {
        return "", err
    }
    
    // 4. Return token for use in main database
    return token, nil
}
```

#### Token Format
```
Format: pm_[environment]_[random_32_chars]
Example: pm_prod_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

Validation:
- Length: 40 characters
- Prefix: Environment-specific
- Entropy: 128 bits minimum
- Expiry: Configurable (default: 5 years)
```

### Fraud Detection System

#### Real-time Fraud Scoring
```go
type FraudDetector struct {
    rules []FraudRule
    mlModel MLModel
    blacklist BlacklistService
}

func (f *FraudDetector) AnalyzeTransaction(tx Transaction) FraudResult {
    score := 0
    triggeredRules := []string{}
    
    // 1. Rule-based checks
    for _, rule := range f.rules {
        if rule.Matches(tx) {
            score += rule.Weight
            triggeredRules = append(triggeredRules, rule.Name)
        }
    }
    
    // 2. Machine learning model
    mlScore := f.mlModel.Predict(tx.Features())
    score += int(mlScore * 100)
    
    // 3. Blacklist checks
    if f.blacklist.IsBlacklisted(tx.CustomerID, tx.IPAddress) {
        score += 50
        triggeredRules = append(triggeredRules, "blacklisted")
    }
    
    // 4. Determine action
    action := f.determineAction(score)
    
    return FraudResult{
        Score: score,
        Action: action,
        TriggeredRules: triggeredRules,
    }
}
```

#### Fraud Rules Examples
```yaml
High Risk Rules (Score: 50+):
  - Multiple failed attempts from same IP
  - Transaction from blacklisted country
  - Unusual spending pattern (>10x average)
  - Velocity: >5 transactions in 1 minute

Medium Risk Rules (Score: 20-49):
  - New payment method on existing account
  - Transaction outside normal hours
  - Different billing/shipping address
  - High-value transaction (>$1000)

Low Risk Rules (Score: 1-19):
  - First-time customer
  - Mobile device transaction
  - Weekend transaction
  - International transaction
```

### 3D Secure Authentication

#### 3DS 2.0 Implementation
```go
func (p *PaymentProcessor) Process3DSecure(payment PaymentRequest) (*PaymentResult, error) {
    // 1. Check if 3DS is required
    if p.requires3DS(payment) {
        // 2. Initiate 3DS authentication
        authRequest := &ThreeDSAuthRequest{
            Amount: payment.Amount,
            Currency: payment.Currency,
            CardNumber: payment.CardToken,
            MerchantInfo: p.merchantInfo,
            BrowserInfo: payment.BrowserInfo,
        }
        
        authResult, err := p.threeDSProvider.Authenticate(authRequest)
        if err != nil {
            return nil, err
        }
        
        // 3. Handle authentication result
        switch authResult.Status {
        case "authenticated":
            // Proceed with payment
            return p.processPayment(payment, authResult.AuthToken)
        case "challenge_required":
            // Return challenge URL to frontend
            return &PaymentResult{
                Status: "requires_action",
                ChallengeURL: authResult.ChallengeURL,
            }, nil
        case "failed":
            return &PaymentResult{
                Status: "failed",
                Error: "3DS authentication failed",
            }, nil
        }
    }
    
    // Process without 3DS
    return p.processPayment(payment, "")
}
```

### API Security

#### Request Validation
```go
type PaymentValidator struct {
    ipWhitelist []string
    rateLimit   RateLimiter
}

func (v *PaymentValidator) ValidateRequest(req *http.Request) error {
    // 1. IP whitelist check
    clientIP := getClientIP(req)
    if !v.isWhitelisted(clientIP) {
        return errors.New("IP not whitelisted")
    }
    
    // 2. Rate limiting
    if !v.rateLimit.Allow(clientIP) {
        return errors.New("rate limit exceeded")
    }
    
    // 3. Signature validation
    if !v.validateSignature(req) {
        return errors.New("invalid signature")
    }
    
    // 4. Idempotency check
    if !v.validateIdempotency(req) {
        return errors.New("duplicate request")
    }
    
    return nil
}
```

#### Webhook Security
```go
func (w *WebhookHandler) ValidateWebhook(req *http.Request) error {
    // 1. Verify webhook signature
    signature := req.Header.Get("X-Webhook-Signature")
    body, _ := ioutil.ReadAll(req.Body)
    
    expectedSig := hmac.New(sha256.New, w.webhookSecret)
    expectedSig.Write(body)
    expectedSignature := hex.EncodeToString(expectedSig.Sum(nil))
    
    if !hmac.Equal([]byte(signature), []byte(expectedSignature)) {
        return errors.New("invalid webhook signature")
    }
    
    // 2. Check timestamp to prevent replay attacks
    timestamp := req.Header.Get("X-Webhook-Timestamp")
    if w.isTimestampTooOld(timestamp) {
        return errors.New("webhook timestamp too old")
    }
    
    return nil
}
```

## 📨 Event Schemas

### Published Events

#### PaymentProcessed
**Topic**: `payments.payment.processed`
**Version**: 1.0

```json
{
  "eventId": "evt_payment_123",
  "eventType": "PaymentProcessed",
  "version": "1.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "source": "payment-service",
  "data": {
    "transactionId": "txn_abc123",
    "orderId": "order_789",
    "customerId": "cust_456",
    "amount": 1360.20,
    "currency": "USD",
    "status": "succeeded",
    "paymentMethod": {
      "type": "credit_card",
      "brand": "visa",
      "last4": "1234"
    },
    "gatewayProvider": "stripe",
    "fraudScore": 15,
    "processedAt": "2024-01-15T10:30:00Z"
  },
  "metadata": {
    "correlationId": "corr_order_789",
    "sensitive": true
  }
}
```

#### PaymentFailed
**Topic**: `payments.payment.failed`
**Version**: 1.0

#### RefundProcessed
**Topic**: `payments.refund.processed`
**Version**: 1.0

#### FraudDetected
**Topic**: `payments.fraud.detected`
**Version**: 1.0

### Subscribed Events

#### OrderCreated
**Topic**: `orders.order.created`
**Source**: order-service

#### OrderCancelled
**Topic**: `orders.order.cancelled`
**Source**: order-service

## 🛡️ Security Monitoring

### Security Metrics
```yaml
Authentication Failures:
  - Failed API key validations
  - Invalid JWT tokens
  - IP whitelist violations

Fraud Detection:
  - High fraud score transactions
  - Blacklist hits
  - Velocity rule violations

Data Access:
  - Sensitive data access logs
  - Token generation/usage
  - Encryption key usage

System Security:
  - Failed login attempts
  - Privilege escalation attempts
  - Unusual API usage patterns
```

### Incident Response
```yaml
Severity Levels:
  Critical (P0):
    - Data breach suspected
    - Payment processing down
    - Fraud attack in progress
    
  High (P1):
    - High fraud scores detected
    - Gateway connectivity issues
    - Security rule violations
    
  Medium (P2):
    - Unusual transaction patterns
    - Performance degradation
    - Configuration changes

Response Times:
  P0: 15 minutes
  P1: 1 hour
  P2: 4 hours
```
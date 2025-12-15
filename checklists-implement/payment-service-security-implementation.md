# 🔐 Payment Service Security Implementation Checklist

**Service**: Payment Service  
**Priority**: 🔴 **CRITICAL**  
**Timeline**: 1 tuần (5 ngày làm việc)  
**Compliance**: PCI DSS Level 1  
**Current Status**: 65% → Target: 90%

---

## 📋 Overview

Payment Service hiện tại đã có foundation tốt nhưng thiếu **critical security features** để production-ready:

### 🎯 Implementation Goals
- **3D Secure (3DS)**: Implement 3DS authentication flow
- **Fraud Detection**: Advanced fraud scoring system  
- **Enhanced Tokenization**: Complete card tokenization
- **PCI DSS Compliance**: Full compliance audit
- **Webhook Security**: Secure webhook handling
- **Performance**: <3s payment processing (p95)

### 🔍 Current State Analysis
```
✅ Basic payment processing (authorize/capture)
✅ Multi-gateway support (Stripe, PayPal, VNPay)
✅ Payment methods (card, wallet, bank transfer, COD)
✅ Refund system
✅ Database schema complete
🔴 3D Secure implementation - MISSING
🔴 Advanced fraud detection - BASIC ONLY
🔴 Enhanced tokenization - INCOMPLETE
🔴 Webhook security - BASIC
🔴 PCI DSS audit - NOT DONE
```

---

## 🚀 Phase 1: 3D Secure Implementation (Day 1-2)

### Priority 1.1: 3DS Core Implementation

**Files to modify:**
- `internal/biz/payment/threeds.go` ✅ (exists)
- `internal/biz/gateway/stripe.go` 
- `internal/service/payment.go`

#### Task 1.1.1: Complete 3DS Flow (4 hours)

**Location**: `internal/biz/payment/threeds.go`

```go
// ✅ ADD: Complete 3DS implementation
func (uc *PaymentUsecase) shouldRequire3DS(req *ProcessPaymentRequest) bool {
    // 1. High-value transactions (>$100 or >2,000,000 VND)
    if req.Amount >= 100 && req.Currency == "USD" {
        return true
    }
    if req.Amount >= 2000000 && req.Currency == "VND" {
        return true
    }
    
    // 2. International cards (issuer country != merchant country)
    if req.CardIssuerCountry != uc.config.MerchantCountry {
        return true
    }
    
    // 3. EU SCA (Strong Customer Authentication) requirements
    if uc.isEUCountry(req.CardIssuerCountry) {
        return true
    }
    
    // 4. First-time customer
    if req.CustomerID != "" {
        isFirstTime, _ := uc.customerRepo.IsFirstTimeCustomer(req.CustomerID)
        if isFirstTime {
            return true
        }
    }
    
    return false
}

func (uc *PaymentUsecase) Create3DSChallenge(ctx context.Context, req *Create3DSRequest) (*ThreeDSChallenge, error) {
    // Implementation for 3DS challenge creation
    challenge, err := uc.gateway.Create3DSChallenge(ctx, &gateway.Create3DSRequest{
        CardToken:   req.CardToken,
        Amount:      req.Amount,
        Currency:    req.Currency,
        ReturnURL:   req.ReturnURL,
        OrderID:     req.OrderID,
    })
    
    if err != nil {
        return nil, fmt.Errorf("failed to create 3DS challenge: %w", err)
    }
    
    // Store 3DS session
    session := &ThreeDSSession{
        ID:          uuid.New().String(),
        PaymentID:   req.PaymentID,
        ChallengeID: challenge.ID,
        Status:      "pending",
        CreatedAt:   time.Now(),
        ExpiresAt:   time.Now().Add(10 * time.Minute),
    }
    
    if err := uc.threeDSRepo.SaveSession(ctx, session); err != nil {
        return nil, err
    }
    
    return &ThreeDSChallenge{
        ChallengeID: challenge.ID,
        ChallengeURL: challenge.URL,
        ExpiresAt:   session.ExpiresAt,
    }, nil
}

func (uc *PaymentUsecase) Handle3DSCallback(ctx context.Context, req *ThreeDSCallbackRequest) (*PaymentResult, error) {
    // Verify 3DS authentication result
    session, err := uc.threeDSRepo.GetSession(ctx, req.ChallengeID)
    if err != nil {
        return nil, err
    }
    
    if session.Status != "pending" {
        return nil, ErrInvalidThreeDSSession
    }
    
    // Verify with gateway
    authResult, err := uc.gateway.Verify3DSAuthentication(ctx, req.ChallengeID, req.AuthToken)
    if err != nil {
        return nil, err
    }
    
    // Update session
    session.Status = authResult.Status
    session.AuthenticationValue = authResult.AuthValue
    session.CompletedAt = timePtr(time.Now())
    
    if err := uc.threeDSRepo.UpdateSession(ctx, session); err != nil {
        return nil, err
    }
    
    if authResult.Status == "authenticated" {
        // Continue with payment processing
        return uc.continuePaymentAfter3DS(ctx, session.PaymentID, authResult)
    }
    
    return &PaymentResult{
        Status:  "failed",
        Message: "3D Secure authentication failed",
    }, nil
}
```

#### Task 1.1.2: Gateway 3DS Integration (3 hours)

**Location**: `internal/biz/gateway/stripe.go`

```go
// ✅ ADD: Stripe 3DS integration
func (g *StripeGateway) Create3DSChallenge(ctx context.Context, req *Create3DSRequest) (*ThreeDSChallenge, error) {
    params := &stripe.PaymentIntentParams{
        Amount:   stripe.Int64(int64(req.Amount * 100)), // Convert to cents
        Currency: stripe.String(req.Currency),
        PaymentMethod: stripe.String(req.CardToken),
        ConfirmationMethod: stripe.String("manual"),
        Confirm: stripe.Bool(true),
        ReturnURL: stripe.String(req.ReturnURL),
    }
    
    // Force 3DS challenge
    params.PaymentMethodOptions = &stripe.PaymentIntentPaymentMethodOptionsParams{
        Card: &stripe.PaymentIntentPaymentMethodOptionsCardParams{
            RequestThreeDSecure: stripe.String("any"),
        },
    }
    
    pi, err := paymentintent.New(params)
    if err != nil {
        return nil, fmt.Errorf("stripe 3DS creation failed: %w", err)
    }
    
    if pi.Status == "requires_action" && pi.NextAction != nil {
        return &ThreeDSChallenge{
            ID:  pi.ID,
            URL: pi.NextAction.RedirectToURL.URL,
        }, nil
    }
    
    return nil, fmt.Errorf("unexpected payment intent status: %s", pi.Status)
}

func (g *StripeGateway) Verify3DSAuthentication(ctx context.Context, challengeID, authToken string) (*ThreeDSResult, error) {
    pi, err := paymentintent.Get(challengeID, nil)
    if err != nil {
        return nil, err
    }
    
    var status string
    var authValue string
    
    switch pi.Status {
    case "succeeded":
        status = "authenticated"
        if pi.Charges != nil && len(pi.Charges.Data) > 0 {
            charge := pi.Charges.Data[0]
            if charge.PaymentMethodDetails != nil && charge.PaymentMethodDetails.Card != nil {
                authValue = charge.PaymentMethodDetails.Card.ThreeDSecure.AuthenticationFlow
            }
        }
    case "requires_payment_method":
        status = "failed"
    default:
        status = "pending"
    }
    
    return &ThreeDSResult{
        Status:    status,
        AuthValue: authValue,
    }, nil
}
```

#### Task 1.1.3: Service Layer Integration (2 hours)

**Location**: `internal/service/payment.go`

```go
// ✅ ADD: 3DS service endpoints
func (s *PaymentService) ProcessPayment(ctx context.Context, req *pb.ProcessPaymentRequest) (*pb.ProcessPaymentResponse, error) {
    // Convert proto to biz request
    bizReq := &payment.ProcessPaymentRequest{
        OrderID:           req.OrderId,
        CustomerID:        req.CustomerId,
        Amount:            req.Amount,
        Currency:          req.Currency,
        PaymentMethod:     req.PaymentMethod,
        CardToken:         req.CardToken,
        CardIssuerCountry: req.CardIssuerCountry,
        ReturnURL:         req.ReturnUrl,
    }
    
    result, err := s.paymentUC.ProcessPayment(ctx, bizReq)
    if err != nil {
        return nil, err
    }
    
    response := &pb.ProcessPaymentResponse{
        PaymentId: result.PaymentID,
        Status:    result.Status,
        Amount:    result.Amount,
        Currency:  result.Currency,
    }
    
    // Handle 3DS challenge
    if result.RequiresAction && result.ActionType == "3ds_authentication" {
        response.RequiresAction = true
        response.ThreeDsChallenge = &pb.ThreeDSChallenge{
            ChallengeId:  result.ThreeDSChallenge.ChallengeID,
            ChallengeUrl: result.ThreeDSChallenge.ChallengeURL,
            ExpiresAt:    timestamppb.New(result.ThreeDSChallenge.ExpiresAt),
        }
    }
    
    return response, nil
}

func (s *PaymentService) Handle3DSCallback(ctx context.Context, req *pb.Handle3DSCallbackRequest) (*pb.Handle3DSCallbackResponse, error) {
    bizReq := &payment.ThreeDSCallbackRequest{
        ChallengeID: req.ChallengeId,
        AuthToken:   req.AuthToken,
    }
    
    result, err := s.paymentUC.Handle3DSCallback(ctx, bizReq)
    if err != nil {
        return nil, err
    }
    
    return &pb.Handle3DSCallbackResponse{
        PaymentId: result.PaymentID,
        Status:    result.Status,
        Message:   result.Message,
    }, nil
}
```

### Priority 1.2: 3DS Testing (Day 2)

#### Task 1.2.1: Unit Tests (2 hours)

**Location**: `internal/biz/payment/threeds_test.go`

```go
func TestShouldRequire3DS(t *testing.T) {
    tests := []struct {
        name     string
        req      *ProcessPaymentRequest
        expected bool
    }{
        {
            name: "high_value_usd",
            req: &ProcessPaymentRequest{
                Amount:   150,
                Currency: "USD",
            },
            expected: true,
        },
        {
            name: "international_card",
            req: &ProcessPaymentRequest{
                Amount:            50,
                Currency:          "USD",
                CardIssuerCountry: "GB",
            },
            expected: true,
        },
        {
            name: "eu_card_sca",
            req: &ProcessPaymentRequest{
                Amount:            30,
                Currency:          "EUR",
                CardIssuerCountry: "DE",
            },
            expected: true,
        },
        {
            name: "low_value_domestic",
            req: &ProcessPaymentRequest{
                Amount:            25,
                Currency:          "USD",
                CardIssuerCountry: "US",
            },
            expected: false,
        },
    }
    
    uc := &PaymentUsecase{
        config: &Config{MerchantCountry: "US"},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := uc.shouldRequire3DS(tt.req)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

#### Task 1.2.2: Integration Tests (3 hours)

**Location**: `test/integration/threeds_test.go`

```go
func TestThreeDSFlow(t *testing.T) {
    // Test complete 3DS flow
    // 1. Create payment requiring 3DS
    // 2. Handle 3DS challenge
    // 3. Complete authentication
    // 4. Verify payment status
}
```

---

## 🛡️ Phase 2: Advanced Fraud Detection (Day 3)

### Priority 2.1: Enhanced Fraud Scoring

#### Task 2.1.1: Advanced Fraud Rules (4 hours)

**Location**: `internal/biz/fraud/rules.go`

```go
// ✅ ENHANCE: Advanced fraud detection rules
func (fd *FraudDetector) CheckPayment(ctx context.Context, req *FraudCheckRequest) (*FraudCheckResult, error) {
    score := 0.0
    signals := []FraudSignal{}
    
    // 1. Velocity checks - enhanced
    velocityScore, velocitySignals := fd.checkEnhancedVelocity(req)
    score += velocityScore
    signals = append(signals, velocitySignals...)
    
    // 2. Device fingerprinting
    deviceScore, deviceSignals := fd.checkDeviceFingerprint(req)
    score += deviceScore
    signals = append(signals, deviceSignals...)
    
    // 3. Behavioral analysis
    behaviorScore, behaviorSignals := fd.checkBehavioralPatterns(req)
    score += behaviorScore
    signals = append(signals, behaviorSignals...)
    
    // 4. Machine learning model (if available)
    if fd.mlModel != nil {
        mlScore, mlSignals := fd.runMLModel(req)
        score += mlScore
        signals = append(signals, mlSignals...)
    }
    
    // 5. Real-time blacklist check
    blacklistScore, blacklistSignals := fd.checkBlacklists(req)
    score += blacklistScore
    signals = append(signals, blacklistSignals...)
    
    // Determine action based on score
    action := fd.determineAction(score)
    
    return &FraudCheckResult{
        Score:     score,
        RiskLevel: fd.getRiskLevel(score),
        Signals:   signals,
        Action:    action,
    }, nil
}

func (fd *FraudDetector) checkEnhancedVelocity(req *FraudCheckRequest) (float64, []FraudSignal) {
    score := 0.0
    signals := []FraudSignal{}
    
    // Check multiple time windows
    timeWindows := []struct {
        duration time.Duration
        limit    int
        weight   float64
    }{
        {5 * time.Minute, 3, 30},   // 3 transactions in 5 minutes
        {1 * time.Hour, 10, 20},    // 10 transactions in 1 hour
        {24 * time.Hour, 50, 10},   // 50 transactions in 24 hours
    }
    
    for _, window := range timeWindows {
        count := fd.getTransactionCount(req.CustomerID, req.CustomerIP, window.duration)
        if count > window.limit {
            score += window.weight
            signals = append(signals, FraudSignal{
                Name:        fmt.Sprintf("velocity_%s", window.duration),
                Value:       count,
                Weight:      window.weight,
                Description: fmt.Sprintf("%d transactions in %s", count, window.duration),
            })
        }
    }
    
    return score, signals
}

func (fd *FraudDetector) checkDeviceFingerprint(req *FraudCheckRequest) (float64, []FraudSignal) {
    score := 0.0
    signals := []FraudSignal{}
    
    if req.DeviceID == "" {
        score += 15
        signals = append(signals, FraudSignal{
            Name:        "missing_device_fingerprint",
            Value:       true,
            Weight:      15,
            Description: "Device fingerprint not provided",
        })
        return score, signals
    }
    
    // Check if device is known for this customer
    if req.CustomerID != "" {
        knownDevices := fd.getCustomerDevices(req.CustomerID)
        if !contains(knownDevices, req.DeviceID) {
            score += 10
            signals = append(signals, FraudSignal{
                Name:        "unknown_device",
                Value:       req.DeviceID,
                Weight:      10,
                Description: "Transaction from unknown device",
            })
        }
    }
    
    // Check device reputation
    deviceRisk := fd.getDeviceRiskScore(req.DeviceID)
    if deviceRisk > 0.7 {
        score += 25
        signals = append(signals, FraudSignal{
            Name:        "high_risk_device",
            Value:       deviceRisk,
            Weight:      25,
            Description: "Device has high fraud risk score",
        })
    }
    
    return score, signals
}
```

#### Task 2.1.2: Machine Learning Integration (3 hours)

**Location**: `internal/biz/fraud/ml_model.go`

```go
// ✅ ADD: ML model integration for fraud detection
type MLFraudModel struct {
    modelEndpoint string
    httpClient    *http.Client
    log           *log.Helper
}

func (ml *MLFraudModel) PredictFraudScore(ctx context.Context, features *FraudFeatures) (float64, error) {
    // Prepare features for ML model
    payload := map[string]interface{}{
        "amount":              features.Amount,
        "currency":            features.Currency,
        "customer_age_days":   features.CustomerAgeDays,
        "transaction_hour":    features.TransactionHour,
        "is_weekend":          features.IsWeekend,
        "billing_shipping_match": features.BillingShippingMatch,
        "card_country":        features.CardCountry,
        "ip_country":          features.IPCountry,
        "device_score":        features.DeviceScore,
        "velocity_1h":         features.Velocity1H,
        "velocity_24h":        features.Velocity24H,
    }
    
    // Call ML service
    response, err := ml.callMLService(ctx, payload)
    if err != nil {
        ml.log.Errorf("ML model call failed: %v", err)
        return 0, err // Don't block payment on ML failure
    }
    
    return response.FraudScore, nil
}

func (ml *MLFraudModel) callMLService(ctx context.Context, payload map[string]interface{}) (*MLResponse, error) {
    jsonPayload, _ := json.Marshal(payload)
    
    req, err := http.NewRequestWithContext(ctx, "POST", ml.modelEndpoint, bytes.NewBuffer(jsonPayload))
    if err != nil {
        return nil, err
    }
    
    req.Header.Set("Content-Type", "application/json")
    
    resp, err := ml.httpClient.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    var mlResp MLResponse
    if err := json.NewDecoder(resp.Body).Decode(&mlResp); err != nil {
        return nil, err
    }
    
    return &mlResp, nil
}
```

### Priority 2.2: Real-time Blacklist Integration

#### Task 2.2.1: Blacklist Service (2 hours)

**Location**: `internal/biz/fraud/blacklist.go`

```go
// ✅ ADD: Real-time blacklist checking
func (fd *FraudDetector) checkBlacklists(req *FraudCheckRequest) (float64, []FraudSignal) {
    score := 0.0
    signals := []FraudSignal{}
    
    // Check email blacklist
    if fd.isBlacklistedEmail(req.CustomerEmail) {
        score += 50
        signals = append(signals, FraudSignal{
            Name:        "blacklisted_email",
            Value:       req.CustomerEmail,
            Weight:      50,
            Description: "Email address is blacklisted",
        })
    }
    
    // Check IP blacklist
    if fd.isBlacklistedIP(req.CustomerIP) {
        score += 40
        signals = append(signals, FraudSignal{
            Name:        "blacklisted_ip",
            Value:       req.CustomerIP,
            Weight:      40,
            Description: "IP address is blacklisted",
        })
    }
    
    // Check card BIN blacklist
    if req.CardBIN != "" && fd.isBlacklistedBIN(req.CardBIN) {
        score += 35
        signals = append(signals, FraudSignal{
            Name:        "blacklisted_bin",
            Value:       req.CardBIN,
            Weight:      35,
            Description: "Card BIN is blacklisted",
        })
    }
    
    return score, signals
}
```

---

## 🔒 Phase 3: Enhanced Tokenization & PCI Compliance (Day 4)

### Priority 3.1: Complete Tokenization

#### Task 3.1.1: Enhanced Card Tokenization (3 hours)

**Location**: `internal/biz/gateway/tokenization.go`

```go
// ✅ ENHANCE: Complete tokenization implementation
func (g *GatewayWrapper) TokenizeCard(ctx context.Context, req *TokenizeCardRequest) (*TokenResult, error) {
    // Validate card data before tokenization
    if err := g.validateCardData(req); err != nil {
        return nil, err
    }
    
    // Never log sensitive card data
    g.log.WithContext(ctx).Infof("Tokenizing card ending in %s", req.CardNumber[len(req.CardNumber)-4:])
    
    // Call gateway tokenization
    result, err := g.gateway.TokenizeCard(ctx, req)
    if err != nil {
        return nil, fmt.Errorf("tokenization failed: %w", err)
    }
    
    // Store token metadata (never store raw card data)
    tokenMetadata := &TokenMetadata{
        Token:          result.Token,
        CardLast4:      req.CardNumber[len(req.CardNumber)-4:],
        CardBrand:      g.detectCardBrand(req.CardNumber),
        ExpiryMonth:    req.ExpiryMonth,
        ExpiryYear:     req.ExpiryYear,
        CardholderName: req.CardholderName,
        CreatedAt:      time.Now(),
    }
    
    if err := g.tokenRepo.SaveTokenMetadata(ctx, tokenMetadata); err != nil {
        g.log.Errorf("Failed to save token metadata: %v", err)
        // Don't fail tokenization, but log error
    }
    
    return result, nil
}

func (g *GatewayWrapper) validateCardData(req *TokenizeCardRequest) error {
    // Luhn algorithm validation
    if !g.validateLuhn(req.CardNumber) {
        return ErrInvalidCardNumber
    }
    
    // Expiry validation
    if g.isCardExpired(req.ExpiryMonth, req.ExpiryYear) {
        return ErrCardExpired
    }
    
    // CVV validation
    if !g.validateCVV(req.CVV, g.detectCardBrand(req.CardNumber)) {
        return ErrInvalidCVV
    }
    
    return nil
}

// CRITICAL: Never store raw card data
func (g *GatewayWrapper) processPaymentWithToken(ctx context.Context, req *ProcessPaymentRequest) (*PaymentResult, error) {
    // Ensure we're using token, not raw card data
    if req.CardNumber != "" {
        return nil, ErrRawCardDataNotAllowed
    }
    
    if req.CardToken == "" {
        return nil, ErrTokenRequired
    }
    
    // Process payment with token only
    return g.gateway.ProcessPayment(ctx, req)
}
```

### Priority 3.2: PCI DSS Compliance Audit

#### Task 3.2.1: Data Security Audit (4 hours)

**Location**: `docs/security/pci-dss-compliance.md`

```markdown
# PCI DSS Compliance Checklist

## Requirement 1: Install and maintain a firewall
- [ ] Network segmentation implemented
- [ ] Payment processing isolated
- [ ] Firewall rules documented

## Requirement 2: Do not use vendor-supplied defaults
- [ ] Default passwords changed
- [ ] Unnecessary services disabled
- [ ] Security configurations documented

## Requirement 3: Protect stored cardholder data
- [ ] ✅ No full card numbers stored
- [ ] ✅ No CVV stored
- [ ] ✅ Tokenization implemented
- [ ] Encryption at rest for sensitive data
- [ ] Key management procedures

## Requirement 4: Encrypt transmission of cardholder data
- [ ] ✅ TLS 1.2+ for all connections
- [ ] Certificate management
- [ ] Strong cryptography

## Requirement 5: Protect all systems against malware
- [ ] Anti-virus software
- [ ] Regular updates
- [ ] Malware scanning

## Requirement 6: Develop and maintain secure systems
- [ ] ✅ Secure coding practices
- [ ] ✅ Input validation
- [ ] ✅ SQL injection prevention
- [ ] Regular security testing

## Requirement 7: Restrict access by business need-to-know
- [ ] Role-based access control
- [ ] Principle of least privilege
- [ ] Access reviews

## Requirement 8: Identify and authenticate access
- [ ] ✅ Strong authentication
- [ ] ✅ Multi-factor authentication
- [ ] Password policies

## Requirement 9: Restrict physical access
- [ ] Physical security controls
- [ ] Media handling procedures
- [ ] Visitor access controls

## Requirement 10: Track and monitor all access
- [ ] ✅ Audit logging implemented
- [ ] Log monitoring
- [ ] Log retention policies

## Requirement 11: Regularly test security systems
- [ ] Vulnerability scanning
- [ ] Penetration testing
- [ ] File integrity monitoring

## Requirement 12: Maintain information security policy
- [ ] Security policies documented
- [ ] Security awareness training
- [ ] Incident response procedures
```

---

## 🔗 Phase 4: Webhook Security & Performance (Day 5)

### Priority 4.1: Secure Webhook Handling

#### Task 4.1.1: Enhanced Webhook Security (3 hours)

**Location**: `internal/biz/webhook/handler.go`

```go
// ✅ ENHANCE: Secure webhook handling
func (h *WebhookHandler) HandleWebhook(w http.ResponseWriter, r *http.Request) {
    // 1. Rate limiting
    if !h.rateLimiter.Allow(r.RemoteAddr) {
        http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
        return
    }
    
    // 2. IP whitelist check
    if !h.isAllowedIP(r.RemoteAddr) {
        h.log.Warnf("Webhook from unauthorized IP: %s", r.RemoteAddr)
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }
    
    // 3. Read body with size limit
    body, err := h.readLimitedBody(r.Body, 1024*1024) // 1MB limit
    if err != nil {
        http.Error(w, "Request too large", http.StatusRequestEntityTooLarge)
        return
    }
    
    // 4. Verify signature
    signature := r.Header.Get("X-Webhook-Signature")
    if !h.verifySignature(body, signature) {
        h.log.Warnf("Invalid webhook signature from %s", r.RemoteAddr)
        http.Error(w, "Invalid signature", http.StatusUnauthorized)
        return
    }
    
    // 5. Parse webhook
    webhook, err := h.parseWebhook(body)
    if err != nil {
        http.Error(w, "Invalid webhook format", http.StatusBadRequest)
        return
    }
    
    // 6. Idempotency check
    if h.isWebhookProcessed(webhook.ID) {
        w.WriteHeader(http.StatusOK)
        return
    }
    
    // 7. Process asynchronously
    h.processWebhookAsync(webhook)
    
    // 8. Return success immediately
    w.WriteHeader(http.StatusOK)
}

func (h *WebhookHandler) verifySignature(body []byte, signature string) bool {
    expectedSignature := h.computeSignature(body)
    return hmac.Equal([]byte(signature), []byte(expectedSignature))
}

func (h *WebhookHandler) computeSignature(body []byte) string {
    mac := hmac.New(sha256.New, []byte(h.webhookSecret))
    mac.Write(body)
    return hex.EncodeToString(mac.Sum(nil))
}
```

### Priority 4.2: Performance Optimization

#### Task 4.2.1: Payment Processing Optimization (2 hours)

**Location**: `internal/biz/payment/usecase.go`

```go
// ✅ OPTIMIZE: Payment processing performance
func (uc *PaymentUsecase) ProcessPayment(ctx context.Context, req *ProcessPaymentRequest) (*PaymentResult, error) {
    // Set timeout for payment processing
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    
    // Start performance tracking
    start := time.Now()
    defer func() {
        duration := time.Since(start)
        uc.metrics.RecordPaymentProcessingTime(duration)
        
        if duration > 3*time.Second {
            uc.log.Warnf("Slow payment processing: %v for payment %s", duration, req.OrderID)
        }
    }()
    
    // Parallel processing where possible
    var (
        fraudResult *FraudCheckResult
        fraudErr    error
        
        customerData *CustomerData
        customerErr  error
    )
    
    // Run fraud check and customer lookup in parallel
    var wg sync.WaitGroup
    wg.Add(2)
    
    go func() {
        defer wg.Done()
        fraudResult, fraudErr = uc.fraudDetector.CheckPayment(ctx, &FraudCheckRequest{
            Amount:     req.Amount,
            Currency:   req.Currency,
            CustomerID: req.CustomerID,
            // ... other fields
        })
    }()
    
    go func() {
        defer wg.Done()
        customerData, customerErr = uc.customerClient.GetCustomer(ctx, req.CustomerID)
    }()
    
    wg.Wait()
    
    // Check for errors
    if fraudErr != nil {
        uc.log.Errorf("Fraud check failed: %v", fraudErr)
        // Continue processing but log warning
    }
    
    if customerErr != nil {
        return nil, fmt.Errorf("customer lookup failed: %w", customerErr)
    }
    
    // Block high-risk payments
    if fraudResult != nil && fraudResult.Action == "block" {
        return &PaymentResult{
            Status:  "blocked",
            Message: "Payment blocked due to fraud risk",
        }, nil
    }
    
    // Continue with payment processing...
    return uc.processPaymentInternal(ctx, req, fraudResult, customerData)
}
```

#### Task 4.2.2: Database Query Optimization (2 hours)

**Location**: `internal/repository/payment.go`

```go
// ✅ OPTIMIZE: Database queries
func (r *PaymentRepository) GetPaymentWithDetails(ctx context.Context, paymentID string) (*Payment, error) {
    var payment Payment
    
    // Use single query with joins instead of multiple queries
    err := r.db.WithContext(ctx).
        Preload("Refunds").
        Preload("Transactions").
        Where("id = ?", paymentID).
        First(&payment).Error
    
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, ErrPaymentNotFound
        }
        return nil, err
    }
    
    return &payment, nil
}

// Add database indexes for performance
func (r *PaymentRepository) CreateIndexes() error {
    indexes := []string{
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_order_id ON payments(order_id)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_customer_id ON payments(customer_id)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_status ON payments(status)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_created_at ON payments(created_at)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_gateway_txn_id ON payments(gateway_txn_id)",
    }
    
    for _, index := range indexes {
        if err := r.db.Exec(index).Error; err != nil {
            return err
        }
    }
    
    return nil
}
```

---

## 🧪 Phase 5: Testing & Validation

### Priority 5.1: Security Testing

#### Task 5.1.1: Security Test Suite (3 hours)

**Location**: `test/security/payment_security_test.go`

```go
func TestPaymentSecurity(t *testing.T) {
    t.Run("no_raw_card_data_stored", func(t *testing.T) {
        // Test that no raw card data is stored in database
    })
    
    t.Run("pci_dss_compliance", func(t *testing.T) {
        // Test PCI DSS compliance requirements
    })
    
    t.Run("webhook_signature_validation", func(t *testing.T) {
        // Test webhook signature validation
    })
    
    t.Run("3ds_authentication_flow", func(t *testing.T) {
        // Test 3DS authentication flow
    })
    
    t.Run("fraud_detection_accuracy", func(t *testing.T) {
        // Test fraud detection accuracy
    })
}
```

### Priority 5.2: Performance Testing

#### Task 5.2.1: Load Testing (2 hours)

**Location**: `test/performance/payment_load_test.go`

```go
func TestPaymentPerformance(t *testing.T) {
    t.Run("payment_processing_time", func(t *testing.T) {
        // Test payment processing time <3s (p95)
    })
    
    t.Run("concurrent_payments", func(t *testing.T) {
        // Test 1000 concurrent payments
    })
    
    t.Run("webhook_processing_time", func(t *testing.T) {
        // Test webhook processing <1s
    })
}
```

---

## 📊 Success Metrics

### Performance Targets
- [ ] Payment processing time: <3s (p95)
- [ ] Webhook processing time: <1s
- [ ] 3DS authentication time: <5s
- [ ] Fraud check time: <500ms

### Security Targets
- [ ] PCI DSS Level 1 compliance: 100%
- [ ] No raw card data stored: 100%
- [ ] 3DS authentication rate: >95%
- [ ] Fraud detection accuracy: >99%

### Business Targets
- [ ] Payment success rate: >95%
- [ ] False positive fraud rate: <1%
- [ ] Customer satisfaction: >4.5/5

---

## 🚀 Deployment Checklist

### Pre-deployment
- [ ] All security tests pass
- [ ] Performance tests pass
- [ ] PCI DSS audit complete
- [ ] Code review approved
- [ ] Documentation updated

### Deployment
- [ ] Blue-green deployment
- [ ] Database migrations
- [ ] Configuration updates
- [ ] Monitoring setup
- [ ] Alerting configured

### Post-deployment
- [ ] Health checks pass
- [ ] Performance monitoring
- [ ] Security monitoring
- [ ] Business metrics tracking
- [ ] Customer feedback monitoring

---

## 📞 Support & Resources

### Documentation
- [PCI DSS Requirements](https://www.pcisecuritystandards.org/)
- [3D Secure Specification](https://www.emvco.com/emv-technologies/3d-secure/)
- [Stripe 3DS Guide](https://stripe.com/docs/payments/3d-secure)

### Team Contacts
- **Security Team**: security@company.com
- **DevOps Team**: devops@company.com
- **Payment Team**: payments@company.com

### Emergency Contacts
- **On-call Engineer**: +1-xxx-xxx-xxxx
- **Security Incident**: security-incident@company.com

---

**Created**: 2025-12-14  
**Owner**: Payment Team  
**Reviewer**: Security Team  
**Next Review**: After implementation completion

🔐 **Remember: Payment security is non-negotiable. Every line of code must be security-first!**
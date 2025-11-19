# 🔒 Security & Fraud Prevention Checklist

**Service:** All Services  
**Created:** 2025-11-19  
**Priority:** 🔴 **High**

---

## 🎯 Overview

Security và fraud prevention là foundation của e-commerce platform. Một breach có thể phá hủy business.

**Key Areas:**
- Authentication & Authorization
- Payment Security (PCI DSS)
- Data Protection (GDPR)
- Fraud Detection
- API Security
- Infrastructure Security

---

## 1. Authentication & Authorization

### Requirements

- [ ] **R1.1** Multi-factor authentication (2FA)
- [ ] **R1.2** Password strength requirements (min 8 chars, special chars)
- [ ] **R1.3** Account lockout after failed attempts (5 tries)
- [ ] **R1.4** Session management (timeout after 30 min inactivity)
- [ ] **R1.5** JWT token expiry (15 min access, 7 day refresh)
- [ ] **R1.6** Role-based access control (RBAC)
- [ ] **R1.7** IP whitelisting for admin panel

### Implementation

```go
type AuthSecurity struct {
    MaxLoginAttempts    int
    LockoutDuration     time.Duration
    SessionTimeout      time.Duration
    PasswordMinLength   int
    RequireSpecialChars bool
    Require2FA          bool
}

func (uc *AuthUseCase) Login(ctx context.Context, req *LoginRequest) (*LoginResponse, error) {
    // 1. Check account lockout
    if uc.isAccountLocked(req.Email) {
        return nil, ErrAccountLocked
    }
    
    // 2. Verify credentials
    user, err := uc.verifyCredentials(req.Email, req.Password)
    if err != nil {
        uc.incrementFailedAttempts(req.Email)
        return nil, ErrInvalidCredentials
    }
    
    // 3. Check 2FA if enabled
    if user.TwoFactorEnabled {
        if !uc.verify2FA(user.ID, req.TwoFactorCode) {
            return nil, Err2FAInvalid
        }
    }
    
    // 4. Generate tokens
    accessToken := uc.generateAccessToken(user, 15*time.Minute)
    refreshToken := uc.generateRefreshToken(user, 7*24*time.Hour)
    
    // 5. Create session
    session := uc.createSession(user.ID, req.IPAddress, req.UserAgent)
    
    // 6. Reset failed attempts
    uc.resetFailedAttempts(req.Email)
    
    // 7. Log successful login
    uc.auditLogger.Log("user.login", user.ID, req.IPAddress)
    
    return &LoginResponse{
        AccessToken:  accessToken,
        RefreshToken: refreshToken,
        ExpiresIn:    900,  // 15 minutes
    }, nil
}

func (uc *AuthUseCase) validatePasswordStrength(password string) error {
    if len(password) < 8 {
        return ErrPasswordTooShort
    }
    
    hasUpper := regexp.MustCompile(`[A-Z]`).MatchString(password)
    hasLower := regexp.MustCompile(`[a-z]`).MatchString(password)
    hasNumber := regexp.MustCompile(`[0-9]`).MatchString(password)
    hasSpecial := regexp.MustCompile(`[!@#$%^&*]`).MatchString(password)
    
    if !hasUpper || !hasLower || !hasNumber || !hasSpecial {
        return ErrPasswordTooWeak
    }
    
    return nil
}
```

---

## 2. Payment Security (PCI DSS)

### Requirements

- [ ] **R2.1** Never store full card numbers
- [ ] **R2.2** Never store CVV
- [ ] **R2.3** Tokenize all card data
- [ ] **R2.4** Encrypt data in transit (TLS 1.3)
- [ ] **R2.5** Encrypt data at rest (AES-256)
- [ ] **R2.6** Secure key management (Vault)
- [ ] **R2.7** Regular PCI compliance audits

### Implementation

```go
// ❌ NEVER DO THIS
type Payment struct {
    CardNumber string  // VIOLATION!
    CVV        string  // VIOLATION!
}

// ✅ CORRECT
type Payment struct {
    CardToken  string  // Tokenized by gateway
    CardLast4  string  // Only last 4 digits
    CardBrand  string
}

// Encryption for sensitive data
type Encryptor struct {
    key []byte
}

func (e *Encryptor) EncryptPII(data string) (string, error) {
    block, err := aes.NewCipher(e.key)
    if err != nil {
        return "", err
    }
    
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return "", err
    }
    
    nonce := make([]byte, gcm.NonceSize())
    if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
        return "", err
    }
    
    ciphertext := gcm.Seal(nonce, nonce, []byte(data), nil)
    return base64.StdEncoding.EncodeToString(ciphertext), nil
}
```

---

## 3. Fraud Detection

### Requirements

- [ ] **R3.1** Real-time fraud scoring
- [ ] **R3.2** Velocity checks (multiple transactions)
- [ ] **R3.3** Geolocation validation
- [ ] **R3.4** Device fingerprinting
- [ ] **R3.5** Email domain validation
- [ ] **R3.6** Address verification (AVS)
- [ ] **R3.7** IP reputation check
- [ ] **R3.8** Behavioral analytics

### Implementation

```go
type FraudDetector struct {
    riskThresholds map[string]float64
}

func (fd *FraudDetector) CheckTransaction(ctx context.Context, txn *Transaction) (*FraudResult, error) {
    score := 0.0
    signals := []FraudSignal{}
    
    // 1. Velocity check
    recentTxns := fd.getRecentTransactions(txn.CustomerID, 1*time.Hour)
    if len(recentTxns) > 5 {
        score += 30
        signals = append(signals, FraudSignal{
            Type: "high_velocity",
            Score: 30,
            Message: fmt.Sprintf("%d transactions in 1 hour", len(recentTxns)),
        })
    }
    
    // 2. Billing/shipping mismatch
    if !addressesMatch(txn.BillingAddress, txn.ShippingAddress) {
        score += 15
        signals = append(signals, FraudSignal{
            Type: "address_mismatch",
            Score: 15,
        })
    }
    
    // 3. High-risk country
    if fd.isHighRiskCountry(txn.BillingAddress.Country) {
        score += 20
        signals = append(signals, FraudSignal{
            Type: "high_risk_country",
            Score: 20,
            Country: txn.BillingAddress.Country,
        })
    }
    
    // 4. VPN/Proxy detection
    if fd.isVPN(txn.IPAddress) {
        score += 10
        signals = append(signals, FraudSignal{
            Type: "vpn_detected",
            Score: 10,
        })
    }
    
    // 5. Disposable email
    if fd.isDisposableEmail(txn.Email) {
        score += 15
        signals = append(signals, FraudSignal{
            Type: "disposable_email",
            Score: 15,
        })
    }
    
    // 6. Device fingerprint
    if txn.CustomerID != "" && !fd.isKnownDevice(txn.CustomerID, txn.DeviceID) {
        score += 10
        signals = append(signals, FraudSignal{
            Type: "unknown_device",
            Score: 10,
        })
    }
    
    // 7. Unusual amount
    avgAmount := fd.getCustomerAverageOrder(txn.CustomerID)
    if txn.Amount > avgAmount * 3 {
        score += 10
        signals = append(signals, FraudSignal{
            Type: "unusual_amount",
            Score: 10,
        })
    }
    
    // Determine action
    var action string
    if score >= 70 {
        action = "block"
    } else if score >= 40 {
        action = "review"
    } else {
        action = "allow"
    }
    
    return &FraudResult{
        Score:   score,
        Signals: signals,
        Action:  action,
    }, nil
}
```

---

## 4. API Security

### Requirements

- [ ] **R4.1** Rate limiting (100 req/min per user)
- [ ] **R4.2** API key authentication
- [ ] **R4.3** Request signing (HMAC)
- [ ] **R4.4** IP whitelisting for sensitive APIs
- [ ] **R4.5** CORS configuration
- [ ] **R4.6** Input validation & sanitization
- [ ] **R4.7** SQL injection prevention
- [ ] **R4.8** XSS prevention

### Implementation

```go
// Rate limiting middleware
func RateLimitMiddleware(limit int, window time.Duration) gin.HandlerFunc {
    return func(c *gin.Context) {
        userID := c.GetString("user_id")
        key := fmt.Sprintf("rate_limit:%s", userID)
        
        count, _ := redis.Incr(ctx, key).Result()
        
        if count == 1 {
            redis.Expire(ctx, key, window)
        }
        
        if count > int64(limit) {
            c.JSON(429, gin.H{
                "error": "Rate limit exceeded",
                "retry_after": window.Seconds(),
            })
            c.Abort()
            return
        }
        
        c.Next()
    }
}

// Input sanitization
func sanitizeInput(input string) string {
    // Remove SQL injection patterns
    input = strings.ReplaceAll(input, "--", "")
    input = strings.ReplaceAll(input, ";", "")
    input = strings.ReplaceAll(input, "' OR '1'='1", "")
    
    // HTML escape for XSS prevention
    input = html.EscapeString(input)
    
    return input
}
```

---

## 5. Data Protection (GDPR)

### Requirements

- [ ] **R5.1** Data encryption at rest (AES-256)
- [ ] **R5.2** Data encryption in transit (TLS 1.3)
- [ ] **R5.3** Right to access (data export)
- [ ] **R5.4** Right to erasure (data deletion)
- [ ] **R5.5** Consent management
- [ ] **R5.6** Data retention policies
- [ ] **R5.7** Breach notification (<72h)
- [ ] **R5.8** Privacy by design

### Implementation

```go
func (uc *CustomerUseCase) ExportCustomerData(ctx context.Context, customerID string) (*DataExport, error) {
    // GDPR Right to Access
    
    data := &DataExport{
        CustomerID: customerID,
        ExportedAt: time.Now(),
    }
    
    // Personal data
    customer, _ := uc.repo.GetCustomer(ctx, customerID)
    data.PersonalInfo = customer
    
    // Orders
    orders, _ := uc.orderClient.GetCustomerOrders(ctx, customerID)
    data.Orders = orders
    
    // Payment history (sanitized, no card details)
    payments, _ := uc.paymentClient.GetPaymentHistory(ctx, customerID)
    data.Payments = sanitizePayments(payments)
    
    // Activity logs
    logs, _ := uc.activityLog.GetLogs(ctx, customerID)
    data.ActivityLogs = logs
    
    return data, nil
}

func (uc *CustomerUseCase) DeleteCustomerData(ctx context.Context, customerID string) error {
    // GDPR Right to Erasure
    
    // 1. Anonymize orders (keep for accounting)
    uc.orderClient.AnonymizeOrders(ctx, customerID)
    
    // 2. Delete personal information
    uc.repo.DeleteCustomer(ctx, customerID)
    
    // 3. Delete payment tokens
    uc.paymentClient.DeleteTokens(ctx, customerID)
    
    // 4. Delete activity logs
    uc.activityLog.DeleteLogs(ctx, customerID)
    
    // 5. Log deletion
    uc.auditLogger.Log("customer.data_deleted", customerID, "gdpr_request")
    
    return nil
}
```

---

## 6. Infrastructure Security

### Requirements

- [ ] **R6.1** Firewall configuration (WAF)
- [ ] **R6.2** DDoS protection
- [ ] **R6.3** Regular security patches
- [ ] **R6.4** Vulnerability scanning
- [ ] **R6.5** Penetration testing (quarterly)
- [ ] **R6.6** Secrets management (Vault)
- [ ] **R6.7** Backup encryption
- [ ] **R6.8** Audit logging

### Implementation

```go
// Secrets management
type SecretsManager struct {
    vaultClient *vault.Client
}

func (sm *SecretsManager) GetSecret(path string) (string, error) {
    secret, err := sm.vaultClient.Logical().Read(path)
    if err != nil {
        return "", err
    }
    
    value, ok := secret.Data["value"].(string)
    if !ok {
        return "", ErrSecretNotFound
    }
    
    return value, nil
}

// Audit logging
type AuditLog struct {
    Timestamp   time.Time
    UserID      string
    Action      string
    Resource    string
    IPAddress   string
    UserAgent   string
    Success     bool
    ErrorCode   string
}

func (al *AuditLogger) Log(action, userID, ipAddress string) {
    log := &AuditLog{
        Timestamp:  time.Now(),
        UserID:     userID,
        Action:     action,
        IPAddress:  ipAddress,
        Success:    true,
    }
    
    // Store in secure audit log database
    al.store(log)
}
```

---

## 📊 Security Checklist

### Authentication
- [ ] 2FA implemented
- [ ] Password strength enforced
- [ ] Account lockout configured
- [ ] Session timeout set
- [ ] JWT expiry configured

### Payment
- [ ] No card storage
- [ ] Tokenization implemented
- [ ] TLS 1.3 enforced
- [ ] PCI compliance verified

### Fraud
- [ ] Fraud scoring active
- [ ] Velocity checks enabled
- [ ] Device fingerprinting
- [ ] Manual review queue

### API
- [ ] Rate limiting active
- [ ] Input validation
- [ ] SQL injection prevention
- [ ] XSS prevention

### Data
- [ ] Encryption at rest
- [ ] Encryption in transit
- [ ] GDPR compliance
- [ ] Data export/deletion

### Infrastructure
- [ ] WAF configured
- [ ] DDoS protection
- [ ] Vulnerability scanning
- [ ] Backup encryption

---

**Status:** Continuous Monitoring Required

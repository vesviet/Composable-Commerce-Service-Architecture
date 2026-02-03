# 🔒 Security Architecture

**Purpose**: Comprehensive security design, threat model, and security controls for the microservices platform  
**Navigation**: [← Back to Architecture](README.md) | [System Overview →](system-overview.md)

---

## 📋 **Overview**

This document outlines the security architecture, threat model, and security controls implemented across our microservices platform. It covers authentication, authorization, data protection, network security, and compliance requirements.

## 🎯 **Security Principles**

### **Defense in Depth**
Multiple layers of security controls to protect against various threat vectors:

```
┌─────────────────────────────────────────────────────────────┐
│                    🌐 Edge Security                         │
│              WAF, DDoS Protection, CDN                     │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                 🚪 API Gateway Security                     │
│         Rate Limiting, Authentication, Authorization        │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                 🔐 Service-to-Service mTLS                  │
│              Mutual TLS, Certificate Management            │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                  🛡️ Application Security                    │
│           Input Validation, Business Logic Controls        │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    🗄️ Data Security                         │
│         Encryption at Rest, Access Controls, Audit         │
└─────────────────────────────────────────────────────────────┘
```

### **Zero Trust Architecture**
Never trust, always verify - every request is authenticated and authorized:

- **Identity Verification**: All users and services must be authenticated
- **Least Privilege**: Minimal access rights required for operation
- **Continuous Monitoring**: Real-time security monitoring and alerting
- **Micro-Segmentation**: Network isolation between services

### **Security by Design**
Security considerations integrated into every architectural decision:

- **Threat Modeling**: Systematic identification of security threats
- **Secure Defaults**: Secure configurations out of the box
- **Privacy by Design**: Data protection built into system design
- **Compliance First**: Regulatory requirements drive security controls

---

## 🔐 **Authentication & Authorization**

### **Multi-Factor Authentication (MFA)**
Enhanced security for admin and customer accounts:

```go
// MFA implementation with TOTP
type MFAService struct {
    totpGenerator *totp.Generator
    backupCodes   BackupCodeService
}

func (s *MFAService) EnableMFA(ctx context.Context, userID string) (*MFASetupResponse, error) {
    // Generate TOTP secret
    secret, err := s.totpGenerator.GenerateSecret(userID)
    if err != nil {
        return nil, err
    }
    
    // Generate backup codes
    backupCodes, err := s.backupCodes.GenerateCodes(userID, 10)
    if err != nil {
        return nil, err
    }
    
    return &MFASetupResponse{
        Secret:      secret,
        QRCode:      s.generateQRCode(secret),
        BackupCodes: backupCodes,
    }, nil
}
```

### **OAuth2 & OpenID Connect**
Standardized authentication with external providers:

```yaml
# OAuth2 Configuration
oauth2:
  providers:
    google:
      client_id: "${GOOGLE_CLIENT_ID}"
      client_secret: "${GOOGLE_CLIENT_SECRET}"
      scopes: ["openid", "profile", "email"]
    facebook:
      client_id: "${FACEBOOK_CLIENT_ID}"
      client_secret: "${FACEBOOK_CLIENT_SECRET}"
      scopes: ["email", "public_profile"]
    github:
      client_id: "${GITHUB_CLIENT_ID}"
      client_secret: "${GITHUB_CLIENT_SECRET}"
      scopes: ["user:email"]
```

### **JWT Token Management**
Secure token-based authentication with refresh tokens:

```go
// JWT token structure
type JWTClaims struct {
    UserID    string   `json:"user_id"`
    Email     string   `json:"email"`
    Roles     []string `json:"roles"`
    SessionID string   `json:"session_id"`
    MFAVerified bool   `json:"mfa_verified"`
    jwt.RegisteredClaims
}

// Token refresh mechanism
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*TokenResponse, error) {
    // Validate refresh token
    claims, err := s.validateRefreshToken(refreshToken)
    if err != nil {
        return nil, ErrInvalidRefreshToken
    }
    
    // Check if session is still valid
    if !s.sessionService.IsValid(ctx, claims.SessionID) {
        return nil, ErrSessionExpired
    }
    
    // Generate new access token
    accessToken, err := s.generateAccessToken(claims.UserID, claims.Roles)
    if err != nil {
        return nil, err
    }
    
    return &TokenResponse{
        AccessToken:  accessToken,
        RefreshToken: refreshToken, // Keep same refresh token
        ExpiresIn:    3600, // 1 hour
    }, nil
}
```

### **Role-Based Access Control (RBAC)**
Granular permissions based on user roles:

```go
// Permission system
type Permission struct {
    Resource string `json:"resource"` // e.g., "orders", "products"
    Action   string `json:"action"`   // e.g., "read", "write", "delete"
    Scope    string `json:"scope"`    // e.g., "own", "all", "warehouse:123"
}

type Role struct {
    ID          string       `json:"id"`
    Name        string       `json:"name"`
    Permissions []Permission `json:"permissions"`
}

// Authorization middleware
func RequirePermission(resource, action string) gin.HandlerFunc {
    return func(c *gin.Context) {
        userID := c.GetString("user_id")
        roles := c.GetStringSlice("roles")
        
        hasPermission := s.authzService.CheckPermission(userID, roles, resource, action)
        if !hasPermission {
            c.JSON(403, gin.H{"error": "Insufficient permissions"})
            c.Abort()
            return
        }
        
        c.Next()
    }
}
```

---

## 🛡️ **Network Security**

### **Service Mesh Security with Dapr**
Mutual TLS (mTLS) for all service-to-service communication:

```yaml
# Dapr mTLS configuration
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: security-config
spec:
  mtls:
    enabled: true
    workloadCertTTL: "24h"
    allowedClockSkew: "15m"
  accessControl:
    defaultAction: deny
    trustDomain: "public"
    policies:
    - appId: order-service
      defaultAction: allow
      trustDomain: "public"
      operations:
      - name: "/api.order.v1.OrderService/CreateOrder"
        httpVerb: ["POST"]
        action: allow
```

### **Network Policies**
Kubernetes network policies for micro-segmentation:

```yaml
# Network policy for order service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-service-netpol
spec:
  podSelector:
    matchLabels:
      app: order-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
    - podSelector:
        matchLabels:
          app: fulfillment-service
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: payment-service
    - podSelector:
        matchLabels:
          app: warehouse-service
    ports:
    - protocol: TCP
      port: 8080
```

### **API Gateway Security**
Centralized security controls at the gateway level:

```yaml
# Kong security plugins
plugins:
- name: rate-limiting
  config:
    minute: 100
    hour: 1000
    policy: local
- name: jwt
  config:
    secret_is_base64: false
    key_claim_name: kid
    claims_to_verify: ["exp", "iat"]
- name: cors
  config:
    origins: ["https://yourdomain.com"]
    methods: ["GET", "POST", "PUT", "DELETE"]
    headers: ["Accept", "Content-Type", "Authorization"]
    credentials: true
- name: ip-restriction
  config:
    deny: ["192.168.1.0/24"] # Block internal networks from external access
```

---

## 🔒 **Data Security**

### **Encryption at Rest**
All sensitive data encrypted using AES-256:

```go
// Database encryption configuration
type DatabaseConfig struct {
    Host     string `yaml:"host"`
    Port     int    `yaml:"port"`
    Database string `yaml:"database"`
    Username string `yaml:"username"`
    Password string `yaml:"password"`
    SSLMode  string `yaml:"ssl_mode"` // require, verify-full
    
    // Encryption settings
    EncryptionKey    string `yaml:"encryption_key"`
    EncryptionAlgo   string `yaml:"encryption_algo"` // AES-256-GCM
    KeyRotationDays  int    `yaml:"key_rotation_days"`
}

// Field-level encryption for PII
type Customer struct {
    ID          string    `json:"id" db:"id"`
    Email       string    `json:"email" db:"email"`
    FirstName   string    `json:"first_name" db:"first_name_encrypted"`
    LastName    string    `json:"last_name" db:"last_name_encrypted"`
    Phone       string    `json:"phone" db:"phone_encrypted"`
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

func (c *Customer) EncryptPII(encryptor *Encryptor) error {
    var err error
    c.FirstName, err = encryptor.Encrypt(c.FirstName)
    if err != nil {
        return err
    }
    
    c.LastName, err = encryptor.Encrypt(c.LastName)
    if err != nil {
        return err
    }
    
    c.Phone, err = encryptor.Encrypt(c.Phone)
    if err != nil {
        return err
    }
    
    return nil
}
```

### **Encryption in Transit**
TLS 1.3 for all external communications:

```yaml
# TLS configuration
tls:
  min_version: "1.3"
  cipher_suites:
    - "TLS_AES_256_GCM_SHA384"
    - "TLS_CHACHA20_POLY1305_SHA256"
    - "TLS_AES_128_GCM_SHA256"
  certificate_path: "/etc/ssl/certs/server.crt"
  private_key_path: "/etc/ssl/private/server.key"
  
  # HSTS configuration
  hsts:
    enabled: true
    max_age: 31536000 # 1 year
    include_subdomains: true
    preload: true
```

### **Data Classification & Handling**
Different security controls based on data sensitivity:

```go
// Data classification levels
type DataClassification int

const (
    Public DataClassification = iota
    Internal
    Confidential
    Restricted
)

// Data handling policies
type DataPolicy struct {
    Classification    DataClassification
    EncryptionRequired bool
    AccessLogging     bool
    RetentionDays     int
    GeographicRestrictions []string
}

var DataPolicies = map[string]DataPolicy{
    "customer.email":      {Confidential, true, true, 2555, []string{"EU", "US"}},
    "customer.phone":      {Confidential, true, true, 2555, []string{"EU", "US"}},
    "payment.card_number": {Restricted, true, true, 90, []string{"US"}},
    "order.total":         {Internal, false, true, 2555, nil},
    "product.name":        {Public, false, false, -1, nil},
}
```

---

## 🔍 **Security Monitoring & Incident Response**

### **Security Information and Event Management (SIEM)**
Centralized security monitoring and alerting:

```go
// Security event logging
type SecurityEvent struct {
    EventID     string                 `json:"event_id"`
    Timestamp   time.Time             `json:"timestamp"`
    EventType   string                `json:"event_type"`
    Severity    string                `json:"severity"`
    UserID      string                `json:"user_id,omitempty"`
    ServiceName string                `json:"service_name"`
    IPAddress   string                `json:"ip_address"`
    UserAgent   string                `json:"user_agent,omitempty"`
    Details     map[string]interface{} `json:"details"`
}

// Security event types
const (
    EventLoginSuccess        = "auth.login.success"
    EventLoginFailure        = "auth.login.failure"
    EventMFAEnabled         = "auth.mfa.enabled"
    EventPasswordChanged    = "auth.password.changed"
    EventUnauthorizedAccess = "auth.unauthorized.access"
    EventSuspiciousActivity = "security.suspicious.activity"
    EventDataAccess         = "data.access"
    EventDataModification   = "data.modification"
)

func (s *SecurityService) LogSecurityEvent(ctx context.Context, event *SecurityEvent) error {
    // Add correlation ID from context
    if traceID := trace.SpanFromContext(ctx).SpanContext().TraceID(); traceID.IsValid() {
        event.Details["trace_id"] = traceID.String()
    }
    
    // Send to SIEM system
    return s.siemClient.SendEvent(ctx, event)
}
```

### **Threat Detection Rules**
Automated detection of security threats:

```yaml
# Security monitoring rules
threat_detection:
  rules:
    - name: "Multiple Failed Logins"
      condition: "failed_login_count > 5 in 5m"
      severity: "high"
      action: "block_ip"
      
    - name: "Unusual API Access Pattern"
      condition: "api_calls > 1000 in 1m from single_ip"
      severity: "medium"
      action: "rate_limit"
      
    - name: "Admin Access from New Location"
      condition: "admin_login and new_geolocation"
      severity: "high"
      action: "require_mfa"
      
    - name: "Bulk Data Access"
      condition: "data_access_count > 10000 in 1h"
      severity: "medium"
      action: "alert_security_team"
```

### **Incident Response Playbook**
Automated and manual response procedures:

```go
// Incident response automation
type IncidentResponse struct {
    IncidentID   string    `json:"incident_id"`
    ThreatType   string    `json:"threat_type"`
    Severity     string    `json:"severity"`
    DetectedAt   time.Time `json:"detected_at"`
    Status       string    `json:"status"`
    Actions      []string  `json:"actions"`
}

func (s *SecurityService) HandleSecurityIncident(ctx context.Context, incident *IncidentResponse) error {
    switch incident.ThreatType {
    case "brute_force_attack":
        return s.handleBruteForceAttack(ctx, incident)
    case "data_breach_attempt":
        return s.handleDataBreachAttempt(ctx, incident)
    case "privilege_escalation":
        return s.handlePrivilegeEscalation(ctx, incident)
    default:
        return s.handleGenericIncident(ctx, incident)
    }
}

func (s *SecurityService) handleBruteForceAttack(ctx context.Context, incident *IncidentResponse) error {
    // 1. Block source IP
    err := s.firewallService.BlockIP(ctx, incident.SourceIP, 24*time.Hour)
    if err != nil {
        return err
    }
    
    // 2. Notify security team
    err = s.notificationService.AlertSecurityTeam(ctx, incident)
    if err != nil {
        return err
    }
    
    // 3. Force password reset for affected accounts
    return s.authService.ForcePasswordReset(ctx, incident.AffectedUsers)
}
```

---

## 📋 **Compliance & Governance**

### **GDPR Compliance**
Data protection and privacy controls:

```go
// GDPR compliance features
type GDPRService struct {
    dataProcessor DataProcessor
    auditLogger   AuditLogger
    consentMgr    ConsentManager
}

// Right to be forgotten
func (s *GDPRService) ProcessDataDeletionRequest(ctx context.Context, userID string) error {
    // 1. Verify user identity
    if !s.verifyUserIdentity(ctx, userID) {
        return ErrUnauthorized
    }
    
    // 2. Log the request
    s.auditLogger.LogDataDeletion(ctx, userID)
    
    // 3. Delete personal data across all services
    services := []string{"customer", "order", "payment", "review"}
    for _, service := range services {
        err := s.dataProcessor.DeleteUserData(ctx, service, userID)
        if err != nil {
            return fmt.Errorf("failed to delete data from %s: %w", service, err)
        }
    }
    
    // 4. Anonymize remaining data
    return s.dataProcessor.AnonymizeUserData(ctx, userID)
}

// Data portability
func (s *GDPRService) ExportUserData(ctx context.Context, userID string) (*UserDataExport, error) {
    export := &UserDataExport{
        UserID:    userID,
        ExportedAt: time.Now(),
        Data:      make(map[string]interface{}),
    }
    
    // Collect data from all services
    services := []string{"customer", "order", "payment", "review"}
    for _, service := range services {
        data, err := s.dataProcessor.GetUserData(ctx, service, userID)
        if err != nil {
            return nil, err
        }
        export.Data[service] = data
    }
    
    return export, nil
}
```

### **PCI DSS Compliance**
Payment card industry security standards:

```go
// PCI DSS compliance controls
type PCICompliance struct {
    cardDataEncryptor *CardDataEncryptor
    accessLogger      *AccessLogger
    networkScanner    *NetworkScanner
}

// Secure card data handling
func (p *PCICompliance) ProcessCardData(ctx context.Context, cardData *CardData) (*ProcessedCard, error) {
    // 1. Validate card data format
    if !p.validateCardFormat(cardData) {
        return nil, ErrInvalidCardFormat
    }
    
    // 2. Encrypt sensitive data
    encryptedPAN, err := p.cardDataEncryptor.EncryptPAN(cardData.PAN)
    if err != nil {
        return nil, err
    }
    
    // 3. Tokenize card number
    token, err := p.cardDataEncryptor.TokenizePAN(cardData.PAN)
    if err != nil {
        return nil, err
    }
    
    // 4. Log access
    p.accessLogger.LogCardDataAccess(ctx, token)
    
    return &ProcessedCard{
        Token:        token,
        EncryptedPAN: encryptedPAN,
        LastFour:     cardData.PAN[len(cardData.PAN)-4:],
        ExpiryMonth:  cardData.ExpiryMonth,
        ExpiryYear:   cardData.ExpiryYear,
    }, nil
}
```

### **SOC 2 Compliance**
Security, availability, and confidentiality controls:

```yaml
# SOC 2 control implementation
soc2_controls:
  security:
    - control_id: "CC6.1"
      description: "Logical and physical access controls"
      implementation: "RBAC, MFA, network segmentation"
      evidence: "Access logs, policy documents"
      
    - control_id: "CC6.2"
      description: "System access is removed when no longer required"
      implementation: "Automated user lifecycle management"
      evidence: "Deprovisioning logs, access reviews"
      
  availability:
    - control_id: "A1.1"
      description: "System availability monitoring"
      implementation: "Health checks, SLA monitoring"
      evidence: "Uptime reports, incident logs"
      
  confidentiality:
    - control_id: "C1.1"
      description: "Confidential information protection"
      implementation: "Data classification, encryption"
      evidence: "Encryption reports, access logs"
```

---

## 🔧 **Security Tools & Technologies**

### **Security Stack**
Comprehensive security toolchain:

```yaml
security_tools:
  authentication:
    - name: "Kratos"
      purpose: "Identity management"
      version: "v0.11"
      
  authorization:
    - name: "Keto"
      purpose: "Permission management"
      version: "v0.8"
      
  secrets_management:
    - name: "HashiCorp Vault"
      purpose: "Secret storage and rotation"
      version: "v1.12"
      
  vulnerability_scanning:
    - name: "Trivy"
      purpose: "Container vulnerability scanning"
      version: "v0.35"
      
  static_analysis:
    - name: "SonarQube"
      purpose: "Code security analysis"
      version: "v9.7"
      
  runtime_protection:
    - name: "Falco"
      purpose: "Runtime security monitoring"
      version: "v0.33"
```

### **Security Testing**
Automated security testing in CI/CD pipeline:

```yaml
# Security testing pipeline
security_tests:
  static_analysis:
    - tool: "gosec"
      command: "gosec ./..."
      fail_on: "medium"
      
    - tool: "semgrep"
      command: "semgrep --config=auto ."
      fail_on: "error"
      
  dependency_scanning:
    - tool: "nancy"
      command: "nancy sleuth"
      fail_on: "high"
      
  container_scanning:
    - tool: "trivy"
      command: "trivy image --severity HIGH,CRITICAL"
      fail_on: "critical"
      
  dynamic_testing:
    - tool: "zap"
      command: "zap-baseline.py -t http://localhost:8080"
      fail_on: "medium"
```

---

## 📊 **Security Metrics & KPIs**

### **Security Dashboard**
Key security metrics to monitor:

```go
// Security metrics
type SecurityMetrics struct {
    AuthenticationMetrics struct {
        LoginAttempts       int64 `json:"login_attempts"`
        SuccessfulLogins    int64 `json:"successful_logins"`
        FailedLogins        int64 `json:"failed_logins"`
        MFAAdoptionRate     float64 `json:"mfa_adoption_rate"`
    } `json:"authentication"`
    
    AuthorizationMetrics struct {
        AuthorizedRequests   int64 `json:"authorized_requests"`
        UnauthorizedRequests int64 `json:"unauthorized_requests"`
        PermissionDenials    int64 `json:"permission_denials"`
    } `json:"authorization"`
    
    SecurityIncidents struct {
        TotalIncidents      int64 `json:"total_incidents"`
        CriticalIncidents   int64 `json:"critical_incidents"`
        ResolvedIncidents   int64 `json:"resolved_incidents"`
        MeanTimeToResolve   int64 `json:"mean_time_to_resolve_minutes"`
    } `json:"incidents"`
    
    ComplianceMetrics struct {
        GDPRRequests        int64 `json:"gdpr_requests"`
        DataBreaches        int64 `json:"data_breaches"`
        ComplianceScore     float64 `json:"compliance_score"`
    } `json:"compliance"`
}
```

### **Security SLAs**
Service level agreements for security operations:

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Incident Response Time** | < 15 minutes | Time from detection to initial response |
| **Critical Vulnerability Patching** | < 24 hours | Time from disclosure to patch deployment |
| **User Access Provisioning** | < 2 hours | Time from request to access granted |
| **Security Audit Completion** | < 30 days | Time to complete quarterly security audit |
| **Compliance Report Generation** | < 7 days | Time to generate compliance reports |

---

## 🛣️ **Security Roadmap**

### **Q1 2026 Priorities**
- ✅ Complete mTLS implementation across all services
- ✅ Deploy advanced threat detection system
- ✅ Implement zero-trust network architecture
- ✅ Complete SOC 2 Type II audit

### **Q2 2026 Goals**
- 🔄 Deploy security orchestration and automated response (SOAR)
- 🔄 Implement advanced persistent threat (APT) detection
- 🔄 Complete penetration testing program
- 🔄 Deploy security awareness training platform

### **Q3 2026 Vision**
- 🎯 Achieve ISO 27001 certification
- 🎯 Implement AI-powered security analytics
- 🎯 Deploy quantum-resistant cryptography
- 🎯 Complete security maturity assessment

---

## 🔗 **Related Documentation**

- **[System Overview](system-overview.md)** - Overall system architecture
- **[API Architecture](api-architecture.md)** - API security standards
- **[Operations Security](../06-operations/security/)** - Operational security procedures
- **[Development Security](../07-development/security/)** - Secure development practices

---

**Last Updated**: January 29, 2026  
**Security Review**: Monthly security architecture review  
**Maintained By**: Security Team & Architecture Team  
**Classification**: Internal Use Only
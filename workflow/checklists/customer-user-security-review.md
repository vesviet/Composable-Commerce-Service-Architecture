# 🔒 Customer & User Services Security Review Report

**Review Date**: January 18, 2026  
**Reviewer**: Senior Team Lead  
**Review Standard**: [TEAM_LEAD_CODE_REVIEW_GUIDE.md](../../TEAM_LEAD_CODE_REVIEW_GUIDE.md)  
**Services**: Customer Service, User Service  
**Focus**: Authentication, RBAC, GDPR Compliance, Data Security

---

## 📊 Executive Summary

| Metric | Customer Service | User Service | Target |
|--------|-----------------|--------------|--------|
| **Overall Maturity** | 8.5/10 | 8.0/10 | 9.0/10 |
| **Security Score** | 8.0/10 | 8.5/10 | 9.5/10 |
| **GDPR Compliance** | 9.0/10 | 7.0/10 | 9.5/10 |
| **Test Coverage** | 60% | 65% | 80% |
| **P0 Issues** | 2 | 3 | 0 |
| **P1 Issues** | 4 | 3 | 0 |
| **P2 Issues** | 3 | 2 | <5 |

**Verdict**: Both services demonstrate strong security fundamentals but require P0 fixes before production deployment.

---

## 🎯 Customer Service Analysis

### ✅ Strengths

#### 1. **Excellent Authentication Implementation** (9/10)
**File**: [customer/internal/biz/customer/auth.go](../../../customer/internal/biz/customer/auth.go)

- ✅ **Password Hashing**: Uses common security package with bcrypt
  ```go
  hashedPassword, err := uc.pwd.HashPassword(req.Password)
  ```
- ✅ **Rate Limiting**: IP-based rate limiting (10 req/min)
  ```go
  count, err := uc.cache.IncrementLoginAttempts(ctx, req.IPAddress)
  if count > 10 { /* block */ }
  ```
- ✅ **Account Lockout**: 5 failed attempts trigger lockout (15 min window)
  ```go
  failures, err := uc.cache.GetLoginFailures(ctx, req.Email)
  if failures >= 5 { /* lock account */ }
  ```
- ✅ **Token Delegation**: Correctly delegates to Auth Service per [auth-flow.md](../auth-flow.md)
  ```go
  tokenResp, err := uc.authClient.GenerateToken(ctx, customer.ID.String(), "customer", claims, ...)
  ```

#### 2. **Outstanding GDPR Compliance** (9/10)
**File**: [customer/internal/biz/customer/gdpr.go](../../../customer/internal/biz/customer/gdpr.go)

- ✅ **30-Day Grace Period**: Scheduled deletion with cancellation option
- ✅ **Comprehensive Anonymization**: 
  - Email → `deleted_{uuid}@deleted.local`
  - Name → "Deleted User"
  - Password cleared
  - Profile data wiped
  - Addresses hard-deleted
  - Order data anonymized via order service
- ✅ **Data Retention Compliance**: Keeps order records for accounting
- ✅ **User Notifications**: Email confirmations for deletion requests

#### 3. **Two-Factor Authentication** (8/10)
**File**: [customer/internal/biz/customer/two_factor.go](../../../customer/internal/biz/customer/two_factor.go)

- ✅ TOTP implementation with QR code generation
- ✅ Secret storage in encrypted field
- ⚠️ **Missing**: Token validation logic (verify TOTP code)

---

### 🔴 P0 Issues (Blocking)

#### P0-1: Missing PII Masking in Logs
**Severity**: P0 (Critical Security)  
**Files**: [customer/internal/biz/customer/auth.go](../../../customer/internal/biz/customer/auth.go) (lines 107, 212, 229)

**Issue**: Customer email and sensitive data logged in plaintext
```go
// ❌ CURRENT: Exposes PII in logs
uc.log.WithContext(ctx).Infof("Registering customer: %s", req.Email)
uc.log.WithContext(ctx).Infof("Login attempt for customer: %s", req.Email)
```

**Risk**: GDPR violation, PII exposure in log aggregation systems (Elasticsearch, Jaeger)

**Fix**:
```go
// ✅ CORRECT: Mask email in logs
maskedEmail := maskEmail(req.Email) // us***@example.com
uc.log.WithContext(ctx).Infof("Registering customer: %s", maskedEmail)

// Or use customer_id only after creation
uc.log.WithContext(ctx).Infof("Login attempt for customer_id: %s", customer.ID)
```

**Implementation**:
1. Import common PII masker (from order service security package)
2. Create `maskEmail(email string) string` helper
3. Update all log statements in:
   - auth.go (3 locations)
   - customer.go (profile updates)
   - gdpr.go (deletion logs)
4. Add unit tests for masking logic

**Estimate**: 4 hours

---

#### P0-2: No Transaction for Customer Registration
**Severity**: P0 (Data Integrity)  
**File**: [customer/internal/biz/customer/auth.go](../../../customer/internal/biz/customer/auth.go:149)

**Issue**: Registration creates customer, sends verification, and welcome emails without transaction
```go
// ❌ CURRENT: No transaction, partial failure possible
if err := uc.repo.Create(ctx, customer); err != nil { /* ... */ }
if err := uc.verificationUC.SendEmailVerification(ctx, customer.ID); err != nil {
    // Email fails, but customer already created
}
```

**Risk**: Customer created but verification email fails → orphaned accounts

**Fix**:
```go
// ✅ CORRECT: Use transaction
err := uc.transaction(ctx, func(ctx context.Context) error {
    // Create customer
    if err := uc.repo.Create(ctx, customer); err != nil {
        return err
    }
    
    // Send verification (idempotent retry if fails)
    if err := uc.verificationUC.SendEmailVerification(ctx, customer.ID); err != nil {
        return err // rollback customer creation
    }
    
    return nil
})
```

**Implementation**:
1. Add TransactionFunc to CustomerRepo interface (follow user service pattern)
2. Inject transaction provider in NewAuthUsecase
3. Wrap Register() in transaction
4. Add rollback tests

**Estimate**: 6 hours

---

### 🟡 P1 Issues (High Priority)

#### P1-1: Weak Password Validation
**Severity**: P1 (Security)  
**File**: [customer/internal/biz/customer/auth.go](../../../customer/internal/biz/customer/auth.go:124)

**Issue**: Only checks length ≥ 8, no complexity requirements
```go
// ❌ CURRENT: Accepts weak passwords like "12345678"
if len(req.Password) < 8 {
    return nil, fmt.Errorf("password must be at least 8 characters")
}
```

**Fix**: Use common validation package (like user service)
```go
// ✅ CORRECT: Use common validator
if err := commonValidation.NewValidator().
    Password("password", req.Password, 8, true, true, true, true).
    Validate(); err != nil {
    return nil, err
}
```

**Requirements**:
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character (!@#$%^&*)

**Estimate**: 2 hours

---

#### P1-2: Account Lockout Has No Admin Override
**Severity**: P1 (Operations)  
**File**: [customer/internal/biz/customer/cache.go](../../../customer/internal/biz/customer/cache.go:167-197)

**Issue**: Locked accounts require 15 min wait, no admin unlock mechanism

**Fix**:
1. Add `UnlockAccount(ctx, email string)` method to AuthUsecase
2. Add admin endpoint to unlock accounts
3. Add audit logging for unlock operations

**Estimate**: 4 hours

---

#### P1-3: No SQL Injection Tests
**Severity**: P1 (Security)  
**Location**: Missing in test suite

**Issue**: No tests verify parameterized queries prevent SQL injection

**Fix**: Add security integration tests
```go
func TestLogin_SQLInjection(t *testing.T) {
    // Test email with SQL injection payload
    email := "admin'--"
    // Should fail auth, not crash or bypass security
}
```

**Estimate**: 3 hours

---

#### P1-4: Missing Integration Tests for Auth Flows
**Severity**: P1 (Quality)  
**Location**: No test directory found for customer service

**Issue**: No integration tests for:
- Registration → Verification → Login flow
- Password reset flow
- Account lockout → Unlock flow
- 2FA enable → Login with 2FA

**Fix**: Create integration test suite with testcontainers

**Estimate**: 8 hours

---

### 🟢 P2 Issues (Normal Priority)

#### P2-1: Cache TTL Not Configurable
**File**: [customer/internal/biz/customer/cache.go](../../../customer/internal/biz/customer/cache.go:29)

**Fix**: Load from config instead of hardcoded 5 minutes

**Estimate**: 1 hour

---

#### P2-2: Missing Prometheus Metrics
**File**: [customer/internal/biz/customer/auth.go](../../../customer/internal/biz/customer/auth.go)

**Fix**: Add metrics for:
- Registration success/failure rate
- Login success/failure rate
- Account lockout rate
- 2FA adoption rate

**Estimate**: 2 hours

---

#### P2-3: TOTP Verification Not Implemented
**File**: [customer/internal/biz/customer/two_factor.go](../../../customer/internal/biz/customer/two_factor.go)

**Fix**: Implement `Verify2FACode(ctx, customerID, code string) (bool, error)`

**Estimate**: 3 hours

---

## 🎯 User Service Analysis

### ✅ Strengths

#### 1. **Robust RBAC Implementation** (9/10)
**File**: [user/internal/biz/user/user.go](../../../user/internal/biz/user/user.go)

- ✅ **Role Assignment with Audit Trail**: `AssignRole(ctx, userID, roleID, assignedBy)`
- ✅ **Permission Versioning**: Increments version on role change to invalidate tokens
  ```go
  user.PermissionsVersion = time.Now().UnixNano()
  ```
- ✅ **Fine-grained Access Control**: `ValidateAccess(ctx, userID, serviceID, operation, path)`
- ✅ **Transactional Role Changes**: Wrapped in transactions
- ✅ **Cache Invalidation**: Clears cache on permission changes

#### 2. **Strong Password Security** (9/10)
**File**: [user/internal/biz/user/password.go](../../../user/internal/biz/user/password.go)

- ✅ Uses common validation package
- ✅ Comprehensive password requirements (8+ chars, uppercase, lowercase, number, special)
- ✅ Proper bcrypt hashing

#### 3. **Audit Logging** (7/10)
**File**: [user/internal/biz/user/user.go](../../../user/internal/biz/user/user.go:927)

- ✅ `RecordLogin()` tracks login events
- ⚠️ **Missing**: Audit trail for RBAC changes (role assignments, removals)

---

### 🔴 P0 Issues (Blocking)

#### P0-3: No Rate Limiting on Admin Login
**Severity**: P0 (Critical Security)  
**File**: User service has no login endpoint (delegates to Auth Service)

**Issue**: Cache helper has rate limiting functions but **NO LOGIN ENDPOINT USES THEM**
```go
// ✅ Functions exist in cache.go
func (c *userCache) IncrementLoginAttempts(ctx, ip string) (int64, error)
func (c *userCache) IncrementLoginFailures(ctx, email string) (int64, error)

// ❌ But NO login handler calls them
```

**Risk**: Brute force attacks on admin accounts

**Investigation Required**:
1. Does User Service have login endpoints? (not found in biz layer)
2. Is login delegated to Auth Service? (likely)
3. If so, does Auth Service apply rate limiting for admin users?

**Fix**: 
- **If User Service has login**: Implement rate limiting in login handler
- **If delegated to Auth Service**: Verify Auth Service applies stricter rate limits for admin users (e.g., 5 req/min vs 10 req/min for customers)

**Estimate**: 4 hours (investigation + fix)

---

#### P0-4: Privilege Escalation Risk - Self-Assignment
**Severity**: P0 (Critical Security)  
**File**: [user/internal/biz/user/user.go](../../../user/internal/biz/user/user.go:598)

**Issue**: `AssignRole()` accepts `assignedBy` parameter but **DOES NOT VALIDATE** if caller has permission to assign roles
```go
// ❌ CURRENT: No permission check
func (uc *UserUsecase) AssignRole(ctx, userID, roleID, assignedBy string) error {
    // Directly assigns role without checking if assignedBy has permission
    return uc.permissionRepo.AssignRole(ctx, userID, roleID, assignedBy)
}
```

**Attack Scenario**:
1. Attacker with low-privilege account calls `AssignRole(attackerID, "super-admin", attackerID)`
2. No validation prevents self-assignment of admin role
3. Privilege escalation complete

**Fix**:
```go
// ✅ CORRECT: Validate caller permissions
func (uc *UserUsecase) AssignRole(ctx, userID, roleID, assignedBy string) error {
    // 1. Verify assignedBy has "user.manage" or "role.assign" permission
    hasPermission, err := uc.ValidateAccess(ctx, assignedBy, "user-service", "role.assign", "")
    if err != nil || !hasPermission {
        return fmt.Errorf("unauthorized: caller lacks permission to assign roles")
    }
    
    // 2. Prevent self-assignment of higher privilege roles
    if userID == assignedBy {
        targetRole, err := uc.roleRepo.FindByID(ctx, roleID)
        if err != nil {
            return err
        }
        if targetRole.Scope == RoleScopeGlobal {
            return fmt.Errorf("self-assignment of global roles not allowed")
        }
    }
    
    // 3. Proceed with assignment
    return uc.transaction(ctx, func(ctx) error {
        if err := uc.permissionRepo.AssignRole(ctx, userID, roleID, assignedBy); err != nil {
            return err
        }
        return uc.incrementPermissionsVersion(ctx, userID)
    })
}
```

**Impact**: **CRITICAL** - This is a P0 security vulnerability that could allow privilege escalation

**Estimate**: 8 hours (fix + comprehensive RBAC tests)

---

#### P0-5: No Audit Logging for RBAC Changes
**Severity**: P0 (Compliance)  
**File**: [user/internal/biz/user/user.go](../../../user/internal/biz/user/user.go:598-645)

**Issue**: Role assignments and removals not logged for audit trail
```go
// ❌ CURRENT: No audit log
func (uc *UserUsecase) AssignRole(ctx, userID, roleID, assignedBy string) error {
    // Assigns role silently, no audit trail
}
```

**Risk**: Compliance failure, no forensic trail for privilege changes

**Fix**:
```go
// ✅ CORRECT: Add audit logging
func (uc *UserUsecase) AssignRole(ctx, userID, roleID, assignedBy string) error {
    // ... permission checks ...
    
    err := uc.transaction(ctx, func(ctx) error {
        if err := uc.permissionRepo.AssignRole(ctx, userID, roleID, assignedBy); err != nil {
            return err
        }
        
        // Audit log
        uc.log.WithContext(ctx).Infof(
            "AUDIT: Role assigned | user_id=%s | role_id=%s | assigned_by=%s | trace_id=%s",
            userID, roleID, assignedBy, getTraceID(ctx),
        )
        
        return uc.incrementPermissionsVersion(ctx, userID)
    })
    
    return err
}
```

**Estimate**: 4 hours

---

### 🟡 P1 Issues (High Priority)

#### P1-5: No GDPR Compliance for Admin Users
**Severity**: P1 (Compliance)  
**Location**: Missing GDPR functionality

**Issue**: Customer service has full GDPR implementation, User service has **ZERO GDPR support**

**Fix**: Implement GDPR module for User service:
1. `RequestAccountDeletion(ctx, userID string)` - 30 day grace period
2. `ProcessAccountDeletion(ctx, userID string)` - Anonymize data
3. `ExportUserData(ctx, userID string)` - Data portability

**Estimate**: 12 hours

---

#### P1-6: N+1 Query Risk in Permission Loading
**Severity**: P1 (Performance)  
**File**: [user/internal/data/postgres/permission.go](../../../user/internal/data/postgres/permission.go:136-148)

**Issue**: Code has comment "avoid N+1 query" and uses JOIN, but needs verification

**Fix**: Add performance tests to verify single query execution

**Estimate**: 3 hours

---

#### P1-7: Missing PII Masking in Logs
**Severity**: P1 (Compliance)  
**File**: [user/internal/biz/user/user.go](../../../user/internal/biz/user/user.go)

**Issue**: User email, username logged in plaintext (same as customer service)

**Fix**: Same as P0-1 for customer service

**Estimate**: 4 hours

---

### 🟢 P2 Issues (Normal Priority)

#### P2-4: Test Coverage Below Target
**Current**: 65%, **Target**: 80%

**Fix**: Add tests for:
- RBAC permission validation
- Role assignment edge cases
- Permission version increment

**Estimate**: 6 hours

---

#### P2-5: No Metrics for RBAC Operations
**Fix**: Add Prometheus metrics for:
- Role assignments/removals
- Permission validation calls
- Access denied rate

**Estimate**: 2 hours

---

## 📊 Test Coverage Analysis

### Customer Service
```
✅ Unit Tests: Present (auth.go, customer.go)
❌ Integration Tests: Missing
❌ Security Tests: Missing (SQL injection, XSS)
❌ GDPR Tests: Missing (anonymization verification)
```

**Recommendation**: Priority on integration tests for auth flows

---

### User Service
```
✅ Unit Tests: Present (user_test.go, password_test.go)
✅ Integration Tests: Present (integration_test.go, user_repository_test.go)
❌ RBAC Tests: Insufficient
❌ Privilege Escalation Tests: Missing
```

**Recommendation**: Focus on RBAC security tests (privilege escalation, self-assignment)

---

## 🔐 Security Gap Summary

| Gap | Customer | User | Severity | Est. Fix Time |
|-----|----------|------|----------|---------------|
| **PII Masking in Logs** | ❌ | ❌ | P0 | 8h total |
| **Transaction Safety** | ❌ | ✅ | P0 | 6h |
| **Rate Limiting** | ✅ | ❌ | P0 | 4h |
| **RBAC Validation** | N/A | ❌ | P0 | 8h |
| **Audit Logging** | Partial | ❌ | P0 | 4h |
| **Password Strength** | ❌ | ✅ | P1 | 2h |
| **GDPR Compliance** | ✅ | ❌ | P1 | 12h |
| **SQL Injection Tests** | ❌ | ❌ | P1 | 6h total |
| **Integration Tests** | ❌ | Partial | P1 | 16h total |
| **Metrics** | Partial | Partial | P2 | 4h total |

**Total P0 Work**: 30 hours  
**Total P1 Work**: 36 hours  
**Total P2 Work**: 10 hours  
**Grand Total**: **76 hours (≈2 weeks with 1 developer)**

---

## 🎯 Recommended Action Plan

### Week 1: P0 Security Fixes (30h)

**Day 1-2: Customer Service P0**
- [ ] P0-1: Implement PII masking in all logs (4h)
- [ ] P0-2: Add transaction wrapper for registration (6h)
- [ ] Test and verify fixes (4h)

**Day 3-4: User Service P0**
- [ ] P0-3: Investigate and fix rate limiting (4h)
- [ ] P0-4: Fix privilege escalation vulnerability (8h)
- [ ] P0-5: Add audit logging for RBAC (4h)

**Day 5: Integration Testing**
- [ ] Test all P0 fixes end-to-end (6h)
- [ ] Update documentation (2h)

---

### Week 2: P1 Critical Fixes (36h)

**Day 1-2: Password & Validation**
- [ ] P1-1: Customer password validation (2h)
- [ ] P1-2: Account unlock mechanism (4h)
- [ ] P1-3: SQL injection tests (3h)
- [ ] P1-7: User PII masking (4h)

**Day 3-4: GDPR & Testing**
- [ ] P1-5: User GDPR implementation (12h)
- [ ] P1-4: Customer integration tests (8h)

**Day 5: Performance & Cleanup**
- [ ] P1-6: N+1 query verification (3h)

---

### Week 3: P2 Enhancements (10h)
- [ ] P2-1 through P2-5: Metrics, config, tests
- [ ] Final security audit
- [ ] Production readiness review

---

## 📝 Compliance Checklist

### GDPR Compliance
- [x] **Customer Service**: 9/10 - Excellent
  - [x] Right to erasure (30-day grace period)
  - [x] Data anonymization
  - [x] User notifications
  - [ ] Data export (missing, but not critical)
- [ ] **User Service**: 3/10 - Needs Work
  - [ ] No GDPR functionality implemented
  - [ ] No data deletion mechanism
  - [ ] No data export

### PCI DSS (Related)
- [x] Password hashing with bcrypt
- [ ] PII masking in logs (both services)
- [x] Rate limiting (customer only)
- [ ] Audit logging (incomplete)

### SOC 2
- [x] Access control (RBAC)
- [ ] Comprehensive audit trail (incomplete)
- [x] Encryption at rest (DB level)
- [x] Secure password storage

---

## 🏆 Maturity Score Breakdown

### Customer Service: 8.5/10

| Category | Score | Justification |
|----------|-------|---------------|
| Authentication | 9/10 | Excellent rate limiting, lockout, token delegation |
| Password Security | 7/10 | Weak validation (P1-1) |
| GDPR Compliance | 9/10 | Outstanding anonymization, grace period |
| PII Protection | 6/10 | No log masking (P0-1) |
| Transaction Safety | 7/10 | Missing in registration (P0-2) |
| Test Coverage | 6/10 | Unit tests present, integration missing |
| Documentation | 8/10 | Clear code comments, flow documented |

**Blockers**: P0-1, P0-2

---

### User Service: 8.0/10

| Category | Score | Justification |
|----------|-------|---------------|
| RBAC Implementation | 8/10 | Good structure, validation issues (P0-4) |
| Password Security | 9/10 | Strong validation, proper hashing |
| Audit Logging | 5/10 | Partial implementation (P0-5) |
| GDPR Compliance | 3/10 | Not implemented (P1-5) |
| Rate Limiting | 4/10 | Functions exist, not used (P0-3) |
| Test Coverage | 7/10 | Good unit tests, RBAC tests missing |
| Permission Versioning | 10/10 | Excellent token invalidation strategy |

**Blockers**: P0-3, P0-4, P0-5

---

## 🚨 Risk Assessment

### Critical Risks (P0)
1. **Privilege Escalation** (User Service) - Score: 10/10 severity
   - Allows attackers to gain admin access
   - No validation on role assignments
   - **MUST FIX BEFORE PRODUCTION**

2. **PII Exposure** (Both Services) - Score: 8/10 severity
   - GDPR violation risk
   - Log aggregation systems (Elasticsearch) will contain PII
   - **MUST FIX BEFORE PRODUCTION**

3. **No Audit Trail** (User Service) - Score: 7/10 severity
   - Compliance failure (SOC 2, PCI DSS)
   - Cannot investigate security incidents
   - **MUST FIX BEFORE PRODUCTION**

### High Risks (P1)
4. **Weak Password Policy** (Customer) - Score: 6/10 severity
   - Accepts "12345678" as valid password
   - Easy brute force target
   - Fix in Week 2

5. **Missing GDPR** (User Service) - Score: 6/10 severity
   - Legal compliance risk for EU customers
   - Fix in Week 2

---

## 📚 Reference Implementation

**Best Practices Observed**:
1. **Order Service Security Package**: [order/internal/security/](../../../order/internal/security/)
   - PII masking utilities
   - Input sanitization
   - Audit logging framework
   - **Recommendation**: Extract to common package for reuse

2. **Auth Service Token Flow**: [auth-flow.md](../auth-flow.md)
   - Clear delegation pattern
   - Token rotation on refresh
   - Fail-closed on revoke failure
   - **Customer Service follows this perfectly**

3. **User Service Permission Versioning**: Excellent pattern
   - Invalidates tokens on permission changes
   - Prevents stale access after role removal
   - **Should be documented as best practice**

---

## 🎓 Security Training Recommendations

### Team Knowledge Gaps
1. **OWASP Top 10** awareness (SQL injection, XSS testing)
2. **GDPR compliance** for developers
3. **RBAC best practices** (principle of least privilege)
4. **Secure logging** (PII masking, structured logs)

### Recommended Training
- [ ] OWASP Top 10 for Go developers (4h)
- [ ] GDPR for Engineers workshop (2h)
- [ ] Production Security Checklist review (1h)

---

## 📞 Sign-Off

**Security Review Status**: ⚠️ **CONDITIONAL APPROVAL**

**Approval Conditions**:
1. ✅ All P0 issues fixed and tested (Est. 30h)
2. ✅ Security audit re-run after P0 fixes
3. ✅ Team lead sign-off on RBAC tests

**Recommended Timeline**: 2-3 weeks to production-ready

**Next Review**: After P0 fixes completed

---

**Reviewed by**: Senior Team Lead  
**Date**: January 18, 2026  
**Document Version**: 1.0

---

## 📎 Appendix: Code Examples

### A1: PII Masking Implementation
```go
// common/security/pii_masker.go (extract from order service)
package security

import "strings"

func MaskEmail(email string) string {
    parts := strings.Split(email, "@")
    if len(parts) != 2 {
        return "***"
    }
    
    username := parts[0]
    if len(username) <= 2 {
        return "**@" + parts[1]
    }
    
    masked := username[:2] + "***"
    return masked + "@" + parts[1]
}

// Example: john.doe@example.com → jo***@example.com
```

### A2: RBAC Validation Pattern
```go
// Secure role assignment with permission checks
func (uc *UserUsecase) AssignRole(ctx, userID, roleID, assignedBy string) error {
    // 1. Validate caller has permission
    hasPermission, err := uc.ValidateAccess(ctx, assignedBy, "user-service", "role.assign", "")
    if err != nil || !hasPermission {
        uc.log.WithContext(ctx).Warnf(
            "SECURITY: Unauthorized role assignment attempt | caller=%s | target=%s | role=%s",
            assignedBy, userID, roleID,
        )
        return ErrUnauthorized
    }
    
    // 2. Prevent privilege escalation
    if userID == assignedBy {
        targetRole, _ := uc.roleRepo.FindByID(ctx, roleID)
        if targetRole.Scope == RoleScopeGlobal {
            return ErrSelfAssignmentNotAllowed
        }
    }
    
    // 3. Execute in transaction with audit
    return uc.transaction(ctx, func(ctx) error {
        if err := uc.permissionRepo.AssignRole(ctx, userID, roleID, assignedBy); err != nil {
            return err
        }
        
        // Audit log
        uc.log.WithContext(ctx).Infof(
            "AUDIT: Role assigned | user=%s | role=%s | by=%s | trace=%s",
            userID, roleID, assignedBy, getTraceID(ctx),
        )
        
        return uc.incrementPermissionsVersion(ctx, userID)
    })
}
```

---

**End of Report**

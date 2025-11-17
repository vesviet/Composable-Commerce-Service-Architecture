# Simple Logic Gaps Review

## 📋 Tổng Quan

Review các logic gaps đơn giản trong project, tập trung vào các issues dễ fix và có thể gây bugs.

**Last Updated**: 2025-01-17  
**Status**: ⚠️ Review in progress

---

## 🔍 1. Auth Service - Session Limit Logic Gap

### Issue: Session limit check không handle error case

**File**: `auth/internal/biz/session/session.go`

**Current Code**:
```go
// Check session limit
sessions, err := uc.repo.GetUserSessions(ctx, req.UserID)
if err == nil && len(sessions) >= uc.maxSessionsPerUser {
    // Revoke oldest session
    oldestSession := sessions[0]
    for _, s := range sessions {
        if s.CreatedAt.Before(oldestSession.CreatedAt) {
            oldestSession = s
        }
    }
    if err := uc.repo.DeleteSession(ctx, oldestSession.ID); err != nil {
        uc.log.WithContext(ctx).Warnf("Failed to revoke oldest session: %v", err)
    }
}
```

**Problem**:
1. Nếu `GetUserSessions` returns error, code sẽ skip limit check và tạo session mới → có thể vượt quá limit
2. Nếu `DeleteSession` fails, chỉ log warning nhưng vẫn tạo session mới → có thể vượt quá limit

**Impact**: User có thể tạo nhiều sessions hơn limit cho phép

**Fix**:
- Option 1: Retry get sessions nếu fails
- Option 2: Fail session creation nếu cannot check/revoke sessions
- Option 3: At least log error và continue (current behavior, but risky)

**Priority**: Medium

---

## 🔍 2. Auth Service - Event Publishing Error Handling

### Issue: Event publishing errors bị ignore

**File**: `auth/internal/biz/user/user.go`

**Current Code**:
```go
_ = uc.eventPublisher.PublishEvent(ctx, "user.registered", event)
_ = uc.eventPublisher.PublishEvent(ctx, "user.authenticated", event)
```

**Problem**:
- Event publishing errors bị ignore hoàn toàn
- Không có logging nếu publish fails
- Có thể intentional (không block flow), nhưng nên log errors

**Impact**: Events có thể bị mất mà không biết

**Fix**:
```go
if err := uc.eventPublisher.PublishEvent(ctx, "user.registered", event); err != nil {
    uc.log.WithContext(ctx).Errorf("Failed to publish user.registered event: %v", err)
    // Don't fail operation, but log error
}
```

**Priority**: Low (có thể intentional)

---

## 🔍 3. Session Revoke Logic - Race Condition Risk

### Issue: Session revoke có thể fail nhưng vẫn tạo session mới

**File**: `auth/internal/biz/session/session.go`

**Current Code**:
```go
if err := uc.repo.DeleteSession(ctx, oldestSession.ID); err != nil {
    uc.log.WithContext(ctx).Warnf("Failed to revoke oldest session: %v", err)
}
// Continue to create new session even if revoke failed
```

**Problem**:
- Nếu revoke fails, vẫn tạo session mới
- Có thể dẫn đến vượt quá limit nếu revoke fails nhiều lần

**Impact**: Session limit có thể bị vượt quá

**Fix**:
- Option 1: Fail session creation nếu cannot revoke oldest
- Option 2: Retry revoke với exponential backoff
- Option 3: At least check total sessions again before creating

**Priority**: Medium

---

## 🔍 4. Missing Input Validation Patterns

### Issue: Cần check các service handlers có validate input đầy đủ không

**Files to Check**:
- `auth/internal/service/*.go`
- `user/internal/service/*.go`
- `catalog/internal/service/*.go`

**Common Missing Validations**:
- Empty string checks
- UUID format validation
- Required field checks
- Range validations (e.g., quantity > 0)

**Priority**: Medium (cần review từng service)

---

## 🔍 5. Null Pointer Checks

### Issue: Cần check các operations có handle nil pointers đúng cách không

**Common Patterns to Check**:
- `if x == nil` before dereferencing
- Optional fields (pointers) có được check không
- Database results có được check nil không

**Priority**: High (có thể cause panics)

---

## 🔍 6. Transaction Handling Gaps

### Issue: Multi-step operations có thể thiếu transaction wrapping

**Files to Check**:
- Operations có nhiều database calls
- Create operations với related entities
- Update operations với cascading changes

**Priority**: High (có thể cause data inconsistency)

---

## 🔍 7. Error Handling Patterns

### Issue: Cần check error handling consistency

**Common Patterns**:
- `if err != nil { return err }` - OK
- `if err != nil { log and continue }` - Cần verify intentional
- `_ = operation()` - Ignore errors - Cần verify intentional

**Priority**: Medium

---

## 📝 Next Steps

1. **Review Auth Service**:
   - Fix session limit logic gap
   - Add error logging for event publishing
   - Improve session revoke logic

2. **Review User Service**:
   - Check input validations
   - Check transaction handling
   - Check null pointer checks

3. **Review Catalog Service**:
   - Check CRUD operations
   - Check event publishing
   - Check validation logic

4. **Review Other Services**:
   - Warehouse Service (đã review)
   - Fulfillment Service (đã review)
   - Order Service (đã review)

---

## 🔄 Update History

- **2025-01-17**: Initial review - Found session limit logic gap, event publishing error handling, and session revoke logic issues


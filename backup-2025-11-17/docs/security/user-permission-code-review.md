# User Permission - Code Review Points

## 📋 Overview

Document này tập trung vào **code-level review** cho user permission implementation. Mỗi section sẽ có:
- Code location
- Current implementation
- Issues found
- Suggested fixes
- Code examples

---

## 1. Permission Aggregation Logic

### 1.1. Current Implementation

**Location:** `user/internal/data/postgres/permission.go:125`

```go
func (r *permissionRepo) GetUserPermissions(ctx context.Context, userID string) ([]string, []string, error) {
    // Get user roles
    assignments, err := r.GetUserRoles(ctx, userID)
    if err != nil {
        return nil, nil, err
    }

    var allPermissions []string
    var allServices []string

    // N+1 Query Problem
    for _, assignment := range assignments {
        var role Role
        if err := r.BaseRepo.DB(ctx).First(&role, "id = ?", assignment.RoleID).Error; err != nil {
            continue
        }

        perms := []string(role.Permissions)
        svcs := []string(role.Services)

        allPermissions = append(allPermissions, perms...)
        allServices = append(allServices, svcs...)
    }

    // Get service access permissions
    var serviceAccess []ServiceAccess
    r.BaseRepo.DB(ctx).Where("user_id = ?", userID).Find(&serviceAccess)
    for _, sa := range serviceAccess {
        perms := []string(sa.Permissions)
        allPermissions = append(allPermissions, perms...)
        allServices = append(allServices, sa.ServiceID)
    }

    // Remove duplicates (simplified)
    return r.uniqueStrings(allPermissions), r.uniqueStrings(allServices), nil
}
```

### 1.2. Issues

1. **N+1 Query Problem**: Query role trong loop
2. **No Priority Rules**: Không có priority giữa role permissions và direct permissions
3. **No Conflict Handling**: Không handle permission conflicts
4. **No Deny Permissions**: Không support deny permissions

### 1.3. Suggested Fix

```go
func (r *permissionRepo) GetUserPermissions(ctx context.Context, userID string) ([]string, []string, error) {
    // 1. Get user roles với JOIN để avoid N+1
    var assignments []struct {
        RoleAssignment
        Role
    }
    err := r.BaseRepo.DB(ctx).
        Table("user_roles").
        Select("user_roles.*, roles.*").
        Joins("JOIN roles ON user_roles.role_id = roles.id").
        Where("user_roles.user_id = ?", userID).
        Scan(&assignments).Error
    if err != nil {
        return nil, nil, err
    }

    // 2. Aggregate role permissions
    rolePermissions := make(map[string]bool)
    roleServices := make(map[string]bool)
    for _, assignment := range assignments {
        perms := []string(assignment.Role.Permissions)
        svcs := []string(assignment.Role.Services)
        for _, perm := range perms {
            rolePermissions[perm] = true
        }
        for _, svc := range svcs {
            roleServices[svc] = true
        }
    }

    // 3. Get direct service access (higher priority)
    var serviceAccess []ServiceAccess
    if err := r.BaseRepo.DB(ctx).Where("user_id = ?", userID).Find(&serviceAccess).Error; err != nil {
        return nil, nil, err
    }

    // 4. Direct permissions override role permissions
    directPermissions := make(map[string]bool)
    denyPermissions := make(map[string]bool)
    for _, sa := range serviceAccess {
        perms := []string(sa.Permissions)
        for _, perm := range perms {
            if strings.HasPrefix(perm, "!") {
                // Deny permission (negative permission)
                denyKey := strings.TrimPrefix(perm, "!")
                denyPermissions[denyKey] = true
                delete(rolePermissions, denyKey)
                delete(directPermissions, denyKey)
            } else {
                // Direct permission (higher priority than role)
                directPermissions[perm] = true
                delete(rolePermissions, perm) // Remove from role permissions
            }
        }
    }

    // 5. Merge permissions (direct > role, exclude denies)
    allPermissions := make([]string, 0)
    for perm := range directPermissions {
        if !denyPermissions[perm] {
            allPermissions = append(allPermissions, perm)
        }
    }
    for perm := range rolePermissions {
        if !denyPermissions[perm] {
            allPermissions = append(allPermissions, perm)
        }
    }

    // 6. Merge services
    allServices := make([]string, 0)
    for svc := range roleServices {
        allServices = append(allServices, svc)
    }
    for _, sa := range serviceAccess {
        allServices = append(allServices, sa.ServiceID)
    }

    return r.uniqueStrings(allPermissions), r.uniqueStrings(allServices), nil
}
```

---

## 2. Permission Format Validation

### 2.1. Current Implementation

**Location:** `user/internal/biz/user/user.go:544`

```go
func (uc *UserUsecase) CreateRole(ctx context.Context, role *Role) (*Role, error) {
    role.ID = uuid.New().String()
    return uc.roleRepo.Save(ctx, role) // No validation
}
```

### 2.2. Issues

1. **No Format Validation**: Không validate permission format
2. **No Service Validation**: Không validate service names
3. **No Conflict Check**: Không check permission conflicts

### 2.3. Suggested Fix

**Create:** `user/internal/biz/user/permission_validator.go`

```go
package user

import (
    "fmt"
    "regexp"
    "strings"
)

var (
    // Permission format: resource:action
    permissionFormatRegex = regexp.MustCompile(`^([a-z0-9_-]+):([a-z0-9_-]+|\*)$`)
    // Service permission format: service:resource:action
    servicePermissionFormatRegex = regexp.MustCompile(`^([a-z0-9_-]+):([a-z0-9_-]+):([a-z0-9_-]+|\*)$`)
)

// ValidatePermission validates permission format
func ValidatePermission(permission string) error {
    if permission == "*" {
        return nil // Wildcard allowed
    }
    
    if strings.HasPrefix(permission, "!") {
        // Deny permission
        permission = strings.TrimPrefix(permission, "!")
    }
    
    if permissionFormatRegex.MatchString(permission) {
        return nil
    }
    
    if servicePermissionFormatRegex.MatchString(permission) {
        return nil
    }
    
    return fmt.Errorf("invalid permission format: %s (expected: resource:action or service:resource:action)", permission)
}

// ValidatePermissions validates array of permissions
func ValidatePermissions(permissions []string) error {
    for _, perm := range permissions {
        if err := ValidatePermission(perm); err != nil {
            return fmt.Errorf("permission %s: %w", perm, err)
        }
    }
    return nil
}

// ValidateServiceName validates service name exists in Consul
func ValidateServiceName(ctx context.Context, serviceName string, consulClient *consul.Client) error {
    services, _, err := consulClient.Catalog().Service(serviceName, "", nil)
    if err != nil {
        return fmt.Errorf("failed to query consul: %w", err)
    }
    if len(services) == 0 {
        return fmt.Errorf("service %s not found in consul", serviceName)
    }
    return nil
}
```

**Update:** `user/internal/biz/user/user.go`

```go
func (uc *UserUsecase) CreateRole(ctx context.Context, role *Role) (*Role, error) {
    // Validate permissions format
    if err := ValidatePermissions(role.Permissions); err != nil {
        return nil, fmt.Errorf("invalid permissions: %w", err)
    }
    
    // Validate service names
    for _, svc := range role.Services {
        if err := ValidateServiceName(ctx, svc, uc.consulClient); err != nil {
            return nil, fmt.Errorf("invalid service %s: %w", svc, err)
        }
    }
    
    role.ID = uuid.New().String()
    return uc.roleRepo.Save(ctx, role)
}
```

---

## 3. Session Invalidation on Permission Changes

### 3.1. Current Implementation

**Location:** `user/internal/biz/user/user.go:550`

```go
func (uc *UserUsecase) UpdateRole(ctx context.Context, role *Role) (*Role, error) {
    return uc.roleRepo.Update(ctx, role) // No session invalidation
}
```

### 3.2. Issues

1. **No Session Invalidation**: Users giữ old permissions trong JWT token
2. **No Event Publishing**: Không notify Auth Service về permission changes

### 3.3. Suggested Fix

```go
func (uc *UserUsecase) UpdateRole(ctx context.Context, role *Role) (*Role, error) {
    // Get old role để compare
    oldRole, err := uc.roleRepo.FindByID(ctx, role.ID)
    if err != nil {
        return nil, err
    }
    
    // Update role
    updated, err := uc.roleRepo.Update(ctx, role)
    if err != nil {
        return nil, err
    }
    
    // Check if permissions changed
    permissionsChanged := !equalStringSlices(oldRole.Permissions, role.Permissions)
    
    if permissionsChanged {
        // Get all users with this role
        userIDs, err := uc.permissionRepo.GetUserIDsByRole(ctx, role.ID)
        if err != nil {
            uc.log.WithContext(ctx).Warnf("Failed to get users with role %s: %v", role.ID, err)
        } else {
            // Revoke all user sessions
            for _, userID := range userIDs {
                if uc.authClient != nil {
                    if err := uc.authClient.RevokeUserSessions(ctx, userID, "role_permissions_changed"); err != nil {
                        uc.log.WithContext(ctx).Warnf("Failed to revoke sessions for user %s: %v", userID, err)
                    }
                }
            }
            
            // Publish event
            if uc.eventPublisher != nil {
                event := map[string]interface{}{
                    "event_type": "role.permissions.updated",
                    "role_id":    role.ID,
                    "role_name":  role.Name,
                    "old_permissions": oldRole.Permissions,
                    "new_permissions": role.Permissions,
                    "affected_users": len(userIDs),
                    "timestamp":   time.Now(),
                }
                _ = uc.eventPublisher.PublishEvent(ctx, "role.permissions.updated", event)
            }
        }
    }
    
    return updated, nil
}
```

---

## 4. Permission Caching

### 4.1. Current Implementation

**Location:** `user/internal/data/postgres/permission.go:125`

- Không có caching, query database mỗi lần

### 4.2. Suggested Fix

**Create:** `user/internal/data/cache/permission_cache.go`

```go
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"

    "github.com/go-kratos/kratos/v2/log"
    "github.com/redis/go-redis/v9"
)

type PermissionCache struct {
    client *redis.Client
    log    *log.Helper
    ttl    time.Duration
}

func NewPermissionCache(client *redis.Client, logger log.Logger) *PermissionCache {
    return &PermissionCache{
        client: client,
        log:    log.NewHelper(logger),
        ttl:    10 * time.Minute, // Default TTL
    }
}

func (c *PermissionCache) GetUserPermissions(ctx context.Context, userID string) ([]string, []string, error) {
    key := fmt.Sprintf("permissions:user:%s", userID)
    
    data, err := c.client.Get(ctx, key).Result()
    if err == redis.Nil {
        return nil, nil, ErrCacheMiss
    }
    if err != nil {
        return nil, nil, err
    }
    
    var result struct {
        Permissions []string
        Services    []string
    }
    if err := json.Unmarshal([]byte(data), &result); err != nil {
        return nil, nil, err
    }
    
    return result.Permissions, result.Services, nil
}

func (c *PermissionCache) SetUserPermissions(ctx context.Context, userID string, permissions, services []string) error {
    key := fmt.Sprintf("permissions:user:%s", userID)
    
    data, err := json.Marshal(struct {
        Permissions []string
        Services    []string
    }{
        Permissions: permissions,
        Services:    services,
    })
    if err != nil {
        return err
    }
    
    return c.client.Set(ctx, key, data, c.ttl).Err()
}

func (c *PermissionCache) InvalidateUserPermissions(ctx context.Context, userID string) error {
    key := fmt.Sprintf("permissions:user:%s", userID)
    return c.client.Del(ctx, key).Err()
}

func (c *PermissionCache) InvalidateRolePermissions(ctx context.Context, roleID string) error {
    // Invalidate all users with this role
    // This requires getting all users with this role first
    // For now, we'll use a pattern-based invalidation
    pattern := "permissions:user:*"
    keys, err := c.client.Keys(ctx, pattern).Result()
    if err != nil {
        return err
    }
    
    // Delete all matching keys
    // Note: In production, use SCAN instead of KEYS
    if len(keys) > 0 {
        return c.client.Del(ctx, keys...).Err()
    }
    
    return nil
}
```

**Update:** `user/internal/data/postgres/permission.go`

```go
type permissionRepo struct {
    *commonRepo.BaseRepo
    log    *log.Helper
    cache  *cache.PermissionCache // Add cache
}

func (r *permissionRepo) GetUserPermissions(ctx context.Context, userID string) ([]string, []string, error) {
    // Try cache first
    if r.cache != nil {
        perms, svcs, err := r.cache.GetUserPermissions(ctx, userID)
        if err == nil {
            return perms, svcs, nil
        }
    }
    
    // Cache miss, query database
    perms, svcs, err := r.getUserPermissionsFromDB(ctx, userID)
    if err != nil {
        return nil, nil, err
    }
    
    // Update cache
    if r.cache != nil {
        _ = r.cache.SetUserPermissions(ctx, userID, perms, svcs)
    }
    
    return perms, svcs, nil
}
```

---

## 5. Audit Logging

### 5.1. Current Implementation

- Không có audit logging

### 5.2. Suggested Fix

**Create:** `user/internal/data/postgres/permission_audit.go`

```go
package postgres

import (
    "context"
    "time"

    commonTime "gitlab.com/ta-microservices/common/utils/time"
    "gorm.io/gorm"
)

type PermissionAuditLog struct {
    ID          string `gorm:"primaryKey"`
    UserID      string `gorm:"index"`
    Action      string // "assign_role", "revoke_role", "grant_service_access", etc.
    Resource    string // "role", "service_access"
    ResourceID  string
    OldValue    string `gorm:"type:text"`
    NewValue    string `gorm:"type:text"`
    ChangedBy   string
    ChangedAt   int64
    Reason      string `gorm:"type:text"`
}

func (r *permissionRepo) LogPermissionChange(ctx context.Context, log *PermissionAuditLog) error {
    log.ID = uuid.New().String()
    log.ChangedAt = commonTime.TimeToInt(time.Now())
    return r.BaseRepo.DB(ctx).Create(log).Error
}
```

**Update:** `user/internal/data/postgres/permission.go`

```go
func (r *permissionRepo) AssignRole(ctx context.Context, userID, roleID, assignedBy string) error {
    // ... existing code ...
    
    // Log audit
    auditLog := &PermissionAuditLog{
        UserID:     userID,
        Action:     "assign_role",
        Resource:   "role",
        ResourceID: roleID,
        NewValue:   roleID,
        ChangedBy:  assignedBy,
        Reason:     "Role assigned to user",
    }
    _ = r.LogPermissionChange(ctx, auditLog)
    
    return nil
}
```

---

## 6. Permission Versioning

### 6.1. Current Implementation

**Location:** `auth/internal/client/user/user_client.go:178`

```go
version = time.Now().Unix() // TODO: implement actual version tracking
```

### 6.2. Suggested Fix

**Update:** `user/internal/data/postgres/permission.go`

```go
type PermissionVersion struct {
    UserID    string `gorm:"primaryKey"`
    Version   int64  `gorm:"not null"`
    UpdatedAt int64
}

func (r *permissionRepo) GetPermissionVersion(ctx context.Context, userID string) (int64, error) {
    var version PermissionVersion
    err := r.BaseRepo.DB(ctx).First(&version, "user_id = ?", userID).Error
    if err == gorm.ErrRecordNotFound {
        // First time, create version
        version = PermissionVersion{
            UserID:    userID,
            Version:   1,
            UpdatedAt: commonTime.TimeToInt(time.Now()),
        }
        if err := r.BaseRepo.DB(ctx).Create(&version).Error; err != nil {
            return 0, err
        }
        return 1, nil
    }
    if err != nil {
        return 0, err
    }
    return version.Version, nil
}

func (r *permissionRepo) IncrementPermissionVersion(ctx context.Context, userID string) error {
    return r.BaseRepo.DB(ctx).
        Model(&PermissionVersion{}).
        Where("user_id = ?", userID).
        UpdateColumns(map[string]interface{}{
            "version":    gorm.Expr("version + 1"),
            "updated_at": commonTime.TimeToInt(time.Now()),
        }).Error
}
```

**Update:** `user/internal/biz/user/user.go`

```go
func (uc *UserUsecase) AssignRole(ctx context.Context, userID, roleID, assignedBy string) error {
    if err := uc.permissionRepo.AssignRole(ctx, userID, roleID, assignedBy); err != nil {
        return err
    }
    
    // Increment permission version
    _ = uc.permissionRepo.IncrementPermissionVersion(ctx, userID)
    
    // Revoke sessions
    if uc.authClient != nil {
        _ = uc.authClient.RevokeUserSessions(ctx, userID, "permissions_changed")
    }
    
    return nil
}
```

---

## 7. Permission Validation at Service Level

### 7.1. Current Implementation

- Services chỉ trust headers từ Gateway

### 7.2. Suggested Fix

**Create:** `common/middleware/permission_validator.go`

```go
package middleware

import (
    "context"
    "fmt"
    
    "github.com/go-kratos/kratos/v2/errors"
)

// ValidatePermission validates user has required permission
func ValidatePermission(ctx context.Context, requiredPermission string, userClient UserServiceClient) error {
    userID := ExtractUserID(ctx)
    if userID == "" {
        return errors.Unauthorized("UNAUTHORIZED", "user ID not found")
    }
    
    // Get user permissions from User Service
    permissions, _, err := userClient.GetUserPermissions(ctx, userID)
    if err != nil {
        return errors.Internal("PERMISSION_CHECK_FAILED", "failed to check permissions")
    }
    
    // Check if user has required permission
    hasPermission := false
    for _, perm := range permissions {
        if perm == requiredPermission || perm == "*" {
            hasPermission = true
            break
        }
        // Support wildcard matching
        if matchPermission(perm, requiredPermission) {
            hasPermission = true
            break
        }
    }
    
    if !hasPermission {
        return errors.Forbidden("FORBIDDEN", fmt.Sprintf("missing required permission: %s", requiredPermission))
    }
    
    return nil
}

func matchPermission(pattern, permission string) bool {
    // Support wildcard matching: "user:*" matches "user:read"
    if strings.HasSuffix(pattern, ":*") {
        prefix := strings.TrimSuffix(pattern, ":*")
        return strings.HasPrefix(permission, prefix+":")
    }
    return false
}
```

---

## 8. Summary

### Code Changes Required

1. **Permission Aggregation**: Fix N+1 queries, add priority rules
2. **Permission Validation**: Add format validation
3. **Session Invalidation**: Revoke sessions on permission changes
4. **Permission Caching**: Implement Redis cache
5. **Audit Logging**: Add audit logging for all changes
6. **Permission Versioning**: Implement actual version tracking
7. **Service Validation**: Validate permissions at service level

### Testing Required

1. Unit tests cho permission aggregation
2. Unit tests cho permission validation
3. Integration tests cho permission flow
4. Performance tests cho permission caching

### Documentation Required

1. Permission format documentation
2. API documentation updates
3. Admin UI documentation
4. Migration guide


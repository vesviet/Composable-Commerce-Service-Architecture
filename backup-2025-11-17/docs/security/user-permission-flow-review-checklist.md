# User Permission Flow - Review Checklist

## 📋 Overview

Document này tổng hợp các review points cho **User Permission Flow** trong hệ thống microservices. Mục đích là để identify issues, gaps, và improvements cần thiết.

## 🔍 Review Areas

### 1. Permission Storage & Structure

#### 1.1. Permission Storage Locations

**Current State:**
- ✅ User permissions: PostgreSQL (User Service)
  - `roles` table: Role definitions với permissions
  - `user_roles` table: User → Role assignments
  - `service_access` table: Direct user → Service permissions
- ✅ Service permissions: Consul KV
  - `service-permissions/{from-service}/{to-service}`
- ✅ JWT tokens: Permissions embedded trong token

**Review Questions:**
- [ ] **Q1.1.1**: Permission data có được sync giữa các storage locations không?
- [ ] **Q1.1.2**: Khi permissions thay đổi, có mechanism để invalidate cached permissions không?
- [ ] **Q1.1.3**: Service permissions trong Consul KV có được validate với database permissions không?

**Issues Found:**
- ⚠️ **I1.1.1**: Permissions trong JWT token không được update khi permissions thay đổi
- ⚠️ **I1.1.2**: Không có sync mechanism giữa database permissions và Consul KV permissions

**Recommendations:**
- [ ] **R1.1.1**: Implement permission cache invalidation khi permissions thay đổi
- [ ] **R1.1.2**: Add sync mechanism giữa database và Consul KV
- [ ] **R1.1.3**: Add permission version tracking để detect stale permissions

---

#### 1.2. Permission Format & Structure

**Current State:**
```go
// Permissions stored as string array
Permissions: []string{"user:read", "user:write", "order:*"}
```

**Review Questions:**
- [ ] **Q1.2.1**: Permission format có được standardized không?
- [ ] **Q1.2.2**: Có validation cho permission format không?
- [ ] **Q1.2.3**: Wildcard permissions (`*`) có được support đúng cách không?
- [ ] **Q1.2.4**: Permission hierarchy có được support không?

**Issues Found:**
- ⚠️ **I1.2.1**: Không có format validation khi create/update roles
- ⚠️ **I1.2.2**: Permission format không documented
- ⚠️ **I1.2.3**: Wildcard support không consistent

**Recommendations:**
- [ ] **R1.2.1**: Standardize permission format: `{resource}:{action}` hoặc `{service}:{resource}:{action}`
- [ ] **R1.2.2**: Add permission format validation
- [ ] **R1.2.3**: Document permission format và wildcard support
- [ ] **R1.2.4**: Consider permission hierarchy (parent/child permissions)

---

### 2. Permission Aggregation

#### 2.1. Permission Aggregation Logic

**Current Implementation:**
```go
// user/internal/data/postgres/permission.go:125
func (r *permissionRepo) GetUserPermissions(ctx context.Context, userID string) {
    // 1. Get permissions from roles
    // 2. Get permissions from service access
    // 3. Merge và remove duplicates
}
```

**Review Questions:**
- [ ] **Q2.1.1**: Permission aggregation logic có đúng không?
- [ ] **Q2.1.2**: Có priority rules giữa role permissions và direct permissions không?
- [ ] **Q2.1.3**: Permission conflicts có được handle không?
- [ ] **Q2.1.4**: Deny permissions có được support không?

**Issues Found:**
- ⚠️ **I2.1.1**: Không có priority rules (role vs direct permissions)
- ⚠️ **I2.1.2**: Không handle permission conflicts
- ⚠️ **I2.1.3**: Không support deny permissions

**Recommendations:**
- [ ] **R2.1.1**: Define priority: Direct permissions > Role permissions
- [ ] **R2.1.2**: Support deny permissions (negative permissions)
- [ ] **R2.1.3**: Handle conflicts explicitly (last wins hoặc deny wins)
- [ ] **R2.1.4**: Document aggregation logic

---

#### 2.2. Permission Caching

**Current State:**
- ❌ Không có permission caching
- Mỗi lần login đều query database

**Review Questions:**
- [ ] **Q2.2.1**: Permissions có được cache không?
- [ ] **Q2.2.2**: Cache invalidation strategy là gì?
- [ ] **Q2.2.3**: Cache TTL là bao lâu?

**Issues Found:**
- ⚠️ **I2.2.1**: Không có permission caching
- ⚠️ **I2.2.2**: Performance issue khi nhiều users login cùng lúc

**Recommendations:**
- [ ] **R2.2.1**: Implement Redis cache cho permissions
- [ ] **R2.2.2**: Cache TTL: 5-10 minutes
- [ ] **R2.2.3**: Invalidate cache khi permissions thay đổi
- [ ] **R2.2.4**: Cache key: `permissions:user:{user_id}`

---

### 3. Permission Management APIs

#### 3.1. Role Management

**APIs:**
- `POST /api/v1/roles` - CreateRole
- `PUT /api/v1/roles/{id}` - UpdateRole
- `GET /api/v1/roles` - ListRoles
- `DELETE /api/v1/roles/{id}` - DeleteRole

**Review Questions:**
- [ ] **Q3.1.1**: Role creation có validate permissions không?
- [ ] **Q3.1.2**: Role update có invalidate user sessions không?
- [ ] **Q3.1.3**: Role deletion có check dependencies không?
- [ ] **Q3.1.4**: Role permissions có được audit log không?

**Issues Found:**
- ⚠️ **I3.1.1**: Không validate permission format khi create role
- ⚠️ **I3.1.2**: Update role không revoke user sessions
- ⚠️ **I3.1.3**: Không có audit logging

**Recommendations:**
- [ ] **R3.1.1**: Add permission format validation
- [ ] **R3.1.2**: Revoke all user sessions khi role permissions thay đổi
- [ ] **R3.1.3**: Check dependencies trước khi delete role
- [ ] **R3.1.4**: Add audit logging cho role changes

---

#### 3.2. User Role Assignment

**APIs:**
- `POST /api/v1/users/{user_id}/roles` - AssignRole
- `DELETE /api/v1/users/{user_id}/roles/{role_id}` - RemoveRole

**Review Questions:**
- [ ] **Q3.2.1**: Role assignment có validate permissions không?
- [ ] **Q3.2.2**: Role assignment có invalidate user sessions không?
- [ ] **Q3.2.3**: Role assignment có được audit log không?
- [ ] **Q3.2.4**: Có check for circular role dependencies không?

**Issues Found:**
- ⚠️ **I3.2.1**: AssignRole không revoke user sessions
- ⚠️ **I3.2.2**: Không có audit logging

**Recommendations:**
- [ ] **R3.2.1**: Revoke user sessions khi assign/remove role
- [ ] **R3.2.2**: Add audit logging
- [ ] **R3.2.3**: Validate role exists và is active
- [ ] **R3.2.4**: Check for permission conflicts

---

#### 3.3. Service Access Management

**APIs:**
- `POST /api/v1/users/{id}/service-access` - GrantServiceAccess
- `DELETE /api/v1/users/{id}/service-access/{service_id}` - RevokeServiceAccess
- `GET /api/v1/users/{id}/service-access` - GetServiceAccess

**Review Questions:**
- [ ] **Q3.3.1**: Service access có validate service exists không?
- [ ] **Q3.3.2**: Service access có invalidate user sessions không?
- [ ] **Q3.3.3**: Service access có được audit log không?
- [ ] **Q3.3.4**: Service permissions có sync với Consul KV không?

**Issues Found:**
- ⚠️ **I3.3.1**: Không validate service exists
- ⚠️ **I3.3.2**: Không revoke user sessions
- ⚠️ **I3.3.3**: Không có audit logging

**Recommendations:**
- [ ] **R3.3.1**: Validate service exists trong Consul
- [ ] **R3.3.2**: Revoke user sessions khi grant/revoke service access
- [ ] **R3.3.3**: Add audit logging
- [ ] **R3.3.4**: Sync với Consul KV permissions

---

### 4. Permission Validation

#### 4.1. Permission Validation Flow

**Current State:**
- Gateway extracts permissions từ JWT token
- Forward permissions qua headers: `X-User-Permissions`
- Services trust headers (không validate)

**Review Questions:**
- [ ] **Q4.1.1**: Services có validate permissions không?
- [ ] **Q4.1.2**: Có mechanism để verify permissions từ User Service không?
- [ ] **Q4.1.3**: Permission validation có được cache không?
- [ ] **Q4.1.4**: Có rate limiting cho permission validation không?

**Issues Found:**
- ⚠️ **I4.1.1**: Services chỉ trust headers, không validate
- ⚠️ **I4.1.2**: Không có mechanism để verify permissions
- ⚠️ **I4.1.3**: Security risk: headers có thể bị tamper

**Recommendations:**
- [ ] **R4.1.1**: Services nên validate permissions với User Service
- [ ] **R4.1.2**: Add permission verification endpoint
- [ ] **R4.1.3**: Cache validation results với short TTL
- [ ] **R4.1.4**: Add rate limiting

---

#### 4.2. Permission Check Performance

**Current State:**
- Permission check = database query mỗi lần
- Không có caching

**Review Questions:**
- [ ] **Q4.2.1**: Permission check có performance issue không?
- [ ] **Q4.2.2**: Có N+1 query problem không?
- [ ] **Q4.2.3**: Permission queries có được optimize không?

**Issues Found:**
- ⚠️ **I4.2.1**: N+1 queries trong GetUserPermissions
- ⚠️ **I4.2.2**: Không có query optimization

**Recommendations:**
- [ ] **R4.2.1**: Use JOIN thay vì N+1 queries
- [ ] **R4.2.2**: Add database indexes
- [ ] **R4.2.3**: Implement permission caching

---

### 5. Permission Versioning & Invalidation

#### 5.1. Permission Versioning

**Current State:**
```go
// auth/internal/biz/user/user.go:178
version = time.Now().Unix() // TODO: implement actual version tracking
```

**Review Questions:**
- [ ] **Q5.1.1**: Permission versioning có được implement không?
- [ ] **Q5.1.2**: Version có được track trong database không?
- [ ] **Q5.1.3**: JWT tokens có check permission version không?
- [ ] **Q5.1.4**: Có mechanism để force token refresh khi permissions thay đổi không?

**Issues Found:**
- ⚠️ **I5.1.1**: Permission versioning không được implement
- ⚠️ **I5.1.2**: Version chỉ là timestamp, không track changes
- ⚠️ **I5.1.3**: JWT tokens không check version

**Recommendations:**
- [ ] **R5.1.1**: Implement actual version tracking trong database
- [ ] **R5.1.2**: Increment version khi permissions thay đổi
- [ ] **R5.1.3**: Check version trong JWT token validation
- [ ] **R5.1.4**: Force token refresh khi version mismatch

---

#### 5.2. Session Invalidation

**Current State:**
- AssignRole có revoke sessions
- UpdateRole không revoke sessions

**Review Questions:**
- [ ] **Q5.2.1**: Tất cả permission changes có revoke sessions không?
- [ ] **Q5.2.2**: Session revocation có được broadcast không?
- [ ] **Q5.2.3**: Có mechanism để notify users về permission changes không?

**Issues Found:**
- ⚠️ **I5.2.1**: UpdateRole không revoke sessions
- ⚠️ **I5.2.2**: GrantServiceAccess không revoke sessions
- ⚠️ **I5.2.3**: Không có broadcast mechanism

**Recommendations:**
- [ ] **R5.2.1**: Revoke sessions cho tất cả permission changes
- [ ] **R5.2.2**: Publish event khi permissions thay đổi
- [ ] **R5.2.3**: Notify users về permission changes (optional)

---

### 6. Audit Logging & Compliance

#### 6.1. Permission Audit Logging

**Current State:**
- ❌ Không có audit logging cho permission changes

**Review Questions:**
- [ ] **Q6.1.1**: Permission changes có được audit log không?
- [ ] **Q6.1.2**: Audit logs có được store ở đâu?
- [ ] **Q6.1.3**: Audit logs có được searchable không?
- [ ] **Q6.1.4**: Audit logs có retention policy không?

**Issues Found:**
- ⚠️ **I6.1.1**: Không có audit logging
- ⚠️ **I6.1.2**: Không track who/when/what

**Recommendations:**
- [ ] **R6.1.1**: Add audit logging cho tất cả permission changes
- [ ] **R6.1.2**: Store audit logs in separate table
- [ ] **R6.1.3**: Log: who, when, what, why, old_value, new_value
- [ ] **R6.1.4**: Add retention policy (ví dụ: 1 year)

---

#### 6.2. Compliance & Security

**Review Questions:**
- [ ] **Q6.2.1**: Permission changes có được authorized không?
- [ ] **Q6.2.2**: Có check for privilege escalation không?
- [ ] **Q6.2.3**: Permission changes có được rate limited không?
- [ ] **Q6.2.4**: Có mechanism để detect suspicious permission changes không?

**Issues Found:**
- ⚠️ **I6.2.1**: Không check for privilege escalation
- ⚠️ **I6.2.2**: Không có rate limiting

**Recommendations:**
- [ ] **R6.2.1**: Check for privilege escalation
- [ ] **R6.2.2**: Add rate limiting cho permission changes
- [ ] **R6.2.3**: Add alerting cho suspicious changes
- [ ] **R6.2.4**: Require approval cho sensitive permission changes

---

### 7. Admin Interface

#### 7.1. Role Management UI

**Current State:**
- ✅ RolesPage: CRUD roles
- ✅ Assign permissions/services

**Review Questions:**
- [ ] **Q7.1.1**: UI có validate permission format không?
- [ ] **Q7.1.2**: UI có show permission conflicts không?
- [ ] **Q7.1.3**: UI có preview permissions trước khi save không?
- [ ] **Q7.1.4**: UI có permission templates không?

**Issues Found:**
- ⚠️ **I7.1.1**: UI không validate permission format
- ⚠️ **I7.1.2**: Không có permission templates

**Recommendations:**
- [ ] **R7.1.1**: Add client-side validation
- [ ] **R7.1.2**: Add permission templates
- [ ] **R7.1.3**: Show permission conflicts
- [ ] **R7.1.4**: Add permission preview

---

#### 7.2. User Permission Management UI

**Current State:**
- ✅ UsersPage: Assign roles
- ❌ Không có UI để manage direct permissions

**Review Questions:**
- [ ] **Q7.2.1**: UI có show user permissions không?
- [ ] **Q7.2.2**: UI có allow manage direct permissions không?
- [ ] **Q7.2.3**: UI có show permission sources (role vs direct) không?
- [ ] **Q7.2.4**: UI có show permission conflicts không?

**Issues Found:**
- ⚠️ **I7.2.1**: Không có UI để manage direct permissions
- ⚠️ **I7.2.2**: Không show permission sources

**Recommendations:**
- [ ] **R7.2.1**: Add UI để manage direct permissions
- [ ] **R7.2.2**: Show permission sources
- [ ] **R7.2.3**: Show permission conflicts
- [ ] **R7.2.4**: Add permission preview

---

### 8. Testing & Quality

#### 8.1. Unit Tests

**Review Questions:**
- [ ] **Q8.1.1**: Permission aggregation có unit tests không?
- [ ] **Q8.1.2**: Permission validation có unit tests không?
- [ ] **Q8.1.3**: Permission conflicts có test cases không?
- [ ] **Q8.1.4**: Test coverage là bao nhiêu?

**Issues Found:**
- ⚠️ **I8.1.1**: Không thấy unit tests cho permission logic

**Recommendations:**
- [ ] **R8.1.1**: Add unit tests cho permission aggregation
- [ ] **R8.1.2**: Add unit tests cho permission validation
- [ ] **R8.1.3**: Add test cases cho permission conflicts
- [ ] **R8.1.4**: Aim for 80%+ test coverage

---

#### 8.2. Integration Tests

**Review Questions:**
- [ ] **Q8.2.1**: Permission flow có integration tests không?
- [ ] **Q8.2.2**: Role assignment flow có integration tests không?
- [ ] **Q8.2.3**: Permission validation flow có integration tests không?

**Recommendations:**
- [ ] **R8.2.1**: Add integration tests cho permission flow
- [ ] **R8.2.2**: Add integration tests cho role assignment
- [ ] **R8.2.3**: Add integration tests cho permission validation

---

### 9. Documentation

#### 9.1. Permission Format Documentation

**Review Questions:**
- [ ] **Q9.1.1**: Permission format có được documented không?
- [ ] **Q9.1.2**: Permission examples có được provided không?
- [ ] **Q9.1.3**: Wildcard support có được documented không?

**Issues Found:**
- ⚠️ **I9.1.1**: Permission format không documented

**Recommendations:**
- [ ] **R9.1.1**: Document permission format
- [ ] **R9.1.2**: Provide permission examples
- [ ] **R9.1.3**: Document wildcard support

---

#### 9.2. API Documentation

**Review Questions:**
- [ ] **Q9.2.1**: Permission management APIs có được documented không?
- [ ] **Q9.2.2**: API examples có được provided không?
- [ ] **Q9.2.3**: Error responses có được documented không?

**Recommendations:**
- [ ] **R9.2.1**: Document permission management APIs
- [ ] **R9.2.2**: Provide API examples
- [ ] **R9.2.3**: Document error responses

---

## 📊 Summary

### Critical Issues (Must Fix)

1. **Permission Versioning**: Không được implement, users giữ stale permissions
2. **Session Invalidation**: UpdateRole không revoke sessions
3. **Permission Validation**: Services không validate permissions, chỉ trust headers
4. **Audit Logging**: Không có audit logging cho permission changes

### High Priority Issues

1. **Permission Caching**: Không có caching, performance issues
2. **Permission Format**: Không có format validation
3. **Permission Aggregation**: Không có priority rules
4. **N+1 Queries**: Performance issues trong GetUserPermissions

### Medium Priority Issues

1. **Permission Templates**: Không có templates
2. **Permission Conflicts**: Không handle conflicts
3. **Service Validation**: Không validate service exists
4. **UI Improvements**: Thiếu features trong admin UI

### Low Priority Issues

1. **Permission Inheritance**: Không support inheritance
2. **Conditional Permissions**: Không support conditional permissions
3. **Permission Groups**: Không có permission groups

---

## 🎯 Action Items

### Phase 1: Critical Fixes (Week 1-2)
- [ ] Implement permission versioning
- [ ] Fix session invalidation cho tất cả permission changes
- [ ] Add permission validation ở services
- [ ] Add audit logging

### Phase 2: High Priority (Week 3-4)
- [ ] Implement permission caching
- [ ] Add permission format validation
- [ ] Fix permission aggregation logic
- [ ] Optimize permission queries

### Phase 3: Medium Priority (Week 5-6)
- [ ] Add permission templates
- [ ] Handle permission conflicts
- [ ] Improve admin UI
- [ ] Add service validation

### Phase 4: Low Priority (Week 7-8)
- [ ] Add permission inheritance
- [ ] Add conditional permissions
- [ ] Add permission groups
- [ ] Improve documentation

---

## 📝 Notes

- Review này tập trung vào **user permissions**, không bao gồm service-to-service permissions
- Một số recommendations có thể require architectural changes
- Priority có thể thay đổi dựa trên business requirements

---

## 🔗 Related Documents

- [Auth & Permission Flow Review](./auth-permission-flow-review.md)
- [Service Permission Matrix](../security/service-permission-matrix.md)
- [Security Overview](../security/security-overview.md)


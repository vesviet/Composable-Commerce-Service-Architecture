# User Management (Admin) Issues & Improvement Checklist

## Critical Priority (P0)
- [ ] **Audit Logging**: Ensure comprehensive audit logging for all role assignments and status changes. Current implementation needs verification.
- [ ] **Middleware Enforcement**: Verify that `ValidateAccess` is correctly integrated into the Gateway middleware for all protected routes.
- [ ] **Rate Limiting**: Ensure login attempts (`ValidateUserCredentials`) are rate-limited to prevent brute force attacks (likely handled by Auth service, but User service should ideally track failed attempts too).

## High Priority (P1)
- [ ] **Password Policy**: Make password complexity rules configurable (currently hardcoded or basic len check).
- [ ] **Soft Delete**: Verify `DeleteUser` performs a proper soft delete and that `ListUsers` filters them out by default.
- [ ] **Service Access Granularity**: Review if `GrantServiceAccess` needs more granular permission definitions beyond just "service access".

## Medium Priority (P2)
- [ ] **Caching**: Verify `GetUserPermissions` results are cached effectively and invalidated on role changes.
- [ ] **MFA Status**: `AuthStatus` message includes MFA fields, but need to confirm if User service actually stores/manages this state or just proxies it.
- [ ] **Bulk Operations**: No endpoint for bulk user import or role assignment.

## Low Priority (P3)
- [ ] **Department Management**: `department` is just a string. Consider normalizing into a separate lookup table/enum if strict validation is needed.
- [ ] **Hierarchical Roles**: Consider if roles should inherit permissions from other roles (not currently in proto).

## Testing
- [ ] Add integration tests for the full User Creation -> Role Assignment -> Access Check flow.
- [ ] Verify RBAC enforcement with negative test cases (user without permission gets denied).

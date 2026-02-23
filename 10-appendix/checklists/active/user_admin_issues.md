# User Management (Admin) Issues & Improvement Checklist

**Last Updated**: 2026-01-21

## 🚩 PENDING ISSUES (Unfixed)
- [Critical] [USER-P0-01 Audit logging for admin actions]: Role assignments/status changes lack verified audit trail. Required: ensure comprehensive audit logs for admin operations.
- [Critical] [USER-P0-02 ValidateAccess middleware coverage]: Verify `ValidateAccess` is enforced for all protected routes in gateway. Required: audit routing/middleware coverage and add tests.
- [Critical] [USER-P0-03 Rate limiting for credential validation]: Ensure `ValidateUserCredentials` is rate-limited (user service should track failures even if auth also rate-limits).
- [High] [USER-P1-01 Configurable password policy]: Password complexity rules are basic/hardcoded. Required: make rules configurable.
- [High] [USER-P1-02 Soft delete verification]: Ensure `DeleteUser` is soft delete and `ListUsers` filters deleted users.
- [High] [USER-P1-03 Service access granularity]: `GrantServiceAccess` may need finer permissions beyond service-level.
- [Medium] [USER-P2-01 Permissions cache invalidation]: `GetUserPermissions` caching/invalidation not verified.
- [Medium] [USER-P2-02 MFA status source-of-truth]: Confirm whether user service stores MFA state or proxies only.
- [Medium] [USER-P2-03 Bulk operations missing]: No bulk user import/role assignment endpoints.
- [Low] [USER-P3-01 Department normalization]: `department` is a string; consider lookup table/enum if strict validation needed.
- [Low] [USER-P3-02 Hierarchical roles]: Role inheritance not supported; evaluate need.
- [Medium] [USER-P2-04 Missing integration tests]: Add tests for User Creation → Role Assignment → Access Check flow.
- [Medium] [USER-P2-05 Missing negative RBAC tests]: Verify access denied for insufficient permissions.

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- None

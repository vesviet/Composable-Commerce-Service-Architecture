# Workflow Review: Account Management

**Workflow**: Account Management (Customer Journey)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~1.5 hours  
**Status**: Complete

---

## Review Summary

Review followed **docs/07-development/standards/workflow-review-sequence-guide.md** (Phase 1, item 5) and **end-to-end-workflow-review-prompt.md**. Focus: authentication, security, user experience per guide.

**Workflow doc**: `docs/05-workflows/customer-journey/account-management.md`  
**Dependencies**: External APIs (OAuth) per guide

---

## Service Participation Matrix

| Service | Role | Input Data | Output Data | Events Published | Events Consumed |
|---------|------|------------|-------------|------------------|-----------------|
| **Gateway** | Entry | HTTP requests | Routed responses | — | — |
| **Auth Service** | Authentication | Login, token ops | JWT, session, Validate/Refresh/Revoke | (auth.login, auth.password_changed per Customer consumption) | — |
| **Customer Service** | Profile + Customer Auth | Register, Login, Verify, Password reset, Profile | Tokens (via Auth), profile, addresses | (auth.customer.* per doc; verify implementation) | auth.login, auth.password_changed |
| **User Service** | Admin users | Validate credentials | User info | — | — |
| **Notification Service** | Communication | Send email/SMS | Queued | — | — |
| **Loyalty Service** | Rewards | customer_id | Points, tier | — | — |
| **Order Service** | Order history | customer_id | Orders | — | — |
| **Analytics Service** | Behavior | Events | Insights | — | auth.customer.* (per doc) |

---

## Findings

### Strengths

1. **Clear separation of concerns**: Auth Service handles tokens, sessions, and credential validation (User/Customer); Customer Service holds customer profile, registration, verification, and password reset; User Service holds admin users.
2. **Dual login paths**: (1) Auth Service Login with `userType=admin|customer` (validates via User or Customer gRPC); (2) Customer Service Login (validates locally, calls Auth.GenerateToken). Both paths produce JWTs from Auth.
3. **Token operations**: Auth exposes GenerateToken, ValidateToken, RefreshToken, RevokeToken; Customer calls Auth.GenerateToken for customer login. Gateway routes `/api/v1/auth/*` to Auth and `/api/v1/customers/login|register|...` to Customer.
4. **Session and revocation**: Auth has session usecase (CreateSession, RevokeSession, RevokeUserSessions); Logout revokes token and session(s).
5. **Customer registration and verification**: Customer Service implements Register, VerifyEmail (verificationUC), RequestPasswordReset, ConfirmPasswordReset; Auth client used for token generation on login.
6. **Auth client in Customer**: Customer calls Auth Service (gRPC) for GenerateToken with circuit breaker; Customer exposes ValidateCredentials and RecordLogin for Auth to call when userType=customer.
7. **Event consumption**: Customer consumes `auth.login` and `auth.password_changed` (eventbus) for last-login update and profile sync.
8. **Workflow documentation**: Account-management doc is detailed (phases 1–5, sequence diagrams, business rules, events, KPIs, security, integration points).

### Issues Found

#### P2 – Registration and verify entry point vs workflow doc

- **Workflow doc**: “POST /auth/register” → Gateway → Auth Service; Auth creates auth record, calls Customer CreateCustomerProfile, sends verification; “GET /auth/verify?token=”.
- **Implementation**: Gateway routes `/api/v1/customers/register` and `/api/v1/customers/verify-email` (and login, refresh, validate, forgot-password, reset-password) to **Customer Service**. Auth Service does **not** expose Register or Verify; Customer Service is the entry for customer registration and email verification.
- **Impact**: Documentation suggests Auth as the single entry for auth flows; implementation uses Customer as entry for customer registration/verify. Both are valid; doc and clients (e.g. frontend) should align on actual paths.
- **Recommendation**: Update workflow doc to state that **customer** registration and verification are served by Customer Service at `/api/v1/customers/register` and `/api/v1/customers/verify-email` (or equivalent), and that Auth Service is used for login (and token ops) and for admin login; or add Auth-side register/verify that delegate to Customer and keep doc as-is.

#### P2 – Event naming and publishing

- **Workflow doc**: Events `auth.customer.registered`, `auth.customer.verified`, `auth.customer.login`, `auth.customer.logout`; Analytics and Loyalty consume.
- **Implementation**: Auth defines `UserRegisteredEvent`, `UserAuthenticatedEvent`, `UserLogoutEvent` (biz/events.go); actual topic names and whether Auth or Customer publishes `auth.customer.*` were not verified in code. Customer consumes `auth.login` and `auth.password_changed` (Dapr).
- **Recommendation**: Confirm who publishes which topics (Auth vs Customer) and align topic names with workflow (e.g. `auth.customer.login` vs `auth.login`). Ensure Analytics/Loyalty subscribe to the topics that are actually published.

#### P2 – JWT signing algorithm

- **Workflow doc**: “JWT Security: RS256 signing, short-lived tokens”.
- **Implementation**: Auth typically uses HS256 (symmetric) in Kratos/JWT setups; RS256 (asymmetric) is common for multi-service validation. Not confirmed in this review.
- **Recommendation**: If Auth uses HS256, update doc to “HS256” and document key distribution; if moving to RS256, document key rotation and public key exposure.

#### P2 – MFA and OAuth

- **Workflow doc**: MFA (TOTP, SMS), OAuth2 (Google, Facebook, GitHub, Apple), account lockout (5 attempts, 15 min).
- **Implementation**: Auth has Login with userType; token and session logic present. MFA and OAuth endpoints were not traced in this review.
- **Recommendation**: Verify MFA and OAuth endpoints exist and are wired in Auth or Customer; document any gaps (e.g. OAuth callback, MFA enable/verify).

### Recommendations

1. **Align doc with entry points**: Document that customer registration and email verification are under Customer Service (`/api/v1/customers/register`, `/api/v1/customers/verify-email`) and list Auth endpoints for login, refresh, validate, logout.
2. **Event contract**: Publish a short event catalog (topics, payloads, producers) for auth.customer.* and auth.login/auth.password_changed and ensure Analytics/Loyalty subscriptions match.
3. **JWT algorithm**: Set and document JWT algorithm (HS256 vs RS256) and key handling.
4. **MFA/OAuth**: Confirm MFA and OAuth implementation status and document in workflow or “Implementation status” section.

---

## Dependencies Validated

- **External APIs (OAuth)**: Workflow lists OAuth as dependency; implementation of OAuth callbacks not fully traced. Customer and Auth client integration (Auth.GenerateToken) is present.
- **Gateway**: Routes for `/api/v1/auth/*` and `/api/v1/customers/*` (login, register, refresh, validate, forgot-password, reset-password, verify-email) are configured.

---

## Next Steps

| Action | Owner | Priority | Status |
|--------|--------|----------|--------|
| Update workflow doc: registration/verify entry = Customer Service paths | Docs | P2 | **Done** (2026-01-31): account-management.md updated |
| Document JWT algorithm (HS256) and key strategy | Auth | P2 | **Done**: Doc updated to HS256, JWT_SECRET/JWT_SECRETS |
| Confirm and document event topics (auth.customer.* vs auth.login) and publishers | Auth + Customer | P2 | Open |
| Verify MFA and OAuth implementation and document status | Auth / Customer | P2 | Open |

---

## Checklist Created

- **Workflow checklist**: `docs/10-appendix/checklists/workflow/customer-journey_account-management_workflow_checklist.md`

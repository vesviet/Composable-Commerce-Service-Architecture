# Workflow Checklist: Account Management

**Workflow**: Account Management (Customer Journey)
**Status**: In Progress
**Last Updated**: 2026-01-31

## 1. Documentation & Design
- [x] Workflow Overview and Business Context defined
- [x] Service Architecture and Participants mapped (Gateway, Auth, Customer, User, Notification, Loyalty, Order, Analytics)
- [x] Phases documented (Registration, Authentication, Profile, Security, Analytics)
- [x] Sequence diagrams for Registration, Login, Verify, Profile, Password, MFA, OAuth
- [x] Business Rules (Registration, Authentication, Profile, Security) defined
- [x] Event Flow Architecture (auth.customer.*, customer.profile.*, security events) documented
- [x] Integration Points and Performance Metrics defined
- [x] **Doc aligned with entry points** — Workflow doc updated (2026-01-31): Customer Service entry for register/verify; API paths and JWT (HS256) documented

## 2. Registration & Verification
- [x] Customer Service: Register, VerifyEmail (verificationUC)
- [x] Gateway routes /api/v1/customers/register, /api/v1/customers/verify-email → Customer Service
- [x] Workflow doc updated: customer registration/verify entry = Customer Service paths; sequence diagrams and API summary aligned
- [ ] Event auth.customer.registered published (by Auth or Customer) and consumed by Analytics/Loyalty

## 3. Authentication & Login
- [x] Auth Service: Login (userType admin|customer), GetCurrentUser, Logout; ValidateToken, RefreshToken, RevokeToken; GenerateToken (called by Customer)
- [x] Auth validates admin via User Service, customer via Customer.ValidateCredentials (gRPC)
- [x] Customer Service: Login (validates + calls Auth.GenerateToken), ValidateCredentials, RecordLogin
- [x] Gateway routes /api/v1/auth/login, /api/v1/auth/refresh, /api/v1/auth/validate → Auth; /api/v1/customers/login → Customer
- [ ] Event auth.customer.login (or auth.login) published and consumed; topic names aligned with doc

## 4. Profile & Address Management
- [x] Customer Service: profile, addresses, preferences (per workflow)
- [x] Gateway routes /api/v1/customers/* for profile, addresses, preferences
- [ ] Location Service integration for address validation (document or verify)

## 5. Password Management
- [x] Customer Service: RequestPasswordReset, ConfirmPasswordReset (authUC)
- [x] Customer consumes auth.password_changed
- [ ] Workflow doc: password change/reset paths (Auth vs Customer) aligned with implementation

## 6. MFA & OAuth
- [ ] MFA (TOTP, SMS) endpoints and flow implemented and documented
- [ ] OAuth2 (Google, Facebook, GitHub) init and callback implemented and documented
- [ ] Account lockout (5 attempts, 15 min) and rate limiting verified

## 7. Events & Integration
- [x] Customer consumes auth.login, auth.password_changed (Dapr)
- [ ] auth.customer.registered, auth.customer.verified, auth.customer.login, auth.customer.logout: publishers and topic names confirmed; Analytics/Loyalty subscriptions aligned
- [ ] customer.profile.updated, customer.address.added: published and consumed as doc

## 8. Security & Compliance
- [x] Password policy (min length, complexity) and hashing (bcrypt) in place
- [x] JWT algorithm (HS256) and key strategy (JWT_SECRET/JWT_SECRETS) documented in workflow doc
- [ ] Rate limiting and session revocation (Auth) verified
- [ ] GDPR/data export and account deletion (document or implement)

## 9. Observability & Testing
- [ ] Auth/Customer metrics (login success, latency, errors) and dashboards
- [ ] End-to-end tests: register → verify → login → profile update
- [ ] Load tests: login throughput, registration throughput per SLA

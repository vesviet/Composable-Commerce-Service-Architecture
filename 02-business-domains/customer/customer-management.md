# Customer & Account Management Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code

## Overview

This document describes the flows for customer registration, authentication, and data management. The logic is distributed across three primary services: `customer`, `auth`, and `gateway`.

**Service Responsibilities:**
-   **`customer` service**: Owns customer data (profile, addresses, preferences) and the business logic for registration and login.
-   **`auth` service**: A specialized service that handles the lifecycle of sessions and JWTs (generation, validation, refresh, revocation).
-   **`gateway` service**: Acts as the security entry point, validating tokens on every request and enforcing a trust boundary.

**Key Files:**
-   `customer/internal/biz/customer/customer.go`
-   `customer/internal/biz/customer/auth.go`
-   `auth/internal/biz/token/token.go`
-   `gateway/internal/router/utils/jwt_validator_wrapper.go`

---

## Key Flows

### 1. Customer Registration Flow

-   **File**: `customer/internal/biz/customer/auth.go` (`Register` function)
-   **Logic**:
    1.  The `customer` service receives the registration request (email, password, etc.).
    2.  It validates the input and checks if the email already exists.
    3.  It hashes the password using a common security utility.
    4.  **Atomicity**: The creation of the `Customer`, `CustomerProfile`, and `CustomerPreferences` records is wrapped in a single **database transaction**.
    5.  Within the same transaction, it triggers the sending of a verification email. If the email fails to send, the entire transaction is rolled back, preventing orphaned accounts.

### 2. Customer Login Flow

-   **File**: `customer/internal/biz/customer/auth.go` (`Login` function)
-   **Logic**:
    1.  **Security**: The flow first checks for **rate limiting** by IP address and **account lockout** based on the number of failed attempts for the email (tracked in Redis).
    2.  It retrieves the customer by email and verifies the password hash.
    3.  If credentials are valid, it resets the failed login attempt counter.
    4.  **Delegation**: It then calls the `auth` service's `GenerateToken` method, passing the user's ID and other claims.
    5.  The `auth` service creates a new session, generates a new `AccessToken` and `RefreshToken`, and returns them to the `customer` service, which then forwards them to the client.

### 3. Per-Request Token Validation Flow (at Gateway)

-   **File**: `gateway/internal/router/utils/jwt_validator_wrapper.go` (`ValidateToken` function)
-   **Logic**: This happens on every authenticated API request.
    1.  **Trust Boundary**: The gateway first strips any client-sent identity headers (e.g., `X-User-ID`) to prevent spoofing.
    2.  **Blacklist Check**: It checks if the token's session ID exists in a Redis blacklist of revoked tokens. This check is **fail-closed**; if Redis is unavailable, the token is rejected for security.
    3.  **Cache Check**: It checks a local, in-memory cache for a valid, non-expired validation result to improve performance.
    4.  **Local Validation**: On a cache miss, it validates the JWT's signature and claims locally using the shared secret.
    5.  **Fallback**: It includes a fallback mechanism (`ValidateTokenWithAuthService`) wrapped in a **circuit breaker** to call the `auth` service directly for validation if needed.
    6.  **Trust Boundary**: After successful validation, the gateway injects trusted identity headers (e.g., `X-User-ID`, `X-User-Roles`) into the request before forwarding it to the downstream service.

### 4. Token Refresh Flow

-   **File**: `auth/internal/biz/token/token.go` (`RefreshToken` function)
-   **Logic**:
    1.  The `auth` service receives the `RefreshToken`.
    2.  It first validates the refresh token itself (checking signature, expiry, and ensuring it hasn't been revoked).
    3.  **Refresh Token Rotation**: In a critical security step, the old refresh token's session is **revoked in the database** *before* a new token pair is generated. This entire process is **fail-closed**; if the old token cannot be revoked, the refresh process fails, and no new token is issued. This prevents token reuse attacks.
    4.  A new `AccessToken` and `RefreshToken` are generated and returned to the client.

---

## Identified Issues & Gaps

### P1 - Security: Incomplete 2FA Implementation

-   **Description**: The `customer` service has logic for enabling/disabling 2FA and generating secrets. However, the core verification function (`Verify2FACode`) is a placeholder that always returns `true`.
-   **Impact**: If 2FA is enabled for an account, it provides no actual security, giving a false sense of protection.
-   **Recommendation**: Implement proper TOTP (Time-based One-Time Password) validation using a standard library. This verification must be integrated into the `Login` flow.

### P2 - Event Reliability: Missing Transactional Outbox

-   **Description**: The `customer` service publishes events like `CustomerCreated` or `AddressUpdated` after the database transaction has already committed. It does not use the Transactional Outbox pattern.
-   **Impact**: If the service crashes between the database commit and the event publishing call, the event is lost. This can lead to data inconsistencies in downstream services that rely on these events (e.g., marketing, analytics).
-   **Recommendation**: Refactor the event publishing logic in the `customer` service to use the Transactional Outbox pattern, similar to how it's implemented in the `catalog` and `promotion` services.

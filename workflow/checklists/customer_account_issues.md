# Customer & Account Management Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Customer & Account Management Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## P1 - Security

- **Issue**: The 2FA verification logic is a non-functional placeholder.
  - **Service**: `customer`
  - **Location**: `customer/internal/biz/customer/two_factor.go` (`Verify2FACode` function)
  - **Impact**: If 2FA is enabled for an account, it provides no actual security as the verification step always succeeds. This gives a false sense of security and fails to protect against unauthorized access if a user's password is compromised.
  - **Recommendation**: Implement proper TOTP (Time-based One-Time Password) validation using a standard library (e.g., `pquerna/otp/totp`). The `Login` flow must be updated to enforce this verification step for users who have 2FA enabled.

---

## P2 - Event Reliability

- **Issue**: The `customer` service does not use the Transactional Outbox pattern for publishing events.
  - **Service**: `customer`
  - **Location**: `customer/internal/biz/customer/customer.go` (e.g., in `CreateCustomer`, `UpdateCustomer`)
  - **Impact**: Events like `CustomerCreated` are published in a separate step after the main database transaction has committed. If the service crashes between the commit and the event publishing call, the event is lost. This leads to data desynchronization in downstream systems (e.g., marketing, analytics, search) that rely on these events.
  - **Recommendation**: Refactor the event publishing logic in the `customer` service to use the Transactional Outbox pattern. This involves writing the event to an `outbox` table within the same database transaction as the customer data change, ensuring guaranteed event delivery.

---

## P2 - Data Integrity

- **Issue**: Deleting the last address for a customer is not prevented, and auto-assigning a new default address on deletion can fail silently.
  - **Service**: `customer`
  - **Location**: `customer/internal/biz/address/address.go` (`DeleteAddress` function)
  - **Impact**: The logic attempts to prevent deleting the last address but may not be fully robust. More importantly, if the deleted address was the default, the attempt to set a new default address only logs an error on failure and continues. This can leave a customer with no default address, which might cause issues in the checkout flow.
  - **Recommendation**: The check to prevent deleting the last address should be strict and return a clear error. The logic to auto-assign a new default address should also be hardened; if it fails, the entire `DeleteAddress` operation should be rolled back or the failure should be made more visible.

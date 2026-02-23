# Customer Domain: Gap Analysis & Improvement Plan

## 1. Executive Summary

The **Customer Service** is well-structured following Clean Architecture and Kratos patterns. It handles core lifecycle management (Registration, Login, Profile, Addresses) and delegates sensitive authentication (Token generation) to the `Auth Service`, which is a security best practice.

 However, a deep code review reveals **Security Risks (Custom 2FA)** and **Feature Gaps** (Loyalty Tiers, Advanced Segmentation) when compared to industry giants like Lazada, Shopee, and Amazon.

## 2. Industry Comparison Matrix

| Feature | Active Implementation | 🟠 Lazada / Shopee | 🟡 Amazon | Gap / Recommendation |
| :--- | :--- | :--- | :--- | :--- |
| **Auth & Security** | Basic Email/Pass, 2FA (Custom), Social Login (Detected) | SMS OTP, Email OTP, QR Login, Biometric (Mobile) | 2FA (App/SMS), Passkeys | **HIGH**: Switch 2FA to standard lib. Add SMS OTP support. |
| **Profile** | Basic Info, Avatar, Preferences | Verified Badge, Social Media Link | Public Profile, Interests | **LOW**: enhanced profile verification. |
| **Addresses** | CRUD, Hierarchy (Country/State...) | Map Pinning, "Work/Home" Tags, Default Shipping/Billing | Hub Locker, Gate Codes, Delivery Instructions | **MED**: Add "Delivery Instructions" and "Map Coordinates". |
| **Loyalty & Tiers** | Basic `CustomerType`, `CustomerGroup` | Bronze/Silver/Gold/Platinum, Points, Gamification | Prime (Subscription), Points | **HIGH**: Implement explicit **Tiering System** (Points -> Tier). |
| **Segmentation** | Basic Rules, Groups | Real-time behavioral segmentation for Ads | AI-driven "Who bought this also bought..." | **MED**: Enhance `segment` logic with behavioral events. |
| **Privacy / GDPR** | `gdpr.go` present, Consent flags | Request Data Deletion, View shared data | "Request My Data" automated reports | **OK**: Ensure `gdpr.go` is fully hooked up to handlers. |

## 3. Detailed Codebase Review

### ✅ Strengths
1.  **Architecture**: Strict separation of concerns (`biz`, `data`, `service`).
2.  **Auth Delegation**: Correctly calls `AuthClient.GenerateToken`, avoiding logic duplication.
3.  **Transactional Integrity**: `CreateCustomer` wraps DB creates + Outbox Event in a single transaction.
4.  **Observerability**: Good use of `promauto` handling.

### 🚨 Critical Issues (P0)

#### 1. Security: Custom Crypto for 2FA
In `customer/internal/biz/customer/two_factor.go`, the TOTP verification is **manually implemented**:
```go
// ❌ RISKY: Manual HOTP/TOTP implementation
func validateTOTPCode(secret, code string) bool { ... }
func generateHOTP(secret string, counter int64) string { ... }
```
**Risk**: "Rolling your own crypto" is prone to side-channel attacks or implementation bugs.
**Fix**: Replace with `github.com/pquerna/otp`.

### ⚠️ Improvements (P1/P2)

#### 1. Loyalty Tier Logic
The API returns `loyalty_tier` in Analytics, but the domain logic for **calculating** this based on spend/points seems missing or simplistic.
*   **Recommendation**: Create a `LoyaltyService` or separate module to calculate tiers based on `order` events.

#### 2. Address Logic
Current `Address` struct is standard.
*   **Recommendation**: Add `Latitude/Longitude` for precise delivery (critical for logistics integration like Grab/Uber/ShopeeExpress).

## 4. Improvement Checklist

### Phase 1: Security & Stability (Immediate)
- [ ] **[Security]** Refactor `two_factor.go` to use `github.com/pquerna/otp` or `gotp`. Remove manual HMAC logic.
- [ ] **[Test]** Add unit tests for 2FA flows to ensure the new library works as expected.
- [ ] **[Reliability]** Verify `Connect` behavior for `AuthClient` (Circuit Breaker configuration).

### Phase 2: Feature Parity (Next Sprint)
- [ ] **[Feature]** Implement **Loyalty Tiers**:
    -   Add `Tier` field to `Customer` model.
    -   Create worker to process `OrderCompleted` events and update spend -> Tier.
- [ ] **[Feature]** Enhance **Address**:
    -   Add `lat`, `lng` fields.
    -   Add `delivery_instructions` (e.g., "Leave at gate").
- [ ] **[UX]** Add **Login History** visibility for users (currently only internal audit logs).

### Phase 3: Advanced (Future)
- [ ] **[AI]** Behavioral Segmentation based on `product_viewed` events.
- [ ] **[Auth]** Passkey support.

## 5. Architectural Recommendations

1.  **Event-Driven Tiering**: Do not calculate Tiers synchronously. listen to `order.completed` -> `loyalty` worker -> update `customer_tier`.
2.  **Cache Strategy**: `Customer` object is large (Profile + Prefs). Ensure `InvalidateCustomer` handles all sub-keys if split.

---
**Standard**: Active
**Reviewer**: Senior Technical Architect

# 📋 Missing Functional Capabilities Checklist
> **Date**: 2026-02-14
> **Status**: Gap Analysis based on v5 Master Checklist & Codebase Review

---

## 🛑 Core Commerce Gaps (High Priority)

These features are standard in modern e-commerce but appear to be missing or unimplemented.

### 1. Wallet & Store Credit
**Status**: ❌ Missing
**Details**: Currently `loyalty-rewards` handles points, but there is no mechanism for "Cash Value" stored on account (e.g., specific currency balance).
**Impact**: Cannot support "Refund to Wallet" (faster than bank refund) or "Top-up" functionality.
- [ ] Create `Wallet` service or add to `Payment/Customer`.
- [ ] Implement `Deposit`, `Withdraw`, `Transfer` transaction types.
- [ ] Integreate with `Payment` service for "Pay with Wallet".
- [ ] Integrate with `Return` service for "Refund to Wallet".

### 2. Gift Cards (Vouchers are not Gift Cards)
**Status**: ❌ Missing
**Details**: `promotion` handles discounts/coupons. Gift Cards are "prepaid cash" with unique codes, not just percentage offs.
**Impact**: Missed revenue stream and gifting functionality.
- [ ] Create `GiftCard` domain (issue, redeem, check balance).
- [ ] Support partial redemption (balance updates).
- [ ] Email/Digital delivery of codes.

### 3. Subscriptions & Recurring Billing
**Status**: ❌ Missing
**Details**: No logic found for recurring orders, subscription boxes, or "Subscribe & Save".
**Impact**: Cannot sell memberships or recurring consumables.
- [ ] Implement `Subscription` service or module in `Order`.
- [ ] Add `RecurringPayment` logic in `Payment` service (tokenization exists, but scheduling is needed).
- [ ] Automated order generation cron jobs.

---

## 🔒 Compliance & Data Privacy

### 4. GDPR / "Right to be Forgotten" Automation
**Status**: ⚠️ Partial / Manual
**Details**: `customer` service has audit logs, but no automated "Export My Data" or "Delete My Account" flow that propagates to all services.
**Impact**: Legal risk; manual operational burden.
- [ ] Implement `DeleteUser` saga (orchestrator) to scrub PII from all services (Order, Shipping, Loyalty, etc.).
- [ ] Implement `ExportUserData` aggregator.
- [ ] Add consent versioning tracking.

---

## 🌍 Internationalization & Scale

### 5. Multi-Currency & FX
**Status**: ❓ Unconfirmed / Likely Missing
**Details**: System seems to assume single base currency. No FX rate management or display currency vs settlement currency logic found.
**Impact**: Limited to single market.
- [ ] Add `Currency` context to all monetary values (Money pattern).
- [ ] Implement `ExchangeRate` service or provider integration.

### 6. Multi-Warehouse Routing (Advanced)
**Status**: 🟡 Partial?
**Details**: `warehouse` exists, but does it support intelligent routing (split shipment based on nearest stock)?
**Impact**: Inefficient shipping costs if scaling to multiple physical locations.
- [ ] Verify `warehouse` selection logic in `Order` or `Fulfillment`.
- [ ] Implement geo-based inventory allocation.

---

## 🛠 Operational / Tooling

### 7. Missing Developer Skills (SOPs)
**Status**: ❌ Missing
**Details**: Current skills focus on "Add" and "Debug". Missing lifecycle management.
- [ ] `scaffold-new-service`: Template for creating service #20+.
- [ ] `manage-secrets`: Best practices for Vault/Env vars.
- [ ] `database-maintenance`: Backup/Restore/Point-in-time recovery flows.
- [ ] `promote-to-prod`: Checklist for go-live (load testing, security scan).


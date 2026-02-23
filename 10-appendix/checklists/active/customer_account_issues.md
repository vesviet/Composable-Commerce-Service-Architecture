# Customer & Account Management Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Customer & Account Management Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] [CUST-P1-01 2FA verification is a placeholder]: `Verify2FACode` always succeeds. Required: implement TOTP validation and enforce in login flow. See `customer/internal/biz/customer/two_factor.go`.
- [Medium] [CUST-P2-01 Customer events missing transactional outbox]: Events are published after DB commit. Required: write events to outbox in the same transaction. See `customer/internal/biz/customer/customer.go`.
- [Medium] [CUST-P2-02 Delete address can leave no default]: Deleting default address can fail silently to set a new default. Required: enforce last-address guard and rollback on default reassignment failure. See `customer/internal/biz/address/address.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- None
